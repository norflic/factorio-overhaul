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

--- Lot ART-MEGA2 : k (1 par défaut) = échelle de la cloche (B.echelle) ; toute la géométrie ci-dessous (lèvre, sol, chaîne, ancre) en est
--- multipliée : le Méga-Bourdon, 2,2 fois plus grand, garde les mêmes 6 ancres, homothétiques depuis sa position au sol.
--- Bas de la chaîne (écran, depuis la position au sol) pour une extension e : 0 repliée, 1 posée.
function B.bas_chaine(i, e, k)
  k = k or 1
  local a = B.ANCRES[i]
  local px, py = (a.levre[1] + a.u[1] * B.PLIEE) * k, (a.levre[2] + a.u[2] * B.PLIEE) * k
  local qx, qy = a.sol[1] * k, (a.sol[2] - B.ANCRE_TETE) * k
  return px + (qx - px) * e, py + (qy - py) * e
end

--- Centre de la feuille de chaîne dont le bas est en (bx, by) : elle glisse dans la cloche (elle est dessinée derrière).
function B.centre_chaine(i, bx, by, k)
  local a = B.ANCRES[i]
  local h = B.CHAINE_LONG * (k or 1) / 2
  return bx - a.u[1] * h, by - a.u[2] * h
end

--- Position de l'ancre (son point au sol, pour les décalages des couches) quand le bas de sa chaîne est en (bx, by).
function B.ancre_depuis_bas(bx, by, k)
  return bx, by + B.ANCRE_TETE * (k or 1)
end

--- Point au sol de l'ancre i (écran, depuis la position au sol de la cloche), à l'échelle k.
function B.sol(i, k)
  local a = B.ANCRES[i]
  k = k or 1
  return a.sol[1] * k, a.sol[2] * k
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
function B.centre_battant(sx, sy, o, k)
  k = k or 1 -- lot ART-MEGA2 : échelle de la cloche ; (sx, sy) est déjà à cette échelle
  local cx, sn = B.dir(o)
  local px, py = B.PIVOT[1] * k, B.PIVOT[2] * k
  local vx, vy = sx - px, sy - py
  return px + vx * cx - vy * sn, py + vx * sn + vy * cx
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

-- ------------------------------------------------------------------------------------------------ fabrication (lot ROBOTS-JEU, 3/11)
-- Le Bourdon se FABRIQUE au Portique (âge 15) : un objet de pile 1, posé à la main là où il doit descendre. L'objet pose une entité
-- RELAIS (`B.POSE`, simple-entity-with-owner) que le script remplace par la descente : il ne pose jamais directement le `spider-vehicle`,
-- car le cerveau des factions lit tout `spider-vehicle` qu'un objet pose (script/ai3/general.lua, dump.units) et commanderait le Bourdon
-- sans savoir le sortir (aucune faction ne le fabrique : choix déclaré). Il compte pour un GÉANT au plafond (Ro.giant_allowed).
B.OBJET = "fo-bourdon-item"
B.POSE = "fo-bourdon-pose"
B.RECETTE = "fo-robot-make-bourdon"
B.TECHNO = "fo-robot-bourdon"
B.USINE = "fo-robot-gantry"
B.AGE = 15
-- Au plus 100 de chaque ingrédient (RB0-1) ; 10 segments du Couronné (dock) : la cloche vient après le dernier géant.
B.FAB = {
  temps = 180,
  ingredients = { { "fo-robot-segment-crowned", 10 }, { "fo-brass", 100 }, { "fo-superconducting-coil", 100 }, { "fo-guidance-core", 100 },
    { "fo-laser-module", 100 } },
}
B.TECH = { name = B.TECHNO, epoch = B.AGE, count = 400, time = 30, prerequisites = { "fo-robot-gantry-crowned" } }

--- Un Bourdon fabriqué peut-il descendre ? p = { actif (réglage fo-war-robots), geants (géants vivants de la force, Bourdons compris),
--- admis (géants admis à son âge) }. Les commandes de démonstration (/fo-bourdon) ne passent pas par ici.
--- Lot MEGA-BOURDON : p.poids (1 par défaut) = géants que la cloche comptera ; le Méga-Bourdon (2) demande deux places libres.
function B.peut_poser(p)
  if type(p) ~= "table" or not p.actif then return false end
  return (p.geants or 0) + (p.poids or 1) <= (p.admis or 0)
end

-- ------------------------------------------------------------------------------------------------ sortie du Portique (lot BOURDON-SORTIE, 4/11)
-- QCM-4/11 du DC : « sortie automatique mais on doit pouvoir les déplacer manuellement hein, contrôler les robots ». Le Bourdon fini SORT SEUL
-- du Portique, comme un kit de robot (script/robots/usine.lua, balayage toutes les 60 ticks) : il descend au point de sortie de l'usine, puis
-- vole à son ralliement. Plafond atteint : l'objet reste en sortie et le Portique s'arrête, comme pour les autres géants.
B.RALLIEMENT_MIN = 6 -- tuiles : plus près que cela du point de descente, il reste posé (ni ancres levées, ni vol pour rien)

--- Le Bourdon en sortie d'un Portique doit-il sortir ? p = { objets (Bourdons finis dans la sortie), faction (vrai : l'usine est à une faction),
--- actif, geants (géants vivants de la force, Bourdons compris), admis }.
--- Lot BOURDON-MINEURS (4/11) : `geants` compte déjà les géants sortis pendant le même balayage (Armee.create les inscrit au registre, et un Bourdon
--- descendu est dans la liste du script dès M.descendre) : plus de compte « deja » en plus, qui les comptait deux fois.
--- Une FACTION ne sort pas de Bourdon : aucune ne le commande (le cerveau ne voit que les objets qui posent une unité, et l'objet pose un relais),
--- et le Bourdon n'a pas de rôle de faction (ni garnison, ni raid : script/faction/military.lua ne l'adopte pas) ; l'objet resterait en sortie.
function B.sortie(p)
  if type(p) ~= "table" or (p.objets or 0) < 1 or p.faction then return false end
  return B.peut_poser({ actif = p.actif, geants = p.geants, admis = p.admis, poids = p.poids })
end

-- Commande par l'outil Armée (lot BOURDON-SORTIE) : les ordres de l'outil (script/robots/outils.lua) deviennent un vol et un Glas.
B.APPROCHE = 35.0 -- tuiles : une cible hors de portée, il s'arrête à cette distance d'elle, sur la droite qui l'y mène, puis sonne

--- Ordre `kind` au Bourdon posé en p = { x, y } vers c = { x, y } : « move » -> { aller = c } ; « attack » : à portée (B.PORTEE_AUTO)
--- -> { glas = c } ; plus loin -> { aller = point à B.APPROCHE de c, glas = c } (il y va, puis sonne). nil : ordre inconnu ou point invalide.
function B.ordre(kind, p, c)
  if type(p) ~= "table" or type(c) ~= "table" then return nil end
  local px, py, cx, cy = p.x or p[1], p.y or p[2], c.x or c[1], c.y or c[2]
  if type(px) ~= "number" or type(py) ~= "number" or type(cx) ~= "number" or type(cy) ~= "number" then return nil end
  if kind == "move" then return { aller = { x = cx, y = cy } } end
  if kind ~= "attack" then return nil end
  local dx, dy = cx - px, cy - py
  local d = math.sqrt(dx * dx + dy * dy)
  if d <= B.PORTEE_AUTO then return { glas = { x = cx, y = cy } } end
  local k = (d - B.APPROCHE) / d
  return { aller = { x = px + dx * k, y = py + dy * k }, glas = { x = cx, y = cy } }
end

--- Lot BOURDON-MINEURS : un Glas en attente (commandé pendant un vol, une descente ou une recharge) est REVÉRIFIÉ au moment de partir, depuis
--- la position où la cloche s'est posée : à portée, il sonne ({ glas }) ; sinon elle s'approche d'abord ({ aller, glas }), l'attente est gardée.
function B.reprise_glas(p, cible) return B.ordre("attack", p, cible) end

--- Après sa descente au point (x, y), le Bourdon vole-t-il au ralliement r = { x, y } ? Rend r, ou nil s'il est absent ou trop près.
function B.ralliement(x, y, r)
  if type(r) ~= "table" or type(r.x) ~= "number" or type(r.y) ~= "number" then return nil end
  local dx, dy = r.x - x, r.y - y
  if dx * dx + dy * dy < B.RALLIEMENT_MIN * B.RALLIEMENT_MIN then return nil end
  return { x = r.x, y = r.y }
end

-- ------------------------------------------------------------------------------------------------ le Méga-Bourdon (lot MEGA-BOURDON, 11/11)
-- Mandat du DC (10/11, 22 h 20, chantier A §2) : « une déclinaison lourde, massive et menaçante du bourdon, dotée d'armes lourdes intégrées
-- et de blindages angulaires taillés ». La même cloche (âge 15, le dernier : il n'y a pas d'âge suivant), cuirassée de plaques taillées,
-- cerclée d'un anneau de lévitation magnétique, avec 4 casemates de canons à plasma sur les épaules. Elle garde le Glas, la descente,
-- les ancres et la télécommande du Bourdon (script/robots/bourdon.lua, variante « mega »).
-- Règles dérivées, aucune valeur sans base :
-- - poids : il compte pour DEUX géants au plafond (Armee.giants) ; d'où le double des PV du Bourdon, le double de sa fabrication et de sa
--   technologie ;
-- - canons : l'orbe à plasma de la lignée Bastion d'armement 4 (shared/content/arsenal.lua, A.age_turret(4), la plus lourde) : portée,
--   portée minimale, cadence, vitesse et rayon de l'orbe repris tels quels ; dégâts portés à l'âge de la cloche par la règle d'échelle E3
--   (Ech.salve, comme les salves des titans) : une volée des CANONS livre la salve de l'âge 15, partagée entre coup direct, zone laser et
--   zone d'explosion dans les proportions de l'orbe Bastion.
-- Lot MEGA-BALISTIQUE (ordre du DC du 11/11 après son playtest : « dégâts décevants, zone d'impact ridicule ») :
-- - rayon : celui de l'orbe Bastion × RAYON_X (« radius = radius * 4 ») ; le Bastion et le Bourdon ne changent pas ;
-- - zone : un tir TUE D'UN COUP chaque unité d'essaim du mod (les unités que produisent les nids, data.raw["unit-spawner"],
--   titans exclus), PV et résistances laser et explosion lus dans data.raw au data stage : les deux zones de la salve sont
--   multipliées par le plus petit facteur (au moins 1) qui tue la plus forte d'entre elles, formule de dégâts du moteur ;
-- - coup direct : à lui seul, il tue d'un coup chaque unité d'essaim, la plus blindée au laser comprise (au moins la part
--   de la salve) ;
-- - effets : explosion, onde de choc, lumière et portée des étincelles de plasma de l'impact Bastion × RAYON_X (la feuille et
--   l'animation existantes, agrandies, à la lueur de l'orbe) ; nombre d'étincelles et durées gardés (UPS).
B.MEGA = {
  NOM = "fo-mega-bourdon",
  OBJET = "fo-mega-bourdon-item",
  POSE = "fo-mega-bourdon-pose",
  RECETTE = "fo-robot-make-mega-bourdon",
  TECHNO = "fo-robot-mega-bourdon",
  GEANTS = 2,     -- géants qu'il compte au plafond
  CANONS = 4,     -- casemates (tools/render/pieces/experimentaux/bourdon.py, MEGA_CANONS)
  N_DIR = 16,     -- directions rendues de chaque tourelle (bourdon.py, N_DIR_TOURELLE)
  CANON_L = 6.2,  -- longueur des canons depuis le pivot, à plat (bourdon.py, tourelle) : la bouche, d'où part l'orbe
  -- un cran (1/16 de tour) toutes les TOURNE ticks : la vitesse de la tourelle laser vanilla (rotation_speed 0,01 tour par tick), que le
  -- Bastion d'armement 4 copie : 1/16 de tour en 6,25 ticks, arrondi au tick supérieur
  TOURNE = 7,
  ARME_AGE = 4,   -- âge d'armement de la lignée Bastion dont il reprend l'orbe
  ORBE = "fo-mega-bourdon-orbe",
  -- Lot ART-MEGA2 (ordre du DC du 11/11, 9 h 47 : « une taille strictement 2 fois supérieure, minimum 200 % à 250 % de l'échelle du
  -- Bourdon ») : échelle du rendu (bourdon.py, MEGA_ECHELLE ; feuilles_mega.py l'écrit dans sprites.lua, « echelle », le test les compare).
  -- Tout ce que le Méga-Bourdon emprunte au Bourdon en est multiplié : chaînes, ancres, battant, griffes, boîtes, lumière.
  ECHELLE = 2.2,
  -- lot MEGA-BALISTIQUE : rayon de zone de l'orbe = rayon de l'orbe Bastion × RAYON_X (ordre du DC) ; s43 MEGA-BOURDON (ordre du DC du
  -- 13/11 : « au moins × 4 par rapport à aujourd'hui », une salve rase une base à 600 % et ses voisines) : 4 → 20, soit 20 → 100 tuiles
  RAYON_X = 20,
  -- s43 MEGA-BOURDON (même ordre) : portée « à son gabarit », bien au-delà du bord de son image : PORTEE_BORD × le plus grand écart de
  -- sa boîte de dessin à son origine (2,2 × 66 = 145 tuiles : 218 tuiles, l'ordre de la portée d'artillerie vanilla, 224) ; la vitesse
  -- de l'orbe suit (temps de vol de l'orbe Bastion gardé)
  PORTEE_BORD = 1.5,
  -- dégâts bruts : DEGATS_X × la zone et le coup direct « au plus juste » (B.arme_mega : tuer d'un coup la plus forte unité d'essaim)
  DEGATS_X = 10,
  -- effets : durées de l'impact et des ondes × DUREE_X (bornes des armes de même) ; ANNEAUX d'explosions (part du rayon, nombre)
  -- autour de l'impact : éclair et onde de choc lumineux du mod (feuilles « eclat » et « onde », teinte de l'orbe, additifs), de
  -- diamètre ANNEAU_PART × le rayon, sans particules, ni son, ni lumière moteur (UPS) ; tranche 2 : la massive-explosion vanilla
  -- finissait en fumées sombres (captures du 13/11)
  DUREE_X = 2,
  ANNEAUX = { { 0.3, 8 }, { 0.6, 12 }, { 0.9, 16 } },
  ANNEAU_PART = 0.25,
  ANNEAU = "fo-mega-bourdon-anneau",
  -- tranche 3 : éclair central lumineux (feuilles « onde » et « eclat », diamètres ECLAIR_PART × le rayon) au lieu de la big-explosion
  -- agrandie (sa fumée sombre couvrait la zone) ; effet `script` d'impact : les vers laissés à 0 PV par la zone meurent au même tick
  ECLAIR = "fo-mega-bourdon-eclair",
  ECLAIR_PART = { onde = 1.2, eclat = 0.5 },
  IMPACT_ID = "fo-mega-bourdon-impact",
  ACHEVE_TYPES = { "turret", "unit-spawner" },
  -- marge de précision : le moteur calcule dégâts et résistances en simple précision (24 bits de mantisse, 2^-24 perdu par opération) ;
  -- un tir « au plus juste » laissait la plus forte à une fraction de PV (banc megabourdon-vitrine du 11/11 : 8 des 9 survivent au
  -- premier impact). Tuer, c'est infliger au moins PV × (1 + 2^-10).
  MARGE = 2 ^ -10,
}

--- Échelle d'une variante de cloche : B.MEGA.ECHELLE pour « mega », 1 sinon.
function B.echelle(v)
  if v == "mega" then return B.MEGA.ECHELLE end
  return 1
end

--- Boîte (collision, sélection, dessin, autocollants) du Méga-Bourdon : celle du Bourdon à l'échelle B.MEGA.ECHELLE. Rend une nouvelle table.
function B.boite_mega(bx)
  local k = B.MEGA.ECHELLE
  return { { bx[1][1] * k, bx[1][2] * k }, { bx[2][1] * k, bx[2][2] * k } }
end

do
  local ings = { { B.OBJET, 1 } }
  for _, g in ipairs(B.FAB.ingredients) do ings[#ings + 1] = { g[1], g[2] } end
  -- le Bourdon lui-même, plus une seconde fois sa matière : deux géants, deux fois le prix
  B.FAB_MEGA = { temps = 2 * B.FAB.temps, ingredients = ings }
  B.TECH_MEGA = { name = B.MEGA.TECHNO, epoch = B.AGE, count = 2 * B.TECH.count, time = B.TECH.time, prerequisites = { B.TECHNO } }
end

--- Variante d'une entité : « bourdon », « mega », ou nil si ce n'est pas une cloche.
function B.variante(nom)
  if nom == B.NOM then return "bourdon" end
  if nom == B.MEGA.NOM then return "mega" end
  return nil
end

--- Nom de l'entité d'une variante (nil : variante inconnue).
function B.nom_de(v)
  if v == nil or v == "bourdon" then return B.NOM end
  if v == "mega" then return B.MEGA.NOM end
  return nil
end

--- Géants que compte une cloche au plafond (0 : pas une cloche).
function B.poids(nom)
  local v = B.variante(nom)
  if v == "bourdon" then return 1 end
  if v == "mega" then return B.MEGA.GEANTS end
  return 0
end

--- Variante posée par un relais (nil : pas un relais de cloche).
function B.variante_pose(nom)
  if nom == B.POSE then return "bourdon" end
  if nom == B.MEGA.POSE then return "mega" end
  return nil
end

--- PV du Méga-Bourdon depuis ceux du Bourdon.
function B.pv_mega(pv) return pv * B.MEGA.GEANTS end

--- Lot MEGA-BALISTIQUE : dégâts reçus (formule du moteur 1.1) d'un coup de d points contre la résistance r = { decrease, percent }
--- (nil : aucune) : la réduction fixe d'abord (au-dessous d'elle, 1 / (2 + réduction - d)), puis le pourcentage.
function B.degat_effectif(d, r)
  local dec, pct = r and r.decrease or 0, r and r.percent or 0
  local x
  if dec < d then x = d - dec else x = 1 / (2 + dec - d) end
  return x * (1 - pct / 100)
end

--- La zone (zl laser, ze explosion) tue-t-elle d'un coup la cible c = { nom, pv, res = { laser = r, explosion = r } } ?
function B.zone_tue(zl, ze, c)
  return B.degat_effectif(zl, c.res.laser) + B.degat_effectif(ze, c.res.explosion) >= c.pv * (1 + B.MEGA.MARGE)
end

--- Le coup direct (laser) seul tue-t-il d'un coup la cible c ?
function B.direct_tue(d, c) return B.degat_effectif(d, c.res.laser) >= c.pv * (1 + B.MEGA.MARGE) end

--- Arme des casemates. spec : A.age_turret(B.MEGA.ARME_AGE) (range, min_range, cooldown, plasma = { direct, radius, speed, area = { laser,
--- explosion } }) ; salve_laser, salve_explosion : Ech.salve(B.AGE, « laser » / « explosion »). cibles (lot MEGA-BALISTIQUE, facultatif) :
--- les unités d'essaim { nom, pv, res } lues dans data.raw ; sans elles, les seules parts de la salve. Rend la table de l'arme d'UNE
--- casemate, ou nil (entrée invalide, ou cible que rien ne tue).
function B.arme_mega(spec, salve_laser, salve_explosion, cibles)
  if type(spec) ~= "table" or type(spec.plasma) ~= "table" or type(spec.plasma.area) ~= "table" then return nil end
  if type(salve_laser) ~= "number" or type(salve_explosion) ~= "number" then return nil end
  local P = spec.plasma
  local tot = P.direct + P.area.laser + P.area.explosion
  if tot <= 0 then return nil end
  local n = B.MEGA.CANONS
  local a = {
    portee = spec.range, portee_min = spec.min_range or 0, recharge = spec.cooldown, vitesse = P.speed, rayon = P.radius * B.MEGA.RAYON_X,
    direct = math.ceil(salve_laser * P.direct / tot / n),
    zone_laser = math.ceil(salve_laser * P.area.laser / tot / n),
    zone_explosion = math.ceil(salve_explosion * P.area.explosion / tot / n),
    facteur = 1,
  }
  if cibles == nil then return a end
  if type(cibles) ~= "table" or #cibles == 0 then return nil end
  local zl, ze = a.zone_laser, a.zone_explosion
  local function tue(k, c) return B.zone_tue(math.ceil(k * zl), math.ceil(k * ze), c) end
  local k = 1
  for _, c in ipairs(cibles) do
    if type(c) ~= "table" or type(c.pv) ~= "number" or type(c.res) ~= "table" then return nil end
    if not tue(k, c) then
      local lo, hi = k, k * 2
      while not tue(hi, c) do
        lo, hi = hi, hi * 2
        if hi > 1e15 then return nil end
      end
      for _ = 1, 64 do
        local m = (lo + hi) / 2
        if tue(m, c) then hi = m else lo = m end
      end
      k = hi
      a.plus_forte = c.nom
    end
  end
  a.facteur = k
  a.zone_laser, a.zone_explosion = math.ceil(k * zl), math.ceil(k * ze)
  for _, c in ipairs(cibles) do
    local r = c.res.laser
    local pct = r and r.percent or 0
    if pct >= 100 then return nil end
    local d = math.ceil(c.pv * (1 + B.MEGA.MARGE) / (1 - pct / 100) + (r and r.decrease or 0))
    for _ = 1, 8 do
      if B.direct_tue(d, c) then break end
      d = d + 1
    end
    if not B.direct_tue(d, c) then return nil end
    if d > a.direct then a.direct, a.plus_blindee = d, c.nom end
  end
  return a
end

--- s43 MEGA-BOURDON (ordre du DC du 13/11) : plus grand écart à l'origine d'une boîte { { x1, y1 }, { x2, y2 } } ou { left_top = { x, y },
--- right_bottom = { x, y } } (forme lue en jeu) ; 0 sans boîte valide.
function B.bord(boite)
  local m = 0
  if type(boite) ~= "table" then return 0 end
  local coins = boite.left_top and { boite.left_top, boite.right_bottom } or boite
  for _, p in ipairs(coins) do
    if type(p) == "table" then
      for _, v in ipairs({ p[1] or p.x, p[2] or p.y }) do
        if type(v) == "number" and math.abs(v) > m then m = math.abs(v) end
      end
    end
  end
  return m
end

--- s43 MEGA-BOURDON : l'arme LOURDE du Méga-Bourdon depuis l'arme au plus juste a (B.arme_mega) et sa boîte de dessin : portée
--- max(portée de l'orbe Bastion, PORTEE_BORD × bord de l'image), vitesse de l'orbe à proportion (temps de vol gardé), coup direct et
--- zones × DEGATS_X (a.juste garde les valeurs au plus juste). Nouvelle table ; nil si a n'est pas une table.
function B.arme_lourde(a, boite)
  if type(a) ~= "table" then return nil end
  local o = {}
  for kk, v in pairs(a) do o[kk] = v end
  o.portee = math.max(a.portee, math.ceil(B.MEGA.PORTEE_BORD * B.bord(boite)))
  o.vitesse = a.vitesse * o.portee / a.portee
  o.juste = { direct = a.direct, zone_laser = a.zone_laser, zone_explosion = a.zone_explosion }
  o.direct = math.ceil(B.MEGA.DEGATS_X * a.direct)
  o.zone_laser = math.ceil(B.MEGA.DEGATS_X * a.zone_laser)
  o.zone_explosion = math.ceil(B.MEGA.DEGATS_X * a.zone_explosion)
  return o
end

--- s43 MEGA-BOURDON : décalages { x, y } des explosions en anneau autour de l'impact pour un rayon de zone r : B.MEGA.ANNEAUX (part du
--- rayon, nombre), directions par la table B.dir (sans trigonométrie), un anneau sur deux tourné d'un demi-pas. Liste dans l'ordre.
function B.anneaux(r)
  local o = {}
  if type(r) ~= "number" or r <= 0 then return o end
  for i, an in ipairs(B.MEGA.ANNEAUX) do
    local rr, n = an[1] * r, an[2]
    local dec = (i % 2 == 0) and 0.5 or 0
    for k = 0, n - 1 do
      local c, sn = B.dir((k + dec) / n)
      o[#o + 1] = { sn * rr, -c * rr }
    end
  end
  return o
end

--- Impact de l'orbe du Méga-Bourdon : copie de la recette d'impact de l'orbe Bastion (Fx.MODES.plasma.impact) à l'échelle du rayon
--- (B.MEGA.RAYON_X) : explosion, onde de choc, onde, lumière et portée des étincelles de plasma ; nombre d'étincelles et durées gardés ;
--- sans brûlure (celle de l'orbe reste). nil si i n'est pas une table.
function B.impact_mega(i)
  if type(i) ~= "table" then return nil end
  local function copie(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for kk, v in pairs(t) do o[kk] = copie(v) end
    return o
  end
  local k = B.MEGA.RAYON_X
  local c = copie(i)
  if c.echelle then c.echelle = c.echelle * k end
  for _, q in ipairs({ "choc", "onde", "distorsion" }) do
    if c[q] then c[q].echelle = c[q].echelle * k end
  end
  if c.lumiere then c.lumiere.taille = c.lumiere.taille * k end
  if c.etincelles then c.etincelles.vitesse = c.etincelles.vitesse * k end
  -- s43 MEGA-BOURDON : durées de l'explosion et des ondes × DUREE_X (nombre d'étincelles gardé)
  local dx = B.MEGA.DUREE_X
  if c.duree then c.duree = c.duree * dx end
  for _, q in ipairs({ "choc", "onde", "distorsion" }) do
    if c[q] and c[q].duree then c[q].duree = c[q].duree * dx end
  end
  c.brulure = nil
  c.source = nil -- s43 tranche 3 : plus de big-explosion (fumée sombre) ; l'onde de choc au sol porte l'impact, l'éclair central s'y ajoute
  return c
end

--- Bornes de vérification des effets du Méga-Bourdon : celles des armes (Fx.BORNES), diamètres et lumière × B.MEGA.RAYON_X.
function B.bornes_mega(b)
  local o = {}
  for kk, v in pairs(b) do o[kk] = v end
  o.vortex_echelle_max = b.vortex_echelle_max * B.MEGA.RAYON_X
  o.lumiere_taille_max = b.lumiere_taille_max * B.MEGA.RAYON_X
  o.duree_max = b.duree_max * B.MEGA.DUREE_X -- s43 MEGA-BOURDON
  return o
end

--- Direction d'une tourelle (0 à N_DIR - 1 ; 0 = nord, sens des aiguilles) la plus proche du vecteur (dx, dy) des feuilles (dy vers le sud,
--- déjà ramené au plan du rendu : le script divise l'écart à l'écran par B.COS45). nil pour un vecteur nul. Table des directions, sans trigonométrie.
function B.direction16(dx, dy)
  if type(dx) ~= "number" or type(dy) ~= "number" or (dx == 0 and dy == 0) then return nil end
  local n = B.MEGA.N_DIR
  local best, bv = 0, nil
  for k = 0, n - 1 do
    local c, sn = B.dir(k / n)
    local v = dx * sn - dy * c
    if bv == nil or v > bv + 1e-9 then best, bv = k, v end
  end
  return best
end

--- Cran suivant d'une tourelle en d qui vise c : un cran par le plus court chemin (à égalité, sens des aiguilles) ; d si elle y est.
function B.pas_tourelle(d, c)
  local n = B.MEGA.N_DIR
  if d == c then return d end
  if (c - d) % n <= n / 2 then return (d + 1) % n end
  return (d - 1) % n
end

--- Bouche des canons d'une tourelle en direction k : décalage à l'écran depuis son pivot, en tuiles.
function B.bouche(k)
  local c, sn = B.dir(k / B.MEGA.N_DIR)
  return sn * B.MEGA.CANON_L, -c * B.MEGA.CANON_L * B.COS45
end

--- Tick du prochain tir de la casemate k (1..n) d'une cloche numéro id : les casemates tirent en quinconce dans la recharge.
function B.decalage_canon(k, id, recharge)
  local n = B.MEGA.CANONS
  return ((k - 1) * math.floor(recharge / n) + (id or 0) * 7) % recharge
end

return B
