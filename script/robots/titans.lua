--[[
  Lot TITANS (9/11) : le JUGGERNAUT (titan allié) en jeu. Règles pures : shared/robots/titans.lua (T.juggernaut(age) : palier, PV,
  plaques, vitesse, armes) ; prototypes : prototypes/titans.lua (un spider-vehicle par palier) ; modèle : script/robots/experimentaux_geants.lua
  (cible G.cible, salve de zone G.salve, plafond des géants, télécommande, corps par `rendering`).
  - Posé : inscrit ; refusé au-delà du plafond des géants (Xp.giant_ok, titans comptés par Armee.hooks.extra_giants, chaîné au Bourdon) ;
    l'entité posée (palier 1, celui de l'objet) est REMPLACÉE par le palier de l'âge de sa force (évolution dynamique au spawn).
  - Toutes les AGE_TICKS : l'âge de la force est relu ; si le palier change, l'entité est remplacée par le prototype du nouveau palier
    (même position, même part de PV, même force), le corps redessiné : nouvelles armes, masse, plaques (règle pure T.juggernaut).
  - Toutes les SCAN ticks, chaque Juggernaut prêt vise l'ennemi le plus proche à portée (G.cible) : griffes (dégâts de zone courte autour
    de lui, K.blast, palier 1) ; canon annulaire (rayon fo-titan-canon sur la cible, coup = salve de son âge, palier 2) ; salve de ZONE des
    géants (G.salve, cratère, palier 4) ; résonance (cadence doublée, palier 6).
  Le KAIJU (ennemi) n'a rien ici : son prototype par ère est choisi au spawn (shared/td/waves.lua, script/td/director.lua) ; l'IA est celle
  du moteur. Dégâts : script/robots/experimentaux_commun.lua (jamais sur sa force ni ses amis). Rien de mesuré en temps, rien en dur.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local T = require("shared.robots.titans")
local Xp = require("shared.robots.experimentaux")
local K = require("script.robots.experimentaux_commun")
local Armee = require("script.robots.armee")
local G = require("script.robots.experimentaux_geants")

local M = {}

Storage.declare("titans", function()
  return { juggernauts = {} }
end)

local function S() return Storage.ns("titans") end

local SCAN = 30
local AGE_TICKS = 600
local CANON = T.PREFIX .. "canon"
local GRIFFE = T.PREFIX .. "griffe"
local BOUCHE = { 6.5, -19.0 }   -- bouche du canon (tuiles depuis le pied ; provisoire, lu sur le rendu : bras droit, côté caméra)

local function rgba(r, g, b, a) return { r = r * a, g = g * a, b = b * a, a = a } end

local function journal(fmt, ...)
  local s = K.S()
  if s and s.journal then log(T.LOG .. " " .. string.format(fmt, ...)) end
end

---------------------------------------------------------------------------------------------------
-- Registre et plafond (chaîné au compte des géants d'Armee)
---------------------------------------------------------------------------------------------------
local function mine(force_name, sauf)
  local n = 0
  local st = S()
  if not st then return 0 end
  for _, g in ipairs(st.juggernauts) do
    if g.e.valid and g.e.force.name == force_name and g.un ~= sauf then n = n + 1 end
  end
  return n
end

function M.count(force_name) return mine(force_name, nil) end

do
  local avant = Armee.hooks.extra_giants
  Armee.hooks.extra_giants = function(force_name)
    return (avant and avant(force_name) or 0) + mine(force_name, nil)
  end
end

local function corps(g)
  local e = g.e
  local s = e.surface
  local st = T.PREFIX .. T.JUGGERNAUT.id .. "-" .. g.stage
  rendering.draw_sprite({ sprite = st .. "-ombre", target = e, surface = s, render_layer = "lower-object" })
  rendering.draw_sprite({ sprite = st .. "-corps", target = e, surface = s, render_layer = "air-object" })
  rendering.draw_sprite({ sprite = st .. "-lueur-1", target = e, surface = s, render_layer = "air-object" })
end

local function rendre(player, e, name)
  if player and player.valid and player.insert({ name = name, count = 1 }) == 1 then return end
  e.surface.spill_item_stack(e.position, { name = name, count = 1 }, true)
end

--- Remplace l'entité `e` par le prototype du palier `palier` (même position, force, part de PV). Rend la nouvelle entité (ou e).
local function remplacer(e, palier)
  local nom = T.juggernaut_name(palier)
  if e.name == nom then return e end
  local s, pos, force = e.surface, e.position, e.force
  local part = e.health / e.prototype.max_health
  local n = s.create_entity({ name = nom, position = pos, force = force, create_build_effect_smoke = false })
  if not n then return e end
  n.health = math.max(1, n.prototype.max_health * part)
  e.destroy()
  return n
end

local function inscrire(e, tick, player)
  local force = e.force
  local age = Armee.age(force)
  local j = T.juggernaut(age)
  e = remplacer(e, j.palier)
  local st = S()
  local g = { un = e.unit_number, e = e, age = age, palier = j.palier, stage = j.stage, next = tick, next_griffes = tick, n = 0 }
  st.juggernauts[#st.juggernauts + 1] = g
  corps(g)
  if player and player.valid and game.item_prototypes["spidertron-remote"] then
    local stack = player.cursor_stack
    if stack and player.clear_cursor() and stack.valid and stack.set_stack({ name = "spidertron-remote", count = 1 }) then
      stack.connected_entity = e
    end
  end
  journal("juggernaut pose #%d force %s age %d palier %d armes %s", e.unit_number, force.name, age, j.palier, table.concat(j.liste_armes, "+"))
  return g
end

local function on_built(ev)
  local e = ev.created_entity or ev.entity
  if not (e and e.valid) then return end
  if not T.juggernaut_palier(e.name) then return end
  local st = S()
  for _, g in ipairs(st.juggernauts) do
    if g.e.valid and g.e == e then return end -- remplacement par ce script (script_raised_built) : déjà inscrit
  end
  local force = e.force
  local age = Armee.age(force)
  local have = Armee.giants(force.name) - mine(force.name, nil) + mine(force.name, e.unit_number)
  local player = ev.player_index and game.get_player(ev.player_index)
  if not Xp.giant_ok(age, have) then
    journal("juggernaut refuse : plafond des geants (%d deja, age %d, plafond %d)", have, age, Xp.giant_cap(age))
    rendre(player, e, T.JUGGERNAUT.name)
    if player then player.print({ "fo-titan.plafond", { "entity-name." .. T.JUGGERNAUT.name }, Xp.giant_cap(age), age }) end
    e.destroy()
    return
  end
  inscrire(e, ev.tick or game.tick, player)
end

---------------------------------------------------------------------------------------------------
-- Évolution par âge : le palier suit l'âge de la force
---------------------------------------------------------------------------------------------------
local function evoluer(ev)
  local st = S()
  if not st or #st.juggernauts == 0 then return end
  for _, g in ipairs(st.juggernauts) do
    if g.e.valid then
      local age = Armee.age(g.e.force)
      if age ~= g.age then
        local j = T.juggernaut(age)
        g.age = age
        if j.palier ~= g.palier then
          local n = remplacer(g.e, j.palier)
          g.e, g.un, g.palier, g.stage = n, n.unit_number, j.palier, j.stage
          corps(g)
          if g.e.force.name == "player" then
            game.print({ "fo-titan.evolue", { "entity-name." .. T.JUGGERNAUT.name }, j.palier, age, table.concat(j.liste_armes, ", ") })
          end
          journal("juggernaut #%d evolue : age %d palier %d armes %s", g.un, age, j.palier, table.concat(j.liste_armes, "+"))
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Armes
---------------------------------------------------------------------------------------------------
local function griffes(g, j, tick)
  local e = g.e
  local total, n = K.blast(j, e.surface, e.force, e, { x = e.position.x, y = e.position.y }, j.griffes.radius, j.salve * j.griffes.part, "physical",
    j.griffes.edge)
  if n > 0 then
    e.surface.create_entity({ name = GRIFFE, position = e.position })
    rendering.draw_circle({ color = rgba(0.3, 0.95, 1.0, 0.5), radius = j.griffes.radius, width = 8, filled = false, target = e.position,
      surface = e.surface, time_to_live = 20, draw_on_ground = true })
    journal("juggernaut griffes #%d cibles %d degats %.0f tick %d", g.un, n, total, tick)
  end
  return n
end

local function canon(g, j, target, tick)
  local e = g.e
  e.surface.create_entity({ name = CANON, position = e.position, source = e, source_offset = { BOUCHE[1], BOUCHE[2] },
    target_position = { target.position.x, target.position.y }, duration = math.min(60, j.cooldown) })
  rendering.draw_circle({ color = rgba(0.3, 0.95, 1.0, 0.6), radius = 2.0, width = 6, filled = false, target = target.position, surface = e.surface,
    time_to_live = 30, draw_on_ground = true })
  local d = K.hit(j, target, j.salve, j.dtype, e.force, e)
  journal("juggernaut canon #%d degats %.0f tick %d", g.un, d, tick)
end

local function scan(ev)
  local st = S()
  if not st or #st.juggernauts == 0 then return end
  local keep = {}
  for _, g in ipairs(st.juggernauts) do
    if g.e.valid then
      keep[#keep + 1] = g
      local j = T.juggernaut(g.age)
      -- griffes : à leur cadence, dès qu'un ennemi est au contact
      if ev.tick >= g.next_griffes and j.armes.griffes then
        if griffes(g, j, ev.tick) > 0 then g.next_griffes = ev.tick + j.griffes.cooldown end
      end
      if ev.tick >= g.next and not G.zone_active(g.un) then
        local t = G.cible(g.e, j, nil)
        if t then
          if j.armes.canon then canon(g, j, t, ev.tick) end
          if j.armes.salve then G.salve(g.e, g.un, j, { x = t.position.x, y = t.position.y }, ev.tick, nil) end
          local s = K.stat(j.id)
          s.coups = s.coups + 1
          g.n = g.n + 1
          g.next = ev.tick + (j.armes.salve and j.zone_cooldown or j.cooldown)
        end
      end
    end
  end
  st.juggernauts = keep
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on_nth_tick(SCAN, scan)
Events.on_nth_tick(AGE_TICKS, evoluer)

return M
