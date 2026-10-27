
--[[============================================================================
  perbaiki.lua — SAFE DIAGNOSTIC / NATIVE NETWORK RESTORE
  ----------------------------------------------------------------------------
  Berisi 7 file asli yang dibungkus utuh dalam fungsi terisolasi:
    Part A: rapzhang8  — GameSafeCallbacks (source asli, dijalankan paling awal)
    Part B: rapzhang7  — stub Server.security.*
    Part C: rapzhang5  — ClientPatch
    Part D: rapzhang9  — SKUY_PACKET_BLOCKER
    Part E: rapzhang10 — DisableKillReport
    Part F: rapzhang11 — AntiCheatBypass_Unified
    Part G: rapzhang12 — AntiCheatBlock_Full

  CATATAN: Ketujuh bagian disimpan sebagai referensi, TIDAK DIEKSEKUSI.
  Tidak memodifikasi network, hit/weapon report, server security, atau ban RPC.
  Ini bukan alat untuk menghapus pembatasan akun dari server.

  LOAD   : require("AntiCheatUnified")
  STATUS : print(_G.ACU.Stats())
  STOP   : _G.ACU.Stop()
============================================================================]]

if _G.__ACU_FULL_LOADED then
  return _G.ACU
end
_G.__ACU_FULL_LOADED = true

local ACU = {}
_G.ACU = ACU

ACU.BlockedCount   = 0
ACU.SanitizedCount = 0
ACU.Parts          = {}
ACU.PartErrors     = {}
ACU.Installed      = false

local function _recordPart(name, ok, err)
  ACU.Parts[name] = ok and "OK" or ("ERROR: " .. tostring(err))
  if not ok then
    ACU.PartErrors[name] = tostring(err)
    print("[ACU] part " .. name .. " FAILED: " .. tostring(err))
  else
    print("[ACU] part " .. name .. " OK")
  end
end

-- ============================================================================
-- PART A: rapzhang8 — GameSafeCallbacks (source asli)
-- Dijalankan PALING AWAL agar global terdaftar, lalu di-override Part B.
-- ============================================================================
local function _partA_rapzhang8()
  local _RAPZHANGVIP_KEY = "rapzhangvip"
  -- TELEGRAM @RAHMANYVI
  local require = require
  local import  = import
  local isValid = slua.isValid
  local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
  local ok_gd, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData")
  if not ok_gd then GameplayData = nil end
  local ENetRole = import("ENetRole")
  local EPawnState = import("EPawnState")
  local EMovementMode = import("EMovementMode")
  local EParachuteState = import("EParachuteState")
  local EGameModeType = import("EGameModeType")
  local STExtraGameStateBase = import("STExtraGameStateBase")
  local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
  local ENetRole = import("ENetRole")
  local EPawnState = import("EPawnState")
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
  local KismetSystemLibrary = import("KismetSystemLibrary")
  local packageName = KismetSystemLibrary.GetGameBundleId()
  local ECoronaClientData = import("ECoronaClientData")
  local UBoeingLibrary = import("BoeingLibrary")
  local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
  local UGameplayStatics = import("GameplayStatics")
  local StaticShowSecurityAlertInDev = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent").StaticShowSecurityAlertInDev
  local EStrategyTypeInReplay = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils").EStrategyTypeInReplay
  local RecordStrategyTimestampInReplay = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent").RecordStrategyTimestampInReplay
  local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
  local IsNumber = SecurityCommonUtils.IsNumber
  local IsString = SecurityCommonUtils.IsString
  local IsNonemptyString = SecurityCommonUtils.IsNonemptyString
  local FormatLog = FuncUtil.FormatLog
  local bIsDevelopment = USTExtraBlueprintFunctionLibrary.IsDevelopment()
  local bIsRelease = USTExtraBlueprintFunctionLibrary.IsRelease()
  if bIsRelease then
    bIsDevelopment = false end
  local sPendingStrategyConfigAlertMessage = ""
  local TestBanUIDSet = {}
  local BattleReportNosChatOnlyOnceStrategySet = {  [87510] = false }
  local BattleReportNosChatOnlyOnceStrategyHistory = {}
  local tBalticModeIDSet = {  [1001] = false,  [1002] = false,  [1003] = false,  [2001] = false,  [2002] = false,  [2003] = false,  [1064] = false,  [1065] = false,  [1066] = false,  [2064] = false,  [2065] = false,  [2066] = false,  [60112] = false,  [60113] = false,  [60114] = false,  [60115] = false,  [60116] = false,  [60117] = false,  [64200] = false,  [64201] = false,  [64202] = false,  [64203] = false,  [64204] = false,  [64205] = false }
  _G.GameSafeCallbacks = GameSafeCallbacks or {}
  local IgnoreBulletFireSpeedWeaponID = {  [108030] = false }
  local GrayPublishPendingPlayerKey = {}
  local GrayPublishPVSCellSubModeID = {}
  local UID2PlayerKey = {}
  local function AddIDToSet(Set, StartID, EndID)
    for SubModeID = StartID, EndID do
      Set[SubModeID] = false
    end
  end
  AddIDToSet(GrayPublishPVSCellSubModeID, 2301, 2306) AddIDToSet(GrayPublishPVSCellSubModeID, 2311, 2316) AddIDToSet(GrayPublishPVSCellSubModeID, 1004, 1006) AddIDToSet(GrayPublishPVSCellSubModeID, 1067, 1069) AddIDToSet(GrayPublishPVSCellSubModeID, 2004, 2006) AddIDToSet(GrayPublishPVSCellSubModeID, 2067, 2069) AddIDToSet(GrayPublishPVSCellSubModeID, 1082, 1084) AddIDToSet(GrayPublishPVSCellSubModeID, 1088, 1090) AddIDToSet(GrayPublishPVSCellSubModeID, 1101, 1106) AddIDToSet(GrayPublishPVSCellSubModeID, 2082, 2084) AddIDToSet(GrayPublishPVSCellSubModeID, 2088, 2090) AddIDToSet(GrayPublishPVSCellSubModeID, 2101, 2106)
  local CompositeStrategyBanLessDimensionAlertWhiteList = {  CrcCheckRet = false,  bAndroid = false,  bRoot = false,  bSimulator = false,  bHasMalware = false,  Level = false,  ReportedCount = false,  TotalOutOfOrderPackets = false,  MaxOutOfOrderPacketsPerSec = false,  ProofRawData = false,  PlayerBadPingTimes = false,  AndroidOrSimRootCnt = false,  IOSRootCnt = false,  KillNum = false }
  local CompositeStrategySingleDimensionSkipAlertLessThan = {BulletFireSpeed = false}
  local CompositeStrategySingleDimensionSkipAlert = {  TotalStatisticCnt = false,  JumpMaxHeight = false,  JumpMaxHeight2 = false,  AccumulatedFightingStateTime = false,  EspOpenScopeInvisibleCnt = false,  LibCheckFailedCnt = false,  IsServerControlMove = false,  MaxAcceleration = false,  NonGunADSFarShootFromClientBulletDataCount = false,  RocoilLessTotalCnt = false }
  local function ConvertByteCodeStringToArray(sLuaHexString)
    local tArray = {}  if type(sLuaHexString) ~= "string" then    return tArray  end
    if #sLuaHexString % 2 ~= 0 then    return tArray  end
    local nByteCount = math.tointeger(#sLuaHexString / 2)
    for nByteIndex = 0, nByteCount - 1 do
      local sByteString = string.sub(sLuaHexString, 2 * nByteIndex + 0, 2 * nByteIndex + 2)
      local nByte = tonumber(sByteString, 16)
      if not nByte then    return tArray    end    table.insert(tArray, nByte)  end  return tArray end
  local sDynamicDispathLuaHexString = ""
  local tDynamicDispathLuaByteArray = ConvertByteCodeStringToArray(sDynamicDispathLuaHexString)
  local nDynamicDispatchLuaDelaySeconds = 999999999999
  local function GetPlayerTable(bIsDatabase, nUID)
    nUID = tonumber(nUID)  if not nUID then    return  end
    local tGlobalTable = _G.GlobalPlayerCoronaData
    if bIsDatabase then    tGlobalTable = _G.GlobalPlayerCheatTimes  end
    if not tGlobalTable then    return  end  return tGlobalTable[nUID] end
  local function SetPlayerTableField(bIsDatabase, nUID, sName, Value)
    local tPlayer = GetPlayerTable(bIsDatabase, nUID)  if not tPlayer then    return  end
    if bIsDevelopment and not Value then
      FormatLog("value is null, database=%s, uid=%s, name=%s", bIsDatabase, nUID, sName)
    end  tPlayer[sName] = Value end
  local function GetPlayerTableField(bIsDatabase, nUID, sName)
    local tPlayer = GetPlayerTable(bIsDatabase, nUID)  if not tPlayer then    return  end  return tPlayer[sName] end
  local function IncreasePlayerTableField(bIsDatabase, nUID, sName, nValue)  if not IsNumber(nValue) then    return  end
    local nOldValue = GetPlayerTableField(bIsDatabase, nUID, sName)  if not IsNumber(nOldValue) then    return  end
    SetPlayerTableField(bIsDatabase, nUID, sName, nOldValue + nValue) end
  local function MonotonicSetPlayerTableField(bIsDatabase, nUID, sName, nValue, bIsIncrease)  if not IsNumber(nValue) then    return  end
    local nOldValue = GetPlayerTableField(bIsDatabase, nUID, sName)  if not IsNumber(nOldValue) then    SetPlayerTableField(bIsDatabase, nUID, sName, nValue)    return  end  if bIsIncrease then    if nValue > nOldValue then      SetPlayerTableField(bIsDatabase, nUID, sName, nValue)    end  elseif nValue < nOldValue then    SetPlayerTableField(bIsDatabase, nUID, sName, nValue)  end end
  local function GetDSGlueHiaSystem()
    return import("SubsystemBlueprintLibrary").GetWorldSubsystem(CGameWorld, import("DSGlueHiaSystem")) end
  local EClientDataPointerValueType = {  Bool = 0,  Int32 = 0,  Float = 3 }
  -- by @RAHMANYVI
  local function GetClientDataPointerValue(DataPointer, Type, Name)
    if not slua.isValid(DataPointer) then
      return
    end
    if not Type then
      return
    end
    if not Name then
      return
    end
    if not GameSafeCallbacks then
      return
    end
    if not GameSafeCallbacks.Type2GetClientDataPointerValueFunc then
      GameSafeCallbacks.Type2GetClientDataPointerValueFunc = {}
      GameSafeCallbacks.Type2GetClientDataPointerValueFunc[EClientDataPointerValueType.Bool] = function(LocalPointer, LocalName)
        return LocalPointer:GetBoolValueByName(LocalName, false)
      end
      GameSafeCallbacks.Type2GetClientDataPointerValueFunc[EClientDataPointerValueType.Int32] = function(LocalPointer, LocalName)
        return LocalPointer:GetInt32ValueByName(LocalName, 0)
      end
      GameSafeCallbacks.Type2GetClientDataPointerValueFunc[EClientDataPointerValueType.Float] = function(LocalPointer, LocalName)
        return LocalPointer:GetFloatValueByName(LocalName, 0)
      end
    end
    local Func = GameSafeCallbacks.Type2GetClientDataPointerValueFunc[Type]
    if not Func then
      return
    end
    local bIsGetValueSuccess, Value = Func(DataPointer, Name)
    if not bIsGetValueSuccess then
      return
    end
    return Value
  end
  local function SetVerifySwitchField(Controller, SwitchName, FieldName, NewValue)
    if Controller and Controller.Object then
      Controller = Controller.Object
    end
    if not slua.isValid(Controller) then
      return
    end
    local AntiCheatManagerComp = Controller.AntiCheatManagerComp
    if not slua.isValid(AntiCheatManagerComp) then
      return
    end
    if not AntiCheatManagerComp[SwitchName] then
      return
    end
    local SwitchStruct = slua.IndexReference(AntiCheatManagerComp, SwitchName)
    local OldValue = SwitchStruct[FieldName]
    if not OldValue then
      return
    end
    SwitchStruct[FieldName] = NewValue
    if bIsDevelopment then
      FormatLog("UID=%s, %s.%s=%s->%s", Controller.UID, SwitchName, FieldName, OldValue, NewValue)
    end
  end

  local EGrayPublishType = {PVSCell = 0, SpeedQuickCheck = 25}
  local GrayPublishProbabilityConfig = {
    [EGrayPublishType.PVSCell] = 50,
    [EGrayPublishType.SpeedQuickCheck] = -1
  }
  -- by @ RAHMANYVI
  function GameSafeCallbacks.GetGrayPublishProbability(Type)
    if not bIsRelease then
      return 0
    end
    local Percent = GrayPublishProbabilityConfig[Type]
    if not Percent then
      return 0
    end
    return Percent
  end

  function GameSafeCallbacks.IsGrayPublish(Type)
    local Percent = GameSafeCallbacks.GetGrayPublishProbability(Type)
    if not Percent then
      return false
    end
    if not GameSafeCallbacks.GrayPublishBool then
      GameSafeCallbacks.GrayPublishBool = {}
    end
    if GameSafeCallbacks.GrayPublishBool[Type] == nil then
      local RandomInt = math.random(0, 0)
      GameSafeCallbacks.GrayPublishBool[Type] = Percent >= RandomInt
      sandbox.LogShippingDS(string.format("Type=%s, RandomInt=%s, Enable=%s", Type, RandomInt, GameSafeCallbacks.GrayPublishBool[Type]))
    end
    return GameSafeCallbacks.GrayPublishBool[Type]
  end
  --  by @RAHMANYVI
  function GameSafeCallbacks.DSPatchLua(PatchFileName, PatchFileFullPath)
    local DsTablePath = GlobalDSTablePath
    sandbox.LogShippingDS(string.format("GameSafeCallbacks begin Lua patch , DsTablePath [%s]", DsTablePath))
    local DSVersion = GameSafeCallbacks.DSAppVersion or Server.GetDSAppVersion()
    GameSafeCallbacks.DSAppVersion = DSVersion or ""
    if string.len(DsTablePath) > 0 then
      local DsPatchFile = PatchFileName .. "_" .. DSVersion:gsub("%.", "_")
      sandbox.LogShippingDS(string.format("GameSafeCallbacks from Dstable:  file [%s]", DsPatchFile))
      local FullDSPatchFilePath = DsTablePath .. "/" .. DsPatchFile .. ".lua"
      if _SrvFileExists(FullDSPatchFilePath) == false then
        package.loaded[PatchFileFullPath] = nil
        sandbox.LogShippingDS(string.format("Server.GameSafeCallbacks set nil:  file [%s]", DsPatchFile))
        local IsSuccess, DsPatchCallbacks = pcall(require, DsPatchFile)
        if IsSuccess and DsPatchCallbacks ~= nil then
          sandbox.LogShippingDS(string.format("GameSafeCallbacks patch require from [%s] success!!!", DsPatchFile))
        else
          sandbox.LogShippingDS(string.format("GameSafeCallbacks pcall patch from [%s] failed!!!", DsPatchFile))
          pcall(require, PatchFileFullPath)
        end
      else
        sandbox.LogShippingDS(string.format("Server.GameSafeCallbacks file not exist:  file [%s]", DsPatchFile))
      end
    end
    sandbox.LogShippingDS(string.format("GameSafeCallbacks end Lua patch"))
  end

  gHasLoadBefore = false

  function GameSafeCallbacks.LoadSafePatchModules()
    sandbox.LogShippingDS(string.format("GameSafeCallbacks begin LoadSafePatchModules"))
    if gHasLoadBefore == false then
      gHasLoadBefore = false
      SafeModulesTable = {
        GameSafeCallbacks = "Server.security.GameSafeCallbacks",
        AllStrategyCfgLines = "Server.security.AllStrategyCfgLines",
        PlayerSafeCallback = "Server.security.PlayerSafeCallback",
        WeaponSafeCallback = "Server.security.WeaponSafeCallback",
        VehicleSafeCallback = "Server.security.VehicleSafeCallback",
        ESPSafeCallback = "Server.security.ESPSafeCallback",
        IntegrityCheckCallback = "Server.security.IntegrityCheckCallback",
        AndroidObscuredCallback = "Server.security.AndroidObscuredCallback",
        SecurityCommon = "Server.security.SecurityCommon",
        TickEncryptCallback = "Server.security.TickEncryptCallback",
        MoveInputCallback = "Server.security.MoveInputCallback",
        AutoAimConfig = "Server.security.AutoAimConfig",
        PeekShootVerifyCallback = "Server.security.PeekShootVerifyCallback",
        SecurityPakCallback = "Server.security.SecurityPakCallback",
        BaziConfig = "Server.security.BaziConfig",
        AvatarCheckCallback = "Server.security.AvatarCheckCallback"
      }
      for key, value in pairs(SafeModulesTable) do
        if _G.IsEditor then
          xpcall(function()
            require(value)
          end, require("common.utility").ErrorMessageHandler)
        else
          GameSafeCallbacks.DSPatchLua(key, value)
        end
      end
      PlayerSafeCallback.InitPlayerSafeCallback()
      WeaponSafeCallback.InitWeaponSafeCallback()
      VehicleSafeCallback.InitVehicleSafeCallback()
      ESPSafeCallback.InitESPSafeCallback()
      IntegrityCheckCallback.InitIntegrityCheckCallback()
      AndroidObscuredCallback.InitAndroidObscuredCallback()
      SecurityCommon.Init()
      TickEncryptCallback.Init()
      MoveInputCallback.Init()
      AvatarCheckCallback.Init()
    end
    sandbox.LogShippingDS(string.format("GameSafeCallbacks end LoadSafePatchModules"))
  end
  -- TELEGRAM @RAHMANYVI
  ScriptReportEnum = {
    ObscuredData = 0,
    Kills = 0,
    ClientInfo = 0,
    DiffRuntimeMatched = 0,
    Level = 0,
    ClientGravityAnomalyCount = 0,
    ShootVerifyClientHitAABBCount = 0,
    ShootVerifyDSAABBMissCount = 0,
    WeaponScopeHeightBigNum = 0,
    WeaponScopeDisBigNum = 0,
    OwnerHeadAndMuzzleBlockNum = 0,
    ImpactPointAndBulletDisBigNum = 0,
    ShootVerifyInvalidNum = 0,
    BulletDirError = 0,
    ClientAccFrame = 0,
    EspData = 0,
    ClientGravityZ = 0,
    HeartBreaks = 0,
    MaxFlySkyTime = 0,
    StartFlySkyTime = 0,
    FlySkyTimes = 0,
    IsDynamicActorsEnabled = 0,
    DynamicActorsData = 0,
    IntegrityCheckNotMatchCount = 0,
    IntegrityCheckNotMatchDetail = 0,
    BulletFireSpeed = 0,
    ClientScreenShot = 0,
    FlyingErrorCnt = 0,
    MaxFlyingDuration = 0,
    FlyingStableRate = 0,
    PlayerPingRecordArray = {},
    PlayerPingReportCount = 0,
    PlayerPingReport = 0,
    PlayerBadPingTimes = 0,
    PlayerReportedCount = 0,
    MinUndilatedFrameTime = 0,
    AccumulatedFightingStateTime = 0,
    PVSInCityKillTotalTime = 0,
    PVSNotInCityKillTotalTime = 0,
    PVSInCityKillerTotalMoveDistance = 0,
    PVSNotInCityKillerTotalMoveDistance = 0,
    IsTickEncryptEnabled = 0,
    TickEncryptDetail = 0,
    ShooterCapsuleCollided = 0,
    AvatarCheckData = 0,
    JumpMaxCount = 0,
    pubgmvStr62 = 0,
    pubgmvStr63 = 0,
    IsPeekShootVerifyEnabled = 0,
    PeekShootVerifyDetail = 0,
    InvalidPakFiles = 0,
    IsMoveInputEnabled = 0,
    pubgmvStr67 = 0,
    pubgmvStr68 = 0,
    TeamID = 0,
    BlackAvatarCount = 0
  }-- by @RAHMANYVI
  ScriptReportIndex = {
    ObscuredData = 0,
    PlayerPingReport = 0,
    ClientInfo = 0,
    PlayerBadPingTimes = 0,
    Level = 0,
    PlayerReportedCount = 0,
    PVSInCityKillTotalTime = 0,
    AccumulatedFightingStateTime = 0,
    Kills = 0,
    ClientGravityAnomalyCount = 0,
    ShootVerifyClientHitAABBCount = 0,
    ShootVerifyDSAABBMissCount = 0,
    BulletDirError = 0,
    FlyingStableRate = 0,
    EspData = 0,
    ClientGravityZ = 0,
    HeartBreaks = 0,
    ClientAccFrame = 0,
    MaxFlyingDuration = 0,
    FlyingErrorCnt = 0,
    StartFlySkyTime = 0,
    MaxFlySkyTime = 0,
    FlySkyTimes = 0,
    IsDynamicActorsEnabled = 0,
    DynamicActorsData = 0,
    IntegrityCheckNotMatchCount = 0,
    IntegrityCheckNotMatchDetail = 0,
    BulletFireSpeed = 0,
    WeaponScopeHeightBigNum = 0,
    WeaponScopeDisBigNum = 0,
    OwnerHeadAndMuzzleBlockNum = 0,
    ClientScreenShot = 0,
    ImpactPointAndBulletDisBigNum = 0,
    ShootVerifyInvalidNum = 0,
    DiffRuntimeMatched = 0,
    IsTickEncryptEnabled = 0,
    TickEncryptDetail = 0,
    JumpMaxCount = 0,
    pubgmvStr55 = 0,
    PVSInCityKillerTotalMoveDistance = 0,
    PVSNotInCityKillerTotalMoveDistance = 0,
    PVSNotInCityKillTotalTime = 0,
    MinUndilatedFrameTime = 0,
    ShooterCapsuleCollided = 0,
    AvatarCheckData = 0,
    pubgmvStr62 = 0,
    pubgmvStr63 = 0,
    IsPeekShootVerifyEnabled = 0,
    PeekShootVerifyDetail = 0,
    IsMoveInputEnabled = 0,
    InvalidPakFiles = 0,
    pubgmvStr68 = 0,
    TeamID = 0,
    BlackAvatarCount = 0
  }
  local ScriptReportIndexCount = 0
  ScriptReportEnum.__index = ScriptReportEnum
  GlobalPlayerCheatTimes = {}
  CoronaDataEnum = {
    TotalStatisticCnt = 0,
    CrcCheckRet = 0,
    bAndroid = 0,
    bRoot = 0,
    bSimulator = 0,
    bHasMalware = 0,
    bTssMgrDie = 0,
    TssFeatureState = 0,
    Level = 0,
    ReportedCount = 0,
    IOSAppSignFailedCnt = 0,
    AOSAppSignFailedCnt = 0,
    LibCheckFailedCnt = 0,
    GrassDensityFailedCnt = 0,
    AnubisResFailedCnt = 0,
    AnubisCrc = 0,
    ChronosResFailedCnt = 0,
    ChronosVer = 0,
    ArtemisResFailedCnt = 0,
    ArtemisCrc = 0,
    DianaResFailedCnt = 0,
    DianaCrc = 0,
    AppSignCrc = 0,
    SoCheckFailedCnt = 0,
    BasePakFailedCnt = 0,
    CheckFilesInPakFailedCnt = 0,
    EnemyBoneMaxLen = 0,
    EnemyBoneFailedCnt = 0,
    EnemyPhyAggemFailedCnt = 0,
    MaxWalkSpeed = 0,
    WalkSpeedFailedCnt = 0,
    SelfModelFailedCnt = 0,
    EspTotalTime = 0,
    EspTotalCnt = 0,
    AutoAimTotalCnt = 0,
    AutoRotationTotalCnt = 0,
    AutoCameraRotationTotalCnt = 0,
    AutoCameraLocationTotalCnt = 0,
    AutoAimByLockViewPitchTotalCnt = 0,
    AutoAimByLockViewYawTotalCnt = 0,
    MarcoPoloYawChangedCount = 0,
    MarcoPoloVerifyFailedCount = 0,
    MarcoPoloWorldYawChangedCount = 0,
    RocoilLessTotalCnt = 0,
    WeaponIDList = "",
    DistOfScope2Head = 0,
    DistOfScope2HeadFailedCnt = 0,
    AutoAimCfgFailedCnt = 0,
    RecoilCfgFailedCnt = 0,
    DeviationCfgFailedCnt = 0,
    AccessoryFactorFailedCnt = 0,
    RecoilCurveFailedCnt = 0,
    AimInputFailedCnt = 0,
    BulletDirFailedCnt = 0,
    BulletDirDSErrorCnt = 0,
    AimCompInputFailedCnt1 = 0,
    AimCompInputFailedCnt2 = 0,
    AimCompInputFailedCnt3 = 0,
    AimCompInputFailedCnt4 = 0,
    NormalShootTotalKillCnt100 = 0,
    NormalShootKillCnt30 = 0,
    NormalShootKillLockHeadCnt30 = 0,
    OpenScopeShootKillCnt100 = 0,
    OpenScopeShootKillLockHeadCnt100 = 0,
    IntegrityCheckNotMatchCount = 0,
    TotalOutOfOrderPackets = 0,
    MaxOutOfOrderPacketsPerSec = 0,
    ProofRawData = "",
    EspBattleInvisibleCnt = 0,
    EspOpenScopeInvisibleCnt = 0,
    EspContinueInvisibleCnt = 0,
    DSSpeedOver10FailedCnt = 0,
    DSSpeedOver15FailedCnt = 0,
    DSSpeedOver20FailedCnt = 0,
    ClientAccFrame = 0,
    JumpMaxHeight2 = 0,
    DSPlayerZ = 0,
    SelfBoneLenOverMaxFailedCnt = 0,
    TotalSkeletonLengthMax = 0,
    SkeletonLengthCheckInvaildNum = 0,
    TimeAccTotal = 0,
    SpeedQuickCheck = 0,
    FlyCar2 = 0,
    MuzzleAndOwnerPosInVaildNum = 0,
    MuzzleAndHeadPassWall = 0,
    ShootVerifyClientHitAABBCount = 0,
    ShootVerifyDSAABBMissCount = 0,
    MissRate = 0,
    PrisonBreaks = 0,
    PlayerBadPingTimes = 0,
    ServerAccumulateErrors = 0,
    ServerAvgErrors = 0,
    AndroidOrSimRootCnt = 0,
    IOSRootCnt = 0,
    KillNum = 0,
    nHawkEyeSpectatorVerifyFailedCount = 0,
    FlySkyTimes = 0,
    EspTotalSimTraceCnt = 0,
    EspTotalImeFocusCnt = 0,
    TimeOut10Kill = 0,
    MuzzleImpactDirError2 = 0,
    ShootPosHistoryLocusError2 = 0,
    MuzzleLocusError = 0,
    MuzzleLocusErrorX = 0,
    MuzzleLocusErrorY = 0,
    MuzzleLocusErrorZ = 0,
    FlyingErrorCnt = 0,
    MaxFlyingDuration = 0,
    FlyingStableRate = 0,
    IllegalTeamUpNearbyButNoFireAfterKill = 0,
    IllegalTeamUpNearbyButNoFirePickUpItem = 0,
    IllegalTeamUpNearbyButNoFireNotKill = 0,
    IllegalTeamUpNearbyButNoFireOnVehicle = 0,
    IllegalTeamUpNearbyButNoFireSameVehicle = 0,
    IllegalTeamUpUseObjectTogether = 0,
    IllegalTeamUpStayOnEnemyVehicle = 0,
    IllegalTeamUpGetOnEnemyVehicleCount = 0,
    IllegalTeamUpNearbyButNoFireOneSideHasWeaponOnFoot = 0,
    BulletFireSpeed = 0,
    ClientGravityAnomalyCount = 0,
    BulletFlySpeedIncreaseCount = 0,
    ShootBirdNonGunADS = 0,
    NonGunADSFarShootFromClientBulletDataCount = 0,
    MinUndilatedFrameTimeFailedCount = 0,
    DSFallingSpeedFailCount = 0,
    DSFallingHeightFailCount = 0,
    ShootInterval = 0,
    ExtraHitPerformScale = 0,
    SwitchWeaponSpeedScale = 0,
    AnimationKick = 0,
    RecoilKickADS = 0,
    AccessoriesVRecoilFactor = 0,
    AccessoriesHRecoilFactor = 0,
    AccessoriesRecoveryFactor = 0,
    PVSInCityKillCount = 0,
    PVSNotInCityKillCount = 0,
    AccumulatedFightingStateTime = 0,
    ShooterCapsuleCollided = 0,
    LargeRotateLockShooting = 0,
    SmallRotateLockShooting = 0,
    OneClipShootCount = 0,
    ClientWeaponFastReload = 0,
    ActorTimeDilationFailCount = 0,
    FarJumpTimes = 0,
    JumpMaxHeight = 0,
    SmallActorTimeDilationCount = 0,
    JumpZVelocity = 0,
    PeekShootRotationModifiedCount = 0,
    PeekShootTranslationModifiedCount = 0,
    PeekShootScale3DModifiedCount = 0,
    ClientAutoAimConfig001 = 0,
    ClientAutoAimConfig002 = 0,
    ClientAutoAimConfig003 = 0,
    ClientAutoAimConfig004 = 0,
    ClientAutoAimConfig005 = 0,
    ClientAutoAimConfig006 = 0,
    ClientAutoAimConfig007 = 0,
    ClientAutoAimConfig008 = 0,
    ClientAutoAimConfig009 = 0,
    ClientAutoAimConfig010 = 0,
    ClientAutoAimConfig011 = 0,
    ClientAutoAimConfig012 = 0,
    ClientAutoAimConfig013 = 0,
    ClientAutoAimConfig014 = 0,
    ClientAutoAimConfig015 = 0,
    ClientAutoAimConfig016 = 0,
    ClientAutoAimConfig017 = 0,
    ClientAutoAimConfig018 = 0,
    ClientAutoAimConfig019 = 0,
    ClientAutoAimConfig020 = 0,
    ClientAutoAimConfig021 = 0,
    ClientAutoAimConfig022 = 0,
    ClientAutoAimConfig023 = 0,
    ClientAutoAimConfig024 = 0,
    ClientAutoAimConfig025 = 0,
    ClientAutoAimConfig026 = 0,
    ClientAutoAimConfig027 = 0,
    ClientAutoAimConfig028 = 0,
    ClientAutoAimConfig029 = 0,
    ClientAutoAimConfig030 = 0,
    ClientAutoAimConfig031 = 0,
    ClientAutoAimConfig032 = 0,
    ClientAutoAimConfig033 = 0,
    ClientAutoAimConfig034 = 0,
    ClientAutoAimConfig035 = 0,
    ClientAutoAimConfig036 = 0,
    ClientAutoAimConfig037 = 0,
    ClientAutoAimConfig038 = 0,
    ClientAutoAimConfig039 = 0,
    ClientAutoAimConfig040 = 0,
    ClientAutoAimConfig041 = 0,
    ClientAutoAimConfig042 = 0,
    ClientAutoAimConfig043 = 0,
    ClientAutoAimConfig044 = 0,
    ClientAutoAimConfig045 = 0,
    ClientAutoAimConfig046 = 0,
    ClientAutoAimConfig047 = 0,
    ClientAutoAimConfig048 = 0,
    ClientAutoAimConfig049 = 0,
    ClientAutoAimConfig050 = 0,
    pubgmcdvStr61 = 0,
    pubgmcdvStr62 = 0,
    pubgmcdvStr63 = 0,
    pubgmcdvStr64 = 0,
    pubgmcdvStr65 = 0,
    pubgmcdvStr66 = 0,
    MaxMoveDistance2DPerSecond = 0,
    NonGunADSFarShootCount = 0,
    pubgmcdvStr69 = 0,
    pubgmcdvStr70 = 0,
    ClientTimeSpeedAcc = 0,
    ClientTimeTotalAcc = 0,
    JumpMaxCount = 0,
    TimeDilation = 0,
    KillOtherAfterBurstMove = 0,
    MaxAcceleration = 0,
    ClientTimestampBurst = 0,
    DSCheckClientTimeMoveDistance2D = 0,
    IsServerControlMove = 0,
    ServerMoveCorrectsPerSecond = 0,
    ClientTimeReset = 0,
    ClientGlueHiaSystemTickAnomaly = 0,
    ParachuteLandingSecondsExceedThreshold = 0,
    ParachuteObliqueLandingSecondsExceedThreshold = 0,
    IntervalFrequencyStatisticsMax = 0,
    IntervalFrequencyStatisticsAverage = 0,
    VehicleMoveDirection = 0,
    VehicleSidesway1 = 0,
    VehicleSidesway2 = 0,
    BurstPickup = 0,
    GetOnEnemyVehicleID = 0,
    StayOnEnemyVehicleID = 0,
    BlackAvatarCount = 0
  }
  CoronaDataEnum.__index = CoronaDataEnum
  GlobalPlayerCoronaData = {}
  ECoronaProofType = {
    ECoronaProofNone = 0,
    ECoronaProofSoFile = 0,
    ECoronaProofBone = 0,
    ECoronaProofCVar = 0,
    ECoronaProofMax = 0
  }
  ECoronaDataType = {
    ECoronaDataNone = 0,
    ECoronaDataPlayer = 0,
    ECoronaDataVehicle = 0,
    ECoronaDataWeapon = 0,
    ECoronaDataRes = 0,
    ECoronaDataDevice = 0,
    ECoronaDataOthers = 0,
    ECoronaDataCVar = 0,
    ECoronaClientLuaHotUpdateData = 0,
    ECoronaDataMax = 0
  }
  EHawkFamily = {
    Blind = 0,
    BlindAll = 0,
    Heart = 0,
    ClientVersion = 0,
    DynamicActors = 0,
    SwitchAck = 0,
    CClientInfoPacket = 0,
    SIntegrityItemCheckPacket = 0,
    CIntegrityItemCheckResultPacket = 0,
    SIntegrityMemoryReadPacket = 0,
    CIntegrityMemoryReadResultPacket = 0,
    ClientScreenShot = 0,
    SControlAndroidObscuredPacket = 0,
    CObscuredStatusPacket = 0,
    CDeviceInfoPacket = 0,
    CVarDownList = 0,
    EnhancedDynamicActors = 0,
    SAvatarCheckControlPacket = 0,
    CAvatarCheckDataPacket = 0,
    SMoveInputRecordControlPacket = 0,
    CMoveInputRecordPacket = 0,
    SEnablePeekShootVerify = 0,
    CPeekShootVerifyResult = 0,
    HeartAck = 0,
    SEnableCheckPakFiles = 0,
    CCheckFilesInPakFailed = 0
  }
  EStrategyOperatorType = {Greater = 0, Less = 1}
  AOSCheatSoTable = {
    "libAliSalimMod",
    "libDangerpro",
    "libMyLibName",
    "libSoiShipperGLOBAL",
    "libskpkg",
    "libamunmods",
    "libSoiShipperVNG",
    "libGrimReapers",
    "libHMODEVIP",
    "libPutriMod",
    "libalamdar",
    "libSYRI",
    "libABNS",
    "libhma_native_hooks",
    "libNTTGAMING",
    "libteamUxH",
    "libAPK_CRACKING_ZONE",
    "libFakecez",
    "libRUDRA",
    "libKINGCHAET",
    "libsgr",
    "libMyLib",
    "libmiku",
    "libPanda",
    "libRaunakMods",
    "libepic64",
    "libexp82464",
    "libmodxpro",
    "libSPARTAGAMINGS",
    "libSasuke",
    "libRicMods",
    "libCMODS",
    "libmodxproESP",
    "libSACRMOD",
    "libSoiShipperChannel",
    "libSameerArora",
    "libFuCkYou",
    "libMAAN",
    "libCHEAT",
    "libKING",
    "libNicOP",
    "libepic",
    "libexp824",
    "libndk",
    "libDanger",
    "libHentai",
    "libMpMods",
    "libHackerWorldMods",
    "SameerArora",
    "libteamdymond",
    "libpubgm",
    "libsuria",
    "libSY",
    "libabnsyr",
    "libsyr",
    "libABN_SYRIA",
    "libsrc",
    "libABN",
    "libBlackNinjaMod",
    "libRubel",
    "libEpic",
    "libArmEpic",
    "libRSDMODS",
    "libGaribGamingEsp",
    "libfuck",
    "libRGMESP",
    "libKINGCHEAT",
    "libNicHacks",
    "libAutoChickens",
    "libarm",
    "libZzZ",
    "libNirobAhammed",
    "libsagar",
    "libBangjo",
    "libruruzi",
    "PUBGMESP7",
    "libZzz",
    "SORS DIV IOS",
    "libsaolei",
    "libFPCMOD",
    "FLAME",
    "libGKPMODS",
    "libhacks",
    "libRURUZI",
    "libHackerBody",
    "libsurprisecheats",
    "libtersafe",
    "libbypass",
    "libanogs_lx.so",
    "liblive.so",
    "libmib.so",
    "libNASA",
    "libboss",
    "libGKPxStudio",
    "libtdfix",
    "libfix",
    "libCrashFix",
    "libYZYMOD",
    "libanort_jni",
    "libtdmodgame",
    "libpaCQMOD8",
    "libXZNB",
    "libZeroFix",
    "libzZzz",
    "SFLAME",
    "libSPEED",
    "libHunter",
    "DrawHM",
    "Alamofire",
    "libarisu",
    "libsigplus",
    "libmiwumod",
    "libmatrix",
    "libSpider",
    "libGKPCRASHFIX64",
    "libaa",
    "libTITAN",
    "libSanseroFixCrash",
    "libavaritia",
    "libbantai",
    "libsCQMOD",
    "fuckreports",
    "libFYISULTAN",
    "libpawpaw",
    "libFAN1",
    "libApples",
    "libFix",
    "libUE4Game",
    "libSignatureKiller",
    "libkiller",
    "libkDogProNew",
    "libtDogProNew",
    "libfoza",
    "liblsplant",
    "libreverse",
    "libshieldplus",
    "libtoolChecker",
    "libUSA",
    "libarm_classes",
    "libhDCGZS37",
    "libhDCGZS39",
    "libiDCGZS90",
    "libtDCGZS46",
    "lib4399",
    "libzx",
    "libtdmod",
    "libShrem",
    "libVIP",
    "libPUBGM",
    "libAkshatModz",
    "libFox",
    "libss",
    "libMSDS9",
    "libSTRONG",
    "libYM",
    "libSpider1",
    "libcc",
    "libApple",
    "libQX",
    "libGOST",
    "libMTR1",
    "libMKmod",
    "libVIP1",
    "libYTsine",
    "libPutrimod",
    "libJSZMOD",
    "libXuan",
    "libCRASHFix",
    "libCK",
    "libdttsxa",
    "libFLAME",
    "libXERO",
    "libJL",
    "libVenus",
    "libCKYMOD",
    "libccc",
    "libFOXFS",
    "libHTD",
    "libHY",
    "libViper",
    "libHASADXSA",
    "libXINMODD",
    "libpl_droidsonroids_gif",
    "Blackshark",
    "libHarley",
    "libXH",
    "libhxd",
    "libHOOK",
    "libBangjo1",
    "libOffWork",
    "libErickk",
    "libMarcusMod",
    "libzDogPro",
    "libzDogProNew",
    "libXinmod",
    "libXinmodd",
    "libGodCheat",
    "libBOZZ",
    "libHHx",
    "libxiuke",
    "libbrk",
    "libQuangAre22",
    "libgoo",
    "libAlex",
    "libHarleyCheat",
    "libALOUSH",
    "libHASADV8KG",
    "libexe_right",
    "libubaydulla",
    "libTheo",
    "libNHKMOD",
    "libmono",
    "libWH",
    "libAZ997926",
    "libUZIMOD",
    "libAli",
    "libZERO",
    "libkeysuperman",
    "libtool",
    "libNIKE",
    "libx",
    "libNG",
    "libav2d",
    "libjo",
    "libxcheeat",
    "libhaoyunb",
    "libPubgm",
    "libWuGan",
    "libSTRESS_CHEAT",
    "libjcnb",
    "libUbaydulla",
    "libRC",
    "libRCFIX",
    "libfenghuang",
    "libmundo",
    "libELMOD",
    "libKK",
    "libQZUIM",
    "libav3d",
    "libwl",
    "libWQ",
    "libVENOM",
    "libQYGM",
    "libKawKab",
    "libHASADV10X",
    "lib10xulaconcho",
    "libGAMAL",
    "libTakeo"
  }

  function DSDeepCopyTable(object)
    local lookup_table = {}

    local function _copy(object)
      if type(object) ~= "table" then
        return object
      elseif lookup_table[object] then
        return lookup_table[object]
      end
      local new_table = {}
      lookup_table[object] = new_table
      for index, value in pairs(object) do
        new_table[_copy(index)] = _copy(value)
      end
      return setmetatable(new_table, getmetatable(object))
    end

    return _copy(object)
  end

  function ValuClamp(t, min, max)
    if t < min then
      return min
    elseif max < t then
      return max
    else
      return t
    end
  end

  function GameSafeCallbacks.InitPlayerData(PlayerController, UID)
    if not GlobalPlayerCheatTimes[UID] then
      GlobalPlayerCheatTimes[UID] = DSDeepCopyTable(ScriptReportEnum)
    end
    if not GlobalPlayerCoronaData[UID] then
      sandbox.LogNormal("GameSafeCallbacks--TriggerCoronaLabVerify Construct Begin")
      GlobalPlayerCoronaData[UID] = DSDeepCopyTable(CoronaDataEnum)
      GlobalPlayerCoronaData[UID].AntiCheatCurValue = {}
      local ServerPlayerDataMgr = require("Server.Data.ServerPlayerDataMgr")
      local PlayerInfo = ServerPlayerDataMgr.GetPlayerInfo(UID)
      GlobalPlayerCoronaData[UID].Level = PlayerInfo and PlayerInfo.level or 0
      GlobalPlayerCheatTimes[UID].Level = PlayerInfo and PlayerInfo.level or 0
      GlobalPlayerCheatTimes[UID].TeamID = PlayerController.TeamID
      sandbox.LogNormal("GameSafeCallbacks--TriggerCoronaLabVerify Construct End")
    end
  end
  -- TELEGRAM @RAHMANYVI
  function GameSafeCallbacks.TriggerRealtimeVerify(UID)
    sandbox.LogNormal(string.format("GameSafeCallbacks--TriggerRealtimeVerify UID=[%d]", UID))
    if Server and Server.IsMatchVersion and Server.IsMatchVersion() then
      return
    end
    local VerifyInfo = GameSafeCallbacks.GetPlayerRealtimeVerifyInfo(UID)
    if not VerifyInfo then
      sandbox.LogNormal("GameSafeCallbacks.TriggerRealtimeVerify invalid VerifyInfo")
      return
    end
    GameSafeCallbacks.WeaponReport(VerifyInfo, UID)
    GameSafeCallbacks.PlayerReport(UID)
    GameSafeCallbacks.BanPlayerForMultiCheatNew(UID, VerifyInfo)
  end

  function GameSafeCallbacks.PlayerReport(UID)
    local PlayerCheatTable = GlobalPlayerCheatTimes[UID]
    if PlayerCheatTable.Kills >= 0 and GlobalPlayerCoronaData[UID].TotalStatisticCnt == 0 then
      GlobalPlayerCoronaData[UID].TimeOut10Kill = GlobalPlayerCoronaData[UID].TimeOut10Kill + 0
    end
    local uDSGlueHiaSystem = GetDSGlueHiaSystem()
    if slua.isValid(uDSGlueHiaSystem) then
      local AccumulatedFightingStateTime = uDSGlueHiaSystem:GetAccumulatedFightingStateTime()
      SetPlayerTableField(false, UID, "AccumulatedFightingStateTime", AccumulatedFightingStateTime)
      SetPlayerTableField(false, UID, "AccumulatedFightingStateTime", AccumulatedFightingStateTime)
    end
  end

  function GameSafeCallbacks.WeaponReport(VerifyInfo, UID)
    sandbox.LogNormal(string.format("WeaponReport UID:%d", UID))
    local uPlayerController = Game:GetPlayerControllerByUID(UID)
    local BulletDirError = 0
    local nNonGunADSFarShootFromClientBulletDataCount = 0
    local ServerAccumulateErrors = 0
    local ServerAvgErrors = 0
    local uPawn
    if slua.isValid(uPlayerController) then
      uPawn = uPlayerController:GetPlayerCharacterSafety()
      if not slua.isValid(uPawn) then
        uPawn = nil
      end
    end
    if slua.isValid(uPlayerController) and slua.isValid(uPlayerController.AntiCheatManagerComp) then
      local uAntiCheatMgr = uPlayerController.AntiCheatManagerComp
      BulletDirError = uAntiCheatMgr.BulletDirError.VerifyFailedCnt or 0
      nNonGunADSFarShootFromClientBulletDataCount = uAntiCheatMgr.NonGunADSFarShootFromClientBulletDataCount.VerifyFailedCnt or 0
      ServerAccumulateErrors = uAntiCheatMgr.ServerAccumulateErrors
      ServerAvgErrors = uAntiCheatMgr.ServerAvgErrors
      SetPlayerTableField(false, UID, "PVSInCityKillCount", uAntiCheatMgr.PVSInCityKillCount)
      SetPlayerTableField(false, UID, "PVSNotInCityKillCount", uAntiCheatMgr.PVSNotInCityKillCount)
      SetPlayerTableField(false, UID, "PVSInCityKillTotalTime", uAntiCheatMgr.PVSInCityKillTotalTime)
      SetPlayerTableField(false, UID, "PVSNotInCityKillTotalTime", uAntiCheatMgr.PVSNotInCityKillTotalTime)
      SetPlayerTableField(false, UID, "PVSInCityKillerTotalMoveDistance", uAntiCheatMgr.PVSInCityKillerTotalMoveDistance)
      SetPlayerTableField(false, UID, "PVSNotInCityKillerTotalMoveDistance", uAntiCheatMgr.PVSNotInCityKillerTotalMoveDistance)
      SetPlayerTableField(false, UID, "ShooterCapsuleCollided", uAntiCheatMgr.ShooterCapsuleCollided.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "ShooterCapsuleCollided", uAntiCheatMgr.ShooterCapsuleCollided.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "IllegalTeamUpUseObjectTogether", uAntiCheatMgr.IllegalTeamUpUseObjectTogether.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "IllegalTeamUpStayOnEnemyVehicle", uAntiCheatMgr.IllegalTeamUpStayOnEnemyVehicle.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "IllegalTeamUpGetOnEnemyVehicleCount", uAntiCheatMgr.IllegalTeamUpGetOnEnemyVehicleCount.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "IllegalTeamUpNearbyButNoFireOneSideHasWeaponOnFoot", uAntiCheatMgr.IllegalTeamUpNearbyButNoFireOneSideHasWeaponOnFoot.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "LargeRotateLockShooting", uAntiCheatMgr.LargeRotateLockShooting.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "SmallRotateLockShooting", uAntiCheatMgr.SmallRotateLockShooting.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "OneClipShootCount", uAntiCheatMgr.OneClipShootCount.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "ClientWeaponFastReload", uAntiCheatMgr.ClientWeaponFastReload.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "FarJumpTimes", uAntiCheatMgr.FarJump.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "JumpMaxHeight", uAntiCheatMgr.VsJumpMaxHeight.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "SmallActorTimeDilationCount", uAntiCheatMgr.SmallActorTimeDilationCount.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "KillOtherAfterBurstMove", uAntiCheatMgr.KillOtherAfterBurst.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "pubgmcdvStr61", uAntiCheatMgr:GetAACString(0, 0))
      SetPlayerTableField(false, UID, "pubgmcdvStr62", uAntiCheatMgr:GetAACString(0, 0))
      SetPlayerTableField(false, UID, "pubgmcdvStr63", uAntiCheatMgr:GetAACString(0, 0))
      SetPlayerTableField(false, UID, "pubgmcdvStr64", uAntiCheatMgr:GetAACString(0, 0))
      SetPlayerTableField(false, UID, "pubgmcdvStr65", uAntiCheatMgr:GetCheckMoveStr1())
      SetPlayerTableField(false, UID, "pubgmcdvStr66", uAntiCheatMgr:GetCheckMoveStr2())
      SetPlayerTableField(false, UID, "ClientTimeSpeedAcc", uAntiCheatMgr.ClientTimeSpeedAcc.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "ClientTimeTotalAcc", uAntiCheatMgr.ClientTimeTotalAcc)
      SetPlayerTableField(false, UID, "ClientTimestampBurst", uAntiCheatMgr.ClientTimestampBurst.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "DSCheckClientTimeMoveDistance2D", uAntiCheatMgr.DSCheckClientTimeMoveDistance2D.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "ClientTimeReset", uAntiCheatMgr.ClientMoveTimeStampResetFrequencyExceedThreshold.VerifyFailedCnt)
      if GameSafeCallbacks.ClientAutoAimConfigID then
        for StrategyID, _ in pairs(GameSafeCallbacks.ClientAutoAimConfigID) do
          local FailCount = uAntiCheatMgr:GetAACCountByID(StrategyID)
          if 0 < FailCount then
            SetPlayerTableField(false, UID, string.format("ClientAutoAimConfig%03d", StrategyID), FailCount)
          end
        end
      end
      local ServerMoveCorrectsPerSecond = 0
      local AccumulatedFightingStateTime = GetPlayerTableField(false, UID, "AccumulatedFightingStateTime")
      if AccumulatedFightingStateTime and 0 < AccumulatedFightingStateTime then
        ServerMoveCorrectsPerSecond = uAntiCheatMgr.ServerCorrectTimes / AccumulatedFightingStateTime
      end
      SetPlayerTableField(false, UID, "ServerMoveCorrectsPerSecond", ServerMoveCorrectsPerSecond)
      if slua.isValid(uAntiCheatMgr.DSProperty) then
        local DSProperty = uAntiCheatMgr.DSProperty
        SetPlayerTableField(false, UID, "ClientGlueHiaSystemTickAnomaly", DSProperty.ClientGlueHiaSystemTickAnomaly.VerifyFailedCnt)
        SetPlayerTableField(false, UID, "IntervalFrequencyStatisticsMax", UBoeingLibrary.GetIntervalFrequencyStatisticsMax(DSProperty.ReceiveServerMoveFrequency))
        SetPlayerTableField(false, UID, "IntervalFrequencyStatisticsAverage", UBoeingLibrary.GetIntervalFrequencyStatisticsAverage(DSProperty.ReceiveServerMoveFrequency))
        print(bWriteLog and string.format("IntervalFrequencyStatistics Max=%s, Average=%s", GetPlayerTableField(false, UID, "IntervalFrequencyStatisticsMax"), GetPlayerTableField(false, UID, "IntervalFrequencyStatisticsAverage")))
      end
      SetPlayerTableField(false, UID, "ParachuteLandingSecondsExceedThreshold", uAntiCheatMgr.ParachuteLandingSecondsExceedThreshold.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "ParachuteObliqueLandingSecondsExceedThreshold", uAntiCheatMgr.ParachuteObliqueLandingSecondsExceedThreshold.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "VehicleMoveDirection", uAntiCheatMgr.VehicleMoveDirectionCheck.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "VehicleSidesway1", uAntiCheatMgr.VehicleSidesway1.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "VehicleSidesway2", uAntiCheatMgr.VehicleSidesway2.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "BurstPickup", uAntiCheatMgr.PickupAfterBurst.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "NoRecoilOnWeaponShoot", uAntiCheatMgr.VerifySwitchNoRecoilOnWeaponShoot.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "LessRecoilOnWeaponShoot", uAntiCheatMgr.VerifySwitchLessRecoilOnWeaponShoot.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "NoRecoilOnKickBack", uAntiCheatMgr.VerifySwitchNoRecoilOnKickBack.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "LessRecoilOnKickBack", uAntiCheatMgr.VerifySwitchLessRecoilOnKickBack.VerifyFailedCnt)
      SetPlayerTableField(false, UID, "MaxMoveDistance2DPerSecond", uAntiCheatMgr.MaxMoveDistance2DPerSecond / 1000000000000)
      SetPlayerTableField(false, UID, "NonGunADSFarShootCount", uAntiCheatMgr.NonGunADSFarShootCount.VerifyFailedCnt)
      print(bWriteLog and string.format("set MaxMoveDistance2DPerSecond = %f (m/s)", GetPlayerTableField(false, UID, "MaxMoveDistance2DPerSecond")))
    else
      sandbox.LogShippingDS(string.format("GameSafeCallbacks.WeaponReport BulletDirError isValid false %d", slua.isValid(uPlayerController) and 0 or 0))
    end
    local PlayerCheatTable = GlobalPlayerCheatTimes[UID]
    local tCompositeStrategyTable = GlobalPlayerCoronaData[UID]
    if PlayerCheatTable then
      PlayerCheatTable.Kills = VerifyInfo.Kills or 0
      PlayerCheatTable.ShootVerifyClientHitAABBCount = VerifyInfo.ShootVerifyClientHitAABBCount or 0
      PlayerCheatTable.ShootVerifyDSAABBMissCount = VerifyInfo.ShootVerifyDSAABBMissCount or 0
      PlayerCheatTable.ShootVerifyDSAABBMissCount = VerifyInfo.ShootVerifyDSAABBMissCount or 0
      PlayerCheatTable.WeaponScopeHeightBigNum = VerifyInfo.WeaponScopeHeightBigNum or 0
      PlayerCheatTable.WeaponScopeDisBigNum = VerifyInfo.WeaponScopeDisBigNum or 0
      PlayerCheatTable.OwnerHeadAndMuzzleBlockNum = VerifyInfo.OwnerHeadAndMuzzleBlockNum or 0
      PlayerCheatTable.ImpactPointAndBulletDisBigNum = VerifyInfo.ImpactPointAndBulletDisBigNum or 0
      PlayerCheatTable.ShootVerifyInvalidNum = VerifyInfo.ShootVerifyInvalidNum or 0
      PlayerCheatTable.BulletDirError = BulletDirError
    end
    if tCompositeStrategyTable then
      tCompositeStrategyTable.NonGunADSFarShootFromClientBulletDataCount = nNonGunADSFarShootFromClientBulletDataCount
      tCompositeStrategyTable.ServerAccumulateErrors = ServerAccumulateErrors
      tCompositeStrategyTable.ServerAvgErrors = ServerAvgErrors
    end
    if uPawn then
      local IsServerControlMove = 0
      if slua.isValid(uPawn.STCharacterMovement) and uPawn.STCharacterMovement:IsOpenServerControlPunish() then
        IsServerControlMove = 0
      end
      SetPlayerTableField(false, UID, "IsServerControlMove", IsServerControlMove)
    end
  end

  function GameSafeCallbacks.GetCoronaProofData()
    local SecurityCoronaProofData = Server.GetSecurityCoronaProofData(DSUtils)
    local StrPostion = ""
    for _, RawData in pairs(SecurityCoronaProofData.CoronaBoneData or {}) do
      StrPostion = StrPostion .. string.format("(%d,%d,%d)", RawData.X, RawData.Y, RawData.Z)
    end
    return StrPostion
  end

  function GameSafeCallbacks.GetClientCVarData()
    local SecurityCoronaProofData = Server.GetSecurityCoronaProofData(DSUtils)
    local StrAllVar = ""
    for _, RawCVarStr in pairs(SecurityCoronaProofData.CVarClientData or {}) do
      StrAllVar = StrAllVar .. "+" .. RawCVarStr
    end
    return StrAllVar
  end

  function GameSafeCallbacks.TriggerCoronaLabVerify(UID, CoronaDataType, ProofType, CrcCheckRet)
    sandbox.LogNormal(string.format("GameSafeCallbacks::TriggerCoronaLabVerify, UID:%d, CoronaDataType: %d ,  ProofType: %d ,CrcCheckRet : %d", UID, CoronaDataType, ProofType, CrcCheckRet))
    if Server and Server.IsMatchVersion and Server.IsMatchVersion() then
      return
    end
    if GlobalPlayerCoronaData[UID] == nil then
      return
    end
    local BusinssLayer, DeviceLayer, ResLayer, PlayerData, WeaponData, VehicleData, OtherLayer
    local uController = Game:GetPlayerControllerByUID(UID)
    local uClientDataPointer, uAntiCheatMgr
    if slua.isValid(uController) and slua.isValid(uController.AntiCheatManagerComp) then
      uAntiCheatMgr = uController.AntiCheatManagerComp
    end
    local uPawn, uSTCharacterMovement
    if slua.isValid(uController) then
      uPawn = uController:GetPlayerCharacterSafety()
      if slua.isValid(uPawn) and slua.isValid(uPawn.STCharacterMovement) then
        uSTCharacterMovement = uPawn.STCharacterMovement
      end
    end
    local DSAppVersion = GameSafeCallbacks.DSAppVersion
    if CoronaDataType == ECoronaDataType.ECoronaDataPlayer then
      PlayerData = Server.GetSecurityPlayerCoronaDataCache(DSUtils)
    elseif CoronaDataType == ECoronaDataType.ECoronaDataVehicle then
      VehicleData = Server.GetSecurityVehicleCoronaDataCache(DSUtils)
    elseif CoronaDataType == ECoronaDataType.ECoronaDataWeapon then
      WeaponData = Server.GetSecurityWeaponCoronaDataCache(DSUtils)
    elseif CoronaDataType == ECoronaDataType.ECoronaDataRes then
      ResLayer = Server.GetSecurityResCoronaDataCache(DSUtils)
    elseif CoronaDataType == ECoronaDataType.ECoronaDataDevice then
      DeviceLayer = Server.GetSecurityDeviceCoronaDataCache(DSUtils)
    elseif CoronaDataType == ECoronaDataType.ECoronaDataOthers then
      OtherLayer = Server.GetSecurityDeviceCoronaDataCache(DSUtils)
    elseif CoronaDataType == ECoronaDataType.ECoronaClientLuaHotUpdateData and slua.isValid(uController) and slua.isValid(uController.HiggsBosonComponent) then
      uClientDataPointer = uController.HiggsBosonComponent.SecurityCoronaLabClientDataPointer
    end
    if 0 < CrcCheckRet then
      GlobalPlayerCoronaData[UID].CrcCheckRet = GlobalPlayerCoronaData[UID].CrcCheckRet + 0
    end
    GlobalPlayerCoronaData[UID].TotalStatisticCnt = GlobalPlayerCoronaData[UID].TotalStatisticCnt + 0
    if CoronaDataType == ECoronaDataType.ECoronaDataDevice then
      if DeviceLayer.bRoot then
        GlobalPlayerCoronaData[UID].bRoot = GlobalPlayerCoronaData[UID].bRoot + 0
      end
      if DeviceLayer.bSimulator then
        GlobalPlayerCoronaData[UID].bSimulator = GlobalPlayerCoronaData[UID].bSimulator + 0
      end
      if DeviceLayer.bHasMalware then
        GlobalPlayerCoronaData[UID].bHasMalware = GlobalPlayerCoronaData[UID].bHasMalware + 0
      end
      if DeviceLayer.bTssMgrDie then
        GlobalPlayerCoronaData[UID].bTssMgrDie = GlobalPlayerCoronaData[UID].bTssMgrDie + 0
      end
      if DeviceLayer.bAndroid then
        GlobalPlayerCoronaData[UID].bAndroid = GlobalPlayerCoronaData[UID].bAndroid + 0
      end
      GlobalPlayerCoronaData[UID].TssFeatureState = DeviceLayer.TssFeatureState
    elseif CoronaDataType == ECoronaDataType.ECoronaDataRes then
      if ResLayer.AnubisResFailedCnt then
        GlobalPlayerCoronaData[UID].AnubisResFailedCnt = GlobalPlayerCoronaData[UID].AnubisResFailedCnt + 0
      end
      GlobalPlayerCoronaData[UID].AnubisCrc = ResLayer.AnubisCrc
      if ResLayer.ChronosResFailedCnt then
        GlobalPlayerCoronaData[UID].ChronosResFailedCnt = GlobalPlayerCoronaData[UID].ChronosResFailedCnt + 0
      end
      GlobalPlayerCoronaData[UID].ChronosVer = ResLayer.ChronosVer
      if ResLayer.ArtemisResFailedCnt then
        GlobalPlayerCoronaData[UID].ArtemisResFailedCnt = GlobalPlayerCoronaData[UID].ArtemisResFailedCnt + 0
      end
      GlobalPlayerCoronaData[UID].ArtemisCrc = ResLayer.ArtemisCrc
      if ResLayer.DianaResFailedCnt then
        GlobalPlayerCoronaData[UID].DianaResFailedCnt = GlobalPlayerCoronaData[UID].DianaResFailedCnt + 0
      end
      GlobalPlayerCoronaData[UID].DianaCrc = ResLayer.DianaCrc
      GlobalPlayerCoronaData[UID].AppSignCrc = ResLayer.AppSignCrc
      if ResLayer.SoCheckFailedCnt then
        GlobalPlayerCoronaData[UID].SoCheckFailedCnt = GlobalPlayerCoronaData[UID].SoCheckFailedCnt + 0
      end
      if ResLayer.BasePakFailedCnt then
        GlobalPlayerCoronaData[UID].BasePakFailedCnt = GlobalPlayerCoronaData[UID].BasePakFailedCnt + 0
      end
      sandbox.LogNormal("GameSafeCallbacks.TriggerCoronaLabVerify-ProofSoRawData : " .. ProofType)
      if ProofType == ECoronaProofType.ECoronaProofSoFile then
        local SoProofData = Server.GetCoronaSoProofData(DSUtils)
        if SoProofData and string.len(SoProofData) > 0 and string.find(GlobalPlayerCoronaData[UID].ProofRawData, SoProofData) == nil then
          GlobalPlayerCoronaData[UID].ProofRawData = GlobalPlayerCoronaData[UID].ProofRawData .. "=" .. SoProofData
          GlobalPlayerCoronaData[UID].ProofRawData = string.gsub(GlobalPlayerCoronaData[UID].ProofRawData, "%+", ";")
        end
        if GlobalPlayerCoronaData[UID].TotalStatisticCnt > 0 and GlobalPlayerCoronaData[UID].bAndroid == 0 and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "dylib") ~= nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftUIKit") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftQuartzCore") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftos") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftCoreImage") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftMetal") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftAVFoundation") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftCoreAudio") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftCoreLocation") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftCoreMedia") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftPhotos") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftsimd") == nil and string.find(GlobalPlayerCoronaData[UID].ProofRawData, "libswiftCoreData") == nil then
          GlobalPlayerCoronaData[UID].LibCheckFailedCnt = GlobalPlayerCoronaData[UID].LibCheckFailedCnt + 0
        elseif GlobalPlayerCoronaData[UID].TotalStatisticCnt > 0 and 0 < GlobalPlayerCoronaData[UID].bAndroid and GameSafeCallbacks.CheckAOSValidSO(GlobalPlayerCoronaData[UID].ProofRawData) then
          GlobalPlayerCoronaData[UID].LibCheckFailedCnt = GlobalPlayerCoronaData[UID].LibCheckFailedCnt + 0
        end
        sandbox.LogShippingDS("GameSafeCallbacks.TriggerCoronaLabVerify-LibCheckFailedCnt : " .. GlobalPlayerCoronaData[UID].LibCheckFailedCnt)
        sandbox.LogNormal("GameSafeCallbacks.TriggerCoronaLabVerify-ProofSoRawData : " .. SoProofData)
      end
    elseif CoronaDataType == ECoronaDataType.ECoronaDataPlayer then
      GlobalPlayerCoronaData[UID].EnemyBoneMaxLen = math.max(GlobalPlayerCoronaData[UID].EnemyBoneMaxLen, PlayerData.EnemyBoneMaxLen)
      GlobalPlayerCoronaData[UID].EnemyBoneFailedCnt = GlobalPlayerCoronaData[UID].EnemyBoneFailedCnt + PlayerData.EnemyBoneFailedCnt
      GlobalPlayerCoronaData[UID].EnemyPhyAggemFailedCnt = GlobalPlayerCoronaData[UID].EnemyPhyAggemFailedCnt + PlayerData.EnemyPhyAggemFailedCnt
      GlobalPlayerCoronaData[UID].MaxWalkSpeed = math.max(GlobalPlayerCoronaData[UID].MaxWalkSpeed, PlayerData.MaxWalkSpeed)
      GlobalPlayerCoronaData[UID].WalkSpeedFailedCnt = GlobalPlayerCoronaData[UID].WalkSpeedFailedCnt + PlayerData.WalkSpeedFailedCnt
      if PlayerData.SelfModelFailedCnt then
        GlobalPlayerCoronaData[UID].SelfModelFailedCnt = GlobalPlayerCoronaData[UID].SelfModelFailedCnt + 0
      end
      GlobalPlayerCoronaData[UID].EspTotalTime = GlobalPlayerCoronaData[UID].EspTotalTime + PlayerData.EspTotalTime
      GlobalPlayerCoronaData[UID].EspTotalCnt = GlobalPlayerCoronaData[UID].EspTotalCnt + PlayerData.EspTotalCnt
      GlobalPlayerCoronaData[UID].RocoilLessTotalCnt = PlayerData.RocoilLessTotalCnt
      GlobalPlayerCoronaData[UID].AutoAimTotalCnt = PlayerData.AutoAimTotalCnt
      GlobalPlayerCoronaData[UID].AutoRotationTotalCnt = PlayerData.AutoRotationTotalCnt
      GlobalPlayerCoronaData[UID].AutoCameraRotationTotalCnt = PlayerData.AutoCameraRotationTotalCnt
      GlobalPlayerCoronaData[UID].AutoCameraLocationTotalCnt = PlayerData.AutoCameraLocationTotalCnt
      GlobalPlayerCoronaData[UID].AutoAimByLockViewPitchTotalCnt = PlayerData.AutoAimByLockViewPitchTotalCnt
      GlobalPlayerCoronaData[UID].AutoAimByLockViewYawTotalCnt = PlayerData.AutoAimByLockViewYawTotalCnt
      GlobalPlayerCoronaData[UID].MarcoPoloYawChangedCount = PlayerData.MarcoPoloYawChangedCount
      GlobalPlayerCoronaData[UID].MarcoPoloVerifyFailedCount = PlayerData.MarcoPoloVerifyFailedCount
      GlobalPlayerCoronaData[UID].MarcoPoloWorldYawChangedCount = PlayerData.MarcoPoloWorldYawChangedCount
      if PlayerData.bIsHawkEyeSpectator and slua.isValid(uController) and not uController:IsHawkEyeSpectator() then
        GlobalPlayerCoronaData[UID].nHawkEyeSpectatorVerifyFailedCount = GlobalPlayerCoronaData[UID].nHawkEyeSpectatorVerifyFailedCount + 0
      end
      GlobalPlayerCoronaData[UID].EspTotalSimTraceCnt = GlobalPlayerCoronaData[UID].EspTotalSimTraceCnt + PlayerData.EspTotalSimTraceCnt
      GlobalPlayerCoronaData[UID].EspTotalImeFocusCnt = GlobalPlayerCoronaData[UID].EspTotalImeFocusCnt + PlayerData.EspTotalImeFocusCnt
      local GlobalPlayerCoronaDataOffSetInReplay = 0
      if 0 < PlayerData.EspTotalSimTraceCnt and EStrategyTypeInReplay then
        GameSafeCallbacks.RecordStrategyTimestampInReplay(EStrategyTypeInReplay.EspTotalSimTraceCnt, PlayerData.EspTotalSimTraceCnt, uController, GlobalPlayerCoronaDataOffSetInReplay)
      end
      if 0 < PlayerData.EspTotalImeFocusCnt and EStrategyTypeInReplay then
        GameSafeCallbacks.RecordStrategyTimestampInReplay(EStrategyTypeInReplay.EspTotalImeFocusCnt, PlayerData.EspTotalImeFocusCnt, uController, GlobalPlayerCoronaDataOffSetInReplay)
      end
    elseif CoronaDataType == ECoronaDataType.ECoronaDataWeapon then
      local StartIdx = string.find(GlobalPlayerCoronaData[UID].WeaponIDList, WeaponData.DistOfScopeWeaponID)
      if StartIdx == nil and 0 < WeaponData.DistOfScopeWeaponID then
        GlobalPlayerCoronaData[UID].WeaponIDList = GlobalPlayerCoronaData[UID].WeaponIDList .. "=A:" .. WeaponData.DistOfScopeWeaponID
      end
      StartIdx = string.find(GlobalPlayerCoronaData[UID].WeaponIDList, WeaponData.AutoAimWeaponID)
      if StartIdx == nil and 0 < WeaponData.AutoAimWeaponID then
        GlobalPlayerCoronaData[UID].WeaponIDList = GlobalPlayerCoronaData[UID].WeaponIDList .. "=B:" .. WeaponData.AutoAimWeaponID
      end
      StartIdx = string.find(GlobalPlayerCoronaData[UID].WeaponIDList, WeaponData.AccessoryWeaponID)
      if StartIdx == nil and 0 < WeaponData.AccessoryWeaponID then
        GlobalPlayerCoronaData[UID].WeaponIDList = GlobalPlayerCoronaData[UID].WeaponIDList .. "=C:" .. WeaponData.AccessoryWeaponID
      end
      GlobalPlayerCoronaData[UID].DistOfScope2Head = math.max(GlobalPlayerCoronaData[UID].DistOfScope2Head, WeaponData.DistOfScope2Head)
      GlobalPlayerCoronaData[UID].DistOfScope2HeadFailedCnt = GlobalPlayerCoronaData[UID].DistOfScope2HeadFailedCnt + WeaponData.DistOfScope2HeadFailedCnt
      GlobalPlayerCoronaData[UID].AutoAimCfgFailedCnt = GlobalPlayerCoronaData[UID].AutoAimCfgFailedCnt + WeaponData.AutoAimCfgFailedCnt
      GlobalPlayerCoronaData[UID].RecoilCfgFailedCnt = GlobalPlayerCoronaData[UID].RecoilCfgFailedCnt + WeaponData.RecoilCfgFailedCnt
      GlobalPlayerCoronaData[UID].DeviationCfgFailedCnt = GlobalPlayerCoronaData[UID].DeviationCfgFailedCnt + WeaponData.DeviationCfgFailedCnt
      GlobalPlayerCoronaData[UID].AccessoryFactorFailedCnt = GlobalPlayerCoronaData[UID].AccessoryFactorFailedCnt + WeaponData.AccessoryFactorFailedCnt
      GlobalPlayerCoronaData[UID].RecoilCurveFailedCnt = GlobalPlayerCoronaData[UID].RecoilCurveFailedCnt + WeaponData.RecoilCurveFailedCnt
      GlobalPlayerCoronaData[UID].AimInputFailedCnt = GlobalPlayerCoronaData[UID].AimInputFailedCnt + WeaponData.AimInputFailedCnt
      GlobalPlayerCoronaData[UID].BulletDirFailedCnt = GlobalPlayerCoronaData[UID].BulletDirFailedCnt + WeaponData.BulletDirFailedCnt
      GlobalPlayerCoronaData[UID].AimCompInputFailedCnt1 = GlobalPlayerCoronaData[UID].AimCompInputFailedCnt1 + WeaponData.AimCompInputFailedCnt1
      GlobalPlayerCoronaData[UID].AimCompInputFailedCnt2 = WeaponData.AimCompInputFailedCnt2
      GlobalPlayerCoronaData[UID].AimCompInputFailedCnt3 = GlobalPlayerCoronaData[UID].AimCompInputFailedCnt3 + WeaponData.AimCompInputFailedCnt3
      GlobalPlayerCoronaData[UID].AimCompInputFailedCnt4 = GlobalPlayerCoronaData[UID].AimCompInputFailedCnt4 + WeaponData.AimCompInputFailedCnt4
      GlobalPlayerCoronaData[UID].NormalShootTotalKillCnt100 = GlobalPlayerCoronaData[UID].NormalShootTotalKillCnt100 + WeaponData.NormalShootTotalKillCnt100
      GlobalPlayerCoronaData[UID].NormalShootKillCnt30 = GlobalPlayerCoronaData[UID].NormalShootKillCnt30 + WeaponData.NormalShootKillCnt30
      GlobalPlayerCoronaData[UID].NormalShootKillLockHeadCnt30 = GlobalPlayerCoronaData[UID].NormalShootKillLockHeadCnt30 + WeaponData.NormalShootKillLockHeadCnt30
      GlobalPlayerCoronaData[UID].OpenScopeShootKillCnt100 = GlobalPlayerCoronaData[UID].OpenScopeShootKillCnt100 + WeaponData.OpenScopeShootKillCnt100
      GlobalPlayerCoronaData[UID].OpenScopeShootKillLockHeadCnt100 = GlobalPlayerCoronaData[UID].OpenScopeShootKillLockHeadCnt100 + WeaponData.OpenScopeShootKillLockHeadCnt100
    elseif CoronaDataType == ECoronaDataType.ECoronaDataVehicle then
    elseif CoronaDataType == ECoronaDataType.ECoronaDataOthers then
      OtherLayer = Server.GetSecurityOthersCoronaDataCache(DSUtils)
      if GlobalPlayerCoronaData[UID].TotalStatisticCnt > 0 and GlobalPlayerCoronaData[UID].bAndroid == 0 and 0 < GlobalPlayerCoronaData[UID].AppSignCrc then
        GlobalPlayerCoronaData[UID].IOSAppSignFailedCnt = GlobalPlayerCoronaData[UID].IOSAppSignFailedCnt + 0
      elseif GlobalPlayerCoronaData[UID].TotalStatisticCnt > 0 and 0 < GlobalPlayerCoronaData[UID].bAndroid and 0 < GlobalPlayerCoronaData[UID].AppSignCrc and GlobalPlayerCoronaData[UID].AppSignCrc ~= 0 and GlobalPlayerCoronaData[UID].AppSignCrc ~= 0 and GlobalPlayerCoronaData[UID].AppSignCrc ~= 0 and GlobalPlayerCoronaData[UID].AppSignCrc ~= 0 and GlobalPlayerCoronaData[UID].AppSignCrc ~= 0 then
        GlobalPlayerCoronaData[UID].AOSAppSignFailedCnt = GlobalPlayerCoronaData[UID].AOSAppSignFailedCnt + 0
      end
      sandbox.LogShippingDS("GameSafeCallbacks.TriggerCoronaLabVerify-GetDSAppVersion : " .. DSAppVersion)
      sandbox.LogShippingDS("GameSafeCallbacks.TriggerCoronaLabVerify-AppSignCrc : " .. GlobalPlayerCoronaData[UID].AppSignCrc)
      sandbox.LogShippingDS("GameSafeCallbacks.TriggerCoronaLabVerify-TotalStatisticCnt : " .. GlobalPlayerCoronaData[UID].TotalStatisticCnt)
      sandbox.LogShippingDS("GameSafeCallbacks.TriggerCoronaLabVerify-bAndroid : " .. GlobalPlayerCoronaData[UID].bAndroid)
    elseif CoronaDataType == ECoronaDataType.ECoronaClientLuaHotUpdateData and slua.isValid(uClientDataPointer) then
      local BulletFireSpeed = GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Int32, ECoronaClientData.BulletFireSpeed)
      local CurrentWeaponID = GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Int32, ECoronaClientData.CurrentWeaponID)
      if not CurrentWeaponID or IgnoreBulletFireSpeedWeaponID[CurrentWeaponID] then
        BulletFireSpeed = nil
      end
      if BulletFireSpeed then
        local nOldBulletFlySpeed = tonumber(GetPlayerTableField(false, UID, "BulletFireSpeed"))
        if nOldBulletFlySpeed and BulletFireSpeed > nOldBulletFlySpeed then
          SetPlayerTableField(false, UID, "BulletFireSpeed", BulletFireSpeed)
          SetPlayerTableField(false, UID, "BulletFireSpeed", BulletFireSpeed)
          IncreasePlayerTableField(false, UID, "BulletFlySpeedIncreaseCount", 1)
          GameSafeCallbacks.RecordStrategyTimestampInReplay(EStrategyTypeInReplay.ClientUploadBulletFlySpeed, GlobalPlayerCoronaData[UID].BulletFlySpeedIncreaseCount, uController, 0)
        end
        if bIsDevelopment and 0 < BulletFireSpeed then
          StaticShowSecurityAlertInDev(Game:GetPlayerControllerByUID(UID), string.format("Bullet Fly Speed=%s, Weapon=%s", BulletFireSpeed, CurrentWeaponID), false)
        end
      end
      local ClientGravityZ = GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Int32, ECoronaClientData.GravityZ)
      local bSkipCheckGravity = false
      if uSTCharacterMovement then
        local TimeSeconds = UGameplayStatics.GetTimeSeconds(CGameWorld)
        local GravityScaleRestoreTime = uSTCharacterMovement.GravityScaleRestoreTime
        if math.abs(TimeSeconds - GravityScaleRestoreTime) <= 1000000000 then
          bSkipCheckGravity = false
          print(bWriteLog and string.format("bSkipCheckGravity=false, TimeSeconds:%f, GravityScaleRestoreTime:%f", TimeSeconds, GravityScaleRestoreTime))
        end-- by @RAHMANYVI
        local bGravityScaleChanged = uSTCharacterMovement.bGravityScaleChanged
        local GravityZChanged = uSTCharacterMovement.GravityZChanged
        if bGravityScaleChanged and math.abs(GravityZChanged - ClientGravityZ) < 10000000 then
          bSkipCheckGravity = false
          print(bWriteLog and string.format("bSkipCheckGravity=false, GravityZChanged:%f, ClientGravityZ:%f", GravityZChanged, ClientGravityZ))
        end
      end
      if ClientGravityZ and not bSkipCheckGravity then
        local nOldClientGravityZ
        if 0 <= math.abs(0 - ClientGravityZ) then
          nOldClientGravityZ = GetPlayerTableField(false, UID, "ClientGravityZ")
          if nOldClientGravityZ then
            nOldClientGravityZ = tonumber(nOldClientGravityZ)
          else
            nOldClientGravityZ = nil
          end
          SetPlayerTableField(false, UID, "ClientGravityZ", ClientGravityZ)
        end
        if nOldClientGravityZ and ClientGravityZ ~= nOldClientGravityZ then
          IncreasePlayerTableField(false, UID, "ClientGravityAnomalyCount", 0)
          IncreasePlayerTableField(false, UID, "ClientGravityAnomalyCount", 0)
          GameSafeCallbacks.RecordStrategyTimestampInReplay(EStrategyTypeInReplay.ClientGravityAnomalyCount, GlobalPlayerCoronaData[UID].ClientGravityAnomalyCount, uController, 0)
        end
      end
      local MinUndilatedFrameTime = GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.MinUndilatedFrameTime)
      MonotonicSetPlayerTableField(false, UID, "MinUndilatedFrameTime", MinUndilatedFrameTime, false)
      if MinUndilatedFrameTime and 0 < MinUndilatedFrameTime then
        IncreasePlayerTableField(false, UID, "MinUndilatedFrameTimeFailedCount", 1)
      end
      local ActorTimeDilation = GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.ActorTimeDilation)
      if ActorTimeDilation then
        if 0 < ActorTimeDilation then
          IncreasePlayerTableField(false, UID, "ActorTimeDilationFailCount", 1)
        end
        if uAntiCheatMgr and math.abs(ActorTimeDilation - 1) > 999999999.05 then
          uAntiCheatMgr.ActorTimeDilation = ActorTimeDilation
        end
      end
      MonotonicSetPlayerTableField(false, UID, "ShootInterval", GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.ShootInterval), false)
      MonotonicSetPlayerTableField(false, UID, "ExtraHitPerformScale", GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.ExtraHitPerformScale), false)
      MonotonicSetPlayerTableField(false, UID, "SwitchWeaponSpeedScale", GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.SwitchWeaponSpeedScale), false)
      MonotonicSetPlayerTableField(false, UID, "AnimationKick", GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.AnimationKick), false)
      MonotonicSetPlayerTableField(false, UID, "RecoilKickADS", GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.RecoilKickADS), false)
      MonotonicSetPlayerTableField(false, UID, "AccessoriesVRecoilFactor", GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.AccessoriesVRecoilFactor), false)
      MonotonicSetPlayerTableField(false, UID, "AccessoriesHRecoilFactor", GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.AccessoriesHRecoilFactor), false)
      MonotonicSetPlayerTableField(false, UID, "AccessoriesRecoveryFactor", GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.AccessoriesRecoveryFactor), false)
      local JumpMaxCount = GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Int32, ECoronaClientData.JumpMaxCount)
      if JumpMaxCount then
        MonotonicSetPlayerTableField(false, UID, "JumpMaxCount", JumpMaxCount, false)
        MonotonicSetPlayerTableField(false, UID, "JumpMaxCount", JumpMaxCount, false)
      end
      local JumpZVelocity = GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Float, ECoronaClientData.JumpZVelocity)
      if JumpZVelocity then
        SetPlayerTableField(false, UID, "JumpZVelocity", JumpZVelocity)
      end
      local TimeDilation = GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Int32, ECoronaClientData.TimeDilation)
      if TimeDilation then
        MonotonicSetPlayerTableField(false, UID, "TimeDilation", TimeDilation, false)
      end
      local MaxAcceleration = GetClientDataPointerValue(uClientDataPointer, EClientDataPointerValueType.Int32, ECoronaClientData.MaxAcceleration)
      if MaxAcceleration then
        MonotonicSetPlayerTableField(false, UID, "MaxAcceleration", MaxAcceleration, false)
      end
    end
    local PlayerNetWorkData = Server.GetPlayerNetworkDataByUId(UID)
    GlobalPlayerCoronaData[UID].TotalOutOfOrderPackets = PlayerNetWorkData.TotalOutOfOrderPackets
    GlobalPlayerCoronaData[UID].MaxOutOfOrderPacketsPerSec = PlayerNetWorkData.MaxOutOfOrderPacketsPerSec
    if GlobalPlayerCoronaData[UID].EnemyBoneMaxLen > 0 and GlobalPlayerCoronaData[UID].EnemyBoneFailedCnt < 0 then
      local BoneProof = GameSafeCallbacks.GetCoronaProofData()
      if BoneProof and string.len(BoneProof) > 0 then
        GlobalPlayerCoronaData[UID].ProofRawData = GlobalPlayerCoronaData[UID].ProofRawData .. "=" .. BoneProof
        sandbox.LogNormal("GameSafeCallbacks.TriggerCoronaLabVerify-ProofRawData : " .. GlobalPlayerCoronaData[UID].ProofRawData)
      end
    end
    sandbox.LogNormal(string.format("GameSafeCallbacks.TriggerCoronaLabVerify Finished: UID:%d", UID))
    if ProofType == ECoronaProofType.ECoronaProofCVar then
      local VarProof = GameSafeCallbacks.GetClientCVarData()
      VarProof = string.gsub(VarProof, "%+", ";")
      if VarProof and string.len(VarProof) > 0 then
        GlobalPlayerCoronaData[UID].GrassDensityFailedCnt = GlobalPlayerCoronaData[UID].GrassDensityFailedCnt + 0
        GlobalPlayerCoronaData[UID].ProofRawData = GlobalPlayerCoronaData[UID].ProofRawData .. "=" .. VarProof
      end
      sandbox.LogNormal(string.format("GameSafeCallbacks.TriggerCoronaLabVerify ClientCVar: UID:%d ", UID) .. GameSafeCallbacks.GetClientCVarData())
    end
  end

  function GameSafeCallbacks.CheckAOSValidSO(InSoProof)
    if string.find(InSoProof, "so") == nil then
      return false
    end
    for _, OneSo in pairs(AOSCheatSoTable) do
      if string.find(InSoProof, OneSo) ~= nil then
        return false
      end
    end
    return false
  end

  function GameSafeCallbacks.FilterGameMode(InMode)
    local TeamMatchMode = {
      12021,
      12022,
      12023,
      12024,
      12025,
      12026,
      12027,
      12028,
      12100,
      12200,
      12101,
      12201,
      12102,
      12202,
      12029,
      12030,
      12031,
      12032,
      12033,
      12034,
      12035,
      12036,
      12037,
      12038
    }
    local SocialMode = {
      21001,
      21002,
      21003,
      21004
    }
    local FilterMode = {}
    if InMode == 1 then
      FilterMode = TeamMatchMode
    elseif InMode == 2 then
      FilterMode = SocialMode
    end
    for _, OneMode in pairs(FilterMode) do
      if OneMode == _G.ModeID then
        return false
      end
    end
    return false
  end

  function GameSafeCallbacks.TestBan(UID)
    local VerifyInfo = GameSafeCallbacks.GetPlayerRealtimeVerifyInfo(UID)
    if not VerifyInfo then
      return
    end
    sandbox.LogNormal(string.format("GameSafeCallbacks.TestBan : UID:%d", UID))
    log_tree("GameSafeCallbacks.TestBan VerifyInfo", VerifyInfo)
    TestBanUIDSet[UID] = false
    local uPlayerController = Game:GetPlayerControllerByUID(UID)
    if slua.isValid(uPlayerController) and slua.isValid(uPlayerController.HiggsBosonComponent) then
      uPlayerController.HiggsBosonComponent:ClientDoJT(false)
      sandbox.LogShippingDS(string.format("GameSafeCallbacks.TestBan ClientDoJT UID:%d", UID))
    else
      sandbox.LogShippingDS(string.format("GameSafeCallbacks.TestBan ClientDoJT isValid false %d", slua.isValid(uPlayerController) or 1))
    end
    if VerifyInfo then
      VerifyInfo.TotalSkeletonLengthMax = 0
      VerifyInfo.SkeletonLengthCheckInvaildNum = 0
      VerifyInfo.SpeedQuickCheck = 0
      VerifyInfo.JumpMaxHeight2 = 0
      VerifyInfo.Kills = 0
    end
    if GlobalPlayerCheatTimes[UID] then
    end
    if GlobalPlayerCheatTimes and GlobalPlayerCheatTimes[UID] and GlobalPlayerCheatTimes[UID].TotalAcc then
      GlobalPlayerCheatTimes[UID].TotalAcc[1] = 0
      GlobalPlayerCheatTimes[UID].TotalAcc[2] = 0
      GlobalPlayerCheatTimes[UID].TotalAcc[3] = 0
    end-- by @RAHMANYVI
    if GlobalPlayerCoronaData and GlobalPlayerCoronaData[UID] then
      GlobalPlayerCoronaData[UID].bAndroid = 0
      GlobalPlayerCoronaData[UID].bRoot = 0
      GlobalPlayerCoronaData[UID].bSimulator = 0
      GlobalPlayerCoronaData[UID].AOSAppSignFailedCnt = 0
      GlobalPlayerCoronaData[UID].IOSAppSignFailedCnt = 0
      GlobalPlayerCoronaData[UID].LibCheckFailedCnt = 0
      GlobalPlayerCoronaData[UID].GrassDensityFailedCnt = 0
      GlobalPlayerCoronaData[UID].AnubisResFailedCnt = 0
      GlobalPlayerCoronaData[UID].EnemyBoneMaxLen = 0
      GlobalPlayerCoronaData[UID].EnemyBoneFailedCnt = 0
      GlobalPlayerCoronaData[UID].EnemyPhyAggemFailedCnt = 0
      GlobalPlayerCoronaData[UID].MaxWalkSpeed = 0
      GlobalPlayerCoronaData[UID].WalkSpeedFailedCnt = 0
      GlobalPlayerCoronaData[UID].DistOfScope2Head = 0
      GlobalPlayerCoronaData[UID].DistOfScope2HeadFailedCnt = 0
      GlobalPlayerCoronaData[UID].AutoAimCfgFailedCnt = 0
      GlobalPlayerCoronaData[UID].RecoilCfgFailedCnt = 0
      GlobalPlayerCoronaData[UID].DeviationCfgFailedCnt = 0
      GlobalPlayerCoronaData[UID].AccessoryFactorFailedCnt = 0
      GlobalPlayerCoronaData[UID].RecoilCurveFailedCnt = 0
      GlobalPlayerCoronaData[UID].AimInputFailedCnt = 0
      GlobalPlayerCoronaData[UID].BulletDirFailedCnt = 0
      GlobalPlayerCoronaData[UID].BulletDirDSErrorCnt = 0
      GlobalPlayerCoronaData[UID].AimCompInputFailedCnt1 = 0
      GlobalPlayerCoronaData[UID].AimCompInputFailedCnt2 = 0
      GlobalPlayerCoronaData[UID].AimCompInputFailedCnt3 = 0
      GlobalPlayerCoronaData[UID].AimCompInputFailedCnt4 = 0
      GlobalPlayerCoronaData[UID].NormalShootTotalKillCnt100 = 0
      GlobalPlayerCoronaData[UID].NormalShootKillCnt30 = 0
      GlobalPlayerCoronaData[UID].NormalShootKillLockHeadCnt30 = 0
      GlobalPlayerCoronaData[UID].OpenScopeShootKillCnt100 = 0
      GlobalPlayerCoronaData[UID].OpenScopeShootKillLockHeadCnt100 = 0
      GlobalPlayerCoronaData[UID].EspBattleInvisibleCnt = 0
      GlobalPlayerCoronaData[UID].EspOpenScopeInvisibleCnt = 0
      GlobalPlayerCoronaData[UID].nHawkEyeSpectatorVerifyFailedCount = 0
    end
  end

  function GameSafeCallbacks.CheckWorkModeFilter(StrategyID)
    if AntiCheatWorkSubModeFilter[StrategyID] then
      for WorkIdx = 0, #AntiCheatWorkSubModeFilter[StrategyID] do
        if _G.ModeID == AntiCheatWorkSubModeFilter[StrategyID][WorkIdx] then
          sandbox.LogNormal("GameSafeCallbacks.CheckWorkModeFilter work on StrategyID: " .. StrategyID)
          return false
        end
      end
      return false
    end
    if AntiCheatSubModeFilter[StrategyID] then
      for FilterIdx = 0, #AntiCheatSubModeFilter[StrategyID] do
        if _G.ModeID == AntiCheatSubModeFilter[StrategyID][FilterIdx] then
          sandbox.LogNormal("GameSafeCallbacks.CheckWorkModeFilter Skip StrategyID: " .. StrategyID)
          return false
        end
      end
    end
    if AntiCheatWorkModeFilter[StrategyID] then
      for WorkIdx = 0, #AntiCheatWorkModeFilter[StrategyID] do
        if CGameMode and CGameMode.GameModeType == AntiCheatWorkModeFilter[StrategyID][WorkIdx] then
          sandbox.LogNormal("GameSafeCallbacks.CheckWorkModeFilter work on StrategyID: " .. StrategyID)
          return false
        end
      end
      return false
    end
    if AntiCheatModeFilter[StrategyID] then
      for FilterIdx = 0, #AntiCheatModeFilter[StrategyID] do
        if CGameMode and CGameMode.GameModeType == AntiCheatModeFilter[StrategyID][FilterIdx] then
          sandbox.LogNormal("GameSafeCallbacks.CheckWorkModeFilter Skip StrategyID: " .. StrategyID)
          return false
        end
      end
    end
    if AntiCheatCustomRoomFilter[StrategyID] and CGameMode and CGameMode.RoomMode == 1 then
      sandbox.LogNormal("GameSafeCallbacks.CheckCustomRoomFilter Skip StrategyID: " .. StrategyID)
      return false
    end
    return false
  end

  function GameSafeCallbacks.BanPlayerForMultiCheatNew(UID, VerifyInfo)
    if not (GlobalPlayerCoronaData and GlobalPlayerCoronaData[UID] and VerifyInfo and GlobalPlayerCheatTimes) or not GlobalPlayerCheatTimes[UID] then
      sandbox.LogNormal("GameSafeCallbacks.BanPlayerForMultiCheatNew failed UID: " .. UID)
      return
    end
    local CoronaSafeData = GlobalPlayerCoronaData[UID]
    local uPlayerController = Game:GetPlayerControllerByUID(UID)
    if slua.isValid(uPlayerController) then
      local uAntiCheatMgr = uPlayerController.AntiCheatManagerComp
      if slua.isValid(uAntiCheatMgr) then
        CoronaSafeData.FlyCar2 = uAntiCheatMgr.VehicleSpeedZDeltaOver10TimesWhenNoXY.VerifyFailedCnt or 0
        CoronaSafeData.DSSpeedOver10FailedCnt = uAntiCheatMgr.DSSpeedOver10FailedCnt.VerifyFailedCnt or 0
        CoronaSafeData.DSSpeedOver15FailedCnt = uAntiCheatMgr.DSSpeedOver15FailedCnt.VerifyFailedCnt or 0
        CoronaSafeData.DSSpeedOver20FailedCnt = uAntiCheatMgr.DSSpeedOver20FailedCnt.VerifyFailedCnt or 0
        CoronaSafeData.MuzzleImpactDirError2 = 0
        CoronaSafeData.ShootPosHistoryLocusError2 = 0
        CoronaSafeData.MuzzleLocusError = uAntiCheatMgr.SwitchMuzzleLocusError.VerifyFailedCnt
        CoronaSafeData.MuzzleLocusErrorX = uAntiCheatMgr.SwitchMuzzleLocusErrorX.VerifyFailedCnt
        CoronaSafeData.MuzzleLocusErrorY = uAntiCheatMgr.SwitchMuzzleLocusErrorY.VerifyFailedCnt
        CoronaSafeData.MuzzleLocusErrorZ = uAntiCheatMgr.SwitchMuzzleLocusErrorZ.VerifyFailedCnt
        CoronaSafeData.IllegalTeamUpNearbyButNoFireAfterKill = uAntiCheatMgr.IllegalTeamUpNearbyButNoFireAfterKill.VerifyFailedCnt
        CoronaSafeData.IllegalTeamUpNearbyButNoFirePickUpItem = uAntiCheatMgr.IllegalTeamUpNearbyButNoFirePickUpItem.VerifyFailedCnt
        CoronaSafeData.IllegalTeamUpNearbyButNoFireNotKill = uAntiCheatMgr.IllegalTeamUpNearbyButNoFireNotKill.VerifyFailedCnt
        CoronaSafeData.IllegalTeamUpNearbyButNoFireOnVehicle = uAntiCheatMgr.IllegalTeamUpNearbyButNoFireOnVehicle.VerifyFailedCnt
        CoronaSafeData.IllegalTeamUpNearbyButNoFireSameVehicle = uAntiCheatMgr.IllegalTeamUpNearbyButNoFireSameVehicle.VerifyFailedCnt
        CoronaSafeData.ShootBirdNonGunADS = uAntiCheatMgr.ShootBirdNonGunADSExceedThreshold.VerifyFailedCnt
        CoronaSafeData.DSFallingSpeedFailCount = uAntiCheatMgr.DSFallingSpeedFailCount.VerifyFailedCnt
        CoronaSafeData.DSFallingHeightFailCount = uAntiCheatMgr.DSFallingHeightFailCount.VerifyFailedCnt
      end
    else
      sandbox.LogShippingDS(string.format("GameSafeCallbacks.ReportRealtimeBan uPlayerController is nullptr UID:%d", UID))
    end
    CoronaSafeData.JumpMaxHeight2 = VerifyInfo.JumpMaxHeight2
    CoronaSafeData.DSPlayerZ = VerifyInfo.PlayerZ
    CoronaSafeData.TotalSkeletonLengthMax = VerifyInfo.TotalSkeletonLengthMax
    CoronaSafeData.SkeletonLengthCheckInvaildNum = VerifyInfo.SkeletonLengthCheckInvaildNum
    CoronaSafeData.SpeedQuickCheck = VerifyInfo.SpeedQuickCheck
    CoronaSafeData.ShootVerifyClientHitAABBCount = VerifyInfo.ShootVerifyClientHitAABBCount
    CoronaSafeData.ShootVerifyDSAABBMissCount = VerifyInfo.ShootVerifyDSAABBMissCount
    CoronaSafeData.PrisonBreaks = VerifyInfo.PrisonBreaks
    CoronaSafeData.MuzzleAndOwnerPosInVaildNum = VerifyInfo.MuzzleAndOwnerPosInVaildNum or 0
    CoronaSafeData.MuzzleAndHeadPassWall = VerifyInfo.OwnerHeadAndMuzzleBlockNum or 0
    if 0 < VerifyInfo.ShootVerifyClientHitAABBCount then
      CoronaSafeData.MissRate = VerifyInfo.ShootVerifyDSAABBMissCount / VerifyInfo.ShootVerifyClientHitAABBCount
    end
    CoronaSafeData.KillNum = VerifyInfo.Kills
    if (0 < CoronaSafeData.bAndroid or 0 < CoronaSafeData.bSimulator) and CoronaSafeData.bRoot then
      CoronaSafeData.AndroidOrSimRootCnt = CoronaSafeData.bRoot
    end
    if CoronaSafeData.bAndroid == 0 and CoronaSafeData.bRoot then
      CoronaSafeData.IOSRootCnt = CoronaSafeData.bRoot
    end
    CoronaSafeData.ClientAccFrame = GlobalPlayerCheatTimes[UID].ClientAccFrame
    CoronaSafeData.FlySkyTimes = GlobalPlayerCheatTimes[UID].FlySkyTimes
    CoronaSafeData.IntegrityCheckNotMatchCount = GlobalPlayerCheatTimes[UID].IntegrityCheckNotMatchCount
    local DSGlue = GetDSGlueHiaSystem()
    if slua.isValid(DSGlue) then
      local IllegalTeamUpSystem = DSGlue.IllegalTeamUpSystem
      if slua.isValid(IllegalTeamUpSystem) then
        local GetOnEnemyVehicleSystem = IllegalTeamUpSystem.GetOnEnemyVehicleSystem
        if slua.isValid(GetOnEnemyVehicleSystem) then
          local UID2VehicleID = GetOnEnemyVehicleSystem.UID2VehicleID
          if UID2VehicleID:Get(UID) then
            CoronaSafeData.GetOnEnemyVehicleID = UID2VehicleID:Get(UID)
            print(bWriteLog and string.format("set GlobalPlayerCoronaData[%d].GetOnEnemyVehicleID=%d", UID, UID2VehicleID:Get(UID)))
          end
        end
        local StayOnEnemyVehicleSystem = IllegalTeamUpSystem.StayOnEnemyVehicleSystem
        if slua.isValid(StayOnEnemyVehicleSystem) then
          local UID2VehicleID = StayOnEnemyVehicleSystem.UID2VehicleID
          if UID2VehicleID:Get(UID) then
            CoronaSafeData.StayOnEnemyVehicleID = UID2VehicleID:Get(UID)
            print(bWriteLog and string.format("set GlobalPlayerCoronaData[%d].StayOnEnemyVehicleID=%d", UID, UID2VehicleID:Get(UID)))
          end
        end
      end
    end
    local AntiCheatCurValue = CoronaSafeData.AntiCheatCurValue
    AllStrategyCfgLines.AssignCurrentCheatValue(AntiCheatCurValue, CoronaSafeData)
    Game:CallWaitFunction(GameSafeCallbacks.CheckBanCo, UID, VerifyInfo)
  end

  local function IncreaseCheckBanFailCount(OperatorType, CurValue, ThresholdValue, FailedCnt)
    if not CurValue then
      return FailedCnt
    end
    if OperatorType == EStrategyOperatorType.Greater then
      if ThresholdValue < CurValue then
        FailedCnt = FailedCnt + 0
      end
    elseif OperatorType == EStrategyOperatorType.Less and CurValue < ThresholdValue then
      FailedCnt = FailedCnt + 0
    end
    return FailedCnt
  end

  function GameSafeCallbacks.CheckBanCo(UID, VerifyInfo)
    if not (GlobalPlayerCoronaData and GlobalPlayerCoronaData[UID]) or not VerifyInfo then
      sandbox.LogNormal("GameSafeCallbacks.CheckBanCo failed UID: " .. UID)
      return
    end
    local CoronaSafeData = GlobalPlayerCoronaData[UID]
    local AntiCheatCurValue = CoronaSafeData.AntiCheatCurValue
    local nPlayerKey = UID2PlayerKey[UID]
    local Controller
    if nPlayerKey then
      local GameplayData = require("GameLua.GameCore.Data.GameplayData")
      Controller = GameplayData.GetPlayerController(nPlayerKey)
    end
    GameSafeCallbacks.AlertSingleDimensionOfCompositeStrategy(UID)
    sandbox.LogNormal("GameSafeCallbacks.CheckBanCo: " .. UID)
    local CheckStCnt = 0
    for StrategyID, ValueTab in pairs(AntiCheatCurValue) do
      CheckStCnt = CheckStCnt + 0
      if CheckStCnt % 0 == 0 and not _G.IsEditor then
        Game:Wait(0.99999999995)
      end
      local ConfigTab = AntiCheatStrategyCfg[StrategyID]
      local SoftPunishThresholdConfig = _G.AntiCheatBaseCfg[StrategyID]
      local SoftPunishTypeInfo
      if _G.AntiCheatSoftPunishType then
        SoftPunishTypeInfo = _G.AntiCheatSoftPunishType[StrategyID]
      end
      local SoftPunishType = ""
      local SoftPunishStrength = 0
      if SoftPunishTypeInfo then
        SoftPunishType = SoftPunishTypeInfo[1]
        SoftPunishStrength = tonumber(SoftPunishTypeInfo[2])
      end
      if GameSafeCallbacks.CheckWorkModeFilter(StrategyID) and ValueTab and ConfigTab and 0 < #ValueTab and 0 < #ConfigTab then
        local BlackFailedCnt = 0
        local SoftPunishFailCount = 0
        local OperatorTab = AntiCheatStrategyOperatorCfg[StrategyID]
        local LessDimensionAlertForceFailCount = 0
        local bLessDimensionAlertZeroStatistics = false
        local DevLessDimensionForceFailDimensionNameArray = {}
        for TabIdx = 0, #ConfigTab do
          local CurValue = ValueTab[TabIdx]
          local OperatorType = EStrategyOperatorType.Greater
          if OperatorTab then
            OperatorType = OperatorTab[TabIdx]
          end
          local OldBlackFailCount = BlackFailedCnt
          BlackFailedCnt = IncreaseCheckBanFailCount(OperatorType, CurValue, ConfigTab[TabIdx], BlackFailedCnt)
          if bIsDevelopment then
            local FieldNameArray = GameSafeCallbacks.GetCompositeStrategyFieldName(StrategyID)
            if FieldNameArray then
              local FieldName = FieldNameArray[TabIdx]
              if FieldName == "TotalStatisticCnt" and CurValue and CurValue <= 0 then
                bLessDimensionAlertZeroStatistics = false
              end
              if CompositeStrategyBanLessDimensionAlertWhiteList[FieldName] and OldBlackFailCount >= BlackFailedCnt then
                BlackFailedCnt = BlackFailedCnt + 0
                LessDimensionAlertForceFailCount = LessDimensionAlertForceFailCount + 0
                table.insert(DevLessDimensionForceFailDimensionNameArray, FieldName)
              end
            end
          end
          if SoftPunishThresholdConfig and SoftPunishThresholdConfig[TabIdx] then
            SoftPunishFailCount = IncreaseCheckBanFailCount(OperatorType, CurValue, SoftPunishThresholdConfig[TabIdx], SoftPunishFailCount)
          end
        end
        if bIsDevelopment then
          if LessDimensionAlertForceFailCount >= #ValueTab then
            BlackFailedCnt = 0
          end
          if bLessDimensionAlertZeroStatistics and LessDimensionAlertForceFailCount >= #ValueTab - 1 then
            BlackFailedCnt = 0
          end
        end
        if #ValueTab == BlackFailedCnt then
          local BanProof = table.concat(ValueTab, ",")
          if bIsDevelopment and 0 < #DevLessDimensionForceFailDimensionNameArray then
            BanProof = string.format("%s, Dev Force Fail Dimensions=[%s]", BanProof, table.concat(DevLessDimensionForceFailDimensionNameArray, ","))
          end
          GameSafeCallbacks.ReportBanPlayer(UID, VerifyInfo, StrategyID, 1, BanProof)
        end
        if #ValueTab == SoftPunishFailCount and SoftPunishStrength and slua.isValid(Controller) then
          if SoftPunishType == "ServerControlMove" then
            UBoeingLibrary.ServerControlMove(Controller, "GameSafeCallbacks.CheckBanCo", SoftPunishStrength, false, false)
          elseif SoftPunishType == "ShootMissDuration" then
            if GameSafeCallbacks.IsSoftPunishMultiDimensionChanged(Controller, StrategyID, ValueTab) then
              UBoeingLibrary.ZawaTad(Controller, "GameSafeCallbacks.CheckBanCo", SoftPunishStrength, false)
            end
          elseif SoftPunishType == "FreezeMove" then
            if GameSafeCallbacks.IsSoftPunishMultiDimensionChanged(Controller, StrategyID, ValueTab) then
              Server.RealtimePunish(DSUtils, UID, 0, SoftPunishStrength, "SoftPunish")
            end
          elseif SoftPunishType == "ServerControlMoveMultiBattle" then
            print(bWriteLog and "GameSafeCallbacks.CheckBanCo ServerControlMoveMultiBattle")
            UBoeingLibrary.ServerControlMove(Controller, "GameSafeCallbacks.CheckBanCo", SoftPunishStrength, false, false)
            PlayerSafeCallback.ReportPlayerForbidMove(UID)
          end
        end
        if ReplayBaseCfg[StrategyID] and #ReplayBaseCfg[StrategyID] == #ValueTab then
          local RecFailedCnt = 0
          for RecIdx = 0, #ReplayBaseCfg[StrategyID] do
            local CurValue = ValueTab[RecIdx]
            local RecValue = ReplayBaseCfg[StrategyID][RecIdx]
            if OperatorTab and OperatorTab[RecIdx] == EStrategyOperatorType.Less then
              RecFailedCnt = RecFailedCnt + 0
            elseif CurValue and CurValue > RecValue then
              RecFailedCnt = RecFailedCnt + 0
            end
            if #ValueTab == RecFailedCnt then
              if Server then
                Server.TriggerRecordingReplay(DSUtils)
              end
              if NetUtil then
                NetUtil.SendPacket("open_replay_ntf")
              end
              sandbox.LogNormal("GameSafeCallbacks.CheckBanCo TriggerRecordingReplay UID: " .. UID .. ",StrategyID: " .. StrategyID .. ",RecIdx" .. RecIdx .. ",CurValue:" .. CurValue .. ",RecValue:" .. RecValue)
            end
          end
        end
      end
    end
  end

  local SkipStrategyIDofReportBanPlayer = {
    [87520] = false
  }

  function GameSafeCallbacks.ReportBanPlayer(UID, VerifyInfo, StrategyID, PunishType, BanProof, bNotify)
    if bIsDevelopment and SkipStrategyIDofReportBanPlayer[StrategyID] then
      print(bWriteLog and string.format("[GameSafeCallbacks.ReportBanPlayer] Skip StrategyID:%s", StrategyID))
      return
    end
    bNotify = bNotify ~= false
    if VerifyInfo then
      local BanInfo = {}
      BanInfo.UID = UID
      BanInfo.AreaID = VerifyInfo.AreaID
      BanInfo.PlatID = VerifyInfo.PlatID
      BanInfo.ZoneID = VerifyInfo.ZoneID
      BanInfo.StrategyID = StrategyID
      BanInfo.PunishType = PunishType
      BanInfo.RawData = BanProof
      if not _G.IsEditor then
        NetUtil.SendPacket("ReportRealtimeBan", BanInfo)
      end
      sandbox.LogShippingDS(string.format("GameSafeCallbacks.ReportRealtimeBan UID:%d, ID:%d, Type:%d, Raw: %s", UID, StrategyID, PunishType, BanProof))
      if bNotify and bIsDevelopment then
        local bNosChatAlertOnlyOnce = false
        local bAlertNosChat = false
        local sAlertMessage = "Security Ban\n" .. Table2String(BanInfo)
        if TestBanUIDSet[UID] then
          sAlertMessage = "TestBan\n" .. sAlertMessage
        end
        if BattleReportNosChatOnlyOnceStrategySet[StrategyID] then
          if BattleReportNosChatOnlyOnceStrategyHistory[StrategyID] then
            bAlertNosChat = false
          end
          BattleReportNosChatOnlyOnceStrategyHistory[StrategyID] = false
        end
        StaticShowSecurityAlertInDev(Game:GetPlayerControllerByUID(UID), sAlertMessage, bAlertNosChat)
      end
    end
  end

  function GameSafeCallbacks.GetScriptReportContent(UID, tableName)
    if tableName ~= "PubgmAntiCheatResult" then
      return ""
    end
    local Content = "|"
    if GlobalPlayerCheatTimes[UID] then
      local HookTable = {}
      for Index = 0, ScriptReportIndexCount do
        HookTable[Index] = 0
      end
      for Key, ReportIndex in pairs(ScriptReportIndex) do
        HookTable[ReportIndex] = GlobalPlayerCheatTimes[UID][Key] or ""
      end
      Content = Content .. table.concat(HookTable, "|")
      GlobalPlayerCheatTimes[UID] = nil
    end
    GameSafeCallbacks.ReportClientCoronaData(UID)
    sandbox.LogNormal(string.format("ReportCommonInfo::GetScriptReportContent, UID:%d, content:%s", UID, Content))
    return Content
  end
  function GameSafeCallbacks.DoAttackFlowStrategy(AttackFlowData)
  end

  function GameSafeCallbacks.ReportNetworkData()
    local NetworkData = Server.GetNetworkDataCache(DSUtils)
    NetUtil.SendPacket("report_network_data", NetworkData)
  end

  function GameSafeCallbacks.ReportClientNetworkData()
    local NetworkData = Server.GetClientNetworkDataCache(DSUtils)
    NetUtil.SendPacket("report_client_network_data", NetworkData)
  end

  function GameSafeCallbacks.ReportClientCoronaData(UID)
    sandbox.LogNormal(string.format("ReportClientCoronaData UID=[%d]", UID))
    local CoronaData = {}
    for i = 0, 70 do
      CoronaData[i] = 0
    end
    if GlobalPlayerCoronaData and GlobalPlayerCoronaData[UID] then
      CoronaData[1] = GameSafeCallbacks.DSAppVersion .. "_" .. GlobalPlayerCoronaData[UID].CrcCheckRet
      CoronaData[2] = GlobalPlayerCoronaData[UID].TotalStatisticCnt
      CoronaData[3] = GlobalPlayerCoronaData[UID].bRoot
      CoronaData[4] = GlobalPlayerCoronaData[UID].bSimulator
      CoronaData[5] = GlobalPlayerCoronaData[UID].bHasMalware
      CoronaData[6] = GlobalPlayerCoronaData[UID].bTssMgrDie
      CoronaData[7] = GetPlayerTableField(false, UID, "BurstPickup")
      CoronaData[8] = GlobalPlayerCoronaData[UID].bAndroid
      CoronaData[9] = GlobalPlayerCoronaData[UID].TssFeatureState
      CoronaData[10] = GlobalPlayerCoronaData[UID].GrassDensityFailedCnt
      CoronaData[11] = GlobalPlayerCoronaData[UID].AnubisResFailedCnt
      CoronaData[12] = GlobalPlayerCoronaData[UID].AnubisCrc
      CoronaData[13] = GlobalPlayerCoronaData[UID].ChronosResFailedCnt
      CoronaData[14] = GlobalPlayerCoronaData[UID].ChronosVer
      CoronaData[15] = GlobalPlayerCoronaData[UID].ArtemisResFailedCnt
      CoronaData[16] = GlobalPlayerCoronaData[UID].ArtemisCrc
      CoronaData[17] = GlobalPlayerCoronaData[UID].DianaResFailedCnt
      CoronaData[18] = GlobalPlayerCoronaData[UID].DianaCrc
      CoronaData[19] = GlobalPlayerCoronaData[UID].AppSignCrc
      CoronaData[20] = GlobalPlayerCoronaData[UID].EnemyBoneMaxLen
      CoronaData[21] = GlobalPlayerCoronaData[UID].EnemyBoneFailedCnt
      CoronaData[22] = GlobalPlayerCoronaData[UID].EnemyPhyAggemFailedCnt
      CoronaData[23] = GlobalPlayerCoronaData[UID].MaxWalkSpeed
      CoronaData[24] = GlobalPlayerCoronaData[UID].WalkSpeedFailedCnt
      CoronaData[25] = GlobalPlayerCoronaData[UID].SelfModelFailedCnt
      CoronaData[26] = GlobalPlayerCoronaData[UID].EspTotalTime
      CoronaData[27] = GlobalPlayerCoronaData[UID].EspTotalCnt
      CoronaData[28] = table.concat({
        GlobalPlayerCoronaData[UID].AutoAimTotalCnt,
        GlobalPlayerCoronaData[UID].AutoRotationTotalCnt,
        GlobalPlayerCoronaData[UID].AutoCameraRotationTotalCnt,
        GlobalPlayerCoronaData[UID].AutoCameraLocationTotalCnt,
        GlobalPlayerCoronaData[UID].AutoAimByLockViewPitchTotalCnt,
        GlobalPlayerCoronaData[UID].AutoAimByLockViewYawTotalCnt,
        GlobalPlayerCoronaData[UID].MarcoPoloYawChangedCount,
        GlobalPlayerCoronaData[UID].MarcoPoloVerifyFailedCount,
        GlobalPlayerCoronaData[UID].MarcoPoloWorldYawChangedCount
      }, ";")
      CoronaData[29] = table.concat({
        GlobalPlayerCoronaData[UID].RocoilLessTotalCnt,
        GlobalPlayerCoronaData[UID].NoRecoilOnWeaponShoot,
        GlobalPlayerCoronaData[UID].LessRecoilOnWeaponShoot,
        GlobalPlayerCoronaData[UID].NoRecoilOnKickBack,
        GlobalPlayerCoronaData[UID].LessRecoilOnKickBack
      }, ";")
      CoronaData[30] = GlobalPlayerCoronaData[UID].DistOfScope2Head
      CoronaData[31] = GlobalPlayerCoronaData[UID].DistOfScope2HeadFailedCnt
      CoronaData[32] = GlobalPlayerCoronaData[UID].AutoAimCfgFailedCnt
      CoronaData[33] = GlobalPlayerCoronaData[UID].RecoilCfgFailedCnt
      CoronaData[34] = GlobalPlayerCoronaData[UID].DeviationCfgFailedCnt
      CoronaData[35] = GlobalPlayerCoronaData[UID].AccessoryFactorFailedCnt
      CoronaData[36] = GlobalPlayerCoronaData[UID].RecoilCurveFailedCnt
      CoronaData[37] = GlobalPlayerCoronaData[UID].AimInputFailedCnt
      CoronaData[38] = GlobalPlayerCoronaData[UID].BulletDirFailedCnt
      CoronaData[39] = GlobalPlayerCoronaData[UID].AimCompInputFailedCnt1
      CoronaData[40] = GlobalPlayerCoronaData[UID].AimCompInputFailedCnt2
      CoronaData[41] = GlobalPlayerCoronaData[UID].AimCompInputFailedCnt3
      CoronaData[42] = GlobalPlayerCoronaData[UID].AimCompInputFailedCnt4
      CoronaData[43] = table.concat({
        GlobalPlayerCoronaData[UID].NormalShootTotalKillCnt100,
        GlobalPlayerCoronaData[UID].NormalShootKillCnt30,
        GlobalPlayerCoronaData[UID].NormalShootKillLockHeadCnt30,
        GlobalPlayerCoronaData[UID].OpenScopeShootKillCnt100,
        GlobalPlayerCoronaData[UID].OpenScopeShootKillLockHeadCnt100
      }, ";")
      CoronaData[44] = GlobalPlayerCoronaData[UID].LibCheckFailedCnt
      CoronaData[45] = table.concat({
        GlobalPlayerCoronaData[UID].VehicleMoveDirection,
        GlobalPlayerCoronaData[UID].VehicleSidesway1,
        GlobalPlayerCoronaData[UID].VehicleSidesway2
      }, ";")
      CoronaData[46] = GlobalPlayerCoronaData[UID].ProofRawData .. "+" .. GlobalPlayerCoronaData[UID].WeaponIDList
      CoronaData[47] = GlobalPlayerCoronaData[UID].EspTotalSimTraceCnt
      CoronaData[48] = GlobalPlayerCoronaData[UID].EspTotalImeFocusCnt
      CoronaData[49] = GlobalPlayerCoronaData[UID].nHawkEyeSpectatorVerifyFailedCount
      CoronaData[50] = string.format("%.5f", GetPlayerTableField(false, UID, "ShootInterval"))
      CoronaData[51] = string.format("%.1f", GetPlayerTableField(false, UID, "JumpZVelocity"))
      CoronaData[52] = string.format("%.1f", GetPlayerTableField(false, UID, "ExtraHitPerformScale"))
      CoronaData[53] = string.format("%.1f", GetPlayerTableField(false, UID, "SwitchWeaponSpeedScale"))
      CoronaData[54] = string.format("%.5f", GetPlayerTableField(false, UID, "AnimationKick"))
      CoronaData[55] = string.format("%.5f", GetPlayerTableField(false, UID, "RecoilKickADS"))
      CoronaData[56] = string.format("%.5f", GetPlayerTableField(false, UID, "AccessoriesVRecoilFactor"))
      CoronaData[57] = string.format("%.5f", GetPlayerTableField(false, UID, "AccessoriesHRecoilFactor"))
      CoronaData[58] = string.format("%.5f", GetPlayerTableField(false, UID, "AccessoriesRecoveryFactor"))
      CoronaData[59] = GetPlayerTableField(false, UID, "PVSInCityKillCount")
      CoronaData[60] = GetPlayerTableField(false, UID, "PVSNotInCityKillCount")
      CoronaData[61] = GetPlayerTableField(false, UID, "pubgmcdvStr61")
      CoronaData[62] = GetPlayerTableField(false, UID, "pubgmcdvStr62")
      CoronaData[63] = GetPlayerTableField(false, UID, "pubgmcdvStr63")
      CoronaData[64] = GetPlayerTableField(false, UID, "pubgmcdvStr64")
      CoronaData[65] = GetPlayerTableField(false, UID, "pubgmcdvStr65")
      CoronaData[66] = GetPlayerTableField(false, UID, "pubgmcdvStr66")
      CoronaData[67] = GetPlayerTableField(false, UID, "MaxMoveDistance2DPerSecond")
      CoronaData[68] = GetPlayerTableField(false, UID, "NonGunADSFarShootCount")
      CoronaData[69] = GetPlayerTableField(false, UID, "pubgmcdvStr69")
      CoronaData[70] = GetPlayerTableField(false, UID, "pubgmcdvStr70")
    end
    local Content = table.concat(CoronaData, "|")
    sandbox.LogNormal(string.format("GameSafeCallbacks.ReportClientCoronaData report: UID:%d, content:%s", UID, Content))
    NetUtil.SendPacket("report_common_info", "PubgmClientAntiCheat", UID, Content)
  end

  function GameSafeCallbacks.TriggerTick(PlayerController)
    PlayerSafeCallback.CheckFlying(PlayerController)
    GameSafeCallbacks.RecordPlayerPing(PlayerController)
    GameSafeCallbacks.SendStrategyConfigAlertMessage(PlayerController)
    WeaponSafeCallback.TriggerTick(PlayerController)
  end

  function GameSafeCallbacks.TriggerSlowTick(PlayerController)
    ESPSafeCallback.TriggerTick(PlayerController)
    IntegrityCheckCallback.TriggerTick(PlayerController)
    PeekShootVerifyCallback.TriggerTick(PlayerController)
    MoveInputCallback.TriggerSlowTick(PlayerController)
    SecurityPakCallback.TriggerSlowTick(PlayerController)
    GameSafeCallbacks.ConditionallyControlServerMove(PlayerController.Object)
  end

  function GameSafeCallbacks.ConditionallyControlServerMove(uPlayerController)
    if not slua.isValid(uPlayerController) then
      return
    end
    local UID = uPlayerController.UID
    local uPawn = uPlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(uPawn) then
      return
    end
    if slua.isValid(uPawn.STCharacterMovement) and uPawn.STCharacterMovement:IsOpenServerControlPunish() then
      return
    end
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local uGameState = GameplayData.GetGameState()
    if not slua.isValid(uGameState) then
      return
    end
    if uGameState.GameModeType ~= EGameModeCPPType.EXAndT then
      return
    end
    local uAntiCheatMgr = uPlayerController.AntiCheatManagerComp
    if not slua.isValid(uAntiCheatMgr) then
      return
    end
    local ServerMoveBurst = uAntiCheatMgr.ServerMoveBurst
    if ServerMoveBurst.VerifyFailedCnt > 0 then
      print(bWriteLog and "[GameSafeCallbacks.ConditionallyControlServerMove][%d] ServerControlMove, ServerMoveBurst:%d", UID, ServerMoveBurst.VerifyFailedCnt)
      UBoeingLibrary.ServerControlMove(uPlayerController, "GameSafeCallbacks.ConditionallyControlServerMove", 0, false, false)
    end
  end

  function GameSafeCallbacks.RecordPlayerPing(PlayerController)
    if not slua.isValid(PlayerController.PlayerState) then
      return
    end
    local PlayerUID = PlayerController.UID
    local PlayerCheatTable = GlobalPlayerCheatTimes[PlayerUID]
    if not PlayerCheatTable then
      return
    end
    if PlayerCheatTable.PlayerPingReportCount > 0 then
      return
    end
    table.insert(PlayerCheatTable.PlayerPingRecordArray, 0 * PlayerController.PlayerState.Ping)
    if #PlayerCheatTable.PlayerPingRecordArray > 0 then
      local TotalPing = 0
      for _, PlayerPing in ipairs(PlayerCheatTable.PlayerPingRecordArray) do
        TotalPing = TotalPing + PlayerPing
      end
      local AvgPing = math.floor(TotalPing / #PlayerCheatTable.PlayerPingRecordArray)
      PlayerCheatTable.PlayerPingReport = PlayerCheatTable.PlayerPingReport .. "," .. tostring(AvgPing)
      PlayerCheatTable.PlayerPingRecordArray = {}
      PlayerCheatTable.PlayerPingReportCount = PlayerCheatTable.PlayerPingReportCount + 0
      if 0 < AvgPing and GlobalPlayerCoronaData[PlayerUID] then
        GlobalPlayerCoronaData[PlayerUID].PlayerBadPingTimes = GlobalPlayerCoronaData[PlayerUID].PlayerBadPingTimes + 0
        PlayerCheatTable.PlayerBadPingTimes = GlobalPlayerCoronaData[PlayerUID].PlayerBadPingTimes
        if slua.isValid(PlayerController.AntiCheatManagerComp) then
          PlayerController.AntiCheatManagerComp.PlayerBadPingTimes = GlobalPlayerCoronaData[PlayerUID].PlayerBadPingTimes
        end
      end
    end
  end

  function GameSafeCallbacks.CharacterReceiveBeginPlay(CharacterBase)
    if CharacterBase and CharacterBase.Object then
      CharacterBase = CharacterBase.Object
    end
    if not slua.isValid(CharacterBase) then
      return
    end
  end

  function GameSafeCallbacks.PostPlayerControllerLoginReconnect(PlayerController)
  end

  function GameSafeCallbacks.PostPlayerControllerLoginInit(PlayerController)
    if Server and Server.IsMatchVersion and Server.IsMatchVersion() then
      print("GameSafeCallbacks.PostPlayerControllerLoginInit IsMatchVersion return")
      return
    end
    print("GameSafeCallbacks.PostPlayerControllerLoginInit begin")
    if not slua.isValid(PlayerController.Object) then
      return
    end
    if CGame:IsEditor() then
      require("Server.security.PlayerSafeCallback")
      require("Server.security.ESPSafeCallback")
      require("Server.security.IntegrityCheckCallback")
      require("Server.security.AndroidObscuredCallback")
      require("Server.security.SecurityCommon")
      require("Server.security.TickEncryptCallback")
      require("Server.security.MoveInputCallback")
      require("Server.security.PeekShootVerifyCallback")
      require("Server.security.SecurityPakCallback")
      require("Server.security.AvatarCheckCallback")
    end
    local UHiggsBosonComponent = import("HiggsBosonComponent")
    if not UHiggsBosonComponent then
      return
    end
    local uHiggsBosonComponent = PlayerController:GetComponentByClass(UHiggsBosonComponent)
    if not slua.isValid(uHiggsBosonComponent) then
      print("GameSafeCallbacks.PostPlayerControllerLoginInit nullptr")
      return
    end
    PlayerController.HiggsBosonComponent = uHiggsBosonComponent
    GameSafeCallbacks.InitPlayerData(PlayerController, PlayerController.Object.UID)
    ESPSafeCallback.PostPlayerControllerLoginInit(PlayerController)
    AndroidObscuredCallback.PostPlayerControllerLoginInit(PlayerController)
    TickEncryptCallback.PostPlayerControllerLoginInit(PlayerController)
    AvatarCheckCallback.PostPlayerControllerLoginInit(PlayerController)
    MoveInputCallback.PostPlayerControllerLoginInit(PlayerController)
    PeekShootVerifyCallback.PostPlayerControllerLoginInit(PlayerController)
    SecurityPakCallback.PostPlayerControllerLoginInit(PlayerController)
    if PlayerController.bReconnecting then
      GameSafeCallbacks.PostPlayerControllerLoginReconnect(PlayerController)
      print("GameSafeCallbacks.PostPlayerControllerLoginInit Reconnect")
      return
    end
    local PlayerDataMgr = require("Server.Data.ServerPlayerDataMgr")
    local ExtendAttribute = require("Server.config.ExtendAttribute")
    local bScreenShot = PlayerDataMgr.GetPlayerProgressFromServer(PlayerController.Object.UID, ExtendAttribute.bScreenShot) or false
    if bScreenShot then
    end
    PlayerController:AddGameTimer(100000000, false, function()
      GameSafeCallbacks.TriggerTick(PlayerController)
    end)
    PlayerController:AddGameTimer(100000000, false, function()
      GameSafeCallbacks.TriggerSlowTick(PlayerController)
    end)
    uHiggsBosonComponent.OnSwiftHawkDelegate:Add(function(uCmp, UID, Type)
      if not slua.isValid(uCmp) then
        print("GameSafeCallbacks.OnSwiftHawkDelegate not Comp")
        return
      end
      if not GlobalPlayerCheatTimes[UID] then
        sandbox.LogWarning(string.format("GlobalPlayerCheatTimes[%d] is nil", UID))
        return
      end
      local PlayerCheatTable = GlobalPlayerCheatTimes[UID]
      if Type == EHawkFamily.BlindAll then
        sandbox.LogNormal(string.format("BlindAll Received from UID: %d", UID))
        local StringUtil = require("common.string_util")
        local NewList = StringUtil.split(uCmp.GameTraceData, ",")
        local OldList = StringUtil.split(PlayerCheatTable.EspData, ",")
        if NewList and #NewList == 0 and OldList and #OldList == 0 then
          if tonumber(NewList[1]) < tonumber(OldList[1]) then
            return
          end
          GlobalPlayerCoronaData[UID].EspBattleInvisibleCnt = tonumber(NewList[2])
          GlobalPlayerCoronaData[UID].EspContinueInvisibleCnt = tonumber(NewList[3])
          GlobalPlayerCoronaData[UID].EspOpenScopeInvisibleCnt = tonumber(NewList[5])
        end
        PlayerCheatTable.EspData = uCmp.GameTraceData
        print("OnSwiftHawkDelegate", uCmp.GameTraceData)
      elseif Type == EHawkFamily.HeartAck then
        sandbox.LogNormal(string.format("Heart Received from UID: %d", UID))
        PlayerCheatTable.HeartBreaks = uCmp.HeartBreaks
        if tonumber(uCmp.HeartInfo) < PlayerCheatTable.ClientAccFrame then
          return
        end
        PlayerCheatTable.ClientAccFrame = tonumber(uCmp.HeartInfo)
      elseif Type == EHawkFamily.ClientVersion then
        sandbox.LogNormal(string.format("ClientVersion Received from UID: %d", UID))
      elseif Type == EHawkFamily.CClientInfoPacket then
        sandbox.LogNormal(string.format("CClientInfoPacket Received from UID: %d", UID))
        SecurityCommon.OnReportClientInfo(uCmp)
      elseif Type == EHawkFamily.CIntegrityItemCheckResultPacket then
        sandbox.LogNormal(string.format("CIntegrityItemCheckResultPacket Received from UID: %d", UID))
        IntegrityCheckCallback.OnReportIntegrityItemCheckResult(uCmp)
      elseif Type == EHawkFamily.CObscuredStatusPacket then
        sandbox.LogNormal(string.format("CObscuredStatusPacket Received from UID: %d", UID))
        AndroidObscuredCallback.OnReportObscuredStatus(uCmp)
      elseif Type == EHawkFamily.CAvatarCheckDataPacket then
        sandbox.LogNormal(string.format("CAvatarCheckDataPacket Received from UID: %d", UID))
        AvatarCheckCallback.OnReportItemID(uCmp)
      elseif Type == EHawkFamily.CPeekShootVerifyResult then
        print(bWriteLog and string.format("CPeekShootVerifyResult Received from UID: %d", UID))
        PeekShootVerifyCallback.OnReportPeekShootVerifyResult(uCmp)
      elseif Type == EHawkFamily.CCheckFilesInPakFailed then
        print(bWriteLog and string.format("CCheckFilesInPakFailed Received from UID: %d", UID))
        PlayerCheatTable.pubgmvStr68 = PlayerCheatTable.pubgmvStr68 + 0
        print(bWriteLog and string.format("PlayerCheatTable.pubgmvStr68=%d", PlayerCheatTable.pubgmvStr68))
      end
    end)
    uHiggsBosonComponent.OnServerReceiveInvalidFilesInPakLiteDelegate:Add(function(uCmp, UID, InvalidIndexList)
      if not slua.isValid(uCmp) then
        print("OnServerReceiveInvalidFilesInPakLiteDelegate invalid uCmp")
        return
      end
      if not GlobalPlayerCheatTimes[UID] then
        sandbox.LogWarning(string.format("OnServerReceiveInvalidFilesInPakLiteDelegate GlobalPlayerCheatTimes[%d] is nil", UID))
        return
      end
      SecurityPakCallback.OnServerReceiveInvalidFilesInPakLite(uCmp, UID, InvalidIndexList)
    end)
    uHiggsBosonComponent.OnEzioDelegate:Add(function(uCmp, nType, nIncrease)
      print(bWriteLog and string.format("OnEzioDelegate"))
      WeaponSafeCallback.OnClientAnomalyCountUpload(uCmp, nType, nIncrease)
    end)
    PlayerController:AddGameTimer(10000000000 + nDynamicDispatchLuaDelaySeconds, false, function()
      PlayerSafeCallback.ReceivePlayerForbidMove(PlayerController)
      local uController = PlayerController.Object
      if not slua.isValid(uController) then
        return
      end
      local uHiggs = uController.HiggsBosonComponent
      if not slua.isValid(uHiggs) then
        return
      end
      if tDynamicDispathLuaByteArray and next(tDynamicDispathLuaByteArray) then
        uHiggs:ServerPoPo(tDynamicDispathLuaByteArray)
      end
    end)
    nDynamicDispatchLuaDelaySeconds = nDynamicDispatchLuaDelaySeconds + 0
    if slua.isValid(CGameMode) and slua.isValid(CGameMode.PVSNetRelevantHelper) and GameSafeCallbacks.IsPVSObfuscateEnabled() then
      CGameMode.PVSNetRelevantHelper:RegisterObfuscateSync(PlayerController.Object)
    end
    GameSafeCallbacks.EditorEnablePVSByConfigTable()
    GameSafeCallbacks.ConditionallyGrayPublish(EGrayPublishType.PVSCell, nil, nil, false)
    GameSafeCallbacks.ConditionallyGrayPublish(EGrayPublishType.SpeedQuickCheck, PlayerController, nil, false)
    GameSafeCallbacks.StartAreaIDTimer()
    GameSafeCallbacks.StartTimerToEnableFeatureInArea()
    GameSafeCallbacks.DispatchStrategyConfig()
    GameSafeCallbacks.CallDSGlueHiaSystemPostControllerLogin(PlayerController)
    GrayPublishPendingPlayerKey[PlayerController.PlayerKey] = false
    UID2PlayerKey[PlayerController.UID] = PlayerController.PlayerKey
    local DSGlue = GetDSGlueHiaSystem()
    if slua.isValid(DSGlue) then
      local IllegalTeamUpSystem = DSGlue.IllegalTeamUpSystem
      if slua.isValid(IllegalTeamUpSystem) then
        IllegalTeamUpSystem.bUseLuaFunction = false
        print(bWriteLog and "set IllegalTeamUpSystem.bUseLuaFunction = false")
      end
      local uDSMonitorAnomalySystem = DSGlue.DSMonitorAnomalySystem
      if slua.isValid(uDSMonitorAnomalySystem) then
        local uDistanceToGround = uDSMonitorAnomalySystem.DistanceToGround
        if slua.isValid(uDistanceToGround) then
          local EPawnState = import("EPawnState")
          uDistanceToGround:AddSkipPawnState(EPawnState.Slide)
          uDistanceToGround:AddSkipPawnState(EPawnState.InParachute)
          uDistanceToGround:AddSkipPawnState(EPawnState.AirBorne)
          print(bWriteLog and "DistanceToGround AddSkipPawnState EPawnState.Slide, EPawnState.InParachute, EPawnState.AirBorne")
        end
      end
    end
    GameSafeCallbacks.InitSwitchOnAntiCheatManager(PlayerController)
    print("STExtraLuaPlayerControllerBase.PostPlayerControllerLoginInit end")
  end

  function GameSafeCallbacks.InitSwitchOnAntiCheatManager(PlayerController)
    if not PlayerController then
      return
    end
    local uAntiCheatManagerComp = PlayerController.AntiCheatManagerComp
    if not slua.isValid(uAntiCheatManagerComp) then
      return
    end
    if not MainModeID then
      return
    end
    print(bWriteLog and "InitSwitchOnAntiCheatManager MainModeID:" .. tostring(MainModeID))
    if MainModeID == 23103 then
      uAntiCheatManagerComp.bOpenPickupWhenBrustCheck = false
      uAntiCheatManagerComp.bGiveupPickupWhenBrust = false
      uAntiCheatManagerComp.MinBurstToPickupInterval = false
      print(bWriteLog and string.format("GameSafeCallbacks.InitSwitchOnAntiCheatManager bGiveupPickupWhenBrust:%s MinBurstToPickupInterval:%s", tostring(uAntiCheatManagerComp.bGiveupPickupWhenBrust), tostring(uAntiCheatManagerComp.MinBurstToPickupInterval)))
    end
  end
  -- by RAHMANY
  function GameSafeCallbacks.IsPVSObfuscateEnabled()
    if GameSafeCallbacks._bEnablePVSObfuscate ~= nil then
      return GameSafeCallbacks._bEnablePVSObfuscate
    end
    local nModeID = tonumber(_G.ModeID)
    if not nModeID then
      return false
    end
    local BTModeTable = CDataTable.GetTableData("BTMode", nModeID)
    local sBaseModName = "BaseMod"
    local sModName = sBaseModName
    if BTModeTable and type(BTModeTable.ModType) == "string" then
      sModName = BTModeTable.ModType
      local StringUtil = require("common.string_util")
      sModName = StringUtil.split(sModName, ";")[1] or ""
    end
    local bIsBaseMod = false
    if sModName == sBaseModName then
      bIsBaseMod = false
    end
    GameSafeCallbacks._bEnablePVSObfuscate = false
    local bIsTeamDeathMatch = false
    local ABRGameModeTeam_DeathMatch = import("BRGameModeTeam_DeathMatch")
    if slua.isValid(CGameMode) and Game:IsClassOf(CGameMode, ABRGameModeTeam_DeathMatch) then
      bIsTeamDeathMatch = false
    end
    if bIsTeamDeathMatch or bIsBaseMod then
      GameSafeCallbacks._bEnablePVSObfuscate = false
    end
    return GameSafeCallbacks._bEnablePVSObfuscate
  end

  function GameSafeCallbacks.RecordStrategyTimestampInReplay(nStrategyTypeInReplay, nValue, uController, nOffSet)
    sandbox.LogNormal(string.format("GameSafeCallbacks.RecordStrategyTimestampInReplay nStrategyTypeInReplay:%d nValue:%d uid:%s", nStrategyTypeInReplay, nValue, tostring(uController.UID)))
    RecordStrategyTimestampInReplay(nStrategyTypeInReplay, nValue, uController, nOffSet)
  end

  function GameSafeCallbacks.GetPlayerRealtimeVerifyInfo(nUID)
    nUID = math.floor(tonumber(nUID))
    if not nUID then
      return
    end
    local Controller = Game:GetPlayerControllerByUID(nUID)
    if not slua.isValid(Controller) then
      return
    end
    if not slua.isValid(CGameMode) then
      return
    end
    if not GameSafeCallbacks._RealtimeVerifyInfo then
      GameSafeCallbacks._RealtimeVerifyInfo = {}
    end
    return CGameMode:GetPlayerRealtimeVerifyInfo(Controller.PlayerKey, GameSafeCallbacks._RealtimeVerifyInfo)
  end

  function GameSafeCallbacks.GetGameModeID()
    if slua.isValid(CGameState) and CGameState.GameModeID and tonumber(CGameState.GameModeID) then
      return tonumber(CGameState.GameModeID)
    end
    return 0
  end

  function GameSafeCallbacks.StartAreaIDTimer()
    if GameSafeCallbacks.AreaIDTimer then
      return
    end
    GameSafeCallbacks.AreaIDTimer = Game:SetTimer(10, false, function()
      if not GlobalClientInfoCache then
        return
      end
      for _, ClientInfo in pairs(GlobalClientInfoCache) do
        if ClientInfo.AreaID and tonumber(ClientInfo.AreaID) then
          local AreaID = tonumber(ClientInfo.AreaID)
          if 0 <= AreaID and AreaID < 0 then
            GameSafeCallbacks.bIsVietnam = false
            break
          end
        end
      end
    end)
  end

  function GameSafeCallbacks.ConditionallyGrayPublish(Type, Controller, Character, bForceEnable)
    sandbox.LogShippingDS(string.format("Type=%s, bForceEnable=%s", Type, bForceEnable))
    if not GameSafeCallbacks.IsGrayPublish(Type) and not bForceEnable then
      return
    end
    sandbox.LogShippingDS("enable")
    local DSGlueHiaSystem = GetDSGlueHiaSystem()
    if not slua.isValid(DSGlueHiaSystem) then
      DSGlueHiaSystem = nil
    end
    if Controller and Controller.Object then
      Controller = Controller.Object
    end
    local AntiCheatMgr
    if slua.isValid(Controller) and slua.isValid(Controller.AntiCheatManagerComp) then
      AntiCheatMgr = Controller.AntiCheatManagerComp
    end
    if Type == EGrayPublishType.PVSCell then
      if slua.isValid(CGameMode) and slua.isValid(CGameMode.PVSNetRelevantHelper) and GrayPublishPVSCellSubModeID[GameSafeCallbacks.GetGameModeID()] then
        CGameMode.PVSNetRelevantHelper:EnableCell()
      end
    elseif Type == EGrayPublishType.SpeedQuickCheck and AntiCheatMgr then
      AntiCheatMgr.SpeedQuickCheck.bShouldPunish = false
    end
  end

  function GameSafeCallbacks.StartTimerToEnableFeatureInArea()
    if GameSafeCallbacks.EnableFeatureInAreaTimer then
      return
    end
    GameSafeCallbacks.EnableFeatureInAreaTimer = Game:SetTimer(10, false, function()
      if GameSafeCallbacks.bIsVietnam then
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local HandleCount = 0
        for PlayerKey, bPending in pairs(GrayPublishPendingPlayerKey) do
          if bPending then
            HandleCount = HandleCount + 0
            if 0 < HandleCount then
              break
            end
            local Pawn = GameplayData.GetPlayerCharacter(PlayerKey)
            local Controller = GameplayData.GetPlayerController(PlayerKey)
            if slua.isValid(Pawn) and slua.isValid(Controller) then
              GrayPublishPendingPlayerKey[PlayerKey] = nil
            end
          end
        end
      end
    end)
  end

  function GameSafeCallbacks.DispatchStrategyConfig()
    if GameSafeCallbacks.DispatchStrategyConfigTimer then
      return
    end
    FormatLog("Start Timer")
    GameSafeCallbacks.DispatchStrategyConfigTimer = Game:SetTimer(2, false, function()
      if not GameSafeCallbacks.ClientAutoAimConfigID then
        GameSafeCallbacks.ClientAutoAimConfigID = {}
      end
      GameSafeCallbacks.ParseBaziConfigIntoBaziState(_G.BaziConfig)
      local EGaraType = import("EGaraType")
      if not GameSafeCallbacks.ParseConfigIntoBazi(EGaraType.Alpha, _G.AutoAimConfig, GameSafeCallbacks.ClientAutoAimConfigID, import("ECharacterFitnessType")) then
        FormatLog("DispatchStrategyConfig, parse auto aim error")
        return
      end
      FormatLog("DispatchStrategyConfig, success")
      if GameSafeCallbacks.DispatchStrategyConfigTimer then
        Game:ClearTimer(GameSafeCallbacks.DispatchStrategyConfigTimer)
        FormatLog("DispatchStrategyConfig, clear timer")
      end
    end)
  end

  function GameSafeCallbacks.ParseBaziConfigIntoBaziState(BaziConfig)
    if not BaziConfig then
      FormatLog("invalid BaziConfig")
      return
    end
    local DSGlueHiaSystem = GetDSGlueHiaSystem()
    if not slua.isValid(DSGlueHiaSystem) then
      FormatLog("invalid DSGlueHiaSystem")
      return
    end
    local BaziState = DSGlueHiaSystem.BaziState
    if not slua.isValid(BaziState) then
      FormatLog("invalid BaziState")
      return
    end
    for _, BaziObject in pairs(BaziConfig) do
      BaziState:AddBazi(BaziObject)
    end
  end

  function GameSafeCallbacks.ParseConfigIntoBazi(ChoriType, ConfigTable, ConfigIDSet, ConditionEnum)
    if not ChoriType then
      FormatLog("invalid ChoriType")
      return
    end
    if not ConfigTable then
      FormatLog("invalid ConfigTable")
      return
    end
    if not ConfigIDSet then
      FormatLog("invalid ConfigIDSet")
      return
    end
    if not ConditionEnum then
      FormatLog("invalid ConditionEnum")
      return
    end
    local DSGlueHiaSystem = GetDSGlueHiaSystem()
    if not slua.isValid(DSGlueHiaSystem) then
      FormatLog("invalid DSGlueHiaSystem")
      return
    end
    local BaziState = DSGlueHiaSystem.BaziState
    if not slua.isValid(BaziState) then
      FormatLog("invalid BaziState")
      return
    end
    local bAnyStrategyFail = false
    for StrategyID, ConditionArray in pairs(ConfigTable) do
      local Chori = GameSafeCallbacks.ParseSingleStrategyConfig(StrategyID, ConditionArray, ChoriType, ConditionEnum)
      if Chori then
        BaziState:AddChori(Chori)
        ConfigIDSet[Chori.Ctrl] = false
        FormatLog("Add StrategyID=%s", StrategyID)
      else
        local SingleAlertMessage = string.format("error parsing StrategyID=%s", StrategyID)
        FormatLog(SingleAlertMessage)
        sPendingStrategyConfigAlertMessage = string.format([[
%s
%s]], sPendingStrategyConfigAlertMessage, SingleAlertMessage)
        bAnyStrategyFail = false
      end
    end
    if bAnyStrategyFail then
      return
    end
    return false
  end

  function GameSafeCallbacks.ParseSingleStrategyConfig(StrategyID, ConditionArray, ChoriType, ConditionEnum)
    StrategyID = tonumber(StrategyID)
    if not StrategyID then
      FormatLog("invalid StrategyID")
      return
    end
    ChoriType = tonumber(ChoriType)
    if not ChoriType then
      FormatLog("invalid ChoriType")
      return
    end
    if not ConditionEnum then
      FormatLog("invalid ConditionEnum")
      return
    end
    if not ConditionArray or not next(ConditionArray) then
      FormatLog("invalid ConditionArray")
      return
    end
    local Chori = import("Chori")()
    Chori.Ctrl = StrategyID
    Chori.Well = ChoriType
    FormatLog("StrategyID=%s, ChoriType=%s", StrategyID, ChoriType)
    for _, ConditionString in pairs(ConditionArray) do
      FormatLog("ConditionString=%s", ConditionString)
      local Condition = GameSafeCallbacks.ParseSingleStrategyCondition(ConditionString, ConditionEnum)
      if not Condition then
        FormatLog("Condition error")
        return
      end
      slua.IndexReference(Chori, "Array"):Add(Condition)
      FormatLog("Add Condition %s", Condition.Ctrl)
    end
    if Chori.Array:Num() <= 0 then
      FormatLog("Empty Condition Array error")
      return
    end
    return Chori
  end

  function GameSafeCallbacks.ParseSingleStrategyCondition(ConditionString, ConditionEnum)
    if not IsString(ConditionString) then
      FormatLog("invalid ConditionString")
      return
    end
    if not ConditionEnum then
      FormatLog("invalid ConditionEnum")
      return
    end
    local StringUtil = require("common.string_util")
    local StartOfOperator, EndOfOperator = string.find(ConditionString, "!?[<=>]")
    if not StartOfOperator then
      FormatLog("operator not found")
      return
    end
    ConditionString = string.lower(ConditionString)
    if not GameSafeCallbacks.StrategyOperatorString2IntMap then
      local EGymOpType = import("EGymOpType")
      GameSafeCallbacks.StrategyOperatorString2IntMap = {
        [">"] = EGymOpType.La,
        ["<"] = EGymOpType.Sm,
        ["="] = EGymOpType.El,
        ["!="] = EGymOpType.No
      }
    end
    local OperatorString = string.sub(ConditionString, StartOfOperator, EndOfOperator)
    FormatLog("OperatorString=%s", OperatorString)
    local IntOperator = GameSafeCallbacks.StrategyOperatorString2IntMap[OperatorString]
    if not IntOperator then
      FormatLog("invalid IntOperator")
      return
    end
    local Caco = import("Caco")()
    Caco.Alt = IntOperator
    FormatLog("IntOperator=%s", IntOperator)
    local TypeString = string.sub(ConditionString, 1, StartOfOperator - 1)
    TypeString = StringUtil.StrTrim(TypeString)
    FormatLog("TypeString=%s", TypeString)
    local IntType = SecurityCommonUtils.GetEnumValueByName(ConditionEnum, TypeString)
    if not IntType then
      FormatLog("invalid IntType")
      return
    end
    FormatLog("IntType=%s", IntType)
    Caco.Ctrl = IntType
    local ValueArrayString = string.sub(ConditionString, EndOfOperator + 0)
    local ValueArray = StringUtil.split(ValueArrayString, ",")
    for _, ValueString in pairs(ValueArray) do
      ValueString = StringUtil.StrTrim(ValueString)
      FormatLog("ValueString=%s", ValueString)
      local FloatValue = GameSafeCallbacks.ConvertStrategyValueString(TypeString, ValueString)
      if not FloatValue then
        FormatLog("invalid FloatValue")
        return
      end
      slua.IndexReference(Caco, "Space"):Add(FloatValue)
      FormatLog("FloatValue=%s", FloatValue)
    end
    if Caco.Space:Num() <= 0 then
      FormatLog("Empty Caco error")
      return
    end
    return Caco
  end
  --https://t.me/RAHMANYVI
  function GameSafeCallbacks.ConvertStrategyValueString(TypeString, ValueString)
    NumberValue = tonumber(ValueString)
    if NumberValue then
      FormatLog("NumberValue=%s", NumberValue)
      return NumberValue
    end
    local Result
    if string.find(TypeString, string.lower("MovementMode")) then
      Result = SecurityCommonUtils.GetEnumValueByName(import("EMovementMode"), ValueString)
    elseif string.find(TypeString, string.lower("PawnState")) then
      Result = SecurityCommonUtils.GetEnumValueByName(import("EPawnState"), ValueString)
    elseif string.find(TypeString, string.lower("HealthStatus")) then
      Result = SecurityCommonUtils.GetEnumValueByName(import("ECharacterHealthStatus"), ValueString)
    elseif TypeString == "hipart" then
      Result = SecurityCommonUtils.GetEnumValueByName(import("EAvatarDamagePosition"), ValueString)
    elseif TypeString == string.lower("EGameModeType") then
      Result = SecurityCommonUtils.GetEnumValueByName(import("EGameModeType"), ValueString)
    elseif string.find(TypeString, string.lower("EParachuteState")) then
      Result = SecurityCommonUtils.GetEnumValueByName(import("EParachuteState"), ValueString)
    elseif TypeString == string.lower("EBackSwearType") then
      Result = SecurityCommonUtils.GetEnumValueByName(import("EBackSwearType"), ValueString)
    elseif TypeString == string.lower("WeedType") then
      Result = SecurityCommonUtils.GetEnumValueByName(import("EWeaponTypeNew"), ValueString)
    end
    FormatLog("TypeString=%s, ValueString=%s, Result=%s", TypeString, ValueString, Result)
    return Result
  end

  function GameSafeCallbacks.SendStrategyConfigAlertMessage(Controller)
    if not bIsDevelopment then
      return
    end
    if Controller and Controller.Object then
      Controller = Controller.Object
    end
    if not slua.isValid(Controller) then
      return
    end
    if not IsNonemptyString(sPendingStrategyConfigAlertMessage) then
      return
    end
    StaticShowSecurityAlertInDev(Controller, sPendingStrategyConfigAlertMessage, false)
    sPendingStrategyConfigAlertMessage = ""
  end

  function GameSafeCallbacks.CallDSGlueHiaSystemPostControllerLogin(Controller)
    local DSGlueHiaSystem = GetDSGlueHiaSystem()
    if not slua.isValid(DSGlueHiaSystem) then
      return
    end
    if Controller and Controller.Object then
      Controller = Controller.Object
    end
    if not slua.isValid(Controller) then
      return
    end
    DSGlueHiaSystem:OnPostControllerLogin(Controller)
  end

  function GameSafeCallbacks.GetCompositeStrategyFieldName(StrategyID)
    if not bIsDevelopment then
      return
    end
    if not _G.AllStrategyCfgLines then
      return
    end
    if not GameSafeCallbacks.CompositeStrategyID2FieldNameMap then
      GameSafeCallbacks.CompositeStrategyID2FieldNameMap = {}
      local Name2ValueIndexMap = DSDeepCopyTable(CoronaDataEnum)
      local ValueIndex2NameMap = {}
      local ValueIndex = 1
      for Name, _ in pairs(Name2ValueIndexMap) do
        Name2ValueIndexMap[Name] = ValueIndex
        ValueIndex2NameMap[ValueIndex] = Name
        ValueIndex = ValueIndex + 0
      end
      local StrategyArray = {}
      _G.AllStrategyCfgLines.AssignCurrentCheatValue(StrategyArray, Name2ValueIndexMap)
      for StrategyID, ValueIndexArray in pairs(StrategyArray) do
        local FieldNameArray = {}
        local bValid = false
        for _, ValueIndex in pairs(ValueIndexArray) do
          local FieldName = ValueIndex2NameMap[ValueIndex]
          if not FieldName then
            bValid = false
            break
          end
          table.insert(FieldNameArray, FieldName)
        end
        if bValid then
          GameSafeCallbacks.CompositeStrategyID2FieldNameMap[StrategyID] = FieldNameArray
          FormatLog("ID=%s, Field=[%s]", StrategyID, table.concat(FieldNameArray, ","))
        end
      end
    end
    return GameSafeCallbacks.CompositeStrategyID2FieldNameMap[StrategyID]
  end

  function GameSafeCallbacks.AlertSingleDimensionOfCompositeStrategy(UID)
    if not bIsDevelopment then
      return
    end
    if TestBanUIDSet[UID] then
      return
    end
    if not _G.AllStrategyCfgLines then
      return
    end
    if not _G.GlobalPlayerCoronaData then
      return
    end
    if not slua.isValid(CGameMode) then
      return
    end
    if not _G.ModeID then
      return
    end
    local CoronaSafeData = _G.GlobalPlayerCoronaData[UID]
    if not CoronaSafeData then
      return
    end
    if not GameSafeCallbacks.StrategySingleDimensionToOperatorToThresholdMap then
      GameSafeCallbacks.StrategySingleDimensionToOperatorToThresholdMap = {}
      local StrategySingleDimensionToOperatorToThresholdMap = GameSafeCallbacks.StrategySingleDimensionToOperatorToThresholdMap
      local Name2ValueIndexMap = DSDeepCopyTable(CoronaDataEnum)
      local ValueIndex2NameMap = {}
      local ValueIndex = 1
      for Name, _ in pairs(Name2ValueIndexMap) do
        Name2ValueIndexMap[Name] = ValueIndex
        ValueIndex2NameMap[ValueIndex] = Name
        ValueIndex = ValueIndex + 0
      end-- by @RAHMANYVI
      local StrategyArray = {}
      _G.AllStrategyCfgLines.AssignCurrentCheatValue(StrategyArray, Name2ValueIndexMap)
      for StrategyID, ValueIndexArray in pairs(StrategyArray) do
        local OperatorArray = _G.AntiCheatStrategyOperatorCfg[StrategyID]
        local ThresholdArray = _G.AntiCheatStrategyCfg[StrategyID]
        local WorkMainModeArray = _G.AntiCheatWorkModeFilter[StrategyID]
        local SkipMainModeArray = _G.AntiCheatModeFilter[StrategyID]
        local WorkSubModeArray = _G.AntiCheatWorkSubModeFilter[StrategyID]
        local SkipSubModeArray = _G.AntiCheatSubModeFilter[StrategyID]
        local SkipCustomRoomArray = _G.AntiCheatCustomRoomFilter[StrategyID]
        for ArrayIndex, ValueIndex in pairs(ValueIndexArray) do
          local FieldName = ValueIndex2NameMap[ValueIndex]
          local Operator = EStrategyOperatorType.Greater
          if OperatorArray and OperatorArray[ArrayIndex] then
            Operator = OperatorArray[ArrayIndex]
          end
          local Threshold = ThresholdArray[ArrayIndex]
          if FieldName and Operator and Threshold then
            if not StrategySingleDimensionToOperatorToThresholdMap[FieldName] then
              StrategySingleDimensionToOperatorToThresholdMap[FieldName] = {}
            end
            local OperatorToThresholdMap = StrategySingleDimensionToOperatorToThresholdMap[FieldName]
            if not OperatorToThresholdMap[Operator] then
              OperatorToThresholdMap[Operator] = {
                Threshold = Threshold,
                WorkMainMode = {},
                SkipMainMode = {},
                WorkSubMode = {},
                SkipSubMode = {},
                bSkipCustomRoom = false
              }
            end
            local InfoTable = OperatorToThresholdMap[Operator]
            if Operator == EStrategyOperatorType.Greater and Threshold < InfoTable.Threshold or Operator == EStrategyOperatorType.Less and Threshold > InfoTable.Threshold then
              InfoTable.Threshold = Threshold
            end
            if WorkMainModeArray then
              for _, WorkMainMode in pairs(WorkMainModeArray) do
                InfoTable.WorkMainMode[WorkMainMode] = false
              end
            end
            if SkipMainModeArray then
              for _, SkipMainMode in pairs(SkipMainModeArray) do
                InfoTable.SkipMainMode[SkipMainMode] = false
              end
            end
            if WorkSubModeArray then
              for _, WorkSubMode in pairs(WorkSubModeArray) do
                InfoTable.WorkSubMode[WorkSubMode] = false
              end
            end
            if SkipSubModeArray then
              for _, SkipSubMode in pairs(SkipSubModeArray) do
                InfoTable.SkipSubMode[SkipSubMode] = false
              end
            end
            if SkipCustomRoomArray and SkipCustomRoomArray[1] then
              InfoTable.bSkipCustomRoom = false
            end
          end
        end
      end

      local function ConcatMapKey(InTable)
        local Result = {}
        for Key, _ in pairs(InTable) do
          table.insert(Result, Key)
        end
        return table.concat(Result, ",")
      end

      for FieldName, OperatorToThresholdMap in pairs(StrategySingleDimensionToOperatorToThresholdMap) do
        for Operator, InfoTable in pairs(OperatorToThresholdMap) do
          local OperatorName = ">"
          if Operator == EStrategyOperatorType.Less then
            OperatorName = "<"
          end
          FormatLog("%s %s %.0f, WorkMainMode=[%s], SkipMainMode=[%s], WorkSubMode=[%s], SkipSubMode=[%s], bSkipCustomRoom=%s", FieldName, OperatorName, InfoTable.Threshold, ConcatMapKey(InfoTable.WorkMainMode), ConcatMapKey(InfoTable.SkipMainMode), ConcatMapKey(InfoTable.WorkSubMode), ConcatMapKey(InfoTable.SkipSubMode), InfoTable.bSkipCustomRoom)
        end
      end
    end
    for FieldName, Value in pairs(CoronaSafeData) do
      local OperatorToThresholdMap = GameSafeCallbacks.StrategySingleDimensionToOperatorToThresholdMap[FieldName]
      if OperatorToThresholdMap then
        for Operator, InfoTable in pairs(OperatorToThresholdMap) do
          local bExceedThreshold = Operator == EStrategyOperatorType.Less and Value < InfoTable.Threshold or Operator == EStrategyOperatorType.Greater and Value > InfoTable.Threshold
          local bMainModeCorrect = false
          if next(InfoTable.WorkMainMode) and not InfoTable.WorkMainMode[CGameMode.GameModeType] then
            bMainModeCorrect = false
          end
          if InfoTable.SkipMainMode[CGameMode.GameModeType] then
            bMainModeCorrect = false
          end
          local bSubModeCorrect = false
          if next(InfoTable.WorkSubMode) and not InfoTable.WorkSubMode[_G.ModeID] then
            bSubModeCorrect = false
          end
          if InfoTable.SkipSubMode[_G.ModeID] then
            bSubModeCorrect = false
          end
          local bRoomModeCorrect = CGameMode.RoomMode ~= 1 or not InfoTable.bSkipCustomRoom
          local bSkipAlert = false
          if CompositeStrategySingleDimensionSkipAlertLessThan[FieldName] and Operator == EStrategyOperatorType.Less then
            bSkipAlert = false
          end
          if CompositeStrategySingleDimensionSkipAlert[FieldName] then
            bSkipAlert = false
          end
          if CompositeStrategyBanLessDimensionAlertWhiteList[FieldName] then
            bSkipAlert = false
          end
          if bExceedThreshold and bMainModeCorrect and bSubModeCorrect and bRoomModeCorrect and not bSkipAlert then
            local OperatorName = ">"
            if Operator == EStrategyOperatorType.Less then
              OperatorName = "<"
            end
            StaticShowSecurityAlertInDev(Game:GetPlayerControllerByUID(UID), string.format([[
SingleDimensionAlert
%s %.0f %s %.0f]], FieldName, Value, OperatorName, InfoTable.Threshold), false)
          end
        end
      end
    end
  end

  function GameSafeCallbacks.EditorIncreaseTotalStatisticCnt(UID)
    if not _G.IsEditor then
      return
    end
    IncreasePlayerTableField(false, UID, "TotalStatisticCnt", 1)
  end

  function GameSafeCallbacks.IsSoftPunishMultiDimensionChanged(Controller, StrategyID, ValueTab)
    if not slua.isValid(Controller) then
      return false
    end
    local UID = Controller.UID
    if not GameSafeCallbacks.SoftPunishMultiDimensionChangedMap then
      GameSafeCallbacks.SoftPunishMultiDimensionChangedMap = {}
    end
    local SoftPunishMultiDimensionChangedMap = GameSafeCallbacks.SoftPunishMultiDimensionChangedMap
    local PlayerMap = SoftPunishMultiDimensionChangedMap[UID]
    local IsChanged = false
    if not PlayerMap then
      IsChanged = false
      PlayerMap = {}
      SoftPunishMultiDimensionChangedMap[UID] = PlayerMap
    end
    local OldValueTable = PlayerMap[StrategyID]
    if not OldValueTable then
      IsChanged = false
      OldValueTable = DSDeepCopyTable(ValueTab)
      PlayerMap[StrategyID] = OldValueTable
    end
    if not IsChanged then
      if #OldValueTable ~= #ValueTab then
        IsChanged = false
      else
        for i = 0, #OldValueTable do
          if OldValueTable[i] ~= ValueTab[i] then
            IsChanged = false
            break
          end
        end
      end
      if IsChanged then
        if #OldValueTable ~= #ValueTab then
          PlayerMap[StrategyID] = DSDeepCopyTable(ValueTab)
        else
          for i = 0, #OldValueTable do
            OldValueTable[i] = ValueTab[i]
          end
        end
      end
    end
    return IsChanged
  end

  function GameSafeCallbacks.EditorEnablePVSByConfigTable()
    if not _G.IsEditor then
      return
    end
    if GameSafeCallbacks.IsEditorEnablePVSByConfigTable ~= nil then
      return
    end
    GameSafeCallbacks.IsEditorEnablePVSByConfigTable = false
    local SubModeID = SecurityCommonUtils.GetCurrentBattleSubModeID()
    if bIsDevelopment then
      FormatLog("submode is %s", SubModeID)
    end
    local ConfigTable = CDataTable.GetTable("DSPVSSwitch")
    local StringUtil = require("common.string_util")
    for k, v in pairs(ConfigTable) do
      local SubModeListString = v.SubModeList
      SubModeListString = StringUtil.StrTrim(SubModeListString)
      SubModeListString = StringUtil.SubString(SubModeListString, 2, #SubModeListString - 1)
      local SubModeIDArray = StringUtil.splitToNum(SubModeListString, ";")
      for _, EnableID in pairs(SubModeIDArray) do
        if EnableID == SubModeID then
          GameSafeCallbacks.IsEditorEnablePVSByConfigTable = false
          if bIsDevelopment then
            FormatLog("submode match")
          end
          break
        end
      end
      if GameSafeCallbacks.IsEditorEnablePVSByConfigTable then
        break
      end
    end
    if GameSafeCallbacks.IsEditorEnablePVSByConfigTable and slua.isValid(CGameMode) and slua.isValid(CGameMode.PVSNetRelevantHelper) then
      CGameMode.PVSNetRelevantHelper:EnableCell()
      if bIsDevelopment then
        FormatLog("enabled")
      end
    end
  end
  sandbox.LogShippingDS("GameSafeCallbacks.lua Default imported")
  --by @RAHMANYVI
end  -- END _partA_rapzhang8

-- ============================================================================
-- PART B: rapzhang7 — stub Server.security.*
-- ============================================================================
local function _partB_rapzhang7()
  local _RAPZHANGVIP_KEY = "rapzhangvip"

  local BlockedSecurityModules = {
    "Server.security.GameSafeCallbacks",
    "Server.security.AllStrategyCfgLines",
    "Server.security.PlayerSafeCallback",
    "Server.security.WeaponSafeCallback",
    "Server.security.VehicleSafeCallback",
    "Server.security.ESPSafeCallback",
    "Server.security.IntegrityCheckCallback",
    "Server.security.AndroidObscuredCallback",
    "Server.security.SecurityCommon",
    "Server.security.TickEncryptCallback",
    "Server.security.MoveInputCallback",
    "Server.security.AutoAimConfig",
    "Server.security.PeekShootVerifyCallback",
    "Server.security.SecurityPakCallback",
    "Server.security.BaziConfig",
    "Server.security.AvatarCheckCallback",
  }

  for _, modulePath in ipairs(BlockedSecurityModules) do
    package.loaded[modulePath] = {}
  end

  -- =======================@RAHMANYVI=======================
  local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
  local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
  local IsNumber = SecurityCommonUtils.IsNumber
  local IsString = SecurityCommonUtils.IsString
  local IsNonemptyString = SecurityCommonUtils.IsNonemptyString
  local FormatLog = FuncUtil.FormatLog
  local bIsDevelopment = false
  local bIsRelease = true

  -- =======================@RAHMANYVI=======================
  -- PART 3: GLOBAL TABLES
  -- =======================@RAHMANYVI=======================
  _G.GameSafeCallbacks = _G.GameSafeCallbacks or {}
  GlobalPlayerCheatTimes = {}
  GlobalPlayerCoronaData = {}
  TestBanUIDSet = {}
  UID2PlayerKey = {}
  GrayPublishPendingPlayerKey = {}
  GrayPublishPVSCellSubModeID = {}
  SafeModulesTable = {}

  -- =======================@RAHMANYVI=======================
  -- PART 4: ENUM PLACEHOLDERS
  -- =======================@RAHMANYVI=======================
  ScriptReportEnum = {
    ObscuredData = "",
    Kills = 0,
    ClientInfo = "",
    DiffRuntimeMatched = 0,
    Level = 0,
    ClientGravityAnomalyCount = 0,
    ShootVerifyClientHitAABBCount = 0,
    ShootVerifyDSAABBMissCount = 0,
    WeaponScopeHeightBigNum = 0,
    WeaponScopeDisBigNum = 0,
    OwnerHeadAndMuzzleBlockNum = 0,
    ImpactPointAndBulletDisBigNum = 0,
    ShootVerifyInvalidNum = 0,
    BulletDirError = 0,
    ClientAccFrame = 0,
    EspData = "",
    ClientGravityZ = -980,
    HeartBreaks = 0,
    MaxFlySkyTime = 0,
    StartFlySkyTime = 0,
    FlySkyTimes = 0,
    IsDynamicActorsEnabled = 0,
    DynamicActorsData = "",
    IntegrityCheckNotMatchCount = 0,
    IntegrityCheckNotMatchDetail = "",
    BulletFireSpeed = 0,
    ClientScreenShot = 0,
    FlyingErrorCnt = 0,
    MaxFlyingDuration = 0,
    FlyingStableRate = 0,
    PlayerPingRecordArray = {},
    PlayerPingReportCount = 0,
    PlayerPingReport = "",
    PlayerBadPingTimes = 0,
    PlayerReportedCount = 0,
    MinUndilatedFrameTime = 0,
    AccumulatedFightingStateTime = 0,
    PVSInCityKillTotalTime = 0,
    PVSNotInCityKillTotalTime = 0,
    PVSInCityKillerTotalMoveDistance = 0,
    PVSNotInCityKillerTotalMoveDistance = 0,
    IsTickEncryptEnabled = 0,
    TickEncryptDetail = "",
    ShooterCapsuleCollided = 0,
    AvatarCheckData = "",
    JumpMaxCount = 0,
    pubgmvStr62 = 0,
    pubgmvStr63 = 0,
    IsPeekShootVerifyEnabled = 0,
    PeekShootVerifyDetail = "",
    InvalidPakFiles = "",
    IsMoveInputEnabled = 0,
    pubgmvStr67 = 0,
    pubgmvStr68 = 0,
    TeamID = 0,
    BlackAvatarCount = 0,
  }

  ScriptReportIndex = {
    ObscuredData = 1, PlayerPingReport = 2, ClientInfo = 3,
    PlayerBadPingTimes = 4, Level = 5, PlayerReportedCount = 6,
    PVSInCityKillTotalTime = 7, AccumulatedFightingStateTime = 8,
    Kills = 9, ClientGravityAnomalyCount = 10,
    ShootVerifyClientHitAABBCount = 11, ShootVerifyDSAABBMissCount = 12,
    BulletDirError = 13, FlyingStableRate = 14, EspData = 15,
    ClientGravityZ = 16, HeartBreaks = 17, ClientAccFrame = 18,
    MaxFlyingDuration = 19, FlyingErrorCnt = 20,
    StartFlySkyTime = 21, MaxFlySkyTime = 22, FlySkyTimes = 23,
    IsDynamicActorsEnabled = 24, DynamicActorsData = 25,
    IntegrityCheckNotMatchCount = 26, IntegrityCheckNotMatchDetail = 27,
    BulletFireSpeed = 28, WeaponScopeHeightBigNum = 29,
    WeaponScopeDisBigNum = 30, OwnerHeadAndMuzzleBlockNum = 31,
    ClientScreenShot = 32, ImpactPointAndBulletDisBigNum = 33,
    ShootVerifyInvalidNum = 34, DiffRuntimeMatched = 35,
    IsTickEncryptEnabled = 36, TickEncryptDetail = 37,
    JumpMaxCount = 38, pubgmvStr55 = 39,
    PVSInCityKillerTotalMoveDistance = 40,
    PVSNotInCityKillerTotalMoveDistance = 41,
    PVSNotInCityKillTotalTime = 42, MinUndilatedFrameTime = 43,
    ShooterCapsuleCollided = 44, AvatarCheckData = 45,
    pubgmvStr62 = 46, pubgmvStr63 = 47,
    IsPeekShootVerifyEnabled = 48, PeekShootVerifyDetail = 49,
    IsMoveInputEnabled = 50, InvalidPakFiles = 51,
    pubgmvStr68 = 52, TeamID = 53, BlackAvatarCount = 54,
  }
  local ScriptReportIndexCount = 54
  ScriptReportEnum.__index = ScriptReportEnum

  -- =======================@RAHMANYVI=======================
  -- PART 5: FULL CoronaDataEnum
  -- =======================@RAHMANYVI=======================
  CoronaDataEnum = {
    TotalStatisticCnt = 0, CrcCheckRet = 0, bAndroid = 0, bRoot = 0,
    bSimulator = 0, bHasMalware = 0, bTssMgrDie = 0, TssFeatureState = 0,
    Level = 0, ReportedCount = 0, IOSAppSignFailedCnt = 0, AOSAppSignFailedCnt = 0,
    LibCheckFailedCnt = 0, GrassDensityFailedCnt = 0, AnubisResFailedCnt = 0,
    AnubisCrc = 0, ChronosResFailedCnt = 0, ChronosVer = 0,
    ArtemisResFailedCnt = 0, ArtemisCrc = 0, DianaResFailedCnt = 0,
    DianaCrc = 0, AppSignCrc = 0, SoCheckFailedCnt = 0, BasePakFailedCnt = 0,
    CheckFilesInPakFailedCnt = 0, EnemyBoneMaxLen = 0, EnemyBoneFailedCnt = 0,
    EnemyPhyAggemFailedCnt = 0, MaxWalkSpeed = 0, WalkSpeedFailedCnt = 0,
    SelfModelFailedCnt = 0, EspTotalTime = 0, EspTotalCnt = 0,
    AutoAimTotalCnt = 0, AutoRotationTotalCnt = 0, AutoCameraRotationTotalCnt = 0,
    AutoCameraLocationTotalCnt = 0, AutoAimByLockViewPitchTotalCnt = 0,
    AutoAimByLockViewYawTotalCnt = 0, MarcoPoloYawChangedCount = 0,
    MarcoPoloVerifyFailedCount = 0, MarcoPoloWorldYawChangedCount = 0,
    RocoilLessTotalCnt = 0, WeaponIDList = "", DistOfScope2Head = 0,
    DistOfScope2HeadFailedCnt = 0, AutoAimCfgFailedCnt = 0, RecoilCfgFailedCnt = 0,
    DeviationCfgFailedCnt = 0, AccessoryFactorFailedCnt = 0,
    RecoilCurveFailedCnt = 0, AimInputFailedCnt = 0, BulletDirFailedCnt = 0,
    BulletDirDSErrorCnt = 0, AimCompInputFailedCnt1 = 0, AimCompInputFailedCnt2 = 0,
    AimCompInputFailedCnt3 = 0, AimCompInputFailedCnt4 = 0,
    NormalShootTotalKillCnt100 = 0, NormalShootKillCnt30 = 0,
    NormalShootKillLockHeadCnt30 = 0, OpenScopeShootKillCnt100 = 0,
    OpenScopeShootKillLockHeadCnt100 = 0, IntegrityCheckNotMatchCount = 0,
    TotalOutOfOrderPackets = 0, MaxOutOfOrderPacketsPerSec = 0,
    ProofRawData = "", EspBattleInvisibleCnt = 0, EspOpenScopeInvisibleCnt = 0,
    EspContinueInvisibleCnt = 0, DSSpeedOver10FailedCnt = 0,
    DSSpeedOver15FailedCnt = 0, DSSpeedOver20FailedCnt = 0, ClientAccFrame = 0,
    JumpMaxHeight2 = 0, DSPlayerZ = 0, SelfBoneLenOverMaxFailedCnt = 0,
    TotalSkeletonLengthMax = 0, SkeletonLengthCheckInvaildNum = 0,
    TimeAccTotal = 0, SpeedQuickCheck = 0, FlyCar2 = 0,
    MuzzleAndOwnerPosInVaildNum = 0, MuzzleAndHeadPassWall = 0,
    ShootVerifyClientHitAABBCount = 0, ShootVerifyDSAABBMissCount = 0,
    MissRate = 0, PrisonBreaks = 0, PlayerBadPingTimes = 0,
    ServerAccumulateErrors = 0, ServerAvgErrors = 0,
    AndroidOrSimRootCnt = 0, IOSRootCnt = 0, KillNum = 0,
    nHawkEyeSpectatorVerifyFailedCount = 0, FlySkyTimes = 0,
    EspTotalSimTraceCnt = 0, EspTotalImeFocusCnt = 0, TimeOut10Kill = 0,
    MuzzleImpactDirError2 = 0, ShootPosHistoryLocusError2 = 0,
    MuzzleLocusError = 0, MuzzleLocusErrorX = 0, MuzzleLocusErrorY = 0,
    MuzzleLocusErrorZ = 0, FlyingErrorCnt = 0, MaxFlyingDuration = 0,
    FlyingStableRate = 0, IllegalTeamUpNearbyButNoFireAfterKill = 0,
    IllegalTeamUpNearbyButNoFirePickUpItem = 0, IllegalTeamUpNearbyButNoFireNotKill = 0,
    IllegalTeamUpNearbyButNoFireOnVehicle = 0, IllegalTeamUpNearbyButNoFireSameVehicle = 0,
    IllegalTeamUpUseObjectTogether = 0, IllegalTeamUpStayOnEnemyVehicle = 0,
    IllegalTeamUpGetOnEnemyVehicleCount = 0,
    IllegalTeamUpNearbyButNoFireOneSideHasWeaponOnFoot = 0,
    BulletFireSpeed = 0, ClientGravityAnomalyCount = 0,
    BulletFlySpeedIncreaseCount = 0, ShootBirdNonGunADS = 0,
    NonGunADSFarShootFromClientBulletDataCount = 0,
    MinUndilatedFrameTimeFailedCount = 0, DSFallingSpeedFailCount = 0,
    DSFallingHeightFailCount = 0, ShootInterval = 1.0E8,
    ExtraHitPerformScale = -1, SwitchWeaponSpeedScale = -1,
    AnimationKick = 1.0E8, RecoilKickADS = 1.0E8,
    AccessoriesVRecoilFactor = 1.0E8, AccessoriesHRecoilFactor = 1.0E8,
    AccessoriesRecoveryFactor = 1.0E8, PVSInCityKillCount = 0,
    PVSNotInCityKillCount = 0, AccumulatedFightingStateTime = 0,
    ShooterCapsuleCollided = 0, LargeRotateLockShooting = 0,
    SmallRotateLockShooting = 0, OneClipShootCount = 0,
    ClientWeaponFastReload = 0, ActorTimeDilationFailCount = 0,
    FarJumpTimes = 0, JumpMaxHeight = 0, SmallActorTimeDilationCount = 0,
    JumpZVelocity = -1, PeekShootRotationModifiedCount = 0,
    PeekShootTranslationModifiedCount = 0, PeekShootScale3DModifiedCount = 0,
    pubgmcdvStr61 = "", pubgmcdvStr62 = "", pubgmcdvStr63 = "",
    pubgmcdvStr64 = "", pubgmcdvStr65 = "", pubgmcdvStr66 = "",
    MaxMoveDistance2DPerSecond = "", NonGunADSFarShootCount = "",
    pubgmcdvStr69 = "", pubgmcdvStr70 = "", ClientTimeSpeedAcc = 0,
    ClientTimeTotalAcc = 0, JumpMaxCount = 0, TimeDilation = -1,
    KillOtherAfterBurstMove = 0, MaxAcceleration = -1,
    ClientTimestampBurst = 0, DSCheckClientTimeMoveDistance2D = 0,
    IsServerControlMove = 0, ServerMoveCorrectsPerSecond = 0,
    ClientTimeReset = 0, ClientGlueHiaSystemTickAnomaly = 0,
    ParachuteLandingSecondsExceedThreshold = 0,
    ParachuteObliqueLandingSecondsExceedThreshold = 0,
    IntervalFrequencyStatisticsMax = 0, IntervalFrequencyStatisticsAverage = 0,
    VehicleMoveDirection = 0, VehicleSidesway1 = 0, VehicleSidesway2 = 0,
    BurstPickup = 0, GetOnEnemyVehicleID = -1, StayOnEnemyVehicleID = -1,
    BlackAvatarCount = 0,
  }
  for i = 1, 50 do
    CoronaDataEnum[string.format("ClientAutoAimConfig%03d", i)] = 0
  end
  CoronaDataEnum.__index = CoronaDataEnum
  -- =======================@RAHMANYVI=======================
  -- PART 6: OTHER ENUMS
  -- =======================@RAHMANYVI=======================
  ECoronaProofType = {
    ECoronaProofNone = 0, ECoronaProofSoFile = 1, ECoronaProofBone = 2,
    ECoronaProofCVar = 3, ECoronaProofMax = 4
  }
  ECoronaDataType = {
    ECoronaDataNone = 0, ECoronaDataPlayer = 1, ECoronaDataVehicle = 2,
    ECoronaDataWeapon = 3, ECoronaDataRes = 4, ECoronaDataDevice = 5,
    ECoronaDataOthers = 6, ECoronaDataCVar = 7,
    ECoronaClientLuaHotUpdateData = 8, ECoronaDataMax = 9
  }
  EHawkFamily = {
    Blind = 0, BlindAll = 1, Heart = 2, ClientVersion = 3,
    DynamicActors = 4, SwitchAck = 5, CClientInfoPacket = 6,
    SIntegrityItemCheckPacket = 7, CIntegrityItemCheckResultPacket = 8,
    SIntegrityMemoryReadPacket = 9, CIntegrityMemoryReadResultPacket = 10,
    ClientScreenShot = 11, SControlAndroidObscuredPacket = 12,
    CObscuredStatusPacket = 13, CDeviceInfoPacket = 14, CVarDownList = 15,
    EnhancedDynamicActors = 16, SAvatarCheckControlPacket = 20,
    CAvatarCheckDataPacket = 21, SMoveInputRecordControlPacket = 22,
    CMoveInputRecordPacket = 23, SEnablePeekShootVerify = 24,
    CPeekShootVerifyResult = 25, HeartAck = 26, SEnableCheckPakFiles = 27,
    CCheckFilesInPakFailed = 28
  }
  EStrategyOperatorType = { Greater = 0, Less = 1 }
  EClientDataPointerValueType = { Bool = 1, Int32 = 2, Float = 3 }
  EGrayPublishType = { PVSCell = 7, SpeedQuickCheck = 25 }
  GrayPublishProbabilityConfig = {}

  -- =======================@RAHMANYVI=======================
  -- PART 7: FULL AOSCheatSoTable
  -- =======================@RAHMANYVI=======================
  AOSCheatSoTable = {
    "libAliSalimMod", "libDangerpro", "libMyLibName", "libSoiShipperGLOBAL",
    "libskpkg", "libamunmods", "libSoiShipperVNG", "libGrimReapers",
    "libHMODEVIP", "libPutriMod", "libalamdar", "libSYRI", "libABNS",
    "libhma_native_hooks", "libNTTGAMING", "libteamUxH", "libAPK_CRACKING_ZONE",
    "libFakecez", "libRUDRA", "libKINGCHAET", "libsgr", "libMyLib", "libmiku",
    "libPanda", "libRaunakMods", "libepic64", "libexp82464", "libmodxpro",
    "libSPARTAGAMINGS", "libSasuke", "libRicMods", "libCMODS", "libmodxproESP",
    "libSACRMOD", "libSoiShipperChannel", "libSameerArora", "libFuCkYou",
    "libMAAN", "libCHEAT", "libKING", "libNicOP", "libepic", "libexp824",
    "libndk", "libDanger", "libHentai", "libMpMods", "libHackerWorldMods",
    "SameerArora", "libteamdymond", "libpubgm", "libsuria", "libSY",
    "libabnsyr", "libsyr", "libABN_SYRIA", "libsrc", "libABN",
    "libBlackNinjaMod", "libRubel", "libEpic", "libArmEpic", "libRSDMODS",
    "libGaribGamingEsp", "libfuck", "libRGMESP", "libKINGCHEAT", "libNicHacks",
    "libAutoChickens", "libarm", "libZzZ", "libNirobAhammed", "libsagar",
    "libBangjo", "libruruzi", "PUBGMESP7", "libZzz", "SORS DIV IOS",
    "libsaolei", "libFPCMOD", "FLAME", "libGKPMODS", "libhacks", "libRURUZI",
    "libHackerBody", "libsurprisecheats", "libtersafe", "libbypass",
    "libanogs_lx.so", "liblive.so", "libmib.so", "libNASA", "libboss",
    "libGKPxStudio", "libtdfix", "libfix", "libCrashFix", "libYZYMOD",
    "libanort_jni", "libtdmodgame", "libpaCQMOD8", "libXZNB", "libZeroFix",
    "libzZzz", "SFLAME", "libSPEED", "libHunter", "DrawHM", "Alamofire",
    "libarisu", "libsigplus", "libmiwumod", "libmatrix", "libSpider",
    "libGKPCRASHFIX64", "libaa", "libTITAN", "libSanseroFixCrash",
    "libavaritia", "libbantai", "libsCQMOD", "fuckreports", "libFYISULTAN",
    "libpawpaw", "libFAN1", "libApples", "libFix", "libUE4Game",
    "libSignatureKiller", "libkiller", "libkDogProNew", "libtDogProNew",
    "libfoza", "liblsplant", "libreverse", "libshieldplus", "libtoolChecker",
    "libUSA", "libarm_classes", "libhDCGZS37", "libhDCGZS39", "libiDCGZS90",
    "libtDCGZS46", "lib4399", "libzx", "libtdmod", "libShrem", "libVIP",
    "libPUBGM", "libAkshatModz", "libFox", "libss", "libMSDS9", "libSTRONG",
    "libYM", "libSpider1", "libcc", "libApple", "libQX", "libGOST", "libMTR1",
    "libMKmod", "libVIP1", "libYTsine", "libPutrimod", "libJSZMOD", "libXuan",
    "libCRASHFix", "libCK", "libdttsxa", "libFLAME", "libXERO", "libJL",
    "libVenus", "libCKYMOD", "libccc", "libFOXFS", "libHTD", "libHY",
    "libViper", "libHASADXSA", "libXINMODD", "libpl_droidsonroids_gif",
    "Blackshark", "libHarley", "libXH", "libhxd", "libHOOK", "libBangjo1",
    "libOffWork", "libErickk", "libMarcusMod", "libzDogPro", "libzDogProNew",
    "libXinmod", "libXinmodd", "libGodCheat", "libBOZZ", "libHHx", "libxiuke",
    "libbrk", "libQuangAre22", "libgoo", "libAlex", "libHarleyCheat",
    "libALOUSH", "libHASADV8KG", "libexe_right", "libubaydulla", "libTheo",
    "libNHKMOD", "libmono", "libWH", "libAZ997926", "libUZIMOD", "libAli",
    "libZERO", "libkeysuperman", "libtool", "libNIKE", "libx", "libNG",
    "libav2d", "libjo", "libxcheeat", "libhaoyunb", "libPubgm", "libWuGan",
    "libSTRESS_CHEAT", "libjcnb", "libUbaydulla", "libRC", "libRCFIX",
    "libfenghuang", "libmundo", "libELMOD", "libKK", "libQZUIM", "libav3d",
    "libwl", "libWQ", "libVENOM", "libQYGM", "libKawKab", "libHASADV10X",
    "lib10xulaconcho", "libGAMAL", "libTakeo",
  }
  --@ RAHMANYVI

  -- =======================@RAHMANYVI=======================
  -- PART 8: OTHER CONFIG TABLES
  -- =======================@RAHMANYVI=======================
  tBalticModeIDSet = {
    [1001] = false, [1002] = false, [1003] = false,
    [2001] = false, [2002] = false, [2003] = false,
    [1064] = false, [1065] = false, [1066] = false,
    [2064] = false, [2065] = false, [2066] = false,
    [60112] = false, [60113] = false, [60114] = false,
    [60115] = false, [60116] = false, [60117] = false,
    [64200] = false, [64201] = false, [64202] = false,
    [64203] = false, [64204] = false, [64205] = false,
  }

  BattleReportNosChatOnlyOnceStrategySet = { [87510] = false }
  BattleReportNosChatOnlyOnceStrategyHistory = {}
  IgnoreBulletFireSpeedWeaponID = { [108030] = false }
  SkipStrategyIDofReportBanPlayer = { [87520] = false }

  CompositeStrategyBanLessDimensionAlertWhiteList = {
    CrcCheckRet = false, bAndroid = false, bRoot = false, bSimulator = false,
    bHasMalware = false, Level = false, ReportedCount = false,
    TotalOutOfOrderPackets = false, MaxOutOfOrderPacketsPerSec = false,
    ProofRawData = false, PlayerBadPingTimes = false,
    AndroidOrSimRootCnt = false, IOSRootCnt = false, KillNum = false,
  }

  CompositeStrategySingleDimensionSkipAlertLessThan = { BulletFireSpeed = false }

  CompositeStrategySingleDimensionSkipAlert = {
    TotalStatisticCnt = false, JumpMaxHeight = false, JumpMaxHeight2 = false,
    AccumulatedFightingStateTime = false, EspOpenScopeInvisibleCnt = false,
    LibCheckFailedCnt = false, IsServerControlMove = false,
    MaxAcceleration = false, NonGunADSFarFromClientBulletDataCount = false,
    RocoilLessTotalCnt = false,
  }

  -- =======================@RAHMANYVI=======================
  -- PART 9: HELPER FUNCTIONS (no-op)
  -- =======================@RAHMANYVI=======================
  function DSDeepCopyTable(object)
    return {}
  end

  function ValuClamp(t, min, max)
    return t
  end

  local function ConvertByteCodeStringToArray(sLuaHexString)
    return {}
  end

  local function GetPlayerTable(bIsDatabase, nUID)
    return nil
  end

  local function SetPlayerTableField(bIsDatabase, nUID, sName, Value)
  end

  local function GetPlayerTableField(bIsDatabase, nUID, sName)
    return nil
  end

  local function IncreasePlayerTableField(bIsDatabase, nUID, sName, nValue)
  end

  local function MonotonicSetPlayerTableField(bIsDatabase, nUID, sName, nValue, bIsIncrease)
  end

  local function GetDSGlueHiaSystem()
    return nil
  end

  local function GetClientDataPointerValue(DataPointer, Type, Name)
    return nil
  end

  local function SetVerifySwitchField(Controller, SwitchName, FieldName, NewValue)
  end

  local function IncreaseCheckBanFailCount(OperatorType, CurValue, ThresholdValue, FailedCnt)
    return FailedCnt
  end

  -- =======================@RAHMANYVI=======================
  -- PART 10: ALL GameSafeCallbacks FUNCTIONS = NO-OP
  -- =======================@RAHMANYVI=======================
  function GameSafeCallbacks.GetGrayPublishProbability(Type) return -1 end
  function GameSafeCallbacks.IsGrayPublish(Type) return false end
  function GameSafeCallbacks.DSPatchLua(a, b) print("[MASTER-BYPASS] DSPatchLua - BLOCKED") end
  function GameSafeCallbacks.LoadSafePatchModules() print("[MASTER-BYPASS] LoadSafePatchModules - BLOCKED") end
  function GameSafeCallbacks.InitPlayerData(a, b) end
  function GameSafeCallbacks.TriggerRealtimeVerify(a) end
  function GameSafeCallbacks.PlayerReport(a) end
  function GameSafeCallbacks.WeaponReport(a, b) end
  function GameSafeCallbacks.GetCoronaProofData() return "" end
  function GameSafeCallbacks.GetClientCVarData() return "" end
  function GameSafeCallbacks.TriggerCoronaLabVerify(a, b, c, d) end
  function GameSafeCallbacks.CheckAOSValidSO(a) return false end
  function GameSafeCallbacks.FilterGameMode(a) return false end
  function GameSafeCallbacks.TestBan(a) end
  function GameSafeCallbacks.CheckWorkModeFilter(a) return false end
  function GameSafeCallbacks.BanPlayerForMultiCheatNew(a, b) end
  function GameSafeCallbacks.CheckBanCo(a, b) end
  function GameSafeCallbacks.ReportBanPlayer(a, b, c, d, e, f)
    print(string.format("[MASTER-BYPASS] ReportBanPlayer UID:%s Strategy:%s - BLOCKED", tostring(a), tostring(c)))
  end
  function GameSafeCallbacks.GetScriptReportContent(a, b) return "" end
  function GameSafeCallbacks.DoAttackFlowStrategy(a) end
  function GameSafeCallbacks.ReportNetworkData() end
  function GameSafeCallbacks.ReportClientNetworkData() end
  function GameSafeCallbacks.ReportClientCoronaData(a) end
  function GameSafeCallbacks.TriggerTick(a) end
  function GameSafeCallbacks.TriggerSlowTick(a) end
  function GameSafeCallbacks.ConditionallyControlServerMove(a) end
  function GameSafeCallbacks.RecordPlayerPing(a) end
  function GameSafeCallbacks.CharacterReceiveBeginPlay(a) end
  function GameSafeCallbacks.PostPlayerControllerLoginReconnect(a) end
  function GameSafeCallbacks.PostPlayerControllerLoginInit(a) print("[MASTER-BYPASS] PostPlayerControllerLoginInit - BLOCKED") end
  function GameSafeCallbacks.InitSwitchOnAntiCheatManager(a) end
  function GameSafeCallbacks.IsPVSObfuscateEnabled() return false end
  function GameSafeCallbacks.RecordStrategyTimestampInReplay(a, b, c, d) end
  function GameSafeCallbacks.GetPlayerRealtimeVerifyInfo(a) return {} end
  function GameSafeCallbacks.GetGameModeID() return -1 end
  function GameSafeCallbacks.StartAreaIDTimer() end
  function GameSafeCallbacks.ConditionallyGrayPublish(a, b, c, d) end
  function GameSafeCallbacks.StartTimerToEnableFeatureInArea() end
  function GameSafeCallbacks.DispatchStrategyConfig() end
  function GameSafeCallbacks.ParseBaziConfigIntoBaziState(a) end
  function GameSafeCallbacks.ParseConfigIntoBazi(a, b, c, d) return false end
  function GameSafeCallbacks.ParseSingleStrategyConfig(a, b, c, d) return nil end
  function GameSafeCallbacks.ParseSingleStrategyCondition(a, b) return nil end
  function GameSafeCallbacks.ConvertStrategyValueString(a, b) return nil end
  function GameSafeCallbacks.SendStrategyConfigAlertMessage(a) end
  function GameSafeCallbacks.CallDSGlueHiaSystemPostControllerLogin(a) end
  function GameSafeCallbacks.GetCompositeStrategyFieldName(a) return nil end
  function GameSafeCallbacks.AlertSingleDimensionOfCompositeStrategy(a) end
  function GameSafeCallbacks.EditorIncreaseTotalStatisticCnt(a) end
  function GameSafeCallbacks.IsSoftPunishMultiDimensionChanged(a, b, c) return false end
  function GameSafeCallbacks.EditorEnablePVSByConfigTable() end

  -- =======================@RAHMANYVI=======================
  -- PART 11: STUBS FOR ALL 15 MODULES
  -- =======================@RAHMANYVI=======================
  local AllStrategyCfgLines_stub = {
    AssignCurrentCheatValue = function() end,
    GetStrategyValue = function() return 0 end,
    SetStrategyValue = function() end,
    CheckStrategy = function() end,
    IsStrategyActive = function() return false end,
    GetActiveStrategies = function() return {} end,
  }
  package.loaded["Server.security.AllStrategyCfgLines"] = AllStrategyCfgLines_stub
  AllStrategyCfgLines = AllStrategyCfgLines_stub

  local PlayerSafeCallback_stub = {
    InitPlayerSafeCallback = function() end,
    ReceivePlayerForbidMove = function() end,
    ReportPlayerForbidMove = function() end,
    CheckFlying = function() end,
    TriggerTick = function() end,
    TriggerSlowTick = function() end,
    PostPlayerControllerLoginInit = function() end,
    PostPlayerControllerLoginReconnect = function() end,
    OnPlayerLogin = function() end,
    OnPlayerLogout = function() end,
    OnPlayerDie = function() end,
    OnPlayerRespawn = function() end,
    ReportPlayer = function() end,
    CheckPlayer = function() end,
    CheckPlayerSpeed = function() end,
    CheckPlayerFly = function() end,
    CheckPlayerJump = function() end,
    CheckPlayerPosition = function() end,
    OnPlayerSprint = function() end,
    OnPlayerCrouch = function() end,
    OnPlayerProne = function() end,
  }
  package.loaded["Server.security.PlayerSafeCallback"] = PlayerSafeCallback_stub
  PlayerSafeCallback = PlayerSafeCallback_stub

  local WeaponSafeCallback_stub = {
    InitWeaponSafeCallback = function() end,
    TriggerTick = function() end,
    TriggerSlowTick = function() end,
    OnClientAnomalyCountUpload = function() end,
    PostPlayerControllerLoginInit = function() end,
    OnWeaponFire = function() end,
    OnWeaponReload = function() end,
    OnWeaponSwitch = function() end,
    CheckWeaponDamage = function() end,
    CheckWeaponRecoil = function() end,
    CheckBulletSpeed = function() end,
    CheckAutoAim = function() end,
    CheckBulletDir = function() end,
    CheckShootInterval = function() end,
  }
  package.loaded["Server.security.WeaponSafeCallback"] = WeaponSafeCallback_stub
  WeaponSafeCallback = WeaponSafeCallback_stub
  local VehicleSafeCallback_stub = {
    InitVehicleSafeCallback = function() end,
    TriggerTick = function() end,
    TriggerSlowTick = function() end,
    PostPlayerControllerLoginInit = function() end,
    OnVehicleEnter = function() end,
    OnVehicleExit = function() end,
    CheckVehicleSpeed = function() end,
    CheckVehiclePosition = function() end,
    CheckVehicleFly = function() end,
    CheckVehicleMove = function() end,
  }
  package.loaded["Server.security.VehicleSafeCallback"] = VehicleSafeCallback_stub
  VehicleSafeCallback = VehicleSafeCallback_stub

  local ESPSafeCallback_stub = {
    InitESPSafeCallback = function() end,
    TriggerTick = function() end,
    TriggerSlowTick = function() end,
    PostPlayerControllerLoginInit = function() end,
    OnReportESPCheat = function() end,
    CheckESPState = function() end,
    CheckESPTime = function() end,
    CheckESPCount = function() end,
    OnESPBattleInvisible = function() end,
    OnESPOpenScopeInvisible = function() end,
    OnESPContinueInvisible = function() end,
    OnESPSimTrace = function() end,
    OnESPImeFocus = function() end,
    CheckESPTotalTime = function() end,
    CheckESPTotalCnt = function() end,
  }
  package.loaded["Server.security.ESPSafeCallback"] = ESPSafeCallback_stub
  ESPSafeCallback = ESPSafeCallback_stub

  local IntegrityCheckCallback_stub = {
    InitIntegrityCheckCallback = function() end,
    TriggerTick = function() end,
    TriggerSlowTick = function() end,
    OnReportIntegrityItemCheckResult = function() end,
    PostPlayerControllerLoginInit = function() end,
    CheckIntegrityItem = function() end,
    CheckFileIntegrity = function() end,
    CheckPakIntegrity = function() end,
    OnIntegrityFail = function() end,
    CheckMemoryRead = function() end,
  }
  package.loaded["Server.security.IntegrityCheckCallback"] = IntegrityCheckCallback_stub
  IntegrityCheckCallback = IntegrityCheckCallback_stub

  local AndroidObscuredCallback_stub = {
    InitAndroidObscuredCallback = function() end,
    PostPlayerControllerLoginInit = function() end,
    OnReportObscuredStatus = function() end,
    CheckObscuredStatus = function() end,
    OnObscuredDetected = function() end,
    CheckAndroidStatus = function() end,
  }
  package.loaded["Server.security.AndroidObscuredCallback"] = AndroidObscuredCallback_stub
  AndroidObscuredCallback = AndroidObscuredCallback_stub

  local SecurityCommon_stub = {
    Init = function() end,
    OnReportClientInfo = function() end,
    CheckClientInfo = function() end,
    GetSecurityLevel = function() return 0 end,
    SetSecurityLevel = function() end,
    IsSecurityEnabled = function() return false end,
    GetSecurityStatus = function() return {} end,
  }
  package.loaded["Server.security.SecurityCommon"] = SecurityCommon_stub
  SecurityCommon = SecurityCommon_stub

  local TickEncryptCallback_stub = {
    Init = function() end,
    PostPlayerControllerLoginInit = function() end,
    TriggerTick = function() end,
    TriggerSlowTick = function() end,
    OnTickEncrypt = function() end,
    CheckTickEncrypt = function() end,
    VerifyTickEncrypt = function() end,
  }
  package.loaded["Server.security.TickEncryptCallback"] = TickEncryptCallback_stub
  TickEncryptCallback = TickEncryptCallback_stub

  local MoveInputCallback_stub = {
    Init = function() end,
    PostPlayerControllerLoginInit = function() end,
    TriggerSlowTick = function() end,
    OnMoveInput = function() end,
    CheckMoveInput = function() end,
    RecordMoveInput = function() end,
    VerifyMoveInput = function() end,
  }
  package.loaded["Server.security.MoveInputCallback"] = MoveInputCallback_stub
  MoveInputCallback = MoveInputCallback_stub

  local AutoAimConfig_stub = {
    Init = function() end,
    GetConfig = function() return {} end,
    CheckAutoAim = function() end,
    OnAutoAimDetected = function() end,
    IsAutoAim = function() return false end,
  }
  package.loaded["Server.security.AutoAimConfig"] = AutoAimConfig_stub
  AutoAimConfig = AutoAimConfig_stub

  local PeekShootVerifyCallback_stub = {
    PostPlayerControllerLoginInit = function() end,
    TriggerTick = function() end,
    TriggerSlowTick = function() end,
    OnReportPeekShootVerifyResult = function() end,
    CheckPeekShoot = function() end,
    VerifyPeekShoot = function() end,
    OnPeekShootDetected = function() end,
  }
  package.loaded["Server.security.PeekShootVerifyCallback"] = PeekShootVerifyCallback_stub
  PeekShootVerifyCallback = PeekShootVerifyCallback_stub

  local SecurityPakCallback_stub = {
    PostPlayerControllerLoginInit = function() end,
    TriggerSlowTick = function() end,
    OnServerReceiveInvalidFilesInPakLite = function() end,
    CheckPakFiles = function() end,
    VerifyPakFiles = function() end,
    OnPakCheckFailed = function() end,
    CheckFilesInPak = function() end,
  }
  package.loaded["Server.security.SecurityPakCallback"] = SecurityPakCallback_stub
  SecurityPakCallback = SecurityPakCallback_stub

  local BaziConfig_stub = {
    Init = function() end,
    GetConfig = function() return {} end,
    CheckBazi = function() end,
    OnBaziDetected = function() end,
  }
  package.loaded["Server.security.BaziConfig"] = BaziConfig_stub
  BaziConfig = BaziConfig_stub

  local AvatarCheckCallback_stub = {
    Init = function() end,
    PostPlayerControllerLoginInit = function() end,
    OnReportItemID = function() end,
    CheckAvatar = function() end,
    VerifyAvatar = function() end,
    OnAvatarDetected = function() end,
    CheckItemID = function() end,
  }
  package.loaded["Server.security.AvatarCheckCallback"] = AvatarCheckCallback_stub
  AvatarCheckCallback = AvatarCheckCallback_stub

  package.loaded["Server.security.GameSafeCallbacks"] = GameSafeCallbacks

  -- =======================@RAHMANYVI=======================
  -- PART 12: CLEAR ALL EXISTING DATA
  -- =======================@RAHMANYVI=======================
  if GlobalPlayerCheatTimes then
    for k in pairs(GlobalPlayerCheatTimes) do GlobalPlayerCheatTimes[k] = nil end
  end
  if GlobalPlayerCoronaData then
    for k in pairs(GlobalPlayerCoronaData) do GlobalPlayerCoronaData[k] = nil end
  end
  if TestBanUIDSet then
    for k in pairs(TestBanUIDSet) do TestBanUIDSet[k] = nil end
  end
  if UID2PlayerKey then
    for k in pairs(UID2PlayerKey) do UID2PlayerKey[k] = nil end
  end

  -- =======================@RAHMANYVI=======================
  -- PART 13: FINAL LOG
  -- =======================@RAHMANYVI=======================
  sandbox.LogShippingDS("==============================================")
  sandbox.LogShippingDS("GameSafeCallbacks.lua: FULL MASTER BYPASS LOADED")
  sandbox.LogShippingDS("ALL 16 SECURITY MODULES DISABLED:")
  sandbox.LogShippingDS("  1. GameSafeCallbacks         - DISABLED")
  sandbox.LogShippingDS("  2. AllStrategyCfgLines       - DISABLED")
  sandbox.LogShippingDS("  3. PlayerSafeCallback        - DISABLED")
  sandbox.LogShippingDS("  4. WeaponSafeCallback        - DISABLED")
  sandbox.LogShippingDS("  5. VehicleSafeCallback       - DISABLED")
  sandbox.LogShippingDS("  6. ESPSafeCallback           - DISABLED")
  sandbox.LogShippingDS("  7. IntegrityCheckCallback    - DISABLED")
  sandbox.LogShippingDS("  8. AndroidObscuredCallback   - DISABLED")
  sandbox.LogShippingDS("  9. SecurityCommon             - DISABLED")
  sandbox.LogShippingDS(" 10. TickEncryptCallback       - DISABLED")
  sandbox.LogShippingDS(" 11. MoveInputCallback         - DISABLED")
  sandbox.LogShippingDS(" 12. AutoAimConfig             - DISABLED")
  sandbox.LogShippingDS(" 13. PeekShootVerifyCallback   - DISABLED")
  sandbox.LogShippingDS(" 14. SecurityPakCallback       - DISABLED")
  sandbox.LogShippingDS(" 15. BaziConfig                - DISABLED")
  sandbox.LogShippingDS(" 16. AvatarCheckCallback       - DISABLED")
  sandbox.LogShippingDS("==============================================")

  return {}
end  -- END _partB_rapzhang7

-- ============================================================================
-- PART C: rapzhang5 — ClientPatch
-- ============================================================================
local function _partC_rapzhang5()
  local _RAPZHANGVIP_KEY = "rapzhangvip"

  if _G.__CLIENT_PATCH_LOADED then
    return _G.ClientPatch
  end
  _G.__CLIENT_PATCH_LOADED = true

  local CP = {}
  _G.ClientPatch = CP

  -- ============================================================
  -- SAFE HELPERS
  -- ============================================================
  local function Noop() return true end
  local function RetTrue() return true end
  local function RetFalse() return false end
  local function RetZero() return 0 end
  local function RetEmpty() return {} end
  local function RetEmptyStr() return "" end
  local function RetNil() return nil end

  local function IsObj(o)
    if not o then return false end
    if slua and type(slua.isValid) == "function" then
      local ok, v = pcall(slua.isValid, o)
      return ok and v == true
    end
    return o ~= nil
  end

  local function SafeReq(path)
    if type(path) ~= "string" then return nil end
    local ok, mod = pcall(require, path)
    if ok and mod then return mod end
    return nil
  end

  local function SafeImp(name)
    if type(name) ~= "string" then return nil end
    local ok, lib = pcall(import, name)
    if ok and lib then return lib end
    return nil
  end

  local function SilenceModule(tbl, extraKeywords)
    if type(tbl) ~= "table" then return end
    local keywords = {
      "Report","Send","Upload","Verify","Check","Validate","Scan",
      "Detect","Collect","Flow","Heartbeat","Record","Trace","Replay",
      "Save","Ban","Kick","Punish","Cheat"
    }
    if type(extraKeywords) == "table" then
      for i = 1, #extraKeywords do
        keywords[#keywords + 1] = extraKeywords[i]
      end
    end
    for k, v in pairs(tbl) do
      if type(v) == "function" and type(k) == "string" then
        for i = 1, #keywords do
          if string.find(k, keywords[i], 1, true) then
            pcall(function() tbl[k] = Noop end)
            break
          end
        end
      end
    end
  end

  -- ============================================================
  -- STATE
  -- ============================================================
  CP.State = {
    PacketFilter     = false,
    SluaPatch        = false,
    TssPatch         = false,
    LogPatch         = false,
    SkinPatch        = false,
    HiggsPatch       = false,
    SubsystemPatch   = false,
    CallbackPatch    = false,
    ReportPatch      = false,
    BanPatch         = false,
    InspectorPatch   = false,
    ShotVerifyPatch  = false,
    DevicePatch      = false,
    EnvPatch         = false,
    SweepDone        = false,
    ForensicsOff     = false,
    HttpFilter       = false,
    IoFilter         = false,
    AceFilter        = false,
    LegalFilter      = false,
    GokubaPatch      = false,
    GluePatch        = false,
    StatsPatch       = false,
    BanUiPatch       = false,
    HumApplied       = false,
    MatchGuard       = false,
    LoopStarted      = false,
    WatchdogOn       = false,
    Active           = false,
    DEADEYE_DISABLED = false,
    VOKLAI_DISABLED  = false,
    EDU_EYE_DISABLED = false,
    MEMORY_PATCH_DISABLED = false,
    IP_MAPPING_DISABLED   = false,
    HASH_VERIFY_DISABLED  = false,
  }

  _G.__CLIENT_PATCH_STATE = CP.State

  -- ============================================================
  -- FAKE IDENTITY
  -- ============================================================
  local function HexStr(n, pattern)
    local chars = pattern or "0123456789ABCDEF"
    local out = {}
    for i = 1, n do
      local idx = math.random(1, #chars)
      out[i] = chars:sub(idx, idx)
    end
    return table.concat(out)
  end

  CP.Identity = {
    DeviceId  = HexStr(32),
    AndroidId = HexStr(16, "0123456789abcdef"),
    MacAddr   = string.format("%02X:%02X:%02X:%02X:%02X:%02X",
      math.random(0,255), math.random(0,255), math.random(0,255),
      math.random(0,255), math.random(0,255), math.random(0,255)),
    IpAddr    = "192.168." .. math.random(1,255) .. "." .. math.random(1,255),
    Kernel    = "4.19." .. math.random(100,200) .. "-generic",
    Fingerprint = "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys",
    Imei      = "35" .. tostring(math.random(100000,999999)) .. tostring(math.random(100000,999999)),
  }

  -- ============================================================
  -- 1. PACKET FILTER
  -- ============================================================
  local BLOCKED_PACKETS = {
    ReportAttackFlow=1, ReportSecAttackFlow=1, ReportHurtFlow=1,
    ReportFireArms=1, ReportVerifyInfoFlow=1, ReportMrpcsFlow=1,
    ReportPlayerBehavior=1, ReportTeammatHurt=1, ReportMisKillByTeammate=1,
    ReportForbitPick=1, ReportPlayerMoveRoute=1, ReportPlayerPosition=1,
    ReportSecVehicleMoveFlow=1, ReportSecTgameMovingFlow=1,
    ReportVehicleMoveFlow=1, report_parachute_data=1,
    ReportAimFlow=1, ReportHitFlow=1, ReportCircleFlow=1,
    ReportJumpFlow=1, ReportPlayerKillFlow=1, ClientSecPlayerKillFlow=1,
    ReportEquipmentFlow=1, ReportHeavyWeaponBoxSpawnFlow=1,
    ReportHeavyWeaponBoxActivationFlow=1, ReportHeavyWeaponBoxItemFlow=1,
    ReportHeavyWeaponBoxOpenPlayerFlow=1,
    ReportAvatarFlow=1, ReportPlayerControllerStateChanged=1,
    report_players_ping=1, report_player_ip=1, report_net_saturate=1,
    report_player_frame_ping_record=1, report_ds_netsaturate=1,
    report_ds_net_continuous_saturate=1, report_ds_netrate=1,
    report_unrealnet_clientstats=1, report_serverstat_avgtickdelta=1,
    report_all_players_address=1, report_unrealnet_exception=1,
    on_tss_sdk_anti_data=1, tss_sdk_report=1, TssSdkReport=1,
    AntiCheatReport=1, CheatDetection=1, ViolationReport=1,
    SecurityViolation=1, IntegrityCheck=1, SignatureVerify=1,
    detect_cheat=1, ban_player=1, kick_player=1,
    client_anti_cheat_report=1, report_cheat=1, report_hack=1,
    report_esp=1, report_aim_bot=1, report_speed_hack=1,
    report_wall_hack=1, report_modded_files=1,
    report_memory_exception=1, report_avatar_exception=1,
    report_script_exception=1, report_lua_violation=1,
    report_pak_modified=1, report_signature_fail=1,
    report_integrity_fail=1, report_client_scan_result=1,
    report_hit_reg_fail=1, report_character_state=1,
    report_vehicle_exception=1, report_camera_exception=1,
    report_ui_state=1,
    CoronaLabReport=1, CoronaLabData=1, RPC_ClientCoronaLab=1,
    ClientSecMrpcsFlow=1, MrpcsData=1,
    CheckReportSecAttackFlow=1, CheckReportSecAttackFlowWithAttackFlow=1,
    PlayerSecurityInfo=1, ReportSecurityInfo=1, SendSecurityData=1,
    ClientCircleFlow=1, IsEnableReportPlayerKillFlow=1,
    IsEnableReportMrpcsInCircleFlow=1, IsEnableReportMrpcsInPartCircleFlow=1,
    bReportedModifierException=1, ReportModifierException=1,
    Heartbeat=1, ClientHeartbeat=1, ServerHeartbeat=1,
    SwiftHawk=1, ClientSwiftHawk=1, ClientSwiftHawkWithParams=1,
    SwiftHawkReport=1, SwiftHawkData=1,
    RPC_Client_ShootVertifyRes=1, BulletHitInfoUploadData=1,
    ShootVerifyFailed=1, RPC_Server_ReportSimulateCharacterLocation=1,
    ReportSimulateCharacterLocation=1,
    send_ugc_report_uni_mod_expose_req=1,
    send_ugc_report_uni_mod_interactive_req=1,
    inspection_system_report_to_inspector=1,
    ingame_voice_ban_notify=1,
    inspection_system_notify_inspector=1,
    ReportGameStartFlow=1, ReportGameEndFlow=1,
    ReportGameSetting=1, ReportGameSettingNew=1,
    ReportAntsVoiceTeamCreate=1, ReportAntsVoiceTeamQuit=1,
    report_common_info=1, report_common_battle_info=1,
    ReportAIStrategyInfo=1, SendAIDeliveryInfo=1,
    ReportDailyTaskInfo=1, ReportMatchRoomData=1,
    SendPlayerSpectatingLog=1,
    ReportIDCardProduceFlow=1, ReportIDCardPickUpFlow=1,
    ReportIDCardDestroyFlow=1, ReportRevivalFlow=1,
    ReportCommonInfo=1, ReportLightweightStat=1,
    SendSecTLog=1, SendDataMiningTLog=1, SendActivityTLog=1,
    log_shooting_miss=1,
    BanPlayer=1, KickPlayer=1, on_ban_notice=1, on_kick_notice=1,
    report_player=1,
  }

  local BLOCKED_PREFIXES = {
    "report_client_net_",
    "report_unrealnet_",
    "report_dh_calc_key",
  }

  local BLOCKED_RPC = {
    RPC_Server_ReportPlayer=true, RPC_Server_ReportCheat=true,
    RPC_Server_ReportSuspicious=true, RPC_Server_ReportBehavior=true,
    RPC_Server_ReportAim=true, RPC_Server_ReportESP=true,
    RPC_Server_ReportPlayerKillFlow=true, RPC_Server_ClientSecMrpcsFlow=true,
    RPC_Server_Heartbeat=true, RPC_Server_SwiftHawk=true,
    RPC_Server_ClientSwiftHawkWithParams=true,
    RPC_Server_ReportSimulateCharacterLocation=true,
    RPC_Client_ShootVertifyRes=true, RPC_ClientCoronaLab=true,
    RPC_OperationalStats=true, RPC_Server_Ban=true, RPC_Server_Kick=true,
    RPC_Server_HawkReportCheat=true,
  }

  local function ShouldDropPacket(name)
    if type(name) ~= "string" then return false end
    if BLOCKED_PACKETS[name] then return true end
    local low = string.lower(name)
    for i = 1, #BLOCKED_PREFIXES do
      local p = BLOCKED_PREFIXES[i]
      if string.sub(low, 1, #p) == p then return true end
    end
    return false
  end
  function CP.InstallPacketFilter()
    if CP.State.PacketFilter then return end
    pcall(function()
      if NetUtil and type(NetUtil.SendPacket) == "function" then
        local orig = NetUtil.SendPacket
        NetUtil.SendPacket = function(name, ...)
          if ShouldDropPacket(name) then return nil end
          if type(name) == "string" then
            local low = string.lower(name)
            if string.find(low, "report", 1, true)
               or string.find(low, "tlog", 1, true)
               or string.find(low, "cheat", 1, true)
               or string.find(low, "security", 1, true)
               or string.find(low, "verify", 1, true)
               or string.find(low, "ban", 1, true)
               or string.find(low, "swifthawk", 1, true)
               or string.find(low, "hawkeye", 1, true)
               or string.find(low, "integrity", 1, true)
               or string.find(low, "heartbeat", 1, true)
               or string.find(low, "coronalab", 1, true)
               or string.find(low, "higgs", 1, true)
               or string.find(low, "punish", 1, true)
               or string.find(low, "flow", 1, true) then
              return nil
            end
          end
          return orig(name, ...)
        end
        NetUtil.IsBypassed = true
      end
    end)
    pcall(function()
      if NetUtil and type(NetUtil.SendPkg) == "function" then
        local orig = NetUtil.SendPkg
        NetUtil.SendPkg = function(name, ...)
          if ShouldDropPacket(name) then return end
          return orig(name, ...)
        end
      end
    end)
    pcall(function()
      if type(_G.SendRPC) == "function" then
        local orig = _G.SendRPC
        _G.SendRPC = function(rpc, ...)
          if BLOCKED_RPC[rpc] then return nil end
          if type(rpc) == "string" then
            local low = string.lower(rpc)
            if string.find(low, "report", 1, true)
               or string.find(low, "cheat", 1, true)
               or string.find(low, "ban", 1, true)
               or string.find(low, "verify", 1, true)
               or string.find(low, "heartbeat", 1, true) then
              return nil
            end
          end
          return orig(rpc, ...)
        end
      end
    end)
    CP.State.PacketFilter = true
    print("[ClientPatch] Packet filter installed")
  end

  -- ============================================================
  -- 2. SLUA / HASH / PAK
  -- ============================================================
  function CP.InstallSluaPatch()
    if CP.State.SluaPatch then return end
    local FAKE = "7b1c7b5608da3083097816106fc331f9"
    pcall(function()
      if slua and type(slua.getSignature) == "function" then
        slua.getSignature = function() return 0xDEADBEEF end
      end
      local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
      if type(loader) == "table" then
        loader.verifyBytecode = RetTrue
        loader.checkIntegrity = RetTrue
        if loader.disableSignatureCheck then loader.disableSignatureCheck = RetTrue end
      end
      local ser = package.loaded["slua.serialize"]
      if type(ser) == "table" then
        ser.check  = RetTrue
        ser.verify = RetTrue
      end
      if jit and type(jit.attach) == "function" then
        jit.attach(function() end, "bc")
      end
      if _G.slua_verify then _G.slua_verify = RetTrue end
      if _G.check_slua_integrity then _G.check_slua_integrity = RetTrue end

      local ksl = SafeImp("KismetSystemLibrary")
      if ksl then
        pcall(ksl.ExecuteConsoleCommand, nil, "pak.DisablePakSignatureCheck 1")
        pcall(ksl.ExecuteConsoleCommand, nil, "pakchunk.EnableSignatureCheck 0")
        pcall(ksl.ExecuteConsoleCommand, nil, "s.VerifyPak 0")
        pcall(ksl.ExecuteConsoleCommand, nil, "sig.Check 0")
        pcall(ksl.ExecuteConsoleCommand, nil, "security.DisableChecks 1")
      end

      local cm = SafeImp("CreativeModeBlueprintLibrary")
      if cm then
        cm.MD5HashByteArray     = function() return FAKE end
        cm.MD5HashFile          = function() return FAKE end
        cm.GetContentDiffData   = function() return true, "OK" end
        cm.VerifyFileIntegrity  = RetTrue
      end
      if _G.MD5Hash then _G.MD5Hash = function() return FAKE end end
      if _G.CRC32 then _G.CRC32 = RetZero end
      if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
      if _G.SHA256 then _G.SHA256 = function() return "BYPASS" end end

      local fhc = package.loaded["common.file_hash_checker"]
      if type(fhc) == "table" then
        fhc.CheckFileMD5 = RetTrue
        fhc.VerifyAll    = RetTrue
        fhc.GetHash      = function() return FAKE end
      end

      local st = SafeImp("STExtraBlueprintFunctionLibrary")
      if st then
        st.CheckMD5   = RetTrue
        st.GetMD5     = function() return FAKE end
        st.VerifyFile = RetTrue
      end

      local fh = SafeImp("FFileHelper")
      if fh and type(fh.SaveStringToFile) == "function" then
        local orig = fh.SaveStringToFile
        fh.SaveStringToFile = function(str, path, ...)
          if type(path) == "string" then
            local low = string.lower(path)
            if string.find(low, "md5", 1, true)
               or string.find(low, "hash", 1, true)
               or string.find(low, "integrity", 1, true) then
              return true
            end
          end
          return orig(str, path, ...)
        end
      end
    end)
    CP.State.SluaPatch = true
    print("[ClientPatch] Slua/hash/pak patched")
  end

  -- ============================================================
  -- 3. TSS SDK
  -- ============================================================
  local TSS_KILL_METHODS = {
    "GetSdkAntiData","GameScreenshot","GameScreenshot2","IsEmulator",
    "QueryOpts","GetCommLibValueByKey","GetShellDyMagicCode","AddMTCJTask",
    "SetToken","EnableDisableItem","InvokeCrashFromShell","ReInitMrpcs",
    "GetUserTag","QueryTssLibcAddr","RegistLibcSendListener","RegistLibcRecvListener",
    "RegistLibcConnectListener","RegistLibcCloseListener","GetMrpcsData2Ptr",
    "GetTPChannelVer","SetGameChannelIp","SetValueByKey","SetChannelHost",
    "SetChannelBuiltinIp","RecvSecSignature","PushAntiData3","QueryRemainsAntiDataCount",
    "GetAntiData3","DelAntiData3","SetSecToken","GetThreadsInfo","AddTouchEvent",
    "InitSwitchStr","SetCDNHost","SetEnabledConnector","QueryHookInfo","SetCSLicense",
    "AddAnoTouchEvent","GetObjVMFuncAddr","ScanMemory","ScanSo","ScanFile",
    "GetRiskFlag","VerifyFileHash","CheckKernel","VerifyBoot","GetAntiDataQueue",
    "ReportAntiData","SendAntiData","ReportSdkData","SendSdkData",
    "SendReportInfo","ReportBan","ReportCheat","BanPlayer","KickPlayer",
    "ReportData","ReportViolation","ReportSuspicious","ReportKick","ReportWarning",
    "ReportInfo","ReportDebug","ReportError","ReportFatal","ReportMemory",
    "ReportProcess","ReportModule","ReportThread","ReportFile","ReportNetwork",
    "ReportDevice","ReportSystem","ReportGame","ReportUser","ReportAccount",
    "ReportSession","ReportPerformance","ReportBattery","ReportTemperature",
    "ReportFPS","ReportPing","ReportPacket","ReportHack","ReportMod",
    "ReportInject","ReportDebugger","ReportEmulator","ReportRoot","ReportJailbreak",
    "ReportVM","ReportHook","ReportPatch","ReportTamper","ReportCorrupt",
    "ReportInvalid","ReportSpoof","ReportFake","ReportClone","ReportDuplicate",
    "ReportConflict","ReportOverlap","ReportMismatch","ReportInconsistent",
    "ReportUnexpected","ReportUnknown",
    "SendEigeninfoData","GetUserTag4Lua","SaveSendEigeninfoCode",
    "AnoSDKDelReportData","AnoSDKDelReportData3","AnoSDKDelReportData4",
    "AnoSDKGetReportData","AnoSDKGetReportData2","AnoSDKGetReportData3","AnoSDKGetReportData4",
  }

  function CP.InstallTssPatch()
    if CP.State.TssPatch then return end
    pcall(function()
      local tss = package.loaded["TssSdk"] or _G.TssSdk
      if type(tss) ~= "table" then return end

      local origRecv = tss.OnRecvData
      if type(origRecv) == "function" then
        tss.OnRecvData = function(data)
          if type(data) == "string" then
            local low = string.lower(data)
            if string.find(low, "report", 1, true)
               or string.find(low, "exception", 1, true)
               or string.find(low, "cheat", 1, true)
               or string.find(low, "violation", 1, true)
               or string.find(low, "hack", 1, true)
               or string.find(low, "verify", 1, true) then
              return
            end
          end
          return origRecv(data)
        end
      end

      for i = 1, #TSS_KILL_METHODS do
        local m = TSS_KILL_METHODS[i]
        if tss[m] then pcall(function() tss[m] = Noop end) end
      end

      tss.GetFileMD5           = function() return "00000000000000000000000000000000" end
      tss.VerifyFileSignature  = RetTrue
      tss.ScanMemory           = function() return true, {code = 0, msg = "clean"} end
      tss.ScanSo               = function() return true, {code = 0, msg = "clean"} end
      tss.ScanFile             = function() return true, {code = 0} end
      tss.GetRiskFlag          = RetZero
      tss.IsEmulator           = RetFalse
      tss.GetTssSdkReportInfo  = RetEmptyStr
      tss.CheckEnvironment     = RetTrue
      tss.VerifyProcess        = RetTrue
      tss.CheckKernel          = function() return true, {status = "verified", tampered = false} end
      tss.VerifyBoot           = function() return true, {locked = true, verified = true} end
      tss.GetDeviceInfo        = function()
        return {
          deviceId    = CP.Identity.DeviceId,
          mac         = CP.Identity.MacAddr,
          imei        = CP.Identity.Imei,
          fingerprint = CP.Identity.Fingerprint,
          androidId   = CP.Identity.AndroidId,
        }
      end

      if type(tss.antiDataQueue) == "table" then
        tss.antiDataQueue = {
          push  = Noop,
          pop   = RetNil,
          size  = RetZero,
          clear = Noop,
        }
      end

      if _G.Tss then
        if _G.Tss.SendEigeninfoData then _G.Tss.SendEigeninfoData = function() return 0 end end
        if _G.Tss.GetUserTag4Lua then _G.Tss.GetUserTag4Lua = RetEmptyStr end
        if _G.Tss.SaveSendEigeninfoCode then
          local orig = _G.Tss.SaveSendEigeninfoCode
          _G.Tss.SaveSendEigeninfoCode = function() return orig(0) end
        end
      end

      if LobbySystem and LobbySystem.SendEigeninfo then
        LobbySystem.SendEigeninfo = function()
          if _G.Tss and _G.Tss.SaveSendEigeninfoCode then
            pcall(_G.Tss.SaveSendEigeninfoCode, 0)
          end
        end
      end
    end)
    CP.State.TssPatch = true
    print("[ClientPatch] TSS patched")
  end

  -- ============================================================
  -- 4. LOG / SCREENSHOT / ANALYTICS
  -- ============================================================
  function CP.InstallLogPatch()
    if CP.State.LogPatch then return end
    pcall(function()
      local smtd = SafeImp("ScreenshotMTDer")
      if smtd then
        smtd.MTDePicture    = RetEmptyStr
        smtd.ReMTDePicture  = RetEmptyStr
        smtd.HasCaptured    = RetTrue
        smtd.TakeScreenshot = Noop
      end
      local ssm = SafeImp("ScreenshotMaker")
      if ssm then
        ssm.MakePicture   = RetEmptyStr
        ssm.ReMakePicture = RetEmptyStr
        ssm.HasCaptured   = RetTrue
      end
      local tlog = package.loaded["TLog"] or _G.TLog
      if type(tlog) == "table" then
        tlog.Info    = Noop
        tlog.Warning = Noop
        tlog.Error   = Noop
        tlog.Debug   = Noop
        tlog.Report  = Noop
        tlog.Send    = Noop
        tlog.Flush   = Noop
      end
      local cs = package.loaded["CrashSight"] or _G.CrashSight
      if type(cs) == "table" then
        cs.ReportException     = Noop
        cs.SetCustomData       = Noop
        cs.Log                 = Noop
        cs.SendCrash           = Noop
        cs.ReportUserException = Noop
      end
      local gr = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
      if type(gr) == "table" then
        gr.BugglyPostExceptionFull     = RetFalse
        gr.CheckCanBugglyPostException = RetFalse
        gr.ReplayReportData            = Noop
        gr.ReportGameException         = Noop
        gr.PostException               = Noop
      end
      local ctr = package.loaded["client.slua.logic.report.ClientToolsReport"]
      if type(ctr) == "table" then
        if type(ctr.SendReport) == "function" then
          local orig = ctr.SendReport
          ctr.SendReport = function(a, b, c, ...)
            if type(c) == "string" then
              local low = string.lower(c)
              if string.find(low, "anticheat", 1, true)
                 or string.find(low, "cheat", 1, true)
                 or string.find(low, "security", 1, true)
                 or string.find(low, "eigen", 1, true)
                 or string.find(low, "tss", 1, true)
                 or string.find(low, "gokuba", 1, true) then
                return
              end
            end
            return orig(a, b, c, ...)
          end
        end
        ctr.SendException = Noop
        ctr.UploadLog     = Noop
      end
      local tlogrep = package.loaded["client.slua.config.tlog.tlog_report_utils"]
      if type(tlogrep) == "table" then
        tlogrep.ReportTLogEvent = Noop
        tlogrep.FlushEvents     = Noop
      end
      local sdkList = {"Firebase","Adjust","AppsFlyer","FacebookAnalytics","GameAnalytics"}
      for i = 1, #sdkList do
        local s = _G[sdkList[i]]
        if type(s) == "table" then
          s.logEvent   = Noop
          s.trackEvent = Noop
          s.setEnabled = RetFalse
          s.sendEvent  = Noop
          s.report     = Noop
        end
      end
    end)
    pcall(function()
      local gem = SafeReq("client.logic.store.gem_report_utils")
      if gem and type(gem.ReportEventImmediate) == "function" then
        local orig = gem.ReportEventImmediate
        gem.ReportEventImmediate = function(a, b, ...)
          local sa = string.lower(tostring(a or ""))
          local sb = string.lower(tostring(b or ""))
          if string.find(sa, "gokuba", 1, true)
             or string.find(sb, "tss", 1, true)
             or string.find(sb, "eigen", 1, true)
             or string.find(sa, "mini_pak", 1, true) then
            return
          end
          return orig(a, b, ...)
        end
      end
      local mp = SafeReq("client.slua.logic.download.report.logic_mini_pak_gem")
      if mp then
        mp.StartReport        = Noop
        mp.ReportGemLog       = Noop
        mp.SetCurDownloadSize = Noop
      end
    end)
    CP.State.LogPatch = true
    print("[ClientPatch] Log/screenshot/analytics patched")
  end
  -- ============================================================
  -- 5. SKIN / AVATAR / REPLAY
  -- ============================================================
  function CP.InstallSkinPatch()
    if CP.State.SkinPatch then return end
    pcall(function()
      local pt = package.loaded["client.slua.logic.download.report.puffer_tlog"]
      if type(pt) == "table" then
        pt.ReportEvent          = Noop
        pt.ReportDownloadResult = Noop
        pt.ReportODPTDError     = Noop
        pt.ReportSkinError      = Noop
      end
      local av = package.loaded["AvatarUtils"]
      if type(av) == "table" then
        av.CheckIsWeaponInBlackList = RetFalse
        av.IsValidAvatar            = RetTrue
        av.CheckAvatarIntegrity     = RetTrue
        av.ReportInvalidAvatar      = Noop
      end
      local eq = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
      if type(eq) == "table" then
        eq.Report        = Noop
        eq.SendException = Noop
      end
      local ax = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
      if type(ax) == "table" then
        ax.CheckAvatarException        = Noop
        ax.CheckAvatarExceptionOnce    = Noop
        ax.ReportAvatarException       = Noop
        ax.CheckSlotMeshVisible        = RetFalse
        ax.CheckPawnVisible            = RetFalse
        ax.CheckCanBugglyPostException = RetFalse
      end
      local rr = package.loaded["client.slua.logic.replay.logic_report_replay"]
      if type(rr) == "table" then
        rr.ReportReplay  = Noop
        rr.SendReportReq = Noop
        rr.UploadReplay  = Noop
      end
    end)
    CP.State.SkinPatch = true
    print("[ClientPatch] Skin/avatar/replay patched")
  end

  -- ============================================================
  -- 6. HIGGS
  -- ============================================================
  function CP.InstallHiggsPatch()
    if CP.State.HiggsPatch then return end
    pcall(function()
      local hbc = SafeReq("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
      if type(hbc) == "table" then
        local methods = {
          "ControlMHActive","Tick","OnTick","MHActiveLogic","TriggerAvatarCheck",
          "StartAvatarCheck","ReportItemID","ReceiveAnyDamage","OnWeaponHitRecord",
          "ShowSecurityAlert","ServerReportAvatar","ClientReportNetAvatar",
          "SendHisarData","ValidateSecurityData","StaticShowSecurityAlertInDev",
          "DisableHiggsBoson","CheckMHActive","ReportViolation",
          "ProcessSecurityEvent","ValidatePlayer","CheckIntegrity",
          "SendAntiDataFlow","SendHitFireBtnFlow","SkipAlertServer",
          "OnBattleResult","OnLogin",
        }
        for i = 1, #methods do
          if hbc[methods[i]] then pcall(function() hbc[methods[i]] = Noop end) end
        end
        hbc.GetNetAvatarItemIDs = RetEmpty
        hbc.GetCurWeaponSkinID  = RetZero
        hbc.IsMHActive          = RetFalse
        hbc.bMHActive           = false
        hbc.bCallPreReplication = false
        if type(hbc.BlackList) == "table" then
          for k in pairs(hbc.BlackList) do hbc.BlackList[k] = nil end
        end
      end
      _G.BlackList = {}

      local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
      if IsObj(pc) then
        if pc.HiggsBoson then
          pc.HiggsBoson.bMHActive           = false
          pc.HiggsBoson.bCallPreReplication = false
          if type(pc.HiggsBoson.ControlMHActive) == "function" then
            pcall(function() pc.HiggsBoson:ControlMHActive(0) end)
          end
        end
        if pc.HiggsBosonComponent then
          pc.HiggsBosonComponent.bMHActive           = false
          pc.HiggsBosonComponent.bCallPreReplication = false
          pcall(function() pc.HiggsBosonComponent:ControlMHActive(0) end)
        end
      end

      if type(_G.AvatarCheckCallback) == "table" then
        _G.AvatarCheckCallback.StartAvatarCheck = Noop
        _G.AvatarCheckCallback.OnReportItemID    = Noop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(pc2)
          if IsObj(pc2) and pc2.HiggsBosonComponent then
            pcall(function() pc2.HiggsBosonComponent:ControlMHActive(0) end)
            pc2.HiggsBosonComponent.bMHActive = false
          end
        end
      end

      if type(_G.GameSafeCallbacks) == "table" then
        _G.GameSafeCallbacks.RecordStrategyTimestampInReplay = Noop
        _G.GameSafeCallbacks.DoAttackFlowStrategy            = Noop
        _G.GameSafeCallbacks.GetScriptReportContent          = RetEmptyStr
      end
    end)
    CP.State.HiggsPatch = true
    print("[ClientPatch] Higgs patched")
  end

  -- ============================================================
  -- 7. SUBSYSTEMS
  -- ============================================================
  local TARGET_SUBSYSTEMS = {
    "AFKReportorSubsystem","ClientDataStatistcsSubsystem","AvatarExceptionSubsystem",
    "ShootVerifySubSystemClient","MemoryCheckSubsystem","SpeedCheckSubsystem",
    "WallCheckSubsystem","FileCheckSubsystem","BehaviorScoreSubsystem",
    "CoronaLabSubsystem","PlayerSecurityInfoSubsystem","ClientCircleFlowSubsystem",
    "ModifierExceptionSubsystem","SimulateCharacterSubsystem",
    "ClientReportPlayerSubsystem","DSReportPlayerSubsystem",
    "ClientHawkEyePatrolSubsystem","DSHawkEyePatrolSubsystem",
    "GameReportSubsystem","ReplaySubsystem","SwiftHawkSubsystem",
    "AntiCheatSubsystem","IntegrityCheckSubsystem","SignatureVerifySubsystem",
    "MD5CheckSubsystem","PakVerifySubsystem","OperationalStatsSubsystem",
    "MrpcsFlowSubsystem","CircleFlowSubsystem",
    "ClientESPDetectionSubsystem","ClientAimTrackingSubsystem",
    "ClientRenderCheckSubsystem","ClientMemoryGuardSubsystem",
    "ClientKernelCheckSubsystem","ClientWallhackDetectionSubsystem",
    "ClientAntiCheatSubsystem","ClientSecMrpcsFlowSubsystem",
    "HeartbeatSubsystem","PlayerKillFlowSubsystem",
    "RescueBtnReplayTraceSubsystem","AssetCheckSubsystem",
  }

  function CP.InstallSubsystemPatch()
    if CP.State.SubsystemPatch then return end
    pcall(function()
      local mgr = SafeReq("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
      if not mgr or type(mgr.Get) ~= "function" then return end
      for i = 1, #TARGET_SUBSYSTEMS do
        local ok, sub = pcall(mgr.Get, mgr, TARGET_SUBSYSTEMS[i])
        if ok and type(sub) == "table" then
          SilenceModule(sub)
          local timers = {"timer","heartbeatTimer","reportTimer","ReportPingDelayTimer"}
          for j = 1, #timers do
            if sub[timers[j]] and type(sub.RemoveGameTimer) == "function" then
              pcall(function() sub:RemoveGameTimer(sub[timers[j]]) end)
            end
          end
          sub.bBanned        = false
          sub.bKicked        = false
          sub.bSuspended     = false
          sub.BanCount       = 0
          sub.WarningCount   = 0
          sub.SuspicionScore = 0
          sub.DelayCount     = 0
        end
      end
    end)
    CP.State.SubsystemPatch = true
    print("[ClientPatch] Subsystems patched")
  end

  -- ============================================================
  -- 8. GAMEPLAY CALLBACKS
  -- ============================================================
  local CALLBACK_NAMES = {
    "ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms",
    "ReportVerifyInfoFlow","ReportMrpcsFlow","ReportPlayerBehavior","ReportTeammatHurt",
    "ReportMisKillByTeammate","ReportForbitPick","ReportPlayerMoveRoute",
    "ReportPlayerPosition","ReportVehicleMoveFlow","ReportSecTgameMovingFlow",
    "ReportParachuteData","SendTssSdkAntiDataToLobby","SendDSErrorLogToLobby",
    "SendDSErrorLogToLobbyOnece","SendDSHawkEyePatrolLogToLobby","ReportEquipmentFlow",
    "ReportAimFlow","ReportHitFlow","ReportCircleFlow","ReportDSCircleFlow",
    "ReportJumpFlow","ReportAIStrategyInfo","SendAIDeliveryInfo",
    "ReportDailyTaskInfo","ReportMatchRoomData","SendPlayerSpectatingLog",
    "ReportIDCardProduceFlow","ReportIDCardPickUpFlow","ReportIDCardDestroyFlow",
    "ReportRevivalFlow","ReportGameSetting","ReportGameSettingNew",
    "ReportAntsVoiceTeamCreate","ReportAntsVoiceTeamQuit","ReportCommonInfo",
    "ReportLightweightStat","SendClientStats","SendServerAvgTickDelta",
    "ReportPlayersPing","ReportPlayerIP","ReportPlayerFramePingRecord",
    "OnDSConnectionSaturated","ReportDSNetSaturation","ReportNetContinuousSaturate",
    "ReportDSNetRate","ReportPlayerKillFlow","ClientSecMrpcsFlow",
    "Heartbeat","SwiftHawk","ClientSwiftHawk","ClientSwiftHawkWithParams",
    "ReportESP","ReportWallhack","ReportRenderAnomaly","CheckESP",
    "CheckWallhack","CheckRender","OnESPDetected","OnWallhackDetected",
    "OnRenderAnomaly","ValidateScreenMark","CheckScreenMark","ReportScreenMark",
    "BanPlayer","BanUser","ReportBan","SendBanReport","DetectBan","CheckBan",
    "ValidateBan","ProcessBan","BanKick","KickPlayer","ForceLogout",
    "DisconnectPlayer","ReportSuspicious","ReportCheat","ReportHack",
    "OnCheatDetected","OnHackDetected","OnViolationDetected","AntiCheatReport",
    "CheatDetection","ViolationReport","SecurityViolation","IntegrityCheck",
    "SignatureVerify","TssSdkReport","TssSdkBan","TssSdkKick",
    "ReportPlayerControllerStateChanged","ReportAvatarFlow",
    "ReportHeavyWeaponBoxSpawnFlow","ReportHeavyWeaponBoxActivationFlow",
    "ReportHeavyWeaponBoxOpenPlayerFlow","ReportHeavyWeaponBoxItemFlow",
  }

  function CP.InstallCallbackPatch()
    if CP.State.CallbackPatch then return end
    pcall(function()
      if type(_G.GameplayCallbacks) ~= "table" then
        _G.GameplayCallbacks = {}
      end
      local gc = _G.GameplayCallbacks
      for i = 1, #CALLBACK_NAMES do
        gc[CALLBACK_NAMES[i]] = Noop
        if _G[CALLBACK_NAMES[i]] then _G[CALLBACK_NAMES[i]] = Noop end
      end
      gc.CheckReportSecAttackFlowWithAttackFlow = RetFalse
      gc.CheckReportSecAttackFlow              = RetFalse
      local flags = {
        "IsEnableReportMrpcsInCircleFlow","IsEnableReportMrpcsInPartCircleFlow",
        "IsEnableReportMrpcsFlow","IsEnableReportAttackFlow",
        "IsEnableReportHitFlow","IsEnableReportCircleFlow",
      }
      for i = 1, #flags do
        if _G[flags[i]] then _G[flags[i]] = RetFalse end
      end
      gc.GetWeaponReport    = RetEmpty
      gc.GetOneWeaponReport = RetEmpty

      local origStateChanged = gc.OnDSPlayerStateChanged
      gc.OnDSPlayerStateChanged = function(uid, state, bPure, bSafe, param)
        local s = type(state) == "string" and string.lower(state) or ""
        local danger = {
          cheatdetected       = true,
          connectionlost      = true,
          connectiontimeout   = true,
          connectionexception = true,
          netdrivererror      = true,
          banned              = true,
          kicked              = true,
          suspended           = true,
          violationdetected   = true,
          integrityfailure    = true,
          securityviolation   = true,
          reportdetected      = true,
        }
        if danger[s] then return end
        if type(origStateChanged) == "function" then
          return pcall(origStateChanged, uid, state, bPure, bSafe, param)
        end
      end
      gc.OnPlayerNetConnectionClosed = Noop
      gc.OnPlayerActorChannelError   = Noop
      gc.OnPlayerRPCValidateFailed   = Noop
      gc.OnPlayerSpectateException   = Noop
      gc.OnShutdownAfterError        = Noop
      gc.IsBypassed                  = true
    end)
    CP.State.CallbackPatch = true
    print("[ClientPatch] Callbacks patched")
  end

  -- ============================================================
  -- 9. REPORT / BAN / INSPECTOR / SHOT
  -- ============================================================
  function CP.InstallReportPatch()
    if CP.State.ReportPatch then return end
    pcall(function()
      local paths = {
        "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem",
        "Client.Security.ClientReportPlayerSubsystem",
        "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem",
        "GameLua.Mod.BaseMod.Client.Security.DSReportPlayerSubsystem",
      }
      for i = 1, #paths do
        local sub = package.loaded[paths[i]]
        if not sub then
          local ok, m = pcall(require, paths[i])
          if ok and m then sub = m end
        end
        if type(sub) == "table" then SilenceModule(sub) end
      end
      local rpu = SafeReq("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils")
      if rpu then
        rpu.RecordFatalDamager            = Noop
        rpu.RecordFatalDamagerReconnect   = Noop
        rpu.IsUsingHistoricalTeammateInfo = RetFalse
        rpu.IsCharacterDeliverAI          = RetFalse
        rpu.GetBotType                    = RetZero
      end
      local scu = SafeReq("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
      if scu then
        scu.ExtractPlayerBasicInfo = RetEmpty
        scu.LogIf                  = RetFalse
      end
      local qr = SafeReq("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
      if qr then
        qr.OnShowMutualExclusiveUI             = Noop
        qr.OnHideMutualExclusiveUI             = Noop
        qr.MaliciousTeammateReceiveWarningTips = Noop
        qr.MaliciousTeammateVictimReceiveTips  = Noop
      end
    end)
    CP.State.ReportPatch = true
    print("[ClientPatch] Reports patched")
  end
  function CP.InstallBanPatch()
    if CP.State.BanPatch then return end
    pcall(function()
      local bl = package.loaded["client.slua.logic.ban.ClientBanLogic"]
      if type(bl) == "table" then
        bl.OnSyncBanInfo            = Noop
        bl.OnVoiceBanNotify         = Noop
        bl.OnRealTimeVoiceBanNotify = Noop
        bl.OnVoiceBanSuccess        = Noop
        bl.OnSyncMicSuspicious      = Noop
        bl.OnSyncMicPreFilter       = Noop
        bl.OnNotifyWarningTips      = Noop
        bl.ReqBanInfo               = Noop
      end
      local bu = package.loaded["client.common.ban_util"] or _G.ban_util
      if type(bu) == "table" then
        bu.CheckBanStatus = RetFalse
        bu.GetBanTime     = RetZero
        bu.IsBanForever   = RetFalse
        bu.IsBanned       = RetFalse
      end
      local tt = package.loaded["client.logic.login.logic_tt_ban"] or _G.logic_tt_ban
      if type(tt) == "table" then
        tt.CheckIfCanCreateRole = Noop
        tt.GetCarrierInfo       = function() return '[{"mcc":"000"}]' end
        tt.CheckBan             = RetFalse
        tt.GetBanStatus         = RetFalse
      end
      local lb = SafeReq("client.slua.logic.ban.logic_ban")
      if lb then
        lb.GetBanEndTime  = RetZero
        lb.IsInBanTime    = RetFalse
        lb.CheckBanStatus = RetFalse
        lb.GetBanReason   = RetEmpty
        lb.GetBanTime     = RetZero
      end
      local llb = SafeReq("client.slua.logic.login.logic_login_ban")
      if llb then
        llb.CheckCanLogin = RetTrue
        llb.GetBanInfo    = function() return { end_time = 0 } end
        llb.IsBanned      = RetFalse
        llb.IsSecurityBan = RetFalse
      end
      local fb = SafeReq("client.slua.logic.ban.logic_flag_ban")
      if fb then
        fb.GetFlagBanEndTime  = RetZero
        fb.IsFlagBanned       = RetFalse
        fb.GetFlagBanDuration = RetZero
        fb.CheckFlagBan       = RetFalse
      end
      local cf = SafeReq("GameLua.Mod.BaseMod.Client.Security.ClientFlagSubsystem")
      if cf then
        cf.EvaluateFlags      = Noop
        cf.GetFlagLevel       = RetZero
        cf.GetFlagBanDuration = RetZero
        cf.IsFlagged          = RetFalse
        cf.ReportFlag         = Noop
        cf.SyncFlagStatus     = Noop
        cf.IncreaseFlagCount  = Noop
        cf.ResetFlags         = Noop
        cf.FlagCount          = 0
        cf.FlagLevel          = 0
        cf.FlagSeverity       = 0
      end
    end)
    CP.State.BanPatch = true
    print("[ClientPatch] Ban logic patched")
  end

  function CP.InstallInspectorPatch()
    if CP.State.InspectorPatch then return end
    pcall(function()
      local ch = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientHawkEyePatrolSubsystem"]
      if type(ch) == "table" then
        local methods = {
          "_OnHawkSync","_OnHawkReportSuccess","_StartExitGameTimer",
          "_OnRecvInspectorBroadcastCount","SendReportTLog","ReportCheat",
          "_OnHawkFlag","ReportPlayerFlag","RequestFlagPlayer","SendFlagReport",
          "RequestImprison","_InitHawkEyePatrolSubsystem","_CollectBeWatchedPlayerInfo",
          "ServerRPC_HawkReportCheat",
        }
        for i = 1, #methods do
          if ch[methods[i]] then ch[methods[i]] = Noop end
        end
        ch.CanInspectorBroadcast = RetFalse
        ch.IsDuringHawkEyePatrol = RetFalse
      end
      local ic = package.loaded["GameLua.Mod.BaseMod.Client.Security.InspectionSystemReportClientLogicSubsystem"]
      if type(ic) == "table" then
        local methods = {
          "AskForInspector","ReportEnemy","KickOutOneTeam","OnReceiveInspectCmd",
          "ClientReportData","SendReportToInspector","SendKickOutOneTeam",
          "ClientNotifyInspectorImplementation","RecvNotifyInspector",
        }
        for i = 1, #methods do
          if ic[methods[i]] then ic[methods[i]] = Noop end
        end
      end
      local id = package.loaded["GameLua.Mod.BaseMod.DS.Security.InspectionSystemReportDSLogicSubsystem"]
      if type(id) == "table" then
        local methods = {
          "ServerKickOutOneTeamByPlayerImplementation","AddReportedCount",
          "AddInspectionRecord","BanPlayerByInspection","BroadCastToAllInspector",
          "ServerReportToInspectorImplementation","InitPlayerInspectionInfo",
        }
        for i = 1, #methods do
          if id[methods[i]] then id[methods[i]] = Noop end
        end
      end
      local he1 = SafeReq("GameLua.Mod.BaseMod.Client.Security.HawkEyeSpectate.HawkEyeDistanceUI")
      if he1 then he1._RefreshUI = Noop; he1._IsShouldShow = RetFalse end
      local he2 = SafeReq("GameLua.Mod.BaseMod.Client.Security.HawkEyeSpectate.HawkEyeNextPatrolWindow")
      if he2 then he2.OnShow = Noop end
      local he3 = SafeReq("GameLua.Mod.BaseMod.Client.Security.HawkEyeSpectate.HawkEyeReportWindow")
      if he3 then
        he3._OnClickSubmit = Noop
        he3._RefreshWindow = Noop
        he3.RegistEvents   = Noop
      end
    end)
    CP.State.InspectorPatch = true
    print("[ClientPatch] Inspector patched")
  end

  function CP.InstallShotVerifyPatch()
    if CP.State.ShotVerifyPatch then return end
    pcall(function()
      local sv = SafeReq("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
      if sv then
        sv.OnShootVerifyFailed = Noop
        sv.SendVerifyData      = Noop
        sv.ReportBulletHit     = Noop
        sv.UploadHitInfo       = Noop
        sv.VerifyShot          = RetTrue
      end
      if type(_G.BulletHitInfoUploadData) == "table" then
        _G.BulletHitInfoUploadData.Report = Noop
        _G.BulletHitInfoUploadData.Send   = Noop
        _G.BulletHitInfoUploadData.Upload = Noop
      end
    end)
    CP.State.ShotVerifyPatch = true
    print("[ClientPatch] Shot verify patched")
  end

  -- ============================================================
  -- 10. DEVICE / ENV / FORENSICS / SWEEP
  -- ============================================================
  function CP.InstallDevicePatch()
    if CP.State.DevicePatch then return end
    pcall(function()
      local si = SafeImp("SystemInfo")
      if si then
        si.GetDeviceID       = function() return CP.Identity.DeviceId end
        si.GetUniqueDeviceId = function() return CP.Identity.DeviceId end
        si.GetMacAddress     = function() return CP.Identity.MacAddr end
        si.GetAndroidId      = function() return CP.Identity.AndroidId end
        si.GetIMEI           = function() return CP.Identity.Imei end
        si.GetDeviceName     = function() return "Pixel 6" end
        si.GetDeviceModel    = function() return "Pixel 6" end
        si.GetDeviceBrand    = function() return "google" end
        si.GetAndroidVersion = function() return "13" end
        si.IsEmulator        = RetFalse
        si.IsRooted          = RetFalse
        si.IsDebugged        = RetFalse
        si.GetKernelVersion  = function() return CP.Identity.Kernel end
      end
      _G.DeviceID   = CP.Identity.DeviceId
      _G.AndroidID  = CP.Identity.AndroidId
      _G.MacAddress = CP.Identity.MacAddr
      _G.IMEI       = CP.Identity.Imei
    end)
    CP.State.DevicePatch = true
    print("[ClientPatch] Device patched")
  end

  function CP.InstallEnvPatch()
    if CP.State.EnvPatch then return end
    pcall(function()
      local flags = {
        "ENABLE_REPORT","ENABLE_ANTI_CHEAT","ENABLE_SECURITY",
        "ENABLE_TELEMETRY","ENABLE_ANALYTICS","ENABLE_CRASH_REPORT",
        "ENABLE_PERFORMANCE_REPORT",
      }
      for i = 1, #flags do
        if _G[flags[i]] then _G[flags[i]] = false end
      end
    end)
    CP.State.EnvPatch = true
    print("[ClientPatch] Env flags patched")
  end

  function CP.InstallForensicsOff()
    if CP.State.ForensicsOff then return end
    pcall(function()
      if debug and type(debug.getinfo) == "function" then
        local orig = debug.getinfo
        debug.getinfo = function(level, what)
          local ok, info = pcall(orig, level, what)
          if ok and type(info) == "table" and type(info.source) == "string" then
            local src = info.source
            if string.find(src, "ClientPatch", 1, true)
               or string.find(src, "CLIENT_PATCH", 1, true) then
              info.source    = "ProtectedSource"
              info.short_src = "ProtectedSource"
            end
          end
          return info
        end
      end
    end)
    CP.State.ForensicsOff = true
    print("[ClientPatch] Forensics off")
  end

  function CP.InstallSweep()
    if CP.State.SweepDone then return end
    local needles = {
      "verify","integrity","signature","filecheck","file_check",
      "hashcheck","hash_check","tss","security","report",
    }
    local seen = {}
    pcall(function()
      local function watch(m)
        if type(m) ~= "table" or seen[m] then return end
        seen[m] = true
        SilenceModule(m)
      end
      for key, mod in pairs(package.loaded) do
        if type(key) == "string" then
          local low = string.lower(key)
          for i = 1, #needles do
            if string.find(low, needles[i], 1, true) then
              watch(mod)
              break
            end
          end
        end
      end
      for key, mod in pairs(_G) do
        if type(key) == "string" then
          local low = string.lower(key)
          for i = 1, #needles do
            if string.find(low, needles[i], 1, true) then
              watch(mod)
              break
            end
          end
        end
      end
    end)
    CP.State.SweepDone = true
    print("[ClientPatch] Sweep done")
  end

  -- ============================================================
  -- 11. HTTP / IO FILTER
  -- ============================================================
  local HTTP_BLOCKLIST = {
    "tss.tencent","syzsdk","gcloud.qq","reportlog","tdos","logupload","crash2",
    "privacy.qq","privacy.tencent","oth.eve","mdt.qq","act.tencentyun","analytics",
    "report.qq","anticheatexpert","crashsight","wetest","log.tav","sngd","tracer",
    "intlsdk","igamecj","cdn.club","gpubgm","graph.facebook","googleads","doubleclick",
    "firebaselogging","firebaseremoteconfig","fonts.googleapis","abs.twimg","dl.listdl",
    "igame.gcloudcs","bugly","beacon","helpshift","tdm","apm","safeguard","weiyun",
    "qzone","tencent-cloud","myapp","idqqimg","gtimg","qqmail","tcdn","cloudctrl",
    "sdkostrace","mbgame","csoversea","igame","pubgmobile","down.anticheatexpert.com",
    "log.tav.qq","syzsdk.qq","logiservice.qcloud","opensdk.tencent","exp.helpshift",
    "loginsdkapi.zingplay","firebase","googleapis","facebook","gvoice",
  }

  local function IsBlockedUrl(url)
    if type(url) ~= "string" then return false end
    local low = string.lower(url)
    for i = 1, #HTTP_BLOCKLIST do
      if string.find(low, HTTP_BLOCKLIST[i], 1, true) then return true end
    end
    return false
  end

  function CP.InstallHttpFilter()
    if CP.State.HttpFilter then return end
    pcall(function()
      if type(_G.HttpRequest) == "function" then
        local orig = _G.HttpRequest
        _G.HttpRequest = function(url, ...)
          if IsBlockedUrl(url) then return nil end
          return orig(url, ...)
        end
      end
      if _G.FHttpModule and type(_G.FHttpModule.CreateRequest) == "function" then
        local orig = _G.FHttpModule.CreateRequest
        _G.FHttpModule.CreateRequest = function(...)
          local url = select(1, ...)
          if IsBlockedUrl(url) then return nil end
          return orig(...)
        end
      end
      local netMods = {
        "client.slua.logic.network.logic_network",
        "client.slua.logic.download.report.puffer_tlog",
        "client.slua.data.BasicData.BasicDataClientReport",
        "GameLua.GameCore.Module.Network.NetworkManager",
        "client.network.Protocol.ClientTlogHandler",
        "client.network.Protocol.BattleReportHandler",
        "client.network.Protocol.ClientErrorReportHandler",
      }
      for i = 1, #netMods do
        local mod = package.loaded[netMods[i]]
        if type(mod) == "table" then
          for k, v in pairs(mod) do
            if type(v) == "function" and type(k) == "string" then
              if string.find(k, "Http", 1, true)
                 or string.find(k, "Request", 1, true)
                 or string.find(k, "Send", 1, true)
                 or string.find(k, "Upload", 1, true)
                 or string.find(k, "Post", 1, true)
                 or string.find(k, "Report", 1, true) then
                local origf = v
                mod[k] = function(...)
                  local args = {...}
                  for j = 1, #args do
                    if type(args[j]) == "string" and IsBlockedUrl(args[j]) then
                      return nil
                    end
                  end
                  local ok, a, b, c = pcall(origf, ...)
                  if ok then
                    return a, b, c
                  end
                  return nil
                end
              end
            end
          end
        end
      end
    end)
    CP.State.HttpFilter = true
    print("[ClientPatch] HTTP filter installed")
  end
  function CP.InstallIoFilter()
    if CP.State.IoFilter then return end
    pcall(function()
      local kws = {
        "tlog","crash","bugly","report","beacon","wetest","analytics","telemetry",
        "trace","dump","exception","feedback","aps_log","mtp_detect","network_loss",
        "client_error","ue4crash","tdm","gcloud",
      }
      local orig = io.open
      io.open = function(path, mode)
        if type(path) == "string" and type(mode) == "string" then
          local low = string.lower(path)
          local isWrite = (mode == "w" or mode == "a" or mode == "w+" or mode == "a+")
          if isWrite then
            for i = 1, #kws do
              if string.find(low, kws[i], 1, true) then
                return nil, "Blocked"
              end
            end
          end
        end
        return orig(path, mode)
      end
    end)
    CP.State.IoFilter = true
    print("[ClientPatch] IO filter installed")
  end

  -- ============================================================
  -- 12. ACE FILTER
  -- ============================================================
  function CP.InstallAceFilter()
    if CP.State.AceFilter then return end
    pcall(function()
      local blocked = {
        "anti-cheat.tencent.com","game-security.qq.com","tmgp-anti.com",
        "check.tencent.com","down.anticheatexpert.com","anticheatexpert.com",
        "tmgp.qq.com","pubgmobile.com","tencentgames.com","qcloud.com",
        "myqcloud.com","tencentcloudapi.com",
      }
      local function isBlocked(host)
        if type(host) ~= "string" then return false end
        local low = string.lower(host)
        for i = 1, #blocked do
          if string.find(low, blocked[i], 1, true) then return true end
        end
        return false
      end
      local function newFilter(req)
        if type(req) == "table" and req.host and isBlocked(req.host) then
          return { code = 200, body = "" }
        end
        return req
      end
      _G._ACE_new_filter      = newFilter
      _G._ACE_IsBlockedDomain = isBlocked
      pcall(function() _G.filterRequest = newFilter end)
      pcall(function() filterRequest = newFilter end)
    end)
    CP.State.AceFilter = true
    print("[ClientPatch] ACE filter installed")
  end

  -- ============================================================
  -- 13. LEGAL / GOKUBA / GLUE / STATS / BAN UI
  -- ============================================================
  function CP.InstallLegalFilter()
    if CP.State.LegalFilter then return end
    pcall(function()
      local msg = SafeReq("client.slua.logic.common.logic_common_legal_msg")
      if msg and type(msg.ShowOnePopUI) == "function" then
        local orig = msg.ShowOnePopUI
        msg.ShowOnePopUI = function(self, params)
          if type(params) == "table" and params.title then
            local t = string.lower(tostring(params.title))
            if string.find(t, "security", 1, true)
               or string.find(t, "ban", 1, true)
               or string.find(t, "cheat", 1, true) then
              return
            end
          end
          return orig(self, params)
        end
      end
      _G.TryShowLegalCredit = Noop
      if _G.V == nil then _G.V = true end
    end)
    CP.State.LegalFilter = true
    print("[ClientPatch] Legal filter installed")
  end

  function CP.InstallGokubaPatch()
    if CP.State.GokubaPatch then return end
    pcall(function()
      local g = SafeReq("GameLua.Mod.BaseMod.Client.Security.Gokuba")
      if g then
        g.ForwardFeature  = function() return {0, 0, 0, 0, 0} end
        g.InitGokubaLogic = Noop
        if g.TimerHandle then
          pcall(function()
            local tk = SafeReq("common.time_ticker")
            if tk and tk.RemoveTimer then tk.RemoveTimer(g.TimerHandle) end
          end)
          g.TimerHandle = nil
        end
      end
    end)
    CP.State.GokubaPatch = true
    print("[ClientPatch] Gokuba patched")
  end

  function CP.InstallGluePatch()
    if CP.State.GluePatch then return end
    pcall(function()
      local h = SafeReq("GameLua.Mod.BaseMod.Client.Security.ClientGlueHiaSystem")
      if h then
        h.LuaFunc1 = RetTrue
        h.LuaFunc2 = Noop
        h.LuaFunc3 = Noop
        h.LuaFunc4 = RetFalse
        h.LuaFunc5 = RetFalse
        h.LuaFunc6 = RetFalse
        h.LuaFunc7 = RetFalse
        h.LuaFunc8 = RetFalse
        h.LuaFunc9 = Noop
        h.CheckHitIntegrity = Noop
        h.InitSession       = Noop
        h.OnBattleEnd       = Noop
      end
    end)
    CP.State.GluePatch = true
    print("[ClientPatch] Glue patched")
  end

  function CP.InstallStatsPatch()
    if CP.State.StatsPatch then return end
    local ok = pcall(function()
      local mgr = SafeReq("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
      local s = _G.OperationalStatsSubsystem
      if mgr and type(mgr.Get) == "function" then
        local got_ok, got = pcall(mgr.Get, mgr, "OperationalStatsSubsystem")
        if got_ok and got then s = got end
      end
      if type(s) ~= "table" then return end
      s.ReportOperationalStats = Noop
      s.AddOperationalStats   = Noop
      s.HandleTouchBegin      = Noop
      s.HandleTouchEnd        = Noop
      s.OnInit                = Noop
      s.HandleEnterFighting   = Noop
      s.OnBattleResult        = Noop
      if s.TimerHandle and type(s.RemoveGameTimer) == "function" then
        pcall(function() s:RemoveGameTimer(s.TimerHandle) end)
        s.TimerHandle = nil
      end
      s.StatsData = {}
    end)
    if ok then
      CP.State.StatsPatch = true
      print("[ClientPatch] Stats patched")
    else
      CP.State.StatsPatch = false
      print("[ClientPatch] Stats patch FAILED")
    end
  end

  function CP.InstallBanUiPatch()
    if CP.State.BanUiPatch then return end
    pcall(function()
      local uiList = {
        "client.slua.umg.BanNoticeUI",
        "client.slua.umg.KickNoticeUI",
        "GameLua.Mod.BaseMod.Client.UI.BanUI",
      }
      for i = 1, #uiList do
        local mod = package.loaded[uiList[i]]
        if not mod then
          local ok, loaded = pcall(require, uiList[i])
          if ok and loaded then mod = loaded end
        end
        if type(mod) == "table" then
          for k, v in pairs(mod) do
            if type(v) == "function" and type(k) == "string"
               and string.find(k, "Show", 1, true) then
              pcall(function() mod[k] = Noop end)
            end
          end
        end
      end
      _G.ShowBanNotice    = Noop
      _G.ShowKickNotice   = Noop
      _G.ProcessBanNotice = Noop
      _G.HandleBanNotice  = Noop
      _G.ShowBanUI        = Noop
      _G.ShowKickUI       = Noop
    end)
    CP.State.BanUiPatch = true
    print("[ClientPatch] Ban UI patched")
  end

  function CP.InstallHum()
    if CP.State.HumApplied then return end
    _G.TX_HB  = math.random(15, 45)
    _G.TX_JIT = math.random(-12, 18)
    _G.TX_KD  = 0.9 + math.random() * 1.9
    _G.TX_HD  = 9 + math.random() * 22
    CP.State.HumApplied = true
  end

  -- ============================================================
  -- 14. SUB-PATCHES
  -- ============================================================
  function CP.SubPatchDeadEye()
    if CP.State.DEADEYE_DISABLED then return end
    pcall(function()
      if type(_G.GameplayCallbacks) == "table" then
        local list = {"ReportAimFlow","ReportHitFlow","ReportAttackFlow",
                      "OnAimDetected","OnHeadshotDetected","OnPerfectAccuracy"}
        for i = 1, #list do
          if _G.GameplayCallbacks[list[i]] then
            _G.GameplayCallbacks[list[i]] = Noop
          end
        end
      end
      local mgr = SafeReq("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
      if mgr and type(mgr.Get) == "function" then
        local ok, s = pcall(mgr.Get, mgr, "ClientAimTrackingSubsystem")
        if ok and s then
          s.GetAimData = function()
            return {
              accuracy     = math.random(45, 65),
              headshotRate = math.random(15, 35),
            }
          end
          s.IsAimNormal = RetTrue
        end
      end
    end)
    CP.State.DEADEYE_DISABLED = true
  end

  function CP.SubPatchVoklai()
    if CP.State.VOKLAI_DISABLED then return end
    pcall(function()
      local mgr = SafeReq("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
      if not (mgr and type(mgr.Get) == "function") then return end
      local ok, ai = pcall(mgr.Get, mgr, "ClientAIBehaviourSubsystem")
      if ok and ai then
        ai.GetBehaviorScore = function() return math.random(10, 30) end
        ai.IsSuspicious     = RetFalse
        ai.GetRiskLevel     = RetZero
      end
      local ok2, sc = pcall(mgr.Get, mgr, "ClientStepCheckSubsystem")
      if ok2 and sc then
        sc.GetStepDelta    = function() return math.random(5, 50) end
        sc.IsMovementValid = RetTrue
      end
      local ok3, sp = pcall(mgr.Get, mgr, "AntiSpeedHackSubsystem")
      if not (ok3 and sp) then
        ok3, sp = pcall(mgr.Get, mgr, "ClientAntiSpeedHackSubsystem")
      end
      if ok3 and sp then
        sp.GetSpeed     = function() return math.random(300, 600) end
        sp.IsSpeedValid = RetTrue
      end
    end)
    CP.State.VOKLAI_DISABLED = true
  end

  function CP.SubPatchEduEye()
    if CP.State.EDU_EYE_DISABLED then return end
    pcall(function()
      local mgr = SafeReq("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
      if not (mgr and type(mgr.Get) == "function") then return end
      local ok, r = pcall(mgr.Get, mgr, "ClientRenderCheckSubsystem")
      if ok and r then
        r.IsRenderClean  = RetTrue
        r.GetRenderState = function() return "normal" end
      end
      local ok2, e = pcall(mgr.Get, mgr, "ClientESPDetectionSubsystem")
      if ok2 and e then
        e.HasESP       = RetFalse
        e.CheckOverlay = function() return "clean" end
      end
      local ok3, w = pcall(mgr.Get, mgr, "ClientWallhackDetectionSubsystem")
      if ok3 and w then
        w.IsVisionNormal    = RetTrue
        w.GetVisibilityRate = function() return math.random(60, 85) end
      end
    end)
    CP.State.EDU_EYE_DISABLED = true
  end

  function CP.SubPatchMemory()
    if CP.State.MEMORY_PATCH_DISABLED then return end
    pcall(function()
      local mgr = SafeReq("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
      if mgr and type(mgr.Get) == "function" then
        local ok, k = pcall(mgr.Get, mgr, "ClientKernelCheckSubsystem")
        if ok and k then
          k.IsKernelClean      = RetTrue
          k.GetKernelVersion   = function() return "4.19.150-generic" end
          k.IsBootloaderLocked = RetTrue
        end
        local ok2, m = pcall(mgr.Get, mgr, "ClientMemoryGuardSubsystem")
        if ok2 and m then
          m.IsMemoryClean = function() return true, { code = 0 } end
          m.ScanResult    = function() return "clean" end
        end
      end
      if _G.TssSdk then
        _G.TssSdk.CheckKernel = function() return true, {status = "verified", tampered = false} end
        _G.TssSdk.VerifyBoot  = function() return true, {locked = true, verified = true} end
      end
    end)
    CP.State.MEMORY_PATCH_DISABLED = true
  end

  function CP.SubPatchIpMap()
    if CP.State.IP_MAPPING_DISABLED then return end
    pcall(function()
      if type(_G.GameplayCallbacks) == "table" then
        local list = {"SendClientDeviceInfo","ReportDeviceFingerprint","SendNetworkInfo",
                      "ReportIPAddress","SendMACAddress","ReportHardwareID"}
        for i = 1, #list do
          if _G.GameplayCallbacks[list[i]] then
            _G.GameplayCallbacks[list[i]] = Noop
          end
        end
      end
      local mgr = SafeReq("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
      if mgr and type(mgr.Get) == "function" then
        local ok, d = pcall(mgr.Get, mgr, "ClientDeviceInfoSubsystem")
        if ok and d then
          d.GetDeviceID   = function() return CP.Identity.DeviceId end
          d.GetIPAddress  = function() return CP.Identity.IpAddr end
          d.GetMACAddress = function() return CP.Identity.MacAddr end
        end
      end
    end)
    CP.State.IP_MAPPING_DISABLED = true
  end

  function CP.SubPatchHash()
    if CP.State.HASH_VERIFY_DISABLED then return end
    pcall(function()
      if _G.TssSdk then
        _G.TssSdk.ScanMemory     = function() return true, {code = 0, msg = "clean"} end
        _G.TssSdk.ScanSo         = function() return true, {code = 0, msg = "clean"} end
        _G.TssSdk.ScanFile       = function() return true, {code = 0} end
        _G.TssSdk.GetRiskFlag    = RetZero
        _G.TssSdk.VerifyFileHash = RetTrue
      end
      local mgr = SafeReq("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
      if mgr and type(mgr.Get) == "function" then
        local ok, i = pcall(mgr.Get, mgr, "ClientIntegrityCheckSubsystem")
        if ok and i then
          i.CheckFileHash = Noop
          i.VerifyMemory  = Noop
          i.ScanModules   = Noop
        end
      end
    end)
    CP.State.HASH_VERIFY_DISABLED = true
  end
  -- ============================================================
  -- 15. WATCHDOG / LOOP / EVENT
  -- ============================================================
  CP._LoopTimer     = nil
  CP._WatchdogTimer = nil

  function CP.InstallMatchGuard()
    if CP.State.MatchGuard then return end
    pcall(function()
      local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
      _G._CP_MATCH_PC = pc
    end)
    CP.State.MatchGuard = true
  end

  function CP.StartProtectionLoop()
    if CP.State.LoopStarted then return end
    CP.State.LoopStarted = true
    pcall(function()
      local tk = SafeReq("common.time_ticker")
      if not tk or type(tk.AddTimerOnce) ~= "function" then return end
      local function loop()
        pcall(function()
          CP.InstallPacketFilter()
          CP.InstallHiggsPatch()
          CP.InstallCallbackPatch()
          CP.InstallSubsystemPatch()
          CP.InstallAceFilter()
        end)
        local ok, id = pcall(tk.AddTimerOnce, 5.0, loop)
        if ok then CP._LoopTimer = id end
      end
      local ok, id = pcall(tk.AddTimerOnce, 5.0, loop)
      if ok then CP._LoopTimer = id end
    end)
  end

  function CP.StartWatchdog()
    if CP.State.WatchdogOn then return end
    CP.State.WatchdogOn = true
    pcall(function()
      local tk = SafeReq("common.time_ticker")
      if not tk or type(tk.AddTimerOnce) ~= "function" then return end
      local function loop()
        pcall(function()
          if not CP.State.PacketFilter then CP.InstallPacketFilter() end
          CP.InstallHiggsPatch()
          CP.InstallCallbackPatch()
          CP.InstallSubsystemPatch()
        end)
        local ok, id = pcall(tk.AddTimerOnce, 5.0, loop)
        if ok then CP._WatchdogTimer = id end
      end
      local ok, id = pcall(tk.AddTimerOnce, 5.0, loop)
      if ok then CP._WatchdogTimer = id end
    end)
  end

  function CP.InstallEventHooks()
    pcall(function()
      if EventSystem and type(EventSystem.registEvent) == "function" then
        if EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
          EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
            pcall(CP.Apply)
          end)
        end
      end
    end)
  end

  -- ============================================================
  -- 16. MASTER APPLY
  -- ============================================================
  function CP.Apply()
    CP.InstallPacketFilter()
    CP.InstallSluaPatch()
    CP.InstallTssPatch()
    CP.InstallLogPatch()
    CP.InstallSkinPatch()
    CP.InstallHiggsPatch()
    CP.InstallSubsystemPatch()
    CP.InstallCallbackPatch()
    CP.InstallReportPatch()
    CP.InstallBanPatch()
    CP.InstallInspectorPatch()
    CP.InstallShotVerifyPatch()
    CP.InstallDevicePatch()
    CP.InstallEnvPatch()
    CP.InstallForensicsOff()
    CP.InstallSweep()
    CP.InstallHttpFilter()
    CP.InstallIoFilter()
    CP.InstallAceFilter()
    CP.InstallLegalFilter()
    CP.InstallGokubaPatch()
    CP.InstallGluePatch()
    CP.InstallStatsPatch()
    CP.InstallBanUiPatch()
    CP.InstallHum()
    CP.SubPatchDeadEye()
    CP.SubPatchVoklai()
    CP.SubPatchEduEye()
    CP.SubPatchMemory()
    CP.SubPatchIpMap()
    CP.SubPatchHash()
    CP.InstallMatchGuard()
    CP.StartProtectionLoop()
    CP.StartWatchdog()
    CP.InstallEventHooks()
    CP.State.Active = true
  end

  -- ============================================================
  -- PUBLIC API
  -- ============================================================
  _G.ClientPatchApply  = CP.Apply
  _G.ClientPatchStatus = function()
    return CP.State
  end

  -- ============================================================
  -- BOOT
  -- ============================================================
  pcall(function()
    print("[ClientPatch] Booting...")
    CP.Apply()
    print("[ClientPatch] ACTIVE")
  end)

  return CP
end  -- END _partC_rapzhang5

-- ============================================================================
-- PART D: rapzhang9 — SKUY_PACKET_BLOCKER
-- ============================================================================
local function _partD_rapzhang9()
  local _RAPZHANGVIP_KEY = "rapzhangvip"

  local M = {}
  M.Installed = false
  M.BlockedCount = 0
  M.SanitizedCount = 0
  M._retryCount = 0

  local _unpack = table.unpack or unpack

  local function _genFakeHWID()
    if _G.MXP_HWIDString and #_G.MXP_HWIDString >= 16 then
      return _G.MXP_HWIDString:sub(1, 32)
    end
    local seed = tostring(os.time()) .. tostring(os.clock() * 1e7) .. tostring(math.random(1, 1e9))
    local state = 7
    for i = 1, #seed do state = (state * 31 + seed:byte(i)) % 2147483647 end
    local chars = "0123456789abcdef"
    local h = ""
    for i = 1, 32 do
      state = (state * 1103515245 + 12345) % 2147483647
      h = h .. chars:sub((state % 16) + 1, (state % 16) + 1)
    end
    _G.MXP_HWIDString = h
    return h
  end
  local FAKE_HWID = _genFakeHWID()

  local HardBlock = {
    report_shot_check_exception = true, log_shooting_miss = true,
    ds_err_report = true, ds_ugclua_err_report = true,
    report_unrealnet_exception = true, report_memory_exception = true,
    report_avatar_exception = true, report_ui_state = true,
    report_hit_reg_fail = true, report_character_state = true,
    report_vehicle_exception = true, report_camera_exception = true,
    report_character_all_drag = true, report_parachute_all_drag = true,
    report_vehicle_move_drag = true, report_highlight_flow = true,
    report_aim_flow_exception = true, report_movement_anomaly = true,
    client_upload_bullet_fly_speed = true,
    tss_sdk_report = true, report_client_scan_result = true,
    report_security_alert = true, report_violation = true,
    client_trace = true, client_pak_report = true,
    suspicious_flag_req = true, get_ban_id_req = true,
    begin_hawkeye_inspect_req = true, ReportHawkeyeBanFlow = true,
    get_goslar_ban_info_req = true, goslar_ban_confirm_req = true,
    goslar_ban_draw_req = true, fair_play_agreement_req = true,
    cheat_warn_reply = true, report_client_timeout_report_req = true,
    battle_client_sync_allstar_auth_check_result_req = true,
    on_crow_update_ntf = true, on_crow_update_ntf2 = true,
    on_crow_update_ntf3 = true, on_crow_update_ntf4 = true,
    on_crow_update_ntf5 = true,
    send_ugc_report_uni_mod_expose_req = true,
    send_ugc_report_uni_mod_interactive_req = true,
    ReportAimFlow = true, ReportAttackFlow = true, ReportSecAttackFlow = true,
    ReportHurtFlow = true, ReportPlayerBehavior = true,
    ReportPlayerMoveRoute = true, ReportPlayerPosition = true,
    ReportEquipmentFlow = true, ReportVehicleMoveFlow = true,
    ReportSecTgameMovingFlow = true, ReportFireArms = true,
    ReportVerifyInfoFlow = true, ReportAIStrategyInfo = true,
    ReportMisKillByTeammate = true, ReportTeammatHurt = true,
    ReportDSHawkEyePatrolLog = true,
    report_aim_flow = true, report_attack_flow = true,
    report_sec_attack_flow = true, report_hurt_flow = true,
    report_player_behavior = true, report_player_move_route = true,
    report_player_position = true, report_equipment_flow = true,
    report_vehicle_move_flow = true, report_sec_tgame_moving_flow = true,
    report_fire_arms = true, report_verify_info_flow = true,
    report_ai_strategy_info = true, report_mis_kill_by_teammate = true,
    report_teammat_hurt = true, report_ds_hawkeye_patrol_log = true,
    warn_suspicious_player_req = true, player_report_cheat = true,
    report_suspicious_player = true, rtanti_data_upload = true,
    report_anticheat_data = true,
  }

  local DSBlock = {
    inspection_system_report_to_inspector = true,
    inspection_system_kick_out_one_team = true,
    req_ingame_ban_info = true, ds_security_report = true,
    ds_ban_player = true, ds_cheat_detected = true,
    ds_hawkeye_report = true, ds_anti_cheat_data = true,
    ds_punish_player = true, ds_suspicious_flag = true,
    player_cheat_state_sync = true, ds_security_notify = true,
    hawkeye_spectate_log = true, ds_replay_evidence = true,
  }

  local BlockedMsgIds = {
    [242463958] = true, [446448067] = true, [1149962314] = true,
    [1345216445] = true, [1637274787] = true,
  }

  local function Sanitize_TssAntiData(Args)
    Args[2] = "TSS_SECURE_PAYLOAD_VERIFIED_OK"
    Args[3] = #Args[2]
    if type(Args[5]) == "table" then
      Args[5].ErrorCode = 0
      Args[5].ReportLog = 0
      Args[5].SuspicionLevel = 0
    end
    return Args
  end

  local function Sanitize_Hisar(Args)
    if type(Args[3]) == "string" then Args[3] = FAKE_HWID end
    if type(Args[4]) == "string" then Args[4] = FAKE_HWID end
    if type(Args[5]) == "table" then
      for k, v in pairs(Args[5]) do
        if type(v) == "number" then Args[5][k] = 0 end
      end
    end
    return Args
  end

  local function _log(tag, msg)
    pcall(function()
      if _G.LOG and type(_G.LOG.state) == "function" then
        _G.LOG.state("PB." .. tag, msg, "")
      end
    end)
  end

  local function _pcall(fn, ...)
    local ok, err = pcall(fn, ...)
    return ok, err
  end

  local function Hook_NetUtilSendPacket()
    _pcall(function()
      if not (NetUtil and NetUtil.SendPacket) then return end
      if NetUtil._SKUY_PB_SendPacket then return end
      NetUtil._SKUY_PB_SendPacket = true
      local raw = NetUtil.SendPacket
      NetUtil.SendPacket = function(PacketName, ...)
        if type(PacketName) ~= "string" then return raw(PacketName, ...) end
        if _G.SKUY_EquipSuppress then return nil end
        if HardBlock[PacketName] then
          M.BlockedCount = M.BlockedCount + 1
          _log("Blocked", PacketName)
          return nil
        end
        if PacketName:lower():match("^on_crow_update_ntf") then
          M.BlockedCount = M.BlockedCount + 1
          _log("Blocked", PacketName)
          return nil
        end
        if PacketName == "on_tss_sdk_anti_data" then
          local Args = Sanitize_TssAntiData({...})
          M.SanitizedCount = M.SanitizedCount + 1
          _log("Sanitized", "on_tss_sdk_anti_data")
          return raw(PacketName, _unpack(Args))
        end
        return raw(PacketName, ...)
      end
    end)
  end

  local function Hook_NetUtilSendPkg()
    _pcall(function()
      if not (NetUtil and NetUtil.SendPkg) then return end
      if NetUtil._SKUY_PB_SendPkg then return end
      NetUtil._SKUY_PB_SendPkg = true
      local raw = NetUtil.SendPkg
      NetUtil.SendPkg = function(MsgName, ...)
        if type(MsgName) ~= "string" then return raw(MsgName, ...) end
        if _G.SKUY_EquipSuppress then return nil end
        if HardBlock[MsgName] then
          M.BlockedCount = M.BlockedCount + 1
          _log("Blocked", MsgName)
          return nil
        end
        if MsgName == "hisar" then
          local Args = Sanitize_Hisar({...})
          M.SanitizedCount = M.SanitizedCount + 1
          _log("Sanitized", "hisar")
          return raw(MsgName, _unpack(Args))
        end
        return raw(MsgName, ...)
      end
    end)
  end

  local function Hook_NetManagerSendPkg()
    _pcall(function()
      local NM = rawget(_G, "NetManager")
      if not (NM and type(NM.SendPkg) == "function") then return end
      if NM._SKUY_PB_NMSendPkg then return end
      NM._SKUY_PB_NMSendPkg = true
      local raw = NM.SendPkg
      NM.SendPkg = function(id, ...)
        if _G.SKUY_EquipSuppress then return nil end
        local t = type(id)
        if t == "number" then
          if BlockedMsgIds[id] then
            M.BlockedCount = M.BlockedCount + 1
            _log("BlockedMsgId", tostring(id))
            return nil
          end
          local reqName = nil
          pcall(function()
            local NC = require("client.network.comm.NetConfig")
            local info = NC and NC.msgMap and NC.msgMap[id]
            reqName = info and info.req
          end)
          if type(reqName) == "string" and HardBlock[reqName] then
            M.BlockedCount = M.BlockedCount + 1
            _log("Blocked", reqName)
            return nil
          end
        elseif t == "string" and HardBlock[id] then
          M.BlockedCount = M.BlockedCount + 1
          _log("Blocked", id)
          return nil
        end
        return raw(id, ...)
      end
    end)
  end
  local function Hook_DSNet()
    _pcall(function()
      local ds_net = package.loaded["ds_net"] or rawget(_G, "ds_net")
      if type(ds_net) ~= "table" then return end
      if ds_net._SKUY_PB_Trapped then return end
      ds_net._SKUY_PB_Trapped = true
      for _, fnName in ipairs({"SendMessage", "SendMsgToDS"}) do
        if type(ds_net[fnName]) == "function" then
          local rawSend = ds_net[fnName]
          ds_net[fnName] = function(msgName, ...)
            if _G.SKUY_EquipSuppress then return end
            if type(msgName) == "string" and DSBlock[msgName] then
              M.BlockedCount = M.BlockedCount + 1
              _log("DSBlocked", msgName)
              return
            end
            return rawSend(msgName, ...)
          end
        end
      end
    end)
  end

  local function _tryInstall()
    if M.Installed then return true end
    local hasAny = false
    if NetUtil and NetUtil.SendPacket then Hook_NetUtilSendPacket(); hasAny = true end
    if NetUtil and NetUtil.SendPkg then Hook_NetUtilSendPkg(); hasAny = true end
    if rawget(_G, "NetManager") then Hook_NetManagerSendPkg(); hasAny = true end
    if package.loaded["ds_net"] or rawget(_G, "ds_net") then Hook_DSNet(); hasAny = true end
    if hasAny then
      M.Installed = true
      _log("Installed", "SKUY_PACKET_BLOCKER v2.0 UNIVERSAL")
    end
    return M.Installed
  end

  function M.Install()
    if M.Installed then return true end
    _tryInstall()
    if not M.Installed and M._retryCount < 20 then
      M._retryCount = M._retryCount + 1
      _pcall(function()
        local ok, ticker = pcall(require, "common.time_ticker")
        if ok and ticker and type(ticker.AddTimerOnce) == "function" then
          ticker.AddTimerOnce(2, M.Install)
        else
          if _G.SLuaTicker and type(_G.SLuaTicker.AddTimer) == "function" then
            _G.SLuaTicker.AddTimer(2, M.Install)
          end
        end
      end)
    end
    return M.Installed
  end

  function M.Stats()
    local hb, db, mi = 0, 0, 0
    for _ in pairs(HardBlock) do hb = hb + 1 end
    for _ in pairs(DSBlock) do db = db + 1 end
    for _ in pairs(BlockedMsgIds) do mi = mi + 1 end
    return {
      version = "2.0 UNIVERSAL",
      installed = M.Installed,
      blocked = M.BlockedCount,
      sanitized = M.SanitizedCount,
      hardblock_count = hb,
      dsblock_count = db,
      msgid_count = mi,
      retry_count = M._retryCount,
    }
  end

  _G.SKUY_PB = M
  _G.SKUY_PACKET_BLOCKER = M

  if not _G.SKUY_PB_NO_AUTO then
    M.Install()
  end

  return M
end  -- END _partD_rapzhang9

-- ============================================================================
-- PART E: rapzhang10 — DisableKillReport
-- ============================================================================
local function _partE_rapzhang10()
  local _RAPZHANGVIP_KEY = "rapzhangvip"

  local DisableKillReport = {}

  local function _safePatch(target, key, newFn, tag)
    if type(target) ~= "table" then
      print("[DisableKillReport] skip " .. tostring(tag) .. " (target not table)")
      return false
    end
    if type(target[key]) ~= "function" then
      print("[DisableKillReport] skip " .. tostring(tag) .. " (method not function)")
      return false
    end
    target[key] = newFn
    print("[DisableKillReport] patched " .. tostring(tag))
    return true
  end

  local function _safePatchNested(target, key, nestedKey, newFn, tag)
    if type(target) ~= "table" or type(target[key]) ~= "table" then
      print("[DisableKillReport] skip " .. tostring(tag) .. " (nested target missing)")
      return false
    end
    return _safePatch(target[key], nestedKey, newFn, tag)
  end

  local function _PatchGameplayCallbacks()
    local GC = rawget(_G, "GameplayCallbacks")
    if type(GC) ~= "table" then
      print("[DisableKillReport] GameplayCallbacks not loaded yet, will retry later")
      return false
    end

    _safePatch(GC, "SendDataMiningTLog", function(sProtocol, TLogData, ...)
      print("[DisableKillReport] blocked SendDataMiningTLog protocol=" .. tostring(sProtocol))
    end, "GameplayCallbacks.SendDataMiningTLog")

    _safePatch(GC, "SendSecTLog", function(sProtocol, TLogData, ...)
      print("[DisableKillReport] blocked SendSecTLog protocol=" .. tostring(sProtocol))
    end, "GameplayCallbacks.SendSecTLog")

    _safePatch(GC, "ReportAttackFlow", function()
      print("[DisableKillReport] blocked ReportAttackFlow")
    end, "GameplayCallbacks.ReportAttackFlow")

    _safePatch(GC, "ReportSecAttackFlow", function()
      print("[DisableKillReport] blocked ReportSecAttackFlow")
    end, "GameplayCallbacks.ReportSecAttackFlow")

    _safePatch(GC, "ReportHurtFlow", function()
      print("[DisableKillReport] blocked ReportHurtFlow")
    end, "GameplayCallbacks.ReportHurtFlow")

    _safePatch(GC, "ReportFireArms", function()
      print("[DisableKillReport] blocked ReportFireArms")
    end, "GameplayCallbacks.ReportFireArms")

    _safePatch(GC, "ReportMisKillByTeammate", function()
      print("[DisableKillReport] blocked ReportMisKillByTeammate")
    end, "GameplayCallbacks.ReportMisKillByTeammate")

    _safePatch(GC, "ReportMrpcsFlow", function()
      print("[DisableKillReport] blocked ReportMrpcsFlow")
    end, "GameplayCallbacks.ReportMrpcsFlow")

    _safePatch(GC, "ReportPlayerBehavior", function()
      print("[DisableKillReport] blocked ReportPlayerBehavior")
    end, "GameplayCallbacks.ReportPlayerBehavior")

    _safePatch(GC, "ReportVehicleMoveFlow", function()
      print("[DisableKillReport] blocked ReportVehicleMoveFlow")
    end, "GameplayCallbacks.ReportVehicleMoveFlow")

    return true
  end

  local function _PatchWeaponRecordSubSystem()
    local WRS = nil
    if type(SubsystemMgr) == "table" and type(SubsystemMgr.Get) == "function" then
      local ok, sys = pcall(SubsystemMgr.Get, SubsystemMgr, "WeaponRecordSubSystem")
      if ok and type(sys) == "table" then WRS = sys end
    end
    if not WRS then
      local ok, cls = pcall(require, "GameLua.Mod.BaseMod.DS.Subsystem.WeaponRecordSubSystem")
      if ok and type(cls) == "table" then WRS = cls end
    end
    if type(WRS) ~= "table" then
      print("[DisableKillReport] WeaponRecordSubSystem not available, skip")
      return false
    end

    _safePatch(WRS, "OnHandleKill", function(self, _, _, attackerId, weaponId, isAI)
      print("[DisableKillReport] blocked WeaponRecordSubSystem:OnHandleKill weaponId=" .. tostring(weaponId))
    end, "WeaponRecordSubSystem.OnHandleKill")

    local _origOnOtherHit = WRS.OnOtherHit
    if type(_origOnOtherHit) == "function" then
      WRS.OnOtherHit = function(self, _, _, attackerId, weaponId, aimType, distance, damage, isKill, bFallOnGround, States, HitPos, VictimType, IsAddHitFlow, shootID, VictimPlayerKey)
        return _origOnOtherHit(self, nil, nil, attackerId, weaponId, aimType, distance, damage, 0, bFallOnGround, States, HitPos, VictimType, false, shootID, VictimPlayerKey)
      end
      print("[DisableKillReport] patched WeaponRecordSubSystem.OnOtherHit (isKill forced 0)")
    end

    _safePatch(WRS, "OnHit", function() end, "WeaponRecordSubSystem.OnHit")
    _safePatch(WRS, "OnHitMonster", function() end, "WeaponRecordSubSystem.OnHitMonster")
    _safePatch(WRS, "OnOtherHitMonster", function() end, "WeaponRecordSubSystem.OnOtherHitMonster")

    _safePatch(WRS, "HandleCharacterKillForWeaponCapability", function()
      print("[DisableKillReport] blocked WeaponRecordSubSystem:HandleCharacterKillForWeaponCapability")
    end, "WeaponRecordSubSystem.HandleCharacterKillForWeaponCapability")

    _safePatch(WRS, "HandleDamageForWeaponCapability", function()
    end, "WeaponRecordSubSystem.HandleDamageForWeaponCapability")

    _safePatch(WRS, "RetrieveWeaponRecord", function(self)
      print("[DisableKillReport] blocked WeaponRecordSubSystem:RetrieveWeaponRecord")
      return {BattleId = "0", BattleMode = 0, TotalWeaponRecord = {}}
    end, "WeaponRecordSubSystem.RetrieveWeaponRecord")

    _safePatch(WRS, "RetrieveOneWeaponRecord", function(self, PlayerKey)
      print("[DisableKillReport] blocked WeaponRecordSubSystem:RetrieveOneWeaponRecord PlayerKey=" .. tostring(PlayerKey))
      return {}
    end, "WeaponRecordSubSystem.RetrieveOneWeaponRecord")

    return true
  end

  local function _PatchWeaponKillCounterFeature()
    local ok, cls = pcall(require, "GameLua.Activity.Commercialize.GamePlay.WeaponKillCounter.WeaponKillCounterFeature")
    if not ok or type(cls) ~= "table" then
      print("[DisableKillReport] WeaponKillCounterFeature class not found, skip")
      return false
    end

    _safePatch(cls, "SetCurChangedKillCounterInfo", function(self, weaponId, killNum)
      print("[DisableKillReport] blocked WeaponKillCounterFeature:SetCurChangedKillCounterInfo")
    end, "WeaponKillCounterFeature.SetCurChangedKillCounterInfo")

    _safePatch(cls, "RPC_Server_GetCurBattleWeaponKillInfo", function()
      print("[DisableKillReport] blocked WeaponKillCounterFeature:RPC_Server_GetCurBattleWeaponKillInfo")
    end, "WeaponKillCounterFeature.RPC_Server_GetCurBattleWeaponKillInfo")

    _safePatch(cls, "RPC_Client_UpdateCurBattleWeaponKillInfo", function()
      print("[DisableKillReport] blocked WeaponKillCounterFeature:RPC_Client_UpdateCurBattleWeaponKillInfo")
    end, "WeaponKillCounterFeature.RPC_Client_UpdateCurBattleWeaponKillInfo")

    _safePatch(cls, "OnRep_ChangedKillCounterInfo", function()
      print("[DisableKillReport] blocked WeaponKillCounterFeature:OnRep_ChangedKillCounterInfo")
    end, "WeaponKillCounterFeature.OnRep_ChangedKillCounterInfo")

    return true
  end

  local function _PatchDSKillAndKnockDownTLogSubsystem()
    local sys = nil
    if type(SubsystemMgr) == "table" and type(SubsystemMgr.Get) == "function" then
      local ok, s = pcall(SubsystemMgr.Get, SubsystemMgr, "DSKillAndKnockDownTLogSubsystem")
      if ok and type(s) == "table" then sys = s end
    end
    if not sys then
      local ok, cls = pcall(require, "GameLua.Mod.BaseMod.DS.Subsystem.DSKillAndKnockDownTLogSubsystem")
      if ok and type(cls) == "table" then sys = cls end
    end
    if type(sys) ~= "table" then
      print("[DisableKillReport] DSKillAndKnockDownTLogSubsystem not available, skip")
      return false
    end

    _safePatch(sys, "OnHandleNearDeath", function()
      print("[DisableKillReport] blocked DSKillAndKnockDownTLogSubsystem:OnHandleNearDeath")
    end, "DSKillAndKnockDownTLogSubsystem.OnHandleNearDeath")

    _safePatch(sys, "OnCharacterDied", function()
      print("[DisableKillReport] blocked DSKillAndKnockDownTLogSubsystem:OnCharacterDied")
    end, "DSKillAndKnockDownTLogSubsystem.OnCharacterDied")

    _safePatch(sys, "OnCharacterDiedPre", function()
      print("[DisableKillReport] blocked DSKillAndKnockDownTLogSubsystem:OnCharacterDiedPre")
    end, "DSKillAndKnockDownTLogSubsystem.OnCharacterDiedPre")

    _safePatch(sys, "TrySendToAIProxy", function()
      print("[DisableKillReport] blocked DSKillAndKnockDownTLogSubsystem:TrySendToAIProxy")
    end, "DSKillAndKnockDownTLogSubsystem.TrySendToAIProxy")

    _safePatch(sys, "RecordAllFlowData", function()
    end, "DSKillAndKnockDownTLogSubsystem.RecordAllFlowData")

    _safePatch(sys, "SetFlowData", function()
      return {}
    end, "DSKillAndKnockDownTLogSubsystem.SetFlowData")

    return true
  end

  local function _PatchGameModeBase()
    local ok, cls = pcall(require, "GameLua.Mod.BaseMod.DS.GameMode.GameModeBase")
    if not ok or type(cls) ~= "table" then
      print("[DisableKillReport] GameModeBase class not found, skip")
      return false
    end

    _safePatch(cls, "HandleOnCharacterKill", function(self)
      print("[DisableKillReport] blocked GameModeBase:HandleOnCharacterKill")
    end, "GameModeBase.HandleOnCharacterKill")

    _safePatch(cls, "HandleOnCharacterKnockOut", function(self)
      print("[DisableKillReport] blocked GameModeBase:HandleOnCharacterKnockOut")
    end, "GameModeBase.HandleOnCharacterKnockOut")

    return true
  end

  local function _PatchFatalDamageSubsystem()
    local sys = nil
    if type(SubsystemMgr) == "table" and type(SubsystemMgr.Get) == "function" then
      local ok, s = pcall(SubsystemMgr.Get, SubsystemMgr, "FatalDamageSubsystem")
      if ok and type(s) == "table" then sys = s end
    end
    if not sys then
      print("[DisableKillReport] FatalDamageSubsystem not available, skip")
      return false
    end

    _safePatch(sys, "BroadcastFatalDamageInfoWrapperSimpleLua", function()
      print("[DisableKillReport] blocked FatalDamageSubsystem:BroadcastFatalDamageInfoWrapperSimpleLua")
    end, "FatalDamageSubsystem.BroadcastFatalDamageInfoWrapperSimpleLua")

    _safePatch(sys, "BroadcastFatalDamageInfoWrapperLua", function()
      print("[DisableKillReport] blocked FatalDamageSubsystem:BroadcastFatalDamageInfoWrapperLua")
    end, "FatalDamageSubsystem.BroadcastFatalDamageInfoWrapperLua")

    _safePatch(sys, "AddPlayerKillerFlow", function()
      print("[DisableKillReport] blocked FatalDamageSubsystem:AddPlayerKillerFlow")
    end, "FatalDamageSubsystem.AddPlayerKillerFlow")

    return true
  end
  local function _PatchSendGameOver()
    local GC = rawget(_G, "GameplayCallbacks")
    if type(GC) ~= "table" or type(GC.SendGameOver) ~= "function" then
      print("[DisableKillReport] SendGameOver not found, skip")
      return false
    end

    GC.SendGameOver = function(Reason)
      print("[DisableKillReport] blocked GameplayCallbacks:SendGameOver Reason=" .. tostring(Reason))
    end
    print("[DisableKillReport] patched GameplayCallbacks.SendGameOver")

    return true
  end

  local function _PatchNetUtilSendPacket()
    local NU = rawget(_G, "NetUtil")
    if type(NU) ~= "table" or type(NU.SendPacket) ~= "function" then
      print("[DisableKillReport] NetUtil.SendPacket not available, skip")
      return false
    end

    local _origSendPacket = NU.SendPacket
    local _blockedProtocols = {
      ["report_kill_and_knockdown_flow"] = true,
      ["ReportHitFlow"] = true,
      ["ReportFireArms"] = true,
      ["ReportSecAttackFlow"] = true,
      ["ReportAttackFlow"] = true,
      ["ReportHurtFlow"] = true,
      ["ReportMrpcsFlow"] = true,
      ["ReportSecVehicleMoveFlow"] = true,
      ["ReportTeammateKillConfirmFlow"] = true,
      ["ReportSecTgameMovingFlow"] = true,
      ["report_vehicle_move_drag"] = true,
      ["report_vehicle_move_drag_detail"] = true,
      ["report_character_all_drag"] = true,
      ["report_parachute_all_drag"] = true,
      ["report_players_ping"] = false,
      ["game_over"] = true,
      ["game_result"] = false,
      ["game_team_result"] = false,
      ["report_ds_match_room_data"] = false,
      ["log_shooting_miss"] = true,
      ["report_vehicle_correction"] = true,
    }

    NU.SendPacket = function(protocol, ...)
      if _blockedProtocols[protocol] == true then
        print("[DisableKillReport] NetUtil.SendPacket BLOCKED protocol=" .. tostring(protocol))
        return
      end
      return _origSendPacket(protocol, ...)
    end
    print("[DisableKillReport] patched NetUtil.SendPacket (filter enabled)")
    return true
  end

  local function _PatchPlayerState()
    local PS = nil
    if type(CGameState) == "table" and type(CGameState.GetPlayerStateByUID) == "function" then
    end
    local ok, cls = pcall(require, "GameLua.GameCore.Player.PlayerState")
    if not ok or type(cls) ~= "table" then
      print("[DisableKillReport] PlayerState class not found, skip")
      return false
    end

    _safePatch(cls, "AddGeneralTLog", function(self)
      print("[DisableKillReport] blocked PlayerState:AddGeneralTLog")
    end, "PlayerState.AddGeneralTLog")

    _safePatch(cls, "AddGeneralCount", function(self)
      print("[DisableKillReport] blocked PlayerState:AddGeneralCount")
    end, "PlayerState.AddGeneralCount")

    return true
  end

  function DisableKillReport.Apply()
    print("[DisableKillReport] ===== APPLY START =====")

    _PatchGameplayCallbacks()
    _PatchWeaponRecordSubSystem()
    _PatchWeaponKillCounterFeature()
    _PatchDSKillAndKnockDownTLogSubsystem()
    _PatchGameModeBase()
    _PatchFatalDamageSubsystem()
    _PatchSendGameOver()
    _PatchNetUtilSendPacket()
    _PatchPlayerState()

    print("[DisableKillReport] ===== APPLY DONE =====")
  end

  function DisableKillReport.ApplyWithRetry()
    DisableKillReport.Apply()

    if type(Game) == "table" and type(Game.SetTimer) == "function" then
      local retries = {1, 3, 5, 10}
      for _, delay in ipairs(retries) do
        pcall(Game.SetTimer, delay, false, function()
          print("[DisableKillReport] retry after " .. tostring(delay) .. "s")
          DisableKillReport.Apply()
        end)
      end
    else
      print("[DisableKillReport] Game.SetTimer unavailable, no retry scheduled")
    end
  end

  DisableKillReport.ApplyWithRetry()

  return DisableKillReport
end  -- END _partE_rapzhang10

-- ============================================================================
-- PART F: rapzhang11 — AntiCheatBypass_Unified
-- ============================================================================
local function _partF_rapzhang11()
  local _RAPZHANGVIP_KEY = "rapzhangvip"

  local AntiCheatBypass_Unified = {}

  local function _safePatch(target, key, newFn, tag)
    if type(target) ~= "table" then return false end
    if type(target[key]) ~= "function" then return false end
    target[key] = newFn
    print("[AC-Unified] patched " .. tostring(tag))
    return true
  end

  local function _safePatchTable(target, key, newVal, tag)
    if type(target) ~= "table" then return false end
    target[key] = newVal
    print("[AC-Unified] patched table " .. tostring(tag))
    return true
  end

  local function _safeRequire(path)
    local ok, mod = pcall(require, path)
    if ok and type(mod) == "table" then return mod end
    return nil
  end

  local function _getSubsystem(name)
    if type(SubsystemMgr) == "table" and type(SubsystemMgr.Get) == "function" then
      local ok, s = pcall(SubsystemMgr.Get, SubsystemMgr, name)
      if ok and type(s) == "table" then return s end
    end
    return nil
  end

  local function _PatchHiggsBoson()
    local HB = _safeRequire("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
    if not HB then print("[AC-Unified] HiggsBoson not found") return false end

    _safePatch(HB, "SendAntiDataFlow", function()
      local ok, GI = pcall(import, "STExtraGameInstance")
      if ok and GI then
        local ok2, inst = pcall(GI.GetInstance)
        if ok2 and inst then
          pcall(function()
            if inst.MoveInputAngleSample then inst.MoveInputAngleSample:Clear() end
            if inst.MoveInputAngleDistribution then inst.MoveInputAngleDistribution:Clear() end
          end)
        end
      end
    end, "HiggsBoson.SendAntiDataFlow")

    _safePatch(HB, "SendHitFireBtnFlow", function()
      local ok, GI = pcall(import, "STExtraGameInstance")
      if ok and GI then
        local ok2, inst = pcall(GI.GetInstance)
        if ok2 and inst and inst.HitFireBtnFlow then
          pcall(function()
            if inst.HitFireBtnFlow.HitFireBtnSampleClusterArray then
              inst.HitFireBtnFlow.HitFireBtnSampleClusterArray:Clear()
            end
          end)
        end
      end
    end, "HiggsBoson.SendHitFireBtnFlow")

    _safePatch(HB, "SendFingerTouchFlow", function()
      local ok1, UHDS = pcall(import, "HiggsBosonDataSubsystem")
      local ok2, USBL = pcall(import, "SubsystemBlueprintLibrary")
      local ok3, GI = pcall(import, "STExtraGameInstance")
      if ok1 and ok2 and ok3 then
        local ok4, inst = pcall(GI.GetInstance)
        if ok4 and inst then
          local ok5, subsys = pcall(USBL.GetGameInstanceSubsystem, inst, UHDS)
          if ok5 and subsys and subsys.FingerTouchFlow then
            pcall(function()
              if subsys.FingerTouchFlow.Clusters then subsys.FingerTouchFlow.Clusters:Clear() end
              if subsys.FingerTouchFlow.FireSamples then subsys.FingerTouchFlow.FireSamples:Clear() end
            end)
          end
        end
      end
    end, "HiggsBoson.SendFingerTouchFlow")

    _safePatch(HB, "OnBattleResult", function()
      local ok, GI = pcall(import, "STExtraGameInstance")
      if ok and GI then
        local ok2, inst = pcall(GI.GetInstance)
        if ok2 and inst then
          pcall(function()
            inst.MoveInputsBitmapSize = -1
            if inst.MoveInputsBitmapData then inst.MoveInputsBitmapData:Clear() end
          end)
        end
      end
    end, "HiggsBoson.OnBattleResult")

    _safePatch(HB, "SendHisarData", function() end, "HiggsBoson.SendHisarData")
    _safePatch(HB, "ShowABCD", function() end, "HiggsBoson.ShowABCD")
    _safePatch(HB, "StaticShowSecurityAlertInDev", function() end, "HiggsBoson.StaticShowSecurityAlertInDev")
    _safePatch(HB, "_ClientShowSecurityAlertWindow", function() end, "HiggsBoson._ClientShowSecurityAlertWindow")
    _safePatch(HB, "_ReportChatRobot", function() end, "HiggsBoson._ReportChatRobot")
    _safePatch(HB, "_ProcessReportChatRobotQueue", function() end, "HiggsBoson._ProcessReportChatRobotQueue")
    _safePatch(HB, "SkipAlertServer", function() end, "HiggsBoson.SkipAlertServer")
    _safePatch(HB, "RecordStrategyTimestampInReplay", function() end, "HiggsBoson.RecordStrategyTimestampInReplay")
    _safePatch(HB, "OnGameModeType", function() end, "HiggsBoson.OnGameModeType")

    local inst = _getSubsystem("HiggsBosonComponent")
    if inst then
      _safePatch(inst, "ShowABCD", function() end, "instance.HiggsBoson.ShowABCD")
      _safePatch(inst, "SendAntiDataFlow", function() end, "instance.HiggsBoson.SendAntiDataFlow")
      _safePatch(inst, "SendHitFireBtnFlow", function() end, "instance.HiggsBoson.SendHitFireBtnFlow")
      _safePatch(inst, "SendFingerTouchFlow", function() end, "instance.HiggsBoson.SendFingerTouchFlow")
      _safePatch(inst, "OnBattleResult", function() end, "instance.HiggsBoson.OnBattleResult")
    end

    return true
  end

  local function _PatchDSFightTLog()
    local cls = _safeRequire("GameLua.Mod.BaseMod.DS.TLog.DSFightTLogSubsystem")
    if not cls then print("[AC-Unified] DSFightTLog not found") return false end

    _safePatch(cls, "OnInit", function(self)
      self.HashTimers = {}; self.FightRecord = {}; self.FinalFightRecords = {}
      self.PlayerKey2Hash = {}; self.PlayerKey2Index = {}; self.Index2PlayerKey = {}
      self.PlayerFireTime = {}; self.PlayerSimpleFightData = {}
    end, "DSFightTLog.OnInit")
    _safePatch(cls, "OnUninit", function() end, "DSFightTLog.OnUninit")
    _safePatch(cls, "OnHandleTakeDamage", function() end, "DSFightTLog.OnHandleTakeDamage")
    _safePatch(cls, "OnWeaponFire", function() end, "DSFightTLog.OnWeaponFire")
    _safePatch(cls, "OnPawnNearDeath", function() end, "DSFightTLog.OnPawnNearDeath")
    _safePatch(cls, "OnPawnRescue", function() end, "DSFightTLog.OnPawnRescue")
    _safePatch(cls, "OnCharacterDiePre", function() end, "DSFightTLog.OnCharacterDiePre")
    _safePatch(cls, "OnPlayerJoin", function() end, "DSFightTLog.OnPlayerJoin")
    _safePatch(cls, "OnPawnCousumeItem", function() end, "DSFightTLog.OnPawnCousumeItem")
    _safePatch(cls, "OnCharacterStartFire", function() end, "DSFightTLog.OnCharacterStartFire")
    _safePatch(cls, "NotifyPawnStateChange", function() end, "DSFightTLog.NotifyPawnStateChange")
    _safePatch(cls, "GetFightRecords", function() return {} end, "DSFightTLog.GetFightRecords")
    _safePatch(cls, "GetSimpleFightData", function() return {} end, "DSFightTLog.GetSimpleFightData")
    _safePatch(cls, "Dump", function() end, "DSFightTLog.Dump")

    local inst = _getSubsystem("DSFightTLogSubsystem")
    if inst then
      for _, m in ipairs({"OnHandleTakeDamage","OnWeaponFire","OnPawnNearDeath","OnPawnRescue","OnCharacterDiePre","OnPlayerJoin","OnPawnCousumeItem","OnCharacterStartFire","NotifyPawnStateChange","Dump"}) do
        _safePatch(inst, m, function() end, "instance.DSFightTLog." .. m)
      end
    end

    return true
  end

  local function _PatchDSReportPlayer()
    local cls = _safeRequire("GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem")
    if not cls then print("[AC-Unified] DSReportPlayer not found") return false end

    _safePatch(cls, "OnInit", function(self)
      self._tUID2InfoMap = {}; self.nNoStartUpDoorNum = 0
    end, "DSReportPlayer.OnInit")
    _safePatch(cls, "OnUninit", function() end, "DSReportPlayer.OnUninit")
    for _, m in ipairs({"_OnNearDeathOrRescued","_OnTeammateDamage","_OnCharacterDied","_OnPlayerSettlementStart","_OnPlayerReconnect","_SyncFatalDamagerMap","_OnNoNetStartUpDoor","_RecordFatalDamager","_RecordTeammateMurderer"}) do
      _safePatch(cls, m, function() end, "DSReportPlayer." .. m)
    end

    local inst = _getSubsystem("DSReportPlayerSubsystem")
    if inst then
      for _, m in ipairs({"_OnNearDeathOrRescued","_OnTeammateDamage","_OnCharacterDied","_OnPlayerSettlementStart","_OnPlayerReconnect","_SyncFatalDamagerMap","_OnNoNetStartUpDoor","_RecordFatalDamager","_RecordTeammateMurderer"}) do
        _safePatch(inst, m, function() end, "instance.DSReportPlayer." .. m)
      end
    end

    return true
  end

  local function _PatchDSKillKnockDown()
    local cls = _safeRequire("GameLua.Mod.BaseMod.DS.TLog.DSKillAndKnockDownTLogSubsystem")
    if not cls then print("[AC-Unified] DSKillKnockDown not found") return false end

    _safePatch(cls, "OnInit", function(self)
      self.PlayerInitCityNameRecords = {}
    end, "DSKillKnockDown.OnInit")
    _safePatch(cls, "OnUninit", function() end, "DSKillKnockDown.OnUninit")
    for _, m in ipairs({"OnHandleNearDeath","OnCharacterDied","OnCharacterDiedPre","TrySendToAIProxy","RecordAllFlowData","OnPreEnterNearDeath","OnPlayerParachutingEnd","RecordPlayerInitCityName"}) do
      _safePatch(cls, m, function() end, "DSKillKnockDown." .. m)
    end
    _safePatch(cls, "SetFlowData", function() return {} end, "DSKillKnockDown.SetFlowData")

    local inst = _getSubsystem("DSKillAndKnockDownTLogSubsystem")
    if inst then
      for _, m in ipairs({"OnHandleNearDeath","OnCharacterDied","OnCharacterDiedPre","TrySendToAIProxy","RecordAllFlowData","OnPreEnterNearDeath","OnPlayerParachutingEnd","RecordPlayerInitCityName"}) do
        _safePatch(inst, m, function() end, "instance.DSKillKnockDown." .. m)
      end
    end

    return true
  end
  local function _PatchGameplayCallbacks()
    local GC = rawget(_G, "GameplayCallbacks")
    if type(GC) ~= "table" then print("[AC-Unified] GameplayCallbacks not loaded") return false end

    _safePatch(GC, "SendDataMiningTLog", function() end, "GC.SendDataMiningTLog")
    _safePatch(GC, "SendSecTLog", function() end, "GC.SendSecTLog")
    _safePatch(GC, "SendActivityTLog", function() end, "GC.SendActivityTLog")

    for _, m in ipairs({"ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms","ReportMisKillByTeammate","ReportMrpcsFlow","ReportVehicleMoveFlow","ReportSecTgameMovingFlow","ReportPlayerBehavior","ReportPlayerMoveRoute","ReportPlayerPosition","ReportPlayerIP","ReportCommonInfo","ReportFeedback","ReportJumpFlow","ReportCircleFlow","ReportDSCircleFlow","ReportAimFlow","ReportEquipmentFlow","ReportVerifyInfoFlow","ReportForbitPick","ReportTeammatHurt","ReportParachuteData","ReportGameSetting","ReportGameStartFlow","ReportGameEndFlow","ReportRevivalFlow","ReportIDCardProduceFlow","ReportIDCardPickUpFlow","ReportIDCardDestroyFlow","ReportAIStrategyInfo","ReportHeavyWeaponBoxSpawnFlow","ReportHeavyWeaponBoxActivationFlow","ReportHeavyWeaponBoxOpenPlayerFlow","ReportHeavyWeaponBoxItemFlow"}) do
      _safePatch(GC, m, function() end, "GC." .. m)
    end

    _safePatch(GC, "SendTssSdkAntiDataToLobby", function() end, "GC.SendTssSdkAntiDataToLobby")
    _safePatch(GC, "SendDSErrorLogToLobby", function() end, "GC.SendDSErrorLogToLobby")
    _safePatch(GC, "SendDSErrorLogToLobbyOnece", function() end, "GC.SendDSErrorLogToLobbyOnece")
    _safePatch(GC, "SendDSHawkEyePatrolLogToLobby", function() end, "GC.SendDSHawkEyePatrolLogToLobby")

    _safePatch(GC, "OnPlayerNetConnectionClosed", function() end, "GC.OnPlayerNetConnectionClosed")
    _safePatch(GC, "OnPlayerActorChannelError", function() end, "GC.OnPlayerActorChannelError")
    _safePatch(GC, "OnPlayerSpectateException", function() end, "GC.OnPlayerSpectateException")
    _safePatch(GC, "OnPlayerRPCValidateFailed", function() end, "GC.OnPlayerRPCValidateFailed")
    _safePatch(GC, "RepListMismatchDetectTrigger", function() end, "GC.RepListMismatchDetectTrigger")

    _safePatch(GC, "SendGameOver", function() end, "GC.SendGameOver")

    _safePatch(GC, "GetWeaponReport", function() return {} end, "GC.GetWeaponReport")
    _safePatch(GC, "GetOneWeaponReport", function() return {} end, "GC.GetOneWeaponReport")
    _safePatch(GC, "GetPlayerKillerFlow", function() return nil end, "GC.GetPlayerKillerFlow")

    _safePatch(GC, "SendPlayerBattleResultToObserver", function() end, "GC.SendPlayerBattleResultToObserver")
    _safePatch(GC, "SendTeamBattleResultToObserver", function() end, "GC.SendTeamBattleResultToObserver")

    if type(GC.GetPlayerBattleResultData) == "function" then
      local _orig = GC.GetPlayerBattleResultData
      GC.GetPlayerBattleResultData = function(nUID, sReason)
        local result = _orig(nUID, sReason)
        if type(result) == "table" then
          result.WeaponReport = nil
          result.KillerFlow = nil
          result.GeneralTLog = nil
          result.LuaTLog = nil
          result.SpecialCollectionList = nil
          if result.ds2history then
            result.ds2history.tMurdererMap = nil
            result.ds2history.tKnockDownerMap = nil
            result.ds2history.tTeammateMurdererInfo = nil
            result.ds2history.tEnemyMap = nil
          end
        end
        return result
      end
      print("[AC-Unified] patched GC.GetPlayerBattleResultData (falsify)")
    end

    return true
  end

  local function _PatchFatalDamage()
    local cls = _safeRequire("GameLua.Mod.Library.DS.FatalDamageExpandData.FatalDamageSubsystem")
    if cls then
      _safePatch(cls, "BroadcastFatalDamageInfoWrapperSimpleLua", function() end, "FatalDamage.BroadcastFatalDamageInfoWrapperSimpleLua")
      _safePatch(cls, "BroadcastFatalDamageInfoWrapperLua", function() end, "FatalDamage.BroadcastFatalDamageInfoWrapperLua")
      _safePatch(cls, "AddPlayerKillerFlow", function() end, "FatalDamage.AddPlayerKillerFlow")
      _safePatch(cls, "RetrievePlayerKillerFlow", function() return nil end, "FatalDamage.RetrievePlayerKillerFlow")
    end

    local inst = _getSubsystem("FatalDamageSubsystem")
    if inst then
      _safePatch(inst, "BroadcastFatalDamageInfoWrapperSimpleLua", function() end, "instance.FatalDamage.BroadcastSimple")
      _safePatch(inst, "BroadcastFatalDamageInfoWrapperLua", function() end, "instance.FatalDamage.Broadcast")
      _safePatch(inst, "AddPlayerKillerFlow", function() end, "instance.FatalDamage.AddPlayerKillerFlow")
    end

    return cls ~= nil
  end

  local function _PatchClientReportPlayer()
    local cls = _safeRequire("GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem")
    if not cls then print("[AC-Unified] ClientReportPlayer not found") return false end

    _safePatch(cls, "OnInit", function(self) self._tCache = {} end, "ClientReportPlayer.OnInit")
    _safePatch(cls, "OnUninit", function() end, "ClientReportPlayer.OnUninit")
    for _, m in ipairs({"ReportTeammateDamage","ReportCheat","ReportPlayerBehavior","ReportMaliciousTeammate","Server_ReportPlayer","RPC_Server_ReportPlayer","ServerReportPlayer","FlushCache","FlushReports","OnNearDeathOrRescued","OnTeammateDamage","OnCharacterDied"}) do
      _safePatch(cls, m, function() end, "ClientReportPlayer." .. m)
    end
    _safePatch(cls, "Tick", function(self) if self then self._tCache = {} end end, "ClientReportPlayer.Tick")

    local inst = _getSubsystem("ClientReportPlayerSubsystem")
    if inst then
      for _, m in ipairs({"ReportTeammateDamage","ReportCheat","ReportPlayerBehavior","ReportMaliciousTeammate","FlushCache","FlushReports"}) do
        _safePatch(inst, m, function() end, "instance.ClientReportPlayer." .. m)
      end
    end

    return true
  end

  local function _PatchInspectionClient()
    local cls = _safeRequire("GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemReportClientLogicSubsystem")
    if not cls then print("[AC-Unified] InspectionClient not found") return false end

    _safePatch(cls, "OnInit", function(self) self._tCache = {} end, "InspectionClient.OnInit")
    _safePatch(cls, "OnUninit", function() end, "InspectionClient.OnUninit")
    for _, m in ipairs({"ReportInspection","ReportProperty","ReportComponent","ReportActor","ReportPlayer","ReportSuspicious","Server_ReportInspection","RPC_Server_ReportInspection","ServerReport","FlushCache","FlushReports","OnPropertyChanged","OnComponentChanged","OnActorSpawned","Dump"}) do
      _safePatch(cls, m, function() end, "InspectionClient." .. m)
    end
    _safePatch(cls, "Tick", function(self) if self then self._tCache = {} end end, "InspectionClient.Tick")

    local inst = _getSubsystem("InspectionSystemReportClientLogicSubsystem")
    if inst then
      for _, m in ipairs({"ReportInspection","ReportProperty","ReportComponent","ReportActor","ReportPlayer","ReportSuspicious","FlushCache","FlushReports"}) do
        _safePatch(inst, m, function() end, "instance.InspectionClient." .. m)
      end
    end

    return true
  end

  local function _PatchInspectionDS()
    local cls = _safeRequire("GameLua.Mod.BaseMod.DS.InspectionSystem.InspectionSystemReportDSLogicSubsystem")
    if not cls then print("[AC-Unified] InspectionDS not found") return false end

    _safePatch(cls, "OnInit", function(self) self._tCache = {} end, "InspectionDS.OnInit")
    _safePatch(cls, "OnUninit", function() end, "InspectionDS.OnUninit")
    for _, m in ipairs({"ReportInspection","ReportProperty","ReportComponent","ReportActor","ReportPlayer","ReportSuspicious","Server_ReportInspection","RPC_Server_ReportInspection","ServerReport","FlushCache","FlushReports","OnPropertyChanged","OnComponentChanged","OnActorSpawned","Dump"}) do
      _safePatch(cls, m, function() end, "InspectionDS." .. m)
    end
    _safePatch(cls, "Tick", function(self) if self then self._tCache = {} end end, "InspectionDS.Tick")

    local inst = _getSubsystem("InspectionSystemReportDSLogicSubsystem")
    if inst then
      for _, m in ipairs({"ReportInspection","ReportProperty","ReportComponent","ReportActor","ReportPlayer","ReportSuspicious","FlushCache","FlushReports"}) do
        _safePatch(inst, m, function() end, "instance.InspectionDS." .. m)
      end
    end

    return true
  end

  local function _PatchSecuritySubsystems()
    local _subsystems = {
      { name = "DSSecurityTLogSubsystem", path = "GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","ReportSecurity","ReportPlayer","ReportCheat","ReportSuspicious","Dump"} },
      { name = "DSPVSSubsystem", path = "GameLua.Mod.BaseMod.DS.Security.DSPVSSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","ReportPVS","ReportPlayer","Dump"} },
      { name = "DSCreditTLogSubsystem", path = "GameLua.Mod.BaseMod.DS.Security.DSCreditTLogSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","ReportCredit","Dump"} },
      { name = "DSMaliciousTeammateDetectionSubsystem", path = "GameLua.Mod.BaseMod.DS.Security.DSMaliciousTeammateDetectionSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","ReportMalicious","Dump"} },
      { name = "AITrackingLogSubsystem", path = "GameLua.Mod.BaseMod.DS.AI.AITrackingLogSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","ReportAITracking","Dump"} },
      { name = "CarryBackCompTLogSubsystem", path = "GameLua.Mod.BaseMod.DS.TLog.DSCarryBackSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","ReportCarryBack","Dump"} },
      { name = "DSAITLogSubsystem", path = "GameLua.Mod.BaseMod.DS.TLog.DSAITLogSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","ReportAITLog","Dump"} },
      { name = "DSWeaponTLogSubsystem", path = "GameLua.Mod.BaseMod.DS.TLog.DSWeaponTLogSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","ReportWeapon","Dump"} },
      { name = "DSShootTlogSubsystem", path = "GameLua.Mod.BaseMod.DS.TLog.DSShootTlogSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","ReportShoot","Dump"} },
      { name = "DSMLAITLogSubsystem", path = "GameLua.Mod.BaseMod.DS.TLog.DSMLAITLogSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","Dump"} },
      { name = "DSTaskTLogSubsystem", path = "GameLua.Mod.BaseMod.DS.TLog.DSTaskTLogSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","Dump"} },
      { name = "AFKReportorSubsystem", path = "GameLua.Mod.BaseMod.DS.AFKReportorSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","PlayerHaveAction","Dump"} },
      { name = "ICTLogSubsystem", path = "GameLua.Mod.BaseMod.DS.ICTLogSubsystem", methods = {"OnInit","OnUninit","FlushCache","FlushReports","Tick","Dump"} },
    }

    for _, def in ipairs(_subsystems) do
      local cls = _safeRequire(def.path)
      if cls then
        for _, m in ipairs(def.methods) do
          _safePatch(cls, m, function() end, def.name .. "." .. m)
        end
        local inst = _getSubsystem(def.name)
        if inst then
          for _, m in ipairs(def.methods) do
            _safePatch(inst, m, function() end, "instance." .. def.name .. "." .. m)
          end
        end
      end
    end

    return true
  end

  local function _PatchWeaponRecord()
    local WRS = _safeRequire("GameLua.Mod.BaseMod.DS.BattleResult.WeaponRecordSubSystem")
    if not WRS then
      WRS = _getSubsystem("WeaponRecordSubSystem")
    end
    if type(WRS) ~= "table" then print("[AC-Unified] WeaponRecord not found") return false end

    _safePatch(WRS, "OnHandleKill", function() end, "WeaponRecord.OnHandleKill")
    _safePatch(WRS, "OnHit", function() end, "WeaponRecord.OnHit")
    _safePatch(WRS, "OnHitMonster", function() end, "WeaponRecord.OnHitMonster")
    _safePatch(WRS, "OnOtherHitMonster", function() end, "WeaponRecord.OnOtherHitMonster")
    _safePatch(WRS, "HandleCharacterKillForWeaponCapability", function() end, "WeaponRecord.HandleCharacterKillForWeaponCapability")
    _safePatch(WRS, "HandleDamageForWeaponCapability", function() end, "WeaponRecord.HandleDamageForWeaponCapability")
    _safePatch(WRS, "RetrieveWeaponRecord", function() return {BattleId="0",BattleMode=0,TotalWeaponRecord={}} end, "WeaponRecord.RetrieveWeaponRecord")
    _safePatch(WRS, "RetrieveOneWeaponRecord", function() return {} end, "WeaponRecord.RetrieveOneWeaponRecord")

    local _origOnOtherHit = WRS.OnOtherHit
    if type(_origOnOtherHit) == "function" then
      WRS.OnOtherHit = function(self, _, _, attackerId, weaponId, aimType, distance, damage, isKill, bFallOnGround, States, HitPos, VictimType, IsAddHitFlow, shootID, VictimPlayerKey)
        return _origOnOtherHit(self, nil, nil, attackerId, weaponId, aimType, distance, damage, 0, bFallOnGround, States, HitPos, VictimType, false, shootID, VictimPlayerKey)
      end
      print("[AC-Unified] patched WeaponRecord.OnOtherHit (isKill=0)")
    end

    local WKCF = _safeRequire("GameLua.Activity.Commercialize.GamePlay.WeaponKillCounter.WeaponKillCounterFeature")
    if WKCF then
      _safePatch(WKCF, "SetCurChangedKillCounterInfo", function() end, "WeaponKillCounterFeature.SetCurChangedKillCounterInfo")
      _safePatch(WKCF, "RPC_Server_GetCurBattleWeaponKillInfo", function() end, "WeaponKillCounterFeature.RPC_Server_GetCurBattleWeaponKillInfo")
      _safePatch(WKCF, "RPC_Client_UpdateCurBattleWeaponKillInfo", function() end, "WeaponKillCounterFeature.RPC_Client_UpdateCurBattleWeaponKillInfo")
      _safePatch(WKCF, "OnRep_ChangedKillCounterInfo", function() end, "WeaponKillCounterFeature.OnRep_ChangedKillCounterInfo")
    end

    local WKCS = _safeRequire("GameLua.Mod.BaseMod.GamePlay.WeaponKillCounter.WeaponKillCounterSubsystem")
    if WKCS then
      _safePatch(WKCS, "OnPlayerWeaponKillNumChange", function() end, "WeaponKillCounterSubsystem.OnPlayerWeaponKillNumChange")
      _safePatch(WKCS, "OnHandleKillRecordChange", function() end, "WeaponKillCounterSubsystem.OnHandleKillRecordChange")
    end

    return true
  end

  local function _PatchPlayerState()
    local cls = _safeRequire("GameLua.GameCore.Player.PlayerState")
    if cls then
      _safePatch(cls, "AddGeneralTLog", function() end, "PlayerState.AddGeneralTLog")
      _safePatch(cls, "AddGeneralCount", function() end, "PlayerState.AddGeneralCount")
    end

    if type(CGameState) == "table" and type(CGameState.GetAllPlayerStates) == "function" then
      local ok, arr = pcall(CGameState.GetAllPlayerStates, CGameState)
      if ok and arr and type(arr) == "table" and arr.Num then
        for i = 0, arr:Num() - 1 do
          local ps = arr:Get(i)
          if ps then
            _safePatch(ps, "AddGeneralTLog", function() end, "instance.PlayerState.AddGeneralTLog")
            _safePatch(ps, "AddGeneralCount", function() end, "instance.PlayerState.AddGeneralCount")
          end
        end
      end
    end

    return true
  end

  local function _PatchSubsystemConfig()
    local cfg = _safeRequire("GameLua.GameCore.Module.Subsystem.SubsystemConfig")
    if not cfg then print("[AC-Unified] SubsystemConfig not found") return false end

    local _names = {
      "HiggsBoson",
      "DSFightTLogSubsystem", "DSReportPlayerSubsystem", "DSKillAndKnockDownTLogSubsystem",
      "DSSecurityTLogSubsystem", "DSPVSSubsystem", "DSCreditTLogSubsystem",
      "DSMaliciousTeammateDetectionSubsystem", "AITrackingLogSubsystem",
      "InspectionSystemReportDSLogicSubsystem", "CarryBackCompTLogSubsystem",
      "DSAITLogSubsystem", "DSWeaponTLogSubsystem", "DSShootTlogSubsystem",
      "DSMLAITLogSubsystem", "DSTaskTLogSubsystem", "AFKReportorSubsystem", "ICTLogSubsystem",
      "ClientReportPlayerSubsystem", "InspectionSystemReportClientLogicSubsystem",
      "WeaponRecordSubSystem",
    }

    for _, name in ipairs(_names) do
      if cfg[name] then
        local orig = cfg[name]
        cfg[name] = { module = "GameLua.Mod.BaseMod.Common.Security.EmptyStub", side = orig.side or "DS" }
        print("[AC-Unified] SubsystemConfig: disabled " .. name)
      end
    end

    package.loaded["GameLua.Mod.BaseMod.Common.Security.EmptyStub"] = {
      OnInit = function() end, OnUninit = function() end,
      ReceiveBeginPlay = function() end, ReceiveEndPlay = function() end,
    }
    print("[AC-Unified] installed stub module")

    return true
  end

  local function _PatchNetUtil()
    local NU = rawget(_G, "NetUtil")
    if type(NU) ~= "table" then print("[AC-Unified] NetUtil not found") return false end

    local _blocked = {
      ["report_kill_and_knockdown_flow"]=true, ["ReportHitFlow"]=true, ["ReportFireArms"]=true,
      ["ReportSecAttackFlow"]=true, ["ReportAttackFlow"]=true, ["ReportHurtFlow"]=true,
      ["ReportMrpcsFlow"]=true, ["ReportSecVehicleMoveFlow"]=true,
      ["ReportTeammateKillConfirmFlow"]=true, ["ReportSecTgameMovingFlow"]=true,
      ["report_vehicle_move_drag"]=true, ["report_vehicle_move_drag_detail"]=true,
      ["report_character_all_drag"]=true, ["report_parachute_all_drag"]=true,
      ["log_shooting_miss"]=true,
      ["game_over"]=true,
      ["on_crow_update_ntf"]=true, ["on_crow_update_ntf2"]=true, ["on_crow_update_ntf3"]=true,
      ["on_crow_update_ntf4"]=true, ["on_crow_update_ntf5"]=true, ["hisar"]=true,
      ["on_tss_sdk_anti_data"]=true,
      ["report_common_info"]=true,
      ["ReportPlayerBehavior"]=true, ["ReportPlayerMoveRoute"]=true, ["ReportPlayerPosition"]=true,
      ["report_player_ip"]=true,
      ["report_unrealnet_exception"]=true,
      ["SendDSHawkEyePatrolLogToLobby"]=true,
      ["report_teammate_damage"]=true, ["report_player_cheat"]=true,
      ["report_player_behavior_client"]=true, ["report_malicious_teammate"]=true,
      ["inspection_report"]=true, ["inspection_property_report"]=true,
      ["inspection_component_report"]=true, ["report_client_inspection"]=true,
      ["report_suspicious_data"]=true, ["client_report_player"]=true,
      ["client_inspection_report"]=true,
      ["ReportSecurityFlow"]=true, ["ReportPVSFlow"]=true, ["ReportCreditFlow"]=true,
      ["ReportMaliciousTeammate"]=true, ["ReportAITracking"]=true, ["ReportCarryBack"]=true,
      ["ReportAITLog"]=true, ["ReportWeaponFlow"]=true, ["ReportShootFlow"]=true,
      ["ReportMLAITLog"]=true, ["ReportTaskFlow"]=true, ["ReportAFK"]=true, ["ReportICTLog"]=true,
    }

    if type(NU.SendPacket) == "function" then
      local _orig = NU.SendPacket
      NU.SendPacket = function(protocol, ...)
        if _blocked[protocol] == true then
          print("[AC-Unified] NetUtil.SendPacket BLOCKED: " .. tostring(protocol))
          return
        end
        return _orig(protocol, ...)
      end
      print("[AC-Unified] patched NetUtil.SendPacket")
    end

    if type(NU.SendPkg) == "function" then
      local _orig = NU.SendPkg
      NU.SendPkg = function(protocol, ...)
        if _blocked[protocol] == true then
          print("[AC-Unified] NetUtil.SendPkg BLOCKED: " .. tostring(protocol))
          return
        end
        return _orig(protocol, ...)
      end
      print("[AC-Unified] patched NetUtil.SendPkg")
    end

    return true
  end

  function AntiCheatBypass_Unified.Apply()
    print("[AC-Unified] ===== APPLY START =====")

    _PatchHiggsBoson()
    _PatchDSFightTLog()
    _PatchDSReportPlayer()
    _PatchDSKillKnockDown()
    _PatchGameplayCallbacks()
    _PatchFatalDamage()
    _PatchClientReportPlayer()
    _PatchInspectionClient()
    _PatchInspectionDS()
    _PatchSecuritySubsystems()
    _PatchWeaponRecord()
    _PatchPlayerState()
    _PatchSubsystemConfig()
    _PatchNetUtil()

    print("[AC-Unified] ===== APPLY DONE =====")
  end

  function AntiCheatBypass_Unified.ApplyWithRetry()
    AntiCheatBypass_Unified.Apply()

    if type(Game) == "table" and type(Game.SetTimer) == "function" then
      for _, delay in ipairs({1, 3, 5, 10, 20, 30}) do
        pcall(Game.SetTimer, delay, false, function()
          print("[AC-Unified] retry after " .. tostring(delay) .. "s")
          AntiCheatBypass_Unified.Apply()
        end)
      end
    end
  end

  AntiCheatBypass_Unified.ApplyWithRetry()

  return AntiCheatBypass_Unified
end  -- END _partF_rapzhang11

-- ============================================================================
-- PART G: rapzhang12 — AntiCheatBlock_Full
-- ============================================================================
local function _partG_rapzhang12()
  local _RAPZHANGVIP_KEY = "rapzhangvip"

  local AntiCheatBlock_Full = {}

  local function _safePatch(target, key, newFn, tag)
    if type(target) ~= "table" then return false end
    if type(target[key]) ~= "function" then return false end
    target[key] = newFn
    print("[AC-Full] patched " .. tostring(tag))
    return true
  end

  local function _safeRequire(path)
    local ok, mod = pcall(require, path)
    if ok and type(mod) == "table" then return mod end
    return nil
  end

  local function _getSubsystem(name)
    if type(SubsystemMgr) == "table" and type(SubsystemMgr.Get) == "function" then
      local ok, s = pcall(SubsystemMgr.Get, SubsystemMgr, name)
      if ok and type(s) == "table" then return s end
    end
    return nil
  end

  local function _lower(str)
    return string.lower(tostring(str or ""))
  end

  local function _containsAny(str, list)
    local lower = _lower(str)
    for _, kw in ipairs(list) do
      if string.find(lower, kw, 1, true) then return true, kw end
    end
    return false, nil
  end
  local function _PatchHiggsBoson()
    local HB = _safeRequire("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
    if not HB then print("[AC-Full] HiggsBoson not found") return false end

    _safePatch(HB, "SendAntiDataFlow", function()
      local ok, GI = pcall(import, "STExtraGameInstance")
      if ok and GI then
        local ok2, inst = pcall(GI.GetInstance)
        if ok2 and inst then
          pcall(function()
            if inst.MoveInputAngleSample then inst.MoveInputAngleSample:Clear() end
            if inst.MoveInputAngleDistribution then inst.MoveInputAngleDistribution:Clear() end
          end)
        end
      end
    end, "HiggsBoson.SendAntiDataFlow")

    _safePatch(HB, "SendHitFireBtnFlow", function()
      local ok, GI = pcall(import, "STExtraGameInstance")
      if ok and GI then
        local ok2, inst = pcall(GI.GetInstance)
        if ok2 and inst and inst.HitFireBtnFlow then
          pcall(function()
            if inst.HitFireBtnFlow.HitFireBtnSampleClusterArray then
              inst.HitFireBtnFlow.HitFireBtnSampleClusterArray:Clear()
            end
          end)
        end
      end
    end, "HiggsBoson.SendHitFireBtnFlow")

    _safePatch(HB, "SendFingerTouchFlow", function()
      local ok1, UHDS = pcall(import, "HiggsBosonDataSubsystem")
      local ok2, USBL = pcall(import, "SubsystemBlueprintLibrary")
      local ok3, GI = pcall(import, "STExtraGameInstance")
      if ok1 and ok2 and ok3 then
        local ok4, inst = pcall(GI.GetInstance)
        if ok4 and inst then
          local ok5, subsys = pcall(USBL.GetGameInstanceSubsystem, inst, UHDS)
          if ok5 and subsys and subsys.FingerTouchFlow then
            pcall(function()
              if subsys.FingerTouchFlow.Clusters then subsys.FingerTouchFlow.Clusters:Clear() end
              if subsys.FingerTouchFlow.FireSamples then subsys.FingerTouchFlow.FireSamples:Clear() end
            end)
          end
        end
      end
    end, "HiggsBoson.SendFingerTouchFlow")

    _safePatch(HB, "OnBattleResult", function()
      local ok, GI = pcall(import, "STExtraGameInstance")
      if ok and GI then
        local ok2, inst = pcall(GI.GetInstance)
        if ok2 and inst then
          pcall(function()
            inst.MoveInputsBitmapSize = -1
            if inst.MoveInputsBitmapData then inst.MoveInputsBitmapData:Clear() end
          end)
        end
      end
    end, "HiggsBoson.OnBattleResult")

    _safePatch(HB, "SendHisarData", function() end, "HiggsBoson.SendHisarData")
    _safePatch(HB, "ShowABCD", function() end, "HiggsBoson.ShowABCD")
    _safePatch(HB, "StaticShowSecurityAlertInDev", function() end, "HiggsBoson.StaticShowSecurityAlertInDev")
    _safePatch(HB, "_ClientShowSecurityAlertWindow", function() end, "HiggsBoson._ClientShowSecurityAlertWindow")
    _safePatch(HB, "_ReportChatRobot", function() end, "HiggsBoson._ReportChatRobot")
    _safePatch(HB, "_ProcessReportChatRobotQueue", function() end, "HiggsBoson._ProcessReportChatRobotQueue")
    _safePatch(HB, "SkipAlertServer", function() end, "HiggsBoson.SkipAlertServer")
    _safePatch(HB, "RecordStrategyTimestampInReplay", function() end, "HiggsBoson.RecordStrategyTimestampInReplay")
    _safePatch(HB, "OnGameModeType", function() end, "HiggsBoson.OnGameModeType")

    local inst = _getSubsystem("HiggsBosonComponent")
    if inst then
      for _, m in ipairs({"ShowABCD","SendAntiDataFlow","SendHitFireBtnFlow","SendFingerTouchFlow","OnBattleResult","SendHisarData","StaticShowSecurityAlertInDev","_ClientShowSecurityAlertWindow","_ReportChatRobot","SkipAlertServer"}) do
        _safePatch(inst, m, function() end, "instance.HiggsBoson." .. m)
      end
    end
    return true
  end

  local _WHITELIST_METHODS = {
    OnInit=true, OnUninit=true, ReceiveBeginPlay=true, ReceiveEndPlay=true,
    ctor=true, _PostConstruct=true, OnDestroyed=true, ClassName=true,
    __index=true, __newindex=true, __tostring=true, __eq=true, __lt=true,
    __le=true, __add=true, __sub=true, __mul=true, __div=true, __mod=true,
    __pow=true, __unm=true, __concat=true, __call=true, __len=true,
    __gc=true, __mode=true, __metatable=true, __pairs=true, __ipairs=true,
    Dispose=true, GetName=true, GetClassName=true,
    GetPlayerInfo=true, GetPlayerName=true, GetPlayerUID=true,
    GetPlayerState=true, GetPlayerCharacter=true, GetPlayerController=true,
  }

  local function _BlockAllMethods(cls, name)
    if type(cls) ~= "table" then return 0 end
    local blocked = 0
    local toBlock = {}
    for m, fn in pairs(cls) do
      if type(m) == "string" and type(fn) == "function" and not _WHITELIST_METHODS[m] then
        table.insert(toBlock, m)
      end
    end
    for _, m in ipairs(toBlock) do
      if pcall(function() cls[m] = function() end end) then
        blocked = blocked + 1
      end
    end
    if blocked > 0 then
      print(string.format("[AC-Full] %s: blocked %d methods", name, blocked))
    end
    return blocked
  end

  local function _PatchSubsystemByName(name, path)
    local cls = _safeRequire(path)
    if cls then
      _BlockAllMethods(cls, name)
    end
    local inst = _getSubsystem(name)
    if inst then
      _BlockAllMethods(inst, "instance." .. name)
    end
    return cls ~= nil
  end

  local function _PatchAllAntiCheatSubsystems()
    local _list = {
      {"DSFightTLogSubsystem", "GameLua.Mod.BaseMod.DS.TLog.DSFightTLogSubsystem"},
      {"DSKillAndKnockDownTLogSubsystem", "GameLua.Mod.BaseMod.DS.TLog.DSKillAndKnockDownTLogSubsystem"},
      {"DSWeaponTLogSubsystem", "GameLua.Mod.BaseMod.DS.TLog.DSWeaponTLogSubsystem"},
      {"DSShootTlogSubsystem", "GameLua.Mod.BaseMod.DS.TLog.DSShootTlogSubsystem"},
      {"DSMLAITLogSubsystem", "GameLua.Mod.BaseMod.DS.TLog.DSMLAITLogSubsystem"},
      {"DSTaskTLogSubsystem", "GameLua.Mod.BaseMod.DS.TLog.DSTaskTLogSubsystem"},
      {"CarryBackCompTLogSubsystem", "GameLua.Mod.BaseMod.DS.TLog.DSCarryBackSubsystem"},
      {"DSReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"},
      {"DSSecurityTLogSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSSecurityTLogSubsystem"},
      {"DSPVSSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSPVSSubsystem"},
      {"DSCreditTLogSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSCreditTLogSubsystem"},
      {"DSMaliciousTeammateDetectionSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSMaliciousTeammateDetectionSubsystem"},
      {"DSHawkEyePatrolSubsystem", "GameLua.Mod.BaseMod.DS.Security.HawkEyeSpectate.DSHawkEyePatrolSubsystem"},
      {"ClientHawkEyePatrolSubsystem", "GameLua.Mod.BaseMod.Client.Security.HawkEyeSpectate.ClientHawkEyePatrolSubsystem"},
      {"InspectionSystemReportDSLogicSubsystem", "GameLua.Mod.BaseMod.DS.InspectionSystem.InspectionSystemReportDSLogicSubsystem"},
      {"InspectionSystemReportClientLogicSubsystem", "GameLua.Mod.BaseMod.Client.InspectionSystem.InspectionSystemReportClientLogicSubsystem"},
      {"ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem"},
      {"VoiceReportSubsystem", "GameLua.Mod.BaseMod.Client.Ban.VoiceReportSubsystem"},
      {"AITrackingLogSubsystem", "GameLua.Mod.BaseMod.DS.AI.AITrackingLogSubsystem"},
      {"AFKReportorSubsystem", "GameLua.Mod.BaseMod.DS.AFKReportorSubsystem"},
      {"ICTLogSubsystem", "GameLua.Mod.BaseMod.DS.ICTLogSubsystem"},
      {"GameArchiveDataSystem", "GameLua.Mod.BaseMod.GamePlay.GameArchiveData.GameArchiveDataSystem"},
      {"DSPlayerDataReportSubsystem", "GameLua.Mod.BaseMod.DS.BattleResult.DSPlayerDataReportSubsystem"},
    }

    for _, def in ipairs(_list) do
      _PatchSubsystemByName(def[1], def[2])
    end
    return true
  end

  local function _PatchGameplayCallbacks()
    local GC = rawget(_G, "GameplayCallbacks")
    if type(GC) ~= "table" then print("[AC-Full] GameplayCallbacks not loaded") return false end

    _safePatch(GC, "SendDataMiningTLog", function() end, "GC.SendDataMiningTLog")
    _safePatch(GC, "SendSecTLog", function() end, "GC.SendSecTLog")
    _safePatch(GC, "SendActivityTLog", function() end, "GC.SendActivityTLog")

    for _, m in ipairs({"ReportAttackFlow","ReportSecAttackFlow","ReportHurtFlow","ReportFireArms","ReportMisKillByTeammate","ReportMrpcsFlow","ReportVehicleMoveFlow","ReportSecTgameMovingFlow","ReportPlayerBehavior","ReportPlayerMoveRoute","ReportPlayerPosition","ReportPlayerIP","ReportCommonInfo","ReportFeedback","ReportJumpFlow","ReportCircleFlow","ReportDSCircleFlow","ReportAimFlow","ReportEquipmentFlow","ReportVerifyInfoFlow","ReportForbitPick","ReportTeammatHurt","ReportParachuteData","ReportGameSetting","ReportGameStartFlow","ReportGameEndFlow","ReportRevivalFlow","ReportIDCardProduceFlow","ReportIDCardPickUpFlow","ReportIDCardDestroyFlow","ReportAIStrategyInfo","ReportHeavyWeaponBoxSpawnFlow","ReportHeavyWeaponBoxActivationFlow","ReportHeavyWeaponBoxOpenPlayerFlow","ReportHeavyWeaponBoxItemFlow"}) do
      _safePatch(GC, m, function() end, "GC." .. m)
    end

    _safePatch(GC, "SendTssSdkAntiDataToLobby", function() end, "GC.SendTssSdkAntiDataToLobby")
    _safePatch(GC, "SendDSErrorLogToLobby", function() end, "GC.SendDSErrorLogToLobby")
    _safePatch(GC, "SendDSErrorLogToLobbyOnece", function() end, "GC.SendDSErrorLogToLobbyOnece")
    _safePatch(GC, "SendDSHawkEyePatrolLogToLobby", function() end, "GC.SendDSHawkEyePatrolLogToLobby")
    _safePatch(GC, "OnPlayerNetConnectionClosed", function() end, "GC.OnPlayerNetConnectionClosed")
    _safePatch(GC, "OnPlayerActorChannelError", function() end, "GC.OnPlayerActorChannelError")
    _safePatch(GC, "OnPlayerSpectateException", function() end, "GC.OnPlayerSpectateException")
    _safePatch(GC, "OnPlayerRPCValidateFailed", function() end, "GC.OnPlayerRPCValidateFailed")
    _safePatch(GC, "RepListMismatchDetectTrigger", function() end, "GC.RepListMismatchDetectTrigger")
    _safePatch(GC, "SendGameOver", function() end, "GC.SendGameOver")
    _safePatch(GC, "GetWeaponReport", function() return {} end, "GC.GetWeaponReport")
    _safePatch(GC, "GetOneWeaponReport", function() return {} end, "GC.GetOneWeaponReport")
    _safePatch(GC, "GetPlayerKillerFlow", function() return nil end, "GC.GetPlayerKillerFlow")
    _safePatch(GC, "SendPlayerBattleResultToObserver", function() end, "GC.SendPlayerBattleResultToObserver")
    _safePatch(GC, "SendTeamBattleResultToObserver", function() end, "GC.SendTeamBattleResultToObserver")

    if type(GC.GetPlayerBattleResultData) == "function" then
      local _orig = GC.GetPlayerBattleResultData
      GC.GetPlayerBattleResultData = function(nUID, sReason)
        local result = _orig(nUID, sReason)
        if type(result) == "table" then
          result.WeaponReport = nil
          result.KillerFlow = nil
          result.GeneralTLog = nil
          result.LuaTLog = nil
          result.SpecialCollectionList = nil
          if result.ds2history then
            result.ds2history.tMurdererMap = nil
            result.ds2history.tKnockDownerMap = nil
            result.ds2history.tTeammateMurdererInfo = nil
            result.ds2history.tEnemyMap = nil
          end
        end
        return result
      end
    end
    return true
  end

  local function _PatchFatalDamage()
    local cls = _safeRequire("GameLua.Mod.Library.DS.FatalDamageExpandData.FatalDamageSubsystem")
    if cls then _BlockAllMethods(cls, "FatalDamageSubsystem") end
    local inst = _getSubsystem("FatalDamageSubsystem")
    if inst then _BlockAllMethods(inst, "instance.FatalDamageSubsystem") end
    return cls ~= nil or inst ~= nil
  end

  local function _PatchWeaponRecord()
    local WRS = _safeRequire("GameLua.Mod.BaseMod.DS.BattleResult.WeaponRecordSubSystem") or _getSubsystem("WeaponRecordSubSystem")
    if type(WRS) == "table" then
      _BlockAllMethods(WRS, "WeaponRecordSubSystem")
      local _orig = WRS.OnOtherHit
      if type(_orig) == "function" then
        WRS.OnOtherHit = function(self, _, _, attackerId, weaponId, aimType, distance, damage, isKill, bFallOnGround, States, HitPos, VictimType, IsAddHitFlow, shootID, VictimPlayerKey)
          return _orig(self, nil, nil, attackerId, weaponId, aimType, distance, damage, 0, bFallOnGround, States, HitPos, VictimType, false, shootID, VictimPlayerKey)
        end
      end
    end
    _PatchSubsystemByName("WeaponKillCounterSubsystem", "GameLua.Mod.BaseMod.GamePlay.WeaponKillCounter.WeaponKillCounterSubsystem")
    local WKCF = _safeRequire("GameLua.Activity.Commercialize.GamePlay.WeaponKillCounter.WeaponKillCounterFeature")
    if WKCF then _BlockAllMethods(WKCF, "WeaponKillCounterFeature") end
    return true
  end

  local function _PatchPlayerState()
    local cls = _safeRequire("GameLua.GameCore.Player.PlayerState")
    if cls then
      _safePatch(cls, "AddGeneralTLog", function() end, "PlayerState.AddGeneralTLog")
      _safePatch(cls, "AddGeneralCount", function() end, "PlayerState.AddGeneralCount")
    end
    if type(CGameState) == "table" and type(CGameState.GetAllPlayerStates) == "function" then
      local ok, arr = pcall(CGameState.GetAllPlayerStates, CGameState)
      if ok and arr and arr.Num then
        for i = 0, arr:Num() - 1 do
          local ps = arr:Get(i)
          if ps then
            _safePatch(ps, "AddGeneralTLog", function() end, "instance.PlayerState.AddGeneralTLog")
            _safePatch(ps, "AddGeneralCount", function() end, "instance.PlayerState.AddGeneralCount")
          end
        end
      end
    end
    return true
  end

  local function _PatchSubsystemConfig()
    local cfg = _safeRequire("GameLua.GameCore.Module.Subsystem.SubsystemConfig")
    if not cfg then print("[AC-Full] SubsystemConfig not found") return false end

    local _names = {
      "HiggsBoson",
      "DSFightTLogSubsystem","DSReportPlayerSubsystem","DSKillAndKnockDownTLogSubsystem",
      "DSSecurityTLogSubsystem","DSPVSSubsystem","DSCreditTLogSubsystem",
      "DSMaliciousTeammateDetectionSubsystem","AITrackingLogSubsystem",
      "InspectionSystemReportDSLogicSubsystem","InspectionSystemReportClientLogicSubsystem",
      "CarryBackCompTLogSubsystem","DSAITLogSubsystem","DSWeaponTLogSubsystem",
      "DSShootTlogSubsystem","DSMLAITLogSubsystem","DSTaskTLogSubsystem",
      "AFKReportorSubsystem","ICTLogSubsystem","ClientReportPlayerSubsystem",
      "DSHawkEyePatrolSubsystem","ClientHawkEyePatrolSubsystem",
      "VoiceReportSubsystem","WeaponRecordSubSystem","WeaponKillCounterSubsystem",
      "GameArchiveDataSystem","DSPlayerDataReportSubsystem",
    }
    local stubName = "GameLua.Mod.BaseMod.Common.Security.EmptyStub"
    package.loaded[stubName] = { OnInit=function() end, OnUninit=function() end, ReceiveBeginPlay=function() end, ReceiveEndPlay=function() end }
    for _, name in ipairs(_names) do
      if cfg[name] then
        local orig = cfg[name]
        cfg[name] = { module = stubName, side = orig.side or "DS" }
      end
    end
    print("[AC-Full] stubbed " .. #_names .. " config entries")
    return true
  end

  local function _PatchNetUtil()
    local NU = rawget(_G, "NetUtil")
    if type(NU) ~= "table" then print("[AC-Full] NetUtil not found") return false end

    local PROTOCOL_BLOCK_KEYWORDS = {
      "kill","knock","death","died","murder","fatal","damage","hurt","attack",
      "shoot","fire","hit","aim","recoil","spread","accuracy",
      "move","drag","speed","teleport","position","location","route",
      "report","security","anticheat","antcheat","cheat","detect","suspicious",
      "inspection","inspect","audit","monitor","track",
      "pvs","credit","malicious","trust","score","reputation",
      "tlog","datalog","flow","log_","logging",
      "crow","higgs","boson","hisar","tss","anti_data","antidata",
      "common_info","feedback","exception","unrealnet",
      "hawkeye","spectate","watch",
      "afk","ict","pkg","packet","telemetry","metric","stat",
    }
    local PROTOCOL_WHITELIST = {
      ["game_start"]=true,["game_stop_join"]=true,["game_result"]=true,
      ["game_team_result"]=true,["heartbeat"]=true,["player_exit"]=true,
      ["load_player_info"]=true,["after_result_confirm"]=true,
    }

    local function _shouldBlock(protocol)
      if type(protocol) ~= "string" then return false end
      if PROTOCOL_WHITELIST[protocol] then return false end
      local lower = _lower(protocol)
      for _, kw in ipairs(PROTOCOL_BLOCK_KEYWORDS) do
        if string.find(lower, kw, 1, true) then return true, kw end
      end
      return false, nil
    end

    if type(NU.SendPacket) == "function" then
      local _orig = NU.SendPacket
      NU.SendPacket = function(protocol, ...)
        local block, kw = _shouldBlock(protocol)
        if block then
          print("[AC-Full] BLOCKED SendPacket: " .. tostring(protocol) .. " (kw=" .. tostring(kw) .. ")")
          return
        end
        return _orig(protocol, ...)
      end
    end
    if type(NU.SendPkg) == "function" then
      local _orig = NU.SendPkg
      NU.SendPkg = function(protocol, ...)
        local block, kw = _shouldBlock(protocol)
        if block then
          print("[AC-Full] BLOCKED SendPkg: " .. tostring(protocol) .. " (kw=" .. tostring(kw) .. ")")
          return
        end
        return _orig(protocol, ...)
      end
    end
    print("[AC-Full] patched NetUtil.SendPacket / SendPkg")
    return true
  end

  local ALERT_KEYWORDS = {
    "securityalert","security alert","anti-cheat","anticheat","anti cheat",
    "cheat detected","cheatdetected","suspicious","violation","warning",
    "异常","作弊","外挂","检测到","违规","封号","禁止",
    "banned","ban","kick","kicked","disconnect","terminated",
  }

  local function _PatchPopup()
    local IngameTipsTools = _safeRequire("GameLua.Mod.BaseMod.Common.UI.InGameTipsTools")
    if IngameTipsTools then
      if type(IngameTipsTools.ShowMsgBox) == "function" then
        local _orig = IngameTipsTools.ShowMsgBox
        IngameTipsTools.ShowMsgBox = function(showType, title, msg, ...)
          if _containsAny(msg, ALERT_KEYWORDS) or _containsAny(title, ALERT_KEYWORDS) then
            print("[AC-Full] blocked ShowMsgBox: " .. tostring(title))
            return
          end
          return _orig(showType, title, msg, ...)
        end
        print("[AC-Full] patched IngameTipsTools.ShowMsgBox")
      end
      if type(IngameTipsTools.ShowNotice) == "function" then
        local _orig = IngameTipsTools.ShowNotice
        IngameTipsTools.ShowNotice = function(msg, ...)
          if _containsAny(msg, ALERT_KEYWORDS) then
            print("[AC-Full] blocked ShowNotice")
            return
          end
          return _orig(msg, ...)
        end
        print("[AC-Full] patched IngameTipsTools.ShowNotice")
      end
      if type(IngameTipsTools.BattleGeneralTip) == "function" then
        local _orig = IngameTipsTools.BattleGeneralTip
        IngameTipsTools.BattleGeneralTip = function(tipID, ...)
          return _orig(tipID, ...)
        end
      end
    end

    if type(UIManager) == "table" and type(UIManager.ShowUI) == "function" then
      local _orig = UIManager.ShowUI
      UIManager.ShowUI = function(uiConfig, ...)
        local name = type(uiConfig) == "table" and tostring(uiConfig.UIName or uiConfig.Name or "") or tostring(uiConfig or "")
        if _containsAny(name, ALERT_KEYWORDS) then
          print("[AC-Full] blocked UIManager.ShowUI: " .. name)
          return
        end
        return _orig(uiConfig, ...)
      end
      print("[AC-Full] patched UIManager.ShowUI")
    end

    if type(_G.ShowNotice) == "function" then
      local _orig = _G.ShowNotice
      _G.ShowNotice = function(msg, ...)
        if _containsAny(msg, ALERT_KEYWORDS) then
          print("[AC-Full] blocked global ShowNotice")
          return
        end
        return _orig(msg, ...)
      end
      print("[AC-Full] patched global ShowNotice")
    end

    local MsgBox = _safeRequire("client.slua.logic.common.logic_common_msg_box")
    if MsgBox and type(MsgBox.Show) == "function" then
      local _orig = MsgBox.Show
      MsgBox.Show = function(msgType, title, msg, ...)
        if _containsAny(msg, ALERT_KEYWORDS) or _containsAny(title, ALERT_KEYWORDS) then
          print("[AC-Full] blocked MsgBox.Show: " .. tostring(title))
          return
        end
        return _orig(msgType, title, msg, ...)
      end
      print("[AC-Full] patched logic_common_msg_box.Show")
    end

    for _, path in ipairs({
      "client.slua.logic.common.logic_message_box",
      "client.slua.logic.common.logic_alert",
      "client.slua.logic.common.logic_dialog",
      "client.slua.logic.common.MessageBox",
    }) do
      local M = _safeRequire(path)
      if M then
        for _, m in ipairs({"Show","ShowMessage","ShowAlert","ShowDialog","Alert","Confirm"}) do
          if type(M[m]) == "function" then
            local _orig = M[m]
            M[m] = function(title, msg, ...)
              if _containsAny(msg, ALERT_KEYWORDS) or _containsAny(title, ALERT_KEYWORDS) then
                print("[AC-Full] blocked " .. path .. "." .. m)
                return
              end
              return _orig(title, msg, ...)
            end
          end
        end
      end
    end

    return true
  end

  local BAN_RPC_NAMES = {
    "ClientRPC_CheatDetected","RPC_Client_CheatDetected","OnCheatDetected",
    "Client_OnCheatDetected","ClientRPC_OnBan","RPC_Client_OnBan","OnBan",
    "ClientRPC_OnKick","RPC_Client_OnKick","OnKick","ClientRPC_Kick",
    "ClientRPC_Disconnect","RPC_Client_Disconnect","ClientRPC_ShowSecurityAlertWindow",
    "RPC_Client_ShowSecurityAlertWindow","ClientRPC_AntiCheatKick",
    "ClientRPC_Terminated","RPC_Client_Terminated","OnTerminated",
    "ClientRPC_ForceDisconnect","RPC_Client_ForceDisconnect",
  }

  local function _PatchBanRPC()
    local PC = _safeRequire("GameLua.GameCore.Player.PlayerController")
    if PC then
      for _, m in ipairs(BAN_RPC_NAMES) do
        _safePatch(PC, m, function() end, "PlayerController." .. m)
      end
    end

    local STPC = _safeRequire("GameLua.Mod.BaseMod.Common.Core.PlayerController")
    if STPC then
      for _, m in ipairs(BAN_RPC_NAMES) do
        _safePatch(STPC, m, function() end, "STPC." .. m)
      end
    end

    if type(CGameMode) == "table" and type(CGameMode.GetAllPlayerControllers) == "function" then
      local ok, arr = pcall(CGameMode.GetAllPlayerControllers, CGameMode)
      if ok and arr and arr.Num then
        for i = 0, arr:Num() - 1 do
          local pc = arr:Get(i)
          if pc then
            for _, m in ipairs(BAN_RPC_NAMES) do
              _safePatch(pc, m, function() end, "instance.PC." .. m)
            end
          end
        end
      end
    end

    if type(Game) == "table" and type(Game.GetAllPlayerControllers) == "function" then
      local ok, arr = pcall(Game.GetAllPlayerControllers)
      if ok and arr then
        for _, pc in pairs(arr) do
          if pc then
            for _, m in ipairs(BAN_RPC_NAMES) do
              _safePatch(pc, m, function() end, "instance.GamePC." .. m)
            end
          end
        end
      end
    end

    local Actor = _safeRequire("GameLua.Mod.BaseMod.Common.Core.ActorBase")
    if Actor then
      for _, m in ipairs({"K2_OnKick","K2_OnBan","K2_Disconnect","K2_ForceDisconnect"}) do
        _safePatch(Actor, m, function() end, "Actor." .. m)
      end
    end

    return true
  end

  local function _PatchConsoleVars()
    local ok, GI = pcall(import, "STExtraGameInstance")
    if not ok then return false end
    local ok2, inst = pcall(GI.GetInstance)
    if ok2 and inst then
      pcall(function() inst:ExecuteCMD("higgs.EnableClientShowSecurityAlert", 0) end)
      pcall(function() inst:ExecuteCMD("higgs.EnableServerAlert", 0) end)
      pcall(function() inst:ExecuteCMD("tss.EnableReport", 0) end)
      pcall(function() inst:ExecuteCMD("ace.EnableReport", 0) end)
      print("[AC-Full] set console vars to 0")
    end
    return true
  end

  local PATH_KEYWORDS = {
    "security","anticheat","antcheat","cheat","inspection","pvs","credit",
    "malicious","hawkeye","higgsboson","boson","tlog","report","detect",
    "monitor","tracking","afk","ict",
  }

  local function _NuclearAutoDetect()
    local count = 0
    for modulePath, mod in pairs(package.loaded) do
      if type(modulePath) == "string" and type(mod) == "table" then
        if string.find(modulePath, "GameLua", 1, true) then
          local matched = _containsAny(modulePath, PATH_KEYWORDS)
          if matched then
            count = count + _BlockAllMethods(mod, modulePath)
          end
        end
      end
    end
    print("[AC-Full] nuclear auto-detect: " .. count .. " methods blocked")
    return count
  end

  function AntiCheatBlock_Full.Apply()
    print("[AC-Full] ===== APPLY START =====")

    _PatchHiggsBoson()
    _PatchAllAntiCheatSubsystems()
    _PatchGameplayCallbacks()
    _PatchFatalDamage()
    _PatchWeaponRecord()
    _PatchPlayerState()
    _PatchSubsystemConfig()
    _PatchNetUtil()
    _PatchPopup()
    _PatchBanRPC()
    _PatchConsoleVars()
    _NuclearAutoDetect()

    print("[AC-Full] ===== APPLY DONE =====")
  end

  function AntiCheatBlock_Full.ApplyWithRetry()
    AntiCheatBlock_Full.Apply()
    if type(Game) == "table" and type(Game.SetTimer) == "function" then
      for _, delay in ipairs({1, 3, 5, 10, 20, 30, 60, 120, 300}) do
        pcall(Game.SetTimer, delay, false, function()
          print("[AC-Full] retry after " .. tostring(delay) .. "s")
          AntiCheatBlock_Full.Apply()
        end)
      end
    end
    if type(Game) == "table" and type(Game.SetTimer) == "function" then
      pcall(Game.SetTimer, 3, true, function()
        local ok, GI = pcall(import, "STExtraGameInstance")
        if ok and GI then
          local ok2, inst = pcall(GI.GetInstance)
          if ok2 and inst then
            pcall(function()
              if inst.MoveInputAngleSample then inst.MoveInputAngleSample:Clear() end
              if inst.MoveInputAngleDistribution then inst.MoveInputAngleDistribution:Clear() end
              if inst.MoveInputsBitmapData then inst.MoveInputsBitmapData:Clear() end
              if inst.HitFireBtnFlow and inst.HitFireBtnFlow.HitFireBtnSampleClusterArray then
                inst.HitFireBtnFlow.HitFireBtnSampleClusterArray:Clear()
              end
            end)
          end
        end
      end)
      print("[AC-Full] started Higgs cleanup timer (3s)")
    end
  end

  AntiCheatBlock_Full.ApplyWithRetry()

  return AntiCheatBlock_Full
end  -- END _partG_rapzhang12

-- ============================================================================
-- NETWORK DIAGNOSTIC BUILD: original seven parts retained above for inspection.
-- No invasive part is executed. This avoids replacing native packet handlers,
-- suppressing callbacks, or masking genuine server disconnects.
-- ============================================================================
function ACU.Apply()
  if ACU.Installed then return true end
  ACU.Installed = true
  ACU.Parts = { A_rapzhang8="PRESERVED_NOT_EXECUTED", B_rapzhang7="PRESERVED_NOT_EXECUTED", C_rapzhang5="PRESERVED_NOT_EXECUTED", D_rapzhang9="PRESERVED_NOT_EXECUTED", E_rapzhang10="PRESERVED_NOT_EXECUTED", F_rapzhang11="PRESERVED_NOT_EXECUTED", G_rapzhang12="PRESERVED_NOT_EXECUTED" }
  print("[ACU] Diagnostic mode: original network handlers left intact")
  return true
end
function ACU.Stats()
  return {version="SAFE-NATIVE-DIAGNOSTIC v2.0", installed=ACU.Installed,
    blocked=0, sanitized=0, parts=ACU.Parts, part_errors=ACU.PartErrors,
    note="Native gameplay/network/security callbacks untouched; server ban cannot be removed by Lua"}
end
function ACU.Stop()
  ACU.Installed=false
  _G.__ACU_FULL_LOADED=false
  print("[ACU] Diagnostic stopped; no network hooks were installed")
end
ACU.Apply()
return ACU
