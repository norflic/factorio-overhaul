--[[
  Lot DESIGN-MODULES (5/11) : MODULES DES GÉANTS en jeu. Règle pure : shared/robots/experimentaux_modules.lua ; prototypes :
  prototypes/experimentaux_modules.lua. PROPOSITION : rien en jeu sans le verdict du DC.

  - XM.stats(e, r) : portée et coup EFFECTIFS d'un géant, lus dans sa grille AU MOMENT DU TIR (rien en storage ici, rien à migrer ; le
    branchement garde seulement le coup effectif dans les tâches en cours du géant, qui vivent déjà en storage). Branchement attendu dans
    script/robots/experimentaux_geants.lua (lot EXPERIMENTAUX, non modifié ici) : patch proposé au lot EXPERIMENTAUX,
    fo-logs/2026-11-06_DESIGNS/modules/branchement-experimentaux_geants.diff (il rend aussi les modules d'un géant refusé au plafond).
  - La marque visible des modules, aux bons moments (critique du 5/11 : un clignement de 18 ticks posé au balayage mentait) :
    XM.visee(e, r, b, pos) quand le géant choisit une cible que seule sa portée en plus atteint : trait de visée violet en tirets et
    cercle de verrouillage, 90 ticks ; XM.impact(e, b, pos) à CHAQUE point qui reçoit des dégâts (arc du Cairn, nœud du Stylet, glace de la
    Trombe, geyser d'Ixion, foyer du Tournesol) : brûlure cramoisie au sol, 75 ticks, et lumière de nuit ; XM.aura(e, b) au départ du
    coup : halo cramoisi au sol sous le géant, 60 ticks. Tout est visible de JOUR (cercles du `rendering`), la lumière s'y ajoute la nuit.
  - Texte au joueur qui pose ou retire un module dans la grille d'un géant : bonus total et plafonds.
  - XM.garnir(e, age) : garniture d'un géant de faction (réserve : aucune faction ne pose aujourd'hui de géant expérimental).
  Déterminisme : la grille est lue comme une LISTE (LuaEquipmentGrid::equipment) et la règle somme des entiers ; aucun pairs.
]]

local Events = require("script.core.events")
local Xp = require("shared.robots.experimentaux")
local Mod = require("shared.robots.experimentaux_modules")

local XM = {}

--- Couleur du `rendering` : le moteur la lit PRÉMULTIPLIÉE (gi1, 4/11).
local function rgba(r, g, b, a) return { r = r * a, g = g * a, b = b * a, a = a } end

local VIOLET = { 0.72, 0.45, 1.0 }
local CRAMOISI = { 1.0, 0.16, 0.10 }
XM.TTL_VISEE = 90
XM.TTL_IMPACT = 75
XM.TTL_AURA = 60

--- Noms des équipements posés dans la grille d'une entité, en liste ; nil sans grille.
local function noms(e)
  if not (e and e.valid) then return nil end
  local grid = e.grid
  if not grid then return nil end
  local out = {}
  for _, eq in ipairs(grid.equipment) do out[#out + 1] = eq.name end
  return out
end

--- Bonus d'un géant (pourcents par type, plafonnés).
function XM.bonus(e)
  local n = noms(e)
  if not n then return Mod.ZERO end
  return Mod.bonus(n)
end

--- Portée et coup effectifs d'un géant `e` dont l'entrée de Xp.GEANTS est `r`.
function XM.stats(e, r)
  local b = XM.bonus(e)
  return { range = Mod.range(r, b), shot = Mod.shot(r, b), bonus = b }
end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function xy(p) return { p.x or p[1], p.y or p[2] } end

--- Visée : la cible (sa POSITION, relevée avant le coup qui peut la tuer) n'est atteinte que grâce à la portée en plus.
function XM.visee(e, r, b, pos)
  if not (e and e.valid and b and pos) or b.portee <= 0 then return false end
  local p = xy(pos)
  local tp = { x = p[1], y = p[2] }
  if not Mod.beyond_base(r, dist(e.position, tp)) then return false end
  local s = e.surface
  local c = VIOLET
  rendering.draw_line({ color = rgba(c[1], c[2], c[3], 0.75), width = 3, from = e, to = xy(tp), surface = s,
    dash_length = 1.2, gap_length = 0.6, time_to_live = XM.TTL_VISEE })
  rendering.draw_circle({ color = rgba(c[1], c[2], c[3], 0.95), radius = 2.6, width = 5, filled = false, target = xy(tp), surface = s,
    time_to_live = XM.TTL_VISEE })
  -- quatre crans du cercle de verrouillage
  for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
    rendering.draw_line({ color = rgba(c[1], c[2], c[3], 0.95), width = 4, from = { tp.x + d[1] * 2.6, tp.y + d[2] * 2.6 },
      to = { tp.x + d[1] * 3.8, tp.y + d[2] * 3.8 }, surface = s, time_to_live = XM.TTL_VISEE })
  end
  return true
end

--- Impact : un point qui reçoit les dégâts d'un coup renforcé (position ou entité).
function XM.impact(e, b, pos)
  if not (e and e.valid and b and pos) or b.puissance <= 0 then return false end
  local k = b.puissance / 100
  local p = xy(pos)
  local s = e.surface
  local c = CRAMOISI
  rendering.draw_circle({ color = rgba(c[1], c[2], c[3], 0.30 + 0.25 * k), radius = 1.2 + 2.2 * k, filled = true, target = p, surface = s,
    time_to_live = XM.TTL_IMPACT, draw_on_ground = true })
  rendering.draw_circle({ color = rgba(c[1], 0.45, 0.25, 0.9), radius = 1.2 + 2.2 * k, width = 3, filled = false, target = p, surface = s,
    time_to_live = XM.TTL_IMPACT, draw_on_ground = true })
  rendering.draw_light({ sprite = "utility/light_medium", target = p, surface = s, color = { r = c[1], g = c[2], b = c[3] },
    intensity = 0.5 + 0.5 * k, scale = 1.5 + 2 * k, time_to_live = XM.TTL_IMPACT })
  return true
end

--- Aura : halo cramoisi au sol sous le géant au départ d'un coup renforcé.
function XM.aura(e, b)
  if not (e and e.valid and b) or b.puissance <= 0 then return false end
  local k = b.puissance / 100
  local c = CRAMOISI
  rendering.draw_circle({ color = rgba(c[1], c[2], c[3], 0.18 + 0.17 * k), radius = 4 + 4 * k, filled = true, target = e, surface = e.surface,
    time_to_live = XM.TTL_AURA, draw_on_ground = true })
  rendering.draw_light({ sprite = "utility/light_medium", target = e, surface = e.surface, color = { r = c[1], g = c[2], b = c[3] },
    intensity = 0.5 + 0.5 * k, scale = 3 + 4 * k, time_to_live = XM.TTL_AURA })
  return true
end

--- Garniture d'un géant de faction à l'âge `age` (Mod.loadout) ; rend le nombre de modules posés.
function XM.garnir(e, age)
  if not (e and e.valid and e.grid) then return 0 end
  local r = Xp.of_name(e.name)
  if not (r and r.is_giant) then return 0 end
  local n = 0
  for _, name in ipairs(Mod.loadout(r.id, age)) do
    if e.grid.put({ name = name }) then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- Texte au joueur qui pose ou retire un module dans la grille d'un géant
---------------------------------------------------------------------------------------------------
local function grille_de_geant(grid)
  return grid and grid.valid and grid.prototype.name:sub(1, #Mod.GRID_PREFIX) == Mod.GRID_PREFIX
end

local function bilan(ev)
  if not grille_de_geant(ev.grid) then return end
  local player = game.get_player(ev.player_index)
  if not (player and player.valid) then return end
  local names = {}
  for _, eq in ipairs(ev.grid.equipment) do names[#names + 1] = eq.name end
  local b = Mod.bonus(names)
  local pt, pu = Mod.type("portee"), Mod.type("puissance")
  player.create_local_flying_text({ create_at_cursor = true, time_to_live = 150,
    text = { "fo-xp-modules.bilan", tostring(b.portee), tostring(pt.cap), tostring(b.puissance), tostring(pu.cap) } })
end

Events.on(defines.events.on_player_placed_equipment, bilan)
Events.on(defines.events.on_player_removed_equipment, bilan)

return XM
