--[[
  Lot TAMPON-MINERAI (DC : tolérance 0 sur le minerai) : les poseurs du centre de commandement passent la règle UNIQUE du sol
  (shared/team/sol_minerai.lua, Sm.forbidden, via la VRAIE PlacesQG.on_resource de script/ai3/places_qg.lua), moteur factice minimal.
    §1 CQ.ensure (script/faction/centre_qg.lua) : centre de niveau 1 posé avec le QG ;
    §2 place_center (script/ai3/capital.lua, bloc extrait) : centre posé par CAPITAL ;
    §3 la règle juge l'emprise POSÉE (recalée sur la grille, F104), pas la place trouvée hors grille ;
    §4 mutants : sans la règle, chaque poseur pose sur la ressource.
  (Le tampon du rapatriement : tests/rapatriement_test.lua §8 quater ; l'agrandissement d'un niveau : tests/levels_test.lua, cas d3.)
  Usage : lua5.2 tests/tampon_minerai_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end
local function read(path) local f = assert(io.open(path, "rb")) local s = f:read("*a") f:close() return s end

local logs = {}
_G.log = function(s) logs[#logs + 1] = s end
local L = require("shared.levels.config")
local CNAME = L.name(L.by_key.command, 1)
local function box(h) return { left_top = { x = -h, y = -h }, right_bottom = { x = h, y = h } } end
_G.remote = { add_interface = function() end, interfaces = {} }
_G.game = { tick = 0, forces = { f1 = { name = "f1" } },
  entity_prototypes = { [CNAME] = { type = "container", collision_box = box(1.7) } } }
local PlacesQG = assert(loadfile("script/ai3/places_qg.lua"))()

--- Monde factice : `ore` = { ["x,y"] = true } tuiles de ressource (une entité « resource » au centre de chaque tuile) ; le moteur trouve
--- la place hors grille (décalage 0,3) et create_entity la recale (centre 4 × 4 sur un coin de tuile).
local function world(ore)
  local s, placed = {}, {}
  s.find_non_colliding_position = function(_, c) return { x = c.x + 0.3, y = c.y + 0.3 } end
  s.count_entities_filtered = function(q)
    if q.type ~= "resource" then return 0 end
    local a = q.area
    for y = math.floor(a[1][2]), math.floor(a[2][2]) do
      for x = math.floor(a[1][1]), math.floor(a[2][1]) do
        if ore[x .. "," .. y] and a[1][1] < x + 0.5 and x + 0.5 < a[2][1] and a[1][2] < y + 0.5 and y + 0.5 < a[2][2] then return 1 end
      end
    end
    return 0
  end
  s.create_entity = function(q)
    local e = { name = q.name, position = { x = math.floor(q.position.x + 0.5), y = math.floor(q.position.y + 0.5) }, valid = true,
      unit_number = 100 + #placed, force = q.force }
    placed[#placed + 1] = e
    return e
  end
  return s, placed
end
--- Ressource sous la première place (0, 14) autour du QG en (0, 0) : un bloc de 9 × 9 tuiles.
local function ore_first()
  local ore = {}
  for x = -4, 4 do for y = 10, 18 do ore[x .. "," .. y] = true end end
  return ore
end
local function none_on_ore(s, placed)
  for _, e in ipairs(placed) do if PlacesQG.on_resource(s, e.name, e.position) then return false end end
  return true
end

---------------------------------------------------------------------------------------------------
-- §1 CQ.ensure
---------------------------------------------------------------------------------------------------
local CQ_SRC = read("script/faction/centre_qg.lua")
local function load_cq(src, rule)
  local cc = nil
  package.loaded["script.core.events"] = setmetatable({}, { __index = function() return function() end end })
  package.loaded["script.faction.state"] = { war = function() return nil end, sorted_keys = function() return {} end }
  package.loaded["script.ai3.places_qg"] = { on_resource = rule }
  package.loaded["script.levels.levels"] = { cc = function() return cc end }
  local CQ = assert(load(src, "=centre_qg", "t", _G))()
  return CQ, function(e) cc = e end
end
local function cq_case(src, rule)
  local CQ, set_cc = load_cq(src, rule)
  local s, placed = world(ore_first())
  local create = s.create_entity
  s.create_entity = function(q) local e = create(q) set_cc(e) return e end
  local f = { key = "A", force = "f1", hq = { valid = true, surface = s }, hq_pos = { x = 0, y = 0 } }
  local e, st = CQ.ensure(f, "test")
  return e, st, s, placed
end
do
  local e, st, s, placed = cq_case(CQ_SRC, PlacesQG.on_resource)
  check(e ~= nil and st == "pose" and #placed == 1, "1.1 CQ.ensure : un centre pose (" .. tostring(st) .. ")")
  check(e and e.position.x == 14 and e.position.y == 0, "1.2 premiere place (0, 14) sur la ressource : centre a la deuxieme (14, 0) ("
    .. (e and (e.position.x .. ", " .. e.position.y) or "-") .. ")")
  check(none_on_ore(s, placed), "1.3 aucun centre sur une tuile de ressource")
  -- tout autour sur la ressource : aucun centre, refus « place » journalisé
  local CQ2, set2 = load_cq(CQ_SRC, PlacesQG.on_resource)
  local all = {}
  for x = -40, 40 do for y = -40, 40 do all[x .. "," .. y] = true end end
  local s2, placed2 = world(all)
  local f2 = { key = "B", force = "f1", hq = { valid = true, surface = s2 }, hq_pos = { x = 0, y = 0 } }
  local e2, st2 = CQ2.ensure(f2, "test")
  check(e2 == nil and st2 == "place" and #placed2 == 0, "1.4 ressource partout : aucun centre pose, motif place (" .. tostring(st2) .. ")")
end

---------------------------------------------------------------------------------------------------
-- §2 place_center (CAPITAL)
---------------------------------------------------------------------------------------------------
local CAP_SRC = read("script/ai3/capital.lua")
local function extract(src, from, to)
  local a = assert(src:find(from, 1, true), "debut introuvable : " .. from)
  local b = assert(src:find(to, a, true), "fin introuvable : " .. to)
  return src:sub(a, b - 1)
end
local CAP_BLOCK = extract(CAP_SRC, "local function place_center(f, c, d, tick)", "--- Remplace UNE machine sur place")
local function load_place(block, rule)
  local Capital = { CENTER_OFFSETS = { { 0, 14 }, { 14, 0 }, { -14, 0 }, { 0, -14 }, { 14, 14 }, { -14, 14 } }, CENTER_SEARCH = 12 }
  local Stock = { count = function() return 5 end, remove = function() end }
  local env = setmetatable({ Capital = Capital, Stock = Stock, L = L, CFAM = L.by_key.command, PlacesQG = { on_resource = rule },
    minutes = function() return 1 end }, { __index = _G })
  return assert(load("local Capital, Stock, L, CFAM, PlacesQG, minutes = Capital, Stock, L, CFAM, PlacesQG, minutes\n" .. block
    .. "\nreturn place_center", "=place_center", "t", env))()
end
local function cap_case(block, rule)
  local place = load_place(block, rule)
  local s, placed = world(ore_first())
  local f = { key = "A", force = "f1", hq = { surface = s }, hq_pos = { x = 0, y = 0 }, team = { consumed = {} } }
  local ok, why = place(f, {}, { cost = { { "objet", 1 } } }, 0)
  return ok, why, s, placed
end
do
  check(CAP_SRC:find("if pos and not PlacesQG.on_resource(surface, name, pos) then", 1, true) ~= nil
    and CAP_SRC:find('local PlacesQG = require("script.ai3.places_qg")', 1, true) ~= nil, "2.0 CAPITAL lit la regle du sol (PlacesQG.on_resource)")
  local ok, why, s, placed = cap_case(CAP_BLOCK, PlacesQG.on_resource)
  check(ok == true and #placed == 1, "2.1 place_center : un centre pose (" .. tostring(why) .. ")")
  check(placed[1] and placed[1].position.x == 14 and placed[1].position.y == 0, "2.2 premiere place sur la ressource : centre a la deuxieme (14, 0)")
  check(none_on_ore(s, placed), "2.3 aucun centre sur une tuile de ressource")
end

---------------------------------------------------------------------------------------------------
-- §3 emprise posée : la place trouvée (0.3, 14.3) hors grille, posée en (0, 14) ; une seule tuile de ressource (-2, 12), coin
-- haut-gauche de l'emprise posée (-2..1, 12..15), que l'emprise trouvée (-1.4..2.0, 12.6..16.0) ne touche pas
---------------------------------------------------------------------------------------------------
do
  local s = world({ ["-2,12"] = true })
  check(PlacesQG.on_resource(s, CNAME, { x = 0.3, y = 14.3 }), "3.1 place trouvee hors grille : la regle juge l'emprise posee (recalee) et la refuse")
  check(not PlacesQG.on_resource(s, CNAME, { x = 0.3, y = 18.3 }), "3.2 a quatre tuiles : admise")
  check(not PlacesQG.on_resource(world({ ["-2,12"] = true }), "transport-belt", { x = -1.5, y = 12.5 }), "3.3 un type sans prototype lu (aucune emprise) : jamais refuse")
end

---------------------------------------------------------------------------------------------------
-- §4 mutants
---------------------------------------------------------------------------------------------------
local mutants, seen = 0, 0
local function mutant(label, detected)
  mutants = mutants + 1
  if detected then seen = seen + 1 else print("  SURVIVANT : " .. label) end
end
do
  local m, k = CQ_SRC:gsub(" and not PlacesQG%.on_resource%(surface, name, pos%)", "", 1)
  check(k == 1, "4.0 motif du mutant CQ trouve")
  local _, _, s, placed = cq_case(m, PlacesQG.on_resource)
  mutant("CQ.ensure sans la regle du sol", not none_on_ore(s, placed))
  local _, _, s2, placed2 = cq_case(CQ_SRC, function() return false end)
  mutant("CQ.ensure, regle du sol muette", not none_on_ore(s2, placed2))
  local mb, kb = CAP_BLOCK:gsub(" and not PlacesQG%.on_resource%(surface, name, pos%)", "", 1)
  check(kb == 1, "4.1 motif du mutant CAPITAL trouve")
  local _, _, s3, placed3 = cap_case(mb, PlacesQG.on_resource)
  mutant("place_center sans la regle du sol", not none_on_ore(s3, placed3))
  local QS = read("script/ai3/places_qg.lua")
  local qm, qk = QS:gsub("%s+pos = { x = Pl%.snap%(pos%.x, w%), y = Pl%.snap%(pos%.y, h%) }", "", 1)
  check(qk == 1, "4.2 motif du mutant de recalage trouve")
  local Qm = assert(load(qm, "=places_qg_mutant", "t", _G))()
  mutant("regle du sol sans recalage (place trouvee)", not Qm.on_resource(world({ ["-2,12"] = true }), CNAME, { x = 0.3, y = 14.3 }))
end
print(string.format("[TAMPON-MINERAI] mutants refuses : %d sur %d", seen, mutants))
failures = failures + (mutants - seen)
print(string.format("[TAMPON-MINERAI] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
