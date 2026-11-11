--[[
  NadBypass Standalone v1.0
  Anti-cheat / report / telemetry suppression + account risk guard.

  Berdiri sendiri: tidak butuh esp_pack_2/2.lua, tidak mengubah fitur mod.
  Bisa dijalankan langsung (auto-start) atau di-dofile lalu dipanggil
  NadBypass.start().

  Cakupan:
    - blokir report flow, telemetry, crash report, replay, screenshot
    - patch scanner/security subsystem (TSS, SwiftHawk, CoronaLab, HiggsBoson,
      shoot verify, modifier exception, simulate location, dll)
    - blokir paket/RPC report di NetUtil.SendPacket / SendRPC
    - pin device fingerprint supaya konsisten antar sesi
    - AccountGuard: trust score akun + budget kill per rank + auto-quiet

  Batas penting: bypass client tidak membatalkan ban server-side. Yang
  membuat akun baru cepat kena adalah skor perilaku server (kill rate vs
  rank, report weight, device history). AccountGuard mengatur supaya pola
  main tidak menabrak ambang itu; bukan penghapus ban.

  Semua patch dibungkus pcall dan bisa di-restore lewat NadBypass.stop().
]]

local B = rawget(_G, "NadBypass")
if type(B) == "table" and B.__standalone == true then
  -- Sudah pernah di-load. Jangan patch dua kali.
  if B.config and B.config.autoStart and not B.started then B.start() end
  return B
end

B = {
  __standalone = true,
  version = "1.0.0",
  started = false,
  phases = {},
  _restore = {},
  _cleanup = {},
  _quiet = false,
}
_G.NadBypass = B

-- ============================================================================
-- CONFIG
-- ============================================================================

local CFG = {
  autoStart = true,
  verbose = true,

  block = {
    aceDomains = true,
    reports = true,
    telemetry = true,
    crash = true,
    screenshots = true,
    network = true,
    md5 = true,
    higgs = true,
    scanners = true,
    gameplay = true,
  },

  device = {
    pin = true,
    fileName = "nad_device_profile.txt",
    model = "SM-G973F",
    brand = "samsung",
  },

  guard = {
    enabled = true,
    accountLevel = 10,
    rank = "Bronze",
    accountAgeDays = 2,
    matches = 15,
    kd = 1.0,
    deviceConsistent = true,
    autoQuiet = true,
    quietRisk = 72,
    warnRisk = 45,
    burstWindow = 18.0,
    hardKillCap = 30,
  },
}
B.config = CFG

local GUARD = CFG.guard

-- ============================================================================
-- SMALL HELPERS
-- ============================================================================

local function nop() return true end
local function retFalse() return false end
local function retTrue() return true end
local function retZero() return 0 end
local function retNil() return nil end
local function retEmpty() return {} end
local function retEmptyString() return "" end

local function clamp(v, lo, hi)
  v = tonumber(v) or 0
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function log(msg)
  if CFG.verbose then print("[NAD BYPASS] " .. tostring(msg)) end
end

local function notify(msg)
  local s = "[NAD BYPASS] " .. tostring(msg)
  pcall(function()
    if type(_G.RapzhangNotify) == "function" then _G.RapzhangNotify(s) end
  end)
  pcall(function()
    local sh = import("ScriptHelperClient")
    if sh and sh.AddOnScreenDebugMessage then
      sh.AddOnScreenDebugMessage(s, -1, 3.0,
        { R = 1, G = 0.85, B = 0.2, A = 1 }, { X = 1.1, Y = 1.1 })
    end
  end)
  if CFG.verbose then print(s) end
end
B.notify = notify

-- Simpan fungsi asli supaya stop() bisa mengembalikan.
local function wrap(obj, key, newfn)
  if obj == nil then return false end
  local ok, orig = pcall(function() return obj[key] end)
  if not ok or type(orig) ~= "function" then return false end
  local ok2 = pcall(function() obj[key] = newfn end)
  if not ok2 then return false end
  B._restore[#B._restore + 1] = function()
    pcall(function() obj[key] = orig end)
  end
  return true
end

local function constFn(value)
  return function() return value end
end

local function onStop(fn)
  B._cleanup[#B._cleanup + 1] = fn
end

local function setField(obj, key, value)
  if obj == nil then return false end
  local ok, old = pcall(function() return obj[key] end)
  if not ok then return false end
  local ok2 = pcall(function() obj[key] = value end)
  if not ok2 then return false end
  onStop(function() pcall(function() obj[key] = old end) end)
  return true
end

local function safeRequire(path)
  local ok, mod = pcall(require, path)
  if ok and mod ~= nil then return mod end
  return nil
end

local function getSubsystem(name)
  local mgr = safeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
  if not mgr then return nil end
  local ok, sub = pcall(function() return mgr:Get(name) end)
  if ok then return sub end
  return nil
end

local function methodKeys(obj)
  local keys = {}
  pcall(function()
    for k, v in pairs(obj) do
      if type(v) == "function" then keys[#keys + 1] = k end
    end
  end)
  return keys
end

-- Ganti semua method yang namanya mengandung salah satu pattern.
local function patchMethods(obj, patterns, repl)
  if obj == nil then return 0 end
  local n = 0
  for _, k in ipairs(methodKeys(obj)) do
    local lk = string.lower(tostring(k))
    for _, p in ipairs(patterns) do
      if lk:find(p, 1, true) then
        if wrap(obj, k, repl) then n = n + 1 end
        break
      end
    end
  end
  return n
end

local function patchLoaded(namePattern, patterns, repl)
  local n = 0
  pcall(function()
    for name, mod in pairs(package.loaded) do
      if type(name) == "string"
        and string.lower(name):find(namePattern, 1, true) then
        n = n + patchMethods(mod, patterns, repl)
      end
    end
  end)
  return n
end

local REPORT_PATTERNS = {
  "report", "send", "upload", "verify", "scan", "detect",
  "validate", "integrity", "signature", "md5", "ban",
}

local function phase(name, fn)
  local ok, err = pcall(fn)
  B.phases[name] = { ok = ok, err = ok and nil or tostring(err) }
  if not ok then log("phase " .. name .. " gagal: " .. tostring(err)) end
  return ok
end

-- ============================================================================
-- DEVICE PROFILE (stable across sessions)
-- ============================================================================

local function devicePaths()
  local fn = CFG.device.fileName
  return {
    "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fn,
    "ShadowTrackerExtra/Saved/Paks/" .. fn,
    fn,
  }
end

local function readSeed()
  local seed = nil
  pcall(function()
    for _, path in ipairs(devicePaths()) do
      local f = io.open(path, "r")
      if f then
        seed = f:read("*a")
        f:close()
        if seed and seed ~= "" then break end
      end
    end
  end)
  if not seed or seed == "" then
    seed = string.format("%d:%d:%s", os.time(), math.floor(os.clock() * 1000),
      tostring({}))
    pcall(function()
      for _, path in ipairs(devicePaths()) do
        local f = io.open(path, "w")
        if f then
          f:write(seed)
          f:close()
          break
        end
      end
    end)
  end
  return seed
end

-- FNV-like 32-bit hash tanpa bitwise op, aman untuk Lua 5.1/5.3.
local function hash32(s, salt)
  salt = salt or 0
  local h = (2166136261 + salt * 40503) % 4294967296
  local mult = 131
  for i = 1, #s do
    h = (h * mult + s:byte(i)) % 4294967296
  end
  h = (h + salt * 7919) % 4294967296
  return h
end

local function hex32(v)
  return string.format("%08x", v % 4294967296)
end

local function pseudoId(seed)
  return hex32(hash32(seed, 1)) .. hex32(hash32(seed, 7))
    .. hex32(hash32(seed, 13)) .. hex32(hash32(seed, 29))
end

local DEVICE = nil
local function deviceProfile()
  if DEVICE then return DEVICE end
  local seed = readSeed()
  local id = pseudoId(seed)
  local imei = (string.format("%010d", hash32(seed, 3))
    .. string.format("%010d", hash32(seed, 11))):sub(1, 15)
  DEVICE = {
    id = id,
    androidId = id:sub(1, 16),
    oaid = id:sub(9, 32),
    imei = imei:sub(1, 15),
    mac = "02:" .. id:sub(1, 2) .. ":" .. id:sub(3, 4) .. ":"
      .. id:sub(5, 6) .. ":" .. id:sub(7, 8) .. ":" .. id:sub(9, 10),
    model = CFG.device.model,
    brand = CFG.device.brand,
  }
  return DEVICE
end
B.deviceProfile = deviceProfile

-- ============================================================================
-- PHASE 1: ACE DOMAIN FILTER
-- ============================================================================

local ACE_DOMAINS = {
  "anti-cheat.tencent.com", "game-security.qq.com", "tmgp-anti.com",
  "check.tencent.com", "down.anticheatexpert.com", "anticheatexpert.com",
  "tmgp.qq.com", "pubgmobile.com", "tencentgames.com", "qcloud.com",
  "myqcloud.com", "tencentcloudapi.com",
}

local function aceDomainBlocked(host)
  if not host then return false end
  local h = string.lower(tostring(host))
  for _, d in ipairs(ACE_DOMAINS) do
    if h:find(d, 1, true) then return true end
  end
  return false
end

local function phaseAceDomains()
  if not CFG.block.aceDomains then return end
  local orig = rawget(_G, "filterRequest")
  if type(orig) ~= "function" then return end
  local newFilter = function(req)
    if req and req.host and aceDomainBlocked(req.host) then
      return { code = 200, body = "" }
    end
    return orig(req)
  end
  wrap(_G, "filterRequest", newFilter)
  _G._ACE_new_filter = newFilter
end

-- ============================================================================
-- PHASE 2: SLUA / MD5 / PAK
-- ============================================================================

local function phaseSlua()
  pcall(function()
    if slua and slua.getSignature then
      wrap(slua, "getSignature", constFn(0xDEADBEEF))
    end
    local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
    if loader then
      wrap(loader, "verifyBytecode", retTrue)
      wrap(loader, "checkIntegrity", retTrue)
      wrap(loader, "disableSignatureCheck", retTrue)
    end
    local ser = package.loaded["slua.serialize"]
    if ser then
      wrap(ser, "check", retTrue)
      wrap(ser, "verify", retTrue)
    end
    if _G.slua_verify then wrap(_G, "slua_verify", retTrue) end
    if _G.check_slua_integrity then
      wrap(_G, "check_slua_integrity", retTrue)
    end
  end)
end

local function phaseMd5()
  if not CFG.block.md5 then return end
  pcall(function()
    local console = import("KismetSystemLibrary")
    if console then
      console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
      console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
      console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
      console.ExecuteConsoleCommand(nil, "sig.Check 0")
      console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
    end
    local CMode = import("CreativeModeBlueprintLibrary")
    if CMode then
      wrap(CMode, "MD5HashByteArray", constFn("00000000000000000000000000000000"))
      wrap(CMode, "MD5HashFile", constFn("00000000000000000000000000000000"))
      wrap(CMode, "GetContentDiffData", function() return true, "BYPASSED" end)
      wrap(CMode, "VerifyFileIntegrity", retTrue)
    end
    if _G.MD5Hash then
      wrap(_G, "MD5Hash", constFn("00000000000000000000000000000000"))
    end
    if _G.CRC32 then wrap(_G, "CRC32", retZero) end
    if _G.SHA1 then wrap(_G, "SHA1", constFn("BYPASS")) end
    local fhc = package.loaded["common.file_hash_checker"]
    if fhc then
      wrap(fhc, "CheckFileMD5", retTrue)
      wrap(fhc, "VerifyAll", retTrue)
      wrap(fhc, "GetHash", constFn("BYPASS"))
    end
    local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
    if TssSdk then
      wrap(TssSdk, "GetFileMD5", constFn("BYPASS"))
      wrap(TssSdk, "VerifyFileSignature", retTrue)
    end
    local STExtra = import("STExtraBlueprintFunctionLibrary")
    if STExtra then
      wrap(STExtra, "CheckMD5", retTrue)
      wrap(STExtra, "GetMD5", constFn("BYPASS"))
      wrap(STExtra, "VerifyFile", retTrue)
    end
  end)
end

-- ============================================================================
-- PHASE 3: SCREENSHOT / LOG / CRASH
-- ============================================================================

local function phaseScreenshotLog()
  pcall(function()
    if CFG.block.screenshots then
      local SMTD = import("ScreenshotMTDer")
      if SMTD then
        wrap(SMTD, "MTDePicture", retEmptyString)
        wrap(SMTD, "ReMTDePicture", retEmptyString)
        wrap(SMTD, "HasCaptured", retTrue)
        wrap(SMTD, "TakeScreenshot", nop)
      end
    end
    if CFG.block.telemetry then
      local TLog = package.loaded["TLog"] or _G.TLog
      if TLog then
        for _, k in ipairs({ "Info", "Warning", "Error", "Debug", "Report",
          "Send", "Flush" }) do
          wrap(TLog, k, nop)
        end
      end
      local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
      if GRUtils then
        wrap(GRUtils, "BugglyPostExceptionFull", retFalse)
        wrap(GRUtils, "CheckCanBugglyPostException", retFalse)
        wrap(GRUtils, "ReplayReportData", nop)
        wrap(GRUtils, "ReportGameException", nop)
        wrap(GRUtils, "PostException", nop)
      end
      local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
      if CTR then
        wrap(CTR, "SendReport", nop)
        wrap(CTR, "SendException", nop)
        wrap(CTR, "UploadLog", nop)
      end
      for _, sdk in ipairs({ "Firebase", "Adjust", "AppsFlyer",
        "FacebookAnalytics", "GameAnalytics" }) do
        local s = _G[sdk]
        if s then
          wrap(s, "logEvent", nop)
          wrap(s, "trackEvent", nop)
          wrap(s, "setEnabled", retFalse)
          wrap(s, "sendEvent", nop)
          wrap(s, "report", nop)
        end
      end
    end
    if CFG.block.crash then
      local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
      if CrashSight then
        for _, k in ipairs({ "ReportException", "SetCustomData", "Log",
          "SendCrash", "ReportUserException" }) do
          wrap(CrashSight, k, nop)
        end
      end
    end
  end)
end

-- ============================================================================
-- PHASE 4: SCANNER SUBSYSTEMS
-- ============================================================================

local SCANNER_SUBS = {
  "AFKReportorSubsystem", "ClientDataStatistcsSubsystem",
  "AvatarExceptionSubsystem", "ShootVerifySubSystemClient",
  "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem",
  "FileCheckSubsystem", "BehaviorScoreSubsystem",
}

local function phaseScanners()
  if not CFG.block.scanners then return end
  pcall(function()
    for _, name in ipairs(SCANNER_SUBS) do
      local sub = getSubsystem(name)
      if sub then
        patchMethods(sub, REPORT_PATTERNS, nop)
        pcall(function()
          if sub.ReportPingDelayTimer then
            sub:RemoveGameTimer(sub.ReportPingDelayTimer)
            sub.ReportPingDelayTimer = nil
          end
          sub.DelayCount = 0
        end)
      end
    end
    local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
    if AvaEx then
      for _, k in ipairs({ "CheckAvatarException", "CheckAvatarExceptionOnce",
        "ReportAvatarException", "CheckSlotMeshVisible", "CheckPawnVisible",
        "CheckCanBugglyPostException" }) do
        wrap(AvaEx, k, nop)
      end
    end
    local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
    if TssSdk then
      local origRecv = nil
      pcall(function() origRecv = TssSdk.OnRecvData end)
      if type(origRecv) == "function" then
        wrap(TssSdk, "OnRecvData", function(data)
          if type(data) == "string" then
            local d = string.lower(data)
            if d:find("report", 1, true) or d:find("exception", 1, true)
              or d:find("cheat", 1, true) or d:find("violation", 1, true)
              or d:find("hack", 1, true) or d:find("verify", 1, true) then
              return
            end
          end
          return origRecv(data)
        end)
      end
      if type(TssSdk.IsEmulator) == "boolean" then
        setField(TssSdk, "IsEmulator", false)
      else
        wrap(TssSdk, "IsEmulator", retFalse)
      end
      for _, k in ipairs({ "SendReportInfo", "ScanMemory",
        "GetTssSdkReportInfo", "CheckEnvironment", "VerifyProcess" }) do
        local v = (k == "GetTssSdkReportInfo") and retEmptyString or retTrue
        wrap(TssSdk, k, v)
      end
    end
  end)
end

-- ============================================================================
-- PHASE 5: REPORT / REPLAY / SECURITY FLOWS
-- ============================================================================

local REPORT_FLOWS = {
  "ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow",
  "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow",
  "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate",
  "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition",
  "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData",
  "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP",
  "ReportPlayerFramePingRecord", "ReportDSNetSaturation",
  "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow",
  "ReportSecMrpcsFlow",
}

local function phaseReportFlows()
  if not CFG.block.reports then return end
  pcall(function()
    for _, f in ipairs(REPORT_FLOWS) do
      if _G[f] then wrap(_G, f, nop) end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then
        wrap(_G.GameplayCallbacks, f, nop)
      end
    end
    for _, f in ipairs({ "CheckReportSecAttackFlowWithAttackFlow",
      "CheckReportSecAttackFlow" }) do
      if _G[f] then wrap(_G, f, retFalse) end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then
        wrap(_G.GameplayCallbacks, f, retFalse)
      end
    end
    for _, f in ipairs({ "IsEnableReportMrpcsInCircleFlow",
      "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow",
      "IsEnableReportAttackFlow", "IsEnableReportHitFlow",
      "IsEnableReportCircleFlow" }) do
      if _G[f] then wrap(_G, f, retFalse) end
    end
    local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
    if logRep then
      wrap(logRep, "ReportReplay", nop)
      wrap(logRep, "SendReportReq", nop)
      wrap(logRep, "UploadReplay", nop)
    end
  end)
end

local function phaseSecurity()
  pcall(function()
    for _, c in ipairs({ "PlayerSecurityInfoCollector", "PlayerSecurityInfo",
      "SecurityInfoCollector", "ClientSecurityCollector",
      "PlayerAntiCheatCollector" }) do
      local obj = _G[c]
      if obj then patchMethods(obj, REPORT_PATTERNS, nop) end
    end
    local SecSub = safeRequire("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
    if SecSub then
      wrap(SecSub, "ReportData", nop)
      wrap(SecSub, "CheckCheat", retFalse)
      wrap(SecSub, "ValidatePlayer", retTrue)
      wrap(SecSub, "CollectData", nop)
      wrap(SecSub, "SendToServer", nop)
    end
    for _, name in ipairs({ "ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData",
      "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem",
      "ClientSecPlayerKillFlow" }) do
      local obj = package.loaded[name] or _G[name]
      if obj then patchMethods(obj, REPORT_PATTERNS, nop) end
    end
    for _, f in ipairs({ "SwiftHawk", "ClientSwiftHawk",
      "ClientSwiftHawkWithParams", "SendSwiftHawkData" }) do
      if _G[f] then wrap(_G, f, nop) end
      if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then
        wrap(_G.GameplayCallbacks, f, nop)
      end
    end
    local swift = safeRequire("GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem")
    if swift then
      wrap(swift, "ReportData", nop)
      wrap(swift, "SendReport", nop)
      wrap(swift, "CollectTelemetry", nop)
    end
    if _G.CoronaLab then
      for _, k in ipairs({ "ReportData", "SendData", "CollectData",
        "Telemetry" }) do
        wrap(_G.CoronaLab, k, nop)
      end
    end
    local corona = getSubsystem("CoronaLabSubsystem")
    if corona then
      for _, k in ipairs({ "ReportData", "SendToServer", "CollectTelemetry",
        "StopCollection" }) do
        wrap(corona, k, nop)
      end
    end
    if _G.bReportedModifierException then _G.bReportedModifierException = false end
    local modEx = safeRequire("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
    if modEx then
      wrap(modEx, "ReportException", nop)
      wrap(modEx, "CheckModifier", retTrue)
      wrap(modEx, "ValidateModifier", retTrue)
      wrap(modEx, "ReportModifierError", nop)
    end
    local sim = safeRequire("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
    if sim then
      wrap(sim, "ReportLocation", nop)
      wrap(sim, "SendLocationData", nop)
      wrap(sim, "VerifyLocation", retTrue)
    end
    local shoot = safeRequire("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
    if shoot then
      wrap(shoot, "OnShootVerifyFailed", nop)
      wrap(shoot, "SendVerifyData", nop)
      wrap(shoot, "ReportBulletHit", nop)
      wrap(shoot, "UploadHitInfo", nop)
      wrap(shoot, "VerifyShot", retTrue)
    end
    if _G.BulletHitInfoUploadData then
      for _, k in ipairs({ "Report", "Send", "Upload" }) do
        wrap(_G.BulletHitInfoUploadData, k, nop)
      end
    end
  end)
end

-- ============================================================================
-- PHASE 6: NETWORK PACKETS / RPC
-- ============================================================================

local BLOCKED_PACKETS = {
  ReportAttackFlow = true, ReportSecAttackFlow = true, ReportFireArms = true,
  ReportVerifyInfoFlow = true, ReportMrpcsFlow = true,
  ReportPlayerBehavior = true, ReportTeammatHurt = true,
  ReportPlayerMoveRoute = true, ReportPlayerPosition = true,
  ReportSecVehicleMoveFlow = true, report_parachute_data = true,
  on_tss_sdk_anti_data = true, ReportAimFlow = true, ReportHitFlow = true,
  ReportCircleFlow = true, report_players_ping = true,
  report_player_ip = true, report_net_saturate = true,
  report_speed_hack = true, report_wall_hack = true,
  report_aim_bot = true, report_esp_usage = true,
  report_modded_files = true, detect_cheat = true, ban_player = true,
  client_anti_cheat_report = true, ClientSecMrpcsFlow = true,
  MrpcsData = true, CheckReportSecAttackFlow = true,
  CheckReportSecAttackFlowWithAttackFlow = true,
  RPC_ClientCoronaLab = true, CoronaLabReport = true, CoronaLabData = true,
  PlayerSecurityInfo = true, ReportSecurityInfo = true,
  SendSecurityData = true, ClientCircleFlow = true,
  IsEnableReportMrpcsInCircleFlow = true,
  IsEnableReportMrpcsInPartCircleFlow = true,
  bReportedModifierException = true, ReportModifierException = true,
  RPC_Server_ReportSimulateCharacterLocation = true,
  ReportSimulateCharacterLocation = true,
  RPC_Client_ShootVertifyRes = true, BulletHitInfoUploadData = true,
  ShootVerifyFailed = true, report_unrealnet_exception = true,
  tss_sdk_report = true, SwiftHawk = true, ClientSwiftHawk = true,
  ClientSwiftHawkWithParams = true, SwiftHawkReport = true,
  SwiftHawkData = true, AntiCheatReport = true, CheatDetection = true,
  ViolationReport = true, SecurityViolation = true, IntegrityCheck = true,
  SignatureVerify = true,
}

local BLOCKED_RPC = {
  "RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk",
  "RPC_Server_ClientSwiftHawkWithParams",
  "RPC_Server_ReportSimulateCharacterLocation",
  "RPC_Client_ShootVertifyRes", "RPC_Client_CoronaLab",
}

local function phaseNetwork()
  if not CFG.block.network then return end
  pcall(function()
    local NetUtil = _G.NetUtil
    if NetUtil and type(NetUtil.SendPacket) == "function" then
      local orig = NetUtil.SendPacket
      wrap(NetUtil, "SendPacket", function(packetName, ...)
        if BLOCKED_PACKETS[packetName] then return nil end
        return orig(packetName, ...)
      end)
      local oldFlag = NetUtil.IsBypassed
      NetUtil.IsBypassed = true
      onStop(function() NetUtil.IsBypassed = oldFlag end)
    end
    if type(_G.SendRPC) == "function" then
      local origRPC = _G.SendRPC
      wrap(_G, "SendRPC", function(rpcName, ...)
        for _, b in ipairs(BLOCKED_RPC) do
          if rpcName == b then return nil end
        end
        return origRPC(rpcName, ...)
      end)
    end
  end)
end

-- ============================================================================
-- PHASE 7: HIGGS BOSON
-- ============================================================================

local HIGGS_METHODS = {
  "ControlMHActive", "Tick", "OnTick", "MHActiveLogic",
  "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID",
  "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert",
  "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData",
  "ValidateSecurityData", "StaticShowSecurityAlertInDev",
  "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation",
  "DisableHiggsBoson", "CheckMHActive", "ReportViolation",
  "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity",
}

local function phaseHiggs()
  if not CFG.block.higgs then return end
  pcall(function()
    local Higgs = safeRequire("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
    if Higgs then
      for _, m in ipairs(HIGGS_METHODS) do wrap(Higgs, m, nop) end
      wrap(Higgs, "GetNetAvatarItemIDs", retEmpty)
      wrap(Higgs, "GetCurWeaponSkinID", retZero)
      wrap(Higgs, "IsMHActive", retFalse)
      pcall(function()
        Higgs.bMHActive = false
        Higgs.bCallPreReplication = false
        if Higgs.BlackList then
          for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end
        end
      end)
    end
    local oldBlackList = _G.BlackList
    _G.BlackList = {}
    onStop(function() _G.BlackList = oldBlackList end)
    local pc = _G.slua_GameFrontendHUD
      and _G.slua_GameFrontendHUD:GetPlayerController()
    if pc and slua and slua.isValid and slua.isValid(pc) then
      pcall(function()
        if pc.HiggsBoson then
          pc.HiggsBoson.bMHActive = false
          pc.HiggsBoson.bCallPreReplication = false
          if pc.HiggsBoson.ControlMHActive then
            pc.HiggsBoson:ControlMHActive(0)
          end
        end
        if pc.HiggsBosonComponent then
          pc.HiggsBosonComponent.bMHActive = false
          pc.HiggsBosonComponent.bCallPreReplication = false
          if pc.HiggsBosonComponent.ControlMHActive then
            pc.HiggsBosonComponent:ControlMHActive(0)
          end
        end
      end)
    end
  end)
end

-- ============================================================================
-- PHASE 8: GAMEPLAY CALLBACKS
-- ============================================================================

local GAMEPLAY_BLOCKED = {
  "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms",
  "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior",
  "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick",
  "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow",
  "ReportSecTgameMovingFlow", "ReportParachuteData",
  "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow",
  "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord",
  "OnDSConnectionSaturated", "ReportDSNetSaturation",
  "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats",
  "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow",
  "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams",
}

local BANNED_STATES = {
  cheatdetected = true, connectionlost = true, connectiontimeout = true,
  connectionexception = true, netdrivererror = true, banned = true,
  kicked = true, suspended = true, violationdetected = true,
  integrityfailure = true, securityviolation = true,
}

local function phaseGameplay()
  if not CFG.block.gameplay then return end
  pcall(function()
    if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
    local GC = _G.GameplayCallbacks
    if GC.IsBypassed then return end
    for _, f in ipairs(GAMEPLAY_BLOCKED) do wrap(GC, f, nop) end
    wrap(GC, "CheckReportSecAttackFlowWithAttackFlow", retFalse)
    wrap(GC, "CheckReportSecAttackFlow", retFalse)
    local origState = GC.OnDSPlayerStateChanged
    if type(origState) == "function" then
      wrap(GC, "OnDSPlayerStateChanged", function(UID, State, bPure, bSafe, Param)
        local s = State and string.lower(tostring(State)) or ""
        if BANNED_STATES[s] then return end
        return origState(UID, State, bPure, bSafe, Param)
      end)
    end
    for _, k in ipairs({ "OnPlayerNetConnectionClosed",
      "OnPlayerActorChannelError", "OnPlayerRPCValidateFailed",
      "OnPlayerSpectateException", "OnShutdownAfterError" }) do
      wrap(GC, k, nop)
    end
    local oldFlag = GC.IsBypassed
    GC.IsBypassed = true
    onStop(function() GC.IsBypassed = oldFlag end)
  end)
end

-- ============================================================================
-- PHASE 9: SUBSYSTEM SWEEP
-- ============================================================================

local KILL_SUBS = {
  "CoronaLabSubsystem", "PlayerSecurityInfoSubsystem",
  "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem",
  "SimulateCharacterSubsystem", "ShootVerifySubSystemClient",
  "HiggsBosonComponent", "ClientReportPlayerSubsystem",
  "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem",
  "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem",
  "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem",
  "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem",
  "AvatarExceptionSubsystem", "GameReportSubsystem",
  "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem",
  "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem",
  "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem",
}

local function phaseSubsystems()
  pcall(function()
    for _, name in ipairs(KILL_SUBS) do
      local sub = getSubsystem(name)
      if sub then
        patchMethods(sub, REPORT_PATTERNS, nop)
        for _, timerKey in ipairs({ "timer", "heartbeatTimer",
          "reportTimer" }) do
          pcall(function()
            if sub[timerKey] then
              sub:RemoveGameTimer(sub[timerKey])
              sub[timerKey] = nil
            end
          end)
        end
      end
    end
    local ops = getSubsystem("OperationalStatsSubsystem")
      or _G.OperationalStatsSubsystem
    if ops then
      for _, k in ipairs({ "ReportOperationalStats", "AddOperationalStats",
        "HandleTouchBegin", "HandleTouchEnd", "OnInit",
        "HandleEnterFighting", "OnBattleResult" }) do
        wrap(ops, k, nop)
      end
      pcall(function()
        if ops.TimerHandle then
          ops:RemoveGameTimer(ops.TimerHandle)
          ops.TimerHandle = nil
        end
      end)
      ops.StatsData = {}
    end
  end)
end

-- ============================================================================
-- PHASE 10: SPECIALIZED MODULE SWEEP
-- (ClientEntry, HawkEye, BanLogic, ReportSystem, TLog, DNS, Gokuba,
--  Racing, Login) — path berbeda per build, jadi pakai pola nama modul.
-- ============================================================================

local function sweepNamed(pattern, patterns)
  local n = patchLoaded(pattern, patterns or REPORT_PATTERNS, nop)
  pcall(function()
    local keys = {}
    for k in pairs(_G) do
      if type(k) == "string" and k ~= "_G" then keys[#keys + 1] = k end
    end
    for _, k in ipairs(keys) do
      if string.lower(k):find(pattern, 1, true) then
        n = n + patchMethods(_G[k], patterns or REPORT_PATTERNS, nop)
      end
    end
  end)
  return n
end

local SPECIAL_PATTERNS = {
  cliententry = { "report", "verify", "check", "detect", "scan", "integrity" },
  hawkeye = REPORT_PATTERNS,
  banlogic = { "report", "ban", "check", "verify", "detect" },
  clientban = { "report", "ban", "check", "verify", "detect" },
  bansubsystem = { "report", "ban", "check", "verify", "detect" },
  reportsystem = { "report", "send", "upload", "record", "collect" },
  reportmanager = { "report", "send", "upload", "record", "collect" },
  gokuba = REPORT_PATTERNS,
  racing = { "report", "check", "verify", "detect", "scan", "ban" },
  -- "login" sengaja tidak memakai "send"/"check": jangan nop login request.
  login = { "report", "verify", "detect", "integrity" },
  dns = { "report", "check", "verify", "detect", "monitor" },
  deviceinfo = { "report", "check", "verify", "detect" },
}

local function phaseSpecialized()
  pcall(function()
    for name, patterns in pairs(SPECIAL_PATTERNS) do
      sweepNamed(name, patterns)
    end
  end)
end

-- ============================================================================
-- PHASE 11: DEVICE PINNING
-- ============================================================================

local DEVICE_GETTERS = {
  { "GetDeviceID", "id" }, { "GetDeviceId", "id" },
  { "GetAndroidID", "androidId" }, { "GetAndroidId", "androidId" },
  { "GetIMEI", "imei" }, { "GetImei", "imei" },
  { "GetOAID", "oaid" }, { "GetOaid", "oaid" },
  { "GetMac", "mac" }, { "GetMacAddress", "mac" },
  { "GetDeviceModel", "model" }, { "GetDeviceBrand", "brand" },
}

local function phaseDevicePin()
  if not CFG.device.pin then return end
  pcall(function()
    local prof = deviceProfile()
    local targets = { _G, _G.TssSdk, _G.DeviceInfo, _G.DeviceUtil }
    for _, target in ipairs(targets) do
      if target then
        for _, g in ipairs(DEVICE_GETTERS) do
          local value = prof[g[2]]
          if value ~= nil then
            wrap(target, g[1], constFn(value))
          end
        end
      end
    end
    local TssSdk = _G.TssSdk
    if TssSdk then
      wrap(TssSdk, "IsEmulator", retFalse)
      wrap(TssSdk, "CheckEnvironment", retTrue)
      wrap(TssSdk, "VerifyProcess", retTrue)
      wrap(TssSdk, "ScanMemory", retTrue)
    end
  end)
end

-- ============================================================================
-- PHASE 12: FINAL FLAGS
-- ============================================================================

local function phaseFinal()
  pcall(function()
    for _, flag in ipairs({ "ENABLE_REPORT", "ENABLE_ANTI_CHEAT",
      "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS",
      "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT" }) do
      if _G[flag] ~= nil then
        local name = flag
        local old = _G[name]
        _G[name] = false
        onStop(function() _G[name] = old end)
      end
    end
  end)
end

-- ============================================================================
-- START / STOP / STATUS
-- ============================================================================

function B.start()
  if B.started then return B end
  B.started = true
  B._restore = {}
  B._cleanup = {}
  B.phases = {}
  log("start v" .. B.version)

  phase("ace", phaseAceDomains)
  phase("slua", phaseSlua)
  phase("md5", phaseMd5)
  phase("screenshot_log", phaseScreenshotLog)
  phase("scanners", phaseScanners)
  phase("report_flows", phaseReportFlows)
  phase("security", phaseSecurity)
  phase("network", phaseNetwork)
  phase("higgs", phaseHiggs)
  phase("gameplay", phaseGameplay)
  phase("subsystems", phaseSubsystems)
  phase("specialized", phaseSpecialized)
  phase("device", phaseDevicePin)
  phase("final", phaseFinal)

  local okCount, total = 0, 0
  for _, st in pairs(B.phases) do
    total = total + 1
    if st.ok then okCount = okCount + 1 end
  end
  log(string.format("selesai: %d/%d fase OK, %d patch aktif",
    okCount, total, #B._restore))
  return B
end

B.install = B.start

-- Dipakai kalau script diinject terlalu awal (modul game belum lengkap).
-- stop() mengembalikan patch lama, lalu start() memindai ulang.
function B.restart()
  if B.started then B.stop() end
  return B.start()
end

function B.stop()
  for i = #B._restore, 1, -1 do
    pcall(B._restore[i])
  end
  for i = #B._cleanup, 1, -1 do
    pcall(B._cleanup[i])
  end
  B._restore = {}
  B._cleanup = {}
  B.started = false
  B.setQuiet(false)
  log("stop: semua patch di-restore")
  return B
end

function B.status()
  local okCount, total = 0, 0
  for _, st in pairs(B.phases) do
    total = total + 1
    if st.ok then okCount = okCount + 1 end
  end
  return {
    version = B.version,
    started = B.started,
    phases_ok = okCount,
    phases_total = total,
    patches = #B._restore,
    guard = B.guard and B.guard.snapshot() or nil,
  }
end

-- ============================================================================
-- ACCOUNT GUARD
-- ============================================================================

local RANK_NAMES = {
  "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Crown", "Ace",
  "Conqueror",
}

local RANK_TIERS = {
  Bronze     = { base = 2.6, trust = 0,  idx = 1 },
  Silver     = { base = 3.4, trust = 2,  idx = 2 },
  Gold       = { base = 4.2, trust = 4,  idx = 3 },
  Platinum   = { base = 5.0, trust = 6,  idx = 4 },
  Diamond    = { base = 5.8, trust = 8,  idx = 5 },
  Crown      = { base = 6.6, trust = 10, idx = 6 },
  Ace        = { base = 7.4, trust = 12, idx = 7 },
  Conqueror  = { base = 8.2, trust = 14, idx = 8 },
}

local function rankInfo(name)
  if type(name) ~= "string" then return RANK_TIERS.Bronze end
  local n = string.lower(name)
  if n:find("conqueror", 1, true) then return RANK_TIERS.Conqueror end
  if n:find("ace", 1, true) then return RANK_TIERS.Ace end
  if n:find("crown", 1, true) then return RANK_TIERS.Crown end
  if n:find("diamond", 1, true) then return RANK_TIERS.Diamond end
  if n:find("platinum", 1, true) then return RANK_TIERS.Platinum end
  if n:find("gold", 1, true) then return RANK_TIERS.Gold end
  if n:find("silver", 1, true) then return RANK_TIERS.Silver end
  return RANK_TIERS.Bronze
end

local G = {
  kills = 0,
  headshots = 0,
  reports = 0,
  bursts = 0,
  spectators = 0,
  lastKillT = nil,
  startT = nil,
  risk = 0,
  state = "safe",
  trust = 0,
  budget = 0,
  baseline = 0,
  _lastNotifyT = -999,
  _lastPolledKills = nil,
  _quiet = false,
}

local function computeTrust()
  local level = clamp(GUARD.accountLevel, 1, 80)
  local age = clamp(GUARD.accountAgeDays, 0, 365)
  local matches = clamp(GUARD.matches, 0, 600)
  local kd = clamp(GUARD.kd, 0, 4)
  local tier = rankInfo(GUARD.rank)

  local score = 0
  score = score + 22 * (level / 80)
  score = score + 24 * (age / 365)
  score = score + 18 * (matches / 600)
  score = score + tier.trust
  score = score + 8 * clamp((kd - 0.8) / 2.2, 0, 1)
  if GUARD.deviceConsistent ~= false then score = score + 12 end
  return clamp(score, 0, 100)
end

local function computeBudget()
  local tier = rankInfo(GUARD.rank)
  local kd = clamp(GUARD.kd, 0.5, 3.0)
  local baseline = tier.base * (0.85 + 0.15 * kd)
  local budget = baseline + G.trust / 18 + 1.5
  return baseline, math.max(2, math.floor(budget + 0.5))
end

local function recalc()
  G.trust = computeTrust()
  G.baseline, G.budget = computeBudget()
end

local function evaluate(now)
  now = tonumber(now) or os.clock()
  if not GUARD.enabled then return G.risk, G.state end

  local risk = 0

  -- 1) kill di atas budget
  local excess = math.max(0, G.kills - G.budget)
  risk = risk + excess * (14 - G.trust * 0.06)

  -- 2) rasio headshot tinggi dengan sample cukup
  if G.kills >= 6 then
    local hs = G.headshots / G.kills
    if hs > 0.70 then
      risk = risk + (hs - 0.70) * 90
    end
  end

  -- 3) kill beruntun terlalu cepat
  risk = risk + G.bursts * 5

  -- 4) report dari korban
  risk = risk + G.reports * (10 - G.trust * 0.04)

  -- 5) penonton / spectate
  risk = risk + math.min(G.spectators, 5) * 2.5

  -- 6) match pendek dengan kill banyak
  local elapsed = G.startT and math.max(0, now - G.startT) or 0
  if G.startT and G.kills >= 8 and elapsed < 240 then
    risk = risk + 8
  end

  -- 7) diskon trust: akun lama menyerap anomali lebih baik
  risk = risk * (1.12 - G.trust / 250)

  -- 8) pengali akun baru: 30 hari pertama lebih diawasi
  local ageFactor = 1 + (1 - clamp(GUARD.accountAgeDays, 0, 30) / 30) * 0.35
  risk = risk * ageFactor

  -- 9) hard cap kill (pola paling tidak masuk akal)
  if G.kills > GUARD.hardKillCap then
    risk = risk + (G.kills - GUARD.hardKillCap) * 6
  end

  G.risk = clamp(risk, 0, 100)

  local prev = G.state
  if G.risk >= GUARD.quietRisk then
    G.state = "quiet"
  elseif G.risk >= GUARD.warnRisk then
    G.state = "warn"
  else
    G.state = "safe"
  end

  if prev ~= G.state and (now - G._lastNotifyT) >= 3.0 then
    G._lastNotifyT = now
    if G.state == "quiet" then
      notify(string.format("RISK %.0f%% — quiet mode, ESP disembunyikan", G.risk))
    elseif G.state == "warn" then
      notify(string.format("RISK %.0f%% (budget %dK) — pelan-pelan",
        G.risk, G.budget))
    else
      notify("RISK turun — aman lagi")
    end
  end

  if GUARD.autoQuiet then
    if G.state == "quiet" and not G._quiet then
      B.setQuiet(true)
    elseif G.state ~= "quiet" and G._quiet
      and G.risk < (GUARD.quietRisk - 12) then
      B.setQuiet(false)
    end
  end

  return G.risk, G.state
end

function B.setQuiet(on)
  on = on and true or false
  if G._quiet == on then return end
  G._quiet = on
  B._quiet = on
  if type(B.onQuiet) == "function" then pcall(B.onQuiet, on) end
  notify(on and "quiet ON — kurangi kill / matikan ESP"
    or "quiet OFF — ESP boleh tampil lagi")
end

function B.isQuiet()
  return G._quiet == true
end

B.guard = {}

function B.guard.setAccount(t)
  if type(t) ~= "table" then return end
  if t.level ~= nil then GUARD.accountLevel = tonumber(t.level) or GUARD.accountLevel end
  if type(t.rank) == "number" then
    GUARD.rank = RANK_NAMES[clamp(math.floor(t.rank), 1, 8)] or GUARD.rank
  elseif t.rank ~= nil then
    GUARD.rank = tostring(t.rank)
  end
  if t.ageDays ~= nil then GUARD.accountAgeDays = tonumber(t.ageDays) or GUARD.accountAgeDays end
  if t.matches ~= nil then GUARD.matches = tonumber(t.matches) or GUARD.matches end
  if t.kd ~= nil then GUARD.kd = tonumber(t.kd) or GUARD.kd end
  if t.deviceConsistent ~= nil then GUARD.deviceConsistent = t.deviceConsistent and true or false end
  recalc()
  return B.guard.snapshot()
end

function B.guard.resetMatch(now)
  G.kills = 0
  G.headshots = 0
  G.reports = 0
  G.bursts = 0
  G.spectators = 0
  G.lastKillT = nil
  G.startT = tonumber(now) or os.clock()
  G.risk = 0
  G.state = "safe"
  G._lastPolledKills = 0
  G._lastNotifyT = -999
  B.setQuiet(false)
  return B.guard.snapshot(now)
end

function B.guard.kill(opts)
  if opts == true then opts = { headshot = true }
  elseif type(opts) ~= "table" then opts = {} end
  local now = tonumber(opts.t) or os.clock()

  if G.startT == nil then G.startT = now end
  G.kills = G.kills + 1
  if opts.headshot then G.headshots = G.headshots + 1 end

  if G.lastKillT and (now - G.lastKillT) < GUARD.burstWindow then
    G.bursts = G.bursts + 1
  end
  G.lastKillT = now

  evaluate(now)

  if G.kills > G.budget and (now - G._lastNotifyT) >= 3.0 then
    G._lastNotifyT = now
    notify(string.format("KILL %d/%d — di atas budget %s",
      G.kills, G.budget, tostring(GUARD.rank)))
  end
  return B.guard.snapshot(now)
end

function B.guard.report(n)
  G.reports = G.reports + math.max(1, math.floor(tonumber(n) or 1))
  evaluate()
  return B.guard.snapshot()
end

function B.guard.setSpectators(n)
  G.spectators = math.max(0, math.floor(tonumber(n) or 0))
  evaluate()
  return B.guard.snapshot()
end

function B.guard.tick(now)
  now = tonumber(now) or os.clock()
  if not GUARD.enabled then return B.guard.snapshot(now) end

  local n = B.adapters.readKills()
  if type(n) == "number" then
    if G._lastPolledKills ~= nil and n < G._lastPolledKills then
      -- 0 setelah sebelumnya > 0 = match baru.
      if n == 0 then B.guard.resetMatch(now) end
    end
    local delta = n - (G._lastPolledKills or n)
    if delta > 0 then
      for _ = 1, delta do B.guard.kill({ t = now }) end
    end
    G._lastPolledKills = n
  end

  evaluate(now)
  return B.guard.snapshot(now)
end

function B.guard.snapshot(now)
  local hsRatio = G.kills > 0 and (G.headshots / G.kills) or 0
  return {
    trust = G.trust,
    baseline = G.baseline,
    budget = G.budget,
    kills = G.kills,
    headshots = G.headshots,
    hsRatio = hsRatio,
    reports = G.reports,
    bursts = G.bursts,
    spectators = G.spectators,
    risk = G.risk,
    state = G.state,
    quiet = G._quiet,
    rank = GUARD.rank,
    accountLevel = GUARD.accountLevel,
    accountAgeDays = GUARD.accountAgeDays,
    elapsed = G.startT
      and math.max(0, (tonumber(now) or os.clock()) - G.startT) or 0,
  }
end

-- ============================================================================
-- ADAPTERS: baca kill count dari game kalau tersedia
-- ============================================================================

B.adapters = {}

function B.adapters.readKills()
  local candidates = {}
  pcall(function()
    local hud = _G.slua_GameFrontendHUD
    if hud and hud.GetPlayerController then
      local pc = hud:GetPlayerController()
      if pc then
        candidates[#candidates + 1] = pc.PlayerState
        candidates[#candidates + 1] = pc.MyPlayerState
        candidates[#candidates + 1] = pc
      end
    end
  end)
  for _, obj in ipairs(candidates) do
    if obj then
      for _, key in ipairs({ "KillCount", "Kills", "BP_mykill", "MyKill" }) do
        local ok, v = pcall(function() return obj[key] end)
        if ok and type(v) == "number" then return v end
      end
      local ok, v = pcall(function() return obj:GetKillCount() end)
      if ok and type(v) == "number" then return v end
    end
  end
  return nil
end

-- ============================================================================
-- BOOT
-- ============================================================================

recalc()

local autostart = rawget(_G, "NAD_BYPASS_AUTOSTART")
if autostart == nil then autostart = CFG.autoStart end
if autostart then B.start() end

return B
