--[[
  Lot RB-1 CHAÎNE (31/10) : les USINES de robots. Règles pures : shared/robots/modele.lua ; données : shared/content/robots.lua.

  Une usine est un `assembling-machine` ordinaire (patron INDUSTRIE, recette, modules, courant sans code neuf) qui fabrique un KIT
  (objet de pile 1). Le moteur n'a aucun événement de fin de fabrication : toutes les 60 ticks, ce module lit la sortie de chaque
  atelier ; s'il y a un kit ET de la place (points de la force sous le plafond, « maintenir N » non atteint), il retire le kit et
  Armee.create pose l'unité près de la machine, qui marche au ralliement de l'atelier. Plafond atteint : le kit n'est PAS retiré,
  la machine s'arrête d'elle-même (statut « sortie pleine », RB0-3) et reprend dès qu'une perte libère des points.

  - Les ateliers sont suivis à la pose (événements de construction) ; un atelier retiré est oublié au balayage suivant.
  - Ralliement par défaut : au sud de la sortie (Mo.default_rally) ; modifiable (interface distante set_rally, lot RB-2 : bouton).
  - « Maintenir N » (rec.keep[robot]) : le kit n'est retiré que si l'effectif vivant du robot pour la force est sous N.
  - Interface distante « fo-robots » : pilotage et lecture sans joueur (bancs, outil du joueur au lot RB-2).
  - F24 : aucun require dans un gestionnaire ; réglage maître éteint : le balayage ne fait rien (le kit reste en sortie).
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Military = require("script.faction.military")
local Armee = require("script.robots.armee")
local Ordres = require("script.robots.ordres")
require("script.robots.soutien") -- lot RB-4 : soin de la Cloche, Truelle
require("script.robots.geant")   -- lot RB-5 : géants (chemin, munition)
local Ro = require("shared.content.robots")
local Mo = require("shared.robots.modele")

local Usine = {}

local KNOWN = {}
for _, r in ipairs(Ro.ROBOTS) do KNOWN[r.id] = true end

local PERIOD = 60       -- ticks entre deux lectures des ateliers
local PRUNE_PERIOD = 300 -- balayage de sécurité du registre : tous les 300 ticks (sur le numéro de tick : rien hors de global)

local function insert_sorted(list, v)
  local i = #list
  while i >= 1 and list[i] > v do i = i - 1 end
  if list[i] == v then return false end
  table.insert(list, i + 1, v)
  return true
end

local function remove_value(list, v)
  for i = 1, #list do
    if list[i] == v then table.remove(list, i) return end
  end
end

---------------------------------------------------------------------------------------------------
-- Suivi des ateliers
---------------------------------------------------------------------------------------------------
local function track(e)
  if not (e and e.valid and e.unit_number and Ro.is_workshop(e.name)) then return end
  local s = Armee.S()
  if not s then return end
  insert_sorted(s.list, e.unit_number)
  local rec = s.factories[e.unit_number]
  if rec then rec.e = e else s.factories[e.unit_number] = { e = e } end
end

local function on_built(e) track(e.created_entity or e.entity) end

--- Relit toutes les surfaces (surfaces par indice) : sauvegarde d'avant le lot, ou atelier posé sans événement.
local function rescan()
  local surfaces = {}
  for _, surf in pairs(game.surfaces) do surfaces[#surfaces + 1] = surf end -- trié juste après
  table.sort(surfaces, function(a, b) return a.index < b.index end)
  local names = {}
  for _, w in ipairs(Ro.FACTORIES) do names[#names + 1] = w.name end
  for _, surf in ipairs(surfaces) do
    for _, e in ipairs(surf.find_entities_filtered({ name = names })) do track(e) end
  end
end

--- Retire de la liste les ateliers que le moteur n'a plus.
local function forget_gone(s)
  local gone = {}
  for _, un in ipairs(s.list) do
    local rec = s.factories[un]
    if not (rec and rec.e and rec.e.valid) then gone[#gone + 1] = un end
  end
  for _, un in ipairs(gone) do
    s.factories[un] = nil
    remove_value(s.list, un)
  end
end

---------------------------------------------------------------------------------------------------
-- La file (lot RB-2) : « maintenir N » dans l'ordre, et la recette qui la suit
---------------------------------------------------------------------------------------------------
--- Lot RB-2 : l'ancien « maintenir N » (rec.keep, RB-1) devient une entrée de la file (rec.queue), dans l'ordre des données.
local function migrate(rec)
  if not rec.keep then return end
  local queue = rec.queue or {}
  for _, r in ipairs(Ro.ROBOTS) do
    local n = rec.keep[r.id]
    if n ~= nil then queue = Mo.queue_set(queue, r.id, n, KNOWN) end
  end
  rec.queue, rec.keep = queue, nil
end

--- Rend au monde ce que `set_recipe` a rendu (RB0 E7 : tout, ingrédients et kits compris) : dans un coffre voisin (à 4 tuiles) s'il
--- y a de la place, sinon au sol près de la machine. Noms triés (déterminisme). Rien n'est jamais détruit.
local function give_back(e, back)
  local names = {}
  for name in pairs(back) do names[#names + 1] = name end -- trié juste après
  table.sort(names)
  if #names == 0 then return end
  local p = e.position
  local boxes = e.surface.find_entities_filtered({ area = { { p.x - 4, p.y - 4 }, { p.x + 4, p.y + 4 } },
    type = { "container", "logistic-container" }, force = e.force })
  table.sort(boxes, function(a, b) return a.unit_number < b.unit_number end)
  for _, name in ipairs(names) do
    local left = back[name]
    for _, box in ipairs(boxes) do
      if left <= 0 then break end
      if box.valid then left = left - box.insert({ name = name, count = left }) end
    end
    if left > 0 then e.surface.spill_item_stack(p, { name = name, count = left }, true) end
  end
end

--- La file impose-t-elle une autre recette (Mo.recipe_wanted) ? Si oui et si le moment est sûr (Mo.recipe_switch_ok), change la
--- recette et rend le contenu. Rend vrai si la recette a changé.
local function drive_recipe(e, rec, inv, tick)
  if not (rec.queue and #rec.queue > 0) then return false end
  local cur = e.get_recipe()
  local cur_r = cur and Ro.robot_of_recipe(cur.name)
  local cur_id = cur_r and cur_r.id
  local force = e.force
  local have, blocked = {}, true
  for _, r in ipairs(Ro.ROBOTS) do
    local kits = inv.get_item_count(r.kit)
    have[r.id] = Armee.have(force.name, r.id) + kits
    local target = Mo.queue_target(rec.queue, r.id)
    -- un kit dont la cible est atteinte reste bloqué en sortie : il ne retient pas le changement de recette
    if kits > 0 and not (target ~= nil and Armee.have(force.name, r.id) >= target) then blocked = false end
  end
  local want = Mo.recipe_wanted(rec.queue, have, cur_id)
  if not want then return false end
  local ok = Mo.recipe_switch_ok({
    current = cur_id, progress = e.crafting_progress, output_blocked = blocked and not inv.is_empty(), output_empty = inv.is_empty(),
    since = (tick and rec.switched) and (tick - rec.switched) or 1000000,
    min_gap = cur_r and math.ceil(cur_r.time * 60 / math.max(e.crafting_speed, 0.01)) or 0,
  })
  if not ok then return false end
  local back = e.set_recipe(Ro.robot(want).recipe)
  rec.switched = tick
  give_back(e, back or {})
  log(string.format("[FO-ROBOTS] recette %d %s -> %s (file de %d)", e.unit_number, tostring(cur_id), want, #rec.queue))
  return true
end

---------------------------------------------------------------------------------------------------
-- Le balayage : kit -> unité
---------------------------------------------------------------------------------------------------
--- Un atelier : suit la file, puis retire au plus un kit par robot s'il y a de la place et pose l'unité. Rend le nombre d'unités
--- posées.
local function process(e, rec, tick)
  local inv = e.get_output_inventory()
  if not inv then return 0 end
  migrate(rec)
  drive_recipe(e, rec, inv, tick)
  if inv.is_empty() then return 0 end
  local s = Armee.S()
  local w = Ro.factory(e.name)
  local force = e.force
  local used = Armee.used(force.name)
  local made = 0
  for _, r in ipairs(Ro.robots_of(e.name)) do
    if inv.get_item_count(r.kit) > 0 then
      -- lot BOURDON-MINEURS : un géant sorti pendant ce balayage est déjà au registre (Armee.create -> Mo.add) : Armee.giants le compte ; l'ancien
      -- compte « giants_made » en plus le comptait deux fois (un 2e géant refusé à tort dans le même balayage)
      local ok = Mo.can_release(Armee.release_params(force, r, Mo.queue_target(rec.queue, r.id), used))
      if ok and inv.remove({ name = r.kit, count = 1 }) == 1 then
        local rally = rec.rally or Mo.default_rally(e.position, w.size)
        local u = Armee.create(e.surface, force, r.id, Mo.out_point(e.position, w.size), rally, e.unit_number)
        if u then
          s.stats.kits_removed = s.stats.kits_removed + 1
          used = used + r.points
          made = made + 1
        else
          inv.insert({ name = r.kit, count = 1 }) -- rien de perdu : le kit revient, on réessaiera
          s.stats.create_failed = s.stats.create_failed + 1
        end
      end
    end
  end
  -- Lot BOURDON-SORTIE : objets d'autres lots qui sortent de l'usine comme un kit (le Bourdon fini au Portique : script/robots/bourdon.lua)
  if Armee.hooks.extra_release then
    made = made + Armee.hooks.extra_release(e, inv, rec.rally or Mo.default_rally(e.position, w.size))
  end
  return made
end

--- Un balayage de tous les ateliers (liste triée). Réglage maître éteint : rien. `tick` : numéro du tick (nil : pas de balayage
--- de sécurité du registre).
function Usine.sweep(tick)
  local s = Armee.S()
  if not s or not Armee.enabled() then return 0 end
  forget_gone(s)
  local made = 0
  for _, un in ipairs(s.list) do
    local rec = s.factories[un]
    made = made + process(rec.e, rec, tick)
  end
  if tick and tick % PRUNE_PERIOD == 0 then Armee.prune() end
  return made
end

---------------------------------------------------------------------------------------------------
-- Réglages d'un atelier (lot RB-2 : panneau de la machine, outil de ralliement, interface distante)
---------------------------------------------------------------------------------------------------
--- L'enregistrement d'un atelier (nil s'il est inconnu ou retiré).
function Usine.record(workshop)
  local s = Armee.S()
  local rec = s and s.factories[workshop]
  if rec and rec.e and rec.e.valid then return rec end
  return nil
end

--- Ralliement d'un atelier : le sien, sinon le point par défaut au sud de sa sortie. Rend { x, y }.
function Usine.rally_of(rec)
  if rec.rally then return rec.rally end
  return Mo.default_rally(rec.e.position, Ro.factory(rec.e.name).size)
end

--- « Maintenir N » d'un robot (n nil : pas de limite). Rend vrai si le réglage a changé. Écrit dans la file (migrée au passage).
function Usine.set_target(workshop, id, n)
  local rec = Usine.record(workshop)
  if not (rec and Ro.robot(id)) then return false end
  migrate(rec)
  local queue, changed = Mo.queue_set(rec.queue, id, n, KNOWN)
  rec.queue = queue
  return changed
end

--- Monte (-1) ou descend (+1) un robot dans la file.
function Usine.move_target(workshop, id, delta)
  local rec = Usine.record(workshop)
  if not rec then return false end
  migrate(rec)
  local queue, changed = Mo.queue_move(rec.queue, id, delta)
  rec.queue = queue
  return changed
end

--- Fixe (x, y) ou, sans coordonnées, efface le ralliement d'un atelier.
function Usine.set_rally(workshop, x, y)
  local rec = Usine.record(workshop)
  if not rec then return false end
  if x == nil then
    rec.rally = nil
  elseif Mo.valid_point({ x = x, y = y }) then
    rec.rally = { x = x, y = y }
  else
    return false
  end
  return true
end

--- Ralliements des ateliers d'une force : { [atelier] = { x, y } } et le premier (ordre des numéros) comme repli, ou nil.
function Usine.rallies(force_name)
  local s = Armee.S()
  local out, first = {}, nil
  if not s then return out, nil end
  for _, un in ipairs(s.list) do
    local rec = s.factories[un]
    if rec and rec.e and rec.e.valid and rec.e.force.name == force_name then
      local p = Usine.rally_of(rec)
      out[un] = p
      first = first or p
    end
  end
  return out, first
end

Events.on_nth_tick(PERIOD, function(e) Usine.sweep(e.tick) end)
Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)
Events.on(defines.events.script_raised_revive, on_built)
Events.on_init(rescan)
Events.on_configuration_changed(rescan)

---------------------------------------------------------------------------------------------------
-- Interface distante « fo-robots » (bancs ; l'interface du joueur viendra au lot RB-2)
---------------------------------------------------------------------------------------------------
local function force_of(name) return game.forces[name] end

local function by_id_table(force_name)
  local out = {}
  for _, r in ipairs(Ro.ROBOTS) do out[r.id] = Armee.have(force_name, r.id) end
  return out
end

remote.add_interface("fo-robots", {
  --- Pose un robot (plafond respecté) : rend le numéro d'unité, ou nil et la raison.
  spawn = function(force_name, id, x, y, rx, ry)
    local force = force_of(force_name)
    if not force then return nil, "force inconnue" end
    local rally = rx and { x = rx, y = ry } or nil
    local u, why = Armee.spawn(game.surfaces[1], force, id, { x = x, y = y }, rally)
    return u and u.unit_number or nil, why
  end,
  --- Sélection puis ordre : area = { x0, y0, x1, y1 } ou { x, y, radius } ; rend { selected, ordered }.
  order = function(force_name, kind, x, y, area, radius)
    local force = force_of(force_name)
    if not force then return { selected = 0, ordered = 0 } end
    local sel, n = Ordres.select_and_order(force, game.surfaces[1], area, kind, { x = x, y = y }, radius)
    return { selected = sel, ordered = n }
  end,
  --- Point de ralliement d'un atelier (numéro d'unité de l'atelier).
  set_rally = function(workshop, x, y) return Usine.set_rally(workshop, x, y) end,
  --- « Maintenir N » d'un atelier pour un robot (nil : pas de limite) : une entrée de la file (lot RB-2).
  set_keep = function(workshop, id, n) return Usine.set_target(workshop, id, n) end,
  --- Monte (-1) ou descend (+1) un robot dans la file d'un atelier.
  move_keep = function(workshop, id, delta) return Usine.move_target(workshop, id, delta) end,
  --- Lecture : { enabled, used, cap, age, units, by_id, workshops, stats } pour une force.
  state = function(force_name)
    local s = Armee.S()
    local force = force_of(force_name)
    if not (s and force) then return nil end
    local stats = {}
    for _, k in ipairs({ "created", "lost", "kits_removed", "create_failed", "pruned", "orders", "ordered" }) do
      stats[k] = s.stats[k]
    end
    return {
      enabled = Armee.enabled(), used = Armee.used(force_name), cap = Armee.cap(force), age = Armee.age(force),
      units = Mo.units_of(s.ledger, force_name), by_id = by_id_table(force_name), workshops = #s.list, stats = stats,
    }
  end,
  --- Rally, « keep » et file d'un atelier.
  workshop = function(workshop)
    local s = Armee.S()
    local rec = s and s.factories[workshop]
    if not rec then return nil end
    migrate(rec)
    local keep, queue = {}, {}
    for _, r in ipairs(Ro.ROBOTS) do keep[r.id] = Mo.queue_target(rec.queue, r.id) end
    for i, q in ipairs(rec.queue or {}) do queue[i] = { id = q.id, n = q.n } end
    return { rally = rec.rally and { x = rec.rally.x, y = rec.rally.y } or nil, keep = keep, queue = queue, valid = rec.e.valid,
      home_units = #Mo.units_at(s.ledger, workshop) }
  end,
  --- Un robot inscrit (bancs) : { name, x, y, valid } ; nil s'il est inconnu.
  unit_info = function(unit_number)
    local e = Armee.entity(unit_number)
    if not e then return nil end
    return { name = e.name, x = e.position.x, y = e.position.y, force = e.force.name, health = e.health, max = e.prototype.max_health }
  end,
  --- Fixe l'âge d'une force pour le plafond et les géants (bancs seulement) ; `age` nil l'efface.
  set_age = function(force_name, age)
    local s = Armee.S()
    if not s then return false end
    s.age_override = s.age_override or {}
    s.age_override[force_name] = age
    return true
  end,
  --- Blesse un robot inscrit (bancs) : sa santé devient `frac` de son maximum ; vrai s'il existait.
  hurt = function(unit_number, frac)
    local e = Armee.entity(unit_number)
    if not e then return false end
    e.health = e.prototype.max_health * frac
    return true
  end,
  --- Tue un robot inscrit (bancs : mort réelle, événement compris) ; vrai s'il existait.
  kill = function(unit_number)
    local e = Armee.entity(unit_number)
    if not e then return false end
    e.die()
    return true
  end,
  --- Un robot de faction vu par sa faction (bancs) : { listed, kind, soldiers, garrison, near } ; nil si l'unité n'a pas de propriétaire.
  faction_view = function(unit_number)
    local owner = State.owner(unit_number)
    local f = owner and State.faction(owner.f)
    if not f then return nil end
    local near, far = Military.garrison_split(f)
    local e = Armee.entity(unit_number)
    return { listed = f.soldiers[unit_number] ~= nil, kind = owner.kind, soldiers = f.soldiers_count,
      garrison = f.garrison_count, near = near, far = far,
      hq = f.hq_pos and { x = f.hq_pos.x, y = f.hq_pos.y } or nil, at = e and { x = e.position.x, y = e.position.y } or nil }
  end,
  --- Cohérence du registre : vrai, ou faux et la raison.
  check = function()
    local s = Armee.S()
    if not s then return false, "etat absent" end
    return Mo.check(s.ledger)
  end,
  --- Un balayage tout de suite (bancs).
  sweep = function() return Usine.sweep() end,
})

return Usine
