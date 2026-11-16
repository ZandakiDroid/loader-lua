-- =============================================================================
-- skinautoload — standalone, fitur skin saja
-- -----------------------------------------------------------------------------
-- Sumber: skinautoload.reference.lua (by @RAHMANYVI), bagian "AddOutfit".
-- Dibuang dari versi asli:
--   * cek expiry + sumber waktu internet (worldtimeapi/timezonedb/timeapi)
--   * popup welcome / expired + tautan Telegram
--   * menu mod, ESP, aimbot, scanner/replay/log blocker, anti-report
--   * kelas BRPlayerCharacterBase (file ini tidak menggantikan kelas game,
--     jadi bisa dimuat sendiri lewat loader tanpa BRP)
-- Target runtime: Lua 5.3 (build game 4.7).
--
-- Semua hook dipasang dari file ini; tidak ada dependensi ke chunk lain.
-- =============================================================================

-- Bypass validasi lokal yang menghalangi item hasil injeksi dipakai.
-- Sengaja sempit: hanya validasi avatar/equipment, bukan file check.
local function _skinValidityBypass()
    pcall(function()
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = function() return false end
            AvatarUtils.IsValidAvatar = function() return true end
        end
        local equipmentException = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if equipmentException then
            equipmentException.Report = function() end
        end
    end)
end
pcall(_skinValidityBypass)

    -- =====================================================================
    -- PERSISTENSI OUTFIT — format sama dengan 1.lua (rapzhang_outfit.json)
    -- Disimpan di folder Paks game, berisi slot pakaian, senjata, lemparan,
    -- kendaraan, emote/rolewear, dan tema lobby.
    -- =====================================================================
    local RAPZHANG_CONFIG_FILE = "rapzhang_outfit.json"

    local function _getOutfitConfigPaths(fileName)
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
            "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        }
        pcall(function()
            if os and os.getenv then
                local homeDir = os.getenv("HOME")
                if homeDir and homeDir ~= "" then
                    -- Fallback terakhir. Di Android, path Paks di atas yang
                    -- dipakai 1.lua dan yang biasa diedit user; jangan sampai
                    -- file lama di HOME menutupi file tersebut.
                    paths[#paths + 1] = homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName
                end
            end
        end)
        return paths
    end

    local CONFIG_PATHS = _getOutfitConfigPaths(RAPZHANG_CONFIG_FILE)
    local _configActivePath = nil

    local function _getOutfitSavePath()
        if _configActivePath then return _configActivePath end
        for _, p in ipairs(CONFIG_PATHS) do
            local f
            pcall(function() f = io.open(p, "r") end)
            if f then
                f:close()
                _configActivePath = p
                return p
            end
        end
        _configActivePath = CONFIG_PATHS[1]
        return _configActivePath
    end

    local function _configWrite(txt)
        local function tryWrite(path)
            local f
            pcall(function() f = io.open(path, "w") end)
            if not f then
                pcall(function()
                    local dir = path:match("^(.*)/[^/]+$")
                    if dir and os and os.execute then os.execute('mkdir -p "' .. dir .. '"') end
                end)
                pcall(function() f = io.open(path, "w") end)
            end
            if not f then return false end
            local ok = pcall(function() f:write(txt) end)
            pcall(function() f:close() end)
            return ok
        end
        if _configActivePath and tryWrite(_configActivePath) then return true end
        for _, p in ipairs(CONFIG_PATHS) do
            if tryWrite(p) then
                _configActivePath = p
                return true
            end
        end
        return false
    end

    local function _numID(n)
        n = tonumber(n)
        if not n or n ~= n then return 0 end
        return math.floor(n + 0.5)
    end

    -- Slot yang disimpan sebagai angka tunggal di JSON (seperti 1.lua).
    local OUTFIT_SLOTS = {
        { "outfit", "outfitRes", "outfitIns", "AddOutfitLastLobbyOutfitRes" },
        { "tshirt", "tshirtRes", "tshirtIns", "AddOutfitLastLobbyTshirtRes" },
        { "pants",  "pantsRes",  "pantsIns",  "AddOutfitLastLobbyPantsRes"  },
        { "shoes",  "shoesRes",  "shoesIns",  "AddOutfitLastLobbyShoesRes"  },
        { "hat",    "hatRes",    "hatIns",    "AddOutfitLastLobbyHatRes"    },
        { "mask",   "maskRes",   "maskIns",   "AddOutfitLastLobbyMaskRes"   },
        { "glass",  "glassRes",  "glassIns",  "AddOutfitLastLobbyGlassRes"  },
        { "gloves", "glovesRes", "glovesIns", "AddOutfitLastLobbyGlovesRes" },
    }
    local EQUIP_SLOTS = { "bag", "helmet", "armor", "parachute", "glider" }

    local function _itemConf(resID)
        local getter = CDataTable and CDataTable.GetTableData
        if not getter then return nil end
        local ok, c = pcall(getter, "Item", tonumber(resID))
        if ok then return c end
        return nil
    end

    local _CLOTH_SLOT_SUBTYPE = {
        [401] = "hat", [402] = "mask", [404] = "pants",
        [405] = "shoes", [407] = "glass", [452] = "gloves",
    }

    -- Klasifikasi resID pakaian ke nama slot JSON.
    local function _clothSlotOf(resID)
        resID = tonumber(resID)
        if not resID or resID <= 0 then return nil end
        local c = _itemConf(resID)
        if not c then return nil end
        local st = tonumber(c.ItemSubType or c.itemSubType) or 0
        local slot = _CLOTH_SLOT_SUBTYPE[st]
        if slot then return slot end
        if st == 403 then
            local tab = tonumber(c.WardrobeTab or c.wardrobeTab) or 0
            if tab == 3 then return "tshirt" end
            return "outfit"
        end
        return nil
    end

    local WEAPON_NAMES = {
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
    local WEAPON_IDS_BY_NAME = {}
    for wid, name in pairs(WEAPON_NAMES) do WEAPON_IDS_BY_NAME[name] = wid end
    WEAPON_IDS_BY_NAME["Pan"] = 108
    WEAPON_IDS_BY_NAME["Dagger"] = 108
    WEAPON_IDS_BY_NAME["Machete"] = 108
    WEAPON_IDS_BY_NAME["Melee"] = 108
    WEAPON_IDS_BY_NAME["pan"] = 108
    WEAPON_IDS_BY_NAME["dagger"] = 108
    WEAPON_IDS_BY_NAME["machete"] = 108

    -- Bangun isi rapzhang_outfit.json dari cache runtime.
    local function _encodeOutfitConfig()
        local cch = _G.AddOutfitEquippedCache or {}
        local parts = {}
        local slots = {}

        local function setSlot(name, res)
            res = tonumber(res)
            if res and res > 0 and not slots[name] then slots[name] = _numID(res) end
        end

        setSlot("outfit", cch.outfitRes)
        for _, s in ipairs(OUTFIT_SLOTS) do
            setSlot(s[1], cch[s[2]])
        end
        for resID in pairs(cch.clothes or {}) do
            local name = _clothSlotOf(resID)
            if name then setSlot(name, resID) end
        end
        for _, s in ipairs(OUTFIT_SLOTS) do
            local res = slots[s[1]]
            if res then parts[#parts + 1] = string.format('  "%s": %d', s[1], res) end
        end

        local eq = cch.equip or {}
        for _, slot in ipairs(EQUIP_SLOTS) do
            local res = tonumber(eq[slot])
            if res and res > 0 then
                parts[#parts + 1] = string.format('  "%s": %d', slot, _numID(res))
            end
        end

        local throwParts = {}
        for st, info in pairs(cch.throwObjects or {}) do
            local res = info and tonumber(info.resID)
            local stN = tonumber(st)
            if stN and res and res > 0 then
                throwParts[#throwParts + 1] = string.format('    "%d": %d', stN, _numID(res))
            end
        end
        table.sort(throwParts)
        parts[#parts + 1] = '  "throwObjects": {\n' .. table.concat(throwParts, ",\n") .. '\n  }'

        local weaponParts = {}
        local meleeParts = {}
        for wid, w in pairs(cch.weapons or {}) do
            local widN = tonumber(wid)
            local res = w and tonumber(w.resID)
            if widN and res and res > 0 then
                if widN == 108 then
                    meleeParts[#meleeParts + 1] = string.format('    "pan": %d', _numID(res))
                else
                    weaponParts[#weaponParts + 1] = string.format('    "%s": %d',
                        WEAPON_NAMES[widN] or tostring(widN), _numID(res))
                end
            end
        end
        table.sort(weaponParts)
        table.sort(meleeParts)
        parts[#parts + 1] = '  "weapons": {\n' .. table.concat(weaponParts, ",\n") .. '\n  }'
        parts[#parts + 1] = '  "melee": {\n' .. table.concat(meleeParts, ",\n") .. '\n  }'

        local vehicleParts = {}
        pcall(function()
            local RR = _G.AddOutfit_R
            if not (DataMgr and DataMgr.VehicleSlotList) then return end
            for subType, list in pairs(DataMgr.VehicleSlotList) do
                local stN = tonumber(subType)
                local sparts = {}
                if stN and type(list) == "table" then
                    for idx, val in pairs(list) do
                        local ins = _numID(type(val) == "table" and (val.insID or val.instid) or val)
                        local res = _numID(type(val) == "table" and val.resID
                            or (RR and RR.insToRes and RR.insToRes[ins]))
                        local idxN = tonumber(idx)
                        if idxN and ins > 0 and res > 0 then
                            sparts[#sparts + 1] = string.format('      "%d": %d', idxN, res)
                        end
                    end
                end
                if #sparts > 0 then
                    table.sort(sparts)
                    vehicleParts[#vehicleParts + 1] = string.format('    "%d": {\n%s\n    }',
                        stN, table.concat(sparts, ",\n"))
                end
            end
        end)
        table.sort(vehicleParts)
        parts[#parts + 1] = '  "vehicleSlots": {\n' .. table.concat(vehicleParts, ",\n") .. '\n  }'

        local hallRes, hallIns = 0, 0
        pcall(function()
            local HT = require("client.logic.lobby.hall_theme_utils")
            hallIns = _numID(HT.GetThemeInstId and HT.GetThemeInstId() or 0)
            hallRes = _numID(HT.homeThemeItemId or 0)
            if hallRes <= 0 and hallIns > 0 then
                local RR = _G.AddOutfit_R
                hallRes = _numID(RR and RR.insToRes and RR.insToRes[hallIns])
            end
        end)
        if hallRes > 0 then parts[#parts + 1] = string.format('  "hallTheme": %d', hallRes) end
        if hallIns > 0 then parts[#parts + 1] = string.format('  "hallThemeIns": %d', hallIns) end

        -- Data tambahan standalone supaya tidak hilang saat game restart.
        local clothes = {}
        for resID in pairs(cch.clothes or {}) do
            local n = _numID(resID)
            if n > 0 then clothes[#clothes + 1] = n end
        end
        table.sort(clothes)
        parts[#parts + 1] = '  "clothes": [' .. table.concat(clothes, ", ") .. ']'

        local motion = {}
        pcall(function()
            if DataMgr and DataMgr.MotionSlotList then
                for _, ins in ipairs(DataMgr.MotionSlotList) do
                    local n = _numID(ins)
                    if n > 0 then motion[#motion + 1] = n end
                end
            end
        end)
        parts[#parts + 1] = '  "motion": [' .. table.concat(motion, ", ") .. ']'

        local rolewear = {}
        pcall(function()
            local AvatarData = require("client.logic.data.AvatarData")
            if AvatarData.GetRoleWear then
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    local n = _numID(ins)
                    if n > 0 then rolewear[#rolewear + 1] = n end
                end
            end
        end)
        table.sort(rolewear)
        parts[#parts + 1] = '  "rolewear": [' .. table.concat(rolewear, ", ") .. ']'

        local equipIns = {}
        pcall(function()
            if DataMgr and DataMgr.equipmentSkinInsIDTable then
                for st, ins in pairs(DataMgr.equipmentSkinInsIDTable) do
                    local stN, insN = tonumber(st), _numID(ins)
                    if stN and insN > 0 then
                        equipIns[#equipIns + 1] = string.format('    "%d": %d', stN, insN)
                    end
                end
            end
        end)
        table.sort(equipIns)
        parts[#parts + 1] = '  "equipIns": {\n' .. table.concat(equipIns, ",\n") .. '\n  }'

        local vst = 0
        pcall(function()
            if DataMgr then vst = _numID(DataMgr.vst_skin) end
        end)
        if vst > 0 then parts[#parts + 1] = string.format('  "vstSkin": %d', vst) end

        local garage = {}
        pcall(function()
            local GTS = ModuleManager and ModuleManager.GetModule
                and ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
            if GTS and GTS.GarageVehicleInfo then
                for slot, info in pairs(GTS.GarageVehicleInfo) do
                    local ins = _numID(info and info.inst_id)
                    local res = _numID(info and info.res_id)
                    if ins > 0 then
                        garage[#garage + 1] = string.format(
                            '    "%d": { "inst_id": %d, "res_id": %d }', _numID(slot), ins, res)
                    end
                end
            end
        end)
        table.sort(garage)
        parts[#parts + 1] = '  "garage": {\n' .. table.concat(garage, ",\n") .. '\n  }'

        return "{\n" .. table.concat(parts, ",\n") .. "\n}\n"
    end

    -- Baca JSON (json.decode; kalau tidak ada, fallback regex sederhana).
    local function _decodeOutfitConfig(txt)
        local out = {
            weapons = {}, melee = {}, throwObjects = {}, vehicleSlots = {},
            clothes = {}, garage = {}, equipIns = {}, motion = {}, rolewear = {},
        }
        if not txt or txt == "" then return out end
        local parsed = false
        pcall(function()
            local J = rawget(_G, "json")
            local t = J and J.decode and J.decode(txt)
            if type(t) ~= "table" then return end
            for k, v in pairs(t) do
                if k == "weapons" and type(v) == "table" then
                    for wk, wv in pairs(v) do
                        local wid = tonumber(wk) or WEAPON_IDS_BY_NAME[tostring(wk)]
                        local res = tonumber(wv)
                        if wid and res and res > 0 then out.weapons[wid] = res end
                    end
                elseif k == "melee" and type(v) == "table" then
                    for mk, mv in pairs(v) do
                        local res = tonumber(mv)
                        if (mk == "pan" or mk == "dagger" or mk == "machete") and res and res > 0 then
                            out.melee[mk] = res
                        end
                    end
                elseif k == "throwObjects" and type(v) == "table" then
                    for stk, rv in pairs(v) do
                        local st, res = tonumber(stk), tonumber(rv)
                        if st and res and res > 0 then out.throwObjects[st] = res end
                    end
                elseif k == "vehicleSlots" and type(v) == "table" then
                    for stk, slotMap in pairs(v) do
                        local st = tonumber(stk)
                        if st and type(slotMap) == "table" then
                            out.vehicleSlots[st] = {}
                            for idx, res in pairs(slotMap) do
                                local i, r = tonumber(idx), tonumber(res)
                                if i and r and r > 0 then out.vehicleSlots[st][i] = r end
                            end
                        end
                    end
                elseif k == "clothes" and type(v) == "table" then
                    for _, r in ipairs(v) do
                        r = tonumber(r)
                        if r and r > 0 then out.clothes[r] = true end
                    end
                elseif k == "garage" and type(v) == "table" then
                    for slot, info in pairs(v) do
                        if type(info) == "table" then
                            local ins = tonumber(info.inst_id)
                            if ins and ins > 0 then
                                out.garage[tonumber(slot) or slot] = {
                                    inst_id = ins, res_id = tonumber(info.res_id) or 0,
                                }
                            end
                        end
                    end
                elseif k == "equipIns" and type(v) == "table" then
                    for stk, iv in pairs(v) do
                        local st, ins = tonumber(stk), tonumber(iv)
                        if st and ins and ins > 0 then out.equipIns[st] = ins end
                    end
                elseif (k == "motion" or k == "rolewear") and type(v) == "table" then
                    out[k] = {}
                    for _, iv in ipairs(v) do
                        local ins = tonumber(iv)
                        if ins and ins > 0 then out[k][#out[k] + 1] = ins end
                    end
                else
                    local n = tonumber(v)
                    if n and n > 0 then out[k] = n end
                end
            end
            parsed = true
        end)
        if not parsed then
            local function parseArray(key)
                local list = {}
                local block = txt:match('"' .. key .. '"%s*:%s*%[([^%]]*)%]')
                if block then
                    for v in block:gmatch('(%d+)') do
                        local n = tonumber(v)
                        if n and n > 0 then list[#list + 1] = n end
                    end
                end
                return list
            end
            out.motion = parseArray("motion")
            out.rolewear = parseArray("rolewear")
            for _, r in ipairs(parseArray("clothes")) do out.clothes[r] = true end
            for k, v in txt:gmatch('"([%w_]+)"%s*:%s*(%d+)') do
                local n = tonumber(v)
                if n and n > 0 then
                    if k == "pan" or k == "dagger" or k == "machete" then
                        out.melee[k] = n
                    else
                        local wid = WEAPON_IDS_BY_NAME[k]
                        if wid then out.weapons[wid] = n else out[k] = n end
                    end
                end
            end
            local throwBlock = txt:match('"throwObjects"%s*:%s*{([^}]*)}')
            if throwBlock then
                for stKey, resValue in throwBlock:gmatch('"(%d+)"%s*:%s*(%d+)') do
                    local st, res = tonumber(stKey), tonumber(resValue)
                    if st and res and res > 0 then out.throwObjects[st] = res end
                end
            end
            local eiBlock = txt:match('"equipIns"%s*:%s*{([^}]*)}')
            if eiBlock then
                for stKey, insValue in eiBlock:gmatch('"(%d+)"%s*:%s*(%d+)') do
                    local st, ins = tonumber(stKey), tonumber(insValue)
                    if st and ins and ins > 0 then out.equipIns[st] = ins end
                end
            end
            local gStart = txt:find('"garage"', 1, true)
            if gStart then
                for slotKey, body in txt:sub(gStart):gmatch('"(%d+)"%s*:%s*{([^}]*)}') do
                    local slot = tonumber(slotKey)
                    local ins = tonumber(body:match('"inst_id"%s*:%s*(%d+)'))
                    local res = tonumber(body:match('"res_id"%s*:%s*(%d+)'))
                    if slot and ins and ins > 0 then
                        out.garage[slot] = { inst_id = ins, res_id = res or 0 }
                    end
                end
            end
            local vsStart = txt:find('"vehicleSlots"', 1, true)
            if vsStart then
                for stKey, body in txt:sub(vsStart):gmatch('"(%-?%d+)"%s*:%s*{([^}]*)}') do
                    local st = tonumber(stKey)
                    if st then
                        local slotMap = {}
                        for idx, res in body:gmatch('"(%-?%d+)"%s*:%s*(%d+)') do
                            local i, r = tonumber(idx), tonumber(res)
                            if i and r and r > 0 then slotMap[i] = r end
                        end
                        if next(slotMap) then out.vehicleSlots[st] = slotMap end
                    end
                end
            end
        end
        return out
    end

    local function _saveEquippedCache()
        pcall(function()
            if not (io and io.open) then return end
            _configWrite(_encodeOutfitConfig())
        end)
    end

    local function _loadEquippedCache()
        if not (io and io.open) then return end
        pcall(function()
            for _, path in ipairs(CONFIG_PATHS) do
                local f
                pcall(function() f = io.open(path, "r") end)
                if f then
                    local txt = f:read("*a")
                    f:close()
                    if not txt or txt == "" then return end
                    local saved = _decodeOutfitConfig(txt)
                    _configActivePath = path

                    _G._savedOutfitClothes = {}
                    _G._savedOutfitRes = nil
                    _G._savedOutfitIns = nil
                    _G._savedOutfitEquip = {}
                    _G._savedVehicleSlotList = {}
                    _G._savedVehicleResSlots = saved.vehicleSlots
                    _G._savedGarageVehicles = saved.garage or {}
                    _G._savedMotionList = saved.motion or {}
                    _G._savedRoleWearList = saved.rolewear or {}
                    _G._savedEquipIns = saved.equipIns or {}
                    _G._savedVstSkin = tonumber(saved.vstSkin)
                    _G._savedHallThemeIns = tonumber(saved.hallThemeIns)
                    _G._savedHallThemeRes = tonumber(saved.hallTheme)
                    _G._savedThrowObjects = {}

                    local cch = _G.AddOutfitEquippedCache
                    if not cch then
                        cch = { clothes = {}, equip = {}, weapons = {} }
                        _G.AddOutfitEquippedCache = cch
                    end
                    cch.clothes = cch.clothes or {}
                    cch.equip = cch.equip or {}
                    cch.weapons = cch.weapons or {}
                    cch.throwObjects = cch.throwObjects or {}

                    local outfitRes = tonumber(saved.outfit)
                    if outfitRes and outfitRes > 0 then
                        cch.outfitRes = outfitRes
                        _G.AddOutfitLastLobbyOutfitRes = outfitRes
                        _G._savedOutfitRes = outfitRes
                    end

                    for _, key in ipairs({ "tshirt", "pants", "shoes", "hat", "mask", "glass", "gloves" }) do
                        local res = tonumber(saved[key])
                        if res and res > 0 then
                            cch.clothes[res] = true
                            _G._savedOutfitClothes[res] = true
                        end
                    end
                    for res in pairs(saved.clothes) do
                        -- Jangan masukkan skin senjata/equip ke daftar pakaian.
                        if not _itemConf(res) or _clothSlotOf(res) then
                            cch.clothes[res] = true
                            _G._savedOutfitClothes[res] = true
                        end
                    end

                    for _, slot in ipairs(EQUIP_SLOTS) do
                        local res = tonumber(saved[slot])
                        if res and res > 0 then
                            cch.equip[slot] = res
                            _G._savedOutfitEquip[slot] = res
                        end
                    end

                    for wid, res in pairs(saved.weapons) do
                        cch.weapons[wid] = { resID = res, insID = 0 }
                        _G._savedOutfitEquip["weapon_" .. tostring(wid)] = { resID = res, insID = 0 }
                    end
                    local meleeRes = tonumber(saved.melee and (saved.melee.pan or saved.melee.dagger or saved.melee.machete))
                    if meleeRes and meleeRes > 0 then
                        cch.weapons[108] = cch.weapons[108] or { resID = meleeRes, insID = 0 }
                        _G._savedOutfitEquip["weapon_108"] = cch.weapons[108]
                    end

                    for st, res in pairs(saved.throwObjects) do
                        cch.throwObjects[st] = { resID = res, insID = 0 }
                        _G._savedThrowObjects[st] = { resID = res, insID = 0 }
                    end

                    _G.AddOutfitPendingPersist = saved
                    _G._addOutfitPersistLoaded = true
                    print("[AddOutfit] Loaded rapzhang_outfit.json:", path)
                    return
                end
            end
        end)
    end

    _G.AddOutfitEncodeConfig = function() return _encodeOutfitConfig() end
    _G.AddOutfitDecodeConfig = function(txt) return _decodeOutfitConfig(txt) end

    local function _snapshotCache()
        local cch = _G.AddOutfitEquippedCache
        if not cch then return "" end
        local parts = {}
        parts[#parts + 1] = tostring(cch.outfitRes or 0)
        local clothIds = {}
        for resID in pairs(cch.clothes or {}) do
            clothIds[#clothIds + 1] = resID
        end
        table.sort(clothIds)
        parts[#parts + 1] = table.concat(clothIds, ",")
        local eq = cch.equip or {}
        parts[#parts + 1] = tostring(eq.bag or 0)
        parts[#parts + 1] = tostring(eq.helmet or 0)
        parts[#parts + 1] = tostring(eq.armor or 0)
        parts[#parts + 1] = tostring(eq.parachute or 0)
        parts[#parts + 1] = tostring(eq.glider or 0)
        local wIds = {}
        for wid in pairs(cch.weapons or {}) do wIds[#wIds + 1] = wid end
        table.sort(wIds)
        for _, wid in ipairs(wIds) do
            local w = cch.weapons[wid]
            parts[#parts + 1] = tostring(wid) .. ":" .. tostring(w.resID or 0)
        end
        if cch.throwObjects then
            local tIds = {}
            for st in pairs(cch.throwObjects) do tIds[#tIds + 1] = st end
            table.sort(tIds)
            for _, st in ipairs(tIds) do
                local info = cch.throwObjects[st]
                parts[#parts + 1] = "throw_" .. tostring(st) .. ":" .. tostring(info.resID or 0)
            end
        end
        return table.concat(parts, "|")
    end

    local _lastSnapshot = ""
    local _saveDirty = false
    local _saveInProgress = false
    local _lastSaveClock = 0
    local SAVE_MIN_INTERVAL = 2.5

    local function _flushSave(force)
        if _saveInProgress then
            _saveDirty = true
            return
        end
        local now = 0
        pcall(function() now = os.clock() end)
        if not force and _lastSaveClock > 0 and (now - _lastSaveClock) < SAVE_MIN_INTERVAL then
            _saveDirty = true
            return
        end
        _saveInProgress = true
        _saveDirty = false
        pcall(function()
            if _G.AddOutfitSyncCacheBeforeSave then _G.AddOutfitSyncCacheBeforeSave() end
            _lastSnapshot = _snapshotCache()
            pcall(_saveEquippedCache)
            local cch2 = _G.AddOutfitEquippedCache
            if cch2 then
                _G._savedOutfitRes = tonumber(cch2.outfitRes) and cch2.outfitRes > 0 and cch2.outfitRes or nil
                _G._savedOutfitIns = tonumber(cch2.outfitIns) and cch2.outfitIns > 0 and cch2.outfitIns or nil
                _G._savedOutfitClothes = {}
                for resID in pairs(cch2.clothes or {}) do
                    _G._savedOutfitClothes[resID] = true
                end
            end
        end)
        pcall(function() _lastSaveClock = os.clock() end)
        _saveInProgress = false
    end

    local _saveDeferred = false
    local function _AutoSaveOutfit(force)
        if force then
            _flushSave(true)
            return
        end
        _saveDirty = true
        if _saveDeferred then return end
        _saveDeferred = true
        local function _doDeferredFlush()
            _saveDeferred = false
            if _saveDirty then _flushSave(false) end
        end
        local ok = pcall(_G.SetTimer, 0.5, _doDeferredFlush)
        if not ok then _doDeferredFlush() end
    end

    _G.AddOutfitTryFlushSave = function()
        if _saveDirty then _flushSave(false) end
    end

    -- ========== حقن WardrobeNewHandler (لإصلاح حفظ السيارات في اللوبي) ==========
    pcall(function()
        local WardrobeNewHandler = {}

        local _bShowNotice = false

        local _ao_R = nil
        local function getR()
            if _ao_R then return _ao_R end
            _ao_R = _G.AddOutfit_R
            return _ao_R
        end
        local function aoIsInjectedIns(ins)
            ins = tonumber(ins)
            if not ins then return false end
            local R = getR()
            return R and R.insToRes[ins] ~= nil
        end

        function WardrobeNewHandler.send_depot_modify_combat_vehicle_req(insID, slotIndex, bShowNotice)
            insID = tonumber(insID)
            slotIndex = tonumber(slotIndex) or 1
            _bShowNotice = bShowNotice
            if aoIsInjectedIns(insID) then
                local R = getR()
                local resID = R and R.insToRes[insID]
                local itemSubType = 0
                if resID and CDataTable and CDataTable.GetTableData then
                    local c = CDataTable.GetTableData("Item", resID)
                    itemSubType = c and tonumber(c.ItemSubType or c.itemSubType) or 0
                end
                if itemSubType and itemSubType > 0 and DataMgr then
                    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                    local slotList = DataMgr.VehicleSlotList[itemSubType] or {}
                    if bShowNotice then
                        for i = #slotList, 1, -1 do
                            if slotList[i] == insID then
                                table.remove(slotList, i)
                            end
                        end
                        slotList[slotIndex] = insID
                    else
                        for i, sid in ipairs(slotList) do
                            if sid == insID then
                                table.remove(slotList, i)
                                break
                            end
                        end
                    end
                    DataMgr.VehicleSlotList[itemSubType] = slotList
                end
                pcall(function()
                    local tabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
                    if tabSurveillance and tabSurveillance.VehicleChange then
                        tabSurveillance.VehicleChange()
                    end
                end)
                -- Dorong ulang daftar avatar kendaraan (skin + model).
                pcall(function()
                    if _G.AddOutfitSyncVehicleAvatarSkinList then
                        _G.AddOutfitSyncVehicleAvatarSkinList(true)
                    end
                end)
                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE)
                end
                pcall(_AutoSaveOutfit)
                return
            end
            local NetManager = require("client.network.comm.NetManager")
            NetManager.SendPkg(1012780591, insID, slotIndex, bShowNotice)
        end

        function WardrobeNewHandler.on_depot_modify_combat_vehicle_rsp(ret_code, vehicle_info)
            if ret_code ~= 0 and ret_code ~= NetErrorCode_NONE then
                if _bShowNotice and ShowNotice then ShowNotice(ret_code) end
                return
            end
            if vehicle_info and DataMgr then
                DataMgr.VehicleSlotList = vehicle_info
            end
            pcall(function()
                local tabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
                if tabSurveillance and tabSurveillance.VehicleChange then
                    tabSurveillance.VehicleChange()
                end
            end)
            if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE)
            end
        end

        function WardrobeNewHandler.send_select_item(insID)
            local NetManager = require("client.network.comm.NetManager")
            NetManager.SendPkg(595484784, insID)
        end

        function WardrobeNewHandler.send_equip_motion_list_req(motion_list)
            local NetManager = require("client.network.comm.NetManager")
            NetManager.SendPkg(1124239581, motion_list)
        end

        package.loaded["client.network.Protocol.WardrobeNewHandler"] = WardrobeNewHandler
        print("[AddOutfit] WardrobeNewHandler injected into package.loaded")
    end)

    local _ao_ok, _ao_err = pcall(function()
        -- Per-match guard using match counter (handles controller reuse across matches)
        do
            local curMatchID = ""
            pcall(function()
                local GD = require("GameLua.GameCore.Data.GameplayData")
                if GD and GD.GetPlayerController then
                    local pc = GD.GetPlayerController()
                    if pc and slua.isValid(pc) then
                        -- Use the player key + timestamp as unique match ID
                        curMatchID = tostring(pc.PlayerKey or "") .. "_" .. tostring(pc)
                    end
                end
            end)
            if curMatchID == "" then
                _G._AO_MATCH_ID = nil
            elseif _G._AO_MATCH_ID == curMatchID then
                return  -- Already loaded for this match
            else
                _G._AO_MATCH_ID = curMatchID
            end
        end
        local game_frontend_hud = require("game_frontend_hud")

        local DEBUG = false  -- toast/notify dimatikan: tanpa popup
        local function isInMatchOrGame()
            local ok, r = pcall(function()
                if GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus() then
                    return true
                end
                if GameStatus and GameStatus.IsInLobbyOrMainCity and not GameStatus.IsInLobbyOrMainCity() then
                    return true
                end
            end)
            return ok and r == true
        end
        local function log(...)
            print("[AddOutfit]", ...)
        end

        local MATCH_CONFIG = {
            outfitRes = 0,
            weaponSkins = {},
            equip = { bag = 0, helmet = 0, armor = 0 },
        }

        local ITEMS = {}
        local _itemsLoaded = false  -- -- by @RAHMANYVI
        local function buildNonMaxLevelSet()
            local nonMax = {}
            if not (CDataTable and CDataTable.GetTable) then return nonMax end
-- by @RAHMANYVI
            pcall(function()
                local upTbl = CDataTable.GetTable("ItemUpgradeConfig")
                if not upTbl then return end
-- by @RAHMANYVI
                local maxLvl, maxItem = {}, {}
                local groupMembers = {}
                for _, cfg in pairs(upTbl) do
                    local gid   = tonumber(cfg.GroupID)
                    local lvl   = tonumber(cfg.Level)
                    local itm   = tonumber(cfg.ItemID)
                    if gid and lvl and itm then
                        if not groupMembers[gid] then groupMembers[gid] = {} end
                        groupMembers[gid][#groupMembers[gid] + 1] = itm
                        if not maxLvl[gid] or lvl > maxLvl[gid] then
                            maxLvl[gid] = lvl
                            maxItem[gid] = itm
                        end
                    end
                end
                for gid, members in pairs(groupMembers) do
                    local topItem = maxItem[gid]
                    for _, itm in ipairs(members) do
                        if itm ~= topItem then nonMax[itm] = true end
                    end
                end
            end)

-- by @RAHMANYVI
            local function processXSuitTable(tableName)
                pcall(function()
                    local tbl = CDataTable.GetTable(tableName)
                    if not tbl then return end
                    local maxStar, maxItem = {}, {}
                    local periodMembers = {}
                    for _, data in pairs(tbl) do
                        local period = tonumber(data.Period or data.period)
                        local star   = tonumber(data.Star or data.star or data.Level or data.level)
                        local itm    = tonumber(data.ItemID or data.itemID or data.ItemId)
                        if period and star and itm then
                            if not periodMembers[period] then periodMembers[period] = {} end
                            periodMembers[period][#periodMembers[period] + 1] = itm
                            if not maxStar[period] or star > maxStar[period] then
                                maxStar[period] = star
                                maxItem[period] = itm
                            end
                        end
                    end
                    for period, members in pairs(periodMembers) do
                        local topItem = maxItem[period]
                        for _, itm in ipairs(members) do
                            if itm ~= topItem then nonMax[itm] = true end
                        end
                    end
                end)
            end
            processXSuitTable("GoldenSuitUpgradeCfg")
            processXSuitTable("GoldenSuitUpgradeCfgKJ")
            processXSuitTable("GoldenSuitUpgradeCfgIN")

-- by @RAHMANYVI
            pcall(function()
                local bpMap = CDataTable.GetTable("BackpackMapping")
                if not bpMap then return end
                for _, m in pairs(bpMap) do
                    local lv3 = tonumber(m.SkinItemIDLv3 or 0) or 0
                    local lv1 = tonumber(m.SkinItemIDLv1 or 0) or 0
                    local lv2 = tonumber(m.SkinItemIDLv2 or 0) or 0
                    if lv1 > 0 and lv1 ~= lv3 then nonMax[lv1] = true end
                    if lv2 > 0 and lv2 ~= lv3 then nonMax[lv2] = true end
                end
            end)

            return nonMax
        end

        local function refreshItems()
            if _itemsLoaded then return #ITEMS end
            if #ITEMS > 0 then return #ITEMS end
            local ItemTable = CDataTable and CDataTable.GetTable and CDataTable.GetTable("Item")
            if not ItemTable then return 0 end
            local nonMax = buildNonMaxLevelSet()
            local seen, count, skipped = {}, 0, 0
            for id, v in pairs(ItemTable) do
                local rid = tonumber(v.ID or v.Id or id)
                if rid and rid > 0 and not seen[rid] then
                    local bpId = tonumber(v.BPID or v.bpID or v.BpId or 0) or 0
                    local mainTab = tonumber(v.WardrobeMainTab or v.wardrobeMainTab or 0) or 0
                    if bpId ~= 0 or mainTab ~= 0 then
                        seen[rid] = true
                        if nonMax[rid] then
                            skipped = skipped + 1
                        else
                            ITEMS[#ITEMS + 1] = rid
                            count = count + 1
                        end
                    end
                end
            end
            table.sort(ITEMS)
            if count > 0 then
                _itemsLoaded = true
                log("@RAHMANYVI", count, "-- by @RAHMANYVI", "(-- by @RAHMANYVI", skipped, "-- by @RAHMANYVI)")
            end
            return count
        end
        local _K = {
            INS_BASE = 2000000000, PKG_SLOT = 3, MELEE_ID = 108,
            GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true },
            NET_OK = NetErrorCode_NONE or "ok",
            GUN_MASTER_SYN_SLOT = 7,
            THROW_SUB = { [612] = "shoulei", [613] = "smoke", [614] = "stun", [615] = "burn" },
            THROW_AVATAR_KEY = { shoulei = "GrenadeAvatarShoulei", smoke = "GrenadeAvatarSmoke", stun = "GrenadeAvatarStun", burn = "GrenadeAvatarBurn" },
        }

        local R = { insToRes = {}, resToIns = {} }
        local _injectedResSet = {}
        for _, rid in ipairs(ITEMS) do _injectedResSet[rid] = true end

        local _C = { cfg = {}, fullSuit = {}, equipSlot = {}, weaponId = {}, itemTab = {}, vehicleItems = {}, pageMatch = {} }

        local _S = {
            matchApplied = false, matchTimer = nil, matchOutfitDone = false,
            avatarItemsRegistered = false, weaponApplied = false, weaponDiagDone = false,
            lastWeaponResID = 0, weaponSpawnHooked = false, bootstrapNotified = false,
            globalFrame = 0, weaponHookGuardUntil = 0, equipSkinApplying = false,
            injectedDone = false, lastAppliedWeaponID = 0, lastAppliedSkinID = 0,
            bootstrapped = false, lobbyApplied = false,
        }

        _G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
        _G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}
        _G.AddOutfitLastLobbyOutfitRes = _G.AddOutfitLastLobbyOutfitRes or nil

        _K.ST_TOP     = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Package_Slot) or 403
        _K.ST_PANTS   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Pants_Slot) or 404
        _K.ST_SHOES   = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.Shoes_Slot) or 405
        _K.ST_UNDER_T = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderCloth) or 450
        _K.ST_UNDER_P = (ENUM_ITEM_SUBTYPE and ENUM_ITEM_SUBTYPE.UnderPants) or 451
        _K.WARDROBE_TAB_SUIT, _K.WARDROBE_TAB_CLOTHES = 10, 3
        _K.WARDROBE_TAB_TROUSERS, _K.WARDROBE_TAB_SHOES = 4, 5
        _K.WARDROBE_TAB_BAG, _K.WARDROBE_TAB_HELMET, _K.WARDROBE_TAB_ARMOR = 15, 16, 17
        _K.WARDROBE_TAB_GUN, _K.WARDROBE_TAB_PARACHUTE = 9, 7
        _K.WARDROBE_TAB_GLIDER = 20
        _K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_PAGE_WEAPON, _K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_PAGE_VEHICLE = 1, 4, 5, 6
        pcall(function()
            local wm = require("client.slua.umg.Wardrobe.wardrobe_macro")
            local t = wm.ENUM_WardrobeSubTabString
            _K.WARDROBE_TAB_SUIT = t.ENUM_WardrobeSubTabString_suit
            _K.WARDROBE_TAB_CLOTHES = t.ENUM_WardrobeSubTabString_clothes
            _K.WARDROBE_TAB_TROUSERS = t.ENUM_WardrobeSubTabString_trousers
            _K.WARDROBE_TAB_SHOES = t.ENUM_WardrobeSubTabString_shoes
            _K.WARDROBE_TAB_BAG = t.ENUM_WardrobeSubTabString_bag
            _K.WARDROBE_TAB_HELMET = t.ENUM_WardrobeSubTabString_helmet
            _K.WARDROBE_TAB_ARMOR = t.ENUM_WardrobeSubTabString_armor
            _K.WARDROBE_TAB_GUN = t.ENUM_WardrobeSubTabString_gun
            _K.WARDROBE_TAB_PARACHUTE = t.ENUM_WardrobeSubTabString_parachute
            _K.WARDROBE_TAB_GLIDER = t.ENUM_WardrobeSubTabString_effect
            _K.WARDROBE_PAGE_AVATAR = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Avatar
            _K.WARDROBE_PAGE_WEAPON = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Weapon
            _K.WARDROBE_PAGE_PARACHUTE = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Parachute
            _K.WARDROBE_PAGE_VEHICLE = wm.ENUM_WardrobePageTypeId.ENUM_WardrobePageType_Vehicle
        end)

        local FULL_SUIT_CLEAR_ST = {
            [_K.ST_TOP] = true, [_K.ST_PANTS] = true, [_K.ST_SHOES] = true,
            [_K.ST_UNDER_T] = true, [_K.ST_UNDER_P] = true,
        }

        local function cache()
            _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
                outfitRes = nil, outfitIns = nil,
                clothes = {},
                equip = {},
                weapons = {},
            }
            return _G.AddOutfitEquippedCache
        end

        local function cfg(resID)
            if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.cfg[resID] ~= nil then return _C.cfg[resID] end
            local c = CDataTable.GetTableData("Item", resID)
            _C.cfg[resID] = c
            return c
        end

        local function subType(c)
            return c and (c.ItemSubType or c.itemSubType) or nil
        end

        local function isThrowObjectRes(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local c = cfg(resID)
            if not c then return nil end
            local st = tonumber(c.ItemSubType or c.itemSubType or 0)
            if _K.THROW_SUB[st] then return st end
            return nil
        end

        local function saveThrowObject(resID, insID)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID then return end
            local st = isThrowObjectRes(resID)
            if not st then return end
            local cch = cache()
            cch.throwObjects = cch.throwObjects or {}
            cch.throwObjects[st] = { resID = resID, insID = insID or R.resToIns[resID] or 0 }
        end

        local function isInjectedIns(ins)
            return ins and R.insToRes[tonumber(ins)] ~= nil
        end

        local function isInjectedRes(res)
            return res and (R.resToIns[tonumber(res)] ~= nil or _injectedResSet[tonumber(res)])
        end

        local function weaponIdFromSkin(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.weaponId[resID] ~= nil then return _C.weaponId[resID] end
            local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
            local wid = m and (m.WeaponID or m.WeaponId) or nil
            _C.weaponId[resID] = wid
            return wid
        end

        local function isHallThemeRes(resID)
            resID = tonumber(resID)
            if not resID then return false end
            local c = cfg(resID)
            if not c then return false end
            local it = tonumber(c.ItemType or c.itemType or 0)
            if ENUM_ITEM_TYPE and ENUM_ITEM_TYPE.Hall_Theme then
                return it == ENUM_ITEM_TYPE.Hall_Theme
            end
            return it == 202
        end

        local function getEquipSkinSlot(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _C.equipSlot[resID] ~= nil then return _C.equipSlot[resID] end
            local slot = nil
            local itemCfg = cfg(resID)
            if itemCfg then
                local st = tonumber(itemCfg.ItemSubType or itemCfg.itemSubType or 0)
                local it = tonumber(itemCfg.ItemType or itemCfg.itemType or 0)
                if st == 501 or st == 504 then slot = "bag"
                elseif st == 502 or st == 505 then slot = "helmet"
                elseif st == 503 or st == 506 then slot = "armor"
                elseif it == 4 and st == 701 then slot = "parachute"
                elseif it == 4 and (st == 413 or st == 414 or st == 415) then slot = "glider" end
            end
            if not slot then
                if resID >= 1502000000 and resID < 1503000000 then slot = "helmet"
                elseif resID >= 1505000000 and resID < 1506000000 then slot = "helmet"
                elseif resID >= 1501000000 and resID < 1502000000 then slot = "bag"
                elseif resID >= 1504000000 and resID < 1505000000 then slot = "bag" end
            end
            _C.equipSlot[resID] = slot
            return slot
        end

        local function wardrobeTab(resID, depotData)
            if depotData and depotData.subTabType then return tonumber(depotData.subTabType) end
            local c = cfg(resID)
            return c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
        end

        local function wardrobeMainTab(resID, depotData)
            if depotData and depotData.mainTabType then return tonumber(depotData.mainTabType) end
            local c = cfg(resID)
            return c and tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or _K.WARDROBE_PAGE_AVATAR
        end

        local function getInjectedItemTab(resID, depotData)
            resID = tonumber(resID)
            if not resID then return nil, nil end
            if _C.itemTab[resID] then
                return _C.itemTab[resID][1], _C.itemTab[resID][2]
            end
            local c = cfg(resID)
            local st = c and tonumber(c.ItemSubType or c.itemSubType) or 0

            local equipSlot = getEquipSkinSlot(resID)
            local result
            if equipSlot == "bag" then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_BAG}
            elseif equipSlot == "helmet" then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_HELMET}
            elseif equipSlot == "armor" then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_ARMOR}
            elseif equipSlot == "parachute" then result = {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_PARACHUTE}
            elseif equipSlot == "glider" then result = {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_GLIDER}
            elseif weaponIdFromSkin(resID) then result = {_K.WARDROBE_PAGE_WEAPON, _K.WARDROBE_TAB_GUN}
            else
                local mainTab = wardrobeMainTab(resID, depotData)
                local subTab = wardrobeTab(resID, depotData)
                if subTab and subTab > 0 then result = {mainTab, subTab}
                elseif st == _K.ST_PANTS then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_TROUSERS}
                elseif st == _K.ST_SHOES then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SHOES}
                elseif st == _K.ST_TOP then
                    if isFullSuitRes(resID, depotData) then result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SUIT}
                    else result = {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_CLOTHES} end
                elseif st == 400 or st == 408 or st == 409 or st == 410 then
                    result = {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_PARACHUTE}
                else
                    result = {mainTab, subTab or 0}
                end
            end
            _C.itemTab[resID] = result
            return result[1], result[2]
        end

        local function injectedMatchesPage(resID, depotData, mainTab, subTab)
            local itemMain, itemSub = getInjectedItemTab(resID, depotData)
            if itemMain ~= mainTab or itemSub ~= subTab then return false end
            if subTab == _K.WARDROBE_TAB_SUIT or subTab == _K.WARDROBE_TAB_CLOTHES then
                local st = depotData and depotData.itemSubType or subType(cfg(resID))
                if st == _K.ST_TOP then
                    local full = isFullSuitRes(resID, depotData)
                    if subTab == _K.WARDROBE_TAB_SUIT then return full end
                    if subTab == _K.WARDROBE_TAB_CLOTHES then return not full end
                end
            end
            return true
        end

        local function isFullSuitRes(resID, depotData)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return false end
            if _C.fullSuit[resID] ~= nil then return _C.fullSuit[resID] end
            local result = false
            pcall(function()
                local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
                if LogicXSuit.IsXSuit(resID) then result = true end
            end)
            if not result then
                local tab = wardrobeTab(resID, depotData)
                if tab == _K.WARDROBE_TAB_SUIT then result = true end
            end
            _C.fullSuit[resID] = result
            return result
        end

        local function getClothKind(resID, depotData)
            resID = tonumber(resID)
            if not resID then return nil end
            local st = subType(cfg(resID))
            if st == _K.ST_TOP then
                return isFullSuitRes(resID, depotData) and "full_suit" or "top"
            end
            if st == _K.ST_PANTS then return "pants" end
            if st == _K.ST_SHOES then return "shoes" end
            if st == _K.ST_UNDER_T then return "under_top" end
            if st == _K.ST_UNDER_P then return "under_pants" end
            return nil
        end

        local function subTypesToClearForKind(kind)
            if kind == "full_suit" then return FULL_SUIT_CLEAR_ST end
            if kind == "top" then return { [_K.ST_TOP] = true } end
            if kind == "pants" then return { [_K.ST_PANTS] = true } end
            if kind == "shoes" then return { [_K.ST_SHOES] = true } end
            if kind == "under_top" then return { [_K.ST_UNDER_T] = true } end
            if kind == "under_pants" then return { [_K.ST_UNDER_P] = true } end
            return nil
        end

        local function isBodyClothSubType(st)
            st = tonumber(st)
            return st == _K.ST_TOP or st == _K.ST_PANTS or st == _K.ST_SHOES or st == _K.ST_UNDER_T or st == _K.ST_UNDER_P
        end

        local _outfitMergeCache = { key = nil, items = nil }
        local _weaponSkinResMergeCache = { key = nil, res = nil }
        local _convertCache = {}

        local function getConvertedAvatarCustom(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            if _convertCache[resID] ~= nil then return _convertCache[resID] end
            local AvatarData = require("client.logic.data.AvatarData")
            local converted = AvatarData.ConvertToAvatarCustom({ resID, 0, 0 })
            _convertCache[resID] = converted
            return converted
        end

        local function invalidateSocialWearCache()
            local s = _G.AddOutfitSocialState
            if s then
                s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
            end
            _outfitMergeCache.key = nil
            _outfitMergeCache.items = nil
            _weaponSkinResMergeCache.key = nil
            _weaponSkinResMergeCache.res = nil
        end

-- by @RAHMANYVI
        local EQUIP_LEVEL_SETS = {
            [1502000382] = { lv1 = 1502001382, lv2 = 1502002382, lv3 = 1502003382, slot = "helmet" },
        }
        local _equipLevelByRes = {}
        local function registerEquipLevelSet(catalog, lv1, lv2, lv3, slot)
            catalog = tonumber(catalog)
            if not catalog then return end
            local set = {
                catalog = catalog,
                lv1 = tonumber(lv1) or 0,
                lv2 = tonumber(lv2) or 0,
                lv3 = tonumber(lv3) or 0,
                slot = slot or "helmet",
            }
            EQUIP_LEVEL_SETS[catalog] = set
            for _, rid in ipairs({ catalog, set.lv1, set.lv2, set.lv3 }) do
                if rid and rid > 0 then _equipLevelByRes[rid] = set end
            end
        end
        for catalog, set in pairs(EQUIP_LEVEL_SETS) do
            registerEquipLevelSet(catalog, set.lv1, set.lv2, set.lv3, set.slot)
        end
        _G.AddOutfitRegisterEquipLevelSet = registerEquipLevelSet

-- by @RAHMANYVI
        local EQUIP_LEVEL_RANGES = {
            { base = 1502000000, slot = "helmet" }, ---- by @RAHMANYVI
            { base = 1501000000, slot = "bag"    }, --  @RAHMANYVI
        }

        local function findEquipLevelRange(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            for _, r in ipairs(EQUIP_LEVEL_RANGES) do
                if resID >= r.base and resID < r.base + 1000000 then return r end
            end
            return nil
        end

        local function detectLevelFromPattern(resID)
            resID = tonumber(resID)
            if not resID then return nil, nil end
            local r = findEquipLevelRange(resID)
            if not r then return nil, nil end
            if resID < r.base + 1000 or resID >= r.base + 4000 then return nil, nil end
            local tail = resID - r.base
            local levelDigit = math.floor(tail / 1000)
            if levelDigit >= 1 and levelDigit <= 3 then
                return levelDigit, r.base + (tail - levelDigit * 1000)
            end
            return nil, nil
        end

        local function buildPatternLevelSet(catalog)
            catalog = tonumber(catalog)
            if not catalog then return nil end
            local r = findEquipLevelRange(catalog)
            if not r then return nil end
            local tail = catalog - r.base
            if tail < 0 or tail >= 1000 then return nil end
            return {
                catalog = catalog,
                lv1 = catalog + 1000,
                lv2 = catalog + 2000,
                lv3 = catalog + 3000,
                slot = r.slot,
            }
        end

        local function getEquipLevelSet(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local set = _equipLevelByRes[resID]
            if set then return set end
            local level, catalog = detectLevelFromPattern(resID)
            if catalog then
                if EQUIP_LEVEL_SETS[catalog] then return EQUIP_LEVEL_SETS[catalog] end
                if level then return buildPatternLevelSet(catalog) end
            end
            -- @RAHMANYVI
            local direct = buildPatternLevelSet(resID)
            if direct then
                _equipLevelByRes[resID] = direct
                if direct.lv1 > 0 then _equipLevelByRes[direct.lv1] = direct end
                if direct.lv2 > 0 then _equipLevelByRes[direct.lv2] = direct end
                if direct.lv3 > 0 then _equipLevelByRes[direct.lv3] = direct end
            end
            return direct
        end

        local function normalizeEquipCatalogRes(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return 0 end
            local set = getEquipLevelSet(resID)
            if set then return set.catalog end
            return resID
        end

        local function detectLevelFromEquipRes(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local set = getEquipLevelSet(resID)
            if set then
                if resID == set.lv1 then return 1
                elseif resID == set.lv2 then return 2
                elseif resID == set.lv3 then return 3 end
            end
            local level = detectLevelFromPattern(resID)
            return level
        end

        local function mapEquipLevelSet(set, level)
            if not set then return 0 end
            level = tonumber(level) or 3
            if level == 1 then return set.lv1 or 0
            elseif level == 2 then return set.lv2 or 0 end
            return set.lv3 or 0
        end

        local function mapEquipSkinRes(resID, level)
            resID, level = tonumber(resID), tonumber(level) or 3
            if not resID or resID <= 0 then return 0 end
            local catalogRes = normalizeEquipCatalogRes(resID)
            local set = getEquipLevelSet(catalogRes)
            if set then
                local mapped = mapEquipLevelSet(set, level)
                if mapped > 0 then return mapped end
            end
            local mapped = 0
            pcall(function()
                local itemMappingCfg = CDataTable.GetTableData("BackpackMapping", catalogRes)
                if itemMappingCfg then
                    if level == 1 then mapped = tonumber(itemMappingCfg.SkinItemIDLv1) or 0
                    elseif level == 2 then mapped = tonumber(itemMappingCfg.SkinItemIDLv2) or 0
                    else mapped = tonumber(itemMappingCfg.SkinItemIDLv3) or 0 end
                end
                if mapped <= 0 and DataMgr and DataMgr.GetEquipmentItemIDByResID then
                    mapped = tonumber(DataMgr.GetEquipmentItemIDByResID(level, catalogRes)) or 0
                end
            end)
            if mapped > 0 then return mapped end
            if isInjectedRes(catalogRes) then return catalogRes end
            return 0
        end

        local function buildEquipSkinLists(resID)
            resID = normalizeEquipCatalogRes(resID)
            return {
                mapEquipSkinRes(resID, 1),
                mapEquipSkinRes(resID, 2),
                mapEquipSkinRes(resID, 3),
            }
        end

        local function ensureMatchEquipCache()
            local cch = cache()
            local eq = MATCH_CONFIG.equip or {}
            if (not cch.equip.bag or cch.equip.bag <= 0) and eq.bag and eq.bag > 0 then
                cch.equip.bag = eq.bag
            end
            if (not cch.equip.helmet or cch.equip.helmet <= 0) and eq.helmet and eq.helmet > 0 then
                cch.equip.helmet = eq.helmet
            end
            if (not cch.equip.armor or cch.equip.armor <= 0) and eq.armor and eq.armor > 0 then
                cch.equip.armor = eq.armor
            end
            if (not cch.equip.parachute or cch.equip.parachute <= 0) and eq.parachute and eq.parachute > 0 then
                cch.equip.parachute = eq.parachute
            end
            if (not cch.equip.glider or cch.equip.glider <= 0) and eq.glider and eq.glider > 0 then
                cch.equip.glider = eq.glider
            end
        end

        local function syncMatchConfigFromCache()
            local cch = cache()
            if cch.outfitRes and cch.outfitRes > 0 then
                MATCH_CONFIG.outfitRes = cch.outfitRes
            else
                MATCH_CONFIG.outfitRes = 0
            end
            MATCH_CONFIG.weaponSkins = MATCH_CONFIG.weaponSkins or {}
            for wid, w in pairs(cch.weapons or {}) do
                if w.resID and w.resID > 0 then
                    MATCH_CONFIG.weaponSkins[wid] = w.resID
                end
            end
            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
            for _, slot in ipairs({ "bag", "helmet", "armor", "parachute", "glider" }) do
                if cch.equip[slot] and cch.equip[slot] > 0 then
                    MATCH_CONFIG.equip[slot] = cch.equip[slot]
                end
            end
        end

        local function restorePersistedVehicles()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if _G._savedVehicleSlotList and DataMgr then
                    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                    for subType, insList in pairs(_G._savedVehicleSlotList) do
                        if insList and #insList > 0 then
                            DataMgr.VehicleSlotList[subType] = insList
                        end
                    end
                end
            end)
            pcall(function()
                if _G._savedGarageVehicles then
                    local GTS = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                    if GTS then
                        GTS.GarageVehicleInfo = GTS.GarageVehicleInfo or {}
                        for slot, info in pairs(_G._savedGarageVehicles) do
                            if info and info.inst_id then
                                GTS.GarageVehicleInfo[slot] = info
                            end
                        end
                    end
                end
            end)
        end

        local function restorePersistedMotions()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if not _G._savedMotionList or #_G._savedMotionList == 0 then return end
                if not DataMgr then return end
                DataMgr.MotionSlotList = {}
                for i, ins in ipairs(_G._savedMotionList) do
                    DataMgr.MotionSlotList[i] = ins
                end
                if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                    EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                end
            end)
        end

        local function restorePersistedEquipIns()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if not DataMgr then return end
                if _G._savedEquipIns then
                    DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
                    for subType, ins in pairs(_G._savedEquipIns) do
                        if ins and ins > 0 then
                            DataMgr.equipmentSkinInsIDTable[subType] = ins
                        end
                    end
                end
                if _G._savedVstSkin and _G._savedVstSkin > 0 then
                    DataMgr.vst_skin = _G._savedVstSkin
                end
            end)
        end

        local function restorePersistedThrowObjects()
            if not _G._addOutfitPersistLoaded then return end
            pcall(function()
                if not _G._savedThrowObjects then return end
                local cch = cache()
                cch.throwObjects = cch.throwObjects or {}
                for st, info in pairs(_G._savedThrowObjects) do
                    if info.resID and info.resID > 0 then
                        cch.throwObjects[st] = info
                    end
                end
            end)
        end

        local GAME_HELMET_LEVEL = {
            [502001] = 1, [502004] = 1,
            [502002] = 2, [502005] = 2,
            [502003] = 3,
        }
        local GAME_BAG_LEVEL = {
            [501001] = 1, [501004] = 1,
            [501002] = 2, [501005] = 2,
            [501003] = 3,
        }

        local function detectEquipLevelFromBaseId(baseId, catalogResID)
            baseId, catalogResID = tonumber(baseId), tonumber(catalogResID)
            if not baseId or baseId <= 0 then return nil end
            local level
            pcall(function()
                catalogResID = catalogResID and normalizeEquipCatalogRes(catalogResID) or catalogResID
                if catalogResID then
                    local set = getEquipLevelSet(catalogResID)
                    if set then
                        if baseId == set.lv1 then level = 1
                        elseif baseId == set.lv2 then level = 2
                        elseif baseId == set.lv3 then level = 3 end
                    end
                    if not level then
                        local m = CDataTable.GetTableData("BackpackMapping", catalogResID)
                        if m then
                            if tonumber(m.SkinItemIDLv1) == baseId then level = 1
                            elseif tonumber(m.SkinItemIDLv2) == baseId then level = 2
                            elseif tonumber(m.SkinItemIDLv3) == baseId then level = 3 end
                        end
                    end
                end
                if not level then
                    local patLevel, patCatalog = detectLevelFromPattern(baseId)
                    if patLevel and (not catalogResID or patCatalog == catalogResID) then
                        level = patLevel
                    end
                end
                if not level then level = GAME_HELMET_LEVEL[baseId] or GAME_BAG_LEVEL[baseId] end
                if not level and baseId >= 1505000001 and baseId <= 1505000003 then
                    level = baseId - 1505000000
                end
                if not level then
                    pcall(function()
                        local BU = require("GameLua.Mod.BaseMod.GamePlay.Backpack.BackpackUtils")
                        if BU.GetEquipmentHelmetLevel then
                            local hl = BU.GetEquipmentHelmetLevel(baseId)
                            if hl and hl >= 1 and hl <= 3 then level = hl end
                        end
                        if not level and BU.GetEquipmentBagLevel then
                            local bl = BU.GetEquipmentBagLevel(baseId)
                            if bl and bl >= 1 and bl <= 3 then level = bl end
                        end
                    end)
                end
            end)
            return level
        end

        local function isBaseEquipItemId(itemId)
            itemId = tonumber(itemId)
            if not itemId or itemId <= 0 then return false end
            if GAME_HELMET_LEVEL[itemId] or GAME_BAG_LEVEL[itemId] then return true end
            if itemId >= 1505000001 and itemId <= 1505000100 then return true end
            if itemId >= 1501000000 and itemId < 1502000000 then return true end
            if itemId >= 502001 and itemId <= 502999 then return true end
            if itemId >= 501001 and itemId <= 501999 then return true end
            return false
        end

        local function resolveMatchEquipSkin(catalogResID, baseItemID)
            catalogResID = normalizeEquipCatalogRes(catalogResID)
            if not catalogResID or catalogResID <= 0 then return 0 end
            local level = detectEquipLevelFromBaseId(baseItemID, catalogResID) or 3
            return mapEquipSkinRes(catalogResID, level)
        end

        local function getEquipDisplayLevel(resID, slot)
            local wornLevel = detectLevelFromEquipRes(resID)
            if wornLevel then return wornLevel end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                if slot == "bag" then wornLevel = fbd:GetBagLevel() or 3
                elseif slot == "helmet" then wornLevel = fbd:GetHelmetLevel() or 3 end
            end)
            return wornLevel or 3
        end

        local function syncEquipLevelFromRes(resID, slot)
            local level = detectLevelFromEquipRes(resID)
            if not level then return end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                if slot == "helmet" then
                    fbd:SetHelmetLevel(level)
                elseif slot == "bag" then
                    fbd:SetBagLevel(level)
                end
            end)
        end

        local function saveEquipSkin(resID, insID)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID then return end
            local slot = getEquipSkinSlot(resID)
            if not slot then return end
            local cch = cache()
            cch.equip[slot] = resID
            if insID then cch.equip[slot .. "Ins"] = insID end
            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
            MATCH_CONFIG.equip[slot] = resID
            _S.matchApplied = false
            invalidateSocialWearCache()
            log("ذاكرة معدات", slot, resID)
            pcall(_AutoSaveOutfit)
        end

        local function saveClothPiece(resID)
            resID = tonumber(resID)
            if not resID then return end
            local cch = cache()
            cch.clothes[resID] = true
            _S.matchApplied = false
            invalidateSocialWearCache()
            pcall(_AutoSaveOutfit)
        end

        local function clearClothesForKind(kind)
            local clearMap = subTypesToClearForKind(kind)
            if not clearMap then return end
            local cch = cache()
            for resID in pairs(cch.clothes) do
                local st = subType(cfg(resID))
                if st and clearMap[st] then cch.clothes[resID] = nil end
            end
            if kind == "full_suit" then
                cch.outfitRes, cch.outfitIns = nil, nil
            end
        end

        local function saveWeaponToCache(weaponID, resID, insID)
            weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
            if not weaponID or not resID or resID <= 0 then return end
            local cch = cache()
            cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
            _G.AddOutfitLastAppliedSkin = {}
            _S.matchApplied = false
            invalidateSocialWearCache()
            log("ذاكرة سكن", weaponID, "→", resID)
            pcall(_AutoSaveOutfit)
        end

        local function cacheWeaponSkinFromIns(weaponID, insID)
            weaponID, insID = tonumber(weaponID), tonumber(insID)
            if not weaponID or not insID or insID <= 0 then return end
            if isInjectedIns(insID) then
                saveWeaponToCache(weaponID, R.insToRes[insID], insID)
                return
            end
            pcall(function()
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
                if d and d.resID and tonumber(d.resID) > 0 then
                    saveWeaponToCache(weaponID, tonumber(d.resID), insID)
                end
            end)
        end

        local function saveEquip(resID, insID)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID or not insID then return end
            local c = cfg(resID)
            local st = subType(c)
            local kind = getClothKind(resID)
            local cch = cache()
            if kind == "full_suit" then
                clearClothesForKind("full_suit")
                cch.outfitRes, cch.outfitIns = resID, insID
                _G.AddOutfitLastLobbyOutfitRes = resID
                invalidateSocialWearCache()
            elseif kind then
                if cch.outfitRes and isFullSuitRes(cch.outfitRes) then
                    cch.outfitRes, cch.outfitIns = nil, nil
                    _G.AddOutfitLastLobbyOutfitRes = nil
                end
                clearClothesForKind(kind)
                saveClothPiece(resID)
            elseif getEquipSkinSlot(resID) then
                saveEquipSkin(resID, insID)
            elseif _K.GUN_SUB[st] then
                local wid = weaponIdFromSkin(resID)
                if not wid then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        wid = wgl.GetCurGunID and wgl:GetCurGunID() or nil
                        if not wid and wgl.GetCurrentGunID then
                            wid = wgl:GetCurrentGunID()
                        end
                    end)
                end
                if wid then saveWeaponToCache(wid, resID, insID) end
            elseif st == _K.MELEE_ID then
                saveWeaponToCache(_K.MELEE_ID, resID, insID)
            elseif isThrowObjectRes(resID) then
                saveThrowObject(resID, insID)
            elseif isInjectedRes(resID) then
                local mt = wardrobeMainTab(resID)
                if mt ~= _K.WARDROBE_PAGE_VEHICLE then
                    saveClothPiece(resID)
                end
            end
            _S.matchApplied = false
            pcall(_AutoSaveOutfit)
        end

        local _lastSyncWeaponCache = 0
        local function syncWeaponCacheFromLobby()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastSyncWeaponCache) < 0.3 then return end  -- throttle: max ~3x per second
            _lastSyncWeaponCache = now
            local cch = cache()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if bag then
                    if bag.bag_skin and tonumber(bag.bag_skin) > 0 then
                        local rid = isInjectedIns(bag.bag_skin) and R.insToRes[bag.bag_skin]
                            or (function()
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(bag.bag_skin)
                                return d and tonumber(d.resID)
                            end)()
                        if rid and isInjectedRes(rid) then cch.equip.bag = rid end
                    end
                    if bag.helmet_skin and tonumber(bag.helmet_skin) > 0 then
                        local rid = isInjectedIns(bag.helmet_skin) and R.insToRes[bag.helmet_skin]
                            or (function()
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(bag.helmet_skin)
                                return d and tonumber(d.resID)
                            end)()
                        if rid and isInjectedRes(rid) then cch.equip.helmet = rid end
                    end
                    if bag.weapon_skin_list then
                        for weaponID, entry in pairs(bag.weapon_skin_list) do
                            cacheWeaponSkinFromIns(weaponID, entry and (entry.skin_id or entry.skinId))
                        end
                    end
                end
            end)
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                if Arm.rsp_list and Arm.rsp_list.install_list then
                    for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                        cacheWeaponSkinFromIns(weaponID, entry and entry.skin_id)
                    end
                end
            end)
            pcall(function()
                if DataMgr and DataMgr.equipmentSkinInsIDTable then
                    local function ridFromIns(ins)
                        ins = tonumber(ins)
                        if not ins or ins <= 0 then return nil end
                        if isInjectedIns(ins) then return R.insToRes[ins] end
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetHallDepotItemDataByInsID(ins)
                        return d and tonumber(d.resID)
                    end
                    local bagRid = ridFromIns(DataMgr.equipmentSkinInsIDTable[504])
                    if bagRid and isInjectedRes(bagRid) then cch.equip.bag = bagRid end
                    local helmRid = ridFromIns(DataMgr.equipmentSkinInsIDTable[505])
                    if helmRid and isInjectedRes(helmRid) then cch.equip.helmet = helmRid end
                    local armorRid = ridFromIns(DataMgr.equipmentSkinInsIDTable[506])
                    if armorRid and isInjectedRes(armorRid) then cch.equip.armor = armorRid end
                end
            end)
        end

        local _lastSyncClothesCache = 0
        local function syncClothesCacheFromLobby()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastSyncClothesCache) < 0.3 then return end  -- throttle: max ~3x per second
            _lastSyncClothesCache = now
            local cch = cache()
            pcall(function()
                local inLobby = false
                if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
                    inLobby = true
                end
                
                if inLobby and not _G._addOutfitPersistLoaded then
                    cch.outfitRes = nil
                    cch.outfitIns = nil
                    _G.AddOutfitLastLobbyOutfitRes = nil
                    cch.clothes = {}
                end

                local AvatarData = require("client.logic.data.AvatarData")
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and ins > 0 then
                        local resID = isInjectedIns(ins) and R.insToRes[ins]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(ins)
                                return d and tonumber(d.resID)
                            end)()
                        if resID and isInjectedRes(resID) then
                            if isFullSuitRes(resID) then
                                cch.outfitRes, cch.outfitIns = resID, ins
                                _G.AddOutfitLastLobbyOutfitRes = resID
                            elseif not getEquipSkinSlot(resID) and not weaponIdFromSkin(resID) then
-- @RAHMANYVI
                                cch.clothes[resID] = true
                            elseif getEquipSkinSlot(resID) then
                                local slot = getEquipSkinSlot(resID)
                                cch.equip[slot] = resID
                                cch.equip[slot .. "Ins"] = ins
                            end
                        end
                    end
                end

-- @RAHMANYVI
                pcall(function()
                    local fashionbag_data = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local paraInsID = tonumber(fashionbag_data:GetParachute())
                    if paraInsID and paraInsID > 0 then
                        local paraResID
                        if isInjectedIns(paraInsID) then
                            paraResID = R.insToRes[paraInsID]
                        else
                            local d = wd:GetHallDepotItemDataByInsID(paraInsID)
                            paraResID = d and tonumber(d.resID)
                        end
                        if paraResID and paraResID > 0 then
                            cch.equip.parachute = paraResID
                            cch.equip.parachuteIns = paraInsID
                            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
                            MATCH_CONFIG.equip.parachute = paraResID
                        end
                    end
                end)

-- @RAHMANYVI
                pcall(function()
                    local fashionbag_data = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local gliderInsID = tonumber(fashionbag_data:GetAircraftOrGliding())
                    if gliderInsID and gliderInsID > 0 then
                        local gliderResID
                        if isInjectedIns(gliderInsID) then
                            gliderResID = R.insToRes[gliderInsID]
                        else
                            local d = wd:GetHallDepotItemDataByInsID(gliderInsID)
                            gliderResID = d and tonumber(d.resID)
                        end
                        if gliderResID and gliderResID > 0 then
                            cch.equip.glider = gliderResID
                            cch.equip.gliderIns = gliderInsID
                            MATCH_CONFIG.equip = MATCH_CONFIG.equip or {}
                            MATCH_CONFIG.equip.glider = gliderResID
                        end
                    end
                end)
            end)
        end

        local function syncClothesCacheFromLive()
            local cch = cache()
            pcall(function()
                local AvatarData = require("client.logic.data.AvatarData")
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                for _, ins in pairs(AvatarData.GetRoleWear()) do
                    ins = tonumber(ins)
                    if ins and ins > 0 then
                        local resID = isInjectedIns(ins) and R.insToRes[ins]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(ins)
                                return d and tonumber(d.resID)
                            end)()
                        if resID and isInjectedRes(resID) then
                            if isFullSuitRes(resID) then
                                cch.outfitRes, cch.outfitIns = resID, ins
                                _G.AddOutfitLastLobbyOutfitRes = resID
                            elseif not getEquipSkinSlot(resID) and not weaponIdFromSkin(resID) then
                                cch.clothes[resID] = true
                            else
                                local slot = getEquipSkinSlot(resID)
                                if slot then
                                    cch.equip[slot] = resID
                                    cch.equip[slot .. "Ins"] = ins
                                end
                            end
                        end
                    end
                end
                pcall(function()
                    local fashionbag_data = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local paraInsID = tonumber(fashionbag_data:GetParachute())
                    if paraInsID and paraInsID > 0 then
                        local paraResID = isInjectedIns(paraInsID) and R.insToRes[paraInsID]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(paraInsID)
                                return d and tonumber(d.resID)
                            end)()
                        if paraResID and paraResID > 0 then
                            cch.equip.parachute = paraResID
                            cch.equip.parachuteIns = paraInsID
                        end
                    end
                    local gliderInsID = tonumber(fashionbag_data:GetAircraftOrGliding())
                    if gliderInsID and gliderInsID > 0 then
                        local gliderResID = isInjectedIns(gliderInsID) and R.insToRes[gliderInsID]
                            or (function()
                                local d = wd:GetHallDepotItemDataByInsID(gliderInsID)
                                return d and tonumber(d.resID)
                            end)()
                        if gliderResID and gliderResID > 0 then
                            cch.equip.glider = gliderResID
                            cch.equip.gliderIns = gliderInsID
                        end
                    end
                end)
            end)
        end

        local function syncThrowObjectCacheFromLobby()
            local cch = cache()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if not bag or not bag.throw_object_list then return end
                cch.throwObjects = cch.throwObjects or {}
                for subType, insID in pairs(bag.throw_object_list) do
                    insID = tonumber(insID)
                    subType = tonumber(subType)
                    if insID and insID > 0 and subType and _K.THROW_SUB[subType] then
                        local resID
                        if isInjectedIns(insID) then
                            resID = R.insToRes[insID]
                        else
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            resID = d and tonumber(d.resID)
                        end
                        if resID and isInjectedRes(resID) then
                            cch.throwObjects[subType] = { resID = resID, insID = insID }
                        end
                    end
                end
            end)
        end

        local function syncAllCacheFromLive()
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLive()
            syncThrowObjectCacheFromLobby()
            ensureMatchEquipCache()
            syncMatchConfigFromCache()
        end
        _G.AddOutfitSyncCacheBeforeSave = syncAllCacheFromLive

        local function snapshotLobbyWear()
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLobby()
            syncThrowObjectCacheFromLobby()
            ensureMatchEquipCache()
        end

        local function getCachedWeaponSkin(weaponID)
            weaponID = tonumber(weaponID) or 0
            if weaponID <= 0 then return nil end
            syncWeaponCacheFromLobby()
            local w = cache().weapons[weaponID]
            if w and w.resID and w.resID > 0 then return w.resID end
            return nil
        end

        local function getMatchWeaponSkin(weaponID)
            weaponID = tonumber(weaponID) or 0
            local fromCache = getCachedWeaponSkin(weaponID)
            if fromCache then return fromCache end
            if MATCH_CONFIG.weaponSkins then
                local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
                if fixed and fixed > 0 then return fixed end
            end
            return nil
        end

        local _ticker
        pcall(function() _ticker = require("common.time_ticker") end)
        local function later(sec, fn)
            if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
            if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
        end

        local function getEntity()
            local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
            if not ok or not dc then return nil end
            local ok2, e = pcall(dc.GetWardrobeData, EWardrobeDataSource and EWardrobeDataSource.Wardrobe or nil)
            if ok2 and e then return e end
            ok2, e = pcall(dc.GetWardrobeData)
            return ok2 and e or nil
        end

        local function alreadyHave(entity, resID)
            local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
            if not arr then return false end
            for _, idx in pairs(arr) do
                local d = entity._data[idx]
                if d and d.count and d.count > 0 then return true end
            end
            return false
        end

        local function ensureDepotTabFields(entity, data, resID)
            if not data then return end
            pcall(function()
                if entity and entity.LoadConfigForData and CDataTable.GetTableData then
                    entity:LoadConfigForData(data, CDataTable.GetTableData)
                end
            end)
            local equipSlot = getEquipSkinSlot(resID)
            if equipSlot == "bag" then
                data.mainTabType = _K.WARDROBE_PAGE_AVATAR
                data.subTabType = _K.WARDROBE_TAB_BAG
            elseif equipSlot == "helmet" then
                data.mainTabType = _K.WARDROBE_PAGE_AVATAR
                data.subTabType = _K.WARDROBE_TAB_HELMET
            elseif equipSlot == "armor" then
                data.mainTabType = _K.WARDROBE_PAGE_AVATAR
                data.subTabType = _K.WARDROBE_TAB_ARMOR
            end
            local c = cfg(resID)
            if c then data.itemSubType = tonumber(c.ItemSubType or c.itemSubType) or data.itemSubType end
            if c then
                local wmTab = tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0
                if wmTab == _K.WARDROBE_PAGE_VEHICLE then
                    data.mainTabType = _K.WARDROBE_PAGE_VEHICLE
                    data.subTabType = tonumber(c.WardrobeTab or c.wardrobeTab) or data.subTabType
                end
            end
        end

        local function depotResID(v)
            return v and tonumber(v.resID or v.res_id) or nil
        end

        local function injectedEquipAllowed(resID, mainTab, subTab)
            local slot = getEquipSkinSlot(resID)
            if slot == "bag" then
                return mainTab == _K.WARDROBE_PAGE_AVATAR and subTab == _K.WARDROBE_TAB_BAG
            end
            if slot == "helmet" then
                return mainTab == _K.WARDROBE_PAGE_AVATAR and subTab == _K.WARDROBE_TAB_HELMET
            end
            if slot == "armor" then
                return mainTab == _K.WARDROBE_PAGE_AVATAR and subTab == _K.WARDROBE_TAB_ARMOR
            end
            if slot == "parachute" then
                return mainTab == _K.WARDROBE_PAGE_PARACHUTE and subTab == _K.WARDROBE_TAB_PARACHUTE
            end
            if slot == "glider" then
                return mainTab == _K.WARDROBE_PAGE_PARACHUTE and subTab == _K.WARDROBE_TAB_GLIDER
            end
            return nil
        end

        local function injectOne(entity, resID, insID)
            if alreadyHave(entity, resID) then
                R.resToIns[resID] = R.resToIns[resID] or insID
                R.insToRes[insID] = resID
                pcall(function()
                    local data = entity.GetDataByInsID and entity:GetDataByInsID(R.resToIns[resID])
                    if data then ensureDepotTabFields(entity, data, resID) end
                end)
                return true
            end
            entity:AddData({
                instid = insID, res_id = resID, count = 1,
                lock_cnt = 0, isnew = 0, valid_hours = 0, expire_ts = 0,
            })
            pcall(function()
                local data = entity.GetDataByInsID and entity:GetDataByInsID(insID)
                if data then
                    ensureDepotTabFields(entity, data, resID)
                end
            end)
            R.insToRes[insID] = resID
            R.resToIns[resID] = insID
-- @RAHMANYVI
            return true
        end

        local function injectArmory(resID, insID)
            local wid = weaponIdFromSkin(resID)
            if not wid then return end
            local Arm = require("client.logic.armory.logic_armory")
            Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
            Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
            if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
            Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
            Arm.WardrobeInsList = Arm.WardrobeInsList or {}
            Arm.WardrobeInsList[resID] = insID
        end

-- @RAHMANYVI
        local function injectAll(entity)
            if _S.injectedDone then return true end
            refreshItems()
            entity = entity or getEntity()
            if not entity or not entity.bInit then return false end

            if next(_C.fullSuit) == nil then
                pcall(function()
                    for _, rid in ipairs(ITEMS) do
                        local c = cfg(rid)
                        if c then
                            local st = tonumber(c.ItemSubType or c.itemSubType) or 0
                            if st == _K.ST_TOP then
                                local tab = tonumber(c.WardrobeTab or c.wardrobeTab) or 0
                                if tab == _K.WARDROBE_TAB_SUIT then
                                    _C.fullSuit[rid] = true
                                else
                                    pcall(function()
                                        local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
                                        if LogicXSuit.IsXSuit(rid) then _C.fullSuit[rid] = true end
                                    end)
                                end
                            end
                            local wmTab = tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0
                            if wmTab == _K.WARDROBE_PAGE_VEHICLE then
                                _C.vehicleItems[#_C.vehicleItems + 1] = rid
                            end
                        end
                        getEquipSkinSlot(rid)
                        weaponIdFromSkin(rid)
                    end
                    for _, rid in ipairs(ITEMS) do
                        getInjectedItemTab(rid)
                    end
                    local allTabs = {
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SUIT},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_CLOTHES},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_TROUSERS},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_SHOES},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_BAG},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_HELMET},
                        {_K.WARDROBE_PAGE_AVATAR, _K.WARDROBE_TAB_ARMOR},
                        {_K.WARDROBE_PAGE_WEAPON, _K.WARDROBE_TAB_GUN},
                        {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_PARACHUTE},
                        {_K.WARDROBE_PAGE_PARACHUTE, _K.WARDROBE_TAB_GLIDER},
                        {_K.WARDROBE_PAGE_VEHICLE, 0},
                    }
                    -- pageMatch is now computed lazily in IsValidCurrentPageItem
                    for k in pairs(_C.pageMatch) do _C.pageMatch[k] = nil end
                end)
            end

            local n = 0
            for i, resID in ipairs(ITEMS) do
                local insID = _K.INS_BASE + i
                if injectOne(entity, resID, insID) then
                    n = n + 1
                    local c = cfg(resID)
                    if _K.GUN_SUB[subType(c)] or subType(c) == _K.MELEE_ID then
                        injectArmory(resID, insID)
                    end
                end
            end
            if n > 0 then
                _S.injectedDone = true
                _G.AddOutfit_R = R
                log("حقن", n, "items")
            end
            return n > 0
        end

        local function injectAllSources()
            return injectAll(getEntity())
        end

        local function refreshWardrobe()
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

        local function findWornInsBySubType(st)
            st = tonumber(st)
            if not st then return nil end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local AvatarData = require("client.logic.data.AvatarData")
            for _, ins in pairs(AvatarData.GetRoleWear()) do
                ins = tonumber(ins)
                if ins and ins > 0 then
                    local d = wd:GetHallDepotItemDataByInsID(ins)
                    if d and tonumber(d.itemSubType) == st then
                        return ins, d.resID
                    end
                end
            end
            return nil
        end

        local function removeRoleWearBySubTypes(stMap)
            if not stMap then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local AvatarData = require("client.logic.data.AvatarData")
            for _, ins in pairs(AvatarData.GetRoleWear()) do
                ins = tonumber(ins)
                if ins and ins > 0 then
                    local d = wd:GetHallDepotItemDataByInsID(ins)
                    if d and stMap[tonumber(d.itemSubType)] then
                        AvatarData.RemoveRoleWearDataByValue(ins)
                    end
                end
            end
        end

        local function clearFashionBagSlots(stMap)
            if not stMap then return end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if not bag or not bag.rolewear_list then return end
                for st, _ in pairs(stMap) do
                    local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
                    if idx then bag.rolewear_list[idx] = 0 end
                end
            end)
        end

        local function syncFashionBagRolewear()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
            end)
        end

        local function ensureKnapsackExtInfo()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local idx = fbd:GetFashionBagUseIndex()
                if not fbd:GetKnapsackExtInfoByIndex(idx) then
                    fbd:SetKnapsackExtInfoByIndex(idx, {})
                end
            end)
        end

        local function getEquipSubType(resID, slot)
            local c = cfg(resID)
            if c then
                local st = tonumber(c.ItemSubType or c.itemSubType)
                if st then return st end
            end
            if slot == "bag" then return ENUM_ITEM_SUBTYPE.Backpack end
            if slot == "helmet" then return ENUM_ITEM_SUBTYPE.Helmet_NoLevel end
            return nil
        end

        local function softRemoveEquipVisual(oldResID, slot)
            oldResID = normalizeEquipCatalogRes(oldResID)
            if not oldResID or oldResID <= 0 or not slot then return end
            pcall(function()
                local TAM = require("client.logic.avatar.logic_team_avatar_manager")
                local AvatarData = require("client.logic.data.AvatarData")
                for lvl = 1, 3 do
                    local displayRes = mapEquipSkinRes(oldResID, lvl)
                    if displayRes > 0 then
                        TAM.ChangeAvatarEquipment(tostring(DataMgr.roleData.uid),
                            AvatarData.CreateAvatarCustom(displayRes), false)
                    end
                end
            end)
        end

        local function applyEquipVisual(resID, insID, slot)
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local HT = require("client.logic.lobby.hall_theme_utils")
                local TAM = require("client.logic.avatar.logic_team_avatar_manager")
                local AvatarData = require("client.logic.data.AvatarData")
                local lds = require("client.slua.logic.wardrobe.logic_display_setting")
                local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                syncEquipLevelFromRes(resID, slot)
                local level = getEquipDisplayLevel(resID, slot)
                local catalogRes = normalizeEquipCatalogRes(resID)
                local itemSt = getEquipSubType(catalogRes, slot)
                if itemSt then lav:AddToWearInfo(itemSt, insID, catalogRes, 0, 0) end
                lav:AvatarChange(catalogRes, true)
                local displayRes = mapEquipSkinRes(catalogRes, level)
                if displayRes > 0 then
                    TAM.ChangeAvatarEquipment(tostring(DataMgr.roleData.uid),
                        AvatarData.CreateAvatarCustom(displayRes), true)
                end
                if lds.data then
                    if slot == "bag" then lds.data.OpenBag = true end
                    if slot == "helmet" then lds.data.OpenHelmet = true end
                end
                if slot == "helmet" then
                    fbd:SetHeadShow(insID)
                    local WRH = require("client.network.Protocol.WardRobeHandler")
                    WRH.send_depot_set_head_show_req(insID)
                end
                if slot == "bag" then HT.PutOnBag(fbd:GetFashionBagUseIndex()) end
            end)
        end

        -- ========== دوال الخلع المُحسَّنة ==========
        local takeOffEquipSkinVisual, takeOffClothVisual, takeOffWeaponSkinVisual

        local function takeOffItem(insID)
            insID = tonumber(insID)
            if not insID or insID <= 0 then return false end
            local resID = R.insToRes[insID]
            if not resID then return false end

            local cch = cache()
            local kind = getClothKind(resID)
            local slot = getEquipSkinSlot(resID)
            local wid  = weaponIdFromSkin(resID)
            local handled = false

            if slot then
                local oldRes = cch.equip[slot] or resID
                takeOffEquipSkinVisual(slot, oldRes, insID)
                cch.equip[slot]          = nil
                cch.equip[slot .. "Ins"] = nil
                if MATCH_CONFIG.equip then MATCH_CONFIG.equip[slot] = 0 end
                handled = true
            elseif kind then
                takeOffClothVisual(resID, insID, kind)
                if kind == "full_suit" then
                    cch.outfitRes, cch.outfitIns = nil, nil
                    _G.AddOutfitLastLobbyOutfitRes = nil
                else
                    cch.clothes[resID] = nil
                end
                handled = true
            elseif wid then
                takeOffWeaponSkinVisual(wid, resID, insID)
                cch.weapons[wid] = nil
                _G.AddOutfitLastAppliedSkin = {}
                _S.weaponApplied = false
                _S.weaponDiagDone = false
                _S.lastAppliedWeaponID = 0
                _S.lastAppliedSkinID = 0
                buildSkinMappings()
                handled = true
            elseif isHallThemeRes(resID) then
                pcall(function()
                    local HT = require("client.logic.lobby.hall_theme_utils")
                    HT.homeThemeItemId = 0
                    HT.SetThemeInstId(0)
                    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                    local idx = fbd:GetFashionBagUseIndex()
                    local bag = fbd:GetCurrentFashionBag()
                    if bag and bag.avatar_show then
                        bag.avatar_show[HT.knapsack_ext_background] = nil
                    end
                end)
                handled = true
            end

            if not handled then return false end

            _S.matchApplied = false
            _S.matchOutfitDone = false
            invalidateSocialWearCache()
            pcall(_AutoSaveOutfit)
            return true
        end

        takeOffEquipSkinVisual = function(slot, resID, insID)
            if not slot then return end
            resID, insID = tonumber(resID), tonumber(insID)
            if _S.equipSkinApplying then return end
            _S.equipSkinApplying = true
            pcall(function()
                if resID and resID > 0 then softRemoveEquipVisual(resID, slot) end
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local lds = require("client.slua.logic.wardrobe.logic_display_setting")
                local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                local HT = require("client.logic.lobby.hall_theme_utils")
                local itemSt = resID and getEquipSubType(resID, slot)
                if itemSt and insID and insID > 0 then
                    pcall(function() lav:SetCurrentWearPreview(itemSt, nil) end)
                end
                if slot == "bag" then
                    fbd:SetBagSkin(0)
                    if lds.data then lds.data.OpenBag = false end
                    HT.PutOnBag(fbd:GetFashionBagUseIndex())
                elseif slot == "helmet" then
                    fbd:SetHelmetSkin(0)
                    if lds.data then lds.data.OpenHelmet = false end
                    fbd:SetHeadShow(0)
                elseif slot == "armor" then
                    pcall(function()
                        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                        wl:on_putdown_rsp(_K.NET_OK, { res_id = resID or 0, instid = insID or 0, count = 1 }, nil)
                    end)
                end
                if DataMgr and DataMgr.equipmentSkinInsIDTable then
                    local subKey = (slot == "bag") and 504 or (slot == "helmet") and 505 or (slot == "armor") and 506
                    if subKey then DataMgr.equipmentSkinInsIDTable[subKey] = 0 end
                end
                syncFashionBagRolewear()
            end)
            _S.equipSkinApplying = false
        end

        takeOffClothVisual = function(resID, insID, kind)
            resID, insID = tonumber(resID), tonumber(insID)
            if not resID or not insID then return end
            kind = kind or getClothKind(resID)
            local clearMap = subTypesToClearForKind(kind)
            if not clearMap then return end
            pcall(function()
                removeRoleWearBySubTypes(clearMap)
                clearFashionBagSlots(clearMap)
                local WRH = require("client.network.Protocol.WardRobeHandler")
                WRH.on_depot_put_down_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, nil)
                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                local TAM = require("client.logic.avatar.logic_team_avatar_manager")
                local AvatarData = require("client.logic.data.AvatarData")
                local uid = tostring(DataMgr.roleData.uid)
                local itemSt = subType(cfg(resID)) or _K.ST_TOP
                if kind == "full_suit" then
                    itemSt = _K.ST_TOP
                    for st in pairs(clearMap) do
                        local oIns, oRes = findWornInsBySubType(st)
                        if oIns and oRes and oRes > 0 then
                            TAM.ChangeAvatarEquipment(uid, AvatarData.CreateAvatarCustom(oRes), false)
                        end
                    end
                end
                TAM.ChangeAvatarEquipment(uid, AvatarData.CreateAvatarCustom(resID), false)
                pcall(function() AvatarData.RemoveRoleWearDataByValue(insID) end)
                pcall(function() av:SetCurrentWearPreview(itemSt, nil) end)
                later(0.05, function()
                    pcall(function() av:ProcessTakeOff() end)
                    syncFashionBagRolewear()
                    pcall(function()
                        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                        wl:on_putdown_rsp(_K.NET_OK, { res_id = resID, instid = insID, count = 1 }, nil)
                    end)
                    if av.InitCurrentWearPreviewMap then av:InitCurrentWearPreviewMap(true) end
                end)
            end)
        end

        takeOffWeaponSkinVisual = function(weaponID, resID, insID)
            weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
            if not weaponID then return end
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                local HT = require("client.logic.lobby.hall_theme_utils")
                local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                -- مسح من install_list
                if Arm.rsp_list and Arm.rsp_list.install_list then
                    Arm.rsp_list.install_list[weaponID] = nil
                end
                -- مسح من FashionBag
                if fbd.UpdateCurrentFashionBagWeaponSkin then
                    fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, 0)
                end
                local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                if bag and bag.weapon_skin_list then
                    bag.weapon_skin_list[weaponID] = nil
                end
                -- تحديث واجهة السلاح
                local bagIdx = fbd:GetFashionBagUseIndex()
                HT.proc_skin_list_chg("weapon_skin", weaponID, 0, bagIdx, {})
                wgl:SetGunID(weaponID)
                if wgl.UpdateCurrentGunAvatar then
                    wgl:UpdateCurrentGunAvatar(weaponID, 0)
                end
                -- أحداث التحديث
                if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, 0)
                end
                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, 0)
                end
                if EventSystem and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, weaponID)
                end
                log("خلع سكن سلاح", weaponID)
            end)
        end
-- @RAHMANYVI

        local function putOnThrowObject(insID)
            insID = tonumber(insID)
            if not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            if not resID then return end
            local st = isThrowObjectRes(resID)
            if not st then return end
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:PutOnThrowObjectSkin(insID)
            end)
            saveThrowObject(resID, insID)
            pcall(_AutoSaveOutfit)
            log("لبس قنبلة", st, resID)
        end

        local function putOnEquipSkin(insID)
            insID = tonumber(insID)
            local resID = R.insToRes[insID]
            if not resID then return end
            local slot = getEquipSkinSlot(resID)
            if not slot then return end
            if _S.equipSkinApplying then return end
            _S.equipSkinApplying = true
            pcall(function()
                local cch = cache()
                local oldResID = cch.equip[slot]
                local oldInsID = cch.equip[slot .. "Ins"]
                ensureKnapsackExtInfo()
                local item = { res_id = resID, instid = insID, count = 1, color = 0, pattern = 0 }
                local oldItem = nil
                if oldInsID and oldInsID > 0 and oldResID and oldResID > 0 then
                    oldItem = { res_id = oldResID, instid = oldInsID, count = 1, color = 0, pattern = 0 }
                end
                local HT = require("client.logic.lobby.hall_theme_utils")
                if slot == "helmet" then
                    HT.ProcPutOnHelmet(item, oldItem)
                elseif slot == "bag" then
                    HT.ProcPutOnBagSkin(item, oldItem)
                elseif slot == "parachute" then
            -- @RAHMANYVI
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                    local origAddToWearInfo = lav.AddToWearInfo
                    lav.AddToWearInfo = function(self2, subType, ...)
                        if tonumber(subType) == 701 then return end
                        return origAddToWearInfo(self2, subType, ...)
                    end
                    pcall(function()
                        wl:on_puton_rsp(_K.NET_OK, item, oldItem, 1, insID, 0)
                    end)
                    lav.AddToWearInfo = origAddToWearInfo
                elseif slot == "glider" then
-- @RAHMANYVI
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                    local origAddToWearInfo = lav.AddToWearInfo
                    lav.AddToWearInfo = function(self2, subType, ...)
                        local st = tonumber(subType)
                        if st == 413 or st == 414 or st == 415 then return end
                        return origAddToWearInfo(self2, subType, ...)
                    end
                    pcall(function()
                        wl:on_puton_rsp(_K.NET_OK, item, oldItem, 1, insID, 0)
                    end)
                    lav.AddToWearInfo = origAddToWearInfo
                else
                    local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                    wl:on_puton_rsp(_K.NET_OK, item, oldItem, 1, insID, 0)
                end
                saveEquipSkin(resID, insID)
                if oldResID and oldResID > 0 and oldResID ~= resID then
                    softRemoveEquipVisual(oldResID, slot)
                end
-- @RAHMANYVI
                if slot ~= "parachute" and slot ~= "glider" then
                    applyEquipVisual(resID, insID, slot)
                end
                invalidateSocialWearCache()
                log("لبس معدات", slot, resID)
            end)
            _S.equipSkinApplying = false
        end

        local function putOnCloth(insID)
            insID = tonumber(insID)
            local resID = R.insToRes[insID]
            if not resID then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if not d then return end

            local kind = getClothKind(resID, d)
            if not kind then return end

            local cch = cache()
            local switchingFromSuit = (kind ~= "full_suit") and cch.outfitRes and isFullSuitRes(cch.outfitRes)
            local switchingToSuit = (kind == "full_suit") and not cch.outfitRes and next(cch.clothes) ~= nil

            local clearMap
            if switchingFromSuit then
                clearMap = FULL_SUIT_CLEAR_ST
            else
                clearMap = subTypesToClearForKind(kind)
            end
            if not clearMap then return end

            local itemSt = subType(cfg(resID)) or _K.ST_TOP

            local function doPutOn()
                local oldIns, oldRes = findWornInsBySubType(itemSt)
                removeRoleWearBySubTypes(clearMap)
                clearFashionBagSlots(clearMap)
                saveEquip(resID, insID)

                local slot = _K.PKG_SLOT
                pcall(function()
                    local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
                    local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(itemSt)
                    if idx then slot = idx end
                end)

                local olditem
                if oldIns and oldIns ~= insID then
                    olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
                end

                local WRH = require("client.network.Protocol.WardRobeHandler")
                local item = { res_id = resID, count = 1, instid = insID }
                WRH.on_depot_put_on_rsp(_K.NET_OK, item, olditem, slot, insID, oldIns or 0)

                pcall(function()
                    local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                    av:AddToWearInfo(itemSt, insID, resID, 0, 0)
                    local displayResID = resID
                    local LogicXSuit = require("client.slua.logic.XSuit.logic_xsuit")
                    if LogicXSuit.IsXSuit(displayResID) then
                        displayResID = LogicXSuit.GetItemShowID(insID) or displayResID
                    end
                    av:AvatarChange(displayResID, true, 0, 0)
                    later(0.05, function()
                        pcall(function() av:ProcessTakeOff() end)
                        syncFashionBagRolewear()
                    end)
                end)
                log("لبس", kind, resID)
            end

            if switchingFromSuit then
                local suitRes = cch.outfitRes
                local suitIns = cch.outfitIns
                cch.outfitRes, cch.outfitIns = nil, nil
                _G.AddOutfitLastLobbyOutfitRes = nil
                if suitRes and suitIns then
                    pcall(function() takeOffClothVisual(suitRes, suitIns, "full_suit") end)
                    later(0.15, doPutOn)
                else
                    doPutOn()
                end
            elseif switchingToSuit then
                local toTakeOff = {}
                for clothRes in pairs(cch.clothes) do
                    local clothIns = R.resToIns[clothRes]
                    local clothKind = getClothKind(clothRes)
                    if clothIns and clothKind then
                        toTakeOff[#toTakeOff + 1] = { resID = clothRes, insID = clothIns, kind = clothKind }
                    end
                end
                for _, c in ipairs(toTakeOff) do
                    cch.clothes[c.resID] = nil
                    pcall(function() takeOffClothVisual(c.resID, c.insID, c.kind) end)
                end
                later(0.15, doPutOn)
            else
                doPutOn()
            end
        end

        local function equipWeaponSkin(weaponID, insID)
            weaponID, insID = tonumber(weaponID), tonumber(insID)
            if not weaponID or not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            saveEquip(resID, insID)

            local Arm = require("client.logic.armory.logic_armory")
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local HT = require("client.logic.lobby.hall_theme_utils")
            local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

            injectArmory(resID, insID)
            Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
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
            log("weapon skin", weaponID, resID, insID)
        end

        local function putOnHallTheme(insID)
            insID = tonumber(insID)
            if not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            if not resID or not isHallThemeRes(resID) then return end
            local item = { res_id = resID, count = 1, instid = insID }
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                wl:on_puton_rsp(_K.NET_OK, item, nil, 1, insID, 0)
            end)
            pcall(_AutoSaveOutfit)
            log("ثيم لوبي", resID, insID)
        end

        local function restorePersistedHallTheme()
            if not _G._addOutfitPersistLoaded then return end
            local ins = tonumber(_G._savedHallThemeIns)
            if not ins or ins <= 0 then return end
            later(2.5, function()
                if isInjectedIns(ins) then putOnHallTheme(ins) end
            end)
        end

-- @RAHMANYVI
        local SOCIAL = _G.AddOutfitSocialState or {}
        _G.AddOutfitSocialState = SOCIAL
        SOCIAL.debGen = SOCIAL.debGen or 0

        local function socialDebounce(sec, fn)
            SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
            local gen = SOCIAL.debGen
            later(sec, function()
                if gen ~= SOCIAL.debGen then return end
                pcall(fn)
            end)
        end

        local function getLobbyCurPage()
            local p = nil
            pcall(function()
                local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
                if LMC.GetCurPage then p = LMC.GetCurPage() end
            end)
            return p
        end

        local function getWeaponSkinResFast()
            local cch = cache()
            local wid = tonumber(DataMgr.Weapon_ID) or 0
            local w = wid > 0 and cch.weapons[wid] or nil
            if w and w.resID and w.resID > 0 then return w.resID end
            for _, ww in pairs(cch.weapons) do
                if ww.resID and ww.resID > 0 then return ww.resID end
            end
            return nil
        end

        local function resolveLobbyWeaponSkinRes()
            local wid = tonumber(DataMgr.Weapon_ID) or 0
            local skin = getWeaponSkinResFast()
            if skin and skin > 0 then return skin end
            if wid > 0 then
                local fromMatch = getMatchWeaponSkin(wid)
                if fromMatch and fromMatch > 0 then return fromMatch end
            end
            return nil
        end

        local function rememberLobbyOutfitRes(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 or not isFullSuitRes(resID) then return end
            _G.AddOutfitLastLobbyOutfitRes = resID
            local cch = cache()
            if not cch.outfitRes or cch.outfitRes <= 0 then
                cch.outfitRes = resID
                if isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
            end
        end

        local function resolveLobbyOutfitRes()
            local cch = cache()
            if tonumber(cch.outfitRes) and cch.outfitRes > 0 then return cch.outfitRes end
            if tonumber(_G.AddOutfitLastLobbyOutfitRes) and _G.AddOutfitLastLobbyOutfitRes > 0 then
                return tonumber(_G.AddOutfitLastLobbyOutfitRes)
            end
            if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
                return tonumber(MATCH_CONFIG.outfitRes)
            end
            for resID in pairs(cch.clothes) do
                if isFullSuitRes(resID) then return resID end
            end
            return nil
        end

        local function collectAllClothResIDs()
            local ids = {}
            local cch = cache()
            if tonumber(cch.outfitRes) and cch.outfitRes > 0 then
                ids[cch.outfitRes] = true
            end
            for resID in pairs(cch.clothes) do
                if not getEquipSkinSlot(resID) and not weaponIdFromSkin(resID) then
                    ids[resID] = true
                end
            end
            return ids
        end

        local function wearPatchKey()
            local outfit = resolveLobbyOutfitRes() or 0
            local skin = resolveLobbyWeaponSkinRes() or 0
            local cch = cache()
            local eq = (cch.equip.bag or 0) .. "_" .. (cch.equip.helmet or 0)
            return outfit .. "_" .. skin .. "_" .. eq
        end

        local function applyInjectedPspace(roleData)
            if not roleData then return end
            roleData.bshow = true
            roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
            local outfitRes = resolveLobbyOutfitRes()
            if outfitRes and outfitRes > 0 then
                roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
            end
            local skinRes = resolveLobbyWeaponSkinRes()
            if skinRes and skinRes > 0 then
                roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
                roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
                roleData.depot_show_info = roleData.depot_show_info or {}
                if roleData.depot_show_info.weapon == nil then roleData.depot_show_info.weapon = true end
            end
        end

        local function patchSelfWearCache(force)
            local key = wearPatchKey()
            if not force and SOCIAL.wearPatchKey == key then return false end
            SOCIAL.wearPatchKey = key
            local myUid = tonumber(DataMgr.roleData.uid)
            if not myUid then return false end
            pcall(function()
                local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                local d = BD:GetCacheData(myUid)
                if d then applyInjectedPspace(d) end
            end)
            return true
        end

        local function requestSocialAvatarRefresh()
            pcall(function()
                if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
                    EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
                end
            end)
        end

        local function onSocialWearDirty(forceRefresh)
            SOCIAL.lastHandSkin = nil
            if patchSelfWearCache(forceRefresh) then requestSocialAvatarRefresh() end
        end

        local _myUidCached
        local function isMyWearData(wearData)
            if not wearData then return false end
            if not _myUidCached then
                pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
            end
            return _myUidCached and tonumber(wearData.uid) == _myUidCached
        end

        local function mergeInjectedWeaponIntoWearData(wearData)
            if not isMyWearData(wearData) then return end
            local cch = cache()
            local wKey = ""
            for wid, w in pairs(cch.weapons) do wKey = wKey .. wid .. ":" .. (w.resID or 0) .. "," end
            wKey = wKey .. "|" .. tostring(DataMgr.Weapon_ID or 0)
            local skinRes
            if _weaponSkinResMergeCache.key == wKey then
                skinRes = _weaponSkinResMergeCache.res
            else
                skinRes = resolveLobbyWeaponSkinRes()
                _weaponSkinResMergeCache.key = wKey
                _weaponSkinResMergeCache.res = skinRes
            end
            if not skinRes or skinRes <= 0 then return end
            wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
                weaponResId = 0, weaponSkinId = 0,
                diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
            }
            wearData.mainWeaponInfo.weaponSkinId = skinRes
            wearData.mainWeaponInfo.weaponResId = 0
        end

        local function getOutfitMergeItems()
            local cch = cache()
            local clothKey = ""
            for resID in pairs(cch.clothes) do clothKey = clothKey .. resID .. "," end
            local key = (cch.outfitRes or 0) .. "_" .. clothKey .. "_" .. (cch.equip.bag or 0) .. "_" .. (cch.equip.helmet or 0)
            if _outfitMergeCache.key == key and _outfitMergeCache.items then
                return _outfitMergeCache.items
            end
            local outfitRes = resolveLobbyOutfitRes()
            local AvatarData = require("client.logic.data.AvatarData")
            local items = {}
            if outfitRes and outfitRes > 0 and isFullSuitRes(outfitRes) then
                rememberLobbyOutfitRes(outfitRes)
                local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
                if converted then items[#items + 1] = converted end
                for resID in pairs(collectAllClothResIDs()) do
                    if resID ~= outfitRes and not isFullSuitRes(resID)
                        and not isBodyClothSubType(subType(cfg(resID))) then
                        local cv = AvatarData.ConvertToAvatarCustom({ resID, 0, 0 })
                        if cv then items[#items + 1] = cv end
                    end
                end
            else
                for resID in pairs(collectAllClothResIDs()) do
                    if not isFullSuitRes(resID) then
                        local converted = AvatarData.ConvertToAvatarCustom({ resID, 0, 0 })
                        if converted then items[#items + 1] = converted end
                    end
                end
            end
            _outfitMergeCache.key = key
            _outfitMergeCache.items = items
            return items
        end

        local function mergeInjectedOutfitIntoWearData(wearData)
            if not isMyWearData(wearData) then return end
            local outfitRes = resolveLobbyOutfitRes()
            local items = getOutfitMergeItems()
            if #items == 0 then return end
            if outfitRes and outfitRes > 0 and isFullSuitRes(outfitRes) then
                local newList = {}
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if not (e and e.ItemID and isBodyClothSubType(subType(cfg(e.ItemID)))) then
                        newList[#newList + 1] = e
                    end
                end
                for _, item in ipairs(items) do
                    newList[#newList + 1] = item
                end
                wearData.WearInfoList = newList
            else
                wearData.WearInfoList = wearData.WearInfoList or {}
                for _, item in ipairs(items) do
                    wearData.WearInfoList[#wearData.WearInfoList + 1] = item
                end
            end
        end

        local function mergeInjectedEquipIntoWearData(wearData)
            if not isMyWearData(wearData) then return end
            local cch = cache()
            wearData.depot_show_info = wearData.depot_show_info or {}
            if cch.equip.bag and cch.equip.bag > 0 then
                local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                local bagLevel = getEquipDisplayLevel(cch.equip.bag, "bag")
                wearData.depot_show_info.bag = true
                wearData.bagSkinInsId = mapEquipSkinRes(catalogBag, bagLevel)
                wearData.skin_info = wearData.skin_info or {}
                wearData.skin_info.bag_skin = cch.equip.bagIns or R.resToIns[cch.equip.bag] or cch.equip.bag
                wearData.skin_info.bag_level = bagLevel
            end
            if cch.equip.helmet and cch.equip.helmet > 0 then
                local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                local helmLevel = getEquipDisplayLevel(cch.equip.helmet, "helmet")
                local helmDisplay = mapEquipSkinRes(catalogHelm, helmLevel)
                wearData.depot_show_info.helmet = true
                wearData.helmet_skin = helmDisplay
                wearData.headShow = helmDisplay
                wearData.skin_info = wearData.skin_info or {}
                wearData.skin_info.helmet_skin = cch.equip.helmetIns or R.resToIns[cch.equip.helmet] or cch.equip.helmet
                wearData.skin_info.head_show = wearData.skin_info.helmet_skin
                wearData.skin_info.helmet_level = helmLevel
            end
        end

        local function mergeInjectedIntoWearData(wearData)
            if not wearData then return end
            mergeInjectedWeaponIntoWearData(wearData)
            mergeInjectedOutfitIntoWearData(wearData)
            mergeInjectedEquipIntoWearData(wearData)
        end

-- @RAHMANYVI
        local function reapplyAccessoryIns(insID)
            insID = tonumber(insID)
            local resID = R.insToRes[insID]
            if not resID then return end
            local c = cfg(resID)
            local st = subType(c)
            saveClothPiece(resID)
            local itemSt = st
            local oldIns, oldRes
            if itemSt then
                oldIns, oldRes = findWornInsBySubType(itemSt)
                if oldIns == insID then oldIns, oldRes = nil, nil end
                removeRoleWearBySubTypes({ [itemSt] = true })
            end
            local WRH = require("client.network.Protocol.WardRobeHandler")
            local olditem
            if oldIns then
                olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
            end
            WRH.on_depot_put_on_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, olditem, 1, insID, oldIns or 0)
            pcall(function()
                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                if oldIns and itemSt then av:SetCurrentWearPreview(itemSt, nil) end
                if itemSt then av:AddToWearInfo(itemSt, insID, resID, 0, 0) end
                av:AvatarChange(resID, true, 0, 0)
                av:ProcessTakeOff()
                syncFashionBagRolewear()
            end)
        end

        local function reapplyInjectedIns(insID)
            insID = tonumber(insID)
            if not insID or not isInjectedIns(insID) then return end
            local resID = R.insToRes[insID]
            if not resID then return end
            if isHallThemeRes(resID) then
                putOnHallTheme(insID)
            elseif getEquipSkinSlot(resID) then
                putOnEquipSkin(insID)
            elseif getClothKind(resID) then
                putOnCloth(insID)
            elseif weaponIdFromSkin(resID) then
                equipWeaponSkin(weaponIdFromSkin(resID), insID)
            elseif _K.GUN_SUB[subType(cfg(resID))] then
                local cch = cache()
                local foundWid = nil
                for wid, w in pairs(cch.weapons or {}) do
                    if w.resID == resID then foundWid = wid; break end
                end
                if foundWid then equipWeaponSkin(foundWid, insID) end
            elseif subType(cfg(resID)) == _K.MELEE_ID then
                equipWeaponSkin(_K.MELEE_ID, insID)
            elseif isThrowObjectRes(resID) then
                putOnThrowObject(insID)
            else
                reapplyAccessoryIns(insID)
            end
        end

        -- ===== LOBBY: outfit dari rapzhang_outfit.json =====
        -- Ins sebuah res baru ada setelah injeksi depot selesai, jadi resolve
        -- dilakukan saat eksekusi (bukan saat JSON dibaca).
        local function persistResolveIns(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return nil end
            local ins = tonumber(R.resToIns[resID])
            if not ins then
                local RR = _G.AddOutfit_R
                if RR and RR.resToIns then ins = tonumber(RR.resToIns[resID]) end
            end
            if not ins and tonumber(_G._savedOutfitRes) == resID then
                ins = tonumber(_G._savedOutfitIns)
            end
            if ins and ins > 0 then
                R.resToIns[resID] = ins
                R.insToRes[ins] = resID
                return ins
            end
            return nil
        end

        -- Pasang satu res ke role wear lobby lewat jalur wardrobe asli.
        local function applyLobbyRes(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return false end
            local kind = getClothKind(resID)
            if not kind and not _clothSlotOf(resID) then return false end
            local ins = persistResolveIns(resID)
            if not ins or not isInjectedIns(ins) then return false end
            if kind then
                -- putOnCloth butuh data depot; kalau belum ada, coba lagi nanti.
                local hasData = false
                pcall(function()
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    hasData = wd:GetHallDepotItemDataByInsID(ins) ~= nil
                end)
                if not hasData then return false end
                return pcall(putOnCloth, ins)
            end
            return pcall(reapplyAccessoryIns, ins)
        end

        -- Terapkan outfit + potongan pakaian tersimpan ke lobby.
        -- Urutan: potongan badan -> full suit -> aksesori, supaya full suit
        -- tidak langsung dibatalkan saveEquip potongan lain.
        local function applyLobbyOutfitNow(done)
            done = done or {}
            local cch = cache()
            local outfitRes = tonumber(resolveLobbyOutfitRes())
            if outfitRes and outfitRes <= 0 then outfitRes = nil end
            local suit = outfitRes and isFullSuitRes(outfitRes) or false

            local body, acc = {}, {}
            for resID in pairs(cch.clothes or {}) do
                resID = tonumber(resID)
                if resID and resID > 0 and resID ~= outfitRes and not done[resID]
                    and (getClothKind(resID) or _clothSlotOf(resID)) then
                    if getClothKind(resID) then
                        body[#body + 1] = resID
                    else
                        acc[#acc + 1] = resID
                    end
                end
            end
            table.sort(body)
            table.sort(acc)

            local ok, tried = 0, 0
            local function attempt(resID)
                tried = tried + 1
                if applyLobbyRes(resID) then
                    done[resID] = true
                    ok = ok + 1
                end
            end

            if outfitRes and not done[outfitRes] then
                if not suit then
                    for _, resID in ipairs(body) do attempt(resID) end
                end
                attempt(outfitRes)
            elseif not outfitRes then
                for _, resID in ipairs(body) do attempt(resID) end
            end
            for _, resID in ipairs(acc) do attempt(resID) end
            return ok, tried
        end
        _G.AddOutfitApplyLobbyOutfit = applyLobbyOutfitNow

        local function reapplyLobbyEquipped(force)
            if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
                return
            end
            -- Gate 2 detik, tapi jangan sampai macet kalau timer reset tidak
            -- pernah jalan (mis. SetTimer/ticker belum siap).
            local nowLobby = 0
            pcall(function() nowLobby = os.clock() end)
            if not force and _S.lobbyApplied and (nowLobby - (_S.lobbyAppliedAt or 0)) < 2.0 then return end
            _S.lobbyApplied = true
            _S.lobbyAppliedAt = nowLobby
            later(2.0, function() _S.lobbyApplied = false end)

            restorePersistedVehicles()
            restorePersistedMotions()
            restorePersistedEquipIns()
            restorePersistedThrowObjects()
            restorePersistedHallTheme()
            syncMatchConfigFromCache()
            -- Lobby: dorong daftar avatar kendaraan supaya model ikut skin.
            pcall(function()
                if _G.AddOutfitSyncVehicleAvatarSkinList then
                    _G.AddOutfitSyncVehicleAvatarSkinList()
                end
            end)

            if not _G._addOutfitPersistLoaded then
                snapshotLobbyWear()
            end
            local cch = cache()
            if not _G._addOutfitPersistLoaded and _G._savedOutfitClothes then
                for resID in pairs(_G._savedOutfitClothes) do
                    cch.clothes[resID] = true
                end
            end
            if not _G._addOutfitPersistLoaded and _G._savedOutfitRes and (not cch.outfitRes or cch.outfitRes <= 0) then
                cch.outfitRes = _G._savedOutfitRes
                cch.outfitIns = _G._savedOutfitIns or R.resToIns[_G._savedOutfitRes]
            end
            syncMatchConfigFromCache()

            local applyStep = 0
            local function scheduleApply(fn)
                applyStep = applyStep + 1
                later(applyStep * 0.12, fn)
            end

            if not _G._addOutfitPersistLoaded and _G._savedRoleWearList and #_G._savedRoleWearList > 0 then
                for _, insID in ipairs(_G._savedRoleWearList) do
                    local id = insID
                    scheduleApply(function() pcall(reapplyInjectedIns, id) end)
                end
            end

            -- Outfit + pakaian dari rapzhang_outfit.json. Cabang lama memakai
            -- cch.outfitIns yang masih nil sebelum injeksi depot selesai,
            -- sehingga full suit tidak pernah terpasang di lobby.
            scheduleApply(function()
                local done = {}
                local tries = 0
                local function attempt()
                    tries = tries + 1
                    local ok, tried = applyLobbyOutfitNow(done)
                    if tried > 0 and ok < tried and tries < 5 then
                        later(0.6 + tries * 0.5, attempt)
                    end
                end
                attempt()

                -- Visual avatar: jalur 1.lua (SlotSyncData), tidak butuh ins.
                -- Diulang kalau karakter lobby belum siap.
                local function visual(attemptNo, maxAttempts)
                    local char = getLocalChar()
                    if char and _G.AddOutfitApplyAvatar then
                        pcall(_G.AddOutfitApplyAvatar, char)
                        return
                    end
                    if attemptNo < maxAttempts then
                        later(0.8, function() visual(attemptNo + 1, maxAttempts) end)
                    end
                end
                later(0.5, function() visual(1, 5) end)
                later(1.6, function() visual(1, 2) end)
            end)
            for wid, w in pairs(cch.weapons) do
                local weaponID, entry = wid, w
                scheduleApply(function()
                    if entry.insID and isInjectedIns(entry.insID) then
                        equipWeaponSkin(weaponID, entry.insID)
                    elseif entry.resID and R.resToIns[entry.resID] and isInjectedIns(R.resToIns[entry.resID]) then
                        equipWeaponSkin(weaponID, R.resToIns[entry.resID])
                    end
                end)
            end
            for _, slot in ipairs({ "bag", "helmet", "armor", "parachute", "glider" }) do
                local resID = cch.equip[slot]
                local insID = cch.equip[slot .. "Ins"]
                scheduleApply(function()
                    if insID and isInjectedIns(insID) then
                        putOnEquipSkin(insID)
                    elseif resID and R.resToIns[resID] then
                        putOnEquipSkin(R.resToIns[resID])
                    end
                end)
            end
            if cch.throwObjects then
                for st, info in pairs(cch.throwObjects) do
                    local tInfo = info
                    scheduleApply(function()
                        if tInfo.insID and isInjectedIns(tInfo.insID) then
                            putOnThrowObject(tInfo.insID)
                        elseif tInfo.resID and R.resToIns[tInfo.resID] and isInjectedIns(R.resToIns[tInfo.resID]) then
                            putOnThrowObject(R.resToIns[tInfo.resID])
                        end
                    end)
                end
            end
            later(math.max(applyStep * 0.12 + 0.3, 0.5), function()
                syncMatchConfigFromCache()
                pcall(_AutoSaveOutfit, true)
                log("-- @RAHMANYVI (-- @RAHMANYVI)")
            end)

            pcall(function()
                if _G._addOutfitPersistLoaded then return end
                local GTS = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if not GTS then return end
                local maxSlots = GTS:GetMaxPositionNum()
                GTS.GarageVehicleInfo = GTS.GarageVehicleInfo or {}
                local usedIns = {}
                for slot, info in pairs(GTS.GarageVehicleInfo) do
                    if info and info.inst_id then
                        usedIns[tonumber(info.inst_id)] = true
                    end
                end
                local changed = false
                for slot = 1, maxSlots do
                    if not GTS.GarageVehicleInfo[slot] then
                        for _, resID in ipairs(_C.vehicleItems) do
                            if isInjectedRes(resID) then
                                local insID = R.resToIns[resID]
                                if insID and not usedIns[insID] then
                                    GTS.GarageVehicleInfo[slot] = { inst_id = insID, res_id = resID }
                                    usedIns[insID] = true
                                    changed = true
                                    break
                                end
                            end
                        end
                    end
                end
                if changed then
                    if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                        EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                    end
                end
            end)
        end

        -- Paksa apply ulang outfit lobby dari konsol:
        --   _G.AddOutfitReapplyLobby()
        _G.AddOutfitReapplyLobby = function() reapplyLobbyEquipped(true) end

        local function initHooks()
        local function hookLobbySwipePersistence()
            pcall(function()
                local AC = require("client.slua.logic.avatar.avatar_common")
                local oGetWear = AC.GetWearDataFromRoleData
                AC.GetWearDataFromRoleData = function(roleData)
                    local wearData = oGetWear(roleData)
                    if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid) then
                        mergeInjectedIntoWearData(wearData)
                    end
                    return wearData
                end
                local oUp = AC.UpdateAvatar
                AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
                    if isMyWearData(wearData) then mergeInjectedIntoWearData(wearData) end
                    return oUp(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
                end
            end)
            pcall(function()
                if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
                    EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                        if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                            socialDebounce(0.5, reapplyLobbyEquipped) ---- @RAHMANYVI
                        end
                    end)
                end
            end)
        end

        -- ========== -- @RAHMANYVI==========
        local function hookCDataTableCache()
            pcall(function()
                if not CDataTable or CDataTable._lava_cached then return end
                CDataTable._lava_cached = true
                local origGetTableData = CDataTable.GetTableData
                CDataTable.GetTableData = function(tableName, resID, ...)
                    if tableName == "Item" then
                        resID = tonumber(resID)
                        if resID and _C.cfg[resID] ~= nil then
                            return _C.cfg[resID]
                        end
                        local result = origGetTableData(tableName, resID, ...)
                        if resID then
                            _C.cfg[resID] = result
                        end
                        return result
                    end
                    return origGetTableData(tableName, resID, ...)
                end
            end)
        end

        local function hookDepotInit()
            pcall(function()
                local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
                local orig = WDE.InitData
                WDE.InitData = function(self, pkg)
                    orig(self, pkg)
                    injectAll(self)
                    refreshWardrobe()
                end
            end)
        end

        local function hookWardrobeData()
            pcall(function()
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local function wrapGet(name)
                    local o = wd[name]
                    if not o then return end
                    wd[name] = function(self, insID, ...)
                        insID = tonumber(insID)
                        if isInjectedIns(insID) then
                            local e = getEntity()
                            if e then return e:GetDataByInsID(insID) end
                        end
                        return o(self, insID, ...)
                    end
                end
                wrapGet("GetHallDepotItemDataByInsID")
                wrapGet("GetValidHallDepotItemDataByInsID")
                local function wrapBool(name)
                    local o = wd[name]
                    if not o then return end
                    wd[name] = function(self, id, ...)
                        if isInjectedRes(tonumber(id)) or isInjectedIns(tonumber(id)) then return true end
                        return o(self, id, ...)
                    end
                end
                wrapBool("HasItem")
                wrapBool("HasValidItem")
                wrapBool("CheckHasPermanentItem")
                if not wd._lava_global_equip then
                    wd._lava_global_equip = true
                    local origGetEquipped = wd.GetEquippedSkinIDByWeaponID
                    wd.GetEquippedSkinIDByWeaponID = function(self, weaponID)
                        local w = cache().weapons[tonumber(weaponID)]
                        if w and w.resID and w.resID > 0 then return w.resID end
                        return origGetEquipped(self, weaponID)
                    end
                end
                if not wd._lava_global_equip_ins then
                    wd._lava_global_equip_ins = true
                    if wd.GetEquippedSkinInsIDByWeaponID then
                        local origGetEquippedIns = wd.GetEquippedSkinInsIDByWeaponID
                        wd.GetEquippedSkinInsIDByWeaponID = function(self, weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then return w.insID end
                            return origGetEquippedIns(self, weaponID)
                        end
                    end
                    if wd.GetWeaponSkinInsID then
                        local origGetWSI = wd.GetWeaponSkinInsID
                        wd.GetWeaponSkinInsID = function(self, weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then return w.insID end
                            return origGetWSI(self, weaponID)
                        end
                    end
                end
            end)
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local oPutDownReq = wl.wardrobe_put_down_req
                if oPutDownReq then
                    wl.wardrobe_put_down_req = function(self, ins_id, unequip_by_server)
                        ins_id = tonumber(ins_id)
                        if isInjectedIns(ins_id) then
                            local resID = R.insToRes[ins_id]
                            takeOffItem(ins_id)
                            pcall(function()
                                self:on_putdown_rsp(_K.NET_OK, {
                                    instid = ins_id,
                                    res_id = resID or 0,
                                }, nil)
                            end)
                            pcall(function()
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA, {
                                        instid = ins_id,
                                        res_id = resID or 0,
                                        count = 1,
                                    })
                                end
                            end)
                            refreshWardrobe()
                            return
                        end
                        return oPutDownReq(self, ins_id, unequip_by_server)
                    end
                end
            end)
        end

        local function hookPageFilter()
            pcall(function()
                local SubTab = require("client.slua.umg.Wardrobe.subtab_item_list_base")
                if SubTab._lava_prefilter then return end
                SubTab._lava_prefilter = true
                local origGet = SubTab.GetArrayHallDepotItemInfo
                SubTab.GetArrayHallDepotItemInfo = function(self)
                    local allData = origGet(self)
                    if not allData or not next(allData) then return allData end
                    local pageId = self.subTabConfig and self.subTabConfig.pageId
                    local subTabId = self.subTabConfig and self.subTabConfig.subTabId
                    if not pageId or not subTabId then return allData end
                    local result = {}
                    for _, data in pairs(allData) do
                        local resID = depotResID(data)
                        if resID and isInjectedRes(resID) then
                            local itemMain, itemSub = getInjectedItemTab(resID, data)
                            if itemMain == pageId then
                                if pageId == _K.WARDROBE_PAGE_AVATAR then
                                    if subTabId == _K.WARDROBE_TAB_SUIT or subTabId == _K.WARDROBE_TAB_CLOTHES then
                                        local st = data.itemSubType or subType(cfg(resID))
                                        if st == _K.ST_TOP then
                                            local full = isFullSuitRes(resID, data)
                                            if (subTabId == _K.WARDROBE_TAB_SUIT and full) or
                                            (subTabId == _K.WARDROBE_TAB_CLOTHES and not full) then
                                                result[#result + 1] = data
                                            end
                                        end
                                    elseif itemSub == subTabId then
                                        result[#result + 1] = data
                                    end
                                elseif itemSub == subTabId then
                                    result[#result + 1] = data
                                end
                            end
                        else
                            result[#result + 1] = data
                        end
                    end
                    return result
                end
            end)
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local o1 = wl.IsValidCurrentPageItem
                wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
                    local resID = depotResID(v)
                    if resID and isInjectedRes(resID) then
                        local cacheKey = resID .. "_" .. mainTab .. "_" .. subTab
                        if _C.pageMatch[cacheKey] ~= nil then
                            return _C.pageMatch[cacheKey]
                        end
                        local result
                        if not (v.expireTS == 0 or not t or t < v.expireTS) then
                            result = false
                        else
                            local equipOk = injectedEquipAllowed(resID, mainTab, subTab)
                            if equipOk ~= nil then
                                result = equipOk
                            elseif weaponIdFromSkin(resID) then
                                result = mainTab == _K.WARDROBE_PAGE_WEAPON and subTab == _K.WARDROBE_TAB_GUN
                            elseif mainTab == _K.WARDROBE_PAGE_VEHICLE then
                                local c = cfg(resID)
                                local wmTab = c and tonumber(c.WardrobeMainTab or c.wardrobeMainTab) or 0
                                if wmTab ~= mainTab and v.mainTabType ~= mainTab then
                                    result = false
                                else
                                    local wTab = c and tonumber(c.WardrobeTab or c.wardrobeTab) or nil
                                    local vTab = v.subTabType and tonumber(v.subTabType) or nil
                                    if wTab and wTab == subTab then result = true
                                    elseif vTab and vTab == subTab then result = true
                                    else result = o1(self, mainTab, subTab, v, t) end
                                end
                            elseif mainTab == _K.WARDROBE_PAGE_AVATAR then
                                local st = v.itemSubType or subType(cfg(resID))
                                if st == _K.ST_TOP then
                                    local full = isFullSuitRes(resID, v)
                                    if subTab == _K.WARDROBE_TAB_SUIT and full then result = true
                                    elseif subTab == _K.WARDROBE_TAB_CLOTHES and not full then result = true
                                    else result = false end
                                elseif st == _K.ST_PANTS and subTab == _K.WARDROBE_TAB_TROUSERS then
                                    result = true
                                elseif st == _K.ST_SHOES and subTab == _K.WARDROBE_TAB_SHOES then
                                    result = true
                                elseif v.subTabType == subTab then
                                    result = true
                                else
                                    result = false
                                end
                            else
                                result = o1(self, mainTab, subTab, v, t)
                            end
                        end
                        _C.pageMatch[cacheKey] = result
                        return result
                    end
                    return o1(self, mainTab, subTab, v, t)
                end
                local o2 = wl.IsCanUse
                wl.IsCanUse = function(self, resId)
                    if isInjectedRes(resId) then return true end
                    return o2(self, resId)
                end
                local o4 = wl.GetWardrobeInsIdByResId
                wl.GetWardrobeInsIdByResId = function(self, resid)
                    resid = tonumber(resid)
                    if isInjectedRes(resid) then return R.resToIns[resid] end
                    return o4(self, resid)
                end
            end)
        end

        local function hookArmory()
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                if not Arm._lava_global_own then
                    Arm._lava_global_own = true
                    local origIsOwn = Arm.IsSkinOwn
                    Arm.IsSkinOwn = function(weaponID, skinID)
                        if isInjectedRes(skinID) then return 1 end
                        return origIsOwn(weaponID, skinID)
                    end
                end
                if not Arm._lava_global_get_install then
                    Arm._lava_global_get_install = true
                    if Arm.get_install_skin then
                        local origGetInstall = Arm.get_install_skin
                        Arm.get_install_skin = function(weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return { skin_id = w.insID }
                            end
                            return origGetInstall(weaponID)
                        end
                    end
                    if Arm.GetInstallSkinInsID then
                        local origGetInstall2 = Arm.GetInstallSkinInsID
                        Arm.GetInstallSkinInsID = function(weaponID)
                            local w = cache().weapons[tonumber(weaponID)]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return w.insID
                            end
                            return origGetInstall2(weaponID)
                        end
                    end
                end
                local oi = Arm.install_weapon_skin
                Arm.install_weapon_skin = function(cd, wid, ins)
                    ins = tonumber(ins)
                    if isInjectedIns(ins) then
                        wid = tonumber(weaponIdFromSkin(R.insToRes[ins]) or wid)
                        equipWeaponSkin(wid, ins)
                        return
                    end
                    return oi(cd, wid, ins)
                end
                local function hookArmoryUninstall(fnName)
                    local orig = Arm[fnName]
                    if not orig then return end
                    Arm[fnName] = function(cd, wid, ins, ...)
                        ins = tonumber(ins)
                        wid = tonumber(wid)
                        if ins and isInjectedIns(ins) then
                            local resID = R.insToRes[ins]
                            wid = weaponIdFromSkin(resID) or wid
                            if takeOffItem(ins) then
                                refreshWardrobe()
                                return
                            end
                        elseif wid and wid > 0 then
                            local cch = cache()
                            local w = cch.weapons[wid]
                            if w and w.insID and isInjectedIns(w.insID) then
                                if takeOffItem(w.insID) then
                                    refreshWardrobe()
                                    return
                                end
                            end
                        end
                        return orig(cd, wid, ins, ...)
                    end
                end
                hookArmoryUninstall("uninstall_weapon_skin")
                hookArmoryUninstall("remove_weapon_skin")
            end)
        end

        local function hookLobbyTheme()
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                if wl._lava_hooked_hall_theme then return end
                wl._lava_hooked_hall_theme = true
                local origPutOn = wl.wardrobe_puton_req
                wl.wardrobe_puton_req = function(self, insID, extra)
                    insID = tonumber(insID)
                    if insID and isInjectedIns(insID) and isHallThemeRes(R.insToRes[insID]) then
                        putOnHallTheme(insID)
                        return
                    end
                    return origPutOn(self, insID, extra)
                end
            end)
        end

        local function hookPutOn()
            pcall(function()
                local WRH = require("client.network.Protocol.WardRobeHandler")
                local o = WRH.send_depot_put_on_req
                WRH.send_depot_put_on_req = function(insID, extra)
                    insID = tonumber(insID)
                    if isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        local c = cfg(resID)
                        local st = subType(c)
                        if getEquipSkinSlot(resID) then
                            putOnEquipSkin(insID)
                            return
                        end
                        if getClothKind(resID) then
                            putOnCloth(insID)
                            return
                        end
                        if _K.GUN_SUB[st] then
                            local wid = weaponIdFromSkin(resID)
                            if not wid then
                                pcall(function()
                                    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                                    wid = wgl.GetCurGunID and wgl:GetCurGunID() or nil
                                    if not wid and wgl.GetCurrentGunID then
                                        wid = wgl:GetCurrentGunID()
                                    end
                                end)
                            end
                            if wid then equipWeaponSkin(wid, insID) end
                            return
                        end
                        if st == _K.MELEE_ID then
                            equipWeaponSkin(_K.MELEE_ID, insID)
                            return
                        end
                        if isHallThemeRes(resID) then
                            putOnHallTheme(insID)
                            return
                        end
                        if isThrowObjectRes(resID) then
                            local st = isThrowObjectRes(resID)
                            local cch = cache()
                            local oldThrow = cch.throwObjects and cch.throwObjects[st]
                            local oldInsID = oldThrow and oldThrow.insID or 0
                            local oldResID = oldThrow and oldThrow.resID or 0
                            putOnThrowObject(insID)
                            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                            local bagIndex = fbd:GetFashionBagUseIndex()
                            local olditem
                            if oldInsID and oldInsID ~= insID and oldInsID ~= 0 then
                                olditem = { res_id = oldResID, count = 1, instid = oldInsID }
                            end
                            WRH.on_depot_put_on_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, olditem, bagIndex, insID, oldInsID, extra)
                            return
                        end
                        local mainTab = wardrobeMainTab(resID)
                        if mainTab == _K.WARDROBE_PAGE_VEHICLE then
                            local item = { res_id = resID, count = 1, instid = insID }
                            WRH.on_depot_put_on_rsp(_K.NET_OK, item, nil, 1, insID, 0, extra)
                            return
                        end
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        if wd:GetHallDepotItemDataByInsID(insID) then
-- @RAHMANYVI
                            local itemSt = st or subType(cfg(resID))
                            local oldIns, oldRes
                            if itemSt then
                                oldIns, oldRes = findWornInsBySubType(itemSt)
                                if oldIns == insID then oldIns, oldRes = nil, nil end
                                removeRoleWearBySubTypes({ [itemSt] = true })
                            end
                            saveClothPiece(resID)
                            local olditem
                            if oldIns then
                                olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
                            end
                            WRH.on_depot_put_on_rsp(_K.NET_OK, { res_id = resID, count = 1, instid = insID }, olditem, 1, insID, oldIns or 0, extra)
                            pcall(function()
                                local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                                if oldIns and itemSt then av:SetCurrentWearPreview(itemSt, nil) end
                                if itemSt then av:AddToWearInfo(itemSt, insID, resID, 0, 0) end
                                av:AvatarChange(resID, true, 0, 0)
                                av:ProcessTakeOff()
                                syncFashionBagRolewear()
                            end)
                            pcall(_AutoSaveOutfit)
                        end
                        return
                    end
                    return o(insID, extra)
                end
            end)

            pcall(function()
                local WRH = require("client.network.Protocol.WardRobeHandler")
                local oPutDown = WRH.send_depot_put_down_req
                WRH.send_depot_put_down_req = function(insID, extra)
                    insID = tonumber(insID)
                    if isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        local removed = takeOffItem(insID)
                        if removed then
                            local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                            pcall(function()
                                wl:on_putdown_rsp(_K.NET_OK, {
                                    res_id = resID or 0,
                                    instid = insID,
                                    count  = 1,
                                }, nil)
                            end)
                            pcall(function()
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA, {
                                        instid = insID,
                                        res_id = resID or 0,
                                        count = 1,
                                    })
                                end
                            end)
                            refreshWardrobe()
                            return
                        end
                    end
                    return oPutDown(insID, extra)
                end
            end)

            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local oPutDownReq = wl.wardrobe_put_down_req
                if oPutDownReq then
                    wl.wardrobe_put_down_req = function(self, ins_id, unequip_by_server)
                        ins_id = tonumber(ins_id)
                        if isInjectedIns(ins_id) then
                            local resID = R.insToRes[ins_id]
                            takeOffItem(ins_id)
                            pcall(function()
                                self:on_putdown_rsp(_K.NET_OK, {
                                    instid = ins_id,
                                    res_id = resID or 0,
                                }, nil)
                            end)
                            pcall(function()
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_PUT_DOWN_DATA, {
                                        instid = ins_id,
                                        res_id = resID or 0,
                                        count = 1,
                                    })
                                end
                            end)
                            refreshWardrobe()
                            return
                        end
                        return oPutDownReq(self, ins_id, unequip_by_server)
                    end
                end
            end)

            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local oEquipSlot = wl.EquipSlotVehicle
                if oEquipSlot and not wl._lava_hooked_equip_slot_vehicle then
                    wl._lava_hooked_equip_slot_vehicle = true
                    wl.EquipSlotVehicle = function(self, resid, dragVehicleInsID, Index)
                        dragVehicleInsID = tonumber(dragVehicleInsID)
                        if dragVehicleInsID and isInjectedIns(dragVehicleInsID) then
                            local resID = R.insToRes[dragVehicleInsID]
                            local c = cfg(resID)
                            local itemSubType = c and tonumber(c.ItemSubType or c.itemSubType) or 0
                            if itemSubType and itemSubType > 0 then
                                DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                                local slotList = DataMgr.VehicleSlotList[itemSubType] or {}
                                local idx = Index or 1
                                for i = #slotList, 1, -1 do
                                    if slotList[i] == dragVehicleInsID then
                                        table.remove(slotList, i)
                                    end
                                end
                                slotList[idx] = dragVehicleInsID
                                DataMgr.VehicleSlotList[itemSubType] = slotList
                                if DataMgr.vehicleSkinInsIDTable then
                                    DataMgr.vehicleSkinInsIDTable[resID] = DataMgr.vehicleSkinInsIDTable[resID] or dragVehicleInsID
                                end
                            end
                            DataMgr.UpdateVehicleSkin(itemSubType, dragVehicleInsID)
                            pcall(function()
                                local tabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
                                if tabSurveillance and tabSurveillance.VehicleChange then
                                    tabSurveillance.VehicleChange()
                                end
                            end)
                            if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE then
                                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_VEHICLE_SLOT_DATA_CHANGE)
                            end
                            return
                        end
                        return oEquipSlot(self, resid, dragVehicleInsID, Index)
                    end
                end
            end)

            pcall(function()
                local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if GarageThemeSystem and not GarageThemeSystem._lava_hooked_equip_vehicle then
                    GarageThemeSystem._lava_hooked_equip_vehicle = true
                    local oEquip = GarageThemeSystem.EquipVehicle
                    GarageThemeSystem.EquipVehicle = function(self, Position, InsID)
                        InsID = tonumber(InsID)
                        if InsID and isInjectedIns(InsID) then
                            self:OnEquipVehicle(Position, InsID)
                            return
                        end
                        return oEquip(self, Position, InsID)
                    end
                    local oBatch = GarageThemeSystem.BatchEquipVehicle
                    GarageThemeSystem.BatchEquipVehicle = function(self, InsIDList)
                        if InsIDList and type(InsIDList) == "table" then
                            local hasInjected = false
                            local filtered = {}
                            for slot, ins in pairs(InsIDList) do
                                if isInjectedIns(tonumber(ins)) then
                                    hasInjected = true
                                    self:OnEquipVehicle(slot, tonumber(ins))
                                else
                                    filtered[slot] = ins
                                end
                            end
                            if hasInjected and not next(filtered) then
                                return
                            end
                            InsIDList = filtered
                        end
                        return oBatch(self, InsIDList)
                    end

                    local oReceive = GarageThemeSystem.OnReceiveGarageData
                    GarageThemeSystem.OnReceiveGarageData = function(self, VehicleInfo)
                        local injectedSlots = {}
                        if self.GarageVehicleInfo then
                            for slot, info in pairs(self.GarageVehicleInfo) do
                                if info and info.inst_id and isInjectedIns(tonumber(info.inst_id)) then
                                    injectedSlots[slot] = info
                                end
                            end
                        end
                        oReceive(self, VehicleInfo)
                        for slot, info in pairs(injectedSlots) do
                            if not self.GarageVehicleInfo[slot] then
                                self.GarageVehicleInfo[slot] = info
                            end
                        end
                    end

                    local oGetInfo = GarageThemeSystem.GetGarageVehicleInfo
                    GarageThemeSystem.GetGarageVehicleInfo = function(self)
                        if not self.bDataReceived and self.GarageVehicleInfo and next(self.GarageVehicleInfo) then
                            return self.GarageVehicleInfo
                        end
                        return oGetInfo(self)
                    end

                    local oGetShowList = GarageThemeSystem.GetGarageShowCarInsIDList
                    if oGetShowList then
                        GarageThemeSystem.GetGarageShowCarInsIDList = function(self, VehicleType)
                            local List = oGetShowList(self, VehicleType) or {}
                            for _, resID in ipairs(_C.vehicleItems) do
                                if isInjectedRes(resID) and #List < self:GetMaxPositionNum() then
                                    local c = cfg(resID)
                                    if c then
                                        local itemSubType = tonumber(c.ItemSubType or c.itemSubType) or 0
                                        local taxonomy = CDataTable.GetTableDataByFilter("WardrobeVehiclesTaxonomy", "ItemSubType", itemSubType)
                                        if taxonomy and taxonomy.UseInGarage == 1 and taxonomy.CategoryID == VehicleType then
                                            local insID = R.resToIns[resID]
                                            if insID then
                                                local alreadyIn = false
                                                for _, existingIns in ipairs(List) do
                                                    if tonumber(existingIns) == tonumber(insID) then
                                                        alreadyIn = true
                                                        break
                                                    end
                                                end
                                                if not alreadyIn then
                                                    table.insert(List, insID)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            return List
                        end
                    end
                end
            end)
        end

        local function hookMotionEquip()
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                if wl._lava_hooked_motion then return end
                wl._lava_hooked_motion = true

                local origEquip = wl.EquipMotion
                wl.EquipMotion = function(self, instid, dst_slot)
                    instid = tonumber(instid)
                    if instid and isInjectedIns(instid) then
                        local insSlot = 0
                        for i, v in ipairs(DataMgr.MotionSlotList) do
                            if v == instid then insSlot = i; break end
                        end
                        if insSlot > 0 then
                            local curIns = DataMgr.MotionSlotList[dst_slot]
                            if curIns == instid then return end
                            DataMgr.MotionSlotList[insSlot] = curIns or 0
                            DataMgr.MotionSlotList[dst_slot] = instid
                        else
                            while #DataMgr.MotionSlotList < dst_slot do
                                table.insert(DataMgr.MotionSlotList, 0)
                            end
                            DataMgr.MotionSlotList[dst_slot] = instid
                        end
                        if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                            EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                        end
                        pcall(_AutoSaveOutfit)
                        return
                    end
                    return origEquip(self, instid, dst_slot)
                end

                local origUnequip = wl.unequip_motion_req
                wl.unequip_motion_req = function(self, instid, slot)
                    instid = tonumber(instid)
                    if instid and isInjectedIns(instid) then
                        for i, v in ipairs(DataMgr.MotionSlotList) do
                            if v == instid then
                                table.remove(DataMgr.MotionSlotList, i)
                                break
                            end
                        end
                        if EventSystem and EVENTTYPE_MOTION and EVENTID_MOTION_UPDATE_SLOT_LIST then
                            EventSystem:postEvent(EVENTTYPE_MOTION, EVENTID_MOTION_UPDATE_SLOT_LIST)
                        end
                        pcall(_AutoSaveOutfit)
                        return
                    end
                    return origUnequip(self, instid, slot)
                end
            end)
        end

        local _emoteSlotKey = nil
        local _emoteSlotCache = {}
        local function getInjectedEmotes()
            local slotList = DataMgr and DataMgr.MotionSlotList or {}
            local key = table.concat(slotList, ",")
            if key == _emoteSlotKey then return _emoteSlotCache end
            _emoteSlotKey = key
            _emoteSlotCache = {}
            for _, insID in ipairs(slotList) do
                insID = tonumber(insID)
                if insID and insID > 0 and isInjectedIns(insID) then
                    local resID = R.insToRes[insID]
                    if resID then
                        local c = cfg(resID)
                        if c and tonumber(c.ItemType) == 22 then
                            _emoteSlotCache[#_emoteSlotCache + 1] = {
                                resID = resID,
                                name = c.ItemName or "",
                                icon = c.ItemSmallIcon or c.ItemIcon or ""
                            }
                        end
                    end
                end
            end
            return _emoteSlotCache
        end

        local function hookIngameEmote()
            pcall(function()
                local QEU = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")
                if QEU._lava_hooked then return end
                QEU._lava_hooked = true

                local origGetList = QEU.GetShowExpressionList
                QEU.GetShowExpressionList = function()
                    local tShowEmoteList, nWeaponEmoteId = origGetList()
                    tShowEmoteList = tShowEmoteList or {}
                    local emotes = getInjectedEmotes()
                    if #emotes > 0 then
                        local existingIDs = {}
                        for _, existing in pairs(tShowEmoteList) do
                            if existing.DefineID then
                                existingIDs[tonumber(existing.DefineID.TypeSpecificID) or 0] = true
                            end
                        end
                        for _, em in ipairs(emotes) do
                            if not existingIDs[em.resID] then
                                tShowEmoteList[#tShowEmoteList + 1] = {
                                    DefineID = {TypeSpecificID = em.resID},
                                    Name = em.name
                                }
                            end
                        end
                    end
                    return tShowEmoteList, nWeaponEmoteId
                end
            end)

            pcall(function()
                local QE = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpression")
                if QE._lava_hooked_img then return end
                QE._lava_hooked_img = true

                local origGetImg = QE.GetEmoteImagePalthMap
                QE.GetEmoteImagePalthMap = function(self, ...)
                    origGetImg(self, ...)
                    local emotes = getInjectedEmotes()
                    for _, em in ipairs(emotes) do
                        if em.icon ~= "" then
                            self.ItemIDToImagePathMap[em.resID] = em.icon
                        end
                    end
                end
            end)

            pcall(function()
                local le = require("GameLua.Mod.Library.GamePlay.Avatar.Emote.logic_emote")
                if le._lava_hooked_exist then return end
                le._lava_hooked_exist = true

                local origExist = le.IsEmoteExist
                le.IsEmoteExist = function(EmoteID)
                    if isInjectedRes(tonumber(EmoteID)) then return true end
                    return origExist(EmoteID)
                end

                local origDownloaded = le.CheckEmoteDownloaded
                if origDownloaded then
                    le.CheckEmoteDownloaded = function(EmoteID, bUseCache, bLobby, bForeceLobby)
                        if isInjectedRes(tonumber(EmoteID)) then return true end
                        return origDownloaded(EmoteID, bUseCache, bLobby, bForeceLobby)
                    end
                end
            end)
        end

        local function hookFashionBag()
            pcall(function()
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                if fbd._lava_hooked_bag then return end
                fbd._lava_hooked_bag = true
                local function onFashionBagSkinChanged(skin, slot)
                    skin = tonumber(skin)
                    if _S.equipSkinApplying or not skin or skin <= 0 or not isInjectedIns(skin) then return end
                    local rid = R.insToRes[skin]
                    if not rid or not isInjectedRes(rid) then return end
                    local cch = cache()
                    local oldRes = cch.equip[slot]
                    if oldRes and oldRes > 0 and oldRes ~= rid then
                        softRemoveEquipVisual(oldRes, slot)
                    end
                    saveEquipSkin(rid, skin)
                    if slot ~= "parachute" and slot ~= "glider" then
                        applyEquipVisual(rid, skin, slot)
                    end
                end
                local origBag = fbd.SetBagSkin
                fbd.SetBagSkin = function(self, skin)
                    local r = origBag(self, skin)
                    onFashionBagSkinChanged(skin, "bag")
                    return r
                end
                local origHelm = fbd.SetHelmetSkin
                fbd.SetHelmetSkin = function(self, skin)
                    local r = origHelm(self, skin)
                    onFashionBagSkinChanged(skin, "helmet")
                    return r
                end
                local function reInjectThrowObjects(bagIndex)
                    pcall(function()
                        local cch = cache()
                        if not cch.throwObjects then return end
                        local bags = fbd.GetFashionBags and fbd:GetFashionBags()
                        if not bags or not bags.bags then return end
                        local bag = bags.bags[bagIndex]
                        if not bag then return end
                        bag.throw_object_list = bag.throw_object_list or {}
                        for st, info in pairs(cch.throwObjects) do
                            if info.insID and info.insID > 0 and _K.THROW_SUB[st] then
                                bag.throw_object_list[st] = info.insID
                            end
                        end
                    end)
                end
                local origUpdateAll = fbd.UpdateAllFashionBagExtraInfos
                if origUpdateAll then
                    fbd.UpdateAllFashionBagExtraInfos = function(self, all_knapsack_ext_info)
                        origUpdateAll(self, all_knapsack_ext_info)
                        if all_knapsack_ext_info then
                            for i, _ in pairs(all_knapsack_ext_info) do
                                reInjectThrowObjects(i)
                            end
                        end
                    end
                end
                local origUpdateOne = fbd.UpdateFashionBagExtraInfoByIndex
                if origUpdateOne then
                    fbd.UpdateFashionBagExtraInfoByIndex = function(self, index, knapsack_ext_info)
                        origUpdateOne(self, index, knapsack_ext_info)
                        if index then reInjectThrowObjects(index) end
                    end
                end
            end)
            pcall(function()
                if not DataMgr or DataMgr._lava_hooked_equip_skin then return end
                DataMgr._lava_hooked_equip_skin = true
                local orig = DataMgr.UpdateEquipmentSkin
                DataMgr.UpdateEquipmentSkin = function(itemSubType, putOnId)
                    putOnId = tonumber(putOnId)
                    if putOnId and putOnId > 0 and isInjectedIns(putOnId) and not _S.equipSkinApplying then
                        putOnEquipSkin(putOnId)
                    elseif putOnId == 0 then
                        local slot = (itemSubType == ENUM_ITEM_SUBTYPE.Backpack) and "bag"
                            or (itemSubType == ENUM_ITEM_SUBTYPE.Helmet_NoLevel) and "helmet" or nil
                        if slot then
                            local cch = cache()
                            takeOffEquipSkinVisual(slot, cch.equip[slot], cch.equip[slot .. "Ins"])
                            cch.equip[slot]          = nil
                            cch.equip[slot .. "Ins"] = nil
                            if MATCH_CONFIG.equip then MATCH_CONFIG.equip[slot] = 0 end
                            _S.matchApplied = false
                            invalidateSocialWearCache()
                            pcall(_AutoSaveOutfit)
                        end
                    end
                    return orig(itemSubType, putOnId)
                end
            end)
        end

        local function hookBackpackValid()
            if _G.DEV_WARDROBE_BP_HOOKED then return end
            _G.DEV_WARDROBE_BP_HOOKED = true
            pcall(function()
                local BU = import("BackpackUtils")
                if BU and BU.GetBPIDByResID then
                    local orig = BU.GetBPIDByResID
                    BU.GetBPIDByResID = function(resID)
                        resID = tonumber(resID)
                        if resID and isInjectedRes(resID) then
                            local bp = orig(resID)
                            if bp and bp > 0 then return bp end
                            return resID
                        end
                        return orig(resID)
                    end
                end
            end)
            pcall(function()
                local AU = import("AvatarUtils")
                if AU and AU.GetBPIDByResID then
                    local orig = AU.GetBPIDByResID
                    AU.GetBPIDByResID = function(resID, ...)
                        resID = tonumber(resID)
                        if resID and isInjectedRes(resID) then
                            local bp = orig(resID, ...)
                            if bp and bp > 0 then return bp end
                            return resID
                        end
                        return orig(resID, ...)
                    end
                end
            end)
        end

        local function hookAvatarValid()
            pcall(function()
                local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
                if not CAC._lava_hooked_check_valid then
                    CAC._lava_hooked_check_valid = true
                    local orig = CAC.CheckItemValid
                    CAC.CheckItemValid = function(self, resID)
                        if isInjectedRes(resID) then return true end
                        return orig(self, resID)
                    end
                end
                if not CAC._lava_hooked_puton then
                    CAC._lava_hooked_puton = true
                    local origPutOn = CAC.PutOnCustomEquipmentByID
                    CAC.PutOnCustomEquipmentByID = function(self, resID, CustomData)
                        -- Skip non-local player to avoid lag
                        if self.IsSelf and not self:IsSelf() then
                            return origPutOn(self, resID, CustomData)
                        end
                        resID = tonumber(resID)
                        if resID and isInjectedRes(resID) then
                            local ok, result = pcall(function()
                                local ItemDefineID = FItemDefineID(4, resID)
                                local EAvatarCustomType = import("EAvatarCustomType")
                                local AvatarCustom = FAvatarCustomDefault()
                                if CustomData then AvatarCustom = CustomData end
                                AvatarCustom.CustomType = EAvatarCustomType.AvatarCustomCharacter
                                return self:HandleEquipItem(ItemDefineID, AvatarCustom)
                            end)
                            if ok and result == true then return true end
                            if ok and result ~= false and result ~= nil then return result end
                        end
                        return origPutOn(self, resID, CustomData)
                    end
                end
            end)
        end

        -- ========== ماتش ==========
        local function isInLobby()
            local ok, r = pcall(function()
                return GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() == true
            end)
            return ok and r == true
        end

        local function isInRealMatch()
            local ok, r = pcall(function()
                return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus() == true
            end)
            return ok and r == true
        end

        local function isInGamePlay()
            if isInLobby() then return false end
            if isInRealMatch() then return true end
            local ok, r = pcall(function()
                local SingleTrainTool = require("GameLua.Mod.SingleTraining.GamePlay.Data.SingleTrainTool")
                return SingleTrainTool.IsSelfInTraining and SingleTrainTool.IsSelfInTraining()
            end)
            if ok and r then return true end
            local char = getLocalChar()
            return char and slua.isValid(char) and slua.isValid(char.CharacterAvatarComp2_BP)
        end

        local function getPlayerController()
            local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok and GD and GD.GetPlayerController then
                local pc = GD.GetPlayerController()
                if pc and slua.isValid(pc) then return pc end
            end
            local pc = nil
            pcall(function()
                if slua_GameFrontendHUD and slua_GameFrontendHUD.GetPlayerController then
                    pc = slua_GameFrontendHUD:GetPlayerController()
                end
            end)
            return pc and slua.isValid(pc) and pc or nil
        end

        function getLocalChar()
            local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok and GD and GD.GetPlayerCharacter then
                local char = GD.GetPlayerCharacter()
                if char and slua.isValid(char) then return char end
            end
            local pc = getPlayerController()
            if pc then
                local char = nil
                pcall(function()
                    if pc.GetPlayerCharacterSafety then char = pc:GetPlayerCharacterSafety() end
                    if (not char or not slua.isValid(char)) and pc.GetPawn then char = pc:GetPawn() end
                    if (not char or not slua.isValid(char)) and pc.K2_GetPawn then char = pc:K2_GetPawn() end
                end)
                if char and slua.isValid(char) then return char end
            end
            return nil
        end

        local function notify(msg)
            if not DEBUG or isInMatchOrGame() then return end
            msg = "[AddOutfit] " .. tostring(msg)
            log(msg:gsub("^%[AddOutfit%] ", ""))
            pcall(function()
                if ShowNotice then ShowNotice(msg, false, 10) end
            end)
        end

        local function getDesiredOutfit()
            if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
                return tonumber(MATCH_CONFIG.outfitRes)
            end
            local cch = cache()
            if tonumber(cch.outfitRes) and cch.outfitRes > 0 then return cch.outfitRes end
            if tonumber(_G.AddOutfitLastLobbyOutfitRes) and _G.AddOutfitLastLobbyOutfitRes > 0 then
                return tonumber(_G.AddOutfitLastLobbyOutfitRes)
            end
            return nil
        end

        local function getWearSlotForResID(resID)
            resID = tonumber(resID)
            if not resID then return nil end
            local itemCfg = cfg(resID)
            if not itemCfg then return 3 end
            local st = tonumber(itemCfg.ItemSubType or itemCfg.itemSubType or 0)
            if st == 401 then return 1 end
            if st == 402 then return 2 end
            if st == 403 then return 3 end
            if st == 404 then return 4 end
            if st == 405 then return 5 end
            if st == 407 then return 6 end
            if st == 400 or st == 408 then return 9 end
            if st == 409 or st == 410 then return 10 end
            if getEquipSkinSlot(resID) then return nil end
            if weaponIdFromSkin(resID) then return nil end
            return 3
        end

        local function makeWearEntry(resID)
            local ENUM = ENUM_AVATAR_DATA_TYPE or { ItemID = 1, ColorID = 2, PatternID = 3 }
            return { [ENUM.ItemID] = resID, [ENUM.ColorID] = 0, [ENUM.PatternID] = 0 }
        end

        local function isApplySuccess(r) return r ~= false end

        local function refreshMatchAvatar(comp)
            if not slua.isValid(comp) then return end
            pcall(function() if comp.ProcessAvatarRectify then comp:ProcessAvatarRectify() end end)
            pcall(function() if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end end)
            pcall(function() if comp.RefreshAvatarReAttach then comp:RefreshAvatarReAttach() end end)
        end

        -- Ambil CharacterAvatarComp2 dengan beberapa nama field yang dipakai
        -- build berbeda (1.lua: getAvatarComponent2 / AvatarComponent2 / _BP).
        local function getAvatarComp2(char)
            if not char or not slua.isValid(char) then return nil end
            -- Bisa juga dipanggil dengan komponen avatar langsung.
            if char.NetAvatarData then return char end
            local comp
            pcall(function()
                if char.getAvatarComponent2 then comp = char:getAvatarComponent2() end
                if (not comp or not slua.isValid(comp)) and char.AvatarComponent2 then
                    comp = char.AvatarComponent2
                end
                if (not comp or not slua.isValid(comp)) and char.CharacterAvatarComp2_BP then
                    comp = char.CharacterAvatarComp2_BP
                end
            end)
            if comp and slua.isValid(comp) then return comp end
            return nil
        end

        -- SlotSyncData bisa berupa TArray UE (Num/Get/Set) atau tabel Lua.
        local function slotSyncArray(comp)
            if not comp or not slua.isValid(comp) then return nil end
            local net
            pcall(function() net = comp.NetAvatarData end)
            if not net and slua.IndexReference then
                pcall(function() net = slua.IndexReference(comp, "NetAvatarData") end)
            end
            if not net then return nil end
            local arr
            pcall(function() arr = net.SlotSyncData end)
            if not arr and slua.IndexReference then
                pcall(function() arr = slua.IndexReference(net, "SlotSyncData") end)
            end
            return arr
        end

        local function slotSyncCount(arr)
            local ok, n = pcall(function() return arr:Num() end)
            if ok and type(n) == "number" then return n, true end
            local count = 0
            for _ in pairs(arr) do count = count + 1 end
            return count, false
        end

        local function slotSyncGet(arr, i, hasNum)
            if hasNum then
                local ok, v = pcall(function() return arr:Get(i) end)
                if ok then return v end
                return nil
            end
            return arr[i]
        end

        local function slotSyncSet(arr, i, v, hasNum)
            if hasNum then
                pcall(function() arr:Set(i, v) end)
            else
                arr[i] = v
            end
        end

        -- Tulis skin ke SlotSyncData karakter in-match. Ini jalur yang benar-
        -- benar mengganti item asli: avatar match dibangun dari data ini,
        -- sedangkan PutOnCustomEquipmentByID hanya untuk avatar lobby.
        local function setSlotSyncSkin(comp, resID, slotID)
            resID, slotID = tonumber(resID), tonumber(slotID)
            if not comp or not resID or resID <= 0 or not slotID then return false end
            local changed, found = false, false
            pcall(function()
                local arr = slotSyncArray(comp)
                if not arr then return end
                local n, hasNum = slotSyncCount(arr)
                local first = hasNum and 0 or 1
                local last = hasNum and (n - 1) or n
                for i = first, last do
                    local e = slotSyncGet(arr, i, hasNum)
                    if e and tonumber(e.SlotID) == slotID then
                        found = true
                        local cur = tonumber(e.ItemId) or tonumber(e.ItemID) or 0
                        if cur ~= resID then
                            pcall(function() e.ItemId = resID end)
                            pcall(function() if e.ItemID ~= nil then e.ItemID = resID end end)
                            pcall(function() if e.FakeItemID ~= nil then e.FakeItemID = resID end end)
                            slotSyncSet(arr, i, e, hasNum)
                            changed = true
                        end
                        break
                    end
                end
                if not found then
                    local entry
                    pcall(function() entry = import("AvatarSyncData")() end)
                    if entry then
                        pcall(function()
                            entry.SlotID = slotID
                            entry.ItemId = resID
                            entry.ItemID = resID
                            entry.FakeItemID = resID
                            local op = import("ESyncOperation")
                            entry.OperationType = (op and op.PutOn) or 0
                        end)
                        local okAdd = pcall(function() arr:Add(entry) end)
                        if not okAdd then pcall(function() table.insert(arr, entry) end) end
                        changed = true
                    end
                end
            end)
            if changed and comp.OnRep_BodySlotStateChanged then
                pcall(function() comp:OnRep_BodySlotStateChanged() end)
            end
            return changed or found
        end

        local function clothSlotID(resID)
            local st = subType(cfg(resID))
            if st == 401 then return 3 end
            if st == 402 then return 4 end
            if st == 403 then return 5 end
            if st == 404 then return 6 end
            if st == 405 then return 7 end
            if st == 407 then return 12 end
            if st == 452 then return 16 end
            return nil
        end

        -- Slot pakaian yang diminta cache (outfit full suit + potongan lain).
        local function desiredClothSlots()
            local cch = cache()
            local out = {}
            local suit = tonumber(cch.outfitRes)
            local fullSuit = false
            if suit and suit > 0 then
                out[5] = suit
                fullSuit = isFullSuitRes(suit)
            end
            for resID in pairs(cch.clothes or {}) do
                resID = tonumber(resID)
                if resID and resID > 0 then
                    local slot = clothSlotID(resID)
                    if slot then
                        if slot ~= 5 then
                            out[slot] = out[slot] or resID
                        elseif not fullSuit then
                            out[5] = out[5] or resID
                        end
                    end
                end
            end
            return out
        end

        _G.AddOutfitSetSlotSkin = setSlotSyncSkin
        _G.AddOutfitDesiredClothSlots = desiredClothSlots

        local function applyItemToMatchAvatar(comp, resID)
            if not slua.isValid(comp) or not resID or not isInjectedRes(resID) then return false end
            resID = tonumber(resID)
            local applied = false
            pcall(function()
                comp.bSyncAvatar = false
                comp.forceLodMode = true
                comp.bIsLobbyAvatar = false
            end)
            local AvatarData = require("client.logic.data.AvatarData")
            local wearEntry = makeWearEntry(resID)
            local AData = AvatarData.ConvertToAvatarCustom and AvatarData.ConvertToAvatarCustom(wearEntry)
                or AvatarData.CreateAvatarCustom(resID, 0, 0)
            pcall(function()
                if comp.PutOnEquipmentByResID then
                    local r = comp:PutOnEquipmentByResID(AData.ItemID or resID, AData)
                    if isApplySuccess(r) then applied = true end
                end
            end)
            if not applied then
                pcall(function()
                    if comp.PutOnCustomEquipmentByID then
                        local r = comp:PutOnCustomEquipmentByID(resID, AData)
                        if isApplySuccess(r) then applied = true end
                    end
                end)
            end
            if not applied then
                pcall(function()
                    local ItemDefineID = FItemDefineID(4, resID)
                    local EAvatarCustomType = import("EAvatarCustomType")
                    local AvatarCustom = FAvatarCustomDefault()
                    AvatarCustom.CustomType = EAvatarCustomType.AvatarCustomCharacter
                    local r = comp:HandleEquipItem(ItemDefineID, AvatarCustom)
                    if isApplySuccess(r) then applied = true end
                end)
            end
            if applied then refreshMatchAvatar(comp) end
            return applied
        end

        local function applyClothToComp(comp, resID)
            if not slua.isValid(comp) then return false end
            local ok = false
            pcall(function()
                if comp.PutOnCustomEquipmentByID then
                    local r = comp:PutOnCustomEquipmentByID(resID)
                    if isApplySuccess(r) then ok = true end
                end
            end)
            if ok then return true end
            return applyItemToMatchAvatar(comp, resID)
        end

        local function matchApplyOutfit(char)
            syncWeaponCacheFromLobby()
            syncClothesCacheFromLobby()
            local comp = getAvatarComp2(char)
            if not comp then return false end

            local slots = desiredClothSlots()
            if next(slots) == nil then return false end
            local applied = false
            local syncOk = false

            -- Jalur utama in-match: tulis SlotSyncData per slot. Tanpa ini
            -- karakter tetap memakai item asli walau lobby sudah berubah.
            for slotID, resID in pairs(slots) do
                if setSlotSyncSkin(comp, resID, slotID) then
                    syncOk = true
                    applied = true
                end
            end

            -- Fallback kalau SlotSyncData tidak bisa diakses sama sekali.
            if not syncOk then
                for _, resID in pairs(slots) do
                    if applyClothToComp(comp, resID) then applied = true end
                end
            end

            if applied then refreshMatchAvatar(comp) end
            return applied
        end

        -- Jalur visual yang sama dipakai lobby (1.lua applyLobbySkins) dan
        -- match. Tidak butuh ins/depot, hanya SlotSyncData.
        _G.AddOutfitApplyAvatar = function(char)
            return matchApplyOutfit(char or getLocalChar())
        end

        local _lastPatchTime = 0
        local function patchPlayerInfoForMatch(PlayerInfo)
            if not PlayerInfo then return end
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastPatchTime) < 1.0 then return end  -- throttle: max once per second
            _lastPatchTime = now
            snapshotLobbyWear()
            local cch = cache()
            if cch.equip.bag then PlayerInfo.bag_skin = cch.equip.bag end
            if cch.equip.helmet then PlayerInfo.helmet_skin = cch.equip.helmet end
            if cch.equip.armor then PlayerInfo.armor_skin = cch.equip.armor end
-- @RAHMANYVI
            local idx = tonumber(PlayerInfo.use_rolewear) or 1
            PlayerInfo.use_rolewear = idx
            PlayerInfo.all_knapsack_ext_info = PlayerInfo.all_knapsack_ext_info or {}
            PlayerInfo.all_knapsack_ext_info[idx] = PlayerInfo.all_knapsack_ext_info[idx] or {}
            local ext = PlayerInfo.all_knapsack_ext_info[idx]
            if cch.equip.bag then
                local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                local bagLists = buildEquipSkinLists(catalogBag)
                ext.bag_skin = catalogBag
                ext.bag_skin_list = bagLists
                PlayerInfo.bag_skin = catalogBag
            end
            if cch.equip.helmet then
                local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                local helmLists = buildEquipSkinLists(catalogHelm)
                ext.helmet_skin = catalogHelm
                ext.helmet_skin_list = helmLists
                PlayerInfo.helmet_skin = catalogHelm
            end
            if cch.equip.armor then ext.armor_skin = cch.equip.armor end
            if cch.equip.parachute and cch.equip.parachute > 0 then
                ext.parachute = cch.equip.parachuteIns or cch.equip.parachute
            end
            if cch.equip.glider and cch.equip.glider > 0 then
                ext.gliding = cch.equip.glider
            end

            pcall(function()
                if cch.throwObjects then
                    local throwList = {}
                    for st, info in pairs(cch.throwObjects) do
                        if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                            throwList[st] = info.resID
                        end
                    end
                    if next(throwList) then
                        local function applyThrowList(kext)
                            if not kext then return end
                            kext.throw_object_list = kext.throw_object_list or {}
                            for st, resID in pairs(throwList) do
                                kext.throw_object_list[st] = resID
                            end
                        end
                        applyThrowList(ext)
                        applyThrowList(PlayerInfo.knapsack_ext_info)
                        PlayerInfo.all_knapsack_ext_info = PlayerInfo.all_knapsack_ext_info or {}
                        for i = 1, 6 do
                            PlayerInfo.all_knapsack_ext_info[i] = PlayerInfo.all_knapsack_ext_info[i] or {}
                            applyThrowList(PlayerInfo.all_knapsack_ext_info[i])
                        end
                        for i, kext in pairs(PlayerInfo.all_knapsack_ext_info) do
                            applyThrowList(kext)
                        end
                        log("patchPlayerInfoForMatch: throw_object_list injected into all knapsack entries")
                    end
                end
            end)

            pcall(function()
                if DataMgr and DataMgr.VehicleSlotList then
                    PlayerInfo.vst_in_battle = PlayerInfo.vst_in_battle or {}
                    for subType, insList in pairs(DataMgr.VehicleSlotList) do
                        if insList and type(insList) == "table" then
                            local resList = {}
                            for i, insID in ipairs(insList) do
                                insID = tonumber(insID)
                                if insID and insID > 0 then
                                    local resID
                                    if isInjectedIns(insID) then
                                        resID = R.insToRes[insID]
                                    else
                                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                        local d = wd:GetHallDepotItemDataByInsID(insID)
                                        resID = d and tonumber(d.resID)
                                    end
                                    if resID and resID > 0 then
                                        resList[#resList + 1] = resID
                                    end
                                end
                            end
                            if #resList > 0 then
                                PlayerInfo.vst_in_battle[subType] = resList
                            end
                        end
                    end
                    if DataMgr.vst_skin then
                        local skinIns = tonumber(DataMgr.vst_skin)
                        if skinIns and skinIns > 0 then
                            local skinRes
                            if isInjectedIns(skinIns) then
                                skinRes = R.insToRes[skinIns]
                            else
                                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                local d = wd:GetHallDepotItemDataByInsID(skinIns)
                                skinRes = d and tonumber(d.resID)
                            end
                            if skinRes and skinRes > 0 then
                                PlayerInfo.vst_skin = skinRes
                            end
                        end
                    end
                end
            end)
        end

        local _lastApplyEquipToController = 0
        local function applyMatchEquipAvatarToController()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastApplyEquipToController) < 0.3 then return false end  -- throttle: max 3x/sec
            _lastApplyEquipToController = now
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local cch = cache()
            if not cch.equip.bag and not cch.equip.helmet and not cch.equip.armor and not cch.equip.parachute and not cch.equip.glider then return false end

            local char = getLocalChar()
            local eq = pc.InitialEquipmentAvatar or {}

            -- طبّق سكن الشنطة فقط لو اللاعب لابس شنطة فعلاً
            if cch.equip.bag and cch.equip.bag > 0 and isWearingEquip(char, "bag") then
                local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                local bagLists = buildEquipSkinLists(catalogBag)
                eq.BagAvatar = catalogBag
                eq.BagAvatarList = bagLists
                local realBagId = getCharEquipLevel(char, 8) or 0
                local bagLevel
                if realBagId > 0 and isBaseEquipItemId(realBagId) then
                    bagLevel = detectEquipLevelFromBaseId(realBagId, catalogBag)
                elseif realBagId > 0 then
                    bagLevel = detectLevelFromEquipRes(realBagId)
                end
                bagLevel = bagLevel or getEquipDisplayLevel(cch.equip.bag, "bag")
                local bagDisplay = mapEquipSkinRes(catalogBag, bagLevel)
                if bagDisplay > 0 then eq.BagAvatar = bagDisplay end
            else
                eq.BagAvatar = 0
                eq.BagAvatarList = nil
            end
            -- طبّق سكن الخوذة فقط لو اللاعب لابس خوذة فعلاً
            if cch.equip.helmet and cch.equip.helmet > 0 and isWearingEquip(char, "helmet") then
                local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                local helmLists = buildEquipSkinLists(catalogHelm)
                eq.HelmetAvatar = catalogHelm
                eq.HelmetAvatarList = helmLists
                local realHelmId = getCharEquipLevel(char, 9) or 0
                local helmLevel
                if realHelmId > 0 and isBaseEquipItemId(realHelmId) then
                    helmLevel = detectEquipLevelFromBaseId(realHelmId, catalogHelm)
                elseif realHelmId > 0 then
                    helmLevel = detectLevelFromEquipRes(realHelmId)
                end
                helmLevel = helmLevel or getEquipDisplayLevel(cch.equip.helmet, "helmet")
                local helmDisplay = mapEquipSkinRes(catalogHelm, helmLevel)
                if helmDisplay > 0 then eq.HelmetAvatar = helmDisplay end
            else
                eq.HelmetAvatar = 0
                eq.HelmetAvatarList = nil
            end
            if cch.equip.armor then eq.ArmorAvatar = cch.equip.armor end
            if cch.equip.parachute and cch.equip.parachute > 0 then
                eq.ParachuteAvatar = cch.equip.parachute
            end
            if cch.equip.glider and cch.equip.glider > 0 then
                eq.GliderAvatar = cch.equip.glider
            end

            pc.InitialEquipmentAvatar = eq
            pcall(function()
                if slua.isValid(pc.PlayerState) and pc.PlayerState.MetroPlayerStateAvatarFeature then
                    pc.PlayerState.MetroPlayerStateAvatarFeature.InitialEquipmentAvatar = eq
                end
            end)
            pcall(function()
                local comp = char and char.CharacterAvatarComp2_BP
                if slua.isValid(comp) and comp.GetEquipmentSkinItemID then
                    if cch.equip.helmet and isWearingEquip(char, "helmet") then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.helmet) end)
                    end
                    if cch.equip.bag and isWearingEquip(char, "bag") then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.bag) end)
                    end
                    if cch.equip.parachute and isWearingEquip(char, "parachute") then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.parachute) end)
                    end
                    if cch.equip.glider and cch.equip.glider > 0 then
                        pcall(function() comp:GetEquipmentSkinItemID(cch.equip.glider) end)
                    end
                end
            end)
            pcall(function()
                if pc.OnEquipmentAvatarChange and pc.OnEquipmentAvatarChange.Broadcast then
                    pc.OnEquipmentAvatarChange:Broadcast()
                end
            end)
            notify("معدات: خوذة=" .. tostring(eq.HelmetAvatar) .. " شنطة=" .. tostring(eq.BagAvatar))
            return true
        end

        local function hookEquipMapping()
            pcall(function()
                if DataMgr and not DataMgr._lava_equip_map_hooked then
                    DataMgr._lava_equip_map_hooked = true
                    local orig = DataMgr.GetEquipmentItemIDByResID
                    DataMgr.GetEquipmentItemIDByResID = function(level, itemResID)
                        level, itemResID = tonumber(level) or 3, tonumber(itemResID)
                        local catalogRes = normalizeEquipCatalogRes(itemResID)
                        local r = orig(level, catalogRes)
                        if r and r > 0 then return r end
                        if isInjectedIns(itemResID) then
                            return mapEquipSkinRes(normalizeEquipCatalogRes(R.insToRes[itemResID]), level)
                        end
                        if isInjectedRes(itemResID) then
                            return mapEquipSkinRes(catalogRes, level)
                        end
                        return r or 0
                    end
                end
            end)
            pcall(function()
                local lav = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
                if lav._lava_skinins_hooked then return end
                lav._lava_skinins_hooked = true
                local orig2 = lav.GetEquipmentItemIDBySkinInsID
                lav.GetEquipmentItemIDBySkinInsID = function(self, itemSubType, itemInsID)
                    local level = lav.GetEquipmentItemShowLevel(lav, itemSubType)
                    local r = orig2(self, itemSubType, itemInsID)
                    if r and r > 0 then return r end
                    itemInsID = tonumber(itemInsID)
                    if isInjectedIns(itemInsID) then
                        return mapEquipSkinRes(normalizeEquipCatalogRes(R.insToRes[itemInsID]), level)
                    end
                    pcall(function()
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetHallDepotItemDataByInsID(itemInsID)
                        if d and isInjectedRes(d.resID) then
                            return mapEquipSkinRes(normalizeEquipCatalogRes(d.resID), level)
                        end
                    end)
                    return r
                end
            end)
            pcall(function()
                local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
                if CAC._lava_equip_skin_hooked then return end
                CAC._lava_equip_skin_hooked = true
                local orig3 = CAC.GetEquipmentSkinItemID
                CAC.GetEquipmentSkinItemID = function(self, InItemID)
                    -- Skip non-local player equipment to avoid lag
                    if self.IsSelf and not self:IsSelf() then
                        return orig3(self, InItemID)
                    end
                    local cch = cache()
                    InItemID = tonumber(InItemID) or 0

                    local function tryGetSkin(catalogRes)
                        if not catalogRes or catalogRes <= 0 then return 0 end
                        catalogRes = normalizeEquipCatalogRes(catalogRes)
                        local skin = resolveMatchEquipSkin(catalogRes, InItemID)
                        if skin > 0 then return skin end
                        for lvl = 1, 3 do
                            local s = mapEquipSkinRes(catalogRes, lvl)
                            if s > 0 then return s end
                        end
                        return 0
                    end

                    if InItemID > 0 and isBaseEquipItemId(InItemID) then
                        local isHelmetBase = GAME_HELMET_LEVEL[InItemID] ~= nil
                            or (InItemID >= 1505000001 and InItemID <= 1505000100)
                            or (InItemID >= 502001 and InItemID <= 502999)
                        local isBagBase = GAME_BAG_LEVEL[InItemID] ~= nil
                            or (InItemID >= 501001 and InItemID <= 501999)
                            or (InItemID >= 1501000000 and InItemID < 1502000000)

                        local char = getLocalChar()
                        if isHelmetBase and cch.equip.helmet and cch.equip.helmet > 0 then
                            if char and isWearingEquip(char, "helmet") then
                                local skin = tryGetSkin(cch.equip.helmet)
                                if skin > 0 then return skin end
                            end
                        end
                        if isBagBase and cch.equip.bag and cch.equip.bag > 0 then
                            if char and isWearingEquip(char, "bag") then
                                local skin = tryGetSkin(cch.equip.bag)
                                if skin > 0 then return skin end
                            end
                        end
                    end

                    local origResult = orig3(self, InItemID)
                    if origResult and origResult > 0 and origResult ~= InItemID then
                        return origResult
                    end

                    -- fallback مع تحقق isWearingEquip
                    local isHelmetQuery = GAME_HELMET_LEVEL[InItemID] ~= nil or (InItemID >= 502001 and InItemID <= 502999)
                    local isBagQuery = GAME_BAG_LEVEL[InItemID] ~= nil or (InItemID >= 501001 and InItemID <= 501999)
                    local char = getLocalChar()

                    if isHelmetQuery and cch.equip.helmet and cch.equip.helmet > 0 then
                        if char and isWearingEquip(char, "helmet") then
                            local skin = tryGetSkin(cch.equip.helmet)
                            if skin > 0 then return skin end
                        end
                    end
                    if isBagQuery and cch.equip.bag and cch.equip.bag > 0 then
                        if char and isWearingEquip(char, "bag") then
                            local skin = tryGetSkin(cch.equip.bag)
                            if skin > 0 then return skin end
                        end
                    end
                    return origResult
                end
                local origEquipFinish = CAC.OnAvatarEquipFinish
                CAC.OnAvatarEquipFinish = function(self, slotType, isEquipped, itemID)
                    if origEquipFinish then origEquipFinish(self, slotType, isEquipped, itemID) end
                    if not isEquipped then return end
                    -- Only process local player equipment to avoid lag
                    if not self.IsSelf or not self:IsSelf() then return end
                    pcall(function()
                        if self.IsLobbyActor and self:IsLobbyActor() then return end
                        local EAvatarSlotType = import("EAvatarSlotType")
                        local cch = cache()
                        local isHelmet = slotType == EAvatarSlotType.EAvatarSlotType_HelmetEquipemtSlot
                        local isBag = slotType == EAvatarSlotType.EAvatarSlotType_BackpackEquipemtSlot
                        if (isHelmet and cch.equip.helmet and cch.equip.helmet > 0)
                            or (isBag and cch.equip.bag and cch.equip.bag > 0) then
                            local owner = self.GetOwner and self:GetOwner()
                            if owner and slua.isValid(owner) and owner.AddGameTimer then
                                owner:AddGameTimer(0.25, false, function()
                                    if slua.isValid(owner) then matchApplyEquipSkins(owner) end
                                end)
                            end
                        end
                        applyMatchEquipAvatarToController()
                    end)
                end
            end)
        end

        local function applyMatchEquipSkinAtLevel(comp, catalogResID, level)
            if not slua.isValid(comp) or not catalogResID or catalogResID <= 0 then return false end
            catalogResID = normalizeEquipCatalogRes(catalogResID)
            level = tonumber(level) or 3
            local skinId = mapEquipSkinRes(catalogResID, level)
            if not skinId or skinId <= 0 then skinId = catalogResID end
            local ok = false
            pcall(function()
                if comp.PutOnCustomEquipmentByID then
                    local r = comp:PutOnCustomEquipmentByID(skinId)
                    if isApplySuccess(r) then ok = true end
                end
            end)
            if not ok then
                pcall(function()
                    local r = comp:HandleEquipItem(FItemDefineID(4, skinId), FAvatarCustomDefault())
                    if isApplySuccess(r) then ok = true end
                end)
            end
            if ok then refreshMatchAvatar(comp) end
            return ok
        end

            -- أضف الدالة دي قبل matchApplyEquipSkins
        local function getCharEquipLevel(char, slotID)
            local found = nil
            slotID = tonumber(slotID)
            if not slotID then return nil end
            pcall(function()
                local comp = getAvatarComp2(char)
                if not comp then return end
                local arr = slotSyncArray(comp)
                if not arr then return end
                local n, hasNum = slotSyncCount(arr)
                local first = hasNum and 0 or 1
                local last = hasNum and (n - 1) or n
                for i = first, last do
                    local e = slotSyncGet(arr, i, hasNum)
                    if e and tonumber(e.SlotID) == slotID then
                        local itemID = tonumber(e.ItemId) or tonumber(e.ItemID) or 0
                        if itemID > 0 then found = itemID end
                        break
                    end
                end
            end)
            return found
        end

        _G.AddOutfitGetCharEquipLevel = getCharEquipLevel

        local function isWearingEquip(char, slot)
            local slotID = (slot == "helmet") and 9 or (slot == "bag") and 8 or (slot == "parachute") and 11 or (slot == "glider") and 15 or nil
            if not slotID then return false end

-- @RAHMANYVI
            local itemID = getCharEquipLevel(char, slotID)
            if itemID and itemID > 0 then return true end

-- @RAHMANYVI
            local wearing = false
            pcall(function()
                local pc = getPlayerController()
                if not pc or not slua.isValid(pc) then return end
                if pc.PlayerState and pc.PlayerState.MetroPlayerStateAvatarFeature then
                    local psEquip = pc.PlayerState.MetroPlayerStateAvatarFeature.EquipmentAvatarData
                    if psEquip then
                        if slot == "helmet" and psEquip.HelmetAvatar and psEquip.HelmetAvatar > 0 then
                            wearing = true
                        elseif slot == "bag" and psEquip.BagAvatar and psEquip.BagAvatar > 0 then
                            wearing = true
                        end
                    end
                end
            end)
            return wearing
        end

        local _lastMatchApplyEquip = 0
        local function matchApplyEquipSkins(char)
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastMatchApplyEquip) < 0.5 then return false end  -- -- @RAHMANYVI
            _lastMatchApplyEquip = now
            local cch = cache()
            if not cch.equip.bag and not cch.equip.helmet and not cch.equip.parachute and not cch.equip.glider then return false end
            local comp = char and char.CharacterAvatarComp2_BP
            if not slua.isValid(comp) then return false end
            local ok = false

            if cch.equip.helmet and cch.equip.helmet > 0 then
                if isWearingEquip(char, "helmet") then
                    local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                    local realHelmId = getCharEquipLevel(char, 9) or 0
                    local helmLevel
                    if realHelmId > 0 and isBaseEquipItemId(realHelmId) then
                        helmLevel = detectEquipLevelFromBaseId(realHelmId, catalogHelm)
                    elseif realHelmId > 0 then
                        helmLevel = detectLevelFromEquipRes(realHelmId)
                    end
                    helmLevel = helmLevel or getEquipDisplayLevel(cch.equip.helmet, "helmet")
                    if applyMatchEquipSkinAtLevel(comp, catalogHelm, helmLevel) then
                        ok = true
                        notify("خوذة ماتش OK " .. mapEquipSkinRes(catalogHelm, helmLevel))
                    end
                end
            end

            if cch.equip.bag and cch.equip.bag > 0 then
                if isWearingEquip(char, "bag") then
                    local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                    local realBagId = getCharEquipLevel(char, 8) or 0
                    local bagLevel
                    if realBagId > 0 and isBaseEquipItemId(realBagId) then
                        bagLevel = detectEquipLevelFromBaseId(realBagId, catalogBag)
                    elseif realBagId > 0 then
                        bagLevel = detectLevelFromEquipRes(realBagId)
                    end
                    bagLevel = bagLevel or getEquipDisplayLevel(cch.equip.bag, "bag")
                    if applyMatchEquipSkinAtLevel(comp, catalogBag, bagLevel) then
                        ok = true
                        notify("شنطة ماتش OK " .. mapEquipSkinRes(catalogBag, bagLevel))
                    end
                end
            end

            if cch.equip.parachute and cch.equip.parachute > 0 then
                if isWearingEquip(char, "parachute") then
                    local paraResID = cch.equip.parachute
                    pcall(function()
                        if comp.PutOnCustomEquipmentByID then
                            local r = comp:PutOnCustomEquipmentByID(paraResID)
                            if isApplySuccess(r) then
                                ok = true
                                notify("براشوت ماتش OK " .. tostring(paraResID))
                            end
                        end
                    end)
                    if not ok then
                        pcall(function()
                            local r = comp:HandleEquipItem(FItemDefineID(4, paraResID), FAvatarCustomDefault())
                            if isApplySuccess(r) then
                                ok = true
                                notify("براشوت ماتش OK " .. tostring(paraResID))
                            end
                        end)
                    end
                end
            end

            if cch.equip.glider and cch.equip.glider > 0 then
                local gliderResID = cch.equip.glider
                pcall(function()
                    if comp.PutOnCustomEquipmentByID then
                        local r = comp:PutOnCustomEquipmentByID(gliderResID)
                        if isApplySuccess(r) then
                            ok = true
                            notify("جلايدر ماتش OK " .. tostring(gliderResID))
                        end
                    end
                end)
                if not ok then
                    pcall(function()
                        local r = comp:HandleEquipItem(FItemDefineID(4, gliderResID), FAvatarCustomDefault())
                        if isApplySuccess(r) then
                            ok = true
                            notify("جلايدر ماتش OK " .. tostring(gliderResID))
                        end
                    end)
                end
            end

-- @RAHMANYVI
            applyMatchEquipAvatarToController()

-- @RAHMANYVI
            pcall(function()
                local NetAvatarData = slua.IndexReference(comp, "NetAvatarData")
                if not NetAvatarData then return end
                local TempSlotSyncData = slua.IndexReference(NetAvatarData, "SlotSyncData")
                if not TempSlotSyncData then return end

                for Index, AvatarSynData in pairs(TempSlotSyncData) do
                    local slotID = AvatarSynData.SlotID
                    local NDRid = AvatarSynData.ItemID

                    if slotID == 8 and NDRid ~= 0 and cch.equip.bag and cch.equip.bag > 0 then
                        local catalogBag = normalizeEquipCatalogRes(cch.equip.bag)
                        local bagLevel
                        if isBaseEquipItemId(NDRid) then
                            bagLevel = detectEquipLevelFromBaseId(NDRid, catalogBag)
                        else
                            bagLevel = detectLevelFromEquipRes(NDRid)
                        end
                        bagLevel = bagLevel or getEquipDisplayLevel(cch.equip.bag, "bag")
                        local skinId = mapEquipSkinRes(catalogBag, bagLevel)
                        if skinId <= 0 then skinId = mapEquipSkinRes(catalogBag, 3) end
                        if skinId > 0 and NDRid ~= skinId then
                            AvatarSynData.ItemID = skinId
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

                    if slotID == 9 and NDRid ~= 0 and cch.equip.helmet and cch.equip.helmet > 0 then
                        local catalogHelm = normalizeEquipCatalogRes(cch.equip.helmet)
                        local helmLevel
                        if isBaseEquipItemId(NDRid) then
                            helmLevel = detectEquipLevelFromBaseId(NDRid, catalogHelm)
                        else
                            helmLevel = detectLevelFromEquipRes(NDRid)
                        end
                        helmLevel = helmLevel or getEquipDisplayLevel(cch.equip.helmet, "helmet")
                        local skinId = mapEquipSkinRes(catalogHelm, helmLevel)
                        if skinId <= 0 then skinId = mapEquipSkinRes(catalogHelm, 3) end
                        if skinId > 0 and NDRid ~= skinId then
                            AvatarSynData.ItemID = skinId
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

-- @RAHMANYVI
                    if slotID == 11 and NDRid ~= 0 and cch.equip.parachute and cch.equip.parachute > 0 then
                        local paraResID = cch.equip.parachute
                        if NDRid ~= paraResID then
                            AvatarSynData.ItemID = paraResID
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end

                    -- جلايدر - SlotID 15 (GlideEquipmtSlot)
                    if slotID == 15 and NDRid ~= 0 and cch.equip.glider and cch.equip.glider > 0 then
                        local gliderResID = cch.equip.glider
                        if NDRid ~= gliderResID then
                            AvatarSynData.ItemID = gliderResID
                            slua.IndexReference(NetAvatarData, "SlotSyncData"):Set(Index, AvatarSynData)
                            ok = true
                        end
                    end
                end

                if ok and comp.OnRep_BodySlotStateChanged then
                    comp:OnRep_BodySlotStateChanged()
                end
            end)
            return ok
        end

        local function hookPlayerWearingDone()
            pcall(function()
                local pc = getPlayerController()
                if not pc or not slua.isValid(pc) or pc._lava_wear_done_hooked then return end
                pc._lava_wear_done_hooked = true
                if pc.OnPlayerChangeWearingDone and pc.OnPlayerChangeWearingDone.Add then
                    pc.OnPlayerChangeWearingDone:Add(function()
                        applyMatchEquipAvatarToController()
                        local char = getLocalChar()
                        if char then
                            pcall(matchApplyOutfit, char)
                            char:AddGameTimer(0.2, false, function()
                                if slua.isValid(char) then
                                    pcall(matchApplyOutfit, char)
                                    matchApplyEquipSkins(char)
                                end
                            end)
                        end
                    end)
                end
            end)
        end

        local function hookCommerAvatarData()
            pcall(function()
                local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
                if CommerAvatarDataUtil._lava_hooked_equip then return end
                CommerAvatarDataUtil._lava_hooked_equip = true
                local orig = CommerAvatarDataUtil.GeneratePlayerAvatarData
                CommerAvatarDataUtil.GeneratePlayerAvatarData = function(self, PlayerInfo, uPlayerController, ...)
                    -- Skip expensive operations for non-local players
                    local localPC = getPlayerController()
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        pcall(function() patchPlayerInfoForMatch(PlayerInfo) end)
                    end
                    orig(self, PlayerInfo, uPlayerController, ...)
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        applyMatchEquipAvatarToController()
                    end
                end
            end)
        end

        local function hookMatchAvatarData()
            hookCommerAvatarData()
            pcall(function()
                local AvatarDataUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
                if AvatarDataUtil._lava_hooked_gen then return end
                AvatarDataUtil._lava_hooked_gen = true
                local origGet = AvatarDataUtil.GetPlayerInfo
                AvatarDataUtil.GetPlayerInfo = function(uPlayerController)
                    local pi = origGet(uPlayerController)
                    -- Only patch for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if pi and uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        patchPlayerInfoForMatch(pi)
                    end
                    return pi
                end
                local origGen = AvatarDataUtil.GeneratePlayerAvatarData
                AvatarDataUtil.GeneratePlayerAvatarData = function(uPlayerController)
                    -- Only patch for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        pcall(function()
                            local PlayerInfo = AvatarDataUtil.GetPlayerInfo(uPlayerController)
                            if PlayerInfo then patchPlayerInfoForMatch(PlayerInfo) end
                        end)
                    end
                    origGen(uPlayerController)
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        applyMatchEquipAvatarToController()
                    end
                    return
                end
                local origInit = AvatarDataUtil.InitialEquipmentAvatar
                AvatarDataUtil.InitialEquipmentAvatar = function(PlayerInfo, uPlayerController)
                    -- Only patch for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        pcall(function() patchPlayerInfoForMatch(PlayerInfo) end)
                    end
                    origInit(PlayerInfo, uPlayerController)
                    if uPlayerController and slua.isValid(uPlayerController) and uPlayerController == localPC then
                        applyMatchEquipAvatarToController()
                    end
                end
            end)
        end

        local function hookClassMethod(classModule, methodName, hookTag, newFunc)
            if not classModule then log("hookClassMethod: nil classModule for", methodName) return false end
            local impl = classModule.__inner_impl
            if not impl then log("hookClassMethod: no __inner_impl for", methodName) return false end
            if impl[hookTag] then log("hookClassMethod: already hooked", methodName) return false end
            local orig = impl[methodName]
            if not orig then log("hookClassMethod: no orig method", methodName) return false end
            impl[hookTag] = true
            impl[methodName] = function(...)
                return newFunc(orig, ...)
            end
            pcall(function() rawset(classModule, methodName, nil) end)
            -- log("hookClassMethod: hooked", methodName)
            return true
        end

        local function hookGrenadeAvatarInit()
            pcall(function()
                local PCB = require("GameLua.GameCore.Framework.PlayerControllerBase")
                -- log suppressed
                hookClassMethod(PCB, "InitGrenadeAvatarList", "_lava_hooked_grenade_init", function(orig, self, ReInitial)
                    orig(self, ReInitial)
                    -- Only inject for local player to avoid lag when enemies appear
                    local localPC = getPlayerController()
                    if not localPC or self ~= localPC then return end
                    if ReInitial then
                        pcall(function()
                            local cch = cache()
                            if cch.throwObjects and self.AddToGrenadeAvatarItemList then
                                for st, info in pairs(cch.throwObjects) do
                                    if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                                        self:AddToGrenadeAvatarItemList(info.resID)
                                    end
                                end
                            end
                        end)
                    end
                end)
            end)
        end

        local function applyGrenadeSkinsToController()
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local cch = cache()
            if not cch.throwObjects then return false end
            local hasThrow = false
            for _, info in pairs(cch.throwObjects) do
                if info.resID and info.resID > 0 then hasThrow = true break end
            end
            if not hasThrow then return false end
            pcall(function()
                if pc.AddToGrenadeAvatarItemList then
                    for st, info in pairs(cch.throwObjects) do
                        if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                            pc:AddToGrenadeAvatarItemList(info.resID)
                        end
                    end
                end
                if pc.OnWeaponAvatarUpdate then
                    pc:OnWeaponAvatarUpdate()
                end
                local char = getLocalChar()
                if char and slua.isValid(char) then
                    local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
                    if slua.isValid(curWeapon) then
                        local wid = 0
                        pcall(function() wid = curWeapon:GetWeaponID() end)
                        if wid >= 602001 and wid <= 602004 then
                            log("applyGrenadeSkinsToController: held grenade wid=", wid)
                            if curWeapon.DelayHandleAvatarMeshChanged then
                                curWeapon:DelayHandleAvatarMeshChanged()
                            end
                            if curWeapon.HandleAvatarMeshChanged then
                                curWeapon:HandleAvatarMeshChanged()
                            end
                            local GRENADE_WID_TO_SUB = {
                                [602001] = 614, [602002] = 613,
                                [602003] = 615, [602004] = 612,
                            }
                            local sub = GRENADE_WID_TO_SUB[wid]
                            local info = sub and cch.throwObjects[sub]
                            if info and info.resID and info.resID > 0 then
                                if slua.isValid(curWeapon.GrenadeAvatarComponent_BP) then
                                    curWeapon.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                                    log("applyGrenadeSkinsToController: ChangeItemAvatar on held weapon", info.resID)
                                end
                                if curWeapon.AddGameTimer then
                                    curWeapon:AddGameTimer(0.1, false, function()
                                        pcall(function()
                                            if slua.isValid(curWeapon) and slua.isValid(curWeapon.GrenadeAvatarComponent_BP) then
                                                curWeapon.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                                            end
                                        end)
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
            return true
        end

        -- Simplified: only hook TryGetGrenadeAvatarID (lightweight), 
        -- skip per-grenade-class GetAvatarID hooks (heavy, fire for all players)
        local function hookGrenadeAvatarLookup()
            pcall(function()
                local AvatarDataUtil = require("GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil")
                if AvatarDataUtil and not AvatarDataUtil._lava_hooked_try_get then
                    AvatarDataUtil._lava_hooked_try_get = true
                    local origTry = AvatarDataUtil.TryGetGrenadeAvatarID
                    if origTry then
                        AvatarDataUtil.TryGetGrenadeAvatarID = function(uPlayerController, ItemID)
                            local cch = cache()
                            if cch.throwObjects then
                                if ItemID == 602001 and cch.throwObjects[614] and cch.throwObjects[614].resID and cch.throwObjects[614].resID > 0 then
                                    return cch.throwObjects[614].resID
                                elseif ItemID == 602002 and cch.throwObjects[613] and cch.throwObjects[613].resID and cch.throwObjects[613].resID > 0 then
                                    return cch.throwObjects[613].resID
                                elseif ItemID == 602003 and cch.throwObjects[615] and cch.throwObjects[615].resID and cch.throwObjects[615].resID > 0 then
                                    return cch.throwObjects[615].resID
                                elseif ItemID == 602004 and cch.throwObjects[612] and cch.throwObjects[612].resID and cch.throwObjects[612].resID > 0 then
                                    return cch.throwObjects[612].resID
                                end
                            end
                            return origTry(uPlayerController, ItemID)
                        end
                    end
                end
            end)
            -- Per-class GetAvatarID hooks removed (heavy, fire for all player grenades)
            -- Timer-based applyGrenadeSkinsToController handles periodic application
        end

        local GRENADE_ITEMID_TO_SUB = {
            [602001] = 614,
            [602002] = 613,
            [602003] = 615,
            [602004] = 612,
        }

        -- Lightweight version: only hooks UpdateGrenadeAvatar for local grenades
        -- Timer-based applyGrenadeSkinsToController handles periodic application
        local function hookProjectileGrenadeAvatar()
            pcall(function()
                local ProjectileBase = require("GameLua.Mod.BaseMod.GamePlay.Actor.Projectile.ProjectileBase")
                local impl = ProjectileBase and ProjectileBase.__inner_impl
                if not impl or impl._lava_hooked_proj then return end
                impl._lava_hooked_proj = true
                local origUpdate = impl.UpdateGrenadeAvatar
                if origUpdate then
                    impl.UpdateGrenadeAvatar = function(self)
                        -- Only process local player grenades
                        if self.bAuthority then return origUpdate(self) end
                        local cch = cache()
                        if cch.throwObjects and slua.isValid(self.GrenadeAvatarComponent_BP) then
                            local itemID
                            if self.GetItemTypeID then
                                itemID = tonumber(self:GetItemTypeID())
                            elseif self.ItemDefineID then
                                itemID = tonumber(self.ItemDefineID.TypeSpecificID)
                            end
                            local sub = itemID and GRENADE_ITEMID_TO_SUB[itemID]
                            local info = sub and cch.throwObjects[sub]
                            if info and info.resID and info.resID > 0 then
                                pcall(function()
                                    self.GrenadeAvatarComponent_BP:ChangeItemAvatar(info.resID, false)
                                end)
                                return
                            end
                        end
                        return origUpdate(self)
                    end
                end
                -- Skip BeginInitialize and ResetGrenadeAvatar hooks (they fire for every player's grenades)
                -- Timer-based applyGrenadeSkinsToController will re-apply periodically
            end)
        end

        local function applyMatchWeaponSkinsToController()
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local skinList = {}
            for _, w in pairs(cache().weapons) do
                if w.resID and w.resID > 0 then skinList[#skinList + 1] = w.resID end
            end
            if #skinList == 0 then return false end
            local ok = false
            pcall(function()
                local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
                CommerAvatarDataUtil:InitWeaponSkinList(pc, skinList, nil, nil)
                if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end
                if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end
                ok = true
            end)
            if ok then notify("سلاح PC: " .. table.concat(skinList, ",")) end
            return ok
        end

        local _weaponTypeIDCache = {}
        local function resolveWeaponTypeID(weaponResID)
            weaponResID = tonumber(weaponResID) or 0
            if weaponResID <= 0 then return 0 end
            if _weaponTypeIDCache[weaponResID] ~= nil then return _weaponTypeIDCache[weaponResID] end
            local found = 0
            pcall(function()
                local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
                if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
            end)
            if found > 0 then _weaponTypeIDCache[weaponResID] = found; return found end
            pcall(function()
                local ic = CDataTable.GetTableData("Item", weaponResID)
                if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
            end)
            local result = found > 0 and found or weaponResID
            _weaponTypeIDCache[weaponResID] = result
            return result
        end

        local _lastBuildSkinMappings = 0
        local function buildSkinMappings()
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastBuildSkinMappings) < 0.5 then return end  -- throttle: max twice per second
            _lastBuildSkinMappings = now
            syncWeaponCacheFromLobby()
            local m = _G.AddOutfitSkinIdMappings
            for k in pairs(m) do m[k] = nil end
            for wid, w in pairs(cache().weapons) do
                wid = tonumber(wid)
                if wid and w.resID and w.resID > 0 then m[wid] = { tonumber(w.resID) } end
            end
            if MATCH_CONFIG.weaponSkins then
                for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
                    weaponKey, skinRes = tonumber(weaponKey), tonumber(skinRes)
                    if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                        m[weaponKey] = { skinRes }
                    end
                end
            end
        end

        local _skinIdCache = {}
        local _skinIdCacheTick = 0
        local function get_skin_id(currentGunId, maxIt)
            currentGunId, maxIt = tonumber(currentGunId) or 0, tonumber(maxIt) or 0
            if currentGunId <= 0 and maxIt <= 0 then return 0 end
            -- Fast path: prefer using weapon cache directly
            local cch = cache()
            local wid = maxIt > 0 and maxIt or currentGunId
            local w = cch.weapons[wid]
            if w and w.resID and w.resID > 0 then return w.resID end
            -- Try type ID lookup
            local typeId = resolveWeaponTypeID(wid)
            if typeId ~= wid then
                local w2 = cch.weapons[typeId]
                if w2 and w2.resID and w2.resID > 0 then return w2.resID end
            end
            -- Cache with short TTL
            local nowTick = _S.globalFrame or 0
            if (nowTick - _skinIdCacheTick) < 60 then
                local cached = _skinIdCache[wid]
                if cached then return cached end
            end
            buildSkinMappings()
            local m = _G.AddOutfitSkinIdMappings
            local result = nil
            if m[wid] and m[wid][1] then result = tonumber(m[wid][1])
            elseif typeId ~= wid and m[typeId] and m[typeId][1] then result = tonumber(m[typeId][1])
            end
            if result then
                _skinIdCache[wid] = result
                _skinIdCacheTick = nowTick
                return result
            end
            return wid
        end
        _G.get_skin_id = get_skin_id
        _G.skinIdMappings = _G.AddOutfitSkinIdMappings

        -- ========== Attachment Skin System (ported from C++ DumpSkin) ==========
        -- Builds weapon-skin -> attachment-skin maps from ItemUpgradeConfig and
        -- ItemUpgradeUnLockConfig, then applies the correct attachment skins
        -- (scopes, compensators, magazines, grips, stocks) when a weapon skin
        -- is active, so each skin carries its own dedicated attachments.

        local _attachMaps = nil

        local function _nameToString(name)
            if name == nil then return "" end
            if type(name) == "string" then return name end
            if type(name) == "userdata" then
                local s = nil
                pcall(function() if name.ToString then s = name:ToString() end end)
                if s and type(s) == "string" then return s end
                pcall(function() if name.ToWString then s = name:ToWString() end end)
                if s and type(s) == "string" then return s end
            end
            if type(name) == "table" and name.SourceString then
                return name.SourceString
            end
            return tostring(name)
        end

        local _WEAPON_CLASS_SUFFIXES = {
            { keywords = { "kar98", "awm", "m24", "amr", "mosin", "win94", "mk14" },
            suffixes = { "(Snipers)", "(Sniper Rifles)" } },
            { keywords = { "m249", "mg3", "dp-28", "dp28" },
            suffixes = { "(Machine Guns)" } },
            { keywords = { "ump", "p90", "vector", "bizon", "uzi", "thompson",
                        "mp5", "mp5k", "tommy" },
            suffixes = { "(SMG)", "(SMG, Pistols)", "(Rifles, SMG)" } },
            { keywords = { "p1911", "p92", "p18c", "deagle", "r1895", "r45",
                        "skorpion", "g18" },
            suffixes = { "(Pistols)", "(SMG, Pistols)" } },
            { keywords = { "akm", "m762", "scar", "famas", "m16a4", "aug",
                        "groza", "qbz", "m416", "mk47", "g36c", "ace32",
                        "k2", "m4" },
            suffixes = { "(AR)", "(Rifles, SMG)" } },
        }

        local function _classSuffixesFromSkinName(skinName)
            if type(skinName) ~= "string" or skinName == "" then return {} end
            local low = string.lower(skinName)
            for _, entry in ipairs(_WEAPON_CLASS_SUFFIXES) do
                for _, kw in ipairs(entry.keywords) do
                    if string.find(low, kw, 1, true) then return entry.suffixes end
                end
            end
            return {}
        end

        local function buildAttachmentMaps()
            if _attachMaps then return _attachMaps end
            _attachMaps = {
                skinAttachments  = {},  -- weaponSkinId -> { partSkinId1, partSkinId2, ... }
                skinBases        = {},  -- weaponSkinId -> { baseId1, baseId2, ... }
                attachToSkin     = {},  -- partSkinId   -> { weaponSkinId, baseId }
                skinToBaseWeapon = {},  -- weaponSkinId -> baseWeaponID
            }
            if not CDataTable or not CDataTable.GetTable then return _attachMaps end

            -- 1) GroupID -> [PartIds] from ItemUpgradeUnLockConfig
            local groupToParts = {}
            pcall(function()
                local unlockTbl = CDataTable.GetTable("ItemUpgradeUnLockConfig")
                if not unlockTbl then return end
                for _, row in pairs(unlockTbl) do
                    local gid  = tonumber(row.GroupID)
                    local part = tonumber(row.PartId or row.PartID)
                    if gid and part then
                        if not groupToParts[gid] then groupToParts[gid] = {} end
                        groupToParts[gid][#groupToParts[gid] + 1] = part
                    end
                end
            end)

            -- 2) weaponSkinId -> GroupID + skinToBaseWeapon from ItemUpgradeConfig
            local skinToGroup = {}
            pcall(function()
                local upTbl = CDataTable.GetTable("ItemUpgradeConfig")
                if not upTbl then return end
                for _, row in pairs(upTbl) do
                    local gid = tonumber(row.GroupID)
                    local itm = tonumber(row.ItemID)
                    if gid and itm and itm >= 1000000000 then
                        skinToGroup[itm] = gid
                        local baseWeaponID = math.floor(itm / 1000) % 1000000
                        if baseWeaponID >= 100000 and baseWeaponID <= 999999 then
                            _attachMaps.skinToBaseWeapon[itm] = baseWeaponID
                        end
                    end
                end
            end)

            -- 3) Base name -> [ids] index from Item table (vanilla attachments only)
            local baseNameToIds = {}
            local itemTbl = CDataTable.GetTable("Item")
            if itemTbl then
                for k, row in pairs(itemTbl) do
                    local id = tonumber(k) or tonumber(row and row.ItemID)
                    if id and id >= 1000 and id < 10000000 then
                        local nm = row and row.ItemName
                        if type(nm) ~= "string" then nm = _nameToString(nm) end
                        if type(nm) == "string" and nm ~= "" then
                            if not baseNameToIds[nm] then baseNameToIds[nm] = {} end
                            baseNameToIds[nm][#baseNameToIds[nm] + 1] = id
                        end
                    end
                end
            end

            -- 4) For each weapon skin, resolve its attachments' base IDs
            for weaponSkinId, gid in pairs(skinToGroup) do
                local parts = groupToParts[gid]
                if parts and #parts > 0 then
                    local bases = {}
                    local wc = cfg(weaponSkinId)
                    local weaponSkinName = ""
                    if wc then
                        local nm = wc.ItemName
                        if type(nm) ~= "string" then nm = _nameToString(nm) end
                        weaponSkinName = nm or ""
                    end
                    local suffixes = _classSuffixesFromSkinName(weaponSkinName)

                    for _, partId in ipairs(parts) do
                        local baseId = 0
                        local partRow = nil
                        if itemTbl then
                            partRow = itemTbl[partId] or itemTbl[tostring(partId)]
                        end
                        if not partRow and CDataTable.GetTableData then
                            partRow = CDataTable.GetTableData("Item", partId)
                        end
                        if partRow then
                            local nm = partRow.ItemName
                            if type(nm) ~= "string" then nm = _nameToString(nm) end
                            if type(nm) == "string" and nm ~= "" then
                                local list = baseNameToIds[nm]
                                if type(list) == "table" and #list >= 1 then
                                    baseId = list[1]
                                    for _, v in ipairs(list) do
                                        if v < baseId then baseId = v end
                                    end
                                end
                                if baseId == 0 then
                                    for _, suf in ipairs(suffixes) do
                                        local trial = nm .. " " .. suf
                                        local lst = baseNameToIds[trial]
                                        if type(lst) == "table" and #lst >= 1 then
                                            baseId = lst[1]
                                            for _, v in ipairs(lst) do
                                                if v < baseId then baseId = v end
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        bases[#bases + 1] = baseId
                        _attachMaps.attachToSkin[partId] = { weaponSkinId, baseId }
                    end
                    _attachMaps.skinAttachments[weaponSkinId] = parts
                    _attachMaps.skinBases[weaponSkinId] = bases
                end
            end

            local nSkins, nAttach = 0, 0
            for _ in pairs(_attachMaps.skinAttachments) do nSkins = nSkins + 1 end
            for _ in pairs(_attachMaps.attachToSkin) do nAttach = nAttach + 1 end
            log("Attachment maps: " .. nSkins .. " skins, " .. nAttach .. " attachments")

            return _attachMaps
        end

        local function applyAttachmentSkins(AttachmentArray, selectedSkinID)
            if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end
            selectedSkinID = tonumber(selectedSkinID) or 0
            if selectedSkinID == 0 then return false end

            local maps = buildAttachmentMaps()
            local attachments = maps.skinAttachments[selectedSkinID]
            local bases = maps.skinBases[selectedSkinID]

            local numSlots = 0
            pcall(function() numSlots = AttachmentArray:Num() end)
            if numSlots <= 0 then return false end

            local changed = false

            -- If selected skin has no attachments in the map, revert any
            -- part-skins found on attachment slots back to their base IDs.
            if not attachments or #attachments == 0 then
                for slotIdx = 0, numSlots - 1 do
                    if slotIdx ~= _K.GUN_MASTER_SYN_SLOT then
                        local slotData = AttachmentArray:Get(slotIdx)
                        if slotData then
                            local curID = 0
                            pcall(function()
                                curID = slua.IndexReference(slotData, "defineID").TypeSpecificID or 0
                            end)
                            curID = tonumber(curID) or 0
                            if curID > 0 then
                                local rIt = maps.attachToSkin[curID]
                                if rIt then
                                    local baseId = rIt[2]
                                    if baseId ~= 0 and baseId ~= curID then
                                        pcall(function()
                                            local defRef = slua.IndexReference(slotData, "defineID")
                                            defRef.TypeSpecificID = baseId
                                            slotData.operationType = 0
                                            AttachmentArray:Set(slotIdx, slotData)
                                        end)
                                        changed = true
                                    end
                                end
                            end
                        end
                    end
                end
                return changed
            end

            -- Build a set of valid attachment skin IDs for this weapon skin
            local validSkinIds = {}
            for _, id in ipairs(attachments) do
                validSkinIds[tonumber(id) or 0] = true
            end

            -- Normal case: for each attachment slot, find the matching
            -- attachment skin by baseId and swap to the selected skin's version.
            for slotIdx = 0, numSlots - 1 do
                if slotIdx ~= _K.GUN_MASTER_SYN_SLOT then
                    local slotData = AttachmentArray:Get(slotIdx)
                    if slotData then
                        local curID = 0
                        pcall(function()
                            curID = slua.IndexReference(slotData, "defineID").TypeSpecificID or 0
                        end)
                        curID = tonumber(curID) or 0
                        if curID > 0 then
                            -- Protection: if current attachment is already the correct skin, skip
                            if validSkinIds[curID] then
                                -- Already the correct skinned attachment, don't change
                            else
                                local baseId = 0
                                local rIt = maps.attachToSkin[curID]
                                if rIt then
                                    baseId = rIt[2]
                                elseif curID < 10000000 then
                                    baseId = curID
                                else
                                    -- Unknown skinned attachment from different skin, skip
                                    baseId = 0
                                end
                                if baseId ~= 0 then
                                    local srcIdx = 0
                                    for k, b in ipairs(bases) do
                                        if b ~= 0 and b == baseId then
                                            local candidate = tonumber(attachments[k]) or 0
                                            if candidate ~= 0 and candidate ~= curID then
                                                srcIdx = k
                                                break
                                            end
                                        end
                                    end
                                    if srcIdx > 0 and srcIdx <= #attachments then
                                        local newID = tonumber(attachments[srcIdx]) or 0
                                        if newID ~= 0 and newID ~= curID then
                                            pcall(function()
                                                local defRef = slua.IndexReference(slotData, "defineID")
                                                defRef.TypeSpecificID = newID
                                                slotData.operationType = 0
                                                AttachmentArray:Set(slotIdx, slotData)
                                            end)
                                            changed = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return changed
        end

        local function applySkinToWeaponRef(CurWeapon)
            if not slua.isValid(CurWeapon) then return false end
            local AttachmentArray = CurWeapon.synData
            if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end

-- @RAHMANYVI
            local AttachmentData = AttachmentArray:Get(_K.GUN_MASTER_SYN_SLOT)
            if not AttachmentData then return false end

            local current_gunid = 0
            pcall(function()
                current_gunid = slua.IndexReference(AttachmentData, "defineID").TypeSpecificID or 0
            end)
            current_gunid = tonumber(current_gunid) or 0
            if current_gunid <= 0 then return false end

            local MaxIt = 0
            pcall(function()
                if CurWeapon.GetWeaponID then MaxIt = CurWeapon:GetWeaponID() end
                if MaxIt <= 0 then MaxIt = CurWeapon:GetItemDefineID().TypeSpecificID end
            end)
            MaxIt = tonumber(MaxIt) or 0
            if MaxIt <= 0 then return false end

            local tmp_id = get_skin_id(current_gunid, MaxIt)
            tmp_id = tonumber(tmp_id) or 0
            if tmp_id <= 0 then return false end

-- @RAHMANYVI
            if tmp_id == current_gunid and not isInjectedRes(tmp_id) then
                local ok, attChanged = pcall(applyAttachmentSkins, AttachmentArray, tmp_id)
                if ok and attChanged then
                    pcall(function()
                        local char = getLocalChar()
                        if char and char.AddGameTimer then
                            for _, delay in ipairs({0.3, 0.6, 1.0}) do
                                char:AddGameTimer(delay, false, function()
                                    if slua.isValid(CurWeapon) then
                                        local aa = CurWeapon.synData
                                        if aa and slua.isValid(aa) then
                                            pcall(applyAttachmentSkins, aa, tmp_id)
                                        end
                                    end
                                end)
                            end
                        end
                    end)
                end
                return false
            end
            if tmp_id == _S.lastAppliedSkinID and MaxIt == _S.lastAppliedWeaponID then
                local ok, attChanged = pcall(applyAttachmentSkins, AttachmentArray, tmp_id)
                if ok and attChanged then
                    pcall(function()
                        local char = getLocalChar()
                        if char and char.AddGameTimer then
                            for _, delay in ipairs({0.3, 0.6, 1.0}) do
                                char:AddGameTimer(delay, false, function()
                                    if slua.isValid(CurWeapon) then
                                        local aa = CurWeapon.synData
                                        if aa and slua.isValid(aa) then
                                            pcall(applyAttachmentSkins, aa, tmp_id)
                                        end
                                    end
                                end)
                            end
                        end
                    end)
                end
                return true
            end

            _G.AddOutfitLastAppliedSkin[current_gunid] = tmp_id
            pcall(function()
                local defRef = slua.IndexReference(AttachmentData, "defineID")
                defRef.TypeSpecificID = tmp_id
                local c0 = cfg(tmp_id)
                if c0 and c0.ItemType and defRef.Type ~= nil then defRef.Type = c0.ItemType end
                AttachmentData.operationType = 0
                AttachmentArray:Set(_K.GUN_MASTER_SYN_SLOT, AttachmentData)
            end)
            pcall(applyAttachmentSkins, AttachmentArray, tmp_id)
            if CurWeapon.DelayHandleAvatarMeshChanged then CurWeapon:DelayHandleAvatarMeshChanged() end
            -- Delayed re-application of attachment skins to ensure attachments
            -- are updated after the weapon finishes loading its default attachments.
            -- This fixes the issue where attachments don't update until you swap them.
            pcall(function()
                local char = getLocalChar()
                if char and char.AddGameTimer then
                    for _, delay in ipairs({0.3, 0.6, 1.0}) do
                        char:AddGameTimer(delay, false, function()
                            if slua.isValid(CurWeapon) then
                                local aa = CurWeapon.synData
                                if aa and slua.isValid(aa) then
                                    pcall(applyAttachmentSkins, aa, tmp_id)
                                end
                            end
                        end)
                    end
                end
            end)
            _S.weaponHookGuardUntil = _S.globalFrame + 45
            _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
            _S.lastAppliedWeaponID = MaxIt
            _S.lastAppliedSkinID = tmp_id
            return true
        end

        function _G.equip_weapon_avatar(uCharacter)
            if not uCharacter or not slua.isValid(uCharacter) then return false end
            buildSkinMappings()
            local WeaponManager = uCharacter:GetWeaponManager()
            if not WeaponManager or not slua.isValid(WeaponManager) then return false end
            local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
            if not uWeaponList or not slua.isValid(uWeaponList) then return false end
            local appliedAny = false
            for i = 0, uWeaponList:Num() - 1 do
                local CurWeapon = uWeaponList:Get(i)
                if slua.isValid(CurWeapon) and applySkinToWeaponRef(CurWeapon) then
                    appliedAny = true
                end
            end
            return appliedAny
        end

        local function getDesiredWeaponSkins()
            syncWeaponCacheFromLobby()
            local out, seen = {}, {}
            local function add(res)
                res = tonumber(res)
                if res and res > 0 and not seen[res] then seen[res] = true; out[#out + 1] = res end
            end
            for _, w in pairs(cache().weapons) do add(w.resID) end
            if MATCH_CONFIG.weaponSkins then
                for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
            end
            return out
        end

        local function registerWeaponAvatarItems(char)
            local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
            if not slua.isValid(pc) then return false end
            local BU = import("BackpackUtils")
            local AU = import("AvatarUtils")
            local addedCount = 0
            for _, resID in ipairs(getDesiredWeaponSkins()) do
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
            notify("سجّلت " .. addedCount .. " سكن سلاح")
            return true
        end

        local _lastMatchApplyWeapon = 0
        local function matchApplyWeaponSkin(char)
            local now = 0
            pcall(function() now = os.clock() end)
            if (now - _lastMatchApplyWeapon) < 0.4 then return false end  -- throttle: max 2.5x/sec
            _lastMatchApplyWeapon = now
            buildSkinMappings()
            applyMatchWeaponSkinsToController()
            if not _S.avatarItemsRegistered then
                _S.avatarItemsRegistered = registerWeaponAvatarItems(char)
            end
            local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
            if not slua.isValid(curWeapon) then
                return _G.equip_weapon_avatar(char)
            end

            local curWeaponResID = 0
            pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
            local desiredSkin = get_skin_id(curWeaponResID, curWeaponResID)
            if curWeaponResID == _S.lastAppliedWeaponID and desiredSkin == _S.lastAppliedSkinID then
                pcall(_G.equip_weapon_avatar, char)
                return true
            end

            local ok = applySkinToWeaponRef(curWeapon)
            ok = _G.equip_weapon_avatar(char) or ok
            if ok then
                _S.lastAppliedWeaponID = curWeaponResID
                _S.lastAppliedSkinID = desiredSkin
                _S.weaponApplied = true
                _S.weaponDiagDone = true
                notify("سكن سلاح مطبق: " .. tostring(desiredSkin))
            end
            return ok
        end

        local function applyMatchThrowObjects()
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return false end
            local cch = cache()
            if not cch.throwObjects then
                log("applyMatchThrowObjects: no throwObjects in cache")
                return false
            end
            local hasThrow = false
            for st, info in pairs(cch.throwObjects) do
                if info.resID and info.resID > 0 then hasThrow = true end
            end
            if not hasThrow then
                log("applyMatchThrowObjects: throwObjects cache empty")
                return false
            end
            local applied = false
            pcall(function()
                -- Try setting InitialConsumableAvatar fields (works if Lua table reference)
                if pc.InitialConsumableAvatar then
                    for st, info in pairs(cch.throwObjects) do
                        local key = _K.THROW_AVATAR_KEY[_K.THROW_SUB[st]]
                        if key and info.resID and info.resID > 0 then
                            pc.InitialConsumableAvatar[key] = info.resID
                            -- log suppressed
                        end
                    end
                end
                -- Rebuild grenade avatar list from InitialConsumableAvatar
                if pc.InitGrenadeAvatarList then
                    pc:InitGrenadeAvatarList(false)
                end
                -- Fallback: directly add to GrenadeAvatarItemList (overwrites server entries)
                if pc.AddToGrenadeAvatarItemList then
                    for st, info in pairs(cch.throwObjects) do
                        if info.resID and info.resID > 0 and _K.THROW_SUB[st] then
                            pc:AddToGrenadeAvatarItemList(info.resID)
                            applied = true
                        end
                    end
                end
            end)
            return applied
        end

        local function matchApplyAll(char)
            local ok = false
            if not _S.matchOutfitDone then
                _S.matchOutfitDone = matchApplyOutfit(char)
                ok = _S.matchOutfitDone or ok
            end
            if applyMatchEquipAvatarToController() then ok = true end
            if matchApplyEquipSkins(char) then ok = true; _S.matchApplied = true end
            if matchApplyWeaponSkin(char) then ok = true end
            if applyMatchThrowObjects() then ok = true end
            return ok
        end

-- @RAHMANYVI
        local function startMatchWatcher(char)
            if _S.matchTimer then return end
            _S.matchOutfitDone = false
            _S.avatarItemsRegistered = false
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.lastAppliedWeaponID = 0
            _S.lastAppliedSkinID = 0

            local attempts = 0

            _S.matchTimer = char:AddGameTimer(1.0, true, function()
                attempts = attempts + 1
                local cur = getLocalChar()
                if not cur or not slua.isValid(cur) then return end
                pcall(matchApplyAll, cur)
                if attempts >= 30 then
                    pcall(function() if cur.RemoveGameTimer then cur:RemoveGameTimer(_S.matchTimer) end end)
                    _S.matchTimer = nil
                    log("-- @RAHMANYVI")
                end
            end)
        end

-- @RAHMANYVI
        local _hookedGetWeaponAvatarRes = false

        local function hookBackpackWeaponAvatarRes()
            if _hookedGetWeaponAvatarRes then return end
            _hookedGetWeaponAvatarRes = true
            pcall(function()
                local BPL = require("GameLua.Mod.BaseMod.Client.Backpack.BackPackFunctionLibrary")
                if BPL and BPL.GetWeaponAvatarRes and not BPL._lava_hooked_avatar_res then
                    BPL._lava_hooked_avatar_res = true
                    local _bpAvatarResCache = {}
                    local _bpAvatarResTicks = {}
                    local _bpResCacheAge = 0
                    local origGetRes = BPL.GetWeaponAvatarRes
                    BPL.GetWeaponAvatarRes = function(WeaponID, AdditionalDataArray)
                        WeaponID = tonumber(WeaponID) or 0
                        if WeaponID <= 0 then return origGetRes(WeaponID, AdditionalDataArray) end
                        -- Cache with invalidation every ~5 seconds via frame count
                        local cached = _bpAvatarResCache[WeaponID]
                        local age = _bpResCacheAge
                        local nowTick = _S.globalFrame or 0
                        if cached and (nowTick - (_bpAvatarResTicks[WeaponID] or 0)) < 150 then
                            return cached, ""
                        end
                        local targetSkinID = 0
                        -- 1) map directly from cache weapons
                        local cch = cache()
                        local typeId = resolveWeaponTypeID(WeaponID)
                        local w = cch.weapons[typeId] or cch.weapons[WeaponID]
                        if w and w.resID and w.resID > 0 then
                            targetSkinID = w.resID
                        end
                        -- 2) fallback to get_skin_id
                        if targetSkinID <= 0 or targetSkinID == WeaponID then
                            local sid = get_skin_id(WeaponID, WeaponID)
                            targetSkinID = tonumber(sid) or 0
                        end
                        -- Cache result
                        if targetSkinID > 0 and targetSkinID ~= WeaponID then
                            _bpAvatarResCache[WeaponID] = targetSkinID
                            _bpAvatarResTicks[WeaponID] = nowTick
                            local skinCfg = cfg(targetSkinID)
                            if skinCfg then
                                return targetSkinID, ""
                            end
                        end
                        _bpAvatarResCache[WeaponID] = WeaponID
                        _bpAvatarResTicks[WeaponID] = nowTick
                        return origGetRes(WeaponID, AdditionalDataArray)
                    end
                    log("[AddOutfit] hookBackpackWeaponAvatarRes: تم")
                end
            end)
        end

-- @RAHMANYVI
        local _lastVehicleSkinKey = ""
        local _lastVehicleApplyClock = 0
        local applyVehicleChassisLight   -- dideklarasikan dulu, dipakai di bawah

        -- Bentuk (shape) kendaraan dari sebuah resID skin.
        local _vehicleShapeCache = {}
        local function vehicleShapeOfSkin(resID)
            resID = tonumber(resID)
            if not resID or resID <= 0 then return nil end
            if _vehicleShapeCache[resID] ~= nil then
                local cached = _vehicleShapeCache[resID]
                return cached ~= false and cached or nil
            end
            local ok, shape = pcall(function()
                local AU = import("AvatarUtils")
                return AU.GetVehicleShapeBySkinID(resID)
            end)
            shape = ok and tonumber(shape) or nil
            if shape and shape >= 0 then
                _vehicleShapeCache[resID] = shape
                return shape
            end
            _vehicleShapeCache[resID] = false
            return nil
        end

        local function getVehicleAvatarComp(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return nil end
            local av
            pcall(function() if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end end)
            if not slua.isValid(av) then pcall(function() av = vehicle.VehicleAvatar end) end
            if not slua.isValid(av) then pcall(function() av = vehicle.VehicleAvatarComponent_BP end) end
            return slua.isValid(av) and av or nil
        end

        -- Semua resID skin kendaraan yang tersimpan (slot DataMgr + config JSON).
        local function vehicleResFromIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return 0 end
            local rid = 0
            if isInjectedIns(ins) then rid = tonumber(R.insToRes[ins]) or 0 end
            if rid <= 0 then
                pcall(function()
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetHallDepotItemDataByInsID(ins)
                    rid = d and tonumber(d.resID) or 0
                end)
            end
            return rid or 0
        end

        -- Semua resID skin kendaraan: daftar gabungan + per subtype.
        local function collectVehicleSkinResIDs()
            local all, bySub, added = {}, {}, {}
            local function add(res, subType)
                res = tonumber(res)
                if not res or res <= 0 then return end
                if not added[res] then
                    added[res] = true
                    all[#all + 1] = res
                end
                subType = tonumber(subType)
                if subType and subType > 0 then
                    bySub[subType] = bySub[subType] or {}
                    local list = bySub[subType]
                    if #list == 0 or list[#list] ~= res then list[#list + 1] = res end
                end
            end
            pcall(function()
                for subType, insList in pairs(DataMgr and DataMgr.VehicleSlotList or {}) do
                    if type(insList) == "table" then
                        for _, ins in ipairs(insList) do add(vehicleResFromIns(ins), subType) end
                    end
                end
            end)
            pcall(function()
                local saved = _G.AddOutfitPendingPersist
                if type(saved) == "table" and type(saved.vehicleSlots) == "table" then
                    for subType, slotMap in pairs(saved.vehicleSlots) do
                        if type(slotMap) == "table" then
                            for _, res in pairs(slotMap) do add(res, subType) end
                        end
                    end
                end
            end)
            return all, bySub
        end

        local function applyVehicleSkinInGame()
            local char = getLocalChar()
            if not char or not slua.isValid(char) then return end

            local vehicle
            pcall(function() vehicle = char:GetCurrentVehicle() end)
            if not slua.isValid(vehicle) then
                pcall(function() vehicle = char.CurrentVehicle end)
            end
            if not vehicle or not slua.isValid(vehicle) then
                _lastVehicleSkinKey = ""
                return
            end

            pcall(syncVehicleAvatarSkinList)

            local av = getVehicleAvatarComp(vehicle)
            if not av then return end

            local list, bySub = collectVehicleSkinResIDs()
            if #list == 0 then return end

            -- Bentuk kendaraan saat ini. GetDefaultAvatarID bisa 0 di match,
            -- jadi dicari lewat beberapa sumber lain.
            local vehShape = nil
            pcall(function()
                local sh = tonumber(vehicle.VehicleShapeType)
                if sh and sh >= 0 then vehShape = sh end
            end)
            local defaultId = 0
            pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
            if not vehShape and defaultId > 0 then vehShape = vehicleShapeOfSkin(defaultId) end

            -- Kalau subtype kendaraan diketahui, pakai daftar slot khusus
            -- subtype itu (paling akurat, tidak tertukar antar kendaraan).
            if defaultId > 0 then
                local defCfg = cfg(defaultId)
                local sub = defCfg and tonumber(defCfg.ItemSubType or defCfg.itemSubType) or 0
                local typed = sub and sub > 0 and bySub[sub] or nil
                if typed and #typed > 0 then list = typed end
            end
            if not vehShape then
                pcall(function()
                    local defCfg = vehicle.AvatarDefaultCfg
                    local defRes = defCfg and tonumber(defCfg.TypeSpecificID)
                    if defRes and defRes > 0 then vehShape = vehicleShapeOfSkin(defRes) end
                end)
            end

            local skinResID = 0
            if vehShape then
                for _, rid in ipairs(list) do
                    if vehicleShapeOfSkin(rid) == vehShape then
                        skinResID = rid
                        break
                    end
                end
            end
            if skinResID <= 0 then skinResID = list[1] end
            if skinResID <= 0 then return end

            -- Avatar yang sedang dipakai kendaraan.
            local cur = 0
            pcall(function() cur = tonumber(vehicle:GetAvatarId()) or 0 end)
            if cur <= 0 then
                pcall(function() cur = tonumber(vehicle.GetVehicleSkinItemID and vehicle:GetVehicleSkinItemID()) or 0 end)
            end
            if cur <= 0 then pcall(function() cur = tonumber(vehicle.ClientUsedAvatarID) or 0 end) end
            if cur <= 0 then pcall(function() cur = tonumber(av:GetCurrentAvatarID()) or 0 end) end

            local key = tostring(vehicle) .. "_" .. tostring(skinResID)
            if cur > 0 and cur == skinResID then
                _lastVehicleSkinKey = key
                return
            end
            local nowClock = 0
            pcall(function() nowClock = os.clock() end)
            -- Jangan memasang ulang terus-menerus kalau current avatar tidak
            -- bisa dibaca (cegah kedip / re-attach tiap 2 detik).
            if _lastVehicleSkinKey == key and (nowClock - _lastVehicleApplyClock) < 10.0 then
                return
            end

            local ok = false

            -- pc.ShowVehicleSkin + daftar avatar (1.lua applyClientVehicleSkin).
            pcall(function()
                local pc = getPlayerController()
                if not pc or not slua.isValid(pc) then return end
                pc.ShowVehicleSkin = skinResID
                local shape = vehicleShapeOfSkin(skinResID)
                if shape and pc.VehicleAvatarList and pc.VehicleAvatarList.Add then
                    pcall(function() pc.VehicleAvatarList:Add(shape, skinResID) end)
                end
            end)

            pcall(function()
                if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end
                if av.bIsLobbyAvatar ~= nil then av.bIsLobbyAvatar = false end
            end)
            pcall(function()
                local pc = getPlayerController()
                if pc and av.SetVehicleNetAvatarData then av:SetVehicleNetAvatarData(pc) end
            end)
            pcall(function()
                if av.VehicleNetAvatarData then
                    av.VehicleNetAvatarData.SwitchEffectId = 7303001
                    av.VehicleNetAvatarData.UpdateFlag = 1
                end
            end)
            pcall(function()
                if av.ChangeItemAvatar then
                    av:ChangeItemAvatar(skinResID, true)
                    ok = true
                elseif av.PreChangeVehicleAvatar then
                    av:PreChangeVehicleAvatar(skinResID)
                    ok = true
                end
            end)
            pcall(function() if av.PostChangeItemAvatar then av:PostChangeItemAvatar(false) end end)
            pcall(function()
                local battleCls = import("VehicleAvatarComponentBattleBase")
                local battleAv = vehicle.GetComponentByClass and vehicle:GetComponentByClass(battleCls)
                if slua.isValid(battleAv) and battleAv.ChangeVehicleAvatar then
                    battleAv:ChangeVehicleAvatar(skinResID, false)
                    ok = true
                end
            end)
            pcall(function()
                if vehicle.ChangeVehicleAvatar then
                    local pc = getPlayerController()
                    if pc then vehicle:ChangeVehicleAvatar(pc) else vehicle:ChangeVehicleAvatar() end
                end
            end)
            pcall(function() if vehicle.ForceNetUpdate then vehicle:ForceNetUpdate() end end)

            _lastVehicleSkinKey = key
            _lastVehicleApplyClock = nowClock
            if ok then
                _G.CurrentEquipVehicleID = skinResID
                pcall(applyVehicleChassisLight)
            end
        end

-- @RAHMANYVI
        local _LAVA_CHASSIS_LIGHT_ID = 7302002

        local function isLocalPlayerVehicle(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return false end
            local char = getLocalChar()
            if not char or not slua.isValid(char) then return false end
            local currentVehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
            if currentVehicle and currentVehicle == vehicle then return true end
            local driver = nil
            pcall(function() driver = vehicle.GetDriver and vehicle:GetDriver() end)
            if driver and driver == char then return true end
            return false
        end

        local function getVehicleSkinID(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return 0 end
            local skinID = 0
            pcall(function()
                if vehicle.GetVehicleSkinItemID then
                    skinID = vehicle:GetVehicleSkinItemID() or 0
                end
            end)
            if skinID and skinID > 0 then return skinID end
            pcall(function()
                if vehicle.ClientUsedAvatarID then
                    skinID = vehicle.ClientUsedAvatarID
                end
            end)
            if skinID and skinID > 0 then return skinID end
            pcall(function()
                local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                if avatarComp and slua.isValid(avatarComp) and avatarComp.GetCurrentAvatarID then
                    skinID = avatarComp:GetCurrentAvatarID() or 0
                end
            end)
            return skinID or 0
        end

        local function vehicleHasSkinApplied(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return false end
            local skinID = getVehicleSkinID(vehicle)
            if skinID <= 0 then return false end
            local defaultID = 0
            pcall(function()
                local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                if avatarComp and slua.isValid(avatarComp) and avatarComp.GetDefaultAvatarID then
                    defaultID = avatarComp:GetDefaultAvatarID() or 0
                end
            end)
            return skinID ~= defaultID
        end

        local function forceVehicleChassisLight(vehicle)
            if not vehicle or not slua.isValid(vehicle) then return end
            local licenseComp = vehicle.GetLicenseComponent and vehicle:GetLicenseComponent()
            if not licenseComp or not slua.isValid(licenseComp) then
                print("[AddOutfit] forceVehicleChassisLight: no licenseComp")
                return
            end
            if not licenseComp.LicensePlate then
                print("[AddOutfit] forceVehicleChassisLight: no LicensePlate")
                return
            end
            if licenseComp.LicensePlate.ChassisLightId == _LAVA_CHASSIS_LIGHT_ID and slua.isValid(licenseComp.ChassisLightMesh) then
                return
            end
            local skinID = getVehicleSkinID(vehicle)
            if skinID > 0 then
                licenseComp.LicensePlate.ItemID = skinID
            end
            licenseComp.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
            if licenseComp.curVehicleAvatarId == nil or licenseComp.curVehicleAvatarId == 0 then
                licenseComp.curVehicleAvatarId = skinID
            end
            print("[AddOutfit] forceVehicleChassisLight: skinID=" .. tostring(skinID) .. " ChassisLightId=" .. tostring(_LAVA_CHASSIS_LIGHT_ID) .. " ItemID=" .. tostring(licenseComp.LicensePlate.ItemID))
            if licenseComp.PreChangeChassisLight then
                pcall(function() licenseComp:PreChangeChassisLight() end)
            end
        end

        applyVehicleChassisLight = function()
            local char = getLocalChar()
            if not char or not slua.isValid(char) then return end
            local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
            if not vehicle or not slua.isValid(vehicle) then return end
            if not isLocalPlayerVehicle(vehicle) then return end
            if not vehicleHasSkinApplied(vehicle) then return end
            forceVehicleChassisLight(vehicle)
        end

        local function hookVehicleLicenseComponentBase()
            local ok, VLB = pcall(require, "GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
            if not ok or not VLB then return end
            local impl = VLB.__inner_impl
            if not impl or type(impl) ~= "table" then return end
            if impl._lava_hooked_chassis then return end
            impl._lava_hooked_chassis = true

            local origCheckDownloaded = impl.CheckHasVehicleDownloaded
            impl.CheckHasVehicleDownloaded = function(self, ItemID)
                local vehicle = self:GetOwner()
                if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                    return true
                end
                return origCheckDownloaded(self, ItemID)
            end

            local origPreChange = impl.PreChangeChassisLight
            impl.PreChangeChassisLight = function(self)
                pcall(function()
                    local vehicle = self:GetOwner()
                    if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                        if self.LicensePlate then
                            local skinID = getVehicleSkinID(vehicle)
                            if skinID > 0 then
                                self.LicensePlate.ItemID = skinID
                            end
                            self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                        end
                    end
                end)
                return origPreChange(self)
            end

            local origAsyncLoad = impl.AsyncLoadAccessoryItemHandle
            if origAsyncLoad then
                impl.AsyncLoadAccessoryItemHandle = function(self, itemId, bCheckDownload)
                    if itemId == _LAVA_CHASSIS_LIGHT_ID then
                        bCheckDownload = false
                    end
                    return origAsyncLoad(self, itemId, bCheckDownload)
                end
            end

            local origAsyncLoadHandle = impl._AsyncLoadHandle
            if origAsyncLoadHandle then
                impl._AsyncLoadHandle = function(self, ItemID)
                    if ItemID == _LAVA_CHASSIS_LIGHT_ID then
                        pcall(function()
                            local UBackpackUtils = import("BackpackUtils")
                            local handlePath = self:GetAccessoryAvatarHandlePath(ItemID)
                            local itemCfg = CDataTable.GetTableData("Item", ItemID)
                            if handlePath and itemCfg and itemCfg.BPID then
                                local bpCfg = CDataTable.GetTableData("AvatarBPTable", itemCfg.BPID)
                                if bpCfg and bpCfg.AvatarBPPath and bpCfg.AvatarBPPath ~= "" then
                                    self:AsyncLoadAsset(handlePath, self.OnAccHandleLoaded, self, ItemID, itemCfg.BPID)
                                    return
                                end
                            end
                            print("[AddOutfit] _AsyncLoadHandle bypass failed for chassis light, trying direct load")
                        end)
                    end
                    return origAsyncLoadHandle(self, ItemID)
                end
            end

            local origOnRep = impl.OnRep_LicensePlate
            if origOnRep then
                impl.OnRep_LicensePlate = function(self)
                    local bReapply = false
                    pcall(function()
                        local vehicle = self:GetOwner()
                        if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                            bReapply = true
                            if self.LicensePlate then
                                local skinID = getVehicleSkinID(vehicle)
                                if skinID > 0 then
                                    self.LicensePlate.ItemID = skinID
                                end
                                self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                            end
                        end
                    end)
                    local result = origOnRep(self)
                    if bReapply then
                        pcall(function()
                            if self.LicensePlate then
                                local skinID = getVehicleSkinID(self:GetOwner())
                                if skinID > 0 then
                                    self.LicensePlate.ItemID = skinID
                                end
                                self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                            end
                            if self.PreChangeChassisLight then
                                self:PreChangeChassisLight()
                            end
                        end)
                    end
                    return result
                end
            end

            local origOnVehicleMesh = impl.OnVehicleMeshAvatarEquiped
            if origOnVehicleMesh then
                impl.OnVehicleMeshAvatarEquiped = function(self, expectItemId)
                    local result = origOnVehicleMesh(self, expectItemId)
                    pcall(function()
                        local vehicle = self:GetOwner()
                        if isLocalPlayerVehicle(vehicle) and vehicleHasSkinApplied(vehicle) then
                            if self.LicensePlate then
                                local skinID = getVehicleSkinID(vehicle)
                                if skinID > 0 then
                                    self.LicensePlate.ItemID = skinID
                                end
                                self.LicensePlate.ChassisLightId = _LAVA_CHASSIS_LIGHT_ID
                            end
                            if self.PreChangeChassisLight then
                                self:PreChangeChassisLight()
                            end
                        end
                    end)
                    return result
                end
            end

            print("[AddOutfit] VehicleLicenseComponentBase chassis hook installed")
        end

        local function hookVehiclePlateLicenseUtil()
            local ok, VPLU = pcall(require, "GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            if not ok or not VPLU then return end
            if VPLU._lava_hooked_chassis then return end
            VPLU._lava_hooked_chassis = true
            local origGetLoc = VPLU.GetChassisLightLocAndScale
            VPLU.GetChassisLightLocAndScale = function(vehicleId, bIsLobbyVehicle)
                local loc, scale = origGetLoc(vehicleId, bIsLobbyVehicle)
                if loc and scale then
                    return loc, scale
                end
                local defaultLoc = FVector(0, -20, 10)
                local defaultScale = FVector(6.5, 7, 1)
                print("[AddOutfit] GetChassisLightLocAndScale fallback defaults for vehicleId:" .. tostring(vehicleId))
                return defaultLoc, defaultScale
            end
            print("[AddOutfit] VehiclePlateLicenseUtil chassis hook installed")
        end

        local function hookServerChangeVehicleAvatar(pc)
            if not pc or not slua.isValid(pc) then return end
            if pc._lava_hooked_server_vehicle_skin then return end
            if not pc.ServerChangeVehicleAvatar then return end
            pc._lava_hooked_server_vehicle_skin = true
            local orig = pc.ServerChangeVehicleAvatar
            local hooked = function(self, resID)
                pcall(function()
                    local char = self:GetPlayerCharacterSafety()
                    if char and slua.isValid(char) then
                        local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
                        if vehicle and slua.isValid(vehicle) then
                            local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                            if avatarComp and slua.isValid(avatarComp) then
                                if avatarComp.SetVehicleNetAvatarData then
                                    avatarComp:SetVehicleNetAvatarData(self)
                                end
                                if avatarComp.VehicleNetAvatarData then
                                    avatarComp.VehicleNetAvatarData.SwitchEffectId = 7303001
                                    avatarComp.VehicleNetAvatarData.UpdateFlag = 1
                                end
                                avatarComp:ChangeItemAvatar(resID, true)
                                avatarComp.CanChangeAvatar = true
                                _lastVehicleSkinKey = ""
                                print("[AddOutfit] Vehicle skin changed locally to " .. tostring(resID))
                                pcall(applyVehicleChassisLight)
                            end
                        end
                    end
                end)
            end
            pcall(function() rawset(pc, "ServerChangeVehicleAvatar", hooked) end)
        end

        local _lava_skin_click_handler
        local function getSkinClickHandler()
            if _lava_skin_click_handler then return _lava_skin_click_handler end
            _lava_skin_click_handler = function(self)
                if self.resID > 0 then
                    local UsingID = self:GetLoopScrollBoxParentUI():GetCurUsingSkinID()
                    if self.resID ~= UsingID then
                        pcall(function()
                            local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                            local PlayerController = GameplayData.GetPlayerController()
                            if not slua.isValid(PlayerController) then return end
                            local char = PlayerController:GetPlayerCharacterSafety()
                            if not char or not slua.isValid(char) then return end
                            local vehicle = char.GetCurrentVehicle and char:GetCurrentVehicle()
                            if not vehicle or not slua.isValid(vehicle) then return end
                            local avatarComp = vehicle.GetAvatarComponent and vehicle:GetAvatarComponent()
                            if not avatarComp or not slua.isValid(avatarComp) then return end
                            if avatarComp.SetVehicleNetAvatarData then
                                avatarComp:SetVehicleNetAvatarData(PlayerController)
                            end
                            if avatarComp.VehicleNetAvatarData then
                                avatarComp.VehicleNetAvatarData.SwitchEffectId = 7303001
                                avatarComp.VehicleNetAvatarData.UpdateFlag = 1
                            end
                            avatarComp:ChangeItemAvatar(self.resID, true)
                            avatarComp.CanChangeAvatar = true
                            _lastVehicleSkinKey = ""
                            print("[AddOutfit] VehicleSkinItem applied skin locally " .. tostring(self.resID))
                            pcall(applyVehicleChassisLight)
                        end)
                    end
                end
                if EventSystem and EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                    EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                end
            end
            return _lava_skin_click_handler
        end

        local function hookVehicleSkinItem()
            local ok, VSI = pcall(require, "GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
            if not ok or not VSI then return end
            -- VSI هو class table اللي ليه __newindex = error، لازم نعدل على __inner_impl
            local impl = VSI.__inner_impl
            if not impl or type(impl) ~= "table" then return end
            if impl._lava_hooked_skin_item then return end
            impl._lava_hooked_skin_item = true
            local handler = getSkinClickHandler()
            local origRegist = impl.RegistEvents
            impl.RegistEvents = function(self)
                rawset(self, "OnClickSkinButton", handler)
                return origRegist(self)
            end
            local origOnRefresh = impl.OnRefresh
            impl.OnRefresh = function(self, resID, selectIndex)
                local cur = rawget(self, "OnClickSkinButton")
                if cur ~= handler then
                    rawset(self, "OnClickSkinButton", handler)
                    pcall(function()
                        if self.UnRegistEvents and self.RegistEvents then
                            self:UnRegistEvents()
                            self:RegistEvents()
                        end
                    end)
                end
                return origOnRefresh(self, resID, selectIndex)
            end
            impl.OnClickSkinButton = handler
        end

        local function hookVehicleSkinAndMusicPanel()
            local ok, VSP = pcall(require, "GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
            if not ok or not VSP then return end
            local impl = VSP.__inner_impl
            if not impl or type(impl) ~= "table" then return end
            if impl._lava_hooked_panel then return end
            impl._lava_hooked_panel = true
            local orig = impl.InitSkinList
            impl.InitSkinList = function(self)
                hookVehicleSkinItem()
                return orig(self)
            end
        end

        local _lastVehicleSync = 0
        local function syncVehicleAvatarSkinList(force)
            if not force then
                local nowSync = 0
                pcall(function() nowSync = os.clock() end)
                if _lastVehicleSync > 0 and (nowSync - _lastVehicleSync) < 5.0 then return end
                _lastVehicleSync = nowSync
            end
            local pc = getPlayerController()
            if not pc or not slua.isValid(pc) then return end
            hookServerChangeVehicleAvatar(pc)
            hookVehicleSkinItem()
            hookVehicleSkinAndMusicPanel()
            hookVehicleLicenseComponentBase()
            hookVehiclePlateLicenseUtil()
            if pc.bEnableFuzzyAvatarOnClient then
                pc.bEnableFuzzyAvatarOnClient = false
            end
            if not DataMgr or not DataMgr.VehicleSlotList then return end
            if not pc.InitVehicleAvatarSkinList then return end
            local vehicleSkinData = {}
            for subType, insList in pairs(DataMgr.VehicleSlotList) do
                if insList and type(insList) == "table" then
                    local itemArray = {}
                    for _, insID in ipairs(insList) do
                        insID = tonumber(insID)
                        if insID and insID > 0 then
                            local skinResID = 0
                            if isInjectedIns(insID) then
                                skinResID = R.insToRes[insID] or 0
                            else
                                pcall(function()
                                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                                    local d = wd:GetHallDepotItemDataByInsID(insID)
                                    skinResID = d and tonumber(d.resID) or 0
                                end)
                            end
                            if skinResID and skinResID > 0 then
                                table.insert(itemArray, {ItemTableID = skinResID, Count = 1})
                            end
                        end
                    end
                    if #itemArray > 0 then
                        table.insert(vehicleSkinData, {Items = itemArray})
                    end
                end
            end
            if #vehicleSkinData > 0 then
                pc.InitialVehicleAvatarSkinList = vehicleSkinData
                pc:InitVehicleAvatarSkinList()
                -- Lobby: daftar avatar (bukan cuma skin list) yang membuat
                -- model kendaraan memakai skin tersebut.
                if isInLobby() then
                    local avatarList = {}
                    for _, entry in ipairs(vehicleSkinData) do
                        for _, item in ipairs(entry.Items or {}) do
                            avatarList[#avatarList + 1] = {
                                ItemTableID = item.ItemTableID,
                                Count = 1,
                            }
                        end
                    end
                    if #avatarList > 0 and pc.InitVehicleAvatarList then
                        pcall(function()
                            pc.InitialVehicleAvatarList = avatarList
                            pc:InitVehicleAvatarList()
                        end)
                    end
                end
            end
        end

        _G.AddOutfitSyncVehicleAvatarSkinList = syncVehicleAvatarSkinList

        local function stopMatchWatcher()
            if _S.matchTimer then
                pcall(function()
                    local char = getLocalChar()
                    if char and char.RemoveGameTimer then char:RemoveGameTimer(_S.matchTimer) end
                end)
                _S.matchTimer = nil
            end
            _S.matchOutfitDone = false
            _S.avatarItemsRegistered = false
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.lastAppliedWeaponID = 0
            _S.lastAppliedSkinID = 0
            _S.matchApplied = false
            _S.bootstrapped = false   -- إعادة ضبط bootstrap
        end

        local function bootstrapMatch(char)
            if _S.bootstrapped then return true end
            char = char or getLocalChar()
            if not char or not slua.isValid(char) then return false end
            snapshotLobbyWear()
            _S.weaponApplied = false
            _S.weaponDiagDone = false
            _S.matchOutfitDone = false
            if not _S.bootstrapNotified then
                _S.bootstrapNotified = true
                notify("اكتشفت شخصيتك في الماتش")
            end
            startMatchWatcher(char)
            hookPlayerWearingDone()
            matchApplyAll(char)
            _S.bootstrapped = true
            return true
        end

        local function isSelfAvatarComp(self)
            if not self or not self.IsSelf then return true end
            local ok, r = pcall(function() return self:IsSelf() end)
            return ok and r == true
        end

        local function hookMatchAvatar()
            pcall(function()
                if EventSystem and EventSystem.registEvent
                    and EVENTTYPE_PLAYEREVENT_AVATAR and EVENTID_LOCAL_PLAYEREVENT_AVATAR_ALL_MESH_LOADED then
                    EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_AVATAR, EVENTID_LOCAL_PLAYEREVENT_AVATAR_ALL_MESH_LOADED, function()
                        if isInLobby() then return end
                        local char = getLocalChar()
                        if char then
                            hookPlayerWearingDone()
                            applyMatchEquipAvatarToController()
                            matchApplyEquipSkins(char)
                        end
                    end)
                end
            end)
            pcall(function()
                local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
                if not CAC._lava_hooked_mesh then
                    CAC._lava_hooked_mesh = true
                    local o = CAC.OnAvatarAllMeshLoadedLua
                    CAC.OnAvatarAllMeshLoadedLua = function(self)
                        o(self)
                        pcall(function()
                            if self.IsLobbyActor and self:IsLobbyActor() then return end
                            if not (self.IsSelf and self:IsSelf()) then return end
                            local char = getLocalChar()
                            if char and char.AddGameTimer then
                                char:AddGameTimer(0.5, false, function() bootstrapMatch(char) end)
                            end
                        end)
                    end
                end
            end)
            pcall(function()
                local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
                local oLoad = WAC.OnWeaponAvatarLoadedLua
                WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
                    oLoad(self, slotID, definedID)
                    pcall(function()
                        if self.IsLobbyActor and self:IsLobbyActor() then return end
                        if not isSelfAvatarComp(self) then return end
                        if _S.globalFrame < _S.weaponHookGuardUntil then return end
                        local char = getLocalChar()
                        if not char then return end
                        bootstrapMatch(char)
                        _S.weaponApplied = false
                        if char.AddGameTimer then
                            char:AddGameTimer(0.2, false, function()
                                local c = getLocalChar()
                                if c then matchApplyWeaponSkin(c) end
                            end)
                            -- Extra delayed pass for attachment skins
                            char:AddGameTimer(0.5, false, function()
                                local c = getLocalChar()
                                if c then matchApplyWeaponSkin(c) end
                            end)
                        end
                    end)
                end
            end)
        end

        local function onWeaponLuaInit(_, _, weapon)
            if not weapon or not slua.isValid(weapon) then return end
            local char = getLocalChar()
            if not char then return end
            local owner = nil
            pcall(function() if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end end)
            if not slua.isValid(owner) or owner ~= char then return end
            if _S.globalFrame < _S.weaponHookGuardUntil then return end
            pcall(function()
                char:AddGameTimer(0.15, false, function()
                    if slua.isValid(weapon) then
                        applySkinToWeaponRef(weapon)
                        _S.weaponApplied = false
                    end
                end)
                -- Extra delayed pass for attachment skins
                char:AddGameTimer(0.5, false, function()
                    if slua.isValid(weapon) then
                        applySkinToWeaponRef(weapon)
                    end
                end)
            end)
        end

        local function hookWeaponSpawn()
            if _S.weaponSpawnHooked then return end
            pcall(function()
                if EventSystem and EventSystem.registEvent
                    and EVENTTYPE_PLAYEREVENT_WEAPON and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
                    EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, onWeaponLuaInit)
                    _S.weaponSpawnHooked = true
                end
            end)
        end

        local function hookLobbyWeaponCache()
            pcall(function()
                local Arm = require("client.logic.armory.logic_armory")
                local oRsp = Arm.install_weapon_skin_rsp
                Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
                    oRsp(client_data, errorCode, weapon_id, instanceID)
                    if errorCode == 0 or errorCode == _K.NET_OK then
                        cacheWeaponSkinFromIns(weapon_id, instanceID)
                    end
                end
            end)
            pcall(function()
                local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
                local o = wl.on_puton_rsp
                wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
                    o(self, res, item, olditem, index, extra)
                    if item and item.instid and (res == 0 or res == _K.NET_OK) then
                        local resID, insID = tonumber(item.res_id), tonumber(item.instid)
                        local slot = getEquipSkinSlot(resID)
                        if isInjectedIns(insID) and slot and not _S.equipSkinApplying then
                            saveEquipSkin(resID, insID)
                            if slot ~= "parachute" and slot ~= "glider" then
                                applyEquipVisual(resID, insID, slot)
                            end
                        elseif isInjectedIns(insID) then
                            local mt = wardrobeMainTab(resID)
                            if mt ~= _K.WARDROBE_PAGE_VEHICLE then
                                if isThrowObjectRes(resID) then
                                    saveThrowObject(resID, insID)
                                else
                                    saveEquip(resID, insID)
                                end
                            end
                        end
                    end
                end
            end)
        end

-- @RAHMANYVI
        local function hookGunWardrobe()
            pcall(function()
                local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                if wgl._lava_gun_hooked then return end
                wgl._lava_gun_hooked = true

                local origSetGunID = wgl.SetGunID
                wgl.SetGunID = function(self, weaponID, ...)
                    weaponID = tonumber(weaponID)
                    if not weaponID then return origSetGunID(self, weaponID, ...) end

                    local w = cache().weapons[weaponID]
                    local injected = w and w.insID and w.insID > 0 and isInjectedIns(w.insID)
-- @RAHMANYVI
                    local currentSkin = wgl.GetCurrentEquippedSkinInsID and wgl:GetCurrentEquippedSkinInsID(weaponID) or 0
                    if injected and currentSkin == w.insID then
-- @RAHMANYVI
                        return origSetGunID(self, weaponID, ...)
                    end

                    if injected then
                        pcall(function()
                            local Arm = require("client.logic.armory.logic_armory")
                            Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
                            Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
                            Arm.rsp_list.install_list[weaponID] = { skin_id = w.insID }
                            
                            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                            if fbd.UpdateCurrentFashionBagWeaponSkin then
                                fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, w.insID)
                            end
                            if fbd.SetFashionBagWeaponSkin then
                                fbd:SetFashionBagWeaponSkin(weaponID, w.insID)
                            end
                        end)
                    else
-- @RAHMANYVI
                        pcall(function()
                            local Arm = require("client.logic.armory.logic_armory")
                            if Arm.rsp_list and Arm.rsp_list.install_list then
                                Arm.rsp_list.install_list[weaponID] = nil
                            end
                            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                            if fbd.UpdateCurrentFashionBagWeaponSkin then
                                fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, 0)
                            end
                            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
                            if bag and bag.weapon_skin_list then
                                bag.weapon_skin_list[weaponID] = nil
                            end
                        end)
                    end

                    local result = origSetGunID(self, weaponID, ...)

                    if injected then
                        later(0.05, function()
                            pcall(function()
                                local wgl2 = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                                wgl2:UpdateCurrentGunAvatar(weaponID, w.insID)
                                
                                if EventSystem then
                                    if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                                        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, w.resID)
                                    end
                                    if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                                        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
                                    end
                                    if EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
                                        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, w.resID)
                                    end
                                end
                            end)
                        end)
-- @RAHMANYVI
                    else
-- @RAHMANYVI
                        later(0.05, function()
                            pcall(function()
                                local wgl2 = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                                wgl2:UpdateCurrentGunAvatar(weaponID, 0)
                                if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, 0)
                                end
                                if EventSystem and EVENTID_WARDROBE_UPDATE_GUN_LIST then
                                    EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, weaponID)
                                end
                            end)
                        end)
                        log("إزالة سكن السلاح", weaponID)
                    end
                    
                    return result
                end

                local origUpdateGunAvatar = wgl.UpdateCurrentGunAvatar
                wgl.UpdateCurrentGunAvatar = function(self, weaponID, insID, ...)
                    weaponID = tonumber(weaponID)
                    insID = tonumber(insID)
                    if weaponID and (not insID or insID <= 0) then
                        local w = cache().weapons[weaponID]
                        if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                            insID = w.insID
                            log("UpdateCurrentGunAvatar: استخدام سكن محفوظ", weaponID, insID)
                        else
                            insID = 0
                        end
                    end
                    return origUpdateGunAvatar(self, weaponID, insID, ...)
                end

                if wgl.GetCurrentEquippedSkinInsID then
                    local origGetCurSkin = wgl.GetCurrentEquippedSkinInsID
                    wgl.GetCurrentEquippedSkinInsID = function(self, weaponID, ...)
                        weaponID = tonumber(weaponID)
                        if weaponID then
                            local w = cache().weapons[weaponID]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return w.insID
                            end
                        end
                        return origGetCurSkin(self, weaponID, ...)
                    end
                end

                if wgl.GetGunSkinInsID then
                    local origGetGunSkin = wgl.GetGunSkinInsID
                    wgl.GetGunSkinInsID = function(self, weaponID, ...)
                        weaponID = tonumber(weaponID)
                        if weaponID then
                            local w = cache().weapons[weaponID]
                            if w and w.insID and w.insID > 0 and isInjectedIns(w.insID) then
                                return w.insID
                            end
                        end
                        return origGetGunSkin(self, weaponID, ...)
                    end
                end

                log("hookGunWardrobe: تم")
            end)
        end

        -- ========== Collection Ace Eliminator Broadcast (619150001) ==========
        local ELIMINATION_KING_EFFECT_ID = 619150001

        -- ========== Last Strike Champion Final Kill Effect (61950002) ==========
        local FINAL_KILL_EFFECT_ID = 61950002

        local function getLocalPlayerKey()
            local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
            if ok and GD and GD.GetPlayerState then
                local ps = GD.GetPlayerState()
                if ps and slua.isValid(ps) and ps.PlayerKey then
                    return tonumber(ps.PlayerKey)
                end
            end
            return nil
        end

        local function getLocalUID()
            local uid
            pcall(function()
                local Subsystem = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
                local AccountSubsystem = Subsystem:Get("AccountSubsystem")
                if AccountSubsystem and AccountSubsystem.GetAccountUID then
                    uid = AccountSubsystem:GetAccountUID()
                end
            end)
            if not uid then
                pcall(function()
                    local GD = require("GameLua.GameCore.Data.GameplayData")
                    local ps = GD.GetPlayerState()
                    if ps and slua.isValid(ps) and ps.UID then
                        uid = tonumber(ps.UID)
                    end
                end)
            end
            return uid
        end

        local function hookEliminationKingEffect()
            if _G._lava_hooked_elim_king then return end
            _G._lava_hooked_elim_king = true

            pcall(function()
                local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
                if CommerAvatarDataUtil._lava_hooked_ext_attr then return end
                CommerAvatarDataUtil._lava_hooked_ext_attr = true

                local ExtendAttribute = require("Server.config.ExtendAttribute")
                local origGetAttr = CommerAvatarDataUtil.GetPlayerExtendAttributeAndTest
                CommerAvatarDataUtil.GetPlayerExtendAttributeAndTest = function(self, UID, attr)
                    if attr == ExtendAttribute.EliminationKingEffect then
                        local localUID = getLocalUID()
                        if localUID and tonumber(UID) == tonumber(localUID) then
                            return ELIMINATION_KING_EFFECT_ID
                        end
                    end
                    return origGetAttr(self, UID, attr)
                end
                log("hookEliminationKingEffect: CommerAvatarDataUtil hooked")
            end)

            pcall(function()
                local KillInfoClass = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
                local impl = KillInfoClass.__inner_impl
                if not impl or impl._lava_hooked_show_king then return end
                impl._lava_hooked_show_king = true

                local origShow = impl.ShowKingEliminationInfo
                impl.ShowKingEliminationInfo = function(self, DamageRecordData)
                    local localKey = getLocalPlayerKey()
                    if localKey and DamageRecordData and DamageRecordData.ExpandDataContent then
                        pcall(function()
                            local FatalDamageInfo = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent)
                            if FatalDamageInfo and FatalDamageInfo.KingEliminationInfo then
                                local KingEliminationInfo = FatalDamageInfo.KingEliminationInfo
                                if KingEliminationInfo.NewKingEliminationInfo then
                                    local info = KingEliminationInfo.NewKingEliminationInfo
                                    if tonumber(info.PlayerKey) == localKey then
                                        info.EffectID = ELIMINATION_KING_EFFECT_ID
                                        log("hookEliminationKingEffect: injected EffectID into NewKingEliminationInfo")
                                    end
                                end
                                if KingEliminationInfo.DeadKingEliminationInfo then
                                    local info = KingEliminationInfo.DeadKingEliminationInfo
                                    if tonumber(info.KillerPlayerKey) == localKey then
                                        info.EffectID = ELIMINATION_KING_EFFECT_ID
                                        log("hookEliminationKingEffect: injected EffectID into DeadKingEliminationInfo")
                                    end
                                end
                            end
                        end)
                    end
                    return origShow(self, DamageRecordData)
                end
                log("hookEliminationKingEffect: KillInfo.ShowKingEliminationInfo hooked")
            end)

            pcall(function()
                local KingEliminationInfoItemClass = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KingEliminationInfoItem")
                local impl = KingEliminationInfoItemClass.__inner_impl
                if not impl or impl._lava_hooked_update then return end
                impl._lava_hooked_update = true

                local origUpdate = impl.UpdateKingEliminationInfo
                impl.UpdateKingEliminationInfo = function(self, DamageRecordData, KingEliminationInfo)
                    local localKey = getLocalPlayerKey()
                    if localKey and KingEliminationInfo then
                        if KingEliminationInfo.NewKingEliminationInfo then
                            local info = KingEliminationInfo.NewKingEliminationInfo
                            if tonumber(info.PlayerKey) == localKey then
                                info.EffectID = ELIMINATION_KING_EFFECT_ID
                            end
                        end
                        if KingEliminationInfo.DeadKingEliminationInfo then
                            local info = KingEliminationInfo.DeadKingEliminationInfo
                            if tonumber(info.KillerPlayerKey) == localKey then
                                info.EffectID = ELIMINATION_KING_EFFECT_ID
                            end
                        end
                    end
                    return origUpdate(self, DamageRecordData, KingEliminationInfo)
                end
                log("hookEliminationKingEffect: KingEliminationInfoItem hooked")
            end)

            pcall(function()
                local PlayerStateBaseClass = require("GameLua.GameCore.Framework.PlayerStateBase")
                local impl = PlayerStateBaseClass.__inner_impl
                if not impl or impl._lava_hooked_init_team then return end
                impl._lava_hooked_init_team = true

                local origInit = impl.InitTeamShowData
                impl.InitTeamShowData = function(self, ...)
                    origInit(self, ...)
                    pcall(function()
                        local localUID = getLocalUID()
                        if localUID and self.UID and tonumber(self.UID) == tonumber(localUID) then
                            self.EliminationKingEffectID = ELIMINATION_KING_EFFECT_ID
                        end
                    end)
                end
                log("hookEliminationKingEffect: PlayerStateBase hooked")
            end)
        end

        local function tickEliminationKingEffect()
            pcall(function()
                local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
                if ok and GD and GD.GetPlayerState then
                    local ps = GD.GetPlayerState()
                    if ps and slua.isValid(ps) then
                        if not ps.EliminationKingEffectID or ps.EliminationKingEffectID == 0 then
                            ps.EliminationKingEffectID = ELIMINATION_KING_EFFECT_ID
                        end
                    end
                end
            end)
        end

        -- ========== Last Strike Champion Final Kill Effect (61950002) ==========
        local function hookFinalKillEffect()
            if _G._lava_hooked_final_kill then return end
            _G._lava_hooked_final_kill = true

            -- 1. Hook FinalKillEffectLevelSequenceActor to handle missing config for 61950002
            -- If config doesn't exist or Sequence is empty, directly call OnPlay callback
            pcall(function()
                local LSActor = require("GameLua.Mod.Library.GamePlay.Actor.FinalKillEffectLevelSequenceActor")
                if LSActor._lava_hooked then return end
                LSActor._lava_hooked = true

                local origBeginPlay = LSActor.ReceiveBeginPlay
                if origBeginPlay then
                    LSActor.ReceiveBeginPlay = function(self)
                        if self.ItemId == FINAL_KILL_EFFECT_ID then
                            local Config = CDataTable.GetTableData("FinalKillEffectCfg", self.ItemId)
                            if not Config or not Config.Sequence or Config.Sequence == "" then
                                log("hookFinalKillEffect: no sequence for 61950002, calling OnPlay directly")
                                if self.Callback and self.Callback.OnPlay then
                                    self.Callback.OnPlay()
                                end
                                return
                            end
                        end
                        return origBeginPlay(self)
                    end
                    log("hookFinalKillEffect: FinalKillEffectLevelSequenceActor hooked")
                end
            end)

            -- 2. Hook TriggerParticleEffect to force ItemId = 61950002
            pcall(function()
                local Feature = require("GameLua.Mod.BaseMod.GamePlay.Feature.Player.PlayerCharacterFinalKillEffectFeature")
                if Feature._lava_hooked_fke then return end
                Feature._lava_hooked_fke = true

                local origTriggerParticle = Feature.TriggerParticleEffect
                if origTriggerParticle then
                    Feature.TriggerParticleEffect = function(self, ItemId, Location, Rotator, TeamMemberNames)
                        log("hookFinalKillEffect: TriggerParticleEffect called, ItemId=" .. tostring(ItemId) .. " forcing to " .. tostring(FINAL_KILL_EFFECT_ID))
                        return origTriggerParticle(self, FINAL_KILL_EFFECT_ID, Location, Rotator, TeamMemberNames)
                    end
                end

                local origPrepareItem = Feature.PrepareItem
                if origPrepareItem then
                    Feature.PrepareItem = function(self, ItemId)
                        log("hookFinalKillEffect: PrepareItem called, ItemId=" .. tostring(ItemId) .. " forcing to " .. tostring(FINAL_KILL_EFFECT_ID))
                        return origPrepareItem(self, FINAL_KILL_EFFECT_ID)
                    end
                end
                log("hookFinalKillEffect: PlayerCharacterFinalKillEffectFeature hooked")
            end)

            -- 3. Direct client-side trigger when game ends
            local function triggerFinalKillEffect()
                pcall(function()
                    local char = getLocalChar()
                    if not char or not slua.isValid(char) then
                        log("hookFinalKillEffect: char not valid")
                        return
                    end

                    if _G._lava_fke_triggered then return end
                    _G._lava_fke_triggered = true

                    char:EnsureDynamicFeature("FinalKillEffect")
                    if not char.FinalKillEffect then
                        log("hookFinalKillEffect: FinalKillEffect feature not available")
                        return
                    end

                    local Location = char:K2_GetActorLocation()
                    local Rotator = FRotator(0, 0, 0)
                    local Names = char.PlayerName or ""

                    log("hookFinalKillEffect: triggering effect 61950002")
                    char.FinalKillEffect:TriggerParticleEffect(FINAL_KILL_EFFECT_ID, Location, Rotator, Names)
                end)
            end

            -- 3a. Hook BattleResult.on_game_result (global function, client-side)
            pcall(function()
                if BattleResult and BattleResult.on_game_result and not BattleResult._lava_hooked_fke then
                    BattleResult._lava_hooked_fke = true
                    local origOnGameResult = BattleResult.on_game_result
                    BattleResult.on_game_result = function(battle_result, result)
                        log("hookFinalKillEffect: BattleResult.on_game_result triggered")
                        triggerFinalKillEffect()
                        return origOnGameResult(battle_result, result)
                    end
                    log("hookFinalKillEffect: BattleResult.on_game_result hooked")
                end
            end)

            -- 3b. Hook BattleResult.on_game_over (global function, client-side)
            pcall(function()
                if BattleResult and BattleResult.on_game_over and not BattleResult._lava_hooked_fke_over then
                    BattleResult._lava_hooked_fke_over = true
                    local origOnGameOver = BattleResult.on_game_over
                    BattleResult.on_game_over = function(game_id)
                        log("hookFinalKillEffect: BattleResult.on_game_over triggered")
                        triggerFinalKillEffect()
                        return origOnGameOver(game_id)
                    end
                    log("hookFinalKillEffect: BattleResult.on_game_over hooked")
                end
            end)

            -- 3c. Also register for the event as backup (with nil checks)
            pcall(function()
                if EventSystem and EventSystem.registEvent
                    and EVENTTYPE_STATE and EVENTID_GAMESTATE_ON_PRE_BATTLE_RESULT
                    and not _G._lava_fke_event_registered then
                    _G._lava_fke_event_registered = true
                    EventSystem:registEvent(EVENTTYPE_STATE, EVENTID_GAMESTATE_ON_PRE_BATTLE_RESULT, triggerFinalKillEffect)
                    log("hookFinalKillEffect: registered for EVENTID_GAMESTATE_ON_PRE_BATTLE_RESULT")
                end
            end)

            log("hookFinalKillEffect: done")
        end

-- @RAHMANYVI
        -- ===================================================================
        -- SECURITY: ANTI-CHEAT BYPASS (from 2.lua Section 19)
        -- ===================================================================
        local function hookSecurityBypass()
            -- 1. Disable puffer download reporting
            pcall(function()
                local pufferTlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
                if pufferTlog then
                    pufferTlog.ReportEvent = function() end
                    pufferTlog.ReportDownloadResult = function() end
                    pufferTlog.ReportODPAKError = function() end
                end
            end)

            -- 2. Bypass AvatarUtils weapon blacklist
            pcall(function()
                local AvatarUtils = package.loaded["AvatarUtils"]
                if AvatarUtils then
                    AvatarUtils.CheckIsWeaponInBlackList = function() return false end
                    AvatarUtils.IsValidAvatar = function() return true end
                end
            end)

            -- 3. Disable file integrity checking
            pcall(function()
                local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
                if SubsystemMgr then
                    local FileCheckSubsystem = SubsystemMgr:Get("FileCheckSubsystem")
                    if FileCheckSubsystem then
                        FileCheckSubsystem.StartCheck = function() end
                        FileCheckSubsystem.ReportAbnormalFile = function() end
                    end
                end
            end)

            -- 4. Disable equipment exception reporting
            pcall(function()
                local equipReport = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
                if equipReport then
                    equipReport.Report = function() end
                end
            end)

            -- 5. Disable puffer download validation
            pcall(function()
                local pufferManager = require("client.slua.logic.download.puffer.puffer_manager")
                local pufferConst = require("client.slua.logic.download.puffer_const")
                if pufferManager and pufferConst then
                    local origCheck = pufferManager.CheckResourceValid
                    if origCheck then
                        pufferManager.CheckResourceValid = function(...) return true end
                    end
                end
            end)

            -- 6. Bypass avatar hash verification
            pcall(function()
                local AvatarUtils = package.loaded["AvatarUtils"]
                if AvatarUtils then
                    local origVerify = AvatarUtils.VerifyAvatarData
                    if origVerify then
                        AvatarUtils.VerifyAvatarData = function(...) return true end
                    end
                end
            end)

            print("[AddOutfit] Security bypass installed")
        end

        -- ===================================================================
        -- DEATHBOX / CORPSE BOX (logika dari 1.lua)
        -- Kotak kematian memakai skin senjata / kendaraan yang dipakai.
        -- ===================================================================
        local cached_GameplayStatics = nil
        local cached_PlayerTombBox = nil
        local cached_ActorClass = nil
        _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer or 0

        local function currentSuitSkinID()
            local cch = _G.AddOutfitEquippedCache
            local res = cch and tonumber(cch.outfitRes) or 0
            if res and res > 0 then return res end
            return tonumber(_G._savedOutfitRes) or 0
        end

        _G.DeadBox_TemperRequest = function(PlayerController)
            if (_G.NeedCheckDeadBoxTimer or 0) <= 0 then return end

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

            local myPlayerKey = PlayerController.PlayerKey
            local currentBoxSkinId = 0
            pcall(function()
                local curVeh = PlayerCharacter.CurrentVehicle
                    or (type(PlayerCharacter.GetCurrentVehicle) == "function" and PlayerCharacter:GetCurrentVehicle())
                if slua.isValid(curVeh) then
                    local vehSkin = getVehicleSkinID(curVeh)
                    if vehSkin and vehSkin > 0 then
                        currentBoxSkinId = tonumber(tostring(vehSkin) .. "1") or 0
                    end
                else
                    local curWeapon = PlayerCharacter.GetCurrentWeapon and PlayerCharacter:GetCurrentWeapon()
                        or PlayerCharacter.CurrentWeapon
                    if slua.isValid(curWeapon) then
                        local defineIDObj = curWeapon.GetItemDefineID and curWeapon:GetItemDefineID()
                        local curWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
                        if curWeaponID > 0 and _G.AddOutfitLastAppliedSkin
                            and _G.AddOutfitLastAppliedSkin[curWeaponID] then
                            local skinID = _G.AddOutfitLastAppliedSkin[curWeaponID]
                            if skinID and skinID > 1000000 then
                                currentBoxSkinId = skinID
                            end
                        end
                    end
                end
            end)

            if currentBoxSkinId == 0 then return end

            local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(
                GameInstance, cached_PlayerTombBox, _G.CachedActorArray_DB)
            if not deadBoxes then return end

            local count = type(deadBoxes.Num) == "function" and deadBoxes:Num() or #deadBoxes
            for i = 1, count do
                local deadBoxActor = type(deadBoxes.Get) == "function" and deadBoxes:Get(i - 1) or deadBoxes[i]
                if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
                    local damageCauser = deadBoxActor.DamageCauser
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

        -- Data kill count dipakai kill message dan UI kill counter.
        -- Preset sama seperti 1.lua + default 0 untuk senjata lain.
        if not _G.killCountInfo then
            _G.killCountInfo = setmetatable({
                [101001] = 0, [101004] = 0, [101003] = 0, [103001] = 0,
                [102001] = 0, [105001] = 0, [102002] = 0, [103002] = 0,
            }, { __index = function() return 0 end })
        end
        function _G.saveKillCountToFile() end
        function _G.loadKillCountFromFile() end
        function _G.addKill(weaponID, count)
            if not weaponID or not count then return end
            _G.killCountInfo[weaponID] = (_G.killCountInfo[weaponID] or 0) + count
            _G.saveKillCountToFile()
        end
        function _G.getKills(weaponID)
            return weaponID and _G.killCountInfo[weaponID] or 0
        end

        -- ===================================================================
        -- KILL COUNTER (logika dari 1.lua)
        -- 1. UI kill counter: MainKillCounter + KillCounterUISubsystem.
        -- 2. Kill feed + deadbox + hitung kill (KillInfo.FileItem).
        -- ===================================================================
        local _killCounterHooked = false
        local _safeRequireCache = {}
        local function safeRequire(name)
            if _safeRequireCache[name] then return _safeRequireCache[name] end
            local loaded = package.loaded[name]
            if loaded then _safeRequireCache[name] = loaded; return loaded end
            local ok, mod = pcall(require, name)
            if ok and mod then _safeRequireCache[name] = mod; return mod end
            return nil
        end

        local function hookKillMessages()
            if _killCounterHooked then return end
            local anyHooked = false

            -- 1. Kill Counter UI hooks (1.lua)
            pcall(function()
                local MyMainKillCounter = safeRequire("GameLua.Mod.BaseMod.Client.KillCounter.MainKillCounter")
                local MyKillCountSubSystem = safeRequire("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
                local ModuleManager = safeRequire("client.module_framework.ModuleManager")
                local UIManager = safeRequire("client.slua_ui_framework.manager")

                if not (MyKillCountSubSystem and MyKillCountSubSystem.__inner_impl
                        and ModuleManager and UIManager) then return end

                _G.OurkillCountSystem = MyKillCountSubSystem.__inner_impl

                if MyMainKillCounter and MyMainKillCounter.__inner_impl then
                    MyMainKillCounter.__inner_impl.OnRefreshUI = function(self, _, _, UID)
                        local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                        if not LogicKillCounter then return end

                        local hud = slua_GameFrontendHUD
                        local pc = hud and hud:GetPlayerController()
                        local uCharacter = pc and pc.GetPlayerCharacterSafety and pc:GetPlayerCharacterSafety()
                        if not uCharacter or not slua.isValid(uCharacter) then return end

                        local currweapon = uCharacter:GetCurrentWeapon()
                        if currweapon ~= nil then
                            local defineID = currweapon:GetItemDefineID()
                            local DefineID = (defineID and slua.isValid(defineID)) and defineID.TypeSpecificID or 0
                            local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                            local SkinID = (synDataRef and slua.isValid(synDataRef)) and synDataRef.TypeSpecificID or 0
                            local curEquipedKillCounter = LogicKillCounter.GetEquipedKillCounterId
                                and LogicKillCounter:GetEquipedKillCounterId(6114302174, self.WeaponID) or nil
                            if self.KillCounterItem then
                                self.KillCounterItem:SetKillCounterItemShowWithNum(
                                    curEquipedKillCounter, _G.getKills(DefineID), SkinID)
                            end
                        end
                    end
                end

                MyKillCountSubSystem.__inner_impl.CheckSupportKCUI = function(self) return true end

                local o_UpdateMainKillCounterUI = MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI
                MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
                    if o_UpdateMainKillCounterUI then
                        pcall(o_UpdateMainKillCounterUI, self, bShow, WeaponID, AvatarID)
                    end

                    local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                    local hud = slua_GameFrontendHUD
                    local pc = hud and hud:GetPlayerController()
                    local uCharacter = pc and pc.GetPlayerCharacterSafety and pc:GetPlayerCharacterSafety()
                    if not uCharacter or not slua.isValid(uCharacter) then return end
                    local currweapon = uCharacter:GetCurrentWeapon()

                    if not bShow and MainKillCounter then
                        UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
                    elseif bShow and currweapon ~= nil then
                        local defineID = currweapon.GetItemDefineID and currweapon:GetItemDefineID()
                        local DefineID = (defineID and slua.isValid(defineID)) and defineID.TypeSpecificID or 0
                        local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                        local currentEquipAvatrid = (synDataRef and slua.isValid(synDataRef))
                            and synDataRef.TypeSpecificID or 0
                        local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                        if not LogicKillCounter then return end

                        local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                        local curEquipedKillCounter = LogicKillCounter.GetEquipedKillCounterId
                            and LogicKillCounter:GetEquipedKillCounterId(6114302174, currentEquipAvatrid) or nil

                        -- Skin mod punya ID > 1.000.000; senjata normal tidak.
                        local isModdedSkin = (currentEquipAvatrid and currentEquipAvatrid > 1000000)

                        if (SupportKillCounter == nil or not isModdedSkin) then
                            if MainKillCounter then
                                UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
                            end
                        else
                            if not MainKillCounter then
                                UIManager.ShowUI(UIManager.UI_Config_InGame.MainKillCounter, DefineID, currentEquipAvatrid)
                                MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                                if MainKillCounter then
                                    MainKillCounter:SetKillCounterItemShowWithNum(
                                        curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                                end
                            else
                                MainKillCounter:UpdateWeaponID(DefineID, currentEquipAvatrid)
                                MainKillCounter:SetKillCounterItemShowWithNum(
                                    curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                            end
                        end
                    end
                end

                MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI = function(self, Weapon, PlayerID)
                    local hud = slua_GameFrontendHUD
                    local pc = hud and hud:GetPlayerController()
                    local uCharacter = pc and pc.GetPlayerCharacterSafety and pc:GetPlayerCharacterSafety()
                    if not uCharacter or not slua.isValid(uCharacter) then return end

                    local currweapon = uCharacter:GetCurrentWeapon()
                    if currweapon ~= nil then
                        local defineID = currweapon.GetItemDefineID and currweapon:GetItemDefineID()
                        local DefineID = (defineID and slua.isValid(defineID)) and defineID.TypeSpecificID or 0
                        local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                        local SkinID = (synDataRef and slua.isValid(synDataRef)) and synDataRef.TypeSpecificID or 0
                        self:UpdateMainKillCounterUI(true, DefineID, SkinID)
                    end
                end

                anyHooked = true
            end)

            -- 2. Kill Info Message hook — skin kill feed, hitung kill, deadbox.
            --    Logika dari 1.lua (kendaraan, kill counter).
            pcall(function()
                local KillInfo = safeRequire("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
                if not (KillInfo and KillInfo.__inner_impl and KillInfo.__inner_impl.FileItem) then return end

                local ModuleManager = safeRequire("client.module_framework.ModuleManager")
                local ECharacterHealthStatus = import("ECharacterHealthStatus")
                local o_FileItem = KillInfo.__inner_impl.FileItem

                local function patchKillRecord(self, DamageRecordData)
                    local LogicKillCounter = ModuleManager
                        and ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                    if not LogicKillCounter then return end

                    local uCharacter = slua_GameFrontendHUD
                        and slua_GameFrontendHUD:GetPlayerController()
                        and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
                    if not uCharacter or not slua.isValid(uCharacter) then return end

                    local SelfName = uCharacter:GetPlayerNameSafety()
                    if DamageRecordData.Causer ~= SelfName then return end

                    if DamageRecordData.DamageType == UEnums.DamageType.VehicleDamage then
                        local carSkinID = 0
                        pcall(function()
                            local curVeh = uCharacter.CurrentVehicle
                                or (type(uCharacter.GetCurrentVehicle) == "function" and uCharacter:GetCurrentVehicle())
                            if slua.isValid(curVeh) then
                                carSkinID = getVehicleSkinID(curVeh) or 0
                            end
                        end)
                        if carSkinID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            ExpandData.CauserVehicleSkinID = carSkinID
                            pcall(function() self:ChangeInfoBgByWeaponAvatarIDLua(carSkinID) end)
                            DamageRecordData.CauserWeaponAvatarID = carSkinID
                            DamageRecordData.CauserClothAvatarID = currentSuitSkinID()
                            DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                        end
                        return
                    end

                    if DamageRecordData.CauserWeaponAvatarID == 69
                        or DamageRecordData.CauserClothAvatarID == 69 then
                        return
                    end

                    local currWeapon = uCharacter:GetCurrentWeapon()
                    if not currWeapon or not slua.isValid(currWeapon) then return end

                    local defineID = currWeapon:GetItemDefineID()
                    local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                    if DefineID == 0 then return end

                    local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                    local hasChanged = false

                    local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                    if SupportKillCounter
                        and DamageRecordData.ResultHealthStatus == ECharacterHealthStatus.FinishedLastBreath then
                        local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
                        local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0

                        -- Hanya skin VIP/mod (ID > 1.000.000) yang dihitung.
                        if SkinID > 1000000 then
                            ExpandData.KillCounterItemId = DefineID
                            ExpandData.KillCounterNum = (ExpandData.KillCounterNum or 0) + 1
                            _G.addKill(DefineID, 1)
                            _G.NeedCheckDeadBoxTimer = 5
                            hasChanged = true
                        end
                    end

                    _G.UpdateMyKillCounter = true
                    local synData = currWeapon.synData
                    if synData and slua.isValid(synData) then
                        local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                        if weaponDefineID and slua.isValid(weaponDefineID) then
                            DamageRecordData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                        end
                    end
                    DamageRecordData.CauserClothAvatarID = currentSuitSkinID()
                    DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                    if hasChanged then _G.UpdateMyKillCounter = true end
                end

                KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                    if not self or not DamageRecordData then
                        return o_FileItem(self, DamageRecordData)
                    end
                    pcall(patchKillRecord, self, DamageRecordData)
                    return o_FileItem(self, DamageRecordData)
                end
                anyHooked = true
            end)

            -- 4. Weapon Slot Mode 2 - Kill Counter Icon
            pcall(function()
                local SlotMode2 = safeRequire("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
                if SlotMode2 and SlotMode2.__inner_impl then
                    local origCheck = SlotMode2.__inner_impl.CheckShowKCIcon
                    SlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                        if self.KillCounterImg and slua.isValid(self.KillCounterImg) then
                            self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible)
                        end
                        if origCheck then return origCheck(self) end
                    end
                    local origShow = SlotMode2.__inner_impl.ShowKCIcon
                    if origShow then
                        SlotMode2.__inner_impl.ShowKCIcon = function(self, weaponID, skinID)
                            local cnt = _G.getKills(weaponID) or 0
                            if origShow then origShow(self, weaponID, skinID) end
                            if cnt > 0 then
                                pcall(function()
                                    if self.KillCounterImg and self.KillCounterImg.SetKillCount then
                                        self.KillCounterImg:SetKillCount(cnt)
                                    end
                                end)
                            end
                        end
                    end
                    anyHooked = true
                end
            end)

            if anyHooked then _killCounterHooked = true end
        end

        -- 3. Loop kill counter (1.lua): update hanya saat ganti senjata atau
        --    tepat setelah kill, supaya tidak memanggil SLUA tiap tick.
        local _lastKCWeaponID = 0
        local _lastKCSkinID = 0

        _G.GameAvatarHandlerkillcounter = function()
            local UIManager = safeRequire("client.slua_ui_framework.manager")
            local hud = slua_GameFrontendHUD
            local PlayerController = hud and hud:GetPlayerController()
            if not PlayerController or not slua.isValid(PlayerController) then return end

            local uCharacter = PlayerController:GetPlayerCharacterSafety()
            if not uCharacter or not slua.isValid(uCharacter) then return end

            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon and slua.isValid(currweapon) then
                local defineIDObj = currweapon.GetItemDefineID and currweapon:GetItemDefineID()
                local currentWeaponID = (defineIDObj and slua.isValid(defineIDObj))
                    and defineIDObj.TypeSpecificID or 0

                -- Skin dari cache V7.5 (tanpa panggilan SLUA).
                local currentSkinID = 0
                if _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[currentWeaponID] then
                    currentSkinID = _G.AddOutfitLastAppliedSkin[currentWeaponID]
                end

                if _G.UpdateMyKillCounter
                    or currentWeaponID ~= _lastKCWeaponID
                    or currentSkinID ~= _lastKCSkinID then
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
                local MainKillCounter = UIManager
                    and UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                if MainKillCounter then
                    UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
                end
            end
        end

        local function startKillCounterLoop()
            if _G.AddOutfitKillCounterLoopStarted then return end
            if not (_ticker and _ticker.AddTimerLoop) then return end
            _G.AddOutfitKillCounterLoopStarted = true
            local ok = pcall(_ticker.AddTimerLoop, 0, _G.GameAvatarHandlerkillcounter, -1, 0.5)
            if ok then
                print("[AddOutfit] Kill counter loop started")
            else
                _G.AddOutfitKillCounterLoopStarted = false
            end
        end

        -- ===================================================================
        -- TEAM BROADCAST KILL MESSAGES (logika dari 1.lua)
        -- Menampilkan skin senjata/kendaraan di notifikasi kill tim.
        -- ===================================================================
        local _teamBroadcastHooked = false
        local _cachedMyName = nil
        local _downloadedAssetsCache = {}

        local function isMyBroadcast(data)
            if not data then return false end
            if data.bIamCauser then return true end
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
            return data.Causer == _cachedMyName
                or data.CauserRealPlayerName == _cachedMyName
                or data.CauserPlayerName == _cachedMyName
        end

        local function getCurrentWeaponSkinID()
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
                    if skinID > 1000000 then currentSkinID = skinID end
                end)
                return currentSkinID
            end
            return 0
        end

        local function downloadTeamAssets(skinID)
            if not skinID or skinID == 0 or skinID == 69 then return end
            if _downloadedAssetsCache[skinID] then return end
            _downloadedAssetsCache[skinID] = true

            pcall(function()
                local PufferManager = require("client.slua.logic.download.puffer.puffer_manager")
                local PufferConst = require("client.slua.logic.download.puffer_const")
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {skinID})

                local cfg2 = CDataTable.GetTableData("TeamKillBroadcast", skinID)
                if cfg2 then
                    if cfg2.EffectPath and cfg2.EffectPath ~= "" then
                        PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg2.EffectPath})
                    end
                    if cfg2.BgPath and cfg2.BgPath ~= "" then
                        PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg2.BgPath})
                    end
                end
            end)
        end

        local function patchTeamKill(messageData)
            if not messageData or not isMyBroadcast(messageData) then return messageData end
            local currentSkinID = getCurrentWeaponSkinID()
            if not currentSkinID or currentSkinID == 0 or currentSkinID == 69 then return messageData end
            local broadcastCfg = CDataTable.GetTableData("TeamKillBroadcast", currentSkinID)
            if not broadcastCfg or (not broadcastCfg.BgPath and not broadcastCfg.EffectPath) then
                return messageData
            end
            pcall(function()
                local exp = slua.LuaArchiverDecode(LuaStateWrapper, messageData.ExpandDataContent) or {}
                exp.CauserWeaponAvatarID = currentSkinID
                messageData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, exp)
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
                if not impl2[key] then
                    impl2[key] = impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable
                end
                local O_Copy = impl2[key]
                impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
                    local copied = O_Copy(self, messageData)
                    local ok2, result = pcall(patchTeamKill, copied)
                    if ok2 then return result end
                    return copied
                end
                _teamBroadcastHooked = true
            end
            pcall(function()
                wrapCopy(require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "base")
            end)
            pcall(function()
                wrapCopy(require("GameLua.Mod.SingleTraining.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "training")
            end)
            if _teamBroadcastHooked then
                print("[AddOutfit] Team broadcast kill messages hooked")
            end
        end

                local function start()
            log("AddOutfit Merged start")
            -- Security bypass first
            pcall(hookSecurityBypass)
            -- Kill message system + kill counter loop (1.lua)
            pcall(hookKillMessages)
            pcall(startKillCounterLoop)
            -- Team broadcast kill messages (logika 1.lua)
            pcall(installTeamBroadcastHooks)
            buildSkinMappings()
            pcall(restorePersistedVehicles)
            pcall(restorePersistedMotions)
            pcall(restorePersistedEquipIns)
            pcall(restorePersistedThrowObjects)
            pcall(restorePersistedHallTheme)
            pcall(syncMatchConfigFromCache)
            hookCDataTableCache()
            hookDepotInit()
            hookWardrobeData()
            hookPageFilter()
            hookArmory()
            hookPutOn()
            hookLobbyTheme()
            hookMotionEquip()
            hookIngameEmote()
            hookFashionBag()
            hookBackpackValid()
            hookAvatarValid()
            hookEquipMapping()
            hookLobbyWeaponCache()
            hookGunWardrobe()
            hookLobbySwipePersistence()
            hookMatchAvatar()
            hookMatchAvatarData()
            hookGrenadeAvatarInit()
            hookGrenadeAvatarLookup()
            hookProjectileGrenadeAvatar()
            hookWeaponSpawn()
            hookVehicleLicenseComponentBase()
            hookVehiclePlateLicenseUtil()
            hookBackpackWeaponAvatarRes()
            hookEliminationKingEffect()
            hookFinalKillEffect()

            if injectAllSources() then
                refreshWardrobe()
                -- Peta res->ins baru terisi sekarang; resolve persistensi.
                pcall(applyLoadedOutfitFromDisk)
                later(1.0, reapplyLobbyEquipped)
            else
                local tries = 0
                local function retry()
                    tries = tries + 1
                    if injectAllSources() then
                        refreshWardrobe()
                        pcall(applyLoadedOutfitFromDisk)
                        later(1.0, reapplyLobbyEquipped)
                        return
                    end
                    if tries < 40 then later(1.5, retry) end
                end
                later(1.5, retry)
            end

            pcall(function()
                if isInGamePlay() then
                    local char = getLocalChar()
                    if char then bootstrapMatch(char) end
                elseif isInLobby() then
                    snapshotLobbyWear()
                end
            end)
        end

        hookBackpackValid()
        hookEquipMapping()
        hookMatchAvatar()
        hookMatchAvatarData()
        hookGrenadeAvatarInit()
        hookGrenadeAvatarLookup()
        hookProjectileGrenadeAvatar()
        hookWeaponSpawn()
        hookBackpackWeaponAvatarRes()
        hookEliminationKingEffect()
        hookFinalKillEffect()
        pcall(_loadEquippedCache)
        -- Terapkan isi rapzhang_outfit.json ke cache runtime. Dipanggil sebelum
        -- start() dan diulang berkala: peta res->ins baru lengkap setelah
        -- injectAllSources(), jadi ins yang belum ketemu di-resolve lagi.
        local _persistAppliedOnce = false
        local function applyLoadedOutfitFromDisk()
            local saved = _G.AddOutfitPendingPersist
            if type(saved) ~= "table" then return false end
            local cch = cache()
            cch.clothes = cch.clothes or {}
            cch.equip = cch.equip or {}
            cch.weapons = cch.weapons or {}
            cch.throwObjects = cch.throwObjects or {}
            local RR = _G.AddOutfit_R

            -- Sekali di awal: JSON jadi sumber kebenaran untuk cache runtime.
            if not _persistAppliedOnce then
                local outfitRes = tonumber(saved.outfit)
                if outfitRes and outfitRes > 0 then
                    cch.outfitRes = outfitRes
                    _G.AddOutfitLastLobbyOutfitRes = outfitRes
                end
                for _, key in ipairs({ "tshirt", "pants", "shoes", "hat", "mask", "glass", "gloves" }) do
                    local res = tonumber(saved[key])
                    if res and res > 0 then cch.clothes[res] = true end
                end
                for res in pairs(saved.clothes or {}) do
                    local n = tonumber(res)
                    if n and n > 0 and (not _itemConf(n) or _clothSlotOf(n)) then
                        cch.clothes[n] = true
                    end
                end
                for _, slot in ipairs(EQUIP_SLOTS) do
                    local res = tonumber(saved[slot])
                    if res and res > 0 then cch.equip[slot] = res end
                end
                for wid, res in pairs(saved.weapons or {}) do
                    local widN, resN = tonumber(wid), tonumber(res)
                    if widN and resN and resN > 0 then
                        local entry = cch.weapons[widN]
                        if type(entry) ~= "table" then entry = {}; cch.weapons[widN] = entry end
                        entry.resID = resN
                    end
                end
                local meleeRes = tonumber(saved.melee
                    and (saved.melee.pan or saved.melee.dagger or saved.melee.machete))
                if meleeRes and meleeRes > 0 then
                    cch.weapons[108] = cch.weapons[108] or {}
                    cch.weapons[108].resID = meleeRes
                end
                for st, res in pairs(saved.throwObjects or {}) do
                    local stN, resN = tonumber(st), tonumber(res)
                    if stN and resN and resN > 0 then
                        local entry = cch.throwObjects[stN]
                        if type(entry) ~= "table" then entry = {}; cch.throwObjects[stN] = entry end
                        entry.resID = resN
                    end
                end
            end

            local function insFor(res)
                res = tonumber(res)
                if not res or res <= 0 then return nil end
                local ins = R.resToIns[res] or (RR and RR.resToIns and RR.resToIns[res])
                ins = tonumber(ins)
                if ins and ins > 0 then
                    R.resToIns[res] = ins
                    R.insToRes[ins] = res
                    if RR then
                        RR.resToIns[res] = ins
                        RR.insToRes[ins] = res
                    end
                    return ins
                end
                return nil
            end

            if cch.outfitRes and cch.outfitRes > 0
                and (not cch.outfitIns or cch.outfitIns <= 0) then
                local ins = insFor(cch.outfitRes)
                if ins then cch.outfitIns = ins end
            end
            for resID in pairs(cch.clothes or {}) do
                insFor(resID)
            end
            for _, slot in ipairs(EQUIP_SLOTS) do
                local res = tonumber(cch.equip and cch.equip[slot])
                if res and res > 0 then
                    if not cch.equip[slot .. "Ins"] or cch.equip[slot .. "Ins"] <= 0 then
                        local ins = insFor(res)
                        if ins then cch.equip[slot .. "Ins"] = ins end
                    end
                end
            end
            for _, w in pairs(cch.weapons or {}) do
                local res = tonumber(w and w.resID)
                if res and res > 0 and (not w.insID or w.insID <= 0) then
                    local ins = insFor(res)
                    if ins then w.insID = ins end
                end
            end
            for _, info in pairs(cch.throwObjects or {}) do
                local res = tonumber(info and info.resID)
                if res and res > 0 and (not info.insID or info.insID <= 0) then
                    local ins = insFor(res)
                    if ins then info.insID = ins end
                end
            end

            local vehSaved = saved.vehicleSlots
            if type(vehSaved) == "table" and not _G.AddOutfitVehicleSlotsApplied then
                local resolved = {}
                for st, slotMap in pairs(vehSaved) do
                    local stN = tonumber(st)
                    local list = {}
                    if stN and type(slotMap) == "table" then
                        for idx, res in pairs(slotMap) do
                            local ins = insFor(res)
                            if ins then list[tonumber(idx) or (#list + 1)] = ins end
                        end
                        if next(list) then
                            resolved[stN] = list
                            if DataMgr then
                                DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
                                DataMgr.VehicleSlotList[stN] = list
                            end
                        end
                    end
                end
                if next(resolved) then
                    _G._savedVehicleSlotList = resolved
                    _G.AddOutfitVehicleSlotsApplied = true
                end
            end

            syncMatchConfigFromCache()
            _persistAppliedOnce = true
            return true
        end
        _G.AddOutfitApplyPersist = applyLoadedOutfitFromDisk
        pcall(applyLoadedOutfitFromDisk)
        start()

        pcall(hookVehicleSkinAndMusicPanel)

        -- Time-based application loop (replaces frame-based tick listener)
        -- Uses os.clock() for time tracking instead of frame counting
        local _lastTickTime = os.clock()
        local _timeCount = 0
        
        -- Cek apakah outfit yang menempel di karakter masih sesuai JSON.
        -- Kalau game menimpanya dengan item asli, apply ulang.
        local function matchOutfitNeedsReapply(char)
            local okCall, need = pcall(function()
                if not char or not slua.isValid(char) then return false end
                local desired = desiredClothSlots()
                if next(desired) == nil then return false end
                local checked, matched = 0, 0
                for slotID, resID in pairs(desired) do
                    checked = checked + 1
                    local cur = getCharEquipLevel(char, slotID)
                    -- Slot yang kosong/terhapus juga dihitung tidak cocok,
                    -- supaya item asli benar-benar ditimpa ulang.
                    if cur and cur == resID then matched = matched + 1 end
                end
                return matched < checked
            end)
            return okCall and need == true
        end

        -- Periodic application functions with different rates
        local function fastApplyLoop()
            pcall(function()
                _timeCount = _timeCount + 1
                _S.globalFrame = _timeCount
                -- Deadbox: pakai skin senjata/kendaraan pada kotak kematian.
                if (_G.NeedCheckDeadBoxTimer or 0) > 0 and _G.DeadBox_TemperRequest then
                    pcall(function()
                        local pc = getPlayerController()
                        if pc and slua.isValid(pc) then _G.DeadBox_TemperRequest(pc) end
                    end)
                end
                -- Broadcast kill tim: coba pasang lagi kalau modul belum ada.
                if not _teamBroadcastHooked and _timeCount % 5 == 0 then
                    pcall(installTeamBroadcastHooks)
                end
                -- Kill counter UI: fallback kalau ticker 0.5s tidak tersedia.
                if not _G.AddOutfitKillCounterLoopStarted
                    and _killCounterHooked
                    and _G.GameAvatarHandlerkillcounter then
                    pcall(_G.GameAvatarHandlerkillcounter)
                end
                if isInLobby() then
                    if _timeCount % 10 == 0 then
                        pcall(snapshotLobbyWear)
                    end
                    if _timeCount % 5 == 0 then
                        pcall(_G.AddOutfitTryFlushSave)
                    end
                end
                if _timeCount % 5 == 0 and _G.AddOutfitPendingPersist then
                    pcall(applyLoadedOutfitFromDisk)
                end
                if isInGamePlay() then
                    local char = getLocalChar()
                    local charValid = char and slua.isValid(char)
                    if not _S.matchTimer and charValid then
                        bootstrapMatch(char)
                    end
                    if _timeCount % 5 == 0 and charValid then
                        pcall(function()
                            local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
                            if slua.isValid(curWeapon) then
                                applySkinToWeaponRef(curWeapon)
                            end
                            equip_weapon_avatar(char)
                            -- Game bisa mengembalikan outfit asli saat respawn;
                            -- cek slot dulu, lalu tulis ulang kalau beda.
                            if not _S.matchOutfitDone or matchOutfitNeedsReapply(char) then
                                _S.matchOutfitDone = matchApplyOutfit(char) or _S.matchOutfitDone
                            end
                            matchApplyEquipSkins(char)
                            applyGrenadeSkinsToController()
                        end)
                    end
                    if _timeCount % 2 == 0 then
                        pcall(applyVehicleSkinInGame)
                    end
                end
            end)
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(1.0, fastApplyLoop)
            end
        end
        
        local function mediumLoop()
            pcall(function()
                -- Character boot check at medium rate
                if isInGamePlay() then
                    local char = getLocalChar()
                    if char and not _S.matchTimer then
                        bootstrapMatch(char)
                    end
                    pcall(tickEliminationKingEffect)
                    pcall(applyVehicleChassisLight)
                end
                if isInLobby() then
                    pcall(snapshotLobbyWear)
                end
            end)
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(2.5, mediumLoop)
            end
        end
        
        local function slowLoop()
            pcall(function()
                if isInGamePlay() then
                    pcall(syncVehicleAvatarSkinList)
                end
                pcall(_G.AddOutfitTryFlushSave)
            end)
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(5.0, slowLoop)
            end
        end
        
        -- Start all loops
        if _ticker and _ticker.AddTimerOnce then
            _ticker.AddTimerOnce(0.5, fastApplyLoop)
            _ticker.AddTimerOnce(1.0, mediumLoop)
            _ticker.AddTimerOnce(2.0, slowLoop)
        end

        -- Game status change detection via polling (cheaper than hooking events)
        local _lastGameStatus = ""
        local function statusPollLoop()
            local currentStatus = ""
            if isInLobby() then currentStatus = "lobby"
            elseif isInGamePlay() then currentStatus = "gameplay"
            else currentStatus = "other" end
            
            if currentStatus ~= _lastGameStatus then
                _lastGameStatus = currentStatus
                -- Status changed, run post-switch logic
                stopMatchWatcher()
                _S.bootstrapNotified = false
                _S.matchOutfitDone = false
                _S.lobbyApplied = false
                _G._lava_fke_triggered = nil
                pcall(function()
                    if isInLobby() then 
                        snapshotLobbyWear()
                        later(2.0, reapplyLobbyEquipped)
                    end
                end)
                pcall(function()
                    if isInGamePlay() then
                        local char = getLocalChar()
                        if char then bootstrapMatch(char) end
                    end
                end)
                pcall(_AutoSaveOutfit, true)
            end
            
            if _ticker and _ticker.AddTimerOnce then
                _ticker.AddTimerOnce(3.0, statusPollLoop)
            end
        end
        
        if _ticker and _ticker.AddTimerOnce then
            _ticker.AddTimerOnce(1.0, statusPollLoop)
        end


        end -- initHooks

        local function prewarmModules()
            local mods = {
                "client.logic.armory.logic_armory",
                "client.slua.logic.wardrobe.fashionbag.fashionbag_data",
                "client.logic.lobby.hall_theme_utils",
                "client.slua.logic.wardrobe.logic_wardrobe_gun",
                "client.slua.logic.wardrobe.wardrobe_data",
                "client.network.Protocol.WardRobeHandler",
                "client.slua.logic.wardrobe.logic_wardrobe_avatar",
                "client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils",
                "client.logic.data.AvatarData",
                "client.slua.logic.XSuit.logic_xsuit",
                "client.slua.logic.wardrobe.logic_wardrobe_new",
                "client.slua.logic.wardrobe.logic_display_setting",
                "client.logic.avatar.logic_team_avatar_manager",
                "client.slua.logic.wardrobe.logic_wardrobe_data_center",
                "client.slua.logic.wardrobe.WardrobeDataEntity",
                "client.slua.umg.Wardrobe.subtab_item_list_base",
                "client.slua.logic.wardrobe.tab_surveillance",
                "client.network.comm.NetManager",
                "client.slua.umg.Wardrobe.wardrobe_macro",
                "client.slua.logic.avatar.avatar_common",
                "client.slua.logic.lobby.Main.Lobby_Main_Control",
                "common.time_ticker",
                "GameLua.GameCore.Module.Subsystem.SubsystemMgr",
                "GameLua.Mod.BaseMod.GamePlay.Backpack.BackpackUtils",
                "GameLua.Mod.Library.GamePlay.Avatar.AvatarDataUtil",
                "GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil",
            }
            for _, m in ipairs(mods) do
                pcall(require, m)
            end
        end

        prewarmModules()
        initHooks()

        log("AddOutfit Merged loaded")
    end)
    if not _ao_ok then
        print("[AddOutfit] LOAD ERROR:", tostring(_ao_err))
    end
-- =============================================================================
-- Selesai. Tidak ada return kelas: chunk ini murni memasang fitur skin.
-- =============================================================================
_G.SkinAutoloadStandalone = { version = 1, mode = "skin-only" }
return _G.SkinAutoloadStandalone
