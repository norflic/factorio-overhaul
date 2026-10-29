--[[
  Lot RESEAU-VIVANT : R.repair avec les FILS RÉELS du moteur (net.edges). Sans eux, le modèle à la portée croit relié ce que le
  moteur n'a pas relié (consommateur sur îlot jugé alimenté, plan vide) ; avec eux, le poteau perdu qui relie est trouvé.
  Usage : lua5.2 tests/reseau_aretes_test.lua
]]
package.path = "./?.lua;" .. package.path
local R = require("shared.team.reseau")
local ok_n, fail_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else fail_n = fail_n + 1 print("  ECHEC : " .. msg) end end
local function pole(x, y) return { x = x, y = y, wire = 7.5, supply = 2.5 } end
local function box(x, y) return { x0 = x - 0.5, y0 = y - 0.5, x1 = x + 0.5, y1 = y + 0.5, kw = 10 } end

-- poteaux vivants 1 (0,0) producteur, 2 (6,0), 3 (12,0) [à portée de 2 mais PAS reliés par le moteur], 4 (18,0) ; consommateur en (18,1)
-- poteau perdu en (9,0) qui relierait 2 et 3
local poles = { pole(0, 0), pole(6, 0), pole(12, 0), pole(18, 0) }
local cons = { box(18, 1) }
local prods = { box(0, 1) }
local cands = { pole(9, 0) }

local blind = R.repair({ poles = poles, consumers = cons, producers = prods }, cands)
check(#blind.chosen == 0, "modele a la portee : 2 et 3 sont deja 'relies', rien a relever (" .. #blind.chosen .. ")")
-- fils reels : 1-2 et 3-4 seulement
local real = R.repair({ poles = poles, consumers = cons, producers = prods, edges = { { 1, 2 }, { 3, 4 } } }, cands)
check(#real.chosen == 1 and real.chosen[1] == 1, "fils reels : le poteau perdu en (9,0) est a relever")
check(real.restored == 1, "fils reels : le consommateur est rallume")
-- fils reels complets : plus rien a relever
local full = R.repair({ poles = poles, consumers = cons, producers = prods, edges = { { 1, 2 }, { 2, 3 }, { 3, 4 } } }, cands)
check(#full.chosen == 0, "fils reels complets : rien a relever")
-- un poteau perdu inutile n'est pas choisi
local useless = R.repair({ poles = poles, consumers = cons, producers = prods, edges = { { 1, 2 }, { 3, 4 } } }, { pole(9, 0), pole(60, 60) })
check(#useless.chosen == 1 and useless.chosen[1] == 1, "le poteau perdu loin de tout n'est pas releve")
-- determinisme
local again = R.repair({ poles = poles, consumers = cons, producers = prods, edges = { { 1, 2 }, { 3, 4 } } }, cands)
check(again.chosen[1] == real.chosen[1] and again.cost == real.cost, "determinisme")
print(string.format("[ARETES] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
