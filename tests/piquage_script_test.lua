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
link_belts()
local Pq = require("shared.team.piquage")
local Li = require("shared.team.liaison")
local P = require("shared.team.plan")
local Piquage = require("script.team.piquage")

local B = { occ = {}, order = { 1 }, projects = {}, lat = P.lattice({ x = 0, y = 0 }), stats = { filled = 0 }, next_id = 2 }
local PROJ1 = { id = 1, state = "fini", spec = { gen = "x", names = { arm = "inserter", pole = "small-electric-pole" } }, parts = { { kind = "module" } }, quais = { { x = 20.5, y = 14.5, item = "X" } }, outs = {}, ents = {},
  inflow = { X = 1.0 } }
B.projects[1] = PROJ1
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
}
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
-- plan refusé si le tapis source a disparu
do
  local keep
  for _, e in ipairs(ENTS) do if e.valid and e.type == "transport-belt" and math.floor(e.position.x) == g.tile.x and math.floor(e.position.y) == g.tile.y then keep = e end end
  keep.valid = false
  local p3 = { id = 9, spec = REQ[1].spec, ents = {}, parts = {}, obstacles = {} }
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

print(string.format("[PIQUAGE-SCRIPT] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
