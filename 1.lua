-- ============================================================================
-- Rapzhang Skin Module - rebuild 4.7 (simple + lazy)
-- ----------------------------------------------------------------------------
-- Tujuan rebuild:
--   * tidak ada katalog 16 ribu item di dalam file (load pertama ringan);
--   * depot hanya diisi untuk tab wardrobe yang sedang dibuka;
--   * pemakaian item tetap lewat alur wardrobe normal (klik -> pakai);
--   * X-Suit otomatis bintang tertinggi, skin senjata otomatis level tertinggi;
--   * granade memakai jalur animasi native.
--
-- Struktur file:
--   1. util + state + persistence
--   2. depot + injeksi lazy per tab
--   3. pakai item (outfit, aksesori, tas, helm, parasut, glider, throwable)
--   4. senjata + X-Suit
--   5. apply lobby + match
--   6. hook + bootstrap
-- ============================================================================

local F = {}
_G.AddOutfit = F
F.version = "4.7-simple-r1"

local function log(...)
    if _G.RAPZHANG_DEBUG then print("[AddOutfit]", ...) end
end
F.log = log

local function tryRequire(name)
    local ok, mod = pcall(require, name)
    if ok then return mod end
    return nil
end
F.requireModule = tryRequire

local TICKER
pcall(function() TICKER = require("common.time_ticker") end)

function F.later(sec, fn)
    if _G.SetTimer then
        pcall(_G.SetTimer, sec, fn)
        return true
    end
    local ticker = TICKER or _G._ticker
    if ticker and ticker.AddTimer then
        pcall(ticker.AddTimer, sec, fn)
        return true
    end
    return false
end

-- ============================================================================
-- KONSTANTA
-- ============================================================================
local INS_BASE        = 2000000000
local PKG_SLOT        = 3
local MELEE_ID        = 108
local HAT_SUB         = 401
local MASK_SUB        = 402
local OUTFIT_SUB      = 403
local PANTS_SUB       = 404
local SHOES_SUB       = 405
local GLASS_SUB       = 407
local GLIDER_SUB      = 415
local GLOVES_SUB      = 452
local PARACHUTE_SUB   = 701
local TAB_CLOTHES     = 3
local TAB_SUIT        = 10
local HALL_THEME_TYPE = 202

local HAT_SUBS    = { [401] = true }
local HEAD_SUBS   = { [401] = true }
local FACE_SUBS   = { [402] = true, [407] = true }
local BAG_SUBS    = { [501] = true, [504] = true }
local HELMET_SUBS = { [502] = true, [505] = true }
local BODY_SUBS   = { [404] = true, [405] = true, [501] = true, [504] = true, [502] = true, [505] = true }
local GUN_SUB     = { [101] = true, [102] = true, [103] = true, [104] = true, [105] = true, [106] = true, [107] = true }
local GLIDER_SUBS = { [413] = true, [414] = true, [415] = true }
local THROW_SUBS  = { [612] = "shoulei", [613] = "smoke", [614] = "stun", [615] = "burn" }
local THROW_SUB_BY_KIND = {}
for st, kind in pairs(THROW_SUBS) do THROW_SUB_BY_KIND[kind] = st end
local THROW_AVATAR_KEYS = {
    shoulei = "GrenadeAvatarShoulei",
    smoke   = "GrenadeAvatarSmoke",
    stun    = "GrenadeAvatarStun",
    burn    = "GrenadeAvatarBurn",
}
local THROW_WEAPON_TO_SUB = { [602001] = 614, [602002] = 613, [602003] = 615, [602004] = 612 }
local NET_OK = NetErrorCode_NONE or "ok"

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

-- ============================================================================
-- STATE
-- ============================================================================
local R = { insToRes = {}, resToIns = {} }
local META = {}                       -- resID -> metadata Item
local C = {                           -- cache pilihan yang sedang dipakai
    slots = {},
    ins = {},
    weapons = {},                     -- weaponID -> { resID, insID }
    throw = {},                       -- subType -> { resID, insID }
    vehicle = nil,                    -- { sub, res, ins }
}
F._state = R
F._cache = C

local PERSIST = {
    path = nil,
    dirty = false,
    scheduled = false,
    lastWritten = nil,
    loaded = false,
}
F._persist = PERSIST

local S = {                           -- state depot / tab
    entity = nil,
    page = nil,
    sub = nil,
    jobs = {},
    jobsByKey = {},
    done = {},
    rows = {},
    seq = 0,
    gen = 0,
    pumpScheduled = false,
    refresh = false,
    nonMax = nil,
    table = nil,                      -- fallback: Item table penuh (sekali)
    applied = false,
    weaponApplied = false,
}
F._depot = S

function F.cache()
    C.slots = C.slots or {}
    C.ins = C.ins or {}
    C.weapons = C.weapons or {}
    C.throw = C.throw or {}
    return C
end

-- ============================================================================
-- HELPER UMUM
-- ============================================================================
function F.getPC()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    local gd = tryRequire("GameLua.GameCore.Data.GameplayData")
    if gd and gd.GetPlayerController then
        local ok, pc = pcall(gd.GetPlayerController)
        if ok and slua.isValid(pc) then return pc end
    end
    return nil
end

function F.getLocalChar()
    local GD = tryRequire("GameLua.GameCore.Data.GameplayData")
    if not GD or not GD.GetPlayerCharacter then return nil end
    local ok, char = pcall(GD.GetPlayerCharacter)
    if ok and slua.isValid(char) then return char end
    return nil
end

function F.isInRealMatch()
    local ok, r = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    return ok and r == true
end

function F.isInLobby()
    local ok, r = pcall(function()
        return not GameStatus or not GameStatus.IsInLobbyOrMainCity or GameStatus.IsInLobbyOrMainCity()
    end)
    return ok and r == true
end

function F.cfg(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    if not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

-- Metadata yang dibutuhkan entity/depot.  Disimpan sebagai angka kecil,
-- bukan salinan penuh tabel Item, supaya RAM tetap rendah.
function F.meta(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    local m = META[resID]
    if m ~= nil then return m end
    local c = F.cfg(resID)
    -- Jangan cache "tidak ada": tabel Item bisa belum siap saat file di-load,
    -- dan hasil negatif yang tersimpan permanen akan membuat item tidak bisa
    -- dipakai setelah tabel tersedia.
    if not c then return nil end
    m = {
        type    = tonumber(c.ItemType) or 0,
        sub     = tonumber(c.ItemSubType or c.itemSubType) or 0,
        main    = tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0,
        tab     = tonumber(c.WardrobeTab or c.wardrobeTab) or 0,
        quality = tonumber(c.ItemQuality or c.itemQuality) or 0,
        name    = c.ItemName or c.itemName or c.Name,
    }
    META[resID] = m
    return m
end

function F.subTypeOf(resID)
    local m = F.meta(resID)
    return m and m.sub or nil
end

function F.wardrobeTab(resID)
    local m = F.meta(resID)
    return m and m.tab or 0
end

function F.wardrobeMainTab(resID)
    local m = F.meta(resID)
    return m and m.main or 0
end

function F.isSuitRes(resID)
    local m = F.meta(resID)
    if not m or m.sub ~= OUTFIT_SUB then return false end
    return m.tab ~= TAB_CLOTHES
end

function F.isTshirtRes(resID)
    local m = F.meta(resID)
    return m and m.sub == OUTFIT_SUB and m.tab == TAB_CLOTHES
end

function F.isParachuteRes(resID)
    local m = F.meta(resID)
    if not m then return false end
    return m.sub == PARACHUTE_SUB
end

function F.isGlideRes(resID)
    local m = F.meta(resID)
    if not m then return false end
    if GLIDER_SUBS[m.sub] == true then return true end
    local ok, hit = pcall(function()
        local MDH = tryRequire("client.logic.avatar.ModelDisplayTypeHelper")
        if MDH and MDH.IsGlideByItemID and MDH.IsGlideByItemID(resID) then return true end
        local wd = tryRequire("client.slua.logic.wardrobe.wardrobe_data")
        return wd and wd.IsGlideType and wd:IsGlideType(m.sub) == true
    end)
    return ok and hit == true
end

function F.isThrowRes(resID)
    return THROW_SUBS[tonumber(F.subTypeOf(resID) or 0)] ~= nil
end

function F.throwObjectSubtype(resID)
    local st = tonumber(F.subTypeOf(resID) or 0)
    if THROW_SUBS[st] then return st end
    return nil
end

function F.isVehicleRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local m = F.meta(resID)
    if not m then return false end
    -- Halaman kendaraan adalah satu-satunya tempat item kendaraan muncul.
    -- Memakai sub-type >= 900 saja berisiko menangkap item halaman lain
    -- (mis. hall theme), jadi penanda utamanya adalah WardrobeMainTab.
    return m.main == 6
end

function F.slotKeyOf(resID)
    local m = F.meta(resID)
    if not m then return nil end
    local st = m.sub
    if st == OUTFIT_SUB then return m.tab == TAB_CLOTHES and "tshirt" or "outfit" end
    if st == HAT_SUB or HEAD_SUBS[st] then return "hat" end
    if st == MASK_SUB then return "mask" end
    if st == GLASS_SUB then return "glass" end
    if st == PANTS_SUB then return "pants" end
    if st == SHOES_SUB then return "shoes" end
    if BAG_SUBS[st] then return "bag" end
    if HELMET_SUBS[st] then return "helmet" end
    if F.isParachuteRes(resID) then return "parachute" end
    if F.isGlideRes(resID) then return "glider" end
    if st == GLOVES_SUB then return "gloves" end
    return nil
end

function F.resToCustSlot(resID)
    local key = F.slotKeyOf(resID)
    if key == "outfit" or key == "tshirt" then return F.CUST_SLOT.ClothesEquipemtSlot end
    if key == "pants" then return F.CUST_SLOT.PantsEquipemtSlot end
    if key == "shoes" then return F.CUST_SLOT.ShoesEquipemtSlot end
    if key == "hat" then return F.CUST_SLOT.HatEquipemtSlot end
    if key == "mask" then return F.CUST_SLOT.FaceEquipemtSlot end
    if key == "glass" then return F.CUST_SLOT.GlassEquipemtSlot end
    if key == "bag" then return F.CUST_SLOT.BackpackEquipemtSlot end
    if key == "helmet" then return F.CUST_SLOT.HelmetEquipemtSlot end
    if key == "parachute" then return F.CUST_SLOT.ParachuteEquipemtSlot end
    if key == "glider" then return F.CUST_SLOT.GlideEquipemtSlot end
    if key == "gloves" then return F.CUST_SLOT.HandEffectEquipemtSlot end
    return nil
end

function F.weaponIdFromSkin(resID)
    resID = tonumber(resID)
    if not resID then return nil end
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
    if m then return tonumber(m.WeaponID or m.WeaponId or m.weaponId) end
    return nil
end

function F.isInjectedIns(ins)
    ins = tonumber(ins)
    return ins ~= nil and R.insToRes[ins] ~= nil
end

function F.isInjectedRes(res)
    res = tonumber(res)
    return res ~= nil and R.resToIns[res] ~= nil
end

-- ============================================================================
-- JSON sederhana (encode + decode) untuk file pilihan
-- ============================================================================
local json = {}

local function jsonQuote(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    return '"' .. s .. '"'
end

local function isArray(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
        if k > n then n = k end
    end
    return n > 0 and n == #t
end

local function encodeValue(v, out)
    local tv = type(v)
    if tv == "nil" then
        out[#out + 1] = "null"
    elseif tv == "boolean" then
        out[#out + 1] = v and "true" or "false"
    elseif tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            out[#out + 1] = "0"
        else
            out[#out + 1] = tostring(v)
        end
    elseif tv == "string" then
        out[#out + 1] = jsonQuote(v)
    elseif tv == "table" then
        if isArray(v) then
            out[#out + 1] = "["
            for i = 1, #v do
                if i > 1 then out[#out + 1] = "," end
                encodeValue(v[i], out)
            end
            out[#out + 1] = "]"
        else
            out[#out + 1] = "{"
            local first = true
            for k, val in pairs(v) do
                if type(k) == "string" or type(k) == "number" then
                    if not first then out[#out + 1] = "," end
                    first = false
                    out[#out + 1] = jsonQuote(k)
                    out[#out + 1] = ":"
                    encodeValue(val, out)
                end
            end
            out[#out + 1] = "}"
        end
    else
        out[#out + 1] = "null"
    end
end

function json.encode(v)
    local out = {}
    encodeValue(v, out)
    return table.concat(out)
end

function json.decode(text)
    if type(text) ~= "string" then return nil end
    local pos = 1
    local len = #text

    local function skip()
        while pos <= len do
            local c = text:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then
                pos = pos + 1
            else
                break
            end
        end
    end

    local parseValue

    local function parseString()
        pos = pos + 1
        local buf = {}
        while pos <= len do
            local c = text:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(buf)
            elseif c == "\\" then
                local n = text:sub(pos + 1, pos + 1)
                if n == "n" then buf[#buf + 1] = "\n"
                elseif n == "r" then buf[#buf + 1] = "\r"
                elseif n == "t" then buf[#buf + 1] = "\t"
                elseif n == "b" then buf[#buf + 1] = "\b"
                elseif n == "f" then buf[#buf + 1] = "\f"
                elseif n == "u" then
                    local hex = text:sub(pos + 2, pos + 5)
                    local code = tonumber(hex, 16)
                    if code then buf[#buf + 1] = string.char(code % 256) end
                    pos = pos + 4
                else
                    buf[#buf + 1] = n
                end
                pos = pos + 2
            else
                buf[#buf + 1] = c
                pos = pos + 1
            end
        end
        return nil
    end

    local function parseNumber()
        local start = pos
        if text:sub(pos, pos) == "-" then pos = pos + 1 end
        while pos <= len do
            local c = text:sub(pos, pos)
            if c:match("[%d%.eE%+%-]") then pos = pos + 1 else break end
        end
        return tonumber(text:sub(start, pos - 1))
    end

    parseValue = function()
        skip()
        if pos > len then return nil end
        local c = text:sub(pos, pos)
        if c == "{" then
            pos = pos + 1
            local obj = {}
            skip()
            if text:sub(pos, pos) == "}" then pos = pos + 1; return obj end
            while pos <= len do
                skip()
                if text:sub(pos, pos) ~= '"' then break end
                local key = parseString()
                skip()
                if text:sub(pos, pos) ~= ":" then break end
                pos = pos + 1
                obj[key] = parseValue()
                skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d ~= "," then break end
            end
            return obj
        elseif c == "[" then
            pos = pos + 1
            local arr = {}
            skip()
            if text:sub(pos, pos) == "]" then pos = pos + 1; return arr end
            while pos <= len do
                arr[#arr + 1] = parseValue()
                skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d ~= "," then break end
            end
            return arr
        elseif c == '"' then
            return parseString()
        elseif c == "t" then
            pos = pos + 4
            return true
        elseif c == "f" then
            pos = pos + 5
            return false
        elseif c == "n" then
            pos = pos + 4
            return nil
        else
            return parseNumber()
        end
    end

    local ok, result = pcall(parseValue)
    if ok then return result end
    return nil
end

F.json = json

-- ============================================================================
-- PERSISTENCE
-- ============================================================================
local CONFIG_NAME = "rapzhang_outfit.json"
local CONFIG_PATHS = {
    "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME,
    "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME,
    "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME,
    "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME,
    "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME,
    "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME,
    "/Documents/ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME,
    "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. CONFIG_NAME,
    "ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME,
    "../../ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME,
}
do
    local home = os and os.getenv and os.getenv("HOME")
    if home and home ~= "" then
        table.insert(CONFIG_PATHS, 1, home .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. CONFIG_NAME)
    end
end

local SLOT_IDS = { "outfit", "tshirt", "pants", "shoes", "hat", "mask", "glass", "bag", "helmet", "parachute", "glider", "gloves" }

local WEAPON_NAME_TO_ID = {
    ["AKM"]=101001, ["M16A4"]=101002, ["SCAR-L"]=101003, ["M416"]=101004,
    ["Groza"]=101005, ["AUG"]=101006, ["QBZ"]=101007, ["M762"]=101008,
    ["G36C"]=101009, ["Mk47"]=101010, ["Honey Badger"]=101012, ["FAMAS"]=101100,
    ["ACE32"]=101101, ["ASM Abakan"]=101102, ["UZI"]=102001, ["UMP45"]=102002,
    ["Vector"]=102003, ["Tommy Gun"]=102004, ["Bizon"]=102005, ["MP5K"]=102007,
    ["PP-19"]=102008, ["P90"]=102105, ["Kar98K"]=103001, ["M24"]=103002,
    ["AWM"]=103003, ["SKS"]=103004, ["VSS"]=103005, ["Mini14"]=103006,
    ["Mk14"]=103007, ["QBU"]=103008, ["QBU-Variant"]=103101, ["SLR"]=103009,
    ["Win94"]=103010, ["Mosin-Nagant"]=103011, ["AMR"]=103012, ["Mk12"]=103100,
    ["DSR"]=103102, ["M1 Garand"]=103103, ["S686"]=104001, ["S1897"]=104002,
    ["S12K"]=104003, ["DBS"]=104004, ["NS2000"]=104101, ["S1897-Variant"]=104102,
    ["M249"]=105001, ["DP-28"]=105002, ["MG3"]=105010, ["P92"]=106001,
    ["P1911"]=106002, ["R1895"]=106003, ["P18C"]=106004, ["Desert Eagle"]=106005,
    ["Scorpion"]=106006, ["Crossbow"]=107001, ["Tactical Crossbow"]=107007,
    ["MGL"]=107008, ["Melee"]=108, ["Pan"]=108, ["Dagger"]=108, ["Machete"]=108,
}

local function weaponIdFromKey(key)
    local n = tonumber(key)
    if n then return n end
    return WEAPON_NAME_TO_ID[tostring(key)]
end

function F.persistRemember(slot, resID)
    resID = tonumber(resID)
    if not slot or not resID or resID <= 0 then return end
    C.slots[slot] = resID
end

function F.persistForget(slot)
    if slot then C.slots[slot] = nil end
end

function F.persistEncode()
    local out = { version = 2 }
    for _, key in ipairs(SLOT_IDS) do
        local res = tonumber(C.slots[key])
        if res and res > 0 then out[key] = res end
    end
    if next(C.weapons) then
        out.weapons = {}
        for wid, w in pairs(C.weapons) do
            wid = tonumber(wid)
            local res = w and tonumber(w.resID)
            if wid and res and res > 0 then
                out.weapons[tostring(wid)] = res
            end
        end
    end
    if next(C.throw) then
        out.throwObjects = {}
        for st, rec in pairs(C.throw) do
            st = tonumber(st)
            local res = rec and tonumber(rec.resID)
            if st and THROW_SUBS[st] and res and res > 0 then
                out.throwObjects[tostring(st)] = res
            end
        end
    end
    if C.vehicle and tonumber(C.vehicle.res) then
        out.lobbyVehicleSubType = tonumber(C.vehicle.sub) or 0
        out.lobbyVehicleResID = tonumber(C.vehicle.res)
    end
    return json.encode(out) .. "\n"
end

function F.persistWrite(text)
    if not (io and io.open) then return false end
    if PERSIST.path then
        local f
        pcall(function() f = io.open(PERSIST.path, "w") end)
        if f then
            pcall(function() f:write(text) f:close() end)
            return true
        end
        PERSIST.path = nil
    end
    for _, path in ipairs(CONFIG_PATHS) do
        local f
        pcall(function() f = io.open(path, "w") end)
        if not f then
            pcall(function()
                local dir = path:match("^(.*)/[^/]+$")
                if dir and os and os.execute then os.execute('mkdir -p "' .. dir .. '" 2>/dev/null') end
            end)
            pcall(function() f = io.open(path, "w") end)
        end
        if f then
            pcall(function() f:write(text) f:close() end)
            PERSIST.path = path
            return true
        end
    end
    return false
end

function F.persistFlush()
    if not PERSIST.dirty then return end
    PERSIST.dirty = false
    pcall(function()
        local text = F.persistEncode()
        if text == PERSIST.lastWritten then return end
        if F.persistWrite(text) then
            PERSIST.lastWritten = text
        end
    end)
end

function F.persistMarkDirty()
    PERSIST.dirty = true
    if PERSIST.scheduled then return end
    PERSIST.scheduled = true
    F.later(1.5, function()
        PERSIST.scheduled = false
        F.persistFlush()
    end)
end

function F.persistParse(text)
    if not text or #text == 0 then return nil end
    local data = json.decode(text)
    if type(data) ~= "table" then
        -- File lama / rusak: ambil pasangan "key": angka saja.
        data = {}
        for key, value in text:gmatch('"([%w_]+)"%s*:%s*(%d+)') do
            data[key] = tonumber(value)
        end
    end
    local out = { weapons = {}, throwObjects = {} }
    local slots = data.slots
    for _, key in ipairs(SLOT_IDS) do
        local res = tonumber(data[key]) or (type(slots) == "table" and tonumber(slots[key])) or nil
        if res and res > 0 then out[key] = res end
    end
    if type(data.weapons) == "table" then
        for k, v in pairs(data.weapons) do
            local wid, res = weaponIdFromKey(k), tonumber(v)
            if wid and res and res > 0 then out.weapons[wid] = res end
        end
    end
    if type(data.throwObjects) == "table" then
        for k, v in pairs(data.throwObjects) do
            local st, res = tonumber(k), tonumber(v)
            if st and THROW_SUBS[st] and res and res > 0 then out.throwObjects[st] = res end
        end
    end
    out.vehicleSub = tonumber(data.lobbyVehicleSubType)
    out.vehicleRes = tonumber(data.lobbyVehicleResID)
    if not out.vehicleRes and type(data.vehicleSlots) == "table" then
        local bestSub, bestRes
        for st, slotsMap in pairs(data.vehicleSlots) do
            local nst = tonumber(st)
            if nst and type(slotsMap) == "table" then
                for _, res in pairs(slotsMap) do
                    local nres = tonumber(res)
                    if nres and nres > 0 then
                        bestSub, bestRes = nst, nres
                        break
                    end
                end
            end
            if bestRes then break end
        end
        out.vehicleSub, out.vehicleRes = bestSub, bestRes
    end
    return out
end

function F.persistLoad()
    if PERSIST.loaded then return PERSIST.loaded end
    PERSIST.loaded = true
    local saved
    pcall(function()
        for _, path in ipairs(CONFIG_PATHS) do
            local f
            pcall(function() f = io.open(path, "r") end)
            if f then
                local text
                pcall(function() text = f:read("*a") f:close() end)
                if text and #text > 0 then
                    PERSIST.path = path
                    PERSIST.lastWritten = text
                    saved = F.persistParse(text)
                    break
                end
                pcall(function() f:close() end)
            end
        end
    end)
    saved = saved or {}
    for _, key in ipairs(SLOT_IDS) do
        local res = tonumber(saved[key])
        if res and res > 0 then C.slots[key] = res end
    end
    for wid, res in pairs(saved.weapons or {}) do
        wid, res = tonumber(wid), tonumber(res)
        if wid and res then C.weapons[wid] = { resID = res } end
    end
    for st, res in pairs(saved.throwObjects or {}) do
        st, res = tonumber(st), tonumber(res)
        if st and res and THROW_SUBS[st] then C.throw[st] = { resID = res } end
    end
    if saved.vehicleRes and saved.vehicleRes > 0 then
        C.vehicle = { sub = saved.vehicleSub, res = saved.vehicleRes }
    end
    return saved
end
-- ============================================================================
-- DEPOT + INJEKSI LAZY PER TAB
-- ----------------------------------------------------------------------------
-- Tidak ada daftar item di file.  Saat wardrobe dibuka, hanya baris Item yang
-- cocok dengan halaman/sub-tab aktif yang diambil dari CDataTable lalu
-- dimasukkan ke depot.  Login tidak menyentuh katalog sama sekali.
-- ============================================================================

function F.getEntity()
    if not F._dc then
        F._dc = tryRequire("client.slua.logic.wardrobe.logic_wardrobe_data_center") or false
    end
    local dc = F._dc
    if dc and dc.GetWardrobeData then
        local ok, e = pcall(dc.GetWardrobeData)
        if ok and e then
            S.entity = e
            return e
        end
    end
    return S.entity
end

function F.findNativeIns(entity, resID)
    local arr = entity and entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if not arr then return nil end
    for _, idx in pairs(arr) do
        local d = entity._data and entity._data[idx]
        if d then
            local ins = tonumber(d.insID or d.instid or d.ins_id)
            if ins then return ins, d end
        end
    end
    return nil
end

-- Tandai resource yang harus selalu ada di depot (pilihan tersimpan /
-- sedang dipakai).  Dipakai ulang setelah depot di-init ulang oleh game.
function F.markNeed(resID)
    resID = tonumber(resID)
    if resID and resID > 0 then S.need = S.need or {}; S.need[resID] = true end
end

function F.rehydrate()
    local need = S.need
    if need then
        for res in pairs(need) do
            pcall(F.ensureRow, res)
        end
    end
end

-- Buat / ambil baris depot untuk sebuah resource.
-- rowMeta (opsional) berasal dari hasil filter Item, sehingga tidak perlu
-- satu panggilan CDataTable.GetTableData per baris.
function F.ensureRow(resID, rowMeta)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end

    local meta = rowMeta
    if not meta then
        local cached = META[resID]
        if type(cached) == "table" then meta = cached end
    end
    if meta then META[resID] = meta else meta = F.meta(resID) end
    if not meta then return nil end

    local entity = F.getEntity()
    local ins = R.resToIns[resID]

    if entity then
        if ins and entity.InsIDToIndexMap then
            local idx = entity.InsIDToIndexMap[ins]
            local row = idx and entity._data and entity._data[idx]
            if row then return ins end
        end
        local nativeIns, nativeRow = F.findNativeIns(entity, resID)
        if nativeIns then
            R.resToIns[resID] = nativeIns
            R.insToRes[nativeIns] = resID
            if nativeRow then
                nativeRow.expireTS = 0
                nativeRow.expire_ts = 0
                if nativeRow.validHours ~= nil then nativeRow.validHours = 0 end
                if nativeRow.valid_hours ~= nil then nativeRow.valid_hours = 0 end
            end
            return nativeIns
        end
    end

    if not ins then
        S.seq = (S.seq or 0) + 1
        ins = INS_BASE + S.seq
        R.resToIns[resID] = ins
        R.insToRes[ins] = resID
    end

    if not entity or not entity.bInit or not entity.AddData then
        return ins
    end

    local row = {
        instid = ins,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    }
    local ok = pcall(function() entity:AddData(row) end)
    if not ok then return nil end

    local idx = tonumber(entity._DataCount)
    local d = idx and entity._data and entity._data[idx]
    if d then
        d.itemType = meta.type or 0
        d.itemSubType = meta.sub or 0
        d.mainTabType = meta.main or 0
        d.subTabType = meta.tab or 0
        d.itemQuality = meta.quality or 0
        d.bConfigLoaded = true
        d.expireTS = 0
        d.expire_ts = 0
        d.validHours = 0
        d.valid_hours = 0
        d.color = d.color or 0
        d.pattern = d.pattern or 0
        d.colorID = d.colorID or 0
        d.patternID = d.patternID or 0
    end
    S.gen = (S.gen or 0) + 1
    return ins
end

function F.instForRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    F.markNeed(resID)
    return F.ensureRow(resID)
end

function F.resOfIns(insID)
    insID = tonumber(insID)
    if not insID then return nil end
    local res = R.insToRes[insID]
    if res then return res end
    local wd = tryRequire("client.slua.logic.wardrobe.wardrobe_data")
    if wd then
        local d
        pcall(function()
            d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        end)
        if d then
            res = tonumber(d.resID or d.res_id)
            if res then
                R.insToRes[insID] = res
                R.resToIns[res] = insID
                return res
            end
        end
    end
    return nil
end

-- Item upgrade (skin senjata) punya beberapa level dengan GroupID yang sama.
-- Level selain tertinggi tidak perlu ditampilkan/di-inject; pemilihan tetap
-- dinormalisasi ke level tertinggi saat dipakai.
function F.buildNonMaxSet()
    if S.nonMax ~= nil then return S.nonMax end
    local set, ready = {}, false
    pcall(function()
        if not CDataTable or not CDataTable.GetTable then return end
        local up = CDataTable.GetTable("ItemUpgradeConfig")
        if type(up) ~= "table" or next(up) == nil then return end
        ready = true
        local best, members = {}, {}
        for _, cfg in pairs(up) do
            local gid = tonumber(cfg.GroupID)
            local lvl = tonumber(cfg.Level)
            local itm = tonumber(cfg.ItemID)
            if gid and lvl and itm then
                members[gid] = members[gid] or {}
                members[gid][#members[gid] + 1] = itm
                if not best[gid] or lvl > best[gid].lvl then
                    best[gid] = { lvl = lvl, item = itm }
                end
            end
        end
        for gid, list in pairs(members) do
            local top = best[gid] and best[gid].item
            for _, itm in ipairs(list) do
                if itm ~= top then set[itm] = true end
            end
        end
    end)
    -- Tabel upgrade bisa belum ter-load saat tab pertama dibuka.  Jangan
    -- simpan hasil kosong, supaya percobaan berikutnya masih bisa memfilter.
    if ready then S.nonMax = set end
    return set
end

local function rowResID(row)
    return tonumber(row.ItemID or row.Id or row.ID or row.id or row.ItemId)
end

local function rowMeta(row)
    return {
        type    = tonumber(row.ItemType or row.itemType) or 0,
        sub     = tonumber(row.ItemSubType or row.itemSubType) or 0,
        main    = tonumber(row.WardrobeMainTab or row.wardrobeMainTab) or 0,
        tab     = tonumber(row.WardrobeTab or row.wardrobeTab) or 0,
        quality = tonumber(row.ItemQuality or row.itemQuality) or 0,
        name    = row.ItemName or row.itemName,
    }
end

local function normalizeRows(rows)
    local out = {}
    if type(rows) ~= "table" then return out end
    for _, row in pairs(rows) do
        if type(row) == "table" and rowResID(row) then
            out[#out + 1] = row
        end
    end
    return out
end

-- Sumber data utama: filter native di C++ (hanya baris satu tab).
function F.fetchTabRows(page, sub)
    page = tonumber(page)
    if not page or page <= 0 then return {} end
    local nonMax = F.buildNonMaxSet()
    local function accept(row)
        local res = rowResID(row)
        if not res then return nil end
        if nonMax[res] then
            local st = tonumber(row.ItemSubType or row.itemSubType) or 0
            if GUN_SUB[st] or st == MELEE_ID then return nil end
        end
        return true
    end

    local filter = CDataTable and CDataTable.GetTableByFilter
    if filter then
        local ok, rows = pcall(filter, "Item", "WardrobeMainTab", page, "WardrobeTab", sub)
        if ok and type(rows) == "table" then
            local out = {}
            for _, row in pairs(rows) do
                if type(row) == "table" and accept(row) then out[#out + 1] = row end
            end
            return out
        end
    end

    local idsFilter = CDataTable and CDataTable.GetTableDataByFilter
    if idsFilter then
        local ok, rows = pcall(idsFilter, "Item", "WardrobeMainTab", page, "WardrobeTab", sub)
        if ok and type(rows) == "table" then
            local out = {}
            for _, item in pairs(rows) do
                local res = type(item) == "table" and rowResID(item) or tonumber(item)
                local cfg = res and F.cfg(res)
                if cfg and accept(cfg) then out[#out + 1] = cfg end
            end
            if #out > 0 then return out end
        end
    end

    -- Fallback build lama: Item table penuh, sekali saja, difilter di Lua.
    if not S.table then
        local ok, tbl = pcall(function() return CDataTable.GetTable("Item") end)
        S.table = (ok and type(tbl) == "table") and tbl or false
    end
    local out = {}
    if S.table then
        for _, row in pairs(S.table) do
            if type(row) == "table" then
                local main = tonumber(row.WardrobeMainTab or row.wardrobeMainTab) or 0
                local tab = tonumber(row.WardrobeTab or row.wardrobeTab) or 0
                if main == page and (sub == nil or tostring(tab) == tostring(sub)) and accept(row) then
                    out[#out + 1] = row
                end
            end
        end
    end
    S.table = nil
    return out
end

function F.schedulePump(delay)
    if S.pumpScheduled then return end
    S.pumpScheduled = true
    F.later(delay or 0, function()
        S.pumpScheduled = false
        F.pump()
    end)
end

function F.pump()
    local job = S.jobs[1]
    if not job then return end
    local entity = F.getEntity()
    if not entity or not entity.bInit then
        F.schedulePump(0.25)
        return
    end

    local t0 = os.clock()
    local rows = job.rows
    local n = #rows
    local i = job.i
    while i < n do
        local last = math.min(i + 24, n)
        for k = i + 1, last do
            local row = rows[k]
            local res = rowResID(row)
            if res then
                pcall(F.ensureRow, res, rowMeta(row))
            end
        end
        i = last
        if (os.clock() - t0) > 0.005 then break end
    end
    job.i = i

    if i >= n then
        table.remove(S.jobs, 1)
        S.jobsByKey[job.key] = nil
        S.done[job.key] = true
        S.gen = S.gen + 1
        F.refreshWardrobe()
        if #S.jobs > 0 then F.schedulePump(0.05) end
    else
        F.schedulePump(0.02)
    end
end

function F.requestTab(page, sub, force)
    page = tonumber(page)
    if not page or page <= 0 then return false end
    S.page = page
    S.sub = sub
    -- Tanpa sub-tab tidak ada daftar yang bisa difilter dengan benar; tunggu
    -- OnShow dari daftar sub-tab (selalu dipanggil saat panel dibuka).
    if sub == nil then return false end
    sub = tonumber(sub) or sub
    local key = tostring(page) .. ":" .. tostring(sub)
    if S.done[key] and not force then return true end
    if S.jobsByKey[key] then return true end

    -- Tab lain yang belum selesai dibuang: pemain sudah pindah tab.
    for i = #S.jobs, 1, -1 do
        local job = S.jobs[i]
        if job.key ~= key then
            S.jobsByKey[job.key] = nil
            table.remove(S.jobs, i)
        end
    end

    local rows = F.fetchTabRows(page, sub)
    S.jobsByKey[key] = true
    S.jobs[#S.jobs + 1] = { key = key, page = page, sub = sub, rows = rows, i = 0 }
    if #rows == 0 then
        S.jobsByKey[key] = nil
        table.remove(S.jobs)
        S.done[key] = true
        return true
    end
    F.schedulePump(0)
    return true
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
        end
    end)
end

local sliceCache = { key = nil }

function F.slice(entity, page, sub)
    local count = tonumber(entity._DataCount) or 0
    local key = tostring(page) .. ":" .. tostring(sub) .. ":" .. count .. ":" .. tostring(S.gen)
    if sliceCache.key == key then return sliceCache.data end
    local data
    pcall(function() data = entity:GetData(true) end)
    if type(data) ~= "table" then return data or {} end
    local out = {}
    -- Sub-tab menu memakai angka; beberapa jalur memakai string ("Gun").
    local want = sub ~= nil and tostring(sub) or nil
    for i = 1, count do
        local v = data[i]
        if v then
            local mt = tonumber(v.mainTabType)
            local st = tonumber(v.subTabType)
            if mt == nil or st == nil then
                -- Baris native yang confignya belum dikonversi: biarkan filter
                -- native yang memutuskan, supaya item asli tidak hilang.
                out[#out + 1] = v
            elseif mt == page and (want == nil or tostring(st) == want) then
                out[#out + 1] = v
            end
        end
    end
    sliceCache.key = key
    sliceCache.data = out
    return out
end

-- ============================================================================
-- HOOK WARDROBE
-- ============================================================================
function F.hookSubTabList(tries)
    if S.listHooked then return true end
    tries = (tries or 0) + 1
    local Sub = tryRequire("client.slua.umg.Wardrobe.subtab_item_list_base")
    local getArray = Sub and Sub.GetArrayHallDepotItemInfo
    if not getArray then
        -- Modul UI baru di-require saat wardrobe dibuka.  Coba lagi beberapa
        -- kali; pemicu Enter juga memanggil ulang fungsi ini.
        if tries <= 20 then
            F.later(0.25, function() pcall(F.hookSubTabList, tries) end)
        end
        return false
    end
    S.listHooked = true

    local onShow = Sub.OnShow
    if onShow then
        Sub.OnShow = function(self, ...)
            pcall(function()
                local cfg = self.subTabConfig
                local page = cfg and tonumber(cfg.pageId)
                local sub = cfg and cfg.subTabId
                if page and page > 0 then
                    S.page = page
                    F.requestTab(page, sub)
                end
            end)
            return onShow(self, ...)
        end
    end

    Sub.GetArrayHallDepotItemInfo = function(self)
        local cfg = self.subTabConfig
        local page = cfg and tonumber(cfg.pageId)
        if not page or page <= 0 then return getArray(self) end
        local sub = cfg and cfg.subTabId
        S.page = page
        if sub ~= nil then F.requestTab(page, sub) end
        local entity
        pcall(function() entity = self:GetDataEntity() end)
        if not entity then return getArray(self) end
        -- GetData(true): jangan jalankan EnsureAllConfigLoaded untuk semua
        -- baris depot (itu sumber freeze saat wardrobe pertama dibuka).
        return F.slice(entity, page, sub)
    end
    return true
end

function F.hookWardrobe()
    local wl = tryRequire("client.slua.logic.wardrobe.logic_wardrobe_new")
    if not wl or wl._rzHooked then return end
    wl._rzHooked = true

    local enter = wl.Enter
    if enter then
        wl.Enter = function(self, page, sub, ...)
            pcall(F.hookSubTabList)
            local result = enter(self, page, sub, ...)
            -- Modul daftar sub-tab baru ada setelah ShowUI; pasang sesudahnya
            -- dan ulangi sebentar lagi kalau UMG masih dibuat.
            pcall(F.hookSubTabList)
            pcall(F.later, 0.2, function()
                pcall(F.installHooks)
                pcall(F.hookSubTabList)
            end)
            pcall(function()
                local p = tonumber(page)
                if not p or p <= 0 then
                    p = tonumber(self.GetCurrentPageId and self:GetCurrentPageId())
                end
                if not p or p <= 0 then p = 1 end
                S.page = p
                if sub ~= nil then
                    F.requestTab(p, sub)
                end
            end)
            return result
        end
    end

    local setPage = wl.SetCurrentPageId
    if setPage then
        wl.SetCurrentPageId = function(self, page, ...)
            setPage(self, page, ...)
            local p = tonumber(page)
            if not p or p <= 0 then
                S.page = nil
                S.sub = nil
            else
                S.page = p
                S.sub = nil
            end
        end
    end
end

function F.hookDepotInit()
    local WDE = tryRequire("client.slua.logic.wardrobe.WardrobeDataEntity")
    if not WDE or WDE._rzInitHooked then return end
    WDE._rzInitHooked = true
    local orig = WDE.InitData
    if not orig then return end
    WDE.InitData = function(self, pkg)
        local result = orig(self, pkg)
        S.entity = self
        S.gen = (S.gen or 0) + 1
        S.jobs = {}
        S.jobsByKey = {}
        S.done = {}
        sliceCache.key = nil
        pcall(F.rehydrate)
        return result
    end
end

function F.hookWardrobeData()
    local wd = tryRequire("client.slua.logic.wardrobe.wardrobe_data")
    if not wd or wd._rzDataHooked then return end
    wd._rzDataHooked = true

    local function wrapBool(name)
        local orig = wd[name]
        if not orig then return end
        wd[name] = function(self, id, ...)
            if F.isInjectedRes(tonumber(id)) or F.isInjectedIns(tonumber(id)) then return true end
            return orig(self, id, ...)
        end
    end
    wrapBool("HasItem")
    wrapBool("HasValidItem")
    wrapBool("CheckHasPermanentItem")
end

function F.hookPageFilter()
    local wl = tryRequire("client.slua.logic.wardrobe.logic_wardrobe_new")
    if not wl or wl._rzFilterHooked then return end
    wl._rzFilterHooked = true

    local isValid = wl.IsValidCurrentPageItem
    if isValid then
        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
            if v then
                local res = tonumber(v.resID or v.res_id)
                if res and F.isInjectedRes(res) then
                    local m = F.meta(res)
                    local mt = tonumber(v.mainTabType) or (m and m.main) or 0
                    local st = tonumber(v.subTabType) or (m and m.tab) or 0
                    if mt == mainTab and tostring(st) == tostring(subTab) then return true end
                end
            end
            return isValid(self, mainTab, subTab, v, t)
        end
    end

    local canUse = wl.IsCanUse
    if canUse then
        wl.IsCanUse = function(self, resId, ...)
            if F.isInjectedRes(tonumber(resId)) then return true end
            return canUse(self, resId, ...)
        end
    end

    local charUse = wl.IsCharacterUse
    if charUse then
        wl.IsCharacterUse = function(self, resId, ...)
            if F.isInjectedRes(tonumber(resId)) then return true end
            return charUse(self, resId, ...)
        end
    end

    local getIns = wl.GetWardrobeInsIdByResId
    if getIns then
        wl.GetWardrobeInsIdByResId = function(self, resid, ...)
            resid = tonumber(resid)
            if resid and R.resToIns[resid] then return R.resToIns[resid] end
            return getIns(self, resid, ...)
        end
    end
end
-- ============================================================================
-- PAKAI ITEM (jalur wardrobe normal)
-- ----------------------------------------------------------------------------
-- Semua klik wardrobe berakhir di WardRobeHandler.send_depot_put_on_req.
-- Untuk item hasil injeksi (tidak dikenal server) request itu diganti dengan
-- pemanggilan on_depot_put_on_rsp secara lokal, persis seperti respons server,
-- supaya wear info, fashion bag, dan avatar lobby ikut ter-update seperti
-- pemakaian normal.
-- ============================================================================

function F.vehicleSubType(resID)
    local m = F.meta(tonumber(resID))
    return m and m.sub or nil
end

local function wdModule()
    return tryRequire("client.slua.logic.wardrobe.wardrobe_data")
end

local function avatarDataModule()
    return tryRequire("client.logic.data.AvatarData")
end

local function fashionBagModule()
    return tryRequire("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
end

local function putOnResponse(item, olditem, slot, insID, oldIns)
    local WRH = tryRequire("client.network.Protocol.WardRobeHandler")
    if not WRH or not WRH.on_depot_put_on_rsp then return false end
    local ok = pcall(WRH.on_depot_put_on_rsp, NET_OK, item, olditem, slot, insID, oldIns or 0)
    return ok
end

function F.invalidateApply()
    S.applied = false
    S.weaponApplied = false
end

-- ============================================================================
-- CACHE + PERSISTENCE PILIHAN
-- ============================================================================
function F.saveEquip(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    if F.resolveHighestWearRes and F.isXSuitRes(resID) then
        local upRes, upIns = F.resolveHighestWearRes(resID, insID)
        if upRes and upRes ~= resID and upIns then
            resID, insID = upRes, upIns
            R.resToIns[resID], R.insToRes[insID] = insID, resID
        end
    end

    local key = F.slotKeyOf(resID)
    if key then
        local cch = F.cache()
        cch.slots[key] = resID
        cch.ins[key] = insID
        F.persistRemember(key, resID)
    elseif F.throwObjectSubtype(resID) then
        F.saveThrowObject(resID, insID)
    elseif F.isVehicleRes(resID) then
        C.vehicle = { sub = F.vehicleSubType and F.vehicleSubType(resID) or nil, res = resID, ins = insID }
    else
        local st = tonumber(F.subTypeOf(resID) or 0)
        if GUN_SUB[st] and F.weaponIdFromSkin and F.saveWeaponToCache then
            local wid = F.weaponIdFromSkin(resID)
            if wid then F.saveWeaponToCache(wid, resID, insID) end
        elseif st == MELEE_ID and F.saveWeaponToCache then
            F.saveWeaponToCache(MELEE_ID, resID, insID)
        end
    end
    F.invalidateApply()
    F.persistMarkDirty()
end

function F.saveThrowObject(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    local st = F.throwObjectSubtype(resID)
    if not st then return false end
    C.throw[st] = { resID = resID, insID = insID or R.resToIns[resID] or 0 }
    F.persistMarkDirty()
    return true
end

function F.clearEquipCache(resID)
    local key = F.slotKeyOf(resID)
    if not key then return end
    C.slots[key] = nil
    C.ins[key] = nil
    F.persistForget(key)
    F.invalidateApply()
    F.persistMarkDirty()
end

-- ============================================================================
-- HELPER WEAR
-- ============================================================================
function F.findWornInsBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return nil, nil end
    local wd, AvatarData = wdModule(), avatarDataModule()
    if not wd or not AvatarData then return nil, nil end
    local wear
    pcall(function() wear = AvatarData.GetRoleWear() end)
    for _, ins in pairs(wear or {}) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d
            pcall(function() d = wd:GetHallDepotItemDataByInsID(ins) end)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID or d.res_id)
                if not filterFn or filterFn(res, d) then
                    return ins, res
                end
            end
        end
    end
    return nil, nil
end

function F.removeRoleWearBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return end
    local wd, AvatarData = wdModule(), avatarDataModule()
    if not wd or not AvatarData then return end
    local wear
    pcall(function() wear = AvatarData.GetRoleWear() end)
    for _, ins in pairs(wear or {}) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d
            pcall(function() d = wd:GetHallDepotItemDataByInsID(ins) end)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID or d.res_id)
                if not filterFn or filterFn(res, d) then
                    pcall(function() AvatarData.RemoveRoleWearDataByValue(ins) end)
                end
            end
        end
    end
end

function F.syncFashionBagRolewear()
    pcall(function()
        local fbd = fashionBagModule()
        if fbd and fbd.SaveRolewearToFashionBag and fbd.GetFashionBagUseIndex then
            fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
        end
    end)
end

-- Kadang instance ID sudah diketahui tetapi resID belum (atau sebaliknya).
-- Ini menyatukan sumber: peta internal, entity depot, lalu wardrobe_data.
function F.depotRow(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return nil end
    local entity = F.getEntity()
    if entity and entity.GetDataByInsID then
        local ok, d = pcall(function() return entity:GetDataByInsID(insID) end)
        if ok and d then return d end
    end
    local wd = wdModule()
    if wd then
        local ok, d = pcall(function() return wd:GetHallDepotItemDataByInsID(insID) end)
        if ok and d then return d end
    end
    return nil
end

function F.resolveInsForRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    if R.resToIns[resID] then return R.resToIns[resID] end
    local ins = F.instForRes(resID)
    if ins then return ins end
    local wd = wdModule()
    if wd and wd.GetHallDepotItemListByResID then
        local list
        pcall(function() list = wd:GetHallDepotItemListByResID(resID) end)
        for _, v in pairs(list or {}) do
            local id = tonumber(v.insID or v.instid or v.ins_id)
            if id and id > 0 then
                R.resToIns[resID], R.insToRes[id] = id, resID
                return id
            end
        end
    end
    return nil
end

function F.ensureDepotItemValid(insID, resID)
    insID = tonumber(insID)
    if not insID then return end
    resID = tonumber(resID) or R.insToRes[insID]
    local function clear(d)
        if not d then return end
        d.expire_ts = 0
        if d.expireTS ~= nil then d.expireTS = 0 end
        if d.expireTs ~= nil then d.expireTs = 0 end
        if d.valid_hours ~= nil then d.valid_hours = 0 end
        if d.validHours ~= nil then d.validHours = 0 end
    end
    pcall(function()
        local entity = F.getEntity()
        if entity and entity.GetDataByInsID then clear(entity:GetDataByInsID(insID)) end
        local wd = wdModule()
        if wd then clear(wd:GetHallDepotItemDataByInsID(insID)) end
    end)
    if resID then F.markNeed(resID) end
end

function F.clearItemExpire(itemData, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if type(itemData) == "table" then
        itemData.expireTS = 0
        itemData.expire_ts = 0
        itemData.expireTs = 0
    end
end

function F.isResourcesReady(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if not F.isInjectedRes(resID) then return true end
    local ready = false
    pcall(function()
        local PufferConst = tryRequire("client.slua.logic.download.puffer_const")
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and mgr.GetStateByItemID and PufferConst then
            ready = mgr:GetStateByItemID(resID) == PufferConst.ENUM_DownloadState.Done
        end
    end)
    return ready
end

function F.requestResourceDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    if F.isResourcesReady(resID) then return end
    _G.AddOutfitDownloadQueued = _G.AddOutfitDownloadQueued or {}
    if _G.AddOutfitDownloadQueued[resID] then return end
    _G.AddOutfitDownloadQueued[resID] = true
    pcall(function()
        local PM = tryRequire("client.slua.logic.download.puffer.puffer_manager")
        if PM and PM.GetPufferManager then
            local mgr = PM.GetPufferManager()
            if mgr and mgr.StartDownload then mgr:StartDownload(resID) end
        end
    end)
end

-- ============================================================================
-- PAKAI: OUTFIT / X-SUIT
-- ============================================================================
function F.putOnOutfit(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    local resID = F.resOfIns(insID)
    if not resID or resID <= 0 then return false end
    R.insToRes[insID], R.resToIns[resID] = resID, insID

    -- X-Suit: selalu bintang tertinggi dari period/branch yang sama.
    if F.isXSuitRes(resID) and F.resolveHighestWearRes then
        local upRes, upIns = F.resolveHighestWearRes(resID, insID)
        if upRes and upRes ~= resID and upIns then
            resID, insID = upRes, upIns
            R.resToIns[resID], R.insToRes[insID] = insID, resID
        end
    end
    F.ensureDepotItemValid(insID, resID)
    if not F.isSuitRes(resID) then
        if F.isTshirtRes(resID) then return F.putOnRoleWear(insID) end
        return false
    end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end

    local d = F.depotRow(insID) or { color = 0, pattern = 0 }
    local isSuit = function(r) return F.isSuitRes(r) end
    local oldIns, oldRes = F.findWornInsBySubType(OUTFIT_SUB, isSuit)
    F.removeRoleWearBySubType(OUTFIT_SUB, isSuit)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = tryRequire("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu and wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(OUTFIT_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end
    local item = {
        res_id = resID, resID = resID,
        count = 1,
        instid = insID, ins_id = insID, insID = insID,
        color = d.color or 0, pattern = d.pattern or 0,
        expire_ts = 0,
    }
    putOnResponse(item, olditem, slot, insID, oldIns)
    pcall(function()
        local av = tryRequire("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        if av and av.AddToWearInfo then av:AddToWearInfo(OUTFIT_SUB, insID, resID, 0, 0) end
        F.syncFashionBagRolewear()
    end)
    return true
end

-- ============================================================================
-- PAKAI: HAT / RAMBUT
-- ============================================================================
function F.putOnHat(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    local resID = F.resOfIns(insID)
    if not resID then return false end
    R.insToRes[insID], R.resToIns[resID] = resID, insID
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local d = F.depotRow(insID) or { color = 0, pattern = 0 }
    local st = tonumber(F.subTypeOf(resID)) or HAT_SUB

    local oldIns, oldRes = F.findWornInsBySubType(st)
    if not oldIns and st ~= HAT_SUB then oldIns, oldRes = F.findWornInsBySubType(HAT_SUB) end
    F.removeRoleWearBySubType(st)
    if st ~= HAT_SUB then F.removeRoleWearBySubType(HAT_SUB) end
    F.saveEquip(resID, insID)

    local slot = 1
    pcall(function()
        local wfu = tryRequire("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu and wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end
    local item = {
        res_id = resID, resID = resID,
        count = 1,
        instid = insID, ins_id = insID, insID = insID,
        color = d.color or 0, pattern = d.pattern or 0,
        expire_ts = 0,
    }
    putOnResponse(item, olditem, slot, insID, oldIns)
    pcall(function()
        local fbd = fashionBagModule()
        if fbd then
            if fbd.SetHeadShow then fbd:SetHeadShow(insID) end
            F.syncFashionBagRolewear()
        end
    end)
    return true
end

-- ============================================================================
-- PAKAI: MASK / GLASSES
-- ============================================================================
function F.putOnFaceAccessory(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    local resID = F.resOfIns(insID)
    if not resID then return false end
    R.insToRes[insID], R.resToIns[resID] = resID, insID
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local d = F.depotRow(insID) or { color = 0, pattern = 0 }
    local st = tonumber(F.subTypeOf(resID)) or tonumber(d.itemSubType)
    if not FACE_SUBS[st] then return false end

    local oldIns, oldRes = F.findWornInsBySubType(st)
    F.removeRoleWearBySubType(st)
    F.saveEquip(resID, insID)

    local slot = (st == MASK_SUB) and 2 or 6
    pcall(function()
        local wfu = tryRequire("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu and wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end
    local item = {
        res_id = resID, resID = resID,
        count = 1,
        instid = insID, ins_id = insID, insID = insID,
        color = d.color or 0, pattern = d.pattern or 0,
        expire_ts = 0,
    }
    putOnResponse(item, olditem, slot, insID, oldIns)
    pcall(F.syncFashionBagRolewear)
    return true
end

-- ============================================================================
-- PAKAI: ROLE WEAR (tshirt, pants, shoes, bag, helmet)
-- ============================================================================
function F.canRoleWear(resID, st)
    st = st or F.subTypeOf(resID)
    if FACE_SUBS[st] or BODY_SUBS[st] then return true end
    if st == GLOVES_SUB then return true end
    if st == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES then return true end
    return false
end

function F.putOnRoleWear(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    local resID = F.resOfIns(insID)
    if not resID then return false end
    R.insToRes[insID], R.resToIns[resID] = resID, insID
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local d = F.depotRow(insID) or { color = 0, pattern = 0 }
    local st = tonumber(F.subTypeOf(resID)) or tonumber(d.itemSubType)
    if not F.canRoleWear(resID, st) then return false end

    local filterFn
    if st == OUTFIT_SUB then
        filterFn = function(r) return F.wardrobeTab(r) == TAB_CLOTHES end
    end
    local oldIns, oldRes = F.findWornInsBySubType(st, filterFn)
    F.removeRoleWearBySubType(st, filterFn)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = tryRequire("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu and wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end
    local item = {
        res_id = resID, resID = resID,
        count = 1,
        instid = insID, ins_id = insID, insID = insID,
        color = d.color or 0, pattern = d.pattern or 0,
        expire_ts = 0,
    }
    putOnResponse(item, olditem, slot, insID, oldIns)

    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
            DataMgr.equipmentSkinInsIDTable[st] = insID
            local fbd = fashionBagModule()
            local bag = fbd and fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
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
    pcall(F.syncFashionBagRolewear)
    return true
end

-- ============================================================================
-- PAKAI: SARUNG TANGAN
-- ============================================================================
function F.putOnGloves(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    local resID = F.resOfIns(insID)
    if not resID then return false end
    R.insToRes[insID], R.resToIns[resID] = resID, insID
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local d = F.depotRow(insID) or { color = 0, pattern = 0 }

    local oldIns, oldRes = F.findWornInsBySubType(GLOVES_SUB)
    F.removeRoleWearBySubType(GLOVES_SUB)
    F.saveEquip(resID, insID)

    local slot = 8
    pcall(function()
        local wfu = tryRequire("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu and wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(GLOVES_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end
    local item = {
        res_id = resID, resID = resID,
        count = 1,
        instid = insID, ins_id = insID, insID = insID,
        color = d.color or 0, pattern = d.pattern or 0,
        expire_ts = 0,
    }
    putOnResponse(item, olditem, slot, insID, oldIns)
    pcall(function()
        local av = tryRequire("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        if av and av.AddToWearInfo then
            av:AddToWearInfo(GLOVES_SUB, insID, resID, d.color or 0, d.pattern or 0)
            DataMgr.UpdateRoleWearData(insID, oldIns or 0)
            av:AvatarChange(resID, true, d.color, d.pattern)
        end
    end)
    pcall(F.refreshWardrobe)
    return true
end

-- ============================================================================
-- PAKAI: PARACHUTE / GLIDER / THROWABLE / VEHICLE
-- ============================================================================
function F.putOnParachute(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    local resID = F.resOfIns(insID)
    if not resID or not F.isParachuteRes(resID) then return false end
    R.insToRes[insID], R.resToIns[resID] = resID, insID
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    pcall(function()
        local fbd = fashionBagModule()
        if fbd then
            if fbd.SetParachute then fbd:SetParachute(insID) end
            if fbd.UpdateParachute then fbd:UpdateParachute(insID) end
        end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            count = 1,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0,
        }
        putOnResponse(item, nil, 1, insID, 0)
    end
    return true
end

function F.putOnGlider(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    local resID = F.resOfIns(insID)
    if not resID then return false end
    local st = F.subTypeOf(resID)
    if not F.isGlideRes(resID) and not GLIDER_SUBS[tonumber(st or 0)] then return false end
    R.insToRes[insID], R.resToIns[resID] = resID, insID
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end

    local bAircraft = false
    pcall(function()
        local MDH = tryRequire("client.logic.avatar.ModelDisplayTypeHelper")
        if MDH and MDH.IsGlideSmoke then bAircraft = MDH.IsGlideSmoke(st) end
    end)
    pcall(function()
        local fbd = fashionBagModule()
        if not fbd then return end
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
            count = 1,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0,
        }
        putOnResponse(item, nil, 1, insID, 0)
    end
    return true
end

function F.rememberThrowObjectInBag(st, insID)
    st, insID = tonumber(st), tonumber(insID)
    if not st or not insID or insID <= 0 then return false end
    pcall(function()
        local fbd = fashionBagModule()
        local bag = fbd and fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if not bag then return end
        bag.throw_object_list = bag.throw_object_list or {}
        bag.throw_object_list[st] = insID
    end)
    return true
end

function F.throwObjectResForIns(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return nil end
    local resID = tonumber(R.insToRes[insID])
    if resID then return resID end
    local d = F.depotRow(insID)
    resID = d and tonumber(d.resID or d.res_id)
    if resID and resID > 0 then
        R.insToRes[insID], R.resToIns[resID] = resID, insID
        return resID
    end
    return nil
end

function F.putOnThrowObject(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    if F._puttingOnThrowObject then return false end
    local resID = F.throwObjectResForIns(insID)
    if not resID then return false end
    local st = F.throwObjectSubtype(resID)
    if not st then return false end

    F._puttingOnThrowObject = true
    R.insToRes[insID], R.resToIns[resID] = resID, insID
    pcall(function()
        local fbd = fashionBagModule()
        if fbd and fbd.PutOnThrowObjectSkin then fbd:PutOnThrowObjectSkin(insID) end
    end)
    F.rememberThrowObjectInBag(st, insID)
    F.saveThrowObject(resID, insID)
    F.requestResourceDownload(resID)
    F._puttingOnThrowObject = false
    if F.applyThrowObjectSkins then pcall(F.applyThrowObjectSkins) end
    return true
end

function F.putOnVehicle(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    local resID = F.resOfIns(insID)
    if not resID or not F.isVehicleRes(resID) then return false end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local sub = F.vehicleSubType and F.vehicleSubType(resID) or nil
    C.vehicle = { sub = sub, res = resID, ins = insID }
    F.persistMarkDirty()

    local item = {
        res_id = resID, resID = resID,
        count = 1,
        instid = insID, ins_id = insID, insID = insID,
        expire_ts = 0,
    }
    putOnResponse(item, nil, 1, insID, 0)
    pcall(function() DataMgr.vst_skin = insID end)
    pcall(function()
        local HT = tryRequire("client.logic.lobby.hall_theme_utils")
        if HT and HT.ProcPutOnVehicle then
            HT.ProcPutOnVehicle({ res_id = resID, instid = insID }, true)
        end
    end)
    pcall(F.refreshWardrobe)
    return true
end

-- ============================================================================
-- LEPAS ITEM
-- ============================================================================
function F.takeOffInjected(insID)
    insID = tonumber(insID)
    if not insID then return end
    local resID = R.insToRes[insID] or F.throwObjectResForIns(insID)
    if not resID then return end
    local st = tonumber(F.subTypeOf(resID) or 0)

    pcall(function()
        local WRH = tryRequire("client.network.Protocol.WardRobeHandler")
        if WRH and WRH.on_depot_put_down_rsp then
            WRH.on_depot_put_down_rsp(NET_OK, { res_id = resID, count = 1, instid = insID }, insID)
        end
    end)
    pcall(function()
        local AvatarData = avatarDataModule()
        if AvatarData and AvatarData.RemoveRoleWearDataByValue then
            AvatarData.RemoveRoleWearDataByValue(insID)
        end
    end)
    if st == HAT_SUB or HEAD_SUBS[st] then
        pcall(function()
            local fbd = fashionBagModule()
            local bag = fbd and fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag and tonumber(bag.head_show) == insID and fbd.SetHeadShow then fbd:SetHeadShow(0) end
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
            local fbd = fashionBagModule()
            local bag = fbd and fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if tonumber(bag.bag_skin) == insID then bag.bag_skin = 0 end
                if tonumber(bag.helmet_skin) == insID then bag.helmet_skin = 0 end
            end
        end)
    end
    if THROW_SUBS[st] then
        C.throw[st] = nil
        pcall(function()
            local fbd = fashionBagModule()
            local bag = fbd and fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag and bag.throw_object_list then bag.throw_object_list[st] = nil end
        end)
        F.persistMarkDirty()
    end
    F.clearEquipCache(resID)
    pcall(F.syncFashionBagRolewear)
end

-- ============================================================================
-- ROUTER KLIK WARDROBE
-- ============================================================================
function F.tryLocalWearByIns(insID)
    insID = tonumber(insID)
    if not insID or insID <= 0 then return false end
    local directIns = R.insToRes[insID] ~= nil
    local resID = R.insToRes[insID] or F.throwObjectResForIns(insID)
    if not resID then
        local d = F.depotRow(insID)
        resID = d and tonumber(d.resID or d.res_id)
    end
    if not resID or resID <= 0 then return false end
    local st = tonumber(F.subTypeOf(resID) or 0)

    F.ensureDepotItemValid(insID, resID)

    if st == GLOVES_SUB then return F.putOnGloves(insID) end
    if THROW_SUBS[st] then return F.putOnThrowObject(insID) end
    if F.isParachuteRes(resID) then return F.putOnParachute(insID) end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then return F.putOnGlider(insID) end
    if st == OUTFIT_SUB then
        if F.isSuitRes(resID) then return F.putOnOutfit(insID) end
        return F.putOnRoleWear(insID)
    end
    if st == HAT_SUB or HEAD_SUBS[st] then return F.putOnHat(insID) end
    if FACE_SUBS[st] then return F.putOnFaceAccessory(insID) end
    if BODY_SUBS[st] or HELMET_SUBS[st] then return F.putOnRoleWear(insID) end
    if F.isVehicleRes(resID) then return F.putOnVehicle(insID) end

    if GUN_SUB[st] then
        local wid = F.weaponIdFromSkin and F.weaponIdFromSkin(resID)
        if wid and F.equipWeaponSkin then return F.equipWeaponSkin(wid, insID) end
        return directIns
    end
    if st == MELEE_ID then
        if F.equipWeaponSkin then return F.equipWeaponSkin(MELEE_ID, insID) end
        return directIns
    end

    -- Tipe di luar cakupan rebuild (emote, hall theme, kill message, dll).
    -- Instance hasil injeksi tidak dikenal server, jadi request-nya ditahan;
    -- instance asli tetap memakai jalur server seperti pemakaian normal.
    return directIns
end
-- ============================================================================
-- X-SUIT (bintang tertinggi) + SKIN SENJATA (level tertinggi)
-- ============================================================================

local XSUIT_CFG_TABLES = {
    "GoldenSuitUpgradeCfg",
    "GoldenSuitUpgradeCfgKJ",
    "GoldenSuitUpgradeCfgIN",
}

function F.xsuitLogic()
    if F._xsuitLogic then return F._xsuitLogic end
    local mod = tryRequire("client.slua.logic.XSuit.logic_xsuit")
    if mod then
        F._xsuitLogic = mod
        return mod
    end
    return nil
end

function F.xsuitUtil()
    local util = tryRequire("GameLua.Activity.Commercialize.GamePlay.XSuit.XSuitUtil")
    if util then return util end
    return nil
end

function F.isXSuitRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if not F.isSuitRes(resID) then return false end
    local mod = F.xsuitLogic()
    if mod and mod.IsXSuit then
        local ok, result = pcall(mod.IsXSuit, resID)
        if ok and result then return true end
    end
    -- Item suit (bukan t-shirt) dianggap kandidat X-Suit; resolver tetap
    -- memakai tabel period/branch sehingga resource non-X-Suit tidak berubah.
    return true
end

function F.xsuitConfigMaps()
    if F._xsuitCfgMaps then return F._xsuitCfgMaps end
    if not (CDataTable and CDataTable.GetTable) then return nil end
    local byItem, best = {}, {}
    local found = false
    for _, tableName in ipairs(XSUIT_CFG_TABLES) do
        local ok, tbl = pcall(function() return CDataTable.GetTable(tableName) end)
        if ok and type(tbl) == "table" and next(tbl) ~= nil then
            found = true
            for _, row in pairs(tbl) do
                local id = tonumber(row.ItemID or row.itemID or row.ItemId or row.itemid)
                local period = tonumber(row.Period or row.period)
                local branch = tonumber(row.BranchId or row.branchId or row.BranchID or row.branch) or 0
                local star = tonumber(row.Star or row.star or row.Level or row.level)
                if id and id > 0 and period and star then
                    byItem[id] = { period = period, branch = branch, star = star }
                    local key = tostring(period) .. ":" .. tostring(branch)
                    local top = best[key]
                    if not top or star > top.star then
                        best[key] = { star = star, resID = id }
                    end
                end
            end
        end
    end
    if not found then return nil end
    F._xsuitCfgMaps = { byItem = byItem, best = best }
    return F._xsuitCfgMaps
end

function F.xsuitHighestRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return resID end
    F._xsuitHighest = F._xsuitHighest or {}
    local cached = F._xsuitHighest[resID]
    if cached then return cached end

    local best = resID
    local mapped = false
    local util = F.xsuitUtil()
    if util then
        pcall(function()
            local period = util:GetPeriodByItemId(resID)
            if not period then return end
            mapped = true
            local branch = util:GetBranchIdByItemId(resID) or 0
            local info = util:GetUpgradeInfoByPeriodAndBranchId(period, branch)
            if type(info) ~= "table" then return end
            local bestStar = tonumber(util:GetLevelByItemId(resID)) or 0
            for star, entry in pairs(info) do
                local s = tonumber(star)
                local id = entry and tonumber(entry.item_id) or 0
                if s and s > bestStar and id > 0 then
                    bestStar, best = s, id
                end
            end
        end)
    end
    if best == resID then
        local maps = F.xsuitConfigMaps()
        local info = maps and maps.byItem[resID]
        if info then
            local top = maps.best[tostring(info.period) .. ":" .. tostring(info.branch)]
            if top and top.resID and top.resID > 0 and (top.star or 0) > (info.star or 0)
                and F.cfg(top.resID) then
                mapped = true
                best = top.resID
            end
        end
    end
    if mapped then F._xsuitHighest[resID] = best end
    return best
end

function F.resolveHighestWearRes(resID, insID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return resID, insID end
    if not F.isXSuitRes(resID) then return resID, insID end
    local target = F.xsuitHighestRes(resID)
    if not target or target == resID then return resID, insID end
    local ins = F.instForRes(target) or R.resToIns[target]
    if not ins then return resID, insID end
    return target, ins
end

function F.autoMaxWearRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return resID end
    if not F.isXSuitRes(resID) then return resID end
    local target = F.xsuitHighestRes(resID)
    if target == resID then return resID end
    if F.instForRes(target) then return target end
    return resID
end

-- ============================================================================
-- SKIN SENJATA
-- ============================================================================
local GUN_MASTER_SYN_SLOT = 7

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
    if weaponID == MELEE_ID or weaponID == 108001 or weaponID == 108004 or weaponID == 108005 then
        local kind = F.meleeKindFromRes(resID)
        local st = tonumber(F.subTypeOf(resID) or 0)
        return kind ~= nil and (st == 0 or st == MELEE_ID)
    end
    local wid = tonumber(F.weaponIdFromSkin(resID))
    return wid ~= nil and wid == weaponID
end

function F.isWeaponSkinRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = tonumber(F.subTypeOf(resID) or 0)
    return GUN_SUB[st] == true or st == MELEE_ID or F.meleeKindFromRes(resID) ~= nil
end

function F.isWeaponSkinIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    return F.isWeaponSkinRes(R.insToRes[insID])
end

function F.ensureResInjected(resID)
    return F.instForRes(resID)
end

-- GroupItemUpgrade: semua level satu skin punya GroupID yang sama.
-- Cache dibangun sekali; kalau tabel belum tersedia, jangan di-memo.
function F.skinGroups()
    if F._skinGroups then return F._skinGroups end
    local c = { groupOf = {}, levelOf = {}, best = {}, ready = false }
    local up = CDataTable and CDataTable.GetTable and CDataTable.GetTable("ItemUpgradeConfig")
    if type(up) == "table" and next(up) ~= nil then
        c.ready = true
        for _, row in pairs(up) do
            local itm = tonumber(row.ItemID or row.itemID)
            local gid = tonumber(row.GroupID or row.groupID)
            local lvl = tonumber(row.Level or row.level) or 0
            if itm and itm > 0 and gid and gid > 0 then
                c.groupOf[itm] = gid
                c.levelOf[itm] = lvl
                local b = c.best[gid]
                if not b or lvl > b.level then
                    c.best[gid] = { level = lvl, resID = itm }
                end
            end
        end
    end
    if c.ready then F._skinGroups = c end
    return c
end

function F.highestSkinRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return resID end
    F._skinUp = F._skinUp or {}
    local cached = F._skinUp[resID]
    if cached then return cached end

    local c = F.skinGroups()
    if not c.ready then return resID end
    local gid = c.groupOf[resID]
    if not gid then
        F._skinUp[resID] = resID
        return resID
    end
    local top = c.best[gid]
    if not top or not top.resID or top.resID == resID then
        F._skinUp[resID] = resID
        return resID
    end
    if (top.level or 0) <= (c.levelOf[resID] or 0) then
        F._skinUp[resID] = resID
        return resID
    end
    -- Jangan menyeberang keluarga senjata lewat GroupID bersama.
    local oldWid = tonumber(F.weaponIdFromSkin(resID))
    local newWid = tonumber(F.weaponIdFromSkin(top.resID))
    if oldWid and newWid and oldWid ~= newWid then
        F._skinUp[resID] = resID
        return resID
    end
    F._skinUp[resID] = top.resID
    return top.resID
end

function F.maxSkinSelection(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or resID <= 0 then return resID, insID end
    local top = tonumber(F.highestSkinRes(resID)) or resID
    if top == resID then return resID, insID end
    local topIns = F.instForRes(top) or R.resToIns[top]
    if not topIns then return resID, insID end
    return top, topIns
end

-- Normalisasi nilai yang dibaca dari JSON: slot X-Suit ke bintang tertinggi,
-- skin senjata ke level tertinggi.  Dipanggil sekali setelah persistLoad.
function F.normalizePersisted()
    local changed = false
    local SLOT_KEYS = { "outfit", "tshirt", "pants", "shoes", "hat", "mask", "glass", "bag", "helmet", "parachute", "glider", "gloves" }
    for _, key in ipairs(SLOT_KEYS) do
        local res = tonumber(C.slots[key])
        if res and res > 0 and F.isXSuitRes(res) then
            local top = F.autoMaxWearRes(res)
            if top and top ~= res then
                C.slots[key] = top
                C.ins[key] = nil
                changed = true
            end
        end
    end
    for wid, w in pairs(C.weapons) do
        local res = w and tonumber(w.resID)
        if res and res > 0 then
            local top = tonumber(F.highestSkinRes(res)) or res
            if top ~= res then
                w.resID = top
                w.insID = nil
                changed = true
            end
        end
    end
    if changed then F.persistMarkDirty() end
    return changed
end

function F.getMatchWeaponSkin(weaponID)
    weaponID = F.normalizeWeaponId(weaponID) or tonumber(weaponID) or 0
    if weaponID <= 0 then return nil end
    local w = C.weapons[weaponID]
    local res = w and tonumber(w.resID)
    if res and res > 0 then return res end
    return nil
end

function F.injectArmory(resID, insID)
    local wid = tonumber(F.weaponIdFromSkin(resID)) or (F.meleeKindFromRes(resID) and MELEE_ID) or nil
    if not wid then return end
    local Arm = tryRequire("client.logic.armory.logic_armory")
    if not Arm then return end
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    local bucket = Arm.rsp_list.skin_list[wid]
    if not bucket then bucket = {}; Arm.rsp_list.skin_list[wid] = bucket end
    local row = bucket[resID]
    if not row then row = { is_open = 1 }; bucket[resID] = row end
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

function F.saveWeaponToCache(weaponID, resID, insID)
    weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
    weaponID = F.normalizeWeaponId(weaponID, resID)
    if resID and resID > 0 then
        local top = tonumber(F.highestSkinRes(resID)) or resID
        if top ~= resID and F.isValidWeaponPersistEntry(weaponID, top) then
            resID = top
            insID = F.instForRes(top) or R.resToIns[top] or insID
        end
    end
    if not F.isValidWeaponPersistEntry(weaponID, resID) then return false end
    C.weapons[weaponID] = { resID = resID, insID = insID or R.resToIns[resID] or 0 }
    F.invalidateApply()
    F.persistMarkDirty()
    return true
end

function F.cacheWeaponSkinFromIns(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or insID <= 0 then return end
    local resID = R.insToRes[insID]
    if resID then
        F.saveWeaponToCache(weaponID, resID, insID)
        return
    end
    local d = F.depotRow(insID)
    resID = d and tonumber(d.resID or d.res_id)
    if resID and resID > 0 then
        R.insToRes[insID], R.resToIns[resID] = resID, insID
        F.saveWeaponToCache(weaponID, resID, insID)
    end
end

function F.equipWeaponSkin(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID then return false end
    local resID = R.insToRes[insID]
    if not resID then
        local d = F.depotRow(insID)
        resID = d and tonumber(d.resID or d.res_id)
    end
    if not resID then return false end
    weaponID = F.normalizeWeaponId(weaponID, resID) or weaponID

    local top, topIns = F.maxSkinSelection(resID, insID)
    if top then resID = top end
    if topIns and topIns > 0 then insID = topIns end
    R.insToRes[insID], R.resToIns[resID] = resID, insID

    F.saveWeaponToCache(weaponID, resID, insID)
    F.injectArmory(resID, insID)

    local Arm = tryRequire("client.logic.armory.logic_armory")
    if Arm then
        Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
        Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
        Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    end
    pcall(function()
        local fbd = fashionBagModule()
        if fbd and fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
        end
    end)
    pcall(function()
        local HT = tryRequire("client.logic.lobby.hall_theme_utils")
        local fbd = fashionBagModule()
        local bagIdx = fbd and fbd.GetFashionBagUseIndex and fbd:GetFashionBagUseIndex() or 0
        if HT and HT.proc_skin_list_chg then HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {}) end
    end)
    pcall(function()
        local wgl = tryRequire("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl then
            if wgl.SetGunID then wgl:SetGunID(weaponID) end
            if wgl.UpdateCurrentGunAvatar then wgl:UpdateCurrentGunAvatar(weaponID, insID) end
        end
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
            EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
        end
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
        end
    end)
    return true
end

-- ============================================================================
-- VISUAL SENJATA DI MATCH / HOLD
-- ============================================================================
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

function F.get_skin_id(currentGunId, maxIt)
    currentGunId = tonumber(currentGunId) or 0
    maxIt = tonumber(maxIt) or 0
    if currentGunId <= 0 and maxIt <= 0 then return 0 end
    local function top(res)
        res = tonumber(res) or 0
        if res > 0 then res = tonumber(F.highestSkinRes(res)) or res end
        return res
    end
    if maxIt > 0 then
        local fromMem = F.getMatchWeaponSkin(maxIt)
        if fromMem then return top(fromMem) end
    end
    local typeID = F.resolveWeaponTypeID(currentGunId)
    local fromType = typeID > 0 and F.getMatchWeaponSkin(typeID)
    if fromType then return top(fromType) end
    if currentGunId > 0 then
        local direct = F.getMatchWeaponSkin(currentGunId)
        if direct then return top(direct) end
    end
    for wid, w in pairs(C.weapons) do
        local res = w and tonumber(w.resID) or 0
        if res > 0 and (tonumber(wid) == maxIt or tonumber(wid) == typeID or tonumber(wid) == currentGunId) then
            return top(res)
        end
    end
    return 0
end

function F.applySkinToWeaponRef(CurWeapon)
    if not slua.isValid(CurWeapon) then return false end
    local arr = CurWeapon.synData
    if not arr or not slua.isValid(arr) then return false end
    local att = arr:Get(GUN_MASTER_SYN_SLOT)
    if not att then return false end

    local currentGunId = 0
    pcall(function() currentGunId = slua.IndexReference(att, "defineID").TypeSpecificID or 0 end)
    if not currentGunId or currentGunId <= 0 then return false end

    local maxIt = 0
    pcall(function()
        if CurWeapon.GetWeaponID then maxIt = CurWeapon:GetWeaponID() end
        if (not maxIt or maxIt <= 0) and CurWeapon.GetItemDefineID then
            maxIt = CurWeapon:GetItemDefineID().TypeSpecificID
        end
    end)
    maxIt = tonumber(maxIt) or 0
    if maxIt <= 0 then return false end

    local skin = tonumber(F.get_skin_id(currentGunId, maxIt)) or 0
    local target = skin > 0 and skin or maxIt

    local wac = CurWeapon.WeaponAvatarComponent
    local currentVisualID = 0
    if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end
    if currentVisualID == target then return false end

    pcall(function()
        local ref = slua.IndexReference(att, "defineID")
        ref.TypeSpecificID = target
        local c0 = F.cfg(target)
        if c0 and c0.ItemType and ref.Type ~= nil then ref.Type = c0.ItemType end
        att.operationType = 0
        arr:Set(GUN_MASTER_SYN_SLOT, att)
    end)
    pcall(function()
        if slua.isValid(wac) then
            if currentVisualID ~= target then
                if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(0) end
                if wac.ClearMeshBySlot then wac:ClearMeshBySlot(0, true, true) end
            end
            if CurWeapon.DelayHandleAvatarMeshChanged then CurWeapon:DelayHandleAvatarMeshChanged() end
            if wac.ReloadAllEquippedAvatar then wac:ReloadAllEquippedAvatar(1) end
        end
    end)
    return true
end

F.applySkinToWeapon = F.applySkinToWeaponRef

function F.equipWeaponAvatarSynData(char)
    if not char or not slua.isValid(char) then return false end
    local wm
    pcall(function() wm = char:GetWeaponManager() end)
    if not wm or not slua.isValid(wm) then return false end
    local list
    pcall(function() list = wm:GetAllInventoryWeaponList(false) end)
    if not list or not slua.isValid(list) then return false end
    local applied = false
    for i = 0, list:Num() - 1 do
        local weapon = list:Get(i)
        if slua.isValid(weapon) and F.applySkinToWeaponRef(weapon) then applied = true end
    end
    return applied
end

function F.onWeaponLuaInit(_, _, weapon)
    if not weapon or not slua.isValid(weapon) then return end
    local char = F.getLocalChar()
    if not char then return end
    local owner
    pcall(function() owner = weapon:GetOwnerPawn() end)
    if not slua.isValid(owner) or owner ~= char then return end
    pcall(function()
        char:AddGameTimer(0.15, false, function()
            if slua.isValid(weapon) then F.applySkinToWeapon(weapon) end
        end)
    end)
end

function F.hookWeaponSpawn()
    if S.weaponSpawnHooked then return end
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_PLAYEREVENT_WEAPON
            and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
            EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, F.onWeaponLuaInit)
            S.weaponSpawnHooked = true
        end
    end)
end
-- ============================================================================
-- APPLY DI LOBBY + MATCH
-- ============================================================================

function F.ensureSkinDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    _G.skinIdCache = _G.skinIdCache or {}
    if not _G.skinIdCache[resID] then
        F.requestResourceDownload(resID)
        _G.skinIdCache[resID] = true
    end
end

function F.getAvatarComp2(char)
    if not char or not slua.isValid(char) then return nil end
    local comp
    pcall(function()
        if char.getAvatarComponent2 then comp = char:getAvatarComponent2() end
        if (not comp or not slua.isValid(comp)) and char.AvatarComponent2 then comp = char.AvatarComponent2 end
        if (not comp or not slua.isValid(comp)) and char.CharacterAvatarComp2_BP then comp = char.CharacterAvatarComp2_BP end
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

-- Tulis satu slot ke NetAvatarData (jalur yang dipakai game untuk menggambar
-- pakaian).  Hanya menulis kalau nilainya berbeda supaya tidak memicu redraw
-- berulang.
function F.applySlotSkinBatch(comp, entries, opts)
    opts = opts or {}
    if not comp or not slua.isValid(comp) or type(entries) ~= "table" then return false end
    local changed, anyOk = false, false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local data = net.SlotSyncData
        if not data or not slua.isValid(data) then return end
        local num = data:Num()
        for _, e in ipairs(entries) do
            local resID, slotID = tonumber(e[1]), tonumber(e[2])
            if resID and resID > 0 and slotID then
                F.ensureSkinDownload(resID)
                for i = 0, num - 1 do
                    local equipment = data:Get(i)
                    if equipment and tonumber(equipment.SlotID) == tonumber(slotID) then
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur == resID then
                            anyOk = true
                        else
                            equipment.ItemId = resID
                            if equipment.ItemID ~= nil then equipment.ItemID = resID end
                            if equipment.FakeItemID ~= nil then equipment.FakeItemID = resID end
                            data:Set(i, equipment)
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
    resID, slotID = tonumber(resID), tonumber(slotID)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotID then return false end
    local changed, already = false, false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local data = net.SlotSyncData
        if not data or not slua.isValid(data) then return end
        local num = data:Num()
        for i = 0, num - 1 do
            local equipment = data:Get(i)
            if equipment and tonumber(equipment.SlotID) == tonumber(slotID) then
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur == resID then
                    already = true
                else
                    F.ensureSkinDownload(resID)
                    equipment.ItemId = resID
                    if equipment.ItemID ~= nil then equipment.ItemID = resID end
                    if equipment.FakeItemID ~= nil then equipment.FakeItemID = resID end
                    data:Set(i, equipment)
                    changed = true
                end
                break
            end
        end
        if (changed or opts.forceRep) and comp.OnRep_BodySlotStateChanged then
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

-- ============================================================================
-- SLOT YANG DIPAKAI
-- ============================================================================
function F.desiredRes(slot)
    return tonumber(C.slots[slot])
end

function F.desiredIns(slot)
    local res = F.desiredRes(slot)
    local ins = tonumber(C.ins[slot])
    if res and (not ins or ins <= 0) then
        ins = F.resolveInsForRes(res)
        if ins then C.ins[slot] = ins end
    end
    return ins, res
end

function F.syncGlobalWearSkins()
    _G.CustSlotType = F.CUST_SLOT
    _G.skinIdCache = _G.skinIdCache or {}
    _G.HatSkin = tonumber(F.desiredRes("hat")) or 0
    _G.SuitSkin = tonumber(F.desiredRes("outfit")) or tonumber(F.desiredRes("tshirt")) or 0
    _G.PantsSkin = tonumber(F.desiredRes("pants")) or 0
    _G.ShoesSkin = tonumber(F.desiredRes("shoes")) or 0
    _G.GlovesSkin = tonumber(F.desiredRes("gloves")) or 0
    _G.MaskSkin = tonumber(F.desiredRes("mask")) or 0
    _G.GlassSkin = tonumber(F.desiredRes("glass")) or 0
    _G.GliderSkin = tonumber(F.desiredRes("glider")) or 0
    _G.ParachuteSkin = tonumber(F.desiredRes("parachute")) or 0
end

-- ============================================================================
-- EQUIPMENT SKIN (tas / helm) — level mengikuti item asli
-- ============================================================================
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

    local function doSlot(key, res, slotName, fallbackSlot, levelFn)
        if res <= 0 then slotOk[key] = true; return end
        local slotEnum = EAvatarSlotType and EAvatarSlotType[slotName] or fallbackSlot
        if not slotEnum then slotOk[key] = false; return end
        local okCall, done = pcall(function()
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
                        if entry and tonumber(entry.SlotID) == tonumber(slotEnum) then
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
                local ok, value = pcall(levelFn, additional > 0 and additional or current)
                if ok then level = tonumber(value) or 1 end
            end
            if level < 1 then level = 1 end
            local targetID = F.levelSkinID(res, level)
            pcall(F.ensureSkinDownload, targetID)
            if current == targetID then return true end

            if sync then
                local wroteID = false
                if sync.ItemID ~= nil then sync.ItemID = targetID; wroteID = true end
                if sync.ItemId ~= nil then sync.ItemId = targetID; wroteID = true end
                if not wroteID then sync.ItemID = targetID end
                if sync.FakeItemID ~= nil then sync.FakeItemID = targetID end
                if comp.ChangeSlotSyncData then
                    local result = comp.ChangeSlotSyncData(sync)
                    if result == false then return false end
                elseif syncArray and syncIndex ~= nil then
                    syncArray:Set(syncIndex, sync)
                else
                    return false
                end
                if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
                return true
            end
            if comp.PutOnCustomEquipmentByID then
                local putOk, putResult = pcall(function() return comp:PutOnCustomEquipmentByID(targetID) end)
                return putOk and putResult ~= false
            end
            return false
        end)
        slotOk[key] = okCall and done == true
    end

    doSlot("bag", bagRes, "EAvatarSlotType_BackpackEquipemtSlot",
        F.CUST_SLOT.BackpackEquipemtSlot,
        BackpackUtils and BackpackUtils.GetEquipmentBagLevel)
    doSlot("helmet", helmetRes, "EAvatarSlotType_HelmetEquipemtSlot",
        F.CUST_SLOT.HelmetEquipemtSlot,
        BackpackUtils and BackpackUtils.GetEquipmentHelmetLevel)
    return slotOk.bag, slotOk.helmet, slotOk.bag and slotOk.helmet
end

function F.matchApplyEquipmentSkin(char, bagRes, helmetRes)
    bagRes, helmetRes = tonumber(bagRes) or 0, tonumber(helmetRes) or 0
    if bagRes <= 0 and helmetRes <= 0 then return true end
    if not char or not slua.isValid(char) then return false end
    local comp = F.getAvatarComp2(char)
    if not slua.isValid(comp) then return false end
    local bagOk, helmetOk = F.applyEquipSkinToComp(comp, bagRes, helmetRes)
    return bagOk and helmetOk
end

function F.scheduleEquipmentSkinApply(char)
    local attempts = 0
    local function retry()
        attempts = attempts + 1
        local current = F.getLocalChar() or char
        local bagRes = tonumber(F.desiredRes("bag")) or 0
        local helmetRes = tonumber(F.desiredRes("helmet")) or 0
        if bagRes <= 0 and helmetRes <= 0 then return end
        if not (current and slua.isValid(current) and F.matchApplyEquipmentSkin(current, bagRes, helmetRes)) then
            if attempts < 10 then F.later(0.4, retry) end
        end
    end
    F.later(0.2, retry)
end

-- ============================================================================
-- THROWABLE (jalur native, animasi tidak disentuh)
-- ============================================================================
function F.applyThrowObjectSkins()
    if F._applyingThrowObjects then return false end
    local pc = F.getPC()
    if not pc or not slua.isValid(pc) then return false end
    local parts = {}
    for st, info in pairs(C.throw) do
        local res = info and tonumber(info.resID)
        if THROW_SUBS[tonumber(st)] and res and res > 0 then
            parts[#parts + 1] = tostring(tonumber(st)) .. ":" .. tostring(res)
        end
    end
    if #parts == 0 then return false end
    table.sort(parts)
    local held = 0
    pcall(function()
        local char = F.getLocalChar()
        local weapon = char and char.GetCurrentWeapon and char:GetCurrentWeapon() or nil
        if slua.isValid(weapon) then held = tonumber(weapon:GetWeaponID()) or 0 end
    end)
    local signature = tostring(pc) .. "|" .. tostring(held) .. "|" .. table.concat(parts, ",")
    if F._throwSignature == signature then return false end

    local applied = false
    for st, info in pairs(C.throw) do
        st = tonumber(st)
        local res = info and tonumber(info.resID)
        local key = st and THROW_AVATAR_KEYS[THROW_SUBS[st]]
        if key and res and res > 0 then
            local ok = pcall(function()
                if pc.InitialConsumableAvatar then pc.InitialConsumableAvatar[key] = res end
            end)
            if ok then applied = true end
        end
    end
    if not applied then return false end
    F._throwSignature = signature
    F._applyingThrowObjects = true
    pcall(function() if pc.InitGrenadeAvatarList then pc:InitGrenadeAvatarList(false) end end)
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    F._applyingThrowObjects = false
    -- Tidak ada poking mesh/ChangeItemAvatar di sini: animasi lempar tetap
    -- memakai jalur native (avatar dibaca dari InitialConsumableAvatar).
    return true
end

function F.hookThrowObjects()
    pcall(function()
        local PCB = tryRequire("GameLua.GameCore.Framework.PlayerControllerBase")
        local impl = PCB and (PCB.__inner_impl or PCB)
        if impl and not impl._rzThrowInitHooked and impl.InitGrenadeAvatarList then
            impl._rzThrowInitHooked = true
            local orig = impl.InitGrenadeAvatarList
            impl.InitGrenadeAvatarList = function(self, ...)
                if not F._applyingThrowObjects then F._throwSignature = nil end
                local result = orig(self, ...)
                pcall(function()
                    if not F._applyingThrowObjects and F.getPC() == self then
                        F.applyThrowObjectSkins()
                    end
                end)
                return result
            end
        end
    end)
    pcall(function()
        local AvatarDataUtil = tryRequire("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
        if AvatarDataUtil and not AvatarDataUtil._rzThrowLookupHooked then
            local orig = AvatarDataUtil.TryGetGrenadeAvatarID
            if orig then
                AvatarDataUtil._rzThrowLookupHooked = true
                AvatarDataUtil.TryGetGrenadeAvatarID = function(pc, itemID)
                    local st = THROW_WEAPON_TO_SUB[tonumber(itemID)]
                    local info = st and C.throw[st]
                    if info and info.resID and F.getPC() == pc then return info.resID end
                    return orig(pc, itemID)
                end
            end
        end
    end)
    pcall(function()
        local classes = {
            { "GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.SpecificProjectile.FragGrenade.FragGrenade", "shoulei" },
            { "GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.SpecificProjectile.SmokeBomb.SmokeBomb", "smoke" },
            { "GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.SpecificProjectile.StunGrenade.StunGrenade", "stun" },
            { "GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.SpecificProjectile.BurnGrenade.BurnGrenade", "burn" },
        }
        for _, entry in ipairs(classes) do
            local ok, cls = pcall(require, entry[1])
            local impl = ok and cls and (cls.__inner_impl or cls)
            if impl and impl.GetAvatarID and not impl._rzThrowAvatarHooked then
                impl._rzThrowAvatarHooked = true
                local orig = impl.GetAvatarID
                local sub = THROW_SUB_BY_KIND[entry[2]]
                impl.GetAvatarID = function(self, consumable)
                    local info = sub and C.throw[sub] or nil
                    if info and info.resID and info.resID > 0 then
                        local mine = false
                        pcall(function()
                            local inst = self.GetInstigatorControllerSafety and self:GetInstigatorControllerSafety() or nil
                            mine = slua.isValid(inst) and F.getPC() == inst
                        end)
                        if mine then return info.resID end
                    end
                    return orig(self, consumable)
                end
            end
        end
    end)
end

-- ============================================================================
-- APPLY KE KARAKTER
-- ============================================================================
function F.matchApplyAllSlots(char)
    if not char or not slua.isValid(char) then return false end
    F.syncGlobalWearSkins()
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local entries = {}
    local function add(res, slot)
        res = tonumber(res)
        if res and res > 0 and slot then entries[#entries + 1] = { res, slot } end
    end
    add(F.desiredRes("hat"), F.CUST_SLOT.HatEquipemtSlot)
    add(F.desiredRes("outfit") or F.desiredRes("tshirt"), F.CUST_SLOT.ClothesEquipemtSlot)
    add(F.desiredRes("pants"), F.CUST_SLOT.PantsEquipemtSlot)
    add(F.desiredRes("shoes"), F.CUST_SLOT.ShoesEquipemtSlot)
    add(F.desiredRes("gloves"), F.CUST_SLOT.HandEffectEquipemtSlot)
    add(F.desiredRes("mask"), F.CUST_SLOT.FaceEquipemtSlot)
    add(F.desiredRes("glass"), F.CUST_SLOT.GlassEquipemtSlot)

    local ok = false
    if #entries > 0 then
        ok = F.applySlotSkinBatch(comp, entries, { forceRep = true })
        if not ok then
            for _, e in ipairs(entries) do
                if F.setMakeSkin(comp, e[1], e[2], { allowPutOn = true }) then ok = true end
            end
        end
    end

    local inAir = F.isCharacterAirborne(char)
    local para = tonumber(F.desiredRes("parachute"))
    if para and para > 0 then
        F.setMakeSkin(comp, para, F.CUST_SLOT.ParachuteEquipemtSlot, { inAir = inAir })
    end
    local glider = tonumber(F.desiredRes("glider"))
    if glider and glider > 0 then
        F.setMakeSkin(comp, glider, F.CUST_SLOT.GlideEquipemtSlot, { inAir = inAir })
    end
    return ok
end

function F.matchApplyWeaponSkin(char)
    if not char or not slua.isValid(char) then return false end
    local weapon
    pcall(function() weapon = char:GetCurrentWeapon() end)
    if not slua.isValid(weapon) then return false end
    local ok = F.applySkinToWeapon(weapon)
    -- Melee (ID 108) juga diterapkan saat dipegang.
    return ok
end

-- ============================================================================
-- LOBBY
-- ============================================================================
function F.restoreLobby()
    if not F.isInLobby() then return false end
    -- Setiap slot dipulihkan lewat applier yang sama dengan klik manual,
    -- jadi wear info + fashion bag ikut sinkron.
    local order = {
        { "outfit", F.putOnOutfit },
        { "tshirt", F.putOnRoleWear },
        { "hat", F.putOnHat },
        { "mask", F.putOnFaceAccessory },
        { "glass", F.putOnFaceAccessory },
        { "pants", F.putOnRoleWear },
        { "shoes", F.putOnRoleWear },
        { "bag", F.putOnRoleWear },
        { "helmet", F.putOnRoleWear },
        { "gloves", F.putOnGloves },
        { "parachute", F.putOnParachute },
        { "glider", F.putOnGlider },
    }
    for _, entry in ipairs(order) do
        local slot, fn = entry[1], entry[2]
        local ins = F.desiredIns(slot)
        if ins and ins > 0 then pcall(fn, ins) end
    end
    -- Skin senjata: pulihkan pilihan ke cache + daftar armory supaya preview
    -- lobby memakai level tertinggi yang tersimpan.
    for wid, w in pairs(C.weapons) do
        local res = w and tonumber(w.resID)
        if res then
            local ins = F.instForRes(res) or w.insID
            if ins then pcall(F.equipWeaponSkin, tonumber(wid), ins) end
        end
    end
    if next(C.throw) then pcall(F.applyThrowObjectSkins) end
    local veh = C.vehicle
    if veh and tonumber(veh.res) then
        local vehIns = tonumber(veh.ins) or F.instForRes(veh.res)
        veh.ins = vehIns
        pcall(function()
            DataMgr.vst_skin = vehIns
            local HT = tryRequire("client.logic.lobby.hall_theme_utils")
            if HT and HT.ProcPutOnVehicle then
                HT.ProcPutOnVehicle({ res_id = veh.res, instid = vehIns }, true)
            end
        end)
    end
    pcall(F.syncGlobalWearSkins)
    return true
end

-- ============================================================================
-- MATCH BOOTSTRAP + WATCHER
-- ============================================================================
function F.bootstrapMatch(char)
    char = char or F.getLocalChar()
    if not char or not slua.isValid(char) then return false end
    if S.applied then return true end
    S.applied = true
    pcall(F.hookThrowObjects)
    pcall(F.syncGlobalWearSkins)
    pcall(F.matchApplyAllSlots, char)
    pcall(F.matchApplyEquipmentSkin, char, F.desiredRes("bag"), F.desiredRes("helmet"))
    if tonumber(F.desiredRes("bag")) or tonumber(F.desiredRes("helmet")) then
        pcall(F.scheduleEquipmentSkinApply, char)
    end
    pcall(F.matchApplyWeaponSkin, char)
    pcall(F.equipWeaponAvatarSynData, char)
    pcall(F.applyThrowObjectSkins)
    return true
end

function F.startMatchWatcher()
    if S.watcher then return true end
    local ticker = _ticker or tryRequire("common.time_ticker")
    if not ticker or not ticker.AddTimerLoop then return false end
    S.watcher = true
    local wasInMatch = false
    ticker.AddTimerLoop(1.0, function()
        local inMatch = F.isInRealMatch()
        if inMatch then
            if not wasInMatch then
                wasInMatch = true
                S.applied = false
                pcall(F.bootstrapMatch)
            else
                local char = F.getLocalChar()
                if char then
                    local weapon
                    pcall(function() weapon = char:GetCurrentWeapon() end)
                    if slua.isValid(weapon) then
                        local wac = weapon.WeaponAvatarComponent
                        local visual = slua.isValid(wac) and (wac.CachedLoadedID or 0) or 0
                        local maxIt = 0
                        pcall(function() maxIt = tonumber(weapon:GetWeaponID()) or 0 end)
                        local target = F.get_skin_id(visual, maxIt)
                        if target and target > 0 and target ~= visual then
                            pcall(F.applySkinToWeapon, weapon)
                        end
                    end
                end
            end
        else
            if wasInMatch then wasInMatch = false end
            S.applied = false
            S.weaponApplied = false
        end
    end)
    return true
end
-- ============================================================================
-- HOOK + BOOTSTRAP
-- ============================================================================

-- Respons pemakaian dari server (item asli) ikut dicatat supaya pilihan
-- terakhir tetap tersimpan walau item dipakai lewat jalur native.
function F.hookPutOnRsp()
    local wl = tryRequire("client.slua.logic.wardrobe.logic_wardrobe_new")
    if not wl or wl._rzPutOnRspHooked or not wl.on_puton_rsp then return end
    wl._rzPutOnRspHooked = true
    local orig = wl.on_puton_rsp
    wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
        local result = orig(self, res, item, olditem, index, extra)
        pcall(function()
            if not item then return end
            local resID = tonumber(item.res_id or item.resID)
            local insID = tonumber(item.instid or item.ins_id or item.insID)
            if not resID or resID <= 0 or not insID or insID <= 0 then return end
            R.insToRes[insID], R.resToIns[resID] = resID, insID
            local st = tonumber(F.subTypeOf(resID) or 0)
            if F.slotKeyOf(resID) then
                F.saveEquip(resID, insID)
            elseif THROW_SUBS[st] then
                F.saveThrowObject(resID, insID)
            elseif GUN_SUB[st] then
                local wid = F.weaponIdFromSkin(resID)
                if wid then F.saveWeaponToCache(wid, resID, insID) end
            elseif st == MELEE_ID then
                F.saveWeaponToCache(MELEE_ID, resID, insID)
            elseif F.isVehicleRes(resID) then
                C.vehicle = { sub = F.vehicleSubType and F.vehicleSubType(resID) or nil, res = resID, ins = insID }
                F.persistMarkDirty()
            end
        end)
        return result
    end
end

function F.hookPutOn()
    local WRH = tryRequire("client.network.Protocol.WardRobeHandler")
    if not WRH or WRH._rzPutOnHooked or not WRH.send_depot_put_on_req then return end
    WRH._rzPutOnHooked = true
    local orig = WRH.send_depot_put_on_req
    WRH.send_depot_put_on_req = function(insID, extra)
        insID = tonumber(insID)
        if insID and F.tryLocalWearByIns(insID) then return end
        return orig(insID, extra)
    end
end

function F.hookWardrobePutOnReq()
    local wl = tryRequire("client.slua.logic.wardrobe.logic_wardrobe_new")
    if not wl or wl._rzPutOnReqHooked or not wl.wardrobe_puton_req then return end
    wl._rzPutOnReqHooked = true
    local orig = wl.wardrobe_puton_req
    wl.wardrobe_puton_req = function(self, insID, extra)
        insID = tonumber(insID)
        if insID then
            F.ensureDepotItemValid(insID)
            if F.tryLocalWearByIns(insID) then return end
        end
        return orig(self, insID, extra)
    end
end

function F.hookPutDown()
    local WRH = tryRequire("client.network.Protocol.WardRobeHandler")
    if not WRH or WRH._rzPutDownHooked then return end
    WRH._rzPutDownHooked = true

    local orig = WRH.send_depot_put_down_req
    if orig then
        WRH.send_depot_put_down_req = function(insID)
            insID = tonumber(insID)
            if insID and F.isInjectedIns(insID) then
                F.takeOffInjected(insID)
                return
            end
            return orig(insID)
        end
    end
    local origBatch = WRH.send_depot_batch_put_down_req
    if origBatch then
        WRH.send_depot_batch_put_down_req = function(list)
            local rest = {}
            for _, id in ipairs(list or {}) do
                id = tonumber(id)
                if id and F.isInjectedIns(id) then
                    F.takeOffInjected(id)
                else
                    rest[#rest + 1] = id
                end
            end
            if #rest > 0 then return origBatch(rest) end
        end
    end
end

function F.hookArmory()
    local Arm = tryRequire("client.logic.armory.logic_armory")
    if Arm and not Arm._rzArmoryHooked then
        Arm._rzArmoryHooked = true
        local origInstall = Arm.install_weapon_skin
        if origInstall then
            Arm.install_weapon_skin = function(cd, wid, ins)
                ins = tonumber(ins)
                if ins and F.isWeaponSkinIns(ins) then
                    local resID = R.insToRes[ins]
                    wid = tonumber(F.weaponIdFromSkin(resID) or wid)
                    F.equipWeaponSkin(wid, ins)
                    return
                end
                return origInstall(cd, wid, ins)
            end
        end
    end
    local AH = tryRequire("client.network.Protocol.ArmoryHandler")
    if AH and not AH._rzArmorySendHooked then
        AH._rzArmorySendHooked = true
        local orig = AH.send_install_weapon_skin
        if orig then
            AH.send_install_weapon_skin = function(cd, wid, ins)
                ins = tonumber(ins)
                if ins and F.isWeaponSkinIns(ins) then
                    local resID = R.insToRes[ins]
                    wid = tonumber(F.weaponIdFromSkin(resID) or wid)
                    F.equipWeaponSkin(wid, ins)
                    return
                end
                return orig(cd, wid, ins)
            end
        end
    end
end

function F.hookGunSkinId()
    local wgl = tryRequire("client.slua.logic.wardrobe.logic_wardrobe_gun")
    if not wgl or wgl._rzGunSkinHooked or not wgl.GetSkinIdByWeaponID then return end
    wgl._rzGunSkinHooked = true
    local orig = wgl.GetSkinIdByWeaponID
    wgl.GetSkinIdByWeaponID = function(self, wid)
        local w = C.weapons[tonumber(wid)]
        if w and w.insID and F.isWeaponSkinIns(w.insID) then return w.insID end
        local Arm = tryRequire("client.logic.armory.logic_armory")
        local entry = Arm and Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid]
        local sid = entry and entry.skin_id
        if sid and F.isWeaponSkinIns(sid) then return sid end
        return orig(self, wid)
    end
end

function F.hookWeaponWear()
    local HT = tryRequire("client.logic.lobby.hall_theme_utils")
    if not HT or HT._rzWeaponWearHooked or not HT.IsWeaponWear then return end
    HT._rzWeaponWearHooked = true
    local orig = HT.IsWeaponWear
    HT.IsWeaponWear = function(insID)
        insID = tonumber(insID)
        if insID and F.isInjectedIns(insID) then
            local Arm = tryRequire("client.logic.armory.logic_armory")
            local install = Arm and Arm.rsp_list and Arm.rsp_list.install_list
            for wid, w in pairs(C.weapons) do
                if tonumber(w.insID) == insID then
                    local entry = install and install[wid]
                    if entry then return tonumber(entry.skin_id) == insID end
                end
            end
        end
        return orig(insID)
    end
end

function F.hookEnterGame()
    if S.enterGameHooked then return end
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
            S.enterGameHooked = true
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
                S.applied = false
                S.weaponApplied = false
                S.throwSignature = nil
                F.later(1.0, function()
                    if F.isInLobby() then pcall(F.restoreLobby) end
                end)
                -- Jalur match: karakter sering baru valid beberapa detik
                -- setelah loading screen.  Coba beberapa kali tanpa
                -- bergantung pada AddTimerLoop host.
                for _, delay in ipairs({ 2.0, 4.0, 8.0, 15.0 }) do
                    F.later(delay, function()
                        local ch = F.getLocalChar()
                        if ch then pcall(F.bootstrapMatch, ch) end
                    end)
                end
            end)
        end
    end)
end

function F.installHooks()
    pcall(F.hookWardrobe)
    pcall(F.hookSubTabList)
    pcall(F.hookDepotInit)
    pcall(F.hookWardrobeData)
    pcall(F.hookPageFilter)
    pcall(F.hookPutOn)
    pcall(F.hookWardrobePutOnReq)
    pcall(F.hookPutDown)
    pcall(F.hookPutOnRsp)
    pcall(F.hookArmory)
    pcall(F.hookGunSkinId)
    pcall(F.hookWeaponWear)
    pcall(F.hookWeaponSpawn)
    pcall(F.hookThrowObjects)
    pcall(F.hookEnterGame)
end

function F.start()
    if S.started then return end
    S.started = true
    pcall(F.installHooks)
    pcall(F.persistLoad)
    pcall(F.normalizePersisted)
    pcall(F.syncGlobalWearSkins)
    pcall(F.startMatchWatcher)

    -- Beberapa modul game baru terdaftar setelah lobby siap.  Ulangi pasang
    -- hook tanpa loop ketat: 4 percobaan dalam 20 detik pertama.
    F.later(1.0, function() pcall(F.installHooks) end)
    F.later(3.0, function() pcall(F.installHooks) end)
    F.later(8.0, function() pcall(F.installHooks) end)
    F.later(20.0, function() pcall(F.installHooks) end)

    -- Pulihkan pilihan tersimpan setelah lobby siap (beberapa kali, karena
    -- depot/avatar bisa di-init ulang oleh game saat login).
    for _, delay in ipairs({ 2.0, 6.0, 12.0 }) do
        F.later(delay, function()
            if F.isInLobby() then pcall(F.restoreLobby) end
        end)
    end
end

_G.AddOutfit = F
F.start()
