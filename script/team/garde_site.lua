--[[
  Lot PERIMETRE2 « garde des sites », côté RUNTIME (règle pure : shared/team/garde_site.lua ; diagnostic et proposition :
  fo-logs/2026-11-04_PERIMETRE2/RAPPORT.md ; accord du lead et QCM du DC du 4/11 18 h 05 « Oui, enceinte et avant-postes »). Votre équipe.

    - on_entity_died : un bâtiment de votre équipe détruit près d'un avant-poste : la vague (unités ennemies à 30 tuiles) est notée au site.
    - on_player_mined_entity / on_robot_mined_entity : un mur retiré par le JOUEUR sur une tuile de mur de l'équipe (enceinte, îlot, avant-poste) :
      tuile RENDUE au joueur pour toujours (f.build.walls_released), pièce abandonnée (e.dropped) : jamais reposée ni replanifiée.
    - Build.wall_mask (crochet posé ici, lu par plan_enceinte de script/team/build.lua) : tuiles jamais murées : rendues, ou dans l'usine du
      joueur (à moins de Gs.PLAYER_GAP tuiles d'un bâtiment de la force qui n'est pas à l'équipe).
    - Build.outpost_walls (crochet, appelé par Build.space_step toutes les 30 s) : anneau de murs autour d'un avant-poste ATTAQUÉ, segment par
      segment, payé en pierre (murs fabriqués par la machinerie de l'enceinte), réparé comme l'enceinte.
    - Gd.view (Team.view) : le site à servir (G1) et le budget (G2 : fer accordé par DEPENSES, sinon repli) ; écrit f.team.depenses.defense_want.
    - Gd.place (tâche « fortify » du poste « garde ») : le groupe, par Outposts.fortify_at (propriétaire « garde<site> », ravitaillement par
      les tâches « refill » existantes). Gd.on_lost : porteur tué -> site au repos.
  Journal [FO-PERIMETRE] : une ligne par cause. État f.garde (nombres, chaînes, tables simples ; créé dans un événement, jamais à on_load).
  Déterminisme : listes triées, aucun `pairs` dans une décision, aucun temps mesuré.
]]
local Events = require("script.core.events")
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local P = require("shared.team.plan")
local Fr = require("shared.team.front")
local Gs = require("shared.team.garde_site")
local Outposts = require("script.faction.outposts")
local Build = require("script.team.build")
local Rsv = require("script.ai3.reserve")
local Stock = require("script.team.stock")
local Enc = require("shared.team.enceinte")
-- Budget de DEPENSES (lot parallèle, pas encore dans main) : chargé au CHARGEMENT du fichier (F24) ; absent ou d'une autre forme : repli.
local okDep, Dep = pcall(require, "script.ai3.depenses")
if not (okDep and type(Dep) == "table" and type(Dep.defense) == "function") then Dep = nil end

local Gd = {}

Gd.OID = "garde"
Gd.PLAN_EVERY = 600      -- ticks : le site à servir est recalculé au plus aussi souvent (et après chaque pose)
Gd.CALM_R = Fr.CALM_R    -- tuiles : pas de pose tant qu'un ennemi est plus près du groupe
Gd.REST = 7200           -- ticks : repos d'un site après une pose nulle
Gd.LOGS = 150            -- lignes [FO-PERIMETRE] au plus

local function iron_key() return T.outposts.iron.product end
local function stone_key() return T.outposts.stone and T.outposts.stone.product or nil end

local function state(f)
  local st = f.garde
  if not st then
    st = { waves = {}, rest = {}, picks = {}, logs = 0, poses = 0, walls = { segs = {}, claimed = {}, rings = {}, done = {} } }
    f.garde = st
  end
  return st
end

local function glog(f, st, text)
  st.logs = st.logs + 1
  if st.logs <= Gd.LOGS then log("[FO-PERIMETRE] " .. (f.key or "player") .. " : " .. text) end
end

--- Une entité de la force du joueur est-elle à votre équipe ? (propriétaire, adoptée, tuile réservée par le plan directeur, coffre, PNJ)
function Gd.team_owned(f, ent)
  if ent.type == "character" then return true end
  if f.hq and f.hq.valid and ent == f.hq then return true end
  local u = ent.unit_number
  if u then
    local o = State.owner(u)
    if o and o.f == f.id then return true end
    if f.adopt and f.adopt.units and f.adopt.units[u] then return true end
  end
  local b = f.build
  if b and b.occ then
    local p = ent.position
    if b.occ[P.tkey(math.floor(p.x), math.floor(p.y))] then return true end
  end
  return false
end

local function team_of(force_name)
  if force_name == "player" then return State.faction("player") end
  return State.by_force(force_name)
end

---------------------------------------------------------------------------------------------------
-- Vagues vues aux avant-postes
---------------------------------------------------------------------------------------------------
local function on_died(e)
  local ent, killer = e.entity, e.force
  if not (T.garde_site_on and ent and ent.valid and ent.force and killer) then return end
  local force = ent.force
  if force.name ~= "player" or killer.name == force.name or force.get_cease_fire(killer) then return end
  local f = State.faction("player")
  if not (f and f.outposts and not f.eliminated) then return end
  if ent.type == "character" or not Gd.team_owned(f, ent) then return end
  local pos = ent.position
  local best, bid
  for _, oid in ipairs(State.sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    if o and o.pos then
      local d = (o.pos.x - pos.x) ^ 2 + (o.pos.y - pos.y) ^ 2
      if d <= 40 * 40 and (best == nil or d < best) then best, bid = d, oid end
    end
  end
  if not bid then return end
  local n = 0
  for _, u in ipairs(ent.surface.find_entities_filtered({ position = pos, radius = 30, type = "unit" })) do
    if u.valid and u.force.name ~= force.name and not force.get_cease_fire(u.force) then n = n + 1 end
  end
  local st = state(f)
  local w = st.waves[bid]
  if w and Gs.wave_live(w.tick, e.tick) then
    if n > w.n then w.n = n end
    w.tick = e.tick
  else
    st.waves[bid] = { n = n, tick = e.tick }
  end
  st.plan_tick = nil
end
Events.on(defines.events.on_entity_died, on_died)

---------------------------------------------------------------------------------------------------
-- Murs rendus au joueur, usine du joueur
---------------------------------------------------------------------------------------------------
local function on_mined(e)
  local ent = e.entity
  if not (ent and ent.valid and (ent.type == "wall" or ent.type == "gate") and ent.force and ent.force.name == "player") then return end
  local f = State.faction("player")
  local b = f and f.build
  if not b then return end
  local tx, ty = math.floor(ent.position.x), math.floor(ent.position.y)
  b.walls_released = b.walls_released or {}
  local k = P.tkey(tx, ty)
  if b.walls_released[k] then return end
  b.walls_released[k] = true
  local hit = 0
  for _, pid in ipairs(b.order or {}) do
    local p = b.projects[pid]
    if p and p.spec and p.spec.enceinte then
      for _, pe in ipairs(p.ents or {}) do
        if pe.wall and not pe.dropped and math.floor(pe.x) == tx and math.floor(pe.y) == ty then
          pe.built, pe.dropped = true, true
          p.dropped = (p.dropped or 0) + 1
          hit = hit + 1
        end
      end
    end
  end
  local st = state(f)
  glog(f, st, string.format("mur retire par le joueur en (%d, %d) a %.1f min : tuile rendue au joueur pour toujours (%d piece(s) de mur de l'equipe abandonnee(s), jamais reposee(s))",
    tx, ty, game.tick / 3600, hit))
end
Events.on(defines.events.on_player_mined_entity, on_mined)
Events.on(defines.events.on_robot_mined_entity, on_mined)

--- Crochet de plan_enceinte (script/team/build.lua) : rend une fonction (tx, ty) -> raison ou nil, pour les tuiles jamais murées.
function Gd.wall_mask(f, surface, areas)
  local b = f.build
  local released = b and b.walls_released or {}
  local boxes = {}
  if f.is_player then
    local g = Gs.PLAYER_GAP
    for _, a in ipairs(areas or {}) do
      for _, ent in ipairs(surface.find_entities_filtered({ area = { { a[1] - g, a[2] - g }, { a[3] + g, a[4] + g } }, force = f.force })) do
        if ent.valid and not Gd.team_owned(f, ent) then
          local bb = ent.bounding_box
          boxes[#boxes + 1] = { x0 = bb.left_top.x, y0 = bb.left_top.y, x1 = bb.right_bottom.x, y1 = bb.right_bottom.y }
        end
      end
    end
  end
  return function(tx, ty)
    if released[P.tkey(tx, ty)] then return "rendue" end
    if #boxes > 0 and Gs.in_player_zone(tx, ty, boxes) then return "joueur" end
    return nil
  end
end
Build.wall_mask = function(f, surface, areas)
  if not (f.is_player and T.enceinte_joueur) or f.garde_temoin then return nil end
  return Gd.wall_mask(f, surface, areas)
end

---------------------------------------------------------------------------------------------------
-- G3 : murs des avant-postes attaqués
---------------------------------------------------------------------------------------------------
local function outpost_box(f, surface, o, oid)
  local x0, y0, x1, y1
  for _, ent in ipairs(surface.find_entities_filtered({ position = o.pos, radius = 40, force = f.force })) do
    local u = ent.valid and ent.unit_number
    local ow = u and State.owner(u)
    if ow and ow.f == f.id and ow.oid == oid then
      local bb = ent.bounding_box
      local a, c = math.floor(bb.left_top.x), math.floor(bb.left_top.y)
      local d, g = math.ceil(bb.right_bottom.x) - 1, math.ceil(bb.right_bottom.y) - 1
      x0, y0 = x0 and math.min(x0, a) or a, y0 and math.min(y0, c) or c
      x1, y1 = x1 and math.max(x1, d) or d, y1 and math.max(y1, g) or g
    end
  end
  if not x0 then return nil end
  return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

function Gd.walls_step(f, surface, tick, ctx)
  if not (T.garde_walls_on and f.is_player and f.outposts and f.hq_pos) or f.garde_temoin then return end
  local st = state(f)
  local h = st.walls
  local b = f.build
  for i = #h.segs, 1, -1 do
    local p = b.projects[h.segs[i].pid]
    if not p or p.state == "refuse" then
      local sg = table.remove(h.segs, i)
      local why = p and p.reason or "projet perdu"
      if p == nil or why == "materiaux" or why == "place" then
        for _, w in ipairs(sg.walls or {}) do h.claimed[Gs.tkey(w[1], w[2])] = nil end
        h.retry = tick + 5 * 3600
      end
      h.cur_s, h.cur_e = nil, nil
      glog(f, st, string.format("murs de l'avant-poste %s : segment refuse (%s) a %.1f min", tostring(sg.oid), tostring(why), tick / 3600))
    end
  end
  ctx.repair(h)
  for _, sg in ipairs(h.segs) do
    local p = b.projects[sg.pid]
    if p and p.state ~= "fini" and p.state ~= "refuse" then return end -- un segment à la fois
  end
  if tick < (h.retry or 0) then return end
  local equiv = ctx.equiv()
  local cap = Enc.segment_cap(equiv)
  if Dep then
    local g = Dep.defense(f, tick)
    local sk = stone_key()
    if type(g) ~= "table" then
      -- (forme inattendue : repli)
    else
      cap = math.min(cap, math.floor((sk and g[sk] or 0) / Gs.WALL_ITEMS))
    end
  end
  for _, oid in ipairs(State.sorted_keys(st.waves)) do
    local w = st.waves[oid]
    local o = f.outposts[oid]
    if o and o.pos and Gs.wave_live(w.tick, tick) and not h.done[oid] then
      local ring = h.rings[oid]
      if not ring then
        local box = outpost_box(f, surface, o, oid)
        if box then
          ring = { box = box }
          h.rings[oid] = ring
        end
      end
      if ring then
        local rr = Gs.ring(ring.box, f.hq_pos)
        local mask = Gd.wall_mask(f, surface, { { rr.box[1], rr.box[2], rr.box[3], rr.box[4] } })
        local seg, why = Gs.next_segment(rr, h.claimed, cap, function(tx, ty) return mask(tx, ty) ~= nil end)
        if seg then
          local tiles = {}
          for _, t in ipairs(seg.walls) do tiles[#tiles + 1] = { t.tx, t.ty } end
          local id, rwhy = ctx.request({ enceinte = true, ilot = "ap" .. tostring(oid), walls = tiles, side = seg.side, prio = ctx.prio,
            domain = "infrastructures" })
          if id then
            for _, t in ipairs(seg.walls) do h.claimed[Gs.tkey(t.tx, t.ty)] = true end
            h.segs[#h.segs + 1] = { pid = id, n = #tiles, side = seg.side, oid = oid, walls = tiles }
            glog(f, st, string.format("murs de l'avant-poste %s attaque (vague %d) : segment %s de %d murs demande (projet %d), porte de %d tuiles cote %s, stock equivalent %d murs a %.1f min",
              tostring(oid), w.n, seg.side, #tiles, id, Gs.GATE, tostring(rr.gate), equiv, tick / 3600))
          else
            glog(f, st, string.format("murs de l'avant-poste %s : segment non demande (%s) a %.1f min", tostring(oid), tostring(rwhy), tick / 3600))
            h.retry = tick + 5 * 3600
          end
          return
        elseif why == "complet" then
          h.done[oid] = true
          glog(f, st, string.format("murs de l'avant-poste %s complets a %.1f min", tostring(oid), tick / 3600))
        elseif why == "stock" then
          if not h.poor then
            h.poor = true
            glog(f, st, string.format("murs de l'avant-poste %s attendus : plafond %d murs (stock equivalent %d) a %.1f min", tostring(oid), cap, equiv, tick / 3600))
          end
          return
        end
      end
    end
  end
end
Build.outpost_walls = function(f, surface, tick, ctx) return Gd.walls_step(f, surface, tick, ctx) end

---------------------------------------------------------------------------------------------------
-- G1 et G2 : groupes de tourelles
---------------------------------------------------------------------------------------------------
local function held(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      local o = State.owner(id)
      if o and type(o.oid) == "string" and o.oid:sub(1, #Gd.OID) == Gd.OID then n = n + 1 end
    end
  end
  return n
end

local function threats_near(f, surface, site)
  local out = {}
  local fm = f.front_mem
  if fm and fm.mem and fm.mem.cells then
    for _, c in ipairs(Fr.top(fm.mem, 64, 1)) do out[#out + 1] = { x = c.x, y = c.y, w = c.score } end
  end
  local nests = surface.find_entities_filtered({ position = site, radius = 64, force = "enemy", type = "unit-spawner" })
  local list = {}
  for _, e in ipairs(nests) do if e.valid then list[#list + 1] = { x = e.position.x, y = e.position.y } end end
  table.sort(list, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
  for _, n in ipairs(list) do out[#out + 1] = { x = n.x, y = n.y, w = 500 } end
  return out
end

--- Fer accordé par DEPENSES (nil sans le module ou réponse d'une autre forme : repli).
local function granted(f, tick)
  if not Dep then return nil end
  local g = Dep.defense(f, tick)
  if type(g) ~= "table" then return nil end
  return g[iron_key()] or 0
end

local function free_iron(f, tick)
  local inp = Rsv.input(f, tick)
  if not inp then return 0 end
  return inp.covered and (inp.free[iron_key()] or 0) or 0
end

function Gd.view(f, fortify_open)
  if not (T.garde_site_on and f.is_player) or f.garde_temoin or f.eliminated or not (f.hq and f.hq.valid and f.hq_pos) then return nil end
  local tick = game.tick
  local st = state(f)
  local busy = fortify_open and fortify_open[Gd.OID] or false
  if st.view and st.plan_tick and tick - st.plan_tick < Gd.PLAN_EVERY then
    st.view.busy = busy
    return st.view
  end
  st.plan_tick = tick
  local surface = f.hq.surface
  local rest = {}
  for _, k in ipairs(State.sorted_keys(st.rest)) do
    if st.rest[k] > tick then rest[k] = true else st.rest[k] = nil end
  end
  local sites, missing = {}, 0
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    local o = f.outposts[oid]
    if o and o.pos and (o.drills or 0) > 0 then
      local w = st.waves[oid]
      local wave = (w and Gs.wave_live(w.tick, tick)) and w.n or 0
      -- le GROUPE est du côté des attaques : « déjà là » = tourelles à moins de Gs.ACCEPT de son centre (pas les tourelles éparses du site)
      -- direction FIGÉE dès la première pose (banc lot-dc : la direction suivait la mémoire du front et le groupe changeait de place)
      local fixed = st.dirs and st.dirs[oid]
      local nx, ny
      if fixed then nx, ny = fixed.nx, fixed.ny else nx, ny = Gs.dir({ x = o.pos.x, y = o.pos.y }, threats_near(f, surface, o.pos), f.hq_pos) end
      local g = Gs.spots({ x = o.pos.x, y = o.pos.y }, nx, ny)
      local have = surface.count_entities_filtered({ position = g, radius = Gs.ACCEPT, force = f.force, type = R.TURRET_TYPES })
      local want = Gs.want(wave)
      if have < want then missing = missing + (want - have) end
      sites[#sites + 1] = { key = oid, x = o.pos.x, y = o.pos.y, have = have, want = want, wave = wave, w = o.drills, nx = nx, ny = ny, gx = g.x, gy = g.y }
    end
  end
  local pick, served, total = Gs.pick(sites, rest)
  local g_iron, free = granted(f, tick), free_iron(f, tick)
  -- demande écrite pour DEPENSES (lue par sa règle quand elle est là ; sans elle, inoffensive)
  local walls_wanted = 0
  for _, oid in ipairs(State.sorted_keys(st.waves)) do
    local w = st.waves[oid]
    if Gs.wave_live(w.tick, tick) and not st.walls.done[oid] then walls_wanted = walls_wanted + 60 end
  end
  f.team.depenses = f.team.depenses or { on = true }
  f.team.depenses.defense_want = Gs.want_table(iron_key(), missing, Gs.UNIT_IRON, stone_key(), walls_wanted)
  local out = { busy = busy, held = held(f), granted = g_iron, free = free, served = served, total = total }
  if pick then
    local nx, ny = pick.nx, pick.ny
    local g = { x = pick.gx, y = pick.gy }
    local calm = surface.find_nearest_enemy({ position = g, max_distance = Gd.CALM_R, force = f.force }) == nil
    if calm then
      st.picks[pick.key] = { nx = nx, ny = ny, want = pick.want }
      out.pick = { key = pick.key, x = g.x, y = g.y, have = pick.have, want = pick.want, wave = pick.wave }
      local sig = pick.key .. ":" .. pick.have .. ":" .. pick.want
      if st.last_sig ~= sig then
        st.last_sig = sig
        glog(f, st, string.format("groupe voulu a l'avant-poste %s (vague vue %d) : %d tourelle(s) a %d tuiles du groupe sur %d, groupe en (%.0f, %.0f) cote (%.2f, %.2f) ; budget : fer %s, accorde par DEPENSES %s, libre hors besoin %d, garde vivante %d ; sites servis %d sur %d a %.1f min",
          tostring(pick.key), pick.wave, pick.have, Gs.ACCEPT, pick.want, g.x, g.y, nx, ny, tostring(Stock.count(f, iron_key())),
          g_iron == nil and "absent (repli 30 %)" or tostring(g_iron), free, out.held, served, total, tick / 3600))
      end
    end
  end
  st.view = out
  return out
end

function Gd.place(f, surface, task, carrier)
  local st = state(f)
  local tick = game.tick
  st.plan_tick = nil
  local key = task.garde
  local o = key and f.outposts and f.outposts[key]
  local pk = key and st.picks[key]
  if not (o and o.pos and pk) then
    glog(f, st, string.format("pose : avant-poste %s disparu a %.1f min", tostring(key), tick / 3600))
    return 0
  end
  local site = { x = o.pos.x, y = o.pos.y }
  local g, spots = Gs.spots(site, pk.nx, pk.ny)
  local have = surface.count_entities_filtered({ position = g, radius = Gs.ACCEPT, force = f.force, type = R.TURRET_TYPES })
  local count = math.min(task.items[1][2], math.max(0, (pk.want or Gs.GROUP_MIN) - have))
  if count <= 0 then
    glog(f, st, string.format("pose : avant-poste %s deja garde (%d tourelle(s)) a %.1f min", tostring(key), have, tick / 3600))
    return 0
  end
  local n = Outposts.fortify_at(f, surface, Gd.OID .. tostring(key), spots, count, carrier, function(pos) return Gs.accepts(g, pos.x, pos.y) end)
  st.poses = st.poses + n
  if n == 0 then st.rest[key] = tick + Gd.REST end
  if n > 0 then
    st.dirs = st.dirs or {}
    if not st.dirs[key] then st.dirs[key] = { nx = pk.nx, ny = pk.ny } end -- le groupe garde sa place
  end
  glog(f, st, string.format("pose de %d tourelle(s) sur %d en groupe a l'avant-poste %s, autour de (%.0f, %.0f) a %.1f min (cumul %d)%s", n, count,
    tostring(key), g.x, g.y, tick / 3600, st.poses, n == 0 and " : aucune place, site au repos 2 min" or ""))
  return n
end

--- Banc témoin : la garde des sites, les murs des avant-postes et l'enceinte de votre équipe éteints pour cette partie (état de la sauvegarde :
--- f.garde_temoin), comme la 0.6.50 ; à appeler à l'init du banc, après la pose du coffre. Rend vrai si l'équipe existe.
remote.add_interface("fo-garde", {
  temoin = function()
    local f = State.faction("player")
    if not f then return false end
    f.garde_temoin = true
    log(string.format("[FO-PERIMETRE] player : banc temoin, garde des sites, murs et enceinte de l'equipe eteints (tick %d)", game.tick))
    return true
  end,
})

function Gd.on_lost(f, key, cause)
  local st = state(f)
  local tick = game.tick
  if key then st.rest[key] = tick + T.lethal_ticks end
  st.plan_tick = nil
  glog(f, st, string.format("PNJ tue en allant garder l'avant-poste %s (%s) a %.1f min ; site au repos %.0f min", tostring(key), tostring(cause),
    tick / 3600, T.lethal_ticks / 3600))
end

return Gd
