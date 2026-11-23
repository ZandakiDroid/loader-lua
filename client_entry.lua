_G.Net = _G.ScriptHelperNetInterface
_G.Client = _G.ScriptHelperClient
_G.Tss = _G.TssManager
if not Client then
  return
end
require("client.slua.logic.HDmpveRemote.HDmpveRemote")
slua.RegCustomErrorTraceback()
if IsEditor or IsWoWEditor and Client.IsDevelopment() then
  GameInstanceID = GameInstanceID or 0
  if _G.IsEnableMockGameSvr then
    GameInstanceID = GameInstanceID + 1
  end
  require("blacklist.LuaPanda").start("127.0.0.1", 8818 + GameInstanceID)
end

function Client.GetTable(...)
  error("Use CDataTable.GetTable instead!")
end

function Client.GetTableData(...)
  error("Use CDataTable.GetTableData instead!")
end

Client.bEditorSkipDownload = IsEditor and not Client.IsSplitMapPakVersion()
if not Client.IsShipping() then
else
  function assert(condition, msg)
    if not condition then
      msg = msg or "assertion failed!"
      
      local utility = require("common.utility")
      utility.ErrorMessageHandler(msg)
      return false
    end
    return true
  end
end
local GisInWaiting = false
require("client.config.global")
require("common.log")
require("common_ustruct")
require("client.common.game_status")
require("common.gc_util")
require("client.slua.config.sound_config")
require("client.logic.ClientEntry.require_old_files")
if Client.IsDevelopment() then
  require("client.logic.gm.RequireBlackList")
  local LuaAPITimeTracer = RequireBlackList("blacklist.editor.runtime_check.LuaAPITimeTracer")
  if LuaAPITimeTracer then
    log(bWriteLog and "Client_entry StartTracer")
    LuaAPITimeTracer.StartTracer()
  end
end
if not Client.IsReleaseVersion(NetInterface) then
  require("blacklist.tools.ScreenShotReport.ScreenShotReport")
end
_G.UnrealNet = UnrealNet or {}
_G.NetUtil = NetUtil or {
  s2cNeedWaiting = {},
  tNetDisconnected = 0,
  tNetConnecting = 0,
  tNetConnected = 0,
  nDSTimeOutShowBitMask = 0,
  DSTimeOutLong = 1,
  DSTimeOutShort = 2,
  NetUnstableReport = {
    Enabled = false,
    HistoryMaxSize = 128,
    History = {},
    HistoryHeadIndex = 1,
    HistoryCount = 0,
    LastRecordedUnstable = nil
  }
}
local EventSystem = require("client.common.event.EventSystem")
local xpcall = _ENV.xpcall
local utility = require("common.utility")
local xpcallHandle = utility.ErrorMessageHandler
local TimeUtil = require("client.common.time_util")
local EmulatorSystem = require("client.logic.login.logic_emulator")
local NetManager = require("client.network.comm.NetManager")
local NetHeartBeatHandler = require("client.network.Protocol.NetHeartBeatHandler")
local PublishRegionMacros = require("client.slua.config.ClientMacros.PublishRegionMacros")
NetUtil.ConnectSDKTimeOutSeconds = 15
NetUtil.ConnectLuaTimeOutSeconds = 20
NetUtil.SendTime = NetUtil.SendTime or 0
NetUtil.SendOneTime = NetUtil.SendOneTime or 0
NetUtil.LobbyDelaySendTime = NetUtil.LobbyDelaySendTime or 0
NetUtil.LobbyDelayRecvTime = NetUtil.LobbyDelayRecvTime or 0
NetUtil.gameTick = NetUtil.gameTick or false
NetUtil.showConnectionMsgTimes = NetUtil.showConnectionMsgTimes or 0
NetUtil.hasTryConnectForNetworkError = NetUtil.hasTryConnectForNetworkError or false
NetUtil.hasTryConnectForNetworkErrorTimes = NetUtil.hasTryConnectForNetworkErrorTimes or 0
NetUtil.isWattingDelayReconnect = NetUtil.isWattingDelayReconnect or false
NetUtil.checkWaitingReEnterGameNotify = NetUtil.checkWaitingReEnterGameNotify or false
NetUtil.waitingReEnterGameStartTime = NetUtil.waitingReEnterGameStartTime or 0
NetUtil.checkConnectingInFighting = false
NetUtil.checkConnectingInFightingTimes = 0
NetUtil.checkConnectingInFightingRandomInterval = 0
NetUtil.waitingConnectSuccessStartTime = NetUtil.waitingConnectSuccessStartTime or 0
NetUtil.checkEnterBattle = false
NetUtil.waitingEnterBattleStartTime = NetUtil.waitingEnterBattleStartTime or 0
NetUtil.LoadingTimeOut = 70
NetUtil.EnterBattleLoadingTime = 0
NetUtil.checkLoginOtherLobbyServer = false
NetUtil.checkLoginRsp = NetUtil.checkLoginRsp or false
NetUtil.checkLoginRetryTime = NetUtil.checkLoginRetryTime or 0
NetUtil.checkBattleLoginRetryTime = NetUtil.checkBattleLoginRetryTime or 0
NetUtil.sendLoginTime = NetUtil.sendLoginTime or 0
NetUtil.dsTimeOutRetryTimes = NetUtil.dsTimeOutRetryTimes or 0
NetUtil.dsTimeOutTipsUIShowing = NetUtil.dsTimeOutTipsUIShowing or false
NetUtil.CurTickTime = NetUtil.CurTickTime or 0
NetUtil.LastTickTime = NetUtil.LastTickTime or 0
NetUtil.needInitCentauriWhenLogin = NetUtil.needInitCentauriWhenLogin or false
NetUtil.noRefreshLogout = NetUtil.noRefreshLogout or false
NetUtil.LobbyResultMonitor = NetUtil.LobbyResultMonitor or {
  gameover = false,
  gamemode = "",
  lobbyReconnTimes = 0
}
NetUtil.ResultMonitorStarTime = 0
NetUtil.BResultMonitorOpen = false
NetUtil.BBattleResultRecieved = false
NetUtil.PleaseReloginTimer = nil
NetUtil.EnterBattleGameID = ""
NetUtil.STOP_CONNECT = false
NetUtil.EnterBattleTimeOutGameID = 0
NetUtil.EnterBattleStageDelegate = nil
NetUtil.EnterBattleTime = 0

function OnClientGameOver()
  local logic_enter_game = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_enter_game)
  local game_mode = logic_enter_game:GetSubModeId()
  log(bWriteLog and "OnClientGameOver  mapMode:" .. game_mode .. "NetUtil.BBattleResultRecieved:" .. tostring(NetUtil.BBattleResultRecieved))
  if NetUtil.BBattleResultRecieved then
    return
  end
  ResetResultMonitor()
  NetUtil.BResultMonitorOpen = true
  NetUtil.ResultMonitorStarTime = TimeUtil.OSTime()
  NetUtil.LobbyResultMonitor.gameover = true
  NetUtil.LobbyResultMonitor.gamemode = game_mode
end

function ResetResultMonitor()
  NetUtil.ResultMonitorStarTime = 0
  NetUtil.BResultMonitorOpen = false
  NetUtil.LobbyResultMonitor = {
    gameover = false,
    gamemode = 0,
    lobbyReconnTimes = 0
  }
  log_tree("ClientEntry ----- ResetResultMonitor", NetUtil.LobbyResultMonitor)
end

function UpdateResultMonitor()
  if not NetUtil.BResultMonitorOpen then
    return
  end
  if not NetUtil.LobbyResultMonitor then
    return
  end
  if not NetUtil.LobbyResultMonitor.gameover then
    return
  end
  if TimeUtil.OSTime() - NetUtil.ResultMonitorStarTime < 2 then
    return
  end
  NetUtil.ResultMonitorStarTime = TimeUtil.OSTime()
  NetUtil.LobbyResultMonitor.lobbyReconnTimes = NetUtil.LobbyResultMonitor.lobbyReconnTimes + 1
  if NetUtil.LobbyResultMonitor.lobbyReconnTimes < 5 then
    return
  end
  if Client.IsEditorDedicatedServer() then
    log(bWriteLog and "ClientEntry ----- UpdateResultMonitor IsEditorDedicatedServer return")
    return
  end
  log(bWriteLog and "ClientEntry ----- UpdateResultMonitor  Force back to lobby")
  local strTile = LocUtil.GetLocalizeResStr(102012)
  local strMsg = LocUtil.GetLocalizeResStr(77010)
  local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
  CommonMsgBoxMgr.Show(1, strTile, strMsg, function()
    if GameStatus.IsInFightingStatus() then
      FuncUtil.ShowLoadingToLobby()
      Client.ReturnToLobby(GameFrontendHUD)
      Client.TPerforPlatDisconnectReport(GameFrontendHUD, 17)
      local param = {}
      NetUtil.GEMReportSubEvent("NoConnectWhenResult", param)
      local ClientTLogManager = SubsystemMgr:Get("ClientTLogManager")
      if ClientTLogManager then
        local Data = {}
        ClientTLogManager:SendReportLobby("NoConnectWhenResult", Data, false)
      end
    end
  end)
  ResetResultMonitor()
  return
end

function Tick(DeltaTime)
  NetUtil.CurTickTime = NetUtil.CurTickTime + DeltaTime
  TimeUtil.nLocalTimeTick = TimeUtil.nLocalTimeTick + DeltaTime
  if NetUtil.CurTickTime - NetUtil.LastTickTime > 5 then
    NetUtil.LastTickTime = NetUtil.CurTickTime
  end
  NetUtil.CheckTime()
  NetUtil.OnTick(TimeUtil.OSTime())
  EmulatorSystem.Tick(DeltaTime)
end

function NetUtil.GEMReportSubEvent(SubEventName, array)
  return Client.GEMReportSubEvent(GameFrontendHUD, "BattleNetworkEvent", SubEventName, array)
end

function NetUtil.DispatchPacket(msg, ...)
  local proc = NetManager.ProcRespondMsg
  if not proc then
    log_error(string.format("undefined msg: %s", msg))
    return
  end
  xpcall(proc, xpcallHandle, msg, ...)
end

function NetUtil.SendTss()
  if Tss then
    Tss.SendSkdData(LuaStateWrapper, NetInterface, "on_recv_client_data")
  else
    log_shipping_client("NetUtil.SendTss Tss is nil")
  end
end

function NetUtil.OnTssRsp(datalen, data)
  if Tss then
    Tss.OnRecvData(datalen, data)
  else
    log_shipping_client("NetUtil.OnTssRsp Tss is nil")
  end
end

local function FindInvalidArchiveType(value, path, depth)
  local t = type(value)
  if t == "number" or t == "string" or t == "boolean" or t == "nil" then
    return nil
  elseif t == "table" then
    if 32 < depth then
      return (path or "?") .. " (table too deep)"
    end
    for k, v in pairs(value) do
      local kt = type(k)
      if kt ~= "number" and kt ~= "string" then
        return string.format("%s[<key type=%s>]", path or "?", kt)
      end
      local bad = FindInvalidArchiveType(v, (path or "") .. "." .. tostring(k), depth + 1)
      if bad then
        return bad
      end
    end
    return nil
  else
    return string.format("%s (type=%s)", path or "?", t)
  end
end

function NetUtil.SendPkg(msgName, ...)
  if NetManager and NetManager.isLogMsgAfterLogin then
    if NetManager.logMsgMap[msgName] then
      NetManager.logMsgMap[msgName] = NetManager.logMsgMap[msgName] + 1
    else
      NetManager.logMsgMap[msgName] = 1
    end
  end
  local nArgs = select("#", ...)
  for i = 1, nArgs do
    local arg = select(i, ...)
    local bad = FindInvalidArchiveType(arg, "arg" .. i, 0)
    if bad then
      log_error(string.format([[
NetUtil.SendPkg drop pkg msg=%s invalid archive type at %s
%s]], tostring(msgName), bad, debug and debug.traceback and debug.traceback("", 2) or ""))
      return
    end
  end
  if Client.IsConnected(NetInterface) then
    Net.SendPacket(LuaStateWrapper, NetInterface, msgName, ...)
  else
    log_shipping_client("ClientEntry -----  connection is failed throw pkg " .. msgName)
  end
end

function NetUtil.ConnectToURL(ip)
  if not ip then
    return
  end
  if Client.IsDevelopment() and NetUtil.STOP_CONNECT then
    log(bWriteLog and "NetUtil.ConnectToURL SWITCH TEST RETURN")
    return
  end
  local EnableDNS = HDmpveRemote.HDmpveRemoteConfigGetString("HTTPDNS", "")
  if EnableDNS ~= "EnableHTTPDNS" then
    return NetUtil.ConnectToURLDirectly(ip)
  else
    return NetUtil.ConnectToURLWithDNSProxy(ip)
  end
end

function NetUtil.ConnectToURLDirectly(ip)
  log(bWriteLog and "NetUtil.ConnectToURLDirectly, url = " .. tostring(ip) .. ", time = " .. tostring(TimeUtil.OSTime()))
  log_shipping_client("[Login process] NetUtil.ConnectToURL " .. ", time" .. tostring(TimeUtil.OSTime()))
  NetUtil.SetWindowEditorLoginTokenIndex()
  Client.ConnectToURL(NetInterface, ip, NetUtil.ConnectSDKTimeOutSeconds)
  local logic_lobby_ping_report = require("client.slua.logic.match.logic_lobby_ping_report")
  logic_lobby_ping_report.OnSendConnectToURL()
end

function NetUtil.SetWindowEditorLoginTokenIndex()
  local DevicePlatformNameMacros = require("client.slua.config.ClientMacros.DevicePlatformNameMacros")
  if DevicePlatformNameMacros.IsPC() then
    local IMSDKHelper = import("IMSDKHelper")
    local IMSDKHelperInstance = IMSDKHelper.GetInstance()
    if IMSDKHelperInstance.SetWindowEditorLoginTokenIndex then
      IMSDKHelperInstance:SetWindowEditorLoginTokenIndex(GameInstanceID)
    end
  end
end

function NetUtil.ConnectToURLWithDNSProxy(ip)
  local DNSServerIP = HDmpveRemote.HDmpveRemoteConfigGetString("HTTPDNSServerIP", "")
  Client.ConnectToURLWithDNSProxy(NetInterface, DNSServerIP, ip, NetUtil.ConnectSDKTimeOutSeconds)
  local logic_lobby_ping_report = require("client.slua.logic.match.logic_lobby_ping_report")
  logic_lobby_ping_report.OnSendConnectToURL()
end

function NetUtil.Disconnect()
  log_shipping_client("ClientEntry ----- NetUtil.Disconnect()")
  Client.Disconnect(NetInterface)
end

function NetUtil.MountPakOfMode(sub_mode, ugc_map_id)
  local MatchModeMgrSystem = require("client.slua.logic.match.logic_mode_mgr")
  local mapKey = MatchModeMgrSystem.GetMapKeyBySubMode(sub_mode, ugc_map_id)
  local PufferTlog = require("client.slua.logic.download.report.puffer_tlog")
  log(bWriteLog and "SubMode: " .. tostring(sub_mode))
  Client.AddAttachFileString("mountmodpaks", true, "sub_mode:" .. tostring(sub_mode) .. " mapKey:" .. tostring(mapKey))
  if mapKey then
    local mapFiles = {}
    local PufferMapManager = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_map_manager)
    mapFiles = PufferMapManager:GetDependMapFiles(mapKey, sub_mode, ugc_map_id)
    for i in pairs(mapFiles) do
      log(bWriteLog and string.format("NetUtil.MountPakOfMode mapFileName:%s", i))
    end
    local mapKeys = {}
    if mapFiles and next(mapFiles) then
      for filename, key in pairs(mapFiles) do
        mapKeys[key] = true
        local path = Client.ProjectSavedDir() .. "Paks/" .. filename
        if not Client.IsFileExistsWithOutPakCheck(path) then
          PufferTlog.SendTLog(PufferTlog.Enum_TLog_From.MissingPak, PufferTlog.Enum_TLog_Optype.Finish, filename)
          local mountResult = " Path:" .. path .. " not exist!"
          Client.AddAttachFileString("mountmodpaks", false, mountResult)
          local StringUtil = require("common.string_util")
          local splits = StringUtil.Split(filename, ".")
          if splits[1] and splits[2] then
            local pre = splits[1] .. "." .. splits[2]
            local ret = GCPufferDownloader.ReturnLocalFiles(PufferDownloader.DOWNLOAD_DIR_RELATIVE, "")
            local replaceFileName = ""
            for _, localFileName in pairs(ret) do
              if string.find(localFileName, pre) and (replaceFileName == "" or localFileName > replaceFileName) then
                replaceFileName = localFileName
              end
            end
            if replaceFileName ~= "" then
              path = Client.ProjectSavedDir() .. "Paks/" .. replaceFileName
              if not Client.IsMounted(path) then
                Client.MountPakFile(path, "")
              end
            end
          end
        else
          local mountResult = " Path:" .. path
          if not Client.IsMounted(path) then
            local success = Client.MountPakFile(path, "")
            log(bWriteLog and "Start to mount " .. tostring(path) .. tostring(success))
            mountResult = mountResult .. " mounted " .. tostring(success)
            Client.AddAttachFileString("mountmodpaks", false, mountResult)
          else
            log(bWriteLog and "Already mounted " .. tostring(path))
            mountResult = mountResult .. " Already mounted."
            Client.AddAttachFileString("mountmodpaks", false, mountResult)
          end
        end
      end
    end
    PufferMapManager:MountFeaturesODPak(mapKey, sub_mode)
    PufferMapManager:RecordDynamicPaks(mapKeys)
  end
  local AkGameplayStatics = import("AkGameplayStatics")
  AkGameplayStatics.RefreshModDirectories()
end

function NetUtil.EnterBattleStandAlone(GameFrontendHUD, map_path, _player_key, nickName, sub_mode, dynamiclevels_op, AdditionalURLSuffixes)
  if AdditionalURLSuffixes == nil then
    AdditionalURLSuffixes = ""
  else
    local AdditionalURLSuffixesHead = "?"
    if AdditionalURLSuffixes:sub(1, 1) ~= AdditionalURLSuffixesHead then
      AdditionalURLSuffixes = AdditionalURLSuffixesHead .. AdditionalURLSuffixes
    end
  end
  NetUtil.MountPakOfMode(sub_mode)
  _G.ModeID = sub_mode
  local ScriptHelperClient = import("ScriptHelperClient")
  ScriptHelperClient.EnterBattleStandAlone(GameFrontendHUD, map_path, _player_key, nickName, dynamiclevels_op, AdditionalURLSuffixes, sub_mode)
  local UIUtil = require("client.common.ui_util")
  if UIUtil.GetGameFrontendHUD() ~= nil then
    UIUtil.GetGameFrontendHUD():SetGameSubMode(tostring(sub_mode))
  end
end

function NetUtil.SetEnterBattleGameID(InGameID)
  if InGameID ~= nil and NetUtil.EnterBattleGameID ~= InGameID then
    NetUtil.EnterBattleGameID = InGameID
    log_shipping_client("LogBattleNetFlow,  GameId: " .. tostring(InGameID))
  end
end

function NetUtil.OnConnected(isConnected, nReason)
  if _G.IsEnableMockGameSvr then
    log(bWriteLog and "NetUtil.OnConnected(IsEnableMockGameSvr)")
    return
  end
  local logic_lobby_ping_report = require("client.slua.logic.match.logic_lobby_ping_report")
  logic_lobby_ping_report.OnReceiveConnected(isConnected)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  log(bWriteLog and "NetUtil.OnConnected, isConnected = " .. tostring(isConnected) .. ", reason = " .. tostring(nReason) .. ", status = " .. GameStatus.GetGameStatus() .. ", ReceivedSyncBaseInfo = " .. tostring(login_module.bIsInitLogin))
  log_shipping_client("[Login process] ClientEntry -----  NetUtil.OnConnected " .. tostring(isConnected) .. ", nReason: " .. nReason .. ", isInitLogin:" .. tostring(login_module.bIsInitLogin))
  if not isConnected then
    local IntlHelper = import("IntlHelper")
    IntlHelper.AddErrorCodeToHistory(string.format("connect-%s", tostring(nReason)))
    local PlayerPrefsSystem = require("client.logic.LogicPlayerPrefs.playerprefs")
    local info = {reason = nReason}
    PlayerPrefsSystem.SaveTableToFile_N(info, PlayerPrefsSystem.ePlayerPrefsType.eLoginHDmpveErr)
  end
  if Client.SetTssNetworkStatus ~= nil then
    if isConnected then
      Client.SetTssNetworkStatus(GameFrontendHUD, 0)
    elseif nReason == 100 then
      Client.SetTssNetworkStatus(GameFrontendHUD, nReason)
    end
  end
  local ban_login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.ban_login_module)
  local bKickOutSelf = ban_login_module.hasKickOut or login_module.bHasLogout or NetUtil.checkLoginOtherLobbyServer
  if isConnected == false and (GameStatus.GetGameStatus() == GameStatus.Login or GameStatus.IsInLobbyOrMainCity()) and bKickOutSelf == false then
    if login_module:reconnectGateway() then
      log(bWriteLog and "ClientEntry -----  LoginSystem.reconnectGateway()")
      return
    else
      Client.GEMReportEnterLobbyEvent(GameFrontendHUD, false, "reconnect backup server failed, errorcode:" .. tostring(nReason))
    end
  elseif isConnected == false and bKickOutSelf == false then
    Client.GEMReportEnterLobbyEvent(GameFrontendHUD, false, tostring(nReason))
  end
  if not NetUtil.checkLoginOtherLobbyServer then
    logic_connection_waiting:Hide(1)
  end
  NetManager.ProcConnected(isConnected)
  local nowTime = TimeUtil.GetServerTimeInSec()
  if isConnected then
    log(bWriteLog and "ClientEntry ----- NetUtil.OnConnected step isConnected")
    log(bWriteLog and string.format("ClientEntry ----- NetUtil.OnConnected nowTime = %s", TimeUtil.FormatTime_YMDHMS(nowTime)))
    NetUtil.hasTryConnectForNetworkError = false
    NetUtil.hasTryConnectForNetworkErrorTimes = 0
    if GisInWaiting then
      log(bWriteLog and "ClientEntry ----- is in LoginSystem.GisInWaiting")
      local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
      CommonMsgBoxMgr.HideAllPanel()
    end
    local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
    log(bWriteLog and "ClientEntry ----- Close ConnectionMessageBoxUI!!!!")
    CommonMsgBoxMgr.HideConnectionPanel()
    local LogicFitVersionDownload = require("client.slua.logic.download.fit.logic_fitVersion_download")
    LogicFitVersionDownload.TryReshowDeleteRestartHint("OnConnected")
    if ban_login_module.hasKickOut then
      NetUtil.gameTick = false
    else
      if Client.IsMatchNoAuthMode and Client.IsMatchNoAuthMode() then
        if login_module.bIsInitLogin == false and GameStatus.GetGameStatus() == GameStatus.Login then
          login_module:competition_login_res(true)
        else
          login_module:TryNoAuthRelogin()
        end
      else
        login_module:OnConnected(NetUtil.ConnectReason)
        NetUtil.ConnectReason = nil
      end
      NetUtil.ClearAutoReconnectParam()
      NetUtil.gameTick = true
    end
    NetUtil.showConnectionMsgTimes = 0
    NetUtil.SendTime = TimeUtil.OSTime()
    NetUtil.LobbyDelaySendTime = TimeUtil.GetMiliseconds()
    NetUtil.LobbyDelayRecvTime = TimeUtil.GetMiliseconds()
    NetUtil.s2cNeedWaiting = {}
    NetUtil.checkConnectingInFighting = false
    NetUtil.checkConnectingInFightingTimes = 0
    log(bWriteLog and "ClientEntry ----- NetUtil.OnConnected step isConnected EVENTID_LOBBY_SERVER_CONNECT_SUCCESS")
    EventSystem:postEvent(EVENTTYPE_NETWORK, EVENTID_LOBBY_SERVER_CONNECT_SUCCESS)
  else
    local login_protect_utils = require("client.slua.logic.login.login_protect_utils")
    login_protect_utils.RecordLoginFailTime()
    log_shipping_client("ClientEntry ----- NetUtil.OnConnected Failed curStatus = " .. GameStatus.GetGameStatus() .. " for reason = " .. nReason)
    EventSystem:postEvent(EVENTTYPE_NETWORK, EVENTID_LOBBY_SERVER_CONNECT_FAILED)
    if ban_login_module.hasKickOut or login_module.bHasLogout or NetUtil.checkLoginOtherLobbyServer then
      log_format("ClientEntry ----- NetUtil.OnConnected kickout or logout state! hasKickOut:%s, hasLogout:%s, checkLoginOtherLobbyServer:%s", ban_login_module.hasKickOut, login_module.bHasLogout, NetUtil.checkLoginOtherLobbyServer)
      log_shipping_client("ClientEntry ----- NetUtil.OnConnected tryConnectLobby failed is in kickout or logout state! hasKickOut:" .. tostring(ban_login_module.hasKickOut) .. ", hasLogout:" .. tostring(login_module.bHasLogout))
      NetUtil.gameTick = false
      return
    end
    local errorMsg = FuncUtil.GetHDmpveErrorMsg(nReason)
    local isInFightingNotSocialNotMainCityNotHome = GameStatus.IsInFightingNotSocialNotMainCityNotHome()
    log_format("NetUtil.OnConnected IsInFightingNotSocialNotMainCityNotHome = %s", isInFightingNotSocialNotMainCityNotHome)
    if isInFightingNotSocialNotMainCityNotHome then
      if not NetUtil.checkConnectingInFighting then
        NetUtil.checkConnectingInFighting = true
        NetUtil.waitingConnectSuccessStartTime = TimeUtil.OSTime()
        log(bWriteLog and "ClientEntry ----- NetUtil.OnConnected waitingConnectSuccessStartTime:" .. NetUtil.waitingConnectSuccessStartTime)
      end
    else
      local gclould_error_define = require("client.common.gclould_error_define")
      if nReason == -1 or nReason == gclould_error_define.GCLOULD_ErrorNetworkException or nReason == gclould_error_define.GCLOULD_ErrorTimeout or nReason == gclould_error_define.GCLOULD_ErrorChecking or nReason == gclould_error_define.GCLOULD_ErrorConnectFailed then
        if not NetUtil.AutoReconnectParam then
          NetUtil.AutoReconnectParam = NetUtil.GetAutoReconnectParam()
          if NetUtil.AutoReconnectParam.showFunc then
            NetUtil.AutoReconnectParam.showFunc()
          end
        end
        log_format("ClientEntry ----- NetUtil.OnConnected AutoReconnectTimes = %s, hasTryConnectForNetworkErrorTimes = %s nowTime = %s", NetUtil.AutoReconnectParam.times, NetUtil.hasTryConnectForNetworkErrorTimes, TimeUtil.FormatTime_YMDHMS(nowTime))
        if NetUtil.hasTryConnectForNetworkErrorTimes < NetUtil.AutoReconnectParam.times then
          log(bWriteLog and "ClientEntry ----- After Connect Failed For Newwork Try Connect One Time......")
          if NetUtil.isWattingDelayReconnect == false then
            NetUtil.isWattingDelayReconnect = true
            NetUtil.ClearAutoReconnectTimer()
            NetUtil.hasTryConnectForNetworkErrorTimes = NetUtil.hasTryConnectForNetworkErrorTimes + 1
            local timer_ticker = require("common.time_ticker")
            NetUtil.autoReconnectTimer = timer_ticker.AddTimerOnce(1, function()
              log(bWriteLog and "ClientEntry ----- NetUtil.OnConnected Auto Reconnect Timer handler")
              NetUtil.tryConnect(Enum_LOGIN_REPORT_CFG.NET_CONNECT_ERR)
              NetUtil.isWattingDelayReconnect = false
            end)
          end
        else
          NetUtil.ClearAutoReconnectParam()
          log(bWriteLog and "ClientEntry ----- Show ConnectingErrorMsg ......")
          NetUtil.showConnectionMsgTimes = NetUtil.showConnectionMsgTimes + 1
          NetUtil.ShowConnectionMsgBox(NetUtil.showConnectionMsgTimes, errorMsg)
        end
      else
        NetUtil.gameTick = false
        local strTile = LocUtil.GetLocalizeResStr(102012)
        if not login_module.bLoginNextRsp then
          local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
          CommonMsgBoxMgr.Show(1, strTile, errorMsg, function()
            if nReason == gclould_error_define.GCLOULD_ErrorAuthFailed then
              local SettingAccount = require("client.logic.setting.logic_setting_account")
              SettingAccount.ClientLogout()
            end
            login_module:backLogin()
          end, nil, nil, nil, true)
        end
      end
      ResetResultMonitor()
    end
  end
  local param = {}
  table.insert(param, isConnected)
  table.insert(param, nReason)
  EventSystem:postEvent(EVENTTYPE_NETWORK, EVENTID_CONNECTED, param)
end

function NetUtil.OnStateChange(state, param1, param2, param3)
  log_shipping_client("ClientEntry ----- OnStateChange State:" .. state .. ", Param1:" .. param1 .. ", Param2:" .. param2 .. ", Param3:" .. param3)
  if state == 0 then
    log(bWriteLog and "ClientEntry ----- HDmpve::Conn::kConnectorStateRunning")
  elseif state == 1 then
    log(bWriteLog and "ClientEntry ----- HDmpve::Conn::kConnectorStateReconnecting.......")
    NetUtil.ProcOnConnecting()
  elseif state == 2 then
    log(bWriteLog and "ClientEntry ----- HDmpve::Conn::kConnectorStateReconnected isConnect:" .. param1)
    NetUtil.ProcOnConnected()
    if NetUtil.CheckSpecialDeviceNetFlash() then
      log(bWriteLog and "NetUtil.OnStateChange check special device net flash")
      logic_connection_waiting:Hide(1)
    else
      NetUtil.OnConnected(param1 == 0, param1)
    end
  elseif state == 3 then
    log(bWriteLog and "ClientEntry ----- HDmpve::Conn::kConnectorStateStayInQueue")
    local queuePosition = param1
    local queueLength = param2
    local estimateTime = param3
    log(bWriteLog and string.format("Queue, current position:%d of total quque length:%d,estimateTime=%d", queuePosition, queueLength, estimateTime))
    GisInWaiting = true
    NetUtil.gameTick = false
    
    local function cancelWaiting()
      log(bWriteLog and "ClientEntry ----- cancelWaiting..")
      local login = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
      login:backLogin()
    end
    
    local timewait = math.floor(estimateTime / 60)
    local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
    CommonMsgBoxMgr.HideAllPanel()
    if not GameStatus.IsInFightingNotSocialNotMainCityNotHome() then
      local str = LocUtil.GetLocalizeResStr(301108)
      local str2 = LocUtil.GetLocalizeResStr(301109)
      local str3 = LocUtil.GetLocalizeResStr(110035)
      local text = string.format(str, queuePosition, timewait)
      CommonMsgBoxMgr.Show(1, str2, text, cancelWaiting, nil, str3)
    end
  elseif state == 4 then
    log(bWriteLog and "ClientEntry ----- HDmpve::Conn::kConnectorStateError ")
    NetUtil.ProcOnDisconnected()
    local errorCode = param1
    log(bWriteLog and "ClientEntry ----- errorCode == " .. errorCode)
    if errorCode == 2 then
      local AccelSystem = require("client.slua.logic.gamemaster.logic_accel")
      if AccelSystem.IsEnableAccel() then
        AccelSystem.Switch2FastMode()
      end
    end
    if errorCode == 207 or errorCode == 205 then
      log(bWriteLog and "ClientEntry ----- HDmpve::Conn::kErrorSendError")
      NetUtil.OnConnected(false, 201)
    else
      if param2 == 7 then
        log(bWriteLog and "ClientEntry ----- \229\144\142\229\143\176\228\184\187\229\138\168\229\176\134\229\174\162\230\136\183\231\171\175\232\184\162\228\184\139\231\186\191")
        log(bWriteLog and "ClientEntry ----- extendCodeOfGameSvr = " .. param3)
      else
        log(bWriteLog and "ClientEntry ----- extend = " .. param2 .. "extend2 = " .. param3)
      end
      NetUtil.OnConnected(false, errorCode)
    end
  end
end

function NetUtil.OnDisconnected(nReason)
  log_error("NetUtil.OnDisconnected nReason\239\188\154" .. nReason)
  log(bWriteLog and "ClientEntry ----- NetUtil.OnDisconnected nReason\239\188\154" .. nReason)
end

NET_UTIL_LOGIN_WAIT_TIME = 8

function NetUtil.CheckTime()
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  if NetUtil.checkLoginRsp and NetUtil.sendLoginTime > 0 and TimeUtil.OSTime() - NetUtil.sendLoginTime >= NET_UTIL_LOGIN_WAIT_TIME then
    if NetUtil.checkLoginRetryTime == 0 then
      log(bWriteLog and "ClientEntry -----  checkLoginRsp timeout!! " .. NetUtil.checkLoginRetryTime .. ", isRelogin:" .. tostring(login_module.bIsRelogin))
      local reportId = Enum_LOGIN_REPORT_CFG.RETRY
      if login_module.bLoginNextRsp then
        reportId = Enum_LOGIN_REPORT_CFG.LOGIN_NEXT
        login_module:SetbLoginNextRsp(false)
      end
      login_module:reqLoginLobby(login_module.bIsRelogin, reportId)
      NetUtil.checkLoginRetryTime = NetUtil.checkLoginRetryTime + 1
    else
    end
    if GameStatus.IsInFightingNotSocialNotMainCityNotHome() then
      if NetUtil.checkBattleLoginRetryTime == 0 or NetUtil.checkBattleLoginRetryTime == 2 or NetUtil.checkBattleLoginRetryTime == 5 then
        log(bWriteLog and "ClientEntry ----- tryConnect lobby in fighting when login failed")
        NetUtil.tryConnect(Enum_LOGIN_REPORT_CFG.NET_CONNECT_FRIGHT_TICK)
      end
      NetUtil.checkBattleLoginRetryTime = NetUtil.checkBattleLoginRetryTime + 1
    end
  end
  if NetUtil.checkEnterBattle and TimeUtil.OSTime() - NetUtil.waitingEnterBattleStartTime > NetUtil.LoadingTimeOut then
    local SmartBearerManagerLuaBridge = import("SmartBearerManagerLuaBridge")
    local bEnterBattleTimeOutExEnabled = false
    if SmartBearerManagerLuaBridge ~= nil then
      bEnterBattleTimeOutExEnabled = SmartBearerManagerLuaBridge.IsClientBackEndSwitcherBEnable(1)
    end
    if bEnterBattleTimeOutExEnabled then
      log(bWriteLog and "EnterBattleTimeOutEx Enabled.")
      local EnterBattleCurStage = ""
      local UIUtil = require("client.common.ui_util")
      if UIUtil ~= nil and UIUtil.GetGameFrontendHUD() ~= nil then
        EnterBattleCurStage = UIUtil.GetGameFrontendHUD():GetClientEnterBattleStage()
      end
      if (EnterBattleCurStage == "NMT_Welcome_Received" or EnterBattleCurStage == "LoadMapCompleted" or EnterBattleCurStage == "NetworkEstablished") and NetUtil.EnterBattleTimeOutGameID ~= g_game_id then
        NetUtil.EnterBattleTimeOutGameID = g_game_id
        NetUtil.LoadingTimeOut = NetUtil.LoadingTimeOut + 20
        log(bWriteLog and "EnterBattleTimeOutEx Processed.")
        return
      end
    end
    NetUtil.StopCheckEnterBattle()
    log(bWriteLog and "ClientEntry -----  checkEnterBattle timeout!! curStatus:" .. GameStatus.GetGameStatus() .. ", isWaittingEnterBattle:" .. tostring(LobbySystem.isWaittingEnterBattle))
    logic_connection_waiting:Hide(1)
    if LobbySystem.isWaittingEnterBattle then
      LobbySystem.SetWaitingBattleFlag(false)
      log(bWriteLog and "NetUtil.CheckTime - deanytjin test should add show mail 1")
      if GameStatus.IsInLobbyOrMainCity() then
        log(bWriteLog and "ClientEntry -----  checkEnterBattle timeout!! not ReturnToLobby")
        local LoadingSystem = require("client.slua.logic.loading.logic_loading")
        LoadingSystem.RefreshLoadPercent(1)
        if LobbySystem.is_DeathMatchMode then
          local TeamCompLoading = require("client.slua.logic.loading.logic_teamcomp_loading")
          TeamCompLoading.RefreshLoadPercent(1)
        end
        EventSystem:postEvent(EVENTTYPE_NETWORK, EVENTID_MAIN_CITY_ENTER_BATTLE_TIMEOUT)
      else
        local Lobby_Main_City_Enter = require("client.slua.logic.lobby.MainCity.Lobby_Main_City_Enter")
        Lobby_Main_City_Enter.bEnterGameFromMainCity = false
        Client.ReturnToLobby(GameFrontendHUD)
      end
      if not NetManager.bConnected and LobbySystem.CheckOpen(BP_ENUM_IS_QUERY_PLAYER_STETE_AFTER_LOADING) then
        login_module:reqLoginLobby(true, Enum_LOGIN_REPORT_CFG.LOAD_TIMEOUT)
      else
        local MatchSystem = require("client.slua.logic.match.logic_match")
        MatchSystem.SetQueryPlayerFlag(true)
      end
      UnrealNet.HandleNetworkExceptionReport("EnterBattleTimeout", "", "")
      local LogicGRomelink = require("client.slua.logic.gromelink.logic_grome_link")
      LogicGRomelink:OnEnterBattleResult(LogicGRomelink.ENUM_ENTER_GAME_RET.TIMEOUT)
      log_shipping_client("LogBattleNetFlow,  EnterBattleTimeout.")
    end
  end
  if NetUtil.checkWaitingReEnterGameNotify and 5 < TimeUtil.OSTime() - NetUtil.waitingReEnterGameStartTime then
    NetUtil.StopCheckDSActive()
    log(bWriteLog and "ClientEntry -----  checkWaitingReEnterGameNotify timeout!! curStatus:" .. GameStatus.GetGameStatus() .. ", isWaittingEnterBattle:" .. tostring(LobbySystem.isWaittingEnterBattle))
    logic_connection_waiting:Hide(1)
    local bReplayState = Client.IsInReplayState(GameFrontendHUD)
    if LobbySystem.isWaittingEnterBattle then
      LobbySystem.SetWaitingBattleFlag(false)
      log(bWriteLog and "NetUtil.CheckTime - deanytjin test should add show mail 2")
      if GameStatus.IsInLobbyOrMainCity() then
        log(bWriteLog and "ClientEntry -----  checkWaitingReEnterGameNotify timeout!! not ReturnToLobby true")
        local LoadingSystem = require("client.slua.logic.loading.logic_loading")
        LoadingSystem.RefreshLoadPercent(1)
        if LobbySystem.is_DeathMatchMode then
          local TeamCompLoading = require("client.slua.logic.loading.logic_teamcomp_loading")
          TeamCompLoading.RefreshLoadPercent(1)
        end
        return
      end
      Client.ReturnToLobby(GameFrontendHUD)
    elseif GameStatus.IsInFightingStatus() and not BattleResult.IgnoreDSError and not bReplayState then
      if GameStatus.IsInLobbyOrMainCity() then
        log(bWriteLog and "ClientEntry -----  checkWaitingReEnterGameNotify timeout!! not ReturnToLobby false")
        local LoadingSystem = require("client.slua.logic.loading.logic_loading")
        LoadingSystem.RefreshLoadPercent(1)
        if LobbySystem.is_DeathMatchMode then
          local TeamCompLoading = require("client.slua.logic.loading.logic_teamcomp_loading")
          TeamCompLoading.RefreshLoadPercent(1)
        end
        return
      end
      local strTile = LocUtil.GetLocalizeResStr(102012)
      local strMsg = ""
      local home_macros = require("client.slua.logic.home.home_macros")
      local Logic_PlanCHMacros = require("client.slua.logic.CollectionHall.Logic_PlanCHMacros")
      local sub_mode = tonumber(Client.GetGameModeID(GameFrontendHUD))
      if sub_mode == home_macros.Home_SubMode.Visit then
        strMsg = LocUtil.GetLocalizeResStr(655421)
      elseif sub_mode == Logic_PlanCHMacros.CollectionHall_SubMode.Visit then
        strMsg = LocUtil.GetLocalizeResStr(880060019)
      else
        strMsg = LocUtil.GetLocalizeResStr(77010)
      end
      local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
      CommonMsgBoxMgr.Show(1, strTile, strMsg, function()
        if GameStatus.IsInFightingStatus() then
          FuncUtil.ShowLoadingToLobby()
          Client.ReturnToLobby(GameFrontendHUD)
          Client.TPerforPlatDisconnectReport(GameFrontendHUD, 11)
        end
      end, nil, nil, nil, {isConnectionPanel = true})
    end
  end
  if NetUtil.checkConnectingInFighting then
    local interval = 0
    if NetUtil.checkConnectingInFightingTimes == 0 or NetUtil.checkConnectingInFightingTimes == 1 then
      interval = 5
    elseif NetUtil.checkConnectingInFightingTimes == 2 then
      interval = 10
    elseif NetUtil.checkConnectingInFightingTimes == 3 then
      interval = 15
    else
      interval = NetUtil.checkConnectingInFightingRandomInterval
    end
    if interval < TimeUtil.OSTime() - NetUtil.waitingReEnterGameStartTime then
      log(bWriteLog and "ClientEntry ----- tryConnect lobby in fighting!!! curTime:" .. TimeUtil.OSTime() .. ", startTime:" .. NetUtil.waitingReEnterGameStartTime .. ", interval:" .. interval)
      if not Client.IsConnected(NetInterface) and GameStatus.IsInFightingStatus() then
        local MatchModeMgrSystem = require("client.slua.logic.match.logic_mode_mgr")
        if MatchModeMgrSystem and MatchModeMgrSystem.IsSocialIslandMode(true) and NetUtil.checkConnectingInFightingTimes > 3 then
          local strTile = LocUtil.GetLocalizeResStr(102012)
          local strMsg = LocUtil.GetLocalizeResStr(301113)
          local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
          CommonMsgBoxMgr.Show(1, strTile, strMsg, function()
            FuncUtil.ShowLoadingToLobby()
            Client.ReturnToLobby(GameFrontendHUD)
            if not NetManager.bConnected and LobbySystem.CheckOpen(BP_ENUM_IS_QUERY_PLAYER_STETE_AFTER_LOADING) then
              login_module:reqLoginLobby(true, Enum_LOGIN_REPORT_CFG.SOCIAL_ISLAND)
            else
              local MatchSystem = require("client.slua.logic.match.logic_match")
              MatchSystem.SetQueryPlayerFlag(true)
            end
            logic_connection_waiting:Hide(1)
          end, nil, nil, nil, {isConnectionPanel = true})
        else
          NetUtil.checkConnectingInFightingTimes = NetUtil.checkConnectingInFightingTimes + 1
          NetUtil.tryConnect(Enum_LOGIN_REPORT_CFG.NET_CONNECT_FRIGHT)
          NetUtil.checkConnectingInFightingRandomInterval = math.random(30, 40)
        end
      else
        log(bWriteLog and "ClientEntry -----  stop checkConnectingInFighting")
        NetUtil.checkConnectingInFighting = false
        NetUtil.waitingReEnterGameStartTime = 0
        NetUtil.checkConnectingInFightingTimes = 0
      end
      NetUtil.waitingReEnterGameStartTime = TimeUtil.OSTime()
    end
  end
  UpdateResultMonitor()
end

function NetUtil.StopCheckLoginOtherLobbyServer()
  log(bWriteLog and "ClientEntry -----  StopCheckLoginOtherLobbyServer")
  if NetUtil.checkLoginOtherLobbyServer then
    logic_connection_waiting:Hide(1)
  end
  log_warning(bWriteLog and "NetUtil.StopCheckLoginOtherLobbyServer checkLoginOtherLobbyServer false")
  NetUtil.checkLoginOtherLobbyServer = false
end

function NetUtil.OnEnterBattleStageDelegate(InStage)
  local loading_macro = require("client.slua.logic.loading.loading_macro")
  local CurStagePercent = loading_macro.EnterBattleStagePercentMap[InStage]
  if CurStagePercent ~= nil then
    log(bWriteLog and "NetUtil.OnEnterBattleStageDelegate Stage: " .. InStage .. ", percent: " .. tostring(CurStagePercent))
    local LoadingSystem = require("client.slua.logic.loading.logic_loading")
    LoadingSystem.RefreshLoadPercent(CurStagePercent, true)
    if LobbySystem.is_DeathMatchMode == true then
      log(bWriteLog and "NetUtil.OnEnterBattleStageDelegate RefreshLoadPercent:exported" .. tostring(CurStagePercent))
      local TeamCompLoading = require("client.slua.logic.loading.logic_teamcomp_loading")
      TeamCompLoading.RefreshLoadPercent(CurStagePercent, true)
    end
  else
    log(bWriteLog and "NetUtil.OnEnterBattleStageDelegate Stage is nil, " .. InStage)
  end
end

function NetUtil.OnEnterBattleStageDelegate_MainCity(InStage)
  log(bWriteLog and "NetUtil.OnEnterBattleStageDelegate_MainCity Stage: " .. tostring(InStage))
  local loading_macro = require("client.slua.logic.loading.loading_macro")
  local CurStagePercent = loading_macro.EnterBattleStagePercentMap[InStage]
  log(bWriteLog and "NetUtil.OnEnterBattleStageDelegate_MainCity CurStagePercent: " .. tostring(CurStagePercent))
end

function NetUtil.BindEnterBattleStageDelegate(sub_mode)
  log(bWriteLog and "NetUtil.BindEnterBattleStageDelegate sub_mode: " .. tostring(sub_mode))
  NetUtil.RemoveEnterBattleStageDelegate()
  if NetUtil.EnterBattleStageDelegate == nil then
    local UIUtil = require("client.common.ui_util")
    local GameFrontHUD = UIUtil.GetGameFrontendHUD()
    if GameFrontHUD ~= nil then
      local Lobby_Main_City = require("client.slua.logic.lobby.MainCity.Lobby_Main_City")
      if Lobby_Main_City.IsMainCitySubMode(sub_mode) then
        NetUtil.EnterBattleStageDelegate = GameFrontHUD.EnterBattleStageDelegate:Add(function(InStage)
          NetUtil.OnEnterBattleStageDelegate_MainCity(InStage)
        end)
      else
        NetUtil.EnterBattleStageDelegate = GameFrontHUD.EnterBattleStageDelegate:Add(function(InStage)
          NetUtil.OnEnterBattleStageDelegate(InStage)
        end)
      end
      log(bWriteLog and "ClientEntry ----- NetUtil.BindEnterBattleStageDelegate")
    end
  end
end

function NetUtil.RemoveEnterBattleStageDelegate()
  log(bWriteLog and "NetUtil.RemoveEnterBattleStageDelegate")
  if NetUtil.EnterBattleStageDelegate ~= nil then
    local UIUtil = require("client.common.ui_util")
    local GameFrontHUD = UIUtil.GetGameFrontendHUD()
    if GameFrontHUD ~= nil then
      GameFrontHUD.EnterBattleStageDelegate:Remove(NetUtil.EnterBattleStageDelegate)
    end
    NetUtil.EnterBattleStageDelegate = nil
    log(bWriteLog and "ClientEntry ----- NetUtil.RemoveEnterBattleStageDelegate")
  end
end

function NetUtil.StartCheckLoginRsp()
  log(bWriteLog and "ClientEntry ----- NetUtil.StartCheckLoginRsp......")
  NetUtil.checkLoginRsp = true
  NetUtil.sendLoginTime = TimeUtil.OSTime()
end

function NetUtil.StopCheckLoginRsp()
  log(bWriteLog and "ClientEntry ----- NetUtil.StopCheckLoginRsp!!!!!")
  NetUtil.checkLoginRsp = false
  NetUtil.sendLoginTime = 0
  NetUtil.checkLoginRetryTime = 0
  if 0 < NetUtil.checkBattleLoginRetryTime then
    local realRetryTime = 1
    if NetUtil.checkBattleLoginRetryTime > 2 then
      realRetryTime = 2
    elseif NetUtil.checkBattleLoginRetryTime > 5 then
      realRetryTime = 3
    end
    local param = {realRetryTime}
    NetUtil.GEMReportSubEvent("ReonnectAfterLoginFail", param)
  end
  NetUtil.checkBattleLoginRetryTime = 0
  NetUtil.bIsTimeOutReconnect = 0
end

function NetUtil.StartCheckDSActive()
  log(bWriteLog and "NetUtil.StartCheckDSActive")
  local curStatus = LuaClassObj.GetGameStatus(bp_global)
  log(bWriteLog and "ClientEntry -----  StartCheckDSActive isWaittingEnterBattle: " .. tostring(LobbySystem.isWaittingEnterBattle) .. ", curStatus: " .. curStatus)
  if LobbySystem.isWaittingEnterBattle and NetUtil.EnterBattleTime > 0 and 0 < NetUtil.waitingEnterBattleStartTime and NetUtil.EnterBattleTime >= NetUtil.waitingEnterBattleStartTime then
    log(bWriteLog and "NetUtil.EnterBattleTime >= NetUtil.waitingEnterBattleStartTime, Skip StartCheckDSActive.")
    return
  end
  local dsNetState = Client.GetUnrealNetworkStatus(GameFrontendHUD)
  if (LobbySystem.isWaittingEnterBattle or curStatus == GameStatus.Fighting) and dsNetState ~= "Online" and NetUtil.checkWaitingReEnterGameNotify == false then
    NetUtil.checkWaitingReEnterGameNotify = true
    NetUtil.waitingReEnterGameStartTime = TimeUtil.OSTime()
    log(bWriteLog and "ClientEntry -----  waitingReEnterGameStartTime:" .. NetUtil.waitingReEnterGameStartTime)
  end
end

function NetUtil.StopCheckDSActive()
  log(bWriteLog and "ClientEntry -----  StopCheckDSActive")
  NetUtil.checkWaitingReEnterGameNotify = false
  NetUtil.waitingReEnterGameStartTime = 0
end

function NetUtil.StartCheckEnterBattle(sub_mode)
  if LobbySystem.isWaittingEnterBattle then
    NetUtil.checkEnterBattle = true
    NetUtil.waitingEnterBattleStartTime = TimeUtil.OSTime()
    local SubModeCfg = CDataTable.GetTableData("BTMode", sub_mode)
    if SubModeCfg and SubModeCfg.LoadingTimeOut and SubModeCfg.LoadingTimeOut > 70 then
      NetUtil.LoadingTimeOut = SubModeCfg.LoadingTimeOut
    else
      NetUtil.LoadingTimeOut = 70
    end
    if Client.IsAsanVersion() then
      NetUtil.LoadingTimeOut = 1000
    end
    log(bWriteLog and "ClientEntry -----  waitingEnterBattleStartTime:" .. NetUtil.waitingEnterBattleStartTime)
    log(bWriteLog and "ClientEntry -----  LoadingTimeOut:" .. NetUtil.LoadingTimeOut)
    NetUtil.BindEnterBattleStageDelegate(sub_mode)
    if LobbySystem.is_DeathMatchMode == true then
      local TeamCompLoading = require("client.slua.logic.loading.logic_teamcomp_loading")
      TeamCompLoading.SetInitPercent(50)
    else
      local LoadingSystem = require("client.slua.logic.loading.logic_loading")
      LoadingSystem.SetInitPercent(50)
    end
  end
end

function NetUtil.StopCheckEnterBattle()
  log(bWriteLog and "ClientEntry -----  StopCheckEnterBattle EnterBattleLoadingTime:", NetUtil.EnterBattleLoadingTime)
  NetUtil.checkEnterBattle = false
  NetUtil.waitingEnterBattleStartTime = 0
  NetUtil.LoadingTimeOut = 70
  NetUtil.RemoveEnterBattleStageDelegate()
end

function NetUtil.OnTick(curTime)
  local ban_login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.ban_login_module)
  if ban_login_module.hasKickOut then
    return
  end
  if NetUtil.gameTick then
    if curTime - NetUtil.SendTime >= 5 then
      NetUtil.SendTime = curTime
      NetUtil.LobbyDelaySendTime = TimeUtil.GetMiliseconds()
      NetHeartBeatHandler.send_heart_beat(curTime)
    end
    if curTime - NetUtil.SendOneTime >= 1 then
      NetUtil.SendOneTime = curTime
      if LobbySystem.isInLobby then
        NetUtil.SendTss()
      end
    end
  end
end

function NetUtil.OnChangeLobbyServerNotify(relogin_seconds, reason)
  log(bWriteLog and "ClientEntry ----- OnChangeLobbyServerNotify relogin_seconds:" .. tostring(relogin_seconds) .. " reason:" .. tostring(reason))
  
  local function _migrate()
    log_warning(bWriteLog and "NetUtil.OnChangeLobbyServerNotify checkLoginOtherLobbyServer true")
    NetUtil.checkLoginOtherLobbyServer = true
    NetUtil.Disconnect()
    local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
    login_module:HandlemServerMigrationAndConnect()
  end
  
  local handleFunc = NetUtil.Please_Relogin_Req
  if reason and type(reason) == "string" and reason == "data-migration" then
    handleFunc = _migrate
  end
  if 0 < relogin_seconds then
    local time_ticker = require("common.time_ticker")
    if NetUtil.PleaseReloginTimer then
      time_ticker.RemoveTimer(NetUtil.PleaseReloginTimer)
      NetUtil.PleaseReloginTimer = nil
    end
    NetUtil.PleaseReloginTimer = time_ticker.AddTimerOnce(relogin_seconds, handleFunc)
  else
    handleFunc()
  end
end

function NetUtil.Please_Relogin_Req()
  log(bWriteLog and "ClientEntry ----- Please_Relogin_Req ~~~~~~~")
  log_warning(bWriteLog and "NetUtil.Please_Relogin_Req checkLoginOtherLobbyServer true")
  NetUtil.checkLoginOtherLobbyServer = true
  NetUtil.Disconnect()
  NetUtil.tryConnect(Enum_LOGIN_REPORT_CFG.NET_RELOGIN)
end

function NetUtil.OnHeartBeatRsp(now)
  TimeUtil.SetServerTimeInSec(now)
  NetUtil.LobbyDelayRecvTime = TimeUtil.GetMiliseconds()
end

function NetUtil.GetZoneValue()
  local ms = 10000
  local ZoneSystem = require("client.slua.logic.teamup.logic_zone")
  local zoneList = ZoneSystem.chooseZoneList
  local zoneID = ZoneSystem.nChooseZoneID
  if not (zoneID and zoneList) or #zoneList <= 0 then
    return ms
  end
  local ip = ""
  for _, v in ipairs(zoneList) do
    if zoneID == v.zone_id then
      ip = v.tpingsvr_ip
      break
    end
  end
  if ip ~= "" then
    local UDPPingCollector = slua_GameFrontendHUD.UDPPingCollector
    ms = UDPPingCollector:GetZoneServerDelay(ip)
  end
  if 10000 < ms then
    ms = 80
  end
  return ms
end

function NetUtil.IsGrowthGuideSubMode(sub_mode)
  local enter_guide = require("client.slua.logic.growth_project.enter_guide")
  local mode_id = enter_guide.MatchId
  if sub_mode == mode_id then
    return true
  else
    return false
  end
end

function NetUtil.ShowConnectionMsgBox(showPanelTimes, errorMsg)
  log(bWriteLog and "ClientEntry -----  NetUtil.ShowConnectionMsgBox: " .. showPanelTimes .. ", curStatus:" .. GameStatus.GetGameStatus() .. ", errorMsg = " .. tostring(errorMsg))
  NetUtil.gameTick = false
  
  local function clickOkCallback()
    NetUtil.tryConnect(Enum_LOGIN_REPORT_CFG.NET_CONNECT_MSGBOX)
  end
  
  local function clickCancelCallback()
    local login = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
    login:backLogin()
    local LogicFitVersionDownload = require("client.slua.logic.download.fit.logic_fitVersion_download")
    LogicFitVersionDownload.TryReshowDeleteRestartHint("ShowConnectionMsgBoxCancel", true)
  end
  
  logic_connection_waiting:Hide(1)
  local strTile = LocUtil.GetLocalizeResStr(102012)
  local strMsg = LocUtil.GetLocalizeResStr(103015)
  if showPanelTimes == 2 then
    strMsg = LocUtil.GetLocalizeResStr(301226)
  elseif showPanelTimes == 3 then
    strMsg = LocUtil.GetLocalizeResStr(301227)
  else
    strMsg = LocUtil.GetLocalizeResStr(301228)
  end
  local extraData = {isConnectionPanel = true, androidCallback = clickCancelCallback}
  if showPanelTimes < 4 then
    local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
    CommonMsgBoxMgr.HideAllPanel()
    CommonMsgBoxMgr.Show(2, strTile, strMsg, clickOkCallback, clickCancelCallback, LocUtil.GetLocalizeResStr(62649), nil, extraData)
  else
    local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
    CommonMsgBoxMgr.HideAllPanel()
    CommonMsgBoxMgr.Show(1, strTile, strMsg, clickCancelCallback, nil, LocUtil.GetLocalizeResStr(62649), nil, extraData)
  end
end

function NetUtil.tryConnect(reason)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  local lobbyInfo = login_module.loginLobbyInfo
  log_shipping_client("[Login process] ClientEntry -----  NetUtil.tryConnect curStatus:" .. GameStatus.GetGameStatus() .. " for reason = " .. tostring(reason))
  NetUtil.gameTick = false
  NetUtil.SendTime = TimeUtil.OSTime()
  local isConnected = Client.IsConnected(NetInterface)
  log(bWriteLog and "ClientEntry NetUtil.tryConnect Client.IsConnected is " .. tostring(isConnected))
  if not GameStatus.IsInFightingStatus() then
    logic_connection_waiting:Show(1)
  end
  NetUtil.ConnectReason = reason
  if NetUtil.ConnectReason == Enum_LOGIN_REPORT_CFG.NET_MSG_TIME_OUT then
    NetUtil.bIsTimeOutReconnect = 1
  end
  NetUtil.ConnectToURL(lobbyInfo.Url)
end

local normalEvent = {
  [9999] = 1,
  [211] = 1
}
local eventParam2ToErrorCode = {
  [2002] = 18010163,
  [2500] = 18010164,
  [2515] = 18010161,
  [2516] = 18010170,
  [2517] = 18010170,
  [2518] = 18010169
}

function NetUtil.OnNetworkEvent(eventID, eventParam, eventParam2)
  local normalRes = eventParam2ToErrorCode[eventParam2]
  local IMSDKSystem = require("client.logic.login.logic_imsdk")
  local ShareMgr = require("client.logic.share.share_logic")
  log(bWriteLog and "ClientEntry -----  OnNetworkEvent: eventID = " .. eventID .. " eventParam = " .. eventParam)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  local curStatus = GameStatus.GetGameStatus()
  logic_connection_waiting:Hide(1)
  if eventID == 1 then
    log(bWriteLog and "authorization initialized")
  elseif eventID == 2 then
    log(bWriteLog and "NetUtil.OnNetworkEvent, login result = " .. tostring(eventParam))
    if PublishRegionMacros.IsGlobalOperationRegion() then
      local logic_login_event = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_login_event)
      logic_login_event:HandleLoginResult(eventParam, eventParam2)
      return
    end
    local SDKMacros = require("client.slua.config.ClientMacros.SDKMacros")
    local IMSDKServerError = SDKMacros.IMSDKServerErrorCode
    IMSDKSystem.StopIMSDKTimer()
    NetUtil.noRefreshLogout = false
    local SettingAccount = require("client.logic.setting.logic_setting_account")
    SettingAccount.SetunifiedAccountLogging(false)
    local SVPNSystem = require("client.slua.logic.gamemaster.logic_svpn")
    SVPNSystem.OnIMSDKLoginResult(eventParam)
    local logic_http_dns = require("client.slua.logic.httpdns.logic_http_dns")
    logic_http_dns:OnMSDKLogin()
    local logic_imsdk_interface = require("client.logic.login.logic_imsdk_interface")
    logic_imsdk_interface:OnMSDKLogin()
    local DevicePlatformNameMacros = require("client.slua.config.ClientMacros.DevicePlatformNameMacros")
    if eventParam ~= 0 then
      login_module:ShowButtonsAfterLoginFailed()
      if eventParam ~= 106 and eventParam ~= 611 and eventParam ~= 701 and eventParam ~= 2 then
        NetUtil.LogoutNoRefresh()
      end
      EventSystem:postEvent(EVENTTYPE_LOGIN, EVENTID_LOGIN_FAIL_NETUTIL)
      local logic_fb_web_login = require("client.logic.login.logic_fb_web_login")
      if logic_fb_web_login:HandleLoginFail(eventParam, eventParam2) then
        return
      end
    end
    if eventParam == 0 then
      log(bWriteLog and "login ok")
      login_module:ClearLoginCountAndTime()
      EventSystem:postEvent(EVENTTYPE_LOGIN, EVENTID_LOGIN_SUCCESS_NETUTIL)
      local logic_cloud_game = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_cloud_game)
      logic_cloud_game:SendMessageToCloudGame(logic_cloud_game.ProtocolName.SDKLoginSuccess)
      
      local function UpdateEndCallBack()
        log(bWriteLog and "UpdateEndCallBack")
        local channel = Client.GetLoginChannel(NetInterface)
        log(bWriteLog and "authorization login ok, channel = " .. channel)
        if channel == BP_ENUM_PLAYFORM_UnifiedAccountByiTOP then
          local PlayerPrefsSystem = require("client.logic.LogicPlayerPrefs.playerprefs")
          if login_module.phoneMailType ~= 0 then
            local tb = {
              unified_type = login_module.phoneMailType
            }
            print(bWriteLog and "UpdateEndCallBack save unified_type = " .. tostring(tb.unified_type))
            PlayerPrefsSystem.SaveTableToFile_N(tb, PlayerPrefsSystem.ePlayerPrefsType.eMailPhoneLoginType)
          end
        end
        if globalConfig.IsDirectConnect() == false and globalConfig.isSupervision == false then
          log("hideAuthorizationUI")
          local is_uepubgm = Client.IsUEPUBGM()
          local servername = ""
          if Client.IsEditor() then
            local UEPUBGMConfig = RequireBlackList("blacklist.editor.uepubgm.UEPUBGMConfig")
            servername = UEPUBGMConfig.GetServerName()
          else
            servername = Client.GetUEPUBGMServerName()
          end
          if not is_uepubgm or servername == "" then
            login_module:Transition(login_module.ELoginFSMEvent.Event_LTCS)
            if channel == BP_ENUM_PLAYFORM_WX and curStatus == GameStatus.Login then
              ShowNotice("101709", true)
            end
            return
          end
          log(bWriteLog and "[ori]Start log in with uepubgm")
          login_module:LoginToServer(servername)
        else
          log("Connect to Gate Directly")
          login_module:ConnectToGate()
        end
      end
      
      local version_up_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.version_up_module)
      log(bWriteLog and "NetUtil.OnNetworkEvent, alreadyGrayUpdate = " .. tostring(version_up_module.bAlreadyGrayUpdate))
      if not version_up_module.bAlreadyGrayUpdate then
        version_up_module:StartGrayUpdate(UpdateEndCallBack)
      else
        UpdateEndCallBack()
      end
      NetUtil.needInitCentauriWhenLogin = true
    elseif eventParam == 3 then
      log(bWriteLog and "auth fail need retry")
      ShowNotice(101713)
    elseif eventParam == 106 then
      log(bWriteLog and "auth fail for user cancel")
      ShowNotice(101711)
    elseif eventParam == 701 then
      if curStatus == GameStatus.Login then
        local title = LocUtil.GetLocalizeResStr(101001)
        local notice = LocUtil.GetLocalizeResStr(4188)
        local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
        CommonMsgBoxMgr.Show(1, title, notice)
      end
    elseif eventParam == 1001 or eventParam == 1002 then
      log(bWriteLog and "client_entry NetUtil.OnNetworkEvent QuickLogin Fail eventParam:" .. tostring(eventParam))
    elseif (eventParam == 211 or eventParam == 9999) and eventParam2 == 2146 then
      if curStatus == GameStatus.Login then
        NetUtil.ShowUnifiedAccountException()
      end
    elseif normalEvent[eventParam] and normalRes then
      NetUtil.ShowMsgCommonMsg(normalRes)
    elseif (eventParam == 211 or eventParam == 9999) and eventParam2 == IMSDKServerError.CHANNEL_OPENID_BANED then
      local IMSDKHelper = import("IMSDKHelper")
      local loginRetJson = IMSDKHelper.GetInstance():GetLastLoginResultJson()
      local loginRet = json.decode(loginRetJson)
      if loginRet.thirdRetCode == IMSDKServerError.CHANNEL_OPENID_BANED then
        local thridMsgJson = loginRet.thirdRetMsg
        local thridMsg = json.decode(thridMsgJson)
        local openid = thridMsg.iOpenid
        local channel = thridMsg.iChannel
        local msg = thridMsg.msg
        local bandEndTime = thridMsg.iBanEnd
        login_module:ShowFreezePopupUI(openid, channel, bandEndTime)
      end
    elseif 9999 <= eventParam and eventParam <= 100000 then
      login_module:UpdateLoginCountAndTime()
      if curStatus == GameStatus.Login then
        local title = LocUtil.GetLocalizeResStr(101001)
        local notice = NetUtil.GetSDKErrorNotice(eventParam, eventParam2)
        local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
        CommonMsgBoxMgr.Show(1, title, notice)
      end
    elseif eventParam == 611 then
      log(bWriteLog and "login failed:" .. eventParam)
      local client_imsdk_eventparam = require("client.logic.ClientEntry.client_imsdk_eventparam")
      local channel = Client.GetLoginChannel(NetInterface)
      log(bWriteLog and "login failed:" .. eventParam .. " channel:" .. channel)
      if client_imsdk_eventparam.channel2ItopErrorCodeTable[channel] then
        local data = {
          ItopErrorCode = client_imsdk_eventparam.channel2ItopErrorCodeTable[channel],
          eventParam2 = eventParam2,
          channel = channel
        }
        UIManager.ShowUI(UIManager.UI_Config.Protection_UIBP, data)
        return
      else
        login_module:UpdateLoginCountAndTime()
        NetUtil.ShowSDKErrorNotice(eventParam, eventParam2)
      end
    else
      log(bWriteLog and "login failed:" .. eventParam)
      if eventParam ~= -1 and eventParam ~= 6 and eventParam ~= 7 and eventParam ~= 106 and eventParam ~= 107 and eventParam ~= 109 and eventParam ~= 200 then
        if curStatus ~= GameStatus.Login then
          return
        end
        login_module:UpdateLoginCountAndTime()
        NetUtil.ShowSDKErrorNotice(eventParam, eventParam2)
        return
      end
      login_module:UpdateLoginCountAndTime()
      login_module:ShowLoginUI()
      if eventParam == 7 and DevicePlatformNameMacros.IsPC() then
        ShowNotice(101710)
      end
    end
  elseif eventID == 3 then
    log(bWriteLog and "NetUtil.OnNetworkEvent, logout result = " .. tostring(eventParam))
    if NetUtil.noRefreshLogout ~= true then
      local login = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
      login:backLogin(1)
    end
    NetUtil.noRefreshLogout = false
  elseif eventID == 4 then
    IMSDKSystem.StopIMSDKTimer()
    EventSystem:postEvent(EVENTTYPE_SHARE, EVENTID_SHARE_BACK)
    log(bWriteLog and "shared success")
    ShareMgr.onShareResult(1, "")
    local webModule = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.webModule)
    local url = webModule:GetURLForComebackAfterShare()
    if url ~= nil then
      log(bWriteLog and "NetUtil.OnNetworkEvent, auto OpenURL afer share, url = " .. tostring(url))
      url = webModule:AddParameterByPersonalInfo(url)
      local WebviewSDK = require("client.slua.logic.url.logic_webview_sdk")
      WebviewSDK:OpenURL(url)
    end
  elseif eventID == 253 then
    log(bWriteLog and "NetUtil.OnNetworkEvent, OnMigrationNotify, result = " .. tostring(eventParam))
    local ui = UIManager.GetUI(UIManager.UI_Config.data_migration)
    if ui ~= nil then
      UIManager.CloseUI(UIManager.UI_Config.data_migration)
    end
    local DataMigrationSystem = require("client.slua.logic.data_migration.data_migration_logic")
    log(bWriteLog and "[DeanJYT] NetUtil.OnNetworkEvent, OnMigrationNotify isDoneNextStep = " .. tostring(DataMigrationSystem.isDoneNextStep) .. ", nextStep type = " .. tostring(type(DataMigrationSystem.nextStep)))
    if not DataMigrationSystem.isDoneNextStep and DataMigrationSystem.nextStep then
      DataMigrationSystem.nextStep()
    end
    if eventParam == 1 then
      local login = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
      login:sendLogout()
      DataMigrationSystem.SetNoticeId(21194)
    elseif eventParam == -741 then
      ShowNotice(LocUtil.GetLocalizeResStr(11595))
    elseif eventParam == 2 then
    else
      ShowNotice(LocUtil.GetLocalizeResStr(740002))
    end
  elseif eventID == 255 then
    log(bWriteLog and "received bind intl event,eventid : " .. eventParam)
    IMSDKSystem.StopIMSDKTimer()
    EventSystem:postEvent(EVENTTYPE_BIND_INTL, EVENTID_INTL_BIND_NOTIFY, eventParam)
  end
end

function NetUtil.ShowUnifiedAccountException()
  local title = LocUtil.GetLocalizeResStr(101001)
  local notice = LocUtil.GetLocalizeResStr(778877)
  
  local function linkCallbackHandler()
    local LogicCustomerService = require("client.slua.logic.CustomerService.LogicCustomerService")
    LogicCustomerService.HelpshiftShowFAQsWithInfo()
  end
  
  local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
  CommonMsgBoxMgr.Show(1, title, notice, nil, nil, nil, nil, {urlHandle = linkCallbackHandler})
end

function NetUtil.ShowMsgCommonMsg(noticeID)
  log(bWriteLog and "  NetUtil.ShowMsgCommonMsg. noticeID: " .. tostring(noticeID))
  noticeID = noticeID or 778877
  local title = LocUtil.GetLocalizeResStr(101001)
  local notice = LocUtil.GetLocalizeResStr(noticeID)
  local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
  CommonMsgBoxMgr.Show(1, title, notice)
end

function NetUtil.GetSDKErrorNotice(eventParam, eventParam2)
  local notice = LocUtil.GetLocalizeResStr(101205)
  if not PublishRegionMacros.IsGlobalOperationRegion() then
    notice = notice .. string.format(" (%d,%d)", eventParam, eventParam2)
  end
  local DevicePlatformNameMacros = require("client.slua.config.ClientMacros.DevicePlatformNameMacros")
  if eventParam == 11016 then
    notice = LocUtil.GetLocalizeResStr(4178)
  elseif eventParam == 11500 then
    notice = LocUtil.GetLocalizeResStr(4179)
  elseif eventParam == 11005 then
    notice = LocUtil.GetLocalizeResStr(4180)
  elseif eventParam == 11020 then
    notice = LocUtil.GetLocalizeResStr(4181)
  elseif eventParam == 11003 then
    notice = LocUtil.GetLocalizeResStr(4182)
  elseif eventParam == 11001 then
    notice = LocUtil.GetLocalizeResStr(4183)
  elseif eventParam == 11002 then
    notice = LocUtil.GetLocalizeResStr(4184)
  elseif eventParam == 20002 then
    notice = LocUtil.GetLocalizeResStr(4322)
  elseif eventParam2 == 2001 then
    notice = LocUtil.GetLocalizeResStr(200000149)
  elseif eventParam == 9999 and Client.GetLoginChannel(NetInterface) == BP_ENUM_PLAYFORM_TWITTER and Client.GetDevicePlatformName() == DevicePlatformNameMacros.Android and Client.IsInstallTwitter(NetInterface) == false then
    notice = LocUtil.GetLocalizeResStr(7496)
  end
  return notice
end

function NetUtil.ShowSDKErrorNotice(eventParam, eventParam2)
  local title = LocUtil.GetLocalizeResStr(101001)
  local notice = ""
  if Client.GetLoginChannel(NetInterface) == BP_ENUM_PLAYFORM_UnifiedAccountByiTOP then
    notice = LocUtil.GetLocalizeResStr(101205)
  else
    notice = LocUtil.GetLocalizeResStr(101100 + eventParam)
  end
  if eventParam2 == 2001 then
    notice = LocUtil.GetLocalizeResStr(200000149)
  elseif eventParam2 == -566 then
    notice = LocUtil.GetLocalizeResStr(75472)
  end
  if notice ~= "" then
    local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
    if eventParam2 ~= 2001 and eventParam2 ~= -566 then
      notice = notice .. string.format(" (%d,%d)", eventParam, eventParam2)
    end
    CommonMsgBoxMgr.Show(1, title, notice)
  end
end

function NetUtil.OnDSServerConnectionErrorNotify(gameID, reason)
  log(bWriteLog and "ClientEntry -----  OnDSServerConnectionErrorNotify -------- gameID:" .. gameID .. ", reason:" .. reason .. ", BattleResult:" .. tostring(BattleResult.IgnoreDSError))
  if BattleResult.IgnoreDSError then
    log(bWriteLog and "ClientEntry -----  BattleResult.IgnoreDSError return\239\188\129\239\188\129\239\188\129\239\188\129")
    return
  end
  local isUGCLoadError = false
  if reason == "load_ugc_err" then
    isUGCLoadError = true
    local LogicUGCCRUD = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGCCRUD)
    if LogicUGCCRUD:GetIsEditMod() then
      LogicUGCCRUD:SetIsEditMod(false)
      LobbySystem.SetWaitingBattleFlag(false)
      NetUtil.StopCheckEnterBattle()
    elseif LobbySystem.isWaittingEnterBattle then
      LobbySystem.SetWaitingBattleFlag(false)
      NetUtil.StopCheckEnterBattle()
    end
  end
  local curStatus = LuaClassObj.GetGameStatus(bp_global)
  log(bWriteLog and "NetUtil.OnDSServerConnectionErrorNotify curStatus = " .. tostring(curStatus))
  if curStatus ~= GameStatus.Fighting then
    log(bWriteLog and "ClientEntry -----  not in fighting dont show msgbox!!!" .. curStatus)
    if isUGCLoadError then
      local LoadingSystem = require("client.slua.logic.loading.logic_loading")
      LoadingSystem.RefreshLoadPercent(1)
      ShowNotice(511009)
    end
  end
  if GameStatus.IsInLobbyOrMainCity() then
    log(bWriteLog and "NetUtil.OnDSServerConnectionErrorNotify ClientEntry IsLobbyOrMainCity")
    if slua_GameFrontendHUD and slua_GameFrontendHUD.UnrealNetworkStatus then
      log(bWriteLog and "NetUtil.OnDSServerConnectionErrorNotify 1 UnrealNetworkStatus = " .. tostring(slua_GameFrontendHUD.UnrealNetworkStatus) .. " g_game_id = " .. tostring(g_game_id))
      if g_game_id and gameID and g_game_id == gameID then
        log(bWriteLog and "NetUtil.OnDSServerConnectionErrorNotify modify UnrealNetworkStatus")
        slua_GameFrontendHUD.UnrealNetworkStatus = "Offline"
      end
      log(bWriteLog and "NetUtil.OnDSServerConnectionErrorNotify 2 UnrealNetworkStatus = " .. tostring(slua_GameFrontendHUD.UnrealNetworkStatus))
    end
    local LoadingSystem = require("client.slua.logic.loading.logic_loading")
    LoadingSystem.RefreshLoadPercent(1)
    if LobbySystem.is_DeathMatchMode then
      local TeamCompLoading = require("client.slua.logic.loading.logic_teamcomp_loading")
      TeamCompLoading.RefreshLoadPercent(1)
    end
    EventSystem:postEvent(EVENTTYPE_NETWORK, EVENTID_MAIN_CITY_DS_CONNECTION_ERROR, gameID, reason)
    return
  end
  if curStatus ~= GameStatus.Fighting then
    return
  end
  local strTile = LocUtil.GetLocalizeResStr(102012)
  local strMsg = LocUtil.GetLocalizeResStr(301229)
  if reason == "timeout" then
    strMsg = LocUtil.GetLocalizeResStr(301230)
  elseif reason == "active-timeout" then
    strMsg = LocUtil.GetLocalizeResStr(301231)
  end
  local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
  CommonMsgBoxMgr.Show(1, strTile, strMsg, function()
    FuncUtil.ShowLoadingToLobby()
    Client.ReturnToLobby(GameFrontendHUD)
    if not NetManager.bConnected and LobbySystem.CheckOpen(BP_ENUM_IS_QUERY_PLAYER_STETE_AFTER_LOADING) then
      local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
      login_module:reqLoginLobby(true, Enum_LOGIN_REPORT_CFG.DS_ERR)
    else
      local MatchSystem = require("client.slua.logic.match.logic_match")
      MatchSystem.SetQueryPlayerFlag(true)
    end
    Client.TPerforPlatDisconnectReport(GameFrontendHUD, 14)
  end, nil, nil, nil, true)
end

function NetUtil.LogOut()
  log(bWriteLog and "ClientEntry ----- NetUtil.LogOut()")
  NetUtil.SendPkg("logout")
  if NetUtil.PleaseReloginTimer then
    local time_ticker = require("common.time_ticker")
    time_ticker.RemoveTimer(NetUtil.PleaseReloginTimer)
    NetUtil.PleaseReloginTimer = nil
  end
end

function NetUtil.sync_time(serverTime)
  log(bWriteLog and string.format("sync_time :%s", TimeUtil.FormatTime_YMDHMS(serverTime, true)))
  TimeUtil.SetServerTimeInSec(serverTime)
end

function NetUtil.LogoutNoRefresh()
  NetUtil.noRefreshLogout = true
  local SettingAccount = require("client.logic.setting.logic_setting_account")
  SettingAccount.ClientLogout()
end

function NetUtil.ProcOnDisconnected()
  NetUtil.tNetDisconnected = TimeUtil.OSTime()
end

function NetUtil.ProcOnConnecting()
  NetUtil.tNetConnecting = TimeUtil.OSTime()
end

function NetUtil.ProcOnConnected()
  NetUtil.tNetConnected = TimeUtil.OSTime()
end

function NetUtil.CheckSpecialDeviceNetFlash()
  if not (NetUtil.tNetDisconnected > 0 and NetUtil.tNetConnecting > NetUtil.tNetDisconnected and NetUtil.tNetConnected > NetUtil.tNetConnecting and NetUtil.tNetConnecting - NetUtil.tNetDisconnected <= 1) or NetUtil.tNetConnected - NetUtil.tNetDisconnected <= 1 then
  end
  return false
end

function NetUtil.MoveFollowTarget(follow_type, follow_uid)
  follow_uid = follow_uid or 0
  Client.MoveFollowTarget(GameFrontendHUD, follow_type, follow_uid)
end

function NetUtil.check_dh_packet_key(packet_key, svr_packet_key_md5, from, dh_ext_info, bReportDSInfo)
  log(bWriteLog and "NetUtil.check_dh_packet_key")
  if type(packet_key) ~= "string" then
    sandbox.LogError("NetUtil.check_dh_packet_key packet_key=" .. tostring(packet_key))
    return
  end
  if type(svr_packet_key_md5) ~= "string" then
    sandbox.LogError("NetUtil.check_dh_packet_key svr_packet_key_md5=" .. tostring(svr_packet_key_md5))
    return
  end
  local packet_key_md5 = Client.MD5LuaString(packet_key)
  dh_ext_info.packet_key_md5 = packet_key_md5
  dh_ext_info.svr_packet_key_md5 = svr_packet_key_md5
  log_tree("dh_ext_info = ", dh_ext_info)
  if bReportDSInfo or string.lower(packet_key_md5) ~= string.lower(svr_packet_key_md5) then
    log(bWriteLog and "NetUtil.check_dh_packet_key report")
    NetUtil.SendPkg("report_dh_calc_key_error", from, dh_ext_info)
  end
  log(bWriteLog and "NetUtil.check_dh_packet_key packet_key_md5=" .. packet_key_md5 .. " svr_packet_key_md5=" .. svr_packet_key_md5)
end

function NetUtil.DecXorForBattle(src, key)
  if src == nil then
    sandbox.LogError("FuncUtil.DecXorForBattle src == nil!")
    return
  end
  if key == nil then
    sandbox.LogError("FuncUtil.DecXorForBattle key == nil!")
    return
  end
  local ssrc = tostring(src)
  local ssrc_len = string.len(ssrc)
  if ssrc_len == 0 then
    sandbox.LogError("FuncUtil.DecXorForBattle src len == 0!")
    return
  end
  local skey = tostring(key)
  local skey_len = string.len(skey)
  if skey_len == 0 then
    sandbox.LogError("FuncUtil.DecXorForBattle key len == 0!")
    return
  end
  local dec_src = {}
  local kidx = 1
  for i = 1, ssrc_len do
    local ch_src = string.byte(ssrc, i)
    local ch_key = string.byte(skey, kidx)
    kidx = kidx % skey_len + 1
    local ch = ch_src ~ ch_key
    table.insert(dec_src, string.char(ch))
  end
  return table.concat(dec_src)
end

function NetUtil.ShowDSTimeOutTipsUI(IsShow, nShowMask)
  local bCurrentDSLongShowTimeOut = NetUtil.nDSTimeOutShowBitMask & NetUtil.DSTimeOutLong
  if 0 < bCurrentDSLongShowTimeOut and nShowMask > NetUtil.DSTimeOutLong then
    print(bWriteLog and "NetUtil.ShowDSTimeOutTipsUI forbidden by DS Long timeout, nShowMask:", nShowMask)
    return
  end
  if UIManager.UI_Config_InGame == nil or UIManager.UI_Config_InGame.WeakNetworkUI == nil then
    return
  end
  if IsShow then
    local WeakNetworkUI = UIManager.GetUI(UIManager.UI_Config_InGame.WeakNetworkUI)
    if not NetUtil.dsTimeOutTipsUIShowing then
      EventSystem:postEvent(EVENTTYPE_CLIENT_TLOG, EVENTID_ADD_VALUE_TLOG, "WeakNetworkNum", 1)
      if WeakNetworkUI == nil then
        UIManager.ShowUI(UIManager.UI_Config_InGame.WeakNetworkUI)
      else
        WeakNetworkUI:ShowWeakIcon()
      end
      NetUtil.nDSTimeOutShowBitMask = NetUtil.nDSTimeOutShowBitMask | nShowMask
      NetUtil.dsTimeOutTipsUIShowing = true
      print(bWriteLog and "NetUtil.ShowDSTimeOutTipsUI  Show nShowMask:", nShowMask)
    end
  else
    local WeakNetworkUI = UIManager.GetUI(UIManager.UI_Config_InGame.WeakNetworkUI)
    if WeakNetworkUI ~= nil then
      WeakNetworkUI:HideWeakIcon()
    end
    NetUtil.dsTimeOutTipsUIShowing = false
    NetUtil.nDSTimeOutShowBitMask = NetUtil.nDSTimeOutShowBitMask & ~nShowMask
    print(bWriteLog and "NetUtil.ShowDSTimeOutTipsUI  Hide nShowMask:", nShowMask)
  end
end

function NetUtil.GetAutoReconnectParam()
  log(bWriteLog and "NetUtil.GetAutoReconnectParam")
  local param = {
    times = 2,
    showFunc = nil,
    clearFunc = nil
  }
  local systemConfig = {
    {
      checkFunc = RoomSystem.CheckNeedReconnect,
      setFunc = RoomSystem.SetAutoReconnectParam
    }
  }
  for i, v in ipairs(systemConfig) do
    if v.checkFunc() then
      v.setFunc(param)
      break
    end
  end
  return param
end

function NetUtil.ClearAutoReconnectParam()
  if not NetUtil.AutoReconnectParam then
    return
  end
  log(bWriteLog and "NetUtil.ClearAutoReconnectParam")
  NetUtil.ClearAutoReconnectTimer()
  if NetUtil.AutoReconnectParam.clearFunc then
    NetUtil.AutoReconnectParam.clearFunc()
  end
  NetUtil.AutoReconnectParam = nil
end

function NetUtil.ClearAutoReconnectTimer()
  if NetUtil.autoReconnectTimer then
    local timer_ticker = require("common.time_ticker")
    timer_ticker.RemoveTimer(NetUtil.autoReconnectTimer)
    NetUtil.autoReconnectTimer = nil
  end
end

function NetUtil.NetUnstableReport.RecordChange(bUnstable)
  local Report = NetUtil.NetUnstableReport
  if not Report.Enabled then
    return
  end
  if Report.LastRecordedUnstable == bUnstable then
    return
  end
  Report.LastRecordedUnstable = bUnstable
  local MaxSize = Report.HistoryMaxSize
  local writeIndex = Report.HistoryHeadIndex
  Report.History[writeIndex] = {
    Time = os.time(),
    Unstable = bUnstable
  }
  if MaxSize <= writeIndex then
    Report.HistoryHeadIndex = 1
  else
    Report.HistoryHeadIndex = writeIndex + 1
  end
  if MaxSize > Report.HistoryCount then
    Report.HistoryCount = Report.HistoryCount + 1
  end
end

function NetUtil.NetUnstableReport.IsNetUnstableAtTime(queryTime)
  if type(queryTime) ~= "number" then
    return false
  end
  local Report = NetUtil.NetUnstableReport
  if not Report.Enabled then
    return false
  end
  local Count = Report.HistoryCount
  if Count <= 0 then
    return false
  end
  local MaxSize = Report.HistoryMaxSize
  local newestIndex = Report.HistoryHeadIndex - 1
  if newestIndex < 1 then
    newestIndex = MaxSize
  end
  for i = 0, Count - 1 do
    local idx = newestIndex - i
    if idx < 1 then
      idx = idx + MaxSize
    end
    local record = Report.History[idx]
    if record ~= nil and queryTime >= record.Time then
      return record.Unstable
    end
  end
  return false
end

if _G.IsEnableMockGameSvr then
  function NetUtil.SendMsgToMockGameSvr(MsgType, ...)
    print(bWriteLog and string.format("NetUtil.LoginMockGameSvr MsgType = %s", MsgType))
    
    if MsgType == "login" then
      NetUtil.SendPkg("mockgamesvr_login", ...)
    end
  end
end
UnrealNet.NetworkStatus = {
  Offline = "Offline",
  Connecting = "Connecting",
  Online = "Online",
  Lost = "Lost",
  RecoverableLost = "RecoverableLost"
}
UnrealNet.NetworkEvent = {
  RemoteHostResolved = "RemoteHostResolved",
  NetworkEstablished = "NetworkEstablished",
  NetworkRecovered = "NetworkRecovered"
}
UnrealNet.NetworkException = {
  FailureReceived = "FailureReceived",
  ConnectionLost = "ConnectionLost",
  ConnectionTimeout = "ConnectionTimeout",
  ConnectionLongTimeNoReceived = "ConnectionLongTimeNoReceived",
  ConnectingTimeout = "ConnectingTimeout",
  PendingConnectionFailure = "PendingConnectionFailure",
  CriticalSocketError = "CriticalSocketError",
  ActorChannelError = "ActorChannelError"
}
UnrealNet.FailureReceivedReason = {
  CharacterDead = "CharacterDead",
  TeammatesAllDead = "TeammatesAllDead",
  GameOver = "GameOver",
  TrainingOver = "TrainingOver",
  CheatDetected = "CheatDetected",
  WatchedPlayerGone = "WatchedPlayerGone",
  NormalNetDriverShutdown = "Normal_NetDriverShutdown",
  HostClosedConnection = "Host closed the connection."
}

function UnrealNet.HandleNetworkEvent(EventType, EventMessage, ...)
  EventMessage = EventMessage or ""
  NetUtil.SendPkg("report_unrealnet_event", g_game_id, EventType, EventMessage)
  if EventType == UnrealNet.NetworkEvent.RemoteHostResolved then
    return
  end
  local curStatus = LuaClassObj.GetGameStatus(bp_global)
  log(bWriteLog and string.format("gavins NetworkEvent %s, curstatus %s", EventType, curStatus))
  if EventType == "NetworkEstablished" or EventType == "NetworkRecovered" then
    logic_connection_waiting:Hide(1)
    NetUtil.dsTimeOutRetryTimes = 0
    local logic_main_city_reconnect = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_main_city_reconnect)
    logic_main_city_reconnect.maincity_dsTimeOutRetryTimes = 0
    if EventType == "NetworkEstablished" and GameStatus.IsInMainCity() then
      logic_main_city_reconnect:CheckDSVersion(EventMessage)
    end
    NetUtil.StopCheckDSActive()
    if curStatus == GameStatus.Fighting and not GameStatus.IsInMainCity() then
      local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
      CommonMsgBoxMgr.HideAllPanel()
    end
    NetUtil.ShowDSTimeOutTipsUI(false, NetUtil.DSTimeOutLong)
  end
end

function UnrealNet.FilterNetworkException(ExceptionType, ErrorMessage)
  if ExceptionType == UnrealNet.NetworkException.FailureReceived then
    if string.find(ErrorMessage, UnrealNet.FailureReceivedReason.NormalNetDriverShutdown) ~= nil then
      return false
    end
    if string.find(ErrorMessage, UnrealNet.FailureReceivedReason.HostClosedConnection) == 1 then
      return false
    end
  end
  if string.find(ErrorMessage, "SwitchIsland") == 1 then
    log(bWriteLog and "SwitchIsland is true")
    return false
  elseif string.find(ErrorMessage, "Normal_ChannelCleanUp") ~= nil then
    local curStatus = LuaClassObj.GetGameStatus(bp_global)
    if curStatus == GameStatus.Login or curStatus == GameStatus.Loading then
      log(bWriteLog and "Is in login")
      return false
    end
    if LobbySystem and LobbySystem.isWaitToEnterGame then
      log(bWriteLog and "LobbySystem.isWaitToEnterGame true")
      return false
    end
  end
  return true
end

function UnrealNet.NetworkExceptionAddEnterBattleStage(InErrorMessage)
  local EnterBattleFinishedStage = ""
  local UIUtil = require("client.common.ui_util")
  if UIUtil.GetGameFrontendHUD() ~= nil then
    EnterBattleFinishedStage = "Stage: " .. UIUtil.GetGameFrontendHUD():GetClientEnterBattleStage()
  end
  local FinalErrorMessage = ""
  if InErrorMessage == nil or #InErrorMessage == 0 then
    FinalErrorMessage = EnterBattleFinishedStage
  else
    FinalErrorMessage = EnterBattleFinishedStage .. " " .. InErrorMessage
  end
  return FinalErrorMessage
end

function UnrealNet.HandleNetworkExceptionReport(ExceptionType, SubType, ErrorMessage)
  local UploadStage = UnrealNet.NetworkExceptionAddEnterBattleStage()
  local EnterBattleStageCostTime = ""
  local UIUtil = require("client.common.ui_util")
  if UIUtil.GetGameFrontendHUD() ~= nil then
    EnterBattleStageCostTime = UIUtil.GetGameFrontendHUD():GetClientEnterBattleStageCostTime()
  end
  local UploadErrorMsg = ErrorMessage .. "Cost:" .. EnterBattleStageCostTime
  NetUtil.SendPkg("report_unrealnet_exception", g_game_id, ExceptionType, UploadErrorMsg, SubType, UploadStage)
end

function UnrealNet.HandleNetworkConnectionClosed(ExceptionType, ErrorMessage)
  if ExceptionType == UnrealNet.FailureReceivedReason.NormalNetDriverShutdown and ErrorMessage == "" or ExceptionType == "Normal_ChannelCleanUp" and ErrorMessage == "" then
    return
  end
  local UploadErrorMessage = string.format("Reason=[%s]&&ErrMsg=[%s]", ExceptionType, ErrorMessage)
  log(bWriteLog and "UnrealNet.HandleNetworkConnectionClosed ExceptionType = " .. UploadErrorMessage)
  UnrealNet.HandleNetworkExceptionReport("NetConnectionClosed", ExceptionType, ErrorMessage)
end

function UnrealNet.HandleSpectateException(ExceptionType, ErrorMessage)
  local UploadErrorMessage = string.format("Reason=[%s]&&ErrMsg=[%s]", ExceptionType, ErrorMessage)
  log(bWriteLog and "UnrealNet.HandleNetworkConnectionClosed ExceptionType = " .. UploadErrorMessage)
  UnrealNet.HandleNetworkExceptionReport("SpectateException", ExceptionType, ErrorMessage)
end

function UnrealNet.HandleNetworkException(ExceptionType, SubType, ErrorLog, bShouldWait, ...)
  local ErrorMessage = ErrorLog .. SubType
  log(bWriteLog and "UnrealNet.HandleNetworkException ExceptionType = " .. ExceptionType .. ", ErrorMessage = " .. ErrorMessage .. ", bShouldWait = " .. tostring(bShouldWait))
  if UnrealNet.FilterNetworkException(ExceptionType, ErrorMessage) then
    local UploadErrorMessage = FuncUtil.ReplaceIllegalChar(ErrorLog)
    UnrealNet.HandleNetworkExceptionReport(ExceptionType, SubType, UploadErrorMessage)
  end
  if ExceptionType == UnrealNet.NetworkException.ActorChannelError then
    return
  end
  if ExceptionType == UnrealNet.NetworkException.FailureReceived and string.find(ErrorMessage, UnrealNet.FailureReceivedReason.TrainingOver) == 1 then
    BattleResultUI.ShowTrainingOverUI()
    return
  end
  local LobbySystem = require("client.logic.login.logic_lobby")
  local dsVersion = Client.GetDSVersion(GameFrontendHUD)
  local curStatus = LuaClassObj.GetGameStatus(bp_global)
  log(bWriteLog and "ClientEntry -----  CurStatus: " .. curStatus .. ", DSVersion: " .. dsVersion)
  if curStatus == GameStatus.Login then
    return
  end
  local LogicUGCMatch = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicUGCMatch)
  local isWaitToEnterGame = LobbySystem.isWaitToEnterGame
  local IsInUGCWaitingEnterGame = LogicUGCMatch:IsInUGCWaitingEnterGame()
  log(bWriteLog and "ClientEntry isWaitToEnterGame = " .. tostring(isWaitToEnterGame) .. " IsInUGCWaitingEnterGame = " .. tostring(IsInUGCWaitingEnterGame))
  if curStatus == GameStatus.Fighting and (isWaitToEnterGame or IsInUGCWaitingEnterGame) then
    log(bWriteLog and "ClientEntry is waiting to enter next game")
    return
  end
  local UIUtil = require("client.common.ui_util")
  local CurStage = ""
  if UIUtil ~= nil and UIUtil.GetGameFrontendHUD() ~= nil then
    CurStage = UIUtil.GetGameFrontendHUD():GetClientEnterBattleStage()
  end
  local Lobby_Main_City = require("client.slua.logic.lobby.MainCity.Lobby_Main_City")
  if not GameStatus.IsInLobbyOrMainCity() and not Lobby_Main_City.IsRecentMainCityGameID(g_game_id) and CurStage ~= "EnterBattleSuccess" and ExceptionType == "ConnectionLongTimeNoReceived" then
    log(bWriteLog and "Ignore LongTimeNoReceived in enter-battle progress")
    return
  end
  if GameStatus.IsInLobbyOrMainCity() or not Lobby_Main_City.IsRecentMainCityGameID(g_game_id) and CurStage ~= "EnterBattleSuccess" and (ExceptionType == "ConnectionTimeout" or ExceptionType == "CriticalSocketError") then
    log(bWriteLog and "ClientEntry is main city mode")
    local LoadingSystem = require("client.slua.logic.loading.logic_loading")
    LoadingSystem.RefreshLoadPercent(1)
    if LobbySystem.is_DeathMatchMode then
      local TeamCompLoading = require("client.slua.logic.loading.logic_teamcomp_loading")
      TeamCompLoading.RefreshLoadPercent(1)
    end
    EventSystem:postEvent(EVENTTYPE_NETWORK, EVENTID_MAIN_CITY_NETWORK_EXCEPTION, ExceptionType, SubType, ErrorLog, bShouldWait)
    return
  end
  if ExceptionType == "FailureReceived" and (string.find(ErrorMessage, "SwitchIsland") == 1 or string.find(ErrorMessage, "switch_level_exit") == 1) then
  else
    local LoadingSystem = require("client.slua.logic.loading.logic_loading")
    LoadingSystem.RefreshLoadPercent(1)
  end
  if ExceptionType == "FailureReceived" then
    if string.find(ErrorMessage, "CharacterDead") == 1 then
      BattleResultUI.SetIsDirectShow(true)
    elseif string.find(ErrorMessage, "SwitchIsland") == 1 then
      return
    elseif string.find(ErrorMessage, "switch_level_exit") == 1 then
      log(bWriteLog and "ClientEntry ----- FailureReceived switch_level_exit, ignore")
      return
    elseif string.find(ErrorMessage, "IdipBan") == 1 then
      local banTable = {}
      for key, value in string.gmatch(ErrorMessage, "(%w+)=([a-zA-Z0-9-,. ]+)") do
        banTable[key] = value
      end
      log_tree("ClientEntry -----  banTable", banTable)
      if banTable.banType and banTable.banInfo and banTable.banTime ~= nil then
        local ban_login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.ban_login_module)
        ban_login_module:on_kickout(banTable.banType, banTable.banInfo, tonumber(banTable.banTime), nil, nil, nil, banTable.linkType)
        return
      end
    end
  end
  LobbySystem.enterGameTimeOutParams = table.pack(ExceptionType, SubType, ErrorLog, bShouldWait)
  local ShowMsgBoxFunc
  local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
  if UIManager.IsUIShow(UIManager.UI_Config.xmission_main) then
    ShowMsgBoxFunc = CommonMsgBoxMgr.ShowTPlan
  else
    ShowMsgBoxFunc = CommonMsgBoxMgr.Show
  end
  local logic_enter_game = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_enter_game)
  local SubMod = 0
  if logic_enter_game and logic_enter_game.InGameReEnterGameInfo ~= nil and #logic_enter_game.InGameReEnterGameInfo >= 11 and logic_enter_game.InGameReEnterGameInfo[11] ~= nil then
    SubMod = logic_enter_game.InGameReEnterGameInfo[11]
    log(bWriteLog and "UnrealNet.HandleNetworkException SubMod " .. tostring(SubMod))
  end
  local SubModeCfg
  if SubMod ~= 0 then
    SubModeCfg = CDataTable.GetTableData("BTMode", SubMod)
  end
  local TimeOutExtendMod = false
  if SubModeCfg and SubModeCfg.ModType ~= "TDM" then
    TimeOutExtendMod = true
  end
  log(bWriteLog and "UnrealNet.HandleNetworkException TimeOutExtendMod " .. tostring(TimeOutExtendMod))
  local TimeOutRetryTimes = 3
  if TimeOutExtendMod == true then
    TimeOutRetryTimes = 5
  end
  local SmartBearerManagerLuaBridge = import("SmartBearerManagerLuaBridge")
  local bInGameReconnectImm = false
  if SmartBearerManagerLuaBridge ~= nil then
    local bExpandClientTimeOut70s = SmartBearerManagerLuaBridge.IsClientBackEndSwitcherBEnable(9)
    local bExpandClientTimeOut100s = SmartBearerManagerLuaBridge.IsClientBackEndSwitcherBEnable(10)
    if bExpandClientTimeOut70s then
      TimeOutRetryTimes = 6
    end
    if bExpandClientTimeOut100s then
      TimeOutRetryTimes = 9
    end
    if SmartBearerManagerLuaBridge.IsClientBackEndSwitcherBEnable(5) then
      bInGameReconnectImm = true
      log(bWriteLog and "ClientBackEndSwitcherB_InGameReconnectImm on")
    else
      log(bWriteLog and "ClientBackEndSwitcherB_InGameReconnectImm off")
    end
  end
  if not _G.IsEditor and bInGameReconnectImm then
    TimeOutRetryTimes = 0
    TimeOutExtendMod = true
  end
  if curStatus == GameStatus.Fighting and bShouldWait == true and TimeOutRetryTimes > NetUtil.dsTimeOutRetryTimes and not BattleResult.IgnoreDSError then
    NetUtil.dsTimeOutRetryTimes = NetUtil.dsTimeOutRetryTimes + 1
    if NetUtil.dsTimeOutRetryTimes == 1 then
      local prompt = LocUtil.GetLocalizeResStr(101001)
      local msg = LocUtil.GetLocalizeResStr(31144)
      ShowMsgBoxFunc(1, prompt, msg, function()
      end)
    end
    LobbySystem.enterGameTimeOutParams = nil
    NetUtil.ShowDSTimeOutTipsUI(true, NetUtil.DSTimeOutLong)
    if NetUtil.dsTimeOutRetryTimes == 1 then
      local TraceSystem = require("client.slua.logic.network_trace.logic_trace")
      TraceSystem.StartTraceTriggerByNetworkBroken()
    end
    return
  end
  local strTile = LocUtil.GetLocalizeResStr(102012)
  local strMsg = LocUtil.GetLocalizeResStr(103017)
  local needRelogin = false
  if ExceptionType == "FailureReceived" or ExceptionType == UnrealNet.NetworkException.PendingConnectionFailure then
    if string.find(ErrorMessage, "CharacterDead") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(120004)
    elseif string.find(ErrorMessage, "TeammatesAllDead") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(120007)
    elseif string.find(ErrorMessage, "GameOver") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(301117)
    elseif string.find(ErrorMessage, UnrealNet.FailureReceivedReason.WatchedPlayerGone) == 1 then
      strMsg = LocUtil.GetLocalizeResStr(501117)
    elseif string.find(ErrorMessage, "SocailIslandInactive") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(9550)
    elseif string.find(ErrorMessage, "SocailIslandClose") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(9570)
    elseif string.find(ErrorMessage, "PlanPHHomeClose") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(69618)
    elseif string.find(ErrorMessage, "PlanCHHallClose") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(880060113)
    elseif string.find(ErrorMessage, "OwnerKickout") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(9863)
    elseif string.find(ErrorMessage, "IslandClose") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(35064)
    elseif string.find(ErrorMessage, "IdipKickOutClient2Exit") == 1 then
      Client.ExitGameForSafety()
    elseif string.find(ErrorMessage, "CWOWClose") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(77113)
    elseif string.find(ErrorMessage, "CWOWInactive") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(9550)
    elseif string.find(ErrorMessage, "manor_kickout_all_visitor") == 1 then
      if string.find(ErrorMessage, "manor_joint_terminate") then
        local logic_home_joint = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_home_joint)
        logic_home_joint.ShowTerminateSuccessUI()
        return
      elseif string.find(ErrorMessage, "manor_joint") then
        strMsg = LocUtil.GetLocalizeResStr(655894)
      else
        strMsg = LocUtil.GetLocalizeResStr(66377)
      end
    elseif string.find(ErrorMessage, "manor_add_black") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(655406)
    elseif string.find(ErrorMessage, "manor_kickout_oldinst_visitor") == 1 then
      strMsg = LocUtil.GetLocalizeResStr(655469)
    end
  elseif ExceptionType == "ConnectionTimeout" then
    strMsg = LocUtil.GetLocalizeResStr(301118)
    needRelogin = true
  elseif ExceptionType == "ConnectingTimeout" then
    strMsg = LocUtil.GetLocalizeResStr(301233)
    local MatchSystem = require("client.slua.logic.match.logic_match")
    log(bWriteLog and "ClientEntry MatchSystem.QueryPlayerState")
    MatchSystem.QueryPlayerState()
  else
    needRelogin = true
  end
  log(bWriteLog and "ClientEntry ----- NetworkFailure, IgnoreDSError -- " .. tostring(BattleResult.IgnoreDSError) .. " needRelogin -- " .. tostring(needRelogin))
  if BattleResult.IgnoreDSError then
    log(bWriteLog and "ClientEntry -----  DS BattleResult.IgnoreDSError return\239\188\129\239\188\129\239\188\129\239\188\129")
    LobbySystem.enterGameTimeOutParams = nil
    return
  end
  if UIUtil ~= nil and UIUtil.GetGameFrontendHUD() ~= nil then
    CurStage = UIUtil.GetGameFrontendHUD():GetClientEnterBattleStage()
  end
  if TimeOutExtendMod == true and curStatus == GameStatus.Fighting and CurStage == "EnterBattleSuccess" and (ExceptionType == "ConnectionTimeout" or ExceptionType == "ConnectionLongTimeNoReceived" or ExceptionType == "CriticalSocketError") and UnrealNet.IsNeedShowMsgBox(ErrorMessage) then
    if logic_enter_game then
      logic_enter_game.InGameShowingReEnter = true
    end
    ShowMsgBoxFunc(2, strTile, LocUtil.GetLocalizeResStr(200000456), function()
      if logic_enter_game ~= nil and logic_enter_game.GameOverGameID ~= nil and logic_enter_game.GameOverGameID == g_game_id then
        logic_enter_game.InGameShowingReEnter = false
        local strTileInner = LocUtil.GetLocalizeResStr(102012)
        local strMsgInner = LocUtil.GetLocalizeResStr(301117)
        ShowMsgBoxFunc(1, strTileInner, strMsgInner, function()
          UnrealNet.RetrunToLobbyFromDisconnect(needRelogin)
          log(bWriteLog and "UnrealNet.HandleNetworkException ReturnToLobby")
        end)
      elseif logic_enter_game ~= nil and logic_enter_game.InGameShowingReEnter == true then
        if logic_enter_game.InGameReEnterGameInfo ~= nil and #logic_enter_game.InGameReEnterGameInfo >= 11 and logic_enter_game.InGameReEnterGameInfo[6] ~= nil and logic_enter_game.InGameReEnterGameInfo[6] == g_game_id then
          local LoadingSystem = require("client.slua.logic.loading.logic_loading")
          if LoadingSystem ~= nil then
            LoadingSystem.ShowLoading(false, nil, logic_enter_game.InGameReEnterGameInfo[11])
          end
          
          local function EnterBattleProtect(ip, port, key, name, packet_key, game_id, is_ob, ad_conf, waterType, waterUserID, sub_mode, mode_type, ugc_map_id, dynamiclevels_op, grome_info)
            if ugc_map_id == 0 then
              logic_enter_game:EnterBattle(ip, port, key, name, packet_key, game_id, is_ob, ad_conf, waterType, waterUserID, sub_mode, mode_type, nil, dynamiclevels_op, grome_info)
            else
              logic_enter_game:EnterBattle(ip, port, key, name, packet_key, game_id, is_ob, ad_conf, waterType, waterUserID, sub_mode, mode_type, ugc_map_id, dynamiclevels_op, grome_info)
            end
          end
          
          UIManager.ClearOnModePreSwitch(GameStatus.Fighting, GameStatus.Fighting)
          slua_GameFrontendHUD:ClearInGameUI()
          EnterBattleProtect(table.unpack(logic_enter_game.InGameReEnterGameInfo))
          log(bWriteLog and "UnrealNet.HandleNetworkException ReloadingBattle")
        end
      else
        UnrealNet.RetrunToLobbyFromDisconnect(needRelogin)
        log(bWriteLog and "UnrealNet.HandleNetworkException ReturnToLobby")
      end
    end, function()
      log(bWriteLog and "UnrealNet.HandleNetworkException ReturnToLobby")
      UnrealNet.RetrunToLobbyFromDisconnect(needRelogin)
      if logic_enter_game then
        logic_enter_game.InGameShowingReEnter = false
      end
    end)
  elseif UnrealNet.IsNeedShowMsgBox(ErrorMessage) then
    ShowMsgBoxFunc(1, strTile, strMsg, function()
      log(bWriteLog and "ClientEntry ----- sun start ReturnToLobby needRelogin: " .. tostring(needRelogin) .. ", curStatus:" .. curStatus .. ", isWaittingEnterBattle" .. tostring(LobbySystem.isWaittingEnterBattle))
      UnrealNet.RetrunToLobbyFromDisconnect(needRelogin)
    end)
  end
  EventSystem:postEvent(EVENTTYPE_NETWORK, EVENTID_DS_SERVER_CONNECT_FAILED)
end

function UnrealNet.RepListMismatchDetectTrigger(IsDetectRepList, IsDetectRepComponent, InPlayerController, InRepObj, Reason, ErrorMessage)
  log(bWriteLog and "UnrealNet.RepListMismatchDetectTrigger")
  if not slua.isValid(InPlayerController) or not slua.isValid(InRepObj) then
    return
  end
  if IsDetectRepList then
    local bResult = false
    local start_idx, end_idx = string.find(ErrorMessage, "ReceivedBunch FAILED")
    if start_idx then
      bResult = true
    end
    if bResult then
      InPlayerController:ClientRepListReq(InRepObj)
      log(bWriteLog and "UnrealNet.RepListMismatchDetectTrigger ClientRepListReq")
    end
  end
  if IsDetectRepComponent then
    local bResult = false
    local start_idx, end_idx = string.find(ErrorMessage, "ReadContentBlockPayloadFailed")
    if start_idx then
      bResult = true
    end
    if bResult then
      InPlayerController:ClientRepComponentsReq(InRepObj)
      log(bWriteLog and "GameplayCallbacks.RepListMismatchDetectTrigger ClientRepComponentsReq")
    end
  end
end

function UnrealNet.IsNeedShowMsgBox(ErrorMessage)
  if string.find(ErrorMessage, "match_isolation_label") == 1 then
    return false
  end
  if string.find(ErrorMessage, "manor_joint_terminate") then
    return false
  end
  return true
end

function UnrealNet.RetrunToLobbyFromDisconnect(needRelogin)
  if GameStatus.IsInFightingStatus() or LobbySystem.isWaittingEnterBattle then
    local timer_ticker = require("common.time_ticker")
    local ClientEVOConfig = require("client.logic.client_evo_config.client_evo_config")
    ClientEVOConfig.OnBeforeConfirmBackToLobby()
    timer_ticker.AddTimerOnce(0.2, function()
      local logic_loading = require("client.slua.logic.loading.logic_loading")
      logic_loading.ShowLoading(true)
      local ClientEntryHandler = require("client.network.Protocol.ClientEntryHandler")
      ClientEntryHandler.send_giveup_enter_game()
      LobbySystem.ReturnToLobby()
      if needRelogin then
        if not NetManager.bConnected and LobbySystem.CheckOpen(BP_ENUM_IS_QUERY_PLAYER_STETE_AFTER_LOADING) then
          local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
          login_module:reqLoginLobby(true, Enum_LOGIN_REPORT_CFG.EXCEPTION_POP)
        else
          local MatchSystem = require("client.slua.logic.match.logic_match")
          MatchSystem.SetQueryPlayerFlag(true)
        end
      end
      Client.TPerforPlatDisconnectReport(GameFrontendHUD, 16)
      local ExceptionType, SubType, ErrorLog, bShouldWait = table.unpack(LobbySystem.enterGameTimeOutParams)
      LobbySystem.enterGameTimeOutParams = nil
      if ExceptionType ~= "ConnectingTimeout" and ExceptionType ~= "ConnectionTimeout" then
        local ErrorReport = {
          ExceptionType,
          SubType,
          ErrorLog
        }
        UnrealNet.HandleNetworkConnectionClosed("ForceReturnToLobby", table.concat(ErrorReport, "_"))
      end
    end)
  end
end

function UnrealNet.HandleBattleExceptionReport(ExceptionType, ErrorMessage, bShouldWait, ...)
  ExceptionType = FuncUtil.ReplaceIllegalChar(ExceptionType)
  ErrorMessage = FuncUtil.ReplaceIllegalChar(ErrorMessage)
  UnrealNet.HandleNetworkExceptionReport(ExceptionType, "", ErrorMessage)
end

function UnrealNet.OnNetRepSerializeError(ErrorType, RepObjName)
  local CommonMsgBoxMgr = require("client.slua.logic.common.logic_common_msg_box")
  local title = LocUtil.LocalizeResFormat(101001)
  local typeMsg = "ActorChannelError"
  if ErrorType == 2 then
    typeMsg = "LuaNetSerializationError"
  end
  local msg = "Battle network serialization error(" .. typeMsg .. [[
), Please check the client and DS version
RepObjName:]] .. RepObjName .. [[

Or use UGMCheatManager::DumpObjectNetProperties to check the rep-list of the Actor on both DS and client.]]
  CommonMsgBoxMgr.Show(1, title, msg)
end

require("common.time_ticker")
require("game_frontend_hud")
require("client.slua_ui_framework.manager")
require("client.logic.ClientEntry.ClientEntry")
local IngameEntry = require("GameLua.GameCore.Main.ClientGameMain")
IngameEntry.InitInagmeEntry()
require("GameLua.Mod.BaseMod.Client.BattleWindowMgr")
log(bWriteLog and ". GameLua.Mod.BaseMod.Client.BattleWindowMgr")
require("ds_net")
log(bWriteLog and ". ds_net")
require("GameLua.Mod.BaseMod.Client.Security.Gokuba")
log(bWriteLog and ". BaseMod.Client.Security.Gokuba")
require("GameLua.Mod.Lobby.Base.Common.LobbyModUtils")
log(bWriteLog and ". Lobby.Base.Common.LobbyModUtils")
require("common.log_filter")
log(bWriteLog and ". common.log_filter")
local Utility = require("common.utility")
local BPLuaUIManager = require("client.module_framework.BPLuaUIManager")
BPLuaUIManager.InitOnlyOne()
UIManager.Init()
if Client.IsCloudVersion() then
  log(bWriteLog and "[OnUpdateFinished] Client.CloudVersionInitDataPipeline")
  Client.CloudVersionInitDataPipeline()
end
if Client.GetDevicePlatformName() == "Android" or Client.GetDevicePlatformName() == "IOS" then
  local ui_config = require("client.slua.config.base_config")
end
local optSwitch = HDmpveRemote.HDmpveRemoteConfigGetInt("GainCrashLogInfoBackgroundOnInit", 0)
if optSwitch ~= 0 then
  if optSwitch & 1 ~= 0 then
    local DevLogUtils = require("common.DevLogUtils")
    DevLogUtils.OpenDevLog()
  end
  if optSwitch & 2 ~= 0 then
    Client.GainSystemLog()
  end
  log(bWriteLog and "LobbySystem.DoConsoleCmdFromRemoteConfig GainCrashLogInfoBackgroundOnInit=" .. optSwitch)
end
