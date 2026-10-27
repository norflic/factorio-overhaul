--[[
  IA3-d « ils ne scalent pas » (docs/IA_ATTENDUS.md ligne A7, docs/IA3_CERVEAU.md §3.6) : la règle d'EFFECTIF d'une
  faction. PUR (aucune API Factorio) : le runtime (script/team/team.lua, Team.view) lui donne la situation de l'équipe à
  la pensée ; elle rend la décision (recruter ou non) et SA RAISON (lisibilité : fenêtre « Équipe et factions », ligne
  minute « [FO-EFFECTIF] » du journal).

  Un joueur grandit quand le travail attend : « plus de bras quand le travail attend ». Une recrue de CROISSANCE quand
    1. du travail UTILE attend depuis au moins E.WAIT_TICKS (2 min) : tâches LIBRES du cerveau (pas le fond), que la
       recrue saurait prendre (ni conception, ni garde, ni l'équipement d'une recrue), dont la matière stricte est LIBRE
       au registre (sinon c'est la matière qui manque, pas les bras), de valeur au moins E.VALUE_MIN ;
    2. ce travail dépasse les bras libres : PNJ sans tâche + PNJ au travail de fond (le fond s'interrompt à la fin de sa
       tâche ; IA1-b les comptait déjà disponibles), moins la tolérance du réglage fo-recruit-idle-max ;
    3. la recrue se paie : coût en plaques (kit + (10 + effectif) fer, O.recruit_cost, déjà réduit par ce que le coffre a
       de prêt) couvert par le stock LIBRE moins ce que le travail en attente et l'objectif courant réservent, plus une
       marge (caractère : un prudent garde plus) ;
    4. le rythme : au plus une recrue de croissance par période (caractère : une faction ambitieuse grandit plus vite) ;
    5. ni plafond (réglage), ni garde de performance (fo-agents-max), ni menace sur le QG.
  Elle ne recrute PAS quand ses PNJ sont inactifs (bras libres ≥ travail qui attend) : raison « inactifs ».
  Sous l'effectif de départ, la survie (IA2-a2, VERIF-NUIT) décide : pas de frein (raison « plancher »).
  Réglage fo-recruit-idle-max ≥ 60 (« aucun frein, seul le stock freine », sens d'IA1-a gardé : protocole 30 contre 10
  d'IA1-b) : pas de frein (raison « sans_frein »).

  E.decide(s, st, tick) -> d
    s = { n, cap, floor, blocked, agents, limit, threatened, idle, fond,
          tasks = { { kind, prio, critical, created, fond, tag, worker, prenable }, ... } (tâches du tableau),
          cost = { [plaque] = n } (coût de la recrue en plaques, après ce que le coffre a de prêt),
          left = { [plaque] = n } (stock libre − réservé par le travail en attente − manque de l'objectif),
          traits = { ambition, prudence } (pour mille, IA2-0) }
    st = état persistant de l'équipe (f.team.effectif : nombres et chaînes) ; st.last = tick de la dernière recrue de
         croissance (écrit par le runtime quand la recrue est faite : E.grown).
    d = { recruit, reason, waiting, hands, short, value, oldest, young, matter, low, period, margin, wait_left }
  Déterminisme : aucune itération par `pairs` qui décide, entiers seulement, aucun temps mesuré.
]]

local E = {}

E.WAIT_TICKS = 2 * 3600   -- travail qui attend depuis au moins 2 min (critère A7)
E.VALUE_MIN = 35          -- valeur minimale (priorité) d'un travail qui justifie une recrue : l'appoint (30) n'en vaut pas
E.PERIOD_TICKS = 3600     -- au plus une recrue de croissance par minute (caractère neutre, ambition 1000)
E.PERIOD_MIN = 1800       -- bornes de la période (ambition très forte : 30 s ; très faible : 2 min)
E.PERIOD_MAX = 7200
E.MARGIN = 50             -- plaques de fer gardées au-delà du coût (caractère neutre, prudence 1000)
E.MARGIN_MIN = 25
E.MARGIN_MAX = 100
E.NO_BRAKE = 60           -- fo-recruit-idle-max à 60 : aucun frein (sens d'IA1-a)
-- Genres de tâches qu'une recrue ne compte pas comme « travail qui attend » : la garde (pas de production ; sous menace,
-- toute l'équipe y va) ; la conception (O.DESIGN_KINDS : généralistes, la recrue est exécutante).
E.EXCLUDED = { garrison = true, claim_site = true, route = true, plan_module = true, claim_lot = true, plan_upgrade = true,
  open_zone = true, unblock = true }
E.RECRUIT_TAG = "ouvrier" -- fabrication de l'équipement d'une recrue (shared/team/planner.lua, want(..., "ouvrier"))
E.PLATES = { "iron-plate", "copper-plate" }

-- Raisons, dans l'ordre où elles sont examinées (fenêtre, journal ; locale/*/ia3d.cfg : fo-ia3d.why-<raison>).
E.REASONS = { "plafond", "garde", "plancher", "sans_frein", "menace", "inactifs", "matiere", "travail_recent",
  "pas_de_travail", "cout", "rythme", "recrue" }
E.RECRUITS = { plancher = true, sans_frein = true, recrue = true }
-- Raisons où l'équipe a l'effectif qu'il lui faut (aucun bras ne manque, ou elle ne peut plus grandir) : son « effectif
-- visé » est atteint (lu par le cerveau d'IA-V2 pour « économie faite », shared/ai3/cerveau.lua). « cout », « rythme »,
-- « recrue », « menace », « plancher », « sans_frein » : des bras manquent ou l'effectif visé reste le plafond.
E.ENOUGH = { plafond = true, garde = true, inactifs = true, matiere = true, travail_recent = true, pas_de_travail = true }

--- L'équipe a-t-elle l'effectif qu'il lui faut (raison d'une décision) ?
function E.enough(reason) return E.ENOUGH[reason or ""] or false end

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

--- Période entre deux recrues de croissance : PERIOD × 1000 / ambition (pour mille), bornée.
function E.period(traits)
  local a = (traits and traits.ambition) or 1000
  if a < 1 then a = 1 end
  return clamp(math.floor(E.PERIOD_TICKS * 1000 / a), E.PERIOD_MIN, E.PERIOD_MAX)
end

--- Marge de fer gardée au-delà du coût : MARGIN × prudence / 1000, bornée.
function E.margin(traits)
  local p = (traits and traits.prudence) or 1000
  return clamp(math.floor(E.MARGIN * p / 1000), E.MARGIN_MIN, E.MARGIN_MAX)
end

--- Travail qui attend, parmi les tâches du tableau : rend (W, valeur, plus ancienne attente, jeunes, sans matière,
--- de faible valeur). W = tâches libres du cerveau, prenables par une recrue, matière libre, valeur ≥ VALUE_MIN, en
--- attente depuis au moins WAIT_TICKS.
function E.waiting(tasks, tick)
  local w, value, oldest, young, matter, low = 0, 0, 0, 0, 0, 0
  for i = 1, #(tasks or {}) do
    local t = tasks[i]
    if not t.worker and not t.fond and not E.EXCLUDED[t.kind or ""] and t.tag ~= E.RECRUIT_TAG then
      local v = (t.prio or 0) * (t.critical and 3 or 2) -- valeur × 2 (1,5 sur le chemin critique, en entiers)
      local age = tick - (t.created or tick)
      if v < E.VALUE_MIN * 2 then
        low = low + 1
      elseif t.prenable == false then
        matter = matter + 1
      elseif age < E.WAIT_TICKS then
        young = young + 1
      else
        w = w + 1
        if v > value then value = v end
        if age > oldest then oldest = age end
      end
    end
  end
  return w, math.floor(value / 2), oldest, young, matter, low
end

--- La recrue se paie-t-elle ? cost et left : { [plaque] = n } ; marge de fer en plus du coût en fer.
function E.affordable(cost, left, margin)
  for _, k in ipairs(E.PLATES) do
    local need = (cost and cost[k]) or 0
    if k == "iron-plate" then need = need + (margin or 0) end
    if need > 0 and ((left and left[k]) or 0) < need then return false end
  end
  return true
end

--- La décision (voir l'en-tête). Ne modifie pas `st` (le runtime écrit st.last par E.grown).
function E.decide(s, st, tick)
  st = st or {}
  local d = { recruit = false, waiting = 0, hands = 0, short = 0, value = 0, oldest = 0, young = 0, matter = 0, low = 0,
    period = E.period(s.traits), margin = E.margin(s.traits), wait_left = 0 }
  local function done(reason)
    d.reason = reason
    d.recruit = E.RECRUITS[reason] or false
    return d
  end
  local n = s.n or 0
  if n >= (s.cap or 0) then return done("plafond") end
  if s.blocked then return done("garde") end
  if n < (s.floor or 0) then return done("plancher") end
  if (s.limit or 0) >= E.NO_BRAKE then return done("sans_frein") end
  local w, value, oldest, young, matter, low = E.waiting(s.tasks, tick)
  d.waiting, d.value, d.oldest, d.young, d.matter, d.low = w, value, oldest, young, matter, low
  local hands = (s.idle or 0) + (s.fond or 0)
  d.hands = hands
  local free = hands - (s.limit or 0)
  if free < 0 then free = 0 end
  d.short = w - free
  if s.threatened then return done("menace") end
  if d.short <= 0 then
    if hands > 0 then return done("inactifs") end
    if matter > 0 then return done("matiere") end
    if young > 0 then return done("travail_recent") end
    return done("pas_de_travail")
  end
  if not E.affordable(s.cost, s.left, d.margin) then return done("cout") end
  local last = st.last
  if last and tick - last < d.period then
    d.wait_left = d.period - (tick - last)
    return done("rythme")
  end
  return done("recrue")
end

--- Le runtime a fait une recrue de croissance (raison « recrue ») à `tick`.
function E.grown(st, tick)
  st.last = tick
  st.grown = (st.grown or 0) + 1
end

--- Comptes de la minute : raisons des pensées (st.why), recrues ; rend la ligne du journal et remet les comptes à zéro.
--- Raisons dans l'ordre de E.REASONS (aucun pairs).
function E.count(st, d)
  st.why = st.why or {}
  st.why[d.reason] = (st.why[d.reason] or 0) + 1
  st.thinks = (st.thinks or 0) + 1
  -- Copie des champs simples de la décision (nombres, chaînes, booléens : global), pour la fenêtre et le journal.
  local keep = {}
  for _, k in ipairs(E.FIELDS) do keep[k] = d[k] end
  st.last_d = keep
end

E.FIELDS = { "reason", "recruit", "waiting", "hands", "short", "value", "oldest", "young", "matter", "low", "period",
  "margin", "wait_left", "floor", "cost_iron", "left_iron" }

function E.minute_summary(st)
  local parts = {}
  local top, top_n = nil, -1
  for _, r in ipairs(E.REASONS) do
    local c = (st.why or {})[r]
    if c then
      parts[#parts + 1] = r .. ":" .. c
      if c > top_n then top, top_n = r, c end
    end
  end
  local out = { reasons = table.concat(parts, " "), top = top or "-", thinks = st.thinks or 0 }
  st.why, st.thinks = {}, 0
  return out
end

return E
