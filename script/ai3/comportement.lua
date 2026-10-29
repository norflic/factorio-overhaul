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
    agents[id] = { final, pts, i, epoch, refuge, hold, hold_stop, hp, armed, armed_t, label, label_key, label_t, escort, tour,
                   backs, back_t, ret_t, flee_t, flee_ep, look_t, shelter_t }
  Flux : Tr.new_stream(graine, 470 + numéro de l'équipe) (sels 470 à 479 : IA3-k ; 479 = votre équipe).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local FSM = require("script.core.fsm")
local Profiler = require("script.core.profiler")
local Trace = require("script.core.trace")
local Registry = require("script.companion.registry")
local Nav = require("script.agents.nav")
local State = require("script.faction.state")
local Character = require("script.faction.character")
local Worker = require("script.team.worker")
local Harvest = require("script.team.harvest") -- lot KIT : entités qui donnent un objet miné (minerai, arbres)
local Survie = require("script.team.survie") -- lot SURVIE-PENURIE : mode survie d'une équipe en pénurie (porte assouplie pour les tâches de ressources)
local Sv = require("shared.team.survie")
local D = require("shared.ai3.danger")
local R = require("shared.ai3.route")
local Re = require("shared.ai3.reaction")
local Tr = require("shared.faction.traits")

local M = {}

M.SETTING = "fo-war-ia3-comportement"
M.SALT = 470
M.HOME_SAFE = 32        -- pas de regard à moins de 32 tuiles du QG (il est défendu)
M.HOME_DEATH_R = 16     -- une mort à moins de 16 tuiles du QG (cases d'attente) : raid sur le QG, sans effet sur la carte
                        -- (D.mark_death) ; 48 classait « QG » des morts au ver à 36-43 tuiles (final-0159125 Écarlate 123456789)
M.WP_RADIUS = 2         -- rayon d'arrivée d'un point de passage
M.WP_REACH = 4          -- point de passage atteint à 4 tuiles (8 coupait les virages : banc route-20261020-4e6303a)
M.GROUP_R = 24          -- un regard qui voit un ennemi marque aussi les autres ennemis à moins de 24 tuiles de lui
M.WP_CHAIN = 12         -- à 12 tuiles du point de passage visé, le PNJ vise déjà le suivant (tronçons enchaînés)
M.LABEL_TTL = 150       -- 2,5 s (D1 : au moins 2 s)
M.LABEL_GAP = 120       -- même étiquette redessinée au plus toutes les 2 s
M.ESCORT_WAIT = 900     -- attente de l'escorte au QG, au plus
M.SAFE_RADIUS = 160     -- au-delà : « loin » (C6)
M.ALLY_R = 16
M.ENGAGE_HOLD = 120
M.PRUNE_PERIOD = 3600
-- « Armé » relu à chaque pensée (60 ticks) : relu toutes les 600 ticks, un PNJ qui venait de vider ses chargeurs fuyait
-- jusqu'à 9 s trop tard (final-050-2c49ceb peur-20261020 : sans munitions, 2 fuites sur 4 après 541 ticks ; C3 : <= 1 s).
M.ARMED_TTL = 60
M.RETARGET_PERIOD = 600 -- un minage refusé cherche un autre site au plus toutes les 10 s (coût : une recherche de tuiles)
-- Lot DEFENSE-FACTIONS D6 (audit tourelles-danger du 29/10, « boucle Trop dangereux » d'Émeraude ; AUCUN seuil de la porte ne change) :
M.PASS_TICKS = 18000    -- 5 min : une destination dont l'escalade a été accordée garde son PASSE-DROIT (au lieu de repartir à 0 refus : 4 refus de
                        -- 30 s, un départ, puis encore 4 refus, à chaque tâche), tant que son but n'est pas à portée d'une menace
M.LABEL_AFTER = 2       -- l'étiquette « Trop dangereux » ne s'affiche qu'au 2e refus de suite pour la même destination (sauf morts)
M.REPORT_EVERY = 18000  -- 5 min : une ligne de bilan de la porte par équipe (M.gate_report), sans profileur
M.MACHINE = "worker"

local COLORS = {
  alerte = { r = 1, g = 0.85, b = 0.1 }, detour = { r = 1, g = 0.6, b = 0.15 }, ["demi-tour"] = { r = 1, g = 0.45, b = 0.1 },
  fuite = { r = 1, g = 0.25, b = 0.25 }, combat = { r = 0.85, g = 0.35, b = 1 }, escorte = { r = 0.35, g = 0.7, b = 1 },
  attente = { r = 0.8, g = 0.8, b = 0.8 }, patrouille = { r = 0.45, g = 1, b = 0.45 }, garde = { r = 0.6, g = 0.9, b = 0.6 },
  nettoyage = { r = 1, g = 0.4, b = 0.8 }, abri = { r = 0.9, g = 0.9, b = 0.4 }, defense = { r = 1, g = 0.5, b = 0.5 },
  chasse = { r = 1, g = 0.3, b = 0.6 },
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
local speed_cache = {} -- [nom de prototype] = vitesse d'une unité (idem)

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

--- Vitesse d'une unité ennemie (prototype) ; nil pour les autres (personnage, tourelle…).
function M.enemy_speed(e)
  if e.type ~= "unit" then return nil end
  local name = e.name
  local v = speed_cache[name]
  if v == nil then
    v = e.prototype.speed or false
    speed_cache[name] = v
  end
  return v or nil
end

--- Tourelles amies debout autour du QG (à moins de Re.RALLY_R tuiles du coffre), en positions { x, y } : celles de l'équipe
-- ET celles que son joueur a posées (un scan de la zone : appelé seulement quand le QG est menacé ou qu'un PNJ y est blessé).
local function qg_turret_points(f)
  local out = {}
  local surface = f.hq and f.hq.valid and f.hq.surface
  if not surface then return out end
  local home = f.home_spot or f.hq_pos
  local list = surface.find_entities_filtered({ position = home, radius = Re.RALLY_R, force = f.force,
    type = { "ammo-turret", "electric-turret", "fluid-turret" } })
  for _, t in ipairs(list) do out[#out + 1] = { x = t.position.x, y = t.position.y, n = t.unit_number or 0 } end
  table.sort(out, function(a, b) if a.n ~= b.n then return a.n < b.n end if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  return out
end

--- Point de ralliement du QG (derrière ses tourelles, côté coffre) ; nil sans tourelle du QG.
function M.rally(f)
  return Re.rally_point(qg_turret_points(f), f.home_spot or f.hq_pos)
end

local weight_cache = {} -- [nom de prototype] = poids (prototypes : identiques chez tous les pairs)
--- Poids d'un ennemi mobile dans le rapport de force (shared/ai3/reaction.lua : `enemies`).
function M.weight(u)
  if u.type == "character" then return 1 end
  local w = weight_cache[u.name]
  if not w then
    local mh = u.prototype.max_health or 75
    w = mh / 75
    if w < 0.2 then w = 0.2 end
    weight_cache[u.name] = w
  end
  return w
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

--- Le personnage a-t-il de quoi tirer ? Lu dans SON inventaire de munitions (aucun nom d'objet : une munition chargée,
--- quelle qu'elle soit).
function M.has_ammo(e)
  local inv = e.get_inventory(defines.inventory.character_ammo)
  return inv ~= nil and not inv.is_empty()
end

local function armed(agent, a, tick)
  if a.armed == nil or tick - (a.armed_t or -1e9) >= M.ARMED_TTL then
    local e = agent.entity
    a.armed = M.has_ammo(e)
    a.armed_t = tick
  end
  return a.armed
end

--- Refuge le plus proche : une tourelle amie (pas du côté de la menace), sinon la case du QG.
local function refuge(f, p, ep, range)
  local best, bd = nil, nil
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t and t.valid then
      local tp = t.position
      -- Ni à 12 tuiles de l'ennemi, ni derrière lui : y courir, c'est courir sur lui (armée en marche sur le QG, int-1).
      if d2(tp, ep) >= 144 and not Re.on_the_way(p, tp, ep) then
        local dd = d2(tp, p)
        if not bd or dd < bd then best, bd = tp, dd end
      end
    end
  end
  local home = f.home_spot or f.hq_pos
  if not best and d2(home, ep) < 32 * 32 then
    -- Pas de tourelle et c'est le QG qui est menacé : s'éloigner de la menace (24 tuiles à l'opposé), pas y courir.
    local vx, vy = p.x - ep.x, p.y - ep.y
    local L = math.sqrt(vx * vx + vy * vy)
    if L < 1 then vx, vy, L = 1, 0, 1 end
    return { x = p.x + 24 * vx / L, y = p.y + 24 * vy / L }
  end
  if not best or d2(home, p) <= bd then
    -- Le QG est du côté de l'ennemi : y courir, c'est courir sur lui (fusion-60, PNJ 7 : tué en rentrant à 232 tuiles) ;
    -- on s'éloigne d'abord, l'itinéraire de retour contourne ensuite la meute marquée.
    local aw = Re.away_point(p, home, ep, range)
    if aw then return aw end
    return { x = home.x, y = home.y }
  end
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

--- Itinéraire de p à goal pour ce PNJ. opts = { draw = bool (variation de tournée), B = seuil forcé, same = résultat d'un
--- appel précédent du MÊME tick pour les mêmes p et goal (son champ est repris : la carte n'a pas changé entre les deux) }.
function M.plan(f, agent, p, goal, tick, opts)
  opts = opts or {}
  local t = M.team(f)
  local prud = M.character(f)
  local B = opts.B or D.block(prud)
  Profiler.fstart("plan:field")
  local field, n = {}, 0
  if opts.same then
    field, n = opts.same.field, opts.same.n or 0
  elseif marks_near(t.map, p, goal, tick) then
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
  Profiler.fstop("plan:field")
  Profiler.fstart("plan:route")
  local res = R.plan(p, goal, { field = field, n = n, B = B, seed = seed, draw = draw, side = opts.side })
  Profiler.fstop("plan:route")
  Profiler.fstart("plan:exact")
  if res.astar then Trace.log("ia3k", "astar", res.expand) end -- attribution des pics (tools/autotest/analyze.py)
  res.B = B
  res.field, res.n = field, n
  -- Profil GÉOMÉTRIQUE (distance réelle aux menaces, D.danger_exact) le long de l'itinéraire, 6 premières tuiles exclues
  -- (le PNJ peut déjà être près d'un danger) : c'est lui que jugent la porte et le choix de l'itinéraire de secours ; les
  -- cases de 16 tuiles (A*) surestiment (un avant-poste à 35-55 tuiles d'un ver était refusé).
  -- Lot PERF : D.exact_prep / D.exact_at (poids décrus calculés une fois, menaces hors du rectangle des échantillons
  -- écartées) : mêmes valeurs que D.danger_exact point par point (tests/perf_test.lua).
  local t2 = t.map
  local mx = 0
  local qs = R.samples(p, res.pts, goal, R.SAMPLE)
  local x0, y0, x1, y1 = goal.x, goal.y, goal.x, goal.y
  for _, q in ipairs(qs) do
    if q.x < x0 then x0 = q.x elseif q.x > x1 then x1 = q.x end
    if q.y < y0 then y0 = q.y elseif q.y > y1 then y1 = q.y end
  end
  local prep = D.exact_prep(t2, tick, x0, y0, x1, y1)
  for _, q in ipairs(qs) do
    if d2(q, p) > 36 then
      local v = D.exact_at(prep, q.x, q.y)
      if v > mx then mx = v end
    end
  end
  res.exact_max = mx
  res.exact_goal = D.exact_at(prep, goal.x, goal.y)
  res.threat_goal = D.exact_at(prep, goal.x, goal.y, true) -- lot INTEG-DEFENSE : le même sans les morts de PNJ (menaces seules)
  Profiler.fstop("plan:exact")
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
    a.urep = nil -- arrêts et détours devant des unités : comptés par destination
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
      -- Le chemin qui minimise le danger : pris s'il reste hors de PORTÉE réelle des menaces (profil géométrique sous le
      -- seuil), ou faute de mieux pour rentrer au QG, passer escorté ou avec le risque accepté.
      local res2 = M.plan(f, agent, p, pos, tick, { B = 1e9, same = res })
      if home or a.escort or a.risk or res2.exact_max < res.B then
        res = res2
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
    Profiler.fstart("leg:wp")
    local q = e.surface.find_non_colliding_position(e.name, w, 8, 1)
    Profiler.fstop("leg:wp")
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

--- Autre tuile de minerai hors danger pour un minage (C5 « change de site ») : ou nil.
function M.retarget_mine(f, t, task, surface, tick, B)
  if not (task.resource and f.hq_pos) then return nil end
  local names = Harvest.names_for(f, task.resource, task.trees)
  if #names == 0 then return nil end -- lot KIT : rien à récolter pour cet objet
  local res = surface.find_entities_filtered({ position = f.hq_pos, radius = task.radius or 96, name = names, limit = 256 })
  table.sort(res, function(x, y)
    local dx, dy = d2(x.position, f.hq_pos), d2(y.position, f.hq_pos)
    if dx ~= dy then return dx < dy end
    if x.position.x ~= y.position.x then return x.position.x < y.position.x end
    return x.position.y < y.position.y
  end)
  local field = D.field(t.map, tick)
  local stride = math.max(1, math.floor(#res / 40))
  for i = 1, #res, stride do
    local p = res[i].position
    if (field[D.key(D.cell(p.x), D.cell(p.y))] or 0) * 4 < B and D.deaths_near(t.map, { p }, D.HOUR_R, tick) == 0 then
      local busy = surface.count_entities_filtered({ area = { { p.x - 0.5, p.y - 0.5 }, { p.x + 0.5, p.y + 0.5 } },
        type = Harvest.free_types(task.resource, f, task.trees), invert = true, limit = 1 })
      if busy == 0 and Harvest.foreign_resource(surface, p, task.resource, f) then busy = 1 end -- lot KIT : ressource étrangère sur la tuile
      if busy == 0 then return { x = p.x, y = p.y } end
    end
  end
  return nil
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
  -- Bloqué au sens des cases : le chemin qui minimise le danger est-il hors de portée réelle des menaces ?
  if res.blocked then
    local res2 = M.plan(f, agent, p, dest, tick, { B = 1e9, same = res })
    if res2.exact_max < res.B then res2.B, res2.blocked = res.B, false res = res2 end
  end
  Profiler.fstart("gate:post")
  local pts = R.samples(p, res.pts, dest, 8)
  local deaths = D.deaths_near(t.map, pts, D.HOUR_R, tick)
  local far = d2(f.hq_pos, dest) > M.SAFE_RADIUS * M.SAFE_RADIUS
  local prud = M.character(f)
  local free = M.escort_free and M.escort_free(f) or 0
  local ginfo = { blocked = res.blocked, max_d = res.exact_max, goal_d = res.exact_goal, deaths = deaths, far = far }
  local sv_deaths = Survie.gate_deaths(f, task.kind) -- lot SURVIE-PENURIE : mode survie ET tâche de ressources (nil sinon)
  local decision, why = D.gate(ginfo, { B = res.B, prudence = prud, escort_ok = free >= 2, survie_deaths = sv_deaths })
  if sv_deaths then
    -- Même entrée sans le mode : la décision ordinaire, pour compter ce que le mode a changé (journal [FO-SURVIE]).
    local d0, w0 = D.gate(ginfo, { B = res.B, prudence = prud, escort_ok = free >= 2 })
    Survie.note_gate(f, tick, d0, w0, decision, why)
  end
  Profiler.fstop("gate:post")
  local a = astate(agent)
  a.escort, a.risk = nil, nil
  -- C5 « ou change de site » : un MINAGE refusé cherche une autre tuile de son minerai hors de la zone marquée (même ordre
  -- que le programme : la plus proche du QG, au plus 40 tuiles contrôlées), puis la porte rejuge.
  -- Lot IA3-k sur 0.5.0 : réessayé au plus toutes les RETARGET_PERIOD ticks pour la même tâche (le tableau garde ses
  -- tâches) ; rien près du QG : gisement CONNU et sûr plus loin (Worker.far_mine, carte de connaissance d'IA3-f, qui
  -- demande une exploration sinon) ; la porte rejuge le nouveau but (final-050-2c49ceb memoire-20261020 : Écarlate sans
  -- soldats, 1 064 attentes, fer livré 400 contre 6 976 au témoin).
  if decision == "wait" and task.kind == "mine"
    and (not task.ia3k_retarget or tick - task.ia3k_retarget >= M.RETARGET_PERIOD) then
    task.ia3k_retarget = tick
    local q = M.retarget_mine(f, t, task, e.surface, tick, res.B)
    if not q and Worker.far_mine then q = Worker.far_mine(f, task, e.surface, tick) end
    if q then
      for _, s in ipairs(steps) do
        if s[1] == "goto" then s[2] = { x = q.x, y = q.y } break end
      end
      task.target = { x = q.x, y = q.y }
      t.stats.retarget = (t.stats.retarget or 0) + 1
      return M.gate(f, agent, task, steps, tick)
    end
  end
  -- ESCALADE (IA3_CERVEAU §4.2 : « attendre n'est pas une fin ») : une destination refusée pour une menace VUE (pas pour
  -- une mort) part quand même après W attentes (2 audacieux à 6 prudent) ; le PNJ garde ses réflexes (demi-tour à portée).
  -- La menace qui bloque est signalée aux soldats (nettoyage quel que soit le caractère, script/ai3/soldats.lua).
  local dk = D.key(D.cell(dest.x), D.cell(dest.y))
  t.waits = t.waits or {}
  local refused_n = nil -- refus de suite pour cette destination (lot DEFENSE-FACTIONS D6 : étiquette au 2e)
  -- Lot INTEG-DEFENSE D-B : une tâche de DÉFENSE (poser ou ravitailler les tourelles de l'équipe : « fortify », « refill ») vers un but
  -- sans menace CONNUE à portée (menaces fixes ou mobiles ; les MORTS de PNJ n'en sont pas) n'est pas refusée indéfiniment pour des
  -- morts : les pièces tombent là où l'on meurt, et la porte bloquait alors le renfort une heure entière (D.HOUR). L'escalade
  -- ci-dessous la laisse partir après W attentes, risque accepté (les réflexes du PNJ restent). Les autres tâches gardent la règle
  -- d'IA3-k (la mort reste un refus sans issue) ; un but à portée d'une menace connue reste refusé pour tous.
  local defense_free = (task.kind == "fortify" or task.kind == "refill") and (res.threat_goal or res.exact_goal) < res.B
  local goal_free = res.exact_goal < res.B or defense_free
  if decision == "wait" and ((why ~= "morts" and why ~= "mort") or defense_free) then
    local w = t.waits[dk]
    if not w then
      w = { n = 0 }
      -- Au plus 64 destinations suivies : la plus ancienne part (clés triées : aucun ordre de pairs).
      local keys = {}
      for k in pairs(t.waits) do keys[#keys + 1] = k end
      if #keys >= 64 then
        table.sort(keys)
        local old = keys[1]
        for _, k in ipairs(keys) do if t.waits[k].t < t.waits[old].t then old = k end end
        t.waits[old] = nil
      end
      t.waits[dk] = w
    end
    w.n, w.t = w.n + 1, tick
    for _, th in ipairs(t.map.threats) do
      for _, q in ipairs(pts) do
        if d2(q, th) <= (th.r + 16) * (th.r + 16) then th.b = tick break end
      end
    end
    local W = Sv.escalade_w(math.max(2, math.min(6, math.floor(4 * prud / 1000))), sv_deaths ~= nil) -- lot SURVIE-PENURIE : escalade dès 2 refus
    refused_n = w.n
    -- Jamais d'escalade vers un BUT à portée réelle d'une menace connue (D.danger_exact au but >= seuil) : le PNJ y
    -- mourrait ou ferait demi-tour à portée ; seuls un nettoyage ou un autre site le débloquent (final-3958412
    -- memoire-123456789 : PNJ tué par un ver après une escalade vers un but à 4 150 de danger, seuil 650).
    if w.pass and tick < w.pass and goal_free then
      -- Lot DEFENSE-FACTIONS D6 : passe-droit de M.PASS_TICKS après une escalade accordée (même condition qu'elle : but hors de portée)
      decision, why = "go", "passe-droit"
      a.risk = true
      w.n = 0 -- (le cycle de refus repart de zéro à l'expiration du passe-droit)
      refused_n = nil
      t.stats.passe_droit = (t.stats.passe_droit or 0) + 1
    elseif w.n > W and goal_free then
      if defense_free and (why == "morts" or why == "mort" or res.exact_goal >= res.B) then t.stats.escalade_defense = (t.stats.escalade_defense or 0) + 1 end -- lu par gate_report
      decision, why = "go", "escalade"
      a.risk = true
      w.n = 0
      w.pass = tick + M.PASS_TICKS
      refused_n = nil
      t.stats.escalade = (t.stats.escalade or 0) + 1
    end
  elseif decision ~= "wait" then
    -- (le passe-droit survit à un « go » ordinaire tant qu'il dure : une destination qui redevient dangereuse ne repart pas à zéro)
    local w = t.waits[dk]
    if w and w.pass and tick < w.pass then w.n = 0 else t.waits[dk] = nil end
  end
  inc(t.stats.gate, decision)
  inc(t.stats.gate_why, decision .. ":" .. why)
  if decision == "wait" then Survie.note_wait(f, tick) end -- lot SURVIE-PENURIE : un refus de plus (paralysie, shared/team/survie.lua)
  if decision == "wait" then
    -- Lot DEFENSE-FACTIONS D6 : « Trop dangereux » seulement au 2e refus de suite (ou si des morts le disent) ; le premier refus ne réécrit pas
    -- l'étiquette du PNJ. La décision, elle, ne change pas.
    if refused_n == nil or refused_n >= M.LABEL_AFTER then label(agent, "attente", tick, t.stats) end
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
      -- Danger connu : le PNJ attend son escorte au QG (au plus ESCORT_WAIT) ; simple éloignement (C6) : il part, les
      -- soldats le rattrapent (pas d'attente qui ralentirait chaque tournée lointaine).
      if why ~= "loin" then
        for i, s in ipairs(steps) do
          if s[1] == "goto" then table.insert(steps, i, { "wait", M.ESCORT_WAIT }) break end
        end
      end
      label(agent, "escorte", tick, t.stats)
    elseif why ~= "loin" then
      label(agent, "attente", tick, t.stats)
      return false, "danger"
    end
  end
  return true
end

--- Lot DEFENSE-FACTIONS D1 : bilan de la porte, SANS profileur (le journal « PNJ attend » exigeait Profiler.enabled() et la durée de la boucle
--- « Trop dangereux » n'était pas mesurable). Une ligne [FO-IA3K] au plus toutes les M.REPORT_EVERY ticks par équipe : décisions de la porte et
--- motifs (cumul depuis le début de la partie, puis les 5 dernières minutes), escalades, passe-droits. Lecture seule ; appelé par
--- script/team/defense_log.lua. État : t.report_t, t.report_prev (nombres), créés ici en événement.
function M.gate_report(f, tick)
  if not M.enabled() then return end
  local t = M.team(f)
  if t.report_t and tick - t.report_t < M.REPORT_EVERY then return end
  local prev = t.report_prev or {}
  local now = {}
  local keys = {}
  for k, n in pairs(t.stats.gate_why or {}) do keys[#keys + 1] = k now[k] = n end
  table.sort(keys)
  local first = t.report_t == nil
  t.report_t = tick
  t.report_prev = now
  if #keys == 0 then return end
  local total, d_total, parts = 0, 0, {}
  for _, k in ipairs(keys) do
    local d = now[k] - (prev[k] or 0)
    total, d_total = total + now[k], d_total + d
    parts[#parts + 1] = string.format("%s %d (+%d)", k, now[k], d)
  end
  log(string.format("[FO-IA3K] %s : bilan de la porte a %.1f min%s : %d decisions (+%d en 5 min) {%s} ; escalades %d (dont defense malgre des morts %d), passe-droits %d, reciblages %d, morts marquees %d",
    tostring(f.key), tick / 3600, first and " (premier)" or "", total, d_total, table.concat(parts, ", "), t.stats.escalade or 0,
    t.stats.escalade_defense or 0, t.stats.passe_droit or 0, t.stats.retarget or 0, t.stats.deaths or 0))
end

---------------------------------------------------------------------------------------------------
-- Crochet : sens (regard, attaque subie, peur, réaction)
---------------------------------------------------------------------------------------------------
--- Le PNJ vient d'être arrêté (Nav.stop) et son état est « step » : sans cet appel, il restait immobile jusqu'à sa
-- prochaine pensée (période 60 ticks : 0 à 60 ticks, soit jusqu'à 7 tuiles gagnées par un soldat et 12 par un
-- déchiqueteur) avant de repartir. La pensée de l'état « step » est donc rejouée tout de suite ; `a.now` coupe le regard
-- de cette pensée imbriquée (pas de réaction dans une réaction).
local function resume_now(agent, a, tick)
  a.now = true
  FSM.think(M.MACHINE, agent, tick)
  a.now = nil
end

local function act(agent, f, t, a, action, why, ep, kind, tick, range, refuge_to)
  -- Déjà en retraite (demi-tour ou fuite de moins de 10 s) : on ne s'arrête pas de nouveau à chaque regard (le PNJ
  -- rentrerait par saccades, poursuivi) ; l'itinéraire du retour évite déjà ce qui est marqué. Une FUITE n'est jamais
  -- retardée par un demi-tour récent (survie avant tâche) : elle n'est évitée que si elle est déjà engagée vers le même
  -- danger (refuge en route, ennemi à moins de 8 tuiles de l'endroit qui l'a lancée).
  if action == "back" and a.ret_t and tick - a.ret_t < 600 then return false end
  if action == "flee" and agent.nav == "moving" and a.refuge and a.flee_ep and a.flee_t and tick - a.flee_t < 600
    and d2(a.flee_ep, ep) <= 64 then return false end
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
    resume_now(agent, a, tick)
    return true
  elseif action == "stop" then
    if agent.nav then Nav.stop(agent, tick) end
    a.pts = nil
    a.hold = tick + Re.STOP_TICKS
    a.hold_stop = true
    return true
  elseif action == "engage" then
    if agent.nav then Nav.stop(agent, tick) end
    a.pts = nil
    a.hold = tick + M.ENGAGE_HOLD
    a.hold_stop = nil
    local e = agent.entity
    e.shooting_state = { state = defines.shooting.shooting_enemies, position = ep }
    return true
  elseif action == "back" or action == "flee" then
    if agent.nav then Nav.stop(agent, tick) end
    a.pts, a.final, a.hold, a.hold_stop = nil, nil, nil, nil
    a.ret_t = tick
    if action == "back" and (kind == "unit" or kind == "character") then
      -- Mémoire des demi-tours devant des unités : le suivant, dans Re.BACK_MEMORY ticks, devient une fuite.
      if a.back_t and tick - a.back_t > Re.BACK_MEMORY then a.backs = 0 end
      a.backs, a.back_t = (a.backs or 0) + 1, tick
    end
    if action == "flee" then
      a.refuge = refuge_to or refuge(f, agent.entity.position, ep, range)
      a.flee_t, a.flee_ep = tick, { x = ep.x, y = ep.y }
      t.stats.refuges = t.stats.refuges + 1
      -- Votre équipe : un PNJ qui fuit prévient les autres AVANT la première perte (lieu de la menace) ; hors du QG, qui
      -- est défendu (même règle que le rappel après une mort : Worker.SAFE_HOME).
      if f.is_player and f.hq_pos and d2(ep, f.hq_pos) > Worker.SAFE_HOME * Worker.SAFE_HOME then
        local n = Worker.recall_near(f, ep, nil, tick, agent)
        if n > 0 then
          t.stats.flee_recalls = (t.stats.flee_recalls or 0) + n
          if Profiler.enabled() then
            log(string.format("[FO-IA3K] %s : PNJ %d fuit (%s) : %d coequipier(s) rappele(s) a moins de %d tuiles de la menace", tostring(f.key),
              agent.id, why, n, Worker.RECALL_RADIUS))
          end
        end
      end
      if M.on_alert and M.on_alert(f, ep, kind, tick) then t.stats.alerts = t.stats.alerts + 1 end
    end
    if agent.task then
      Worker.abort(agent, f, tick, action == "flee" and "fuite" or "danger")
    else
      agent.steps, agent.pc = { { "home" } }, 1
      FSM.set(M.MACHINE, agent, "step", tick)
    end
    resume_now(agent, a, tick)
    return true
  end
  return false
end

--- Pendant un arrêt : une unité mobile est-elle à portée + marge (Re.breach) ? Un regard à portée de vue (rayon du regard),
-- une classification : coût d'un seul find_nearest_enemy par pensée d'un PNJ en arrêt.
function M.hold_breached(f, e)
  local prud = M.character(f)
  local p = e.position
  local enemy = e.surface.find_nearest_enemy({ position = p, max_distance = Re.look_radius(prud), force = e.force })
  if not enemy then return false end
  local kind, range = M.classify(enemy)
  return Re.breach(kind, math.sqrt(d2(p, enemy.position)), range)
end

function M.sense(agent, tick)
  if not M.enabled() then return false end
  local e = agent.entity
  if not (e and e.valid) then return false end
  local f = faction_of(agent)
  if not (f and f.hq_pos) then return false end
  local a = astate(agent)
  if a.now then return false end -- pensée rejouée par resume_now : pas de réaction dans une réaction
  local t = M.team(f)
  if a.pending then M.flush_label(a, e, tick, t.stats) end
  local hp = math.floor(e.get_health_ratio() * 1000 + 0.5)
  local hurt = a.hp ~= nil and hp < a.hp - 5
  a.hp = hp
  -- Arrêt en cours (alerte, combat) : on attend sur place, l'autodéfense tire ; puis nouvel itinéraire. Une blessure
  -- pendant l'arrêt le rompt (la peur est rejugée tout de suite).
  local breach = false
  if a.hold then
    if tick < a.hold and not hurt then
      -- Un ARRÊT (alerte) garde les yeux ouverts : des unités qui franchissent portée + marge le rompent (le regard
      -- ci-dessous juge alors, PNJ immobile : fuite). Le combat sur place (engage) n'est pas rompu.
      if not (a.hold_stop and M.hold_breached(f, e)) then return true end
      breach = true
    end
    a.hold, a.hold_stop = nil, nil
    a.pts = nil
    if agent.state == "walk" and not hurt and not breach then
      FSM.set(M.MACHINE, agent, "step", tick)
      return true
    end
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
  -- Tronçons ENCHAÎNÉS sans arrêt : à WP_CHAIN tuiles du point de passage visé, le PNJ vise déjà le suivant (sinon il
  -- attendait sa pensée suivante, jusqu'à 1 s par point de passage).
  if walking and a.wp_goal and a.pts and agent.goal and d2(a.wp_goal, agent.goal) <= 1
    and d2(p, a.wp_goal) <= M.WP_CHAIN * M.WP_CHAIN then
    local w = a.pts[(a.i or 1) + 1]
    if w or (a.final and not a.partial) then
      a.i = (a.i or 1) + 1
      if w and not w.ok then
        local q = e.surface.find_non_colliding_position(e.name, w, 8, 1)
        if q then
          w = { x = q.x, y = q.y, ok = true }
          a.pts[a.i] = w
        end
      end
      if w then
        a.wp_goal = { x = w.x, y = w.y }
        Nav.go(agent, w, tick, { radius = M.WP_RADIUS })
      else
        a.wp_goal = nil
        Nav.go(agent, a.final, tick, { radius = agent.walk_radius or 2 })
      end
      t.stats.chained = (t.stats.chained or 0) + 1
      walking = false -- chemin en cours de demande : pas de regard ce tour-ci
    end
  end
  -- Une menace fixe NOUVELLE vue par un camarade touche le reste de notre trajet : nouvel itinéraire (détour).
  if walking and a.pts and not a.risk and (a.mver or 0) < (t.mver or 0) then
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
  -- Regard périodique d'un PNJ armé, sain et à l'arrêt (étalé par numéro) : il voyait venir les groupes seulement blessé.
  if not (walking or hurt or fear or breach or not is_armed) and not Re.idle_look_due(tick, a.look_t, agent.id) then
    return false
  end
  a.look_t = tick
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
  -- Le GROUPE de l'ennemi vu est marqué en entier (un nid et ses gardes, des vers en grappe) : sinon le détour contourne
  -- le plus proche et passe sous la vue des autres (banc route-20261020-4e6303a).
  local group = e.surface.find_entities_filtered({ position = ep, radius = M.GROUP_R, force = enemy.force, limit = 16,
    type = { "unit", "unit-spawner", "turret", "ammo-turret", "electric-turret", "fluid-turret", "character" } })
  local marked_one = false
  for _, g in ipairs(group) do
    if g == enemy then marked_one = true end
    local gk, gr = M.classify(g)
    local gp = g.position
    if D.mark_seen(t.map, gp.x, gp.y, gk, gr, tick) and (D.KINDS[gk] or D.KINDS.unit).fixed then
      -- Menace fixe nouvelle : les camarades en marche rejugent leur trajet (8 dernières gardées).
      t.mver = (t.mver or 0) + 1
      t.new_threats = t.new_threats or {}
      t.new_threats[#t.new_threats + 1] = { v = t.mver, x = gp.x, y = gp.y, r = gr or D.KINDS[gk].r, k = gk }
      while #t.new_threats > 8 do table.remove(t.new_threats, 1) end
    end
  end
  if not marked_one then D.mark_seen(t.map, ep.x, ep.y, kind, range, tick) end
  inc(t.stats.seen, kind)
  local dist = math.sqrt(d2(p, ep))
  local K = D.KINDS[kind] or D.KINDS.unit
  local rr = range or K.r
  local on_route = walking and d_route(p, a, ep) <= rr + Re.MARGIN
  local s = e.surface
  local enemies, allies = 1, 0
  if not K.fixed then
    -- Force ennemie PESÉE : une unité vaut sa vie maximale / 75 (petit déchiqueteur 0,2, moyen 1, gros 5), au moins 0,2 ;
    -- un personnage vaut 1 (un ouvrier armé comme nous).
    enemies = 0
    for _, u in ipairs(s.find_entities_filtered({ position = ep, radius = 16, force = enemy.force, type = { "unit", "character" }, limit = 24 })) do
      enemies = enemies + M.weight(u)
    end
    allies = math.max(0, s.count_entities_filtered({ position = p, radius = M.ALLY_R, force = e.force,
      type = { "unit", "character" } }) - 1)
  end
  local action, why = Re.decide({ kind = kind, range = range, dist = dist, on_route = on_route, hp = hp, armed = is_armed,
    enemies = enemies, allies = allies, walking = walking, prudence = prud, agressivite = agr, repeats = a.urep,
    backs = (a.back_t and tick - a.back_t <= Re.BACK_MEMORY) and a.backs or 0 })
  -- C4 : un soldat ou un ouvrier ADVERSE isolé (force pesée ≤ 1,5, pas la force des déchiqueteurs) vu près du QG : la
  -- garnison est appelée, elle le chasse (au plus une alerte par menace et par minute : script/ai3/soldats.lua).
  if not K.fixed and enemy.force.name ~= "enemy" and enemies <= Re.ISOLATED and M.on_alert then
    if M.on_alert(f, ep, kind, tick, "hunt") then t.stats.hunts = (t.stats.hunts or 0) + 1 end
  end
  -- Tournée escaladée (risque accepté par la porte) : pas de nouveau détour pour une menace fixe déjà connue (le chemin
  -- qui minimise le danger la contourne déjà au mieux) ; le demi-tour à portée reste.
  if a.risk and K.fixed and action == "detour" then action = "none" end
  -- Près du QG, face à des UNITÉS : sans tourelle où se réfugier, fuir seul est pire que rester groupés (un déchiqueteur
  -- court plus vite qu'un personnage) : on se bat sur place. Même banc : 4 ouvriers sans tâche rattrapés à 11 tuiles du QG.
  local to = nil
  if near_home and not K.fixed and (action == "flee" or action == "back") then
    -- Lot FUITE : pas de combat un par un (int-1 : 5 PNJ tués dans les 32 tuiles du QG). Re.hq_response : assez nombreux,
    -- on se bat ; sinon on se regroupe derrière les tourelles du QG ; sans tourelle, on s'éloigne d'un ennemi plus lent, et
    -- face à un plus rapide (déchiqueteur) on se bat, groupés.
    local rally = M.rally(f)
    local resp = Re.hq_response({ allies = allies + 1, force = enemies, prudence = prud, agressivite = agr, rally = rally,
      outrun = Re.outrun(M.enemy_speed(enemy), e.prototype.running_speed) })
    if resp == "rally" then
      if d2(p, rally) <= 36 then action, why = "engage", "sous-les-tourelles"
      else action, why, to = "flee", "ralliement", rally end
    elseif resp == "away" then
      action, why, to = "flee", "eloignement", Re.away_from(p, ep, rr)
    else
      action, why = "engage", "groupes-au-qg"
    end
  end
  if action == "none" then return false end
  -- MEUTE : le PNJ recule devant un groupe d'unités (force pesée ≥ 0,4) : la zone du groupe (vue + étendue) devient une
  -- menace fixe à décroissance rapide, pour que le nouvel itinéraire ne passe pas par ses bords (banc final-c4091c0 : 3
  -- entrées dans une zone vue occupée, entre des disques d'unités sous le seuil de blocage).
  if not K.fixed and enemies >= 0.4 and (action == "stop" or action == "detour" or action == "back" or action == "flee") then
    local sx, sy, n = 0, 0, 0
    for _, g in ipairs(group) do
      if g.type == "unit" or g.type == "character" then
        sx, sy, n = sx + g.position.x, sy + g.position.y, n + 1
      end
    end
    if n > 0 then
      local cx, cy = sx / n, sy / n
      local spread = 0
      for _, g in ipairs(group) do
        if g.type == "unit" or g.type == "character" then
          local d = math.sqrt(d2(g.position, { x = cx, y = cy }))
          if d > spread then spread = d end
        end
      end
      if D.mark_seen(t.map, cx, cy, "pack", rr + spread, tick) then
        t.mver = (t.mver or 0) + 1
        t.new_threats = t.new_threats or {}
        t.new_threats[#t.new_threats + 1] = { v = t.mver, x = cx, y = cy, r = rr + spread, k = "pack" }
        while #t.new_threats > 8 do table.remove(t.new_threats, 1) end
      end
      t.stats.packs = (t.stats.packs or 0) + 1
    end
  end
  if not K.fixed and (action == "stop" or action == "detour") then a.urep = (a.urep or 0) + 1 end
  -- Pas de demi-tour ni de fuite pour un PNJ déjà en route vers le QG sans tâche : il rentre déjà (refuge seulement).
  return act(agent, f, t, a, action, why, ep, kind, tick, range, to)
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
  -- Lot RECO-DIRECTION (relecture) : un éclaireur de reconnaissance (agent.reco_tag) mort en route ne laisse aucune marque : l'équipe ne
  -- sait pas où il est tombé (demande du DC : ce qu'il a vu n'est transmis que s'il revient). Compté à part.
  if agent.reco_tag and agent.death_cause and agent.death_cause:find("/", 1, true) then
    t.stats.deaths_reco = (t.stats.deaths_reco or 0) + 1
  elseif agent.death_cause and agent.death_cause:find("/", 1, true) then
    local at_home = f.hq_pos and d2(agent.death_pos, f.hq_pos) <= M.HOME_DEATH_R * M.HOME_DEATH_R
    D.mark_death(t.map, agent.death_pos.x, agent.death_pos.y, game.tick, at_home)
    if at_home then t.stats.deaths_home = (t.stats.deaths_home or 0) + 1 end
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

-- YEUX FIXES (brouillard d'IA2-c : le QG voit à 160 tuiles, un avant-poste à 128) : les menaces fixes connues dans leur
-- champ sont REVÉRIFIÉES à tour de rôle (M.RECHECK par équipe toutes les M.RECHECK_PERIOD ticks) ; une menace qui n'y est
-- plus (nid détruit par des tourelles, des soldats, une autre faction) est oubliée. Sans cela, personne ne retournant à un
-- endroit refusé par la porte, un nid détruit bloquait encore les tournées pendant des dizaines de minutes (banc
-- final-65703a5\memoire-20261020 : 282 refus, nid détruit). Les menaces hors de ce champ restent en mémoire (brouillard).
M.RECHECK = 8
M.RECHECK_PERIOD = 600
local function eyes_see(f, p)
  if f.hq_pos and d2(p, f.hq_pos) <= 160 * 160 then return true end
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if o.pos and d2(p, o.pos) <= 128 * 128 then return true end
  end
  return false
end
Events.on_nth_tick(M.RECHECK_PERIOD, function(e)
  if not M.enabled() then return end
  local st = S()
  if not st then return end
  for _, k in ipairs(State.sorted_keys(st.teams)) do
    local t = st.teams[k]
    local f = State.faction(tonumber(k) or k)
    local surface = f and f.hq and f.hq.valid and f.hq.surface
    local list = t.map.threats
    if surface and #list > 0 then
      local keep, gone = {}, 0
      local start = (t.recheck_i or 0) % #list
      local checked = 0
      for idx, th in ipairs(list) do
        local turn = ((idx - 1 - start) % #list) < M.RECHECK
        local alive = true
        if turn and eyes_see(f, th) then
          checked = checked + 1
          alive = surface.find_nearest_enemy({ position = { x = th.x, y = th.y }, max_distance = (th.k == "pack") and 24 or 6,
            force = f.force }) ~= nil
        end
        if alive then keep[#keep + 1] = th else gone = gone + 1 end
      end
      t.recheck_i = start + M.RECHECK
      if gone > 0 then
        t.map.threats = keep
        t.stats.recheck_gone = (t.stats.recheck_gone or 0) + gone
      end
      t.stats.rechecks = (t.stats.rechecks or 0) + checked
    end
  end
end)

---------------------------------------------------------------------------------------------------
-- Interface distante « fo-ia3k » (bancs ; le mod de test n'a pas accès à `global` de ce mod)
--   status(clé)                       -> { enabled, epoch, stats, summary, escorts } ou nil
--   agents(clé)                       -> { { id, x, y, state, task, hp, hold, refuge, wps, wp_i, final }, ... }
--   trip(clé, id, x, y[, attente[, sx, sy[, genre]]]) -> numéro de tournée (PNJ sans tâche) ou false ; (sx, sy) : entrée ;
--                                        genre de la tâche (« garrison » par défaut ; un autre genre n'est pas exempté du rappel) [bancs]
--   hold(clé, vrai|faux)              -> vrai : la porte refuse toute tâche du cerveau (tournées seules) [bancs]
--   set_character(clé, prudence, agressivite) -> vrai (nil, nil : caractère de la faction)           [bancs]
--   mark(clé, x, y, genre, portée), death(clé, x, y), forget(clé) (carte remise à zéro) -> vrai       [bancs]
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
  trip = function(key, id, x, y, wait, sx, sy, kind)
    local f = team_by_key(key)
    local ag = Registry.get(id)
    if not (f and ag and ag.faction == f.id and ag.entity.valid) or ag.task then return false end
    local t = M.team(f)
    t.trips = (t.trips or 0) + 1
    ag.task = { key = "ia3k-trip:" .. t.trips, kind = kind or "garrison", post = "ia3k", trip = t.trips, claimed = game.tick }
    ag.steps = { { "goto", { x = x, y = y }, 3 }, { "wait", wait or 60 }, { "home" } }
    -- (sx, sy) : entrée du couloir, rejointe d'abord (bancs à couloirs parallèles aux axes).
    if sx and sy then table.insert(ag.steps, 1, { "goto", { x = sx, y = sy }, 2 }) end
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
  forget = function(key)
    local f = team_by_key(key)
    if not f then return false end
    local t = M.team(f)
    t.map = D.new()
    t.new_threats = {}
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
