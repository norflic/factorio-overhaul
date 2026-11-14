-- s44 TOURELLES-STOCK : la porte du planificateur ne retient plus le stock payé sur un lieu attaqué en « production d'abord ».
package.path = "./?.lua;" .. package.path
local S = require("shared.team.defense_stock")
local ok, n = 0, 0
local function check(c, msg)
  n = n + 1
  if c then ok = ok + 1 else print("ECHEC : " .. msg) end
end
-- lieux attaqués : posés même en production d'abord
for _, k in ipairs({ "qg", "prevu", "attaque", "site" }) do
  check(S.gate(k, true, false) == nil, "production d'abord ne doit pas retenir " .. k)
  check(S.gate(k, false, false) == nil, "rien ne retient " .. k)
  check(S.gate(k, true, true) == "ressources", "decimee retient " .. k)
end
-- couverture (aucune attaque) : la production d'abord retient toujours
check(S.gate("couverture", true, false) == "ressources", "couverture retenue en production d'abord")
check(S.gate("couverture", false, false) == nil, "couverture permise hors production d'abord")
check(S.gate(nil, true, false) == "ressources", "genre inconnu retenu en production d'abord")
-- mutant : une porte qui laisse tout passer ou retient tout échoue
local real = S.gate
S.gate = function() return nil end
check(S.gate("couverture", true, false) ~= real("couverture", true, false), "mutant tout-permis detecte")
S.gate = function() return "ressources" end
check(S.gate("attaque", true, false) ~= real("attaque", true, false), "mutant tout-retenu detecte")
S.gate = real
-- le lot reste borné par voyage (plafond par vague inchangé)
local c = S.lot(50, 200, 48, 10000)
check(c == S.LOT, "lot borne a S.LOT")
print(string.format("s44_tourelles-stock : %d/%d OK", ok, n))
if ok ~= n then os.exit(1) end
