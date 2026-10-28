--[[
  Lot COUVERTURE : exécutant hors jeu (moteur simulé réduit) de script/team/couverture.lua (choix des positions, épreuve du
  moteur, repli) et de script/team/reconstruction.lua (registre, tâches « rebuild », programme, pose, « améliorer attend »).
  Les règles pures sont dans tests/couverture_test.lua ; ici on contrôle le branchement : qui est inscrit, qui ne l'est pas,
  quand une tâche naît, ce que le PNJ pose, ce qui est restitué à l'avant-poste.
  Usage : lua5.2 tests/couverture_exec_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- Doublures --------------------------------------------------------------------------------------------------------
local handlers = {}
package.loaded["script.core.events"] = { on = function(id, fn) handlers[id] = fn end }
defines = { events = { on_entity_died = 1 }, direction = { north = 0, east = 2, south = 4, west = 6 } }
local ns = { ia3k = { teams = {} } }
package.loaded["script.core.storage"] = { ns = function(n) ns[n] = ns[n] or {}; return ns[n] end }
local player
local owners = {}
package.loaded["script.faction.state"] = {
  sorted_keys = function(t) local k = {} for key in next, t do k[#k + 1] = key end table.sort(k) return k end,
  owner = function(u) return owners[u] end,
  own = function(e, fid, kind, oid) owners[e.unit_number] = { f = fid, kind = kind, oid = oid } end,
  faction = function(id) if id == "player" then return player end end,
  by_force = function() return nil end,
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
  ["tourelle-x"] = { turret_range = 18, items_to_place_this = { { name = "tourelle-x" } } },
}
game = { tick = 0, entity_prototypes = PROTOS }

local R = require("shared.ai3.reglages")
local Rc = require("shared.team.reconstruction")
local Recon = require("script.team.reconstruction")
local Couv = require("script.team.couverture")
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
    hq = { valid = true, position = { x = 0, y = 0 }, unit_number = 1 }, stock = { ["item-a"] = 5, ["item-b"] = 5, ["item-d"] = 5 },
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
  get_tile = function() return { name = "grass-1" } end,
  can_place_entity = function() return surface.placeable end,
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
  check(#f.recon.hits == 2, "toute perte est une menace pour la couverture (2 inscrites aux coups reçus)")
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
  check(Rc.pending(f.recon) == 2, "tourelle : jamais au registre (défendre d'abord les refait), mais menace")
  local n_hits = #f.recon.hits
  died({ entity = ent("piece-a", "character", 10, 10), tick = 1005 })
  check(Rc.pending(f.recon) == 2 and #f.recon.hits == n_hits, "un personnage mort n'est ni refait ni compté")
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

-- §4 Couverture : exécutant ----------------------------------------------------------------------------------------------
do
  local f = new_team()
  f.hq.surface = surface
  local fes = {}
  local function mk(ty, x, y) local e = ent("piece-a", ty, x, y) fes[#fes + 1] = e return e end
  mk("lab", 0, 0); mk("furnace", 20, 5); mk("mining-drill", -20, 5); mk("transport-belt", 3, 3)
  local surf = {
    find_entities_filtered = function(t)
      local out = {}
      for _, e in ipairs(fes) do
        local ok = false
        for _, ty in ipairs(t.type) do if ty == e.type then ok = true end end
        if ok and (e.position.x - t.position.x) ^ 2 + (e.position.y - t.position.y) ^ 2 <= t.radius ^ 2 then out[#out + 1] = e end
      end
      return out
    end,
    can_place_entity = function(t) return not (t.position.x == 0 and t.position.y == 0) end,
  }
  PROTOS["gun-turret"] = { turret_range = 18 }
  local st = Couv.plan(f, surf, { x = 0, y = 0 }, true)
  check(st ~= nil and st.n_assets == 3, "bâtiments vus par TYPE et force : le tapis (type passif) ne compte pas (" .. tostring(st and st.n_assets) .. ")")
  local p1 = Couv.next(st, f, surf)
  local p2 = Couv.next(st, f, surf)
  check(p1 and p2 and not (p1.x == 0 and p1.y == 0) and not (p2.x == 0 and p2.y == 0), "épreuve du moteur : la place refusée n'est jamais rendue")
  check(math.sqrt((p1.x - p2.x) ^ 2 + (p1.y - p2.y) ^ 2) >= 18 * 0.4 - 1e-9, "espacement respecté")
  PROTOS["gun-turret"] = { turret_range = 0 }
  package.loaded["script.team.couverture"] = nil -- mémoire des portées neuve (elle garde la première lecture)
  local Couv0 = require("script.team.couverture")
  check(Couv0.plan(f, surf, { x = 0, y = 0 }, true) == nil, "portée inconnue : pas de plan (repli sur les positions fixes)")
  PROTOS["gun-turret"] = { turret_range = 18 }
  check(Couv.plan(f, { find_entities_filtered = function() return {} end }, { x = 500, y = 500 }, false) == nil, "rien à protéger : pas de plan")
  -- menaces : bâtiments détruits récents
  f.recon = { hits = { { x = 60, y = 0, t = game.tick } } }
  local st2 = Couv.plan(f, surf, { x = 0, y = 0 }, true)
  check(st2 and st2.n_threats == 1, "bâtiments détruits récemment : menaces de la couverture")
end

-- §4 bis Généralisation : une autre tourelle (autre nom, autre portée) et d'autres noms de pièces, mêmes règles ------------
do
  local f = new_team()
  local save = R.TURRET
  R.TURRET = "canon-lourd"
  PROTOS["canon-lourd"] = { turret_range = 30 }
  package.loaded["script.team.couverture"] = nil
  local Couv3 = require("script.team.couverture")
  local fes = { ent("piece-b", "lab", 0, 0), ent("piece-b", "furnace", 40, 0), ent("piece-b", "boiler", -40, 0) }
  local surf = { find_entities_filtered = function(t)
    local out = {}
    for _, e in ipairs(fes) do
      for _, ty in ipairs(t.type) do if ty == e.type then out[#out + 1] = e end end
    end
    return out
  end, can_place_entity = function() return true end }
  local st = Couv3.plan(f, surf, { x = 0, y = 0 }, true)
  local p1, p2 = Couv3.next(st, f, surf), Couv3.next(st, f, surf)
  check(st.range == 30 and p1 and p2, "la portée du prototype (30) décide, quel que soit le nom de la tourelle")
  check(p1 and p2 and math.sqrt((p1.x - p2.x) ^ 2 + (p1.y - p2.y) ^ 2) >= 30 * 0.4 - 1e-9, "espacement : 40 % de la portée lue (12 tuiles), pas une valeur écrite")
  R.TURRET = save
  package.loaded["script.team.couverture"] = nil
  require("script.team.couverture")
end

-- §5 Source -----------------------------------------------------------------------------------------------------------------
for _, file in ipairs({ "script/team/couverture.lua", "script/team/reconstruction.lua" }) do
  local fh = assert(io.open(file, "rb"))
  local src = fh:read("*a")
  fh:close()
  local code = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  check(not code:find("[^i]pairs%(") and not code:find("math.random", 1, true), file .. " : ni pairs ni hasard")
  check(not code:find('"gun%-turret"') and not code:find('"iron%-plate"') and not code:find('"lab"'), file .. " : aucun nom du jeu")
end

print(string.format("[COUVERTURE-EXEC] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
