--[[
  Lot RB-5 GÉANTS (1/11) : les GÉANTS (âges 13 à 15), des `spider-vehicle`, côté exécution. Données : shared/content/robots.lua
  (champ `giant`) ; plafond : Mo.giants_allowed (1, 2 puis 3 par force aux âges 13, 14 et 15) ; PV et dégâts : shared/robots/duel.lua.

  Ce que RB0 (E3, E9) a prouvé en moteur réel et qu'on utilise :
    - une araignée d'une force non ennemie, SANS conducteur, tire seule sur une cible militaire à portée
      (vehicle_automatic_targeting_parameters : valeur par défaut, aucune écriture) ; la munition se pose par script
      (get_inventory(defines.inventory.spider_ammo).insert) ;
    - elle franchit mur, forêt et falaise par ses pattes ; l'eau large la bloque : request_path (boîte ±1, masque d'eau) puis des points
      poussés dans l'autopilote, un sur GIANT_PATH_STEP, suffisent ;
    - un canon de portée 100 touche tous les relèvements (zones mortes à 60 au-delà de l'échelle 3) ;
    - les déchiqueteurs l'attaquent comme un soldat (cible militaire par défaut).
  Ordres : « move » (aller) et « attack » (aller, puis tenir : le canon fait le reste). Le chemin est demandé au moteur, le résultat
  arrive à on_script_path_request_finished ; F216 : un résultat peut arriver pour un géant déjà mort, on vérifie `valid` avant tout.
  Une araignée de FACTION n'est pas un soldat d'un groupe d'unités : elle reste où elle est née (garde du lieu), sans ordre.
  Déterminisme : registre en liste triée, aucun pairs décisionnel, aucune horloge ; état = nombres (global.fo.robots.giants, .paths).
]]

local Events = require("script.core.events")
local Armee = require("script.robots.armee")
local F = require("shared.faction.config")
local Ro = require("shared.content.robots")
local Mo = require("shared.robots.modele")
local XpG = require("script.robots.experimentaux_geants") -- règle d'échelle : salve de zone (lot EXPERIMENTAUX-PUISSANCE)

local Geant = {}

local GIANTS = Ro.giants()
local MAX_TRIES = 3
local PERIOD = 60

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function giants_table() return Armee.table_of("giants") end
local function paths_table() return Armee.table_of("paths") end

---------------------------------------------------------------------------------------------------
-- Munition et couleur
---------------------------------------------------------------------------------------------------
--- Remet de la munition dans le magasin du géant (au moins GIANT_AMMO.min, jusqu'à .top). Rend les obus ajoutés.
function Geant.top_up(u)
  local _, id = Ro.parse_unit(u.name)
  if not id then return 0 end
  local inv = u.get_inventory(defines.inventory.spider_ammo)
  if not inv then return 0 end
  local shell = Ro.shell_name(id)
  local have = inv.get_item_count(shell)
  if have >= Ro.GIANT_AMMO.min then return 0 end
  return inv.insert({ name = shell, count = Ro.GIANT_AMMO.top - have })
end

--- Pose d'un géant : couleur de la faction (une araignée se teint à l'exécution), munition.
function Geant.setup(u, f)
  if f then
    for _, fc in ipairs(F.factions) do
      if fc.key == f.key then u.color = { r = fc.color.r, g = fc.color.g, b = fc.color.b, a = 1 } end
    end
  end
  Geant.top_up(u)
end

---------------------------------------------------------------------------------------------------
-- Chemin et ordres
---------------------------------------------------------------------------------------------------
local function request(u, g)
  local s = Armee.S()
  local paths = paths_table()
  if not (s and paths) then return false end
  local box = Ro.GIANT_PATH_BOX
  local id = u.surface.request_path({
    bounding_box = { { -box, -box }, { box, box } }, collision_mask = { "water-tile" }, start = u.position, goal = { x = g.x, y = g.y },
    force = u.force, radius = 3, pathfind_flags = { cache = false, low_priority = true }, can_open_gates = false, entity_to_ignore = u,
  })
  g.req = id
  g.tries = (g.tries or 0) + 1
  paths[id] = u.unit_number
  return true
end

--- Ordre à un géant : `kind` « move » ou « attack », vers `pos`. Rend vrai si la demande de chemin est partie.
function Geant.go(u, kind, pos, radius)
  local giants = giants_table()
  if not (giants and u and u.valid and u.unit_number) then return false end
  local g = { x = pos.x, y = pos.y, kind = kind, radius = radius or 0, tries = 0, arrived = false }
  giants[u.unit_number] = g
  u.autopilot_destination = nil
  local ok = request(u, g)
  log(string.format("[FO-ROBOTS] geant %d ordre %s vers (%.1f, %.1f)", u.unit_number, kind, pos.x, pos.y))
  return ok
end

--- Pousse dans l'autopilote un point sur GIANT_PATH_STEP du chemin, puis le but.
local function push(u, g, path)
  u.autopilot_destination = nil
  if path then
    for i = Ro.GIANT_PATH_STEP, #path - 1, Ro.GIANT_PATH_STEP do u.add_autopilot_destination(path[i].position) end
  end
  u.add_autopilot_destination({ x = g.x, y = g.y })
end

Events.on(defines.events.on_script_path_request_finished, function(e)
  local paths = Armee.S() and paths_table()
  local un = paths and paths[e.id]
  if not un then return end
  paths[e.id] = nil
  local giants = giants_table()
  local g = giants and giants[un]
  local u = Armee.entity(un)
  if not (g and u and u.valid) then return end -- F216 : le géant est mort pendant que le chemin se calculait
  g.req = nil
  if e.try_again_later and (g.tries or 0) < MAX_TRIES then
    request(u, g)
    return
  end
  push(u, g, e.path) -- sans chemin (impasse ou trop d'essais) : la ligne droite, comme l'araignée du jeu de base
  if not e.path then log(string.format("[FO-ROBOTS] geant %d : pas de chemin, ligne droite", un)) end
end)

---------------------------------------------------------------------------------------------------
-- Balayage : munition, arrivée, reprise
---------------------------------------------------------------------------------------------------
function Geant.sweep()
  local s = Armee.S()
  if not s or not Armee.enabled() then return 0 end
  local giants = giants_table()
  local n = 0
  for _, r in ipairs(GIANTS) do
    for _, un in ipairs(Mo.units_with(s.ledger, r.id)) do
      local u = Armee.entity(un)
      if u then
        n = n + 1
        Geant.top_up(u)
        local g = giants and giants[un]
        if g and not g.arrived and not g.req then
          if dist(u.position, g) <= Ro.GIANT_HOLD then
            g.arrived = true
          elseif u.autopilot_destination == nil then
            if (g.tries or 0) < MAX_TRIES then request(u, g) else push(u, g, nil) g.tries = 0 end
          end
        end
      end
    end
  end
  if giants then
    local gone = {}
    for un in next, giants do
      if not Armee.entity(un) then gone[#gone + 1] = un end
    end
    table.sort(gone)
    for _, un in ipairs(gone) do giants[un] = nil end
  end
  return n
end

Events.on_nth_tick(PERIOD, function() Geant.sweep() end)

---------------------------------------------------------------------------------------------------
-- Règle d'échelle (lot EXPERIMENTAUX-PUISSANCE ; réponses du DC du 5/11, appliquée aux géants de robotsjeu avec l'accord du lead) :
-- en plus du canon (qui ne vise que le militaire), toutes les r.zone_cooldown ticks au plus, une SALVE DE ZONE au point visé : cible
-- militaire la plus proche à portée, sinon toute entité ennemie à portée (« jusqu'à la fin ») ; coup plein (Ech.salve de l'âge) sur
-- chaque ennemi dans 15 × (âge − 9) tuiles, cratère et sol brûlé (script/robots/experimentaux_geants.lua). État : s.salves[un] = tick
-- de la prochaine salve, refait à chaque balayage pour les seuls géants vivants (aucune itération par `pairs`).
---------------------------------------------------------------------------------------------------
local SALVE_SCAN = 30

function Geant.salves(tick)
  local s = Armee.S()
  if not s or not Armee.enabled() then return 0 end
  local old = Armee.table_of("salves")
  local nxt, n = {}, 0
  for _, r in ipairs(GIANTS) do
    for _, un in ipairs(Mo.units_with(s.ledger, r.id)) do
      local u = Armee.entity(un)
      if u then
        local at = old[un] or 0
        if tick >= at then
          local t = XpG.cible(u, r)
          if t then
            XpG.salve(u, un, r, { x = t.position.x, y = t.position.y }, tick)
            at = tick + r.zone_cooldown
            n = n + 1
          end
        end
        nxt[un] = at
      end
    end
  end
  s.salves = nxt
  return n
end

Events.on_nth_tick(SALVE_SCAN, function(ev) Geant.salves(ev.tick) end)

Armee.hooks.giant_go = Geant.go
Armee.hooks.giant_setup = Geant.setup

-- Interface distante « fo-robots-geant » (bancs) : état d'un géant inscrit.
remote.add_interface("fo-robots-geant", {
  info = function(unit_number)
    local u = Armee.entity(unit_number)
    if not u then return nil end
    local giants = giants_table()
    local g = giants and giants[unit_number]
    local inv = u.get_inventory(defines.inventory.spider_ammo)
    local _, id = Ro.parse_unit(u.name)
    return {
      name = u.name, x = u.position.x, y = u.position.y, health = u.health,
      autopilot = #u.autopilot_destinations, arrived = g and g.arrived or false, goal = g and { x = g.x, y = g.y } or nil,
      kind = g and g.kind or nil, tries = g and g.tries or 0, req = g and g.req or nil,
      shells = (inv and id) and inv.get_item_count(Ro.shell_name(id)) or 0,
    }
  end,
  sweep = function() return Geant.sweep() end,
})

return Geant
