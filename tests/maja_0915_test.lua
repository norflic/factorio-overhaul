--[[
  maja-0915 : l'ordre Maj+A ne compte que les entités POSÉES PAR L'ORDRE (nées après, sur une case libre à la pose) et désigne un
  gisement pour la bande de champ. Lancement : lua5.2 tests/maja_0915_test.lua (racine du mod).
]]
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local skip = { character = true, ["entity-ghost"] = true }
-- 175 foreuses déjà là à la pose (cases occupées), remplacées ensuite (numéros neufs) : 0 posée par l'ordre
local pre, ents = {}, {}
for i = 1, 175 do
  pre[Co.cell_key(i * 3 + 0.5, 10.5)] = true
  ents[#ents + 1] = { un = 1000 + i, x = i * 3 + 0.5, y = 10.5, type = "mining-drill", force = "player" }
end
local n, ghost = Co.count_new(ents, 900, pre, "player", skip)
check(n == 0, "remplacements sur place : 0 posée par l'ordre (lu " .. n .. ")")
check(ghost == false, "pas de fantôme neuf")
-- entités nées avant l'ordre (numéro <= repère) : jamais comptées
n = Co.count_new({ { un = 50, x = 0.5, y = 0.5, type = "mining-drill", force = "player" } }, 900, {}, "player", skip)
check(n == 0, "née avant l'ordre : non comptée")
-- une rangée neuve sur des cases libres : comptée ; autre force, personnage : non comptés ; fantôme neuf vu
local row = {}
for i = 1, 6 do row[#row + 1] = { un = 2000 + i, x = i * 3 + 0.5, y = 40.5, type = "mining-drill", force = "player" } end
row[#row + 1] = { un = 3000, x = 5.5, y = 50.5, type = "mining-drill", force = "enemy" }
row[#row + 1] = { un = 3001, x = 6.5, y = 50.5, type = "character", force = "player" }
row[#row + 1] = { un = 3002, x = 7.5, y = 50.5, type = "entity-ghost", force = "player" }
n, ghost = Co.count_new(row, 900, pre, "player", skip)
check(n == 6, "rangée neuve sur cases libres : 6 (lu " .. n .. ")")
check(ghost == true, "fantôme neuf vu")
-- un fantôme d'amélioration sur une case occupée n'est pas un plan de l'ordre
n, ghost = Co.count_new({ { un = 4000, x = 3.5, y = 10.5, type = "entity-ghost", force = "player" } }, 900, pre, "player", skip)
check(n == 0 and ghost == false, "fantôme sur case occupée : ignoré")
-- état vide / repère absent : sûr
n = Co.count_new(nil, nil, nil, "player", nil)
check(n == 0, "liste vide : 0")

-- gisement désigné : même ressource, boîte touchant le cercle, le plus de tuiles d'abord
local o = { id = 4, resource = "res-a", x = 100, y = 100, r = 20 }
local deps = {
  { id = 1, resource = "res-a", tiles = 50, x0 = 500, y0 = 500, x1 = 600, y1 = 600, cx = 550, cy = 550 },
  { id = 2, resource = "res-b", tiles = 9999, x0 = 90, y0 = 90, x1 = 110, y1 = 110, cx = 100, cy = 100 },
  { id = 3, resource = "res-a", tiles = 300, x0 = 110, y0 = 110, x1 = 200, y1 = 200, cx = 150, cy = 150 },
  { id = 5, resource = "res-a", tiles = 800, x0 = 60, y0 = 60, x1 = 140, y1 = 140, cx = 100, cy = 100 },
}
local d = Co.pick_deposit(deps, o)
check(d and d.id == 5, "gisement désigné : le plus grand de la ressource dans le cercle (lu " .. tostring(d and d.id) .. ")")
d = Co.pick_deposit({ deps[1], deps[2] }, o)
check(d and d.id == "cmd-4" and d.cx == 100 and d.x0 == 80 and d.resource == "res-a", "sans recensement : gisement tiré du cercle")
check(Co.pick_deposit(deps, { id = 1, x = 0, y = 0, r = 1 }) == nil, "ordre sans ressource : rien")

print(string.format("maja_0915 : %d OK, %d ECHEC(S)", passes, failures))
if failures > 0 then os.exit(1) end
