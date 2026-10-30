--[[
  PÔLES, MANAGERS, GÉNÉRALISTES (lot IA1-b, docs/EQUIPES_PNJ.md §3, §4, §8.1, §8.6, §16) : branche le modèle pur
  shared/team/org.lua sur l'équipe réelle (team.lua, board.lua, worker.lua).

  Une fois par pensée d'équipe (après Board.sync) :
    1. durées des tâches MESURÉES par type (fin réussie : temps depuis la prise) ; travail estimé de chaque tâche du
       tableau (`work`) et reste de chaque tâche prise (`work_left`, publié : « reste de la tâche en cours ») ;
    2. candidats de fond par pôle (shared/team/fond.lua) : leur nombre (plus les PNJ déjà au fond) est la capacité
       `room` de chaque pôle ;
    3. O.plan : pôles cibles (travail du cerveau + surplus selon l'orientation, dans la capacité de fond), placement
       des recrues, au plus 2 changements de pôle par pensée (immédiats pour un inoccupé, DIFFÉRÉS en fin de tâche
       pour un occupé : O.settle, jamais de tâche interrompue), promotion, pôles des généralistes, meneurs des
       PARTIES durables (Q-IA1-6 (2), D-14 : avant-postes, fonderie, atelier, défense) ;
    4. ouverture du fond : pour chaque pôle, autant de tâches que de PNJ inactifs du pôle, plus une marge, moins les
       tâches libres du pôle ;
    5. rapport d'une ligne par manager et par généraliste (interface v0 en lecture, `/fo-team org`, `/fo-team vue`,
       interface distante « fo-ia1 »).
  État : f.team.org (orientation choisie, statistiques, rapport, durées mesurées, crise injectée par un banc) et
  agent.org = { role, pole, dest, moved_tick, project, changes } (registre des agents). Listes triées partout.

  NON fait dans ce lot (déclaré) : exécutants NOMMÉS qui suivent une partie (lecture (2) de Q-IA1-6 : seul le meneur
  est désigné) ; zones (IA1-g) ; projets de conception (IA1-d) ; rangs et expérience (IA1-h) ; cibles de production
  (IA1-e1) ; onglets « Orientation », « PNJ », « Territoire », « Chantiers » de l'interface (IA1-i).
]]

local Profiler = require("script.core.profiler") -- lot PERF : portées fines
local Events = require("script.core.events")
local O = require("shared.team.org")
local T = require("shared.team.config")
local Fond = require("shared.team.fond")
local FerEquipe = require("shared.team.fer_equipe") -- lot FER-EQUIPE : minage de fer de renfort pour les inactifs
local Inter = require("script.team.intermediaires") -- lot MAIN-ET-INTERMEDIAIRES (D09) : ressources que les machines sortent en quantité
local Planner = require("shared.team.planner") -- lot IA1-b2 : avant-postes non défendus (P.undefended)
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Registry = require("script.companion.registry")
local Board = require("script.team.board")

local Poles = {}

Poles.PERIOD = 300            -- période de pensée des équipes (shared/faction/config.lua think_period, player_team)
Poles.CHANGES_KEPT = 8        -- dates des derniers changements de pôle EFFECTIFS gardées par PNJ (mesure)
Poles.CHIEFS = 5              -- généralistes au plus (docs §4.4 ; réglage fo-team-chiefs prévu au §11, non créé)
Poles.CRISIS_PRIO = 50
Poles.ROOM_WINDOW = 60        -- capacité de fond lissée sur 60 pensées (5 min)
Poles.DANGER_RADIUS = 40      -- nid ou ver à moins de 40 tuiles : avant-poste écarté du fond (garde, agrandissement)
Poles.FAR_LOGS = 20           -- lot SCALE-COMPLET : lignes [FO-LOIN] du fond au plus par équipe (f.stats.far_logs)
local POLE_KEYS = { "extraction", "base", "territoire" }

local function new_stats()
  return {
    thinks = 0, double_think = 0, moves_now = 0, moves_deferred = 0, settled = 0, interrupted = 0, promoted = 0,
    gen_moves = 0, fond_opened = 0, starve_taken = 0, token_refused = 0, busy_sum = 0, n_sum = 0,
  }
end

function Poles.state(f)
  local t = f.team
  t.org = t.org or { stats = new_stats(), dur = {} }
  return t.org
end

--- Orientation de l'équipe : celle choisie (interface distante, `/fo-team orientation`), sinon la personnalité de la
--- faction (O.PERSONALITY), sinon l'équilibre (votre équipe).
function Poles.orientation(f)
  local org = f.team and f.team.org
  if org and org.orientation then return org.orientation end
  if f.is_player then return "equilibre" end
  return O.PERSONALITY[f.personality or ""] or "equilibre"
end

--- Choisit l'orientation (nom de préréglage, table { extraction, base, territoire } ou liste de 3 points).
--- Rend les points normalisés, ou nil si la valeur est refusée.
function Poles.set_orientation(f, o)
  if type(o) == "string" and not O.PRESETS[o] then return nil end
  if type(o) ~= "string" and type(o) ~= "table" then return nil end
  local org = Poles.state(f)
  org.orientation = o
  org.orientation_tick = game.tick
  return O.normalize(o, false)
end

---------------------------------------------------------------------------------------------------
-- Durées mesurées (O.TASK_WORK était une estimation « à mesurer au lot IA1-b »)
---------------------------------------------------------------------------------------------------
function Poles.task_done(f, task, ok, tick)
  if not f.team then return end
  local org = Poles.state(f)
  -- Minage : la ressource qui vient de réussir sert à la crise d'un banc ; celle dont le programme a échoué (aucune
  -- tuile libre à 96 tuiles du QG) est écartée du minage de fond pendant 2 min (essai 5 : tâches perdues en pause).
  if task.kind == "mine" and task.resource then
    if ok then
      if not task.trees then org.last_mined = task.resource end -- lot CORR-RECONSTRUIRE : le bois des arbres ne sert pas de ressource de crise
    elseif task.fail == "programme" then
      org.mine_bad = org.mine_bad or {}
      org.mine_bad[task.resource] = tick
    end
  end
  if not (ok and task.claimed) then return end
  local d = org.dur[task.kind] or { n = 0, s = 0 }
  d.n = d.n + 1
  d.s = d.s + math.floor((tick - task.claimed) / 60)
  org.dur[task.kind] = d
end

local function work_of(org, kind)
  local d = org.dur[kind]
  if d and d.n >= 3 then return math.max(1, math.floor(d.s / d.n)) end
  return O.TASK_WORK[kind] or O.DEFAULT_WORK
end

---------------------------------------------------------------------------------------------------
-- Changements de pôle
---------------------------------------------------------------------------------------------------
local function log_change(f, o, tick)
  o.changes = o.changes or {}
  o.changes[#o.changes + 1] = tick
  while #o.changes > Poles.CHANGES_KEPT do table.remove(o.changes, 1) end
end

--- Fin de tâche d'un PNJ (worker.lua, AVANT sa tâche suivante) : sa destination différée devient son pôle.
function Poles.settle(f, agent, tick)
  local o = agent.org
  if not (o and o.dest ~= nil and f.team) then return end
  if O.settle(o, tick) then
    log_change(f, o, tick)
    Poles.state(f).stats.settled = Poles.state(f).stats.settled + 1
  end
end

--- Pire nombre de changements EFFECTIFS d'un PNJ dans une heure glissante [t, t + 1 h) (mesure du critère).
function Poles.worst_hour(changes)
  local worst = 0
  local c = changes or {}
  for i = 1, #c do
    local n = 0
    for j = i, #c do
      if c[j] - c[i] < 216000 then n = n + 1 end
    end
    if n > worst then worst = n end
  end
  return worst
end

---------------------------------------------------------------------------------------------------
-- Parties durables (Q-IA1-6 (2)) : ce que mènent les généralistes
---------------------------------------------------------------------------------------------------
local function parts_of(f, view)
  local list = {}
  for _, o in ipairs(view.outposts or {}) do
    list[#list + 1] = { id = "ap:" .. o.id, domain = "gisements", prio = o.drills or 0, started = true }
  end
  list[#list + 1] = { id = "fonderie", domain = "gisements", prio = 1, started = true }
  list[#list + 1] = { id = "atelier", domain = "production", prio = 1, started = true }
  list[#list + 1] = { id = "defense", domain = "defense", prio = 1, started = true }
  return list
end

--- Partie d'une tâche (seulement quand le domaine de la partie garde le pôle du type de la tâche).
local function part_of_task(t)
  local k = t.kind
  if (k == "service" or k == "extend") and t.outpost then return "ap:" .. t.outpost end
  if k == "smelt" or k == "smelters" then return "fonderie" end
  if k == "craft" then return "atelier" end
  if k == "refill" or k == "fortify" or k == "garrison" then return "defense" end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Pensée d'organisation
---------------------------------------------------------------------------------------------------
local function crisis_tasks(org, tick)
  local c = org.crisis
  if not c then return {} end
  if tick >= c.until_tick then
    org.crisis = nil
    return {}
  end
  local out = {}
  local res = c.resource or org.last_mined or "coal"
  for i = 1, c.n do
    out[#out + 1] = { key = "crise:mine:" .. i, kind = "mine", prio = Poles.CRISIS_PRIO, resource = res,
      count = 50, crisis = true }
  end
  return out
end

--- Injecte une crise de travail d'extraction (bancs) : n tâches de minage du minerai `resource`, rouvertes à chaque
--- pensée pendant `ticks` (« avant-poste perdu : le travail d'extraction explose », docs §4.2).
function Poles.inject_crisis(f, n, ticks, resource)
  local org = Poles.state(f)
  org.crisis = { n = n, until_tick = game.tick + ticks, resource = resource, at = game.tick }
  return true
end

--- Le cerveau manque-t-il d'OBJETS (et non de sites) pour son objectif ? (plan.missing de shared/team/planner.lua)
--- Lot IA1-b2 : un objet que l'équipe ne sait pas faire (`book` sans sa recette : tourelle sans la recherche) ne
--- compte pas : le fond ne lui prendrait aucune plaque (essai 6 : « il manque tourelle » coupait la réserve, PNJ inactifs).
local RAW = { ["iron-plate"] = true, ["copper-plate"] = true, coal = true, stone = true, ["iron-ore"] = true,
  ["copper-ore"] = true, ["steel-plate"] = true, ["stone-brick"] = true }
function Poles.brain_short(plan, book)
  for _, m in ipairs(plan and plan.missing or {}) do
    local item = m[1]
    if type(item) == "string" and item:sub(1, 5) ~= "site:" and (not book or RAW[item] or book:handcraftable(item)) then
      return true
    end
  end
  return false
end

function Poles.think(f, view, book, tick, plan)
  local org = Poles.state(f)
  local st = org.stats
  if org.last_think and tick - org.last_think < Poles.PERIOD then st.double_think = st.double_think + 1 end
  org.last_think = tick
  st.thinks = st.thinks + 1

  -- Crise injectée (bancs) : travail d'extraction réel, compté dans le besoin.
  local crisis = crisis_tasks(org, tick)
  if #crisis > 0 then Board.add(f, crisis, tick) end

  local b = Board.get(f)
  local list = b.list

  Profiler.fstart("poles:1-travail")
  -- 1. Travail estimé (mesuré) et reste des tâches prises ; parties.
  local real, fond_busy = {}, { 0, 0, 0 }
  local mine_fond_busy = 0
  for _, t in ipairs(list) do
    local w = work_of(org, t.kind)
    t.work = w
    t.project = part_of_task(t)
    if t.worker and t.claimed then t.work_left = math.max(1, w - math.floor((tick - t.claimed) / 60)) end
    if t.fond then
      if t.worker then
        local p = O.POLE_INDEX[t.pole or O.task_pole(t)] or 2
        fond_busy[p] = fond_busy[p] + 1
        if t.kind == "mine" and not t.key:find(":fer:", 1, true) then mine_fond_busy = mine_fond_busy + 1 end -- lot FER-EQUIPE : le renfort de fer a son propre plafond
      end
    else
      real[#real + 1] = t
    end
  end

  -- PNJ vivants (ordre des id).
  local agents, by_id = {}, {}
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a and a.entity and a.entity.valid then
      a.org = a.org or {}
      agents[#agents + 1] = a
      by_id[a.id] = a
    end
  end
  local npcs, n_exec, gens_before = {}, 0, 0
  for _, a in ipairs(agents) do
    local o = a.org
    local role = o.role or "executant"
    if role == "generalist" then gens_before = gens_before + 1 else n_exec = n_exec + 1 end
    npcs[#npcs + 1] = { id = a.id, role = role, pole = o.pole, dest = o.dest, rank = 1, xp = 0, idle = a.task == nil,
      work_left = a.task and a.task.work_left or nil, moved_tick = o.moved_tick }
  end
  org.n_exec = n_exec

  Profiler.fstop("poles:1-travail")
  Profiler.fstart("poles:2-fond")
  -- 2. Candidats de fond (capacité par pôle).
  -- Clés déjà au tableau, ou en pause après un échec (Board.add les refuserait : la capacité serait surévaluée).
  local keys = {}
  for _, t in ipairs(list) do keys[t.key] = true end
  for _, k in ipairs(State.sorted_keys(b.cooldown or {})) do
    if tick < b.cooldown[k] then keys[k] = true else b.cooldown[k] = nil end -- pauses échues : retirées
  end
  local skip = {}
  for _, res in ipairs(State.sorted_keys(org.mine_bad or {})) do
    if tick - org.mine_bad[res] < 7200 then skip[res] = true end
  end
  -- Lot MAIN-ET-INTERMEDIAIRES (D09) : ni fond ni renfort de fer sur une ressource que les machines de l'équipe sortent en quantité
  -- (décision de la pensée précédente, script/team/intermediaires.lua ; mode survie : rien de coupé).
  for _, res in ipairs(State.sorted_keys(Inter.mine_skip(f))) do skip[res] = true end
  local free = Fond.free_stock(view.stock, list)
  local epoch = (f.tech or 0) + 1
  local mine_cap = O.manual_cap(n_exec, epoch)
  -- Avant-postes DANGEREUX (nid ou ver à moins de 40 tuiles) : ni garde ni agrandissement de fond (morts des PNJ :
  -- 117 tués par les ennemis en 60 min à 30 PNJ, contre 12 avant le lot). Une recherche par avant-poste et par pensée.
  local danger = {}
  local surface = f.hq and f.hq.valid and f.hq.surface
  if surface then
    for _, o in ipairs(view.outposts or {}) do
      local real = f.outposts and f.outposts[o.id]
      local pos = real and (real.access or real.pos)
      if pos and surface.count_entities_filtered({ position = pos, radius = Poles.DANGER_RADIUS, force = "enemy",
        type = { "unit-spawner", "turret" }, limit = 1 }) > 0 then
        danger[o.id] = true
      end
      -- Lot IA1-b2 : votre équipe, avant-poste près d'une perte récente : pas de fond vers lui (prudence par zone).
      if pos and f.is_player and Poles.near_loss(f, pos, tick) then danger[o.id] = true end
    end
  end
  local prudent = Poles.prudent(org, tick)
  if f.is_player then prudent = false end -- prudence par zone (Poles.near_loss), plus de repli de toute l'équipe
  if prudent then st.prudent_thinks = (st.prudent_thinks or 0) + 1 end
  -- Le fond sert les PNJ AU-DELÀ DE L'EFFECTIF DE DÉPART (fo-npc-start, 8 ; f.team.floor) : une équipe restée à son
  -- effectif de départ garde le comportement d'avant IA1-b (aucune sortie de fond). Moteur réel, verif-guide graine
  -- 1618033988 (la partie du guide du DC) : avec le fond à 8 PNJ, votre équipe sortait, perdait ses PNJ à partir de
  -- 18 min et son coffre était détruit (3 essais sur 4 avec des règles de prudence différentes) ; sans fond, 8 PNJ et
  -- 2 100 fer à 59 min (main 0.4.25).
  -- Lot IA1-b2 (D-17, « Laisser grandir ») : une équipe sous « défendre d'abord » (view.defend_first) QUI PEUT POSER
  -- DES TOURELLES (au stock ou fabricables) a son fond DÈS son effectif de départ : le QG puis chaque avant-poste sont
  -- défendus avant d'y travailler, rien ne se bâtit sans tourelles, la réserve ne sert que ce qui peut se poser, et votre
  -- équipe n'a plus de garde d'avant-poste. C'est ce travail qui fait venir les recrues (frein « pas de recrue sans
  -- travail », script/team/team.lua). SANS tourelle possible, règle d'IA1-b (fond au-delà de l'effectif de départ) :
  -- essai 2 du lot (fond dès le départ sans tourelle), verif-guide graine 1618033988 : 5 avant-postes à 8 min, QG
  -- attaqué à 9 min, équipe perdue à 10 min (F241 de nouveau).
  local df = view.defend_first and true or false
  local turrets_ok = df and ((free["gun-turret"] or 0) > 0 or (book and book:handcraftable("gun-turret"))) or false
  local n, floor0 = f.engineers_count or 0, f.team.floor or 0
  -- Équipe décimée (sous son effectif de départ) : aucun fond (essai 3 : sorties de fond d'une équipe en reconstruction).
  -- Votre équipe à son effectif de départ (R-QCM-25c (c), complément du DC : « sur les 8 PNJ y en avait pas mal qui
  -- faisaient rien ») : fond COMPLET si une tourelle est possible, sinon fond SÛR (ctx.safe_only : fonderie, réserve
  -- au-dessus des planchers, transport des avant-postes proches, minage près du coffre ; ni agrandir ni bâtir).
  -- Une faction : fond au-delà de son effectif de départ seulement (règle d'IA1-b ; la croissance reste à votre équipe).
  -- Votre équipe SANS tourelle possible : fond SÛR quel que soit l'effectif (pas d'expansion sans défense ; ia1b-scale10,
  -- 10 PNJ sans recherche : agrandissements de fond, QG attaqué par des cracheurs, équipe perdue à 24 min).
  local full, safe
  if f.is_player then
    full = turrets_ok and n >= floor0
    safe = (not turrets_ok) and n >= floor0
  else
    full = n > floor0
    safe = false
  end
  local fond_on = (full or safe) and not view.hq_threat -- QG menacé : tout le monde au coffre (script/team/team.lua)
  org.fond_on = fond_on
  local cands
  -- Lot FER-EQUIPE : PNJ inactifs de votre équipe + coffre pauvre en fer et en minerai : minage de fer à la main de renfort.
  -- Calculé AUSSI quand le fond est coupé (FerEquipe.off_fond : votre équipe sous son effectif de départ, sans fer pour recruter).
  local player = f.is_player or false
  local fer_off = FerEquipe.off_fond({ player = player, fond_on = fond_on, threat = view.hq_threat })
  local iron_extra
  local spec = player and T.outposts.iron
  if spec then
    local idle_n = 0
    for _, np in ipairs(npcs) do if np.idle and np.role ~= "generalist" then idle_n = idle_n + 1 end end
    iron_extra = { res = spec.resource, n = FerEquipe.extra_mines({ idle = idle_n, plates = free[spec.product],
      ore = free[spec.resource], smelters = view.smelters, prudent = prudent, skip = skip[spec.resource] }) }
    if iron_extra.n > 0 and (fond_on or fer_off) and not org.fer_logged then
      org.fer_logged = tick
      log(string.format("[FO-FER] %s : minage de fer de renfort, %d PNJ inactif(s) sur %d, fer %d, minerai %d, effectif %d/%d%s a %.1f min",
        f.key or "?", iron_extra.n, idle_n, free[spec.product] or 0, free[spec.resource] or 0, n, floor0,
        fond_on and "" or " (fond coupe, sous l'effectif de depart)", tick / 3600))
    end
  end
  -- Lot PRIORITE-RESSOURCES : le cerveau a décidé « production d'abord » (le fer ne paie pas la défense ET la production,
  -- shared/team/priorite.lua) : le fond agrandit et bâtit sans attendre les tourelles, seul un avant-poste meurtrier reste exclu.
  local prod_first = plan ~= nil and plan.priorite ~= nil and plan.priorite.production_first == true
  local block_turrets = turrets_ok and not prod_first
  if fond_on then
    local fctx = { book = book, keys = keys, mine_skip = skip, danger = danger,
      prudent = prudent, brain_short = Poles.brain_short(plan, book), mine_left = math.max(0, mine_cap - mine_fond_busy),
      defend_first = block_turrets, undefended = Planner.no_go(view, block_turrets), no_outpost_guard = player,
      no_hq_guard = player, turrets_ok = turrets_ok, no_reserve_floor = df, safe_only = safe or nil,
      -- Transport sans limite de distance (essai 7 : à 64 tuiles, presque aucun avant-poste n'était assez proche) ; un
      -- avant-poste meurtrier non défendu et la prudence (pertes récentes) l'arrêtent.
      transport = player or nil, reserve = player and Fond.PLAYER_RESERVE or nil,
      mine_radius = player and T.near_mine or nil, annex_want = Stock.wanted(f), iron_extra = iron_extra,
      saturated = f.team.ia3 and f.team.ia3.saturated or nil } -- lot SITE-PROCHE (R4)
    cands = Fond.candidates(view, free, fctx)
    -- Lot SCALE-COMPLET : builds LOINTAINS refusés par le fond (shared/team/fond.lua, F.far_build ; écrits dans fctx.far_builds) :
    -- un avant-poste proche du même type a encore des places. Journal [FO-LOIN], Poles.FAR_LOGS lignes au plus par équipe.
    -- Relecture : une ligne quand un type ENTRE dans le refus (f.stats.far_on[type]), et non à chaque pensée : sinon les
    -- Poles.FAR_LOGS lignes partaient en 20 pensées (100 s) et le journal se taisait pour le reste de la partie.
    local far_now = {}
    for _, fb in ipairs(fctx.far_builds or {}) do far_now[fb.kind] = true end
    f.stats.far_on = f.stats.far_on or {}
    for _, kind in ipairs(T.OUTPOST_ORDER) do
      if not far_now[kind] then f.stats.far_on[kind] = nil end
    end
    for _, fb in ipairs(fctx.far_builds or {}) do
      local first = not f.stats.far_on[fb.kind]
      f.stats.far_on[fb.kind] = true
      if first and (f.stats.far_logs or 0) < Poles.FAR_LOGS then
        f.stats.far_logs = (f.stats.far_logs or 0) + 1
        log(string.format("[FO-LOIN] %s : fond, nouvel avant-poste %s refuse a %.1f min : site admissible le plus proche a %d tuiles du QG, avant-poste %s avec des places a %d tuiles (on agrandit le proche)",
          f.key or "?", fb.kind, tick / 3600, math.floor(fb.d_site), fb.kind, math.floor(fb.d_room)))
      end
    end
  else
    cands = { extraction = {}, base = {}, territoire = {} }
    -- Lot FER-EQUIPE : fond coupé pour votre équipe SOUS son effectif de départ (hors QG menacé) : seul le renfort de fer reste.
    if iron_extra and fer_off then
      cands.extraction = Fond.iron_extra_tasks({ iron_extra = iron_extra, keys = keys, mine_skip = skip, prudent = prudent,
        mine_radius = T.near_mine })
    end
  end
  local room_now = {}
  for p, name in ipairs(POLE_KEYS) do room_now[p] = #cands[name] + fond_busy[p] end
  -- Capacité LISSÉE : le maximum des ROOM_WINDOW dernières pensées (5 min). Essai 4 du banc : la capacité instantanée
  -- de la Base passait de 0 à 3 et revenait (réserve refaite en 10 s), les cibles suivaient, des PNJ changeaient de
  -- pôle puis restaient sous délai de garde 10 min dans un pôle vide (orientation et crise sans effet en 2 pensées).
  -- Un PNJ dont le pôle n'a rien à faire prend le fond d'un autre pôle (Board.claim, rang 7) : il reste au travail.
  org.room_hist = org.room_hist or {}
  local hist = org.room_hist
  hist[#hist + 1] = room_now
  while #hist > Poles.ROOM_WINDOW do table.remove(hist, 1) end
  local room = { 0, 0, 0 }
  for _, r in ipairs(hist) do
    for p = 1, 3 do if r[p] > room[p] then room[p] = r[p] end end
  end
  -- Prospecter (fond du manager Gisements) : un type dont aucun avant-poste ne peut plus s'agrandir et qui n'a aucun
  -- site connu demande un site de plus à la prospection (Sites.prospect lit f.site_needs) : le capital suivant.
  local growable = {}
  for _, o in ipairs(view.outposts or {}) do
    if not o.full and (o.drills or 0) < T.max_drills(o.kind) then growable[o.kind] = true end
  end
  f.site_needs = f.site_needs or {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local res = T.outposts[kind].resource
    if full and not prudent and not growable[kind] and (view.sites and view.sites[kind] or 0) == 0 then
      f.site_needs[res] = math.max(f.site_needs[res] or 0, 1)
    end
  end

  Profiler.fstop("poles:2-fond")
  Profiler.fstart("poles:3-org")
  -- 3. Organisation.
  local out = O.plan({
    tick = tick, npcs = npcs, tasks = real, orientation = Poles.orientation(f), threatened = view.threatened,
    zones = 0, projects = parts_of(f, view), chiefs = Poles.CHIEFS, vacancy_since = org.vacancy_since, room = room,
  })
  for _, pl in ipairs(out.place) do
    local a = by_id[pl.id]
    if a then a.org.pole = pl.pole end
  end
  for _, m in ipairs(out.moves) do
    local a = by_id[m.id]
    if a then
      if m.deferred then
        a.org.dest = m.to
        st.moves_deferred = st.moves_deferred + 1
      else
        if a.task then st.interrupted = st.interrupted + 1 end -- ne doit jamais arriver (contrôlé par ia1-poles)
        a.org.pole = m.to
        a.org.moved_tick = tick
        log_change(f, a.org, tick)
        st.moves_now = st.moves_now + 1
      end
    end
  end
  if out.promote and by_id[out.promote] then
    by_id[out.promote].org.role = "generalist"
    st.promoted = st.promoted + 1
    -- Promotion après une mort : délai depuis la vacance (mesure du banc : jamais moins de 2 min).
    if org.vacancy_since then
      local d = tick - org.vacancy_since
      st.vacancy_promotions = (st.vacancy_promotions or 0) + 1
      st.vacancy_delay_min = math.min(st.vacancy_delay_min or d, d)
      st.vacancy_delay_max = math.max(st.vacancy_delay_max or d, d)
    end
  end
  local gen_moved = {}
  for _, gm in ipairs(out.gen_moves) do gen_moved[gm.id] = gm end
  for _, g in ipairs(out.gen_poles) do
    local a = by_id[g.id]
    if a then
      local o = a.org
      local gm = gen_moved[g.id]
      if gm and gm.from ~= nil and gm.from ~= g.pole then
        o.moved_tick = tick
        log_change(f, o, tick)
        st.gen_moves = st.gen_moves + 1
      end
      o.pole, o.dest = g.pole, nil
    end
  end
  for _, a in ipairs(agents) do a.org.project = nil end
  for _, l in ipairs(out.leaders or {}) do
    local a = by_id[l.npc]
    if a then a.org.project = l.project end
  end
  local gens = 0
  for _, a in ipairs(agents) do if a.org.role == "generalist" then gens = gens + 1 end end
  if gens >= (out.generalists_wanted or 0) then org.vacancy_since = nil end

  Profiler.fstop("poles:3-org")
  -- 4. Fond : inactifs du pôle + marge (1 + 1 par 6 PNJ du pôle) - tâches libres du pôle.
  local idle_p, staff_p, open_p = { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }
  for _, a in ipairs(agents) do
    local p = O.POLE_INDEX[O.effective_pole(a.org) or ""]
    if p then
      staff_p[p] = staff_p[p] + 1
      if not a.task then idle_p[p] = idle_p[p] + 1 end
    end
  end
  for _, t in ipairs(list) do
    if not t.worker then
      local p = O.POLE_INDEX[t.pole or O.task_pole(t)] or 2
      open_p[p] = open_p[p] + 1
    end
  end
  local add = {}
  local opened = { 0, 0, 0 }
  local short = 0
  for p, name in ipairs(POLE_KEYS) do
    local k = math.max(0, idle_p[p] + 1 + math.floor(staff_p[p] / 6) - open_p[p])
    local c = cands[name]
    for i = 1, math.min(k, #c) do
      c[i].project = part_of_task(c[i])
      add[#add + 1] = c[i]
    end
    opened[p] = math.min(k, #c)
    -- PNJ inactifs de ce pôle que son fond ne peut pas occuper : servis par le fond des autres pôles (rang 7).
    short = short + math.max(0, math.min(idle_p[p], k) - opened[p])
  end
  for p, name in ipairs(POLE_KEYS) do
    local c = cands[name]
    while short > 0 and opened[p] < #c do
      opened[p] = opened[p] + 1
      local t = c[opened[p]]
      t.project = part_of_task(t)
      add[#add + 1] = t
      short = short - 1
    end
  end
  if #add > 0 then
    Board.add(f, add, tick)
    st.fond_opened = st.fond_opened + #add
  end

  -- Mesures : occupation (PNJ avec une tâche), effectifs, rapport.
  local idle = 0
  for _, a in ipairs(agents) do if not a.task then idle = idle + 1 end end
  st.busy_sum = st.busy_sum + (#agents - idle)
  st.n_sum = st.n_sum + #agents
  local actual, assigned, pending, gpole = { 0, 0, 0 }, { 0, 0, 0 }, 0, { 0, 0, 0 }
  for _, a in ipairs(agents) do
    local o = a.org
    local pa = O.POLE_INDEX[o.pole or ""]
    local pe = O.POLE_INDEX[O.effective_pole(o) or ""]
    if o.role == "generalist" then
      if pa then gpole[pa] = gpole[pa] + 1 end
    else
      if pa then actual[pa] = actual[pa] + 1 end
      if pe then assigned[pe] = assigned[pe] + 1 end
      if o.dest then pending = pending + 1 end
    end
  end
  if org.crisis then
    log(string.format("[FO-IA1B] %s : crise, %d tache(s) de crise au tableau, besoin %d/%d/%d s, cibles %d/%d/%d, %d changement(s) decide(s)",
      f.key or "player", #crisis, math.floor(out.need[1]), math.floor(out.need[2]), math.floor(out.need[3]),
      out.targets[1], out.targets[2], out.targets[3], #out.moves))
  end
  org.last = {
    tick = tick, pts = out.pts, targets = out.targets, assigned = assigned, actual = actual, pending = pending,
    gens = gpole, n = #agents, idle = idle, need = out.need, surplus = out.surplus, room = room, opened = opened,
    mine_cap = mine_cap, idle_rate = out.idle_rate, ops = out.ops, waiting = #(out.waiting or {}),
  }
  Poles.report(f, view, agents, org)
  return out
end

---------------------------------------------------------------------------------------------------
-- Rapports : une ligne par manager et par généraliste (données ; texte localisé à l'affichage)
---------------------------------------------------------------------------------------------------
function Poles.report(f, view, agents, org)
  local b = Board.get(f)
  local c = { service_busy = 0, mine_busy = 0, craft_busy = 0, craft_open = 0, grow_open = 0, grow_busy = 0,
    garrison_busy = 0, smelt_busy = 0 }
  for _, t in ipairs(b.list) do
    local k = t.kind
    if t.worker then
      if k == "service" then c.service_busy = c.service_busy + 1
      elseif k == "mine" then c.mine_busy = c.mine_busy + 1
      elseif k == "craft" then c.craft_busy = c.craft_busy + 1
      elseif k == "extend" or k == "build" then c.grow_busy = c.grow_busy + 1
      elseif k == "garrison" then c.garrison_busy = c.garrison_busy + 1
      elseif k == "smelt" or k == "smelters" then c.smelt_busy = c.smelt_busy + 1 end
    else
      if k == "craft" then c.craft_open = c.craft_open + 1 end
      if k == "extend" or k == "build" then c.grow_open = c.grow_open + 1 end
    end
  end
  local drills = 0
  for _, o in ipairs(view.outposts or {}) do drills = drills + (o.drills or 0) end
  local low = 0
  for _, g in ipairs(view.turret_groups or {}) do if g.low then low = low + 1 end end
  local stock = view.stock or {}
  local gens = {}
  for _, a in ipairs(agents) do
    local o = a.org
    if o.role == "generalist" then
      gens[#gens + 1] = { id = a.id, pole = o.pole or "?", part = o.project or "", task = a.task and a.task.kind or "" }
    end
  end
  org.report = {
    managers = {
      gisements = { outposts = #(view.outposts or {}), drills = drills, grow_open = c.grow_open, grow_busy = c.grow_busy },
      logistique = { service = c.service_busy, mine = c.mine_busy, mine_cap = org.last and org.last.mine_cap or 0 },
      production = { craft = c.craft_busy, craft_open = c.craft_open, drills = stock["burner-mining-drill"] or 0,
        furnaces = stock["stone-furnace"] or 0 },
      infrastructures = { smelters = view.smelters or 0, smelt = c.smelt_busy },
      defense = { groups = #(view.turret_groups or {}), low = low, garrison = c.garrison_busy },
    },
    generalists = gens,
  }
end

local function pole_name(p) return { "fo-ia1b.pole-" .. (p ~= "" and p ~= "?" and p or "none") } end

--- Lignes localisées de la vue d'ensemble (interface v0 et `/fo-team org`).
function Poles.lines(f)
  local org = f.team and f.team.org
  if not (org and org.last and org.report) then return { { "fo-ia1b.no-report" } } end
  local L, r = org.last, org.report.managers
  local busy = L.n > 0 and math.floor(100 * (L.n - L.idle) / L.n + 0.5) or 0
  local lines = {
    { "fo-ia1b.orientation", L.pts[1], L.pts[2], L.pts[3] },
    { "fo-ia1b.staff", L.actual[1], L.gens[1], L.actual[2], L.gens[2], L.actual[3], L.gens[3], L.n, busy, L.pending },
    { "fo-ia1b.mgr-gisements", r.gisements.outposts, r.gisements.drills, r.gisements.grow_busy, r.gisements.grow_open },
    { "fo-ia1b.mgr-logistique", r.logistique.service, r.logistique.mine, r.logistique.mine_cap },
    { "fo-ia1b.mgr-production", r.production.craft, r.production.craft_open, r.production.drills, r.production.furnaces },
    { "fo-ia1b.mgr-infrastructures", r.infrastructures.smelters, r.infrastructures.smelt },
    { "fo-ia1b.mgr-defense", r.defense.groups, r.defense.low, r.defense.garrison },
  }
  for _, g in ipairs(org.report.generalists) do
    local part = g.part ~= "" and g.part or { "fo-ia1b.part-none" }
    local task = g.task ~= "" and { "fo-ia1b.task", g.task } or { "fo-ia1b.task-none" }
    lines[#lines + 1] = { "fo-ia1b.gen-line", g.id, pole_name(g.pole), part, task }
  end
  return lines
end

---------------------------------------------------------------------------------------------------
-- Interface v0 (lecture) : cadre « Vue d'ensemble » de votre équipe
---------------------------------------------------------------------------------------------------
local FRAME = "fo_ia1b_vue"

local function fill(frame, f)
  frame.clear()
  for _, l in ipairs(Poles.lines(f)) do frame.add({ type = "label", caption = l }) end
end

function Poles.toggle_view(player, f)
  local screen = player.gui.screen
  if screen[FRAME] then
    screen[FRAME].destroy()
    return false
  end
  local frame = screen.add({ type = "frame", name = FRAME, caption = { "fo-ia1b.view-title" }, direction = "vertical" })
  frame.location = { 40, 120 }
  fill(frame, f)
  return true
end

Events.on_nth_tick(600, function()
  local f = State.faction("player")
  if not f then return end
  for _, player in ipairs(game.connected_players or {}) do
    local screen = player.gui and player.gui.screen
    local frame = screen and screen[FRAME]
    if frame then fill(frame, f) end
  end
end)

---------------------------------------------------------------------------------------------------
-- Disparition d'un généraliste : la promotion attend 2 min (O.PROMOTION_DELAY), sauf croissance
---------------------------------------------------------------------------------------------------
Registry.on_removed(function(agent)
  if not (agent.faction and agent.org) then return end
  local f = State.faction(agent.faction)
  if not (f and f.team) then return end
  local org = Poles.state(f)
  -- Prudence : dates des dernières pertes de PNJ de l'équipe.
  org.losses = org.losses or {}
  org.losses[#org.losses + 1] = game.tick
  while #org.losses > 8 do table.remove(org.losses, 1) end
  -- Lot IA1-b2 : lieu de la perte (prudence PAR ZONE de votre équipe, Poles.near_loss).
  local p = agent.death_pos
  if p then
    org.loss_pos = org.loss_pos or {}
    org.loss_pos[#org.loss_pos + 1] = { x = p.x, y = p.y, tick = game.tick }
    while #org.loss_pos > 8 do table.remove(org.loss_pos, 1) end
  end
  if agent.org.role == "generalist" and org.vacancy_since == nil then org.vacancy_since = game.tick end
end)

--- PRUDENCE (lot IA1-b) : au moins PRUDENCE_LOSSES PNJ perdus dans les PRUDENCE_TICKS dernières, le fond ne sort plus
--- du QG (ni minage, ni agrandissement, ni construction, ni garde d'avant-poste) jusqu'à PRUDENCE_TICKS après la
--- dernière perte. Moteur réel, verif-guide graine 1618033988 : votre équipe sortie au fond y perdait ses PNJ (1 PNJ
--- et 67 fer à 59 min, contre 8 PNJ et 2 100 fer avant le lot), les recrues de survie vidant le coffre.
Poles.PRUDENCE_LOSSES = 2
Poles.PRUDENCE_TICKS = 5 * 3600

function Poles.prudent(org, tick)
  local l = org.losses or {}
  local n = 0
  for i = #l, 1, -1 do
    if tick - l[i] < Poles.PRUDENCE_TICKS then n = n + 1 else break end
  end
  return n >= Poles.PRUDENCE_LOSSES
end

--- Lot IA1-b2 (D-18, décision de l'orchestrateur) : prudence PAR ZONE pour votre équipe. Au lieu de garder toute
--- l'équipe au QG 5 min après 2 pertes (ia1-poles : 20 à 22 PNJ sur 27 y attendaient), seul le travail de fond qui
--- mène à moins de Poles.LOSS_RADIUS tuiles du lieu d'une perte récente (Poles.PRUDENCE_TICKS) est écarté.
Poles.LOSS_RADIUS = 64
function Poles.near_loss(f, pos, tick)
  local org = f.team and f.team.org
  if not (org and org.loss_pos and pos) then return false end
  local r2 = Poles.LOSS_RADIUS * Poles.LOSS_RADIUS
  for _, p in ipairs(org.loss_pos) do
    if tick - p.tick < Poles.PRUDENCE_TICKS then
      local dx, dy = p.x - pos.x, p.y - pos.y
      if dx * dx + dy * dy <= r2 then return true end
    end
  end
  return false
end

--- État publié pour les bancs (interface distante « fo-ia1 », team_status) : aucune fonction, aucun objet du moteur.
function Poles.status(f)
  local org = f.team and f.team.org
  if not org then return nil end
  local npcs = {}
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a and a.org then
      local o = a.org
      local ch = {}
      for i, t in ipairs(o.changes or {}) do ch[i] = t end
      npcs[#npcs + 1] = { id = a.id, role = o.role or "executant", pole = o.pole, dest = o.dest, project = o.project,
        task = a.task and a.task.kind or nil, fond = a.task and a.task.fond or false, changes = ch,
        resource = a.task and a.task.resource or nil, -- lot IA-V2 : ressource d'une tâche de minage (bancs, lecture seule)
        worst_hour = Poles.worst_hour(o.changes) }
    end
  end
  local stats = {}
  for k, v in pairs(org.stats) do stats[k] = v end
  local dur = {}
  for _, k in ipairs(State.sorted_keys(org.dur)) do dur[k] = { n = org.dur[k].n, s = org.dur[k].s } end
  return { last = org.last, stats = stats, npcs = npcs, report = org.report, dur = dur,
    orientation = Poles.orientation(f), crisis = org.crisis }
end

return Poles
