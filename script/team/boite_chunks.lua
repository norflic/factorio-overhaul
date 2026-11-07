--[[
  Lot POULS (7/11, fo-logs\2026-11-07_POULS\CRITERES.md) : BOÎTE des chunks générés de chaque surface (min et max des coordonnées de chunk
  en x et en y). Le relevé du réseau par bandes (script/team/reseau_vivant.lua) la parcourt ligne de chunks par ligne de chunks : toute
  entité est dans un chunk généré, donc dans la boîte. Requis par script/team/build.lua (qui la passe à Rv.step : api.box).

  Tenue par on_chunk_generated (4 comparaisons par chunk). Relevée EN ENTIER au chargement (on_init, on_configuration_changed : une partie
  d'avant ce lot, ou un mod changé ; revue de la 0.6.59, point 6), jamais pendant un tick de jeu. Un chunk supprimé ne la réduit qu'au
  chargement suivant (bandes vides en trop, sans effet sur le compte). État : global « boite_chunks » = { by = { [surface.index] =
  { x0, y0, x1, y1 } } }.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")

local Box = {}

Storage.declare("boite_chunks", function() return { by = {} } end)

local function S()
  local s = Storage.ns("boite_chunks")
  if s and not s.by then s.by = {} end
  return s
end

local function grow(b, x, y)
  if x < b.x0 then b.x0 = x end
  if x > b.x1 then b.x1 = x end
  if y < b.y0 then b.y0 = y end
  if y > b.y1 then b.y1 = y end
end

--- Les chunks générés de `surface`, un passage (surface.get_chunks).
local function scan(surface)
  local b
  for c in surface.get_chunks() do
    if b then grow(b, c.x, c.y) else b = { x0 = c.x, y0 = c.y, x1 = c.x, y1 = c.y } end
  end
  return b
end

--- Boîte { x0, y0, x1, y1 } (coordonnées de chunk, bornes comprises) des chunks générés de `surface`, ou nil s'il n'y en a aucun.
--- (Secours : une surface sans boîte est relevée ici ; depuis la revue de la 0.6.59, point 6, cela n'arrive plus en jeu : voir plus bas.)
function Box.get(surface)
  local s = S()
  if not (s and surface and surface.valid) then return nil end
  local b = s.by[surface.index]
  if b then return b end
  b = scan(surface)
  if b then s.by[surface.index] = b end
  return b
end

--- Revue de la 0.6.59, point 6 : le relevé entier se faisait au premier pouls d'une sauvegarde 0.6.58 (un passage sur TOUS les chunks, dans
--- un tick de jeu). Il se fait au chargement : on_init et on_configuration_changed relèvent toutes les surfaces (chaque boîte ne dépend que
--- de sa surface : l'ordre de parcours ne change rien). Ensuite on_chunk_generated tient la boîte, et la CRÉE pour une surface neuve
--- (aucun chunk avant le premier événement).
local function rebuild_all()
  local s = S()
  if not s then return end
  s.by = {}
  for _, surface in pairs(game.surfaces) do
    if surface.valid then
      local b = scan(surface)
      if b then s.by[surface.index] = b end
    end
  end
end
Events.on_init(rebuild_all)
Events.on_configuration_changed(rebuild_all)

Events.on(defines.events.on_chunk_generated, function(e)
  local s = S()
  local surface = e.surface
  if not (s and surface and surface.valid) then return end
  local b = s.by[surface.index]
  if b then grow(b, e.position.x, e.position.y) else s.by[surface.index] = { x0 = e.position.x, y0 = e.position.y, x1 = e.position.x, y1 = e.position.y } end
end)

return Box
