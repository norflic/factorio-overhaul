--[[
  Lot EXPERIMENTAUX-PUISSANCE (5/11) : règle d'échelle des unités expérimentales PAR ÂGE. Lua pur (testé par tests/echelle_test.lua).
  Décisions du DC (QCM-5/11-XP, 21 h 35, OBJECTIFS §4) : « mouche » à 4 âges de moins ; tenir 3 min sous 10 déchiqueteurs de SON âge ;
  5 salves pour tuer un déchiqueteur de son âge ; frapper tout ce qui est ennemi, jusqu'à la fin ; zone « +15 par âge » ; cratère et sol
  brûlé. Décision du lead : la même règle vaut pour le Bourdon et les géants de robotsjeu (l'attaque du Bourdon reste telle quelle).

  E1 résistance d'écart d'âge : sur tous les types de dégâts, part FIXE = le coup d'une mitrailleuse de l'âge A − ECART (le moteur ne
     connaît pas l'âge du tireur ; la force d'un coup croît de × 1,32 par âge, une part fixe filtre donc par âge), part en % = POURCENT.
  E2 PV : tenir SURVIE_S secondes sous MEUTE déchiqueteurs du palier de son âge, avec E1 (le soin des géants s'ajoute : marge).
  E3 salve : chaque cible de la zone prend un coup PLEIN qui, après la résistance du déchiqueteur du palier de son âge à ce type de dégâts,
     vaut PV / SALVES ; zone R(A) = PAS_ZONE × (A − AGE_ZONE0) pour A ≥ 10 (15 à l'âge 10, 90 à l'âge 15).
  E4 trace : cratère de rayon R(A) / 6 au point visé (2,5 à l'âge 10, 15 à l'âge 15).
  COÛT : une recherche d'entités par salve, cibles rangées par anneau de distance (ordre fixe), au plus PLAFOND par salve ; au plus BUDGET
     coups de zone par tick EN TOUT, partagés par toutes les salves en cours (Ech.partage) ; une salve de zone au plus toutes les CADENCE_ZONE
     ticks.

  SUPPOSÉ (à confirmer en jeu) : le palier des déchiqueteurs de l'âge A est A − DECALAGE_PALIER (âge 15 ↔ palier 12) ; la meilleure munition
  vanilla d'un âge est le chargeur perforant jusqu'à l'âge 8, l'uranium ensuite.
]]

local D = require("shared.tirs.degats")
local E = require("shared.content.enemies")

local Ech = {}

Ech.ECART = 4
Ech.POURCENT = 50
Ech.SURVIE_S = 180
Ech.MEUTE = 10
Ech.SALVES = 5
Ech.PAS_ZONE = 15
Ech.AGE_ZONE0 = 9
Ech.AGE_ZONE_MIN = 10
Ech.DECALAGE_PALIER = 3
Ech.CRATERE_PART = 6
-- Coups de zone par tick, EN TOUT, partagés par les salves en cours. Mesuré le 7/11 (xp-zone en --seul) : 120 coups par SALVE, deux salves
-- en même temps, donnaient 34 ms au pire tick (particleUpdate 15,7 : débris des morts ; scriptUpdate 15,4 : damage() et la mort dans le
-- moteur, environ 0,06 ms par coup mortel). Décision du lead : budget PARTAGÉ, 40 pour commencer.
Ech.BUDGET = 40
Ech.ANNEAU = 3
Ech.SECTEUR = 32 -- côté d'un secteur de recherche (une recherche du moteur par tick ; le tick 0 du double tir coûtait 10,7 ms, 7/11)
Ech.MORTS = 15 -- morts par tick EN TOUT, partagées par les salves en cours (débris : diagnostic du 7/11)
Ech.PLAFOND = 4000
Ech.CADENCE_ZONE = 180
Ech.AGE_MAX = 15 -- dernier âge du jeu (15 époques) : cratères prototypés de AGE_ZONE_MIN à AGE_MAX

--- Types de dégâts couverts par la résistance d'écart d'âge (ordre fixe).
Ech.TYPES = { "physical", "impact", "explosion", "fire", "acid", "poison", "laser", "electric" }

--- Déchiqueteurs vanilla 1.1.91 (data/base/prototypes/entity/enemies.lua) : PV, morsure, cadence (ticks), résistances { fixe, % }.
Ech.VANILLA = {
  { pv = 15, morsure = 7, cadence = 35, res = {} },
  { pv = 75, morsure = 15, cadence = 35, res = { physical = { 4, 10 }, explosion = { 0, 10 } } },
  { pv = 375, morsure = 30, cadence = 35, res = { physical = { 8, 10 }, explosion = { 0, 10 } } },
  { pv = 3000, morsure = 90, cadence = 50, res = { physical = { 12, 10 }, explosion = { 12, 10 } } },
}

--- Formule de dégâts du moteur : d = coup − fixe ; si d < 1, d = 1 / (2 − d) ; puis × (1 − % / 100).
function Ech.apres(coup, fixe, pct)
  local d = coup - (fixe or 0)
  if d < 1 then d = 1 / (2 - d) end
  return d * (1 - (pct or 0) / 100)
end

--- Palier des déchiqueteurs de l'âge A (SUPPOSÉ).
function Ech.palier(age)
  return math.max(1, math.min(E.TIERS, age - Ech.DECALAGE_PALIER))
end

--- Déchiqueteur ordinaire (sans famille) d'un palier : { pv, morsure, cadence, res = { [type] = { fixe, % } } }, comme
--- prototypes/enemies.lua (paliers 5 et plus : le béhémoth × E.new_tiers, résistances + resist en fixe et en %, plafond 95 %,
--- physique, explosion et acide ajoutés).
function Ech.dechiqueteur(p)
  if p <= E.VANILLA_TIERS then return Ech.VANILLA[p] end
  local b, nt = Ech.VANILLA[E.VANILLA_TIERS], E.new_tiers[p]
  local res = {}
  for _, t in ipairs(Ech.TYPES) do
    local r = b.res[t]
    if r then
      res[t] = { r[1] + nt.resist, math.min(95, r[2] + nt.resist) }
    elseif t == "physical" or t == "explosion" or t == "acid" then
      res[t] = { nt.resist, math.min(95, nt.resist) }
    end
  end
  return { pv = b.pv * nt.hp, morsure = b.morsure * nt.damage, cadence = b.cadence, res = res }
end

--- Meilleure munition vanilla d'un âge (SUPPOSÉ) : dégâts d'une balle.
function Ech.munition(a)
  return a <= 8 and 8 or 24
end

--- Coup d'une mitrailleuse du mod à l'âge a (son plus haut niveau, 2 × a), meilleure munition : 0 avant l'âge 1.
function Ech.coup_tourelle(a)
  if a < 1 then return 0 end
  return Ech.munition(a) * D.par_niveau[math.min(30, 2 * a)]
end

--- E1 : part fixe de la résistance d'écart d'âge d'une unité d'âge A.
function Ech.fixe(age)
  return Ech.coup_tourelle(age - Ech.ECART)
end

--- E1 : résistances du prototype (liste, ordre de Ech.TYPES), fixe arrondi au dixième.
function Ech.resistances(age)
  local f = math.floor(Ech.fixe(age) * 10 + 0.5) / 10
  local out = {}
  for _, t in ipairs(Ech.TYPES) do out[#out + 1] = { type = t, decrease = f, percent = Ech.POURCENT } end
  return out
end

--- DPS reçu de MEUTE déchiqueteurs du palier de l'âge A, avec la résistance E1 (morsure physique).
function Ech.dps_meute(age)
  local b = Ech.dechiqueteur(Ech.palier(age))
  return Ech.MEUTE * (60 / b.cadence) * Ech.apres(b.morsure, Ech.fixe(age), Ech.POURCENT)
end

--- E2 : PV d'une unité d'âge A (arrondis à la centaine au-dessus).
function Ech.pv(age)
  return math.ceil(Ech.SURVIE_S * Ech.dps_meute(age) / 100) * 100
end

--- E3 : coup d'une salve sur une cible, AVANT résistance, pour un type de dégâts : après la résistance du déchiqueteur du palier de
--- l'âge A, il vaut PV / SALVES. nil si ce déchiqueteur est immunisé (100 %).
function Ech.salve(age, dtype)
  local b = Ech.dechiqueteur(Ech.palier(age))
  local r = b.res[dtype] or { 0, 0 }
  if r[2] >= 100 then return nil end
  local net = b.pv / Ech.SALVES
  return math.ceil(net / (1 - r[2] / 100) + r[1])
end

--- E3 : rayon de la zone d'une salve (nil avant l'âge 10 : les petits gardent leur forme).
function Ech.rayon(age)
  if age < Ech.AGE_ZONE_MIN then return nil end
  return Ech.PAS_ZONE * (age - Ech.AGE_ZONE0)
end

--- E4 : rayon du cratère au point visé (nil avant l'âge 10).
function Ech.cratere(age)
  local r = Ech.rayon(age)
  if not r then return nil end
  return r / Ech.CRATERE_PART
end

--- Coût : cibles d'une salve rangées par ANNEAU de distance (largeur Ech.ANNEAU tuiles, du centre vers le bord : l'onde se voit), dans un
--- anneau dans l'ordre d'entrée (celui de la recherche du moteur, le même sur toutes les machines) ; au plus PLAFOND. Rangement en temps
--- linéaire, sans tri par comparaison (moteur simulé : un tri complet de 7 000 cibles coûtait 17 ms en un tick, tests/echelle_cout.lua),
--- et INCRÉMENTAL : Ech.poser (une entrée), au fil de la recherche par SECTEURS (Ech.secteurs, un par tick en jeu) ; puis Ech.prochain rend
--- les cibles une à une en parcourant les anneaux, sans rien allouer, et libère au passage les entrées rendues (moins de travail pour le
--- ramasse-miettes : diagnostic du pic de 13,9 ms, 7/11). Les longueurs d'anneau sont gardées à part (jamais l'opérateur # sur un anneau
--- à trous).
function Ech.nouveau_plan(center)
  return { c = { x = center.x, y = center.y }, rings = {}, cnt = {}, top = 0 }
end

--- Range un élément `item` à la position (x, y) dans son anneau.
function Ech.poser(p, x, y, item)
  local dx, dy = x - p.c.x, y - p.c.y
  local k = math.floor(math.sqrt(dx * dx + dy * dy) / Ech.ANNEAU) + 1 -- sqrt est exactement arrondie (IEEE 754) : même anneau partout
  local r = p.rings[k]
  if not r then r = {}; p.rings[k] = r; p.cnt[k] = 0 end
  local n = p.cnt[k] + 1
  r[n] = item
  p.cnt[k] = n
  if k > p.top then p.top = k end
end

function Ech.ranger(p, cands, a, b)
  for i = a, b do
    local c = cands[i]
    Ech.poser(p, c.x, c.y, c)
  end
end

--- Curseur de parcours d'un plan rangé : anneau k, rang i dans l'anneau, éléments déjà rendus.
function Ech.curseur()
  return { k = 1, i = 1, pris = 0 }
end

--- Vrai si un job de salve de zone peut frapper : il cherche encore (secteurs), ou il a un curseur et un plan à compteurs (`cnt`). Un job
--- d'une sauvegarde d'avant (0.6.56 et avant : liste `found` à ranger, ou plan sans `cnt`) n'est ni l'un ni l'autre : il est abandonné
--- (B1 de la revue de la 0.6.57 : Ech.frapper indexait alors un curseur ou des compteurs absents, et la partie plantait à la reprise).
function Ech.zone_jouable(j)
  return j.secteurs ~= nil or (j.cur ~= nil and j.plan ~= nil and j.plan.cnt ~= nil)
end

--- La cible suivante (du centre vers le bord), nil quand le plan est épuisé ou le plafond atteint. `liberer` : l'entrée rendue est retirée
--- de son anneau.
function Ech.prochain(p, cur, liberer)
  while cur.pris < Ech.PLAFOND and cur.k <= p.top do
    local r = p.rings[cur.k]
    if r and cur.i <= p.cnt[cur.k] then
      local x = r[cur.i]
      if liberer then r[cur.i] = nil end
      cur.i = cur.i + 1
      cur.pris = cur.pris + 1
      return x
    end
    cur.k, cur.i = cur.k + 1, 1
  end
  return nil
end

--- Vrai si plus rien ne reste à rendre (plafond atteint, ou anneaux restants vides).
function Ech.epuise(p, cur)
  if cur.pris >= Ech.PLAFOND then return true end
  local k, i = cur.k, cur.i
  while k <= p.top do
    if p.rings[k] and i <= p.cnt[k] then return false end
    k, i = k + 1, 1
  end
  return true
end

--- Les n éléments suivants (tests, coût) ; rend la tranche et vrai quand le plan est épuisé.
function Ech.suivants(p, cur, n)
  local out = {}
  while #out < n do
    local x = Ech.prochain(p, cur)
    if x == nil then break end
    out[#out + 1] = x
  end
  return out, Ech.epuise(p, cur)
end

function Ech.liste(p)
  local out = {}
  for k = 1, p.top do
    local r = p.rings[k]
    if r then
      for i = 1, p.cnt[k] do
        if #out >= Ech.PLAFOND then return out end
        out[#out + 1] = r[i]
      end
    end
  end
  return out
end

--- Un tick de frappe d'une salve : au plus `qh` coups et au plus `qm` MORTS (budget de morts : le coût du moteur, débris et morts, suit le
--- nombre de morts par tick ; diagnostic du 7/11). `frappe(item)` frappe une cible et rend vrai si elle meurt. Rend coups, morts, épuisé.
function Ech.frapper(p, cur, qh, qm, frappe)
  local coups, morts = 0, 0
  while coups < qh and morts < qm do
    local x = Ech.prochain(p, cur, true)
    if x == nil then break end
    coups = coups + 1
    if frappe(x) then morts = morts + 1 end
  end
  return coups, morts, Ech.epuise(p, cur)
end

--- RECHERCHE PAR SECTEURS : carrés de côté `cote` qui couvrent le disque (centre c, rayon r), ligne par ligne, sans ceux qui ne le touchent
--- pas. Un secteur est DEMI-OUVERT : [x0, x1[ × [y0, y1[ (Ech.dans_secteur), pour qu'une entité posée sur un bord commun ne soit gardée
--- qu'une fois (F96 : la recherche par zone rend aussi les entités qui touchent seulement la zone).
function Ech.secteurs(c, r, cote)
  local out = {}
  local x0, y0 = c.x - r, c.y - r
  local n = math.ceil(2 * r / cote)
  for j = 0, n - 1 do
    for i = 0, n - 1 do
      local a, b = x0 + i * cote, y0 + j * cote
      local q = { x0 = a, y0 = b, x1 = a + cote, y1 = b + cote }
      local px = math.max(q.x0, math.min(c.x, q.x1))
      local py = math.max(q.y0, math.min(c.y, q.y1))
      local dx, dy = px - c.x, py - c.y
      if dx * dx + dy * dy <= r * r then out[#out + 1] = q end
    end
  end
  return out
end

function Ech.dans_secteur(q, x, y)
  return x >= q.x0 and x < q.x1 and y >= q.y0 and y < q.y1
end

--- Le plan en une fois (même file que ranger + liste). `cands` : { x, y, ... } ; la table d'entrée n'est pas touchée.
function Ech.plan(cands, center)
  local p = Ech.nouveau_plan(center)
  Ech.ranger(p, cands, 1, #cands)
  return Ech.liste(p)
end

--- Coût : nombre de ticks pour traiter n cibles d'une salve SEULE (tout le budget pour elle).
function Ech.ticks(n)
  return math.ceil(n / Ech.BUDGET)
end

--- Tranche k (1, 2, …) d'une liste, pour une salve seule : indices de début et de fin (fin < début : rien).
function Ech.tranche(k, n)
  local a = (k - 1) * Ech.BUDGET + 1
  return a, math.min(n, k * Ech.BUDGET)
end

--- Partage du budget du tick `tick` entre `n` salves en cours (dans l'ordre de la file) : liste de n parts dont la SOMME vaut `budget`.
--- Chacune reçoit floor(budget / n) ; le reste (budget mod n) va à des salves qui tournent d'un tick à l'autre : sur n ticks, toutes
--- reçoivent autant. Une salve à qui il reste moins que sa part laisse le surplus perdu pour ce tick (le budget est un maximum).
function Ech.partage(n, budget, tick)
  local out = {}
  if n <= 0 then return out end
  local base, reste = math.floor(budget / n), budget % n
  for i = 1, n do
    out[i] = base + (((i - 1 - tick) % n) < reste and 1 or 0)
  end
  return out
end

--- Modules (lot DESIGN-MODULES, PRODUIT accordé le 5/11) : portée, zone et salve effectives d'une unité avec ses bonus (0,2 = + 20 %).
--- La cadence n'est pas touchée. `bonus` : { portee, puissance } ou nil.
function Ech.effectif(r, bonus)
  local bp = (bonus and bonus.portee) or 0
  local bf = (bonus and bonus.puissance) or 0
  return { range = r.range * (1 + bp), zone = r.zone and r.zone * (1 + bp), salve = r.salve and r.salve * (1 + bf) }
end

---------------------------------------------------------------------------------------------------
-- BALAYAGE (demande du DC du 5/11, 21 h 43, pour le Stylet de l'âge 11, « le gros triangle qui chatouille ») : « Il se tournerait et
-- tirerait un gros rayon laser et tournerait sur un angle de 30 degrés et ça brûlerait tout sur le passage (sous le laser aussi) ».
-- Le rayon part de l'unité, de longueur L, et balaie BALAYAGE_ANGLE degrés centrés sur la cible en BALAYAGE_PAS pas ; chaque ennemi touché
-- par la BANDE du rayon (demi-largeur BALAYAGE_DEMI) prend UNE fois la salve laser de son âge ; du feu au sol tous les BALAYAGE_FEU_PAS
-- tuiles le long du rayon, à chaque pas. Sans trigonométrie : rotations par des constantes écrites (cos et sin de 15° et du pas).
---------------------------------------------------------------------------------------------------
Ech.BALAYAGE_ANGLE = 30
Ech.BALAYAGE_PAS = 10        -- 10 pas de 3°
Ech.BALAYAGE_TICKS = 120     -- durée du balayage (2 s)
Ech.BALAYAGE_DEMI = 1.5      -- demi-largeur de la bande brûlée (le rayon fait 3 tuiles de large)
Ech.BALAYAGE_FEU_PAS = 4     -- un feu tous les 4 tuiles le long du rayon, à chaque pas
Ech.BALAYAGE_FEU_TICKS = 600 -- le sol brûle 10 s
local COS15, SIN15 = 0.96592582628906829, 0.25881904510252074
local COS3, SIN3 = 0.99862953475457383, 0.052335956242943835

--- Paramètres du balayage d'une unité d'âge A et de portée `portee` : longueur du rayon = portée.
function Ech.balayage(age, portee)
  return { angle = Ech.BALAYAGE_ANGLE, pas = Ech.BALAYAGE_PAS, ticks = Ech.BALAYAGE_TICKS, longueur = portee, demi = Ech.BALAYAGE_DEMI,
           feu_pas = Ech.BALAYAGE_FEU_PAS, feu_ticks = Ech.BALAYAGE_FEU_TICKS, salve = Ech.salve(age, "laser") }
end

--- Extrémités du rayon aux pas 0 à BALAYAGE_PAS : de −15° à +15° autour de la direction de la cible, longueur L. Rend nil si la cible est
--- sur l'unité.
function Ech.rayons(o, cible, L)
  local dx, dy = cible.x - o.x, cible.y - o.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1e-9 then return nil end
  local ux, uy = dx / d, dy / d
  -- départ : rotation de −15°
  local vx, vy = ux * COS15 + uy * SIN15, -ux * SIN15 + uy * COS15
  local out = {}
  for k = 0, Ech.BALAYAGE_PAS do
    out[#out + 1] = { x = o.x + vx * L, y = o.y + vy * L }
    vx, vy = vx * COS3 - vy * SIN3, vx * SIN3 + vy * COS3
  end
  return out
end

--- Le point p est-il dans la bande (demi-largeur w) du segment o → e ? (distance au segment, au carré : sans racine)
function Ech.dans_bande(p, o, e, w)
  local sx, sy = e.x - o.x, e.y - o.y
  local px, py = p.x - o.x, p.y - o.y
  local l2 = sx * sx + sy * sy
  local t = l2 > 0 and (px * sx + py * sy) / l2 or 0
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  local qx, qy = px - t * sx, py - t * sy
  return qx * qx + qy * qy <= w * w
end

--- Points de feu le long du segment o → e, tous les `pas` tuiles (le premier à `pas` de l'unité).
function Ech.feux(o, e, pas)
  local sx, sy = e.x - o.x, e.y - o.y
  local l = math.sqrt(sx * sx + sy * sy)
  local out = {}
  local n = math.floor(l / pas)
  for i = 1, n do
    local t = i * pas / l
    out[#out + 1] = { x = o.x + sx * t, y = o.y + sy * t }
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- IMPACT, variante B (design IMPACT, à montrer au DC à côté de la variante A, cratère et une brûlure au centre) : « sol brûlé » sur toute
-- la zone. Une très grande brûlure au centre, 6 grandes sur un anneau à 0,35 du rayon, 12 moyennes sur un anneau à 0,7, et une petite sous
-- une cible tuée sur k (au plus Ech.BRULURES_MAX par salve). Brûlures du jeu de base (`*-scorchmark`, 10 min). Directions : 24 vecteurs
-- unitaires ÉCRITS (pas de 15°), sans trigonométrie.
---------------------------------------------------------------------------------------------------
Ech.BRULURES_MAX = 300
Ech.BRULURE_ANNEAUX = { { part = 0.35, pas = 4, nom = "big-scorchmark" }, { part = 0.7, pas = 2, nom = "medium-scorchmark" } }
local Q15 = { { 1, 0 }, { 0.96592582628906831, 0.25881904510252074 }, { 0.86602540378443871, 0.5 }, { 0.70710678118654757, 0.70710678118654757 },
  { 0.5, 0.86602540378443871 }, { 0.25881904510252074, 0.96592582628906831 } }
local DIR24 = {}
for q = 0, 3 do
  for i = 1, 6 do
    local x, y = Q15[i][1], Q15[i][2]
    for _ = 1, q do x, y = -y, x end
    DIR24[#DIR24 + 1] = { x, y }
  end
end
Ech.DIR24 = DIR24

--- Brûlures d'une salve de zone centrée en `c`, de rayon `zone` : liste { x, y, nom } (centre, puis anneaux, dans l'ordre).
function Ech.brulures(c, zone)
  local out = { { x = c.x, y = c.y, nom = "huge-scorchmark" } }
  for _, a in ipairs(Ech.BRULURE_ANNEAUX) do
    local rr = zone * a.part
    for k = 1, 24, a.pas do
      out[#out + 1] = { x = c.x + DIR24[k][1] * rr, y = c.y + DIR24[k][2] * rr, nom = a.nom }
    end
  end
  return out
end

--- Une petite brûlure sous une cible tuée sur `pas_brulure(n)`, pour n cibles frappées : au plus Ech.BRULURES_MAX par salve.
function Ech.pas_brulure(n)
  return math.max(1, math.ceil(n / Ech.BRULURES_MAX))
end

---------------------------------------------------------------------------------------------------
-- Régénération (demande du lead du 6/11) : elle suit le maximum (même part du maximum par tick qu'avant la règle). La vie des sauvegardes
-- existantes n'a rien à faire : le moteur garde la PROPORTION de vie quand le max_health d'un prototype change (banc xp-vie-migration,
-- 7/11 : une migration en plus l'appliquait deux fois).
---------------------------------------------------------------------------------------------------
--- Régénération par tick d'un maximum `pv`, pour une régénération `soin0` par tick qui allait avec le maximum `pv0`.
function Ech.soin(pv, soin0, pv0)
  return pv * soin0 / pv0
end

---------------------------------------------------------------------------------------------------
-- SÉQUELLES (réponses du DC du 7/11, QCM-7/11) : « Cratère et verre, pas de falaises » ; « les dégâts visibles permanents devraient en
-- réalité durer 1 heure, se résorber » ; le Glas du Bourdon : « non temporaire mais de 10 minutes ». Les traces des géants (cratère, verre,
-- sol brûlé) durent TRACE_TICKS puis se résorbent ; celles du Glas, TRACE_GLAS_TICKS.
-- Cratère : les tuiles du disque passent au sol `nuclear-ground` ; leur sol d'origine est noté dans un REGISTRE par surface, rendu à
-- l'échéance, seulement si la tuile est encore un sol de cratère (un sol posé depuis par un joueur n'est jamais écrasé). Un nouveau cratère
-- sur une tuile déjà marquée repousse son échéance et garde son sol d'origine. Rendu par lots de RESORPTION_LOT tuiles par tick.
---------------------------------------------------------------------------------------------------
Ech.TRACE_TICKS = 216000      -- 1 h
Ech.TRACE_GLAS_TICKS = 36000  -- 10 min
Ech.RESORPTION_LOT = 100

--- Tuiles (coin entier) dont le CENTRE est dans le disque de centre c et de rayon r, ligne par ligne (ordre fixe).
function Ech.disque(c, r)
  local out = {}
  local r2 = r * r
  for y = math.floor(c.y - r), math.floor(c.y + r) do
    local dy = y + 0.5 - c.y
    for x = math.floor(c.x - r), math.floor(c.x + r) do
      local dx = x + 0.5 - c.x
      if dx * dx + dy * dy <= r2 then out[#out + 1] = { x = x, y = y } end
    end
  end
  return out
end

--- Registre des tuiles marquées d'une surface : t[clé] = { x, y, orig, fin } ; file d'échéances en ordre croissant (n : dernier indice,
--- tete : premier non traité ; jamais l'opérateur # sur une file à trous).
function Ech.trace_nouveau()
  return { t = {}, file = {}, tete = 1, n = 0 }
end

--- Marque la tuile (x, y), de sol `orig`, jusqu'au tick `fin`. Rend vrai si elle n'était pas marquée (le sol de cratère est à poser).
--- Les `fin` successives doivent croître (en jeu : fin = tick + TRACE_TICKS) : la file est lue dans l'ordre.
function Ech.trace_marquer(R, x, y, orig, fin)
  local k = x .. "," .. y
  local e = R.t[k]
  if e then
    if fin > e.fin then e.fin = fin end
  else
    R.t[k] = { x = x, y = y, orig = orig, fin = fin }
  end
  R.n = R.n + 1
  R.file[R.n] = { k = k, fin = fin }
  return e == nil
end

--- Tuiles échues au tick `tick`, au plus `max`, retirées du registre (une tuile repoussée par un cratère plus récent attend sa propre
--- échéance). La file est compactée quand sa tête dépasse 4 096.
function Ech.trace_echues(R, tick, max)
  local out = {}
  while R.tete <= R.n and #out < max do
    local q = R.file[R.tete]
    if q.fin > tick then break end
    R.file[R.tete] = nil
    R.tete = R.tete + 1
    local e = R.t[q.k]
    if e and e.fin <= tick then
      out[#out + 1] = e
      R.t[q.k] = nil
    end
  end
  if R.tete > 4096 then
    local f, m = {}, 0
    for i = R.tete, R.n do m = m + 1; f[m] = R.file[i] end
    R.file, R.tete, R.n = f, 1, m
  end
  return out
end

--- Nombre de tuiles encore marquées (contrôles).
function Ech.trace_compte(R)
  local n, vu = 0, {}
  for i = R.tete, R.n do
    local q = R.file[i]
    if R.t[q.k] and not vu[q.k] then
      vu[q.k] = true
      n = n + 1
    end
  end
  return n
end

return Ech
