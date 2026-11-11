--[[
  Lot FIX-P5 (failles 1 et 2) : la menace sur un QG cherche une UNITÉ ennemie (script/ai3/menace.lua), pas l'ennemi le plus
  proche quel qu'il soit (un ver ou un nid masquait la vague). Usage : lua5.2 tests/fix_p5_menace_test.lua
]]
package.path = "./?.lua;" .. package.path
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local function new_force(name, foes)
  local fo = { name = name }
  fo.is_enemy = function(o) return foes[o.name] == true end
  return fo
end
game = { forces = {} }
game.forces.player = new_force("player", { enemy = true, scarlet = true })
game.forces.enemy = new_force("enemy", { player = true })
game.forces.scarlet = new_force("scarlet", { player = true })
game.forces.ami = new_force("ami", {})

local ents = {}
local function ent(ty, force, x, y) ents[#ents + 1] = { valid = true, type = ty, force = force, position = { x = x, y = y } } end
-- Surface simulée : filtres du moteur (position + rayon, force, type, limit) appliqués comme en 1.1.91.
local surface = {
  find_entities_filtered = function(t)
    local fs, ts = {}, {}
    for _, n in ipairs(t.force or {}) do fs[n] = true end
    for _, n in ipairs(t.type or {}) do ts[n] = true end
    local out = {}
    for _, e in ipairs(ents) do
      local dx, dy = e.position.x - t.position.x, e.position.y - t.position.y
      if (not t.force or fs[e.force]) and (not t.type or ts[e.type]) and dx * dx + dy * dy <= t.radius * t.radius then
        out[#out + 1] = e
        if t.limit and #out >= t.limit then break end
      end
    end
    return out
  end,
  find_nearest_enemy = function() return ents[1] end, -- l'ancienne recherche : le ver, plus proche
}

local Mn = require("script.ai3.menace")
local hq = { x = 0, y = 0 }
ent("turret", "enemy", 5, 0)            -- ver, le plus proche
ent("unit-spawner", "enemy", 8, 0)      -- nid
ent("unit", "ami", 3, 0)                -- unité d'une force non ennemie
ent("unit", "enemy", 30, 0)             -- vague, plus loin
ent("unit", "scarlet", 20, 0)           -- raid d'une faction, plus proche que la vague
ent("unit", "enemy", 90, 0)             -- hors rayon

local en = Mn.nearest_unit(surface, "player", hq, 64)
check(en ~= nil, "ver et nid plus proches : la vague d'unités derrière eux est vue")
check(en and en.type == "unit", "ennemi rendu : une unité (ni ver ni nid)")
check(en and en.force ~= "ami", "une unité d'une force non ennemie n'est pas une menace")
check(en and en.force == "scarlet" and en.position.x == 20, "la plus proche des unités ennemies (raid à 20 tuiles avant la vague à 30)")
check(Mn.nearest_unit(surface, game.forces.player, hq, 64) == en, "force donnée en LuaForce : même réponse")
check(Mn.nearest_unit(surface, "player", hq, 10) == nil, "seulement ver et nid dans le rayon : aucune menace")
check(Mn.nearest_unit(surface, "ami", hq, 64) == nil, "force sans ennemi : aucune menace")
ent("character", "enemy", 2, 0)
check(Mn.nearest_unit(surface, "player", hq, 64).type == "character", "un personnage ennemi est une menace")
ents[#ents] = nil

-- Branchement : les deux recherches de menace de soldats.lua passent par Mn.nearest_unit, plus par find_nearest_enemy.
local fh = io.open("script/ai3/soldats.lua", "r")
local src = fh:read("*a")
fh:close()
local _, near = src:gsub("find_nearest_enemy%(%{ position = f%.hq_pos", "")
check(near == 0, "soldats.lua : plus aucun find_nearest_enemy autour du QG (menace du QG et mise à l'abri)")
local _, calls = src:gsub("Mn%.nearest_unit%(", "")
check(calls == 2, "soldats.lua : hq_threat et la mise à l'abri de votre équipe cherchent une unité (2 appels)")

print(string.format("[FIX-P5 MENACE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
