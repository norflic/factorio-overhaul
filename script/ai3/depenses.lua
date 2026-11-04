--[[
  Lot DEPENSES2 (4/11) : runtime de shared/ai3/depenses.lua. Appelé par la capitalisation (script/ai3/capitalisation.lua, decide) une fois
  par cycle et par équipe (factions et votre équipe). État : f.team.depenses (nombres et tables ; créé au premier appel, rien à migrer).
  Interface (le budget est À CE LOT ; le périmètre le CONSOMME) :
    - f.team.depenses.defense_want = { [matière] = quantité } : demande de défense, écrite par le périmètre ;
    - Dep.defense(f, tick) -> { [matière] = quantité accordée } (table vide : rien ne dort, règle éteinte ou résultat périmé) ;
    - Dep.labs_target(f, now, cap, tick) -> cible ABSOLUE de laboratoires ou nil (script/ai3/cerveau.lua) ;
    - Dep.soldiers_target(f, army, max, tick) -> cible d'armée relevée (script/ai3/cerveau.lua, factions) ;
    - Dep.capi_reserve(f, rin, tick) -> l'entrée « stock hors besoin » de la capitalisation, DÉBITÉE de ce que cette règle a accordé ou
      engagé (défense, laboratoires et soldats encore à faire : revue D2, pas de double dépense).
  Interrupteur : f.team.depenses.on = false. Journal : [FO-DEPENSES] <équipe> minute <m> | <cause>.
]]

local Dp = require("shared.ai3.depenses")
local Rsv = require("script.ai3.reserve")

local Dep = {}

Dep.FRESH = 3 * 3600
Dep.LABS_MAX = Dp.LABS_MAX

local function sorted_keys(t)
  local ks = {}
  for k in next, t or {} do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function state_of(f)
  local t = f.team
  if type(t.depenses) ~= "table" then t.depenses = { on = true, st = Dp.new() } end
  if type(t.depenses.st) ~= "table" then t.depenses.st = Dp.new() end
  return t.depenses
end

local function fresh(f, tick)
  local d = f and f.team and f.team.depenses
  if type(d) ~= "table" or d.on == false or type(d.res) ~= "table" or not d.res_tick then return nil end
  if tick and tick - d.res_tick > Dep.FRESH then return nil end
  return d.res
end

--- products = { { key, def_only } } dans l'ordre (plaques des fonderies, puis matières brutes « défense seule »).
function Dep.think(f, cs, tick, products, minutes)
  if not (f and f.team) then return nil end
  local d = state_of(f)
  local rin = Rsv.input(f, tick)
  local flows = (cs and cs.flows) or {}
  local list = {}
  for _, p in ipairs(products or {}) do
    local k = p.key
    list[#list + 1] = { key = k, def_only = p.def_only, made = (flows[k] and flows[k].made) or 0,
      free = (rin and rin.free and rin.free[k]) or 0,
      missing = (rin == nil) or (((rin.missing and rin.missing[k]) or 0) > 0) }
  end
  local res
  d.st, res = Dp.step(d.st, { on = d.on ~= false, tick = tick, products = list,
    want = type(d.defense_want) == "table" and d.defense_want or nil })
  d.res, d.res_tick = res, tick
  if res.labs <= 0 then d.lab_base, d.lab_target = nil, nil end -- rien ne dort pour la recherche : base oubliée (Dp.labs_target)
  if d.on ~= false then
    log(string.format("[FO-DEPENSES] %s minute %d | %s | laboratoires base %s cible %s, soldats cible %s", f.key or "?",
      math.floor((minutes or 0) + 0.5), res.why, tostring(d.lab_base or "-"), tostring(d.lab_target or "-"), tostring(d.soldier_target or "-")))
  end
  return res
end

--- Accordé à la défense, par matière (copie : le lecteur ne peut pas écrire l'état).
function Dep.defense(f, tick)
  local r = fresh(f, tick)
  local out = {}
  if r then for _, k in ipairs(sorted_keys(r.defense)) do out[k] = r.defense[k] end end
  return out
end

--- Cible ABSOLUE de laboratoires (revue D1) : now = laboratoires présents, cap = plafond total. nil : rien ne dort.
function Dep.labs_target(f, now, cap, tick)
  local r = fresh(f, tick)
  local d = f and f.team and f.team.depenses
  if not (r and d) then return nil end
  local target, base = Dp.labs_target(d.lab_base, now, r.labs, cap)
  d.lab_base, d.lab_target, d.lab_now = base, target, now
  return target
end

--- Cible d'armée relevée (revue D3) ; army = cible du cerveau, max = plafond de soldats ; now = soldats présents (débit).
function Dep.soldiers_target(f, army, max, now, tick)
  local r = fresh(f, tick)
  local d = f and f.team and f.team.depenses
  if not (r and d) or (r.soldiers or 0) <= 0 then
    if d then d.soldier_target = nil end
    return army
  end
  local t = Dp.soldiers(army, r.soldiers, max)
  d.soldier_target, d.soldier_now = t, now
  return t
end

--- Ce que cette règle a accordé ou engagé, par matière : défense accordée + laboratoires et soldats encore à faire (répartis sur les
--- matières de la recherche au prorata de leur part).
function Dep.reserved(f, tick)
  local r = fresh(f, tick)
  local d = f and f.team and f.team.depenses
  local out = {}
  if not (r and d) then return out end
  for _, k in ipairs(sorted_keys(r.defense)) do out[k] = (out[k] or 0) + (r.defense[k] or 0) end
  local eng = Dp.engaged(d.lab_target, d.lab_now, Dp.LAB_COST)
  if d.soldier_target and d.soldier_now then eng = eng + Dp.engaged(d.soldier_target, d.soldier_now, Dp.SOLDIER_COST) end
  if eng > 0 and (r.research or 0) > 0 then
    for _, k in ipairs(sorted_keys(r.rper)) do out[k] = (out[k] or 0) + eng * (r.rper[k] or 0) / r.research end
  end
  return out
end

--- Entrée « stock hors besoin » de la capitalisation débitée de Dep.reserved (copie ; rin nil -> nil).
function Dep.capi_reserve(f, rin, tick)
  if rin == nil then return nil end
  local held = Dep.reserved(f, tick)
  if next(held) == nil then return rin end
  local out = {}
  for _, k in ipairs(sorted_keys(rin)) do out[k] = rin[k] end
  local free = {}
  for _, k in ipairs(sorted_keys(rin.free)) do free[k] = math.max(0, (rin.free[k] or 0) - (held[k] or 0)) end
  out.free = free
  return out
end

return Dep
