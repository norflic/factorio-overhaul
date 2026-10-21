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
                 (O.TASK_DOMAIN), chaque domaine à un pôle.
    GÉNÉRALISTES environ 1 PNJ sur 6 (5 sur 30, réglable) : de vrais ouvriers, rattachés à un pôle de
                 référence, qui MÈNENT un projet de bout en bout à travers les domaines (« je vais aller
                 chercher du pétrole, je vais mettre des tuyaux ») ; eux seuls prennent les tâches de conception.
    EXÉCUTANTS   les autres : répartis entre les 3 pôles selon les besoins (travail ouvert) et
                 l'orientation (curseurs du joueur, ou personnalité de la faction), avec hystérésis.

  Règles du projet respectées (ARCHITECTURE §2) : aucune API, aucune itération décidée par l'ordre de
  `pairs` (listes et ordres fixes), aucun temps mesuré, aucune trigonométrie, aucun flottant dans un test
  d'égalité de quantités (arithmétique entière pour les coûts et les plafonds), données sérialisables
  (aucune fonction renvoyée dans un résultat destiné à global).

  API principale :
    O.plan(input)                -> décisions d'une pensée (cibles par pôle, mouvements, promotion,
                                    pôles des généralistes, meneurs des projets), avec `ops` (travail compté)
    O.pick_task(npc, tasks, ctx) -> la tâche qu'un PNJ inoccupé prend (un seul passage, O(T))
    O.modifiers(rank, profile, difficulty) -> modificateurs par personnage (LuaControl.character_*)
    O.resurrection(rank, epoch, material, mult), O.recruit_cost(headcount), O.revive_policy(...)
    O.headcount_cap(epoch, max), O.generalists_wanted(n, chiefs), O.normalize(orientation)
]]

local T = require("shared.team.config")

local O = {}

---------------------------------------------------------------------------------------------------
-- Pôles et domaines (ordre FIXE : il sert aussi à départager les égalités)
---------------------------------------------------------------------------------------------------
O.POLES = { "extraction", "base", "territoire" }
O.POLE_INDEX = { extraction = 1, base = 2, territoire = 3 }

O.DOMAINS = {
  { key = "gisements",       pole = "extraction" }, -- « s'occuperait des ressources » ; minerai fondu en plaques
  { key = "logistique",      pole = "extraction" }, -- porteurs, tournées, tapis, poteaux, conduites
  { key = "production",      pole = "base" },       -- « tout ce qui va être automatisé, la construction de tel ou tel objet »
  { key = "infrastructures", pole = "base" },       -- « d'améliorer par exemple les infrastructures existantes », énergie
  { key = "defense",         pole = "territoire" }, -- zones, tourelles, ravitaillement, reconstruction
}
O.DOMAIN_POLE = {}
for _, d in ipairs(O.DOMAINS) do O.DOMAIN_POLE[d.key] = d.pole end

-- Domaine de chaque type de tâche. Les 9 premiers existent déjà (shared/team/planner.lua) : le modèle
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
-- Travail MANUEL plafonné (règle d'automatisation, §5 de docs/EQUIPES_PNJ.md) : au-delà du plafond, la tâche
-- reste au tableau, le manque se voit et le cerveau lance un projet d'automatisation (tapis, conduite).
O.MANUAL_KINDS = { mine = "minage", carry = "portage", service = "portage" }
O.URGENT_PRIO = 90 -- une tâche de priorité >= 90 (ravitaillement urgent) se prend hors pôle et hors plafond

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
O.HORIZON_S = 300            -- besoin d'un pôle = secondes de travail ouvert / 300 s (5 min) = PNJ équivalents
O.CAP_NUM, O.CAP_DEN = 5, 4  -- un pôle reçoit au plus ceil(besoin × 5/4) exécutants avant le « fond »
O.FLOOR_EXTRACTION = 2       -- plancher : 2 exécutants à l'extraction
O.FLOOR_PER_ZONE = 2         -- plancher : 2 exécutants par zone active (« j'ai par exemple […] 2 PNJ »)
O.THREAT_POINTS = 20         -- menace : +20 points d'orientation au territoire, le temps de la menace
O.MAX_MOVES = 2              -- hystérésis : au plus 2 changements de pôle par pensée…
O.MOVE_GAP = 2               -- … seulement si l'écart à la cible atteint 2 d'un côté au moins…
O.MOVE_COOLDOWN = 10 * 3600  -- … et jamais le même PNJ deux fois en 10 min (<= 6 changements par heure)
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
O.START = 8                              -- effectif de départ (2 aujourd'hui) : 2 généralistes + 6 exécutants à 30
O.CAP_FRACTION = { { 1, 2 }, { 5, 6 } }  -- plafond à l'époque 1 : 1/2 du maximum ; époque 2 : 5/6 ; ensuite : tout

--- Plafond d'effectif d'une équipe à l'époque `epoch` pour un maximum réglé `max` (entier, arrondi au-dessus).
--- 30 -> 15, 25, 30 ; 10 -> 5, 9, 10 ; 50 -> 25, 42, 50.
function O.headcount_cap(epoch, max)
  local fr = O.CAP_FRACTION[epoch or 1]
  if not fr then return max end
  return math.floor((max * fr[1] + fr[2] - 1) / fr[2])
end

--- Effectif de départ, borné par le plafond de l'époque 1.
function O.start_headcount(max)
  return math.min(O.START, O.headcount_cap(1, max))
end

--- Généralistes voulus pour n PNJ vivants : un pour 6 (arrondi au-dessus), au plus `chiefs` (réglage, 5).
function O.generalists_wanted(n, chiefs)
  if n <= 0 then return 0 end
  local g = math.floor((n + O.GENERALIST_PER - 1) / O.GENERALIST_PER)
  return math.min(chiefs or 5, g, n)
end

---------------------------------------------------------------------------------------------------
-- Orientation
---------------------------------------------------------------------------------------------------
--- Orientation normalisée en LISTE de 3 points entiers {extraction, base, territoire} de somme 100.
--- Accepte un nom de préréglage, une table { extraction =, base =, territoire = } ou une liste de 3 nombres.
--- Valeurs négatives ramenées à 0 ; tout à 0 -> équilibre. menace = true : +20 points au territoire.
function O.normalize(o, threatened)
  if type(o) == "string" then o = O.PRESETS[o] or O.PRESETS.equilibre end
  o = o or O.PRESETS.equilibre
  local raw = {}
  for i, p in ipairs(O.POLES) do
    local v = o[p] or o[i] or 0
    raw[i] = v > 0 and v or 0
  end
  if threatened then raw[3] = raw[3] + O.THREAT_POINTS * (raw[1] + raw[2] + raw[3]) / 100 end
  local sum = raw[1] + raw[2] + raw[3]
  if sum <= 0 then
    local e = O.PRESETS.equilibre
    raw, sum = { e.extraction, e.base, e.territoire }, 100
  end
  -- Points entiers par le plus fort reste (somme exactement 100).
  local pts = O.apportion(100, raw)
  return pts
end

---------------------------------------------------------------------------------------------------
-- Outils déterministes
---------------------------------------------------------------------------------------------------
--- Coût compté d'un tri de n éléments : n × ceil(log2 n). On ne compte pas les appels du comparateur, qui
--- dépendent de l'ordre d'entrée : le travail compté ne dépend ainsi que des tailles (test reproductible).
local function sort_cost(n)
  local c, k = 0, 1
  while k < n do k = k * 2; c = c + 1 end
  return n * c
end
O.sort_cost = sort_cost

--- Répartit `total` unités entières selon `weights` (liste) : méthode du plus fort reste ; égalité de
--- reste départagée par l'indice. Poids tous nuls -> zéros. `ops` (table { n = }) compte le travail.
function O.apportion(total, weights, ops)
  local n = #weights
  local out, sum = {}, 0
  for i = 1, n do sum = sum + weights[i]; out[i] = 0 end
  if total <= 0 or sum <= 0 then return out end
  local given, rest = 0, {}
  for i = 1, n do
    local q = total * weights[i] / sum
    local f = math.floor(q)
    out[i] = f
    given = given + f
    rest[i] = { i = i, r = q - f }
    if ops then ops.n = ops.n + 1 end
  end
  if ops then ops.n = ops.n + sort_cost(n) end
  table.sort(rest, function(a, b)
    if a.r ~= b.r then return a.r > b.r end
    return a.i < b.i
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

--- Pôle d'une tâche (domaine explicite, sinon d'après son type ; inconnu -> base).
function O.task_domain(task)
  return task.domain or O.TASK_DOMAIN[task.kind] or "production"
end
function O.task_pole(task)
  return O.DOMAIN_POLE[O.task_domain(task)] or "base"
end

--- Travail ouvert par domaine et par pôle (secondes) d'une liste de tâches : la « demande » des managers.
--- Renvoie { domains = { [domaine] = s }, poles = { s_extraction, s_base, s_territoire } } ; O(T).
function O.demand_from_tasks(tasks, ops)
  local dom, poles = {}, { 0, 0, 0 }
  for _, d in ipairs(O.DOMAINS) do dom[d.key] = 0 end
  for i = 1, #tasks do
    local t = tasks[i]
    if not t.worker then
      local d = O.task_domain(t)
      local w = t.work or O.TASK_WORK[t.kind] or O.DEFAULT_WORK
      dom[d] = (dom[d] or 0) + w
      local p = O.POLE_INDEX[O.DOMAIN_POLE[d] or "base"]
      poles[p] = poles[p] + w
    end
    if ops then ops.n = ops.n + 1 end
  end
  return { domains = dom, poles = poles }
end

---------------------------------------------------------------------------------------------------
-- Cibles par pôle (exécutants)
---------------------------------------------------------------------------------------------------
--- n exécutants ; need = { s, s, s } secondes de travail ouvert par pôle ; pts = orientation (3 entiers,
--- somme 100) ; zones = zones actives. Renvoie cibles { e, b, t } (somme n) et surplus (exécutants sans
--- travail identifié, envoyés au « fond » du pôle le mieux orienté : agrandir, prospecter, renforcer).
---
--- 1. Partage pondéré « orientation × besoin », chaque pôle plafonné à ceil(besoin × 5/4) PNJ (on ne met
---    pas 10 PNJ sur 2 tâches) ; 3 tours de remplissage au plus.
--- 2. Ce qui reste va au fond, selon l'orientation seule.
--- 3. Planchers (extraction 2, territoire 2 par zone active) pris aux pôles les mieux pourvus.
function O.pole_targets(n, need, pts, zones, ops)
  ops = ops or { n = 0 }
  local t = { 0, 0, 0 }
  if n <= 0 then return t, 0 end
  local cap = {}
  for p = 1, 3 do
    -- besoin en PNJ = s / horizon ; plafond = ceil(besoin × 5/4) en arithmétique entière
    local s = math.floor(need[p] or 0)
    cap[p] = math.floor((s * O.CAP_NUM + O.HORIZON_S * O.CAP_DEN - 1) / (O.HORIZON_S * O.CAP_DEN))
  end
  local left = n
  for _ = 1, 3 do
    if left <= 0 then break end
    local w = {}
    for p = 1, 3 do w[p] = cap[p] > 0 and pts[p] * (need[p] or 0) or 0 end
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
  floor[3] = math.min(O.FLOOR_PER_ZONE * (zones or 0), n - floor[1])
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
  return t, surplus
end

---------------------------------------------------------------------------------------------------
-- Généralistes : pôles de référence (stables) et meneurs de projets
---------------------------------------------------------------------------------------------------
--- Quotas de généralistes par pôle : d'abord un pour chaque pôle orienté à 15 % ou plus (du plus orienté au
--- moins orienté, égalité par l'ordre des pôles), tant qu'il en reste ; le reste selon l'orientation.
function O.generalist_quotas(g, pts, ops)
  local q = { 0, 0, 0 }
  if g <= 0 then return q end
  local order = { 1, 2, 3 }
  table.sort(order, function(a, b)
    if pts[a] ~= pts[b] then return pts[a] > pts[b] end
    return a < b
  end)
  local used = 0
  for _, p in ipairs(order) do
    if used < g and pts[p] >= O.GENERALIST_MIN_SHARE then
      q[p] = 1
      used = used + 1
    end
  end
  if used < g then
    local share = O.apportion(g - used, pts, ops)
    for p = 1, 3 do q[p] = q[p] + share[p] end
  end
  return q
end

--- Pôle de référence de chaque généraliste, en changeant le moins possible : ceux dont le pôle a encore
--- un quota le gardent (par id croissant), les autres vont aux pôles qui manquent (ordre des pôles).
--- gens : liste triée par id de { id, pole } ; renvoie une liste { { id, pole }, ... } (même ordre).
local function generalist_poles(gens, quotas, ops)
  local left = { quotas[1], quotas[2], quotas[3] }
  local out, pending = {}, {}
  for i, g in ipairs(gens) do
    local p = g.pole and O.POLE_INDEX[g.pole]
    if p and left[p] > 0 then
      left[p] = left[p] - 1
      out[i] = { id = g.id, pole = g.pole }
    else
      pending[#pending + 1] = i
    end
    ops.n = ops.n + 1
  end
  local p = 1
  for _, i in ipairs(pending) do
    while p <= 3 and left[p] <= 0 do p = p + 1 end
    -- Plus de généralistes que de quotas (équipe qui rétrécit) : on garde l'ancien pôle, sinon la base.
    local pole = p <= 3 and O.POLES[p] or (gens[i].pole or "base")
    if p <= 3 then left[p] = left[p] - 1 end
    out[i] = { id = gens[i].id, pole = pole }
    ops.n = ops.n + 1
  end
  return out
end

--- Meneurs de projets. projects = { { id, domain, prio, leader, started }, ... } ; gens = { { id, pole }, ... }.
--- Un généraliste mène au plus un projet. Un projet garde son meneur s'il est toujours généraliste et vivant
--- (stabilité). Les projets sans meneur sont servis par priorité effective décroissante (égalité : id) : un
--- projet COMMENCÉ (fantômes posés, matériaux engagés) gagne O.ENGAGED_BONUS points, pour qu'un chantier
--- orphelin soit repris avant d'en ouvrir un nouveau. Chacun est servi par le généraliste libre du même pôle
--- d'abord, sinon le premier libre (id croissant). Renvoie leaders = { { project, npc }, ... } (ordre des
--- projets servis) et waiting = { id de projet, ... }.
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
-- Pensée d'organisation
---------------------------------------------------------------------------------------------------
--[[
  input = {
    tick,
    npcs = { { id, role = "generalist"|"executant", pole, rank, xp, idle, moved_tick }, ... }  -- vivants
    tasks = { tâche, ... }        -- tableau de l'équipe (tâches libres comptées) ; ou `need` = { s, s, s }
    orientation,                  -- préréglage, table ou liste (voir O.normalize)
    threatened, zones,            -- menace en cours ; zones actives
    projects = { { id, domain, prio, leader }, ... },
    chiefs,                       -- réglage fo-team-chiefs (5)
    vacancy_since,                -- tick de la mort d'un généraliste non remplacé (nil : croissance)
  }
  Renvoie {
    pts      = orientation en points (3 entiers),
    need     = travail ouvert par pôle (s),
    targets  = cibles d'exécutants par pôle { e, b, t }, surplus,
    place    = { { id, pole }, ... }  exécutants sans pôle placés (nouvelles recrues), sans délai,
    moves    = { { id, from, to }, ... } changements de pôle (au plus O.MAX_MOVES),
    promote  = id d'un exécutant à promouvoir, ou nil ; generalists_wanted,
    gen_poles = { { id, pole }, ... }, leaders, waiting,
    idle_rate = inactifs / vivants (affichage et critère C5-2),
    ops      = unités de travail comptées (coût borné, critère du test)
  }
  L'appelant applique les décisions ; ce module ne modifie pas `input`.
]]
function O.plan(input)
  local ops = { n = 0 }
  local tick = input.tick or 0
  local pts = O.normalize(input.orientation, input.threatened)

  -- Population, triée par id (l'ordre d'entrée ne compte pas).
  local all = copy_list(input.npcs or {})
  ops.n = ops.n + sort_cost(#all)
  table.sort(all, by_id)
  local gens, execs = {}, {}
  local idle_n = 0
  for _, a in ipairs(all) do
    if a.role == "generalist" then gens[#gens + 1] = a else execs[#execs + 1] = a end
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
      gens[#gens + 1] = { id = b.id, pole = b.pole, rank = b.rank, xp = b.xp }
      table.sort(gens, by_id)
    end
  end

  -- Besoins par pôle.
  local need
  if input.need then
    need = { input.need[1] or 0, input.need[2] or 0, input.need[3] or 0 }
  else
    need = O.demand_from_tasks(input.tasks or {}, ops).poles
  end

  -- Cibles d'exécutants.
  local targets, surplus = O.pole_targets(#execs, need, pts, input.zones or 0, ops)

  -- Compte actuel ; les recrues sans pôle vont là où l'écart est le plus grand (sans délai).
  local cur = { 0, 0, 0 }
  local unplaced = {}
  for _, e in ipairs(execs) do
    local p = e.pole and O.POLE_INDEX[e.pole]
    if p then cur[p] = cur[p] + 1 else unplaced[#unplaced + 1] = e end
    ops.n = ops.n + 1
  end
  local place = {}
  for _, e in ipairs(unplaced) do
    local bp, bd = 1, nil
    for p = 1, 3 do
      local d = targets[p] - cur[p]
      if bd == nil or d > bd then bp, bd = p, d end
      ops.n = ops.n + 1
    end
    cur[bp] = cur[bp] + 1
    place[#place + 1] = { id = e.id, pole = O.POLES[bp] }
  end

  -- Hystérésis : au plus MAX_MOVES mouvements, PNJ inoccupés et hors délai de garde seulement. Le receveur est
  -- le pôle le plus en manque ; le donneur, le plus excédentaire qui a un candidat (sinon le suivant).
  local moves = {}
  local moved = {}
  local function candidate(pole_name)
    -- Inoccupé, hors délai de garde ; rang le plus bas, puis recrue la plus récente (id le plus grand).
    local pick
    for _, e in ipairs(execs) do
      ops.n = ops.n + 1
      if e.pole == pole_name and e.idle and not moved[e.id]
        and (e.moved_tick == nil or tick - e.moved_tick >= O.MOVE_COOLDOWN) then
        if not pick or e.rank < pick.rank or (e.rank == pick.rank and e.id > pick.id) then pick = e end
      end
    end
    return pick
  end
  for _ = 1, O.MAX_MOVES do
    local d, recv, rd = {}, nil, 0
    for p = 1, 3 do
      d[p] = targets[p] - cur[p]
      if d[p] > rd then recv, rd = p, d[p] end
      ops.n = ops.n + 1
    end
    if not recv then break end
    local order = { 1, 2, 3 }
    table.sort(order, function(a, b)
      if d[a] ~= d[b] then return d[a] < d[b] end
      return a < b
    end)
    local done = false
    for _, q in ipairs(order) do
      if d[q] < 0 and (rd >= O.MOVE_GAP or -d[q] >= O.MOVE_GAP) then
        local pick = candidate(O.POLES[q])
        if pick then
          moved[pick.id] = true
          moves[#moves + 1] = { id = pick.id, from = O.POLES[q], to = O.POLES[recv] }
          cur[q] = cur[q] - 1
          cur[recv] = cur[recv] + 1
          done = true
          break
        end
      end
    end
    if not done then break end
  end

  -- Généralistes : pôles de référence et meneurs de projets.
  local quotas = O.generalist_quotas(#gens, pts, ops)
  local gen_poles = generalist_poles(gens, quotas, ops)
  local leaders, waiting = assign_leaders(input.projects or {}, gen_poles, ops)

  return {
    pts = pts, need = need, targets = targets, surplus = surplus, place = place, moves = moves,
    promote = promote, generalists_wanted = wanted, gen_poles = gen_poles, leaders = leaders, waiting = waiting,
    idle_rate = #all > 0 and idle_n / #all or 0, ops = ops.n,
  }
end

---------------------------------------------------------------------------------------------------
-- Prise de tâche (remplace le tri complet de Board.claim : un passage sur une liste triée une fois)
---------------------------------------------------------------------------------------------------
--- Trie un tableau de tâches une fois par pensée : priorité décroissante, puis clé. Note au passage le pôle
--- de chaque tâche (champ texte `pole`, sérialisable) pour que chaque prise reste un simple passage.
function O.sort_tasks(tasks)
  for i = 1, #tasks do
    local t = tasks[i]
    t.pole = t.pole or O.task_pole(t)
  end
  table.sort(tasks, function(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    return a.key < b.key
  end)
  return tasks
end

--[[
  npc = { id, role, pole, project } ; tasks = liste triée (O.sort_tasks), tâches prises ignorées ;
  ctx = { manual_busy = { minage = n, portage = n }, manual_cap = { minage = n, portage = n } }.
  Rangs (le plus petit gagne ; à rang égal, l'ordre de la liste) :
    0  généraliste : une tâche de SON projet (task.project) ;
    1  généraliste : une tâche de conception de son pôle ;
    2  une tâche (non conception pour un exécutant) de son pôle ;
    3  généraliste : n'importe quelle tâche ; exécutant : une tâche URGENTE (prio >= 90) d'un autre pôle.
  Un exécutant ne prend jamais une tâche de conception. Le travail manuel au-delà de son plafond n'est pas
  pris, sauf urgence. Renvoie l'indice de la tâche ou nil ; un seul passage, O(T).
]]
function O.pick_task(npc, tasks, ctx)
  ctx = ctx or {}
  local busy, cap = ctx.manual_busy or {}, ctx.manual_cap or {}
  local gen = npc.role == "generalist"
  local best_i, best_r = nil, 99
  for i = 1, #tasks do
    local t = tasks[i]
    if not t.worker then
      local design = O.DESIGN_KINDS[t.kind]
      local urgent = (t.prio or 0) >= O.URGENT_PRIO
      local manual = O.MANUAL_KINDS[t.kind]
      local blocked = (design and not gen) or (manual and not urgent and cap[manual] ~= nil and (busy[manual] or 0) >= cap[manual])
      if not blocked then
        local same = (t.pole or O.task_pole(t)) == npc.pole
        local r
        if gen and npc.project ~= nil and t.project == npc.project then r = 0
        elseif gen and design and same then r = 1
        elseif same then r = 2
        elseif gen or urgent then r = 3 end
        if r and r < best_r then
          best_i, best_r = i, r
          if r == 0 then break end
        end
      end
    end
  end
  return best_i
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
  return math.max(1, math.floor(n_exec * pct / 100))
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
O.BUILD_BONUS = 6    -- portée de construction 10 -> 16 : un lot de 24 tuiles se bâtit depuis deux rues
O.REACH_BONUS = 6
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
  local minutes = math.floor(t / 3600)
  return (xp or 0) + minutes, t - minutes * 3600
end

--- Modificateurs à écrire sur le personnage (LuaControl, lecture et écriture vérifiées dans runtime-api.json
--- 1.1.91). profile : "egal" | "leger" | "fort" ; difficulty : clé F.pvp_order ou nil (équipe du joueur).
function O.modifiers(rank, profile, difficulty)
  local b = O.RANK_BONUS[math.max(1, math.min(O.RANK_MAX, rank or 1))]
  local s = (O.PROFILES[profile or "leger"] or 1) * (difficulty and O.DIFFICULTY[difficulty] or 1)
  return {
    character_crafting_speed_modifier = b.craft * s,
    character_mining_speed_modifier = b.mine * s,
    character_running_speed_modifier = math.min(O.RUN_CAP, b.run * s),
    character_inventory_slots_bonus = math.floor(b.inv * s + 0.5),
    character_build_distance_bonus = O.BUILD_BONUS,
    character_reach_distance_bonus = O.REACH_BONUS,
  }
end
O.MODIFIER_ORDER = {
  "character_crafting_speed_modifier", "character_mining_speed_modifier", "character_running_speed_modifier",
  "character_inventory_slots_bonus", "character_build_distance_bonus", "character_reach_distance_bonus",
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
  return 1 + math.floor((cc_level or 0) / 5)
end

--- Coût d'une recrue (rang 1) : kit + (10 + effectif actuel) plaques de fer.
function O.recruit_cost(headcount)
  local list = {}
  for _, it in ipairs(T.kits.worker) do list[#list + 1] = { it[1], it[2] } end
  list[#list + 1] = { "iron-plate", O.RECRUIT_BASE + (headcount or 0) }
  return merge_sorted(list)
end

--- Politique des IA (et bouton « automatique » de votre équipe) : ressusciter un PNJ de rang 2 ou plus si
--- le stock le permet, sinon recruter, sinon attendre.
function O.revive_policy(rank, can_resurrect, can_recruit)
  if (rank or 1) >= 2 and can_resurrect then return "resurrect" end
  if can_recruit then return "recruit" end
  if can_resurrect then return "resurrect" end
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
      need = need + math.floor((trial[k] + s - 1) / s)
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
