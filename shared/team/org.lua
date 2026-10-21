--[[
  ORGANISATION D'UNE ÉQUIPE DE PNJ — PUR (aucune API Factorio). Lot IA1, OBJECTIFS.md C5, conception :
  docs/EQUIPES_PNJ.md.

  Demande du Directeur Créatif (21/10, 21 h 35 et 21 h 45) : environ 30 PNJ par faction, « avec si vous voulez
  des managers aussi », organisés en PÔLES (extraction ; avancée de la base ; protection et territoire), dont
  « peut-être que 5 » généralistes, « des ouvriers à part entière, mais qui soient multifonctions […] les
  couteaux suisses », dont « ces 5 là ils piloteraient en fait différentes parties ». Le joueur : « nous on
  pourrait diriger […] l'orientation principale », « concentrer nos efforts sur tel ou tel aspect ». Les PNJ
  progressent (« crafter plus vite », « se déplacer légèrement plus vite »), et un PNJ mort se ressuscite
  contre un coût.

  Ce module décide QUI fait QUOI. Il ne décide pas QUOI faire (c'est le cerveau d'équipe, planner.lua, puis
  le solveur de production du lot IA1-e) ni COMMENT le faire (programmes d'étapes de script/team/worker.lua).

    MANAGERS     5 domaines, chacun une fonction pure du cerveau (pas un personnage) : gisements,
                 logistique, production, infrastructures, défense. Chaque tâche appartient à un domaine
                 (celui de son projet, sinon celui de son type : O.TASK_DOMAIN), chaque domaine à un pôle.
    GÉNÉRALISTES environ 1 PNJ sur 6 (5 sur 30, réglable) : de vrais ouvriers, rattachés à un pôle de
                 référence, qui MÈNENT ce que le cerveau leur confie (`projects` : un projet, ou une partie
                 durable, ou un domaine entier : l'interprétation est soumise au Directeur Créatif, question
                 Q-IA1-6 de docs/EQUIPES_PNJ.md) ; eux seuls prennent les tâches de conception.
    EXÉCUTANTS   les autres : répartis entre les 3 pôles selon les besoins (travail ouvert ET restant des
                 tâches en cours) et l'orientation, avec hystérésis. Un exécutant occupé n'est jamais
                 interrompu : son changement de pôle est DIFFÉRÉ (champ `dest`), appliqué à la fin de sa tâche
                 (O.settle). Les exécutants du territoire sont nommés aux zones (2 par zone par défaut).

  Règles du projet respectées (ARCHITECTURE §2) : aucune API, aucune itération décidée par l'ordre de
  `pairs` (listes et ordres fixes), aucun temps mesuré, aucune trigonométrie, arithmétique ENTIÈRE dans les
  décisions (répartitions au plus fort reste entier, coûts, plafonds), données sérialisables (aucune
  fonction renvoyée dans un résultat destiné à global).

  API principale :
    O.plan(input)                -> décisions d'une pensée (cibles par pôle, mouvements immédiats ou différés,
                                    équipes de zone, promotion, pôles des généralistes, meneurs), avec `ops`
    O.settle(npc, tick)          -> fin de tâche : applique le pôle de destination différé (seule fonction qui
                                    modifie son argument : l'état du PNJ tenu par le runtime)
    O.pick_task(npc, tasks, ctx) -> la tâche qu'un PNJ inoccupé prend (un seul passage, O(T))
    O.share_tokens(total, demands, turn) -> jetons de travail d'un tick, partagés à tour de rôle entre équipes
    O.modifiers(rank, profile, difficulty) -> modificateurs par personnage (LuaControl.character_*)
    O.resurrection, O.recruit_cost, O.cost_value, O.revive_policy
    O.headcount_cap(epoch, max), O.generalists_wanted(n, chiefs), O.normalize(orientation, threatened)
]]

local T = require("shared.team.config")

local O = {}

---------------------------------------------------------------------------------------------------
-- Pôles et domaines (ordre FIXE : il sert aussi à départager les égalités)
---------------------------------------------------------------------------------------------------
O.POLES = { "extraction", "base", "territoire" }
O.POLE_INDEX = { extraction = 1, base = 2, territoire = 3 }
-- Ordre de départage des égalités entre pôles : normal, et sous menace (le territoire d'abord).
O.POLE_ORDER = { 1, 2, 3 }
O.THREAT_ORDER = { 3, 1, 2 }

O.DOMAINS = {
  { key = "gisements",       pole = "extraction" }, -- « s'occuperait des ressources » ; minerai fondu en plaques
  { key = "logistique",      pole = "extraction" }, -- porteurs, tournées, tapis, poteaux, conduites
  { key = "production",      pole = "base" },       -- « tout ce qui va être automatisé, la construction de tel ou tel objet »
  { key = "infrastructures", pole = "base" },       -- « d'améliorer par exemple les infrastructures existantes », énergie
  { key = "defense",         pole = "territoire" }, -- zones, tourelles, ravitaillement, reconstruction
}
O.DOMAIN_POLE = {}
for _, d in ipairs(O.DOMAINS) do O.DOMAIN_POLE[d.key] = d.pole end

-- Domaine de chaque type de tâche, quand la tâche n'appartient à AUCUN projet (une tâche de projet prend le
-- domaine de son projet : O.task_domain). Les 9 premiers existent déjà (shared/team/planner.lua) : le modèle
-- s'applique tel quel au cerveau d'aujourd'hui (lot IA1-b). Les suivants arrivent avec les lots IA1-c à g.
O.TASK_DOMAIN = {
  -- existants
  build = "gisements", extend = "gisements", mine = "gisements", smelt = "gisements", smelters = "gisements",
  service = "logistique",
  craft = "production",
  refill = "defense", fortify = "defense",
  -- nouveaux (IA1)
  drill_line = "gisements", pumpjack = "gisements", clear = "gisements",
  carry = "logistique", belt = "logistique", pipe = "logistique", power_line = "logistique", recover = "logistique",
  ghost = "production", recipe = "production", lab = "production",
  upgrade = "infrastructures", replace = "infrastructures", repair = "infrastructures", power_plant = "infrastructures",
  zone_ring = "defense", garrison = "defense", rebuild = "defense",
  -- conception (généralistes seulement)
  claim_site = "gisements", route = "logistique", plan_module = "production", claim_lot = "production",
  plan_upgrade = "infrastructures", open_zone = "defense", unblock = "production",
}
-- Tâches de CONCEPTION : réservées aux généralistes (choisir et réserver un lot, implanter un gabarit, tracer
-- une conduite ou une ligne, ouvrir une zone, débloquer un échec). `unblock` porte le domaine de la tâche
-- bloquée dans task.domain.
O.DESIGN_KINDS = {
  claim_site = true, route = true, plan_module = true, claim_lot = true, plan_upgrade = true, open_zone = true,
  unblock = true,
}
-- Travail MANUEL plafonné (règle d'automatisation, §6.6 de docs/EQUIPES_PNJ.md) : au-delà du plafond, la tâche
-- reste au tableau, le manque se voit et le cerveau lance un projet d'automatisation (tapis, conduite).
O.MANUAL_KINDS = { mine = "minage", carry = "portage", service = "portage" }
-- URGENCE : une tâche de priorité >= 90 (ravitaillement des tourelles, combustible d'un avant-poste à sec) passe
-- AVANT le travail ordinaire du pôle du PNJ, quel que soit son pôle, et hors plafond manuel. Hors de son pôle,
-- au plus O.urgent_away_cap(exécutants) PNJ à la fois (pas de ruée de toute l'équipe).
O.URGENT_PRIO = 90
O.URGENT_AWAY_PCT = 20

-- Durée estimée d'une tâche (secondes de travail, trajets compris) quand la tâche n'en donne pas (task.work).
-- Estimations de conception, À MESURER au lot IA1-b (statistiques par type, journal [FO-TEAM]).
O.TASK_WORK = {
  build = 90, extend = 60, mine = 60, smelt = 40, smelters = 30, service = 45, craft = 30, refill = 40, fortify = 60,
  drill_line = 90, pumpjack = 60, clear = 20, carry = 60, belt = 60, pipe = 60, power_line = 60, recover = 60,
  ghost = 60, recipe = 10, lab = 40, upgrade = 30, replace = 30, repair = 30, power_plant = 90,
  zone_ring = 90, garrison = 300, rebuild = 60,
  claim_site = 10, route = 30, plan_module = 20, claim_lot = 10, plan_upgrade = 10, open_zone = 20, unblock = 30,
}
O.DEFAULT_WORK = 60

---------------------------------------------------------------------------------------------------
-- Réglages du modèle (valeurs ❔ : propositions soumises au Directeur Créatif, docs/EQUIPES_PNJ.md §11)
---------------------------------------------------------------------------------------------------
O.HORIZON_S = 300            -- besoin d'un pôle = secondes de travail (ouvert + restant) / 300 s = PNJ équivalents
O.CAP_NUM, O.CAP_DEN = 5, 4  -- un pôle reçoit au plus ceil(besoin × 5/4) exécutants avant le « fond »
O.FLOOR_EXTRACTION = 2       -- plancher : 2 exécutants à l'extraction
O.FLOOR_PER_ZONE = 2         -- équipe d'une zone par défaut : 2 PNJ nommés (« j'ai par exemple […] 2 PNJ »)
O.ZONE_FLOOR_MAX_PCT = 50    -- les équipes de zone prennent au plus 50 % des exécutants (avertissement au-delà)
O.THREAT_POINTS = 20         -- menace : +20 points ENTIERS au territoire, pris aux deux autres pôles au prorata
O.MAX_MOVES = 2              -- hystérésis : au plus 2 décisions de changement de pôle par pensée…
O.MOVE_GAP = 2               -- … seulement si l'écart à la cible atteint 2 d'un côté au moins…
O.MOVE_COOLDOWN = 10 * 3600  -- … et jamais le même PNJ moins de 10 min après son dernier changement EFFECTIF
                             -- (exécutants et généralistes) : <= 6 changements par heure glissante [t, t + 1 h)
O.GENERALIST_PER = 6         -- un généraliste pour 6 PNJ (5 sur 30)
O.GENERALIST_MIN_SHARE = 15  -- un pôle orienté à 15 % ou plus a au moins un généraliste (si le nombre le permet)
O.PROMOTION_DELAY = 2 * 3600 -- un généraliste mort est remplacé par promotion après 2 min (sauf résurrection)

-- Préréglages d'orientation (en points, somme 100) : l'onglet « Orientation » de l'interface les propose.
O.PRESETS = {
  equilibre  = { extraction = 40, base = 40, territoire = 20 },
  ressources = { extraction = 60, base = 25, territoire = 15 },
  base       = { extraction = 25, base = 60, territoire = 15 },
  protection = { extraction = 20, base = 25, territoire = 55 },
  expansion  = { extraction = 45, base = 20, territoire = 35 },
}
O.PRESET_ORDER = { "equilibre", "ressources", "base", "protection", "expansion" }
-- Orientation des factions IA, tirée de leur personnalité (shared/faction/config.lua).
O.PERSONALITY = {
  conqueror  = { extraction = 33, base = 33, territoire = 34 },
  technocrat = { extraction = 47, base = 47, territoire = 6 },
  builder    = { extraction = 40, base = 53, territoire = 7 },
  balanced   = { extraction = 40, base = 40, territoire = 20 },
}

---------------------------------------------------------------------------------------------------
-- Effectifs
---------------------------------------------------------------------------------------------------
O.START = 8                              -- effectif de départ (2 aujourd'hui) : 2 généralistes + 6 exécutants
O.CAP_FRACTION = { { 1, 2 }, { 5, 6 } }  -- plafond à l'époque 1 : 1/2 du maximum ; époque 2 : 5/6 ; ensuite : tout
                                         -- (proposition ❔ ; options chiffrées : Q-IA1-2)

--- Plafond d'effectif d'une équipe à l'époque `epoch` pour un maximum réglé `max` (entier, arrondi au-dessus).
--- 30 -> 15, 25, 30 ; 10 -> 5, 9, 10 ; 50 -> 25, 42, 50. `fractions` remplace O.CAP_FRACTION (option « 30 dès
--- l'époque 1 » : {}).
function O.headcount_cap(epoch, max, fractions)
  local fr = (fractions or O.CAP_FRACTION)[epoch or 1]
  if not fr then return max end
  return math.floor((max * fr[1] + fr[2] - 1) / fr[2])
end

--- Effectif de départ, borné par le plafond de l'époque 1.
function O.start_headcount(max, fractions)
  return math.min(O.START, O.headcount_cap(1, max, fractions))
end

--- Généralistes voulus pour n PNJ vivants : un pour 6 (arrondi au-dessus), au plus `chiefs` (réglage, 5).
function O.generalists_wanted(n, chiefs)
  if n <= 0 then return 0 end
  local g = math.floor((n + O.GENERALIST_PER - 1) / O.GENERALIST_PER)
  return math.min(chiefs or 5, g, n)
end

---------------------------------------------------------------------------------------------------
-- Outils déterministes (arithmétique entière)
---------------------------------------------------------------------------------------------------
--- Coût compté d'un tri de n éléments : n × ceil(log2 n). On ne compte pas les appels du comparateur, qui
--- dépendent de l'ordre d'entrée : le travail compté ne dépend ainsi que des tailles (test reproductible).
local function sort_cost(n)
  local c, k = 0, 1
  while k < n do k = k * 2; c = c + 1 end
  return n * c
end
O.sort_cost = sort_cost

--- Division entière exacte a = q × b + r (0 <= r < b), a >= 0 et b > 0 entiers : le quotient flottant est
--- corrigé pour rester exact quelle que soit l'erreur d'arrondi de la division.
local function idiv(a, b)
  local q = math.floor(a / b)
  while q * b > a do q = q - 1 end
  while (q + 1) * b <= a do q = q + 1 end
  return q, a - q * b
end

--- Répartit `total` unités entières selon `weights` (liste, poids tronqués à des entiers >= 0) : méthode du
--- plus fort reste, en ENTIERS (restes comparés comme entiers, aucun flottant) ; égalité de reste départagée
--- par `order` (liste d'indices, par défaut 1..n). Poids tous nuls -> zéros. `ops` (table { n = }) compte.
function O.apportion(total, weights, ops, order)
  local n = #weights
  local out, w, sum = {}, {}, 0
  for i = 1, n do
    local v = weights[i] or 0
    w[i] = v > 0 and math.floor(v) or 0
    sum = sum + w[i]
    out[i] = 0
  end
  if total <= 0 or sum <= 0 then return out end
  local rank = {}
  if order then for k, i in ipairs(order) do rank[i] = k end end
  local given, rest = 0, {}
  for i = 1, n do
    local q, r = idiv(total * w[i], sum)
    out[i] = q
    given = given + q
    rest[i] = { i = i, r = r, k = rank[i] or i }
    if ops then ops.n = ops.n + 1 end
  end
  if ops then ops.n = ops.n + sort_cost(n) end
  table.sort(rest, function(a, b)
    if a.r ~= b.r then return a.r > b.r end
    return a.k < b.k
  end)
  local k = 1
  while given < total do
    local i = rest[k].i
    out[i] = out[i] + 1
    given = given + 1
    k = k % n + 1
  end
  return out
end

local function by_id(a, b) return a.id < b.id end

local function copy_list(list)
  local out = {}
  for i = 1, #list do out[i] = list[i] end
  return out
end

--- Partage les `total` jetons de travail d'un tick entre les équipes, un par un à tour de rôle, à partir de
--- l'équipe `turn` (indice 1-based, qui tourne à chaque tick : `tick % #demands + 1`). demands = liste (ordre
--- fixe des équipes) d'unités voulues. Renvoie la liste des unités accordées (somme <= total, chacune <= sa
--- demande ; deux équipes non servies en entier diffèrent d'au plus 1). O(total + équipes).
--- Usage (docs/EQUIPES_PNJ.md §12) : fantômes posés et ravivés, nœuds d'A*, évaluations de lot et de rue :
--- un budget PAR TICK POUR TOUT LE MOD, et non par équipe.
O.TICK_BUDGET = 400 -- unités de travail par tick pour tout le mod (1 unité ≈ 1 µs estimée, à étalonner par R4)
O.OP_UNITS = { ghost = 50, revive = 50, astar_node = 2, lot_eval = 50, street_eval = 50 } -- estimés, R4
function O.share_tokens(total, demands, turn)
  local n = #demands
  local out, left = {}, {}
  for i = 1, n do
    out[i] = 0
    local d = demands[i] or 0
    left[i] = d > 0 and math.floor(d) or 0
  end
  if n == 0 or total <= 0 then return out end
  local i = ((turn or 1) - 1) % n + 1
  local given, misses = 0, 0
  while given < total and misses < n do
    if left[i] > 0 then
      out[i] = out[i] + 1
      left[i] = left[i] - 1
      given = given + 1
      misses = 0
    else
      misses = misses + 1
    end
    i = i % n + 1
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Orientation
---------------------------------------------------------------------------------------------------
--- Orientation normalisée en LISTE de 3 points entiers {extraction, base, territoire} de somme 100.
--- Accepte un nom de préréglage, une table { extraction =, base =, territoire = } ou une liste de 3 nombres
--- (entiers attendus ; une fraction est tronquée). Valeurs négatives ramenées à 0 ; tout à 0 -> équilibre.
--- threatened = true : +20 points ENTIERS au territoire (au plus jusqu'à 100), retirés à l'extraction et à la
--- base au prorata de leurs points (plus fort reste entier).
function O.normalize(o, threatened)
  if type(o) == "string" then o = O.PRESETS[o] or O.PRESETS.equilibre end
  o = o or O.PRESETS.equilibre
  local raw, sum = {}, 0
  for i, p in ipairs(O.POLES) do
    local v = o[p] or o[i] or 0
    raw[i] = v > 0 and math.floor(v) or 0
    sum = sum + raw[i]
  end
  if sum <= 0 then
    local e = O.PRESETS.equilibre
    raw = { e.extraction, e.base, e.territoire }
  end
  local pts = O.apportion(100, raw)
  if threatened then
    local add = math.min(O.THREAT_POINTS, 100 - pts[3])
    if add > 0 then
      local take = O.apportion(add, { pts[1], pts[2] })
      pts = { pts[1] - take[1], pts[2] - take[2], pts[3] + add }
    end
  end
  return pts
end

---------------------------------------------------------------------------------------------------
-- Domaines des tâches et besoin par pôle
---------------------------------------------------------------------------------------------------
--- Carte « id de projet -> domaine » (consultée par clé, jamais parcourue).
function O.project_domains(projects)
  local m = {}
  for _, p in ipairs(projects or {}) do
    if p.id ~= nil and p.domain then m[p.id] = p.domain end
  end
  return m
end

--- Domaine d'une tâche : domaine explicite, sinon celui de SON PROJET (`proj_dom`, carte de
--- O.project_domains), sinon celui de son type ; inconnu -> production. Une tâche ghost d'un projet Pétrole
--- (domaine gisements) va donc au pôle Extraction, pas au pôle Base.
function O.task_domain(task, proj_dom)
  if task.domain then return task.domain end
  if proj_dom and task.project ~= nil and proj_dom[task.project] then return proj_dom[task.project] end
  return O.TASK_DOMAIN[task.kind] or "production"
end
function O.task_pole(task, proj_dom)
  return O.DOMAIN_POLE[O.task_domain(task, proj_dom)] or "base"
end

--- Travail par domaine et par pôle (secondes) d'une liste de tâches : la « demande » des managers.
--- Tâche libre : son travail estimé (task.work, sinon O.TASK_WORK). Tâche PRISE (task.worker) : son travail
--- RESTANT, task.work_left fourni par le runtime, sinon la moitié de l'estimation (reste moyen d'une tâche
--- observée à un instant quelconque : estimé). Un pôle dont tout le travail est pris ne paraît donc pas vide.
--- Renvoie { domains = { [domaine] = s }, poles = { s, s, s } (ouvert + restant), open = {…}, taken = {…} } ; O(T).
function O.demand_from_tasks(tasks, ops, proj_dom)
  local dom, poles, open, taken = {}, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }
  for _, d in ipairs(O.DOMAINS) do dom[d.key] = 0 end
  for i = 1, #tasks do
    local t = tasks[i]
    local d = O.task_domain(t, proj_dom)
    local w = t.work or O.TASK_WORK[t.kind] or O.DEFAULT_WORK
    local p = O.POLE_INDEX[O.DOMAIN_POLE[d] or "base"]
    if t.worker then
      w = t.work_left or math.floor(w / 2)
      taken[p] = taken[p] + w
    else
      open[p] = open[p] + w
    end
    dom[d] = (dom[d] or 0) + w
    poles[p] = poles[p] + w
    if ops then ops.n = ops.n + 1 end
  end
  return { domains = dom, poles = poles, open = open, taken = taken }
end

---------------------------------------------------------------------------------------------------
-- Zones (territoire) : liste triée et plancher borné
---------------------------------------------------------------------------------------------------
--- zones = nombre de zones anonymes (2 PNJ chacune) ou liste { { id, prio, crew }, ... }. Renvoie une copie
--- triée par priorité décroissante puis id, avec crew (2 par défaut) et prio (0 par défaut).
function O.zone_list(zones, ops)
  local out = {}
  if type(zones) == "number" then
    for i = 1, zones do out[i] = { id = i, prio = 0, crew = O.FLOOR_PER_ZONE } end
    return out
  end
  for i, z in ipairs(zones or {}) do
    out[i] = { id = z.id, prio = z.prio or 0, crew = z.crew or O.FLOOR_PER_ZONE }
  end
  if ops then ops.n = ops.n + sort_cost(#out) end
  table.sort(out, function(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    return a.id < b.id
  end)
  return out
end

---------------------------------------------------------------------------------------------------
-- Cibles par pôle (exécutants)
---------------------------------------------------------------------------------------------------
--- n exécutants ; need = { s, s, s } secondes de travail (ouvert + restant) par pôle ; pts = orientation (3
--- entiers, somme 100) ; zones = nombre ou liste (O.zone_list). Renvoie :
---   t = cibles { e, b, t } (somme n) ;
---   surplus = exécutants AU-DELÀ DU CARNET (travail ouvert + restant à l'horizon de 5 min), envoyés au « fond »
---     du pôle le mieux orienté (agrandir, prospecter, renforcer). Ce n'est PAS un taux d'inactivité : un
---     exécutant au travail peut compter dans le surplus si le carnet ne l'occupera plus dans 5 min ;
---   info = { zone_wanted = PNJ voulus par les zones, zone_floor = plancher retenu (borné), capped = vrai si
---     les zones demandent plus que 50 % des exécutants ou que l'effectif ne permet }.
---
--- 1. Partage pondéré « orientation × besoin », chaque pôle plafonné à ceil(besoin × 5/4) PNJ (on ne met
---    pas 10 PNJ sur 2 tâches) ; 3 tours de remplissage au plus.
--- 2. Ce qui reste va au fond, selon l'orientation seule.
--- 3. Planchers (extraction 2 ; territoire : somme des équipes de zone, bornée à 50 % des exécutants) pris
---    aux pôles les mieux pourvus.
function O.pole_targets(n, need, pts, zones, ops)
  ops = ops or { n = 0 }
  local t = { 0, 0, 0 }
  local zl = (type(zones) == "table" and zones[1] and zones[1].crew) and zones or O.zone_list(zones or 0, ops)
  local wanted = 0
  for _, z in ipairs(zl) do wanted = wanted + z.crew end
  if n <= 0 then return t, 0, { zone_wanted = wanted, zone_floor = 0, capped = wanted > 0, floors = { 0, 0, 0 } } end
  local cap = {}
  for p = 1, 3 do
    -- besoin en PNJ = s / horizon ; plafond = ceil(besoin × 5/4) en arithmétique entière
    local s = math.floor(need[p] or 0)
    cap[p] = idiv(s * O.CAP_NUM + O.HORIZON_S * O.CAP_DEN - 1, O.HORIZON_S * O.CAP_DEN)
  end
  local left = n
  for _ = 1, 3 do
    if left <= 0 then break end
    local w = {}
    for p = 1, 3 do w[p] = cap[p] > 0 and pts[p] * math.floor(need[p] or 0) or 0 end
    local share = O.apportion(left, w, ops)
    local given = 0
    for p = 1, 3 do
      local g = math.min(share[p], cap[p])
      t[p] = t[p] + g
      cap[p] = cap[p] - g
      given = given + g
      ops.n = ops.n + 1
    end
    left = left - given
    if given == 0 then break end
  end
  local surplus = left
  if left > 0 then
    local share = O.apportion(left, pts, ops)
    for p = 1, 3 do t[p] = t[p] + share[p] end
  end
  -- Planchers, dans l'ordre des pôles ; on prend au pôle qui a le plus au-dessus de son propre plancher.
  local floor = { math.min(O.FLOOR_EXTRACTION, n), 0, 0 }
  floor[3] = math.min(wanted, (idiv(n * O.ZONE_FLOOR_MAX_PCT, 100)), n - floor[1])
  for p = 1, 3 do
    while t[p] < floor[p] do
      local donor, best = nil, 0
      for q = 1, 3 do
        local spare = t[q] - floor[q]
        if q ~= p and spare > best then donor, best = q, spare end
        ops.n = ops.n + 1
      end
      if not donor then break end
      t[donor] = t[donor] - 1
      t[p] = t[p] + 1
    end
  end
  return t, surplus, { zone_wanted = wanted, zone_floor = floor[3], capped = wanted > floor[3], floors = floor }
end

---------------------------------------------------------------------------------------------------
-- Généralistes : pôles de référence (stables) et meneurs
---------------------------------------------------------------------------------------------------
--- Quotas de généralistes par pôle : d'abord un pour chaque pôle orienté à 15 % ou plus (du plus orienté au
--- moins orienté ; égalité départagée par `order`, O.POLE_ORDER par défaut, O.THREAT_ORDER sous menace : le
--- territoire n'est alors jamais derrière un pôle à égalité), tant qu'il en reste ; le reste selon l'orientation.
function O.generalist_quotas(g, pts, ops, order)
  local q = { 0, 0, 0 }
  if g <= 0 then return q end
  order = order or O.POLE_ORDER
  local pos = {}
  for k, p in ipairs(order) do pos[p] = k end
  local sorted = { 1, 2, 3 }
  table.sort(sorted, function(a, b)
    if pts[a] ~= pts[b] then return pts[a] > pts[b] end
    return pos[a] < pos[b]
  end)
  local used = 0
  for _, p in ipairs(sorted) do
    if used < g and pts[p] >= O.GENERALIST_MIN_SHARE then
      q[p] = 1
      used = used + 1
    end
  end
  if used < g then
    local share = O.apportion(g - used, pts, ops, order)
    for p = 1, 3 do q[p] = q[p] + share[p] end
  end
  return q
end

--- Pôle de référence de chaque généraliste, en changeant le moins possible et avec le même délai de garde
--- que les exécutants : un généraliste changé il y a moins de 10 min GARDE son pôle (même au-delà du quota) ;
--- les autres gardent leur pôle s'il a encore un quota (par id croissant) ; le reste va aux pôles qui manquent
--- (dans `order`). gens : liste triée par id de { id, pole, moved_tick }. Renvoie gen_poles = { { id, pole } }
--- (même ordre) et gen_moves = { { id, from, to } } (changements, à dater par l'appelant : moved_tick = tick).
local function generalist_poles(gens, quotas, tick, order, ops)
  local left = { quotas[1], quotas[2], quotas[3] }
  local out, pending, moves = {}, {}, {}
  for i, g in ipairs(gens) do
    local p = g.pole and O.POLE_INDEX[g.pole]
    if p and g.moved_tick ~= nil and tick - g.moved_tick < O.MOVE_COOLDOWN then
      left[p] = left[p] - 1
      out[i] = { id = g.id, pole = g.pole }
    end
    ops.n = ops.n + 1
  end
  for i, g in ipairs(gens) do
    if not out[i] then
      local p = g.pole and O.POLE_INDEX[g.pole]
      if p and left[p] > 0 then
        left[p] = left[p] - 1
        out[i] = { id = g.id, pole = g.pole }
      else
        pending[#pending + 1] = i
      end
    end
    ops.n = ops.n + 1
  end
  for _, i in ipairs(pending) do
    local pole
    for _, p in ipairs(order) do
      if left[p] > 0 then
        left[p] = left[p] - 1
        pole = O.POLES[p]
        break
      end
    end
    -- Plus de généralistes que de quotas (équipe qui rétrécit) : on garde l'ancien pôle, sinon la base.
    pole = pole or gens[i].pole or "base"
    out[i] = { id = gens[i].id, pole = pole }
    if gens[i].pole and gens[i].pole ~= pole then
      moves[#moves + 1] = { id = gens[i].id, from = gens[i].pole, to = pole }
    end
    ops.n = ops.n + 1
  end
  return out, moves
end

--- Meneurs. projects = { { id, domain, prio, leader, started }, ... } : ce que le cerveau confie à un
--- généraliste (un projet, une partie durable ou un domaine : Q-IA1-6) ; gens = { { id, pole }, ... }.
--- Un généraliste mène au plus un élément. Un élément garde son meneur s'il est toujours généraliste et vivant
--- (stabilité). Les éléments sans meneur sont servis par priorité effective décroissante (égalité : id) : un
--- élément COMMENCÉ (fantômes posés, matériaux engagés) gagne O.ENGAGED_BONUS points, pour qu'un chantier
--- orphelin soit repris avant d'en ouvrir un nouveau. Chacun est servi par le généraliste libre du même pôle
--- d'abord, sinon le premier libre (id croissant). Renvoie leaders = { { project, npc }, ... } (ordre des
--- éléments servis) et waiting = { id, ... }.
O.ENGAGED_BONUS = 20
local function assign_leaders(projects, gens, ops)
  local is_gen, gen_pole = {}, {}
  for _, g in ipairs(gens) do is_gen[g.id] = true; gen_pole[g.id] = g.pole end
  local order = copy_list(projects)
  local function eff(p) return (p.prio or 0) + (p.started and O.ENGAGED_BONUS or 0) end
  ops.n = ops.n + sort_cost(#order)
  table.sort(order, function(a, b)
    local ea, eb = eff(a), eff(b)
    if ea ~= eb then return ea > eb end
    return a.id < b.id
  end)
  local busy, leaders, waiting = {}, {}, {}
  local keep = {}
  for i, pr in ipairs(order) do
    if pr.leader and is_gen[pr.leader] and not busy[pr.leader] then
      busy[pr.leader] = true
      keep[i] = pr.leader
    end
    ops.n = ops.n + 1
  end
  for i, pr in ipairs(order) do
    local chosen = keep[i]
    if not chosen then
      local pole = O.DOMAIN_POLE[pr.domain] or "base"
      local first
      for _, g in ipairs(gens) do
        ops.n = ops.n + 1
        if not busy[g.id] then
          if gen_pole[g.id] == pole then chosen = g.id break end
          first = first or g.id
        end
      end
      chosen = chosen or first
      if chosen then busy[chosen] = true end
    end
    if chosen then
      leaders[#leaders + 1] = { project = pr.id, npc = chosen }
    else
      waiting[#waiting + 1] = pr.id
    end
  end
  return leaders, waiting
end

--- Meilleur exécutant à promouvoir : rang, puis expérience, puis id le plus petit.
local function best_executant(execs)
  local best
  for _, e in ipairs(execs) do
    if not best or e.rank > best.rank or (e.rank == best.rank and (e.xp > best.xp or (e.xp == best.xp and e.id < best.id))) then
      best = e
    end
  end
  return best
end

---------------------------------------------------------------------------------------------------
-- État d'un PNJ : pôle effectif et fin de tâche
---------------------------------------------------------------------------------------------------
--- Pôle EFFECTIF d'un PNJ : sa destination différée s'il en a une, sinon son pôle.
function O.effective_pole(npc)
  return npc.dest or npc.pole
end

--- Fin de tâche d'un PNJ (appelée par le runtime AVANT qu'il prenne sa tâche suivante) : un changement de pôle
--- différé devient effectif et le délai de garde part de cet instant. Modifie `npc` (état du runtime) ;
--- renvoie vrai si le pôle a changé.
function O.settle(npc, tick)
  if npc.dest == nil then return false end
  local changed = npc.dest ~= npc.pole
  npc.pole, npc.dest = npc.dest, nil
  if changed then npc.moved_tick = tick end
  return changed
end

---------------------------------------------------------------------------------------------------
-- Pensée d'organisation
---------------------------------------------------------------------------------------------------
--[[
  input = {
    tick,
    npcs = { { id, role = "generalist"|"executant", pole, dest, rank, xp, idle, work_left, moved_tick, zone }, ... }
           -- vivants ; dest = pôle de destination différé ; work_left = secondes restantes de la tâche en cours
    tasks = { tâche, ... }        -- tableau de l'équipe (libres ET prises) ; ou `need` = { s, s, s }
    orientation,                  -- préréglage, table ou liste (voir O.normalize)
    threatened,                   -- menace en cours
    zones,                        -- nombre de zones, ou liste { { id, prio, crew }, ... }
    projects = { { id, domain, prio, leader, started }, ... },
    chiefs,                       -- réglage fo-team-chiefs (5)
    vacancy_since,                -- tick de la mort d'un généraliste non remplacé (nil : croissance)
  }
  Renvoie {
    pts      = orientation en points (3 entiers),
    need     = travail (ouvert + restant) par pôle (s),
    targets  = cibles d'exécutants par pôle { e, b, t } ; surplus (au-delà du carnet, voir O.pole_targets),
    place    = { { id, pole }, ... }  recrues sans pôle placées, sans délai,
    moves    = { { id, from, to, deferred }, ... } au plus O.MAX_MOVES décisions :
               deferred = false : PNJ inoccupé, l'appelant pose pole = to et moved_tick = tick ;
               deferred = true  : PNJ occupé, l'appelant pose dest = to ; O.settle l'applique à la fin de la tâche.
               Un PNJ qui a déjà une destination différée n'est jamais redésigné avant de l'avoir rejointe.
    assigned = effectifs par pôle EFFECTIF après décisions { e, b, t } (destinations comprises),
    crews    = { { zone, npcs = { id, ... }, wanted }, ... } équipes nommées (ordre de priorité des zones),
    zone_of  = { { id, zone }, ... } (par id) : l'appelant pose npc.zone, et nil pour les autres exécutants,
    zone_short = { id de zone, ... } zones sous effectif ; warnings = { "trop_de_zones" } le cas échéant,
    promote  = id d'un exécutant à promouvoir, ou nil ; generalists_wanted,
    gen_poles = { { id, pole }, ... }, gen_moves = { { id, from, to } } (à dater : moved_tick), leaders, waiting,
    idle_rate = inactifs / vivants (taux d'inactivité RÉEL, critère C5-2 ; distinct du surplus),
    ops      = unités de travail comptées (coût borné, critère du test)
  }
  L'appelant applique les décisions ; ce module ne modifie pas `input`.
]]
function O.plan(input)
  local ops = { n = 0 }
  local tick = input.tick or 0
  local threatened = input.threatened and true or false
  local order = threatened and O.THREAT_ORDER or O.POLE_ORDER
  local pts = O.normalize(input.orientation, threatened)

  -- Population, triée par id (l'ordre d'entrée ne compte pas).
  local all = copy_list(input.npcs or {})
  ops.n = ops.n + sort_cost(#all)
  table.sort(all, by_id)
  local gens, execs = {}, {}
  local idle_n = 0
  for _, a in ipairs(all) do
    if a.role == "generalist" then
      gens[#gens + 1] = { id = a.id, pole = O.effective_pole(a), moved_tick = a.moved_tick }
    else
      execs[#execs + 1] = a
    end
    if a.idle then idle_n = idle_n + 1 end
    ops.n = ops.n + 1
  end

  -- Promotion : une par pensée, si les généralistes manquent (mort : après 2 min ; croissance : aussitôt).
  local wanted = O.generalists_wanted(#all, input.chiefs)
  local promote
  if #gens < wanted and #execs > 0 then
    local since = input.vacancy_since
    if since == nil or tick - since >= O.PROMOTION_DELAY then
      local b = best_executant(execs)
      ops.n = ops.n + #execs
      promote = b.id
      -- Le promu quitte les exécutants pour la suite de cette pensée.
      local rest = {}
      for _, e in ipairs(execs) do if e.id ~= promote then rest[#rest + 1] = e end end
      execs = rest
      gens[#gens + 1] = { id = b.id, pole = O.effective_pole(b), moved_tick = b.moved_tick }
      table.sort(gens, by_id)
    end
  end

  -- Besoins par pôle (travail ouvert + restant des tâches en cours ; les tâches de projet héritent du domaine).
  local proj_dom = O.project_domains(input.projects)
  local need
  if input.need then
    need = { input.need[1] or 0, input.need[2] or 0, input.need[3] or 0 }
  else
    need = O.demand_from_tasks(input.tasks or {}, ops, proj_dom).poles
  end

  -- Cibles d'exécutants.
  local zl = O.zone_list(input.zones or 0, ops)
  local targets, surplus, zinfo = O.pole_targets(#execs, need, pts, zl, ops)

  -- Compte par pôle EFFECTIF (destinations différées comprises) ; recrues sans pôle placées sans délai là où
  -- l'écart est le plus grand (égalité : ordre de départage).
  local cur = { 0, 0, 0 }
  local epole = {}
  local unplaced = {}
  for _, e in ipairs(execs) do
    local name = O.effective_pole(e)
    local p = name and O.POLE_INDEX[name]
    if p then
      cur[p] = cur[p] + 1
      epole[e.id] = name
    else
      unplaced[#unplaced + 1] = e
    end
    ops.n = ops.n + 1
  end
  local place = {}
  for _, e in ipairs(unplaced) do
    local bp, bd = order[1], nil
    for _, p in ipairs(order) do
      local d = targets[p] - cur[p]
      if bd == nil or d > bd then bp, bd = p, d end
      ops.n = ops.n + 1
    end
    cur[bp] = cur[bp] + 1
    epole[e.id] = O.POLES[bp]
    place[#place + 1] = { id = e.id, pole = O.POLES[bp] }
  end

  -- Hystérésis : au plus MAX_MOVES décisions par pensée. Receveur : le pôle le plus en manque ; donneurs : les
  -- pôles excédentaires, du plus excédentaire au moins excédentaire. Écart minimal de 2, SAUF pour un pôle sous
  -- son plancher (équipes de zone, extraction) : un plancher se remplit à l'unité. 1er passage : un PNJ INOCCUPÉ (effet
  -- immédiat) ; 2e passage : un PNJ OCCUPÉ, dont le changement est DIFFÉRÉ à la fin de sa tâche (aucun travail
  -- interrompu). Jamais un PNJ qui a déjà une destination, ni un PNJ changé il y a moins de 10 min.
  local moves, moved = {}, {}
  local function movable(e, pole_name, idle_only)
    if e.dest ~= nil or e.pole ~= pole_name or moved[e.id] then return false end
    if e.moved_tick ~= nil and tick - e.moved_tick < O.MOVE_COOLDOWN then return false end
    if idle_only and not e.idle then return false end
    return true
  end
  -- Préférence : inoccupé ; hors équipe de zone ; tâche qui finit le plus tôt ; rang le plus bas ; recrue la
  -- plus récente (id le plus grand). Les vétérans et les gardiens de zone restent à leur poste.
  local function better(a, b)
    local ai, bi = a.idle and true or false, b.idle and true or false
    if ai ~= bi then return ai end
    local az, bz = a.zone ~= nil, b.zone ~= nil
    if az ~= bz then return not az end
    local aw, bw = a.work_left or 0, b.work_left or 0
    if aw ~= bw then return aw < bw end
    local ar, br = a.rank or 1, b.rank or 1
    if ar ~= br then return ar < br end
    return a.id > b.id
  end
  local function candidate(pole_name, idle_only)
    local pick
    for _, e in ipairs(execs) do
      ops.n = ops.n + 1
      if movable(e, pole_name, idle_only) and (not pick or better(e, pick)) then pick = e end
    end
    return pick
  end
  local pos = {}
  for k, p in ipairs(order) do pos[p] = k end
  for _ = 1, O.MAX_MOVES do
    local d, recv, rd = {}, nil, 0
    for _, p in ipairs(order) do
      d[p] = targets[p] - cur[p]
      if d[p] > rd then recv, rd = p, d[p] end
      ops.n = ops.n + 1
    end
    if not recv then break end
    local donors = {}
    for _, q in ipairs(order) do
      if d[q] < 0 and (rd >= O.MOVE_GAP or -d[q] >= O.MOVE_GAP or cur[recv] < zinfo.floors[recv]) then
        donors[#donors + 1] = q
      end
    end
    table.sort(donors, function(a, b)
      if d[a] ~= d[b] then return d[a] < d[b] end
      return pos[a] < pos[b]
    end)
    local pick, from
    for pass = 1, 2 do
      for _, q in ipairs(donors) do
        pick = candidate(O.POLES[q], pass == 1)
        if pick then from = q break end
      end
      if pick then break end
    end
    if not pick then break end
    moved[pick.id] = true
    moves[#moves + 1] = { id = pick.id, from = O.POLES[from], to = O.POLES[recv], deferred = not pick.idle }
    cur[from] = cur[from] - 1
    cur[recv] = cur[recv] + 1
    epole[pick.id] = O.POLES[recv]
  end

  -- Équipes de zone : des exécutants NOMMÉS par zone (2 par défaut), dans l'ordre de priorité des zones, la
  -- somme bornée au plancher retenu (50 % des exécutants au plus). On garde d'abord les membres actuels
  -- (stabilité), puis on complète avec les exécutants du territoire sans zone (id croissant).
  local terr = {}
  for _, e in ipairs(execs) do
    if epole[e.id] == "territoire" then terr[#terr + 1] = e end
    ops.n = ops.n + 1
  end
  local budget = zinfo.zone_floor
  local crews, taken_by, zone_short = {}, {}, {}
  local give = {}
  for zi, z in ipairs(zl) do
    give[zi] = math.min(z.crew, budget)
    budget = budget - give[zi]
    crews[zi] = { zone = z.id, npcs = {}, wanted = z.crew }
  end
  for zi, z in ipairs(zl) do
    for _, e in ipairs(terr) do
      ops.n = ops.n + 1
      if #crews[zi].npcs >= give[zi] then break end
      if e.zone == z.id and not taken_by[e.id] then
        taken_by[e.id] = z.id
        crews[zi].npcs[#crews[zi].npcs + 1] = e.id
      end
    end
  end
  for zi in ipairs(zl) do
    for _, e in ipairs(terr) do
      ops.n = ops.n + 1
      if #crews[zi].npcs >= give[zi] then break end
      if not taken_by[e.id] then
        taken_by[e.id] = crews[zi].zone
        crews[zi].npcs[#crews[zi].npcs + 1] = e.id
      end
    end
    table.sort(crews[zi].npcs)
    if #crews[zi].npcs < crews[zi].wanted then zone_short[#zone_short + 1] = crews[zi].zone end
  end
  local zone_of = {}
  for _, e in ipairs(terr) do
    if taken_by[e.id] then zone_of[#zone_of + 1] = { id = e.id, zone = taken_by[e.id] } end
  end
  local warnings = {}
  if zinfo.capped then warnings[#warnings + 1] = "trop_de_zones" end

  -- Généralistes : pôles de référence (délai de garde compris) et meneurs.
  local quotas = O.generalist_quotas(#gens, pts, ops, order)
  local gen_poles, gen_moves = generalist_poles(gens, quotas, tick, order, ops)
  local leaders, waiting = assign_leaders(input.projects or {}, gen_poles, ops)

  return {
    pts = pts, need = need, targets = targets, surplus = surplus, place = place, moves = moves,
    assigned = cur, crews = crews, zone_of = zone_of, zone_short = zone_short, warnings = warnings,
    promote = promote, generalists_wanted = wanted, gen_poles = gen_poles, gen_moves = gen_moves,
    leaders = leaders, waiting = waiting,
    idle_rate = #all > 0 and idle_n / #all or 0, ops = ops.n,
  }
end

---------------------------------------------------------------------------------------------------
-- Prise de tâche (remplace le tri complet de Board.claim : un passage sur une liste triée une fois)
---------------------------------------------------------------------------------------------------
--- Trie un tableau de tâches une fois par pensée : priorité décroissante, puis clé. Note au passage le pôle
--- de chaque tâche (champ texte `pole`, sérialisable ; une tâche de projet prend le pôle de son projet,
--- `projects` facultatif) pour que chaque prise reste un simple passage.
function O.sort_tasks(tasks, projects)
  local proj_dom = projects and O.project_domains(projects) or nil
  for i = 1, #tasks do
    local t = tasks[i]
    t.pole = t.pole or O.task_pole(t, proj_dom)
  end
  table.sort(tasks, function(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    return a.key < b.key
  end)
  return tasks
end

--- Plafond des PNJ occupés à une urgence HORS de leur pôle : 20 % des exécutants, au moins 2.
function O.urgent_away_cap(n_exec)
  return math.max(2, (idiv(math.max(0, n_exec) * O.URGENT_AWAY_PCT, 100)))
end

--[[
  npc = { id, role, pole, dest, project, zone } ; tasks = liste triée (O.sort_tasks), tâches prises ignorées ;
  ctx = { manual_busy = { minage = n, portage = n }, manual_cap = { minage = n, portage = n },
          urgent_away = PNJ occupés à une urgence hors de leur pôle, urgent_away_cap = O.urgent_away_cap(n) }.
  Le pôle du PNJ est son pôle EFFECTIF (destination différée comprise) : un PNJ marqué « à déplacer » ne
  reprend plus de tâche ordinaire de son ancien pôle.
  Rangs (le plus petit gagne ; à rang égal, l'ordre de la liste, donc la priorité) :
    0  généraliste : une tâche de SON projet (task.project) ;
    1  membre d'une équipe de zone : une tâche de SA zone (task.zone), quelle que soit sa priorité ;
    2  une tâche URGENTE (prio >= 90) de son pôle ;
    3  une tâche URGENTE d'un autre pôle, tant que urgent_away < urgent_away_cap (l'urgence passe AVANT le
       travail ordinaire de son pôle) ;
    4  généraliste : une tâche de conception de son pôle ;
    5  une tâche (non conception pour un exécutant) de son pôle ;
    6  généraliste : n'importe quelle tâche ; exécutant : une urgence d'un autre pôle au-delà du plafond.
  Un exécutant ne prend jamais une tâche de conception. Le travail manuel au-delà de son plafond n'est pas
  pris, sauf urgence. Renvoie l'indice de la tâche (ou nil) et `away` (vrai si la tâche est hors du pôle du
  PNJ : l'appelant compte alors urgent_away) ; un seul passage, O(T).
]]
function O.pick_task(npc, tasks, ctx)
  ctx = ctx or {}
  local busy, cap = ctx.manual_busy or {}, ctx.manual_cap or {}
  local away_full = ctx.urgent_away_cap ~= nil and (ctx.urgent_away or 0) >= ctx.urgent_away_cap
  local gen = npc.role == "generalist"
  local my_pole = O.effective_pole(npc)
  local best_i, best_r, best_away = nil, 99, false
  for i = 1, #tasks do
    local t = tasks[i]
    if not t.worker then
      local design = O.DESIGN_KINDS[t.kind]
      local urgent = (t.prio or 0) >= O.URGENT_PRIO
      local manual = O.MANUAL_KINDS[t.kind]
      local blocked = (design and not gen) or (manual and not urgent and cap[manual] ~= nil and (busy[manual] or 0) >= cap[manual])
      if not blocked then
        local same = (t.pole or O.task_pole(t)) == my_pole
        local r
        if gen and npc.project ~= nil and t.project == npc.project then r = 0
        elseif npc.zone ~= nil and t.zone == npc.zone then r = 1
        elseif urgent and same then r = 2
        elseif urgent and not away_full then r = 3
        elseif gen and design and same then r = 4
        elseif same then r = 5
        elseif gen or urgent then r = 6 end
        if r and r < best_r then
          best_i, best_r, best_away = i, r, not same
          if r == 0 then break end
        end
      end
    end
  end
  return best_i, best_away
end

---------------------------------------------------------------------------------------------------
-- Règle d'automatisation (P1, greffée) et plafonds de travail manuel
---------------------------------------------------------------------------------------------------
--- Un flux de plus de 60 objets/min, nécessaire plus de 10 min, sur 64 tuiles ou moins, passe par un tapis
--- ou une conduite : le cerveau ouvre un projet « belt » ou « pipe » au lieu de payer des porteurs.
function O.needs_automation(flow_per_min, minutes, distance)
  return flow_per_min > 60 and minutes > 10 and distance <= 64
end

--- Plafond de PNJ en travail manuel (par catégorie : minage, portage) : la moitié des exécutants à l'époque 1
--- (départ à la main, comme un joueur), 20 % ensuite ; au moins 1.
function O.manual_cap(n_exec, epoch)
  local pct = (epoch or 1) <= 1 and 50 or 20
  return math.max(1, (idiv(math.max(0, n_exec) * pct, 100)))
end

---------------------------------------------------------------------------------------------------
-- Progression des PNJ (modificateurs PAR PERSONNAGE ; jamais ceux de la force, qui toucheraient le joueur)
---------------------------------------------------------------------------------------------------
-- XP = minutes de travail utile ; une tâche de conception compte double ; une victime rapporte 2.
O.XP_THRESHOLDS = { 0, 30, 120, 360, 900 } -- rang 2 : 30 min ; 3 : 2 h ; 4 : 6 h ; 5 : 15 h de travail
O.XP_DESIGN_MULT = 2
O.XP_KILL = 2
O.RANK_MAX = #O.XP_THRESHOLDS

-- Profil « léger » (défaut ❔). craft et mine : bonus ajouté au modificateur (×(1 + bonus)) ; run : +x de
-- vitesse de course ; inv : cases en plus.
O.RANK_BONUS = {
  { craft = 0,    run = 0,    mine = 0,    inv = 0 },
  { craft = 0.25, run = 0.04, mine = 0.25, inv = 10 },
  { craft = 0.5,  run = 0.08, mine = 0.5,  inv = 20 },
  { craft = 1.0,  run = 0.12, mine = 1.0,  inv = 30 },
  { craft = 2.0,  run = 0.15, mine = 1.5,  inv = 40 },
}
O.PROFILES = { egal = 0, leger = 1, fort = 1.5 }
O.RUN_CAP = 0.15     -- « se déplacer légèrement plus vite » : jamais plus de +15 %, quel que soit le profil
-- Distance de construction CONTRÔLÉE PAR LE SCRIPT (programme d'étapes) : LuaEntity.revive ne vérifie aucune
-- portée, donc character_build_distance_bonus n'aurait aucun effet sur une pose scriptée ; on ne l'écrit pas.
-- 16 tuiles (le joueur : 10) pour couvrir un lot de 24 depuis deux rues : écart DÉCLARÉ (docs §6.6 et §10).
O.SCRIPT_BUILD_DISTANCE = 16
-- Difficulté des factions IA (clés de F.pvp_order) : multiplie les bonus. L'équipe du joueur : 1.
O.DIFFICULTY = { peaceful = 0.8, easy = 0.8, normal = 1, hard = 1.1, merciless = 1.25 }

function O.rank(xp)
  local r = 1
  for i = 2, O.RANK_MAX do
    if (xp or 0) >= O.XP_THRESHOLDS[i] then r = i end
  end
  return r
end

--- XP gagnée pour `work_ticks` de travail utile (entier, minutes arrondies vers le bas, reste conservé par
--- l'appelant dans `carry`). Renvoie xp, carry.
function O.gain(xp, carry, work_ticks, design)
  local t = (carry or 0) + work_ticks * (design and O.XP_DESIGN_MULT or 1)
  local minutes = idiv(t, 3600)
  return (xp or 0) + minutes, t - minutes * 3600
end

--- Modificateurs à écrire sur le personnage (LuaControl, lecture et écriture vérifiées dans runtime-api.json
--- 1.1.91). profile : "egal" | "leger" | "fort" ; difficulty : clé F.pvp_order ou nil (équipe du joueur).
--- Au rang 1, tous valent 0 : le PNJ est exactement le joueur (fabrication, minage, course, inventaire).
function O.modifiers(rank, profile, difficulty)
  local b = O.RANK_BONUS[math.max(1, math.min(O.RANK_MAX, rank or 1))]
  local s = (O.PROFILES[profile or "leger"] or 1) * (difficulty and O.DIFFICULTY[difficulty] or 1)
  return {
    character_crafting_speed_modifier = b.craft * s,
    character_mining_speed_modifier = b.mine * s,
    character_running_speed_modifier = math.min(O.RUN_CAP, b.run * s),
    character_inventory_slots_bonus = math.floor(b.inv * s + 0.5),
  }
end
O.MODIFIER_ORDER = {
  "character_crafting_speed_modifier", "character_mining_speed_modifier", "character_running_speed_modifier",
  "character_inventory_slots_bonus",
}

---------------------------------------------------------------------------------------------------
-- Résurrection et recrutement
---------------------------------------------------------------------------------------------------
O.RES_BASE_S = 10          -- respawn_time vanilla du personnage (défaut 10 s, prototype-api.json 1.1.91)
O.RES_PER_RANK_S = 10      -- + 10 s par rang au-delà du premier : 10 s au rang 1, 50 s au rang 5
O.RES_PLATES_PER_RANK = 25 -- plaques de fer par rang
O.RES_MATERIAL_PER_RANK = 2 -- matériau de l'époque par rang, à partir de l'époque 2
O.RECRUIT_BASE = 10        -- recrue : kit + (10 + effectif) plaques de fer

local function merge_sorted(list)
  local idx, out = {}, {}
  for _, it in ipairs(list) do
    if it[2] > 0 then
      local i = idx[it[1]]
      if i then out[i][2] = out[i][2] + it[2] else out[#out + 1] = { it[1], it[2] }; idx[it[1]] = #out end
    end
  end
  table.sort(out, function(a, b) return a[1] < b[1] end)
  return out
end

--- Coût et délai de résurrection d'un PNJ de rang `rank` à l'époque `epoch`. material : objet monnaie de
--- l'époque (shared/levels/config.lua, table d'indirection) ; mult : réglage fo-resurrection-cost (1),
--- appliqué au surcoût (plaques et matériau), jamais au kit. Renvoie { cost = liste triée, ticks }.
--- Le PNJ garde son nom, son rang, son expérience et son rôle.
function O.resurrection(rank, epoch, material, mult)
  rank = math.max(1, math.min(O.RANK_MAX, rank or 1))
  mult = mult or 1
  local list = {}
  for _, it in ipairs(T.kits.worker) do list[#list + 1] = { it[1], it[2] } end
  list[#list + 1] = { "iron-plate", math.ceil(O.RES_PLATES_PER_RANK * rank * mult) }
  if (epoch or 1) >= 2 and material then
    list[#list + 1] = { material, math.ceil(O.RES_MATERIAL_PER_RANK * rank * mult) }
  end
  return { cost = merge_sorted(list), ticks = (O.RES_BASE_S + O.RES_PER_RANK_S * (rank - 1)) * 60 }
end

--- Résurrections simultanées au centre de commandement : 1, plus 1 tous les 5 niveaux du centre.
function O.resurrection_slots(cc_level)
  return 1 + idiv(math.max(0, cc_level or 0), 5)
end

--- Coût d'une recrue (rang 1) : kit + (10 + effectif actuel) plaques de fer.
function O.recruit_cost(headcount)
  local list = {}
  for _, it in ipairs(T.kits.worker) do list[#list + 1] = { it[1], it[2] } end
  list[#list + 1] = { "iron-plate", O.RECRUIT_BASE + (headcount or 0) }
  return merge_sorted(list)
end

--- Valeur d'une liste de coût en MU : values[objet] (MU), 1 par défaut (la plaque de fer vaut 1 MU, X0).
function O.cost_value(list, values)
  local v = 0
  for _, it in ipairs(list) do v = v + it[2] * ((values and values[it[1]]) or 1) end
  return v
end

--- Politique des IA (et bouton « automatique » de votre équipe). Rang 2 ou plus : ressusciter si c'est
--- payable (l'expérience vaut au moins 30 min de travail). Rang 1 : l'option payable la MOINS CHÈRE (valeurs
--- en MU, O.cost_value) ; à égalité ou faute de valeurs, la résurrection (elle garde le nom et l'expérience
--- acquise). Sinon l'autre option payable ; sinon attendre.
function O.revive_policy(rank, can_resurrect, can_recruit, res_value, rec_value)
  if can_resurrect and can_recruit then
    if (rank or 1) >= 2 then return "resurrect" end
    if rec_value ~= nil and res_value ~= nil and rec_value < res_value then return "recruit" end
    return "resurrect"
  end
  if can_resurrect then return "resurrect" end
  if can_recruit then return "recruit" end
  return "wait"
end

---------------------------------------------------------------------------------------------------
-- Amélioration INSTANTANÉE (précision du 21/10, 21 h 45) : une tâche ordinaire du domaine
-- « infrastructures », sans file ni durée ni nombre de chantiers. Un PNJ améliore en un trajet autant de
-- bâtiments que son inventaire en porte.
---------------------------------------------------------------------------------------------------
--- costs = { { {objet, n}, ... }, ... } coûts successifs (un par bâtiment, dans l'ordre du module) ;
--- stack = { [objet] = taille de pile } ; slots = cases libres du PNJ. Renvoie le nombre de bâtiments servis
--- en un trajet (préfixe de la liste) et les objets à prendre (liste triée).
function O.trip_capacity(costs, stack, slots)
  local carry, names = {}, {}
  local served = 0
  for _, c in ipairs(costs) do
    local trial = {}
    for k, v in pairs(carry) do trial[k] = v end -- copie (ordre sans effet : somme)
    for _, it in ipairs(c) do trial[it[1]] = (trial[it[1]] or 0) + it[2] end
    -- cases nécessaires, sommées sur la liste triée des objets
    local ks = {}
    for k in pairs(trial) do ks[#ks + 1] = k end
    table.sort(ks)
    local need = 0
    for _, k in ipairs(ks) do
      local s = stack[k] or 50
      need = need + idiv(trial[k] + s - 1, s)
    end
    if need > slots then break end
    carry = trial
    served = served + 1
  end
  for k in pairs(carry) do names[#names + 1] = k end
  table.sort(names)
  local take = {}
  for _, k in ipairs(names) do take[#take + 1] = { k, carry[k] } end
  return served, take
end

return O
