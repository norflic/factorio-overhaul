--[[
  Lot X10-GEL, palier A, au MOTEUR SIMULÉ (monde factice écrit ici : entités, inventaires, gisements, brûleurs, statistiques). Ce
  n'est pas une preuve en jeu : le micro-banc `x10-gel-arene` la fait (L1_CRITERES.md §4, C1 à C7). Ici, la chaîne du runtime :
    M1  relevé en tranches : 3 îlots (foreuse -> coffre, foreuse -> four, four du QG ; la foreuse -> coffre SANS drop_target, cible lue
        sur drop_position, comme en moteur réel avant le premier dépôt) ; refus : foreuse électrique, foreuse sur
        tapis, four servi par un bras ;
    M2  joueur loin : figés après Gel.CALM ticks de calme, au guet ; active = false ; Gel.status rend le statut comptable ;
    M3  pas comptables : coffre, sortie du four, source du four du QG, gisement, charbon, statistiques (on_flow), products_finished,
        pollution, à la valeur attendue (0,25 minerai par seconde, 3,2 s par plaque) ;
    M4  joueur à 220 tuiles : réveil au guet suivant (au plus 20 ticks), pas dû payé, statuts comptables effacés ;
    M5  attaque sur la faction : tout réveillé au guet suivant ;
    M6  un bras posé près d'un îlot figé : réveillé, retiré, puis refusé « bras » au relevé suivant ;
    M7  budget d'écritures (Gel.WRITES = 2) : le gel et le réveil s'étalent sur plusieurs ticks ;
    M8  réglage éteint : tout réveillé, plus rien de figé ; données changées : tout réveillé, registre vidé ;
    M9  votre équipe jamais figée ;
    M10 déterminisme : deux passages, mêmes journaux et mêmes inventaires ;
    M11 contrôle statique : aucune écriture de crafting_progress ni bonus_progress ; mining_progress et bonus_mining_progress d'une foreuse
        écrits par le seul write_progress (gel_usines_jeu.lua, option (ii) du lead) ; au monde factice, jamais sur autre chose qu'une foreuse ;
    M14 option (ii) : au réveil, la fraction comptée pendant le gel est rendue à la foreuse par sa progression ;
    M15 four du QG vide refusé « recette » ; four figé dont la source prend un objet sans recette de four : recette gardée, aucun
        nom inconnu lu (inventaires et statistiques du monde factice passent le contrôle du moteur simulé partagé,
        tests/mock_engine.lua M.item_known : « Unknown item name » comme le moteur), rien produit (C19, sauvegarde du DC, 8/11) ;
    M16 portées fines du guet fermées sous leur nom (mesure C19) ;
    M12 remplaçant d'une machine figée (fast_replace, raise_built) hérité inactif : rendu actif dans le gestionnaire ;
    M13 faction anéantie pendant le gel : tout réveillé au guet suivant, n_frozen à 0, registre de la faction vidé ;
    Mutants du runtime (relecture de revue-s, 8/11) : guet limité aux factions vivantes ; remplaçant laissé inactif ; (C19) four du QG
        relevé sans recette, recette fictive « ? » rendue au pas, portée fine non fermée.
  Usage : lua5.2 tests/gel_moteur_test.lua   (depuis la racine du mod ; shared/faction/cadence.lua de x10-s10 requis)
]]
package.path = "./?.lua;" .. package.path
-- Contrôle des noms d'objets du MOTEUR SIMULÉ partagé (Mk.item_known : « Unknown item name » comme le moteur, C19, 8/11) : les
-- inventaires et les statistiques du monde factice le passent, avec les objets de Mk.item_prototypes.
local Mk = require("tests.mock_engine")

local ok_n, fail_n = 0, 0
local quiet = false -- passages des mutants (fin du fichier) : rien n'est imprimé
local function check(c, msg)
  if c then ok_n = ok_n + 1; if os.getenv("FO_VERBOSE") and not quiet then print("[GEL-MOTEUR] OK : " .. msg) end
  else fail_n = fail_n + 1; if not quiet then print("[GEL-MOTEUR] ECHEC : " .. msg) end end
  return c
end

---------------------------------------------------------------------------------------------------
-- Monde factice
---------------------------------------------------------------------------------------------------
local W
local function new_inv(cap)
  local inv = { items = {}, cap = cap or 4800 }
  -- comme le moteur : un nom qui n'est pas un objet lève « Unknown item name » (C19, sauvegarde du DC, 8/11 : « ? »), par le contrôle
  -- du moteur simulé partagé (tests/mock_engine.lua, M.item_known)
  local function known(n) if not Mk.item_known(n) then error("Unknown item name: " .. tostring(n)) end end
  function inv.get_item_count(n) if n == nil then local t = 0 for _, c in pairs(inv.items) do t = t + c end return t end known(n) return inv.items[n] or 0 end
  function inv.get_insertable_count(n)
    known(n)
    local used = 0
    for _, c in pairs(inv.items) do used = used + c end
    return math.max(0, inv.cap - used)
  end
  function inv.insert(s) known(s.name); local q = math.min(s.count, inv.get_insertable_count(s.name)); if q > 0 then inv.items[s.name] = (inv.items[s.name] or 0) + q end return q end
  function inv.remove(s) known(s.name); local q = math.min(s.count, inv.items[s.name] or 0); inv.items[s.name] = (inv.items[s.name] or 0) - q; if inv.items[s.name] == 0 then inv.items[s.name] = nil end return q end
  function inv.get_contents() local o = {} for k, v in pairs(inv.items) do o[k] = v end return o end
  return inv
end

local STATUS = { working = 1, disabled_by_script = 2, no_fuel = 3, no_ingredients = 4, full_output = 5, no_minable_resources = 6,
  waiting_for_space_in_destination = 7, item_ingredient_shortage = 8, no_power = 9, low_power = 10, normal = 11 }

local function entity(o)
  W.un = W.un + 1
  local e = { valid = true, unit_number = W.un, name = o.name, type = o.type, force = { name = o.force or "fo-a" }, position = { x = o.x, y = o.y },
    _active = true, prototype = o.proto or {}, speed_bonus = 0, productivity_bonus = 0, consumption_bonus = 0, pollution_bonus = 0,
    crafting_speed = o.crafting_speed, products_finished = 0, surface = W.surface }
  local h = o.h or 1
  e.bounding_box = { left_top = { x = o.x - h, y = o.y - h }, right_bottom = { x = o.x + h, y = o.y + h } }
  e.to_be_deconstructed = function() return false end
  if o.burner then
    local raw = { inventory = new_inv(50), remaining_burning_fuel = 0, currently_burning = nil }
    raw.inventory.items.coal = o.coal or 5
    e.burner = setmetatable({}, { __index = raw, __newindex = function(_, k, v)
      if k == "currently_burning" and v ~= nil then
        assert(type(v) == "table" and v.name, "currently_burning : un LuaItemPrototype est attendu")
        v = { name = v.name, fuel_value = v.fuel_value }
      end
      raw[k] = v
    end })
  end
  if o.type == "furnace" then e._src, e._out = new_inv(50), new_inv(100) end
  if o.type == "container" then e._inv = new_inv(1600) end
  setmetatable(e, { __index = function(t, k)
    if k == "active" then return rawget(t, "_active") end
    if k == "status" then return rawget(t, "_active") and STATUS.working or STATUS.disabled_by_script end
    if k == "mining_progress" then return rawget(t, "_mp") or 0 end
    if k == "bonus_mining_progress" then return rawget(t, "_bmp") or 0 end
    return nil
  end, __newindex = function(t, k, v)
    if k == "active" then rawset(t, "_active", v); W.writes[W.tick] = (W.writes[W.tick] or 0) + 1; return end
    -- option (ii) : la progression d'une FOREUSE peut être écrite (fait moteur x10-gel-progres) ; jamais celle d'un four (F83, F84)
    if k == "mining_progress" or k == "bonus_mining_progress" then
      if rawget(t, "type") ~= "mining-drill" then W.bad_writes = W.bad_writes + 1 end
      W.mp_writes = W.mp_writes + 1
      rawset(t, k == "mining_progress" and "_mp" or "_bmp", v)
      return
    end
    if k == "crafting_progress" or k == "bonus_progress" then W.bad_writes = W.bad_writes + 1 end
    rawset(t, k, v)
  end, __eq = function(a, b) return rawget(a, "unit_number") == rawget(b, "unit_number") end })
  e.get_inventory = function(i) if i == defines.inventory.chest then return e._inv end if i == defines.inventory.furnace_source then return e._src end end
  e.get_output_inventory = function() return e._out end
  W.ents[#W.ents + 1] = e
  return e
end

local function resource(x, y, amount)
  local r = { valid = true, position = { x = x, y = y }, amount = amount, type = "resource",
    prototype = { infinite_resource = false, mineable_properties = { mining_time = 1, products = { { type = "item", name = "iron-ore", amount = 1 } } } } }
  r.deplete = function() r.valid = false; r.amount = 0 end
  W.res[#W.res + 1] = r
  return r
end

local function in_area(p, a) return p.x >= a[1][1] and p.x <= a[2][1] and p.y >= a[1][2] and p.y <= a[2][2] end
local function type_ok(t, ty)
  if t == nil then return true end
  if type(t) == "string" then return t == ty end
  for _, x in ipairs(t) do if x == ty then return true end end
  return false
end

local DRILL_P = { mining_drill_radius = 0.99, mining_speed = 0.25, energy_usage = 2500, burner_prototype = { effectivity = 1, emissions = 12 / (150000 * 60) } }
local FURN_P = { energy_usage = 1500, burner_prototype = { effectivity = 1, emissions = 2 / (90000 * 60) } }
local ELEC_DRILL_P = { mining_drill_radius = 2.49, mining_speed = 0.5, energy_usage = 1500 }

local function new_world()
  W = { un = 0, ents = {}, res = {}, writes = {}, bad_writes = 0, mp_writes = 0, tick = 0, logs = {}, flows = {}, flows_in = {}, flows_out = {}, pollution = 0, store = {} }
  W.surface = { index = 1 }
  W.surface.find_entities_filtered = function(q)
    local out = {}
    if q.type == "resource" then
      for _, r in ipairs(W.res) do if r.valid and in_area(r.position, q.area) then out[#out + 1] = r end end
      return out
    end
    for _, e in ipairs(W.ents) do
      local hit
      if q.position then
        local bb = e.bounding_box
        hit = q.position.x >= bb.left_top.x and q.position.x <= bb.right_bottom.x and q.position.y >= bb.left_top.y and q.position.y <= bb.right_bottom.y
      else
        hit = in_area(e.position, q.area)
      end
      if e.valid and type_ok(q.type, e.type) and (q.force == nil or q.force == e.force.name) and hit then out[#out + 1] = e end
    end
    return out
  end
  W.surface.pollute = function(_, a) W.pollution = W.pollution + a end
  local recipes = { ["iron-plate"] = { category = "smelting", energy = 3.2, ingredients = { { type = "item", name = "iron-ore", amount = 1 } },
    products = { { type = "item", name = "iron-plate", amount = 1 } } } }
  -- objets du moteur simulé partagé (recettes et objets de base : charbon, minerais, pierre, bois), contrôlés par Mk.item_known ; seul le
  -- charbon est un combustible chimique (comme avant : le bois n'en est pas un ici)
  local protos = Mk.item_prototypes(recipes)
  protos.coal.fuel_value, protos.coal.fuel_category = 4000000, "chemical"
  protos.wood.fuel_value = 0
  local force = { item_production_statistics = { on_flow = function(n, c)
    if not Mk.item_known(n) then error("Unknown item name: " .. tostring(n)) end
    W.flows[n] = (W.flows[n] or 0) + c
    if c > 0 then W.flows_in[n] = (W.flows_in[n] or 0) + c else W.flows_out[n] = (W.flows_out[n] or 0) - c end
  end }, mining_drill_productivity_bonus = 0 }
  game = { tick = 0, connected_players = {}, forces = { ["fo-a"] = force, player = force }, recipe_prototypes = recipes,
    item_prototypes = protos, surfaces = { [1] = W.surface } }
  W.player = { valid = true, surface = W.surface, position = { x = 5000, y = 5000 } }
  game.connected_players = { W.player }
end

defines = { inventory = { chest = 1, furnace_source = 2 }, entity_status = STATUS,
  events = { on_built_entity = 1, on_robot_built_entity = 2, script_raised_built = 3, script_raised_revive = 4, on_player_mined_entity = 5,
    on_robot_mined_entity = 6, script_raised_destroy = 7, on_entity_died = 8 } }
settings = { global = { ["fo-war-gel"] = { value = true } } }
log = function(s) W.logs[#W.logs + 1] = s end

---------------------------------------------------------------------------------------------------
-- Modules réels du lot, sur un bus d'événements et un stockage factices
---------------------------------------------------------------------------------------------------
-- Pile du profileur factice (portées start/stop et fines) ; PROF.bad compte les fermetures hors du sommet ou sans ouverture.
PROF = { stack = {}, bad = 0, seen = {}, cnt = {} }
function prof_open(n)
  PROF.stack[#PROF.stack + 1] = n
  PROF.seen[n] = true
  if n == "gel:guet" or n == "gel:garnisons" then -- ticks de la période qui portent un guet (C19 : guets étalés)
    PROF.at = PROF.at or {}
    PROF.at[n] = PROF.at[n] or {}
    PROF.at[n][game.tick % 20] = true
  end
end
function prof_close(n)
  if PROF.stack[#PROF.stack] == n then PROF.stack[#PROF.stack] = nil else PROF.bad = PROF.bad + 1 end
end
--- Portées du profileur factice depuis le dernier PROF neuf : toutes fermées sous leur nom, au sommet ; portées et compteurs attendus vus
--- (C19, 8/11 : instrumentation fine du guet, sans décision changée).
function prof_check(tag, scopes, counters)
  local miss = {}
  for _, n in ipairs(scopes) do if not PROF.seen[n] then miss[#miss + 1] = n end end
  for _, n in ipairs(counters) do if not ((PROF.cnt[n] or 0) > 0) then miss[#miss + 1] = "#" .. n end end
  return #miss == 0 and PROF.bad == 0 and #PROF.stack == 0, string.format("%s : portees fermees sous leur nom (%d hors du sommet, %d ouverte(s)) ; vues : %s",
    tag, PROF.bad, #PROF.stack, #miss == 0 and "toutes" or ("MANQUENT " .. table.concat(miss, " ")))
end
local H
local MUT_JEU = nil -- source mutée de script/faction/gel_usines_jeu.lua (mutants, fin du fichier)
local MUT_GU = nil -- source mutée de script/faction/gel_usines.lua (mutants, fin du fichier)
local function load_mod()
  H = { on = {}, nth = {}, died = {}, config = {} }
  for _, m in ipairs({ "script.core.events", "script.core.storage", "script.core.profiler", "script.faction.state", "script.faction.gel",
    "script.faction.gel_usines", "script.faction.gel_usines_jeu", "shared.faction.gel", "shared.faction.gel_compta" }) do package.loaded[m] = nil end
  package.loaded["script.core.events"] = {
    on = function(id, fn) H.on[id] = H.on[id] or {}; table.insert(H.on[id], fn) end,
    on_nth_tick = function(n, fn) H.nth[n] = H.nth[n] or {}; table.insert(H.nth[n], fn) end,
    on_died = function(fn) table.insert(H.died, fn) end,
    on_init = function() end, on_load = function() end,
    on_configuration_changed = function(fn) table.insert(H.config, fn) end,
  }
  package.loaded["script.core.storage"] = {
    declare = function(name, init) W.store[name] = W.store[name] or init() end,
    ns = function(name) return W.store[name] end,
    raw = function() return W.store end,
  }
  -- Profileur factice : start/stop et portées FINES (C19, 8/11) sur une pile, pour contrôler qu'elles se ferment sous leur nom, au
  -- sommet ; compteurs (fcount) cumulés. PROF est global au fichier (vidé par le seul passage qui le lit).
  package.loaded["script.core.profiler"] = { start = prof_open, stop = prof_close, fstart = prof_open, fstop = prof_close,
    fcount = function(n, k) PROF.cnt[n] = (PROF.cnt[n] or 0) + (k or 1) end }
  package.loaded["script.faction.commander"] = { army_out = function() return W.army_out == true, nil end }
  local Gel = require("script.faction.gel")
  local Gu
  if MUT_GU then
    Gu = assert(load(MUT_GU, "=script/faction/gel_usines.lua"))()
    package.loaded["script.faction.gel_usines"] = Gu
  else
    Gu = require("script.faction.gel_usines")
  end
  local Gj
  if MUT_JEU then
    Gj = assert(load(MUT_JEU, "=script/faction/gel_usines_jeu.lua"))()
    package.loaded["script.faction.gel_usines_jeu"] = Gj
  else
    Gj = require("script.faction.gel_usines_jeu")
  end
  return Gel, Gu, Gj
end

local function run(n)
  for _ = 1, n do
    W.tick = W.tick + 1
    game.tick = W.tick
    for _, fn in ipairs(H.nth[1] or {}) do fn({ tick = W.tick }) end
    if W.tick % 20 == 0 then for _, fn in ipairs(H.nth[20] or {}) do fn({ tick = W.tick }) end end
  end
end

--- Une faction de banc : avant-poste (foreuse -> coffre, foreuse -> four), four du QG, et trois cas refusés.
local function build_faction()
  local Gel = load_mod()
  -- M18 (C19) : FORCE_TOUS fait décider TOUS les îlots à chaque guet (Gj.TOUS, bancs hors jeu) : la partie doit rester identique
  if FORCE_TOUS then package.loaded["script.faction.gel_usines_jeu"].TOUS = true end
  local S = W.store
  local f = { key = "a", force = "fo-a", hq = { valid = true }, hq_pos = { x = 0, y = 0 }, outposts = {}, smelters = {} }
  S.war.active, S.war.surface, S.war.factions[1], S.war.by_force["fo-a"] = true, 1, f, 1
  -- (1) foreuse -> coffre
  local r1 = resource(10.5, 10.5, 1000)
  local d1 = entity({ name = "burner-mining-drill", type = "mining-drill", x = 10.5, y = 10.5, proto = DRILL_P, burner = true, coal = 5 })
  local c1 = entity({ name = "wooden-chest", type = "container", x = 10.5, y = 12.5, h = 0.35 })
  -- fait du micro-banc A (8/11) : drop_target reste nil tant que la foreuse n'a rien déposé ; la cible est lue sur drop_position
  d1.drop_position = { x = 10.2, y = 12.3 }
  d1.mining_target = r1
  -- (2) foreuse -> four
  local r2 = resource(20.5, 10.5, 1000)
  local d2 = entity({ name = "burner-mining-drill", type = "mining-drill", x = 20.5, y = 10.5, proto = DRILL_P, burner = true, coal = 5 })
  local k2 = entity({ name = "stone-furnace", type = "furnace", x = 20.5, y = 13, proto = FURN_P, burner = true, coal = 5, crafting_speed = 1 })
  d2.drop_target = k2
  d2.mining_target = r2
  -- (3) four du QG rempli à la main
  local s1 = entity({ name = "stone-furnace", type = "furnace", x = -10.5, y = 0.5, proto = FURN_P, burner = true, coal = 5, crafting_speed = 1 })
  s1._src.items["iron-ore"] = 10
  -- refusés : foreuse électrique ; foreuse sur un tapis ; four servi par un bras
  resource(40.5, 10.5, 1000)
  local de = entity({ name = "electric-mining-drill", type = "mining-drill", x = 40.5, y = 10.5, proto = ELEC_DRILL_P })
  de.drop_target = entity({ name = "wooden-chest", type = "container", x = 40.5, y = 13, h = 0.5 })
  resource(60.5, 10.5, 1000)
  local db = entity({ name = "burner-mining-drill", type = "mining-drill", x = 60.5, y = 10.5, proto = DRILL_P, burner = true })
  db.drop_target = entity({ name = "transport-belt", type = "transport-belt", x = 60.5, y = 12, h = 0.5 })
  resource(80.5, 10.5, 1000)
  local dk = entity({ name = "burner-mining-drill", type = "mining-drill", x = 80.5, y = 10.5, proto = DRILL_P, burner = true })
  local kk = entity({ name = "stone-furnace", type = "furnace", x = 80.5, y = 13, proto = FURN_P, burner = true, crafting_speed = 1 })
  dk.drop_target = kk
  local arm = entity({ name = "inserter", type = "inserter", x = 80.5, y = 15, h = 0.2 })
  arm.pickup_target = kk
  f.outposts[1] = { drill_list = { d1, d2, de, db, dk } }
  f.smelters = { s1 }
  return f, { r1 = r1, r2 = r2, d1 = d1, c1 = c1, d2 = d2, k2 = k2, s1 = s1, Gel = Gel }
end

local function frozen_count()
  local n = 0
  for _, e in ipairs(W.ents) do if e.valid and not e.active then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------------------------------
-- Scènes
---------------------------------------------------------------------------------------------------
local function scenes()
  PROF = { stack = {}, bad = 0, seen = {}, cnt = {} }
  new_world()
  local f, E = build_faction()
  local Gel = E.Gel
  local Gu = require("script.faction.gel_usines")
  -- M1
  run(40)
  local u = Gu.U()
  local n = 0
  for _ in pairs(u.ilots) do n = n + 1 end
  check(n == 3, "M1 : 3 ilots releves (" .. n .. ")")
  local refus = u.stats[1] and u.stats[1].refus or {}
  check(refus.electrique == 1 and refus.bus == 1 and refus.bras == 1, "M1 : refus electrique, bus, bras (" .. tostring(refus.electrique) .. ", " ..
    tostring(refus.bus) .. ", " .. tostring(refus.bras) .. ")")
  -- M2
  run(700)
  check(not E.d1.active and not E.d2.active and not E.k2.active and not E.s1.active, "M2 : joueur loin : les 4 machines sont figees")
  check(frozen_count() == 4, "M2 : rien d'autre n'est fige (" .. frozen_count() .. ")")
  run(1300)
  check(Gel.status(E.d1) == STATUS.working and Gel.status(E.s1) == STATUS.working, "M2 : Gel.status rend « working » (comptable), pas disabled_by_script")
  -- M3
  local ore0, coal0 = E.c1._inv.items["iron-ore"] or 0, E.d1.burner.inventory.items.coal or 0
  local plate0, src0 = E.k2._out.items["iron-plate"] or 0, E.s1._src.items["iron-ore"] or 0
  local r10 = E.r1.amount
  run(3600)
  local ore = (E.c1._inv.items["iron-ore"] or 0) - ore0
  check(ore >= 14 and ore <= 16, "M3 : 60 s : 15 minerais au coffre (0,25/s) (" .. ore .. ")")
  check(r10 - E.r1.amount == ore, "M3 : gisement debite d'autant (" .. (r10 - E.r1.amount) .. ")")
  local plates = (E.k2._out.items["iron-plate"] or 0) - plate0
  check(plates >= 14 and plates <= 16, "M3 : 60 s : 15 plaques a la sortie du four (la foreuse limite) (" .. plates .. ")")
  local qg = (E.s1._out.items["iron-plate"] or 0)
  check(qg == 10 and (E.s1._src.items["iron-ore"] or 0) == 0, "M3 : four du QG : 10 minerais fondus en 10 plaques (" .. qg .. ", source " .. src0 .. " -> 0)")
  check((coal0 - (E.d1.burner.inventory.items.coal or 0)) >= 1, "M3 : charbon brule par la foreuse")
  check((W.flows["iron-plate"] or 0) >= plates + qg - 2, "M3 : statistiques : plaques versees par on_flow (" .. tostring(W.flows["iron-plate"]) .. ")")
  check(E.k2.products_finished >= plates and E.s1.products_finished == 10, "M3 : products_finished incremente")
  -- statistiques de minerai : la foreuse -> four produit ET son four consomme dans le même pas : rien ne s'annule
  check((W.flows_in["iron-ore"] or 0) >= ore + plates - 2, "M3 : minerai produit (entree) : coffre + four (" .. tostring(W.flows_in["iron-ore"]) .. " >= " .. (ore + plates - 2) .. ")")
  check((W.flows_out["iron-ore"] or 0) >= plates + qg - 2, "M3 : minerai consomme (sortie) : fours (" .. tostring(W.flows_out["iron-ore"]) .. " >= " .. (plates + qg - 2) .. ")")
  check(W.pollution > 0, "M3 : pollution emise")
  check(Gel.status(E.s1) == STATUS.no_ingredients, "M3 : four du QG vide : statut comptable « no_ingredients »")
  -- M4
  W.player.position = { x = 6.5 - 220, y = 10 } -- 220 tuiles a gauche de la boite de la foreuse (1) ; 230 de celle de (2)
  local T = W.tick
  local woke_at
  for _ = 1, 25 do run(1); if E.d1.active and not woke_at then woke_at = W.tick end end
  check(woke_at and woke_at - T <= 20, "M4 : joueur a 220 tuiles : reveil en " .. tostring(woke_at and (woke_at - T)) .. " ticks")
  check(E.d2.active == false, "M4 : le reste (a plus de 224 tuiles de sa boite) reste fige")
  check(Gel.status(E.d1) == STATUS.working and Gel.state().vstatus[E.d1.unit_number] == nil, "M4 : statut comptable efface au reveil")
  -- M14 option (ii) : au réveil, la fraction comptée pendant le gel est rendue à la foreuse par sa progression (unités de mining_time)
  do
    local I1 = Gu.U().ilots[Gu.U().by_unit[E.d1.unit_number]]
    local bank = I1 and I1.acc.bank_frac and I1.acc.bank_frac[E.d1.unit_number]
    check(W.mp_writes >= 1 and E.d1.mining_progress > 0 and E.d1.mining_progress < 1 and bank == nil,
      "M14 : reveil : progression de la foreuse ecrite (" .. string.format("%.4f", E.d1.mining_progress) .. "), plus rien de cote")
  end
  W.player.position = { x = 5000, y = 5000 }
  -- M5
  run(700)
  check(not E.d1.active, "M5 : refige apres 600 ticks de calme")
  f.attack_alert_t = W.tick
  run(20)
  check(E.d1.active and E.d2.active and E.s1.active, "M5 : attaque : tout reveille au guet suivant")
  f.attack_alert_t = nil
  run(1300)
  check(not E.d2.active, "M5 : refige ensuite")
  -- M17 (décision du lead, 8/11) : « armée dehors » ne réveille PAS les usines ; la règle commune, elle, réveillerait
  do
    W.army_out = true
    run(40)
    check(not E.d2.active and not E.s1.active, "M17 : armee dehors : les usines restent figees")
    local Gp = require("shared.faction.gel")
    local I2 = Gu.U().ilots[Gu.U().by_unit[E.d2.unit_number]]
    local acts = Gp.decide_all({ { id = I2.id, st = { frozen = true }, boxes = I2.boxes } }, Gel.input(f, {}, true), nil, W.tick)
    check(acts[1] and acts[1].action == "eveille" and acts[1].cause == "armee dehors",
      "M17 : la regle commune avec army_out = vrai reveillerait (" .. tostring(acts[1] and acts[1].cause) .. ") : les deux regles different")
    W.army_out = nil
  end
  -- M6
  local arm2 = entity({ name = "inserter", type = "inserter", x = 20.5, y = 15, h = 0.2 })
  arm2.pickup_target = E.k2
  for _, fn in ipairs(H.on[defines.events.script_raised_built] or {}) do fn({ entity = arm2 }) end
  run(20)
  check(E.d2.active and E.k2.active, "M6 : bras pose pres de l'ilot fige : reveille")
  run(4000)
  check(E.d2.active and (u.stats[1].refus.bras or 0) >= 2, "M6 : releve suivant : refuse « bras », plus jamais fige (" .. tostring(u.stats[1].refus.bras) .. ")")
  arm2.valid = false
  -- M7 budget
  Gel.WRITES = 1
  run(4000)
  local per_tick_ok = true
  for t, c in pairs(W.writes) do if t > W.tick - 4000 and c > 1 then per_tick_ok = false end end
  check(per_tick_ok and not E.d1.active, "M7 : budget d'une ecriture par tick respecte, gel etale")
  Gel.WRITES = 600
  -- M8
  settings.global["fo-war-gel"].value = false
  run(20)
  check(frozen_count() == 0, "M8 : reglage eteint : tout reveille (" .. frozen_count() .. ")")
  run(2000)
  check(frozen_count() == 0, "M8 : reglage eteint : rien de refige")
  settings.global["fo-war-gel"].value = true
  run(2000)
  if os.getenv("FO_DEBUG") then
    for _, id in ipairs(require("script.faction.state").sorted_keys(u.ilots)) do local I = u.ilots[id]
      print("DBG ilot", id, "fz", tostring(I.st.frozen), "calm", tostring(I.st.calm), "dirty", tostring(I.dirty), "owed", tostring(I.owed), "pend", tostring(I.pending)) end
    print("DBG pend", #u.pend, "owed", #u.owed, "u==", tostring(Gu.U() == u))
    local sc = u.scan[1]
    print("DBG scan", sc and #sc.q, sc and sc.pos, sc and sc.next_at, "tick", W.tick, "ids_f", #(u.ids_f[1] or {}))
    for k, v in pairs(u.stats[1].refus) do print("DBG refus", k, v) end
  end
  check(frozen_count() > 0, "M8 : rallume : refige")
  for _, fn in ipairs(H.config) do fn({}) end
  check(frozen_count() == 0 and Gel.state().u == nil and Gel.state().n_frozen == 0, "M8 : donnees changees : tout reveille, registre vide")
  -- M9
  f.is_player = true
  run(5000)
  check(frozen_count() == 0, "M9 : votre equipe : jamais figee")
  f.is_player = nil
  -- M12 remplaçant d'une machine figée (niveau, fast_replace, raise_built) qui hériterait de active = false (relecture de revue-s)
  -- (depuis M15 : un four du QG VIDE n'est pas relevé ; s1 a tout fondu en M3 : regarni, il est relevé au relevé suivant, 3 600 ticks)
  E.s1._src.items["iron-ore"] = 40
  run(4300)
  check(not E.s1.active, "M12 : four du QG refige")
  local s1b = entity({ name = "steel-furnace", type = "furnace", x = E.s1.position.x, y = E.s1.position.y, proto = FURN_P, burner = true, crafting_speed = 2 })
  s1b.active = false
  E.s1.valid = false
  for _, fn in ipairs(H.on[defines.events.script_raised_built] or {}) do fn({ entity = s1b }) end
  check(s1b.active == true, "M12 : remplacant d'une machine figee : rendu actif dans le gestionnaire")
  run(40)
  check(frozen_count() == 0 or not E.d1.active, "M12 : l'ilot du remplace est relu (les autres peuvent rester figes)")
  -- M13 faction anéantie pendant le gel : tout est réveillé, le registre de la faction est vidé (relecture de revue-s)
  run(1300)
  check(frozen_count() > 0, "M13 : figes avant l'aneantissement (" .. frozen_count() .. ")")
  f.eliminated = true
  run(20)
  check(frozen_count() == 0, "M13 : faction aneantie : tout reveille au guet suivant (" .. frozen_count() .. ")")
  check(Gel.state().n_frozen == 0, "M13 : faction aneantie : n_frozen a 0 (" .. tostring(Gel.state().n_frozen) .. ")")
  run(60)
  check(Gu.U().ids_f[1] == nil, "M13 : registre de la faction aneantie vide")
  f.eliminated = nil
  check(W.bad_writes == 0, "M11 : aucune ecriture de progression (au monde factice)")
  -- M16 instrumentation fine du guet (C19, mesure seulement) : portées fermées, portées et compteurs vus
  check(prof_check("M16", { "gel:guet", "gel:pas", "gel:releve", "gel:g:entrees", "gel:g:regle", "gel:g:actions", "gel:g:menage" },
    { "gel:ilots", "gel:geles", "gel:decides" }))
  -- M19 (C19) : guets étalés : le guet des usines ne tombe qu'aux ticks 0 (commun) et 2 (faction 1) de la période de 20
  do
    local at = PROF.at and PROF.at["gel:guet"] or {}
    local bad = 0
    for k = 0, 19 do if at[k] and k ~= 0 and k ~= 2 then bad = bad + 1 end end
    local ks = {} for k = 0, 19 do if at[k] then ks[#ks + 1] = k end end
    check(bad == 0 and at[0] and at[2], "M19 : guet des usines aux ticks 0 (commun) et 2 (faction 1) de la periode seulement (" .. table.concat(ks, ",") .. ")")
  end
  return table.concat(W.logs, "\n") .. "|" .. tostring(E.c1._inv.items["iron-ore"]) .. "|" .. tostring(E.k2._out.items["iron-plate"])
end

-- M15 four du QG sans recette connue (C19, sauvegarde du DC, 8/11 : « Unknown item name: ? » arrêtait la partie)
local function scene_recette()
  new_world()
  local f = build_faction()
  local Gu = require("script.faction.gel_usines")
  local s2 = entity({ name = "stone-furnace", type = "furnace", x = -20.5, y = 0.5, proto = FURN_P, burner = true, coal = 5, crafting_speed = 1 })
  s2._src.items["iron-ore"] = 10
  local s3 = entity({ name = "stone-furnace", type = "furnace", x = -30.5, y = 0.5, proto = FURN_P, burner = true, coal = 5, crafting_speed = 1 })
  f.smelters = { f.smelters[1], s2, s3 }
  run(40)
  local u = Gu.U()
  local refus = u.stats[1] and u.stats[1].refus or {}
  check((refus.recette or 0) >= 1 and u.by_unit[s3.unit_number] == nil, "M15 : four du QG vide : refuse « recette » au releve (" .. tostring(refus.recette) .. ")")
  check(u.by_unit[s2.unit_number] ~= nil, "M15 : four du QG garni : releve")
  -- la source de s2 est vidée et remplie d'un objet sans recette de four AVANT son premier pas : la recette reste inconnue (« ? »)
  s2._src.items = { wood = 5 }
  local ok, err = pcall(run, 3000)
  check(ok, "M15 : four figé dont la source prend un objet sans recette de four : aucun nom inconnu lu au moteur, la partie continue" .. (ok and "" or (" : " .. tostring(err))))
  check((s2._out.items["iron-plate"] or 0) == 0 and (s2._src.items.wood or 0) == 5, "M15 : rien produit ni consommé par ce four (recette gardée, ingrédient absent)")
end
scene_recette()

local a = scenes()
local dec_a, il_a = PROF.cnt["gel:decides"] or 0, PROF.cnt["gel:ilots"] or 0
local b = scenes()
check(a == b, "M10 : deux passages : memes journaux et memes inventaires")
-- M18 (C19, décision du lead) : seuls les îlots éveillés décidés = TOUS les îlots décidés : même partie (journaux et inventaires)
FORCE_TOUS = true
local c = scenes()
local dec_c, il_c = PROF.cnt["gel:decides"] or 0, PROF.cnt["gel:ilots"] or 0
FORCE_TOUS = nil
check(c == a and dec_a < il_a and dec_c == il_c, string.format(
  "M18 : figes calmes sautes = tous decides : meme partie ; postes decides %d sur %d (tous : %d sur %d)", dec_a, il_a, dec_c, il_c))

-- M11 contrôle statique des fichiers du lot
do
  local bad = {}
  for _, p in ipairs({ "script/faction/gel.lua", "script/faction/gel_usines.lua", "script/faction/gel_usines_jeu.lua", "shared/faction/gel.lua", "shared/faction/gel_compta.lua" }) do
    local fh = assert(io.open(p, "rb"))
    local s = fh:read("*a")
    fh:close()
    for _, k in ipairs({ "crafting_progress%s*=", "bonus_progress%s*=" }) do
      if s:find("[%.:]" .. k) then bad[#bad + 1] = p .. " " .. k end
    end
    -- C19 (8/11) : plus aucun nom fictif « ? » dans les fichiers du lot (il atteignait le moteur : « Unknown item name: ? »)
    if s:find('"?"', 1, true) then bad[#bad + 1] = p .. ' "?"' end
    -- option (ii) : la progression d'une foreuse n'est écrite QUE par write_progress (gel_usines_jeu.lua)
    if p ~= "script/faction/gel_usines_jeu.lua" then
      for _, k in ipairs({ "mining_progress%s*=", "bonus_mining_progress%s*=" }) do
        if s:find("[%.:]" .. k) then bad[#bad + 1] = p .. " " .. k end
      end
    end
  end
  check(#bad == 0, "M11 : aucune ecriture de progression dans les fichiers du lot" .. (#bad > 0 and (" : " .. table.concat(bad, ", ")) or ""))
end

-- Mutants du runtime (relecture de revue-s, 8/11) : texte de gel_usines_jeu.lua changé, la scène complète doit échouer.
do
  local fh = assert(io.open("script/faction/gel_usines_jeu.lua", "rb"))
  local SRC = fh:read("*a")
  fh:close()
  local MUTANTS = {
    { "guet limite aux factions vivantes", "        want_wake(I, tick, \"faction disparue\")\n", "" },
    { "progression non rendue au reveil (option ii)", "else Gc.bank(I.acc); write_progress(I) end", "else Gc.bank(I.acc) end" },
    { "remplacant d'une machine figee laisse inactif", "if why == \"pose\" and inside_frozen and entity.active == false then entity.active = true end", "" },
    { "armee dehors reveille encore les usines", "  local s = Gel.input(f, players, false)", "  local s = Gel.input(f, players, (Commander.army_out(f)))" },
    { "un fige jamais relu apres une cause de faction (C19)", "local skip = (not Gj.TOUS) and G.skip_quiet(s, fbox, tick)", "local skip = (not Gj.TOUS) and fbox ~= nil" },
    { "guet des usines aux ticks des garnisons (C19)", "local who = G.guet_of(tick % G.GUET, \"usines\")", "local who = G.guet_of(tick % G.GUET, \"garnisons\")" },
    { "portee fine non fermee (C19)", "  Profiler.fstop(\"gel:g:menage\")\n", "" },
  }
  -- (C19, 8/11) mutants de gel_usines.lua (relevé) et de la recette fictive d'avant le correctif, rendue au pas
  local fg = assert(io.open("script/faction/gel_usines.lua", "rb"))
  local SRC_GU = fg:read("*a")
  fg:close()
  local MUTANTS_GU = {
    { "four du QG releve sans recette (C19)", "  if not recipe then return nil, \"recette\" end\n  local u = s.unit_number", "  local u = s.unit_number" },
  }
  MUTANTS[#MUTANTS + 1] = { "recette fictive « ? » rendue au pas (C19, avant le correctif)", "  if not recipe then return end\n  local e = I.machines[1]",
    "  if not recipe then m.ing, m.out = { { \"?\", 1 } }, { { \"?\", 1 } }; return end\n  local e = I.machines[1]" }
  local seen, missed = 0, {}
  local ok0, fail0 = ok_n, fail_n
  quiet = true
  for _, mu in ipairs(MUTANTS) do
    local s, e = SRC:find(mu[2], 1, true)
    if not s then missed[#missed + 1] = mu[1] .. " (texte introuvable)" else
      MUT_JEU = SRC:sub(1, s - 1) .. mu[3] .. SRC:sub(e + 1)
      local before = fail_n
      local okc = pcall(function() scene_recette(); scenes() end)
      local died = (fail_n > before) or not okc
      if died then seen = seen + 1 else missed[#missed + 1] = mu[1] end
      MUT_JEU = nil
    end
  end
  for _, mu in ipairs(MUTANTS_GU) do
    local s, e = SRC_GU:find(mu[2], 1, true)
    if not s then missed[#missed + 1] = mu[1] .. " (texte introuvable)" else
      MUT_GU = SRC_GU:sub(1, s - 1) .. mu[3] .. SRC_GU:sub(e + 1)
      local before = fail_n
      local okc = pcall(function() scene_recette(); scenes() end)
      local died = (fail_n > before) or not okc
      if died then seen = seen + 1 else missed[#missed + 1] = mu[1] end
      MUT_GU = nil
    end
  end
  ok_n, fail_n = ok0, fail0
  quiet = false
  check(#missed == 0, string.format("mutants du runtime : %d/%d vus%s", seen, #MUTANTS + #MUTANTS_GU, #missed > 0 and (" ; NON VUS : " .. table.concat(missed, " ; ")) or ""))
end

print(string.format("[GEL-MOTEUR] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
