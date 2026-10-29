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

--- Pièces (chaudières, machines à vapeur, pompes) de la centrale finie de l'équipe et nombre de chaudières ; nil sans centrale finie.
local function pieces_of(f)
  local b = f.build
  if not b then return nil end
  local pieces, boilers = {}, 0
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.state == "fini" and p.spec and p.spec.gen == D.PLANT.gen then
      for _, e in ipairs(p.ents) do
        local sp = M.spec(e.name) or {}
        if sp.water or sp.power_out or sp.kind == "offshore" then
          pieces[#pieces + 1] = { x = e.x, y = e.y }
          if sp.water then boilers = boilers + 1 end
        end
      end
    end
  end
  if #pieces == 0 then return nil end
  return pieces, boilers
end

function GC.view(f, fortify_open)
  local pieces, boilers = pieces_of(f)
  if not pieces then return nil end
  local range = range_of_turret()
  if not range then return nil end
  local turrets = {}
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      local inv = t.get_inventory(defines.inventory.turret_ammo)
      turrets[#turrets + 1] = { x = t.position.x, y = t.position.y, rounds = inv and inv.get_item_count() or 0 }
    end
  end
  return { pieces = pieces, boilers = boilers, turrets = turrets, range = range, low = T.turret_ammo_low,
    fortify = fortify_open and fortify_open["plant"] or false }
end

function GC.place(f, surface, task, carrier)
  local pieces, range = task.pieces, task.range
  return Outposts.fortify_at(f, surface, "plant", task.sites or {}, task.items[1][2], carrier,
    function(pos) return Guard.covers(pieces, pos.x, pos.y, range) end)
end

return GC
