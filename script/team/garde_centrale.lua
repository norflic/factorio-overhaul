--[[
  Lot CENTRALE-GARDE, côté RUNTIME : la centrale FINIE d'une équipe est un poste à défendre (shared/team/garde_centrale.lua pour la
  règle). Deux services :
    - GC.view(f, fortify_open) : la vue de la centrale pour le planificateur permanent (pièces, chaudières, tourelles de l'équipe avec
      leurs munitions, portée lue au prototype de la tourelle) ; nil sans centrale finie ;
    - GC.place(f, surface, task, carrier) : pose, depuis l'inventaire du PNJ, les tourelles de la tâche « fortify » du poste « plant » aux
      emplacements de la règle, uniquement là où toutes les pièces sont à portée ; le coût vient du stock (tâche à objets stricts).
  Les tourelles posées appartiennent au poste « plant » (State.own, groupe de ravitaillement « oplant » de Outposts.turret_groups).
]]
local T = require("shared.team.config")
local M = require("shared.team.modules")
local D = require("shared.team.automatisation_donnees")
local Guard = require("shared.team.garde_centrale")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")

local GC = {}

local function range_of_turret()
  local proto = game.entity_prototypes[T.turret]
  local ap = proto and proto.attack_parameters
  return ap and ap.range or nil
end

--- Pièces VIVANTES (chaudières, machines à vapeur, pompes) de LA centrale de l'équipe (b.plant, finie) et nombre de chaudières vivantes ;
--- nil sans centrale finie ou sans chaudière vivante (centrale détruite : on ne remplace pas des tourelles autour des ruines). Une seule
--- centrale lue : deux projets éloignés ne donneraient aucun emplacement qui couvre tout (correctif du 2e relecteur).
local function pieces_of(f, surface)
  local b = f.build
  local p = b and b.plant and b.projects[b.plant]
  if not (p and p.state == "fini" and p.spec and p.spec.gen == D.PLANT.gen) then return nil end
  local pieces, boilers = {}, 0
  for _, e in ipairs(p.ents) do
    local sp = M.spec(e.name) or {}
    if sp.water or sp.power_out or sp.kind == "offshore" then
      local real = surface.find_entity(e.name, { e.x, e.y })
      if real and real.valid and real.force.name == f.force then
        pieces[#pieces + 1] = { x = e.x, y = e.y }
        if sp.water then boilers = boilers + 1 end
      end
    end
  end
  if #pieces == 0 or boilers == 0 then return nil end
  return pieces, boilers
end

local function turrets_of(f)
  local turrets = {}
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      local inv = t.get_inventory(defines.inventory.turret_ammo)
      turrets[#turrets + 1] = { x = t.position.x, y = t.position.y, rounds = inv and inv.get_item_count() or 0 }
    end
  end
  return turrets
end

-- Journal [FO-CENTRALE-GARDE] (lecture seule : l'état ne sert qu'à ne pas répéter une ligne) : la centrale vue finie, un état toutes les
-- 3 minutes (tourelles armées à portée, tâche ouverte, fer au stock), chaque pose (cumul, délai depuis la centrale finie).
local STATUS_EVERY = 3 * 3600

--- Pause de la garde après la mort d'un porteur en route (comme un avant-poste MEURTRIER : T.lethal_ticks) ; journalise le trajet perdu.
function GC.on_lost(f, agent_id, cause)
  local b = f.build
  if not b then return end
  b.garde = b.garde or { poses = 0 }
  local tick = game.tick
  b.garde.pause_until = tick + T.lethal_ticks
  b.garde.lost = (b.garde.lost or 0) + 1
  log(string.format("[FO-CENTRALE-GARDE] %s : PNJ %s tue en allant poser les tourelles de la centrale (%s) a %.1f min ; garde en pause jusqu'a %.1f min (trajets perdus : %d)",
    f.key or "player", tostring(agent_id), tostring(cause), tick / 3600, b.garde.pause_until / 3600, b.garde.lost))
end

function GC.view(f, fortify_open, iron)
  local surface = f.hq and f.hq.valid and f.hq.surface or nil
  if not surface then return nil end
  local pieces, boilers = pieces_of(f, surface)
  if not pieces then return nil end
  local range = range_of_turret()
  if not range then return nil end
  local turrets = turrets_of(f)
  local b = f.build
  b.garde = b.garde or { poses = 0 }
  local g, tick = b.garde, game.tick
  local view = { pieces = pieces, boilers = boilers, turrets = turrets, range = range, low = T.turret_ammo_low,
    fortify = fortify_open and fortify_open["plant"] or false, pause = (g.pause_until or 0) > tick }
  local have = Guard.guards(pieces, turrets, range, T.turret_ammo_low)
  local want = Guard.wanted(boilers)
  if not g.fini then
    g.fini = tick
    log(string.format("[FO-CENTRALE-GARDE] %s : centrale finie a %.1f min (%d pieces, %d chaudiere(s)) ; gardes voulues %d, armees a portee %d ; fer au stock %s (plancher %d)",
      f.key or "player", tick / 3600, #pieces, boilers, want, have, tostring(iron or "?"), T.defend_iron_floor))
  end
  if tick - (g.status or g.fini) >= STATUS_EVERY then
    g.status = tick
    log(string.format("[FO-CENTRALE-GARDE] %s : etat a %.1f min : armees a portee %d sur %d, tache ouverte %s, tourelles de l'equipe %d, fer au stock %s (plancher %d), %d pose(s)",
      f.key or "player", tick / 3600, have, want, tostring(view.fortify), #turrets, tostring(iron or "?"), T.defend_iron_floor, g.poses))
  end
  return view
end

function GC.place(f, surface, task, carrier)
  local pieces, range = task.pieces, task.range
  local n = Outposts.fortify_at(f, surface, "plant", task.sites or {}, task.items[1][2], carrier,
    function(pos) return Guard.covers(pieces, pos.x, pos.y, range) end)
  local b = f.build
  if b then
    b.garde = b.garde or { poses = 0 }
    local g, tick = b.garde, game.tick
    g.poses = g.poses + n
    if n > 0 and not g.pose1 then g.pose1 = tick end
    local have = Guard.guards(pieces, turrets_of(f), range, T.turret_ammo_low)
    log(string.format("[FO-CENTRALE-GARDE] %s : pose de %d tourelle(s) sur %d demandee(s) a %.1f min (cumul %d), armees a portee %d, delai depuis la centrale finie %s%s",
      f.key or "player", n, task.items[1][2], tick / 3600, g.poses, have,
      g.fini and string.format("%.1f min", (tick - g.fini) / 3600) or "?", g.pose1 == tick and " (premiere pose)" or ""))
  end
  return n
end

return GC
