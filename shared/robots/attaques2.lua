--[[
  Lot DESIGN-ATTAQUES (5/11, nuit) : la 2e attaque des 5 géants expérimentaux, règles PURES (aucune API du jeu).
  Demande du DC (5/11, en jouant) : « revoir leurs attaques […] avoir vraiment un impact […] quand il y a un bourdon qui passe par
  au-dessus d'une base, j'ai pas envie que la base elle se dise bah c'est bon, je peux continuer après son passage » ; QCM : « De nouvelles
  attaques ». Repère : le Glas du Bourdon (shared/robots/bourdon.lua).

  Une « grande attaque » par géant, chacune avec une FORME propre, LE CORPS DU GÉANT QUI AGIT, un climax, et une SÉQUELLE qui dure.
  Séquelles (QCM-7/11, le DC) : « Cratère et verre, pas de falaises » ; « les dégâts visibles permanents devraient en réalité durer
  1 heure, se résorber » : toute trace visible dure Ech.TRACE_TICKS (1 h) puis le sol d'origine revient (A.SOL_TRACE, registre Ech.trace_*).
    Cairn (10)     « La Surtension » : la foudre frappe le poteau ennemi le plus proche ; la surtension court le long des fils de cuivre
                   (parcours en largeur, 60 poteaux au plus), chaque poteau atteint reste sous tension, puis tous sautent en vague ;
                   l'orage frappe la zone. Sans réseau (nids de biters) : l'arc saute d'un bâtiment à l'autre (proximité).
                   Séquelle : le réseau coupé et ses accumulateurs vidés ; de nuit, la base s'éteint.
    Stylet (11)    « Le Balayage »   : l'idée du DC (5/11) : un gros rayon laser qui balaie 30° et brûle tout sur son passage.
                   Séquelle : un éventail de sol brûlé (brûlures d'1 h). La Balafre (canyon de falaises) est abandonnée.
    Trombe (12)    « Le Cyclone »    : la Trombe elle-même descend sur la base et la parcourt en huit pendant 10 s ; elle arrache ce qu'elle
                   touche et jette des rochers sur son couloir. Séquelle : un couloir rasé, encombré de rochers, qui s'effacent en 1 h.
    Ixion (13)     « L'Éruption »    : une lance de plasma part du cœur solaire ; le sol se fend, éclate, crache des bombes de lave ; un lac
                   de croûte rougeoyante s'étend. Séquelle : un lac infranchissable 1 min, qui refroidit en cratère en 3 min ; le cratère
                   dure 1 h puis le sol d'origine revient.
    Tournesol (14) « Le Zénith »     : le foyer concentre le soleil en un point qui grave une spirale de verre en fusion du bord vers le
                   centre, puis éclate au centre. Séquelle : la spirale reste infranchissable 2 min (la base coupée en anneaux), puis
                   refroidit en verre doré constructible ; le verre dure 1 h puis le sol d'origine revient.
  Critique sévère du 5/11 (sous-agent, notes 3 à 6 sur 10) prise en compte : corps qui agit, climax à la fin, plus de « bombe atomique »
  vanilla ni de lignes plates, couleurs pures par la lumière ronde (une teinte multiplie, F36), dégâts au lieu de morts d'office, un son
  par géant, une touche pour le joueur.

  Coût (exigence du lead) : UNE recherche d'entités par salve (find_entities_filtered à la frappe), puis dégâts par TRANCHES de temps
  (chaque entité reçoit son tick de passage, calculé ici). Exception déclarée : aucune.
  Déterminisme : aucune trigonométrie (pseudo-angle « en losange » et table de directions du Bourdon, B.dir), aucun hasard du moteur
  (générateur maison B.alea), listes triées, aucun pairs.
  CHIFFRES PROVISOIRES : les dégâts suivent le coup du géant (Xp.stats, `r.shot`) ; la règle d'échelle de l'agent experimentaux (zone
  15 × (âge − 9), dégâts) les remplacera (A.zone, A.coup).
]]

local B = require("shared.robots.bourdon")
local Ech = require("shared.robots.echelle")

local A = {}

A.PREFIX = "fo-att2-"
A.LOG = "[FO-ATT2]"
A.RECHARGE = 1800       -- automatique : une grande attaque toutes les 30 s au plus
A.RECHARGE_ORDRE = 900  -- sur ordre du joueur : 15 s
A.FACTEUR = 2           -- repli : coup plein par cible = FACTEUR × coup de la 1re attaque (non partagé)
-- COÛT PAR TICK (demande du lead, 7/11 : moins de 1 ms). Mesure en jeu du 7/11 (att2-perf, seul sur le PC), avec des bornes fixes
-- (150 rangées, 20 coups, 64 tuiles, 10 poteaux par tick) : 2,2 à 4,0 ms au pire tick de la grande attaque. D'où un BUDGET de jetons par
-- tick, PARTAGÉ par toutes les grandes attaques en cours et les refroidissements, remis à plein à chaque tick ; ce qui dépasse passe au
-- tick suivant. Les poids sont FIXES (environ des µs, estimés sur cette mesure) : aucune décision sur un temps mesuré (déterminisme).
-- v7 (mesure seule du 7/11 à 12 h 25, v6) : avec les poids de la v6, 500 jetons valaient 3 à 7 ms de script, pas 0,5 : les poids étaient
-- 6 à 9 fois trop bas. Une mort déclenche une vingtaine de gestionnaires on_entity_died du mod (ruines, journaux, factions) ; un poteau
-- grillé recoupe le réseau électrique ; une bande de 32 tuiles de haut rendait 1 300 entités (4 à 5 ms). Poids recalés sur cette mesure,
-- en µs ; budget de 2 000 (environ 2 ms de script par tick pour toutes les grandes attaques ensemble).
A.BUDGET = 2000
A.POIDS = {
  coup = 400,    -- un coup (damage ou die) : ruines, explosion de mort, gestionnaires on_entity_died du mod (synchrones)
  feu = 150,     -- un feu au sol et sa brûlure
  eclat = 50,    -- une explosion, un éclat, un rocher
  poteau = 700,  -- un poteau qui saute au climax du Cairn : mort, réseau électrique recoupé, grosse explosion, éclat
  rang = 8,      -- une entité rangée pendant la charge (position, type, santé)
  tuile = 40,    -- une tuile vérifiée, posée et notée au registre des séquelles
  abattre = 200, -- un arbre ou un rocher abattu
  bande = 300,   -- une bande de recherche d'entités (A.BANDE_AIRE tuiles², trois recherches : ennemies, arbres et rochers, autres forces)
  vide = 20,     -- un accumulateur, une tourelle laser, un roboport vidés
}
A.BANDE_AIRE = 400      -- surface d'une bande de recherche (tuiles²) : environ 0,3 ms (0,7 µs par tuile² sur une base dense, mesuré)

--- Hauteur des bandes de recherche pour une boîte de `largeur` tuiles : A.BANDE_AIRE / largeur, au moins 1.
function A.hauteur_bande(largeur) return math.max(1, math.floor(A.BANDE_AIRE / math.max(1, largeur))) end
A.TUILES = 32           -- tuiles posées par tick au plus (le reste du budget pour les coups)

-- SÉQUELLES (QCM-7/11) : 1 h, puis le sol d'origine revient (registre Ech.trace_* de shared/robots/echelle.lua, par surface).
A.TRACE = Ech.TRACE_TICKS
A.RESORPTION = 5         -- un passage de résorption tous les 5 ticks, au budget du tick (A.POIDS.tuile par tuile, A.POIDS.eclat par rocher)
--- Les sols que le temps efface : le cratère (la lave refroidie) et le verre doré (le verre chaud refroidi). La lave et le verre chaud
--- refroidissent bien avant l'heure (4 et 3 min).
A.SOLS_TRACE = { ["nuclear-ground"] = true, [A.PREFIX .. "verre"] = true }

--- Le sol à rendre à une tuile échue `e` (registre : { x, y, orig, fin }) dont le sol actuel est `nom` : son sol d'origine si elle porte
--- encore une trace des grandes attaques (cratère, verre) ; rien si autre chose l'a changée depuis (un joueur qui pave, une autre attaque
--- encore chaude), ni si l'origine était déjà ce sol (un cratère d'experimentaux dessous : son propre registre le rendra).
function A.sol_a_rendre(e, nom)
  if A.SOLS_TRACE[nom] and e.orig ~= nom then return e.orig end
  return nil
end

--- Une tuile échue encore CHAUDE (lave, verre chaud : une autre grande attaque l'a reprise, ou un banc a avancé l'heure) n'est pas perdue :
--- elle reprend A.REPRISE ticks d'attente, son sol d'origine gardé.
A.CHAUDS = { [A.PREFIX .. "lave"] = true, [A.PREFIX .. "verre-chaud"] = true }
A.REPRISE = 600
function A.encore_chaud(nom) return A.CHAUDS[nom] == true end

--- Les bandes de recherche d'une boîte (x0, y0, x1, y1), de `h` tuiles de haut au plus, du nord au sud. La dernière garde son bord sud.
function A.bandes(x0, y0, x1, y1, h)
  local out = {}
  local y = y0
  repeat
    local yb = math.min(y1, y + h)
    out[#out + 1] = { x0 = x0, y0 = y, x1 = x1, y1 = yb, der = (yb >= y1) }
    y = yb
  until y >= y1
  return out
end

--- Une entité rendue par la recherche de la bande `b` lui revient-elle ? Chaque position n'appartient qu'à UNE bande (F96 : la recherche
--- rend aussi ce qui touche la bande par un bord) : nord inclus, sud exclu sauf pour la dernière ; hors de la boîte en x, à personne.
function A.dans_bande(b, x, y)
  if x < b.x0 or x > b.x1 or y < b.y0 or y > b.y1 then return false end
  return y < b.y1 or b.der
end

--- Zone d'un géant d'âge `age` (choix du DC transmis par le lead, 5/11 : 15 × (âge − 9) tuiles ; 15 à l'âge 10, 75 à l'âge 14).
function A.zone(age) return 15 * (math.floor(age) - 9) end

--- Coup plein d'une grande attaque, par cible (provisoire) : r.shot vient de Xp.stats.
--- Règle d'échelle d'experimentaux (corr-xp-puissance, shared/robots/echelle.lua) : la salve de l'âge pour ce type de dégâts (PV du
--- déchiqueteur du palier de l'âge, après sa résistance, / 5). Repli : FACTEUR × le coup de la 1re attaque.
function A.coup(r) return Ech.salve(r.age, r.dtype) or (r.shot or 0) * A.FACTEUR end
A.Ech = Ech

--- Dégâts à la distance relative f (0 au centre de l'effet, 1 au bord) : coup au centre, coup × bord au bord ; 0 au-delà.
function A.chute(coup, f, bord)
  if f > 1 then return 0 end
  if f < 0 then f = 0 end
  return coup * (1 - (1 - bord) * f)
end

A.ATTAQUES = {
  cairn = { nom = "surtension", charge = 90, sauts = 60, saut_ticks = 3, tenue = 30, foudres = 36, foudre_ticks = 5, bord = 0.5, proche = 12 },
  -- Stylet : « Le Balayage » (idée du DC, 5/11, 21 h 43) sur la règle Ech.balayage d'experimentaux ; la Balafre (falaises) est
  -- ABANDONNÉE (QCM-7/11 : « Cratère et verre, pas de falaises ») ; son plan est A.plan_balayage
  stylet = { nom = "balayage", charge = 60, bord = 1 },
  trombe = { nom = "cyclone", charge = 100, duree = 600, boucle = 0.6, rayon = 7, souffle = 15, bord = 0.3, pas = 2, debris = 0.35, coeur = 2 },
  ixion = { nom = "eruption", charge = 120, lance = 40, lave = 1 / 3, fonte = 0.5, onde = 0.9, bord = 0.3, tenue = 3600,
    refroidit = 10800, anneaux = 12, feux = 80, secteurs = 24, bombes = 18 },
  tournesol = { nom = "zenith", charge = 150, pas = 16, duree = 660, bord = 0.25, pinceau = 1.3, tenue = 7200, refroidit = 3600, tranches = 8 },
}
A.ORDRE = { "cairn", "stylet", "trombe", "ixion", "tournesol" }

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

---------------------------------------------------------------------------------------------------
-- Angles sans trigonométrie
---------------------------------------------------------------------------------------------------
--- Pseudo-angle « en losange » de (dx, dy), dans [0, 4) : monotone avec l'angle vrai (sens des aiguilles à l'écran, y vers le bas),
--- 0 vers l'est, 1 vers le sud, 2 vers l'ouest, 3 vers le nord. (0, 0) rend 0.
function A.pseudo_angle(dx, dy)
  if dx == 0 and dy == 0 then return 0 end
  if dy >= 0 then
    if dx >= 0 then return dy / (dx + dy) end
    return 1 - dx / (-dx + dy)
  end
  if dx < 0 then return 2 - dy / (-dx - dy) end
  return 3 + dx / (dx - dy)
end

--- Direction unitaire d'un pseudo-angle (inverse de A.pseudo_angle).
function A.direction(pa)
  pa = pa % 4
  local q = math.floor(pa)
  local f = pa - q
  local x, y
  if q == 0 then x, y = 1 - f, f
  elseif q == 1 then x, y = -f, 1 - f
  elseif q == 2 then x, y = f - 1, -f
  else x, y = f, f - 1 end
  local n = math.sqrt(x * x + y * y)
  return x / n, y / n
end

---------------------------------------------------------------------------------------------------
-- Commun : tranches de temps
---------------------------------------------------------------------------------------------------
--- Range des éléments { t = tick relatif, ... } par tick : rend { [t] = { éléments } } et la liste triée des ticks.
--- Ordre dans un tick : celui de la liste d'entrée (déjà triée par l'appelant).
function A.tranches(items)
  local par, ticks = {}, {}
  for _, it in ipairs(items) do
    local t = it.t
    local l = par[t]
    if not l then l = {}; par[t] = l; ticks[#ticks + 1] = t end
    l[#l + 1] = it
  end
  table.sort(ticks)
  return par, ticks
end

--- Tri stable par distance puis par numéro (les candidats ont `id`).
local function par_id(a, b)
  if a.t ~= b.t then return a.t < b.t end
  return a.id < b.id
end
A.par_id = par_id

---------------------------------------------------------------------------------------------------
-- Cairn, « La Surtension »
---------------------------------------------------------------------------------------------------
--- Parcours en largeur du réseau de cuivre depuis `depart` (id), au plus `max` poteaux départ compris. voisins(id) rend une liste
--- d'ids (ordre quelconque : triée ici). Rend les niveaux { { ids du niveau 0 }, { niveau 1 }, ... }, sans doublon, et le parent de
--- chaque poteau atteint (l'arc part de lui).
function A.surtension(depart, voisins, max)
  local vu = { [depart] = true }
  local parent = {}
  local niveaux = { { depart } }
  local n, cur = 1, { depart }
  while n < max do
    local nx = {}
    for _, id in ipairs(cur) do
      local l = {}
      for _, v in ipairs(voisins(id) or {}) do l[#l + 1] = v end
      table.sort(l)
      for _, v in ipairs(l) do
        if not vu[v] and n < max then
          vu[v] = true
          parent[v] = id
          nx[#nx + 1] = v
          n = n + 1
        end
      end
    end
    if #nx == 0 then break end
    niveaux[#niveaux + 1] = nx
    cur = nx
  end
  return niveaux, parent
end

---------------------------------------------------------------------------------------------------
-- Grille de proximité (Trombe) : les candidats rangés par case de `cell` tuiles, lus par clé calculée (jamais parcourue)
---------------------------------------------------------------------------------------------------
local function cle(cx, cy) return cx .. ":" .. cy end

function A.grille(cands, cell)
  local g = {}
  for i, c in ipairs(cands) do
    local k = cle(math.floor(c.x / cell), math.floor(c.y / cell))
    local l = g[k]
    if not l then l = {}; g[k] = l end
    l[#l + 1] = i
  end
  return g
end

--- Indices des candidats des cases qui touchent le disque (x, y, r), dans l'ordre des cases (lignes puis colonnes) et des indices.
--- Ajoute un candidat (indice i) à la grille (construction par tranches).
function A.grille_ajoute(g, i, c, cell)
  local k = cle(math.floor(c.x / cell), math.floor(c.y / cell))
  local l = g[k]
  if not l then l = {}; g[k] = l end
  l[#l + 1] = i
end

function A.voisinage(g, x, y, r, cell)
  local out = {}
  local x0, x1 = math.floor((x - r) / cell), math.floor((x + r) / cell)
  local y0, y1 = math.floor((y - r) / cell), math.floor((y + r) / cell)
  for cy = y0, y1 do
    for cx = x0, x1 do
      local l = g[cle(cx, cy)]
      if l then for _, i in ipairs(l) do out[#out + 1] = i end end
    end
  end
  return out
end

--- Les éclairs de l'orage : `n` indices dans 1..m (m candidats triés), tirés à la graine ; une même cible peut être frappée deux fois.
function A.foudres(m, n, graine)
  local out = {}
  if m < 1 then return out end
  local etat = { v = (graine % 2147483646) + 1 }
  for _ = 1, 3 do B.alea(etat) end
  for i = 1, n do out[i] = 1 + math.floor(B.alea(etat) * m) % m end
  return out
end

--- Sans réseau électrique (nids de biters, bases sans poteaux) : l'arc saute de proche en proche. Parcours en largeur où les voisins d'un
--- candidat sont les candidats à moins de `r` tuiles (grille de proximité), au plus `max`. Rend niveaux et parents (INDICES des candidats).
function A.reseau_proche(cands, depart, r, max)
  local g = A.grille(cands, r)
  local voisins = function(i)
    local c = cands[i]
    local l = {}
    for _, k in ipairs(A.voisinage(g, c.x, c.y, r, r)) do
      local o = cands[k]
      if k ~= i and (o.x - c.x) * (o.x - c.x) + (o.y - c.y) * (o.y - c.y) <= r * r then l[#l + 1] = k end
    end
    return l
  end
  return A.surtension(depart, voisins, max)
end

---------------------------------------------------------------------------------------------------
-- Stylet, « Le Balayage » (idée du DC, 5/11, 21 h 43 : « Il se tournerait et tirerait un gros rayon lazer et tournerait sur un angle de
-- 30 degrès et ca brulerait tout sur le passage (sous le azer aussi) »). Règle d'experimentaux : Ech.balayage, Ech.rayons, Ech.dans_bande.
---------------------------------------------------------------------------------------------------
--- Plan du balayage : chaque cible touchée par la bande du rayon au pas k (rayons = Ech.rayons) prend la salve UNE fois, au tick du
--- premier pas qui la touche (pas k au tick k × ticks / pas). Rend { t, id, i, f = 0, tue = false } triés.
function A.plan_balayage(o, rayons, cands, demi, ticks, pas)
  local out = {}
  for i, c in ipairs(cands) do
    for k, e in ipairs(rayons) do
      if Ech.dans_bande(c, o, e, demi) then
        out[#out + 1] = { t = math.floor((k - 1) * ticks / pas), id = c.id, i = i, f = 0, tue = false }
        break
      end
    end
  end
  table.sort(out, par_id)
  return out
end

--- Position du bout du rayon au tick relatif t (interpolée entre deux pas) : rend x, y, et l'indice du pas atteint.
function A.bout_balayage(rayons, t, ticks, pas)
  local u = math.max(0, math.min(pas, t * pas / ticks))
  local k = math.floor(u)
  if k >= pas then return rayons[pas + 1].x, rayons[pas + 1].y, pas + 1 end
  local f = u - k
  local a, b = rayons[k + 1], rayons[k + 2]
  return a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f, k + 1
end

---------------------------------------------------------------------------------------------------
-- Trombe, « Le Cyclone »
---------------------------------------------------------------------------------------------------
--- Position du tourbillon au tick relatif t (0..duree) : un huit (lemniscate de Gerono) de demi-largeur w autour de c, tourné de `o`
--- (fraction de tour). Il part du centre, y repasse à mi-course et y finit. Rend x, y.
function A.cyclone(c, w, o, t, duree)
  local s = 0.25 + t / duree
  local cs, sn = B.dir(s)
  local _, sn2 = B.dir(2 * s)
  local u, v = w * cs, w * sn2 / 2
  local co, so = B.dir(o)
  return c.x + u * co - v * so, c.y + u * so + v * co
end

--- Passage du tourbillon près d'un point p : échantillonne la course tous les `pas` ticks ; rend t (tick relatif) et d (distance) du
--- plus proche passage, ou nil au-delà de `souffle`.
function A.passage_cyclone(p, c, w, o, duree, pas, souffle)
  local bt, bd2
  local lim = souffle * souffle
  local t = 0
  while t <= duree do
    local x, y = A.cyclone(c, w, o, t, duree)
    local dx, dy = p.x - x, p.y - y
    local q = dx * dx + dy * dy
    if q <= lim and (not bd2 or q < bd2) then bt, bd2 = t, q end
    t = t + pas
  end
  if not bt then return nil end
  return bt, math.sqrt(bd2)
end

--- Débris : une cible arrachée laisse-t-elle un rocher (part `part`) ? Rend l'indice du rocher (1 à 3) ou nil ; tiré à la graine.
A.ROCHERS = { "rock-big", "sand-rock-big", "rock-huge" }
function A.debris(id, graine, part)
  local h = (id * 2654435761 + graine * 40503) % 4294967296
  local u = (h % 10007) / 10007
  if u >= part then return nil end
  return 1 + math.floor(h / 10007) % #A.ROCHERS
end

--- Boîte englobante de la course (pour l'unique recherche d'entités), élargie de `marge`.
function A.boite_cyclone(c, w, o, duree, pas, marge)
  local x0, y0, x1, y1 = c.x, c.y, c.x, c.y
  local t = 0
  while t <= duree do
    local x, y = A.cyclone(c, w, o, t, duree)
    if x < x0 then x0 = x end
    if x > x1 then x1 = x end
    if y < y0 then y0 = y end
    if y > y1 then y1 = y end
    t = t + pas
  end
  return { { x0 - marge, y0 - marge }, { x1 + marge, y1 + marge } }
end

---------------------------------------------------------------------------------------------------
-- Ixion, « L'Éruption »
---------------------------------------------------------------------------------------------------
--- Bord du lac : `n` rayons (secteurs de pseudo-angle égaux), entre 0,8 et 1 fois `rl`, tirés à la graine (un bord qui n'est pas un cercle).
function A.bords_lave(rl, n, graine)
  local etat = { v = (graine % 2147483646) + 1 }
  for _ = 1, 3 do B.alea(etat) end
  local out = {}
  for i = 1, n do out[i] = rl * (0.8 + 0.2 * B.alea(etat)) end
  return out
end

--- Rayon du bord dans la direction de pseudo-angle pa (interpolé entre secteurs).
function A.bord(bords, pa)
  local n = #bords
  local p = (pa % 4) / 4 * n
  local k = math.floor(p)
  local f = p - k
  local a, b = bords[k % n + 1], bords[(k + 1) % n + 1]
  return a + (b - a) * f
end

--- Distance relative d'une tuile au bord (0 au centre, 1 sur le bord).
function A.f_lave(c, bords, x, y)
  local dx, dy = x - c.x, y - c.y
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1e-9 then return 0 end
  return d / A.bord(bords, A.pseudo_angle(dx, dy))
end

--- Tuiles (coins entiers x, y : centre en x + 0,5) dont la distance relative est dans ]f0, f1] ; parcours ligne par ligne (ordre fixe).
function A.tuiles_lave(c, bords, f0, f1)
  local rmax = 0
  for _, r in ipairs(bords) do if r > rmax then rmax = r end end
  local lim = math.ceil(rmax * f1) + 1
  local cx, cy = math.floor(c.x), math.floor(c.y)
  local out = {}
  for y = cy - lim, cy + lim do
    for x = cx - lim, cx + lim do
      local f = A.f_lave(c, bords, x + 0.5, y + 0.5)
      if f > f0 and f <= f1 then out[#out + 1] = { x = x, y = y } end
    end
  end
  return out
end

--- Tick relatif où la fonte atteint la distance relative f (le front avance de `fonte` tuiles par tick sur un rayon moyen rl).
function A.t_fonte(f, rl, fonte) return math.floor(f * rl / fonte) end

--- Les feux de l'anneau extérieur : `n` points entre rl et R, tirés à la graine (rayon, puis direction par pseudo-angle).
function A.feux(c, rl, R, n, graine)
  local etat = { v = (graine * 7 % 2147483646) + 1 }
  for _ = 1, 3 do B.alea(etat) end
  local out = {}
  for i = 1, n do
    local r = rl + (R - rl) * B.alea(etat)
    local ux, uy = A.direction(4 * B.alea(etat))
    out[i] = { x = c.x + ux * r, y = c.y + uy * r }
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Tournesol, « Le Zénith »
---------------------------------------------------------------------------------------------------
--- La spirale va du BORD vers le CENTRE : u (en tours, pas `pas` tuiles par tour) de U = R / pas à 0. La vitesse du point est à peu près
--- constante : u(t) = U × √(1 − t / T).
function A.u_zenith(t, T, U)
  if t >= T then return 0 end
  if t <= 0 then return U end
  return U * math.sqrt(1 - t / T)
end

--- Point de la spirale au paramètre u (tours) : rayon pas × u, direction de pseudo-angle 4 × (u mod 1).
function A.point_zenith(c, pas, u)
  local ux, uy = A.direction(4 * (u % 1))
  local r = pas * u
  return c.x + ux * r, c.y + uy * r
end

--- Passage du point brûlant près de p : rend t (tick relatif), d (distance radiale au bras le plus proche). Exact pour la spirale de
--- A.point_zenith : au tick t, le point est dans la direction de p, au rayon pas × u.
function A.passage_zenith(p, c, pas, U, T)
  local dx, dy = p.x - c.x, p.y - c.y
  local rr = math.sqrt(dx * dx + dy * dy)
  local a = A.pseudo_angle(dx, dy) / 4
  local k = math.floor(rr / pas - a + 0.5)
  local kmax = math.floor(U - a)
  if k > kmax then k = kmax end
  if k < 0 then k = 0 end
  local u = a + k
  local d = math.abs(rr - pas * u)
  if u > U then u, d = U, math.abs(rr - pas * U) end
  local t = math.floor(T * (1 - (u / U) * (u / U)) + 0.5)
  return t, d
end

--- Tuiles du verre entre u1 et u2 (u2 < u1) : échantillons tous les 0,75 tuile, disque de rayon `pinceau` ; sans doublon dans l'appel.
function A.tuiles_zenith(c, pas, u1, u2, pinceau)
  local x1, y1 = A.point_zenith(c, pas, u1)
  local x2, y2 = A.point_zenith(c, pas, u2)
  local L = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
  local m = math.max(1, math.ceil(L / 0.75))
  local vu, out = {}, {}
  local lim = math.ceil(pinceau)
  for i = 0, m do
    local x, y = A.point_zenith(c, pas, u1 + (u2 - u1) * i / m)
    local tx, ty = math.floor(x), math.floor(y)
    for oy = -lim, lim do
      for ox = -lim, lim do
        local qx, qy = tx + ox, ty + oy
        local ex, ey = qx + 0.5 - x, qy + 0.5 - y
        if ex * ex + ey * ey <= pinceau * pinceau then
          local k = qx .. ":" .. qy
          if not vu[k] then vu[k] = true; out[#out + 1] = { x = qx, y = qy } end
        end
      end
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Plan d'une salve (commun aux 5) : chaque cible reçoit son tick et sa part
---------------------------------------------------------------------------------------------------
--- Plan des coups d'une salve : `cands` = { { x, y, id, mobile } } triés par id. Rend une liste { t, id, i, f, tue } triée par (t, id) :
--- f distance relative (0 plein coup, 1 bord), tue = vrai si la cible est sur le tracé même (falaise, lave, couloir, bras de verre).
--- p = { c = centre, R = zone, w, o (Trombe), U (Tournesol), traits, departs (Stylet : { 0, 0 }), bords, rl (Ixion) }. Seule la lave tue
--- d'office (ce qu'elle recouvre est fondu) ; ailleurs, des dégâts (les résistances comptent).
function A.plan(id, p, cands, sans_tri)
  local a = A.ATTAQUES[id]
  local out = {}
  for i, c in ipairs(cands) do
    local t, f, tue
    if id == "trombe" then
      local tt, d = A.passage_cyclone(c, p.c, p.w, p.o, a.duree, a.pas, a.souffle)
      if tt then t, f, tue = tt, math.max(0, d - a.rayon) / (a.souffle - a.rayon), false end
    elseif id == "ixion" then
      local dd = math.sqrt(d2(c, p.c))
      if dd <= p.R then
        local fl = A.f_lave(p.c, p.bords, c.x, c.y)
        if fl <= 1 then
          t, f, tue = A.t_fonte(fl, p.rl, a.fonte), 0, true
        else
          t, f, tue = math.floor(dd / a.onde), (dd - p.rl) / (p.R - p.rl), false
        end
      end
    elseif id == "tournesol" then
      local dd = math.sqrt(d2(c, p.c))
      if dd <= p.R + a.pas / 2 then
        if dd < a.pas then
          -- au cœur de la spirale (moins d'un tour), l'éclat final au centre
          t, f, tue = a.duree, dd / a.pas, false
        else
          local tt, d = A.passage_zenith(c, p.c, a.pas, p.U, a.duree)
          t, f, tue = tt, math.min(1, d / (a.pas / 2)), false
        end
      end
    elseif id == "cairn" then
      -- l'orage : les éclairs sont tirés à part (A.foudres) ; ici, rien (le plan du Cairn est fait par le script : réseau et orage)
      t = nil
    end
    if t then out[#out + 1] = { t = t, id = c.id, i = i, f = math.max(0, math.min(1, f)), tue = tue } end
  end
  if not sans_tri then table.sort(out, par_id) end
  return out
end

--- Durée totale d'une grande attaque (charge comprise), en ticks, et sa recharge : pour la règle « une à la fois » et les bancs.
function A.duree(id, p)
  local a = A.ATTAQUES[id]
  if id == "cairn" then return a.charge + math.max(a.sauts * a.saut_ticks + a.tenue, a.foudres * a.foudre_ticks) + 40 end
  if id == "stylet" then return a.charge + Ech.BALAYAGE_TICKS + 60 end
  if id == "trombe" then return a.charge + a.duree + 30 end
  if id == "ixion" then return a.charge + a.lance + math.max(A.t_fonte(1, p.rl, a.fonte), math.ceil(p.R / a.onde)) + 30 end
  return a.charge + a.duree + 60
end

return A
