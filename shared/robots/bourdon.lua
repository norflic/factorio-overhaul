--[[
  LE BOURDON, expérimental de l'âge 15 : règles pures (lot BOURDON, 1er/11). Aucun appel moteur : géométrie, temps du Glas,
  dégâts, plan des fissures, table des directions (pas de trigonométrie dans la simulation).

  Repère : tuiles à l'écran depuis la position au sol de l'entité (y vers le bas). Une hauteur z se voit à z × √½ (F47).
  Orientation d'une image : fraction de tour, sens des aiguilles (rendering) ; l'axe x de l'image va en (cos, sin) de
  l'orientation, son axe y (vers le bas) en (−sin, cos).
]]

local B = {}

B.NOM = "fo-bourdon"

-- ------------------------------------------------------------------------------------------------ directions
-- 256 pas par tour : récurrence de rotation, constantes écrites (cos et sin de 2π / 256).
local N_DIR = 256
local COS_T, SIN_T = {}, {}
do
  local c1, s1 = 0.99969881869620, 0.02454122852291
  local c, s = 1.0, 0.0
  for k = 0, N_DIR - 1 do
    -- recale les quadrants exacts, pour que l'erreur d'arrondi ne s'accumule pas
    if k % 64 == 0 then
      local q = k / 64
      c = (q == 0 and 1.0) or (q == 2 and -1.0) or 0.0
      s = (q == 1 and 1.0) or (q == 3 and -1.0) or 0.0
    end
    COS_T[k] = c
    SIN_T[k] = s
    c, s = c * c1 - s * s1, s * c1 + c * s1
  end
end

--- (cos, sin) d'une orientation en fraction de tour, interpolés dans la table.
function B.dir(o)
  local p = (o % 1) * N_DIR
  local k = math.floor(p)
  if k >= N_DIR then p, k = 0, 0 end -- (-1e-17) % 1 vaut 1 en virgule flottante
  local f = p - k
  local k2 = (k + 1) % N_DIR
  return COS_T[k] * (1 - f) + COS_T[k2] * f, SIN_T[k] * (1 - f) + SIN_T[k2] * f
end

-- ------------------------------------------------------------------------------------------------ géométrie
B.COS45 = 0.70710678
-- Ombre : soleil plein ouest à 48° (tools/render/fo_calib.py) : une hauteur z porte à 0,9 × z vers l'est.
B.OMBRE_PAR_Z = 0.9
B.Z_LEVRE = 33.0
B.PIVOT = { 0.0, -28.284 }       -- attache du battant : z = 40 (screen 40 × √½)
B.CHAINE_LONG = 36.925           -- longueur de la feuille de chaîne à l'écran, en tuiles (sprites.lua, chaine.long)
B.CHAINE_OMBRE_LONG = 36.0       -- longueur de la feuille d'ombre de chaîne
B.ANCRE_TETE = 2.333             -- hauteur à l'écran de la tête d'ancre (z = 3,3), où finit la chaîne
B.PLIEE = 7.0                    -- ancre repliée : la chaîne dépasse de tant sous la lèvre

-- Les 6 ancres, dans l'ordre des rendus (tools/render/pieces/experimentaux/bourdon.py, ANCRES).
-- sol : ancre posée ; levre : sortie de la chaîne ; u : direction lèvre vers ancre ; o : orientation de la chaîne.
B.ANCRES = {
  { sol = { -30.764, 10.236 }, levre = { -13.301, -18.909 }, u = { -0.5458, 0.8379 }, long = 31.997, o = 0.0919, ombre_long = 47.520, ombre_o = 0.7305, ombre_u = { 0.9925, -0.1223 } },
  { sol = { 0.000, 21.920 }, levre = { 0.000, -12.940 }, u = { 0.0000, 1.0000 }, long = 32.527, o = 0.0000, ombre_long = 31.858, ombre_o = 0.6911, ombre_u = { 0.9323, -0.3618 } },
  { sol = { 30.764, 10.236 }, levre = { 13.301, -18.909 }, u = { 0.5458, 0.8379 }, long = 31.997, o = 0.9081, ombre_long = 13.546, ombre_o = 0.6794, ombre_u = { 0.9033, -0.4289 } },
  { sol = { 25.889, -13.300 }, levre = { 11.893, -29.444 }, u = { 0.7118, 0.7024 }, long = 19.663, o = 0.8739, ombre_long = 17.272, ombre_o = 0.8183, ombre_u = { 0.9092, 0.4163 } },
  { sol = { 0.000, -21.213 }, levre = { 0.000, -33.729 }, u = { 0.0000, 1.0000 }, long = 10.182, o = 0.0000, ombre_long = 31.609, ombre_o = 0.8056, ombre_u = { 0.9396, 0.3423 } },
  { sol = { -25.889, -13.300 }, levre = { -11.893, -29.444 }, u = { -0.7118, 0.7024 }, long = 19.663, o = 0.1261, ombre_long = 44.284, ombre_o = 0.7760, ombre_u = { 0.9867, 0.1624 } },
}

--- Bas de la chaîne (écran, depuis la position au sol) pour une extension e : 0 repliée, 1 posée.
function B.bas_chaine(i, e)
  local a = B.ANCRES[i]
  local px, py = a.levre[1] + a.u[1] * B.PLIEE, a.levre[2] + a.u[2] * B.PLIEE
  local qx, qy = a.sol[1], a.sol[2] - B.ANCRE_TETE
  return px + (qx - px) * e, py + (qy - py) * e
end

--- Centre de la feuille de chaîne dont le bas est en (bx, by) : elle glisse dans la cloche (elle est dessinée derrière).
function B.centre_chaine(i, bx, by)
  local a = B.ANCRES[i]
  local h = B.CHAINE_LONG / 2
  return bx - a.u[1] * h, by - a.u[2] * h
end

--- Position de l'ancre (son point au sol, pour les décalages des couches) quand le bas de sa chaîne est en (bx, by).
function B.ancre_depuis_bas(bx, by)
  return bx, by + B.ANCRE_TETE
end

-- ------------------------------------------------------------------------------------------------ temps
B.RECHARGE_AUTO = 1200      -- Glas automatique sur cible en portée : toutes les 20 s
B.RECHARGE_ORDRE = 300      -- par ordre du joueur : 5 s
B.CHARGE = 70               -- le battant recule, les vitraux montent, avant le coup
B.PORTEE = 60.0             -- rayon des dégâts
B.PORTEE_AUTO = 50.0        -- une cible à moins de tant déclenche le Glas automatique
B.VITESSE_ONDE = 0.85       -- tuiles par tick
B.R_FIN = 76.0              -- l'onde visible s'éteint à ce rayon
B.DEBUT_ONDE2 = 22          -- seconde onde, plus faible
B.VITESSE_ONDE2 = 0.68
B.R_FIN2 = 58.0
B.DESCENTE = 300            -- ticks de la descente
B.DESCENTE_H = 90.0         -- hauteur de départ à l'écran au-dessus de la pose
B.CHUTE = 40                -- ticks de chute d'une ancre
B.CHUTE_PAS = 7             -- décalage entre 2 ancres
B.LEVE = 56                 -- ticks de remontée d'une ancre
B.LEVE_PAS = 5
B.BALANCEMENT_PERIODE = 330 -- période du flottement

B.DEGAT_CENTRE = 2500
B.DEGAT_BORD = 700
B.TRANCHE = 3               -- largeur d'une tranche de la liste des cibles, en tuiles

function B.rayon(t) return t <= 0 and 0.0 or t * B.VITESSE_ONDE end
function B.rayon2(t) return t <= B.DEBUT_ONDE2 and 0.0 or (t - B.DEBUT_ONDE2) * B.VITESSE_ONDE2 end
function B.fin_onde() return math.ceil(B.R_FIN / B.VITESSE_ONDE) end
function B.fin_onde2() return B.DEBUT_ONDE2 + math.ceil(B.R_FIN2 / B.VITESSE_ONDE2) end

--- Dégâts à la distance r du centre ; 0 au-delà de la portée.
function B.degats(r)
  if r > B.PORTEE then return 0 end
  return B.DEGAT_CENTRE + (B.DEGAT_BORD - B.DEGAT_CENTRE) * (r / B.PORTEE)
end

--- Tranche de la liste des cibles à la distance r (1 pour le centre).
function B.tranche(r)
  return math.floor(r / B.TRANCHE) + 1
end

-- interpolation par morceaux dans une table { {t, v}, ... } triée
local function courbe(tab, t)
  if t <= tab[1][1] then return tab[1][2] end
  for i = 2, #tab do
    local a, b = tab[i - 1], tab[i]
    if t <= b[1] then
      return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])
    end
  end
  return tab[#tab][2]
end
B.courbe = courbe

-- t : ticks depuis le coup (négatif : la charge). Écart du battant vers la cible, en fraction de tour (négatif : il recule).
local BALANCE = {
  { -70, 0.0 }, { -22, -0.0625 }, { -10, -0.06 }, { 0, 0.04 }, { 18, -0.022 }, { 42, 0.0125 }, { 72, -0.0062 }, { 108, 0.0028 }, { 150, 0.0 },
}
local VITRAUX = { { -70, 1.0 }, { -2, 1.9 }, { 0, 3.0 }, { 16, 2.3 }, { 36, 1.75 }, { 70, 1.3 }, { 120, 1.0 } }
local CRISTAL = { { -70, 1.0 }, { -2, 1.9 }, { 0, 3.0 }, { 14, 2.4 }, { 36, 1.6 }, { 70, 1.2 }, { 120, 1.0 } }
B.FIN_BALANCE = 150

--- Orientation à donner au battant : sens +1 si le coup part vers l'est, −1 sinon. Une orientation positive porte le bas du battant vers
--- l'ouest (sens des aiguilles autour du pivot) : d'où le signe moins.
function B.balance(t, sens) return -courbe(BALANCE, t) * (sens or 1) end
function B.vitraux(t) return courbe(VITRAUX, t) end
function B.cristal(t) return courbe(CRISTAL, t) end

--- Une intensité i (1 à 3) répartie sur les 3 copies additives : rend le blanc de chacune, de 0 à 1.
function B.copies(i)
  local a = i >= 1 and 1.0 or i
  local b = math.max(0.0, math.min(1.0, i - 1))
  local c = math.max(0.0, math.min(1.0, i - 2))
  return a, b, c
end

--- Décalage du centre d'une couche du battant, tournée de `o` (fraction de tour) autour du pivot.
function B.centre_battant(sx, sy, o)
  local cx, sn = B.dir(o)
  local vx, vy = sx - B.PIVOT[1], sy - B.PIVOT[2]
  return B.PIVOT[1] + vx * cx - vy * sn, B.PIVOT[2] + vx * sn + vy * cx
end

--- Flottement vertical à l'écran, au tick donné (tuiles).
function B.flottement(tick, id)
  local p = (tick + (id or 0) * 97) % B.BALANCEMENT_PERIODE
  local _, s = B.dir(p / B.BALANCEMENT_PERIODE)
  return s * 0.32
end

--- Balancement latéral d'une ancre repliée, à l'écran.
function B.oscille(tick, i)
  local p = (tick + i * 61) % 170
  local _, s = B.dir(p / 170)
  return s * 0.45
end

--- Descente : hauteur restante à l'écran, t de 0 à DESCENTE, freinée à la fin.
function B.hauteur_descente(t)
  if t >= B.DESCENTE then return 0.0 end
  local f = 1 - t / B.DESCENTE
  return B.DESCENTE_H * f * f * f
end

--- Extension d'une ancre pendant sa chute (gravité), u de 0 à 1.
function B.ext_chute(u)
  if u <= 0 then return 0.0 end
  if u >= 1 then return 1.0 end
  return u * u
end

--- Extension d'une ancre pendant sa remontée (treuil, départ lent), u de 0 à 1.
function B.ext_leve(u)
  if u <= 0 then return 1.0 end
  if u >= 1 then return 0.0 end
  return 1 - u * u * (3 - 2 * u)
end

-- ------------------------------------------------------------------------------------------------ onde
B.CRETES = 96       -- morceaux d'arc de la crête
B.POUSSIERES = 56   -- morceaux de chacun des 2 rangs du mur de poussière
B.CRETES2 = 48      -- seconde onde
B.CRETE_LONG = 12.0 -- longueur de la feuille de crête (tuiles)
B.POUSSIERE_LONG = 16.0

--- Échelle en longueur d'un morceau d'arc au rayon r : les morceaux se recouvrent de 35 %, jamais d'écrasement sous 0,18.
function B.echelle_arc(r, n, long)
  local arc = 6.2832 * r / n * 1.35
  local e = arc / long
  return e < 0.18 and 0.18 or e
end

--- Force de l'onde au rayon r : pleine jusqu'à la portée, puis s'éteint.
function B.force_onde(r)
  if r <= B.PORTEE then return 1.0 end
  if r >= B.R_FIN then return 0.0 end
  return 1.0 - (r - B.PORTEE) / (B.R_FIN - B.PORTEE)
end

--- Hauteur du mur de poussière à l'écran : il monte avec le rayon.
function B.hauteur_poussiere(r)
  return 1.2 + r * 0.075
end

-- ------------------------------------------------------------------------------------------------ fissures
-- Générateur maison (congruence), jamais le hasard du moteur.
local function alea(etat)
  etat.v = (etat.v * 16807) % 2147483647
  return etat.v / 2147483647
end
B.alea = alea

B.FISSURE_PAS = 5.0      -- longueur d'un segment
B.FISSURE_LONG = 8.0     -- longueur de la feuille
B.MAX_SEGMENTS = 340

local function trace(segs, etat, x, y, o, long, epais, dov, niveau)
  local pas = B.FISSURE_PAS
  local n = math.floor(long / pas)
  for i = 1, n do
    if #segs >= B.MAX_SEGMENTS then return end
    o = o + (alea(etat) - 0.5) * dov
    local c, s = B.dir(o)
    local x2, y2 = x + c * pas, y + s * pas
    -- rayon d'arrivée de l'onde sur le milieu du segment
    local mx, my = (x + x2) / 2, (y + y2) / 2
    segs[#segs + 1] = {
      x = mx, y = my, o = o, r = math.sqrt(mx * mx + my * my),
      v = 1 + math.floor(alea(etat) * 6) % 6, -- feuille (1 à 6)
      e = epais * (1 - 0.55 * i / n),
      n = niveau,
      -- vies : aléa fixe au plan, pour une cicatrice qui se referme morceau par morceau
      vc = alea(etat), vh = alea(etat),
    }
    x, y = x2, y2
    if niveau == 0 and alea(etat) < 0.32 and i > 1 then
      local cote = alea(etat) < 0.5 and -1 or 1
      trace(segs, etat, x, y, o + cote * (0.05 + 0.08 * alea(etat)), (n - i + 1) * pas * (0.3 + 0.35 * alea(etat)), epais * 0.55, dov * 1.2, 1)
    end
  end
end

--- Plan des fissures autour du centre : 18 rayons, plus longs sur le côté de la cible.
-- cible_o : orientation vers la cible (ou nil). Rend une liste de segments triée par rayon d'arrivée croissant.
function B.plan_fissures(graine, cible_o)
  local etat = { v = (graine % 2147483647) + 1 }
  for _ = 1, 3 do alea(etat) end
  local segs = {}
  local n = 18
  for i = 0, n - 1 do
    local o = i / n + 0.01 * (alea(etat) - 0.5)
    local long = 46.0 + 11.0 * (i % 3) + 6.0 * alea(etat)
    local epais = (i % 3 == 0) and 1.0 or 0.62
    if cible_o then
      local d = (o - cible_o) % 1
      if d > 0.5 then d = 1 - d end
      if d < 0.12 then long = long * 1.25; epais = epais * 1.2 end
    end
    local c, s = B.dir(o)
    trace(segs, etat, c * 4.5, s * 4.5, o, long, epais, 0.085, 0)
  end
  -- tri stable par rayon d'arrivée (l'ordre de création des segments départage)
  for i, sg in ipairs(segs) do sg.i = i end
  table.sort(segs, function(a, b)
    if a.r ~= b.r then return a.r < b.r end
    return a.i < b.i
  end)
  return segs
end

--- Tri par nom : l'ordre de game.forces n'est jamais utilisé (déterminisme).
function B.trie(noms)
  table.sort(noms)
  return noms
end

return B
