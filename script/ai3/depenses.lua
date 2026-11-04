--[[
  Lot DEPENSES2 (4/11) : runtime de shared/ai3/depenses.lua. Appelé par la capitalisation (script/ai3/capitalisation.lua, decide) une fois
  par cycle et par équipe (factions et votre équipe). État : f.team.depenses (nombres et tables ; créé au premier appel, rien à migrer).
  Interface (le budget est À CE LOT ; le périmètre le CONSOMME) :
    - f.team.depenses.defense_want = { [matière] = quantité } : demande de défense, écrite par le périmètre ;
    - Dep.defense(f, tick) -> { [matière] = quantité accordée } (table vide : rien ne dort, règle éteinte ou résultat périmé) ;
    - Dep.labs_target(f, now, cap, tick) -> cible ABSOLUE de laboratoires ou nil (script/ai3/cerveau.lua) ;
    - Dep.soldiers_target(f, army, max, now, tick, key, key_short) -> cible d'armée relevée (script/ai3/cerveau.lua, factions : votre
      équipe n'a ni chemin de recrutement ni prototype de soldat, voir RAPPORT.md) ;
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

--- Essai 3 : le centre d'abord. Il attend tant qu'il est le but courant de l'amélioration (script/ai3/capital.lua, c.current.center)
--- ou payable (porte ouverte du report, lot AGES : c.defer.open).
function Dep.centre_waiting(f)
  local c = f and f.team and f.team.capital
  return (c and ((c.current and c.current.center) or (c.defer and c.defer.open))) and true or false
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
  local hold = Dep.centre_waiting(f)
  local res
  d.st, res = Dp.step(d.st, { on = d.on ~= false, tick = tick, products = list, hold = hold,
    want = type(d.defense_want) == "table" and d.defense_want or nil })
  d.res, d.res_tick = res, tick
  -- Rien ne dort pour la recherche : base oubliée. Centre en attente : base et cible GARDÉES (pas un nouveau sommeil qui repartirait de
  -- plus haut), mais aucun laboratoire demandé ni débité tant qu'il attend (Dep.labs_target, Dp.reserved).
  if res.labs <= 0 and not res.hold then d.lab_base, d.lab_target = nil, nil end
  if res.hold then d.soldier_target = nil end
  if d.on ~= false then
    local sold
    if f.is_player then sold = "soldats : votre equipe ne recrute pas"
    elseif d.soldier_target then sold = string.format("soldats cible %d (cerveau %d, presents %d)", d.soldier_target, d.soldier_brain or 0, d.soldier_now or 0)
    else sold = "soldats : rien de plus" end
    log(string.format("[FO-DEPENSES] %s minute %d | %s | laboratoires base %s cible %s | %s", f.key or "?",
      math.floor((minutes or 0) + 0.5), res.why, tostring(d.lab_base or "-"), tostring(d.lab_target or "-"), sold))
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
  if not (r and d) or r.hold then return nil end
  local target, base = Dp.labs_target(d.lab_base, now, r.labs, cap, d.lab_target)
  d.lab_base, d.lab_target, d.lab_now = base, target, now
  return target
end

--- Cible d'armée relevée (revue D3, E4) ; army = cible du cerveau, max = plafond de soldats, now = soldats présents (débit), key = matière
--- clé (seule à payer des soldats), key_short = elle manque (rien de plus : la garde de Br.army et de la prévision).
function Dep.soldiers_target(f, army, max, now, tick, key, key_short)
  local r = fresh(f, tick)
  local d = f and f.team and f.team.depenses
  local extra = r and Dp.soldiers_extra(r, key, key_short) or 0
  if not d or extra <= 0 then
    if d then d.soldier_target = nil end
    return army
  end
  local t = Dp.soldiers(army, extra, max)
  d.soldier_target, d.soldier_brain, d.soldier_now, d.soldier_key = t, army, now, key
  return t
end

--- Ce que cette règle a accordé ou engagé, par matière : défense accordée + laboratoires et soldats encore à faire (répartis sur les
--- matières de la recherche au prorata de leur part).
function Dep.reserved(f, tick)
  local r = fresh(f, tick)
  local d = f and f.team and f.team.depenses
  if not (r and d) then return {} end
  return Dp.reserved(r, d.lab_target, d.lab_now, d.soldier_target, d.soldier_brain, d.soldier_now, d.soldier_key)
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
