--[[
  Lot ICONES-DISTINCTES (11/11, mandat du DC du 10/11 22 h 20) : les icônes DÉDIÉES de cinq métaux qui montraient tous une
  copie teintée de la plaque d'acier vanilla : tôle magnétique, billettes de fer, de cuivre et de tungstène, plaque de
  titane (objets : 64 px + 3 mipmaps). Rendus 3D (Blender) réduits par tools/render/pieces/metaux/icones.py, qui génère
  aussi graphics/metaux/icones/icones.lua et MANIFEST.json (ne pas les éditer à la main).
  Lu par prototypes/crafts.lua et titanium.lua ; un nom absent de la table garde l'icône provisoire de l'appelant.
]]

local ICO = require("__factorio-overhaul__/graphics/metaux/icones/icones")

local M = {}

--- Icônes d'un objet ; nil s'il n'est pas dessiné.
function M.icones_objet(name)
  local i = ICO.item[name]
  return i and { { icon = i.icon, icon_size = i.icon_size, icon_mipmaps = i.icon_mipmaps } } or nil
end

return M
