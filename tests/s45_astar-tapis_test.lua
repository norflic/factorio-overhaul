-- s45 astar-tapis : un tracé neuf ne pose rien sur un tapis, un souterrain ou un séparateur existant ; une paire neuve passe par-dessous.
package.path = "./?.lua;" .. package.path
local Ti = require("shared.team.tapis_infranchissable")
local Tv = require("shared.team.traversee")

local ok, fail = 0, 0
local function check(c, msg) if c then ok = ok + 1 else fail = fail + 1; print("ECHEC : " .. msg) end end

-- tuiles : une boîte de séparateur (2 x 1) couvre 2 tuiles, un tapis 1
local set = Ti.tiles({ { x0 = 4.0, y0 = 2.0, x1 = 6.0, y1 = 3.0 }, { x0 = 1.15, y0 = 1.15, x1 = 1.85, y1 = 1.85 } })
check(set["4,2"] and set["5,2"] and not set["6,2"], "séparateur : 2 tuiles")
check(set["1,1"] and not set["2,1"], "tapis : 1 tuile")

-- garde : s et t exempts, le reste interdit
local base = function() return 1 end
local g = Ti.guard(base, function(x, y) return true end, { x = 0, y = 0 }, { x = 9, y = 0 })
check(g(0, 0) == 1 and g(9, 0) == 1 and g(3, 0) == nil, "garde : bouts exempts, milieu interdit")
check(Ti.guard(base, nil) == base, "garde sans lecture : coût inchangé")

-- un mur de tapis existants en x = 5 (n'importe quel sens) sur toute la hauteur de la boîte : le tracé de (0,0) à (10,0)
local wall = {}
for y = -3, 3 do wall[Ti.key(5, y)] = true end
local bounds = { x0 = -1, y0 = -3, x1 = 11, y1 = 3 }
local cost = Ti.guard(base, function(x, y) return wall[Ti.key(x, y)] == true end, { x = 0, y = 0 }, { x = 10, y = 0 })
-- sans souterrain : aucun chemin (le mur est infranchissable)
local tiles = Tv.route({ x = 0, y = 0 }, { x = 10, y = 0 }, 2, bounds, cost, {})
check(tiles == nil, "sans souterrain : le mur de tapis n'est pas emprunté")
-- avec souterrains : une paire passe par-dessous, aucun bout sur le mur
tiles = Tv.route({ x = 0, y = 0 }, { x = 10, y = 0 }, 2, bounds, cost, { maxd = 5 })
check(tiles ~= nil, "avec souterrains : tracé trouvé")
local jumps = 0
for _, e in ipairs(tiles or {}) do
  check(not wall[Ti.key(e.x, e.y)], "aucune pièce sur un tapis existant (" .. e.x .. "," .. e.y .. ")")
  if e.ug == "input" then jumps = jumps + 1 end
end
check(jumps >= 1, "une paire souterraine passe sous le mur")

print(string.format("s45 astar-tapis : %d OK, %d ECHEC", ok, fail))
if fail > 0 then os.exit(1) end
