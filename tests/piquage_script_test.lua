--[[
  Lot PIQUAGE : le SCRIPT (script/team/piquage.lua) joué hors jeu contre un monde fictif minimal (tapis, coffre, surface, stock). Ce n'est PAS le
  moteur : il prouve l'enchaînement relevé -> décision -> demande -> plan -> pose du répartiteur -> suivi, les causes de refus et le journal,
  avant tout banc. Les noms d'objets des données du jeu sont écrits ici (le test n'est pas une règle de décision).
    §1 relevé et décision ; §2 demande ; §3 plan (tracé, entités, preuve) ; §4 pose du répartiteur et priorité ; §5 refus (tapis mixte,
    sans répartiteur, remplacement refusé) ; §6 branchement dans build.lua (lu comme texte).
  Usage : lua5.2 tests/piquage_script_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end

---------------------------------------------------------------------------------------------------
-- Moteur fictif
---------------------------------------------------------------------------------------------------
local LOGS = {}
log = function(s) LOGS[#LOGS + 1] = s end
defines = { inventory = { chest = 1 }, direction = { north = 0, east = 2, south = 4, west = 6 } }
local IFACE = {}
remote = { add_interface = function(name, t) IFACE[name] = t end }
local FACTION = { key = "player", force = "player", engineers = {}, hq_pos = { x = -30, y = 0 } }
game = {
  tick = 0,
  forces = { player = { recipes = { ["splitter"] = { enabled = true } } } },
  item_prototypes = { X = { stack_size = 100 } },
  get_filtered_entity_prototypes = function()
    return { splitter = { items_to_place_this = { { name = "splitter" } }, belt_speed = 0.03125, has_flag = function() return false end } }
  end,
}
local STOCK = { splitter = 1, ["transport-belt"] = 0 }
local CALLS = { create = {}, bars = {} }
package.loaded["script.faction.state"] = {
  sorted_keys = function(t) local ks = {} for k in pairs(t) do ks[#ks + 1] = k end table.sort(ks) return ks end,
  faction = function() return FACTION end, alive = function() return {} end,
}
package.loaded["script.team.convoyeurs"] = {
  is_belt = function(n) return n == "transport-belt" end,
  belts = function() return { { name = "transport-belt", speed = 0.03125, item = "transport-belt" } } end,
  choose = function() return "transport-belt" end,
}
package.loaded["script.team.stock"] = {
  count = function(_, it) return STOCK[it] or 0 end,
  remove = function(_, it, n) STOCK[it] = (STOCK[it] or 0) - n return n end,
  insert = function(_, it, n) STOCK[it] = (STOCK[it] or 0) + n return n end,
}
package.loaded["script.ai3.reserve"] = { on = function() return true end }
package.loaded["script.companion.registry"] = { get = function() return nil end }

local ENTS = {}
local function box(e)
  local w, h = e.w or 1, e.h or 1
  return { left_top = { x = e.position.x - w / 2, y = e.position.y - h / 2 }, right_bottom = { x = e.position.x + w / 2, y = e.position.y + h / 2 } }
end
local function new_ent(name, typ, px, py, dir, extra)
  local e = { name = name, type = typ, position = { x = px, y = py }, direction = dir or 0, force = { name = "player" }, valid = true, w = 1, h = 1 }
  for _, k in ipairs({ "w", "h", "count" }) do if extra and extra[k] then e[k] = extra[k] end end
  e.bounding_box = box(e)
  ENTS[#ENTS + 1] = e
  return e
end
local LINES = {} -- entité -> { [1] = contenu, [2] = contenu }
local function belt(tx, ty, dir, c1, c2)
  local e = new_ent("transport-belt", "transport-belt", tx + 0.5, ty + 0.5, dir)
  LINES[e] = { c1 or {}, c2 or {} }
  e.get_transport_line = function(i) return { get_contents = function() return LINES[e][i] end } end
  return e
end
local DV = { [0] = { 0, -1 }, [2] = { 1, 0 }, [4] = { 0, 1 }, [6] = { -1, 0 } }
local function link_belts()
  for _, e in ipairs(ENTS) do
    if e.type == "transport-belt" then
      e.belt_neighbours = { inputs = {}, outputs = {} }
    end
  end
  for _, e in ipairs(ENTS) do
    if e.type == "transport-belt" and e.valid then
      local v = DV[e.direction]
      for _, o in ipairs(ENTS) do
        if o ~= e and o.valid and o.type == "transport-belt" and o.position.x == e.position.x + v[1] and o.position.y == e.position.y + v[2] then
          e.belt_neighbours.outputs[#e.belt_neighbours.outputs + 1] = o
          o.belt_neighbours.inputs[#o.belt_neighbours.inputs + 1] = e
        end
      end
    end
  end
end

local function in_box(px, py, b, r) return px >= b.left_top.x - r and px <= b.right_bottom.x + r and py >= b.left_top.y - r and py <= b.right_bottom.y + r end
local function name_ok(f, name) if f == nil then return true end if type(f) == "string" then return f == name end for _, n in ipairs(f) do if n == name then return true end end return false end
local SURF = {}
SURF.find_entities_filtered = function(t)
  local out = {}
  for _, e in ipairs(ENTS) do
    if e.valid and name_ok(t.name, e.name) and name_ok(t.type, e.type) and (t.force == nil or e.force.name == t.force) then
      local hit
      if t.position then
        hit = in_box(t.position.x or t.position[1], t.position.y or t.position[2], e.bounding_box, (t.radius or 0) - 0.5 > 0 and (t.radius - 0.5) or 0)
      elseif t.area then
        local a = t.area
        local b = e.bounding_box
        hit = not (b.right_bottom.x <= a[1][1] or b.left_top.x >= a[2][1] or b.right_bottom.y <= a[1][2] or b.left_top.y >= a[2][2])
      end
      if hit then out[#out + 1] = e end
    end
  end
  if t.limit then while #out > t.limit do out[#out] = nil end end
  return out
end
SURF.get_tile = function() return { valid = true, collides_with = function() return false end } end
SURF.find_nearest_enemy = function() return nil end
local CAN_FR = true
SURF.can_fast_replace = function() return CAN_FR end
SURF.create_entity = function(t)
  CALLS.create[#CALLS.create + 1] = t
  if not t.fast_replace then return nil end
  -- remplace le tapis dont la tuile contient (x - 0,5 .. ) : l'une des deux moitiés du répartiteur
  local ex, ey = t.position.x or t.position[1], t.position.y or t.position[2]
  local horiz = (t.direction == 0 or t.direction == 4)
  local victims = {}
  for _, e in ipairs(ENTS) do
    if e.valid and e.type == "transport-belt" then
      local dx, dy = math.abs(e.position.x - ex), math.abs(e.position.y - ey)
      if (horiz and dx <= 0.5 and dy <= 0.5) or ((not horiz) and dy <= 0.5 and dx <= 0.5) then victims[#victims + 1] = e end
    end
  end
  for _, v in ipairs(victims) do v.valid = false end
  local sp = new_ent(t.name, "splitter", ex, ey, t.direction, { w = horiz and 2 or 1, h = horiz and 1 or 2 })
  sp.splitter_output_priority = "none"
  return sp
end

local function chest(tx, ty, n)
  local e = new_ent("iron-chest", "container", tx + 0.5, ty + 0.5, 0)
  e.get_item_count = function() return n end
  e.get_inventory = function()
    return { supports_bar = function() return true end, get_bar = function() return CALLS.bar or 99 end,
      set_bar = function(v) CALLS.bar = v; CALLS.bars[#CALLS.bars + 1] = v end }
  end
  return e
end

---------------------------------------------------------------------------------------------------
-- Monde : un tapis horizontal plein de X au nord du quai, un coffre de quai au sud
---------------------------------------------------------------------------------------------------
for x = 0, 40 do belt(x, 10, 2, { X = 4 }, { X = 4 }) end
chest(20, 14, 10)
-- la tête d'alimentation du quai (tapis du PLAN, tuile réservée) porte aussi l'objet, dense : elle ne doit jamais être piquée
for x = 21, 23 do belt(x, 16, 2, { X = 4 }, { X = 4 }) end
-- une ligne de liaison FINIE (tuiles du plan, réservées) : ses tapis sont des sources pour les autres quais ; sa tuile (19,10) est celle que le piquage remplacera
for x = 21, 23 do belt(x, 18, 2, { X = 4 }, { X = 4 }) end
-- lignes d'un AUTRE projet fini du plan (rôle « tapis » : source ; rôle « tete » : jamais) et du projet du quai lui-même (jamais)
for x = 22, 24 do belt(x, 13, 2, { X = 4 }, { X = 4 }) end
for x = 25, 27 do belt(x, 13, 2, { X = 4 }, { X = 4 }) end
for x = 16, 18 do belt(x, 13, 2, { X = 4 }, { X = 4 }) end
link_belts()
local Pq = require("shared.team.piquage")
local Li = require("shared.team.liaison")
local P = require("shared.team.plan")
local Piquage = require("script.team.piquage")

local B = { occ = { [P.tkey(21, 16)] = 1, [P.tkey(22, 16)] = 1, [P.tkey(23, 16)] = 1 }, order = { 1 }, projects = {}, lat = P.lattice({ x = 0, y = 0 }), stats = { filled = 0 }, next_id = 2 }
local PROJ1 = { id = 1, state = "fini", spec = { gen = "x", names = { arm = "inserter", pole = "small-electric-pole" } }, parts = { { kind = "module" } }, quais = { { x = 20.5, y = 14.5, item = "X" } }, outs = {}, ents = {},
  inflow = { X = 1.0 }, tapis_piquable = { { x = 23, y = 16, item = "X" }, { x = 22, y = 16, item = "Y" } } }
B.projects[1] = PROJ1
local PROJL = { id = 5, state = "fini", spec = { liaison = { item = "X" } }, parts = {}, quais = {}, outs = {}, ents = {
  { name = "transport-belt", x = 19.5, y = 10.5, dir = 2, role = "liaison-tapis", built = true },
  { name = "transport-belt", x = 21.5, y = 18.5, dir = 2, role = "liaison-tapis", built = true },
  { name = "transport-belt", x = 22.5, y = 18.5, dir = 2, role = "liaison-tapis", built = true } } }
B.projects[5] = PROJL
local PROJM = { id = 6, state = "fini", spec = { gen = "y" }, parts = {}, quais = {}, outs = {}, ents = {} }
for x = 22, 24 do PROJM.ents[#PROJM.ents + 1] = { name = "transport-belt", x = x + 0.5, y = 13.5, dir = 2, role = "tapis", built = true } end
for x = 25, 27 do PROJM.ents[#PROJM.ents + 1] = { name = "transport-belt", x = x + 0.5, y = 13.5, dir = 2, role = "tete", built = true } end
for x = 16, 18 do PROJ1.ents[#PROJ1.ents + 1] = { name = "transport-belt", x = x + 0.5, y = 13.5, dir = 2, role = "tapis", built = true } end
B.projects[6] = PROJM
B.order[#B.order + 1] = 6
for x = 16, 27 do B.occ[P.tkey(x, 13)] = 6 end
B.order[#B.order + 1] = 5
B.occ[P.tkey(21, 18)], B.occ[P.tkey(22, 18)], B.occ[P.tkey(23, 18)] = 5, 5, 5
FACTION.build = B

local REQ = {}
local API = { prio = 56, fill = 400, low = 60, request = function(f, spec)
  local id = B.next_id
  B.next_id = id + 1
  local p = { id = id, spec = spec, state = "attente", parts = {}, ents = {}, quais = {}, outs = {}, obstacles = {}, stock = {} }
  B.projects[id] = p
  B.order[#B.order + 1] = id
  REQ[#REQ + 1] = { id = id, spec = spec }
  return id
end }
IFACE["fo-piquage"].set_param("player", "sans_centrale", true)
IFACE["fo-piquage"].set_param("player", "period", 1)

local TICK = 0
local function cycle()
  TICK = TICK + 1800
  game.tick = TICK
  local calls = 0
  Piquage.step(API, FACTION, SURF, TICK) -- ouvre le cycle
  while B.piquage.cyc and calls < 20 do Piquage.step(API, FACTION, SURF, TICK); calls = calls + 1 end
end
local function has_log(pattern)
  for _, l in ipairs(LOGS) do if l:find(pattern) then return l end end
  return nil
end

---------------------------------------------------------------------------------------------------
-- §1 relevé et décision
---------------------------------------------------------------------------------------------------
cycle() -- découverte
local tr = B.piquage.track["1:q1"]
check(tr and #tr.order == Piquage.MAX_TRACK, "1.1 découverte : " .. Piquage.MAX_TRACK .. " tuiles suivies, les plus proches du quai")
check(tr and tr.tiles["21:16"] == nil and tr.tiles["22:16"] == nil, "1.1 bis les tapis du plan (tuiles réservées) ne sont pas suivis")
check(tr and tr.tiles["21:18"] ~= nil and tr.tiles["22:18"] ~= nil and tr.tiles["23:18"] == nil, "1.1 quater les tapis d'une liaison finie (tuiles du plan) sont des sources, pas ceux qu'elle ne déclare pas")
check(tr and tr.tiles["22:13"] ~= nil and tr.tiles["25:13"] == nil and tr.tiles["16:13"] == nil,
  "1.1 quinquies les lignes d'un autre projet fini sont des sources (22:13), pas ses têtes d'alimentation (25:13) ni les tapis du projet du quai (16:13)")
check(tr and tr.tiles["23:16"] ~= nil, "1.1 ter un tapis du plan déclaré piquable par son projet (p.tapis_piquable) pour CET objet est suivi, pas pour un autre")
check(tr and tr.tiles["20:10"] ~= nil and tr.tiles["20:10"].obs.n == 1 and tr.tiles["20:10"].obs.dense == 1, "1.2 la tuile en face du quai est suivie, 1 relevé dense")
cycle()
cycle() -- 3 relevés : candidate
check(#REQ == 0, "1.3 aucune demande avant la confirmation : " .. #REQ)
check(has_log("attendre : a confirmer") ~= nil, "1.4 journal : à confirmer")
cycle()
if os.getenv("PQ_DEBUG") == "1" then for _, l in ipairs(LOGS) do print(l) end end
check(#REQ == 1, "2.1 une demande de projet après confirmation : " .. #REQ)
local lc = REQ[1] and REQ[1].spec.liaison
check(lc and lc.piquage == true and lc.item == "X" and lc.split == "splitter" and lc.extra.item == "splitter", "2.2 spec : liaison.piquage, répartiteur et son objet lus aux données")
check(lc and lc.geo.dir == 2 and lc.geo.priority ~= lc.geo.side and (lc.geo.priority == "left" or lc.geo.priority == "right"), "2.3 géométrie et priorité écrites au projet")
check(REQ[1] and REQ[1].spec.prio == 56 and REQ[1].spec.pile == "capital" and REQ[1].spec.domain == "infrastructures", "2.4 même famille que la liaison (pile capital)")
check(has_log("%[FO%-PIQUAGE%] player : quai 1:q1 %(X, 1%.00/s, a [%d]+ tuiles du QG%) : piquage demande : projet 2") ~= nil, "2.5 journal : piquage demande")
local seen_bilan = has_log("%[FO%-PIQUAGE%] player : bilan : quais d'entree 1,")
check(seen_bilan ~= nil, "2.6 journal : bilan avec tournées fill")
local Q = B.piquage.quais["1:q1"]
check(Q and Q.verdict == "demande" and Q.cause == "ok" and type(Q.tick) == "number", "2.6 bis état lisible : b.piquage.quais[\"1:q1\"] = demande/ok")
check(B.piquage.bilan.quais == 1 and B.piquage.bilan.tournees == 0, "2.6 ter état lisible : b.piquage.bilan")
cycle()
check(#REQ == 1, "2.7 pas de seconde demande pour le même quai tant que la première vit : " .. #REQ)

---------------------------------------------------------------------------------------------------
-- §3 plan
---------------------------------------------------------------------------------------------------
local P2 = B.projects[2]
local PLAN_API = {
  read_masks = function(x0, y0, x1, y1) return { water = {}, blocked = { [P.tkey(20, 14)] = true }, clear = {} } end,
  reserve_tiles = function(b, p, ents) for _, e in ipairs(ents) do p.ents[#p.ents + 1] = e end return true end,
  wood_of = function() return {} end, free_spot = function(b, masks, x, y) return x, y end,
  add_obstacle = function(p, o) p.obstacles[#p.obstacles + 1] = o end, item_of = function(name) return name end,
  seg_passable = function() return function() return true end end, REACH = 10,
  -- lot COLONNES : le tracé des lignes de rapatriement et de liaison (règle pure Tv.route), souterrains de portée 5, sans gisement
  trav = { route = function(f, surface, p, s, t, td, bounds, cost, o)
    local tiles, info, st = require("shared.team.traversee").route(s, t, td, bounds, cost, { maxd = 5, sd = o.sd, weight = o.weight, max = o.max, no_detour = o.no_detour,
      phase_slice = o.phase_slice, phase_state = o.phase_state }) -- (lot PIQUAGE-COUT : les tranches passent comme dans Trav.route)
    if not tiles then return nil, info, st end
    return tiles, info, { ug = "UG", maxd = 5 }
  end },
}
game.tick = game.tick + 1
local ok_plan, why_plan = Piquage.plan(PLAN_API, FACTION, SURF, P2)
check(ok_plan == true, "3.1 le plan réussit" .. (ok_plan and "" or (" : " .. tostring(why_plan))))
local nb, na, np = 0, 0, 0
for _, e in ipairs(P2.ents) do
  if e.role == "liaison-tapis" then nb = nb + 1 elseif e.role == "liaison-bras" then na = na + 1 elseif e.role == "liaison" then np = np + 1 end
end
check(nb >= 1 and na == 1 and np == 1, string.format("3.2 entités : %d tapis, %d bras, %d poteau", nb, na, np))
local g = lc and lc.geo
local on_world = false
for _, e in ipairs(P2.ents) do
  local tx, ty = math.floor(e.x), math.floor(e.y)
  if ty == 10 and tx >= 0 and tx <= 40 then on_world = true end -- jamais sur le tapis existant
  if tx == g.side_tile.x and ty == g.side_tile.y then on_world = true end
  if tx == g.tile.x and ty == g.tile.y then on_world = true end
end
check(not on_world, "3.3 aucune pièce sur le tapis existant ni sur la tuile latérale du répartiteur")
local first
for _, e in ipairs(P2.ents) do if e.role == "liaison-tapis" and math.floor(e.x) == g.branch.x and math.floor(e.y) == g.branch.y then first = e end end
check(first ~= nil, "3.4 un tapis part de la sortie du répartiteur")
check(has_log("projet 2 planifie %(quai 1:q1, X%)") ~= nil, "3.5 journal : projet planifié")
-- le répartiteur est compté aux besoins du projet (build.lua, needs_of, lu comme texte) : voir §6
-- anti-doublon avec la liaison : la ligne à poser dans finish_cycle de script/team/liaison.lua (à l'intégration) est
--   for _, d in ipairs(c.docks) do d.linked = st.links[d.key] ~= nil or (b.piquage ~= nil and b.piquage.links[d.key] ~= nil) end
-- Preuve : les clés de b.piquage.links sont celles des quais de la liaison (pid:qN), et un quai ainsi marqué n'est plus apparié (Li.pairs).
do
  local key = next(B.piquage.links)
  check(key == "1:q1" and key == (PROJ1.id .. ":q" .. 1), "3.0 la clé de b.piquage.links est celle des quais de la liaison (pid:qN)")
  local b_sim = B
  local dock = { key = key, pid = 1, x = 20, y = 14, item = "X", flow = 1.0 }
  local src = { key = "9:o1", pid = 9, x = 25, y = 14, item = "X" }
  dock.linked = (({})[key] ~= nil) or (b_sim.piquage ~= nil and b_sim.piquage.links[dock.key] ~= nil) -- (st.links de la liaison vide ici)
  check(dock.linked == true and #Li.pairs({ dock }, { src }) == 0, "3.0 bis un quai déjà piqué n'est pas apparié par la liaison")
  dock.linked = (({})[key] ~= nil) or (b_sim.piquage ~= nil and b_sim.piquage.links["7:q9"] ~= nil)
  check(dock.linked == false and #Li.pairs({ dock }, { src }) == 1, "3.0 ter un quai non piqué reste apparié")
end
-- COÛT BORNÉ : une seule recherche par appel et par tick, sans gisement ni détour (lot COLONNES : le tracé de Trav.route, souterrains compris)
do
  local called = 0
  local api2 = {}
  for k, v in pairs(PLAN_API) do api2[k] = v end
  local seen_o
  api2.trav = { route = function(f, surface, p, s, t, td, bounds, cost, o) called = called + 1; seen_o = o return PLAN_API.trav.route(f, surface, p, s, t, td, bounds, cost, o) end }
  P2.abandoned = true -- (le projet 2 planifié plus haut ne doit pas compter comme tapis voisin dans ce second plan)
  game.tick = game.tick + 1
  local p4 = { id = 11, spec = REQ[1].spec, ents = {}, parts = {}, obstacles = {} }
  local ok4, w4 = Piquage.plan(api2, FACTION, SURF, p4)
  check(ok4 == true and called == 1 and seen_o and seen_o.no_ore and seen_o.no_detour and seen_o.max == Piquage.ROUTE_NODES,
    "3.7 le plan réussit en UNE recherche de Trav.route, sans gisement ni détour, noeuds plafonnés (appels : " .. called .. ")" .. (ok4 and "" or (" : " .. tostring(w4))))
  local p5 = { id = 12, spec = REQ[1].spec, ents = {}, parts = {}, obstacles = {} }
  local ok5, w5, wait5 = Piquage.plan(api2, FACTION, SURF, p5) -- même tick : pas de seconde recherche
  check(ok5 == false and wait5 == "calcul" and tostring(w5):find("une recherche de branche par tick", 1, true),
    "3.8 une seule recherche de branche par tick : la seconde attend (« calcul », le projet reprend au passage suivant)")
  game.tick = game.tick + 1
  local ok6 = Piquage.plan(api2, FACTION, SURF, p5)
  check(ok6 == true, "3.9 le passage suivant planifie")
  P2.abandoned = nil
end
-- plan refusé si le tapis source a disparu
do
  local keep
  for _, e in ipairs(ENTS) do if e.valid and e.type == "transport-belt" and math.floor(e.position.x) == g.tile.x and math.floor(e.position.y) == g.tile.y then keep = e end end
  keep.valid = false
  local p3 = { id = 9, spec = REQ[1].spec, ents = {}, parts = {}, obstacles = {} }
  game.tick = game.tick + 1
  local ok3, w3 = Piquage.plan(PLAN_API, FACTION, SURF, p3)
  check(ok3 == false and tostring(w3):find("tapis source disparu", 1, true), "3.6 tapis source disparu : plan refusé, cause écrite (" .. tostring(w3) .. ")")
  keep.valid = true
end

---------------------------------------------------------------------------------------------------
-- §4 pose du répartiteur et priorité
---------------------------------------------------------------------------------------------------
P2.state, P2.wired = "fini", 2
STOCK.splitter, STOCK["transport-belt"] = 1, 0
cycle()
check(#CALLS.create == 1 and CALLS.create[1].name == "splitter" and CALLS.create[1].fast_replace == true and CALLS.create[1].spill == false,
  "4.1 un remplacement sur place demandé au moteur : " .. #CALLS.create)
check(CALLS.create[1] and (CALLS.create[1].position[1] or CALLS.create[1].position.x) == g.x and (CALLS.create[1].position[2] or CALLS.create[1].position.y) == g.y and CALLS.create[1].direction == g.dir, "4.2 position et sens du répartiteur = géométrie de la règle")
local sp
for _, e in ipairs(ENTS) do if e.name == "splitter" and e.valid then sp = e end end
check(sp and sp.splitter_output_priority == g.priority, "4.3 priorité de sortie écrite sur le tapis PRINCIPAL : " .. tostring(sp and sp.splitter_output_priority))
check(STOCK.splitter == 0 and STOCK["transport-belt"] == 1, "4.4 stock : répartiteur consommé, tapis remplacé rendu")
local n_adopted, adopted = 0, nil
for _, q in ipairs({ PROJ1, PROJL, PROJM }) do
  for _, e in ipairs(q.ents) do if e.piq then n_adopted = n_adopted + 1; adopted = e end end
end
check(n_adopted == 1 and adopted.name == "splitter" and adopted.item == "splitter" and adopted.x == g.x and adopted.y == g.y and adopted.dir == g.dir,
  "4.4 bis la pièce de tapis remplacée dans le plan du projet propriétaire devient « répartiteur » (sinon la reconstruction la referait) : " .. n_adopted)
check(#PROJL.ents == 3 and #PROJM.ents == 6, "4.4 ter aucune autre pièce de plan n'est ajoutée ni retirée")
check(P2.piq_placed == true, "4.5 le projet sait que le répartiteur est posé (plus de besoin)")
check(has_log("repartiteur pose : sur le tapis") ~= nil, "4.6 journal : repartiteur pose")
check(CALLS.bar ~= nil and CALLS.bar == Li.bar(400, 100), "4.7 barre du coffre d'entrée posée")
check(has_log("branche finie") ~= nil, "4.8 journal : branche finie")
cycle()
check(#CALLS.create == 1, "4.9 pas de seconde pose quand le répartiteur est là")
-- priorité remise si quelqu'un la change
sp.splitter_output_priority = "none"
cycle()
check(sp.splitter_output_priority == g.priority, "4.10 priorité relue et remise à chaque relevé")
check(has_log("piquage ne livre pas") ~= nil or has_log("piquage actif") ~= nil, "4.11 journal : livraison constatée ou non")
do
  local q = B.piquage.quais["1:q1"]
  local VALID_V, VALID_C = {}, {}
  for _, v in ipairs(Pq.VERDICT_CODES) do VALID_V[v] = true end
  for _, v in ipairs(Pq.CAUSE_CODES) do VALID_C[v] = true end
  local all = true
  for k, e in pairs(B.piquage.quais) do if not (VALID_V[e.verdict] and VALID_C[e.cause]) then all = false end end
  check(q ~= nil and all, "4.12 chaque verdict et chaque cause de l'état est un mot fixe de la liste de la règle")
end

---------------------------------------------------------------------------------------------------
-- §5 refus
---------------------------------------------------------------------------------------------------
do
  -- répartiteur absent du coffre : attend, ne consomme pas d'essai
  local sp0 = sp
  sp0.valid = false
  local b1 = ENTS[1]
  -- un tapis rétabli à la place du répartiteur
  local rebuilt = belt(g.tile.x, g.tile.y, g.dir, { X = 4 }, { X = 4 })
  link_belts()
  STOCK.splitter = 0
  local before = #CALLS.create
  cycle()
  check(#CALLS.create == before and has_log("attendre : repartiteur : aucun repartiteur au coffre") ~= nil, "5.1 sans répartiteur au coffre : attend, cause écrite")
  CAN_FR = false
  STOCK.splitter = 1
  for _ = 1, Piquage.SPLIT_TRIES + 1 do cycle() end
  check(#CALLS.create == before, "5.2 remplacement refusé par le moteur : aucune pose forcée")
  check(has_log("coupe : %d+ pose%(s%) du repartiteur refusee%(s%)") ~= nil, "5.3 après les essais : coupé, la branche reste inerte, le PNJ continue")
  -- s40 p10 : le répartiteur réapparaît après la coupe : la branche revit (verdict de livraison, plus « coupe »), puis l'état du test est remis
  do
    local lk = B.piquage.links["1:q1"]
    check(lk ~= nil and lk.cut == true, "5.3 bis le lien est coupé")
    sp0.valid = true
    cycle()
    local qv = B.piquage.quais["1:q1"]
    check(lk.cut == nil and lk.split == true and lk.split_tries == 0, "5.3 ter répartiteur constaté en place : la coupe est levée")
    check(qv and (qv.verdict == "actif" or qv.verdict == "inerte"), "5.3 quater le verdict redevient celui de la livraison : " .. tostring(qv and qv.verdict))
    sp0.valid = false
    lk.cut, lk.split_tries = true, Piquage.SPLIT_TRIES
  end
  CAN_FR = true
  rebuilt.valid = true
end
do
  -- tapis mixte : un deuxième objet sur la tuile
  local c = B.piquage
  local tile = c.track["1:q1"] and c.track["1:q1"].tiles["20:10"]
  check(tile ~= nil, "5.4 tuile suivie")
  local obs = Pq.observe(Pq.observe(Pq.observe(nil, { count = 8, other = 0 }), { count = 8, other = 3 }), { count = 8, other = 0 })
  check(Pq.tile_verdict({ obs = obs, shape = "straight", back = true, front = true }) == false, "5.5 la règle refuse un tapis où un autre objet a été vu")
end

---------------------------------------------------------------------------------------------------
-- §7 pire cas BORNÉ (instructions de la machine virtuelle, jamais le temps : os.clock est trop gros et dépend de la charge du PC)
---------------------------------------------------------------------------------------------------
local BUDGET = 300000 -- instructions du A* d'un appel de Piquage.plan : de l'ordre de 5 ms (cible du lead, ~60 millions d'instructions par seconde)
local PASSES = 60     -- appels au plus d'un même plan dans ce test (une tranche par appel ; au-delà : la recherche ne finit pas)
belt(58, -30, 2, { X = 4 }, { X = 4 })
link_belts()
local function far_project(id)
  local c = {}
  for k, v in pairs(REQ[1].spec.liaison) do c[k] = v end
  c.geo, c.site_i = Pq.geometry(58, -30, 2, "right"), 1
  return { id = id, spec = { liaison = c }, ents = {}, parts = {}, obstacles = {} }
end
local WALL_API = {}
for k, v in pairs(PLAN_API) do WALL_API[k] = v end
WALL_API.read_masks = function()
  local blocked = { [P.tkey(20, 14)] = true }
  for y = -80, 80 do blocked[P.tkey(40, y)] = true end -- un mur sans passage entre le tapis source et le quai : la recherche explore tout ce qu'elle peut
  return { water = {}, blocked = blocked, clear = {} }
end
-- instructions du seul A* (le tracé de l'API enveloppé) : le reste du plan dépend du moteur fictif de ce test, pas du mod.
-- Lot PIQUAGE-COUT : le tracé se fait par tranches, une par appel (« calcul ») : le plan est rappelé au tick suivant jusqu'au verdict.
-- Rend le pire APPEL (le coût d'une pensée), ok, raison, le total de la recherche, le nombre d'appels, le tracé rendu (nil : aucun).
local function instructions(mod, api, p)
  local worst, total, passes, route = 0, 0, 0, nil
  local real = api.trav.route
  api.trav.route = function(...)
    local m = 0
    debug.sethook(function() m = m + 1000 end, "", 1000)
    local a, b, c = real(...)
    debug.sethook()
    if m > worst then worst = m end
    total = total + m
    if type(a) == "table" then route = a end
    return a, b, c
  end
  local ok, why, wait
  repeat
    game.tick = game.tick + 1
    passes = passes + 1
    ok, why, wait = mod.plan(api, FACTION, SURF, p)
  until wait ~= "calcul" or passes >= PASSES
  api.trav.route = real
  return worst, ok, why, total, passes, route
end
do
  local n, ok, why, tot, np = instructions(Piquage, WALL_API, far_project(30))
  check(ok == false and (tostring(why):find("aucun chemin", 1, true) or tostring(why):find("trop long", 1, true)),
    "7.1 mur sans passage : refus en " .. np .. " pensée(s), cause écrite (" .. tostring(why) .. ")")
  check(n <= BUDGET, string.format("7.2 pire cas (boîte de 52 x 54, aucun chemin) : A* %d instructions par pensée <= %d (total %d en %d pensées)", n, BUDGET, tot, np))
  local n2, ok2, _w2, tot2, np2 = instructions(Piquage, PLAN_API, far_project(31))
  check(n2 <= BUDGET, string.format("7.3 cas sans obstacle : %d instructions par pensée <= %d (total %d en %d pensées)", n2, BUDGET, tot2, np2))
  check(tot <= 3 * BUDGET and np <= 8, string.format("7.5 recherche entière bornée (ROUTE_NODES par recherche, deux recherches) : %d instructions, %d pensées", tot, np))
  check(Piquage.ROUTE_WEIGHT == 1.4 and Piquage.ROUTE_NODES <= 1000, "7.4 A* pondéré à 1,4, noeuds plafonnés (" .. Piquage.ROUTE_NODES .. ")")
  -- mutants du script : le plafond de noeuds retiré, le garde « une recherche par tick » retiré
  local SRC_S = read("script/team/piquage.lua")
  local function load_script(src) local fn, err = load(src, "=piquage_script", "t"); assert(fn, err); return fn() end
  local function smut(name, from, to, probe)
    local src, cnt = SRC_S:gsub(from, to, 1)
    if cnt == 0 then check(false, "mutant " .. name .. " : motif introuvable") return end
    local okl, Pm = pcall(load_script, src)
    if not okl then check(true, "mutant " .. name .. " (ne se charge pas)") return end
    local okp, seen = pcall(probe, Pm)
    check(not okp or seen, "mutant " .. name .. " vu")
  end
  smut("plafond de noeuds retiré", "Piquage%.ROUTE_NODES = 300", "Piquage.ROUTE_NODES = 1000000000",
    function(Pm) local _, _, _, t = instructions(Pm, WALL_API, far_project(32)); return t > 3 * BUDGET end)
  smut("heuristique non pondérée à noeuds illimités", "max = Piquage%.ROUTE_NODES", "max = 1000000000",
    function(Pm) local _, _, _, t = instructions(Pm, WALL_API, far_project(33)); return t > 3 * BUDGET end)
  -- lot PIQUAGE-COUT : la tranche retirée rend les deux recherches d'un tenant (619 000 instructions mesurées) ; l'état de reprise jeté fait
  -- recommencer la recherche à chaque pensée (elle ne finit jamais)
  smut("tranche retirée", "phase_slice = Piquage%.ROUTE_SLICE", "phase_slice = nil",
    function(Pm) local m = instructions(Pm, WALL_API, far_project(40)); return m > BUDGET end)
  smut("état de reprise jeté", "phase_state = rs and rs%.st or nil", "phase_state = nil",
    function(Pm) local _, _, _, _, k = instructions(Pm, WALL_API, far_project(41)); return k >= PASSES end)
  smut("garde une recherche par tick retiré", "if LAST_SEARCH == game%.tick then", "if false then",
    function(Pm)
      game.tick = game.tick + 1
      Pm.plan(PLAN_API, FACTION, SURF, far_project(34))
      -- même tick : sans le garde, la seconde recherche part (lot PIQUAGE-COUT : une recherche par tranches rend aussi « calcul », la raison les distingue)
      local _, w = Pm.plan(PLAN_API, FACTION, SURF, far_project(35))
      return not tostring(w):find("une recherche de branche par tick", 1, true)
    end)
  -- 7.6 lot PIQUAGE-COUT : le MÊME tracé, par tranches ou d'un tenant. Plafond porté à 5 000 états (les deux scripts) : la recherche de tuiles
  -- échoue contre le mur, celle des paires souterraines le franchit après des dizaines de tranches
  do
    local function sig_of(r)
      local t = {}
      for _, e in ipairs(r or {}) do t[#t + 1] = string.format("%d:%d:%d:%s", e.x, e.y, e.dir, tostring(e.ug)) end
      return table.concat(t, ";")
    end
    local big = SRC_S:gsub("Piquage%.ROUTE_NODES = 300", "Piquage.ROUTE_NODES = 5000", 1)
    local whole = big:gsub("phase_slice = Piquage%.ROUTE_SLICE", "phase_slice = nil", 1)
    local pa, pb = far_project(42), far_project(43)
    local wa, oka, ya, _ta, na, ra = instructions(load_script(big), WALL_API, pa)
    local wb, okb, yb, _tb, nb2, rb = instructions(load_script(whole), WALL_API, pb)
    local ug = 0
    for _, e in ipairs(ra or {}) do if e.ug then ug = ug + 1 end end
    check(na > 4 and nb2 == 1 and ra ~= nil and ug >= 2 and sig_of(ra) == sig_of(rb) and oka == okb and ya == yb and pa.rs_piq == nil,
      string.format("7.6 même tracé (%d tuiles, %d pièces souterraines) par tranches (%d pensées, %d instructions au pire) que d'un tenant (%d) ; même verdict (%s)",
        ra and #ra or 0, ug, na, wa, wb, tostring(ya)))
  end
  smut("plusieurs sites essayés", "local site = sites%[%(%(lc%.site_i or 1%) %- 1%) %% #sites %+ 1%]", "local site = sites[1]",
    function(Pm)
      P2.abandoned = true
      local function near(id, si)
        local c = {}
        for k, v in pairs(REQ[1].spec.liaison) do c[k] = v end
        c.site_i = si
        return { id = id, spec = { liaison = c }, ents = {}, parts = {}, obstacles = {} }
      end
      local function arm_of(p) for _, e in ipairs(p.ents) do if e.role == "liaison-bras" then return e end end end
      game.tick = game.tick + 1
      local pa = near(37, 1); Pm.plan(PLAN_API, FACTION, SURF, pa)
      game.tick = game.tick + 1
      local pb = near(38, 2); Pm.plan(PLAN_API, FACTION, SURF, pb)
      P2.abandoned = nil
      local a, b = arm_of(pa), arm_of(pb)
      return a ~= nil and b ~= nil and a.x == b.x and a.y == b.y
    end)
end

---------------------------------------------------------------------------------------------------
-- §6 branchement (lu comme texte)
---------------------------------------------------------------------------------------------------
local BUILD = read("script/team/build.lua")
check(BUILD:find('Build%.Piquage = require%("script%.team%.piquage"%)') ~= nil, "6.1 build.lua : le module est un champ de Build (pas une locale)")
check(BUILD:find("if spec%.liaison and spec%.liaison%.piquage then return Build%.Piquage%.plan%(") ~= nil, "6.2 plan_project : le piquage a son plan")
check(BUILD:find("Build%.Piquage%.step%(") ~= nil, "6.3 pulse_team : le relevé du piquage tourne avec celui de la liaison")
check(BUILD:find("lq%.extra and not p%.piq_placed then bump%(need, lq%.extra%.item%)") ~= nil, "6.4 needs_of : le répartiteur est un besoin du projet jusqu'à sa pose")
check(BUILD:find("q%.tours, q%.filled = ") ~= nil, "6.5 la tournée « fill » est comptée par quai")
local SCRIPT = read("script/team/piquage.lua")
local code_s = SCRIPT:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
local n_pairs = 0
for _ in code_s:gmatch("[^i%.]pairs%(") do n_pairs = n_pairs + 1 end
check(n_pairs == 2, "6.6 pairs seulement dans sorted_keys et dans la lecture triée des prototypes : " .. n_pairs)
local state_block = SCRIPT:match("local function new_state%(.-\nend")
check(state_block ~= nil and not state_block:find("function%s*%("), "6.7 l'état b.piquage ne garde aucune fonction")
check(not code_s:find("os%.clock") and not code_s:find("math%.random") and not code_s:find("math%.sin"), "6.8 ni horloge mesurée, ni hasard, ni trigonométrie")
check(not code_s:find("global") , "6.9 le script ne nomme pas global")

-- §7 (s40 p7) tour de découverte : les quais dus les plus anciens d'abord, jamais les mêmes quais de tête
do
  local dus = {}
  for i = 1, 5 do dus[i] = { key = "q" .. i, last = 100 } end
  dus[4].last = nil; dus[5].last = 50
  local t = Piquage.discover_turn(dus, 3)
  check(t.q4 and t.q5 and t.q1 and not t.q2 and not t.q3, "7.1 jamais decouvert, puis le plus ancien, puis l'ordre du debit")
  local n = 0
  for _ in pairs(Piquage.discover_turn(dus, 9)) do n = n + 1 end
  check(n == 5, "7.2 quota plus grand que la liste : tous")
  check(next(Piquage.discover_turn({}, 3)) == nil, "7.3 aucun quai du : tour vide")
  -- 20 quais toujours dus (aucun tapis) : en 7 passages chacun est decouvert au moins une fois
  local last, seen = {}, {}
  for pass = 1, 7 do
    local l = {}
    for i = 1, 20 do l[i] = { key = "k" .. i, last = last["k" .. i] } end
    for _, k in ipairs({ "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9", "k10", "k11", "k12", "k13", "k14", "k15", "k16", "k17", "k18", "k19", "k20" }) do
      if Piquage.discover_turn(l, 3)[k] then last[k] = pass; seen[k] = true end
    end
  end
  local all = true
  for i = 1, 20 do if not seen["k" .. i] then all = false end end
  check(all, "7.4 vingt quais dus : aucun n'est affame")
end

-- §8 (s40 p8) purge des tables par quai et par projet
do
  local st = { links = { ["3:q1"] = {} }, track = { ["1:q1"] = {}, ["2:q1"] = {}, ["3:q1"] = {} }, disc = { ["1:q1"] = 5, ["2:q1"] = 5 },
    said = { ["1:q1"] = "a", ["2:q1"] = "b", ["2:q1#pose"] = "c", ["3:q1#vie"] = "d" }, tries = { ["1:q1"] = 1, ["2:q1"] = 2, ["9:q1"] = 1 },
    last_try = { ["9:q1"] = 7 }, flow = { [1] = {}, [9] = false } }
  Piquage.purge(st, { ["1:q1"] = true }, { [1] = {}, [2] = {}, [3] = {} })
  check(st.track["1:q1"] and st.track["3:q1"] and not st.track["2:q1"], "8.1 suivi : garde le quai releve et le quai lie, retire l'absent")
  check(st.disc["1:q1"] == 5 and st.disc["2:q1"] == nil, "8.2 decouverte purgee avec le suivi")
  check(st.said["1:q1"] == "a" and st.said["2:q1"] == nil and st.said["2:q1#pose"] == nil and st.said["3:q1#vie"] == "d", "8.3 journal purge, suffixes compris")
  check(st.tries["1:q1"] == 1 and st.tries["2:q1"] == 2 and st.tries["9:q1"] == nil and st.last_try["9:q1"] == nil, "8.4 essais gardes tant que le projet existe")
  check(st.flow[1] ~= nil and st.flow[9] == nil, "8.5 debits d'un projet disparu retires")
end

-- §9 (s40 p9) sources du plan lues une fois par relevé : même filtre qu'avant (hors projet du quai, hors têtes, hors branches de piquage)
do
  local function belt(x, y, role) return { name = "transport-belt", x = x + 0.5, y = y + 0.5, role = role } end
  local fx = { build = { order = { 1, 2, 3, 4 }, projects = {
    [1] = { id = 1, state = "fini", ents = { belt(0, 0), belt(1, 0, "tete"), belt(5, 5) } },
    [2] = { id = 2, state = "fini", ents = { belt(5, 5), belt(2, 0) }, tapis_piquable = { { x = 7, y = 7, item = "X" } } },
    [3] = { id = 3, state = "fini", spec = { liaison = { piquage = true, item = "X" } }, ents = { belt(3, 0) } },
    [4] = { id = 4, state = "pose", ents = { belt(4, 0) } },
  } } }
  local ps = Piquage.plan_sources(fx)
  local function ok_for(pid, k) return ps.owner[k] ~= nil and (ps.multi[k] or ps.owner[k] ~= pid) or false end
  check(ok_for(2, "0:0") and not ok_for(1, "0:0"), "9.1 tuile d'un autre projet : source ; du projet du quai : non")
  check(ps.owner["1:0"] == nil and ps.owner["3:0"] == nil and ps.owner["4:0"] == nil, "9.2 tete, branche de piquage et projet non fini : jamais sources")
  check(ok_for(1, "5:5") and ok_for(2, "5:5"), "9.3 tuile de deux projets : source pour chacun")
  check(ps.opt_in["7:7"] == "X", "9.4 tapis declare piquable")
end

print(string.format("[PIQUAGE-SCRIPT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
