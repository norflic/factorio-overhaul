--[[
  Lot IA3-k « comportements visibles » : exécution (docs/IA3K_COMPORTEMENTS.md). Règles pures : shared/ai3/danger.lua
  (carte du danger, porte des tâches), shared/ai3/route.lua (itinéraire), shared/ai3/reaction.lua (réaction, peur).

  Branché sur les ouvriers par des crochets COURTS de script/team/worker.lua (Worker.hook = ce module) :
    sense(agent, tick)  début de l'autodéfense, à chaque pensée du PNJ : regard devant lui, attaque subie, peur,
                        réaction ; rend true quand il a pris la main (la pensée de l'état s'arrête là) ;
    leg(agent, pos, r, tick)  avant chaque Nav.go d'une étape « aller » : prochain point de passage (ou nil) ;
    gate(f, agent, task, steps, tick)  après le programme d'une tâche : partir, attendre l'escorte, ou attendre.
  Morts : crochet Registry.on_removed (cause et lieu gardés par le registre). Réglage de carte fo-war-ia3-comportement :
  éteint, aucun crochet n'agit.

  État (global, espace « ia3k », nombres et tables) :
    teams[clé] = { map, epoch, stream, char = { prudence, agressivite } | nil (forcé par un banc), hold, stats,
                   escorts = { [id d'agent] = { units, n, since } } }
    agents[id] = { final, pts, i, epoch, refuge, hold, hp, armed, armed_t, label, label_key, label_t, escort, tour }
  Flux : Tr.new_stream(graine, 470 + numéro de l'équipe) (sels 470 à 479 : IA3-k ; 479 = votre équipe).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local FSM = require("script.core.fsm")
local Profiler = require("script.core.profiler")
local Registry = require("script.companion.registry")
local Nav = require("script.agents.nav")
local State = require("script.faction.state")
local Character = require("script.faction.character")
local Worker = require("script.team.worker")
local T = require("shared.team.config")
local D = require("shared.ai3.danger")
local R = require("shared.ai3.route")
local Re = require("shared.ai3.reaction")
local Tr = require("shared.faction.traits")

local M = {}

M.SETTING = "fo-war-ia3-comportement"
M.SALT = 470
M.HOME_SAFE = 32        -- pas de regard à moins de 32 tuiles du QG (il est défendu)
M.WP_RADIUS = 4         -- rayon d'arrivée d'un point de passage
M.WP_REACH = 8          -- point de passage atteint à 8 tuiles
M.LABEL_TTL = 150       -- 2,5 s (D1 : au moins 2 s)
M.LABEL_GAP = 120       -- même étiquette redessinée au plus toutes les 2 s
M.ESCORT_WAIT = 900     -- attente de l'escorte au QG, au plus
M.SAFE_RADIUS = 160     -- au-delà : « loin » (C6)
M.ALLY_R = 16
M.ENGAGE_HOLD = 120
M.PRUNE_PERIOD = 3600
M.MACHINE = "worker"

local COLORS = {
  alerte = { r = 1, g = 0.85, b = 0.1 }, detour = { r = 1, g = 0.6, b = 0.15 }, ["demi-tour"] = { r = 1, g = 0.45, b = 0.1 },
  fuite = { r = 1, g = 0.25, b = 0.25 }, combat = { r = 0.85, g = 0.35, b = 1 }, escorte = { r = 0.35, g = 0.7, b = 1 },
  attente = { r = 0.8, g = 0.8, b = 0.8 }, patrouille = { r = 0.45, g = 1, b = 0.45 }, garde = { r = 0.6, g = 0.9, b = 0.6 },
  nettoyage = { r = 1, g = 0.4, b = 0.8 }, abri = { r = 0.9, g = 0.9, b = 0.4 }, defense = { r = 1, g = 0.5, b = 0.5 },
}
M.COLORS = COLORS

Storage.declare("ia3k", function() return { teams = {}, agents = {} } end)

local function S() return Storage.ns("ia3k") end

---------------------------------------------------------------------------------------------------
-- Réglage (cache local, refait à chaque changement de réglage : valeur synchronisée)
---------------------------------------------------------------------------------------------------
local enabled_cache = nil
function M.enabled()
  if enabled_cache == nil then
    local s = settings.global[M.SETTING]
    enabled_cache = s ~= nil and s.value == true
  end
  return enabled_cache
end
Events.on(defines.events.on_runtime_mod_setting_changed, function() enabled_cache = nil end)
Events.on_configuration_changed(function() enabled_cache = nil end)

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
local function new_stats()
  return { looks = 0, seen = {}, actions = {}, plans = 0, astar = 0, via = 0, blocked = 0, gate = {}, deaths = 0,
    labels = {}, refuges = 0, alerts = 0, forgot = 0, epoch_checks = 0, gate_why = {} }
end

function M.team_key(f) return tostring(f.id) end

function M.team(f)
  local k = M.team_key(f)
  local st = S()
  local t = st.teams[k]
  if not t then
    local num = type(f.id) == "number" and f.id or 9
    t = { map = D.new(), epoch = 0, stream = Tr.new_stream(Character.map_seed(), M.SALT + num), stats = new_stats(),
      escorts = {} }
    st.teams[k] = t
  end
  return t
end

local function astate(agent)
  local st = S()
  local a = st.agents[agent.id]
  if not a then
    a = {}
    st.agents[agent.id] = a
  end
  return a
end
M.astate = astate

local function faction_of(agent)
  return agent.faction and State.faction(agent.faction) or nil
end

--- Caractère lu par les règles (pour mille) : forcé par un banc, sinon les traits tirés de la faction (IA2-0), sinon
--- neutre (votre équipe).
function M.character(f)
  local t = M.team(f)
  if t.char then return t.char.prudence or 1000, t.char.agressivite or 1000 end
  local tr = f.traits
  return (tr and tr.prudence) or 1000, (tr and tr.agressivite) or 1000
end

local function inc(tab, k, n) tab[k] = (tab[k] or 0) + (n or 1) end

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

---------------------------------------------------------------------------------------------------
-- Étiquettes visibles (D1)
---------------------------------------------------------------------------------------------------
--- Texte au-dessus d'une entité. `holder` garde l'identifiant (un seul texte vivant par porteur). D1 : chaque état reste
--- au moins LABEL_GAP ticks ; un état nouveau qui arrive avant attend son tour (holder.pending, M.flush_label), sauf la
--- fuite, qui s'affiche tout de suite au-dessus (second emplacement) sans effacer l'état précédent.
function M.label_entity(holder, entity, key, tick, stats)
  if not (entity and entity.valid) then return end
  local young = holder.label_t and tick - holder.label_t < M.LABEL_GAP
  if holder.label_key == key and young then return end
  if young and holder.label and rendering.is_valid(holder.label) then
    if key == "fuite" then
      if holder.label2_t and tick - holder.label2_t < M.LABEL_GAP then return end
      if holder.label2 and rendering.is_valid(holder.label2) then rendering.destroy(holder.label2) end
      holder.label2 = rendering.draw_text({
        text = { "fo-ia3k.etat-fuite" }, surface = entity.surface, target = entity, target_offset = { 0, -4.0 },
        color = COLORS.fuite, scale = 1.3, alignment = "center", time_to_live = M.LABEL_TTL,
      })
      holder.label2_t = tick
      if stats then inc(stats.labels, key) end
      return
    end
    holder.pending = key
    return
  end
  holder.pending = nil
  if holder.label and rendering.is_valid(holder.label) then rendering.destroy(holder.label) end
  holder.label = rendering.draw_text({
    text = { "fo-ia3k.etat-" .. key }, surface = entity.surface, target = entity, target_offset = { 0, -3.2 },
    color = COLORS[key] or COLORS.alerte, scale = 1.3, alignment = "center", time_to_live = M.LABEL_TTL,
  })
  holder.label_key, holder.label_t = key, tick
  if stats then inc(stats.labels, key) end
end

local function label(agent, key, tick, tstats)
  M.label_entity(astate(agent), agent.entity, key, tick, tstats)
end
M.label = label

--- État en attente (arrivé pendant les 2 s du précédent) : affiché quand son tour vient.
function M.flush_label(holder, entity, tick, stats)
  if holder.pending and holder.label_t and tick - holder.label_t >= M.LABEL_GAP then
    M.label_entity(holder, entity, holder.pending, tick, stats)
  end
end

---------------------------------------------------------------------------------------------------
-- Ce que l'on voit
---------------------------------------------------------------------------------------------------
local range_cache = {} -- [nom de prototype] = portée (prototypes : identiques chez tous les pairs)

local TURRET_TYPES = { ["ammo-turret"] = true, ["electric-turret"] = true, ["fluid-turret"] = true, ["artillery-turret"] = true }

--- Genre (shared/ai3/danger.lua) et portée d'une entité ennemie, lus de son TYPE et de son prototype.
function M.classify(e)
  local ty = e.type
  local kind
  if ty == "unit-spawner" then kind = "spawner"
  elseif ty == "turret" then kind = (e.force.name == "enemy") and "worm" or "turret"
  elseif TURRET_TYPES[ty] then kind = "turret"
  elseif ty == "character" then kind = "character"
  else kind = "unit" end
  local name = e.name
  local r = range_cache[name]
  if r == nil then
    r = false
    if kind == "worm" or kind == "turret" or kind == "unit" then
      local pr = e.prototype
      local ap = pr.attack_parameters
      if ap and ap.range then r = ap.range end
      -- Une unité charge dès qu'elle VOIT : sa portée utile est sa distance de vue (petit déchiqueteur : 30).
      if kind == "unit" and ty == "unit" then
        local v = pr.vision_distance
        if v and v > (r or 0) then r = v end
      end
    end
    range_cache[name] = r
  end
  return kind, (r ~= false) and r or nil
end

--- Distance d'un point à la polyligne départ -> pts[i..] -> final.
local function d_route(p, a, ep)
  local pts = {}
  if a.pts then for i = a.i or 1, #a.pts do pts[#pts + 1] = a.pts[i] end end
  if a.final then pts[#pts + 1] = a.final end
  local best = 1e18
  local px, py = p.x, p.y
  for _, q in ipairs(pts) do
    local vx, vy = q.x - px, q.y - py
    local wx, wy = ep.x - px, ep.y - py
    local L = vx * vx + vy * vy
    local u = L > 0 and (wx * vx + wy * vy) / L or 0
    if u < 0 then u = 0 elseif u > 1 then u = 1 end
    local dx, dy = px + u * vx - ep.x, py + u * vy - ep.y
    local dd = dx * dx + dy * dy
    if dd < best then best = dd end
    px, py = q.x, q.y
  end
  return math.sqrt(best)
end
M.d_route = d_route

local function armed(agent, a, tick)
  if a.armed == nil or tick - (a.armed_t or -1e9) >= 600 then
    local e = agent.entity
    a.armed = e.get_item_count(T.worker_ammo) + e.get_item_count("piercing-rounds-magazine") > 0
    a.armed_t = tick
  end
  return a.armed
end

--- Refuge le plus proche : une tourelle amie (pas du côté de la menace), sinon la case du QG.
local function refuge(f, p, ep)
  local best, bd = nil, nil
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t and t.valid then
      local tp = t.position
      if d2(tp, ep) >= 144 then
        local dd = d2(tp, p)
        if not bd or dd < bd then best, bd = tp, dd end
      end
    end
  end
  local home = f.home_spot or f.hq_pos
  if not best or d2(home, p) <= bd then return { x = home.x, y = home.y } end
  -- 3 tuiles derrière la tourelle, du côté du QG
  local hx, hy = home.x - best.x, home.y - best.y
  local L = math.sqrt(hx * hx + hy * hy)
  if L < 1 then return { x = best.x, y = best.y } end
  return { x = best.x + 3 * hx / L, y = best.y + 3 * hy / L }
end
M.refuge = refuge

-- Crochet d'alerte (branché par script/ai3/soldats.lua) : soldats envoyés vers une menace vue par un PNJ en fuite.
M.on_alert = nil
-- Crochet d'escorte (branché par script/ai3/soldats.lua) : demande(f, agent, n, tick) -> true si des soldats partent ;
-- escort_free(f) -> nombre de soldats qui peuvent escorter.
M.request_escort = nil
M.escort_free = nil

---------------------------------------------------------------------------------------------------
-- Itinéraire d'un PNJ (route.lua sur la carte de son équipe)
---------------------------------------------------------------------------------------------------
--- Y a-t-il une marque près de la boîte du trajet ? (sans calculer le champ : menaces, morts, cases mobiles).
local function marks_near(map, a, b, tick)
  local m = (R.BOX_MARGIN + 2) * D.CELL
  local x0, x1 = math.min(a.x, b.x) - m, math.max(a.x, b.x) + m
  local y0, y1 = math.min(a.y, b.y) - m, math.max(a.y, b.y) + m
  for _, t in ipairs(map.threats) do
    if t.x >= x0 and t.x <= x1 and t.y >= y0 and t.y <= y1 then return true end
  end
  for _, d in ipairs(map.deaths) do
    if tick - d.t < D.HOUR and d.x >= x0 and d.x <= x1 and d.y >= y0 and d.y <= y1 then return true end
  end
  for k in pairs(map.cells) do -- existence seulement : indépendant de l'ordre
    local cx, cy = D.unkey(k)
    local x, y = D.center(cx, cy)
    if x >= x0 and x <= x1 and y >= y0 and y <= y1 then return true end
  end
  return false
end

--- Itinéraire de p à goal pour ce PNJ. opts = { draw = bool (variation de tournée), B = seuil forcé }.
function M.plan(f, agent, p, goal, tick, opts)
  opts = opts or {}
  local t = M.team(f)
  local prud = M.character(f)
  local B = opts.B or D.block(prud)
  local field, n = {}, 0
  if marks_near(t.map, p, goal, tick) then
    local m = R.BOX_MARGIN + 1
    local box = { math.min(D.cell(p.x), D.cell(goal.x)) - m, math.min(D.cell(p.y), D.cell(goal.y)) - m,
      math.max(D.cell(p.x), D.cell(goal.x)) + m, math.max(D.cell(p.y), D.cell(goal.y)) + m }
    field, n = D.field(t.map, tick, box)
  end
  local draw, seed = nil, nil
  if opts.draw then
    local st = t.stream
    draw = function(k) return Tr.range(st, 1, k) end
    seed = Tr.range(st, 1, Tr.MOD - 2)
  end
  local res = R.plan(p, goal, { field = field, n = n, B = B, seed = seed, draw = draw, side = opts.side })
  res.B = B
  res.field = field
  return res
end

---------------------------------------------------------------------------------------------------
-- Crochet : prochain point de passage d'une étape « aller »
---------------------------------------------------------------------------------------------------
function M.leg(agent, pos, radius, tick, depth)
  depth = (depth or 0) + 1
  if depth > 4 then return nil end -- garde : sorties ou points injoignables en chaîne
  if not M.enabled() then return nil end
  local f = faction_of(agent)
  local e = agent.entity
  if not (f and e and e.valid) then return nil end
  local a = astate(agent)
  local p = e.position
  if a.refuge then
    if d2(p, a.refuge) > 36 then return a.refuge, 3 end
    a.refuge = nil
  end
  if not a.final or d2(a.final, pos) > 1 then
    a.final = { x = pos.x, y = pos.y }
    a.pts = nil
  end
  -- Sortie d'une zone marquée faite : l'itinéraire est recalculé depuis la case sûre.
  if a.pts and a.partial and not a.pts[a.i] then a.pts, a.partial = nil, nil end
  if not a.pts then
    local t = M.team(f)
    -- Côté de la variation : un pour les retours au QG, un pour les allers (sinon l'aller suivant dépend du retour).
    local home = d2(pos, f.hq_pos) <= 24 * 24
    local sk = home and "side_h" or "side_o"
    local res = M.plan(f, agent, p, pos, tick, { draw = true, side = a[sk] })
    if res.side then a[sk] = res.side end
    if res.blocked and not res.partial then
      t.stats.blocked = t.stats.blocked + 1
      if home or a.escort then
        -- Rentrer au QG (ou passer escorté) : le chemin qui minimise le danger, faute de mieux.
        res = M.plan(f, agent, p, pos, tick, { B = 1e9 })
      else
        -- Aller sans issue sûre : on ne traverse pas ; demi-tour à la pensée suivante (sense).
        a.abort_pending = true
        a.pts, a.i = {}, 1
        return { x = p.x, y = p.y }, 1
      end
    end
    a.partial = res.partial or nil
    t.stats.plans = t.stats.plans + 1
    if res.astar then t.stats.astar = t.stats.astar + 1 elseif #res.pts > 0 then t.stats.via = t.stats.via + 1 end
    if res.escape then t.stats.escapes = (t.stats.escapes or 0) + 1 end
    a.pts, a.i, a.epoch, a.mver = res.pts, 1, t.epoch, t.mver
    a.tour = (a.tour or 0) + 1
    if res.astar and Profiler.enabled() then
      log(string.format("[FO-IA3K] %s : PNJ %d itineraire A* de (%d, %d) a (%d, %d) : %d point(s), %.0f tuiles (direct %.0f), danger max %d (seuil %d)%s%s",
        tostring(f.key), agent.id, math.floor(p.x), math.floor(p.y), math.floor(pos.x), math.floor(pos.y), #res.pts, res.len,
        res.direct, res.max_d, res.B, res.escape and ", sortie de zone" or "", res.blocked and ", BLOQUE" or ""))
    end
  end
  while a.pts[a.i] and d2(p, a.pts[a.i]) <= M.WP_REACH * M.WP_REACH do a.i = a.i + 1 end
  if a.partial and not a.pts[a.i] then a.pts, a.partial = nil, nil return M.leg(agent, pos, radius, tick, depth) end
  local w = a.pts[a.i]
  if w and not w.ok then
    -- Point de passage praticable (ni eau, ni bâtiment) : la case libre la plus proche, sinon il est sauté.
    local q = e.surface.find_non_colliding_position(e.name, w, 8, 1)
    if q then
      w = { x = q.x, y = q.y, ok = true }
      a.pts[a.i] = w
    else
      a.i = a.i + 1
      return M.leg(agent, pos, radius, tick, depth)
    end
  end
  if w then
    a.wp_goal = { x = w.x, y = w.y }
    return w, M.WP_RADIUS
  end
  a.wp_goal = nil
  return nil
end

--- Crochet : la navigation vers un POINT DE PASSAGE a échoué (îlot, falaise) : les points restants sont abandonnés, le
--- PNJ va droit au but (la tâche n'échoue pas pour un point de passage). Rend true si l'échec était le nôtre.
function M.nav_failed(agent, tick)
  if not M.enabled() then return false end
  local a = S().agents[agent.id]
  if not (a and a.wp_goal and agent.goal) then return false end
  if d2(a.wp_goal, agent.goal) > 1 then return false end
  a.pts, a.i, a.wp_goal = {}, 1, nil
  local f = faction_of(agent)
  if f then local t = M.team(f) t.stats.wp_fail = (t.stats.wp_fail or 0) + 1 end
  return true
end

---------------------------------------------------------------------------------------------------
-- Crochet : porte d'une tâche (C5, C6)
---------------------------------------------------------------------------------------------------
function M.gate(f, agent, task, steps, tick)
  local t0 = S().teams[M.team_key(f)]
  if t0 and t0.hold then return false, "banc" end -- banc : même réglage éteint (témoin)
  if not M.enabled() then return true end
  local t = M.team(f)
  local dest
  for i, s in ipairs(steps) do
    if s[1] == "goto" then dest = s[2] break end
  end
  if not dest then return true end
  local e = agent.entity
  local p = e.position
  local res = M.plan(f, agent, p, dest, tick)
  local pts = R.samples(p, res.pts, dest, 8)
  local deaths = D.deaths_near(t.map, pts, D.HOUR_R, tick)
  local far = d2(f.hq_pos, dest) > M.SAFE_RADIUS * M.SAFE_RADIUS
  local prud = M.character(f)
  local free = M.escort_free and M.escort_free(f) or 0
  local decision, why = D.gate({ blocked = res.blocked, max_d = res.max_d, goal_d = res.goal_d, deaths = deaths, far = far },
    { B = res.B, prudence = prud, escort_ok = free >= 2 })
  inc(t.stats.gate, decision)
  inc(t.stats.gate_why, decision .. ":" .. why)
  local a = astate(agent)
  a.escort = nil
  if decision == "wait" then
    label(agent, "attente", tick, t.stats)
    if Profiler.enabled() then
      log(string.format("[FO-IA3K] %s : PNJ %d attend (%s) : tache %s vers (%d, %d), morts de l'heure %d, danger %d (seuil %d)",
        tostring(f.key), agent.id, why, tostring(task.kind), math.floor(dest.x), math.floor(dest.y), deaths, res.max_d, res.B))
    end
    return false, "danger"
  end
  if decision == "escort" then
    -- Taille de l'escorte : 2, plus une par menace fixe connue à moins de 64 tuiles du trajet ou du but (6 au plus).
    local n = 2
    for _, th in ipairs(t.map.threats) do
      for _, q in ipairs(pts) do
        if d2(q, th) <= 64 * 64 then n = n + 1 break end
      end
    end
    if n > 6 then n = 6 end
    if M.request_escort and M.request_escort(f, agent, n, tick, task.key) then
      a.escort = true
      for i, s in ipairs(steps) do
        if s[1] == "goto" then table.insert(steps, i, { "wait", M.ESCORT_WAIT }) break end
      end
      label(agent, "escorte", tick, t.stats)
    elseif why ~= "loin" then
      label(agent, "attente", tick, t.stats)
      return false, "danger"
    end
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- Crochet : sens (regard, attaque subie, peur, réaction)
---------------------------------------------------------------------------------------------------
local function act(agent, f, t, a, action, why, ep, kind, tick)
  -- Déjà en retraite (demi-tour ou fuite de moins de 10 s) : on ne s'arrête pas de nouveau à chaque regard (le PNJ
  -- rentrerait par saccades, poursuivi) ; l'itinéraire du retour évite déjà ce qui est marqué.
  if (action == "back" or action == "flee") and a.ret_t and tick - a.ret_t < 600 then return false end
  inc(t.stats.actions, action)
  local key = Re.LABEL[action]
  if key then label(agent, key, tick, t.stats) end
  if Profiler.enabled() then
    local p = agent.entity.position
    log(string.format("[FO-IA3K] %s : PNJ %d %s (%s) : %s en (%d, %d) a %d tuiles, tache %s", tostring(f.key), agent.id, action,
      why, kind, math.floor(ep.x), math.floor(ep.y), math.floor(math.sqrt(d2(p, ep))),
      agent.task and tostring(agent.task.kind) or "aucune"))
  end
  if action == "detour" then
    if agent.nav then Nav.stop(agent, tick) end
    a.pts = nil
    FSM.set(M.MACHINE, agent, "step", tick)
    return true
  elseif action == "stop" then
    if agent.nav then Nav.stop(agent, tick) end
    a.pts = nil
    a.hold = tick + Re.STOP_TICKS
    return true
  elseif action == "engage" then
    if agent.nav then Nav.stop(agent, tick) end
    a.pts = nil
    a.hold = tick + M.ENGAGE_HOLD
    local e = agent.entity
    e.shooting_state = { state = defines.shooting.shooting_enemies, position = ep }
    return true
  elseif action == "back" or action == "flee" then
    if agent.nav then Nav.stop(agent, tick) end
    a.pts, a.final, a.hold = nil, nil, nil
    a.ret_t = tick
    if action == "flee" then
      a.refuge = refuge(f, agent.entity.position, ep)
      t.stats.refuges = t.stats.refuges + 1
      if M.on_alert and M.on_alert(f, ep, kind, tick) then t.stats.alerts = t.stats.alerts + 1 end
    end
    if agent.task then
      Worker.abort(agent, f, tick, action == "flee" and "fuite" or "danger")
    else
      agent.steps, agent.pc = { { "home" } }, 1
      FSM.set(M.MACHINE, agent, "step", tick)
    end
    return true
  end
  return false
end

function M.sense(agent, tick)
  if not M.enabled() then return false end
  local e = agent.entity
  if not (e and e.valid) then return false end
  local f = faction_of(agent)
  if not (f and f.hq_pos) then return false end
  local a = astate(agent)
  local t = M.team(f)
  if a.pending then M.flush_label(a, e, tick, t.stats) end
  local hp = math.floor(e.get_health_ratio() * 1000 + 0.5)
  local hurt = a.hp ~= nil and hp < a.hp - 5
  a.hp = hp
  -- Arrêt en cours (alerte, combat) : on attend sur place, l'autodéfense tire ; puis nouvel itinéraire. Une blessure
  -- pendant l'arrêt le rompt (la peur est rejugée tout de suite).
  if a.hold then
    if tick < a.hold and not hurt then return true end
    a.hold = nil
    a.pts = nil
    if agent.state == "walk" and not hurt then FSM.set(M.MACHINE, agent, "step", tick) return true end
  end
  local p = e.position
  -- Aller sans issue sûre (leg) : demi-tour.
  if a.abort_pending then
    a.abort_pending = nil
    if agent.task then return act(agent, f, t, a, "back", "sans-issue", p, "route", tick) end
  end
  local near_home = d2(p, f.hq_pos) <= M.HOME_SAFE * M.HOME_SAFE
  local walking = agent.state == "walk" and agent.nav == "moving"
  local prud, agr = M.character(f)
  -- Une menace fixe NOUVELLE vue par un camarade touche le reste de notre trajet : nouvel itinéraire (détour).
  if walking and a.pts and (a.mver or 0) < (t.mver or 0) then
    local hit = nil
    for _, nt in ipairs(t.new_threats or {}) do
      if nt.v > (a.mver or 0) and d_route(p, a, nt) <= nt.r + Re.MARGIN then hit = nt end
    end
    a.mver = t.mver
    if hit then
      t.stats.shared = (t.stats.shared or 0) + 1
      return act(agent, f, t, a, "detour", "camarade", hit, hit.k, tick)
    end
  end
  -- Une mort de l'équipe depuis le calcul de l'itinéraire : le reste du trajet est rejugé (C5).
  if walking and a.pts and (a.epoch or 0) < t.epoch and a.final then
    a.epoch = t.epoch
    t.stats.epoch_checks = t.stats.epoch_checks + 1
    local res = M.plan(f, agent, p, a.final, tick)
    local deaths = D.deaths_near(t.map, R.samples(p, res.pts, a.final, 8), D.HOUR_R, tick)
    if deaths >= 2 and not a.escort and agent.task then
      return act(agent, f, t, a, "back", "morts", a.final, "mort", tick)
    end
    a.pts = nil
    FSM.set(M.MACHINE, agent, "step", tick)
    return true
  end
  if near_home and not hurt then return false end
  local is_armed = armed(agent, a, tick)
  local fear = hp < Re.fear(prud)
  if not (walking or hurt or fear or not is_armed) then return false end
  -- Regard : autour d'un point LOOK_AHEAD tuiles devant (vers le point de passage courant), sinon autour du PNJ.
  local c = p
  if walking and agent.goal then
    local gx, gy = agent.goal.x - p.x, agent.goal.y - p.y
    local L = math.sqrt(gx * gx + gy * gy)
    if L > 1 then
      local k = math.min(Re.LOOK_AHEAD, L) / L
      c = { x = p.x + gx * k, y = p.y + gy * k }
    end
  end
  local r = Re.look_radius(prud)
  t.stats.looks = t.stats.looks + 1
  local enemy = e.surface.find_nearest_enemy({ position = c, max_distance = r, force = e.force })
  local nd = enemy and math.sqrt(d2(c, enemy.position)) or nil
  t.stats.forgot = t.stats.forgot + D.forget_unseen(t.map, c.x, c.y, r, nd)
  if hurt then D.mark_attack(t.map, p.x, p.y, tick) end
  if not enemy then return false end
  local ep = enemy.position
  local kind, range = M.classify(enemy)
  if D.mark_seen(t.map, ep.x, ep.y, kind, range, tick) and (D.KINDS[kind] or D.KINDS.unit).fixed then
    -- Menace fixe nouvelle : les camarades en marche rejugent leur trajet (8 dernières gardées).
    t.mver = (t.mver or 0) + 1
    t.new_threats = t.new_threats or {}
    t.new_threats[#t.new_threats + 1] = { v = t.mver, x = ep.x, y = ep.y, r = range or D.KINDS[kind].r, k = kind }
    while #t.new_threats > 8 do table.remove(t.new_threats, 1) end
  end
  inc(t.stats.seen, kind)
  local dist = math.sqrt(d2(p, ep))
  local K = D.KINDS[kind] or D.KINDS.unit
  local rr = range or K.r
  local on_route = walking and d_route(p, a, ep) <= rr + Re.MARGIN
  local s = e.surface
  local enemies, allies = 1, 0
  if not K.fixed then
    enemies = s.count_entities_filtered({ position = ep, radius = 16, force = enemy.force, type = { "unit", "character" } })
    allies = math.max(0, s.count_entities_filtered({ position = p, radius = M.ALLY_R, force = e.force,
      type = { "unit", "character" } }) - 1)
  end
  local action, why = Re.decide({ kind = kind, range = range, dist = dist, on_route = on_route, hp = hp, armed = is_armed,
    enemies = enemies, allies = allies, walking = walking, prudence = prud, agressivite = agr })
  if action == "none" then return false end
  -- Pas de demi-tour ni de fuite pour un PNJ déjà en route vers le QG sans tâche : il rentre déjà (refuge seulement).
  return act(agent, f, t, a, action, why, ep, kind, tick)
end

---------------------------------------------------------------------------------------------------
-- Morts : la carte de l'équipe les retient (C5)
---------------------------------------------------------------------------------------------------
Registry.on_removed(function(agent)
  local st = S()
  if not st then return end
  local a = st.agents[agent.id]
  if a and a.label and rendering.is_valid(a.label) then rendering.destroy(a.label) end
  if a and a.label2 and rendering.is_valid(a.label2) then rendering.destroy(a.label2) end
  st.agents[agent.id] = nil
  if not agent.faction or not agent.death_pos then return end
  local f = State.faction(agent.faction)
  if not f then return end
  local t = M.team(f)
  -- Morts tuées par un ennemi seulement (« cause/force:dégâts »).
  if agent.death_cause and agent.death_cause:find("/", 1, true) then
    D.mark_death(t.map, agent.death_pos.x, agent.death_pos.y, game.tick)
    t.epoch = t.epoch + 1
    t.stats.deaths = t.stats.deaths + 1
    log(string.format("[FO-IA3K] %s : mort marquee en (%d, %d) (%s), %d mort(s) de l'heure a moins de %d tuiles",
      tostring(f.key), math.floor(agent.death_pos.x), math.floor(agent.death_pos.y), agent.death_cause,
      D.deaths_near(t.map, { agent.death_pos }, D.HOUR_R, game.tick), D.HOUR_R))
  end
  if t.escorts then t.escorts[agent.id] = nil end
end)

-- Ménage périodique des cartes (cases éteintes, menaces oubliées, morts hors de l'heure).
Events.on_nth_tick(M.PRUNE_PERIOD, function(e)
  local st = S()
  if not st then return end
  for _, k in ipairs(State.sorted_keys(st.teams)) do D.prune(st.teams[k].map, e.tick) end
end)

---------------------------------------------------------------------------------------------------
-- Interface distante « fo-ia3k » (bancs ; le mod de test n'a pas accès à `global` de ce mod)
--   status(clé)                       -> { enabled, epoch, stats, summary, escorts } ou nil
--   agents(clé)                       -> { { id, x, y, state, task, hp, hold, refuge, wps, wp_i, final }, ... }
--   trip(clé, id, x, y[, attente])    -> numéro de tournée (PNJ sans tâche seulement) ou false        [bancs]
--   hold(clé, vrai|faux)              -> vrai : la porte refuse toute tâche du cerveau (tournées seules) [bancs]
--   set_character(clé, prudence, agressivite) -> vrai (nil, nil : caractère de la faction)           [bancs]
--   mark(clé, x, y, genre, portée), death(clé, x, y) -> vrai                                          [bancs]
--   danger(clé)                       -> { threats, deaths, summary }
---------------------------------------------------------------------------------------------------
local function team_by_key(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end
M.team_by_key = team_by_key

local function copy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = copy(x) end
  return out
end

remote.add_interface("fo-ia3k", {
  status = function(key)
    local f = team_by_key(key)
    if not f then return nil end
    local t = M.team(f)
    local n = 0
    for _ in pairs(t.escorts or {}) do n = n + 1 end
    return { enabled = M.enabled(), epoch = t.epoch, stats = copy(t.stats), summary = D.summary(t.map, game.tick),
      escorts = n, soldiers = copy(t.soldiers) }
  end,
  agents = function(key)
    local f = team_by_key(key)
    if not f then return nil end
    local out = {}
    for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
      local ag = Registry.get(id)
      if ag and ag.entity.valid then
        local a = S().agents[id] or {}
        local p = ag.entity.position
        out[#out + 1] = { id = id, x = p.x, y = p.y, state = ag.state, task = ag.task and ag.task.kind or nil,
          trip = ag.task and ag.task.trip or nil, hp = math.floor(ag.entity.get_health_ratio() * 1000 + 0.5),
          hold = a.hold, refuge = copy(a.refuge), wps = a.pts and #a.pts or 0, wp_i = a.i, final = copy(a.final),
          label = a.label_key, label_t = a.label_t, pts = copy(a.pts), side_o = a.side_o, side_h = a.side_h }
      end
    end
    return out
  end,
  trip = function(key, id, x, y, wait)
    local f = team_by_key(key)
    local ag = Registry.get(id)
    if not (f and ag and ag.faction == f.id and ag.entity.valid) or ag.task then return false end
    local t = M.team(f)
    t.trips = (t.trips or 0) + 1
    ag.task = { key = "ia3k-trip:" .. t.trips, kind = "garrison", post = "ia3k", trip = t.trips, claimed = game.tick }
    ag.steps = { { "goto", { x = x, y = y }, 3 }, { "wait", wait or 60 }, { "home" } }
    ag.pc, ag.failed = 1, nil
    FSM.set(M.MACHINE, ag, "step", game.tick)
    return t.trips
  end,
  hold = function(key, on)
    local f = team_by_key(key)
    if not f then return false end
    M.team(f).hold = on and true or nil
    return true
  end,
  set_character = function(key, prudence, agressivite)
    local f = team_by_key(key)
    if not f then return false end
    local t = M.team(f)
    if prudence == nil and agressivite == nil then t.char = nil
    else t.char = { prudence = prudence or 1000, agressivite = agressivite or 1000 } end
    return true
  end,
  mark = function(key, x, y, kind, range)
    local f = team_by_key(key)
    if not f then return false end
    D.mark_seen(M.team(f).map, x, y, kind or "worm", range, game.tick)
    return true
  end,
  death = function(key, x, y)
    local f = team_by_key(key)
    if not f then return false end
    local t = M.team(f)
    D.mark_death(t.map, x, y, game.tick)
    t.epoch = t.epoch + 1
    return true
  end,
  danger = function(key)
    local f = team_by_key(key)
    if not f then return nil end
    local t = M.team(f)
    return { threats = copy(t.map.threats), deaths = copy(t.map.deaths), summary = D.summary(t.map, game.tick) }
  end,
})

Worker.hook = M
return M
