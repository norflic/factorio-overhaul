-- Lot FOREUSES : remplacement d'une foreuse a combustion par une electrique (regle pure, shared/team/foreuse_swap.lua).
package.path = "./?.lua;" .. package.path
local S = require("shared.team.foreuse_swap")
local T = require("shared.team.config")
local ok_n, ko_n = 0, 0
local function check(c, msg) if c then ok_n = ok_n + 1 else ko_n = ko_n + 1 print("ECHEC : " .. msg) end end

local E = T.drill_electric
-- Cas du moteur : foreuse a combustion en (10, 10) vers le nord, four 2 x 2 en (9, 8) (outposts.lua : sink_position).
local sink = { x = 9, y = 8, w = 2, h = 2 }
local cx, cy = S.electric_center(10, 10, 0, sink, E)
check(cx == 9.5 and cy == 10.5, "nord : centre (9.5, 10.5), obtenu " .. tostring(cx) .. ", " .. tostring(cy))
-- Les quatre directions, par rotation du meme cas : le centre tourne avec la foreuse.
for _, dir in ipairs({ 2, 4, 6 }) do
  local sx, sy = S.rotate(dir, sink.x - 10, sink.y - 10)
  local s2 = { x = 10 + sx, y = 10 + sy, w = 2, h = 2 }
  local ex, ey = S.electric_center(10, 10, dir, s2, E)
  local rx, ry = S.rotate(dir, 9.5 - 10, 10.5 - 10)
  check(ex == 10 + rx and ey == 10 + ry, "direction " .. dir .. " : centre tourne")
end
-- La nouvelle boite contient l'ancienne emprise, ne recouvre pas le four, depose dans le four.
local box = { x = cx, y = cy, w = 3, h = 3 }
check(not S.overlap(box, sink), "la boite ne recouvre pas le four")
check(S.inside(sink, cx + 0, cy - 1.85), "le depot tombe dans le four")
check(cx - 1.5 <= 9 and cx + 1.5 >= 11 and cy - 1.5 <= 9 and cy + 1.5 >= 11, "l'ancienne emprise est contenue")
-- Recepteur 1 x 1 (coffre) : charbon, pierre.
local chest = { x = 9.5, y = 8.5, w = 1, h = 1 } -- depot (9.5, 8.7) pour le burner (10, 10) nord
local kx, ky = S.electric_center(10, 10, 0, chest, E)
check(kx == 9.5 and ky == 10.5, "coffre : centre (9.5, 10.5)")
-- Recepteur hors de portee du depot : aucun centre.
check(S.electric_center(10, 10, 0, { x = 20, y = 20, w = 2, h = 2 }, E) == nil, "recepteur lointain : nil")
-- Zone d'alimentation : poteau moyen (3.5) a 3 tuiles du bord, petit (2.5) trop loin.
check(S.covered(9.5, 14, 3.5, box), "poteau moyen couvre")
check(not S.covered(9.5, 16, 2.5, box), "petit poteau trop loin")
check(not S.covered(13.5, 10.5, 1.0, box), "zone qui touche seulement le bord : non couverte")
-- Choix du type : l'objet ET le courant.
check(S.choose_type(true, true) == "electric", "objet et courant : electrique")
check(S.choose_type(true, false) == "burner", "pas de courant : combustion")
check(S.choose_type(false, true) == "burner", "objet introuvable : combustion")
-- Plan : seules les foreuses alimentees, triees par id, bornees par le stock et la limite.
local function entry(id, x, y) return { id = id, x = x, y = y, dir = 0, sink = { x = x - 1, y = y - 2, w = 2, h = 2 } } end
local entries = { entry(3, 10, 10), entry(1, 30, 10), entry(2, 50, 10), entry(4, 70, 10) }
local ctx = { poles = { { x = 9.5, y = 14, dist = 3.5, powered = true }, { x = 29.5, y = 14, dist = 3.5, powered = true },
  { x = 49.5, y = 14, dist = 3.5, powered = false } }, electric = E, have = 5, obtainable = true, limit = 2 }
local out, ready = S.plan(entries, ctx)
check(ready == 2, "deux candidats alimentes (le poteau eteint et l'absence de poteau excluent), obtenu " .. ready)
check(#out == 2 and out[1].id == 1 and out[2].id == 3, "ordre par id : 1 puis 3")
ctx.have = 1
out = S.plan(entries, ctx)
check(#out == 1 and out[1].id == 1, "borne par le stock")
ctx.obtainable = false
out, ready = S.plan(entries, ctx)
check(#out == 0 and ready == 0, "objet introuvable : rien")
-- Fabrication d'avance : candidats moins stock, plafonnee.
check(S.demand(6, 0, 4) == 4 and S.demand(3, 1, 4) == 2 and S.demand(3, 5, 4) == 0, "demande de fabrication")
-- Determinisme : meme entree, meme sortie.
ctx.obtainable, ctx.have = true, 5
local a = S.plan(entries, ctx)
local b = S.plan({ entries[4], entries[3], entries[2], entries[1] }, ctx)
check(#a == #b and a[1].id == b[1].id and a[2].id == b[2].id, "ordre des entrees sans effet")

print(string.format("[FOREUSES] BILAN : %d OK, %d ECHEC(S)", ok_n, ko_n))
os.exit(ko_n == 0 and 0 or 1)
