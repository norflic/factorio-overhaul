--[[
  Lot X10-GEL, branchement GARNISONS (Q7 ; DC, QCM du 7/11, 18 h 33 : « Oui, figées hors de vue (Recommandé) » pour les soldats).
  fo-logs/2026-11-07_X10/L1_CRITERES.md §3.12, critères C12 à C18. LA règle de zone et de réveil est celle des usines
  (shared/faction/gel.lua : Gel.decide_all) ; ce fichier ne lui donne que ses entrées propres.

  Ce qui est figé (`active = false` SEULEMENT ; `destructible` n'est jamais touché : un coup doit pouvoir arriver, et réveiller) :
  un soldat d'une faction (f.soldiers, script/faction/military.lua), d'un NOM de soldat des factions (prototypes/faction.lua ; les
  robots et votre équipe : jamais), sans groupe, en rôle de garnison (au QG, garde, patrouille : script/ai3/soldats.lua), arrivé à
  son point, en pleine santé, avec le même ordre depuis Gel.CALM ticks (G.soldier_unfit), à un POSTE (son point d'ordre) que la
  règle commune fige (aucune cause de faction, aucun joueur à moins de 256 tuiles, aucune menace locale, Gel.CALM ticks de calme).

  Réveil :
    - au guet (toutes les G.GUET ticks) : cause de faction (S10), joueur à moins de 224 tuiles du poste, menace locale (ennemi mobile à
      moins de G.HAZARD_R du poste, de G.HQ_R du QG, ou dans la boîte d'un amas de tourelles élargie de la portée + G.TURRET_MARGIN ;
      tourelle qui tire ; alerte d'armée ; alerte de site), ordre changé ou groupe ;
    - AU TICK MÊME : un coup reçu par un bâtiment, une tourelle, un soldat ou un PNJ de l'équipe (on_entity_damaged, filtre du mod :
      script/team/reparation.lua, noms de Ga.filter_names) ; une mort dans l'équipe (Events.on_died) ; une commande donnée au soldat
      (crochet Gel.before_command, script/ai3/soldats.lua et script/faction/military.lua).
  Bancs : groupes de garnison posés par l'interface « fo-gel » (script/faction/gel_banc.lua), soumis à la même règle.

  État (global, namespace « gel », champ `gar`, créé au premier guet) :
    v[vid] = { n, units = { [unit] = { e, post, t } } }  soldats figés par vue (vid : numéro de faction ou « banc:<nom> ») ;
    where[unit] = vid ; n = total ; el[unit] = { t, post } (apte depuis) ; posts[vid][clé] = { st, pt, boxes } ;
    lists[vid] = { t, enemies, clusters, turrets } (relus toutes les Ga.RELIST ticks) ; hit[vid], lost[vid] (dernier coup, perte) ;
    bancs[nom] ; bforce[force] = vid ; stats.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Profiler = require("script.core.profiler")
local G = require("shared.faction.gel")
local A = require("shared.ai3.armee")
local Gel = require("script.faction.gel")
local C = require("script.ai3.comportement")
local Commander = require("script.faction.commander") -- Commander.army_out (S10) ; requis au chargement, après commander

local Ga = {}

Ga.ON = true
Ga.RELIST = 3600 -- forces ennemies, amas de tourelles : relus chaque minute
Ga.CELL = 64     -- amas de tourelles : une cellule de 64 tuiles
Ga.HOME_DY = 14  -- point de la garnison du QG : QG + (0, 14) (script/ai3/soldats.lua, home)
Ga.MOBILE = { "unit", "character", "car", "spider-vehicle" }

local NAMES = Gel.SOLDIER_NAMES -- noms des soldats des factions : les seuls qui peuvent être figés

--- Clés triées d'une table : nombres puis chaînes (les vues mêlent numéros de faction et « banc:<nom> »).
local function keys(t)
  local ks = {}
  for k in next, t do ks[#ks + 1] = k end
  table.sort(ks, function(x, y)
    local tx, ty = type(x), type(y)
    if tx ~= ty then return tx < ty end
    return x < y
  end)
  return ks
end

local function GA0()
  local g = Gel.state()
  return g and g.gar
end

local function GA()
  local g = Gel.state()
  if not g then return nil end
  local a = g.gar
  if not a then
    a = { n = 0, v = {}, where = {}, el = {}, posts = {}, lists = {}, hit = {}, lost = {}, bancs = {}, bforce = {},
      stats = { gel = 0, reveil = 0, why = {}, dmg = 0, dmg_soldat = 0, requetes = 0 }, count = false }
    g.gar = a
  end
  return a
end
Ga.A = GA

---------------------------------------------------------------------------------------------------
-- Gel et réveil d'un soldat
---------------------------------------------------------------------------------------------------
local function freeze(a, vid, id, e, post, tick)
  e.active = false
  local V = a.v[vid]
  if not V then
    V = { n = 0, units = {} }
    a.v[vid] = V
  end
  V.units[id] = { e = e, post = post, t = tick }
  V.n, a.n = V.n + 1, a.n + 1
  a.where[id] = vid
  a.el[id] = nil
  a.stats.gel = a.stats.gel + 1
end

local function wake_one(a, vid, id, why)
  local V = a.v[vid]
  local r = V and V.units[id]
  if not r then return false end
  if r.e.valid then r.e.active = true end
  V.units[id] = nil
  V.n, a.n = V.n - 1, a.n - 1
  a.where[id] = nil
  a.el[id] = nil -- l'aptitude repart de zéro : Gel.CALM ticks avant un nouveau gel (pas de battement)
  a.stats.reveil = a.stats.reveil + 1
  a.stats.why[why] = (a.stats.why[why] or 0) + 1
  return true
end

--- Réveille TOUS les soldats figés d'une vue ; le calme de ses postes repart de zéro. Rend le nombre réveillé.
local function wake_view(a, vid, why, tick)
  local V = a.v[vid]
  local n = 0
  if V and V.n > 0 then
    for _, id in ipairs(State.sorted_keys(V.units)) do
      if wake_one(a, vid, id, why) then n = n + 1 end
    end
  end
  local P = a.posts[vid]
  if P then
    for _, k in ipairs(keys(P)) do P[k].st.frozen, P[k].st.calm = false, nil end
  end
  if n > 0 then
    Gel.say("garnison:" .. tostring(vid), string.format("garnison %s : %d soldat(s) reveille(s), cause %s, tick %d", tostring(vid), n, why, tick))
  end
  return n
end
Ga.wake_view = wake_view

-- Crochet de script/faction/gel.lua (Gel.before_command) : un soldat figé qui reçoit une commande est réveillé AVANT.
Gel.wake_unit = function(u, why)
  local a = GA0()
  if not (a and a.n > 0) then return end
  local vid = a.where[u.unit_number]
  if vid then wake_one(a, vid, u.unit_number, why or "ordre") end
end

---------------------------------------------------------------------------------------------------
-- Menaces locales
---------------------------------------------------------------------------------------------------
local RANGE = {} -- portée des tourelles par nom (prototypes : fixe pour la session)
local function range_of(t)
  local name = t.name
  local r = RANGE[name]
  if not r then
    local ap = game.entity_prototypes[name].attack_parameters
    r = (ap and ap.range) or 24
    RANGE[name] = r
  end
  return r
end

local function enemies_of(force_name)
  local me = game.forces[force_name]
  local out = {}
  if not me then return out end
  local names = {}
  for name in pairs(game.forces) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    if name ~= force_name and me.is_enemy(game.forces[name]) then out[#out + 1] = name end
  end
  return out
end

local function lists_of(a, vid, view, tick)
  local L = a.lists[vid]
  if L and tick - L.t < Ga.RELIST then return L end
  local clusters, turrets, by = {}, {}, {}
  for _, id in ipairs(State.sorted_keys(view.turrets or {})) do
    local t = view.turrets[id]
    if t and t.valid then
      local p = t.position
      local r = range_of(t) + G.TURRET_MARGIN
      local k = State.chunk_key(math.floor(p.x / Ga.CELL), math.floor(p.y / Ga.CELL))
      local c = by[k]
      if not c then
        c = { x0 = p.x - r, y0 = p.y - r, x1 = p.x + r, y1 = p.y + r }
        by[k] = c
        clusters[#clusters + 1] = c
      else
        c.x0, c.y0 = math.min(c.x0, p.x - r), math.min(c.y0, p.y - r)
        c.x1, c.y1 = math.max(c.x1, p.x + r), math.max(c.y1, p.y + r)
      end
      turrets[#turrets + 1] = t
    end
  end
  L = { t = tick, enemies = enemies_of(view.force), clusters = clusters, turrets = turrets }
  a.lists[vid] = L
  return L
end

local function count(a, surface, q)
  a.stats.requetes = a.stats.requetes + 1
  return surface.count_entities_filtered(q) > 0
end

--- Menace de FACTION (toute la garnison) : alerte d'armée ou de site, ennemi près du QG ou des tourelles, tourelle qui tire.
local function faction_hazard(a, vid, view, L, tick)
  if view.armee and A.alert_on(view.armee) then return "alerte d'armee" end
  for _, al in ipairs(view.alerts or {}) do
    if (al["until"] or 0) > tick then return "alerte de site" end
  end
  for _, t in ipairs(L.turrets) do
    if t.valid and t.shooting_target ~= nil then return "tourelle qui tire" end
  end
  if #L.enemies == 0 then return nil end
  local surface = view.surface
  if count(a, surface, { position = view.hq, radius = G.HQ_R, type = Ga.MOBILE, force = L.enemies, limit = 1 }) then
    return "ennemi pres du QG"
  end
  for _, c in ipairs(L.clusters) do
    if count(a, surface, { area = { { c.x0, c.y0 }, { c.x1, c.y1 } }, type = Ga.MOBILE, force = L.enemies, limit = 1 }) then
      return "ennemi pres des tourelles"
    end
  end
  return nil
end

--- Menace au POSTE (appelée quand la requête du QG est vide : un poste dont le cercle y est compris n'est pas relu).
local function post_hazard(a, view, L, pt)
  if #L.enemies == 0 then return nil end
  local dx, dy = pt.x - view.hq.x, pt.y - view.hq.y
  if math.sqrt(dx * dx + dy * dy) + G.HAZARD_R <= G.HQ_R then return nil end
  if count(a, view.surface, { position = pt, radius = G.HAZARD_R, type = Ga.MOBILE, force = L.enemies, limit = 1 }) then
    return "ennemi pres du poste"
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Guet d'une vue (une faction ou un groupe de banc)
---------------------------------------------------------------------------------------------------
local function role_of(per, id)
  local ps = per and per[id]
  if not (ps and ps.role) then return "home", nil end
  return ps.role, ps.key
end

--- view = { soldiers = { [unit] = { entity, group } }, per = rôles (t.sd.per) ou nil, hq = {x, y}, surface, force (nom),
--- turrets = { [unit] = entité }, armee, alerts, is_player } ; s = entrées de la règle commune.
local function guet_view(a, vid, view, s, tick)
  local V = a.v[vid]
  local home = { x = view.hq.x, y = view.hq.y + Ga.HOME_DY }
  local P = a.posts[vid]
  if not P then
    P = {}
    a.posts[vid] = P
  end
  -- 1. Soldats par poste ; un soldat figé dont l'ordre a changé (ou qui a un groupe) est réveillé.
  local members, order, seen = {}, {}, {}
  for _, id in ipairs(State.sorted_keys(view.soldiers)) do
    local sl = view.soldiers[id]
    local e = sl.entity
    if e and e.valid then
      seen[id] = true
      local role, key = role_of(view.per, id)
      local garrison = G.GARRISON_ROLES[role] ~= nil and NAMES[e.name] == true
      local post = role == "home" and "home" or (key or role)
      local r = V and V.units[id]
      if r and (sl.group or not garrison or r.post ~= post) then
        wake_one(a, vid, id, sl.group and "groupe" or "ordre")
        r = nil
      end
      if garrison and not sl.group then
        local L = members[post]
        if not L then
          L = {}
          members[post] = L
          order[#order + 1] = post
          if not P[post] then
            local pt = G.soldier_point(key, home)
            P[post] = { st = { frozen = false }, pt = pt, boxes = G.boxes({ pt }) }
          end
        end
        L[#L + 1] = { id = id, e = e, sl = sl, role = role, frozen = r ~= nil }
      else
        a.el[id] = nil
      end
    end
  end
  -- Soldats figés disparus de la liste (morts, retirés) ; postes sans soldat.
  if V and V.n > 0 then
    for _, id in ipairs(State.sorted_keys(V.units)) do
      if not seen[id] then wake_one(a, vid, id, "retire") end
    end
  end
  for _, k in ipairs(keys(P)) do
    if not members[k] then P[k] = nil end
  end
  if #order == 0 then return end
  -- 2. Menaces : seulement sans cause de faction (sinon tout est réveillé par la règle, sans requête).
  local fup = G.faction_cause(s, tick) or type(s.players) ~= "table"
  local fh, L = nil, nil
  if not fup then
    L = lists_of(a, vid, view, tick)
    fh = faction_hazard(a, vid, view, L, tick)
  end
  local posts, pts = {}, {}
  for _, k in ipairs(order) do
    local p = P[k]
    pts[#pts + 1] = p.pt
    local hz = fh
    if not fup and not hz then hz = post_hazard(a, view, L, p.pt) end
    posts[#posts + 1] = { id = k, st = p.st, boxes = p.boxes, hazard = hz }
  end
  -- 3. LA règle commune, poste par poste (raccourci de la faction).
  for _, o in ipairs(G.decide_all(posts, s, G.boxes(pts), tick)) do
    local p = P[o.id]
    if o.action == "fige" then
      p.st.frozen = true
    else
      p.st.frozen = false
      local n = 0
      for _, m in ipairs(members[o.id]) do
        if m.frozen and wake_one(a, vid, m.id, o.cause or "reveil") then
          m.frozen = false
          n = n + 1
        end
      end
      if n > 0 then
        Gel.say("garnison:" .. tostring(vid), string.format("garnison %s, poste %s : %d soldat(s) reveille(s), cause %s, tick %d",
          tostring(vid), o.id, n, tostring(o.cause), tick))
      end
    end
  end
  -- 4. Aptitude des soldats éveillés (postes figés ou au calme) et gel des aptes depuis Gel.CALM ticks.
  local froze = 0
  for _, k in ipairs(order) do
    local p = P[k]
    local counting = p.st.frozen or p.st.calm ~= nil
    for _, m in ipairs(members[k]) do
      if m.frozen then
        if not p.st.frozen then wake_one(a, vid, m.id, "poste eveille") end
      elseif counting then
        local pos = m.e.position
        local dx, dy = pos.x - p.pt.x, pos.y - p.pt.y
        local unfit = G.soldier_unfit({ is_player = view.is_player, group = m.sl.group ~= nil, role = m.role,
          health = m.e.get_health_ratio(), d = math.sqrt(dx * dx + dy * dy) })
        local el = a.el[m.id]
        if unfit then
          a.el[m.id] = nil
        elseif not (el and el.post == k) then
          a.el[m.id] = { t = tick, post = k }
        elseif p.st.frozen and tick - el.t >= G.CALM and Gel.spend(tick, 1) == 1 then
          freeze(a, vid, m.id, m.e, k, tick)
          froze = froze + 1
        end
      else
        a.el[m.id] = nil
      end
    end
  end
  if froze > 0 then
    Gel.say("garnison-gel:" .. tostring(vid), string.format("garnison %s : %d soldat(s) fige(s), %d au total, tick %d", tostring(vid), froze,
      a.v[vid] and a.v[vid].n or 0, tick))
  end
end

local function max_t(x, y)
  if type(x) ~= "number" then return y end
  if type(y) ~= "number" then return x end
  return math.max(x, y)
end

local function guet(tick)
  if not (Ga.ON and Gel.on()) then
    -- Réglage éteint : rien n'est lu ni créé ; ce qui est figé est réveillé.
    local a = GA0()
    if a and a.n > 0 then
      for _, vid in ipairs(keys(a.v)) do wake_view(a, vid, "reglage", tick) end
    end
    return
  end
  local war = State.war()
  local a = GA()
  if not a then return end
  Profiler.start("gel:garnisons")
  local players = Gel.players((war and war.surface) or 1)
  if war and war.active and war.factions then
    for _, fid in ipairs(State.alive()) do
      local f = war.factions[fid]
      if f and f.hq and f.hq.valid and f.hq_pos and f.soldiers and (f.soldiers_count or 0) > 0 then
        local s = Gel.input(f, players, (Commander.army_out(f)))
        if not Ga.ON then s.off = true end
        s.attack_t, s.lost_t = max_t(s.attack_t, a.hit[fid]), max_t(s.lost_t, a.lost[fid])
        local t = C.enabled() and C.team(f) or nil
        local view = { soldiers = f.soldiers, per = t and t.sd and t.sd.per or nil, hq = f.hq_pos, surface = f.hq.surface,
          force = f.force, turrets = f.turrets, armee = f.armee, alerts = t and t.alerts or nil, is_player = f.is_player }
        guet_view(a, fid, view, s, tick)
      elseif f and a.v[fid] and a.v[fid].n > 0 then
        wake_view(a, fid, "faction", tick) -- QG perdu, plus de soldats : rien ne reste figé
      end
    end
  end
  for _, name in ipairs(keys(a.bancs)) do
    local b = a.bancs[name]
    local vid = "banc:" .. name
    local surface = game.surfaces[b.surface or 1]
    if surface then
      local s = { players = b.players or players, threatened_until = b.threatened_until, attack_t = max_t(b.attack_t, a.hit[vid]),
        lost_t = max_t(b.lost_t, a.lost[vid]), base_alert = b.base_alert, army_out = b.army_out or false,
        off = (not Ga.ON) or not Gel.on() }
      local view = { soldiers = b.soldiers, per = b.per, hq = b.hq, surface = surface, force = b.force, turrets = b.turrets,
        armee = b.armee, alerts = b.alerts, is_player = false }
      guet_view(a, vid, view, s, tick)
    end
  end
  Profiler.stop("gel:garnisons")
end
Ga.guet = guet

Events.on_nth_tick(G.GUET, function(e) guet(e.tick) end)

---------------------------------------------------------------------------------------------------
-- Réveil au tick même : coup reçu, mort dans l'équipe
---------------------------------------------------------------------------------------------------
local function vid_of(a, force_name)
  local f = State.by_force(force_name)
  if f then return f.id end
  return a.bforce[force_name]
end

local function on_damaged(e)
  local a = GA0()
  if not a then return end
  local ent = e.entity
  if a.count then
    a.stats.dmg = a.stats.dmg + 1
    if ent and ent.valid and NAMES[ent.name] then a.stats.dmg_soldat = a.stats.dmg_soldat + 1 end
  end
  if a.n == 0 or not (ent and ent.valid) then return end
  local vid = vid_of(a, ent.force.name)
  if vid == nil then return end
  a.hit[vid] = e.tick
  if a.v[vid] and a.v[vid].n > 0 then wake_view(a, vid, "degat", e.tick) end
end
Events.on(defines.events.on_entity_damaged, on_damaged)

Events.on_died(function(e)
  local a = GA0()
  if not (a and a.n > 0) then return end
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local vid = vid_of(a, ent.force.name)
  if vid == nil then return end
  a.lost[vid] = e.tick
  if a.v[vid] and a.v[vid].n > 0 then wake_view(a, vid, "perte", e.tick) end
end, { types = { "unit", "character", "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret", "wall", "gate",
  "container", "furnace", "assembling-machine", "mining-drill", "lab", "electric-pole", "boiler", "generator", "radar", "inserter",
  "transport-belt", "roboport", "rocket-silo" }, ennemi = false })

-- Données changées : tous les soldats figés sont réveillés, l'état est refait au guet suivant.
Events.on_configuration_changed(function()
  local a = GA0()
  if not a then return end
  for _, vid in ipairs(keys(a.v)) do
    for _, id in ipairs(State.sorted_keys(a.v[vid].units)) do
      local r = a.v[vid].units[id]
      if r.e.valid then r.e.active = true end
    end
  end
  local bancs, bforce = a.bancs, a.bforce
  Gel.state().gar = nil
  local b = GA()
  if b then b.bancs, b.bforce = bancs, bforce end
end)

Ga.guet_view, Ga.freeze, Ga.wake_one, Ga.on_damaged = guet_view, freeze, wake_one, on_damaged
return Ga
