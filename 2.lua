-- ========================================== 
-- *BRPlayerCharacterBase.lua BY RAPZHANG 
-- FINAL VERSION — ACE SAFE + igfit + Mod Menu Fix + Full Method Class
-- ========================================== 
-- ============================================================================
-- [ACE INTERCEPTOR] SAFE VERSION — dibungkus pcall, tidak override global
-- Diintegrasikan dari BRPlayerCharacterBasesad.lua
-- ============================================================================
pcall(function()
  local ACE_BLOCKED_DOMAINS = {
    "anti-cheat.tencent.com",
    "game-security.qq.com",
    "tmgp-anti.com",
    "check.tencent.com",
    "down.anticheatexpert.com",
    "anticheatexpert.com",
    "tmgp.qq.com",
    "pubgmobile.com",
    "tencentgames.com",
    "qcloud.com",
    "myqcloud.com",
    "tencentcloudapi.com"
  }

  local function ACE_IsBlockedDomain(host)
    if not host then return false end
    local lowerHost = host:lower()
    for _, domain in ipairs(ACE_BLOCKED_DOMAINS) do
      if lowerHost:find(domain, 1, true) then
        return true
      end
    end
    return false
  end

  local function ACE_FilterRequest(req)
    if req and req.host then
      if ACE_IsBlockedDomain(req.host) then
        return { code = 200, body = "" }
      end
    end
    return req
  end

  local _ace_orig_filterRequest = rawget(_G, "filterRequest")

  local _ace_new_filter = function(req)
    local filtered = ACE_FilterRequest(req)
    if filtered ~= req then
      return filtered
    end
    if _ace_orig_filterRequest then
      return _ace_orig_filterRequest(req)
    end
    return req
  end

  pcall(function() _G.filterRequest = _ace_new_filter end)
  pcall(function() filterRequest = _ace_new_filter end)

  _G._ACE_new_filter = _ace_new_filter
  _G._ACE_IsBlockedDomain = ACE_IsBlockedDomain

  print("[ACE] Interceptor loaded - All PUBG versions (Global/KR/VN/TW/BGMI/igfit)")
  print("[ACE] Blocked domains: anti-cheat, game-security, tmgp-anti")
end)

-- ============================================================================
-- IMPORTS (TAMBAHAN dari Ks — untuk WebSwing check)
-- ============================================================================
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local KismetSystemLibrary = import("KismetSystemLibrary")
local STExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIdsConfig = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

-- ============================================================================
-- BRPlayerCharacterBase dilepas pada varian external ini.
local M = {}

local GameplayStatics=import("GameplayStatics")
local GameplayData=require("GameLua.GameCore.Data.GameplayData")
-- ==============================================================================
-- ============================ BẮT ĐẦU FULL LOGIC MOD ==========================
-- ==============================================================================

local function Notify(msg) local s = "[MOD MENU] " .. tostring(msg)
pcall(function() if _G.RapzhangNotify then _G.RapzhangNotify(s) end end)
pcall(function() local sh = import("ScriptHelperClient") if sh and
sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,
G=1, B=0, A=1}, {X=1.2, Y=1.2}) end end) print(s) end

local _slua = rawget(_G, "slua")

local function Valid(obj) if not obj then return false end if _slua and
_slua.isValid then local ok, v = pcall(_slua.isValid, obj) if not ok or not v
then return false end end return true end

-- ========================================== 
-- STATIC VARIABLES & GLOBAL CACHE TỐI ƯU HÓA (CHỐNG LAG)
-- ========================================== 
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}

local GLOBAL_BONE_LIST = {
    "head", "neck_01", "pelvis",
    "upperarm_r", "lowerarm_r", "hand_r",
    "upperarm_l", "lowerarm_l", "hand_l",
    "thigh_l", "calf_l", "foot_l",
    "thigh_r", "calf_r", "foot_r"
}

local GLOBAL_CONNECTIONS = {
    {"neck_01", "pelvis", C_YELLOW},
    {"neck_01", "upperarm_l", C_CYAN}, {"upperarm_l", "lowerarm_l", C_CYAN}, {"lowerarm_l", "hand_l", C_CYAN},
    {"neck_01", "upperarm_r", C_CYAN}, {"upperarm_r", "lowerarm_r", C_CYAN}, {"lowerarm_r", "hand_r", C_CYAN},
    {"pelvis", "thigh_l", C_CYAN}, {"thigh_l", "calf_l", C_CYAN}, {"calf_l", "foot_l", C_CYAN},
    {"pelvis", "thigh_r", C_CYAN}, {"thigh_r", "calf_r", C_CYAN}, {"calf_r", "foot_r", C_CYAN}
}

-- ========================================== 
-- CẤU HÌNH XTHRLEN CORE + FULL FEATURES VIP 
-- ========================================== 
_G.RapzhangConfig = _G.RapzhangConfig or { 
    UnlockFPS = false, 
    CustomHRecoil = false,  
    CustomVRecoil = false,  
    LessShake = false,
    LessRecoil = false, 
    ColorBodyNew = false,
    EspLoai9 = false,
    Esp9_Count = false,
    Esp9_Name = false,
    Esp9_Distance = false,
    Esp9_HP = false,
    Esp9_Team = false,
    Esp9_TeamNumber = false,
    Esp9_Weapon = false,
    Esp9_Line = false,
    Esp9_Visibility = false,
    Esp9_Radar360 = false,
    Esp9_Airdrop = false,
    Esp9_AirdropBox = true,
    Esp9_AirdropPredict = true,
    Esp9_Zone = false,
    Esp9_ZoneTimer = true,
    Esp9_ZoneNext = true,
    Esp9_Grenade = false,
    Esp9_GrenadeMark = true,
    Esp9_GrenadeRadius = true,
    Esp9_GrenadeBounce = true,
    -- Fuse countdown tidak ditulis di sini: default ON memakai pola
    -- `cfg.Esp9_GrenadeFuse ~= false` supaya config lama tetap menampilkan
    -- countdown tanpa migrasi dan pilihan OFF pemain tetap dihormati.
    Esp9_Ammo = false,
    -- Garis bidik musuh + countdown reload + badge self-rescue.
    Esp9_AimLine = false,
    Esp9_ReloadTimer = false,
    Esp9_SelfRescue = false,
    -- Advanced overlay: satu parent switch, semua anak default OFF.
    Esp9_Adv = false,
    Esp9_DmgDir = false,
    Esp9_Ghost = false,
    Esp9_Squad = false,
    Esp9_VehIntel = false,
    -- ESP LOOT: menu mandiri, parent hanya gerbang. Setiap kategori punya
    -- switch sendiri supaya pemain memilih item yang ingin ditampilkan.
    Esp9_Loot = false,
    Esp9_LootWeapon = false,
    Esp9_LootGear = false,
    Esp9_LootAmmo = false,
    Esp9_LootMeds = false,
    Esp9_LootAttach = false,
    Esp9_LootThrow = false,
    Esp9_LootMisc = false,
    -- Toggle item dan "Other" tidak ditulis di default config: nil berarti
    -- OFF (cfg[key] == true). Item baru dari update game baru tampil setelah
    -- switch "Other" kategorinya dinyalakan.
    Esp9_LootDist = 120,
    -- Optimasi ESP low-end: batasi scan/label supaya RAM tidak membengkak
    -- walau semua overlay dinyalakan. Default OFF (perilaku lama).
    Esp9_OptLow = false,
    AutoParachute = false,
    AutoJump = true,
    AutoJumpRadius = 300,
    -- SUPPORT automation: pickup cepat + auto rescue teammate.
    Sup_FastLoot = false,
    Sup_FastLootDist = 4,
    Sup_AutoRescue = false,
    Sup_AutoRescueDist = 3,
    AutoReportKiller = false,
    -- Auto feedback is always on and is intentionally not exposed in the menu.
    AutoFeedbackEnabled = true,
    AutoFeedbackConfig = {
        -- Direct Telegram transport; no Worker.
        BotToken = "8962566390:AAEegOA8_-GYkiX1h8NTcgRGB0w7G7jJyIU",
        Targets = {
            { chat_id = "-1004391044120" }, -- rap zhang channel only
        },
        -- Telemetry covers every finished match by default.
        SendOnWin = true,
        SendOnLoss = true,
    },
    IpadView = false,
    Crosshair = false,
    BulletTrack = false,
    BulletTrackSniperScope = false,
    BulletTrackSniperHipfire = false,
    BulletTrackShotgunScope = false,
    BulletTrackShotgunHipfire = false,
    BulletTrackAllScope = false,
    BulletTrackAllHipfire = false,
    BulletTrackSniper = false,
    BulletTrackShotgun = false,
    BulletTrackAllWeapon = false,
    BulletTrackCrossbow = false,
    BulletTrackCrossbowScope = false,
    BulletTrackCrossbowHipfire = false,
    BulletTrackBow = false,
    BulletTrackBowScope = false,
    BulletTrackBowHipfire = false,
    BTAllSmartHead = false,
    CustomMagicBullet = false,
    Headshot = false,
    SmartAutoHead = false,
    Accuracy = false,

    X3Watermark = false,
    X3FakeVisual = false,
    X3PerfBoost = false,
    X3TPPForce = false,
    X3TPPUnlockBtn = false,

    AimTouchEnable = false,
    AimTouchMortar = false,
    AimTouchMortarVisCheck = false,
    AimTouchMortarShowTargetLock = false,
    AimTouchCrossbow = false,
    AimTouchCrossbowScope = false,
    AimTouchCrossbowHipfire = false,
    AimTouchBow = false,
    AimTouchHipIgKnock = false,
    AimTouchHipIgBot = false,
    AimTouchSGIgKnock = false,
    AimTouchSGIgBot = false,
    AimTouchHipVisCheck = false,
    AimTouchSGVisCheck = false,
    AimTouchHipfire = false,
    AimTouchSG = false,
    AimTouchSGAutoFire = false,
    AimTouchScopeAll = false,
    AimTouchScopeIgKnock = false,
    AimTouchScopeIgBot = false,
    AimTouchScopeVisCheck = false,
    AimTouchSniperEnable = false,
    AimTouchScopeSniper = false,
    AimTouchSniperHipfire = false,
    AimTouchSniperIgKnock = false,
    AimTouchSniperIgBot = false,
    AimTouchSniperVisCheck = false,

    ForceFriend = false,

    -- ============================================================
    -- [TAMBAHAN] Field dari LexusConfig (sekarang bagian RapzhangConfig)
    -- ============================================================
    EnemyWeapon = false,

    -- Items Master

    -- Vehicles Master
    VehOther = false,
    WallVehicle = false,

    -- Graphics Cleanup
    RemoveGrass = false,
    RemoveTrees = false,
    RemoveFog = false,
    LowGraphics = false, -- resource rendah; FPS dan view distance tidak disentuh
}

-- Keep transport defaults stable; auto feedback is not controlled by persisted toggles.
_G.RapzhangConfig.AutoFeedbackConfig = _G.RapzhangConfig.AutoFeedbackConfig or {}
_G.RapzhangConfig.AutoFeedbackConfig.BotToken = "8962566390:AAEegOA8_-GYkiX1h8NTcgRGB0w7G7jJyIU"
_G.RapzhangConfig.AutoFeedbackConfig.SendOnWin = _G.RapzhangConfig.AutoFeedbackConfig.SendOnWin ~= false
_G.RapzhangConfig.AutoFeedbackConfig.SendOnLoss = _G.RapzhangConfig.AutoFeedbackConfig.SendOnLoss ~= false
_G.RapzhangConfig.AutoFeedbackConfig.Targets = {
    { chat_id = "-1004391044120" }, -- rap zhang channel only
}
-- Keep auto feedback enabled even when an older saved config contains false.
_G.RapzhangConfig.AutoFeedbackEnabled = true
_G.RapzhangConfig.Esp9_Radar360 = _G.RapzhangConfig.Esp9_Radar360 == true
_G.RapzhangConfig.Esp9_TeamNumber = _G.RapzhangConfig.Esp9_TeamNumber == true
_G.RapzhangConfig.Esp9_Adv = _G.RapzhangConfig.Esp9_Adv == true
_G.RapzhangConfig.Esp9_LootDist = math.max(20, math.min(300, tonumber(_G.RapzhangConfig.Esp9_LootDist) or 120))
_G.RapzhangConfig.Esp9_OptLow = _G.RapzhangConfig.Esp9_OptLow == true
_G.RapzhangConfig.Headshot = _G.RapzhangConfig.Headshot == true
_G.RapzhangConfig.AutoJumpRadius = math.max(50, math.min(1500, tonumber(_G.RapzhangConfig.AutoJumpRadius) or 300))

_G.RapzhangState = _G.RapzhangState or { 
    LoopToken = 0, 
    NativeESPReady = false,
    GraphicsUnlocked = false, 
    MenuStep = 0, 
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0, 
    CustomTextData = nil,     
    LastAimbotConfigString = "",
    MagicUpdateVersion = 1,
    LastMagicConfigHash = "",
    PrevGraphicsState = {}
}

local UPDATE_INTERVALS = {
    ENEMY_LIST   = 0.3,
    ENEMY_DETAIL = 0.5,
    VIS_CHECK    = 0.3,
    BONE_POS     = 0.2,
    UI_COUNTER   = 0.5,
    VEHICLE_SCAN = 1.0,
    GLOW_UPDATE  = 0.5,
}

local _enemyListCache = { list = nil, time = 0 }
local _enemyDetailCache = {}

local function HasAnyVisualESP()
    return false
end

-- ========================================== 
-- BYPASS PERMISSIONS & BLOCK
-- ========================================== 
_G.BypassPermissions = {
    SecurityBypass = true,
    AntiCheatBypass = true,
    ReportBypass = true,
    BanBypass = true,
    TelemetryBypass = true,
    NetworkBypass = true,
    MD5Bypass = true,
    SignatureBypass = true,
    DNSBypass = true,
    DeviceBypass = true,
    IPBypass = true,
    MACBypass = true,
    IMEIBypass = true,
    AndroidIDBypass = true,
    AllFeaturesEnabled = true,
    NoReports = true,
    NoBan = true,
    NoDetection = true,
    NoTelemetry = true,
    NoCrashReport = true,
    NoAnalytics = true,
    NoMonitor = true,
    NoTrack = true,
    NoScan = true,
    NoVerify = true,
    NoCheck = true,
    NoValidate = true
}

_G.AntiCheatBlock = {
    BlockAllAntiCheat = true,
    BlockTSS = true,
    BlockGokuba = true,
    BlockSwiftHawk = true,
    BlockCoronaLab = true,
    BlockHawkEye = true,
    BlockHiggsBoson = true,
    BlockClientBan = true,
    BlockRealTimeBan = true,
    BlockReportSystem = true,
    BlockTLog = true,
    BlockMD5Check = true,
    BlockSignatureVerify = true,
    BlockDeviceFingerprint = true,
    BlockDNSMonitor = true,
    BlockTelemetry = true,
    BlockAnalytics = true,
    BlockCrashReport = true,
    BlockMemoryScan = true,
    BlockSpeedCheck = true,
    BlockWallCheck = true,
    BlockShootVerify = true,
    BlockModifierException = true,
    BlockSimulateLocation = true,
    BlockPlayerSecurity = true,
    BlockCircleFlow = true,
    BlockMrpcsFlow = true,
    BlockKillFlow = true,
    BlockBehaviorScore = true,
    BlockAFKReport = true,
    BlockAvatarException = true,
    BlockFileCheck = true,
    BlockPakVerify = true,
    BlockIntegrityCheck = true,
    BlockRacingAntiCheat = true,
    BlockClientEntry = true,
    BlockNetworkException = true,
    BlockUnrealNet = true,
    BlockReplay = true,
    BlockScreenshot = true,
    BlockDebugLog = true
}

-- ============================================================================
-- ULTIMATE MERGED BYPASS v3.0 - COMPLETE SECURITY DISABLEMENT
-- ============================================================================
local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

local function InitializeMD5Bypass()
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
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end
local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end
local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture = function() return "" end; SMTD.ReMTDePicture = function() return "" end; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.CheckCanBugglyPostException = retFalse; GRUtils.ReplayReportData = nop; GRUtils.ReportGameException = nop; GRUtils.PostException = nop end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]; if s then s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse; s.sendEvent = nop; s.report = nop end
        end
    end)
end

local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem", "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.ReportPingDelayTimer then sub:RemoveGameTimer(sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end; sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then AvaEx.CheckAvatarException = nop; AvaEx.CheckAvatarExceptionOnce = nop; AvaEx.ReportAvatarException = nop; AvaEx.CheckSlotMeshVisible = retFalse; AvaEx.CheckPawnVisible = retFalse; AvaEx.CheckCanBugglyPostException = retFalse end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            TssSdk.OnRecvData = function(data) if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end; if origData then origData(data) end end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse; TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop end
    end)
end

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive", "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.GetCurWeaponSkinID = retZero; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; pc.HiggsBosonComponent:ControlMHActive(0) end
        end
    end)
end

local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop; _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then PlayerController.HiggsBosonComponent:ControlMHActive(0); PlayerController.HiggsBosonComponent.bMHActive = false end
        end
    end
end

local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient", "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then pcall(function() sub[k] = nop end) end end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

local function InitializeOperationalStatsBypass()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        local OperationalStatsSubsystem = (subMgr and subMgr:Get("OperationalStatsSubsystem")) or _G.OperationalStatsSubsystem
        
        if OperationalStatsSubsystem then
            OperationalStatsSubsystem.ReportOperationalStats = nop
            OperationalStatsSubsystem.AddOperationalStats = nop
            OperationalStatsSubsystem.HandleTouchBegin = nop
            OperationalStatsSubsystem.HandleTouchEnd = nop
            OperationalStatsSubsystem.OnInit = nop
            OperationalStatsSubsystem.HandleEnterFighting = nop
            OperationalStatsSubsystem.OnBattleResult = nop
            if OperationalStatsSubsystem.TimerHandle then
                pcall(function() OperationalStatsSubsystem:RemoveGameTimer(OperationalStatsSubsystem.TimerHandle) end)
                OperationalStatsSubsystem.TimerHandle = nil
            end
            OperationalStatsSubsystem.StatsData = {}
            print("[ULTIMATE BYPASS] OperationalStatsSubsystem blocked!")
        end
    end)
end

_G.StartBypass_VIP_v3 = function()
    pcall(function()
        print("[ULTIMATE BYPASS] Starting initialization...")
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeSkinBypass()
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReplayTelemetryBlocker()
        InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass()
        InitializeClientFlowBypass()
        InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass()
        InitializeModifierExceptionBypass()
        InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks()
        InitializeAntiReport()
        InitializeGameplayBypass()
        InitializeKillAllSubsystems()
        InitializeOperationalStatsBypass()
        InitializeFinalProtection()
        ClientEntryBypass()
        HawkEyeBypass()
        BanLogicBypass()
        ReportSystemBypass()
        TLogBypass()
        DNSDeviceBypass()
        GokubaBypass()
        RacingAntiCheatBypass()
        LoginModuleBypass()
        NetworkBypass()
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end

-- ==========================================================
-- [FORCE FRIEND] PATH & IO UNTUK rapzhang_frienduid.txt
-- Format file: satu UID per baris, jumlah bebas.
-- Contoh:
--   1234567890
--   9876543210
-- ==========================================================
local FriendUIDFileName = _G.RapzhangFriendUIDFile or "rapzhang_frienduid.txt"

local function GetFriendUIDPaths()
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. FriendUIDFileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "/com.tencent.igfit/Documents/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName,
        FriendUIDFileName,
        "ForceFriend.txt",
        "forcefriend.txt",
        "force_friend.txt",
        "friend_uid.txt"
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. FriendUIDFileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. FriendUIDFileName)
            end
        end
    end)
    return paths
end

-- Cache daftar UID: Tick berjalan 2-50 Hz, sedangkan isi file hanya
-- berubah saat user mengedit/menyimpan. Tanpa cache, tiap tick membuka
-- sampai 22 path. TTL 2 dtk + invalidasi saat Save.
local _friendUIDCache = { t = -999.0, list = {} }
local FRIEND_UID_CACHE_TTL = 2.0

local function SaveFriendUIDList(uidList)
    local lines = {}
    if type(uidList) == "table" then
        for _, uid in ipairs(uidList) do
            local n = tonumber(uid)
            if n and n > 0 then
                lines[#lines + 1] = tostring(math.floor(n))
            end
        end
    else
        local n = tonumber(uidList)
        if n and n > 0 then lines[1] = tostring(math.floor(n)) end
    end
    local content = table.concat(lines, "\n")
    pcall(function()
        for _, path in ipairs(GetFriendUIDPaths()) do
            local f = io.open(path, "w")
            if f then
                f:write(content)
                f:close()
                break
            end
        end
    end)
    _friendUIDCache.t = -999.0
end

local function LoadFriendUIDList()
    local result = {}
    local seen = {}
    pcall(function()
        local paths = GetFriendUIDPaths()
        if _G.RapzhangFriendUIDPath and _G.RapzhangFriendUIDPath ~= "" then
            table.insert(paths, 1, _G.RapzhangFriendUIDPath)
        end
        for _, path in ipairs(paths) do
            local f = io.open(path, "r")
            if f then
                local data = f:read("*a")
                f:close()
                if data and data ~= "" then
                    for token in data:gmatch("[^,%s;]+") do
                        local cleaned = token:gsub("^[Uu][Ii][Dd]%s*[:=]%s*", "")
                        local n = tonumber(cleaned)
                        if n and n > 0 then
                            local key = tostring(math.floor(n))
                            if not seen[key] then
                                seen[key] = true
                                result[#result + 1] = math.floor(n)
                            end
                        end
                    end
                end
                if #result > 0 then
                    print(string.format("[FORCE FRIEND] Loaded %d UID(s) from %s", #result, path))
                    break
                end
            end
        end
    end)
    if #result == 0 then
        pcall(function()
            local cd = _G.RapzhangState and _G.RapzhangState.CustomTextData
            if cd and cd.ForceFriendUID then
                local n = tonumber(cd.ForceFriendUID) or 0
                if n > 0 then
                    result[1] = n
                    SaveFriendUIDList(result)
                end
            end
        end)
    end
    if #result == 0 then
        print("[FORCE FRIEND] UID file not found or empty: " .. tostring(FriendUIDFileName))
    end
    return result
end

local function LoadFriendUIDListCached()
    local now = os.time()
    if (now - _friendUIDCache.t) < FRIEND_UID_CACHE_TTL then
        return _friendUIDCache.list
    end
    _friendUIDCache.t = now
    _friendUIDCache.list = LoadFriendUIDList()
    return _friendUIDCache.list
end

local function FriendUIDListEquals(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    if #a ~= #b then return false end
    for i = 1, #a do
        if tostring(a[i]) ~= tostring(b[i]) then return false end
    end
    return true
end

local function FriendUIDInList(list, uid)
    if type(list) ~= "table" then return false end
    local target = tostring(uid)
    for _, v in ipairs(list) do
        if tostring(v) == target then return true end
    end
    return false
end

_G.RapzhangFriendUID = {
    FileName = FriendUIDFileName,
    GetPaths = GetFriendUIDPaths,
    Load = LoadFriendUIDListCached,
    LoadFresh = LoadFriendUIDList,
    Save = SaveFriendUIDList,
    Equals = FriendUIDListEquals,
    Contains = FriendUIDInList,
}

-- ==========================================
-- HÀM QUẢN LÝ DỌN RÁC MAP MARK
-- ==========================================
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.RapzhangState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    _G.RapzhangState.TrackedMarks[mark] = nil
end

_G.ClearMortarTargetLock = function()
    local state = _G.RapzhangState
    if not state then return end
    if state.MortarTargetLockMark then
        SafeRemoveMark(state.MortarTargetLockMark)
    end
    state.MortarTargetLockMark = nil
    state.MortarTargetLockActor = nil
    state.MortarTargetLockLastUpdate = nil
end

_G.UpdateMortarTargetLock = function(show, target)
    local state = _G.RapzhangState
    if not state then return end
    if not show or not Valid(target) then
        ClearMortarTargetLock()
        return
    end

    local now = os.clock()
    local needsRefresh = state.MortarTargetLockActor ~= target
        or not state.MortarTargetLockMark
        or (now - (state.MortarTargetLockLastUpdate or 0)) >= 0.15
    if not needsRefresh then return end

    local markPos = nil
    pcall(function()
        if type(target.GetHeadLocation) == "function" then
            markPos = target:GetHeadLocation(false)
        end
        if not markPos and type(target.K2_GetActorLocation) == "function" then
            markPos = target:K2_GetActorLocation()
            if markPos then markPos.Z = markPos.Z + 70 end
        end
    end)
    if not markPos then return end

    local newMark = SafeAddMark(1003, markPos, 0, "", 4, nil)
    if not newMark then return end
    local oldMark = state.MortarTargetLockMark
    state.MortarTargetLockMark = newMark
    state.MortarTargetLockActor = target
    state.MortarTargetLockLastUpdate = now
    if oldMark and oldMark ~= newMark then
        SafeRemoveMark(oldMark)
    end
end

local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true
                hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end

-- ==========================================
-- HỆ THỐNG LƯU VÀ TẢI SETTING MENU VIP (TỰ ĐỘNG)
-- ==========================================
local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.tencent.igfit/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
            end
        end
    end)
    return paths
end

local ConfigFileName = "rapzhang_settings.txt"
_G.LastConfigSaveStr = ""
_G.ModConfigFileValid = false
_G.ResetFeatureBooleansOff = function()
    for key, value in pairs(_G.RapzhangConfig or {}) do
        if type(value) == "boolean" then _G.RapzhangConfig[key] = false end
    end
end

_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nRapzhangConfig = {\n"
        for k, v in pairs(_G.RapzhangConfig or {}) do
            -- Persist only Lua primitives here. Nested transport tables are
            -- runtime defaults and must not be serialized as table addresses.
            if type(v) == "boolean" or type(v) == "number" then
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            elseif type(v) == "string" then
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. string.format("%q", v) .. ",\n"
            end
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.RapzhangState and _G.RapzhangState.CustomTextData then
            for k, v in pairs(_G.RapzhangState.CustomTextData) do
                if type(v) == "boolean" or type(v) == "number" then
                    data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
                elseif type(v) == "string" then
                    data = data .. "  [\"" .. tostring(k) .. "\"] = " .. string.format("%q", v) .. ",\n"
                end
            end
        end
        data = data .. "}\n}"
        
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data

        local paths = GetConfigPaths(ConfigFileName)
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(data)
                file:close()
                break
            end
        end
    end)
end

_G.LoadModSettings = function()
    _G.ModConfigFileValid = false
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end

        if content then
            local func = load(content)
            if func then
                local okSaved, savedData = pcall(func)
                if okSaved and savedData and type(savedData) == "table" then
                    _G.ModConfigFileValid = true
                    _G.ResetFeatureBooleansOff()
                    if savedData.RapzhangConfig then
                        for k, v in pairs(savedData.RapzhangConfig) do
                            _G.RapzhangConfig[k] = v
                        end
                    end
                    if savedData.CustomTextData then
                        _G.RapzhangState.CustomTextData = _G.RapzhangState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do
                            _G.RapzhangState.CustomTextData[k] = v
                        end
                    end
                    _G.RapzhangConfig.X3TPPForce = nil
                end
            end
        end
        if not _G.ModConfigFileValid then _G.ResetFeatureBooleansOff() end
        -- This feature is automatic and is not controlled by persisted settings.
        _G.RapzhangConfig.AutoFeedbackEnabled = true
        _G.SaveModSettings() 
    end)
end

local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker") 
        if okTicker and ticker and ticker.AddTimerOnce then 
            ticker.AddTimerOnce(3.0, AutoSaveLoop)
        end
    end)
end

local SETTINGS_LOADER_VERSION = "rapzhang-settings-v2"
if _G.ModConfigLoadedVersion ~= SETTINGS_LOADER_VERSION then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
    _G.ModConfigLoadedVersion = SETTINGS_LOADER_VERSION
end

-- Migrasi sekali: versi lama menyimpan semua toggle item ON saat subgrup
-- dinyalakan. Reset pilihan loot agar update ini mulai dari item OFF dan
-- pemain memilih sendiri item yang ingin ditampilkan.
do
    local cfg = _G.RapzhangConfig
    if cfg and cfg.Esp9_LootSelVer ~= 2 then
        local drop = {}
        for k in pairs(cfg) do
            local sk = tostring(k)
            if sk:find("^Esp9_LootI_") or sk:find("^Esp9_LootG_")
                or sk:match("^Esp9_Loot%a+Other$") then
                drop[#drop + 1] = k
            end
        end
        for _, k in ipairs(drop) do cfg[k] = nil end
        cfg.Esp9_Loot = false
        for _, k in ipairs({
            "Esp9_LootWeapon", "Esp9_LootGear", "Esp9_LootAmmo", "Esp9_LootMeds",
            "Esp9_LootAttach", "Esp9_LootThrow", "Esp9_LootMisc",
        }) do cfg[k] = false end
        cfg.Esp9_LootSelVer = 2
    end
end

-- Clamp nilai SUPPORT setelah config tersimpan dimuat (angka tidak ikut
-- di-reset oleh ResetFeatureBooleansOff, jadi cukup sekali di sini).
do
    local cfg = _G.RapzhangConfig
    if cfg then
        cfg.Sup_FastLootDist = math.max(1, math.min(15, math.floor((tonumber(cfg.Sup_FastLootDist) or 4) + 0.5)))
        cfg.Sup_AutoRescueDist = math.max(1, math.min(15, math.floor((tonumber(cfg.Sup_AutoRescueDist) or 3) + 0.5)))
    end
end

_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end

-- ============================================================
-- ESP LOOT ITEM CATALOG
-- Satu sumber data untuk menu toggle per item dan filter scan.
-- ID mengikuti tabel item PUBG Mobile. Entri yang tidak tercatat
-- di sini tetap tampil lewat toggle "Other" per kategori, jadi
-- item baru dari update game tidak hilang diam-diam.
-- ============================================================
_G.RapzhangLoot = _G.RapzhangLoot or {}
do
    local L = _G.RapzhangLoot
    L.Catalog = {
        -- WEAPON / ASSAULT RIFLES
        { id = 101001, key = "AKM",            name = "AKM",             cat = "weapon", group = "AR" },
        { id = 101002, key = "M16A4",          name = "M16A4",           cat = "weapon", group = "AR" },
        { id = 101003, key = "SCARL",          name = "SCAR-L",          cat = "weapon", group = "AR" },
        { id = 101004, key = "M416",           name = "M416",            cat = "weapon", group = "AR" },
        { id = 101005, key = "Groza",          name = "Groza",           cat = "weapon", group = "AR" },
        { id = 101006, key = "AUG",            name = "AUG",             cat = "weapon", group = "AR" },
        { id = 101007, key = "QBZ",            name = "QBZ",             cat = "weapon", group = "AR" },
        { id = 101008, key = "M762",           name = "M762",            cat = "weapon", group = "AR" },
        { id = 101009, key = "Mk47Mutant",     name = "Mk47 Mutant",     cat = "weapon", group = "AR" },
        { id = 101010, key = "G36C",           name = "G36C",            cat = "weapon", group = "AR" },
        { id = 101012, key = "HoneyBadger",    name = "Honey Badger",    cat = "weapon", group = "AR" },
        { id = 101100, key = "FAMAS",          name = "FAMAS",           cat = "weapon", group = "AR" },
        { id = 101101, key = "ASMAbakan",      name = "ASM Abakan",      cat = "weapon", group = "AR" },
        { id = 101102, key = "ACE32",          name = "ACE32",           cat = "weapon", group = "AR" },
        -- WEAPON / SMGs
        { id = 102001, key = "UZI",            name = "UZI",             cat = "weapon", group = "SMG" },
        { id = 102002, key = "UMP45",          name = "UMP45",           cat = "weapon", group = "SMG" },
        { id = 102003, key = "Vector",         name = "Vector",          cat = "weapon", group = "SMG" },
        { id = 102004, key = "Thompson",       name = "Thompson",        cat = "weapon", group = "SMG" },
        { id = 102005, key = "Bizon",          name = "PP-19 Bizon",     cat = "weapon", group = "SMG" },
        { id = 102007, key = "MP5K",           name = "MP5K",            cat = "weapon", group = "SMG" },
        { id = 102105, key = "P90",            name = "P90",             cat = "weapon", group = "SMG" },
        -- WEAPON / SNIPERS + DMR
        { id = 103001, key = "Kar98K",         name = "Kar98K",          cat = "weapon", group = "SR" },
        { id = 103002, key = "M24",            name = "M24",             cat = "weapon", group = "SR" },
        { id = 103003, key = "AWM",            name = "AWM",             cat = "weapon", group = "SR" },
        { id = 103004, key = "SKS",            name = "SKS",             cat = "weapon", group = "SR" },
        { id = 103005, key = "VSS",            name = "VSS",             cat = "weapon", group = "SR" },
        { id = 103006, key = "Mini14",         name = "Mini14",          cat = "weapon", group = "SR" },
        { id = 103007, key = "Mk14",           name = "Mk14",            cat = "weapon", group = "SR" },
        { id = 103008, key = "Win94",          name = "Win94",           cat = "weapon", group = "SR" },
        { id = 103009, key = "SLR",            name = "SLR",             cat = "weapon", group = "SR" },
        { id = 103010, key = "QBU",            name = "QBU",             cat = "weapon", group = "SR" },
        { id = 103011, key = "Mosin",          name = "Mosin Nagant",    cat = "weapon", group = "SR" },
        { id = 103012, key = "AMR",            name = "AMR",             cat = "weapon", group = "SR" },
        { id = 103100, key = "Mk12",           name = "Mk12",            cat = "weapon", group = "SR" },
        -- WEAPON / SHOTGUNS
        { id = 104001, key = "S686",           name = "S686",            cat = "weapon", group = "SG" },
        { id = 104002, key = "S1897",          name = "S1897",           cat = "weapon", group = "SG" },
        { id = 104003, key = "S12K",           name = "S12K",            cat = "weapon", group = "SG" },
        { id = 104004, key = "DBS",            name = "DBS",             cat = "weapon", group = "SG" },
        { id = 104100, key = "SPAS12",         name = "SPAS-12",         cat = "weapon", group = "SG" },
        { id = 104101, key = "M1014",          name = "M1014",           cat = "weapon", group = "SG" },
        { id = 104102, key = "NS2000",         name = "NS2000",          cat = "weapon", group = "SG" },
        -- WEAPON / MACHINE GUNS
        { id = 105001, key = "M249",           name = "M249",            cat = "weapon", group = "MG" },
        { id = 105002, key = "DP28",           name = "DP-28",           cat = "weapon", group = "MG" },
        { id = 105003, key = "M134",           name = "M134",            cat = "weapon", group = "MG" },
        { id = 105010, key = "MG3",            name = "MG3",             cat = "weapon", group = "MG" },
        -- WEAPON / PISTOLS
        { id = 106001, key = "P92",            name = "P92",             cat = "weapon", group = "Pistol" },
        { id = 106002, key = "P1911",          name = "P1911",           cat = "weapon", group = "Pistol" },
        { id = 106003, key = "R1895",          name = "R1895",           cat = "weapon", group = "Pistol" },
        { id = 106004, key = "P18C",           name = "P18C",            cat = "weapon", group = "Pistol" },
        { id = 106005, key = "R45",            name = "R45",             cat = "weapon", group = "Pistol" },
        { id = 106006, key = "SawedOff",       name = "Sawed-off",       cat = "weapon", group = "Pistol" },
        { id = 106007, key = "FlareGun",       name = "Flare Gun",       cat = "weapon", group = "Pistol" },
        { id = 106008, key = "Vz61",           name = "Vz61",            cat = "weapon", group = "Pistol" },
        { id = 106010, key = "DesertEagle",    name = "Desert Eagle",    cat = "weapon", group = "Pistol" },
        -- WEAPON / MELEE + OTHER
        { id = 108001, key = "Machete",        name = "Machete",         cat = "weapon", group = "Melee" },
        { id = 108003, key = "Sickle",         name = "Sickle",          cat = "weapon", group = "Melee" },
        { id = 108004, key = "Pan",            name = "Pan",             cat = "weapon", group = "Melee" },
        { id = 107001, key = "Crossbow",       name = "Crossbow",        cat = "weapon", group = "Other" },
        -- GEAR / HELMET, VEST, BACKPACK (level 1-3)
        { id = 502001, key = "HelmetLv1",      name = "Helmet Lv.1",     cat = "gear",   group = "Helmet" },
        { id = 502002, key = "HelmetLv2",      name = "Helmet Lv.2",     cat = "gear",   group = "Helmet" },
        { id = 502003, key = "HelmetLv3",      name = "Helmet Lv.3",     cat = "gear",   group = "Helmet" },
        { id = 503001, key = "VestLv1",        name = "Vest Lv.1",       cat = "gear",   group = "Vest" },
        { id = 503002, key = "VestLv2",        name = "Vest Lv.2",       cat = "gear",   group = "Vest" },
        { id = 503003, key = "VestLv3",        name = "Vest Lv.3",       cat = "gear",   group = "Vest" },
        { id = 501001, key = "BackpackLv1",    name = "Backpack Lv.1",   cat = "gear",   group = "Backpack" },
        { id = 501002, key = "BackpackLv2",    name = "Backpack Lv.2",   cat = "gear",   group = "Backpack" },
        { id = 501003, key = "BackpackLv3",    name = "Backpack Lv.3",   cat = "gear",   group = "Backpack" },
        -- ATTACHMENT / MUZZLE
        { id = 201001, key = "Choke",          name = "Choke (SG)",              cat = "attach", group = "Muzzle" },
        { id = 201002, key = "CompensatorSMG", name = "Compensator (SMG)",       cat = "attach", group = "Muzzle" },
        { id = 201003, key = "CompensatorSR",  name = "Compensator (SR)",        cat = "attach", group = "Muzzle" },
        { id = 201004, key = "FlashHiderSMG",  name = "Flash Hider (SMG)",       cat = "attach", group = "Muzzle" },
        { id = 201005, key = "FlashHiderSR",   name = "Flash Hider (SR)",        cat = "attach", group = "Muzzle" },
        { id = 201006, key = "SuppressorSMG",  name = "Suppressor (SMG)",        cat = "attach", group = "Muzzle" },
        { id = 201007, key = "SuppressorSR",   name = "Suppressor (SR)",         cat = "attach", group = "Muzzle" },
        { id = 201009, key = "CompensatorAR",  name = "Compensator (AR)",        cat = "attach", group = "Muzzle" },
        { id = 201010, key = "FlashHiderAR",   name = "Flash Hider (AR)",        cat = "attach", group = "Muzzle" },
        { id = 201011, key = "SuppressorAR",   name = "Suppressor (AR)",         cat = "attach", group = "Muzzle" },
        { id = 201012, key = "Duckbill",       name = "Duckbill (SG)",           cat = "attach", group = "Muzzle" },
        -- ATTACHMENT / GRIP
        { id = 202001, key = "AngledGrip",     name = "Angled Foregrip",         cat = "attach", group = "Grip" },
        { id = 202002, key = "VerticalGrip",   name = "Vertical Foregrip",       cat = "attach", group = "Grip" },
        { id = 202003, key = "HalfGrip",       name = "Half Grip",               cat = "attach", group = "Grip" },
        { id = 202004, key = "LightGrip",      name = "Lightweight Grip",        cat = "attach", group = "Grip" },
        { id = 202006, key = "ThumbGrip",      name = "Thumb Grip",              cat = "attach", group = "Grip" },
        { id = 202007, key = "LaserSight",     name = "Laser Sight",             cat = "attach", group = "Grip" },
        -- ATTACHMENT / SCOPE
        { id = 203001, key = "RedDot",         name = "Red Dot Sight",           cat = "attach", group = "Scope" },
        { id = 203002, key = "Holo",           name = "Holographic Sight",       cat = "attach", group = "Scope" },
        { id = 203003, key = "Scope2x",        name = "2x Scope",                cat = "attach", group = "Scope" },
        { id = 203004, key = "Scope4x",        name = "4x Scope",                cat = "attach", group = "Scope" },
        { id = 203005, key = "Scope8x",        name = "8x Scope",                cat = "attach", group = "Scope" },
        { id = 203014, key = "Scope3x",        name = "3x Scope",                cat = "attach", group = "Scope" },
        { id = 203015, key = "Scope6x",        name = "6x Scope",                cat = "attach", group = "Scope" },
        { id = 203018, key = "CantedSight",    name = "Canted Sight",            cat = "attach", group = "Scope" },
        -- ATTACHMENT / MAGAZINE
        { id = 204001, key = "ExtMagPistol",    name = "Extended Mag (Pistol)",          cat = "attach", group = "Magazine" },
        { id = 204002, key = "QuickMagPistol",  name = "Quickdraw Mag (Pistol)",         cat = "attach", group = "Magazine" },
        { id = 204003, key = "ExtQuickMagPistol", name = "Extended Quickdraw (Pistol)",  cat = "attach", group = "Magazine" },
        { id = 204004, key = "ExtMagSMG",       name = "Extended Mag (SMG)",             cat = "attach", group = "Magazine" },
        { id = 204005, key = "QuickMagSMG",     name = "Quickdraw Mag (SMG)",            cat = "attach", group = "Magazine" },
        { id = 204006, key = "ExtQuickMagSMG",  name = "Extended Quickdraw (SMG)",       cat = "attach", group = "Magazine" },
        { id = 204007, key = "ExtMagSR",        name = "Extended Mag (SR)",              cat = "attach", group = "Magazine" },
        { id = 204008, key = "QuickMagSR",      name = "Quickdraw Mag (SR)",             cat = "attach", group = "Magazine" },
        { id = 204009, key = "ExtQuickMagSR",   name = "Extended Quickdraw (SR)",        cat = "attach", group = "Magazine" },
        { id = 204011, key = "ExtMagAR",        name = "Extended Mag (AR)",              cat = "attach", group = "Magazine" },
        { id = 204012, key = "QuickMagAR",      name = "Quickdraw Mag (AR)",             cat = "attach", group = "Magazine" },
        { id = 204013, key = "ExtQuickMagAR",   name = "Extended Quickdraw (AR)",        cat = "attach", group = "Magazine" },
        { id = 204015, key = "ExtMagMG",        name = "Extended Mag (MG)",              cat = "attach", group = "Magazine" },
        { id = 204016, key = "JungleMagAR",     name = "Jungle Style Mag (AR)",          cat = "attach", group = "Magazine" },
        { id = 204017, key = "ShotgunLoader",   name = "Shotgun Quick Loader",           cat = "attach", group = "Magazine" },
        { id = 204051, key = "MiniDrumAR",      name = "Mini Drum Mag (AR)",             cat = "attach", group = "Magazine" },
        -- ATTACHMENT / STOCK
        { id = 205001, key = "StockUZI",        name = "Stock (Micro UZI)",       cat = "attach", group = "Stock" },
        { id = 205002, key = "TacticalStock",   name = "Tactical Stock",          cat = "attach", group = "Stock" },
        { id = 205003, key = "CheekPad",        name = "Cheek Pad (SR)",          cat = "attach", group = "Stock" },
        { id = 205004, key = "CrossbowStock",   name = "Crossbow Stock",          cat = "attach", group = "Stock" },
        { id = 204014, key = "BulletLoops",     name = "Bullet Loops (SR)",       cat = "attach", group = "Stock" },
        -- AMMO
        { id = 301001, key = "Ammo9mm",         name = "9mm",             cat = "ammo" },
        { id = 302001, key = "Ammo762",         name = "7.62mm",          cat = "ammo" },
        { id = 303001, key = "Ammo556",         name = "5.56mm",          cat = "ammo" },
        { id = 304001, key = "Ammo12G",         name = "12 Gauge",        cat = "ammo" },
        { id = 305001, key = "Ammo45",          name = ".45 ACP",         cat = "ammo" },
        { id = 306001, key = "Ammo300",         name = ".300 Magnum",     cat = "ammo" },
        { id = 307001, key = "AmmoBolt",        name = "Crossbow Bolt",   cat = "ammo" },
        { id = 308001, key = "AmmoFlare",       name = "Flare",           cat = "ammo" },
        -- MEDS / CONSUMABLES
        { id = 601001, key = "EnergyDrink",     name = "Energy Drink",        cat = "meds" },
        { id = 601002, key = "Adrenaline",      name = "Adrenaline Syringe",  cat = "meds" },
        { id = 601003, key = "Painkiller",      name = "Painkiller",          cat = "meds" },
        { id = 601004, key = "Bandage",         name = "Bandage",             cat = "meds" },
        { id = 601005, key = "FirstAid",        name = "First Aid Kit",       cat = "meds" },
        { id = 601006, key = "MedKit",          name = "Med Kit",             cat = "meds" },
        -- THROWABLES
        { id = 602001, key = "Flashbang",       name = "Flashbang",       cat = "throw" },
        { id = 602002, key = "Smoke",           name = "Smoke Grenade",   cat = "throw" },
        { id = 602003, key = "Molotov",         name = "Molotov Cocktail",cat = "throw" },
        { id = 602004, key = "Frag",            name = "Frag Grenade",    cat = "throw" },
        { id = 602005, key = "Apple",           name = "Apple",           cat = "throw" },
        -- MISC
        { id = 603001, key = "GasCan",          name = "Gas Can",         cat = "misc" },
        { id = 601095, key = "SelfAid",         name = "Self Aid",        cat = "misc" },
        { id = 3000324, key = "ShopToken",      name = "Shop Token",      cat = "misc" },
    }

    L.ById = {}
    L.KeyCat = {}
    L.KeyName = {}
    L.KeyGroup = {}
    L.KeyCfg = {}
    L.ByCat = {}
    L.ByGroup = {}
    for _, e in ipairs(L.Catalog) do
        L.ById[e.id] = e
        L.KeyCat[e.key] = e.cat
        L.KeyName[e.key] = e.name
        L.KeyGroup[e.key] = e.group
        L.KeyCfg[e.key] = "Esp9_LootI_" .. e.key
        L.ByCat[e.cat] = L.ByCat[e.cat] or {}
        table.insert(L.ByCat[e.cat], e)
        local gk = tostring(e.cat) .. ":" .. tostring(e.group or "")
        L.ByGroup[gk] = L.ByGroup[gk] or {}
        table.insert(L.ByGroup[gk], e)
    end

    -- Varian model/warna gear memakai level yang sama, jadi cukup satu
    -- toggle per level.
    L.Alias = {
        [501004] = "BackpackLv1", [501005] = "BackpackLv2", [501006] = "BackpackLv3",
        [502004] = "HelmetLv1",   [502005] = "HelmetLv2",   [502006] = "HelmetLv3",
    }
    for id, key in pairs(L.Alias) do
        for _, e in ipairs(L.Catalog) do
            if e.key == key then L.ById[id] = e break end
        end
    end

    L.CatOrder = { "weapon", "gear", "attach", "ammo", "meds", "throw", "misc" }
    L.CatLabel = {
        weapon = "▶ Weapons",
        gear   = "▶ Gear / Armor",
        attach = "▶ Attachments",
        ammo   = "▶ Ammo",
        meds   = "▶ Meds / Consumables",
        throw  = "▶ Throwables",
        misc   = "▶ Misc / Chips",
    }
    L.GroupOrder = {
        weapon = { "AR", "SMG", "SR", "SG", "MG", "Pistol", "Melee", "Other" },
        gear   = { "Helmet", "Vest", "Backpack" },
        attach = { "Muzzle", "Grip", "Scope", "Magazine", "Stock" },
    }
    L.GroupLabel = {
        AR = "Assault Rifles", SMG = "SMGs", SR = "Snipers / DMR",
        SG = "Shotguns", MG = "Machine Guns", Pistol = "Pistols",
        Melee = "Melee", Other = "Other Weapons",
        Helmet = "Helmets", Vest = "Vests", Backpack = "Backpacks",
        Muzzle = "Muzzles", Grip = "Grips", Scope = "Scopes",
        Magazine = "Magazines", Stock = "Stocks",
    }
    L.GroupSlug = {
        AR = "AR", SMG = "SMG", SR = "SR", SG = "SG", MG = "MG",
        Pistol = "PISTOL", Melee = "MELEE", Other = "OTHER",
        Helmet = "HELMET", Vest = "VEST", Backpack = "BACKPACK",
        Muzzle = "MUZZLE", Grip = "GRIP", Scope = "SCOPE",
        Magazine = "MAG", Stock = "STOCK",
    }
    -- Gerbang subgrup: ON hanya membuka subgrup, tidak menyalakan item.
    L.GroupCfg = {}
    for cat, groups in pairs(L.GroupOrder) do
        for _, group in ipairs(groups) do
            L.GroupCfg[cat .. ":" .. group] =
                "Esp9_LootG_" .. (L.GroupSlug[group] or group)
        end
    end
end

-- ============================================================
-- HỆ THỐNG MENU VIP NATIVE (CHẠY TRỰC TIẾP TỪ SETTING GAME)
-- ========================================== 

function _G.InitModMenuTab()
    print("[MOD MENU] InitModMenuTab dipanggil")
    
    if _G.ModMenuInitialized and _G.RapzhangMenuVersion == 2 then 
        print("[MOD MENU] Sudah initialized, skip")
        return 
    end
    _G.ModMenuInitialized = true

    local function T(vnText, enText)
        return enText
    end

    -- STEP 1: Init CustomTextData
    pcall(function()
        _G.RapzhangState.CustomTextData = _G.RapzhangState.CustomTextData or {
            OuterSpeed = 10, InnerSpeed = 10, OuterRecoil = 0, HRecoil = 0.3, VRecoil = 0.3,
            MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120,
            AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250,
            AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30,
            AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchScopePred = 0, AimTouchScopeRecoil = 0,
            AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400, AimTouchSniperPred = 0,
            BugManRatio = 133,
            WeaponGlowThickness = 3, WeaponGlowColor = 5,
            ColorV3Hidden = 1, ColorV3Visible = 2, ColorV3Thickness = 4, OutlineColor = 4,
            BTRange = 300, BTPart = 0, BTProb = 100,
            BTSniperRange = 300, BTSniperPart = 0, BTSniperProb = 100,
            BTShotgunRange = 300, BTShotgunPart = 0, BTShotgunProb = 100,
            BTCrossbowRange = 300, BTCrossbowPart = 0, BTCrossbowProb = 100,
            BTBowRange = 300, BTBowPart = 0, BTBowProb = 100,
            BTAllRange = 300, BTAllPart = 0, BTAllProb = 100
        }
    end)

    -- Default fields used by the ESP/AIMTOUCH/BULLET menu.
    -- Existing persisted values are preserved.
    local menuDefaults = {
        AimTouchMortarFOV = 360, AimTouchMortarPrio = 1, AimTouchMortarPred = 0,
        AimTouchCrossbowCond = 2, AimTouchCrossbowPrio = 1, AimTouchCrossbowVel = 160,
        AimTouchCrossbowDrop = 100, AimTouchCrossbowDropProne = 120,
        AimTouchCrossbowSpeed = 100, AimTouchCrossbowFOV = 40, AimTouchCrossbowDist = 150,
        AimTouchCrossbowPred = 0,
        AimTouchBowCond = 1, AimTouchBowBone = 1, AimTouchBowSpeed = 80,
        AimTouchBowFOV = 40, AimTouchBowDist = 150, AimTouchBowPred = 0,
        AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1,
        AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30,
        AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1,
        AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300,
        AimTouchScopePred = 0, AimTouchScopeRecoil = 0,
        AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2,
        AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400,
        AimTouchSniperPred = 0,
        BTRange = 300, BTPart = 0, BTProb = 100,
        BTSniperRange = 300, BTSniperPart = 0, BTSniperProb = 100,
        BTShotgunRange = 300, BTShotgunPart = 0, BTShotgunProb = 100,
        BTCrossbowRange = 300, BTCrossbowPart = 0, BTCrossbowProb = 100,
        BTBowRange = 300, BTBowPart = 0, BTBowProb = 100,
        BTAllRange = 300, BTAllPart = 0, BTAllProb = 100,
    }
    for key, value in pairs(menuDefaults) do
        if _G.RapzhangState.CustomTextData[key] == nil then
            _G.RapzhangState.CustomTextData[key] = value
        end
    end

    _G.RapzhangBTData = _G.RapzhangState.CustomTextData
    if _G.RapzhangBTData.BTRange == nil and type(_G.RapzhangConfig.BTRange) == "number" then _G.RapzhangBTData.BTRange = _G.RapzhangConfig.BTRange end
    if _G.RapzhangBTData.BTPart == nil and type(_G.RapzhangConfig.BTPart) == "number" then _G.RapzhangBTData.BTPart = _G.RapzhangConfig.BTPart end
    if _G.RapzhangBTData.BTProb == nil and type(_G.RapzhangConfig.BTProb) == "number" then _G.RapzhangBTData.BTProb = _G.RapzhangConfig.BTProb end
    if _G.RapzhangBTData.BTSniperRange == nil and type(_G.RapzhangConfig.BTSniperRange) == "number" then _G.RapzhangBTData.BTSniperRange = _G.RapzhangConfig.BTSniperRange end
    if _G.RapzhangBTData.BTSniperPart == nil and type(_G.RapzhangConfig.BTSniperPart) == "number" then _G.RapzhangBTData.BTSniperPart = _G.RapzhangConfig.BTSniperPart end
    if _G.RapzhangBTData.BTSniperProb == nil and type(_G.RapzhangConfig.BTSniperProb) == "number" then _G.RapzhangBTData.BTSniperProb = _G.RapzhangConfig.BTSniperProb end
    if _G.RapzhangBTData.BTShotgunRange == nil and type(_G.RapzhangConfig.BTShotgunRange) == "number" then _G.RapzhangBTData.BTShotgunRange = _G.RapzhangConfig.BTShotgunRange end
    if _G.RapzhangBTData.BTShotgunPart == nil and type(_G.RapzhangConfig.BTShotgunPart) == "number" then _G.RapzhangBTData.BTShotgunPart = _G.RapzhangConfig.BTShotgunPart end
    if _G.RapzhangBTData.BTShotgunProb == nil and type(_G.RapzhangConfig.BTShotgunProb) == "number" then _G.RapzhangBTData.BTShotgunProb = _G.RapzhangConfig.BTShotgunProb end
    if _G.RapzhangBTData.BTAllRange == nil and type(_G.RapzhangConfig.BTAllRange) == "number" then _G.RapzhangBTData.BTAllRange = _G.RapzhangConfig.BTAllRange end
    if _G.RapzhangBTData.BTAllPart == nil and type(_G.RapzhangConfig.BTAllPart) == "number" then _G.RapzhangBTData.BTAllPart = _G.RapzhangConfig.BTAllPart end
    if _G.RapzhangBTData.BTAllProb == nil and type(_G.RapzhangConfig.BTAllProb) == "number" then _G.RapzhangBTData.BTAllProb = _G.RapzhangConfig.BTAllProb end
    _G.RapzhangConfig.BTRange = nil; _G.RapzhangConfig.BTPart = nil; _G.RapzhangConfig.BTProb = nil
    _G.RapzhangConfig.BTSniperRange = nil; _G.RapzhangConfig.BTSniperPart = nil; _G.RapzhangConfig.BTSniperProb = nil
    _G.RapzhangConfig.BTShotgunRange = nil; _G.RapzhangConfig.BTShotgunPart = nil; _G.RapzhangConfig.BTShotgunProb = nil
    _G.RapzhangConfig.BTAllRange = nil; _G.RapzhangConfig.BTAllPart = nil; _G.RapzhangConfig.BTAllProb = nil
    if _G.RapzhangBTData.BTRange == nil then _G.RapzhangBTData.BTRange = 300 end
    if _G.RapzhangBTData.BTPart == nil then _G.RapzhangBTData.BTPart = 0 end
    if _G.RapzhangBTData.BTProb == nil then _G.RapzhangBTData.BTProb = 100 end
    if _G.RapzhangBTData.BTSniperRange == nil then _G.RapzhangBTData.BTSniperRange = 300 end
    if _G.RapzhangBTData.BTSniperPart == nil then _G.RapzhangBTData.BTSniperPart = 0 end
    if _G.RapzhangBTData.BTSniperProb == nil then _G.RapzhangBTData.BTSniperProb = 100 end
    if _G.RapzhangBTData.BTShotgunRange == nil then _G.RapzhangBTData.BTShotgunRange = 300 end
    if _G.RapzhangBTData.BTShotgunPart == nil then _G.RapzhangBTData.BTShotgunPart = 0 end
    if _G.RapzhangBTData.BTShotgunProb == nil then _G.RapzhangBTData.BTShotgunProb = 100 end
    if _G.RapzhangBTData.BTAllRange == nil then _G.RapzhangBTData.BTAllRange = 300 end
    if _G.RapzhangBTData.BTAllPart == nil then _G.RapzhangBTData.BTAllPart = 0 end
    if _G.RapzhangBTData.BTAllProb == nil then _G.RapzhangBTData.BTAllProb = 100 end

    -- STEP 2: LocUtil Hook
    pcall(function()
        local LocUtil = _G.LocUtil
        if not LocUtil and package.loaded["client.common.LocUtil"] then
            LocUtil = require("client.common.LocUtil")
        end
        
        local FakeTextMap = {
            [999000] = T("rapzhang", "rapzhang"),
            [999001] = T("ESP", "ESP"),
            [999002] = T("AIMTOUCH", "AIMTOUCH"),
            [999003] = T("SUPPORT", "SUPPORT"),
            [999004] = T("GRAPHIC", "GRAPHIC"),
            [999006] = T("BULLET", "BULLET")
        }

        if LocUtil and not LocUtil._IsModMenuHooked_V2 then
            local hookFuncs = {"GetLocalizeResStr", "GetText", "GetTextByID", "GetLocalText", "GetLocalizeStr"}
            for _, funcName in ipairs(hookFuncs) do
                if LocUtil[funcName] then
                    local old_func = LocUtil[funcName]
                    LocUtil[funcName] = function(id)
                        if FakeTextMap[id] then
                            return FakeTextMap[id]
                        end
                        if type(id) == "string" and not tonumber(id) then
                            return id
                        end
                        if old_func then
                            return old_func(id)
                        end
                        return ""
                    end
                end
            end
            LocUtil._IsModMenuHooked_V2 = true
        end
    end)

    -- STEP 3: Require SettingPageDefine + SettingCatalog
    local SettingPageDefine = nil
    local SettingCatalog = nil
    pcall(function()
        SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    end)
    pcall(function()
        SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    end)

    if not SettingPageDefine or not SettingCatalog then
        print("[MOD MENU] ERROR: SettingPageDefine atau SettingCatalog gagal require!")
        _G.ModMenuInitialized = false
        return
    end
    print("[MOD MENU] SettingPageDefine + SettingCatalog OK")

    -- Remove legacy skin-slider rows left by an older menu build.
    local function StripLegacySkinSliderRows(node)
        if type(node) ~= "table" then return end
        for i = #node, 1, -1 do
            local item = node[i]
            if type(item) == "table" then
                local key = tostring(item.Key or "")
                local text = tostring(item.Text or "")
                if key:find("SkinSlider", 1, true) or text:lower():find("skin slider", 1, true) then
                    table.remove(node, i)
                else
                    StripLegacySkinSliderRows(item)
                end
            end
        end
    end
    pcall(function() StripLegacySkinSliderRows(SettingCatalog) end)
    pcall(function() StripLegacySkinSliderRows(SettingPageDefine.ModMenu) end)
    if type(_G.RapzhangConfig) == "table" then
        for key in pairs(_G.RapzhangConfig) do
            if tostring(key):find("SkinSlider", 1, true) then _G.RapzhangConfig[key] = nil end
        end
    end

    -- STEP 4: Hapus ModMenu lama
    pcall(function()
        for fmMenuIndex = #SettingCatalog, 1, -1 do
            if SettingCatalog[fmMenuIndex] and SettingCatalog[fmMenuIndex].Key == "ModMenu" then 
                table.remove(SettingCatalog, fmMenuIndex) 
            end
        end
    end)

    -- STEP 5: Require AliasMap
    local AliasMap = nil
    pcall(function()
        AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
    end)
    if not AliasMap then
        print("[MOD MENU] ERROR: AliasMap gagal require!")
        _G.ModMenuInitialized = false
        return
    end
    print("[MOD MENU] AliasMap OK")

    -- STEP 6: Stack ESP
        local StackESP = {
            { Key = "ModMenu_ESP9_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ ESP 2", "▶ ESP 2"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.EspLoai9 == true end, SetFunc = function(c,v) _G.RapzhangConfig.EspLoai9 = (v == true); if not v and _G.ESP and _G.ESP.ResetWidgets then pcall(_G.ESP.ResetWidgets) end; return true end },
            { Key = "ModMenu_ESP9_Count", UI = AliasMap.Switcher, Text = T("   Player Count", "   Player Count"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Count == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Count = (v == true) return true end },
            { Key = "ModMenu_ESP9_Name", UI = AliasMap.Switcher, Text = T("   Player Name", "   Player Name"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Name == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Name = (v == true) return true end },
            { Key = "ModMenu_ESP9_Dist", UI = AliasMap.Switcher, Text = T("   Player Distance", "   Player Distance"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Distance == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Distance = (v == true) return true end },
            { Key = "ModMenu_ESP9_HP", UI = AliasMap.Switcher, Text = T("   Health Bar", "   Health Bar"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_HP == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_HP = (v == true) return true end },
            { Key = "ModMenu_ESP9_Team", UI = AliasMap.Switcher, Text = T("   Team Color Box", "   Team Color Box"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Team == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Team = (v == true) return true end },
            { Key = "ModMenu_ESP9_TeamNumber", UI = AliasMap.Switcher, Text = T("   Team Number", "   Team Number"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_TeamNumber == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_TeamNumber = v and true or false; return true end },
            { Key = "ModMenu_ESP9_Visibility", UI = AliasMap.Switcher, Text = T("   Visibility (Open/Close)", "   Visibility (Open/Close)"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Visibility == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_Visibility = (v == true); return true end },
            { Key = "ModMenu_ESP9_AimLine", UI = AliasMap.Switcher, Text = T("   Enemy Aim Line", "   Enemy Aim Line"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_AimLine == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_AimLine = (v == true); pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_SelfRescue", UI = AliasMap.Switcher, Text = T("   Self-Rescue Badge", "   Self-Rescue Badge"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_SelfRescue == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_SelfRescue = (v == true); pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_Line", UI = AliasMap.Switcher, Text = T("   Snapline", "   Snapline"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Line == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_Line = (v == true); return true end },
            { Key = "ModMenu_ESP9_Weapon", UI = AliasMap.Switcher, Text = T("   Weapon Icon", "   Weapon Icon"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Weapon == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Weapon = (v == true) return true end },
            { Key = "ModMenu_ESP9_Ammo", UI = AliasMap.Switcher, Text = T("   Enemy Ammo + Reload", "   Enemy Ammo + Reload"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Ammo == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_Ammo = v and true or false; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_ReloadTimer", UI = AliasMap.Switcher, Text = T("   Reload Countdown", "   Reload Countdown"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_ReloadTimer == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_ReloadTimer = v and true or false; if v then _G.RapzhangConfig.Esp9_Ammo = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_Radar360", UI = AliasMap.Switcher, Text = T("   360 Radar + Distance", "   360 Radar + Distance"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Radar360 == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_Radar360 = v and true or false; return true end },
            { Key = "ModMenu_ESP9_Airdrop", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Airdrop ESP", "   ▶ Airdrop ESP"), ExpandHandle = "ModMenu_ESP9_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.Esp9_Airdrop == true end, SetFunc = function(_,v) local on = v and true or false; _G.RapzhangConfig.Esp9_Airdrop = on; if on then _G.RapzhangConfig.Esp9_AirdropBox = true; _G.RapzhangConfig.Esp9_AirdropPredict = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_AirdropBox", UI = AliasMap.Switcher, Text = T("      Airdrop Box", "      Airdrop Box"), ExpandHandle = "ModMenu_ESP9_Airdrop", GetFunc = function() return _G.RapzhangConfig.Esp9_AirdropBox == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_AirdropBox = v and true or false; if v then _G.RapzhangConfig.Esp9_Airdrop = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_AirdropPredict", UI = AliasMap.Switcher, Text = T("      Landing Prediction", "      Landing Prediction"), ExpandHandle = "ModMenu_ESP9_Airdrop", GetFunc = function() return _G.RapzhangConfig.Esp9_AirdropPredict == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_AirdropPredict = v and true or false; if v then _G.RapzhangConfig.Esp9_Airdrop = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_Zone", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Zone + Circle Info", "   ▶ Zone + Circle Info"), ExpandHandle = "ModMenu_ESP9_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.Esp9_Zone == true end, SetFunc = function(_,v) local on = v and true or false; _G.RapzhangConfig.Esp9_Zone = on; if on then _G.RapzhangConfig.Esp9_ZoneTimer = true; _G.RapzhangConfig.Esp9_ZoneNext = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_ZoneTimer", UI = AliasMap.Switcher, Text = T("      Zone Timer", "      Zone Timer"), ExpandHandle = "ModMenu_ESP9_Zone", GetFunc = function() return _G.RapzhangConfig.Esp9_ZoneTimer == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_ZoneTimer = v and true or false; if v then _G.RapzhangConfig.Esp9_Zone = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_ZoneNext", UI = AliasMap.Switcher, Text = T("      Next Circle (3D)", "      Next Circle (3D)"), ExpandHandle = "ModMenu_ESP9_Zone", GetFunc = function() return _G.RapzhangConfig.Esp9_ZoneNext == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_ZoneNext = v and true or false; if v then _G.RapzhangConfig.Esp9_Zone = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_Grenade", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Grenade ESP", "   ▶ Grenade ESP"), ExpandHandle = "ModMenu_ESP9_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.Esp9_Grenade == true end, SetFunc = function(_,v) local on = v and true or false; _G.RapzhangConfig.Esp9_Grenade = on; if on then _G.RapzhangConfig.Esp9_GrenadeMark = true; _G.RapzhangConfig.Esp9_GrenadeRadius = true; _G.RapzhangConfig.Esp9_GrenadeBounce = true; _G.RapzhangConfig.Esp9_GrenadeFuse = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_GrenadeMark", UI = AliasMap.Switcher, Text = T("      Grenade Marker + Type", "      Grenade Marker + Type"), ExpandHandle = "ModMenu_ESP9_Grenade", GetFunc = function() return _G.RapzhangConfig.Esp9_GrenadeMark == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_GrenadeMark = v and true or false; if v then _G.RapzhangConfig.Esp9_Grenade = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_GrenadeRadius", UI = AliasMap.Switcher, Text = T("      Blast Radius", "      Blast Radius"), ExpandHandle = "ModMenu_ESP9_Grenade", GetFunc = function() return _G.RapzhangConfig.Esp9_GrenadeRadius == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_GrenadeRadius = v and true or false; if v then _G.RapzhangConfig.Esp9_Grenade = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_GrenadeBounce", UI = AliasMap.Switcher, Text = T("      Bounce Prediction", "      Bounce Prediction"), ExpandHandle = "ModMenu_ESP9_Grenade", GetFunc = function() return _G.RapzhangConfig.Esp9_GrenadeBounce == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_GrenadeBounce = v and true or false; if v then _G.RapzhangConfig.Esp9_Grenade = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ESP9_GrenadeFuse", UI = AliasMap.Switcher, Text = T("      Fuse Countdown", "      Fuse Countdown"), ExpandHandle = "ModMenu_ESP9_Grenade", GetFunc = function() return _G.RapzhangConfig.Esp9_GrenadeFuse ~= false end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_GrenadeFuse = (v == true); if v then _G.RapzhangConfig.Esp9_Grenade = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            -- =============================================
            -- ADVANCED OVERLAY: parent ON/OFF + anak-anaknya
            -- =============================================
            { Key = "ModMenu_ADV_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Advanced Overlay", "   ▶ Advanced Overlay"), ExpandHandle = "ModMenu_ESP9_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.Esp9_Adv == true end, SetFunc = function(_,v) local onv = v and true or false; _G.RapzhangConfig.Esp9_Adv = onv; if not onv then for _,k in ipairs(_G.ESP and _G.ESP.AdvChildren or {"Esp9_DmgDir","Esp9_Ghost","Esp9_Squad","Esp9_VehIntel"}) do _G.RapzhangConfig[k] = false end end; pcall(function() if _G.ESP and _G.ESP.Adv then _G.ESP.Adv.ClearAll() end end); if not onv then pcall(function() if _G.ESP and _G.ESP.Adv and _G.ESP.Adv.UninstallDamageHook then _G.ESP.Adv.UninstallDamageHook() end end) end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ADV_Dmg", UI = AliasMap.Switcher, Text = T("      Damage Direction + Attacker", "      Damage Direction + Attacker"), ExpandHandle = "ModMenu_ADV_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_DmgDir == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_DmgDir = v and true or false; if v then _G.RapzhangConfig.Esp9_Adv = true; pcall(function() if _G.ESP and _G.ESP.Adv then _G.ESP.Adv.InstallDamageHook() end end) else pcall(function() if _G.ESP and _G.ESP.Adv and _G.ESP.Adv.UninstallDamageHook then _G.ESP.Adv.UninstallDamageHook() end end) end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ADV_Ghost", UI = AliasMap.Switcher, Text = T("      Ghost Last-Seen Marker", "      Ghost Last-Seen Marker"), ExpandHandle = "ModMenu_ADV_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Ghost == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_Ghost = v and true or false; if v then _G.RapzhangConfig.Esp9_Adv = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ADV_Squad", UI = AliasMap.Switcher, Text = T("      Squad Strength Tracker", "      Squad Strength Tracker"), ExpandHandle = "ModMenu_ADV_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Squad == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_Squad = v and true or false; if v then _G.RapzhangConfig.Esp9_Adv = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
            { Key = "ModMenu_ADV_Veh", UI = AliasMap.Switcher, Text = T("      Vehicle Intel (Enemy)", "      Vehicle Intel (Enemy)"), ExpandHandle = "ModMenu_ADV_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_VehIntel == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_VehIntel = v and true or false; if v then _G.RapzhangConfig.Esp9_Adv = true end; pcall(function() if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end end); return true end },
        }

        local RequestMenuRefresh = function() end
        local StackAimbot = {}

        local function DisableAimTouchChildren()
            local keys = {
                "AimTouchMortar",
                "AimTouchMortarVisCheck",
                "AimTouchMortarShowTargetLock",
                "AimTouchCrossbow",
                "AimTouchCrossbowScope",
                "AimTouchCrossbowHipfire",
                "AimTouchBow",
                "AimTouchHipIgKnock",
                "AimTouchHipIgBot",
                "AimTouchHipVisCheck",
                "AimTouchHipfire",
                "AimTouchSG",
                "AimTouchSGAutoFire",
                "AimTouchSGIgKnock",
                "AimTouchSGIgBot",
                "AimTouchSGVisCheck",
                "AimTouchScopeAll",
                "AimTouchScopeIgKnock",
                "AimTouchScopeIgBot",
                "AimTouchScopeVisCheck",
                "AimTouchSniperEnable",
                "AimTouchScopeSniper",
                "AimTouchSniperHipfire",
                "AimTouchSniperIgKnock",
                "AimTouchSniperIgBot",
                "AimTouchSniperVisCheck",
            }
            for _, key in ipairs(keys) do _G.RapzhangConfig[key] = false end
        end
        local function DisableBulletChildren()
            -- Parent utama OFF harus benar-benar mematikan semua cabang Bullet Track.
            -- Sebelumnya beberapa parent (Crossbow/Bow/Shotgun/Sniper/All) tertinggal ON.
            local keys = {
                "BulletTrackCrossbow",
                "BulletTrackCrossbowScope",
                "BulletTrackCrossbowHipfire",
                "BulletTrackBow",
                "BulletTrackBowScope",
                "BulletTrackBowHipfire",
                "BulletTrackShotgun",
                "BulletTrackShotgunScope",
                "BulletTrackShotgunHipfire",
                "BulletTrackSniper",
                "BulletTrackSniperScope",
                "BulletTrackSniperHipfire",
                "BulletTrackAllWeapon",
                "BulletTrackAllScope",
                "BulletTrackAllHipfire",
                "BTAllSmartHead",
                "CustomHRecoil",
                "CustomVRecoil",
                "LessShake",
                "Accuracy",
                "Crosshair",
            }
            for _, key in ipairs(keys) do
                _G.RapzhangConfig[key] = false
            end
            -- Hentikan state target yang mungkin masih tersisa dari tick sebelumnya.
            pcall(function()
                if BulletTrackSmartHead then
                    BulletTrackSmartHead._target = nil
                    BulletTrackSmartHead._activeProfile = nil
                    BulletTrackSmartHead._lastFiring = false
                end
            end)
            pcall(function()
                if _G.RapzhangState and _G.RapzhangState.RefreshActiveWeaponStats then
                    _G.RapzhangState.RefreshActiveWeaponStats()
                end
            end)
        end

        local StackAimbotV2 = {
            { Key = "ModMenu_AT_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ AIMTOUCH V2 ENHANCED", "▶ AIMTOUCH V2 ENHANCED"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.AimTouchEnable == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchEnable = (v == true); if v ~= true then DisableAimTouchChildren() end; RequestMenuRefresh(); return true end },
            --AIMBOT MORTAR ( MORTAR )
            { Key = "ModMenu_AT_Mortar_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Mortar Aimbot", "   ▶ Mortar Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.AimTouchMortar == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchMortar = (v == true); RequestMenuRefresh(); return true end },
            { Key = "ModMenu_AT_Mortar_ShowTargetLock", UI = AliasMap.Switcher, Text = T("      Show Target Lock", "      Show Target Lock"), ExpandHandle = "ModMenu_AT_Mortar_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchMortarShowTargetLock == true end, SetFunc = function(_,v) _G.RapzhangConfig.AimTouchMortarShowTargetLock = (v == true) return true end },
            { Key = "ModMenu_AT_Mortar_VisCheck", UI = AliasMap.Switcher, Text = T("      Visibility Check", "      Visibility Check"), ExpandHandle = "ModMenu_AT_Mortar_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchMortarVisCheck == true end, SetFunc = function(_,v) _G.RapzhangConfig.AimTouchMortarVisCheck = (v == true) return true end },
            { Key = "ModMenu_AT_Mortar_FOV", UI = AliasMap.Slider, Text = T("      FOV Radius (1-360)", "      FOV Radius (1-360)"), ExpandHandle = "ModMenu_AT_Mortar_Ex", MinValue = 1, MaxValue = 360, min = 1, max = 360, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchMortarFOV or 360 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchMortarFOV = v return true end },
            { Key = "ModMenu_AT_Mortar_Prio", UI = AliasMap.Slider, Text = T("      Priority (1:Crosshair 2:Distance 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_Mortar_Ex", MinValue = 1, MaxValue = 3, min = 1, max = 3, Min = 1, Max = 3, GetFunc = function() return math.min(3, math.max(1, _G.RapzhangState.CustomTextData.AimTouchMortarPrio or 1)) end, SetFunc = function(_,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 3 then val = 3 end; _G.RapzhangState.CustomTextData.AimTouchMortarPrio = val return true end },
            { Key = "ModMenu_AT_Mortar_Pred", UI = AliasMap.Slider, Text = T("      Prediction Value (0-100)", "      Prediction Value (0-100)"), ExpandHandle = "ModMenu_AT_Mortar_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchMortarPred or 0 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchMortarPred = v return true end },
    
            -- =============================================
            --[BARU DITAMBAHKAN] AIMBOT Crossbow ( CROSSBOW ) - TETAPKAN DI BAWAH MORTAR
            -- =============================================
            { Key = "ModMenu_AT_Crossbow_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Crossbow Aimbot", "   ▶ Crossbow Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.AimTouchCrossbow == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchCrossbow = (v == true); RequestMenuRefresh(); return true end },
            { Key = "ModMenu_AT_Crossbow_Scope", UI = AliasMap.Switcher, Text = T("      Scope Mode", "      Scope Mode"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchCrossbowScope == true end, SetFunc = function(_,v) _G.RapzhangConfig.AimTouchCrossbowScope = (v == true); return true end },
            { Key = "ModMenu_AT_Crossbow_Hip", UI = AliasMap.Switcher, Text = T("      Hip Fire Mode", "      Hip Fire Mode"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchCrossbowHipfire == true end, SetFunc = function(_,v) _G.RapzhangConfig.AimTouchCrossbowHipfire = (v == true); return true end },
            { Key = "ModMenu_AT_Crossbow_Cond", UI = AliasMap.Slider, Text = T("      Trigger (1:On Fire, 2:Always)", "      Trigger (1:On Fire, 2:Always)"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchCrossbowCond or 2 end, SetFunc = function(_,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.RapzhangState.CustomTextData.AimTouchCrossbowCond = val return true end },
            { Key = "ModMenu_AT_Crossbow_Prio", UI = AliasMap.Slider, Text = T("      Priority (1:Crosshair 2:Distance 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", MinValue = 1, MaxValue = 3, min = 1, max = 3, Min = 1, Max = 3, GetFunc = function() return math.min(3, math.max(1, _G.RapzhangState.CustomTextData.AimTouchCrossbowPrio or 1)) end, SetFunc = function(_,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 3 then val = 3 end; _G.RapzhangState.CustomTextData.AimTouchCrossbowPrio = val return true end },
            { Key = "ModMenu_AT_Crossbow_Vel", UI = AliasMap.Slider, Text = T("      Bolt Velocity (50-300 m/s)", "      Bolt Velocity (50-300 m/s)"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", MinValue = 50, MaxValue = 300, min = 50, max = 300, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchCrossbowVel or 160 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchCrossbowVel = v return true end },
            { Key = "ModMenu_AT_Crossbow_Drop", UI = AliasMap.Slider, Text = T("      Drop Compensation (0-200)", "      Drop Compensation (0-200)"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", MinValue = 0, MaxValue = 200, min = 0, max = 200, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchCrossbowDrop or 100 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchCrossbowDrop = v return true end },
            { Key = "ModMenu_AT_Crossbow_DropProne", UI = AliasMap.Slider, Text = T("      Drop Prone (0-200)", "      Drop Prone (0-200)"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", MinValue = 0, MaxValue = 200, min = 0, max = 200, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchCrossbowDropProne or 120 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchCrossbowDropProne = v return true end },
            { Key = "ModMenu_AT_Crossbow_Spd", UI = AliasMap.Slider, Text = T("      Speed (1-100)", "      Speed (1-100)"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, Min = 1, Max = 100, GetFunc = function() return math.max(1, math.min(100, math.floor((_G.RapzhangState.CustomTextData.AimTouchCrossbowSpeed or 100) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchCrossbowSpeed = math.max(1, math.min(100, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_Crossbow_FOV", UI = AliasMap.Slider, Text = T("      FOV (1-100)", "      FOV (1-100)"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchCrossbowFOV or 40 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchCrossbowFOV = v return true end },
            { Key = "ModMenu_AT_Crossbow_Dist", UI = AliasMap.Slider, Text = T("      Distance Limit (1-500m)", "      Distance Limit (1-500m)"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return math.max(1, math.min(500, math.floor((_G.RapzhangState.CustomTextData.AimTouchCrossbowDist or 150) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchCrossbowDist = math.max(1, math.min(500, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_Crossbow_Pred", UI = AliasMap.Slider, Text = T("      Prediction (0-100)", "      Prediction (0-100)"), ExpandHandle = "ModMenu_AT_Crossbow_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchCrossbowPred or 0 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchCrossbowPred = v return true end },

            -- =============================================
            --[TAMBAH BARU] AIMBOT CUNG EXPLOSION ( EXPLOSIVE BOW ) - TEMPATKAN DI BAWAH CROSSBOW
            -- =============================================
            { Key = "ModMenu_AT_Bow_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Explosive Bow Aimbot", "   ▶ Explosive Bow Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.AimTouchBow == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchBow = (v == true); RequestMenuRefresh(); return true end },
            { Key = "ModMenu_AT_Bow_Cond", UI = AliasMap.Slider, Text = T("      Condition (1:Bow Drawn 2:Always)", "      Condition (1:Bow Drawn 2:Always)"), ExpandHandle = "ModMenu_AT_Bow_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchBowCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.RapzhangState.CustomTextData.AimTouchBowCond = val return true end },
            { Key = "ModMenu_AT_Bow_Bone", UI = AliasMap.Slider, Text = T("      Position (1:Head 2:Chest 3:Stomach)", "      Position (1:Head 2:Chest 3:Stomach)"), ExpandHandle = "ModMenu_AT_Bow_Ex", MinValue = 1, MaxValue = 3, min = 1, max = 3, Min = 1, Max = 3, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchBowBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 3 then val = 3 end; _G.RapzhangState.CustomTextData.AimTouchBowBone = val return true end },
            { Key = "ModMenu_AT_Bow_Spd", UI = AliasMap.Slider, Text = T("      Speed (1-100)", "      Speed (1-100)"), ExpandHandle = "ModMenu_AT_Bow_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, Min = 1, Max = 100, GetFunc = function() return math.max(1, math.min(100, math.floor((_G.RapzhangState.CustomTextData.AimTouchBowSpeed or 80) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchBowSpeed = math.max(1, math.min(100, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_Bow_FOV", UI = AliasMap.Slider, Text = T("      FOV (1-100)", "      FOV (1-100)"), ExpandHandle = "ModMenu_AT_Bow_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchBowFOV or 40 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchBowFOV = v return true end },
            { Key = "ModMenu_AT_Bow_Dist", UI = AliasMap.Slider, Text = T("      Distance Limit (1-500m)", "      Distance Limit (1-500m)"), ExpandHandle = "ModMenu_AT_Bow_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return math.max(1, math.min(500, math.floor((_G.RapzhangState.CustomTextData.AimTouchBowDist or 150) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchBowDist = math.max(1, math.min(500, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_Bow_Drop", UI = AliasMap.Slider, Text = T("      Bow Drop (0-100)", "      Bow Drop (0-100)"), ExpandHandle = "ModMenu_AT_Bow_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchBowDrop or 50 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchBowDrop = v return true end },
            { Key = "ModMenu_AT_Bow_Pred", UI = AliasMap.Slider, Text = T("      Prediction (0-100)", "      Prediction (0-100)"), ExpandHandle = "ModMenu_AT_Bow_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchBowPred or 0 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchBowPred = v return true end },
            -- HIPFIRE (TÂM TRẮNG)
            { Key = "ModMenu_AT_Hip_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Hipfire Aimbot", "   ▶ Hipfire Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.AimTouchHipfire == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchHipfire = (v == true); RequestMenuRefresh(); return true end },
            { Key = "ModMenu_AT_Hip_IgKnock", UI = AliasMap.Switcher, Text = T("      Ignore Knocked", "      Ignore Knocked"), ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchHipIgKnock == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchHipIgKnock = (v == true) return true end },
            { Key = "ModMenu_AT_Hip_IgBot", UI = AliasMap.Switcher, Text = T("      Ignore Bots", "      Ignore Bots"), ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchHipIgBot == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchHipIgBot = (v == true) return true end },
            { Key = "ModMenu_AT_Hip_Vis", UI = AliasMap.Switcher, Text = T("      Visibility Check", "      Visibility Check"), ExpandHandle = "ModMenu_AT_Hip_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchHipVisCheck == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchHipVisCheck = (v == true) return true end },
            { Key = "ModMenu_AT_Hip_Prio", UI = AliasMap.Slider, Text = T("      Priority (1:Crosshair 2:Distance 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 3, min = 1, max = 3, Min = 1, Max = 3, GetFunc = function() return math.min(3, math.max(1, _G.RapzhangState.CustomTextData.AimTouchHipPrio or 1)) end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 3 then val = 3 end; _G.RapzhangState.CustomTextData.AimTouchHipPrio = val return true end },
            { Key = "ModMenu_AT_Hip_Bone", UI = AliasMap.Slider, Text = T("      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)", "      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchHipBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.RapzhangState.CustomTextData.AimTouchHipBone = val return true end },
            { Key = "ModMenu_AT_Hip_Cond", UI = AliasMap.Slider, Text = T("      Trigger (1:On Fire, 2:Always)", "      Trigger (1:On Fire, 2:Always)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchHipCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.RapzhangState.CustomTextData.AimTouchHipCond = val return true end },
            { Key = "ModMenu_AT_Hip_Spd", UI = AliasMap.Slider, Text = T("      Smoothness / Speed (1-100)", "      Smoothness / Speed (1-100)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, Min = 1, Max = 100, GetFunc = function() return math.max(1, math.min(100, math.floor((_G.RapzhangState.CustomTextData.AimTouchHipSpeed or 50) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchHipSpeed = math.max(1, math.min(100, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_Hip_FOV", UI = AliasMap.Slider, Text = T("      FOV Radius (1-100)", "      FOV Radius (1-100)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchHipFOV or 30 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchHipFOV = v return true end },
            { Key = "ModMenu_AT_Hip_Dist", UI = AliasMap.Slider, Text = T("      Distance Limit (1-500m)", "      Distance Limit (1-500m)"), ExpandHandle = "ModMenu_AT_Hip_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return math.max(1, math.min(500, math.floor((_G.RapzhangState.CustomTextData.AimTouchHipDist or 250) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchHipDist = math.max(1, math.min(500, math.floor(v + 0.5))); return true end },

            -- AIMBOT SHOTGUN
            { Key = "ModMenu_AT_SG_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Shotgun Aimbot", "   ▶ Shotgun Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.AimTouchSG == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchSG = (v == true); RequestMenuRefresh(); return true end },
            { Key = "ModMenu_AT_SG_AutoFire", UI = AliasMap.Switcher, Text = T("      Auto Fire", "      Auto Fire"), ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchSGAutoFire == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchSGAutoFire = (v == true) return true end },
            { Key = "ModMenu_AT_SG_IgKnock", UI = AliasMap.Switcher, Text = T("      Ignore Knocked", "      Ignore Knocked"), ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchSGIgKnock == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchSGIgKnock = (v == true) return true end },
            { Key = "ModMenu_AT_SG_IgBot", UI = AliasMap.Switcher, Text = T("      Ignore Bots", "      Ignore Bots"), ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchSGIgBot == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchSGIgBot = (v == true) return true end },
            { Key = "ModMenu_AT_SG_Vis", UI = AliasMap.Switcher, Text = T("      Visibility Check", "      Visibility Check"), ExpandHandle = "ModMenu_AT_SG_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchSGVisCheck == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchSGVisCheck = (v == true) return true end },
            { Key = "ModMenu_AT_SG_Prio", UI = AliasMap.Slider, Text = T("      Priority (1:Crosshair 2:Distance 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 3, min = 1, max = 3, Min = 1, Max = 3, GetFunc = function() return math.min(3, math.max(1, _G.RapzhangState.CustomTextData.AimTouchSGPrio or 1)) end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 3 then val = 3 end; _G.RapzhangState.CustomTextData.AimTouchSGPrio = val return true end },
            { Key = "ModMenu_AT_SG_Bone", UI = AliasMap.Slider, Text = T("      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)", "      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchSGBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.RapzhangState.CustomTextData.AimTouchSGBone = val return true end },
            { Key = "ModMenu_AT_SG_Cond", UI = AliasMap.Slider, Text = T("      Trigger (1:On Fire, 2:Always)", "      Trigger (1:On Fire, 2:Always)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchSGCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.RapzhangState.CustomTextData.AimTouchSGCond = val return true end },
            { Key = "ModMenu_AT_SG_Spd", UI = AliasMap.Slider, Text = T("      Smoothness / Speed (1-100)", "      Smoothness / Speed (1-100)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, Min = 1, Max = 100, GetFunc = function() return math.max(1, math.min(100, math.floor((_G.RapzhangState.CustomTextData.AimTouchSGSpeed or 80) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchSGSpeed = math.max(1, math.min(100, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_SG_FOV", UI = AliasMap.Slider, Text = T("      FOV Radius (1-100)", "      FOV Radius (1-100)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchSGFOV or 40 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchSGFOV = v return true end },
            { Key = "ModMenu_AT_SG_Dist", UI = AliasMap.Slider, Text = T("      Distance Limit (1-500m)", "      Distance Limit (1-500m)"), ExpandHandle = "ModMenu_AT_SG_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return math.max(1, math.min(500, math.floor((_G.RapzhangState.CustomTextData.AimTouchSGDist or 30) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchSGDist = math.max(1, math.min(500, math.floor(v + 0.5))); return true end },
            
            -- SCOPE ALL (SÚNG THƯỜNG KHI MỞ SCOPE)
            { Key = "ModMenu_AT_ScopeAll_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Scope Aimbot", "   ▶ Scope Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.AimTouchScopeAll == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchScopeAll = (v == true); RequestMenuRefresh(); return true end },
            { Key = "ModMenu_AT_ScopeAll_IgKnock", UI = AliasMap.Switcher, Text = T("      Ignore Knocked", "      Ignore Knocked"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchScopeIgKnock == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchScopeIgKnock = (v == true) return true end },
            { Key = "ModMenu_AT_ScopeAll_IgBot", UI = AliasMap.Switcher, Text = T("      Ignore Bots", "      Ignore Bots"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchScopeIgBot == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchScopeIgBot = (v == true) return true end },
            { Key = "ModMenu_AT_ScopeAll_Vis", UI = AliasMap.Switcher, Text = T("      Visibility Check", "      Visibility Check"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchScopeVisCheck == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchScopeVisCheck = (v == true) return true end },
            { Key = "ModMenu_AT_ScopeAll_Prio", UI = AliasMap.Slider, Text = T("      Priority (1:Crosshair 2:Distance 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 3, min = 1, max = 3, Min = 1, Max = 3, GetFunc = function() return math.min(3, math.max(1, _G.RapzhangState.CustomTextData.AimTouchScopePrio or 1)) end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 3 then val = 3 end; _G.RapzhangState.CustomTextData.AimTouchScopePrio = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Bone", UI = AliasMap.Slider, Text = T("      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)", "      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchScopeBone or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.RapzhangState.CustomTextData.AimTouchScopeBone = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Cond", UI = AliasMap.Slider, Text = T("      Trigger (1:On Fire, 2:Always)", "      Trigger (1:On Fire, 2:Always)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchScopeCond or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.RapzhangState.CustomTextData.AimTouchScopeCond = val return true end },
            { Key = "ModMenu_AT_ScopeAll_Spd", UI = AliasMap.Slider, Text = T("      Smoothness / Speed (1-100)", "      Smoothness / Speed (1-100)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, Min = 1, Max = 100, GetFunc = function() return math.max(1, math.min(100, math.floor((_G.RapzhangState.CustomTextData.AimTouchScopeSpeed or 40) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchScopeSpeed = math.max(1, math.min(100, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_ScopeAll_FOV", UI = AliasMap.Slider, Text = T("      FOV Radius (1-100)", "      FOV Radius (1-100)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchScopeFOV or 20 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchScopeFOV = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Dist", UI = AliasMap.Slider, Text = T("      Distance Limit (1-500m)", "      Distance Limit (1-500m)"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return math.max(1, math.min(500, math.floor((_G.RapzhangState.CustomTextData.AimTouchScopeDist or 300) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchScopeDist = math.max(1, math.min(500, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_ScopeAll_Pred", UI = AliasMap.Slider, Text = T("      Prediction Value", "      Prediction Value"), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchScopePred or 0 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchScopePred = v return true end },
            { Key = "ModMenu_AT_ScopeAll_Recoil", UI = AliasMap.Slider, Text = T("      Auto Recoil Comp.", "      Auto Recoil Comp."), ExpandHandle = "ModMenu_AT_ScopeAll_Ex", MinValue = 0, MaxValue = 50, min = 0, max = 50, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchScopeRecoil or 0 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchScopeRecoil = v return true end },

            -- SCOPE SNIPER (SÚNG NGẮM/TỈA)
            { Key = "ModMenu_AT_Sniper_Ex", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Sniper Aimbot", "   ▶ Sniper Aimbot"), ExpandHandle = "ModMenu_AT_Ex", ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.AimTouchSniperEnable == true end, SetFunc = function(_,v) _G.RapzhangConfig.AimTouchSniperEnable = (v == true); if v ~= true then _G.RapzhangConfig.AimTouchScopeSniper = false; _G.RapzhangConfig.AimTouchSniperHipfire = false end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_AT_Sniper_ScopeMode", UI = AliasMap.Switcher, Text = T("      Scope Mode (ON/OFF)", "      Scope Mode (ON/OFF)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchScopeSniper == true end, SetFunc = function(_,v) _G.RapzhangConfig.AimTouchScopeSniper = (v == true); if v == true then _G.RapzhangConfig.AimTouchSniperEnable = true end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_AT_Sniper_Hip", UI = AliasMap.Switcher, Text = T("      Hip Fire Mode", "      Hip Fire Mode"), ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchSniperHipfire == true end, SetFunc = function(_,v) _G.RapzhangConfig.AimTouchSniperHipfire = (v == true); if v == true then _G.RapzhangConfig.AimTouchSniperEnable = true end; return true end },
            { Key = "ModMenu_AT_Sniper_IgKnock", UI = AliasMap.Switcher, Text = T("      Ignore Knocked", "      Ignore Knocked"), ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchSniperIgKnock == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchSniperIgKnock = (v == true) return true end },
            { Key = "ModMenu_AT_Sniper_IgBot", UI = AliasMap.Switcher, Text = T("      Ignore Bots", "      Ignore Bots"), ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchSniperIgBot == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchSniperIgBot = (v == true) return true end },
            { Key = "ModMenu_AT_Sniper_Vis", UI = AliasMap.Switcher, Text = T("      Visibility Check", "      Visibility Check"), ExpandHandle = "ModMenu_AT_Sniper_Ex", GetFunc = function() return _G.RapzhangConfig.AimTouchSniperVisCheck == true end, SetFunc = function(c,v) _G.RapzhangConfig.AimTouchSniperVisCheck = (v == true) return true end },
            { Key = "ModMenu_AT_Sniper_Prio", UI = AliasMap.Slider, Text = T("      Priority (1:Crosshair 2:Distance 3:HP)", "      Priority (1:Crosshair 2:Distance 3:HP)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 3, min = 1, max = 3, Min = 1, Max = 3, GetFunc = function() return math.min(3, math.max(1, _G.RapzhangState.CustomTextData.AimTouchSniperPrio or 1)) end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 3 then val = 3 end; _G.RapzhangState.CustomTextData.AimTouchSniperPrio = val return true end },
            { Key = "ModMenu_AT_Sniper_Bone", UI = AliasMap.Slider, Text = T("      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)", "      Bone (1:Head 2:Chest 3:Stomach 4:Pelvis)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 4, min = 1, max = 4, Min = 1, Max = 4, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchSniperBone or 1 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 4 then val = 4 end; _G.RapzhangState.CustomTextData.AimTouchSniperBone = val return true end },
            { Key = "ModMenu_AT_Sniper_Cond", UI = AliasMap.Slider, Text = T("      Trigger (1:On Fire, 2:Always)", "      Trigger (1:On Fire, 2:Always)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 2, min = 1, max = 2, Min = 1, Max = 2, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchSniperCond or 2 end, SetFunc = function(c,v) local val = math.floor(v+0.5); if val < 1 then val = 1 end; if val > 2 then val = 2 end; _G.RapzhangState.CustomTextData.AimTouchSniperCond = val return true end },
            { Key = "ModMenu_AT_Sniper_Spd", UI = AliasMap.Slider, Text = T("      Smoothness / Speed (1-100)", "      Smoothness / Speed (1-100)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, Min = 1, Max = 100, GetFunc = function() return math.max(1, math.min(100, math.floor((_G.RapzhangState.CustomTextData.AimTouchSniperSpeed or 30) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchSniperSpeed = math.max(1, math.min(100, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_Sniper_FOV", UI = AliasMap.Slider, Text = T("      FOV Radius (1-100)", "      FOV Radius (1-100)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchSniperFOV or 20 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchSniperFOV = v return true end },
            { Key = "ModMenu_AT_Sniper_Dist", UI = AliasMap.Slider, Text = T("      Distance Limit (1-500m)", "      Distance Limit (1-500m)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 1, MaxValue = 500, min = 1, max = 500, Min = 1, Max = 500, GetFunc = function() return math.max(1, math.min(500, math.floor((_G.RapzhangState.CustomTextData.AimTouchSniperDist or 400) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.AimTouchSniperDist = math.max(1, math.min(500, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_AT_Sniper_Pred", UI = AliasMap.Slider, Text = T("      Prediction Value (0-100)", "      Prediction Value (0-100)"), ExpandHandle = "ModMenu_AT_Sniper_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.AimTouchSniperPred or 0 end, SetFunc = function(c,v) _G.RapzhangState.CustomTextData.AimTouchSniperPred = v return true end }
        }

        local StackSkin = {
            { Key = "Lobby Super Car", UI = AliasMap.Switcher, Text = T("VIP Super Car Lobby (Disable to revert)", "VIP Super Car Lobby (Disable to revert)"), GetFunc = function() return _G.RapzhangConfig.SanhSieuXeVip == true end, SetFunc = function(c,v) _G.RapzhangConfig.SanhSieuXeVip = v; if _G.LobbyThemeSystem and _G.LobbyThemeSystem.UpdateTheme then _G.LobbyThemeSystem.UpdateTheme() end return true end },
            { Key = "ModMenu_ModEmote", UI = AliasMap.Switcher, Text = T("Unlock All VIP Emotes", "Unlock All VIP Emotes"), GetFunc = function() return _G.RapzhangConfig.ModEmote == true end, SetFunc = function(c,v) _G.RapzhangConfig.ModEmote = v return true end },
            { Key = "ModMenu_ModSkin", UI = AliasMap.Switcher, Text = T("VIP Mod Skin System (Lobby + Match)", "VIP Mod Skin System (Lobby + Match)"), GetFunc = function() return _G.RapzhangConfig.ModSkin == true end, SetFunc = function(c,v) _G.RapzhangConfig.ModSkin = v and true or false; if _G.AddOutfit and _G.AddOutfit.startLobbySkinWatcher then _G.AddOutfit.startLobbySkinWatcher() end; return true end },
            { Key = "ModMenu_SkinDeadBox", UI = AliasMap.Switcher, Text = T("Deadbox Skin (Sync with Weapon)", "Deadbox Skin (Sync with Weapon)"), GetFunc = function() return _G.RapzhangConfig.SkinDeadBox == true end, SetFunc = function(c,v) _G.RapzhangConfig.SkinDeadBox = v return true end },
            { Key = "ModMenu_SkinAttachment", UI = AliasMap.Switcher, Text = T("Weapon Attachment Skin", "Weapon Attachment Skin"), GetFunc = function() return _G.RapzhangConfig.SkinAttachment == true end, SetFunc = function(c,v) _G.RapzhangConfig.SkinAttachment = v return true end },
            { Key = "ModMenu_KillMessage", UI = AliasMap.Switcher, Text = T("VIP Kill Messenger", "VIP Kill Messenger"), GetFunc = function() return _G.RapzhangConfig.KillMessage == true end, SetFunc = function(c,v) _G.RapzhangConfig.KillMessage = v return true end },
            { Key = "ModMenu_KillCountUI", UI = AliasMap.Switcher, Text = T("Kill Counter UI", "Kill Counter UI"), GetFunc = function() return _G.RapzhangConfig.KillCountUI == true end, SetFunc = function(c,v) _G.RapzhangConfig.KillCountUI = v return true end },
        }

        local StackBullet = {
            { Key = "ModMenu_BT", UI = AliasMap.TitleSwitcher, Text = T("▶ BULLET TRACK V2", "▶ BULLET TRACK V2"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.BulletTrack == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrack = v and true or false; if not v then DisableBulletChildren() end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Crossbow", UI = AliasMap.TitleSwitcher, Text = T("   ▶ BT Crossbow", "   ▶ BT Crossbow"), ExpandIndex = 0, ExpandHandle = "ModMenu_BT", GetFunc = function() return _G.RapzhangConfig.BulletTrackCrossbow == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackCrossbow = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true else _G.RapzhangConfig.BulletTrackCrossbowScope = false; _G.RapzhangConfig.BulletTrackCrossbowHipfire = false end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Crossbow_Scope", UI = AliasMap.Switcher, Text = T("      Scope Mode", "      Scope Mode"), ExpandHandle = "ModMenu_BT_Crossbow", GetFunc = function() return _G.RapzhangConfig.BulletTrackCrossbowScope == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackCrossbowScope = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackCrossbow = true end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Crossbow_Hip", UI = AliasMap.Switcher, Text = T("      Hip Fire Mode", "      Hip Fire Mode"), ExpandHandle = "ModMenu_BT_Crossbow", GetFunc = function() return _G.RapzhangConfig.BulletTrackCrossbowHipfire == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackCrossbowHipfire = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackCrossbow = true end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Crossbow_Range", UI = AliasMap.Slider, Text = T("      Crosshair Radius (1-1000)", "      Crosshair Radius (1-1000)"), ExpandHandle = "ModMenu_BT_Crossbow", MinValue = 1, MaxValue = 1000, min = 1, max = 1000, Min = 1, Max = 1000, GetFunc = function() return math.max(1, math.min(1000, math.floor((tonumber(_G.RapzhangState.CustomTextData.BTCrossbowRange) or 300) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTCrossbowRange = math.max(1, math.min(1000, math.floor((tonumber(v) or 300) + 0.5))); return true end },
            { Key = "ModMenu_BT_Crossbow_Part", UI = AliasMap.Slider, Text = T("      Body Part (0:Head 1:Neck 2:Chest)", "      Body Part (0:Head 1:Neck 2:Chest)"), ExpandHandle = "ModMenu_BT_Crossbow", MinValue = 0, MaxValue = 2, min = 0, max = 2, Min = 0, Max = 2, GetFunc = function() return math.max(0, math.min(2, math.floor((_G.RapzhangState.CustomTextData.BTCrossbowPart or 0) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTCrossbowPart = math.max(0, math.min(2, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_Crossbow_Prob", UI = AliasMap.Slider, Text = T("      Track Chance (0-1000)", "      Track Chance (0-1000)"), ExpandHandle = "ModMenu_BT_Crossbow", MinValue = 0, MaxValue = 1000, min = 0, max = 1000, Min = 0, Max = 1000, GetFunc = function() local v = _G.RapzhangState.CustomTextData.BTCrossbowProb or 100; if v <= 100 then v = v * 10 end; return math.max(0, math.min(1000, math.floor(v + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTCrossbowProb = math.max(0, math.min(1000, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_Bow", UI = AliasMap.TitleSwitcher, Text = T("   ▶ BT Bow", "   ▶ BT Bow"), ExpandIndex = 0, ExpandHandle = "ModMenu_BT", GetFunc = function() return _G.RapzhangConfig.BulletTrackBow == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackBow = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true else _G.RapzhangConfig.BulletTrackBowScope = false; _G.RapzhangConfig.BulletTrackBowHipfire = false end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Bow_Scope", UI = AliasMap.Switcher, Text = T("      Scope Mode", "      Scope Mode"), ExpandHandle = "ModMenu_BT_Bow", GetFunc = function() return _G.RapzhangConfig.BulletTrackBowScope == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackBowScope = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackBow = true end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Bow_Hip", UI = AliasMap.Switcher, Text = T("      Hip Fire Mode", "      Hip Fire Mode"), ExpandHandle = "ModMenu_BT_Bow", GetFunc = function() return _G.RapzhangConfig.BulletTrackBowHipfire == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackBowHipfire = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackBow = true end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Bow_Range", UI = AliasMap.Slider, Text = T("      Crosshair Radius (1-1000)", "      Crosshair Radius (1-1000)"), ExpandHandle = "ModMenu_BT_Bow", MinValue = 1, MaxValue = 1000, min = 1, max = 1000, Min = 1, Max = 1000, GetFunc = function() return math.max(1, math.min(1000, math.floor((tonumber(_G.RapzhangState.CustomTextData.BTBowRange) or 300) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTBowRange = math.max(1, math.min(1000, math.floor((tonumber(v) or 300) + 0.5))); return true end },
            { Key = "ModMenu_BT_Bow_Part", UI = AliasMap.Slider, Text = T("      Body Part (0:Head 1:Neck 2:Chest)", "      Body Part (0:Head 1:Neck 2:Chest)"), ExpandHandle = "ModMenu_BT_Bow", MinValue = 0, MaxValue = 2, min = 0, max = 2, Min = 0, Max = 2, GetFunc = function() return math.max(0, math.min(2, math.floor((_G.RapzhangState.CustomTextData.BTBowPart or 0) + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTBowPart = math.max(0, math.min(2, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_Bow_Prob", UI = AliasMap.Slider, Text = T("      Track Chance (0-1000)", "      Track Chance (0-1000)"), ExpandHandle = "ModMenu_BT_Bow", MinValue = 0, MaxValue = 1000, min = 0, max = 1000, Min = 0, Max = 1000, GetFunc = function() local v = _G.RapzhangState.CustomTextData.BTBowProb or 100; if v <= 100 then v = v * 10 end; return math.max(0, math.min(1000, math.floor(v + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTBowProb = math.max(0, math.min(1000, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_Shotgun", UI = AliasMap.TitleSwitcher, Text = T("   ▶ BT Shotgun", "   ▶ BT Shotgun"), ExpandIndex = 0, ExpandHandle = "ModMenu_BT", GetFunc = function() return _G.RapzhangConfig.BulletTrackShotgun == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackShotgun = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true else _G.RapzhangConfig.BulletTrackShotgunScope = false; _G.RapzhangConfig.BulletTrackShotgunHipfire = false end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Shotgun_Scope", UI = AliasMap.Switcher, Text = T("      Scope Mode", "      Scope Mode"), ExpandHandle = "ModMenu_BT_Shotgun", GetFunc = function() return _G.RapzhangConfig.BulletTrackShotgunScope == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackShotgunScope = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackShotgun = true end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Shotgun_Hip", UI = AliasMap.Switcher, Text = T("      Hip Fire Mode", "      Hip Fire Mode"), ExpandHandle = "ModMenu_BT_Shotgun", GetFunc = function() return _G.RapzhangConfig.BulletTrackShotgunHipfire == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackShotgunHipfire = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackShotgun = true end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Shotgun_Range", UI = AliasMap.Slider, Text = T("      Crosshair Radius", "      Crosshair Radius"), ExpandHandle = "ModMenu_BT_Shotgun", MinValue = 1, MaxValue = 1000, min = 1, max = 1000, Min = 1, Max = 1000, GetFunc = function() local v = tonumber(_G.RapzhangState.CustomTextData.BTShotgunRange) or 300; return math.max(1, math.min(1000, math.floor(v + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTShotgunRange = math.max(1, math.min(1000, math.floor((tonumber(v) or 300) + 0.5))); return true end },
            { Key = "ModMenu_BT_Shotgun_Part", UI = AliasMap.Slider, Text = T("      Body Part (0:Head 1:Neck 2:Chest)", "      Body Part (0:Head 1:Neck 2:Chest)"), ExpandHandle = "ModMenu_BT_Shotgun", MinValue = 0, MaxValue = 2, min = 0, max = 2, Min = 0, Max = 2, GetFunc = function() return _G.RapzhangState.CustomTextData.BTShotgunPart or 0 end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTShotgunPart = math.max(0, math.min(2, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_Shotgun_Prob", UI = AliasMap.Slider, Text = T("      Track Chance", "      Track Chance"), ExpandHandle = "ModMenu_BT_Shotgun", MinValue = 0, MaxValue = 100, min = 0, max = 100, Min = 0, Max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.BTShotgunProb or 100 end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTShotgunProb = math.max(0, math.min(100, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_Sniper", UI = AliasMap.TitleSwitcher, Text = T("   ▶ BT Sniper", "   ▶ BT Sniper"), ExpandIndex = 0, ExpandHandle = "ModMenu_BT", GetFunc = function() return _G.RapzhangConfig.BulletTrackSniper == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackSniper = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true else _G.RapzhangConfig.BulletTrackSniperScope = false; _G.RapzhangConfig.BulletTrackSniperHipfire = false end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Sniper_Scope", UI = AliasMap.Switcher, Text = T("      Scope Mode", "      Scope Mode"), ExpandHandle = "ModMenu_BT_Sniper", GetFunc = function() return _G.RapzhangConfig.BulletTrackSniperScope == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackSniperScope = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackSniper = true end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Sniper_Hip", UI = AliasMap.Switcher, Text = T("      Hip Fire Mode", "      Hip Fire Mode"), ExpandHandle = "ModMenu_BT_Sniper", GetFunc = function() return _G.RapzhangConfig.BulletTrackSniperHipfire == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackSniperHipfire = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackSniper = true end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_Sniper_Range", UI = AliasMap.Slider, Text = T("      Crosshair Radius", "      Crosshair Radius"), ExpandHandle = "ModMenu_BT_Sniper", MinValue = 1, MaxValue = 1000, min = 1, max = 1000, Min = 1, Max = 1000, GetFunc = function() local v = tonumber(_G.RapzhangState.CustomTextData.BTSniperRange) or 300; return math.max(1, math.min(1000, math.floor(v + 0.5))) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTSniperRange = math.max(1, math.min(1000, math.floor((tonumber(v) or 300) + 0.5))); return true end },
            { Key = "ModMenu_BT_Sniper_Part", UI = AliasMap.Slider, Text = T("      Body Part (0:Head 1:Neck 2:Chest)", "      Body Part (0:Head 1:Neck 2:Chest)"), ExpandHandle = "ModMenu_BT_Sniper", MinValue = 0, MaxValue = 2, min = 0, max = 2, Min = 0, Max = 2, GetFunc = function() return _G.RapzhangState.CustomTextData.BTSniperPart or 0 end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTSniperPart = math.max(0, math.min(2, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_Sniper_Prob", UI = AliasMap.Slider, Text = T("      Track Chance", "      Track Chance"), ExpandHandle = "ModMenu_BT_Sniper", MinValue = 0, MaxValue = 100, min = 0, max = 100, Min = 0, Max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.BTSniperProb or 100 end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTSniperProb = math.max(0, math.min(100, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_All", UI = AliasMap.TitleSwitcher, Text = T("   ▶ BT All Weapon", "   ▶ BT All Weapon"), ExpandIndex = 0, ExpandHandle = "ModMenu_BT", GetFunc = function() return _G.RapzhangConfig.BulletTrackAllWeapon == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackAllWeapon = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true else _G.RapzhangConfig.BulletTrackAllScope = false; _G.RapzhangConfig.BulletTrackAllHipfire = false; _G.RapzhangConfig.BTAllSmartHead = false end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_All_Scope", UI = AliasMap.Switcher, Text = T("      Scope Mode", "      Scope Mode"), ExpandHandle = "ModMenu_BT_All", GetFunc = function() return _G.RapzhangConfig.BulletTrackAllScope == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackAllScope = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackAllWeapon = true;  end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_All_Hip", UI = AliasMap.Switcher, Text = T("      Hip Fire Mode", "      Hip Fire Mode"), ExpandHandle = "ModMenu_BT_All", GetFunc = function() return _G.RapzhangConfig.BulletTrackAllHipfire == true end, SetFunc = function(_,v) _G.RapzhangConfig.BulletTrackAllHipfire = v and true or false; if v then _G.RapzhangConfig.BulletTrack = true; _G.RapzhangConfig.BulletTrackAllWeapon = true;  end; RequestMenuRefresh(); return true end },
            { Key = "ModMenu_BT_All_Range", UI = AliasMap.Slider, Text = T("      Crosshair Radius", "      Crosshair Radius"), ExpandHandle = "ModMenu_BT_All", MinValue = 1, MaxValue = 1000, min = 1, max = 1000, Min = 1, Max = 1000, GetFunc = function() local v = tonumber(_G.RapzhangState.CustomTextData.BTAllRange) or 300; return math.max(1, math.min(1000, math.floor(v + 0.5))) end, SetFunc = function(_,v) v = tonumber(v) or 300; _G.RapzhangState.CustomTextData.BTAllRange = math.max(1, math.min(1000, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_All_Part", UI = AliasMap.Slider, Text = T("      Body Part (0:Head 1:Neck 2:Chest)", "      Body Part (0:Head 1:Neck 2:Chest)"), ExpandHandle = "ModMenu_BT_All", MinValue = 0, MaxValue = 2, min = 0, max = 2, Min = 0, Max = 2, GetFunc = function() return _G.RapzhangState.CustomTextData.BTAllPart or 0 end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTAllPart = math.max(0, math.min(2, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_All_Prob", UI = AliasMap.Slider, Text = T("      Track Chance", "      Track Chance"), ExpandHandle = "ModMenu_BT_All", MinValue = 0, MaxValue = 100, min = 0, max = 100, Min = 0, Max = 100, GetFunc = function() return _G.RapzhangState.CustomTextData.BTAllProb or 100 end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.BTAllProb = math.max(0, math.min(100, math.floor(v + 0.5))); return true end },
            { Key = "ModMenu_BT_All_SmartHead", UI = AliasMap.Switcher, Text = T("      Smart Auto Aim Head", "      Smart Auto Aim Head"), ExpandHandle = "ModMenu_BT_All", GetFunc = function() return _G.RapzhangConfig.BTAllSmartHead == true end, SetFunc = function(_,v) _G.RapzhangConfig.BTAllSmartHead = v and true or false; return true end },
            { Key = "ModMenu_Magic_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ DỄ BỊ BAN MẠNG Magic Bullet Tùy Chỉnh", "▶ (RISK BAN) Custom Magic Bullet"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.CustomMagicBullet == true end, SetFunc = function(c,v) _G.RapzhangConfig.CustomMagicBullet = v == true; if _G.RapzhangHitboxConfigChanged then pcall(_G.RapzhangHitboxConfigChanged, true) end; if _G.SaveModSettings then pcall(_G.SaveModSettings) end; return true end },
            { Key = "ModMenu_Magic_Head", UI = AliasMap.Slider, Text = T("   Kích Thước Hitbox Đầu (1.0x - 3.0x)", "   Head Hitbox Scale (1.0x - 3.0x)"), ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() local x = tonumber(_G.RapzhangState.CustomTextData.MagicHead) or 1.0; return math.floor((math.max(1.0, math.min(3.0, x)) - 1.0) / 2.0 * 100 + 0.5) end, SetFunc = function(c,v) local n = math.max(0, math.min(100, tonumber(v) or 0)); _G.RapzhangState.CustomTextData.MagicHead = 1.0 + (n / 100.0) * 2.0; if _G.RapzhangHitboxConfigChanged then pcall(_G.RapzhangHitboxConfigChanged, false) end; return true end },
            { Key = "ModMenu_Magic_Body", UI = AliasMap.Slider, Text = T("   Kích Thước Hitbox Thân (1.0x - 3.0x)", "   Body Hitbox Scale (1.0x - 3.0x)"), ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() local x = tonumber(_G.RapzhangState.CustomTextData.MagicBody) or 1.0; return math.floor((math.max(1.0, math.min(3.0, x)) - 1.0) / 2.0 * 100 + 0.5) end, SetFunc = function(c,v) local n = math.max(0, math.min(100, tonumber(v) or 0)); _G.RapzhangState.CustomTextData.MagicBody = 1.0 + (n / 100.0) * 2.0; if _G.RapzhangHitboxConfigChanged then pcall(_G.RapzhangHitboxConfigChanged, false) end; return true end },
            { Key = "ModMenu_Magic_Legs", UI = AliasMap.Slider, Text = T("   Kích Thước Hitbox Chân (1.0x - 3.0x)", "   Legs Hitbox Scale (1.0x - 3.0x)"), ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() local x = tonumber(_G.RapzhangState.CustomTextData.MagicLegs) or 1.0; return math.floor((math.max(1.0, math.min(3.0, x)) - 1.0) / 2.0 * 100 + 0.5) end, SetFunc = function(c,v) local n = math.max(0, math.min(100, tonumber(v) or 0)); _G.RapzhangState.CustomTextData.MagicLegs = 1.0 + (n / 100.0) * 2.0; if _G.RapzhangHitboxConfigChanged then pcall(_G.RapzhangHitboxConfigChanged, false) end; return true end },
            { Key = "ModMenu_Headshot", UI = AliasMap.Switcher, Text = T("Headshot (2x Hitbox Kepala)", "Headshot (2x Head Hitbox)"), GetFunc = function() return _G.RapzhangConfig.Headshot == true end, SetFunc = function(_, v) _G.RapzhangConfig.Headshot = v == true; if _G.RapzhangHeadshotRefresh then pcall(_G.RapzhangHeadshotRefresh) end; if _G.SaveModSettings then pcall(_G.SaveModSettings) end; return true end },

            { Key = "ModMenu_HRecoil_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Less Horizontal Recoil (Drop/Put Weapon)", "▶ Less Horizontal Recoil (Drop/Put Weapon)"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.CustomHRecoil == true end, SetFunc = function(_,v) _G.RapzhangConfig.CustomHRecoil = v and true or false; if _G.RapzhangState.RefreshActiveWeaponStats then _G.RapzhangState.RefreshActiveWeaponStats() end; return true end },
            { Key = "ModMenu_HRecoil_Val", UI = AliasMap.Slider, Text = T("   Horizontal Recoil Value", "   Horizontal Recoil Value"), ExpandHandle = "ModMenu_HRecoil_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor((((_G.RapzhangState.CustomTextData.HRecoil or 0.3) - 0.3) / 4.7) * 100 + 0.5) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.HRecoil = 0.3 + (v / 100.0) * 4.7; return true end },
            { Key = "ModMenu_VRecoil_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ Less Vertical Recoil (Drop/Put Weapon)", "▶ Less Vertical Recoil (Drop/Put Weapon)"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.CustomVRecoil == true end, SetFunc = function(_,v) _G.RapzhangConfig.CustomVRecoil = v and true or false; if _G.RapzhangState.RefreshActiveWeaponStats then _G.RapzhangState.RefreshActiveWeaponStats() end; return true end },
            { Key = "ModMenu_VRecoil_Val", UI = AliasMap.Slider, Text = T("   Vertical Recoil Value", "   Vertical Recoil Value"), ExpandHandle = "ModMenu_VRecoil_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() return math.floor((((_G.RapzhangState.CustomTextData.VRecoil or 0.3) - 0.3) / 4.7) * 100 + 0.5) end, SetFunc = function(_,v) _G.RapzhangState.CustomTextData.VRecoil = 0.3 + (v / 100.0) * 4.7; return true end },
            { Key = "ModMenu_LessShake", UI = AliasMap.Switcher, Text = T("No Recoil (Drop/Put Weapon)", "No Recoil (Drop/Put Weapon)"), GetFunc = function() return _G.RapzhangConfig.LessShake == true end, SetFunc = function(_,v) _G.RapzhangConfig.LessShake = v and true or false; if _G.RapzhangState.RefreshActiveWeaponStats then _G.RapzhangState.RefreshActiveWeaponStats() end; return true end },
            { Key = "ModMenu_LessRecoil", UI = AliasMap.Switcher, Text = T("Less Recoil (Drop/Put Weapon)", "Less Recoil (Drop/Put Weapon)"), GetFunc = function() return _G.RapzhangConfig.LessRecoil == true end, SetFunc = function(_,v) _G.RapzhangConfig.LessRecoil = v and true or false; if _G.RapzhangState.RefreshActiveWeaponStats then _G.RapzhangState.RefreshActiveWeaponStats() end; return true end },
            { Key = "ModMenu_Accuracy", UI = AliasMap.Switcher, Text = T("100% Accuracy (Drop/Put Weapon)", "100% Accuracy (Drop/Put Weapon)"), GetFunc = function() return _G.RapzhangConfig.Accuracy == true end, SetFunc = function(_,v) _G.RapzhangConfig.Accuracy = v and true or false; if _G.RapzhangState.RefreshActiveWeaponStats then _G.RapzhangState.RefreshActiveWeaponStats() end; return true end },
            { Key = "ModMenu_Crosshair", UI = AliasMap.Switcher, Text = T("Small Crosshair (Drop/Put Weapon)", "Small Crosshair (Drop/Put Weapon)"), GetFunc = function() return _G.RapzhangConfig.Crosshair == true end, SetFunc = function(_,v) _G.RapzhangConfig.Crosshair = v and true or false; if _G.RapzhangState.RefreshActiveWeaponStats then _G.RapzhangState.RefreshActiveWeaponStats() end; return true end },
        }
    -- STEP 9: Stack Support
    -- Inventory toggle scoped to Support: opens/closes the main outfit/weapon wardrobe UI.
    _G.RapzhangConfig.InventoryInGame = _G.RapzhangConfig.InventoryInGame == true

    local function InstallInventoryCloseHook(uiManager)
        if not uiManager or uiManager._RapzhangInventoryCloseHooked or type(uiManager.CloseUI) ~= "function" then
            return
        end
        local originalCloseUI = uiManager.CloseUI
        uiManager.CloseUI = function(config, ...)
            local isInventory = config == (uiManager.UI_Config and uiManager.UI_Config.wardrobe)
            if not isInventory and type(config) == "table" and type(config.keyName) == "string" then
                isInventory = string.find(string.lower(config.keyName), "wardrobe", 1, true) ~= nil
            end
            local results = { originalCloseUI(config, ...) }
            if isInventory then
                _G.RapzhangConfig.InventoryInGame = false
                if _G.SaveModSettings then pcall(_G.SaveModSettings) end
            end
            local table_unpack = table.unpack or unpack
            return table_unpack(results)
        end
        uiManager._RapzhangInventoryCloseHooked = true
    end

    local function SetSupportInventoryEnabled(enabled)
        enabled = enabled == true
        local ok, result = pcall(function()
            local uiManager = rawget(_G, "UIManager")
            if not uiManager or not uiManager.UI_Config or not uiManager.UI_Config.wardrobe then
                error("Main wardrobe UI config is unavailable")
            end
            InstallInventoryCloseHook(uiManager)

            if enabled then
                -- Enter() performs the wardrobe's normal scene/data setup before ShowUI.
                local wardrobeLogic = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                if not wardrobeLogic or type(wardrobeLogic.Enter) ~= "function" then
                    error("WardrobeLogic.Enter is unavailable")
                end
                wardrobeLogic:Enter()
            else
                uiManager.CloseUI(uiManager.UI_Config.wardrobe)
            end
            return true
        end)
        if not ok then
            Notify("Wardrobe: " .. tostring(result))
            return false
        end
        _G.RapzhangConfig.InventoryInGame = enabled
        if _G.SaveModSettings then pcall(_G.SaveModSettings) end
        return true
    end

    local StackSupport = {
        { Key = "ModMenu_InventoryInGame", UI = AliasMap.Switcher, Text = T("   Inventory / Wardrobe In-Game", "   Inventory / Wardrobe In-Game"), GetFunc = function() return _G.RapzhangConfig.InventoryInGame == true end, SetFunc = function(_, v) return SetSupportInventoryEnabled(v) end },
        { Key = "ModMenu_AutoReportKiller", UI = AliasMap.Switcher, Text = T("   Killer Report Assist (Confirm)", "   Killer Report Assist (Confirm)"), GetFunc = function() return _G.RapzhangConfig.AutoReportKiller == true end, SetFunc = function(_, v) _G.RapzhangConfig.AutoReportKiller = v and true or false; if not v and _G.AutoReportAssistReset then pcall(_G.AutoReportAssistReset, false) end; return true end },
        { Key = "ModMenu_X3FakeVisual", UI = AliasMap.Switcher, Text = T("   Fake Sultan Visual", "   Fake Sultan Visual"), GetFunc = function() return _G.RapzhangConfig.X3FakeVisual == true end, SetFunc = function(_, v) _G.RapzhangConfig.X3FakeVisual = v and true or false; return true end },
        { Key = "ModMenu_ForceFriend", UI = AliasMap.Switcher, Text = T("   Force Friend", "   Force Friend"), GetFunc = function() return _G.RapzhangConfig.ForceFriend == true end, SetFunc = function(_, v) _G.RapzhangConfig.ForceFriend = v and true or false; if v then pcall(function() SaveFriendUIDList(LoadFriendUIDList()) end) end; if _G.RapzhangForceFriend then if v and _G.RapzhangForceFriend.Boot then pcall(_G.RapzhangForceFriend.Boot) elseif _G.RapzhangForceFriend.Refresh then pcall(_G.RapzhangForceFriend.Refresh) end end; if v and _G.RapzhangStartFriendSync then pcall(_G.RapzhangStartFriendSync) end; if _G.SaveModSettings then pcall(_G.SaveModSettings) end; return true end },
        { Key = "ModMenu_AutoParachute", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Auto Parachute (Map Mark)", "   ▶ Auto Parachute (Map Mark)"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.AutoParachute == true end, SetFunc = function(_, v) local on = v and true or false; if _G.RapzhangAutoParachute and _G.RapzhangAutoParachute.Set then pcall(_G.RapzhangAutoParachute.Set, on) else _G.RapzhangConfig.AutoParachute = on end; if on then _G.RapzhangConfig.AutoJump = true end; return true end },
        { Key = "ModMenu_AutoJump", UI = AliasMap.Switcher, Text = T("      Auto Jump From Plane", "      Auto Jump From Plane"), ExpandHandle = "ModMenu_AutoParachute", GetFunc = function() return _G.RapzhangConfig.AutoJump == true end, SetFunc = function(_, v) _G.RapzhangConfig.AutoJump = v and true or false; if v then _G.RapzhangConfig.AutoParachute = true; if _G.RapzhangAutoParachute and _G.RapzhangAutoParachute.Set then pcall(_G.RapzhangAutoParachute.Set, true) end end; return true end },
        { Key = "ModMenu_AutoJumpRadius", UI = AliasMap.Slider, Text = T("      Auto Jump Radius (m)", "      Auto Jump Radius (m)"), ExpandHandle = "ModMenu_AutoParachute", MinValue = 50, MaxValue = 1500, min = 50, max = 1500, Min = 50, Max = 1500, GetFunc = function() return math.max(50, math.min(1500, math.floor((tonumber(_G.RapzhangConfig.AutoJumpRadius) or 300) + 0.5))) end, SetFunc = function(_, v) _G.RapzhangConfig.AutoJumpRadius = math.max(50, math.min(1500, math.floor((tonumber(v) or 300) + 0.5))); return true end },
        { Key = "ModMenu_Sup_FastLoot", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Fast Auto Pickup", "   ▶ Fast Auto Pickup"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.Sup_FastLoot == true end, SetFunc = function(_, v) local on = v and true or false; _G.RapzhangConfig.Sup_FastLoot = on; if on then pcall(function() if _G.ESP and _G.ESP.Support then _G.ESP.Support.Reset() end end); if _G.ESP and _G.ESP.Start then pcall(_G.ESP.Start) end end; if _G.SaveModSettings then pcall(_G.SaveModSettings) end; return true end },
        { Key = "ModMenu_Sup_FastLootDist", UI = AliasMap.Slider, Text = T("      Pickup Radius (m)", "      Pickup Radius (m)"), ExpandHandle = "ModMenu_Sup_FastLoot", MinValue = 1, MaxValue = 15, min = 1, max = 15, Min = 1, Max = 15, GetFunc = function() return math.max(1, math.min(15, math.floor((tonumber(_G.RapzhangConfig.Sup_FastLootDist) or 4) + 0.5))) end, SetFunc = function(_, v) _G.RapzhangConfig.Sup_FastLootDist = math.max(1, math.min(15, math.floor((tonumber(v) or 4) + 0.5))); pcall(function() if _G.ESP and _G.ESP.Support then _G.ESP.Support.Reset() end end); if _G.SaveModSettings then pcall(_G.SaveModSettings) end; return true end },
        { Key = "ModMenu_Sup_AutoRescue", UI = AliasMap.TitleSwitcher, Text = T("   ▶ Auto Rescue Team", "   ▶ Auto Rescue Team"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.Sup_AutoRescue == true end, SetFunc = function(_, v) local on = v and true or false; _G.RapzhangConfig.Sup_AutoRescue = on; if on then pcall(function() if _G.ESP and _G.ESP.Support then _G.ESP.Support.Reset() end end); if _G.ESP and _G.ESP.Start then pcall(_G.ESP.Start) end end; if _G.SaveModSettings then pcall(_G.SaveModSettings) end; return true end },
        { Key = "ModMenu_Sup_AutoRescueDist", UI = AliasMap.Slider, Text = T("      Rescue Radius (m)", "      Rescue Radius (m)"), ExpandHandle = "ModMenu_Sup_AutoRescue", MinValue = 1, MaxValue = 10, min = 1, max = 10, Min = 1, Max = 10, GetFunc = function() return math.max(1, math.min(10, math.floor((tonumber(_G.RapzhangConfig.Sup_AutoRescueDist) or 3) + 0.5))) end, SetFunc = function(_, v) _G.RapzhangConfig.Sup_AutoRescueDist = math.max(1, math.min(10, math.floor((tonumber(v) or 3) + 0.5))); pcall(function() if _G.ESP and _G.ESP.Support then _G.ESP.Support.Reset() end end); if _G.SaveModSettings then pcall(_G.SaveModSettings) end; return true end },
    }

    -- STEP 10: Stack ESP LOOT (tab sendiri di samping ESP)
    local Loot = _G.RapzhangLoot or { Catalog = {}, ByCat = {}, ByGroup = {} }
    local LOOT_CAT_KEY = {
        weapon = "Esp9_LootWeapon",
        gear   = "Esp9_LootGear",
        attach = "Esp9_LootAttach",
        ammo   = "Esp9_LootAmmo",
        meds   = "Esp9_LootMeds",
        throw  = "Esp9_LootThrow",
        misc   = "Esp9_LootMisc",
    }
    local LOOT_CAT_MENU = {
        weapon = "ModMenu_Loot_Weapon",
        gear   = "ModMenu_Loot_Gear",
        attach = "ModMenu_Loot_Attach",
        ammo   = "ModMenu_Loot_Ammo",
        meds   = "ModMenu_Loot_Meds",
        throw  = "ModMenu_Loot_Throw",
        misc   = "ModMenu_Loot_Misc",
    }
    local LOOT_GROUP_PREFIX = {
        weapon = "W_",
        gear   = "G_",
        attach = "A_",
    }

    local function LootSyncConfig()
        pcall(function()
            if _G.ESP and _G.ESP.SyncMenuConfig then _G.ESP.SyncMenuConfig() end
        end)
    end

    local function LootClearLabels()
        pcall(function()
            if _G.ESP and _G.ESP.Adv and _G.ESP.Adv.ClearLoot then
                _G.ESP.Adv.ClearLoot()
            end
        end)
    end

    local function LootEnableCategory(cat)
        local key = LOOT_CAT_KEY[cat]
        if key then _G.RapzhangConfig[key] = true end
        _G.RapzhangConfig.Esp9_Loot = true
    end

    local function LootItemRow(e, indent)
        local cfgKey = (Loot.KeyCfg and Loot.KeyCfg[e.key]) or ("Esp9_LootI_" .. e.key)
        local groupKey = e.group and Loot.GroupCfg
            and Loot.GroupCfg[e.cat .. ":" .. e.group] or nil
        local parent = LOOT_CAT_MENU[e.cat]
        local prefix = LOOT_GROUP_PREFIX[e.cat]
        if prefix and e.group then
            parent = "ModMenu_Loot_" .. prefix
                .. (Loot.GroupSlug[e.group] or e.group)
        end
        return {
            Key = "ModMenu_Loot_I_" .. e.key,
            UI = AliasMap.Switcher,
            Text = T(indent .. e.name, indent .. e.name),
            ExpandHandle = parent,
            GetFunc = function() return _G.RapzhangConfig[cfgKey] == true end,
            SetFunc = function(_, v)
                _G.RapzhangConfig[cfgKey] = v and true or false
                if v then
                    if groupKey then _G.RapzhangConfig[groupKey] = true end
                    LootEnableCategory(e.cat)
                end
                LootSyncConfig()
                return true
            end,
        }
    end

    local function LootGroupRow(cat, group)
        local label = (Loot.GroupLabel and Loot.GroupLabel[group]) or group
        local groupKey = (Loot.GroupCfg and Loot.GroupCfg[cat .. ":" .. group])
            or ("Esp9_LootG_" .. ((Loot.GroupSlug and Loot.GroupSlug[group]) or group))
        return {
            Key = "ModMenu_Loot_" .. (LOOT_GROUP_PREFIX[cat] or "X_")
                .. ((Loot.GroupSlug and Loot.GroupSlug[group]) or group),
            UI = AliasMap.TitleSwitcher,
            Text = T("   ▶ " .. label, "   ▶ " .. label),
            ExpandHandle = LOOT_CAT_MENU[cat],
            ExpandIndex = 0,
            -- Gerbang subgrup: ON tidak menyentuh toggle item. Item yang
            -- dipilih sendiri akan menyalakan gerbang ini otomatis.
            GetFunc = function() return _G.RapzhangConfig[groupKey] == true end,
            SetFunc = function(_, v)
                local onv = v and true or false
                _G.RapzhangConfig[groupKey] = onv
                if onv then
                    LootEnableCategory(cat)
                else
                    LootClearLabels()
                end
                LootSyncConfig()
                return true
            end,
        }
    end

    local function LootCatRow(cat)
        local catKey = LOOT_CAT_KEY[cat]
        local label = (Loot.CatLabel and Loot.CatLabel[cat]) or cat
        return {
            Key = LOOT_CAT_MENU[cat],
            UI = AliasMap.TitleSwitcher,
            Text = T(label, label),
            ExpandIndex = 0,
            GetFunc = function() return _G.RapzhangConfig[catKey] == true end,
            SetFunc = function(_, v)
                local onv = v and true or false
                _G.RapzhangConfig[catKey] = onv
                if onv then
                    _G.RapzhangConfig.Esp9_Loot = true
                else
                    LootClearLabels()
                end
                LootSyncConfig()
                return true
            end,
        }
    end

    local function LootOtherRow(cat)
        local catKey = LOOT_CAT_KEY[cat]
        local otherKey = catKey .. "Other"
        return {
            Key = LOOT_CAT_MENU[cat] .. "_Other",
            UI = AliasMap.Switcher,
            Text = T("   Other / Uncategorized", "   Other / Uncategorized"),
            ExpandHandle = LOOT_CAT_MENU[cat],
            GetFunc = function() return _G.RapzhangConfig[otherKey] == true end,
            SetFunc = function(_, v)
                _G.RapzhangConfig[otherKey] = v and true or false
                if v then LootEnableCategory(cat) end
                LootSyncConfig()
                return true
            end,
        }
    end

    local StackLoot = {
        { Key = "ModMenu_Loot_Master", UI = AliasMap.Switcher, Text = T("Enable ESP LOOT", "Enable ESP LOOT"), GetFunc = function() return _G.RapzhangConfig.Esp9_Loot == true end, SetFunc = function(_, v) local onv = v and true or false; _G.RapzhangConfig.Esp9_Loot = onv; if not onv then for _, k in pairs(LOOT_CAT_KEY) do _G.RapzhangConfig[k] = false end; for _, k in pairs(Loot.GroupCfg or {}) do _G.RapzhangConfig[k] = false end; LootClearLabels() end; LootSyncConfig(); return true end },
        { Key = "ModMenu_Loot_Dist", UI = AliasMap.Slider, Text = T("Scan Radius (20-300m)", "Scan Radius (20-300m)"), MinValue = 20, MaxValue = 300, min = 20, max = 300, Min = 20, Max = 300, GetFunc = function() return math.max(20, math.min(300, math.floor((_G.RapzhangConfig.Esp9_LootDist or 120) + 0.5))) end, SetFunc = function(_, v) _G.RapzhangConfig.Esp9_LootDist = math.max(20, math.min(300, math.floor(v + 0.5))); return true end },
    }

    for _, cat in ipairs(Loot.CatOrder or {}) do
        StackLoot[#StackLoot + 1] = LootCatRow(cat)
        local groups = (Loot.GroupOrder or {})[cat]
        if groups then
            for _, group in ipairs(groups) do
                StackLoot[#StackLoot + 1] = LootGroupRow(cat, group)
                for _, e in ipairs((Loot.ByGroup or {})[cat .. ":" .. group] or {}) do
                    StackLoot[#StackLoot + 1] = LootItemRow(e, "      ")
                end
            end
        else
            for _, e in ipairs((Loot.ByCat or {})[cat] or {}) do
                StackLoot[#StackLoot + 1] = LootItemRow(e, "   ")
            end
        end
        StackLoot[#StackLoot + 1] = LootOtherRow(cat)
    end

        -- STEP 10: Stack Graphic
    local StackGraphic = {
        { Key = "ModMenu_LowGraphics", UI = AliasMap.Switcher, Text = T("Super Duper Low Graphics (Resource)", "Super Duper Low Graphics (Resource)"), GetFunc = function() return _G.RapzhangConfig.LowGraphics == true end, SetFunc = function(_, v)
            _G.RapzhangConfig.LowGraphics = v == true
            if _G.RapzhangX3 and _G.RapzhangX3.ApplyLowGraphics then pcall(_G.RapzhangX3.ApplyLowGraphics, _G.RapzhangConfig.LowGraphics) end
            if _G.SaveModSettings then pcall(_G.SaveModSettings) end
            return true
        end },
        { Key = "ModMenu_EspLowOpt", UI = AliasMap.Switcher, Text = T("Optimasi ESP Low (Hemat RAM)", "ESP LOW Optimization (RAM Saver)"), GetFunc = function() return _G.RapzhangConfig.Esp9_OptLow == true end, SetFunc = function(_, v)
            _G.RapzhangConfig.Esp9_OptLow = v == true
            if _G.ESP and _G.ESP.SetLowEnd then pcall(_G.ESP.SetLowEnd, _G.RapzhangConfig.Esp9_OptLow) end
            if _G.SaveModSettings then pcall(_G.SaveModSettings) end
            return true
        end },
        { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ iPad View", "▶ iPad View"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.IpadView == true end, SetFunc = function(_, v) _G.RapzhangConfig.IpadView = v and true or false; return true end },
        { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = T("   FOV", "   FOV"), ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.RapzhangState.CustomTextData.IpadViewFOV or 120) - 90 end, SetFunc = function(_, v) _G.RapzhangState.CustomTextData.IpadViewFOV = 90 + v; return true end },
        { Key = "ModMenu_ColorBodyNew", UI = AliasMap.Switcher, Text = T("Wallhack", "Wallhack"), GetFunc = function() return _G.RapzhangConfig.ColorBodyNew == true end, SetFunc = function(_, v) _G.RapzhangConfig.ColorBodyNew = v and true or false; return true end },
        { Key = "ModMenu_X3TPPUnlockBtn", UI = AliasMap.Switcher, Text = T("Unlock TPP/FPP Switch", "Unlock TPP/FPP Switch"), GetFunc = function() return _G.RapzhangConfig.X3TPPUnlockBtn == true end, SetFunc = function(_, v) _G.RapzhangConfig.X3TPPUnlockBtn = v == true; if v and _G.RapzhangX3 and _G.RapzhangX3._XFTPPUnlockTry then pcall(_G.RapzhangX3._XFTPPUnlockTry) end; if _G.SaveModSettings then pcall(_G.SaveModSettings) end; return true end },
        { Key = "ModMenu_X3PerfBoost", UI = AliasMap.Switcher, Text = T("Unlock 165 FPS", "Unlock 165 FPS"), GetFunc = function() return _G.RapzhangConfig.X3PerfBoost == true end, SetFunc = function(_, v) _G.RapzhangConfig.X3PerfBoost = v and true or false; if _G.RapzhangX3 and _G.RapzhangX3.ApplyPerfBoost then pcall(_G.RapzhangX3.ApplyPerfBoost, _G.RapzhangX3.RapzhangConfig.X3PerfBoost) end; return true end },
    }

    -- STEP 11: Register ModMenu
    local ok_register = pcall(function()
        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text = T("rapzhang", "rapzhang"),
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_AimTouch", Text = T("AIMTOUCH", "AIMTOUCH"), Stack = StackAimbotV2 },
                { Key = "Cat_Bullet", Text = T("BULLET", "BULLET"), Stack = StackBullet },
                { Key = "Cat_ESP", Text = T("ESP", "ESP"), Stack = StackESP },
                { Key = "Cat_Loot", Text = T("ESP LOOT", "ESP LOOT"), Stack = StackLoot },
                { Key = "Cat_Support", Text = T("SUPPORT", "SUPPORT"), Stack = StackSupport },
                { Key = "Cat_Graphic", Text = T("GRAPHIC", "GRAPHIC"), Stack = StackGraphic }
            }
        }
    end)

    if not ok_register then
        print("[MOD MENU] ERROR: Gagal register SettingPageDefine.ModMenu")
        _G.ModMenuInitialized = false
        return
    end

    -- STEP 12: Insert ke SettingCatalog
    pcall(function()
        table.insert(SettingCatalog, 1, SettingPageDefine.ModMenu)
    end)
    print("[MOD MENU] SettingCatalog insert OK")

    -- STEP 13: Hook UIManager.ShowUI
    pcall(function()
        local UIManager = _G.UIManager
        if UIManager and not UIManager._IsModMenuHooked then
            local old_ShowUI = UIManager.ShowUI
            UIManager.ShowUI = function(config, ...)
                local args = {...}
                local n = select('#', ...)
                
                if config and config.keyName then
                    local lowerKeyName = string.lower(config.keyName)
                    if string.find(lowerKeyName, "setting_main") and not string.find(lowerKeyName, "custom") then
                        local catalog = args[1]
                        if type(catalog) == "table" and catalog[1] and type(catalog[1]) == "table" and catalog[1].Key then
                            local hasModMenu = false
                            for _, page in ipairs(catalog) do
                                if type(page) == "table" and page.Key == "ModMenu" then
                                    hasModMenu = true
                                    break
                                end
                            end
                            if not hasModMenu then
                                table.insert(catalog, 1, SettingPageDefine.ModMenu)
                            end
                        end
                    end
                end
                local table_unpack = table.unpack or unpack
                return old_ShowUI(config, table_unpack(args, 1, n))
            end
            UIManager._IsModMenuHooked = true
            print("[MOD MENU] UIManager.ShowUI hooked OK")
        end
    end)

    -- STEP 14: Mark sukses
    _G.RapzhangMenuVersion = 2
    print("[MOD MENU] InitModMenuTab SELESAI — ModMenu version 2 aktif")
end

-- ==========================================================
-- [FORCE FRIEND] MODULE — multi-UID + auto-retry query
-- ==========================================================
if not _G.RapzhangForceFriend then
    local FF = {}
    _G.RapzhangForceFriend = FF

    FF._currentUIDs = {}
    FF._hooked = false
    FF._orig = {}
    FF._queryLastAttempt = 0
    FF._queryAttempts = {}

    function FF._installHooks()
        if FF._hooked and FF._orig.batch ~= nil then return end
        pcall(function()
            local StatusHandler = require("client.network.Protocol.StatusHandler")
            if not StatusHandler then return end

            if FF._orig.batch == nil then
                FF._orig.batch = StatusHandler.on_batch_get_group_and_online_rsp
            end
            if FF._orig.notifyGroup == nil then
                FF._orig.notifyGroup = StatusHandler.on_notify_group_status_chg
            end
            if FF._orig.notifyOnline == nil then
                FF._orig.notifyOnline = StatusHandler.on_notify_online_status_chg
            end
        end)
        FF._hooked = true
    end

    function FF._uninstallHooks()
        pcall(function()
            local StatusHandler = require("client.network.Protocol.StatusHandler")
            if not StatusHandler then return end
            if FF._orig.batch then StatusHandler.on_batch_get_group_and_online_rsp = FF._orig.batch end
            if FF._orig.notifyGroup then StatusHandler.on_notify_group_status_chg = FF._orig.notifyGroup end
            if FF._orig.notifyOnline then StatusHandler.on_notify_online_status_chg = FF._orig.notifyOnline end
        end)
        FF._orig.batch = nil
        FF._orig.notifyGroup = nil
        FF._orig.notifyOnline = nil
        FF._hooked = false
    end

    function FF._triggerQuerySingle(uid)
        pcall(function()
            local FriendApplyHandler = require("client.network.Protocol.FriendApplyHandler")
            if FriendApplyHandler and FriendApplyHandler.on_auto_add_inner_friend_notify then
                FriendApplyHandler.on_auto_add_inner_friend_notify(uid)
            end
        end)
        pcall(function()
            local PlayerStatusMgr = ModuleManager and ModuleManager.GetModule and ModuleManager.GetModule(ModuleManager.CommonModuleConfig.PlayerStatusMgr)
            if PlayerStatusMgr and PlayerStatusMgr.send_batch_get_group_and_online_req then
                PlayerStatusMgr:send_batch_get_group_and_online_req(ENUM_BATCH_GET_GROUP_AND_ONLINE.AllFriend, { uid })
            end
        end)
        pcall(function()
            local StatusHandler = require("client.network.Protocol.StatusHandler")
            if StatusHandler and StatusHandler.send_batch_get_group_and_online_req then
                StatusHandler.send_batch_get_group_and_online_req(ENUM_BATCH_GET_GROUP_AND_ONLINE.TeamUpStranger, { uid })
            end
        end)
        pcall(function()
            local logic_profile_get_wrap = require("client.slua.logic.user.profile.logic_profile_get_wrap")
            if logic_profile_get_wrap and logic_profile_get_wrap.GetFriendProfiles then
                logic_profile_get_wrap.GetFriendProfiles(0, { uid }, nil, true, true)
            end
        end)
        pcall(function()
            local StatusHandler = require("client.network.Protocol.StatusHandler")
            if StatusHandler and StatusHandler.send_query_friend_room_id then
                StatusHandler.send_query_friend_room_id(uid)
            end
        end)
    end

    function FF._triggerQuery()
        local uids = FF._currentUIDs
        if type(uids) ~= "table" or #uids == 0 then return end
        FF._queryAttempts = {}
        for i, uid in ipairs(uids) do
            FF._queryAttempts[tostring(uid)] = 0
            local delay = (i - 1) * 0.2
            if delay <= 0 then
                pcall(function() FF._triggerQuerySingle(uid) end)
            else
                pcall(function()
                    local ticker = require("common.time_ticker")
                    if ticker and ticker.AddTimerOnce then
                        ticker.AddTimerOnce(delay, function()
                            pcall(function() FF._triggerQuerySingle(uid) end)
                        end)
                    end
                end)
            end
        end
    end

    -- Status sudah diterima? Hentikan retry per UID supaya tidak menembak
    -- query yang sama terus-menerus.
    local function _hasStatus(uid)
        local ok, has = pcall(function()
            local MM = require("client.module_framework.ModuleManager")
            local PSM = MM.GetModule(MM.CommonModuleConfig.PlayerStatusMgr)
            if not PSM or not PSM.statusMap then return false end
            return (PSM.statusMap[uid] or PSM.statusMap[tostring(uid)]) ~= nil
        end)
        return ok and has == true
    end
    FF._hasStatus = _hasStatus

    function FF._retryQueryIfNeeded()
        if type(FF._currentUIDs) ~= "table" or #FF._currentUIDs == 0 then return end
        local now = os.time()
        if (now - (FF._queryLastAttempt or 0)) < 2.0 then return end
        FF._queryLastAttempt = now
        for _, uid in ipairs(FF._currentUIDs) do
            local key = tostring(uid)
            local attempts = FF._queryAttempts[key] or 0
            if attempts < 6 and not FF._hasStatus(uid) then
                FF._queryAttempts[key] = attempts + 1
                pcall(function() FF._triggerQuerySingle(uid) end)
                if attempts == 0 then
                    print(string.format("[FORCE FRIEND] Query UID %s (attempt 1/6)", key))
                end
            end
        end
    end

    function FF.Boot()
        if _G.RapzhangConfig.ForceFriend ~= true then return end
        local uids = _G.RapzhangFriendUID and _G.RapzhangFriendUID.Load() or {}
        FF._currentUIDs = uids
        if type(uids) == "table" and #uids > 0 then
            FF._installHooks()
            FF._triggerQuery()
            pcall(function() if _G.RapzhangFakeFriendApply then _G.RapzhangFakeFriendApply(uids) end end)
            pcall(function() if _G.RapzhangStartFriendSync then _G.RapzhangStartFriendSync() end end)
        end
    end

    function FF.Tick()
        local enabled = _G.RapzhangConfig.ForceFriend == true
        if not enabled then
            if FF._hooked then FF._uninstallHooks() end
            if type(FF._currentUIDs) == "table" and #FF._currentUIDs > 0 then
                FF._currentUIDs = {}
                pcall(function()
                    if _G._nadFfClearAll then _G._nadFfClearAll() end
                end)
            end
            return
        end

        -- Force Friend hanya relevan di lobby. Saat in-match tidak ada
        -- friend list yang perlu di-refresh, jadi jangan scan file/query.
        local inMatch = false
        pcall(function() inMatch = (LobbySystem and LobbySystem.isInMatch) == true end)
        if inMatch then return end

        -- Tick berjalan 2-50 Hz; file UID cukup dibaca maksimal 2 dtk
        -- sekali (Load sudah punya cache internal).
        local now = os.time()
        if (now - (FF._lastScan or -999.0)) < 2.0 then
            FF._retryQueryIfNeeded()
            return
        end
        FF._lastScan = now

        local uids = _G.RapzhangFriendUID and _G.RapzhangFriendUID.Load() or {}
        local changed = not _G.RapzhangFriendUID.Equals(FF._currentUIDs, uids)
        if changed then
            FF._currentUIDs = uids
            if type(uids) == "table" and #uids > 0 then
                FF._installHooks()
                FF._triggerQuery()
                pcall(function() if _G.RapzhangFakeFriendApply then _G.RapzhangFakeFriendApply(uids) end end)
                pcall(function() if _G.RapzhangStartFriendSync then _G.RapzhangStartFriendSync() end end)
            else
                if FF._hooked then FF._uninstallHooks() end
            end
        elseif type(uids) == "table" and #uids > 0 and not FF._hooked then
            FF._installHooks()
            FF._triggerQuery()
            pcall(function() if _G.RapzhangFakeFriendApply then _G.RapzhangFakeFriendApply(uids) end end)
            pcall(function() if _G.RapzhangStartFriendSync then _G.RapzhangStartFriendSync() end end)
        end

        FF._retryQueryIfNeeded()
    end

    function FF.Refresh()
        if _G.RapzhangConfig.ForceFriend ~= true then
            if FF._hooked then FF._uninstallHooks() end
            FF._currentUIDs = {}
            return
        end
        local uids = _G.RapzhangFriendUID and _G.RapzhangFriendUID.Load() or {}
        if not _G.RapzhangFriendUID.Equals(FF._currentUIDs, uids) then
            FF._currentUIDs = uids
            if type(uids) == "table" and #uids > 0 then
                FF._installHooks()
                FF._triggerQuery()
            end
        end
    end

    print("[FORCE FRIEND] Module loaded (multi-UID, auto-retry 6x).")
end

-- ==========================================================
-- [AUTO PARACHUTE] MODULE
-- Uses the game's own auto-parachute path:
--   ParachuteComponent:SetAutoParachuteLocation(mark + Z offset)
--   PlayerController:EnableAutoParachute(true)
-- Read/write only through pcall so unsupported builds stay safe.
-- ==========================================================
if not _G.RapzhangAutoParachute then
    local AP = {}
    AP.Enabled = false
    AP.Applied = false
    AP.LastApply = -999.0
    AP.LastError = nil
    AP.ZOffset = 15000.0
    AP.MarkEpsilon = 0.1
    AP.MaxWorldCoord = 2000000.0
    AP.Jumped = false
    AP.LastJumpTry = -999.0
    AP.LastPlaneSeen = -999.0

    local function APValid(obj)
        if obj == nil then return false end
        local ok, v = pcall(function() return slua.isValid(obj) end)
        return ok and v == true
    end

    function AP.Now()
        local t = nil
        pcall(function() if os and os.clock then t = os.clock() end end)
        return tonumber(t) or 0.0
    end

    function AP.GetPC()
        local pc = nil
        pcall(function()
            if _G.ESP and _G.ESP.GetController then pc = _G.ESP.GetController() end
        end)
        if not APValid(pc) then
            pcall(function()
                local gd = _G.ESP and _G.ESP.GetGameplayData and _G.ESP.GetGameplayData() or nil
                if not gd then gd = require("GameLua.GameCore.Data.GameplayData") end
                if gd and gd.GetPlayerController then pc = gd.GetPlayerController() end
            end)
        end
        if not APValid(pc) then
            pcall(function()
                local hud = rawget(_G, "slua_GameFrontendHUD")
                if hud and hud.GetPlayerController then pc = hud:GetPlayerController() end
            end)
        end
        return APValid(pc) and pc or nil
    end

    function AP.GetCharacter(pc)
        local ch = nil
        pcall(function() if pc.GetPlayerCharacterSafety then ch = pc:GetPlayerCharacterSafety() end end)
        if not APValid(ch) then
            pcall(function() if pc.GetCurPlayerCharacter then ch = pc:GetCurPlayerCharacter() end end)
        end
        if not APValid(ch) then pcall(function() ch = pc.Pawn end) end
        return APValid(ch) and ch or nil
    end

    function AP.GetPlayerState(pc)
        local ps = nil
        pcall(function() if pc.GetCurPlayerState then ps = pc:GetCurPlayerState() end end)
        if not APValid(ps) then pcall(function() ps = pc.PlayerState end) end
        return APValid(ps) and ps or nil
    end

    -- PlayerState.MapMark is normalised map space. The game clears it to
    -- FVector(0,0,0) and writes Z=1 through SetPlayerMark for a real mark, so
    -- Z is the authoritative existence flag (see Game:GetPlayerMark3D and
    -- AutoParachuteUI:ActivateAutoParachute). X/Y length is only a fallback
    -- for builds that do not replicate Z.
    -- true = mark exists, false = definitely cleared, nil = unknown.
    function AP.HasMapMark(ps)
        if not APValid(ps) then return false end
        local mm, ok = nil, false
        pcall(function() mm = ps.MapMark ok = true end)
        if not ok or mm == nil then return nil end
        local mx, my, mz = nil, nil, nil
        ok = pcall(function()
            mx, my, mz = tonumber(mm.X), tonumber(mm.Y), tonumber(mm.Z)
        end)
        if not ok then return nil end
        if not mx or not my or mx ~= mx or my ~= my then return nil end
        if mz ~= nil then
            if mz ~= mz then return nil end
            -- The game clears all three components with FVector(0,0,0).
            -- Z=0 alone is not enough on forks that do not replicate the
            -- flag, so only the full zero vector is "definitely cleared".
            if mz == 0.0 and mx == 0.0 and my == 0.0 then return false end
            return true
        end
        return (mx * mx + my * my) > 0.0
    end

    -- A usable target is a finite world-space vector. World (0,0) is the
    -- map-centre origin and doubles as the cleared-mark value, so a vector
    -- with both X and Y at ~0 is never a real target (same rule as AirLineUI).
    function AP.IsValidMapMark(loc)
        if loc == nil then return false end
        local x, y, ok = nil, nil, false
        ok = pcall(function() x, y = tonumber(loc.X), tonumber(loc.Y) end)
        if not ok or not x or not y then return false end
        if x ~= x or y ~= y then return false end
        if math.abs(x) == math.huge or math.abs(y) == math.huge then return false end
        if math.abs(x) < AP.MarkEpsilon and math.abs(y) < AP.MarkEpsilon then return false end
        if math.abs(x) > AP.MaxWorldCoord or math.abs(y) > AP.MaxWorldCoord then return false end
        return true
    end

    function AP.GetMapMarkLocation(pc)
        local ps = AP.GetPlayerState(pc)
        if not ps then return nil end
        -- A cleared MapMark is authoritative even if GetMapMark3DLocation
        -- still returns a stale vector.
        if AP.HasMapMark(ps) == false then return nil end
        local loc = nil
        pcall(function()
            if ps.GetMapMark3DLocation then loc = ps:GetMapMark3DLocation() end
        end)
        if AP.IsValidMapMark(loc) then return loc end
        -- Fallback: only accept MapMark when it already looks like world units.
        -- On this game MapMark itself is normalised map space; the native
        -- GetMapMark3DLocation is the world-space source.
        loc = nil
        pcall(function()
            local mm = ps.MapMark
            local mx, my = tonumber(mm and mm.X), tonumber(mm and mm.Y)
            if mx and my and (mx * mx + my * my) > 100000000 then
                loc = { X = mx, Y = my, Z = 0 }
            end
        end)
        if AP.IsValidMapMark(loc) then return loc end
        return nil
    end

    function AP.GetStateType(pc)
        local st = nil
        pcall(function() if pc.GetCurrentStateType then st = pc:GetCurrentStateType() end end)
        return st
    end

    function AP.InPlane(pc)
        if not pc then return false end
        local inPlane = false
        pcall(function() if pc.IsInPlane then inPlane = pc:IsInPlane() == true end end)
        if not inPlane then
            local st = AP.GetStateType(pc)
            if EStateType and st ~= nil and st == EStateType.State_InPlane then
                inPlane = true
            end
        end
        return inPlane
    end

    -- The character is attached to the plane while boarding, so its location is
    -- the best fallback when the view target is a camera/sequencer actor.
    function AP.GetPlaneLocation(pc, ch)
        local loc = nil
        pcall(function()
            if APValid(ch) and ch.K2_GetActorLocation then loc = ch:K2_GetActorLocation() end
        end)
        if not loc then
            pcall(function()
                if pc and pc.GetViewTarget then
                    local vt = pc:GetViewTarget()
                    if APValid(vt) and vt.K2_GetActorLocation then loc = vt:K2_GetActorLocation() end
                end
            end)
        end
        if not loc then
            pcall(function()
                local pawn = pc and pc.Pawn
                if APValid(pawn) and pawn.K2_GetActorLocation then loc = pawn:K2_GetActorLocation() end
            end)
        end
        if loc and tonumber(loc.X) and tonumber(loc.Y) then return loc end
        return nil
    end

    function AP.ResetJumpIfLeftPlane(pc)
        if not AP.Jumped then return end
        if pc == nil then return end
        if (AP.Now() - (AP.LastJumpTry or -999.0)) <= 5.0 then return end
        if AP.InPlane(pc) then return end
        AP.Jumped = false
    end

    function AP.TryAutoJump(pc, ch, mark)
        if _G.RapzhangConfig.AutoJump ~= true then return false end
        if not AP.InPlane(pc) then
            AP.ResetJumpIfLeftPlane(pc)
            return false
        end
        AP.LastPlaneSeen = AP.Now()
        if AP.Jumped then return false end
        if not AP.IsValidMapMark(mark) then mark = AP.GetMapMarkLocation(pc) end
        if not AP.IsValidMapMark(mark) then return false end
        local plane = AP.GetPlaneLocation(pc, ch)
        if not plane then return false end
        local dx = (tonumber(plane.X) or 0.0) - (tonumber(mark.X) or 0.0)
        local dy = (tonumber(plane.Y) or 0.0) - (tonumber(mark.Y) or 0.0)
        local distM = math.sqrt(dx * dx + dy * dy) / 100.0
        local radius = tonumber(_G.RapzhangConfig.AutoJumpRadius) or 300
        if radius < 50 then radius = 50 end
        if radius > 1500 then radius = 1500 end
        if distM > radius then return false end
        local ok = false
        pcall(function()
            if pc.JumpFromPlane then
                pc:JumpFromPlane()
                ok = true
            end
        end)
        if ok then
            AP.Jumped = true
            AP.LastJumpTry = AP.Now()
            print(string.format("[AUTO PARACHUTE] Auto jump at %.0fm from mark (radius %.0fm)", distM, radius))
        end
        return ok
    end

    function AP.Apply(mark)
        local pc = AP.GetPC()
        if not pc then AP.LastError = "no controller" return false end
        local loc = mark
        if not AP.IsValidMapMark(loc) then loc = AP.GetMapMarkLocation(pc) end
        if not AP.IsValidMapMark(loc) then
            AP.LastError = "no map mark"
            if AP.Applied then pcall(AP.Disable) end
            return false
        end
        local comp = nil
        pcall(function() if pc.GetParachuteComponent then comp = pc:GetParachuteComponent() end end)
        if not APValid(comp) then AP.LastError = "no parachute component" return false end
        local tx = tonumber(loc.X) or 0.0
        local ty = tonumber(loc.Y) or 0.0
        local tz = tonumber(loc.Z) or 0.0
        if tz ~= tz or math.abs(tz) == math.huge then tz = 0.0 end
        tz = tz + AP.ZOffset
        local target = nil
        pcall(function() if FVector then target = FVector(tx, ty, tz) end end)
        if not target then target = { X = tx, Y = ty, Z = tz } end
        local ok = false
        pcall(function()
            comp:SetAutoParachuteLocation(target)
            ok = true
        end)
        if not ok then AP.LastError = "set location failed" return false end
        pcall(function() if pc.EnableAutoParachute then pc:EnableAutoParachute(true) end end)
        AP.Applied = true
        AP.LastApply = AP.Now()
        AP.LastError = nil
        return true
    end

    function AP.Disable()
        local pc = AP.GetPC()
        if pc then
            pcall(function() if pc.EnableAutoParachute then pc:EnableAutoParachute(false) end end)
        end
        AP.Applied = false
    end

    function AP.Set(enabled)
        _G.RapzhangConfig.AutoParachute = enabled == true
        if _G.RapzhangConfig.AutoParachute then
            AP.Jumped = false
            local ok = false
            pcall(function() ok = AP.Apply() end)
            AP.Enabled = ok == true
        else
            AP.Enabled = false
            pcall(AP.Disable)
        end
        if _G.SaveModSettings then pcall(_G.SaveModSettings) end
        return true
    end

    function AP.IsAirborneState(pc, ch)
        local ps = nil
        pcall(function() ps = ch.ParachuteState end)
        if EParachuteState then
            if ps == EParachuteState.PS_FreeFall or ps == EParachuteState.PS_Opening then
                return true
            end
        end
        local st = AP.GetStateType(pc)
        if EStateType and st ~= nil then
            if st == EStateType.State_InPlane or st == EStateType.State_ParachuteJump then
                return true
            end
        end
        return false
    end

    function AP.Tick()
        if _G.RapzhangConfig.AutoParachute ~= true then
            if AP.Applied then pcall(AP.Disable) end
            AP.Enabled = false
            return
        end
        local pc = AP.GetPC()
        if not pc then
            if AP.Applied then pcall(AP.Disable) end
            AP.Enabled = false
            return
        end
        -- Tanpa map mark fitur harus idle walau toggle ON: jangan pernah
        -- memasang target dan jangan pernah JumpFromPlane.
        local loc = AP.GetMapMarkLocation(pc)
        if not AP.IsValidMapMark(loc) then
            if AP.Applied then pcall(AP.Disable) end
            AP.ResetJumpIfLeftPlane(pc)
            AP.Enabled = false
            return
        end
        AP.Enabled = true
        local ch = AP.GetCharacter(pc)
        if not ch then return end
        pcall(AP.TryAutoJump, pc, ch, loc)
        if not AP.IsAirborneState(pc, ch) then
            if AP.Applied then pcall(AP.Disable) end
            return
        end
        local now = AP.Now()
        if (now - (AP.LastApply or -999.0)) >= 0.50 then
            pcall(AP.Apply, loc)
        end
    end

    _G.RapzhangAutoParachute = AP
    _G.RapzhangAutoParachuteTick = function()
        pcall(AP.Tick)
    end
    print("[AUTO PARACHUTE] Module loaded.")
end


-- MULAI: ESP CORE (replaced from esp new.lua)
-- Only the ESP implementation is replaced; adjacent systems remain unchanged.
local ESP_Enabled = true

local FVector2D = _G.FVector2D or import("Vector2D")
local FLinearColor = _G.FLinearColor or import("LinearColor")
local SlateBlueprintLibrary = nil
local WidgetLayoutLibrary = nil
local SlateColor = nil
local GameplayStaticsESP = nil
pcall(function() SlateBlueprintLibrary = import("SlateBlueprintLibrary") end)
pcall(function() WidgetLayoutLibrary = import("WidgetLayoutLibrary") end)
pcall(function() SlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor") end)
pcall(function() GameplayStaticsESP = import("GameplayStatics") end)
local KismetSystemLibraryESP = nil
local HitResultClassESP = nil
pcall(function() KismetSystemLibraryESP = import("KismetSystemLibrary") end)
pcall(function() HitResultClassESP = import("HitResult") end)
local TraceStartPos = { X = 0, Y = 0, Z = 0 }
local CachedHitResult = nil
pcall(function()
  if HitResultClassESP then CachedHitResult = HitResultClassESP()
  else CachedHitResult = {} end
end)

local function ESPValid(obj)
  if obj == nil then return false end
  local ok, v = pcall(function() return slua.isValid(obj) end)
  return ok and v == true
end

local function ESPV2(x, y)
  if FVector2D then return FVector2D(x, y) end
  return { X = x, Y = y }
end

local function ESPMKC(r, g, b, a)
  if FLinearColor then return FLinearColor(r, g, b, a) end
  return { R = r, G = g, B = b, A = a }
end

local CFG = {
  MaxDistance = 6000000,     -- cm (60 km, effectively full map like the previous ESP)
  MaxTracked = 24,
  ScreenMargin = 220,
  TopTextY = 6.0,           -- canvas px, bilkul upar center
  SnapOriginY = 0.0,        -- top edge se start (esplook jaisa)
  SnapThickness = 1.8,
  CornerThickness = 2.2,
  CornerLen = 0.28,
  CornerMin = 6,
  CornerMax = 28,
  BoxMinWidth = 22,
  BoxMaxWidth = 320,
  BoxMinHeight = 2,     -- keep distant targets visible; do not cut off around 87 m
  BoxWidthFactor = 0.62,
  WidthScale = 1.22,
  HeadExtra = 0.06,
  FootExtra = 0.02,
  SideBarWidth = 3.5,
  SideBarGap = 5.0,
  SideBgAlpha = 0.55,
  NameFontSize = 12,
  DistFontSize = 10,
  StateFontSize = 10,
  TextGap = 1.0,
  CounterFontSize = 14,
  CounterW = 300.0,
  CounterH = 28.0,
  DeadZone = 0.5,           -- px, isse kam harkat = slate ko chhuna nahi (flicker fix)
  VisInterval = 0.50,       -- sec, cached visibility trace per target (performance)
  SizeHyst = 2.0,           -- px, viewport me itna farq ignore
}

-- esplook.png colors
local C_WHITE  = ESPMKC(1.0, 1.0, 1.0, 1.0)
local C_BLACK  = ESPMKC(0.0, 0.0, 0.0, 1.0)
local C_GREEN  = ESPMKC(0.12, 1.0, 0.25, 1.0)   -- snap line + "Open"
local C_RED    = ESPMKC(1.0, 0.15, 0.15, 1.0)   -- low health + "Close"
local C_YELLOW = ESPMKC(1.0, 0.90, 0.30, 1.0)   -- double chevron
local C_BLUE   = ESPMKC(0.38, 0.72, 1.0, 1.0)   -- "Bot" name
local C_ORANGE = ESPMKC(1.0, 0.55, 0.18, 1.0)   -- aim line / self-rescue badge

local function RND(v)
  if v ~= v then return 0 end
  return math.floor(v + 0.5)
end

local function Lerp(a, b, t) return a + (b - a) * t end

-- Health color: 100% green | 70% green+halka yellow | 40% red+halka white | 20% red
local function HealthColor(pct)
  pct = tonumber(pct) or 1.0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  local r, g, b
  if pct >= 0.7 then
    local t = (pct - 0.7) / 0.3
    r = Lerp(0.75, 0.12, t)
    g = 1.0
    b = Lerp(0.15, 0.25, t)
  elseif pct >= 0.4 then
    local t = (pct - 0.4) / 0.3
    r = 1.0
    g = Lerp(0.45, 0.95, t)
    b = Lerp(0.45, 0.20, t)
  else
    local t = pct / 0.4
    r = 1.0
    g = Lerp(0.15, 0.45, t)
    b = Lerp(0.15, 0.45, t)
  end
  return ESPMKC(r, g, b, 1.0)
end

local ESP = {}
ESP.Canvas = nil
ESP.Lines = {}      -- snap lines : key -> {Widget, Slot}
ESP.AimLines = {}   -- enemy aim lines: key -> {Widget, Slot}
ESP.Corners = {}    -- corner boxes: key -> {w1..w8 Widget/Slot}
ESP.HealthBg = {}   -- health bg (dark) : key -> {Widget, Slot}
ESP.HealthFill = {} -- health fill (pct + color) : key -> {Widget, Slot}
ESP.Infos = {}      -- bottom texts: key -> {Container, Name, Dist, State, slots}
ESP.Counter = nil   -- top "Players: X | Bots: Y"
ESP.EnemyCache = {}
ESP.RadarMarks = {}
ESP.VisCache = {}   -- visibility cache: key -> {b, t}
ESP.ScaleX = 1.0
ESP.ScaleY = 1.0
ESP.OffsetX = 0.0
ESP.OffsetY = 0.0
ESP.ViewW = 1920
ESP.ViewH = 1080
ESP.ScanInterval = 0.50
ESP.LightInterval = 0.080
ESP.TransformInterval = 0.75
ESP.LastScan = -999.0
ESP.LastTransform = -999.0
ESP.LastWorld = nil
ESP.bActive = false
-- Mode hemat resource (menu GRAPHIC). OFF = perilaku lama persis.
ESP.LowEnd = false
ESP.LootInterval = 0.55
ESP.VehInterval = 0.45
ESP.SquadInterval = 0.80
ESP.LootCap = 70
ESP.SweepTTL = 3.0
ESP.CacheTTL = 30.0
ESP.LowTickInterval = 0.080
ESP.AirdropInterval = 0.80
ESP.GrenadeInterval = 0.45
ESP.ZoneRingSegments = 20
ESP.GrenadeRingSegments = 18

function ESP.SetLowEnd(on)
  on = on == true
  ESP.LowEnd = on
  -- Profil low-end lebih agresif: target, scan, dan widget dikurangi lagi
  -- supaya HP kelas bawah tidak memproses puluhan label/garis tiap tick.
  CFG.MaxTracked = on and 12 or 24
  CFG.VisInterval = on and 2.00 or 0.50
  ESP.ScanInterval = on and 0.90 or 0.50
  ESP.TransformInterval = on and 1.20 or 0.75
  ESP.LootInterval = on and 1.10 or 0.55
  ESP.VehInterval = on and 1.10 or 0.45
  ESP.SquadInterval = on and 1.50 or 0.80
  ESP.LootCap = on and 24 or 70
  ESP.SweepTTL = on and 0.90 or 3.0
  ESP.CacheTTL = on and 8.0 or 30.0
  ESP.LowTickInterval = on and 0.150 or 0.080
  ESP.AirdropInterval = on and 1.20 or 0.80
  ESP.GrenadeInterval = on and 0.70 or 0.45
  ESP.ZoneRingSegments = on and 12 or 20
  ESP.GrenadeRingSegments = on and 12 or 18
  if on then
    -- Buang label/cache basi saat mode diaktifkan supaya penghematan
    -- langsung terasa, bukan menunggu TTL/scan berikutnya.
    pcall(function()
      if ESP.Adv and ESP.Adv.TrimLootCache then ESP.Adv.TrimLootCache(ESP.LootCap) end
      if ESP.Adv and ESP.Adv.SyncLootLabels then ESP.Adv.SyncLootLabels() end
      if ESP.Extra and ESP.Extra.Sweep then ESP.Extra.Sweep(ESP.Now(), ESP.SweepTTL) end
    end)
  end
end

function ESP.GetGameplayData()
  if ESP._GDP then return ESP._GDP end
  local ok, GDP = pcall(function() return require("GameLua.GameCore.Data.GameplayData") end)
  if ok and GDP then ESP._GDP = GDP return GDP end
  return nil
end

function ESP.GetController()
  local pc = nil
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP and GDP.GetPlayerController then pc = GDP.GetPlayerController() end
  end)
  if not ESPValid(pc) then
    pcall(function()
      if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
    end)
  end
  return ESPValid(pc) and pc or nil
end

function ESP.GetLocalCharacter()
  local c = nil
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP then
      if GDP.GetPlayerCharacter then c = GDP.GetPlayerCharacter() end
      if not ESPValid(c) and GDP.GetLocalCharacter then c = GDP.GetLocalCharacter() end
    end
  end)
  if not ESPValid(c) then
    local pc = ESP.GetController()
    pcall(function() if pc and pc.GetPawn then c = pc:GetPawn() end end)
  end
  return ESPValid(c) and c or nil
end

function ESP.GetAllCharacters()
  local AllChars = {}
  pcall(function()
    local Pawns = Game:GetAllPlayerPawns()
    if Pawns then
      for _, Pawn in pairs(Pawns) do
        if Pawn and slua.isValid(Pawn) then
          local pKey = nil
          if Pawn.GetPlayerKey then pcall(function() pKey = Pawn:GetPlayerKey() end) end
          if not pKey and Pawn.PlayerKey then pKey = Pawn.PlayerKey end
          if not pKey and Pawn.PlayerState and Pawn.PlayerState.PlayerKey then pKey = Pawn.PlayerState.PlayerKey end
          if pKey then AllChars[pKey] = Pawn end
        end
      end
    end
  end)
  if not next(AllChars) then
    pcall(function()
      local GS = require("GameLua.GameCore.Data.CGameState")
      if GS and GS.GetAllCharacters then AllChars = GS:GetAllCharacters() end
    end)
  end
  return AllChars
end

function ESP.GetMyPlayerKey()
  local pc = ESP.GetController()
  if not ESPValid(pc) then return nil end
  local k = nil
  pcall(function()
    if pc.GetPlayerKey then k = pc:GetPlayerKey()
    elseif pc.PlayerState and pc.PlayerState.PlayerKey then k = pc.PlayerState.PlayerKey end
  end)
  return k
end

function ESP.IsMe(Character, PlayerKey, MyKey)
  local me = false
  pcall(function()
    local GDP = ESP.GetGameplayData()
    if GDP and GDP.GetLocalCharacter then
      local mc = GDP.GetLocalCharacter()
      if mc and Character == mc then me = true return end
    end
    local pc = ESP.GetController()
    if pc and pc.GetPawn then
      local p = pc:GetPawn()
      if p and Character == p then me = true return end
    end
  end)
  if not me and MyKey ~= nil and PlayerKey ~= nil then
    me = (tostring(PlayerKey) == tostring(MyKey))
  end
  return me
end

function ESP.GetTeamID(Character)
  if not ESPValid(Character) then return nil end
  local id = nil
  pcall(function() if Character.GetTeamID then id = Character:GetTeamID() end end)
  if id == nil then pcall(function() id = Character.TeamID end) end
  if id == nil then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then ps = Character:GetPlayerState() end
    end)
    if not ESPValid(ps) then pcall(function() ps = Character.PlayerState end) end
    if ESPValid(ps) then
      pcall(function() if ps.GetTeamID then id = ps:GetTeamID() end end)
      if id == nil then pcall(function() id = ps.TeamID end) end
    end
  end
  return id
end

function ESP.IsAlive(Character)
  if not ESPValid(Character) then return false end
  local alive = nil
  pcall(function() if Character.IsAlive then alive = Character:IsAlive() end end)
  if type(alive) == "boolean" then return alive end
  local hp = nil
  pcall(function() hp = Character.Health end)
  if type(hp) ~= "number" then pcall(function() hp = Character.HP end) end
  if type(hp) == "number" then return hp > 0 end
  return true
end

function ESP.IsKnocked(Character)
  if not ESPValid(Character) then return false end
  local k = false
  pcall(function()
    if Character.HealthStatus == 1 then k = true end
  end)
  if not k then pcall(function()
    if Character.IsNearDeath and Character:IsNearDeath() then k = true end
  end) end
  return k
end

-- Apakah pawn masih bisa self-rescue (item/feature tersedia). Hanya dipanggil
-- saat target knocked; cache-nya ada di ESP.UpdateInfo (0,5 detik).
function ESP.CanSelfRescue(Character)
  if not ESPValid(Character) then return false end
  local v = nil
  pcall(function() if Character.CanSelfRescue then v = Character:CanSelfRescue() end end)
  if type(v) == "boolean" then return v end
  pcall(function() v = Character.bCanSelfRescue end)
  return v == true
end

function ESP.IsBot(Character)
  if not ESPValid(Character) then return false end
  local bAI = false
  pcall(function()
    if Game and Game.IsAI then bAI = Game:IsAI(Character) end
    if not bAI and Character then
      if Character.bEnsure == true or Character.bMEnsure == true then bAI = true
      elseif Character.PlayerState and Character.PlayerState.bPSEnsure == true then bAI = true
      elseif Character.Controller then
        if Character.Controller.IsMLAI == true or Character.Controller.FakePlayerBornType == 1 then bAI = true end
      end
    end
  end)
  if not bAI then
    pcall(function()
      if Character.bIsAI == true then bAI = true end
    end)
  end
  if not bAI then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety() end
    end)
    if ESPValid(ps) then
      pcall(function()
        if ps.bIsABot == true or ps.bIsBot == true or ps.bIsAI == true then bAI = true end
      end)
    end
  end
  return bAI
end

function ESP.GetPlayerKey(Character)
  if Character == nil then return "nil" end
  local key = nil
  pcall(function() if Character.GetPlayerKey then key = Character:GetPlayerKey() end end)
  if key == nil then pcall(function() key = Character.PlayerKey end) end
  if key == nil then
    -- Jangan langsung pakai tostring(Character): wrapper slua bisa berbeda
    -- antar frame dan membuat panel baru terus-menerus untuk target yang sama.
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety() end
    end)
    if not ESPValid(ps) then pcall(function() ps = Character.PlayerState end) end
    if ESPValid(ps) then
      pcall(function() key = ps.PlayerKey end)
      if key == nil then pcall(function() key = ps.UID end) end
    end
  end
  if key == nil then pcall(function() key = Character.UID end) end
  local n = tonumber(key)
  if n then return string.format("%.0f", n) end
  return tostring(key or Character)
end

function ESP.GetHealthPct(Character)
  if not ESPValid(Character) then return 1.0 end
  local hp, maxhp = nil, nil
  pcall(function() hp = Character.Health end)
  if type(hp) ~= "number" then pcall(function() hp = Character.HP end) end
  pcall(function() maxhp = Character.MaxHealth end)
  if type(maxhp) ~= "number" then pcall(function() maxhp = Character.MaxHP end) end
  if type(hp) ~= "number" then return 1.0 end
  if type(maxhp) ~= "number" or maxhp <= 0 then maxhp = 100 end
  local pct = hp / maxhp
  if pct ~= pct then return 1.0 end
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  return pct
end

local function NormalizeName(v)
  if v == nil or v == false then return nil end
  local ok, t = pcall(tostring, v)
  if not ok or not t then return nil end
  t = t:gsub("^%s+", ""):gsub("%s+$", "")
  if t == "" or t == "nil" or t == "None" or t == "NULL" or t == "Unknown" then return nil end
  return t
end

function ESP.ResolveName(Character, isBot)
  if isBot then return "Bot" end
  local name = nil
  local function take(v)
    if not name then name = NormalizeName(v) end
  end
  pcall(function() if Character.GetPlayerNameSafety then take(Character:GetPlayerNameSafety()) end end)
  pcall(function() if not name and Character.GetPlayerName then take(Character:GetPlayerName()) end end)
  pcall(function() if not name then take(Character.PlayerName) end end)
  pcall(function() if not name then take(Character.NickName) end end)
  if not name then
    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety()
      elseif Character.GetPlayerState then ps = Character:GetPlayerState() end
    end)
    if not ESPValid(ps) then pcall(function() ps = Character.PlayerState end) end
    if ESPValid(ps) then
      pcall(function() if ps.GetPlayerName then take(ps:GetPlayerName()) end end)
      pcall(function() if not name then take(ps.PlayerName) end end)
      pcall(function() if not name then take(ps.PlayerNamePrivate) end end)
      pcall(function() if not name then take(ps.NickName) end end)
    end
  end
  return name or "Player"
end

function ESP.GetBonePos(Character, boneName)
  if not ESPValid(Character) or not boneName then return nil end
  local pos = nil
  pcall(function()
    if type(Character.GetBonePos) == "function" then
      pos = Character:GetBonePos(boneName, { X = 0, Y = 0, Z = 0 })
    end
    if not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then
      if type(Character.GetSocketLocation) == "function" then
        pos = Character:GetSocketLocation(boneName)
      end
    end
    if (not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0)) and ESPValid(Character.Mesh) then
      local mesh = Character.Mesh
      if mesh and mesh.GetSocketLocation then
        local mp = mesh:GetSocketLocation(boneName)
        if mp and not (mp.X == 0 and mp.Y == 0 and mp.Z == 0) then pos = mp end
      end
    end
  end)
  return pos
end

function ESP.GetCamLoc(pc)
  local loc = nil
  pcall(function()
    if GameplayStaticsESP and GameplayStaticsESP.GetPlayerCameraManager then
      local mgr = GameplayStaticsESP.GetPlayerCameraManager(pc, 0)
      if ESPValid(mgr) and mgr.GetCameraLocation then loc = mgr:GetCameraLocation() end
    end
  end)
  if not loc then
    pcall(function()
      if pc and pc.GetPawn then
        local p = pc:GetPawn()
        if ESPValid(p) and p.K2_GetActorLocation then loc = p:K2_GetActorLocation() end
      end
    end)
  end
  return loc
end

function ESP.IsBoneVisible(pc, camLoc, target, bonePos)
  if not ESPValid(pc) or not ESPValid(target) or not bonePos or not camLoc then return false end
  if not KismetSystemLibraryESP or not KismetSystemLibraryESP.LineTraceSingle then return true end
  local dx = bonePos.X - camLoc.X
  local dy = bonePos.Y - camLoc.Y
  local dz = bonePos.Z - camLoc.Z
  local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
  if dist < 50 then return true end
  TraceStartPos.X = camLoc.X + (dx / dist) * 60
  TraceStartPos.Y = camLoc.Y + (dy / dist) * 60
  TraceStartPos.Z = camLoc.Z + (dz / dist) * 60
  local bVis = false
  pcall(function()
    local bHit = KismetSystemLibraryESP.LineTraceSingle(
      pc, TraceStartPos, bonePos, 0, false, nil, 0, CachedHitResult, true)
    if bHit then
      local hitActor = nil
      if CachedHitResult then
        if type(CachedHitResult.GetActor) == "function" then
          hitActor = CachedHitResult:GetActor()
        elseif CachedHitResult.Actor then
          hitActor = CachedHitResult.Actor
        end
      end
      if ESPValid(hitActor) then
        if hitActor == target then bVis = true end
      end
    else
      bVis = true
    end
  end)
  return bVis
end

function ESP.IsVisible(key, pc, camLoc, Character)
  local now = ESP.Now()
  local cached = ESP.VisCache[key]
  if cached and (now - (cached.t or 0)) < (CFG.VisInterval or 0.15) then
    return cached.b
  end
  local bVis = false
  if ESPValid(Character) and ESPValid(pc) and camLoc then
    local bones = { "head", "spine_03", "pelvis" }
    for _, bn in ipairs(bones) do
      local bp = ESP.GetBonePos(Character, bn)
      if bp and (bp.X ~= 0 or bp.Y ~= 0 or bp.Z ~= 0) then
        if ESP.IsBoneVisible(pc, camLoc, Character, bp) then bVis = true break end
      end
    end
  else
    bVis = true
  end
  ESP.VisCache[key] = { b = bVis, t = now }
  return bVis
end

function ESP.ActorLocation(Character)
  local loc = nil
  if not ESPValid(Character) then return nil end
  pcall(function()
    if Character.K2_GetActorLocation then loc = Character:K2_GetActorLocation()
    elseif Game and Game.GetActorLocation then loc = Game:GetActorLocation(Character) end
  end)
  return loc
end

function ESP.DistMeters(a, b)
  if not a or not b then return math.huge end
  local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
  return math.sqrt(dx * dx + dy * dy + dz * dz) / 100.0
end

function ESP.GetVerticalBounds(Character)
  if not ESPValid(Character) then return nil, nil end
  local center, halfHeight = nil, nil
  local capsule = nil
  pcall(function()
    if Character.GetCapsuleComponent then capsule = Character:GetCapsuleComponent()
    elseif Character.CapsuleComponent then capsule = Character.CapsuleComponent end
  end)
  if capsule and ESPValid(capsule) then
    pcall(function()
      if capsule.K2_GetComponentLocation then center = capsule:K2_GetComponentLocation()
      elseif capsule.GetComponentLocation then center = capsule:GetComponentLocation() end
      if capsule.GetScaledCapsuleHalfHeight then halfHeight = capsule:GetScaledCapsuleHalfHeight()
      elseif capsule.GetUnscaledCapsuleHalfHeight then halfHeight = capsule:GetUnscaledCapsuleHalfHeight()
      elseif capsule.CapsuleHalfHeight then halfHeight = capsule.CapsuleHalfHeight end
    end)
  end
  if not center then
    pcall(function() if Character.K2_GetActorLocation then center = Character:K2_GetActorLocation() end end)
  end
  if not center then
    pcall(function() if Game and Game.GetActorLocation then center = Game:GetActorLocation(Character) end end)
  end
  if not center then return nil, nil end
  if not halfHeight or halfHeight < 10 or halfHeight > 200 then
    halfHeight = 85
    pcall(function()
      if Character.bIsCrouched then halfHeight = 60 end
      if Character.IsProne and Character:IsProne() then halfHeight = 25 end
    end)
  end
  return center, halfHeight
end

function ESP.GetHeadFeet(Character)
  local center, half = ESP.GetVerticalBounds(Character)
  if not center or not half then return nil, nil end
  local head = { X = center.X, Y = center.Y, Z = center.Z + half }
  local feet = { X = center.X, Y = center.Y, Z = center.Z - half }
  return head, feet
end

-- Arah bidik pawn dalam world space. GetViewRotation adalah sumber utama
-- (replikasi aim remote pawn), fallback ke base aim/actor rotation.
function ESP.GetAimDir(Character)
  if not ESPValid(Character) then return nil end
  local rot = nil
  pcall(function() if Character.GetViewRotation then rot = Character:GetViewRotation() end end)
  if rot == nil then
    pcall(function() if Character.GetBaseAimRotation then rot = Character:GetBaseAimRotation() end end)
  end
  if rot == nil then
    pcall(function() if Character.K2_GetActorRotation then rot = Character:K2_GetActorRotation() end end)
  end
  if rot == nil then
    pcall(function() if Character.GetActorRotation then rot = Character:GetActorRotation() end end)
  end
  if rot == nil then return nil end
  local pitch, yaw = nil, nil
  pcall(function() pitch = tonumber(rot.Pitch) end)
  pcall(function() yaw = tonumber(rot.Yaw) end)
  if pitch == nil or yaw == nil then return nil end
  local p = math.rad(pitch)
  local y = math.rad(yaw)
  local cp = math.cos(p)
  return { X = cp * math.cos(y), Y = cp * math.sin(y), Z = math.sin(p) }
end

-- Garis pendek dari kepala target mengikuti arah bidiknya. Merah bila sudut
-- bidik mengarah ke kepala pemain lokal (< ~10 derajat) dalam 150 m.
function ESP.DrawAimLine(key, pc, Character, headWorld, headS, meHead)
  local data = ESP.AimLines[key]
  if not (ESP.Menu and ESP.Menu.ShowAimLine) or not headWorld or not headS then
    if data then ESP.Hide(data) end
    return
  end
  local dir = ESP.GetAimDir(Character)
  if not dir then
    if data then ESP.Hide(data) end
    return
  end
  local len = 900.0
  local endS = ESP.Project(pc, {
    X = headWorld.X + dir.X * len,
    Y = headWorld.Y + dir.Y * len,
    Z = headWorld.Z + dir.Z * len,
  })
  if not endS then
    if data then ESP.Hide(data) end
    return
  end
  local color = C_ORANGE
  if meHead then
    local dx = meHead.X - headWorld.X
    local dy = meHead.Y - headWorld.Y
    local dz = meHead.Z - headWorld.Z
    local d2 = dx * dx + dy * dy + dz * dz
    local distM = math.sqrt(d2) / 100.0
    if distM > 0.1 and distM <= 150.0 then
      local dot = (dx * dir.X + dy * dir.Y + dz * dir.Z) / math.sqrt(d2)
      if dot >= 0.985 then color = C_RED end
    end
  end
  data = data or ESP.NewLine(C_ORANGE, 34)
  if not data then return end
  ESP.AimLines[key] = data
  if data.aimColor ~= color then
    data.aimColor = color
    pcall(function() data.Widget:SetBrushColor(color) end)
  end
  ESP.DrawLine(data, headS.X, headS.Y, endS.X, endS.Y, 1.6)
end

function ESP.Now()
  local t = nil
  pcall(function()
    local w = (slua and slua.getWorld and slua.getWorld()) or nil
    if GameplayStaticsESP and w and GameplayStaticsESP.GetRealTimeSeconds then
      t = GameplayStaticsESP.GetRealTimeSeconds(w)
    end
  end)
  if tonumber(t) then return tonumber(t) end
  pcall(function() if os and os.clock then t = os.clock() end end)
  return tonumber(t) or 0.0
end

function ESP.World()
  local w = nil
  pcall(function() if slua and slua.getWorld then w = slua.getWorld() end end)
  return w
end

-- ---------- canvas ----------
function ESP.GetCanvas()
  if ESPValid(ESP.Canvas) then return ESP.Canvas end
  local root = nil
  pcall(function()
    local InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
    if InGameUITools and InGameUITools.GetMainControlBaseUI then root = InGameUITools.GetMainControlBaseUI() end
  end)
  if not ESPValid(root) then return nil end
  local canvas = nil
  pcall(function()
    if ESPValid(root.CanvasPanel_0) then canvas = root.CanvasPanel_0
    elseif ESPValid(root.CanvasPanel_42) then canvas = root.CanvasPanel_42 end
  end)
  if ESPValid(canvas) then
    -- UI in-game dibangun ulang: widget lama menempel ke canvas yang sudah
    -- mati. Reset supaya panel baru dibuat di canvas yang baru.
    if ESP.Canvas ~= nil and ESP.Canvas ~= canvas then
      pcall(ESP.ResetWidgets)
    end
    ESP.Canvas = canvas
    return canvas
  end
  return nil
end

function ESP.UpdateCanvasTransform(pc)
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return false end
  local calibrated = false
  pcall(function()
    if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
      local geo = canvas:GetCachedGeometry()
      if geo then
        local p0 = SlateBlueprintLibrary.AbsoluteToLocal(geo, ESPV2(0, 0))
        local p1 = SlateBlueprintLibrary.AbsoluteToLocal(geo, ESPV2(100, 100))
        if p0 and p1 and tonumber(p0.X) and tonumber(p1.X) and p1.X ~= p0.X and p1.Y ~= p0.Y then
          ESP.ScaleX = (p1.X - p0.X) / 100.0
          ESP.ScaleY = (p1.Y - p0.Y) / 100.0
          ESP.OffsetX = p0.X
          ESP.OffsetY = p0.Y
          calibrated = true
        end
      end
    end
  end)
  if not calibrated then
    local scale = 1.0
    pcall(function()
      if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
        local s = WidgetLayoutLibrary.GetViewportScale(pc)
        if tonumber(s) and s > 0 then scale = s end
      end
    end)
    ESP.ScaleX = 1.0 / scale
    ESP.ScaleY = 1.0 / scale
    ESP.OffsetX = 0.0
    ESP.OffsetY = 0.0
  end
  return true
end

function ESP.Viewport(pc)
  local w, h = 1920.0, 1080.0
  pcall(function()
    if pc and pc.GetViewportSize then
      local v = ESPV2(0, 0)
      pc:GetViewportSize(v)
      if v and tonumber(v.X) and v.X > 200 then w, h = v.X, v.Y end
    end
  end)
  return w, h
end

function ESP.Project(pc, worldLoc)
  if not pc or not worldLoc then return nil end
  local pix = ESPV2(0, 0)
  local ok = false
  pcall(function()
    local res = pc:ProjectWorldLocationToScreen(worldLoc, pix, true)
    ok = (res == true or res == 1 or (pix and (pix.X ~= 0 or pix.Y ~= 0)))
  end)
  if not ok then return nil end
  return ESPV2(pix.X * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0),
               pix.Y * (ESP.ScaleY or 1.0) + (ESP.OffsetY or 0.0)), pix
end

function ESP.SnapOrigin(pc, viewW)
  -- esplook: origin bilkul top-center
  local cw = nil
  pcall(function()
    local canvas = ESP.GetCanvas()
    if ESPValid(canvas) then
      local geo = canvas:GetCachedGeometry()
      if geo and geo.GetLocalSize then
        local s = geo:GetLocalSize()
        if s and tonumber(s.X) and s.X > 1 then cw = tonumber(s.X) end
      end
    end
  end)
  local cx = nil
  if tonumber(cw) and cw > 1 then cx = cw * 0.5
  else cx = (viewW * 0.5) * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0) end
  return ESPV2(cx, (CFG.SnapOriginY or 0.0))
end

-- ---------- widget helpers (Help patterns) ----------
function ESP.SetFont(w, size)
  if not ESPValid(w) then return end
  pcall(function()
    local f = w.Font
    if f then
      f.Size = size
      if f.OutlineSettings then
        pcall(function() f.OutlineSettings.OutlineSize = 1 end)
        pcall(function() f.OutlineSettings.OutlineColor = C_BLACK end)
      end
      w:SetFont(f)
    end
    if w.SetShadowOffset then w:SetShadowOffset(ESPV2(1.0, 1.0)) end
    if w.SetShadowColorAndOpacity then w:SetShadowColorAndOpacity(C_BLACK) end
  end)
end

function ESP.SetTextColor(w, color)
  if not ESPValid(w) then return end
  pcall(function()
    if SlateColor then w:SetColorAndOpacity(SlateColor(color))
    else w:SetColorAndOpacity(color) end
  end)
end

function ESP.NewLine(color, z)
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local border = nil
  pcall(function() border = CGame:NewObjectFromPath("/Script/UMG.Border", canvas) end)
  if not ESPValid(border) then return nil end
  pcall(function()
    border:SetBrushColor(color)
    border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    border:SetRenderTransformPivot(ESPV2(0.0, 0.5))
  end)
  local slot = nil
  pcall(function() slot = canvas:AddChildToCanvas(border) end)
  if not slot then
    pcall(function() border:RemoveFromParent() end)
    return nil
  end
  pcall(function() slot:SetAutoSize(false) slot:SetZOrder(z or 30) end)
  return { Widget = border, Slot = slot }
end

function ESP.DrawLine(data, x1, y1, x2, y2, thickness)
  if not data or not ESPValid(data.Widget) or not data.Slot then return false end
  if x1 ~= x1 or y1 ~= y1 or x2 ~= x2 or y2 ~= y2 then return false end
  x1, y1, x2, y2 = RND(x1), RND(y1), RND(x2), RND(y2)
  local dz = CFG.DeadZone or 0.5
  if data.lx1 and data.th == thickness then
    if math.abs((data.lx1 or 0) - x1) < dz and math.abs((data.ly1 or 0) - y1) < dz
    and math.abs((data.lx2 or 0) - x2) < dz and math.abs((data.ly2 or 0) - y2) < dz then
      if data.hidden ~= true then return true end
    end
  end
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then
    ESP.Hide(data)
    return false
  end
  local angle = ((math.atan2 and math.atan2(dy, dx)) or math.atan(dy, dx)) * 180.0 / math.pi
  angle = math.floor(angle * 10 + 0.5) / 10
  len = RND(len)
  if data.lx1 == x1 and data.ly1 == y1 and data.lx2 == x2 and data.ly2 == y2 and data.th == thickness then
    if data.hidden == true then
      pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      data.hidden = false
    end
    return true
  end
  local wasHidden = data.hidden == true
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x1, y1 - thickness * 0.5))
    data.Slot:SetSize(ESPV2(len, thickness))
    data.Widget:SetRenderAngle(angle)
    -- Jangan panggil SetWidgetVisibility tiap tick untuk garis yang sudah
    -- terlihat; SetPosition/SetSize sudah cukup. Ini menghemat ribuan call
    -- UMG per detik saat banyak target/label bergerak.
    if wasHidden then
      data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end
  end)
  if ok then
    data.lx1, data.ly1, data.lx2, data.ly2, data.th = x1, y1, x2, y2, thickness
    data.hidden = false
  end
  return true
end

function ESP.DrawVBar(data, x, top, h, thickness)
  -- vertical health bar: no angle math, seedha Position+Size (double-draw fix)
  if not data or not ESPValid(data.Widget) or not data.Slot then return false end
  if h ~= h or h < 1 then ESP.Hide(data) return false end
  x, top, h = RND(x), RND(top), RND(h)
  local dz = CFG.DeadZone or 0.5
  if data.bx ~= nil then
    if math.abs(data.bx - x) < dz and math.abs(data.bt - top) < dz and math.abs(data.bh - h) < dz then
      if data.hidden ~= true then return true end
    end
  end
  if data.bx == x and data.bt == top and data.bh == h then
    if data.hidden == true then
      pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      data.hidden = false
    end
    return true
  end
  local wasHidden = data.hidden == true
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x, top))
    data.Slot:SetSize(ESPV2(thickness, h))
    data.Widget:SetRenderAngle(0)
    if wasHidden then
      data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end
  end)
  if ok then data.bx, data.bt, data.bh = x, top, h data.hidden = false end
  return true
end

function ESP.Hide(data)
  if data and ESPValid(data.Widget) and data.hidden ~= true then
    pcall(function() data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    data.hidden = true
    data.lx1, data.ly1, data.lx2, data.ly2, data.th = nil, nil, nil, nil, nil
    data.bx, data.bt, data.bh = nil, nil, nil
  end
end

function ESP.SetBrush(data, color, colorKey)
  if not data or not ESPValid(data.Widget) then return end
  if colorKey and data.colorKey == colorKey then return end
  pcall(function() data.Widget:SetBrushColor(color) end)
  if colorKey then data.colorKey = colorKey end
end

function ESP.Destroy(data)
  if not data then return end
  local w = data.Widget or data.Container
  if ESPValid(w) then
    pcall(function() w:RemoveFromParent() end)
    pcall(function() w:ConditionalBeginDestroy() end)
  end
end

-- Panel info membuat beberapa widget anak. Hancurkan anaknya secara
-- eksplisit: kalau hanya container yang di-destroy, widget anak bisa
-- tertahan di Slate tree dan menumpuk sepanjang match (force close).
function ESP.DestroyInfo(data)
  if not data then return end
  for _, w in pairs({ data.Name, data.Dist, data.State, data.Weapon,
                       data.WeaponIcon, data.Ammo }) do
    if w then ESP.Destroy({ Widget = w }) end
  end
  ESP.Destroy({ Widget = data.Container })
end

-- top counter "Players: X | Bots: Y" : bilkul center-top
function ESP.CreateCounter()
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local container = nil
  pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
  if not ESPValid(container) then return nil end
  local playerTxt, sepTxt, botTxt = nil, nil, nil
  pcall(function() playerTxt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() sepTxt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() botTxt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  if not ESPValid(playerTxt) or not ESPValid(sepTxt) or not ESPValid(botTxt) then
    ESP.Destroy({ Widget = container })
    return nil
  end
  pcall(function()
    playerTxt:SetText("Player: 0")
    sepTxt:SetText(" | ")
    botTxt:SetText("Bot: 0")
    playerTxt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    sepTxt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    botTxt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    if playerTxt.SetJustification then playerTxt:SetJustification(1) end
    if sepTxt.SetJustification then sepTxt:SetJustification(1) end
    if botTxt.SetJustification then botTxt:SetJustification(1) end
  end)
  ESP.SetTextColor(playerTxt, C_RED)
  ESP.SetTextColor(sepTxt, C_WHITE)
  ESP.SetTextColor(botTxt, C_GREEN)
  ESP.SetFont(playerTxt, CFG.CounterFontSize)
  ESP.SetFont(sepTxt, CFG.CounterFontSize)
  ESP.SetFont(botTxt, CFG.CounterFontSize)
  local pSlot, sSlot, bSlot, mSlot = nil, nil, nil, nil
  pcall(function() pSlot = container:AddChildToCanvas(playerTxt) end)
  pcall(function() sSlot = container:AddChildToCanvas(sepTxt) end)
  pcall(function() bSlot = container:AddChildToCanvas(botTxt) end)
  pcall(function() mSlot = canvas:AddChildToCanvas(container) end)
  if not pSlot or not sSlot or not bSlot or not mSlot then
    ESP.Destroy({ Widget = container })
    return nil
  end
  local W, H = CFG.CounterW or 300.0, CFG.CounterH or 28.0
  pcall(function()
    pSlot:SetAutoSize(true) pSlot:SetAlignment(ESPV2(0.5, 0.5)) pSlot:SetPosition(ESPV2(78.0, H * 0.5)) pSlot:SetZOrder(5)
    sSlot:SetAutoSize(true) sSlot:SetAlignment(ESPV2(0.5, 0.5)) sSlot:SetPosition(ESPV2(150.0, H * 0.5)) sSlot:SetZOrder(5)
    bSlot:SetAutoSize(true) bSlot:SetAlignment(ESPV2(0.5, 0.5)) bSlot:SetPosition(ESPV2(222.0, H * 0.5)) bSlot:SetZOrder(5)
    mSlot:SetAutoSize(false) mSlot:SetAlignment(ESPV2(0.5, 0.0)) mSlot:SetSize(ESPV2(W, H)) mSlot:SetZOrder(60)
  end)
  return { Container = container, PlayerText = playerTxt, Separator = sepTxt, BotText = botTxt, Slot = mSlot, W = W, H = H }
end
function ESP.CanvasCenterX(viewW)
  local cw = nil
  pcall(function()
    local canvas = ESP.GetCanvas()
    if ESPValid(canvas) then
      local geo = canvas:GetCachedGeometry()
      if geo and geo.GetLocalSize then
        local s = geo:GetLocalSize()
        if s and tonumber(s.X) and s.X > 1 then cw = tonumber(s.X) end
      end
    end
  end)
  if tonumber(cw) and cw > 1 then return cw * 0.5 end
  return (viewW * 0.5) * (ESP.ScaleX or 1.0) + (ESP.OffsetX or 0.0)
end

-- Anak dari Advanced Overlay. Didefinisikan di sini supaya menu, config
-- sync, dan modul ESP.Adv memakai daftar yang sama (tidak duplikat).
ESP.AdvChildren = ESP.AdvChildren or {
  "Esp9_DmgDir", "Esp9_Ghost", "Esp9_Squad", "Esp9_VehIntel",
}

-- Anak ESP LOOT: kategori item. Parent hanya gerbang; ON tidak memaksa
-- kategori mana pun, tetapi kategori ON selalu menyalakan parent.
ESP.LootChildren = ESP.LootChildren or {
  "Esp9_LootWeapon", "Esp9_LootGear", "Esp9_LootAmmo", "Esp9_LootMeds",
  "Esp9_LootAttach", "Esp9_LootThrow", "Esp9_LootMisc",
}

function ESP.SyncMenuConfig()
  local cfg = _G.RapzhangConfig or {}
  ESP.Menu = ESP.Menu or {}
  -- Self-heal: config lama bisa menyimpan anak ADV = true sementara parent
  -- false (menu lama tidak menulis parent). Tanpa ini semua overlay diam.
  if cfg.Esp9_Adv ~= true then
    for _, k in ipairs(ESP.AdvChildren) do
      if cfg[k] == true then cfg.Esp9_Adv = true break end
    end
  end
  -- ESP LOOT punya gerbang sendiri, terpisah dari Advanced Overlay.
  if cfg.Esp9_Loot ~= true then
    for _, k in ipairs(ESP.LootChildren) do
      if cfg[k] == true then cfg.Esp9_Loot = true break end
    end
  end
  ESP.Menu.ShowCount = cfg.Esp9_Count == true
  ESP.Menu.ShowName = cfg.Esp9_Name == true
  ESP.Menu.ShowDistance = cfg.Esp9_Distance == true
  ESP.Menu.ShowHealth = cfg.Esp9_HP == true
  ESP.Menu.ShowTeam = cfg.Esp9_Team == true
  ESP.Menu.ShowTeamNumber = cfg.Esp9_TeamNumber == true
  ESP.Menu.ShowLine = cfg.Esp9_Line == true
  ESP.Menu.ShowVisibility = cfg.Esp9_Visibility == true
  ESP.Menu.ShowAimLine = cfg.Esp9_AimLine == true
  -- Badge self-rescue memakai baris status yang sudah ada; baris itu tetap
  -- tampil walau "Visibility" OFF saat badge aktif.
  ESP.Menu.ShowSelfRescue = cfg.Esp9_SelfRescue == true
  -- esp new.lua has no weapon-icon or skeleton renderer.
  ESP.Menu.ShowWeapon = cfg.Esp9_Weapon == true
  -- Reload countdown adalah bagian dari teks ammo; ON-kan teks ammo juga.
  if cfg.Esp9_ReloadTimer == true then cfg.Esp9_Ammo = true end
  ESP.Menu.ShowAmmo = cfg.Esp9_Ammo == true
  ESP.Menu.Adv = cfg.Esp9_Adv == true
  ESP.Menu.Loot = cfg.Esp9_Loot == true
  local lowEnd = cfg.Esp9_OptLow == true
  if lowEnd ~= ESP.LowEnd then pcall(ESP.SetLowEnd, lowEnd) end
end

-- Team color mapping: jangan memakai teamID % jumlah warna karena Team 20,
-- Team 28, dan ID lain dapat bertabrakan pada slot warna yang sama.
ESP.TeamColorPalette = ESP.TeamColorPalette or {
  ESPMKC(1.0, 1.0, 1.0, 1.0),
  ESPMKC(0.35, 0.80, 1.0, 1.0),
  ESPMKC(1.0, 0.65, 0.25, 1.0),
  ESPMKC(0.55, 1.0, 0.45, 1.0),
  ESPMKC(0.95, 0.45, 1.0, 1.0),
  ESPMKC(1.0, 0.35, 0.55, 1.0),
  ESPMKC(0.25, 1.0, 0.90, 1.0),
  ESPMKC(1.0, 0.90, 0.20, 1.0),
  ESPMKC(0.60, 0.45, 1.0, 1.0),
  ESPMKC(1.0, 0.55, 0.15, 1.0),
  ESPMKC(0.20, 0.85, 0.55, 1.0),
  ESPMKC(0.85, 0.75, 1.0, 1.0),
}
ESP.TeamColorMap = ESP.TeamColorMap or {}
function ESP.TeamColor(Character)
  local team = tonumber(ESP.GetTeamID(Character))
  local teamKey = tostring(team or "unknown")
  local cached = ESP.TeamColorMap[teamKey]
  if cached then return ESP.TeamColorPalette[cached] end

  local count = #ESP.TeamColorPalette
  local base = math.abs(team or 0) % count + 1
  local used = {}
  for _, slot in pairs(ESP.TeamColorMap) do used[slot] = true end
  local slot = base
  for _ = 1, count do
    if not used[slot] then break end
    slot = (slot % count) + 1
  end
  ESP.TeamColorMap[teamKey] = slot
  return ESP.TeamColorPalette[slot]
end

function ESP.UpdateCounter(nPlayers, nBots, pc, viewW)
  if ESP.Menu and not ESP.Menu.ShowCount then
    if ESP.Counter then ESP.Destroy(ESP.Counter) ESP.Counter = nil end
    return ESPV2(ESP.CanvasCenterX(viewW) or (viewW * 0.5), (CFG.SnapOriginY or 0.0))
  end
  local d = ESP.Counter
  if not d or not ESPValid(d.Container) then
    ESP.Destroy(d)
    d = ESP.CreateCounter()
    ESP.Counter = d
  end
  if not d then return nil end
  local playerLabel = string.format("Player: %d", nPlayers or 0)
  local botLabel = string.format("Bot: %d", nBots or 0)
  pcall(function()
    if d.LastPlayer ~= playerLabel then d.PlayerText:SetText(playerLabel) d.LastPlayer = playerLabel end
    if d.LastBot ~= botLabel then d.BotText:SetText(botLabel) d.LastBot = botLabel end
  end)
  local cx = ESP.CanvasCenterX(viewW)
  if cx then
    cx = RND(cx)
    if d.px == nil or math.abs(d.px - cx) >= 1.0 then
      d.px = cx
      pcall(function()
        -- alignment (0.5,0) hai, isliye seedha center X do (cx-150 wala purana math hata diya)
        d.Slot:SetPosition(ESPV2(cx, CFG.TopTextY))
      end)
    end
    if d.shown ~= true then
      pcall(function()
        d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
      d.shown = true
    end
  end
  return ESPV2(cx, (CFG.SnapOriginY or 0.0))
end

-- bottom info: Bot / 16m / Open
function ESP.GetWeaponInfo(Character)
  if not ESPValid(Character) then return nil end
  local id, name, path, texture, weapon = nil, nil, nil, nil, nil
  pcall(function()
    if type(Character.GetCurrentWeapon) == "function" then weapon = Character:GetCurrentWeapon() end
    if not weapon then weapon = Character.CurrentWeapon or Character.CurrentWeaponReplicated end
    if not weapon and type(Character.GetWeaponManager) == "function" then
      local wm = Character:GetWeaponManager()
      if wm and type(wm.GetCurrentWeapon) == "function" then weapon = wm:GetCurrentWeapon() end
    end
  end)
  if weapon and ESPValid(weapon) then
    pcall(function()
      if type(weapon.GetItemDefineID) == "function" then
        local d = weapon:GetItemDefineID()
        if d and slua.isValid(d) then id = d.TypeSpecificID or d.typeSpecificID or d.ID end
      end
      if not id and type(weapon.GetWeaponID) == "function" then id = weapon:GetWeaponID() end
      if not id then id = weapon.WeaponID end
      if not id and type(weapon.GetItemID) == "function" then id = weapon:GetItemID() end
      if type(weapon.GetWeaponName) == "function" then name = weapon:GetWeaponName() end
      if type(weapon.GetWeaponIconPath) == "function" then path = weapon:GetWeaponIconPath() end
      if type(weapon.GetWeaponIcon) == "function" then texture = weapon:GetWeaponIcon() end
    end)
  end
  if not id then
    pcall(function()
      local ps = Character.PlayerState
      if ps and type(ps.GetCurrentWeaponID) == "function" then id = ps:GetCurrentWeaponID() end
      if not id and ps then id = ps.CurWeaponID end
    end)
  end
  return { WeaponID = id, WeaponName = name, WeaponIconPath = path, WeaponIconTexture = texture, CurrentWeapon = weapon }
end

function ESP.FixWeaponIconBrushSize(image, w, h)
  if not ESPValid(image) then return end
  w, h = w or 72, h or 36
  pcall(function()
    local brush = image.Brush
    if brush then
      brush.ImageSize = ESPV2(w, h)
      brush.DrawAs = 3
      brush.TintColor = ESPMKC(1, 1, 1, 1)
      if image.SetBrush then image:SetBrush(brush) end
    end
    if image.SetDesiredSizeOverride then image:SetDesiredSizeOverride(ESPV2(w, h)) end
    image:SetRenderOpacity(1.0)
    image:SetColorAndOpacity(ESPMKC(1, 1, 1, 1))
  end)
end

function ESP.ApplyWeaponIconToImage(image, info)
  if not ESPValid(image) or not info or not info.WeaponID then return false end
  local function applyTexture(obj)
    if not obj or not ESPValid(obj) then return false end
    local ok = false
    pcall(function() if image.SetBrushFromAsset then image:SetBrushFromAsset(obj) ok = true end end)
    if not ok then pcall(function() if image.SetBrushFromTexture then image:SetBrushFromTexture(obj, true) ok = true end end) end
    return ok
  end
  local function applyPath(path)
    if type(path) ~= "string" or path == "" then return false end
    local ok = false
    pcall(function()
      if image.SetBrushResourceFromPathSync then image:SetBrushResourceFromPathSync(path, true) ok = true end
    end)
    if not ok then pcall(function()
      local util = require("client.slua_ui_framework.util")
      if util and util.SetTexture then ok = util.SetTexture(image, path, {sync=true, bMatchSize=true}) ~= false end
    end) end
    if not ok then pcall(function()
      local tex = import(path)
      if tex then ok = applyTexture(tex) end
    end) end
    return ok
  end
  local applied = applyTexture(info.WeaponIconTexture)
  if not applied then
    pcall(function()
      local row = CDataTable.GetTableData("Item", info.WeaponID)
      if row then
        applied = applyPath(row.KillWhiteIcon or row.IconPath or row.WeaponIconPath)
      end
    end)
  end
  if not applied then applied = applyPath(info.WeaponIconPath) end
  if not applied then pcall(function()
    local ui = require("client.common.ui_util")
    local result = ui.GetItemBigIcon(info.WeaponID, image)
    if type(result) == "string" then applied = applyPath(result)
    elseif result and slua.isValid(result) then applied = applyTexture(result)
    elseif type(result) == "table" then
      applied = applyTexture(result.Texture or result.ResourceObject or result.BrushResource)
      if not applied then applied = applyPath(result.Path or result.IconPath or result.TexturePath) end
    end
  end) end
  if applied then
    ESP.FixWeaponIconBrushSize(image)
    image:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
  end
  return applied
end

function ESP.CreateInfo()
  local canvas = ESP.GetCanvas()
  if not ESPValid(canvas) then return nil end
  local container, tName, tDist, tState, tWeapon, tWeaponIcon = nil, nil, nil, nil, nil, nil
  local tAmmo = nil
  pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
  if not ESPValid(container) then return nil end
  pcall(function() tName = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tDist = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tState = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tWeapon = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tWeaponIcon = CGame:NewObjectFromPath("/Script/UMG.Image", container) end)
  pcall(function() tAmmo = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  if not ESPValid(tName) or not ESPValid(tDist) or not ESPValid(tState) or not ESPValid(tWeapon) or not ESPValid(tWeaponIcon)
     or not ESPValid(tAmmo) then
    ESP.DestroyInfo({ Container = container, Name = tName, Dist = tDist, State = tState,
                      Weapon = tWeapon, WeaponIcon = tWeaponIcon, Ammo = tAmmo })
    return nil
  end
  pcall(function()
    tName:SetText("Bot")
    tDist:SetText("0m")
    tState:SetText("Open")
    tWeapon:SetText("")
    tAmmo:SetText("")
    tWeapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    tName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tDist:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tState:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tWeapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    tWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    tAmmo:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    if tName.SetJustification then tName:SetJustification(1) end
    if tDist.SetJustification then tDist:SetJustification(1) end
    if tState.SetJustification then tState:SetJustification(1) end
    if tWeapon.SetJustification then tWeapon:SetJustification(1) end
    if tAmmo.SetJustification then tAmmo:SetJustification(1) end
  end)
  ESP.SetTextColor(tName, C_BLUE)
  ESP.SetTextColor(tDist, C_WHITE)
  ESP.SetTextColor(tState, C_GREEN)
  ESP.SetTextColor(tWeapon, C_YELLOW)
  ESP.SetTextColor(tAmmo, C_WHITE)
  ESP.SetFont(tName, CFG.NameFontSize)
  ESP.SetFont(tDist, CFG.DistFontSize)
  ESP.SetFont(tState, CFG.StateFontSize)
  ESP.SetFont(tWeapon, CFG.DistFontSize)
  ESP.SetFont(tAmmo, CFG.DistFontSize)
  local s1, s2, s3, s4, ms = nil, nil, nil, nil, nil
  pcall(function() s1 = container:AddChildToCanvas(tName) end)
  pcall(function() s2 = container:AddChildToCanvas(tDist) end)
  pcall(function() s3 = container:AddChildToCanvas(tState) end)
  pcall(function() s4 = container:AddChildToCanvas(tWeapon) end)
  local s5, s6 = nil, nil
  pcall(function() s5 = container:AddChildToCanvas(tWeaponIcon) end)
  pcall(function() s6 = container:AddChildToCanvas(tAmmo) end)
  pcall(function() ms = canvas:AddChildToCanvas(container) end)
  if not s1 or not s2 or not s3 or not s4 or not s5 or not s6 or not ms then
    ESP.DestroyInfo({ Container = container, Name = tName, Dist = tDist, State = tState,
                      Weapon = tWeapon, WeaponIcon = tWeaponIcon, Ammo = tAmmo })
    return nil
  end
  pcall(function()
    s1:SetAutoSize(true) s1:SetAlignment(ESPV2(0.5, 0.5)) s1:SetZOrder(36)
    s2:SetAutoSize(true) s2:SetAlignment(ESPV2(0.5, 0.5)) s2:SetZOrder(36)
    s3:SetAutoSize(true) s3:SetAlignment(ESPV2(0.5, 0.5)) s3:SetZOrder(36)
    s4:SetAutoSize(true) s4:SetAlignment(ESPV2(0.5, 0.5)) s4:SetZOrder(36)
    s5:SetAutoSize(false) s5:SetAlignment(ESPV2(0.5, 0.5)) s5:SetPosition(ESPV2(60.0, 74.0)) s5:SetSize(ESPV2(72.0, 36.0)) s5:SetZOrder(36)
    s6:SetAutoSize(true) s6:SetAlignment(ESPV2(0.5, 0.5)) s6:SetZOrder(36)
    ms:SetAutoSize(false) ms:SetZOrder(35)
    -- Posisi anak relatif container selalu sama. Dulu semuanya di-set ulang
    -- tiap target bergerak (6 call UMG per tick per target). Sekarang hanya
    -- root container dan ikon senjata (yang ikut tinggi kepala) yang update.
    local w = 120.0
    local h1, h2, h3, h4 = 20.0, 17.0, 17.0, 15.0
    local panelH = h1 + h2 + h3 + h4 + 30.0
    ms:SetSize(ESPV2(w, panelH))
    s1:SetPosition(ESPV2(w * 0.5, h1 * 0.5))
    s2:SetPosition(ESPV2(w * 0.5, h1 + h2 * 0.5 + CFG.TextGap))
    s3:SetPosition(ESPV2(w * 0.5, h1 + h2 + h3 * 0.5 + CFG.TextGap * 2.0))
    s6:SetPosition(ESPV2(w * 0.5, h1 + h2 + h3 + h4 * 0.5 + CFG.TextGap * 3.0))
    s4:SetPosition(ESPV2(w * 0.5, h1 + h2 + h3 + CFG.TextGap * 3.0 + 8.0))
  end)
  return { Container = container, Name = tName, Dist = tDist, State = tState, Weapon = tWeapon, WeaponIcon = tWeaponIcon,
           Ammo = tAmmo,
           S1 = s1, S2 = s2, S3 = s3, S4 = s4, S5 = s5, S6 = s6, Slot = ms }
end

function ESP.UpdateInfo(key, Character, isBot, distM, bVisible, footX, footY, topY)
  local d = ESP.Infos[key]
  if not d or not ESPValid(d.Container) or not d.Ammo then
    ESP.DestroyInfo(d)
    d = ESP.CreateInfo()
    ESP.Infos[key] = d
  end
  if not d then return end
  local menu = ESP.Menu or {}
  -- Bot pe "Bot", real player pe real name (cache, flicker fix)
  local name = d.CachedName
  if not name then
    name = ESP.ResolveName(Character, isBot)
    d.CachedName = name
  end
  if isBot then
    name = "Bot"
    d.CachedName = "Bot"
  end
  if menu.ShowTeamNumber then
    local team = ESP.GetTeamID(Character)
    name = string.format("%s [T%s]", name, tostring(team or "-"))
  end
  local dl = string.format("%dm", math.max(0, math.floor((tonumber(distM) or 0) + 0.5)))
  local teamID = ESP.GetTeamID(Character)
  local teamKey = tostring(teamID or "-")
  local nameColor = ESP.TeamColor(Character)
  local now = ESP.Now()
  local weaponCache = d.WeaponCache
  if not weaponCache or (now - (weaponCache.t or 0)) >= 0.50 then
    -- Widget teks senjata selalu collapsed; cukup ikonnya yang perlu info.
    weaponCache = { t = now, info = ESP.GetWeaponInfo(Character) }
    d.WeaponCache = weaponCache
  end
  local weaponInfo = weaponCache.info
  local ammoText = ""
  if ESP.Extra and menu.ShowAmmo then
    ammoText = ESP.Extra.GetAmmoText(Character, isBot) or ""
  end
  -- Visibility: Open (green) / Close (red)
  local sr = false
  if menu.ShowSelfRescue then
    if (now - (d.SRT or -999.0)) >= 0.50 then
      d.SRT = now
      d.SR = ESP.IsKnocked(Character) and ESP.CanSelfRescue(Character)
    end
    sr = d.SR == true
  else
    d.SR, d.SRT = false, nil
  end
  local st = bVisible and "Open" or "Close"
  if sr then st = st .. " SR" end
  pcall(function()
    if d.LastN ~= name then
      d.Name:SetText(name) d.LastN = name
    end
    if d.LastTeamColor ~= teamKey then
      ESP.SetTextColor(d.Name, nameColor)
      d.LastTeamColor = teamKey
    end
    if d.LastD ~= dl then d.Dist:SetText(dl) d.LastD = dl end
    if d.LastS ~= st then
      d.State:SetText(st) d.LastS = st
      if sr then ESP.SetTextColor(d.State, C_ORANGE)
      elseif bVisible then ESP.SetTextColor(d.State, C_GREEN)
      else ESP.SetTextColor(d.State, C_RED) end
    end
    if d.LastAmmo ~= ammoText then d.Ammo:SetText(ammoText) d.LastAmmo = ammoText end
    if menu.ShowWeapon and weaponInfo and weaponInfo.WeaponID then
      if d.LastWeaponID ~= weaponInfo.WeaponID then
        d.LastWeaponID = weaponInfo.WeaponID
        ESP.ApplyWeaponIconToImage(d.WeaponIcon, weaponInfo)
      end
    else
      d.LastWeaponID = nil
    end
  end)
  -- 4 baris teks (nama, jarak, status, ammo), centered under feet.
  -- Visibility anak hanya di-set saat kombinasi toggle/status berubah; panel
  -- yang sama tidak perlu 6 call UMG tiap tick.
  local visName = menu.ShowName == true
  local visDist = menu.ShowDistance == true
  local visState = (menu.ShowVisibility or sr) == true
  local visAmmo = menu.ShowAmmo == true and ammoText ~= ""
  local visWeapon = menu.ShowWeapon == true and d.LastWeaponID ~= nil
  local visKey = (visName and "1" or "0") .. (visDist and "1" or "0")
    .. (visState and "1" or "0") .. (visAmmo and "1" or "0")
    .. (visWeapon and "1" or "0")
  if d.LastVisKey ~= visKey then
    d.LastVisKey = visKey
    pcall(function()
      local visible = UEnums.ESlateVisibility.SelfHitTestInvisible
      local hidden = UEnums.ESlateVisibility.Collapsed
      d.Name:SetWidgetVisibility(visName and visible or hidden)
      d.Dist:SetWidgetVisibility(visDist and visible or hidden)
      d.State:SetWidgetVisibility(visState and visible or hidden)
      d.Ammo:SetWidgetVisibility(visAmmo and visible or hidden)
      d.Weapon:SetWidgetVisibility(hidden)
      d.WeaponIcon:SetWidgetVisibility(visWeapon and visible or hidden)
      d.Container:SetWidgetVisibility(visible)
    end)
  end
  local x = RND(footX - 120.0 * 0.5)
  local y = RND(footY + 4.0)
  if d.ix == nil or math.abs(d.ix - x) >= 1.0 or math.abs((d.iy or 0) - y) >= 1.0 then
    d.ix, d.iy = x, y
    pcall(function() d.Slot:SetPosition(ESPV2(x, y)) end)
  end
  -- Weapon icon: above the target box/head, not in the bottom text panel.
  local iconY = ((tonumber(topY) or (footY - 50.0)) - footY) - 18.0
  if d.LastIconY == nil or math.abs(d.LastIconY - iconY) >= 1.0 then
    d.LastIconY = iconY
    pcall(function() d.S5:SetPosition(ESPV2(60.0, iconY)) end)
  end
end

function ESP.EnsureCorner(key, idx, color)
  local t = ESP.Corners[key]
  if not t then t = {} ESP.Corners[key] = t end
  local d = t[idx]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(color or C_WHITE, 32)
  t[idx] = d
  return d
end

function ESP.EnsureHealthBg(key)
  local d = ESP.HealthBg[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(ESPMKC(0.0, 0.0, 0.0, CFG.SideBgAlpha or 0.55), 31)
  ESP.HealthBg[key] = d
  return d
end

function ESP.EnsureHealthFill(key)
  local d = ESP.HealthFill[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(C_GREEN, 32)
  ESP.HealthFill[key] = d
  return d
end

-- Health bar: bg full height + fill bottom-se-up pct height, color HealthColor()
-- single bg + single fill per target (double-draw fix)
function ESP.UpdateHealthBar(key, pct, x, top, h)
  local bg = ESP.EnsureHealthBg(key)
  local fill = ESP.EnsureHealthFill(key)
  if not bg or not fill then return end
  local w = CFG.SideBarWidth or 3.5
  ESP.DrawVBar(bg, x, top, h, w)
  pct = tonumber(pct) or 1.0
  if pct < 0 then pct = 0 end
  if pct > 1 then pct = 1 end
  -- color bucket cache: har frame SetBrushColor nahi (flicker fix)
  local bucket
  if pct >= 0.7 then bucket = "g_" .. math.floor(pct * 20 + 0.5)
  elseif pct >= 0.4 then bucket = "y_" .. math.floor(pct * 20 + 0.5)
  else bucket = "r_" .. math.floor(pct * 20 + 0.5) end
  ESP.SetBrush(fill, HealthColor(pct), bucket)
  local fh = h * pct
  if fh < 1 then
    ESP.Hide(fill)
    return
  end
  -- bottom anchored: khali hissa upar, bhara hissa neeche
  ESP.DrawVBar(fill, x, top + (h - fh), fh, w)
end

function ESP.EnsureSnap(key)
  local d = ESP.Lines[key]
  if d and ESPValid(d.Widget) then return d end
  d = ESP.NewLine(C_GREEN, 30)
  ESP.Lines[key] = d
  return d
end

function ESP.HideTarget(key)
  local c = ESP.Corners[key]
  if c then for i = 1, 8 do ESP.Hide(c[i]) end end
  ESP.Hide(ESP.HealthBg[key])
  ESP.Hide(ESP.HealthFill[key])
  ESP.Hide(ESP.Lines[key])
  ESP.Hide(ESP.AimLines[key])
  local inf = ESP.Infos[key]
  if inf and ESPValid(inf.Container) then
    -- Paksa UpdateInfo menerapkan ulang visibility saat target kembali
    -- terlihat; container baru saja di-collapse di sini.
    inf.LastVisKey = nil
    pcall(function() inf.Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
  end
end

function ESP.ReleaseTarget(key)
  local c = ESP.Corners[key]
  if c then for i = 1, 8 do ESP.Destroy(c[i]) end end
  ESP.Corners[key] = nil
  ESP.Destroy(ESP.HealthBg[key])
  ESP.HealthBg[key] = nil
  ESP.Destroy(ESP.HealthFill[key])
  ESP.HealthFill[key] = nil
  ESP.Destroy(ESP.Lines[key])
  ESP.Lines[key] = nil
  ESP.Destroy(ESP.AimLines[key])
  ESP.AimLines[key] = nil
  ESP.DestroyInfo(ESP.Infos[key])
  ESP.Infos[key] = nil
  ESP.VisCache[key] = nil
  if ESP.Extra and ESP.Extra.PlayerCache then ESP.Extra.PlayerCache[key] = nil end
end

function ESP.ResetWidgets()
  ESP.ClearRadarMarks()
  if ESP.Extra and ESP.Extra.Reset then pcall(ESP.Extra.Reset) end
  for _, d in pairs(ESP.Lines) do ESP.Destroy(d) end
  for _, d in pairs(ESP.AimLines) do ESP.Destroy(d) end
  for _, t in pairs(ESP.Corners) do for _, d in pairs(t) do ESP.Destroy(d) end end
  for _, d in pairs(ESP.HealthBg) do ESP.Destroy(d) end
  for _, d in pairs(ESP.HealthFill) do ESP.Destroy(d) end
  for _, d in pairs(ESP.Infos) do ESP.DestroyInfo(d) end
  ESP.Lines = {}
  ESP.AimLines = {}
  ESP.Corners = {}
  ESP.HealthBg = {}
  ESP.HealthFill = {}
  ESP.Infos = {}
  ESP.VisCache = {}
  if ESP.Counter then ESP.Destroy(ESP.Counter) end
  ESP.Counter = nil
  ESP.Canvas = nil
  ESP.EnemyCache = {}
  ESP.SeenKeys = {}
end

function ESP.SetupRadarScreenConfig()
  if ESP._RadarScreenConfigReady then return true end
  local ok = false
  pcall(function()
    local tools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
    local cfg = tools and tools.GetCurrentConfig and tools.GetCurrentConfig("ScreenMarkConfig")
    if cfg then
      cfg[8888] = {
        UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
        MaxWidgetNum = 99,
        MaxShowDistance = 6000000,
        bBindOutScreen = true,
        bBindBlocked = true,
        bIsBindingActor = true,
        BindSocketName = "head",
        bUseLuaWorldSocketName = true,
        WorldPositionOffset = (FVector and FVector(0,0,30)) or {X=0,Y=0,Z=30},
        bNeedPreLoad = true,
        Priority = 2
      }
      ESP._RadarScreenConfigReady = true; ok = true
    end
  end)
  return ok
end
function ESP.ClearRadarMarks()
  for key, mark in pairs(ESP.RadarMarks or {}) do
    pcall(function() SafeRemoveMark(mark) end)
    ESP.RadarMarks[key] = nil
  end
end
function ESP.UpdateRadarMarks(items)
  local ok = pcall(function()
    if not (_G.RapzhangConfig and _G.RapzhangConfig.Esp9_Radar360 == true) then
      ESP.ClearRadarMarks(); return
    end
    if not ESP.SetupRadarScreenConfig() then return end
    local seen = {}
    for _, item in ipairs(items or {}) do
      local key, actor = item.Key, item.Character
      if key and ESPValid(actor) and ESP.IsAlive(actor) then
        seen[key] = true
        if not ESP.RadarMarks[key] then
          local pos = (FVector and FVector(0,0,0)) or {X=0,Y=0,Z=0}
          local mark = SafeAddMark(8888, pos, 0, "", 4, actor)
          if mark and mark ~= 0 then ESP.RadarMarks[key] = mark end
        end
      end
    end
    for key, mark in pairs(ESP.RadarMarks) do
      if not seen[key] then
        pcall(function() SafeRemoveMark(mark) end)
        ESP.RadarMarks[key] = nil
      end
    end
  end)
  if not ok then ESP.RadarMarks = ESP.RadarMarks or {} end
end

-- ============================================================
-- ESP EXTRA PACK
-- Airdrop ESP + landing prediction, zone timer + next circle,
-- grenade ESP + blast radius, enemy rank, clan peek, ammo/reload.
-- Everything here is read-only and pcall-guarded.
-- ============================================================
ESP.Extra = ESP.Extra or {}
do
  local EX = ESP.Extra
  local C_EX_CYAN   = ESPMKC(0.35, 0.90, 1.00, 1.0)
  local C_EX_ORANGE = ESPMKC(1.00, 0.55, 0.15, 1.0)

  EX.Labels = EX.Labels or {}
  EX.Boxes = EX.Boxes or {}
  EX.Rings = EX.Rings or {}
  EX.Extras = EX.Extras or {}
  EX.Airdrops = EX.Airdrops or {}
  EX.Grenades = EX.Grenades or {}
  EX.PlayerCache = EX.PlayerCache or {}
  EX.PredictCache = EX.PredictCache or {}
  EX.ClassCache = EX.ClassCache or {}
  EX.GrenadeTypeCache = EX.GrenadeTypeCache or {}
  EX.BounceCache = EX.BounceCache or {}
  EX.FuseGuess = EX.FuseGuess or {}
  EX.LastSeen = EX.LastSeen or {}
  EX.LastAirdropScan = -999.0
  EX.LastGrenadeScan = -999.0
  EX.ZoneRingT = -999.0
  EX.ZoneGroundZ = nil
  EX.ZoneGroundX, EX.ZoneGroundY = nil, nil
  EX.ZoneDataT = -999.0
  EX.ZoneDataCache = nil
  EX.ZoneDataOK = false
  EX.ZoneTextT = -999.0
  EX.ZoneTextCache = nil
  EX.ZoneMeT = -999.0
  EX.ZoneMeOK = false
  EX.ZoneMeLoc = nil
  EX.ZoneNextTextT = -999.0
  EX.ZoneNextText = nil
  EX.HitResult = nil

  function EX.ImportClass(path, alias)
    local cached = EX.ClassCache[path]
    if cached ~= nil then return cached or nil end
    local cls = nil
    pcall(function()
      cls = import(path)
      if not cls and alias and alias ~= path then cls = import(alias) end
    end)
    EX.ClassCache[path] = cls or false
    return cls or nil
  end

  function EX.ScanActors(classPath, alias)
    local list = {}
    if not GameplayStaticsESP or not GameplayStaticsESP.GetAllActorsOfClass then return list end
    local cls = EX.ImportClass(classPath, alias)
    if not cls then return list end
    pcall(function()
      local pc = ESP.GetController()
      if not pc then return end
      local actorClass = EX.ImportClass("/Script/Engine.Actor")
      if not actorClass then return end
      local arr = slua.Array(UEnums.EPropertyClass.Object, actorClass)
      GameplayStaticsESP.GetAllActorsOfClass(pc, cls, arr)
      if arr then
        for _, a in pairs(arr) do
          if a and ESPValid(a) then list[#list + 1] = a end
        end
      end
    end)
    return list
  end

  function EX.ActorLoc(a)
    local loc = nil
    pcall(function()
      if a.K2_GetActorLocation then loc = a:K2_GetActorLocation()
      elseif Game and Game.GetActorLocation then loc = Game:GetActorLocation(a) end
    end)
    return loc
  end

  function EX.ActorVelocity(a)
    local vx, vy, vz = 0.0, 0.0, 0.0
    pcall(function()
      local v = nil
      if a.GetVelocity then v = a:GetVelocity() end
      if not v then v = a.Velocity end
      if v then
        vx = tonumber(v.X) or 0.0
        vy = tonumber(v.Y) or 0.0
        vz = tonumber(v.Z) or 0.0
      end
    end)
    return vx, vy, vz
  end

  function EX.GetOwnerActor(a)
    local owner = nil
    pcall(function()
      if a.GetOwner then owner = a:GetOwner() end
      if not owner then owner = a.Owner end
    end)
    return owner
  end

  function EX.GroundZ(pc, x, y, z)
    if not KismetSystemLibraryESP or not KismetSystemLibraryESP.LineTraceSingle then return 0.0 end
    if not EX.HitResult then
      pcall(function()
        if HitResultClassESP then EX.HitResult = HitResultClassESP() end
      end)
    end
    if not EX.HitResult then return 0.0 end
    local gz = 0.0
    pcall(function()
      local start = { X = x, Y = y, Z = z }
      local endPos = { X = x, Y = y, Z = z - 500000.0 }
      local hit = KismetSystemLibraryESP.LineTraceSingle(pc, start, endPos, 0, false, nil, 0, EX.HitResult, true)
      if hit then
        local l = EX.HitResult.Location or EX.HitResult.ImpactPoint
        if l and tonumber(l.Z) then gz = tonumber(l.Z) end
      end
    end)
    return gz
  end

  function EX.GetLabel(key)
    local d = EX.Labels[key]
    if d and ESPValid(d.Container) and ESPValid(d.Text) then return d end
    if d then ESP.Destroy(d) end
    local canvas = ESP.GetCanvas()
    if not ESPValid(canvas) then return nil end
    local container, txt = nil, nil
    pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
    if not ESPValid(container) then return nil end
    pcall(function() txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
    if not ESPValid(txt) then
      ESP.Destroy({ Widget = container })
      return nil
    end
    local child, slot = nil, nil
    pcall(function() child = container:AddChildToCanvas(txt) end)
    pcall(function() slot = canvas:AddChildToCanvas(container) end)
    if not child or not slot then
      ESP.Destroy({ Widget = container })
      return nil
    end
    pcall(function()
      txt:SetText("")
      txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      if txt.SetJustification then txt:SetJustification(1) end
      child:SetAutoSize(true)
      child:SetAlignment(ESPV2(0.5, 0.5))
      child:SetZOrder(37)
      slot:SetAutoSize(true)
      slot:SetAlignment(ESPV2(0.5, 0.0))
      slot:SetZOrder(37)
    end)
    ESP.SetFont(txt, 11)
    d = { Container = container, Text = txt, Slot = slot, Child = child }
    EX.Labels[key] = d
    return d
  end

  function EX.DrawLabel(key, x, y, text, color)
    local d = EX.GetLabel(key)
    if not d then return end
    if d.lastText ~= text then
      pcall(function() d.Text:SetText(text) end)
      d.lastText = text
    end
    if d.lastColor ~= color then
      ESP.SetTextColor(d.Text, color)
      d.lastColor = color
    end
    local px, py = RND(x), RND(y)
    if d.px ~= px or d.py ~= py then
      pcall(function() d.Slot:SetPosition(ESPV2(px, py)) end)
      d.px, d.py = px, py
    end
    if d.shown ~= true then
      pcall(function() d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
      d.shown = true
    end
  end

  function EX.HideLabel(key)
    local d = EX.Labels[key]
    if d and ESPValid(d.Container) and d.shown ~= false then
      pcall(function() d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
      d.shown = false
    end
  end

  function EX.GetBox(key)
    local t = EX.Boxes[key]
    if t then return t end
    t = {}
    for i = 1, 8 do t[i] = ESP.NewLine(C_WHITE, 34) end
    EX.Boxes[key] = t
    return t
  end

  function EX.GetRing(key, n)
    local t = EX.Rings[key]
    if t and #t == n then return t end
    if t then for _, d in ipairs(t) do ESP.Destroy(d) end end
    t = {}
    for i = 1, n do t[i] = ESP.NewLine(C_WHITE, 33) end
    EX.Rings[key] = t
    return t
  end

  function EX.GetExtra(key, n)
    local t = EX.Extras[key]
    if t and #t == n then return t end
    if t then for _, d in ipairs(t) do ESP.Destroy(d) end end
    t = {}
    for i = 1, n do t[i] = ESP.NewLine(C_WHITE, 33) end
    EX.Extras[key] = t
    return t
  end

  function EX.DrawBox(key, cx, cy, w, h, color, colorKey, th)
    local t = EX.GetBox(key)
    if not t then return end
    local L, R = cx - w * 0.5, cx + w * 0.5
    local T, B = cy - h * 0.5, cy + h * 0.5
    local arm = math.max(4.0, math.min(10.0, math.min(w, h) * 0.30))
    th = th or 1.8
    for i = 1, 8 do ESP.SetBrush(t[i], color, colorKey) end
    ESP.DrawLine(t[1], L, T, L + arm, T, th)
    ESP.DrawLine(t[2], L, T, L, T + arm, th)
    ESP.DrawLine(t[3], R, T, R - arm, T, th)
    ESP.DrawLine(t[4], R, T, R, T + arm, th)
    ESP.DrawLine(t[5], L, B, L + arm, B, th)
    ESP.DrawLine(t[6], L, B, L, B - arm, th)
    ESP.DrawLine(t[7], R, B, R - arm, B, th)
    ESP.DrawLine(t[8], R, B, R, B - arm, th)
  end

  -- Tabel titik unit circle di-cache per jumlah segmen. DrawRing dipanggil
  -- tiap frame (zona, granat), jadi cos/sin tidak perlu dihitung ulang
  -- 2x per segmen setiap frame.
  function EX.GetUnitRing(n)
    local cache = EX.UnitRings
    if cache == nil then
      cache = {}
      EX.UnitRings = cache
    end
    local u = cache[n]
    if u ~= nil then return u end
    u = {}
    for i = 1, n do
      local a1 = ((i - 1) / n) * math.pi * 2.0
      local a2 = (i / n) * math.pi * 2.0
      u[i] = { math.cos(a1), math.sin(a1), math.cos(a2), math.sin(a2) }
    end
    cache[n] = u
    return u
  end

  function EX.DrawRing(key, cx, cy, rx, ry, color, colorKey, th, n)
    n = n or 16
    local t = EX.GetRing(key, n)
    if not t then return end
    rx = math.max(2.0, rx or 2.0)
    ry = math.max(2.0, ry or 2.0)
    th = th or 1.5
    local u = EX.GetUnitRing(n)
    for i = 1, n do
      local p = u[i]
      ESP.SetBrush(t[i], color, colorKey)
      ESP.DrawLine(t[i],
        cx + p[1] * rx, cy + p[2] * ry,
        cx + p[3] * rx, cy + p[4] * ry, th)
    end
  end

  function EX.HideBox(key)
    local b = EX.Boxes[key]
    if b then for _, d in ipairs(b) do ESP.Hide(d) end end
  end

  function EX.HideRing(key)
    local r = EX.Rings[key]
    if r then for _, d in ipairs(r) do ESP.Hide(d) end end
  end

  function EX.HideExtra(key)
    local e = EX.Extras[key]
    if e then for _, d in ipairs(e) do ESP.Hide(d) end end
  end

  function EX.HideMark(key)
    EX.HideLabel(key)
    EX.HideBox(key)
    EX.HideRing(key)
    EX.HideExtra(key)
  end

  function EX.HidePrefix(prefix)
    local n = #prefix
    for key in pairs(EX.Labels) do
      if key:sub(1, n) == prefix then EX.HideMark(key) end
    end
    for key in pairs(EX.Boxes) do
      if key:sub(1, n) == prefix then EX.HideMark(key) end
    end
    for key in pairs(EX.Rings) do
      if key:sub(1, n) == prefix then EX.HideMark(key) end
    end
    for key in pairs(EX.Extras) do
      if key:sub(1, n) == prefix then EX.HideMark(key) end
    end
  end

  function EX.DestroyMark(key)
    local d = EX.Labels[key]
    if d then ESP.Destroy(d) EX.Labels[key] = nil end
    local b = EX.Boxes[key]
    if b then
      for _, x in ipairs(b) do ESP.Destroy(x) end
      EX.Boxes[key] = nil
    end
    local r = EX.Rings[key]
    if r then
      for _, x in ipairs(r) do ESP.Destroy(x) end
      EX.Rings[key] = nil
    end
    local e = EX.Extras[key]
    if e then
      for _, x in ipairs(e) do ESP.Destroy(x) end
      EX.Extras[key] = nil
    end
    EX.PredictCache[key] = nil
    EX.BounceCache[key] = nil
  end

  -- Buang widget aktor yang sudah tidak terlihat (grenade/airdrop lama).
  function EX.Sweep(now, ttl)
    ttl = ttl or 3.0
    for key, seen in pairs(EX.LastSeen) do
      if (now - (tonumber(seen) or 0)) > ttl then
        EX.LastSeen[key] = nil
        if key:sub(1, 4) ~= "zone" then
          EX.DestroyMark(key)
        end
      end
    end
    -- Cache per-pemain dan cache tipe grenade tidak boleh tumbuh sepanjang
    -- match; entri lama dibuang setelah 30 detik tidak disentuh.
    local cacheTTL = tonumber(ESP.CacheTTL) or 30.0
    for key, c in pairs(EX.PlayerCache) do
      if (now - (tonumber(c and c.t) or 0)) > cacheTTL then
        EX.PlayerCache[key] = nil
      end
    end
    for key, c in pairs(EX.GrenadeTypeCache) do
      if (now - (tonumber(c and c.t) or 0)) > cacheTTL then
        EX.GrenadeTypeCache[key] = nil
      end
    end
    for key, c in pairs(EX.BounceCache) do
      if (now - (tonumber(c and c.t) or 0)) > cacheTTL then
        EX.BounceCache[key] = nil
      end
    end
  end

  function EX.Reset()
    for _, d in pairs(EX.Labels) do ESP.Destroy(d) end
    for _, t in pairs(EX.Boxes) do for _, d in ipairs(t) do ESP.Destroy(d) end end
    for _, t in pairs(EX.Rings) do for _, d in ipairs(t) do ESP.Destroy(d) end end
    for _, t in pairs(EX.Extras) do for _, d in ipairs(t) do ESP.Destroy(d) end end
    EX.Labels, EX.Boxes, EX.Rings, EX.Extras = {}, {}, {}, {}
    EX.Airdrops, EX.Grenades = {}, {}
    EX.PlayerCache, EX.PredictCache = {}, {}
    EX.GrenadeTypeCache = {}
    EX.BounceCache = {}
    EX.FuseGuess = {}
    EX.LastSeen = {}
    EX._PSMap, EX._PSMapT = nil, nil
    EX._PSCharMap, EX._PSIdentMiss = nil, nil
    EX._PSMapN, EX._PSArrN, EX._PSMapC = 0, 0, 0
    EX._CorpsMap, EX._CorpsMapT = nil, nil
    EX.LastAirdropScan, EX.LastGrenadeScan = -999.0, -999.0
    EX.ZoneRingT = -999.0
    EX.ZoneGroundZ = nil
    EX.ZoneGroundX, EX.ZoneGroundY = nil, nil
    EX.ZoneDataT = -999.0
    EX.ZoneDataCache = nil
    EX.ZoneDataOK = false
    EX.ZoneTextT = -999.0
    EX.ZoneTextCache = nil
    EX.ZoneMeT = -999.0
    EX.ZoneMeOK = false
    EX.ZoneMeLoc = nil
    EX.ZoneNextTextT = -999.0
    EX.ZoneNextText = nil
  end

  -- Baca properti objek slua. Sebagian properti C++ tidak terbaca lewat
  -- indexing biasa, tetapi bisa lewat slua.IndexReference (game sendiri
  -- memakai ini, mis. AliasDataUtil untuk PlayerState.AliasInfo).
  local function propOf(obj, field)
    if obj == nil then return nil end
    local v = nil
    local ok = pcall(function() v = obj[field] end)
    if ok and v ~= nil then return v end
    local sl = rawget(_G, "slua")
    if sl and type(sl.IndexReference) == "function" then
      pcall(function() v = sl.IndexReference(obj, field) end)
      if v ~= nil then return v end
    end
    pcall(function()
      local f = obj["Get" .. field]
      if type(f) == "function" then v = f(obj) end
    end)
    return v
  end

  -- Ambil objek global game. Beberapa host memuat mod dengan environment
  -- proxy (__index), jadi rawget(_G, ...) bisa nil walau `Game` terlihat.
  local function gameGlobal(name)
    local v = rawget(_G, name)
    if v ~= nil then return v end
    local ok, value = pcall(function()
      if name == "Game" then return Game end
      if name == "CGameState" then return CGameState end
      if name == "GameState" then return GameState end
      return nil
    end)
    if ok then return value end
    return nil
  end

  -- Iterasi seluruh PlayerState langsung dari engine. Ini jalur yang dipakai
  -- game sendiri di client (AliasDataUtil: Game:GetAllPlayerStates()).
  local function eachEnginePlayerState(fn)
    local game = gameGlobal("Game")
    if not (game and game.GetAllPlayerStates) then return 0 end
    local arr = nil
    pcall(function() arr = game:GetAllPlayerStates() end)
    if arr == nil then return 0 end
    local n, used = 0, false
    pcall(function()
      for _, ps in pairs(arr) do
        if ESPValid(ps) then
          used = true
          n = n + 1
          fn(ps)
        end
      end
    end)
    if used then return n end
    local cnt = 0
    pcall(function()
      cnt = tonumber(arr.Num and arr:Num()) or tonumber(arr.Length and arr:Length())
        or tonumber(#arr) or 0
    end)
    -- UE TArray memakai index 0-based untuk :Get(). Fallback 1-based hanya
    -- dipakai kalau tidak ada satu pun elemen yang terbaca.
    for i = 0, cnt - 1 do
      local ps = nil
      pcall(function() ps = arr:Get(i) end)
      if ps == nil then pcall(function() ps = arr[i] end) end
      if ps ~= nil then n = n + 1 fn(ps) end
    end
    if n == 0 then
      for i = 1, cnt do
        local ps = nil
        pcall(function() ps = arr:Get(i) end)
        if ps == nil then pcall(function() ps = arr[i] end) end
        if ps ~= nil then n = n + 1 fn(ps) end
      end
    end
    return n
  end

  -- GameState.PlayerArray adalah sumber yang dipakai MapDataBase di client:
  -- array PlayerState hasil replikasi, tidak bergantung pada API CGame.
  local function eachGameStatePlayerState(fn)
    local gs = nil
    local gd = ESP.GetGameplayData()
    if gd and gd.GetGameState then
      pcall(function() gs = gd.GetGameState() end)
    end
    if not ESPValid(gs) then gs = gameGlobal("CGameState") or gameGlobal("GameState") end
    if gs == nil then return 0 end
    local arr = nil
    pcall(function() arr = gs.PlayerArray end)
    if arr == nil then pcall(function() arr = gs.PlayerStates end) end
    if arr == nil then return 0 end
    local n, used = 0, false
    pcall(function()
      for _, ps in pairs(arr) do
        if ESPValid(ps) then
          used = true
          n = n + 1
          fn(ps)
        end
      end
    end)
    if used then return n end
    local cnt = 0
    pcall(function()
      cnt = tonumber(arr.Num and arr:Num()) or tonumber(arr.Length and arr:Length())
        or tonumber(#arr) or 0
    end)
    for i = 0, cnt - 1 do
      local ps = nil
      pcall(function() ps = arr:Get(i) end)
      if ps == nil then pcall(function() ps = arr[i] end) end
      if ESPValid(ps) then n = n + 1 fn(ps) end
    end
    if n == 0 then
      for i = 1, cnt do
        local ps = nil
        pcall(function() ps = arr:Get(i) end)
        if ps == nil then pcall(function() ps = arr[i] end) end
        if ESPValid(ps) then n = n + 1 fn(ps) end
      end
    end
    return n
  end

  -- Normalisasi nama khusus untuk key peta (tidak memakai upvalue di luar
  -- blok ESP.Extra supaya harness ekstraksi tetap bisa menjalankannya).
  local function playerNameKey(v)
    if v == nil then return nil end
    local ok, s = pcall(tostring, v)
    if not ok or s == nil then return nil end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "nil" or s == "None" or s == "NULL" or s == "Unknown" then
      return nil
    end
    return s
  end

  -- Peta PlayerKey/UID/Character -> PlayerState. Sumber utama adalah engine
  -- (Game:GetAllPlayerStates), lalu registry GameplayData sebagai pelengkap.
  -- Rebuild max 1x/detik.
  function EX.PlayerStateMap()
    local now = ESP.Now()
    if EX._PSMap and (now - (EX._PSMapT or -999.0)) < 1.0 then return EX._PSMap end
    local map = {}
    local function addKey(prefix, value, ps)
      if value == nil then return end
      local s = tostring(value)
      if s == "" or s == "nil" then return end
      local k = prefix .. s
      if map[k] == nil then map[k] = ps
      elseif map[k] ~= ps then map[k] = false end
      local n = tonumber(value)
      if n ~= nil then
        local ns = string.format("%.0f", n)
        local nk = prefix .. ns
        if map[nk] == nil then map[nk] = ps
        elseif map[nk] ~= ps then map[nk] = false end
      end
    end
    local function addPS(ps, arrayKey)
      if not ESPValid(ps) then return end
      if arrayKey ~= nil then addKey("k:", arrayKey, ps) end
      addKey("k:", propOf(ps, "PlayerKey"), ps)
      addKey("u:", propOf(ps, "UID"), ps)
      addKey("u:", propOf(ps, "PlayerUID"), ps)
      local pn = playerNameKey(propOf(ps, "PlayerName"))
        or playerNameKey(propOf(ps, "NickName"))
      if pn then
        addKey("n:", pn, ps)
        addKey("nl:", pn:lower(), ps)
        -- Nama pawn kadang membawa tag clan di depan; PlayerState hanya
        -- menyimpan nickname. Simpan versi tanpa tag sebagai kunci kedua.
        local bare = pn
        for _, pair in ipairs({ { "[", "]" }, { "【", "】" }, { "〔", "〕" },
          { "「", "」" }, { "『", "』" }, { "《", "》" }, { "<", ">" },
          { "(", ")" }, { "（", "）" }, { "|", "|" } }) do
          local open, close = pair[1], pair[2]
          if pn:sub(1, #open) == open then
            local at = pn:find(close, #open + 1, true)
            if at and at > #open + 1 then
              local rest = pn:sub(at + #close):gsub("^%s+", "")
              if rest ~= "" and rest ~= pn then bare = rest break end
            end
          end
        end
        addKey("ns:", bare:lower(), ps)
      end
      local ch = nil
      pcall(function() if ps.GetPlayerCharacter then ch = ps:GetPlayerCharacter() end end)
      if ch == nil then ch = propOf(ps, "PlayerCharacter") end
      if ch == nil then ch = propOf(ps, "Pawn") end
      if ESPValid(ch) then
        local ck = nil
        pcall(function() if ch.GetPlayerKey then ck = ch:GetPlayerKey() end end)
        if ck == nil then ck = propOf(ch, "PlayerKey") end
        addKey("c:", ck, ps)
      end
    end
    local engineCount = eachEnginePlayerState(function(ps) addPS(ps, nil) end)
    -- Client Ranked kadang tidak mengekspos CGame:GetAllPlayerStates, tetapi
    -- GameState.PlayerArray tetap berisi PlayerState (dipakai MapDataBase).
    local arrayCount = eachGameStatePlayerState(function(ps) addPS(ps, nil) end)
    local gd = ESP.GetGameplayData()
    local list = nil
    if gd and gd.GetAllPlayerStates then
      pcall(function() list = gd.GetAllPlayerStates() end)
    end
    if type(list) == "table" then
      for k, ps in pairs(list) do addPS(ps, k) end
    end
    local mapCount = 0
    local charMap = {}
    local seenPS = {}
    for _, ps in pairs(map) do
      if ESPValid(ps) then
        mapCount = mapCount + 1
        -- Indeks identitas pawn dibangun sekali per rebuild peta, bukan per
        -- target: GetPlayerState cukup lookup tostring(pawn).
        local id = tostring(ps)
        if not seenPS[id] then
          seenPS[id] = true
          pcall(function()
            local ch = nil
            if ps.GetPlayerCharacter then ch = ps:GetPlayerCharacter() end
            if ESPValid(ch) then
              local cid = tostring(ch)
              if charMap[cid] == nil then charMap[cid] = ps end
            end
          end)
        end
      end
    end
    EX._PSMap, EX._PSMapT = map, now
    EX._PSCharMap = charMap
    EX._PSMapN = engineCount
    EX._PSArrN = arrayCount
    EX._PSMapC = mapCount
    return map
  end

  -- Skor kandidat PlayerState: pilih yang benar-benar membawa data rank.
  -- Di Ranked, PS pertama yang valid bisa PS kosong (tanpa SegmentLevel),
  -- sedangkan PS lain untuk pemain yang sama membawa CurSegLevel/UnlockSegLevel.
  local function psRankScore(ps)
    if not ESPValid(ps) then return -1 end
    local score = 0
    local function numField(obj, field)
      if obj == nil then return nil end
      local v = tonumber(propOf(obj, field))
      if v and v == v and v > 0 and v ~= math.huge then return v end
      return nil
    end
    local seg = numField(ps, "SegmentLevel") or numField(ps, "Segment_Level")
    if seg then score = score + 1000 + math.min(seg, 999) end
    local pf = nil
    pcall(function() pf = ps.PromotionFeature end)
    if pf == nil then pcall(function() pf = ps.PlayerStatePromotionFeature end) end
    local pfSeg = numField(pf, "SegmentLevel")
    if pfSeg then score = score + 800 + math.min(pfSeg, 799) end
    local cur = numField(ps, "CurSegLevel")
    if cur then score = score + 600 + math.min(cur, 599) end
    local unlock = numField(ps, "UnlockSegLevel")
    if unlock then score = score + 500 + math.min(unlock, 499) end
    local peak = numField(ps, "PeakSegmentID")
    if peak then score = score + 300 + math.min(peak, 299) end
    local title = propOf(ps, "SegmentTitle") or propOf(pf, "SegmentTitle")
    if type(title) == "string" and title ~= "" and title ~= "None" then
      score = score + 200
    end
    if numField(ps, "PromotionLayer") then score = score + 10 end
    pcall(function()
      if type(ps.IsRankMode) == "function" and ps:IsRankMode() then score = score + 5 end
    end)
    return score
  end

  function EX.GetPlayerState(Character)
    if not ESPValid(Character) then return nil end
    local seen = {}
    local best, bestScore = nil, -1
    local function add(ps)
      if not ESPValid(ps) then return end
      local id = nil
      pcall(function() id = tostring(ps) end)
      if id ~= nil then
        if seen[id] then return end
        seen[id] = true
      end
      local sc = psRankScore(ps)
      if sc > bestScore then best, bestScore = ps, sc end
    end

    local ps = nil
    pcall(function()
      if Character.GetPlayerStateSafety then ps = Character:GetPlayerStateSafety() end
    end)
    if not ESPValid(ps) then
      pcall(function() if Character.GetPlayerState then ps = Character:GetPlayerState() end end)
    end
    if not ESPValid(ps) then ps = propOf(Character, "PlayerState") end
    if not ESPValid(ps) then ps = propOf(Character, "PlayerStateReplicated") end
    add(ps)
    -- Sebagian pawn tidak menyimpan PlayerState langsung; ambil lewat
    -- controller/owner-nya (pawn -> controller -> PlayerState).
    if not ESPValid(ps) then
      local pc = nil
      pcall(function() if Character.GetOwner then pc = Character:GetOwner() end end)
      if pc == nil then pc = propOf(Character, "Owner") end
      if pc == nil then pc = propOf(Character, "Controller") end
      if pc == nil then
        pcall(function() if Character.GetController then pc = Character:GetController() end end)
      end
      if pc ~= nil then
        ps = propOf(pc, "PlayerState")
        if not ESPValid(ps) then
          pcall(function() if pc.GetPlayerState then ps = pc:GetPlayerState() end end)
        end
        add(ps)
      end
    end

    local key = nil
    local uid = nil
    pcall(function() if Character.GetPlayerKey then key = Character:GetPlayerKey() end end)
    if key == nil then key = propOf(Character, "PlayerKey") end
    pcall(function() if Character.GetPlayerUID then uid = Character:GetPlayerUID() end end)
    if uid == nil then uid = propOf(Character, "UID") end
    if uid == nil then uid = propOf(Character, "PlayerUID") end
    if key == nil then key = uid end

    -- Registry native: Game/CGameState menyediakan lookup by PlayerKey/UID.
    -- Ini jalur yang dipakai game sendiri (Game:GetPlayerStateByPlayerKey).
    local function tryRegistry(obj, fn, arg)
      if obj == nil or arg == nil then return nil end
      local f = nil
      pcall(function() f = obj[fn] end)
      if type(f) ~= "function" then return nil end
      local cand = nil
      pcall(function() cand = f(obj, arg) end)
      if not ESPValid(cand) then
        local n = tonumber(arg)
        if n ~= nil then pcall(function() cand = f(obj, n) end) end
      end
      if ESPValid(cand) then return cand end
      return nil
    end
    local game = gameGlobal("Game")
    local gameState = gameGlobal("CGameState") or gameGlobal("GameState")
    for _, spec in ipairs({
      { obj = game, fn = "GetPlayerStateByPlayerKey", arg = key },
      { obj = game, fn = "GetPlayerStateByKey", arg = key },
      { obj = game, fn = "GetPlayerStateByUID", arg = uid },
      { obj = gameState, fn = "GetPlayerStateByUID", arg = uid },
      { obj = gameState, fn = "GetPlayerStateByPlayerKey", arg = key },
      { obj = gameState, fn = "GetPlayerState", arg = key },
    }) do
      add(tryRegistry(spec.obj, spec.fn, spec.arg))
    end

    -- Fallback: registry GameplayData, dipakai game sendiri untuk UI player lain.
    local gd = ESP.GetGameplayData()
    if gd then
      for _, id in ipairs({ key, uid }) do
        if id ~= nil then
          for _, fn in ipairs({ "GetPlayerState", "GetPlayerStateByKey", "GetPlayerStateByPlayerKey" }) do
            if type(gd[fn]) == "function" then
              local cand = nil
              pcall(function() cand = gd[fn](id) end)
              if not ESPValid(cand) then
                local nk = tonumber(id)
                if nk ~= nil then pcall(function() cand = gd[fn](nk) end) end
              end
              add(cand)
            end
          end
        end
      end
    end

    -- Fallback: peta PlayerKey/UID/Character/nama -> PlayerState.
    local map = EX.PlayerStateMap()
    local ids = { key, uid }
    for _, id in ipairs(ids) do
      if id ~= nil then
        local ks = tostring(id)
        local hit = map["k:" .. ks] or map["u:" .. ks] or map["c:" .. ks]
        if hit == nil then
          local nk = tonumber(id)
          if nk ~= nil then
            ks = tostring(nk)
            hit = map["k:" .. ks] or map["u:" .. ks] or map["c:" .. ks]
          end
        end
        add(hit)
      end
    end
    -- Identitas pawn dari indeks yang dibangun bersama peta: paling murah
    -- dan tidak bergantung pada PlayerKey/nama yang kadang kosong di Ranked.
    local charID = tostring(Character)
    local charHit = EX._PSCharMap and EX._PSCharMap[charID] or nil
    add(charHit)
    -- Nama adalah kunci terakhir: di Ranked spawn island sebagian pawn tidak
    -- membawa PlayerKey/UID yang cocok, tetapi nama pemain tetap terbaca.
    local name = ESP.ResolveName(Character, false)
    local bareName = name
    if name and name ~= "Player" and name ~= "Bot" then
      local low = name:lower()
      add(map["n:" .. name] or map["nl:" .. low] or map["ns:" .. low])
      for _, pair in ipairs({ { "[", "]" }, { "【", "】" }, { "〔", "〕" },
        { "「", "」" }, { "『", "』" }, { "《", "》" }, { "<", ">" },
        { "(", ")" }, { "（", "）" }, { "|", "|" } }) do
        local open, close = pair[1], pair[2]
        if name:sub(1, #open) == open then
          local at = name:find(close, #open + 1, true)
          if at and at > #open + 1 then
            local rest = name:sub(at + #close):gsub("^%s+", "")
            if rest ~= "" then
              bareName = rest
              add(map["ns:" .. rest:lower()])
            end
          end
        end
        -- Tag di belakang nama: "Nick[ABC]". Cari penutup terakhir lalu
        -- pembuka terakhir sebelum penutup itu (tanpa pattern magic).
        local closeAt = nil
        local cs = 1
        while true do
          local p = name:find(close, cs, true)
          if not p then break end
          closeAt = p
          cs = p + #close
        end
        if closeAt and closeAt > #open then
          local openAt = nil
          local search = 1
          while true do
            local p = name:find(open, search, true)
            if not p or p >= closeAt then break end
            openAt = p
            search = p + #open
          end
          if openAt then
            local tail = name:sub(1, openAt - 1):gsub("%s+$", "")
            if tail ~= "" and tail ~= name then
              bareName = tail
              add(map["ns:" .. tail:lower()])
            end
          end
        end
      end
    end

    -- Scan GameState.PlayerArray: sumber yang dipakai MapDataBase di client.
    -- Dilakukan hanya kalau kandidat belum membawa rank, supaya tidak mahal.
    if bestScore < 100 and not ESPValid(charHit) then
      local missAt = EX._PSIdentMiss and EX._PSIdentMiss[charID]
      if not (missAt and (ESP.Now() - missAt) < 1.0) then
        local foundIdentity = false
        local gs = nil
        if gd and gd.GetGameState then pcall(function() gs = gd.GetGameState() end) end
        if not ESPValid(gs) then gs = gameGlobal("CGameState") or gameGlobal("GameState") end
        local arr = nil
        if ESPValid(gs) then pcall(function() arr = gs.PlayerArray end) end
        local n = 0
        pcall(function()
          n = tonumber(arr and arr.Num and arr:Num())
            or tonumber(arr and arr.Length and arr:Length()) or 0
        end)
        if n <= 0 and arr ~= nil then
          pcall(function() for _ in pairs(arr) do n = n + 1 end end)
        end
        for i = 0, n - 1 do
          local cand = nil
          pcall(function() cand = arr:Get(i) end)
          if cand == nil then pcall(function() cand = arr[i] end) end
          if ESPValid(cand) then
            local ck = nil
            pcall(function() ck = cand.PlayerKey end)
            local pn = nil
            pcall(function() pn = cand.PlayerName end)
            local same = false
            if key ~= nil and ck ~= nil and tostring(ck) == tostring(key) then same = true end
            if not same and cand == ps then same = true end
            if not same then
              -- Identitas paling kuat: PlayerState menunjuk pawn yang sama.
              pcall(function()
                if cand.GetPlayerCharacter and cand:GetPlayerCharacter() == Character then
                  same = true
                  foundIdentity = true
                end
              end)
            end
            if not same and name and pn and tostring(pn) == tostring(name) then same = true end
            if not same and bareName and pn and tostring(pn):lower() == bareName:lower() then same = true end
            if same then add(cand) end
          end
        end
        -- Catat kegagalan 1 detik supaya target tanpa PlayerState tidak
        -- memicu scan PlayerArray setiap frame.
        if not foundIdentity and EX._PSCharMap and EX._PSCharMap[charID] == nil then
          EX._PSIdentMiss = EX._PSIdentMiss or {}
          EX._PSIdentMiss[charID] = ESP.Now()
        end
      end
    end

    return best
  end

  local function playerCache(key)
    local c = EX.PlayerCache[key]
    if not c then c = {} EX.PlayerCache[key] = c end
    return c
  end

  -- MODE_47 adalah ladder ranked utama (dipakai PlayerStatePromotionFeature),
  -- MODE_25 dipakai battle result, sisanya fallback lintas build.
  local RANK_TABLES = {
    "RankIntegralLevel_MODE_47",
    "RankIntegralLevel_MODE_25",
    "RankIntegralLevel_MODE_1",
    "RankIntegralLevel",
  }
  local RANK_TIER_NAMES = {
    [1] = "Bronze",
    [2] = "Silver",
    [3] = "Gold",
    [4] = "Platinum",
    [5] = "Diamond",
    [6] = "Crown",
    [7] = "Ace",
    [8] = "Conqueror",
  }
  local RANK_SUB_NAMES = { "V", "IV", "III", "II", "I" }

  local function rankTrim(v)
    if v == nil then return nil end
    local ok, s = pcall(tostring, v)
    if not ok or s == nil then return nil end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "None" or s == "nil" or s == "NULL" then return nil end
    return s
  end

  local function rankLocStr(id)
    if id == nil or id == "" then return nil end
    local loc = rawget(_G, "LocUtil")
    if not loc then
      local ok, mod = pcall(require, "common.loc_util")
      if ok then loc = mod end
    end
    local fn = nil
    pcall(function() if loc then fn = loc.GetLocalizeResStr end end)
    if type(fn) == "function" then
      local ok, value = pcall(fn, tonumber(id) or id)
      local text = ok and rankTrim(value) or nil
      if text then return text end
    end
    return nil
  end

  local function rankCfgFromUtil(level)
    local util = rawget(_G, "FuncUtil")
    if not util then
      local ok, mod = pcall(require, "common.func_util")
      if ok then util = mod end
    end
    local fn = nil
    pcall(function() if util then fn = util.GetRankTableData end end)
    if type(fn) ~= "function" then return nil end
    -- Jalur yang dipakai game sendiri: GetRankTableData(segment) satu argumen.
    local ok, cfg = pcall(fn, level)
    if ok and type(cfg) == "table" then return cfg end
    local season = 0
    pcall(function() season = tonumber(_G.DataMgr and _G.DataMgr.season_id) or 0 end)
    for _, s in ipairs({ season, 0 }) do
      local ok2, cfg2 = pcall(fn, level, s)
      if ok2 and type(cfg2) == "table" then return cfg2 end
    end
    return nil
  end

  local function rankCfgFromTables(level)
    local dt = rawget(_G, "CDataTable")
    local fn = nil
    pcall(function() if dt then fn = dt.GetTableData end end)
    if type(fn) ~= "function" then return nil end
    for _, tbl in ipairs(RANK_TABLES) do
      local cfg = nil
      pcall(function() cfg = fn(tbl, level) end)
      if type(cfg) ~= "table" then
        pcall(function() cfg = fn(tbl, tostring(level)) end)
      end
      if type(cfg) == "table" then return cfg end
    end
    return nil
  end

  local function rankNameFromCfg(cfg)
    if type(cfg) ~= "table" then return nil end
    for _, key in ipairs({ "Name", "RankName", "SegmentName", "IntegralTypeName", "ShowName", "NameID", "RankNameID", "RankIntegralName" }) do
      local text = rankTrim(cfg[key])
      if text then
        if text:match("^%d+$") then
          -- Angka panjang adalah localization id, bukan nama rank.
          if #text >= 4 then
            local localized = rankLocStr(text)
            if localized then return localized end
          end
        else
          return text
        end
      end
    end
    return nil
  end

  -- Fallback nama tier dari segment id: 1xx Bronze ... 8xx Conqueror.
  -- 1xx-6xx masih memakai sub-level 1..5 = V..I. Untuk 7xx (ladder Ace)
  -- sub-level adalah jumlah bintang; di PUBG Mobile KR Ace Master mulai
  -- sekitar bintang 10 dan Ace Dominator sekitar bintang 20.
  local function rankFallbackName(level)
    local n = tonumber(level)
    if not n or n <= 0 then return nil end
    local tier = math.floor(n / 100)
    local sub = n % 100
    local tierName = RANK_TIER_NAMES[tier]
    if not tierName then return nil end
    if tier == 7 then
      if sub >= 20 then return "Ace Dominator" end
      if sub >= 10 then return "Ace Master" end
      return "Ace"
    end
    if tier <= 6 and sub >= 1 and sub <= #RANK_SUB_NAMES then
      return tierName .. " " .. RANK_SUB_NAMES[sub]
    end
    return tierName
  end

  local function rankCfgFor(level)
    return rankCfgFromUtil(level) or rankCfgFromTables(level)
  end

  local function rankLabel(level)
    local name = rankNameFromCfg(rankCfgFor(level)) or rankFallbackName(level)
    if name then return name end
    return "Lv" .. tostring(level)
  end

  local function rankNumField(obj, field)
    if obj == nil then return nil end
    local v = propOf(obj, field)
    v = tonumber(v)
    if v and v == v and v > 0 and v ~= math.huge then return v end
    return nil
  end

  -- Nama file ikon rank menyimpan angka bintang/divisi. Contoh:
  -- .../RankIntegralLevel/Ace/Ace_15.Ace_15 -> 15. Dipakai sebagai
  -- cadangan kalau SegmentLevel tidak membawa sub-level.
  local function rankNumFromIcon(cfg)
    if type(cfg) ~= "table" then return nil end
    for _, key in ipairs({ "SubIcon", "BigIcon", "Icon", "SmallIcon", "RankIcon" }) do
      local path = cfg[key]
      if type(path) == "string" and path ~= "" then
        local tail = path:match("([%w_%-%.]+)$") or path
        local last = nil
        for digits in tail:gmatch("%d+") do last = tonumber(digits) end
        if last and last >= 1 and last <= 99 then return last end
      end
    end
    return nil
  end

  local function rankIconText(cfg)
    if type(cfg) ~= "table" then return "" end
    local parts = {}
    for _, key in ipairs({ "SubIcon", "BigIcon", "Icon", "SmallIcon", "RankIcon" }) do
      local v = cfg[key]
      if type(v) == "string" then parts[#parts + 1] = v:lower() end
    end
    return table.concat(parts, " ")
  end

  -- Angka yang ditampilkan di samping nama rank:
  --   1xx-6xx : divisi V..I dari sub-level;
  --   7xx     : bintang dari sub-level SegmentLevel (fallback angka di
  --             path ikon). PromotionLayer BUKAN bintang: nilainya bracket
  --             promosi (mis. 1 = 605..710, 2 = 714..715, 3 = 719..720).
  --   8xx     : Conqueror, tanpa angka.
  local function rankStarNumber(level, cfg)
    local n = tonumber(level) or 0
    if n <= 0 then return nil end
    local sub = n % 100
    if sub >= 1 and sub <= 99 then return sub end
    return rankNumFromIcon(cfg)
  end

  -- Angka yang ditampilkan di samping nama rank:
  --   1xx-6xx : divisi V..I dari sub-level;
  --   7xx     : bintang (sub-level SegmentLevel, fallback angka ikon);
  --   8xx     : Conqueror, tanpa angka.
  local function rankSubText(level, cfg)
    local n = tonumber(level) or 0
    if n <= 0 then return nil end
    local tier = math.floor(n / 100)
    local sub = n % 100
    if tier == 7 then
      local num = rankStarNumber(level, cfg)
      if num and num >= 1 then return tostring(num) end
      return nil
    end
    if tier >= 1 and tier <= 6 then
      if sub >= 1 and sub <= #RANK_SUB_NAMES then return RANK_SUB_NAMES[sub] end
      return nil
    end
    return nil
  end

  -- Susun teks rank final, mis. "Ace 4", "Ace Master 15",
  -- "Ace Dominator 20", "Crown I", "Conqueror".
  local function rankDisplay(level, ps, tag)
    local n = tonumber(level) or 0
    local tier = math.floor(n / 100)
    local cfg = rankCfgFor(level)
    local name = rankNameFromCfg(cfg)
    if not name then
      name = rankFallbackName(level)
    end
    if not name then return "Lv" .. tostring(level) end
    if tier == 7 then
      local low = name:lower():gsub("[%s_%-]", "")
      if low == "ace" or low == "acemaster" or low == "acedominator" or low:find("王牌", 1, true) then
        local icons = rankIconText(cfg)
        local star = rankStarNumber(level, cfg)
        if star and star >= 20 then
          name = "Ace Dominator"
        elseif star and star >= 10 then
          name = "Ace Master"
        elseif star and star >= 1 then
          name = "Ace"
        elseif icons:find("dominator", 1, true) then
          name = "Ace Dominator"
        elseif icons:find("master", 1, true) then
          name = "Ace Master"
        end
      end
    end
    local suffix = rankSubText(level, cfg)
    if suffix and not name:match("%d+%s*$") and not name:match("%s[IVX]+%s*$") then
      name = name .. " " .. suffix
    end
    return name
  end

  -- Formatter publik: dipakai ESP dan telemetri (AutoFeedback) supaya
  -- label rank selalu identik. Hanya menerima segment klasik 1xx..8xx.
  function EX.FormatRank(level)
    local n = tonumber(level)
    if n == nil or n <= 0 then return nil end
    local tier = math.floor(n / 100)
    if tier < 1 or tier > 8 then return nil end
    local ok, text = pcall(rankDisplay, n, nil, nil)
    if ok and type(text) == "string" and text ~= "" then return text end
    return nil
  end

  -- Sumber rank musuh, berurutan dari yang paling "current":
  --   SegmentLevel C++ (dipakai WatchGameInGamePlayerInfo untuk player lain),
  --   SegmentLevel milik feature Promotion (diisi client dari tabel season),
  --   CurSegLevel, UnlockSegLevel, lalu PeakSegmentID (label PEAK).
  -- PromotionLayer TIDAK dipakai sebagai level: nilainya layer promosi,
  -- bukan segment 1xx..8xx.
  local function rankFeature(ps)
    if ps == nil then return nil end
    local pf = nil
    pcall(function() pf = ps.PromotionFeature end)
    if pf == nil then pcall(function() pf = ps.PlayerStatePromotionFeature end) end
    if pf == nil then
      pcall(function()
        if type(ps.GetPromotionFeature) == "function" then pf = ps:GetPromotionFeature() end
      end)
    end
    return pf
  end

  -- Fallback terakhir: PromotionLayer hanyalah bracket promosi, bukan angka
  -- bintang, tetapi client punya tabel layer -> segment_level. Dipakai hanya
  -- kalau tidak ada satu pun field rank langsung (mis. enemy di Ranked yang
  -- hanya mereplikasi PromotionLayer). Read-only, tidak mengubah state game.
  local function promotionLevelFromLayer(layer)
    layer = tonumber(layer)
    if not layer or layer <= 0 then return nil end
    local now = ESP.Now()
    if EX._PromoTable == nil and (not EX._PromoTried or (now - (EX._PromoTriedAt or 0)) >= 10.0) then
      EX._PromoTried = true
      EX._PromoTriedAt = now
      pcall(function()
        local util = require("client.logic.season.promotion_match.promotion_match_util")
        if util and util.ReqPromotionBaseConfig then
          util.ReqPromotionBaseConfig(function(data)
            if type(data) == "table" then EX._PromoTable = data end
          end)
        end
      end)
    end
    local t = EX._PromoTable
    if type(t) ~= "table" then return nil end
    local e = t[layer]
    if type(e) ~= "table" then return nil end
    local lv = tonumber(e.semgent_level) or tonumber(e.segment_level) or tonumber(e.SegmentLevel)
    if lv and lv >= 100 and lv <= 899 then return lv end
    return nil
  end

  local function rankLevelFromPS(ps)
    if ps == nil then return nil, nil end
    local pf = rankFeature(ps)
    local sources = {
      { obj = ps, field = "SegmentLevel", tag = nil },
      { obj = ps, field = "Segment_Level", tag = nil },
      { obj = pf, field = "SegmentLevel", tag = nil },
      { obj = ps, field = "CurSegLevel", tag = nil },
      { obj = ps, field = "UnlockSegLevel", tag = nil },
      { obj = ps, field = "PeakSegmentID", tag = "PEAK" },
    }
    for _, s in ipairs(sources) do
      local level = rankNumField(s.obj, s.field)
      if level then return level, s.tag end
    end
    local layer = rankNumField(ps, "PromotionLayer")
    if layer then
      local level = promotionLevelFromLayer(layer)
      if level then return level, nil end
    end
    return nil, nil
  end

  -- Beberapa build hanya mengisi judul rank di feature Promotion.
  local function rankTitleFromPS(ps)
    local pf = rankFeature(ps)
    if pf == nil then return nil end
    local title = nil
    pcall(function() title = rankTrim(pf.SegmentTitle) end)
    return title
  end

  function EX.GetRankText(Character, isBot)
    if not ESPValid(Character) then return "" end
    local key = ESP.GetPlayerKey(Character)
    local now = ESP.Now()
    local c = playerCache(key)
    -- Data rank baru tersedia beberapa saat setelah PlayerState/feature siap;
    -- jangan mengunci hasil kosong selama 5 detik.
    local ttl = (c.rank and c.rank ~= "") and 10.0 or 0.75
    if c.rankT and (now - c.rankT) < ttl then return c.rank or "" end
    c.rankT = now
    c.t = now
    local ps = EX.GetPlayerState(Character)
    if not ps then
      c.rank = "" return ""
    end
    local level, tag = rankLevelFromPS(ps)
    if not level then
      local title = rankTitleFromPS(ps)
      if title then
        c.rank = "RANK " .. title
        return c.rank
      end
      c.rank = "" return ""
    end
    level = math.floor(level + 0.5)
    local text = "RANK "
    if tag == "PEAK" then text = text .. "PEAK " end
    c.rank = text .. rankDisplay(level, ps, tag)
    return c.rank
  end

  local CLAN_KEYS = {
    "ClanName", "ClanTag", "ClanShortName", "GuildName", "GuildTag",
    "AllianceName", "PlayerClanName", "TeamClanName", "CorpsName",
    "CorpsShortName", "CorpsTag",
  }

  local function firstText(v)
    if v == nil then return nil end
    local s = tostring(v)
    if s == "" or s == "None" or s == "nil" or s == "0" then return nil end
    return s
  end

  -- Build ini tidak punya ClanName/GuildName sama sekali di GameLua; konsep
  -- terdekat adalah Corps (corps_id). Nama corps diambil dari
  -- GameState.CorpsInfoArray bila array itu tersedia di client.
  local function corpsNameFromID(id)
    local n = tonumber(id)
    if not n or n <= 0 then return nil end
    local now = ESP.Now()
    local map = EX._CorpsMap
    if not map or (now - (EX._CorpsMapT or -999.0)) >= 5.0 then
      map = {}
      local gs = nil
      local gd = ESP.GetGameplayData()
      if gd and gd.GetGameState then pcall(function() gs = gd.GetGameState() end) end
      local arr = nil
      if ESPValid(gs) then pcall(function() arr = gs.CorpsInfoArray end) end
      local function entry(info)
        if info == nil then return end
        local cid = nil
        for _, f in ipairs({ "CorpsID", "CorpsId", "corps_id", "ID", "Id" }) do
          local v = tonumber(propOf(info, f))
          if v and v > 0 then cid = v end
          if cid then break end
        end
        if not cid then return end
        for _, f in ipairs({ "CorpsName", "GuildName", "ClanName", "Name",
          "CorpsSimpleName", "SimpleName", "ShortName",
          "CorpsTag", "GuildTag", "ClanTag", "Tag" }) do
          local v = firstText(propOf(info, f))
          if v then map[cid] = v return end
        end
      end
      if type(arr) == "table" then
        for _, info in pairs(arr) do entry(info) end
      elseif arr ~= nil then
        local cnt = 0
        pcall(function()
          cnt = tonumber(arr.Num and arr:Num()) or tonumber(arr.Length and arr:Length())
            or tonumber(#arr) or 0
        end)
        -- UE TArray di slua memakai index 0-based untuk :Get().
        for i = 0, cnt - 1 do
          local info = nil
          pcall(function() info = arr:Get(i) end)
          if info == nil then pcall(function() info = arr[i] end) end
          entry(info)
        end
      end
      EX._CorpsMap, EX._CorpsMapT = map, now
    end
    return map[n]
  end

  local CLAN_TAG_PATTERNS = {
    "^%[([^%]]+)%]", "^【([^】]+)】", "^〔([^〕]+)〕", "^「([^」]+)」",
    "^『([^』]+)』", "^《([^》]+)》", "^<([^>]+)>", "^%(([^%)]+)%)",
    "^（([^）]+)）", "^%|([^|]+)%|",
    "%[([^%]]+)%]%s*$", "【([^】]+)】%s*$", "〔([^〕]+)〕%s*$",
    "「([^」]+)」%s*$", "『([^』]+)』%s*$", "《([^》]+)》%s*$",
    "<([^>]+)>%s*$", "%(([^%)]+)%)%s*$", "（([^）]+)）%s*$",
    "%|([^|]+)%|%s*$",
  }

  -- Tag clan biasanya ditulis pemain di nama, mis. "[ABC]Nick",
  -- "Nick[ABC]", "【ABC】Nick", "(ABC)Nick". Tidak ada field clan di build
  -- ini, jadi nama adalah satu-satunya sumber yang tersisa.
  function EX.ParseClanTag(name)
    if type(name) ~= "string" then return nil end
    local s = name:gsub("^%s+", ""):gsub("%s+$", "")
    for _, pat in ipairs(CLAN_TAG_PATTERNS) do
      local tag = s:match(pat)
      if tag then
        tag = tag:gsub("^%s+", ""):gsub("%s+$", "")
        if #tag >= 1 and #tag <= 16 and not tag:match("^%d+$") then
          return tag
        end
      end
    end
    return nil
  end

  function EX.GetClanText(Character, isBot)
    if not ESPValid(Character) then return "" end
    local key = ESP.GetPlayerKey(Character)
    local now = ESP.Now()
    local c = playerCache(key)
    local ttl = (c.clan and c.clan ~= "") and 10.0 or 0.75
    if c.clanT and (now - c.clanT) < ttl then return c.clan or "" end
    c.clanT = now
    c.t = now
    local ps = EX.GetPlayerState(Character)
    local value = nil
    if ps then
      for _, field in ipairs(CLAN_KEYS) do
        local v = firstText(propOf(ps, field))
        if v then value = v break end
      end
      if not value then
        local info = nil
        pcall(function() info = ps.ClanInfo end)
        if not info then pcall(function() info = ps.GuildInfo end) end
        if not info then pcall(function() info = ps.PlayerClanInfo end) end
        if not info then pcall(function() info = ps.CorpsInfo end) end
        if info then
          for _, field in ipairs(CLAN_KEYS) do
            local v = firstText(propOf(info, field))
            if v then value = v break end
          end
        end
      end
      if not value then
        local cid = nil
        for _, f in ipairs({ "CorpsID", "CorpsId", "corps_id" }) do
          local v = tonumber(propOf(ps, f))
          if v and v > 0 then cid = v end
          if cid then break end
        end
        if cid then value = corpsNameFromID(cid) end
      end
    end
    -- Fallback terakhir: tag clan yang ditulis pemain di nama, mis.
    -- "[ABC]Nick", "Nick[ABC]" atau "【ABC】Nick". Tidak ada field clan
    -- di build ini.
    if not value and not isBot then
      local names = {}
      local okName, resolved = pcall(ESP.ResolveName, Character, false)
      if okName and type(resolved) == "string" then names[#names + 1] = resolved end
      if ESPValid(ps) then
        local pn = propOf(ps, "PlayerName")
        if type(pn) == "string" and pn ~= "" then names[#names + 1] = pn end
      end
      for _, candidate in ipairs(names) do
        local tag = EX.ParseClanTag(candidate)
        if tag then value = tag break end
      end
    end
    if not value then
      c.clan = "" return ""
    end
    local text = "CLAN " .. value
    c.clan = text
    return text
  end

  function EX.GetAmmoText(Character, isBot)
    if not ESPValid(Character) then return "" end
    local key = ESP.GetPlayerKey(Character)
    local now = ESP.Now()
    local c = playerCache(key)
    if c.ammoT and (now - c.ammoT) < (c.reloading and 0.12 or 0.25) then return c.ammo or "" end
    c.ammoT = now
    c.t = now
    local weapon = nil
    pcall(function()
      if Character.GetCurrentWeapon then weapon = Character:GetCurrentWeapon() end
    end)
    if not ESPValid(weapon) then
      pcall(function() weapon = Character.CurrentWeapon or Character.CurrentWeaponReplicated end)
    end
    if not ESPValid(weapon) then c.ammo = "" return "" end
    local cur, max = nil, nil
    pcall(function()
      if weapon.GetCurrentBulletNumInClip then cur = weapon:GetCurrentBulletNumInClip(0) end
    end)
    pcall(function()
      if weapon.GetMaxBulletNumInOneClipFromEntity then max = weapon:GetMaxBulletNumInOneClipFromEntity() end
    end)
    if type(cur) ~= "number" then
      pcall(function()
        if weapon.CurBulletInClip then cur = weapon.CurBulletInClip.CurBulletNumInClip end
      end)
    end
    if type(max) ~= "number" then pcall(function() max = weapon.CurMaxBulletNumInOneClip end) end
    if type(cur) ~= "number" then c.ammo = "" return "" end
    cur = math.floor(cur + 0.5)
    local reloading = false
    pcall(function()
      if weapon.bIsReloading == true or weapon.bReloading == true then reloading = true end
    end)
    if not reloading then
      pcall(function()
        if weapon.IsReloading and weapon:IsReloading() == true then reloading = true end
      end)
    end
    local text
    if type(max) == "number" and max > 0 then
      text = string.format("AMMO %d/%d", cur, math.floor(max + 0.5))
    else
      text = string.format("AMMO %d", cur)
    end
    -- Countdown reload: GetCurReloadTime() memberi durasi total saat reload
    -- dimulai; sisa waktu dihitung lokal supaya label bergerak tiap 0,12 dtk.
    local reloadTimer = _G.RapzhangConfig and _G.RapzhangConfig.Esp9_ReloadTimer == true
    if reloading then
      if not c.wasReloading then
        local total = nil
        pcall(function() if weapon.GetCurReloadTime then total = weapon:GetCurReloadTime() end end)
        if type(total) ~= "number" then pcall(function() total = weapon.CurReloadTime end) end
        if type(total) ~= "number" or total <= 0.0 then total = nil end
        c.reloadStart = now
        c.reloadDur = total
      end
      c.wasReloading = true
    else
      c.wasReloading = false
      c.reloadStart, c.reloadDur = nil, nil
    end
    c.reloading = reloading
    if reloading then
      if reloadTimer then
        local remain = nil
        if c.reloadStart and c.reloadDur then
          remain = c.reloadDur - (now - c.reloadStart)
          if remain < 0.0 then remain = 0.0 end
          if remain > c.reloadDur then remain = c.reloadDur end
        end
        if remain then
          text = text .. string.format("  RL %.1fs", remain)
        else
          text = text .. "  RELOAD"
        end
      else
        text = text .. "  RELOAD"
      end
    end
    c.ammo = text
    return text
  end

  function EX.ScanAirdrops()
    local list = EX.ScanActors("/Script/ShadowTrackerExtra.AirDropBoxActor", "AirDropBoxActor")
    local myLoc = nil
    pcall(function() myLoc = ESP.ActorLocation(ESP.GetLocalCharacter()) end)
    local out = {}
    for _, a in ipairs(list) do
      local loc = EX.ActorLoc(a)
      if loc and myLoc then
        local dm = ESP.DistMeters(myLoc, loc)
        if dm <= 800.0 then
          out[#out + 1] = { Actor = a, Dist = dm }
        end
      end
    end
    table.sort(out, function(x, y) return (x.Dist or 99999) < (y.Dist or 99999) end)
    EX.Airdrops = out
  end

  function EX.PredictLanding(pc, a, loc, now)
    local key = tostring(a)
    local cached = EX.PredictCache[key]
    if cached and (now - (cached.t or 0)) < 0.50 then
      return cached.pred, cached.eta
    end
    local gz = EX.GroundZ(pc, loc.X, loc.Y, loc.Z)
    local vx, vy, vz = EX.ActorVelocity(a)
    local h = (tonumber(loc.Z) or 0.0) - gz
    if h < 0.0 then h = 0.0 end
    local eta = 0.0
    if h > 50.0 then
      local g = 980.0
      if vz < -10.0 then
        if vz > -800.0 then
          -- turun perlahan (parasut): kecepatan dianggap konstan
          eta = h / (-vz)
        else
          -- jatuh bebas: gerak proyektil
          eta = (-vz + math.sqrt(vz * vz + 2.0 * g * h)) / g
        end
      else
        eta = h / 350.0
      end
    end
    if eta < 0.0 then eta = 0.0 end
    if eta > 45.0 then eta = 45.0 end
    local pred = {
      X = (tonumber(loc.X) or 0.0) + vx * eta,
      Y = (tonumber(loc.Y) or 0.0) + vy * eta,
      Z = gz + 25.0,
    }
    EX.PredictCache[key] = { t = now, pred = pred, eta = eta }
    return pred, eta
  end

  function EX.DrawAirdrops(pc, vw, vh, now)
    local cfg = _G.RapzhangConfig or {}
    local showBox = cfg.Esp9_AirdropBox == true
    local showPred = cfg.Esp9_AirdropPredict == true
    local seen = {}
    local myLoc = nil
    pcall(function() myLoc = ESP.ActorLocation(ESP.GetLocalCharacter()) end)
    local shown = 0
    for _, item in ipairs(EX.Airdrops) do
      local a = item.Actor
      if ESPValid(a) then
        local loc = EX.ActorLoc(a)
        if loc then
          local s = ESP.Project(pc, loc)
          if s and s.X > -180 and s.X < vw + 180 and s.Y > -180 and s.Y < vh + 180 then
            shown = shown + 1
            if shown <= 6 and (showBox or showPred) then
              local key = "ad_" .. tostring(a)
              seen[key] = true
              EX.LastSeen[key] = now
              local dm = myLoc and ESP.DistMeters(myLoc, loc) or item.Dist or 0
              local size = math.max(10.0, math.min(42.0, 1400.0 / math.max(12.0, dm)))
              if showBox then
                EX.DrawBox(key, s.X, s.Y, size, size, C_EX_ORANGE, "ad", 2.0)
              else
                EX.HideBox(key)
              end
              local pred, eta = nil, nil
              if showPred then
                pred, eta = EX.PredictLanding(pc, a, loc, now)
              end
              local label = string.format("AIRDROP %dm", math.floor((tonumber(dm) or 0) + 0.5))
              if showPred and pred then
                local ps2 = ESP.Project(pc, pred)
                if ps2 then
                  local ex = EX.GetExtra(key, 3)
                  if ex then
                    for i = 1, 3 do ESP.SetBrush(ex[i], C_EX_ORANGE, "ad") end
                    ESP.DrawLine(ex[1], s.X, s.Y, ps2.X, ps2.Y, 1.2)
                    local m = 6.0
                    ESP.DrawLine(ex[2], ps2.X - m, ps2.Y - m, ps2.X + m, ps2.Y + m, 2.0)
                    ESP.DrawLine(ex[3], ps2.X - m, ps2.Y + m, ps2.X + m, ps2.Y - m, 2.0)
                  end
                else
                  EX.HideExtra(key)
                end
                if eta and eta > 0.5 then
                  label = label .. string.format("  %.0fs", eta)
                end
              else
                EX.HideExtra(key)
              end
              local ly = showBox and (s.Y + size * 0.5 + 3.0) or (s.Y + 10.0)
              EX.DrawLabel(key, s.X, ly, label, C_EX_ORANGE)
            end
          end
        end
      end
    end
    for key in pairs(EX.Labels) do
      if key:sub(1, 3) == "ad_" and not seen[key] then EX.HideMark(key) end
    end
    for key in pairs(EX.Boxes) do
      if key:sub(1, 3) == "ad_" and not seen[key] then EX.HideMark(key) end
    end
    for key in pairs(EX.Extras) do
      if key:sub(1, 3) == "ad_" and not seen[key] then EX.HideMark(key) end
    end
  end

  local GRENADE_TYPE_BY_ID = {
    [602001] = "FLASH",
    [602002] = "SMOKE",
    [602003] = "MOLOTOV",
    [602004] = "FRAG",
    [601006] = "MED",
    [602115] = "FIREWORK",
  }

  local function exNameHas(s, ...)
    for i = 1, select("#", ...) do
      local p = select(i, ...)
      if p and string.find(s, p, 1, true) then return true end
    end
    return false
  end

  function EX.GetProjectileTags()
    if EX.ProjectileTags ~= nil then return EX.ProjectileTags or nil end
    local tags = nil
    pcall(function()
      tags = require("GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.ProjectileTypes")
    end)
    EX.ProjectileTags = tags or false
    return tags or nil
  end

  local function exTagEq(a, b)
    if a == nil or b == nil then return false end
    local ok, r = pcall(function() return TagEquals(a, b) end)
    if ok then return r == true end
    return tostring(a) == tostring(b)
  end

  function EX.GetGrenadeType(a)
    if not ESPValid(a) then return "GRENADE" end
    local key = tostring(a)
    local now = ESP.Now()
    local cached = EX.GrenadeTypeCache[key]
    if cached and (now - (cached.t or 0)) < 10.0 then return cached.v end
    local id = nil
    pcall(function() if a.GetItemTypeID then id = a:GetItemTypeID() end end)
    if type(id) ~= "number" then
      pcall(function() id = a.ItemDefineID and a.ItemDefineID.TypeSpecificID end)
    end
    if type(id) ~= "number" then pcall(function() id = a.CurGrenadeID end) end
    local t = nil
    if type(id) == "number" and id > 0 then
      t = GRENADE_TYPE_BY_ID[math.floor(id + 0.5)]
    end
    if not t then
      local name = ""
      pcall(function()
        if KismetSystemLibraryESP and KismetSystemLibraryESP.GetObjectName then
          name = tostring(KismetSystemLibraryESP.GetObjectName(a) or "")
        end
      end)
      if name == "" then
        pcall(function() if a.SafeGetObjectName then name = tostring(a:SafeGetObjectName() or "") end end)
      end
      if name == "" then
        pcall(function()
          local cls = a:GetClass()
          if cls and cls.GetName then name = tostring(cls:GetName() or "") end
        end)
      end
      local low = string.lower(name)
      if exNameHas(low, "smoke", "smoking") then t = "SMOKE"
      elseif exNameHas(low, "molotov", "burn", "fire", "flame", "incendiary") then t = "MOLOTOV"
      elseif exNameHas(low, "frag", "shoulei", "fragmentation") then t = "FRAG"
      elseif exNameHas(low, "flash", "blind", "stun") then t = "FLASH"
      elseif exNameHas(low, "medicine", "heal", "medkit", "med") then t = "MED"
      elseif exNameHas(low, "apple") then t = "APPLE"
      elseif exNameHas(low, "snow", "ice") then t = "SNOW"
      elseif exNameHas(low, "firework") then t = "FIREWORK"
      end
    end
    if not t and type(id) == "number" and id > 0 then
      pcall(function()
        local dt = CDataTable
        if dt and dt.GetTableData then
          local cfg = dt.GetTableData("Item", math.floor(id + 0.5))
          local nm = cfg and (cfg.ItemName or cfg.Name)
          if nm then
            local low = string.lower(tostring(nm))
            if exNameHas(low, "smoke") then t = "SMOKE"
            elseif exNameHas(low, "molotov", "burn", "fire") then t = "MOLOTOV"
            elseif exNameHas(low, "frag") then t = "FRAG"
            elseif exNameHas(low, "flash", "stun") then t = "FLASH"
            elseif exNameHas(low, "medicine", "heal", "med") then t = "MED"
            end
          end
        end
      end)
    end
    t = t or "GRENADE"
    EX.GrenadeTypeCache[key] = { t = now, v = t }
    return t
  end

  function EX.GetGrenadeState(a)
    local tag = nil
    pcall(function() if a.GetCurStateType then tag = a:GetCurStateType() end end)
    return tag
  end

  function EX.IsGrenadeActive(a)
    if not ESPValid(a) then return false end
    local hidden = false
    pcall(function() if a.IsHidden then hidden = a:IsHidden() == true end end)
    if not hidden then pcall(function() hidden = a.bHidden == true end) end
    if hidden then return false end
    local tag = EX.GetGrenadeState(a)
    local tags = EX.GetProjectileTags()
    local state = tags and tags.Tags and tags.Tags.State or nil
    if state then
      if exTagEq(tag, state.Destroyed) or exTagEq(tag, state.PostEffect) then return false end
      if exTagEq(tag, state.InEffect) then
        local remain = nil
        pcall(function() if a.GetRemainingEffectTime then remain = a:GetRemainingEffectTime() end end)
        if type(remain) == "number" then
          if remain <= 0.0 then return false end
        else
          pcall(function() if a.GetCurStateRemainingLifeSpan then remain = a:GetCurStateRemainingLifeSpan() end end)
          if type(remain) == "number" and remain <= 0.0 then return false end
        end
      end
    else
      local tagStr = tostring(tag or "")
      if string.find(tagStr, "Destroyed", 1, true) or string.find(tagStr, "PostEffect", 1, true) then
        return false
      end
      if string.find(tagStr, "InEffect", 1, true) then
        local remain = nil
        pcall(function() if a.GetRemainingEffectTime then remain = a:GetRemainingEffectTime() end end)
        if type(remain) == "number" and remain <= 0.0 then return false end
      end
    end
    local exploded = false
    pcall(function()
      exploded = a.bExploded == true or a.bIsExploded == true or a.bHasExploded == true
    end)
    if exploded then
      local gtype = EX.GetGrenadeType(a)
      if gtype ~= "SMOKE" and gtype ~= "MOLOTOV" then return false end
      local remain = nil
      pcall(function() if a.GetRemainingEffectTime then remain = a:GetRemainingEffectTime() end end)
      if type(remain) == "number" and remain <= 0.0 then return false end
    end
    return true
  end

  function EX.GetGrenadeRemain(a, gtype)
    local t = nil
    pcall(function() if a.GetRemainingEffectTime then t = a:GetRemainingEffectTime() end end)
    if type(t) == "number" and t >= 0.0 then return t end
    pcall(function() if a.GetCurStateRemainingLifeSpan then t = a:GetCurStateRemainingLifeSpan() end end)
    if type(t) == "number" and t > 0.0 and t < 120.0 then return t end
    return EX.GetGrenadeFuse(a)
  end

  function EX.ScanGrenades()
    local list = EX.ScanActors("STExtraGrenadeBase", "/Script/ShadowTrackerExtra.STExtraGrenadeBase")
    local myLoc = nil
    pcall(function() myLoc = ESP.ActorLocation(ESP.GetLocalCharacter()) end)
    local out = {}
    for _, a in ipairs(list) do
      local loc = EX.ActorLoc(a)
      if loc and myLoc and EX.IsGrenadeActive(a) then
        local dm = ESP.DistMeters(myLoc, loc)
        if dm <= 120.0 then
          out[#out + 1] = { Actor = a, Dist = dm }
        end
      end
    end
    table.sort(out, function(x, y) return (x.Dist or 99999) < (y.Dist or 99999) end)
    local trimmed = {}
    for i = 1, math.min(#out, 8) do trimmed[i] = out[i] end
    EX.Grenades = trimmed
  end

  local GRENADE_RADIUS_FIELDS = {
    "ExplosionRadius", "ExplodeRadius", "DamageRadius", "DamageRadiusOuter",
    "RealDamageRadiusOuter", "EffectRadius", "BlastRadius",
  }

  function EX.GetBlastRadiusCM(a)
    local r = nil
    pcall(function()
      for _, f in ipairs(GRENADE_RADIUS_FIELDS) do
        local v = a[f]
        if type(v) == "number" and v > 0 then r = v break end
      end
    end)
    if type(r) ~= "number" or r <= 0 then r = 800.0 end
    if r < 200.0 then r = r * 100.0 end
    return math.max(200.0, math.min(3000.0, r))
  end

  function EX.GetGrenadeFuse(a)
    local t = nil
    pcall(function()
      if a.GetRemainingTimeBeforeExplode then t = a:GetRemainingTimeBeforeExplode() end
    end)
    if type(t) ~= "number" then pcall(function() t = a.RemainingTimeBeforeExplode end) end
    if type(t) ~= "number" then pcall(function() t = a.RemainingTime end) end
    if type(t) ~= "number" then pcall(function() t = a.LifeSpan end) end
    if type(t) ~= "number" then return nil end
    return math.max(0.0, t)
  end

  -- Fallback countdown saat build tidak mengekspos sisa fuse: catat waktu
  -- pertama grenade terlihat lalu hitung mundur dari asumsi fuse 3,5 dtk.
  -- Nilai ini hanya tampilan; prediksi pantulan tetap memakai fuse asli.
  function EX.EstimateGrenadeFuse(a, now)
    if not ESPValid(a) then return nil end
    now = tonumber(now) or ESP.Now()
    local key = tostring(a)
    local g = EX.FuseGuess[key]
    if not g then
      g = { t = now, dur = 3.5 }
      EX.FuseGuess[key] = g
    end
    local remain = g.dur - (now - g.t)
    if remain < 0.0 then remain = 0.0 end
    if remain > g.dur then remain = g.dur end
    return remain
  end

  -- ============================================================
  -- GRENADE BOUNCE PREDICTION
  -- Simulasi ringan untuk menggambar arah pantul grenade. Bukan
  -- fisika game: gravitasi 980 cm/s^2 + line trace dunia, lalu
  -- kecepatan dipantulkan memakai Bounciness/Friction milik
  -- ProjectileMovement grenade (default 0,4 / 0,7).
  -- ============================================================
  local GRENADE_GRAVITY = 980.0
  local BOUNCE_STEP = 0.05
  local BOUNCE_SAMPLE = 5          -- satu titik path tiap 5 langkah (0,25 dtk)
  local BOUNCE_MAX_TIME = 3.0
  local BOUNCE_MAX_BOUNCES = 3
  local BOUNCE_MAX_POINTS = 24
  local BOUNCE_PATH_SEGS = 24
  local BOUNCE_MARK_SEGS = 12      -- 3 garis per pantulan (X + arah)
  local BOUNCE_REFRESH = 0.20
  local BOUNCE_MIN_SPEED = 40.0
  local BOUNCE_MAX_DIST = 200.0    -- meter; di luar ini path tidak terlihat

  function EX.GetGrenadeBounceParams(a)
    local bounciness, friction = 0.4, 0.7
    if not ESPValid(a) then return bounciness, friction end
    pcall(function()
      local pm = a.ProjectileMovement or a.DelayFlyProjMovement
      if pm then
        if type(pm.Bounciness) == "number" then bounciness = pm.Bounciness end
        if type(pm.Friction) == "number" then friction = pm.Friction end
      end
      if type(a.Bounciness) == "number" then bounciness = a.Bounciness end
      if type(a.Friction) == "number" then friction = a.Friction end
    end)
    return math.max(0.0, math.min(1.0, bounciness)),
           math.max(0.0, math.min(1.0, friction))
  end

  -- Kecepatan grenade: GetVelocity kadang nol/tidak ada di client,
  -- jadi coba juga properti movement dan velocity hasil lemparan.
  function EX.GetGrenadeVelocity(a)
    local best = nil
    local function take(v)
      if best or not v then return end
      local vx = tonumber(v.X)
      local vy = tonumber(v.Y)
      local vz = tonumber(v.Z)
      if vx == nil or vy == nil or vz == nil then return end
      local sp = vx * vx + vy * vy + vz * vz
      if sp > 1.0 then best = { vx, vy, vz } end
    end
    if ESPValid(a) then
      if a.GetVelocity then
        local ok, v = pcall(function() return a:GetVelocity() end)
        if ok then take(v) end
      end
      local ok, v = pcall(function() return a.Velocity end)
      if ok then take(v) end
      ok, v = pcall(function() return a.ThrowVelocity end)
      if ok then take(v) end
      ok, v = pcall(function() return a.LaunchVelocity end)
      if ok then take(v) end
      if not best then
        local pm = nil
        ok = pcall(function() pm = a.DelayFlyProjMovement or a.ProjectileMovement end)
        if ok and pm then
          local ok2, mv = pcall(function() return pm.Velocity end)
          if ok2 then take(mv) end
        end
      end
    end
    if best then return best[1], best[2], best[3] end
    return 0.0, 0.0, 0.0
  end

  -- Pantulan: komponen tangensial dikurangi Friction, komponen normal
  -- dibalik lalu dikali Bounciness (pola ProjectileMovement UE).
  function EX.ReflectVelocity(vx, vy, vz, nx, ny, nz, bounciness, friction)
    vx, vy, vz = tonumber(vx) or 0.0, tonumber(vy) or 0.0, tonumber(vz) or 0.0
    nx, ny, nz = tonumber(nx) or 0.0, tonumber(ny) or 0.0, tonumber(nz) or 0.0
    local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
    if nl < 1.0e-6 then
      nx, ny, nz = 0.0, 0.0, 1.0
    else
      nx, ny, nz = nx / nl, ny / nl, nz / nl
    end
    bounciness = math.max(0.0, math.min(1.0, tonumber(bounciness) or 0.4))
    friction = math.max(0.0, math.min(1.0, tonumber(friction) or 0.7))
    local vn = vx * nx + vy * ny + vz * nz
    if vn > 0.0 then vn = 0.0 end
    local k = 1.0 - friction
    return (vx - vn * nx) * k - vn * nx * bounciness,
           (vy - vn * ny) * k - vn * ny * bounciness,
           (vz - vn * nz) * k - vn * nz * bounciness
  end

  -- Line trace dunia; mengembalikan hit, lokasi, dan normal permukaan.
  function EX.TraceBounce(pc, x1, y1, z1, x2, y2, z2, selfActor, ignoreActor)
    if not pc or not KismetSystemLibraryESP or not KismetSystemLibraryESP.LineTraceSingle then
      return false
    end
    if not EX.HitResult then return false end
    local hit = nil
    pcall(function()
      hit = KismetSystemLibraryESP.LineTraceSingle(
        pc, { X = x1, Y = y1, Z = z1 }, { X = x2, Y = y2, Z = z2 },
        0, false, nil, 0, EX.HitResult, true)
    end)
    if not hit then return false end
    local hitActor = nil
    pcall(function()
      if EX.HitResult.GetActor then hitActor = EX.HitResult:GetActor()
      elseif EX.HitResult.Actor then hitActor = EX.HitResult.Actor end
    end)
    if selfActor and hitActor and tostring(hitActor) == tostring(selfActor) then
      return false
    end
    if ignoreActor and hitActor and tostring(hitActor) == tostring(ignoreActor) then
      return false
    end
    local l = EX.HitResult.Location or EX.HitResult.ImpactPoint
    if not l or type(l.X) ~= "number" or type(l.Y) ~= "number" or type(l.Z) ~= "number" then
      return false
    end
    local n = EX.HitResult.Normal or EX.HitResult.ImpactNormal
    local nx, ny, nz = 0.0, 0.0, 1.0
    if n then
      nx = tonumber(n.X) or 0.0
      ny = tonumber(n.Y) or 0.0
      nz = tonumber(n.Z) or 0.0
    end
    local nl = math.sqrt(nx * nx + ny * ny + nz * nz)
    if nl < 1.0e-4 then
      nx, ny, nz = 0.0, 0.0, 1.0
    else
      nx, ny, nz = nx / nl, ny / nl, nz / nl
    end
    return true, { X = l.X, Y = l.Y, Z = l.Z }, nx, ny, nz
  end

  -- Prediksi jalur sampai fuse habis (atau 4 detik). Hasil di-cache
  -- 0,15 detik karena posisi/kecepatan grenade berubah tiap frame.
  function EX.PredictGrenadeBounces(a, loc, now, pc)
    if not ESPValid(a) or not loc then return nil end
    now = tonumber(now) or ESP.Now()
    local key = tostring(a)
    local x = tonumber(loc.X) or 0.0
    local y = tonumber(loc.Y) or 0.0
    local z = tonumber(loc.Z) or 0.0
    local cached = EX.BounceCache[key]
    if cached then
      local age = now - (tonumber(cached.t) or 0.0)
      if age >= 0.0 and age < BOUNCE_REFRESH then
        -- Grenade bergerak tiap frame; geser jalur cache agar tetap
        -- menempel pada posisi aktor saat ini, bukan posisi lama.
        local dx = x - (tonumber(cached.StartX) or x)
        local dy = y - (tonumber(cached.StartY) or y)
        local dz = z - (tonumber(cached.StartZ) or z)
        if dx * dx + dy * dy + dz * dz > 0.25 then
          for i = 1, #(cached.Points or {}) do
            local p = cached.Points[i]
            p.X, p.Y, p.Z = p.X + dx, p.Y + dy, p.Z + dz
          end
          for i = 1, #(cached.Bounces or {}) do
            local b = cached.Bounces[i]
            b.X, b.Y, b.Z = b.X + dx, b.Y + dy, b.Z + dz
          end
          cached.StartX, cached.StartY, cached.StartZ = x, y, z
        end
        return cached
      end
    end
    if BOUNCE_MAX_DIST > 0.0 and ESP.GetLocalCharacter and ESP.ActorLocation then
      local me = ESP.GetLocalCharacter()
      local myLoc = me and ESP.ActorLocation(me) or nil
      if myLoc then
        local dx, dy, dz = x - myLoc.X, y - myLoc.Y, z - myLoc.Z
        if dx * dx + dy * dy + dz * dz > (BOUNCE_MAX_DIST * 100.0) ^ 2 then
          EX.BounceCache[key] = nil
          return nil
        end
      end
    end
    local vx, vy, vz = EX.GetGrenadeVelocity(a)
    local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
    if speed < BOUNCE_MIN_SPEED then
      EX.BounceCache[key] = nil
      return nil
    end
    if pc and KismetSystemLibraryESP and KismetSystemLibraryESP.LineTraceSingle and not EX.HitResult then
      pcall(function()
        if HitResultClassESP then EX.HitResult = HitResultClassESP() end
      end)
    end
    -- Tanpa line trace kita tidak bisa tahu dinding/lantai; jangan
    -- menggambar jalur bebas yang menyesatkan.
    local canTrace = (pc ~= nil) and KismetSystemLibraryESP
      and KismetSystemLibraryESP.LineTraceSingle and EX.HitResult ~= nil
    if not canTrace then
      EX.BounceCache[key] = nil
      return nil
    end
    local bounciness, friction = EX.GetGrenadeBounceParams(a)
    local ignoreActor = EX.GetOwnerActor(a)
    local fuse = EX.GetGrenadeFuse(a)
    local maxTime = BOUNCE_MAX_TIME
    if type(fuse) == "number" and fuse > 0.0 then maxTime = math.min(maxTime, fuse) end
    if maxTime < BOUNCE_STEP then
      EX.BounceCache[key] = nil
      return nil
    end
    local points, bounces = {}, {}
    points[1] = { X = x, Y = y, Z = z }
    -- Mulai trace sedikit di depan pusat aktor supaya tidak menabrak
    -- collider grenade itu sendiri pada langkah pertama.
    local invSpeed = 1.0 / speed
    x = x + vx * invSpeed * 8.0
    y = y + vy * invSpeed * 8.0
    z = z + vz * invSpeed * 8.0
    local t, step = 0.0, 0
    while t < maxTime and #points < BOUNCE_MAX_POINTS do
      local dt = math.min(BOUNCE_STEP, maxTime - t)
      if dt <= 1.0e-4 then break end
      local px, py, pz = x, y, z
      vz = vz - GRENADE_GRAVITY * dt
      x = x + vx * dt
      y = y + vy * dt
      z = z + vz * dt
      t = t + dt
      step = step + 1
      local bounced = false
      if canTrace then
        local hit, hitLoc, nx, ny, nz = EX.TraceBounce(pc, px, py, pz, x, y, z, a, ignoreActor)
        if hit and hitLoc then
          points[#points + 1] = hitLoc
          local rvx, rvy, rvz = EX.ReflectVelocity(vx, vy, vz, nx, ny, nz, bounciness, friction)
          bounces[#bounces + 1] = { X = hitLoc.X, Y = hitLoc.Y, Z = hitLoc.Z,
                                    VX = rvx, VY = rvy, VZ = rvz }
          vx, vy, vz = rvx, rvy, rvz
          -- geser sedikit dari permukaan supaya trace berikutnya tidak
          -- langsung menabrak bidang yang sama.
          x, y, z = hitLoc.X + nx * 3.0, hitLoc.Y + ny * 3.0, hitLoc.Z + nz * 3.0
          bounced = true
          if #bounces >= BOUNCE_MAX_BOUNCES then break end
          if (rvx * rvx + rvy * rvy + rvz * rvz) < (BOUNCE_MIN_SPEED * BOUNCE_MIN_SPEED) then break end
        end
      end
      if not bounced and (step % BOUNCE_SAMPLE) == 0 then
        points[#points + 1] = { X = x, Y = y, Z = z }
      end
    end
    local last = points[#points]
    if last and (math.abs(last.X - x) > 1.0 or math.abs(last.Y - y) > 1.0
                 or math.abs(last.Z - z) > 1.0) and #points < BOUNCE_MAX_POINTS then
      points[#points + 1] = { X = x, Y = y, Z = z }
    end
    local res = { t = now, Fuse = fuse, Points = points, Bounces = bounces,
                  StartX = points[1].X, StartY = points[1].Y, StartZ = points[1].Z }
    EX.BounceCache[key] = res
    return res
  end

  -- Gambar jalur (satu pool line tetap) + tanda X dan panah arah pada
  -- setiap titik pantulan. Pool sengaja berukuran tetap agar
  -- EX.GetExtra tidak membangun ulang widget setiap frame.
  function EX.DrawGrenadeBouncePath(pc, key, pred, color, ckey)
    local pathKey, markKey = key .. "_path", key .. "_bp"
    local p = EX.GetExtra(pathKey, BOUNCE_PATH_SEGS)
    local m = EX.GetExtra(markKey, BOUNCE_MARK_SEGS)
    if not pred or not p or not m then
      EX.HideExtra(pathKey)
      EX.HideExtra(markKey)
      return
    end
    local pts = pred.Points or {}
    local segs, prev = 0, nil
    for i = 1, #pts do
      if segs >= BOUNCE_PATH_SEGS then break end
      local s = ESP.Project(pc, pts[i])
      if s then
        if prev then
          segs = segs + 1
          ESP.SetBrush(p[segs], color, ckey)
          ESP.DrawLine(p[segs], prev.X, prev.Y, s.X, s.Y, 1.2)
        end
        prev = s
      else
        prev = nil
      end
    end
    for i = segs + 1, BOUNCE_PATH_SEGS do ESP.Hide(p[i]) end

    local used = 0
    local bounces = pred.Bounces or {}
    for i = 1, math.min(#bounces, BOUNCE_MAX_BOUNCES) do
      local b = bounces[i]
      local s = ESP.Project(pc, b)
      if s then
        local i1, i2, i3 = used + 1, used + 2, used + 3
        if i3 <= BOUNCE_MARK_SEGS then
          local size = 5.0
          ESP.SetBrush(m[i1], color, ckey)
          ESP.SetBrush(m[i2], color, ckey)
          ESP.SetBrush(m[i3], color, ckey)
          ESP.DrawLine(m[i1], s.X - size, s.Y - size, s.X + size, s.Y + size, 2.0)
          ESP.DrawLine(m[i2], s.X - size, s.Y + size, s.X + size, s.Y - size, 2.0)
          local bvx, bvy, bvz = b.VX or 0.0, b.VY or 0.0, b.VZ or 0.0
          local sp = math.sqrt(bvx * bvx + bvy * bvy + bvz * bvz)
          if sp > 1.0e-3 then
            local reach = math.max(80.0, math.min(220.0, sp * 0.18))
            local e = ESP.Project(pc, { X = b.X + (bvx / sp) * reach,
                                        Y = b.Y + (bvy / sp) * reach,
                                        Z = b.Z + (bvz / sp) * reach })
            if e then
              ESP.DrawLine(m[i3], s.X, s.Y, e.X, e.Y, 2.0)
            else
              ESP.Hide(m[i3])
            end
          else
            ESP.Hide(m[i3])
          end
          used = i3
        end
      end
    end
    for i = used + 1, BOUNCE_MARK_SEGS do ESP.Hide(m[i]) end
  end

  function EX.DrawGrenades(pc, vw, vh, now)
    local cfg = _G.RapzhangConfig or {}
    local showMark = cfg.Esp9_GrenadeMark == true
    local showRadius = cfg.Esp9_GrenadeRadius == true
    local showBounce = cfg.Esp9_GrenadeBounce == true
    local showFuse = cfg.Esp9_GrenadeFuse ~= false
    local seen = {}
    local me = ESP.GetLocalCharacter()
    local shown = 0
    for _, item in ipairs(EX.Grenades) do
      local a = item.Actor
      local key = "gr_" .. tostring(a)
      if ESPValid(a) and EX.IsGrenadeActive(a) then
        local loc = EX.ActorLoc(a)
        if loc then
          local s = ESP.Project(pc, loc)
          if s and s.X > -120 and s.X < vw + 120 and s.Y > -120 and s.Y < vh + 120 then
            shown = shown + 1
            if shown <= 6 and (showMark or showRadius or showBounce) then
              seen[key] = true
              EX.LastSeen[key] = now
              local own = false
              local owner = EX.GetOwnerActor(a)
              if ESPValid(owner) and ESPValid(me) then own = (owner == me) end
              local color = own and C_GREEN or C_RED
              local ckey = own and "gr_own" or "gr_enemy"
              local radius = EX.GetBlastRadiusCM(a)
              if showRadius then
                local rx, ry = nil, nil
                local px = ESP.Project(pc, { X = loc.X + radius, Y = loc.Y, Z = loc.Z })
                local py = ESP.Project(pc, { X = loc.X, Y = loc.Y + radius, Z = loc.Z })
                if px and py then
                  local dx, dy = px.X - s.X, px.Y - s.Y
                  rx = math.sqrt(dx * dx + dy * dy)
                  dx, dy = py.X - s.X, py.Y - s.Y
                  ry = math.sqrt(dx * dx + dy * dy)
                end
                if rx and ry and rx > 2.0 and ry > 2.0 then
                  EX.DrawRing(key, s.X, s.Y, rx, ry, color, ckey, 1.5,
                    ESP.GrenadeRingSegments or 18)
                else
                  EX.HideRing(key)
                end
              else
                EX.HideRing(key)
              end
              if showMark then
                EX.DrawBox(key, s.X, s.Y, 12.0, 12.0, color, ckey, 1.6)
                local gtype = EX.GetGrenadeType(a)
                local remain = nil
                if showFuse then
                  remain = EX.GetGrenadeRemain(a, gtype)
                  if not remain then remain = EX.EstimateGrenadeFuse(a, now) end
                end
                local label = string.format("%s %dm", gtype, math.floor((radius / 100.0) + 0.5))
                if remain then label = label .. string.format("  %.1fs", remain) end
                EX.DrawLabel(key, s.X, s.Y + 10.0, label, color)
              else
                EX.HideBox(key)
                EX.HideLabel(key)
              end
              if showBounce then
                local pathKey, markKey = key .. "_path", key .. "_bp"
                seen[pathKey] = true
                seen[markKey] = true
                EX.LastSeen[pathKey] = now
                EX.LastSeen[markKey] = now
                local pred = EX.PredictGrenadeBounces(a, loc, now, pc)
                EX.DrawGrenadeBouncePath(pc, key, pred, color, ckey)
              else
                EX.HideExtra(key .. "_path")
                EX.HideExtra(key .. "_bp")
              end
            end
          end
        end
      end
    end
    for key in pairs(EX.Labels) do
      if key:sub(1, 3) == "gr_" and not seen[key] then EX.HideMark(key) end
    end
    for key in pairs(EX.Boxes) do
      if key:sub(1, 3) == "gr_" and not seen[key] then EX.HideMark(key) end
    end
    for key in pairs(EX.Rings) do
      if key:sub(1, 3) == "gr_" and not seen[key] then EX.HideMark(key) end
    end
    for key in pairs(EX.Extras) do
      if key:sub(1, 3) == "gr_" and not seen[key] then EX.HideMark(key) end
    end
    if showFuse then
      local alive = {}
      for _, item in ipairs(EX.Grenades) do
        if ESPValid(item.Actor) then alive[tostring(item.Actor)] = true end
      end
      for key in pairs(EX.FuseGuess) do
        if not alive[key] then EX.FuseGuess[key] = nil end
      end
    end
  end

  function EX.GetGameState()
    local gs = nil
    pcall(function()
      local GDP = ESP.GetGameplayData()
      if GDP and GDP.GetGameState then gs = GDP.GetGameState() end
    end)
    if not ESPValid(gs) then pcall(function() gs = CGameState end) end
    return ESPValid(gs) and gs or nil
  end

  local function fmtTime(sec)
    sec = math.max(0, math.floor((tonumber(sec) or 0) + 0.5))
    return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
  end

  function EX.GetZoneData()
    local gs = EX.GetGameState()
    if not gs then return nil end
    local data = {}
    pcall(function() if gs.GetCurCircleWave then data.wave = gs:GetCurCircleWave() end end)
    pcall(function() data.blue = gs.BlueCircle end)
    pcall(function() data.white = gs.WhiteCircle end)
    local s = nil
    pcall(function() if gs.GetCircleInfo then s = gs:GetCircleInfo() end end)
    if type(s) == "string" and s ~= "" then
      local tail = s:match(";([%-%d%.,]+)$")
      if tail then
        local nums = {}
        for n in tail:gmatch("([%-%d%.]+)") do
          local v = tonumber(n)
          if v ~= nil then nums[#nums + 1] = v end
        end
        if #nums >= 5 then
          local t = nums[2]
          local dil = nums[3]
          local stime = nums[4]
          local nowS = nil
          pcall(function()
            if gs.GetServerWorldTimeSeconds then nowS = gs:GetServerWorldTimeSeconds() end
          end)
          if type(nowS) == "number" and type(stime) == "number" then
            data.remain = math.max(0.0, (t or 0) - (nowS - stime) * (dil or 1))
          else
            data.remain = t
          end
          data.circleType = nums[1]
        end
      end
    end
    return data
  end

  -- Zona berikutnya selalu termuat di dalam zona aktif. WhiteCircle dan
  -- BlueCircle bisa bertukar arti antar mode/build, jadi tentukan dari
  -- geometri: lingkaran yang termuat (atau radius lebih kecil saat transisi)
  -- adalah next; yang memuat adalah zona aktif.
  local function zoneCircle(c)
    if c == nil then return nil end
    local x, y, z = tonumber(c.X), tonumber(c.Y), tonumber(c.Z)
    if x == nil or y == nil or z == nil or z <= 0 then return nil end
    return c
  end

  function EX.GetZoneCircles(data)
    data = data or EX.GetZoneData()
    if not data then return nil, nil, "NONE" end
    -- CircleInfoType 3 = NoCircleInfo (lihat ECircleState di game).
    -- WhiteCircle/BlueCircle bisa masih menyimpan nilai fase lama; jangan
    -- gambar next zone yang sudah tidak valid.
    if tonumber(data.circleType) == 3 then
      return nil, nil, "NOINFO"
    end
    local w = zoneCircle(data.white)
    local b = zoneCircle(data.blue)
    local outer, inner, status = nil, nil, "NONE"
    if w ~= nil and b ~= nil then
      local dx = tonumber(w.X) - tonumber(b.X)
      local dy = tonumber(w.Y) - tonumber(b.Y)
      local d = math.sqrt(dx * dx + dy * dy)
      local wz, bz = tonumber(w.Z), tonumber(b.Z)
      -- Saat blue zone selesai menyusut, white circle menjadi zona aktif
      -- dan next circle baru belum dibuat. Dua circle yang hampir sama
      -- bukan "next" yang valid, jadi jangan tampilkan NEXT INSIDE.
      if d <= 100.0 and math.abs(wz - bz) <= 100.0 then
        outer = (wz >= bz) and w or b
        inner = nil
        status = "TRANS"
      elseif d + wz <= bz + 1.0 then
        outer, inner = b, w
        status = "OK"
      elseif d + bz <= wz + 1.0 then
        outer, inner = w, b
        status = "OK"
      elseif wz <= bz then
        outer, inner = b, w
        status = "TRANS"
      else
        outer, inner = w, b
        status = "TRANS"
      end
    elseif w ~= nil then
      outer, inner = w, nil
      status = "1C"
    elseif b ~= nil then
      outer, inner = b, nil
      status = "1C"
    end
    return outer, inner, status
  end

  -- Cache data zona: GetZoneData membaca beberapa field GameState dan
  -- mem-parse string circle. DrawZone dipanggil tiap frame, sedangkan
  -- wave/posisi/radius zona hanya berubah per fase; 0,25 dtk cukup dan
  -- menghemat puluhan pcall per detik.
  local ZONE_DATA_TTL = 0.25
  local function zoneData(now)
    local t = EX.ZoneDataT
    if EX.ZoneDataOK == true and t ~= nil and (now - t) >= 0
      and (now - t) < ZONE_DATA_TTL then
      return EX.ZoneDataCache
    end
    local data = EX.GetZoneData()
    EX.ZoneDataCache = data
    EX.ZoneDataOK = true
    EX.ZoneDataT = now
    return data
  end

  -- Label timer ikut di-throttle: teks NEXT/SAFE hanya perlu diperbarui
  -- beberapa kali per detik, bukan tiap frame.
  local ZONE_TEXT_TTL = 0.20

  -- Posisi pemain dipakai label timer + marker NEXT. Cukup 0,25 dtk:
  -- teks dan marker di-throttle, jadi membaca pawn tiap frame hanya
  -- menambah pcall tanpa manfaat.
  local ZONE_ME_TTL = 0.25
  local function zoneMeLoc(now)
    local t = EX.ZoneMeT
    if EX.ZoneMeOK == true and t ~= nil and (now - t) >= 0
      and (now - t) < ZONE_ME_TTL then
      return EX.ZoneMeLoc
    end
    local loc = nil
    pcall(function() loc = ESP.ActorLocation(ESP.GetLocalCharacter()) end)
    EX.ZoneMeLoc = loc
    EX.ZoneMeOK = true
    EX.ZoneMeT = now
    return loc
  end

  local function zoneNextDist(nextCircle, myLoc)
    if nextCircle == nil or myLoc == nil then return nil end
    local dx = (tonumber(nextCircle.X) or 0) - (tonumber(myLoc.X) or 0)
    local dy = (tonumber(nextCircle.Y) or 0) - (tonumber(myLoc.Y) or 0)
    return math.sqrt(dx * dx + dy * dy) - (tonumber(nextCircle.Z) or 0)
  end

  -- Teks baris atas: NEXT <jarak> / NEXT INSIDE.
  local function zoneNextLabel(dist)
    if dist == nil then return "NEXT" end
    if dist <= 0 then return "NEXT INSIDE" end
    return string.format("NEXT %dm", math.floor(dist / 100.0 + 0.5))
  end

  -- Teks di pusat circle: cukup jarak, karena "NEXT" sudah ada di atas.
  local function zoneMarkerLabel(dist)
    if dist == nil then return "NEXT" end
    if dist <= 0 then return "INSIDE" end
    return string.format("%dm", math.floor(dist / 100.0 + 0.5))
  end

  function EX.DrawZone(pc, vw, vh, now)
    local cfg = _G.RapzhangConfig or {}
    local showTimer = cfg.Esp9_ZoneTimer == true
    local showNext = cfg.Esp9_ZoneNext == true
    now = tonumber(now) or ESP.Now()
    local data = zoneData(now)
    if not data or (not showTimer and not showNext) then
      EX.HideLabel("zone_text")
      EX.HideRing("zone_ring")
      EX.HideRing("zone_next_mark")
      EX.HideRing("zone_next_spot")
      EX.HideLabel("zone_next_text")
      return
    end
    -- Zona next/aktif ditentukan geometri, bukan nama field: WhiteCircle dan
    -- BlueCircle bisa bertukar arti antar mode. `nextCircle` dipakai untuk
    -- NEXT + ring + marker, `outer` (zona aktif) dipakai untuk SAFE.
    local outer, nextCircle, zoneStatus = EX.GetZoneCircles(data)
    local nextOK = nextCircle ~= nil
    local myLoc = zoneMeLoc(now)
    local nextDist = zoneNextDist(nextCircle, myLoc)
    if showTimer then
      if (now - (EX.ZoneTextT or -999.0)) >= ZONE_TEXT_TTL
        or EX.ZoneTextCache == nil or now < (EX.ZoneTextT or 0) then
        local parts = {}
        if type(data.wave) == "number" and data.wave >= 0 then
          parts[#parts + 1] = string.format("ZONE %d", math.floor(data.wave + 0.5))
        else
          parts[#parts + 1] = "ZONE"
        end
        if type(data.remain) == "number" then
          parts[#parts + 1] = "SHRINK " .. fmtTime(data.remain)
        end
        if nextOK and nextDist ~= nil then
          parts[#parts + 1] = zoneNextLabel(nextDist)
        end
        if outer ~= nil and myLoc then
          local dx = (tonumber(outer.X) or 0) - myLoc.X
          local dy = (tonumber(outer.Y) or 0) - myLoc.Y
          local dist = math.sqrt(dx * dx + dy * dy)
          if dist <= (tonumber(outer.Z) or 0) then
            parts[#parts + 1] = "SAFE"
          end
        end
        -- Indikator validasi: status geometri + CircleInfoType mentah.
        -- OK = next termuat; TRANS = transisi/radius fallback; 1C = hanya
        -- satu circle; NOINFO = CircleInfoType 3. T<0..3> dari GetCircleInfo.
        if zoneStatus ~= nil then
          local ct = tonumber(data.circleType)
          parts[#parts + 1] = string.format("[%s/T%s]", zoneStatus,
            ct ~= nil and string.format("%d", math.floor(ct + 0.5)) or "?")
        end
        EX.ZoneTextT = now
        EX.ZoneTextCache = table.concat(parts, "  |  ")
      end
      EX.DrawLabel("zone_text", vw * 0.5, 36.0, EX.ZoneTextCache, C_EX_CYAN)
    else
      EX.HideLabel("zone_text")
    end
    if showNext and nextOK and pc then
      local wx = tonumber(nextCircle.X) or 0
      local wy = tonumber(nextCircle.Y) or 0
      -- Ground Z hanya perlu di-trace ulang saat pusat circle berpindah
      -- (fase baru) atau tiap 3 dtk sebagai penyegar. Sebelumnya line trace
      -- jalan tiap 1 dtk meski pusat zona tidak bergerak.
      local moved = true
      if EX.ZoneGroundX ~= nil and EX.ZoneGroundY ~= nil then
        local gx, gy = wx - EX.ZoneGroundX, wy - EX.ZoneGroundY
        moved = (gx * gx + gy * gy) > 10000.0
      end
      if EX.ZoneGroundZ == nil or moved or (now - (EX.ZoneRingT or -999.0)) >= 3.0 then
        EX.ZoneRingT = now
        EX.ZoneGroundX, EX.ZoneGroundY = wx, wy
        EX.ZoneGroundZ = EX.GroundZ(pc, wx, wy, 20000.0)
      end
      local center = {
        X = wx,
        Y = wy,
        Z = (EX.ZoneGroundZ or 0) + 30.0,
      }
      local cs = ESP.Project(pc, center)
      if cs and cs.X > -200 and cs.X < vw + 200 and cs.Y > -200 and cs.Y < vh + 200 then
        local r = tonumber(nextCircle.Z) or 0
        -- Marker = titik masuk terdekat di tepi next circle, bukan pusat.
        -- Saat pemain masih di luar next, titik ini adalah "spot in" yang
        -- paling cepat dicapai; saat sudah di dalam next, marker kembali ke
        -- pusat karena tepi terdekat justru arah keluar.
        local markX, markY = wx, wy
        local hasSpot = false
        if myLoc and r > 0 then
          local mdx = (tonumber(myLoc.X) or 0) - wx
          local mdy = (tonumber(myLoc.Y) or 0) - wy
          local md = math.sqrt(mdx * mdx + mdy * mdy)
          if md > (r + 1.0) then
            markX = wx + (mdx / md) * r
            markY = wy + (mdy / md) * r
            hasSpot = true
          end
        end
        local markZ = center.Z
        local ms = ESP.Project(pc, { X = markX, Y = markY, Z = markZ })
        local px = ESP.Project(pc, { X = center.X + r, Y = center.Y, Z = center.Z })
        local py = ESP.Project(pc, { X = center.X, Y = center.Y + r, Z = center.Z })
        local rx, ry = nil, nil
        if px and py then
          local dx, dy = px.X - cs.X, px.Y - cs.Y
          rx = math.sqrt(dx * dx + dy * dy)
          dx, dy = py.X - cs.X, py.Y - cs.Y
          ry = math.sqrt(dx * dx + dy * dy)
        end
        if rx and ry and rx > 4 and ry > 4 and rx < 20000 and ry < 20000 then
          EX.DrawRing("zone_ring", cs.X, cs.Y, rx, ry, C_EX_CYAN, "zone", 1.4,
            ESP.ZoneRingSegments or 20)
        else
          EX.HideRing("zone_ring")
        end
        -- Diamond di pusat next circle: acuan utama zona berikutnya.
        EX.DrawRing("zone_next_mark", cs.X, cs.Y, 7.0, 7.0, C_EX_CYAN, "zone_mark", 1.8, 4)
        -- Spot-in: titik masuk terdekat di tepi next circle (oranye), hanya
        -- saat pemain masih di luar. Ini yang dipakai untuk arah jalan,
        -- bukan pusat zona.
        if hasSpot and ms and ms.X > -200 and ms.X < vw + 200
          and ms.Y > -200 and ms.Y < vh + 200 then
          EX.DrawRing("zone_next_spot", ms.X, ms.Y, 5.0, 5.0, C_EX_ORANGE, "zone_spot", 1.8, 4)
        else
          EX.HideRing("zone_next_spot")
        end
        if (now - (EX.ZoneNextTextT or -999.0)) >= ZONE_TEXT_TTL
          or EX.ZoneNextText == nil or now < (EX.ZoneNextTextT or 0) then
          EX.ZoneNextTextT = now
          EX.ZoneNextText = zoneMarkerLabel(nextDist)
        end
        EX.DrawLabel("zone_next_text", cs.X, cs.Y + 12.0,
          EX.ZoneNextText, C_EX_CYAN)
      else
        EX.HideRing("zone_ring")
        EX.HideRing("zone_next_mark")
        EX.HideRing("zone_next_spot")
        EX.HideLabel("zone_next_text")
      end
    else
      EX.HideRing("zone_ring")
      EX.HideRing("zone_next_mark")
      EX.HideRing("zone_next_spot")
      EX.HideLabel("zone_next_text")
    end
  end

  function EX.Update(pc, vw, vh, camLoc, now)
    if not pc then return end
    now = now or ESP.Now()
    local cfg = _G.RapzhangConfig or {}
    if cfg.Esp9_Zone == true then
      pcall(EX.DrawZone, pc, vw, vh, now)
    else
      EX.HideLabel("zone_text")
      EX.HideMark("zone_ring")
      EX.HideMark("zone_next_mark")
      EX.HideLabel("zone_next_text")
    end
    if cfg.Esp9_Airdrop == true then
      if (now - (EX.LastAirdropScan or -999)) >= (ESP.AirdropInterval or 0.80) then
        EX.LastAirdropScan = now
        pcall(EX.ScanAirdrops)
      end
      pcall(EX.DrawAirdrops, pc, vw, vh, now)
    else
      if #(EX.Airdrops or {}) > 0 then EX.Airdrops = {} end
      EX.HidePrefix("ad_")
    end
    if cfg.Esp9_Grenade == true then
      if (now - (EX.LastGrenadeScan or -999)) >= (ESP.GrenadeInterval or 0.45) then
        EX.LastGrenadeScan = now
        pcall(EX.ScanGrenades)
      end
      pcall(EX.DrawGrenades, pc, vw, vh, now)
    else
      if #(EX.Grenades or {}) > 0 then EX.Grenades = {} end
      EX.HidePrefix("gr_")
    end
    pcall(EX.Sweep, now, ESP.SweepTTL or 3.0)
  end
end

function ESP.Scan()
  local pc = ESP.GetController()
  local me = ESP.GetLocalCharacter()
  if not pc or not me then ESP.EnemyCache = {} ESP.SeenKeys = {} return pc, 0, 0 end
  local myLoc = ESP.ActorLocation(me)
  if not myLoc then ESP.EnemyCache = {} ESP.SeenKeys = {} return pc, 0, 0 end
  local myTeam = ESP.GetTeamID(me)
  local list = {}
  local nReal, nBot = 0, 0
  local pawns = nil
  pcall(function() if Game and Game.GetAllPlayerPawns then pawns = Game:GetAllPlayerPawns() end end)
  if pawns then
    for _, ch in pairs(pawns) do
      if ESPValid(ch) and ch ~= me and ESP.IsAlive(ch) then
        local team = ESP.GetTeamID(ch)
        if myTeam == nil or team == nil or tostring(team) ~= tostring(myTeam) then
          local loc = ESP.ActorLocation(ch)
          local dm = ESP.DistMeters(myLoc, loc)
          if dm * 100.0 <= (CFG.MaxDistance or 40000) then
            local isBot = ESP.IsBot(ch)
            if isBot then nBot = nBot + 1 else nReal = nReal + 1 end
            list[#list + 1] = { Character = ch, Key = ESP.GetPlayerKey(ch),
                                IsBot = isBot, Distance = dm }
          end
        end
      end
    end
  end
  table.sort(list, function(a, b) return (a.Distance or 99999) < (b.Distance or 99999) end)
  -- Simpan SEMUA key yang masih terlihat, bukan hanya top-N. Dipakai sweep
  -- untuk membedakan target yang benar-benar pergi dari target yang hanya
  -- tergeser keluar dari batas MaxTracked (biar panel tidak dibuat-hancur
  -- terus di perbatasan urutan jarak).
  local seen = {}
  for _, it in ipairs(list) do
    if it.Key ~= nil then seen[it.Key] = true end
  end
  ESP.SeenKeys = seen
  local trimmed = {}
  local maxR = CFG.MaxTracked or 16
  for i, it in ipairs(list) do
    if i > maxR then break end
    trimmed[#trimmed + 1] = it
  end
  ESP.EnemyCache = trimmed
  pcall(function() ESP.UpdateRadarMarks(trimmed) end)
  return pc, nReal, nBot
end
-- ==========================================================
-- [ADV] ADVANCED OVERLAY — damage / ghost / squad / vehicle
-- Master switch: Esp9_Adv. Semua overlay read-only dan pcall-guarded.
-- ESP LOOT (ground) memakai modul yang sama untuk scan/draw, tetapi
-- punya menu + gate sendiri (Esp9_Loot) dan tidak tergantung Esp9_Adv.
-- ==========================================================
do
  local ADV = {}
  ESP.Adv = ADV
  ADV.Version = 1

  local COL = {
    white  = ESPMKC(0.93, 0.93, 0.93, 1.0),
    gray   = ESPMKC(0.70, 0.72, 0.76, 1.0),
    green  = ESPMKC(0.40, 1.00, 0.55, 1.0),
    blue   = ESPMKC(0.38, 0.72, 1.00, 1.0),
    purple = ESPMKC(0.85, 0.48, 1.00, 1.0),
    gold   = ESPMKC(1.00, 0.62, 0.18, 1.0),
    orange = ESPMKC(1.00, 0.55, 0.18, 1.0),
    red    = ESPMKC(1.00, 0.22, 0.22, 1.0),
    yellow = ESPMKC(1.00, 0.88, 0.30, 1.0),
    cyan   = ESPMKC(0.30, 1.00, 0.95, 1.0),
  }

  local function cfg()
    return _G.RapzhangConfig or {}
  end

  local function on(key)
    local c = _G.RapzhangConfig
    return c ~= nil and c[key] == true
  end

  local function masterOn()
    local c = _G.RapzhangConfig
    if c == nil then return false end
    -- Self-heal: kalau ada anak yang ON tetapi parent tersimpan OFF,
    -- overlay tetap harus hidup dan config parent diperbaiki.
    if c.Esp9_Adv ~= true then
      local kids = ESP.AdvChildren
      if kids then
        for i = 1, #kids do
          if c[kids[i]] == true then c.Esp9_Adv = true break end
        end
      end
    end
    return c.Esp9_Adv == true
  end

  local function worldGlobal(name)
    local v = rawget(_G, name)
    if v ~= nil then return v end
    local ok, value = pcall(function() return _G[name] end)
    if ok then return value end
    return nil
  end

  local function subsystem(name)
    local mgr = rawget(_G, "SubsystemMgr")
    if not mgr then
      pcall(function() mgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr") end)
    end
    if not mgr then return nil end
    local s = nil
    pcall(function() s = mgr:Get(name) end)
    return s
  end

  local function itemData(name, id)
    local d = nil
    pcall(function()
      if CDataTable and CDataTable.GetTableData then
        d = CDataTable.GetTableData(name, id)
      end
    end)
    return d
  end

  local function hidePrefix(p)
    pcall(function() ESP.Extra.HidePrefix(p) end)
  end

  local function atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi * 0.5 end
    if x == 0 and y < 0 then return -math.pi * 0.5 end
    return 0
  end

  local function camYaw(pc)
    local yaw = nil
    pcall(function()
      if pc and pc.GetControlRotation then
        local rot = pc:GetControlRotation()
        if rot then yaw = rot.Yaw or rot.yaw or rot.Pitch end
      end
    end)
    return tonumber(yaw)
  end

  -- Sudut relatif terhadap kamera: 0 = depan, +90 = kanan.
  local function bearing(meLoc, targetLoc, yaw)
    if not meLoc or not targetLoc then return nil end
    local dx = targetLoc.X - meLoc.X
    local dy = targetLoc.Y - meLoc.Y
    if dx == 0 and dy == 0 then return nil end
    local ang = math.deg(atan2(dy, dx))
    if yaw then ang = ang - yaw end
    while ang <= -180.0 do ang = ang + 360.0 end
    while ang > 180.0 do ang = ang - 360.0 end
    return ang
  end

  local function class(path, alias)
    local c = nil
    pcall(function() c = ESP.Extra.ImportClass(path, alias) end)
    return c
  end

  local function actorsOfClass(cls)
    local list = {}
    if not cls then return list end
    local arr = nil
    pcall(function()
      local g = worldGlobal("Game")
      if g and g.GetActorsByClass then arr = g:GetActorsByClass(cls) end
    end)
    if arr == nil then
      pcall(function()
        local pc = ESP.GetController()
        local base = class("/Script/Engine.Actor")
        if pc and base and GameplayStaticsESP and GameplayStaticsESP.GetAllActorsOfClass then
          arr = slua.Array(UEnums.EPropertyClass.Object, base)
          GameplayStaticsESP.GetAllActorsOfClass(pc, cls, arr)
        end
      end)
    end
    if arr then
      for _, a in pairs(arr) do
        if ESPValid(a) then list[#list + 1] = a end
      end
    end
    return list
  end

  -- Iterasi aman untuk UE TArray (slua): pairs() dulu, lalu Num()/Get()
  -- 0-based. Dipakai untuk semua hasil query game yang bisa berupa array.
  local function iterArray(arr)
    local list = {}
    if arr == nil then return list end
    local used = false
    pcall(function()
      for _, v in pairs(arr) do
        if v ~= nil then
          used = true
          list[#list + 1] = v
        end
      end
    end)
    if used then return list end
    local n = 0
    pcall(function()
      n = tonumber(arr.Num and arr:Num()) or tonumber(arr.Length and arr:Length())
        or tonumber(#arr) or 0
    end)
    for i = 0, n - 1 do
      local v = nil
      pcall(function() v = arr:Get(i) end)
      if v == nil then pcall(function() v = arr[i] end) end
      if v ~= nil then list[#list + 1] = v end
    end
    return list
  end

  -- Pola client milik game sendiri (GameAPI:UpdatePickupActorLocation):
  -- static object grid, bukan GetActorsByClass. Flag 0 dipakai untuk
  -- PickUpWrapperActor. Argumen ke-5 disamakan dengan pemakaian game (`1`);
  -- filter radius dilakukan di Lua karena arti parameter native itu tidak
  -- terdokumentasi di dump.
  local function staticObjectsInRegion(path, alias, flag, loc)
    local out = nil
    pcall(function()
      local cls = class(path, alias)
      local lib = import("STExtraBlueprintFunctionLibrary")
      local gs = gameGlobal("CGameState")
      if gs == nil then
        local gd = ESP.GetGameplayData()
        if gd and gd.GetGameState then gs = gd.GetGameState() end
      end
      if not (cls and lib and lib.LuaGetStaticObjectsInRegion and gs and loc) then return end
      local Vec = rawget(_G, "FVector") or import("Vector") or FVector
      if not Vec then return end
      local uLoc = Vec(loc.X, loc.Y, loc.Z)
      local arr = lib.LuaGetStaticObjectsInRegion(gs, cls, uLoc, flag, 1)
      if arr ~= nil then out = iterArray(arr) end
    end)
    return out
  end

  -- Query spasial milik game (CGame). Jauh lebih murah daripada
  -- GetActorsByClass untuk loot/kendaraan. Mengembalikan nil jika API tidak
  -- tersedia di client supaya pemanggil memakai fallback class scan.
  local function queryList(fn)
    local g = worldGlobal("Game")
    if not g then return nil end
    local arr = nil
    local ok = pcall(function() arr = fn(g) end)
    if not ok or arr == nil then return nil end
    local list = {}
    pcall(function()
      for _, a in pairs(arr) do
        if ESPValid(a) then list[#list + 1] = a end
      end
    end)
    return list
  end

  -- Sebagian build mengekspos Query* hanya di DS dan mengembalikan tabel
  -- kosong di client. Uji sekali: kalau class scan menemukan aktor sementara
  -- query kosong, matikan query untuk fitur itu agar ESP tidak hilang diam-diam.
  ADV.QueryOK = ADV.QueryOK or {}
  ADV.StaticOK = ADV.StaticOK or {}

  -- Urutan: query spasial game -> static object grid -> class scan.
  -- QueryPickUpWrappers bisa kosong di client walau aktornya ada; static
  -- grid adalah pola yang dipakai GameAPI untuk pickup.
  local function queryOrScan(key, queryFn, scanFn, staticFn)
    local state = ADV.QueryOK[key]
    local pool = nil
    if state ~= false then
      pool = queryList(queryFn)
      if pool ~= nil and #pool > 0 then
        ADV.QueryOK[key] = true
        return pool
      end
      if pool == nil then ADV.QueryOK[key] = false end
    end
    if staticFn and ADV.StaticOK[key] ~= false then
      local alt = staticFn()
      if alt ~= nil then
        ADV.StaticOK[key] = true
        if #alt > 0 then return alt end
      else
        ADV.StaticOK[key] = false
      end
    end
    -- Query yang sudah terbukti bekerja boleh dipercaya saat kosong supaya
    -- class scan seluruh world tidak jalan tiap 0,5 detik.
    if pool ~= nil and state == true then return pool end
    local alt = scanFn()
    if #alt > 0 then
      if pool ~= nil then ADV.QueryOK[key] = false end
      return alt
    end
    if pool ~= nil then ADV.QueryOK[key] = true return pool end
    return alt
  end

  local function qualityColor(q)
    q = tonumber(q) or 0
    if q >= 5 then return COL.gold end
    if q >= 4 then return COL.purple end
    if q >= 3 then return COL.blue end
    if q >= 2 then return COL.green end
    return COL.white
  end

  -- Kategori item mengikuti ENUM_ITEM_TYPE PUBG:
  -- 1 weapon, 2 attachment, 3 ammo, 5 backpack/armor/helmet,
  -- 6 consumable (602xxx = throwable), 10 chip/extra.
  local function lootCategory(typ, id, data)
    typ = tonumber(typ)
    if typ == nil and data ~= nil then
      typ = tonumber(data.ItemType) or tonumber(data.Type)
    end
    id = tonumber(id)
    if typ == 1 then return "weapon" end
    if typ == 2 then return "attach" end
    if typ == 3 then return "ammo" end
    if typ == 5 then return "gear" end
    if typ == 6 then
      if id and id >= 602000 and id < 603000 then return "throw" end
      return "meds"
    end
    if typ == 10 then return "misc" end
    return "misc"
  end

  local function itemEntry(id, typ, count)
    local data = id and itemData("Item", id) or nil
    local name = data and (data.ItemName or data.Name) or nil
    if type(name) ~= "string" or name == "" then
      -- Sebagian item (mis. token/currency) tidak punya baris ItemData di
      -- client; pakai nama katalog supaya label tidak jatuh ke "Item <id>".
      local e = _G.RapzhangLoot and _G.RapzhangLoot.ById and _G.RapzhangLoot.ById[id]
      name = e and e.name or nil
    end
    if type(name) ~= "string" or name == "" then
      name = "Item " .. tostring(id or "?")
    end
    if #name > 26 then name = name:sub(1, 26) .. ".." end
    local n = tonumber(count) or 0
    if n > 1 then name = name .. " x" .. tostring(math.floor(n)) end
    return name, data
  end

  local function readDefineID(obj)
    local id, typ, count = nil, nil, nil
    pcall(function()
      local d = obj.DefineID
      if d then
        id = tonumber(d.TypeSpecificID)
        typ = tonumber(d.Type)
      end
    end)
    if id == nil or id == 0 then
      pcall(function()
        local d = obj.ItemDefineID
        if d then
          id = tonumber(d.TypeSpecificID)
          typ = tonumber(d.Type)
        end
      end)
    end
    if id == nil or id == 0 then pcall(function() id = tonumber(obj.ItemID) end) end
    if id == 0 then id = nil end
    for _, k in ipairs({ "ItemCount", "Count", "PickUpCount" }) do
      if count == nil then
        pcall(function() count = tonumber(obj[k]) end)
      end
    end
    return id, typ, count
  end

  local function listItems(obj)
    local out = {}
    local readable = false
    pcall(function()
      if not obj.GetPickUpDataList then return end
      local l = obj:GetPickUpDataList()
      if not l then return end
      readable = true
      local n = 0
      pcall(function() n = tonumber(l:Num()) or 0 end)
      if n <= 0 then
        pcall(function() n = #l end)
      end
      if n <= 0 then return end
      for i = 0, n - 1 do
        local e = nil
        pcall(function() e = l:Get(i) end)
        if e == nil then e = l[i + 1] or l[i] end
        if e then
          local d = e.ID or e.DefineID or e.ItemDefineID
          local id = d and tonumber(d.TypeSpecificID) or tonumber(e.ItemID)
          local typ = d and tonumber(d.Type) or nil
          -- Count bisa 0/nil untuk item tunggal pada beberapa build; jangan
          -- buang entri karena itu membuat seluruh loot tidak tampil.
          local cnt = tonumber(e.Count)
          if not cnt or cnt < 1 then cnt = 1 end
          if id and id > 0 then
            out[#out + 1] = {
              id = id, typ = typ, count = cnt, define = d,
              -- InstanceID dipakai PickupManager:PickUpTarget (pickup per
              -- entri, bukan per wrapper) untuk fast auto pickup.
              -- Loot ground sering hanya punya ID.InstanceID; deathbox
              -- menulis InstanceID di level entri.
              iid = tonumber(e.InstanceID) or (d and tonumber(d.InstanceID)),
            }
          end
        end
      end
    end)
    return out, readable
  end

  local function actorKey(prefix, loc)
    return string.format("%s%d_%d_%d", prefix,
      math.floor(loc.X / 10.0), math.floor(loc.Y / 10.0), math.floor(loc.Z / 10.0))
  end

  -- Key stabil per aktor: nama objek UE unik dalam satu world. Fallback ke
  -- koordinat kalau SafeGetObjectName tidak tersedia. Ini mencegah label
  -- kendaraan/loot dibuat ulang setiap kali aktor bergerak sedikit.
  local function objectKey(prefix, obj, loc)
    local name = nil
    pcall(function()
      if obj and obj.SafeGetObjectName then name = obj:SafeGetObjectName() end
    end)
    if name ~= nil then
      name = tostring(name)
      if name ~= "" then return prefix .. name end
    end
    if not loc then return nil end
    return actorKey(prefix, loc)
  end

  -- --------------------------------------------------------
  -- 1) Ground loot ESP (ESP LOOT, kategori terpisah)
  -- --------------------------------------------------------
  ADV.LootCache = ADV.LootCache or {}
  ADV.LootScan = ADV.LootScan or -999.0
  ADV.GroundKey = ADV.GroundKey or "lt_"

  local LOOT_CAT_KEY = {
    weapon = "Esp9_LootWeapon",
    gear   = "Esp9_LootGear",
    ammo   = "Esp9_LootAmmo",
    meds   = "Esp9_LootMeds",
    attach = "Esp9_LootAttach",
    throw  = "Esp9_LootThrow",
    misc   = "Esp9_LootMisc",
  }

  -- Filter per item. Entri katalog memakai toggle item sendiri; ID yang
  -- belum tercatat tetap tampil selama toggle "Other" kategori ON.
  local function lootItemVisible(c, id, cat)
    local entry = _G.RapzhangLoot and _G.RapzhangLoot.ById and _G.RapzhangLoot.ById[id]
    if entry then
      if entry.group then
        local groupKey = _G.RapzhangLoot.GroupCfg
          and _G.RapzhangLoot.GroupCfg[entry.cat .. ":" .. entry.group]
        if groupKey and c[groupKey] ~= true then return false end
      end
      local cfgKey = (_G.RapzhangLoot.KeyCfg and _G.RapzhangLoot.KeyCfg[entry.key])
        or ("Esp9_LootI_" .. entry.key)
      return c[cfgKey] == true
    end
    local catKey = LOOT_CAT_KEY[cat]
    if catKey then return c[catKey .. "Other"] == true end
    return false
  end

  -- Item yang baru diambil lokal. Data wrapper di client bisa terlambat
  -- ter-update, jadi key+item di-blacklist sebentar supaya scan berikutnya
  -- tidak menggambar ulang label yang sudah dihapus.
  ADV.Picked = ADV.Picked or {}
  ADV.PickTTL = 5.0

  function ADV.NoteLootPicked(wrapper, itemID)
    if not wrapper then return end
    local loc = ESP.ActorLocation(wrapper)
    local key = objectKey(ADV.GroundKey or "lt_", wrapper, loc)
    if not key then return end
    local now = ESP.Now()
    local ttl = ADV.PickTTL or 5.0
    if itemID then
      ADV.Picked[key .. "|" .. tostring(itemID)] = now + ttl
    else
      -- Event pickup tidak selalu membawa ID item: blacklist seluruh pile
      -- sebentar supaya label tidak langsung digambar ulang dari data basi.
      ADV.Picked[key .. "|*"] = now + ttl
    end
    local keep, changed = {}, false
    for _, it in ipairs(ADV.LootCache or {}) do
      local sameItem = (itemID == nil) or (it.id == itemID)
      if it.key == key and sameItem then
        changed = true
      else
        keep[#keep + 1] = it
      end
    end
    if changed then
      ADV.LootCache = keep
      pcall(ADV.SyncLootLabels)
    end
  end

  -- Item yang di-blacklist bisa muncul sebagai item lain di pile yang sama,
  -- jadi cek ID spesifik dan wildcard (event tanpa ID) sekaligus.
  local function lootPickedAt(key, id, now)
    local t = ADV.Picked
    if not t then return false end
    local a = t[key .. "|" .. tostring(id)]
    if a and a > now then return true end
    local b = t[key .. "|*"]
    return b ~= nil and b > now
  end

  function ADV.OnPawnPickup(_, _, uCharacter, uWrapperActor)
    if not uWrapperActor then return end
    -- Pickup oleh pemain mana pun tetap membuat label pile itu basi; tidak
    -- perlu memfilter karakter lokal (objek karakter bisa beda wrapper).
    pcall(ADV.NoteLootPicked, uWrapperActor, nil)
  end

  -- Instance PickUpListPanel adalah singleton UI yang dipakai game lewat
  -- UIManager.GetUI(UIManager.UI_Config_InGame.PickUpListPanel). Library
  -- ClientIngameUIFunctionLibrary tidak ada di semua build, jadi jalur itu
  -- hanya fallback.
  local function findPickupPanel()
    local panel = nil
    pcall(function()
      local um = rawget(_G, "UIManager")
      local cfg = um and um.UI_Config_InGame and um.UI_Config_InGame.PickUpListPanel
      if um and cfg and type(um.GetUI) == "function" then
        panel = um.GetUI(cfg)
      end
    end)
    if panel == nil then
      pcall(function()
        local um = rawget(_G, "UIManager")
        local cfg = um and um.UI_Config_InGame and um.UI_Config_InGame.PickUpListPanel
        if um and cfg and type(um.GetUI) == "function" then panel = um:GetUI(cfg) end
      end)
    end
    if panel == nil then
      pcall(function()
        local ok, lib = pcall(require, "GameLua.Mod.Library.Client.ClientIngameUIFunctionLibrary")
        local icp = ok and lib and lib.GetInputControlPanel and lib.GetInputControlPanel() or nil
        local main = icp and icp.MainControlBaseUI
        local bp = main and main.BackPackPickUpPanel_BP
        panel = bp and bp.PickUpListPanel_BP
      end)
    end
    if panel == nil then
      pcall(function()
        local icp = worldGlobal("InputControlPanel")
        local main = icp and icp.MainControlBaseUI
        local bp = main and main.BackPackPickUpPanel_BP
        panel = bp and bp.PickUpListPanel_BP
      end)
    end
    return panel
  end

  -- Bungkus satu method instance. Idempoten: kalau method sudah wrapper kita,
  -- jangan dibungkus lagi saat panel yang sama ditemukan pada retry berikut.
  local function hookPanelMethod(panel, name, makeWrap)
    if not panel then return false end
    local cur = nil
    pcall(function() cur = panel[name] end)
    if type(cur) ~= "function" then return false end
    ADV._pickWraps = ADV._pickWraps or {}
    if cur == ADV._pickWraps[name] then return true end
    local wrap = makeWrap(cur)
    local ok = false
    if pcall(function() panel[name] = wrap end) then ok = true end
    if not ok then
      -- Sebagian objek UI memakai proxy userdata: assignment instance bisa
      -- ditolak. Fallback ke tabel class lewat metatable.__index.
      pcall(function()
        local mt = getmetatable(panel)
        local idx = mt and mt.__index
        if type(idx) == "table" and type(idx[name]) == "function" then
          idx[name] = wrap
          ok = true
        end
      end)
    end
    if ok then ADV._pickWraps[name] = wrap end
    return ok
  end

  local function wrapPickupItem(orig)
    return function(self, uPlayerCharacter, pickupItem, pickCount)
      pcall(function()
        local wrapper = pickupItem and pickupItem.Wrapper
        local mainItem = pickupItem and pickupItem.MainItemData
        local id = mainItem and mainItem.ID and tonumber(mainItem.ID.TypeSpecificID) or nil
        if wrapper then ADV.NoteLootPicked(wrapper, id) end
      end)
      return orig(self, uPlayerCharacter, pickupItem, pickCount)
    end
  end

  -- Hitungan index di PickUpGroundItemByIndex memakai offset scroll yang sama
  -- dengan source game. Diperlukan karena quick-pick memanggil method ini,
  -- lalu method ini memanggil karakter langsung (bypass PickUpWrapperActor).
  local function groundItemAt(self, nIndex)
    local wrapper, id = nil, nil
    pcall(function()
      local list = self and self.GroundItemList
      local reuse = self and self.CustomizePickUpPanel_BP
        and self.CustomizePickUpPanel_BP.BTReuseList
      if not list or not reuse then return end
      local sizeY = tonumber(reuse.itemSizeY) or 0
      if sizeY <= 0 then return end
      local offset = tonumber(reuse.CurrentOffset) or 0
      local hide, frac = math.modf(offset / sizeY)
      if 0.1 < frac then hide = hide + 1 end
      local idx = math.floor(hide + (tonumber(nIndex) or 1) - 1)
      local n = 0
      pcall(function() n = tonumber(list:Num()) or 0 end)
      if n <= 0 then pcall(function() n = #list end) end
      if idx < 0 or idx >= n then return end
      local itemData = nil
      pcall(function() itemData = list:Get(idx) end)
      if itemData == nil then itemData = list[idx + 1] end
      local sr = itemData and itemData.SearchItemResult
      wrapper = sr and sr.Wrapper or nil
      local md = sr and sr.MainItemData
      id = md and md.ID and tonumber(md.ID.TypeSpecificID) or nil
    end)
    return wrapper, id
  end

  local function wrapGroundIndex(orig)
    return function(self, nIndex)
      local wrapper, id = groundItemAt(self, nIndex)
      if wrapper then pcall(ADV.NoteLootPicked, wrapper, id) end
      return orig(self, nIndex)
    end
  end

  -- Panel pickup adalah jalur Lua yang dipakai pickup manual maupun auto-pick.
  -- Bungkus method instance-nya supaya label bisa hilang tepat saat pickup,
  -- tanpa menunggu RPC/sinkronisasi wrapper.
  function ADV.InstallPickupHook()
    local installed = false
    local panel = findPickupPanel()

    if hookPanelMethod(panel, "PickUpWrapperActor", wrapPickupItem) then installed = true end
    if hookPanelMethod(panel, "PickUpGroundItemByIndex", wrapGroundIndex) then installed = true end

    -- Fallback untuk jalur yang memanggil method karakter/pickup manager
    -- langsung (mis. quick pickup). Best-effort: kalau userdata menolak
    -- assignment, panel hook di atas tetap dipakai.
    local me = ESP.GetLocalCharacter()
    if me and type(me.PickUpWrapperActor) == "function"
      and me.PickUpWrapperActor ~= ADV._charWrap then
      local orig = me.PickUpWrapperActor
      local wrap = function(self, wrapper, mainItem, cnt, flag)
        pcall(function()
          local id = mainItem and mainItem.ID and tonumber(mainItem.ID.TypeSpecificID) or nil
          if wrapper then ADV.NoteLootPicked(wrapper, id) end
        end)
        return orig(self, wrapper, mainItem, cnt, flag)
      end
      if pcall(function() me.PickUpWrapperActor = wrap end) then
        ADV._charWrap, ADV._charOrig = wrap, orig
        installed = true
      end
    end

    -- Sinyal event pickup (kalau build mengirimnya ke client). Signature
    -- mengikuti PickupSearchSubsystem:CheckRemove(_, _, Character, Wrapper).
    if not ADV._pickEvent then
      local es = worldGlobal("EventSystem")
      local et = worldGlobal("EVENTTYPE_INGAME_NORMAL")
      local eid = worldGlobal("EVENTID_PAWN_PICK_UP_ITEM")
      if es and es.registEvent and et and eid then
        if pcall(function() es:registEvent(et, eid, ADV.OnPawnPickup) end) then
          ADV._pickEvent = true
          installed = true
        end
      end
    end

    return installed
  end

  function ADV.ScanLoot(me, now)
    local c = cfg()
    now = now or ESP.Now()
    local radius = tonumber(c.Esp9_LootDist) or 120
    radius = math.max(20, math.min(300, radius))
    local meLoc = ESP.ActorLocation(me)
    if not meLoc then ADV.LootCache = {} return end
    -- Bersihkan blacklist pickup yang sudah kedaluwarsa.
    for k, exp in pairs(ADV.Picked or {}) do
      if (tonumber(exp) or 0) <= now then ADV.Picked[k] = nil end
    end

    local want = {}
    local any = false
    for cat, key in pairs(LOOT_CAT_KEY) do
      if c[key] == true then want[cat] = true any = true end
    end
    if not any then ADV.LootCache = {} return end

    local out = {}
    -- Key yang masih tampil pada scan sebelumnya. Kalau wrapper yang sama
    -- sekarang daftar itemnya kosong, isinya sudah diambil dan label harus
    -- langsung dibuang, bukan menunggu TTL Sweep.
    local prevVisible = {}
    for _, it in ipairs(ADV.LootCache or {}) do prevVisible[it.key] = true end
    ADV.ListOK = ADV.ListOK or {}
    local seenNow = {}
    local pool = queryOrScan("loot",
      function(g) return g:QueryPickUpWrappers(meLoc, radius * 100.0, nil, false, 70) end,
      function() return actorsOfClass(class("/Script/ShadowTrackerExtra.PickUpWrapperActor", "PickUpWrapperActor")) end,
      function() return staticObjectsInRegion("/Script/ShadowTrackerExtra.PickUpWrapperActor", "PickUpWrapperActor", 0, meLoc) end)
    for _, a in ipairs(pool) do
      local loc = ESP.ActorLocation(a)
      if loc then
        local dist = ESP.DistMeters(meLoc, loc)
        if dist <= radius then
          local key = objectKey(ADV.GroundKey, a, loc)
          if key then seenNow[key] = true end
          local removed = false
          pcall(function()
            removed = a.bItemRemoved == true or a.bPickedUp == true
              or a.bIsPickedUp == true or a.bTaken == true
          end)
          local id, typ, count = readDefineID(a)
          local entries, listed = listItems(a)
          if listed then ADV.ListOK[key] = true end
          local listedBefore = ADV.ListOK[key] == true
          -- Wrapper yang tadinya punya label lalu daftar itemnya kosong/tak
          -- terbaca berarti isinya sudah diambil. Jangan hidupkan lagi dari
          -- DefineID statis yang tidak ikut ter-update.
          local emptied = prevVisible[key] == true and #entries == 0
            and (listed or listedBefore)
          if not removed and not emptied then
            -- DefineID hanya dipakai kalau list item memang tidak tersedia
            -- di build ini (bukan saat list terbaca tapi sudah kosong).
            if #entries == 0 and not listed and id
              and (tonumber(count) == nil or tonumber(count) > 0) then
              entries = { { id = id, typ = typ, count = count } }
            end
            if #entries > 0 then
              -- Satu wrapper bisa berisi beberapa item. Pilih item pertama
              -- yang kategorinya ON dan toggle item-nya tidak dimatikan.
              local picked = nil
              for _, e in ipairs(entries) do
                local entry = _G.RapzhangLoot and _G.RapzhangLoot.ById and _G.RapzhangLoot.ById[e.id]
                local cat = entry and entry.cat or lootCategory(e.typ, e.id, nil)
                if not lootPickedAt(key, e.id, now)
                  and want[cat] and lootItemVisible(c, e.id, cat) then
                  picked = e
                  break
                end
              end
              if picked then
                local name, data = itemEntry(picked.id, picked.typ, picked.count)
                out[#out + 1] = {
                  key = key,
                  id = picked.id,
                  actor = a,
                  x = loc.X, y = loc.Y, z = loc.Z,
                  dist = dist,
                  text = string.format("%s · %dm", name, math.floor(dist + 0.5)),
                  color = qualityColor(data and data.ItemQuality),
                  off = 0,
                }
              end
            end
          end
        end
      end
    end

    table.sort(out, function(a, b) return (a.dist or 99999) < (b.dist or 99999) end)
    -- ListOK hanya perlu untuk wrapper yang masih terlihat/ada di pool. Key
    -- dari wrapper yang sudah hancur/keluar radius dibuang supaya tabel tidak
    -- tumbuh sepanjang match.
    for k in pairs(ADV.ListOK) do
      if not seenNow[k] and not prevVisible[k] then ADV.ListOK[k] = nil end
    end
    local trimmed = {}
    local cap = tonumber(ESP.LootCap) or 70
    for i = 1, math.min(#out, 70) do
      if i > cap then break end
      trimmed[i] = out[i]
    end
    ADV.LootCache = trimmed
  end

  -- Samakan label loot dengan cache scan. Label yang itemnya sudah diambil
  -- atau aktornya hilang dihancurkan pada frame yang sama supaya tidak ada
  -- tanda hantu dan widget tidak menumpuk.
  function ADV.SyncLootLabels()
    -- Modul ADV berada di luar blok `local EX = ESP.Extra`; akses lewat
    -- ESP.Extra supaya tidak menyentuh global EX yang nil (dulu membuat
    -- seluruh DrawLoot gagal dan semua label loot hilang).
    local extra = ESP.Extra
    if not extra or not extra.Labels then return end
    local keep = {}
    for _, it in ipairs(ADV.LootCache or {}) do keep[it.key] = true end
    local prefix = ADV.GroundKey or "lt_"
    local n = #prefix
    local gone = nil
    for key in pairs(extra.Labels) do
      if type(key) == "string" and key:sub(1, n) == prefix and not keep[key] then
        gone = gone or {}
        gone[#gone + 1] = key
      end
    end
    if not gone then return end
    local lastSeen = extra.LastSeen or {}
    for _, key in ipairs(gone) do
      lastSeen[key] = nil
      -- Sembunyikan dulu: DestroyMark bisa tertunda/gagal di sebagian build,
      -- sedangkan HideLabel langsung membuat widget tidak terlihat.
      if extra.HideLabel then pcall(extra.HideLabel, key) end
      if extra.DestroyMark then pcall(extra.DestroyMark, key) end
    end
  end

  -- Potong cache loot ke cap baru tanpa menunggu scan berikutnya. Dipakai
  -- saat Optimasi ESP Low dinyalakan supaya label/widget di luar cap langsung
  -- dilepas, bukan tetap menunggu 1,1 detik sampai scan low-end berikutnya.
  function ADV.TrimLootCache(cap)
    local list = ADV.LootCache or {}
    cap = tonumber(cap)
    if cap == nil or cap < 1 or #list <= cap then return end
    local keep = {}
    for i = 1, cap do keep[i] = list[i] end
    ADV.LootCache = keep
  end

  -- Buang cache loot yang sudah di luar radius scan saat ini. Dipanggil tiap
  -- frame draw supaya label tidak menunggu scan berikutnya (0,55 dtk; 1,10 dtk
  -- saat Optimasi ESP Low) ketika pemain bergerak keluar radius atau slider
  -- radius diperkecil. Actor yang sudah tidak valid juga langsung dibuang.
  function ADV.PruneLootRange()
    local list = ADV.LootCache or {}
    if #list == 0 then return end
    local me = ESP.GetLocalCharacter()
    local meLoc = me and ESP.ActorLocation(me) or nil
    if not meLoc then
      ADV.LootCache = {}
      pcall(ADV.SyncLootLabels)
      return
    end
    local c = cfg()
    local radius = tonumber(c.Esp9_LootDist) or 120
    radius = math.max(20, math.min(300, radius))
    local keep, changed = {}, false
    for _, it in ipairs(list) do
      local alive = true
      if it.actor ~= nil and ESPValid then
        local ok, valid = pcall(ESPValid, it.actor)
        if ok and valid == false then alive = false end
      end
      local d = ESP.DistMeters(meLoc, { X = it.x, Y = it.y, Z = it.z })
      if alive and d <= radius then
        keep[#keep + 1] = it
      else
        changed = true
      end
    end
    if changed then
      ADV.LootCache = keep
      pcall(ADV.SyncLootLabels)
    end
  end

  function ADV.DrawLoot(pc, now)
    -- Radius dicek tiap frame: label yang sudah di luar jangkauan langsung
    -- hilang tanpa menunggu ScanLoot berikutnya.
    pcall(ADV.PruneLootRange)
    -- Sinkronisasi label tidak boleh memblokir render loot kalau ada API
    -- widget yang tidak tersedia di build tertentu.
    pcall(ADV.SyncLootLabels)
    local list = ADV.LootCache or {}
    for _, it in ipairs(list) do
      local s = ESP.Project(pc, { X = it.x, Y = it.y, Z = it.z + 25.0 })
      if s then
        ESP.Extra.DrawLabel(it.key, s.X, s.Y + (it.off or 0), it.text, it.color)
        ESP.Extra.LastSeen[it.key] = now
      elseif ESP.Extra.HideLabel then
        -- Proyeksi gagal (di belakang kamera/tepi layar): jangan biarkan
        -- label tertinggal di posisi terakhir.
        pcall(ESP.Extra.HideLabel, it.key)
      end
    end
  end

  -- --------------------------------------------------------
  -- 2) Damage direction + attacker lock
  -- --------------------------------------------------------
  ADV.Dmg = ADV.Dmg or {
    t = -999.0, casterT = -999.0, caster = nil, casterKey = nil,
    hits = 0, sum = 0, head = 0, cx = nil, cy = nil, cz = nil,
  }
  ADV._hookTried = false
  ADV._hooked = false
  ADV._hookAt = -999.0

  -- Cari objek DamageInfo di daftar argumen event. EventSystem memanggil
  -- fn(eventType, eventID, ...) sehingga DamageInfo ada di posisi 3, tetapi
  -- wrapper subsystem bisa memakai posisi lain. Jangan mengandalkan indeks.
  local function findDamageInfo(...)
    local n = select("#", ...)
    for i = 1, n do
      local v = select(i, ...)
      if v ~= nil then
        local t = type(v)
        if t == "table" or t == "userdata" then
          local hit = false
          pcall(function()
            hit = v.Target ~= nil or v.Damage ~= nil or v.Caster ~= nil
          end)
          if hit then return v end
        end
      end
    end
    return nil
  end

  -- PlayerKey bisa diambil dari pawn, controller, PlayerState, atau wrapper.
  -- Dipakai untuk mencocokkan Target/Caster damage tanpa harus lebih dulu
  -- me-resolve pawn (yang bisa gagal di awal match).
  local function playerKeyOf(a)
    if not ESPValid(a) then return nil end
    local key = nil
    pcall(function() if a.GetPlayerKey then key = a:GetPlayerKey() end end)
    if key == nil then pcall(function() key = a.PlayerKey end) end
    if key == nil then
      local ps = nil
      pcall(function() if a.GetPlayerStateSafety then ps = a:GetPlayerStateSafety() end end)
      if not ESPValid(ps) then pcall(function() ps = a.PlayerState end) end
      if ESPValid(ps) then pcall(function() key = ps.PlayerKey end) end
    end
    if key == nil then pcall(function() key = a.UID end) end
    if key == nil then return nil end
    return key
  end

  -- DamageInfo.Caster bisa pawn, controller, atau PlayerState. Kembalikan
  -- character yang punya lokasi supaya arah tembakan/lock shooter bisa digambar.
  local function characterForActor(a)
    if not ESPValid(a) then return nil end
    if ESP.ActorLocation(a) then return a end
    local ch = nil
    pcall(function() if a.GetPlayerCharacter then ch = a:GetPlayerCharacter() end end)
    if not ESPValid(ch) then pcall(function() ch = a.Pawn end) end
    if not ESPValid(ch) then pcall(function() ch = a.Character end) end
    if ESPValid(ch) and ESP.ActorLocation(ch) then return ch end
    local key = playerKeyOf(a)
    if key == nil then return nil end
    local gd = ESP.GetGameplayData()
    if gd then
      pcall(function() if gd.GetPlayerCharacter then ch = gd.GetPlayerCharacter(key) end end)
      if ESPValid(ch) and ESP.ActorLocation(ch) then return ch end
    end
    pcall(function()
      local g = worldGlobal("Game")
      if g and g.GetPlayerCharacterByKey then ch = g:GetPlayerCharacterByKey(key) end
    end)
    if ESPValid(ch) and ESP.ActorLocation(ch) then return ch end
    -- Terakhir: scan pawn yang direplikasi dan cocokkan PlayerKey-nya.
    pcall(function()
      local g = worldGlobal("Game")
      local pawns = g and g.GetAllPlayerPawns and g:GetAllPlayerPawns() or nil
      for _, p in ipairs(iterArray(pawns)) do
        if ESPValid(p) then
          local pk = nil
          pcall(function() if p.GetPlayerKey then pk = p:GetPlayerKey() end end)
          if pk == nil then pcall(function() pk = p.PlayerKey end) end
          if pk ~= nil and tostring(pk) == tostring(key) and ESP.ActorLocation(p) then
            ch = p
            break
          end
        end
      end
    end)
    if ESPValid(ch) and ESP.ActorLocation(ch) then return ch end
    return nil
  end

  ADV._dmgSeen = nil
  ADV._dmgSeenT = -999.0

  function ADV.OnDamage(a, b, c, d, e)
    pcall(function()
      if not (masterOn() and on("Esp9_DmgDir")) then return end
      local info = findDamageInfo(a, b, c, d, e)
      if info == nil then return end

      local me = ESP.GetLocalCharacter()
      if not ESPValid(me) then return end
      local meKey = ESP.GetPlayerKey(me)
      local target = info.Target
      if not ESPValid(target) then return end
      local targetKey = playerKeyOf(target)
      if targetKey == nil then
        target = characterForActor(target)
        if ESPValid(target) then targetKey = ESP.GetPlayerKey(target) end
      end
      if meKey == nil or targetKey == nil then return end
      if tostring(targetKey) ~= tostring(meKey) then return end

      -- Self-damage (jatuh, grenade sendiri, zone) tidak punya arah musuh.
      -- Jangan pernah mengunci diri sendiri sebagai "shooter", dan jangan
      -- memakai ulang arah lama saat damage tanpa caster (zone/fall).
      local caster = characterForActor(info.Caster)
      if not ESPValid(caster) then return end
      local ck = playerKeyOf(info.Caster) or ESP.GetPlayerKey(caster)
      if ck ~= nil and tostring(ck) == tostring(meKey) then return end
      local cl = ESP.ActorLocation(caster)
      if not cl then return end

      local now = ESP.Now()
      -- Wrapper subsystem dan registrasi EventSystem bisa menerima DamageInfo
      -- yang sama. Abaikan salinan kedua dalam window singkat; sertakan
      -- damage + caster supaya pellet/hit berbeda tidak ikut tertelan.
      local sig = tostring(info) .. "|" .. tostring(info.Damage) .. "|" .. tostring(ck)
      if ADV._dmgSeen == sig and (now - (ADV._dmgSeenT or -999.0)) < 0.15 then return end
      ADV._dmgSeen, ADV._dmgSeenT = sig, now

      local dm = ADV.Dmg
      if (now - (dm.t or -999.0)) > 2.5 then
        dm.hits, dm.sum, dm.head = 0, 0, 0
      end
      dm.t = now
      dm.hits = (dm.hits or 0) + 1
      dm.sum = (dm.sum or 0) + (tonumber(info.Damage) or 0)
      local head = false
      pcall(function()
        head = info.IsHeadShot == true or info.bIsHeadShot == true
          or info.IsHeadShotDamage == true
      end)
      if head then dm.head = (dm.head or 0) + 1 end

      dm.caster = caster
      dm.casterKey = ck
      dm.casterName = nil
      dm.casterBot = ESP.IsBot(caster)
      dm.casterT = now
      dm.cx, dm.cy, dm.cz = cl.X, cl.Y, cl.Z
    end)
  end

  function ADV.InstallDamageHook()
    if ADV._hooked then return end
    local now = ESP.Now()
    if ADV._hookTried and (now - (ADV._hookAt or -999.0)) < 5.0 then return end
    ADV._hookTried = true
    ADV._hookAt = now
    local installed = false

    -- Jalur 1: registrasi EventSystem tanpa ctx. EventSystem memanggil
    -- fn(eventType, eventID, ...) sehingga findDamageInfo menemukan DamageInfo
    -- tanpa bergantung pada posisi argumen.
    local es = worldGlobal("EventSystem")
    local et = worldGlobal("EVENTTYPE_INGAME")
    local eid = worldGlobal("EVENTID_TAKE_DAMAGE_CLIENT")
    if es and es.registEvent and et and eid then
      pcall(function()
        if es.unregistEvent then es:unregistEvent(et, eid, ADV.OnDamage) end
      end)
      local ok = pcall(function() es:registEvent(et, eid, ADV.OnDamage) end)
      installed = ok
    end

    -- Jalur 2: bungkus method subsystem yang game sendiri daftarkan pada
    -- event yang sama. Signature (self, _, __, DamageInfo) membuat DamageInfo
    -- selalu di posisi 3. Dedupe di OnDamage mencegah hit dihitung dua kali
    -- kalau kedua jalur menerima objek DamageInfo yang sama.
    local sub = subsystem("SoundVisualizationSubsystem")
    if sub then
      local orig = nil
      pcall(function() orig = sub.AddBeHitToCache end)
      if type(orig) == "function" and orig ~= ADV._dmgWrap then
        local w = function(self, a, b, c, d, e)
          local info = findDamageInfo(a, b, c, d, e)
          if info then pcall(ADV.OnDamage, nil, nil, info) end
          return orig(self, a, b, c, d, e)
        end
        local applied = pcall(function() sub.AddBeHitToCache = w end)
        if applied then
          ADV._dmgWrap = w
          ADV._dmgOrig = orig
          installed = true
        end
      elseif orig == ADV._dmgWrap then
        installed = true
      end
    end
    ADV._hooked = installed
  end

  function ADV.UninstallDamageHook()
    local sub = subsystem("SoundVisualizationSubsystem")
    if sub and ADV._dmgWrap then
      pcall(function()
        if sub.AddBeHitToCache == ADV._dmgWrap and ADV._dmgOrig then
          sub.AddBeHitToCache = ADV._dmgOrig
        end
      end)
    end
    local es = worldGlobal("EventSystem")
    local et = worldGlobal("EVENTTYPE_INGAME")
    local eid = worldGlobal("EVENTID_TAKE_DAMAGE_CLIENT")
    if es and es.unregistEvent and et and eid then
      pcall(function() es:unregistEvent(et, eid, ADV.OnDamage) end)
    end
    ADV._dmgWrap, ADV._dmgOrig = nil, nil
    ADV._hooked = false
    ADV._hookTried = false
    ADV._hookAt = -999.0
    ADV._dmgSeen, ADV._dmgSeenT = nil, -999.0
  end

  function ADV.HideDamage()
    ESP.Extra.HideExtra("dm_arc")
    ESP.Extra.HideLabel("dm_txt")
    ESP.Extra.HideBox("dm_box")
    ESP.Extra.HideLabel("dm_box_txt")
  end

  function ADV.DrawDamage(pc, me, vw, vh, now)
    local d = ADV.Dmg
    if not d then return end
    local age = now - (d.t or -999.0)
    local meLoc = ESP.ActorLocation(me)
    local meKey = ESP.GetPlayerKey(me)
    local cx, cy = vw * 0.5, vh * 0.5

    if age <= 3.0 and (d.hits or 0) > 0 and meLoc and d.cx then
      local ang = bearing(meLoc, { X = d.cx, Y = d.cy, Z = d.cz or meLoc.Z }, camYaw(pc))
      if ang then
        local seg = 7
        local span = 24.0
        local r = math.min(vw, vh) * 0.17
        local t = nil
        pcall(function() t = ESP.Extra.GetExtra("dm_arc", seg) end)
        if t then
          local base = ang - 90.0
          for i = 1, seg do
            local a1 = math.rad(base - span + (2.0 * span) * ((i - 1) / seg))
            local a2 = math.rad(base - span + (2.0 * span) * (i / seg))
            ESP.SetBrush(t[i], COL.red, "dm_arc")
            ESP.DrawLine(t[i],
              cx + math.cos(a1) * r, cy + math.sin(a1) * r,
              cx + math.cos(a2) * r, cy + math.sin(a2) * r, 3.0)
          end
        end
        local dist = ESP.DistMeters(meLoc, { X = d.cx, Y = d.cy, Z = d.cz or meLoc.Z })
        local txt = string.format("%d hit  %d dmg  %dm%s",
          d.hits, math.floor((d.sum or 0) + 0.5), math.floor(dist + 0.5),
          (d.head or 0) > 0 and ("  HS x" .. tostring(d.head)) or "")
        ESP.Extra.DrawLabel("dm_txt", cx, cy + r + 16.0, txt, COL.red)
        ESP.Extra.LastSeen["dm_txt"] = now
        ESP.Extra.LastSeen["dm_arc"] = now
      end
    else
      ESP.Extra.HideExtra("dm_arc")
      ESP.Extra.HideLabel("dm_txt")
    end

    local casterAge = now - (d.casterT or -999.0)
    local selfCaster = d.casterKey ~= nil and meKey ~= nil
      and tostring(d.casterKey) == tostring(meKey)
    if casterAge <= 6.0 and not selfCaster and ESPValid(d.caster) and ESP.IsAlive(d.caster) then
      local head, feet = ESP.GetHeadFeet(d.caster)
      local hs, fs = ESP.Project(pc, head), ESP.Project(pc, feet)
      if hs and fs then
        local h = fs.Y - hs.Y
        if h >= 12.0 and h <= vh * 1.5 then
          local w = math.max(22.0, h * 0.62)
          local bx = (hs.X + fs.X) * 0.5
          local by = (hs.Y + fs.Y) * 0.5
          ESP.Extra.DrawBox("dm_box", bx, by, w, h, COL.red, "dm_box", 2.0)
          -- Nama shooter di-cache saat lock; ResolveName cukup sekali per
          -- shooter, bukan tiap frame selama 6 detik.
          if d.casterName == nil then
            local nm = "ENEMY"
            pcall(function() nm = ESP.ResolveName(d.caster, d.casterBot) end)
            if type(nm) ~= "string" or nm == "" then nm = "ENEMY" end
            d.casterName = nm
          end
          local name = d.casterName
          local dist = meLoc and ESP.DistMeters(meLoc, ESP.ActorLocation(d.caster)) or 0
          ESP.Extra.DrawLabel("dm_box_txt", bx, hs.Y - 12.0,
            string.format("SHOOTER %s · %dm", name, math.floor(dist + 0.5)), COL.red)
          ESP.Extra.LastSeen["dm_box"] = now
          ESP.Extra.LastSeen["dm_box_txt"] = now
        end
      end
    else
      ESP.Extra.HideBox("dm_box")
      ESP.Extra.HideLabel("dm_box_txt")
    end
  end

  -- --------------------------------------------------------
  -- 3) Ghost last-seen marker
  -- --------------------------------------------------------
  ADV.Ghosts = ADV.Ghosts or {}

  function ADV.UpdateGhosts(me, now)
    if not on("Esp9_Ghost") then
      if next(ADV.Ghosts) then ADV.Ghosts = {} end
      return
    end
    local seen = {}
    for _, it in ipairs(ESP.EnemyCache or {}) do
      local c = it.Character
      if ESPValid(c) and it.Key ~= nil then
        local loc = ESP.ActorLocation(c)
        if loc then
          local g = ADV.Ghosts[it.Key]
          if not g then
            g = { key = it.Key }
            ADV.Ghosts[it.Key] = g
            pcall(function() g.name = ESP.ResolveName(c, it.IsBot) end)
            if type(g.name) ~= "string" or g.name == "" then
              g.name = it.IsBot and "Bot" or "Enemy"
            end
          end
          g.x, g.y, g.z = loc.X, loc.Y, loc.Z
          g.t = now
          g.live = false
          seen[it.Key] = true
        end
      end
    end
    for key, g in pairs(ADV.Ghosts) do
      if not seen[key] then
        local age = now - (g.t or 0)
        g.live = age <= 12.0
        if age > 12.5 then ADV.Ghosts[key] = nil end
      end
    end
  end

  function ADV.DrawGhosts(pc, me, now)
    local meLoc = ESP.ActorLocation(me)
    for key, g in pairs(ADV.Ghosts or {}) do
      if g.live then
        local age = now - (g.t or 0)
        local s = ESP.Project(pc, { X = g.x, Y = g.y, Z = g.z + 40.0 })
        if s then
          local k = "gh_" .. tostring(key)
          local col = age < 4.0 and COL.cyan or (age < 8.0 and COL.blue or COL.gray)
          local ck = "gh_" .. (age < 4.0 and "fresh" or (age < 8.0 and "warm" or "old"))
          ESP.Extra.DrawBox(k, s.X, s.Y, 26.0, 40.0, col, ck, 1.4)
          local dist = meLoc and ESP.DistMeters(meLoc, { X = g.x, Y = g.y, Z = g.z }) or 0
          ESP.Extra.DrawLabel(k .. "_t", s.X, s.Y - 26.0,
            string.format("%s · %dm · %ds", tostring(g.name or "Enemy"),
              math.floor(dist + 0.5), math.floor(age)), col)
          ESP.Extra.LastSeen[k] = now
          ESP.Extra.LastSeen[k .. "_t"] = now
        end
      end
    end
  end

  -- --------------------------------------------------------
  -- 4) Squad strength tracker
  -- --------------------------------------------------------
  ADV.SquadCache = ADV.SquadCache or {}
  ADV.SquadScan = ADV.SquadScan or -999.0

  -- Sumber utama: semua pawn yang direplikasi. ESP.EnemyCache hanya top-16
  -- by distance, jadi tracker tidak boleh bergantung pada cache itu saja.
  function ADV.ScanSquad(me, now)
    local myTeam = ESP.GetTeamID(me)
    local meLoc = ESP.ActorLocation(me)
    if myTeam == nil or not meLoc then ADV.SquadCache = {} return end
    local pawns = nil
    pcall(function()
      local g = worldGlobal("Game")
      if g and g.GetAllPlayerPawns then pawns = g:GetAllPlayerPawns() end
    end)
    local teams = {}
    local function add(c, dist)
      if not ESPValid(c) or c == me then return end
      local tid = ESP.GetTeamID(c)
      if tid == nil or tostring(tid) == tostring(myTeam) then return end
      if not ESP.IsAlive(c) and not ESP.IsKnocked(c) then return end
      local tk = tostring(tid)
      local t = teams[tk]
      if not t then t = { id = tk, up = 0, down = 0, dist = 99999 } teams[tk] = t end
      if ESP.IsKnocked(c) then t.down = t.down + 1 else t.up = t.up + 1 end
      if dist and dist < t.dist then t.dist = dist end
    end
    local list = iterArray(pawns)
    if #list > 0 then
      for _, c in ipairs(list) do
        add(c, ESP.DistMeters(meLoc, ESP.ActorLocation(c)))
      end
    else
      for _, it in ipairs(ESP.EnemyCache or {}) do
        add(it.Character, it.Distance)
      end
    end
    local out = {}
    for _, t in pairs(teams) do out[#out + 1] = t end
    table.sort(out, function(a, b) return (a.dist or 99999) < (b.dist or 99999) end)
    ADV.SquadCache = out
  end

  function ADV.HideSquad()
    ESP.Extra.HideLabel("sq_h")
    for i = 1, 8 do ESP.Extra.HideLabel("sq_" .. tostring(i)) end
  end

  function ADV.DrawSquad(pc, me, vw, vh, now)
    local list = ADV.SquadCache or {}
    if #list == 0 then
      -- Fallback: kelompokkan ESP.EnemyCache kalau scan pawn tidak tersedia.
      local teams = {}
      for _, it in ipairs(ESP.EnemyCache or {}) do
        local c = it.Character
        if ESPValid(c) then
          local tid = ESP.GetTeamID(c)
          local tk = tostring(tid or "-")
          local t = teams[tk]
          if not t then
            t = { id = tk, up = 0, down = 0, dist = 99999 }
            teams[tk] = t
          end
          if ESP.IsKnocked(c) then t.down = t.down + 1 else t.up = t.up + 1 end
          if (it.Distance or 99999) < t.dist then t.dist = it.Distance end
        end
      end
      local tmp = {}
      for _, t in pairs(teams) do tmp[#tmp + 1] = t end
      table.sort(tmp, function(a, b) return (a.dist or 99999) < (b.dist or 99999) end)
      list = tmp
    end
    if #list == 0 then ADV.HideSquad() return end
    table.sort(list, function(a, b) return (a.dist or 99999) < (b.dist or 99999) end)

    ESP.Extra.DrawLabel("sq_h", 96.0, 118.0, "SQUAD INTEL", COL.gray)
    ESP.Extra.LastSeen["sq_h"] = now
    for i = 1, math.min(#list, 8) do
      local t = list[i]
      local txt = string.format("T%s  %d up", tostring(t.id), t.up)
      if t.down > 0 then txt = txt .. "  " .. tostring(t.down) .. " down" end
      local col = t.down > 0 and COL.yellow or COL.white
      ESP.Extra.DrawLabel("sq_" .. tostring(i), 96.0, 118.0 + i * 13.0, txt, col)
      ESP.Extra.LastSeen["sq_" .. tostring(i)] = now
    end
    for i = math.min(#list, 8) + 1, 8 do
      ESP.Extra.HideLabel("sq_" .. tostring(i))
    end
  end

  -- --------------------------------------------------------
  -- 5) Vehicle intel
  -- --------------------------------------------------------
  ADV.VehCache = ADV.VehCache or {}
  ADV.VehScan = ADV.VehScan or -999.0

  local function vehicleOccupants(v, myTeam)
    local total, enemy = 0, 0
    if myTeam == nil then return total, enemy end
    local arr = nil
    pcall(function()
      local g = worldGlobal("Game")
      if g and g.GetPlayersOnVehicle then arr = g:GetPlayersOnVehicle(v) end
    end)
    if arr then
      for _, p in pairs(arr) do
        if ESPValid(p) then
          total = total + 1
          local tid = ESP.GetTeamID(p)
          if tid == nil or tostring(tid) ~= tostring(myTeam) then
            enemy = enemy + 1
          end
        end
      end
    end
    return total, enemy
  end

  function ADV.ScanVehicles(me, now)
    local meLoc = ESP.ActorLocation(me)
    if not meLoc then ADV.VehCache = {} return end
    local myTeam = ESP.GetTeamID(me)
    local pool = queryOrScan("veh",
      function(g) return g:QueryVehicles(meLoc, 150.0 * 100.0) end,
      function() return actorsOfClass(class("/Script/ShadowTrackerExtra.STExtraVehicleBase", "STExtraVehicleBase")) end)
    local out = {}
    for _, v in ipairs(pool) do
      local loc = ESP.ActorLocation(v)
      if loc then
        local dist = ESP.DistMeters(meLoc, loc)
        if dist <= 150.0 then
          local total, enemy = vehicleOccupants(v, myTeam)
          if enemy > 0 then
            local hp, hpmax, fuel, fuelmax = nil, nil, nil, nil
            local vc = nil
            pcall(function() vc = v.VehicleCommon end)
            if ESPValid(vc) then
              pcall(function()
                hp = tonumber(vc:GetVehicleHP())
                hpmax = tonumber(vc:GetVehicleHPMax())
                fuel = tonumber(vc.Fuel)
                fuelmax = tonumber(vc.FuelMax)
              end)
            end
            local hpTxt = "?"
            if hp and hpmax and hpmax > 0 then
              hpTxt = tostring(math.floor(hp / hpmax * 100.0 + 0.5)) .. "%"
            end
            local fuelTxt = ""
            if fuel and fuelmax and fuelmax > 0 then
              fuelTxt = string.format("  %d%%F", math.floor(fuel / fuelmax * 100.0 + 0.5))
            elseif fuel then
              fuelTxt = string.format("  %dL", math.floor(fuel + 0.5))
            end
            out[#out + 1] = {
              key = objectKey("vh_", v, loc),
              x = loc.X, y = loc.Y, z = loc.Z,
              dist = dist,
              text = string.format("VEH %dE · %s%s · %dm", enemy, hpTxt, fuelTxt, math.floor(dist + 0.5)),
              color = enemy >= 2 and COL.red or COL.orange,
            }
          end
        end
      end
    end
    table.sort(out, function(a, b) return (a.dist or 99999) < (b.dist or 99999) end)
    local trimmed = {}
    for i = 1, math.min(#out, 12) do trimmed[i] = out[i] end
    ADV.VehCache = trimmed
  end

  function ADV.DrawVehicles(pc, now)
    for _, it in ipairs(ADV.VehCache or {}) do
      local s = ESP.Project(pc, { X = it.x, Y = it.y, Z = it.z + 90.0 })
      if s then
        ESP.Extra.DrawLabel(it.key, s.X, s.Y, it.text, it.color)
        ESP.Extra.LastSeen[it.key] = now
      end
    end
  end

  -- --------------------------------------------------------
  -- Orchestrator
  -- --------------------------------------------------------
  function ADV.ClearLoot()
    ADV.LootCache = {}
    ADV.ListOK = {}
    ADV.Picked = {}
    hidePrefix("lt_")
  end

  function ADV.ClearAll()
    ADV.ClearLoot()
    hidePrefix("dm_")
    hidePrefix("gh_")
    hidePrefix("sq_")
    hidePrefix("vh_")
    ADV.VehCache = {}
    ADV.Ghosts = {}
    ADV.SquadCache = {}
    ADV.QueryOK = {}
    ADV.StaticOK = {}
    if ADV.Dmg then ADV.Dmg.hits = 0 ADV.Dmg.t = -999.0 ADV.Dmg.casterT = -999.0
      ADV.Dmg.casterName = nil ADV.Dmg.caster = nil ADV.Dmg.cx = nil end
    pcall(ADV.UninstallDamageHook)
  end

  function ADV.Update(pc, vw, vh, camLoc, now, me)
    -- ESP LOOT dan Advanced Overlay adalah dua gerbang terpisah.
    -- Loot tetap berjalan walau Esp9_Adv OFF. Advanced Overlay tetap milik
    -- menu ESP V2, jadi ikut mati saat EspLoai9 OFF walau parent-nya ON.
    local lootOn = on("Esp9_Loot")
    local advOn = cfg().EspLoai9 == true and masterOn()
    if not lootOn and not advOn then
      if not ADV._cleared then
        ADV._cleared = true
        pcall(ADV.ClearAll)
      end
      return
    end
    ADV._cleared = false
    local world = ESP.World()
    if world ~= ADV._World then
      -- Match/world baru: hook EventSystem dan subsystem lama tidak berlaku.
      -- Lepas wrapper lama dulu supaya subsystem singleton tidak ter-wrap
      -- berlapis tiap match.
      pcall(ADV.UninstallDamageHook)
      ADV._World = world
      ADV._hooked = false
      ADV._hookTried = false
      ADV._hookAt = -999.0
      ADV._dmgWrap, ADV._dmgOrig = nil, nil
      ADV._dmgSeen, ADV._dmgSeenT = nil, -999.0
      ADV.QueryOK = {}
      ADV.StaticOK = {}
      ADV.LootCache, ADV.VehCache, ADV.Ghosts = {}, {}, {}
      ADV.SquadCache = {}
      ADV.LootScan, ADV.VehScan, ADV.SquadScan = -999.0, -999.0, -999.0
      ADV._lootCleared, ADV._advCleared = false, false
      if ADV.Dmg then
        ADV.Dmg.t, ADV.Dmg.casterT = -999.0, -999.0
        ADV.Dmg.hits, ADV.Dmg.sum, ADV.Dmg.head = 0, 0, 0
        ADV.Dmg.caster, ADV.Dmg.casterKey, ADV.Dmg.cx = nil, nil, nil
        ADV.Dmg.casterName, ADV.Dmg.casterBot = nil, nil
      end
    end
    if not ESPValid(me) then return end

    if lootOn then
      ADV._lootCleared = false
      -- Pasang hook panel pickup sekali; instance panel bisa dibuat ulang
      -- saat match/UI reload, jadi dicek berkala.
      if (now - (ADV._pickHookAt or -999.0)) >= 2.0 then
        ADV._pickHookAt = now
        pcall(ADV.InstallPickupHook)
      end
      if (now - (ADV.LootScan or -999.0)) >= (ESP.LootInterval or 0.55) then
        ADV.LootScan = now
        pcall(ADV.ScanLoot, me, now)
      end
      pcall(ADV.DrawLoot, pc, now)
    elseif not ADV._lootCleared then
      ADV._lootCleared = true
      pcall(ADV.ClearLoot)
    end

    if advOn then
      ADV._advCleared = false
      if on("Esp9_DmgDir") then
        pcall(ADV.InstallDamageHook)
        pcall(ADV.DrawDamage, pc, me, vw, vh, now)
      else
        ADV.Dmg.t, ADV.Dmg.casterT = -999.0, -999.0
        ADV.Dmg.cx = nil
        ADV.Dmg.casterName = nil
        pcall(ADV.UninstallDamageHook)
        pcall(ADV.HideDamage)
      end

      if on("Esp9_Ghost") then
        pcall(ADV.UpdateGhosts, me, now)
        pcall(ADV.DrawGhosts, pc, me, now)
      else
        if next(ADV.Ghosts or {}) then ADV.Ghosts = {} end
        hidePrefix("gh_")
      end

      if on("Esp9_Squad") then
        if (now - (ADV.SquadScan or -999.0)) >= (ESP.SquadInterval or 0.8) then
          ADV.SquadScan = now
          pcall(ADV.ScanSquad, me, now)
        end
        pcall(ADV.DrawSquad, pc, me, vw, vh, now)
      else
        ADV.SquadCache = {}
        pcall(ADV.HideSquad)
      end

      if on("Esp9_VehIntel") then
        if (now - (ADV.VehScan or -999.0)) >= (ESP.VehInterval or 0.45) then
          ADV.VehScan = now
          pcall(ADV.ScanVehicles, me, now)
        end
        pcall(ADV.DrawVehicles, pc, now)
      else
        ADV.VehCache = {}
        hidePrefix("vh_")
      end
    elseif not ADV._advCleared then
      ADV._advCleared = true
      ADV.Dmg.t, ADV.Dmg.casterT = -999.0, -999.0
      ADV.Dmg.cx = nil
      ADV.Dmg.casterName = nil
      pcall(ADV.UninstallDamageHook)
      pcall(ADV.HideDamage)
      if next(ADV.Ghosts or {}) then ADV.Ghosts = {} end
      hidePrefix("gh_")
      ADV.SquadCache = {}
      pcall(ADV.HideSquad)
      ADV.VehCache = {}
      hidePrefix("vh_")
    end
  end

  -- ============================================================
  -- SUPPORT AUTOMATION — fast auto pickup + auto rescue teammate
  -- ------------------------------------------------------------
  -- Tidak menggambar widget dan tidak butuh canvas, jadi driver tetap
  -- hidup lewat ESP.Tick walau ESP 2 dan ESP LOOT sama-sama OFF.
  -- Pickup memakai jalur resmi panel tanpa animasi:
  -- PickUpListPanel_BP:PickUpWrapperActorWithoutAnim(me, SearchItemResult, count).
  -- Jumlah selalu dari panel:GetUseful2, bukan jumlah stack di ground.
  -- ============================================================
  local SUPPORT = {}
  ESP.Support = SUPPORT
  SUPPORT.Version = 1
  SUPPORT.Pickups = {}
  SUPPORT.Cooldown = {}
  SUPPORT.Attempts = {}
  SUPPORT.ScanAt = -999.0
  SUPPORT._pickAt = -999.0
  SUPPORT._rescueAt = -999.0
  SUPPORT._rescueSearchAt = -999.0
  SUPPORT._pruneAt = -999.0
  SUPPORT._panel = nil
  SUPPORT._panelAt = -999.0
  SUPPORT._panelSearchAt = -999.0
  SUPPORT._classAt = -999.0
  SUPPORT._classPool = {}
  SUPPORT._gearHold = {}
  SUPPORT._itemCfg = {}
  SUPPORT._armorLv = {}
  SUPPORT._durabilityType = nil

  local SUPPORT_PICK_BUDGET = 2
  local SUPPORT_PICK_WINDOW = 0.10
  local SUPPORT_PICK_CD = 0.60
  local SUPPORT_PICK_FAIL_CD = 8.0
  local SUPPORT_SCAN_INTERVAL = 0.40
  local SUPPORT_RESCUE_INTERVAL = 0.60
  -- Refresh search CanRescueTeammate tidak boleh tiap tick rescue: search
  -- butuh waktu mengunci kandidat. 1,5 dtk memberi kesempatan itu tanpa
  -- membuat rescue terasa lambat.
  local SUPPORT_RESCUE_SEARCH_INTERVAL = 1.50

  local function supportDistance(key, def)
    local v = tonumber(cfg()[key]) or def
    return math.max(1.0, math.min(15.0, v))
  end

  -- Tie-breaker lama: meds -> ammo -> attachment -> gear -> weapon ->
  -- throw/misc. Urutan utama sekarang mengikuti hasil search panel game
  -- (terdekat dulu); prioritas ini hanya memecah jarak yang sama.
  local function supportPriority(typ, id)
    typ = tonumber(typ)
    if typ == 6 then
      if id and id >= 602000 and id < 603000 then return 4 end
      return 0
    end
    if typ == 3 then return 1 end
    if typ == 2 then return 2 end
    if typ == 5 then return 3 end
    if typ == 1 then return 5 end
    return 6
  end

  -- ------------------------------------------------------------
  -- Helper SUPPORT (mandiri, tidak memakai local ADV) supaya blok ini
  -- tetap bisa diekstrak test_support.lua tanpa runtime game.
  -- ------------------------------------------------------------

  -- Iterasi aman untuk TArray/map slua: pairs() dulu, lalu Num()/Get()
  -- 0-based. Nilai yang tidak terbaca tidak membuat scan gagal total.
  local function supportArray(arr)
    local list = {}
    if arr == nil then return list end
    local used = false
    pcall(function()
      for _, v in pairs(arr) do
        if v ~= nil then
          used = true
          list[#list + 1] = v
        end
      end
    end)
    if used then return list end
    local n = 0
    pcall(function() n = tonumber(arr:Num()) end)
    if not n or n <= 0 then pcall(function() n = tonumber(arr:Length()) end) end
    if not n or n <= 0 then pcall(function() n = tonumber(#arr) end) end
    if not n or n <= 0 then return list end
    for i = 0, n - 1 do
      local v = nil
      pcall(function() v = arr:Get(i) end)
      if v == nil then pcall(function() v = arr[i] end) end
      if v ~= nil then list[#list + 1] = v end
    end
    return list
  end

  -- Panggil method tabel Game tanpa melempar error ke frame driver.
  -- Mengembalikan nil bila API tidak ada di build ini. Ariti tetap dibatasi
  -- supaya tidak butuh table.pack/table.unpack di host Lua yang lebih tua.
  local function supportQuery(method, a, b, c, d, e, f)
    local g = rawget(_G, "Game")
    if g == nil then return nil end
    local fn = nil
    pcall(function() fn = g[method] end)
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn, g, a, b, c, d, e, f)
    if ok then return res end
    return nil
  end

  -- Baca field struct slua. Akses langsung biasanya cukup, tapi game sendiri
  -- memakai slua.IndexReference untuk field struct bersarang; kalau akses
  -- langsung nil, coba IndexReference sebelum menyerah.
  local function supportIndex(obj, field)
    if obj == nil then return nil end
    local v = nil
    pcall(function() v = obj[field] end)
    if v == nil then
      pcall(function()
        local s = rawget(_G, "slua")
        if s and type(s.IndexReference) == "function" then
          v = s.IndexReference(obj, field)
        end
      end)
    end
    return v
  end

  -- Ambil ID/type/count/InstanceID dari MainItemData (atau entry mentah).
  -- Tiap field dibaca terpisah supaya satu field yang tidak ada di build
  -- lain tidak membatalkan pembacaan field lainnya.
  local function supportDefineID(mid)
    if mid == nil then return nil end
    local id, typ, cnt, iid = nil, nil, nil, nil
    local d = supportIndex(mid, "ID") or supportIndex(mid, "DefineID")
      or supportIndex(mid, "ItemDefineID")
    if d then
      id = tonumber(supportIndex(d, "TypeSpecificID"))
      typ = tonumber(supportIndex(d, "Type"))
      iid = tonumber(supportIndex(d, "InstanceID"))
    end
    cnt = tonumber(supportIndex(mid, "Count"))
    if iid == nil then iid = tonumber(supportIndex(mid, "InstanceID")) end
    if id == nil or id == 0 then id = tonumber(supportIndex(mid, "ItemID")) end
    if id == 0 then id = nil end
    return id, typ, cnt, iid
  end

  -- Satu elemen SortedItemsArray adalah BattleSearchItemSortingInfo:
  -- { bHighPriority = bool, SearchItemResult = { Wrapper, MainItemData } }.
  -- Beberapa build menaruh field langsung di elemen, jadi keduanya dicek.
  local function supportEntry(el, boxActor)
    if el == nil then return nil end
    local sr = supportIndex(el, "SearchItemResult") or el
    local wrapper = supportIndex(sr, "Wrapper") or supportIndex(el, "Wrapper")
    local mid = supportIndex(sr, "MainItemData") or supportIndex(el, "MainItemData")
    local hp = supportIndex(el, "bHighPriority")
    if hp == nil then hp = supportIndex(sr, "bHighPriority") end
    local id, typ, cnt, iid = supportDefineID(mid)
    if id == nil or id <= 0 then return nil end
    local exact = wrapper ~= nil
    if wrapper == nil and boxActor ~= nil then
      -- Deathbox: utamakan wrapper pickup milik box (GetPickupWrapperActor).
      -- Box sendiri bukan PickUpWrapperActor, jadi hanya dipakai sebagai
      -- sumber lokasi bila wrapper tidak bisa diambil.
      pcall(function()
        if boxActor.GetPickupWrapperActor then wrapper = boxActor:GetPickupWrapperActor() end
      end)
      if wrapper ~= nil then
        exact = true
      else
        wrapper = boxActor
      end
    end
    local define = supportIndex(mid, "ID")
    return {
      result = sr, define = define, wrapper = wrapper, exact = exact,
      id = id, typ = typ, count = cnt, iid = iid, hp = hp,
    }
  end

  -- ------------------------------------------------------------
  -- Guard senjata & armor. Tujuan: fast loot tidak boleh menukar
  -- senjata yang sudah menempati slot, dan tidak boleh mengganti
  -- helmet/vest yang masih lebih baik dari item loot.
  -- ------------------------------------------------------------

  -- Config item (ItemSubType, Durability) di-cache per TypeSpecificID.
  local function supportItemCfg(id)
    id = tonumber(id)
    if not id or id <= 0 then return nil end
    local cache = SUPPORT._itemCfg
    if cache == nil then cache = {} SUPPORT._itemCfg = cache end
    local hit = cache[id]
    if hit ~= nil then return hit or nil end
    local itemCfg = nil
    pcall(function()
      local dt = rawget(_G, "CDataTable")
      if dt and type(dt.GetTableData) == "function" then
        itemCfg = dt.GetTableData("Item", id)
      end
    end)
    cache[id] = itemCfg or false
    return itemCfg
  end

  -- Sisa durability dari list FBattleItemAdditionalData. Field list beda
  -- antara BattleItemData (AdditionalData) dan hasil search
  -- (AdditionalDataList); pemanggil yang memilih field.
  local function supportRemainDurability(adList)
    if adList == nil then return nil end
    local enumVal = SUPPORT._durabilityType
    if enumVal == nil then
      enumVal = false
      pcall(function()
        local E = import("EBattleItemAdditionalDataType")
        if E then enumVal = tonumber(E.RemainingDuability) or false end
      end)
      SUPPORT._durabilityType = enumVal
    end
    local fallback, floats = nil, 0
    for _, ad in ipairs(supportArray(adList)) do
      local dt = tonumber(supportIndex(ad, "EDataType"))
      local fv = tonumber(supportIndex(ad, "FloatData"))
      if enumVal and dt == enumVal then return fv end
      if fv ~= nil then
        floats = floats + 1
        if fallback == nil then fallback = fv end
      end
    end
    -- Build tanpa import enum: hanya pakai FloatData bila tunggal, agar
    -- data affix/tipe lain tidak salah dibaca sebagai durability.
    if enumVal == false and floats == 1 then return fallback end
    return nil
  end

  -- Level armor 1..3. Utamakan helper game; fallback mengikuti
  -- OBPlayerInfoUI:SetLvByID (digit terakhir ItemID).
  local function supportArmorLevel(tsid)
    tsid = tonumber(tsid)
    if not tsid or tsid <= 0 then return 0 end
    local cache = SUPPORT._armorLv
    if cache == nil then cache = {} SUPPORT._armorLv = cache end
    local hit = cache[tsid]
    if hit ~= nil then return hit end
    local level = nil
    pcall(function()
      local u = import("BackpackUtils")
      if u and type(u.GetEquipmentLevel) == "function" then
        level = tonumber(u.GetEquipmentLevel(tsid))
      end
    end)
    if level == nil or level <= 0 then
      local d = tsid % 10
      if d == 1 or d == 4 or d == 7 then level = 1
      elseif d == 2 or d == 5 or d == 8 then level = 2
      else level = 3 end
    end
    cache[tsid] = level
    return level
  end

  local function supportBackpack(me, panel)
    local comp = nil
    if panel ~= nil then
      pcall(function()
        if type(panel.GetBackpackComponent) == "function" then
          comp = panel:GetBackpackComponent()
        end
      end)
    end
    if comp == nil then
      pcall(function()
        if me and type(me.GetBackpackComponent) == "function" then
          comp = me:GetBackpackComponent()
        end
      end)
    end
    if comp == nil then
      pcall(function()
        local pc = nil
        if me and type(me.GetPlayerController) == "function" then
          pc = me:GetPlayerController()
        end
        if pc and type(pc.GetBackpackComponent) == "function" then
          comp = pc:GetBackpackComponent()
        end
      end)
    end
    if comp == nil then
      pcall(function()
        local lib = import("STExtraBlueprintFunctionLibrary")
        if lib and type(lib.GetBackpackComponentFromCharacter) == "function" then
          comp = lib.GetBackpackComponentFromCharacter(me)
        end
      end)
    end
    return comp
  end

  -- BattleItemData armor yang sedang dipakai (bEquipping), dicari per
  -- subtype 502 (helmet) / 503 (vest).
  local function supportEquippedArmor(comp, subType)
    if comp == nil then return nil end
    local found = nil
    pcall(function()
      local u = import("BackpackUtils")
      if u and type(u.GetAllItemsInBackpackWithOneSubType) == "function" then
        local arr = u.GetAllItemsInBackpackWithOneSubType(comp, subType, 0)
        for _, item in ipairs(supportArray(arr)) do
          if supportIndex(item, "bEquipping") then
            found = item
            break
          end
        end
      end
    end)
    if found == nil then
      pcall(function()
        local u = import("BackpackUtils")
        if u and type(u.GetEuqippedArmorInBackpack) == "function" then
          for _, item in ipairs(supportArray(u.GetEuqippedArmorInBackpack(comp))) do
            local d = supportIndex(item, "DefineID")
            local tsid = tonumber(supportIndex(d, "TypeSpecificID"))
            local cfg = supportItemCfg(tsid)
            if tonumber(supportIndex(cfg, "ItemSubType")) == subType then
              found = item
              break
            end
          end
        end
      end)
    end
    return found
  end

  local function supportWeaponManager(me, panel)
    local wm = nil
    pcall(function()
      if me and type(me.GetWeaponManager) == "function" then
        wm = me:GetWeaponManager()
      end
    end)
    if wm == nil and panel ~= nil then
      pcall(function()
        if type(panel.GetWeaponManager) == "function" then
          wm = panel:GetWeaponManager()
        end
      end)
    end
    return wm
  end

  -- Game menunda auto-pick saat memakai consumable (heal) dan saat state
  -- Pick tidak diizinkan; reload juga membuat pickup paksa berhenti di
  -- tengah aksi. Fast loot mengikuti gate yang sama supaya heal/reload
  -- tidak macet.
  local function supportActionBusy(me)
    local busy = false
    pcall(function()
      local E = import("EPawnState")
      if E == nil then return end
      if E.UseConsumables ~= nil and me and type(me.HasState) == "function" then
        if me:HasState(E.UseConsumables) then busy = true end
      end
      if E.Pick ~= nil and me and type(me.AllowState) == "function" then
        if me:AllowState(E.Pick, false) == false then busy = true end
      end
    end)
    if busy then return true end
    pcall(function()
      local wm = supportWeaponManager(me, nil)
      if wm == nil then return end
      local w = nil
      if type(wm.GetCurrentUsingWeapon) == "function" then
        w = wm:GetCurrentUsingWeapon()
      end
      if w == nil and type(wm.GetCurrentWeapon) == "function" then
        w = wm:GetCurrentWeapon()
      end
      if w == nil then return end
      local E = import("EFreshWeaponStateType")
      local reloadState = E and tonumber(E.FreshWeaponStateType_Reload) or nil
      local state = tonumber(supportIndex(w, "CurFreshWeaponState"))
      if reloadState ~= nil and state == reloadState then busy = true end
      if supportIndex(w, "bIsReloading") == true then busy = true end
      if supportIndex(w, "bReloading") == true then busy = true end
      if type(w.IsReloading) == "function" then
        local r = nil
        pcall(function() r = w:IsReloading() end)
        if r == true then busy = true end
      end
    end)
    return busy
  end

  local function supportSlotEnum(slotName)
    local slot = nil
    pcall(function()
      local E = import("ESurviveWeaponPropSlot")
      if E then slot = tonumber(E[slotName]) end
    end)
    if slot == nil then
      -- Nilai enum client: Main1=1, Main2=2, Sub=3, Melee=4.
      local fallback = {
        SWPS_MainShootWeapon1 = 1, SWPS_MainShootWeapon2 = 2,
        SWPS_SubShootWeapon = 3, SWPS_MeleeWeapon = 4,
      }
      slot = fallback[slotName]
    end
    return slot
  end

  local function supportSlotBusy(wm, slotName)
    if wm == nil then return nil end
    local slot = supportSlotEnum(slotName)
    if slot == nil then return nil end
    local w = nil
    local callOk = pcall(function() w = wm:GetInventoryWeaponByPropSlot(slot) end)
    if not callOk then return nil end
    return ESPValid(w)
  end

  -- Senjata hanya diambil bila slot tujuannya kosong. Tidak ada jalur
  -- yang menukar senjata terpasang; bila status slot tidak bisa dibaca,
  -- item senjata dilewati (lebih aman daripada swap).
  local function supportWeaponPickAllowed(it, me, panel)
    local cfg = supportItemCfg(it.id)
    local sub = tonumber(supportIndex(cfg, "ItemSubType"))
    local wm = supportWeaponManager(me, panel)
    if wm == nil then return false, "weapon" end
    if sub == 106 then
      local busy = supportSlotBusy(wm, "SWPS_SubShootWeapon")
      if busy == nil or busy == true then return false, "weapon" end
      return true, "weapon"
    end
    if sub == 107 or sub == 108 then
      local busy = supportSlotBusy(wm, "SWPS_MeleeWeapon")
      if busy == nil or busy == true then return false, "weapon" end
      return true, "weapon"
    end
    local a = supportSlotBusy(wm, "SWPS_MainShootWeapon1")
    local b = supportSlotBusy(wm, "SWPS_MainShootWeapon2")
    if a == nil or b == nil then return false, "weapon" end
    if a == true and b == true then return false, "weapon" end
    return true, "weapon"
  end

  -- TypeSpecificID ammo yang dipakai senjata di slot aktif (primary 1/2 +
  -- pistol). Ammo jenis lain tidak perlu diambil dan hanya memenuhi tas.
  local function supportWeaponAmmoSet(me, panel)
    local set = {}
    local wm = supportWeaponManager(me, panel)
    if wm == nil then return set end
    local slots = {
      "SWPS_MainShootWeapon1", "SWPS_MainShootWeapon2",
      "SWPS_SubShootWeapon",
    }
    local function addBullet(b)
      local id = tonumber(supportIndex(b, "TypeSpecificID"))
      if id and id > 0 then set[id] = true end
    end
    for _, name in ipairs(slots) do
      local slot = supportSlotEnum(name)
      if slot ~= nil then
        local w = nil
        local ok = pcall(function() w = wm:GetInventoryWeaponByPropSlot(slot) end)
        if ok and ESPValid(w) then
          pcall(function()
            local comp = nil
            if type(w.GetWeaponEntityComponent) == "function" then
              comp = w:GetWeaponEntityComponent()
            end
            if comp == nil then comp = w.WeaponEntityComp end
            addBullet(supportIndex(comp, "BulletType"))
          end)
          pcall(function()
            local glc = w.GrenadeLaunchComponent
            if glc then addBullet(glc.BulletType) end
          end)
        end
      end
    end
    return set
  end

  local function supportAmmoPickAllowed(it, me, panel)
    local set = supportWeaponAmmoSet(me, panel)
    return set[it.id] == true, nil
  end

  -- Attachment hanya diambil bila game menganggapnya berguna untuk senjata
  -- yang sedang dibawa (GetAssociationsUseful > 0). Tanpa API tersebut,
  -- attachment dilewati agar tas tidak penuh.
  local function supportAttachmentPickAllowed(it, me, panel)
    local comp = supportBackpack(me, panel)
    local wm = supportWeaponManager(me, panel)
    if comp == nil or wm == nil then return false, nil end
    local define = it.define
    if define == nil and it.result ~= nil then
      define = supportIndex(supportIndex(it.result, "MainItemData"), "ID")
    end
    if define == nil then return false, nil end
    local useful = nil
    pcall(function()
      local u = import("BackpackUtils")
      if u and type(u.GetAssociationsUseful) == "function" then
        useful = tonumber(u.GetAssociationsUseful(comp, wm, define))
      end
    end)
    if useful == nil then return false, nil end
    return useful > 0, nil
  end

  -- Slot pakaian dari ItemSubType (sama dengan ClothArmerType2Enum di
  -- BackPackPanelUI_ArmorSlot/BackpackClothingUI). 401 dan 406 sama-sama
  -- slot topi, 29 = sarung tangan.
  local function supportClothingSlot(sub)
    sub = tonumber(sub)
    if sub == nil then return nil end
    if sub == 29 then return "gloves" end
    if sub == 401 or sub == 406 then return "cap" end
    if sub == 402 then return "mask" end
    if sub == 403 then return "jacket" end
    if sub == 404 then return "trouser" end
    if sub == 405 then return "shoe" end
    if sub == 407 then return "glasses" end
    return nil
  end

  local function supportIsClothing(sub)
    return supportClothingSlot(sub) ~= nil
  end

  local SUPPORT_CLOTH_GROUP = {
    gloves = { 29 }, cap = { 401, 406 }, mask = { 402 },
    jacket = { 403 }, trouser = { 404 }, shoe = { 405 },
    glasses = { 407 },
  }

  -- Slot pakaian terisi bila sudah ada item dengan slot yang sama, baik
  -- sedang dipakai maupun disimpan. Ini mencegah deathbox mengambil
  -- topi/masker/jaket duplikat.
  local function supportClothingSlotFilled(comp, slot)
    if comp == nil or slot == nil then return false end
    local found = false
    pcall(function()
      local u = import("BackpackUtils")
      if u and type(u.GetClothingAndArmorInBackpack) == "function" then
        for _, item in ipairs(supportArray(u.GetClothingAndArmorInBackpack(comp))) do
          local d = supportIndex(item, "DefineID")
          local tsid = tonumber(supportIndex(d, "TypeSpecificID"))
          local icfg = supportItemCfg(tsid)
          local isub = tonumber(supportIndex(icfg, "ItemSubType"))
          if supportClothingSlot(isub) == slot then found = true break end
        end
      end
    end)
    if found then return true end
    -- Fallback build tanpa GetClothingAndArmorInBackpack.
    for _, sub in ipairs(SUPPORT_CLOTH_GROUP[slot] or {}) do
      pcall(function()
        local u = import("BackpackUtils")
        if u and type(u.GetAllItemsInBackpackWithOneSubType) == "function" then
          for _, _ in ipairs(supportArray(u.GetAllItemsInBackpackWithOneSubType(comp, sub, 0))) do
            found = true break
          end
        end
      end)
      if found then return true end
    end
    return found
  end

  -- Pakaian hanya diambil saat slotnya kosong. Type 4 (Clothing) dan type 5
  -- yang bersubtype pakaian sama-sama lewat sini; subtype tak dikenal
  -- dilewati agar tidak menambah pakaian duplikat.
  local function supportClothingPickAllowed(it, comp)
    if comp == nil then return false, nil end
    local cfg = supportItemCfg(it.id)
    local sub = tonumber(supportIndex(cfg, "ItemSubType"))
    local slot = supportClothingSlot(sub)
    if slot == nil then return false, nil end
    if supportClothingSlotFilled(comp, slot) then return false, nil end
    return true, nil
  end

  -- Backpack (subtype 501): hanya naik level. Backpack lv3 terpasang
  -- berarti tidak ada backpack lagi yang perlu diambil.
  local function supportBackpackPickAllowed(it, comp)
    if comp == nil then return false, nil end
    local newLevel = supportArmorLevel(it.id)
    local cur = supportEquippedArmor(comp, 501)
    if cur == nil then return true, nil end
    local curDef = supportIndex(cur, "DefineID")
    local curID = tonumber(supportIndex(curDef, "TypeSpecificID"))
    local curLevel = supportArmorLevel(curID)
    if curLevel >= 3 then return false, nil end
    return newLevel > curLevel, nil
  end

  local function supportRatio(remain, maxD)
    if maxD and maxD > 0 and remain ~= nil then
      local r = remain / maxD
      if r < 0 then return 0.0 end
      if r > 1 then return 1.0 end
      return r
    end
    return 1.0
  end

  -- Helmet/vest hanya boleh diambil bila benar-benar lebih baik:
  --  - tidak ada armor terpasang;
  --  - level lebih tinggi (durability baru masih terpakai);
  --  - level sama dan durability baru lebih tinggi dengan margin jelas;
  --  - armor lama praktis rusak dan armor baru masih layak.
  -- Armor level sama/lebih rendah yang masih penuh tidak pernah ditukar.
  local function supportArmorPickAllowed(it, sub, cfg, comp)
    -- Tanpa backpack component status armor terpasang tidak bisa dipastikan;
    -- jangan mengambil helmet/vest (bisa menukar armor penuh).
    if comp == nil then return false, nil end
    local maxD = tonumber(supportIndex(cfg, "Durability"))
    local mid = supportIndex(it.result, "MainItemData")
    local ad = supportIndex(mid, "AdditionalDataList")
    if ad == nil then ad = supportIndex(mid, "AdditionalData") end
    local newRatio = supportRatio(supportRemainDurability(ad), maxD)
    local newLevel = supportArmorLevel(it.id)
    local cur = supportEquippedArmor(comp, sub)
    if cur == nil then return newRatio > 0.02, nil end
    local curDef = supportIndex(cur, "DefineID")
    local curID = tonumber(supportIndex(curDef, "TypeSpecificID"))
    local curCfg = supportItemCfg(curID)
    local curMax = tonumber(supportIndex(curCfg, "Durability"))
    local curAD = supportIndex(cur, "AdditionalData")
    if curAD == nil then curAD = supportIndex(cur, "AdditionalDataList") end
    local curRatio = supportRatio(supportRemainDurability(curAD), curMax)
    local curLevel = supportArmorLevel(curID)
    if curRatio >= 0.95 and newLevel <= curLevel then return false, nil end
    if newLevel > curLevel then return newRatio > 0.02, nil end
    if newLevel == curLevel then
      if curRatio <= 0.10 then return newRatio >= 0.50, nil end
      return newRatio >= curRatio + 0.20, nil
    end
    -- Level baru lebih rendah: hanya layak bila armor lama praktis rusak.
    return curRatio <= 0.10 and newRatio >= 0.50, nil
  end

  local function supportItemGate(it, me, panel, now)
    local typ = it.typ
    if typ == nil then
      -- Sebagian wrapper hanya mengekspos ID; ambil tipe dari config.
      typ = tonumber(supportIndex(supportItemCfg(it.id), "ItemType"))
    end
    if typ == 1 then
      if (SUPPORT._gearHold.weapon or 0) > now then return false, "weapon" end
      return supportWeaponPickAllowed(it, me, panel)
    end
    -- Attachment: hanya yang berguna untuk senjata yang sedang dibawa.
    -- Tanpa filter ini attachment acak memenuhi tas, terutama di deathbox.
    if typ == 2 then
      return supportAttachmentPickAllowed(it, me, panel), nil
    end
    -- Ammo: hanya jenis yang dipakai senjata aktif. Ammo kaliber lain
    -- tidak ada gunanya dan hanya menghabiskan slot tas.
    if typ == 3 then
      return supportAmmoPickAllowed(it, me, panel), nil
    end
    -- Pakaian punya ItemType 4 (Clothing). Hanya boleh diambil bila slot
    -- pakaian yang sama belum terisi; ini yang mencegah deathbox mengambil
    -- topi/masker/jaket/celana/sepatu/kacamata/sarung tangan duplikat.
    if typ == 4 then
      local comp = supportBackpack(me, panel)
      return supportClothingPickAllowed(it, comp)
    end
    if typ == 5 then
      local cfg = supportItemCfg(it.id)
      local sub = tonumber(supportIndex(cfg, "ItemSubType"))
      if supportIsClothing(sub) then
        local comp = supportBackpack(me, panel)
        return supportClothingPickAllowed(it, comp)
      end
      if sub == 501 then
        local holdKey = "backpack"
        if (SUPPORT._gearHold[holdKey] or 0) > now then return false, holdKey end
        local comp = supportBackpack(me, panel)
        return supportBackpackPickAllowed(it, comp), holdKey
      end
      if sub ~= 502 and sub ~= 503 then return true, nil end
      local holdKey = "armor" .. tostring(sub)
      if (SUPPORT._gearHold[holdKey] or 0) > now then return false, holdKey end
      local comp = supportBackpack(me, panel)
      local allowed = supportArmorPickAllowed(it, sub, cfg, comp)
      return allowed, holdKey
    end
    return true, nil
  end

  -- Instance PickUpListPanel adalah sumber filter pickup setting utama.
  -- Cache 2 detik supaya UIManager.GetUI tidak dipanggil tiap window.
  local function supportPanel(now)
    if (now - (SUPPORT._panelAt or -999.0)) < 2.0 then return SUPPORT._panel end
    SUPPORT._panelAt = now
    local panel = nil
    pcall(function()
      if type(findPickupPanel) == "function" then panel = findPickupPanel() end
    end)
    SUPPORT._panel = panel
    return panel
  end

  -- Field search ada di panel dan/atau UIRoot; cek dua-duanya.
  local function supportPanelInfo(panel, field)
    local info = nil
    if panel == nil then return nil end
    pcall(function() info = panel[field] end)
    if info == nil then
      pcall(function()
        local root = panel.UIRoot
        if root then info = root[field] end
      end)
    end
    return info
  end

  -- Segarkan hasil search (throttle 0,5 dtk). Kalau UIRoot tidak punya
  -- method ini, data lama tetap dipakai.
  local function supportRefresh(panel, me, now)
    if panel == nil then return end
    if (now - (SUPPORT._panelSearchAt or -999.0)) < 0.5 then return end
    SUPPORT._panelSearchAt = now
    pcall(function()
      local root = panel.UIRoot
      if root and type(root.UpdatePickupsAndTombBoxesData) == "function" then
        root:UpdatePickupsAndTombBoxesData(me)
      end
    end)
  end

  -- Kumpulkan kandidat dari hasil search panel. SortedItemsArray sudah
  -- difilter pickup setting utama (limit jenis, jumlah, kapasitas), dan
  -- bHighPriority menandai item yang boleh di-auto-pick — persis seperti
  -- AutoPickGroundItem / CheckIsRevivalCardCanPick di PickUpListPanel.
  -- Mengembalikan jumlah item ground mentah dan total item mentah.
  local function supportCollectPanel(panel, meLoc, radius, out, seenKey)
    if panel == nil then return 0, 0 end
    local raw, groundRaw = 0, 0
    local items = {}
    local function addArray(arr, boxActor, isGround)
      for _, el in ipairs(supportArray(arr)) do
        local item = supportEntry(el, boxActor)
        if item then
          raw = raw + 1
          if isGround then groundRaw = groundRaw + 1 end
          items[#items + 1] = { item = item, box = not isGround }
        end
      end
    end
    local ground = supportPanelInfo(panel, "SearchedPickupItemInfo")
    if ground then
      local arr = nil
      pcall(function() arr = ground.SortedItemsArray end)
      if arr then addArray(arr, nil, true) end
    end
    local boxes = supportPanelInfo(panel, "AllSearchedTombBoxesInfo")
    if boxes then
      local list = nil
      pcall(function() list = boxes.AllBoxes end)
      for _, box in ipairs(supportArray(list)) do
        local boxActor, arr = nil, nil
        pcall(function() boxActor = box.Box end)
        pcall(function() arr = box.SortedItemsArray end)
        if arr then addArray(arr, boxActor, false) end
      end
    end
    -- Ground mengikuti auto-pick game: bila flag boolean ada, hanya
    -- bHighPriority == true. Deathbox tidak memakai flag ini di game
    -- (AutoPickTobmBoxItem tidak memeriksanya), jadi entri box tetap masuk.
    local strict = false
    for _, rec in ipairs(items) do
      if type(rec.item.hp) == "boolean" then strict = true break end
    end
    for _, rec in ipairs(items) do
      local item = rec.item
      -- Ground mengikuti auto-pick panel: wajib bHighPriority. Deathbox
      -- tidak memakai flag itu di game (AutoPickTobmBoxItem tidak
      -- memeriksanya), jadi entri box tetap dikumpulkan.
      if rec.box == true or not strict or item.hp == true then
        local loc = nil
        pcall(function() loc = ESP.ActorLocation(item.wrapper) end)
        -- Kandidat tanpa wrapper pickup yang pasti tidak bisa dipakai
        -- PickUpWrapperActorWithoutAnim; simpan exact supaya FastLoot
        -- melewatinya dan tidak mengirim struct yang salah.
        if loc then
          local dist = ESP.DistMeters(meLoc, loc)
          if dist <= radius then
            local key = tostring(item.wrapper) .. "|" .. tostring(item.iid or 0)
              .. "|" .. tostring(item.id)
            if not seenKey[key] then
              seenKey[key] = true
              out[#out + 1] = {
                wrapper = item.wrapper, iid = item.iid or 0,
                count = item.count or 1, id = item.id, typ = item.typ,
                dist = dist, prio = supportPriority(item.typ, item.id),
                key = key, result = item.result, define = item.define,
                exact = item.exact, hp = item.hp, panel = true,
                box = rec.box == true,
              }
            end
          end
        end
      end
    end
    return groundRaw, raw
  end

  -- Pool wrapper world: query useful dan query biasa digabung karena query
  -- useful bisa hanya berisi loot ground, sementara wrapper deathbox yang
  -- belum dibuka hanya muncul di query biasa. Duplikat dibuang. Class scan
  -- menjadi fallback terakhir dan di-cache ~1 detik (GetActorsByClass
  -- menyusuri seluruh world).
  local function supportWorldPool(meLoc, radius, me, now)
    local dist = radius * 100.0
    local pool, seen = {}, {}
    local function merge(list)
      for _, a in ipairs(supportArray(list)) do
        if a ~= nil and not seen[a] then
          seen[a] = true
          pool[#pool + 1] = a
        end
      end
    end
    merge(supportQuery("QueryUsefulPickUpWrappers", meLoc, dist, nil, false, me, 40))
    merge(supportQuery("QueryPickUpWrappers", meLoc, dist, nil, false, 40))
    if #pool > 0 then return pool end
    if (now - (SUPPORT._classAt or -999.0)) >= 1.0 then
      SUPPORT._classAt = now
      local scanned = nil
      pcall(function()
        local cls = class("/Script/ShadowTrackerExtra.PickUpWrapperActor", "PickUpWrapperActor")
        if cls then scanned = actorsOfClass(cls) end
      end)
      SUPPORT._classPool = scanned or {}
    end
    return SUPPORT._classPool or {}
  end

  -- Wrapper isi deathbox punya BoxType; wrapper loot ground tidak. Game
  -- sendiri memakai pembeda ini di AIActionExecutionComponent:ActionPick
  -- (BoxType == nil -> PickUpActor, selain itu -> PickUpWrapperActor per
  -- entri). Fallback nama class untuk build yang tidak mengekspos BoxType.
  local function supportIsBoxActor(a)
    if a == nil then return false end
    local box = false
    pcall(function() box = a.BoxType ~= nil end)
    if box then return true end
    pcall(function() box = a.bIsTombBox == true or a.bIsDeadBox == true end)
    if box then return true end
    pcall(function()
      local cls = a.GetClass and a:GetClass() or nil
      local name = cls and cls.GetName and cls:GetName() or nil
      if type(name) == "string" then
        box = name:find("DeadBox") ~= nil or name:find("TombBox") ~= nil
          or name:find("PickUpWrapperList") ~= nil
      end
    end)
    return box
  end

  -- skipGround=true: panel sudah punya data ground, jadi scan world hanya
  -- dipakai untuk wrapper deathbox yang tidak muncul di panel sebelum box
  -- dibuka. Ground world tetap tidak diambil FastLoot (tidak ada GetUseful2).
  local function supportCollectWorld(meLoc, radius, out, seenKey, me, now, skipGround)
    local pool = supportWorldPool(meLoc, radius, me, now)
    for _, a in ipairs(pool) do
      local loc = ESP.ActorLocation(a)
      if loc then
        local dist = ESP.DistMeters(meLoc, loc)
        if dist <= radius then
          local removed = false
          pcall(function()
            removed = a.bItemRemoved == true or a.bPickedUp == true
              or a.bIsPickedUp == true or a.bTaken == true
          end)
          if not removed then
            local isBox = supportIsBoxActor(a)
            if isBox or not skipGround then
              local entries = listItems(a) or {}
              for _, e in ipairs(entries) do
                local iid = e.iid or 0
                local key = tostring(a) .. "|" .. tostring(iid) .. "|" .. tostring(e.id)
                if not seenKey[key] then
                  seenKey[key] = true
                  out[#out + 1] = {
                    wrapper = a, iid = iid, count = e.count or 1,
                    id = e.id, typ = e.typ, dist = dist,
                    prio = supportPriority(e.typ, e.id), key = key,
                    define = e.define, box = isBox,
                  }
                end
              end
            end
          end
        end
      end
    end
  end

  function SUPPORT.Reset()
    SUPPORT.Pickups = {}
    SUPPORT.Cooldown = {}
    SUPPORT.Attempts = {}
    SUPPORT.ScanAt = -999.0
    SUPPORT._pickAt = -999.0
    SUPPORT._rescueAt = -999.0
    SUPPORT._rescueSearchAt = -999.0
    SUPPORT._pruneAt = -999.0
    SUPPORT._panel = nil
    SUPPORT._panelAt = -999.0
    SUPPORT._panelSearchAt = -999.0
    SUPPORT._classAt = -999.0
    SUPPORT._classPool = {}
    SUPPORT._gearHold = {}
  end

  function SUPPORT.Prune(now)
    for k, t in pairs(SUPPORT.Cooldown) do
      if (tonumber(t) or 0) <= now then SUPPORT.Cooldown[k] = nil end
    end
    for k, a in pairs(SUPPORT.Attempts) do
      if not a or (now - (tonumber(a.t) or 0)) > 20.0 then SUPPORT.Attempts[k] = nil end
    end
  end

  function SUPPORT.CanOperate(me)
    if not ESPValid(me) then return false end
    if ESP.IsKnocked(me) then return false end
    local alive = true
    pcall(function() if me.IsAlive then alive = me:IsAlive() ~= false end end)
    if not alive then return false end
    local flying = false
    pcall(function() if me.IsInPlane then flying = me:IsInPlane() == true end end)
    if not flying then
      pcall(function() if me.IsInParachute then flying = me:IsInParachute() == true end end)
    end
    if flying then return false end
    local EPawnState = nil
    pcall(function() EPawnState = import("EPawnState") end)
    if EPawnState and EPawnState.Pick and me.AllowState then
      local allowed = nil
      pcall(function() allowed = me:AllowState(EPawnState.Pick, false) end)
      if allowed == false then return false end
    end
    return true
  end

  function SUPPORT.Scan(me, now)
    local radius = supportDistance("Sup_FastLootDist", 4.0)
    local meLoc = ESP.ActorLocation(me)
    if not meLoc then SUPPORT.Pickups = {} return end
    now = tonumber(now) or ESP.Now()
    local out, seenKey = {}, {}
    local panel = supportPanel(now)
    supportRefresh(panel, me, now)
    local groundRaw = supportCollectPanel(panel, meLoc, radius, out, seenKey)
    -- Scan world selalu jalan untuk wrapper deathbox: isi box yang belum
    -- dibuka tidak ada di panel, dan game tidak menyediakan GetUseful2 untuk
    -- entri world. Ground world hanya dikumpulkan saat panel belum punya
    -- data ground (diagnostik); FastLoot tetap menolak ground world.
    supportCollectWorld(meLoc, radius, out, seenKey, me, now, groundRaw > 0)
    -- Entri panel di depan, lalu deathbox world, lalu ground world. Dengan
    -- begitu kandidat box tidak terdorong keluar batas 40 oleh loot ground.
    table.sort(out, function(x, y)
      local function rank(it)
        if it.panel == true then return 0 end
        if it.box == true then return 1 end
        return 2
      end
      local xp, yp = rank(x), rank(y)
      if xp ~= yp then return xp < yp end
      if x.dist ~= y.dist then return x.dist < y.dist end
      if x.prio ~= y.prio then return x.prio < y.prio end
      return tostring(x.key) < tostring(y.key)
    end)
    if #out > 40 then
      local trimmed = {}
      for i = 1, 40 do trimmed[i] = out[i] end
      out = trimmed
    end
    SUPPORT.Pickups = out
  end

  function SUPPORT.NoteAttempt(key, now)
    SUPPORT.Cooldown[key] = now + SUPPORT_PICK_CD
    local a = SUPPORT.Attempts[key]
    if not a or (now - (tonumber(a.t) or now)) > 4.0 then
      a = { n = 0, t = now }
    end
    a.n = (a.n or 0) + 1
    a.t = now
    if a.n >= 4 then
      -- Server menolak (kapasitas/limit/jarak) atau data wrapper basi:
      -- berhenti mencoba entri ini sebentar agar RPC tidak spam.
      SUPPORT.Cooldown[key] = now + SUPPORT_PICK_FAIL_CD
      a.n = 0
    end
    SUPPORT.Attempts[key] = a
  end

  function SUPPORT.FastLoot(me, now)
    if cfg().Sup_FastLoot ~= true then return end
    if not SUPPORT.CanOperate(me) then return end
    now = tonumber(now) or ESP.Now()
    if (now - (SUPPORT.ScanAt or -999.0)) >= SUPPORT_SCAN_INTERVAL then
      SUPPORT.ScanAt = now
      pcall(SUPPORT.Scan, me, now)
    end
    if (now - (SUPPORT._pickAt or -999.0)) < SUPPORT_PICK_WINDOW then return end
    SUPPORT._pickAt = now
    if supportActionBusy(me) then return end
    local pm = nil
    pcall(function() if me.GetPickupManager then pm = me:GetPickupManager() end end)
    if not ESPValid(pm) then pm = nil end
    local panel = supportPanel(now)
    local panelFn = false
    if panel ~= nil then
      local fn = nil
      pcall(function() fn = panel.PickUpWrapperActorWithoutAnim end)
      panelFn = type(fn) == "function"
    end
    -- Ground loot hanya lewat panel + GetUseful2. Deathbox boleh lewat
    -- PickupManager:PickUpTarget karena isinya tidak muncul di panel
    -- sebelum box dibuka.
    if not pm and not panelFn then return end
    local usefulFn = nil
    if panel ~= nil then pcall(function() usefulFn = panel.GetUseful2 end) end
    if type(usefulFn) ~= "function" then usefulFn = nil end
    local radius = supportDistance("Sup_FastLootDist", 4.0)
    local meLoc = ESP.ActorLocation(me)
    if not meLoc then return end
    local budget = SUPPORT_PICK_BUDGET
    for _, it in ipairs(SUPPORT.Pickups) do
      if budget <= 0 then break end
      local isBox = it.box == true
      -- Ground: wajib hasil search panel + bHighPriority + GetUseful2.
      -- Deathbox: boleh dari world scan tanpa membuka box; GetUseful2 tetap
      -- dipakai bila struct search tersedia.
      local eligible
      if isBox then
        eligible = pm ~= nil or (panelFn and it.result ~= nil and it.exact == true)
      else
        eligible = it.panel == true and it.hp == true and it.exact == true
          and it.result ~= nil and usefulFn ~= nil
      end
      if eligible and (SUPPORT.Cooldown[it.key] or 0) <= now then
        local loc = ESP.ActorLocation(it.wrapper)
        if loc and ESPValid(it.wrapper) then
          local d = ESP.DistMeters(meLoc, loc)
          if d <= radius then
            local skip = false
            local count = math.max(1, math.floor(tonumber(it.count) or 1))
            -- GetUseful2 menghormati pickup setting, limit jenis, kapasitas
            -- tas, dan jumlah yang sudah dibawa. Untuk box tanpa struct
            -- search, pakai jumlah stack seperti jalur lama.
            if usefulFn ~= nil and it.result ~= nil then
              local useful = nil
              local usefulOK = pcall(function()
                useful = usefulFn(panel, it.define, it.result)
              end)
              useful = tonumber(useful)
              if usefulOK and useful ~= nil then
                if useful <= 0 then
                  skip = true
                else
                  count = math.max(1, math.floor(useful))
                  local stack = math.floor(tonumber(it.count) or 0)
                  if stack > 0 and count > stack then count = stack end
                end
              elseif not isBox then
                -- Ground tidak boleh menebak saat GetUseful2 gagal.
                skip = true
              end
            end
            -- Guard tambahan di luar GetUseful2: jangan menukar senjata
            -- yang sudah mengisi slot, dan jangan mengganti helmet/vest
            -- yang masih lebih baik.
            local holdKey = nil
            if not skip then
              local allowed, gearKey = supportItemGate(it, me, panel, now)
              if not allowed then skip = true end
              holdKey = gearKey
            end
            local ok = false
            if not skip then
              -- Jalur game tanpa animasi memakai struct hasil search asli,
              -- termasuk InstanceID dan MainItemData yang benar.
              if panelFn and it.result ~= nil and it.exact == true then
                ok = pcall(function()
                  panel:PickUpWrapperActorWithoutAnim(me, it.result, count)
                end)
              end
              -- Deathbox world: langsung ke PickupManager tanpa membuka box.
              if not ok and isBox and pm ~= nil then
                ok = pcall(function()
                  pm:PickUpTarget(it.wrapper, it.iid, count, 0)
                end)
              end
            end
            if ok then
              budget = budget - 1
              SUPPORT.NoteAttempt(it.key, now)
              if holdKey then
                -- Tahan pickup sejenis sebentar: state server belum tentu
                -- sudah sinkron, jadi jangan sampai dua armor/senjata
                -- diambil beruntun dan saling menukar.
                SUPPORT._gearHold[holdKey] = math.max(
                  SUPPORT._gearHold[holdKey] or 0, now + 1.2)
              end
            else
              -- Cek ulang setelah 1 dtk: bisa jadi baru berguna setelah
              -- isi backpack berubah, tanpa men-spam GetUseful2.
              SUPPORT.Cooldown[it.key] = now + 1.0
            end
          end
        end
      end
    end
    if budget < SUPPORT_PICK_BUDGET then
      SUPPORT.ScanAt = now - (SUPPORT_SCAN_INTERVAL - 0.08)
    end
  end

  -- Minta komponen search memeriksa ulang kandidat rescue. Dipanggil
  -- maksimal tiap SUPPORT_RESCUE_SEARCH_INTERVAL agar hasil search sempat
  -- settle; reset tiap 0,6 dtk membuat rescue tidak pernah terkonfirmasi.
  local function supportRefreshRescueSearch(me, now)
    if (now - (SUPPORT._rescueSearchAt or -999.0)) < SUPPORT_RESCUE_SEARCH_INTERVAL then
      return false
    end
    SUPPORT._rescueSearchAt = now
    pcall(function()
      local ECharacterSearchEnum = import("ECharacterSearchEnum")
      local EExecutionCondition = import("EExecutionCondition")
      local sc = me.SearchOtherComponent
      if sc and ECharacterSearchEnum and EExecutionCondition then
        if sc.ResetSearchResult then
          sc:ResetSearchResult(ECharacterSearchEnum.CanRescueTeammate, EExecutionCondition.Client)
        end
        if sc.ResetTickCheckTime then
          sc:ResetTickCheckTime(ECharacterSearchEnum.CanRescueTeammate, 0.0, EExecutionCondition.Client, false)
        end
      end
    end)
    return true
  end

  function SUPPORT.FindDownedTeammate(me)
    local radius = supportDistance("Sup_AutoRescueDist", 3.0)
    local meLoc = ESP.ActorLocation(me)
    local myTeam = ESP.GetTeamID(me)
    if not meLoc or myTeam == nil then return nil end
    local pawns = nil
    -- Game:GetAllPlayerPawns() memakai colon. Fallback ke
    -- ESP.GetAllCharacters() yang sudah memakai colon dan mengembalikan
    -- map PlayerKey -> pawn, supaya auto rescue tidak mati saat daftar
    -- pawn utama kosong/gagal.
    pcall(function()
      if Game and type(Game.GetAllPlayerPawns) == "function" then
        pawns = Game:GetAllPlayerPawns()
      end
    end)
    if type(pawns) ~= "table" or next(pawns) == nil then
      pcall(function() pawns = ESP.GetAllCharacters() end)
    end
    if type(pawns) ~= "table" then return nil end
    local best, bestD = nil, radius
    for _, ch in pairs(pawns) do
      if ESPValid(ch) and ch ~= me then
        local team = ESP.GetTeamID(ch)
        if team ~= nil and tostring(team) == tostring(myTeam) and ESP.IsKnocked(ch) then
          local loc = ESP.ActorLocation(ch)
          if loc then
            local d = ESP.DistMeters(meLoc, loc)
            if d <= bestD then best, bestD = ch, d end
          end
        end
      end
    end
    return best
  end

  function SUPPORT.AutoRescue(me, now)
    if cfg().Sup_AutoRescue ~= true then return end
    if not ESPValid(me) or ESP.IsKnocked(me) then return end
    if (now - (SUPPORT._rescueAt or -999.0)) < SUPPORT_RESCUE_INTERVAL then return end
    SUPPORT._rescueAt = now
    -- RescueWho hanyalah kandidat dari event search, bukan bukti rescue
    -- sedang berjalan. Satu-satunya penanda aktif adalah IsRescueingOther.
    local rescuing = false
    pcall(function() rescuing = me.IsRescueingOther == true end)
    if rescuing then return end
    local target = SUPPORT.FindDownedTeammate(me)
    if not target then
      -- Kandidat bisa saja sudah dipegang komponen walau scan pawn gagal.
      local rc = nil
      pcall(function() rc = me.RescueOtherComponent end)
      if ESPValid(rc) then
        local who = nil
        pcall(function() who = rc.RescueWho end)
        if ESPValid(who) and who ~= me and ESP.IsKnocked(who) then
          local myTeam, team = ESP.GetTeamID(me), ESP.GetTeamID(who)
          local meLoc, loc = ESP.ActorLocation(me), ESP.ActorLocation(who)
          if myTeam ~= nil and team ~= nil
            and tostring(myTeam) == tostring(team) and meLoc and loc
            and ESP.DistMeters(meLoc, loc) <= supportDistance("Sup_AutoRescueDist", 3.0) then
            target = who
          end
        end
      end
    end
    if target then
      -- Jalur tombol rescue game: panggil langsung supaya tidak perlu tap.
      local confirmed = false
      pcall(function() confirmed = me:PlayerConfirmToRescue() == true end)
      if not confirmed then
        supportRefreshRescueSearch(me, now)
      end
    else
      supportRefreshRescueSearch(me, now)
    end
  end

  function SUPPORT.Update(now)
    now = tonumber(now) or ESP.Now()
    local c = _G.RapzhangConfig
    if c == nil then return end
    local lootOn = c.Sup_FastLoot == true
    local rescueOn = c.Sup_AutoRescue == true
    if not lootOn and not rescueOn then
      if SUPPORT._active then
        SUPPORT._active = false
        pcall(SUPPORT.Reset)
      end
      return
    end
    SUPPORT._active = true
    local me = ESP.GetLocalCharacter()
    if not ESPValid(me) then return end
    if (now - (SUPPORT._pruneAt or -999.0)) >= 5.0 then
      SUPPORT._pruneAt = now
      pcall(SUPPORT.Prune, now)
    end
    if lootOn then pcall(SUPPORT.FastLoot, me, now) end
    if rescueOn then pcall(SUPPORT.AutoRescue, me, now) end
  end
end

--// SRC HUB
-- ESP LOOT adalah menu mandiri: tetap render walau ESP V2 (EspLoai9) OFF.
-- Jalur ini hanya memanggil ADV.Update saat gate utama ESP mati; saat gate
-- hidup, ADV.Update sudah dipanggil sekali dari ESP.Update.
function ESP.UpdateLootOnly()
  local cfg = _G.RapzhangConfig or {}
  if cfg.Esp9_Loot ~= true then return end
  local pc = ESP.GetController()
  if not pc then return end
  if not ESP.GetCanvas() then return end
  local now = ESP.Now()
  if (now - (ESP.LastTransform or -999.0)) >= (ESP.TransformInterval or 0.50) then
    pcall(ESP.UpdateCanvasTransform, pc)
    ESP.LastTransform = now
  end
  local vw, vh = ESP.Viewport(pc)
  local me = ESP.GetLocalCharacter()
  if ESP.Adv and ESP.Adv.Update then
    pcall(ESP.Adv.Update, pc, vw, vh, ESP.GetCamLoc(pc), now, me)
  end
  if ESP.Extra and ESP.Extra.Sweep then
    pcall(ESP.Extra.Sweep, now, ESP.SweepTTL or 3.0)
  end
end

function ESP.Update()
  ESP.SyncMenuConfig()
  local mainEnabled = _G.RapzhangConfig and _G.RapzhangConfig.EspLoai9 == true
  if not mainEnabled or not ESP_Enabled then
    if not ESP._MainOffCleaned then
      ESP.ResetWidgets()
      ESP._MainOffCleaned = true
    end
    pcall(ESP.UpdateLootOnly)
    return
  end
  ESP._MainOffCleaned = false
  local world = ESP.World()
  if world ~= ESP.LastWorld then
    ESP.ResetWidgets()
    ESP.LastWorld = world
    ESP.LastScan = -999.0
    ESP.LastTransform = -999.0
  end
  local canvas = ESP.GetCanvas()
  if not canvas then return end
  local now = ESP.Now()
  local pc = ESP.GetController()
  if (now - ESP.LastScan) >= (ESP.ScanInterval or 0.35) then
    local r, b
    pc, r, b = ESP.Scan()
    ESP.LastScan = now
    ESP.RealCount, ESP.BotCount = r or 0, b or 0
  end
  pc = pc or ESP.GetController()
  if not pc then return end
  if (now - (ESP.LastTransform or -999.0)) >= (ESP.TransformInterval or 0.50) then
    ESP.UpdateCanvasTransform(pc)
    ESP.LastTransform = now
  end
  local vw, vh = ESP.Viewport(pc)
  -- viewport hysteresis: 2px se kam farq ignore (flicker fix)
  local hyst = CFG.SizeHyst or 2.0
  if math.abs(vw - (ESP.ViewW or 0)) > hyst or math.abs(vh - (ESP.ViewH or 0)) > hyst then
    ESP.ViewW, ESP.ViewH = vw, vh
  else
    vw, vh = ESP.ViewW, ESP.ViewH
  end
  local origin = ESP.UpdateCounter(ESP.RealCount or 0, ESP.BotCount or 0, pc, vw)
  if not origin then return end
  local menu = ESP.Menu or {}
  -- Visibility trace memakai 3 line trace per target. Kalau baris Open/Close
  -- dan badge self-rescue sama-sama OFF, hasilnya tidak pernah tampil, jadi
  -- lewati trace dan GetCamLoc sepenuhnya.
  local needVis = menu.ShowVisibility == true or menu.ShowSelfRescue == true
  local camLoc = nil
  if needVis then camLoc = ESP.GetCamLoc(pc) end

  local meChar = ESP.GetLocalCharacter()
  local meHead = nil
  if menu.ShowAimLine and ESPValid(meChar) then
    meHead = ESP.GetHeadFeet(meChar)
  end

  local active = {}
  for _, item in ipairs(ESP.EnemyCache) do
    local c = item.Character
    local key = item.Key
    if ESPValid(c) and ESP.IsAlive(c) then
      local head, feet = ESP.GetHeadFeet(c)
      if head and feet then
        local headS, headPix = ESP.Project(pc, head)
        local feetS, feetPix = ESP.Project(pc, feet)
        if headS and feetS and headPix and feetPix then
          local m = CFG.ScreenMargin or 220
          local on = headPix.X > -m and headPix.X < vw + m
            and headPix.Y > -m and headPix.Y < vh + m
            and feetPix.X > -m and feetPix.X < vw + m
            and feetPix.Y > -m and feetPix.Y < vh + m
          if on then
            local H = feetS.Y - headS.Y
            -- sanity: ulti box / bahut badi box = garbage projection, hide
            if H >= (CFG.BoxMinHeight or 14) and H <= vh * 1.5 then
              active[key] = true
              if (ESP.Menu or {}).ShowAimLine then
                ESP.DrawAimLine(key, pc, c, head, headS, meHead)
              else
                ESP.Hide(ESP.AimLines[key])
              end
              local W = H * (CFG.BoxWidthFactor or 0.62)
              W = math.max(CFG.BoxMinWidth or 22, math.min(CFG.BoxMaxWidth or 320, W))
              local padT = H * (CFG.HeadExtra or 0)
              local padB = H * (CFG.FootExtra or 0)
              local cx = (headS.X + feetS.X) * 0.5
              local L = cx - W * 0.5
              local R = cx + W * 0.5
              local T = headS.Y - padT
              local B = feetS.Y + padB

              -- 1) team-colored corners (8 segments)
              local arm = math.min(R - L, B - T) * (CFG.CornerLen or 0.28)
              local boxColor = ESP.TeamColor(c)
              arm = math.max(CFG.CornerMin or 6, math.min(CFG.CornerMax or 28, arm))
              local th = CFG.CornerThickness or 2.2
              if (ESP.Menu or {}).ShowTeam then
                ESP.DrawLine(ESP.EnsureCorner(key, 1, boxColor), L, T, L + arm, T, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 2, boxColor), L, T, L, T + arm, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 3, boxColor), R, T, R - arm, T, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 4, boxColor), R, T, R, T + arm, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 5, boxColor), L, B, L + arm, B, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 6, boxColor), L, B, L, B - arm, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 7, boxColor), R, B, R - arm, B, th)
                ESP.DrawLine(ESP.EnsureCorner(key, 8, boxColor), R, B, R, B - arm, th)
              else
                for i = 1, 8 do ESP.Hide(ESP.Corners[key] and ESP.Corners[key][i]) end
              end

              -- 2) health bar (left): bg full + fill pct + HealthColor
              local pct = ESP.GetHealthPct(c)
              local sbX = L - (CFG.SideBarGap or 5.0)
              if (ESP.Menu or {}).ShowHealth then
                ESP.UpdateHealthBar(key, pct, sbX, T, B - T)
              else
                ESP.Hide(ESP.HealthBg[key])
                ESP.Hide(ESP.HealthFill[key])
              end

              -- 4) green snap line top-center -> head
              if (ESP.Menu or {}).ShowLine then
                ESP.DrawLine(ESP.EnsureSnap(key), origin.X, origin.Y, headS.X, headS.Y,
                             CFG.SnapThickness or 1.8)
              else
                ESP.Hide(ESP.Lines[key])
              end

              -- 5) bottom info: name / distance / Open-Close(visibility)
              local bVis = false
              if needVis then bVis = ESP.IsVisible(key, pc, camLoc, c) end
              ESP.UpdateInfo(key, c, item.IsBot, item.Distance, bVis, cx, B, T)
            else
              ESP.HideTarget(key)
            end
          else
            ESP.HideTarget(key)
          end
        else
          ESP.HideTarget(key)
        end
      else
        ESP.HideTarget(key)
      end
    end
  end
  -- stale: yang off-screen di-hide, yang sudah keluar dari EnemyCache di-release.
  -- Dulu release hanya lewat Corners/HealthBg; saat Team box & Health bar OFF
  -- tabel itu kosong, sehingga ESP.Infos (6 widget/target) dan ESP.Lines tidak
  -- pernah dihancurkan -> UMG menumpuk -> force close di pertengahan match.
  local seenCache = ESP.SeenKeys
  if seenCache == nil then
    seenCache = {}
    for _, it in ipairs(ESP.EnemyCache) do seenCache[it.Key] = true end
  end
  local stale = {}
  local function markStale(t)
    for k in pairs(t) do
      if not seenCache[k] then stale[k] = true end
    end
  end
  markStale(ESP.Lines)
  markStale(ESP.Infos)
  markStale(ESP.Corners)
  markStale(ESP.HealthBg)
  markStale(ESP.HealthFill)
  for k in pairs(stale) do
    ESP.ReleaseTarget(k)
  end
  for k in pairs(ESP.Infos) do
    if not active[k] then ESP.HideTarget(k) end
  end
  for k in pairs(ESP.Lines) do
    if not active[k] then ESP.Hide(ESP.Lines[k]) end
  end
  -- Extra world ESP: airdrop, zone, grenade.
  local me = ESP.GetLocalCharacter()
  if ESP.Extra and ESP.Extra.Update then
    pcall(ESP.Extra.Update, pc, vw, vh, camLoc, now)
  end
  -- Advanced overlays: loot, damage, ghost, squad, vehicle, sound.
  if ESP.Adv and ESP.Adv.Update then
    pcall(ESP.Adv.Update, pc, vw, vh, camLoc, now, me)
  end
end

-- Single driver: sirf ek repeating timer (lag/flicker fix).
-- Purana triple-driver (Tick loop + 2x AddGameTimer) hata diya.
function ESP.Tick()
  -- SUPPORT automation tidak butuh canvas dan harus tetap jalan saat ESP 2
  -- maupun ESP LOOT OFF.
  if ESP.Support and ESP.Support.Update then pcall(ESP.Support.Update, ESP.Now()) end
  if ESP.LowEnd then
    local now = ESP.Now()
    if (now - (ESP._LowTick or -999.0)) < (ESP.LowTickInterval or 0.120) then return end
    ESP._LowTick = now
  end
  pcall(ESP.Update)
end

function ESP.AttachTimers()
  pcall(function()
    local pc = ESP.GetController()
    if ESPValid(pc) and pc.AddGameTimer then
      if ESP._TimerPC == pc and ESP._TimerHooked then return end
      ESP._TimerPC = pc
      ESP._TimerHooked = true
      pc:AddGameTimer(ESP.LightInterval or 0.080, true, function()
        if ESP.bActive then pcall(ESP.Tick) end
      end)
    else
      if not ESP._ReattachScheduled then
        ESP._ReattachScheduled = true
        pcall(function()
          require("timer").SetGameTimer(1.0, false, function()
            ESP._ReattachScheduled = false
            ESP._TimerHooked = false
            ESP.AttachTimers()
          end)
        end)
      end
    end
    if not ESP._HealthCheckScheduled then
      ESP._HealthCheckScheduled = true
      pcall(function() require("timer").SetGameTimer(5.0, false, function()
        ESP._HealthCheckScheduled = false
        if ESP.bActive then ESP.AttachTimers() end
      end) end)
    end
  end)
end
function ESP.Stop()
  ESP.bActive = false
  ESP._TimerHooked = false
  ESP._TimerPC = nil
  ESP._MainOffCleaned = false
  ESP.ResetWidgets()
  -- Kedua gate OFF: lepas hook overlay dan kosongkan cache, jangan biarkan
  -- event damage tetap terpasang selama fitur tidak dipakai.
  if ESP.Adv and ESP.Adv.ClearAll then pcall(ESP.Adv.ClearAll) end
end
function ESP.Start()
  if ESP.bActive and ESP._TimerHooked then
    pcall(ESP.Update)
    return
  end
  -- Apply persisted menu values before the first render/update pass.
  ESP.SyncMenuConfig()
  ESP.bActive = true
  pcall(ESP.Update)
  ESP.AttachTimers()
end

_G.ESP = ESP
_G.PlayerMapMarker = ESP

local function ESPLater(sec, fn)
  local tk = nil
  pcall(function() tk = require("common.time_ticker") end)
  if tk and tk.AddTimerOnce then pcall(function() tk.AddTimerOnce(sec, fn) end) return end
  pcall(function() require("timer").SetGameTimer(sec, false, fn) end)
end

local _ESPStartedPC = nil
local function ESPRequestedEnabled()
  pcall(function()
    if _G.SyncRapzhangConfig then _G.SyncRapzhangConfig() end
  end)
  local c = _G.RapzhangConfig
  -- ESP LOOT punya gerbang sendiri: driver harus tetap hidup walau
  -- ESP V2 (EspLoai9) OFF, supaya label loot tetap dirender.
  -- SUPPORT automation juga menghidupkan driver tanpa canvas/ESP apa pun.
  return c ~= nil
    and (c.EspLoai9 == true or c.Esp9_Loot == true
      or c.Sup_FastLoot == true or c.Sup_AutoRescue == true)
    and ESP_Enabled == true
end
local function ESPStartAll()
  pcall(function()
    local pc = nil
    if slua_GameFrontendHUD then pc = slua_GameFrontendHUD:GetPlayerController() end
    if not ESPValid(pc) then pc = ESP.GetController() end
    if not ESPRequestedEnabled() then
      if ESP.bActive then ESP.Stop() end
      _ESPStartedPC = nil
      return
    end
    ESP.SyncMenuConfig()
    if ESPValid(pc) then
      if pc ~= _ESPStartedPC then
        _ESPStartedPC = pc
        ESP._TimerHooked = false
        ESP._TimerPC = nil
        ESP.Start()
      elseif not ESP.bActive then
        -- A previous module instance may have left the global bootstrap flag set.
        -- Re-enter the full start path instead of only attaching a timer.
        ESP.Start()
      else
        ESP.AttachTimers()
        pcall(ESP.Update)
      end
    end
  end)
end

pcall(function()
  ESPStartAll()
  ESPLater(1.0, ESPStartAll)
end)
if not _G.__ESPLookTickStarted then
  _G.__ESPLookTickStarted = true
  ESPStartAll()
else
  -- Re-bootstrap after reloads where the global marker survives.
  ESPStartAll()
end

-- ============================================================
-- BULLET TRACK SMART HEAD (isolated from ESP/AimTouch)
-- ============================================================
local BulletTrackSmartHead = _G.BulletTrackSmartHead or {}
_G.BulletTrackSmartHead = BulletTrackSmartHead
BulletTrackSmartHead._target = nil
BulletTrackSmartHead._scanAt = 0
BulletTrackSmartHead._viewport = nil
BulletTrackSmartHead._lastBulletSpeed = 80000
BulletTrackSmartHead._lastVelocity = nil
BulletTrackSmartHead._lastVelocityAt = 0
BulletTrackSmartHead._lastInjectedShootID = nil
BulletTrackSmartHead._lastInjectedAt = 0
BulletTrackSmartHead._lastFiring = false
BulletTrackSmartHead._observedWeaponKey = nil
BulletTrackSmartHead._observedShootID = nil
BulletTrackSmartHead._hooked = BulletTrackSmartHead._hooked or {}
BulletTrackSmartHead.BoneMap = {[0] = "Head", [1] = "neck_01", [2] = "spine_03"}

function BulletTrackSmartHead.SafeBonePos(target, boneName)
    if not target or not slua.isValid(target) then return nil end
    local alternate = boneName == "Head" and "head" or (boneName == "head" and "Head" or nil)
    local pos = nil
    pcall(function() if target.GetBonePos then pos = target:GetBonePos(boneName, {X=0,Y=0,Z=0}) end end)
    if pos and (pos.X ~= 0 or pos.Y ~= 0 or pos.Z ~= 0) then return pos end
    if alternate then
        pos = nil
        pcall(function() if target.GetBonePos then pos = target:GetBonePos(alternate, {X=0,Y=0,Z=0}) end end)
        if pos and (pos.X ~= 0 or pos.Y ~= 0 or pos.Z ~= 0) then return pos end
    end
    pcall(function() if target.GetSocketLocation then pos = target:GetSocketLocation(boneName) end end)
    if pos and (pos.X ~= 0 or pos.Y ~= 0 or pos.Z ~= 0) then return pos end
    return nil
end

function BulletTrackSmartHead.FindTarget(lp, pc, cx, cy, boneName)
    if not lp or not pc then return nil end
    local myTeam = 0
    pcall(function() myTeam = lp.GetTeamID and lp:GetTeamID() or lp.TeamID or 0 end)
    local activeProfile = BulletTrackSmartHead._activeProfile or {}
    local maxPx = tonumber(activeProfile.range) or tonumber(_G.RapzhangState.CustomTextData and _G.RapzhangState.CustomTextData.BTRange) or 300
    maxPx = math.max(1, math.min(1000, math.floor(maxPx + 0.5)))
    local maxDistCm = 400 * 100
    local actors = {}
    pcall(function()
        local cls = import("STExtraPlayerCharacter")
        if cls and Game and Game.GetActorsByClass then
            local list = Game:GetActorsByClass(cls)
            if list and list.Num and list.Get then
                for i = 0, (list:Num() or 0) - 1 do
                    local actor = list:Get(i)
                    if actor and slua.isValid(actor) and actor ~= lp then actors[#actors+1] = actor end
                end
            end
        end
    end)
    if #actors == 0 then
        pcall(function()
            local gd = require("GameLua.GameCore.Data.GameplayData")
            local all = gd and gd.GetAllPlayerCharacters and gd.GetAllPlayerCharacters()
            if all then for _, actor in pairs(all) do if actor ~= lp then actors[#actors+1] = actor end end end
        end)
    end
    local best, bestD = nil, maxPx
    for _, actor in ipairs(actors) do
        pcall(function()
            if actor.IsAlive and not actor:IsAlive() then return end
            local team = actor.GetTeamID and actor:GetTeamID() or actor.TeamID or 0
            if team == myTeam then return end
            if lp.GetDistanceTo and lp:GetDistanceTo(actor) > maxDistCm then return end
            local pos = BulletTrackSmartHead.SafeBonePos(actor, boneName)
            if not pos then return end
            local screen = nil
            pcall(function() local V = import("Vector2D"); if V then screen = V() end end)
            if not screen or not pc.ProjectWorldLocationToScreen or not pc:ProjectWorldLocationToScreen(pos, screen, false) then return end
            local dx, dy = screen.X - cx, screen.Y - cy
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < bestD then bestD, best = dist, actor end
        end)
    end
    return best
end

function BulletTrackSmartHead.InstallSmartHeadHook()
    if not (_G.RapzhangConfig.BulletTrackAllWeapon == true and _G.RapzhangConfig.BTAllSmartHead == true) then return end
    local EADP = nil
    pcall(function() EADP = import("EAvatarDamagePosition") end)
    if not EADP or not EADP.BigHead then return end
    for _, modulePath in ipairs({"GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity", "GameLua.Logic.Weapon.ShootWeaponEntity"}) do
        local mod = package.loaded[modulePath]
        if mod and not BulletTrackSmartHead._hooked[modulePath] then
            local originalA = mod.GetHitBodyType
            local originalB = mod.GetHitBodyTypeByHitPos
            mod.GetHitBodyType = function(self, impact, vec)
                if _G.RapzhangConfig.BulletTrackAllWeapon == true and _G.RapzhangConfig.BTAllSmartHead == true then return EADP.BigHead end
                if originalA then return originalA(self, impact, vec) end
            end
            mod.GetHitBodyTypeByHitPos = function(self, vec)
                if _G.RapzhangConfig.BulletTrackAllWeapon == true and _G.RapzhangConfig.BTAllSmartHead == true then return EADP.BigHead end
                if originalB then return originalB(self, vec) end
            end
            BulletTrackSmartHead._hooked[modulePath] = true
        end
    end
end

function BulletTrackSmartHead.GetWeaponLabel(weapon, shoot)
    local label = nil
    pcall(function()
        for _, name in ipairs({"GetWeaponName", "GetWeaponDisplayName", "GetItemName", "GetName"}) do
            if type(weapon[name]) == "function" then
                local value = weapon[name](weapon)
                if value and tostring(value) ~= "" then label = tostring(value); break end
            end
            if shoot and type(shoot[name]) == "function" then
                local value = shoot[name](shoot)
                if value and tostring(value) ~= "" then label = tostring(value); break end
            end
        end
    end)
    local weaponId = nil
    pcall(function()
        if type(weapon.GetWeaponID) == "function" then weaponId = weapon:GetWeaponID() end
        if not weaponId and shoot and type(shoot.GetWeaponID) == "function" then weaponId = shoot:GetWeaponID() end
    end)
    if not weaponId then
        weaponId = weapon.WeaponID or weapon.WeaponId or weapon.ID or (shoot and (shoot.WeaponID or shoot.WeaponId or shoot.ID))
    end
    local idText = weaponId and tostring(weaponId) or ""
    return string.lower((label or "") .. " " .. idText)
end

function BulletTrackSmartHead.GetWeaponClass(weapon, shoot)
    local weaponId = 0
    local weaponName = ""
    pcall(function()
        if weapon and type(weapon.GetWeaponID) == "function" then weaponId = tonumber(weapon:GetWeaponID()) or 0 end
        if weapon and type(weapon.GetWeaponName) == "function" then weaponName = tostring(weapon:GetWeaponName() or "") end
    end)
    if weaponId == 0 and shoot then
        pcall(function()
            if type(shoot.GetWeaponID) == "function" then weaponId = tonumber(shoot:GetWeaponID()) or 0 end
            if weaponName == "" and type(shoot.GetWeaponName) == "function" then weaponName = tostring(shoot:GetWeaponName() or "") end
        end)
    end
    local name = string.lower(weaponName)
    local isShotgun = (weaponId >= 1030000 and weaponId < 1040000)
        or name:find("s686", 1, true) or name:find("s1897", 1, true)
        or name:find("s12", 1, true) or name:find("dbs", 1, true)
        or name:find("m1014", 1, true) or name:find("ns2000", 1, true)
        or name:find("spas", 1, true) or name:find("aa12", 1, true)
        or name:find("origin", 1, true) or name:find("shotgun", 1, true)
    local isSniper = name:find("kar98", 1, true) or name:find("m24", 1, true)
        or name:find("awm", 1, true) or name:find("mosin", 1, true)
        or name:find("win94", 1, true) or name:find("amr", 1, true)
        or name:find("sks", 1, true) or name:find("slr", 1, true)
        or name:find("mini", 1, true) or name:find("mk14", 1, true)
        or name:find("qbu", 1, true) or name:find("mk12", 1, true)
        or name:find("vss", 1, true) or name:find("dsr", 1, true)
        or name:find("m1 garand", 1, true) or name:find("sniper", 1, true)
    local isCrossbow = name:find("crossbow", 1, true) or name:find("nỏ", 1, true)
        or weaponId == 107001 or weaponId == 107007 or weaponId == 107020
    local isBow = (name:find("bow", 1, true) or name:find("cung", 1, true)
        or weaponId == 107008 or weaponId == 107009) and not isCrossbow
    if isCrossbow then return "crossbow" end
    if isBow then return "bow" end
    if isSniper then return "sniper" end
    if isShotgun then return "shotgun" end
    return "other"
end

function BulletTrackSmartHead.GetProfile(weapon, shoot)
    local cfg = _G.RapzhangConfig
    local class = BulletTrackSmartHead.GetWeaponClass(weapon, shoot)
    local data = _G.RapzhangState.CustomTextData or {}
    if class == "crossbow" and cfg.BulletTrackCrossbow == true then
        local radius = tonumber(data.BTCrossbowRange) or 300
        radius = math.max(1, math.min(1000, math.floor(radius + 0.5)))
        return { class = class, range = radius, part = data.BTCrossbowPart or 0, prob = data.BTCrossbowProb or 100 }
    end
    if class == "bow" and cfg.BulletTrackBow == true then
        local radius = tonumber(data.BTBowRange) or 300
        radius = math.max(1, math.min(1000, math.floor(radius + 0.5)))
        return { class = class, range = radius, part = data.BTBowPart or 0, prob = data.BTBowProb or 100 }
    end
    if class == "sniper" then
        if cfg.BulletTrackSniper ~= true then return nil end
        local radius = tonumber(data.BTSniperRange) or 300
        radius = math.max(1, math.min(1000, math.floor(radius + 0.5)))
        return { class = class, range = radius, part = data.BTSniperPart or 0, prob = data.BTSniperProb or 100 }
    end
    if class == "shotgun" then
        if cfg.BulletTrackShotgun ~= true then return nil end
        local radius = tonumber(data.BTShotgunRange) or 300
        radius = math.max(1, math.min(1000, math.floor(radius + 0.5)))
        return { class = class, range = radius, part = data.BTShotgunPart or 0, prob = data.BTShotgunProb or 100 }
    end
    if cfg.BulletTrackAllWeapon == true then
        local radius = tonumber(data.BTAllRange) or 300
        radius = math.max(1, math.min(1000, math.floor(radius + 0.5)))
        return { class = "all", range = radius, part = data.BTAllPart or 0, prob = data.BTAllProb or 100 }
    end
    return nil
end

function BulletTrackSmartHead.Tick(localPlayer)
    BulletTrackSmartHead.InstallSmartHeadHook()
    if not _G.RapzhangConfig.BulletTrack then _G.RapzhangConfig.BulletTrack = false; BulletTrackSmartHead._target = nil return end
    if not localPlayer or not slua.isValid(localPlayer) then return end
    local wm = localPlayer.WeaponManagerComponent or (localPlayer.GetWeaponManager and localPlayer:GetWeaponManager())
    local weapon = wm and wm.CurrentWeaponReplicated
    if not weapon or not slua.isValid(weapon) then return end
    local adsDetected = false
    pcall(function()
        if localPlayer.bIsGunADS == true or localPlayer.bIsGunADS == 1 then adsDetected = true end
        if type(localPlayer.IsGunADS) == "function" and localPlayer:IsGunADS() then adsDetected = true end
        if weapon.bIsGunADS == true or weapon.bIsGunADS == 1 then adsDetected = true end
        if type(weapon.IsGunADS) == "function" and weapon:IsGunADS() then adsDetected = true end
    end)
    _G.RapzhangBTIsADS = adsDetected
    local firing = false
    pcall(function()
        if localPlayer.bIsWeaponFiring == true or localPlayer.bIsWeaponFiring == 1 then firing = true end
        if not firing and type(localPlayer.IsWeaponFiring) == "function" and localPlayer:IsWeaponFiring() then firing = true end
        if not firing and (weapon.bIsWeaponFiring == true or weapon.bIsWeaponFiring == 1) then firing = true end
        local wm2 = localPlayer.WeaponManagerComponent
        if not firing and wm2 and (wm2.bIsWeaponFiring == true or wm2.bIsWeaponFiring == 1) then firing = true end
    end)
    local shoot = weapon.ShootWeaponComponent
    if not shoot or not slua.isValid(shoot) then return end
    pcall(function()
        if not firing and (shoot.bIsWeaponFiring == true or shoot.bIsWeaponFiring == 1) then firing = true end
    end)
    pcall(function()
        if shoot.bIsGunADS == true or shoot.bIsGunADS == 1 then _G.RapzhangBTIsADS = true end
        if type(shoot.IsGunADS) == "function" and shoot:IsGunADS() then _G.RapzhangBTIsADS = true end
    end)
    local profile = BulletTrackSmartHead.GetProfile(weapon, shoot)
    if not profile then
        BulletTrackSmartHead._activeProfile = nil
        BulletTrackSmartHead._target = nil
        return
    end
    local legacySniperShotgun = profile.class == "sniper" or profile.class == "shotgun"
    if legacySniperShotgun and type(shoot.ShootBulletInner) ~= "function" then return end
    if legacySniperShotgun then
        _G.RapzhangBTIsADS = false
        pcall(function()
            if localPlayer.bIsGunADS == true or localPlayer.bIsGunADS == 1 then _G.RapzhangBTIsADS = true end
            if not _G.RapzhangBTIsADS and type(localPlayer.IsGunADS) == "function" and localPlayer:IsGunADS() then _G.RapzhangBTIsADS = true end
        end)
    end
    if not firing then
        local observedShootId = tonumber(shoot.CurShootID) or 0
        local weaponKey = tostring(weapon)
        if BulletTrackSmartHead._observedWeaponKey ~= weaponKey then
            BulletTrackSmartHead._observedWeaponKey = weaponKey
            BulletTrackSmartHead._observedShootID = observedShootId
        elseif observedShootId > 0 and observedShootId ~= BulletTrackSmartHead._observedShootID then
            firing = true
            BulletTrackSmartHead._observedShootID = observedShootId
        end
    end
    if not firing then
        BulletTrackSmartHead._lastFiring = false
        BulletTrackSmartHead._activeProfile = nil
        BulletTrackSmartHead._target = nil
        return
    end
    local btModeAllowed = false
    if profile.class == "crossbow" then
        btModeAllowed = (_G.RapzhangBTIsADS and _G.RapzhangConfig.BulletTrackCrossbowScope == true) or ((not _G.RapzhangBTIsADS) and _G.RapzhangConfig.BulletTrackCrossbowHipfire == true)
    elseif profile.class == "bow" then
        btModeAllowed = (_G.RapzhangBTIsADS and _G.RapzhangConfig.BulletTrackBowScope == true) or ((not _G.RapzhangBTIsADS) and _G.RapzhangConfig.BulletTrackBowHipfire == true)
    elseif profile.class == "sniper" then
        btModeAllowed = (_G.RapzhangBTIsADS and _G.RapzhangConfig.BulletTrackSniperScope == true) or ((not _G.RapzhangBTIsADS) and _G.RapzhangConfig.BulletTrackSniperHipfire == true)
    elseif profile.class == "shotgun" then
        btModeAllowed = (_G.RapzhangBTIsADS and _G.RapzhangConfig.BulletTrackShotgunScope == true) or ((not _G.RapzhangBTIsADS) and _G.RapzhangConfig.BulletTrackShotgunHipfire == true)
    else
        btModeAllowed = (_G.RapzhangBTIsADS and _G.RapzhangConfig.BulletTrackAllScope == true) or ((not _G.RapzhangBTIsADS) and _G.RapzhangConfig.BulletTrackAllHipfire == true)
    end
    if not btModeAllowed then
        BulletTrackSmartHead._target = nil
        return
    end
    BulletTrackSmartHead._activeProfile = profile
    local pc = localPlayer.GetPlayerControllerSafety and localPlayer:GetPlayerControllerSafety() or nil
    if not pc or not slua.isValid(pc) then return end
    local vp = BulletTrackSmartHead._viewport
    if not vp or os.clock() - (vp.t or 0) > 5 then
        pcall(function()
            local ui = require("client.common.ui_util")
            local size = ui and ui.GetViewportSize and ui.GetViewportSize()
            if size and size.X and size.Y then vp = {x=size.X,y=size.Y,t=os.clock()}; BulletTrackSmartHead._viewport = vp end
        end)
    end
    if not vp then return end
    local activeProfile = BulletTrackSmartHead._activeProfile or {}
    local bone = BulletTrackSmartHead.BoneMap[math.floor((activeProfile.part or 0)+0.5)] or "Head"
    local prob = tonumber(activeProfile.prob) or 100
    if activeProfile.class == "bow" or activeProfile.class == "crossbow" then
        if prob <= 100 then prob = prob * 10 end
        if prob < 1000 and math.random(1, 1000) > prob then return end
    elseif prob < 100 and math.random(1, 100) > prob then
        return
    end
    local now = os.clock()
    local target = BulletTrackSmartHead._target
    local targetValid = target and slua.isValid(target) or false
    if targetValid then pcall(function() if target.IsAlive and not target:IsAlive() then targetValid = false end end) end
    if not targetValid or now >= BulletTrackSmartHead._scanAt then
        BulletTrackSmartHead._scanAt = now + 0.03
        target = BulletTrackSmartHead.FindTarget(localPlayer, pc, vp.x*0.5, vp.y*0.5, bone)
        BulletTrackSmartHead._target = target
    end
    if not target or not slua.isValid(target) then return end
    local aimPos = BulletTrackSmartHead.SafeBonePos(target, bone)
    if not aimPos then return end
    local nowPrediction = os.clock()
    local velocity = nil
    pcall(function() if target.GetVelocity then velocity = target:GetVelocity() end end)
    if velocity and (velocity.X ~= 0 or velocity.Y ~= 0 or velocity.Z ~= 0) then
        BulletTrackSmartHead._lastVelocity = velocity
        BulletTrackSmartHead._lastVelocityAt = nowPrediction
    elseif BulletTrackSmartHead._lastVelocity and nowPrediction - (BulletTrackSmartHead._lastVelocityAt or 0) <= 0.15 then
        velocity = BulletTrackSmartHead._lastVelocity
    end
    local bulletSpeed = tonumber(BulletTrackSmartHead._lastBulletSpeed) or 80000
    pcall(function()
        if type(shoot.GetMaxBulletFlySpeed) == "function" then
            local value = tonumber(shoot:GetMaxBulletFlySpeed())
            if value and value > 10000 and value < 1000000 then
                bulletSpeed = value
                BulletTrackSmartHead._lastBulletSpeed = value
            end
        end
    end)
    if not bulletSpeed or bulletSpeed <= 10000 then
        bulletSpeed = 80000
        BulletTrackSmartHead._lastBulletSpeed = bulletSpeed
    end
    if velocity and (velocity.X ~= 0 or velocity.Y ~= 0 or velocity.Z ~= 0) then
        local distanceCm = 0
        pcall(function() distanceCm = tonumber(localPlayer:GetDistanceTo(target)) or 0 end)
        local flightTime = distanceCm / bulletSpeed
        if flightTime > 0 and flightTime < 0.5 then
            local V = rawget(_G, "FVector") or import("Vector")
            if V then aimPos = V(aimPos.X + velocity.X * flightTime, aimPos.Y + velocity.Y * flightTime, aimPos.Z + velocity.Z * flightTime) end
        end
    end
    local camLoc, rot = nil, nil
    pcall(function()
        local gs = import("GameplayStatics")
        local cm = gs and gs.GetPlayerCameraManager and gs.GetPlayerCameraManager(pc, 0)
        if cm and slua.isValid(cm) then camLoc = cm:GetCameraLocation() end
    end)
    if not camLoc then return end
    pcall(function()
        local kml = import("KismetMathLibrary")
        if kml and kml.FindLookAtRotation then rot = kml.FindLookAtRotation(camLoc, aimPos) end
    end)
    if not rot then return end
    local entity = shoot.ShootWeaponEntityComponent
    if not entity or not slua.isValid(entity) then return end
    local shootId = type(shoot.CurShootID) == "number" and shoot.CurShootID or 0
    local injectNow = os.clock()
    if shootId > 0 then
        if BulletTrackSmartHead._lastInjectedShootID == shootId then return end
        BulletTrackSmartHead._lastInjectedShootID = shootId
    else
        if BulletTrackSmartHead._lastFiring then return end
        BulletTrackSmartHead._lastFiring = true
    end
    BulletTrackSmartHead._lastInjectedAt = injectNow
    pcall(function()
        if type(shoot.ShootBulletInner) == "function" then
            shoot:ShootBulletInner(aimPos, rot, shootId)
        elseif entity and type(entity.ShootBulletInner) == "function" then
            entity:ShootBulletInner(aimPos, rot, shootId)
        end
    end)
end

local function IsGameplayMatchActive(GameplayData)
    local active = false
    pcall(function()
        if GameStatus and type(GameStatus.IsInFightingStatus) == "function" then
            active = GameStatus.IsInFightingStatus() == true
        end
    end)
    if not active and GameplayData then
        pcall(function()
            local gs = GameplayData.GetGameState and GameplayData.GetGameState()
            local mode = gs and gs.GetGameModeState and gs:GetGameModeState()
            active = mode == "FightingState" or tostring(mode) == "FightingState"
        end)
    end
    return active
end

_G.RapzhangState.RestoreGameplayWeaponStats = _G.RapzhangState.RestoreGameplayWeaponStats or function(player)
    pcall(function()
        local localPlayer = player
        if not Valid(localPlayer) then
            local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if okData and GameplayData and GameplayData.GetPlayerController then
                local pc = GameplayData.GetPlayerController()
                if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end
            end
        end
        if not Valid(localPlayer) then return end

        local weapon = nil
        local weaponManager = localPlayer.WeaponManagerComponent
        if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
            weapon = weaponManager:GetCurrentWeapon()
        end
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
            elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
        end
        if not Valid(weapon) then return end

        local entities, seen = {}, {}
        local function addEntity(entity)
            if Valid(entity) and not seen[entity] then
                seen[entity] = true
                entities[#entities + 1] = entity
            end
        end
        addEntity(weapon.ShootWeaponEntity_GEN_VARIABLE)
        addEntity(weapon.ShootWeaponEntity)
        if Valid(weapon.ShootWeaponComponent) then
            addEntity(weapon.ShootWeaponComponent.ShootWeaponEntityComponent)
        end

        for _, entity in ipairs(entities) do
            local orig = entity.OriginalStatsCached
            if orig then
                entity.GameDeviationFactor = orig.GameDeviationFactor
                entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
                entity.BulletFireSpeed = orig.BulletFireSpeed
                entity.ShootInterval = orig.ShootInterval
                entity.BaseDamage = orig.BaseDamage
                entity.AccessoriesHRecoilFactor = orig.AccessoriesHRecoilFactor
                entity.AccessoriesVRecoilFactor = orig.AccessoriesVRecoilFactor
                entity.RecoilKick = orig.RecoilKick
                entity.RecoilKickADS = orig.RecoilKickADS
                entity.AnimationKick = orig.AnimationKick
            end
            if entity.AutoAimingConfig and entity.OriginalAutoAimCached then
                local aimOrig = entity.OriginalAutoAimCached
                pcall(function() entity.AutoAimingConfig.Bones = { "Spine_01", "Pelvis", "Head" } end)
                if entity.AutoAimingConfig.OuterRange and aimOrig.OuterSpeed ~= nil then
                    entity.AutoAimingConfig.OuterRange.Speed = aimOrig.OuterSpeed
                end
                if entity.AutoAimingConfig.InnerRange and aimOrig.InnerSpeed ~= nil then
                    entity.AutoAimingConfig.InnerRange.Speed = aimOrig.InnerSpeed
                end
            end
            entity.RapzhangWeaponModsActive = false
        end
    end)
end

local function RapzhangMenu()
    if _G.RapzhangState.MenuStep ~= 0 then return end
    _G.RapzhangLang = "EN"
    _G.RapzhangState.MenuStep = 1
    pcall(function()
        _G.InitModMenuTab()
    end)
end

-- ========================================== 
-- LOGIC MỞ KHÓA 165 FPS VÀ UI IPAD VIEW 
-- ========================================== 
local function InitializeGraphicsUnlock() 
    if _G.RapzhangState.GraphicsUnlocked then return end

    pcall(function()
        local SettingCfg = require("client.logic.setting.setting_config")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        if SettingCfg then
            if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
            if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
        end
        if GraphicSettingDB then
            if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
        end
    end)

    pcall(function()
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        
        local KismetMathLibrary = import("KismetMathLibrary") or _G.KismetMathLibrary
        local FLinearColor = import("LinearColor") or _G.FLinearColor

        if logic_setting_graphics then
            local old_SetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if old_SetFPS then old_SetFPS(gameInstance, FPSLevel) end
                if FPSLevel == 8 then 
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end

        if GSC_FPS and GSC_FPS.__inner_impl then
            local fps_impl = GSC_FPS.__inner_impl
            function fps_impl:GetMaxFPSLevel() return 8, 8 end
            function fps_impl:InitRealSupportFPS()
                local RealSupportFPS = {}
                for i = 1, 8 do RealSupportFPS[i] = {true, true} end
                if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, RealSupportFPS, false) end
                return RealSupportFPS
            end
            function fps_impl:UpdateSelectedFPSState(selectedLevel)
                if not slua.isValid(self.UIRoot) then return end
                for level = 2, 8 do
                    local name = "NodeFps" .. (({[2]=20,[3]=25,[4]=30,[5]=40,[6]=60,[7]=90,[8]=120})[level] or 120)
                    local widget = self.UIRoot[name]
                    if slua.isValid(widget) then
                        widget:SetIsEnabled(true) 
                        pcall(function() widget:SetRenderOpacity(1.0) end)
                        local switcher = self.UIRoot["WidgetSwitcher_" .. level]
                        if slua.isValid(switcher) then 
                            switcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) 
                        end
                    end
                end
            end
        end

        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            local ft_impl = GSC_FPSFT.__inner_impl
            local NMinFPS, NStep = 90, 5
            local function clamp(value, min, max)
                if value < min then return min end
                if max < value then return max end
                return value
            end
            local function lerp(a, b, t) return a + (b - a) * t end
            local function _getColorByPercent(start, finish, percent)
                if not FLinearColor then return nil end
                return FLinearColor(lerp(start.R, finish.R, percent), lerp(start.G, finish.G, percent), lerp(start.B, finish.B, percent), lerp(start.A, finish.A, percent))
            end
            
            ft_impl.ShowOrHide = function(self)
                self:SelfHitTestInvisible()
                if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end
            end

            ft_impl.InitFPSFTSwitch = function(self)
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(FPSFineTuneSwitch, true) end
                if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, FPSFineTuneSwitch) end
                if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
            end

            ft_impl.InitFPSFTValue165 = function(self)
                local itemRoot = self.UIRoot
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                local FPSFineTuneNum = 165
                if FPSFineTuneSwitch then
                    FPSFineTuneNum = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
                    itemRoot.Slider_screen3:SetLocked(false)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 1.0, 1.0, 1.0))
                    end
                else
                    itemRoot.Slider_screen3:SetLocked(true)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 0.625, 0.6, 1))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 0.625, 0.6, 1.0))
                    end
                end
                local FPSFineTunePer = (FPSFineTuneNum - NMinFPS) / (165 - NMinFPS)
                
                itemRoot.Veihclescreen3:SetText(tostring(FPSFineTuneNum))
                itemRoot.Slider_screen3:SetValue(FPSFineTunePer)
                itemRoot.ProgressBar_screen3:SetPercent(FPSFineTunePer)
                
                if FLinearColor then
                    local startColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                    local midColor = FLinearColor(1.0, 0.54, 0.11, 1.0)
                    local endColor = FLinearColor(1.0, 0.23, 0.15, 1.0)
                    local sliderColor = FPSFineTunePer < 0.4 and startColor or _getColorByPercent(midColor, endColor, (FPSFineTunePer - 0.4) / 0.6)
                    itemRoot.Slider_screen3:SetSliderHandleColor(sliderColor)
                end
            end

            ft_impl.OnFPSFTValueChange3 = function(self, FPSFineTuneNum)
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, FPSFineTuneNum)
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
                if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
                local gameInstance = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
                if gameInstance then
                    gameInstance:ExecuteCMD("t.MaxFPS", tostring(FPSFineTuneNum))
                    gameInstance:ExecuteCMD("r.FrameRateLimit", tostring(FPSFineTuneNum))
                end
            end

            ft_impl.OnFPSFTSliderValueChange3 = function(self, value)
                if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) and KismetMathLibrary then
                    local FPSFineTuneNum = KismetMathLibrary.FCeil(value * (165 - NMinFPS) / NStep) * NStep + NMinFPS
                    self:OnFPSFTValueChange3(clamp(FPSFineTuneNum, NMinFPS, 165))
                end
            end
            
            ft_impl.OnFPSFTAdd = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTAdd2 = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus2 = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTSliderValueChange = ft_impl.OnFPSFTSliderValueChange3
            ft_impl.OnFPSFTSliderValueChange2 = ft_impl.OnFPSFTSliderValueChange3
        end
    end)
    _G.RapzhangState.GraphicsUnlocked = true
    Notify("Graphics & FPS 165Hz Unlocked (Upgraded Version)")
end

-- ========================================== 
-- LOCAL FUNCTIONS CHO LOGIC NEW ESP - OPTIMIZED
-- ========================================== 
local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 3.0) then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            if Valid(cachedMesh) then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then
                        table.insert(meshes, comp)
                    end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end

local function ApplyColorBodyNew(enemy, markData)
    pcall(function()
        if not _G.ConsoleNewWallReady then
            local KismetSystemLibrary = import("KismetSystemLibrary")
            local world = slua.getWorld()
            if KismetSystemLibrary and world then
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
                _G.ConsoleNewWallReady = true
            end
        end

        local meshes = GetAllSkeletalMeshes(enemy, markData)
        
        local weapon = nil
        pcall(function() weapon = enemy:GetCurrentWeapon() end)
        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
            table.insert(meshes, weapon.Mesh)
        end

        local isBot = markData.AK_IS_BOT or false
        local currentMeshCount = #meshes
        
        local stateHash = (isBot and "BOT" or "PLAYER") .. "_" .. tostring(currentMeshCount)
        
        if markData.LastColorNewHash == stateHash and markData.ColorNewApplied then
            return
        end
        
        markData.LastColorNewHash = stateHash
        markData.ColorNewApplied = true

        local LinearColorClass = import("LinearColor") or _G.FLinearColor
        local c_vis = LinearColorClass and LinearColorClass(0, 100, 0, 1) or {R=0, G=100, B=0, A=1}
        local c_occ = LinearColorClass and LinearColorClass(100, 0, 0, 1) or {R=100, G=0, B=0, A=1}
        local c_bVis = LinearColorClass and LinearColorClass(49, 48, 0, 100) or {R=49, G=48, B=0, A=100}
        local c_bOcc = LinearColorClass and LinearColorClass(9, 1.5, 45, 100) or {R=9, G=1.5, B=45, A=100}

        local visColor = isBot and c_bVis or c_vis
        local occColor = isBot and c_bOcc or c_occ

        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetDrawDyeing) == "function" then
                        mesh:SetDrawDyeing(true)
                        mesh:SetDrawDyeingMode(1)
                        mesh:SetVisibleDyeingColor(visColor)
                        mesh:SetOccludedDyeingColor(occColor)
                        mesh:SetDyeingColorFadeDistance(99999.0)
                        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
                        mesh:SetDrawHighlight(true)
                        mesh:OverrideHighlightColor(visColor)
                        mesh:SetHighlightCanBeOccluded(false)
                        mesh:SetRenderCustomDepth(true)
                        mesh:SetCustomDepthStencilValue(255)
                    end
                end)
            end
        end
    end)
end

local function UndoColorBodyNew(enemy, markData)
    if not markData.ColorNewApplied then
        return
    end

    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 and markData.CachedMeshes then
            meshes = markData.CachedMeshes
        end
        local weapon = nil
        pcall(function() weapon = enemy:GetCurrentWeapon() end)
        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
            table.insert(meshes, weapon.Mesh)
        end

        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetDrawDyeing) == "function" then
                        mesh:SetDrawDyeing(false)
                        mesh:SetDrawHighlight(false)
                        mesh:SetRenderCustomDepth(false)
                    end
                end)
            end
        end
        markData.ColorNewApplied = false
        markData.LastColorNewHash = ""
    end)
end

-- ========================================== 
-- HỆ THỐNG AIMBOT V2 TÍCH HỢP MỚI (UPDATE KISMET SMOOTH)
-- ========================================== 
_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()

    if not slua.isValid(player) then
        return result
    end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        if not _G.RapzhangConfig.AimTouchEnable then
            ClearMortarTargetLock()
            return
        end        
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then
            ClearMortarTargetLock()
            return
        end        
        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then
            ClearMortarTargetLock()
            return
        end        
        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS
        local weapon = player.WeaponManagerComponent and player.WeaponManagerComponent.CurrentWeaponReplicated
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end
        local isShotgun = false
        local isSniper = false
        local isMortar = false 
        local isCrossbow = false
        local isBow = false
        local isM249 = false
        local currentAmmo = 1
        
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            local wNameLower = tostring(wName):lower()
            isM249 = wNameLower:find("m249", 1, true) ~= nil or wNameLower:find("m%-249", 1, true) ~= nil
            
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then 
                isShotgun = true 
            end
                                    
            if not isM249 and (wName:find("Kar98") or wName:find("M24") or wName:find("AWM") or wName:find("Mosin") or wName:find("Win94") or wName:find("AMR") or wName:find("SKS") or wName:find("SLR") or wName:find("Mini") or wName:find("Mk14") or wName:find("QBU") or wName:find("Mk12") or wName:find("VSS") or wName:find("DSR") or wName:find("M1 Garand")) then
                isSniper = true
            end

            if wName:lower():find("mortar") or wName:lower():find("cối") then
                isMortar = true
            end
            
            if wName:lower():find("crossbow") or wName:lower():find("nỏ") or wID == 107001 or wID == 107007 or wID == 107020 then
                isCrossbow = true
            end
            
            if wID == 107008 or wID == 107009 or (wName:lower():find("bow") and not wName:lower():find("crossbow")) or wName:lower():find("cung") then
                isBow = true
            end            
            
            if type(weapon.GetCurrentAmmo) == "function" then
                currentAmmo = weapon:GetCurrentAmmo()
            elseif weapon.ShootWeaponComponent and type(weapon.ShootWeaponComponent.GetCurrentAmmo) == "function" then
                currentAmmo = weapon.ShootWeaponComponent:GetCurrentAmmo()
            elseif weapon.CurrentAmmo ~= nil then
                currentAmmo = weapon.CurrentAmmo
            end
        end

        if isM249 and not isFiring then
            pcall(function()
                if weapon and (weapon.bIsWeaponFiring == true or weapon.bIsWeaponFiring == 1 or weapon.bIsFiring == true or weapon.bIsFiring == 1) then isFiring = true end
                local shootComp = weapon and weapon.ShootWeaponComponent
                if not isFiring and shootComp and (shootComp.bIsWeaponFiring == true or shootComp.bIsWeaponFiring == 1 or shootComp.bIsFiring == true or shootComp.bIsFiring == 1) then isFiring = true end
            end)
        end

        if not isMortar then
            ClearMortarTargetLock()
        end

        if _G.RapzhangState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.RapzhangState.IsAutoFiring = false
        end

        if isShotgun and currentAmmo <= 0 then
            return
        end

        local cond = 2
        local prioMode = 1
        local boneIdx = 1
        local speedVal = 50
        local fovVal = 30
        local maxDistMeters = 50
        local ignoreWall = false 
        local igKnock = false
        local igBot = false
        local predVal = 0 
        local recoilCompVal = 0 
       
        if isMortar and _G.RapzhangConfig.AimTouchMortar then
            local isPlaced = false
            pcall(function()
                if weapon and weapon.MortarState == 2 then isPlaced = true end
            end)
            if not isPlaced then
                ClearMortarTargetLock()
                return
            end

            cond = 2 
            prioMode = 1  
            boneIdx = 4 
            speedVal = 100 
            fovVal = _G.RapzhangState.CustomTextData.AimTouchMortarFOV or 360
            maxDistMeters = 2000
            ignoreWall = _G.RapzhangConfig.AimTouchMortarVisCheck == true
            igKnock = false
            igBot = false
            prioMode = _G.RapzhangState.CustomTextData.AimTouchMortarPrio or 1
            predVal = _G.RapzhangState.CustomTextData.AimTouchMortarPred or 0 
            
        elseif isShotgun and _G.RapzhangConfig.AimTouchSG then
            cond = _G.RapzhangState.CustomTextData.AimTouchSGCond or 1
            if _G.RapzhangConfig.AimTouchSGAutoFire then cond = 2 end
            if cond == 1 and not isFiring then return end
            prioMode = _G.RapzhangState.CustomTextData.AimTouchSGPrio or 1
            boneIdx = _G.RapzhangState.CustomTextData.AimTouchSGBone or 2
            speedVal = _G.RapzhangState.CustomTextData.AimTouchSGSpeed or 80
            fovVal = _G.RapzhangState.CustomTextData.AimTouchSGFOV or 40
            maxDistMeters = _G.RapzhangState.CustomTextData.AimTouchSGDist or 30
            ignoreWall = _G.RapzhangConfig.AimTouchSGVisCheck
            igKnock = _G.RapzhangConfig.AimTouchSGIgKnock
            igBot = _G.RapzhangConfig.AimTouchSGIgBot
            
        elseif isCrossbow and _G.RapzhangConfig.AimTouchCrossbow then
            local crossbowModeAllowed = (isADS and _G.RapzhangConfig.AimTouchCrossbowScope) or ((not isADS) and _G.RapzhangConfig.AimTouchCrossbowHipfire)
            if not crossbowModeAllowed then
                _G.AimTouchLockedTarget = nil
                return
            end
            cond = _G.RapzhangState.CustomTextData.AimTouchCrossbowCond or 2
            if cond == 1 and not isFiring then
                _G.AimTouchLockedTarget = nil
                return
            end
            prioMode = _G.RapzhangState.CustomTextData.AimTouchCrossbowPrio or 1
            boneIdx = _G.RapzhangState.CustomTextData.AimTouchCrossbowBone or 1
            speedVal = _G.RapzhangState.CustomTextData.AimTouchCrossbowSpeed or 100 
            fovVal = _G.RapzhangState.CustomTextData.AimTouchCrossbowFOV or 40
            maxDistMeters = _G.RapzhangState.CustomTextData.AimTouchCrossbowDist or 150
            ignoreWall = false 
            igKnock = false
            igBot = false
            predVal = _G.RapzhangState.CustomTextData.AimTouchCrossbowPred or 0 
                                     
        elseif isBow and _G.RapzhangConfig.AimTouchBow then
            cond = _G.RapzhangState.CustomTextData.AimTouchBowCond or 1
            if cond == 1 and not (isFiring or isADS) then 
                _G.AimTouchLockedTarget = nil 
                return 
            end
            prioMode = 1
            boneIdx = _G.RapzhangState.CustomTextData.AimTouchBowBone or 1 
            speedVal = _G.RapzhangState.CustomTextData.AimTouchBowSpeed or 80
            fovVal = _G.RapzhangState.CustomTextData.AimTouchBowFOV or 40
            maxDistMeters = _G.RapzhangState.CustomTextData.AimTouchBowDist or 150
            ignoreWall = false 
            igKnock = false
            igBot = false   
            predVal = _G.RapzhangState.CustomTextData.AimTouchBowPred or 0 
            recoilCompVal = _G.RapzhangState.CustomTextData.AimTouchBowRecoil or 0 
            
        elseif isSniper then
            if _G.RapzhangConfig.AimTouchSniperEnable ~= true then
                _G.AimTouchLockedTarget = nil
                _G.RapzhangConfig.AimTouchScopeSniper = false
                _G.RapzhangConfig.AimTouchSniperHipfire = false
                return
            end
            local sniperModeAllowed = (isADS and _G.RapzhangConfig.AimTouchScopeSniper) or ((not isADS) and _G.RapzhangConfig.AimTouchSniperHipfire)
            if not sniperModeAllowed then
                _G.AimTouchLockedTarget = nil
                return
            end
            if sniperModeAllowed then
                cond = _G.RapzhangState.CustomTextData.AimTouchSniperCond or 2
                if cond == 1 and not isFiring then return end
                prioMode = _G.RapzhangState.CustomTextData.AimTouchSniperPrio or 1
                boneIdx = _G.RapzhangState.CustomTextData.AimTouchSniperBone or 1
                speedVal = _G.RapzhangState.CustomTextData.AimTouchSniperSpeed or 30
                fovVal = _G.RapzhangState.CustomTextData.AimTouchSniperFOV or 20
                maxDistMeters = _G.RapzhangState.CustomTextData.AimTouchSniperDist or 400
                ignoreWall = _G.RapzhangConfig.AimTouchSniperVisCheck
                igKnock = _G.RapzhangConfig.AimTouchSniperIgKnock
                igBot = _G.RapzhangConfig.AimTouchSniperIgBot
                predVal = _G.RapzhangState.CustomTextData.AimTouchSniperPred or 0 
            else
                return
            end
        elseif isADS then
            if _G.RapzhangConfig.AimTouchScopeAll then
                cond = _G.RapzhangState.CustomTextData.AimTouchScopeCond or 1
                if cond == 1 and not isFiring then return end
                prioMode = _G.RapzhangState.CustomTextData.AimTouchScopePrio or 1
                boneIdx = _G.RapzhangState.CustomTextData.AimTouchScopeBone or 2
                speedVal = _G.RapzhangState.CustomTextData.AimTouchScopeSpeed or 40
                fovVal = _G.RapzhangState.CustomTextData.AimTouchScopeFOV or 20
                maxDistMeters = _G.RapzhangState.CustomTextData.AimTouchScopeDist or 300
                ignoreWall = _G.RapzhangConfig.AimTouchScopeVisCheck
                igKnock = _G.RapzhangConfig.AimTouchScopeIgKnock
                igBot = _G.RapzhangConfig.AimTouchScopeIgBot
                predVal = _G.RapzhangState.CustomTextData.AimTouchScopePred or 0
                recoilCompVal = _G.RapzhangState.CustomTextData.AimTouchScopeRecoil or 0
            else
                return
            end
        else
            if not _G.RapzhangConfig.AimTouchHipfire then return end
            cond = _G.RapzhangState.CustomTextData.AimTouchHipCond or 1
            if cond == 1 and not isFiring then return end 
            prioMode = _G.RapzhangState.CustomTextData.AimTouchHipPrio or 1
            boneIdx = _G.RapzhangState.CustomTextData.AimTouchHipBone or 1
            speedVal = _G.RapzhangState.CustomTextData.AimTouchHipSpeed or 50
            fovVal = _G.RapzhangState.CustomTextData.AimTouchHipFOV or 30
            maxDistMeters = _G.RapzhangState.CustomTextData.AimTouchHipDist or 250
            ignoreWall = _G.RapzhangConfig.AimTouchHipVisCheck
            igKnock = _G.RapzhangConfig.AimTouchHipIgKnock
            igBot = _G.RapzhangConfig.AimTouchHipIgBot
        end

        local currentMaxDist = maxDistMeters * 100 
        local enemies = _G.GetEnemyTargetsFromActors(currentMaxDist)
        if not enemies or #enemies == 0 then 
            _G.AimTouchLockedTarget = nil
            if isMortar then ClearMortarTargetLock() end
            return 
        end
        
        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")
        
        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end
        
        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end
        
        local ui_util = require("client.common.ui_util")
        if not ui_util then return end
        
        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end
        
        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = (fovVal / 100.0) * (viewportSize.X / 2.0)
        
        local bestTarget = nil
        local bestScore = 99999999
        local bestBoneName = nil
        local bestBonePos = nil
        
        _G.AimTouchLockedTarget = _G.AimTouchLockedTarget or nil
        local isLockedTargetValid = false

        local selBoneName = "head"
        if boneIdx == 1 then selBoneName = "head"
        elseif boneIdx == 2 then selBoneName = "spine_03"
        elseif boneIdx == 3 then selBoneName = "spine_01"
        elseif boneIdx == 4 then selBoneName = "pelvis" end

        local primaryBoneName = selBoneName
        local smartBoneCache = _G.AimTouchBoneFallbackCache or {}
        _G.AimTouchBoneFallbackCache = smartBoneCache
        local smartTraceLib, smartHitResult = nil, nil
        pcall(function() smartTraceLib = import("KismetSystemLibrary") end)
        local function SmartBonePosition(target, boneName)
            local pos = nil
            pcall(function()
                if type(target.GetBonePos) == "function" then
                    pos = target:GetBonePos(boneName, {X=0, Y=0, Z=0})
                end
            end)
            if (not pos or (pos.X == 0 and pos.Y == 0 and pos.Z == 0)) and type(target.GetSocketLocation) == "function" then
                pcall(function() pos = target:GetSocketLocation(boneName) end)
            end
            if pos and pos.X and pos.Y and pos.Z and not (pos.X == 0 and pos.Y == 0 and pos.Z == 0) then return pos end
            return nil
        end
        local function SmartBoneVisible(target, bonePos)
            if not bonePos then return false end
            local visible = nil
            if smartTraceLib and type(smartTraceLib.LineTraceSingle) == "function" then
                pcall(function()
                    if not smartHitResult then
                        local HitResultClass = import("HitResult") or import("/Script/Engine.HitResult")
                        smartHitResult = HitResultClass and HitResultClass() or {}
                    end
                    local hit = smartTraceLib.LineTraceSingle(pc, camLoc, bonePos, 0, false, nil, 0, smartHitResult, true)
                    if not hit then
                        visible = true
                    else
                        local hitActor = nil
                        if type(smartHitResult.GetActor) == "function" then hitActor = smartHitResult:GetActor()
                        elseif smartHitResult.Actor then hitActor = smartHitResult.Actor end
                        if hitActor == target then
                            visible = true
                        elseif hitActor and type(hitActor.IsChildOf) == "function" then
                            visible = hitActor:IsChildOf(target) == true
                        else
                            visible = false
                        end
                    end
                end)
            end
            if visible == nil and type(pc.LineOfSightTo) == "function" then
                pcall(function() visible = pc:LineOfSightTo(target) == true end)
            end
            return visible == true
        end
        local function SelectStableBone(target)
            local key = tostring(target) .. ":" .. tostring(primaryBoneName)
            local nowBone = os.clock()
            local cached = smartBoneCache[key]
            local candidates = {primaryBoneName}
            local function add(name)
                for _, v in ipairs(candidates) do if v == name then return end end
                candidates[#candidates + 1] = name
            end
            -- Cache hanya dipakai sebagai urutan prioritas, bukan sebagai hasil
            -- visibility; raycast tetap diulang agar perubahan dinding/cover
            -- langsung terlihat pada frame berikutnya.
            if cached and cached.name then
                candidates = {cached.name}
            end
            if primaryBoneName == "head" then
                add("neck_01"); add("spine_03"); add("spine_01"); add("pelvis")
            elseif primaryBoneName == "neck_01" then
                add("head"); add("spine_03"); add("spine_01"); add("pelvis")
            elseif primaryBoneName == "spine_03" or primaryBoneName == "spine_01" then
                add("neck_01"); add("head"); add("pelvis")
            else
                add("spine_03"); add("neck_01"); add("head")
            end
            for _, name in ipairs(candidates) do
                local pos = SmartBonePosition(target, name)
                if pos and SmartBoneVisible(target, pos) then
                    smartBoneCache[key] = {time = nowBone, name = name, pos = pos}
                    return name, pos
                end
            end
            smartBoneCache[key] = {time = nowBone, name = false, pos = nil}
            return nil, nil
        end

        for i, target in ipairs(enemies) do
            if not slua.isValid(target) then goto continue end
            if igKnock and target.HealthStatus == 1 then goto continue end
            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then goto continue end
            end
            
            local tPos = nil
            if type(target.K2_GetActorLocation) == "function" then
                tPos = target:K2_GetActorLocation()
            end
            if not tPos then goto continue end
            tPos.Z = tPos.Z + 30

            local candidateBoneName, candidateBonePos = nil, nil
            if ignoreWall then
                candidateBoneName, candidateBonePos = SelectStableBone(target)
                if not candidateBoneName or not candidateBonePos then goto continue end
            else
                candidateBonePos = SmartBonePosition(target, primaryBoneName)
            end
            local aimScreenPos = candidateBonePos or tPos
            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(aimScreenPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end

            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)
            local currentFovLimit = FOV_RADIUS
            if (isCrossbow or isBow) and target == _G.AimTouchLockedTarget then
                currentFovLimit = FOV_RADIUS * 5.0
            end
            if distScreen > currentFovLimit then goto continue end

            local currentScore = distScreen
            if prioMode == 2 then currentScore = player:GetDistanceTo(target)
            elseif prioMode == 3 then currentScore = target.Health or 100
            elseif prioMode == 4 then 
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end
            
            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
                bestBoneName = candidateBoneName
                bestBonePos = candidateBonePos
            end
            
            ::continue::
        end
        
        if not slua.isValid(bestTarget) then 
            _G.AimTouchLockedTarget = nil
            if isMortar then ClearMortarTargetLock() end
            return 
        end

        -- Target dengan aim point paling dekat ke pusat crosshair menjadi target
        -- aktif; lock lama tidak boleh mengalahkan target yang lebih presisi.
        _G.AimTouchLockedTarget = bestTarget
        
        local smartFallbackBone = bestBoneName and bestBoneName ~= primaryBoneName
        if smartFallbackBone then selBoneName = bestBoneName end
        local finalBonePos = nil
        if not smartFallbackBone then
            pcall(function()
                if type(bestTarget.GetBonePos) == "function" then
                    finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
                end
            end)
        else
            finalBonePos = bestBonePos and {X=bestBonePos.X, Y=bestBonePos.Y, Z=bestBonePos.Z} or nil
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if boneIdx == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif boneIdx == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif boneIdx == 3 then finalBonePos.Z = finalBonePos.Z + 20 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end

        local targetPose = 0
        pcall(function()
            if type(bestTarget.GetPoseState) == "function" then
                targetPose = bestTarget:GetPoseState()
            elseif bestTarget.PoseState then
                targetPose = bestTarget.PoseState
            end
        end)
        
        if not smartFallbackBone and boneIdx == 1 then
            if targetPose == 2 then
                finalBonePos.Z = finalBonePos.Z + 5
            elseif isCrossbow then
                finalBonePos.Z = finalBonePos.Z + 18
            elseif isBow then
                finalBonePos.Z = finalBonePos.Z + 8
            else
                finalBonePos.Z = finalBonePos.Z + 8
            end
        elseif not smartFallbackBone and (boneIdx == 2 or boneIdx == 3) then
            if targetPose == 2 then
                finalBonePos.Z = finalBonePos.Z - 6
            end
        end

        local tVelocity = nil
        pcall(function()
            if type(bestTarget.GetVelocity) == "function" then
                tVelocity = bestTarget:GetVelocity()
            end
        end)

        if isMortar and _G.RapzhangConfig.AimTouchMortar and predVal > 0 then
            pcall(function()
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local approxDist = player:GetDistanceTo(bestTarget) / 100.0
                    local approxToF = approxDist / 100.0 
                    local predScale = predVal / 50.0
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * approxToF * predScale)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * approxToF * predScale)
                end
            end)
        end

        if isCrossbow and _G.RapzhangConfig.AimTouchCrossbow then
            pcall(function()
                local distUU = player:GetDistanceTo(bestTarget) 
                local vMeters = _G.RapzhangState.CustomTextData.AimTouchCrossbowVel or 160
                if vMeters < 50 then vMeters = 160 end 

                local dropScale = 1.0
                if targetPose == 2 then
                    dropScale = (_G.RapzhangState.CustomTextData.AimTouchCrossbowDropProne or 120) / 100.0
                else
                    dropScale = (_G.RapzhangState.CustomTextData.AimTouchCrossbowDrop or 100) / 100.0
                end
                
                local vUU = vMeters * 100 
                local ToF = distUU / vUU                               
                
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) and predVal > 0 then
                    local predScale = predVal / 50.0
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF * predScale)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF * predScale)
                end
                
                local gravity = 980 
                local dropAmount = 0.5 * gravity * (ToF * ToF) * dropScale * 1.15
                finalBonePos.Z = finalBonePos.Z + dropAmount
            end)
        end

        if isBow and _G.RapzhangConfig.AimTouchBow then
            pcall(function()
                local distUU = player:GetDistanceTo(bestTarget)
                local distMeters = distUU / 100.0
                
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) and predVal > 0 then
                    local ToF_Pred = (distMeters / 150.0) * (predVal / 50.0)
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF_Pred)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF_Pred)
                end

                local dropVal = _G.RapzhangState.CustomTextData.AimTouchBowDrop or 50
                if dropVal > 0 then
                    local ToF_Drop = distUU / 15000.0 
                    local dropScale = dropVal / 100.0
                    local gravity = 980
                    local dropAmount = 0.5 * gravity * (ToF_Drop * ToF_Drop) * dropScale
                    finalBonePos.Z = finalBonePos.Z + dropAmount
                end
            end)
        end

        if not isMortar and not isCrossbow and not isBow and predVal > 0 then
            pcall(function()
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0 
                    local ToF = (distToEnemy / 800.0) * (predVal / 50.0) 
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end
        
        local currentRot = pc:GetControlRotation()
        if not currentRot then return end
        
        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch
        
        if isADS and not isCrossbow and not isBow then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end
        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end
        
        speedVal = tonumber(speedVal) or 50
        if speedVal < 1 then speedVal = 1 end
        if speedVal > 100 then speedVal = 100 end
        local aimTickInterval = 0.02
        local smoothResponse = 3.0 + (speedVal * 0.90)
        local smoothFactor = 1.0 - math.exp(-smoothResponse * aimTickInterval)
        if smoothFactor < 0.02 then smoothFactor = 0.02 end
        if smoothFactor > 0.85 then smoothFactor = 0.85 end
        
        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)
        
        if recoilCompVal > 0 and (isFiring or (isBow and isADS)) then
            local pullDownForce = (recoilCompVal / 50.0) * 1.5 
            finalPitch = finalPitch - pullDownForce
        end
        
        if isMortar and _G.RapzhangConfig.AimTouchMortar then
            local targetPos = { X = finalBonePos.X, Y = finalBonePos.Y, Z = finalBonePos.Z }
            local launchPos = camLoc
            pcall(function()
                if player.K2_GetActorLocation then
                    local pLoc = player:K2_GetActorLocation()
                    if pLoc then 
                        launchPos = { X = pLoc.X, Y = pLoc.Y, Z = pLoc.Z + 50 } 
                    end
                end
            end)

            local function CalcMortarTrajectory(V, G, tX, tY, tZ)
                local mDx = math.sqrt((tX - launchPos.X)^2 + (tY - launchPos.Y)^2) - 80 
                if mDx < 500 then mDx = 500 end 
                local mDy = tZ - launchPos.Z
                
                local minVSq = G * (mDy + math.sqrt(mDx*mDx + mDy*mDy))
                if (V * V) < minVSq then
                    V = math.sqrt(minVSq) + 100 
                end

                local v2 = V * V
                local root = v2*v2 - G*(G*mDx*mDx + 2*mDy*v2)
                
                if root >= 0 then
                    local angleRad = math.atan((v2 + math.sqrt(root)) / (G * mDx))
                    local deg = math.deg(angleRad)
                    if deg >= 35 and deg <= 89.5 then 
                        return true, deg, mDx / (V * math.cos(angleRad)), mDx
                    end
                end
                return false, 45, 0, mDx
            end

            local vNear, gNear = 9070, 980 * 2.8   
            local vFar, gFar = 12520, 980 * 4.0    
            local vUltra, gUltra = 16800, 980 * 4.5 
            
            local isValid, physAngle, ToF, finalDx = false, 45, 0, 0
            
            local okNear, angNear, tofNear, dxN = CalcMortarTrajectory(vNear, gNear, targetPos.X, targetPos.Y, targetPos.Z)
            local okFar, angFar, tofFar, dxF = CalcMortarTrajectory(vFar, gFar, targetPos.X, targetPos.Y, targetPos.Z)
            local okUltra, angUltra, tofUltra, dxU = CalcMortarTrajectory(vUltra, gUltra, targetPos.X, targetPos.Y, targetPos.Z)

            if okNear and dxN <= 25000 then
                isValid, physAngle, ToF, finalDx = okNear, angNear, tofNear, dxN
            elseif okFar and dxF <= 40000 then
                isValid, physAngle, ToF, finalDx = okFar, angFar, tofFar, dxF
            elseif okUltra then
                isValid, physAngle, ToF, finalDx = okUltra, angUltra, tofUltra, dxU
            elseif okNear then
                isValid, physAngle, ToF, finalDx = okNear, angNear, tofNear, dxN
            end

            local targetCameraPitch = ((physAngle - 45) / 43.0) * 90.0 - 60.0
            local rot = KismetMathLibrary.FindLookAtRotation(camLoc, targetPos)
            local targetCameraYaw = rot.Yaw

            local deltaPitchMortar = targetCameraPitch - currentRot.Pitch
            local deltaYawMortar = targetCameraYaw - currentRot.Yaw

            if deltaPitchMortar > 180 then deltaPitchMortar = deltaPitchMortar - 360 end
            if deltaPitchMortar < -180 then deltaPitchMortar = deltaPitchMortar + 360 end
            if deltaYawMortar > 180 then deltaYawMortar = deltaYawMortar - 360 end
            if deltaYawMortar < -180 then deltaYawMortar = deltaYawMortar + 360 end
            
            finalPitch = currentRot.Pitch + (deltaPitchMortar * smoothFactor)
            finalYaw = currentRot.Yaw + (deltaYawMortar * smoothFactor)
        end
        
        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")
        UpdateMortarTargetLock(isMortar and _G.RapzhangConfig.AimTouchMortar and _G.RapzhangConfig.AimTouchMortarShowTargetLock == true, bestTarget)
        
        if isShotgun and _G.RapzhangConfig.AimTouchSGAutoFire then
            pcall(function()
                local distToTarget = player:GetDistanceTo(bestTarget) / 100
                if distToTarget <= maxDistMeters then
                    player.bIsWeaponFiring = true
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(true) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(true) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = true end
                    
                    local currentWep = player:GetCurrentWeapon()
                    if slua.isValid(currentWep) and type(currentWep.StartFire) == "function" then 
                        currentWep:StartFire() 
                    end
                    _G.RapzhangState.IsAutoFiring = true
                end
            end)
        end

    end)
end

-- ==========================================
-- MAIN LOOP (DENGAN ACE RE-HOOK)
-- ==========================================
-- ============================================================
-- KILLER REPORT ASSIST (isolated, confirmation required)
-- ============================================================
do
  local function AR_Load(name)
    if package.loaded[name] then return package.loaded[name] end
    local ok, mod = pcall(require, name)
    return ok and mod or nil
  end
  local state = _G.AutoReportAssistState or { matchID = "", reported = {}, dismissed = {}, promptOpen = false, lastCheck = 0 }
  _G.AutoReportAssistState = state
  state.reported = state.reported or {}; state.dismissed = state.dismissed or {}
  function _G.AutoReportAssistReset(clearMatch)
    state.reported = {}; state.dismissed = {}; state.promptOpen = false; state.pendingUID = nil; state.lastCheck = 0
    if clearMatch then state.matchID = "" end
  end
  local function notify(msg)
    local text = "[REPORT ASSIST] " .. tostring(msg)
    pcall(function()
      local sh = import("ScriptHelperClient")
      if sh and sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(text, -1, 3.0, {R=1,G=1,B=0,A=1}, {X=1.1,Y=1.1}) else print(text) end
    end)
  end
  local function submit(complaint, target, matchID)
    complaint.Submit(target.name, false, false, {4}, "Report Killer", 1, {1,3,9}, {}, "", matchID, 18, target.uid, target.openID or "", "", {}, 0,0,0,0,0,0, false, 0, nil, "NTHMOD_KillerReport", target.uid, false, 0)
  end
  local function showConfirm(target, matchID)
    if state.promptOpen then return end
    local uid = tostring(target.uid or 0); if uid == "0" or uid == "" then return end
    local msg = AR_Load("client.slua.logic.common.logic_common_msg_box")
    if not msg or type(msg.Show) ~= "function" then notify("Sistem report belum siap; gunakan report manual."); state.dismissed[uid]=true; return end
    state.promptOpen=true; state.pendingUID=uid
    local function finish() state.promptOpen=false; state.pendingUID=nil end
    msg.Show(1, "REPORT KILLER", "Killer terdeteksi:\n\n"..tostring(target.name).."\nUID: "..uid.."\n\nKirim laporan untuk pemain ini?", function()
      local complaint=AR_Load("client.logic.battle.logic_complaint")
      if not complaint then notify("Sistem report belum siap."); finish(); return end
      local already=false
      pcall(function() if complaint.IsAlreadyReported then already=complaint.IsAlreadyReported(target.name,matchID)==true end end)
      if already or state.reported[uid] then state.reported[uid]=true; notify("Target sudah dilaporkan di match ini."); finish(); return end
      local ok=pcall(submit, complaint, target, matchID)
      if ok then
        state.reported[uid]=true
        notify("Laporan dikirim: "..tostring(target.name))
        -- Kirim notifikasi ke Telegram setelah report benar-benar dipanggil.
        pcall(function()
          local feedback=_G.RapzhangAutoTextFeedback
          if feedback and feedback.SendReport then feedback.SendReport(target.name, target.uid, matchID) end
        end)
      else notify("Gagal mengirim laporan; gunakan report manual.") end
      finish()
    end, function() state.dismissed[uid]=true; notify("Laporan dibatalkan: "..tostring(target.name)); finish() end, "LAPORKAN", "BATAL")
  end
  function _G.AutoReportAssistTick()
    local cfg=_G.RapzhangConfig
    if not cfg or cfg.AutoReportKiller ~= true or state.promptOpen then return end
    local now=os.clock(); if now-(state.lastCheck or 0)<1.0 then return end; state.lastCheck=now
    local complaint=AR_Load("client.logic.battle.logic_complaint"); if not complaint then return end
    local matchID=tostring((type(complaint.GetBattleID)=="function" and complaint.GetBattleID()) or "LOBBY")
    if matchID=="LOBBY" or matchID=="0" or matchID=="" then return end
    if tostring(state.matchID or "")~=matchID then state.matchID=matchID; state.reported={}; state.dismissed={}; state.pendingUID=nil end
    local mgr=rawget(_G,"SubsystemMgr")
    if not mgr then pcall(function() mgr=require("GameLua.GameCore.Module.Subsystem.SubsystemMgr") end) end
    if not mgr then return end
    local sub; pcall(function() sub=mgr:Get("ClientReportPlayerSubsystem") end); if not sub then return end
    local utils=AR_Load("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils"); if not utils then return end
    local targets={}; pcall(function() for _,d in pairs(sub:GetFatalDamagerMap(true) or {}) do targets[#targets+1]=d end end); pcall(function() for _,d in pairs(sub:GetFatalDamagerMap(false) or {}) do targets[#targets+1]=d end end)
    for _,data in pairs(targets) do
      local name=data and utils.S_NAME and data[utils.S_NAME]; local uid=data and utils.S_UID and data[utils.S_UID]
      if name and uid then
        local target={name=tostring(name),uid=tonumber(uid) or 0,openID=(utils.S_OPEN_ID and data[utils.S_OPEN_ID]) or ""}; local key=tostring(target.uid)
        if target.name~="" and target.uid>0 and not state.reported[key] and not state.dismissed[key] then showConfirm(target,matchID); break end
      end
    end
  end
end
-- ============================================================
-- AUTO TEXT FEEDBACK (Telegram; no screenshot; complete match report)
-- ============================================================
_G.RapzhangAutoTextFeedback = (function()
  local AF = _G.RapzhangAutoTextFeedback or {}
  AF._lastMatchSent = AF._lastMatchSent or ""
  AF._lastSendAt = AF._lastSendAt or 0

  local function mod(name)
    if package.loaded[name] then return package.loaded[name] end
    local ok, m = pcall(require, name)
    return ok and m or nil
  end

  local function addTimerOnce(delay, callback)
    local ticker = mod("common.time_ticker")
    if ticker and type(ticker.AddTimerOnce) == "function" then
      local ok = pcall(ticker.AddTimerOnce, delay, callback)
      if ok then return true end
    end
    if ticker and type(ticker.AddTimer) == "function" then
      local ok = pcall(ticker.AddTimer, delay, function()
        callback()
      end)
      if ok then return true end
    end
    return false
  end

  local function g(t, key)
    if t == nil then return nil end
    local ok, value = pcall(function() return t[key] end)
    if ok then return value end
    return nil
  end

  local function firstNumber(...)
    local n = select("#", ...)
    for i = 1, n do
      local raw = select(i, ...)
      if type(raw) == "number" then return raw end
      if type(raw) == "string" then
        local value = tonumber(raw)
        if value ~= nil then return value end
      end
    end
    return nil
  end

  local function firstBool(...)
    local n = select("#", ...)
    for i = 1, n do
      local value = select(i, ...)
      if value == true then return true end
      if value == false then return false end
    end
    return nil
  end

  local function valFrom(sources, ...)
    local keys = {...}
    for _, src in ipairs(sources) do
      if src ~= nil then
        for _, key in ipairs(keys) do
          local value = g(src, key)
          local kind = type(value)
          if value ~= nil and value ~= "" and kind ~= "table" and kind ~= "function" and kind ~= "userdata" then
            return value
          end
        end
      end
    end
    return nil
  end

  local function fmtInt(value)
    local n = tonumber(value)
    if n == nil then return nil end
    n = math.floor(n)
    local text = tostring(n)
    local sign = ""
    if text:sub(1, 1) == "-" then
      sign = "-"
      text = text:sub(2)
    end
    local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    out = out:gsub("^,", ""):gsub(",$", "")
    return sign .. out
  end

  local function fmtCount(value, singular, plural)
    local n = tonumber(value)
    if n == nil then return nil end
    plural = plural or (singular .. "s")
    return fmtInt(n) .. " " .. (n == 1 and singular or plural)
  end

  local function fmtNum(value, decimals)
    local n = tonumber(value)
    if n == nil then return nil end
    if decimals ~= nil then
      return string.format("%." .. tostring(decimals) .. "f", n)
    end
    if n == math.floor(n) then return fmtInt(n) end
    return string.format("%.1f", n)
  end

  local function fmtSigned(value)
    local n = tonumber(value)
    if n == nil then return nil end
    if n > 0 then return "+" .. fmtInt(n) end
    if n < 0 then return fmtInt(n) end
    return "±0"
  end

  local function fmtDuration(value)
    local n = tonumber(value)
    if n == nil or n < 0 then return nil end
    n = math.floor(n + 0.5)
    local h = math.floor(n / 3600)
    local m = math.floor((n % 3600) / 60)
    local s = n % 60
    if h > 0 then
      return string.format("%dh %02dm %02ds", h, m, s)
    end
    return string.format("%dm %02ds", m, s)
  end

  local function fmtDistance(value)
    local n = tonumber(value)
    if n == nil then return nil end
    if n >= 1000 then return string.format("%.2f km", n / 1000) end
    return fmtInt(n) .. " m"
  end

  local function fmtPercent(value)
    local n = tonumber(value)
    if n == nil then return nil end
    return string.format("%.1f%%", n)
  end

  local function clip(value, maxChars)
    local text = tostring(value == nil and "" or value)
    if maxChars == nil or maxChars <= 0 then return text end
    local index, count = 1, 0
    while index <= #text do
      if count >= maxChars then
        return text:sub(1, index - 1) .. "…"
      end
      local byte = text:byte(index)
      local step = 1
      if byte >= 240 then
        step = 4
      elseif byte >= 224 then
        step = 3
      elseif byte >= 192 then
        step = 2
      end
      index = index + step
      count = count + 1
    end
    return text
  end

  local function esc(value)
    local text = tostring(value == nil and "" or value)
    text = text:gsub("%c", " ")
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    return text
  end

  local function urlEncode(value)
    return tostring(value == nil and "" or value):gsub("([^%w%-%_%.%~])", function(c)
      return string.format("%%%02X", string.byte(c))
    end)
  end

  local function utf8Len(text)
    local index, count = 1, 0
    while index <= #text do
      local byte = text:byte(index)
      local step = 1
      if byte >= 240 then
        step = 4
      elseif byte >= 224 then
        step = 3
      elseif byte >= 192 then
        step = 2
      end
      index = index + step
      count = count + 1
    end
    return count
  end

  local function trimMessage(text)
    if utf8Len(text) <= 3800 then return text end
    local plain = text:gsub("<[^>]->", "")
    return clip(plain, 3800)
  end

  -- Beberapa host memuat mod lewat environment proxy (__index). Global game
  -- seperti DataMgr/LocUtil terlihat dari chunk, tetapi rawget(_G, ...) bisa
  -- nil. Cek rawget, indeks _G, lalu global chunk supaya season_id tidak
  -- jatuh ke SeasonNumber battle result.
  local function hostValue(name)
    local value = rawget(_G, name)
    if value ~= nil then return value end
    local ok, exposed = pcall(function() return _G[name] end)
    if ok and exposed ~= nil then return exposed end
    if name == "DataMgr" then
      ok, exposed = pcall(function() return DataMgr end)
    elseif name == "LocUtil" then
      ok, exposed = pcall(function() return LocUtil end)
    elseif name == "FuncUtil" then
      ok, exposed = pcall(function() return FuncUtil end)
    elseif name == "CDataTable" then
      ok, exposed = pcall(function() return CDataTable end)
    end
    if ok then return exposed end
    return nil
  end

  local function tableData(name, id)
    if id == nil then return nil end
    local dt = hostValue("CDataTable")
    if not (dt and type(dt.GetTableData) == "function") then return nil end
    local ok, value = pcall(function()
      return dt.GetTableData(name, id)
    end)
    if ok and value then return value end
    if type(id) == "number" then
      ok, value = pcall(function()
        return dt.GetTableData(name, tostring(id))
      end)
      if ok and value then return value end
    end
    return nil
  end

  local function locStr(id)
    if id == nil or id == "" then return nil end
    local loc = hostValue("LocUtil")
    if not loc then
      local ok, lib = pcall(mod, "common.loc_util")
      if ok then loc = lib end
    end
    if loc and type(loc.GetLocalizeResStr) == "function" then
      local ok, value = pcall(loc.GetLocalizeResStr, tonumber(id) or id)
      if ok and value ~= nil and tostring(value) ~= "" then
        return tostring(value)
      end
    end
    return nil
  end

  local function rankSeason()
    local dm = hostValue("DataMgr")
    local season = tonumber(dm and dm.season_id)
    if season and season > 0 then return season end
    return nil
  end

  -- SeasonInfo memakai beberapa field dengan arti berbeda:
  --   CycleName     -> identitas season yang dipakai UI rank ("32", "S32",
  --                    "C10S32"); angka setelah S adalah nomor season.
  --   SeasonNameNew -> banner rank baru.
  --   SeasonName    -> kartu profil / teks season lama.
  -- Field lama dan baru bisa membawa nomor internal yang berbeda. Karena
  -- bullet sudah berlabel "Season", yang dibutuhkan hanya nomor season yang
  -- tampil di game. Ekstrak dari CycleName lebih dulu, lalu field nama.
  local SEASON_TEXT_FIELDS = { "SeasonNameNew", "SeasonName", "ShowName", "Name" }

  local function cleanSeasonText(value)
    if value == nil then return nil end
    local ok, text = pcall(tostring, value)
    if not ok or text == nil then return nil end
    text = text:match("^%s*(.-)%s*$") or text
    if text == "" or text == "None" or text == "nil" or text == "NULL" then return nil end
    return text
  end

  local function seasonNumberFromText(text)
    if not text then return nil end
    text = tostring(text):match("^%s*(.-)%s*$") or tostring(text)
    if text == "" then return nil end
    -- "C10S32" / "C9 S27": angka setelah S adalah nomor season.
    local cycle = text:match("[Cc]%s*%d+%s*[Ss]%s*(%d+)")
    if cycle then return tonumber(cycle) end
    -- "S32", "SS32", "Season 32", "Musim 32".
    local prefixed = text:match("^%s*[Ss]%s*(%d+)%s*$")
      or text:match("^%s*[Ss][Ss]%s*(%d+)%s*$")
      or text:match("^%s*[Ss][Ee][Aa][Ss][Oo][Nn]%s*[:#%-–—]?%s*(%d+)")
      or text:match("^%s*[Mm][Uu][Ss][Ii][Mm]%s*[:#%-–—]?%s*(%d+)")
    if prefixed then return tonumber(prefixed) end
    -- "32" polos.
    local plain = text:match("^%s*(%d+)%s*$")
    if plain then return tonumber(plain) end
    -- "第32赛季".
    local zh = text:match("%f[%d](%d+)%s*赛季")
    if zh then return tonumber(zh) end
    return nil
  end

  local function seasonFieldText(cfg, key)
    local text = cleanSeasonText(cfg[key])
    if not text then return nil end
    -- Angka 4+ digit adalah localization id, bukan nomor season.
    if text:match("^%d+$") and #text >= 4 then
      return cleanSeasonText(locStr(text))
    end
    return text
  end

  local function seasonNameFromCfg(cfg, season)
    if type(cfg) ~= "table" then return nil end

    local cycleText = seasonFieldText(cfg, "CycleName")
    local cycleNumber = seasonNumberFromText(cycleText)
    if cycleNumber then return tostring(cycleNumber) end

    for _, key in ipairs(SEASON_TEXT_FIELDS) do
      local number = seasonNumberFromText(seasonFieldText(cfg, key))
      if number then return tostring(number) end
    end

    -- Tidak ada angka season: pakai label apa adanya, tetapi buang prefix
    -- "Season"/"S" agar bullet tidak menjadi "Season: Season <nama>".
    local chosen = cycleText
    if not chosen then
      for _, key in ipairs(SEASON_TEXT_FIELDS) do
        chosen = seasonFieldText(cfg, key)
        if chosen then break end
      end
    end
    if not chosen then return nil end
    local stripped = chosen:gsub("^[Ss][Ee][Aa][Ss][Oo][Nn]%s*[:%-–—]?%s*", "")
    stripped = stripped:match("^%s*(.-)%s*$") or stripped
    stripped = stripped:gsub("^[Ss]%s*(%d+)$", "%1")
    if stripped ~= "" then return stripped end
    return chosen
  end

  -- Nama season untuk laporan. fallback terakhir hanya angka id karena
  -- bullet sudah memberi label "Season".
  local function seasonLabel(season)
    local n = tonumber(season)
    if n == nil or n <= 0 then return nil end
    local name = seasonNameFromCfg(tableData("SeasonInfo", n), n)
    if name then return name end
    return tostring(n)
  end

  local function rankCfg(segment, season)
    local n = tonumber(segment)
    if n == nil or n <= 0 then return nil end
    local util = hostValue("FuncUtil")
    if not util then
      local ok, lib = pcall(mod, "common.func_util")
      if ok then util = lib end
    end
    if util and type(util.GetRankTableData) == "function" then
      local wanted, current = tonumber(season), rankSeason()
      local tries, seen = {}, {}
      if wanted and wanted > 0 then tries[#tries + 1] = wanted end
      if current and current ~= wanted then tries[#tries + 1] = current end
      tries[#tries + 1] = 0
      for _, s in ipairs(tries) do
        if not seen[s] then
          seen[s] = true
          local ok, cfg = pcall(util.GetRankTableData, n, s)
          if ok and type(cfg) == "table" then return cfg end
        end
      end
      -- Some builds expose the lookup without a season argument.
      local ok, cfg = pcall(util.GetRankTableData, n)
      if ok and type(cfg) == "table" then return cfg end
    end
    return nil
  end

  local function rankNameFromCfg(cfg)
    if type(cfg) ~= "table" then return nil end
    for _, key in ipairs({ "Name", "RankName", "SegmentName", "IntegralTypeName", "ShowName" }) do
      local value = cfg[key]
      if value ~= nil and tostring(value) ~= "" then
        local text = tostring(value):match("^%s*(.-)%s*$")
        if text ~= "" then
          if text:match("^%d+$") then
            -- Numeric field: a long number is a localization id, not a name.
            if #text >= 4 then
              local localized = locStr(text)
              if localized and localized ~= "" then return localized end
            end
          else
            return text
          end
        end
      end
    end
    return nil
  end

  -- Direct table lookup; works even when FuncUtil is not exposed to Lua mods.
  local function rankCfgFromTables(segment)
    local n = tonumber(segment)
    if n == nil or n <= 0 then return nil end
    local firstCfg = nil
    for _, name in ipairs({
      "RankIntegralLevel_MODE_25",
      "RankIntegralLevel_MODE_47",
      "RankIntegralLevel",
    }) do
      local cfg = tableData(name, n)
      if type(cfg) == "table" then
        firstCfg = firstCfg or cfg
        if rankNameFromCfg(cfg) then return cfg end
      end
    end
    return firstCfg
  end

  -- Last resort when every table lookup fails: derive the tier from the
  -- segment id (1xx Bronze ... 8xx Conqueror, sub-level 1=V ... 5=I).
  local RANK_TIER_NAMES = {
    [1] = "Bronze",
    [2] = "Silver",
    [3] = "Gold",
    [4] = "Platinum",
    [5] = "Diamond",
    [6] = "Crown",
    [7] = "Ace",
    [8] = "Conqueror",
  }
  local RANK_SUB_NAMES = { "V", "IV", "III", "II", "I" }

  local function rankFallbackName(segment)
    local n = tonumber(segment)
    if n == nil or n <= 0 then return nil end
    local tier = math.floor(n / 100)
    local sub = n % 100
    local tierName = RANK_TIER_NAMES[tier]
    if tierName == nil then return nil end
    if tier <= 6 and sub >= 1 and sub <= #RANK_SUB_NAMES then
      return tierName .. " " .. RANK_SUB_NAMES[sub]
    end
    return tierName
  end

  local function rankLabel(segment, season)
    local n = tonumber(segment)
    if n == nil or n <= 0 then return nil end
    -- Samakan dengan ESP: nama config + bintang/divisi (Ace 4, Ace Master 15,
    -- Ace Dominator 20). Jangan pakai salinan logika sendiri.
    local ex = nil
    pcall(function()
      ex = (ESP and ESP.Extra) or (_G.ESP and _G.ESP.Extra)
    end)
    if ex and type(ex.FormatRank) == "function" then
      local ok, text = pcall(ex.FormatRank, n)
      if ok and text ~= nil and text ~= "" then return text end
    end
    local name = rankNameFromCfg(rankCfg(n, season)) or rankNameFromCfg(rankCfgFromTables(n))
    if name then return name end
    return rankFallbackName(n) or ("Rank " .. tostring(n))
  end

  -- ==========================================================================
  -- ULTIMATE ROYALE (separate ladder: Vanguard ... Legend)
  -- ==========================================================================
  -- UR rating starts at 1,000 points; each mini-tier is 100 points and each
  -- full tier is 500 points. Legend starts at 3,000.
  local UR_TIER_NAMES = { "Vanguard", "Exceed", "Supreme", "Peerless", "Legend" }
  local UR_SUB_NAMES = { "V", "IV", "III", "II", "I" }
  local UR_BASE_POINTS = 1000
  local UR_SUB_STEP = 100

  local function urTierFromPoints(points)
    local n = tonumber(points)
    if n == nil or n < UR_BASE_POINTS then return nil end
    local index = math.floor((n - UR_BASE_POINTS) / UR_SUB_STEP)
    if index >= 20 then return "Legend" end
    local tier = math.floor(index / 5) + 1
    local sub = (index % 5) + 1
    return UR_TIER_NAMES[tier] .. " " .. UR_SUB_NAMES[sub]
  end

  -- Some builds expose a numeric UR segment instead of rating points. Accept
  -- the common 1..25 and 1001..1025 id layouts. Classic 1xx segments are not
  -- accepted here because they collide with Bronze/Silver ids.
  local function urTierFromSegment(segment)
    local n = tonumber(segment)
    if n == nil or n <= 0 then return nil end
    local id = n
    if id >= 1000 and id < 1100 then id = id - 1000 end
    if id < 1 or id > 25 then return nil end
    local tier = math.floor((id - 1) / 5) + 1
    if tier >= 5 then return "Legend" end
    local sub = (id - 1) % 5 + 1
    return UR_TIER_NAMES[tier] .. " " .. UR_SUB_NAMES[sub]
  end

  local function urText(value)
    if value == nil then return nil end
    local text = tostring(value):match("^%s*(.-)%s*$")
    if text == "" then return nil end
    if text:match("^%d+$") then
      if #text >= 4 then
        local localized = locStr(text)
        if localized and localized ~= "" then return localized end
      end
      return nil
    end
    return text
  end

  local function textLooksUR(value)
    if value == nil then return false end
    local text = tostring(value)
    if text == "" then return false end
    text = text:lower()
    if text:find("ultimate", 1, true) then return true end
    if text:find("%f[%a]ur%f[%A]") then return true end
    return false
  end

  local UR_CONTAINER_KEYS = {
    "ur_rating", "urRating", "URRating",
    "ur_rating_info", "urRatingInfo", "URRatingInfo",
    "ur_info", "urInfo", "URInfo",
    "ur_data", "urData", "URData",
    "ultimate_royale_rating", "ultimateRoyaleRating", "UltimateRoyaleRating",
    "ultimate_royale_rating_info", "ultimateRoyaleRatingInfo", "UltimateRoyaleRatingInfo",
    "ultimate_royale", "ultimateRoyale", "UltimateRoyale",
    "ultimate_royale_info", "ultimateRoyaleInfo", "UltimateRoyaleInfo",
    "ultimate_royale_data", "ultimateRoyaleData", "UltimateRoyaleData",
    "BP_STRUCT_URRating", "BP_STRUCT_UltimateRoyaleRating",
    "BP_STRUCT_URRatingInfo", "BP_STRUCT_UltimateRoyaleRatingInfo",
  }

  local function collectURTables(sources, result, rating)
    local out, seen = {}, {}
    local function add(t)
      if type(t) == "table" and not seen[t] then
        seen[t] = true
        out[#out + 1] = t
      end
    end
    local function addContainers(t)
      if type(t) ~= "table" then return end
      for _, key in ipairs(UR_CONTAINER_KEYS) do add(g(t, key)) end
    end
    for _, src in ipairs(sources) do
      addContainers(src)
      addContainers(g(src, "rating") or g(src, "BP_STRUCT_BTRating"))
    end
    addContainers(result)
    addContainers(rating)
    -- One level of common nesting plus array entries.
    local base = #out
    for i = 1, base do
      local t = out[i]
      for _, key in ipairs({
        "rating_info", "ratingInfo", "RatingInfo",
        "info", "Info", "data", "Data", "detail", "Detail",
        "rating", "Rating",
      }) do
        add(g(t, key))
      end
      pcall(function()
        for _, value in ipairs(t) do add(value) end
      end)
    end
    return out
  end

  local UR_CFG_POINT_KEYS = {
    "rating", "rank_rating", "rankRating", "ur_rating", "urRating",
    "score", "points", "cur_rating", "current_rating", "curRating", "currentRating",
    "rating_point", "ratingPoint", "rank_point", "rankPoint",
    "integral", "Integral", "cur_score", "curScore",
  }
  local UR_CFG_DELTA_KEYS = {
    "change_rating", "changeRating", "rating_change", "ratingChange",
    "change_rank_rating", "changeRankRating",
    "change_ur_rating", "changeURRating",
    "delta", "change", "change_score", "changeScore",
    "add_rating", "addRating", "add_point", "addPoint",
  }
  local UR_CFG_SEGMENT_KEYS = {
    "segment", "segment_id", "segmentId", "new_segment", "newSegment",
    "cur_segment", "curSegment", "current_segment", "currentSegment",
  }
  local UR_CFG_OLD_SEGMENT_KEYS = {
    "old_segment", "oldSegment", "pre_segment", "preSegment",
    "last_segment", "lastSegment",
  }
  local UR_CFG_TIER_TEXT_KEYS = {
    "tier_name", "tierName", "TierName",
    "rank_name", "rankName", "RankName",
    "segment_name", "segmentName", "SegmentName",
    "show_name", "showName", "ShowName",
    "display_name", "displayName", "DisplayName",
  }
  local UR_POINT_KEYS = {
    "ur_rating", "urRating", "URRating",
    "ur_rank_rating", "urRankRating", "URRankRating",
    "ultimate_royale_rating", "ultimateRoyaleRating", "UltimateRoyaleRating",
    "ultimate_royale_rank_rating", "ultimateRoyaleRankRating",
    "ur_score", "urScore", "ur_points", "urPoints",
  }
  local UR_DELTA_KEYS = {
    "ur_change_rating", "urChangeRating",
    "ur_rating_change", "urRatingChange",
    "ur_delta", "urDelta",
    "change_ur_rating", "changeURRating",
    "ultimate_royale_change_rating", "ultimateRoyaleChangeRating",
    "ultimate_royale_rating_change", "ultimateRoyaleRatingChange",
    "ultimate_royale_delta", "ultimateRoyaleDelta",
    "change_ultimate_royale_rating", "changeUltimateRoyaleRating",
  }
  local UR_SEGMENT_KEYS = {
    "ur_segment", "urSegment", "URSegment",
    "ur_new_segment", "urNewSegment",
    "ultimate_royale_segment", "ultimateRoyaleSegment",
    "ultimate_royale_new_segment", "ultimateRoyaleNewSegment",
  }
  local UR_OLD_SEGMENT_KEYS = {
    "ur_old_segment", "urOldSegment",
    "ultimate_royale_old_segment", "ultimateRoyaleOldSegment",
  }
  local UR_TIER_TEXT_KEYS = {
    "ur_tier_name", "urTierName", "urTier",
    "ur_rank_name", "urRankName", "urSegmentName",
    "ultimate_royale_tier_name", "ultimateRoyaleTierName",
    "ultimate_royale_rank_name", "ultimateRoyaleRankName",
    "ultimate_royale_segment_name", "ultimateRoyaleSegmentName",
  }

  local function firstFromTables(tables, keys)
    for _, t in ipairs(tables) do
      if type(t) == "table" then
        for _, key in ipairs(keys) do
          local n = firstNumber(g(t, key))
          if n ~= nil then return n end
        end
      end
    end
    return nil
  end

  local function firstTextFromTables(tables, keys)
    for _, t in ipairs(tables) do
      if type(t) == "table" then
        for _, key in ipairs(keys) do
          local text = urText(g(t, key))
          if text then return text end
        end
      end
    end
    return nil
  end

  local function finalizeUR(ur)
    if type(ur) ~= "table" then return nil end
    if ur.points ~= nil and ur.points < UR_BASE_POINTS then ur.points = nil end
    if ur.segment ~= nil and ur.segment <= 0 then ur.segment = nil end
    if ur.oldSegment ~= nil and ur.oldSegment <= 0 then ur.oldSegment = nil end
    if ur.oldPoints == nil and ur.points ~= nil and ur.delta ~= nil then
      ur.oldPoints = math.max(0, ur.points - ur.delta)
    end
    if type(ur.tier) == "string" and ur.tier ~= "" then
      ur.tierName = ur.tierName or ur.tier
    end
    if type(ur.oldTier) == "string" and ur.oldTier ~= "" then
      ur.oldTierName = ur.oldTierName or ur.oldTier
    end
    ur.tier = ur.tierName or urTierFromPoints(ur.points) or urTierFromSegment(ur.segment)
    ur.oldTier = ur.oldTierName or urTierFromPoints(ur.oldPoints) or urTierFromSegment(ur.oldSegment)
    if ur.tier and ur.oldTier and ur.tier ~= ur.oldTier then
      ur.tierLabel = ur.oldTier .. " → " .. ur.tier
    else
      ur.tierLabel = ur.tier or ur.oldTier
    end
    if ur.tier == nil and ur.points == nil then return nil end
    return ur
  end

  local function extractUR(sources, result, rating, allowClassic)
    local containers = collectURTables(sources, result, rating)
    local ur = {}

    local flat = {}
    for _, src in ipairs(sources) do flat[#flat + 1] = src end
    if type(result) == "table" then flat[#flat + 1] = result end
    if type(rating) == "table" then flat[#flat + 1] = rating end
    local rd = _G.DataMgr and _G.DataMgr.roleData
    if type(rd) == "table" then flat[#flat + 1] = rd end

    -- Explicit UR-prefixed fields are the most reliable source.
    ur.points = firstFromTables(flat, UR_POINT_KEYS)
    ur.delta = firstFromTables(flat, UR_DELTA_KEYS)
    ur.segment = firstFromTables(flat, UR_SEGMENT_KEYS)
    ur.oldSegment = firstFromTables(flat, UR_OLD_SEGMENT_KEYS)
    ur.tierName = firstTextFromTables(flat, UR_TIER_TEXT_KEYS)

    -- Then nested UR structs.
    ur.points = ur.points or firstFromTables(containers, UR_CFG_POINT_KEYS)
    ur.delta = ur.delta or firstFromTables(containers, UR_CFG_DELTA_KEYS)
    ur.segment = ur.segment or firstFromTables(containers, UR_CFG_SEGMENT_KEYS)
    ur.oldSegment = ur.oldSegment or firstFromTables(containers, UR_CFG_OLD_SEGMENT_KEYS)
    ur.tierName = ur.tierName or firstTextFromTables(containers, UR_CFG_TIER_TEXT_KEYS)

    -- UR matches may reuse the classic rating struct for the active ladder.
    -- In that case the generic rating fields carry UR values.
    if allowClassic and type(rating) == "table" then
      ur.points = ur.points or firstNumber(
        g(rating, "rating"), g(rating, "score"), g(rating, "points"), g(rating, "rank_rating")
      )
      ur.delta = ur.delta or firstNumber(
        g(rating, "change_rating"), g(rating, "rating_change"),
        g(rating, "delta"), g(rating, "change_rank_rating")
      )
      ur.segment = ur.segment or firstNumber(g(rating, "new_segment"), g(rating, "segment"))
      ur.oldSegment = ur.oldSegment or firstNumber(g(rating, "old_segment"))
    end

    return finalizeUR(ur)
  end

  local UR_FLAG_KEYS = {
    "IsUltimateRoyale", "isUltimateRoyale", "is_ultimate_royale", "bIsUltimateRoyale",
    "URMode", "ur_mode", "isUR", "is_ur", "bIsUR", "bIsUr",
    "UltimateRoyaleMode", "ultimate_royale_mode",
  }
  local UR_MODE_TEXT_KEYS = {
    "ModeName", "ModeNameInternal", "Name", "ShowName", "GameMode", "ModeType",
    "ModeDesc", "Desc", "Description", "UIName", "TeamModeName",
  }

  local function modeLooksUR(mode, sources, subMode)
    if textLooksUR(mode) then return true end
    local cfg = tableData("BTMode", subMode)
    if type(cfg) == "table" then
      for _, key in ipairs(UR_MODE_TEXT_KEYS) do
        local value = g(cfg, key)
        if type(value) == "string" and textLooksUR(value) then return true end
        if type(value) == "number" then
          local text = locStr(value)
          if text and textLooksUR(text) then return true end
        end
      end
    end
    local dm = rawget(_G, "DataMgr")
    if dm and type(dm.GetModeName) == "function" and subMode then
      local ok, name = pcall(dm.GetModeName, subMode)
      if ok and textLooksUR(name) then return true end
    end
    for _, src in ipairs(sources) do
      for _, key in ipairs(UR_FLAG_KEYS) do
        local value = g(src, key)
        if value == true then return true end
        if type(value) == "number" and value == 1 then return true end
        if type(value) == "string" then
          local lower = value:lower()
          if lower == "1" or lower == "true" or textLooksUR(value) then return true end
        end
      end
    end
    return false
  end

  local function displayName()
    local name = "Player"
    pcall(function()
      local rd = _G.DataMgr and _G.DataMgr.roleData
      name = tostring((rd and (rd.nickName or rd.name or rd.nickname or rd.playerName)) or name)
    end)
    return name
  end

  local function currentUID()
    local uid = nil
    pcall(function()
      local rd = _G.DataMgr and _G.DataMgr.roleData
      uid = rd and (rd.uid or rd.openID or rd.openid)
    end)
    if uid == nil then uid = rawget(_G, "_KONG_UK") end
    return uid
  end

  local function maskUID(uid)
    local text = tostring(uid == nil and "" or uid)
    if text == "" or text == "nil" or text == "0" then return "unknown" end
    if #text > 5 then return text:sub(1, 5) .. "*****" end
    return "*****"
  end

  local function cleanNameText(value)
    if value == nil then return nil end
    local kind = type(value)
    if kind ~= "string" and kind ~= "number" then return nil end
    local text = tostring(value)
    text = text:gsub("%c", " "):gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or text == "nil" or text == "None" or text == "NULL" then
      return nil
    end
    return text
  end

  local function nameLooksMasked(value)
    local text = tostring(value == nil and "" or value)
    if text == "" then return true end
    if text:find("**", 1, true) or text:find("＊", 1, true) then return true end
    if text:find("^%*+$") or text:find("^#+$") then return true end
    return false
  end

  local function utf8Length(text)
    local lib = rawget(_G, "utf8")
    if lib and type(lib.len) == "function" then
      local ok, count = pcall(lib.len, text)
      if ok and type(count) == "number" then return count end
    end
    local index, count = 1, 0
    while index <= #text do
      local byte = text:byte(index)
      local size = 1
      if byte >= 240 then size = 4
      elseif byte >= 224 then size = 3
      elseif byte >= 192 then size = 2 end
      index = index + size
      count = count + 1
    end
    return count
  end

  local function utf8Head(text, count)
    if count <= 0 then return "" end
    local lib = rawget(_G, "utf8")
    if lib and type(lib.offset) == "function" then
      local ok, offset = pcall(lib.offset, text, count + 1)
      if ok and offset then return text:sub(1, offset - 1) end
    end
    local index, chars = 1, 0
    while index <= #text and chars < count do
      local byte = text:byte(index)
      local size = 1
      if byte >= 240 then size = 4
      elseif byte >= 224 then size = 3
      elseif byte >= 192 then size = 2 end
      index = index + size
      chars = chars + 1
    end
    return text:sub(1, index - 1)
  end

  local function maskPlayerName(value)
    local text = cleanNameText(value)
    if text == nil then return nil end
    local lower = text:lower()
    if lower == "unknown" or lower == "player" or lower == "bot" then
      return text
    end
    local total = utf8Length(text)
    if total <= 0 then return text end
    local keep = 4
    if total <= keep then keep = total > 1 and 1 or 0 end
    if keep == 0 then return "*" end
    local stars = total - keep
    if stars > 6 then stars = 6 end
    return utf8Head(text, keep) .. string.rep("*", stars)
  end

  local function playerStateOf(character)
    local ps = nil
    pcall(function()
      if character.GetPlayerStateSafety then
        ps = character:GetPlayerStateSafety()
      end
      if ps == nil and character.GetPlayerState then
        ps = character:GetPlayerState()
      end
    end)
    if ps == nil then pcall(function() ps = character.PlayerState end) end
    return ps
  end

  local function characterUID(character, ps)
    local uid = nil
    if character.GetPlayerUID then
      pcall(function() uid = character:GetPlayerUID() end)
    end
    if uid == nil and ps and ps.GetUIDString then
      pcall(function() uid = ps:GetUIDString() end)
    end
    if uid == nil and ps then
      pcall(function() uid = ps.PlayerUID or ps.UID end)
    end
    if uid == nil then
      pcall(function() uid = character.PlayerUID end)
    end
    if uid == nil then
      pcall(function()
        local game = rawget(_G, "Game")
        if game and type(game.GetPlayerUID) == "function" then
          uid = game:GetPlayerUID(character)
        end
      end)
    end
    return uid
  end

  local function characterName(character, ps)
    local name = nil
    if character.GetPlayerNameSafety then
      pcall(function() name = character:GetPlayerNameSafety() end)
    end
    if name == nil and character.GetPlayerName then
      pcall(function() name = character:GetPlayerName() end)
    end
    if name == nil then
      pcall(function() name = character.PlayerName or character.NickName end)
    end
    if name == nil and ps then
      if ps.GetPlayerName then
        pcall(function() name = ps:GetPlayerName() end)
      end
      if name == nil then
        pcall(function() name = ps.PlayerName or ps.PlayerNamePrivate or ps.NickName end)
      end
    end
    return cleanNameText(name)
  end

  local function liveNameForUID(uid)
    if uid == nil then return nil end
    local target = tostring(uid)
    if target == "" then return nil end
    local gd = mod("GameLua.GameCore.Data.GameplayData")
    if not (gd and type(gd.GetAllPlayerCharacters) == "function") then return nil end
    local ok, list = pcall(gd.GetAllPlayerCharacters)
    if not ok or type(list) ~= "table" then return nil end
    local found = nil
    pcall(function()
      for _, character in pairs(list) do
        local ps = playerStateOf(character)
        local characterUIDValue = characterUID(character, ps)
        if characterUIDValue ~= nil and tostring(characterUIDValue) == target then
          local name = characterName(character, ps)
          if name and not nameLooksMasked(name) then
            found = name
            return
          end
        end
      end
    end)
    return found
  end

  local function teammateDisplayName(tm, myUID)
    if tm == nil then return nil end
    local first = nil
    local nameKeys = {
      "Name", "PlayerName", "NickName", "nickName", "Nickname",
      "RoleName", "role_name", "ShowName", "RealName",
    }
    for _, key in ipairs(nameKeys) do
      local candidate = cleanNameText(g(tm, key))
      if candidate then
        if first == nil then first = candidate end
        if not nameLooksMasked(candidate) then return candidate end
      end
    end
    local uid = g(tm, "UID")
    if uid ~= nil and myUID ~= nil and tostring(uid) == tostring(myUID) then
      local mine = cleanNameText(displayName())
      if mine and not nameLooksMasked(mine) then return mine end
    end
    local live = liveNameForUID(uid)
    if live then return live end
    return first
  end

  local function activeFeatureText()
    local cfg = _G.RapzhangConfig or {}
    local features = {}
    local function add(label, enabled)
      if enabled == true then features[#features + 1] = label end
    end
    local function anyPrefix(prefix)
      for key, value in pairs(cfg) do
        if type(key) == "string" and key:sub(1, #prefix) == prefix and value == true then
          return true
        end
      end
      return false
    end
    add("ESP", anyPrefix("Esp"))
    add("Wallhack", cfg.ColorBodyNew == true)
    add("Bullet Track", anyPrefix("BulletTrack"))
    add("Aim Assist", anyPrefix("AimTouch"))
    add("Magic Bullet", cfg.CustomMagicBullet == true)
    add("Headshot", cfg.Headshot == true)
    add("Smart Head", cfg.SmartAutoHead == true or cfg.BTAllSmartHead == true)
    add("Accuracy", cfg.Accuracy == true)
    add("Less Recoil", cfg.LessRecoil == true)
    add("No Shake", cfg.LessShake == true)
    add("Custom H-Recoil", cfg.CustomHRecoil == true)
    add("Custom V-Recoil", cfg.CustomVRecoil == true)
    add("Unlock FPS", cfg.UnlockFPS == true)
    add("iPad View", cfg.IpadView == true)
    add("Crosshair", cfg.Crosshair == true)
    add("Remove Grass", cfg.RemoveGrass == true)
    add("Remove Trees", cfg.RemoveTrees == true)
    add("Remove Fog", cfg.RemoveFog == true)
    add("Low Graphics", cfg.LowGraphics == true)
    add("Vehicle WH", cfg.WallVehicle == true or cfg.VehOther == true)
    add("Enemy Weapon", cfg.EnemyWeapon == true)
    add("Force Friend", cfg.ForceFriend == true)
    add("Auto Report", cfg.AutoReportKiller == true)
    add("Auto Parachute", cfg.AutoParachute == true)
    add("Auto Jump", cfg.AutoJump == true)
    add("X3 Watermark", cfg.X3Watermark == true)
    add("X3 Fake Visual", cfg.X3FakeVisual == true)
    add("X3 Perf Boost", cfg.X3PerfBoost == true)
    add("X3 TPP Force", cfg.X3TPPForce == true)
    if #features == 0 then return "None" end
    if #features > 10 then
      return table.concat(features, ", ", 1, 10) .. " +" .. tostring(#features - 10)
    end
    return table.concat(features, ", ")
  end

  local function detectRegion()
    local region = nil
    pcall(function()
      local c = rawget(_G, "Client")
      if c and type(c.GetPublishRegion) == "function" then
        region = c.GetPublishRegion()
      end
    end)
    if region ~= nil and tostring(region) ~= "" then return tostring(region) end
    return nil
  end

  local function clientVersion()
    local version = nil
    pcall(function()
      local c = rawget(_G, "Client")
      if c and type(c.GetAppVersion) == "function" then
        version = c.GetAppVersion()
      end
    end)
    if version ~= nil and tostring(version) ~= "" then return tostring(version) end
    return nil
  end

  local function clientValue(name)
    local value = nil
    pcall(function()
      local c = rawget(_G, "Client")
      local fn = c and c[name]
      if type(fn) == "function" then
        value = fn()
      end
    end)
    if value == nil then return nil end
    local text = tostring(value)
    if text == "" or text == "nil" or text == "unknown" or text == "Unknown" then
      return nil
    end
    return value
  end

  local function cleanDeviceText(value, maxChars)
    if value == nil then return nil end
    local kind = type(value)
    if kind ~= "string" and kind ~= "number" then return nil end
    local text = tostring(value)
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or text == "nil" or text == "unknown" or text == "Unknown" then
      return nil
    end
    return clip(text, maxChars or 48)
  end

  local function detectDevicePlatform()
    local platform = clientValue("GetDevicePlatformName")
    if platform ~= nil then
      local text = tostring(platform)
      local upper = string.upper(text)
      if upper == "IOS" then return "iOS" end
      if upper == "ANDROID" then return "Android" end
      return text
    end
    local soVersion = tonumber(clientValue("GetAndroidSOVersion"))
    if soVersion == 32 or soVersion == 64 then return "Android" end
    local gd = rawget(_G, "GlobalData")
    if gd and type(gd.IsIOSCheck) == "function" then
      local ok, isIOS = pcall(gd.IsIOSCheck)
      if ok and isIOS == true then return "iOS" end
    end
    return "Unknown"
  end

  local function detectAppArch(platform)
    local soVersion = tonumber(clientValue("GetAndroidSOVersion"))
    if soVersion == 32 then return "32-bit" end
    if soVersion == 64 then return "64-bit" end
    -- Current iOS builds are ARM64-only (Apple dropped 32-bit apps in iOS 11).
    if platform == "iOS" then return "64-bit" end
    local cpu = string.lower(tostring(clientValue("GetCpuType") or ""))
    if cpu ~= "" then
      if cpu:find("arm64", 1, true) or cpu:find("aarch64", 1, true)
          or cpu:find("x86_64", 1, true) or cpu:find("64-bit", 1, true) then
        return "64-bit"
      end
      if cpu:find("armeabi", 1, true) or cpu:find("armv7", 1, true)
          or cpu:find("x86", 1, true) or cpu:find("32-bit", 1, true) then
        return "32-bit"
      end
    end
    return "Unknown"
  end

  local function detectDevice()
    local platform = detectDevicePlatform()
    local model = cleanDeviceText(clientValue("GetDeviceModel"), 42)
    local make = cleanDeviceText(clientValue("GetDeviceMake"), 24)
    if model and make then
      if not string.lower(model):find(string.lower(make), 1, true) then
        model = make .. " " .. model
      end
    elseif not model and make then
      model = make
    end
    local osVersion = cleanDeviceText(clientValue("GetOSVersion"), 24)
      or cleanDeviceText(clientValue("GetAndroidVersion"), 24)
    local osLabel = nil
    if osVersion then
      local lower = string.lower(osVersion)
      if platform == "Android" and not lower:find("android", 1, true) then
        osLabel = "Android " .. osVersion
      elseif platform == "iOS" and not lower:find("ios", 1, true) then
        osLabel = "iOS " .. osVersion
      else
        osLabel = osVersion
      end
    end
    return {
      platform = platform,
      arch = detectAppArch(platform),
      model = model,
      os = osLabel,
    }
  end

  local function detectGameVariant()
    local region = detectRegion()
    local regionMap = {
      JAPAN = "PUBGM: Japan",
      KOREA = "PUBGM: KR",
      VNG = "PUBGM: VN",
      TW = "PUBGM: TW/HK/MO",
      GLOBAL = "PUBGM: Global",
      FIT = "PUBGM: Global",
      FITCE = "PUBGM: Global",
      BGMILITE = "PUBGM: India",
      BLUEHOLE = "PUBGM: Global",
      CE = "PUBGM: CE",
    }
    if region and regionMap[string.upper(region)] then
      return regionMap[string.upper(region)]
    end

    local candidates = {
      region,
      rawget(_G, "GameVersion"), rawget(_G, "GAME_VERSION"),
      rawget(_G, "GameRegion"), rawget(_G, "GAME_REGION"),
      rawget(_G, "Region"), rawget(_G, "SERVER_REGION"),
      rawget(_G, "PackageName"), rawget(_G, "PACKAGE_NAME"),
      rawget(_G, "AppPackageName"), rawget(_G, "APP_PACKAGE_NAME"),
      rawget(_G, "ChannelName"), rawget(_G, "CHANNEL_NAME"),
      rawget(_G, "ServerRegion"), rawget(_G, "server_region")
    }
    pcall(function()
      local rd = _G.DataMgr and _G.DataMgr.roleData
      if type(rd) == "table" then
        candidates[#candidates + 1] = rd.region
        candidates[#candidates + 1] = rd.country
        candidates[#candidates + 1] = rd.packageName
        candidates[#candidates + 1] = rd.package_name
        candidates[#candidates + 1] = rd.channel
        candidates[#candidates + 1] = rd.serverRegion
      end
    end)

    local function classify(value)
      local text = tostring(value or ""):lower()
      if text == "" or text == "nil" then return nil end
      if text:find("pubg.krmobile", 1, true) or text:find("korea", 1, true)
          or text:match("[^%a]kr[^%a]") or text:match("^kr$") then
        return "PUBGM: KR"
      end
      if text:find("vng", 1, true) or text:find("vietnam", 1, true)
          or text:match("[^%a]vn[^%a]") or text:match("^vn$") then
        return "PUBGM: VN"
      end
      if text:find("taiwan", 1, true) or text:find("rekoo", 1, true)
          or text:find("hongkong", 1, true) or text:find("macau", 1, true)
          or text:match("[^%a]tw[^%a]") or text:match("^tw$") then
        return "PUBGM: TW/HK/MO"
      end
      if text:find("com.tencent.igfit", 1, true) then
        return "PUBGM: Flash"
      end
      if text:find("com.pubg.imobile", 1, true) or text:find("bgmi", 1, true)
          or text:find("india", 1, true) then
        return "PUBGM: India"
      end
      if text:find("com.tencent.ig", 1, true)
          or text:find("battlegrounds", 1, true) or text:find("global", 1, true)
          or text:find("com.pubg.mobile", 1, true) then
        return "PUBGM: Global"
      end
      return nil
    end

    for _, value in ipairs(candidates) do
      local result = classify(value)
      if result then return result end
    end
    local loaded = package and package.loaded
    if type(loaded) == "table" then
      for name in pairs(loaded) do
        local result = classify(name)
        if result then return result end
      end
    end
    return "PUBGM: Unknown"
  end

  local function getHttp()
    local mm = rawget(_G, "ModuleManager")
    if mm and type(mm.GetModule) == "function"
        and mm.CommonModuleConfig and mm.CommonModuleConfig.http_manager then
      local ok, http = pcall(mm.GetModule, mm.CommonModuleConfig.http_manager)
      if ok and http and type(http.Post) == "function" then return http end
    end
    local cls = mod("client.slua.logic.http.http_manager")
    if cls and type(cls.Post) == "function" then return cls end
    return nil
  end

  local function telegramCallback(chatId)
    return function(success, data, content, result)
      local okResponse = false
      local reason = nil
      if type(data) == "table" then
        okResponse = data.ok == true
        reason = data.description
      else
        local body = tostring(data or "")
        if body == "" then body = tostring(content or "") end
        if body == "" then body = tostring(result or "") end
        okResponse = body:find('"ok"%s*:%s*true') ~= nil
        reason = body:match('"description"%s*:%s*"([^"]*)"') or tostring(result or "unknown")
      end
      if okResponse then
        print(string.format("[RAPZHANG] Telegram %s OK", chatId))
      else
        print(string.format("[RAPZHANG] Telegram %s failed: %s", chatId, tostring(reason or "unknown")))
      end
    end
  end

  local function postTelegram(http, url, body, callback)
    local headers = {["Content-Type"] = "application/x-www-form-urlencoded"}
    local isClass = rawget(http, "__inner_impl") ~= nil
    local ok, indexOrError
    if not isClass and type(http.AddTimerOnce) == "function" then
      ok, indexOrError = pcall(function()
        return http:Post(url, headers, body, nil, callback, 30)
      end)
    else
      ok, indexOrError = pcall(function()
        return http:Post(url, headers, body, nil, callback)
      end)
    end
    if not ok then
      print("[RAPZHANG] Telegram transport error: " .. tostring(indexOrError))
      return false
    end
    if tonumber(indexOrError) == 0 then
      print("[RAPZHANG] Telegram transport unavailable (HTTP wrapper not ready)")
      return false
    end
    return true
  end

  local function sendToTargets(text)
    local rootCfg = _G.RapzhangConfig or {}
    if rootCfg.AutoFeedbackEnabled ~= true then return false end
    local cfg = rootCfg.AutoFeedbackConfig or {}
    local token = cfg.BotToken
    if token == nil or token == "" then return false end
    local http = getHttp()
    if not http then
      print("[RAPZHANG] Telegram transport unavailable")
      return false
    end
    local sent = false
    for _, target in ipairs(cfg.Targets or {}) do
      local chatId = type(target) == "table" and tostring(target.chat_id or "") or ""
      if chatId:match("^%-100%d+$") then
        local url = "https://api.telegram.org/bot" .. token .. "/sendMessage"
        local body = "chat_id=" .. urlEncode(chatId)
          .. "&text=" .. urlEncode(text)
          .. "&parse_mode=HTML&disable_web_page_preview=true"
        if postTelegram(http, url, body, telegramCallback(chatId)) then
          sent = true
        end
      end
    end
    return sent
  end

  local function sourceList()
    local sources = {}
    local br = rawget(_G, "BP_STRUCT_BattleResultData")
    if type(br) == "table" then sources[#sources + 1] = br end

    local sub = nil
    pcall(function()
      if _G.SubsystemMgr and _G.SubsystemMgr.Get then
        sub = _G.SubsystemMgr:Get("BattleResultSubSystem")
      end
    end)
    if sub then
      pcall(function()
        if sub.GetBattleResultData then
          local data = sub:GetBattleResultData()
          if type(data) == "table" then sources[#sources + 1] = data end
        end
      end)
      pcall(function()
        if sub.GetResultProcessLogic then
          local logic = sub:GetResultProcessLogic("BattleResultDataLogic")
          if logic and type(logic.GetBattleResultData) == "function" then
            local data = logic:GetBattleResultData()
            if type(data) == "table" then sources[#sources + 1] = data end
          end
        end
      end)
    end

    local ui = rawget(_G, "BattleResultUI")
    if type(ui) == "table" then
      sources[#sources + 1] = ui
      local back = g(ui, "result_back")
      if type(back) == "table" then sources[#sources + 1] = back end
    end

    local like = mod("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
    if like and type(like.GetMyPlayerState) == "function" then
      local ok, ps = pcall(like.GetMyPlayerState)
      if ok and ps ~= nil then sources[#sources + 1] = ps end
    end
    return sources, br
  end

  local function resultScore(t)
    if t == nil then return -1 end
    local score = 0
    if g(t, "TeammateList") or g(t, "BP_ARRAY_TeammateList") then score = score + 4 end
    if g(t, "person_rank") or g(t, "team_rank") then score = score + 2 end
    if g(t, "rating") or g(t, "BP_STRUCT_BTRating") then score = score + 2 end
    if g(t, "battle_id") or g(t, "Reason") then score = score + 1 end
    return score
  end

  local function chooseResult(sources)
    local best, bestScore = nil, -2
    for _, src in ipairs(sources) do
      local score = resultScore(src)
      if score > bestScore then
        best = src
        bestScore = score
      end
    end
    return best
  end

  local function findSelf(result, sources)
    local list = g(result, "TeammateList") or g(result, "BP_ARRAY_TeammateList")
    if type(list) ~= "table" then list = {} end
    local myUID = currentUID()
    local myName = g(result, "BP_myname") or rawget(_G, "BP_myname") or displayName()
    local selfTm = nil
    for _, tm in ipairs(list) do
      if type(tm) == "table" then
        local uid = g(tm, "UID") or g(tm, "uid")
        local name = g(tm, "Name") or g(tm, "name")
        if (myUID ~= nil and uid ~= nil and tostring(uid) == tostring(myUID))
            or (myName ~= nil and name ~= nil and tostring(name) == tostring(myName)) then
          selfTm = tm
          break
        end
      end
    end
    if selfTm == nil and #list == 1 then selfTm = list[1] end
    return selfTm, myUID, myName, list
  end

  local function resolveMatchID(sources, fallback)
    local id = valFrom(sources, "battle_id", "battleId", "match_id", "matchID", "GameID", "game_id")
    if id == nil or tostring(id) == "0" or tostring(id) == "" then
      local complaint = mod("client.logic.battle.logic_complaint")
      if complaint and type(complaint.GetBattleID) == "function" then
        local ok, value = pcall(complaint.GetBattleID)
        if ok and value ~= nil and tostring(value) ~= "0" then id = value end
      end
    end
    if id == nil or tostring(id) == "0" or tostring(id) == "" then
      id = rawget(_G, "g_game_id")
    end
    if id == nil or tostring(id) == "0" or tostring(id) == "" then
      id = fallback
    end
    if id == nil or tostring(id) == "0" or tostring(id) == "" then
      id = os.time()
    end
    if type(id) == "number" then
      return string.format("%.0f", id)
    end
    return tostring(id)
  end

  local function resolveMap(sources, subMode)
    local map = nil
    local util = mod("GameLua.Mod.BaseMod.Client.BattleResult.BattleResultUtil")
    if util and type(util.GetMapCfg) == "function" and subMode then
      local ok, cfg = pcall(util.GetMapCfg, subMode)
      if ok and type(cfg) == "table" then
        map = cfg.MapName or cfg.Name or cfg.MapNameInternal
      end
    end
    if (map == nil or map == "") and subMode then
      local modeCfg = tableData("BTMode", subMode)
      if modeCfg then
        if modeCfg.MapShowId then map = locStr(modeCfg.MapShowId) end
        if (map == nil or map == "") and modeCfg.MapID then
          local mapCfg = tableData("Map", modeCfg.MapID)
          if mapCfg then map = mapCfg.MapName or mapCfg.Name end
        end
      end
    end
    if type(map) == "number" then map = locStr(map) or tostring(map) end
    if map == nil or map == "" then
      map = valFrom(sources, "MapName", "map_name", "Map", "map")
    end
    if map == nil or map == "" then
      local gs = rawget(_G, "GameplayStatics")
      if gs and type(gs.GetCurrentLevelName) == "function" then
        local ok, level = pcall(gs.GetCurrentLevelName, nil, true)
        if ok and level ~= nil and tostring(level) ~= "" then map = tostring(level) end
      end
    end
    if map == nil or map == "" then return "Unknown" end
    return tostring(map)
  end

  local function resolveMode(sources, battleType, subMode)
    local mode = nil
    local util = mod("GameLua.Mod.BaseMod.Client.BattleResult.BattleResultUtil")
    if util and type(util.GetTeamModeName) == "function" and battleType then
      local ok, value = pcall(util.GetTeamModeName, battleType, subMode)
      if ok and value ~= nil and tostring(value) ~= "" then mode = tostring(value) end
    end
    if mode == nil or mode == "" then
      mode = valFrom(sources, "BP_TeamModeName", "ModeName", "mode_name", "GameMode", "game_mode", "Mode", "mode")
    end
    if (mode == nil or mode == "") and subMode then
      local modeCfg = tableData("BTMode", subMode)
      if modeCfg then mode = locStr(modeCfg.ModeName) or modeCfg.ModeName end
    end
    if mode == nil or mode == "" then return "Unknown" end
    if type(mode) == "number" then mode = locStr(mode) or tostring(mode) end
    return tostring(mode):gsub("^%s+", ""):gsub("%s+$", "")
  end

  local function resolvePerspective(subMode, battleType)
    local fpp = nil
    local modeCfg = tableData("BTMode", subMode)
    if modeCfg and modeCfg.IsFpp ~= nil then
      fpp = modeCfg.IsFpp == true or tonumber(modeCfg.IsFpp) == 1
    end
    if fpp == nil then
      local gd = mod("GameLua.GameCore.Data.GameplayData")
      if gd and type(gd.GetGameState) == "function" then
        local ok, gs = pcall(gd.GetGameState)
        if ok and gs then fpp = g(gs, "IsFPPGameMode") == true end
      end
    end
    if fpp == nil and battleType then
      fpp = battleType == 401 or battleType == 402 or battleType == 403
    end
    return fpp == true and "FPP" or "TPP"
  end

  local function buildFeedback(fallbackMatchID)
    local sources, br = sourceList()
    local result = chooseResult(sources)
    local selfTm, myUID, myName, teamList = findSelf(result, sources)
    local d = {}
    d.sources = sources
    d.result = result
    d.teamList = teamList
    d.myUID = g(selfTm, "UID") or myUID
    d.reporterName = displayName()
    d.myName = teammateDisplayName(selfTm, d.myUID) or cleanNameText(myName)
      or cleanNameText(d.reporterName)
    if d.myName == nil or nameLooksMasked(d.myName) then
      local mine = cleanNameText(d.reporterName)
      if mine and not nameLooksMasked(mine) then d.myName = mine end
    end
    d.reporterUIDMasked = maskUID(d.myUID)
    d.variant = detectGameVariant()
    d.region = detectRegion()
    d.clientVersion = clientVersion()
    local device = detectDevice()
    d.devicePlatform = device.platform
    d.appArch = device.arch
    d.deviceModel = device.model
    d.deviceOS = device.os
    d.active = activeFeatureText()
    d.logged = os.date("%Y-%m-%d %H:%M:%S")
    d.matchID = resolveMatchID(sources, fallbackMatchID)

    d.battleType = firstNumber(valFrom(sources, "battle_type", "battleType", "BATTLETYPE_MODE"))
    d.subMode = firstNumber(valFrom(sources, "sub_mode", "subMode", "ModeId", "mode_id"))
    d.mode = resolveMode(sources, d.battleType, d.subMode)
    d.isTeam = firstBool(g(result, "is_team_result"), g(result, "IsTeamResult"))
    if d.isTeam == nil then
      d.isTeam = #teamList > 1
    end

    local reason = string.lower(tostring(valFrom(sources, "Reason", "reason", "ResultType", "result_type") or ""))
    d.reason = reason
    d.personRank = firstNumber(g(result, "person_rank"), valFrom(sources, "person_rank", "Placement", "placement"))
    d.teamRank = firstNumber(g(result, "team_rank"), valFrom(sources, "team_rank", "TeamPlacement", "team_placement"))
    d.totalPlayers = firstNumber(g(result, "TotalPlayerCount"), g(result, "total_player_count"))
    d.totalTeams = firstNumber(g(result, "TotalTeamCount"), g(result, "total_team_count"))
    d.remainingPlayers = firstNumber(g(result, "RemainingPlayerCount"), g(result, "remaining_player_count"))
    d.remainingTeams = firstNumber(g(result, "RemainingTeamCount"), g(result, "remaining_team_count"))
    d.isSolo = firstBool(g(result, "IsSolo"), g(result, "is_solo"))
    if d.isSolo == nil then d.isSolo = d.isTeam == false end

    d.kills = firstNumber(
      g(selfTm, "Kill"), g(selfTm, "Kills"),
      valFrom(sources, "BP_mykill", "mykill", "Kills", "kills")
    ) or 0
    d.damage = firstNumber(
      g(selfTm, "DamageAmount"), g(selfTm, "TotalDamage"),
      valFrom(sources, "BP_mydamage", "mydamage", "DamageAmount", "TotalDamage", "Damage", "damage")
    )
    d.assists = firstNumber(
      g(selfTm, "AssistNum"), g(selfTm, "Assists"), g(selfTm, "AssistCount"),
      valFrom(sources, "BP_myassist", "myassist", "AssistNum", "Assists", "AssistCount")
    )
    d.knocks = firstNumber(
      g(selfTm, "KnockDownCount"), g(selfTm, "KnockdownCount"), g(selfTm, "Knockouts"),
      g(selfTm, "KnockNum"), g(selfTm, "KnockNumber"), g(selfTm, "KnockDowns"),
      valFrom(sources, "KnockDownCount", "KnockdownCount", "Knockouts", "KnockNum", "KnockNumber", "KnockDowns", "knockdowns", "BP_myknockout", "myknockout")
    )
    d.headshots = firstNumber(
      g(selfTm, "HeadShotNum"), g(selfTm, "HeadshotNum"), g(selfTm, "Headshots"),
      valFrom(sources, "HeadShotNum", "HeadshotNum", "Headshots", "HeadShotCount")
    )
    d.revives = firstNumber(
      g(selfTm, "rescueTimes"), g(selfTm, "Revives"), g(selfTm, "RescueCount"),
      valFrom(sources, "rescueTimes", "Revives", "RescueCount", "revives")
    )
    d.survival = firstNumber(
      g(selfTm, "surviveTime"), g(selfTm, "SurvivalTime"), g(selfTm, "SurviveTime"),
      valFrom(sources, "BP_MySurviveTime_f", "SurviveTime", "survival_time", "BP_MySurviveTime")
    )
    d.distance = firstNumber(
      g(selfTm, "travelDistance"), g(selfTm, "TravelDistance"),
      valFrom(sources, "travelDistance", "TravelDistance", "Distance", "distance")
    )
    d.healing = firstNumber(
      g(selfTm, "HealAmount"), g(selfTm, "Healing"),
      valFrom(sources, "HealAmount", "Healing", "heal_amount")
    )
    d.score = firstNumber(
      g(selfTm, "FinalScore"), g(selfTm, "FinalScore_f"), g(selfTm, "Score"),
      valFrom(sources, "FinalScore", "FinalScore_f", "Score", "score")
    )
    d.isMVP = firstBool(g(selfTm, "IsMVP"), valFrom(sources, "IsMVP", "isMVP")) == true

    local shotsFired = firstNumber(g(result, "ShootWeaponShotNum"), valFrom(sources, "ShootWeaponShotNum"))
    local shotsHit = firstNumber(g(result, "ShootWeaponShotAndHitPlayerNum"), valFrom(sources, "ShootWeaponShotAndHitPlayerNum"))
    d.shotsFired = shotsFired
    d.shotsHit = shotsHit
    if shotsFired and shotsFired > 0 and shotsHit then
      d.accuracy = shotsHit / shotsFired * 100
    end
    d.healTimes = firstNumber(g(result, "HealTimes"), valFrom(sources, "HealTimes"))
    d.vehicles = firstNumber(g(result, "destroyVehicleNum"), valFrom(sources, "destroyVehicleNum"))
    d.exp = firstNumber(g(result, "add_exp"), g(result, "char_add_exp"), valFrom(sources, "add_exp", "char_add_exp"))
    d.gold = firstNumber(g(result, "add_gold"), valFrom(sources, "add_gold"))
    d.seasonCoin = firstNumber(g(result, "seasonGold"), g(g(result, "SeasonCoinInfo"), "add_coin_cnt"))
    d.careerScore = firstNumber(g(result, "careerScore"))

    local headshotRatio = firstNumber(g(result, "HeadShotRatio"), valFrom(sources, "HeadShotRatio"))
    if headshotRatio then
      if headshotRatio <= 1 then headshotRatio = headshotRatio * 100 end
      d.headshotRate = headshotRatio
    end

    local rating = g(result, "rating") or g(result, "BP_STRUCT_BTRating")
    if type(rating) ~= "table" then
      for _, src in ipairs(sources) do
        local candidate = g(src, "rating") or g(src, "BP_STRUCT_BTRating")
        if type(candidate) == "table" then
          rating = candidate
          break
        end
      end
    end
    rating = rating or {}

    -- DataMgr.season_id adalah season yang sedang dipakai client (sumber
    -- yang sama dengan kartu profil/rank). Field SeasonNumber dari battle
    -- result bisa membawa nomor lain (internal/server), jadi jangan
    -- diprioritaskan di atas season client.
    d.season = firstNumber(
      rankSeason(),
      g(result, "SeasonNumber"), g(result, "seasonNumber")
    )
    d.seasonName = seasonLabel(d.season)

    local urTables = collectURTables(sources, result, rating)
    local urMode = modeLooksUR(d.mode, sources, d.subMode)
    if not urMode then
      -- 1..25 and 1001..1025 are not classic segments; they identify UR even
      -- when the result does not expose the mode name.
      local urSegment = firstNumber(g(rating, "new_segment"), g(rating, "newSegment"))
      if urSegment and urTierFromSegment(urSegment) ~= nil then urMode = true end
    end
    local urData = nil
    if urMode or #urTables > 0 then
      urData = extractUR(sources, result, rating, urMode)
    end
    if not urMode and urData ~= nil then urMode = true end
    d.urMatch = urMode
    if urMode then
      -- Ultimate Royale has its own ladder; do not feed its segment into the
      -- classic rank table, and do not label classic points as UR points.
      d.ur = urData
    else
      d.rankPoints = firstNumber(
        g(rating, "rank_rating"), g(rating, "rankRating"),
        valFrom(sources, "rank_rating", "rankRating")
      )
      d.rankDelta = firstNumber(
        g(rating, "change_rank_rating"), g(rating, "changeRankRating")
      )
      d.oldSegment = firstNumber(g(rating, "old_segment"), g(rating, "oldSegment"))
      d.newSegment = firstNumber(g(rating, "new_segment"), g(rating, "newSegment"))
      d.killRating = firstNumber(g(rating, "kill_rating"), g(rating, "killRating"))
      d.killDelta = firstNumber(g(rating, "change_kill_rating"), g(rating, "changeKillRating"))
      d.winRating = firstNumber(g(rating, "win_rating"), g(rating, "winRating"))
      d.winDelta = firstNumber(g(rating, "change_win_rating"), g(rating, "changeWinRating"))
      if d.rankPoints and d.rankDelta then
        d.oldPoints = math.max(0, d.rankPoints - d.rankDelta)
      end
      d.newRankName = rankLabel(d.newSegment, d.season)
      d.oldRankName = rankLabel(d.oldSegment, d.season)
      if d.newRankName and d.oldRankName and d.newRankName ~= d.oldRankName then
        d.rankTier = d.oldRankName .. " → " .. d.newRankName
      else
        d.rankTier = d.newRankName or d.oldRankName
      end
    end

    local protections = {}
    local protect = g(result, "BP_STRUCT_BTRatingProtect") or g(result, "rating_protect")
    if type(protect) == "table" then
      local protectType = g(protect, "protect_type")
      if protectType ~= nil and tostring(protectType) ~= "" and tostring(protectType) ~= "0" then
        protections[#protections + 1] = tostring(protectType)
      end
      local protectValue = firstNumber(g(protect, "value"))
      if protectValue and protectValue > 0 then
        protections[#protections + 1] = "value " .. fmtInt(protectValue)
      end
    end
    if g(result, "segment_protect") == true then protections[#protections + 1] = "Segment protect" end
    if g(result, "is_rank_protect") == true then protections[#protections + 1] = "Rank protect" end
    if g(result, "is_time_card_protect") == true or g(result, "is_times_card_protect") == true then
      protections[#protections + 1] = "Time card"
    end
    if g(result, "is_activity_protect") == true then protections[#protections + 1] = "Activity" end
    if g(result, "is_player_return_protect") == true then protections[#protections + 1] = "Return protect" end
    if g(result, "double_rating") == true then protections[#protections + 1] = "Double rating" end
    if #protections > 0 then d.protection = table.concat(protections, ", ") end

    local personRank = d.personRank
    local teamRank = d.teamRank
    d.teamWin = d.isTeam == true and teamRank == 1
    d.win = reason == "win" or reason == "winner" or reason == "chicken"
    if not d.win and d.isTeam ~= true and personRank == 1
        and (reason == "" or reason == "win" or reason == "winner") then
      d.win = true
    end
    if not d.win and d.teamWin then d.win = true end

    if d.teamWin then
      d.statusHtml = "<b>TEAM WIN</b> 🏆"
    elseif d.win then
      d.statusHtml = "<b>WIN</b> 🏆"
    elseif reason == "dead" then
      d.statusHtml = "<b>ELIMINATED</b>"
    elseif reason ~= "" then
      d.statusHtml = "<b>" .. esc(string.upper(reason)) .. "</b>"
    else
      d.statusHtml = "<b>FINISHED</b>"
    end

    d.map = resolveMap(sources, d.subMode)
    d.perspective = resolvePerspective(d.subMode, d.battleType)
    return d
  end

  local function formatFeedback(d)
    local lines = {}
    local function add(line) lines[#lines + 1] = line end
    local function bullet(label, value)
      if value ~= nil and tostring(value) ~= "" then
        add("• " .. label .. ": " .. tostring(value))
      end
    end

    add("🎯 <b>RAPZHANG MATCH REPORT</b>")
    add("━━━━━━━━━━━━━━━━━━")
    bullet("Player", "<code>" .. esc(clip(maskPlayerName(d.myName) or "Unknown", 48)) .. "</code>")
    bullet("UID", "<code>" .. esc(d.reporterUIDMasked or "unknown") .. "</code>")
    bullet("Variant", esc(d.variant or "PUBGM: Unknown"))
    if (d.variant == nil or d.variant == "PUBGM: Unknown") and d.region then
      bullet("Region", esc(d.region))
    end
    bullet("Client", esc(d.clientVersion))
    add("")
    add("📱 <b>DEVICE</b>")
    bullet("Platform", esc(d.devicePlatform or "Unknown"))
    bullet("App arch", "<b>" .. esc(d.appArch or "Unknown") .. "</b>")
    if d.deviceModel or d.deviceOS then
      local deviceParts = {}
      if d.deviceModel then deviceParts[#deviceParts + 1] = esc(d.deviceModel) end
      if d.deviceOS then deviceParts[#deviceParts + 1] = esc(d.deviceOS) end
      bullet("Device", table.concat(deviceParts, " · "))
    end
    add("")
    add("🏁 <b>RESULT</b>")
    bullet("Status", d.statusHtml or "<b>FINISHED</b>")
    if d.isTeam == true then
      local denom = d.totalTeams and d.totalTeams > 0 and (" / " .. fmtCount(d.totalTeams, "team")) or ""
      bullet("Team placement", "<b>#" .. (fmtInt(d.teamRank) or "?") .. "</b>" .. denom)
      local pdenom = d.totalPlayers and d.totalPlayers > 0 and (" / " .. fmtCount(d.totalPlayers, "player")) or ""
      bullet("Personal rank", "<b>#" .. (fmtInt(d.personRank) or "?") .. "</b>" .. pdenom)
    else
      local denom = d.totalPlayers and d.totalPlayers > 0 and (" / " .. fmtCount(d.totalPlayers, "player")) or ""
      bullet("Placement", "<b>#" .. (fmtInt(d.personRank) or "?") .. "</b>" .. denom)
    end
    if d.remainingPlayers ~= nil or d.remainingTeams ~= nil then
      local parts = {}
      if d.remainingPlayers ~= nil then parts[#parts + 1] = fmtCount(d.remainingPlayers, "player") end
      if d.remainingTeams ~= nil then parts[#parts + 1] = fmtCount(d.remainingTeams, "team") end
      bullet("Remaining", table.concat(parts, " / "))
    end
    bullet("Map", esc(d.map))
    bullet("Mode", esc(d.mode))
    bullet("View", esc(d.perspective))

    add("")
    add("📊 <b>COMBAT</b>")
    local combatStart = #lines + 1
    bullet("Kills", fmtInt(d.kills))
    bullet("Damage", fmtInt(d.damage))
    bullet("Assists", fmtInt(d.assists))
    bullet("Knocks", fmtInt(d.knocks))
    bullet("Headshots", fmtInt(d.headshots))
    bullet("Headshot rate", fmtPercent(d.headshotRate))
    bullet("Revives", fmtInt(d.revives))
    if d.shotsFired ~= nil or d.shotsHit ~= nil then
      local shots = (fmtInt(d.shotsHit) or "0") .. " / " .. (fmtInt(d.shotsFired) or "0")
      if d.accuracy then shots = shots .. " (" .. fmtPercent(d.accuracy) .. ")" end
      bullet("Shots hit", shots)
    end
    bullet("Survival", fmtDuration(d.survival))
    bullet("Distance", fmtDistance(d.distance))
    bullet("Healing", fmtInt(d.healing))
    bullet("Heals used", fmtInt(d.healTimes))
    bullet("Vehicles destroyed", fmtInt(d.vehicles))
    local scoreText = fmtNum(d.score, 1)
    if scoreText and d.isMVP then scoreText = scoreText .. " · MVP" end
    bullet("Score", scoreText)
    if #lines < combatStart then add("• No combat data available") end

    local rewardParts = {}
    if d.exp and d.exp > 0 then rewardParts[#rewardParts + 1] = "EXP +" .. fmtInt(d.exp) end
    if d.gold and d.gold > 0 then rewardParts[#rewardParts + 1] = "BP +" .. fmtInt(d.gold) end
    if d.seasonCoin and d.seasonCoin > 0 then rewardParts[#rewardParts + 1] = "Season coin +" .. fmtInt(d.seasonCoin) end
    if d.careerScore and d.careerScore > 0 then rewardParts[#rewardParts + 1] = "Career +" .. fmtInt(d.careerScore) end
    if #rewardParts > 0 then
      add("")
      add("💰 <b>REWARDS</b>")
      add("• " .. table.concat(rewardParts, " · "))
    end

    local hasRank = d.rankTier ~= nil or d.rankPoints ~= nil
      or d.killRating ~= nil or d.winRating ~= nil
      or (d.protection ~= nil and not d.urMatch)
    if hasRank or d.ur == nil then
      add("")
      add("🏅 <b>RANK</b>")
      bullet("Tier", esc(d.rankTier))
      if d.rankPoints ~= nil then
        local points
        if d.oldPoints ~= nil then
          points = fmtInt(d.oldPoints) .. " → <b>" .. fmtInt(d.rankPoints) .. "</b>"
        else
          points = "<b>" .. fmtInt(d.rankPoints) .. "</b>"
        end
        if d.rankDelta ~= nil and d.rankDelta ~= 0 then
          points = points .. " (" .. fmtSigned(d.rankDelta) .. ")"
        end
        bullet("Points", points)
      end
      local ratingParts = {}
      if d.killRating ~= nil then
        local part = "Kill " .. fmtInt(d.killRating)
        if d.killDelta ~= nil then part = part .. " (" .. fmtSigned(d.killDelta) .. ")" end
        ratingParts[#ratingParts + 1] = part
      end
      if d.winRating ~= nil then
        local part = "Win " .. fmtInt(d.winRating)
        if d.winDelta ~= nil then part = part .. " (" .. fmtSigned(d.winDelta) .. ")" end
        ratingParts[#ratingParts + 1] = part
      end
      if #ratingParts > 0 then bullet("Rating", esc(table.concat(ratingParts, " · "))) end
      if hasRank then
        bullet("Protection", esc(d.protection))
        bullet("Season", esc(d.seasonName))
      elseif d.urMatch then
        add("• Ultimate Royale data unavailable")
      else
        add("• No ranked data (unranked match)")
      end
    end

    if d.ur then
      add("")
      add("🎯 <b>ULTIMATE ROYALE</b>")
      bullet("Tier", esc(d.ur.tierLabel))
      if d.ur.points ~= nil then
        local points
        if d.ur.oldPoints ~= nil then
          points = fmtInt(d.ur.oldPoints) .. " → <b>" .. fmtInt(d.ur.points) .. "</b>"
        else
          points = "<b>" .. fmtInt(d.ur.points) .. "</b>"
        end
        if d.ur.delta ~= nil and d.ur.delta ~= 0 then
          points = points .. " (" .. fmtSigned(d.ur.delta) .. ")"
        end
        bullet("Points", points)
      end
      bullet("Protection", esc(d.protection))
      bullet("Season", esc(d.seasonName))
    end

    if d.teamList and #d.teamList > 1 then
      local totalKills, totalAssists, totalDamage = 0, 0, 0
      for _, tm in ipairs(d.teamList) do
        totalKills = totalKills + (tonumber(g(tm, "Kill")) or 0)
        totalAssists = totalAssists + (tonumber(g(tm, "AssistNum")) or 0)
        totalDamage = totalDamage + (tonumber(g(tm, "DamageAmount")) or 0)
      end
      add("")
      add(string.format("👥 <b>SQUAD</b> (%d players · %sK · %sA · %sD)",
        #d.teamList, fmtInt(totalKills), fmtInt(totalAssists), fmtInt(totalDamage)))
      local shown = 0
      for _, tm in ipairs(d.teamList) do
        if shown >= 4 then break end
        local rawName = teammateDisplayName(tm, d.myUID) or "Unknown"
        local name = esc(clip(maskPlayerName(rawName) or rawName, 48))
        local uid = g(tm, "UID")
        local isSelf = (d.myUID ~= nil and uid ~= nil and tostring(uid) == tostring(d.myUID))
          or (d.myName ~= nil and rawName == tostring(d.myName))
        local kills = tonumber(g(tm, "Kill")) or 0
        local assists = tonumber(g(tm, "AssistNum")) or 0
        local damage = tonumber(g(tm, "DamageAmount")) or 0
        local suffix = isSelf and " <i>(you)</i>" or ""
        if nameLooksMasked(rawName) and uid ~= nil then
          suffix = suffix .. " <i>(UID " .. esc(maskUID(uid)) .. ")</i>"
        end
        local mvp = g(tm, "IsMVP") == true and " · MVP" or ""
        add("• " .. name .. suffix .. " — " .. fmtInt(kills) .. "K / " .. fmtInt(assists) .. "A / " .. fmtInt(damage) .. "D" .. mvp)
        shown = shown + 1
      end
      if #d.teamList > shown then
        add("• +" .. tostring(#d.teamList - shown) .. " more")
      end
    end

    add("")
    add("🧩 <b>SESSION</b>")
    bullet("Match ID", "<code>" .. esc(d.matchID or "-") .. "</code>")
    bullet("Active", esc(d.active or "None"))
    bullet("Reporter", esc(clip(maskPlayerName(d.reporterName) or "Player", 48)) .. " (" .. esc(d.reporterUIDMasked or "unknown") .. ")")
    bullet("Logged", esc(d.logged or ""))

    return trimMessage(table.concat(lines, "\n"))
  end

  local function emit(d)
    local text = formatFeedback(d)
    if not sendToTargets(text) then
      print("[RAPZHANG] Auto feedback: Telegram transport/target unavailable")
    end
  end

  local function formatReport(d, targetName, targetUID, matchID)
    local lines = {}
    local function add(line) lines[#lines + 1] = line end
    local function bullet(label, value)
      if value ~= nil and tostring(value) ~= "" then
        add("• " .. label .. ": " .. tostring(value))
      end
    end
    add("🚨 <b>PLAYER REPORT</b>")
    add("━━━━━━━━━━━━━━━━━━")
    bullet("Target", "<code>" .. esc(clip(maskPlayerName(targetName) or "Unknown", 48)) .. "</code>")
    bullet("UID", "<code>" .. esc(tostring(targetUID or "unknown")) .. "</code>")
    bullet("Match ID", "<code>" .. esc(tostring(matchID or d.matchID or "-")) .. "</code>")
    bullet("Reason", "Cheating")
    add("")
    add("📊 <b>REPORTER</b>")
    bullet("Name", esc(clip(maskPlayerName(d.reporterName) or "Player", 48)))
    bullet("UID", esc(d.reporterUIDMasked or "unknown"))
    bullet("Kills", fmtInt(d.kills))
    if d.ur then
      bullet("Ladder", "Ultimate Royale")
      bullet("Rank", esc(d.ur.tierLabel))
      bullet("Points", fmtInt(d.ur.points))
    else
      bullet("Rank", esc(d.rankTier))
      bullet("Points", fmtInt(d.rankPoints))
    end
    bullet("Mode", esc(d.mode))
    bullet("Time", esc(d.logged or ""))
    return trimMessage(table.concat(lines, "\n"))
  end

  function AF.SendReport(playerName, playerUID, matchID)
    local ok, err = pcall(function()
      local d = buildFeedback(matchID)
      local text = formatReport(d, playerName, playerUID, d.matchID)
      if not sendToTargets(text) then
        print("[RAPZHANG] Player report: Telegram transport/target unavailable")
      end
    end)
    if not ok then print("[RAPZHANG] Player report error: " .. tostring(err)) end
  end

  function AF.Send(kills, rank, segment, matchID)
    local ok, err = pcall(function()
      local d = buildFeedback(matchID)
      if (d.kills == nil or d.kills == 0) and (tonumber(kills) or 0) > 0 then
        d.kills = tonumber(kills)
      end
      local rankArg = tonumber(rank)
      local segmentArg = tonumber(segment)
      -- A UR segment id from the caller is a strong signal even when the
      -- battle result did not expose the mode name.
      if not d.urMatch and segmentArg and urTierFromSegment(segmentArg) ~= nil then
        d.urMatch = true
        d.ur = d.ur or { segment = segmentArg }
      end
      if d.urMatch then
        if (rankArg and rankArg > 0) or (segmentArg and segmentArg > 0) then
          d.ur = d.ur or {}
          if rankArg and rankArg > 0 and (d.ur.points == nil or d.ur.points == 0) then
            d.ur.points = rankArg
          end
          if segmentArg and segmentArg > 0 and (d.ur.segment == nil or d.ur.segment == 0) then
            d.ur.segment = segmentArg
          end
          d.ur = finalizeUR(d.ur)
        end
      else
        if (d.rankPoints == nil or d.rankPoints == 0) and (rankArg or 0) > 0 then
          d.rankPoints = rankArg
        end
        if (d.newSegment == nil or d.newSegment == 0) and (segmentArg or 0) > 0 then
          d.newSegment = segmentArg
          d.newRankName = rankLabel(d.newSegment, d.season)
          d.rankTier = d.newRankName or d.rankTier
        end
      end
      emit(d)
    end)
    if not ok then print("[RAPZHANG] Auto feedback error: " .. tostring(err)) end
  end

  function AF.HandleShowUI(config, params)
    local ui = _G.UIManager
    local inGame = ui and ui.UI_Config_InGame
    local countdown = inGame and inGame.GameOverCountDown_UIBP
    if not countdown or config ~= countdown then return end

    local d = buildFeedback(nil)
    local reason = string.lower(tostring((params and params.Reason) or d.reason or ""))
    local isWin = d.win == true or reason == "win" or reason == "winner" or reason == "chicken"
    local cfg = (_G.RapzhangConfig and _G.RapzhangConfig.AutoFeedbackConfig) or {}
    local sendOnWin = cfg.SendOnWin ~= false
    local sendOnLoss = cfg.SendOnLoss ~= false
    if isWin and not sendOnWin then return end
    if (not isWin) and not sendOnLoss then return end

    local matchID = tostring(d.matchID or "")
    if matchID == "" or matchID == "0" then matchID = tostring(os.time()) end
    if AF._lastMatchSent == matchID then return end
    AF._lastMatchSent = matchID

    if not addTimerOnce(1.5, function() emit(d) end) then
      emit(d)
    end
  end

  function AF.Install()
    if not (_G.RapzhangConfig and _G.RapzhangConfig.AutoFeedbackEnabled == true) then return end
    local ui = _G.UIManager
    if not ui or type(ui.ShowUI) ~= "function" then
      if not AF._installQueued then
        AF._installQueued = true
        addTimerOnce(3.0, function()
          AF._installQueued = false
          AF.Install()
        end)
      end
      return
    end
    if ui._RapzhangAutoTextFeedbackHookedV2 then return end
    local old = ui.ShowUI
    ui.ShowUI = function(config, params, ...)
      local result = old(config, params, ...)
      local current = _G.RapzhangAutoTextFeedback
      if current and type(current.HandleShowUI) == "function" then
        pcall(current.HandleShowUI, config, params)
      end
      return result
    end
    ui._RapzhangAutoTextFeedbackHookedV2 = true
  end

  return AF
end)()
local function UpdateIndependentWallhack(GameplayData, localPlayer)
    -- Wallhack is deliberately independent from ESP/UI state.
    pcall(function()
        if not GameplayData or not Valid(localPlayer) then return end
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then
            allCharacters = GameplayData.GetAllPlayerCharacters() or {}
        elseif GameplayData.GameCharacters then
            for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
        end
        local seen = {}
        local wallOn = _G.RapzhangConfig and _G.RapzhangConfig.ColorBodyNew == true
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local key = GetSafeEnemyKey(enemy)
                seen[key] = true
                _G.RapzhangState.EnemyMarks[key] = _G.RapzhangState.EnemyMarks[key] or { enemy = enemy }
                local markData = _G.RapzhangState.EnemyMarks[key]
                markData.enemy = enemy
                if wallOn then ApplyColorBodyNew(enemy, markData) else UndoColorBodyNew(enemy, markData) end
            end
        end
        for key, markData in pairs(_G.RapzhangState.EnemyMarks or {}) do
            if not seen[key] and not wallOn and markData and markData.enemy then
                UndoColorBodyNew(markData.enemy, markData)
            end
        end
    end)
end

local function ClearIndependentWallhackState()
    local marks = _G.RapzhangState and _G.RapzhangState.EnemyMarks or {}
    for key, markData in pairs(marks) do
        if markData then
            local enemy = markData.enemy
            pcall(function()
                if enemy or markData.ColorNewApplied then
                    UndoColorBodyNew(enemy, markData)
                end
            end)
            markData.enemy = nil
        end
        marks[key] = nil
    end
    -- [MAGIC BULLET] Pastikan PhysAsset dikembalikan & cache dibersihkan.
    if _G.AK_ClearMagicBulletCache then
        pcall(_G.AK_ClearMagicBulletCache)
    end
end

-- ============================================================================
-- [HITBOX ENGINE] Magic Bullet + Headshot (logic ported from premium.lua)
-- Menyimpan geometri collision asli per PhysicsAsset (per bone), lalu
-- mengaplikasikan skala penuh ke elemen pertama Box/Sphere/Sphyl.
-- Magic & Headshot memakai satu hash/state supaya toggle salah satu tidak
-- membatalkan skala fitur lainnya.
--
-- [BATAS SERVER-SIDE]
-- Server tidak pernah menerima PhysicsAsset/geometri hitbox. Yang dikirim
-- client saat menembak hanyalah hasil trace: actor, BoneName, impact point,
-- dan trace start/end. Jadi scale hitbox bekerja karena server menerima
-- BoneName "head"/"neck_01" yang valid, bukan karena server membaca ukuran
-- hitbox. Sebaliknya, HeadDamageMultiplier/BodyDamageMultiplier hanya nilai
-- prediksi lokal: server tetap memakai damage table miliknya, dan selisih
-- prediksi vs hasil server justru menjadi sinyal deteksi. Karena itu fitur
-- Headshot di bawah sengaja TIDAK menyentuh multiplier senjata.
--
-- Catatan: FeatureDynamicVertifyHitBoxScale dan AddIgnoreVerifyShootBigHead
-- adalah mekanisme server untuk skill yang memang membesarkan kepala. Keduanya
-- server-authoritative; client Lua tidak bisa menulisnya ke server. Yang bisa
-- dilakukan client hanya menjaga skala tetap di dalam toleransi BlockBoxScale.
-- ============================================================================
_G.RapzhangHitboxBoneMap = function(headScale, bodyScale, legsScale)
    return {
        ["head"] = headScale, ["neck_01"] = headScale,
        ["pelvis"] = bodyScale, ["spine_01"] = bodyScale,
        ["spine_02"] = bodyScale, ["spine_03"] = bodyScale,
        ["thigh_l"] = legsScale, ["thigh_r"] = legsScale,
        ["calf_l"] = legsScale, ["calf_r"] = legsScale,
        ["foot_l"] = legsScale, ["foot_r"] = legsScale,
    }
end

-- Skala kepala Headshot. 2x aman sampai ping ~500ms; 3x hanya aman di
-- ping 100-200ms (lihat toleransi BlockBoxScale di komentar bawah).
_G.RapzhangHeadshotHeadScale = 2.0
-- Batas atas skala semua hitbox (head/body/legs). DS LagCompensationSubSystem
-- memberi toleransi BlockBoxScale 3x/2.5x/2x/1.5x tergantung ping shooter;
-- di atas 3x, SwitchHitOutCollisionBox (PunishThresHold=10) mencatat
-- pelanggaran. 5x/25x hampir pasti kena.
_G.RapzhangMaxHitboxScale = 3.0
_G.RapzhangMaxHeadScale = 3.0

-- forTicker=true: dipakai ticker Headshot yang berjalan walau ESP OFF.
-- Saat ESP OFF, skala Magic diabaikan agar dua fitur tidak saling menimpa.
_G.RapzhangGetHitboxScale = function(forTicker)
    local cfg = _G.RapzhangConfig or {}
    local data = (_G.RapzhangState and _G.RapzhangState.CustomTextData) or {}
    local magicOn = cfg.CustomMagicBullet == true
    local headshotOn = cfg.Headshot == true
    if forTicker and magicOn and cfg.EspLoai9 ~= true then
        magicOn = false
    end
    if not magicOn and not headshotOn then
        return "OFF", 1.0, 1.0, 1.0
    end
    local head, body, legs = 1.0, 1.0, 1.0
    local maxScale = tonumber(_G.RapzhangMaxHitboxScale) or 3.0
    if magicOn then
        head = math.max(1.0, math.min(maxScale, tonumber(data.MagicHead) or 1.0))
        body = math.max(1.0, math.min(maxScale, tonumber(data.MagicBody) or 1.0))
        legs = math.max(1.0, math.min(maxScale, tonumber(data.MagicLegs) or 1.0))
    end
    if headshotOn then
        -- max(), bukan perkalian: Magic 3x + Headshot 2x tidak boleh menjadi 6x.
        -- Server hanya melihat BoneName, tetapi hitbox di luar toleransi
        -- BlockBoxScale membuat SwitchHitOutCollisionBox mencatat pelanggaran.
        head = math.max(head, tonumber(_G.RapzhangHeadshotHeadScale) or 2.0)
    end
    local maxHead = tonumber(_G.RapzhangMaxHeadScale) or maxScale
    head = math.max(1.0, math.min(maxHead, head))
    return string.format("MB_%.2f_%.2f_%.2f", head, body, legs), head, body, legs
end

_G.RapzhangInvalidateHitboxMarks = function()
    local marks = _G.RapzhangState and _G.RapzhangState.EnemyMarks
    if not marks then return end
    for _, markData in pairs(marks) do
        if markData then
            markData.MagicBulletHash = nil
            markData.MagicTargetID = nil
        end
    end
end

-- forceRestore=true saat toggle berubah: cache dibersihkan supaya skala lama
-- tidak tertinggal ketika fitur lain (atau semuanya) dimatikan.
_G.RapzhangHitboxConfigChanged = function(forceRestore)
    pcall(_G.RapzhangInvalidateHitboxMarks)
    local cfg = _G.RapzhangConfig or {}
    if forceRestore or (cfg.CustomMagicBullet ~= true and cfg.Headshot ~= true) then
        if _G.AK_ClearMagicBulletCache then
            pcall(_G.AK_ClearMagicBulletCache)
        end
    end
end

_G.RapzhangApplyHitbox = function(mesh, hash, headScale, bodyScale, legsScale, stateKey)
    if hash == nil or hash == "OFF" then return false end
    if not mesh or not slua or not slua.isValid(mesh) then return false end

    local overrideValid = slua.isValid(mesh.PhysicsAssetOverride)
    local phys = mesh.PhysicsAssetOverride
    if not overrideValid and mesh.SkeletalMesh then
        phys = mesh.SkeletalMesh.PhysicsAsset
    end
    if not slua.isValid(phys) or not phys.SkeletalBodySetups then return false end

    local physName = "DefaultPhys"
    pcall(function()
        if type(phys.GetName) == "function" then physName = phys:GetName() end
    end)
    physName = tostring(physName)

    _G.AK_ModdedPhysAssets = _G.AK_ModdedPhysAssets or {}
    _G.AK_OrigHitboxes = _G.AK_OrigHitboxes or {}
    local orig = _G.AK_OrigHitboxes[physName]
    if not orig then
        orig = {}
        _G.AK_OrigHitboxes[physName] = orig
    end

    local changed = false
    if _G.AK_ModdedPhysAssets[physName] ~= hash then
        local maxScale = tonumber(_G.RapzhangMaxHitboxScale) or 3.0
        local scales = _G.RapzhangHitboxBoneMap(
            math.max(1.0, math.min(tonumber(_G.RapzhangMaxHeadScale) or maxScale, tonumber(headScale) or 1.0)),
            math.max(1.0, math.min(maxScale, tonumber(bodyScale) or 1.0)),
            math.max(1.0, math.min(maxScale, tonumber(legsScale) or 1.0))
        )

        local setups = phys.SkeletalBodySetups
        local count = 0
        if type(setups.Num) == "function" then count = setups:Num() else count = #setups end
        local limit = math.min(count, 50)

        for i = 1, limit do
            local bodySetup = nil
            pcall(function()
                if type(setups.Get) == "function" then bodySetup = setups:Get(i - 1) else bodySetup = setups[i] end
            end)
            if bodySetup and slua.isValid(bodySetup) then
                local lowerBone = string.lower(tostring(bodySetup.BoneName))
                local boneKey = nil
                for key in pairs(scales) do
                    if string.find(lowerBone, key, 1, true) then boneKey = key break end
                end

                if boneKey then
                    local scale = scales[boneKey]
                    local agg = bodySetup.AggGeom
                    local arrays = {
                        Box = (agg and agg.BoxElems) or bodySetup.BoxElems,
                        Sphere = (agg and agg.SphereElems) or bodySetup.SphereElems,
                        Sphyl = (agg and agg.SphylElems) or bodySetup.SphylElems,
                    }

                    local cache = orig[boneKey]
                    if not cache then
                        cache = { Arrays = {} }
                        orig[boneKey] = cache
                    end
                    cache.Setup = bodySetup

                    for kind, arr in pairs(arrays) do
                        local elem = nil
                        pcall(function()
                            if arr and type(arr.Num) == "function" and arr:Num() > 0 then
                                elem = type(arr.Get) == "function" and arr:Get(0) or arr[1]
                            elseif arr and type(arr) == "table" and #arr > 0 then
                                elem = arr[1]
                            end
                        end)

                        if elem then
                            cache.Arrays[kind] = arr
                            if kind == "Box" then
                                if not cache.Box then cache.Box = { X = elem.X, Y = elem.Y, Z = elem.Z } end
                                elem.X = cache.Box.X * scale
                                elem.Y = cache.Box.Y * scale
                                elem.Z = cache.Box.Z * scale
                            elseif kind == "Sphere" then
                                if not cache.Sphere then cache.Sphere = { Radius = elem.Radius } end
                                elem.Radius = cache.Sphere.Radius * scale
                            else
                                if not cache.Sphyl then cache.Sphyl = { Radius = elem.Radius, Length = elem.Length } end
                                elem.Radius = cache.Sphyl.Radius * scale
                                elem.Length = cache.Sphyl.Length * scale
                            end

                            if type(arr.Set) == "function" then arr:Set(0, elem) else arr[1] = elem end
                            if agg then
                                agg[kind .. "Elems"] = arr
                                bodySetup.AggGeom = agg
                            else
                                bodySetup[kind .. "Elems"] = arr
                            end
                        end
                    end
                end
            end
        end

        _G.AK_ModdedPhysAssets[physName] = hash
        changed = true
    end

    -- Refresh physics state for every mesh that has not seen this hash yet
    -- (new enemy or config change), not just the first mesh sharing the asset.
    _G.RapzhangMeshHitboxState = _G.RapzhangMeshHitboxState or {}
    local meshState = stateKey and _G.RapzhangMeshHitboxState[stateKey] or nil
    local meshHash = meshState and meshState.hash or nil
    local needRefresh = changed or not overrideValid or (stateKey ~= nil and meshHash ~= hash)

    if needRefresh then
        pcall(function()
            if type(mesh.SetPhysicsAsset) == "function" then mesh:SetPhysicsAsset(phys) end
            mesh.PhysicsAssetOverride = phys
            if type(mesh.RecreatePhysicsState) == "function" then
                mesh:RecreatePhysicsState()
            end
        end)
        if stateKey ~= nil then
            _G.RapzhangMeshHitboxState[stateKey] = { hash = hash, mesh = mesh }
        end
    end

    return true, physName
end

-- ============================================================================
-- [HITBOX CACHE CLEARER]
-- Mengembalikan PhysicsAsset ke geometri asli & menghapus semua jejak cache.
-- Dipanggil saat: keluar match, mati, kembali ke lobby, atau toggle OFF.
-- ============================================================================
_G.AK_ClearMagicBulletCache = function()
    pcall(function()
        local orig = _G.AK_OrigHitboxes
        if orig then
            for physName, bones in pairs(orig) do
                for _, cache in pairs(bones) do
                    local bodySetup = cache.Setup
                    if bodySetup and slua.isValid(bodySetup) then
                        local agg = bodySetup.AggGeom
                        for kind, arr in pairs(cache.Arrays or {}) do
                            local data = cache[kind]
                            if arr and data then
                                local elem = nil
                                pcall(function()
                                    if type(arr.Num) == "function" and arr:Num() > 0 then
                                        elem = type(arr.Get) == "function" and arr:Get(0) or arr[1]
                                    elseif type(arr) == "table" and #arr > 0 then
                                        elem = arr[1]
                                    end
                                end)
                                if elem then
                                    if kind == "Box" then
                                        elem.X, elem.Y, elem.Z = data.X, data.Y, data.Z
                                    elseif kind == "Sphere" then
                                        elem.Radius = data.Radius
                                    else
                                        elem.Radius, elem.Length = data.Radius, data.Length
                                    end
                                    if type(arr.Set) == "function" then arr:Set(0, elem) else arr[1] = elem end
                                    if agg then
                                        agg[kind .. "Elems"] = arr
                                        bodySetup.AggGeom = agg
                                    else
                                        bodySetup[kind .. "Elems"] = arr
                                    end
                                end
                            end
                        end
                    end
                end
                orig[physName] = nil
            end
        end
        -- Rebuild physics state agar geometri asli langsung terpakai di
        -- semua mesh yang pernah diskalakan (toggle OFF / match selesai).
        local meshStates = _G.RapzhangMeshHitboxState
        if meshStates then
            for _, state in pairs(meshStates) do
                local mesh = state and state.mesh
                if mesh and slua.isValid(mesh) then
                    pcall(function()
                        local phys = mesh.PhysicsAssetOverride
                        if not slua.isValid(phys) and mesh.SkeletalMesh then
                            phys = mesh.SkeletalMesh.PhysicsAsset
                        end
                        if slua.isValid(phys) then
                            if type(mesh.SetPhysicsAsset) == "function" then mesh:SetPhysicsAsset(phys) end
                            if type(mesh.RecreatePhysicsState) == "function" then mesh:RecreatePhysicsState() end
                        end
                    end)
                end
            end
        end

        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.RapzhangMeshHitboxState = {}
    end)

    -- Clear flag per-enemy mark
    pcall(function()
        local marks = _G.RapzhangState and _G.RapzhangState.EnemyMarks
        if marks then
            for _, markData in pairs(marks) do
                if markData then
                    markData.MagicBulletHash = nil
                    markData.MagicTargetID = nil
                    markData.MagicApplied = false
                end
            end
        end
    end)

    -- Kembalikan multiplier senjata Headshot dihapus: nilai itu client-only
    -- dan tidak pernah dipakai server untuk menghitung damage.
    _G.AK_MagicBulletCleared = true
end

local IpadCameraState = _G.RapzhangIpadCameraState or {
    Camera = nil,
    OriginalFOV = nil,
    AppliedFOV = nil,
    LastApplyTime = 0,
    WasAiming = false,
}
_G.RapzhangIpadCameraState = IpadCameraState

local function RestoreIpadCameraState()
    pcall(function()
        local camera = IpadCameraState.Camera
        local original = tonumber(IpadCameraState.OriginalFOV)
        if Valid(camera) and original then
            camera.FieldOfView = original
        end
    end)
    IpadCameraState.Camera = nil
    IpadCameraState.OriginalFOV = nil
    IpadCameraState.AppliedFOV = nil
    IpadCameraState.LastApplyTime = 0
    IpadCameraState.WasAiming = false
end

local function UpdateIpadViewCamera(localPlayer)
    local enabled = _G.RapzhangConfig and _G.RapzhangConfig.IpadView == true
    if not enabled or not Valid(localPlayer) then
        RestoreIpadCameraState()
        return
    end

    local camera = nil
    pcall(function() camera = localPlayer.ThirdPersonCameraComponent end)
    if not Valid(camera) then
        return
    end

    -- Respawn, vehicle transition, and world changes can replace the camera object.
    if IpadCameraState.Camera ~= camera then
        RestoreIpadCameraState()
        IpadCameraState.Camera = camera
        IpadCameraState.OriginalFOV = tonumber(camera.FieldOfView) or 90
    end

    local aiming = false
    pcall(function() aiming = localPlayer.bIsWeaponAiming == true end)
    if aiming then
        IpadCameraState.WasAiming = true
        IpadCameraState.AppliedFOV = nil
        return
    end

    -- Re-apply after leaving ADS, or at a fixed time interval independent of FPS.
    local now = os.clock()
    local target = tonumber(_G.RapzhangState.CustomTextData and _G.RapzhangState.CustomTextData.IpadViewFOV) or 120
    target = math.max(90, math.min(190, target))
    local leavingAiming = IpadCameraState.WasAiming == true
    if leavingAiming then
        IpadCameraState.WasAiming = false
        IpadCameraState.AppliedFOV = nil
    end
    if not leavingAiming and now - (IpadCameraState.LastApplyTime or 0) < 0.08 then
        return
    end

    pcall(function()
        if tonumber(camera.FieldOfView) ~= target then
            camera.FieldOfView = target
        end
    end)
    IpadCameraState.AppliedFOV = target
    IpadCameraState.LastApplyTime = now
end

local function MainLoop()
    -- Satu sumber kebenaran untuk semua pipeline ESP. ESP 360/legacy tidak
    -- boleh tetap aktif ketika ESP utama dimatikan dari menu.
    local function IsUnifiedESPEnabled()
        return _G.RapzhangConfig and _G.RapzhangConfig.EspLoai9 == true
    end

    local function ClearLegacyESPState()
        local state = _G.RapzhangState
        if not state then return end
        for key, data in pairs(state.EnemyMarks or {}) do
            if data then
                SafeRemoveMark(data.radarMark); data.radarMark = nil
                SafeRemoveMark(data.hpMark); data.hpMark = nil
                SafeRemoveMark(data.hpMark8); data.hpMark8 = nil
                SafeRemoveMark(data.distMark); data.distMark = nil
                data.enemy = nil
            end
            state.EnemyMarks[key] = nil
        end
        if state.TrackedMarks then
            for markId in pairs(state.TrackedMarks) do SafeRemoveMark(markId) end
            state.TrackedMarks = {}
        end
    end
    -- ============================================================
    -- [ACE RE-HOOK] Pastikan filterRequest tetap ter-hook
    -- ============================================================
    pcall(function()
        if _G._ACE_new_filter and rawget(_G, "filterRequest") ~= _G._ACE_new_filter then
            local cur = rawget(_G, "filterRequest")
            _G.filterRequest = function(req)
                local filtered = _G._ACE_new_filter(req)
                if filtered ~= req then return filtered end
                if cur then return cur(req) end
                return req
            end
        end
    end)

    -- [FORCE FRIEND] Deteksi perubahan toggle / file UID setiap tick.
    pcall(function()
        if _G.RapzhangForceFriend and _G.RapzhangForceFriend.Tick then
            _G.RapzhangForceFriend.Tick()
        end
    end)
    pcall(function()
        if BulletTrackSmartHead and BulletTrackSmartHead.InstallSmartHeadHook then
            BulletTrackSmartHead.InstallSmartHeadHook()
        end
    end)
    -- Auto Parachute harus tetap jalan walau pawn belum siap (guard internal).
    if _G.RapzhangAutoParachuteTick then pcall(_G.RapzhangAutoParachuteTick) end

    if _G.RapzhangState.CustomTextData == nil then 
        _G.RapzhangState.CustomTextData = {OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120,
        AimTouchMortarFOV = 360, AimTouchMortarPrio = 1, AimTouchMortarPred = 0,
        AimTouchCrossbowCond = 2, AimTouchCrossbowPrio = 1, AimTouchCrossbowBone = 1, AimTouchCrossbowSpeed = 100, AimTouchCrossbowFOV = 40, AimTouchCrossbowDist = 150, AimTouchCrossbowPred = 50, AimTouchCrossbowVel = 160, AimTouchCrossbowDrop = 100, AimTouchCrossbowDropProne = 120,
        AimTouchBowCond = 1, AimTouchBowBone = 1, AimTouchBowSpeed = 80, AimTouchBowFOV = 40, AimTouchBowDist = 150, AimTouchBowPred = 50, AimTouchBowRecoil = 0, AimTouchBowDrop = 50,
        AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250, AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30, AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400}
    end

    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GameplayData then return end 
    local pc = GameplayData.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end

    if localPlayer and BulletTrackSmartHead and BulletTrackSmartHead.Tick then
        pcall(function() BulletTrackSmartHead.Tick(localPlayer) end)
    end

        if not Valid(localPlayer) then 
        ClearIndependentWallhackState()
        if _G.RapzhangState.TrackedMarks then
            for markId, _ in pairs(_G.RapzhangState.TrackedMarks) do
                SafeRemoveMark(markId)
            end
        end
        _G.RapzhangState.TrackedMarks = {} 
        
        for key, data in pairs(_G.RapzhangState.EnemyMarks) do
            if data and data.MIDs then
                for meshStr, midTable in pairs(data.MIDs) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs = nil
            end
            if data and data.MIDs_V3 then
                for meshStr, midTable in pairs(data.MIDs_V3) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
                data.MIDs_V3 = nil
            end
        end
        
        _G.RapzhangState.EnemyMarks = {}
        -- [MAGIC BULLET] Restore PhysAsset & hapus semua jejak cache.
        if _G.AK_ClearMagicBulletCache then
            pcall(_G.AK_ClearMagicBulletCache)
        end
        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.RapzhangState.PrevGraphicsState = {}
        
        return 
    end

    if _G.AutoReportAssistTick then pcall(_G.AutoReportAssistTick) end
    -- Auto-feedback installation is outside the ESP branch: ESP OFF does not disable it.
    if _G.RapzhangConfig.AutoFeedbackEnabled == true and _G.RapzhangAutoTextFeedback and _G.RapzhangAutoTextFeedback.Install then
        pcall(_G.RapzhangAutoTextFeedback.Install)
    end

    -- Sync persisted/menu state before deciding whether ESP should start or stop.
    -- On reload, the old order could read the default false value once and never retry.
    pcall(function()
        if _G.SyncRapzhangConfig then _G.SyncRapzhangConfig() end
    end)
    pcall(function()
        ESP.SyncMenuConfig()
        ESPStartAll()
    end)

    if _G.RapzhangConfig.EspLoai9 or _G.RapzhangConfig.Esp9_Loot
        or _G.RapzhangConfig.Sup_FastLoot or _G.RapzhangConfig.Sup_AutoRescue then
        if _G.PlayerMapMarker and not _G.PlayerMapMarker.bActive then
            pcall(_G.PlayerMapMarker.Start)
        end
    else
        if _G.PlayerMapMarker and _G.PlayerMapMarker.bActive then
            pcall(_G.PlayerMapMarker.Stop)
        end
    end

    pcall(function()
    end)

    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_SecurityCommonUtils = nil
    pcall(function() Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.RapzhangConfig.UnlockFPS then InitializeGraphicsUnlock() end
    RapzhangMenu()

    local gameplayInMatch = IsGameplayMatchActive(GameplayData)
    local wasGameplayActive = _G.RapzhangState.GameplayActive == true
    _G.RapzhangState.GameplayActive = gameplayInMatch
    if wasGameplayActive and not gameplayInMatch then
        _G.RapzhangState.RestoreGameplayWeaponStats(localPlayer)
    end
        if not gameplayInMatch then
        ClearIndependentWallhackState()
        RestoreIpadCameraState()
        -- [MAGIC BULLET] Pastikan restore & cache clear meskipun di lobby.
        if _G.AK_ClearMagicBulletCache then
            pcall(_G.AK_ClearMagicBulletCache)
        end
        -- Reset flag supaya saat masuk match lagi, modifikasi bisa di-apply ulang.
        _G.AK_MagicBulletCleared = false
        return
    end
    -- Wallhack remains active and toggleable even when ESP is OFF.
    UpdateIndependentWallhack(GameplayData, localPlayer)
    
    UpdateIpadViewCamera(localPlayer)

    if _G.RapzhangConfig.AimTouchEnable then
        _G.AimTouch()
    else
        ClearMortarTargetLock()
    end

    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    local now = os.clock()
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if false and not _G.RapzhangState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "0")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
                _G.RapzhangState.PrevGraphicsState.RemoveGrass = true
            elseif not false and _G.RapzhangState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "1")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
                _G.RapzhangState.PrevGraphicsState.RemoveGrass = false
            end

            if false and not _G.RapzhangState.PrevGraphicsState.RemoveTrees then
                gi:ExecuteCMD("foliage.DensityScale", "0")
                gi:ExecuteCMD("r.Foliage.DensityScale", "0")
                gi:ExecuteCMD("foliage.MinimumScreenSize", "10000")
                gi:ExecuteCMD("r.DisableTreeRender", "1")
                _G.RapzhangState.PrevGraphicsState.RemoveTrees = true
            elseif not false and _G.RapzhangState.PrevGraphicsState.RemoveTrees then
                gi:ExecuteCMD("foliage.DensityScale", "1")
                gi:ExecuteCMD("r.Foliage.DensityScale", "1")
                gi:ExecuteCMD("foliage.MinimumScreenSize", "0.0001")
                gi:ExecuteCMD("r.DisableTreeRender", "0")
                _G.RapzhangState.PrevGraphicsState.RemoveTrees = false
            end
            
            if false and not _G.RapzhangState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "0")           
                gi:ExecuteCMD("r.VolumetricFog", "0") 
                _G.RapzhangState.PrevGraphicsState.RemoveFog = true
            elseif not false and _G.RapzhangState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "1")           
                gi:ExecuteCMD("r.VolumetricFog", "1") 
                _G.RapzhangState.PrevGraphicsState.RemoveFog = false
            end
            
            if false and not _G.RapzhangState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "2")
                gi:ExecuteCMD("r.CharacterDiffusePower", "5")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "100")
                _G.RapzhangState.PrevGraphicsState.WhiteBody = true
            elseif not false and _G.RapzhangState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                _G.RapzhangState.PrevGraphicsState.WhiteBody = false
            end
            
            if false and not _G.RapzhangState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "4")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "200")
                gi:ExecuteCMD("r.CharacterDiffusePower", "200")
                _G.RapzhangState.PrevGraphicsState.ColorBodyV2 = true
            elseif not false and _G.RapzhangState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                _G.RapzhangState.PrevGraphicsState.ColorBodyV2 = false
            end
            
            if false and not _G.RapzhangState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.RapzhangState.PrevGraphicsState.BlackSky = true
            elseif not false and _G.RapzhangState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.RapzhangState.PrevGraphicsState.BlackSky = false
            end
        end
    end)

    pcall(function()
        local weapon = nil
        pcall(function()
            local weaponManager = localPlayer.WeaponManagerComponent
            if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
                weapon = weaponManager:GetCurrentWeapon()
            end
        end)
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
            elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
        end

        if Valid(weapon) then
            local entities = {}
            if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
            if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
            if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then 
                table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent) 
            end

            for _, entity in ipairs(entities) do
                local anyWeaponModOn = _G.RapzhangConfig.CustomHRecoil or _G.RapzhangConfig.CustomVRecoil or _G.RapzhangConfig.LessShake or _G.RapzhangConfig.Accuracy or _G.RapzhangConfig.Crosshair or false or false or _G.RapzhangConfig.AimbotMode ~= "None" or _G.RapzhangConfig.LessRecoil or _G.RapzhangConfig.VerticalRecoil

                if anyWeaponModOn then
                    if not entity.OriginalStatsCached then
                        entity.OriginalStatsCached = {
                            GameDeviationFactor = entity.GameDeviationFactor,
                            GameDeviationAccuracy = entity.GameDeviationAccuracy,
                            BulletFireSpeed = entity.BulletFireSpeed,
                            ShootInterval = entity.ShootInterval,
                            BaseDamage = entity.BaseDamage,
                            AccessoriesHRecoilFactor = entity.AccessoriesHRecoilFactor,
                            AccessoriesVRecoilFactor = entity.AccessoriesVRecoilFactor,
                            RecoilKick = entity.RecoilKick,
                            RecoilKickADS = entity.RecoilKickADS,
                            AnimationKick = entity.AnimationKick
                        }
                    end
                    
                    if _G.RapzhangConfig.CustomHRecoil then
                        entity.AccessoriesHRecoilFactor = _G.RapzhangState.CustomTextData.HRecoil or 0.3
                    elseif _G.RapzhangConfig.LessRecoil then
                        entity.AccessoriesHRecoilFactor = 0.3
                    elseif entity.OriginalStatsCached then
                        entity.AccessoriesHRecoilFactor = entity.OriginalStatsCached.AccessoriesHRecoilFactor
                    end
                    
                    if _G.RapzhangConfig.CustomVRecoil then
                        entity.AccessoriesVRecoilFactor = _G.RapzhangState.CustomTextData.VRecoil or 0.3
                    elseif _G.RapzhangConfig.VerticalRecoil or _G.RapzhangConfig.LessRecoil then
                        entity.AccessoriesVRecoilFactor = 0.3
                    elseif entity.OriginalStatsCached then
                        entity.AccessoriesVRecoilFactor = entity.OriginalStatsCached.AccessoriesVRecoilFactor
                    end
                    
                    if _G.RapzhangConfig.LessShake then
                        -- No Recoil: hilangkan seluruh hentakan kamera/animasi.
                        entity.RecoilKick = 0.0
                        entity.RecoilKickADS = 0.0
                        entity.AnimationKick = 0.0
                    elseif _G.RapzhangConfig.LessRecoil then
                        -- Less Recoil: sisakan 20% dari recoil asli agar masih ada sedikit shake.
                        local base = entity.OriginalStatsCached or {}
                        if base.RecoilKick ~= nil then entity.RecoilKick = base.RecoilKick * 0.20 end
                        if base.RecoilKickADS ~= nil then entity.RecoilKickADS = base.RecoilKickADS * 0.20 end
                        if base.AnimationKick ~= nil then entity.AnimationKick = base.AnimationKick * 0.20 end
                    elseif entity.OriginalStatsCached then
                        -- Kembalikan hentakan asli saat kedua mode recoil dimatikan.
                        local base = entity.OriginalStatsCached
                        entity.RecoilKick = base.RecoilKick
                        entity.RecoilKickADS = base.RecoilKickADS
                        entity.AnimationKick = base.AnimationKick
                    end
                    if _G.RapzhangConfig.Accuracy then
                        entity.GameDeviationAccuracy = 0.0
                    elseif entity.OriginalStatsCached then
                        entity.GameDeviationAccuracy = entity.OriginalStatsCached.GameDeviationAccuracy
                    end
                    if _G.RapzhangConfig.Crosshair then
                        entity.GameDeviationFactor = 0.0
                    elseif entity.OriginalStatsCached then
                        entity.GameDeviationFactor = entity.OriginalStatsCached.GameDeviationFactor
                    end
                    if false then entity.BulletFireSpeed = 500000.0; entity.ShootInterval = 0.001; entity.BaseDamage = 60000.0 end
                    
                    if entity.AutoAimingConfig then
                        if not entity.OriginalAutoAimCached then
                            entity.OriginalAutoAimCached = {
                                OuterSpeed = entity.AutoAimingConfig.OuterRange and entity.AutoAimingConfig.OuterRange.Speed,
                                InnerSpeed = entity.AutoAimingConfig.InnerRange and entity.AutoAimingConfig.InnerRange.Speed
                            }
                        end
                        
                        if false then
                            pcall(function() entity.AutoAimingConfig.Bones = { "Head", "Head", "Head" } end)
                        end
                        
                        if _G.RapzhangConfig.AimbotMode == "Far" then
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = 5
                                entity.AutoAimingConfig.OuterRange.RangeRate = 0.7
                                entity.AutoAimingConfig.OuterRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.OuterRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.OuterRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.OuterRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.OuterRange.ProneRate = 1
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = 5
                                entity.AutoAimingConfig.InnerRange.RangeRate = 0.7
                                entity.AutoAimingConfig.InnerRange.SpeedRate = 1.3
                                entity.AutoAimingConfig.InnerRange.RangeRateSight = 1.8
                                entity.AutoAimingConfig.InnerRange.SpeedRateSight = 2.2
                                entity.AutoAimingConfig.InnerRange.CrouchRate = 1.1
                                entity.AutoAimingConfig.InnerRange.ProneRate = 1
                            end
                        end
                    end
                    
                    entity.RapzhangWeaponModsActive = true

                elseif entity.RapzhangWeaponModsActive then
                    if entity.OriginalStatsCached then
                        local orig = entity.OriginalStatsCached
                        entity.GameDeviationFactor = orig.GameDeviationFactor
                        entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
                        entity.BulletFireSpeed = orig.BulletFireSpeed
                        entity.ShootInterval = orig.ShootInterval
                        entity.BaseDamage = orig.BaseDamage
                        entity.AccessoriesHRecoilFactor = orig.AccessoriesHRecoilFactor
                        entity.AccessoriesVRecoilFactor = orig.AccessoriesVRecoilFactor
                        entity.RecoilKick = orig.RecoilKick
                        entity.RecoilKickADS = orig.RecoilKickADS
                        entity.AnimationKick = orig.AnimationKick
                    end
                    if entity.AutoAimingConfig and entity.OriginalAutoAimCached then
                        pcall(function() entity.AutoAimingConfig.Bones = { "Spine_01", "Pelvis", "Head" } end)
                        if entity.AutoAimingConfig.OuterRange and entity.OriginalAutoAimCached.OuterSpeed then
                            entity.AutoAimingConfig.OuterRange.Speed = entity.OriginalAutoAimCached.OuterSpeed
                        end
                        if entity.AutoAimingConfig.InnerRange and entity.OriginalAutoAimCached.InnerSpeed then
                            entity.AutoAimingConfig.InnerRange.Speed = entity.OriginalAutoAimCached.InnerSpeed
                        end
                    end
                    entity.RapzhangWeaponModsActive = false
                end
            end
        end
    end)

    pcall(function()
        if not IsUnifiedESPEnabled() then
            ClearLegacyESPState()
            return
        end
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end

        -- State gabungan Magic Bullet + Headshot (dipakai di loop di bawah).
        local mbHash, mbHead, mbBody, mbLegs = _G.RapzhangGetHitboxScale(false)

        local currentValidKeys = {}
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer then
                currentValidKeys[GetSafeEnemyKey(enemy)] = true
            end
        end
        
        for key, data in pairs(_G.RapzhangState.EnemyMarks) do
            if not currentValidKeys[key] then
                SafeRemoveMark(data.radarMark)
                SafeRemoveMark(data.hpMark)
                SafeRemoveMark(data.distMark)
                
                if _G.AimTouchVisCache and _G.AimTouchVisCache[key] then
                    _G.AimTouchVisCache[key] = nil
                end
                
                if data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs = nil
                end
                if data.MIDs_V3 then
                    for meshStr, midTable in pairs(data.MIDs_V3) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs_V3 = nil
                end
                
                data.enemy = nil
                data.CachedMeshes = nil
                _G.RapzhangState.EnemyMarks[key] = nil
                if _G.RapzhangMeshHitboxState then _G.RapzhangMeshHitboxState[key] = nil end
            end
        end

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local bIsReallyDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
                end)

                local eKey = GetSafeEnemyKey(enemy)
                _G.RapzhangState.EnemyMarks[eKey] = _G.RapzhangState.EnemyMarks[eKey] or { enemy = enemy }
                local markData = _G.RapzhangState.EnemyMarks[eKey]
                markData.enemy = enemy 

                if not bIsReallyDead then
                    if markData.lastEnemyActor ~= enemy then
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                        if markData.radarMark then SafeRemoveMark(markData.radarMark); markData.radarMark = nil end
                        
                        markData.lastEnemyActor = enemy
                        markData.LastUIComp = nil
                        markData.LastFrameUIState = nil
                    end
                    
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    
                    local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
                    local isBot = markData.AK_IS_BOT or false
                    -- Wallhack is handled by UpdateIndependentWallhack; ESP only handles markers/widgets.
                                        -- ============================================================================
                    -- [MAGIC BULLET + HEADSHOT — premium.lua logic]
                    -- Cache asli per-PhysicsAsset, skala penuh, elemen geometri pertama.
                    -- Hash gabungan: toggle salah satu fitur tidak membatalkan yang lain.
                    -- ============================================================================
                    pcall(function()
                        local EnemyMesh = eMesh
                        if not slua.isValid(EnemyMesh) then return end
                        if mbHash == "OFF" then return end

                        local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
                        if markData.MagicBulletHash == mbHash and markData.MagicTargetID == uniqueID then
                            return
                        end

                        local ok = _G.RapzhangApplyHitbox(EnemyMesh, mbHash, mbHead, mbBody, mbLegs, eKey)
                        if ok then
                            markData.MagicBulletHash = mbHash
                            markData.MagicTargetID = uniqueID
                        end
                    end)
                    -- ============================================================================
                    -- [END MAGIC BULLET + HEADSHOT]
                    -- ============================================================================

                    if false and _G.RapzhangConfig.Esp9_Radar360 == true then
                        if not markData.radarMark or markData.radarMark == 0 then 
                            markData.radarMark = SafeAddMark(8888, FVector(0,0,0), 0, "", 4, enemy) 
                        end
                    else
                        if markData.radarMark and markData.radarMark ~= 0 then
                            SafeRemoveMark(markData.radarMark)
                            markData.radarMark = nil
                        end
                    end
                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark)
                        markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark)
                        markData.hpMark = nil
                        SafeRemoveMark(markData.hpMark8)
                        markData.hpMark8 = nil
                        SafeRemoveMark(markData.distMark)
                        markData.distMark = nil
                        markData.IsCleanedUp = true
                    end
                end
            end
        end
    end)
end

_G.RapzhangState.RefreshActiveWeaponStats = function()
    pcall(MainLoop)
    pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.05, function() pcall(MainLoop) end)
        end
    end)
end
_G.RapzhangState.LoopToken = (_G.RapzhangState.LoopToken or 0) + 1  
local myToken = _G.RapzhangState.LoopToken

function FastTick() 
    if myToken ~= _G.RapzhangState.LoopToken then return end
    
    pcall(MainLoop)

    local aimActive = _G.RapzhangState.GameplayActive == true and _G.RapzhangConfig.AimTouchEnable
    local interval = aimActive and 0.02 or 0.5
    local okTicker, ticker = pcall(require, "common.time_ticker") 
    if okTicker and ticker and ticker.AddTimerOnce then 
        ticker.AddTimerOnce(interval, FastTick) 
    end 
end

FastTick()
Notify("Bạn Đang Chơi Mod Vvip 4 Của Tôi Nếu Chưa Có Key Inbox Tele rapzhang Để Mua Nếu Ai Đó Đã Bán Cho Bạn Thứ Này Ngoài Tôi Thì Xin Chúc Mừng Bạn Đã Bị Lừa")

-- ===================================================================================
-- SYSTEM HOOKS TỪ BYPASS MỚI
-- ===================================================================================
local function InitAllModSystems()
    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
    end)

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return end

    pcall(function()
        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false 
                LocalPlayer.bHasShownExpiredNotice = false 
                LocalPlayer.bIsDeadFlag = false
            end
        end
    end)
end

pcall(function() 
    require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) 
        require("common.time_ticker").AddTimerOnce(1.0, function()
            pcall(function()
                if _G.RapzhangForceFriend and _G.RapzhangForceFriend.Boot then
                    _G.RapzhangForceFriend.Boot()
                end
            end)
        end)
    end)

-- ==============================================================================
-- ================= BẮT ĐẦU LOGIC MOD EMOTE ===================================
-- ==============================================================================

function M.OnBeginPlay(self)

end

-- =====================================================
-- HAWKEYE DISABLE
-- =====================================================
local function DisableHawkEye()
    pcall(function()
        local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubsystemMgr then
            local hawkEye = SubsystemMgr:Get("ClientHawkEyePatrolSubsystem")
            if hawkEye then
                hawkEye.IsDuringHawkEyePatrol = function() return false end
                if hawkEye._nInitializeTimerID then
                    Game:ClearTimer(hawkEye._nInitializeTimerID)
                end
                hawkEye.ReportCheat = function() end
                hawkEye.SendReportTLog = function() end
                hawkEye._OnHawkSync = function() end
                hawkEye._OnHawkReportSuccess = function() end
                hawkEye._InitHawkEyePatrolSubsystem = function() end
                print("[HAWKEYE] Disabled successfully")
            end
        end
    end)
end

pcall(function()
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(6.0, DisableHawkEye)
    end
end)

-- ============================================================================
-- EXTRA FEATURES INTEGRATION: ExtraFItur.lua
-- ============================================================================
function X3ExtraRuntimeInit()
    _G.RapzhangX3 = _G.RapzhangX3 or {}
    _G.RapzhangX3.RapzhangConfig = _G.RapzhangConfig
    _G.RapzhangX3.SaveModSettings = _G.SaveModSettings

    local XC = _G.RapzhangConfig
    XC.X3Watermark = XC.X3Watermark ~= false
    XC.X3TPPForce = XC.X3TPPForce == true
    XC.X3FakeVisual = XC.X3FakeVisual == true
    XC.X3PerfBoost = XC.X3PerfBoost == true
    XC.X3TPPUnlockBtn = XC.X3TPPUnlockBtn == true

    _G.RapzhangX3._WMRefresh = function()
        _G.RapzhangX3._WMVisible = XC.X3Watermark == true and (_G.RapzhangX3._WMManual == true or _G.RapzhangX3._WMEndOn == true)
        return _G.RapzhangX3._WMVisible
    end
    _G.RapzhangX3._WMHookInstall = _G.RapzhangX3._WMHookInstall or function() return true end
    _G.RapzhangX3._WMShowUI = _G.RapzhangX3._WMShowUI or function(show) _G.RapzhangX3._WMVisible = show == true end

    _G.RapzhangX3._PerfBoostState = _G.RapzhangX3._PerfBoostState or { applied = nil, last = 0 }
    local X3PerfCmds_ON = {"r.MotionBlurQuality 0", "r.DepthOfFieldQuality 0", "r.SceneColorFringeQuality 0", "r.LensFlareQuality 0", "r.BloomQuality 2", "r.Tonemapper.GrainQuantization 0", "r.Shadow.CSM.MaxMobileCascades 1", "r.Shadow.DistanceScale 0.5", "r.EmitterSpawnRateScale 0.5", "r.ParticleLODBias 1", "r.StaticMeshLODDistanceScale 0.8"}
    local X3PerfCmds_OFF = {"r.MotionBlurQuality 2", "r.DepthOfFieldQuality 2", "r.SceneColorFringeQuality 1", "r.LensFlareQuality 2", "r.BloomQuality 4", "r.Tonemapper.GrainQuantization 1", "r.Shadow.CSM.MaxMobileCascades 2", "r.Shadow.DistanceScale 1.0", "r.EmitterSpawnRateScale 1", "r.ParticleLODBias 0", "r.StaticMeshLODDistanceScale 1.0"}
    _G.RapzhangX3._LowGraphicsState = _G.RapzhangX3._LowGraphicsState or { applied = nil, last = 0 }
    -- Only render/resource settings. Intentionally excludes FPS and view distance.
    local LowGraphics_ON = {
        "r.MotionBlurQuality 0",
        "r.DepthOfFieldQuality 0",
        "r.SceneColorFringeQuality 0",
        "r.LensFlareQuality 0",
        "r.BloomQuality 0",
        "r.AmbientOcclusionLevels 0",
        "r.AmbientOcclusionRadiusScale 0",
        "r.ReflectionEnvironment 0",
        "r.SSR.Quality 0",
        "r.LightShaftQuality 0",
        "r.VolumetricFog 0",
        "r.Fog 0",
        "r.ParticleLODBias 2",
        "r.EmitterSpawnRateScale 0.35",
        "r.Shadow.CSM.MaxMobileCascades 0",
        "r.Shadow.DistanceScale 0",
        "r.ShadowQuality 0",
        "r.ContactShadows 0",
        "r.Shadow.Virtual.Enable 0",
        "r.DistanceFieldShadowing 0",
        "r.CapsuleShadows 0",
        "r.MaterialQualityLevel 0",
        "r.DetailMode 0",
    }
    local LowGraphics_OFF = {
        "r.MotionBlurQuality 2",
        "r.DepthOfFieldQuality 2",
        "r.SceneColorFringeQuality 1",
        "r.LensFlareQuality 2",
        "r.BloomQuality 4",
        "r.AmbientOcclusionLevels 2",
        "r.AmbientOcclusionRadiusScale 1",
        "r.ReflectionEnvironment 1",
        "r.SSR.Quality 2",
        "r.LightShaftQuality 1",
        "r.VolumetricFog 1",
        "r.Fog 1",
        "r.ParticleLODBias 0",
        "r.EmitterSpawnRateScale 1",
        "r.Shadow.CSM.MaxMobileCascades 2",
        "r.Shadow.DistanceScale 1",
        "r.ShadowQuality 2",
        "r.ContactShadows 1",
        "r.Shadow.Virtual.Enable 1",
        "r.DistanceFieldShadowing 1",
        "r.CapsuleShadows 1",
        "r.MaterialQualityLevel 1",
        "r.DetailMode 2",
    }
    -- Extra resource reduction layered on top of the native VERYSMOOTH Lua path.
    -- Termasuk bias mip tekstur (Streaming.MipBias/MipMapLODBias), anisotropic
    -- off, dan streaming boost rendah supaya tekstur ikut benar-benar low.
    -- Deliberately excludes FPS, frame-rate limit, and view-distance variables.
    local SuperDuper_ON = {
        "r.Fog 0",
        "r.VolumetricFog 0",
        "r.LightShaftQuality 0",
        "r.LensFlareQuality 0",
        "r.BloomQuality 0",
        "r.MotionBlurQuality 0",
        "r.DepthOfFieldQuality 0",
        "r.SceneColorFringeQuality 0",
        "r.ReflectionEnvironment 0",
        "r.SSR.Quality 0",
        "r.AmbientOcclusionLevels 0",
        "r.AmbientOcclusionRadiusScale 0",
        "r.ParticleLODBias 2",
        "r.EmitterSpawnRateScale 0.25",
        "r.Shadow.CSM.MaxMobileCascades 0",
        "r.Shadow.DistanceScale 0",
        "r.ShadowQuality 0",
        "r.ContactShadows 0",
        "r.Shadow.Virtual.Enable 0",
        "r.DistanceFieldShadowing 0",
        "r.CapsuleShadows 0",
        "r.MaterialQualityLevel 0",
        "r.DetailMode 0",
        "r.MipLODBiasLowClampSize 512",
        "r.ForceMipFilterToPoint 1",
        "r.StaticMeshForceLODMaterialBias 2",
        "s.EnableOverrideVerySmoothMaterial 1",
        "r.DisableLensFlareWhenBeginPlay 1",
        -- Tekstur benar-benar low: mip dipaksa turun, anisotropic dimatikan,
        -- dan jarak streaming dikurangi. Efeknya tekstur jauh lebih blur
        -- (hemat bandwidth/RAM) tetapi geometri dan jarak pandang tetap.
        "r.Streaming.MipBias 2",
        "r.MipMapLODBias 1",
        "r.MaxAnisotropy 0",
        "r.Streaming.Boost 0.5",
    }
    local SuperDuper_OFF = {
        "r.Fog 1",
        "r.VolumetricFog 1",
        "r.LightShaftQuality 1",
        "r.LensFlareQuality 2",
        "r.BloomQuality 4",
        "r.MotionBlurQuality 2",
        "r.DepthOfFieldQuality 2",
        "r.SceneColorFringeQuality 1",
        "r.ReflectionEnvironment 1",
        "r.SSR.Quality 2",
        "r.AmbientOcclusionLevels 2",
        "r.AmbientOcclusionRadiusScale 1",
        "r.ParticleLODBias 0",
        "r.EmitterSpawnRateScale 1",
        "r.Shadow.CSM.MaxMobileCascades 2",
        "r.Shadow.DistanceScale 1",
        "r.ShadowQuality 2",
        "r.ContactShadows 1",
        "r.Shadow.Virtual.Enable 1",
        "r.DistanceFieldShadowing 1",
        "r.CapsuleShadows 1",
        "r.MaterialQualityLevel 1",
        "r.DetailMode 2",
        "r.MipLODBiasLowClampSize 0",
        "r.ForceMipFilterToPoint 0",
        "r.StaticMeshForceLODMaterialBias 0",
        "s.EnableOverrideVerySmoothMaterial 0",
        "r.DisableLensFlareWhenBeginPlay 0",
        "r.Streaming.MipBias 0",
        "r.MipMapLODBias 0",
        "r.MaxAnisotropy 4",
        "r.Streaming.Boost 1",
    }
    local function ApplySuperDuperCommands(gameInstance, commands)
        if not gameInstance or type(gameInstance.ExecuteCMD) ~= "function" then return end
        for _, command in ipairs(commands) do
            pcall(function() gameInstance:ExecuteCMD(command:match("^(%S+)"), command:match("%s+(.+)$")) end)
        end
    end

    _G.RapzhangX3.ApplyLowGraphics = function(on)
        local st, now = _G.RapzhangX3._LowGraphicsState, os.clock()
        if st.applied == on and now - (st.last or 0) < 2.0 then return true end

        local ok, result = pcall(function()
            local DB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
            local Logic = require("client.slua.logic.setting.logic_setting_graphics")
            local Quality = import("ERenderQuality")
            if not DB or not Logic or not Quality then return false end

            -- Simpan setting grafis asli sekali untuk pemulihan saat OFF.
            if not st.saved then
                st.saved = {}
                local keys = {
                    "BattleRenderQuality", "LobbyRenderQuality", "ManorRenderQuality",
                    "MainCityRenderQuality", "SelectedQuality", "SelectedShadow",
                    "SelectedWaterReflection", "SelectedEnergySaving",
                    "RenderMSAASetting", "RenderMSAAValue"
                }
                for _, name in ipairs(keys) do
                    local key = DB[name]
                    if key and DB.GetUIData then st.saved[name] = DB:GetUIData(key) end
                end
                local gi = Logic.GetGameInstance and Logic.GetGameInstance()
                local applying = gi and gi.GetRenderQualityApplying and gi:GetRenderQualityApplying()
                if applying then
                    st.saved.RenderStyleSetting = applying.RenderStyleSetting
                    st.saved.RenderQualitySetting = applying.RenderQualitySetting
                    st.saved.RenderMSAASetting = applying.RenderMSAASetting
                    st.saved.RenderMSAAValue = applying.RenderMSAAValue
                end
            end

            local gi = Logic.GetGameInstance and Logic.GetGameInstance()
            if not gi then return false end
            local applying = gi.GetRenderQualityApplying and gi:GetRenderQualityApplying() or {}
            local style = applying.RenderStyleSetting or st.saved.RenderStyleSetting
            local msaa = applying.RenderMSAASetting or false
            local msaaValue = applying.RenderMSAAValue or 0

            if on then
                -- Jalur asli Lua: kualitas terendah. FPS/view distance tidak disentuh.
                if DB.UpdateSelectedQuality then DB:UpdateSelectedQuality(Quality.VERYSMOOTH, true) end
                if DB.UpdateUIData then
                    DB:UpdateUIData(DB.SelectedShadow, false)
                    DB:UpdateUIData(DB.SelectedWaterReflection, false)
                    DB:UpdateUIData(DB.SelectedEnergySaving, true)
                    DB:UpdateUIData(DB.RenderMSAASetting, false)
                    DB:UpdateUIData(DB.RenderMSAAValue, 0)
                end
                if DB.SaveChanges then DB:SaveChanges() end
                if Logic.SetQuality then Logic.SetQuality(gi, Quality.VERYSMOOTH, style, false, 0) end
                ApplySuperDuperCommands(gi, SuperDuper_ON)
            else
                -- Pulihkan hanya nilai yang disimpan; FPS dan view distance tidak pernah diubah.
                if DB.UpdateUIData then
                    for _, name in ipairs({"BattleRenderQuality", "LobbyRenderQuality", "ManorRenderQuality", "MainCityRenderQuality", "SelectedQuality", "SelectedShadow", "SelectedWaterReflection", "SelectedEnergySaving", "RenderMSAASetting", "RenderMSAAValue"}) do
                        local key, value = DB[name], st.saved[name]
                        if key and value ~= nil then DB:UpdateUIData(key, value) end
                    end
                end
                if DB.SaveChanges then DB:SaveChanges() end
                local q = st.saved.RenderQualitySetting or st.saved.SelectedQuality or Quality.BALANCE
                local rs = st.saved.RenderStyleSetting or style
                local rm = st.saved.RenderMSAASetting == true
                local rv = tonumber(st.saved.RenderMSAAValue) or 0
                if Logic.SetQuality then Logic.SetQuality(gi, q, rs, rm, rv) end
                ApplySuperDuperCommands(gi, SuperDuper_OFF)
            end
            return true
        end)
        st.applied, st.last = on, now
        print("[LOW GRAPHICS LUA] " .. (on and "ON" or "OFF") .. " result=" .. tostring(ok and result))
        return ok and result == true
    end
    if XC.LowGraphics == true then pcall(_G.RapzhangX3.ApplyLowGraphics, true) end

    _G.RapzhangX3.ApplyPerfBoost = function(on)
        local st, now = _G.RapzhangX3._PerfBoostState, os.clock()
        if st.applied == on and now - (st.last or 0) < 5.0 then return true end
        local pc = nil
        pcall(function() pc = GameplayData and GameplayData.GetPlayerController and GameplayData.GetPlayerController() end)
        if not (pc and slua.isValid(pc)) then return false end
        local KSL = import("KismetSystemLibrary")
        if not (KSL and KSL.ExecuteConsoleCommand) then return false end
        for _, cmd in ipairs(on and X3PerfCmds_ON or X3PerfCmds_OFF) do pcall(KSL.ExecuteConsoleCommand, pc, cmd, nil) end
        st.applied, st.last = on, now
        if type(_G.RapzhangX3.Trace) == "function" then _G.RapzhangX3.Trace("PERF BOOST: " .. (on and "ON" or "OFF")) end
        return true
    end

    _G.RapzhangX3._FakeVisualInstall = function()
        local XC = _G.RapzhangConfig
        if not XC.X3FakeVisual then 
            return false 
        end

        if not _G._fakeGachaInited then
            pcall(function()
                if _G.InitFakeGachaSystem then
                    _G.InitFakeGachaSystem()
                    _G._fakeGachaInited = true
                    print("[FAKE GACHA] Initialized by Fake Sultan toggle")
                end
            end)
        end

        _G.RapzhangX3._FakeMoneyOK = _G.RapzhangX3._FakeMoneyOK or false
        _G.RapzhangX3._SkinLvlOK = _G.RapzhangX3._SkinLvlOK or false
        local applied = false
        local DM = rawget(_G, "DataMgr")
        if DM then
            local function applyCurrency()
                local maxVisual = 999999999
                DM.gold, DM.ticket, DM.diamond, DM.fp_token = maxVisual, maxVisual, maxVisual, maxVisual
                DM.uc = maxVisual
                DM.gold_chip, DM.gen_ticket, DM.eternal_diamond = maxVisual, maxVisual, maxVisual
                DM.corps_money, DM.smelt, DM.battle_coin = maxVisual, maxVisual, maxVisual
                DM.home_coin, DM.pp, DM.bp = maxVisual, maxVisual, maxVisual
                DM.coupon, DM.voucher = maxVisual, maxVisual
                DM.wow_creation_score, DM.ugc_advanced_crystal = maxVisual, maxVisual
                DM.carteam_coin_count, DM.anchor, DM.anchor_origin = maxVisual, maxVisual, maxVisual
                local F = _G.FakePlayerDataCore or {
                    G = 78787878, UC = 72000, Silver = 78916613,
                    Level = 100, Avatar = 30396, AvatarBox = 2002901,
                    Segment = 801, HistorySegment = 801, PeakSegment = 1301,
                    Rating = 13200, PeakRating = 8000, Achievement = 9500,
                    Collection = 99999,
                }
                _G.FakePlayerDataCore = F
                DM.eternal_diamond, DM.ticket, DM.diamond, DM.uc = F.G, F.UC, F.Silver, F.UC
                if DM.roleData then
                    local rd = DM.roleData
                    rd.level, rd.pic_url, rd.headIconUrl = F.Level, F.Avatar, F.Avatar
                    rd.cur_avatar_box_id, rd.bgbg_vip = F.AvatarBox, 1
                    rd.cur_max_segment_level, rd.history_max_segment_level = F.Segment, F.HistorySegment
                    rd.peakgame_history_max_segment, rd.achievement_score = F.PeakSegment, F.Achievement
                    rd.segment = rd.segment or {}
                    rd.segment.solo, rd.segment.double, rd.segment.team = F.Segment, F.Segment, F.Segment
                    rd.segment.fpp_solo, rd.segment.fpp_double, rd.segment.fpp_team = F.Segment, F.Segment, F.Segment
                    rd.brief_collect_data = rd.brief_collect_data or {}
                    rd.brief_collect_data.total_score = F.Collection
                    rd.brief_collect_data.cur_season_collect_score = F.Collection
                end
                local ES = rawget(_G, "EventSystem")
                local ET = rawget(_G, "EVENTTYPE_DATA_MGR")
                if ES and ES.postEvent and ET then
                    pcall(function() ES:postEvent(ET, rawget(_G, "EVENTID_DATAMGR_GOLD_CHANGE"), DM.gold) end)
                    pcall(function() ES:postEvent(ET, rawget(_G, "EVENTID_DATAMGR_DIAMOND_CHANGE"), DM.diamond) end)
                    pcall(function() ES:postEvent(ET, rawget(_G, "EVENTID_DATAMGR_TICKET_CHANGE"), DM.ticket) end)
                    pcall(function() ES:postEvent(ET, rawget(_G, "EVENTID_DATAMGR_UC_CHANGE"), DM.uc) end)
                end
                applied = true
            end
            pcall(applyCurrency)
            if type(DM.InitRoleData) == "function" and not DM.__x3FakeVisual then
                local original = DM.InitRoleData
                DM.InitRoleData = function(roleDataTb)
                    original(roleDataTb)
                    pcall(applyCurrency)
                end
                DM.__x3FakeVisual = true
            end
        end

        local MM = rawget(_G, "ModuleManager")
        if MM and MM.GetModule and MM.LobbyModuleConfig then
            pcall(function()
                local cm = MM.GetModule(MM.LobbyModuleConfig.collect_module)
                if cm then
                    local maxLevel = 100
                    if type(cm.GetLevelByScore) == "function" and not cm.__x3lvl_a then
                        local original = cm.GetLevelByScore
                        cm.GetLevelByScore = function(self, score)
                            if score and score >= 0 then return maxLevel, maxLevel, maxLevel, 0, 0 end
                            return original(self, score)
                        end
                        cm.__x3lvl_a = true
                    end
                    if type(cm.GetLevelDataByScore) == "function" and not cm.__x3lvl_b then
                        local original = cm.GetLevelDataByScore
                        cm.GetLevelDataByScore = function(self, score, isSeason)
                            if score and score >= 0 then return maxLevel, "", maxLevel end
                            return original(self, score, isSeason)
                        end
                        cm.__x3lvl_b = true
                    end
                    if type(cm.GetSeasonLevelByScore) == "function" and not cm.__x3lvl_c then
                        local original = cm.GetSeasonLevelByScore
                        cm.GetSeasonLevelByScore = function(self, score, ...)
                            if score and score >= 0 then return maxLevel, false, "" end
                            return original(self, score, ...)
                        end
                        cm.__x3lvl_c = true
                    end
                    applied = true
                    _G.RapzhangX3._SkinLvlOK = true
                end
            end)
        end
        if applied then _G.RapzhangX3._FakeMoneyOK = true end
        return applied
    end

    _G.RapzhangX3._XFTPPUnlockTry = function()
        if not XC.X3TPPUnlockBtn then return false end
        local ok, UIT = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        if not ok or type(UIT) ~= "table" or type(UIT.IsFPP) ~= "function" then return false end
        if UIT.__x3tpp_orig == nil then
            UIT.__x3tpp_orig = UIT.IsFPP
            UIT.IsFPP = function(...)
                if XC.X3TPPUnlockBtn == true then return false end
                return UIT.__x3tpp_orig(...)
            end
        end
        pcall(function()
            local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
            if gs and slua.isValid(gs) then
                if gs.IsCanSwitchFPP ~= nil then gs.IsCanSwitchFPP = true end
                if gs.IsFPPGameMode ~= nil then gs.IsFPPGameMode = false end
                if gs.IsFPPMode ~= nil then gs.IsFPPMode = false end
                if gs.bIsFPPMode ~= nil then gs.bIsFPPMode = false end
                if gs.C_IsFPPMode ~= nil then gs.C_IsFPPMode = false end
            end
        end)
        return true
    end

    _G.RapzhangX3._XFTPPTick = function()
        if XC.X3TPPUnlockBtn ~= true then
            _G.RapzhangX3._XFTPPOn = false
            return
        end
        local nowU = os.clock()
        if not _G.RapzhangX3._TPPUnlockOK and nowU - (_G.RapzhangX3._TPPUnlockAt or 0) >= 3.0 then
            _G.RapzhangX3._TPPUnlockAt = nowU
            pcall(_G.RapzhangX3._XFTPPUnlockTry)
        end
        pcall(function()
            local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
            if gs and slua.isValid(gs) then
                if gs.IsFPPGameMode ~= nil then gs.IsFPPGameMode = false end
                if gs.IsCanSwitchFPP ~= nil then gs.IsCanSwitchFPP = true end
                if gs.IsFPPMode ~= nil then gs.IsFPPMode = false end
                if gs.bIsFPPMode ~= nil then gs.bIsFPPMode = false end
                if gs.C_IsFPPMode ~= nil then gs.C_IsFPPMode = false end
            end
        end)
    end

    local function X3ExtraTick()
        pcall(function()
            local pc = GameplayData and GameplayData.GetPlayerController and GameplayData.GetPlayerController()
            local lp = pc and pc.Pawn
            local inMatch = false
            pcall(function()
                local gs = GameplayData and GameplayData.GetGameState and GameplayData.GetGameState()
                local mode = gs and gs.GetGameModeState and gs:GetGameModeState()
                inMatch = mode == "FightingState"
            end)
                _G.RapzhangX3._XFTPPTick(lp)
            _G.RapzhangX3.ApplyPerfBoost(XC.X3PerfBoost == true)
            if XC.X3FakeVisual then _G.RapzhangX3._FakeVisualInstall() end
            if not XC.X3FakeVisual then
            end
            _G.RapzhangX3._WMRefresh()
        end)
        local ok, ticker = pcall(require, "common.time_ticker")
        if ok and ticker and ticker.AddTimerOnce then ticker.AddTimerOnce(3.0, X3ExtraTick) end
    end
    pcall(X3ExtraTick)
end
X3ExtraRuntimeInit()

-- ============================================================================
-- FAKE UC + DRAW SYSTEM
-- ============================================================================
_G._fakeGachaOriginalFunctions = {}

local function SafeRequire(modulePath)
    local success, result = pcall(require, modulePath)
    if not success or not result then
        return nil
    end
    return result
end

local function GetResId(data)
    local keys = {"resid", "res_id", "item_id", "itemId", "award_item_id", "id", "resID", "itemid"}
    for _, key in ipairs(keys) do
        local val = data[key]
        if val then
            local num = tonumber(val)
            if num and num > 0 then
                return num
            end
        end
    end
    return nil
end

local function GetItemCount(data)
    local keys = {"count", "item_count", "item_num", "itemCount", "num", "award_item_num", "itemNum"}
    for _, key in ipairs(keys) do
        local val = data[key]
        if val then
            local num = tonumber(val)
            if num and num > 0 then
                return num
            end
        end
    end
    return 1
end

local function GetValidHours(data)
    local keys = {"valid_hours", "vaild_time", "valid_time", "award_item_valid_time", "validTime", "validHour"}
    for _, key in ipairs(keys) do
        local val = data[key]
        if val then
            local num = tonumber(val)
            if num then
                return num
            end
        end
    end
    return 0
end

local function GetPosId(data)
    local keys = {"pos_id", "posId", "position", "index", "display_sort"}
    for _, key in ipairs(keys) do
        local val = data[key]
        if val then
            local num = tonumber(val)
            if num and num > 0 then
                return num
            end
        end
    end
    return nil
end

local function ExtractRewardList(activityData)
    local rewardList = {}
    if not activityData then return rewardList end

    local targetList = nil
    if activityData.poolItemConfig and #activityData.poolItemConfig > 0 then
        targetList = activityData.poolItemConfig
    elseif activityData.AwardPoolConfig then
        local index = activityData.CurAwardPoolIndex or 1
        targetList = activityData.AwardPoolConfig[index]
    elseif activityData.draw_info then
        local index = activityData.CurAwardPoolIndex or 1
        if activityData.draw_info[index] then
            targetList = activityData.draw_info[index].item_list
        end
    elseif activityData.CurBigAwardPoolConfig then
        targetList = activityData.CurBigAwardPoolConfig
    elseif activityData.dropList then
        targetList = activityData.dropList
    elseif activityData.pool_info then
        targetList = activityData.pool_info
    elseif activityData.CurSmallAwardPoolConfig then
        targetList = activityData.CurSmallAwardPoolConfig
    elseif activityData.totalDrawAwardConfig then
        targetList = activityData.totalDrawAwardConfig
    elseif activityData.DrawActivityInfo and activityData.DrawActivityInfo.pool_info then
        targetList = activityData.DrawActivityInfo.pool_info
    elseif activityData.super_airdrop_param then
        targetList = activityData.super_airdrop_param
    elseif activityData.Items then
        targetList = activityData.Items
    end

    if targetList then
        for _, itemData in ipairs(targetList) do
            local resId = GetResId(itemData)
            if resId then
                local posId = GetPosId(itemData) or (#rewardList + 1)
                table.insert(rewardList, {
                    resid = resId,
                    count = GetItemCount(itemData),
                    pos_id = posId,
                    valid_hours = GetValidHours(itemData)
                })
            end
        end
    end
    return rewardList
end

local function ShowRewardPanel(itemList)
    local Logic_CommonItemGet = SafeRequire("client.slua.logic.common.CommonItemGet.Logic_CommonItemGet")
    if Logic_CommonItemGet then
        local formattedList = {}
        for _, item in pairs(itemList) do
            table.insert(formattedList, {
                res_id = item.resid,
                count = item.count or 1,
                valid_hours = item.valid_hours or 0
            })
        end
        Logic_CommonItemGet.ShowPanel_DefaultStyle(formattedList, false, true)
    end
end

local function UpdatePlayerData(activityData, addTimes, isTenDraw)
    if not activityData then return end

    if activityData.playerData then
        local pData = activityData.playerData
        local totalDraw = pData.totalDrawTime or 0
        pData.totalDrawTime = totalDraw + addTimes

        if pData.one_draw_times ~= nil then
            local current = pData.one_draw_times or 0
            pData.one_draw_times = current + (isTenDraw and 0 or 1)
        end

        if pData.duo_draw_times ~= nil then
            local current = pData.duo_draw_times or 0
            pData.duo_draw_times = current + (isTenDraw and 1 or 0)
        end

        if pData.curLuckyValue ~= nil then
            local addLucky = isTenDraw and 10 or 1
            local maxLucky = 100
            if activityData.globalConfig and activityData.globalConfig.maxLuckyValue then
                maxLucky = activityData.globalConfig.maxLuckyValue
            end
            pData.curLuckyValue = math.min((pData.curLuckyValue or 0) + addLucky, maxLucky)
        end

        if pData.draw_times_week ~= nil then
            pData.draw_times_week = (pData.draw_times_week or 0) + addTimes
        end

        if pData.debrisItemCount ~= nil then
            pData.debrisItemCount = (pData.debrisItemCount or 0) + addTimes
        end
    end

    if activityData.TotalSnatchTimes then
        local actId = activityData.ActivityId or 0
        local currentSnatch = activityData.TotalSnatchTimes[actId] or 0
        activityData.TotalSnatchTimes[actId] = currentSnatch + addTimes
    end

    if activityData.acc_list_info and activityData.acc_list_info.cur_times ~= nil then
        activityData.acc_list_info.cur_times = (activityData.acc_list_info.cur_times or 0) + addTimes
    end

    if activityData.DrawLogConfig then
        for _, logConfig in pairs(activityData.DrawLogConfig) do
            if logConfig.had_draw_count ~= nil then
                logConfig.had_draw_count = (logConfig.had_draw_count or 0) + addTimes
            end
        end
    end

    if activityData.curLuckyValue ~= nil then
        local addLucky = isTenDraw and 10 or 1
        local maxLucky = 100
        if activityData.globalConfig and activityData.globalConfig.maxLuckyValue then
            maxLucky = activityData.globalConfig.maxLuckyValue
        end
        activityData.curLuckyValue = math.min((activityData.curLuckyValue or 0) + addLucky, maxLucky)
    end

    if activityData.CurRoundDrawTimes ~= nil then
        activityData.CurRoundDrawTimes = (activityData.CurRoundDrawTimes or 0) + addTimes
    end

    if activityData.draw_times_week ~= nil then
        activityData.draw_times_week = (activityData.draw_times_week or 0) + addTimes
    end

    if activityData.pool_draw_times then
        activityData.pool_draw_times = (activityData.pool_draw_times or 0) + addTimes
    end

    if activityData.totalDrawAwardConfig then
        for _, config in pairs(activityData.totalDrawAwardConfig) do
            if config.timesCount then
                if ((activityData.totalDrawTime or 0) + addTimes) >= config.timesCount then
                    config.hasGet = true
                end
            end
        end
    end

    if activityData.DrawActivityInfo and activityData.DrawActivityInfo.accumulate_info then
        local poolId = 10000
        activityData.pool_draw_times = (activityData.pool_draw_times or 0) + addTimes
        local currentPoolTimes = activityData.pool_draw_times
        local accInfo = activityData.DrawActivityInfo.accumulate_info[poolId]
        if accInfo then
            for reqTimes, info in pairs(accInfo) do
                if reqTimes <= currentPoolTimes then
                    activityData.DrawActivityInfo.accumulate_info[poolId][reqTimes].state = 2
                end
            end
        end
    end

    if EventSystem then
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBACK_LUCKY_VALUE_UP)
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBACK_STATUS_CHANGE)
    end
end

local function ProcessDraw(activityData, isTenDraw)
    if not activityData then return end

    local availableRewards = ExtractRewardList(activityData)
    if not availableRewards or #availableRewards == 0 then
        if _G.ShowNotice then _G.ShowNotice("Phần thưởng trống") end
        return
    end

    local drawCount = isTenDraw and math.min(10, #availableRewards) or 1
    local selectedRewards = {}
    local pickedIndexes = {}

    for i = 1, drawCount do
        local pickIdx = nil
        local attempts = 0
        repeat
            pickIdx = math.random(1, #availableRewards)
            attempts = attempts + 1
        until not pickedIndexes[pickIdx] or attempts > 50
        
        pickedIndexes[pickIdx] = true
        local item = availableRewards[pickIdx]
        
        table.insert(selectedRewards, {
            resid = item.resid,
            count = item.count or 1,
            pos_id = item.pos_id or i,
            valid_hours = item.valid_hours or 0
        })
    end

    UpdatePlayerData(activityData, drawCount, isTenDraw)

    if activityData.dropList ~= nil then
        activityData.dropList = {}
        for i, item in pairs(selectedRewards) do
            table.insert(activityData.dropList, {
                res_id = item.resid,
                count = item.count,
                valid_hours = item.valid_hours or 0,
                pos_id = item.pos_id or i
            })
        end
    end

    if activityData.DropItem ~= nil then activityData.DropItem = selectedRewards end
    if activityData.pet_awards ~= nil then activityData.pet_awards = selectedRewards end
    if activityData.award_info ~= nil then activityData.award_info = selectedRewards end

    if isTenDraw then
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBACK_DARW_TEN_ANIMATION, 10)
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYMULTI_LOTTERY, selectedRewards)
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBASE_ALL_DRAW_ANIM_START, 1, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
    else
        local posId = selectedRewards[1] and selectedRewards[1].pos_id or 1
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBACK_DARW_ONE_ANIMATION, posId)
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBASE_ONE_DRAW_ANIM_START, 1, posId)
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYUNBACK_DARW_ANIMATION, posId)
    end

    EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBACK_STATUS_CHANGE)
    EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKUNYBACK_STATUS_CHANGE)
    EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBACK_REFRESH)
    EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_SPIN_START_COIN_UPDATE)
    EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYMULTI_REFRESH_WINDOW)

    if _G.AddTimerOnce then
        _G.AddTimerOnce(_G, 2.5, function()
            ShowRewardPanel(selectedRewards)
        end)
    end
end

function _G.InitFakeGachaSystem()
    if _G._fakeGachaInited then return end
    _G._fakeGachaInited = true

    if DataMgr then
        DataMgr.ticket = 999999999
        DataMgr.eternal_diamond = 999999999
        DataMgr.home_coin = 999999999
        DataMgr.gold = 999999999
        DataMgr.diamond = 999999999
        DataMgr.pp = 999999999
        DataMgr.bp = 999999999
        DataMgr.coupon = 999999999
        DataMgr.voucher = 999999999

        local mt = getmetatable(DataMgr) or {}
        local oldIndex = mt.__index
        mt.__index = function(t, key)
            if key == "ticket" or key == "uc" or key == "UC" or key == "gold" or key == "diamond" or key == "eternal_diamond" or key == "home_coin" or key == "pp" or key == "bp" or key == "coupon" or key == "voucher" then
                return 999999999
            end
            if type(oldIndex) == "function" then
                return oldIndex(t, key)
            elseif type(oldIndex) == "table" then
                return oldIndex[key]
            end
            return rawget(t, key)
        end
        setmetatable(DataMgr, mt)

        if DataMgr.GetUserData then
            local oldGetUserData = DataMgr.GetUserData
            DataMgr.GetUserData = function(arg1)
                local data = oldGetUserData(arg1)
                if data then
                    data.ticket = 999999999
                    data.uc = 999999999
                    data.gold = 999999999
                    data.diamond = 999999999
                    data.eternal_diamond = 999999999
                    data.home_coin = 999999999
                end
                return data
            end
        end
    end

    local logic_common_pay_box = SafeRequire("client.slua.logic.common.Payclass.logic_common_pay_box")
    if logic_common_pay_box then
        logic_common_pay_box.ShowUcRechargeMsg = function() return true end
        logic_common_pay_box.ShowRechargeMsg = function() return true end
    end

    local QRcodeRestrictManager = SafeRequire("client.module_framework.CommonModuleConfig.QRcodeRestrictManager")
    if QRcodeRestrictManager then
        QRcodeRestrictManager.CheckUCRestrict = function() return false end
        QRcodeRestrictManager.IsRestrictUC = function() return false end
        QRcodeRestrictManager.ShowRestrictTips = function() end
    end
    
    local luckyback_activity = SafeRequire("client.slua.logic.lobby_activity.logic_luckyback_activity")
    if luckyback_activity then
        if not _G._fakeGachaOriginalFunctions.luckyback_activity_orig then
            _G._fakeGachaOriginalFunctions.luckyback_activity_orig = {
                do_one_draw_back_by_activity_req = luckyback_activity.do_one_draw_back_by_activity_req,
                do_one_draw_by_tick = luckyback_activity.do_one_draw_by_tick,
                get_sum_draw_award_by_activity_req = luckyback_activity.get_sum_draw_award_by_activity_req
            }
        end
        luckyback_activity.do_one_draw_back_by_activity_req = function(arg1, arg2)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(luckyback_activity, arg1 == 2)
            else
                local orig = _G._fakeGachaOriginalFunctions.luckyback_activity_orig.do_one_draw_back_by_activity_req
                if orig then orig(arg1, arg2) end
            end
        end
        luckyback_activity.do_one_draw_by_tick = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(luckyback_activity, false)
            else
                local orig = _G._fakeGachaOriginalFunctions.luckyback_activity_orig.do_one_draw_by_tick
                if orig then orig(arg1) end
            end
        end
        luckyback_activity.get_sum_draw_award_by_activity_req = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                local rewardList = ExtractRewardList(luckyback_activity)
                if rewardList and #rewardList > 0 then
                    local pickIdx = math.random(1, #rewardList)
                    ShowRewardPanel({
                        {resid = rewardList[pickIdx].resid, count = 1, valid_hours = 0}
                    })
                end
            else
                local orig = _G._fakeGachaOriginalFunctions.luckyback_activity_orig.get_sum_draw_award_by_activity_req
                if orig then orig(arg1) end
            end
        end
    end

    local luckydouble_activity = SafeRequire("client.slua.logic.lobby_activity.logic_luckydouble_activity")
    if luckydouble_activity then
        if not _G._fakeGachaOriginalFunctions.luckydouble_activity_orig then
            _G._fakeGachaOriginalFunctions.luckydouble_activity_orig = {
                send_do_one_lucky_double_draw_by_activity_req = luckydouble_activity.send_do_one_lucky_double_draw_by_activity_req,
                send_double_draw_on_shot_req = luckydouble_activity.send_double_draw_on_shot_req
            }
        end
        luckydouble_activity.send_do_one_lucky_double_draw_by_activity_req = function(arg1, arg2, arg3, arg4)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(luckydouble_activity, false)
            else
                local orig = _G._fakeGachaOriginalFunctions.luckydouble_activity_orig.send_do_one_lucky_double_draw_by_activity_req
                if orig then orig(arg1, arg2, arg3, arg4) end
            end
        end
        luckydouble_activity.send_double_draw_on_shot_req = function(arg1, arg2, arg3, arg4)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(luckydouble_activity, true)
            else
                local orig = _G._fakeGachaOriginalFunctions.luckydouble_activity_orig.send_double_draw_on_shot_req
                if orig then orig(arg1, arg2, arg3, arg4) end
            end
        end
    end

    local luckyunback_activity = SafeRequire("client.slua.logic.lobby_activity.logic_luckyunback_activity")
    if luckyunback_activity then
        if not _G._fakeGachaOriginalFunctions.luckyunback_activity_orig then
            _G._fakeGachaOriginalFunctions.luckyunback_activity_orig = {
                send_do_draw_discount_by_activity_req = luckyunback_activity.send_do_draw_discount_by_activity_req
            }
        end
        luckyunback_activity.send_do_draw_discount_by_activity_req = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(luckyunback_activity, false)
            else
                local orig = _G._fakeGachaOriginalFunctions.luckyunback_activity_orig.send_do_draw_discount_by_activity_req
                if orig then orig(arg1) end
            end
        end
    end

    local luckmix_activity = SafeRequire("client.slua.logic.lobby_activity.logic_luckmix_activity")
    if luckmix_activity then
        if not _G._fakeGachaOriginalFunctions.luckmix_activity_orig then
            _G._fakeGachaOriginalFunctions.luckmix_activity_orig = {
                DoDraw = luckmix_activity.DoDraw
            }
        end
        luckmix_activity.DoDraw = function(arg1, arg2)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(luckmix_activity, arg1 == 2)
            else
                local orig = _G._fakeGachaOriginalFunctions.luckmix_activity_orig.DoDraw
                if orig then orig(arg1, arg2) end
            end
        end
    end

    local luckymulti_activity = SafeRequire("client.slua.logic.lobby_activity.logic_luckymulti_activity")
    if luckymulti_activity then
        if not _G._fakeGachaOriginalFunctions.luckymulti_activity_orig then
            _G._fakeGachaOriginalFunctions.luckymulti_activity_orig = {
                Lottery = luckymulti_activity.Lottery
            }
        end
        luckymulti_activity.Lottery = function(arg1, arg2, arg3, arg4)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(luckymulti_activity, arg1 == 10)
            else
                local orig = _G._fakeGachaOriginalFunctions.luckymulti_activity_orig.Lottery
                if orig then orig(arg1, arg2, arg3, arg4) end
            end
        end
    end

    local scrapgold_draw = SafeRequire("client.slua.logic.lobby_activity.logic_scrapgold_draw")
    if scrapgold_draw then
        if not _G._fakeGachaOriginalFunctions.scrapgold_draw_orig then
            _G._fakeGachaOriginalFunctions.scrapgold_draw_orig = {
                DoDraw = scrapgold_draw.DoDraw
            }
        end
        scrapgold_draw.DoDraw = function(arg1, arg2)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(scrapgold_draw, arg1 == 2)
            else
                local orig = _G._fakeGachaOriginalFunctions.scrapgold_draw_orig.DoDraw
                if orig then orig(arg1, arg2) end
            end
        end
    end

    local godzilla_ban = SafeRequire("client.slua.logic.lobby_activity.logic_godzilla_ban")
    if godzilla_ban then
        if not _G._fakeGachaOriginalFunctions.godzilla_ban_orig then
            _G._fakeGachaOriginalFunctions.godzilla_ban_orig = {
                OneDraw = godzilla_ban.OneDraw,
                TenDraw = godzilla_ban.TenDraw
            }
        end
        godzilla_ban.OneDraw = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(godzilla_ban, false)
            else
                local orig = _G._fakeGachaOriginalFunctions.godzilla_ban_orig.OneDraw
                if orig then orig(arg1) end
            end
        end
        godzilla_ban.TenDraw = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(godzilla_ban, true)
            else
                local orig = _G._fakeGachaOriginalFunctions.godzilla_ban_orig.TenDraw
                if orig then orig(arg1) end
            end
        end
    end

    local crazy_weekend = SafeRequire("client.slua.logic.lobby_activity.crazy_weekend.logic_crazy_weekend_luckydraw")
    if crazy_weekend then
        if crazy_weekend.send_get_happy_weekend_ticket_req then
            crazy_weekend.send_get_happy_weekend_ticket_req = function()
                if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                    local tickets = {}
                    for i = 1, 3 do
                        tickets[i] = {get_time = os.time(), register_week = 1}
                    end
                    crazy_weekend.MyLuckyDraw = {}
                    for key, val in pairs(tickets) do
                        table.insert(crazy_weekend.MyLuckyDraw, {[key] = val})
                    end
                    crazy_weekend.ticket_active = true
                    EventSystem:postEvent(EVENTTYPE_CRAZYWEEKEND, EVENTID_CRAZYWEEKEND_TICKET_UPDATE)
                else
                end
            end
        end
    end

    local LukcyOptionalTurntable = SafeRequire("client.slua.logic.lobby_activity.LukcyOptionalTurntable.Logic_LukcyOptionalTurntable")
    if LukcyOptionalTurntable then
        if not _G._fakeGachaOriginalFunctions.LukcyOptionalTurntable_orig then
            _G._fakeGachaOriginalFunctions.LukcyOptionalTurntable_orig = {
                SendDrawActReq = LukcyOptionalTurntable.SendDrawActReq
            }
        end
        LukcyOptionalTurntable.SendDrawActReq = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(LukcyOptionalTurntable, arg1 == 10)
            else
                local orig = _G._fakeGachaOriginalFunctions.LukcyOptionalTurntable_orig.SendDrawActReq
                if orig then orig(arg1) end
            end
        end
    end

    local tarotcard_drawcard = SafeRequire("client.slua.logic.tarot_card.logic_tarotcard_drawcard")
    if tarotcard_drawcard then
        if not _G._fakeGachaOriginalFunctions.tarotcard_drawcard_orig then
            _G._fakeGachaOriginalFunctions.tarotcard_drawcard_orig = {
                DoDraw = tarotcard_drawcard.DoDraw
            }
        end
        tarotcard_drawcard.DoDraw = function(arg1, arg2)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(tarotcard_drawcard, arg1 == 2)
            else
                local orig = _G._fakeGachaOriginalFunctions.tarotcard_drawcard_orig.DoDraw
                if orig then orig(arg1, arg2) end
            end
        end
    end

    local super_airdrop = SafeRequire("client.slua.logic.lobby_activity.logic_super_airdrop")
    if super_airdrop then
        if not _G._fakeGachaOriginalFunctions.super_airdrop_orig then
            _G._fakeGachaOriginalFunctions.super_airdrop_orig = {
                send_choose_and_get_super_airdrop_reward_req = super_airdrop.send_choose_and_get_super_airdrop_reward_req
            }
        end
        super_airdrop.send_choose_and_get_super_airdrop_reward_req = function(arg1, arg2)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                local rewardList = ExtractRewardList(super_airdrop)
                if rewardList and #rewardList > 0 then
                    local pickIdx = math.random(1, #rewardList)
                    ShowRewardPanel({
                        {resid = rewardList[pickIdx].resid, count = 1, valid_hours = 0}
                    })
                end
                super_airdrop.have_take_award = true
            else
                local orig = _G._fakeGachaOriginalFunctions.super_airdrop_orig.send_choose_and_get_super_airdrop_reward_req
                if orig then orig(arg1, arg2) end
            end
        end
    end

    local xsuit_activity = SafeRequire("client.slua.logic.XSuit.logic_xsuit_activity")
    if xsuit_activity then
        if not _G._fakeGachaOriginalFunctions.xsuit_activity_orig then
            _G._fakeGachaOriginalFunctions.xsuit_activity_orig = {
                send_do_draw_act_req = xsuit_activity.send_do_draw_act_req,
                OnGetDrawActivityInfo = xsuit_activity.OnGetDrawActivityInfo,
                send_get_accumulate_pool_reward_req = xsuit_activity.send_get_accumulate_pool_reward_req
            }
        end
        xsuit_activity.send_do_draw_act_req = function(arg1, arg2, arg3, arg4, arg5)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ProcessDraw(xsuit_activity, arg4 == 10)
            else
                local orig = _G._fakeGachaOriginalFunctions.xsuit_activity_orig.send_do_draw_act_req
                if orig then orig(arg1, arg2, arg3, arg4, arg5) end
            end
        end
        xsuit_activity.OnGetDrawActivityInfo = function(arg1, arg2, arg3)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                if arg2 ~= 0 then
                    local mockInfo = {
                        activity_id = 999999,
                        exchange_activity_id = 999999,
                        ex_item_id = 403003,
                        pool_info = {
                            [1001] = { {itemid = 403003, cli_tag = 1} }
                        },
                        draw_currency = {
                            [1006] = {one_cost = 1, ten_cost = 10}
                        },
                        gold_dress_one_level_id = 403003,
                        is_first_dis = true,
                        discount_uc_cost = 1,
                        accumulate_coin_count = 9999,
                        accumulate_info = {
                            [10000] = { {} }
                        },
                        branch_box_item_id = 403003
                    }
                    arg1.DrawActivityInfo = mockInfo
                    EventSystem:postEvent(EVENTTYPE_XSUIT, EVENTID_XSUIT_DRAW_ACTIVITY_UPDATE)
                    return
                end
                local orig = _G._fakeGachaOriginalFunctions.xsuit_activity_orig.OnGetDrawActivityInfo
                if orig then orig(arg1, arg2, arg3) end
            else
                local orig = _G._fakeGachaOriginalFunctions.xsuit_activity_orig.OnGetDrawActivityInfo
                if orig then orig(arg1, arg2, arg3) end
            end
        end
        xsuit_activity.send_get_accumulate_pool_reward_req = function(arg1, arg2)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                ShowRewardPanel({ {resid = 403003, count = arg2 or 1, valid_hours = 0} })
                local stateInfo = { [arg1] = { [arg2] = { state = 2 } } }
                xsuit_activity.SetAccumulateStateInfo(xsuit_activity, stateInfo)
                EventSystem:postEvent(EVENTTYPE_XSUIT, EVENTID_XSUIT_ACCUMULATE_POOL_REWARD)
            else
                local orig = _G._fakeGachaOriginalFunctions.xsuit_activity_orig.send_get_accumulate_pool_reward_req
                if orig then orig(arg1, arg2) end
            end
        end
    end

    local logic_ladder_draw = SafeRequire("client.slua.logic.lobby_activity.logic_ladder_draw")
    if logic_ladder_draw then
        if not _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig then
            _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig = {
                OnRotateRsp = logic_ladder_draw.OnRotateRsp,
                OnRandomAwardRsp = logic_ladder_draw.OnRandomAwardRsp,
                OnRecvAwardRsp = logic_ladder_draw.OnRecvAwardRsp,
                GetDrawData = logic_ladder_draw.GetDrawData
            }
        end
        logic_ladder_draw.OnRotateRsp = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                if not arg1 or not arg1.reward_info then
                    local rewards = ExtractRewardList(logic_ladder_draw)
                    if rewards and #rewards > 0 then
                        local pickIdx = math.random(1, #rewards)
                        arg1 = {
                            pos = 1,
                            last_opt_rest = 1,
                            reward_info = { {item_id = rewards[pickIdx].resid, item_num = 1, valid_hours = 0} }
                        }
                    else
                        arg1 = {
                            pos = 1,
                            last_opt_rest = 1,
                            reward_info = { {item_id = 403003, item_num = 1, valid_hours = 0} }
                        }
                    end
                end
                local orig = _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig.OnRotateRsp
                if orig then orig(arg1) end
                EventSystem:postEvent(EVENTTYPE_LADDER_DRAW, EVENTID_LADDER_DRAW_ROTATE)
            else
                local orig = _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig.OnRotateRsp
                if orig then orig(arg1) end
            end
        end

        logic_ladder_draw.OnRandomAwardRsp = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                if not arg1 or not arg1.real_list then
                    local rewards = ExtractRewardList(logic_ladder_draw)
                    if rewards and #rewards > 0 then
                        local pickIdx = math.random(1, #rewards)
                        local mockItem = {resid = rewards[pickIdx].resid, count = 1, valid_hours = 0}
                        arg1 = {
                            real_list = {mockItem},
                            reward_list = {mockItem},
                            decompose_list = {}
                        }
                    else
                        local mockItem = {resid = 403003, count = 1, valid_hours = 0}
                        arg1 = {
                            real_list = {mockItem},
                            reward_list = {mockItem},
                            decompose_list = {}
                        }
                    end
                end
                local orig = _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig.OnRandomAwardRsp
                if orig then orig(arg1) end
                EventSystem:postEvent(EVENTTYPE_LADDER_DRAW, EVENTID_LADDER_DRAW_RANDOM_AWARD)
            else
                local orig = _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig.OnRandomAwardRsp
                if orig then orig(arg1) end
            end
        end

        logic_ladder_draw.OnRecvAwardRsp = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                if not arg1 or not arg1.real_list then
                    local rewards = ExtractRewardList(logic_ladder_draw)
                    if rewards and #rewards > 0 then
                        local pickIdx = math.random(1, #rewards)
                        local mockItem = {resid = rewards[pickIdx].resid, count = 1, valid_hours = 0}
                        arg1 = {
                            real_list = {mockItem},
                            reward_list = {mockItem},
                            decompose_list = {}
                        }
                    else
                        local mockItem = {resid = 403003, count = 1, valid_hours = 0}
                        arg1 = {
                            real_list = {mockItem},
                            reward_list = {mockItem},
                            decompose_list = {}
                        }
                    end
                end
                local orig = _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig.OnRecvAwardRsp
                if orig then orig(arg1) end
                ShowRewardPanel(arg1.real_list)
                EventSystem:postEvent(EVENTTYPE_LADDER_DRAW, EVENTID_LADDER_DRAW_RECV_AWARD)
            else
                local orig = _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig.OnRecvAwardRsp
                if orig then orig(arg1) end
            end
        end

        logic_ladder_draw.GetDrawData = function(arg1)
            if _G.RapzhangConfig and _G.RapzhangConfig.X3FakeVisual then
                local data = nil
                local orig = _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig.GetDrawData
                if orig then data = orig(arg1) end
                if data and data.reward_info then return data end
                
                local rewards = ExtractRewardList(logic_ladder_draw)
                if rewards and #rewards > 0 then
                    local pickIdx = math.random(1, #rewards)
                    local mockInfo = {
                        pos = 1,
                        last_opt_rest = 1,
                        reward_info = { {item_id = rewards[pickIdx].resid, item_num = 1, valid_hours = 0} }
                    }
                    if logic_ladder_draw.svrDrawData then
                        logic_ladder_draw.svrDrawData[logic_ladder_draw.nShowingActivityID] = mockInfo
                    end
                    return mockInfo
                end
                return data
            else
                local orig = _G._fakeGachaOriginalFunctions.logic_ladder_draw_orig.GetDrawData
                if orig then return orig(arg1) end
                return nil
            end
        end
    end

    _G.DoFakeDraw = function(isTenDraw)
        local modules = {
            SafeRequire("client.slua.logic.lobby_activity.logic_luckyback_activity"),
            SafeRequire("client.slua.logic.lobby_activity.logic_luckydouble_activity"),
            SafeRequire("client.slua.logic.lobby_activity.logic_luckyunback_activity"),
            SafeRequire("client.slua.logic.lobby_activity.logic_luckmix_activity"),
            SafeRequire("client.slua.logic.lobby_activity.logic_luckymulti_activity"),
            SafeRequire("client.slua.logic.lobby_activity.logic_scrapgold_draw"),
            SafeRequire("client.slua.logic.XSuit.logic_xsuit_activity")
        }
        
        for _, mod in ipairs(modules) do
            if mod and mod.ActivityId and mod.ActivityId > 0 then
                ProcessDraw(mod, isTenDraw or false)
                return
            end
        end
    end

    _G.DoFakeDrawOne = function() _G.DoFakeDraw(false) end
    _G.DoFakeDrawTen = function() _G.DoFakeDraw(true) end

    _G.BuyItem = function(resid, count)
        ShowRewardPanel({ {resid = resid, count = count or 1, valid_hours = 0} })
    end

    _G.OpenChest = function(resid)
        ShowRewardPanel({ {resid = resid or 403003, count = 1, valid_hours = 0} })
    end

    _G.ClaimAllRewards = function()
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBACK_STATUS_CHANGE)
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKUNYBACK_STATUS_CHANGE)
        EventSystem:postEvent(EVENTTYPE_ACTIVITY, EVENTID_LUCKYBACK_REFRESH)
        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_DEPOT_UPDATE)
    end
end

-- ============================================================================
-- ============================================================================
-- ==========================================
-- Lobby Join (Fake Friend team action)
-- Source: jni/LuaFakeFriend.hpp (kFakeFriendScript)
-- Entry: _G._nadFakeFriendTeamAction(uid)
-- Join path: TeamUpNewSystem.JoinTeamByChat + team_apply_request + team_invite_reply
-- C++: ProcessFakeFriendTeamActionRequest() in Main-Lib.cpp

_G.__RAPZHANG_FAKE_FRIEND_LOADED = true

_G.HackAccountData = _G.HackAccountData or { uc = 0, level = 0, collectionLevel = 0, avatar = 0, avatarFrame = 0, matchStartAnim = 0, friends = {} }
_G._nadFfProfileCache = _G._nadFfProfileCache or {}
_G._nadFfSet = _G._nadFfSet or {}
_G._nadFfEntryCache = nil
local _nadAppliedFriends = {}

local function _nadRemoveFakeFriend(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return end
    pcall(function()
        local FriendHandler = require("client.network.Protocol.FriendHandler")
        FriendHandler.on_del_inner_friend_notify(uid)
    end)
    pcall(function()
        local MM = require("client.module_framework.ModuleManager")
        local LFL = MM.GetModule(MM.CommonModuleConfig.logic_friend_list)
        if LFL and LFL.res_friendlist and LFL.res_friendlist.inner_list then
            LFL.res_friendlist.inner_list[uid] = nil
            LFL.res_friendlist.inner_list[tostring(uid)] = nil
        end
    end)
    _nadAppliedFriends[uid] = nil
end

local function _nadFfEsc(s)
    s = tostring(s or "")
    s = s:gsub("|", "/")
    s = s:gsub("\r", " ")
    s = s:gsub("\n", " ")
    return s
end

local function _nadFfIsFakeFriend(uid)
    uid = tonumber(uid)
    if not uid then return false end
    local set = _G._nadFfSet
    if set and set[uid] then return true end
    local friends = _G.HackAccountData and _G.HackAccountData.friends or {}
    for _, f in ipairs(friends) do
        if tonumber(f) == uid then return true end
    end
    return false
end

local function _nadFfRebuildSet()
    local set = {}
    local friends = _G.HackAccountData and _G.HackAccountData.friends or {}
    for _, f in ipairs(friends) do
        local n = tonumber(f)
        if n and n > 0 then set[n] = true end
    end
    _G._nadFfSet = set
end

local function _nadFfSnapStatus(v)
    if not v then return nil end
    return {
        teamState = v.teamState, teamStateNew = v.teamStateNew, online = v.online,
        game_id = v.game_id, game_mode = v.game_mode, game_sub_mode = v.game_sub_mode,
        timeSinceGameBegin = v.timeSinceGameBegin, gameBeginTime = v.gameBeginTime,
        currentTeamAmount = v.currentTeamAmount, maxTeamAmount = v.maxTeamAmount,
        socialland_type = v.socialland_type, is_in_hall = v.is_in_hall,
        team_id = v.team_id, teamId = v.teamId, leader_uid = v.leader_uid,
    }
end

local function _nadFfRememberTeamId(uid, v)
    if not uid or not v then return end
    local tid = tonumber(v.team_id or v.teamId or v.teamid)
    if tid and tid > 0 then
        _G._nadFfTeamIdCache = _G._nadFfTeamIdCache or {}
        _G._nadFfTeamIdCache[uid] = tid
        _G._nadFfTeamIdCache[tostring(uid)] = tid
    end
end

local function _nadFfCacheRaw(uid, v)
    if not _nadFfIsFakeFriend(uid) then return end
    _G._nadFfRawCache = _G._nadFfRawCache or {}
    local snap = _nadFfSnapStatus(v)
    if not snap then return end
    _G._nadFfRawCache[uid] = snap
    _G._nadFfRawCache[tostring(uid)] = snap
    _nadFfRememberTeamId(uid, v)
end

local function _nadFfResolveTeamId(uid, eff)
    uid = tonumber(uid)
    _G._nadFfTeamIdCache = _G._nadFfTeamIdCache or {}
    local cached = _G._nadFfTeamIdCache[uid] or _G._nadFfTeamIdCache[tostring(uid)]
    if cached and cached > 0 then return cached end
    if eff then
        local tid = tonumber(eff.team_id or eff.teamId or eff.teamid)
        if tid and tid > 0 then return tid end
        local leader = tonumber(eff.leader_uid or eff.leader)
        if leader and leader > 0 then return leader end
    end
    return uid
end

local function _nadFfFriendDisplayName(uid)
    uid = tonumber(uid)
    local ModuleManager = require("client.module_framework.ModuleManager")
    local logic_profile = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_profile)
    if logic_profile then
        local p = logic_profile:GetLocalProfile(uid)
        if not p and logic_profile.GetProfile then p = logic_profile:GetProfile(uid) end
        if p and p.nickName and p.nickName ~= "" then return p.nickName end
    end
    return tostring(uid)
end

local function _nadFfIsHidden(s)
    if not s then return false end
    if s.teamState == 8 or s.teamState == 7 then return true end
    if s.teamStateNew == 8 or s.teamStateNew == 7 then return true end
    return false
end

local function _nadFfHasGameData(s)
    if not s then return false end
    if s.socialland_type and s.socialland_type ~= 0 then return false end
    if s.game_mode and s.game_mode == 26000 then return false end
    if s.is_in_hall then return false end
    if s.game_id and s.game_id ~= 0 then return true end
    if s.game_mode and s.game_mode ~= 0 then return true end
    return (s.timeSinceGameBegin and s.timeSinceGameBegin > 0) or
        (s.gameBeginTime and s.gameBeginTime > 0)
end

local function _nadFfModeName(subMode)
    if not subMode or subMode == 0 then return nil end
    if not (DataMgr and DataMgr.GetModeName) then return nil end
    local name = DataMgr.GetModeName(subMode)
    if not name or name == "" then return nil end
    name = string.gsub(name, "[Pp]rivate%s*", "")
    name = string.gsub(name, "[Ii]nvisible%s*", "")
    name = string.gsub(name, "^[Ii]n%s+", "")
    name = name:match("^%s*(.-)%s*$") or name
    if name == "" then return nil end
    return name
end

local function _nadFfGetRaw(uid)
    _G._nadFfRawCache = _G._nadFfRawCache or {}
    local c = _G._nadFfRawCache[uid] or _G._nadFfRawCache[tostring(uid)]
    if c then return c end
    return nil
end

-- Stealth: do not touch game statusMap; only fill hack monitor (mode/since from raw cache).
local function _nadFfApplyStealthRaw(raw, mode, squad, state, since, time_util)
    if not raw then return mode, squad, state, since, false end
    local hidden = _nadFfIsHidden(raw)
    local inGame = _nadFfHasGameData(raw)
    local stealthOffline = (raw.online == 0 or raw.online == false) and inGame
    if not hidden and not stealthOffline then return mode, squad, state, since, false end
    state = "OFFLINE"
    if inGame then
        if raw.game_sub_mode == 10080 then
            mode = (LocUtil and LocUtil.GetLocalizeResStr) and LocUtil.GetLocalizeResStr(100042) or "Training Grounds"
        else
            mode = _nadFfModeName(raw.game_sub_mode) or mode
        end
        if raw.currentTeamAmount and raw.maxTeamAmount then
            squad = string.format("%d/%d", raw.currentTeamAmount, raw.maxTeamAmount)
        end
        if raw.timeSinceGameBegin and raw.timeSinceGameBegin > 0 and time_util and time_util.GetOpenedTimeStr then
            since = "Started " .. tostring(time_util.GetOpenedTimeStr(raw.timeSinceGameBegin)) .. " ago"
        end
    else
        mode = "Idle"
    end
    return mode, squad, state, since, true
end

-- Ephemeral status for hack actions only (never written to PlayerStatusMgr.statusMap).
local function _nadFfEffectiveStatus(uid, status)
    local sRaw = _nadFfGetRaw(uid)
    if not sRaw and status then
        sRaw = _nadFfSnapStatus(status)
    end
    if not sRaw and not status then
        return nil
    end
    local hidden = sRaw and _nadFfIsHidden(sRaw)
    local stealthOff = sRaw and (sRaw.online == 0 or sRaw.online == false) and _nadFfHasGameData(sRaw)
    if not hidden and not stealthOff then
        return status
    end
    local eff = {}
    if status then
        for k, v in pairs(status) do eff[k] = v end
    end
    if sRaw then
        for k, v in pairs(sRaw) do eff[k] = v end
    end
    eff.online = 1
    if sRaw and _nadFfHasGameData(sRaw) then
        eff.teamState = 2
        eff.teamStateNew = 2
    elseif sRaw and (sRaw.teamState == 1 or sRaw.teamStateNew == 1) then
        eff.teamState = 1
        eff.teamStateNew = 1
    else
        eff.teamState = 0
        eff.teamStateNew = 0
    end
    return eff
end

local function _nadFfSyncTeamState(status)
    if not status then return nil end
    if status.teamStateNew ~= nil then
        status.teamState = status.teamStateNew
    end
    return status
end

local function _nadFfFriendNeedsApplyJoin(status)
    if not status then return false end
    local PlayerStatusUtil = require("client.slua.logic.player_status.PlayerStatusUtil")
    if PlayerStatusUtil.IsTeam(status) then return true end
    if PlayerStatusUtil.ISLANDInTeam(status) then return true end
    if PlayerStatusUtil.IsInHomeTeam(status) then return true end
    if PlayerStatusUtil.WoWInTeam(status) then return true end
    if PlayerStatusUtil.IsMainCityTeam(status) then return true end
    local cur = tonumber(status.currentTeamAmount)
    return cur and cur > 1
end

function _G._nadFakeFriendTeamAction(uid)
    if not (_G.RapzhangConfig and _G.RapzhangConfig.ForceFriend == true) then return false end
    uid = tonumber(uid)
    if not uid or uid <= 0 then return false end
    if not _nadFfIsFakeFriend(uid) then return false end
    if LobbySystem and LobbySystem.isInMatch then return false end
    local ModuleManager = require("client.module_framework.ModuleManager")
    local PlayerStatusMgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.PlayerStatusMgr)
    local status = PlayerStatusMgr and PlayerStatusMgr.GetStatusData and PlayerStatusMgr:GetStatusData(uid)
    if not status then return false end
    local actionStatus = _nadFfSyncTeamState(_nadFfEffectiveStatus(uid, status) or status)
    if not actionStatus then return false end
    local PlayerStatusUtil = require("client.slua.logic.player_status.PlayerStatusUtil")
    local TeamUpNewSystem = require("client.slua.logic.teamup.logic_team_up")
    local from = TeamUpNewSystem.E_InviteFromType.FriendBar
    local src = "rapzhang_ff"

    if tonumber(actionStatus.game_sub_mode) == 10080 then
        local ShootingTrainTool = require("GameLua.Mod.SingleTraining.GamePlay.Data.SingleTrainTool")
        ShootingTrainTool.ClickButton_SingleTraining(uid)
        return true
    end

    if PlayerStatusUtil.InHall(actionStatus) and actionStatus.mod_id then
        return false
    end
    if PlayerStatusUtil.IsRoom(actionStatus) and actionStatus.mod_id then
        return false
    end

    if _nadFfFriendNeedsApplyJoin(actionStatus) then
        pcall(function()
            if TeamUpNewSystem.CanInviteFriend and TeamUpNewSystem.CanInviteFriend() then
                TeamUpNewSystem.team_apply_request(uid, from)
            end
        end)
        local teamId = _nadFfResolveTeamId(uid, actionStatus)
        pcall(function() TeamUpNewSystem.JoinTeamByChat(uid, teamId, src, from) end)
        pcall(function()
            TeamUpNewSystem.team_invite_reply(NetErrorCode_NONE, uid, tonumber(teamId), src, from)
        end)
        return true
    end

    local sentInvite = false
    pcall(function()
        if TeamUpNewSystem.CanInviteFriend and TeamUpNewSystem.CanInviteFriend(uid) then
            TeamUpNewSystem.team_invite_request(uid, from)
            sentInvite = true
        end
    end)
    local myTeamId = TeamUpNewSystem.GetTeamID and TeamUpNewSystem.GetTeamID()
    local iAmLeader = TeamUpNewSystem.IsTeamLeader and TeamUpNewSystem.IsTeamLeader()
    if myTeamId and iAmLeader then
        pcall(function()
            TeamUpNewSystem.team_apply_reply(
                NetErrorCode_NONE, uid, tonumber(myTeamId), src, from, "",
                _nadFfFriendDisplayName(uid))
        end)
        return true
    end
    return sentInvite
end

local function _nadEnsureFriendListSlot(uid)
    uid = tonumber(uid)
    if not uid then return end
    local MM = require("client.module_framework.ModuleManager")
    local logic_friend_list = MM.GetModule(MM.CommonModuleConfig.logic_friend_list)
    if not logic_friend_list then return end
    if not logic_friend_list.res_friendlist then
        logic_friend_list.res_friendlist = { inner_list = {}, plat_list = {} }
    end
    local rfl = logic_friend_list.res_friendlist
    if not rfl.inner_list then rfl.inner_list = {} end
    -- Cek langsung ke inner_list, bukan GetFriendInfo: method itu bisa
    -- sudah di-patch dan tidak boleh dipakai sebagai penentu apakah slot
    -- benar-benar ada.
    if rfl.inner_list[uid] or rfl.inner_list[tostring(uid)] then return end
    local TimeUtil = require("client.common.time_util")
    rfl.inner_list[uid] = { uid = uid, intimacy = 0, create_time = TimeUtil.GetServerTimeInSec() }
end

local function _nadFfOfflineModeText(uid, time_util)
    local ModuleManager = require("client.module_framework.ModuleManager")
    local logic_profile = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_profile)
    if logic_profile and logic_profile.GetLastOnlineTime and time_util and time_util.GetLastOnlineTimeStr then
        local last = logic_profile:GetLastOnlineTime(uid)
        if last then
            return time_util.GetLastOnlineTimeStr(last)
        end
    end
    if LocUtil and LocUtil.GetLocalizeResStr then
        return LocUtil.GetLocalizeResStr(1212)
    end
    return "OFFLINE"
end

local function _nadFfModeStateFromGameStatus(status, time_util, uid)
    local mode, squad, state, since = "--", "--", "OFFLINE", "--"
    if not status then return mode, squad, state, since end
    status = _nadFfSyncTeamState(status)
    if status.online == 0 or status.online == false then
        if uid then
            mode = _nadFfOfflineModeText(uid, time_util)
        else
            mode = "OFFLINE"
        end
        return mode, squad, state, since
    end
    if status.socialland_type and status.socialland_type ~= 0 then
        return "Idle", squad, "ONLINE", since
    end
    if status.teamState == 0 then
        mode = "Idle"
        state = "ONLINE"
        return mode, squad, state, since
    end
    if status.teamState == 1 then
        mode = "Idle"
        state = "IN TEAM"
        if status.currentTeamAmount and status.maxTeamAmount then
            squad = string.format("%d/%d", status.currentTeamAmount, status.maxTeamAmount)
        end
        return mode, squad, state, since
    end
    if status.teamState == 2 then
        state = "IN GAME"
        if status.game_sub_mode == 10080 then
            mode = (LocUtil and LocUtil.GetLocalizeResStr) and LocUtil.GetLocalizeResStr(100042) or "Training"
        elseif status.timeSinceGameBegin and status.timeSinceGameBegin > 0 then
            mode = _nadFfModeName(status.game_sub_mode) or "--"
            if time_util and time_util.GetOpenedTimeStr then
                since = "Started " .. tostring(time_util.GetOpenedTimeStr(status.timeSinceGameBegin)) .. " ago"
            end
        else
            mode = _nadFfModeName(status.game_sub_mode) or "In Game"
        end
        if status.currentTeamAmount and status.maxTeamAmount then
            squad = string.format("%d/%d", status.currentTeamAmount, status.maxTeamAmount)
        end
        return mode, squad, state, since
    end
    mode = "Idle"
    state = "ONLINE"
    return mode, squad, state, since
end

function _G._nadExportFakeFriendUiFile(force)
    -- Dipanggil dari setiap batch response; batasi 1 dtk sekali dan
    -- hanya tulis file kalau isinya berubah.
    local now = os.time()
    if force ~= true and (now - (_G._nadFfLastExport or -999.0)) < 1.0 then return end
    _G._nadFfLastExport = now
    local friends = _G.HackAccountData and _G.HackAccountData.friends or {}
    local lines = {}
    local ModuleManager = require("client.module_framework.ModuleManager")
    local logic_profile = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_profile)
    local PlayerStatusMgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.PlayerStatusMgr)
    local time_util = require("client.common.time_util")
    for _, uid in ipairs(friends) do
        uid = tonumber(uid)
        if uid and uid > 0 then
            local name = tostring(uid)
            pcall(function()
                local p = logic_profile:GetLocalProfile(uid)
                if not p and logic_profile.GetProfile then p = logic_profile:GetProfile(uid) end
                if p and p.nickName and p.nickName ~= "" then name = p.nickName end
                if p then
                    local c = _G._nadFfProfileCache[uid]
                    if not c then c = {} _G._nadFfProfileCache[uid] = c end
                    if c.nickName == nil and p.nickName ~= nil then c.nickName = p.nickName end
                    if c.level == nil and p.level ~= nil then c.level = p.level end
                    if c.picUrl == nil and p.picUrl ~= nil then c.picUrl = p.picUrl end
                    if c.sex == nil and p.sex ~= nil then c.sex = p.sex end
                    if c.cur_avatar_box_id == nil and p.cur_avatar_box_id ~= nil then c.cur_avatar_box_id = p.cur_avatar_box_id end
                    if c.nation == nil and p.nation ~= nil then c.nation = p.nation end
                    if c.segment_info == nil and p.segment_info ~= nil then c.segment_info = p.segment_info end
                end
            end)
            local status = nil
            if PlayerStatusMgr and PlayerStatusMgr.statusMap then
                status = PlayerStatusMgr.statusMap[uid] or PlayerStatusMgr.statusMap[tostring(uid)]
            end
            if not status and PlayerStatusMgr and PlayerStatusMgr.GetStatusData then
                status = PlayerStatusMgr:GetStatusData(uid)
            end
            local sRaw = _nadFfGetRaw(uid) or _nadFfSnapStatus(status)
            local mode, squad, state, since = "--", "--", "OFFLINE", "--"
            local stealthApplied = false
            mode, squad, state, since, stealthApplied = _nadFfApplyStealthRaw(sRaw, mode, squad, state, since, time_util)
            if not stealthApplied then
                mode, squad, state, since = _nadFfModeStateFromGameStatus(status, time_util, uid)
                if (status and (status.online == 0 or status.online == false)) then
                    local applied
                    mode, squad, state, since, applied = _nadFfApplyStealthRaw(sRaw, mode, squad, state, since, time_util)
                    if not applied then
                        state = "OFFLINE"
                        mode = _nadFfOfflineModeText(uid, time_util)
                    end
                end
            end
            lines[#lines + 1] = string.format("%s|%s|%s|%s|%s|%s",
                uid, _nadFfEsc(name), _nadFfEsc(mode), _nadFfEsc(squad), _nadFfEsc(state), _nadFfEsc(since))
        end
    end
    local content = table.concat(lines, "\n")
    if content == _G._nadFfLastExportStr then return end
    _G._nadFfLastExportStr = content
    local f = io.open("/data/share1/rapzhang_ff_ui.txt", "w")
    if f then
        f:write(content)
        f:close()
    end
end

local function _nadRequestFakeFriendStatus()
    -- Status/profil tidak berubah secepat tick; 15 dtk cukup dan
    -- menghindari spam batch request ke lobby.
    local now = os.time()
    if (now - (_G._nadFfLastStatusReq or -999.0)) < 15.0 then return end
    _G._nadFfLastStatusReq = now
    local friends = _G.HackAccountData and _G.HackAccountData.friends or {}
    local uidList = {}
    for _, uid in ipairs(friends) do
        uid = tonumber(uid)
        if uid and uid > 0 then uidList[#uidList + 1] = uid end
    end
    if #uidList == 0 then
        pcall(_G._nadExportFakeFriendUiFile)
        return
    end
    pcall(function()
        local logic_profile_get_wrap = require("client.slua.logic.user.profile.logic_profile_get_wrap")
        local cfg = Enum_PROFILE_REPORT_CFG and Enum_PROFILE_REPORT_CFG.FRIEND_ADD or 0
        logic_profile_get_wrap.GetFriendProfiles(cfg, uidList, function()
            pcall(_G._nadExportFakeFriendUiFile)
        end)
    end)
    -- Jalur yang dipakai game untuk "recommended friend" (bukan teman):
    -- ini yang mengisi logic_profile sehingga nama/avatar/rank tampil.
    pcall(function()
        local logic_profile_get_wrap = require("client.slua.logic.user.profile.logic_profile_get_wrap")
        local cfg = Enum_PROFILE_REPORT_CFG and Enum_PROFILE_REPORT_CFG.BATTLE_RESULT or 0
        if logic_profile_get_wrap and logic_profile_get_wrap.GetNormalProfiles then
            logic_profile_get_wrap.GetNormalProfiles(uidList, function()
                pcall(_G._nadExportFakeFriendUiFile)
            end, cfg)
        end
    end)
    pcall(function()
        local MM = require("client.module_framework.ModuleManager")
        local PlayerStatusMgr = MM.GetModule(MM.CommonModuleConfig.PlayerStatusMgr)
        local ENUM_BATCH_GET_GROUP_AND_ONLINE = require("client.slua.logic.player_status.player_status_macros").ENUM_BATCH_GET_GROUP_AND_ONLINE
        if PlayerStatusMgr and PlayerStatusMgr.GetOrReqStatusData then
            PlayerStatusMgr:GetOrReqStatusData(ENUM_BATCH_GET_GROUP_AND_ONLINE.AddFriend, uidList, function()
                pcall(_G._nadExportFakeFriendUiFile)
            end)
        end
        if PlayerStatusMgr and PlayerStatusMgr.send_batch_get_group_and_online_req then
            PlayerStatusMgr:send_batch_get_group_and_online_req(ENUM_BATCH_GET_GROUP_AND_ONLINE.AllFriend, uidList)
        end
    end)
end

-- ------------------------------------------------------------------
-- [FORCE FRIEND v2] Profil + merge friend list
-- Entri tampil seperti teman asli (nama/avatar/rank dari logic_profile,
-- online dari PlayerStatusMgr, urutan wajar) tanpa menulis relasi ke
-- server. Semua patch defensif: kalau method tidak ada, fallback ke
-- injeksi inner_list yang lama.
-- ------------------------------------------------------------------

-- Nilai tampilan untuk entri fake. Hanya field yang memang sudah dipakai
-- entri v1 (_nadEnsureFriendListSlot): intimacy + create_time. Jangan
-- menambah field baru ke tabel milik game; UI bisa memvalidasi schema.
local function _nadFfMeta(uid, idx)
    uid = tonumber(uid)
    if not uid then return nil end
    idx = tonumber(idx) or 1
    -- Basis waktu stabil: kalau memakai os.time() langsung, create_time
    -- berubah tiap detik dan UI bisa re-sort/flicker.
    _G._nadFfBaseTime = _G._nadFfBaseTime or os.time()
    return 300 + idx, _G._nadFfBaseTime - 90 * 86400 - idx * 3600
end

-- Enrich entri yang sudah ada (dibuat _nadEnsureFriendListSlot / notify
-- game) supaya tampil seperti teman lama, tanpa mengubah schema.
local function _nadFfEnrichEntry(e, uid, idx)
    if type(e) ~= "table" then return e end
    local intimacy, create_time = _nadFfMeta(uid, idx)
    if not intimacy then return e end
    if (tonumber(e.intimacy) or 0) < intimacy then e.intimacy = intimacy end
    e.create_time = create_time
    -- Bersihkan field tambahan dari versi v2 lama (hot reload).
    e.is_fake = nil
    return e
end

local function _nadFfFindIdx(uid)
    local friends = _G.HackAccountData and _G.HackAccountData.friends or {}
    for i, f in ipairs(friends) do
        if tonumber(f) == tonumber(uid) then return i end
    end
    return 1
end

local function _nadInstallFriendListPatch()
    local MM = require("client.module_framework.ModuleManager")
    local LFL = MM.GetModule(MM.CommonModuleConfig.logic_friend_list)
    if not LFL or LFL.__nadFfMapPatched then return end
    LFL.__nadFfMapPatched = true

    -- UI friend list meminta map tiap render. Kalau server baru mengganti
    -- inner_list, entri fake hilang; di sini slot dibuat ulang lewat jalur
    -- v1 (_nadEnsureFriendListSlot) lalu tabel entri game yang sama dipakai.
    local origMap = LFL.GetFriendInfoMap
    if type(origMap) == "function" then
        LFL.GetFriendInfoMap = function(self, ...)
            local map = origMap(self, ...)
            if type(map) ~= "table" then return map end
            -- Bungkus dengan pcall: kalau schema/build berbeda, map asli
            -- tetap dikembalikan dan UI tidak ikut rusak.
            pcall(function()
                local friends = _G.HackAccountData and _G.HackAccountData.friends or {}
                for i, f in ipairs(friends) do
                    local uid = tonumber(f)
                    if uid then
                        local e = map[uid] or map[tostring(uid)]
                        if not e then
                            pcall(_nadEnsureFriendListSlot, uid)
                            local rfl = LFL.res_friendlist
                            local il = rfl and rfl.inner_list
                            e = il and (il[uid] or il[tostring(uid)]) or nil
                            if e then map[uid] = e end
                        end
                        if e then _nadFfEnrichEntry(e, uid, i) end
                    end
                end
            end)
            return map
        end
    end

    -- GetFriendInfo hanya meng-enrich entri yang benar-benar ada. Jangan
    -- mensintesis entri: _nadEnsureFriendListSlot memakai inner_list untuk
    -- memutuskan pembuatan slot, dan UI mengharapkan schema game.
    local origInfo = LFL.GetFriendInfo
    if type(origInfo) == "function" then
        LFL.GetFriendInfo = function(a, b, ...)
            local info = origInfo(a, b, ...)
            -- Dukung pemanggilan colon (self, uid) maupun dot (uid).
            local uid = (type(a) == "table") and b or a
            if info and _nadFfIsFakeFriend(uid) then
                pcall(_nadFfEnrichEntry, info, uid, _nadFfFindIdx(uid))
            end
            return info
        end
    end
end

local function _nadInstallRelationPatch()
    local LogicFriend = require("client.slua.logic.friend.logic_new_friend")
    if not LogicFriend or LogicFriend.__nadFfRelationPatched then return end
    LogicFriend.__nadFfRelationPatched = true
    local origInner = LogicFriend.IsInnerFriend
    if type(origInner) == "function" then
        LogicFriend.IsInnerFriend = function(a, b, ...)
            local uid = (type(a) == "table") and b or a
            if _nadFfIsFakeFriend(uid) then return true end
            return origInner(a, b, ...)
        end
    end
    local origFriend = LogicFriend.IsFriend
    if type(origFriend) == "function" then
        LogicFriend.IsFriend = function(a, b, ...)
            local uid = (type(a) == "table") and b or a
            if _nadFfIsFakeFriend(uid) then return true end
            return origFriend(a, b, ...)
        end
    end
end

local function _nadApplyFakeFriends()
    _nadFfRebuildSet()
    local friends = _G.HackAccountData and _G.HackAccountData.friends or {}
    local FriendApplyHandler = require("client.network.Protocol.FriendApplyHandler")
    local LogicFriend = require("client.slua.logic.friend.logic_new_friend")
    local currentSet = {}
    for _, uid in ipairs(friends) do
        uid = tonumber(uid)
        if uid and uid > 0 then
            currentSet[uid] = true
            pcall(function() _nadEnsureFriendListSlot(uid) end)
            -- Modul friend dapat dibuat ulang saat masuk/keluar match. Jangan
            -- hanya mengandalkan cache _nadAppliedFriends; daftarkan ulang UID
            -- ke instance modul yang baru agar friendlist langsung muncul.
            pcall(function()
                if FriendApplyHandler and FriendApplyHandler.on_auto_add_inner_friend_notify then
                    FriendApplyHandler.on_auto_add_inner_friend_notify(uid)
                end
            end)
            pcall(function()
                if LogicFriend.IsInnerFriend and not LogicFriend.IsInnerFriend(uid) and LogicFriend.AddInnerFriend then
                    LogicFriend.AddInnerFriend(uid)
                end
            end)
            pcall(function()
                if LogicFriend.AddFriendData then LogicFriend.AddFriendData(uid) end
            end)
            _nadAppliedFriends[uid] = true
        end
    end
    for uid, _ in pairs(_nadAppliedFriends) do
        if not currentSet[uid] then
            _nadRemoveFakeFriend(uid)
        end
    end
    pcall(_nadInstallFriendListPatch)
    pcall(_nadInstallRelationPatch)
    pcall(_nadRequestFakeFriendStatus)
end

function _G._nadFfClearAll()
    local applied = {}
    for uid in pairs(_nadAppliedFriends) do applied[#applied + 1] = uid end
    for _, uid in ipairs(applied) do
        pcall(_nadRemoveFakeFriend, uid)
    end
    _G.HackAccountData.friends = {}
    _G._nadFfSet = {}
    _G._nadFfProfileCache = {}
    _G._nadFfRawCache = {}
    _G._nadFfLastExportStr = nil
end

pcall(function()
    if _G.__nadFakeFriendStatusHooked then return end
    _G.__nadFakeFriendStatusHooked = true
    pcall(function()
        local MM = require("client.module_framework.ModuleManager")
        local PSM = MM.GetModule(MM.CommonModuleConfig.PlayerStatusMgr)
        if not PSM then return end
        if PSM.statusMap then
            for uid, s in pairs(PSM.statusMap) do
                _nadFfCacheRaw(uid, s)
            end
        end
        if not PSM.__nadFfBatchHooked and PSM.on_batch_get_group_and_online_rsp then
            PSM.__nadFfBatchHooked = true
            local _origBatch = PSM.on_batch_get_group_and_online_rsp
            PSM.on_batch_get_group_and_online_rsp = function(self, listType, res, infos)
                if infos then
                    for uid, v in pairs(infos) do
                        _nadFfCacheRaw(uid, v)
                    end
                end
                local ret = _origBatch(self, listType, res, infos)
                pcall(_G._nadExportFakeFriendUiFile)
                return ret
            end
        end
        if not PSM.__nadFfSetHooked and PSM._SetStatusData then
            PSM.__nadFfSetHooked = true
            local _origSet = PSM._SetStatusData
            PSM._SetStatusData = function(self, uid, newStatus)
                _nadFfCacheRaw(uid, newStatus)
                return _origSet(self, uid, newStatus)
            end
        end
    end)
    pcall(function()
        if _G.__nadFfTeamApplyHooked then return end
        _G.__nadFfTeamApplyHooked = true
        local TeamUpNewSystem = require("client.slua.logic.teamup.logic_team_up")
        if not TeamUpNewSystem.on_team_apply_notify then return end
        local _origApplyNotify = TeamUpNewSystem.on_team_apply_notify
        TeamUpNewSystem.on_team_apply_notify = function(applierID, applierName, teamid, applyInfo)
            applierID = tonumber(applierID)
            if applierID and _nadFfIsFakeFriend(applierID) and TeamUpNewSystem.IsTeamLeader and TeamUpNewSystem.IsTeamLeader() then
                local from = TeamUpNewSystem.E_InviteFromType.FriendBar
                local src = (applyInfo and applyInfo.src) or "rapzhang_ff"
                local fromType = (applyInfo and applyInfo.from) or from
                local sig = (applyInfo and applyInfo.signatur) or ""
                TeamUpNewSystem.team_apply_reply(NetErrorCode_NONE, applierID, teamid, src, fromType, sig, applierName or _nadFfFriendDisplayName(applierID))
                return
            end
            return _origApplyNotify(applierID, applierName, teamid, applyInfo)
        end
    end)
    if EventSystem and EventSystem.registEvent and EVENTTYPE_FRIEND and EVENTID_BATCH_GET_PLAYERSTATUS then
        EventSystem:registEvent(EVENTTYPE_FRIEND, EVENTID_BATCH_GET_PLAYERSTATUS, function()
            pcall(_G._nadExportFakeFriendUiFile)
        end)
    end
end)
function _G.RapzhangFakeFriendApply(uids)
    if not (_G.RapzhangConfig and _G.RapzhangConfig.ForceFriend == true) then return false end
    -- Pemanggil yang sudah punya daftar UID (mis. FF.Tick) boleh
    -- mengopernya agar tidak memuat ulang file/cache.
    if type(uids) ~= "table" then
        local loader = _G.RapzhangFriendUID
        uids = loader and loader.Load and loader.Load() or {}
    end
    _G.HackAccountData = _G.HackAccountData or {}
    -- Daftar berubah? Jangan tunggu throttle 15 dtk; minta profil/status
    -- segera supaya nama/avatar tidak tampil sebagai UID mentah.
    if not (_G.RapzhangFriendUID and _G.RapzhangFriendUID.Equals(_G.HackAccountData.friends, uids)) then
        _G._nadFfLastStatusReq = nil
    end
    _G.HackAccountData.friends = uids
    pcall(_nadFfRebuildSet)
    pcall(_nadApplyFakeFriends)
    return true
end

-- Startup langsung jika Force Friend sudah aktif sebelum file dimuat.
-- Timer Boot yang ada tetap menjadi retry saat modul lobby belum siap.
if _G.RapzhangConfig and _G.RapzhangConfig.ForceFriend == true then
    pcall(function()
        if _G.RapzhangForceFriend and _G.RapzhangForceFriend.Boot then
            _G.RapzhangForceFriend.Boot()
        end
    end)
    pcall(_G.RapzhangFakeFriendApply)
    pcall(_G.RapzhangStartFriendSync)
end

-- Re-apply berkala diperlukan karena modul friend/status dapat dibuat ulang
-- oleh game setelah transisi lobby <-> match.
if not _G.RapzhangStartFriendSync then
    _G.RapzhangFriendSyncLoopStarted = false
    function _G.RapzhangStartFriendSync()
        if _G.RapzhangFriendSyncLoopStarted then return end
        _G.RapzhangFriendSyncLoopStarted = true
        local function syncStep()
            if not (_G.RapzhangConfig and _G.RapzhangConfig.ForceFriend == true) then
                _G.RapzhangFriendSyncLoopStarted = false
                return
            end
            pcall(_G.RapzhangFakeFriendApply)
            local scheduled = false
            local ok = pcall(function()
                local ticker = require("common.time_ticker")
                if ticker and ticker.AddTimerOnce then
                    ticker.AddTimerOnce(0.75, syncStep)
                    scheduled = true
                end
            end)
            if not ok or not scheduled then _G.RapzhangFriendSyncLoopStarted = false end
        end
        syncStep()
    end
end

if _G.RapzhangConfig and _G.RapzhangConfig.ForceFriend == true then
    pcall(_G.RapzhangStartFriendSync)
end

pcall(_G.RapzhangFakeFriendApply)

-- Hot-reload safety: sesi lama mungkin masih memasang wrapper MBCT pada
-- FastTick. Netralkan agar tidak menimpa cache hitbox yang baru.
if _G.RapzhangMBCrosshair then
  pcall(function()
    _G.RapzhangMBCrosshair.Tick = function() end
    _G.RapzhangMBCrosshair.ForceRestore = function() end
  end)
end

-- ============================================================================
-- [HEADSHOT FEATURE] — hitbox-only, server-safe
-- Headshot TIDAK mengubah HeadDamageMultiplier/BodyDamageMultiplier.
-- Nilai itu hanya prediksi client; server menghitung damage dari weapon
-- table miliknya sendiri. Yang benar-benar sampai ke server adalah BoneName
-- dari trace, jadi fitur ini hanya memperbesar hitbox head/neck (2x) lewat
-- mesin PhysicsAsset di atas. Ticker berjalan sendiri agar aktif walau ESP OFF.
-- ============================================================================
do
  local HEADSHOT = {
    Interval = 1.0,
    InitialDelay = 2.0,
  }
  _G.RapzhangHeadshotConfig = HEADSHOT

  local function HeadshotGameplayData()
    local ok, gd = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and gd then return gd end
    return nil
  end

  local function ApplyHeadshotHitbox()
    local hash, head, body, legs = _G.RapzhangGetHitboxScale(true)
    if hash == "OFF" or not _G.RapzhangApplyHitbox then return end

    local gd = HeadshotGameplayData()
    if not gd then return end

    local localPlayer = nil
    pcall(function() localPlayer = gd.GetPlayerCharacter() end)
    if not slua.isValid(localPlayer) then return end

    local allCharacters = {}
    pcall(function()
      if type(gd.GetAllPlayerCharacters) == "function" then
        allCharacters = gd.GetAllPlayerCharacters() or {}
      end
    end)
    if #allCharacters == 0 then
      pcall(function()
        if Game and type(Game.GetAllPlayerPawns) == "function" then
          allCharacters = Game:GetAllPlayerPawns() or {}
        end
      end)
    end

    for _, character in pairs(allCharacters) do
      if slua.isValid(character) and character ~= localPlayer and character.TeamID ~= localPlayer.TeamID then
        local mesh = nil
        pcall(function()
          mesh = character.Mesh or (type(character.getAvatarComponent2) == "function" and character:getAvatarComponent2() or nil)
        end)
        if slua.isValid(mesh) then
          local stateKey = nil
          pcall(function() stateKey = GetSafeEnemyKey(character) end)
          pcall(_G.RapzhangApplyHitbox, mesh, hash, head, body, legs, stateKey)
        end
      end
    end
  end

  -- ON  : clear stale cache lalu apply hitbox kepala 5x.
  -- OFF : clear cache/restore hitbox (tidak ada multiplier yang perlu di-restore).
  function _G.RapzhangHeadshotRefresh()
    local on = _G.RapzhangConfig and _G.RapzhangConfig.Headshot == true
    if _G.RapzhangHitboxConfigChanged then
      pcall(_G.RapzhangHitboxConfigChanged, true)
    end
    if on then
      pcall(ApplyHeadshotHitbox)
    end
    _G.RapzhangHeadshotActive = on
  end

  local function HeadshotTick()
    if _G.RapzhangConfig and _G.RapzhangConfig.Headshot == true then
      local gd = HeadshotGameplayData()
      local inMatch = false
      if gd and IsGameplayMatchActive then
        pcall(function() inMatch = IsGameplayMatchActive(gd) end)
      end
      if inMatch then
        pcall(ApplyHeadshotHitbox)
      end
    end

    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and type(ticker.AddTimerOnce) == "function" then
      pcall(ticker.AddTimerOnce, HEADSHOT.Interval, HeadshotTick)
    end
  end
  _G.RapzhangHeadshotTick = HeadshotTick

  -- Delay the first run so GameplayData/player pawns are ready.
  local okTicker, ticker = pcall(require, "common.time_ticker")
  if okTicker and ticker and type(ticker.AddTimerOnce) == "function" then
    pcall(ticker.AddTimerOnce, HEADSHOT.InitialDelay, HeadshotTick)
  end
end

-- NO-BRPLAYER MODE: payload dijalankan sebagai external module.
-- Tidak membuat atau mendaftarkan CBRPlayerCharacterBase.

-- Force IsDevelopment() = true so dev-mode code paths unlock.

return M
