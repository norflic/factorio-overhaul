--[[
  Lot TOURELLES, branchement : Outposts.fortify (script/faction/outposts.lua) avec un moteur factice minimal.
  Usage :  lua5.2 tests/pose_tourelles_moteur_test.lua
  Vérifie : mêmes emplacements qu'avant sans bâtiment lointain (ancien ordre), tourelle du côté du bâtiment lointain, nombre posé
  inchangé et limité par les objets portés, repli si le moteur refuse une pose, QG (sans id), rien de posé sans objet, journal.
]]
package.path = "./?.lua;" .. package.path
defines = { direction = { north = 0, east = 2, south = 4, west = 6 }, inventory = { chest = 1 } }
local logs = {}
function log(s) logs[#logs + 1] = s end
package.loaded["script.faction.state"] = { own = function() end, sorted_keys = function(t) local k = {} for a in pairs(t) do k[#k + 1] = a end table.sort(k) return k end }
package.loaded["script.faction.sites"] = {}
package.loaded["script.ai3.places_qg"] = {}
package.loaded["shared.ai3.places"] = package.loaded["shared.ai3.places"] or nil

local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end

local T = require("shared.team.config")
local Outposts = require("script.faction.outposts")

local function bbox(x, y, s) return { left_top = { x = x - s / 2, y = y - s / 2 }, right_bottom = { x = x + s / 2, y = y + s / 2 } } end

local function world(buildings, refuse)
  local placed = {}
  local surface = {}
  surface.find_non_colliding_position = function(_, c) return { x = c.x, y = c.y } end
  surface.find_entities_filtered = function(q)
    local out = {}
    if q.name then for _, p in ipairs(placed) do out[#out + 1] = p end return out end
    for _, b in ipairs(buildings) do out[#out + 1] = b end
    return out
  end
  surface.create_entity = function(q)
    if refuse and refuse[#placed + 1 + (refuse.n or 0)] and not refuse.done then refuse.done = true return nil end
    local e = { name = q.name, position = q.position, unit_number = 1000 + #placed, valid = true,
      get_item_count = function() return 0 end, insert = function() end }
    placed[#placed + 1] = e
    return e
  end
  return surface, placed
end
local function building(x, y, ty, s, un) return { position = { x = x, y = y }, type = ty, bounding_box = bbox(x, y, s), unit_number = un } end
local function carrier(n) local c = { n = n }
  c.get_item_count = function(name) return name == "gun-turret" and c.n or 0 end
  c.remove = function(q) if q.name == "gun-turret" then c.n = c.n - q.count end return q.count end
  return c
end
_G.game = { entity_prototypes = { ["gun-turret"] = { turret_range = 18 } } }
local function fac() return { force = "f1", key = "A", id = 1, turrets = {}, outposts = {}, stats = {} } end

-- 1. Aucun bâtiment lointain : l'ancien premier emplacement (7,7)
do
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1) })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and placed[1].position.x == 7 and placed[1].position.y == 7, "petit avant-poste : (7,7) comme avant")
end
-- 2. Bâtiment lointain au nord-ouest
do
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1), building(-14, -14, "mining-drill", 3, 2) })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and placed[1].position.x == -7 and placed[1].position.y == -7, "bâtiment au nord-ouest : (-7,-7)")
end
-- 3. Deux tourelles, deux côtés
do
  local s, placed = world({ building(0, 0, "lab", 3, 1), building(-14, -14, "mining-drill", 3, 2), building(14, 14, "furnace", 2, 3) })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 2, carrier(5))
  check(n == 2 and placed[1].position.x ~= placed[2].position.x, "deux côtés couverts")
end
-- 4. Limité par les objets portés et par le nombre voulu
do
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1) })
  local c = carrier(1)
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 3, c)
  check(n == 1 and c.n == 0, "une seule tourelle portée : une seule posée")
  n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 3, carrier(0))
  check(n == 0, "aucune tourelle portée : rien posé")
end
-- 5. Repli : le moteur refuse la première pose
do
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1) }, { [1] = true })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and #placed == 1, "pose refusée une fois : le candidat suivant est essayé")
end
-- 6. QG (sans id) et journal
do
  local s, placed = world({ building(0, 0, "container", 2, 77), building(-20, 0, "furnace", 2, 3) })
  local f = fac()
  f.hq = { valid = true, unit_number = 77 }
  logs = {}
  local n = Outposts.fortify(f, s, { pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and placed[1].position.x == -9 and placed[1].position.y == 0, "QG : (-9,0) couvre le coffre et le four lointain")
  check(#logs == 1 and logs[1]:find("%[FO%-TOUR%-POSE%]") and logs[1]:find("QG"), "une ligne de journal [FO-TOUR-POSE]")
end
-- 7. Portée inconnue : ancien ordre
do
  _G.game.entity_prototypes["gun-turret"] = { turret_range = 0 }
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1), building(-14, -14, "mining-drill", 3, 2) })
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 1, carrier(5))
  check(n == 1 and placed[1].position.x == 7, "portée inconnue : ancien ordre")
end

-- 8. Repli ancien : tous les emplacements se replient sur le même point avant toute pose (doublons écartés) ; les tourelles
--    suivantes sont complétées une à une, la place cherchée après les tourelles déjà posées (comme avant le lot)
do
  _G.game.entity_prototypes["gun-turret"] = { turret_range = 18 }
  local s, placed = world({ building(0, 0, "mining-drill", 3, 1) })
  s.find_non_colliding_position = function(_, c)
    if #placed == 0 then return { x = 7, y = 7 } end
    return { x = c.x + #placed * 0.01, y = c.y }
  end
  local n = Outposts.fortify(fac(), s, { id = 1, pos = { x = 0, y = 0 } }, 3, carrier(5))
  check(n == 3, "emplacements confondus avant la pose : le nombre voulu est quand même posé (repli ancien)")
end

print(string.format("[TOURELLES-MOTEUR] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
