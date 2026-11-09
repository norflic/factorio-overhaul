--[[
  Lot ETAGE4 : bail des tournées prises (règle pure : shared/team/bail.lua). À chaque pensée d'équipe, après la synchronisation du tableau
  (script/team/team.lua) : pour chaque tâche PRISE d'un type à bail (Bl.KINDS), relevé du progrès du PNJ qui la tient (étape, approche du but
  de l'ÉTAPE, B.target ; combat ou fuite) dans la tâche (t.prog, nombres seuls) ; bail échu : Worker.release_stuck (abandon, puis
  dégagement au bail suivant) et une ligne [FO-BAIL] qui dit l'état exact du PNJ (machine, étape, navigation, comportement, position). Un PNJ
  qui n'existe plus, ou qui tient autre chose : la tâche est rendue. Bails de suite d'une même tournée (m4) : pause de la tournée.
  Les AUTRES tâches prises (hors Bl.KINDS) sont MESURÉES en lecture seule (accord du lead, 4/11) : tenue sans progrès depuis Bl.LEASE ou plus,
  par type (nombre de tâches, durée la plus longue), une ligne à la première fois, un bilan toutes les B.SUM_EVERY ticks.
  Interrupteur de banc : f.team.bail_regle == false coupe tout (comportement de 0.6.51).
  État : t.prog, t.hold_t, t.seen, t.pre_act, t.bail_vu (dans la tâche) ; b.bail_n (bails de suite par clé de tournée) ; f.stats.bail_*.
]]
local Bl = require("shared.team.bail")
local State = require("script.faction.state")
local Registry = require("script.companion.registry")
local Board = require("script.team.board")
local Worker = require("script.team.worker")

local B = {}

B.LOGS = 40          -- lignes [FO-BAIL] de bail au plus par équipe
B.MLOGS = 30         -- lignes [FO-BAIL] de mesure (autres tâches) au plus par équipe
B.SUM_EVERY = 10 * 3600 -- bilan [FO-BAIL] par équipe

--- État des comportements visibles du PNJ (arrêt, combat, fuite), par le crochet de script/team/worker.lua ; nil quand ils sont éteints.
local function k_of(agent)
  local H = Worker.hook
  if not (H and H.astate and H.enabled and H.enabled()) then return nil end
  return H.astate(agent)
end

--- But de l'ÉTAPE en cours (pas le point de passage des comportements visibles, agent.goal) : position d'un « goto », QG d'un « home » ; nil pour
--- une étape sans lieu (take, act : instantanées ; wait).
function B.target(agent, f)
  local step = agent.steps and agent.pc and agent.steps[agent.pc]
  if not step then return nil end
  if step[1] == "goto" and type(step[2]) == "table" and step[2].x then return step[2] end
  if step[1] == "home" then return f.home_spot end
  return nil
end

--- État du PNJ AVANT qu'il soit rendu (machine, étape, but de l'étape, navigation, comportement, point de passage, position) : ce que le journal
--- doit dire.
local function describe(agent, tick, f)
  local e = agent and agent.entity
  local p = e and e.valid and e.position or { x = 0, y = 0 }
  local step = agent and agent.steps and agent.steps[agent.pc]
  local tg = agent and f and B.target(agent, f)
  local g = agent and agent.goal
  local k = agent and e and e.valid and k_of(agent) or nil
  local ks = k and string.format("arret %s%s, refuge %s", k.hold and string.format("%d", k.hold - tick) or "-", k.hold_stop and " (alerte)" or "",
    k.refuge and "oui" or "non") or "comportement eteint"
  return string.format("PNJ %s etat %s, etape %s/%s (%s) vers %s, nav %s (%s), %s, tir %s, point de passage %s, position (%.1f, %.1f), %s",
    tostring(agent and agent.id), tostring(agent and agent.state), tostring(agent and agent.pc), tostring(agent and agent.steps and #agent.steps),
    tostring(step and step[1]), tg and string.format("(%.1f, %.1f)", tg.x, tg.y) or "-", tostring(agent and agent.nav),
    tostring(agent and agent.nav_fail), ks, agent and agent.shooting and "oui" or "non", g and string.format("(%.1f, %.1f)", g.x, g.y) or "-",
    p.x, p.y, agent and agent.street_walk and "rue" or "chemin")
end

local function line(f, t, desc, why, stall, tick)
  f.stats.bail_logs = (f.stats.bail_logs or 0) + 1
  if f.stats.bail_logs > B.LOGS then return end
  log(string.format("[FO-BAIL] %s : %s rendue (%s) apres %d s sans progres ; %s a %.1f min",
    f.key or "player", tostring(t.key), why, math.floor(stall / 60), desc, tick / 3600))
end

--- Le PNJ n'est-il pas encore à l'acte de son programme (étape « act » à venir) ? Après l'acte (retour au QG, travail fait) ou dans un
--- programme sans acte (abandon : « rentrer »), la tenue maximale ne s'applique plus (revue du lead, M1).
function B.pre_act(agent)
  local steps = agent.steps
  if not (steps and agent.pc) then return false end
  -- Garde PC-INVALIDE (plantage bail.lua:72, azure, 87,8 min : pc = 0, donc steps[0] nil). Le défaut est la cause réelle, corrigée dans
  -- script/team/worker.lua (état ia1d) ; cette garde ne le cache pas : une ligne au journal dit quand elle sert.
  if agent.pc < 1 or agent.pc > #steps + 1 then
    if not agent.pc_inv_logged then
      agent.pc_inv_logged = true
      log(string.format("[FO-PC-INVALIDE] PNJ %s : pc %s hors du programme (%d etape(s)) dans le bail : ni acte a venir ni tenue",
        tostring(agent.id), tostring(agent.pc), #steps))
    end
  end
  for i = math.max(agent.pc, 1), #steps do
    local s = steps[i]
    if s and s[1] == "act" then return true end
  end
  return false
end

--- Relevé de progrès d'une tâche tenue par `agent` (but de l'ÉTAPE ; combat et fuite : m5, bornés par tâche : R1). Rend (ticks sans progrès,
--- au combat ou en fuite compté, pensée précédente).
local function observe(f, t, agent, tick)
  local e = agent.entity
  local p, g = e.position, B.target(agent, f)
  local last = t.seen
  local raw = Bl.busy(k_of(agent), agent.shooting, tick)
  t.busy_acc = Bl.busy_acc(t.busy_acc, last, tick, raw)
  local busy = Bl.busy_counted(raw, t.busy_acc)
  -- travail sur place du bâtisseur (étape « ia1d », script/team/build.lua Build.work) : reconstructions (job.done) et arbres coupés vers son
  -- point d'appui (job.cut, cut_toward ; relecture de revue-etage4). L'attente de jetons (Tokens.take) n'en est pas : 2 min sans jeton = famine.
  local job = agent.ia1d
  local work = job and ((job.done or 0) + (job.cut or 0)) or nil
  local prog, stall = Bl.progress(t.prog, { pc = agent.pc, x = p.x, y = p.y, gx = g and g.x, gy = g and g.y, busy = busy, work = work }, tick)
  t.prog = prog
  t.seen = tick
  return stall, busy, last
end

--- m4 : bail d'une tournée (abandon) : bails de suite comptés par clé ; au-delà de Bl.HOLD_AFTER, la tournée est mise en pause (délai de reprise
--- du tableau, que Board.finish ne raccourcit pas) avec une ligne [FO-BAIL].
local function count_bail(f, b, t, tick)
  local o = f.outposts and f.outposts[t.outpost]
  b.bail_n = b.bail_n or {}
  local n = Bl.count(b.bail_n[t.key], not (o and (o.flux_fails or 0) > 0))
  b.bail_n[t.key] = n
  if not Bl.pause(n) then return end
  b.bail_n[t.key] = 0
  b.cooldown[t.key] = math.max(b.cooldown[t.key] or 0, tick + Bl.PAUSE_TICKS)
  f.stats.bail_paused = (f.stats.bail_paused or 0) + 1
  log(string.format("[FO-BAIL] %s : %s en pause %d min (%d bails de suite sans tournee reussie) a %.1f min", f.key or "player", tostring(t.key),
    Bl.PAUSE_TICKS / 3600, n, tick / 3600))
end

--- Une tâche à bail (Bl.KINDS). Rend 1 si elle est rendue.
local function lease(f, b, t, tick)
  local agent = Registry.get(t.worker)
  local e = agent and agent.entity
  if agent and agent.task == t and not (e and e.valid) then
    -- Revue (R2) : fenêtre de mort (entité perdue, PNJ encore inscrit) : rien ici ; Registry.on_removed finit la tâche une seule fois, avec
    -- le traitement de la mort (o.lethal_tick, lot IA1-b2). Filet : au-delà de Bl.DEAD_WAIT sans l'événement, la tâche est rendue ci-dessous.
    t.dead_t = t.dead_t or tick
    if tick - t.dead_t < Bl.DEAD_WAIT then return 0 end
  end
  if not (agent and e and e.valid and agent.task == t) then
    -- Le PNJ qui la tenait n'existe plus ou tient autre chose : la tâche est rendue (elle ne sera jamais finie par lui).
    f.stats.bail_orphan = (f.stats.bail_orphan or 0) + 1
    line(f, t, describe(agent, tick, f), "sans PNJ", tick - (t.claimed or tick), tick)
    t.fail = t.fail or "bail"
    -- Revue du lead (M2) : un PNJ encore inscrit (entité perdue) ne tient plus la tâche AVANT qu'elle soit finie : la machine ne la
    -- finirait pas une seconde fois.
    if agent and agent.task == t then agent.task, agent.steps, agent.pc = nil, nil, nil end
    Board.finish(f, t, false, tick)
    return 1
  end
  local stall, busy, last = observe(f, t, agent, tick)
  if busy then f.stats.bail_busy = (f.stats.bail_busy or 0) + 1 end
  t.hold_t = Bl.held_base(t.hold_t or t.claimed or tick, last, tick, busy)
  t.pre_act = B.pre_act(agent)
  local held = tick - t.hold_t
  if not Bl.expired(t.kind, stall, held, t.pre_act) then return 0 end
  local desc = describe(agent, tick, f)
  local how = Worker.release_stuck(agent, f, tick)
  f.stats.bail_released = (f.stats.bail_released or 0) + 1
  line(f, t, desc, string.format("%s, %s, tenue %d s, motif %s", how, stall >= Bl.LEASE and "sans progres" or "trop longue", math.floor(held / 60),
    tostring(t.fail)), stall, tick)
  -- L'abandon est un progrès (nouveau programme « rentrer », sans acte : la tenue maximale ne s'applique plus) ; le relevé repart de zéro.
  t.prog = nil
  if how == "abandon" then count_bail(f, b, t, tick) end
  return 1
end

--- Mesure en lecture seule d'une AUTRE tâche prise (accord du lead, 4/11) : rien n'est rendu.
local function measure(f, t, tick)
  local agent = Registry.get(t.worker)
  local e = agent and agent.entity
  if not (agent and e and e.valid and agent.task == t) then return end -- fabrication en arrière-plan, PNJ perdu : hors mesure
  local stall = observe(f, t, agent, tick)
  if stall < Bl.LEASE then return end
  local s = f.stats
  s.bail_autres = s.bail_autres or {}
  local r = s.bail_autres[t.kind] or { n = 0, max = 0 }
  s.bail_autres[t.kind] = r
  if stall > r.max then r.max = stall end
  if t.bail_vu then return end
  t.bail_vu = true
  r.n = r.n + 1
  s.bail_mlogs = (s.bail_mlogs or 0) + 1
  if s.bail_mlogs > B.MLOGS then return end
  log(string.format("[FO-BAIL] %s : MESURE (lecture seule) %s (%s) tenue sans progres depuis %d s ; %s a %.1f min", f.key or "player",
    tostring(t.key), tostring(t.kind), math.floor(stall / 60), describe(agent, tick, f), tick / 3600))
end

--- Bilan [FO-BAIL] d'une équipe, une fois par tranche de B.SUM_EVERY ticks.
local function summary(f, tick)
  local s = f.stats
  local slot = math.floor(tick / B.SUM_EVERY)
  if s.bail_sum_slot == slot then return end
  local first = s.bail_sum_slot == nil
  s.bail_sum_slot = slot
  if first then return end
  local parts = {}
  for _, kind in ipairs(State.sorted_keys(s.bail_autres or {})) do
    local r = s.bail_autres[kind]
    parts[#parts + 1] = string.format("%s %d (max %d s)", kind, r.n, math.floor(r.max / 60))
  end
  log(string.format("[FO-BAIL] %s : BILAN a %.0f min : rendues %d, sans PNJ %d, pauses %d, releves au combat ou en fuite %d ; AUTRES taches "
    .. "tenues sans progres %d s ou plus (lecture seule) : %s", f.key or "player", tick / 3600, s.bail_released or 0, s.bail_orphan or 0,
    s.bail_paused or 0, s.bail_busy or 0, Bl.LEASE / 60, #parts > 0 and table.concat(parts, ", ") or "aucune"))
end

--- Une pensée d'équipe : relevés de progrès, baux échus, mesure des autres tâches. Rend le nombre de tâches rendues.
function B.think(f, tick)
  if not (f.team and f.team.bail_regle ~= false) then return 0 end
  local b = Board.get(f)
  local n = 0
  for _, key in ipairs(State.sorted_keys(b.tasks)) do
    local t = b.tasks[key]
    if t and t.worker then
      if Bl.KINDS[t.kind] then n = n + lease(f, b, t, tick) else measure(f, t, tick) end
    end
  end
  summary(f, tick)
  return n
end

return B
