--[[
  Panneau de statistiques de la partie (lot PANEL-STATS) : LECTURE du moteur et de l'état du mod, pour l'onglet
  « Partie » de la fenêtre « Équipe et factions » (script/gui/partie.lua). Modèle pur : shared/gui/stats.lua.

  LECTURE SEULE : rien ici n'écrit dans l'état de jeu ni ne décide quoi que ce soit ; la seule écriture est l'anneau de
  relevés de l'espace « ia1i » (borné, hors de l'état de jeu : tests/ia1i_test.lua l'exclut de la comparaison).

  Deux fréquences (aucun calcul coûteux : tout est étalé, rien n'est parcouru à chaque tick) :
    - UN RELEVÉ toutes les S.PERIOD ticks (30 s), fenêtre ouverte ou non : les compteurs CUMULÉS de chaque équipe
      (production et consommation de la force, objets portés au coffre par les PNJ) entrent dans l'anneau de l'équipe ;
      les débits par minute sont des écarts de deux relevés (F242 : les compteurs, pas la moyenne du moteur) ;
    - UNE LECTURE (`collect`) à chaque reconstruction de l'onglet, soit toutes les 3 s, fenêtre OUVERTE sur l'onglet
      seulement (script/gui/team_window.lua, `every = 3`).

  Machines et mains restent SÉPARÉES (consigne du lot, F319/F244) :
    machines  statistiques de production du moteur de la force : toutes ses machines, qui qu'ait posé la machine ;
              ni ce que les PNJ minent à la main, ni ce qu'ils fabriquent à la main n'y est (F319) ;
    mains     compteurs du mod : objets portés au coffre par les PNJ (`f.team.delivered`), minerai miné à la main
              (`f.stats.mined`), fabrications à la main (`f.stats.crafted`).
]]

local State = require("script.faction.state")
local Poles = require("script.team.poles")
local Team = require("script.team.team")
local Journal = require("script.gui.ia1i_journal")
local S = require("shared.gui.stats")
local Profiler = require("script.core.profiler") -- mesure seulement (désactivée par défaut)

local Stats = {}

local function panel()
  local ns = Journal.ns()
  if not ns then return nil end
  if not ns.panel then ns.panel = { rings = {} } end -- sauvegarde d'avant le lot : créé au premier relevé
  return ns.panel
end

--- Équipe du joueur si elle existe VRAIMENT (coffre posé), sinon nil.
local function active_team(f)
  if f and f.hq and f.hq.valid and f.team then return f end
  return nil
end

--- Équipes montrées : la vôtre d'abord (même sans équipe de PNJ : la force du joueur a ses statistiques), puis les
--- factions vivantes dans l'ordre de leurs numéros. { key, f (nil sans équipe), force (nom) }.
function Stats.teams()
  local out = {}
  local pf = active_team(State.faction("player"))
  out[1] = { key = "player", f = pf, force = (pf and pf.force) or "player" }
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.key and game.forces[f.force] then out[#out + 1] = { key = f.key, f = f, force = f.force } end
  end
  return out
end

--- Compteurs cumulés du moteur d'une force : (production, consommation), tables {objet = n}. Lecture protégée : le
--- moteur simulé des tests hors jeu n'a pas de statistiques.
--- Rend aussi `hot` = { prod, cons } : le débit de la dernière minute de chaque objet (get_flow_count du moteur), pour que
--- le relevé garde un objet récent à fort débit même si son cumul est encore petit (S.trim). Une fois par relevé (30 s).
local function engine_counts(force)
  local prod, cons = {}, {}
  local hot = { prod = {}, cons = {} }
  pcall(function()
    local st = force.item_production_statistics
    prod, cons = st.input_counts, st.output_counts
    local idx = defines.flow_precision_index.one_minute
    for _, name in ipairs(S.sorted_keys(prod)) do
      hot.prod[name] = st.get_flow_count({ name = name, input = true, precision_index = idx })
    end
    for _, name in ipairs(S.sorted_keys(cons)) do
      hot.cons[name] = st.get_flow_count({ name = name, input = false, precision_index = idx })
    end
  end)
  return prod or {}, cons or {}, hot
end

--- (kills, pertes) d'une force : somme des ENTRÉES et des SORTIES de `kill_count_statistics`. Sens établi en moteur réel
--- le 29/10 par de vraies morts (banc `panel-kills`, 11 OK) : `input_counts` = ennemis détruits PAR la force (une tourelle
--- du joueur tue 3 petits mordeurs : input{small-biter=3}) ; `output_counts` = entités DE la force détruites (un coffre
--- du joueur tué par l'ennemi : output{wooden-chest=1}). Même sens que data/core/lualib/kill-score.lua.
local function engine_kills(force)
  local kills, losses = 0, 0
  pcall(function()
    local st = force.kill_count_statistics
    kills, losses = S.sum(st.input_counts), S.sum(st.output_counts)
  end)
  return kills, losses
end

-- Noms des technologies, triés, une fois par session (les prototypes sont fixes : même liste au rechargement).
local tech_names
local function technology_names()
  if tech_names then return tech_names end
  local list = {}
  for name, proto in pairs(game.technology_prototypes) do
    if not proto.hidden then list[#list + 1] = name end
  end
  table.sort(list)
  tech_names = list
  return list
end

--- (recherchées, au total) d'une force : ~220 technologies × 3 lectures, soit environ 0,6 ms par force (mesuré le 29/10,
--- ia1-gui) : trop pour un rafraîchissement par seconde. Compté donc à chaque relevé (30 s) et à chaque recherche terminée
--- (`recount`), et LU dans `ia1i.panel.techs` par l'onglet. Au total : les technologies ACTIVÉES et non cachées (celles de
--- l'arbre que le joueur voit).
local function count_techs(force)
  local done, total = 0, 0
  pcall(function()
    local techs = force.technologies
    for _, name in ipairs(technology_names()) do
      local t = techs[name]
      if t and t.enabled then
        total = total + 1
        if t.researched then done = done + 1 end
      end
    end
  end)
  return done, total
end

--- Recherche en cours { name, pct } d'une force, ou nil (deux lectures).
local function engine_research(force)
  local current
  pcall(function()
    local cur = force.current_research
    if cur then current = { name = cur.name, pct = S.pct(force.research_progress) } end
  end)
  return current
end

--- Recompte les technologies d'une force (recherche terminée) ; sans effet si le panneau n'a pas d'état.
function Stats.recount(force_name)
  local P = panel()
  local force = P and game.forces[force_name]
  if not force then return end
  P.techs = P.techs or {}
  local done, total = count_techs(force)
  P.techs[force_name] = { done = done, total = total }
end

---------------------------------------------------------------------------------------------------
-- Relevé (toutes les S.PERIOD ticks)
---------------------------------------------------------------------------------------------------
--- Ajoute un relevé aux anneaux de chaque équipe ; retire les anneaux des équipes disparues.
function Stats.sample(tick)
  local P = panel()
  if not P then return end
  Profiler.start("panel:sample")
  local live = {}
  local teams = Stats.teams()
  local turn = math.floor(tick / S.PERIOD) % #teams -- une équipe recomptée par relevé (étalé) ; l'événement fait le reste
  for i, t in ipairs(teams) do
    local force = game.forces[t.force]
    if force then
      live[t.key] = true
      local cached = P.techs and P.techs[t.force]
      if i == turn + 1 or not cached then Stats.recount(t.force) end
      local prod, cons, hot = engine_counts(force)
      local f = t.f
      local hand = (f and f.team and f.team.delivered) or {}
      local st = (f and f.stats) or {}
      local ring = P.rings[t.key]
      if not ring then
        ring = {}
        P.rings[t.key] = ring
      end
      S.push(ring, S.make_sample(tick, prod, cons, hand, st.mined, st.crafted, hot), S.RING)
    end
  end
  for _, k in ipairs(S.sorted_keys(P.rings)) do
    if not live[k] then P.rings[k] = nil end
  end
  local forces = {}
  for _, t in ipairs(Stats.teams()) do forces[t.force] = true end
  for _, k in ipairs(S.sorted_keys(P.techs or {})) do
    if not forces[k] then P.techs[k] = nil end
  end
  Profiler.stop("panel:sample")
end

--- Anneau d'une équipe (liste de relevés, copie superficielle pour les interfaces distantes) ou {}.
function Stats.ring(key)
  local P = panel()
  return (P and P.rings[key]) or {}
end

---------------------------------------------------------------------------------------------------
-- Lecture (fenêtre ouverte)
---------------------------------------------------------------------------------------------------
local function team_row(t, war_recs)
  local f = t.f
  local force = game.forces[t.force]
  local kills, losses = 0, 0
  local done, total, current = 0, 0, nil
  if force then
    kills, losses = engine_kills(force)
    local P = panel()
    local c = P and P.techs and P.techs[t.force]
    if c then done, total = c.done, c.total else done, total = count_techs(force) end -- avant le premier relevé
    current = engine_research(force)
  end
  local row = {
    key = t.key, player = t.key == "player", has_team = f ~= nil, force = t.force,
    techs_done = done, techs_total = total, research = current, kills = kills, losses = losses,
    color = f and f.color or nil,
  }
  if f then
    row.level = f.tech or 0
    row.outposts = f.outposts_count or 0
    row.soldiers = f.soldiers_count or 0
    row.engineers = f.engineers_count or 0
    row.npc_max = Team.npc_max(f)
    if row.player then
      -- Les attaques de VOTRE équipe n'existent pas (elle ne lance pas d'attaque) : seulement celles qu'elle subit.
      row.attacks_out = nil
      row.attacks_in = war_recs
    else
      row.attacks_out = (f.stats and f.stats.attacks) or 0
      row.attacks_in = (f.pvp and f.pvp.attacks) or 0
    end
  elseif row.player then
    row.attacks_in = war_recs
  end
  return row
end

--- Détail de l'équipe choisie : machines, mains, PNJ.
local function team_detail(t)
  local f = t.f
  local force = game.forces[t.force]
  local ring = Stats.ring(t.key)
  local d = { key = t.key, span = S.span(ring), samples = #ring, has_team = f ~= nil }

  -- Machines : cumuls FRAIS (lus maintenant), débits des relevés.
  local prod, cons = {}, {}
  if force then prod, cons = engine_counts(force) end
  d.machines = {}
  for _, r in ipairs(S.flows(ring, "prod", S.SHOWN)) do
    d.machines[#d.machines + 1] = { name = r.name, rate = r.rate, total = prod[r.name] or r.total,
      cons_rate = S.rate(ring, "cons", r.name), cons_total = cons[r.name] or 0 }
  end
  d.prod_total, d.cons_total = S.sum(prod), S.sum(cons)

  -- Mains : seulement s'il y a une équipe de PNJ.
  if f then
    local delivered = (f.team and f.team.delivered) or {}
    d.hands = { items = {}, mined = (f.stats and f.stats.mined) or 0, crafted = (f.stats and f.stats.crafted) or 0,
      mined_rate = S.rate_scalar(ring, "mined"), crafted_rate = S.rate_scalar(ring, "crafted"),
      delivered_total = S.sum(delivered) }
    for _, r in ipairs(S.flows(ring, "hand", S.SHOWN)) do
      d.hands.items[#d.hands.items + 1] = { name = r.name, rate = r.rate, total = delivered[r.name] or r.total }
    end

    -- PNJ : tâche de chacun (Poles.status), décompte, part au travail, causes d'inactivité (cumul des pensées).
    local s = Poles.status(f)
    local alive = f.engineers_count or 0
    local tc = S.task_counts(s and s.npcs or {}, alive)
    d.workers = { alive = alive, max = Team.npc_max(f), tasks = tc.list, total = tc.total, mining = tc.mining }
    local L = s and s.last
    if L then d.workers.busy = S.busy_pct(L.n, L.idle) end
    local why = f.team and f.team.idle_why
    if why then d.workers.why = { rien = why.rien or 0, bloque = why.bloque or 0, manque = why.manque or 0 } end
  end
  return d
end

--- Tout ce que l'onglet affiche : { tick, teams = { ligne… }, detail = {…} } ; `selected` = clé de l'équipe détaillée
--- (« player » par défaut, ou la première équipe si la clé n'existe plus). Aucune fonction, aucun objet du moteur.
function Stats.collect(selected, tick)
  Profiler.start("panel:collect")
  local teams = Stats.teams()
  local recs = 0
  for _, t in ipairs(teams) do
    if t.key ~= "player" and t.f and t.f.pvp then recs = recs + (t.f.pvp.attacks or 0) end
  end
  local out = { tick = tick, teams = {} }
  local pick = teams[1]
  for _, t in ipairs(teams) do
    out.teams[#out.teams + 1] = team_row(t, recs)
    if t.key == selected then pick = t end
  end
  out.selected = pick.key
  out.detail = team_detail(pick)
  Profiler.stop("panel:collect")
  return out
end

return Stats
