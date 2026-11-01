--[[
  Lot RB-1 CHAÎNE (31/10) : l'ARMÉE des robots, côté exécution. Règles pures : shared/robots/modele.lua ; données :
  shared/content/robots.lua.

  - Registre (« ledger ») des unités vivantes dans global.fo.robots : points utilisés et effectif par force et par robot, en
    nombres et chaînes ; les entités sont rangées à part (ents), lues par numéro d'unité.
  - Création : Armee.create pose l'unité d'un propriétaire (le joueur, ou une faction : prototype par propriétaire), l'inscrit
    et lui donne sa première commande. Pour une FACTION, un robot EST un soldat : Military.adopt le place dans f.soldiers
    (garnison, groupes, raids, retour et pertes de script/faction/military.lua servent sans copie) ; pour le joueur, le robot
    obéit à son joueur seul (jamais dans f.soldiers de l'équipe, sinon le cerveau de l'équipe le rappellerait).
  - Pertes : une unité morte, détruite ou retirée libère ses points (idempotent) ; un balayage de sécurité retire du registre ce
    que le moteur n'a plus.
  - Âge d'une force : sa faction (tech + 1) ou le niveau de son centre de commandement ; plafond en points :
    Mo.cap(âge, réglage fo-war-robots-cap).
  Déterminisme : le registre se parcourt en liste triée par numéro d'unité ; aucun pairs dans une décision ; aucune décision sur un
  temps mesuré. Journal : lignes « [FO-ROBOTS] » (kits payés contre unités arrivées : PLAN §7, risque 4).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local State = require("script.faction.state")
local Military = require("script.faction.military")
local Levels = require("script.levels.levels")
local Ro = require("shared.content.robots")
local Mo = require("shared.robots.modele")

local Armee = {}

--- Crochets posés par script/robots/geant.lua (lot RB-5) : l'ordre d'un géant (araignée) passe par un chemin demandé au moteur ;
--- armee.lua ne le requiert pas (geant.lua requiert armee.lua).
Armee.hooks = {}

Storage.declare("robots", function()
  return {
    ledger = Mo.new_ledger(),
    ents = {},      -- [numéro d'unité] = entité (le moteur 1.1 n'a pas de recherche par numéro) ; lu par numéro, jamais parcouru
    factories = {}, -- [numéro d'unité de l'atelier] = { e = atelier, rally = { x, y } ou nil, keep = { [robot] = n } ou nil }
    list = {},      -- numéros d'unité des ateliers, triés
    stats = { created = 0, lost = 0, kits_removed = 0, create_failed = 0, pruned = 0, orders = 0, ordered = 0 },
    sel = {},    -- lot RB-2 : [indice de joueur] = numéros d'unité choisis (triés)
    rally_for = {}, -- lot RB-2 : [indice de joueur] = numéro de l'atelier dont l'outil de ralliement attend un clic
    alerts = {}, -- lot RB-2 : [nom de force] = état des pertes (Cm.new_loss)
  }
end)

--- État du lot (nil avant la création de l'espace de stockage : sauvegarde d'avant le lot, avant on_configuration_changed).
function Armee.S() return Storage.ns("robots") end

function Armee.enabled()
  local s = settings.global[Ro.SETTING]
  return s ~= nil and s.value == true
end

local function cap_setting()
  local s = settings.global[Ro.SETTING_CAP]
  return s and s.value or 0
end

---------------------------------------------------------------------------------------------------
-- Âge, plafond, effectifs
---------------------------------------------------------------------------------------------------
--- Âge d'une force : (tech + 1) d'une faction, sinon le niveau de son centre de commandement (au moins 1).
function Armee.age(force)
  local f = State.by_force(force.name)
  if f then return (f.tech or 0) + 1 end
  return math.max(1, Levels.cc_level(force))
end

function Armee.cap(force) return Mo.cap(Armee.age(force), cap_setting()) end

--- Géants vivants d'une force (lot RB-5).
function Armee.giants(force_name)
  local s = Armee.S()
  return s and Mo.giants_of(s.ledger, force_name) or 0
end

--- Paramètres de Mo.can_release pour le robot `r` de `force` : `used` (points déjà pris, y compris les kits retirés pendant ce
--- balayage) et `giants_extra` (géants créés pendant ce balayage) sont facultatifs.
function Armee.release_params(force, r, keep, used, giants_extra)
  return {
    used = used or Armee.used(force.name), cap = Armee.cap(force), points = r.points, have = Armee.have(force.name, r.id), keep = keep,
    giant = r.is_giant, giants_have = Armee.giants(force.name) + (giants_extra or 0), giants_allowed = Mo.giants_allowed(Armee.age(force)),
  }
end

function Armee.used(force_name)
  local s = Armee.S()
  return s and Mo.used(s.ledger, force_name) or 0
end

function Armee.have(force_name, id)
  local s = Armee.S()
  return s and Mo.have(s.ledger, force_name, id) or 0
end

--- L'entité d'un robot inscrit (nil si inconnue ou invalide).
function Armee.entity(unit_number)
  local s = Armee.S()
  local e = s and s.ents[unit_number]
  if e and e.valid then return e end
  return nil
end

--- Parties de l'état ajoutées par le lot RB-2, créées à la demande (une sauvegarde d'avant le lot n'a pas ces tables ; jamais
--- créées pendant on_load : seuls les gestionnaires d'événements et le balayage les appellent).
function Armee.table_of(name)
  local s = Armee.S()
  if not s then return nil end
  if s[name] == nil then s[name] = {} end
  return s[name]
end

--- Le numéro d'unité est-il un robot inscrit ?
function Armee.registered(unit_number)
  local s = Armee.S()
  return s ~= nil and s.ledger.units[unit_number] ~= nil
end

---------------------------------------------------------------------------------------------------
-- Commandes (construction des commandes du moteur ; l'ordre en lui-même : script/robots/ordres.lua)
---------------------------------------------------------------------------------------------------
--- Donne un ordre à une unité : « move » (aller, puis rester sur place) ou « attack » (marche-attaque sur une zone, puis rester).
--- Distraction par l'ennemi : l'unité riposte en route, la commande reprend ensuite (F171). Rend vrai si l'ordre est donné.
function Armee.send(u, kind, pos, radius)
  if not (u and u.valid) then return false end
  if u.type == "spider-vehicle" then
    return Armee.hooks.giant_go ~= nil and Armee.hooks.giant_go(u, kind, pos, radius) or false
  end
  local stay = { type = defines.command.stop, distraction = defines.distraction.by_enemy }
  local first
  if kind == "move" then
    first = { type = defines.command.go_to_location, destination = { x = pos.x, y = pos.y }, radius = radius or 2,
      distraction = defines.distraction.by_enemy }
  elseif kind == "attack" then
    first = { type = defines.command.attack_area, destination = { x = pos.x, y = pos.y }, radius = radius or Ro.ATTACK_RADIUS,
      distraction = defines.distraction.by_enemy }
  else
    return false
  end
  u.set_command({ type = defines.command.compound, structure_type = defines.compound_command.return_last,
    commands = { first, stay } })
  return true
end

---------------------------------------------------------------------------------------------------
-- Création et pertes
---------------------------------------------------------------------------------------------------
local function owner_key(force)
  local f = State.by_force(force.name)
  return f and f.key or Ro.PLAYER_OWNER, f
end

--- Pose l'unité du robot `id` pour `force`, près de `near`. Aucun contrôle de plafond ici (c'est le travail de l'appelant :
--- usine.lua, ou Armee.spawn). `rally` = point de ralliement du joueur (ignoré pour une faction : sa garnison est son QG).
--- `home` (lot RB-2) : numéro d'unité de l'atelier d'origine, gardé au registre (ralliement de l'unité). Rend l'unité, ou (nil, raison).
function Armee.create(surface, force, id, near, rally, home)
  local s = Armee.S()
  local r = Ro.robot(id)
  if not (s and r) then return nil, "robot inconnu ou état absent" end
  local owner, f = owner_key(force)
  local name = Ro.proto_name(owner, r)
  local pos = surface.find_non_colliding_position(name, near, r.is_giant and 24 or 8, r.is_giant and 1 or 0.5)
  if not pos then return nil, "pas de place" end
  local u = surface.create_entity({ name = name, position = pos, force = force })
  if not (u and u.valid and u.unit_number) then return nil, "création refusée" end
  Mo.add(s.ledger, force.name, u.unit_number, id, r.points, home)
  s.ents[u.unit_number] = u
  script.register_on_entity_destroyed(u)
  s.stats.created = s.stats.created + 1
  if r.is_giant then
    -- un géant (araignée) : couleur de la faction, munition, puis ralliement ; une faction ne l'adopte pas comme soldat (groupes d'unités)
    if Armee.hooks.giant_setup then Armee.hooks.giant_setup(u, f) end
    if rally and not f then Armee.send(u, "move", rally, 2) end
  elseif f then
    Military.adopt(f, u)
  elseif rally then
    Armee.send(u, "move", rally, 2)
  end
  log(string.format("[FO-ROBOTS] unite %d %s force=%s points=%d/%d", u.unit_number, id, force.name,
    Mo.used(s.ledger, force.name), Armee.cap(force)))
  return u
end

--- Pose un robot en respectant le plafond (assistant des bancs et de l'interface distante). Rend l'unité, ou (nil, raison).
function Armee.spawn(surface, force, id, near, rally)
  local r = Ro.robot(id)
  if not r then return nil, "robot inconnu" end
  if not Mo.can_release(Armee.release_params(force, r)) then return nil, "plafond" end
  return Armee.create(surface, force, id, near, rally)
end

--- Une unité n'existe plus : ses points sont libérés (idempotent). Rend vrai si elle était inscrite.
function Armee.release(unit_number, why)
  local s = Armee.S()
  if not s then return false end
  local force, id = Mo.remove(s.ledger, unit_number)
  s.ents[unit_number] = nil
  if not force then return false end
  s.stats.lost = s.stats.lost + 1
  log(string.format("[FO-ROBOTS] perte %d %s force=%s (%s) points=%d", unit_number, id, force, why or "?",
    Mo.used(s.ledger, force)))
  return true
end

--- Balayage de sécurité : retire du registre les unités que le moteur n'a plus (retirées sans événement). Rend leur nombre.
function Armee.prune()
  local s = Armee.S()
  if not s then return 0 end
  local gone = Mo.prune(s.ledger, function(un)
    local e = s.ents[un]
    return e ~= nil and e.valid
  end)
  s.stats.pruned = s.stats.pruned + #gone
  s.stats.lost = s.stats.lost + #gone
  for _, un in ipairs(gone) do
    s.ents[un] = nil
    log(string.format("[FO-ROBOTS] perte %d (balayage)", un))
  end
  return #gone
end

--- Lot RB-3 : un kit posé À LA MAIN (son prototype pose l'unité du joueur) : l'unité est inscrite au registre si le plafond le permet,
--- sinon elle est retirée et le kit rendu. Rend vrai si l'unité est gardée.
function Armee.register_placed(u, player)
  local s = Armee.S()
  local owner, id = Ro.parse_unit(u.name)
  local r = id and Ro.robot(id)
  if not (s and r and u.unit_number) or Armee.registered(u.unit_number) then return false end
  local force = u.force
  if owner ~= Ro.PLAYER_OWNER or State.by_force(force.name) or not Armee.enabled() or not Mo.can_release(Armee.release_params(force, r)) then
    u.destroy()
    if player and player.valid then
      player.insert({ name = r.kit, count = 1 })
      player.print({ "fo-robots.placed-refused", { "fo-robots.name-" .. id } })
    end
    log(string.format("[FO-ROBOTS] kit pose a la main refuse (plafond ou reglage) : %s force=%s", id, force.name))
    return false
  end
  Mo.add(s.ledger, force.name, u.unit_number, id, r.points)
  s.ents[u.unit_number] = u
  script.register_on_entity_destroyed(u)
  s.stats.created = s.stats.created + 1
  s.stats.placed = (s.stats.placed or 0) + 1
  if r.is_giant and Armee.hooks.giant_setup then Armee.hooks.giant_setup(u, nil) end
  log(string.format("[FO-ROBOTS] unite %d %s force=%s points=%d/%d (kit pose a la main)", u.unit_number, id, force.name,
    Mo.used(s.ledger, force.name), Armee.cap(force)))
  return true
end

local function on_placed(e)
  local u = e.created_entity or e.entity
  if not (u and u.valid and (u.type == "unit" or u.type == "spider-vehicle") and Ro.parse_unit(u.name)) then return end
  Armee.register_placed(u, e.player_index and game.get_player(e.player_index))
end
Events.on(defines.events.on_built_entity, on_placed)
Events.on(defines.events.on_robot_built_entity, on_placed)

Events.on(defines.events.on_entity_died, function(e)
  local u = e.entity
  if u and u.valid and (u.type == "unit" or u.type == "spider-vehicle") and Ro.parse_unit(u.name) then Armee.release(u.unit_number, "mort") end
end)

Events.on(defines.events.on_entity_destroyed, function(e)
  if e.unit_number then Armee.release(e.unit_number, "detruite") end
end)

return Armee
