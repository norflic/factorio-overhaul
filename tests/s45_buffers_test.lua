-- s45 BUFFERS : entre le besoin ordinaire et l'abondance, la cible d'un quai suit le stock LIBRE (au lieu de retomber à la cible ordinaire).
package.path = "./?.lua;" .. package.path
local Rm = require("shared.team.remplissage")
local ok, bad = 0, 0
local function check(c, m) if c then ok = ok + 1 else bad = bad + 1; print("  ECHEC : " .. m) end end
-- cas du journal 0.7.103 (scarlet/emerald) : stock 3801, besoin 2100 sur 9 quais, base 100 -> avant : 100
local l = Rm.level({ base_want = 100, base_low = 50, cap = 4800, stock = 3801, need = 2100, nq = 9 })
check(l.cause == "proportionnel" and l.want == 100 + math.floor(1701 * 0.7 / 9), "stock libre partage : " .. l.want)
check(l.low >= 50 and l.low < l.want, "relance entre base et cible")
-- jamais au-dela de la place du coffre
l = Rm.level({ base_want = 30, base_low = 15, cap = 120, stock = 9000, need = 3000, nq = 2 })
check(l.want == 120, "borne par la place du coffre : " .. l.want)
-- sous le seuil de securite (stock <= besoin) : a l'identique
l = Rm.level({ base_want = 30, base_low = 15, cap = 4800, stock = 900, need = 900, nq = 30 })
check(l.cause == "juste" and l.want == 30 and l.low == 15, "sous le besoin : cible ordinaire")
-- le stock reserve (besoin ordinaire de tous les quais) n'est jamais distribue : somme des cibles <= stock
for _, nq in ipairs({ 1, 3, 9, 30 }) do
  for _, stock in ipairs({ 500, 2000, 3801, 7999 }) do
    local need = 100 * nq
    local tot = 0
    for _ = 1, nq do tot = tot + Rm.level({ base_want = 100, base_low = 50, cap = 4800, stock = stock, need = need, nq = nq }).want end
    if stock > need then check(tot <= need + math.floor((stock - need) * Rm.SHARE_PM / 1000), "pas de vol du stock reserve nq " .. nq .. " stock " .. stock) end
  end
end
-- abondant inchange
l = Rm.level({ base_want = 400, base_low = 60, cap = 4800, stock = 150000, need = 12000, nq = 30 })
check(l.cause == "abondant" and l.want == 3500, "abondant inchange")
-- cap nul : juste
l = Rm.level({ base_want = 30, base_low = 15, cap = 0, stock = 9000, need = 300, nq = 1 })
check(l.cause == "juste" and l.want == 30, "coffre sans place : juste")
print(string.format("[S45-BUFFERS] BILAN : %d OK, %d ECHEC(S)", ok, bad))
if bad > 0 then os.exit(1) end
