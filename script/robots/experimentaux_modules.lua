--[[
  Lot DESIGN-MODULES (5/11) : MODULES DES GÉANTS en jeu. Règle pure : shared/robots/experimentaux_modules.lua ; prototypes :
  prototypes/experimentaux_modules.lua. PROPOSITION : rien en jeu sans le verdict du DC.

  Partage avec le lot EXPERIMENTAUX (branchement 77926be9, script/robots/experimentaux_geants.lua, qui reste à lui) :
  - le géant applique lui-même le bonus (Ech.effectif : portée de ciblage et rayon de zone × (1 + portée), salve × (1 + puissance) ;
    la cadence ne change pas) ; il le lit dans g.bonus, écrit par Geants.set_bonus(numéro, portée, puissance) en FRACTIONS (0,2 = +20 %) ;
  - ce script lit les GRILLES et réécrit le bonus de tous les géants inscrits (K.S().giants, quelques-uns) quand un module est posé ou retiré
    (joueur ou script) et quand un géant est posé (objet qui porte sa grille compris) ; aucun état propre, rien à migrer ;
  - la MARQUE VISIBLE des modules, une fois par SALVE, si le géant offre le crochet Geants.ecoute (proposé au lot EXPERIMENTAUX) :
    portée : anneau violet de la zone agrandie au point visé, et trait de visée en tirets si ce point est au-delà de la portée de base ;
    puissance : anneau cramoisi au point visé et halo sous le géant. Au plus 9 objets de `rendering` par salve, durée au plus égale à la
    cadence de zone (rien ne s'empile d'une salve à l'autre).
  - Texte au joueur qui pose ou retire un module dans la grille d'un géant : bonus total et plafonds.
  - XM.garnir(e, age) : garniture d'un géant de faction (réserve : aucune faction ne pose aujourd'hui de géant expérimental).
  Déterminisme : grilles lues comme des LISTES (LuaEquipmentGrid::equipment), géants dans l'ordre de leur liste ; aucun pairs.
]]

local Events = require("script.core.events")
local Xp = require("shared.robots.experimentaux")
local Mod = require("shared.robots.experimentaux_modules")
local K = require("script.robots.experimentaux_commun")
local Geants = require("script.robots.experimentaux_geants")

local XM = {}

--- Couleur du `rendering` : le moteur la lit PRÉMULTIPLIÉE (gi1, 4/11).
local function rgba(r, g, b, a) return { r = r * a, g = g * a, b = b * a, a = a } end

local VIOLET = { 0.72, 0.45, 1.0 }
local CRAMOISI = { 1.0, 0.16, 0.10 }
XM.TTL_MAX = 90          -- durée d'une marque (ticks), ramenée à la cadence de zone du géant si elle est plus courte

--- Noms des équipements posés dans la grille d'une entité, en liste ; nil sans grille.
local function noms(e)
  if not (e and e.valid) then return nil end
  local grid = e.grid
  if not grid then return nil end
  local out = {}
  for _, eq in ipairs(grid.equipment) do out[#out + 1] = eq.name end
  return out
end

--- Bonus d'un géant (pourcents entiers par type, plafonnés).
function XM.bonus(e)
  local n = noms(e)
  if not n then return Mod.ZERO end
  return Mod.bonus(n)
end

--- Fractions envoyées au géant (0,25 = +25 %).
function XM.fractions(b) return b.portee / 100, b.puissance / 100 end

--- Réécrit le bonus de tous les géants inscrits ; rend le nombre de géants mis à jour.
function XM.sync()
  local s = K.S()
  if not s or not s.giants then return 0 end
  local n = 0
  for _, g in ipairs(s.giants) do
    if g.e and g.e.valid then
      local b = XM.bonus(g.e)
      local p, f = XM.fractions(b)
      if Geants.set_bonus(g.un, p, f) then
        n = n + 1
        K.journal("modules geant #%d portee +%d %% puissance +%d %%", g.un, b.portee, b.puissance)
      end
    end
  end
  return n
end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

--- Durée d'une marque : au plus la cadence de zone du géant (sinon les marques de deux salves s'empilent, Tournesol compris).
function XM.ttl(r)
  local cad = r.zone_cooldown or r.cooldown or XM.TTL_MAX
  return math.max(1, math.min(XM.TTL_MAX, cad))
end

--- La marque d'une SALVE : `e` le géant, `r` son entrée de Xp.GEANTS, `bonus` en fractions ({ portee, puissance }), `c` le point visé,
--- `eff` les valeurs effectives (Ech.effectif : range, zone, salve). Rend le nombre d'objets de `rendering` posés.
function XM.salve(e, r, bonus, c, eff)
  if not (e and e.valid and bonus and c and eff) then return 0 end
  local bp, bf = bonus.portee or 0, bonus.puissance or 0
  if bp <= 0 and bf <= 0 then return 0 end
  local s, ttl, n = e.surface, XM.ttl(r), 0
  local p = { c.x, c.y }
  local zone = eff.zone or 0
  if bp > 0 then
    local v = VIOLET
    if zone > 0 then
      rendering.draw_circle({ color = rgba(v[1], v[2], v[3], 0.85), radius = zone, width = 6, filled = false, target = p, surface = s,
        time_to_live = ttl, draw_on_ground = true })
      n = n + 1
    end
    if dist(e.position, c) > r.range then
      -- trait de visée : le point n'est atteint que grâce à la portée en plus
      rendering.draw_line({ color = rgba(v[1], v[2], v[3], 0.75), width = 3, from = e, to = p, surface = s, dash_length = 1.2, gap_length = 0.6,
        time_to_live = ttl })
      rendering.draw_circle({ color = rgba(v[1], v[2], v[3], 0.95), radius = 2.6, width = 5, filled = false, target = p, surface = s,
        time_to_live = ttl })
      n = n + 2
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        rendering.draw_line({ color = rgba(v[1], v[2], v[3], 0.95), width = 4, from = { c.x + d[1] * 2.6, c.y + d[2] * 2.6 },
          to = { c.x + d[1] * 3.8, c.y + d[2] * 3.8 }, surface = s, time_to_live = ttl })
        n = n + 1
      end
    end
  end
  if bf > 0 then
    local k = math.min(1, bf)
    local q = CRAMOISI
    rendering.draw_circle({ color = rgba(q[1], q[2], q[3], 0.55 + 0.35 * k), radius = math.max(1, zone - 1), width = 8, filled = false,
      target = p, surface = s, time_to_live = ttl, draw_on_ground = true })
    rendering.draw_circle({ color = rgba(q[1], q[2], q[3], 0.18 + 0.17 * k), radius = 4 + 4 * k, filled = true, target = e, surface = s,
      time_to_live = ttl, draw_on_ground = true })
    n = n + 2
  end
  return n
end

if Geants.ecoute then Geants.ecoute(XM.salve) end

--- Garniture d'un géant de faction à l'âge `age` (Mod.loadout) ; rend le nombre de modules posés.
function XM.garnir(e, age)
  if not (e and e.valid and e.grid) then return 0 end
  local r = Xp.of_name(e.name)
  if not (r and r.is_giant) then return 0 end
  local n = 0
  for _, name in ipairs(Mod.loadout(r.id, age)) do
    if e.grid.put({ name = name }) then n = n + 1 end
  end
  XM.sync()
  return n
end

---------------------------------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------------------------------
local function grille_de_geant(grid)
  return grid and grid.valid and grid.prototype.name:sub(1, #Mod.GRID_PREFIX) == Mod.GRID_PREFIX
end

local function equipement(ev)
  if not grille_de_geant(ev.grid) then return end
  XM.sync()
  if not ev.player_index then return end
  local player = game.get_player(ev.player_index)
  if not (player and player.valid) then return end
  local names = {}
  for _, eq in ipairs(ev.grid.equipment) do names[#names + 1] = eq.name end
  local b = Mod.bonus(names)
  local pt, pu = Mod.type("portee"), Mod.type("puissance")
  player.create_local_flying_text({ create_at_cursor = true, time_to_live = 150,
    text = { "fo-xp-modules.bilan", tostring(b.portee), tostring(pt.cap), tostring(b.puissance), tostring(pu.cap) } })
end

--- Un géant posé (après son inscription par experimentaux_geants, abonné avant ce script) : son bonus suit la grille qu'il porte.
local function pose(ev)
  local e = ev.created_entity or ev.entity
  if not (e and e.valid) then return end
  local r = Xp.of_name(e.name)
  if r and r.is_giant then XM.sync() end
end

Events.on(defines.events.on_player_placed_equipment, equipement)
Events.on(defines.events.on_player_removed_equipment, equipement)
Events.on(defines.events.on_equipment_inserted, equipement)
Events.on(defines.events.on_equipment_removed, equipement)
Events.on(defines.events.on_built_entity, pose)
Events.on(defines.events.on_robot_built_entity, pose)
Events.on(defines.events.script_raised_built, pose)
Events.on(defines.events.script_raised_revive, pose)

return XM
