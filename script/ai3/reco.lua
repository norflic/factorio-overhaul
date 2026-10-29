--[[
  Lot RECO-DIRECTION, côté EXÉCUTION (règles pures : shared/ai3/reco.lua ; tests : tests/reco_test.lua, tests/reco_moteur_test.lua).

  Demande du DC (29/10, vers 22 h 25) : détecter « la direction dans laquelle ils viennent en gros, (comme un humain, et doivent
  envoyer un scout pour repérage et une fois qu'il l'a trouvé il revient si il meurt pas avant) ».

  Chaîne (factions ET votre équipe : toute équipe qui a une carte de connaissance, f.ai3f) :
    1. ATTAQUE REÇUE : le front (script/team/front.lua, on_entity_died, mêmes filtres : pièce de l'équipe, tuée par une force hostile)
       appelle le crochet Front.on_hit ; ici, seules les forces qui ne sont PAS des équipes comptent (les biters ; une faction rivale a son
       QG connu, IA2-c). Le point (le tueur, sinon la pièce) est rangé par octant vu du QG (Rc.record) ; état f.reco.
    2. ENVOI : la voie d'exploration (script/ai3/exploration.lua, team_pass) demande Reco.want : direction suspecte, non expliquée par un
       nid CONNU (K.enemy_points de la carte de connaissance), hors délai, aucune reconnaissance en cours ; un ouvrier libre part (mission
       « reco » de la même machinerie que les éclaireurs d'IA3-f : étapes goto / wait / home, surveillance, chemins ratés).
    3. MARCHE de proche en proche (Reco.monitor) : étape suivante dans l'octant (Rc.waypoint) quand la précédente est atteinte ; un nid
       vu à Rc.EYE tuiles le fait rentrer (« trouve ») ; un ennemi à Rc.FLEE tuiles aussi (« fuite ») ; portée maximale (« portee ») ;
       durée (« duree »).
    4. CARNET : ce que son œil voit n'entre PAS dans la carte de l'équipe (crochet Reco.eye dans les yeux en marche) ; il est noté dans
       son carnet (un secteur par passe, mêmes comptages que le regard d'IA3-f) ; TRANSMIS à son arrivée à Rc.HOME_R tuiles du QG
       (Rc.deliver). Mort avant : carnet perdu, journal, direction toujours suspecte, nouvel envoi après Rc.COOL_DEATH.
  Journal : « [FO-RECO] » (secteur suspect, direction expliquée, envoi, nid vu, fuite, retour et transmission, mort, carnet porté).

  État : f.reco (nombres, chaînes, tables simples ; créé en événement, jamais à on_load) ; sur la mission (k.exl) : ex.d, ex.leg, ex.wp,
  ex.c (carnet) ; sur l'agent : a.reco_tag (numéro de la mission). Aucun temps mesuré, listes triées.
  Bancs de mesure seulement : l'interface fo-ia3f, set_reco(false), coupe tout (aucun envoi, aucun relevé) ; le drapeau est rangé dans
  global.fo.ai3f.reco_off (relecture : une variable de module serait perdue au chargement d'une sauvegarde et désynchroniserait une
  partie à plusieurs).
]]

local Rc = require("shared.ai3.reco")
local K = require("shared.ai3.carte")
local Registry = require("script.companion.registry")
local State = require("script.faction.state")
local Front = require("script.team.front")

local Reco = {}

Reco.LOGS = 400               -- lignes [FO-RECO] au plus par équipe (les envois et retours sont rares ; garde-fou)
local LOOK_EVERY = 30         -- ticks : regard de l'éclaireur (nids à Rc.EYE, ennemi à Rc.FLEE)
local IDLE_LOG = 5 * 3600     -- « pas de PNJ libre » : une ligne au plus toutes les 5 min par équipe
local CARRY_TTL = 20 * 3600   -- un carnet porté par un PNJ qui ne rentre pas est oublié après 20 min
-- Tueurs IMMOBILES (types du moteur) : un ver ou un nid qui tue une pièce posée à sa portée n'est pas une vague venue de loin ; la menace
-- est sur place (carte du danger d'IA3-k, front). Leur coup ne donne pas de direction à reconnaître.
local STATIC_KILLER = { ["turret"] = true, ["unit-spawner"] = true }
local WANT_EVERY = 300        -- ticks : une décision d'envoi au plus toutes les 5 s par équipe (lecture de la carte de connaissance bornée)

-- Crochets de script/ai3/exploration.lua (fonctions locales de la voie, posées une fois au chargement : Reco.bind).
local H = nil
function Reco.bind(h) H = h end

--- Reconnaissance active ? (drapeau des bancs dans global, lu par la voie : H.off).
function Reco.enabled() return not (H and H.off and H.off()) end

local function label(f) return f.key or tostring(f.id) end
local function minutes(t) return t / 3600 end

local function say(f, s, fmt, ...)
  s.logs = (s.logs or 0) + 1
  if s.logs > Reco.LOGS then return end
  log(string.format("[FO-RECO] %s : " .. fmt, label(f), ...))
end

function Reco.state(f, tick)
  if not f.reco then f.reco = Rc.new(tick) end
  return f.reco
end

local function dist(a, x, y) return math.floor(math.sqrt((a.x - x) ^ 2 + (a.y - y) ^ 2)) end

---------------------------------------------------------------------------------------------------
-- 1. Attaques reçues (crochet du front)
---------------------------------------------------------------------------------------------------
--- Pièce de l'équipe f tuée (filtres du front déjà passés). Seules les forces hostiles qui ne sont pas des équipes comptent.
Front.on_hit = function(f, ent, e, w)
  if not f.hq_pos or not Reco.enabled() then return end
  local killer = e.force
  if not killer or killer.name == "player" or State.by_force(killer.name) then return end
  local cause = e.cause and e.cause.valid and e.cause or nil
  if cause and STATIC_KILLER[cause.type] then return end
  local p = cause and cause.position or ent.position
  local s = Reco.state(f, e.tick)
  local d, crossed = Rc.record(s, f.hq_pos, p.x, p.y, w, e.tick)
  if crossed then
    local c = s.sec[d + 1]
    say(f, s, "direction %s suspecte a %.1f min : %d piece(s) perdue(s), score %d, point moyen (%d, %d) a %d tuiles du QG",
      Rc.name(d), minutes(e.tick), c.n, c.w, c.mx, c.my, dist(f.hq_pos, c.mx, c.my))
  end
end

---------------------------------------------------------------------------------------------------
-- 2. Envoi
---------------------------------------------------------------------------------------------------
local function reco_mission(k)
  for _, ex in ipairs(k.exl or {}) do if ex.kind == "reco" then return ex end end
  return nil
end

--- Direction à reconnaître pour l'équipe (candidate de Rc.pick) ou nil. Écrit au journal les directions expliquées par un nid connu.
function Reco.want(f, k, tick)
  if not Reco.enabled() then return nil end
  local s = f.reco
  if not (s and k and k.m and f.hq_pos) then return nil end
  if reco_mission(k) then return nil end
  if tick < (s.want_at or 0) then return nil end
  s.want_at = tick + WANT_EVERY
  s.busy = nil
  local hq = f.hq_pos
  -- Relecture : UNE lecture de la carte de connaissance par décision (au rayon le plus grand des directions notées, plafonné par
  -- Rc.REACH_CAP), au lieu d'une par candidate ; Rc.explained refiltre au rayon de chacune.
  local r = 0
  for i = 1, 8 do
    local sec = s.sec[i]
    if sec then r = math.max(r, Rc.explain_r(sec, hq)) end
  end
  local points = nil
  local c, skipped = Rc.pick(s, tick, function(d, sec)
    points = points or K.enemy_points(k.m, hq.x, hq.y, r)
    return Rc.explained(sec, d, hq, points)
  end)
  s.expl = s.expl or {}
  for _, sk in ipairs(skipped) do
    local key = sk.nest and (sk.nest.x .. "," .. sk.nest.y) or "?"
    if s.expl[sk.d + 1] ~= key then
      s.expl[sk.d + 1] = key
      say(f, s, "direction %s expliquee par le nid connu en (%d, %d), %d tuiles du QG, a %.1f min : aucun envoi", Rc.name(sk.d),
        sk.nest and sk.nest.x or 0, sk.nest and sk.nest.y or 0, sk.nest and dist(hq, sk.nest.x, sk.nest.y) or -1, minutes(tick))
    end
  end
  return c
end

--- Aucun ouvrier libre pour partir : une ligne au plus toutes les IDLE_LOG ticks.
function Reco.no_idle(f, c, tick)
  local s = f.reco
  if not s then return end
  if tick - (s.idle_log or -IDLE_LOG) >= IDLE_LOG then
    s.idle_log = tick
    say(f, s, "direction %s a reconnaitre (score %d) mais aucun PNJ libre a %.1f min", Rc.name(c.d), c.w, minutes(tick))
  end
end

--- Mission « reco » qui démarre (appelé par start_mission d'exploration.lua) : champs de la mission et de l'agent.
function Reco.start(f, k, ex, a, c, tick)
  local s = Reco.state(f, tick)
  ex.d, ex.leg, ex.c, ex.w0 = c.d, 0, Rc.c_new(), c.w
  ex.reach = Rc.reach(c, f.hq_pos)
  a.task.reco = true
  a.reco_tag = ex.tag
  Rc.on_send(s, c.d)
  say(f, s, "eclaireur %d envoye vers %s a %.1f min : score %d, %d piece(s) perdue(s), point moyen (%d, %d), portee %d tuiles",
    a.id, Rc.name(c.d), minutes(tick), c.w, c.n, c.mx, c.my, ex.reach)
  return { { "wait", 30 }, { "home" } } -- la première étape est posée à la première surveillance
end

---------------------------------------------------------------------------------------------------
-- 3. Carnet : yeux et notes
---------------------------------------------------------------------------------------------------
local function carnet_of(f, k, agent_id)
  for _, ex in ipairs((k and k.exl) or {}) do
    if ex.kind == "reco" and ex.agent == agent_id and ex.c then return ex.c end
  end
  for _, cr in ipairs((f.reco and f.reco.carry) or {}) do
    if cr.agent == agent_id then return cr.c end
  end
  return nil
end

--- Œil d'un éclaireur de reconnaissance (crochet des yeux en marche) : les secteurs vont au carnet, pas à la carte. Faux si l'agent n'a
--- plus de carnet (son étiquette est alors retirée et il redevient un œil ordinaire).
function Reco.eye(f, k, a, p, tick)
  local c = carnet_of(f, k, a.id)
  if not c then
    a.reco_tag = nil
    return false
  end
  for _, key in ipairs(H.eye_keys(p.x, p.y, Rc.EYE)) do
    if K.due(k.m, key, tick, K.RELOOK.moving) then Rc.c_want(c, key) end
  end
  return true
end

--- Un secteur du carnet noté (au plus un par appel).
local function note_one(c, surface, tick)
  local key = Rc.c_pop(c)
  if key == nil then return end
  if H.generated(surface, key) then Rc.c_note(c, key, tick, H.observe(surface, key)) end
end

--- Secteur d'un point noté tout de suite (le nid vu, l'ennemi qui le fait fuir).
local function note_now(c, surface, x, y, tick)
  local key = K.key_of(x, y)
  if c.obs[key] then return end
  if H.generated(surface, key) then Rc.c_note(c, key, tick, H.observe(surface, key)) end
end

---------------------------------------------------------------------------------------------------
-- 4. Transmission, perte
---------------------------------------------------------------------------------------------------
local function deliver(f, k, c, agent_id, d, surface, tick, why)
  local s = Reco.state(f, tick)
  local seen_nests, seen_worms = c.nests, c.worms
  local out = Rc.deliver(c, k.m)
  Rc.on_back(s, d, seen_nests, tick)
  say(f, s, "eclaireur %d de retour de %s (%s) a %.1f min : %d secteur(s), %d nid(s), %d ver(s), %d incident(s) transmis a la carte",
    agent_id, Rc.name(d), why, minutes(tick), out.sectors, out.nests, out.worms, out.marks)
  if seen_nests == 0 then
    say(f, s, "%s : aucun nid trouve, direction toujours suspecte, nouvel envoi possible dans %d min", Rc.name(d), Rc.COOL_EMPTY / 3600)
  end
  for _, fr in ipairs(out.fresh) do H.on_fresh(f, k, surface, fr.key, fr.names, fr.t) end
  local a = Registry.get(agent_id)
  if a then a.reco_tag = nil end
end

local function lose(f, c, agent_id, d, tick, how)
  local s = Reco.state(f, tick)
  local cool = Rc.on_lost(s, d, tick)
  say(f, s, "ECLAIREUR %d %s en reconnaissance %s a %.1f min : carnet perdu (%d secteur(s), %d nid(s) vus) ; %s reste suspecte, nouvel envoi dans %d min au plus tot (%d mort(s) de suite)",
    agent_id, how, Rc.name(d), minutes(tick), c and c.n or 0, c and c.nests or 0, Rc.name(d), cool / 3600, s.deaths[d + 1] or 0)
end

--- Surveillance d'une mission « reco » (appelée par monitor_one d'exploration.lua, agent valide, tâche en place, sans chemin raté).
function Reco.monitor(f, k, ex, a, tick)
  local e = a.entity
  local surface = e.surface
  local p = e.position
  if ex.c then note_one(ex.c, surface, tick) end
  if ex.state == "home" then
    if not ex.delivered and ex.c and Rc.at_home(f.hq_pos, p.x, p.y) then
      ex.delivered = true
      deliver(f, k, ex.c, a.id, ex.d, surface, tick, ex.why or "retour")
    end
    return
  end
  if tick - ex.started >= Rc.MAX_TICKS then
    H.go_home(a, ex, "duree", tick)
    return
  end
  if tick >= (ex.next_look or 0) then
    ex.next_look = tick + LOOK_EVERY
    local nests = surface.find_entities_filtered({ position = p, radius = Rc.EYE, force = "enemy", type = "unit-spawner", limit = 4 })
    if #nests > 0 then
      table.sort(nests, function(u, v)
        local du, dv = (u.position.x - p.x) ^ 2 + (u.position.y - p.y) ^ 2, (v.position.x - p.x) ^ 2 + (v.position.y - p.y) ^ 2
        if du ~= dv then return du < dv end
        if u.position.x ~= v.position.x then return u.position.x < v.position.x end
        return u.position.y < v.position.y
      end)
      for _, n in ipairs(nests) do note_now(ex.c, surface, n.position.x, n.position.y, tick) end
      local n1 = nests[1].position
      ex.nest = { x = math.floor(n1.x), y = math.floor(n1.y) }
      say(f, Reco.state(f, tick), "eclaireur %d voit un nid en (%d, %d) a %d tuiles du QG (direction %s, etape %d) a %.1f min : il rentre",
        a.id, ex.nest.x, ex.nest.y, dist(f.hq_pos, n1.x, n1.y), Rc.name(ex.d), ex.leg, minutes(tick))
      H.go_home(a, ex, "trouve", tick)
      return
    end
    local enemy = surface.find_nearest_enemy({ position = p, max_distance = Rc.FLEE, force = e.force })
    if enemy then
      local q = enemy.position
      Rc.c_mark(ex.c, q.x, q.y, tick)
      note_now(ex.c, surface, q.x, q.y, tick)
      say(f, Reco.state(f, tick), "eclaireur %d fuit (%s a %d tuiles) en (%d, %d), etape %d vers %s, a %.1f min : il rentre avec son carnet",
        a.id, enemy.type, dist(p, q.x, q.y), math.floor(p.x), math.floor(p.y), ex.leg, Rc.name(ex.d), minutes(tick))
      H.go_home(a, ex, "fuite", tick)
      return
    end
  end
  -- Étape suivante : aucune encore, la précédente atteinte (attente après le goto), ou retour demandé par le programme.
  local step = a.steps and a.steps[a.pc]
  local arrived = step and step[1] == "wait" and (step[2] or 0) >= 600
  if ex.wp and not arrived and not (step and step[1] == "home") then return end
  ex.leg = ex.leg + 1
  local wp = Rc.waypoint(f.hq_pos, ex.d, ex.leg, ex.reach)
  if not wp then
    H.go_home(a, ex, "portee", tick)
    return
  end
  if H.chunk_ready(surface, wp) then
    local q = surface.find_non_colliding_position(H.body, wp, 24, 1)
    if q then wp = { x = q.x, y = q.y } end
  end
  ex.wp = { x = wp.x, y = wp.y }
  local steps = { { "goto", ex.wp, 6 }, { "wait", 600 }, { "home" } }
  if not H.chunk_ready(surface, wp) then
    surface.request_to_generate_chunks(wp, 2)
    table.insert(steps, 1, { "wait", 90 })
  end
  H.set_steps(a, steps, tick)
end

--- Fin d'une mission « reco » (appelé par end_mission) : transmission si l'éclaireur est rentré, carnet porté s'il est vivant mais loin,
--- perte s'il est mort.
function Reco.on_end(f, k, ex, tick, why)
  if ex.reco_end then return end
  ex.reco_end = true
  local s = Reco.state(f, tick)
  if s.busy == ex.d then s.busy = nil end
  local a = Registry.get(ex.agent)
  local alive = a and a.entity and a.entity.valid
  if ex.delivered then
    if a then a.reco_tag = nil end
    return
  end
  if not alive then
    lose(f, ex.c, ex.agent, ex.d, tick, ex.dead or (a and a.death_cause and ("MORT (" .. a.death_cause .. ")")) or "PERDU")
    ex.c = nil
    return
  end
  local p = a.entity.position
  if ex.c and Rc.at_home(f.hq_pos, p.x, p.y) then
    deliver(f, k, ex.c, a.id, ex.d, a.entity.surface, tick, why)
    ex.c = nil
    return
  end
  -- Vivant, loin de la base (tâche reprise en route) : il porte son carnet jusqu'au retour. Pas de second envoi vers la même direction
  -- en attendant.
  s.carry = s.carry or {}
  s.carry[#s.carry + 1] = { agent = a.id, d = ex.d, c = ex.c or Rc.c_new(), t = tick, why = why }
  ex.c = nil
  s.cool[ex.d + 1] = math.max(s.cool[ex.d + 1] or 0, tick + Rc.COOL_FOUND)
  say(f, s, "eclaireur %d (%s, %s) a %d tuiles du QG a %.1f min : il garde son carnet jusqu'a son retour", a.id, Rc.name(ex.d), why,
    dist(f.hq_pos, p.x, p.y), minutes(tick))
  while #s.carry > Rc.CARRY_MAX do
    local old = table.remove(s.carry, 1)
    local oa = Registry.get(old.agent)
    if oa then oa.reco_tag = nil end
    lose(f, old.c, old.agent, old.d, tick, "OUBLIE (trop de carnets portes)")
  end
end

--- Carnets portés (une passe de la voie des yeux, chaque équipe) : notes, transmission à l'arrivée, perte à la mort, oubli au délai.
function Reco.carry_pass(f, k, tick)
  local s = f.reco
  if not (s and s.carry and #s.carry > 0) then return end
  local keep = {}
  for _, cr in ipairs(s.carry) do
    local a = Registry.get(cr.agent)
    if not (a and a.entity and a.entity.valid) then
      lose(f, cr.c, cr.agent, cr.d, tick, cr.dead or "PERDU")
    else
      local p = a.entity.position
      note_one(cr.c, a.entity.surface, tick)
      if Rc.at_home(f.hq_pos, p.x, p.y) then
        deliver(f, k, cr.c, cr.agent, cr.d, a.entity.surface, tick, cr.why or "retour")
      elseif tick - cr.t >= CARRY_TTL then
        a.reco_tag = nil
        lose(f, cr.c, cr.agent, cr.d, tick, "OUBLIE (pas rentre en " .. (CARRY_TTL / 3600) .. " min)")
      else
        keep[#keep + 1] = cr
      end
    end
  end
  s.carry = keep
end

-- Mort d'un éclaireur de reconnaissance : la cause et le lieu sont gardés pour le journal (le carnet est perdu à la fin de la mission ou
-- à la passe des carnets portés). Aucune marque sur la carte de l'équipe : elle ne sait pas où il est tombé.
Registry.on_removed(function(agent)
  if not agent.reco_tag or not agent.faction then return end
  local f = State.faction(agent.faction)
  if not f then return end
  local p = agent.death_pos
  local how = string.format("MORT (%s) en (%d, %d)", tostring(agent.death_cause or "?"), p and math.floor(p.x) or 0, p and math.floor(p.y) or 0)
  for _, ex in ipairs((f.ai3f and f.ai3f.exl) or {}) do
    if ex.kind == "reco" and ex.agent == agent.id then ex.dead = how end
  end
  for _, cr in ipairs((f.reco and f.reco.carry) or {}) do
    if cr.agent == agent.id then cr.dead = how end
  end
end)

--- Résumé (interface des bancs).
function Reco.report(f)
  local s = f.reco
  if not s then return nil end
  local sec = {}
  for d = 0, 7 do
    local c = s.sec[d + 1]
    if c then sec[#sec + 1] = { d = Rc.name(d), w = c.w, n = c.n, x = c.mx, y = c.my } end
  end
  return { sent = s.sent, back = s.back, lost = s.lost, found = s.found, hits = s.hits, carry = #(s.carry or {}), sectors = sec }
end

return Reco
