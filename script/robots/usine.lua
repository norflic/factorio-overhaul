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
local Ro = require("shared.content.robots")
local Mo = require("shared.robots.modele")

local Usine = {}

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
  for _, w in ipairs(Ro.WORKSHOPS) do names[#names + 1] = w.name end
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
-- Le balayage : kit -> unité
---------------------------------------------------------------------------------------------------
--- Un atelier : retire au plus un kit par robot s'il y a de la place, pose l'unité. Rend le nombre d'unités posées.
local function process(e, rec)
  local inv = e.get_output_inventory()
  if not inv or inv.is_empty() then return 0 end
  local s = Armee.S()
  local w = Ro.workshop(e.name)
  local force = e.force
  local cap = Armee.cap(force)
  local used = Armee.used(force.name)
  local made = 0
  for _, r in ipairs(Ro.robots_of(e.name)) do
    if inv.get_item_count(r.kit) > 0 then
      local ok = Mo.can_release({
        used = used, cap = cap, points = r.points, have = Armee.have(force.name, r.id), keep = rec.keep and rec.keep[r.id],
      })
      if ok and inv.remove({ name = r.kit, count = 1 }) == 1 then
        local rally = rec.rally or Mo.default_rally(e.position, w.size)
        local u = Armee.create(e.surface, force, r.id, Mo.out_point(e.position, w.size), rally)
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
    made = made + process(rec.e, rec)
  end
  if tick and tick % PRUNE_PERIOD == 0 then Armee.prune() end
  return made
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
  set_rally = function(workshop, x, y)
    local s = Armee.S()
    local rec = s and s.factories[workshop]
    if not rec then return false end
    rec.rally = { x = x, y = y }
    return true
  end,
  --- « Maintenir N » d'un atelier pour un robot (nil : pas de limite).
  set_keep = function(workshop, id, n)
    local s = Armee.S()
    local rec = s and s.factories[workshop]
    if not (rec and Ro.robot(id)) then return false end
    rec.keep = rec.keep or {}
    rec.keep[id] = n
    return true
  end,
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
  --- Rally et « keep » d'un atelier.
  workshop = function(workshop)
    local s = Armee.S()
    local rec = s and s.factories[workshop]
    if not rec then return nil end
    local keep = {}
    for _, r in ipairs(Ro.ROBOTS) do keep[r.id] = rec.keep and rec.keep[r.id] or nil end
    return { rally = rec.rally and { x = rec.rally.x, y = rec.rally.y } or nil, keep = keep, valid = rec.e.valid }
  end,
  --- Un robot inscrit (bancs) : { name, x, y, valid } ; nil s'il est inconnu.
  unit_info = function(unit_number)
    local e = Armee.entity(unit_number)
    if not e then return nil end
    return { name = e.name, x = e.position.x, y = e.position.y, force = e.force.name }
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
