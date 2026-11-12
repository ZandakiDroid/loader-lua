--[[
  anticheat_470.lua — bypass anti-cheat client PUBG Mobile 4.7.0
  Sumber acuan: mini_obb.pak 4.7.0 yang sudah didekode ke mini470/dec_all
  (479 file Lua hasil filter kata kunci).

  Modul ini berdiri sendiri:
    * tidak require esp_pack_2 / 2.lua / part A-J
    * tidak mengubah fitur gameplay, UI, atau konfigurasi lain
    * semua hook dibungkus pcall dan bisa dilepas lewat AC470.stop()

  Pemakaian:
    dofile("bypass_470/anticheat_470.lua")        -- autoStart = true
    atau
    local AC = dofile("bypass_470/anticheat_470.lua")
    AC.config.autoStart = false
    AC.start({ layers = { sound = false } })
    AC.stop()

  Semua patch bersifat idempotent. Memuat file ini dua kali mengembalikan
  tabel AC470 yang sama tanpa memasang hook ganda.
]]

local MODULE_ID = "anticheat_470"
local VERSION = "1.0.0"

local existing = rawget(_G, "AC470")
if type(existing) == "table" and existing.__id == MODULE_ID then
  return existing
end

local M = {
  __id = MODULE_ID,
  version = VERSION,
  started = false,
  nativeLoad = nil,
  errors = {},
  stats = {},
  _watch = {},
}

_G.AC470 = M

-- ============================================================================
-- 0. Utilitas
-- ============================================================================

local function isTable(v)
  return type(v) == "table"
end

local function isFn(v)
  return type(v) == "function"
end

-- Table host bisa berupa userdata C++ dengan method di metatable.
local function hostTable(obj)
  if isTable(obj) then
    return obj
  end
  local mt = getmetatable(obj)
  if isTable(mt) then
    return mt
  end
  return nil
end

local function log(fmt, ...)
  if M.config and M.config.verbose then
    local ok, msg = pcall(string.format, "[AC470] " .. fmt, ...)
    print(ok and msg or ("[AC470] " .. tostring(fmt)))
  end
end

local function addError(where, err)
  local msg = string.format("%s: %s", tostring(where), tostring(err))
  M.errors[#M.errors + 1] = msg
  if M.config and M.config.verbose then
    print("[AC470] ERROR " .. msg)
  end
end

local function safeCall(where, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    addError(where, err)
  end
  return ok, err
end

local function merge(dst, src)
  if not isTable(src) then
    return dst
  end
  for k, v in pairs(src) do
    if isTable(v) and isTable(dst[k]) then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

local function globMatch(text, pattern)
  if type(text) ~= "string" or type(pattern) ~= "string" then
    return false
  end
  if text == pattern then
    return true
  end
  if not string.find(pattern, "*", 1, true) then
    return false
  end
  local escaped = pattern:gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1")
  escaped = escaped:gsub("%*", ".*")
  return string.match(text, "^" .. escaped .. "$") ~= nil
end

local function anyMatch(text, patterns)
  if type(patterns) ~= "table" then
    return false
  end
  for _, p in pairs(patterns) do
    if globMatch(text, p) then
      return true
    end
  end
  return false
end

-- ============================================================================
-- 1. Konfigurasi
-- ============================================================================

M.config = {
  autoStart = true,
  verbose = true,
  verboseBlock = false,

  layers = {
    loader = true,          -- hook_lua_native_func: pre-mark / restore load
    tss = true,             -- transport TSS + tag perangkat
    net = true,             -- filter NetUtil.SendPkg / SendPacket
    report = true,          -- GameReportUtils / GameReportSubsystem / Buggly
    replayHandlers = true,  -- handler ReplayReportHandler (ID 1-12)
    gameplayMonitors = true,-- FPPAnim, SpectatorScope, ReportCrashKit
    higgs = true,           -- HiggsBoson behavioral flow
    sound = true,           -- SoundMonitor TLog + AudioNumberTooMuch
    crew = true,            -- crew safety detection auto-pass
    gokuba = true,          -- Gokuba ForwardFeature
    notify = true,          -- SecurityNotifyPCFeature (tips ban)
    crash = true,           -- ClientToolsReport / native crash (opsional)
    tlog = true,            -- tlog ReportTLogEvent + lobby flow
    dsMonitor = true,       -- logic_ds_monitor DSProtocolFrequencyReport
    ban = false,            -- hanya kosmetik, lihat README
  },

  loader = {
    blockHookModule = true,
    restoreLoad = true,
    restorePcall = false,   -- pcall/xpcall hook tidak menghalangi script
  },

  tss = {
    blockSend = true,
    blockRecv = false,
    spoofUserTag = true,
    userTag = "",
    spoofDeviceFeature = true,
    deviceFeature = 0,
    blockMethods = {
      "SendSkdData", "SendSdkData", "SendAntiData", "ReportAntiData",
      "SendReportInfo", "ReportSdkData",
    },
  },

  net = {
    block = {
      "on_crow_update_ntf*",
      "hisar",
      "report_unrealnet_event",
      "report_unrealnet_exception",
      "report_dh_calc_key_error",
      "DSProtocolFrequencyReport",
    },
    allow = {},
    numericBlock = {},
    blockAllstarAuthRpc = false,
  },

  report = {
    blockReplay = true,
    replayAllow = {},
    blockBuggly = true,
    bugglyAllow = {},
    blockException = true,
    blockSubsystemRecord = true,
  },

  sound = {
    blockCollect = true,
    blockTlog = true,
  },

  crew = {
    autoPass = true,
    result = 0,
  },

  notify = {
    blockTips = true,
    blockBanSync = true,
  },

  crash = {
    blockClientToolsReport = true,
    blockNativeCrash = false,
  },

  tlog = {
    blockLobbyFlows = { "SoundAbnormalFlow" },
    blockEventNames = { "CrewSafetyDetection", "Screen_Capture_Report" },
  },

  dsMonitor = {
    blockRecord = true,
  },

  ban = {
    hideIdipTips = true,
  },
}

if isTable(rawget(_G, "AC470_CONFIG")) then
  merge(M.config, rawget(_G, "AC470_CONFIG"))
end

M.stats = {
  patched = 0,
  netBlocked = 0,
  tssBlocked = 0,
  replayBlocked = 0,
  bugglyBlocked = 0,
  exceptionBlocked = 0,
  crewPass = 0,
  gokubaBlocked = 0,
  notifyBlocked = 0,
  tlogBlocked = 0,
  dsRecordBlocked = 0,
  crashBlocked = 0,
  conflicts = 0,
  errors = 0,
}

-- ============================================================================
-- 2. Registry patch + restore
-- ============================================================================

local registry = {}
local byTarget = setmetatable({}, { __mode = "k" })
local loadPatch = nil

local function patchField(target, key, newFn, tag)
  if not isTable(target) or type(key) ~= "string" or not isFn(newFn) then
    return false
  end
  local old = target[key]
  local hadRaw = rawget(target, key) ~= nil
  if old == newFn then
    return true
  end
  local set = byTarget[target]
  if not set then
    set = {}
    byTarget[target] = set
  end
  local rec = set[key]
  if rec then
    rec.new = newFn
    rawset(target, key, newFn)
    return true
  end
  rec = { old = old, hadRaw = hadRaw, new = newFn, tag = tag or key }
  set[key] = rec
  registry[#registry + 1] = { target = target, key = key }
  rawset(target, key, newFn)
  M.stats.patched = M.stats.patched + 1
  if M.config.verbose then
    log("patch %s (%s)", key, tostring(tag or ""))
  end
  return true
end

local function restoreAll()
  local conflicts = 0
  for i = #registry, 1, -1 do
    local entry = registry[i]
    local set = byTarget[entry.target]
    local rec = set and set[entry.key]
    if rec then
      local current = rawget(entry.target, entry.key)
      if current == rec.new then
        if rec.hadRaw then
          rawset(entry.target, entry.key, rec.old)
        else
          rawset(entry.target, entry.key, nil)
        end
      else
        conflicts = conflicts + 1
      end
      set[entry.key] = nil
    end
  end
  registry = {}
  byTarget = setmetatable({}, { __mode = "k" })
  M.stats.conflicts = M.stats.conflicts + conflicts
  return conflicts
end

-- ============================================================================
-- 3. Loader guard: common/hook_lua_native_func.lua
-- ============================================================================

local function isValidLoad(fn)
  if not isFn(fn) then
    return false
  end
  local ok, chunk = pcall(fn, "return 470", "=ac470_probe", "bt", _G)
  if not ok or not isFn(chunk) then
    return false
  end
  local ok2, value = pcall(chunk)
  return ok2 and value == 470
end

local function findUpvalue(fn, validator)
  if not isFn(fn) or not debug or not debug.getupvalue then
    return nil
  end
  for i = 1, 64 do
    local name, value = debug.getupvalue(fn, i)
    if name == nil then
      break
    end
    if isFn(value) and value ~= fn and validator(value) then
      return value, name
    end
  end
  return nil
end

local function installLoader()
  local cfg = M.config.loader
  local n = 0

  if cfg.blockHookModule then
    local names = { "common.hook_lua_native_func", "hook_lua_native_func" }
    for i = 1, #names do
      if package.loaded[names[i]] == nil then
        package.loaded[names[i]] = true
        n = n + 1
      end
    end
  end

  local current = _G.load
  local native = M.nativeLoad
  if not isValidLoad(native) then
    native = nil
  end
  if not native and isValidLoad(current) then
    native = current
  end
  if not native and isFn(current) then
    native = findUpvalue(current, isValidLoad)
  end

  if isFn(native) then
    M.nativeLoad = native
    if cfg.restoreLoad and current ~= native then
      patchField(_G, "load", native, "loader.load")
      loadPatch = native
      n = n + 1
    end
  else
    M.errors[#M.errors + 1] = "loader: native load tidak ditemukan"
  end

  if cfg.restorePcall then
    local function restoreNamed(field, upName)
      local f = _G[field]
      if not isFn(f) or not debug or not debug.getupvalue then
        return false
      end
      for i = 1, 32 do
        local name, value = debug.getupvalue(f, i)
        if name == nil then
          break
        end
        if name == upName and isFn(value) then
          patchField(_G, field, value, "loader." .. field)
          return true
        end
      end
      return false
    end
    if restoreNamed("pcall", "OriginalPcall") then
      n = n + 1
    end
    if restoreNamed("xpcall", "OriginalXpcall") then
      n = n + 1
    end
  end

  return n
end

-- ============================================================================
-- 4. TSS transport
-- ============================================================================

local function tssTable()
  local t = rawget(_G, "Tss")
  if t == nil then
    t = rawget(_G, "TssManager")
  end
  return hostTable(t)
end

local function installTss()
  local cfg = M.config.tss
  local tss = tssTable()
  if not isTable(tss) then
    return 0
  end
  local n = 0

  if cfg.blockSend then
    for i = 1, #cfg.blockMethods do
      local name = cfg.blockMethods[i]
      if isFn(tss[name]) then
        patchField(tss, name, function()
          M.stats.tssBlocked = M.stats.tssBlocked + 1
          return true
        end, "tss." .. name)
        n = n + 1
      end
    end
    local netUtil = hostTable(rawget(_G, "NetUtil"))
    if isTable(netUtil) and isFn(netUtil.SendTss) then
      patchField(netUtil, "SendTss", function()
        M.stats.tssBlocked = M.stats.tssBlocked + 1
        return true
      end, "tss.SendTss")
      n = n + 1
    end
  end

  if cfg.blockRecv and isFn(tss.OnRecvData) then
    patchField(tss, "OnRecvData", function()
      return true
    end, "tss.OnRecvData")
    n = n + 1
  end

  if cfg.spoofUserTag and isFn(tss.GetUserTag4Lua) then
    patchField(tss, "GetUserTag4Lua", function()
      return M.config.tss.userTag
    end, "tss.GetUserTag4Lua")
    n = n + 1
  end

  if cfg.spoofDeviceFeature and isFn(tss.GetDeviceFeature) then
    patchField(tss, "GetDeviceFeature", function()
      return M.config.tss.deviceFeature
    end, "tss.GetDeviceFeature")
    n = n + 1
  end

  return n
end

-- ============================================================================
-- 5. Filter RPC / paket
-- ============================================================================

local function shouldBlockMessage(msgName, cfg)
  cfg = cfg or M.config.net
  if type(msgName) == "number" then
    local list = cfg.numericBlock
    if not isTable(list) then
      return false
    end
    if list["*"] == true or list[msgName] == true then
      return true
    end
    for _, v in pairs(list) do
      if v == msgName then
        return true
      end
    end
    return false
  end
  if type(msgName) ~= "string" then
    return false
  end
  if anyMatch(msgName, cfg.allow) then
    return false
  end
  if cfg.blockAllstarAuthRpc and globMatch(msgName, "battle_client_sync_allstar_auth_check_result_req") then
    return true
  end
  return anyMatch(msgName, cfg.block)
end

local function makeSendWrapper(original, tag)
  return function(msgName, ...)
    if shouldBlockMessage(msgName) then
      M.stats.netBlocked = M.stats.netBlocked + 1
      if M.config.verboseBlock then
        log("blokir %s (%s)", tostring(msgName), tag)
      end
      return false
    end
    return original(msgName, ...)
  end
end

local function installNet()
  local n = 0
  local netUtil = hostTable(rawget(_G, "NetUtil"))
  if isTable(netUtil) then
    local names = { "SendPkg", "SendPacket" }
    for i = 1, #names do
      local name = names[i]
      if isFn(netUtil[name]) then
        patchField(netUtil, name, makeSendWrapper(netUtil[name], "NetUtil." .. name), "net." .. name)
        n = n + 1
      end
    end
  end
  local netManager = hostTable(rawget(_G, "NetManager"))
  if isTable(netManager) and isFn(netManager.SendPkg) then
    patchField(netManager, "SendPkg", makeSendWrapper(netManager.SendPkg, "NetManager.SendPkg"), "net.NetManager.SendPkg")
    n = n + 1
  end
  return n
end

-- ============================================================================
-- 6. GameReport: GameReportUtils, GameReportSubsystem, BugglyReportRecord
-- ============================================================================

local function isReplayAllowed(ID)
  local allow = M.config.report.replayAllow
  if not isTable(allow) then
    return false
  end
  if allow["*"] == true then
    return true
  end
  if allow[ID] == true or allow[tostring(ID)] == true then
    return true
  end
  for _, v in pairs(allow) do
    if v == ID or v == tostring(ID) then
      return true
    end
  end
  return false
end

local function isBugglyAllowed(name)
  local allow = M.config.report.bugglyAllow
  if not isTable(allow) then
    return false
  end
  if allow["*"] == true then
    return true
  end
  if type(name) == "string" and (allow[name] == true or allow["*"] == true) then
    return true
  end
  for _, v in pairs(allow) do
    if v == name then
      return true
    end
  end
  return false
end

local function patchReportUtils(mod)
  if not isTable(mod) then
    return
  end

  local oldReplay = mod.ReplayReportData
  if isFn(oldReplay) then
    patchField(mod, "ReplayReportData", function(ID, Array)
      if M.config.report.blockReplay and not isReplayAllowed(ID) then
        M.stats.replayBlocked = M.stats.replayBlocked + 1
        return false
      end
      return oldReplay(ID, Array)
    end, "report.utils.ReplayReportData")
  end

  local oldReplayDS = mod.ReplayReportDataFromDS
  if isFn(oldReplayDS) then
    patchField(mod, "ReplayReportDataFromDS", function()
      return false
    end, "report.utils.ReplayReportDataFromDS")
  end

  local oldCheck = mod.CheckCanBugglyPostException
  if isFn(oldCheck) then
    patchField(mod, "CheckCanBugglyPostException", function(ReportName)
      if M.config.report.blockBuggly and not isBugglyAllowed(ReportName) then
        M.stats.bugglyBlocked = M.stats.bugglyBlocked + 1
        return false
      end
      return oldCheck(ReportName)
    end, "report.utils.CheckCanBugglyPostException")
  end

  local oldBuggly = mod.BugglyPostExceptionFull
  if isFn(oldBuggly) then
    patchField(mod, "BugglyPostExceptionFull", function(ReportName, ReportString, bPrintLog, ReportInfo)
      if M.config.report.blockBuggly and not isBugglyAllowed(ReportName) then
        M.stats.bugglyBlocked = M.stats.bugglyBlocked + 1
        return false
      end
      return oldBuggly(ReportName, ReportString, bPrintLog, ReportInfo)
    end, "report.utils.BugglyPostExceptionFull")
  end

  local oldException = mod.ReportException
  if isFn(oldException) then
    patchField(mod, "ReportException", function(ErrorMsg, Category)
      if M.config.report.blockException then
        M.stats.exceptionBlocked = M.stats.exceptionBlocked + 1
        return false
      end
      return oldException(ErrorMsg, Category)
    end, "report.utils.ReportException")
  end
end

local function patchReportSubsystem(cls)
  if not isTable(cls) then
    return
  end

  local oldReplay = cls.ReplayReportData
  if isFn(oldReplay) then
    patchField(cls, "ReplayReportData", function(self, ID, Array)
      if M.config.report.blockReplay and not isReplayAllowed(ID) then
        M.stats.replayBlocked = M.stats.replayBlocked + 1
        return false
      end
      return oldReplay(self, ID, Array)
    end, "report.subsystem.ReplayReportData")
  end

  local oldReplayDS = cls.ReplayReportDataFromDS
  if isFn(oldReplayDS) then
    patchField(cls, "ReplayReportDataFromDS", function()
      return false
    end, "report.subsystem.ReplayReportDataFromDS")
  end

  local oldCheck = cls.CheckCanBugglyPostException
  if isFn(oldCheck) then
    patchField(cls, "CheckCanBugglyPostException", function(self, ReportName)
      if M.config.report.blockBuggly and not isBugglyAllowed(ReportName) then
        M.stats.bugglyBlocked = M.stats.bugglyBlocked + 1
        return false
      end
      return oldCheck(self, ReportName)
    end, "report.subsystem.CheckCanBugglyPostException")
  end

  local oldBuggly = cls.BugglyPostExceptionFull
  if isFn(oldBuggly) then
    patchField(cls, "BugglyPostExceptionFull", function(self, ReportName, ReportString, bPrintLog, ReportInfo)
      if M.config.report.blockBuggly and not isBugglyAllowed(ReportName) then
        M.stats.bugglyBlocked = M.stats.bugglyBlocked + 1
        return false
      end
      return oldBuggly(self, ReportName, ReportString, bPrintLog, ReportInfo)
    end, "report.subsystem.BugglyPostExceptionFull")
  end

  local oldRecord = cls.GetBugglyReportRecord
  if M.config.report.blockSubsystemRecord and isFn(oldRecord) then
    patchField(cls, "GetBugglyReportRecord", function(self, ReportName)
      if M.config.report.blockBuggly and not isBugglyAllowed(ReportName) then
        return nil
      end
      return oldRecord(self, ReportName)
    end, "report.subsystem.GetBugglyReportRecord")
  end
end

local function patchBugglyRecord(cls)
  if not isTable(cls) then
    return
  end

  local oldCheck = cls.CheckCanBugglyPostException
  if isFn(oldCheck) then
    patchField(cls, "CheckCanBugglyPostException", function(self)
      local name = isTable(self) and self.ReportName or nil
      if M.config.report.blockBuggly and not isBugglyAllowed(name) then
        return false
      end
      return oldCheck(self)
    end, "buggly.CheckCanBugglyPostException")
  end

  local oldPost = cls.BugglyPostExceptionFull
  if isFn(oldPost) then
    patchField(cls, "BugglyPostExceptionFull", function(self, ReportString, bPrintLog, ReportInfo)
      local name = isTable(self) and self.ReportName or nil
      if M.config.report.blockBuggly and not isBugglyAllowed(name) then
        M.stats.bugglyBlocked = M.stats.bugglyBlocked + 1
        return false
      end
      return oldPost(self, ReportString, bPrintLog, ReportInfo)
    end, "buggly.BugglyPostExceptionFull")
  end
end

-- ============================================================================
-- 7. ReplayReportHandler + monitor gameplay
-- ============================================================================

local REPLAY_HANDLERS = {
  "OnReportUIState",
  "OnReceiveBattleResult",
  "OnUpdateBattleResultPeriod",
  "OnReportAvatarNetData",
  "OnReportControlRotationSuddenChange",
  "OnReportForbiddenMoveException",
  "OnReportParachuteAvgSpeed",
  "OnReportSpectatorScopeAvatarInconsistency",
  "OnReportNaNPositionEvent",
  "OnReportFPPAnimState",
  "OnReportAvatarMeshLoaded",
  "OnReportMiniMapIconJump",
}

local function patchReplayHandlers(cls)
  if not isTable(cls) then
    return
  end
  for i = 1, #REPLAY_HANDLERS do
    local name = REPLAY_HANDLERS[i]
    if isFn(cls[name]) then
      patchField(cls, name, function()
        return true
      end, "replay." .. name)
    end
  end
end

local function patchFPPAnim(cls)
  if not isTable(cls) then
    return
  end
  local names = { "TriggerReport", "ReportFPPAnimState" }
  for i = 1, #names do
    if isFn(cls[names[i]]) then
      patchField(cls, names[i], function()
        return false
      end, "fpp." .. names[i])
    end
  end
end

local function patchSpectatorScope(cls)
  if not isTable(cls) then
    return
  end
  local names = {
    "QueueSpectatorScopeAvatarCheck",
    "CheckSpectatorScopeAvatarInconsistency",
    "ReportSpectatorScopeAvatarInconsistency",
  }
  for i = 1, #names do
    if isFn(cls[names[i]]) then
      patchField(cls, names[i], function()
        return true
      end, "spectator." .. names[i])
    end
  end
end

local function patchCrashKit(cls)
  if not isTable(cls) then
    return
  end
  local names = {
    "OnControlRotationSuddenChangeToReplay",
    "ReportCharacterMoveableException",
    "ReportTeammateDisappear",
    "OnForbiddenMoveEventToReplay",
    "OnNaNPositionEventToReplay",
  }
  for i = 1, #names do
    if isFn(cls[names[i]]) then
      patchField(cls, names[i], function()
        return false
      end, "crashkit." .. names[i])
    end
  end
end

-- ============================================================================
-- 8. HiggsBoson
-- ============================================================================

local function installHiggs(cls)
  if not isTable(cls) then
    return
  end

  local methods = {
    "SendAntiDataFlow",
    "SendHitFireBtnFlow",
    "SendFingerTouchFlow",
    "OnBattleResult",
    "SendHisarData",
    "RPC_Server_TellServerName",
    "RPC_Client_ShowSecurityAlertWindow",
    "RPC_Client_ServerNameAck",
    "ShowABCD",
    "RecordStrategyTimestampInReplay",
  }
  for i = 1, #methods do
    local name = methods[i]
    if isFn(cls[name]) then
      patchField(cls, name, function()
        return false
      end, "higgs." .. name)
    end
  end
end

-- ============================================================================
-- 9. SoundMonitor + TLog
-- ============================================================================

local function installSound(cls)
  if not isTable(cls) then
    return
  end

  if M.config.sound.blockCollect and isFn(cls.OnCollectMonitorData) then
    patchField(cls, "OnCollectMonitorData", function(self)
      if isTable(self) then
        self.bHasSent = true
      end
    end, "sound.OnCollectMonitorData")
  end

  if isFn(cls.CheckAudioNumberAbnormal) then
    patchField(cls, "CheckAudioNumberAbnormal", function()
      return false
    end, "sound.CheckAudioNumberAbnormal")
  end

  if M.config.sound.blockTlog and isFn(cls.SendSoundMonitorTlog) then
    patchField(cls, "SendSoundMonitorTlog", function(self)
      if isTable(self) then
        self.bHasSent = true
      end
    end, "sound.SendSoundMonitorTlog")
  end
end

local function isBlockedLobbyFlow(flow)
  local list = M.config.tlog.blockLobbyFlows
  if not isTable(list) then
    return false
  end
  for i = 1, #list do
    if globMatch(flow, list[i]) then
      return true
    end
  end
  return false
end

local function isBlockedTlogEvent(tlogType)
  local defs = rawget(_G, "TLogEventDefine")
  local names = M.config.tlog.blockEventNames
  if not isTable(defs) or not isTable(names) then
    return false
  end
  for i = 1, #names do
    local name = names[i]
    if defs[name] ~= nil and defs[name] == tlogType then
      return true
    end
  end
  return false
end

local function patchTlogUtils(mod)
  if not isTable(mod) then
    return
  end
  local old = mod.ReportTLogEvent
  if not isFn(old) then
    return
  end
  patchField(mod, "ReportTLogEvent", function(...)
    local tlogType = ...
    if isBlockedTlogEvent(tlogType) then
      M.stats.tlogBlocked = M.stats.tlogBlocked + 1
      return false
    end
    return old(...)
  end, "tlog.ReportTLogEvent")
end

local function patchClientTlogHandler(mod)
  if not isTable(mod) then
    return
  end
  local old = mod.send_report_lobby_common_tlog
  if not isFn(old) then
    return
  end
  patchField(mod, "send_report_lobby_common_tlog", function(flow, ...)
    if isBlockedLobbyFlow(flow) then
      M.stats.tlogBlocked = M.stats.tlogBlocked + 1
      return false
    end
    return old(flow, ...)
  end, "tlog.send_report_lobby_common_tlog")
end

-- ============================================================================
-- 10. Crew safety detection
-- ============================================================================

local function crewPass(self)
  M.stats.crewPass = M.stats.crewPass + 1
  if isTable(self) and isFn(self.SendCheckResult) then
    local ok, err = pcall(self.SendCheckResult, self, M.config.crew.result)
    if not ok then
      addError("crew.SendCheckResult", err)
    end
  end
end

local function installCrewBase(cls)
  if not isTable(cls) then
    return
  end
  if not M.config.crew.autoPass then
    return
  end

  local names = { "PerformCheck", "PerformCheckWithObfuscation", "PerformCheckWithoutObfuscation" }
  for i = 1, #names do
    if isFn(cls[names[i]]) then
      patchField(cls, names[i], crewPass, "crew." .. names[i])
    end
  end

  if isFn(cls.StartCheckNilTimer) then
    patchField(cls, "StartCheckNilTimer", function()
      return false
    end, "crew.StartCheckNilTimer")
  end
end

local function patchCrewSubclass(cls)
  if not isTable(cls) then
    return
  end
  local names = { "PerformCheck", "PerformCheckWithObfuscation", "PerformCheckWithoutObfuscation", "StartCheckNilTimer" }
  for i = 1, #names do
    local name = names[i]
    if rawget(cls, name) ~= nil and isFn(cls[name]) then
      if name == "StartCheckNilTimer" then
        patchField(cls, name, function()
          return false
        end, "crewsub." .. name)
      else
        patchField(cls, name, crewPass, "crewsub." .. name)
      end
    end
  end
end

-- ============================================================================
-- 11. Gokuba, SecurityNotify, crash, DS monitor, ban
-- ============================================================================

local function installGokuba(mod)
  if not isTable(mod) then
    return
  end
  if isFn(mod.ForwardFeature) then
    patchField(mod, "ForwardFeature", function()
      M.stats.gokubaBlocked = M.stats.gokubaBlocked + 1
      return false
    end, "gokuba.ForwardFeature")
  end
end

local function installNotify(cls)
  if not isTable(cls) then
    return
  end
  local groups = {
    { enabled = M.config.notify.blockTips, methods = {
      "Notify", "ClientRPC_WeakTips", "ClientRPC_NormalTips", "ClientRPC_StrongTips",
    } },
    { enabled = M.config.notify.blockBanSync, methods = {
      "SyncBanInfo", "ClientRPC_SyncBanID",
    } },
  }
  for g = 1, #groups do
    local group = groups[g]
    if group.enabled then
      for i = 1, #group.methods do
        local name = group.methods[i]
        if isFn(cls[name]) then
          patchField(cls, name, function()
            M.stats.notifyBlocked = M.stats.notifyBlocked + 1
          end, "notify." .. name)
        end
      end
    end
  end
end

local function installClientTools(mod)
  if not isTable(mod) then
    return
  end
  if M.config.crash.blockClientToolsReport and isFn(mod.SendReport) then
    patchField(mod, "SendReport", function()
      M.stats.crashBlocked = M.stats.crashBlocked + 1
      return false
    end, "crash.ClientToolsReport.SendReport")
  end
end

local function installClientErrorReport(mod)
  if not isTable(mod) then
    return
  end
  if M.config.crash.blockClientToolsReport and isFn(mod.send_client_tools_batch_report_req) then
    patchField(mod, "send_client_tools_batch_report_req", function()
      M.stats.crashBlocked = M.stats.crashBlocked + 1
      return false
    end, "crash.ClientErrorReportHandler")
  end
end

local function installNativeCrash()
  local client = hostTable(rawget(_G, "Client"))
  if not isTable(client) then
    return 0
  end
  local n = 0
  local names = { "CrashPostExceptionFull", "CrashPostException" }
  for i = 1, #names do
    local name = names[i]
    if isFn(client[name]) then
      patchField(client, name, function()
        M.stats.crashBlocked = M.stats.crashBlocked + 1
        return false
      end, "crash.Client." .. name)
      n = n + 1
    end
  end
  return n
end

local function installDsMonitor(mod)
  if not isTable(mod) or not M.config.dsMonitor.blockRecord then
    return
  end
  if isFn(mod.NewRecord) then
    patchField(mod, "NewRecord", function()
      M.stats.dsRecordBlocked = M.stats.dsRecordBlocked + 1
      return false
    end, "dsmonitor.NewRecord")
  end
  if isFn(mod.OnRecordMsg) then
    patchField(mod, "OnRecordMsg", function()
      return false
    end, "dsmonitor.OnRecordMsg")
  end
  if isFn(mod.SetClientMonitor) then
    patchField(mod, "SetClientMonitor", function(self)
      if isTable(self) then
        self.bOpenClientMonitor = false
      end
    end, "dsmonitor.SetClientMonitor")
  end
end

local function installBan(mod)
  if not isTable(mod) then
    return
  end
  if M.config.ban.hideIdipTips and isFn(mod.ShowIDIPBanTips) then
    patchField(mod, "ShowIDIPBanTips", function()
      return false
    end, "ban.ShowIDIPBanTips")
  end
end

-- ============================================================================
-- 12. Watch module / require hook
-- ============================================================================

local installed = {}
local WATCH_LAYER = {}

local function applyWatch(name, mod)
  local installer = M._watch[name]
  if not installer or installed[name] == mod then
    return false
  end
  local layer = WATCH_LAYER[name]
  if layer ~= nil and M.config.layers[layer] == false then
    return false
  end
  local ok, err = pcall(installer, mod)
  if not ok then
    addError("install:" .. name, err)
    return false
  end
  installed[name] = mod
  return true
end

local function watch(names, installer, layer)
  if type(names) == "string" then
    names = { names }
  end
  for i = 1, #names do
    M._watch[names[i]] = installer
    WATCH_LAYER[names[i]] = layer
  end
end

local RAW_REQUIRE = require
local requireWrapper = nil
local installRuntime

local function installRequireHook()
  if requireWrapper and rawget(_G, "require") == requireWrapper then
    return
  end
  RAW_REQUIRE = rawget(_G, "require")
  if not isFn(RAW_REQUIRE) then
    return
  end
  requireWrapper = function(name, ...)
    local a, b, c = RAW_REQUIRE(name, ...)
    if M.started and type(name) == "string" then
      applyWatch(name, a)
      local ok, err = pcall(installRuntime)
      if not ok then
        addError("runtime", err)
      end
    end
    return a, b, c
  end
  _G.require = requireWrapper
end

local function removeRequireHook()
  if requireWrapper and rawget(_G, "require") == requireWrapper then
    _G.require = RAW_REQUIRE
  end
  requireWrapper = nil
end

function M.rescan()
  if not M.started then
    return 0
  end
  local n = 0
  for name in pairs(M._watch) do
    local mod = package.loaded[name]
    if mod ~= nil and mod ~= true then
      if applyWatch(name, mod) then
        n = n + 1
      end
    end
  end
  return n
end

-- ============================================================================
-- 13. Registrasi modul
-- ============================================================================

watch({
  "GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils",
}, patchReportUtils, "report")

watch({
  "GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportSubsystem",
}, patchReportSubsystem, "report")

watch({
  "GameLua.Mod.BaseMod.Client.BugglyReport.BugglyReportRecord",
}, patchBugglyRecord, "report")

watch({
  "GameLua.Mod.BaseMod.Client.Replay.ReplayReportHandler",
}, patchReplayHandlers, "replayHandlers")

watch({
  "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature",
  "GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature_Test",
}, patchFPPAnim, "gameplayMonitors")

watch({
  "GameLua.Mod.BaseMod.GamePlay.Weapon.Monitor.SpectatorScopeAvatarMonitor",
}, patchSpectatorScope, "gameplayMonitors")

watch({
  "GameLua.Mod.BaseMod.GamePlay.Feature.Player.ReportCrashKitFeature",
}, patchCrashKit, "gameplayMonitors")

watch({
  "GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent",
}, installHiggs, "higgs")

watch({
  "GameLua.Mod.BaseMod.Client.SoundMonitorSubsystem",
}, installSound, "sound")

watch({
  "client.slua.umg.crew.crew_safety_detection_base",
}, installCrewBase, "crew")

watch({
  "client.slua.umg.crew.crew_safety_detection_allstar",
  "client.slua.umg.crew.crew_safety_detection_peak",
  "client.slua.umg.crew.crew_safety_detection_pug",
  "client.slua.umg.crew.crew_safety_detection_tournament",
  "client.slua.umg.crew.crew_safety_detection_nationesport",
}, patchCrewSubclass, "crew")

watch({
  "GameLua.Mod.BaseMod.Client.Security.Gokuba",
}, installGokuba, "gokuba")

watch({
  "GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature",
}, installNotify, "notify")

watch({
  "client.slua.logic.report.ClientToolsReport",
}, installClientTools, "crash")

watch({
  "client.slua.config.tlog.tlog_report_utils",
}, patchTlogUtils, "tlog")

watch({
  "client.network.Protocol.ClientErrorReportHandler",
}, installClientErrorReport, "crash")

watch({
  "client.network.Protocol.ClientTlogHandler",
}, patchClientTlogHandler, "tlog")

watch({
  "client.logic.data.logic_ds_monitor",
}, installDsMonitor, "dsMonitor")

watch({
  "client.slua.logic.login.ban_login_module",
}, installBan, "ban")

-- ============================================================================
-- 14. Cakupan (dipakai README / status)
-- ============================================================================

M.coverage = {
  { layer = "loader", file = "common/hook_lua_native_func.lua", hook = "load / pcall / xpcall" },
  { layer = "tss", file = "client/client_entry.lua", hook = "Tss.SendSkdData, Tss.GetUserTag4Lua, Tss.GetDeviceFeature" },
  { layer = "net", file = "client/client_entry.lua", hook = "NetUtil.SendPkg / SendPacket" },
  { layer = "report", file = "GameReport/GameReportUtils.lua", hook = "ReplayReportData, BugglyPostExceptionFull, ReportException" },
  { layer = "report", file = "GameReport/GameReportSubsystem.lua", hook = "ReplayReportData, ReplayReportDataFromDS, GetBugglyReportRecord" },
  { layer = "report", file = "BugglyReport/BugglyReportRecord.lua", hook = "BugglyPostExceptionFull, CheckCanBugglyPostException" },
  { layer = "replayHandlers", file = "Replay/ReplayReportHandler.lua", hook = "12 handler replay ID 1-12" },
  { layer = "gameplayMonitors", file = "Feature/Player/FPPAnimMonitorFeature.lua", hook = "TriggerReport, ReportFPPAnimState" },
  { layer = "gameplayMonitors", file = "Weapon/Monitor/SpectatorScopeAvatarMonitor.lua", hook = "Check/Report SpectatorScope + RPC alarm" },
  { layer = "gameplayMonitors", file = "Feature/Player/ReportCrashKitFeature.lua", hook = "5 reporter replay" },
  { layer = "higgs", file = "Common/Security/HiggsBosonComponent.lua", hook = "SendAntiDataFlow, ntf2-5, hisar, RPC alert" },
  { layer = "sound", file = "Client/SoundMonitorSubsystem.lua", hook = "OnCollectMonitorData, CheckAudioNumberAbnormal, TLog" },
  { layer = "crew", file = "client/slua/umg/crew/crew_safety_detection_*.lua", hook = "PerformCheck -> SendCheckResult(0)" },
  { layer = "gokuba", file = "Client/Security/Gokuba.lua", hook = "ForwardFeature" },
  { layer = "notify", file = "Common/Security/SecurityNotifyPCFeature.lua", hook = "Notify, SyncBanInfo, 4 ClientRPC" },
  { layer = "crash", file = "client/slua/logic/report/ClientToolsReport.lua", hook = "SendReport" },
  { layer = "crash", file = "client/network/Protocol/ClientErrorReportHandler.lua", hook = "send_client_tools_batch_report_req" },
  { layer = "tlog", file = "client/slua/config/tlog/tlog_report_utils.lua", hook = "ReportTLogEvent" },
  { layer = "tlog", file = "client/network/Protocol/ClientTlogHandler.lua", hook = "send_report_lobby_common_tlog" },
  { layer = "dsMonitor", file = "client/logic/data/logic_ds_monitor.lua", hook = "NewRecord, OnRecordMsg, SetClientMonitor" },
  { layer = "ban", file = "client/slua/logic/login/ban_login_module.lua", hook = "ShowIDIPBanTips (opsional)" },
}

-- ============================================================================
-- 15. Start / stop / status
-- ============================================================================

local runtime = { tss = false, net = false, nativeCrash = false }

function installRuntime()
  local n = 0
  if M.config.layers.tss ~= false and not runtime.tss and tssTable() then
    local c = installTss()
    if c > 0 then
      runtime.tss = true
      n = n + c
    end
  end
  if M.config.layers.net ~= false and not runtime.net and hostTable(rawget(_G, "NetUtil")) then
    local c = installNet()
    if c > 0 then
      runtime.net = true
      n = n + c
    end
  end
  if M.config.layers.crash ~= false and M.config.crash.blockNativeCrash
    and not runtime.nativeCrash and hostTable(rawget(_G, "Client")) then
    local c = installNativeCrash()
    if c > 0 then
      runtime.nativeCrash = true
      n = n + c
    end
  end
  return n
end

M.installRuntime = installRuntime

local LAYERS = {
  { "loader", installLoader },
  { "report", function()
      patchReportUtils(package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"])
    end },
  { "replayHandlers", function()
      patchReplayHandlers(package.loaded["GameLua.Mod.BaseMod.Client.Replay.ReplayReportHandler"])
    end },
  { "gameplayMonitors", function()
      patchFPPAnim(package.loaded["GameLua.Mod.BaseMod.GamePlay.Feature.Player.FPPAnimMonitorFeature"])
      patchSpectatorScope(package.loaded["GameLua.Mod.BaseMod.GamePlay.Weapon.Monitor.SpectatorScopeAvatarMonitor"])
      patchCrashKit(package.loaded["GameLua.Mod.BaseMod.GamePlay.Feature.Player.ReportCrashKitFeature"])
    end },
  { "higgs", function()
      installHiggs(package.loaded["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"])
    end },
  { "sound", function()
      installSound(package.loaded["GameLua.Mod.BaseMod.Client.SoundMonitorSubsystem"])
    end },
  { "crew", function()
      installCrewBase(package.loaded["client.slua.umg.crew.crew_safety_detection_base"])
    end },
  { "gokuba", function()
      installGokuba(package.loaded["GameLua.Mod.BaseMod.Client.Security.Gokuba"])
    end },
  { "notify", function()
      installNotify(package.loaded["GameLua.Mod.BaseMod.Common.Security.SecurityNotifyPCFeature"])
    end },
  { "crash", function()
      installClientTools(package.loaded["client.slua.logic.report.ClientToolsReport"])
    end },
  { "tlog", function()
      patchTlogUtils(package.loaded["client.slua.config.tlog.tlog_report_utils"])
      patchClientTlogHandler(package.loaded["client.network.Protocol.ClientTlogHandler"])
    end },
  { "dsMonitor", function()
      installDsMonitor(package.loaded["client.logic.data.logic_ds_monitor"])
    end },
  { "ban", function()
      installBan(package.loaded["client.slua.logic.login.ban_login_module"])
    end },
}

local function resetStats()
  for k in pairs(M.stats) do
    M.stats[k] = 0
  end
end

function M.start(opts)
  if isTable(opts) then
    merge(M.config, opts)
  end
  if M.started then
    installRuntime()
    M.rescan()
    return true
  end

  M.started = true
  M.errors = {}
  installed = {}
  resetStats()

  installRequireHook()

  for i = 1, #LAYERS do
    local layer = LAYERS[i]
    if M.config.layers[layer[1]] ~= false then
      safeCall("layer:" .. layer[1], layer[2])
    end
  end

  installRuntime()
  M.rescan()

  if M.config.verbose then
    local watched = 0
    for _ in pairs(M._watch) do
      watched = watched + 1
    end
    log("start v%s — %d patch, %d modul dipantau, %d error",
      VERSION, M.stats.patched, watched, #M.errors)
  end
  return true
end

function M.stop()
  if not M.started then
    return true
  end
  local conflicts = restoreAll()
  removeRequireHook()
  runtime.tss = false
  runtime.net = false
  runtime.nativeCrash = false
  installed = {}
  M.started = false
  if M.config.verbose then
    log("stop — %d konflik", conflicts)
  end
  return true
end

function M.restart(opts)
  M.stop()
  return M.start(opts)
end

function M.status()
  local watched = 0
  for _ in pairs(M._watch) do
    watched = watched + 1
  end
  local stats = {}
  for k, v in pairs(M.stats) do
    stats[k] = v
  end
  return {
    id = MODULE_ID,
    version = VERSION,
    started = M.started,
    nativeLoad = M.nativeLoad ~= nil,
    watched = watched,
    errors = #M.errors,
    stats = stats,
  }
end

if M.config.autoStart then
  M.start()
end

return M
