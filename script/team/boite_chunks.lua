--[[
  Lot POULS (7/11, fo-logs\2026-11-07_POULS\CRITERES.md) : BOÎTE des chunks générés de chaque surface (min et max des coordonnées de chunk
  en x et en y). Le relevé du réseau par bandes (script/team/reseau_vivant.lua) la parcourt ligne de chunks par ligne de chunks : toute
  entité est dans un chunk généré, donc dans la boîte. Requis par script/team/build.lua (qui la passe à Rv.step : api.box).

  Tenue par on_chunk_generated (4 comparaisons par chunk). Une partie qui n'a pas la boîte (d'avant ce lot) la relève EN ENTIER une fois,
  au premier besoin (surface.get_chunks : un passage sur les chunks, une seule fois par partie). Un chunk supprimé ne la réduit jamais
  (bandes vides en trop, sans effet sur le compte). État : global « boite_chunks » = { by = { [surface.index] = { x0, y0, x1, y1 } } }.
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

--- Boîte { x0, y0, x1, y1 } (coordonnées de chunk, bornes comprises) des chunks générés de `surface`, ou nil s'il n'y en a aucun.
function Box.get(surface)
  local s = S()
  if not (s and surface and surface.valid) then return nil end
  local b = s.by[surface.index]
  if b then return b end
  for c in surface.get_chunks() do
    if b then grow(b, c.x, c.y) else b = { x0 = c.x, y0 = c.y, x1 = c.x, y1 = c.y } end
  end
  if b then s.by[surface.index] = b end
  return b
end

Events.on(defines.events.on_chunk_generated, function(e)
  local s = S()
  local surface = e.surface
  if not (s and surface and surface.valid) then return end
  local b = s.by[surface.index]
  -- pas encore relevée : Box.get la relèvera en entier (le chunk neuf compris)
  if b then grow(b, e.position.x, e.position.y) end
end)

return Box
