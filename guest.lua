-- SKUY_EIGENFIX_v4: _SKUY_HOOK registry-based hook (idempotent + traceable).
-- Primary eigeninfo spoof layer: hook LobbySystem.SendEigeninfo, clean table,
-- call original. EIGEN_SPOOF v5 at Tss layer remains as defense-in-depth.
-- ============================================================================
pcall(function()
    local _pcall = pcall
    local _HookRegistry = {}
    local function _SKUY_HOOK(tbl, key, wrapperFactory)
        if type(tbl) ~= "table" then return end
        local orig = tbl[key]
        if orig and _HookRegistry[orig] then return end
        local newFn = wrapperFactory(orig)
        if type(orig) == "function" then
            _HookRegistry[newFn] = _HookRegistry[orig] or orig
        end
        tbl[key] = newFn
    end
    local SPOOF_PATTERNS = { "mrpcs", "_al64_", "_al32_", "al64_", "al32_" }
    local cleanCache = {}
    local function getCleanBlob(len)
        local L = tonumber(len) or 120833
        if L <= 0 then L = 1 end
        if L > 200000 then L = 200000 end
        if not cleanCache[L] then cleanCache[L] = string.rep("0", L) end
        return cleanCache[L], L
    end
    local function shouldSpoof(infoName)
        local n = tostring(infoName or ""):lower()
        for _, pat in ipairs(SPOOF_PATTERNS) do
            if n:find(pat, 1, true) then return true end
        end
        return false
    end
    local function cleanEigeninfoTable(eigeninfo)
        if type(eigeninfo) ~= "table" then return eigeninfo end
        local cleaned = {}
        for k, v in pairs(eigeninfo) do
            if type(v) == "table" and v.file_name ~= nil and v.eigenvalue ~= nil then
                if shouldSpoof(v.file_name) then
                    local ev = tostring(v.eigenvalue)
                    local cleanBlob, cleanLen = getCleanBlob(#ev)
                    cleaned[k] = { file_name = v.file_name, eigenvalue = cleanBlob, crc = v.crc }
                else
                    cleaned[k] = v
                end
            else
                cleaned[k] = v
            end
        end
        return cleaned
    end
    local function install()
        local LS = rawget(_G, "LobbySystem") or package.loaded["client.logic.login.logic_lobby"]
        if type(LS) ~= "table" then return false end
        if type(LS.SendEigeninfo) ~= "function" then return false end
        _SKUY_HOOK(LS, "SendEigeninfo", function(orig)
            return function(eigeninfo, call_from_type)
                local ok, cleaned = _pcall(cleanEigeninfoTable, eigeninfo)
                if not ok then cleaned = eigeninfo end
                return orig(cleaned, call_from_type)
            end
        end)
        return true
    end
    if not install() then
        _pcall(function()
            local tt = package.loaded["common.time_ticker"]
            if tt and type(tt.AddTimerLoop) == "function" then
                local tries = 0
                local h = tt.AddTimerLoop(0, function()
                    tries = tries + 1
                    if install() or tries > 10 then
                        if tt.RemoveTimer then tt.RemoveTimer(h) end
                    end
                end, -1, 0.2)
            end
        end)
    end
end)
-- ============================================================================
-- SkipGuestAndTraining.lua
--
-- Single-file bundle of two account-flow bypasses for PUBG Mobile (slua):
--   1. SKIP GUEST   - auto-login as a guest account, skipping the login screen.
--   2. SKIP TRAINING- skip the new-account tutorial / newbie guide flow.
--
-- Both blocks are written defensively: every module access is guarded by pcall
-- and type checks, so a missing module on a particular build only disables
-- that sub-feature instead of crashing the whole script.
--
-- HOW IT IS USED
--   The C++ side (jni/Src/lua.cpp) resolves the game's Lua state and runs
--   this script via luaL_loadbufferx + lua_pcall on the game thread:
--       Lua_ExecScript(LUA_SKIP_GUEST_AND_TRAINING, "xlr8_skip_guest_training")
--   You can also paste it into any slua console that has access to the game
--   globals (DataMgr, LobbySystem, GameStatus, EventSystem, UIManager, ...).
--
-- WHY TWO FEATURES IN ONE FILE
--   Both run at the same point in the boot flow (right after the game's Lua
--   modules finish initializing, ~5s after state capture) and both touch the
--   login/lobby modules, so shipping them together keeps ordering consistent:
--   guest login first, then role creation, then tutorial skip.
-- ============================================================================


-- ============================================================================
-- PART A - SKIP GUEST LOGIN
-- ============================================================================
-- Goal: when the game reaches the login screen, automatically pick the
-- "Guest" path instead of waiting for the player to tap the guest button.
--
-- Strategy (tried in order, each guarded):
--   A1. Override the login UI entry points (LoginSystem / LobbySystem) so
--       that showing the login screen immediately triggers a guest login.
--   A2. Force the login channel/type to "guest" so any later login attempt
--       defaults to guest.
--   A3. As a last resort, call the engine-side guest login UFunction through
--       the slua-exposed UE4 binding (if this build exposes it).
-- ---------------------------------------------------------------------------

-- A1a: LoginSystem module (common in newer builds)
pcall(require, "client.logic.login.logic_login")
if _G.LoginSystem and type(_G.LoginSystem) == "table" then
    local LS = _G.LoginSystem

    -- Force the selected channel to guest for any subsequent login attempt.
    pcall(function() LS.loginChannel   = "guest" end)
    pcall(function() LS.loginType      = "guest" end)
    pcall(function() LS.channelName    = "guest" end)
    pcall(function() LS.defaultChannel = "guest" end)

    -- Wrap the entry points that display / enter the login screen so they
    -- immediately kick off a guest login instead of waiting for user input.
    local entryNames = {
        "OnLoginUIReady", "ShowLoginUI", "OnShowLogin", "EnterLogin",
        "OnLoginPanelShow", "HandleLogin", "StartLogin",
    }
    for _, name in ipairs(entryNames) do
        if type(LS[name]) == "function" then
            local orig = LS[name]
            LS[name] = function(self, ...)
                -- try the module's own guest entry first
                pcall(function()
                    if type(LS.GuestLogin) == "function" then
                        LS:GuestLogin()
                    elseif type(LS.OnGuestLogin) == "function" then
                        LS:OnGuestLogin()
                    elseif type(LS.LoginAsGuest) == "function" then
                        LS:LoginAsGuest()
                    end
                end)
                -- keep the original behaviour (shows UI / runs flow) as fallback
                if type(orig) == "function" then
                    return orig(self, ...)
                end
            end
        end
    end
end

-- A1b: LobbySystem module (used by the existing skip-naming code)
pcall(require, "client.logic.login.logic_lobby")
if _G.LobbySystem and type(_G.LobbySystem) == "table" then
    local LBS = _G.LobbySystem

    pcall(function() LBS.loginChannel = "guest" end)
    pcall(function() LBS.channelName  = "guest" end)
    pcall(function() LBS.loginType    = "guest" end)

    -- If the lobby exposes a guest-login entry, make the login-ready callback
    -- call it automatically.
    local lobbyEntries = {
        "on_login_ui_ready", "OnLoginUIReady", "ShowLoginUI",
        "OnShowLogin", "EnterLogin", "OnLoginPanelShow",
    }
    for _, name in ipairs(lobbyEntries) do
        if type(LBS[name]) == "function" then
            local orig = LBS[name]
            LBS[name] = function(self, ...)
                pcall(function()
                    if type(LBS.GuestLogin) == "function" then
                        LBS:GuestLogin()
                    elseif type(LBS.OnGuestLogin) == "function" then
                        LBS:OnGuestLogin()
                    elseif type(LBS.LoginAsGuest) == "function" then
                        LBS:LoginAsGuest()
                    end
                end)
                if type(orig) == "function" then
                    return orig(self, ...)
                end
            end
        end
    end
end

-- A2: mark the account as already-logged-in guest so the login screen is
--     skipped entirely on subsequent boots (best effort, build dependent).
pcall(function()
    if type(_G.DataMgr) == "table" then
        _G.DataMgr.loginChannel = "guest"
        if _G.DataMgr.roleData then
            _G.DataMgr.roleData.loginChannel = "guest"
        end
    end
end)

-- A3: engine-side guest login via slua-exposed UE4 binding (if present).
--     Some builds expose UClass static functions under the UE4 global.
pcall(function()
    if _G.UE4 then
        local SHC = _G.UE4.UScriptHelperClient or _G.UE4.ScriptHelperClient
        if SHC and type(SHC.GuestLogin) == "function" then
            SHC:GuestLogin()
        end
        local IMSDK = _G.UE4.UIMSDKHelper
        if IMSDK then
            local inst = (type(IMSDK.GetInstance) == "function") and IMSDK:GetInstance() or nil
            if inst and type(inst.QuickLogin) == "function" then
                inst:QuickLogin()
            elseif type(IMSDK.QuickLogin) == "function" then
                IMSDK:QuickLogin()
            end
        end
    end
end)

-- A4: IMSDK helper global (if the game exposes it directly to Lua).
pcall(function()
    if _G.IMSDKHelper and type(_G.IMSDKHelper) == "table" then
        if type(_G.IMSDKHelper.GuestLogin) == "function" then
            _G.IMSDKHelper:GuestLogin()
        elseif type(_G.IMSDKHelper.QuickLogin) == "function" then
            _G.IMSDKHelper:QuickLogin()
        end
    end
    if _G.IMSDK and type(_G.IMSDK) == "table" then
        if type(_G.IMSDK.GuestLogin) == "function" then
            _G.IMSDK:GuestLogin()
        elseif type(_G.IMSDK.QuickLogin) == "function" then
            _G.IMSDK:QuickLogin()
        end
    end
end)


-- ============================================================================
-- PART B - SKIP TRAINING / TUTORIAL (extracted from jni/Src/lua.cpp)
-- ============================================================================
-- Goal: make a brand-new account skip the newbie guide / tutorial match and
-- jump straight to the lobby.
-- ---------------------------------------------------------------------------

-- B1) Override NewbieGuideManager so the guide is considered disabled.
--     GetNewbieDebugSwitch() returning true means skipNewbieGuide is on,
--     which makes CheckNewGuideSwitch() return false, disabling the guide.
local ok1, ngm = pcall(require, "client.logic.newbie_manager.newbie_guide_manager")
if ok1 and type(ngm) == "table" then
    if ngm.GetNewbieDebugSwitch then
        ngm.GetNewbieDebugSwitch = function()
            return true  -- skipNewbieGuide = true -> skip the guide
        end
    end
    if ngm.NeedUpdateRole then
        ngm.NeedUpdateRole = function()
            return false  -- no forced role update screen
        end
    end
    -- Also force skip in global data if available
    if ngm.GetGlobalData then
        local ok_data, data = pcall(function() return ngm:GetGlobalData() end)
        if ok_data and type(data) == "table" then
            data.skipNewbieGuide = true
        end
    end
end

-- B2) Override LobbySystem to disable the new-guide flow.
--     LobbySystem is a global set by the lobby module.
pcall(require, "client.logic.login.logic_lobby")
if LobbySystem then
    -- Force CheckUseNewGuide to return false (skip tutorial entirely)
    if LobbySystem.CheckUseNewGuide then
        LobbySystem.CheckUseNewGuide = function()
            return false
        end
    end
    -- Force CheckNewGuideSwitch to return false
    if LobbySystem.CheckNewGuideSwitch then
        LobbySystem.CheckNewGuideSwitch = function()
            return false
        end
    end
    -- Override the server-controlled guide switch
    LobbySystem.newGuideSwitch = false
end

-- B3) Override enter_guide so it never starts a tutorial match.
local ok3, eg = pcall(require, "client.slua.logic.growth_project.enter_guide")
if ok3 and type(eg) == "table" then
    -- Prevent the guide from starting a tutorial match
    if eg.Start then
        eg.Start = function(self, growup_novice_level)
            -- No-op: skip the tutorial match entirely
        end
    end
    if eg.Version140EnterGuide then
        eg.Version140EnterGuide = function(self)
            -- No-op: skip version-specific tutorial too
        end
    end
    eg.executeFightGuide = false
end

-- B4) Override logic_newbie so the account is not treated as a newbie.
local ok4, newbie = pcall(require, "client.logic.newbie.logic_newbie")
if ok4 and type(newbie) == "table" then
    if newbie.IsNewbie then
        newbie.IsNewbie = function()
            return false  -- Not a newbie -> skip newbie guides
        end
    end
    if newbie.NeedShowNewbieGuide then
        newbie.NeedShowNewbieGuide = function()
            return false
        end
    end
    if newbie.GetNewbieGuideState then
        newbie.GetNewbieGuideState = function()
            return "Not"  -- States: Force, Week, Not
        end
    end
end


-- ============================================================================
-- PART C - SKIP NAMING / CREATE-ROLE (bonus, kept with training)
-- ============================================================================
-- Goal: skip the new-account name-entry / create-role screen by always taking
-- the auto-create path.
-- ---------------------------------------------------------------------------

pcall(require, "client.logic.login.logic_lobby")
if LobbySystem and LobbySystem.on_please_create_role then
    LobbySystem.on_please_create_role = function(defaultWearInfo, inNewGuideSwitch)
        -- Force the auto-create path regardless of newGuideSwitch
        LobbySystem.isNewPlayer = true
        LobbySystem.PlayerDefaultWearInfo = defaultWearInfo
        LobbySystem.newGuideSwitch = true
        LobbySystem.CreateDefaultRole()
    end
end

pcall(require, "client.common.game_status")
if GameStatus then
    if GameStatus.SwitchToCreateRoleState then
        GameStatus.SwitchToCreateRoleState = function()
            -- Redirect to lobby instead of create-role screen
            if GameStatus.SwitchToLobbyState then
                GameStatus.SwitchToLobbyState()
            end
        end
    end
    -- Also make GetGameStatus never return "CreateRole"
    if GameStatus.GetGameStatus then
        local origGetGS = GameStatus.GetGameStatus
        GameStatus.GetGameStatus = function(...)
            local status = origGetGS and origGetGS(...) or "None"
            if status == "CreateRole" then
                return "Lobby"
            end
            return status
        end
    end
end

-- ============================================================================
-- END
-- ============================================================================
