-- Lot POTEAU-CHANTIER (0716) : règle pure shared/team/poteau_chantier.lua (zone d'alimentation, compensation), avec Rc.pick_chain.
package.path = "./?.lua;" .. package.path
local Pc = require("shared.team.poteau_chantier")
local Rc = require("shared.team.reconstruction")

local pass, fail = 0, 0
local function check(c, msg)
  if c then pass = pass + 1 else fail = fail + 1 print("[POTEAU-CHANTIER] ECHEC : " .. msg) end
end

-- zone
local box = { x0 = 10, y0 = 10, x1 = 13, y1 = 13 } -- machine 3x3
check(Pc.covers(8.5, 11.5, 2.5, box), "zone 2,5 a 1,5 tuile du bord : couvre")
check(not Pc.covers(6.5, 11.5, 2.5, box), "zone 2,5 a 3,5 tuiles du bord : ne couvre pas")
check(Pc.covers(6.5, 11.5, 4, box) and not Pc.covers(6.5, 11.5, 3.5, box), "zone qui depasse le bord : couvre ; qui le touche seulement : non")

-- compensation : la machine couverte par le poteau moyen (zone 3,5) ne l'est plus par le petit (2,5) au même endroit
local free = function() return true end
local add, lost = Pc.compensate({ { key = 1, box = box } }, { { x = 6.5, y = 11.5, supply = 2.5 } }, 2.5, 7.5, free)
check(#add == 1 and #lost == 0, "machine hors zone : un poteau de compensation")
check(add[1] and Pc.covers(add[1].x, add[1].y, 2.5, box), "le poteau ajoute couvre la machine")
local dx, dy = add[1].x - 6.5, add[1].y - 11.5
check(math.sqrt(dx * dx + dy * dy) <= 7.5, "le poteau ajoute est relie au reseau par le fil")
check(add[1].x % 1 == 0.5 and add[1].y % 1 == 0.5, "centre de tuile")
local add2 = Pc.compensate({ { key = 1, box = box } }, { { x = 8.5, y = 11.5, supply = 2.5 } }, 2.5, 7.5, free)
check(#add2 == 0, "machine couverte : rien a ajouter")
local _, lost3 = Pc.compensate({ { key = 7, box = box } }, { { x = 6.5, y = 11.5, supply = 2.5 } }, 2.5, 7.5, function() return false end)
check(#lost3 == 1 and lost3[1] == 7, "aucune tuile libre : la machine est signalee")
local _, lost4 = Pc.compensate({ { key = 1, box = box } }, { { x = -40.5, y = 11.5, supply = 2.5 } }, 2.5, 7.5, free)
check(#lost4 == 1, "aucune place reliee au reseau par le fil : signalee")
-- deux machines voisines : un seul ajout peut servir les deux
local b2 = { x0 = 13, y0 = 10, x1 = 16, y1 = 13 }
local add5 = Pc.compensate({ { key = 1, box = box }, { key = 2, box = b2 } }, { { x = 6.5, y = 11.5, supply = 2.5 } }, 2.5, 7.5, free)
check(#add5 >= 1 and #add5 <= 2, "deux machines : au plus deux ajouts")
-- determinisme
local a1 = Pc.compensate({ { key = 1, box = box }, { key = 2, box = b2 } }, { { x = 6.5, y = 11.5, supply = 2.5 } }, 2.5, 7.5, free)
local a2 = Pc.compensate({ { key = 1, box = box }, { key = 2, box = b2 } }, { { x = 6.5, y = 11.5, supply = 2.5 } }, 2.5, 7.5, free)
local same = #a1 == #a2
for i = 1, #a1 do same = same and a1[i].x == a2[i].x and a1[i].y == a2[i].y end
check(same, "meme entree, memes ajouts")
-- chaine de repli + compensation sur une ligne de poteaux moyens (pas 9)
local cands = { { name = "petit", item = "ip", supply = 2.5, wire = 7.5 }, { name = "moyen", item = "im", supply = 3.5, wire = 9 } }
local c, pts = Rc.pick_chain(cands, { x = 0.5, y = 0.5 }, { { x = 9.5, y = 0.5 } }, function(x) return x.item == "ip" end)
check(c and c.name == "petit" and #pts == 1, "chantier : petit poteau et un relais vers le voisin a 9")
-- mutant : la compensation qui ignore le fil
local src = io.open("shared/team/poteau_chantier.lua"):read("*a")
local mut = src:gsub("if near <= wire and near < bd then", "if near < bd then", 1)
local PcX = assert(load(mut))()
local addm = PcX.compensate({ { key = 1, box = box } }, { { x = -40.5, y = 11.5, supply = 2.5 } }, 2.5, 7.5, free)
check(#addm == 1 and #lost4 == 1, "mutant : un poteau de compensation hors de portee de fil est vu")

print(string.format("[POTEAU-CHANTIER] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
