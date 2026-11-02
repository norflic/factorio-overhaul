--[[
  Lot OBSTACLES : lecture au moteur de l'emprise RÉELLE des falaises (règle pure : shared/team/falaise.lua, qui dit pourquoi
  `bounding_box` ne suffit pas). Deux appelants : les masques du plan directeur (script/team/build.lua, read_masks) et ceux du
  champ de l'avant-poste (script/team/champ.lua, blocked_in). Aucun état, aucun `global`.
]]
local Fal = require("shared.team.falaise")

local M = {}

--- Tuiles de l'emprise réelle d'une falaise (LuaEntity de type « cliff ») : liste plate { tx, ty, ... }.
function M.tiles(e)
  local scale = 1
  local pr = e.prototype
  local cb = pr and pr.collision_box
  if cb and cb.right_bottom and cb.right_bottom.x and cb.right_bottom.x > 0 then scale = cb.right_bottom.x end
  local pos = e.position
  return Fal.tiles(pos.x, pos.y, e.cliff_orientation, scale)
end

--- Appelle put(tx, ty) pour chaque tuile de l'emprise réelle des falaises qui touchent le rectangle (x0, y0, x1, y1). La zone donnée
--- au moteur est élargie de Fal.REACH (une falaise dont la boîte générique est dehors peut avoir son emprise dedans). Rend le nombre
--- de falaises lues.
function M.mark(surface, x0, y0, x1, y1, put)
  local ax0, ay0, ax1, ay1 = Fal.search_area(x0, y0, x1, y1)
  local list = surface.find_entities_filtered({ area = { { ax0, ay0 }, { ax1, ay1 } }, type = "cliff" })
  for _, e in ipairs(list) do
    if e.valid then
      local t = M.tiles(e)
      for i = 1, #t - 1, 2 do put(t[i], t[i + 1]) end
    end
  end
  return #list
end

--- Appelle put(tx, ty) pour chaque tuile de la mémoire apprise `mem` (b.hard : { n, t = { [P.tkey] = true } }, voir Build) ; l'ordre de
--- parcours n'a aucun effet (ensemble).
function M.mark_learned(mem, put)
  if not (mem and mem.t) then return end
  for k in pairs(mem.t) do
    local tx, ty = Fal.untkey(k)
    put(tx, ty)
  end
end

return M
