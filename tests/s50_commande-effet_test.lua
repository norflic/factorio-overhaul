--[[
  s50 commande-effet : le centre reporté (starved / thaw / cash) ne double plus un remplacement de la zone prioritaire du joueur.
  Lancement : lua5.2 tests/s50_commande-effet_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Cap = require("shared.ai3.capital")
local L = require("shared.levels.config")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local protos = {
  ["lent-a"] = { type = "furnace", group = "g", w = 2, h = 2, energy = "burner", cats = { s = true }, speed = 1, item = "lent-a" },
  ["vite-a"] = { type = "furnace", group = "g", w = 2, h = 2, energy = "burner", cats = { s = true }, speed = 4, item = "vite-a" },
}
local function ctx(zones)
  return { proto = function() return nil end, unit_cost = function(i) return ({ ["vite-a"] = 10 })[i] end, stock = { ["vite-a"] = 1 },
    weights = {}, mproto = function(n) return protos[n] end, machines = { "lent-a", "vite-a" }, zones = zones, thaw = true, cash = true }
end
local census = { list = {}, center = nil, no_center = true,
  machines = { { id = 1, name = "lent-a", working = true, x = 200, y = 200, block = "zone1" } } }
local d = Cap.choose(L, census, ctx({ { id = 1, x = 200, y = 200, r = 10 } }))
check(d.replace and d.zone == true, "zone : le remplacement de la zone est le but (" .. tostring(d.key) .. ")")
check(not d.starved and not d.cash, "zone : ni starved ni cash")

-- source : la boucle du centre est sautée quand le premier candidat est de la zone
local fh = assert(io.open("shared/ai3/capital.lua", "r"))
local src = fh:read("*a"); fh:close()
check(src:find("zone_first and {} or res.cands", 1, true) ~= nil, "Cap.choose : le centre ne passe pas devant la zone")

print(string.format("s50 commande-effet : %d OK, %d echec(s)", passes, failures))
os.exit(failures == 0 and 0 or 1)
