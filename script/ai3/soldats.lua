--[[
  Lot IA3-k : exécution des RÔLES des soldats (règle pure shared/ai3/soldats.lua ; B5, C4, C7) et de la mise à l'abri des
  ouvriers sans arme quand le QG est menacé (C7). Une faction toutes les PERIOD ticks, à tour de rôle (coût O(soldats)).

  Commandes INDIVIDUELLES composées (return_last) terminées par `wander` sans fin : elles ne finissent jamais, donc
  aucun `on_ai_command_completed` pour une unité (son numéro peut égaler un numéro de groupe : script/faction/military.lua
  lit cet événement par numéro de groupe). Un soldat qui a un rôle porte `s.ia3k` (le rappel des soldats lointains du chef
  l'ignore : crochet de military.lua) ; une attaque du chef le reprend (s.group), son rôle tombe.

  État (global, carte de l'équipe de script/ai3/comportement.lua) : t.sd = { per = { [unit] = { role, key, rest_until,
  escort, label… } }, clearing, free_n, cursor } ; t.alerts = { { x, y, until, n } } ; t.soldiers = mesures (B5).
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Registry = require("script.companion.registry")
local Worker = require("script.team.worker")
local Profiler = require("script.core.profiler")
local D = require("shared.ai3.danger")
local Re = require("shared.ai3.reaction")
local Sd = require("shared.ai3.soldats")
local C = require("script.ai3.comportement")

local SD = {}

SD.PERIOD = 30
SD.ESCORT_NEAR = 20
SD.ESCORT_MAX_TICKS = 10 * 3600
SD.ALERT_TICKS = 3600
SD.CLEAR_TICKS = 3 * 3600
SD.THREAT_HQ = 220     -- menaces candidates au nettoyage : à moins de 220 tuiles du QG...
SD.THREAT_OUTPOST = 64 -- ... ou de 64 tuiles d'un avant-poste
SD.HQ_THREAT_R = 48

local LABEL = { patrol = "patrouille", guard = "garde", escort = "escorte", clear = "nettoyage", defense = "defense", hunt = "chasse" }

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function home(f) return { x = f.hq_pos.x, y = f.hq_pos.y + 14 } end

local function go(p, r) return { type = defines.command.go_to_location, destination = p, radius = r, distraction = defines.distraction.by_enemy } end
local function wander(r) return { type = defines.command.wander, radius = r, distraction = defines.distraction.by_enemy } end
local function compound(u, cmds)
  u.set_command({ type = defines.command.compound, structure_type = defines.compound_command.return_last, commands = cmds })
end

local function command_for(u, o, f, agent_entity)
  local p = { x = o.x, y = o.y }
  if o.role == "patrol" then
    compound(u, { go(p, 8), wander(12) })
  elseif o.role == "guard" then
    compound(u, { go(p, 4), wander(4) })
  elseif o.role == "escort" and agent_entity and agent_entity.valid then
    compound(u, { { type = defines.command.go_to_location, destination_entity = agent_entity, radius = 5,
      distraction = defines.distraction.by_enemy }, wander(6) })
  elseif o.role == "clear" or o.role == "defense" or o.role == "hunt" then
    compound(u, { { type = defines.command.attack_area, destination = p, radius = 24, distraction = defines.distraction.by_enemy },
      wander(12) })
  else
    compound(u, { go(home(f), 12), wander(18) })
  end
end

--- Soldats libres pour une escorte (dernier passage) : lu par la porte des tâches.
C.escort_free = function(f)
  local t = C.team(f)
  return (t.sd and t.sd.free_n) or 0
end

--- Demande d'escorte de la porte : enregistrée, servie au passage suivant.
C.request_escort = function(f, agent, n, tick, key)
  local t = C.team(f)
  if not (t.sd and (t.sd.free_n or 0) >= 2) then return false end
  t.escorts = t.escorts or {}
  t.escorts[agent.id] = { n = n, since = tick, key = key }
  return true
end

--- Alerte d'un PNJ en fuite : les soldats les plus proches vont vers la menace (si elle est près du QG).
--- mode « hunt » (C4) : un adversaire isolé vu par un ouvrier : 3 soldats le chassent (rôle « hunt »).
C.on_alert = function(f, ep, kind, tick, mode)
  if not (f.soldiers and f.hq_pos) or (f.soldiers_count or 0) == 0 or d2(ep, f.hq_pos) > Sd.NEAR_HQ * Sd.NEAR_HQ * 2 then
    return false
  end
  local t = C.team(f)
  t.alerts = t.alerts or {}
  for _, a in ipairs(t.alerts) do
    if d2(a, ep) <= 24 * 24 then
      if tick - (a.t or 0) < 3600 and mode == "hunt" then return false end
      a["until"] = tick + SD.ALERT_TICKS
      a.x, a.y, a.t = ep.x, ep.y, tick
      return true
    end
  end
  t.alerts[#t.alerts + 1] = { x = ep.x, y = ep.y, ["until"] = tick + SD.ALERT_TICKS, n = mode == "hunt" and 3 or 4,
    role = mode == "hunt" and "hunt" or nil, t = tick }
  return true
end

--- C7 : QG menacé. Réponse de l'équipe (Re.hq_response, lot FUITE) :
---   "stand"  : assez nombreux, ou rien à faire (ennemi plus rapide, pas de tourelle) : les ouvriers SANS munitions à moins
---              de 160 tuiles du QG (et à plus de 12 tuiles) se mettent à l'abri (refuge : tourelle amie, sinon le QG s'il est
---              loin de la menace, sinon à l'opposé) ; les autres restent (ils se battent groupés) ;
---   "rally"  : TOUS les PNJ occupés ou libres à moins de 160 tuiles vont derrière les tourelles du QG (point de ralliement) ;
---   "away"   : tous s'éloignent de l'ennemi, qu'ils distancent ;
--- la garnison, la fortification et la défense (Re.recall_exempt) gardent leur poste.
local function shelter(f, t, threat, tick, resp, rally, range)
  local far2 = Re.away_distance(range) ^ 2
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local ag = Registry.get(id)
    if ag and ag.entity.valid then
      local e = ag.entity
      local p = e.position
      local dh = d2(p, f.hq_pos)
      local to = nil
      if dh <= Sd.NEAR_HQ * Sd.NEAR_HQ and not (ag.task and Re.recall_exempt(ag.task.kind, ag.task.defend)) then
        if resp == "rally" then
          if d2(p, rally) > 36 then to = rally end
        elseif resp == "away" then
          if d2(p, threat) < far2 then to = Re.away_from(p, threat, range) end
        elseif ag.task and not C.has_ammo(e) and dh > 12 * 12 then
          to = C.refuge(f, p, threat)
        end
      end
      if to then
        local a = C.astate(ag)
        if not a.refuge then
          a.refuge = to
          a.pts, a.final = nil, nil
          Worker.abort(ag, f, tick, "abri")
          C.label(ag, "abri", tick, t.stats)
          t.stats.shelter = (t.stats.shelter or 0) + 1
          if resp ~= "stand" then t.stats["shelter_" .. resp] = (t.stats["shelter_" .. resp] or 0) + 1 end
        end
      end
    end
  end
end

--- Armés près du QG (à moins de HQ_THREAT_R) : PNJ avec munitions et soldats ; sert à la réponse de l'équipe.
local function armed_near_hq(f)
  local n = 0
  local r2 = SD.HQ_THREAT_R * SD.HQ_THREAT_R
  for _, id in ipairs(State.sorted_keys(f.engineers or {})) do
    local ag = Registry.get(id)
    if ag and ag.entity.valid and d2(ag.entity.position, f.hq_pos) <= r2 and C.has_ammo(ag.entity) then n = n + 1 end
  end
  for _, id in ipairs(State.sorted_keys(f.soldiers or {})) do
    local s = f.soldiers[id]
    if s.entity and s.entity.valid and d2(s.entity.position, f.hq_pos) <= r2 then n = n + 1 end
  end
  return n
end

local function pass(f, tick)
  local t = C.team(f)
  t.sd = t.sd or { per = {}, cursor = 0 }
  local sd = t.sd
  local per = sd.per
  local enabled = C.enabled()
  local surface = f.hq and f.hq.valid and f.hq.surface
  if not surface then return end
  -- Menace sur le QG (C7) : l'ennemi militaire le plus proche à moins de HQ_THREAT_R tuiles.
  local threat = nil
  if enabled then
    local en = surface.find_nearest_enemy({ position = f.hq_pos, max_distance = SD.HQ_THREAT_R, force = f.force })
    if en and (en.type == "unit" or en.type == "character") then threat = { x = en.position.x, y = en.position.y } end
    if threat then
      -- Force ennemie PESÉE autour de la menace (même mesure que le regard : moyen déchiqueteur = 1).
      local force = 0
      for _, u in ipairs(surface.find_entities_filtered({ position = threat, radius = 16, force = en.force,
        type = { "unit", "character" }, limit = 24 })) do
        force = force + C.weight(u)
      end
      local prud, agr = C.character(f)
      local rally = C.rally(f)
      local _, range = C.classify(en)
      local own = game.entity_prototypes["character"] and game.entity_prototypes["character"].running_speed or nil
      local resp = Re.hq_response({ allies = armed_near_hq(f), force = force, prudence = prud, agressivite = agr, rally = rally,
        outrun = Re.outrun(C.enemy_speed(en), own) })
      t.stats["hq_" .. resp] = (t.stats["hq_" .. resp] or 0) + 1
      shelter(f, t, threat, tick, resp, rally, range)
    end
  end
  local soldiers = f.soldiers or {}
  local ids = State.sorted_keys(soldiers)
  local list, group_n = {}, 0
  for _, id in ipairs(ids) do
    local s = soldiers[id]
    if s.entity and s.entity.valid then
      local ps = per[id]
      if not ps then
        ps = {}
        per[id] = ps
      end
      if s.group then
        if ps.role then ps.role, ps.key, ps.escort = nil, nil, nil end
        s.ia3k = nil
        ps.was_group = true
        group_n = group_n + 1
      else
        if ps.was_group then
          ps.was_group = nil
          ps.rest_until = tick + Sd.REST
        end
        local p = s.entity.position
        list[#list + 1] = { id = id, x = p.x, y = p.y, role = ps.role, rest_until = ps.rest_until, escort = ps.escort }
      end
    end
  end
  for _, id in ipairs(State.sorted_keys(per)) do
    if not soldiers[id] then
      local ps = per[id]
      if ps.label and rendering.is_valid(ps.label) then rendering.destroy(ps.label) end
      per[id] = nil
    end
  end
  if not enabled then
    -- Réglage éteint : les rôles tombent, les soldats rentrent en garnison.
    for _, s in ipairs(list) do
      local ps = per[s.id]
      if ps.role then
        command_for(soldiers[s.id].entity, { role = "home" }, f)
        ps.role, ps.key, ps.escort = nil, nil, nil
        soldiers[s.id].ia3k = nil
      end
    end
    sd.free_n = 0
    return
  end
  -- Escortes demandées (triées par PNJ) : PNJ vivant, même tâche (ou tâche pas encore prise : 120 ticks de grâce).
  local escorts, esc_ent = {}, {}
  t.escorts = t.escorts or {}
  for _, aid in ipairs(State.sorted_keys(t.escorts)) do
    local er = t.escorts[aid]
    local ag = Registry.get(aid)
    local alive = ag and ag.entity.valid
    local same = alive and ((ag.task and ag.task.key == er.key) or (not ag.task and tick - er.since < 120))
    if alive and same and tick - er.since < SD.ESCORT_MAX_TICKS then
      local p = ag.entity.position
      escorts[#escorts + 1] = { aid = aid, x = p.x, y = p.y, n = er.n }
      esc_ent[aid] = ag
    else
      t.escorts[aid] = nil
    end
  end
  -- Points à défendre.
  local defend = {}
  if threat then defend[#defend + 1] = { key = "hq", x = threat.x, y = threat.y } end
  local alerts = {}
  for _, a in ipairs(t.alerts or {}) do
    if tick < a["until"] then
      alerts[#alerts + 1] = a
      defend[#defend + 1] = { key = "alerte", x = a.x, y = a.y, n = a.n, role = a.role }
    end
  end
  t.alerts = alerts
  -- Menaces candidates au nettoyage (vues par l'équipe), regroupées ; « a tué » : une mort de l'heure à 48 tuiles.
  local cand = {}
  for _, th in ipairs(t.map.threats) do
    local ok = d2(th, f.hq_pos) <= SD.THREAT_HQ * SD.THREAT_HQ
    if not ok then
      for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
        local o = f.outposts[oid]
        if d2(th, o.access or o.pos) <= SD.THREAT_OUTPOST * SD.THREAT_OUTPOST then ok = true break end
      end
    end
    if ok then
      -- « a tué » ou BLOQUE une tournée (porte, escalade) : nettoyée quel que soit le caractère de la faction.
      cand[#cand + 1] = { x = th.x, y = th.y, killed = D.deaths_near(t.map, { th }, 48, tick) > 0 or (th.b ~= nil and tick - th.b < 3600) }
    end
  end
  table.sort(cand, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  local clusters = Sd.clusters(cand)
  table.sort(clusters, function(a, b)
    if (a.killed and 1 or 0) ~= (b.killed and 1 or 0) then return a.killed and true or false end
    local da, db = d2(a, f.hq_pos), d2(b, f.hq_pos)
    if da ~= db then return da < db end
    return a.x < b.x
  end)
  -- Opération de nettoyage en cours : les soldats arrivés sur place sont des YEUX (les ouvriers n'y vont plus) : un
  -- regard autour de la cible efface les menaces qui n'y sont plus (D.forget_unseen).
  if sd.clearing then
    local on_site = false
    for _, s in ipairs(list) do
      if per[s.id].role == "clear" and d2(s, sd.clearing) <= 24 * 24 then on_site = true break end
    end
    if on_site then
      local en = surface.find_nearest_enemy({ position = sd.clearing, max_distance = 32, force = f.force })
      local nd = en and math.sqrt(d2(en.position, sd.clearing)) or nil
      t.stats.forgot = (t.stats.forgot or 0) + D.forget_unseen(t.map, sd.clearing.x, sd.clearing.y, 32, nd)
      -- Plus aucun ennemi militaire à 32 tuiles : les menaces fixes connues dans ce rayon sont effacées toutes.
      if not en then t.stats.forgot = t.stats.forgot + D.forget_unseen(t.map, sd.clearing.x, sd.clearing.y, 34, nil) end
    end
    -- Menaces candidates recalculées après le regard.
    local keep = {}
    for _, c in ipairs(clusters) do
      local alive = false
      for _, th in ipairs(t.map.threats) do if d2(th, c) <= 24 * 24 then alive = true break end end
      if alive then keep[#keep + 1] = c end
    end
    clusters = keep
  end
  -- Opération de nettoyage en cours : finie quand plus aucune menace connue près d'elle, ou au bout de CLEAR_TICKS.
  if sd.clearing then
    local still = false
    for _, c in ipairs(clusters) do if d2(c, sd.clearing) <= 24 * 24 then still = true end end
    if not still or tick >= sd.clearing["until"] then
      if Profiler.enabled() then
        log(string.format("[FO-IA3K] %s : nettoyage en (%d, %d) %s", tostring(f.key), math.floor(sd.clearing.x),
          math.floor(sd.clearing.y), still and "abandonne (delai)" or "termine (plus de menace vue)"))
      end
      t.stats.cleared = (t.stats.cleared or 0) + (still and 0 or 1)
      sd.clearing = nil
    end
  end
  -- Avant-postes marqués (menace ou mort à moins de 48 tuiles) : 2 gardes chacun.
  local marked = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    local p = o.access or o.pos
    local hot = D.deaths_near(t.map, { p }, 48, tick) > 0
    if not hot then
      for _, th in ipairs(t.map.threats) do if d2(th, p) <= 48 * 48 then hot = true break end end
    end
    if hot then marked[#marked + 1] = { x = p.x, y = p.y } end
  end
  local ch_prud, ch_agr = C.character(f)
  local orders, summary = Sd.assign({
    tick = tick, hq = f.hq_pos, agr = ch_agr, soldiers = list, defend = defend, escorts = escorts,
    threats = clusters, clearing = sd.clearing, marked_outposts = marked, cursor = sd.cursor,
  })
  -- Application : commande seulement quand l'ordre change (l'escorte est relancée à chaque passage : elle suit le PNJ).
  local started_clear = nil
  for _, s in ipairs(list) do
    local u = soldiers[s.id].entity
    local ps = per[s.id]
    local o = orders[s.id]
    if o then
      local ag = o.aid and esc_ent[o.aid]
      if o.key ~= ps.key or o.role == "escort" then
        command_for(u, o, f, ag and ag.entity)
        if o.key ~= ps.key then C.label_entity(ps, u, LABEL[o.role] or "garde", tick, t.stats) end
      else
        C.flush_label(ps, u, tick, t.stats)
      end
      if o.role == "clear" and not sd.clearing then started_clear = o end
      ps.role, ps.key, ps.escort = o.role, o.key, o.aid
      -- Drapeau lu par le rappel du chef (military.lua) : seulement les rôles qui éloignent légitimement du QG.
      local far_role = o.role == "escort" or o.role == "clear"
        or (o.role == "guard" and d2(o, f.hq_pos) > Sd.NEAR_HQ * Sd.NEAR_HQ)
      soldiers[s.id].ia3k = far_role and o.role or nil
    elseif ps.role then
      local was = ps.role
      -- Égaré loin du QG : aucune commande (le rappel du chef le ramène par un itinéraire, F172).
      if d2(s, f.hq_pos) <= Sd.NEAR_HQ * Sd.NEAR_HQ then command_for(u, { role = "home" }, f) end
      ps.role, ps.key, ps.escort = nil, nil, nil
      soldiers[s.id].ia3k = nil
      if was ~= "patrol" and was ~= "guard" then ps.rest_until = tick + Sd.REST end
    end
  end
  if started_clear then
    sd.clearing = { x = started_clear.x, y = started_clear.y, ["until"] = tick + SD.CLEAR_TICKS }
    t.stats.clear_ops = (t.stats.clear_ops or 0) + 1
    if Profiler.enabled() then
      log(string.format("[FO-IA3K] %s : nettoyage lance en (%d, %d) avec %d soldat(s)", tostring(f.key), math.floor(started_clear.x),
        math.floor(started_clear.y), summary.roles.clear or 0))
    end
  end
  -- Escorte prête : le PNJ qui attend au QG part dès que la moitié de son escorte est près de lui.
  for _, er in ipairs(escorts) do
    local ag = esc_ent[er.aid]
    if ag.state == "wait" and ag.wait_until and ag.wait_until > tick then
      local near = 0
      for _, s in ipairs(list) do
        local o = orders[s.id]
        if o and o.aid == er.aid and d2(s, er) <= SD.ESCORT_NEAR * SD.ESCORT_NEAR then near = near + 1 end
      end
      if near * 2 >= math.min(er.n, Sd.ESCORT_MAX) then
        ag.wait_until = tick
        t.stats.escort_ready = (t.stats.escort_ready or 0) + 1
      end
    end
  end
  -- Soldats libres pour une escorte : ni au repos, ni en défense, escorte ou nettoyage, près du QG.
  local free_n = 0
  for _, s in ipairs(list) do
    local o = orders[s.id]
    local busy = o and (o.role == "escort" or o.role == "defense" or o.role == "clear" or o.role == "hunt")
    if not busy and not (s.rest_until and tick < s.rest_until) and d2(s, f.hq_pos) <= Sd.NEAR_HQ * Sd.NEAR_HQ then
      free_n = free_n + 1
    end
  end
  sd.free_n = free_n
  sd.cursor = (sd.cursor or 0)
  -- Mesures (B5) : soldats-passages par état.
  local m = t.soldiers or { samples = 0, total = 0, idle = 0, rest = 0, group = 0, far = 0, roles = {} }
  t.soldiers = m
  m.samples = m.samples + 1
  m.far = (m.far or 0) + (summary.far or 0)
  m.total = m.total + #list + group_n
  m.idle = m.idle + summary.idle
  m.rest = m.rest + summary.rest
  m.group = m.group + group_n
  for k, v in pairs(summary.roles) do m.roles[k] = (m.roles[k] or 0) + v end
end

Events.on_nth_tick(SD.PERIOD, function(e)
  local alive = State.alive()
  if #alive == 0 then return end
  local war = State.war()
  if not war.active then return end
  local i = math.floor(e.tick / SD.PERIOD) % #alive + 1
  local f = war.factions[alive[i]]
  if f and not f.eliminated and f.hq_pos then pass(f, e.tick) end
end)

-- Votre équipe n'a pas de soldats : seule la mise à l'abri (C7) la concerne, toutes les 120 ticks.
Events.on_nth_tick(120, function(e)
  if not C.enabled() then return end
  local f = State.faction("player")
  if not (f and f.hq and f.hq.valid and f.hq_pos) then return end
  local en = f.hq.surface.find_nearest_enemy({ position = f.hq_pos, max_distance = SD.HQ_THREAT_R, force = f.force })
  if en and (en.type == "unit" or en.type == "character") then
    shelter(f, C.team(f), { x = en.position.x, y = en.position.y }, e.tick)
  end
end)

SD.pass = pass
return SD
