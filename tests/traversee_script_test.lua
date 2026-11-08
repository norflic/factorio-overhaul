--[[
  Tests hors jeu de la couche RUNTIME du lot TRAVERSEE (script/team/traversee.lua) sur un moteur MINIMAL fabriqué ici (game, surface, équipe) :
  lecture du souterrain débloqué (vitesse, portée), gisement par chunk avec cache, souterrains existants par axe, nature de l'obstacle au
  journal, réglage éteint, chaîne de poteaux. Usage, depuis la racine du mod :   lua5.2 tests/traversee_script_test.lua
]]

package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

-- Moteur minimal -------------------------------------------------------------------------------
local logs = {}
function log(text) logs[#logs + 1] = text end -- luacheck: ignore

local ore_tiles, entities, ghost_ugs = {}, {}, {}
local resource_reads = 0
local surface = {
  index = 1,
  find_entities_filtered = function(q)
    local x0, y0, x1, y1 = q.area[1][1], q.area[1][2], q.area[2][1], q.area[2][2]
    local out = {}
    if q.type == "resource" then
      resource_reads = resource_reads + 1
      for _, o in ipairs(ore_tiles) do
        if o.x >= x0 and o.x < x1 and o.y >= y0 and o.y < y1 then out[#out + 1] = { position = { x = o.x + 0.5, y = o.y + 0.5 }, type = "resource" } end
      end
    elseif q.type == "underground-belt" then
      for _, e in ipairs(entities) do
        if e.type == "underground-belt" and e.x >= x0 and e.x < x1 and e.y >= y0 and e.y < y1 then
          out[#out + 1] = { position = { x = e.x + 0.5, y = e.y + 0.5 }, direction = e.direction, type = e.type }
        end
      end
    elseif q.name == "entity-ghost" then
      for _, e in ipairs(ghost_ugs) do
        if e.x >= x0 and e.x < x1 and e.y >= y0 and e.y < y1 then
          out[#out + 1] = { position = { x = e.x + 0.5, y = e.y + 0.5 }, direction = e.direction, type = "entity-ghost", ghost_type = "underground-belt" }
        end
      end
    elseif q.type == nil and q.name == nil then
      for _, e in ipairs(entities) do
        if e.x + 0.5 > x0 and e.x + 0.5 < x1 and e.y + 0.5 > y0 and e.y + 0.5 < y1 then
          out[#out + 1] = { position = { x = e.x + 0.5, y = e.y + 0.5 }, type = e.type }
        end
      end
    end
    return out
  end,
  count_tiles_filtered = function() return 0 end,
}

local function proto(speed, maxd, item)
  return { belt_speed = speed, max_underground_distance = maxd, items_to_place_this = { { name = item } }, has_flag = function() return false end }
end
local recipes = { ["underground-belt"] = { enabled = true }, ["fast-underground-belt"] = { enabled = false } }
game = { -- luacheck: ignore
  tick = 100,
  forces = { player = { recipes = recipes } },
  entity_prototypes = { ["transport-belt"] = { belt_speed = 0.03125 }, ["fast-transport-belt"] = { belt_speed = 0.0625 } },
  get_filtered_entity_prototypes = function(filters)
    assert(filters[1].filter == "type" and filters[1].type == "underground-belt")
    return { ["underground-belt"] = proto(0.03125, 5, "underground-belt"), ["fast-underground-belt"] = proto(0.0625, 7, "fast-underground-belt") }
  end,
}

local P = require("shared.team.plan")
local Tv = require("shared.team.traversee")
local Trav = require("script.team.traversee")

local function team() return { key = "azure", force = "player", build = { stats = {}, order = {}, projects = {} } } end

-- Couloir de 3 lignes : mur d'une colonne (poteau) à x = 6 ----------------------------------------
local bounds = { x0 = 0, y0 = 0, x1 = 12, y1 = 2 }
local function cost(x, y)
  if x < 0 or x > 12 or y < 0 or y > 2 then return nil end
  if x == 6 then return nil end
  return 1
end
entities = {}
for y = 0, 2 do entities[#entities + 1] = { x = 6, y = y, type = "electric-pole" } end

local f = team()
local tiles, info, names = Trav.route(f, surface, { id = 81 }, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, bounds, cost, { belt = "transport-belt", kind = "liaison" })
check(tiles and info.jumps == 1, "1 : une paire souterraine pour traverser le poteau")
check(names and names.ug == "underground-belt" and names.maxd == 5, "2 : souterrain débloqué le moins cher dont la vitesse atteint celle du tapis")
check(#Tv.verify(tiles, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, 5, cost) == 0, "3 : preuve")
check(logs[1] and logs[1]:find("[FO-TRAVERSEE] azure : projet 81 (liaison) : souterrain de (", 1, true) and logs[1]:find("poteau", 1, true),
  "4 : journal : l'obstacle franchi est un poteau (" .. tostring(logs[1]) .. ")")
local ents = Trav.entities(tiles, { belt = "transport-belt", ug = names.ug }, "liaison-tapis")
local nug = 0
for _, e in ipairs(ents) do if e.type then nug = nug + 1 end end
check(nug == 2 and ents[1].name == "transport-belt", "5 : entités : deux pièces souterraines typées, le reste en tapis")
check(f.build.stats.traversee and f.build.stats.traversee.routes == 1 and f.build.stats.traversee.jumps == 1, "6 : compteurs de l'équipe")

-- Un tapis rapide exige un souterrain rapide ; non débloqué : le plus rapide débloqué ---------------
local ug = Trav.underground(f, "fast-transport-belt")
check(ug and ug.name == "underground-belt", "7 : rapide non débloqué : le plus rapide débloqué (" .. tostring(ug and ug.name) .. ")")
recipes["fast-underground-belt"].enabled = true
ug = Trav.underground(f, "fast-transport-belt")
check(ug and ug.name == "fast-underground-belt" and ug.maxd == 7, "8 : rapide débloqué : portée 7")
recipes["fast-underground-belt"].enabled = false
recipes["underground-belt"].enabled = false
check(Trav.underground(f, "transport-belt") == nil, "9 : aucun souterrain débloqué : nil")
local none, why = Trav.route(team(), surface, { id = 1 }, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, bounds, cost, { belt = "transport-belt" })
check(none == nil and why == "aucun chemin", "10 : sans souterrain, le mur plein ne se passe pas")
local last = logs[#logs] or ""
check(last:find("REFUS (aucun chemin)", 1, true) and last:find("poteau en (6,", 1, true), "10b : la CAUSE du refus est écrite (" .. last .. ")")
recipes["underground-belt"].enabled = true

-- Réglage éteint : ancien tracé --------------------------------------------------------------------
Trav.set_enabled(false)
local open_cost = function(x, y) if x < 0 or x > 12 or y < 0 or y > 4 then return nil end if x == 6 and y <= 2 then return nil end return 1 end
local t2, i2 = Trav.route(team(), surface, nil, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, { x0 = 0, y0 = 0, x1 = 12, y1 = 4 }, open_cost, { belt = "transport-belt" })
check(t2 and i2.jumps == 0, "11 : réglage éteint : contournement de l'ancien tracé, aucune paire")
Trav.set_enabled(true)

-- Gisement : lecture par chunk, cache ----------------------------------------------------------
ore_tiles = {}
for x = 4, 8 do for y = 0, 2 do ore_tiles[#ore_tiles + 1] = { x = x, y = y } end end
entities = {}
game.tick = 5000
resource_reads = 0
local look = Trav.ore_lookup(surface)
check(look(5, 1) == true and look(10, 1) == false, "12 : tuile de gisement lue")
local r1 = resource_reads
look(6, 2); look(9, 0); look(1, 1)
check(resource_reads == r1 and r1 == 1, "13 : un seul chunk lu pour toutes ces questions (" .. resource_reads .. ")")
game.tick = 5000 + Trav.TTL + 1
look(5, 1)
check(resource_reads == 2, "14 : relu après la durée de vie du cache")

-- Gisement évité par le tracé -------------------------------------------------------------------------
local wide = { x0 = 0, y0 = 0, x1 = 12, y1 = 6 }
local wc = function(x, y) if x < 0 or x > 12 or y < 0 or y > 6 then return nil end return 1 end
logs = {}
local t3, i3 = Trav.route(team(), surface, { id = 2 }, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, wide, wc, { belt = "transport-belt", kind = "foreuses" })
check(t3 and i3.base_ore == 5 and i3.ore == 0, "15 : gisement de 5 tuiles évité par un détour (base " .. tostring(i3 and i3.base_ore) .. ", final " .. tostring(i3 and i3.ore) .. ")")
check(logs[1] and logs[1]:find("gisement evite", 1, true), "16 : journal : gisement évité")

-- Souterrains existants : un fantôme de même axe sous la paire l'interdit ---------------------------
entities = {}
for y = 0, 2 do entities[#entities + 1] = { x = 6, y = y, type = "electric-pole" } end
ore_tiles = {}
game.tick = 90000
ghost_ugs = { { x = 6, y = 0, direction = 2 }, { x = 6, y = 1, direction = 2 }, { x = 6, y = 2, direction = 2 } }
local t4 = Trav.route(team(), surface, { id = 3 }, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, bounds, cost, { belt = "transport-belt" })
check(t4 == nil, "17 : fantôme de souterrain de même axe sous le mur : pas de paire")
ghost_ugs = { { x = 6, y = 0, direction = 0 }, { x = 6, y = 1, direction = 0 }, { x = 6, y = 2, direction = 0 } }
local t5 = Trav.route(team(), surface, { id = 4 }, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, bounds, cost, { belt = "transport-belt" })
check(t5 ~= nil, "18 : fantôme d'axe perpendiculaire : paire permise")
ghost_ugs = {}
-- pièce planifiée par un autre projet de l'équipe
local f6 = team()
f6.build.order = { 1 }
f6.build.projects[1] = { ents = { { name = "underground-belt", x = 6.5, y = 1.5, dir = 2, type = "input" } } }
f6.build.projects[1].ents[2] = { name = "underground-belt", x = 6.5, y = 0.5, dir = 2, type = "input" }
f6.build.projects[1].ents[3] = { name = "underground-belt", x = 6.5, y = 2.5, dir = 2, type = "input" }
local t6 = Trav.route(f6, surface, { id = 5 }, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, bounds, cost, { belt = "transport-belt" })
check(t6 == nil, "19 : souterrain planifié de même axe sous le mur : pas de paire")

-- Poteaux --------------------------------------------------------------------------------------------
ore_tiles = {}
for x = 17, 19 do for y = -1, 1 do ore_tiles[#ore_tiles + 1] = { x = x, y = y } end end
game.tick = 200000
local calls = 0
local fp = team()
local free = function() return true end
local a, b = { x = 0.5, y = 0.5 }, { x = 60.5, y = 0.5 }
local chain = Trav.pole_chain(fp, surface, a, b, 9, false, free, nil)
local on = 0
for _, c in ipairs(chain or {}) do if c.x >= 17 and c.x < 20 and c.y >= -1 and c.y < 2 then on = on + 1 end end
check(chain and on == 0, "20 : chaîne de poteaux sans gisement (" .. tostring(on) .. " sur le gisement)")
Trav.set_enabled(false)
local chain0 = Trav.pole_chain(fp, surface, a, b, 9, false, free, nil)
local on0 = 0
for _, c in ipairs(chain0 or {}) do if c.x >= 17 and c.x < 20 and c.y >= -1 and c.y < 2 then on0 = on0 + 1 end end
check(chain0 and on0 >= 1, "21 : réglage éteint : la chaîne d'avant (" .. tostring(on0) .. " sur le gisement)")
Trav.set_enabled(true)

local bilan
for _, l in ipairs(logs) do if l:find("bilan a ", 1, true) then bilan = l end end
logs = {}
game.tick = 400000
Trav.route(team(), surface, { id = 9 }, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, bounds, cost, { belt = "transport-belt" })
local fb = team()
Trav.route(fb, surface, { id = 10 }, { x = 0, y = 1 }, { x = 12, y = 1 }, 2, bounds, cost, { belt = "transport-belt" })
local got
for _, l in ipairs(logs) do if l:find("azure : bilan a ", 1, true) then got = l end end
check(got and got:find("1 trace(s) dont 1 avec paire", 1, true), "24 : bilan par tranche de 5 min (" .. tostring(got) .. ")")

print(string.format("[TRAVERSEE-SCRIPT] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
