--[[
  Lot RB-4 GAMME (1/11) : les robots de SOUTIEN, côté exécution (PLAN fo-logs/2026-10-31_ROBOTS §1 « Bouclier » et « Ingénieur »).
  Données : shared/content/robots.lua (champs `heal` et `engineer`) ; PV de soin calibrés par shared/robots/duel.lua.

  - Cloche (heal) : une unité n'a pas de grille d'équipement (equipment_grid est sur VehiclePrototype) : le bouclier est SIMULÉ par un
    soin en impulsion toutes les `Ro.SUPPORT_PERIOD` ticks. Elle rend `amount` PV à chaque robot ou araignée ALLIÉ blessé dans `radius`
    tuiles, 30 au plus (les plus petits numéros d'unité d'abord : déterminisme), plus un cercle `rendering` d'une demi-seconde.
  - Truelle (engineer) : ravive au plus `ghosts` fantômes de construction de sa force dans `radius` tuiles (LuaEntity.revive, 33 à 83 µs,
    F295) ET répare au plus `repair_max` murs, portes et tourelles blessés de `repair` PV. Les matériaux du fantôme sont PRIS, jamais
    inventés : dans un coffre de sa force à `radius` tuiles (le plus petit numéro d'unité qui les a), sinon dans l'inventaire d'un joueur
    connecté de la force (le premier par indice). Elle ne bâtit aucune base : elle ne pose que ce qu'un fantôme demande.
  Déterminisme : robots en liste triée (registre), cibles triées par numéro d'unité, fantômes par (y, x), joueurs par indice ; aucun pairs
  décisionnel, aucune horloge. Réglage maître éteint : rien. Aucun require dans un gestionnaire (F24).
]]

local Events = require("script.core.events")
local Armee = require("script.robots.armee")
local Ro = require("shared.content.robots")
local Mo = require("shared.robots.modele")

local Soutien = {}

local TARGET_TYPES = { "unit", "spider-vehicle" }
local REPAIR_TYPES = { "wall", "gate", "ammo-turret", "electric-turret", "fluid-turret", "turret", "artillery-turret" }

local HEALERS, ENGINEERS = {}, {}
for _, r in ipairs(Ro.ROBOTS) do
  if r.heal then HEALERS[#HEALERS + 1] = r end
  if r.engineer then ENGINEERS[#ENGINEERS + 1] = r end
end

local function by_unit_number(a, b) return a.unit_number < b.unit_number end

---------------------------------------------------------------------------------------------------
-- Cloche
---------------------------------------------------------------------------------------------------
--- Une impulsion de soin autour de `e` (la Cloche). Rend (nombre de soignés, PV rendus au total).
function Soutien.heal(e, h)
  local list = e.surface.find_entities_filtered({ position = e.position, radius = h.radius, force = e.force, type = TARGET_TYPES })
  table.sort(list, by_unit_number)
  local n, total = 0, 0
  for _, t in ipairs(list) do
    if n >= h.max then break end
    if t.valid and t.unit_number then
      local hp, mx = t.health, t.prototype.max_health
      if hp and mx and hp < mx then
        local add = math.min(h.amount, mx - hp)
        t.health = hp + add
        n = n + 1
        total = total + add
      end
    end
  end
  if n > 0 then
    rendering.draw_circle({ color = { r = 0.25, g = 0.8, b = 0.6, a = 0.25 }, radius = h.radius, width = 2, filled = false,
      target = e, surface = e.surface, time_to_live = 30 })
  end
  return n, total
end

---------------------------------------------------------------------------------------------------
-- Truelle
---------------------------------------------------------------------------------------------------
--- Où prendre `count` de `name` : un coffre de la force à `radius` tuiles de `e` (le plus petit numéro d'unité), sinon le premier joueur
--- connecté de la force (par indice) qui les porte. Rend la source (coffre ou joueur) ou nil. Les deux savent remove_item et insert.
local function carrier(e, radius, name, count)
  local boxes = e.surface.find_entities_filtered({ position = e.position, radius = radius, force = e.force, type = "container" })
  table.sort(boxes, by_unit_number)
  for _, b in ipairs(boxes) do
    if b.valid and b.get_item_count(name) >= count then return b end
  end
  local players = {}
  for _, p in ipairs(e.force.connected_players) do players[#players + 1] = p end
  table.sort(players, function(a, b) return a.index < b.index end)
  for _, p in ipairs(players) do
    if p.valid and p.get_item_count(name) >= count then return p end
  end
  return nil
end

--- Ravive des fantômes autour de `e` : rend le nombre de fantômes ravivés.
function Soutien.raise_ghosts(e, eng)
  local ghosts = e.surface.find_entities_filtered({ position = e.position, radius = eng.radius, force = e.force, type = "entity-ghost" })
  table.sort(ghosts, function(a, b)
    if a.position.y ~= b.position.y then return a.position.y < b.position.y end
    return a.position.x < b.position.x
  end)
  local done = 0
  for _, g in ipairs(ghosts) do
    if done >= eng.ghosts then break end
    if g.valid then
      local needs = g.ghost_prototype.items_to_place_this
      local item = needs and needs[1]
      local p = item and carrier(e, eng.radius, item.name, item.count or 1)
      if p then
        local taken = p.remove_item({ name = item.name, count = item.count or 1 })
        if taken > 0 then
          local _, revived = g.revive({ raise_revive = true })
          if revived then
            done = done + 1
          else
            p.insert({ name = item.name, count = taken }) -- rien de perdu : le fantôme n'a pas pu être ravivé (place prise)
          end
        end
      end
    end
  end
  return done
end

--- Répare des bâtiments blessés autour de `e` : rend (nombre réparés, PV rendus).
function Soutien.repair(e, eng)
  local list = e.surface.find_entities_filtered({ position = e.position, radius = eng.radius, force = e.force, type = REPAIR_TYPES })
  table.sort(list, by_unit_number)
  local n, total = 0, 0
  for _, t in ipairs(list) do
    if n >= eng.repair_max then break end
    if t.valid and t.unit_number then
      local hp, mx = t.health, t.prototype.max_health
      if hp and mx and hp < mx then
        local add = math.min(eng.repair, mx - hp)
        t.health = hp + add
        n = n + 1
        total = total + add
      end
    end
  end
  return n, total
end

---------------------------------------------------------------------------------------------------
-- Balayage
---------------------------------------------------------------------------------------------------
--- Un balayage de tous les soutiens (liste triée du registre). Rend { healed, hp, revived, repaired }.
function Soutien.sweep()
  local out = { healed = 0, hp = 0, revived = 0, repaired = 0 }
  local s = Armee.S()
  if not s or not Armee.enabled() then return out end
  for _, r in ipairs(HEALERS) do
    for _, un in ipairs(Mo.units_with(s.ledger, r.id)) do
      local e = Armee.entity(un)
      if e then
        local n, total = Soutien.heal(e, r.heal)
        out.healed, out.hp = out.healed + n, out.hp + total
      end
    end
  end
  for _, r in ipairs(ENGINEERS) do
    for _, un in ipairs(Mo.units_with(s.ledger, r.id)) do
      local e = Armee.entity(un)
      if e then
        out.revived = out.revived + Soutien.raise_ghosts(e, r.engineer)
        local n = Soutien.repair(e, r.engineer)
        out.repaired = out.repaired + n
      end
    end
  end
  s.stats.healed = (s.stats.healed or 0) + out.healed
  s.stats.heal_hp = (s.stats.heal_hp or 0) + out.hp
  s.stats.revived = (s.stats.revived or 0) + out.revived
  s.stats.repaired = (s.stats.repaired or 0) + out.repaired
  return out
end

Events.on_nth_tick(Ro.SUPPORT_PERIOD, function() Soutien.sweep() end)

-- Interface distante « fo-robots-soutien » (bancs) : un balayage tout de suite, et les compteurs.
remote.add_interface("fo-robots-soutien", {
  sweep = function() return Soutien.sweep() end,
  stats = function()
    local s = Armee.S()
    if not s then return nil end
    return { healed = s.stats.healed or 0, heal_hp = s.stats.heal_hp or 0, revived = s.stats.revived or 0, repaired = s.stats.repaired or 0 }
  end,
})

return Soutien
