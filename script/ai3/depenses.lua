--[[
  Lot DEPENSES2 (4/11) : runtime de shared/ai3/depenses.lua. Appelé par la capitalisation (script/ai3/capitalisation.lua, decide) une fois
  par cycle et par équipe (factions et votre équipe). État : f.team.depenses (nombres et tables ; créé au premier appel, rien à migrer).
  Interface (le budget est À CE LOT ; le périmètre le CONSOMME) :
    - f.team.depenses.defense_want = { [matière] = quantité } : demande de défense, écrite par le périmètre ;
    - Dep.defense(f, tick) -> accord, info : accord = { [matière] = accordé − déjà débité } (table vide : rien ne dort, règle éteinte ou
      résultat périmé) ; info = { etat = "actif" | "eteint" | "perime", tick = tick de l'accord } (PERIMETRE2 : repli si etat ≠ "actif") ;
    - Dep.debit(f, "defense", matière, quantité) -> quantité débitée de l'accord courant (au plus son reste) ; le compte repart de zéro à
      chaque nouvel accord (Dep.think) ; ce qui est débité sort aussi de la réserve (Dep.reserved) ;
    - Dep.labs_target(f, now, cap, tick) -> cible ABSOLUE de laboratoires ou nil (script/ai3/cerveau.lua) ;
    - Dep.soldiers_target(f, army, max, now, tick, key, key_short) -> cible d'armée relevée (script/ai3/cerveau.lua ; factions, et votre
      équipe depuis le lot DEPENSES2 b : cible de base 0, plafond des factions, unités fo-player-*) ;
    - Dep.capi_reserve(f, rin, tick) -> l'entrée « stock hors besoin » de la capitalisation, DÉBITÉE de ce que cette règle a accordé ou
      engagé (défense, laboratoires et soldats encore à faire : revue D2, pas de double dépense).
  Interrupteur : f.team.depenses.on = false. Journal : [FO-DEPENSES] <équipe> minute <m> | <cause>.
]]

local Dp = require("shared.ai3.depenses")
local Rsv = require("script.ai3.reserve")
local Stock = require("script.team.stock") -- (journal Dep.on_trained)

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
  d.spent = {} -- (nouvel accord : il est calculé sur le stock libre, qui a déjà perdu ce que la défense a posé)
  -- Rien ne dort pour la recherche : base oubliée. Centre en attente : base et cible GARDÉES (pas un nouveau sommeil qui repartirait de
  -- plus haut), mais aucun laboratoire demandé ni débité tant qu'il attend (Dep.labs_target, Dp.reserved).
  if res.labs <= 0 and not res.hold then d.lab_base, d.lab_target = nil, nil end
  -- (essai 4 : le centre en attente ne retient plus les soldats ; Dep.soldiers_target les sert comme hors attente)
  if d.on ~= false then
    local sold
    -- (lot DEPENSES2 b : votre équipe aussi)
    if d.soldier_target then sold = string.format("soldats cible %d (cerveau %d, presents %d)", d.soldier_target, d.soldier_brain or 0, d.soldier_now or 0)
    elseif d.soldier_note then sold = "soldats : rien de plus (" .. d.soldier_note .. ")"
    else sold = "soldats : rien de plus" end
    log(string.format("[FO-DEPENSES] %s minute %d | %s | laboratoires base %s cible %s | %s", f.key or "?",
      math.floor((minutes or 0) + 0.5), res.why, tostring(d.lab_base or "-"), tostring(d.lab_target or "-"), sold))
  end
  return res
end

--- Matières qui DORMENT selon le dernier relevé frais : { [matière] = true } (vide : règle éteinte, rien ne dort ou relevé périmé). Lu par
--- la capitalisation (siège du complément, shared/ai3/emplacements.lua, règle 7).
function Dep.sleeping(f, tick)
  local r = fresh(f, tick)
  local out = {}
  if r then for _, k in ipairs(sorted_keys(r.per)) do if (r.per[k] or 0) > 0 then out[k] = true end end end
  return out
end

--- Accordé à la défense et pas encore débité, par matière (copie : le lecteur ne peut pas écrire l'état), et l'état de l'accord :
--- "eteint" (interrupteur), "perime" (aucun accord, ou plus vieux que Dep.FRESH), "actif" (même centre en attente : la défense reste servie).
function Dep.defense(f, tick)
  local d = f and f.team and f.team.depenses
  local r = fresh(f, tick)
  local etat = (type(d) == "table" and d.on == false) and "eteint" or (r and "actif" or "perime")
  local info = { etat = etat, tick = type(d) == "table" and d.res_tick or nil }
  return r and Dp.defense_left(r, d.spent) or {}, info
end

--- Dépense de défense (kind = "defense") sur l'accord courant : rend la quantité débitée (au plus le reste de l'accord ; 0 si éteint,
--- sans accord ou autre kind).
function Dep.debit(f, kind, item, qty)
  local d = f and f.team and f.team.depenses
  if kind ~= "defense" or type(d) ~= "table" or d.on == false or type(d.res) ~= "table" then return 0 end
  if type(d.spent) ~= "table" then d.spent = {} end
  return Dp.debit(d.res, d.spent, item, qty)
end

--- Cible ABSOLUE de laboratoires (revue D1) : now = laboratoires présents, cap = plafond total. nil : rien ne dort.
function Dep.labs_target(f, now, cap, tick, fed)
  local r = fresh(f, tick)
  local d = f and f.team and f.team.depenses
  if not (r and d) or r.hold then return nil end
  d.lab_base = Dp.rebase(d.lab_base, now, d.lab_target, r.labs, fed) -- sprint s41 : cible atteinte, plaques qui dorment encore, laboratoires nourris
  local target, base = Dp.labs_target(d.lab_base, now, r.labs, cap, d.lab_target)
  d.lab_base, d.lab_target, d.lab_now = base, target, now
  return target
end

--- Cible d'armée relevée (revue D3, E4) ; army = cible du cerveau, max = plafond de soldats, now = soldats présents (débit), key = matière
--- clé (seule à payer des soldats), key_short = elle manque (rien de plus : la garde de Br.army et de la prévision).
--- cost (relecture, point 2) = { [matière] = quantité } : coût d'UN soldat de l'unité que l'équipe recrute (T.kits au livre de recettes,
--- script/ai3/cerveau.lua) ; débité par Dep.reserved. Rien de plus (plafond déjà atteint, ou 0 sans guerre pour votre équipe) : aucune
--- cible gardée, aucun débit, journal « rien de plus (plafond 0) » (relecture, point 3).
function Dep.soldiers_target(f, army, max, now, tick, key, key_short, cost)
  local r = fresh(f, tick)
  local d = f and f.team and f.team.depenses
  if d then d.army_base, d.army_key, d.army_key_short = army, key, key_short and true or nil end -- (journal Dep.on_trained)
  local extra = r and Dp.soldiers_extra(r, key, key_short) or 0
  if not d or extra <= 0 then
    if d then d.soldier_target, d.soldier_note = nil, nil end
    return army
  end
  local t = Dp.soldiers(army, extra, max)
  if t <= math.max(0, math.floor(tonumber(army) or 0)) then
    d.soldier_target = nil
    d.soldier_note = math.floor(tonumber(max) or 0) <= 0 and "plafond 0" or "plafond atteint"
    return army
  end
  local c = {}
  for _, k in ipairs(sorted_keys(cost or {})) do
    local v = tonumber(cost[k]) or 0
    if v > 0 then c[k] = v end
  end
  d.soldier_target, d.soldier_brain, d.soldier_now, d.soldier_key, d.soldier_note = t, army, now, key, nil
  d.soldier_cost = next(c) ~= nil and c or nil
  return t
end

--- Lot DEPENSES2 (R1, demande du lead) : journal des soldats de VOTRE ÉQUIPE quand ils sont payés (script/team/team.lua, après
--- Military.train) : combien, quelle unité, sa cible (base des factions + stock qui dort), son fer au coffre et si sa matière clé manque
--- (jamais vrai ici : la base et le relèvement sont à 0 quand elle manque, script/ai3/cerveau.lua).
function Dep.on_trained(f, unit, made, tick)
  if not (f and f.is_player and (made or 0) > 0) then return end
  local d = (f.team and f.team.depenses) or {}
  local key = d.army_key or "?"
  local have = d.army_key and Stock.count(f, d.army_key) or -1
  log(string.format("[FO-DEPENSES] %s : %d soldat(s) %s paye(s) a %.1f min | soldats %d, cible %d (base %d + stock qui dort %d) | %s au coffre %d, matiere cle qui manque : %s",
    f.key or "?", made, tostring(unit), (tick - (f.started or 0)) / 3600, f.soldiers_count or 0, d.soldier_target or d.army_base or 0,
    d.army_base or 0, math.max(0, (d.soldier_target or 0) - (d.army_base or 0)), key, have, d.army_key_short and "OUI" or "non"))
end

--- Ce que cette règle a accordé ou engagé, par matière : défense accordée + laboratoires et soldats encore à faire (répartis sur les
--- matières de la recherche au prorata de leur part).
function Dep.reserved(f, tick)
  local r = fresh(f, tick)
  local d = f and f.team and f.team.depenses
  if not (r and d) then return {} end
  return Dp.reserved(r, d.lab_target, d.lab_now, d.soldier_target, d.soldier_brain, d.soldier_now, d.soldier_key, d.spent, d.soldier_cost)
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
