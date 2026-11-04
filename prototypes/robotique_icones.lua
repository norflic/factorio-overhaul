--[[
  Lot DA-ICONES (03/11) : les icônes DÉDIÉES de la robotique, suite du lot ICONES-CALCUL (prototypes/calcul_icones.lua) :
  7 pièces de robots, 2 circuits, 3 siliciums, 3 bobinages, les kits des 12 robots, les 3 segments des géants (objets : 64 px
  + 3 mipmaps) et 15 technologies (256 px + 3 mipmaps), à la place des objets vanilla teintés. Rendus 3D (Blender) réduits par
  tools/render/pieces/robotique/icones.py, qui génère aussi graphics/robotique/icones/icones.lua et MANIFEST.json (ne pas les
  éditer à la main).
  Lu par prototypes/robot_parts.lua, tin.lua, crafts.lua, superconductors.lua et robots.lua ; un nom absent de la table garde
  l'icône provisoire (copie vanilla teintée) de l'appelant.
]]

local ICO = require("__factorio-overhaul__/graphics/robotique/icones/icones")

local M = {}

local function une(i)
  return { { icon = i.icon, icon_size = i.icon_size, icon_mipmaps = i.icon_mipmaps } }
end

--- Icônes d'un objet ; nil s'il n'est pas dessiné.
function M.icones_objet(name)
  local i = ICO.item[name]
  return i and une(i) or nil
end

--- Icônes d'une technologie ; nil si elle n'est pas dessinée.
function M.icones_tech(name)
  local i = ICO.tech[name]
  return i and une(i) or nil
end

return M
