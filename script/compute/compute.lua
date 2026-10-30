--[[
  Lot CALCUL (30/10) : le CALCUL tenu par script (D-19, D-20 (4)). Règles pures : shared/content/compute.lua.

  - Le centre de calcul est une machine à recettes SANS produit (comme la torchère d'AMELIO-CRAFTS, dont le banc
    crafts-chaines a prouvé que products_finished compte ces fabrications). Toutes les 60 ticks, ce module lit pour chaque
    centre l'avancement products_finished + crafting_progress et en déduit le calcul de la fenêtre : (écart d'avancement) ×
    unités par fabrication de la recette en cours. Un centre sans courant, sans eau ou sans baie n'avance pas : il ne calcule
    pas. Rien ne se garde d'une fenêtre à l'autre (calcul NON stockable).
  - Réseau v1 = la FORCE (question Q-CALC-1 au DC : relier par câble comme l'électricité ?).
  - Consommateur v1 : la vitesse de recherche (LuaForce.laboratory_speed_modifier), bonus plafonné (Q-CALC-2). Les
    technologies vanilla écrivent le même champ : on retire la part posée à la fenêtre précédente avant de poser la
    nouvelle (Cp.lab_modifier), et on oublie notre part quand le moteur recalcule les effets des technologies.
  - Déterminisme : centres en LISTE triée par numéro d'unité, forces par nom trié ; aucun pairs ; aucune décision sur un
    temps mesuré.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Cp = require("shared.content.compute")

local Compute = {}

local NAME = "fo-data-center"

Storage.declare("compute", function()
  return {
    units = {},   -- numéros d'unité des centres, triés
    by = {},      -- [unité] = { e = entité, prev = { recipe, progress } }
    forces = {},  -- [nom de force] = { rate = unités/s, bonus = part posée sur laboratory_speed_modifier, centers = n }
    last_tick = nil,
  }
end)

local function S() return Storage.ns("compute") end

local function insert_sorted(list, u)
  local i = #list
  while i >= 1 and list[i] > u do i = i - 1 end
  if list[i] == u then return false end
  table.insert(list, i + 1, u)
  return true
end

local function track(e)
  if not (e and e.valid and e.name == NAME and e.unit_number) then return end
  local s = S()
  if not s then return end
  if insert_sorted(s.units, e.unit_number) then s.by[e.unit_number] = { e = e } end
end

--- Relit tous les centres de toutes les surfaces (surfaces par indice, centres par numéro d'unité).
local function rescan()
  local s = S()
  if not s then return end
  local surfaces = {}
  for _, surf in pairs(game.surfaces) do surfaces[#surfaces + 1] = surf end -- trié juste après
  table.sort(surfaces, function(a, b) return a.index < b.index end)
  local found = {}
  for _, surf in ipairs(surfaces) do
    for _, e in ipairs(surf.find_entities_filtered({ name = NAME })) do
      if e.unit_number then found[#found + 1] = e end
    end
  end
  table.sort(found, function(a, b) return a.unit_number < b.unit_number end)
  local units, by = {}, {}
  for _, e in ipairs(found) do
    units[#units + 1] = e.unit_number
    local old = s.by[e.unit_number]
    by[e.unit_number] = { e = e, prev = old and old.prev or nil }
  end
  s.units, s.by = units, by
end

local function sorted_force_names(s, extra)
  local seen, names = {}, {}
  for _, n in ipairs(extra) do if not seen[n] then seen[n] = true; names[#names + 1] = n end end
  local keys = {}
  for n in pairs(s.forces) do keys[#keys + 1] = n end -- trié juste après
  for _, n in ipairs(keys) do if not seen[n] then seen[n] = true; names[#names + 1] = n end end
  table.sort(names)
  return names
end

--- Une fenêtre de mesure : calcul de chaque force, puis bonus de recherche.
function Compute.window(tick)
  local s = S()
  if not s then return end
  local ticks = s.last_tick and (tick - s.last_tick) or 0
  s.last_tick = tick
  local sum, count, active = {}, {}, {}
  local keep = {}
  for _, u in ipairs(s.units) do
    local rec = s.by[u]
    local e = rec and rec.e
    if e and e.valid then
      keep[#keep + 1] = u
      local fname = e.force.name
      local r = e.get_recipe()
      local now = { recipe = r and r.name or nil, progress = Cp.progress(e.products_finished, e.crafting_progress) }
      local d = Cp.delta(rec.prev, now)
      rec.prev = now
      if sum[fname] == nil then sum[fname], count[fname] = 0, 0; active[#active + 1] = fname end
      sum[fname] = sum[fname] + d
      count[fname] = count[fname] + 1
    else
      s.by[u] = nil
    end
  end
  s.units = keep
  for _, fname in ipairs(sorted_force_names(s, active)) do
    local force = game.forces[fname]
    local st = s.forces[fname] or { rate = 0, bonus = 0, centers = 0 }
    if force and force.valid then
      local rate = Cp.rate(sum[fname] or 0, ticks)
      local bonus = Cp.lab_bonus(rate)
      local new_mod = Cp.lab_modifier(force.laboratory_speed_modifier, st.bonus, bonus)
      if new_mod ~= force.laboratory_speed_modifier then force.laboratory_speed_modifier = new_mod end
      st.rate, st.bonus, st.centers = rate, bonus, count[fname] or 0
      if st.centers == 0 and bonus == 0 then s.forces[fname] = nil else s.forces[fname] = st end
    else
      s.forces[fname] = nil
    end
  end
end

--- Le moteur a recalculé les effets des technologies d'une force : notre part n'y est plus.
local function forget(force_name)
  local s = S()
  if s and s.forces[force_name] then s.forces[force_name].bonus = 0 end
end

local function on_built(e) track(e.created_entity or e.entity) end
Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on(defines.events.on_technology_effects_reset, function(e) forget(e.force.name) end)
Events.on(defines.events.on_force_reset, function(e) forget(e.force.name) end)
-- Forces fusionnées : la force source disparaît, Compute.window oublie son état (game.forces[nom] = nil).
Events.on_nth_tick(Cp.WINDOW_TICKS, function(e) Compute.window(e.tick) end)
Events.on_init(rescan)
Events.on_configuration_changed(rescan)

--- Lecture (bancs, interface) : état d'une force.
function Compute.state(force_name)
  local s = S()
  local st = s and s.forces[force_name]
  return { rate = st and st.rate or 0, bonus = st and st.bonus or 0, centers = st and st.centers or 0,
           tracked = s and #s.units or 0 }
end

remote.add_interface("fo-calcul", {
  -- Lecture seule : { rate = unités/s de la dernière fenêtre, bonus = part de recherche posée, centers, tracked }.
  state = function(force_name) return Compute.state(force_name or "player") end,
})

return Compute
