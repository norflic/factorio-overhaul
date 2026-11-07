--[[
  Lot EXPERIMENTAUX (3/11) : les robots expérimentaux en jeu. Règles pures : shared/robots/experimentaux.lua ; prototypes :
  prototypes/experimentaux.lua.

  - L'attaque du moteur (rayon, jet, tir d'une unité) ne lève qu'un effet `script` (on_script_trigger_effect) : TOUS les dégâts sont
    appliqués ici par entity.damage, seulement aux forces ENNEMIES du tireur (force.is_enemy : ni amie, ni en cessez-le-feu), et comptés.
  - Mât-Foudre : un coup par cadence (un rayon lève l'effet à chaque intervalle : les suivants sont ignorés), puis l'arc saute vers 2 cibles.
  - Géode : les pointes courent de la Géode à la cible, une tous les 3 ticks (file `jobs`, traitée à chaque tick tant qu'elle n'est pas vide).
  - Sarracénie : le jet principal tombe, le script lance les 2 autres ; Veilleuse : la goutte éclate, plaque de verre.
  - Demi-Vie : usage unique ; fusion, puis zone contaminée (impulsion toutes les 30 ticks, `zones`).
  - Les GÉANTS (palier 3) : script/robots/experimentaux_geants.lua ; outils communs : script/robots/experimentaux_commun.lua.
  - Géode et Demi-Vie sont LANCÉES (capsule, on_player_used_capsule) : l'unité est posée au point visé, de la force du joueur, puis envoyée
    sur l'ennemi le plus proche (et renvoyée quand sa commande finit).
  Journal « [FO-XP] » (dégâts appliqués, cibles, tick) seulement si le journal est ouvert (interface « fo-xp », bancs) ; les totaux sont
  toujours tenus (storage, `stats`). Déterminisme : listes triées, aucun pairs, aucun hasard ; `require` en tête (F24).
]]

local Events = require("script.core.events")
local Xp = require("shared.robots.experimentaux")
local K = require("script.robots.experimentaux_commun")
local Geants = require("script.robots.experimentaux_geants")

local M = {}

-- outils communs (script/robots/experimentaux_commun.lua) : stockage, comptes, journal, ennemis, dégâts
local S, stat, journal, candidates, hit, blast = K.S, K.stat, K.journal, K.candidates, K.hit, K.blast

local NAMES = {}
for _, r in ipairs(Xp.ROBOTS) do NAMES[#NAMES + 1] = r.name end
for _, r in ipairs(Xp.GEANTS) do NAMES[#NAMES + 1] = r.name end

local CHAIN_BEAM = Xp.PREFIX .. "arc-saut"
local SARR_JET2 = Xp.PREFIX .. "sarracenie-jet2"
local FUSION = Xp.PREFIX .. "demi-vie-fusion"
local ZONE = Xp.PREFIX .. "demi-vie-zone"
local ECLAIR = Xp.PREFIX .. "veilleuse-eclair"
local SPR_POINTE, SPR_POINTE_LUEUR, SPR_VERRE = Xp.PREFIX .. "pointe", Xp.PREFIX .. "pointe-lueur", Xp.PREFIX .. "verre"

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
    -- la Géode s'arrête à sa portée et tire de là (i2 : en « attack_area », elle allait au milieu des cibles et ses pointes ne couraient plus)
    u.set_command({ type = defines.command.attack, target = t, distraction = defines.distraction.by_enemy })
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
    local all = {}
    for _, r in ipairs(Xp.ROBOTS) do all[#all + 1] = r end
    for _, r in ipairs(Xp.GEANTS) do all[#all + 1] = r end
    for _, r in ipairs(all) do
      local st = s.stats[r.id]
      out[r.id] = { coups = st and st.coups or 0, degats = st and st.degats or 0, cibles = st and st.cibles or 0, tues = st and st.tues or 0,
        sauts = st and st.sauts or 0, jets = st and st.jets or 0 }
    end
    return out
  end,
  journal = function(on) S().journal = on and true or false end,
  zones = function() return #S().zones end,
  --- Géants de cette famille, vivants, pour une force (le plafond des géants les compte avec ceux de robotsjeu).
  geants = function(force_name) return Geants.count(force_name) end,
  --- Modules (lot DESIGN-MODULES) : bonus de portée et de puissance d'un géant (0,2 = + 20 %, produit avec la règle d'échelle).
  bonus = function(unit_number, portee, puissance) return Geants.set_bonus(unit_number, portee, puissance) end,
  --- Design IMPACT (bancs d'images) : trace d'une salve de zone, « A » (cratère et une brûlure, défaut) ou « B » (sol brûlé sur la zone).
  impact = function(v) S().impact = (v == "B") and "B" or nil end,
  --- Bancs seulement : durée des cratères en ticks (nil : Ech.TRACE_TICKS, 1 h) ; cratère posé par script, pour un banc court.
  trace_ticks = function(n) S().trace_ticks = tonumber(n) end,
  --- Bancs de mesure seulement : autres budgets de coups et de morts par tick des salves de zone (sans argument : Ech.BUDGET, Ech.MORTS).
  budgets = function(coups, morts)
    S().budgets = (tonumber(coups) and tonumber(morts)) and { coups = math.floor(tonumber(coups)), morts = math.floor(tonumber(morts)) } or nil
  end,
  --- Bancs seulement : coups et morts des salves de zone par tick (journal allumé), « tick:coups:morts » séparés par des virgules, ticks
  --- croissants.
  morts_par_tick = function()
    local m, c = S().morts_tick or {}, S().coups_tick or {}
    local ticks = {}
    for t in pairs(c) do ticks[#ticks + 1] = t end -- trié juste après
    table.sort(ticks)
    local out = {}
    for _, t in ipairs(ticks) do out[#out + 1] = t .. ":" .. c[t] .. ":" .. (m[t] or 0) end
    return table.concat(out, ",")
  end,
  cratere = function(x, y, r) Geants.cratere(game.surfaces[1], { x = x, y = y }, r, game.tick) end,
  --- Bancs seulement (point 4) : autre plafond des traces dessinées d'1 h par surface (sans argument : Ech.RENDUS_MAX) ; traces comptées.
  rendus_max = function(n) S().rendus_max = tonumber(n) end,
  rendus = function(surface_index)
    local F = S().rendus and S().rendus[surface_index or 1]
    return F and (F.n - F.tete + 1) or 0
  end,
  --- Bancs seulement (B1) : jobs de salve au format de la 0.6.56 posés pour le géant `un` ; nombre de jobs de zone ; salve active.
  ancien_job = function(un) return Geants.ancien_job(un) end,
  jobs_zone = function() return Geants.jobs_zone() end,
  zone_active = function(un) return Geants.zone_active(un) end,
  noms = function() return NAMES end,
})

return M
