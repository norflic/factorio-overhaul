--[[
  Lot EXPERIMENTAUX (3/11) : les robots expérimentaux en jeu. Règles pures : shared/robots/experimentaux.lua ; prototypes :
  prototypes/experimentaux.lua.

  - L'attaque du moteur (rayon, jet, tir d'une unité) ne lève qu'un effet `script` (on_script_trigger_effect) : TOUS les dégâts sont
    appliqués ici par entity.damage, seulement aux forces ENNEMIES du tireur (force.is_enemy : ni amie, ni en cessez-le-feu), et comptés.
  - Mât-Foudre : un coup par cadence (un rayon lève l'effet à chaque intervalle : les suivants sont ignorés), puis l'arc saute vers 2 cibles.
  - Géode : les pointes courent de la Géode à la cible, une tous les 3 ticks (file `jobs`, traitée à chaque tick tant qu'elle n'est pas vide).
  - Sarracénie : le jet principal tombe, le script lance les 2 autres ; Veilleuse : la goutte éclate, plaque de verre.
  - Demi-Vie : usage unique ; fusion, puis zone contaminée (impulsion toutes les 30 ticks, `zones`).
  - Géode et Demi-Vie sont LANCÉES (capsule, on_player_used_capsule) : l'unité est posée au point visé, de la force du joueur, puis envoyée
    sur l'ennemi le plus proche (et renvoyée quand sa commande finit).
  Journal « [FO-XP] » (dégâts appliqués, cibles, tick) seulement si le journal est ouvert (interface « fo-xp », bancs) ; les totaux sont
  toujours tenus (storage, `stats`). Déterminisme : listes triées, aucun pairs, aucun hasard ; `require` en tête (F24).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Xp = require("shared.robots.experimentaux")

local M = {}

Storage.declare("experimentaux", function()
  return { jobs = {}, zones = {}, units = {}, last = {}, fired = {}, stats = {}, journal = false }
end)

local function S() return Storage.ns("experimentaux") end

local NAMES = {}
for _, r in ipairs(Xp.ROBOTS) do NAMES[#NAMES + 1] = r.name end

local CHAIN_BEAM = Xp.PREFIX .. "arc-saut"
local SARR_JET2 = Xp.PREFIX .. "sarracenie-jet2"
local FUSION = Xp.PREFIX .. "demi-vie-fusion"
local ZONE = Xp.PREFIX .. "demi-vie-zone"
local ECLAIR = Xp.PREFIX .. "veilleuse-eclair"
local SPR_POINTE, SPR_POINTE_LUEUR, SPR_VERRE = Xp.PREFIX .. "pointe", Xp.PREFIX .. "pointe-lueur", Xp.PREFIX .. "verre"

---------------------------------------------------------------------------------------------------
-- Comptes et journal
---------------------------------------------------------------------------------------------------
local function stat(id)
  local s = S()
  local st = s.stats[id]
  if not st then
    st = { coups = 0, degats = 0, cibles = 0, tues = 0, sauts = 0, jets = 0 }
    s.stats[id] = st
  end
  return st
end

local function journal(fmt, ...)
  local s = S()
  if s and s.journal then log(Xp.LOG .. " " .. string.format(fmt, ...)) end
end

---------------------------------------------------------------------------------------------------
-- Ennemis et dégâts
---------------------------------------------------------------------------------------------------
--- Forces ennemies d'une force (triées par nom).
local function enemy_forces(force)
  local list = {}
  for _, f in pairs(game.forces) do -- trié juste après
    if f ~= force and force.is_enemy(f) then list[#list + 1] = f.name end
  end
  table.sort(list)
  return list
end

--- Entités ennemies (avec PV) autour d'un point, en candidats { x, y, id, e } (id : numéro d'unité, sinon rang).
local function candidates(surface, force, pos, radius)
  local forces = enemy_forces(force)
  if #forces == 0 then return {} end
  local found = surface.find_entities_filtered({ position = pos, radius = radius, force = forces })
  local out = {}
  for i, e in ipairs(found) do
    if e.valid and e.health and e.destructible then
      out[#out + 1] = { x = e.position.x, y = e.position.y, id = e.unit_number or (1e9 + i), e = e }
    end
  end
  return out
end

--- Dégâts d'un expérimental à une entité ennemie ; rend les dégâts infligés (0 si rien).
local function hit(r, e, amount, dtype, force, src)
  if not (e and e.valid and e.health and e.destructible) or amount <= 0 then return 0 end
  if not force.is_enemy(e.force) then return 0 end
  local before = e.health
  -- le moteur refuse un 4e argument nil (« 'entity': table expected, got nil », banc p1-a) : sans tireur, 3 arguments
  local dealt
  if src and src.valid then dealt = e.damage(amount, force, dtype, src) else dealt = e.damage(amount, force, dtype) end
  dealt = dealt or 0
  local st = stat(r.id)
  st.degats = st.degats + dealt
  st.cibles = st.cibles + 1
  if before > 0 and (not e.valid or e.health <= 0) then st.tues = st.tues + 1 end
  return dealt
end

--- Dégâts de zone autour d'un point (chute linéaire au bord si `edge` < 1). Rend total, nombre de cibles.
local function blast(r, surface, force, src, pos, radius, amount, dtype, edge)
  local list = Xp.in_radius(pos, candidates(surface, force, pos, radius + 2), radius)
  local total, n = 0, 0
  for _, it in ipairs(list) do
    local d = hit(r, it.c.e, Xp.falloff(amount, it.d, radius, edge or 1), dtype, force, src)
    if d > 0 then total, n = total + d, n + 1 end
  end
  return total, n
end

---------------------------------------------------------------------------------------------------
-- Mât-Foudre : l'arc et ses sauts
---------------------------------------------------------------------------------------------------
local function arc(e)
  local src, tgt = e.source_entity, e.target_entity
  if not (src and src.valid and tgt and tgt.valid) then return end
  local r = Xp.robot("mat-foudre")
  local s = S()
  local un = src.unit_number
  local last = s.last[un]
  if last and e.tick - last < r.cooldown - 1 then return end -- un coup par cadence
  s.last[un] = e.tick
  local st = stat(r.id)
  st.coups = st.coups + 1
  local force, surface = src.force, src.surface
  local first = { x = tgt.position.x, y = tgt.position.y, id = tgt.unit_number or 0, e = tgt }
  local total = hit(r, tgt, r.shot, r.dtype, force, src)
  local jumps = Xp.chain(first, candidates(surface, force, tgt.position, r.chain.radius), r.chain.jumps, r.chain.radius)
  local prev = tgt
  for _, j in ipairs(jumps) do
    if prev.valid and j.e.valid then
      surface.create_entity({ name = CHAIN_BEAM, position = prev.position, source = prev, target = j.e, duration = 20 })
    end
    local pos = j.e.valid and j.e.position
    total = total + hit(r, j.e, r.shot * r.chain.share, r.dtype, force, src)
    if pos then surface.create_entity({ name = "small-scorchmark", position = pos }) end
    if j.e.valid then prev = j.e end
  end
  st.sauts = st.sauts + #jumps
  journal("mat-foudre arc #%d degats %.1f sauts %d tick %d", un, total, #jumps, e.tick)
end

---------------------------------------------------------------------------------------------------
-- Géode : le buisson de pointes
---------------------------------------------------------------------------------------------------
local function buisson(e)
  local src, tgt = e.source_entity, e.target_entity
  if not (src and src.valid) then return end
  local r = Xp.robot("geode")
  local to = tgt and tgt.valid and tgt.position or e.target_position
  if not to then return end
  local st = stat(r.id)
  st.coups = st.coups + 1
  local s = S()
  local from = src.position
  s.jobs[#s.jobs + 1] = {
    id = r.id, surface = src.surface.index, force = src.force.name, src = src, un = src.unit_number,
    points = Xp.spike_points({ x = from.x, y = from.y }, { x = to.x, y = to.y }, r.spikes.count), step = 0, next = e.tick + 1, total = 0,
  }
end

local function pas_buisson(job, tick)
  local r = Xp.robot(job.id)
  job.step = job.step + 1
  local p = job.points[job.step]
  local surface = game.surfaces[job.surface]
  local force = game.forces[job.force]
  if not (p and surface and force) then return true end
  rendering.draw_sprite({ sprite = SPR_POINTE, target = { p.x, p.y }, surface = surface, time_to_live = 70, render_layer = "object" })
  rendering.draw_sprite({ sprite = SPR_POINTE_LUEUR, target = { p.x, p.y }, surface = surface, time_to_live = 40, render_layer = "object" })
  local last = job.step >= #job.points
  local amount = last and r.shot or r.shot * r.spikes.share
  local radius = last and r.spikes.final_radius or r.spikes.radius
  local src = job.src
  job.total = job.total + blast(r, surface, force, src, p, radius, amount, r.dtype, 1)
  if last then
    journal("geode buisson #%d degats %.1f tick %d", job.un or 0, job.total, tick)
    return true
  end
  job.next = tick + r.spikes.step_ticks
  return false
end

---------------------------------------------------------------------------------------------------
-- Sarracénie : le crachat (3 jets) ; Veilleuse : la goutte
---------------------------------------------------------------------------------------------------
local function crachat(e, principal)
  local src = e.source_entity
  local to = e.target_position
  if not (src and src.valid and to) then return end
  local r = Xp.robot("sarracenie")
  local st = stat(r.id)
  local force, surface = src.force, src.surface
  if principal then
    st.coups = st.coups + 1
    local pts = Xp.jet_points(src.position, to, r.jets.count, r.jets.spread)
    for k = 2, #pts do
      surface.create_entity({ name = SARR_JET2, position = src.position, source = src, source_position = src.position,
        target_position = { pts[k].x, pts[k].y } })
    end
  end
  st.jets = st.jets + 1
  local total, n = blast(r, surface, force, src, to, r.jets.radius, r.shot / r.jets.count, r.dtype, 1)
  journal("sarracenie %s #%d degats %.1f cibles %d tick %d", principal and "jet" or "jet2", src.unit_number, total, n, e.tick)
end

local function goutte(e)
  local src = e.source_entity
  local to = e.target_position
  if not (src and src.valid and to) then return end
  local r = Xp.robot("veilleuse")
  local st = stat(r.id)
  st.coups = st.coups + 1
  local surface = src.surface
  surface.create_entity({ name = ECLAIR, position = to })
  rendering.draw_sprite({ sprite = SPR_VERRE, target = to, surface = surface, time_to_live = 1800, render_layer = "decals",
    x_scale = 0.9, y_scale = 0.9 })
  local total, n = blast(r, surface, src.force, src, to, r.drop.radius, r.shot, r.dtype, 0.5)
  journal("veilleuse goutte #%d degats %.1f cibles %d tick %d", src.unit_number, total, n, e.tick)
end

---------------------------------------------------------------------------------------------------
-- Demi-Vie : la fusion (usage unique) et sa zone
---------------------------------------------------------------------------------------------------
local function fusion(e)
  local src = e.source_entity
  if not (src and src.valid) then return end
  local r = Xp.robot("demi-vie")
  local s = S()
  local un = src.unit_number
  if s.fired[un] then return end
  s.fired[un] = e.tick
  local st = stat(r.id)
  st.coups = st.coups + 1
  local surface, force, pos = src.surface, src.force, { x = src.position.x, y = src.position.y }
  src.destroy({ raise_destroy = true }) -- elle fond sur place : plus d'unité, plus de tir
  surface.create_entity({ name = FUSION, position = pos })
  surface.create_entity({ name = ZONE, position = pos })
  local total, n = blast(r, surface, force, nil, pos, r.blast.radius, r.burst, r.dtype, r.blast.edge)
  s.zones[#s.zones + 1] = { surface = surface.index, force = force.name, x = pos.x, y = pos.y, t0 = e.tick }
  journal("demi-vie fusion #%d degats %.1f cibles %d tick %d", un, total, n, e.tick)
end

local function contamination(ev)
  local s = S()
  if not s or #s.zones == 0 then return end
  local r = Xp.robot("demi-vie")
  local keep = {}
  for _, z in ipairs(s.zones) do
    local surface, force = game.surfaces[z.surface], game.forces[z.force]
    if surface and force and Xp.zone_alive(r, z.t0, ev.tick) then
      local total = blast(r, surface, force, nil, { x = z.x, y = z.y }, r.contamination.radius, Xp.contamination_pulse(r), r.contamination.dtype, 1)
      if total > 0 then journal("demi-vie zone (%.0f, %.0f) degats %.1f tick %d", z.x, z.y, total, ev.tick) end
      keep[#keep + 1] = z
    end
  end
  s.zones = keep
end

---------------------------------------------------------------------------------------------------
-- Lancer un attaquant ; le renvoyer quand sa commande finit
---------------------------------------------------------------------------------------------------
local function send(u)
  if not (u and u.valid) then return false end
  local r = Xp.of_name(u.name)
  local t = u.surface.find_nearest_enemy({ position = u.position, max_distance = 150, force = u.force })
  if not t then
    u.set_command({ type = defines.command.wander, radius = 4, distraction = defines.distraction.by_enemy })
    return false
  end
  if r.single_use then
    u.set_command({ type = defines.command.attack, target = t, distraction = defines.distraction.none })
  else
    u.set_command({ type = defines.command.attack_area, destination = t.position, radius = r.range, distraction = defines.distraction.by_anything })
  end
  return true
end

--- Pose l'unité `id` (Géode, Demi-Vie) au point visé, pour une force, et l'envoie. Rend l'entité ou nil.
function M.lancer(id, surface, force, pos)
  local r = Xp.robot(id)
  if not (r and r.is_unit) then return nil end
  local p = surface.find_non_colliding_position(r.name, pos, 8, 0.5) or pos
  local u = surface.create_entity({ name = r.name, position = p, force = force, raise_built = true })
  if not u then return nil end
  local s = S()
  s.units[#s.units + 1] = { un = u.unit_number, e = u }
  send(u)
  journal("%s lancee #%d (%.1f, %.1f) force %s", id, u.unit_number, p.x, p.y, force.name)
  return u
end

local function on_capsule(e)
  local item = e.item
  local r = item and Xp.of_name(item.name)
  if not (r and r.is_unit) then return end
  local player = game.get_player(e.player_index)
  if not player then return end
  M.lancer(r.id, player.surface, player.force, e.position)
end

--- Commande finie (pas une simple distraction, F171) : l'unité repart vers l'ennemi le plus proche ; les unités disparues sortent de la liste.
local function on_command_done(e)
  local s = S()
  if not s or #s.units == 0 or e.was_distracted then return end
  local keep, again = {}, nil
  for _, it in ipairs(s.units) do
    if it.e and it.e.valid then
      keep[#keep + 1] = it
      if it.un == e.unit_number then again = it.e end
    end
  end
  s.units = keep
  if again then send(again) end
end

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
local HANDLERS = {
  [Xp.EFFECT.arc] = arc,
  [Xp.EFFECT.buisson] = buisson,
  [Xp.EFFECT.crachat] = function(e) crachat(e, true) end,
  [Xp.EFFECT.jet] = function(e) crachat(e, false) end,
  [Xp.EFFECT.goutte] = goutte,
  [Xp.EFFECT.fusion] = fusion,
}

local function on_effect(e)
  local fn = HANDLERS[e.effect_id]
  if fn then fn(e) end
end

local function on_tick(e)
  local s = S()
  if not s or #s.jobs == 0 then return end
  local keep = {}
  for _, job in ipairs(s.jobs) do
    local done = false
    if job.next <= e.tick then done = pas_buisson(job, e.tick) end
    if not done then keep[#keep + 1] = job end
  end
  s.jobs = keep
end

Events.on(defines.events.on_script_trigger_effect, on_effect)
Events.on(defines.events.on_player_used_capsule, on_capsule)
Events.on(defines.events.on_ai_command_completed, on_command_done)
Events.on(defines.events.on_tick, on_tick)
Events.on_nth_tick(30, contamination)

---------------------------------------------------------------------------------------------------
-- Interface distante « fo-xp » (bancs) : lancer, comptes, journal
---------------------------------------------------------------------------------------------------
remote.add_interface("fo-xp", {
  lancer = function(id, force_name, x, y)
    local u = M.lancer(id, game.surfaces[1], game.forces[force_name], { x = x, y = y })
    return u and u.unit_number or nil
  end,
  stats = function()
    local s = S()
    local out = {}
    for _, r in ipairs(Xp.ROBOTS) do
      local st = s.stats[r.id]
      out[r.id] = { coups = st and st.coups or 0, degats = st and st.degats or 0, cibles = st and st.cibles or 0, tues = st and st.tues or 0,
        sauts = st and st.sauts or 0, jets = st and st.jets or 0 }
    end
    return out
  end,
  journal = function(on) S().journal = on and true or false end,
  zones = function() return #S().zones end,
  noms = function() return NAMES end,
})

return M
