--[[
  CARTE DE VALEUR des sites d'avant-poste (lot IA2-b) — PUR (aucune API Factorio), testable hors jeu
  (tests/valeur_test.lua). Conception : fo-logs/2026-10-24_ANALYSE/IA_ADAPTATIVE.md §B4 :

    valeur(site) = richesse + eau − terrain − accès − danger − contestation      (entiers, points)

  - richesse    : quantité lue UNE fois à la découverte (somme des `amount` des tuiles lues, ≤ 64), courbe saturante
                  1000 × q / (q + RICH_HALF) ; inconnue (partie existante) : RICH_UNKNOWN ;
  - eau         : WATER si de l'eau à moins de 24 tuiles (lue à la découverte) ;
  - terrain     : arbres et rochers (ROUGH par obstacle) et falaises (CLIFF par falaise) autour du site, plafonné ;
  - accès       : distance depuis le TERRITOIRE (QG et propres avant-postes), PAS depuis le QG seul, plus un quart de la
                  distance au QG (les tournées partent du QG) ; ÷ portée = REACH × ambition × appétit du chef ;
  - danger      : vu SOUS BROUILLARD (le runtime ne passe que ce que la faction voit) : QG rivaux connus, avant-postes
                  rivaux vus, et nos propres sites perdus récemment ; × prudence ;
  - contestation: un avant-poste rival vu à moins de CONTEST_R tuiles (gisement disputé) ; × prudence.

  Choix (V.choose) : le meilleur site par valeur, HASARD BORNÉ entre ceux à moins de V.margin(best) de lui (tirage
  uniforme injecté `draw(n)`, flux d'expansion de la faction : Tr.new_stream(graine, 100 + id), sels 100 à 199 réservés à
  IA2-b). Jamais un site franchement moins bon.

  Front (V.pick_front) : point d'où part le prochain tour de prospection (QG ou un de nos avant-postes) ; les bases
  s'étirent le long des gisements trouvés au lieu de grandir en spirale autour du QG.

  Zone de départ (V.start_slots) : les 4 gisements garantis en ÉVENTAIL autour d'un axe tiré (64 directions, table
  constante V.DIRS64 : aucune trigonométrie en jeu), et non plus en croix aux mêmes angles pour toutes les factions.

  Déterminisme : distances par math.sqrt (arrondi IEEE exact), puis entiers (math.floor) ; listes triées ; aucun pairs.
]]

local V = {}

V.SALT = 100            -- flux d'expansion : Tr.new_stream(graine, V.SALT + id)
V.RICH_HALF = 50000     -- richesse à mi-courbe (somme des amount de ≤ 64 tuiles lues)
V.RICH_UNKNOWN = 500    -- richesse d'un site sans lecture (partie existante)
V.WATER = 50
V.ROUGH = 4             -- par arbre ou rocher dans le rayon du chantier
V.CLIFF = 50            -- par falaise
V.TERRAIN_MAX = 400
V.REACH = 220           -- portée de base (tuiles) : un site à REACH tuiles du territoire coûte 1 000 (ambition 1 000)
V.HQ_SHARE = 4          -- la distance au QG compte pour 1 / HQ_SHARE
V.DANGER_HQ_R = 320     -- QG rival : danger (R − d) × 3 en deçà de R
V.DANGER_OP_R = 160     -- avant-poste rival vu : danger (R − d) × 5 en deçà de R
V.CONTEST_R = 64        -- avant-poste rival vu à moins de 64 tuiles : gisement disputé
V.CONTEST = 400
V.LOST_R = 64           -- notre site perdu à moins de 64 tuiles…
V.LOST_TTL = 30 * 3600  -- … depuis moins de 30 min : danger dégressif
V.LOST = 600
V.NEAR = 100            -- hasard borné : marge de V.NEAR pour mille de |meilleure valeur|, au moins MARGIN_MIN
V.MARGIN_MIN = 60

-- Appétit d'expansion selon la dominante du chef (pour mille ; posture inconnue ou absente : 1 000).
V.APPETITE = { expansion = 1300, capitalisation = 1000, technologie = 1000, armee = 950, assaut = 1000, raids = 1000,
  fortification = 800, reconstruction = 750 }

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

--- Appétit d'expansion (pour mille) d'après le mélange de postures du chef (`mix` = { {key, w}, … }, poids pour
--- mille), et la survie (repli : 700). Sans chef : 1 000.
function V.appetite(mix, survival)
  if survival then return 700 end
  if not mix or #mix == 0 then return 1000 end
  local a, wsum = 0, 0
  for _, m in ipairs(mix) do
    a = a + (V.APPETITE[m.key] or 1000) * (m.w or 0)
    wsum = wsum + (m.w or 0)
  end
  if wsum <= 0 then return 1000 end
  return math.floor(a / wsum)
end

--- Portée (tuiles) d'une faction : REACH × ambition × appétit, bornée à [80 ; 600].
function V.reach(ambition, appetite)
  local r = math.floor(V.REACH * (ambition or 1000) / 1000 * (appetite or 1000) / 1000)
  if r < 80 then r = 80 end
  if r > 600 then r = 600 end
  return r
end

--- Composantes de la valeur d'un site. `ctx` :
---   hq {x, y} ; anchors : liste de points du territoire (QG compris) ; rivals : { {x, y, hq = bool}, … } VUS ;
---   lost : { {x, y, tick}, … } nos sites perdus ; tick ; ambition, prudence (pour mille) ; appetite (pour mille).
--- Renvoie { value, rich, water, terrain, access, danger, contest, d_terr, d_hq } (entiers).
function V.components(site, ctx)
  local c = {}
  -- Richesse
  if site.rich then
    c.rich = math.floor(1000 * site.rich / (site.rich + V.RICH_HALF))
  else
    c.rich = V.RICH_UNKNOWN
  end
  c.water = site.water and V.WATER or 0
  local t = (site.rough or 0) * V.ROUGH + (site.cliffs or 0) * V.CLIFF
  c.terrain = t > V.TERRAIN_MAX and V.TERRAIN_MAX or t
  -- Accès : depuis le territoire (QG et avant-postes), plus une part de la distance au QG.
  local d_hq = ctx.hq and dist(site, ctx.hq) or 0
  local d_terr = d_hq
  for _, a in ipairs(ctx.anchors or {}) do
    local d = dist(site, a)
    if d < d_terr then d_terr = d end
  end
  c.d_hq, c.d_terr = math.floor(d_hq), math.floor(d_terr)
  local reach = V.reach(ctx.ambition, ctx.appetite)
  c.reach = reach
  c.access = math.floor(1000 * (d_terr + d_hq / V.HQ_SHARE) / reach)
  -- Danger et contestation (vus), × prudence.
  local danger, contest = 0, 0
  for _, r in ipairs(ctx.rivals or {}) do
    local d = dist(site, r)
    if r.hq then
      if d < V.DANGER_HQ_R then danger = danger + (V.DANGER_HQ_R - d) * 3 end
    else
      if d < V.DANGER_OP_R then danger = danger + (V.DANGER_OP_R - d) * 5 end
      if d < V.CONTEST_R then contest = contest + V.CONTEST end
    end
  end
  for _, l in ipairs(ctx.lost or {}) do
    local age = (ctx.tick or 0) - (l.tick or 0)
    if age >= 0 and age < V.LOST_TTL and dist(site, l) < V.LOST_R then
      danger = danger + V.LOST * (V.LOST_TTL - age) / V.LOST_TTL
    end
  end
  local pru = ctx.prudence or 1000
  c.danger = math.floor(danger * pru / 1000)
  c.contest = math.floor(contest * pru / 1000)
  c.value = c.rich + c.water - c.terrain - c.access - c.danger - c.contest
  return c
end

function V.value(site, ctx)
  return V.components(site, ctx).value
end

--- Marge du hasard borné autour de la meilleure valeur.
function V.margin(best)
  local m = math.floor(math.abs(best) * V.NEAR / 1000)
  if m < V.MARGIN_MIN then m = V.MARGIN_MIN end
  return m
end

--- Classe les candidats (valeur décroissante, puis x, puis y : ordre total, déterministe). `cands` = liste de sites ;
--- renvoie une liste { site, value, comp, i } triée.
function V.rank(cands, ctx)
  local list = {}
  for i, s in ipairs(cands) do
    local comp = V.components(s, ctx)
    list[#list + 1] = { site = s, value = comp.value, comp = comp, i = i }
  end
  table.sort(list, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    if a.site.x ~= b.site.x then return a.site.x < b.site.x end
    if a.site.y ~= b.site.y then return a.site.y < b.site.y end
    return a.i < b.i
  end)
  return list
end

--- Choix d'un site parmi `cands` : hasard borné entre les candidats à moins de V.margin(meilleure) de la meilleure
--- valeur (tirage `draw(n)` seulement s'il y en a au moins 2). Renvoie l'entrée choisie (de V.rank), son rang par
--- valeur (1 = meilleure), son rang par distance au QG (1 = la plus proche) et la liste classée. nil sans candidat.
function V.choose(cands, ctx, draw)
  if #cands == 0 then return nil end
  local list = V.rank(cands, ctx)
  local best = list[1].value
  local m = V.margin(best)
  local n = 0
  for _, e in ipairs(list) do
    if e.value >= best - m then n = n + 1 else break end
  end
  local k = 1
  if n >= 2 and draw then k = draw(n) end
  local chosen = list[k]
  local near_rank = 1
  for _, e in ipairs(list) do
    if e ~= chosen and (e.comp.d_hq < chosen.comp.d_hq
      or (e.comp.d_hq == chosen.comp.d_hq and e.i < chosen.i)) then near_rank = near_rank + 1 end
  end
  return chosen, k, near_rank, list
end

---------------------------------------------------------------------------------------------------
-- Front de prospection
---------------------------------------------------------------------------------------------------
V.FRONT_MIN = 64        -- un avant-poste devient front à 64 tuiles ou plus du QG (les emplacements de 88 et 120 tuiles
                        -- de l'éventail de départ en sont : la prospection part d'abord dans l'axe de la base)
V.FRONT_DRY = 20 * 3600 -- un front dont le tour n'a rien trouvé est laissé 20 min
V.REFRESH = 5 * 3600    -- renouvellement de la réserve : le pire site d'une ressource demandée au complet est oublié

--- Choix du front du prochain tour de prospection. `fronts` = { {key, x, y}, … } (avant-postes à FRONT_MIN tuiles
--- ou plus du QG, triés par clé) ; `ctx` comme V.components ; `dry` = { [key] = tick de fin } ; `turn` = numéro du
--- tour (un tour sur deux part du QG : rien n'est jamais perdu de la prospection autour du QG).
--- Renvoie la clé du front (nil = QG). Note d'un front : − danger − contestation − (d_hq ÷ portée) ; hasard borné.
function V.pick_front(fronts, ctx, dry, turn, draw)
  if (turn or 0) % 2 == 0 then return nil end
  local cands = {}
  for _, p in ipairs(fronts or {}) do
    if not (dry and dry[p.key] and (ctx.tick or 0) < dry[p.key]) then cands[#cands + 1] = p end
  end
  if #cands == 0 then return nil end
  local scored = {}
  local reach = V.reach(ctx.ambition, ctx.appetite)
  for i, p in ipairs(cands) do
    local comp = V.components({ x = p.x, y = p.y, rich = V.RICH_HALF }, { hq = ctx.hq, anchors = nil, rivals = ctx.rivals,
      lost = ctx.lost, tick = ctx.tick, ambition = ctx.ambition, prudence = ctx.prudence, appetite = ctx.appetite })
    -- Le front le plus avancé n'est pas pénalisé par sa distance au QG au-delà de la portée : on le note par le danger.
    local s = -comp.danger - comp.contest - math.floor(1000 * math.min(comp.d_hq, reach) / reach / 4)
    scored[#scored + 1] = { key = p.key, score = s, i = i }
  end
  table.sort(scored, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.i < b.i
  end)
  local best = scored[1].score
  local m = V.margin(best)
  local n = 0
  for _, e in ipairs(scored) do
    if e.score >= best - m then n = n + 1 else break end
  end
  local k = 1
  if n >= 2 and draw then k = draw(n) end
  return scored[k].key
end

---------------------------------------------------------------------------------------------------
-- Zone de départ : gisements garantis en éventail autour d'un axe tiré
---------------------------------------------------------------------------------------------------
-- cos et sin de 2πk/64, k = 0 à 63 (constantes calculées hors jeu ; aucune trigonométrie en jeu).
V.DIRS64 = {
  { 1.0, 0.0 }, { 0.9951847266721969, 0.0980171403295606 }, { 0.9807852804032304, 0.19509032201612825 }, { 0.9569403357322088, 0.29028467725446233 },
  { 0.9238795325112867, 0.3826834323650898 }, { 0.881921264348355, 0.47139673682599764 }, { 0.8314696123025452, 0.5555702330196022 }, { 0.773010453362737, 0.6343932841636455 },
  { 0.7071067811865476, 0.7071067811865476 }, { 0.6343932841636455, 0.7730104533627369 }, { 0.5555702330196023, 0.8314696123025452 }, { 0.4713967368259978, 0.8819212643483549 },
  { 0.38268343236508984, 0.9238795325112867 }, { 0.29028467725446233, 0.9569403357322089 }, { 0.19509032201612833, 0.9807852804032304 }, { 0.09801714032956077, 0.9951847266721968 },
  { 0.0, 1.0 }, { -0.09801714032956065, 0.9951847266721969 }, { -0.1950903220161282, 0.9807852804032304 }, { -0.29028467725446216, 0.9569403357322089 },
  { -0.3826834323650897, 0.9238795325112867 }, { -0.4713967368259977, 0.881921264348355 }, { -0.555570233019602, 0.8314696123025453 }, { -0.6343932841636454, 0.7730104533627371 },
  { -0.7071067811865475, 0.7071067811865476 }, { -0.773010453362737, 0.6343932841636455 }, { -0.8314696123025453, 0.5555702330196022 }, { -0.8819212643483549, 0.4713967368259978 },
  { -0.9238795325112867, 0.3826834323650899 }, { -0.9569403357322088, 0.2902846772544624 }, { -0.9807852804032304, 0.1950903220161286 }, { -0.9951847266721968, 0.09801714032956083 },
  { -1.0, 0.0 }, { -0.9951847266721969, -0.09801714032956059 }, { -0.9807852804032304, -0.19509032201612836 }, { -0.9569403357322089, -0.2902846772544621 },
  { -0.9238795325112868, -0.38268343236508967 }, { -0.881921264348355, -0.47139673682599764 }, { -0.8314696123025455, -0.555570233019602 }, { -0.7730104533627371, -0.6343932841636453 },
  { -0.7071067811865477, -0.7071067811865475 }, { -0.6343932841636459, -0.7730104533627367 }, { -0.5555702330196022, -0.8314696123025452 }, { -0.47139673682599786, -0.8819212643483549 },
  { -0.38268343236509034, -0.9238795325112865 }, { -0.29028467725446244, -0.9569403357322088 }, { -0.19509032201612866, -0.9807852804032303 }, { -0.09801714032956045, -0.9951847266721969 },
  { 0.0, -1.0 }, { 0.09801714032956009, -0.9951847266721969 }, { 0.1950903220161283, -0.9807852804032304 }, { 0.29028467725446205, -0.9569403357322089 },
  { 0.38268343236509, -0.9238795325112866 }, { 0.4713967368259976, -0.881921264348355 }, { 0.5555702330196018, -0.8314696123025455 }, { 0.6343932841636456, -0.7730104533627369 },
  { 0.7071067811865474, -0.7071067811865477 }, { 0.7730104533627365, -0.6343932841636459 }, { 0.8314696123025452, -0.5555702330196022 }, { 0.8819212643483548, -0.4713967368259979 },
  { 0.9238795325112865, -0.3826834323650904 }, { 0.9569403357322088, -0.2902846772544625 }, { 0.9807852804032303, -0.19509032201612872 }, { 0.9951847266721969, -0.0980171403295605 },
}

-- Emplacements de l'éventail (décalage angulaire en 64es de tour par rapport à l'axe, distance en tuiles), dans
-- l'ordre où les gisements les prennent ; les 5 premiers d'abord (éventail de ± 62° autour de l'axe), les suivants
-- si l'eau en bloque. Anneaux de 46, 88 et 120 tuiles ; écart minimal entre deux emplacements : 41 tuiles
-- (gisements de rayon 11 au plus ; contrôlé par tests/valeur_test.lua). L'anneau extérieur est à 80 tuiles ou plus
-- (C.CAPITAL_RADIUS d'IA2-a2) : « la périphérie d'abord » y trouve une cible hors du cœur. Avec 76 tuiles (essai 2),
-- une faction qui ne s'étendait pas n'avait aucune périphérie et perdait son QG à la 1re attaque réussie (F218, F224 ;
-- moteur réel, ia1-scale : Ambre à 39,9 min).
V.FAN = { { 0, 46 }, { 11, 46 }, { -11, 46 }, { 5, 88 }, { -5, 88 }, { 22, 46 }, { -22, 46 }, { 0, 120 },
  { 16, 88 }, { -16, 88 }, { 27, 88 }, { -27, 88 }, { 32, 46 }, { 32, 120 }, { 11, 120 }, { -11, 120 } }

--- Décalages (dx, dy) des emplacements de la zone de départ autour de l'axe `axis` (0 à 63, 0 = est, sens horaire à
--- l'écran : 16 = sud).
function V.start_slots(axis)
  local out = {}
  for _, s in ipairs(V.FAN) do
    local d = V.DIRS64[((axis + s[1]) % 64) + 1]
    out[#out + 1] = { d[1] * s[2], d[2] * s[2] }
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Espacement entre sites (lot SITES) : règle pure, lue par script/faction/sites.lua (réserve et revendications)
---------------------------------------------------------------------------------------------------
-- Moteur réel (trace [FO-SITES], 27/10) : 40 tuiles imposées entre TOUS les sites faisaient refuser le cuivre de
-- votre équipe à 27 tuiles du charbon (retenu à 263 tuiles), la pierre à 14 tuiles. Deux gisements de ressources
-- différentes ne partagent aucune tuile : seuls les avant-postes (foreuses, tourelles) peuvent se gêner, d'où la
-- somme de leurs rayons ; deux sites de la MÊME ressource gardent 40 tuiles (un grand gisement exploité à plusieurs).
V.SPACING_SAME = 40
V.RADIUS_MIN = 6        -- rayon minimal d'un avant-poste (le plus petit gisement de départ, T.seed_radius.stone)

--- Rayon d'un site : étendue des tuiles lues à la découverte (site.radius), au moins V.RADIUS_MIN.
function V.site_radius(site)
  local r = site.radius
  if type(r) ~= "number" or r < V.RADIUS_MIN then return V.RADIUS_MIN end
  return r
end

--- Distance minimale entre deux sites a et b ({ resource, radius } ; ressource inconnue : prudence, 40).
function V.spacing(a, b)
  if a.resource == nil or b.resource == nil or a.resource == b.resource then return V.SPACING_SAME end
  return math.min(V.SPACING_SAME, V.site_radius(a) + V.site_radius(b))
end

--- Vrai si les sites a et b ({ x, y, resource, radius }) sont trop proches l'un de l'autre.
function V.too_close(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  local d = V.spacing(a, b)
  return dx * dx + dy * dy < d * d
end

return V
