--[[
  unlock_470.lua - modul unlock kosmetik standalone untuk PUBG Mobile 4.7.0
  ============================================================================

  Tujuan
    Membuka tampilan koleksi/kosmetik (outfit, senjata, attachment, kendaraan,
    parasut, grenade, title, profile border) sebisa mungkin dari sisi client,
    plus panel fake gacha lokal. Semua perubahan bersifat LOKAL/VISUAL:
    inventory server tetap pemilik data sebenarnya.

  Prinsip kerja
    1. Hook predikat "owned/unlocked" dan hitungan "owned count" pada modul
       lobby yang sudah dimuat (client.slua.logic.* / client.logic.*).
    2. Proxy tabel kepemilikan (nama seperti OwnedItemMap / UnlockMap) supaya
       lookup item id yang tidak ada di tabel tetap dianggap owned.
    3. Spoof DataMgr.roleData (profile border / title / skor koleksi) dan
       currency tampilan supaya tombol draw tidak disabled.
    4. Inject daftar avatar ke jalur resmi client:
         - weapon skin + attachment  -> CommerAvatarDataUtil.ConstructWeaponSkinList
         - vehicle skin              -> CommerAvatarDataUtil._FillVehicleSkinList
         - glider/parachute          -> CommerAvatarDataUtil._FillGlideList
         - grenade skin              -> PlayerControllerBase.InitGrenadeAvatarList
       Jalur ini hanya membangun data avatar lokal; tidak memanggil RPC server.
    5. Fake gacha: intersep fungsi request draw/lottery, tampilkan panel reward
       lokal (Logic_CommonItemGet), tidak pernah mengirim request draw.
    6. Auto-load: ticker 1 detik memasang hook yang modulnya baru dimuat
       (lobby dimuat bertahap setelah script dieksekusi).

  Yang TIDAK dilakukan
    * Tidak menyentuh esp_pack_2/2.lua atau file lain.
    * Tidak memanggil ServerRequestUseModWeaponSkin / RPC server apa pun.
    * Tidak menambah item ke backpack battle atau mengubah count loot.
    * Tidak memalsukan hasil gacha ke server (reward hanya panel lokal).

  Pemakaian
    dofile("unlock_470/unlock_470.lua")
    -- atau kontrol penuh:
    _G.UNLOCK470_CONFIG = { autoStart = false, ... }
    local U = dofile("unlock_470/unlock_470.lua")
    U.start()

  API publik
    UNLOCK470.start(opts) / stop() / restart(opts) / refresh() / setConfig(t)
    UNLOCK470.tick() / status() / audit() / applyCosmetics()
    UNLOCK470.findItems(opts) / dumpItem(id) / describe()
    UNLOCK470.config  (boleh diubah langsung, lalu panggil refresh())
]]

local MODULE_ID = "unlock_470"
local VERSION = "1.0.0"

local existing = rawget(_G, "UNLOCK470")
if type(existing) == "table" and existing.__id == MODULE_ID then
  return existing
end

local M = {
  __id = MODULE_ID,
  version = VERSION,
  started = false,
  errors = {},
  stats = {},
  _patches = {},
  _proxies = {},
  _hooks = {},
  _state = {},
  _scanned = {},
  _cache = {},
  _configRevision = 0,
  _installed = {},
  _wrapped = setmetatable({}, { __mode = "k" }),
}

_G.UNLOCK470 = M

-- ============================================================================
-- 0. Konfigurasi
-- ============================================================================

M.config = {
  -- true = langsung start saat file dieksekusi. Ticker akan menunggu modul
  -- lobby yang belum tersedia, jadi aman dipanggil dari loader awal.
  autoStart = true,
  verbose = false,

  tick = {
    enabled = true,
    interval = 1.0,
  },

  -- Layer 1: tampilan kepemilikan di lobby/collection/store/profile.
  ownership = {
    enabled = true,
    predicates = true,
    counts = true,
    minCount = 1,
    -- Proxy tabel seperti OwnedItemMap supaya lookup id yang tidak ada
    -- dianggap owned. Hanya tabel dictionary (tanpa array padat).
    proxyTables = true,
  },

  -- Layer 2: profile border, title, skor koleksi.
  profile = {
    enabled = true,
    -- 0 = jangan ubah. Contoh avatar box: 2002901.
    avatarBoxId = 0,
    -- 0 = jangan ubah.
    titleId = 0,
    -- 1 = badge VIP tampil di profile.
    bgbgVip = 1,
    -- 0 = jangan ubah. Skor koleksi tinggi membuat level koleksi terlihat max.
    collectionScore = 0,
    -- Field tambahan: { key = value }.
    extra = {},
  },

  -- Layer 3: currency tampilan. Diperlukan agar tombol gacha tidak disabled.
  -- Nilai ini hanya memengaruhi UI client; server tetap menolak pembelian.
  currency = {
    enabled = true,
    value = 999999999,
    fields = {
      "gold", "ticket", "diamond", "uc", "UC", "fp_token",
      "eternal_diamond", "home_coin", "pp", "bp", "coupon", "voucher",
      "gold_chip", "gen_ticket", "corps_money", "smelt", "battle_coin",
      "wow_creation_score", "ugc_advanced_crystal", "carteam_coin_count",
      "anchor", "anchor_origin",
    },
  },

  -- Layer 4: override getter avatar (UI/collection) dan opsi apply lokal.
  avatar = {
    enabled = true,
    -- GetEquippedItemDefineID / GetEquippedItemDefineID3 / GetAvatarIDBySlotID
    -- mengembalikan item yang dikonfigurasi. Pemakai Lua (UI, effect) melihat
    -- item tersebut; mesh native tetap mengikuti data server.
    forceGetters = true,
    -- Percobaan mengubah outfit karakter lewat ChangeItemAvatar(itemID, false).
    -- Default false: jalur ini tidak terdokumentasi untuk character dan bisa
    -- memicu validasi server. Nyalakan hanya kalau Anda menerima risikonya.
    runtimeChange = false,
    -- Percobaan menulis ViewSlotDesc + refresh. Sangat eksperimental.
    experimentalSlotDesc = false,
    -- Nama slot mengikuti EAvatarSlotType tanpa prefix, contoh:
    --   ClothesEquipemtSlot = 401001,
    --   HelmetEquipemtSlot  = 501001,
    slots = {},
  },

  -- Layer 5: weapon skin + attachment (in-match, lokal).
  weapon = {
    enabled = true,
    -- Daftar item id weapon skin yang dipaksa tersedia untuk semua senjata.
    skins = {},
    -- Attachment per weapon skin: { [skinID] = { partID, ... } }.
    attachments = {},
    -- Pindai WeaponSkinMapping dan ambil skin per WeaponID.
    autoFromMapping = true,
    -- true = satu skin terbaru per senjata; false = semua skin.
    preferOnePerWeapon = true,
    maxAuto = 200,
    -- Bangun AdditionIntData dari ItemUpgradeUnLockConfig.
    autoAttachments = true,
    maxAttachmentsPerSkin = 12,
  },

  -- Layer 6: vehicle skin (in-match, lokal).
  vehicle = {
    enabled = true,
    skins = {},
    -- 0 = biarkan pilihan lama. >0 = paksa skin yang tampil.
    showSkin = 0,
    autoFromMapping = true,
    preferOnePerVehicle = true,
    maxAuto = 30,
  },

  -- Layer 7: glider / parachute.
  glide = {
    enabled = true,
    gliderId = 0,
    aircraftId = 0,
    -- true = pilih id glider tertinggi dari tabel Item (subtype 413-415).
    autoPick = false,
  },

  -- Layer 8: grenade / throwable skin.
  grenade = {
    enabled = true,
    -- { { proto = <protoItemID>, avatar = <avatarItemID> }, ... }
    list = {},
  },

  -- Layer 8b: depot/Inventory (WardrobeData) sintetis.
  -- Item yang tidak ada di akun tetap disuntikkan ke entity depot client,
  -- sehingga muncul di tab Inventory/Wardrobe (bukan hanya Collection).
  wardrobe = {
    enabled = true,
    inject = true,
    -- "missing" = hanya item yang belum ada di depot (tanpa duplikat),
    -- "all"     = suntik semua item kosmetik (bisa tampil ganda kalau sudah
    --             dimiliki),
    -- "list"    = hanya id di `items`.
    mode = "missing",
    -- Tambahan id eksplisit. Format: { 401001, 401002 } atau
    -- { [401001] = true }.
    items = {},
    -- Batas jumlah item yang disuntikkan (0 = tanpa batas).
    maxItems = 20000,
    -- Hanya tipe item tertentu. Kosong = semua item yang punya
    -- WardrobeMainTab/WardrobeTab.
    includeItemTypes = {},
    excludeItemTypes = {},
    -- Hapus entri sintetis saat item asli dengan resID sama masuk dari server.
    dropOnReal = true,
    -- Minta UI refresh setelah injeksi.
    notify = true,
    -- Equip lokal untuk entri sintetis. Tidak mengirim RPC ke server dan
    -- hanya mengubah tampilan lobby (mannequin/preview). Default false.
    localEquip = false,
  },

  -- Layer 9: fake gacha lokal.
  fakeGacha = {
    enabled = true,
    showPanel = true,
    -- Maksimal item per panel (Logic_CommonItemGet biasanya 10).
    panelBatching = 10,
    -- Reward eksplisit: { { id = 403003, count = 1 }, ... }.
    rewards = {},
    fallbackResId = 403003,
    defaultDrawCount = 1,
    tenDrawCount = 10,
    -- Intersep fungsi draw yang sudah dikenal (logic_lucky*, XSuit, dll).
    interceptKnown = true,
    -- Pindai modul lobby_activity/lottery untuk nama fungsi request draw.
    interceptScan = true,
  },
}

-- ============================================================================
-- 1. Utility dasar
-- ============================================================================

local function isFn(v)
  return type(v) == "function"
end

local function isTable(v)
  return type(v) == "table"
end

local function rawTable(v)
  local t = type(v)
  if t == "table" or t == "userdata" then
    return v
  end
  return nil
end

local function now()
  local ok, t = pcall(os.clock)
  if ok then
    return tonumber(t) or 0.0
  end
  return 0.0
end

local function trace(fmt, ...)
  if not M.config.verbose then
    return
  end
  local n = select("#", ...)
  local args = { ... }
  local unpackFn = table.unpack or unpack
  pcall(function()
    local msg = nil
    if n > 0 then
      msg = string.format(fmt, unpackFn(args, 1, n))
    else
      msg = tostring(fmt)
    end
    print("[UNLOCK470] " .. msg)
  end)
end

local function addError(tag, err)
  M.stats.errors = (M.stats.errors or 0) + 1
  if #M.errors < 80 then
    M.errors[#M.errors + 1] = tostring(tag) .. ": " .. tostring(err)
  end
  trace("%s: %s", tostring(tag), tostring(err))
end

local function isArrayLike(t)
  if type(t) ~= "table" then
    return false
  end
  return #t > 0
end

local function merge(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then
    return dst
  end
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table"
      and not isArrayLike(v) and not isArrayLike(dst[k]) then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

local function resetStats()
  M.stats = {
    patched = 0,
    restored = 0,
    scanned = 0,
    ownershipForced = 0,
    countForced = 0,
    proxies = 0,
    profileApplied = 0,
    currencyApplied = 0,
    avatarGetter = 0,
    avatarChange = 0,
    avatarChangeFail = 0,
    weaponInjected = 0,
    vehicleInjected = 0,
    glideInjected = 0,
    grenadeInjected = 0,
    fakeDraws = 0,
    fakeRewards = 0,
    panelFails = 0,
    errors = 0,
    timerUnavailable = 0,
  }
end

resetStats()

local function copyList(src)
  local out = {}
  if type(src) ~= "table" then
    return out
  end
  for k, v in pairs(src) do
    out[k] = v
  end
  return out
end

-- Salinan satu level; array di dalamnya ikut disalin supaya fungsi game yang
-- menulis balik (ConstructWeaponSkinList) tidak merusak data server asli.
local function copyAttachMap(src)
  local out = {}
  if type(src) ~= "table" then
    return out
  end
  for k, v in pairs(src) do
    if type(v) == "table" then
      local arr = {}
      for i, x in ipairs(v) do
        arr[i] = x
      end
      for kk, x in pairs(v) do
        if type(kk) ~= "number" then
          arr[kk] = x
        end
      end
      out[k] = arr
    else
      out[k] = v
    end
  end
  return out
end

local function isValid(obj)
  if obj == nil then
    return false
  end
  local s = rawget(_G, "slua")
  if s and isFn(s.isValid) then
    local ok, r = pcall(s.isValid, obj)
    if ok then
      return r and true or false
    end
  end
  return true
end

local function safeRequire(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  if package and package.loaded then
    local cached = package.loaded[path]
    if cached ~= nil then
      return cached
    end
  end
  if not isFn(require) then
    return nil
  end
  local ok, mod = pcall(require, path)
  if ok then
    return mod
  end
  return nil
end

local function importClass(name)
  if package and package.loaded and package.loaded[name] ~= nil then
    return package.loaded[name]
  end
  local g = rawget(_G, name)
  if g ~= nil then
    return g
  end
  if not isFn(import) then
    return nil
  end
  local ok, cls = pcall(import, name)
  if ok and cls ~= nil then
    return cls
  end
  return nil
end

-- ============================================================================
-- 2. Registry patch + restore
--
-- Satu target+key hanya punya satu record. Kalau modul lain mengganti fungsi
-- setelah kita, record di-update (old = fungsi eksternal terbaru) supaya
-- stop() tidak menghapus hook modul lain.
-- ============================================================================

local function isOurs(fn)
  return type(fn) == "function" and M._wrapped[fn] == true
end

local function findPatch(target, key)
  for i = #M._patches, 1, -1 do
    local p = M._patches[i]
    if p.target == target and p.key == key then
      return i, p
    end
  end
  return nil, nil
end

local function patchValue(target, key, newFn, tag, label)
  if target == nil or type(key) ~= "string" or not isFn(newFn) then
    return false
  end

  local okOld, old = pcall(function()
    return target[key]
  end)
  if not okOld or old == nil then
    return false
  end
  if old == newFn or isOurs(old) then
    return true
  end
  if not isFn(old) then
    return false
  end

  local okSet = pcall(function()
    target[key] = newFn
  end)
  if not okSet then
    addError("patch", "gagal set " .. tostring(label or key))
    return false
  end

  local okCheck, check = pcall(function()
    return target[key]
  end)
  if not okCheck or check ~= newFn then
    addError("patch", "verifikasi gagal " .. tostring(label or key))
    return false
  end

  pcall(function()
    M._wrapped[newFn] = true
  end)

  local idx, p = findPatch(target, key)
  if idx ~= nil then
    p.old = old
    p.new = newFn
    p.tag = tag
    p.label = label or p.label
  else
    M._patches[#M._patches + 1] = {
      target = target,
      key = key,
      old = old,
      new = newFn,
      tag = tag or "patch",
      label = label or tostring(key),
    }
    M.stats.patched = M.stats.patched + 1
  end

  trace("patch %s", tostring(label or key))
  return true
end

local function restoreAll()
  for i = #M._patches, 1, -1 do
    local p = M._patches[i]
    pcall(function()
      local cur = p.target[p.key]
      if cur == p.new then
        p.target[p.key] = p.old
        M.stats.restored = M.stats.restored + 1
      end
    end)
  end
  M._patches = {}

  for i = #M._proxies, 1, -1 do
    local px = M._proxies[i]
    pcall(function()
      if getmetatable(px.tbl) == px.mt then
        setmetatable(px.tbl, nil)
      end
    end)
  end
  M._proxies = {}
  M._hooks = {}
end

-- ============================================================================
-- 3. Akses runtime game
-- ============================================================================

local function getDataMgr()
  local dm = rawget(_G, "DataMgr")
  if dm ~= nil then
    return dm
  end
  if package and package.loaded then
    return package.loaded["DataMgr"]
  end
  return nil
end

local function getGameplayData()
  local gd = rawget(_G, "GameplayData")
  if gd ~= nil then
    return gd
  end
  return safeRequire("GameLua.GameCore.Data.GameplayData")
end

local function getPC()
  local gd = getGameplayData()
  if gd and isFn(gd.GetPlayerController) then
    local ok, pc = pcall(gd.GetPlayerController)
    if ok and pc ~= nil then
      return pc
    end
  end
  return nil
end

local function getPawn(pc)
  if pc == nil then
    return nil
  end
  local getters = { "GetPlayerCharacterSafety", "GetMyPawn", "K2_GetPawn", "GetPawn" }
  for _, name in ipairs(getters) do
    local fn = nil
    pcall(function()
      fn = pc[name]
    end)
    if isFn(fn) then
      local ok, pawn = pcall(fn, pc)
      if ok and pawn ~= nil and isValid(pawn) then
        return pawn
      end
    end
  end
  for _, field in ipairs({ "Pawn", "MyPawn", "PlayerCharacter" }) do
    local ok, pawn = pcall(function()
      return pc[field]
    end)
    if ok and pawn ~= nil and isValid(pawn) then
      return pawn
    end
  end
  return nil
end

local function getAvatarComp(pawn)
  if pawn == nil then
    return nil
  end
  for _, name in ipairs({ "getAvatarComponent2", "GetAvatarComponent2" }) do
    local fn = nil
    pcall(function()
      fn = pawn[name]
    end)
    if isFn(fn) then
      local ok, comp = pcall(fn, pawn)
      if ok and comp ~= nil and isValid(comp) then
        return comp
      end
    end
  end
  for _, field in ipairs({ "CharacterAvatarComp2_BP", "CharacterAvatarComponent", "AvatarComponent" }) do
    local ok, comp = pcall(function()
      return pawn[field]
    end)
    if ok and comp ~= nil and isValid(comp) then
      return comp
    end
  end
  return nil
end

local function getCDataTable()
  local cdt = rawget(_G, "CDataTable")
  if cdt ~= nil then
    return cdt
  end
  local tools = safeRequire("GameLua.Mod.BaseMod.Common.GamePlayTools")
  if tools and isFn(tools.GetTableData) then
    return tools
  end
  return nil
end

local function getTable(name)
  local cdt = getCDataTable()
  if cdt == nil or not isFn(cdt.GetTable) then
    return nil
  end
  local ok, tbl = pcall(cdt.GetTable, name)
  if ok then
    return tbl
  end
  return nil
end

local function getTableData(name, key)
  local cdt = getCDataTable()
  if cdt == nil or not isFn(cdt.GetTableData) then
    return nil
  end
  local ok, row = pcall(cdt.GetTableData, name, key)
  if ok then
    return row
  end
  return nil
end

local function getItemCfg(id)
  local n = tonumber(id)
  if n == nil then
    return nil
  end
  local cache = M._cache.items
  if cache == nil then
    cache = {}
    M._cache.items = cache
  end
  local hit = cache[n]
  if hit ~= nil then
    return hit or nil
  end
  local cfg = getTableData("Item", n)
  cache[n] = cfg or false
  return cfg
end

local function getItemName(id)
  local cfg = getItemCfg(id)
  if type(cfg) == "table" then
    return tostring(cfg.ItemName or cfg.Name or id)
  end
  return tostring(id)
end

local function getItemUpgradeMgr()
  local mm = rawget(_G, "ModuleManager")
  if mm == nil or not isFn(mm.GetModule) then
    return nil
  end
  local name = nil
  pcall(function()
    if mm.CommonModuleConfig then
      name = mm.CommonModuleConfig.ItemUpgradeModule
    end
  end)
  if name == nil then
    return nil
  end
  local ok, mgr = pcall(mm.GetModule, name)
  if ok then
    return mgr
  end
  return nil
end

-- ============================================================================
-- 4. Item define id + slot enum
-- ============================================================================

local SLOT_ALIAS = {
  Clothes = "ClothesEquipemtSlot",
  Pants = "PantsEquipemtSlot",
  Head = "HeadEquipemtSlot",
  Hair = "HairEquipemtSlot",
  Hat = "HatEquipemtSlot",
  Helmet = "HelmetEquipemtSlot",
  Backpack = "BackpackEquipemtSlot",
  Armor = "ArmorEquipemtSlot",
  Glass = "GlassEquipemtSlot",
  Face = "FaceEquipemtSlot",
  Beard = "BeardEquipemtSlot",
  Shoes = "ShoesEquipemtSlot",
  Glide = "GlideEquipemtSlot",
  Parachute = "ParachuteEquipemtSlot",
  FootEffect = "FootEffectEquipemtSlot",
  HandEffect = "HandEffectEquipemtSlot",
  Pendant = "BackPack_PendantSlot",
  NightVision = "NightVisionEquipemtSlot",
  UnderCloth = "UnderClothSlot",
  UnderPants = "UnderPantsSlot",
}

local function getSlotEnum()
  return importClass("EAvatarSlotType")
end

local function slotEnum(name)
  if type(name) ~= "string" then
    return nil
  end
  local E = getSlotEnum()
  if E == nil then
    return nil
  end
  local candidates = {}
  if name:sub(1, 17) == "EAvatarSlotType_" then
    candidates[#candidates + 1] = name
  else
    candidates[#candidates + 1] = "EAvatarSlotType_" .. name
    candidates[#candidates + 1] = name
    if SLOT_ALIAS[name] then
      candidates[#candidates + 1] = "EAvatarSlotType_" .. SLOT_ALIAS[name]
    end
  end
  for _, key in ipairs(candidates) do
    local ok, v = pcall(function()
      return E[key]
    end)
    if ok and v ~= nil then
      return v
    end
  end
  return nil
end

local function getDefineIDCtor()
  local c = rawget(_G, "FItemDefineID")
  if c ~= nil then
    return c
  end
  if isFn(import) then
    local ok, mod = pcall(import, "ItemDefineID")
    if ok and mod ~= nil then
      return mod
    end
  end
  return nil
end

local function makeDefineID(typ, id, template)
  local ctor = getDefineIDCtor()
  if ctor == nil then
    return nil
  end
  local ok, v = pcall(ctor, tonumber(typ) or 6, tonumber(id) or 0)
  if not ok or v == nil then
    return nil
  end
  if template ~= nil then
    pcall(function()
      local iid = tonumber(template.InstanceID)
      if iid and iid > 0 then
        v.InstanceID = iid
      end
    end)
  end
  return v
end

local function configuredSlotID(slot)
  local slots = M.config.avatar.slots
  if type(slots) ~= "table" then
    return nil
  end
  for name, id in pairs(slots) do
    local n = tonumber(id)
    if n and n > 0 then
      local enumVal = slotEnum(name)
      if enumVal ~= nil and enumVal == slot then
        return n
      end
    end
  end
  return nil
end

-- ============================================================================
-- 5. Ownership layer (lobby)
-- ============================================================================

local PROXY_MT = {
  __index = function(_, key)
    if type(key) == "number" and key >= 10000 then
      return 1
    end
    return nil
  end,
}

local PROXY_NAMES = {
  OwnedItemMap = true,
  owned_item_map = true,
  OwnedMap = true,
  owned_map = true,
  ItemOwnedMap = true,
  item_owned_map = true,
  UnlockMap = true,
  unlock_map = true,
  UnlockedMap = true,
  unlocked_map = true,
  OwnedItems = true,
  owned_items = true,
  OwnedItemList = true,
  owned_item_list = true,
}

local PREDICATE_EXACT = {
  IsOwned = true,
  IsItemOwned = true,
  IsOwnedItem = true,
  IsAvatarOwned = true,
  IsSkinOwned = true,
  IsWeaponSkinOwned = true,
  IsVehicleSkinOwned = true,
  IsTitleOwned = true,
  IsProfileBorderOwned = true,
  IsProfileOwned = true,
  IsUnlocked = true,
  IsItemUnlocked = true,
  IsUnlock = true,
  IsItemUnlock = true,
  HasItem = true,
  HasOwnedItem = true,
  HasItemOwned = true,
  CheckOwned = true,
  CheckItemOwned = true,
  IsItemAvailable = true,
  CanUseItem = true,
}

local PREDICATE_PREFIX = {
  "IsOwned",
  "IsItemOwned",
  "IsAvatarOwned",
  "IsSkinOwned",
  "IsWeaponSkinOwned",
  "IsVehicleSkinOwned",
  "IsTitleOwned",
  "IsProfileBorderOwned",
  "IsUnlocked",
  "IsItemUnlocked",
  "HasOwned",
  "CheckItemOwned",
}

local COUNT_NAMES = {
  GetOwnedCount = true,
  GetOwnedItemCount = true,
  GetItemOwnedCount = true,
  GetOwnedNum = true,
  GetItemOwnedNum = true,
  GetOwnCount = true,
  GetOwnedItemNum = true,
  GetItemOwnNum = true,
}

local PROFILE_GETTERS = {
  GetCurAvatarBoxID = "avatarBoxId",
  GetCurAvatarBoxId = "avatarBoxId",
  GetAvatarBoxID = "avatarBoxId",
  GetAvatarBoxId = "avatarBoxId",
  GetProfileBorderID = "avatarBoxId",
  GetProfileFrameID = "avatarBoxId",
  GetCurTitleID = "titleId",
  GetCurTitleId = "titleId",
  GetTitleID = "titleId",
  GetTitleId = "titleId",
  GetCurrentTitleID = "titleId",
  GetCurrentTitleId = "titleId",
}

local function isPredicateName(name)
  if PREDICATE_EXACT[name] then
    return true
  end
  if name:find("Count", 1, true) or name:find("Num", 1, true)
    or name:find("Time", 1, true) or name:find("Limit", 1, true)
    or name:find("Max", 1, true) or name:find("Rate", 1, true) then
    return false
  end
  for _, prefix in ipairs(PREDICATE_PREFIX) do
    if name:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

local function isItemIdValue(v)
  local t = type(v)
  if t == "number" then
    return v >= 10000
  end
  if t == "string" then
    local n = tonumber(v)
    return n ~= nil and n >= 10000
  end
  if t == "table" or t == "userdata" then
    local ok, id = pcall(function()
      return tonumber(v.TypeSpecificID)
    end)
    if ok and id and id >= 10000 then
      return true
    end
    ok, id = pcall(function()
      return tonumber(v.ItemID)
    end)
    if ok and id and id >= 10000 then
      return true
    end
  end
  return false
end

local function hasItemIdArg(...)
  local n = select("#", ...)
  for i = 1, n do
    if isItemIdValue((select(i, ...))) then
      return true
    end
  end
  return false
end

local function makePredicate(old, label)
  return function(...)
    local ok, res = pcall(old, ...)
    if ok and res then
      return res
    end
    if hasItemIdArg(...) then
      M.stats.ownershipForced = M.stats.ownershipForced + 1
      return true
    end
    if not ok then
      trace("predicate error %s: %s", label, tostring(res))
      return false
    end
    return res
  end
end

local function makeCount(old, label)
  return function(...)
    local ok, res = pcall(old, ...)
    local n = ok and tonumber(res) or nil
    local min = tonumber(M.config.ownership.minCount) or 1
    if hasItemIdArg(...) then
      if n == nil or n < min then
        M.stats.countForced = M.stats.countForced + 1
        return min
      end
    end
    if not ok then
      trace("count error %s: %s", label, tostring(res))
      return nil
    end
    return res
  end
end

local function makeProfileGetter(old, key, label)
  return function(...)
    local v = tonumber(M.config.profile[key])
    if v and v > 0 then
      return v
    end
    return old(...)
  end
end

local function tryProxy(path, key, tbl)
  if not M.config.ownership.enabled or not M.config.ownership.proxyTables then
    return false
  end
  if type(tbl) ~= "table" then
    return false
  end
  -- Array padat bukan map kepemilikan; jangan disentuh.
  if #tbl > 0 then
    return false
  end
  if getmetatable(tbl) ~= nil then
    return false
  end
  local ok = pcall(setmetatable, tbl, PROXY_MT)
  if not ok then
    return false
  end
  M._proxies[#M._proxies + 1] = {
    tbl = tbl,
    mt = PROXY_MT,
    label = tostring(path) .. "." .. tostring(key),
  }
  M.stats.proxies = M.stats.proxies + 1
  trace("proxy %s.%s", tostring(path), tostring(key))
  return true
end

local DENY_PARTS = {
  "battle", "replay", "report", "security", "exception",
  "anticheat", "download", "cheat", ".gm.", "gm_",
}

local function moduleAllowed(path)
  if type(path) ~= "string" then
    return false
  end
  local a = path:sub(1, 18)
  local b = path:sub(1, 13)
  if a ~= "client.slua.logic." and b ~= "client.logic." then
    return false
  end
  local low = path:lower()
  if low:find(".umg.", 1, true) then
    return false
  end
  for _, d in ipairs(DENY_PARTS) do
    if low:find(d, 1, true) then
      return false
    end
  end
  return true
end

-- ============================================================================
-- 6. Fake gacha: nama fungsi request
-- ============================================================================

local GACHA_KNOWN = {
  ["client.slua.logic.lobby_activity.logic_luckyback_activity"] = {
    "do_one_draw_back_by_activity_req",
    "do_one_draw_by_tick",
    "get_sum_draw_award_by_activity_req",
  },
  ["client.slua.logic.lobby_activity.logic_luckydouble_activity"] = {
    "send_do_one_lucky_double_draw_by_activity_req",
    "send_double_draw_on_shot_req",
  },
  ["client.slua.logic.lobby_activity.logic_luckyunback_activity"] = {
    "send_do_draw_discount_by_activity_req",
  },
  ["client.slua.logic.lobby_activity.logic_luckmix_activity"] = {
    "DoDraw",
  },
  ["client.slua.logic.lobby_activity.logic_luckymulti_activity"] = {
    "Lottery",
  },
  ["client.slua.logic.lobby_activity.logic_scrapgold_draw"] = {
    "DoDraw",
  },
  ["client.slua.logic.lobby_activity.logic_godzilla_ban"] = {
    "OneDraw",
    "TenDraw",
  },
  ["client.slua.logic.lobby_activity.logic_super_airdrop"] = {
    "send_choose_and_get_super_airdrop_reward_req",
  },
  ["client.slua.logic.lobby_activity.logic_ladder_draw"] = {
    "OnRotateRsp",
    "OnRandomAwardRsp",
  },
  ["client.slua.logic.lobby_activity.LukcyOptionalTurntable.Logic_LukcyOptionalTurntable"] = {
    "SendDrawActReq",
  },
  ["client.slua.logic.lobby_activity.crazy_weekend.logic_crazy_weekend_luckydraw"] = {
    "send_get_happy_weekend_ticket_req",
  },
  ["client.slua.logic.XSuit.logic_xsuit_activity"] = {
    "send_do_draw_act_req",
    "send_get_accumulate_pool_reward_req",
  },
  ["client.slua.logic.tarot_card.logic_tarotcard_drawcard"] = {
    "DoDraw",
  },
}

local function isGachaModule(path)
  local low = path:lower()
  return low:find("lucky", 1, true) ~= nil
    or low:find("lottery", 1, true) ~= nil
    or low:find("gacha", 1, true) ~= nil
    or low:find("draw", 1, true) ~= nil
    or low:find("xsuit", 1, true) ~= nil
    or low:find("turntable", 1, true) ~= nil
    or low:find("tarot", 1, true) ~= nil
    or low:find("airdrop", 1, true) ~= nil
end

local function isDrawRequestName(name)
  local low = name:lower()
  if low:sub(1, 3) == "get" or low:sub(1, 2) == "on" then
    return false
  end
  if low:find("rsp", 1, true) or low:find("recv", 1, true)
    or low:find("handle", 1, true) or low:find("callback", 1, true) then
    return false
  end
  local deny = {
    "info", "data", "config", "list", "state", "status", "detail",
    "query", "record", "history", "report", "log", "cost", "price",
    "preview", "count",
  }
  for _, d in ipairs(deny) do
    if low:find(d, 1, true) then
      return false
    end
  end
  local hasDraw = low:find("draw", 1, true) or low:find("lottery", 1, true)
    or low:find("gacha", 1, true) or low:find("lucky", 1, true)
    or low:find("turntable", 1, true)
  if not hasDraw then
    return false
  end
  return low:sub(1, 4) == "send" or low:find("req", 1, true) ~= nil
    or low:sub(1, 2) == "do" or low:find("one", 1, true) ~= nil
    or low:find("ten", 1, true) ~= nil or low:find("multi", 1, true) ~= nil
    or low == "draw"
end

-- ============================================================================
-- 7. Profile + currency
-- ============================================================================

local applyProfile
local applyCurrency
local makeGachaHook

local function roleDataSet(t, key, value)
  if t == nil or key == nil or value == nil then
    return false
  end
  local okCur, cur = pcall(function()
    return t[key]
  end)
  if okCur and cur == value then
    return false
  end
  local ok = pcall(function()
    t[key] = value
  end)
  return ok
end

applyProfile = function()
  if not M.started or not M.config.profile.enabled then
    return false
  end
  local dm = getDataMgr()
  if dm == nil then
    return false
  end
  local okRd, rd = pcall(function()
    return dm.roleData
  end)
  if not okRd or rd == nil or (type(rd) ~= "table" and type(rd) ~= "userdata") then
    return false
  end

  local p = M.config.profile
  local changed = 0

  if tonumber(p.avatarBoxId) and tonumber(p.avatarBoxId) > 0 then
    local id = tonumber(p.avatarBoxId)
    if roleDataSet(rd, "cur_avatar_box_id", id) then changed = changed + 1 end
    if roleDataSet(rd, "avatar_box_id", id) then changed = changed + 1 end
  end

  if tonumber(p.titleId) and tonumber(p.titleId) > 0 then
    local id = tonumber(p.titleId)
    if roleDataSet(rd, "cur_title_id", id) then changed = changed + 1 end
    if roleDataSet(rd, "title_id", id) then changed = changed + 1 end
  end

  if p.bgbgVip ~= nil then
    if roleDataSet(rd, "bgbg_vip", p.bgbgVip) then changed = changed + 1 end
  end

  local score = tonumber(p.collectionScore)
  if score and score > 0 then
    local okBcd, bcd = pcall(function()
      return rd.brief_collect_data
    end)
    if okBcd and bcd ~= nil and (type(bcd) == "table" or type(bcd) == "userdata") then
      if roleDataSet(bcd, "total_score", score) then changed = changed + 1 end
      if roleDataSet(bcd, "cur_season_collect_score", score) then changed = changed + 1 end
    end
  end

  if type(p.extra) == "table" then
    for k, v in pairs(p.extra) do
      if roleDataSet(rd, k, v) then changed = changed + 1 end
    end
  end

  M.stats.profileApplied = changed
  return changed > 0
end

applyCurrency = function()
  if not M.started or not M.config.currency.enabled then
    return false
  end
  local dm = getDataMgr()
  if dm == nil then
    return false
  end
  local value = tonumber(M.config.currency.value) or 999999999
  local n = 0
  for _, key in ipairs(M.config.currency.fields) do
    local ok = pcall(function()
      dm[key] = value
    end)
    if ok then
      n = n + 1
    end
  end
  M.stats.currencyApplied = n
  return n > 0
end

local function installDataMgrHook()
  local dm = getDataMgr()
  if dm == nil then
    return false
  end
  -- Relogin bisa mengganti tabel DataMgr; pasang ulang pada identitas baru.
  if M._hooks.initRoleData and M._state.dataMgr == dm then
    return true
  end
  local old = nil
  pcall(function()
    old = dm.InitRoleData
  end)
  if not isFn(old) then
    return false
  end
  local new = function(...)
    local ret = old(...)
    pcall(applyProfile)
    pcall(applyCurrency)
    return ret
  end
  if patchValue(dm, "InitRoleData", new, "profile", "DataMgr.InitRoleData") then
    M._hooks.initRoleData = true
    M._state.dataMgr = dm
    M._installed.profile = true
    return true
  end
  return false
end

-- ============================================================================
-- 8. Scan modul lobby + pasang hook
-- ============================================================================

local function patchGachaFunction(path, mod, key, old)
  if key:sub(1, 2) == "On" then
    return false
  end
  if not isFn(makeGachaHook) then
    return false
  end
  local new = makeGachaHook(old, mod, path, key)
  return patchValue(mod, key, new, "gacha", path .. "." .. key)
end

local function patchModule(path, mod)
  local known = GACHA_KNOWN[path]
  local gachaModule = isGachaModule(path)
  local lowPath = path:lower()

  for key, value in pairs(mod) do
    if type(key) ~= "string" then
      -- entri array/numerik bukan API; lewati supaya modul tetap terpindai
    elseif isFn(value) then
      if M.config.ownership.enabled and M.config.ownership.predicates
        and isPredicateName(key) then
        patchValue(mod, key, makePredicate(value, path .. "." .. key),
          "ownership", path .. "." .. key)

      elseif M.config.ownership.enabled and M.config.ownership.counts
        and COUNT_NAMES[key] then
        patchValue(mod, key, makeCount(value, path .. "." .. key),
          "ownership", path .. "." .. key)

      elseif M.config.profile.enabled and PROFILE_GETTERS[key] then
        local gate = true
        if key == "GetTitleID" or key == "GetTitleId" then
          gate = lowPath:find("profile", 1, true) ~= nil
            or lowPath:find("title", 1, true) ~= nil
            or lowPath:find("avatar", 1, true) ~= nil
            or lowPath:find("lobby", 1, true) ~= nil
            or lowPath:find("home", 1, true) ~= nil
            or lowPath:find("player", 1, true) ~= nil
        end
        if gate then
          patchValue(mod, key, makeProfileGetter(value, PROFILE_GETTERS[key], path .. "." .. key),
            "profile", path .. "." .. key)
        end

      elseif M.config.fakeGacha.enabled then
        local knownHit = false
        if M.config.fakeGacha.interceptKnown and known then
          for _, name in ipairs(known) do
            if name == key then
              knownHit = true
              break
            end
          end
        end
        if knownHit then
          patchGachaFunction(path, mod, key, value)
        elseif M.config.fakeGacha.interceptScan and gachaModule and isDrawRequestName(key) then
          patchGachaFunction(path, mod, key, value)
        end
      end

    elseif isTable(value) and PROXY_NAMES[key] then
      tryProxy(path, key, value)
    end
  end
end

local function scanModules()
  if not package or not package.loaded then
    return 0
  end
  local scanned = 0
  for path, mod in pairs(package.loaded) do
    if type(path) == "string" and isTable(mod) and moduleAllowed(path)
      and M._scanned[path] ~= mod then
      M._scanned[path] = mod
      local ok, err = pcall(patchModule, path, mod)
      if not ok then
        addError("scan:" .. path, err)
      end
      scanned = scanned + 1
    end
  end
  M.stats.scanned = M.stats.scanned + scanned
  M._installed.ownership = M._installed.ownership or (M.config.ownership.enabled and true or nil)
  return scanned
end

-- ============================================================================
-- 9. Avatar getter + apply lokal (opsional)
-- ============================================================================

local function makeDefineGetter(old, label)
  return function(self, slot, ...)
    local id = configuredSlotID(slot)
    if id ~= nil and id > 0 then
      local ok, desc = pcall(old, self, slot, ...)
      local typ = 6
      if ok and desc ~= nil then
        local okType, t = pcall(function()
          return tonumber(desc.Type)
        end)
        if okType and t then
          typ = t
        end
      end
      local made = makeDefineID(typ, id, ok and desc or nil)
      if made ~= nil then
        M.stats.avatarGetter = M.stats.avatarGetter + 1
        return made
      end
    end
    return old(self, slot, ...)
  end
end

local function makeAvatarIDGetter(old)
  return function(self, slot, ...)
    local id = configuredSlotID(slot)
    if id ~= nil and id > 0 then
      M.stats.avatarGetter = M.stats.avatarGetter + 1
      return id
    end
    return old(self, slot, ...)
  end
end

local function installAvatarClass()
  if not M.config.avatar.enabled then
    M._installed.avatar = true
    return true
  end
  if not M.config.avatar.forceGetters then
    M._installed.avatar = true
    return true
  end

  local cls = importClass("CharacterAvatarComponent")
  if cls == nil then
    return false
  end
  if M._state.avatarClass == cls and M._installed.avatar then
    return true
  end
  M._state.avatarClass = cls

  local patched = 0
  local getName = "GetEquippedItemDefineID"
  local oldName = nil
  pcall(function()
    oldName = cls[getName]
  end)
  if isFn(oldName) then
    if patchValue(cls, getName, makeDefineGetter(oldName, "CharacterAvatarComponent." .. getName),
      "avatar", "CharacterAvatarComponent." .. getName) then
      patched = patched + 1
    end
  end

  local name3 = "GetEquippedItemDefineID3"
  local old3 = nil
  pcall(function()
    old3 = cls[name3]
  end)
  if isFn(old3) then
    if patchValue(cls, name3, makeDefineGetter(old3, "CharacterAvatarComponent." .. name3),
      "avatar", "CharacterAvatarComponent." .. name3) then
      patched = patched + 1
    end
  end

  local idName = "GetAvatarIDBySlotID"
  local oldID = nil
  pcall(function()
    oldID = cls[idName]
  end)
  if isFn(oldID) then
    if patchValue(cls, idName, makeAvatarIDGetter(oldID),
      "avatar", "CharacterAvatarComponent." .. idName) then
      patched = patched + 1
    end
  end

  if patched > 0 then
    M._installed.avatar = true
  end
  return patched > 0
end

local function applySlotDesc(comp)
  local map = nil
  pcall(function()
    map = comp.ViewSlotDesc
  end)
  if map == nil then
    return 0
  end
  local n = 0
  for name, id in pairs(M.config.avatar.slots) do
    local itemID = tonumber(id)
    if itemID and itemID > 0 then
      local slot = slotEnum(name)
      if slot ~= nil then
        local ok, desc = pcall(function()
          return map:Get(slot)
        end)
        if ok and desc ~= nil then
          local ok1 = pcall(function()
            desc.ItemDefineID.TypeSpecificID = itemID
          end)
          local ok2 = pcall(function()
            desc.RealShowItemDefineID.TypeSpecificID = itemID
          end)
          if ok1 or ok2 then
            n = n + 1
          end
        end
      end
    end
  end
  if n > 0 then
    for _, method in ipairs({ "BP_PostChangeItemAvatar", "RefreshAvatar", "BP_RefreshAvatar" }) do
      local fn = nil
      pcall(function()
        fn = comp[method]
      end)
      if isFn(fn) then
        pcall(fn, comp)
        break
      end
    end
  end
  return n
end

local function applyPawnCosmetics(force)
  if not M.started or not M.config.avatar.enabled then
    return false
  end
  if not M.config.avatar.runtimeChange and not M.config.avatar.experimentalSlotDesc then
    return false
  end

  local pc = getPC()
  local pawn = getPawn(pc)
  if pawn == nil then
    return false
  end
  if not force and M._lastAvatarPawn == pawn then
    return false
  end
  local comp = getAvatarComp(pawn)
  if comp == nil then
    return false
  end

  local changed = 0
  if M.config.avatar.experimentalSlotDesc then
    local ok, n = pcall(applySlotDesc, comp)
    if ok then
      changed = changed + (tonumber(n) or 0)
    end
  end

  if M.config.avatar.runtimeChange and not M._avatarChangeUnsupported then
    local id = tonumber(M.config.avatar.slots.ClothesEquipemtSlot)
      or tonumber(M.config.avatar.slots.Clothes) or 0
    if id > 0 then
      local fn = nil
      pcall(function()
        fn = comp.ChangeItemAvatar
      end)
      if isFn(fn) then
        local ok, ret = pcall(fn, comp, id, false)
        if ok and ret ~= false then
          M.stats.avatarChange = M.stats.avatarChange + 1
          changed = changed + 1
        else
          M.stats.avatarChangeFail = M.stats.avatarChangeFail + 1
          if not ok then
            M._avatarChangeUnsupported = true
          end
        end
      else
        M._avatarChangeUnsupported = true
      end
    end
  end

  M._lastAvatarPawn = pawn
  return changed > 0
end

-- ============================================================================
-- 10. Inject avatar (weapon / vehicle / glide / grenade)
--
-- Semua jalur di bawah adalah fungsi Lua milik client yang membangun daftar
-- avatar lokal dari data PlayerInfo. Tidak ada RPC server yang dipanggil.
-- ============================================================================

local COMMER_PATH = "GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil"

local function isLocalPC(pc)
  if pc == nil then
    return true
  end
  local gd = getGameplayData()
  if gd and isFn(gd.GetPlayerController) then
    local ok, localPC = pcall(gd.GetPlayerController)
    if ok and localPC ~= nil then
      return pc == localPC
    end
  end
  local fn = nil
  pcall(function()
    fn = pc.IsLocalPlayerController
  end)
  if isFn(fn) then
    local ok, r = pcall(fn, pc)
    if ok and r ~= nil then
      return r and true or false
    end
  end
  local flag = nil
  pcall(function()
    flag = pc.bIsLocalPlayerController
  end)
  if flag ~= nil then
    return flag and true or false
  end
  return true
end

local function appendUnique(t, id)
  local n = #t + 1
  while t[n] ~= nil do
    n = n + 1
  end
  t[n] = id
end

local function hasSkinID(list, id)
  if type(list) ~= "table" then
    return false
  end
  for _, v in pairs(list) do
    local vid = nil
    if type(v) == "table" then
      vid = tonumber(v.ItemTableID or v.ItemID)
    else
      vid = tonumber(v)
    end
    if vid == id then
      return true
    end
  end
  return false
end

local function cacheGet(key)
  local c = M._cache[key]
  if type(c) == "table" and c.rev == M._configRevision then
    return c.value
  end
  return nil
end

local function cacheSet(key, value)
  M._cache[key] = { rev = M._configRevision, value = value }
  return value
end

-- ---------------------------------------------------------------------------
-- Weapon skins
-- ---------------------------------------------------------------------------

local function autoWeaponSkins()
  local hit = cacheGet("weaponAuto")
  if hit ~= nil then
    return hit
  end
  local out = {}
  local mapping = getTable("WeaponSkinMapping")
  if type(mapping) == "table" then
    local best = {}
    for skinID, row in pairs(mapping) do
      local sid = tonumber(skinID)
      if sid and sid > 0 then
        local base = 0
        if type(row) == "table" then
          base = tonumber(row.WeaponID or row.OriginalID or row.BaseID or row.WeaponId) or 0
        end
        if M.config.weapon.preferOnePerWeapon and base > 0 then
          if best[base] == nil or sid > best[base] then
            best[base] = sid
          end
        else
          out[#out + 1] = sid
        end
      end
    end
    if M.config.weapon.preferOnePerWeapon then
      for _, sid in pairs(best) do
        out[#out + 1] = sid
      end
    end
  end
  table.sort(out)
  local maxAuto = tonumber(M.config.weapon.maxAuto) or 200
  while #out > maxAuto do
    table.remove(out, 1)
  end
  return cacheSet("weaponAuto", out)
end

local function collectWeaponSkins()
  local out = {}
  local seen = {}
  local function add(id)
    local n = tonumber(id)
    if n and n > 0 and not seen[n] then
      seen[n] = true
      out[#out + 1] = n
    end
  end
  for _, id in ipairs(M.config.weapon.skins or {}) do
    add(id)
  end
  if M.config.weapon.autoFromMapping then
    for _, id in ipairs(autoWeaponSkins()) do
      add(id)
    end
  end
  return out
end

local function autoAttachments(skinID)
  local explicit = nil
  if type(M.config.weapon.attachments) == "table" then
    explicit = M.config.weapon.attachments[skinID]
      or M.config.weapon.attachments[tostring(skinID)]
  end
  if type(explicit) == "table" and #explicit > 0 then
    return copyList(explicit)
  end
  if not M.config.weapon.autoAttachments then
    return nil
  end

  local cache = M._cache.attachments
  if type(cache) ~= "table" then
    cache = {}
    M._cache.attachments = cache
  end
  local hit = cache[skinID]
  if type(hit) == "table" and hit.rev == M._configRevision then
    return hit.value
  end

  local out = nil
  local mapping = getTableData("WeaponSkinMapping", skinID)
  local weaponID = skinID
  if type(mapping) == "table" then
    weaponID = tonumber(mapping.WeaponID) or skinID
  end
  local multi = getTableData("WeaponMultiStateCfg", skinID)
  if type(multi) == "table" and tonumber(multi.BaseID) then
    weaponID = tonumber(multi.BaseID)
  end

  local mgr = getItemUpgradeMgr()
  local group = nil
  local level = 0
  if mgr then
    if isFn(mgr.GetGroupID) then
      local ok, r = pcall(mgr.GetGroupID, mgr, weaponID)
      if ok then
        group = tonumber(r)
      end
    end
    if isFn(mgr.GetLevel) then
      local ok, r = pcall(mgr.GetLevel, mgr, weaponID)
      if ok then
        level = tonumber(r) or 0
      end
    end
  end

  if group and group > 0 then
    local unlockTable = getTable("ItemUpgradeUnLockConfig")
    if type(unlockTable) == "table" then
      local parts = {}
      for _, row in pairs(unlockTable) do
        if type(row) == "table" and tonumber(row.GroupID) == group then
          local partID = tonumber(row.PartId)
          if partID then
            local lm = getTableData("ItemUpgradePartLevelMap", partID)
            if type(lm) == "table" and lm.BasePartId and mgr
              and isFn(mgr.GetLevelMatchedPartId) then
              local ok, matched = pcall(mgr.GetLevelMatchedPartId, mgr,
                lm.BasePartId, group, level)
              if ok then
                partID = tonumber(matched) or partID
              end
            end
            parts[#parts + 1] = partID
          end
        end
      end
      table.sort(parts)
      local maxN = tonumber(M.config.weapon.maxAttachmentsPerSkin) or 12
      while #parts > maxN do
        parts[#parts] = nil
      end
      if #parts > 0 then
        out = parts
      end
    end
  end

  cache[skinID] = { rev = M._configRevision, value = out }
  return out
end

local function injectWeapon(pc, weaponList, attachList)
  local ids = collectWeaponSkins()
  local n = 0
  for _, id in ipairs(ids) do
    if not hasSkinID(weaponList, id) then
      appendUnique(weaponList, id)
      n = n + 1
    end
    local existing = attachList[id]
    if existing == nil then
      existing = attachList[tostring(id)]
    end
    if existing == nil then
      local parts = autoAttachments(id)
      if type(parts) == "table" and #parts > 0 then
        attachList[id] = parts
      end
    end
  end
  return n
end

local function installWeaponFallback(mod)
  local old = mod.InitWeaponSkinList
  if not isFn(old) then
    return false
  end
  local new = function(self, pc, weaponList, attachList, pendant)
    local ret = old(self, pc, weaponList, attachList, pendant)
    if not M.config.weapon.enabled or not isLocalPC(pc) or pc == nil then
      return ret
    end
    local list = nil
    pcall(function()
      list = pc.InitialWeaponAvatarList
    end)
    if type(list) == "table" then
      local n = 0
      for _, id in ipairs(collectWeaponSkins()) do
        if not hasSkinID(list, id) then
          local parts = autoAttachments(id)
          list[#list + 1] = {
            ItemTableID = id,
            Count = 1,
            AdditionIntData = parts,
          }
          n = n + 1
        end
      end
      M.stats.weaponInjected = M.stats.weaponInjected + n
    end
    return ret
  end
  if patchValue(mod, "InitWeaponSkinList", new, "weapon",
    COMMER_PATH .. ".InitWeaponSkinList") then
    M._state.weaponInstalled = true
    M._installed.weapon = true
    return true
  end
  return false
end

local function installWeapon()
  if not M.config.weapon.enabled then
    M._installed.weapon = true
    return true
  end
  local mod = safeRequire(COMMER_PATH)
  if mod == nil then
    return false
  end
  if M._state.weaponTarget == mod and M._state.weaponInstalled then
    return true
  end
  M._state.weaponTarget = mod
  M._state.weaponInstalled = false

  local old = nil
  pcall(function()
    old = mod.ConstructWeaponSkinList
  end)
  if not isFn(old) then
    return installWeaponFallback(mod)
  end

  local new = function(self, pc, weaponList, attachList, pendant)
    if not M.config.weapon.enabled or not isLocalPC(pc) then
      return old(self, pc, weaponList, attachList, pendant)
    end
    local wl = copyList(weaponList)
    local al = copyAttachMap(attachList)
    local n = injectWeapon(pc, wl, al)
    local ret = old(self, pc, wl, al, pendant)
    if n > 0 then
      M.stats.weaponInjected = M.stats.weaponInjected + n
    end
    return ret
  end

  if patchValue(mod, "ConstructWeaponSkinList", new, "weapon",
    COMMER_PATH .. ".ConstructWeaponSkinList") then
    M._state.weaponInstalled = true
    M._installed.weapon = true
    return true
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Vehicle skins
-- ---------------------------------------------------------------------------

local function autoVehicleSkins()
  local hit = cacheGet("vehicleAuto")
  if hit ~= nil then
    return hit
  end
  local out = {}
  local mapping = getTable("VehiclePlaneSkinMapping")
  if type(mapping) == "table" then
    local best = {}
    for skinID, row in pairs(mapping) do
      local sid = tonumber(skinID)
      if sid and sid > 0 then
        local base = 0
        if type(row) == "table" then
          base = tonumber(row.OrginalID or row.OriginalID or row.VehicleID) or 0
        end
        if M.config.vehicle.preferOnePerVehicle and base > 0 then
          if best[base] == nil or sid > best[base] then
            best[base] = sid
          end
        else
          out[#out + 1] = sid
        end
      end
    end
    if M.config.vehicle.preferOnePerVehicle then
      for _, sid in pairs(best) do
        out[#out + 1] = sid
      end
    end
  end
  table.sort(out)
  local maxAuto = tonumber(M.config.vehicle.maxAuto) or 30
  while #out > maxAuto do
    table.remove(out, 1)
  end
  return cacheSet("vehicleAuto", out)
end

local function collectVehicleSkins()
  local out = {}
  local seen = {}
  local function add(id)
    local n = tonumber(id)
    if n and n > 0 and not seen[n] then
      seen[n] = true
      out[#out + 1] = n
    end
  end
  for _, id in ipairs(M.config.vehicle.skins or {}) do
    add(id)
  end
  if M.config.vehicle.autoFromMapping then
    for _, id in ipairs(autoVehicleSkins()) do
      add(id)
    end
  end
  return out
end

local function installVehicle()
  if not M.config.vehicle.enabled then
    M._installed.vehicle = true
    return true
  end
  local mod = safeRequire(COMMER_PATH)
  if mod == nil then
    return false
  end
  if M._state.vehicleTarget == mod and M._state.vehicleInstalled then
    return true
  end
  M._state.vehicleTarget = mod
  M._state.vehicleInstalled = false

  local old = nil
  pcall(function()
    old = mod._FillVehicleSkinList
  end)
  if not isFn(old) then
    return false
  end

  local new = function(self, playerInfo, pc)
    if not M.config.vehicle.enabled or not isLocalPC(pc)
      or type(playerInfo) ~= "table" then
      return old(self, playerInfo, pc)
    end

    local pi = copyList(playerInfo)
    local vst = {}
    if type(playerInfo.vst_in_battle) == "table" then
      for k, v in pairs(playerInfo.vst_in_battle) do
        if type(v) == "table" then
          vst[k] = copyList(v)
        else
          vst[k] = v
        end
      end
    end
    pi.vst_in_battle = vst

    local nextKey = 900000
    local n = 0
    for _, skinID in ipairs(collectVehicleSkins()) do
      while vst[nextKey] ~= nil do
        nextKey = nextKey + 1
      end
      vst[nextKey] = { skinID }
      nextKey = nextKey + 1
      n = n + 1
    end

    local show = tonumber(M.config.vehicle.showSkin) or 0
    if show > 0 then
      pi.vst_skin = show
    end

    local ret = old(self, pi, pc)
    if n > 0 then
      M.stats.vehicleInjected = M.stats.vehicleInjected + n
    end
    return ret
  end

  if patchValue(mod, "_FillVehicleSkinList", new, "vehicle",
    COMMER_PATH .. "._FillVehicleSkinList") then
    M._state.vehicleInstalled = true
    M._installed.vehicle = true
    return true
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Glider / parachute
-- ---------------------------------------------------------------------------

local function autoGliderID()
  local hit = cacheGet("gliderAuto")
  if hit ~= nil then
    return hit
  end
  local best = 0
  local items = getTable("Item")
  if type(items) == "table" then
    for id, row in pairs(items) do
      local nid = tonumber(id)
      local sub = type(row) == "table" and tonumber(row.ItemSubType) or nil
      if nid and sub and (sub == 413 or sub == 414 or sub == 415) and nid > best then
        best = nid
      end
    end
  end
  return cacheSet("gliderAuto", best)
end

local function installGlide()
  if not M.config.glide.enabled then
    M._installed.glide = true
    return true
  end
  local mod = safeRequire(COMMER_PATH)
  if mod == nil then
    return false
  end
  if M._state.glideTarget == mod and M._state.glideInstalled then
    return true
  end
  M._state.glideTarget = mod
  M._state.glideInstalled = false

  local old = nil
  pcall(function()
    old = mod._FillGlideList
  end)
  if not isFn(old) then
    return false
  end

  local new = function(self, playerInfo, pc, itemList, flying)
    if not M.config.glide.enabled or not isLocalPC(pc)
      or type(playerInfo) ~= "table" then
      return old(self, playerInfo, pc, itemList, flying)
    end

    local pi = copyList(playerInfo)
    if type(playerInfo.all_knapsack_ext_info) == "table" then
      local extMap = {}
      for k, v in pairs(playerInfo.all_knapsack_ext_info) do
        extMap[k] = (type(v) == "table") and copyList(v) or v
      end
      pi.all_knapsack_ext_info = extMap
    end

    local glider = tonumber(M.config.glide.gliderId) or 0
    if glider <= 0 and M.config.glide.autoPick then
      glider = tonumber(autoGliderID()) or 0
    end
    local aircraft = tonumber(M.config.glide.aircraftId) or 0

    local rolewear = pi.use_rolewear
    local extMap = pi.all_knapsack_ext_info
    if type(extMap) == "table" and rolewear ~= nil then
      local ext = extMap[rolewear]
      if ext == nil then
        ext = extMap[tostring(rolewear)]
      end
      if type(ext) == "table" then
        if glider > 0 then
          ext.gliding = glider
        end
        if aircraft > 0 then
          ext.aircraft_put_id = aircraft
        end
      end
    end

    local ret = old(self, pi, pc, itemList, flying)

    if type(itemList) == "table" and glider > 0 then
      local found = false
      for _, item in ipairs(itemList) do
        local id = nil
        if type(item) == "table" then
          id = tonumber(item.ItemTableID or item.ItemID)
        else
          id = tonumber(item)
        end
        if id == glider then
          found = true
          break
        end
      end
      if not found then
        itemList[#itemList + 1] = { ItemTableID = glider, Count = 1 }
        M.stats.glideInjected = M.stats.glideInjected + 1
      end
    end
    return ret
  end

  if patchValue(mod, "_FillGlideList", new, "glide",
    COMMER_PATH .. "._FillGlideList") then
    M._state.glideInstalled = true
    M._installed.glide = true
    return true
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Grenade / throwable
-- ---------------------------------------------------------------------------

local function installGrenade()
  if not M.config.grenade.enabled then
    M._installed.grenade = true
    return true
  end
  local pcb = safeRequire("GameLua.GameCore.Framework.PlayerControllerBase")
  if pcb == nil then
    pcb = rawget(_G, "PlayerControllerBase")
  end
  if pcb == nil then
    return false
  end
  if M._state.grenadeTarget == pcb and M._state.grenadeInstalled then
    return true
  end
  M._state.grenadeTarget = pcb
  M._state.grenadeInstalled = false

  local old = nil
  pcall(function()
    old = pcb.InitGrenadeAvatarList
  end)
  if not isFn(old) then
    return false
  end

  local new = function(self, reinit)
    local ret = old(self, reinit)
    if not M.config.grenade.enabled or not isLocalPC(self) then
      return ret
    end
    local list = nil
    pcall(function()
      list = self.GrenadeAvatarItemList
    end)
    if list == nil then
      return ret
    end
    local n = 0
    for _, entry in ipairs(M.config.grenade.list) do
      local proto = nil
      local avatar = nil
      if type(entry) == "table" then
        proto = tonumber(entry.proto or entry.protoID or entry[1])
        avatar = tonumber(entry.avatar or entry.avatarID or entry[2])
      end
      if proto and avatar then
        local ok = pcall(function()
          list:Add(proto, avatar)
        end)
        if ok then
          n = n + 1
        end
      end
    end
    if n > 0 then
      M.stats.grenadeInjected = M.stats.grenadeInjected + n
    end
    return ret
  end

  if patchValue(pcb, "InitGrenadeAvatarList", new, "grenade",
    "PlayerControllerBase.InitGrenadeAvatarList") then
    M._state.grenadeInstalled = true
    M._installed.grenade = true
    return true
  end
  return false
end

-- ============================================================================
-- 10.5 Wardrobe depot: item sintetis di Inventory/Wardrobe
--
-- Collection hanya membaca flag "owned". Tab Inventory/Wardrobe membaca
-- entity depot (WardrobeDataEntity) yang diisi server lewat
-- WardrobeData:InitHallDepotData / OnHallDepotDataNotify. Supaya item benar
-- benar muncul di Inventory, entri sintetis ditambahkan ke entity tersebut
-- dengan insID lokal dan field yang sama seperti entri server.
-- ============================================================================

local WARDROBE_DATA_PATH = "client.slua.logic.wardrobe.wardrobe_data"
local WARDROBE_CENTER_PATH = "client.slua.logic.wardrobe.logic_wardrobe_data_center"
local WARDROBE_LOGIC_PATH = "client.slua.logic.wardrobe.logic_wardrobe_new"
local WARDROBE_HANDLER_PATH = "client.network.Protocol.WardRobeHandler"

-- insID asli adalah 64-bit (timestamp << 32). Basis rendah ini tidak mungkin
-- bentrok dan membuat urutan sortir tetap wajar.
local WARDROBE_INS_BASE = 1000000000
local WARDROBE_INS_SPAN = 10000000

local function wardrobeFakeIns(resID)
  local id = tonumber(resID)
  if not id then
    return nil
  end
  return WARDROBE_INS_BASE + id
end

local function isWardrobeFakeIns(insID)
  local id = tonumber(insID)
  if not id then
    return false
  end
  return id >= WARDROBE_INS_BASE and id < WARDROBE_INS_BASE + WARDROBE_INS_SPAN
end

local function getWardrobeEntity(source)
  local center = safeRequire(WARDROBE_CENTER_PATH)
  if type(center) ~= "table" or not isFn(center.GetWardrobeData) then
    return nil
  end
  local ok, entity = pcall(center.GetWardrobeData, center, source)
  if ok and type(entity) == "table" then
    return entity
  end
  return nil
end

local function getWardrobeItemByIns(insID)
  local entity = getWardrobeEntity()
  if not entity or not isFn(entity.GetDataByInsID) then
    return nil
  end
  local ok, item = pcall(entity.GetDataByInsID, entity, insID)
  if ok then
    return item
  end
  return nil
end

-- Field tabel "Item" yang dipakai WardrobeDataEntity:LoadConfigForData.
local function wardrobeRowTabs(row)
  if type(row) ~= "table" then
    return nil
  end
  local main = tonumber(row.WardrobeMainTab)
  local sub = tonumber(row.WardrobeTab)
  if main and main > 0 and sub and sub > 0 then
    return main, sub
  end
  return nil
end

local function wardrobeTypeInList(list, typ)
  if type(list) ~= "table" then
    return false
  end
  if typ ~= nil and list[typ] then
    return true
  end
  for _, v in ipairs(list) do
    if tonumber(v) == typ then
      return true
    end
  end
  return false
end

local function wardrobeTypeAllowed(typ, cfg)
  typ = tonumber(typ)
  local inc = cfg.includeItemTypes
  if type(inc) == "table" and next(inc) ~= nil then
    if not wardrobeTypeInList(inc, typ) then
      return false
    end
  end
  local exc = cfg.excludeItemTypes
  if type(exc) == "table" and typ ~= nil and wardrobeTypeInList(exc, typ) then
    return false
  end
  return true
end

local function asWardrobeItemID(v)
  local n = tonumber(v)
  if n and n >= 10000 and n < 100000000 then
    return n
  end
  return nil
end

-- resID yang sudah punya entri valid di depot. Entri kedaluwarsa tidak
-- dihitung, supaya skin trial yang sudah habis tetap disuntik ulang.
local function wardrobeServerTime()
  local tu = safeRequire("client.common.time_util")
  if type(tu) == "table" and isFn(tu.GetServerTimeInSec) then
    local ok, t = pcall(tu.GetServerTimeInSec)
    if ok and tonumber(t) then
      return tonumber(t)
    end
  end
  return os.time()
end

local function wardrobeValidResSet(entity)
  local data = entity and entity._data
  if type(data) ~= "table" then
    return nil
  end
  local set = {}
  local serverTime = wardrobeServerTime()
  for _, item in pairs(data) do
    if type(item) == "table" then
      local res = tonumber(item.resID)
      local count = tonumber(item.count) or 0
      local expire = tonumber(item.expireTS) or 0
      if res and count > 0 and (expire == 0 or expire > serverTime) then
        set[res] = true
      end
    end
  end
  return set
end

local function wardrobeCandidates(entity, cfg)
  local list, seen = {}, {}
  local existing = nil
  if cfg.mode ~= "all" then
    existing = wardrobeValidResSet(entity)
  end

  local function add(id, row)
    id = asWardrobeItemID(id)
    if not id or seen[id] then
      return
    end
    if existing and existing[id] ~= nil then
      return
    end
    row = row or getItemCfg(id)
    local main, sub = wardrobeRowTabs(row)
    if main == nil then
      return
    end
    if not wardrobeTypeAllowed(row.ItemType, cfg) then
      return
    end
    seen[id] = true
    list[#list + 1] = id
  end

  if cfg.mode == "all" or cfg.mode == "missing" then
    local items = getTable("Item")
    if type(items) == "table" then
      for id, row in pairs(items) do
        add(id, row)
      end
    end
  end

  -- Tambahan eksplisit, mendukung array maupun map.
  local extra = cfg.items
  if type(extra) == "table" then
    for k, v in pairs(extra) do
      local kid = asWardrobeItemID(k)
      local vid = asWardrobeItemID(v)
      if kid then
        add(kid)
      elseif vid then
        add(vid)
      end
    end
  end

  table.sort(list)
  local max = tonumber(cfg.maxItems) or 0
  if max > 0 and #list > max then
    for i = #list, max + 1, -1 do
      list[i] = nil
    end
  end
  return list
end

local function postWardrobeUpdate()
  if not M.config.wardrobe.notify then
    return false
  end
  local ev = rawget(_G, "EventSystem")
  local et = rawget(_G, "EVENTTYPE_WARDROBE")
  local eid = rawget(_G, "EVENTID_WARDROBE_DEPOT_UPDATE")
  if type(ev) == "table" and isFn(ev.postEvent) and et ~= nil and eid ~= nil then
    local ok = pcall(ev.postEvent, ev, et, eid)
    if ok then
      M.stats.wardrobeNotifies = (M.stats.wardrobeNotifies or 0) + 1
      return true
    end
  end
  return false
end

local function wardrobeProbeValid(entity)
  local probe = M._state.wardrobeProbe
  if type(probe) ~= "table" or probe.ins == nil then
    return false
  end
  local maps = entity.InsIDToIndexMap
  local index = type(maps) == "table" and maps[probe.ins] or nil
  if index == nil then
    return false
  end
  local data = entity._data
  local item = type(data) == "table" and data[index] or nil
  return type(item) == "table" and tonumber(item.resID) == probe.res
end

local function injectWardrobeEntity(entity, force)
  local cfg = M.config.wardrobe
  if not M.started or not cfg.enabled or not cfg.inject then
    return 0
  end
  if type(entity) ~= "table" or not isFn(entity.AddData) then
    return 0
  end
  -- InitData membangun ulang _data. Jangan suntik sebelum data server siap.
  if entity.bInit ~= true then
    return 0
  end
  if not force and wardrobeProbeValid(entity) then
    return 0
  end

  local clean = M._state.wardrobeClean
  if not force and type(clean) == "table" and clean.entity == entity
    and clean.count == entity._DataCount then
    return 0
  end

  local candidates = wardrobeCandidates(entity, cfg)
  local getTableDataFn = nil
  local cdt = getCDataTable()
  if cdt and isFn(cdt.GetTableData) then
    getTableDataFn = cdt.GetTableData
  end

  local injected = 0
  local lastIns, lastRes = nil, nil
  for i = 1, #candidates do
    local res = candidates[i]
    local ins = wardrobeFakeIns(res)
    local maps = entity.InsIDToIndexMap
    if ins and not (type(maps) == "table" and maps[ins] ~= nil) then
      local ok, info = pcall(entity.AddData, entity, {
        instid = ins,
        res_id = res,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
      })
      if ok and type(info) == "table" then
        if getTableDataFn and isFn(entity.LoadConfigForData) then
          pcall(entity.LoadConfigForData, entity, info, getTableDataFn)
        end
        -- Cadangan kalau LoadConfigForData belum siap: isi field yang
        -- dibaca filter tab.
        if info.bConfigLoaded ~= true then
          local row = getItemCfg(res)
          local main, sub = wardrobeRowTabs(row)
          if main ~= nil then
            info.itemType = row.ItemType
            info.itemSubType = row.ItemSubType
            info.mainTabType = main
            info.subTabType = sub
            info.itemQuality = row.ItemQuality
            info.bConfigLoaded = true
          end
        end
        if info.bConfigLoaded == true then
          injected = injected + 1
          lastIns, lastRes = ins, res
        end
      end
    end
  end

  if injected > 0 then
    M._state.wardrobeProbe = { ins = lastIns, res = lastRes }
    M._state.wardrobeClean = nil
    M.stats.wardrobeInjected = (M.stats.wardrobeInjected or 0) + injected
    trace("wardrobe inject %d item", injected)
    postWardrobeUpdate()
  else
    -- Semua item sudah ada; hindari scan tabel Item setiap tick.
    M._state.wardrobeClean = { entity = entity, count = entity._DataCount or 0 }
  end
  return injected
end

local injectWardrobe = function(force)
  local cfg = M.config.wardrobe
  if not M.started or not cfg.enabled or not cfg.inject then
    return 0
  end
  local entity = getWardrobeEntity()
  if not entity then
    return 0
  end
  return injectWardrobeEntity(entity, force)
end

local function dropWardrobeReals(changelist)
  local cfg = M.config.wardrobe
  if not cfg.dropOnReal or type(changelist) ~= "table" then
    return 0
  end
  local entity = getWardrobeEntity()
  if not entity or not isFn(entity.RemoveData) then
    return 0
  end
  local removed = 0
  for _, v in pairs(changelist) do
    if type(v) == "table" then
      local res = tonumber(v.res_id or v.resID)
      local cnt = tonumber(v.count)
      if res and res >= 10000 and (cnt == nil or cnt > 0) then
        local ins = wardrobeFakeIns(res)
        local maps = entity.InsIDToIndexMap
        if ins and type(maps) == "table" and maps[ins] ~= nil then
          local ok = pcall(entity.RemoveData, entity, ins)
          if ok then
            removed = removed + 1
          end
        end
      end
    end
  end
  return removed
end

-- Hapus semua entri sintetis saat stop() supaya Inventory kembali ke data
-- server. Dipanggil hanya kalau modul memang pernah menyuntik.
local function cleanupWardrobe()
  local entity = getWardrobeEntity()
  if not entity or not isFn(entity.RemoveData) or type(entity._data) ~= "table" then
    return 0
  end
  local ids = {}
  for _, item in pairs(entity._data) do
    if type(item) == "table" and isWardrobeFakeIns(item.insID) then
      ids[#ids + 1] = item.insID
    end
  end
  local removed = 0
  for i = 1, #ids do
    local ok = pcall(entity.RemoveData, entity, ids[i])
    if ok then
      removed = removed + 1
    end
  end
  if removed > 0 then
    M.stats.wardrobeRemoved = (M.stats.wardrobeRemoved or 0) + removed
    postWardrobeUpdate()
  end
  return removed
end

local function wardrobeWornItem(subType)
  local avatar = safeRequire("client.slua.logic.wardrobe.logic_wardrobe_avatar")
  if type(avatar) ~= "table" or not isFn(avatar.GetCurrentWearPreview) then
    return nil
  end
  local ok, wear = pcall(avatar.GetCurrentWearPreview, avatar, subType)
  if ok and type(wear) == "table" and wear.insID then
    return { instid = wear.insID, res_id = wear.resID }
  end
  return nil
end

-- Cache wrapper per fungsi asli supaya ticker tidak membuat closure baru
-- setiap detik.
local wardrobeWrapCache = setmetatable({}, { __mode = "k" })

local function wardrobeWrap(old, factory)
  if not isFn(old) then
    return nil
  end
  local cached = wardrobeWrapCache[old]
  if cached == nil then
    cached = factory(old)
    wardrobeWrapCache[old] = cached
  end
  return cached
end

local function wardrobeInitWrapper(old)
  return function(self, ...)
    local result = old(self, ...)
    if M.started and M.config.wardrobe.enabled then
      M._state.wardrobeProbe = nil
      M._state.wardrobeClean = nil
      pcall(injectWardrobe)
    end
    return result
  end
end

local function wardrobeNotifyWrapper(old)
  return function(self, changelist, ...)
    local result = old(self, changelist, ...)
    if M.started and M.config.wardrobe.enabled then
      pcall(dropWardrobeReals, changelist)
      M._state.wardrobeClean = nil
      pcall(injectWardrobe)
    end
    return result
  end
end

local function wardrobePutOnWrapper(old)
  return function(self, insID, extra)
    local cfg = M.config.wardrobe
    if M.started and cfg.enabled and cfg.localEquip and isWardrobeFakeIns(insID) then
      local item = getWardrobeItemByIns(insID)
      if item then
        local logic = (type(self) == "table" and isFn(self.on_puton_rsp)) and self or nil
        if logic == nil then
          logic = safeRequire(WARDROBE_LOGIC_PATH)
        end
        if type(logic) == "table" and isFn(logic.on_puton_rsp) then
          local olditem = wardrobeWornItem(item.itemSubType)
          M._state.wardrobeEquipping = true
          local ok, err = pcall(logic.on_puton_rsp, logic, 0, {
            instid = item.insID,
            res_id = item.resID,
            color = item.colorID,
            pattern = item.patternID,
          }, olditem, nil, extra)
          M._state.wardrobeEquipping = false
          if ok then
            M.stats.wardrobeEquipped = (M.stats.wardrobeEquipped or 0) + 1
            trace("wardrobe local equip %s", tostring(item.resID))
            return true
          end
          addError("wardrobeEquip", err)
        end
      end
    end
    return old(self, insID, extra)
  end
end

local function wardrobeHeadShowWrapper(old)
  return function(...)
    if M._state.wardrobeEquipping then
      M.stats.wardrobeRpcBlocked = (M.stats.wardrobeRpcBlocked or 0) + 1
      return
    end
    return old(...)
  end
end

local function installWardrobe()
  local cfg = M.config.wardrobe
  if not M.started or not cfg.enabled then
    return false
  end

  local mod = safeRequire(WARDROBE_DATA_PATH)
  if type(mod) ~= "table" then
    return false
  end

  local okInit = patchValue(mod, "InitHallDepotData",
    wardrobeWrap(mod.InitHallDepotData, wardrobeInitWrapper),
    "wardrobe", "WardrobeData.InitHallDepotData")
  local okNotify = patchValue(mod, "OnHallDepotDataNotify",
    wardrobeWrap(mod.OnHallDepotDataNotify, wardrobeNotifyWrapper),
    "wardrobe", "WardrobeData.OnHallDepotDataNotify")
  if okInit or okNotify then
    M._installed.wardrobe = true
  end

  -- Modul logic hanya di-patch kalau sudah dimuat game. Memaksa require di
  -- awal login bisa menarik macros/import yang belum siap.
  local logic = package and package.loaded and package.loaded[WARDROBE_LOGIC_PATH]
  if cfg.localEquip and type(logic) == "table" and isFn(logic.wardrobe_puton_req) then
    patchValue(logic, "wardrobe_puton_req",
      wardrobeWrap(logic.wardrobe_puton_req, wardrobePutOnWrapper),
      "wardrobe", "WardrobeLogic.wardrobe_puton_req")
  end

  local handler = package and package.loaded and package.loaded[WARDROBE_HANDLER_PATH]
  if cfg.localEquip and type(handler) == "table"
    and isFn(handler.send_depot_set_head_show_req) then
    patchValue(handler, "send_depot_set_head_show_req",
      wardrobeWrap(handler.send_depot_set_head_show_req, wardrobeHeadShowWrapper),
      "wardrobe", "WardRobeHandler.send_depot_set_head_show_req")
  end

  pcall(injectWardrobe)
  return okInit or okNotify
end

-- ============================================================================
-- 11. Fake gacha
-- ============================================================================

local RES_KEYS = {
  "resid", "res_id", "itemid", "item_id", "ItemID", "ItemId",
  "award_id", "reward_id", "id", "ID",
}
local CNT_KEYS = {
  "count", "num", "item_num", "item_count", "Count",
  "award_num", "reward_num", "num_id",
}
local VALID_KEYS = {
  "valid_hours", "valid_time", "expire_hours", "expire_time",
}
local POS_KEYS = {
  "pos_id", "pos", "index", "Index",
}
local NESTED_KEYS = {
  "item", "award", "reward", "prize", "item_info",
  "itemData", "award_info", "drop_item", "item_config",
}
local EXTRA_LIST_FIELDS = {
  "ActivityData", "activityData", "DrawActivityInfo", "drawData",
  "data", "draw_info", "activity_data", "info",
}

local function readNumber(t, keys)
  if type(t) ~= "table" then
    return nil
  end
  for _, key in ipairs(keys) do
    local ok, v = pcall(function()
      return t[key]
    end)
    if ok and v ~= nil then
      local n = tonumber(v)
      if n ~= nil then
        return n
      end
    end
  end
  return nil
end

local function readReward(entry, index)
  if type(entry) == "number" or type(entry) == "string" then
    local id = tonumber(entry)
    if id and id > 0 then
      return { resid = id, count = 1, valid_hours = 0, pos_id = index or 1 }
    end
    return nil
  end
  if type(entry) ~= "table" then
    return nil
  end

  local id = readNumber(entry, RES_KEYS)
  local count = nil
  local valid = nil
  if id == nil or id <= 0 then
    for _, key in ipairs(NESTED_KEYS) do
      local sub = entry[key]
      if type(sub) == "table" then
        local sid = readNumber(sub, RES_KEYS)
        if sid and sid > 0 then
          id = sid
          count = readNumber(sub, CNT_KEYS)
          valid = readNumber(sub, VALID_KEYS)
          break
        end
      end
    end
  end
  if id == nil or id <= 0 then
    return nil
  end

  if count == nil then
    count = readNumber(entry, CNT_KEYS)
  end
  if valid == nil then
    valid = readNumber(entry, VALID_KEYS)
  end
  if count == nil or count < 1 then
    count = 1
  end
  if count > 9999 then
    count = 9999
  end
  if valid == nil or valid < 0 then
    valid = 0
  end
  local pos = readNumber(entry, POS_KEYS) or index or 1

  return {
    resid = math.floor(id),
    count = math.floor(count),
    valid_hours = math.floor(valid),
    pos_id = pos,
  }
end

local function extractRewards(data)
  local out = {}
  if type(data) ~= "table" then
    return out
  end

  local function scan(list)
    if type(list) ~= "table" then
      return
    end
    local n = #list
    if n > 0 then
      for i = 1, math.min(n, 200) do
        local r = readReward(list[i], i)
        if r ~= nil then
          out[#out + 1] = r
        end
      end
    else
      local keys = {}
      for k in pairs(list) do
        keys[#keys + 1] = k
      end
      table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
      end)
      for i = 1, math.min(#keys, 200) do
        local r = readReward(list[keys[i]], i)
        if r ~= nil then
          out[#out + 1] = r
        end
      end
    end
  end

  local function scanMaybeMap(value)
    if type(value) ~= "table" then
      return
    end
    if #value > 0 then
      scan(value)
    else
      local handled = false
      for _, v in pairs(value) do
        if type(v) == "table" then
          scan(v)
          handled = true
        end
      end
      if not handled then
        scan(value)
      end
    end
  end

  scanMaybeMap(data.poolItemConfig)
  scanMaybeMap(data.CurBigAwardPoolConfig)
  scanMaybeMap(data.CurSmallAwardPoolConfig)
  scanMaybeMap(data.dropList)
  scanMaybeMap(data.pool_info)
  scanMaybeMap(data.Items)

  local index = tonumber(data.CurAwardPoolIndex) or 1
  if type(data.AwardPoolConfig) == "table" then
    local entry = data.AwardPoolConfig[index]
      or data.AwardPoolConfig[tostring(index)]
    if type(entry) == "table" then
      scan(entry)
    end
  end
  if type(data.draw_info) == "table" then
    local entry = data.draw_info[index]
      or data.draw_info[tostring(index)]
    if type(entry) == "table" then
      scan(entry.item_list or entry.list or entry.items)
    end
  end
  if type(data.DrawActivityInfo) == "table" then
    scanMaybeMap(data.DrawActivityInfo.pool_info)
  end

  return out
end

local function buildFakeRewards(mod, count)
  local cfg = M.config.fakeGacha
  local out = {}
  local explicit = cfg.rewards
  if type(explicit) == "table" and #explicit > 0 then
    for i = 1, count do
      local r = readReward(explicit[((i - 1) % #explicit) + 1], i)
      if r ~= nil then
        out[#out + 1] = r
      end
    end
    if #out > 0 then
      return out
    end
  end

  local pool = extractRewards(mod)
  if #pool == 0 and type(mod) == "table" then
    for _, field in ipairs(EXTRA_LIST_FIELDS) do
      local sub = mod[field]
      if type(sub) == "table" then
        pool = extractRewards(sub)
        if #pool > 0 then
          break
        end
      end
    end
  end
  if #pool == 0 then
    pool = {
      {
        resid = tonumber(cfg.fallbackResId) or 403003,
        count = 1,
        valid_hours = 0,
        pos_id = 1,
      },
    }
  end

  for i = 1, count do
    local picked = pool[math.random(1, #pool)]
    out[#out + 1] = {
      resid = picked.resid,
      count = picked.count,
      valid_hours = picked.valid_hours,
      pos_id = picked.pos_id or i,
    }
  end
  return out
end

local function showRewardPanel(rewards)
  local logic = safeRequire("client.slua.logic.common.CommonItemGet.Logic_CommonItemGet")
  if logic == nil or not isFn(logic.ShowPanel_DefaultStyle) then
    M.stats.panelFails = M.stats.panelFails + 1
    return false
  end
  local maxPerPanel = tonumber(M.config.fakeGacha.panelBatching) or 10
  if maxPerPanel < 1 then
    maxPerPanel = 1
  end
  local i = 1
  while i <= #rewards do
    local chunk = {}
    for j = i, math.min(i + maxPerPanel - 1, #rewards) do
      local r = rewards[j]
      chunk[#chunk + 1] = {
        res_id = r.resid,
        count = r.count,
        valid_hours = r.valid_hours,
      }
    end
    local ok = pcall(logic.ShowPanel_DefaultStyle, chunk, false, true)
    if not ok then
      ok = pcall(logic.ShowPanel_DefaultStyle, logic, chunk, false, true)
    end
    if not ok then
      M.stats.panelFails = M.stats.panelFails + 1
      return false
    end
    i = i + maxPerPanel
  end
  return true
end

local function detectDrawCount(name, ...)
  local low = tostring(name):lower()
  local cfg = M.config.fakeGacha
  local ten = tonumber(cfg.tenDrawCount) or 10
  if low:find("ten", 1, true) or low:find("multi", 1, true)
    or low:find("double", 1, true) then
    return ten
  end
  local hasTen = false
  local hasTwo = false
  for i = 1, select("#", ...) do
    local v = (select(i, ...))
    if type(v) == "number" then
      if v == 10 then
        hasTen = true
      end
      if v == 2 then
        hasTwo = true
      end
    end
  end
  if hasTen then
    return ten
  end
  -- logic_luckyback_* memakai arg1 == 2 sebagai ten draw.
  if hasTwo and low:find("back", 1, true) then
    return ten
  end
  if low:find("one", 1, true) then
    return 1
  end
  return tonumber(cfg.defaultDrawCount) or 1
end

makeGachaHook = function(old, mod, path, fname)
  return function(...)
    if not M.started or not M.config.fakeGacha.enabled then
      return old(...)
    end
    local count = detectDrawCount(fname, ...)
    local rewards = buildFakeRewards(mod, count)
    if M.config.fakeGacha.showPanel then
      pcall(showRewardPanel, rewards)
    end
    M.stats.fakeDraws = M.stats.fakeDraws + 1
    M.stats.fakeRewards = M.stats.fakeRewards + #rewards
    trace("fake draw %s.%s (%d)", tostring(path), tostring(fname), count)
    return true
  end
end

-- ============================================================================
-- 12. Install pending + ticker + lifecycle
-- ============================================================================

local function installPending()
  if not M.started then
    return
  end
  pcall(scanModules)
  if M.config.profile.enabled or M.config.currency.enabled then
    pcall(installDataMgrHook)
  end
  if M.config.avatar.enabled then
    pcall(installAvatarClass)
  end
  pcall(installWardrobe)
  pcall(installWeapon)
  pcall(installVehicle)
  pcall(installGlide)
  pcall(installGrenade)
  pcall(applyProfile)
  pcall(applyCurrency)
end

function M._tick()
  if not M.started then
    return
  end
  pcall(installPending)
  pcall(applyPawnCosmetics)
end

local function scheduleOnce(delay, fn)
  local ok, ticker = pcall(require, "common.time_ticker")
  if ok and ticker and isFn(ticker.AddTimerOnce) then
    local ok2 = pcall(ticker.AddTimerOnce, delay, fn)
    if ok2 then
      return true
    end
  end
  if isFn(_G.AddTimerOnce) then
    local ok2 = pcall(_G.AddTimerOnce, _G, delay, fn)
    if ok2 then
      return true
    end
  end
  if isFn(_G.AddTimer) then
    local ok2 = pcall(_G.AddTimer, _G, delay, fn)
    if ok2 then
      return true
    end
  end
  return false
end

local function schedule()
  if not M.started or not M.config.tick.enabled then
    return
  end
  local gen = M._timerGen
  if M._scheduledGen == gen then
    return
  end
  M._scheduledGen = gen
  local function step()
    -- Timer dari generasi lama (setelah stop/restart) harus mati.
    if gen ~= M._timerGen then
      return
    end
    M._scheduledGen = nil
    if not M.started then
      return
    end
    pcall(M._tick)
    schedule()
  end
  local delay = tonumber(M.config.tick.interval) or 1.0
  local ok = scheduleOnce(delay, step)
  if not ok then
    M._scheduledGen = nil
    M.stats.timerUnavailable = M.stats.timerUnavailable + 1
  end
end

function M.start(opts)
  if M.started then
    if type(opts) == "table" then
      merge(M.config, opts)
      M.refresh()
    end
    return M
  end
  if type(opts) == "table" then
    merge(M.config, opts)
  end

  M.started = true
  M.errors = {}
  resetStats()
  M._configRevision = M._configRevision + 1
  M._cache = {}
  M._installed = {}
  M._scanned = {}
  M._state = {}
  M._hooks = {}
  M._proxies = {}
  M._patches = {}
  M._avatarChangeUnsupported = false
  M._lastAvatarPawn = nil
  M._timerGen = (M._timerGen or 0) + 1
  M._scheduledGen = nil

  pcall(installPending)
  schedule()
  trace("start v%s", VERSION)
  return M
end

function M.stop()
  M.started = false
  M._timerGen = (M._timerGen or 0) + 1
  M._scheduledGen = nil
  pcall(restoreAll)
  if M._installed.wardrobe then
    pcall(cleanupWardrobe)
  end
  M._installed = {}
  M._state = {}
  M._scanned = {}
  M._cache = {}
  M._lastAvatarPawn = nil
  M._avatarChangeUnsupported = false
  return M
end

function M.restart(opts)
  M.stop()
  return M.start(opts)
end

function M.refresh()
  M._configRevision = M._configRevision + 1
  M._cache = {}
  M._state.wardrobeProbe = nil
  M._state.wardrobeClean = nil
  if M.started then
    pcall(applyProfile)
    pcall(applyCurrency)
    pcall(installPending)
  end
  return M
end

function M.setConfig(partial)
  if type(partial) == "table" then
    merge(M.config, partial)
  end
  return M.refresh()
end

function M.tick()
  M._tick()
  schedule()
  return M
end

function M.applyCosmetics()
  return applyPawnCosmetics(true)
end

-- Paksa injeksi ulang depot (item baru tetap idempoten: yang sudah ada
-- dilewati lewat insID sintetis).
function M.injectWardrobe()
  return injectWardrobe(true)
end

-- Diagnostik depot: jumlah entri total, entri sintetis, dan probe injeksi.
function M.wardrobeInfo()
  local cfg = M.config.wardrobe
  local entity = getWardrobeEntity()
  local out = {
    enabled = (cfg.enabled and cfg.inject) and true or false,
    mode = cfg.mode,
    entity = entity ~= nil,
    total = 0,
    fake = 0,
    injected = M.stats.wardrobeInjected or 0,
    equipped = M.stats.wardrobeEquipped or 0,
    blocked = M.stats.wardrobeRpcBlocked or 0,
    probe = M._state.wardrobeProbe ~= nil,
  }
  if entity and type(entity._data) == "table" then
    for _, item in pairs(entity._data) do
      if type(item) == "table" then
        out.total = out.total + 1
        if isWardrobeFakeIns(item.insID) then
          out.fake = out.fake + 1
        end
      end
    end
  end
  return out
end

function M.status()
  local layers = {}
  for k, v in pairs(M._installed) do
    layers[k] = v and true or false
  end
  local stats = {}
  for k, v in pairs(M.stats) do
    stats[k] = v
  end
  local patches = #M._patches
  local proxies = #M._proxies
  return {
    id = MODULE_ID,
    version = VERSION,
    started = M.started,
    patches = patches,
    proxies = proxies,
    layers = layers,
    stats = stats,
    errors = #M.errors,
    revision = M._configRevision,
  }
end

function M.audit()
  local patches = {}
  for i = 1, #M._patches do
    local p = M._patches[i]
    local cur = nil
    pcall(function()
      cur = p.target[p.key]
    end)
    patches[#patches + 1] = {
      label = p.label,
      tag = p.tag,
      active = (cur == p.new),
    }
  end
  local proxies = {}
  for i = 1, #M._proxies do
    local px = M._proxies[i]
    proxies[#proxies + 1] = {
      label = px.label,
      active = (getmetatable(px.tbl) == px.mt),
    }
  end
  local errors = {}
  for i = 1, #M.errors do
    errors[i] = M.errors[i]
  end
  return {
    patches = patches,
    proxies = proxies,
    errors = errors,
  }
end

-- ============================================================================
-- 13. Diagnostik katalog
-- ============================================================================

function M.findItems(opts)
  opts = opts or {}
  local out = {}
  local items = getTable("Item")
  if type(items) ~= "table" then
    return out
  end
  local wantType = tonumber(opts.type)
  local subMin = tonumber(opts.subMin)
  local subMax = tonumber(opts.subMax)
  local needle = nil
  if opts.nameContains ~= nil then
    needle = tostring(opts.nameContains):lower()
  end

  for id, row in pairs(items) do
    local nid = tonumber(id)
    if nid and type(row) == "table" then
      local typ = tonumber(row.ItemType)
      local sub = tonumber(row.ItemSubType)
      local keep = true
      if wantType ~= nil and typ ~= wantType then
        keep = false
      end
      if keep and subMin ~= nil and (sub or -1) < subMin then
        keep = false
      end
      if keep and subMax ~= nil and (sub or -1) > subMax then
        keep = false
      end
      if keep and needle ~= nil then
        local name = tostring(row.ItemName or row.Name or "")
        if not name:lower():find(needle, 1, true) then
          keep = false
        end
      end
      if keep then
        out[#out + 1] = {
          id = nid,
          name = row.ItemName or row.Name,
          type = typ,
          subtype = sub,
        }
      end
    end
  end

  table.sort(out, function(a, b)
    return a.id > b.id
  end)
  local limit = tonumber(opts.limit) or 50
  while #out > limit do
    out[#out] = nil
  end
  return out
end

function M.dumpItem(id)
  return getItemCfg(id), getItemName(id)
end

function M.describe()
  local st = M.status()
  print(string.format("[UNLOCK470] v%s started=%s patches=%d proxies=%d errors=%d",
    st.version, tostring(st.started), st.patches, st.proxies, st.errors))
  local layers = {}
  for k, v in pairs(st.layers) do
    if v then
      layers[#layers + 1] = k
    end
  end
  table.sort(layers)
  print("[UNLOCK470] layers: " .. (#layers > 0 and table.concat(layers, ", ") or "-"))
  print(string.format("[UNLOCK470] weapon=%d vehicle=%d glide=%d grenade=%d fakeDraws=%d",
    st.stats.weaponInjected or 0, st.stats.vehicleInjected or 0,
    st.stats.glideInjected or 0, st.stats.grenadeInjected or 0,
    st.stats.fakeDraws or 0))
  print(string.format("[UNLOCK470] wardrobe=%d equipped=%d",
    st.stats.wardrobeInjected or 0, st.stats.wardrobeEquipped or 0))
  return st
end

-- ============================================================================
-- 14. Auto-load
-- ============================================================================

do
  local cfg = rawget(_G, "UNLOCK470_CONFIG")
  if type(cfg) == "table" then
    merge(M.config, cfg)
  end
  if M.config.autoStart then
    local ok, err = pcall(M.start)
    if not ok then
      addError("autoStart", err)
    end
  end
end

return M
