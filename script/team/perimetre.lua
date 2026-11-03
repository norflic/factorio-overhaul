--[[
  Lot PERIMETRE, côté RUNTIME (règle pure : shared/team/perimetre.lua ; spécification : fo-logs/2026-11-03_PERIMETRE/SPEC.md).
  Retour du DC du 3/11 (RETOUR3) : tourelles « mal réparties », « pas prévisionnelles », points sensibles non protégés, « un premier
  périmètre puis un deuxième périmètre ».

  Services :
    - Pm.view(f, fortify_open) : appelé à chaque pensée (script/team/team.lua). Relevé toutes les Pe.EVERY ticks (bornes de 5 min) :
      points sensibles et tourelles de l'équipe, nids proches ; MESURE au journal (même interrupteur coupé : lecture seule) ; interrupteur
      allumé : anneaux et postes (Pe.update). Puis, au plus toutes les Pm.PLAN_EVERY ticks, le poste à servir (Pe.plan) ; rend
      { pick, busy, held } pour le planificateur (shared/team/planner.lua, poste « perim », facultatif, budget Pe.allowed) ou nil.
    - Pm.place(f, surface, task, carrier) : pose les tourelles de la tâche « fortify » du poste « perim » (Outposts.fortify_at ; propriétaire
      « perim<clé> », ravitaillement « operim<clé> » par les tâches « refill » existantes) ; rend le nombre posé.
    - Pm.on_lost(f, key, cause) : porteur tué -> poste au repos T.lethal_ticks.
    - on_entity_died : bâtiments de l'équipe perdus sous un ennemi (compteurs de la mesure seulement ; aucune décision n'en dépend).

  État f.perim (créé dans un événement, jamais à on_load ; nombres, chaînes, tables simples) : rings, posts, next_id (règle pure) ; rest,
  zero (repos des postes) ; chk (contrôle « pas d'ennemi », daté) ; nests (relevé) ; pick, plan_tick, served, total (plan) ; lost
  (compteurs de pertes) ; next_scan, logs, mlogs, poses.
  Déterminisme : listes triées, aucun `pairs` dans une décision, aucun temps mesuré.
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local Fr = require("shared.team.front")
local Pe = require("shared.team.perimetre")
local Outposts = require("script.faction.outposts")

local Pm = {}

Pm.OID = "perim"          -- préfixe du propriétaire des tourelles posées (State.own : « perim<clé> ») et identifiant du poste
Pm.PLAN_EVERY = 300       -- ticks : le poste à servir est recalculé au plus aussi souvent (et après chaque pose)
Pm.CHECK_EVERY = 1800     -- ticks : validité d'un contrôle « pas d'ennemi près du poste »
Pm.CALM_R = Fr.CALM_R     -- tuiles : pas de pose tant qu'un ennemi est plus près du poste (comme le front)
Pm.LOGS = 120             -- lignes d'événements [FO-PERIMETRE] au plus par équipe
Pm.MLOGS = 400            -- lignes de mesure au plus par équipe (une toutes les 5 min)

local SENS_TYPES
local function types()
  if SENS_TYPES then return end
  SENS_TYPES = {}
  for _, ty in ipairs(R.ENTITY_TYPES) do
    if Pe.role_w(R.ENTITY_ROLE[ty]) > 0 then SENS_TYPES[#SENS_TYPES + 1] = ty end
  end
end

local RANGE = {} -- portée par nom de prototype (cache local : les prototypes ne changent pas en cours de partie)
local function range_of(name)
  local r = RANGE[name]
  if r == nil then
    local p = game.entity_prototypes[name]
    r = (p and p.turret_range) or 0
    RANGE[name] = r
  end
  return r
end

--- Règle allumée pour cette équipe : interrupteur de shared/team/config.lua, sauf forçage d'un banc (f.perim.forced, interface fo-perimetre).
local function enabled(f)
  local st = f.perim
  if st and st.forced ~= nil then return st.forced end
  if f.is_player then return T.perimetre_on == true end
  return T.perimetre_factions == true
end
local function measured(f) return f.is_player or T.perimetre_factions == true or (f.perim ~= nil and f.perim.forced == true) end

local function state(f)
  local st = f.perim
  if not st then
    st = { rings = {}, posts = {}, next_id = 1, rest = {}, zero = {}, chk = {}, nests = {}, lost = { sens = 0, tur = 0, mur = 0, autre = 0 },
      logs = 0, mlogs = 0, poses = 0, next_scan = 0 }
    f.perim = st
  end
  return st
end

local function plog(f, st, text)
  st.logs = st.logs + 1
  if st.logs <= Pm.LOGS then log("[FO-PERIMETRE] " .. (f.key or "player") .. " : " .. text) end
end

local function sorted_pts(list)
  table.sort(list, function(a, b)
    if a.x ~= b.x then return a.x < b.x end
    if a.y ~= b.y then return a.y < b.y end
    return (a.role or "") < (b.role or "")
  end)
  return list
end

local function area_of(f, extra)
  local h, d = f.hq_pos, Pe.MAX_DIST + (extra or 0)
  return { { h.x - d, h.y - d }, { h.x + d, h.y + d } }
end

--- Points sensibles de l'équipe { x, y, role } (le coffre du QG en « qg »), triés.
local function read_points(f, surface)
  types()
  local pts = {}
  for _, e in ipairs(surface.find_entities_filtered({ area = area_of(f), force = f.force, type = SENS_TYPES })) do
    if e.valid then pts[#pts + 1] = { x = e.position.x, y = e.position.y, role = R.ENTITY_ROLE[e.type] } end
  end
  sorted_pts(pts)
  table.insert(pts, 1, { x = f.hq_pos.x, y = f.hq_pos.y, role = "qg" })
  return pts
end

--- Tourelles de la force { x, y, range, armed }, triées (la portée couvre un point sensible jusqu'au bord de la zone).
local function read_turrets(f, surface)
  local out = {}
  for _, t in ipairs(surface.find_entities_filtered({ area = area_of(f, 24), force = f.force, type = R.TURRET_TYPES })) do
    if t.valid then
      local inv = t.type == "ammo-turret" and t.get_inventory(defines.inventory.turret_ammo) or nil
      local armed = (inv == nil) or inv.get_item_count() > 0
      out[#out + 1] = { x = t.position.x, y = t.position.y, range = range_of(t.name), armed = armed }
    end
  end
  return sorted_pts(out)
end

--- Tourelles du périmètre vivantes (propriétaire « perim… »).
local function held(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      local o = State.owner(id)
      if o and type(o.oid) == "string" and o.oid:sub(1, #Pm.OID) == Pm.OID then n = n + 1 end
    end
  end
  return n
end

--- Menaces { x, y, w } : cellules attaquées de la mémoire du front (score), nids relevés (Pe.W_NEST).
local function threats(f, st)
  local out = {}
  local fm = f.front_mem
  if fm and fm.mem and fm.mem.cells then
    for _, c in ipairs(Fr.top(fm.mem, 64, 1)) do out[#out + 1] = { x = c.x, y = c.y, w = c.score } end
  end
  for _, n in ipairs(st.nests or {}) do out[#out + 1] = { x = n.x, y = n.y, w = Pe.W_NEST } end
  return out
end

local function base_range()
  return range_of(T.turret)
end

local function wall_of(f)
  local b = f.build
  local enc = b and b.enc
  return enc and enc.bounds or nil
end

local function turret_xy(list)
  local out = {}
  for _, t in ipairs(list) do out[#out + 1] = { x = t.x, y = t.y } end
  return out
end

local function plan(f, st, surface, tick)
  st.plan_tick = tick
  local rest = {}
  for _, key in ipairs(State.sorted_keys(st.rest)) do
    if st.rest[key] > tick then rest[key] = true else st.rest[key] = nil end
  end
  local function allow(post)
    local c = st.chk[post.key]
    if c and tick - c.t < Pm.CHECK_EVERY then return c.ok end
    local ok = surface.find_nearest_enemy({ position = { x = post.x, y = post.y }, max_distance = Pm.CALM_R, force = f.force }) == nil
    st.chk[post.key] = { t = tick, ok = ok }
    return ok
  end
  local p = Pe.plan({ posts = st.posts, turrets = turret_xy(read_turrets(f, surface)), threats = threats(f, st), rest = rest, allow = allow })
  st.pick, st.served, st.total = p.pick, p.served, p.total
  if p.pick then
    for _, post in ipairs(st.posts) do if post.key == p.pick.key then post.want = p.pick.want end end
    local sig = p.pick.key .. ":" .. p.pick.have
    if st.last_pick ~= sig then
      st.last_pick = sig
      plog(f, st, string.format("poste %s (%s%s) en (%.0f, %.0f) a %.1f min : %d tourelle(s) a moins de %d tuiles sur %d voulue(s), menace %d ; postes servis %d sur %d",
        p.pick.key, p.pick.kind, p.pick.ring and (" anneau " .. p.pick.ring) or "", p.pick.x, p.pick.y, tick / 3600, p.pick.have, Pe.HAVE_R,
        p.pick.want, p.pick.threat, p.served, p.total))
    end
  end
end

--- Relevé : mesure (toujours), anneaux et postes (interrupteur allumé).
local function scan(f, st, surface, tick, on)
  local pts = read_points(f, surface)
  local tur = read_turrets(f, surface)
  local nests = {}
  for _, e in ipairs(surface.find_entities_filtered({ area = area_of(f, Pe.THREAT_R), force = "enemy", type = "unit-spawner" })) do
    if e.valid then nests[#nests + 1] = { x = e.position.x, y = e.position.y } end
  end
  st.nests = sorted_pts(nests)
  if on then
    local ev, info = Pe.update(st, { points = pts, turrets = tur, hq = f.hq_pos, wall = wall_of(f), range = base_range(), tick = tick })
    for _, e in ipairs(ev) do
      plog(f, st, string.format("anneau %d %s a %.1f min : (%.0f, %.0f) a (%.0f, %.0f), %d poste(s) ; %d point(s) sensible(s) au coeur",
        e.ring, e.what == "mur" and "sur le mur de l'enceinte (rentre de " .. Pe.INSET .. " tuiles)" or (e.what == "remplace" and "agrandi" or "ne"),
        tick / 3600, e.box[1], e.box[2], e.box[3], e.box[4], e.n, info.core))
    end
    if info.new > 0 or info.dropped > 0 then
      plog(f, st, string.format("postes aux points sensibles a %.1f min : %d nouveau(x), %d retire(s)", tick / 3600, info.new, info.dropped))
    end
    plan(f, st, surface, tick)
  end
  -- mesure (lecture seule)
  local ca = Pe.coverage(pts, tur, true)
  local armed = 0
  for _, t in ipairs(tur) do if t.armed then armed = armed + 1 end end
  local parts = {}
  for _, c in ipairs(Pe.CATS) do parts[#parts + 1] = string.format("%s %d/%d", c, ca.cats[c].c, ca.cats[c].n) end
  local nring, npoint = 0, 0
  for _, p in ipairs(st.posts) do if p.kind == "ring" then nring = nring + 1 else npoint = npoint + 1 end end
  st.mlogs = st.mlogs + 1
  if st.mlogs <= Pm.MLOGS then
    log(string.format("[FO-PERIMETRE] %s : mesure a %.1f min : couverture armee %d %% du poids (%d/%d) ; nombre : %s ; tourelles %d dont armees %d, " ..
      "isolees %d, du perimetre %d ; anneaux %d, postes %d point(s) + %d d'anneau (servis %s sur %s) ; perdus sous l'ennemi : sensibles %d, " ..
      "tourelles %d, murs %d, autres %d ; regle %s", f.key or "player", tick / 3600, Pe.pct(ca.wc, ca.w), ca.wc, ca.w, table.concat(parts, " "),
      #tur, armed, Pe.isolated(tur), held(f), #st.rings, npoint, nring, tostring(st.served or 0), tostring(st.total or 0),
      st.lost.sens, st.lost.tur, st.lost.mur, st.lost.autre, on and "allumee" or "eteinte"))
  end
end

function Pm.view(f, fortify_open)
  if f.eliminated or not measured(f) or not (f.hq and f.hq.valid and f.hq_pos) then return nil end
  local tick = game.tick
  local st = state(f)
  local surface = f.hq.surface
  local on = enabled(f)
  if tick >= st.next_scan then
    st.next_scan = (math.floor(tick / Pe.EVERY) + 1) * Pe.EVERY
    scan(f, st, surface, tick, on)
  elseif on and (st.plan_tick == nil or tick - st.plan_tick >= Pm.PLAN_EVERY) then
    plan(f, st, surface, tick)
  end
  if not on then return nil end
  return { pick = st.pick, busy = fortify_open and fortify_open[Pm.OID] or false, held = held(f) }
end

local function find_post(st, key)
  for _, p in ipairs(st.posts) do if p.key == key then return p end end
  return nil
end

function Pm.place(f, surface, task, carrier)
  local st = state(f)
  local tick = game.tick
  local post = task.perim and find_post(st, task.perim)
  st.plan_tick = nil -- le poste à servir est recalculé à la pensée suivante
  if not post then
    plog(f, st, string.format("pose : poste %s disparu (relevé) a %.1f min", tostring(task.perim), tick / 3600))
    return 0
  end
  -- tourelles déjà là MAINTENANT (une autre pose a pu servir le poste depuis la commande) : jamais plus que le groupe voulu
  local have = surface.count_entities_filtered({ position = { x = post.x, y = post.y }, radius = Pe.HAVE_R, force = f.force, type = R.TURRET_TYPES })
  local want = post.want or Pe.GROUP
  local count = math.min(task.items[1][2], math.max(0, want - have))
  if count <= 0 then
    plog(f, st, string.format("pose : poste %s deja servi (%d tourelle(s) sur %d) a %.1f min", post.key, have, want, tick / 3600))
    return 0
  end
  local n = Outposts.fortify_at(f, surface, Pm.OID .. post.key, Pe.sites(post), count, carrier,
    function(pos) return Pe.accepts(post, pos.x, pos.y) end)
  st.poses = st.poses + n
  if n == 0 then
    st.zero[post.key] = math.min(Pe.REST_MAX, (st.zero[post.key] or 0) + 1)
    st.rest[post.key] = tick + Pe.rest_ticks(st.zero[post.key])
  else
    st.zero[post.key] = nil
  end
  plog(f, st, string.format("pose de %d tourelle(s) sur %d au poste %s (%s%s) en (%.0f, %.0f) a %.1f min (cumul %d)%s", n, count, post.key, post.kind,
    post.ring and (" anneau " .. post.ring) or "", post.x, post.y, tick / 3600, st.poses,
    n == 0 and string.format(" : aucune place a moins de %d tuiles, poste au repos %.0f min", Pe.ACCEPT, Pe.rest_ticks(st.zero[post.key]) / 3600) or ""))
  return n
end

function Pm.on_lost(f, key, cause)
  local st = state(f)
  local tick = game.tick
  if key then st.rest[key] = tick + T.lethal_ticks end
  st.plan_tick = nil
  plog(f, st, string.format("PNJ tue en allant au poste %s (%s) a %.1f min ; poste au repos %.0f min", tostring(key), tostring(cause), tick / 3600,
    T.lethal_ticks / 3600))
end

--- Bâtiment d'une équipe mesurée détruit par une force ennemie : compteur de la mesure (aucune décision n'en dépend).
local function on_died(e)
  local ent = e.entity
  local killer = e.force
  if not (ent and ent.valid and ent.force and killer) then return end
  local fname = ent.force.name
  if killer.name == fname or ent.force.get_cease_fire(killer) then return end
  local f = (fname == "player") and State.faction("player") or State.by_force(fname)
  local st = f and f.perim
  if not st then return end
  local role = R.ENTITY_ROLE[ent.type]
  if not role or role == "main" then return end
  if Pe.role_w(role) > 0 then st.lost.sens = st.lost.sens + 1
  elseif ent.type == "wall" or ent.type == "gate" then st.lost.mur = st.lost.mur + 1
  elseif role == "militaire" then st.lost.tur = st.lost.tur + 1
  else st.lost.autre = st.lost.autre + 1 end
end
Events.on(defines.events.on_entity_died, on_died)

--- Lecture seule pour les bancs : état du périmètre d'une équipe (« player » : votre équipe), copie en tables simples ; nil sans état.
remote.add_interface("fo-perimetre", {
  --- Banc témoin : force la règle (vrai/faux) pour une équipe existante, la mesure reste ; nil rend l'interrupteur de la configuration.
  --- Rend vrai si l'équipe existe (à appeler AVANT sa première pensée : à l'init du banc, après la pose du coffre).
  set_enabled = function(key, on)
    local f = (key == nil or key == "player") and State.faction("player") or State.faction(key)
    if not f then return false end
    state(f).forced = on
    log(string.format("[FO-PERIMETRE] %s : regle forcee %s par un banc (tick %d)", f.key or "player", tostring(on), game.tick))
    return true
  end,
  status = function(key)
    local f = (key == nil or key == "player") and State.faction("player") or State.faction(key)
    local st = f and f.perim
    if not st then return nil end
    local posts, rings = {}, {}
    for _, p in ipairs(st.posts) do
      posts[#posts + 1] = { key = p.key, kind = p.kind, ring = p.ring, x = p.x, y = p.y, want = p.want, w = p.w }
    end
    for _, r in ipairs(st.rings) do rings[#rings + 1] = { r.x0, r.y0, r.x1, r.y1, wall = r.wall } end
    return { rings = rings, posts = posts, poses = st.poses, held = held(f),
      lost = { sens = st.lost.sens, tur = st.lost.tur, mur = st.lost.mur, autre = st.lost.autre } }
  end,
})

return Pm
