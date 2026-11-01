--[[
  Lot RB-1 CHAÎNE (31/10) : les ORDRES du joueur à ses robots, en appel direct (l'outil de sélection à glisser viendra au lot
  RB-2 : même fonctions, appelées par ses événements). Jamais de contrôle direct d'un robot : le joueur choisit une zone, puis un
  ordre ; le moteur conduit chaque unité (chemin, combat).

  - Sélection : les robots INSCRITS d'une force dans une zone (rectangle, ou rayon autour d'un point), triés par numéro d'unité.
  - Ordre : « move » (aller en un point) ou « attack » (marche-attaque sur une zone). Chaque unité reçoit sa propre commande
    (pas de groupe : F171 à F174 — départ vers un groupe lointain perdu, membres retirés sans événement — ne s'appliquent pas).
  - Les unités d'une FACTION n'obéissent pas au joueur : leur garnison, leurs raids et leur retour sont ceux de
    script/faction/military.lua.
  Réglage maître éteint : aucun ordre n'est donné.
]]

local State = require("script.faction.state")
local Ro = require("shared.content.robots")
local Mo = require("shared.robots.modele")
local Armee = require("script.robots.armee")

local Ordres = {}

--- Robots inscrits de `force` dans `area` = { x0, y0, x1, y1 } (rectangle) ou { x, y, radius } (disque), sur `surface`.
--- Rend la liste d'entités triée par numéro d'unité.
function Ordres.select(force, surface, area)
  local s = Armee.S()
  if not (s and force and surface and type(area) == "table") then return {} end
  local found
  if area.radius then
    found = surface.find_entities_filtered({ type = { "unit", "spider-vehicle" }, force = force, position = { x = area.x, y = area.y }, radius = area.radius })
  else
    found = surface.find_entities_filtered({ type = { "unit", "spider-vehicle" }, force = force, area = { { area.x0, area.y0 }, { area.x1, area.y1 } } })
  end
  local out = {}
  for _, e in ipairs(found) do
    if e.valid and e.unit_number and s.ledger.units[e.unit_number] and Ro.parse_unit(e.name) then out[#out + 1] = e end
  end
  table.sort(out, function(a, b) return a.unit_number < b.unit_number end)
  return out
end

--- Donne `kind` ("move" ou "attack") à chaque entité de la liste, vers `pos` (rayon `radius` pour une marche-attaque).
--- Rend (nombre d'ordres donnés, raison du refus ou nil).
function Ordres.order(force, entities, kind, pos, radius)
  local s = Armee.S()
  if not s then return 0, "etat absent" end
  if not Armee.enabled() then return 0, "reglage eteint" end
  if not Mo.is_order(kind) then return 0, "ordre inconnu" end
  if not Mo.valid_point(pos) then return 0, "point invalide" end
  if State.by_force(force.name) then return 0, "faction" end
  local p = { x = pos.x or pos[1], y = pos.y or pos[2] }
  local n = 0
  for _, e in ipairs(entities) do
    if e.valid and s.ledger.units[e.unit_number] and e.force == force and Armee.send(e, kind, p, radius) then n = n + 1 end
  end
  s.stats.orders = s.stats.orders + 1
  s.stats.ordered = s.stats.ordered + n
  log(string.format("[FO-ROBOTS] ordre %s force=%s : %d unite(s) vers (%.1f, %.1f)", kind, force.name, n, p.x, p.y))
  return n
end

--- Sélection puis ordre en un appel (ce que fera l'outil de glisser : zone, puis marche-attaque au centre de la zone).
--- Rend (sélectionnées, ordonnées).
function Ordres.select_and_order(force, surface, area, kind, pos, radius)
  local sel = Ordres.select(force, surface, area)
  local n = Ordres.order(force, sel, kind, pos, radius)
  return #sel, n
end

return Ordres
