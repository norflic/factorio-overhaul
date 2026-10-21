--[[
  Niveaux de bâtiments : runtime (session 5 ; 15 époques depuis le lot V2). Règles : shared/levels/config.lua.

  - Centre de commandement : un par force ; son niveau EST l'époque (1 à 15) ; il plafonne les autres
    bâtiments à 2 × son niveau et fixe les ouvriers (1 à 5).
  - Amélioration : coût prélevé dans le centre de commandement PUIS l'inventaire du joueur (l'usine
    alimente le centre par convoyeurs et inserteurs : la production nourrit la progression) ; chantier
    minuté, bâtiment hors service, barre de progression ; au terme, remplacement par le niveau suivant en
    « remplacement rapide » moteur (contenu, recette, modules, fils de circuit conservés), santé en
    proportion. Murs : instantanés, rangée entière possible.
  - Bâtiment détruit en chantier : chantier perdu. Bâtiment démonté en chantier : moitié du coût rendue.
  Déterminisme : tout se passe dans des événements ; parcours des chantiers dans l'ordre des numéros.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local L = require("shared.levels.config")

local Levels = {}

Storage.declare("levels", function()
  return { cc = {}, jobs = {}, busy = {}, replacing = false, time_factor = nil, stats = { upgrades = 0, instant = 0, cancelled = 0, lost = 0 } }
end)

local function S() return Storage.ns("levels") end

Levels.parse = L.parse

---------------------------------------------------------------------------------------------------
-- Centre de commandement
---------------------------------------------------------------------------------------------------
--- Centre de commandement valide de la force, ou nil.
function Levels.cc(force)
  local rec = S().cc[force.name]
  if rec and rec.valid then return rec end
  return nil
end

function Levels.cc_level(force)
  local cc = Levels.cc(force)
  if not cc then return 0 end
  local _, n = L.parse(cc.name)
  return n or 0
end

function Levels.busy(force)
  return S().busy[force.name] or 0
end

function Levels.time_factor()
  local f = S().time_factor
  if f then return f end
  local s = settings.global["fo-level-time-factor"]
  return s and s.value or 1
end

---------------------------------------------------------------------------------------------------
-- Objets de coût : chaque objet de la table d'indirection doit exister dans le jeu chargé.
-- Cache LOCAL (jamais dans global), dérivé des prototypes, identiques sur tous les clients ; rempli au
-- premier appel pendant un événement (game n'existe pas pendant on_load).
---------------------------------------------------------------------------------------------------
local item_cache = {}

function Levels.item_exists(name)
  local known = item_cache[name]
  if known == nil then
    known = game.item_prototypes[name] ~= nil
    item_cache[name] = known
  end
  return known
end

--- Objets de coût absents du jeu (liste triée ; vide si tout va bien).
function Levels.missing_cost_items()
  local out = {}
  for _, item in ipairs(L.cost_items()) do
    if not Levels.item_exists(item) then out[#out + 1] = item end
  end
  return out
end

local function check_cost_items()
  local miss = Levels.missing_cost_items()
  if #miss > 0 then
    log("[FO-LEVELS] ERREUR : objets de coût absents du jeu : " .. table.concat(miss, ", "))
  else
    log("[FO-LEVELS] " .. #L.cost_items() .. " objets de coût, tous présents ; "
      .. #L.provisional_materials() .. " matériaux d'époque provisoires")
  end
end

Events.on_init(check_cost_items)
Events.on_configuration_changed(check_cost_items)

---------------------------------------------------------------------------------------------------
-- Paiement : centre de commandement d'abord, puis inventaire du joueur.
---------------------------------------------------------------------------------------------------
local function sources(force, player)
  local invs = {}
  local cc = Levels.cc(force)
  if cc then invs[#invs + 1] = cc.get_inventory(defines.inventory.chest) end
  if player and player.valid then
    local m = player.get_main_inventory()
    if m then invs[#invs + 1] = m end
  end
  return invs
end

local function available(invs, item)
  local n = 0
  for _, inv in ipairs(invs) do n = n + inv.get_item_count(item) end
  return n
end

--- Manque pour payer `cost` : liste { {objet, il_manque} } (vide si payable).
local function missing(invs, cost)
  local m = {}
  for _, c in ipairs(cost) do
    local have = available(invs, c[1])
    if have < c[2] then m[#m + 1] = { c[1], c[2] - have } end
  end
  return m
end

local function pay(invs, cost)
  for _, c in ipairs(cost) do
    local left = c[2]
    for _, inv in ipairs(invs) do
      if left <= 0 then break end
      left = left - inv.remove({ name = c[1], count = left })
    end
  end
end

Levels.sources = sources
Levels.available = available

---------------------------------------------------------------------------------------------------
-- Rendu du chantier
---------------------------------------------------------------------------------------------------
local function box_size(entity)
  local b = entity.prototype.selection_box
  return b.right_bottom.x - b.left_top.x, b.right_bottom.y - b.left_top.y
end

local function fmt_time(ticks)
  local s = math.max(0, math.ceil(ticks / 60))
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end
Levels.fmt_time = fmt_time

local function draw_job(job)
  local e = job.entity
  local w, h = box_size(e)
  local top = -h / 2 - 0.45
  local half = math.max(0.9, w / 2)
  job.bar_w = 2 * half
  job.bar_top = top
  job.r_bg = rendering.draw_rectangle({
    color = { r = 0, g = 0, b = 0, a = 0.75 }, filled = true, surface = e.surface,
    left_top = e, left_top_offset = { -half - 0.05, top - 0.05 },
    right_bottom = e, right_bottom_offset = { half + 0.05, top + 0.27 },
  })
  job.r_fg = rendering.draw_rectangle({
    color = { r = 1, g = 0.78, b = 0.2, a = 1 }, filled = true, surface = e.surface,
    left_top = e, left_top_offset = { -half, top },
    right_bottom = e, right_bottom_offset = { -half + 0.01, top + 0.22 },
  })
  job.r_text = rendering.draw_text({
    text = { "fo-levels.building", job.to, fmt_time(job.finish - game.tick) }, surface = e.surface,
    target = e, target_offset = { 0, top - 0.75 }, color = { r = 1, g = 0.9, b = 0.5 }, scale = 1.2,
    alignment = "center", scale_with_zoom = false,
  })
end

local function undraw_job(job)
  for _, k in ipairs({ "r_bg", "r_fg", "r_text" }) do
    if job[k] and rendering.is_valid(job[k]) then rendering.destroy(job[k]) end
  end
end

local function update_job_render(job, tick)
  local span = math.max(1, job.finish - job.start)
  local p = math.min(1, (tick - job.start) / span)
  if job.r_fg and rendering.is_valid(job.r_fg) then
    rendering.set_right_bottom(job.r_fg, job.entity, { -job.bar_w / 2 + job.bar_w * p + 0.01, job.bar_top + 0.22 })
  end
  if job.r_text and rendering.is_valid(job.r_text) then
    rendering.set_text(job.r_text, { "fo-levels.building", job.to, fmt_time(job.finish - tick) })
  end
end

---------------------------------------------------------------------------------------------------
-- Remplacement par le niveau suivant
---------------------------------------------------------------------------------------------------
local function manual_replace(old, name)
  -- Secours si le remplacement rapide échoue : contenus et recette recopiés (fils de circuit perdus).
  local surface, pos, dir, force = old.surface, old.position, old.direction, old.force
  local recipe = old.type == "assembling-machine" and old.get_recipe() or nil
  -- Déterminisme (ARCHITECTURE §2) : inventaires dans l'ordre des index, objets dans l'ordre des noms (ce
  -- qui déborde au sol quand l'inventaire est plein ne dépend d'aucun ordre de pairs).
  local saved = {}
  for i = 1, 10 do
    local inv = old.get_inventory(i)
    if inv and not inv.is_empty() then
      local contents = inv.get_contents()
      local names = {}
      for item in pairs(contents) do names[#names + 1] = item end
      table.sort(names)
      local list = {}
      for _, item in ipairs(names) do list[#list + 1] = { item, contents[item] } end
      saved[#saved + 1] = { index = i, items = list }
    end
  end
  old.destroy({ raise_destroy = false })
  local new = surface.create_entity({ name = name, position = pos, direction = dir, force = force, raise_built = true, create_build_effect_smoke = false })
  if not new then return nil end
  if recipe then new.set_recipe(recipe) end
  for _, rec in ipairs(saved) do
    local inv = new.get_inventory(rec.index)
    for _, it in ipairs(rec.items) do
      local item, count = it[1], it[2]
      local put = inv and inv.insert({ name = item, count = count }) or 0
      if put < count then surface.spill_item_stack(pos, { name = item, count = count - put }, true, force, false) end
    end
  end
  return new
end

local function celebrate(entity, family, n)
  local e = L.epoch_of(family, n)
  local c = L.epochs[e].color
  -- Premier niveau d'une époque (et chaque niveau du centre, qui EST l'époque) : on annonce l'époque.
  local text = { "fo-levels.level-up", n }
  if e >= 2 and L.step_of(family, n) == 1 then text = { "fo-epochs.epoch-up", e, { "fo-epochs.name-" .. L.epochs[e].key } } end
  entity.surface.create_entity({ name = "flying-text", position = { entity.position.x, entity.position.y - 1.5 },
    text = text, color = { r = c.r, g = c.g, b = c.b } })
  rendering.draw_light({ sprite = "utility/light_medium", surface = entity.surface, target = entity,
    scale = 2 + box_size(entity), intensity = 1, color = c, time_to_live = 90 })
  entity.surface.play_sound({ path = "utility/research_completed", position = entity.position, volume_modifier = 0.6 })
end

--- Fonctions appelées après chaque remplacement : f(ancien_numéro, nouvelle_entité). Enregistrées au
--- chargement des modules (jamais pendant un événement).
Levels.on_replaced = {}

--- Remplace `entity` par le niveau n de sa famille. Renvoie la nouvelle entité ou nil.
local function replace(entity, family, n)
  local st = S()
  local name = L.name(family, n)
  local old_unit = entity.unit_number
  local ratio = entity.get_health_ratio() or 1
  local was_cc = Levels.cc(entity.force) == entity
  local surface, pos, dir, force = entity.surface, entity.position, entity.direction, entity.force
  st.replacing = true
  local new = surface.create_entity({
    name = name, position = pos, direction = dir, force = force,
    fast_replace = true, spill = false, raise_built = true, create_build_effect_smoke = false,
  })
  if not (new and new.valid and new.name == name) then
    if entity.valid then new = manual_replace(entity, name) end
    st.stats.fallback = (st.stats.fallback or 0) + 1
  end
  st.replacing = false
  if not new then return nil end
  new.health = new.prototype.max_health * ratio
  if was_cc then st.cc[force.name] = new end
  celebrate(new, family, n)
  for _, f in ipairs(Levels.on_replaced) do f(old_unit, new) end
  return new
end

---------------------------------------------------------------------------------------------------
-- Démarrer une amélioration
---------------------------------------------------------------------------------------------------
--- Coût, durée et autorisation de l'amélioration suivante de `entity` (sans rien changer).
--- Renvoie une table { family, level, next, cost, ticks, ok, reason, missing, busy, builders, cc_level }.
function Levels.preview(entity, player)
  local family, n = L.parse(entity.name)
  if not family then return nil end
  local force = entity.force
  local info = { family = family, level = n, next = n + 1, cc_level = Levels.cc_level(force),
                 busy = Levels.busy(force) }
  info.builders = L.builders(info.cc_level)
  local job = S().jobs[entity.unit_number or -1]
  if job then
    info.job = job
    info.ok, info.reason = false, "busy"
    return info
  end
  if n >= family.max then
    info.ok, info.reason = false, "max"
    return info
  end
  info.cost = L.cost(family, n + 1)
  info.ticks = L.time_ticks(family, n + 1, Levels.time_factor())
  info.ok, info.reason = L.check(family, n + 1, info.cc_level, info.busy)
  info.required_cc = L.required_cc(family, n + 1)
  -- Un objet de coût absent du jeu (table d'indirection pointant vers un objet pas encore livré) : on
  -- refuse proprement au lieu de laisser le moteur lever une erreur sur un nom d'objet inconnu.
  local unknown = {}
  for _, c in ipairs(info.cost) do
    if not Levels.item_exists(c[1]) then unknown[#unknown + 1] = c[1] end
  end
  if #unknown > 0 then
    info.unknown = unknown
    info.missing = {}
    info.ok, info.reason = false, "unknown-item"
    return info
  end
  info.missing = missing(sources(force, player), info.cost)
  if info.ok and #info.missing > 0 then info.ok, info.reason = false, "no-resources" end
  return info
end

--- Lance l'amélioration de `entity` (player facultatif : source de paiement et destinataire des messages).
--- Renvoie ok, raison, info.
function Levels.start(entity, player)
  if not (entity and entity.valid) then return false, "invalid" end
  local info = Levels.preview(entity, player)
  if not info then return false, "not-levelable" end
  if not info.ok then return false, info.reason, info end
  local st = S()
  local force = entity.force
  pay(sources(force, player), info.cost)
  if info.ticks == 0 then
    local new = replace(entity, info.family, info.next)
    if not new then return false, "replace-failed", info end
    st.stats.instant = st.stats.instant + 1
    return true, "done", info, new
  end
  local job = {
    entity = entity, unit = entity.unit_number, force = force.name, family = info.family.key,
    to = info.next, start = game.tick, finish = game.tick + info.ticks, cost = info.cost,
  }
  entity.active = false
  draw_job(job)
  st.jobs[job.unit] = job
  st.busy[force.name] = (st.busy[force.name] or 0) + 1
  return true, "started", info
end

--- Murs : améliore tous les murs reliés de même niveau (jusqu'à 400), tant que les ressources suffisent.
function Levels.start_row(entity, player)
  if not (entity and entity.valid) then return 0 end
  local family, n = L.parse(entity.name)
  if not (family and family.instant) then return 0 end
  local surface, name = entity.surface, entity.name
  local seen, queue, list = {}, { entity }, {}
  local function key(p) return math.floor(p.x) .. "," .. math.floor(p.y) end
  seen[key(entity.position)] = true
  while #queue > 0 and #list < 400 do
    local e = table.remove(queue, 1)
    list[#list + 1] = e
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local p = { x = e.position.x + d[1], y = e.position.y + d[2] }
      local k = key(p)
      if not seen[k] then
        seen[k] = true
        local nb = surface.find_entity(name, p)
        if nb and nb.force == entity.force then queue[#queue + 1] = nb end
      end
    end
  end
  local done = 0
  for _, e in ipairs(list) do
    local ok = Levels.start(e, player)
    if not ok then break end
    done = done + 1
  end
  return done
end

---------------------------------------------------------------------------------------------------
-- Chantiers
---------------------------------------------------------------------------------------------------
local function end_job(job, outcome)
  local st = S()
  undraw_job(job)
  st.jobs[job.unit] = nil
  st.busy[job.force] = math.max(0, (st.busy[job.force] or 1) - 1)
  st.stats[outcome] = (st.stats[outcome] or 0) + 1
end

Events.on_nth_tick(30, function(e)
  local st = S()
  if next(st.jobs) == nil then return end
  local units = {}
  for u in pairs(st.jobs) do units[#units + 1] = u end
  table.sort(units)
  for _, u in ipairs(units) do
    local job = st.jobs[u]
    if not job.entity.valid then
      end_job(job, "lost")
    elseif e.tick >= job.finish then
      local family = L.by_key[job.family]
      local old = job.entity
      end_job(job, "upgrades")
      old.active = true
      replace(old, family, job.to)
    else
      update_job_render(job, e.tick)
    end
  end
end)

---------------------------------------------------------------------------------------------------
-- Changement de version (0.3.0 → 15 époques, et toute mise à jour suivante)
-- Les noms 0.3.0 gardent leur sens et l'état ne change pas de forme : aucune donnée à convertir. Réparation
-- défensive seulement : chantier dont le bâtiment a disparu ou dont la cible n'existe plus (perdu, bâtiment
-- remis en service), centre disparu oublié, ouvriers occupés recomptés à partir des chantiers.
---------------------------------------------------------------------------------------------------
function Levels.repair()
  local st = S()
  local units = {}
  for u in pairs(st.jobs) do units[#units + 1] = u end
  table.sort(units)
  local fixed = 0
  for _, u in ipairs(units) do
    local job = st.jobs[u]
    local family = L.by_key[job.family or ""]
    if not (job.entity and job.entity.valid) then
      end_job(job, "lost")
      fixed = fixed + 1
    elseif not family or job.to > family.max then
      job.entity.active = true
      end_job(job, "lost")
      fixed = fixed + 1
    elseif type(job.cost) == "table" then
      -- Objets de coût retirés du jeu depuis la sauvegarde : purgés (le remboursement au démontage les
      -- ignore aussi).
      local kept = {}
      for _, c in ipairs(job.cost) do
        if Levels.item_exists(c[1]) then kept[#kept + 1] = c end
      end
      job.cost = kept
    end
  end
  local forces = {}
  for name in pairs(st.cc) do forces[#forces + 1] = name end
  table.sort(forces)
  for _, name in ipairs(forces) do
    local cc = st.cc[name]
    if not (cc and cc.valid and L.parse(cc.name)) then st.cc[name] = nil end
  end
  local busy = {}
  units = {}
  for u in pairs(st.jobs) do units[#units + 1] = u end
  table.sort(units)
  for _, u in ipairs(units) do
    local f = st.jobs[u].force
    busy[f] = (busy[f] or 0) + 1
  end
  st.busy = busy
  return fixed
end

--- PV au-dessus du maximum du prototype (0.3.0 → V2 : un mur niveau 10 passe de 3 712 à 1 925 PV) :
--- ramenés au maximum. Le moteur borne toute écriture de `health` ; on n'écrit que si c'est nécessaire.
--- Renvoie le nombre de bâtiments corrigés. Surfaces dans l'ordre de leur index, entités dans l'ordre du
--- moteur (déterministe).
function Levels.clamp_health()
  local names = {}
  for _, f in ipairs(L.families) do
    for n = 2, f.max do names[#names + 1] = L.name(f, n) end
  end
  local surfaces = {}
  for _, surface in pairs(game.surfaces) do surfaces[surface.index] = surface end
  local idx = {}
  for i in pairs(surfaces) do idx[#idx + 1] = i end
  table.sort(idx)
  local fixed = 0
  for _, i in ipairs(idx) do
    for _, e in ipairs(surfaces[i].find_entities_filtered({ name = names })) do
      local max = e.prototype.max_health
      if max and e.health and e.health > max then
        e.health = max
        fixed = fixed + 1
      end
    end
  end
  return fixed
end

Events.on_configuration_changed(function()
  local fixed = Levels.repair()
  if fixed > 0 then log("[FO-LEVELS] mise à jour : " .. fixed .. " chantier(s) réparé(s)") end
  local clamped = Levels.clamp_health()
  if clamped > 0 then log("[FO-LEVELS] mise à jour : PV ramenés au maximum sur " .. clamped .. " bâtiment(s)") end
end)

---------------------------------------------------------------------------------------------------
-- Construction et retrait
---------------------------------------------------------------------------------------------------
local function on_built(e)
  local ent = e.created_entity or e.entity
  if not (ent and ent.valid) then return end
  local family = L.parse(ent.name)
  if not (family and family.key == "command") then return end
  local st = S()
  local cur = Levels.cc(ent.force)
  if cur and cur ~= ent and not st.replacing then
    -- Un seul centre par force : le second est rendu au joueur.
    local player = e.player_index and game.get_player(e.player_index)
    local surface, pos, item = ent.surface, ent.position, ent.name
    ent.destroy()
    local put = 0
    if player and player.valid then
      put = player.insert({ name = item, count = 1 })
      player.print({ "fo-levels.only-one-cc" })
    end
    if put == 0 then surface.spill_item_stack(pos, { name = item, count = 1 }, true, nil, false) end
    return
  end
  st.cc[ent.force.name] = ent
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)

local function refund_half(cost, buffer)
  if not buffer then return end
  for _, c in ipairs(cost) do
    local q = math.floor(c[2] / 2)
    -- Un chantier d'une version antérieure peut citer un objet retiré depuis (table d'indirection changée) :
    -- l'insérer lèverait une erreur moteur « Unknown item name ».
    if q > 0 and Levels.item_exists(c[1]) then buffer.insert({ name = c[1], count = q }) end
  end
end

local function on_removed(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local st = S()
  local job = ent.unit_number and st.jobs[ent.unit_number]
  if job then
    if e.buffer then refund_half(job.cost, e.buffer) end
    end_job(job, e.buffer and "cancelled" or "lost")
  end
  if st.cc[ent.force.name] == ent and not st.replacing then st.cc[ent.force.name] = nil end
end

Events.on(defines.events.on_player_mined_entity, on_removed)
Events.on(defines.events.on_robot_mined_entity, on_removed)
Events.on(defines.events.on_entity_died, on_removed)
Events.on(defines.events.script_raised_destroy, on_removed)

return Levels
