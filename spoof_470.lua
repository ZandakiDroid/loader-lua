--[[
  spoof_470.lua - lapisan "validation spoof" untuk esp_pack_2/2.lua (PUBG 4.7.0)

  Prinsip:
    * Jangan memblokir semua telemetri (itu sendiri anomali). Yang dilakukan
      modul ini adalah menjaga nilai yang dilihat server/DS tetap berada di
      dalam amplop yang dianggap legal, lalu mematikan monitor client yang
      menghasilkan laporan replay/Buggly untuk fitur yang sedang dipakai.
    * Modul ini TIDAK mengubah 2.lua. Bisa dimuat sebelum atau sesudah 2.lua.
      Hook yang belum tersedia akan dicoba ulang oleh ticker.

  Sumber ambang (bukan tebakan), dari source 4.7.0:
    GameLua/Mod/BaseMod/DS/Weapon/LagCompensationSubSystem.lua
      - BlockBoxScale per ping shooter:
          PST_100_200 = 3.0, PST_200_350 = 2.5, PST_350_500 = 2.0,
          PST_500_700 = 1.5, PST_G700 = 1.5
      - SwitchHitOutCollisionBox.PunishThresHold = 10
      - SwitchHitComponentUnvalid.PunishThresHold = 5
      - TolMuzImpDir2HeadMuzzleDir = -10
      - TolShootPos2History = 50, TolShootPos2History2 = 100
      - TolerateHitDataDelayTime = 1.2 (1.0 pada gray publish)
    GameReportConfig.ReplayConfigs[5] = OnReportControlRotationSuddenChange
    ReportCrashKitFeature:HandlePlayerEnterFighting memasang
      bEnableControlRotationSuddenChangeMonitor = true pada PlayerController.

  Pemakaian:
    dofile("esp_pack_2/spoof_470.lua")
    -- atau, kontrol penuh:
    _G.SPOOF470_CONFIG = { autoStart = false }
    local SP = dofile("esp_pack_2/spoof_470.lua")
    SP.start()

  API:
    SPOOF470.start(opts) / stop() / restart(opts) / status() / audit() / _tick()
    SPOOF470.config  (ubah langsung; wrapper membaca config secara live)
]]

local MODULE_ID = "spoof_470"
local VERSION = "1.1.0"

local existing = rawget(_G, "SPOOF470")
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
  _hooks = {},
  _baseStats = {},
}

_G.SPOOF470 = M

-- ============================================================================
-- 0. Konfigurasi
-- ============================================================================

M.config = {
  autoStart = true,
  verbose = false,

  -- Aimbot: batasi kecepatan putar per panggilan SetControlRotation dan
  -- matikan monitor "control rotation sudden change".
  aim = {
    enabled = true,
    -- 7 derajat per panggilan. 2.lua memanggil ini tiap ~20 ms saat aim aktif,
    -- jadi ~350 derajat/detik: masih dalam rentang flick manusia, tetapi tidak
    -- lagi lompatan 90-180 derajat dalam satu frame.
    maxDegPerTick = 7.0,
    jitterDeg = 0.08,
    disableSuddenChangeMonitor = true,
    sources = {
      AimTouch = true,
      Aimbot = true,
      AimTouchV2 = true,
    },
  },

  -- Hitbox: cap skala sesuai BlockBoxScale resmi DS, dikali faktor aman.
  -- Ping dibaca dari PlayerState.Ping * 4 (ms), sama seperti CharacterBase
  -- dan ReportClientPingSystem di source 4.7.0.
  hitbox = {
    enabled = true,
    safety = 0.9,
    unknownPingCap = 2.2,
    -- PST_0_100 tidak punya entri BlockBoxScale di Lua DS. Nilai native-nya
    -- tidak bisa dipastikan. 2.2 x 0.9 = 1.98: Headshot 2x nyaris utuh tetapi
    -- tetap di bawah 2.0, batas terendah yang mungkin dipakai native.
    lowPingCap = 2.2,
    hardMax = 3.0,
    minScale = 1.0,
    tiers = {
      { 200, 3.0 },
      { 350, 2.5 },
      { 500, 2.0 },
      { 700, 1.5 },
      { math.huge, 1.5 },
    },
  },

  -- Nilai yang ikut diverifikasi DS saat shoot verification. Recoil/spread
  -- tidak masuk daftar karena hanya lokal; tiga field ini yang bisa membuat
  -- cadence/damage/kecepatan peluru terlihat mustahil bila diubah.
  combat = {
    enabled = true,
    fields = { "BulletFireSpeed", "ShootInterval", "BaseDamage" },
  },

  -- Bullet Track memanggil ShootBulletInner dari Lua. Guard ini:
  --   * membatasi frekuensi sinkronisasi (bukan memblokir tembakan),
  --   * menyelaraskan ControlRotation ke arah tembakan bila sudutnya <= maxSyncDeg,
  --   * opsional memblokir tembakan yang sudutnya > maxOffAxisDeg.
  -- Tidak menebak arti aimPos; guard hanya memakai rot.
  shot = {
    enabled = true,
    minInterval = 0.03,
    syncRotation = true,
    maxSyncDeg = 20.0,
    blockOffAxis = false,
    maxOffAxisDeg = 45.0,
  },

  -- Rate limit interaksi. 2.lua sendiri punya cooldown per item 0.6 dtk,
  -- tetapi FastLoot masih bisa 2 item / 0.1 dtk untuk item berbeda. Server
  -- tetap memvalidasi jarak/state; guard ini menjaga laju RPC tetap wajar.
  interact = {
    enabled = true,
    pickupInterval = 0.25,
    rescueInterval = 0.75,
  },

  -- Backstop: buang kunci konfigurasi cheat yang unik dari payload keluar.
  -- Sengaja tidak memakai kata umum (Accuracy/Headshot) agar statistik sah
  -- tidak ikut terhapus.
  payload = {
    enabled = true,
    maxDepth = 2,
    deny = {
      RapzhangConfig = true,
      RapzhangState = true,
      CustomTextData = true,
      SPOOF470 = true,
      AP470 = true,
      AC470 = true,
      AimTouchEnable = true,
      CustomMagicBullet = true,
      BTAllSmartHead = true,
      BulletTrack = true,
      Sup_FastLoot = true,
      Sup_AutoRescue = true,
      ForceFriend = true,
      ModSkin = true,
      ModEmote = true,
      X3FakeVisual = true,
    },
  },

  monitor = {
    interval = 0.5,
  },
}

-- ============================================================================
-- 1. Utilitas
-- ============================================================================

local function isFn(v)
  return type(v) == "function"
end

local function isTable(v)
  return type(v) == "table"
end

local function hostTable(v)
  local t = type(v)
  if t == "table" or t == "userdata" then
    return v
  end
  return nil
end

local function now()
  local t = nil
  pcall(function()
    if os and os.clock then
      t = os.clock()
    end
  end)
  return tonumber(t) or 0.0
end

local function clamp(v, lo, hi)
  v = tonumber(v)
  if v == nil or v ~= v then
    return lo
  end
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

local function addError(tag, err)
  M.errors[#M.errors + 1] = tostring(tag) .. ": " .. tostring(err)
  M.stats.errors = (M.stats.errors or 0) + 1
  if M.config.verbose then
    pcall(function()
      print("[SPOOF470] " .. tostring(tag) .. ": " .. tostring(err))
    end)
  end
end

local function merge(dst, src)
  if type(src) ~= "table" then
    return dst
  end
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

local function resetStats()
  M.stats = {
    aimClamped = 0,
    monitorOff = 0,
    hitboxAdjusted = 0,
    combatRestored = 0,
    shotSynced = 0,
    shotRateLimited = 0,
    shotBlocked = 0,
    payloadScrubbed = 0,
    interactBlocked = 0,
    errors = 0,
    patched = 0,
  }
end

resetStats()

-- ============================================================================
-- 2. Registry patch + restore
--
-- Satu target+key hanya punya satu record. Kalau modul lain (2.lua / loader)
-- mengganti fungsi setelah kita, record di-update: old = fungsi eksternal
-- terbaru, sehingga stop() tidak menghapus hook modul lain.
-- ============================================================================

local function findPatch(target, key)
  for i = #M._patches, 1, -1 do
    local p = M._patches[i]
    if p.target == target and p.key == key then
      return i, p
    end
  end
  return nil, nil
end

local function patchValue(target, key, newFn, tag)
  if target == nil or type(key) ~= "string" or not isFn(newFn) then
    return false
  end

  local okOld, old = pcall(function()
    return target[key]
  end)
  if not okOld or old == nil then
    return false
  end
  if old == newFn then
    return true
  end

  local okSet = pcall(function()
    target[key] = newFn
  end)
  if not okSet then
    return false
  end

  local okCheck, check = pcall(function()
    return target[key]
  end)
  if not okCheck or check ~= newFn then
    return false
  end

  local idx, p = findPatch(target, key)
  if idx ~= nil then
    p.old = old
    p.new = newFn
    p.tag = tag
  else
    M._patches[#M._patches + 1] = {
      target = target,
      key = key,
      old = old,
      new = newFn,
      tag = tag,
    }
    M.stats.patched = M.stats.patched + 1
  end
  return true
end

local function restoreAll()
  for i = #M._patches, 1, -1 do
    local p = M._patches[i]
    pcall(function()
      -- Hanya kembalikan jika wrapper kita masih yang terpasang. Kalau sudah
      -- diganti modul lain, biarkan fungsi eksternal itu yang aktif.
      local cur = p.target[p.key]
      if cur == p.new then
        p.target[p.key] = p.old
      end
    end)
  end
  M._patches = {}
  M._hooks = {}
end

-- ============================================================================
-- 3. Akses runtime game
-- ============================================================================

local function getPC()
  local pc = nil
  pcall(function()
    local esp = rawget(_G, "ESP")
    if esp and isFn(esp.GetController) then
      pc = esp.GetController()
    end
  end)
  if pc == nil then
    pcall(function()
      local hud = rawget(_G, "slua_GameFrontendHUD")
      if hud and isFn(hud.GetPlayerController) then
        pc = hud:GetPlayerController()
      end
    end)
  end
  if pc == nil then
    pcall(function()
      local gd = package.loaded["GameLua.GameCore.Data.GameplayData"]
      if gd and isFn(gd.GetPlayerController) then
        pc = gd.GetPlayerController()
      end
    end)
  end
  if pc == nil then
    pcall(function()
      local game = rawget(_G, "Game")
      if game and isFn(game.GetPlayerController) then
        pc = game:GetPlayerController(0)
      end
    end)
  end
  return pc
end

local function getCharacter()
  local pc = getPC()
  if pc == nil then
    return nil
  end
  local ch = nil
  pcall(function()
    if isFn(pc.GetPlayerCharacterSafety) then
      ch = pc:GetPlayerCharacterSafety()
    end
  end)
  if ch == nil then
    pcall(function()
      if isFn(pc.GetCurPlayerCharacter) then
        ch = pc:GetCurPlayerCharacter()
      end
    end)
  end
  if ch == nil then
    pcall(function()
      ch = pc.Pawn
    end)
  end
  if ch == nil then
    pcall(function()
      local gd = package.loaded["GameLua.GameCore.Data.GameplayData"]
      if gd and isFn(gd.GetPlayerCharacter) then
        ch = gd.GetPlayerCharacter()
      end
    end)
  end
  return ch
end

-- Ping shooter dalam ms. PlayerState.Ping adalah satuan 0.25 ms (x4 = ms),
-- sama dengan pemakaian di CharacterBase/ReportClientPingSystem.
-- Tidak di-cache: perubahan tier ping harus langsung terlihat oleh hitbox,
-- dan satu pembacaan properti per mesh masih murah.
local function pingMs()
  local pc = getPC()
  if pc == nil then
    return nil
  end

  local p = nil
  pcall(function()
    local ps = pc.PlayerState
    if ps then
      p = tonumber(ps.Ping)
      if p ~= nil then
        p = p * 4
      end
    end
  end)
  if p == nil then
    pcall(function()
      local q = tonumber(pc.Ping)
      if q ~= nil and q > 0 then
        p = q
      end
    end)
  end
  if p ~= nil and (p <= 0 or p ~= p or p > 5000) then
    p = nil
  end
  return p
end

local function getCurrentWeapon(me)
  if me == nil then
    return nil
  end
  local w = nil
  pcall(function()
    if isFn(me.GetCurrentWeapon) then
      w = me:GetCurrentWeapon()
    end
  end)
  if w == nil then
    pcall(function()
      if isFn(me.GetCurrentShootWeapon) then
        w = me:GetCurrentShootWeapon()
      end
    end)
  end
  if w == nil then
    pcall(function()
      local wm = me.WeaponManagerComponent
      if wm and isFn(wm.GetCurrentWeapon) then
        w = wm:GetCurrentWeapon()
      end
    end)
  end
  return w
end

local function weaponEntities(w)
  local list = {}
  if w == nil then
    return list
  end
  pcall(function()
    if w.ShootWeaponEntity_GEN_VARIABLE ~= nil then
      list[#list + 1] = w.ShootWeaponEntity_GEN_VARIABLE
    end
  end)
  pcall(function()
    if w.ShootWeaponEntity ~= nil then
      list[#list + 1] = w.ShootWeaponEntity
    end
  end)
  pcall(function()
    local sc = w.ShootWeaponComponent
    if sc and sc.ShootWeaponEntityComponent ~= nil then
      list[#list + 1] = sc.ShootWeaponEntityComponent
    end
  end)
  return list
end

-- ============================================================================
-- 4. Aim guard
-- ============================================================================

local function rotationDelta(cur, target)
  local dp = (tonumber(target.Pitch) or 0) - (tonumber(cur.Pitch) or 0)
  local dy = (tonumber(target.Yaw) or 0) - (tonumber(cur.Yaw) or 0)
  dp = ((dp + 180) % 360) - 180
  dy = ((dy + 180) % 360) - 180
  return dp, dy
end

local function clampRotation(pc, rot)
  local cur = nil
  pcall(function()
    cur = pc:GetControlRotation()
  end)
  if cur == nil then
    return rot
  end

  local dp, dy = rotationDelta(cur, rot)
  local mag = math.sqrt(dp * dp + dy * dy)
  local maxd = tonumber(M.config.aim.maxDegPerTick) or 0
  if maxd <= 0 or mag <= maxd then
    return rot
  end

  local k = maxd / mag
  local jitter = tonumber(M.config.aim.jitterDeg) or 0
  local jp, jy = 0, 0
  if jitter > 0 then
    local t = now() * 1000.0
    jp = math.sin(t * 1.7) * jitter
    jy = math.cos(t * 2.3) * jitter
  end

  return {
    Pitch = clamp((tonumber(cur.Pitch) or 0) + dp * k + jp, -89.0, 89.0),
    Yaw = (tonumber(cur.Yaw) or 0) + dy * k + jy,
    Roll = tonumber(rot.Roll) or 0,
  }
end

local function shouldClampSource(source)
  if source == nil then
    return false
  end
  local list = M.config.aim.sources
  return type(list) == "table" and list[source] == true
end

local function hookAimOnPC(pc)
  if pc == nil then
    return false
  end
  local curFn = nil
  pcall(function()
    curFn = pc.SetControlRotation
  end)
  if not isFn(curFn) then
    return false
  end
  if M._hooks.aimPC == pc and M._hooks.aimPCFn == curFn then
    return true
  end

  local old = curFn
  local new = function(self, rot, source, ...)
    if M.started and M.config.aim.enabled and shouldClampSource(source) then
      local ok, clamped = pcall(clampRotation, self, rot)
      if ok and clamped ~= nil then
        rot = clamped
        M.stats.aimClamped = M.stats.aimClamped + 1
      end
    end
    return old(self, rot, source, ...)
  end

  if patchValue(pc, "SetControlRotation", new, "aim.pc") then
    M._hooks.aimPC = pc
    M._hooks.aimPCFn = new
    return true
  end
  return false
end

local function hookAimOnClass()
  local cls = M._hooks.aimClass
  if cls == nil then
    local ok, imported = pcall(import, "PlayerController")
    if not ok or imported == nil then
      return false
    end
    cls = imported
  end

  local curFn = nil
  pcall(function()
    curFn = cls.SetControlRotation
  end)
  if not isFn(curFn) then
    return false
  end
  if M._hooks.aimClass == cls and M._hooks.aimClassFn == curFn then
    return true
  end

  local old = curFn
  local new = function(self, rot, source, ...)
    if M.started and M.config.aim.enabled and shouldClampSource(source) then
      local ok, clamped = pcall(clampRotation, self, rot)
      if ok and clamped ~= nil then
        rot = clamped
        M.stats.aimClamped = M.stats.aimClamped + 1
      end
    end
    return old(self, rot, source, ...)
  end

  if patchValue(cls, "SetControlRotation", new, "aim.class") then
    M._hooks.aimClass = cls
    M._hooks.aimClassFn = new
    return true
  end
  return false
end

local function ensureMonitorOff()
  if not M.config.aim.enabled or not M.config.aim.disableSuddenChangeMonitor then
    return
  end
  local pc = getPC()
  if pc == nil then
    return
  end

  local targets = { pc }
  pcall(function()
    if pc.Pawn ~= nil then
      targets[#targets + 1] = pc.Pawn
    end
  end)
  pcall(function()
    if pc.PlayerState ~= nil then
      targets[#targets + 1] = pc.PlayerState
    end
  end)
  local ch = getCharacter()
  if ch ~= nil and ch ~= pc then
    targets[#targets + 1] = ch
  end

  for i = 1, #targets do
    local obj = targets[i]
    pcall(function()
      if obj.bEnableControlRotationSuddenChangeMonitor == true then
        obj.bEnableControlRotationSuddenChangeMonitor = false
        M.stats.monitorOff = M.stats.monitorOff + 1
      end
    end)
  end
end

local RK_PATH = "GameLua.Mod.BaseMod.GamePlay.Feature.Player.ReportCrashKitFeature"

local function hookCrashKit()
  local mod = package.loaded[RK_PATH]
  if type(mod) ~= "table" then
    return false
  end
  local curFn = mod.HandlePlayerEnterFighting
  if not isFn(curFn) then
    return false
  end
  if M._hooks.crashKitFn == curFn then
    return true
  end

  local old = curFn
  local new = function(self, ...)
    local r = old(self, ...)
    pcall(function()
      local owner = self and self.Owner
      if owner then
        owner.bEnableControlRotationSuddenChangeMonitor = false
        if owner.Pawn then
          owner.Pawn.bEnableControlRotationSuddenChangeMonitor = false
        end
        if owner.PlayerState then
          owner.PlayerState.bEnableControlRotationSuddenChangeMonitor = false
        end
      end
    end)
    return r
  end

  if patchValue(mod, "HandlePlayerEnterFighting", new, "aim.crashkit") then
    M._hooks.crashKitFn = new
    return true
  end
  return false
end

-- ============================================================================
-- 5. Hitbox guard (BlockBoxScale per ping)
-- ============================================================================

local function capForPing(ping)
  local cfg = M.config.hitbox
  local safety = tonumber(cfg.safety) or 1.0
  local hardMax = tonumber(cfg.hardMax) or 3.0
  local minScale = tonumber(cfg.minScale) or 1.0
  local raw

  if ping == nil then
    raw = tonumber(cfg.unknownPingCap) or 2.0
  elseif ping < 100 then
    raw = tonumber(cfg.lowPingCap) or 2.0
  else
    raw = 1.0
    for i = 1, #cfg.tiers do
      local limit = tonumber(cfg.tiers[i][1]) or math.huge
      local scale = tonumber(cfg.tiers[i][2]) or 1.0
      if ping <= limit then
        raw = scale
        break
      end
    end
  end

  return clamp(raw * safety, minScale, hardMax)
end

local function rebuildHash(h, b, l)
  return string.format("MB_%.2f_%.2f_%.2f", h, b, l)
end

local function installHitboxGet()
  local cur = rawget(_G, "RapzhangGetHitboxScale")
  if not isFn(cur) then
    return false
  end
  if cur == M._hooks.hitboxGet then
    return true
  end

  local new = function(forTicker, ...)
    local hash, h, b, l = cur(forTicker, ...)
    if not M.started or not M.config.hitbox.enabled then
      return hash, h, b, l
    end
    if hash == nil or hash == "OFF" then
      return hash, h, b, l
    end
    local cap = capForPing(pingMs())
    local nh = math.min(tonumber(h) or 1.0, cap)
    local nb = math.min(tonumber(b) or 1.0, cap)
    local nl = math.min(tonumber(l) or 1.0, cap)
    local newHash = rebuildHash(nh, nb, nl)
    if newHash ~= hash then
      M.stats.hitboxAdjusted = M.stats.hitboxAdjusted + 1
    end
    return newHash, nh, nb, nl
  end

  if patchValue(_G, "RapzhangGetHitboxScale", new, "hitbox.get") then
    M._hooks.hitboxGet = new
    return true
  end
  return false
end

local function installHitboxApply()
  local cur = rawget(_G, "RapzhangApplyHitbox")
  if not isFn(cur) then
    return false
  end
  if cur == M._hooks.hitboxApply then
    return true
  end

  local new = function(mesh, hash, h, b, l, stateKey, ...)
    if not M.started or not M.config.hitbox.enabled then
      return cur(mesh, hash, h, b, l, stateKey, ...)
    end
    if hash ~= nil and hash ~= "OFF" then
      local cap = capForPing(pingMs())
      h = math.min(tonumber(h) or 1.0, cap)
      b = math.min(tonumber(b) or 1.0, cap)
      l = math.min(tonumber(l) or 1.0, cap)
      hash = rebuildHash(h, b, l)
    end
    return cur(mesh, hash, h, b, l, stateKey, ...)
  end

  if patchValue(_G, "RapzhangApplyHitbox", new, "hitbox.apply") then
    M._hooks.hitboxApply = new
    return true
  end
  return false
end

-- ============================================================================
-- 6. Combat stat guard
-- ============================================================================

local function statBase(e)
  local base = nil
  pcall(function()
    base = e.OriginalStatsCached
  end)
  if type(base) == "table" then
    return base
  end

  local key = e
  base = M._baseStats[key]
  if type(base) == "table" then
    return base
  end

  base = {}
  local fields = M.config.combat.fields
  for i = 1, #fields do
    local f = fields[i]
    local v = nil
    pcall(function()
      v = e[f]
    end)
    if v ~= nil then
      base[f] = v
    end
  end
  M._baseStats[key] = base
  return base
end

local function guardCombat()
  if not M.config.combat.enabled then
    return
  end
  local me = getCharacter()
  if me == nil then
    return
  end

  local w = getCurrentWeapon(me)
  if w == nil then
    return
  end

  local list = weaponEntities(w)
  local fields = M.config.combat.fields
  for i = 1, #list do
    local e = list[i]
    if e ~= nil then
      local base = statBase(e)
      for j = 1, #fields do
        local f = fields[j]
        local bv = base[f]
        local cv = nil
        pcall(function()
          cv = e[f]
        end)
        if bv ~= nil and cv ~= nil and cv ~= bv then
          pcall(function()
            e[f] = bv
          end)
          M.stats.combatRestored = M.stats.combatRestored + 1
        end
      end
    end
  end
end

-- ============================================================================
-- 7. Shot guard (Bullet Track)
-- ============================================================================

local lastShotAt = -999.0

local function installShotGuard()
  if not M.config.shot.enabled then
    return false
  end
  if not (_G.RapzhangConfig and _G.RapzhangConfig.BulletTrack == true) then
    return false
  end

  local me = getCharacter()
  local w = getCurrentWeapon(me)
  if w == nil then
    return false
  end

  local targets = {}
  pcall(function()
    if w.ShootWeaponComponent ~= nil then
      targets[#targets + 1] = w.ShootWeaponComponent
    end
  end)
  pcall(function()
    local sc = w.ShootWeaponComponent
    if sc and sc.ShootWeaponEntityComponent ~= nil then
      targets[#targets + 1] = sc.ShootWeaponEntityComponent
    end
  end)
  pcall(function()
    if w.ShootWeaponEntity ~= nil then
      targets[#targets + 1] = w.ShootWeaponEntity
    end
  end)

  M._hooks.shot = M._hooks.shot or {}
  local any = false

  for i = 1, #targets do
    local target = targets[i]
    local cur = nil
    pcall(function()
      cur = target.ShootBulletInner
    end)
    if isFn(cur) then
      local key = tostring(target)
      if M._hooks.shot[key] ~= cur then
        local old = cur
        local new = function(self, aimPos, rot, shootId, ...)
          if not M.started or not M.config.shot.enabled then
            return old(self, aimPos, rot, shootId, ...)
          end

          local t = now()
          if (t - lastShotAt) >= (tonumber(M.config.shot.minInterval) or 0.03) then
            lastShotAt = t
            local pc = getPC()
            if pc ~= nil and rot ~= nil and rot.Pitch ~= nil and rot.Yaw ~= nil then
              local curRot = nil
              pcall(function()
                curRot = pc:GetControlRotation()
              end)
              if curRot ~= nil then
                local dp, dy = rotationDelta(curRot, rot)
                local mag = math.sqrt(dp * dp + dy * dy)
                local maxSync = tonumber(M.config.shot.maxSyncDeg) or 20.0
                if M.config.shot.blockOffAxis == true
                  and mag > (tonumber(M.config.shot.maxOffAxisDeg) or 45.0) then
                  M.stats.shotBlocked = M.stats.shotBlocked + 1
                  return nil
                end
                if M.config.shot.syncRotation == true and mag <= maxSync then
                  pcall(function()
                    pc:SetControlRotation({
                      Pitch = tonumber(rot.Pitch) or 0,
                      Yaw = tonumber(rot.Yaw) or 0,
                      Roll = tonumber(rot.Roll) or 0,
                    }, "BulletTrackSync")
                  end)
                  M.stats.shotSynced = M.stats.shotSynced + 1
                end
              end
            end
          else
            M.stats.shotRateLimited = M.stats.shotRateLimited + 1
          end

          return old(self, aimPos, rot, shootId, ...)
        end

        if patchValue(target, "ShootBulletInner", new, "shot") then
          M._hooks.shot[key] = new
          any = true
        end
      end
    end
  end
  return any
end

-- ============================================================================
-- 8. Payload scrub
-- ============================================================================

local function scrub(tbl, depth)
  if type(tbl) ~= "table" or depth <= 0 then
    return tbl
  end
  local deny = M.config.payload.deny
  local ok = pcall(function()
    for k, v in pairs(tbl) do
      if type(k) == "string" and deny[k] == true then
        tbl[k] = nil
        M.stats.payloadScrubbed = M.stats.payloadScrubbed + 1
      elseif type(v) == "table" then
        scrub(v, depth - 1)
      end
    end
  end)
  if not ok then
    M.stats.payloadScrubFailed = (M.stats.payloadScrubFailed or 0) + 1
  end
  return tbl
end

local unpackFn = table.unpack or unpack

local function scrubArgs(...)
  local n = select("#", ...)
  local args = { ... }
  local depth = tonumber(M.config.payload.maxDepth) or 2
  for i = 1, n do
    if type(args[i]) == "table" then
      scrub(args[i], depth)
    end
  end
  if unpackFn ~= nil then
    return unpackFn(args, 1, n)
  end
  return nil
end

local function installPayload()
  local net = hostTable(rawget(_G, "NetUtil"))
  local any = false
  if net ~= nil then
    for _, name in ipairs({ "SendPkg", "SendPacket" }) do
      local cur = nil
      pcall(function()
        cur = net[name]
      end)
      if isFn(cur) and M._hooks["payload." .. name] ~= cur then
        local old = cur
        local new = function(...)
          if M.started and M.config.payload.enabled then
            return old(scrubArgs(...))
          end
          return old(...)
        end
        if patchValue(net, name, new, "payload." .. name) then
          M._hooks["payload." .. name] = new
          any = true
        end
      end
    end
  end

  local curRPC = rawget(_G, "SendRPC")
  if isFn(curRPC) and M._hooks["payload.SendRPC"] ~= curRPC then
    local old = curRPC
    local new = function(...)
      if M.started and M.config.payload.enabled then
        return old(scrubArgs(...))
      end
      return old(...)
    end
    if patchValue(_G, "SendRPC", new, "payload.SendRPC") then
      M._hooks["payload.SendRPC"] = new
      any = true
    end
  end

  return any
end

-- ============================================================================
-- 9. Interact guard (default ON, bisa dimatikan)
-- ============================================================================

local lastPickupAt = -999.0
local lastRescueAt = -999.0

local function makePickupWrapper(old)
  return function(self, ...)
    if M.started and M.config.interact.enabled then
      local interval = tonumber(M.config.interact.pickupInterval) or 0.25
      local t = now()
      if (t - lastPickupAt) < interval then
        M.stats.interactBlocked = M.stats.interactBlocked + 1
        return false
      end
      lastPickupAt = t
    end
    return old(self, ...)
  end
end

local function installPickupGuard()
  if not M.config.interact.enabled then
    return false
  end

  local me = getCharacter()
  if me == nil then
    return false
  end

  M._hooks.pickup = M._hooks.pickup or {}
  local any = false

  local targets = {}
  local panel = nil
  pcall(function()
    local um = rawget(_G, "UIManager")
    local cfg = um and um.UI_Config_InGame and um.UI_Config_InGame.PickUpListPanel
    if um and cfg and isFn(um.GetUI) then
      panel = um.GetUI(cfg)
    end
  end)
  if panel ~= nil then
    targets[#targets + 1] = panel
  end

  local pm = nil
  pcall(function()
    if isFn(me.GetPickupManager) then
      pm = me:GetPickupManager()
    end
  end)
  if pm ~= nil then
    targets[#targets + 1] = pm
  end

  for i = 1, #targets do
    local target = targets[i]
    for _, method in ipairs({ "PickUpWrapperActorWithoutAnim", "PickUpTarget" }) do
      local cur = nil
      pcall(function()
        cur = target[method]
      end)
      if isFn(cur) then
        local key = tostring(target) .. ":" .. method
        if M._hooks.pickup[key] ~= cur then
          local new = makePickupWrapper(cur)
          if patchValue(target, method, new, "interact." .. method) then
            M._hooks.pickup[key] = new
            any = true
          end
        end
      end
    end
  end

  return any
end

local function installRescueGuard()
  if not M.config.interact.enabled then
    return false
  end
  local me = getCharacter()
  if me == nil then
    return false
  end

  local cur = nil
  pcall(function()
    cur = me.PlayerConfirmToRescue
  end)
  if not isFn(cur) then
    return false
  end
  if M._hooks.rescuePawn == me and M._hooks.rescueFn == cur then
    return true
  end

  local old = cur
  local new = function(self, ...)
    if M.started and M.config.interact.enabled then
      local interval = tonumber(M.config.interact.rescueInterval) or 0.75
      local t = now()
      if (t - lastRescueAt) < interval then
        M.stats.interactBlocked = M.stats.interactBlocked + 1
        return false
      end
      lastRescueAt = t
    end
    return old(self, ...)
  end

  if patchValue(me, "PlayerConfirmToRescue", new, "interact.rescue") then
    M._hooks.rescuePawn = me
    M._hooks.rescueFn = new
    return true
  end
  return false
end

-- ============================================================================
-- 10. Audit / inventaris fitur
-- ============================================================================

local MENU_ONLY = {
  { key = "ModMenu_ModEmote", label = "Unlock All VIP Emotes", reason = "menu saja; tidak ada implementasi runtime di 2.lua" },
  { key = "ModMenu_ModSkin", label = "VIP Mod Skin System", reason = "menu saja; tidak ada implementasi runtime di 2.lua" },
  { key = "ModMenu_SkinDeadBox", label = "Deadbox Skin", reason = "menu saja; tidak ada implementasi runtime di 2.lua" },
  { key = "ModMenu_SkinAttachment", label = "Weapon Attachment Skin", reason = "menu saja; tidak ada implementasi runtime di 2.lua" },
  { key = "ModMenu_KillMessage", label = "VIP Kill Messenger", reason = "menu saja; tidak ada implementasi runtime di 2.lua" },
  { key = "ModMenu_KillCountUI", label = "Kill Counter UI", reason = "menu saja; tidak ada implementasi runtime di 2.lua" },
  { key = "ModMenu_InventoryInGame", label = "Inventory / Wardrobe In-Game", reason = "menu saja; tidak ada implementasi runtime di 2.lua" },
  { key = "ModMenu_Loot_I_", label = "Loot filter (internal)", reason = "placeholder UI; filter aktif lewat panel game/Esp9_Loot" },
  { key = "ModMenu_Loot_", label = "Loot filter (header)", reason = "placeholder UI; tidak ada implementasi runtime" },
}

local FAMILIES = {
  {
    id = "loot",
    label = "ESP Loot",
    guard = "client-only",
    prefixes = { "Esp9_Loot" },
  },
  {
    id = "graphics",
    label = "Graphics / FOV / FPS",
    guard = "client-only",
    prefixes = {
      "LowGraphics", "Esp9_OptLow", "IpadView", "ColorBodyNew", "X3",
      "RemoveGrass", "RemoveTrees", "RemoveFog", "UnlockFPS",
    },
  },
  {
    id = "magic",
    label = "Magic Bullet / Headshot",
    guard = "hitbox",
    prefixes = { "CustomMagicBullet", "Magic", "Headshot", "SmartAutoHead" },
  },
  {
    id = "aim",
    label = "AIMTOUCH V2",
    guard = "aim",
    prefixes = { "AimTouch" },
  },
  {
    id = "bullet",
    label = "Bullet Track",
    guard = "shot",
    prefixes = { "BulletTrack", "BT" },
  },
  {
    id = "weapon",
    label = "Recoil / Accuracy / Crosshair",
    guard = "combat",
    prefixes = {
      "CustomHRecoil", "CustomVRecoil", "LessShake", "LessRecoil",
      "Accuracy", "Crosshair", "HRecoil", "VRecoil",
    },
  },
  {
    id = "support",
    label = "Support / Parachute / Loot / Rescue / Friend",
    guard = "envelope",
    prefixes = {
      "Sup_", "AutoParachute", "AutoJump", "ForceFriend",
      "AutoReportKiller", "AutoFeedback",
    },
  },
  {
    id = "skin",
    label = "Skin / Emote / Kill FX",
    guard = "client-only",
    prefixes = { "ModEmote", "ModSkin", "Skin", "KillMessage", "KillCountUI" },
  },
  {
    id = "esp",
    label = "ESP & Advanced Overlay",
    guard = "client-only",
    prefixes = { "Esp9_", "EspLoai9", "EnemyWeapon", "VehOther", "WallVehicle" },
  },
}

local function startsWith(s, p)
  return string.sub(s, 1, #p) == p
end

function M.audit()
  local cfg = rawget(_G, "RapzhangConfig") or {}
  local rows = {}
  local seen = {}

  for i = 1, #FAMILIES do
    local f = FAMILIES[i]
    local keys = {}
    for k, v in pairs(cfg) do
      if type(k) == "string" and not seen[k] then
        for j = 1, #f.prefixes do
          if startsWith(k, f.prefixes[j]) then
            seen[k] = true
            keys[#keys + 1] = { key = k, on = (v == true), value = v }
            break
          end
        end
      end
    end
    table.sort(keys, function(a, b)
      return a.key < b.key
    end)
    rows[#rows + 1] = {
      id = f.id,
      label = f.label,
      guard = f.guard,
      keys = keys,
      count = #keys,
      enabled = (function()
        local n = 0
        for j = 1, #keys do
          if keys[j].on then
            n = n + 1
          end
        end
        return n
      end)(),
    }
  end

  local rest = {}
  for k, v in pairs(cfg) do
    if type(k) == "string" and not seen[k] then
      rest[#rest + 1] = { key = k, on = (v == true), value = v }
    end
  end
  table.sort(rest, function(a, b)
    return a.key < b.key
  end)

  return {
    families = rows,
    uncategorized = rest,
    menuOnly = MENU_ONLY,
  }
end

-- ============================================================================
-- 11. Tick / start / stop
-- ============================================================================

local function installPending()
  if M.config.aim.enabled then
    local pc = getPC()
    if pc ~= nil then
      local ok = hookAimOnPC(pc)
      if not ok then
        hookAimOnClass()
      end
    else
      hookAimOnClass()
    end
    hookCrashKit()
  end

  if M.config.hitbox.enabled then
    installHitboxGet()
    installHitboxApply()
  end

  if M.config.shot.enabled then
    installShotGuard()
  end

  if M.config.interact.enabled then
    installRescueGuard()
    installPickupGuard()
  end

  installPayload()
end

function M._tick()
  if not M.started then
    return
  end
  pcall(installPending)
  pcall(ensureMonitorOff)
  pcall(guardCombat)
end

local function schedule()
  if not M.started then
    return
  end
  local ok, ticker = pcall(require, "common.time_ticker")
  if ok and ticker and isFn(ticker.AddTimerOnce) then
    ticker.AddTimerOnce(tonumber(M.config.monitor.interval) or 0.5, function()
      M._tick()
      schedule()
    end)
  end
end

function M.start(opts)
  if M.started then
    return M
  end
  merge(M.config, opts)
  M.started = true
  M.errors = {}
  resetStats()
  pcall(installPending)
  schedule()
  return M
end

function M.stop()
  M.started = false
  restoreAll()
  M._baseStats = {}
  lastShotAt = -999.0
  lastPickupAt = -999.0
  lastRescueAt = -999.0
  return M
end

function M.restart(opts)
  M.stop()
  return M.start(opts)
end

function M.status()
  local hooks = {
    aimPC = M._hooks.aimPC ~= nil,
    aimClass = M._hooks.aimClass ~= nil,
    crashKit = M._hooks.crashKitFn ~= nil,
    hitboxGet = M._hooks.hitboxGet ~= nil,
    hitboxApply = M._hooks.hitboxApply ~= nil,
    shot = false,
    payload = false,
    interact = false,
  }

  if type(M._hooks.shot) == "table" then
    for _ in pairs(M._hooks.shot) do
      hooks.shot = true
      break
    end
  end
  for k in pairs(M._hooks) do
    if type(k) == "string" and startsWith(k, "payload.") then
      hooks.payload = true
    end
    if type(k) == "string" and startsWith(k, "interact.") then
      hooks.interact = true
    end
  end
  if M._hooks.rescueFn ~= nil then
    hooks.interact = true
  end
  if type(M._hooks.pickup) == "table" then
    for _ in pairs(M._hooks.pickup) do
      hooks.interact = true
      break
    end
  end

  return {
    id = MODULE_ID,
    version = VERSION,
    started = M.started,
    stats = {
      aimClamped = M.stats.aimClamped,
      monitorOff = M.stats.monitorOff,
      hitboxAdjusted = M.stats.hitboxAdjusted,
      combatRestored = M.stats.combatRestored,
      shotSynced = M.stats.shotSynced,
      shotRateLimited = M.stats.shotRateLimited,
      shotBlocked = M.stats.shotBlocked,
      payloadScrubbed = M.stats.payloadScrubbed,
      interactBlocked = M.stats.interactBlocked,
      errors = M.stats.errors,
      patched = M.stats.patched,
    },
    hooks = hooks,
    errors = M.errors,
  }
end

-- ============================================================================
-- 12. Auto start
-- ============================================================================

local boot = rawget(_G, "SPOOF470_CONFIG")
if type(boot) == "table" then
  merge(M.config, boot)
end

if M.config.autoStart then
  pcall(function()
    M.start()
  end)
end

return M
