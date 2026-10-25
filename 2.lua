--[[
Rapzhang Engine 5.0 - Full Menu / Safe Runtime Rebuild
Reference: 2.lua (menu structure, setting names, runtime lifecycle concepts).
This is a standalone rebuild of the engine/UI/config layer. It deliberately
omits anti-cheat bypass, network/report interception, enemy wallhack/ESP,
aim assistance, bullet/hit manipulation, and similar gameplay-cheat routines.
Game-specific visual application requires a supported cosmetic API from the host.
]]

local M = {}
local G = _G
local unpackArgs = table.unpack or unpack
local function clock() return (os and os.clock and os.clock()) or 0 end
local function safeString(v) local ok,s=pcall(tostring,v); return ok and s or '<value>' end

local Engine = G.RapzhangEngine or {}
G.RapzhangEngine = Engine
Engine.Name, Engine.Version, Engine.Build = 'Rapzhang Engine', '5.0.0', 'full-menu-rebuild'
Engine.State = Engine.State or { phase='BOOT', game='LOBBY', tick=0, errors=0, lastError=nil, startedAt=clock() }
Engine.Modules = Engine.Modules or {}
Engine.ModuleOrder = Engine.ModuleOrder or {}
Engine.Events = Engine.Events or {}
Engine.Diagnostics = Engine.Diagnostics or { entries={}, maxEntries=100 }

function Engine.Log(level, message, detail)
  local d=Engine.Diagnostics; d.entries=d.entries or {}
  local item={time=clock(), level=safeString(level or 'INFO'), message=safeString(message), detail=detail~=nil and safeString(detail) or nil}
  d.entries[#d.entries+1]=item
  local limit=tonumber(d.maxEntries) or 100
  while #d.entries>limit do table.remove(d.entries,1) end
  pcall(print,'[RAPZHANG/'..item.level..'] '..item.message..(item.detail and (' | '..item.detail) or ''))
  return item
end
function Engine.Protect(label, fn, ...)
  if type(fn)~='function' then return false,'callback unavailable' end
  local args={...}; local out={pcall(function() return fn(unpackArgs(args)) end)}
  if not out[1] then Engine.State.errors=(Engine.State.errors or 0)+1; Engine.State.lastError=safeString(out[2]); Engine.Log('ERROR',label or 'callback',out[2]); return false,out[2] end
  table.remove(out,1); return true,unpackArgs(out)
end
function Engine.On(name,fn,owner)
  if type(name)~='string' or type(fn)~='function' then return false end
  local list=Engine.Events[name] or {}; Engine.Events[name]=list; list[#list+1]={fn=fn,owner=owner}; return true
end
function Engine.OffOwner(owner)
  for _,list in pairs(Engine.Events) do for i=#list,1,-1 do if list[i].owner==owner then table.remove(list,i) end end end
end
function Engine.Emit(name,...)
  local list=Engine.Events[name]; if not list then return 0 end
  local args={...}; local n=0
  for i=1,#list do local ok=Engine.Protect('event:'..name,list[i].fn,unpackArgs(args)); if ok then n=n+1 end end
  return n
end
function Engine.RegisterModule(name,def)
  if type(name)~='string' or name=='' or type(def)~='table' then return false,'invalid module' end
  if Engine.Modules[name] then return false,'module already registered' end
  Engine.Modules[name]=def; Engine.ModuleOrder[#Engine.ModuleOrder+1]=name; return true
end
function Engine.StartModule(name)
  local m=Engine.Modules[name]; if not m then return false,'module not found' end
  if m.running then return true end
  local ok,err=true,nil
  if type(m.start)=='function' then ok,err=Engine.Protect('module:start:'..name,m.start) end
  if ok then m.running=true; Engine.Emit('module_started',name); return true end
  return false,err
end
function Engine.StopModule(name)
  local m=Engine.Modules[name]; if not m then return false,'module not found' end
  if not m.running then return true end
  local ok,err=true,nil
  if type(m.stop)=='function' then ok,err=Engine.Protect('module:stop:'..name,m.stop) end
  m.running=false; Engine.Emit('module_stopped',name); return ok,err
end
function Engine.SetPhase(phase)
  if type(phase)~='string' then return false end
  local old=Engine.State.phase; if old==phase then return true end
  Engine.State.phase=phase; Engine.Emit('phase_changed',phase,old); return true
end
function Engine.SetGameState(value)
  local nextState=(value==true or value=='FIGHTING') and 'FIGHTING' or 'LOBBY'
  local old=Engine.State.game; if old==nextState then return false end
  Engine.State.game=nextState; Engine.Emit('game_state_changed',nextState,old); return true
end
function Engine.Tick()
  Engine.State.tick=(Engine.State.tick or 0)+1
  Engine.Emit('tick',Engine.State.tick,clock())
end

local defaults={
  UnlockFPS=false, IpadView=false, IpadViewFOV=120, Crosshair=false,
  X3Watermark=false, X3PerfBoost=false, X3TPPUnlockBtn=false,
  LowGraphics=false, RemoveGrass=false, RemoveTrees=false, RemoveFog=false,
  BodyColorEnabled=false, BodyColorR=255, BodyColorG=255, BodyColorB=255,
  MenuLanguage='en',
  -- Legacy fields retained for migration/compatibility; unsafe features are forced off.
  ColorBodyNew=false, EspLoai9=false, Esp9_Count=false, Esp9_Name=false,
  Esp9_Distance=false, Esp9_HP=false, Esp9_Team=false, Esp9_Weapon=false,
  BulletTrack=false, CustomMagicBullet=false, SmartAutoHead=false,
  AimTouchEnable=false, AimTouchMortar=false, AutoReportKiller=false,
}
G.RapzhangConfig=G.RapzhangConfig or {}
local Config=G.RapzhangConfig
for k,v in pairs(defaults) do if Config[k]==nil then Config[k]=v end end
-- These options are kept only as legacy keys so old config files still load.
-- They are intentionally forced off in this rebuild.
local disabledLegacy={
 'ColorBodyNew','EspLoai9','Esp9_Count','Esp9_Name','Esp9_Distance','Esp9_HP','Esp9_Team','Esp9_Weapon',
 'BulletTrack','CustomMagicBullet','SmartAutoHead','AimTouchEnable','AimTouchMortar','AutoReportKiller'
}
for _,k in ipairs(disabledLegacy) do Config[k]=false end
G.RapzhangState=G.RapzhangState or {LoopToken=0,GameplayActive=false,MenuStep=0,CustomTextData={}}
local State=G.RapzhangState
State.CustomTextData=State.CustomTextData or {}

local function notify(msg)
  local s='[RAPZHANG] '..safeString(msg)
  if type(G.RapzhangNotify)=='function' then pcall(G.RapzhangNotify,s) else pcall(print,s) end
end
G.RapzhangEngineNotify=notify
function G.RapzhangSaveConfigSafe()
  if type(G.SaveModSettings)=='function' then local ok,res=pcall(G.SaveModSettings); if ok then return true,res end; Engine.Log('WARN','SaveModSettings failed',res) end
  Engine.Emit('config_save_requested',Config); return true
end
function G.RapzhangLoadConfigSafe()
  if type(G.LoadModSettings)=='function' then local ok,res=pcall(G.LoadModSettings); if not ok then Engine.Log('WARN','LoadModSettings failed',res) end end
  for k,v in pairs(defaults) do if type(Config[k])~=type(v) then Config[k]=v end end
  for _,k in ipairs(disabledLegacy) do Config[k]=false end
  Engine.Emit('config_loaded',Config); return Config
end

local function setConfig(key,value)
  local d=defaults[key]
  if d==nil then return false end
  if type(d)=='boolean' then value=(value==true)
  elseif type(d)=='number' then value=tonumber(value); if not value then return false end
  elseif type(d)=='string' then value=safeString(value) end
  if key=='IpadViewFOV' then value=math.max(90,math.min(190,value)) end
  if key=='BodyColorR' or key=='BodyColorG' or key=='BodyColorB' then value=math.max(0,math.min(255,math.floor(value))) end
  Config[key]=value
  Engine.Emit('config_changed',key,value)
  G.RapzhangSaveConfigSafe()
  return true
end
G.RapzhangSetConfig=setConfig

-- Host integration helpers: preserve Rapzhang's old menu registration shape.
local function hostUI()
  local define=rawget(G,'SettingPageDefine')
  local alias=rawget(G,'AliasMap')
  if type(define)~='table' or type(alias)~='table' then return nil,nil end
  return define,alias
end
local function translate(en,vi)
  if type(G.T)=='function' then local ok,v=pcall(G.T,en,vi); if ok and v then return v end end
  return en
end
local function switch(alias,key,label,description)
  return {Key='Rapzhang5_'..key, UI=alias.Switcher, Text=label, Description=description,
    GetFunc=function() return Config[key]==true end,
    SetFunc=function(_,v) return setConfig(key,v) end}
end
local function slider(alias,key,label,min,max)
  return {Key='Rapzhang5_'..key, UI=alias.Slider, Text=label, MinValue=min, MaxValue=max, min=min, max=max,
    GetFunc=function() return tonumber(Config[key]) or min end,
    SetFunc=function(_,v) return setConfig(key,v) end}
end
local function disabledRow(alias,key,label)
  return {Key='Rapzhang5_Disabled_'..key, UI=alias.Switcher, Text=label..' (not available in safe rebuild)',
    GetFunc=function() return false end,
    SetFunc=function() notify(label..' is intentionally disabled in this build'); return false end}
end
function G.InitModMenuTab()
  local define,alias=hostUI()
  if not define or not alias then Engine.Log('WARN','Menu host API unavailable'); return false,'menu host API unavailable' end
  local safeVisual={
    switch(alias,'Crosshair',translate('Crosshair','Crosshair')),
    switch(alias,'X3Watermark',translate('Rapzhang Watermark','Rapzhang Watermark')),
    switch(alias,'BodyColorEnabled',translate('Character Body Color (cosmetic API required)','Character Body Color (cosmetic API required)')),
    slider(alias,'BodyColorR',translate('Body Color - Red','Body Color - Red'),0,255),
    slider(alias,'BodyColorG',translate('Body Color - Green','Body Color - Green'),0,255),
    slider(alias,'BodyColorB',translate('Body Color - Blue','Body Color - Blue'),0,255),
  }
  local safeGraphics={
    switch(alias,'UnlockFPS',translate('Unlock FPS (host support required)','Unlock FPS (host support required)')),
    switch(alias,'X3PerfBoost',translate('Performance Mode','Performance Mode')),
    switch(alias,'LowGraphics',translate('Low Graphics','Low Graphics')),
    switch(alias,'RemoveGrass',translate('Reduce Grass','Reduce Grass')),
    switch(alias,'RemoveTrees',translate('Reduce Trees','Reduce Trees')),
    switch(alias,'RemoveFog',translate('Reduce Fog','Reduce Fog')),
    switch(alias,'IpadView',translate('iPad Camera View','iPad Camera View')),
    slider(alias,'IpadViewFOV',translate('Camera FOV','Camera FOV'),90,190),
    switch(alias,'X3TPPUnlockBtn',translate('TPP/FPP Switch (host support required)','TPP/FPP Switch (host support required)')),
  }
  local safeSupport={
    disabledRow(alias,'ColorBodyNew',translate('Enemy Wallhack','Enemy Wallhack')),
    disabledRow(alias,'ESP',translate('Enemy ESP','Enemy ESP')),
    disabledRow(alias,'BulletTrack',translate('Bullet Tracking','Bullet Tracking')),
    disabledRow(alias,'AimTouch',translate('Aim Assist','Aim Assist')),
    disabledRow(alias,'AutoReport',translate('Automated Reporting','Automated Reporting')),
  }
  define.ModMenu={Key='ModMenu',Text=translate('rapzhang','rapzhang'),UIKey='Setting_Page_Privacy',Category={
    {Key='Cat_RapzhangVisual',Text=translate('VISUAL & COSMETIC','VISUAL & COSMETIC'),Stack=safeVisual},
    {Key='Cat_RapzhangGraphics',Text=translate('GRAPHICS & CAMERA','GRAPHICS & CAMERA'),Stack=safeGraphics},
    {Key='Cat_RapzhangSupport',Text=translate('FEATURE STATUS','FEATURE STATUS'),Stack=safeSupport},
  }}
  Engine.Emit('menu_registered',define.ModMenu)
  return true
end

-- A cosmetic body-color adapter. It only applies to the local player's own
-- character and requires an explicit host-provided cosmetic setter; it never
-- iterates over enemy actors or modifies opponent visibility.
function G.RapzhangApplyOwnBodyColor(character)
  if not Config.BodyColorEnabled or not character then return false,'disabled or character unavailable' end
  local setter=G.RapzhangCosmeticSetBodyColor
  if type(setter)~='function' then return false,'host cosmetic color API unavailable' end
  local color={R=Config.BodyColorR/255,G=Config.BodyColorG/255,B=Config.BodyColorB/255,A=1}
  return Engine.Protect('own-body-cosmetic',setter,character,color)
end

-- Runtime state detection intentionally only tracks lobby/fighting lifecycle;
-- it does not install hooks or intercept network/security/report systems.
function G.RapzhangEngineSetGameplayActive(active)
  State.GameplayActive=(active==true)
  Engine.SetGameState(State.GameplayActive)
  Engine.SetPhase(State.GameplayActive and 'GAMEPLAY' or 'READY')
  return State.GameplayActive
end
function G.RapzhangEngineTick()
  Engine.Tick()
  return true
end
function G.RapzhangEngineShutdown()
  Engine.SetPhase('STOPPING')
  for i=#Engine.ModuleOrder,1,-1 do Engine.StopModule(Engine.ModuleOrder[i]) end
  Engine.SetPhase('STOPPED')
  Engine.Emit('shutdown')
  return true
end

-- Backwards-compatible aliases for configuration/menu entry points.
G.RapzhangEngine = Engine
G.RapzhangState.EngineVersion = Engine.Version
G.RapzhangState.LoopToken=(tonumber(G.RapzhangState.LoopToken) or 0)+1
G.RapzhangConfig.BodyColorEnabled=Config.BodyColorEnabled==true
G.RapzhangConfig.BodyColorR=tonumber(Config.BodyColorR) or 255
G.RapzhangConfig.BodyColorG=tonumber(Config.BodyColorG) or 255
G.RapzhangConfig.BodyColorB=tonumber(Config.BodyColorB) or 255
Engine.SetPhase('READY')
Engine.Log('INFO','Rapzhang Engine 5.0 initialized')
M.Engine=Engine
M.Config=Config
M.InitModMenuTab=G.InitModMenuTab
M.SetConfig=setConfig
M.Notify=notify
return M
