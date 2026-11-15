--[[
  Lot liaison-maje (15/11) : Maj + E sans paire sortie / quai finie -> tournée prioritaire de l'avant-poste désigné vers le QG.
  Règles pures (shared/ai3/commande.lua : Co.tour_pick, Co.tour_state) et câblage (commande, vue, planificateur, tournée).
  Usage :   lua5.2 tests/liaison_maje_test.lua
]]
package.path = "./?.lua;" .. package.path
local Co = require("shared.ai3.commande")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end

print("== 1. Choix de l'avant-poste")
local a = { x = 0, y = 0, r = 8 }
local ops = { { id = 3, x = 30, y = 0 }, { id = 1, x = -20, y = 0 }, { id = 2, x = 200, y = 0 } }
local p, d = Co.tour_pick(a, ops)
check(p and p.id == 1 and d == 20, "le plus proche du point A")
check(Co.tour_pick({ x = 1000, y = 0, r = 8 }, ops) == nil, "rien a portee : aucun")
check(Co.tour_pick(nil, ops) == nil, "sans point A : aucun")
p = Co.tour_pick(a, { { id = 5, x = 10, y = 0 }, { id = 4, x = -10, y = 0 } })
check(p and p.id == 4, "egalite : plus petit numero")
check(Co.tour_pick(a, { { id = 9, x = a.r + Co.TOUR_REACH, y = 0 } }) ~= nil, "a la limite : retenu")

print("== 2. Etat de la tournee")
check(Co.tour_state(100, nil, 200) == "en cours", "pas encore servie")
check(Co.tour_state(100, 50, 200) == "en cours", "une tournee d'avant l'ordre ne compte pas")
check(Co.tour_state(100, 150, 200) == "servie", "tournee apres l'ordre : servie")
check(Co.tour_state(100, nil, 100 + Co.TOUR_TTL) == "abandon", "abandon apres Co.TOUR_TTL")
check(Co.TOUR_PRIO > 90, "priorite au-dessus de l'urgence ordinaire")

print("== 3. Cablage")
local cmd = read("script/gui/commande.lua")
check(cmd:find("Co.tour_pick(o.a, cands)", 1, true) ~= nil, "commande : choix de l'avant-poste")
check(cmd:find("Co.tour_state(o.tour.t0, op and op.last_service, game.tick)", 1, true) ~= nil, "commande : tournee suivie par last_service")
check(cmd:find('Co.mark(cs, o.id, "fini")', 1, true) ~= nil, "commande : ordre servi marque fini")
check(read("script/team/team.lua"):find("cmd = o.cmd,", 1, true) ~= nil, "vue : l'avant-poste porte son ordre")
local pl = read("shared/team/planner.lua")
check(pl:find('if o.cmd ~= nil and not o.unsafe then', 1, true) ~= nil and pl:find("Co_TOUR_PRIO", 1, true) ~= nil, "planificateur : tournee prioritaire")
check(read("script/faction/outposts.lua"):find("if o.cmd then o.cmd_got", 1, true) ~= nil, "tournee : objets rapportes comptes")

print(string.format("\nResultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
