package.path = "./?.lua;" .. package.path
local Mo = require("shared.ai3.moteurs")
local Ml = require("shared.ai3.mall")
local ok, fail = 0, 0
local function check(c, m) if c then ok = ok + 1 else fail = fail + 1 print("ECHEC " .. m) end end

-- noms inventés : la règle ne lit que la structure
local fab = {
  rA = { main = false, patronnable = true, solides = { { name = "p", amount = 1 }, { name = "g", amount = 1 } }, fluides_in = {}, produits = { "X" } },
  rB = { main = false, patronnable = true, solides = { { name = "X", amount = 2 } }, fluides_in = {}, produits = { "Bat" } },
  rC = { main = true, patronnable = true, solides = { { name = "p", amount = 1 } }, fluides_in = {}, produits = { "g" } },
  rD = { main = false, patronnable = true, solides = { { name = "p", amount = 1 } }, fluides_in = {}, produits = { "Y" } }, -- personne ne consomme Y
  rE = { main = false, patronnable = true, solides = { { name = "q", amount = 1 } }, fluides_in = {}, produits = { "Z" } }, -- q inutilisable
  rF = { main = false, patronnable = true, solides = { { name = "Z", amount = 1 }, { name = "Y", amount = 1 } }, fluides_in = {}, produits = { "W" } },
}
local enabled = function(rn) return rn ~= "rB" end
local usable = function(n) return n == "p" or n == "g" end
local stock = {}
local have = function(n) return stock[n] or 0 end
local l = Mo.wants(fab, enabled, usable, have)
check(#l == 2, "deux candidats (X, Y) : " .. #l)
local items = {}
for _, w in ipairs(l) do items[w.item] = w end
check(items.X and items.X.need == Mo.STOCK, "X demande au tampon entier")
check(items.Y ~= nil, "Y consomme par rF")
check(items.Z == nil, "Z : ingredient inutilisable")
check(items.g == nil, "g : la main le fait")
-- recette verrouillée : rien
local l2 = Mo.wants(fab, function(rn) return rn ~= "rA" and rn ~= "rD" end, usable, have)
check(#l2 == 0, "recettes verrouillees : rien")
-- tampon atteint : demande éteinte
stock.X = Mo.STOCK
local l3 = Mo.wants(fab, enabled, usable, have)
local hasX = false
for _, w in ipairs(l3) do if w.item == "X" then hasX = true end end
check(not hasX, "tampon atteint : X non demande")
stock.X = 5
local l4 = Mo.wants(fab, enabled, usable, have)
for _, w in ipairs(l4) do if w.item == "X" then check(w.need == Mo.STOCK - 5, "manque borne") end end
-- pose au mall
local st = Ml.new()
check(Mo.seed(st, 100, l4, Ml) == #l4, "demande posee")
check(st.want.X and st.want.X.src == Mo.SRC, "source moteur")
-- une demande plus forte d'une autre source est gardée
st.want.X = { rate = 99, tick = 100, src = "refus" }
Mo.seed(st, 101, l4, Ml)
check(st.want.X.src == "refus", "demande plus forte gardee")
-- déterminisme
local a, b = Mo.wants(fab, enabled, usable, have), Mo.wants(fab, enabled, usable, have)
check(#a == #b and a[1].item == b[1].item, "deterministe")
print(string.format("s44_moteurs : %d OK, %d echec(s)", ok, fail))
if fail > 0 then os.exit(1) end
