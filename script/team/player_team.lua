--[[
  Équipe du JOUEUR : les compagnons travaillent pour le joueur avec le même cerveau d'équipe que les
  factions IA (shared/team/planner.lua, échelle T.player_ladder : charbon, fer, cuivre, pierre, munitions,
  expansion, fonderie, avant-postes défendus).

  Le joueur pose un COFFRE D'ÉQUIPE (objet fo-team-chest) : c'est le stock de l'équipe. Les ouvriers ne
  consomment que ce qu'il contient ; ils y rapportent la production des avant-postes qu'ils construisent.
  Lot IA1-a : fo-npc-start PNJ (8) sont offerts à la pose du coffre ; ensuite, un ouvrier est recruté dès que
  son prix (pistolet + 10 chargeurs + (10 + effectif) plaques de fer) est dans le coffre, jusqu'à
  fo-player-team-npc-max (30 ; T.player_workers_max = 8 avant). Le cerveau fabrique ces équipements lui-même
  s'il a des plaques.

    /fo-team status    objectif, ce qui manque, stock, tâches
    /fo-team org       lot IA1-b : effectifs par pôle, une ligne par manager et par généraliste
    /fo-team vue       lot IA1-b : ouvre ou ferme la vue d'ensemble (interface v0, lecture)
    /fo-team orientation <equilibre|ressources|base|protection|expansion>   lot IA1-b : orientation de l'équipe
    /fo-team dismiss   renvoie tous les ouvriers (l'équipement des recrues PAYÉES revient au coffre ; pas celui des
                       PNJ offerts à la fondation ni de l'embauche de secours, lot IA1-a)
]]

local Events = require("script.core.events")
local Scheduler = require("script.core.scheduler")
local Storage = require("script.core.storage")
local T = require("shared.team.config")
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Sites = require("script.faction.sites")
local Registry = require("script.companion.registry")
local Team = require("script.team.team")
local Poles = require("script.team.poles")
local Sq = require("shared.team.survie_qg") -- lot S1 : sort du coffre détruit (reposé si des PNJ vivent)
local Depart = require("shared.team.depart") -- lot PARITE : coffre posé d'office et tourelles de QG, comme une faction
local DepartCoffre = require("shared.team.depart_coffre") -- lot DEFAUTS-DC : stock de départ du coffre posé d'office (données)
local Fondation = require("shared.team.fondation")
require("script.team.adopte") -- lot ADOPTE : machines posées à la main par le joueur, inscrites au registre de l'équipe

local PlayerTeam = {}

local CHEST = "fo-team-chest"
local THINK_LANE = "fo-pteam"
local PROSPECT_LANE = "fo-pteam-prospect"

local function get() return Storage.ns("pteam").team end

-- Lot JOURNAUX-DC (point 5 du rapport CINQ-POINTS : aucune ligne de votre équipe dans les deux parties du DC du 29/10, l'absence
-- d'équipe se DÉDUISAIT) : [FO-PTEAM] cree / renvoye / perdu, pour que la présence de votre équipe se lise au journal.
local function minutes_since(f, tick) return (tick - (f.started or tick)) / 3600 end

function PlayerTeam.get() return get() end

local function create(chest)
  local surface = chest.surface
  local f = {
    id = "player", key = "player", force = chest.force.name, is_player = true, personality = "builder",
    color = { r = 0.95, g = 0.85, b = 0.3 }, hq = chest, hq_pos = { x = chest.position.x, y = chest.position.y },
    tech = 0, upgrades = 0, started = game.tick, surface = surface.index,
    engineers = {}, engineers_count = 0, outposts = {}, outposts_count = 0, next_oid = 0,
    turrets = {}, soldiers = {}, soldiers_count = 0, garrison_count = 0, groups = {}, smelters = {},
    stats = { attacks = 0, outposts_built = 0, outposts_lost = 0, soldiers_lost = 0, kills = 0 },
  }
  Storage.ns("pteam").team = f
  Team.init(f, surface)
  -- Lot PARITE (retour du DC du 2/11, point 19) : l'équipe naît avec les tourelles de QG d'une faction, UNE fois par partie (un coffre
  -- perdu puis refabriqué ne les redonne pas ; une équipe déjà lancée à la montée de version ne les reçoit pas : voir plus bas).
  local ns = Storage.ns("pteam")
  local due = Depart.turrets_due({ grant = Fondation.grant(true, false).hq_turrets, offered = Depart.is_offered(ns.depart_offert) })
  local placed = due > 0 and Team.place_hq_turrets(f, surface, chest.position, due) or 0
  ns.depart_offert = true
  log(string.format("[FO-PTEAM] depart tick %d : %d tourelle(s) de QG offerte(s) sur %d voulue(s)%s", game.tick, placed, due,
    due == 0 and " (depart deja offert a cette partie)" or ""))
  f.chest_reg = script.register_on_entity_destroyed(chest)
  f.goal_label = rendering.draw_text({
    text = Team.goal_text(f), surface = surface, target = chest, target_offset = { 0, -1.6 },
    color = { r = 1, g = 1, b = 1 }, scale = 1.1, alignment = "center",
  })
  Scheduler.add(THINK_LANE, 1)
  Scheduler.add(PROSPECT_LANE, 1)
  game.print({ "fo-team.created" })
  log(string.format("[FO-PTEAM] cree tick %d : coffre d'equipe pose en (%d, %d), force %s, %d PNJ offerts, plafond %d",
    game.tick, math.floor(chest.position.x), math.floor(chest.position.y), f.force, f.engineers_count or 0, Team.npc_max(f)))
  return f
end

--- Lot PARITE : pose d'office le coffre d'équipe près du point de départ du joueur, comme une faction naît avec son QG. Appelé par les
--- chemins de lancement HUMAINS de la guerre (réglage de carte, commande, bouton : script/faction/war.lua), jamais par les bancs
--- (remote war_start), qui posent leur coffre eux-mêmes. Rend vrai si le coffre a été posé, sinon faux et le motif.
function PlayerTeam.found_default(surface, center)
  local ns = Storage.ns("pteam")
  local ok, why = Depart.chest_due({ human = true, team = get() ~= nil, offered = Depart.is_offered(ns.depart_offert) })
  if not ok then
    log(string.format("[FO-PTEAM] coffre d'office tick %d : non pose (%s)", game.tick, why))
    return false, why
  end
  -- Lot s41 spawn-joueur : le coffre d'office évite un gisement (Depart.CHEST_SPOTS, Depart.pick_chest) : sur le minerai, ni tourelle de QG
  -- ni coffre du stock ne se posait autour de lui. Sans ressource à la première place : (6, 6) comme avant ; à défaut l'ancienne recherche.
  local cands, R = {}, Depart.CHEST_CLEAR
  for i, o in ipairs(Depart.CHEST_SPOTS) do
    local p = surface.find_non_colliding_position(CHEST, { x = center.x + o[1], y = center.y + o[2] }, 4, 1)
    local ore = p and surface.count_entities_filtered({ area = { { p.x - R, p.y - R }, { p.x + R, p.y + R } }, type = "resource" }) or 0
    cands[i] = { pos = p, ore = ore }
    if p and ore == 0 then break end
  end
  local pick = Depart.pick_chest(cands)
  local near = { x = center.x + Depart.CHEST_OFFSET[1], y = center.y + Depart.CHEST_OFFSET[2] }
  local pos = pick and cands[pick].pos or surface.find_non_colliding_position(CHEST, near, 20, 1)
  if pick and pick > 1 then
    log(string.format("[FO-PTEAM] coffre d'office tick %d : depart sur un gisement (%d ressource(s) autour de la place 1), place %d retenue (%d ressource(s))",
      game.tick, cands[1].ore or 0, pick, cands[pick].ore))
  end
  local chest = pos and surface.create_entity({ name = CHEST, position = pos, force = "player", raise_built = true })
  if not (chest and chest.valid and get()) then
    log(string.format("[FO-PTEAM] coffre d'office tick %d : non pose (aucune place a 20 tuiles du depart)", game.tick))
    return false, "pas-de-place"
  end
  -- Lot DEFAUTS-DC : le coffre posé d'office est GARNI du stock de départ du guide, une fois par partie (ns.depart_garni) ; un coffre fondé
  -- par le joueur ne passe jamais ici. Les PNJ offerts sont déjà fondés (raise_built synchrone, F40) : le stock sert à la suite.
  local due, wy = DepartCoffre.stock_due({ founded_by_default = true, garni = ns.depart_garni == true })
  if due then
    ns.depart_garni = true
    local parts = {}
    for _, it in ipairs(DepartCoffre.items()) do
      local put = chest.insert({ name = it[1], count = it[2] })
      parts[#parts + 1] = it[1] .. "=" .. put .. (put < it[2] and ("/" .. it[2]) or "")
    end
    log(string.format("[FO-PTEAM] coffre d'office garni tick %d : %s", game.tick, table.concat(parts, " ")))
  else
    log(string.format("[FO-PTEAM] coffre d'office tick %d : non garni (%s)", game.tick, wy))
  end
  game.print({ "fo-parite.office" })
  return true, why
end

local function dismiss(f, refund)
  -- refund = vrai : renvoi demandé (commande ou bouton de la fenêtre) ; faux : coffre perdu (journal « perdu » plus bas).
  if refund then
    log(string.format("[FO-PTEAM] renvoye tick %d : %d PNJ renvoyes a %.1f min (le coffre reste, l'equipe peut recruter de nouveau)",
      game.tick, f.engineers_count or 0, minutes_since(f, game.tick)))
  end
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    -- Lot IA1-a : un kit OFFERT (PNJ de départ, embauche de secours sans arme) n'est jamais rendu.
    if refund and f.hq and f.hq.valid and not (a and a.free_kit) then
      for _, it in ipairs(T.kits.worker) do Stock.insert(f, it[1], it[2]) end
    end
    Registry.remove(id, true)
  end
end
-- Lot IA1-i : exposé tel quel pour le bouton « Renvoyer l'équipe » de l'interface (même fonction que /fo-team dismiss).
PlayerTeam.dismiss = dismiss

--- Lot DEPENSES2 (b, relecture point 1) : quand votre équipe PREND FIN (coffre perdu), ses soldats (unités fo-player-*, payées par son stock
--- qui dort) partent avec elle, comme ses PNJ (dismiss : Registry.remove) : propriété rendue (State.disown, aucun événement de perte vers
--- une équipe suivante), entité retirée, comptes à zéro. Sans cela ils restaient des unités de votre force sans suivi, qu'une nouvelle
--- équipe ne comptait pas. Le renvoi (dismiss(f, true)) garde l'équipe : ses soldats restent suivis. Rend le nombre de soldats retirés.
local function release_soldiers(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.soldiers or {})) do
    local s = f.soldiers[id]
    State.disown(id)
    if s and s.entity and s.entity.valid then
      s.entity.destroy()
      n = n + 1
    end
    f.soldiers[id] = nil
  end
  f.soldiers_count, f.garrison_count = 0, 0
  return n
end
PlayerTeam.release_soldiers = release_soldiers

local function on_built(e)
  local ent = e.created_entity or e.entity
  if not (ent and ent.valid and ent.name == CHEST) then return end
  local f = get()
  if f and f.hq and f.hq.valid then
    local player = e.player_index and game.get_player(e.player_index)
    if player then player.print({ "fo-team.only-one" }) end
    return
  end
  create(ent)
end

-- Lot PARITE : une équipe DÉJÀ lancée à la montée de version ne reçoit rien d'office (ni tourelles, ni coffre si elle perd le sien) ;
-- une partie sans équipe garde le départ à offrir.
Events.on_configuration_changed(function()
  local ns = Storage.ns("pteam")
  if not ns then return end
  local before = ns.depart_offert
  ns.depart_offert = Depart.migrate_offered({ team = ns.team ~= nil, offered = ns.depart_offert })
  log(string.format("[FO-PTEAM] montee de version : depart offert %s -> %s (equipe %s)", tostring(before), tostring(ns.depart_offert),
    ns.team ~= nil and "lancee" or "absente"))
end)

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.script_raised_built, on_built)

-- Lot JOURNAUX-DC : qui détruit le coffre d'équipe (l'entité est encore valide ici ; la perte vient par on_entity_destroyed).
-- Lot MORTS : le type du coffre (nom CHEST, lu aux prototypes), jamais la force « enemy » (le coffre est à la force de l'équipe).
Events.on_died(function(e)
  local ent = e.entity
  if not (ent and ent.valid and ent.name == CHEST) then return end
  local f = get()
  if not (f and f.hq and f.hq.valid and f.hq.unit_number == ent.unit_number) then return end
  f.lost_by = (e.force and e.force.name or "?") .. "/" .. (e.cause and e.cause.valid and e.cause.name or "?")
end, { noms = { CHEST }, ennemi = false })

--- Lot S1 : coffre détruit par l'ennemi alors que des PNJ vivent : un coffre neuf à la même place (ou à côté), l'équipe continue. Le contenu du
--- coffre est perdu (les coffres annexes restent). Rend vrai si l'équipe continue.
local function repose(f, tick)
  local surface = game.surfaces[f.surface]
  if not (surface and surface.valid) then return false end
  local pos = surface.find_non_colliding_position(CHEST, f.hq_pos, 6, 1) or f.hq_pos
  local chest = surface.create_entity({ name = CHEST, position = pos, force = f.force, raise_built = false })
  if not (chest and chest.valid) then return false end
  f.hq, f.hq_pos = chest, { x = chest.position.x, y = chest.position.y }
  f.chest_reg = script.register_on_entity_destroyed(chest)
  f.lost_by = nil
  if f.goal_label and rendering.is_valid(f.goal_label) then rendering.destroy(f.goal_label) end
  f.goal_label = rendering.draw_text({
    text = Team.goal_text(f), surface = surface, target = chest, target_offset = { 0, -1.6 },
    color = { r = 1, g = 1, b = 1 }, scale = 1.1, alignment = "center",
  })
  return true
end

Events.on(defines.events.on_entity_destroyed, function(e)
  local f = get()
  if not f or e.registration_number ~= f.chest_reg then return end
  -- Lot S1 (« la perte d'un coffre ne met plus fin à votre équipe ») : détruit par l'ennemi avec des PNJ vivants, il est reposé.
  local lost = f.chest_lost or {}
  f.chest_lost = lost
  while #lost > 0 and e.tick - lost[1] > Sq.CHEST_WINDOW do table.remove(lost, 1) end
  local fate, why = Sq.chest_fate({ killed = f.lost_by ~= nil, workers = f.engineers_count or 0, soldiers = f.soldiers_count or 0, recent = #lost })
  if fate == "poser" then
    local by = f.lost_by
    lost[#lost + 1] = e.tick
    if repose(f, e.tick) then
      log(string.format("[FO-SURVIE] player : coffre d'equipe detruit par %s a %.1f min, REPOSE en (%d, %d) (%s : %d PNJ, %d soldats ; repose n %d en 30 min) ; contenu perdu, coffres annexes gardes",
        tostring(by), e.tick / 3600, math.floor(f.hq_pos.x), math.floor(f.hq_pos.y), why, f.engineers_count or 0, f.soldiers_count or 0, #lost))
      game.print({ "fo-team.chest-replaced" })
      return
    end
    why = "aucune place pour le coffre neuf"
  end
  log(string.format("[FO-SURVIE] player : coffre d'equipe perdu a %.1f min, l'equipe prend fin (%s)", e.tick / 3600, why))
  log(string.format("[FO-PTEAM] perdu tick %d : coffre d'equipe %s, %d PNJ partis, %d soldats, equipe fondee il y a %.1f min",
    e.tick, f.lost_by and ("detruit par " .. f.lost_by) or "retire (mine, deconstruit ou script)", f.engineers_count or 0,
    f.soldiers_count or 0, minutes_since(f, e.tick)))
  dismiss(f, false)
  local gone = PlayerTeam.release_soldiers(f) -- (par la table : le banc hors jeu en fait un mutant)
  if gone > 0 then log(string.format("[FO-PTEAM] perdu tick %d : %d soldat(s) de votre equipe retire(s) avec elle", e.tick, gone)) end
  if f.goal_label and rendering.is_valid(f.goal_label) then rendering.destroy(f.goal_label) end
  Storage.ns("pteam").team = nil
  Scheduler.remove(THINK_LANE, 1)
  Scheduler.remove(PROSPECT_LANE, 1)
  game.print({ "fo-team.lost" })
end)

-- Lot PERF3 (accord du lead, 5/11) : votre équipe pensait au MÊME tick que la première faction (créneau 1 des deux voies de période
-- 300, tick % 300 = 0) : 504 ticks de 50 à 200 ms à cette phase sur la partie du DC (fo-logs/2026-11-05_PERF3/BASE.md). Phase 174 :
-- la plus calme mesurée (0,047 ms en moyenne, p99 0,08), loin des 4 pensées de faction (0 à 3) et des passes du plan directeur qui les
-- suivent (5 à 75), hors des multiples de 5 (build:pulse), de 15 (regards d'IA3-f) et des restes 0 à 3 de 30 (prospection).
local THINK_PHASE = 174
Scheduler.define_lane(THINK_LANE, 300, function(_, tick)
  local f = get()
  if not (f and f.hq and f.hq.valid) then return end
  Team.think(f, f.hq.surface, tick)
end, THINK_PHASE)

Scheduler.define_lane(PROSPECT_LANE, 30, function(_, tick)
  local f = get()
  if not (f and f.hq and f.hq.valid) then return end
  Sites.prospect(f, f.hq.surface, tick)
end)

Events.on_nth_tick(600, function()
  local f = get()
  if f and f.goal_label and rendering.is_valid(f.goal_label) then rendering.set_text(f.goal_label, Team.goal_text(f)) end
end)

commands.add_command("fo-team", { "fo-team.command-help" }, function(cmd)
  local player = cmd.player_index and game.get_player(cmd.player_index)
  local f = get()
  local sub = (cmd.parameter or "status"):match("^%s*(%S*)")
  if not f then
    if player then player.print({ "fo-team.none" }) end
    return
  end
  if sub == "dismiss" then
    dismiss(f, true)
    if player then player.print({ "fo-team.dismissed" }) end
    return
  end
  -- Lot IA1-b : vue d'ensemble de l'organisation (interface v0, lecture) et orientation.
  if sub == "org" then
    for _, l in ipairs(Poles.lines(f)) do
      if player then player.print(l) end
    end
    return
  end
  if sub == "vue" then
    if player then Poles.toggle_view(player, f) end
    return
  end
  if sub == "orientation" then
    local name = (cmd.parameter or ""):match("^%s*%S+%s+(%S+)")
    local pts = name and Poles.set_orientation(f, name)
    if player then
      if pts then
        player.print({ "fo-ia1b.orientation-set", pts[1], pts[2], pts[3] })
      else
        player.print({ "fo-ia1b.orientation-help" })
      end
    end
    return
  end
  local line = Team.status_line(f)
  if player then
    player.print(Team.goal_text(f))
    player.print(line)
  end
  log(line)
end)

return PlayerTeam
