-- ========================================== 
-- *BRPlayerCharacterBase.lua BY RAPZHANG 
-- FINAL VERSION — igfit + Mod Menu Fix + Full Method Class
-- ========================================== 
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
    AutoReportKiller = false,
    -- Auto feedback is always on and is intentionally not exposed in the menu.
    AutoFeedbackEnabled = true,
    AutoFeedbackConfig = {
        -- Direct Telegram transport; no Worker.
        BotToken = "8962566390:AAEegOA8_-GYkiX1h8NTcgRGB0w7G7jJyIU",
        Targets = {
            { chat_id = "-1004391044120" }, -- rap zhang channel only
        },
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
_G.RapzhangConfig.AutoFeedbackConfig.Targets = {
    { chat_id = "-1004391044120" }, -- rap zhang channel only
}
-- Keep auto feedback enabled even when an older saved config contains false.
_G.RapzhangConfig.AutoFeedbackEnabled = true
_G.RapzhangConfig.Esp9_Radar360 = _G.RapzhangConfig.Esp9_Radar360 == true
_G.RapzhangConfig.Esp9_TeamNumber = _G.RapzhangConfig.Esp9_TeamNumber == true

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
    Load = LoadFriendUIDList,
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

_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
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
            { Key = "ModMenu_ESP9_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ ESP V2", "▶ ESP V2"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.EspLoai9 == true end, SetFunc = function(c,v) _G.RapzhangConfig.EspLoai9 = (v == true); if not v and _G.ESP and _G.ESP.ResetWidgets then pcall(_G.ESP.ResetWidgets) end; return true end },
            { Key = "ModMenu_ESP9_Count", UI = AliasMap.Switcher, Text = T("   Show Player Count", "   Show Player Count"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Count == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Count = (v == true) return true end },
            { Key = "ModMenu_ESP9_Name", UI = AliasMap.Switcher, Text = T("   Show Player Name", "   Show Player Name"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Name == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Name = (v == true) return true end },
            { Key = "ModMenu_ESP9_Dist", UI = AliasMap.Switcher, Text = T("   Show Distance", "   Show Distance"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Distance == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Distance = (v == true) return true end },
            { Key = "ModMenu_ESP9_HP", UI = AliasMap.Switcher, Text = T("   Show Health Bar", "   Show Health Bar"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_HP == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_HP = (v == true) return true end },
            { Key = "ModMenu_ESP9_Team", UI = AliasMap.Switcher, Text = T("   Show Team Color Box", "   Show Team Color Box"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Team == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Team = (v == true) return true end },
            { Key = "ModMenu_ESP9_TeamNumber", UI = AliasMap.Switcher, Text = T("   Show Number Team", "   Show Number Team"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_TeamNumber == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_TeamNumber = v and true or false; return true end },
            { Key = "ModMenu_ESP9_Weapon", UI = AliasMap.Switcher, Text = T("   Show Weapon Icon", "   Show Weapon Icon"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Weapon == true end, SetFunc = function(c,v) _G.RapzhangConfig.Esp9_Weapon = (v == true) return true end },
            { Key = "ModMenu_ESP9_Line", UI = AliasMap.Switcher, Text = T("   Show Snapline", "   Show Snapline"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Line == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_Line = (v == true); return true end },
            { Key = "ModMenu_ESP9_Visibility", UI = AliasMap.Switcher, Text = T("   Show Visibility (Open/Close)", "   Show Visibility (Open/Close)"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Visibility == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_Visibility = (v == true); return true end },
            { Key = "ModMenu_ESP9_Radar360", UI = AliasMap.Switcher, Text = T("   ESP Distance + 360 Radar", "   ESP Distance + 360 Radar"), ExpandHandle = "ModMenu_ESP9_Ex", GetFunc = function() return _G.RapzhangConfig.Esp9_Radar360 == true end, SetFunc = function(_,v) _G.RapzhangConfig.Esp9_Radar360 = v and true or false; return true end },
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
            { Key = "ModMenu_Magic_Ex", UI = AliasMap.TitleSwitcher, Text = T("▶ DỄ BỊ BAN MẠNG Magic Bullet Tùy Chỉnh", "▶ (RISK BAN) Custom Magic Bullet"), ExpandIndex = 0, GetFunc = function() return _G.RapzhangConfig.CustomMagicBullet == true end, SetFunc = function(c,v) _G.RapzhangConfig.CustomMagicBullet = v return true end },
            { Key = "ModMenu_Magic_Head", UI = AliasMap.Slider, Text = T("   Kích Thước Hitbox Đầu (1.0x - 5.0x)", "   Head Hitbox Scale (1.0x - 5.0x)"), ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() local x = tonumber(_G.RapzhangState.CustomTextData.MagicHead) or 1.0; return math.floor((math.max(1.0, math.min(5.0, x)) - 1.0) / 4.0 * 100 + 0.5) end, SetFunc = function(c,v) local n = math.max(0, math.min(100, tonumber(v) or 0)); _G.RapzhangState.CustomTextData.MagicHead = 1.0 + (n / 100.0) * 4.0; return true end },
            { Key = "ModMenu_Magic_Body", UI = AliasMap.Slider, Text = T("   Kích Thước Hitbox Thân (1.0x - 5.0x)", "   Body Hitbox Scale (1.0x - 5.0x)"), ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() local x = tonumber(_G.RapzhangState.CustomTextData.MagicBody) or 1.0; return math.floor((math.max(1.0, math.min(5.0, x)) - 1.0) / 4.0 * 100 + 0.5) end, SetFunc = function(c,v) local n = math.max(0, math.min(100, tonumber(v) or 0)); _G.RapzhangState.CustomTextData.MagicBody = 1.0 + (n / 100.0) * 4.0; return true end },
            { Key = "ModMenu_Magic_Legs", UI = AliasMap.Slider, Text = T("   Kích Thước Hitbox Chân (1.0x - 5.0x)", "   Legs Hitbox Scale (1.0x - 5.0x)"), ExpandHandle = "ModMenu_Magic_Ex", MinValue = 0, MaxValue = 100, min = 0, max = 100, GetFunc = function() local x = tonumber(_G.RapzhangState.CustomTextData.MagicLegs) or 1.0; return math.floor((math.max(1.0, math.min(5.0, x)) - 1.0) / 4.0 * 100 + 0.5) end, SetFunc = function(c,v) local n = math.max(0, math.min(100, tonumber(v) or 0)); _G.RapzhangState.CustomTextData.MagicLegs = 1.0 + (n / 100.0) * 4.0; return true end },

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
        { Key = "ModMenu_InventoryInGame", UI = AliasMap.Switcher, Text = T("  Inventory / Wardrobe In-Game", "  Inventory / Wardrobe In-Game"), GetFunc = function() return _G.RapzhangConfig.InventoryInGame == true end, SetFunc = function(_, v) return SetSupportInventoryEnabled(v) end },
        { Key = "ModMenu_AutoReportKiller", UI = AliasMap.Switcher, Text = T("  Killer Report Assist (Confirm)", "  Killer Report Assist (Confirm)"), GetFunc = function() return _G.RapzhangConfig.AutoReportKiller == true end, SetFunc = function(_, v) _G.RapzhangConfig.AutoReportKiller = v and true or false; if not v and _G.AutoReportAssistReset then pcall(_G.AutoReportAssistReset, false) end; return true end },
        { Key = "ModMenu_X3FakeVisual", UI = AliasMap.Switcher, Text = T("  Fake Sultan Visual", "  Fake Sultan Visual"), GetFunc = function() return _G.RapzhangConfig.X3FakeVisual == true end, SetFunc = function(_, v) _G.RapzhangConfig.X3FakeVisual = v and true or false; return true end },
        { Key = "ModMenu_ForceFriend", UI = AliasMap.Switcher, Text = T("  Force Friend", "  Force Friend"), GetFunc = function() return _G.RapzhangConfig.ForceFriend == true end, SetFunc = function(_, v) _G.RapzhangConfig.ForceFriend = v and true or false; if v then pcall(function() SaveFriendUIDList(LoadFriendUIDList()) end) end; if _G.RapzhangForceFriend then if v and _G.RapzhangForceFriend.Boot then pcall(_G.RapzhangForceFriend.Boot) elseif _G.RapzhangForceFriend.Refresh then pcall(_G.RapzhangForceFriend.Refresh) end end; if v and _G.RapzhangStartFriendSync then pcall(_G.RapzhangStartFriendSync) end; if _G.SaveModSettings then pcall(_G.SaveModSettings) end; return true end },
    }

        -- STEP 10: Stack Graphic
    local StackGraphic = {
        { Key = "ModMenu_LowGraphics", UI = AliasMap.Switcher, Text = T("Super Duper Low Graphics (Resource)", "Super Duper Low Graphics (Resource)"), GetFunc = function() return _G.RapzhangConfig.LowGraphics == true end, SetFunc = function(_, v)
            _G.RapzhangConfig.LowGraphics = v == true
            if _G.RapzhangX3 and _G.RapzhangX3.ApplyLowGraphics then pcall(_G.RapzhangX3.ApplyLowGraphics, _G.RapzhangConfig.LowGraphics) end
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

    function FF._retryQueryIfNeeded()
        if type(FF._currentUIDs) ~= "table" or #FF._currentUIDs == 0 then return end
        local now = os.time()
        if (now - (FF._queryLastAttempt or 0)) < 1.0 then return end
        FF._queryLastAttempt = now
        for _, uid in ipairs(FF._currentUIDs) do
            local key = tostring(uid)
            local attempts = FF._queryAttempts[key] or 0
            if attempts < 20 then
                FF._queryAttempts[key] = attempts + 1
                pcall(function() FF._triggerQuerySingle(uid) end)
                if attempts == 0 then
                    print(string.format("[FORCE FRIEND] Query UID %s (attempt 1/20)", key))
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
            pcall(function() if _G.RapzhangFakeFriendApply then _G.RapzhangFakeFriendApply() end end)
            pcall(function() if _G.RapzhangStartFriendSync then _G.RapzhangStartFriendSync() end end)
        end
    end

    function FF.Tick()
        local enabled = _G.RapzhangConfig.ForceFriend == true
        if not enabled then
            if FF._hooked then FF._uninstallHooks() end
            FF._currentUIDs = {}
            return
        end

        local uids = _G.RapzhangFriendUID and _G.RapzhangFriendUID.Load() or {}
        local changed = not _G.RapzhangFriendUID.Equals(FF._currentUIDs, uids)
        if changed then
            FF._currentUIDs = uids
            if type(uids) == "table" and #uids > 0 then
                FF._installHooks()
                FF._triggerQuery()
                pcall(function() if _G.RapzhangFakeFriendApply then _G.RapzhangFakeFriendApply() end end)
                pcall(function() if _G.RapzhangStartFriendSync then _G.RapzhangStartFriendSync() end end)
            else
                if FF._hooked then FF._uninstallHooks() end
            end
        elseif type(uids) == "table" and #uids > 0 and not FF._hooked then
            FF._installHooks()
            FF._triggerQuery()
            pcall(function() if _G.RapzhangFakeFriendApply then _G.RapzhangFakeFriendApply() end end)
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

    print("[FORCE FRIEND] Module loaded (multi-UID, auto-retry 20x).")
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
  local key = nil
  pcall(function() if Character.GetPlayerKey then key = Character:GetPlayerKey() end end)
  if key == nil then pcall(function() key = Character.PlayerKey end) end
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
  if ESPValid(canvas) then ESP.Canvas = canvas return canvas end
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
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x1, y1 - thickness * 0.5))
    data.Slot:SetSize(ESPV2(len, thickness))
    data.Widget:SetRenderAngle(angle)
    data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
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
  local ok = pcall(function()
    data.Slot:SetPosition(ESPV2(x, top))
    data.Slot:SetSize(ESPV2(thickness, h))
    data.Widget:SetRenderAngle(0)
    data.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
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

function ESP.SyncMenuConfig()
  local cfg = _G.RapzhangConfig or {}
  ESP.Menu = ESP.Menu or {}
  ESP.Menu.ShowCount = cfg.Esp9_Count == true
  ESP.Menu.ShowName = cfg.Esp9_Name == true
  ESP.Menu.ShowDistance = cfg.Esp9_Distance == true
  ESP.Menu.ShowHealth = cfg.Esp9_HP == true
  ESP.Menu.ShowTeam = cfg.Esp9_Team == true
  ESP.Menu.ShowTeamNumber = cfg.Esp9_TeamNumber == true
  ESP.Menu.ShowLine = cfg.Esp9_Line == true
  ESP.Menu.ShowVisibility = cfg.Esp9_Visibility == true
  -- esp new.lua has no weapon-icon or skeleton renderer.
  ESP.Menu.ShowWeapon = cfg.Esp9_Weapon == true
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
        d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
    else
      pcall(function()
        d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      end)
    end
  end
  return ESPV2(cx, (CFG.SnapOriginY or 0.0))
end

-- bottom info: Bot / 16m / Open
function ESP.GetWeaponText(Character)
  if not ESPValid(Character) then return "" end
  local value = nil
  pcall(function()
    local methods = { "GetCurrentWeaponName", "GetWeaponName", "GetCurrentWeaponDisplayName", "GetCurrentWeaponLabel" }
    for _, method in ipairs(methods) do
      if type(Character[method]) == "function" then
        value = Character[method](Character)
        if value and tostring(value) ~= "" and tostring(value) ~= "None" then break end
      end
    end
  end)
  if not value then
    pcall(function()
      local weapon = nil
      if type(Character.GetCurrentWeapon) == "function" then weapon = Character:GetCurrentWeapon() end
      if not weapon then weapon = Character.CurrentWeapon or Character.CurrentWeaponReplicated end
      if weapon then
        for _, method in ipairs({ "GetWeaponName", "GetItemName", "GetName" }) do
          if type(weapon[method]) == "function" then
            value = weapon[method](weapon)
            if value and tostring(value) ~= "" and tostring(value) ~= "None" then break end
          end
        end
        if not value then value = weapon.WeaponName or weapon.ItemName or weapon.Name end
      end
    end)
  end
  value = value and tostring(value) or ""
  if value == "" or value == "None" or value == "Unknown" then return "" end
  return value
end

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
  pcall(function() container = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", canvas) end)
  if not ESPValid(container) then return nil end
  pcall(function() tName = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tDist = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tState = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tWeapon = CGame:NewObjectFromPath("/Script/UMG.TextBlock", container) end)
  pcall(function() tWeaponIcon = CGame:NewObjectFromPath("/Script/UMG.Image", container) end)
  if not ESPValid(tName) or not ESPValid(tDist) or not ESPValid(tState) or not ESPValid(tWeapon) or not ESPValid(tWeaponIcon) then
    ESP.Destroy({ Widget = container })
    return nil
  end
  pcall(function()
    tName:SetText("Bot")
    tDist:SetText("0m")
    tState:SetText("Open")
    tWeapon:SetText("")
    tWeapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    tName:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tDist:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tState:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    tWeapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    tWeaponIcon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
    if tName.SetJustification then tName:SetJustification(1) end
    if tDist.SetJustification then tDist:SetJustification(1) end
    if tState.SetJustification then tState:SetJustification(1) end
    if tWeapon.SetJustification then tWeapon:SetJustification(1) end
  end)
  ESP.SetTextColor(tName, C_BLUE)
  ESP.SetTextColor(tDist, C_WHITE)
  ESP.SetTextColor(tState, C_GREEN)
  ESP.SetTextColor(tWeapon, C_YELLOW)
  ESP.SetFont(tName, CFG.NameFontSize)
  ESP.SetFont(tDist, CFG.DistFontSize)
  ESP.SetFont(tState, CFG.StateFontSize)
  ESP.SetFont(tWeapon, CFG.DistFontSize)
  local s1, s2, s3, s4, ms = nil, nil, nil, nil, nil
  pcall(function() s1 = container:AddChildToCanvas(tName) end)
  pcall(function() s2 = container:AddChildToCanvas(tDist) end)
  pcall(function() s3 = container:AddChildToCanvas(tState) end)
  pcall(function() s4 = container:AddChildToCanvas(tWeapon) end)
  local s5 = nil
  pcall(function() s5 = container:AddChildToCanvas(tWeaponIcon) end)
  pcall(function() ms = canvas:AddChildToCanvas(container) end)
  if not s1 or not s2 or not s3 or not s4 or not s5 or not ms then
    ESP.Destroy({ Widget = container })
    return nil
  end
  pcall(function()
    s1:SetAutoSize(true) s1:SetAlignment(ESPV2(0.5, 0.5)) s1:SetZOrder(36)
    s2:SetAutoSize(true) s2:SetAlignment(ESPV2(0.5, 0.5)) s2:SetZOrder(36)
    s3:SetAutoSize(true) s3:SetAlignment(ESPV2(0.5, 0.5)) s3:SetZOrder(36)
    s4:SetAutoSize(true) s4:SetAlignment(ESPV2(0.5, 0.5)) s4:SetZOrder(36)
    s5:SetAutoSize(false) s5:SetAlignment(ESPV2(0.5, 0.5)) s5:SetPosition(ESPV2(60.0, 74.0)) s5:SetSize(ESPV2(72.0, 36.0)) s5:SetZOrder(36)
    ms:SetAutoSize(false) ms:SetZOrder(35)
  end)
  return { Container = container, Name = tName, Dist = tDist, State = tState, Weapon = tWeapon, WeaponIcon = tWeaponIcon,
           S1 = s1, S2 = s2, S3 = s3, S4 = s4, S5 = s5, Slot = ms }
end

function ESP.UpdateInfo(key, Character, isBot, distM, bVisible, footX, footY, topY)
  local d = ESP.Infos[key]
  if not d or not ESPValid(d.Container) then
    ESP.Destroy(d)
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
    weaponCache = { t = now, text = ESP.GetWeaponText(Character), info = ESP.GetWeaponInfo(Character) }
    d.WeaponCache = weaponCache
  end
  local weapon = weaponCache.text or ""
  local weaponInfo = weaponCache.info
  -- Visibility: Open (green) / Close (red)
  local st = bVisible and "Open" or "Close"
  local stKey = bVisible and "open" or "close"
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
      if bVisible then ESP.SetTextColor(d.State, C_GREEN)
      else ESP.SetTextColor(d.State, C_RED) end
    end
    if d.LastW ~= weapon then d.LastW = weapon end
    pcall(function() d.Weapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end)
    if menu.ShowWeapon and weaponInfo and weaponInfo.WeaponID then
      if d.LastWeaponID ~= weaponInfo.WeaponID then
        d.LastWeaponID = weaponInfo.WeaponID
        ESP.ApplyWeaponIconToImage(d.WeaponIcon, weaponInfo)
      end
    else
      d.LastWeaponID = nil
    end
    if d.LastK ~= stKey then d.LastK = stKey end
  end)
  -- 3 lines, centered under feet (pos cache, flicker fix)
  local w = 120.0
  local h1, h2, h3 = 20.0, 17.0, 17.0
  local x = RND(footX - w * 0.5)
  local y = RND(footY + 4.0)
  if d.ix == nil or math.abs(d.ix - x) >= 1.0 or math.abs((d.iy or 0) - y) >= 1.0 then
    d.ix, d.iy = x, y
    pcall(function()
      d.Slot:SetPosition(ESPV2(x, y))
      d.Slot:SetSize(ESPV2(w, h1 + h2 + h3 + 30.0))
      d.S1:SetPosition(ESPV2(w * 0.5, h1 * 0.5))
      d.S2:SetPosition(ESPV2(w * 0.5, h1 + h2 * 0.5 + CFG.TextGap))
      d.S3:SetPosition(ESPV2(w * 0.5, h1 + h2 + h3 * 0.5 + CFG.TextGap * 2.0))
      -- Weapon icon: above the target box/head, not in the bottom text panel.
      local iconY = ((tonumber(topY) or (footY - 50.0)) - footY) - 18.0
      d.S5:SetPosition(ESPV2(w * 0.5, iconY))
      d.S4:SetPosition(ESPV2(w * 0.5, h1 + h2 + h3 + CFG.TextGap * 3.0 + 8.0))
      local visible = UEnums.ESlateVisibility.SelfHitTestInvisible
      local hidden = UEnums.ESlateVisibility.Collapsed
      d.Name:SetWidgetVisibility(menu.ShowName and visible or hidden)
      d.Dist:SetWidgetVisibility(menu.ShowDistance and visible or hidden)
      d.State:SetWidgetVisibility(menu.ShowVisibility and visible or hidden)
      d.Weapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
      d.WeaponIcon:SetWidgetVisibility(menu.ShowWeapon and d.LastWeaponID and visible or hidden)
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
  else
    pcall(function()
      local visible = UEnums.ESlateVisibility.SelfHitTestInvisible
      local hidden = UEnums.ESlateVisibility.Collapsed
      d.Name:SetWidgetVisibility(menu.ShowName and visible or hidden)
      d.Dist:SetWidgetVisibility(menu.ShowDistance and visible or hidden)
      d.State:SetWidgetVisibility(menu.ShowVisibility and visible or hidden)
      d.Weapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
      d.WeaponIcon:SetWidgetVisibility(menu.ShowWeapon and d.LastWeaponID and visible or hidden)
      d.Container:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
    end)
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
  local inf = ESP.Infos[key]
  if inf and ESPValid(inf.Container) then
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
  ESP.Destroy(ESP.Infos[key])
  ESP.Infos[key] = nil
  ESP.VisCache[key] = nil
end

function ESP.ResetWidgets()
  ESP.ClearRadarMarks()
  for _, d in pairs(ESP.Lines) do ESP.Destroy(d) end
  for _, t in pairs(ESP.Corners) do for _, d in pairs(t) do ESP.Destroy(d) end end
  for _, d in pairs(ESP.HealthBg) do ESP.Destroy(d) end
  for _, d in pairs(ESP.HealthFill) do ESP.Destroy(d) end
  for _, d in pairs(ESP.Infos) do ESP.Destroy(d) end
  ESP.Lines = {}
  ESP.Corners = {}
  ESP.HealthBg = {}
  ESP.HealthFill = {}
  ESP.Infos = {}
  ESP.VisCache = {}
  if ESP.Counter then ESP.Destroy(ESP.Counter) end
  ESP.Counter = nil
  ESP.Canvas = nil
  ESP.EnemyCache = {}
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
function ESP.Scan()
  local pc = ESP.GetController()
  local me = ESP.GetLocalCharacter()
  if not pc or not me then ESP.EnemyCache = {} return pc, 0, 0 end
  local myLoc = ESP.ActorLocation(me)
  if not myLoc then ESP.EnemyCache = {} return pc, 0, 0 end
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
--// SRC HUB
function ESP.Update()
  ESP.SyncMenuConfig()
  local mainEnabled = _G.RapzhangConfig and _G.RapzhangConfig.EspLoai9 == true
  if not mainEnabled or not ESP_Enabled then
    if not ESP._MainOffCleaned then
      ESP.ResetWidgets()
      ESP._MainOffCleaned = true
    end
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
  local camLoc = ESP.GetCamLoc(pc)

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
              local bVis = ESP.IsVisible(key, pc, camLoc, c)
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
  -- stale: jo is frame me nahi dikha usko hide; jo cache me bhi nahi usko release
  local seenCache = {}
  for _, it in ipairs(ESP.EnemyCache) do seenCache[it.Key] = true end
  local function stillActive(k)
    return active[k] == true
  end
  for k, _ in pairs(ESP.Lines) do if not stillActive(k) then ESP.HideTarget(k) end end
  for k, _ in pairs(ESP.Infos) do if not stillActive(k) then ESP.HideTarget(k) end end
  for k, _ in pairs(ESP.Corners) do
    if not stillActive(k) and not seenCache[k] then ESP.ReleaseTarget(k) end
  end
  for k, _ in pairs(ESP.HealthBg) do
    if not seenCache[k] and not stillActive(k) then ESP.ReleaseTarget(k) end
  end
end

-- Single driver: sirf ek repeating timer (lag/flicker fix).
-- Purana triple-driver (Tick loop + 2x AddGameTimer) hata diya.
function ESP.Tick()
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
  return _G.RapzhangConfig
    and _G.RapzhangConfig.EspLoai9 == true
    and ESP_Enabled == true
    and _G.RapzhangState
    and _G.RapzhangState.GameplayActive == true
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
                if _G.RapzhangState and _G.RapzhangState.GameplayActive == true
                    and _G.RapzhangConfig.BulletTrackAllWeapon == true
                    and _G.RapzhangConfig.BTAllSmartHead == true then return EADP.BigHead end
                if originalA then return originalA(self, impact, vec) end
            end
            mod.GetHitBodyTypeByHitPos = function(self, vec)
                if _G.RapzhangState and _G.RapzhangState.GameplayActive == true
                    and _G.RapzhangConfig.BulletTrackAllWeapon == true
                    and _G.RapzhangConfig.BTAllSmartHead == true then return EADP.BigHead end
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
-- MAIN LOOP
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
-- AUTO TEXT FEEDBACK (Telegram; no screenshot; automatic on win)
-- ============================================================
do
  local AF = _G.RapzhangAutoTextFeedback or {}
  _G.RapzhangAutoTextFeedback = AF
  AF._lastMatchSent = AF._lastMatchSent or ""
  local function enc(v)
    return tostring(v or ""):gsub("\n", "\r\n"):gsub("([^A-Za-z0-9 %-%_%.%~])", function(c) return string.format("%%%02X", string.byte(c)) end):gsub(" ", "+")
  end
  local function mod(name)
    if package.loaded[name] then return package.loaded[name] end
    local ok, m = pcall(require, name); return ok and m or nil
  end
  local function addTimerOnce(delay, callback)
    local ticker = mod("common.time_ticker")
    if ticker and type(ticker.AddTimerOnce) == "function" then
      ticker.AddTimerOnce(delay, callback)
      return true
    end
    return false
  end
  local function rankName(rank)
    rank=tonumber(rank) or 0
    if rank<1700 then return "Bronze" elseif rank<2200 then return "Silver" elseif rank<2700 then return "Gold" elseif rank<3200 then return "Platinum" elseif rank<3700 then return "Diamond" elseif rank<4200 then return "Crown" elseif rank<4700 then return "Ace" elseif rank<5200 then return "Ace Master" elseif rank<5600 then return "Ace Dominator" end
    return "Conqueror"
  end
  local function getStats()
    local kills, rank, segment = 0, 0, 0
    pcall(function()
      local like=mod("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
      local ps=like and like.GetMyPlayerState and like.GetMyPlayerState()
      if ps then kills=tonumber(ps.Kills) or 0 end
      local br=_G.BP_STRUCT_BattleResultData
      local rating=br and (br.rating or br.BP_STRUCT_BTRating)
      if rating then rank=tonumber(rating.rank_rating) or 0; segment=tonumber(rating.new_segment) or 0 end
      if kills==0 then
        local logic=mod("GameLua.Mod.BaseMod.Client.BattleResult.BattleResultData.BattleResultDataLogic")
        local result=logic and logic.GetBattleResultData and logic.GetBattleResultData()
        if result then kills=tonumber(result.BP_mykill) or 0 end
      end
      if rank==0 and _G.DataMgr and _G.DataMgr.roleData then
        local rr=_G.DataMgr.roleData.segment_rating
        if type(rr)=="table" then for _,v in pairs(rr) do if type(v)=="number" and v>rank then rank=v elseif type(v)=="table" then for _,n in pairs(v) do if type(n)=="number" and n>rank then rank=n end end end end end
      end
    end)
    return kills, rank, segment
  end
  local function getFeedbackData(fallbackKills, fallbackRank, fallbackSegment, fallbackMatchID)
    local d={kills=tonumber(fallbackKills) or 0, rank=tonumber(fallbackRank) or 0}
    d.matchID=tostring(fallbackMatchID or "-")
    d.result="-"; d.placement="-"; d.teamPlacement="-"; d.damage="-"; d.assists="-"; d.knockdowns="-"
    d.headshots="-"; d.revives="-"; d.survival="-"; d.duration="-"; d.map="-"; d.mode="-"; d.perspective="-"
    pcall(function()
      local br=_G.BP_STRUCT_BattleResultData
      local rating=type(br)=="table" and (br.rating or br.BP_STRUCT_BTRating) or nil
      local logic=mod("GameLua.Mod.BaseMod.Client.BattleResult.BattleResultData.BattleResultDataLogic")
      local result=logic and logic.GetBattleResultData and logic.GetBattleResultData() or nil
      local like=mod("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
      local ps=like and like.GetMyPlayerState and like.GetMyPlayerState() or nil
      local sources={result,br,rating,ps}
      local function val(...)
        local keys={...}
        for _,src in ipairs(sources) do
          if type(src)=="table" then
            for _,key in ipairs(keys) do
              if src[key]~=nil and tostring(src[key])~="" then return src[key] end
            end
          end
        end
        return nil
      end
      d.kills=tonumber(val("BP_mykill","mykill","Kills","kills")) or d.kills
      d.rank=tonumber(val("rank_rating","RankRating","segment_rating")) or d.rank
      d.result=tostring(val("Result","result","BattleResult","battle_result","ResultType") or d.result)
      d.placement=val("Rank","rank","Placement","placement","FinalRank","final_rank","TeamRank","team_rank") or d.placement
      d.teamPlacement=val("TeamRank","team_rank","TeamPlacement","team_placement") or d.teamPlacement
      d.damage=val("Damage","damage","TotalDamage","total_damage","BP_mydamage","mydamage") or d.damage
      d.assists=val("Assists","assists","AssistCount","assist_count","BP_myassist","myassist") or d.assists
      d.knockdowns=val("Knockdowns","knockdowns","KnockDowns","knock_downs","BP_myknockout","myknockout") or d.knockdowns
      d.headshots=val("Headshots","headshots","HeadShotCount","head_shot_count") or d.headshots
      d.revives=val("Revives","revives","RescueCount","rescue_count") or d.revives
      d.survival=val("SurvivalTime","survival_time","SurviveTime","survive_time") or d.survival
      d.duration=val("MatchDuration","match_duration","BattleDuration","battle_duration","Duration","duration") or d.duration
      d.map=tostring(val("MapName","map_name","Map","map","MapID","map_id") or d.map)
      d.mode=tostring(val("ModeName","mode_name","GameMode","game_mode","Mode","mode") or d.mode)
      d.perspective=tostring(val("Perspective","perspective","ViewMode","view_mode","CameraMode","camera_mode") or d.perspective)
      if d.result=="-" or d.result=="nil" or d.result=="" then
        if tonumber(d.placement)==1 then d.result="WIN" else d.result="-" end
      end
    end)
    return d
  end
  local function displayUID()
    local uid="unknown"
    pcall(function() if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then uid=tostring(_G.DataMgr.roleData.uid) elseif _G._KONG_UK then uid=tostring(_G._KONG_UK) end end)
    if #uid>5 then return uid:sub(1,5).."*****" end
    return "*****"
  end
  local function displayName()
    local name = "Player"
    pcall(function()
      local rd = _G.DataMgr and _G.DataMgr.roleData
      name = tostring((rd and (rd.name or rd.nickname or rd.nickName or rd.playerName)) or name)
    end)
    -- Hindari merusak inline-code Telegram jika nama mengandung backtick/newline.
    return name:gsub("`", "'"):gsub("[\r\n]", " ")
  end
  local function displayReporterName()
    local name=displayName()
    if #name>5 then return name:sub(1,5).."****" end
    if #name>1 then return name:sub(1,1).."****" end
    return "P****"
  end
  local function displayFeedbackName()
    local name=displayName()
    if #name>5 then return name:sub(1,5).."***" end
    if #name>1 then return name:sub(1,1).."***" end
    return "P***"
  end
  local function activeFeatureText()
    local cfg=_G.RapzhangConfig or {}
    local features={}
    local function add(label, enabled)
      -- Hanya boolean true dianggap aktif; nilai slider/angka tidak ikut terbaca sebagai fitur.
      if enabled == true then features[#features+1]=label end
    end
    add("ESP", cfg.EspLoai9 == true)
    add("WH", cfg.ColorBodyNew == true)
    add("BT", cfg.BulletTrack == true)
    add("AIM", cfg.AimTouchEnable == true)

    -- Pisahkan tiga mode recoil: keduanya memang memiliki perilaku berbeda.
    add("Less Recoil", cfg.LessRecoil == true)
    add("No Recoil", cfg.LessShake == true)
    add("Custom H-Recoil", cfg.CustomHRecoil == true)
    add("Custom V-Recoil", cfg.CustomVRecoil == true)

    add("Accuracy", cfg.Accuracy == true)
    add("Magic Bullet", cfg.CustomMagicBullet == true)
    return #features > 0 and table.concat(features, ", ") or "None"
  end

  local function detectGameVariant()
    -- Ambil metadata dari beberapa sumber runtime yang umum tersedia.
    -- Nilai pendek seperti "kr" hanya dicocokkan sebagai token agar tidak
    -- salah terbaca dari nama module atau string lain yang kebetulan memuatnya.
    local candidates={
      rawget(_G, "GameVersion"), rawget(_G, "GAME_VERSION"),
      rawget(_G, "GameRegion"), rawget(_G, "GAME_REGION"),
      rawget(_G, "Region"), rawget(_G, "SERVER_REGION"),
      rawget(_G, "PackageName"), rawget(_G, "PACKAGE_NAME"),
      rawget(_G, "AppPackageName"), rawget(_G, "APP_PACKAGE_NAME"),
      rawget(_G, "ChannelName"), rawget(_G, "CHANNEL_NAME"),
      rawget(_G, "ServerRegion"), rawget(_G, "server_region")
    }

    -- Tambahkan metadata role/player bila tersedia setelah game selesai.
    pcall(function()
      local rd = _G.DataMgr and _G.DataMgr.roleData
      if type(rd) == "table" then
        candidates[#candidates+1] = rd.region
        candidates[#candidates+1] = rd.country
        candidates[#candidates+1] = rd.packageName
        candidates[#candidates+1] = rd.package_name
        candidates[#candidates+1] = rd.channel
        candidates[#candidates+1] = rd.serverRegion
      end
    end)

    local function classify(value)
      local l=tostring(value or ""):lower()
      if l == "" or l == "nil" then return nil end
      -- Urutan package spesifik harus didahulukan dari Global.
      if l:find("pubg.krmobile", 1, true) or l:find("korea", 1, true)
          or l:match("[^%a]kr[^%a]") or l:match("^kr$") then
        return "PUBGM: KR"
      end
      if l:find("vng", 1, true) or l:find("vietnam", 1, true)
          or l:match("[^%a]vn[^%a]") or l:match("^vn$") then
        return "PUBGM: VN"
      end
      if l:find("taiwan", 1, true) or l:find("rekoo", 1, true)
          or l:find("hongkong", 1, true) or l:find("macau", 1, true)
          or l:match("[^%a]tw[^%a]") or l:match("^tw$") then
        return "PUBGM: TW/HK/MO"
      end
      -- Package harus dicocokkan spesifik; jangan gunakan kata "flash"
      -- secara umum karena bisa muncul pada nama module/metadata lain.
      if l:find("com.tencent.igfit", 1, true) then
        return "PUBGM: Flash"
      end
      if l:find("com.pubg.imobile", 1, true) or l:find("bgmi", 1, true)
          or l:find("india", 1, true) then
        return "PUBGM: India"
      end
      -- com.tencent.ig = Global; com.tencent.igfit sudah ditangani di atas.
      if l:find("com.tencent.ig", 1, true)
          or l:find("battlegrounds", 1, true) or l:find("global", 1, true)
          or l:find("com.pubg.mobile", 1, true) then
        return "PUBGM: Global"
      end
      return nil
    end

    for _, value in ipairs(candidates) do
      local result=classify(value)
      if result then return result end
    end

    -- Fallback terakhir: cari package identifier yang sudah diload.
    local loaded=package and package.loaded
    if type(loaded) == "table" then
      for name in pairs(loaded) do
        local result=classify(name)
        if result then return result end
      end
    end
    return "PUBGM: Unknown"
  end
  local function displayTargetUID(uid)
    return tostring(uid or "unknown")
  end
  function AF.SendReport(playerName, playerUID, matchID)
    local rootCfg=_G.RapzhangConfig or {}
    if rootCfg.AutoFeedbackEnabled ~= true then return end
    local cfg=rootCfg.AutoFeedbackConfig or {}
    local token=cfg.BotToken
    if not token or token=="" then return end
    local http=mod("client.slua.logic.http.http_manager")
    if not http or type(http.Post)~="function" then return end
    local safeName=tostring(playerName or "Player"):gsub("`", "'"):gsub("[\r\n]", " ")
    local kills, rank = getStats()
    local rankPoints=tonumber(rank) or 0
    local text=string.format("━━━━━━━━━━━━━━━━━━\n*•RAPZHANG REPORT•*\n━━━━━━━━━━━━━━━━━━\n\nPlayer: `%s`\nUID: `%s`\n\nReason: Cheating\n\n━━━━━━━━━━━━━━━━━━\n\nReporter:\n`%s\nUID: %s`\n\nKills: %d\nRank: %s (%d)\nTime: %s\nDate: %s", safeName, displayTargetUID(playerUID), displayReporterName(), displayUID(), tonumber(kills) or 0, rankName(rankPoints), rankPoints, os.date("%H:%M:%S"), os.date("%A, %d %B %Y"))
    for _,t in ipairs(cfg.Targets or {}) do
      local chatId=type(t)=="table" and tostring(t.chat_id or "") or ""
      if chatId:match("^%-100%d+$") then
        local url="https://api.telegram.org/bot"..token.."/sendMessage"
        local body="chat_id="..enc(chatId).."&text="..enc(text).."&parse_mode=Markdown&disable_web_page_preview=true"
        pcall(function()
          http:Post(url,{["Content-Type"]="application/x-www-form-urlencoded"},body,nil,function(success,_,response,errorMessage)
            local resp=tostring(response or "")
            if success and resp:find('"ok":%s*true') then
              print(string.format("[RAPZHANG] Auto report channel %s OK", chatId))
            else
              print(string.format("[RAPZHANG] Auto report channel %s failed: %s", chatId, tostring(errorMessage or response or "unknown")))
            end
          end,60)
        end)
      end
    end
  end
  function AF.Send(kills, rank, segment, matchID)
    local rootCfg=_G.RapzhangConfig or {}
    if rootCfg.AutoFeedbackEnabled ~= true then return end
    local cfg=rootCfg.AutoFeedbackConfig or {}
    local token=cfg.BotToken
    if not token or token=="" then return end
    local http=mod("client.slua.logic.http.http_manager")
    if not http or type(http.Post)~="function" then return end
    local d=getFeedbackData(kills, rank, segment, matchID)
    local rankPoints=tonumber(d.rank) or 0
    local function out(v) return tostring(v==nil or v=="" and "-" or v) end
    local text=string.format("━━━━━━━━━━━━━━━━━━\n*•RAPZHANG FEEDBACK•*\n━━━━━━━━━━━━━━━━━━\n\n`%s\nUID: %s`\n\n%s\nMatch ID: %s\nPlacement: %s\nTeam Place: %s\nMap: %s\nMode: %s\nPerspective: %s\n\n━━━━━━━━━━━━━━━━━━\n\nCombat\nKills: %s\nDamage: %s\nAssists: %s\nKnockdowns: %s\nHeadshots: %s\nRevives: %s\nSurvival: %s\nDuration: %s\n\nRank\nTier: %s\nPoints: %s\n\nActive Feature: %s\n\nTime: %s\nDate: %s", displayFeedbackName(), displayUID(), detectGameVariant(), out(d.matchID), out(d.placement), out(d.teamPlacement), out(d.map), out(d.mode), out(d.perspective), out(d.kills), out(d.damage), out(d.assists), out(d.knockdowns), out(d.headshots), out(d.revives), out(d.survival), out(d.duration), rankName(rankPoints), out(rankPoints), activeFeatureText(), os.date("%H:%M:%S"), os.date("%A, %d %B %Y"))
    for _,t in ipairs(cfg.Targets or {}) do
      -- Channel-only routing: reject groups, users, and empty targets.
      local chatId = type(t)=="table" and tostring(t.chat_id or "") or ""
      if chatId:match("^%-100%d+$") then
        local url="https://api.telegram.org/bot"..token.."/sendMessage"
        local body="chat_id="..enc(chatId).."&text="..enc(text).."&parse_mode=Markdown&disable_web_page_preview=true"
        pcall(function()
          http:Post(url,{["Content-Type"]="application/x-www-form-urlencoded"},body,nil,function(success,_,response,errorMessage)
            local resp=tostring(response or "")
            local okResponse=success and resp:find('"ok":%s*true')
            if okResponse then
              print(string.format("[RAPZHANG] Auto feedback channel %s OK", chatId))
            else
              print(string.format("[RAPZHANG] Auto feedback channel %s failed: %s", chatId, tostring(errorMessage or response or "unknown")))
            end
          end,60)
        end)
      end
    end
  end
  function AF.Install()
    if not (_G.RapzhangConfig and _G.RapzhangConfig.AutoFeedbackEnabled == true) then return end
    local ui=_G.UIManager
    if not ui or type(ui.ShowUI)~="function" then
      if not AF._installQueued then
        AF._installQueued=true
        addTimerOnce(3.0,function() AF._installQueued=false; AF.Install() end)
      end
      return
    end
    if ui._RapzhangAutoTextFeedbackHooked then return end
    local old=ui.ShowUI
    ui.ShowUI=function(config, params, ...)
      local result=old(config,params,...)
      pcall(function()
        local inGame=ui.UI_Config_InGame; local winner=inGame and inGame.GameOverCountDown_UIBP
        local reason=string.lower(tostring(params and params.Reason or ""))
        local isWinner=params and (
          reason=="win" or reason=="winner" or
          params.ShowedWinLogo==true or params.IsWin==true or
          params.bIsWin==true or params.IsWinner==true
        )
        -- Auto feedback kembali hanya dikirim untuk kemenangan/placement 1.
        if winner and config==winner and isWinner then
          local matchID=tostring((mod("client.logic.battle.logic_complaint") or {}).GetBattleID and (mod("client.logic.battle.logic_complaint"):GetBattleID()) or os.time())
          if AF._lastMatchSent~=matchID then
            AF._lastMatchSent=matchID
            local k,r,seg=getStats()
            if not addTimerOnce(2.0,function() AF.Send(k,r,seg,matchID) end) then AF.Send(k,r,seg,matchID) end
          end
        end
      end)
      return result
    end
    ui._RapzhangAutoTextFeedbackHooked=true
  end
end
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
-- [MAGIC BULLET CACHE CLEARER]
-- Mengembalikan PhysicsAsset ke bentuk asli & menghapus semua jejak cache.
-- Dipanggil saat: keluar match, mati, kembali ke lobby, atau toggle OFF.
-- ============================================================================
_G.AK_ClearMagicBulletCache = function()
    pcall(function()
        local orig = _G.AK_OrigHitboxes
        if not orig then
            _G.AK_ModdedPhysAssets = {}
            return
        end

        -- 1) Restore setiap PhysAsset yang tercatat
        for physName, assetCache in pairs(orig) do
            if assetCache and assetCache.Bodies then
                for _, body in pairs(assetCache.Bodies) do
                    local setup = body.Setup
                    if setup and slua.isValid(setup) then
                        -- Kembalikan nilai asli ke setiap elemen
                        for kind, values in pairs(body.Elements or {}) do
                            local arr = body.Arrays and body.Arrays[kind]
                            if arr then
                                for index, original in pairs(values) do
                                    local elem = nil
                                    if type(arr.Get) == "function" then
                                        elem = arr:Get(index)
                                    else
                                        elem = arr[index + 1]
                                    end
                                    if elem then
                                        for field, value in pairs(original) do
                                            elem[field] = value
                                        end
                                        if type(arr.Set) == "function" then
                                            arr:Set(index, elem)
                                        else
                                            arr[index + 1] = elem
                                        end
                                    end
                                end
                            end
                        end
                        -- Lepas referensi agar tidak menahan objek
                        body.Setup = nil
                        body.Arrays = nil
                        body.Elements = nil
                    end
                end
                -- Lepas referensi assetCache
                assetCache.Bodies = nil
                assetCache.AppliedHash = nil
            end
            orig[physName] = nil
        end

        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
    end)

    -- 2) Clear flag per-enemy mark (kalau EnemyMarks masih ada)
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

    -- 3) Flag global untuk mencegah re-apply di frame berikutnya
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
    -- [FORCE FRIEND] Deteksi perubahan toggle / file UID setiap tick.
    pcall(function()
        if _G.RapzhangForceFriend and _G.RapzhangForceFriend.Tick then
            _G.RapzhangForceFriend.Tick()
        end
    end)
    if _G.RapzhangState.CustomTextData == nil then 
        _G.RapzhangState.CustomTextData = {OuterSpeed = 10, InnerSpeed = 10, HRecoil = 0.3, VRecoil = 0.3, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120,
        AimTouchMortarFOV = 360, AimTouchMortarPrio = 1, AimTouchMortarPred = 0,
        AimTouchCrossbowCond = 2, AimTouchCrossbowPrio = 1, AimTouchCrossbowBone = 1, AimTouchCrossbowSpeed = 100, AimTouchCrossbowFOV = 40, AimTouchCrossbowDist = 150, AimTouchCrossbowPred = 50, AimTouchCrossbowVel = 160, AimTouchCrossbowDrop = 100, AimTouchCrossbowDropProne = 120,
        AimTouchBowCond = 1, AimTouchBowBone = 1, AimTouchBowSpeed = 80, AimTouchBowFOV = 40, AimTouchBowDist = 150, AimTouchBowPred = 50, AimTouchBowRecoil = 0, AimTouchBowDrop = 50,
        AimTouchHipPrio = 1, AimTouchHipBone = 1, AimTouchHipCond = 1, AimTouchHipSpeed = 50, AimTouchHipFOV = 30, AimTouchHipDist = 250, AimTouchSGPrio = 1, AimTouchSGBone = 2, AimTouchSGCond = 1, AimTouchSGSpeed = 80, AimTouchSGFOV = 40, AimTouchSGDist = 30, AimTouchScopePrio = 1, AimTouchScopeBone = 2, AimTouchScopeCond = 1, AimTouchScopeSpeed = 40, AimTouchScopeFOV = 20, AimTouchScopeDist = 300, AimTouchSniperPrio = 1, AimTouchSniperBone = 1, AimTouchSniperCond = 2, AimTouchSniperSpeed = 30, AimTouchSniperFOV = 20, AimTouchSniperDist = 400}
    end

    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GameplayData then return end 
    local pc = nil
    pcall(function()
        if type(GameplayData.GetPlayerController) == "function" then
            pc = GameplayData.GetPlayerController()
        end
    end)
    local localPlayer = nil
    if Valid(pc) then pcall(function() localPlayer = pc:GetPlayerCharacterSafety() end) end

    -- State is updated before any fighting-only feature is ticked.
    local gameplayInMatch = IsGameplayMatchActive(GameplayData)
    local wasGameplayActive = _G.RapzhangState.GameplayActive == true
    _G.RapzhangState.GameplayActive = gameplayInMatch

    if wasGameplayActive and not gameplayInMatch then
        pcall(function() _G.RapzhangState.RestoreGameplayWeaponStats(localPlayer) end)
        pcall(ClearIndependentWallhackState)
        pcall(RestoreIpadCameraState)
        pcall(ClearMortarTargetLock)
        pcall(function() if ESP and ESP.Stop then ESP.Stop() end end)
        pcall(function()
            if _G.PlayerMapMarker and _G.PlayerMapMarker.Stop then _G.PlayerMapMarker.Stop() end
        end)
        pcall(function() if _G.AK_ClearMagicBulletCache then _G.AK_ClearMagicBulletCache() end end)
        _G.AK_MagicBulletCleared = false
    end

    if gameplayInMatch and localPlayer and BulletTrackSmartHead and BulletTrackSmartHead.InstallSmartHeadHook then
        pcall(function() BulletTrackSmartHead.InstallSmartHeadHook() end)
    end
    if gameplayInMatch and localPlayer and BulletTrackSmartHead and BulletTrackSmartHead.Tick then
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
        -- Ensure fighting-only visual systems are inert when no player object exists.
        pcall(function() if ESP and ESP.Stop then ESP.Stop() end end)
        pcall(function()
            if _G.PlayerMapMarker and _G.PlayerMapMarker.Stop then _G.PlayerMapMarker.Stop() end
        end)
        pcall(RestoreIpadCameraState)
        pcall(ClearMortarTargetLock)
        -- Restore temporary gameplay changes and clear their caches.
        if _G.AK_ClearMagicBulletCache then
            pcall(_G.AK_ClearMagicBulletCache)
        end
        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.RapzhangState.PrevGraphicsState = {}
        
        return 
    end

    -- Auto-feedback installation is persistent setup; reporting itself is fighting-only.
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
    end)

    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_SecurityCommonUtils = nil
    pcall(function() Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.RapzhangConfig.UnlockFPS then InitializeGraphicsUnlock() end
    RapzhangMenu()

    if not gameplayInMatch then
        -- Idempotent lobby cleanup: safe to run on every lobby tick.
        pcall(ClearIndependentWallhackState)
        pcall(RestoreIpadCameraState)
        pcall(ClearMortarTargetLock)
        pcall(function() if ESP and ESP.Stop then ESP.Stop() end end)
        pcall(function()
            if _G.PlayerMapMarker and _G.PlayerMapMarker.Stop then _G.PlayerMapMarker.Stop() end
        end)
        pcall(function() if _G.AK_ClearMagicBulletCache then _G.AK_ClearMagicBulletCache() end end)
        _G.AK_MagicBulletCleared = false
        return
    end

    -- Fighting-only systems start only after the state gate.
    if _G.AutoReportAssistTick then pcall(_G.AutoReportAssistTick) end
    pcall(function()
        ESP.SyncMenuConfig()
        ESPStartAll()
    end)
    if _G.RapzhangConfig.EspLoai9 then
        if _G.PlayerMapMarker and not _G.PlayerMapMarker.bActive then
            pcall(_G.PlayerMapMarker.Start)
        end
    else
        if _G.PlayerMapMarker and _G.PlayerMapMarker.bActive then
            pcall(_G.PlayerMapMarker.Stop)
        end
    end

    -- Wallhack remains active and toggleable during fighting even when ESP is OFF.
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
                    -- [MAGIC BULLET V2 — PhysicsAsset Scale (dari magicoptimal.lua)]
                    -- Scale collision capsule per-bone (head/body/legs), BUKAN visual mesh.
                    -- ============================================================================
                    pcall(function()
                        local EnemyMesh = eMesh
                        if not slua.isValid(EnemyMesh) then return end

                        local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
                        local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
                        if not slua.isValid(PhysicsAsset) and EnemyMesh.SkeletalMesh then
                            PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset
                        end
                        if not slua.isValid(PhysicsAsset) or not PhysicsAsset.SkeletalBodySetups then return end

                        _G.AK_ModdedPhysAssets = _G.AK_ModdedPhysAssets or {}
                        _G.AK_OrigHitboxes = _G.AK_OrigHitboxes or {}
                        local PhysAssetName = "DefaultPhys"
                        pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                        local assetCache = _G.AK_OrigHitboxes[PhysAssetName]
                        if not assetCache then
                            assetCache = { Bodies = {}, AppliedHash = "" }
                            _G.AK_OrigHitboxes[PhysAssetName] = assetCache
                        end

                        local function ArrayCount(arr)
                            if not arr then return 0 end
                            if type(arr.Num) == "function" then return arr:Num() end
                            return #arr
                        end
                        local function ArrayGet(arr, index)
                            if type(arr.Get) == "function" then return arr:Get(index) end
                            return arr[index + 1]
                        end
                        local function ArraySet(arr, index, value)
                            if type(arr.Set) == "function" then arr:Set(index, value) else arr[index + 1] = value end
                        end
                        local function MatchBone(name)
                            local lower = string.lower(tostring(name))
                            local ordered = { "head", "neck_01", "spine_03", "spine_02", "spine_01", "pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r" }
                            for _, key in ipairs(ordered) do
                                if lower == key or string.find(lower, key, 1, true) then return key end
                            end
                            return nil
                        end
                                                local function RestoreAsset()
                            for _, body in pairs(assetCache.Bodies) do
                                local setup = body.Setup
                                if slua.isValid(setup) then
                                    for kind, values in pairs(body.Elements or {}) do
                                        local arr = body.Arrays and body.Arrays[kind]
                                        if arr then
                                            for index, original in pairs(values) do
                                                local elem = ArrayGet(arr, index)
                                                if elem then
                                                    for field, value in pairs(original) do elem[field] = value end
                                                    ArraySet(arr, index, elem)
                                                end
                                            end
                                        end
                                    end
                                end
                                -- [CACHE CLEAR] Lepas referensi supaya tidak ada jejak.
                                body.Setup = nil
                                body.Arrays = nil
                                body.Elements = nil
                            end
                            assetCache.Bodies = {}
                            assetCache.AppliedHash = "OFF"
                            _G.AK_ModdedPhysAssets[PhysAssetName] = "OFF"
                        end

                                                -- [MAGIC BULLET] Guard: hanya aktif saat in-match.
                        -- Jika keluar match / lobby, paksa restore & clear.
                        local inMatchNow = _G.RapzhangState and _G.RapzhangState.GameplayActive == true
                        local runInject_Global = (_G.RapzhangConfig.CustomMagicBullet == true) and inMatchNow

                        if not inMatchNow then
                            -- Paksa restore & hapus cache saat tidak di match.
                            if assetCache.AppliedHash ~= "OFF" then
                                RestoreAsset()
                            end
                            if _G.AK_ClearMagicBulletCache then
                                pcall(_G.AK_ClearMagicBulletCache)
                            end
                            return
                        end

                        local mHead_Global = tonumber(_G.RapzhangState.CustomTextData.MagicHead) or 1.0
                        local mBody_Global = tonumber(_G.RapzhangState.CustomTextData.MagicBody) or 1.0
                        local mLegs_Global = tonumber(_G.RapzhangState.CustomTextData.MagicLegs) or 1.0

                        if not runInject_Global then
                            if assetCache.AppliedHash ~= "OFF" then
                                RestoreAsset()
                            end
                            if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
                            EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                            markData.MagicBulletHash = "OFF"
                            markData.MagicTargetID = uniqueID
                            return
                        end

                        local BoneScaleMap = {
                            ["head"] = mHead_Global, ["neck_01"] = mHead_Global,
                            ["pelvis"] = mBody_Global, ["spine_01"] = mBody_Global, ["spine_02"] = mBody_Global, ["spine_03"] = mBody_Global,
                            ["thigh_l"] = mLegs_Global, ["thigh_r"] = mLegs_Global, 
                            ["calf_l"] = mLegs_Global, ["calf_r"] = mLegs_Global,   
                            ["foot_l"] = mLegs_Global, ["foot_r"] = mLegs_Global    
                        }

                        local wantedHash = string.format("M_%.2f_%.2f_%.2f", mHead_Global, mBody_Global, mLegs_Global)
                        if assetCache.AppliedHash ~= wantedHash then
                            local setups = PhysicsAsset.SkeletalBodySetups
                            local setupCount = math.min(ArrayCount(setups), 50)
                            for setupIndex = 0, setupCount - 1 do
                                local bodySetup = ArrayGet(setups, setupIndex)
                                if slua.isValid(bodySetup) then
                                    local boneKey = MatchBone(bodySetup.BoneName)
                                    local requestedScale = boneKey and tonumber(BoneScaleMap[boneKey]) or nil
                                    if requestedScale then
                                        requestedScale = math.max(1.0, math.min(5.0, requestedScale))
                                        local scale = 1.0 + ((requestedScale - 1.0) * 0.35)
                                        local bodyKey = tostring(setupIndex)
                                        local bodyCache = assetCache.Bodies[bodyKey]
                                        if not bodyCache then
                                            bodyCache = { Setup = bodySetup, Arrays = {}, Elements = {} }
                                            assetCache.Bodies[bodyKey] = bodyCache
                                        end
                                        local geom = bodySetup.AggGeom
                                        local arrays = {
                                            Box = geom and geom.BoxElems or bodySetup.BoxElems,
                                            Sphere = geom and geom.SphereElems or bodySetup.SphereElems,
                                            Sphyl = geom and geom.SphylElems or bodySetup.SphylElems
                                        }
                                        for kind, arr in pairs(arrays) do
                                            if arr then
                                                bodyCache.Arrays[kind] = arr
                                                bodyCache.Elements[kind] = bodyCache.Elements[kind] or {}
                                                for elemIndex = 0, ArrayCount(arr) - 1 do
                                                    local elem = ArrayGet(arr, elemIndex)
                                                    if elem then
                                                        local original = bodyCache.Elements[kind][elemIndex]
                                                        if not original then
                                                            original = {}
                                                            if kind == "Box" then original = { X = elem.X, Y = elem.Y, Z = elem.Z }
                                                            elseif kind == "Sphere" then original = { Radius = elem.Radius }
                                                            else original = { Radius = elem.Radius, Length = elem.Length } end
                                                            bodyCache.Elements[kind][elemIndex] = original
                                                        end
                                                        if kind == "Box" then
                                                            elem.X = original.X * scale
                                                            elem.Y = original.Y * scale
                                                            elem.Z = original.Z * scale
                                                        elseif kind == "Sphere" then
                                                            elem.Radius = original.Radius * scale
                                                        else
                                                            elem.Radius = original.Radius * scale
                                                            elem.Length = original.Length * scale
                                                        end
                                                        ArraySet(arr, elemIndex, elem)
                                                    end
                                                end
                                                if geom then bodySetup.AggGeom = geom end
                                            end
                                        end
                                    end
                                end
                            end
                            assetCache.AppliedHash = wantedHash
                            _G.AK_ModdedPhysAssets[PhysAssetName] = wantedHash
                        end

                        if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
                        EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                        markData.MagicBulletHash = wantedHash
                        markData.MagicTargetID = uniqueID
                    end)
                    -- ============================================================================
                    -- [END MAGIC BULLET V2]
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

-- ============================================================================
-- RUNTIME LIFECYCLE ORCHESTRATOR
-- Flow: LOAD -> INITIALIZING -> READY <-> GAMEPLAY -> STOPPED
-- A generation token invalidates stale callbacks after reload/restart.
-- ============================================================================
local Lifecycle = _G.RapzhangLifecycle or {}
_G.RapzhangLifecycle = Lifecycle

Lifecycle.phase = Lifecycle.phase or "LOADED"
Lifecycle.gameState = (_G.RapzhangState and _G.RapzhangState.GameplayActive == true) and "FIGHTING" or "LOBBY"
Lifecycle.generation = (tonumber(Lifecycle.generation) or 0) + 1
Lifecycle.initialized = Lifecycle.initialized == true
Lifecycle.lastError = Lifecycle.lastError
Lifecycle.tickCount = tonumber(Lifecycle.tickCount) or 0
Lifecycle.lastTransitionAt = tonumber(Lifecycle.lastTransitionAt) or 0
Lifecycle.startedGeneration = tonumber(Lifecycle.startedGeneration) or 0

local lifecycleGeneration = Lifecycle.generation
local function LifecycleSetPhase(nextPhase)
    if Lifecycle.phase == nextPhase then return end
    Lifecycle.phase = nextPhase
    Lifecycle.lastTransitionAt = os.clock()
end

local function LifecycleSchedule(delaySeconds, callback)
    local expectedGeneration = Lifecycle.generation
    local guardedCallback = function(...)
        if expectedGeneration ~= Lifecycle.generation then return end
        return callback(...)
    end
    local ok, ticker = pcall(require, "common.time_ticker")
    if not ok or not ticker or type(ticker.AddTimerOnce) ~= "function" then
        Lifecycle.lastError = "common.time_ticker unavailable"
        return false
    end
    local scheduled, err = pcall(function()
        ticker.AddTimerOnce(delaySeconds, guardedCallback)
    end)
    if not scheduled then Lifecycle.lastError = tostring(err) end
    return scheduled
end

local function LifecycleRunProtected(label, callback)
    local ok, err = pcall(callback)
    if not ok then
        Lifecycle.lastError = tostring(label) .. ": " .. tostring(err)
        pcall(print, "[LIFECYCLE] " .. Lifecycle.lastError)
    end
    return ok
end

local function LifecycleInitialize()
    if lifecycleGeneration ~= Lifecycle.generation or Lifecycle.initialized then return end
    LifecycleSetPhase("INITIALIZING")

    local okData, GameplayData = pcall(function()
        return package.loaded["GameLua.GameCore.Data.GameplayData"]
            or require("GameLua.GameCore.Data.GameplayData")
    end)
    if not okData or not GameplayData then
        Lifecycle.lastError = "GameplayData unavailable: " .. tostring(GameplayData)
        LifecycleSetPhase("READY")
        return
    end

    LifecycleRunProtected("initialize player flags", function()
        local player = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua and type(slua.isValid) == "function" and slua.isValid(player) then
            if player.bHasShownDevNotice == nil then
                player.bHasShownDevNotice = false
                player.bHasShownExpiredNotice = false
                player.bIsDeadFlag = false
            end
        end
    end)

    Lifecycle.initialized = true
    LifecycleSetPhase("READY")

    -- Optional subsystem boot is isolated so one failure does not stop runtime.
    LifecycleSchedule(0.5, function()
        if lifecycleGeneration ~= Lifecycle.generation then return end
        LifecycleRunProtected("force-friend boot", function()
            local feature = _G.RapzhangForceFriend
            if feature and type(feature.Boot) == "function" then feature.Boot() end
        end)
    end)
end

local function LifecycleTick()
    if lifecycleGeneration ~= Lifecycle.generation then return end
    Lifecycle.tickCount = Lifecycle.tickCount + 1

    LifecycleRunProtected("main loop", function()
        if type(MainLoop) == "function" then MainLoop() end
    end)
    -- Fighting-only enhancement tick; never run it from lobby state.
    LifecycleRunProtected("gameplay enhancement tick", function()
        if _G.RapzhangState and _G.RapzhangState.GameplayActive == true
            and _G.MBCT and type(_G.MBCT.Tick) == "function" then
            _G.MBCT.Tick()
        end
    end)

    local gameplayActive = false
    LifecycleRunProtected("gameplay state", function()
        local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"]
        if type(IsGameplayMatchActive) == "function" then
            gameplayActive = IsGameplayMatchActive(GameplayData) == true
        else
            gameplayActive = _G.RapzhangState and _G.RapzhangState.GameplayActive == true
        end
    end)
    Lifecycle.gameState = gameplayActive and "FIGHTING" or "LOBBY"
    LifecycleSetPhase(gameplayActive and "GAMEPLAY" or (Lifecycle.initialized and "READY" or "INITIALIZING"))

    local config = _G.RapzhangConfig or {}
    local state = _G.RapzhangState or {}
    local aimActive = gameplayActive and config.AimTouchEnable == true
    local interval = aimActive and 0.02 or 0.5
    LifecycleSchedule(interval, LifecycleTick)
end

function Lifecycle.Start()
    if Lifecycle.startedGeneration == Lifecycle.generation then return true end
    if Lifecycle.phase == "STOPPED" then
        Lifecycle.generation = Lifecycle.generation + 1
        lifecycleGeneration = Lifecycle.generation
    end
    Lifecycle.startedGeneration = Lifecycle.generation
    LifecycleSetPhase("LOADED")
    LifecycleSchedule(0.5, LifecycleInitialize)
    -- Keep the original immediate first tick; subsequent ticks are self-scheduled.
    LifecycleTick()
    return true
end

function Lifecycle.Stop()
    -- Existing one-shot timers cannot be cancelled reliably, so invalidate them.
    Lifecycle.generation = Lifecycle.generation + 1
    lifecycleGeneration = Lifecycle.generation
    LifecycleSetPhase("STOPPED")
    return true
end

-- Backward-compatible entry points used by existing integrations.
_G.RapzhangState.RefreshActiveWeaponStats = function()
    LifecycleRunProtected("refresh weapon stats", function()
        if type(MainLoop) == "function" then MainLoop() end
    end)
end

_G.RapzhangState.LoopToken = (_G.RapzhangState.LoopToken or 0) + 1
function FastTick()
    if lifecycleGeneration ~= Lifecycle.generation then return end
    LifecycleTick()
end

Lifecycle.Start()
Notify("Bạn Đang Chơi Mod Vvip 4 Của Tôi Nếu Chưa Có Key Inbox Tele rapzhang Để Mua Nếu Ai Đó Đã Bán Cho Bạn Thứ Này Ngoài Tôi Thì Xin Chúc Mừng Bạn Đã Bị Lừa")

-- ============================================================================
-- MODULE ENTRY POINTS
-- ============================================================================
function M.OnBeginPlay(self)
    -- Engine callback retained for compatibility; runtime startup is centralized above.
end

-- ==============================================================================
-- ================= BẮT ĐẦU LOGIC MOD EMOTE ===================================
-- ==============================================================================

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
local _nadAppliedFriends = {}

local function _nadRemoveFakeFriend(uid)
    uid = tonumber(uid)
    if not uid or uid <= 0 then return end
    pcall(function()
        local FriendHandler = require("client.network.Protocol.FriendHandler")
        FriendHandler.on_del_inner_friend_notify(uid)
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
    local friends = _G.HackAccountData and _G.HackAccountData.friends or {}
    uid = tonumber(uid)
    if not uid then return false end
    for _, f in ipairs(friends) do
        if tonumber(f) == uid then return true end
    end
    return false
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
    if logic_friend_list.GetFriendInfo and logic_friend_list:GetFriendInfo(uid) then return end
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

function _G._nadExportFakeFriendUiFile()
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
    local f = io.open("/data/share1/rapzhang_ff_ui.txt", "w")
    if f then
        f:write(table.concat(lines, "\n"))
        f:close()
    end
end

local function _nadRequestFakeFriendStatus()
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

local function _nadApplyFakeFriends()
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
    pcall(_nadRequestFakeFriendStatus)
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
function _G.RapzhangFakeFriendApply()
    if not (_G.RapzhangConfig and _G.RapzhangConfig.ForceFriend == true) then return false end
    local loader = _G.RapzhangFriendUID
    local uids = loader and loader.Load and loader.Load() or {}
    _G.HackAccountData = _G.HackAccountData or {}
    _G.HackAccountData.friends = uids
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

-- ============================================================================
-- [MAGIC BULLET ENHANCEMENT PACK] — ZanLUAMaker
-- 1. Ignore Knock toggle untuk Magic Bullet
-- 2. Jitter Scale (scale acak ±15%)
-- 3. Crosshair-Triggered (aktif hanya saat crosshair on target)
-- 4. Auto cleanup saat target mati & keluar match
-- TIDAK menyentuh Bullet Track
-- ============================================================================
do

  _G.RapzhangConfig = _G.RapzhangConfig or {}
  if _G.RapzhangConfig.MagicIgnoreKnock == nil then
    _G.RapzhangConfig.MagicIgnoreKnock = false
  end

  _G.AK_JitterPercent = _G.AK_JitterPercent or 15

  _G.AK_GetJitteredScale = function(baseScale)
    local jitterRange = (_G.AK_JitterPercent or 15) / 100.0
    local jitter = 1.0 + (math.random() * 2 - 1) * jitterRange
    local result = baseScale * jitter
    if result < 1.0 then result = 1.0 end
    return result
  end

  local MBCT = _G.RapzhangMBCrosshair or {}
  _G.RapzhangMBCrosshair = MBCT

  MBCT.Config = {
    CrosshairRadiusPx  = 80,
    MaxDistance        = 30000,
    RequireLineOfSight = true,
    MinActiveDuration  = 0.3,
    MaxActiveDuration  = 2.0,
    ReapplyCooldown    = 0.15,
    JitterPercent      = 15,
  }

  MBCT._activeTarget  = nil
  MBCT._activeMeshKey = nil
  MBCT._appliedAt     = 0
  MBCT._lastReapplyAt = 0
  MBCT._origCache     = {}

  local function mbct_getViewport()
    local vw, vh = 1920, 1080
    pcall(function()
      local ui = require("client.common.ui_util")
      if ui and ui.GetViewportSize then
        local size = ui.GetViewportSize()
        if size and size.X and size.Y then vw, vh = size.X, size.Y end
      end
    end)
    return vw, vh
  end

  local function mbct_getCamLoc(pc)
    local loc = nil
    pcall(function()
      local gs = import("GameplayStatics")
      if gs and gs.GetPlayerCameraManager then
        local cm = gs.GetPlayerCameraManager(pc, 0)
        if cm and slua.isValid(cm) then loc = cm:GetCameraLocation() end
      end
    end)
    return loc
  end

  local function mbct_getBonePos(target, boneName)
    local pos = nil
    pcall(function()
      if type(target.GetBonePos) == "function" then
        pos = target:GetBonePos(boneName, {X=0, Y=0, Z=0})
      end
      if not pos and type(target.GetSocketLocation) == "function" then
        pos = target:GetSocketLocation(boneName)
      end
    end)
    return pos
  end

  local function mbct_isKnocked(target)
    if not target then return false end
    local knocked = false
    pcall(function()
      if target.HealthStatus == 1 then knocked = true end
      if not knocked and type(target.IsNearDeath) == "function" then
        knocked = target:IsNearDeath() == true
      end
      if not knocked and type(target.IsKnocked) == "function" then
        knocked = target:IsKnocked() == true
      end
    end)
    return knocked
  end

  local function mbct_isCrosshairOnTarget(pc, target, vw, vh)
    if not slua.isValid(target) or not slua.isValid(pc) then return false end

    local localPlayer = nil
    pcall(function()
      local GDP = require("GameLua.GameCore.Data.GameplayData")
      localPlayer = GDP and GDP.GetPlayerCharacter()
    end)
    if slua.isValid(localPlayer) and localPlayer.GetDistanceTo then
      local dist = localPlayer:GetDistanceTo(target) or 0
      if dist > MBCT.Config.MaxDistance then return false end
    end

    local headPos  = mbct_getBonePos(target, "head")
    local chestPos = mbct_getBonePos(target, "spine_03")
    local aimPos   = headPos or chestPos
    if not aimPos then
      pcall(function()
        if type(target.K2_GetActorLocation) == "function" then
          aimPos = target:K2_GetActorLocation()
          if aimPos then aimPos.Z = aimPos.Z + 50 end
        end
      end)
    end
    if not aimPos then return false end

    local screen = nil
    pcall(function()
      local V = import("Vector2D")
      if V then screen = V() end
    end)
    if not screen then return false end

    local ok = false
    pcall(function()
      ok = pc:ProjectWorldLocationToScreen(aimPos, screen, false)
    end)
    if not ok then return false end

    local dx = screen.X - vw * 0.5
    local dy = screen.Y - vh * 0.5
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist > MBCT.Config.CrosshairRadiusPx then return false end

    if MBCT.Config.RequireLineOfSight then
      local camLoc = mbct_getCamLoc(pc)
      if camLoc then
        local bVisible = false
        pcall(function()
          local ksl = import("KismetSystemLibrary")
          if ksl and ksl.LineTraceSingle then
            local hr = nil
            pcall(function()
              local HR = import("HitResult")
              hr = HR and HR() or {}
            end)
            local bHit = ksl.LineTraceSingle(pc, camLoc, aimPos, 0, false, nil, 0, hr, true)
            if not bHit then
              bVisible = true
            else
              local hitActor = nil
              if type(hr.GetActor) == "function" then hitActor = hr:GetActor() end
              if hitActor == target then bVisible = true end
            end
          else
            bVisible = true
          end
        end)
        if not bVisible then return false end
      end
    end

    return true
  end

  local function mbct_findCrosshairTarget(pc, vw, vh)
    local GDP = require("GameLua.GameCore.Data.GameplayData")
    if not GDP then return nil end
    local localPlayer = GDP.GetPlayerCharacter()
    if not slua.isValid(localPlayer) then return nil end

    local allChars = {}
    pcall(function()
      if GDP.GetAllPlayerCharacters then
        allChars = GDP.GetAllPlayerCharacters() or {}
      end
    end)

    local best     = nil
    local bestDist = MBCT.Config.CrosshairRadiusPx

    for _, enemy in pairs(allChars) do
      if slua.isValid(enemy) and enemy ~= localPlayer then
        local isEnemy = false
        pcall(function() isEnemy = enemy.TeamID ~= localPlayer.TeamID end)

        if isEnemy then
          local alive = true
          pcall(function()
            if type(enemy.IsAlive) == "function" then
              alive = enemy:IsAlive()
            elseif enemy.Health then
              alive = enemy.Health > 0
            end
          end)

          if alive then
            local skipKnocked = false
            if _G.RapzhangConfig.MagicIgnoreKnock == true then
              skipKnocked = mbct_isKnocked(enemy)
            end

            if not skipKnocked then
              if mbct_isCrosshairOnTarget(pc, enemy, vw, vh) then
                local headPos = mbct_getBonePos(enemy, "head")
                if headPos then
                  local screen = nil
                  pcall(function()
                    local V = import("Vector2D")
                    if V then screen = V() end
                  end)
                  if screen then
                    local ok = false
                    pcall(function()
                      ok = pc:ProjectWorldLocationToScreen(headPos, screen, false)
                    end)
                    if ok then
                      local dx = screen.X - vw * 0.5
                      local dy = screen.Y - vh * 0.5
                      local d = math.sqrt(dx*dx + dy*dy)
                      if d < bestDist then
                        bestDist = d
                        best = enemy
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    return best
  end

  local function mbct_applyToTarget(enemy)
    if not slua.isValid(enemy) then return false end

    local data = _G.RapzhangState and _G.RapzhangState.CustomTextData or {}
    local cfgH = tonumber(data.MagicHead) or 1.0
    local cfgB = tonumber(data.MagicBody) or 1.0
    local cfgL = tonumber(data.MagicLegs) or 1.0

    local mesh = nil
    pcall(function()
      mesh = enemy.Mesh
      if not mesh and type(enemy.getAvatarComponent2) == "function" then
        mesh = enemy:getAvatarComponent2()
      end
    end)
    if not slua.isValid(mesh) then return false end

    local pa = mesh.PhysicsAssetOverride
    if not slua.isValid(pa) and mesh.SkeletalMesh then
      pa = mesh.SkeletalMesh.PhysicsAsset
    end
    if not slua.isValid(pa) or not pa.SkeletalBodySetups then return false end

    local meshKey = tostring(mesh)
    if MBCT._activeMeshKey == meshKey then return true end

    MBCT._origCache[meshKey] = MBCT._origCache[meshKey] or {}

    local setups = pa.SkeletalBodySetups
    local count  = math.min(setups:Num() or 0, 50)

    for i = 0, count - 1 do
      local setup = setups:Get(i)
      if slua.isValid(setup) then
        local boneName = string.lower(tostring(setup.BoneName or ""))
        local requested = nil

        if boneName:find("head", 1, true) or boneName:find("neck", 1, true) then
          requested = cfgH
        elseif boneName:find("spine", 1, true) or boneName:find("pelvis", 1, true) then
          requested = cfgB
        elseif boneName:find("thigh", 1, true) or boneName:find("calf", 1, true) or boneName:find("foot", 1, true) then
          requested = cfgL
        end

        if requested and requested > 1.0 then
          local baseScale = 1.0 + ((requested - 1.0) * 0.35)
          local scale
          if _G.AK_GetJitteredScale then
            scale = _G.AK_GetJitteredScale(baseScale)
          else
            local jr = (MBCT.Config.JitterPercent or 15) / 100.0
            local j  = 1.0 + (math.random() * 2 - 1) * jr
            scale = baseScale * j
            if scale < 1.0 then scale = 1.0 end
          end

          local geom = setup.AggGeom
          if geom and not MBCT._origCache[meshKey][i] then
            MBCT._origCache[meshKey][i] = {
              BoxElems    = geom.BoxElems,
              SphereElems = geom.SphereElems,
              SphylElems  = geom.SphylElems,
            }
          end

          pcall(function()
            if geom.BoxElems then
              for j = 0, (geom.BoxElems:Num() or 0) - 1 do
                local e = geom.BoxElems:Get(j)
                if e then
                  e.X = e.X * scale
                  e.Y = e.Y * scale
                  e.Z = e.Z * scale
                end
              end
            end
            if geom.SphereElems then
              for j = 0, (geom.SphereElems:Num() or 0) - 1 do
                local e = geom.SphereElems:Get(j)
                if e then e.Radius = e.Radius * scale end
              end
            end
            if geom.SphylElems then
              for j = 0, (geom.SphylElems:Num() or 0) - 1 do
                local e = geom.SphylElems:Get(j)
                if e then
                  e.Radius = e.Radius * scale
                  e.Length = e.Length * scale
                end
              end
            end
          end)
        end
      end
    end

    pcall(function()
      if mesh.SetPhysicsAsset then mesh:SetPhysicsAsset(pa) end
      mesh.PhysicsAssetOverride = pa
    end)

    MBCT._activeTarget  = enemy
    MBCT._activeMeshKey = meshKey
    MBCT._appliedAt     = os.clock()
    return true
  end

  local function mbct_restoreTarget()
    if not MBCT._activeTarget then return end

    local enemy   = MBCT._activeTarget
    local meshKey = MBCT._activeMeshKey

    if slua.isValid(enemy) then
      local mesh = nil
      pcall(function()
        mesh = enemy.Mesh
        if not mesh and type(enemy.getAvatarComponent2) == "function" then
          mesh = enemy:getAvatarComponent2()
        end
      end)
      if slua.isValid(mesh) then
        local pa = mesh.PhysicsAssetOverride
        if not slua.isValid(pa) and mesh.SkeletalMesh then
          pa = mesh.SkeletalMesh.PhysicsAsset
        end
        if slua.isValid(pa) then
          local setups = pa.SkeletalBodySetups
          local count  = math.min(setups:Num() or 0, 50)
          local cache  = MBCT._origCache[meshKey] or {}
          for i = 0, count - 1 do
            local setup = setups:Get(i)
            local orig  = cache[i]
            if slua.isValid(setup) and orig then
              local geom = setup.AggGeom
              if geom then
                if orig.BoxElems    then geom.BoxElems    = orig.BoxElems end
                if orig.SphereElems then geom.SphereElems = orig.SphereElems end
                if orig.SphylElems  then geom.SphylElems  = orig.SphylElems end
              end
            end
          end
          pcall(function()
            if mesh.SetPhysicsAsset then mesh:SetPhysicsAsset(pa) end
          end)
        end
      end
    end

    MBCT._origCache[meshKey] = nil
    MBCT._activeTarget  = nil
    MBCT._activeMeshKey = nil
    MBCT._appliedAt     = 0
  end

  function MBCT.Tick()
    local cfg = _G.RapzhangConfig or {}
    if cfg.CustomMagicBullet ~= true then
      if MBCT._activeTarget then pcall(mbct_restoreTarget) end
      return
    end

    local pc = nil
    pcall(function()
      local GDP = require("GameLua.GameCore.Data.GameplayData")
      pc = GDP and GDP.GetPlayerController()
    end)
    if not slua.isValid(pc) then return end

    local vw, vh = mbct_getViewport()
    local crosshairTarget = mbct_findCrosshairTarget(pc, vw, vh)

    if crosshairTarget ~= MBCT._activeTarget then
      if MBCT._activeTarget then pcall(mbct_restoreTarget) end
      if crosshairTarget then
        local now = os.clock()
        if now - MBCT._lastReapplyAt >= MBCT.Config.ReapplyCooldown then
          MBCT._lastReapplyAt = now
          pcall(mbct_applyToTarget, crosshairTarget)
        end
      end
    else
      if MBCT._activeTarget then
        local elapsed = os.clock() - MBCT._appliedAt
        if elapsed > MBCT.Config.MaxActiveDuration then
          pcall(mbct_restoreTarget)
        end
      end
    end
  end

  function MBCT.ForceRestore()
    pcall(mbct_restoreTarget)
  end

  function MBCT.GetActiveTarget()
    return MBCT._activeTarget
  end

  local function mbct_injectMenu()
    pcall(function()
      local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
      if not SettingPageDefine or not SettingPageDefine.ModMenu then return end

      local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
      if not AliasMap then return end

      for _, cat in ipairs(SettingPageDefine.ModMenu.Category or {}) do
        if cat.Key == "Cat_Bullet" and cat.Stack then
          local exists = false
          for _, item in ipairs(cat.Stack) do
            if item.Key == "ModMenu_Magic_IgnoreKnock" then exists = true break end
          end
          if exists then return end

          local insertAt = #cat.Stack + 1
          for i, item in ipairs(cat.Stack) do
            if item.Key == "ModMenu_Magic_Ex" then
              insertAt = i + 1
              break
            end
          end

          table.insert(cat.Stack, insertAt, {
            Key = "ModMenu_Magic_IgnoreKnock",
            UI = AliasMap.Switcher,
            Text = "   Ignore Knocked",
            ExpandHandle = "ModMenu_Magic_Ex",
            GetFunc = function() return _G.RapzhangConfig.MagicIgnoreKnock == true end,
            SetFunc = function(_, v) _G.RapzhangConfig.MagicIgnoreKnock = (v == true); return true end,
          })
          print("[MB PACK] Menu item IgnoreKnock injected")
        end
      end
    end)
  end

  pcall(mbct_injectMenu)

  if not _G.__mbctMenuRetryScheduled then
    _G.__mbctMenuRetryScheduled = true
    local function retryLoop()
      pcall(mbct_injectMenu)
      pcall(function()
        local ticker = require("common.time_ticker")
        if ticker and ticker.AddTimerOnce then
          ticker.AddTimerOnce(2.0, retryLoop)
        end
      end)
    end
    pcall(function()
      local ticker = require("common.time_ticker")
      if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(2.0, retryLoop)
      end
    end)
  end

  if not _G.__mbctFastTickHooked then
    _G.__mbctFastTickHooked = true
    local _origFastTick = _G.FastTick
    if type(_origFastTick) == "function" then
      local _wrapped = function(...)
        if _origFastTick then _origFastTick(...) end
        pcall(function()
          if MBCT and MBCT.Tick then MBCT.Tick() end
        end)
      end
      _G.FastTick = _wrapped
    end
  end

  if not _G.__mbctCleanupHooked then
    _G.__mbctCleanupHooked = true
    local _origClear = _G.AK_ClearMagicBulletCache
    _G.AK_ClearMagicBulletCache = function()
      pcall(function()
        if MBCT and MBCT.ForceRestore then MBCT.ForceRestore() end
      end)
      if _origClear then pcall(_origClear) end
    end
  end

  print("[MB PACK] Magic Bullet Enhancement Pack loaded")
end
-- ============================================================================
-- [END MAGIC BULLET ENHANCEMENT PACK]

-- NO-BRPLAYER MODE: payload dijalankan sebagai external module.
-- Tidak membuat atau mendaftarkan CBRPlayerCharacterBase.

-- Force IsDevelopment() = true so dev-mode code paths unlock.

return M
