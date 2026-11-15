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
-- relais décalés : la tuile prévue est prise, un voisin libre garde chaque pas sous le fil
do
  local a, b = { x = 0.5, y = 0.5 }, { x = 9.5, y = 0.5 }
  local pts = Rc.chain_points(a, { b }, 7.5)
  local blocked = {}
  for _, q in ipairs(pts) do blocked[q.x .. "," .. q.y] = true end
  local put = Pc.place_chain(a, b, pts, 7.5, function(x, y) return not blocked[x .. "," .. y] end)
  check(put and #put == #pts, "relais decale quand sa tuile est prise")
  local okw = put ~= nil
  local prev = a
  for _, q in ipairs(put or {}) do
    if math.sqrt((q.x - prev.x) ^ 2 + (q.y - prev.y) ^ 2) > 7.5 then okw = false end
    if blocked[q.x .. "," .. q.y] then okw = false end
    prev = q
  end
  if math.sqrt((b.x - prev.x) ^ 2 + (b.y - prev.y) ^ 2) > 7.5 then okw = false end
  check(okw, "chaque pas de la chaine decalee reste sous le fil, hors des tuiles prises")
  check(Pc.place_chain(a, b, pts, 7.5, function() return false end) == nil, "aucune tuile libre : nil")
  local put2 = Pc.place_chain(a, b, pts, 7.5, function() return true end)
  check(put2 and put2[1].x == pts[1].x and put2[1].y == pts[1].y, "tuile libre : le relais reste a sa place")
end
-- mutant : la compensation qui ignore le fil
local src = io.open("shared/team/poteau_chantier.lua"):read("*a")
local mut = src:gsub("if near <= wire and near < bd then", "if near < bd then", 1)
local PcX = assert(load(mut))()
local addm = PcX.compensate({ { key = 1, box = box } }, { { x = -40.5, y = 11.5, supply = 2.5 } }, 2.5, 7.5, free)
check(#addm == 1 and #lost4 == 1, "mutant : un poteau de compensation hors de portee de fil est vu")

print(string.format("[POTEAU-CHANTIER] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
