-- ============================================================================
_G.RapzhangConfig = _G.RapzhangConfig or {}
-- Remove legacy slider selections from the shared Rapzhang setting table.
-- The slider module is no longer present and no SkinSlider_* key is written.
for key in pairs(_G.RapzhangConfig) do
    if tostring(key):find("SkinSlider", 1, true) then
        _G.RapzhangConfig[key] = nil
    end
end
-- Fitur-fitur ini selalu aktif dan sengaja tidak disimpan di RapzhangConfig.
-- Hapus nilai lama agar setting lama tidak dapat mematikan fitur tersebut.
for _, key in ipairs({"ModSkin", "SkinAttachment", "SkinDeadBox", "KillMessage", "KillCountUI", "ModEmote"}) do
    _G.RapzhangConfig[key] = nil
end
local RAPZHANG_MOD_SKIN_ALWAYS_ON = true
local RAPZHANG_SKIN_ATTACHMENT_ALWAYS_ON = true
local RAPZHANG_SKIN_DEADBOX_ALWAYS_ON = true
local RAPZHANG_MOD_EMOTE_ALWAYS_ON = true
local RAPZHANG_VEHICLE_SKIN_ALWAYS_ON = true
local RAPZHANG_KILL_MESSAGE_ALWAYS_ON = true
local RAPZHANG_KILL_COUNT_UI_ALWAYS_ON = true
-- RAPZHANG SKIN + EMOTE + KILL/Lobby MODULE
-- Extracted from lengkap.lua: AddOutfit / wardrobe / weapon skin / vehicle skin
-- / persistence / lobby-match skin hooks / kill message /
-- kill counter / lobby initialization / emote logic.
--
-- Excluded intentionally: bypass, ESP/aim, force friend, gacha, and lobby
-- super-car/theme logic.
-- Load this file after the normal game globals/config are available.
-- ============================================================================

-- ================= START CORE ADD-OUTFIT V7.5 (SKIN SYSTEM) ================
-- ==============================================================================
-- Weapon attachments are discovered from official game tables by Rapzhang ownership manager.

local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if not RAPZHANG_SKIN_DEADBOX_ALWAYS_ON or _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray_DB then
        _G.CachedActorArray_DB = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    -- Optimization: Pre-fetch player ID and gun/vehicle IDs outside loop to avoid recalculation
    local myPlayerKey = PlayerController.PlayerKey
    local currentBoxSkinId = 0
    pcall(function()
        local curVeh = PlayerCharacter.CurrentVehicle or (type(PlayerCharacter.GetCurrentVehicle) == "function" and PlayerCharacter:GetCurrentVehicle())
        if slua.isValid(curVeh) and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
            currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
        else
            -- [VIP FIX]: Get the ID of the weapon currently held to output the correct loot box; remove loop to prevent FPS drops
            local curWeapon = PlayerCharacter.GetCurrentWeapon and PlayerCharacter:GetCurrentWeapon() or PlayerCharacter.CurrentWeapon
            if slua.isValid(curWeapon) then
                local defineIDObj = curWeapon.GetItemDefineID and curWeapon:GetItemDefineID()
                local curWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
                
                -- Cross-reference saved Skin inventory to get current Skin ID
                if curWeaponID > 0 and _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[curWeaponID] then
                    local skinID = _G.AddOutfitLastAppliedSkin[curWeaponID]
                    if skinID and skinID > 1000000 then 
                        currentBoxSkinId = skinID 
                    end
                end
            end
        end
    end)

    if currentBoxSkinId == 0 then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray_DB)
    if not deadBoxes then return end
    
    local count = type(deadBoxes.Num) == "function" and deadBoxes:Num() or #deadBoxes
    for i = 1, count do
        local deadBoxActor = type(deadBoxes.Get) == "function" and deadBoxes:Get(i-1) or deadBoxes[i]
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            -- Compare extremely fast using cached MyPlayerKey
            if slua.isValid(damageCauser) and damageCauser.PlayerKey == myPlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    pcall(function()
                        DeadBoxAvatarComponent:ResetItemAvatar()
                        DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                        DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                    end)
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end

-- [[ AddOutfit v7.5 — Integrates Skin selection via Wardrobe ]]
local F = {}
local DEBUG = false  
function F.log(...)
    if DEBUG then print("[AddOutfit]", ...) end
end

local MATCH_CONFIG = {
    outfitRes = 0,        
    hatRes    = 0,        
    maskRes   = 0,
    glassRes  = 0,
    tshirtRes = 0,        
    pantsRes  = 0,        
    shoesRes  = 0,        
    bagRes    = 0,        
    helmetRes = 0,        
    weaponSkins = {},
}

-- ============================================================================
-- KATALOG ITEM RUNTIME (LANGSUNG DARI TABEL PUBG)
--
-- Daftar ~16.000 ID hardcoded (15.958 baris) dihapus dan diganti pemindaian
-- tabel "Item" milik game. Hanya item yang punya WardrobeMainTab + WardrobeTab
-- + ItemSubType yang masuk katalog, karena hanya item itulah yang bisa tampil
-- dan dipakai di grid Wardrobe. Hasilnya di-cache sekali; kalau PUBG menambah
-- item baru, item itu otomatis ikut tanpa menyentuh script ini.
--
-- Meta (ItemType/ItemSubType/WardrobeMainTab/WardrobeTab/ItemQuality) ikut
-- disimpan saat pemindaian supaya injeksi massal tidak perlu memanggil
-- CDataTable.GetTableData ribuan kali (ini yang bikin lag di versi lama).
-- ============================================================================
local ITEM_CATALOG = nil        -- array resID, urut naik
local ITEM_CATALOG_SET = nil    -- resID -> true
local ITEM_CATALOG_INDEX = nil  -- resID -> posisi 1..N (dasar insID sintetis)
local ITEM_CATALOG_META = nil   -- posisi -> { ItemType, ItemSubType, MainTab, SubTab, Quality }
local INS_BASE = 2000000000

local function getItemTableRaw()
    local cdt = rawget(_G, "CDataTable")
    if not cdt or not cdt.GetTable then return nil end
    local t
    pcall(function() t = cdt.GetTable("Item") end)
    if type(t) ~= "table" then return nil end
    return t
end

local function catalogRowID(key, row, arrayForm)
    if type(row) == "table" then
        local rid = tonumber(row.ItemID) or tonumber(row.ItemId)
            or tonumber(row.ID) or tonumber(row.Id)
        if rid and rid > 0 then return rid end
    end
    -- Kalau tabel game berbentuk array, key numerik hanyalah indeks baris,
    -- bukan resID. Jangan pernah menyuntik indeks 1..N sebagai item.
    if arrayForm then return nil end
    return tonumber(key)
end

local function buildItemCatalog()
    if ITEM_CATALOG then return ITEM_CATALOG end
    local tbl = getItemTableRaw()
    if not tbl then return nil end
    local arrayForm = type(tbl[1]) == "table"
    local list, seen, meta = {}, {}, {}
    for key, row in pairs(tbl) do
        if type(row) == "table" then
            local rid = catalogRowID(key, row, arrayForm)
            local mainTab = tonumber(row.WardrobeMainTab or row.wardrobeMainTab) or 0
            local subTab = tonumber(row.WardrobeTab or row.wardrobeTab) or 0
            local itemType = tonumber(row.ItemType or row.itemType) or 0
            local subType = tonumber(row.ItemSubType or row.itemSubType) or 0
            if rid and rid > 0 and not seen[rid]
                and mainTab > 0 and subTab > 0 and subType > 0 then
                seen[rid] = true
                list[#list + 1] = rid
                meta[#list] = { itemType, subType, mainTab, subTab,
                    tonumber(row.ItemQuality or row.itemQuality) or 0 }
            end
        end
    end
    if #list == 0 then return nil end
    -- Urutkan resID sambil menjaga pasangan meta tetap sejajar.
    local order = {}
    for i = 1, #list do order[i] = i end
    table.sort(order, function(a, b) return list[a] < list[b] end)
    local ids, metas, index = {}, {}, {}
    for pos = 1, #order do
        local old = order[pos]
        local rid = list[old]
        ids[pos] = rid
        metas[pos] = meta[old]
        index[rid] = pos
    end
    ITEM_CATALOG, ITEM_CATALOG_SET = ids, seen
    ITEM_CATALOG_INDEX, ITEM_CATALOG_META = index, metas
    return ids
end

local function itemCatalog()
    return ITEM_CATALOG or buildItemCatalog()
end

local function itemCatalogSet()
    buildItemCatalog()
    return ITEM_CATALOG_SET
end

function F.itemCatalog()
    return itemCatalog()
end

function F.itemCatalogSet()
    return itemCatalogSet()
end

function F.catalogIndex(resID)
    resID = tonumber(resID)
    if not resID then return nil end
    buildItemCatalog()
    return ITEM_CATALOG_INDEX and ITEM_CATALOG_INDEX[resID] or nil
end

function F.catalogMeta(resID)
    local i = F.catalogIndex(resID)
    return i and ITEM_CATALOG_META and ITEM_CATALOG_META[i] or nil
end

-- insID sintetis selalu INS_BASE + posisi katalog, bukan INS_BASE + resID.
-- Hasilnya < 2^31 dan tidak berubah selama urutan tabel Item sama.
function F.catalogIns(resID)
    local i = F.catalogIndex(resID)
    if i then return INS_BASE + i end
    return nil
end

function F.syntheticResFromIns(insID)
    insID = tonumber(insID)
    if not insID or insID < INS_BASE then return nil end
    local list = itemCatalog()
    if not list then return nil end
    return list[insID - INS_BASE]
end
local PKG_SLOT = 3
local MELEE_ID = 108
local HAT_SUB = 401
local MASK_SUB = 402
local OUTFIT_SUB = 403
local PANTS_SUB = 404
local SHOES_SUB = 405
local GLASS_SUB = 407
local GLIDER_SUB = 415      
local GLOVES_SUB = 452
local GLIDER_SUBS = { [413] = true, [414] = true, [415] = true }

F.CUST_SLOT = {
    NONE = 0,
    HeadEquipemtSlot = 1,
    HairEquipemtSlot = 2,
    HatEquipemtSlot = 3,
    FaceEquipemtSlot = 4,
    ClothesEquipemtSlot = 5,
    PantsEquipemtSlot = 6,
    ShoesEquipemtSlot = 7,
    BackpackEquipemtSlot = 8,
    HelmetEquipemtSlot = 9,
    ArmorEquipemtSlot = 10,
    ParachuteEquipemtSlot = 11,
    GlassEquipemtSlot = 12,
    NightVisionEquipemtSlot = 13,
    BeardEquipemtSlot = 14,
    GlideEquipemtSlot = 15,
    HandEffectEquipemtSlot = 16,
    BackPack_PendantSlot = 17,
}
_G.CustSlotType = F.CUST_SLOT

local CHASSIS_LIGHT_SUB = 7302
local CHASSIS_LIGHT_IDS = { [7302001] = true, [7302002] = true }
local DEFAULT_CHASSIS_LIGHT = 7302002
local PARACHUTE_SUB = 701   
local DEFAULT_PARACHUTE_RES = 703001  
local TAB_SUIT = 10
local TAB_CLOTHES = 3
local PAGE_AVATAR = 1
local PAGE_VEHICLE = 6
local PAGE_PARACHUTE = 5
local HALL_THEME_TYPE = 202
local SUBTYPE_DEFAULT_TAB = {
    [401] = 1, [402] = 2, [403] = 10, [404] = 4, [405] = 5, [407] = 14,
    [501] = 15, [504] = 15, [502] = 16, [505] = 16,
}
local HAT_SUBS = { [401] = true }
local HELMET_SUBS = { [502] = true, [505] = true }
local HEAD_SUBS = { [401] = true } -- [FIX VIP] Removed 502 and 505 to fully separate Helmet from Hair/Fashion Hats
local BAG_SUBS = { [501] = true, [504] = true }
local FACE_SUBS = { [402] = true, [407] = true }
local BODY_SUBS = { [404] = true, [405] = true, [501] = true, [504] = true, [502] = true, [505] = true }
local GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
local THROW_SUBS = { [612] = "shoulei", [613] = "smoke", [614] = "stun", [615] = "burn" }
local THROW_AVATAR_KEYS = {
    shoulei = "GrenadeAvatarShoulei", smoke = "GrenadeAvatarSmoke",
    stun = "GrenadeAvatarStun", burn = "GrenadeAvatarBurn",
}
local THROW_WEAPON_TO_SUB = { [602001] = 614, [602002] = 613, [602003] = 615, [602004] = 612 }
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {}, byWeapon = {} }
local _matchApplied = false

_G.AddOutfitPersist = _G.AddOutfitPersist or { path = nil, dirty = false, scheduled = false, loaded = nil, lastWritten = nil, configVehicleSlots = nil, configWeapons = nil, weaponConfigLoaded = false, configSlots = nil, lobbyVehicleSubType = nil, lobbyVehicleIns = nil, lobbyVehicleResID = nil, hallThemeResID = nil, hallThemeIns = nil, configChassisLight = nil, configChassisLightMap = nil }
local PERSIST = _G.AddOutfitPersist
PERSIST.configThrowObjects = PERSIST.configThrowObjects or {}

F.persistMarkDirty = function() end

local PERF = {
    lobbySynced     = false,
    mappingsDirty   = true,
    desiredSkins    = nil,
    skinTarget      = {},
    matchActive     = false,
    lastBootstrapAt = 0,
    wearDoneThisMatch = false,  
}
local MATCH_TICK_SEC    = 3.0
local MATCH_MAX_SEC     = 45.0
local BOOTSTRAP_COOLDOWN = 2.0
local INJECT_RETRY_MAX  = 5
local INJECT_RETRY_SEC  = 3.0

function F.lobbyState()
    _G.AddOutfitLobbyState = _G.AddOutfitLobbyState or {
        wardrobeRefreshed = false,
        reapplyScheduled  = false,
        reapplyDone       = false,
        outfitResolved    = false,
        skinResolved      = false,
        cachedOutfit      = nil,
        cachedSkin        = nil,
        injectRefreshGen  = 0,
        lobbySynced       = false,
    }
    return _G.AddOutfitLobbyState
end

local LOBBY = setmetatable({}, {
    __index = function(_, k) return F.lobbyState()[k] end,
    __newindex = function(_, k, v) F.lobbyState()[k] = v end,
})

function F.invalidateLobbyResolved()
    LOBBY.outfitResolved = false
    LOBBY.skinResolved   = false
    LOBBY.cachedOutfit   = nil
    LOBBY.cachedSkin     = nil
end

function F.perfInvalidateLobby()
    LOBBY.lobbySynced   = false
    PERF.mappingsDirty = true
    PERF.desiredSkins  = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    F.invalidateLobbyResolved()
end

function F.cache()
    _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
        outfitRes = nil, outfitIns = nil,
        hatRes = nil, hatIns = nil,
        maskRes = nil, maskIns = nil,
        glassRes = nil, glassIns = nil,
        tshirtRes = nil, tshirtIns = nil,
        pantsRes = nil, pantsIns = nil,
        shoesRes = nil, shoesIns = nil,
        bagRes = nil, bagIns = nil,
        helmetRes = nil, helmetIns = nil,
        weapons = {},
        throwObjects = {},
        vehicleSlots = {},  
        hallThemeRes = nil, hallThemeIns = nil,
        parachuteRes = nil, parachuteIns = nil,
        gliderRes = nil, gliderIns = nil,
        glovesRes = nil, glovesIns = nil,
    }
    local cch = _G.AddOutfitEquippedCache
    cch.weapons = cch.weapons or {}
    cch.throwObjects = cch.throwObjects or {}
    cch.vehicleSlots = cch.vehicleSlots or {}
    return cch
end
function F.cfg(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

function F.subType(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

function F.wardrobeTab(resID)
    local c = F.cfg(resID)
    return c and tonumber(c.WardrobeTab) or 0
end

function F.depotResID(v)
    return v and tonumber(v.resID or v.res_id) or nil
end

function F.resToCustSlot(resID, st)
    resID, st = tonumber(resID), tonumber(st)
    if not resID or resID <= 0 then return nil end
    st = st or F.subType(F.cfg(resID))
    if st == HAT_SUB or HAT_SUBS[st] then return F.CUST_SLOT.HatEquipemtSlot end
    if st == OUTFIT_SUB then return F.CUST_SLOT.ClothesEquipemtSlot end
    if st == PANTS_SUB then return F.CUST_SLOT.PantsEquipemtSlot end
    if st == SHOES_SUB then return F.CUST_SLOT.ShoesEquipemtSlot end
    if st == MASK_SUB then return F.CUST_SLOT.FaceEquipemtSlot end
    if st == GLASS_SUB then return F.CUST_SLOT.GlassEquipemtSlot end
    if st == GLOVES_SUB then return F.CUST_SLOT.HandEffectEquipemtSlot end
    if BAG_SUBS[st] then return F.CUST_SLOT.BackpackEquipemtSlot end
    if HELMET_SUBS[st] then return F.CUST_SLOT.HelmetEquipemtSlot end
    if F.isParachuteRes(resID) or st == PARACHUTE_SUB then return F.CUST_SLOT.ParachuteEquipemtSlot end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then return F.CUST_SLOT.GlideEquipemtSlot end
    return nil
end

function F.isSuitRes(resID)
    if F.subType(F.cfg(resID)) ~= OUTFIT_SUB then return false end
    return F.wardrobeTab(resID) ~= TAB_CLOTHES
end

function F.isTshirtRes(resID)
    return F.subType(F.cfg(resID)) == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES
end

function F.weaponIdFromSkin(resID)
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
    if not m then return nil end
    return m.WeaponID or m.WeaponId
end
function F.throwObjectSubtype(resID)
    local st = tonumber(F.subType(F.cfg(tonumber(resID))))
    if st and THROW_SUBS[st] then return st end
    return nil
end

-- Keep this mapping identical to the melee slider catalog.  Melee resources
-- are grouped by their resource prefix rather than WeaponSkinMapping.
function F.meleeKindFromRes(resID)
    resID = tonumber(resID)
    if not resID then return nil end
    local prefix = tostring(math.floor(resID / 1000))
    if prefix == "1108004" then return "pan" end
    if prefix == "1108005" then return "dagger" end
    if prefix == "1108001" then return "machete" end
    return nil
end

function F.normalizeWeaponId(weaponID, resID)
    weaponID, resID = tonumber(weaponID), tonumber(resID)
    if weaponID == 108001 or weaponID == 108004 or weaponID == 108005
        or F.meleeKindFromRes(resID) then
        return MELEE_ID
    end
    return weaponID
end
function F.isValidWeaponId(weaponID)
    weaponID = tonumber(weaponID)
    if not weaponID or weaponID <= 0 then return false end
    if weaponID == MELEE_ID or weaponID == 108001 or weaponID == 108004 or weaponID == 108005 then return true end
    return weaponID >= 101000 and weaponID < 108000
end

function F.isValidWeaponPersistEntry(weaponID, resID)
    weaponID, resID = tonumber(weaponID), tonumber(resID)
    if not F.isValidWeaponId(weaponID) or not resID or resID <= 0 then return false end
    if weaponID == resID then return false end
    if resID >= 1800000 and resID < 1810000 then return false end
    if resID >= 1900000 and resID < 2000000 then return false end
    -- Pan, dagger and machete resources often have no row in
    -- WeaponSkinMapping. Prefer the item subtype when the table is available,
    -- but use the known resource family as a safe early-start fallback.
    if weaponID == MELEE_ID or weaponID == 108001 or weaponID == 108004 or weaponID == 108005 then
        local kind = F.meleeKindFromRes(resID)
        local st = tonumber(F.subType(F.cfg(resID)))
        return kind ~= nil and (st == nil or st == MELEE_ID)
    end
    if F.isInjectedRes(resID) then
        local wid = tonumber(F.weaponIdFromSkin(resID))
        return wid and wid == weaponID
    end
    local wid = tonumber(F.weaponIdFromSkin(resID))
    return wid and wid == weaponID
end

function F.sanitizeConfigWeapons(wmap)
    if type(wmap) ~= "table" then return {} end
    local clean = {}
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        wid = F.normalizeWeaponId(wid, res)
        if F.isValidWeaponPersistEntry(wid, res) then clean[wid] = res end
    end
    return clean
end

function F.indexWeaponSkin(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    if not (GUN_SUB[st] or st == MELEE_ID) then return end
    local wid = F.weaponIdFromSkin(resID)
    if st == MELEE_ID then wid = MELEE_ID end
    wid = tonumber(wid)
    if not wid or wid <= 0 then return end
    R.byWeapon[wid] = R.byWeapon[wid] or {}
    R.byWeapon[wid][resID] = insID
end

-- Varian tanpa CDataTable.GetTableData: subtype sudah diketahui dari meta
-- katalog, jadi injeksi massal tidak memanggil config native dua kali.
function F.indexWeaponSkinDirect(resID, insID, st)
    resID, insID, st = tonumber(resID), tonumber(insID), tonumber(st)
    if not resID or not insID or not st then return end
    if not (GUN_SUB[st] or st == MELEE_ID) then return end
    local wid = (st == MELEE_ID) and MELEE_ID or tonumber(F.weaponIdFromSkin(resID))
    if not wid or wid <= 0 then return end
    local t = R.byWeapon[wid]
    if not t then t = {}; R.byWeapon[wid] = t end
    t[resID] = insID
    F.injectArmory(resID, insID, wid)
end

function F.isInjectedIns(ins)
    return ins and R.insToRes[tonumber(ins)] ~= nil
end

function F.isInjectedRes(res)
    return res and R.resToIns[tonumber(res)] ~= nil
end

-- "Owned" untuk Wardrobe = ada di katalog live PUBG. Ini dipakai sebelum
-- injeksi sempat jalan (mis. cek HasItem saat loading) dan oleh UI yang
-- menanyakan status milik tanpa menyentuh depot.
function F.isOwnedRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    if R.resToIns[resID] then return true end
    local set = ITEM_CATALOG_SET
    if not set then
        buildItemCatalog()
        set = ITEM_CATALOG_SET
    end
    return set ~= nil and set[resID] == true
end

-- Materialisasi satu item katalog ke depot atas permintaan. Dipakai kalau
-- ada kode yang menanyakan item tertentu sebelum injectAll selesai.
function F.ensureOwnedDepot(resID)
    resID = tonumber(resID)
    if not resID then return nil end
    local e = F.getEntity and F.getEntity() or nil
    if not e or not e.bInit or type(e._data) ~= "table" then return nil end
    local arr = e.ResIDToIndexArrayMap and e.ResIDToIndexArrayMap[resID]
    if arr then
        for k = 1, #arr do
            local d = e._data[arr[k]]
            if d then return d end
        end
    end
    local idx = F.catalogIndex(resID)
    if not idx then return nil end
    local insID = INS_BASE + idx
    if not e.InsIDToIndexMap or e.InsIDToIndexMap[insID] == nil then
        pcall(F.injectOne, e, resID, insID)
    end
    return e:GetDataByInsID(insID)
end

function F.ensureOwnedDepotByIns(insID)
    insID = tonumber(insID)
    if not insID then return nil end
    if insID >= INS_BASE then
        local res = F.syntheticResFromIns(insID)
        if res then return F.ensureOwnedDepot(res) end
        return nil
    end
    local e = F.getEntity and F.getEntity() or nil
    if not e then return nil end
    return e:GetDataByInsID(insID)
end

function F.isWeaponSkinRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    return GUN_SUB[st] or tonumber(st) == MELEE_ID or F.meleeKindFromRes(resID) ~= nil
end

function F.isWeaponSkinIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local res = R.insToRes[insID]
    return res and F.isWeaponSkinRes(res)
end

function F.cleanArmoryPollution()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if not Arm.rsp_list then return end
        if Arm.rsp_list.install_list then
            for wid, entry in pairs(Arm.rsp_list.install_list) do
                local ins = tonumber(entry and entry.skin_id)
                if ins and not F.isWeaponSkinIns(ins) then
                    Arm.rsp_list.install_list[wid] = nil
                end
            end
        end
        if Arm.rsp_list.skin_list then
            for wid, skins in pairs(Arm.rsp_list.skin_list) do
                if type(skins) == "table" then
                    for resID in pairs(skins) do
                        if not F.isWeaponSkinRes(tonumber(resID)) then
                            skins[resID] = nil
                        end
                    end
                end
            end
        end
    end)
end

function F.depotSubType(insID, resID)
    resID = tonumber(resID) or tonumber(R.insToRes[insID])
    local st = F.subType(F.cfg(resID))
    if st then return st end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    return d and tonumber(d.itemSubType)
end

-- ============================================================================
-- RESPON EQUIP LOKAL
--
-- Server tidak tahu item sintetis, jadi `depot_put_on_req` untuk item katalog
-- pasti ditolak dan wardrobe tidak pernah masuk jalur sukses. Di sini respon
-- sukses dibentuk sendiri memakai fungsi handler game yang asli, sehingga
-- SELURUH logika on_puton_rsp berjalan: model hall, fashion bag, grenade,
-- event grid, dan penyimpanan skin.
--
-- `index` untuk throw object HARUS indeks fashion bag yang aktif; kalau tidak,
-- skin grenade masuk ke bag lain dan tidak terlihat terpakai.
-- ============================================================================
function F.activeBagIndex()
    local idx
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        idx = tonumber(fbd:GetFashionBagUseIndex())
        local bag = idx and fbd:GetFashionBag(idx)
        if not bag or type(bag.throw_object_list) ~= "table" then idx = nil end
    end)
    return idx
end

function F.localEquipResponse(insID, extra, oldInsID)
    insID = tonumber(insID)
    if not insID then return false end
    local resID = tonumber(R.insToRes[insID])
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not resID and d then resID = tonumber(d.resID or d.res_id) end
    if not resID or resID <= 0 then return false end
    local WRH = require("client.network.Protocol.WardRobeHandler")
    if type(WRH.on_depot_put_on_rsp) ~= "function" then return false end

    local item = {
        res_id = resID,
        count = tonumber(d and d.count) or 1,
        -- expire_ts = 0 (truthy) mencegah UpdateLastEquipForeverSkin menyimpan
        -- insID sintetis sebagai skin permanen akun.
        expire_ts = 0,
        color = d and d.colorID or nil,
        pattern = d and d.patternID or nil,
    }
    local olditem
    oldInsID = tonumber(oldInsID)
    if (not oldInsID or oldInsID <= 0) and d then
        -- Cari item yang sedang dipakai untuk subtipe yang sama supaya
        -- on_puton_rsp bisa melepas yang lama (tidak menumpuk dua skin).
        pcall(function()
            local la = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
            local sub = tonumber(d.itemSubType)
            local wear = la:GetCurrentWearPreview(sub)
            local cur = wear and tonumber(wear.insID)
            if cur and cur > 0 and cur ~= insID then oldInsID = cur end
        end)
    end
    if oldInsID and oldInsID > 0 then
        local od = wd:GetHallDepotItemDataByInsID(oldInsID)
        if od then
            olditem = {
                res_id = od.resID or od.res_id,
                count = od.count,
                expire_ts = 0,
                color = od.colorID,
                pattern = od.patternID,
            }
        end
    end

    local index = F.activeBagIndex()
    local called = pcall(WRH.on_depot_put_on_rsp, NET_OK, item, olditem, index, insID, oldInsID or 0, extra)
    return called
end

function F.localUnequipResponse(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local resID = tonumber(R.insToRes[insID])
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not resID and d then resID = tonumber(d.resID or d.res_id) end
    if not resID or resID <= 0 then return false end
    local WRH = require("client.network.Protocol.WardRobeHandler")
    if type(WRH.on_depot_put_down_rsp) ~= "function" then return false end
    local called = pcall(WRH.on_depot_put_down_rsp, NET_OK, {
        res_id = resID,
        count = tonumber(d and d.count) or 1,
        expire_ts = 0,
    }, insID)
    return called
end

function F.tryLocalWearByIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local resID = R.insToRes[insID]
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not resID and d then resID = tonumber(d.resID or d.res_id) end
    if not resID or resID <= 0 then return false end
    if not RAPZHANG_MOD_SKIN_ALWAYS_ON then return false end -- Skip if Mod Skin is disabled
    local st = F.depotSubType(insID, resID)

    local function mapLocal()
        if not R.insToRes[insID] then
            R.insToRes[insID] = resID
            R.resToIns[resID] = insID
        end
    end

    if st == GLOVES_SUB then mapLocal(); F.putOnGloves(insID) return true end
    if THROW_SUBS[tonumber(st)] then
        mapLocal()
        -- Jalur sukses asli: ShowGrenadeModel + PutOnThrowObjectSkin ke
        -- fashion bag aktif + event update grid. Kalau handler belum siap,
        -- simpan konfigurasi supaya skin tetap dipakai saat match.
        if not F.localEquipResponse(insID) then
            F.saveThrowObject(resID, insID)
        end
        pcall(F.applyThrowObjectSkins)
        return true
    end
    F.clearItemExpire(d, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if F.isParachuteRes(resID) then mapLocal(); return F.putOnParachute(insID) end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then mapLocal(); return F.putOnGlider(insID) end

    if st == OUTFIT_SUB then
        mapLocal()
        if F.isSuitRes(resID) or F.wardrobeTab(resID) == TAB_SUIT then
            F.putOnOutfit(insID)
        else
            F.putOnRoleWear(insID)
        end
        return true
    end
    if st == HAT_SUB or HEAD_SUBS[st] then mapLocal(); F.putOnHat(insID) return true end
    if FACE_SUBS[st] then mapLocal(); F.putOnFaceAccessory(insID) return true end
    if BODY_SUBS[st] or HELMET_SUBS[st] then mapLocal(); F.putOnRoleWear(insID) return true end

    if not F.isOwnedRes(resID) then return false end
    if GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.equipWeaponSkin(wid, insID) end
        return true
    end
    if st == MELEE_ID then F.equipWeaponSkin(MELEE_ID, insID) return true end
    if F.isHallThemeRes(resID) and (F.isOwnedRes(resID) or F.isInjectedIns(insID)) then
        mapLocal()
        return F.putOnHallTheme(insID)
    end
    if F.isVehicleRes(resID) and (F.isOwnedRes(resID) or F.isInjectedIns(insID)) then
        mapLocal()
        return F.putOnVehicle(insID)
    end
    -- Fallback generik: semua tab wardrobe lain (emoji, quicksign, quick
    -- message, emoji bubble, holografi, plating, bag pendant, lobby music,
    -- MiniTV, MVP motion, foot effect, toy, cabin show, dll) tetap memakai
    -- on_puton_rsp asli, jadi event dan tampilan grid ikut benar.
    mapLocal()
    if F.localEquipResponse(insID) then return true end
    return false
end

function F.isHallThemeRes(resID)
    local c = F.cfg(tonumber(resID))
    if not c then return false end
    local t = c.ItemType or c.itemType
    return t == HALL_THEME_TYPE
end

function F.isResourcesReady(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if not F.isInjectedRes(resID) and not F.isOwnedRes(resID) then return true end
    local ready = false
    pcall(function()
        local PufferConst = require("client.slua.logic.download.puffer_const")
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and mgr.GetStateByItemID then
            local st = mgr:GetStateByItemID(resID)
            ready = st == PufferConst.ENUM_DownloadState.Done
        end
    end)
    return ready
end

function F.requestResourceDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    if not F.isOwnedRes(resID) and not F.isInjectedRes(resID) then return end
    if F.isResourcesReady(resID) then return end
    _G.AddOutfitDownloadQueued = _G.AddOutfitDownloadQueued or {}
    if _G.AddOutfitDownloadQueued[resID] then return end
    _G.AddOutfitDownloadQueued[resID] = true
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PM.Download(PufferConst.ENUM_DownloadType.ODPAK, { resID }, "AddOutfit", function()
            _G.AddOutfitDownloadQueued[resID] = nil
        end)
    end)
end

function F.ensureInjectedResources()
    for res in pairs(R.resToIns) do
        F.requestResourceDownload(tonumber(res))
    end
end

function F.restorePufferHooks()
    pcall(function()
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and _G.AddOutfitPufferOrig then
            mgr.GetStateByItemID = _G.AddOutfitPufferOrig
        end
    end)
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        if PM and _G.AddOutfitPufferGetStateOrig then
            PM.GetState = _G.AddOutfitPufferGetStateOrig
        end
    end)
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local vacImpl = VAC and VAC.__inner_impl
        if vacImpl and _G.AddOutfitVehOrigAssets then
            vacImpl.LuaIsAssetsAlreadyAvailable = _G.AddOutfitVehOrigAssets
        end
    end)
end

function F.invalidateSocialWearCache()
    local s = _G.AddOutfitSocialState
    if s then
        s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
    end
end

function F.clearWeaponEquippedMark(weaponID)
    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if weaponID then
        _G.AddOutfitWeaponEquipped[tonumber(weaponID)] = nil
    else
        for k in pairs(_G.AddOutfitWeaponEquipped) do _G.AddOutfitWeaponEquipped[k] = nil end
    end
end

function F.isWeaponVisuallyEquipped(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID then return false end
    return _G.AddOutfitWeaponEquipped and _G.AddOutfitWeaponEquipped[weaponID] == insID
end

function F.saveWeaponToCache(weaponID, resID, insID)
    weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
    weaponID = F.normalizeWeaponId(weaponID, resID)
    F.clearWeaponEquippedMark(weaponID)
    if not F.isValidWeaponPersistEntry(weaponID, resID) then return end
    local cch = F.cache()
    cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
    PERSIST.configWeapons = PERSIST.configWeapons or {}
    PERSIST.configWeapons[weaponID] = resID
    if weaponID == MELEE_ID then
        local kind = F.meleeKindFromRes(resID)
        if kind then
            PERSIST.configMelee = PERSIST.configMelee or {}
            PERSIST.configMelee[kind] = resID
        end
    end
    _G.AddOutfitLastAppliedSkin = {}
    _matchApplied = false
    F.perfInvalidateLobby()
    F.invalidateSocialWearCache()
    F.persistMarkDirty()
    F.log("ذاكرة سكن", weaponID, "→", resID)
end

-- Keep all melee sources synchronized.  The game exposes Pan/Dagger/Machete
-- through the single native weapon slot 108, while the slider and JSON use
-- separate names.  Normalize every source to both representations.
function F.syncMeleeSelection(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    local kind = F.meleeKindFromRes(resID)
    if not kind or not F.isValidWeaponPersistEntry(MELEE_ID, resID) then return false end
    if insID and insID > 0 then
        R.resToIns[resID] = insID
        R.insToRes[insID] = resID
    end
    local cch = F.cache()
    cch.weapons[MELEE_ID] = { resID = resID, insID = insID or (R.resToIns[resID] or 0) }
    PERSIST.configMelee = PERSIST.configMelee or {}
    PERSIST.configWeapons = PERSIST.configWeapons or {}
    PERSIST.configMelee[kind] = resID
    PERSIST.configWeapons[MELEE_ID] = resID
    pcall(F.persistMarkDirty)
    return true
end

function F.cacheWeaponSkinFromIns(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or insID <= 0 then return end
    if F.isInjectedIns(insID) then
        F.saveWeaponToCache(weaponID, R.insToRes[insID], insID)
        return
    end
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        if d and d.resID and tonumber(d.resID) > 0 then
            F.saveWeaponToCache(weaponID, tonumber(d.resID), insID)
        end
    end)
end

function F.saveThrowObject(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    local st = F.throwObjectSubtype(resID)
    if not st then return false end
    local cch = F.cache()
    local record = { resID = resID, insID = insID or R.resToIns[resID] or 0 }
    cch.throwObjects[st] = record
    PERSIST.configThrowObjects = PERSIST.configThrowObjects or {}
    PERSIST.configThrowObjects[st] = resID
    F.requestResourceDownload(resID)
    F.persistMarkDirty()
    return true
end
function F.saveEquip(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = resID, insID
            _G.AddOutfitLastLobbyTshirtRes = resID
            F.persistRememberSlot("tshirt", resID)
        else
            cch.outfitRes, cch.outfitIns = resID, insID
            _G.AddOutfitLastLobbyOutfitRes = resID
            F.persistRememberSlot("outfit", resID)
            F.invalidateSocialWearCache()
        end
    elseif st == HAT_SUB then
        cch.hatRes, cch.hatIns = resID, insID
        _G.AddOutfitLastLobbyHatRes = resID
        F.persistRememberSlot("hat", resID)
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = resID, insID
        _G.AddOutfitLastLobbyMaskRes = resID
        F.persistRememberSlot("mask", resID)
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = resID, insID
        _G.AddOutfitLastLobbyGlassRes = resID
        F.persistRememberSlot("glass", resID)
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = resID, insID
        _G.AddOutfitLastLobbyPantsRes = resID
        F.persistRememberSlot("pants", resID)
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = resID, insID
        _G.AddOutfitLastLobbyShoesRes = resID
        F.persistRememberSlot("shoes", resID)
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = resID, insID
        _G.AddOutfitLastLobbyBagRes = resID
        F.persistRememberSlot("bag", resID)
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = resID, insID
        _G.AddOutfitLastLobbyHelmetRes = resID
        F.persistRememberSlot("helmet", resID)
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = resID, insID
        _G.AddOutfitLastLobbyParachuteRes = resID
        F.persistRememberSlot("parachute", resID)
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = resID, insID
        _G.AddOutfitLastLobbyGliderRes = resID
        F.persistRememberSlot("glider", resID)
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = resID, insID
        _G.AddOutfitLastLobbyGlovesRes = resID
        F.persistRememberSlot("gloves", resID)
    elseif THROW_SUBS[tonumber(st)] then
        F.saveThrowObject(resID, insID)
    elseif GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.saveWeaponToCache(wid, resID, insID) end
    elseif st == MELEE_ID then
        F.saveWeaponToCache(MELEE_ID, resID, insID)
    end
    _matchApplied = false
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.findWornInsBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    return ins, res
                end
            end
        end
    end
    return nil
end

function F.syncHatCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(HAT_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.hatRes, cch.hatIns = tonumber(res), ins
            return
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        local headIns = tonumber(bag and bag.head_show) or 0
        if headIns <= 0 then return end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(headIns) or wd:GetHallDepotItemDataByInsID(headIns)
        if not d or not d.resID or tonumber(d.resID) <= 0 then return end
        local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
        if HEAD_SUBS[st] then
            cch.hatRes, cch.hatIns = tonumber(d.resID), headIns
        end
    end)
end

function F.syncFaceCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(MASK_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.maskRes, cch.maskIns = tonumber(res), ins
            _G.AddOutfitLastLobbyMaskRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLASS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glassRes, cch.glassIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlassRes = tonumber(res)
        end
    end)
end

function F.syncBodyCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.wardrobeTab(r) == TAB_CLOTHES end)
        if ins and res and tonumber(res) > 0 then
            cch.tshirtRes, cch.tshirtIns = tonumber(res), ins
            _G.AddOutfitLastLobbyTshirtRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(PANTS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.pantsRes, cch.pantsIns = tonumber(res), ins
            _G.AddOutfitLastLobbyPantsRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(SHOES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.shoesRes, cch.shoesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyShoesRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLOVES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glovesRes, cch.glovesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlovesRes = tonumber(res)
        end
    end)
    pcall(function()
        for st in pairs(BAG_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.bagRes, cch.bagIns = tonumber(res), ins
                _G.AddOutfitLastLobbyBagRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        for st in pairs(HELMET_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.helmetRes, cch.helmetIns = tonumber(res), ins
                _G.AddOutfitLastLobbyHelmetRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        if ins and res and tonumber(res) > 0 then
            cch.outfitRes, cch.outfitIns = tonumber(res), ins
            _G.AddOutfitLastLobbyOutfitRes = tonumber(res)
        end
    end)
end

function F.syncAirborneCacheFromLobby(saveToConfig)
    local cch = F.cache()
    local cfgPara = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    local cfgGlide = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    local changed = false

    local function maybeSave(slotName, res)
        if not saveToConfig or not res or res <= 0 then return end
        if slotName == "parachute" and res == DEFAULT_PARACHUTE_RES
            and cfgPara and cfgPara > 0 and cfgPara ~= DEFAULT_PARACHUTE_RES then
            return
        end
        F.persistRememberSlot(slotName, res)
        changed = true
    end

    local function applyPara(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isParachuteRes(res) then return end
        if cfgPara and cfgPara > 0 and not saveToConfig then
            if res == cfgPara then cch.parachuteIns = ins end
            return
        end
        if res == DEFAULT_PARACHUTE_RES and not saveToConfig then return end
        if cch.parachuteRes ~= res or cch.parachuteIns ~= ins then
            cch.parachuteRes, cch.parachuteIns = res, ins
            _G.AddOutfitLastLobbyParachuteRes = res
            maybeSave("parachute", res)
        end
    end

    local function applyGlide(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isGlideRes(res) then return end
        if cfgGlide and cfgGlide > 0 and not saveToConfig then
            if res == cfgGlide then cch.gliderIns = ins end
            return
        end
        if cch.gliderRes ~= res or cch.gliderIns ~= ins then
            cch.gliderRes, cch.gliderIns = res, ins
            _G.AddOutfitLastLobbyGliderRes = res
            maybeSave("glider", res)
        end
    end

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local paraIns = tonumber(fbd.GetParachute and fbd:GetParachute()) or 0
        if paraIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(paraIns) or wd:GetHallDepotItemDataByInsID(paraIns)
            applyPara(d and tonumber(d.resID), paraIns)
        end
        local glideIns = tonumber(fbd.GetAircraftOrGliding and fbd:GetAircraftOrGliding()) or 0
        if glideIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(glideIns) or wd:GetHallDepotItemDataByInsID(glideIns)
            applyGlide(d and tonumber(d.resID), glideIns)
        end
    end)
    pcall(function()
        for st in pairs(GLIDER_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res then applyGlide(res, ins) break end
        end
        local ins, res = F.findWornInsBySubType(PARACHUTE_SUB)
        if ins and res then applyPara(res, ins) end
    end)
    if changed then F.persistMarkDirty() end
end

function F.syncWeaponCacheFromLobby(force)
    if LOBBY.lobbySynced and not force then return end
    LOBBY.lobbySynced = true
    PERF.mappingsDirty = true
    PERF.desiredSkins = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    local cch = F.cache()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.weapon_skin_list then
            for weaponID, entry in pairs(bag.weapon_skin_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and (entry.skin_id or entry.skinId)) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    weaponID = F.normalizeWeaponId(weaponID, res)
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm.rsp_list and Arm.rsp_list.install_list then
            for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and entry.skin_id) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    weaponID = F.normalizeWeaponId(weaponID, res)
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    -- Normalize the lobby's active melee selection after both inventory and
    -- armory sources have been read. This covers a lobby equip that existed
    -- before the mod menu initialized.
    pcall(function()
        local mw = cch.weapons[MELEE_ID]
        local configured = tonumber(PERSIST.configWeapons and PERSIST.configWeapons[MELEE_ID])
            or tonumber(MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[MELEE_ID])
            or tonumber(PERSIST.configMelee and PERSIST.configMelee.pan)
            or tonumber(PERSIST.configMelee and PERSIST.configMelee.dagger)
            or tonumber(PERSIST.configMelee and PERSIST.configMelee.machete)
        if mw and mw.resID and not configured then
            F.syncMeleeSelection(mw.resID, mw.insID)
        end
    end)
    -- A saved slider/JSON choice has priority over a stale native lobby
    -- cache. Restore it after reading the lobby so the match bootstrap cannot
    -- replace it with the previous weapon-108 value.
    pcall(function()
        local savedMelee = tonumber(PERSIST.configWeapons and PERSIST.configWeapons[MELEE_ID])
            or tonumber(MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[MELEE_ID])
        local savedIns = savedMelee and (R.resToIns[savedMelee] or F.resolveInsForRes(savedMelee))
        if savedMelee and savedIns then
            cch.weapons[MELEE_ID] = { resID = savedMelee, insID = savedIns }
        end
    end)
    F.syncHatCacheFromLobby()
    F.syncFaceCacheFromLobby()
    F.syncBodyCacheFromLobby()
end

function F.getCachedWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    if weaponID <= 0 then return nil end
    F.syncWeaponCacheFromLobby()
    local w = F.cache().weapons[weaponID]
    if w and w.resID and w.resID > 0 then return w.resID end
    return nil
end

function F.getMatchWeaponSkin(weaponID)
    weaponID = F.normalizeWeaponId(weaponID) or tonumber(weaponID) or 0
    -- When rapzhang_outfit contains a weapons table, it is authoritative.
    -- An absent key means an empty slot, not permission to reuse native/cache data.
    if PERSIST.weaponConfigLoaded then
        local configured = tonumber(PERSIST.configWeapons and PERSIST.configWeapons[weaponID])
        if configured and configured > 0 then return configured end
        return nil
    end
    if weaponID == MELEE_ID then
        local configured = tonumber(MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[MELEE_ID])
            or tonumber(PERSIST.configWeapons and PERSIST.configWeapons[MELEE_ID])
        if configured and configured > 0 then return configured end
    end
    local fromCache = F.getCachedWeaponSkin(weaponID)
    if fromCache then return fromCache end
    if MATCH_CONFIG.weaponSkins then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
        if fixed and fixed > 0 then return fixed end
    end
    return nil
end

function F.removeRoleWearBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    AvatarData.RemoveRoleWearDataByValue(ins)
                end
            end
        end
    end
end

function F.syncFashionBagRolewear()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

local _ticker
pcall(function() _ticker = require("common.time_ticker") end)
function F.later(sec, fn)
    if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
    if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
end

function F.getPC()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    local ok, gd = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and gd then
        local pc = gd.GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    return nil
end

function F.syncVehicleSlotsToDataMgr()
    local cch = F.cache()
    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        local arr = DataMgr.VehicleSlotList[subType]
        if not arr then arr = {}; DataMgr.VehicleSlotList[subType] = arr end
        for k in pairs(arr) do arr[k] = nil end
        for idx, e in pairs(slots or {}) do
            if e and tonumber(e.insID) and tonumber(e.insID) > 0 then
                arr[tonumber(idx)] = tonumber(e.insID)
            end
        end
    end
end

function F.mergeInjectedIntoVehicleSlotList(serverList)
    serverList = serverList or {}
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            local arr = serverList[subType]
            if not arr then arr = {}; serverList[subType] = arr end
            for idx, e in pairs(slots) do
                idx = tonumber(idx)
                local insID = e and tonumber(e.insID)
                if idx and insID and insID > 0 and F.isInjectedIns(insID) then
                    arr[idx] = insID
                end
            end
        end
    end
    local cfg = PERSIST.configVehicleSlots
    if cfg then
        for subType, slotMap in pairs(cfg) do
            subType = tonumber(subType)
            if subType and type(slotMap) == "table" then
                local arr = serverList[subType]
                if not arr then arr = {}; serverList[subType] = arr end
                for idx, res in pairs(slotMap) do
                    idx, res = tonumber(idx), tonumber(res)
                    local ins = res and R.resToIns[res]
                    if idx and ins and F.isInjectedIns(ins) then
                        arr[idx] = ins
                    end
                end
            end
        end
    end
    return serverList
end

function F.applyVehicleSlotsFromConfigMap(slotMap)
    if not slotMap or not next(slotMap) then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local any = false
    for subType, slots in pairs(slotMap) do
        subType = tonumber(subType)
        if subType then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, res in pairs(slots) do
                idx, res = tonumber(idx), tonumber(res)
                local ins = res and R.resToIns[res]
                if idx and ins then
                    cch.vehicleSlots[subType][idx] = { resID = res, insID = ins }
                    any = true
                end
            end
        end
    end
    return any
end

function F.notifyVehicleSlotUI()
    pcall(function()
        local WRH = require("client.network.Protocol.WardrobeNewHandler")
        WRH.on_depot_modify_combat_vehicle_rsp(0, DataMgr.VehicleSlotList or {})
    end)
end

function F.mergeInjectedVehicleSkinTable(serverTable)
    serverTable = serverTable or {}
    local cfg = PERSIST.configVehicleSlots
    if not cfg then return serverTable end
    for subType, slotMap in pairs(cfg) do
        subType = tonumber(subType)
        if subType and type(slotMap) == "table" then
            local res = tonumber(slotMap[1] or slotMap["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                serverTable[subType] = ins
            end
        end
    end
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        local e = slots and (slots[1] or slots["1"])
        local insID = e and tonumber(e.insID)
        if subType and insID and insID > 0 and F.isInjectedIns(insID) then
            serverTable[subType] = insID
        end
    end
    return serverTable
end

function F.equipVehicleTypesFromConfig(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
    local subTypes = {}
    for st in pairs(slotMap) do
        local n = tonumber(st)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    local any, lobbyRes, lobbyIns = false, nil, nil
    for _, subType in ipairs(subTypes) do
        local slots = slotMap[subType] or slotMap[tostring(subType)]
        if type(slots) == "table" then
            local res = tonumber(slots[1] or slots["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                DataMgr.vehicleSkinInsIDTable[subType] = ins
                any = true
                if not lobbyIns then
                    lobbyRes, lobbyIns = res, ins
                end
            end
        end
    end
    if any then
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    return any, lobbyRes, lobbyIns
end

function F.applyLobbyVehicleDisplay(resID, insID, showVehicle)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or insID <= 0 then return end
    _G.AddOutfitApplyingConfig = true
    pcall(function() DataMgr.vst_skin = insID end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        HallThemeUtils.ProcPutOnVehicle({ res_id = resID, instid = insID }, showVehicle ~= false)
    end)
    pcall(F.applyVehicleSkinsToPC)
    _G.AddOutfitApplyingConfig = false
end

function F.setLobbyVehicleManual(subType, resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    subType = tonumber(subType)
    if not insID then return end
    if F.isChassisLightId(resID) or subType == CHASSIS_LIGHT_SUB then return end
    if resID and not F.isVehicleRes(resID) then return end
    if not F.isInjectedIns(insID) and not F.isVehicleRes(resID) then return end
    if not resID then resID = R.insToRes[insID] end
    if not subType and resID then subType = tonumber(F.vehicleSubType(resID)) end
    _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
    _G.AddOutfitLobbyVeh.manual = true
    _G.AddOutfitLobbyVeh.subType = subType
    _G.AddOutfitLobbyVeh.resID = resID
    _G.AddOutfitLobbyVeh.insID = insID
    PERSIST.lobbyVehicleSubType = subType
    PERSIST.lobbyVehicleIns = insID
    PERSIST.lobbyVehicleResID = resID
    F.persistMarkDirty()
end

function F.resolveLobbyVehicle(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    local L = _G.AddOutfitLobbyVeh or {}
    local st = tonumber(PERSIST.lobbyVehicleSubType) or tonumber(L.subType)
    local res = tonumber(PERSIST.lobbyVehicleResID) or tonumber(L.resID)
    if res and res > 0 then
        local ins = R.resToIns[res]
        if ins then
            if not st then st = tonumber(F.vehicleSubType(res)) end
            return res, ins, st
        end
    end
    local ins = tonumber(PERSIST.lobbyVehicleIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then
        res = R.insToRes[ins] or res
        if not st and res then st = tonumber(F.vehicleSubType(res)) end
        return res, ins, st
    end
    if st and slotMap then
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    local subTypes = {}
    for s in pairs(slotMap or {}) do
        local n = tonumber(s)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    if subTypes[1] then
        st = subTypes[1]
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    return nil, nil, nil
end

function F.syncLobbyVehicleResFromIns()
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0 then return end
    local ins = tonumber(PERSIST.lobbyVehicleIns)
    if ins and R.insToRes[ins] then
        PERSIST.lobbyVehicleResID = R.insToRes[ins]
        F.persistMarkDirty()
    end
end

function F.hasExplicitLobbyVehicle()
    local res = tonumber(PERSIST.lobbyVehicleResID)
    local st = tonumber(PERSIST.lobbyVehicleSubType)
    if F.isChassisLightId(res) or st == CHASSIS_LIGHT_SUB then return false end
    if res and res > 0 and not F.isVehicleRes(res) then return false end
    if res and res > 0 then return true end
    if (tonumber(PERSIST.lobbyVehicleIns) or 0) > 0 then return true end
    local L = _G.AddOutfitLobbyVeh
    if L and L.manual and ((tonumber(L.resID) or 0) > 0 or (tonumber(L.insID) or 0) > 0) then return true end
    return false
end

function F.shouldApplyLobbyFromConfig(silent)
    if not F.hasExplicitLobbyVehicle() then return false end
    local _, lobbyIns = F.resolveLobbyVehicle(PERSIST.configVehicleSlots)
    if not lobbyIns then return false end
    local cur = tonumber(DataMgr.vst_skin)
    if cur == lobbyIns then return false end
    return true
end

function F.reapplyVehicleSlotsFromConfig(silent)
    local slotMap = PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    if not F.applyVehicleSlotsFromConfigMap(slotMap) then return false end
    F.syncVehicleSlotsToDataMgr()
    F.notifyVehicleSlotUI()
    F.equipVehicleTypesFromConfig(slotMap)
    if F.shouldApplyLobbyFromConfig(silent) then
        local lobbyRes, lobbyIns = F.resolveLobbyVehicle(slotMap)
        if lobbyIns then
            F.applyLobbyVehicleDisplay(lobbyRes, lobbyIns, not silent)
        elseif not silent then
            pcall(F.applyVehicleSkinsToPC)
            F.perfInvalidateLobby()
        end
    end
    return true
end

function F.applyHallThemeDisplay(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not resID then return false end
    if not F.isInjectedIns(insID) then return false end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    _G.AddOutfitApplyingTheme = true
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        HT.ProcPutOnHallTheme({ res_id = resID, instid = insID }, nil)
    end)
    _G.AddOutfitApplyingTheme = false
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    return true
end

function F.setHallThemeManual(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not F.isInjectedIns(insID) then return end
    if not resID then resID = R.insToRes[insID] end
    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
    _G.AddOutfitLobbyTheme.manual = true
    _G.AddOutfitLobbyTheme.resID = resID
    _G.AddOutfitLobbyTheme.insID = insID
    PERSIST.hallThemeResID = resID
    PERSIST.hallThemeIns = insID
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    F.persistMarkDirty()
end

function F.resolveHallTheme()
    local L = _G.AddOutfitLobbyTheme or {}
    local res = tonumber(PERSIST.hallThemeResID) or tonumber(L.resID)
    if res and R.resToIns[res] then return res, R.resToIns[res] end
    local ins = tonumber(PERSIST.hallThemeIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then return R.insToRes[ins], ins end
    return nil, nil
end

function F.shouldApplyHallThemeFromConfig(silent)
    local _, ins = F.resolveHallTheme()
    if not ins then return false end
    local cur = nil
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        cur = tonumber(HT.GetThemeInstId())
    end)
    if cur == ins then return false end
    if _G.AddOutfitLobbyTheme and _G.AddOutfitLobbyTheme.manual then return true end
    if silent and cur and cur > 0 and F.isInjectedIns(cur) then return false end
    return true
end

function F.putOnHallTheme(insID)
    insID = tonumber(insID)
    if not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if F.applyHallThemeDisplay(resID, insID) then
        F.setHallThemeManual(resID, insID)
        return true
    end
    return false
end

function F.reapplyHallThemeFromConfig(silent)
    if not F.shouldApplyHallThemeFromConfig(silent) then return false end
    local res, ins = F.resolveHallTheme()
    if not res or not ins then return false end
    return F.applyHallThemeDisplay(res, ins)
end

function F.syncVehicleCacheFromDataMgr()
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, insID in pairs(slots) do
                idx, insID = tonumber(idx), tonumber(insID)
                if idx and insID and insID > 0 then
                    local res = R.insToRes[insID]
                    if not res then
                        pcall(function()
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            res = d and tonumber(d.resID)
                        end)
                    end
                    if res and res > 0 then
                        cch.vehicleSlots[subType][idx] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end
end

function F.vehicleSubType(resID)
    local c = F.cfg(resID)
    return c and (c.ItemSubType or c.itemSubType)
end

function F.modifyInjectedVehicleSlot(insID, slotIndex, equip)
    insID = tonumber(insID)
    slotIndex = tonumber(slotIndex)
    if not insID or not slotIndex then return false end
    local resID = R.insToRes[insID]
    if not resID and insID >= INS_BASE then
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            resID = d and tonumber(d.resID or d.res_id)
        end)
    end
    if not resID then return false end
    local st = F.vehicleSubType(resID)
    if not st or tonumber(st) < 900 then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    cch.vehicleSlots[st] = cch.vehicleSlots[st] or {}
    if equip then
        for _, slots in pairs(cch.vehicleSlots) do
            for i, e in pairs(slots) do
                if e and tonumber(e.insID) == insID then slots[i] = nil end
            end
        end
        cch.vehicleSlots[st][slotIndex] = { resID = resID, insID = insID }
        PERSIST.configVehicleSlots = PERSIST.configVehicleSlots or {}
        PERSIST.configVehicleSlots[st] = PERSIST.configVehicleSlots[st] or {}
        PERSIST.configVehicleSlots[st][slotIndex] = resID
    else
        local e = cch.vehicleSlots[st][slotIndex]
        if e and tonumber(e.insID) == insID then
            cch.vehicleSlots[st][slotIndex] = nil
            if PERSIST.configVehicleSlots and PERSIST.configVehicleSlots[st] then
                PERSIST.configVehicleSlots[st][slotIndex] = nil
            end
        end
    end
    F.syncVehicleSlotsToDataMgr()
    if equip and slotIndex == 1 then
        DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
        DataMgr.vehicleSkinInsIDTable[st] = insID
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    F.persistMarkDirty()
    F.notifyVehicleSlotUI()
    return true
end

function F.buildVstInBattleFromSlots()
    local vst = {}
    local function insToRes(insID)
        insID = tonumber(insID)
        if not insID or insID <= 0 then return nil end
        local res = R.insToRes[insID]
        if res and res > 0 then return res end
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            res = d and tonumber(d.resID)
        end)
        if res and res > 0 then return res end
        if insID >= 1000000 and F.cfg(insID) then return insID end
        return nil
    end
    local function fillFromSlots(subType, slots)
        subType = tonumber(subType)
        if not subType or type(slots) ~= "table" then return end
        local resList = {}
        for idx = 1, 8 do
            local val = slots[idx] or slots[tostring(idx)]
            local res = insToRes(val)
            if not res and type(val) == "table" then
                res = tonumber(val.resID or val.res_id)
            end
            if res and res > 0 then resList[#resList + 1] = res end
        end
        if #resList > 0 then vst[subType] = resList end
    end
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        fillFromSlots(subType, slots)
    end
    if not next(vst) then
        local cch = F.cache()
        for subType, slots in pairs(cch.vehicleSlots or {}) do
            local resList = {}
            for idx = 1, 8 do
                local e = slots[idx]
                local res = e and tonumber(e.resID)
                if res and res > 0 then resList[#resList + 1] = res end
            end
            if #resList > 0 then vst[tonumber(subType)] = resList end
        end
    end
    if not next(vst) then
        local bySub = {}
        for res, _ in pairs(R.resToIns) do
            res = tonumber(res)
            local c = F.cfg(res)
            local st = c and tonumber(F.subType(c))
            if res and st and st >= 900 then
                bySub[st] = bySub[st] or {}
                bySub[st][#bySub[st] + 1] = res
            end
        end
        for st, list in pairs(bySub) do
            table.sort(list)
            vst[st] = list
        end
    end
    return vst
end

function F.isVehicleSkinAllowed(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if F.isInjectedRes(skinId) then return true end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do
            if tonumber(res) == skinId then return true end
        end
    end
    if R.resToIns[skinId] then
        local c = F.cfg(skinId)
        local st = F.subType(c)
        if st and tonumber(st) >= 900 then return true end
    end
    return false
end

function F.isSkinInVehiclePCList(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    local pc = F.getPC()
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return false end
    local UAvatarUtils = import("AvatarUtils")
    local shape = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
    if shape and shape >= 0 then
        local entry = pc.VehicleAvatarSkinList:Get(shape)
        if entry and entry.SkinList then
            for _, id in pairs(entry.SkinList) do
                if tonumber(id) == skinId then return true end
            end
        end
    end
    return false
end

function F.shouldHandleVehicleSkinClick(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    return F.isVehicleSkinAllowed(resID) or F.isSkinInVehiclePCList(resID)
end

function F.getMatchVehicle()
    local found = nil
    pcall(function()
        local subs = SubsystemMgr:Get("VehicleControlUISubSystem")
        if subs and subs.GetVehicleUserComponent then
            local uuc = subs:GetVehicleUserComponent()
            if slua.isValid(uuc) and slua.isValid(uuc.Vehicle) then found = uuc.Vehicle end
        end
    end)
    if slua.isValid(found) then return found end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.GetPlayerCharacterSafety then
        local char = pc:GetPlayerCharacterSafety()
        if slua.isValid(char) then
            if char.GetCurrentVehicle then
                local v = char:GetCurrentVehicle()
                if slua.isValid(v) then return v end
            end
            if char.CurrentVehicle and slua.isValid(char.CurrentVehicle) then
                return char.CurrentVehicle
            end
        end
    end
    return nil
end

function F.applyClientVehicleSkin(skinId, vehicle, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    vehicle = vehicle or F.getMatchVehicle()
    if not slua.isValid(vehicle) then return false end

    local UAvatarUtils = import("AvatarUtils")
    pcall(function()
        if slua.isValid(pc) then
            pc.ShowVehicleSkin = skinId
            local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
            if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
                pc.VehicleAvatarList:Add(shapeType, skinId)
            end
        end
    end)

    local applied = false
    local av = nil
    pcall(function()
        if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end
        if not slua.isValid(av) then av = vehicle.VehicleAvatarComponent_BP end
    end)

    if slua.isValid(av) then
        pcall(function() if av.bIsLobbyAvatar ~= nil then av.bIsLobbyAvatar = false end end)
        pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
        pcall(function()
            if slua.isValid(pc) and av.SetVehicleNetAvatarData then
                av:SetVehicleNetAvatarData(pc)
            end
        end)
        pcall(function()
            if av.ChangeItemAvatar then
                av:ChangeItemAvatar(skinId, false)
                applied = true
            elseif av.PreChangeVehicleAvatar then
                av:PreChangeVehicleAvatar(skinId)
                applied = true
            end
        end)
        pcall(function()
            if av.PostChangeItemAvatar then av:PostChangeItemAvatar(false) end
        end)
    end

    pcall(function()
        local battleCls = import("VehicleAvatarComponentBattleBase")
        local battleAv = vehicle:GetComponentByClass(battleCls)
        if slua.isValid(battleAv) then
            if battleAv.ChangeVehicleAvatar then
                battleAv:ChangeVehicleAvatar(skinId, false)
                applied = true
            end
            pcall(function()
                local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
                local uid = pc and pc.PlayerUID or 0
                local bTire = VehiclePlateLicenseUtil.NeedOpenHighTire(tonumber(uid), skinId)
                if battleAv.PreChangeHighTireLight then
                    battleAv:PreChangeHighTireLight(skinId, bTire)
                end
            end)
        end
    end)

    pcall(function()
        if vehicle.ChangeVehicleAvatar and slua.isValid(pc) then
            vehicle:ChangeVehicleAvatar(pc)
            applied = true
        end
    end)

    pcall(function() if vehicle.ForceNetUpdate then vehicle:ForceNetUpdate() end end)
    pcall(function() if slua.isValid(pc) and pc.ForceNetUpdate then pc:ForceNetUpdate() end end)
    return applied
end

function F.getVehicleSkinIds()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then
            seen[res] = true
            out[#out + 1] = res
        end
    end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do add(res) end
    end
    for res in pairs(R.resToIns) do
        local c = F.cfg(tonumber(res))
        local st = c and tonumber(F.subType(c))
        if st and st >= 900 then add(res) end
    end
    return out
end

function F.buildVehVst(skinIds)
    local bySub = {}
    for _, skinId in ipairs(skinIds or {}) do
        local subType = 961
        local ok, c = pcall(function() return CDataTable.GetTableData("Item", skinId) end)
        if ok and c and c.ItemSubType then subType = c.ItemSubType end
        bySub[subType] = bySub[subType] or {}
        bySub[subType][#bySub[subType] + 1] = skinId
    end
    return bySub
end

function F.directInjectVehicleSkinList(pc, skinIds)
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return end
    local UAvatarUtils = import("AvatarUtils")
    for _, skinId in ipairs(skinIds or {}) do
        local shapeType = nil
        pcall(function() shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId) end)
        if shapeType and shapeType >= 0 then
            pcall(function() pc.VehicleAvatarList:Add(shapeType, skinId) end)
            local entry = pc.VehicleAvatarSkinList:Get(shapeType)
            if entry and entry.SkinList then
                pcall(function() entry.SkinList:Add(skinId) end)
            end
        end
    end
end

function F.mergeVstIntoPlayerInfo(playerInfo)
    if not playerInfo then return end
    F.syncVehicleCacheFromDataMgr()
    local vst = F.buildVehVst(F.getVehicleSkinIds())
    if not next(vst) then return end
    playerInfo.vst_in_battle = playerInfo.vst_in_battle or {}
    for subType, list in pairs(vst) do
        playerInfo.vst_in_battle[subType] = list
    end
    local first
    for _, list in pairs(vst) do first = list[1]; break end
    if first and first > 0 then playerInfo.vst_skin = first end
end

function F.applyVehicleSkinsToPC(pc)
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end
    local skinIds = F.getVehicleSkinIds()
    if #skinIds == 0 then return false end
    local vst = F.buildVehVst(skinIds)
    local avatarList, avatarSkinList = {}, {}
    for _, skinList in pairs(vst) do
        local itemArray = {}
        for _, resid in ipairs(skinList) do
            if resid and resid > 0 then
                itemArray[#itemArray + 1] = { ItemTableID = resid, Count = 1 }
                avatarList[#avatarList + 1] = { ItemTableID = resid, Count = 1 }
            end
        end
        if #itemArray > 0 then
            avatarSkinList[#avatarSkinList + 1] = { Items = itemArray }
        end
    end
    pcall(function() pc.bEnableFuzzyAvatarOnClient = false end)
    pcall(function() pc.ShowVehicleSkin = skinIds[1] end)
    if #avatarList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarList = avatarList
            pc:InitVehicleAvatarList()
        end)
    end
    if #avatarSkinList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarSkinList = avatarSkinList
            pc:InitVehicleAvatarSkinList()
        end)
    end
    F.directInjectVehicleSkinList(pc, skinIds)
    return true
end

function F.serverChangeVehicleAvatar(skinId, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end

    F.applyVehicleSkinsToPC(pc)

    pcall(function()
        pc.ShowVehicleSkin = skinId
        local UAvatarUtils = import("AvatarUtils")
        local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
        if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
            pc.VehicleAvatarList:Add(shapeType, skinId)
        end
        F.directInjectVehicleSkinList(pc, { skinId })
    end)

    local ok = false
    pcall(function()
        if pc.ServerChangeVehicleAvatar then
            pc:ServerChangeVehicleAvatar(skinId)
            ok = true
        end
    end)

    pcall(function()
        if pc.PlayerState and slua.isValid(pc.PlayerState) then
            pc.PlayerState.nVst_skin = skinId
        end
    end)

    pcall(function() pc:ForceNetUpdate() end)
    return ok
end

_G.AddOutfitVehSel = _G.AddOutfitVehSel or { override = nil, overrideVehicle = nil, byShape = {} }
local VEHSEL = _G.AddOutfitVehSel
_G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or { manual = false, subType = nil, resID = nil, insID = nil }
local _vehTickLastApply = 0
local VEH_SWITCH_EFFECT_ID = 7303001

function F.prepVehicleSwitchEffect(av, vehicle)
    if not slua.isValid(av) then return end
    if not F.isInRealMatch() then
        pcall(function() av.curSwitchEffectId = 0 end)
        return
    end
    pcall(function()
        av.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
        local defaultId = 0
        pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
        local curId = 0
        if slua.isValid(vehicle) then
            pcall(function() curId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
            if curId <= 0 then
                pcall(function() curId = tonumber(vehicle.ClientUsedAvatarID) or 0 end)
            end
        end
        if curId <= 0 then curId = defaultId end
        if not av.lastEquipedAvatarId or av.lastEquipedAvatarId <= 0 then
            av.lastEquipedAvatarId = curId > 0 and curId or defaultId
        end
    end)
end

function F.isParachuteRes(resID)
    return F.subType(F.cfg(tonumber(resID))) == PARACHUTE_SUB
end

function F.isGlideRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    if GLIDER_SUBS[st] then return true end
    local ok, r = pcall(function()
        local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
        if MDH.IsGlideByItemID and MDH.IsGlideByItemID(resID) then return true end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        return wd.IsGlideType(st)
    end)
    return ok and r == true
end

function F.isVehicleRes(resID)
    resID = tonumber(resID)
    if not resID or F.isChassisLightId(resID) then return false end
    local st = tonumber(F.subType(F.cfg(resID)))
    return st and st >= 900 and st < 7000 and st ~= CHASSIS_LIGHT_SUB
end

function F.ensureInjectedItemAlive(entity, resID, insID)
    entity = entity or F.getEntity()
    insID = tonumber(insID) or (resID and R.resToIns[tonumber(resID)])
    resID = tonumber(resID) or (insID and R.insToRes[insID])
    if not entity or not insID then return end
    pcall(function()
        local d = entity:GetDataByInsID(insID)
        if d then
            d.expire_ts = 0
            d.expireTS = 0
            d.valid_hours = 0
        end
    end)
end

function F.sanitizeAllInjectedExpire()
    local entity = F.getEntity()
    if not entity then return end
    for res, ins in pairs(R.resToIns) do
        F.ensureInjectedItemAlive(entity, res, ins)
    end
end

function F.putOnVehicle(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local resID = R.insToRes[insID]
    if not resID or not F.isVehicleRes(resID) then return false end
    F.ensureInjectedItemAlive(nil, resID, insID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local item = {
        res_id = resID, resID = resID,
        instid = insID, ins_id = insID, insID = insID,
        expire_ts = 0, expireTS = 0, count = 1,
    }
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    F.setLobbyVehicleManual(F.vehicleSubType(resID), resID, insID)
    pcall(function()
        local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
        TabSurveillance.VehicleChange()
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
        end
    end)
    return true
end

function F.isChassisLightId(id)
    return CHASSIS_LIGHT_IDS[tonumber(id)] == true
end

function F.getDesiredChassisLight(vehicleSkinId)
    vehicleSkinId = tonumber(vehicleSkinId)
    local map = PERSIST.configChassisLightMap
    if vehicleSkinId and map and map[vehicleSkinId] then
        local v = tonumber(map[vehicleSkinId])
        if F.isChassisLightId(v) then return v end
    end
    local def = tonumber(PERSIST.configChassisLight) or DEFAULT_CHASSIS_LIGHT
    return F.isChassisLightId(def) and def or DEFAULT_CHASSIS_LIGHT
end

function F.saveChassisLight(vehicleSkinId, lightId)
    vehicleSkinId = tonumber(vehicleSkinId)
    lightId = tonumber(lightId)
    if not F.isChassisLightId(lightId) then return end
    PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
    if vehicleSkinId and vehicleSkinId > 0 then
        PERSIST.configChassisLightMap[vehicleSkinId] = lightId
    else
        PERSIST.configChassisLight = lightId
    end
    F.requestResourceDownload(lightId)
    F.persistMarkDirty()
end

function F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local lic = nil
    pcall(function()
        if vehicle.GetLicenseComponent then lic = vehicle:GetLicenseComponent() end
    end)
    if slua.isValid(lic) then return lic end
    pcall(function() lic = vehicle.BP_Lobby_VehicleLicenseComponent end)
    if slua.isValid(lic) then return lic end
    pcall(function()
        local cls = import("VehicleLicenseNumberComponent")
        lic = vehicle:GetComponentByClass(cls)
    end)
    return slua.isValid(lic) and lic or nil
end

function F.applyVehicleChassisLight(vehicle, skinId, lightId)
    -- [FIX VIP] If Mod Skin is disabled then skip loading underglow lights
    if not RAPZHANG_MOD_SKIN_ALWAYS_ON then return false end 
    
    skinId = tonumber(skinId)
    lightId = tonumber(lightId) or F.getDesiredChassisLight(skinId)
    if not F.isChassisLightId(lightId) then return false end
    if not slua.isValid(vehicle) then return false end
    if skinId and skinId > 0 then
        F.requestResourceDownload(skinId)
    end
    F.requestResourceDownload(lightId)
    local applied = false
    pcall(function()
        if vehicle.SetChassisLightShowData then
            vehicle:SetChassisLightShowData(lightId)
            applied = true
        end
    end)
    local lic = F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(lic) then return applied end
    pcall(function()
        local vid = skinId
        if not vid or vid <= 0 then
            pcall(function()
                if vehicle.GetAvatarId then vid = tonumber(vehicle:GetAvatarId()) end
            end)
        end
        if not vid or vid <= 0 then
            pcall(function() vid = tonumber(lic.LicensePlate and lic.LicensePlate.ItemID) end)
        end
        if vid and vid > 0 then
            lic.curVehicleAvatarId = vid
            if lic.ChangeNetData_ItemID then
                lic:ChangeNetData_ItemID(vid)
            elseif lic.LicensePlate then
                lic.LicensePlate.ItemID = vid
            end
        end
        if lic.LicensePlate then
            lic.LicensePlate.ChassisLightId = lightId
        end
        if lic.SetChassisLightData and vid and vid > 0 then
            lic:SetChassisLightData(vid, lightId)
        elseif lic.PreChangeChassisLight then
            lic:PreChangeChassisLight()
        end
        applied = true
    end)
    return applied
end

function F.scheduleChassisLightApply(vehicle, skinId)
    skinId = tonumber(skinId)
    local vref = slua.isValid(vehicle) and vehicle or nil
    local function try()
        local v = slua.isValid(vref) and vref or F.getCurrentVehicleForSkin()
        if slua.isValid(v) then
            F.applyVehicleChassisLight(v, skinId)
        end
    end
    F.later(0.4, try)
    F.later(1.1, try)
end

function F.getVehicleShape(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local shape = vehicle.VehicleShapeType
    if shape and tonumber(shape) >= 0 then return tonumber(shape) end
    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local defId = vehicle.AvatarDefaultCfg and vehicle.AvatarDefaultCfg.TypeSpecificID
        if defId and tonumber(defId) > 0 then
            shape = UAvatarUtils.GetVehicleShapeBySkinID(tonumber(defId))
        end
    end)
    return shape and tonumber(shape) >= 0 and tonumber(shape) or nil
end

function F.getDesiredVehicleSkinForShape(shape)
    shape = tonumber(shape)
    if not shape or shape < 0 then return nil end
    F.syncVehicleCacheFromDataMgr()
    local UAvatarUtils = import("AvatarUtils")
    local vst = F.buildVstInBattleFromSlots()
    for _, list in pairs(vst) do
        local skin = list and tonumber(list[1])
        if skin and skin > 0 then
            local s = UAvatarUtils.GetVehicleShapeBySkinID(skin)
            if s == shape then return skin end
        end
    end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.VehicleAvatarList then
        local skin = tonumber(pc.VehicleAvatarList:Get(shape))
        if skin and skin > 0 then return skin end
    end
    return nil
end

function F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local av = nil
    pcall(function() av = vehicle.VehicleAvatar end)
    if slua.isValid(av) then return av end
    pcall(function() if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end end)
    if slua.isValid(av) then return av end
    pcall(function() av = vehicle.VehicleAvatarComponent_BP end)
    if slua.isValid(av) then return av end
    return nil
end

function F.getCurrentVehicleForSkin()
    local char = F.getLocalChar()
    if char and slua.isValid(char) then
        local v = nil
        pcall(function() v = char.CurrentVehicle end)
        if slua.isValid(v) then return v end
    end
    return F.getMatchVehicle()
end

function F.forceVehicleAvatar(skinId, vehicle)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if not F.isResourcesReady(skinId) then
        F.requestResourceDownload(skinId)
        return false
    end
    vehicle = slua.isValid(vehicle) and vehicle or F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return false end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return false end
    local applied = false
    F.prepVehicleSwitchEffect(av, vehicle)
    pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
    pcall(function()
        av:ChangeItemAvatar(skinId, true)
        applied = true
        _G.CurrentEquipVehicleID = skinId
    end)
    if applied then F.scheduleChassisLightApply(vehicle, skinId) end
    return applied
end

function F.vehicleAvatarTemper()
    local vehicle = F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return end

    local defaultId = 0
    pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
    if defaultId <= 0 then return end

    local shape = nil
    pcall(function() shape = tonumber(import("AvatarUtils").GetVehicleShapeBySkinID(defaultId)) end)

    local skinId = nil
    if VEHSEL.override and slua.isValid(VEHSEL.overrideVehicle) and VEHSEL.overrideVehicle == vehicle then
        skinId = VEHSEL.override
    end
    if not skinId and shape then skinId = VEHSEL.byShape[shape] end
    if not skinId then skinId = F.getDesiredVehicleSkinForShape(shape) end
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 or skinId == defaultId then return end

    local cur = 0
    pcall(function() cur = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
    if cur <= 0 then
        pcall(function() cur = tonumber(vehicle.GetVehicleSkinItemID and vehicle:GetVehicleSkinItemID()) or 0 end)
    end
    if cur == skinId then return end

    F.forceVehicleAvatar(skinId, vehicle)
end

function F.vehicleSkinTick()
    -- Retry only while a vehicle is active. vehicleAvatarTemper exits without
    -- doing avatar work when the selected skin is already applied.
    if not RAPZHANG_VEHICLE_SKIN_ALWAYS_ON then return false end
    local vehicle = F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return false end
    pcall(F.vehicleAvatarTemper)
    return true
end

function F.startVehicleSkinTicker()
    if not RAPZHANG_VEHICLE_SKIN_ALWAYS_ON or _G.AddOutfitVehTickerStarted then return end
    local ok = pcall(function()
        local ticker = _ticker or require("common.time_ticker")
        if not ticker or not ticker.AddTimerLoop then return end
        ticker.AddTimerLoop(0, function()
            pcall(F.vehicleSkinTick)
        end, -1, 0.75)
        _G.AddOutfitVehTickerDisabled = nil
        _G.AddOutfitVehTickerStarted = true
    end)
    if not ok then _G.AddOutfitVehTickerStarted = nil end
end

function F.matchApplyVehicleSkin(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end

    local vehicle = F.getCurrentVehicleForSkin()

    VEHSEL.override = skinId
    VEHSEL.overrideVehicle = slua.isValid(vehicle) and vehicle or nil

    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local shape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(skinId))
        if shape and shape >= 0 then VEHSEL.byShape[shape] = skinId end
        local av = F.getVehicleAvatarComp(vehicle)
        if slua.isValid(av) then
            local defaultId = tonumber(av:GetDefaultAvatarID()) or 0
            if defaultId > 0 then
                local defShape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(defaultId))
                if defShape and defShape >= 0 then VEHSEL.byShape[defShape] = skinId end
            end
        end
    end)

    F.applyVehicleSkinsToPC(F.getPC())
    local ok = F.forceVehicleAvatar(skinId, vehicle)
    F.startVehicleSkinTicker()
    return ok
end

function F.autoApplyVehicleSkinOnEnter(vehicle)
    if not slua.isValid(vehicle) then return end
    F.syncVehicleCacheFromDataMgr()
    F.applyVehicleSkinsToPC(F.getPC())
    F.startVehicleSkinTicker()
    F.later(0.35, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.9, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.5, function()
        local skinId = nil
        pcall(function() skinId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) end)
        F.scheduleChassisLightApply(vehicle, skinId)
    end)
end

local function GetOutfitConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
    end)
    return paths
end

local CONFIG_PATHS = GetOutfitConfigPaths("rapzhang_outfit.json")

local PERSIST_SLOTS = {
    { "outfit", "outfitRes", "outfitIns", "AddOutfitLastLobbyOutfitRes" },
    { "tshirt", "tshirtRes", "tshirtIns", "AddOutfitLastLobbyTshirtRes" },
    { "pants",  "pantsRes",  "pantsIns",  "AddOutfitLastLobbyPantsRes"  },
    { "shoes",  "shoesRes",  "shoesIns",  "AddOutfitLastLobbyShoesRes"  },
    { "hat",    "hatRes",    "hatIns",    "AddOutfitLastLobbyHatRes"    },
    { "mask",   "maskRes",   "maskIns",   "AddOutfitLastLobbyMaskRes"   },
    { "glass",  "glassRes",  "glassIns",  "AddOutfitLastLobbyGlassRes"  },
    { "bag",    "bagRes",    "bagIns",    "AddOutfitLastLobbyBagRes"    },
    { "helmet", "helmetRes", "helmetIns", "AddOutfitLastLobbyHelmetRes" },
    { "parachute", "parachuteRes", "parachuteIns", "AddOutfitLastLobbyParachuteRes" },
    { "glider", "gliderRes", "gliderIns", "AddOutfitLastLobbyGliderRes" },
    { "gloves", "glovesRes", "glovesIns", "AddOutfitLastLobbyGlovesRes" },
}

function F.isPersistableWearRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if F.isInjectedRes(resID) then return true end
    if F.isParachuteRes(resID) or F.isGlideRes(resID) then return true end
    if PERSIST.configSlots then
        for _, v in pairs(PERSIST.configSlots) do
            if tonumber(v) == resID then return true end
        end
    end
    return false
end

function F.persistRememberSlot(slotName, resID)
    slotName = slotName and tostring(slotName)
    resID = tonumber(resID)
    if not slotName or not resID or resID <= 0 then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    PERSIST.configSlots[slotName] = resID
end

function F.persistForgetSlot(slotName)
    if PERSIST.configSlots and slotName then
        PERSIST.configSlots[tostring(slotName)] = nil
    end
end

function F.persistLoadSlotsFromSaved(saved)
    if type(saved) ~= "table" then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]])
        if res and res > 0 then PERSIST.configSlots[s[1]] = res end
    end
    F.applyPersistSlotsToCache()
end

function F.resolveInsForRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    if R.resToIns[resID] then return R.resToIns[resID] end
    local ins
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local list = wd.GetHallDepotItemListByResID and wd:GetHallDepotItemListByResID(resID)
        if list then
            for _, v in pairs(list) do
                local id = tonumber(v.insID or v.instid or v.ins_id)
                if id and id > 0 then ins = id break end
            end
        end
        if not ins then
            local d = wd.GetValidHallDepotItemDataByInsID and wd:GetValidHallDepotItemDataByInsID(resID)
            if not d and wd.GetHallDepotItemDataByResID then
                d = wd:GetHallDepotItemDataByResID(resID)
            end
            if d then ins = tonumber(d.insID or d.instid or d.ins_id) end
        end
    end)
    return ins
end

function F.applyPersistSlotsToCache()
    if not PERSIST.configSlots then return end
    local cch = F.cache()
    for _, s in ipairs(PERSIST_SLOTS) do
        local slotName, cacheResKey, cacheInsKey, globalKey = s[1], s[2], s[3], s[4]
        local res = tonumber(PERSIST.configSlots[slotName])
        if res and res > 0 then
            cch[cacheResKey] = res
            _G[globalKey] = res
            local ins = F.resolveInsForRes(res)
            if ins and ins > 0 then
                cch[cacheInsKey] = ins
                -- The saved JSON contains a resource ID, while the wardrobe
                -- appliers require an instance ID.  Rebuild both maps here;
                -- on a cold start the injected wardrobe may be populated only
                -- after the first pass through this function.
                R.resToIns[res] = ins
                R.insToRes[ins] = res
            end
        end
    end
end

function F.getDesiredGliderRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("gliderRes", "gliderRes", "AddOutfitLastLobbyGliderRes")
end

function F.getDesiredParachuteRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("parachuteRes", "parachuteRes", "AddOutfitLastLobbyParachuteRes")
end

function F.getAvatarComp2(char)
    if not char or not slua.isValid(char) then return nil end
    local comp
    pcall(function()
        if char.getAvatarComponent2 then
            comp = char:getAvatarComponent2()
        end
        if (not comp or not slua.isValid(comp)) and char.AvatarComponent2 then
            comp = char.AvatarComponent2
        end
        if (not comp or not slua.isValid(comp)) and char.CharacterAvatarComp2_BP then
            comp = char.CharacterAvatarComp2_BP
        end
    end)
    return comp
end

function F.isCharacterAirborne(char)
    if not char or not slua.isValid(char) then return false end
    local ok, r = pcall(function()
        local EParachuteState = import("EParachuteState")
        local st = char.ParachuteState
        return st and st ~= EParachuteState.PS_None
    end)
    return ok and r == true
end

function F.reapplyWeaponsFromConfig()
    local wmap = F.sanitizeConfigWeapons(PERSIST.configWeapons)
    local dropped = false
    for k in pairs(PERSIST.configWeapons or {}) do
        if not wmap[tonumber(k) or k] then dropped = true break end
    end
    PERSIST.configWeapons = wmap
    if dropped then F.persistMarkDirty() end
    if not next(wmap) then return false end
    local cch = F.cache()
    local any = false
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        local ins = res and R.resToIns[res]
        if wid and ins and F.isInjectedIns(ins) then
            MATCH_CONFIG.weaponSkins = MATCH_CONFIG.weaponSkins or {}
            MATCH_CONFIG.weaponSkins[wid] = res
            cch.weapons[wid] = { resID = res, insID = ins }
            if F.equipWeaponSkin(wid, ins) then
                any = true
            else
                F.syncWeaponArmorySilent(wid, ins)
            end
        end
    end
    return any
end

function F.persistEncode()
    local cch = F.cache()
    local parts = {}
    local weaponNames = {
        [101001]="AKM", [101002]="M16A4", [101003]="SCAR-L", [101004]="M416",
        [101005]="Groza", [101006]="AUG", [101007]="QBZ", [101008]="M762",
        [101009]="G36C", [101010]="Mk47", [101012]="Honey Badger", [101100]="FAMAS",
        [101101]="ACE32", [101102]="ASM Abakan", [102001]="UZI", [102002]="UMP45",
        [102003]="Vector", [102004]="Tommy Gun", [102005]="Bizon", [102007]="MP5K",
        [102008]="PP-19", [102105]="P90", [103001]="Kar98K", [103002]="M24",
        [103003]="AWM", [103004]="SKS", [103005]="VSS", [103006]="Mini14",
        [103007]="Mk14", [103008]="QBU", [103009]="SLR", [103010]="Win94",
        [103011]="Mosin-Nagant", [103012]="AMR", [103100]="Mk12", [103101]="QBU-Variant",
        [103102]="DSR", [103103]="M1 Garand", [104001]="S686", [104002]="S1897",
        [104003]="S12K", [104004]="DBS", [104101]="NS2000", [104102]="S1897-Variant",
        [105001]="M249", [105002]="DP-28", [105010]="MG3", [106001]="P92",
        [106002]="P1911", [106003]="R1895", [106004]="P18C", [106005]="Desert Eagle",
        [106006]="Scorpion", [107001]="Crossbow", [107007]="Tactical Crossbow",
        [107008]="MGL", [108]="Melee",
    }
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
            or tonumber(cch[s[2]])
        if res and res > 0 and F.isPersistableWearRes(res) then
            parts[#parts + 1] = string.format('  "%s": %d', s[1], res)
        end
    end
    local throwParts = {}
    local throwMap = {}
    for st, res in pairs(PERSIST.configThrowObjects or {}) do
        st, res = tonumber(st), tonumber(res)
        if st and THROW_SUBS[st] and res and res > 0 then throwMap[st] = res end
    end
    for st, record in pairs(cch.throwObjects or {}) do
        st = tonumber(st)
        local res = record and tonumber(record.resID)
        if st and THROW_SUBS[st] and res and res > 0 then throwMap[st] = res end
    end
    for st, res in pairs(throwMap) do
        throwParts[#throwParts + 1] = string.format('    "%d": %d', st, res)
    end
    table.sort(throwParts)
    parts[#parts + 1] = '  "throwObjects": {\n' .. table.concat(throwParts, ",\n") .. "\n  }"
    local wparts = {}
    local wmap = {}
    for wid, res in pairs(F.sanitizeConfigWeapons(PERSIST.configWeapons)) do
        wmap[wid] = res
    end
    for wid, w in pairs(cch.weapons or {}) do
        local res = w and tonumber(w.resID)
        wid = tonumber(wid)
        if F.isValidWeaponPersistEntry(wid, res) then wmap[wid] = res end
    end
    for wid, res in pairs(wmap) do
        local key = weaponNames[tonumber(wid)] or tostring(wid)
        wparts[#wparts + 1] = string.format('    "%s": %d', key, res)
    end
    table.sort(wparts)
    parts[#parts + 1] = '  "weapons": {\n' .. table.concat(wparts, ",\n") .. "\n  }"
    local mparts = {}
    -- Backfill the explicit melee section from the native weapon-108 entry.
    -- This covers older sessions/configs that only recorded `weapons[108]`.
    local cachedMeleeRes = tonumber(PERSIST.configMelee and PERSIST.configMelee.pan)
        or tonumber(PERSIST.configMelee and PERSIST.configMelee.dagger)
        or tonumber(PERSIST.configMelee and PERSIST.configMelee.machete)
        or tonumber(PERSIST.configWeapons and PERSIST.configWeapons[108])
    local cachedMeleeKind = F.meleeKindFromRes(cachedMeleeRes)
    if cachedMeleeKind and cachedMeleeRes and cachedMeleeRes > 0 then
        PERSIST.configMelee = PERSIST.configMelee or {}
        PERSIST.configMelee[cachedMeleeKind] = cachedMeleeRes
    end
    for _, mk in ipairs({ "pan", "dagger", "machete" }) do
        local mr = tonumber(PERSIST.configMelee and PERSIST.configMelee[mk])
        if mr and mr > 0 and F.isValidWeaponPersistEntry(108, mr) then
            mparts[#mparts + 1] = string.format('    "%s": %d', mk, mr)
        end
    end
    table.sort(mparts)
    parts[#parts + 1] = '  "melee": {\n' .. table.concat(mparts, ",\n") .. "\n  }"
    local vparts = {}
    local function appendVehicleSlots(src)
        for subType, slots in pairs(src or {}) do
            local sparts = {}
            if type(slots) == "table" then
                for idx, val in pairs(slots) do
                    local res = type(val) == "table" and tonumber(val.resID) or tonumber(val)
                    if res and res > 0 then
                        sparts[#sparts + 1] = string.format('      "%d": %d', tonumber(idx), res)
                    end
                end
            end
            table.sort(sparts)
            if #sparts > 0 then
                vparts[#vparts + 1] = string.format('    "%d": {\n%s\n    }', tonumber(subType), table.concat(sparts, ",\n"))
            end
        end
    end
    -- Merge both stores before encoding.  The runtime cache can contain
    -- slots learned from the game while the JSON can contain slots selected
    -- by the slider; writing only one source silently loses vehicle skins.
    local mergedVehicleSlots = {}
    local function mergeVehicleSlots(src)
        for subType, slots in pairs(src or {}) do
            local st = tonumber(subType)
            if st and type(slots) == "table" then
                mergedVehicleSlots[st] = mergedVehicleSlots[st] or {}
                for idx, value in pairs(slots) do
                    local nidx = tonumber(idx)
                    local res = type(value) == "table" and tonumber(value.resID or value.res_id) or tonumber(value)
                    if nidx and res and res > 0 then mergedVehicleSlots[st][nidx] = res end
                end
            end
        end
    end
    mergeVehicleSlots(PERSIST.configVehicleSlots)
    mergeVehicleSlots(cch.vehicleSlots)
    appendVehicleSlots(mergedVehicleSlots)
    table.sort(vparts)
    parts[#parts + 1] = '  "vehicleSlots": {\n' .. table.concat(vparts, ",\n") .. "\n  }"
    if PERSIST.lobbyVehicleSubType and PERSIST.lobbyVehicleSubType > 0
        and PERSIST.lobbyVehicleSubType ~= CHASSIS_LIGHT_SUB
        and not F.isChassisLightId(PERSIST.lobbyVehicleResID)
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleSubType": %d', PERSIST.lobbyVehicleSubType)
    end
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleResID": %d', PERSIST.lobbyVehicleResID)
    end
    if PERSIST.lobbyVehicleIns and PERSIST.lobbyVehicleIns > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID or R.insToRes[PERSIST.lobbyVehicleIns]) then
        parts[#parts + 1] = string.format('  "lobbyVehicleIns": %d', PERSIST.lobbyVehicleIns)
    end
    local hres = tonumber(cch.hallThemeRes) or tonumber(PERSIST.hallThemeResID)
    if hres and hres > 0 and F.isInjectedRes(hres) then
        parts[#parts + 1] = string.format('  "hallTheme": %d', hres)
    end
    local cl = tonumber(PERSIST.configChassisLight)
    if F.isChassisLightId(cl) then
        parts[#parts + 1] = string.format('  "chassisLight": %d', cl)
    end
    local cmap = PERSIST.configChassisLightMap
    if cmap and next(cmap) then
        local cparts = {}
        for vid, lid in pairs(cmap) do
            vid, lid = tonumber(vid), tonumber(lid)
            if vid and vid > 0 and F.isChassisLightId(lid) then
                cparts[#cparts + 1] = string.format('    "%d": %d', vid, lid)
            end
        end
        table.sort(cparts)
        if #cparts > 0 then
            parts[#parts + 1] = '  "chassisLightMap": {\n' .. table.concat(cparts, ",\n") .. "\n  }"
        end
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n}\n"
end

function F.persistWrite(txt)
    if not (io and io.open) then return false end
    if PERSIST.path then
        local f
        pcall(function() f = io.open(PERSIST.path, "w") end)
        if f then f:write(txt) f:close() return true end
        PERSIST.path = nil
    end
    for _, p in ipairs(CONFIG_PATHS) do
        local f
        pcall(function() f = io.open(p, "w") end)
        if not f then
            pcall(function()
                local dir = p:match("^(.*)/[^/]+$")
                if dir and os and os.execute then os.execute('mkdir -p "' .. dir .. '"') end
            end)
            pcall(function() f = io.open(p, "w") end)
        end
        if f then
            f:write(txt) f:close()
            PERSIST.path = p
            return true
        end
    end
    return false
end

function F.persistFlush()
    if not PERSIST.dirty then return end
    PERSIST.dirty = false
    pcall(function()
        local txt = F.persistEncode()
        if txt == PERSIST.lastWritten then return end
        if F.persistWrite(txt) then
            PERSIST.lastWritten = txt
        end
    end)
end

F.persistMarkDirty = function()
    PERSIST.dirty = true
    if PERSIST.scheduled then return end
    PERSIST.scheduled = true
    F.later(2.0, function()
        PERSIST.scheduled = false
        F.persistFlush()
    end)
end

function F.persistParse(txt)
    if not txt or #txt == 0 then return nil end
    local out = { weapons = {}, melee = {}, throwObjects = {}, vehicleSlots = {} }
    local weaponIdsByName = {
        ["AKM"]=101001, ["M16A4"]=101002, ["SCAR-L"]=101003, ["M416"]=101004,
        ["Groza"]=101005, ["AUG"]=101006, ["QBZ"]=101007, ["M762"]=101008,
        ["G36C"]=101009, ["Mk47"]=101010, ["Honey Badger"]=101012, ["FAMAS"]=101100,
        ["ACE32"]=101101, ["ASM Abakan"]=101102, ["UZI"]=102001, ["UMP45"]=102002,
        ["Vector"]=102003, ["Tommy Gun"]=102004, ["Bizon"]=102005, ["MP5K"]=102007,
        ["PP-19"]=102008, ["P90"]=102105, ["Kar98K"]=103001, ["M24"]=103002,
        ["AWM"]=103003, ["SKS"]=103004, ["VSS"]=103005, ["Mini14"]=103006,
        ["Mk14"]=103007, ["QBU"]=103008, ["QBU-Variant"]=103101, ["SLR"]=103009, ["Win94"]=103010,
        ["Mosin-Nagant"]=103011, ["AMR"]=103012, ["Mk12"]=103100, ["DSR"]=103102,
        ["M1 Garand"]=103103, ["S686"]=104001, ["S1897"]=104002, ["S12K"]=104003,
        ["DBS"]=104004, ["NS2000"]=104101, ["S1897-Variant"]=104102, ["M249"]=105001, ["DP-28"]=105002,
        ["MG3"]=105010, ["P92"]=106001, ["P1911"]=106002, ["R1895"]=106003,
        ["P18C"]=106004, ["Desert Eagle"]=106005, ["Scorpion"]=106006,
        ["Crossbow"]=107001, ["Tactical Crossbow"]=107007, ["MGL"]=107008,
        ["Melee"]=108, ["Pan"]=108, ["Dagger"]=108, ["Machete"]=108,
    }
    local function weaponID(key)
        local n = tonumber(key)
        if n then return n end
        return weaponIdsByName[tostring(key)]
    end
    local parsed = false
    pcall(function()
        local t = json and json.decode and json.decode(txt)
        if type(t) == "table" then
            for k, v in pairs(t) do
                if k == "weapons" and type(v) == "table" then
                    for wk, wv in pairs(v) do
                        local wid, res = weaponID(wk), tonumber(wv)
                        if F.isValidWeaponPersistEntry(wid, res) then out.weapons[wid] = res end
                    end
                elseif k == "throwObjects" and type(v) == "table" then
                    for stk, rv in pairs(v) do
                        local st, res = tonumber(stk), tonumber(rv)
                        if st and THROW_SUBS[st] and res and res > 0 then out.throwObjects[st] = res end
                    end
                elseif k == "melee" and type(v) == "table" then
                    for mk, mv in pairs(v) do
                        if (mk == "pan" or mk == "dagger" or mk == "machete") and tonumber(mv) and tonumber(mv) > 0 then
                            out.melee[mk] = tonumber(mv)
                        end
                    end
                elseif k == "vehicleSlots" and type(v) == "table" then
                    for stk, slotMap in pairs(v) do
                        local st = tonumber(stk)
                        if st then
                            out.vehicleSlots[st] = out.vehicleSlots[st] or {}
                            for idxStr, res in pairs(slotMap) do
                                local idx, r = tonumber(idxStr), tonumber(res)
                                if idx and r and r > 0 then out.vehicleSlots[st][idx] = r end
                            end
                        end
                    end
                elseif k == "chassisLightMap" and type(v) == "table" then
                    out.chassisLightMap = {}
                    for vk, lv in pairs(v) do
                        local vid, lid = tonumber(vk), tonumber(lv)
                        if vid and lid and F.isChassisLightId(lid) then
                            out.chassisLightMap[vid] = lid
                        end
                    end
                else
                    local n = tonumber(v)
                    if n and n > 0 then out[k] = n end
                end
            end
            parsed = true
        end
    end)
    if not parsed then
        local throwBlock = txt:match('"throwObjects"%s*:%s*{([^}]*)}')
        if throwBlock then
            for stKey, resValue in throwBlock:gmatch('"(%d+)"%s*:%s*(%d+)') do
                local st, res = tonumber(stKey), tonumber(resValue)
                if st and THROW_SUBS[st] and res and res > 0 then out.throwObjects[st] = res end
            end
        end
        for k, v in txt:gmatch('"([%w_]+)"%s*:%s*(%d+)') do
            local n = tonumber(v)
            if n and n > 0 then
                local wid = weaponID(k)
                if wid and F.isValidWeaponPersistEntry(wid, n) then
                    out.weapons[wid] = n
                elseif not wid then
                    out[k] = n
                end
            end
        end
    end
    return out
end

function F.persistLoadFromDisk()
    if not (io and io.open) then return end
    pcall(function()
        for _, p in ipairs(CONFIG_PATHS) do
            local f
            pcall(function() f = io.open(p, "r") end)
            if f then
                local txt = f:read("*a")
                f:close()
                PERSIST.path = p
                PERSIST.lastWritten = txt
                PERSIST.loaded = F.persistParse(txt)
                PERSIST.configThrowObjects = PERSIST.loaded and PERSIST.loaded.throwObjects or {}
                F.persistLoadSlotsFromSaved(PERSIST.loaded)
                if PERSIST.loaded and PERSIST.loaded.vehicleSlots then
                    PERSIST.configVehicleSlots = PERSIST.loaded.vehicleSlots
                end
                if PERSIST.loaded and PERSIST.loaded.melee then
                    PERSIST.configMelee = PERSIST.configMelee or {}
                    for _, mk in ipairs({ "pan", "dagger", "machete" }) do
                        local mr = tonumber(PERSIST.loaded.melee[mk])
                        if mr and mr > 0 then PERSIST.configMelee[mk] = mr end
                    end
                end
                if PERSIST.loaded and PERSIST.loaded.weapons then
                    local raw = PERSIST.loaded.weapons
                    PERSIST.weaponConfigLoaded = true
                    PERSIST.configWeapons = F.sanitizeConfigWeapons(raw)
                    if next(raw) and not next(PERSIST.configWeapons) then
                        F.persistMarkDirty()
                    elseif next(raw) then
                        for wid, res in pairs(raw) do
                            if not F.isValidWeaponPersistEntry(tonumber(wid), tonumber(res)) then
                                F.persistMarkDirty()
                                break
                            end
                        end
                    end
                end
                PERSIST.lobbyVehicleSubType = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleSubType)
                PERSIST.lobbyVehicleResID = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleResID)
                PERSIST.lobbyVehicleIns = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleIns)
                if PERSIST.lobbyVehicleSubType or PERSIST.lobbyVehicleIns or PERSIST.lobbyVehicleResID then
                    if F.isChassisLightId(PERSIST.lobbyVehicleResID)
                        or PERSIST.lobbyVehicleSubType == CHASSIS_LIGHT_SUB
                        or not F.isVehicleRes(PERSIST.lobbyVehicleResID) then
                        PERSIST.lobbyVehicleSubType = nil
                        PERSIST.lobbyVehicleResID = nil
                        PERSIST.lobbyVehicleIns = nil
                    else
                        _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
                        _G.AddOutfitLobbyVeh.manual = true
                        _G.AddOutfitLobbyVeh.subType = PERSIST.lobbyVehicleSubType
                        _G.AddOutfitLobbyVeh.resID = PERSIST.lobbyVehicleResID
                        _G.AddOutfitLobbyVeh.insID = PERSIST.lobbyVehicleIns
                    end
                end
                PERSIST.hallThemeResID = tonumber(PERSIST.loaded and PERSIST.loaded.hallTheme)
                PERSIST.hallThemeIns = nil
                if PERSIST.hallThemeResID then
                    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
                    _G.AddOutfitLobbyTheme.manual = true
                    _G.AddOutfitLobbyTheme.resID = PERSIST.hallThemeResID
                end
                PERSIST.configChassisLight = tonumber(PERSIST.loaded and PERSIST.loaded.chassisLight)
                if PERSIST.loaded and PERSIST.loaded.chassisLightMap then
                    PERSIST.configChassisLightMap = PERSIST.loaded.chassisLightMap
                end
                return
            end
        end
    end)
end

function F.persistApplyLoaded()
    local saved = PERSIST.loaded
    if not saved then return end
    PERSIST.loaded = nil
    local cch = F.cache()
    local any = false
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]]) or tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
        -- The JSON is the source of truth at startup. Do not keep an older
        -- in-memory slot when the saved outfit contains a newer selection.
        if res and res > 0 then
            -- Do not require the mapping to exist yet.  On first launch the
            -- depot/injected item list can finish loading after the JSON is
            -- parsed, so resolve it directly and cache the result.
            local ins = R.resToIns[res] or F.resolveInsForRes(res)
            if ins then
                R.resToIns[res] = ins
                R.insToRes[ins] = res
                cch[s[2]], cch[s[3]] = res, ins
                _G[s[4]] = res
                any = true
            end
        end
    end
    PERSIST.configMelee = PERSIST.configMelee or {}
    for _, mk in ipairs({ "pan", "dagger", "machete" }) do
        local mr = tonumber(saved.melee and saved.melee[mk])
        if mr and mr > 0 and F.isValidWeaponPersistEntry(108, mr) then
            PERSIST.configMelee[mk] = mr
        end
    end
    PERSIST.configWeapons = F.sanitizeConfigWeapons(saved.weapons or PERSIST.configWeapons)
    PERSIST.weaponConfigLoaded = type(saved.weapons) == "table" or PERSIST.weaponConfigLoaded == true
    local loadedThrowObjects = saved.throwObjects or PERSIST.configThrowObjects or {}
    PERSIST.configThrowObjects = {}
    cch.throwObjects = cch.throwObjects or {}
    for st, res in pairs(loadedThrowObjects) do
        st, res = tonumber(st), tonumber(res)
        if st and THROW_SUBS[st] and res and res > 0 then
            PERSIST.configThrowObjects[st] = res
            local ins = R.resToIns[res] or F.resolveInsForRes(res)
            if ins and ins > 0 then
                R.resToIns[res], R.insToRes[ins] = ins, res
            end
            cch.throwObjects[st] = { resID = res, insID = ins or 0 }
            F.requestResourceDownload(res)
            any = true
        end
    end
    -- Remove native/cache entries for weapon slots intentionally left empty.
    for wid in pairs(cch.weapons or {}) do
        if not PERSIST.configWeapons[tonumber(wid) or wid] then cch.weapons[wid] = nil end
    end
    -- Melee is represented by the native weapon slot 108.  Older JSON files
    -- may contain only the explicit `melee` object, so promote its selections
    -- into the weapon map before the single startup reapply pass.
    for _, mk in ipairs({ "pan", "dagger", "machete" }) do
        local mr = tonumber(PERSIST.configMelee[mk])
        if mr and mr > 0 and F.isValidWeaponPersistEntry(108, mr) then
            PERSIST.configWeapons[108] = mr
            cch.weapons[108] = { resID = mr, insID = R.resToIns[mr] }
            break
        end
    end
    if next(PERSIST.configWeapons) and F.reapplyWeaponsFromConfig() then
        any = true
    end
    if saved.vehicleSlots then
        PERSIST.configVehicleSlots = saved.vehicleSlots
        if F.reapplyVehicleSlotsFromConfig(true) then
            any = true
        end
    end
    if saved.hallTheme then
        PERSIST.hallThemeResID = tonumber(saved.hallTheme)
        if PERSIST.hallThemeResID and F.reapplyHallThemeFromConfig(true) then
            any = true
        end
    end
    if saved.chassisLight then
        PERSIST.configChassisLight = tonumber(saved.chassisLight)
    end
    if saved.chassisLightMap then
        PERSIST.configChassisLightMap = saved.chassisLightMap
    end
    if any then
        _matchApplied = false
        F.perfInvalidateLobby()
    end
end

function F.getEntity()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

function F.firstInsForRes(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if not arr then return nil end
    for _, idx in pairs(arr) do
        local d = entity._data[idx]
        if d and d.count and d.count > 0 then return d.insID end
    end
    return nil
end

function F.injectOne(entity, resID, insID)
    local ownedIns = F.firstInsForRes(entity, resID)
    if ownedIns then
        F.ensureInjectedItemAlive(entity, resID, ownedIns)
        R.resToIns[resID] = ownedIns
        R.insToRes[ownedIns] = resID
        F.indexWeaponSkin(resID, ownedIns)
        return true
    end
    -- Sudah pernah disuntik (mis. dipanggil ulang setelah modul reload).
    local maps = entity.InsIDToIndexMap
    if maps and maps[insID] ~= nil then
        R.insToRes[insID] = resID
        R.resToIns[resID] = insID
        F.indexWeaponSkin(resID, insID)
        return true
    end
    local ok, info = pcall(entity.AddData, entity, {
        instid = insID,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    })
    if not ok or type(info) ~= "table" then return false end

    pcall(function()
        if entity.LoadConfigForData and CDataTable and CDataTable.GetTableData then
            entity:LoadConfigForData(info, CDataTable.GetTableData)
        end
    end)

    -- Cadangan kalau config belum terbaca: isi field yang dibaca filter tab.
    if info.bConfigLoaded ~= true then
        local c = F.cfg(resID)
        local mainTab = tonumber(c and c.WardrobeMainTab)
        local subTab = tonumber(c and c.WardrobeTab)
        if mainTab and subTab then
            info.itemType = c.ItemType
            info.itemSubType = c.ItemSubType
            info.mainTabType = mainTab
            info.subTabType = subTab
            info.itemQuality = c.ItemQuality
            info.bConfigLoaded = true
        end
    end

    -- Entri tanpa config tidak akan pernah lolos filter grid. Batalkan supaya
    -- tidak menempati InsIDToIndexMap dan bisa dicoba lagi nanti.
    if info.bConfigLoaded ~= true then
        pcall(function() entity:RemoveData(insID) end)
        return false
    end

    R.insToRes[insID] = resID
    R.resToIns[resID] = insID
    F.indexWeaponSkin(resID, insID)
    return true
end

function F.reviveExpiredOwned(entity)
    entity = entity or F.getEntity()
    if not entity or not entity.bInit or not entity._data then return end
    local now = 0
    pcall(function()
        local TimeUtil = require("client.common.time_util")
        now = tonumber(TimeUtil.GetServerTimeInSec()) or 0
    end)
    if now <= 0 then return end
    _G.AddOutfitRevived = _G.AddOutfitRevived or {}
    local n = 0
    for i = 1, (entity._DataCount or #entity._data) do
        local d = entity._data[i]
        if d then
            local exp = tonumber(d.expire_ts or d.expireTS) or 0
            local res = tonumber(d.res_id or d.resID)
            local ins = tonumber(d.instid or d.insID)
            if exp > 0 and exp <= now and res and ins and (tonumber(d.count) or 0) > 0 then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
                _G.AddOutfitRevived[res] = ins
                n = n + 1
            end
        end
    end
end

function F.mergeRevivedIntoMaps()
    for res, ins in pairs(_G.AddOutfitRevived or {}) do
        if not R.resToIns[res] then
            R.resToIns[res] = ins
            R.insToRes[ins] = res
            F.indexWeaponSkin(res, ins)
        end
    end
end

function F.injectArmory(resID, insID, wid)
    wid = tonumber(wid) or tonumber(F.weaponIdFromSkin(resID))
    if not wid then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
    Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

function F.mergeInjectedArmorySkins()
    for _, skins in pairs(R.byWeapon) do
        for resID, insID in pairs(skins) do
            F.injectArmory(resID, insID)
        end
    end
end

-- Penanda injeksi per entity. `entity._data` diganti tabel baru setiap
-- InitData, jadi referensi ini otomatis mendeteksi depot yang di-reset.
local LAST_INJECT = setmetatable({}, { __mode = "k" })

local function isSyntheticIns(ins)
    ins = tonumber(ins)
    return ins ~= nil and ins >= INS_BASE and ins < INS_BASE + 2000000000
end

function F.rebuildInjectedMaps(entity)
    if not entity or type(entity._data) ~= "table" then return end
    local n = 0
    for _, d in pairs(entity._data) do
        if type(d) == "table" then
            local ins = tonumber(d.insID or d.instid)
            local res = tonumber(d.resID or d.res_id)
            if ins and res and isSyntheticIns(ins) then
                R.insToRes[ins] = res
                R.resToIns[res] = ins
                F.indexWeaponSkin(res, ins)
                n = n + 1
            end
        end
    end
    return n
end

function F.injectAll(entity)
    if not RAPZHANG_MOD_SKIN_ALWAYS_ON then return false end
    entity = entity or F.getEntity()
    if not entity or not entity.bInit then return false end

    local catalog = itemCatalog()
    if not catalog or #catalog == 0 then return false end

    local mark = LAST_INJECT[entity]
    if mark and mark.data == rawget(entity, "_data") then
        if not mark.mapsRebuilt then
            F.rebuildInjectedMaps(entity)
            mark.mapsRebuilt = true
        end
        return true
    end
    if F._injectBusy then return true end
    F._injectBusy = true

    local n, added = 0, 0
    local ok = pcall(function()
        local data = entity._data
        if type(data) ~= "table" then return end
        local insMap = entity.InsIDToIndexMap
        local resMap = entity.ResIDToIndexArrayMap
        if type(insMap) ~= "table" then insMap = {}; entity.InsIDToIndexMap = insMap end
        if type(resMap) ~= "table" then resMap = {}; entity.ResIDToIndexArrayMap = resMap end

        local meta = ITEM_CATALOG_META
        local count = tonumber(entity._DataCount) or 0
        local prevCount = count

        for i = 1, #catalog do
            local resID = catalog[i]
            local insID = INS_BASE + i
            local m = meta and meta[i]
            local existingIns = nil

            -- Item yang benar-benar dimiliki server tetap memakai insID asli
            -- supaya armory/equip server tidak rusak.
            local arr = resMap[resID]
            local reviveD
            if arr then
                for k = 1, #arr do
                    local d = data[arr[k]]
                    if d then
                        if (tonumber(d.count) or 0) > 0 then
                            existingIns = tonumber(d.insID or d.instid)
                            d.expire_ts, d.expireTS, d.valid_hours = 0, 0, 0
                            break
                        end
                        reviveD = reviveD or d
                    end
                end
            end
            -- Baris lama dengan count 0 (mis. habis/kedaluwarsa) dihidupkan
            -- kembali, bukan ditambah baris kedua. Kalau ditambah, lookup
            -- berdasarkan resID bisa mengembalikan baris count 0 lebih dulu.
            if not existingIns and reviveD then
                existingIns = tonumber(reviveD.insID or reviveD.instid)
                reviveD.count = 1
                reviveD.expire_ts, reviveD.expireTS, reviveD.valid_hours = 0, 0, 0
                if m then
                    reviveD.itemType = reviveD.itemType or m[1]
                    reviveD.itemSubType = reviveD.itemSubType or m[2]
                    reviveD.mainTabType = reviveD.mainTabType or m[3]
                    reviveD.subTabType = reviveD.subTabType or m[4]
                    reviveD.itemQuality = reviveD.itemQuality or m[5]
                    reviveD.bConfigLoaded = true
                end
            end

            local useIns
            if existingIns then
                useIns = existingIns
            else
                useIns = insID
                count = count + 1
                data[count] = {
                    insID = insID,
                    resID = resID,
                    count = 1,
                    lock_cnt = 0,
                    isNew = false,
                    validHours = 0,
                    expireTS = 0,
                    bConfigLoaded = true,
                    itemType = m and m[1] or nil,
                    itemSubType = m and m[2] or nil,
                    mainTabType = m and m[3] or nil,
                    subTabType = m and m[4] or nil,
                    itemQuality = m and m[5] or nil,
                }
                insMap[insID] = count
                if not arr then
                    arr = {}
                    resMap[resID] = arr
                end
                arr[#arr + 1] = count
                added = added + 1
            end

            R.insToRes[useIns] = resID
            R.resToIns[resID] = useIns
            n = n + 1

            if m and m[2] then
                F.indexWeaponSkinDirect(resID, useIns, m[2])
            end
        end

        entity._DataCount = count
        -- Semua entri sintetis sudah bConfigLoaded. Majukan penanda batch
        -- config supaya GetData berikutnya tidak memindai ribuan entri itu.
        if type(entity.loadConfigCurrentIndex) == "number"
            and entity.loadConfigCurrentIndex > prevCount then
            entity.loadConfigCurrentIndex = count + 1
        end
        if not _G.AddOutfitUnexpireDone then
            _G.AddOutfitUnexpireDone = true
            pcall(F.reviveExpiredOwned, entity)
        end
        F.mergeRevivedIntoMaps()
    end)

    F._injectBusy = false
    if not ok then return false end
    if n > 0 then
        -- mapsRebuilt = true: peta sudah diisi langsung di loop, tidak perlu
        -- scan ulang 16.000+ entri saat grid pertama kali dibuka.
        LAST_INJECT[entity] = { data = rawget(entity, "_data"), count = n, mapsRebuilt = true }
    end
    return n > 0, added
end

function F.refreshWardrobe()
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
            end
        end
    end)
end

function F.refreshWardrobeOnce()
    if LOBBY.wardrobeRefreshed then return end
    LOBBY.wardrobeRefreshed = true
    F.refreshWardrobe()
end

function F.scheduleInjectRefresh()
    LOBBY.injectRefreshGen = (LOBBY.injectRefreshGen or 0) + 1
    local gen = LOBBY.injectRefreshGen
    F.later(0.4, function()
        if gen ~= LOBBY.injectRefreshGen then return end
        F.refreshWardrobe()
    end)
end

function F.putOnOutfit(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    if not F.isSuitRes(resID) then
        if F.isTshirtRes(resID) then return F.putOnRoleWear(insID) end
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local suitFilter = function(r) return F.isSuitRes(r) end
    local oldIns, oldRes = F.findWornInsBySubType(OUTFIT_SUB, suitFilter)
    F.removeRoleWearBySubType(OUTFIT_SUB, suitFilter)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(OUTFIT_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(OUTFIT_SUB, insID, resID, 0, 0)
        F.syncFashionBagRolewear()
    end)
end

function F.putOnHat(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or HAT_SUB

    local oldIns, oldRes = F.findWornInsBySubType(st)
    if not oldIns and st ~= HAT_SUB then
        oldIns, oldRes = F.findWornInsBySubType(HAT_SUB)
    end
    F.removeRoleWearBySubType(st)
    if st ~= HAT_SUB then F.removeRoleWearBySubType(HAT_SUB) end
    F.saveEquip(resID, insID)

    local slot = 1
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SetHeadShow(insID)
        F.syncFashionBagRolewear()
    end)
    F.invalidateSocialWearCache()
end

function F.putOnFaceAccessory(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not FACE_SUBS[st] then return end

    local oldIns, oldRes = F.findWornInsBySubType(st)
    F.removeRoleWearBySubType(st)
    F.saveEquip(resID, insID)

    local slot = (st == MASK_SUB) and 2 or 6
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.canRoleWear(resID, st)
    st = st or F.subType(F.cfg(resID))
    if FACE_SUBS[st] or BODY_SUBS[st] then return true end
    if st == GLOVES_SUB then return true end
    if st == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES then return true end
    return false
end

F.putOnRoleWear = function(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not F.canRoleWear(resID, st) then return end

    local filterFn
    if st == OUTFIT_SUB then
        filterFn = function(r) return F.wardrobeTab(r) == TAB_CLOTHES end
    end
    local oldIns, oldRes = F.findWornInsBySubType(st, filterFn)
    F.removeRoleWearBySubType(st, filterFn)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
            DataMgr.equipmentSkinInsIDTable[st] = insID
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if st == 504 or st == 501 then
                    DataMgr.equipmentSkinInsIDTable[504] = insID
                    bag.bag_skin = insID
                elseif st == 505 or st == 502 then
                    DataMgr.equipmentSkinInsIDTable[505] = insID
                    bag.helmet_skin = insID
                end
            end
        end)
    end

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(F.scheduleEquipmentSkinApply)
    end
end

function F.putOnGloves(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local oldIns, oldRes = F.findWornInsBySubType(GLOVES_SUB)
    F.removeRoleWearBySubType(GLOVES_SUB)
    F.saveEquip(resID, insID)

    local slot = 8
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(GLOVES_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern, expire_ts = 0 }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local logic_wardrobe_avatar = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        logic_wardrobe_avatar:AddToWearInfo(GLOVES_SUB, insID, resID, d.color or 0, d.pattern or 0)
        DataMgr.UpdateRoleWearData(insID, oldIns or 0)
        logic_wardrobe_avatar:AvatarChange(resID, true, d.color, d.pattern)
    end)
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl.SetClickItemInsId then wl:SetClickItemInsId(insID) end
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
        end
    end)
    F.invalidateSocialWearCache()
end

function F.ensureDepotItemValid(insID, resID)
    insID = tonumber(insID)
    if not insID then return end
    pcall(function()
        local entity = F.getEntity()
        if entity and entity.GetDataByInsID then
            local d = entity:GetDataByInsID(insID)
            if d then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
            end
        end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local hd = wd:GetHallDepotItemDataByInsID(insID)
        if hd then
            hd.expire_ts = 0
            if hd.expireTS ~= nil then hd.expireTS = 0 end
            if hd.valid_hours ~= nil then hd.valid_hours = 0 end
        end
    end)
end

function F.clearItemExpire(itemData, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if type(itemData) == "table" then
        itemData.expireTS = 0
        itemData.expire_ts = 0
        itemData.expireTs = 0
    end
end

function F.onGlideClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    local isGlide = resID and F.isGlideRes(resID)
    if not isGlide and itemData.itemSubType then
        isGlide = GLIDER_SUBS[tonumber(itemData.itemSubType)] == true
    end
    if insID and resID and isGlide then
        F.saveEquip(resID, insID)
        if F.putOnGlider(insID) then
            pcall(function()
                if self.ShowGlide then self:ShowGlide(resID) end
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitGlideClickOrig then
        F.clearItemExpire(itemData, insID, resID)
        return _G.AddOutfitGlideClickOrig(self, itemData)
    end
end

function F.onParachuteClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    if insID and resID and F.isParachuteRes(resID) then
        F.saveEquip(resID, insID)
        if F.putOnParachute(insID) then
            pcall(function()
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitParaClickOrig then
        return _G.AddOutfitParaClickOrig(self, itemData)
    end
end

function F.hookAirborneClick()
    pcall(function()
        local WG = require("client.slua.umg.Wardrobe.subtab_gliding")
        if WG then
            if not WG._AddOutfitGlideWrapped then
                WG._AddOutfitGlideWrapped = true
                _G.AddOutfitGlideClickOrig = WG.ClickItem
            end
            WG.ClickItem = function(self, itemData)
                return F.onGlideClick(self, itemData)
            end
        end
        local WP = require("client.slua.umg.Wardrobe.subtab_parachute")
        if WP then
            if not WP._AddOutfitParaWrapped then
                WP._AddOutfitParaWrapped = true
                _G.AddOutfitParaClickOrig = WP.ClickItem
            end
            WP.ClickItem = function(self, itemData)
                return F.onParachuteClick(self, itemData)
            end
        end
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd and not fbd._AddOutfitAirborneFBHooked then
            fbd._AddOutfitAirborneFBHooked = true
            local oG = fbd.UpdateAircraftOrGliding
            fbd.UpdateAircraftOrGliding = function(self, putOnID, bAircraft)
                local r = oG(self, putOnID, bAircraft)
                local ins = tonumber(putOnID)
                if ins and ins > 0 then
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                    local res = d and tonumber(d.resID)
                    if res and F.isGlideRes(res) then F.saveEquip(res, ins) end
                end
                return r
            end
            local oP = fbd.UpdateParachute
            if oP then
                fbd.UpdateParachute = function(self, insID)
                    local r = oP(self, insID)
                    local ins = tonumber(insID)
                    if ins and ins > 0 then
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                        local res = d and tonumber(d.resID)
                        if res and F.isParachuteRes(res) then F.saveEquip(res, ins) end
                    end
                    return r
                end
            end
        end
    end)
    pcall(function()
        if not ModuleManager or not ModuleManager.GetModule then return end
        local FB = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.FashionBagEditUtils)
        if FB and not FB._AddOutfitFBBagHooked then
            FB._AddOutfitFBBagHooked = true
            local o = FB.PutOnFashionBagItem
            FB.PutOnFashionBagItem = function(self, itemData)
                if itemData then
                    F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
                end
                local r = o(self, itemData)
                if itemData then
                    local res = tonumber(itemData.res_id)
                    local ins = tonumber(itemData.ins_id)
                    if res and ins and (F.isGlideRes(res) or F.isParachuteRes(res)) then
                        F.saveEquip(res, ins)
                    end
                end
                return r
            end
        end
    end)
end

function F.putOnParachute(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or not F.isParachuteRes(resID) then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.SetParachute then fbd:SetParachute(insID) end
        if fbd.UpdateParachute then fbd:UpdateParachute(insID) end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.putOnGlider(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)
    if not F.isGlideRes(resID) and not GLIDER_SUBS[st] then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    local bAircraft = false
    pcall(function()
        local ModelDisplayTypeHelper = require("client.logic.avatar.ModelDisplayTypeHelper")
        local st = F.subType(F.cfg(resID))
        bAircraft = ModelDisplayTypeHelper.IsGlideSmoke(st)
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateAircraftOrGliding then
            fbd:UpdateAircraftOrGliding(insID, bAircraft)
        elseif fbd.SetGliding then
            fbd:SetGliding(insID)
            if DataMgr.UpdateEffect then DataMgr.UpdateEffect(insID) end
        end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.syncAirborneToDataMgr()
    F.applyPersistSlotsToCache()
    local cch = F.cache()
    local paraRes = F.getDesiredParachuteRes()
    local gliderRes = F.getDesiredGliderRes()
    if paraRes and paraRes > 0 and not cch.parachuteIns then
        cch.parachuteIns = F.resolveInsForRes(paraRes)
        cch.parachuteRes = paraRes
    end
    if gliderRes and gliderRes > 0 and not cch.gliderIns then
        cch.gliderIns = F.resolveInsForRes(gliderRes)
        cch.gliderRes = gliderRes
    end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if cch.parachuteIns and tonumber(cch.parachuteIns) > 0 then
            if fbd.SetParachute then fbd:SetParachute(cch.parachuteIns) end
            if DataMgr.roleData then DataMgr.roleData.parachute = tostring(cch.parachuteIns) end
        end
        if cch.gliderIns and tonumber(cch.gliderIns) > 0 then
            local bAircraft = false
            if cch.gliderRes then
                pcall(function()
                    local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
                    bAircraft = not MDH.IsGlideSmoke(F.subType(F.cfg(cch.gliderRes)))
                end)
            end
            if fbd.UpdateAircraftOrGliding then
                fbd:UpdateAircraftOrGliding(cch.gliderIns, bAircraft)
            elseif fbd.SetGliding then
                fbd:SetGliding(cch.gliderIns)
                if DataMgr.UpdateEffect then DataMgr.UpdateEffect(cch.gliderIns) end
            end
            if DataMgr.roleData then
                if bAircraft then
                    DataMgr.roleData.aircraft_put_id = tostring(cch.gliderIns)
                    DataMgr.gliding = cch.gliderIns
                else
                    DataMgr.roleData.gliding = tostring(cch.gliderIns)
                end
            end
        end
    end)
end

function F.putOnGenericInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    F.saveEquip(resID, insID)
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0)
end

function F.clearEquipCache(resID)
    local st = F.subType(F.cfg(resID))
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = nil, nil
            _G.AddOutfitLastLobbyTshirtRes = nil
            F.persistForgetSlot("tshirt")
        else
            cch.outfitRes, cch.outfitIns = nil, nil
            _G.AddOutfitLastLobbyOutfitRes = nil
            F.persistForgetSlot("outfit")
        end
    elseif st == HAT_SUB or HEAD_SUBS[st] then
        cch.hatRes, cch.hatIns = nil, nil
        _G.AddOutfitLastLobbyHatRes = nil
        F.persistForgetSlot("hat")
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = nil, nil
        _G.AddOutfitLastLobbyMaskRes = nil
        F.persistForgetSlot("mask")
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = nil, nil
        _G.AddOutfitLastLobbyGlassRes = nil
        F.persistForgetSlot("glass")
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = nil, nil
        _G.AddOutfitLastLobbyPantsRes = nil
        F.persistForgetSlot("pants")
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = nil, nil
        _G.AddOutfitLastLobbyShoesRes = nil
        F.persistForgetSlot("shoes")
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = nil, nil
        _G.AddOutfitLastLobbyBagRes = nil
        F.persistForgetSlot("bag")
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = nil, nil
        _G.AddOutfitLastLobbyHelmetRes = nil
        F.persistForgetSlot("helmet")
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = nil, nil
        _G.AddOutfitLastLobbyParachuteRes = nil
        F.persistForgetSlot("parachute")
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = nil, nil
        _G.AddOutfitLastLobbyGliderRes = nil
        F.persistForgetSlot("glider")
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = nil, nil
        _G.AddOutfitLastLobbyGlovesRes = nil
        F.persistForgetSlot("gloves")
    end
    _matchApplied = false
    F.invalidateSocialWearCache()
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.takeOffInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    local st = F.subType(F.cfg(resID))

    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_down_rsp(NET_OK, { res_id = resID, count = 1 }, insID)
    end)

    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        AvatarData.RemoveRoleWearDataByValue(insID)
    end)
    if st == HAT_SUB or HEAD_SUBS[st] then
        pcall(function()
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag and tonumber(bag.head_show) == insID then fbd:SetHeadShow(0) end
        end)
    end
    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            local t = DataMgr.equipmentSkinInsIDTable
            if t then
                for _, k in ipairs({ st, 504, 505 }) do
                    if tonumber(t[k]) == insID then t[k] = 0 end
                end
            end
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if tonumber(bag.bag_skin) == insID then bag.bag_skin = 0 end
                if tonumber(bag.helmet_skin) == insID then bag.helmet_skin = 0 end
            end
        end)
    end

    F.clearEquipCache(resID)
    pcall(function() F.syncFashionBagRolewear() end)
end

function F.syncWeaponArmorySilent(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return end
    local resID = R.insToRes[insID]
    if not resID then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
        end
    end)
end

function F.equipWeaponSkin(weaponID, insID, forceVisual)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if not resID then return false end

    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if not forceVisual and F.isWeaponVisuallyEquipped(weaponID, insID) then
        F.syncWeaponArmorySilent(weaponID, insID)
        return false
    end
    F.saveEquip(resID, insID)

    local Arm = require("client.logic.armory.logic_armory")
    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
    local HT = require("client.logic.lobby.hall_theme_utils")
    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    if fbd.UpdateCurrentFashionBagWeaponSkin then
        fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
    end

    local bagIdx = fbd:GetFashionBagUseIndex()
    HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {})

    wgl:SetGunID(weaponID)
    wgl:UpdateCurrentGunAvatar(weaponID, insID)

    if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
    end
    if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
    end
    _G.AddOutfitWeaponEquipped[weaponID] = insID
    return true
end

local SOCIAL = _G.AddOutfitSocialState or {}
_G.AddOutfitSocialState = SOCIAL
SOCIAL.debGen = SOCIAL.debGen or 0
SOCIAL.wearPatchKey = SOCIAL.wearPatchKey or nil
SOCIAL.snapshotKey = SOCIAL.snapshotKey or nil
SOCIAL.fullSnapshot = SOCIAL.fullSnapshot or nil

function F.socialDebounce(sec, fn)
    SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
    local gen = SOCIAL.debGen
    F.later(sec, function()
        if gen ~= SOCIAL.debGen then return end
        pcall(fn)
    end)
end

function F.getLobbyCurPage()
    local p = nil
    pcall(function()
        local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
        if LMC.GetCurPage then p = LMC.GetCurPage() end
    end)
    return p
end

function F.isLobbyLeftPage()
    return ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left
end

function F.getWeaponSkinResFast()
    local cch = F.cache()
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local w = wid > 0 and cch.weapons[wid] or nil
    if w and w.resID and w.resID > 0 then return w.resID end
    for _, ww in pairs(cch.weapons) do
        if ww.resID and ww.resID > 0 then return ww.resID end
    end
    return nil
end

function F.resolveLobbyWeaponSkinRes()
    if LOBBY.skinResolved then return LOBBY.cachedSkin end
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local skin = F.getWeaponSkinResFast()
    if skin and skin > 0 then return skin end

    if wid > 0 then
        local fromMatch = F.getMatchWeaponSkin(wid)
        if fromMatch and fromMatch > 0 then return fromMatch end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, s in pairs(MATCH_CONFIG.weaponSkins) do
            s = tonumber(s)
            if s and s > 0 then return s end
        end
    end

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local entry = Arm.rsp_list and Arm.rsp_list.install_list
            and Arm.rsp_list.install_list[wid > 0 and wid or 101004]
        local insID = tonumber(entry and entry.skin_id) or 0
        if insID > 0 and F.isInjectedIns(insID) then
            skin = tonumber(R.insToRes[insID])
        elseif insID > 0 then
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if d and d.resID then skin = tonumber(d.resID) end
        end
    end)
    if skin and skin > 0 then return skin end

    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID and wid > 0 then
            local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                skin = tonumber(R.insToRes[insID])
            end
        end
    end)
    LOBBY.skinResolved = true
    LOBBY.cachedSkin = (skin and skin > 0) and skin or nil
    return LOBBY.cachedSkin
end

function F.resolveLobbyOutfitRes()
    if LOBBY.outfitResolved then return LOBBY.cachedOutfit end
    local cch = F.cache()
    local outfitRes = tonumber(cch.outfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    outfitRes = tonumber(_G.AddOutfitLastLobbyOutfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = tonumber(MATCH_CONFIG.outfitRes)
        return LOBBY.cachedOutfit
    end

    local injectedRes, anyRes
    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local function resFromIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return nil end
            if F.isInjectedIns(ins) then return tonumber(R.insToRes[ins]) end
            local d = wd:GetHallDepotItemDataByInsID(ins)
            return d and tonumber(d.resID) or nil
        end
        for _, ins in pairs(AvatarData.GetRoleWear()) do
            local res = resFromIns(ins)
            if res and F.isSuitRes(res) then
                if F.isInjectedRes(res) then injectedRes = res end
                anyRes = anyRes or res
            end
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.rolewear_list then
            for _, ins in pairs(bag.rolewear_list) do
                local res = resFromIns(ins)
                if res and F.isSuitRes(res) then
                    if F.isInjectedRes(res) then injectedRes = res end
                    anyRes = anyRes or res
                end
            end
        end
    end)
    if injectedRes and injectedRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = injectedRes
        return injectedRes
    end
    if anyRes and anyRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = anyRes
        return anyRes
    end
    LOBBY.outfitResolved = true
    LOBBY.cachedOutfit = nil
    return nil
end

function F.rememberLobbyOutfitRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isSuitRes(resID) then return end
    _G.AddOutfitLastLobbyOutfitRes = resID
    F.invalidateLobbyResolved()
    local cch = F.cache()
    if not cch.outfitRes or cch.outfitRes <= 0 then
        cch.outfitRes = resID
        if F.isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
    end
end

function F.wearPatchKey()
    local outfit = F.resolveLobbyOutfitRes() or 0
    local skin = F.resolveLobbyWeaponSkinRes() or 0
    local openGun = 1
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then openGun = lds.data.OpenGun and 1 or 0 end
    end)
    return outfit .. "_" .. skin .. "_" .. openGun
end

function F.syncDepotShowWeaponFlags(depot)
    depot = depot or {}
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data then
            if lds.data.OpenGun ~= nil then depot.weapon = lds.data.OpenGun end
            if lds.data.OpenSocialWeapon ~= nil then depot.social_weapon = lds.data.OpenSocialWeapon end
        end
    end)
    return depot
end

function F.applyInjectedPspace(roleData)
    if not roleData then return end
    roleData.bshow = true
    roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
        roleData.depot_show_info = roleData.depot_show_info or {}
        if roleData.depot_show_info.weapon == nil then
            roleData.depot_show_info.weapon = true
        end
    end
    roleData.depot_show_info = F.syncDepotShowWeaponFlags(roleData.depot_show_info)
end

function F.patchSelfWearCache(force)
    local key = F.wearPatchKey()
    if not force and SOCIAL.wearPatchKey == key then return false end
    SOCIAL.wearPatchKey = key
    SOCIAL.snapshotKey = nil
    SOCIAL.fullSnapshot = nil

    local myUid = tonumber(DataMgr.roleData.uid)
    if not myUid then return false end

    local changed = false
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local d = BD:GetCacheData(myUid)
        if not d then
            BD:OnHandleMsgDataAndCallback(myUid, F.buildLocalRoleDataForCoupleAvatar())
            return true
        end
        local oldCloth = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local oldSkin = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        F.applyInjectedPspace(d)
        local nc = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local ns = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        if oldCloth ~= nc or oldSkin ~= ns or not d.bshow then changed = true end
    end)
    return force or changed
end

function F.requestSocialAvatarRefresh()
    pcall(function()
        if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
            EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
        end
    end)
end

function F.onSocialWearDirty(forceRefresh)
    SOCIAL.lastHandSkin = nil
    if F.patchSelfWearCache(forceRefresh) then
        F.requestSocialAvatarRefresh()
    end
end

function F.buildLocalRoleDataForCoupleAvatar()
    local key = F.wearPatchKey()
    if SOCIAL.fullSnapshot and SOCIAL.snapshotKey == key then
        return SOCIAL.fullSnapshot
    end
    F.syncWeaponCacheFromLobby()
    local cch = F.cache()
    local ad = DataMgr.avatarData or {}
    local gender = tonumber(ad.gamegender) or 2
    if gender < 1 then gender = 2 end

    local data = {
        uid = DataMgr.roleData.uid,
        gender = gender,
        bshow = true,
        pspace_wear_ext = {
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HEAD] = { tonumber(ad.headid) or 401993, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HAIR] = { tonumber(ad.hairid) or 40601001, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { 0, 0, 0 },
        },
        depot_show_info = {
            weapon = true, social_weapon = true, idle = true,
            helmet = true, bag = true, vehicle = true, hand = true,
        },
    }

    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end

    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON][1] = 0
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN][1] = skinRes
    end
    data.depot_show_info = F.syncDepotShowWeaponFlags(data.depot_show_info)
    SOCIAL.fullSnapshot = data
    SOCIAL.snapshotKey = F.wearPatchKey()
    return data
end

local _myUidCached
function F.isMyWearData(wearData)
    if not wearData then return false end
    if not _myUidCached then
        pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
    end
    return _myUidCached and tonumber(wearData.uid) == _myUidCached
end

function F.mergeInjectedWeaponIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    wearData.depot_show_info = F.syncDepotShowWeaponFlags(wearData.depot_show_info)
    if not skinRes or skinRes <= 0 then return end
    wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
        weaponResId = 0, weaponSkinId = 0,
        diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
    }
    if wearData.mainWeaponInfo.weaponSkinId == skinRes
        and (tonumber(wearData.mainWeaponInfo.weaponResId) or 0) == 0 then
        return
    end
    wearData.mainWeaponInfo.weaponSkinId = skinRes
    wearData.mainWeaponInfo.weaponResId = 0
end

function F.equipSocialHandWeapon(avatar, skinRes)
    if not avatar or not skinRes or skinRes <= 0 then return end
    if SOCIAL.lastHandSkin == skinRes then return end
    SOCIAL.lastHandSkin = skinRes
    pcall(function()
        avatar:PutonEquipment(skinRes, nil, { bIsUse = true })
    end)
end

function F.shouldShowHandWeapon()
    local show = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then
            show = lds.data.OpenGun ~= false
        end
    end)
    return show
end

function F.mergeInjectedOutfitIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local outfitRes = F.resolveLobbyOutfitRes()
    if not outfitRes or outfitRes <= 0 then return end
    F.rememberLobbyOutfitRes(outfitRes)
    local AvatarData = require("client.logic.data.AvatarData")
    local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
    if not converted then return end
    wearData.WearInfoList = wearData.WearInfoList or {}
    local replaced = false
    for i, e in ipairs(wearData.WearInfoList) do
        if e and e.ItemID and F.isSuitRes(e.ItemID) then
            wearData.WearInfoList[i] = converted
            replaced = true
            break
        end
    end
    if not replaced then
        table.insert(wearData.WearInfoList, converted)
    end
end

function F.mergeInjectedIntoWearData(wearData)
    if not wearData then return end
    F.mergeInjectedWeaponIntoWearData(wearData)
    F.mergeInjectedOutfitIntoWearData(wearData)
end

-- Apply the saved suit as soon as the injected wardrobe mapping is ready.
-- This intentionally runs before the lobby-page guard used by the social
-- avatar path; otherwise the first load can wait for the delayed lobby
-- reapply while weapon skins are already visible.
function F.applyPersistedSuitImmediate()
    local cch = F.cache()
    if not cch then return false end
    F.applyPersistSlotsToCache()
    local applied = false
    if cch.outfitIns and F.isInjectedIns(cch.outfitIns) then
        pcall(function() F.putOnOutfit(cch.outfitIns) end)
        applied = true
    end
    if cch.tshirtIns and F.isInjectedIns(cch.tshirtIns) then
        pcall(function() F.putOnRoleWear(cch.tshirtIns) end)
        applied = true
    end
    return applied
end

function F.reapplyLobbyEquipped()
    -- Suit and T-shirt are restored in the same immediate pass as weapon
    -- skins, even when the current lobby page is the social/left page.
    F.applyPersistedSuitImmediate()
    if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
        return
    end
    F.syncWeaponCacheFromLobby()
    F.applyPersistSlotsToCache()
    local curPage = F.getLobbyCurPage()

    if ENUM_LobbyPageType and curPage == ENUM_LobbyPageType.Left then
        F.onSocialWearDirty(true)
        return
    end

    local cch = F.cache()
    -- Saved accessory entries contain resource IDs, but the wardrobe appliers
    -- need the injected instance ID. Resolve each saved resource again after
    -- the wardrobe has finished loading; this is especially important for
    -- bag/helmet and airborne items, whose instance mapping is often late.
    local function savedIns(resKey, insKey)
        local res = tonumber(cch[resKey])
        local ins = tonumber(cch[insKey])
        if res and res > 0 and (not ins or ins <= 0 or not F.isInjectedIns(ins)) then
            ins = F.resolveInsForRes(res)
            if ins and ins > 0 then
                cch[insKey] = ins
                R.resToIns[res] = ins
                R.insToRes[ins] = res
            end
        end
        return ins
    end
    if cch.outfitIns and F.isInjectedIns(cch.outfitIns) then
        F.putOnOutfit(cch.outfitIns)
    end
    local hatIns = savedIns("hatRes", "hatIns")
    if hatIns and F.isInjectedIns(hatIns) then
        F.putOnHat(hatIns)
    end
    local maskIns = savedIns("maskRes", "maskIns")
    if maskIns and F.isInjectedIns(maskIns) then
        F.putOnRoleWear(maskIns)
    end
    local glassIns = savedIns("glassRes", "glassIns")
    if glassIns and F.isInjectedIns(glassIns) then
        F.putOnRoleWear(glassIns)
    end
    if cch.tshirtIns and F.isInjectedIns(cch.tshirtIns) then
        F.putOnRoleWear(cch.tshirtIns)
    end
    local pantsIns = savedIns("pantsRes", "pantsIns")
    if pantsIns and F.isInjectedIns(pantsIns) then
        F.putOnRoleWear(pantsIns)
    end
    local shoesIns = savedIns("shoesRes", "shoesIns")
    if shoesIns and F.isInjectedIns(shoesIns) then
        F.putOnRoleWear(shoesIns)
    end
    local bagIns = savedIns("bagRes", "bagIns")
    if bagIns and F.isInjectedIns(bagIns) then
        F.putOnRoleWear(bagIns)
    end
    local helmetIns = savedIns("helmetRes", "helmetIns")
    if helmetIns and F.isInjectedIns(helmetIns) then
        F.putOnRoleWear(helmetIns)
    end
    local parachuteIns = savedIns("parachuteRes", "parachuteIns")
    if parachuteIns then
        F.putOnParachute(parachuteIns)
    end
    local gliderIns = savedIns("gliderRes", "gliderIns")
    if gliderIns then
        F.putOnGlider(gliderIns)
    end
    local glovesIns = savedIns("glovesRes", "glovesIns")
    if glovesIns and F.isInjectedIns(glovesIns) then
        F.putOnGloves(glovesIns)
    end

    local mainWid = tonumber(DataMgr.Weapon_ID) or 0
    local w = mainWid > 0 and cch.weapons[mainWid] or nil
    if w and w.resID and w.resID > 0 then
        if w.insID and F.isInjectedIns(w.insID) then
            F.equipWeaponSkin(mainWid, w.insID)
        else
            pcall(function() DataMgr.InitWeaponData(mainWid, w.resID, w.insID or 0) end)
        end
    end

    pcall(function()
        local uid = tostring(DataMgr.roleData.uid)
        local LAM = require("client.logic.avatar.LobbyAvatarManager")
        local TAM = require("client.logic.avatar.logic_team_avatar_manager")
        if w and w.resID and w.resID > 0 and TAM.GetAvatarByUid(uid) then
            LAM.EquipWeapon(uid, { weaponId = mainWid, skinId = w.resID }, nil, true)
        end
    end)

    F.reapplyVehicleSlotsFromConfig(true)
    F.reapplyHallThemeFromConfig(true)
    F.reapplyWeaponsFromConfig()
    pcall(F.applyVehicleSkinsToPC)
end

F.scheduleLobbyReapplyOnce = function()
    if LOBBY.reapplyDone or LOBBY.reapplyScheduled then return end
    LOBBY.reapplyScheduled = true
    F.later(2.0, function()
        LOBBY.reapplyScheduled = false
        if LOBBY.reapplyDone then return end
        LOBBY.reapplyDone = true
        F.reapplyLobbyEquipped()
    end)
end

function F.hookLobbySwipePersistence()
    if _G.AddOutfitLobbySwipeHooked then return end
    _G.AddOutfitLobbySwipeHooked = true
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local oRsp = BD.on_get_avatar_show_rsp
        BD.on_get_avatar_show_rsp = function(self, res, target_uid, data)
            oRsp(self, res, target_uid, data)
                if tonumber(target_uid) == tonumber(DataMgr.roleData.uid) then
                F.patchSelfWearCache(true)
                SOCIAL.forceAvatarRedraw = true
                SOCIAL.lastHandSkin = nil
                if ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    F.requestSocialAvatarRefresh()
                end
            end
        end
    end)

    pcall(function()
        local AC = require("client.slua.logic.avatar.avatar_common")
        local oGetWear = AC.GetWearDataFromRoleData
        AC.GetWearDataFromRoleData = function(roleData)
            local wearData = oGetWear(roleData)
            if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid)
                and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            return wearData
        end
        local oUp = AC.UpdateAvatar
        AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            local showGun = isShowWeapon and F.shouldShowHandWeapon()
            if wearData and wearData.depot_show_info then
                showGun = showGun and wearData.depot_show_info.weapon ~= false
            end
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if e and e.ItemID and F.isInjectedRes(e.ItemID) and F.isSuitRes(e.ItemID) then
                        F.rememberLobbyOutfitRes(e.ItemID)
                        break
                    end
                end
            end
            local ret = oUp(avatar, wearData, showGun, isShowHelmet, isShowBag)
            if showGun and F.isMyWearData(wearData) and avatar and F.isLobbyLeftPage() then
                local skin = tonumber(wearData.mainWeaponInfo and wearData.mainWeaponInfo.weaponSkinId) or 0
                if skin <= 0 then skin = F.resolveLobbyWeaponSkinRes() or 0 end
                if skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
            end
            return ret
        end
    end)

    pcall(function()
        local CA = require("client.logic.avatar.CoupleAvatar")
        local Cfg = require("client.slua.logic.lobby.Left.CoupleAvatarConfig")
        local oMulti = CA._UpdateMultiAvatar
        if oMulti then
            CA._UpdateMultiAvatar = function(self, avatar, avatarType)
                local isSelf = avatarType == Cfg.AvatarType.Self
                    and self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
                if isSelf and F.isLobbyLeftPage() then
                    pcall(function()
                        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                        local d = BD:GetCacheData(tonumber(self.SelfUID))
                        if d then F.applyInjectedPspace(d) end
                    end)
                    if SOCIAL.forceAvatarRedraw then
                        self.CompareDataCache[avatarType] = nil
                        SOCIAL.forceAvatarRedraw = nil
                    end
                end
                oMulti(self, avatar, avatarType)
                if isSelf and F.isLobbyLeftPage() and self.isShowWeapon ~= false and F.shouldShowHandWeapon() then
                    local skin = F.resolveLobbyWeaponSkinRes()
                    if skin and skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
                end
            end
        end
        local oHideCheck = CA.CheckSelfIsHideAvatar
        CA.CheckSelfIsHideAvatar = function(self, nSelfUId, tRoleData)
            if F.isLobbyLeftPage() and tostring(nSelfUId) == tostring(DataMgr.roleData.uid) then
                return false
            end
            return oHideCheck(self, nSelfUId, tRoleData)
        end

        local oUpdate = CA.Update
        CA.Update = function(self)
            if not F.isLobbyLeftPage() then
                return oUpdate(self)
            end
            local isSelf = self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
            local oHide = CA.HideAvatars
            if isSelf then
                CA.HideAvatars = function() end
            end
            local ok, err = pcall(oUpdate, self)
            CA.HideAvatars = oHide
        end

        local oRecv = CA.OnReceiveData
        CA.OnReceiveData = function(self, uid, data)
            if F.isLobbyLeftPage() and uid == self.SelfUID and tostring(uid) == tostring(DataMgr.roleData.uid) then
                if data then
                    F.applyInjectedPspace(data)
                else
                    data = F.buildLocalRoleDataForCoupleAvatar()
                end
            end
            return oRecv(self, uid, data)
        end
    end)

    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_START then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_START, function(_, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    local o = F.resolveLobbyOutfitRes()
                    if o then F.rememberLobbyOutfitRes(o) end
                    F.patchSelfWearCache(true)
                    SOCIAL.forceAvatarRedraw = true
                end
            end)
        end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    F.socialDebounce(0.45, function()
                        F.onSocialWearDirty(true)
                    end)
                elseif ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                    SOCIAL.wearPatchKey = nil
                    F.invalidateLobbyResolved()
                    if not LOBBY.reapplyDone then
                        F.socialDebounce(0.5, F.scheduleLobbyReapplyOnce)
                    end
                end
            end)
        end
        if EVENTTYPE_LOBBY_SOCIAL and EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA then
            EventSystem:registEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA, function(_, _, nUId)
                if tonumber(nUId) == tonumber(DataMgr.roleData.uid) then
                    F.socialDebounce(0.2, function() F.patchSelfWearCache(false) end)
                end
            end)
        end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function()
                SOCIAL.wearPatchKey = nil
                SOCIAL.snapshotKey = nil
                F.syncWeaponCacheFromLobby()
                
                local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
                if curPage == ENUM_LobbyPageType.Left then
                    F.socialDebounce(0.25, function() F.onSocialWearDirty(true) end)
                end
                
                -- [BUG FIX VIP] Automatically reapply Mod Skin when the game shows weapon updates in the lobby
                F.socialDebounce(0.3, function()
                    if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
                end)
            end)
        end
    end)

    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        local oSwitch = lds.SwitchGun
        lds.SwitchGun = function(...)
            local r = oSwitch(...)
            SOCIAL.wearPatchKey = nil
            
            local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
            if curPage == ENUM_LobbyPageType.Left then
                F.socialDebounce(0.2, function() F.onSocialWearDirty(true) end)
            end
            
            -- [BUG FIX VIP] When clicking the weapon slot in the lobby, wait for the game to swap the original gun, then reapply Mod Skin after 0.3s
            F.socialDebounce(0.3, function()
                if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
            end)
            
            return r
        end
    end)
end

function F.hookDepotInit()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if WDE._AddOutfitInitHooked then return end
        WDE._AddOutfitInitHooked = true
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            _G.AddOutfitUnexpireDone = false
            -- Kalau saat start modul ini belum bisa di-require, pasang hook
            -- GetData sekarang: kelasnya jelas sudah ada karena InitData jalan.
            pcall(F.hookWardrobeGetData)
            -- Hook lain juga dipasang ulang di sini: WardRobeHandler dan
            -- logic_wardrobe_new bisa belum ada saat script dimuat.
            if F.ensureWardrobeHooks then pcall(F.ensureWardrobeHooks) end
            pcall(function()
                if F.injectAll(self) then
                    pcall(F.mergeInjectedArmorySkins)
                    pcall(F.reapplyThrowObjectBag)
                    F.scheduleInjectRefresh()
                    LOBBY.reapplyDone = false
                    LOBBY.reapplyScheduled = false
                    F.scheduleLobbyReapplyOnce()
                end
            end)
        end
    end)
end

function F.hookWardrobeData()
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        if wd._AddOutfitDataHooked then return end
        wd._AddOutfitDataHooked = true
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                local r
                if F.isInjectedIns(insID) then
                    local e = F.getEntity()
                    if e then r = e:GetDataByInsID(insID) end
                    if not r then r = F.ensureOwnedDepotByIns(insID) end
                else
                    r = o(self, insID, ...)
                end
                if r and (F.isInjectedIns(insID) or F.isInjectedRes(r.resID or r.res_id)) then
                    r.expire_ts = 0
                    r.expireTS = 0
                    r.valid_hours = 0
                end
                return r
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")
        -- Lookup berbasis resID: materialisasi entri katalog saat diminta.
        -- Ini yang membuat item baru langsung "owned" walau injectAll belum
        -- sempat berjalan (mis. dipanggil saat loading lobby).
        local function wrapRes(name, returnsList)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, resID, ...)
                resID = tonumber(resID)
                local r = o(self, resID, ...)
                if (r == nil or (returnsList and type(r) == "table" and #r == 0))
                    and F.isOwnedRes(resID) then
                    F.ensureOwnedDepot(resID)
                    r = o(self, resID, ...)
                end
                return r
            end
        end
        wrapRes("GetHallDepotItemDataByResID")
        wrapRes("GetAllHallDepotItemDataByResID")
        wrapRes("GetHallDepotItemDataByResIDAndSource")
        wrapRes("GetHallDepotItemDataByResIDAndValidExpireTime")
        wrapRes("GetHallDepotItemDataByResIDAndTimeliness")
        wrapRes("GetHallDepotItemListByResID", true)
        wrapRes("GetHallDepotItemListByResIDValidExpireTime", true)
        local oCount = wd.GetHallDepotItemCountByResID
        if oCount then
            wd.GetHallDepotItemCountByResID = function(self, resID, ...)
                resID = tonumber(resID)
                local n = oCount(self, resID, ...)
                if (not n or n == 0) and F.isOwnedRes(resID) then
                    F.ensureOwnedDepot(resID)
                    n = oCount(self, resID, ...)
                    if not n or n == 0 then n = 1 end
                end
                return n
            end
        end
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                id = tonumber(id)
                if F.isOwnedRes(id) or F.isInjectedIns(id) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
    end)
end

-- Dipanggil setiap grid mengambil daftar depot. Kalau entri sintetis belum
-- ada (InitData terlambat / hook terpasang setelah depot dibangun), suntik
-- tepat sebelum daftar dibaca supaya item langsung ikut terfilter.
function F.hookWardrobeGetData()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if WDE._AddOutfitGetDataHooked then return end
        WDE._AddOutfitGetDataHooked = true
        local orig = WDE.GetData
        if not orig then return end
        WDE.GetData = function(self, ...)
            -- Jalankan milik game lebih dulu: EnsureAllConfigLoaded memuat
            -- config item server, jadi entri baru tidak memicu loop config.
            local result = orig(self, ...)
            local mark = LAST_INJECT[self]
            if not F._injectBusy
                and (mark == nil or mark.data ~= rawget(self, "_data")) then
                pcall(F.injectAll, self)
            end
            return result
        end
    end)
end

-- Jalur kedua: sebagian tab (weapon/pendant) membaca daftar lewat
-- WardrobeData, bukan langsung ke entity.
function F.hookWardrobeDepotList()
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        if wd._AddOutfitDepotListHooked then return end
        wd._AddOutfitDepotListHooked = true
        local orig = wd.GetArrayHallDepotItemInfo
        if not orig then return end
        wd.GetArrayHallDepotItemInfo = function(self, ...)
            pcall(F.injectAll)
            return orig(self, ...)
        end
    end)
end

function F.hookPageFilter()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPageFilterHooked then return end
        wl._AddOutfitPageFilterHooked = true
        local o1 = wl.IsValidCurrentPageItem
        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
            if v and F.isOwnedRes(v.resID) then
                local itemTab = tonumber(v.subTabType)
                local itemMain = tonumber(v.mainTabType)
                if itemTab == nil or itemMain == nil then
                    local meta = F.catalogMeta(v.resID)
                    if meta then
                        itemMain = itemMain or meta[3]
                        itemTab = itemTab or meta[4]
                    end
                end
                if itemTab and itemTab == subTab
                    and (itemMain == mainTab
                        or (mainTab == PAGE_PARACHUTE and F.isHallThemeRes(v.resID))) then
                    -- Item katalog selalu permanen (expire 0), jadi tidak perlu
                    -- cek waktu di sini.
                    return true
                end
            end
            return o1(self, mainTab, subTab, v, t)
        end
        local o2 = wl.IsCanUse
        wl.IsCanUse = function(self, resId)
            if F.isOwnedRes(resId) then return true end
            return o2(self, resId)
        end
        local o3 = wl.IsCharacterUse
        wl.IsCharacterUse = function(self, resId)
            if F.isOwnedRes(resId) then return true end
            return o3(self, resId)
        end
        local o4 = wl.GetWardrobeInsIdByResId
        wl.GetWardrobeInsIdByResId = function(self, resid)
            resid = tonumber(resid)
            if not F.isOwnedRes(resid) then
                return o4 and o4(self, resid) or 0
            end
            -- Sudah dipetakan (biasanya oleh injeksi massal): pakai langsung.
            local ins = R.resToIns[resid]
            if ins and tonumber(ins) and tonumber(ins) > 0 then return ins end
            -- Belum dipetakan: tanya depot asli. Kalau item benar-benar
            -- dimiliki, ini mengembalikan insID server; kalau tidak, wrapper
            -- lookup akan membuat entri sintetis yang konsisten.
            local real = o4 and o4(self, resid) or nil
            real = tonumber(real)
            if real and real > 0 then
                R.resToIns[resid], R.insToRes[real] = real, resid
                return real
            end
            ins = F.catalogIns(resid)
            if ins then
                R.resToIns[resid], R.insToRes[ins] = ins, resid
                return ins
            end
            return 0
        end
        -- Region lock (ENUM ItemRegion/ValidRegionCodes) membuat item katalog
        -- menampilkan notice 4987 dan batal dipakai. Untuk wardrobe pribadi
        -- semua item katalog harus bisa dipakai.
        local o5 = wl.IsItemIsolated
        if o5 then
            wl.IsItemIsolated = function(self, resId)
                if F.isOwnedRes(resId) then return false end
                return o5(self, resId)
            end
        end
    end)
end

function F.hookArmory()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm._AddOutfitArmoryHooked then return end
        Arm._AddOutfitArmoryHooked = true
        local oa = Arm.get_weapon_skin_list_rsp
        Arm.get_weapon_skin_list_rsp = function(a, b, c, d)
            oa(a, b, c, d)
            F.mergeInjectedArmorySkins()
        end
        local oi = Arm.install_weapon_skin
        Arm.install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return oi(cd, wid, ins)
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        if AH._AddOutfitArmorySendHooked then return end
        AH._AddOutfitArmorySendHooked = true
        local o = AH.send_install_weapon_skin
        AH.send_install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return o(cd, wid, ins)
        end
    end)
end

function F.hookGunSkinId()
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl._AddOutfitGunSkinHooked then return end
        wgl._AddOutfitGunSkinHooked = true
        local o = wgl.GetSkinIdByWeaponID
        wgl.GetSkinIdByWeaponID = function(self, wid)
            local c = F.cache()
            local w = c.weapons[wid]
            if w and F.isWeaponSkinIns(w.insID) then return w.insID end
            local Arm = require("client.logic.armory.logic_armory")
            if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                local sid = Arm.rsp_list.install_list[wid].skin_id
                if sid and F.isWeaponSkinIns(sid) then return sid end
            end
            return o(self, wid)
        end
    end)
end

function F.hookPutOn()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutOnHooked then return end
        WRH._AddOutfitPutOnHooked = true
        local o = WRH.send_depot_put_on_req
        WRH.send_depot_put_on_req = function(insID, extra)
            insID = tonumber(insID)
            if F.tryLocalWearByIns(insID) then return end
            -- Jaring kedua: apa pun yang lolos dari jalur di atas tetapi
            -- masih item katalog tidak boleh dikirim ke server.
            if insID and F.isInjectedIns(insID) and F.localEquipResponse(insID, extra) then
                return
            end
            -- Item sintetis tidak pernah dikenal server. Kalau respon lokal
            -- gagal (mis. modul wardrobe belum siap), lebih baik no-op
            -- daripada mengirim insID palsu dan memicu notice error.
            if insID and F.isInjectedIns(insID) then return end
            return o(insID, extra)
        end
    end)
end

function F.hookPutDown()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutDownHooked then return end
        WRH._AddOutfitPutDownHooked = true
        local o = WRH.send_depot_put_down_req
        WRH.send_depot_put_down_req = function(insID)
            insID = tonumber(insID)
            if insID and F.isInjectedIns(insID) then
                if not F.localUnequipResponse(insID) then F.takeOffInjected(insID) end
                return
            end
            return o(insID)
        end
        local ob = WRH.send_depot_batch_put_down_req
        WRH.send_depot_batch_put_down_req = function(instid_list)
            local rest = {}
            for _, id in ipairs(instid_list or {}) do
                if F.isInjectedIns(tonumber(id)) then
                    if not F.localUnequipResponse(id) then F.takeOffInjected(id) end
                else
                    rest[#rest + 1] = id
                end
            end
            if #rest > 0 then return ob(rest) end
        end
    end)
end

function F.hookVehicleSwitchEffect()
    if _G.AddOutfitVehSwitchHooked then return end
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local impl = VAC and VAC.__inner_impl
        if not impl or impl._AddOutfitVehSwitchHooked then return end
        impl._AddOutfitVehSwitchHooked = true

        if not _G.AddOutfitVehOrigCanSwitch then
            _G.AddOutfitVehOrigCanSwitch = impl.CheckCanPlaySkinSwitchEffect
        end
        impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            return true
        end

        if not _G.AddOutfitVehOrigShowSwitch then
            _G.AddOutfitVehOrigShowSwitch = impl.ShowVehicleSwitchEffect
        end
        impl.ShowVehicleSwitchEffect = function(self)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
                self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
            end
            local vehicleActor = self:GetOwner()
            if not slua.isValid(vehicleActor) then return false end
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect()
                pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                self.uSwitchEffectActor = nil
            end
            if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                local defId = 0
                pcall(function() defId = self:GetDefaultAvatarID() or 0 end)
                self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or defId or 0
            end
            local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
            local bIsLobbyActor = self:IsLobbyActor()
            local world = slua_GameFrontendHUD:GetWorld()
            local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
            local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
            self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
            if not slua.isValid(self.uSwitchEffectActor) then
                self.uSwitchEffectActor = nil
                return false
            end
            self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
            self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
            self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
            pcall(function() self:HideParticles() end)
            self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
            self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
            self.uSwitchEffectActor:StartVehicleSwitchEffect(
                vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
            self.uOldVehicleMeshAnimClass = nil
            return true
        end

        if not _G.AddOutfitVehOrigBeginPlay then
            _G.AddOutfitVehOrigBeginPlay = impl.ReceiveBeginPlay
        end
        local oBegin = _G.AddOutfitVehOrigBeginPlay
        impl.ReceiveBeginPlay = function(self)
            oBegin(self)
            pcall(function()
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                    self.uSwitchEffectActor = nil
                end
                self.lastEquipedAvatarId = 0
                if self.IsLobbyActor and self:IsLobbyActor() then
                    self.curSwitchEffectId = 0
                elseif F.isInRealMatch() then
                    self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
                else
                    self.curSwitchEffectId = 0
                end
            end)
        end

        if impl.LuaIsAssetsAlreadyAvailable and not _G.AddOutfitVehOrigAssets then
            _G.AddOutfitVehOrigAssets = impl.LuaIsAssetsAlreadyAvailable
            impl.LuaIsAssetsAlreadyAvailable = function(self, avatarId)
                if F.isVehicleSkinAllowed(tonumber(avatarId)) then return true end
                return _G.AddOutfitVehOrigAssets(self, avatarId)
            end
        end

        _G.AddOutfitVehSwitchHooked = true
    end)
end

function F.hookVehicleChassisLight()
    if _G.AddOutfitVehChassisHooked then return end
    pcall(function()
        local LIC = require("GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
        if LIC and LIC.CheckHasVehicleDownloaded and not _G.AddOutfitVehOrigLicDownload then
            _G.AddOutfitVehOrigLicDownload = LIC.CheckHasVehicleDownloaded
            LIC.CheckHasVehicleDownloaded = function(self, itemID)
                local id = tonumber(itemID)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return _G.AddOutfitVehOrigLicDownload(self, itemID)
            end
        end
    end)
    pcall(function()
        local LVF = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicVehicleExtendedFeature)
        if not LVF or LVF._AddOutfitChassisHooked then return end
        LVF._AddOutfitChassisHooked = true

        if not _G.AddOutfitVehOrigGetFeature then
            _G.AddOutfitVehOrigGetFeature = LVF.CheckHasGetFeatureItem
        end
        LVF.CheckHasGetFeatureItem = function(self, featureId)
            if F.isChassisLightId(featureId) then return true end
            return _G.AddOutfitVehOrigGetFeature(self, featureId)
        end

        if not _G.AddOutfitVehOrigEquippedFeature then
            _G.AddOutfitVehOrigEquippedFeature = LVF.CheckHasEquippedItem
        end
        LVF.CheckHasEquippedItem = function(self, featureId, vehicleId)
            -- [FIX VIP] Added ModSkin condition check
            if RAPZHANG_MOD_SKIN_ALWAYS_ON then
                if F.isChassisLightId(featureId) then
                    return F.getDesiredChassisLight(vehicleId) == tonumber(featureId)
                end
            end
            return _G.AddOutfitVehOrigEquippedFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigEquipChassisData then
            _G.AddOutfitVehOrigEquipChassisData = LVF.GetEquipedChassisLightData
        end
        LVF.GetEquipedChassisLightData = function(self, vehicleId, source)
            -- [FIX VIP] Added ModSkin condition check
            if RAPZHANG_MOD_SKIN_ALWAYS_ON then
                local our = F.getDesiredChassisLight(vehicleId)
                if our then return our end
            end
            return _G.AddOutfitVehOrigEquipChassisData(self, vehicleId, source)
        end

        if not _G.AddOutfitVehOrigChassisLightData then
            _G.AddOutfitVehOrigChassisLightData = LVF.GetVehicleChassisLightData
        end
        LVF.GetVehicleChassisLightData = function(self, uid, vehicleId, position, source)
            -- [FIX VIP] Added ModSkin condition check
            if RAPZHANG_MOD_SKIN_ALWAYS_ON then
                if uid and DataMgr and DataMgr.roleData and tonumber(uid) == tonumber(DataMgr.roleData.uid) then
                    local our = F.getDesiredChassisLight(vehicleId)
                    if our then return our end
                end
            end
            return _G.AddOutfitVehOrigChassisLightData(self, uid, vehicleId, position, source)
        end

        if not _G.AddOutfitVehOrigPutOnFeature then
            _G.AddOutfitVehOrigPutOnFeature = LVF.PutOnVehicleFeature
        end
        LVF.PutOnVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                F.saveChassisLight(vehicleId, featureId)
                self.equip_chassis_light = self.equip_chassis_light or {}
                if vehicleId and vehicleId > 0 then
                    self.equip_chassis_light[vehicleId] = featureId
                end
                return
            end
            return _G.AddOutfitVehOrigPutOnFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigPutOffFeature then
            _G.AddOutfitVehOrigPutOffFeature = LVF.PutOffVehicleFeature
        end
        LVF.PutOffVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
                if vehicleId and vehicleId > 0 then
                    PERSIST.configChassisLightMap[vehicleId] = nil
                end
                if self.equip_chassis_light and vehicleId then
                    self.equip_chassis_light[vehicleId] = nil
                end
                F.persistMarkDirty()
                return
            end
            return _G.AddOutfitVehOrigPutOffFeature(self, featureId, vehicleId)
        end
    end)
    _G.AddOutfitVehChassisHooked = true
end

function F.hookVehicles()
    F.hookVehicleSwitchEffect()
    F.hookVehicleChassisLight()
    pcall(function()
        local WV = require("client.slua.umg.Wardrobe.subtab_vehicles")
        if not WV or WV._AddOutfitVehClickHooked then return end
        WV._AddOutfitVehClickHooked = true
        local oClick = WV.ClickItem
        WV.ClickItem = function(self, vehicleSkin, bForceUsing)
            if vehicleSkin and F.isInjectedRes(vehicleSkin.res_id) then
                vehicleSkin.expireTS = 0
                vehicleSkin.expire_ts = 0
            end
            return oClick(self, vehicleSkin, bForceUsing)
        end
        local oDrop = WV.OnVehicleSlotDrop
        if oDrop then
            WV.OnVehicleSlotDrop = function(self, DragWidget, Index, DragDropData)
                pcall(function()
                    local ins = DragDropData and DragDropData.ins_id
                    if F.isInjectedIns(tonumber(ins)) then
                        F.ensureInjectedItemAlive(nil, nil, ins)
                    end
                end)
                return oDrop(self, DragWidget, Index, DragDropData)
            end
        end
    end)
    pcall(function()
        local WNH = require("client.network.Protocol.WardrobeNewHandler")
        if WNH._AddOutfitVehicleHooked then return end
        WNH._AddOutfitVehicleHooked = true
        local oMod = WNH.send_depot_modify_combat_vehicle_req
        WNH.send_depot_modify_combat_vehicle_req = function(instid, slot_index, ope_type)
            if F.modifyInjectedVehicleSlot(instid, slot_index, ope_type == true) then return end
            return oMod(instid, slot_index, ope_type)
        end
        local oRsp = WNH.on_depot_modify_combat_vehicle_rsp
        WNH.on_depot_modify_combat_vehicle_rsp = function(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                knapsack_vst = F.mergeInjectedIntoVehicleSlotList(knapsack_vst)
            end
            oRsp(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                F.syncVehicleSlotsToDataMgr()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
                if not (_G.AddOutfitLobbyVeh and _G.AddOutfitLobbyVeh.manual) then
                    pcall(F.applyVehicleSkinsToPC)
                end
                F.persistMarkDirty()
            end
        end
    end)
    pcall(function()
        local gsm = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.golden_suit_module)
        if gsm and gsm.VehicleNeedClothes and not gsm._AddOutfitVehClothesHooked then
            gsm._AddOutfitVehClothesHooked = true
            local o = gsm.VehicleNeedClothes
            gsm.VehicleNeedClothes = function(self, vehicleId)
                vehicleId = tonumber(vehicleId)
                if vehicleId and F.isInjectedRes(vehicleId) then return 0 end
                return o(self, vehicleId)
            end
        end
    end)
    pcall(function()
        local mod = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
        if mod._FillVehicleSkinList then
            if not _G.AddOutfitVehFillOrig then
                _G.AddOutfitVehFillOrig = mod._FillVehicleSkinList
            end
            local o = _G.AddOutfitVehFillOrig
            mod._FillVehicleSkinList = function(self, playerInfo, uPlayerController)
                F.mergeVstIntoPlayerInfo(playerInfo)
                return o(self, playerInfo, uPlayerController)
            end
            mod._AddOutfitFillVehHooked = true
        end
    end)
    pcall(function()
        local classMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
        if not classMod or not classMod.__inner_impl then return end
        local impl = classMod.__inner_impl
        if not _G.AddOutfitVehOrigClick then
            _G.AddOutfitVehOrigClick = impl.OnClickSkinButton
        end
        local oClick = _G.AddOutfitVehOrigClick
        impl.OnClickSkinButton = function(self)
            local resID = tonumber(self.resID)
            if resID and resID > 0 then
                if F.matchApplyVehicleSkin(resID) then
                    pcall(function()
                        if EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                            EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                        end
                    end)
                end
                return
            end
            return oClick(self)
        end
        if not _G.AddOutfitVehOrigRefresh then
            _G.AddOutfitVehOrigRefresh = impl.OnRefresh
        end
        local oRefresh = _G.AddOutfitVehOrigRefresh
        impl.OnRefresh = function(self, resID, selectIndex)
            oRefresh(self, resID, selectIndex)
            if self.resID and tonumber(self.resID) and tonumber(self.resID) > 0 then
                if F.isResourcesReady(self.resID) then
                    pcall(function()
                        local PufferConst = require("client.slua.logic.download.puffer_const")
                        self.dowloadState = PufferConst.ENUM_DownloadState.Done
                        self.UIRoot.Image_Download:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        self:SetWidgetVisible(self.UIRoot.Image_Mask, false)
                    end)
                else
                    F.requestResourceDownload(self.resID)
                end
            end
        end
        classMod._AddOutfitSkinClickHooked = true
    end)
    pcall(function()
        local utilMod = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
        if utilMod.CheckHasUnLockFeature and not utilMod._AddOutfitVehPlateHooked then
            utilMod._AddOutfitVehPlateHooked = true
            local orig = utilMod.CheckHasUnLockFeature
            utilMod.CheckHasUnLockFeature = function(ft, uid, itemId)
                local id = tonumber(itemId)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return orig(ft, uid, itemId)
            end
        end
    end)
    pcall(function()
        local panelMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
        if panelMod and panelMod.__inner_impl and not panelMod._AddOutfitInitSkinHooked then
            panelMod._AddOutfitInitSkinHooked = true
            local o = panelMod.__inner_impl.InitSkinList
            panelMod.__inner_impl.InitSkinList = function(self)
                F.applyVehicleSkinsToPC(F.getPC())
                return o(self)
            end
        end
    end)
    pcall(function()
        local VUC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleUserComponent")
        if not VUC then return end
        if not _G.AddOutfitVehOrigEnter then
            _G.AddOutfitVehOrigEnter = VUC.SendUIMsgWhenEnterVehicleCompleted
        end
        local oEnter = _G.AddOutfitVehOrigEnter
        VUC.SendUIMsgWhenEnterVehicleCompleted = function(self)
            oEnter(self)
            pcall(function()
                if slua.isValid(self.Vehicle) then
                    F.autoApplyVehicleSkinOnEnter(self.Vehicle)
                end
            end)
        end
        VUC._AddOutfitEnterVehHooked = true
    end)
end

function F.hookWeaponWear()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        local o = HT.IsWeaponWear
        HT.IsWeaponWear = function(insId)
            insId = tonumber(insId)
            if F.isInjectedIns(insId) then
                local c = F.cache()
                local Arm = require("client.logic.armory.logic_armory")
                for wid, w in pairs(c.weapons) do
                    if tonumber(w.insID) == insId then
                        if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                            return tonumber(Arm.rsp_list.install_list[wid].skin_id) == insId
                        end
                        return true
                    end
                end
            end
            return o(insId)
        end
    end)
end

function F.hookNotice()
    pcall(function()
        if DataMgr and not DataMgr._AddOutfitExpireHooked then
            DataMgr._AddOutfitExpireHooked = true
            local oValid = DataMgr.IsValidTime
            DataMgr.IsValidTime = function(expireTS)
                if expireTS == nil or tonumber(expireTS) == 0 then return true end
                if oValid and oValid(expireTS) then return true end
                local inMatch = false
                pcall(function()
                    inMatch = GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
                end)
                if not inMatch then return true end
                return false
            end
        end
    end)
end

function F.wrapWardrobeClick(classMod, key)
    if not classMod or not classMod[key] or classMod["_AddOutfitWrap_" .. key] then return end
    classMod["_AddOutfitWrap_" .. key] = true
    local orig = classMod[key]
    classMod[key] = function(self, widget, index)
        local itemData = self.LoopScrollGrid_Normal and self.LoopScrollGrid_Normal:GetItemData(index)
        if itemData then
            F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
            F.ensureDepotItemValid(itemData.ins_id, itemData.res_id)
        end
        return orig(self, widget, index)
    end
end

function F.hookWardrobeWearClicks()
    if _G.AddOutfitWearClickHooked then return end
    _G.AddOutfitWearClickHooked = true
    F.hookNotice()
    pcall(function()
        local avatarClass = require("client.slua.umg.Wardrobe.subtab_avatar")
        F.wrapWardrobeClick(avatarClass, "OnClickItem")
        F.wrapWardrobeClick(avatarClass, "ClickAvatarItem")
    end)
    pcall(function()
        local suitClass = require("client.slua.umg.Wardrobe.subtab_suit")
        F.wrapWardrobeClick(suitClass, "OnClickItem")
    end)
    pcall(function()
        local bagClass = require("client.slua.umg.Wardrobe.subtab_bag")
        F.wrapWardrobeClick(bagClass, "OnClickItem")
    end)
end

function F.hookAvatarValid()
    pcall(function()
        local path = "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent"
        local comp = require(path)
        if comp and comp.CheckItemValid then
            local o = comp.CheckItemValid
            comp.CheckItemValid = function(self, resID)
                if F.isInjectedRes(resID) then return true end
                return o(self, resID)
            end
        end
    end)
end

function F.isInRealMatch()
    local ok, r = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    return ok and r == true
end

function F.getLocalChar()
    local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GD then return nil end
    local char = GD.GetPlayerCharacter()
    if char and slua.isValid(char) then return char end
    return nil
end

-- Lobby skin apply: reuse existing visual-only skin functions on the lobby character.
local _lobbySkinWatcherStarted = false
local _lobbySkinWatcherBusy = false

function F.applyLobbySkins()
    if not RAPZHANG_MOD_SKIN_ALWAYS_ON then return false end
    if F.isInRealMatch and F.isInRealMatch() then return false end
    local char = F.getLocalChar and F.getLocalChar()
    if not char or not slua.isValid(char) then return false end
    if _lobbySkinWatcherBusy then return false end
    _lobbySkinWatcherBusy = true
    local ok = false
    pcall(function() ok = F.matchApplyAllSlots(char) or ok end)
    pcall(function() ok = F.matchApplyHat(char) or ok end)
    pcall(function() ok = F.matchApplyFaceWear(char) or ok end)
    pcall(function() ok = F.matchApplyWeaponSkin(char) or ok end)
    _lobbySkinWatcherBusy = false
    return ok
end

function F.startLobbySkinWatcher()
    -- Performance: apply once on enable/startup. Re-apply is event-driven by
    -- wardrobe/swipe/weapon hooks; do not poll the whole avatar every second.
    if _lobbySkinWatcherStarted then return end
    _lobbySkinWatcherStarted = true
    pcall(F.applyLobbySkins)
end
_G.RapzhangApplyLobbySkins = F.applyLobbySkins
_G.RapzhangStartLobbySkinWatcher = F.startLobbySkinWatcher

function F.getWAC(char)
    local w = char and char.GetCurrentWeapon and char:GetCurrentWeapon()
    if slua.isValid(w) and slua.isValid(w.WeaponAvatarComponent) then
        return w.WeaponAvatarComponent
    end
    return nil
end

function F.notify(msg)
    if not DEBUG then return end
    pcall(function() if ShowNotice then ShowNotice("[AddOutfit] " .. tostring(msg)) end end)
end

function F.getDesiredOutfit()
    local persisted = tonumber(PERSIST.configSlots and PERSIST.configSlots.outfit)
    if persisted and persisted > 0 then
        return persisted
    end
    if MATCH_CONFIG.outfitRes and MATCH_CONFIG.outfitRes > 0 then
        return MATCH_CONFIG.outfitRes
    end
    local wornSuitRes
    pcall(function()
        local _, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        wornSuitRes = tonumber(res)
    end)
    if wornSuitRes and wornSuitRes > 0 then return wornSuitRes end
    local tshirtWorn = false
    pcall(function()
        local ins = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isTshirtRes(r) end)
        tshirtWorn = ins ~= nil
    end)
    if tshirtWorn then return nil end
    F.syncBodyCacheFromLobby()
    local c = F.cache()
    return c.outfitRes
end

function F.matchApplyOutfit(char)
    local outfitRes = F.getDesiredOutfit()
    if not outfitRes then return true end
    if not F.isResourcesReady(outfitRes) then
        F.requestResourceDownload(outfitRes)
        return false
    end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local ok = F.setMakeSkin(comp, outfitRes, F.CUST_SLOT.ClothesEquipemtSlot, { allowPutOn = true })
    return ok
end

function F.getDesiredHat()
    if MATCH_CONFIG.hatRes and tonumber(MATCH_CONFIG.hatRes) > 0 then
        return tonumber(MATCH_CONFIG.hatRes)
    end
    F.syncHatCacheFromLobby()
    local h = F.cache().hatRes
    if h and tonumber(h) > 0 then return tonumber(h) end
    return tonumber(_G.AddOutfitLastLobbyHatRes) or nil
end

function F.ensureSkinDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    _G.skinIdCache = _G.skinIdCache or {}
    if not _G.skinIdCache[resID] then
        F.requestResourceDownload(resID)
        _G.skinIdCache[resID] = true
    end
end

function F.syncGlobalWearSkins()
    _G.CustSlotType = F.CUST_SLOT
    _G.skinIdCache = _G.skinIdCache or {}
    _G.HatSkin = tonumber(F.getDesiredHat()) or 0
    local outfit = F.getDesiredOutfit()
    _G.SuitSkin = tonumber(outfit)
        or tonumber(F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby))
        or 0
    _G.PantsSkin = tonumber(F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby)) or 0
    _G.ShoesSkin = tonumber(F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby)) or 0
    _G.GlovesSkin = tonumber(F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby)) or 0
    _G.MaskSkin = tonumber(F.getDesiredMask()) or 0
    _G.GlassSkin = tonumber(F.getDesiredGlass()) or 0
    _G.GliderSkin = tonumber(F.getDesiredGliderRes()) or 0
    _G.ParachuteSkin = tonumber(F.getDesiredParachuteRes()) or 0
end

function F.setMakeSkinAtIndex(comp, applyIdx, resID, slotID)
    resID = tonumber(resID)
    slotID = tonumber(slotID)
    applyIdx = tonumber(applyIdx)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotID or applyIdx == nil then
        return false
    end
    local changed = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local equipment = applyData:Get(applyIdx)
        if equipment and equipment.SlotID == slotID then
            local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
            if cur ~= resID then
                F.ensureSkinDownload(resID)
                equipment.ItemId = resID
                if equipment.ItemID ~= nil then equipment.ItemID = resID end
                applyData:Set(applyIdx, equipment)
                changed = true
            end
        end
    end)
    return changed
end

function F.applySlotSkinBatch(comp, entries, opts)
    opts = opts or {}
    if not comp or not slua.isValid(comp) or not entries then return false end
    local changed, anyOk = false, false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for _, e in ipairs(entries) do
            local itemId, slotId = tonumber(e[1]), tonumber(e[2])
            if itemId and itemId > 0 and slotId then
                F.ensureSkinDownload(itemId)
                for i = 0, num - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotId then
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur == itemId then
                            anyOk = true
                        elseif cur ~= itemId then
                            equipment.ItemId = itemId
                            if equipment.ItemID ~= nil then equipment.ItemID = itemId end
                            applyData:Set(i, equipment)
                            changed = true
                            anyOk = true
                        end
                        break
                    end
                end
            end
        end
        if (changed or opts.forceRep) and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return anyOk or changed
end

function F.setMakeSkin(comp, resID, slotID, opts)
    opts = opts or {}
    slotID, resID = tonumber(slotID), tonumber(resID)
    if not comp or not slua.isValid(comp) or not slotID or not resID or resID <= 0 then return false end
    local changed = false
    local already = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for i = 0, num - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur == resID then
                    already = true
                elseif cur ~= resID then
                    F.ensureSkinDownload(resID)
                    equipment.ItemId = resID
                    if equipment.ItemID ~= nil then equipment.ItemID = resID end
                    applyData:Set(i, equipment)
                    changed = true
                end
                break
            end
        end
        if changed and not opts.skipRep and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
        if opts.inAir and comp.PutOnCustomEquipmentByID then
            comp:PutOnCustomEquipmentByID(resID)
        end
    end)
    if already or changed then return true end
    if opts.allowPutOn and comp.PutOnCustomEquipmentByID then
        pcall(function() comp:PutOnCustomEquipmentByID(resID) end)
        return true
    end
    return false
end
F.setSlotSkin = F.setMakeSkin

_G.setMakeSkin = function(applyIdx, itemId, applyEquipSlot)
    local char = F.getLocalChar()
    if not char then return end
    local comp = F.getAvatarComp2(char)
    if not comp then return end
    if F.setMakeSkinAtIndex(comp, applyIdx, itemId, applyEquipSlot) then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
    end
end

function F.patchWearNetAvatar(comp, resID, slotName, noForceShow)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotName then return false end
    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local slot = EAvatarSlotType[slotName]
        if not slot then return end
        local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slot)
        if sync then
            sync.ItemID = resID
            if sync.FakeItemID ~= nil then sync.FakeItemID = resID end
            sync.OperationType = ESyncOperation.PutOn
            if comp.ChangeSlotSyncData then
                comp:ChangeSlotSyncData(sync)
                ok = true
            end
        end
        if not noForceShow and comp.SetAvatarVisibility then
            comp:SetAvatarVisibility(slot, true, true)
        end
    end)
    return ok
end

function F.patchHatNetAvatar(comp, hatRes)
    return F.patchWearNetAvatar(comp, hatRes, "EAvatarSlotType_HatEquipemtSlot")
end

function F.matchApplyWearItem(char, resID, slotID, label, opts)
    if not resID or resID <= 0 then return true end
    slotID = slotID or F.resToCustSlot(resID)
    if not slotID then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    opts = opts or {}
    opts.allowPutOn = true
    local ok = F.setMakeSkin(comp, resID, slotID, opts)
    return ok
end

function F.getDesiredMask()
    if MATCH_CONFIG.maskRes and tonumber(MATCH_CONFIG.maskRes) > 0 then
        return tonumber(MATCH_CONFIG.maskRes)
    end
    F.syncFaceCacheFromLobby()
    local m = F.cache().maskRes
    if m and tonumber(m) > 0 then return tonumber(m) end
    return tonumber(_G.AddOutfitLastLobbyMaskRes) or nil
end

function F.getDesiredGlass()
    if MATCH_CONFIG.glassRes and tonumber(MATCH_CONFIG.glassRes) > 0 then
        return tonumber(MATCH_CONFIG.glassRes)
    end
    F.syncFaceCacheFromLobby()
    local g = F.cache().glassRes
    if g and tonumber(g) > 0 then return tonumber(g) end
    return tonumber(_G.AddOutfitLastLobbyGlassRes) or nil
end

function F.matchApplyFaceWear(char)
    local maskRes = F.getDesiredMask()
    local glassRes = F.getDesiredGlass()
    if (not maskRes or maskRes <= 0) and (not glassRes or glassRes <= 0) then
        return true
    end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local net = comp.NetAvatarData
        local applyData = net and net.SlotSyncData

        local function forceApplySlot(resID, slotID, slotNameStr)
            if not resID or resID <= 0 then return end
            
            local slotEnum = EAvatarSlotType and EAvatarSlotType[slotNameStr]
            local needRep = false
            
            -- 1. OVERWRITE NETWORK DATA (Prevent desync)
            if applyData and slua.isValid(applyData) then
                local found = false
                for i = 0, applyData:Num() - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotID then
                        found = true
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur ~= resID then
                            F.ensureSkinDownload(resID)
                            equipment.ItemId = resID
                            if equipment.ItemID ~= nil then equipment.ItemID = resID end
                            if equipment.FakeItemID ~= nil then equipment.FakeItemID = resID end
                            applyData:Set(i, equipment)
                            needRep = true
                        end
                        break
                    end
                end
                
                if not found then
                    F.ensureSkinDownload(resID)
                    local entry = import("AvatarSyncData")()
                    entry.SlotID = slotID
                    entry.ItemId = resID
                    entry.ItemID = resID
                    entry.FakeItemID = resID
                    entry.OperationType = ESyncOperation.PutOn
                    applyData:Add(entry)
                    needRep = true
                end
            end

            -- [HIBERNATION LOGIC] - ABSOLUTE FPS OPTIMIZATION
            _G.FaceWearStateCache = _G.FaceWearStateCache or {}
            -- Create a unique ID for the current character to avoid collisions
            local cacheKey = tostring(comp) .. "_" .. tostring(slotID)

            if needRep or _G.FaceWearStateCache[cacheKey] ~= resID then
                -- First forced display / Or Skin ID changed -> Run Full C++
                if slotEnum then
                    if comp.CancelHideAvatarBySlot then comp:CancelHideAvatarBySlot(slotEnum) end
                    if comp.SetAvatarVisibility then comp:SetAvatarVisibility(slotEnum, true, true) end
                end
                if comp.PutOnCustomEquipmentByID then
                    comp:PutOnCustomEquipmentByID(resID)
                end
                
                -- Update cache so the next loop enters Hibernation
                _G.FaceWearStateCache[cacheKey] = resID
                ok = true -- Set flag to call OnRep_BodySlotStateChanged (redraw Mesh)
            else
                -- HIBERNATION STATE: Data correct, 3D Mesh rendered.
                -- Only run lightweight CancelHide to prevent the game auto-hiding when picking up Helmet (1,2,3).
                -- Skip re-rendering Mesh to avoid FPS drops.
                if slotEnum and comp.CancelHideAvatarBySlot then 
                    comp:CancelHideAvatarBySlot(slotEnum) 
                end
            end
        end

        -- Force-apply Mask
        forceApplySlot(maskRes, F.CUST_SLOT.FaceEquipemtSlot, "EAvatarSlotType_FaceEquipemtSlot")
        -- Force-apply Glasses
        forceApplySlot(glassRes, F.CUST_SLOT.GlassEquipemtSlot, "EAvatarSlotType_GlassEquipemtSlot")
        
        -- Update 3D visuals ONLY WHEN EXITING HIBERNATION (when necessary)
        if ok and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return ok
end

function F.getDesiredWear(configKey, cacheResKey, globalKey, syncFn)
    local persistKey = cacheResKey and cacheResKey:gsub("Res$", "")
    if persistKey and PERSIST.configSlots then
        local pr = tonumber(PERSIST.configSlots[persistKey])
        if pr and pr > 0 then return pr end
    end
    local fixed = MATCH_CONFIG[configKey] and tonumber(MATCH_CONFIG[configKey])
    if fixed and fixed > 0 then return fixed end
    if syncFn then syncFn() end
    local v = F.cache()[cacheResKey]
    if v and tonumber(v) > 0 then return tonumber(v) end
    return tonumber(_G[globalKey]) or nil
end

local EQUIP_APPLY = { lastBagWrite = 0, lastHelmetWrite = 0 }

function F.levelSkinID(baseSkin, level)
    level = tonumber(level) or 1
    if level < 1 then level = 1 end
    local mapped = 0
    pcall(function()
        local t = CDataTable.GetTableData("BackpackMapping", baseSkin)
        if t then
            if level <= 1 then mapped = tonumber(t.SkinItemIDLv1) or 0
            elseif level == 2 then mapped = tonumber(t.SkinItemIDLv2) or 0
            else mapped = tonumber(t.SkinItemIDLv3) or 0 end
        end
    end)
    if mapped > 0 then return mapped end
    return baseSkin + (level - 1) * 1000
end

function F.applyEquipSkinToComp(comp, bagRes, helmetRes)
    bagRes, helmetRes = tonumber(bagRes) or 0, tonumber(helmetRes) or 0
    local slotOk = { bag = bagRes <= 0, helmet = helmetRes <= 0 }
    if not comp or not slua.isValid(comp) then return slotOk.bag, slotOk.helmet, false end

    local EAvatarSlotType, BackpackUtils
    pcall(function() EAvatarSlotType = import("EAvatarSlotType") end)
    pcall(function() BackpackUtils = import("BackpackUtils") end)

    local function doSlot(key, res, slotName, fallbackSlot, levelFn, lastKey)
        if res <= 0 then slotOk[key] = true; return end
        local slotEnum = EAvatarSlotType and EAvatarSlotType[slotName] or fallbackSlot
        if not slotEnum then slotOk[key] = false; return end

        local callOk, done, target = pcall(function()
            local sync, syncArray, syncIndex
            if comp.GetSlotSyncData then
                local ok, value = pcall(function() return comp:GetSlotSyncData(slotEnum) end)
                if ok then sync = value end
            end
            if not sync then
                local net = comp.NetAvatarData
                local arr = net and net.SlotSyncData
                if arr and slua.isValid(arr) then
                    for i = 0, arr:Num() - 1 do
                        local entry = arr:Get(i)
                        if entry and (tonumber(entry.SlotID) == tonumber(slotEnum) or entry.SlotID == slotEnum) then
                            sync, syncArray, syncIndex = entry, arr, i
                            break
                        end
                    end
                end
            end

            local current = sync and (tonumber(sync.ItemID) or tonumber(sync.ItemId) or 0) or 0
            local additional = sync and tonumber(sync.AdditionalItemID) or 0
            local level = 1
            if type(levelFn) == "function" then
                local levelOk, value = pcall(levelFn, additional > 0 and additional or current)
                if levelOk then level = tonumber(value) or 1 end
            end
            if level < 1 then level = 1 end
            local targetID = F.levelSkinID(res, level)
            if targetID <= 0 then return false, targetID end
            pcall(F.ensureSkinDownload, targetID)
            if current == targetID then return true, targetID end

            if sync then
                local writeOk, writeResult = pcall(function()
                    local wroteID = false
                    if sync.ItemID ~= nil then sync.ItemID = targetID; wroteID = true end
                    if sync.ItemId ~= nil then sync.ItemId = targetID; wroteID = true end
                    if not wroteID then sync.ItemID = targetID end
                    if sync.FakeItemID ~= nil then sync.FakeItemID = targetID end
                    if comp.ChangeSlotSyncData then
                        local result = comp:ChangeSlotSyncData(sync)
                        if result == false then return false end
                    elseif syncArray and syncIndex ~= nil then
                        syncArray:Set(syncIndex, sync)
                    else
                        return false
                    end
                    pcall(function()
                        if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
                    end)
                    return true
                end)
                if writeOk and writeResult ~= false then return true, targetID end
                return false, targetID
            end

            if comp.PutOnCustomEquipmentByID then
                local putOk, putResult = pcall(function() return comp:PutOnCustomEquipmentByID(targetID) end)
                return putOk and putResult ~= false, targetID
            end
            return false, targetID
        end)

        slotOk[key] = callOk and done == true
        if slotOk[key] and target then EQUIP_APPLY[lastKey] = target end
    end

    doSlot("bag", bagRes, "EAvatarSlotType_BackpackEquipemtSlot",
        F.CUST_SLOT.BackpackEquipemtSlot,
        BackpackUtils and BackpackUtils.GetEquipmentBagLevel, "lastBagWrite")
    doSlot("helmet", helmetRes, "EAvatarSlotType_HelmetEquipemtSlot",
        F.CUST_SLOT.HelmetEquipemtSlot,
        BackpackUtils and BackpackUtils.GetEquipmentHelmetLevel, "lastHelmetWrite")
    return slotOk.bag, slotOk.helmet, slotOk.bag and slotOk.helmet
end

function F.matchApplyEquipmentSkin(char, bagRes, helmetRes)
    bagRes = tonumber(bagRes) or 0
    helmetRes = tonumber(helmetRes) or 0
    if bagRes <= 0 and helmetRes <= 0 then return true end
    if not char or not slua.isValid(char) then return false end
    local comp
    pcall(function()
        local bpComp = char.CharacterAvatarComp2_BP
        if bpComp and slua.isValid(bpComp) then comp = bpComp end
    end)
    if not slua.isValid(comp) then comp = F.getAvatarComp2(char) end
    if not slua.isValid(comp) then return false end
    local bagOk, helmetOk = F.applyEquipSkinToComp(comp, bagRes, helmetRes)
    return bagOk and helmetOk
end

local EQUIP_RETRY = { serial = 0 }
function F.scheduleEquipmentSkinApply(char)
    EQUIP_RETRY.serial = EQUIP_RETRY.serial + 1
    local serial, attempts = EQUIP_RETRY.serial, 0
    local function retry()
        if serial ~= EQUIP_RETRY.serial then return end
        attempts = attempts + 1
        local current = F.getLocalChar and F.getLocalChar() or char
        local bagRes = tonumber(F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)) or 0
        local helmetRes = tonumber(F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)) or 0
        if bagRes <= 0 and helmetRes <= 0 then return end
        local applied = current and slua.isValid(current) and F.matchApplyEquipmentSkin(current, bagRes, helmetRes)
        if not applied and attempts < 12 then F.later(0.35, retry) end
    end
    F.later(0.15, retry)
    return true
end

local _equipLevelTimer = nil
local _equipLevelTimerOwner = nil
local _equipLevelMatchSeen = false
local _equipLevelWaitTicks = 0
function F.stopEquipmentSkinWatcher()
    if _equipLevelTimer and _equipLevelTimerOwner and slua.isValid(_equipLevelTimerOwner) then
        pcall(function()
            if _equipLevelTimerOwner.RemoveGameTimer then
                _equipLevelTimerOwner:RemoveGameTimer(_equipLevelTimer)
            end
        end)
    end
    _equipLevelTimer = nil
    _equipLevelTimerOwner = nil
    _equipLevelMatchSeen = false
    _equipLevelWaitTicks = 0
end

function F.startEquipmentSkinWatcher(char)
    if _equipLevelTimer then return true end
    if not char or not slua.isValid(char) or not char.AddGameTimer then return false end
    _equipLevelTimerOwner = char
    _equipLevelMatchSeen = F.isInRealMatch and F.isInRealMatch() or false
    _equipLevelWaitTicks = 0
    local ok, timer = pcall(function()
        return char:AddGameTimer(1.0, true, function()
            local current = F.getLocalChar and F.getLocalChar() or _equipLevelTimerOwner
            if not current or not slua.isValid(current) then
                F.stopEquipmentSkinWatcher()
                return
            end
            if F.isInRealMatch and F.isInRealMatch() then
                _equipLevelMatchSeen = true
                local bagRes = tonumber(F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)) or 0
                local helmetRes = tonumber(F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)) or 0
                if bagRes > 0 or helmetRes > 0 then
                    pcall(F.matchApplyEquipmentSkin, current, bagRes, helmetRes)
                end
            else
                _equipLevelWaitTicks = _equipLevelWaitTicks + 1
                if _equipLevelMatchSeen or _equipLevelWaitTicks >= 45 then
                    F.stopEquipmentSkinWatcher()
                end
            end
        end)
    end)
    if ok then
        _equipLevelTimer = timer
        return true
    end
    _equipLevelTimerOwner = nil
    return false
end

function F.hookEquipmentRectify()
    _G.AddOutfitEquipRectifyFn = function(self)
        pcall(function()
            if self.IsLobbyActor and self:IsLobbyActor() then return end
            if not (self.IsSelf and self:IsSelf()) then return end
            local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
            local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
            if (tonumber(bagRes) or 0) <= 0 and (tonumber(helmetRes) or 0) <= 0 then return end
            local bagOk, helmetOk = F.applyEquipSkinToComp(self, bagRes, helmetRes)
            if not bagOk or not helmetOk then pcall(F.scheduleEquipmentSkinApply) end
        end)
    end
    pcall(function()
        local MCAC = require("GameLua.Mod.TPlan.Component.MetroCharacterAvatarComponent")
        if MCAC._AddOutfitRectifyHooked then return end
        MCAC._AddOutfitRectifyHooked = true
        local o = MCAC.ProcessClientAvatarRectify
        MCAC.ProcessClientAvatarRectify = function(self)
            o(self)
            if _G.AddOutfitEquipRectifyFn then _G.AddOutfitEquipRectifyFn(self) end
        end
    end)
end

function F.applyAirborneSlots(char, forceInAir)
    local comp = F.getAvatarComp2(char)
    if not comp or not slua.isValid(comp) then return false end
    pcall(function() F.syncAirborneToDataMgr() end)
    local inAir = forceInAir == true or F.isCharacterAirborne(char)
    local any = false
    local paraRes = F.getDesiredParachuteRes()
    if paraRes and paraRes > 0 then
        any = true
        if not F.isResourcesReady(paraRes) then F.requestResourceDownload(paraRes) end
        F.setMakeSkin(comp, paraRes, F.CUST_SLOT.ParachuteEquipemtSlot, { inAir = inAir })
    end
    local gliderRes = F.getDesiredGliderRes()
    if gliderRes and gliderRes > 0 then
        any = true
        if not F.isResourcesReady(gliderRes) then F.requestResourceDownload(gliderRes) end
        F.setMakeSkin(comp, gliderRes, F.CUST_SLOT.GlideEquipemtSlot, { inAir = inAir })
    end
    return any
end

function F.matchApplyBodyWear(char)
    local pieces = {}
    if not F.getDesiredOutfit() then
        pieces[#pieces + 1] = {
            F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby),
            F.CUST_SLOT.ClothesEquipemtSlot, "تيشرت",
        }
    end
    pieces[#pieces + 1] = { F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.PantsEquipemtSlot, "سروال" }
    pieces[#pieces + 1] = { F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.ShoesEquipemtSlot, "حذاء" }
    pieces[#pieces + 1] = { F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.HandEffectEquipemtSlot, "قفازات" }
    local any, okAll = false, true
    for _, p in ipairs(pieces) do
        local res, slot, label = p[1], p[2], p[3]
        if res and res > 0 then
            any = true
            okAll = F.matchApplyWearItem(char, res, slot, label) and okAll
        end
    end
    local anyAir = F.applyAirborneSlots(char, false)
    if anyAir then any = true end
    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        any = true
        okAll = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) and okAll
    end
    return not any or okAll
end

function F.matchApplyAllSlots(char)
    if not char then return false end
    F.syncGlobalWearSkins()
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local entries = {}
    local function add(skin, slot)
        skin = tonumber(skin)
        if skin and skin > 0 and slot then entries[#entries + 1] = { skin, slot } end
    end
    add(_G.HatSkin, F.CUST_SLOT.HatEquipemtSlot)
    add(_G.SuitSkin, F.CUST_SLOT.ClothesEquipemtSlot)
    add(_G.PantsSkin, F.CUST_SLOT.PantsEquipemtSlot)
    add(_G.ShoesSkin, F.CUST_SLOT.ShoesEquipemtSlot)
    add(_G.GlovesSkin, F.CUST_SLOT.HandEffectEquipemtSlot)
    add(_G.MaskSkin, F.CUST_SLOT.FaceEquipemtSlot)
    add(_G.GlassSkin, F.CUST_SLOT.GlassEquipemtSlot)

    local ok = false
    if #entries > 0 then
        ok = F.applySlotSkinBatch(comp, entries, { forceRep = true })
        if not ok then
            for _, e in ipairs(entries) do
                if F.setMakeSkin(comp, e[1], e[2], { allowPutOn = true }) then ok = true end
            end
        end
    end

    F.applyAirborneSlots(char, false)

    pcall(F.applyThrowObjectSkins)
    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    local equipmentOk = true
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        equipmentOk = F.matchApplyEquipmentSkin(char, bagRes, helmetRes)
    end

    return (ok or #entries == 0) and equipmentOk
end

function F.matchApplyHat(char)
    local hatRes = tonumber(F.getDesiredHat())
    if not hatRes or hatRes <= 0 then return true end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local slotID = F.CUST_SLOT.HatEquipemtSlot
    local ok = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local found = false
        for i = 0, applyData:Num() - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                found = true
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur ~= hatRes then
                    F.ensureSkinDownload(hatRes)
                    equipment.ItemId = hatRes
                    if equipment.ItemID ~= nil then equipment.ItemID = hatRes end
                    if equipment.FakeItemID ~= nil then equipment.FakeItemID = hatRes end
                    applyData:Set(i, equipment)
                end
                ok = true
                break
            end
        end
        if not found then
            F.ensureSkinDownload(hatRes)
            local ESyncOperation = import("ESyncOperation")
            local entry = import("AvatarSyncData")()
            entry.SlotID = slotID
            entry.ItemId = hatRes
            entry.ItemID = hatRes
            entry.FakeItemID = hatRes
            entry.OperationType = ESyncOperation.PutOn
            applyData:Add(entry)
            ok = true
        end
        
    end)
    return ok
end

local _avatarItemsRegistered = false

function F.getDesiredWeaponSkins()
    if PERF.desiredSkins then return PERF.desiredSkins end
    F.syncWeaponCacheFromLobby()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then seen[res] = true; out[#out+1] = res end
    end
    for wid, w in pairs(F.cache().weapons) do
        if wid ~= MELEE_ID and w.resID then add(w.resID) end
    end
    if not PERSIST.weaponConfigLoaded and MATCH_CONFIG.weaponSkins then
        for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
    end
    PERF.desiredSkins = out
    return out
end

function F._cacheSkinTarget(weaponResID, skin)
    if skin and skin > 0 then PERF.skinTarget[weaponResID] = skin else PERF.skinTarget[weaponResID] = 0 end
    return skin
end

local GUN_MASTER_SYN_SLOT = 7

function F.findSkinSlotInSynData(weapon)
    if not slua.isValid(weapon) then return GUN_MASTER_SYN_SLOT, 0 end
    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return GUN_MASTER_SYN_SLOT, 0 end
    local count = 0
    pcall(function() count = arr:Num() end)
    for i = 0, math.min(count - 1, 15) do
        local ok2, att = pcall(function() return arr:Get(i) end)
        if ok2 and att then
            local ok3, defRef = pcall(slua.IndexReference, att, "defineID")
            if ok3 and defRef then
                local tid = 0
                pcall(function() tid = tonumber(defRef.TypeSpecificID) or 0 end)
                if tid >= 1000000 then
                    return i, tid
                end
            end
        end
    end
    return GUN_MASTER_SYN_SLOT, 0
end

function F.resolveWeaponTypeID(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return 0 end
    local found = 0
    pcall(function()
        local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
        if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
    end)
    if found > 0 then return found end
    pcall(function()
        local ic = CDataTable.GetTableData("Item", weaponResID)
        if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
    end)
    return found > 0 and found or weaponResID
end

function F.findTargetSkinForWeaponRes(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return nil end
    local cached = PERF.skinTarget[weaponResID]
    if cached ~= nil then return cached == 0 and nil or cached end

    local memSkin = F.getMatchWeaponSkin(weaponResID)
    if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        memSkin = F.getMatchWeaponSkin(typeID)
        if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    end

    if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[weaponResID] then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponResID])
        if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
    end

    for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
        local wid = F.weaponIdFromSkin(skinRes)
        if wid and tonumber(wid) == weaponResID then return F._cacheSkinTarget(weaponResID, skinRes) end
    end

    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[typeID] then
            local fixed = tonumber(MATCH_CONFIG.weaponSkins[typeID])
            if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
        end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local wid = F.weaponIdFromSkin(skinRes)
            if wid and tonumber(wid) == typeID then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    local avatarMatch = nil
    pcall(function()
        local AU = import("AvatarUtils")
        local weaponBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(weaponResID), false)
        if not weaponBase or weaponBase <= 0 then return end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local skinBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(skinRes), false)
            if skinBase and skinBase > 0 and skinBase == weaponBase then
                avatarMatch = skinRes
                return
            end
        end
    end)
    if avatarMatch then return F._cacheSkinTarget(weaponResID, avatarMatch) end

    local c = F.cfg(weaponResID)
    local st = F.subType(c)
    if st and GUN_SUB[st] and MATCH_CONFIG.weaponSkins then
        for _, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            local skinWid = F.weaponIdFromSkin(skinRes)
            if skinWid then
                local sc = F.cfg(tonumber(skinWid))
                if sc and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
            end
            local sc = F.cfg(skinRes)
            if sc and GUN_SUB[F.subType(sc)] and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    PERF.skinTarget[weaponResID] = 0
    return nil
end

function F.getSynMasterSkinID(weapon)
    if not slua.isValid(weapon) then return 0 end
    local id = 0
    pcall(function()
        local slot, tid = F.findSkinSlotInSynData(weapon)
        id = tid
        if id == 0 then
            local arr = weapon.synData
            if not arr or not slua.isValid(arr) then return end
            local att = arr:Get(GUN_MASTER_SYN_SLOT)
            if not att then return end
            id = slua.IndexReference(att, "defineID").TypeSpecificID or 0
        end
    end)
    return id
end

_G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
_G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}

function F.buildSkinMappings()
    if not PERF.mappingsDirty then return end
    F.syncWeaponCacheFromLobby()
    PERF.mappingsDirty = false
    local m = _G.AddOutfitSkinIdMappings
    for k in pairs(m) do m[k] = nil end
    for wid, w in pairs(F.cache().weapons) do
        wid = tonumber(wid)
        if wid and w.resID and w.resID > 0 then
            m[wid] = { tonumber(w.resID) }
        end
    end
    if not PERSIST.weaponConfigLoaded and MATCH_CONFIG.weaponSkins then
        for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            weaponKey = tonumber(weaponKey)
            skinRes = tonumber(skinRes)
            if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                m[weaponKey] = { skinRes }
            end
        end
    end
end

function F.get_skin_id(currentGunId, maxIt)
    currentGunId = tonumber(currentGunId) or 0
    maxIt = tonumber(maxIt) or 0
    if currentGunId <= 0 and maxIt <= 0 then return 0 end
    F.buildSkinMappings()
    if maxIt > 0 then
        local fromMem = F.getMatchWeaponSkin(maxIt)
        if fromMem then return fromMem end
    end
    local fromMem2 = F.getMatchWeaponSkin(F.resolveWeaponTypeID(currentGunId))
    if fromMem2 then return fromMem2 end
    local m = _G.AddOutfitSkinIdMappings
    if maxIt > 0 and m[maxIt] and m[maxIt][1] then return tonumber(m[maxIt][1]) end
    local list = m[currentGunId]
    if list and list[1] then return tonumber(list[1]) end
    -- No configured entry means this weapon slot is intentionally empty.
    -- Never borrow a skin from another weapon/type or use the base ID as a
    -- fake skin target.
    return 0
end

function F.applyThrowObjectSkins()
    if F._applyingThrowObjects then return false end
    local cch = F.cache()
    local pc = F.getPC and F.getPC() or nil
    if not pc or not slua.isValid(pc) then return false end
    local signatureParts = {}
    for st, info in pairs(cch.throwObjects or {}) do
        local res = info and tonumber(info.resID)
        if THROW_SUBS[tonumber(st)] and res and res > 0 then
            signatureParts[#signatureParts + 1] = tostring(tonumber(st)) .. ":" .. tostring(res)
        end
    end
    table.sort(signatureParts)
    if #signatureParts == 0 then return false end
    local heldWeaponID = 0
    pcall(function()
        local char = F.getLocalChar and F.getLocalChar() or nil
        local weapon = char and char.GetCurrentWeapon and char:GetCurrentWeapon() or nil
        if slua.isValid(weapon) then heldWeaponID = tonumber(weapon.GetWeaponID and weapon:GetWeaponID()) or 0 end
    end)
    local signature = tostring(pc) .. "|" .. tostring(heldWeaponID) .. "|" .. table.concat(signatureParts, ",")
    if F._throwAppliedSignature == signature then return false end
    local applied = false
    for st, info in pairs(cch.throwObjects or {}) do
        st = tonumber(st)
        local res = info and tonumber(info.resID)
        local key = st and THROW_AVATAR_KEYS[THROW_SUBS[st]]
        if key and res and res > 0 then
            pcall(function()
                if pc.InitialConsumableAvatar then pc.InitialConsumableAvatar[key] = res end
                applied = true
            end)
        end
    end
    if not applied then return false end
    F._throwAppliedSignature = signature
    F._applyingThrowObjects = true
    pcall(function() if pc.InitGrenadeAvatarList then pc:InitGrenadeAvatarList(false) end end)
    for st, info in pairs(cch.throwObjects or {}) do
        local res = info and tonumber(info.resID)
        if THROW_SUBS[tonumber(st)] and res and res > 0 and pc.AddToGrenadeAvatarItemList then
            pcall(function() pc:AddToGrenadeAvatarItemList(res) end)
        end
    end
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    F._applyingThrowObjects = false
    -- Force a held throwable to rebuild its cosmetic mesh so its skin-specific
    -- inspect/throw animation and visual state are refreshed together.
    pcall(function()
        local char = F.getLocalChar and F.getLocalChar() or nil
        local weapon = char and char.GetCurrentWeapon and char:GetCurrentWeapon() or nil
        if not slua.isValid(weapon) then return end
        local wid = tonumber(weapon.GetWeaponID and weapon:GetWeaponID()) or 0
        local st = THROW_WEAPON_TO_SUB[wid]
        local info = st and cch.throwObjects[st]
        if not info or not info.resID then return end
        local comp = weapon.GrenadeAvatarComponent_BP
        if slua.isValid(comp) and comp.ChangeItemAvatar then comp:ChangeItemAvatar(info.resID, false) end
        if weapon.DelayHandleAvatarMeshChanged then weapon:DelayHandleAvatarMeshChanged() end
        if weapon.AddGameTimer then
            weapon:AddGameTimer(0.1, false, function()
                pcall(function()
                    if slua.isValid(weapon) and slua.isValid(weapon.GrenadeAvatarComponent_BP) then
                        weapon.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                    end
                end)
            end)
        end
    end)
    return true
end

-- ============================================================================
-- PULIHKAN SKIN GRENADE KE FASHION BAG
--
-- fashionbag_data menyimpan pilihan per subtipe (612 shoulei, 613 smoke,
-- 614 stun, 615 burn) di bag yang sedang dipakai. Setelah relogin / ganti
-- bag, slot itu bisa kosong lagi karena server tidak pernah menerima item
-- sintetis. Fungsi ini mengisi slot kosong dari config tersimpan, dan kalau
-- server ternyata sudah punya skin asli di slot itu, cache lokal disamakan
-- dengan nilai server supaya grid dan bag tidak berbeda.
-- ============================================================================
function F.reapplyThrowObjectBag()
    local cch = F.cache()
    local changed = false
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local idx = tonumber(fbd:GetFashionBagUseIndex())
        if not idx then return end
        -- Jangan menyentuh bag yang belum dimuat: GetThrowObjectSkin akan
        -- mengindeks throw_object_list milik bag kosong.
        local bag = fbd.GetFashionBag and fbd:GetFashionBag(idx) or nil
        if not bag then return end
        bag.throw_object_list = bag.throw_object_list or {}
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        for st, info in pairs(cch.throwObjects or {}) do
            st = tonumber(st)
            local res = info and tonumber(info.resID)
            if THROW_SUBS[st] and res and res > 0 then
                local cur = tonumber(fbd:GetThrowObjectSkin(st, idx)) or 0
                if cur == 0 then
                    local ins = tonumber(info.insID)
                    if not ins or ins <= 0 then
                        ins = tonumber(R.resToIns[res]) or tonumber(F.catalogIns(res)) or 0
                    end
                    if ins > 0 then
                        fbd:SetThrowObjectSkin(st, ins, idx)
                        info.insID = ins
                        PERSIST.configThrowObjects = PERSIST.configThrowObjects or {}
                        PERSIST.configThrowObjects[st] = res
                        changed = true
                    end
                elseif cur ~= tonumber(info.insID) then
                    -- Bag server menang. Ambil resID aslinya supaya config
                    -- tersimpan tidak menunjuk item yang tidak terpasang.
                    local d = wd:GetHallDepotItemDataByInsID(cur)
                    local serverRes = d and tonumber(d.resID or d.res_id)
                    if serverRes and serverRes > 0 then
                        info.insID = cur
                        info.resID = serverRes
                        PERSIST.configThrowObjects = PERSIST.configThrowObjects or {}
                        PERSIST.configThrowObjects[st] = serverRes
                        R.resToIns[serverRes], R.insToRes[cur] = cur, serverRes
                        changed = true
                    end
                end
            end
        end
    end)
    if changed then
        pcall(F.persistMarkDirty)
        pcall(F.applyThrowObjectSkins)
    end
    return changed
end

function F.hookThrowObjects()
    pcall(function()
        local PCB = require("GameLua.GameCore.Framework.PlayerControllerBase")
        local impl = PCB and (PCB.__inner_impl or PCB)
        if impl and not impl._AddOutfitThrowInitHooked and impl.InitGrenadeAvatarList then
            impl._AddOutfitThrowInitHooked = true
            local orig = impl.InitGrenadeAvatarList
            impl.InitGrenadeAvatarList = function(self, ...)
                if not F._applyingThrowObjects then F._throwAppliedSignature = nil end
                local result = orig(self, ...)
                pcall(function()
                    if not F._applyingThrowObjects and F.getPC and F.getPC() == self then
                        F.applyThrowObjectSkins()
                    end
                end)
                return result
            end
        end
    end)
    pcall(function()
        local AvatarDataUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
        if AvatarDataUtil and not AvatarDataUtil._AddOutfitThrowLookupHooked then
            local orig = AvatarDataUtil.TryGetGrenadeAvatarID
            if orig then
                AvatarDataUtil._AddOutfitThrowLookupHooked = true
                AvatarDataUtil.TryGetGrenadeAvatarID = function(pc, itemID)
                    local st = THROW_WEAPON_TO_SUB[tonumber(itemID)]
                    local info = st and F.cache().throwObjects[st]
                    if info and info.resID and F.getPC and F.getPC() == pc then return info.resID end
                    return orig(pc, itemID)
                end
            end
        end
    end)
    pcall(function()
        local ProjectileBase = require("GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.ProjectileBase")
        local impl = ProjectileBase and ProjectileBase.__inner_impl
        if not impl or impl._AddOutfitThrowProjectileHooked or not impl.UpdateGrenadeAvatar then return end
        impl._AddOutfitThrowProjectileHooked = true
        local origUpdate = impl.UpdateGrenadeAvatar
        impl.UpdateGrenadeAvatar = function(self)
            if self.bAuthority then return origUpdate(self) end
            local itemID
            pcall(function()
                if self.GetItemTypeID then itemID = tonumber(self:GetItemTypeID())
                elseif self.ItemDefineID then itemID = tonumber(self.ItemDefineID.TypeSpecificID) end
            end)
            local st = itemID and THROW_WEAPON_TO_SUB[itemID]
            local info = st and F.cache().throwObjects[st]
            if info and info.resID and info.resID > 0 and slua.isValid(self.GrenadeAvatarComponent_BP) then
                pcall(function() self.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false) end)
                return
            end
            return origUpdate(self)
        end
    end)
    return true
end
function F.applySkinToWeaponRef(CurWeapon)
    if not slua.isValid(CurWeapon) then return false end
    local AttachmentArray = CurWeapon.synData
    if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end

    local AttachmentData = AttachmentArray:Get(GUN_MASTER_SYN_SLOT)
    if not AttachmentData then return false end

    local current_gunid = 0
    pcall(function() current_gunid = slua.IndexReference(AttachmentData, "defineID").TypeSpecificID or 0 end)
    if not current_gunid or current_gunid <= 0 then return false end

    local MaxIt = 0
    pcall(function()
        if CurWeapon.GetWeaponID then MaxIt = CurWeapon:GetWeaponID() end
        if MaxIt <= 0 then MaxIt = CurWeapon:GetItemDefineID().TypeSpecificID end
    end)
    MaxIt = tonumber(MaxIt) or 0
    local configuredSkin = tonumber(F.get_skin_id(current_gunid, MaxIt)) or 0
    if MaxIt <= 0 then return false end
    -- Empty rapzhang_outfit slot: restore the real base weapon and do not
    -- attach any skin-specific parts.
    local tmp_id = configuredSkin > 0 and configuredSkin or MaxIt

    local attachmentChanged = false
    local attachKey = tostring(CurWeapon) .. ":" .. tostring(tmp_id)
    local appliedKeys = _G.RapzhangWeaponAttachmentAppliedKey
    if type(appliedKeys) ~= "table" then
        appliedKeys = {}
        _G.RapzhangWeaponAttachmentAppliedKey = appliedKeys
    end
    if configuredSkin > 0 and not appliedKeys[attachKey] then
        local ran = false
        pcall(function()
            if _G.RapzhangApplyWeaponAttachments then
                ran = true
                attachmentChanged = _G.RapzhangApplyWeaponAttachments(CurWeapon, tmp_id) == true
            end
        end)
        if ran then appliedKeys[attachKey] = true end
    end

    -- Connect attachments to the exact skin currently used by this weapon.
    -- The ownership bootstrap may run before the weapon has its final skin ID.
    local registered = _G.RapzhangWeaponAttachmentRegistered
    if type(registered) ~= "table" then
        registered = {}
        _G.RapzhangWeaponAttachmentRegistered = registered
    end
    if configuredSkin > 0 and not registered[tmp_id] and _G.RapzhangSyncWeaponAvatarOwnership then
        local ok = false
        pcall(function()
            ok = _G.RapzhangSyncWeaponAvatarOwnership(F.getPC(), { tmp_id }) == true
        end)
        if ok then registered[tmp_id] = true end
    end
    
    local changedAny = attachmentChanged

    -- LOGIC 1: GET THE ACTUAL DISPLAYED IMAGE ID
    local wac = CurWeapon.WeaponAvatarComponent
    local currentVisualID = 0
    if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end

    -- IF PRIMARY WEAPON IS NOT A VIP SKIN -> CHANGE DATA
    if currentVisualID ~= tmp_id then
        changedAny = true
        pcall(function()
            local defRef = slua.IndexReference(AttachmentData, "defineID")
            defRef.TypeSpecificID = tmp_id
            local c0 = F.cfg(tmp_id)
            if c0 and c0.ItemType and defRef.Type ~= nil then defRef.Type = c0.ItemType end
            AttachmentData.operationType = 0
            AttachmentArray:Set(GUN_MASTER_SYN_SLOT, AttachmentData)
        end)
    end

    -- LOGIC 2: Attachments are supplied by the official Rapzhang ownership
    -- manager during match bootstrap; no manual attachment IDs are used.

    -- LOGIC 3: Force game to redraw the in-hand Mesh
    if changedAny then
        pcall(function()
            if slua.isValid(wac) then
                -- If it's a newly picked-up gun, remove the old worn gun skin
                if currentVisualID ~= tmp_id then
                    if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(0) end
                    if wac.ClearMeshBySlot then wac:ClearMeshBySlot(0, true, true) end
                end
                
                if CurWeapon.DelayHandleAvatarMeshChanged then
                    CurWeapon:DelayHandleAvatarMeshChanged()
                end
                if wac.ReloadAllEquippedAvatar then
                    wac:ReloadAllEquippedAvatar(1) 
                end
            end
        end)
        if configuredSkin > 0 then
            _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
        else
            _G.AddOutfitLastAppliedSkin[MaxIt] = nil
        end
        return true
    end
    
    return false
end

function _G.equip_weapon_avatar(uCharacter)
    if not uCharacter or not slua.isValid(uCharacter) then return false end
    F.buildSkinMappings()
    local WeaponManager = uCharacter:GetWeaponManager()
    if not WeaponManager or not slua.isValid(WeaponManager) then return false end
    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
    if not uWeaponList or not slua.isValid(uWeaponList) then return false end

    local appliedAny = false
    for i = 0, uWeaponList:Num() - 1 do
        local CurWeapon = uWeaponList:Get(i)
        if slua.isValid(CurWeapon) and F.applySkinToWeaponRef(CurWeapon) then
            appliedAny = true
        end
    end
    return appliedAny
end

function F.equipWeaponAvatarSynData(char)
    return _G.equip_weapon_avatar(char)
end

F.applySkinToWeapon = F.applySkinToWeaponRef

function F.registerWeaponAvatarItems(char)
    local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
    if not slua.isValid(pc) then return false end
    local AU = import("AvatarUtils")
    local BU = import("BackpackUtils")
    local addedCount = 0

    for _, resID in ipairs(F.getDesiredWeaponSkins()) do
        local doneDirect = false
        pcall(function()
            if pc.AddWeaponAvatarItem then
                pc:AddWeaponAvatarItem(tonumber(resID))
                doneDirect = true
                addedCount = addedCount + 1
            end
        end)
        if not doneDirect then
            pcall(function()
                local skinBPID = BU.GetBPIDByResID(tonumber(resID))
                local arr = slua.Array(UEnums.EPropertyClass.Int)
                local parents = AU.GetWeaponAvatarParentIDList(skinBPID, arr, false)
                if parents and parents.Num and parents:Num() > 0 and pc.WeaponAvatarItemList then
                    for _, parentID in pairs(parents) do
                        pc.WeaponAvatarItemList:Add(parentID, skinBPID)
                    end
                    addedCount = addedCount + 1
                end
            end)
        end
    end

    if addedCount == 0 then return false end

    pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    return true
end

function F.reloadCurrentWeaponAvatar(char)
    pcall(function()
        local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
        if not slua.isValid(weapon) then return end
        local wac = weapon.WeaponAvatarComponent
        if slua.isValid(wac) then
            local ES = import("EWeaponAttachmentSocketType")
            pcall(function() wac:ClearMeshPathCacheBySlot(ES.MasterGun) end)
            pcall(function() wac:ClearMeshBySlot(ES.MasterGun, true, true) end)
        end
        if weapon.DelayHandleAvatarMeshChanged then
            weapon:DelayHandleAvatarMeshChanged()
        elseif slua.isValid(wac) and wac.ReloadAllEquippedAvatar then
            local ESlotDescDiff = import("ESlotDescDiff")
            wac:ReloadAllEquippedAvatar(ESlotDescDiff.MeshDiff)
        end
    end)
end

local _weaponDiagDone = false
local _weaponApplied = false
local _lastWeaponResID = 0
local _weaponSpawnHooked = false
function F.onWeaponLuaInit(_, _, weapon)
    if not weapon or not slua.isValid(weapon) then return end
    local char = F.getLocalChar()
    if not char then return end
    local owner = nil
    pcall(function()
        if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end
    end)
    if not slua.isValid(owner) or owner ~= char then return end
    pcall(function()
        char:AddGameTimer(0.15, false, function()
            local c = F.getLocalChar()
            if c and slua.isValid(weapon) then
                F.applySkinToWeapon(weapon)
                _weaponApplied = false
            end
        end)
    end)
end

function F.hookWeaponSpawn()
    if _weaponSpawnHooked then return end
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_PLAYEREVENT_WEAPON and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
            EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, onWeaponLuaInit)
            _weaponSpawnHooked = true
        end
    end)
end

function F.matchApplyWeaponSkin(char)
    -- Visual-only mode: do not inject entries into WeaponAvatarItemList.
    -- Keep the original inventory intact and apply skins only to live weapon visuals.
    local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
    if not slua.isValid(curWeapon) then return false end
    -- Melee uses native weapon ID 108 and is not part of the ordinary
    -- firearm desired-skin list. Apply it explicitly to the live inventory.
    pcall(function()
        local wm = char.GetWeaponManager and char:GetWeaponManager()
        local list = wm and wm.GetAllInventoryWeaponList and wm:GetAllInventoryWeaponList(false)
        if list and slua.isValid(list) then
            for i = 0, list:Num() - 1 do
                local weapon = list:Get(i)
                if slua.isValid(weapon) then
                    local wid = 0
                    pcall(function()
                        wid = tonumber(weapon:GetWeaponID()) or tonumber(weapon:GetItemDefineID().TypeSpecificID) or 0
                    end)
                    if wid == MELEE_ID then F.applySkinToWeapon(weapon) end
                end
            end
        end
    end)
    local currentVisualID = 0
    pcall(function()
        local wac = curWeapon.WeaponAvatarComponent
        if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end
    end)

    local curWeaponResID = 0
    pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
    local targetSkin = F.findTargetSkinForWeaponRes(curWeaponResID) or curWeaponResID

    local isVisualMatched = false
    if currentVisualID > 0 and currentVisualID == targetSkin then
        isVisualMatched = true
    end

    -- Performance: the match watcher performs the initial inventory apply.
    -- Weapon spawn/switch hooks handle later changes; never scan the full
    -- backpack on a 0.4s polling loop.

    -- REPORT COMPLETE: If the currently held gun is finished, lock the Engine's original thread.
    if isVisualMatched and not RAPZHANG_SKIN_ATTACHMENT_ALWAYS_ON then
        _weaponApplied = true
        return true
    end

    F.buildSkinMappings()
    local okSyn = F.applySkinToWeapon(curWeapon)

    return okSyn
end

local _matchTimer = nil
local _matchWearDone = false
local _matchBootstrapScheduled = false
local _matchCharKey = nil

function F.startMatchWatcher(char)
    pcall(F.startEquipmentSkinWatcher, char)
    if _matchTimer or PERF.matchActive then return end
    PERF.matchActive = true
    _matchCharKey = tostring(char)
    local skipWear = PERF.wearDoneThisMatch
    _matchWearDone = skipWear
    _avatarItemsRegistered = false
    _weaponDiagDone = false
    _weaponApplied = false
    _lastWeaponResID = 0
    local elapsed = 0

    _matchTimer = char:AddGameTimer(MATCH_TICK_SEC, true, function()
        elapsed = elapsed + MATCH_TICK_SEC
        local cur = F.getLocalChar()
        if not cur or not slua.isValid(cur) then return end

        if not _matchWearDone then
            _matchWearDone = F.matchApplyAllSlots(cur)
        end
        pcall(F.applyThrowObjectSkins)
        F.matchApplyHat(cur)
        F.matchApplyFaceWear(cur) -- [FIX VIP] Add continuous forced call for Glasses & Mask like Hat.
        if not _weaponApplied then
            F.matchApplyWeaponSkin(cur)
        end
        if F.isCharacterAirborne(cur) then
            F.applyAirborneSlots(cur, true)
        end

        if (_matchWearDone and _weaponApplied) or elapsed >= MATCH_MAX_SEC then
            if _matchWearDone then
                PERF.wearDoneThisMatch = true
            end
            if _matchTimer and cur.RemoveGameTimer then
                pcall(function() cur:RemoveGameTimer(_matchTimer) end)
            end
            _matchTimer = nil
            PERF.matchActive = false
        end
    end)
end

function F.stopMatchWatcher()
    pcall(F.stopEquipmentSkinWatcher)
    if _matchTimer then
        pcall(function()
            local char = F.getLocalChar()
            if char and char.RemoveGameTimer then char:RemoveGameTimer(_matchTimer) end
        end)
        _matchTimer = nil
    end
    PERF.matchActive = false
    PERF.wearDoneThisMatch = false
    PERF.lastBootstrapAt = 0
    _matchBootstrapScheduled = false
    _matchCharKey = nil
    _matchWearDone = false
    _avatarItemsRegistered = false
    _weaponApplied = false
    _weaponDiagDone = false
    _lastWeaponResID = 0
end

function F.hookAirborneCache()
    if _G.AddOutfitAirborneHooked then return end
    _G.AddOutfitAirborneHooked = true
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST, function()
                F.syncAirborneCacheFromLobby()
            end)
        end
    end)
end

function F.reapplyFromInventory()
    if _G.AddOutfitInventoryReapplyBusy then return false end
    _G.AddOutfitInventoryReapplyBusy = true
    local ok = pcall(function()
        -- Refresh the source cache first. Vehicle selections are maintained
        -- separately from normal avatar wear slots.
        F.syncVehicleCacheFromDataMgr()
        F.syncVehicleSlotsToDataMgr()

        if GameStatus and GameStatus.IsInLobbyOrMainCity
            and GameStatus.IsInLobbyOrMainCity() then
            F.reapplyLobbyEquipped()
        else
            local char = F.getLocalChar()
            if char and slua.isValid(char) then
                F.matchApplyAllSlots(char)
                F.matchApplyHat(char)
                F.matchApplyFaceWear(char)
                F.applyAirborneSlots(char, F.isCharacterAirborne(char))
            end
            F.applyVehicleSkinsToPC(F.getPC())
        end

        local vehicle = F.getCurrentVehicleForSkin()
        if vehicle and slua.isValid(vehicle) then
            F.autoApplyVehicleSkinOnEnter(vehicle)
        end
    end)
    _G.AddOutfitInventoryReapplyBusy = nil
    return ok
end

function F.hookPutOnRsp()
    if _G.AddOutfitPutOnRspHooked then return end
    _G.AddOutfitPutOnRspHooked = true
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.on_puton_rsp
        wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
            o(self, res, item, olditem, index, extra)
            if not item or not item.instid then return end
            local resID = tonumber(item.res_id)
            local insID = tonumber(item.instid)
            if not resID or not insID then return end
            local c = F.cfg(resID)
            local st = F.subType(c)
            if st == OUTFIT_SUB then
                F.saveEquip(resID, insID)
            elseif st == HAT_SUB or FACE_SUBS[st] or BODY_SUBS[st] or HELMET_SUBS[st]
                or st == PARACHUTE_SUB or F.isGlideRes(resID) or st == GLOVES_SUB then
                F.saveEquip(resID, insID)
            elseif F.isParachuteRes(resID) or F.isGlideRes(resID) then
                F.saveEquip(resID, insID)
            elseif HEAD_SUBS[st] then
                F.saveEquip(resID, insID)
            elseif GUN_SUB[st] then
                local wid = F.weaponIdFromSkin(resID)
                if wid then F.cacheWeaponSkinFromIns(wid, insID) end
            elseif st == MELEE_ID then
                F.cacheWeaponSkinFromIns(MELEE_ID, insID)
                local meleeKind = F.meleeKindFromRes(resID)
                if meleeKind then
                    PERSIST.configMelee = PERSIST.configMelee or {}
                    PERSIST.configMelee[meleeKind] = resID
                    F.persistMarkDirty()
                end
            elseif F.throwObjectSubtype(resID) then
                F.saveThrowObject(resID, insID)
            elseif F.isInjectedIns(insID) then
                F.saveEquip(resID, insID)
            end
            -- The inventory response is the synchronization point. Reapply
            -- immediately after the cache has been updated, including vehicle
            -- slots, without polling a JSON/config file.
            F.reapplyFromInventory()
        end
    end)
end

-- Pasang ulang semua hook wardrobe yang penting. Dipanggil dari InitData dan
-- dari loop auto-inject supaya modul yang belum siap saat script dimuat
-- (WardRobeHandler, logic_wardrobe_new, fashionbag_data) tetap ter-hook.
function F.ensureWardrobeHooks()
    if F.hookWardrobeData then pcall(F.hookWardrobeData) end
    if F.hookWardrobeGetData then pcall(F.hookWardrobeGetData) end
    if F.hookPageFilter then pcall(F.hookPageFilter) end
    if F.hookPutOn then pcall(F.hookPutOn) end
    if F.hookPutDown then pcall(F.hookPutDown) end
    if F.hookWardrobePutOnReq then pcall(F.hookWardrobePutOnReq) end
    if F.hookPutOnRsp then pcall(F.hookPutOnRsp) end
end

function F.hookLobbyWeaponCache()
    if _G.AddOutfitLobbyWeaponCacheHooked then return end
    _G.AddOutfitLobbyWeaponCacheHooked = true
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local oRsp = Arm.install_weapon_skin_rsp
        Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
            oRsp(client_data, errorCode, weapon_id, instanceID)
            if (errorCode == 0 or errorCode == NET_OK) and F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
        local oH = Arm.HandleWeaponSkinChange
        Arm.HandleWeaponSkinChange = function(client_data, weapon_id, instanceID)
            oH(client_data, weapon_id, instanceID)
            if F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.on_put_on_weapon_wear_rsp
        wgl.on_put_on_weapon_wear_rsp = function(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            o(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            if res == 0 or res == NET_OK then
                F.cacheWeaponSkinFromIns(weapon_id, new_skin_id)
            end
        end
    end)
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function(_, _, resOrFlag, weapon_id)
                weapon_id = tonumber(weapon_id)
                if weapon_id and weapon_id > 0 then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        local insID = tonumber(wgl:GetSkinIdByWeaponID(weapon_id)) or 0
                        if insID > 0 then F.cacheWeaponSkinFromIns(weapon_id, insID) end
                    end)
                elseif tonumber(resOrFlag) and tonumber(resOrFlag) > 100000 then
                    pcall(function()
                        local wid = F.weaponIdFromSkin(resOrFlag)
                        if wid then
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local ins = wd.GetWardrobeInsIdByResId and wd:GetWardrobeInsIdByResId(resOrFlag)
                            if ins and ins > 0 then F.cacheWeaponSkinFromIns(wid, ins) end
                        end
                    end)
                end
            end)
        end
    end)
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local oHeadReq = WRH.send_depot_set_head_show_req
        WRH.send_depot_set_head_show_req = function(insID)
            insID = tonumber(insID) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                if d and d.resID then
                    F.saveEquip(tonumber(d.resID), insID)
                end
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:SetHeadShow(insID)
                WRH.on_depot_set_head_show_rsp(NET_OK, insID)
                return
            end
            return oHeadReq(insID)
        end
        local oHead = WRH.on_depot_set_head_show_rsp
        WRH.on_depot_set_head_show_rsp = function(err_code, id)
            oHead(err_code, id)
            if err_code ~= 0 and err_code ~= NET_OK then return end
            id = tonumber(id) or 0
            if id <= 0 then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(id)
            if d and d.resID then
                local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
                if st == HAT_SUB or HELMET_SUBS[st] then
                    F.saveEquip(tonumber(d.resID), id)
                end
            end
        end
    end)
end

function F.hookWardrobePutOnReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPutOnReqHooked then return end
        wl._AddOutfitPutOnReqHooked = true
        local oReq = wl.wardrobe_puton_req
        wl.wardrobe_puton_req = function(self, insID, extra)
            insID = tonumber(insID)
            F.ensureDepotItemValid(insID)
            if F.tryLocalWearByIns(insID) then return end
            if insID and F.isInjectedIns(insID) then return end
            return oReq(self, insID, extra)
        end
        if not wl._AddOutfitPutOnDataHooked then
            wl._AddOutfitPutOnDataHooked = true
            local oData = wl.wardrobe_puton_data_req
            wl.wardrobe_puton_data_req = function(self, itemData)
                if itemData then
                    local insID = tonumber(itemData.ins_id or itemData.insID)
                    local resID = tonumber(itemData.res_id or itemData.resID)
                    F.clearItemExpire(itemData, insID, resID)
                    F.ensureDepotItemValid(insID, resID)
                end
                return oData(self, itemData)
            end
        end
    end)
end

local _bootstrapNotified = false

function F.bootstrapMatch(char)
    char = char or F.getLocalChar()
    if not char or not slua.isValid(char) then return false end
    if PERF.matchActive then return true end
    local now = os.clock()
    if (now - PERF.lastBootstrapAt) < BOOTSTRAP_COOLDOWN then return false end
    PERF.lastBootstrapAt = now
    _G.RapzhangWeaponAttachmentAppliedKey = {}
    pcall(F.hookThrowObjects)
    F.syncWeaponCacheFromLobby(true)
    F.applyPersistSlotsToCache()
    -- Do not prune armory lists here: an incomplete local mapping can make valid lobby inventory disappear.
    F.syncGlobalWearSkins()
    pcall(function()
        if _G.RapzhangSyncWeaponAvatarOwnership then
            _G.RapzhangSyncWeaponAvatarOwnership(F.getPC(), F.getDesiredWeaponSkins())
        end
    end)
    F.syncAirborneToDataMgr()
    pcall(function() F.applyAirborneSlots(char, F.isCharacterAirborne(char)) end)
    F.syncVehicleCacheFromDataMgr()
    F.syncVehicleSlotsToDataMgr()
    pcall(function() F.applyVehicleSkinsToPC(F.getPC()) end)
    F.startVehicleSkinTicker()
    pcall(function()
        local v = F.getMatchVehicle()
        if slua.isValid(v) then F.autoApplyVehicleSkinOnEnter(v) end
    end)
    _weaponApplied = false
    _weaponDiagDone = false
    _matchApplied = false
    if not _bootstrapNotified then
        _bootstrapNotified = true
    end
    F.startMatchWatcher(char)
    return true
end

function F.hookMatchAvatar()
    pcall(function()
        local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
        local o = CAC.OnAvatarAllMeshLoadedLua
        CAC.OnAvatarAllMeshLoadedLua = function(self)
            o(self)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                local char = F.getLocalChar()
                if not char or not slua.isValid(char) then return end
                -- A new match can arrive before the lobby event resets the
                -- old watcher. Detect a new/reused local avatar here.
                local charKey = tostring(char)
                if _matchCharKey and charKey ~= _matchCharKey then
                    F.stopMatchWatcher()
                elseif PERF.wearDoneThisMatch and not PERF.matchActive then
                    F.stopMatchWatcher()
                end
                if PERF.matchActive or _matchBootstrapScheduled then return end
                if char.AddGameTimer then
                    _matchBootstrapScheduled = true
                    char:AddGameTimer(0.5, false, function()
                        _matchBootstrapScheduled = false
                        local current = F.getLocalChar()
                        if current and slua.isValid(current) and not PERF.matchActive then
                            PERF.wearDoneThisMatch = false
                            F.bootstrapMatch(current)
                        end
                    end)
                end
            end)
        end
    end)
    pcall(function()
        local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
        local oLoad = WAC.OnWeaponAvatarLoadedLua
            WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
            oLoad(self, slotID, definedID)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                local char = F.getLocalChar()
                if not char then return end
                _weaponApplied = false
                if not PERF.matchActive then F.bootstrapMatch(char)
                elseif char.AddGameTimer then
                    char:AddGameTimer(0.25, false, function()
                        local c = F.getLocalChar()
                        if c then F.matchApplyWeaponSkin(c) end
                    end)
                end
            end)
        end
    end)
end

function F.hookVehicleInfoInit()
    pcall(function()
        if DataMgr._AddOutfitVehInfoHooked then return end
        DataMgr._AddOutfitVehInfoHooked = true
        local orig = DataMgr.InitVehicleInfo
        DataMgr.InitVehicleInfo = function(vehicle_info, vst_skin)
            vehicle_info = F.mergeInjectedIntoVehicleSlotList(vehicle_info)
            orig(vehicle_info, vst_skin)
            F.later(0.15, function()
                F.reapplyVehicleSlotsFromConfig()
                F.reapplyHallThemeFromConfig()
                LOBBY.reapplyDone = false
                LOBBY.reapplyScheduled = false
                F.scheduleLobbyReapplyOnce()
            end)
        end
    end)
end

function F.hookVehicleSkinDataInit()
    pcall(function()
        if DataMgr._AddOutfitVehSkinDataHooked then return end
        DataMgr._AddOutfitVehSkinDataHooked = true
        local origInit = DataMgr.InitVehicleSkinData
        DataMgr.InitVehicleSkinData = function(data)
            data = F.mergeInjectedVehicleSkinTable(data)
            origInit(data)
            F.later(0.1, function()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
            end)
        end
        local origUpd = DataMgr.UpdateVehicleSkin
        DataMgr.UpdateVehicleSkin = function(itemSubType, putOnId)
            origUpd(itemSubType, putOnId)
            if not _G.AddOutfitApplyingConfig and F.isInjectedIns(putOnId) then
                F.setLobbyVehicleManual(itemSubType, R.insToRes[putOnId], putOnId)
            end
        end
    end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        if HallThemeUtils._AddOutfitLobbyVehHooked then return end
        HallThemeUtils._AddOutfitLobbyVehHooked = true
        local orig = HallThemeUtils.ProcPutOnVehicle
        HallThemeUtils.ProcPutOnVehicle = function(putOnItem, bShowVehicle)
            orig(putOnItem, bShowVehicle)
            if not _G.AddOutfitApplyingConfig and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setLobbyVehicleManual(F.vehicleSubType(res or R.insToRes[ins]), res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookHallTheme()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        if HT._AddOutfitHallThemeHooked then return end
        HT._AddOutfitHallThemeHooked = true
        local orig = HT.ProcPutOnHallTheme
        HT.ProcPutOnHallTheme = function(putOnItem, putOffItem)
            orig(putOnItem, putOffItem)
            if not _G.AddOutfitApplyingTheme and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setHallThemeManual(res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookEnterGame()
    if _G.AddOutfitEnterGameHooked then return end
    _G.AddOutfitEnterGameHooked = true
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
                F.perfInvalidateLobby()
                -- A reconnect/new lobby reuses this Lua state. Clear the
                -- one-shot restore guards so saved outfit and accessory
                -- selections are applied again instead of being skipped.
                _G.AddOutfitLobbyRestored = false
                LOBBY.reapplyDone = false
                LOBBY.reapplyScheduled = false
                LOBBY.wardrobeRefreshed = false
                F.syncWeaponCacheFromLobby(true)
                F.reapplyVehicleSlotsFromConfig(true)
                F.reapplyHallThemeFromConfig(true)
                pcall(F.applyVehicleSkinsToPC)
                F.stopMatchWatcher()
                _bootstrapNotified = false
                F.later(1.0, function()
                    pcall(function()
                        if GameStatus and GameStatus.IsInLobbyOrMainCity
                            and GameStatus.IsInLobbyOrMainCity() then
                            F.persistLoadFromDisk()
                            F.persistApplyLoaded()
                            F.reapplyLobbyEquipped()
                            _G.AddOutfitLobbyRestored = true
                        end
                    end)
                end)
            end)
        end
    end)
end

function F.afterInjectApply(firstTime)
    F.mergeInjectedArmorySkins()
    -- Keep the original armory response intact; do not prune lobby inventory entries.
    pcall(F.reapplyThrowObjectBag)
    if firstTime then
        F.refreshWardrobeOnce()
        F.persistApplyLoaded()
        -- Do not wait for the scheduled lobby/social refresh for the suit.
        -- Weapon and suit now share the same first-load application phase.
        F.applyPersistedSuitImmediate()
        F.syncLobbyVehicleResFromIns()
        F.reapplyVehicleSlotsFromConfig(true)
        F.reapplyHallThemeFromConfig(true)
        F.reapplyWeaponsFromConfig()
        F.scheduleLobbyReapplyOnce()
    else
        F.reapplyWeaponsFromConfig()
    end
end



function F.start()
    F.restorePufferHooks()
    F.buildSkinMappings()
    if not _G.AddOutfitPersistLoaded then
        _G.AddOutfitPersistLoaded = true
        F.persistLoadFromDisk()
    end
    F.applyPersistSlotsToCache()
    F.syncGlobalWearSkins()
    
    _G.apply_vehicle_skin = F.matchApplyVehicleSkin
    _G.skinIdMappings = _G.AddOutfitSkinIdMappings
    
    F.hookDepotInit()
    F.hookWardrobeData()
    F.hookWardrobeGetData()
    F.hookWardrobeDepotList()
    F.hookPageFilter()
    F.hookArmory()
    F.hookGunSkinId()
    F.hookPutOn()
    F.hookPutDown()
    F.hookVehicles()
    F.hookAirborneClick()
    F.hookVehicleInfoInit()
    F.hookVehicleSkinDataInit()
    F.hookHallTheme()
    F.hookWeaponWear()
    F.hookNotice()
    F.hookAvatarValid()
    F.hookPutOnRsp()
    F.hookAirborneCache()
    F.hookLobbyWeaponCache()
    F.hookThrowObjects()
    F.hookLobbySwipePersistence()
    F.hookWardrobePutOnReq()
    F.hookWardrobeWearClicks()
    F.hookMatchAvatar()
    F.hookEquipmentRectify()
    F.hookWeaponSpawn()
    F.hookEnterGame()

-- ==============================================================================
-- [NEW] KILL MESSENGER, DEADBOX, KILL COUNTER & ICON LOGIC FROM SAMPLE CODE.
-- ==============================================================================
local function decodeExpand(expandContent)
    local ok, exp = pcall(function() return slua.LuaArchiverDecode(LuaStateWrapper, expandContent) or {} end)
    return ok and exp or {}
end

local function encodeExpand(exp)
    return slua.LuaArchiverEncode(LuaStateWrapper, exp or {})
end

local _cachedMyName = nil
local function isMyKill(data)
    if not data then return false end
    if data.bIamCauser then return true end
    -- Optimize: Retrieve the name only once to avoid calling C++ SLUA thousands of times.
    if not _cachedMyName then
        local hud = slua_GameFrontendHUD
        if hud then
            local pc = hud:GetPlayerController()
            if slua.isValid(pc) then
                local ch = pc:GetPlayerCharacterSafety()
                if slua.isValid(ch) then _cachedMyName = ch:GetPlayerNameSafety() end
            end
        end
    end
    if not _cachedMyName or _cachedMyName == "" then return false end
    return data.Causer == _cachedMyName or data.CauserRealPlayerName == _cachedMyName or data.CauserPlayerName == _cachedMyName
end

local function getCurrentWeaponSkinID()
    -- [FIXED] Get the exact Skin ID of the gun CURRENTLY HELD to avoid showing the wrong Kill Message.
    local hud = slua_GameFrontendHUD
    if not hud then return 0 end
    local pc = hud:GetPlayerController()
    if not slua.isValid(pc) then return 0 end
    local ch = pc:GetPlayerCharacterSafety()
    if not slua.isValid(ch) then return 0 end
    
    local currWeapon = ch:GetCurrentWeapon()
    if slua.isValid(currWeapon) and currWeapon.synData then
        local currentSkinID = 0
        pcall(function()
            local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
            local skinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
            
            -- Only output Kill Message if the held gun is truly a VIP gun (ID > 1000000).
            if skinID > 1000000 then 
                currentSkinID = skinID
            end
        end)
        return currentSkinID
    end
    return 0
end

local _downloadedAssetsCache = {}
local function downloadTeamAssets(skinID)
    if not skinID or skinID == 0 or skinID == 69 then return end
    -- Optimize: Load each skin only once to avoid spamming bandwidth and CPU.
    if _downloadedAssetsCache[skinID] then return end
    _downloadedAssetsCache[skinID] = true

    pcall(function()
        local PufferManager = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {skinID})
        
        local cfg = CDataTable.GetTableData("TeamKillBroadcast", skinID)
        if cfg then
            if cfg.EffectPath and cfg.EffectPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.EffectPath})
            end
            if cfg.BgPath and cfg.BgPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.BgPath})
            end
        end
    end)
end

local function patchTeamKill(messageData)
    if not RAPZHANG_KILL_MESSAGE_ALWAYS_ON then return messageData end -- [BLOCK IF SWITCH OFF]
    if not messageData or not isMyKill(messageData) then return messageData end
    local currentSkinID = getCurrentWeaponSkinID()
    if not currentSkinID or currentSkinID == 0 or currentSkinID == 69 then return messageData end
    local broadcastCfg = CDataTable.GetTableData("TeamKillBroadcast", currentSkinID)
    if not broadcastCfg or (not broadcastCfg.BgPath and not broadcastCfg.EffectPath) then return messageData end
    pcall(function()
        local exp = decodeExpand(messageData.ExpandDataContent)
        exp.CauserWeaponAvatarID = currentSkinID
        messageData.ExpandDataContent = encodeExpand(exp)
        messageData.bShowBottomBothSidesKillInfo = true
        messageData.bIamCauser = true
        downloadTeamAssets(currentSkinID)
    end)
    return messageData
end

local function installTeamBroadcastHooks()
    local function wrapCopy(mod, tag)
        if not mod then return end
        local impl2 = mod.__inner_impl or mod
        if not impl2 or not impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable then return end
        local key = "__teamKillCopy_" .. tag
        if not impl2[key] then impl2[key] = impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable end
        local O_Copy = impl2[key]
        impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
            local copied = O_Copy(self, messageData)
            
            -- [MAX OPTIMIZE] If Kill Message is off -> Skip all logic below, return to the game's original behavior.
            if not RAPZHANG_KILL_MESSAGE_ALWAYS_ON then return copied end
            
            local ok2, result = pcall(function() return patchTeamKill(copied) end)
            if ok2 then return result end
            return copied
        end
    end
    pcall(function() wrapCopy(require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "base") end)
    pcall(function() wrapCopy(require("GameLua.Mod.SingleTraining.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "training") end)
end

-- Initialize the Kill Count system.
_G.killCountInfo = {
    [101001] = 0000, [101004] = 0000, [101003] = 0000, [103001] = 0000,
    [102001] = 0000, [105001] = 0000, [102002] = 0000, [103002] = 0000
}

function _G.saveKillCountToFile()
    -- Emptied the file save function to prevent FPS drops.
end

function _G.loadKillCountFromFile()
    -- Emptied the file read function to prevent FPS drops.
end

function _G.addKill(weaponID, count)
    if not weaponID or not count then return end
    _G.killCountInfo[weaponID] = (_G.killCountInfo[weaponID] or 0) + count
    _G.saveKillCountToFile()
end

function _G.getKills(weaponID) return weaponID and _G.killCountInfo[weaponID] or 0 end

-- Hook Deadbox (Create Corpse Box) and KillInfo.
pcall(function()
    local SKillInfo = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
    local SKillInfoModuleManager = require("client.module_framework.ModuleManager")
    local UEnums = _ENV.UEnums
    local ECharacterHealthStatus = import("ECharacterHealthStatus")
    
    if SKillInfo and SKillInfo.__inner_impl and SKillInfo.__inner_impl.FileItem then
        local O_FileItem = SKillInfo.__inner_impl.FileItem
        SKillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
            if not self or not DamageRecordData then return end

            -- [MAX OPTIMIZE] Disable all 3 features -> Immediately return to original game, super light.
            if not RAPZHANG_SKIN_DEADBOX_ALWAYS_ON and not RAPZHANG_KILL_COUNT_UI_ALWAYS_ON and not RAPZHANG_KILL_MESSAGE_ALWAYS_ON then
                return O_FileItem(self, DamageRecordData)
            end

            local LogicKillCounter = SKillInfoModuleManager.GetModule(SKillInfoModuleManager.CommonModuleConfig.LogicKillCounter)
            if not LogicKillCounter then return O_FileItem(self, DamageRecordData) end

            local uCharacter = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            if not uCharacter or not slua.isValid(uCharacter) then return O_FileItem(self, DamageRecordData) end

            local SelfName = uCharacter:GetPlayerNameSafety()
            local bIsCauser = DamageRecordData.Causer == SelfName

            if bIsCauser then
                if DamageRecordData.DamageType == UEnums.DamageType.VehicleDamage then
                    if RAPZHANG_SKIN_DEADBOX_ALWAYS_ON or RAPZHANG_KILL_MESSAGE_ALWAYS_ON then 
                        local carSkinID = _G.CurrentEquipVehicleID or 0
                        if carSkinID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            ExpandData.CauserVehicleSkinID = carSkinID
                            if RAPZHANG_KILL_MESSAGE_ALWAYS_ON then -- ONLY ENABLE forcing SKIN onto KILL FEED.
                                self:ChangeInfoBgByWeaponAvatarIDLua(carSkinID)
                                DamageRecordData.CauserWeaponAvatarID = carSkinID
                                DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                            end
                            DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                        end
                    end
                elseif DamageRecordData.CauserWeaponAvatarID ~= 69 and DamageRecordData.CauserClothAvatarID ~= 69 then
                    local currWeapon = uCharacter:GetCurrentWeapon()
                    if currWeapon and slua.isValid(currWeapon) then
                        local defineID = currWeapon:GetItemDefineID()
                        local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                        if DefineID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            local hasChanged = false

                            local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                            if SupportKillCounter and DamageRecordData.ResultHealthStatus == ECharacterHealthStatus.FinishedLastBreath then
                                local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
                                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                                
                                -- [FPS OPTIMIZE] Mod guns must use IDs above 1,000,000 (e.g. Frost M4: 1101004046).
                                if SkinID > 1000000 then 
                                    if RAPZHANG_KILL_COUNT_UI_ALWAYS_ON then 
                                        ExpandData.KillCounterItemId = DefineID
                                        ExpandData.KillCounterNum = (ExpandData.KillCounterNum or 0) + 1
                                        _G.addKill(DefineID, 1)
                                        hasChanged = true
                                    end
                                    if RAPZHANG_SKIN_DEADBOX_ALWAYS_ON then 
                                        _G.NeedCheckDeadBoxTimer = 5 
                                        hasChanged = true
                                    end
                                end
                            end

                            if hasChanged or RAPZHANG_KILL_MESSAGE_ALWAYS_ON then
                                _G.UpdateMyKillCounter = true
                                if RAPZHANG_KILL_MESSAGE_ALWAYS_ON then -- ONLY ENABLE changing the message package to display on TOP.
                                    local synData = currWeapon.synData
                                    if synData and slua.isValid(synData) then
                                        local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                        if weaponDefineID and slua.isValid(weaponDefineID) then
                                            DamageRecordData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        end
                                    end
                                    DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                                end
                                DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        end
                    end
                end
            end
            O_FileItem(self, DamageRecordData)
        end
    end
end)

-- Hook UI Kill Counter (Update count & Icon on screen).
pcall(function()
    local MyMainKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainKillCounter")
    local MyKillCountSubSystem = require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
    local MyMainWeaponInfoItemUI = require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
    local MyMainWeaponKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainWeaponKillCounter")
    local SlotBase = require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
    local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    local UIManager = require("client.slua_ui_framework.manager")
    local ModuleManager = require("client.module_framework.ModuleManager")

    if MyKillCountSubSystem and MyKillCountSubSystem.__inner_impl then
        _G.OurkillCountSystem = MyKillCountSubSystem.__inner_impl
        
        local o_OnRefreshUI = MyMainKillCounter.__inner_impl.OnRefreshUI
        MyMainKillCounter.__inner_impl.OnRefreshUI = function(self, _, _, UID)
            if not RAPZHANG_KILL_COUNT_UI_ALWAYS_ON then return end -- BLOCK WHEN OFF.
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, self.WeaponID)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self.KillCounterItem:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), SkinID)
            end
        end

        MyKillCountSubSystem.__inner_impl.CheckSupportKCUI = function(self) return RAPZHANG_KILL_COUNT_UI_ALWAYS_ON end

        local o_UpdateMainKillCounterUI = MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
            -- [MAX OPTIMIZE] Immediately suppress the Game UI call if turned off, PREVENT FLASHING.
            if not RAPZHANG_KILL_COUNT_UI_ALWAYS_ON then
                o_UpdateMainKillCounterUI(self, false, WeaponID, AvatarID) -- Force parameter False.
                local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
                return
            end

            o_UpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID)
            local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
         
            if not bShow and MainKillCounter then
                UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
            elseif bShow and currweapon ~= nil then
                local DefineID = currweapon:GetItemDefineID().TypeSpecificID
                local currentEquipAvatrid = slua.IndexReference(currweapon.synData:Get(7), "defineID").TypeSpecificID
                local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                
                local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, currentEquipAvatrid)
                
                -- [FPS OPTIMIZE] DETECT MOD GUNS: Normal guns ID < 1,000,000, Mod guns ID > 1,000,000.
                local isModdedSkin = (currentEquipAvatrid and currentEquipAvatrid > 1000000)
                
                -- Close UI if it's a pistol, knife, PAN, or a normal gun without skin.
                if (SupportKillCounter == nil or not isModdedSkin) then
                    if MainKillCounter then
                        UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
                    end
                else
                    -- Show UI if it's a Mod gun (Even if curEquipedKillCounter returns nil because the server can't identify it).
                    if not MainKillCounter then
                        UIManager.ShowUI(UIManager.UI_Config_InGame.MainKillCounter, DefineID, currentEquipAvatrid)
                        MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                        if MainKillCounter then
                            MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                        end
                    else
                        MainKillCounter:UpdateWeaponID(DefineID, currentEquipAvatrid)
                        MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                    end
                end
            end
        end

        local o_CheckNeedMainKillCounterUI = MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI = function(self, Weapon, PlayerID)
            if not RAPZHANG_KILL_COUNT_UI_ALWAYS_ON then return end -- BLOCK WHEN OFF.
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self:UpdateMainKillCounterUI(true, DefineID, SkinID)
            end
        end
    end
end)

-- Updater loop (Cache optimized: Only update UI when switching guns or on a Kill network event).
local _lastKCWeaponID = 0
local _lastKCSkinID = 0

_G.GameAvatarHandlerkillcounter = function()
    -- The deadbox skin hook is triggered by kill events, then serviced from
    -- this existing timer. Keep it independent of the KillCountUI toggle.
    if RAPZHANG_SKIN_DEADBOX_ALWAYS_ON
        and (_G.NeedCheckDeadBoxTimer or 0) > 0
        and _G.DeadBox_TemperRequest then
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pc and slua.isValid(pc) then _G.DeadBox_TemperRequest(pc) end
        end)
    end

    local UIManager = require("client.slua_ui_framework.manager")
    
    if not RAPZHANG_KILL_COUNT_UI_ALWAYS_ON then
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
        return 
    end

    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not PlayerController or not slua.isValid(PlayerController) then return end
    
    local uCharacter = PlayerController:GetPlayerCharacterSafety()
    if not uCharacter or not slua.isValid(uCharacter) then return end
    
    local currweapon = uCharacter:GetCurrentWeapon()
    if currweapon and slua.isValid(currweapon) then
        -- Get DefineID safely without creating RAM garbage.
        local defineIDObj = currweapon:GetItemDefineID()
        local currentWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
        
        -- Get Skin ID from the Skin V7.5 cache (Very lightweight, no SLUA calls).
        local currentSkinID = 0
        if _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[currentWeaponID] then
            currentSkinID = _G.AddOutfitLastAppliedSkin[currentWeaponID]
        end

        -- EXTREME OPTIMIZE: Only send UI update command if JUST SWITCHED GUN or JUST KILLED SOMEONE.
        if _G.UpdateMyKillCounter or currentWeaponID ~= _lastKCWeaponID or currentSkinID ~= _lastKCSkinID then
            _lastKCWeaponID = currentWeaponID
            _lastKCSkinID = currentSkinID
            _G.UpdateMyKillCounter = false
            
            if _G.OurkillCountSystem then
                _G.OurkillCountSystem:UpdateMainKillCounterUI(true, currentWeaponID, currentSkinID)
            end
        end
    else
        _lastKCWeaponID = 0
        _lastKCSkinID = 0
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
    end
end

local function LobbyTickSetup()
    if not _G.CounterUpdated then
        _G.CounterUpdated = true
        _G.loadKillCountFromFile()
    end
    -- Removed continuous translateec.conf file scanning logic that caused lag.
end

-- Activate Hooks and Loop.
pcall(function()
    installTeamBroadcastHooks()
    LobbyTickSetup() -- Only call file read once on game entry, do not repeat.
    
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, _G.GameAvatarHandlerkillcounter, -1, 0.5)
        -- Removed 0.4s file read loop to avoid FPS drops.
    end
end)
-- ==============================================================================

    F.startVehicleSkinTicker()
    if not _G.AddOutfitVehInitTimers then
        _G.AddOutfitVehInitTimers = true
        F.later(1.5, function() pcall(F.applyVehicleSkinsToPC) end)
        F.later(4.0, function() pcall(F.applyVehicleSkinsToPC) end)
    end

    pcall(function()
        if F.isInRealMatch() then
            local char = F.getLocalChar()
            if char then
                F.bootstrapMatch(char)
            end
        end
    end)

    local firstLobby = not _G.AddOutfitLobbyInitDone
    if F.ensureWardrobeHooks then pcall(F.ensureWardrobeHooks) end
    if F.injectAll() then
        if firstLobby then _G.AddOutfitLobbyInitDone = true end
        F.afterInjectApply(firstLobby)
        return
    end
    local tries = 0
    local function retry()
        tries = tries + 1
        if F.injectAll() then
            local ft = not _G.AddOutfitLobbyInitDone
            if ft then _G.AddOutfitLobbyInitDone = true end
            F.afterInjectApply(ft)
            return
        end
        if tries < INJECT_RETRY_MAX then F.later(INJECT_RETRY_SEC, retry) end
    end
    F.later(INJECT_RETRY_SEC, retry)
end


-- ================= START AUTOMATIC WEAPON ATTACHMENT OWNERSHIP =================
_G.__RapzhangWeaponAttachmentOwnershipReady = true

if _G.RapzhangAttachmentOwnershipMode == nil then
    _G.RapzhangAttachmentOwnershipMode = true
end

local function toInt(v) return tonumber(v) or 0 end
local function isSkinItem(id) return toInt(id) >= 1000000000 end
local function isVanillaAttach(id) local n = toInt(id); return n > 0 and n < 1000000000 end

local function getLocalChar()
    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not PlayerController or not slua.isValid(PlayerController) then return nil end
    return PlayerController:GetPlayerCharacterSafety()
end

local function rapzhangGetLocalPC()
    local ch = getLocalChar()
    if not ch or not slua.isValid(ch) then return nil end
    local pc = nil
    pcall(function()
        if ch.GetPlayerControllerSafety then pc = ch:GetPlayerControllerSafety() end
    end)
    return (pc and slua.isValid(pc)) and pc or nil
end

local OwnershipMgr = {
    SOCKET_SLOT_MAX = 12,
    _cache = nil,
    _skinCtx = {},
}

function OwnershipMgr:cfg(resID)
    resID = toInt(resID)
    if resID <= 0 or not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

function OwnershipMgr:gameUtils()
    if not self._gu then
        self._gu = {}
        pcall(function() self._gu.au = import("AvatarUtils") end)
        pcall(function() self._gu.bu = import("BackpackUtils") end)
        if not self._gu.au then pcall(function() self._gu.au = import("/Script/ShadowTrackerExtra.AvatarUtils") end) end
        if not self._gu.bu then pcall(function() self._gu.bu = import("/Script/ShadowTrackerExtra.BackpackUtils") end) end
    end
    return self._gu.au, self._gu.bu
end

function OwnershipMgr:avatarBPID(resId)
    resId = toInt(resId)
    if resId <= 0 then return 0 end
    local au, bu = self:gameUtils()
    local bp = 0
    pcall(function()
        if au and au.GetBPIDByResID then bp = toInt(au.GetBPIDByResID(resId)) end
    end)
    if bp <= 0 then
        pcall(function()
            if bu and bu.GetBPIDByResID then bp = toInt(bu.GetBPIDByResID(resId)) end
        end)
    end
    return bp > 0 and bp or resId
end

function OwnershipMgr:makeIntArray()
    local ok, a = pcall(function()
        return slua.Array(UEnums.EPropertyClass.Int)
    end)
    return ok and a or nil
end

function OwnershipMgr:splitList(str, sep)
    if not str or str == "" then return {} end
    local ok, StringUtil = pcall(require, "common.string_util")
    if ok and StringUtil and StringUtil.Split then
        return StringUtil.Split(str, sep)
    end
    local out = {}
    for part in string.gmatch(str, "[^" .. sep .. "]+") do
        out[#out + 1] = part
    end
    return out
end

function OwnershipMgr:parsePairList(str)
    local out = {}
    for _, chunk in pairs(self:splitList(str, "|")) do
        local parts = self:splitList(chunk, "-")
        if #parts >= 2 then
            local key = toInt(parts[1])
            local val = toInt(parts[2])
            if val > 0 then out[#out + 1] = { key = key, val = val } end
        else
            local id = toInt(parts[1])
            if id > 0 then out[#out + 1] = { key = 0, val = id } end
        end
    end
    return out
end

function OwnershipMgr:buildCache()
    if self._cache then return self._cache end
    local c = {
        groupOf = {}, levelOf = {}, groupParts = {},
        diffColor = {}, levelRow = {},
        parentOf = {}, socketOf = {}, canon = {},
        ready = false,
    }
    if not CDataTable or not CDataTable.GetTable then
        self._cache = c
        return c
    end
    local got = 0
    local up = CDataTable.GetTable("ItemUpgradeConfig")
    if up then
        got = got + 1
        for _, row in pairs(up) do
            local itm, gid = toInt(row.ItemID), toInt(row.GroupID)
            if isSkinItem(itm) and gid > 0 then
                c.groupOf[itm] = gid
                c.levelOf[itm] = toInt(row.Level)
            end
        end
    end
    local unlock = CDataTable.GetTable("ItemUpgradeUnLockConfig")
    if unlock then
        got = got + 1
        for _, row in pairs(unlock) do
            local gid, part = toInt(row.GroupID), toInt(row.PartId or row.PartID)
            if gid > 0 and isSkinItem(part) then
                local list = c.groupParts[gid]
                if not list then list = {}; c.groupParts[gid] = list end
                list[#list + 1] = part
            end
        end
    end
    local diff = CDataTable.GetTable("ItemUpgradeDiffColorPart")
    if diff then
        for _, row in pairs(diff) do
            local alt = toInt(row.DiffColorPartID)
            if alt > 0 then c.diffColor[alt] = true end
        end
    end
    local lvl = CDataTable.GetTable("ItemUpgradePartLevelMap")
    if lvl then
        for k, row in pairs(lvl) do
            local part = toInt(row.PartID or row.PartId or k)
            if part > 0 then
                c.levelRow[part] = {
                    min = toInt(row.MinActiveLevel),
                    max = toInt(row.MaxActiveLevel),
                    grp = toInt(row.GroupID),
                }
            end
        end
    end
    c.ready = (got == 2)
    self._cache = c
    return c
end

function OwnershipMgr:parentOf(partId)
    partId = toInt(partId)
    if not isSkinItem(partId) then return 0 end
    local c = self:buildCache()
    if c.parentOf[partId] ~= nil then return c.parentOf[partId] end
    local v = 0
    pcall(function()
        local row = CDataTable.GetTableData("WeaponAttachAttrBPTable", partId)
        if row and row.ParentID then v = toInt(row.ParentID) end
    end)
    if v <= 0 then
        pcall(function()
            local au = self:gameUtils()
            if au and au.GetWeaponAttachmentSkinParentID then
                local bp = self:avatarBPID(partId)
                local p = toInt(au.GetWeaponAttachmentSkinParentID(bp))
                if isVanillaAttach(p) and self:cfg(p) then v = p end
            end
        end)
    end
    if not isVanillaAttach(v) then v = 0 end
    -- Do not cache misses: attachment metadata may become available after
    -- the first lobby/match bootstrap.
    if v > 0 then c.parentOf[partId] = v end
    return v
end

function OwnershipMgr:socketOf(resId)
    resId = toInt(resId)
    if resId <= 0 then return -1 end
    local c = self:buildCache()
    if c.socketOf[resId] ~= nil then return c.socketOf[resId] end
    local s = -1
    pcall(function()
        local _, bu = self:gameUtils()
        if bu and bu.getSocketByAttachResID then
            local r = bu.getSocketByAttachResID(resId)
            if r ~= nil then s = tonumber(r) or -1 end
        end
    end)
    -- A missing socket can be a load-order issue; retry it on a later pass.
    if s >= 0 then c.socketOf[resId] = s end
    return s
end

function OwnershipMgr:canonicalVanilla(id)
    id = toInt(id)
    if not isVanillaAttach(id) then return 0 end
    local c = self:buildCache()
    if c.canon[id] ~= nil then return c.canon[id] end
    local v = id
    pcall(function()
        local au = self:gameUtils()
        if au and au.GetAdjustWeaponAttachmentID then
            local adj = toInt(au.GetAdjustWeaponAttachmentID(id))
            if isVanillaAttach(adj) then v = adj end
        end
    end)
    c.canon[id] = v
    return v
end

function OwnershipMgr:betterPart(a, b)
    local c = self:buildCache()
    local da, db = c.diffColor[a] == true, c.diffColor[b] == true
    if da ~= db then return db end
    local la, lb = c.levelRow[a] ~= nil, c.levelRow[b] ~= nil
    if la ~= lb then return la end
    return a < b
end

function OwnershipMgr:baseWeaponId(weaponSkinId)
    weaponSkinId = toInt(weaponSkinId)
    if weaponSkinId <= 0 then return 0 end
    local base = 0
    pcall(function()
        local row = CDataTable.GetTableData("WeaponSkinMapping", weaponSkinId)
        if row then base = toInt(row.WeaponID or row.weaponID or row.WeaponId) end
    end)
    if base <= 0 then
        pcall(function()
            if CDataTable.GetTableData("ArmoryConfig", weaponSkinId) then
                base = weaponSkinId
            end
        end)
    end
    return base > 0 and base or weaponSkinId
end

function OwnershipMgr:isAssetAvailable(partId, isLobby)
    partId = toInt(partId)
    if partId <= 0 then return false end
    local ic = self:cfg(partId)
    if not ic then return false end
    local bpId = toInt(ic.BPID)
    if bpId <= 0 then bpId = self:avatarBPID(partId) end
    if bpId <= 0 then return true end
    local ok, ret = pcall(function()
        local model_util = require("client.common.model_util")
        if model_util.GetClass("Avatar", bpId, isLobby == true, false) then return true end
        if model_util.GetClass("Avatar", bpId, true, false) then return true end
        if model_util.GetClass("Avatar", bpId, false, false) then return true end
        return false
    end)
    if ok and ret then return true end
    return ic ~= nil
end

-- Fallback for M24 attachment skins missing from ItemUpgradeUnLockConfig /
-- WeaponAttrBPTable.AttachmentSkinIDList in some client data versions.
local M24_BASE_WEAPON_ID = 103002
local M24_ATTACHMENT_SKIN_FALLBACK = {
    1103002136,
    1103002106,
    1103002113,
    1103002126,
    1103002146,
    1103002156,
}
local M24_ATTACHMENT_SKIN_FALLBACK_SET = {}
for _, partId in ipairs(M24_ATTACHMENT_SKIN_FALLBACK) do
    M24_ATTACHMENT_SKIN_FALLBACK_SET[partId] = true
end

function OwnershipMgr:applyM24AttachmentFallback(ctx)
    if type(ctx) ~= "table" then return end
    for _, partId in ipairs(M24_ATTACHMENT_SKIN_FALLBACK) do
        -- These IDs are explicitly listed as valid M24 resources; do not
        -- require Item-table availability during the early bootstrap pass.
        ctx.parts[partId] = true
        local parent = self:parentOf(partId)
        if isVanillaAttach(parent) then
            local canonicalParent = self:canonicalVanilla(parent)
            if canonicalParent > 0 then
                if not ctx.byVanilla[canonicalParent] then
                    ctx.byVanilla[canonicalParent] = partId
                end
                if not ctx.defaultSkinByVanilla[canonicalParent] then
                    ctx.defaultSkinByVanilla[canonicalParent] = partId
                end
            end
        end
        -- Some attachment rows expose a socket but no usable vanilla ParentID.
        local attachSlot = self:socketOf(partId)
        if (attachSlot < 0 or attachSlot > self.SOCKET_SLOT_MAX)
            and isVanillaAttach(parent) then
            attachSlot = self:socketOf(parent)
        end
        if attachSlot >= 0 and attachSlot <= self.SOCKET_SLOT_MAX
            and not ctx.defaultSkinBySlot[attachSlot] then
            ctx.defaultSkinBySlot[attachSlot] = partId
        end
    end
end

function OwnershipMgr:getSkinContext(weaponSkinId)
    weaponSkinId = toInt(weaponSkinId)
    if weaponSkinId <= 0 then return nil end
    local baseId = self:baseWeaponId(weaponSkinId)
    if self._skinCtx[weaponSkinId] then
        local cached = self._skinCtx[weaponSkinId]
        if baseId == M24_BASE_WEAPON_ID then self:applyM24AttachmentFallback(cached) end
        return cached
    end
    local c = self:buildCache()
    local ctx = {
        weaponSkinId = weaponSkinId,
        byVanilla = {},
        parts = {},
        defaultVanilla = {},
        defaultSkinByVanilla = {},
        defaultSkinBySlot = {},
    }
    local gid = c.groupOf[weaponSkinId]
    local level = c.levelOf[weaponSkinId] or 0
    local list = gid and c.groupParts[gid]
    if list then
        for _, part in ipairs(list) do
            local ok = true
            local lr = c.levelRow[part]
            if lr then
                if lr.grp > 0 and lr.grp ~= gid then ok = false end
                if lr.min > 0 and level < lr.min then ok = false end
                if lr.max > 0 and level > lr.max then ok = false end
            end
            if ok then
                ctx.parts[part] = true
                local van = self:parentOf(part)
                if van > 0 then
                    local cur = ctx.byVanilla[van]
                    if not cur or self:betterPart(part, cur) then
                        ctx.byVanilla[van] = part
                    end
                end
            end
        end
    end
    local skinBp = self:avatarBPID(weaponSkinId)
    pcall(function()
        local row = CDataTable.GetTableData("WeaponAttrBPTable", skinBp)
        if row and row.AttachmentSkinIDList and row.AttachmentSkinIDList ~= "" then
            for _, pair in ipairs(self:parsePairList(row.AttachmentSkinIDList)) do
                local skinId, key = pair.val, pair.key
                if isSkinItem(skinId) and self:cfg(skinId) then
                    ctx.parts[skinId] = true
                    local van = self:parentOf(skinId)
                    if van > 0 then
                        ctx.defaultSkinByVanilla[van] = skinId
                        if not ctx.byVanilla[van] then ctx.byVanilla[van] = skinId end
                    end
                    if isVanillaAttach(key) then
                        local canon = self:canonicalVanilla(key)
                        ctx.defaultSkinByVanilla[canon] = skinId
                        if not ctx.byVanilla[canon] then ctx.byVanilla[canon] = skinId end
                    elseif key >= 0 and key <= self.SOCKET_SLOT_MAX then
                        ctx.defaultSkinBySlot[key] = skinId
                    end
                end
            end
        end
    end)
    local baseBp = self:avatarBPID(baseId)
    pcall(function()
        local row = CDataTable.GetTableData("WeaponAttrBPTable", baseBp)
        if row and row.AttachmentIDList_a and row.AttachmentIDList_a ~= "" then
            for _, pair in ipairs(self:parsePairList(row.AttachmentIDList_a)) do
                local vanId = pair.val > 0 and pair.val or pair.key
                if isVanillaAttach(vanId) then
                    local slot = self:socketOf(vanId)
                    if slot >= 0 and slot <= self.SOCKET_SLOT_MAX then
                        ctx.defaultVanilla[slot] = self:canonicalVanilla(vanId)
                    end
                end
            end
        end
    end)
    pcall(function()
        local au = self:gameUtils()
        if not au or not au.GetWeaponAvatarDefaultAttachment then return end
        local outArr = self:makeIntArray()
        if not outArr then return end
        outArr = au.GetWeaponAvatarDefaultAttachment(baseBp, outArr, false)
        if not outArr or not slua.isValid(outArr) then return end
        local n = 0
        pcall(function() n = outArr:Num() end)
        for i = 0, n - 1 do
            local vanId = 0
            pcall(function() vanId = toInt(outArr:Get(i)) end)
            if vanId > 0 then
                local slot = self:socketOf(vanId)
                if slot >= 0 and slot <= self.SOCKET_SLOT_MAX then
                    ctx.defaultVanilla[slot] = self:canonicalVanilla(vanId)
                end
            end
        end
    end)
    if baseId == M24_BASE_WEAPON_ID then
        self:applyM24AttachmentFallback(ctx)
    end
    self._skinCtx[weaponSkinId] = ctx
    return ctx
end

function OwnershipMgr:collectAttachmentSkinIds(weaponSkinId, isLobby)
    weaponSkinId = toInt(weaponSkinId)
    if weaponSkinId <= 0 then return {} end
    local ctx = self:getSkinContext(weaponSkinId)
    if not ctx then return {} end
    local out, seen = {}, {}
    local isM24 = self:baseWeaponId(weaponSkinId) == M24_BASE_WEAPON_ID
    for partId, _ in pairs(ctx.parts) do
        partId = toInt(partId)
        local isKnownM24Fallback = isM24 and M24_ATTACHMENT_SKIN_FALLBACK_SET[partId] == true
        if isSkinItem(partId) and not seen[partId]
            and (isKnownM24Fallback or self:isAssetAvailable(partId, isLobby == true)) then
            seen[partId] = true
            out[#out + 1] = partId
        end
    end
    table.sort(out)
    return out
end

function OwnershipMgr:buildWeaponAttachSkinMap(weaponSkinIds)
    local map = {}
    if type(weaponSkinIds) ~= "table" then return map end
    for _, sid in ipairs(weaponSkinIds) do
        sid = toInt(sid)
        if sid > 0 and isSkinItem(sid) then
            local parts = self:collectAttachmentSkinIds(sid, false)
            if #parts > 0 then map[sid] = parts end
        end
    end
    return map
end

function OwnershipMgr:mergeWeaponAttachSkinMaps(base, extra)
    base = base or {}
    for sid, list in pairs(extra or {}) do
        sid = toInt(sid)
        if sid > 0 and type(list) == "table" and #list > 0 then
            local dst = base[sid]
            if type(dst) ~= "table" then dst = {}; base[sid] = dst end
            local seen = {}
            for _, x in ipairs(dst) do seen[toInt(x)] = true end
            for _, x in ipairs(list) do
                x = toInt(x)
                if x > 0 and not seen[x] then
                    seen[x] = true
                    dst[#dst + 1] = x
                end
            end
        end
    end
    return base
end

function OwnershipMgr:mergeWeaponSkinIdList(existing)
    if _G.RapzhangMatchWeaponSkin and _G.RapzhangMatchWeaponSkin.mergeWeaponSkinIdList then
        return _G.RapzhangMatchWeaponSkin.mergeWeaponSkinIdList(existing)
    end
    existing = existing or {}
    if type(existing) ~= "table" then return {} end
    local out, seen = {}, {}
    local function add(id)
        id = toInt(id)
        if id > 0 and isSkinItem(id) and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    for _, id in ipairs(existing) do add(id) end
    if _G.RapzhangWeaponSkinIdList and type(_G.RapzhangWeaponSkinIdList) == "table" then
        for _, id in ipairs(_G.RapzhangWeaponSkinIdList) do add(id) end
    end
    return out
end

function OwnershipMgr:registerWeaponAvatarOwnership(pc, weaponSkinIds)
    if not pc or not slua.isValid(pc) then return false end
    self:buildCache()
    local merged = self:mergeWeaponSkinIdList(weaponSkinIds)
    if type(merged) ~= "table" or #merged == 0 then return false end
    local attachMap = self:buildWeaponAttachSkinMap(merged)
    _G.RapzhangWeaponAttachmentMap = attachMap
    pcall(function()
        local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
        if CommerAvatarDataUtil and CommerAvatarDataUtil.InitWeaponSkinList then
            CommerAvatarDataUtil:InitWeaponSkinList(pc, merged, attachMap, nil)
        end
    end)
    local added = {}
    local function regItem(resID)
        resID = toInt(resID)
        if resID <= 0 or added[resID] then return end
        added[resID] = true
        pcall(function()
            if pc.AddWeaponAvatarItem then pc:AddWeaponAvatarItem(resID) end
        end)
    end
    for _, sid in ipairs(merged) do regItem(sid) end
    for _, list in pairs(attachMap) do
        for _, pid in ipairs(list) do regItem(pid) end
    end
    pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    -- Ownership registration does not refresh a gun that is already spawned.
    -- Rebuild the active weapon mesh once so its attachment list is consumed.
    pcall(function()
        local char = F and F.getLocalChar and F.getLocalChar() or nil
        if char and F.reloadCurrentWeaponAvatar then
            F.reloadCurrentWeaponAvatar(char)
        end
    end)
    return true
end

function OwnershipMgr:installInitWeaponSkinListHook()
    if self._initHooked then return end
    self._initHooked = true
    local mgr = self
    pcall(function()
        local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
        if not CommerAvatarDataUtil or not CommerAvatarDataUtil.InitWeaponSkinList then return end
        if CommerAvatarDataUtil._rapzhang_ownership_init_hooked then return end
        CommerAvatarDataUtil._rapzhang_ownership_init_hooked = true
        local orig = CommerAvatarDataUtil.InitWeaponSkinList
        CommerAvatarDataUtil.InitWeaponSkinList = function(self, uPlayerController, weapon_skin_list, weaponattach_skin_list, WeaponPendantInfo)
            if _G.RapzhangAttachmentOwnershipMode == true then
                local skins = mgr:mergeWeaponSkinIdList(weapon_skin_list)
                local autoMap = mgr:buildWeaponAttachSkinMap(skins or {})
                weaponattach_skin_list = mgr:mergeWeaponAttachSkinMaps(weaponattach_skin_list, autoMap)
            end
            return orig(self, uPlayerController, weapon_skin_list, weaponattach_skin_list, WeaponPendantInfo)
        end
    end)
end

function OwnershipMgr:ResetCache()
    self._cache = nil
    self._skinCtx = {}
end

function _G.RapzhangApplyWeaponAttachments(weapon, weaponSkinId)
    if not weapon or not slua.isValid(weapon) then return false end
    weaponSkinId = toInt(weaponSkinId)
    if weaponSkinId <= 0 then return false end
    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return false end
    local ctx = OwnershipMgr:getSkinContext(weaponSkinId)
    if not ctx then return false end
    local changed = false
    local function setExistingSlot(slot, data, skinId)
        skinId = toInt(skinId)
        if not slot or slot < 0 or slot >= GUN_MASTER_SYN_SLOT or skinId <= 0 then return end
        pcall(function()
            local ref = data and slua.IndexReference(data, "defineID")
            if ref and toInt(ref.TypeSpecificID) ~= skinId then
                ref.TypeSpecificID = skinId
                data.defineID = ref
                arr:Set(slot, data)
                changed = true
            end
        end)
    end
    -- Keep the slot chosen by the game. Resolve the current attachment's
    -- parent, then replace only its ID; never treat table keys as synData
    -- indexes (that was the cause of scope 6 becoming scope 3).
    for slot = 0, GUN_MASTER_SYN_SLOT - 1 do
        pcall(function()
            local data = arr:Get(slot)
            local ref = data and slua.IndexReference(data, "defineID")
            local currentId = ref and toInt(ref.TypeSpecificID) or 0
            if currentId <= 0 then return end
            local parent = OwnershipMgr:parentOf(currentId)
            if parent <= 0 then parent = OwnershipMgr:canonicalVanilla(currentId) end
            local skinPart = ctx.byVanilla[parent] or ctx.defaultSkinByVanilla[parent]
            -- ParentID is absent for some valid attachment resources. Resolve
            -- by the attachment's actual socket, but still write to the
            -- existing synData index selected by the game.
            if not skinPart then
                local attachSlot = OwnershipMgr:socketOf(currentId)
                if (attachSlot < 0 or attachSlot > OwnershipMgr.SOCKET_SLOT_MAX)
                    and isVanillaAttach(parent) then
                    attachSlot = OwnershipMgr:socketOf(parent)
                end
                if attachSlot >= 0 and attachSlot <= OwnershipMgr.SOCKET_SLOT_MAX then
                    skinPart = ctx.defaultSkinBySlot[attachSlot]
                end
            end
            if skinPart and skinPart ~= currentId then
                setExistingSlot(slot, data, skinPart)
            end
        end)
    end
    return changed
end

function _G.RapzhangDetectWeaponSkinFromAttachments(weapon, weaponId)
    if not weapon or not slua.isValid(weapon) then return 0 end
    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return 0 end
    weaponId = toInt(weaponId)
    if weaponId <= 0 or not F or not F.getDesiredWeaponSkins then return 0 end
    local active = {}
    for i = 0, GUN_MASTER_SYN_SLOT - 1 do
        pcall(function()
            local data = arr:Get(i)
            local ref = data and slua.IndexReference(data, "defineID")
            local id = ref and toInt(ref.TypeSpecificID) or 0
            if id > 0 then active[id] = true end
        end)
    end
    local best, bestScore = 0, 0
    for _, skinId in ipairs(F.getDesiredWeaponSkins()) do
        skinId = toInt(skinId)
        local owner = toInt(F.weaponIdFromSkin(skinId))
        if skinId > 0 and owner == weaponId then
            local ctx = OwnershipMgr:getSkinContext(skinId)
            local score = 0
            for partId in pairs((ctx and ctx.parts) or {}) do
                if active[toInt(partId)] then score = score + 1 end
            end
            if score > bestScore then best, bestScore = skinId, score end
        end
    end
    return best
end

_G.RapzhangWeaponAttachOwnership = OwnershipMgr
_G.RapzhangAutoAttach = OwnershipMgr

function _G.RapzhangBuildWeaponAttachSkinMap(weaponSkinIds)
    return OwnershipMgr:buildWeaponAttachSkinMap(weaponSkinIds or {})
end

function _G.RapzhangSyncWeaponAvatarOwnership(pc, weaponSkinIds)
    if _G.__WeaponAttachPaused then return false end
    pc = pc or rapzhangGetLocalPC()
    if not pc or not slua.isValid(pc) then return false end
    return OwnershipMgr:registerWeaponAvatarOwnership(pc, weaponSkinIds) == true
end

function _G.RapzhangRefreshAllWeaponAttachmentOwnership()
    if _G.__WeaponAttachPaused then return false end
    return _G.RapzhangSyncWeaponAvatarOwnership(nil, nil) == true
end

OwnershipMgr:installInitWeaponSkinListHook()


-- Bridge Rapzhang ownership to the existing Rapzhang weapon-skin selection.
_G.RapzhangMatchWeaponSkin = {
    mergeWeaponSkinIdList = function(existing)
        local out, seen = {}, {}
        local function add(id)
            id = tonumber(id) or 0
            if id > 0 and id >= 1000000000 and not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
        for _, id in ipairs(existing or {}) do add(id) end
        for _, id in ipairs(F.getDesiredWeaponSkins and F.getDesiredWeaponSkins() or {}) do add(id) end
        return out
    end,
}

-- ================= END AUTOMATIC WEAPON ATTACHMENT OWNERSHIP ===================

-- ============================================================================
-- AUTO-LOAD UNLOCK
--
-- Script ini dipakai tanpa menu: skin harus langsung aktif begitu lobby siap.
-- InitData depot kadang baru datang setelah script dimuat, atau dibangun ulang
-- saat masuk/keluar lobby. Karena itu injeksi tidak boleh hanya sekali di awal.
-- Loop 1 detik ini berhenti melakukan kerja setelah injeksi sukses; setelah
-- itu biayanya hanya satu pengecekan boolean per detik.
-- ============================================================================
function F.startAutoInject()
    if _G.AddOutfitAutoInjectStarted then return true end
    _G.AddOutfitAutoInjectStarted = true
    _G.AddOutfitAutoInjectStop = nil

    local function applyOnce()
        if _G.AddOutfitAutoInjectDone then return end
        _G.AddOutfitAutoInjectDone = true
        if not _G.AddOutfitLobbyInitDone then
            _G.AddOutfitLobbyInitDone = true
            pcall(F.afterInjectApply, true)
        end
    end

    local function pass()
        if _G.AddOutfitAutoInjectDone then return true end
        if F.ensureWardrobeHooks then pcall(F.ensureWardrobeHooks) end
        local ok, injected = pcall(F.injectAll)
        if ok and injected then
            applyOnce()
            return true
        end
        return false
    end

    if pass() then return true end

    local ticker = _ticker
    if not ticker then
        pcall(function() ticker = require("common.time_ticker") end)
    end
    if ticker and ticker.AddTimerLoop then
        local tries = 0
        local ok = pcall(ticker.AddTimerLoop, 1, function()
            if _G.AddOutfitAutoInjectStop or _G.AddOutfitAutoInjectDone then
                return
            end
            if pass() then return end
            tries = tries + 1
            if tries >= 60 then
                -- Sudah 1 menit. Berhenti memindai katalog tiap detik; depot
                -- yang datang belakangan ditangani hook InitData/GetData.
                _G.AddOutfitAutoInjectStop = true
            end
        end, -1, 1)
        if ok then return true end
    end

    -- Ticker game tidak tersedia: pakai timer biasa sebagai cadangan.
    F.later(3, function()
        if pass() then return end
        F.later(5, function()
            if pass() then return end
            F.later(15, pass)
        end)
    end)
    return false
end

-- Diagnostik ringan: panggil `AddOutfit.diagWardrobe()` kalau grid masih
-- kosong. Hasilnya menunjukkan apakah entity sudah init, katalog terbaca,
-- dan berapa entri sintetis yang benar-benar ada di depot.
function F.diagWardrobe()
    local e = F.getEntity()
    local catalog = itemCatalog()
    local out = {
        entity = e ~= nil,
        bInit = e and e.bInit == true or false,
        dataCount = e and tonumber(e._DataCount) or 0,
        catalog = catalog and #catalog or 0,
        injected = 0,
        busy = F._injectBusy == true,
        autoDone = _G.AddOutfitAutoInjectDone == true,
    }
    if e and type(e._data) == "table" then
        for _, d in pairs(e._data) do
            if type(d) == "table" and isSyntheticIns(d.insID) then
                out.injected = out.injected + 1
            end
        end
    end
    print(string.format(
        "[AddOutfit] ent=%s init=%s data=%d katalog=%d injek=%d",
        tostring(out.entity), tostring(out.bInit), out.dataCount,
        out.catalog, out.injected))
    return out
end

_G.AddOutfit = F
F.start()
F.startAutoInject()

-- Match lifecycle fallback: some game versions reuse the same avatar and do
-- not fire the mesh-loaded callback again after returning from the lobby.
-- This watcher only observes the boolean fighting-state transition. It does
-- not scan/apply skins every tick; bootstrap runs once per lobby -> match.
if not _G.AddOutfitMatchStateWatcherStarted then
    _G.AddOutfitMatchStateWatcherStarted = true
    pcall(function()
        local ticker = _ticker or require("common.time_ticker")
        if not ticker or not ticker.AddTimerLoop then return end
        local wasInMatch = false
        local weaponStates = {}
        local lastActiveWeapon = nil
        local function attachmentSignature(weapon)
            if not weapon or not slua.isValid(weapon) then return nil end
            local arr = weapon.synData
            if not arr or not slua.isValid(arr) then return nil end
            local ids = {}
            for i = 0, GUN_MASTER_SYN_SLOT - 1 do
                local id = 0
                pcall(function()
                    local data = arr:Get(i)
                    local ref = data and slua.IndexReference(data, "defineID")
                    id = ref and tonumber(ref.TypeSpecificID) or 0
                end)
                ids[#ids + 1] = tostring(id or 0)
            end
            return table.concat(ids, ":")
        end
        local function weaponSkinId(weapon)
            local id, weaponId = 0, 0
            pcall(function()
                if weapon.GetWeaponID then weaponId = tonumber(weapon:GetWeaponID()) or 0 end
                local arr = weapon.synData
                local master = arr and arr:Get(GUN_MASTER_SYN_SLOT)
                local ref = master and slua.IndexReference(master, "defineID")
                local gunId = ref and tonumber(ref.TypeSpecificID) or 0
                if weaponId <= 0 and weapon.GetItemDefineID then
                    weaponId = tonumber(weapon:GetItemDefineID().TypeSpecificID) or 0
                end
                if F.get_skin_id then
                    id = tonumber(F.get_skin_id(gunId, weaponId)) or 0
                end
            end)
            return id
        end
        local function processWeapon(weapon, isActive, forceActive)
            if not weapon or not slua.isValid(weapon) then return end
            local sig = attachmentSignature(weapon)
            if not sig then return end
            local state = weaponStates[weapon]
            if not state then state = {}; weaponStates[weapon] = state end
            local force = forceActive == true or (isActive and weapon ~= lastActiveWeapon)
            -- The weapon skin must be applied independently of attachments.
            -- Retry only a few times while an unheld weapon finishes loading.
            state.skinApplyTries = (state.skinApplyTries or 0) + 1
            if state.skinApplyTries <= 3 or force then
                pcall(function() F.applySkinToWeapon(weapon) end)
            end
            if force or state.signature ~= sig then
                local skinId = weaponSkinId(weapon)
                if skinId > 0 and _G.RapzhangApplyWeaponAttachments then
                    pcall(function() _G.RapzhangApplyWeaponAttachments(weapon, skinId) end)
                end
                state.signature = attachmentSignature(weapon) or sig
                if isActive and (force or state.signature ~= sig) then
                    if weapon.DelayHandleAvatarMeshChanged then
                        weapon:DelayHandleAvatarMeshChanged()
                    elseif weapon.WeaponAvatarComponent and weapon.WeaponAvatarComponent.ReloadAllEquippedAvatar then
                        weapon.WeaponAvatarComponent:ReloadAllEquippedAvatar(1)
                    end
                end
            else
                state.signature = sig
            end
        end
        ticker.AddTimerLoop(0, function()
            local inMatch = false
            pcall(function() inMatch = F.isInRealMatch() == true end)
            if inMatch and not wasInMatch then
                wasInMatch = true
                weaponStates = {}
                lastActiveWeapon = nil
                pcall(F.stopMatchWatcher)
                F.later(0.35, function()
                    pcall(function()
                        if not F.isInRealMatch() then return end
                        local char = F.getLocalChar()
                        if not char or not slua.isValid(char) then return end
                        PERF.wearDoneThisMatch = false
                        F.bootstrapMatch(char)
                    end)
                end)
            elseif not inMatch and wasInMatch then
                wasInMatch = false
                weaponStates = {}
                lastActiveWeapon = nil
                _matchBootstrapScheduled = false
                _matchCharKey = nil
                _G.RapzhangWeaponAttachmentAppliedKey = {}
                _G.RapzhangWeaponAttachmentRegistered = {}
                PERF.lastBootstrapAt = 0
                PERF.wearDoneThisMatch = false
                PERF.desiredSkins = nil
                PERF.mappingsDirty = true
                for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
                pcall(function() LOBBY.lobbySynced = false end)
                -- Returning from a match can bypass ENTER_GAME_BEGIN. Reset
                -- the one-shot lobby guards here and retry after the lobby
                -- wardrobe data has had time to rebuild.
                LOBBY.reapplyDone = false
                LOBBY.reapplyScheduled = false
                LOBBY.wardrobeRefreshed = false
                _G.AddOutfitLobbyRestored = false
                F.later(1.0, function()
                    pcall(function()
                        if GameStatus and GameStatus.IsInLobbyOrMainCity
                            and GameStatus.IsInLobbyOrMainCity() then
                            F.persistLoadFromDisk()
                            F.persistApplyLoaded()
                            F.reapplyLobbyEquipped()
                            _G.AddOutfitLobbyRestored = true
                        end
                    end)
                end)
                pcall(F.stopMatchWatcher)
            end
            if inMatch then
                pcall(function()
                    local char = F.getLocalChar()
                    if not char or not slua.isValid(char) then return end
                    local active = char.GetCurrentWeapon and char:GetCurrentWeapon() or nil
                    local previousActive = lastActiveWeapon
                    local switched = active and active ~= previousActive
                    if switched then
                        _weaponApplied = false
                        pcall(function() F.matchApplyWeaponSkin(char) end)
                    end
                    local wm = char.GetWeaponManager and char:GetWeaponManager() or nil
                    local list = wm and wm.GetAllInventoryWeaponList and wm:GetAllInventoryWeaponList(false) or nil
                    if list and list.Num and list.Get then
                        for i = 0, list:Num() - 1 do
                            local weapon = list:Get(i)
                            processWeapon(weapon, weapon == active, weapon == active and active ~= previousActive)
                        end
                    elseif active then
                        processWeapon(active, true, active ~= previousActive)
                    end
                    lastActiveWeapon = active
                end)
            end
        end, -1, 0.5)
    end)
end

-- Fallback ingame: run once after startup only. Subsequent changes are
-- handled by match/weapon/avatar hooks, not by a permanent polling loop.
if not _G.AddOutfitIngameSkinInitDone then
    _G.AddOutfitIngameSkinInitDone = true
    pcall(function()
        F.later(0.5, function()
            pcall(function()
                if not RAPZHANG_MOD_SKIN_ALWAYS_ON then return end
                if not F.isInRealMatch or not F.isInRealMatch() then return end
                local char = F.getLocalChar and F.getLocalChar() or nil
                if not char or not slua.isValid(char) then return end
                if not PERF.matchActive then F.bootstrapMatch(char) end
            end)
        end)
    end)
end

-- [FIX VIP] Automatic system to restore lobby skin when the game is just opened.
_G.AddOutfitLobbyRestored = false

local function AutoRestoreLobbySkin()
    if _G.AddOutfitLobbyRestored then return end
    
    -- [LOBBY HIBERNATION FLAG]: If already boarded the plane into match -> Hibernate, do not read the Lobby file anymore!
    if _G.AddOutfit and _G.AddOutfit.isInRealMatch() then return end
    
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
            -- Wait for DataMgr to finish loading the character UID (Avoid errors from loading too early).
            if DataMgr and DataMgr.roleData and DataMgr.roleData.uid then
                local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
                if LMC and LMC.GetCurPage then
                    if _G.AddOutfit and _G.AddOutfit.reapplyLobbyEquipped then
                        -- Fire sequential commands: Read File -> Assign Data -> Render on character.
                        _G.AddOutfit.persistLoadFromDisk() 
                        _G.AddOutfit.persistApplyLoaded() 
                        _G.AddOutfit.reapplyLobbyEquipped() 
                        
                        -- Set flag as completed.
                        _G.AddOutfitLobbyRestored = true
                    end
                end
            end
        end
    end)
end

-- Restore once after startup. Wardrobe/weapon events perform later updates.
pcall(function()
    if F.later then F.later(1.0, AutoRestoreLobbySkin) end
end)
-- ==============================================================================
-- ================= END CORE ADD-OUTFIT V7.5 (SKIN SYSTEM) ================
-- ==============================================================================

-- ==============================================================================
-- ================= END CORE ADD-OUTFIT V7.5 (SKIN SYSTEM) ================
-- ==============================================================================

-- ==============================================================================
-- ================= START MOD EMOTE LOGIC (INGAME ONLY - 0% FPS DROP) =========
-- ==============================================================================
pcall(function()
    local QuickExpressionUtils = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")

    -- List of VIP Action IDs.
    local EXTRA_EMOTES = {
          -- [ACTIONS]
    12201301, -- Gothic Assassin Action
    12216101, -- Blood Hawk Fighter Action
    12212201, -- Dark Assassin Action
    12219207, -- General Taurus Action
    12209001, -- Samurai Fighter Action
    12219561, -- Deep Red Cloak Action
    12210001, -- Touch of Death Action
    12219022, -- Spiked Guard Action
    12208801, -- Demigod Warrior Action
    12210801, -- Silver Shell Hunter Action
    12200701, -- Time-Space Travel Action
    12219242, -- Sky Stroll Action
    12206001, -- Blue Meadow Spirit Action
    12205401, -- King of Beasts Action
    12205201, -- Behemoth Heart Action
    12212601, -- Mystic Slayer Action
    12205601, -- Behemoth Soul Action
    12219208, -- Cyber Monkey King Action
    12212001, -- Martial Saint Action
    12206801, -- Mystic Sea Dragon Action
    12209801, -- Spirit Master Action
    12211401, -- Frost Witch Action
    12207001, -- Star Sea Travel Action
    12211801, -- Lord of Order Action
    12207901, -- Enchanting Sea King Action
    12203401, -- Illusion Commemoration Action
    12204001, -- Clown Action (April Fools')
    12201801, -- Snow Guardian Action
    12215601, -- Stellar Superhero Action
    12215532, -- Lord of Flame Action
    12213201, -- Plan for Tomorrow Action
    12215529, -- Racing Knight Action
    12219053, -- Jewel Queen Action
    12204601, -- World Martial Display Action
    12215701, -- Planet of Apes Action
    12219003, -- Divine Darkness Action
    12219004, -- Fiery Silver Soul Action
    12219009, -- Fiery Enchantment Action
    12219216, -- Withered Ritual Action
    }

    -- EXTREME OPTIMIZE: Cache data in RAM so the game doesn't create new tables each button press.
    local CachedInGameEmotes = nil
    local LastBaseCount = -1
    local LastEmoteSwitchState = nil
    local CachedWeaponShowEmoteID = -1

    -- Emote merge function runs only once.
    local function GetOptimizedEmoteList(baseList)
        local baseCount = baseList and #baseList or 0
        local isEmoteModEnabled = RAPZHANG_MOD_EMOTE_ALWAYS_ON

        -- If already merged, the original emote count hasn't changed, AND the toggle state is unchanged -> use from Cache.
        if CachedInGameEmotes and LastBaseCount == baseCount and LastEmoteSwitchState == isEmoteModEnabled then
            return CachedInGameEmotes
        end

        local compact = {}
        local seen = {}
        
        -- 1. Add the player's default Emotes.
        if baseList then
            -- Preserve the game-provided order; weapon inspect animation
            -- metadata is associated with its original list position.
            for _, data in ipairs(baseList) do
                -- Weapon-show/inspect entries can be special records without
                -- DefineID. Keep every original record; filtering those out
                -- truncates the inspect action and makes its animation stop
                -- before the full sequence finishes.
                if data then
                    local id = data.DefineID and data.DefineID.TypeSpecificID
                    if not id or not seen[id] then
                        table.insert(compact, data)
                        if id then seen[id] = true end
                    end
                end
            end
        end

        -- 2. Add the configured extra emotes; this feature is always enabled.
        if isEmoteModEnabled then
            for _, nEmoteID in ipairs(EXTRA_EMOTES) do
                if not seen[nEmoteID] then
                    table.insert(compact, {
                        DefineID = {TypeSpecificID = nEmoteID},
                        Name = tostring(nEmoteID)
                    })
                    seen[nEmoteID] = true
                end
            end
        end

        CachedInGameEmotes = compact
        LastBaseCount = baseCount
        LastEmoteSwitchState = isEmoteModEnabled
        return CachedInGameEmotes
    end

    -- Hook into the in-game list Load function.
    if QuickExpressionUtils and not _G.__EMOTE_INGAME_HOOKED then
        _G.__EMOTE_INGAME_HOOKED = true
        _G.__EMOTE_ORIG_GET_LIST = QuickExpressionUtils.GetShowExpressionList
        
        QuickExpressionUtils.GetShowExpressionList = function()
            local baseList, nWeaponShowEmoteID = _G.__EMOTE_ORIG_GET_LIST()
            -- Preserve the special weapon-show/inspect context. Passing -1
            -- unconditionally makes the inspect montage use the short
            -- generic emote path instead of its complete weapon sequence.
            CachedWeaponShowEmoteID = tonumber(nWeaponShowEmoteID) or -1
            return GetOptimizedEmoteList(baseList), nWeaponShowEmoteID
        end
    end

    -- Hook the in-game Emote button event to force the UI to render.
    if not _G.__EMOTE_MENU_EVENT_HOOKED and EventSystem and EventSystem.registEvent then
        _G.__EMOTE_MENU_EVENT_HOOKED = true
        EventSystem:registEvent(EVENTTYPE_INGAME, EVENTID_INGAME_QUICK_EXPRESSION_DECAL_CLICK, function()
            pcall(function()
                if not RAPZHANG_MOD_EMOTE_ALWAYS_ON then return end

                local UIManager = require("client.slua_ui_framework.manager")
                if not UIManager or not UIManager.UI_Config_InGame then return end
                local subPanel = UIManager.GetUI(UIManager.UI_Config_InGame.QuickExpressionDecalSubPanel)
                
                if subPanel and subPanel.GetQuickExpressionDecalItemByIndex and CachedInGameEmotes then
                    local showCount = 0
                    for _, data in ipairs(CachedInGameEmotes) do
                        local nEmoteID = data.DefineID and data.DefineID.TypeSpecificID
                        -- The built-in weapon inspect entry may not carry a
                        -- DefineID; its playable ID is returned separately by
                        -- GetShowExpressionList.
                        if (not nEmoteID or nEmoteID <= 0) and CachedWeaponShowEmoteID > 0 then
                            nEmoteID = CachedWeaponShowEmoteID
                        end
                        if nEmoteID and nEmoteID > 0 then
                            showCount = showCount + 1
                            local item = subPanel:GetQuickExpressionDecalItemByIndex(showCount)
                            if item then
                                -- Disable redundant effects that burden the machine.
                                if item.UIRoot.WidgetSwitcher_Effect then item.UIRoot.WidgetSwitcher_Effect:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                                
                                item:Show()
                                item:RefreshData(nEmoteID, CachedWeaponShowEmoteID)
                            end
                        end
                    end
                    if subPanel.HideRestBlocks then subPanel:HideRestBlocks(showCount) end
                    if subPanel.UIRoot then
                        subPanel.UIRoot.WrapBox_List:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
                        subPanel.UIRoot.VerticalBox_Empty:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end)
        end)
    end
end)
-- ==============================================================================
-- ================= END MOD EMOTE LOGIC ==================================
-- ==============================================================================

-- ============================================================================
-- SOCIAL COLLECTION HALL
-- ============================================================================
local SOCIAL_HALL_CONFIG = {
    ROOM_SCENE_NAME = "Lobby_Social_CH_Mesh",
    CAMERA_ID = 10151,
    DEFAULT_SKIN_ID = 6680101,
    DEFAULT_BG_WALL = 6680200,
    MONUMENT_ID = 6680702,
}
_G.RapzhangSocialHallConfig = SOCIAL_HALL_CONFIG

function _G.LoadCollectionHallScene()
    pcall(function()
        if LobbySceneManager and LobbySceneManager.LoadStreamLevel then
            LobbySceneManager.LoadStreamLevel(
                true,
                SOCIAL_HALL_CONFIG.ROOM_SCENE_NAME,
                SOCIAL_HALL_CONFIG.CAMERA_ID,
                "Lobby_Light"
            )
        end
    end)
end

function _G.SetBehindPlayerBackground(bgItemId)
    bgItemId = tonumber(bgItemId)
    if not bgItemId or bgItemId <= 0 then return false end
    local ok, applied = pcall(function()
        local ModuleManager = require("client.module_framework.ModuleManager")
        if not ModuleManager or not ModuleManager.LobbyModuleConfig then return false end
        local Logic = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.Logic_SocialLobbyModule)
        if not Logic or not Logic.SetBGWallPicItemId then return false end
        local roleData = DataMgr and DataMgr.roleData
        local myUid = roleData and tonumber(roleData.uid)
        if not myUid then return false end
        Logic:SetBGWallPicItemId(myUid, bgItemId)
        if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_SLOT_DATA_UPDATE then
            EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_SLOT_DATA_UPDATE)
        end
        return true
    end)
    return ok and applied == true
end

function _G.UnlockAllCollectionPlatforms()
    local ok, refreshed = pcall(function()
        local ModuleManager = require("client.module_framework.ModuleManager")
        if not ModuleManager or not ModuleManager.LobbyModuleConfig then return false end
        local Logic = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.Logic_SocialLobbyModule)
        if not Logic then return false end
        -- Keep the game's native unlock checks and edit/save revision checks.
        -- Client-only overrides can make locked slots look editable, but the
        -- server will not persist placements in slots the account has not unlocked.
        if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_SLOT_DATA_UPDATE then
            EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_SLOT_DATA_UPDATE)
        end
        return true
    end)
    return ok and refreshed == true
end

_G.LoadCollectionHallScene()
_G.UnlockAllCollectionPlatforms()
