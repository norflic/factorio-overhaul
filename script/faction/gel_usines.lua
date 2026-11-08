--[[
  Lot X10-GEL, branchement USINES, palier A (fo-logs/2026-11-07_X10/L1_CRITERES.md §3.1 à §3.11) : les avant-postes thermiques
  (foreuse à combustible -> coffre, ou -> four) et les fours du QG remplis à la main des FACTIONS sont figés (`active = false`) hors de
  vue ; leur production est comptée (shared/faction/gel_compta.lua) aux frontières : gisement débité, combustible brûlé, coffre ou
  sortie du four remplis, source du four du QG vidée, statistiques de la force (on_flow), products_finished, pollution.

  Garde FERMÉE (palier A) : un îlot n'est accepté que sans bras (aucun bras ne prend ni ne dépose dans le four), sans tapis, sans
  machine électrique, sur un minerai solide fini d'une seule sorte, avec une recette de fonte connue. Sinon : refusé (raison au
  journal), jamais figé. Votre équipe : jamais (Gel.input rend « votre equipe »).

  Chaîne : découverte (tranches, Gu.SCAN_PER_TICK candidats par tick, toutes les Gu.RESCAN ticks par faction) -> poste de la règle
  commune -> guet (Gel.GUET ticks : shared/faction/gel.lua, decide_all) -> gel (écritures bornées par Gel.spend) -> pas comptable
  toutes les Gu.STEP ticks (créneau = id modulo Gu.STEP) -> réveil (pas dû au tick du réveil, payé dans les ticks suivants ; remise à
  zéro des fractions) ; un bâtiment posé, retiré ou mort près d'un îlot le marque « à relire » (réveillé et retiré au guet suivant).
  Jamais d'écriture de crafting_progress, mining_progress ou bonus_progress (F83, F84).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local State = require("script.faction.state")
local Profiler = require("script.core.profiler")
local G = require("shared.faction.gel")
local Gc = require("shared.faction.gel_compta")
local Gel = require("script.faction.gel")

local Gu = {}

Gu.STEP = 1200          -- ticks entre deux pas comptables d'un îlot figé
Gu.RESCAN = 3600        -- ticks entre deux relevés des candidats d'une faction
Gu.SCAN_PER_TICK = 1    -- candidats relevés au plus par tick, toutes factions (une découverte : 30 à 60 appels de l'API)
Gu.OWED_PER_TICK = 4    -- pas dus (réveil) payés au plus par tick
Gu.NEAR = 3             -- tuiles autour d'un îlot : un bâtiment posé ou retiré ici le marque « à relire »
Gu.PALIER = "A"         -- palier B (bus, bras, électrique) : refusé tant qu'il n'est pas prouvé
Gu.ON = true            -- faux : branchement éteint (bancs témoins)

local function U()
  local g = Gel.state()
  if not g then return nil end -- namespace pas encore créé (on_init d'un mod ajouté à une sauvegarde passe avant on_configuration_changed)
  if not g.u then
    g.u = { ilots = {}, by_unit = {}, cells = {}, slots = {}, owed = {}, pend = {}, next_id = 0, scan = {}, ids_f = {}, fbox = {}, stats = {}, bancs = {} }
  end
  return g.u
end

---------------------------------------------------------------------------------------------------
-- Données des prototypes (tables LOCALES, relues après un chargement ; mêmes valeurs sur tous les clients)
---------------------------------------------------------------------------------------------------
-- Caches dans les CHAMPS d'une table de module (F403 : jamais une table neuve affectée à un local de module dans une fonction).
local CACHE = { book = nil, fuels = nil }

local function products_of(list)
  local out = {}
  for _, p in ipairs(list or {}) do
    if p.type == "fluid" then return nil end
    local a = p.amount or (((p.amount_min or 0) + (p.amount_max or 0)) / 2)
    out[#out + 1] = { p.name, a * (p.probability or 1) }
  end
  return #out > 0 and out or nil
end

--- Recettes de fonte par ingrédient (une seule entrée solide), noms triés : la première gagne.
local function book()
  if CACHE.book then return CACHE.book end
  CACHE.book = {}
  local names = {}
  for name, r in pairs(game.recipe_prototypes) do if r.category == "smelting" then names[#names + 1] = name end end
  table.sort(names)
  for _, name in ipairs(names) do
    local r = game.recipe_prototypes[name]
    local ing = r.ingredients
    local out = products_of(r.products)
    if #ing == 1 and ing[1].type == "item" and out and not CACHE.book[ing[1].name] then
      CACHE.book[ing[1].name] = { ing = { { ing[1].name, ing[1].amount } }, out = out, time = r.energy }
    end
  end
  return CACHE.book
end

--- Combustibles chimiques sans résidu : { [nom] = J }.
local function fuels()
  if CACHE.fuels then return CACHE.fuels end
  CACHE.fuels = {}
  local names = {}
  for name, it in pairs(game.item_prototypes) do
    if (it.fuel_value or 0) > 0 and it.fuel_category == "chemical" and not it.burnt_result then names[#names + 1] = name end
  end
  table.sort(names)
  for _, n in ipairs(names) do CACHE.fuels[n] = game.item_prototypes[n].fuel_value end
  return CACHE.fuels
end

---------------------------------------------------------------------------------------------------
-- Découverte d'un îlot (lecture seule du monde)
---------------------------------------------------------------------------------------------------
local function burner_info(e)
  local p = e.prototype
  local bp = p.burner_prototype
  if not (e.burner and bp) then return nil end
  local power = (p.energy_usage or 0) * (1 + (e.consumption_bonus or 0))
  return { power = power, eff = bp.effectivity or 1, emis = (bp.emissions or 0) * (1 + (e.pollution_bonus or 0)) }
end

local function fuel_table(e)
  local fv, all = {}, fuels()
  fv.coal = all.coal
  local inv = e.burner and e.burner.inventory
  for _, n in ipairs(Gc.sorted_names(inv and inv.get_contents() or {})) do
    if all[n] then fv[n] = all[n] else return nil end -- combustible inconnu (résidu) : îlot refusé
  end
  local cb = e.burner and e.burner.currently_burning
  if cb and not all[cb.name] then return nil end
  return fv
end

local function sorted_by_unit(list)
  table.sort(list, function(a, b) return a.unit_number < b.unit_number end)
  return list
end

--- Gisements solides finis sous une foreuse, triés par position ; nil et la raison sinon.
local function resources_of(surface, d)
  local r = d.prototype.mining_drill_radius or 0.99
  local p = d.position
  local list = surface.find_entities_filtered({ area = { { p.x - r, p.y - r }, { p.x + r, p.y + r } }, type = "resource" })
  table.sort(list, function(a, b)
    if a.position.x ~= b.position.x then return a.position.x < b.position.x end
    return a.position.y < b.position.y
  end)
  local out, prod, mt = {}, nil, nil
  for _, res in ipairs(list) do
    local mp = res.prototype.mineable_properties
    if res.prototype.infinite_resource or mp.required_fluid then return nil, "minerai a fluide" end
    local pr = products_of(mp.products)
    if not pr then return nil, "minerai a fluide" end
    local key = pr[1][1]
    if prod and prod[1][1] ~= key then return nil, "melange" end
    prod, mt = pr, mp.mining_time
    if (res.amount or 0) > 0 then out[#out + 1] = res end
  end
  if #out == 0 then return nil, "gisement vide" end
  return out, nil, prod, mt
end

-- Entités qui peuvent RECEVOIR le dépôt d'une foreuse (seuls coffre et four sont pris ; tout autre receveur rend le refus « bus »).
local RECEIVERS = { "container", "logistic-container", "linked-container", "infinity-container", "furnace", "assembling-machine",
  "transport-belt", "underground-belt", "splitter", "loader", "loader-1x1", "linked-belt", "boiler", "burner-generator", "reactor",
  "mining-drill", "car", "cargo-wagon", "ammo-turret", "artillery-turret", "lab", "rocket-silo" }

--- Cible du dépôt d'une foreuse. `drop_target` reste nil tant que la foreuse n'a rien déposé (fait du micro-banc A du 8/11 : nil au
--- tick 10 sur 24 foreuses posées par script, alors que le moteur y dépose ensuite) : sinon, l'entité receveuse qui touche la TUILE
--- sous `drop_position` (doc de LuaEntity.drop_target : « collide with the tile box under the drop-off position » ; une recherche au
--- point exact ne trouve pas le coffre, micro-banc A de 13dc9822). Tuile rognée de 0,01 : une entité qui ne fait que toucher son bord
--- n'est pas prise (F96). Plus petit numéro d'unité. Une foreuse figée ne relit jamais sa cible : même règle au relevé et au pas.
local function target_of(d)
  local t = d.drop_target
  if t and t.valid then return t end
  local dp = d.drop_position
  local fx, fy = math.floor(dp.x), math.floor(dp.y)
  local list = d.surface.find_entities_filtered({ area = { { fx + 0.01, fy + 0.01 }, { fx + 0.99, fy + 0.99 } }, type = RECEIVERS })
  local best = nil
  for _, e in ipairs(list) do
    if e.valid and e.unit_number and e.unit_number ~= d.unit_number and (best == nil or e.unit_number < best.unit_number) then best = e end
  end
  return best
end

--- Bras qui touchent une entité (prise ou dépôt), et foreuses qui y déposent : liste triée de foreuses, nombre de bras.
local function neighbours(surface, t, force)
  local bb = t.bounding_box
  local area = { { bb.left_top.x - 3, bb.left_top.y - 3 }, { bb.right_bottom.x + 3, bb.right_bottom.y + 3 } }
  local arms = 0
  for _, a in ipairs(surface.find_entities_filtered({ area = area, type = "inserter" })) do
    local pt, dt = a.pickup_target, a.drop_target
    if (pt and pt == t) or (dt and dt == t) then arms = arms + 1 end
  end
  local feeders = {}
  for _, d in ipairs(surface.find_entities_filtered({ area = area, type = "mining-drill", force = force })) do
    local dt = target_of(d)
    if dt and dt.unit_number == t.unit_number then feeders[#feeders + 1] = d end
  end
  return sorted_by_unit(feeders), arms
end

local function drill_desc(d, res_ids, prod, mt, dst, force)
  local b = burner_info(d)
  local rate = (d.prototype.mining_speed or 0) * (1 + (d.speed_bonus or 0)) / (mt or 1) / 60
  return { id = d.unit_number, kind = "drill", rate = rate, out = prod,
    prod = (d.productivity_bonus or 0) + (game.forces[force].mining_drill_productivity_bonus or 0),
    energy = "burner", power = b.power, eff = b.eff, emis = b.emis, fuel = "f" .. d.unit_number, res = res_ids, src = {}, dst = dst }
end

local function furnace_desc(s, recipe, src, dst)
  local b = burner_info(s)
  local m = { id = s.unit_number, kind = "craft", rate = 1, ing = { { "?", 1 } }, out = { { "?", 1 } }, prod = s.productivity_bonus or 0,
    energy = "burner", power = b.power, eff = b.eff, emis = b.emis, fuel = "f" .. s.unit_number, src = src, dst = dst }
  if recipe then
    m.ing, m.out = recipe.ing, recipe.out
    m.rate = (s.crafting_speed or 1) / (recipe.time * 60)
  end
  return m
end

--- Îlot autour d'une foreuse d'avant-poste : rend I (non enregistré) ou nil et la raison.
local function discover_pair(f, surface, d)
  if not (d.valid and d.unit_number and d.force.name == f.force) then return nil, "invalide" end
  if d.to_be_deconstructed() then return nil, "a demonter" end
  if not burner_info(d) then return nil, "electrique" end
  local t = target_of(d)
  if not t then return nil, "sans cible" end
  local drills, sink_kind = { d }, nil
  if t.type == "container" or t.type == "logistic-container" then
    sink_kind = "coffre"
  elseif t.type == "furnace" then
    local feeders, arms = neighbours(surface, t, f.force)
    if arms > 0 then return nil, "bras" end
    if not burner_info(t) then return nil, "electrique" end
    drills, sink_kind = feeders, "four"
    if #drills == 0 then return nil, "sans cible" end
  else
    return nil, "bus"
  end
  local il = { machines = {}, fv = {} }
  local I = { kind = "paire", machines = {}, units = {}, targets = {}, res = {}, pool_ent = {}, pool_kind = {}, pool_item = {}, fuel_ent = {},
    force = f.force, surface = surface.index }
  local recipe, ore
  for _, dd in ipairs(drills) do
    if not burner_info(dd) or dd.to_be_deconstructed() then return nil, "foreuse" end
    local list, why, prod, mt = resources_of(surface, dd)
    if not list then return nil, why end
    if ore and ore ~= prod[1][1] then return nil, "melange" end
    ore = prod[1][1]
    local fv = fuel_table(dd)
    if not fv then return nil, "combustible" end
    for _, n in ipairs(Gc.sorted_names(fv)) do il.fv[n] = fv[n] end
    local res_ids = {}
    for k, res in ipairs(list) do
      local pid = "r" .. dd.unit_number .. "_" .. k
      res_ids[#res_ids + 1] = pid
      I.res[pid] = res
    end
    local dst
    if sink_kind == "coffre" then
      dst = { { k = "pool", id = "c" .. t.unit_number } }
    else
      dst = { { k = "bus", id = "b" .. t.unit_number } }
    end
    il.machines[#il.machines + 1] = drill_desc(dd, res_ids, prod, mt, dst, f.force)
    I.machines[#I.machines + 1] = dd
    I.targets[dd.unit_number] = t.unit_number
    I.fuel_ent["f" .. dd.unit_number] = dd
  end
  if sink_kind == "coffre" then
    local pid = "c" .. t.unit_number
    I.pool_ent[pid], I.pool_kind[pid], I.pool_item[pid] = t, "coffre", ore
    I.chest = t
  else
    recipe = book()[ore]
    if not recipe then return nil, "recette" end
    local fv = fuel_table(t)
    if not fv then return nil, "combustible" end
    for _, n in ipairs(Gc.sorted_names(fv)) do il.fv[n] = fv[n] end
    local pid = "o" .. t.unit_number
    il.machines[#il.machines + 1] = furnace_desc(t, recipe, { { k = "bus", id = "b" .. t.unit_number } }, { { k = "pool", id = pid } })
    I.machines[#I.machines + 1] = t
    I.pool_ent[pid], I.pool_kind[pid], I.pool_item[pid] = t, "sortie", recipe.out[1][1]
    I.fuel_ent["f" .. t.unit_number] = t
  end
  table.sort(il.machines, function(a, b) return a.id < b.id end)
  sorted_by_unit(I.machines)
  local okc, why = Gc.check(il)
  if not okc then return nil, why end
  I.il = Gc.prepare(il)
  return I
end

--- Îlot d'un four du QG rempli à la main : rend I ou nil et la raison.
local function discover_four(f, surface, s)
  if not (s.valid and s.unit_number and s.force.name == f.force and s.type == "furnace") then return nil, "invalide" end
  if s.to_be_deconstructed() then return nil, "a demonter" end
  if not burner_info(s) then return nil, "electrique" end
  local feeders, arms = neighbours(surface, s, f.force)
  if arms > 0 then return nil, "bras" end
  if #feeders > 0 then return nil, "foreuse" end
  local fv = fuel_table(s)
  if not fv then return nil, "combustible" end
  local u = s.unit_number
  local il = { machines = { furnace_desc(s, nil, { { k = "pool", id = "s" .. u } }, { { k = "pool", id = "o" .. u } }) }, fv = fv }
  local I = { kind = "four", dyn = true, machines = { s }, units = {}, targets = {}, res = {}, pool_ent = { ["s" .. u] = s, ["o" .. u] = s },
    pool_kind = { ["s" .. u] = "source", ["o" .. u] = "sortie" }, pool_item = {}, fuel_ent = { ["f" .. u] = s }, force = f.force, surface = surface.index }
  I.il = Gc.prepare(il)
  return I
end

---------------------------------------------------------------------------------------------------
-- Registre
---------------------------------------------------------------------------------------------------
local function cell_keys(box)
  local out = {}
  for cx = math.floor(box.x0 / 32), math.floor(box.x1 / 32) do
    for cy = math.floor(box.y0 / 32), math.floor(box.y1 / 32) do out[#out + 1] = State.chunk_key(cx, cy) end
  end
  return out
end

local function insert_sorted(list, v)
  local i = #list + 1
  while i > 1 and list[i - 1] > v do i = i - 1 end
  table.insert(list, i, v)
end

local function remove_value(list, v)
  for i = 1, #list do if list[i] == v then table.remove(list, i) return end end
end

local function register(fid, I, tick)
  local u = U()
  u.next_id = u.next_id + 1
  I.id, I.fid = u.next_id, fid
  local pts, x0, y0, x1, y1 = {}, math.huge, math.huge, -math.huge, -math.huge
  local all = {}
  for _, e in ipairs(I.machines) do all[#all + 1] = e end
  if I.chest then all[#all + 1] = I.chest end
  for _, e in ipairs(all) do
    local bb = e.bounding_box
    x0, y0 = math.min(x0, bb.left_top.x), math.min(y0, bb.left_top.y)
    x1, y1 = math.max(x1, bb.right_bottom.x), math.max(y1, bb.right_bottom.y)
  end
  for _, e in ipairs(I.machines) do I.units[#I.units + 1] = e.unit_number; u.by_unit[e.unit_number] = I.id end
  pts[1], pts[2] = { x = x0, y = y0 }, { x = x1, y = y1 }
  I.box = { x0 = x0 - Gu.NEAR, y0 = y0 - Gu.NEAR, x1 = x1 + Gu.NEAR, y1 = y1 + Gu.NEAR }
  I.pos = { x = (x0 + x1) / 2, y = (y0 + y1) / 2 }
  I.pts = pts
  I.boxes = G.boxes(pts)
  I.cells = cell_keys(I.box)
  for _, k in ipairs(I.cells) do
    u.cells[k] = u.cells[k] or {}
    insert_sorted(u.cells[k], I.id)
  end
  I.st, I.acc, I.last, I.born = { frozen = false }, {}, tick, tick
  I.slot = I.id % Gu.STEP
  u.ilots[I.id] = I
  u.ids_f[fid] = u.ids_f[fid] or {}
  insert_sorted(u.ids_f[fid], I.id)
  u.fbox[fid] = nil -- boîte de la faction à refaire
  return I
end

local function unregister(I)
  local u = U()
  for _, un in ipairs(I.units) do if u.by_unit[un] == I.id then u.by_unit[un] = nil end end
  for _, k in ipairs(I.cells or {}) do
    if u.cells[k] then remove_value(u.cells[k], I.id); if #u.cells[k] == 0 then u.cells[k] = nil end end
  end
  if u.slots[I.slot] then remove_value(u.slots[I.slot], I.id) end
  remove_value(u.ids_f[I.fid] or {}, I.id)
  u.ilots[I.id] = nil
  u.fbox[I.fid] = nil
end

local function faction_box(fid)
  local u = U()
  if u.fbox[fid] then return u.fbox[fid] end
  local pts = {}
  for _, id in ipairs(u.ids_f[fid] or {}) do
    local I = u.ilots[id]
    pts[#pts + 1] = I.pts[1]
    pts[#pts + 1] = I.pts[2]
  end
  u.fbox[fid] = G.boxes(pts)
  return u.fbox[fid]
end

Gu.U = U
Gu.target_of = target_of
Gu.book, Gu.fuels = book, fuels
Gu.faction_box = faction_box
Gu.discover_pair, Gu.discover_four, Gu.register, Gu.unregister = discover_pair, discover_four, register, unregister

--- Données changées : caches des prototypes à relire.
function Gu.reset_caches() CACHE.book, CACHE.fuels = nil, nil end

return Gu
