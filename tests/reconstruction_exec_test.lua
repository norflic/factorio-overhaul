--[[
  Lot RECONSTRUIRE : exécutant hors jeu (moteur simulé réduit) de script/team/reconstruction.lua (registre, tâches « rebuild », programme, pose, « améliorer attend »).
  Les règles pures sont dans tests/reconstruction_test.lua ; ici on contrôle le branchement : qui est inscrit, qui ne l'est pas,
  quand une tâche naît, ce que le PNJ pose, ce qui est restitué à l'avant-poste.
  Usage : lua5.2 tests/reconstruction_exec_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- Doublures --------------------------------------------------------------------------------------------------------
local handlers = {}
package.loaded["script.core.events"] = { on = function(id, fn) handlers[id] = fn end }
defines = { events = { on_entity_died = 1, on_player_mined_entity = 2, on_robot_mined_entity = 3 }, entity_status = { no_power = 7, working = 1 }, direction = { north = 0, east = 2, south = 4, west = 6 } }
local ns = { ia3k = { teams = {} } }
package.loaded["script.core.storage"] = { ns = function(n) ns[n] = ns[n] or {}; return ns[n] end }
local player
local owners = {}
package.loaded["script.faction.state"] = {
  sorted_keys = function(t) local k = {} for key in next, t do k[#k + 1] = key end table.sort(k) return k end,
  owner = function(u) return owners[u] end,
  own = function(e, fid, kind, oid) owners[e.unit_number] = { f = fid, kind = kind, oid = oid } end,
  faction = function(id) if id == "player" then return player end end,
  by_force = function(fn) return fn == "scarlet" and package.loaded.__scarlet or nil end,
  alive = function() return {} end,
}
local added = {}
package.loaded["script.team.board"] = {
  get = function(f) return f.team.board end,
  add = function(f, tasks)
    local n = 0
    for _, t in ipairs(tasks) do if not f.team.board.tasks[t.key] then f.team.board.tasks[t.key] = t; added[#added + 1] = t; n = n + 1 end end
    return n
  end,
}
package.loaded["script.team.stock"] = { count = function(f, item) return f.stock[item] or 0 end }
remote = { add_interface = function() end }
local logs = {}
function log(s) logs[#logs + 1] = s end

local PROTOS = {
  ["piece-a"] = { items_to_place_this = { { name = "item-a" } } },
  ["piece-b"] = { items_to_place_this = { { name = "item-b" } } },
  ["piece-d"] = { items_to_place_this = { { name = "item-d" } } },
  ["pole-x"] = { items_to_place_this = { { name = "item-p" } } },
  ["chaudiere-x"] = { items_to_place_this = { { name = "item-c" } } },
  ["tourelle-x"] = { turret_range = 18, items_to_place_this = { { name = "tourelle-x" } } },
}
game = { tick = 0, entity_prototypes = PROTOS }
PROTOS["pole-x"].supply_area_distance = 2.5
PROTOS["pole-x"].max_wire_distance = 7.5
PROTOS["pole-m"] = { items_to_place_this = { { name = "item-m" } }, supply_area_distance = 3.5, max_wire_distance = 9 }
PROTOS["pole-s"] = { items_to_place_this = { { name = "item-s" } }, supply_area_distance = 1, max_wire_distance = 5 }
function game.get_filtered_entity_prototypes() return setmetatable({}, { __pairs = function() local ks = { "pole-x", "pole-m", "pole-s" } local i = 0 return function() i = i + 1 if ks[i] then return ks[i], PROTOS[ks[i]] end end end }) end

-- Lot CORR-RECONSTRUIRE : le bois vient des arbres, tout le reste porte le nom de son entité (script/team/harvest.lua, balayage des prototypes).
package.loaded["script.team.harvest"] = { names = function(item) if item == "bois" then return { "arbre-a" } end return { item } end }
local R = require("shared.ai3.reglages")
-- Lot REBUILD-TOUT (29/10) : tout est allumé par défaut ; les sections 1 à 11 testent le mécanisme GÉNÉRAL du registre (relevé des projets
-- éteint : le registre refait aussi les pièces des projets), la section 12 le branchement du relevé.
check(R.RECON_ALL_PIECES == true and R.RECON_FACTIONS == true and R.REBUILD_SWEEP == true, "réglages par défaut : factions, toutes les pièces et relevé allumés (lot REBUILD-TOUT)")
R.REBUILD_SWEEP = false
local Rc = require("shared.team.reconstruction")
local Recon = require("script.team.reconstruction")
local died = handlers[1]
check(died ~= nil, "l'exécutant s'abonne à on_entity_died")

-- Une équipe de test ----------------------------------------------------------------------------------------------
local unit = 100
local function ent(name, ty, x, y, force, dir)
  unit = unit + 1
  return { valid = true, name = name, type = ty, unit_number = unit, position = { x = x, y = y }, direction = dir or 0,
    force = { name = force or "player" }, get_recipe = function() return { name = "rec-1" } end }
end
local function new_team()
  local f = { id = "player", key = "player", force = "player", is_player = true, started = 0, stats = {},
    hq = { valid = true, position = { x = 0, y = 0 }, unit_number = 1 }, stock = { ["item-a"] = 5, ["item-b"] = 5, ["item-d"] = 5, ["item-p"] = 3, ["item-c"] = 1 },
    outposts = { [7] = { id = 7, drills = 2, drill_list = {}, sinks = {} } }, turrets = {},
    team = { board = { tasks = {} } },
    build = { order = { 1 }, projects = { [1] = { ents = { { name = "piece-a", x = 10, y = 10 }, { name = "piece-b", x = 12, y = 10 } } } } } }
  player = f
  owners = {}
  added = {}
  return f
end
local surface
surface = {
  enemies = 0, placeable = true, created = {},
  find_enemy_units = function(self) local n = {} for i = 1, surface.enemies do n[i] = {} end return n end,
  find_entity = function() return nil end,
  find_entities = function() return {} end,
  floor_items = {},
  consumers = {},
  corpses = {},
  find_entities_filtered = function(args)
    if args and type(args.type) == "table" then return surface.consumers end
    if args and args.type == "corpse" then return surface.corpses end
    local l = {} for i, e in ipairs(surface.floor_items) do l[i] = e end return l end,
  get_tile = function() return { name = "grass-1" } end,
  can_place_entity = function() return surface.placeable and #surface.floor_items == 0 end,
  create_entity = function(spec)
    local e = ent(spec.name, spec.type or "assembling-machine", spec.position.x, spec.position.y, spec.force, spec.direction)
    e.set_recipe = function(r) e.recipe = r end
    surface.created[#surface.created + 1] = e
    return e
  end,
}
-- Le moteur simulé a deux fonctions de plus au site d'appel : set_recipe sur type "assembling-machine".

-- §1 Inscription ------------------------------------------------------------------------------------------------------
do
  local f = new_team()
  local a = ent("piece-a", "assembling-machine", 10, 10)
  died({ entity = a, tick = 1000 })
  check(f.recon and Rc.pending(f.recon) == 1, "pièce d'un projet du plan directeur : inscrite")
  local r = f.recon.lost[Rc.key({ name = "piece-a", x = 10, y = 10 })]
  check(r and r.item == "item-a" and r.recipe == "rec-1" and r.value == 5, "objet lu au prototype, recette gardée, valeur du rôle")
  died({ entity = ent("piece-d", "assembling-machine", 50, 50), tick = 1001 })
  check(Rc.pending(f.recon) == 1, "pièce posée par le JOUEUR (hors projet, hors propriétés) : jamais refaite")
  local d = ent("piece-d", "mining-drill", 20, 20)
  owners[d.unit_number] = { f = "player", kind = "drill", oid = 7 }
  died({ entity = d, tick = 1002 })
  local rd = f.recon.lost[Rc.key({ name = "piece-d", x = 20, y = 20 })]
  check(rd and rd.kind == "drill" and rd.oid == 7, "foreuse d'un avant-poste : inscrite avec son avant-poste")
  local o = ent("piece-d", "mining-drill", 30, 20)
  owners[o.unit_number] = { f = "autre", kind = "drill", oid = 1 }
  died({ entity = o, tick = 1003 })
  check(f.recon.lost[Rc.key({ name = "piece-d", x = 30, y = 20 })] == nil, "foreuse d'une autre équipe : ignorée")
  died({ entity = ent("tourelle-x", "ammo-turret", 5, 5), tick = 1004 })
  check(Rc.pending(f.recon) == 2, "tourelle : jamais au registre (défendre d'abord les refait)")
  died({ entity = ent("piece-a", "character", 10, 10), tick = 1005 })
  check(Rc.pending(f.recon) == 2, "un personnage mort n'est ni refait ni compté")
  died({ entity = { valid = false }, tick = 1 })
end

-- §2 Pensée : tâches ---------------------------------------------------------------------------------------------------
do
  local f = new_team()
  died({ entity = ent("piece-a", "assembling-machine", 10, 10), tick = 1000 })
  died({ entity = ent("piece-b", "transport-belt", 12, 10), tick = 1001 })
  check(Recon.think(f, surface, 1000 + Rc.CALM - 5) == 0, "patience : rien avant le calme")
  surface.enemies = 2
  check(Recon.think(f, surface, 1000 + Rc.CALM + 50) == 0 and f.recon.stats.deferred >= 1, "ennemis près de la place : différée, pas de tâche")
  surface.enemies = 0
  check(Recon.think(f, surface, 1000 + Rc.CALM + 100) == 0, "pièce différée : pas avant la date de report")
  local n = Recon.think(f, surface, 1000 + Rc.CALM + Recon.RETRY + 100)
  check(n == 1 and #added == 1, "calme et place libre : une tâche pour le lot")
  local t = added[1]
  check(t.kind == "rebuild" and #t.recs == 2 and t.pos.x == 10 and t.prio == Rc.task_prio(5), "tâche « rebuild » : le lot des deux voisines, priorité de la plus précieuse")
  check(#t.items == 2 and t.items[1][1] == "item-a" and t.items[2][1] == "item-b", "objets du lot au stock")
  check(Recon.think(f, surface, 1000 + Rc.CALM + Recon.RETRY + 200) == 0, "tâche déjà au tableau : pas de doublon")
  check(Recon.hold_upgrades(f) == true, "améliorer attend (objets au stock)")
  f.stock = {}
  check(Recon.hold_upgrades(f) == false, "sans l'objet au stock, rien à refaire : l'amélioration d'autre chose ne les gêne pas")
  f.stock = { ["item-a"] = 5, ["item-b"] = 5 }
  -- Programme : la prise de la tâche marque les pièces
  t.worker = 9
  local steps = Recon.program(f, t)
  check(steps and steps[2][1] == "take" and steps[2].strict == true and steps[4][2] == "rebuild", "programme : prendre au stock (strict), aller, poser")
  check(f.recon.lost[t.recs[1]].claimed == t.key, "pièces prises par la tâche")
  check(#Rc.due(f.recon, 20000) == 0, "pièces prises : non reproposées")
  -- PNJ mort en route : la tâche perd son ouvrier, les pièces reviennent
  t.worker = nil
  Recon.think(f, surface, 20000)
  check(f.recon.lost[t.recs[1]].claimed == nil, "tâche sans ouvrier : pièces rendues")
  f.team.board.tasks[t.key] = nil
end

-- §3 Pose ---------------------------------------------------------------------------------------------------------------
do
  local f = new_team()
  surface.enemies = 0
  died({ entity = ent("piece-a", "assembling-machine", 10, 10, "player", 2), tick = 100 })
  local d = ent("piece-d", "mining-drill", 16, 12)
  owners[d.unit_number] = { f = "player", kind = "drill", oid = 7 }
  died({ entity = d, tick = 100 })
  Recon.think(f, surface, 100 + Rc.CALM + 10)
  local t = added[#added]
  t.worker = 3
  Recon.program(f, t)
  local inv = { items = { ["item-a"] = 1, ["item-d"] = 1 } }
  inv.get_item_count = function(n) return inv.items[n] or 0 end
  inv.remove = function(s) inv.items[s.name] = (inv.items[s.name] or 0) - s.count end
  local agent = { entity = { get_main_inventory = function() return inv end } }
  surface.created = {}
  local ok = Recon.act(agent, f, t, surface)
  check(ok and #surface.created == 2, "le PNJ pose les deux pièces")
  local a = surface.created[1]
  check(a.name == "piece-a" and a.position.x == 10 and a.direction == 2, "même nom, même place, même direction")
  check(a.recipe == "rec-1", "recette rétablie")
  check(inv.items["item-a"] == 0 and inv.items["item-d"] == 0, "un objet par pièce retiré de l'inventaire")
  local o = f.outposts[7]
  check(o.drills == 3 and #o.drill_list == 1, "foreuse rendue à son avant-poste (compte et liste)")
  check(owners[surface.created[2].unit_number] and owners[surface.created[2].unit_number].kind == "drill", "propriété rétablie")
  check(Rc.pending(f.recon) == 0 and Recon.hold_upgrades(f) == false and f.recon.stats.rebuilt == 2, "registre vidé, améliorations libres")
  local bn = f.recon.stats.byname and f.recon.stats.byname["piece-a"]
  check(bn and bn.rec == 1 and bn.own == 1 and bn.own_sum >= 0 and bn.ext == 0, "mesure : pièce détruite puis refaite par l'équipe, comptée par nom")
  -- place prise : la pièce reste
  died({ entity = ent("piece-b", "assembling-machine", 12, 10), tick = 5000 })
  Recon.think(f, surface, 5000 + Rc.CALM + 5)
  local t2 = added[#added]
  t2.worker = 3
  Recon.program(f, t2)
  inv.items["item-b"] = 1
  surface.placeable = false
  check(Recon.act(agent, f, t2, surface) == false and Rc.pending(f.recon) == 1 and f.recon.stats.blocked == 1, "place occupée : rien posé, la pièce reste en attente")
  check(f.recon.lost[t2.recs[1]].claimed == nil, "tâche finie : pièce libérée pour un autre essai")
  surface.placeable = true
  -- objets au sol (contenu d'un coffre détruit) : ramassés avant la pose, sinon la pose est refusée
  inv.insert = function(s) inv.items[s.name] = (inv.items[s.name] or 0) + s.count return s.count end
  local gone = false
  surface.floor_items = { { valid = true, stack = { valid_for_read = true, name = "coal", count = 3 },
    destroy = function() gone = true surface.floor_items = {} end } }
  inv.items["item-b"] = 1
  local before = f.recon.stats.blocked
  check(Recon.act(agent, f, t2, surface) == true and gone and inv.items["coal"] == 3 and f.recon.stats.blocked == before,
    "objets au sol dans l'emprise : ramasses, puis la piece est posee")
  surface.floor_items = {}
  died({ entity = ent("piece-b", "assembling-machine", 12, 10), tick = 6000 })
  Recon.think(f, surface, 6000 + Rc.CALM + 5)
  t2 = added[#added]
  t2.worker = 3
  Recon.program(f, t2)
  -- PNJ debout sur l'emprise : écarté avant la pose
  PROTOS["piece-b"].collision_box = { left_top = { x = -1.5, y = -1.5 }, right_bottom = { x = 1.5, y = 1.5 } }
  local moved
  local me
  me = { valid = true, name = "character", position = { x = 12.5, y = 10.5 }, get_main_inventory = function() return inv end,
    teleport = function(p) moved = p; me.position = p end }
  inv.items["item-b"] = 1
  surface.find_non_colliding_position = function(_, c) return { x = c.x, y = c.y } end
  Recon.program(f, t2)
  Recon.act({ entity = me }, f, t2, surface)
  check(moved ~= nil and moved.x > 12 + 1.5 and Rc.pending(f.recon) == 0, "PNJ debout sur l'emprise : écarté à l'est, puis la pièce est posée")
  -- avant-poste disparu : la foreuse seule ne se refait pas
  local f2 = new_team()
  f2.outposts = {}
  local d2 = ent("piece-d", "mining-drill", 40, 40)
  owners[d2.unit_number] = { f = "player", kind = "drill", oid = 7 }
  died({ entity = d2, tick = 10 })
  Recon.think(f2, surface, 10 + Rc.CALM + 10)
  check(Rc.pending(f2.recon) == 0 and f2.recon.stats.discarded == 1 and #added == 0, "avant-poste disparu : foreuse seule abandonnée sans tâche")
end

-- §6 Infrastructure électrique ------------------------------------------------------------------------------------------
do
  local f = new_team()
  local pole = ent("pole-x", "electric-pole", 60, 60) -- posé à la main : hors projet, hors propriétés
  died({ entity = pole, tick = 1000 })
  died({ entity = ent("chaudiere-x", "boiler", 90, 90), tick = 1000 })
  died({ entity = ent("piece-d", "container", 70, 70), tick = 1000 })
  check(Rc.pending(f.recon) == 2, "poteau et chaudière posés à la main sont inscrits ; un coffre ne l'est pas")
  local rp = f.recon.lost[Rc.key({ name = "pole-x", x = 60, y = 60 })]
  local rb = f.recon.lost[Rc.key({ name = "chaudiere-x", x = 90, y = 90 })]
  check(rp.infra and rp.value == Rc.pole_value(0) and rb.infra and rb.value == Rc.INFRA_VALUE, "valeurs : poteau de base, chaudière au-dessus")
  -- Un laboratoire ordinaire du projet, détruit en même temps : refait APRÈS les pièces d'infrastructure, et plus tard (patience).
  died({ entity = ent("piece-a", "assembling-machine", 10, 10), tick = 1000 })
  local n = Recon.think(f, surface, 1000 + Rc.CALM_INFRA + 5)
  check(n >= 1, "patience courte : l'infrastructure a sa tâche avant la patience ordinaire")
  check(added[1] and #added[1].recs == 1 and f.recon.lost[added[1].recs[1]].name == "chaudiere-x",
    "la chaudière est la première tâche (valeur au-dessus du poteau ; lots séparés, trop loin l'un de l'autre)")
  check(added[1].prio > added[2].prio, "priorité de tâche : chaudière avant poteau")
  -- Valeur d'un poteau : consommateurs sans courant près de lui, lus au moteur.
  f.team.board.tasks = {}
  added = {}
  for i = 1, 20 do surface.consumers[i] = { valid = true, status = defines.entity_status.no_power } end
  surface.consumers[21] = { valid = true, status = defines.entity_status.working }
  Recon.think(f, surface, 1000 + Rc.CALM_INFRA + 400)
  check(rp.cut == 20 and rp.value == Rc.pole_value(20) and rp.value > Rc.ROLE_VALUE.labo, "poteau qui coupe 20 consommateurs : valeur plafonnée, avant un laboratoire")
  check(rb.value == Rc.INFRA_VALUE, "la valeur d'une chaudière n'est pas relue")
  surface.consumers = {}
  -- Sans l'objet au stock : en attente, comptée, sans tâche
  local f2 = new_team()
  f2.stock["item-p"] = 0
  died({ entity = ent("pole-x", "electric-pole", 61, 61), tick = 2000 })
  Recon.think(f2, surface, 2000 + Rc.CALM_INFRA + 5)
  local bn = f2.recon.stats.byname["pole-x"]
  check(bn and bn.nostock == 1 and #added == 0, "faute d'objet au stock : pas de tâche, pièce comptée en attente de stock")
  surface.consumers = {}
end

-- §7 Factions : réglage R.RECON_FACTIONS -------------------------------------------------------------------------------
do
  local sc = { id = "scarlet", key = "scarlet", force = "scarlet", started = 0, stats = {},
    hq = { valid = true, position = { x = 0, y = 0 }, unit_number = 2 }, stock = { ["item-a"] = 5 }, outposts = {}, team = { board = { tasks = {} } },
    build = { order = { 1 }, projects = { [1] = { ents = { { name = "piece-a", x = 10, y = 10 } } } } } }
  package.loaded.__scarlet = sc
  R.RECON_FACTIONS = false
  died({ entity = ent("piece-a", "assembling-machine", 10, 10, "scarlet"), tick = 1000 })
  check(sc.recon == nil or Rc.pending(sc.recon) == 0, "faction : pièce détruite non inscrite (réglage éteint)")
  R.RECON_FACTIONS = true
  died({ entity = ent("piece-a", "assembling-machine", 10, 10, "scarlet"), tick = 1000 })
  check(sc.recon and Rc.pending(sc.recon) == 1, "faction : inscrite quand le réglage est allumé")
  R.RECON_FACTIONS = false
  package.loaded.__scarlet = nil
end

-- §8 Portée par défaut : infrastructure seule ; fabrication des objets d'infrastructure ----------------------------------
do
  R.RECON_ALL_PIECES = false
  local f = new_team()
  died({ entity = ent("piece-a", "assembling-machine", 10, 10), tick = 1000 })
  died({ entity = ent("pole-x", "electric-pole", 60, 60), tick = 1000 })
  check(Rc.pending(f.recon) == 1 and f.recon.lost[Rc.key({ name = "pole-x", x = 60, y = 60 })], "portée par défaut : le poteau seul est inscrit")
  -- craft_spares : objet absent du stock libre, livre de recettes qui sait le faire
  f.stock["item-p"] = 0
  local made = {}
  local book = {
    handcraftable = function(_, item) return item == "item-p" end,
    plan = function(_, list) return { raw = {}, crafts = { { "recette-p", list[1][2] } }, uses = { ["copper-plate"] = 1, ["iron-plate"] = 2 } } end,
  }
  local free = { ["iron-plate"] = 50, ["copper-plate"] = 50 }
  local n = Recon.craft_spares(f, book, free, 1000 + Rc.CALM_INFRA + 5)
  local t = f.team.board.tasks["craft:item-p:reconstruction"]
  check(n == 1 and t and t.kind == "craft" and t.item == "item-p" and t.count == 1 and t.uses[1][1] == "copper-plate" and t.uses[2][1] == "iron-plate",
    "objet d'infrastructure manquant : une tâche de fabrication, matières triées")
  check(Recon.craft_spares(f, book, free, 1000 + Rc.CALM_INFRA + 6) == 0, "même objet : pas de doublon au tableau")
  f.team.board.tasks = {}
  local book2 = { handcraftable = function() return true end, plan = function() return { raw = { ["iron-ore"] = 3 }, crafts = {}, uses = {} } end }
  check(Recon.craft_spares(f, book2, free, 1000 + Rc.CALM_INFRA + 7) == 0 and next(f.team.board.tasks) == nil, "matière première absente : rien de fabriqué")
  check(Recon.craft_spares(f, nil, free, 1000 + Rc.CALM_INFRA + 8) == 0, "sans livre de recettes : rien")
  -- Revue statique 29/10 : la matière ne couvre qu'une partie du besoin (3 poteaux perdus, matière pour 2) : on fabrique les 2
  local f7 = new_team()
  for i = 1, 3 do died({ entity = ent("pole-x", "electric-pole", 60 + 10 * i, 60), tick = 1000 }) end
  f7.stock["item-p"] = 0
  local book3 = {
    handcraftable = function(_, item) return item == "item-p" end,
    plan = function(_, list)
      local m = list[1][2]
      if m > 2 then return { raw = { ["item-bois"] = m - 2 }, crafts = {}, uses = {} } end
      return { raw = {}, crafts = { { "recette-p", m } }, uses = { ["copper-plate"] = m } }
    end,
  }
  check(Recon.craft_spares(f7, book3, { ["copper-plate"] = 50 }, 1000 + Rc.CALM_INFRA + 5) == 1
    and f7.team.board.tasks["craft:item-p:reconstruction"].count == 2, "matière pour 2 sur 3 poteaux : la tâche fabrique 2, pas rien")
  R.RECON_ALL_PIECES = true
end


-- §9 Réparation ----------------------------------------------------------------------------------------------------------
do
  local f = new_team()
  local function dmg(name, x, y, hp, mx)
    local e = ent(name, "electric-pole", x, y)
    e.health = hp
    e.prototype = { max_health = mx }
    e.get_health_ratio = function() return e.health / mx end -- (le balayage lit le ratio : un seul appel moteur par entité)
    return e
  end
  local a, b, c = dmg("pole-x", 10, 10, 20, 100), dmg("pole-x", 12, 10, 90, 100), dmg("pole-x", 14, 10, 50, 100)
  surface.consumers = { a, b, c }
  surface.find_entity = function(_, p) for _, e in ipairs({ a, b, c }) do if e.position.x == p[1] and e.position.y == p[2] then return e end end end
  local n = Recon.repair_think(f, surface, 5000)
  local t
  for _, tk in pairs(f.team.board.tasks) do if tk.kind == "repair" then t = tk end end
  check(n == 1 and t and #t.targets == 2 and t.targets[1].x == 10, "pièces d'infrastructure sous 60 % de santé : une tâche de réparation (deux pièces, la plus abîmée d'abord)")
  check(Recon.repair_think(f, surface, 5001) == 0, "balayage une fois par seconde")
  check(Recon.repair_think(f, surface, 5000 + Recon.REPAIR_SCAN + 1) == 0, "une seule tâche de réparation à la fois")
  check(Recon.repair_program(f, t) ~= nil and Recon.repair_program(f, {}) == nil, "programme : aller sur place, réparer")
  local ok = Recon.repair_act({}, f, t, surface)
  check(ok and a.health == 100 and c.health == 100 and b.health == 90, "santé remise au maximum pour les pièces du lot seulement")
  check(Recon.repair_act({}, f, t, surface) == false, "rien à réparer : faux")
  f.team.board.tasks = {}
  surface.enemies = 3
  surface.consumers = { dmg("pole-x", 10, 10, 10, 100) }
  check(Recon.repair_think(f, surface, 9000) == 0 and next(f.team.board.tasks) == nil, "ennemis près de la pièce : pas de réparation")
  surface.enemies = 0
  local fa = new_team()
  fa.is_player = false
  check(Recon.repair_think(fa, surface, 9000) == 0, "les factions ne réparent pas (votre équipe seule)")
  surface.consumers = {}
end


-- §10 Pièce de remplacement et restes ------------------------------------------------------------------------------------
do
  local f = new_team()
  R.RECON_ALL_PIECES = false
  -- poteau « moyen » perdu : objet absent, non fabricable ; le petit poteau est au stock
  local pm = ent("pole-m", "electric-pole", 80, 80)
  pm.neighbours = { copper = { { valid = true, position = { x = 86, y = 80 } } } }
  died({ entity = pm, tick = 3000 })
  local r = f.recon.lost[Rc.key({ name = "pole-m", x = 80, y = 80 })]
  check(r and r.etype == "electric-pole" and math.abs(r.reach - 6) < 1e-9 and r.item == "item-m", "poteau perdu : portée de fil vers les voisins notée")
  f.stock["item-m"] = 0
  local book = { handcraftable = function(_, it) return it == "item-p" end, plan = function() return { raw = {}, crafts = {}, uses = {} } end }
  local free = { ["item-p"] = 2, ["item-m"] = 0 }
  Recon.craft_spares(f, book, free, 3000 + Rc.CALM_INFRA + 5)
  check(r.place == "pole-x" and r.item == "item-p", "objet ni au stock ni fabricable : le poteau du meilleur niveau disponible est posé à la place")
  check(f.recon.stats.substituted == 1, "remplacement compté")
  -- Pose : la pièce de remplacement est posée sous son propre nom
  f.stock["item-p"] = 2
  Recon.think(f, surface, 3000 + Rc.CALM_INFRA + 10)
  local t
  for _, tk in pairs(f.team.board.tasks) do if tk.kind == "rebuild" then t = tk end end
  check(t and t.items[1][1] == "item-p", "tâche : l'objet du remplaçant est pris au stock")
  t.worker = 1
  Recon.program(f, t)
  local inv = { items = { ["item-p"] = 1 } }
  inv.get_item_count = function(n) return inv.items[n] or 0 end
  inv.remove = function(sp) inv.items[sp.name] = (inv.items[sp.name] or 0) - sp.count end
  surface.created = {}
  check(Recon.act({ entity = { get_main_inventory = function() return inv end } }, f, t, surface), "pose du remplaçant")
  check(surface.created[1] and surface.created[1].name == "pole-x", "créé sous le nom du remplaçant, à la place exacte")
  -- Fil trop court : pas de remplaçant
  local f2 = new_team()
  local pm2 = ent("pole-m", "electric-pole", 90, 90)
  pm2.neighbours = { copper = { { valid = true, position = { x = 99, y = 90 } } } }
  died({ entity = pm2, tick = 4000 })
  Recon.craft_spares(f2, book, { ["item-p"] = 2 }, 4000 + Rc.CALM_INFRA + 5)
  local r2 = f2.recon.lost[Rc.key({ name = "pole-m", x = 90, y = 90 })]
  check(r2.place == nil, "voisin à 9 tuiles : le petit poteau (fil 7,5) ne convient pas, pas de remplaçant")
  -- Restes et cadavres de la place retirés avant la pose
  local f3 = new_team()
  died({ entity = ent("pole-x", "electric-pole", 60, 60), tick = 5000 })
  Recon.think(f3, surface, 5000 + Rc.CALM_INFRA + 5)
  local t3
  for _, tk in pairs(f3.team.board.tasks) do if tk.kind == "rebuild" then t3 = tk end end
  t3.worker = 1
  Recon.program(f3, t3)
  local gone = 0
  surface.corpses = { { valid = true, destroy = function() gone = gone + 1 end }, { valid = true, destroy = function() gone = gone + 1 end } }
  local inv3 = { items = { ["item-p"] = 1 } }
  inv3.get_item_count = function(n) return inv3.items[n] or 0 end
  inv3.remove = function(sp) inv3.items[sp.name] = (inv3.items[sp.name] or 0) - sp.count end
  surface.created = {}
  Recon.act({ entity = { get_main_inventory = function() return inv3 end } }, f3, t3, surface)
  check(gone == 2 and #surface.created == 1, "restes (corpse) de la pièce détruite retirés avant la pose")
  surface.corpses = {}
  R.RECON_ALL_PIECES = true
end


-- §11 Récolte du bois quand aucun poteau n'est fabricable (lot CORR-RECONSTRUIRE) ---------------------------------------------
do
  R.RECON_ALL_PIECES = false
  local function lost_pole()
    local f = new_team()
    local pm = ent("pole-m", "electric-pole", 80, 80)
    pm.neighbours = { copper = { { valid = true, position = { x = 86, y = 80 } } } }
    died({ entity = pm, tick = 6000 })
    f.stock["item-m"] = 0
    f.stock["item-p"] = 0
    return f
  end
  -- item-m : de l'acier (ne se coupe pas) ; item-p : du bois ; item-s : non fabricable à la main
  local function book_of(raw_of)
    return { handcraftable = function(_, it) return raw_of[it] ~= nil end,
      plan = function(_, list) return { raw = raw_of[list[1][1]] or {}, crafts = {}, uses = {} } end }
  end
  local at = 6000 + Rc.CALM_INFRA + 5
  local f = lost_pole()
  local n = Recon.craft_spares(f, book_of({ ["item-m"] = { acier = 2 }, ["item-p"] = { bois = 1 } }), {}, at)
  local t = f.team.board.tasks["recon:gather:bois"]
  check(t and t.kind == "mine" and t.resource == "bois" and t.trees == true and t.prudent == true and t.count == Rc.GATHER_BATCH,
    "aucun poteau fabricable, le bois manque : tâche de minage sur les arbres")
  check(t and t.prio == Rc.task_prio(Rc.INFRA_VALUE) and t.domain == "defense", "récolte : priorité de l'infrastructure, domaine défense")
  check(f.recon.stats.gathers == 1 and n == 0, "récolte comptée (aucune fabrication encore)")
  local lg = false
  for _, l in ipairs(logs) do if l:find("recolte de bois", 1, true) then lg = true end end
  check(lg, "récolte : journal [FO-RECON]")
  check(Recon.craft_spares(f, book_of({ ["item-m"] = { acier = 2 }, ["item-p"] = { bois = 1 } }), {}, at + 1) == 0, "récolte : pas de doublon au tableau")
  -- l'acier seul manque : récolter ne débloque rien
  local f2 = lost_pole()
  Recon.craft_spares(f2, book_of({ ["item-m"] = { acier = 2 }, ["item-p"] = { acier = 1 } }), {}, at)
  check(next(f2.team.board.tasks) == nil, "seul l'acier manque : aucune récolte")
  -- poteaux non fabricables à la main
  local f3 = lost_pole()
  Recon.craft_spares(f3, book_of({}), {}, at)
  check(next(f3.team.board.tasks) == nil, "rien de fabricable à la main : aucune récolte")
  -- règle coupée (« sans la règle » du banc)
  local f4 = lost_pole()
  Recon.GATHER = false
  Recon.craft_spares(f4, book_of({ ["item-m"] = { acier = 2 }, ["item-p"] = { bois = 1 } }), {}, at)
  Recon.GATHER = true
  check(next(f4.team.board.tasks) == nil, "règle coupée : aucune récolte (comportement d'avant)")
  -- une fois le bois au stock, le petit poteau est fabriqué à la place du moyen (récolte -> remplaçant -> fabrication)
  local f5 = lost_pole()
  local r5 = f5.recon.lost[Rc.key({ name = "pole-m", x = 80, y = 80 })]
  Recon.craft_spares(f5, { handcraftable = function(_, it) return it == "item-p" end, plan = function() return { raw = {}, crafts = { { "r", 1 } }, uses = { ["copper-plate"] = 1 } } end },
    { ["copper-plate"] = 10 }, at)
  check(r5.place == "pole-x" and f5.team.board.tasks["craft:item-p:reconstruction"], "bois récolté : le petit poteau est posé à la place et fabriqué")
  -- le remplaçant le plus « récoltable » est choisi parmi plusieurs
  local f6 = lost_pole()
  Recon.craft_spares(f6, book_of({ ["item-m"] = { bois = 4 }, ["item-p"] = { bois = 1 } }), {}, at)
  check(f6.team.board.tasks["recon:gather:bois"] and f6.team.board.tasks["recon:gather:bois"].count == Rc.GATHER_BATCH, "récolte : un seul objet, une seule tâche")
  R.RECON_ALL_PIECES = true
end



-- §4 bis Pièce refaite par un autre moyen (revue globale 1) ----------------------------------------------------------------
do
  local f = new_team()
  surface.enemies = 0
  died({ entity = ent("piece-a", "assembling-machine", 10, 10), tick = 100 })
  check(Rc.pending(f.recon) == 1, "§4bis : pièce inscrite")
  -- le plan directeur (ou le joueur) la repose : le balayage la voit en place et la retire du registre
  local there = ent("piece-a", "assembling-machine", 10, 10)
  local old_find = surface.find_entity
  surface.find_entity = function(name, pos) if name == "piece-a" and pos[1] == 10 and pos[2] == 10 then return there end return nil end
  Recon.think(f, surface, 100 + 650)
  surface.find_entity = old_find
  check(Rc.pending(f.recon) == 0 and next(f.recon.lost) == nil, "§4bis : pièce revue en place retirée du registre (plus de pièce de rechange demandée)")
  local bn = f.recon.stats.byname and f.recon.stats.byname["piece-a"]
  check(bn and bn.rec == 1 and bn.ext == 1 and bn.own == 0, "§4bis : comptée comme refaite par un autre moyen")
  -- une pièce dont un PNJ tient la tâche n'est pas retirée sous ses pieds
  local f2 = new_team()
  died({ entity = ent("piece-b", "assembling-machine", 12, 10), tick = 100 })
  local k = Rc.key({ name = "piece-b", x = 12, y = 10 })
  f2.recon.lost[k].claimed = "rebuild:x"
  f2.team.board.tasks["rebuild:x"] = { key = "rebuild:x", kind = "rebuild", worker = 3 }
  surface.find_entity = function(name) if name == "piece-b" then return ent("piece-b", "assembling-machine", 12, 10) end return nil end
  Recon.think(f2, surface, 100 + 650)
  surface.find_entity = old_find
  check(f2.recon.lost[k] ~= nil, "§4bis : pièce réclamée par un PNJ gardée (la tâche la résout)")
end

-- §12 Lot REBUILD-TOUT : le relevé des projets prend les pièces du plan, le registre garde l'infrastructure et les avant-postes ---------------
do
  R.REBUILD_SWEEP = true
  local f = new_team()
  died({ entity = ent("piece-a", "assembling-machine", 10, 10), tick = 1000 })
  check(f.recon == nil or Rc.pending(f.recon) == 0, "§12 relevé allumé : une pièce d'un projet n'est pas inscrite au registre")
  died({ entity = ent("pole-x", "electric-pole", 60, 60), tick = 1000 })
  check(Rc.pending(f.recon) == 1, "§12 relevé allumé : le poteau est inscrit")
  local drill = ent("piece-d", "mining-drill", 40, 40)
  owners[drill.unit_number] = { f = "player", kind = "drill", oid = 7 }
  died({ entity = drill, tick = 1000 })
  check(Rc.pending(f.recon) == 2, "§12 relevé allumé : la foreuse d'un avant-poste est inscrite")
  -- retrait à la main : mémorisé par le relevé
  local hand = handlers[2]
  check(hand ~= nil and handlers[3] ~= nil, "§12 l'exécutant s'abonne aux retraits du joueur et de ses robots")
  f.build.projects[1].state = "fini"
  hand({ entity = ent("piece-a", "assembling-machine", 10, 10), tick = 2000 })
  check(f.build.sweep and f.build.sweep.hand["10.0,10.0"] == 2000, "§12 pièce retirée à la main : mémorisée")
  hand({ entity = ent("piece-a", "assembling-machine", 10, 10, "scarlet"), tick = 2000 })
  check(f.build.sweep.hand_cnt == 1, "§12 une pièce d'une autre force n'est pas mémorisée")
  R.REBUILD_SWEEP = false
end

-- §5 Source -----------------------------------------------------------------------------------------------------------------
for _, file in ipairs({ "script/team/reconstruction.lua" }) do
  local fh = assert(io.open(file, "rb"))
  local src = fh:read("*a")
  fh:close()
  local code = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("[^i]pairs%(") and not code:find("math.random", 1, true), file .. " : ni pairs ni hasard")
  check(not code:find('"gun%-turret"') and not code:find('"iron%-plate"') and not code:find('"lab"'), file .. " : aucun nom du jeu")
end

print(string.format("[RECONSTRUIRE-EXEC] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
