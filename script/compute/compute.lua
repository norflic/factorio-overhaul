--[[
  Lot CALCUL (30/10), refait au lot CALCUL-V2 (30/10) : le CALCUL tenu par script (D-19, D-20 (4)), produit par des
  centres MODULAIRES. Règle pure : shared/content/compute_rack.lua ; données : shared/content/compute_chain.lua.

  - Un centre (fo-data-center 4 × 4, fo-data-center-2 6 × 6) porte des BAIES dans ses emplacements de modules (objets de
    type « module », catégorie fo-baie). Toutes les 60 ticks, ce module lit pour chaque centre : l'inventaire de modules
    (les robots posent des modules sans événement, F199 : on lit, on ne s'abonne pas), la recette de refroidissement et la
    part du temps où elle a tourné (r, par products_finished + crafting_progress, comme la v1), la satisfaction électrique
    (e, sur le compagnon). Cr.evaluate en tire le calcul, la puissance et la chaleur. Rien ne se garde d'une fenêtre à
    l'autre (calcul NON stockable).
  - Compagnon d'énergie : une interface électrique cachée sous chaque centre ; sa puissance (power_usage, J/tick) est écrite
    = somme des kW des baies, son tampon = une fenêtre d'un tick (H-CV2-4 : satisfaction = énergie / tampon).
  - Réseau = la FORCE (Q-CALC-1 ouverte). Consommateur : la vitesse de recherche (laboratory_speed_modifier), bonus
    plafonné (Cr.lab_bonus) ; la part posée à la fenêtre précédente est retirée avant de poser la nouvelle (Cp.lab_modifier,
    règle v1 inchangée), la part des technologies est gardée.
  - Migration des sauvegardes 0.6.27 (on_configuration_changed) : un centre sur une recette v1 (baie usée) passe au
    refroidissement à l'eau glacée ; les baies rendues vont DANS ses emplacements, le surplus tombe au sol près de lui
    (marqué à ramasser par sa force) ; l'eau de la v1 est perdue (≤ 3 000 par centre, déclarée) ; compagnon créé.
  - Déterminisme : centres en LISTE triée par numéro d'unité, forces par nom trié, joueurs dans l'ordre du moteur ; aucun
    pairs dans une décision ; aucune décision sur un temps mesuré.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local Cp = require("shared.content.compute")
local Cr = require("shared.content.compute_rack")
local Gui = require("script.compute.gui")

local Compute = {}

Compute.NAMES = { "fo-data-center", "fo-data-center-2" }
local IS_CENTER = {}
for _, n in ipairs(Compute.NAMES) do IS_CENTER[n] = true end
local V1_RECIPES = { ["fo-compute-classic"] = true, ["fo-compute-accelerated"] = true, ["fo-compute-quantum"] = true }
Compute.MIGRATION_RECIPE = "fo-dc-chilled-water"

Storage.declare("compute", function()
  return {
    units = {},   -- numéros d'unité des centres, triés
    by = {},      -- [unité] = { e = centre, p = compagnon, prev = { recipe, progress }, last = évaluation }
    forces = {},  -- [nom de force] = { rate = unités/s, bonus = part posée sur laboratory_speed_modifier, centers = n }
    last_tick = nil,
    migrated = { centers = 0, racks_in = 0, spilled = 0, water_lost = 0 },
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

local function remove_sorted(list, u)
  for i = 1, #list do if list[i] == u then table.remove(list, i) return end end
end

--- Compagnon d'énergie du centre (créé s'il manque).
local function companion(e, rec)
  if rec.p and rec.p.valid then return rec.p end
  local name = e.name .. "-power"
  local p = e.surface.find_entities_filtered({ name = name, position = e.position, limit = 1 })[1]
  if not p then
    p = e.surface.create_entity({ name = name, position = e.position, force = e.force, create_build_effect_smoke = false })
  end
  if p then
    p.destructible = false
    p.power_usage = 0
    p.electric_buffer_size = 1
  end
  rec.p = p
  return p
end

local function track(e)
  if not (e and e.valid and IS_CENTER[e.name] and e.unit_number) then return end
  local s = S()
  if not s then return end
  local u = e.unit_number
  if insert_sorted(s.units, u) or not s.by[u] then s.by[u] = s.by[u] or { e = e } end
  s.by[u].e = e
  companion(e, s.by[u])
end

local function untrack(e)
  if not (e and e.valid and IS_CENTER[e.name] and e.unit_number) then return end
  local s = S()
  if not s then return end
  local rec = s.by[e.unit_number]
  if rec and rec.p and rec.p.valid then rec.p.destroy() end
  s.by[e.unit_number] = nil
  remove_sorted(s.units, e.unit_number)
end

---------------------------------------------------------------------------------------------------
-- Migration d'un centre v1 (recette à baie usée) : passe au refroidissement à l'eau glacée, baies dans ses emplacements.
---------------------------------------------------------------------------------------------------
local function migrate_center(e)
  local r = e.get_recipe()
  if not (r and V1_RECIPES[r.name]) then return end
  local s = S()
  local m = s.migrated
  local water = e.get_fluid_count("water")
  local back = e.set_recipe(Compute.MIGRATION_RECIPE) or {}
  -- Objets rendus (entrée et fabrication en cours), noms triés.
  local names = {}
  for n in pairs(back) do names[#names + 1] = n end
  table.sort(names)
  local inv = e.get_module_inventory()
  for _, n in ipairs(names) do
    local count = back[n]
    if count > 0 and inv and Cr.BY_NAME[n] then
      local put = inv.insert({ name = n, count = count })
      m.racks_in = m.racks_in + put
      count = count - put
    end
    if count > 0 then
      e.surface.spill_item_stack(e.position, { name = n, count = count }, true, e.force, false)
      m.spilled = m.spilled + count
    end
  end
  m.water_lost = m.water_lost + water
  m.centers = m.centers + 1
  log(string.format("[FO-CALCUL-V2-MIGRATION] centre %d : %s -> %s, %d objet(s) rendu(s), eau perdue %.0f",
    e.unit_number, r.name, Compute.MIGRATION_RECIPE, #names, water))
end

--- Relit tous les centres de toutes les surfaces (surfaces par indice, centres par numéro d'unité) ; compagnons créés ou
--- retirés (orphelins) ; centres v1 migrés.
local function rescan(migrate)
  local s = S()
  if not s then return end
  s.migrated = s.migrated or { centers = 0, racks_in = 0, spilled = 0, water_lost = 0 }
  local surfaces = {}
  for _, surf in pairs(game.surfaces) do surfaces[#surfaces + 1] = surf end -- trié juste après
  table.sort(surfaces, function(a, b) return a.index < b.index end)
  local found, companions = {}, {}
  for _, surf in ipairs(surfaces) do
    for _, e in ipairs(surf.find_entities_filtered({ name = Compute.NAMES })) do
      if e.unit_number then found[#found + 1] = e end
    end
    for _, p in ipairs(surf.find_entities_filtered({ name = { "fo-data-center-power", "fo-data-center-2-power" } })) do
      companions[#companions + 1] = p
    end
  end
  table.sort(found, function(a, b) return a.unit_number < b.unit_number end)
  local units, by, kept = {}, {}, {}
  for _, e in ipairs(found) do
    if migrate then migrate_center(e) end
    units[#units + 1] = e.unit_number
    local old = s.by[e.unit_number]
    local rec = { e = e, p = old and old.p or nil, prev = old and old.prev or nil, last = old and old.last or nil }
    if migrate then rec.prev = nil end
    by[e.unit_number] = rec
    local p = companion(e, rec)
    if p and p.unit_number then kept[p.unit_number] = true end
  end
  -- Compagnons sans centre (sauvegarde éditée, centre retiré sans événement) : retirés.
  for _, p in ipairs(companions) do if p.valid and p.unit_number and not kept[p.unit_number] then p.destroy() end end
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

--- Évalue un centre sur la fenêtre écoulée (ticks) ; écrit la puissance de son compagnon pour la fenêtre suivante.
local function evaluate_center(rec, ticks)
  local e = rec.e
  local r = e.get_recipe()
  local now = { recipe = r and r.name or nil, progress = Cp.progress(e.products_finished, e.crafting_progress) }
  local d = 0
  if rec.prev and rec.prev.recipe == now.recipe and now.recipe then d = now.progress - rec.prev.progress end
  rec.prev = now
  local share = Cr.share(d, r and r.energy or 0, e.crafting_speed, ticks)
  local inv = e.get_module_inventory()
  local counts = Cr.counts(inv and inv.get_contents() or {})
  local p = companion(e, rec)
  local sat = 1
  if p then sat = Cr.satisfaction(p.energy, p.electric_buffer_size, p.power_usage) end
  local ev = Cr.evaluate(counts, now.recipe, share, sat, e.name)
  ev.r, ev.e, ev.counts = share, sat, counts
  rec.last = ev
  if p then
    local base = Cr.CENTERS[e.name].base_kw
    local usage = (ev.kw - base) * 1000 / 60 -- J par tick
    if usage < 0 then usage = 0 end
    if p.power_usage ~= usage then p.power_usage = usage end
    local buf = usage > 0 and usage or 1
    if p.electric_buffer_size ~= buf then p.electric_buffer_size = buf end
  end
  return ev
end

--- Une fenêtre de mesure : calcul de chaque centre, de chaque force, puis bonus de recherche.
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
      local ev = evaluate_center(rec, ticks)
      if sum[fname] == nil then sum[fname], count[fname] = 0, 0; active[#active + 1] = fname end
      -- Première fenêtre (durée inconnue) : rien n'est compté (on ne fabrique jamais de calcul d'un état inconnu).
      if ticks > 0 then sum[fname] = sum[fname] + ev.compute end
      count[fname] = count[fname] + 1
    else
      if rec and rec.p and rec.p.valid then rec.p.destroy() end
      s.by[u] = nil
    end
  end
  s.units = keep
  for _, fname in ipairs(sorted_force_names(s, active)) do
    local force = game.forces[fname]
    local st = s.forces[fname] or { rate = 0, bonus = 0, centers = 0 }
    if force and force.valid then
      local rate = sum[fname] or 0
      local bonus = Cr.lab_bonus(rate)
      local new_mod = Cp.lab_modifier(force.laboratory_speed_modifier, st.bonus, bonus)
      if new_mod ~= force.laboratory_speed_modifier then force.laboratory_speed_modifier = new_mod end
      st.rate, st.bonus, st.centers = rate, bonus, count[fname] or 0
      if st.centers == 0 and bonus == 0 then s.forces[fname] = nil else s.forces[fname] = st end
    else
      s.forces[fname] = nil
    end
  end
  Gui.refresh_all(Compute)
end

--- Le moteur a recalculé les effets des technologies d'une force : notre part n'y est plus.
local function forget(force_name)
  local s = S()
  if s and s.forces[force_name] then s.forces[force_name].bonus = 0 end
end

local function on_built(e) track(e.created_entity or e.entity) end
local function on_removed(e) untrack(e.entity) end
Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on(defines.events.on_player_mined_entity, on_removed)
Events.on(defines.events.on_robot_mined_entity, on_removed)
Events.on(defines.events.on_entity_died, on_removed)
Events.on(defines.events.script_raised_destroy, on_removed)
Events.on(defines.events.on_technology_effects_reset, function(e) forget(e.force.name) end)
Events.on(defines.events.on_force_reset, function(e) forget(e.force.name) end)
-- Forces fusionnées : la force source disparaît, Compute.window oublie son état (game.forces[nom] = nil).
Events.on_nth_tick(Cp.WINDOW_TICKS, function(e) Compute.window(e.tick) end)
--- Relecture de tous les centres (bancs hors jeu : tests/compute_v2_script_test.lua) ; migrate = migration des centres v1.
Compute.rescan = rescan
Events.on_init(function() rescan(false) end)
Events.on_configuration_changed(function() rescan(true) end)
Events.on(defines.events.on_gui_opened, function(e)
  local ent = e.entity
  if ent and ent.valid and IS_CENTER[ent.name] then Gui.show(game.get_player(e.player_index), Compute, ent) end
end)

--- Lecture : dernière évaluation d'un centre (ou nil).
function Compute.center(e)
  local s = S()
  local rec = s and e and e.valid and e.unit_number and s.by[e.unit_number]
  return rec and rec.last or nil
end

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
  -- Lecture seule : dernière évaluation d'un centre { compute, kw, heat, cooling, f_mem, f_heat, cap, export, limit, r, e,
  -- counts } (bancs).
  center = function(e) return Compute.center(e) end,
  -- Lecture seule : compagnon d'énergie d'un centre (bancs).
  companion = function(e)
    local s = S()
    local rec = s and e and e.valid and e.unit_number and s.by[e.unit_number]
    return rec and rec.p or nil
  end,
  migrated = function() local s = S() return s and s.migrated or nil end,
})

return Compute
