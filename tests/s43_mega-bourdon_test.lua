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
ck(X:find("an.created_effect, an.sound = nil, nil", 1, true) ~= nil, "effets : anneaux sans particules ni son")
ck(S:find("ARME_MEGA = B.arme_lourde(B.arme_mega(", 1, true) ~= nil and S:find("pr and pr.drawing_box) or false", 1, true) ~= nil,
  "script : arme lourde, boîte de dessin lue dans le prototype")
print(string.format("[S43-MEGA-BOURDON] BILAN : %d OK, %d ECHEC(S)", ok, ko))
os.exit(ko == 0 and 0 or 1)
