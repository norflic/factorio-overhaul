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
local A = require("shared.ai3.armee") -- lot ARMEE-ANTICIPATION : menace estimée, regroupement, raid
local FC = require("shared.faction.config")
local FS = require("shared.faction.strategy")
local D = require("shared.ai3.danger")
local K = require("shared.ai3.carte")
local Re = require("shared.ai3.reaction")
local Sd = require("shared.ai3.soldats")
local C = require("script.ai3.comportement")
local Nt = require("shared.ai3.nettoyage") -- lot NETTOYAGE-SITE : priorité au site proche (Nt.filter_threats)
local Nts = require("script.ai3.nettoyage") -- lot NETTOYAGE-SITE : opération de nettoyage du site proche bloqué

local SD = {}

SD.PERIOD = 30
SD.ESCORT_NEAR = 20
SD.ESCORT_MAX_TICKS = 10 * 3600
SD.ALERT_TICKS = 3600
SD.CLEAR_TICKS = 3 * 3600
SD.THREAT_HQ = 220     -- menaces candidates au nettoyage : à moins de 220 tuiles du QG...
SD.THREAT_OUTPOST = 64 -- ... ou de 64 tuiles d'un avant-poste
SD.HQ_THREAT_R = 48
SD.RING_TICKS = 3600  -- lot CENTRALE : les anneaux sûrs sont recalculés chaque minute
SD.SHELTER_TICKS = 600 -- ralliement ou éloignement : on y attend 10 s, puis le PNJ rentre et la menace est rejugée

local LABEL = { patrol = "patrouille", guard = "garde", escort = "escorte", clear = "nettoyage", defense = "defense", hunt = "chasse",
  muster = "regroupement" }

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
  elseif o.role == "muster" then
    compound(u, { go(p, 6), wander(8) }) -- lot ARMEE-ANTICIPATION : une seule force, serrée, qui réagit à l'ennemi (distraction)
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
  -- Lot ARMEE-ANTICIPATION (« ils ont envoyé quatre soldats dans un endroit trop dangereux », DC 29/10) : la fuite devant un NID,
  -- un VER ou une tourelle n'appelle pas 4 soldats en attaque de zone au pied du champ (aucune mesure de sa force) ; ces menaces
  -- fixes sont déjà dans la carte de l'équipe (t.map.threats) : le nettoyage les prend, compté sur le champ entier (Sd.field_need).
  if kind == "spawner" or kind == "worm" or kind == "turret" then return false end
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
  resp = resp or "stand" -- l'appel de votre équipe (sans soldats) n'en donne pas : mise à l'abri seule (moteur réel, petrole-guide 20261020 : plantage à la minute 73)
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
        local march = resp ~= "stand" -- ralliement ou éloignement : marche EXPLICITE (un PNJ déjà au QG n'ira nulle part sinon)
        if march and tick - (a.shelter_t or -1e9) >= SD.SHELTER_TICKS or (not march and not a.refuge) then
          if march then a.shelter_t = tick else a.refuge = to end
          a.pts, a.final = nil, nil
          Worker.abort(ag, f, tick, "abri")
          if march then ag.steps, ag.pc = { { "goto", to, 3 }, { "wait", SD.SHELTER_TICKS }, { "home" } }, 1 end
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

--- Lot ARMEE-ANTICIPATION : force d'un soldat de l'équipe (meilleur soldat débloqué ; fusilier de niveau 0 = 1).
local function strength_of(f)
  return FS.soldier_strength(FC.best_soldier(f.tech or 0), f.tech or 0, f.upgrades or 0)
end

--- Lot ARMEE-ANTICIPATION : menace qui va venir (shared/ai3/armee.lua), au plus toutes les A.PERIOD ticks. État f.armee (créé
--- ici, en événement) : { t, alert_until, threat, need, muster, raid, fails, est, on, log_t, seen, raid_why } ; lecteurs : ce
--- fichier (regroupement, raid, alertes, journal) et script/team/team.lua (Team.view : army_alert, army_need, lus par
--- shared/team/planner.lua).
local function armee_eval(f, surface, km, list, tick)
  local st = f.armee
  if not st then
    st = { fails = {} }
    f.armee = st
  end
  if st.t and tick - st.t < A.PERIOD then return st end
  st.t = tick
  local pts = km and K.enemy_points(km, f.hq_pos.x, f.hq_pos.y, Sd.KNOWN_R) or {}
  table.sort(pts, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return a.kind < b.kind
  end)
  local fields = A.fields(Sd.clusters(pts), f.hq_pos)
  for _, c in ipairs(fields) do
    c.polluted = surface.get_pollution({ x = c.x, y = c.y }) > 0
    local w = 0
    for _, u in ipairs(surface.find_enemy_units({ x = c.x, y = c.y }, A.FIELD_R, f.force)) do w = w + C.weight(u) end
    c.units = w
  end
  local approach = {}
  for _, u in ipairs(surface.find_enemy_units(f.hq_pos, A.HQ_R, f.force)) do
    local p = u.position
    approach[#approach + 1] = { x = p.x, y = p.y, w = C.weight(u), id = u.unit_number or 0 }
  end
  table.sort(approach, function(a, b) return a.id < b.id end)
  local est = A.estimate({ tick = tick, hq = f.hq_pos, home = home(f), strength = strength_of(f), fields = fields,
    approach = approach, fails = st.fails, soldiers = f.soldiers_count or 0, free = #list })
  st.est = { threat = est.threat, incoming = est.incoming, hot = #est.hot, nests = est.nests, worms = est.worms, units = est.units,
    need = est.need }
  st.raid = est.raid
  if est.alert then
    st.alert_until = tick + A.HOLD
    st.muster, st.need, st.threat = est.muster, est.recruit, est.threat -- relecture : besoin = menace ET raid visé (+ réserve)
  end
  return st
end

--- Lot ARMEE-ANTICIPATION : journal [FO-ARMEE] : début et fin d'alerte, état toutes les 5 min pendant l'alerte, recrues de
--- l'alerte, raid différé (au changement de motif). Une ligne par cause.
local function armee_journal(f, st, summary, list, tick)
  if not st then return end
  local on = A.alert_on(st, tick)
  local e = st.est or {}
  local soldiers = f.soldiers_count or 0
  local function state_line(what)
    log(string.format("[FO-ARMEE] %s : menace %s a %.1f min : estimee %.1f (vague en approche %.1f ; champs menacants %d : %d nid(s), %d ver(s), unites %.1f), soldats %d (sans groupe %d), besoin %d (menace seule %d), regroupement en (%d, %d)%s",
      tostring(f.key), what, tick / 3600, e.threat or 0, e.incoming or 0, e.hot or 0, e.nests or 0, e.worms or 0, e.units or 0,
      soldiers, #list, st.need or 0, e.need or 0, math.floor(st.muster and st.muster.x or 0), math.floor(st.muster and st.muster.y or 0),
      st.raid and string.format(", raid vise (%d, %d) besoin %d", math.floor(st.raid.x), math.floor(st.raid.y), st.raid.need) or ""))
  end
  if on and not st.on then
    st.on, st.log_t = true, tick
    state_line("ANNONCEE")
  elseif not on and st.on then
    st.on, st.raid_why = nil, nil
    state_line("retombee")
  elseif on and tick - (st.log_t or 0) >= 5 * 3600 then
    st.log_t = tick
    state_line("en cours")
  end
  if on and st.seen and soldiers > st.seen then
    log(string.format("[FO-ARMEE] %s : recrues de l'alerte a %.1f min : +%d soldat(s), effectif %d, besoin %d", tostring(f.key),
      tick / 3600, soldiers - st.seen, soldiers, st.need or 0))
  end
  st.seen = soldiers
  local why = summary and summary.raid or nil
  if why ~= st.raid_why then
    st.raid_why = why
    if (why == "effectif" or why == "bloque") and st.raid then
      log(string.format("[FO-ARMEE] %s : raid differe en (%d, %d) a %.1f min : %s ; regroupement et recrutement d'abord",
        tostring(f.key), math.floor(st.raid.x), math.floor(st.raid.y), tick / 3600,
        why == "effectif" and string.format("%d soldat(s) libres pour un besoin de %d + reserve %d", #list, st.raid.need, st.raid.reserve or 0)
          or "champ d'une retraite recente"))
    end
  end
end

--- Menace sur le QG (C7) : l'ennemi militaire le plus proche à moins de HQ_THREAT_R tuiles ; réponse de l'équipe (shelter).
local function hq_threat(f, t, surface, tick)
  local en = surface.find_nearest_enemy({ position = f.hq_pos, max_distance = SD.HQ_THREAT_R, force = f.force })
  if not (en and (en.type == "unit" or en.type == "character")) then return end
  local threat = { x = en.position.x, y = en.position.y }
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
  return threat -- lot NETTOYAGE-SITE : lu par pass (aucune opération de nettoyage lancée quand le QG est menacé)
end

local function pass(f, tick)
  local t = C.team(f)
  t.sd = t.sd or { per = {}, cursor = 0 }
  local sd = t.sd
  local per = sd.per
  local enabled = C.enabled()
  local surface = f.hq and f.hq.valid and f.hq.surface
  if not surface then return end
  local hq_en = nil -- lot NETTOYAGE-SITE : menace sur le QG (lue par Nts.pass)
  if enabled then hq_en = hq_threat(f, t, surface, tick) end
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
    sd.nt = nil -- lot NETTOYAGE-SITE (relecture) : ses soldats viennent d'être rendus ci-dessus ; aucune opération figée au rallumage
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
  -- Lot ARMEE-ANTICIPATION : `threat` n'était plus défini ici depuis le lot FUITE (b390ad3, 28/10 : la menace a été déplacée dans
  -- hq_threat) ; la défense du QG par TOUS les soldats ne partait plus jamais. La menace rendue par hq_threat est relue.
  if hq_en then defend[#defend + 1] = { key = "hq", x = hq_en.x, y = hq_en.y } end
  local alerts = {}
  -- Lot ARMEE-ANTICIPATION : pendant une alerte (vague annoncée, f.armee), une alerte de défense prend TOUTE la force libre si
  -- elle est près du QG (à moins de Sd.NEAR_HQ), personne sinon : plus d'envoi de 4 soldats isolés loin du regroupement.
  local army_on = A.alert_on(f.armee, tick)
  for _, a in ipairs(t.alerts or {}) do
    if tick < a["until"] then
      alerts[#alerts + 1] = a
      local n = a.n
      -- Relecture : `cond and nil or 0` valait TOUJOURS 0 (Lua : `nil or 0`) : pendant l'alerte, aucune alerte de défense ne
      -- partait, même au pied du QG ; écrit en deux branches.
      if army_on and not a.role then
        if d2(a, f.hq_pos) <= Sd.NEAR_HQ * Sd.NEAR_HQ then n = nil else n = 0 end
      end
      if n ~= 0 then defend[#defend + 1] = { key = "alerte", x = a.x, y = a.y, n = n, role = a.role } end
    end
  end
  t.alerts = alerts
  -- Coupure de banc : war_option « soldats_offensive » = false (ni expédition, ni nids de la carte de connaissance, ni retraite).
  local ws = State.war().settings
  local offense = not (ws and ws.soldats_offensive == false)
  local km = f.ai3f and f.ai3f.m
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
      cand[#cand + 1] = { x = th.x, y = th.y, kind = th.k, killed = D.deaths_near(t.map, { th }, 48, tick) > 0 or (th.b ~= nil and tick - th.b < 3600) }
    end
  end
  -- Lot ACT-SOLDATS : les nids et vers de la carte de CONNAISSANCE (yeux du QG, des avant-postes, éclaireurs) à moins de
  -- Sd.KNOWN_R tuiles du QG sont aussi candidats, pour l'EXPÉDITION seulement (Sd.add_known). Sans cela, seuls les nids vus en
  -- marche par un PNJ armé comptaient : fumée 0.6.13, 24 soldats inactifs pendant 35 min et aucune expédition (RD_LOG, lot ACT-SOLDATS).
  if offense and km then
    local added = Sd.add_known(cand, K.enemy_points(km, f.hq_pos.x, f.hq_pos.y, Sd.KNOWN_R))
    if added > 0 then
      t.stats.known_threats = (t.stats.known_threats or 0) + 1
      if not sd.known_logged then
        sd.known_logged = true
        local nn = 0
        for _, c in ipairs(cand) do if c.known and c.kind == "spawner" then nn = nn + 1 end end
        log(string.format("[FO-SOLDATS-CONN] %s : premiers nids de la carte de connaissance lus par l'expedition : %d nid(s) et %d ver(s) a moins de %d tuiles du QG, %d soldat(s) sans groupe",
          tostring(f.key), nn, added - nn, Sd.KNOWN_R, #list))
      end
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
      -- Même oubli sur la carte de connaissance (sinon un nid détruit y reste jusqu'au prochain regard du secteur, 30 min).
      if offense and km then
        local lim = (nd and math.min(nd, 32) or 34) - 2
        if lim > 0 then t.stats.forgot_known = (t.stats.forgot_known or 0) + K.forget_enemies(km, sd.clearing.x, sd.clearing.y, lim) end
      end
    end
    -- Menaces candidates recalculées après le regard.
    local keep = {}
    for _, c in ipairs(clusters) do
      local alive = false
      for _, th in ipairs(t.map.threats) do if d2(th, c) <= 24 * 24 then alive = true break end end
      -- Groupe fait (en tout ou en partie) de nids connus : vivant tant que la carte de connaissance en garde près de lui.
      if not alive and (c.known or 0) > 0 and km then alive = #K.enemy_points(km, c.x, c.y, 24) > 0 end
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
  -- Lot CORR-SOLDATS : EXPÉDITION des soldats inactifs contre un champ de nids connu (règle pure Sd.offense_ok), avec RETRAITE :
  -- si plus de la moitié de la force de départ est morte, les survivants rentrent et le site n'est pas retenté avant
  -- Sd.RETREAT_COOL. Coupure de banc : war_option « soldats_offensive » = false (ni expédition, ni retraite, ni site interdit).
  local keep_b = {}
  for _, b in ipairs(sd.blocked or {}) do if tick < b["until"] then keep_b[#keep_b + 1] = b end end
  sd.blocked = keep_b
  if offense and sd.clearing and sd.clearing.ids then
    local lost = 0
    for _, id in ipairs(sd.clearing.ids) do
      local sl = soldiers[id]
      if not (sl and sl.entity and sl.entity.valid) then lost = lost + 1 end
    end
    sd.clearing.lost = lost
    sd.clearing.need = #sd.clearing.ids - lost -- force encore en vie : les survivants gardent leur ordre, pas de renfort
    if Sd.retreat(#sd.clearing.ids, lost) then
      sd.blocked[#sd.blocked + 1] = { x = sd.clearing.x, y = sd.clearing.y, ["until"] = tick + Sd.RETREAT_COOL }
      for _, id in ipairs(sd.clearing.ids) do
        local sl, ps = soldiers[id], per[id]
        if sl and sl.entity and sl.entity.valid and ps and not sl.group then
          command_for(sl.entity, { role = "home" }, f)
          ps.role, ps.key, ps.escort = nil, nil, nil
          ps.rest_until = tick + Sd.REST
          sl.ia3k = nil
        end
      end
      t.stats.retreats = (t.stats.retreats or 0) + 1
      if sd.clearing.raid and f.armee then
        -- Lot ARMEE-ANTICIPATION : raid repoussé : le prochain raid sur ce champ demandera au moins A.FAIL_MULT × cette force.
        f.armee.fails = A.record_fail(f.armee.fails, sd.clearing.x, sd.clearing.y, #sd.clearing.ids, tick)
        log(string.format("[FO-ARMEE] %s : raid repousse en (%d, %d) a %.1f min : %d mort(s) sur %d, retraite ; prochain raid sur ce champ avec au moins %d soldat(s), pas avant %d min",
          tostring(f.key), math.floor(sd.clearing.x), math.floor(sd.clearing.y), tick / 3600, lost, #sd.clearing.ids,
          #sd.clearing.ids * A.FAIL_MULT, math.floor(Sd.RETREAT_COOL / 3600)))
      end
      if Profiler.enabled() then
        log(string.format("[FO-IA3K] %s : RETRAITE du nettoyage en (%d, %d) : %d mort(s) sur %d", tostring(f.key),
          math.floor(sd.clearing.x), math.floor(sd.clearing.y), lost, #sd.clearing.ids))
      end
      sd.clearing = nil
    end
  end
  -- Lot NETTOYAGE-SITE (arbitrage du DC, 29/10) : le site PROCHE bloqué d'une ressource demandée est nettoyé par une opération
  -- (script/ai3/nettoyage.lua) ; ses soldats sortent de la liste attribuée, et tant qu'elle est préparée (attente d'effectif) ou
  -- en cours, les expéditions plus lointaines que le site sont retirées des menaces candidates. Coupure de banc : offense.
  local nt_n = 0
  -- Coupure coupée en cours d'opération (relecture) : l'opération tombe ; ses soldats, restés dans `list`, reçoivent un ordre de
  -- Sd.assign ou rentrent (rôle « nettoyage-site » sans ordre : branche du rôle perdu plus bas).
  if not offense and sd.nt then sd.nt = nil end
  if offense then
    -- Intégration 0.6.20 (jonction proposée par ARMEE-ANTICIPATION, rapport §5) : pendant une alerte d'armée (vague annoncée,
    -- regroupement), aucune opération de nettoyage n'est préparée ni gardée : les soldats restent au regroupement, comme sous une
    -- menace du QG.
    local nt = Nts.pass(f, t, sd, list, soldiers, per, surface, tick,
      { threatened = hq_en ~= nil or #defend > 0 or army_on, km = km, command = command_for, expedition = sd.clearing })
    if nt.n > 0 then
      local kept = {}
      for _, s in ipairs(list) do if not nt.taken[s.id] then kept[#kept + 1] = s end end
      list, nt_n = kept, nt.n
    end
    if nt.hold and nt.site then
      clusters = Nt.filter_threats(clusters, f.hq_pos, nt.site)
    elseif nt.cleared then
      clusters = Nt.drop_site(clusters, nt.cleared) -- champ lu avant le nettoyage : aucune expédition vers des nids détruits
    end
    -- Soldats rendus par une opération finie à ce passage : repos et rôle relus (sinon Sd.assign les reprend aussitôt).
    for _, s in ipairs(list) do
      local ps = per[s.id]
      s.role, s.rest_until = ps.role, ps.rest_until
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
  -- Lot CENTRALE : anneaux de patrouille et de garde réduits aux points SÛRS (nids et vers connus de la carte de connaissance,
  -- danger et morts de la carte de l'équipe), recalculés chaque minute ou quand la carte de l'équipe change. Nombres seulement.
  local epoch = t.epoch or 0
  if not sd.ring_t or tick - sd.ring_t >= SD.RING_TICKS or sd.ring_epoch ~= epoch then
    local km = f.ai3f and f.ai3f.m
    local B = D.block(ch_prud)
    local function safe(x, y)
      if km then
        local n, w = K.enemies_near(km, x, y, Sd.SAFE_R)
        if n + w > 0 then return false end
      end
      return D.danger_at(t.map, x, y, tick) < B
    end
    sd.ppts = Sd.safe_ring(f.hq_pos, Sd.PATROL_RADII, safe)
    sd.gpts = Sd.safe_ring(f.hq_pos, Sd.GUARD_RADII, safe)
    sd.ring_t, sd.ring_epoch = tick, epoch
  end
  -- Lot ARMEE-ANTICIPATION : menace estimée (au plus toutes les A.PERIOD ticks), alerte, regroupement et raid.
  local ast = armee_eval(f, surface, km, list, tick)
  army_on = A.alert_on(ast, tick)
  -- Relecture : le raid estimé (jusqu'à A.PERIOD ticks plus tôt) n'est lancé que s'il vise encore une menace des groupes du passage.
  local raid = (army_on and offense and A.raid_alive(ast.raid, clusters)) and ast.raid or nil
  local orders, summary = Sd.assign({
    tick = tick, hq = f.hq_pos, agr = ch_agr, soldiers = list, defend = defend, escorts = escorts,
    threats = clusters, clearing = sd.clearing, marked_outposts = marked, cursor = sd.cursor,
    patrol_pts = sd.ppts, guard_pts = sd.gpts, offense = offense, blocked = sd.blocked,
    muster = army_on and ast.muster or nil, raid = raid,
  })
  armee_journal(f, ast, summary, list, tick)
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
    local ids = {}
    for _, sl in ipairs(list) do
      local o = orders[sl.id]
      if o and o.role == "clear" then ids[#ids + 1] = sl.id end
    end
    sd.clearing = { x = started_clear.x, y = started_clear.y, ["until"] = tick + SD.CLEAR_TICKS, ids = ids, need = #ids,
      raid = (summary.target and summary.target.raid) or nil } -- lot ARMEE-ANTICIPATION : raid (retraite mémorisée dans f.armee.fails)
    if summary.target and summary.target.raid then
      log(string.format("[FO-ARMEE] %s : raid lance en (%d, %d) a %.1f min avec %d soldat(s) sur %d libres (besoin %d) : champ de %s nid(s), %s menace(s), defenseurs %.1f",
        tostring(f.key), math.floor(started_clear.x), math.floor(started_clear.y), tick / 3600, #ids, #list,
        summary.target.need or 0, tostring(summary.target.nests), tostring(summary.target.wide or summary.target.k),
        (ast and ast.raid and ast.raid.units) or 0))
    end
    t.stats.clear_ops = (t.stats.clear_ops or 0) + 1
    if summary.offense then
      t.stats.offense_ops = (t.stats.offense_ops or 0) + 1
      t.stats.offense_sent = (t.stats.offense_sent or 0) + #ids
      if not sd.offense_logged then
        sd.offense_logged = true
        local tg = summary.target or {}
        log(string.format("[FO-SOLDATS-CONN] %s : premiere expedition en (%d, %d) : %d soldat(s) sur %d sans groupe (reserve %d), champ de %s menace(s) dont %s nid(s), %s connue(s) de la seule carte de connaissance",
          tostring(f.key), math.floor(started_clear.x), math.floor(started_clear.y), #ids, #list, Sd.reserve(#list),
          tostring(tg.wide or tg.k), tostring(tg.nests), tostring(tg.known or 0)))
      end
    end
    if Profiler.enabled() then
      log(string.format("[FO-IA3K] %s : nettoyage lance en (%d, %d) avec %d soldat(s)%s ; groupe k=%s champ=%s nids=%s, %d menace(s) connue(s)", tostring(f.key),
        math.floor(started_clear.x), math.floor(started_clear.y), summary.roles.clear or 0,
        summary.offense and " (expedition des inactifs)" or "", tostring(summary.target and summary.target.k), tostring(summary.target and summary.target.wide),
        tostring(summary.target and summary.target.nests), #cand))
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
  m.total = m.total + #list + group_n + nt_n
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

-- Votre équipe n'est pas une faction de la guerre (State.alive) : elle n'a pas de rôles de soldats, mais son QG est menacé
-- comme les autres (une vague de biters, un raid d'une faction) : même réponse, à chaque période (une recherche d'ennemi).
Events.on_nth_tick(SD.PERIOD, function(e)
  if not C.enabled() then return end
  local f = State.faction("player")
  local surface = f and f.hq_pos and f.hq and f.hq.valid and f.hq.surface
  if surface then hq_threat(f, C.team(f), surface, e.tick) end
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
