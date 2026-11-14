--[[
  s43 MEGA-BOURDON (ordre du DC du 13/11) : le Méga-Bourdon tire à son gabarit.
  Usage, depuis la racine du mod :   lua5.2 tests/s43_mega-bourdon_test.lua
  1. PORTÉE : PORTEE_BORD × le bord de sa boîte de dessin (Bourdon × ECHELLE), au-delà du bord de l'image, ordre de l'artillerie ;
     vitesse de l'orbe à proportion (temps de vol de l'orbe Bastion gardé).
  2. ZONE : rayon au moins 4 fois les 20 tuiles d'avant ; DÉGÂTS : × DEGATS_X sur la valeur au plus juste (gardée dans a.juste).
  3. ANNEAUX : explosions décalées sur la zone, rayons dans [0, rayon], nombre borné (UPS).
  4. BRANCHEMENT : prototype (nids et vers dans l'essaim, arme lourde), effets (anneau branché), script (arme lourde, boîte lue).
]]
package.path = "./?.lua;" .. package.path
local B = require("shared.robots.bourdon")
local A = require("shared.content.arsenal")
local Ech = require("shared.robots.echelle")

local ok, ko = 0, 0
local function ck(c, m) if c then ok = ok + 1 else ko = ko + 1; print("  ECHEC : " .. m) end end
local function lire(p) local f = io.open(p, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return s end

-- 1. portée
local BOITE_BOURDON = { { -40, -66 }, { 40, 26 } } -- prototypes/bourdon.lua, drawing_box du Bourdon
local bm = B.boite_mega(BOITE_BOURDON)
ck(math.abs(B.bord(bm) - 66 * B.MEGA.ECHELLE) < 1e-9, "bord de l'image du Méga-Bourdon : 66 × ECHELLE")
ck(B.bord({ left_top = { x = -3, y = -9 }, right_bottom = { x = 5, y = 2 } }) == 9, "bord : forme lue en jeu (left_top, right_bottom)")
ck(B.bord(nil) == 0 and B.bord({}) == 0, "bord : sans boîte, 0")
local spec = A.age_turret(B.MEGA.ARME_AGE)
local a = B.arme_mega(spec, Ech.salve(B.AGE, "laser"), Ech.salve(B.AGE, "explosion"))
local L = B.arme_lourde(a, bm)
ck(type(L) == "table", "arme lourde calculée")
ck(L.portee >= 1.2 * B.bord(bm), "portée nettement au-delà du bord de l'image (" .. L.portee .. " tuiles)")
ck(L.portee >= 5 * spec.range, "portée : au moins 5 fois celle de l'orbe Bastion (" .. spec.range .. ")")
ck(L.portee >= 150 and L.portee <= 300, "portée de l'ordre de l'artillerie vanilla (224)")
ck(math.abs(L.portee / L.vitesse - spec.range / spec.plasma.speed) < 1e-6, "temps de vol de l'orbe Bastion gardé")
ck(L.portee_min == a.portee_min and L.recharge == a.recharge, "portée minimale et cadence inchangées")
ck(B.arme_lourde(a, nil).portee == spec.range, "sans boîte : la portée de l'orbe Bastion")
ck(B.arme_lourde(nil, bm) == nil, "arme lourde : entrée invalide")
-- 2. zone et dégâts
ck(L.rayon >= 4 * 20, "rayon de zone au moins 4 fois les 20 tuiles d'avant (" .. L.rayon .. ")")
ck(L.rayon == spec.plasma.radius * B.MEGA.RAYON_X, "rayon : orbe Bastion × RAYON_X")
ck(B.MEGA.DEGATS_X >= 10, "dégâts massivement augmentés (× 10 au moins)")
ck(L.direct == math.ceil(B.MEGA.DEGATS_X * a.direct) and L.zone_laser == math.ceil(B.MEGA.DEGATS_X * a.zone_laser)
  and L.zone_explosion == math.ceil(B.MEGA.DEGATS_X * a.zone_explosion), "coup direct et zones × DEGATS_X")
ck(L.juste.direct == a.direct and L.juste.zone_laser == a.zone_laser and a.direct < L.direct, "valeurs au plus juste gardées, arme d'origine intacte")
local ess = { { nom = "gros", pv = 8e6, res = { laser = { decrease = 10, percent = 20 }, explosion = { decrease = 10, percent = 30 } } } }
local Lm = B.arme_lourde(B.arme_mega(spec, Ech.salve(B.AGE, "laser"), Ech.salve(B.AGE, "explosion"), ess), bm)
ck(B.zone_tue(Lm.zone_laser, Lm.zone_explosion, { pv = B.MEGA.DEGATS_X * 0.9 * 8e6, res = ess[1].res }), "la zone lourde tue 9 fois la plus forte")
-- 3. anneaux
local an = B.anneaux(L.rayon)
local n = 0
for _, x in ipairs(B.MEGA.ANNEAUX) do n = n + x[2] end
ck(#an == n and n <= 48, "anneaux : " .. n .. " explosions (48 au plus, UPS)")
local dmin, dmax = 1e9, 0
for _, o in ipairs(an) do
  local d = math.sqrt(o[1] * o[1] + o[2] * o[2])
  if d < dmin then dmin = d end
  if d > dmax then dmax = d end
end
ck(dmax <= L.rayon and dmax >= 0.8 * L.rayon, "anneau extérieur au bord de la zone")
ck(dmin >= 0.2 * L.rayon, "anneau intérieur hors de l'impact central")
ck(#B.anneaux(0) == 0 and #B.anneaux(nil) == 0, "anneaux : rayon nul, aucune")
-- impact et bornes
local Fx = require("shared.content.effets_armes")
local J = B.impact_mega(Fx.MODES.plasma.impact)
local Bo = B.bornes_mega(Fx.BORNES)
ck(Bo.duree_max == Fx.BORNES.duree_max * B.MEGA.DUREE_X and J.choc.duree <= Bo.duree_max, "durées doublées, dans les bornes du Méga-Bourdon")
ck(J.choc.echelle >= 1.5 * L.rayon, "onde de choc au sol : au moins les trois quarts du diamètre de la zone")
-- 4. branchement
local P, X, S = lire("prototypes/bourdon.lua"), lire("prototypes/effets_armes.lua"), lire("script/robots/bourdon.lua")
ck(P:find('for _, ty in ipairs({ "unit-spawner", "turret" }) do', 1, true) ~= nil, "prototype : nids et vers dans l'essaim")
ck(P:find("arme = assert(Bm.arme_lourde(arme, boite_mega)", 1, true) ~= nil, "prototype : l'orbe prend l'arme lourde")
ck(P:find("{ type = \"area\", radius = arme.rayon,", 1, true) ~= nil and P:find("amount = arme.zone_laser", 1, true) ~= nil, "prototype : zone au rayon et aux dégâts de l'arme")
ck(X:find("ajoute_cible(orbe.action, { type = \"create-entity\", entity_name = an.name, offsets = Bm.anneaux(rayon) })", 1, true) ~= nil, "effets : anneaux branchés")
ck(X:find("layers = { feuille_anim(\"onde\", c, d_an, t_an), feuille_anim(\"eclat\", c, 0.6 * d_an, t_an) }", 1, true) ~= nil
  and X:find("massive-explosion", 1, true) == nil, "effets : anneaux lumineux (onde et éclair du mod), plus de fumée vanilla")
ck(S:find("ARME_MEGA = B.arme_lourde(B.arme_mega(", 1, true) ~= nil and S:find("pr and pr.drawing_box) or false", 1, true) ~= nil,
  "script : arme lourde, boîte de dessin lue dans le prototype")
-- 5. tranche 2 : plafond de la cascade des couvées (shared/combat/couvee.lua)
local Cv = require("shared.combat.couvee")
local f = Cv.file()
for i = 1, 3 do ck(Cv.ajouter(f, i), "petite file : naissance gardée") end
local t = Cv.tranche(f, 32)
ck(#t == 3 and t[1] == 1 and t[3] == 3 and Cv.taille(f) == 0, "petit combat : toutes les naissances au tick suivant, dans l'ordre")
-- cascade : chaque tick, toutes les unités nées meurent (arme de zone) et chacune demande 2 naissances
local vivants, pire, total = 2 ^ 11, 0, 0 -- une couvée du palier 12 : 2 048 descendants au dernier palier sans plafond
f = Cv.file()
for _ = 1, vivants do Cv.ajouter(f, 1) end
for _ = 1, 200 do
  local nes = #Cv.tranche(f, Cv.BUDGET_TICK)
  if nes > pire then pire = nes end
  total = total + nes
  for _ = 1, 2 * nes do Cv.ajouter(f, 1) end
end
ck(pire <= Cv.BUDGET_TICK, "cascade : au plus BUDGET_TICK naissances par tick (" .. pire .. ")")
ck(Cv.taille(f) <= Cv.ATTENTE_MAX and f.abandons > 0, "cascade : file bornée, le surplus abandonné (" .. f.abandons .. ")")
ck(#f.l <= 2 * Cv.ATTENTE_MAX + Cv.BUDGET_TICK, "file jamais vide : la liste ne grandit pas sans fin (" .. #f.l .. ")")
f = Cv.file()
for i = 1, Cv.ATTENTE_MAX + 5 do Cv.ajouter(f, i) end
ck(Cv.taille(f) == Cv.ATTENTE_MAX and f.abandons == 5, "au-delà d'ATTENTE_MAX : abandon compté")
local M = lire("script/world/enemy_mechanics.lua")
ck(M:find("Cv.ajouter(f, { n = child,", 1, true) ~= nil and M:find("Cv.tranche(f, Cv.BUDGET_TICK)", 1, true) ~= nil
  and M:find("Events.on_nth_tick(1, naissances)", 1, true) ~= nil, "enemy_mechanics : naissances par la file plafonnée")
local _, nce = M:gsub("create_entity", "")
ck(nce == 1, "enemy_mechanics : une seule pose d'unité")
-- 6. tranche 3 : éclair central au lieu de la big-explosion
ck(J.source == nil and J.choc ~= nil, "impact central : plus de big-explosion (fumée sombre), l'onde de choc le porte")
local blanc = { r = 1, g = 1, b = 1 }
local J3 = B.impact_mega(Fx.MODES.plasma.impact)
J3.couleur, J3.lumiere.couleur = blanc, blanc
ck(#Fx.verifier({ nom = "mega", mode = "plasma", couleur = blanc, impact = J3 }, Bo) == 0, "impact sans source : dans les bornes du Méga-Bourdon")
ck(X:find("ajoute_cible(orbe.action, { type = \"create-entity\", entity_name = ec.name })", 1, true) ~= nil, "effets : éclair central branché")
-- 7. tranche 4 : une salve sur 4 cibles distinctes
local function base(cx, cy, r, l)
  for dx = -r, r, 6 do for dy = -r, r, 6 do if dx * dx + dy * dy <= r * r then l[#l + 1] = { x = cx + dx, y = cy + dy } end end end
  return l
end
local R = L.rayon
local pts = base(150, 0, 28, {}) -- la base principale (dense) et trois voisines (banc megabourdon-salve), plus un nid isolé
base(150, -62, 16, pts); base(150, 62, 16, pts); base(212, 0, 16, pts)
pts[#pts + 1] = { x = 400, y = 400 }
local cs = B.cibles_salve(pts, 4, R)
ck(#cs == 4, "4 cibles pour 4 casemates")
local ok_ecart = true
for i = 1, #cs do for j = i + 1, #cs do
  local dx, dy = pts[cs[i]].x - pts[cs[j]].x, pts[cs[i]].y - pts[cs[j]].y
  if cs[i] ~= cs[j] and dx * dx + dy * dy < R * R then ok_ecart = false end
end end
ck(ok_ecart, "cibles distinctes écartées d'au moins un rayon d'impact")
local function couvert(p)
  for _, i in ipairs(cs) do
    local dx, dy = p.x - pts[i].x, p.y - pts[i].y
    if dx * dx + dy * dy <= R * R then return true end
  end
  return false
end
local tous = true
for k = 1, #pts - 1 do if not couvert(pts[k]) then tous = false end end
ck(tous, "la salve couvre la base visée et ses trois voisines (rayon " .. R .. ")")
ck(pts[cs[1]].x >= 122 and pts[cs[1]].x <= 178 and math.abs(pts[cs[1]].y) <= 28, "première cible : dans la base la plus dense")
local inv = {}
for k = #pts, 1, -1 do inv[#inv + 1] = pts[k] end
local cs2 = B.cibles_salve(inv, 4, R)
local memes = true
for i = 1, 4 do if pts[cs[i]].x ~= inv[cs2[i]].x or pts[cs[i]].y ~= inv[cs2[i]].y then memes = false end end
ck(memes, "choix déterministe : l'ordre d'entrée ne compte pas")
local un = B.cibles_salve({ { x = 1, y = 1 }, { x = 2, y = 1 } }, 4, R)
ck(#un == 4 and un[1] == un[2] and un[1] == un[4], "une seule zone : les 4 casemates sur la même cible")
ck(#B.cibles_salve({}, 4, R) == 0 and #B.cibles_salve(nil, 4, R) == 0, "aucun point : aucune cible")
ck(S:find("for _, i in ipairs(B.cibles_salve(pts, B.MEGA.CANONS, a.rayon)) do", 1, true) ~= nil
  and S:find("local cible = #cs > 0 and cs[(k - 1) % #cs + 1] or nil", 1, true) ~= nil, "script : une cible de salve par casemate")
print(string.format("[S43-MEGA-BOURDON] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
