--[[
  Lot ICONES-CALCUL (03/11) : les icônes DÉDIÉES de la chaîne du calcul (32 objets, baies et fluides, 7 technologies) à la place
  des objets vanilla teintés (« tous les circuits [...] ne sont que des teintes différentes des circuits électriques de base »,
  le DC, 3/11). Rendus 3D (Blender) réduits en lumière linéaire par tools/render/pieces/calcul/icones.py, qui génère aussi
  graphics/calcul/icones/icones.lua et MANIFEST.json (ne pas les éditer à la main) ; objets et fluides : 64 px + 3 mipmaps,
  technologies : 256 px + 3 mipmaps.
  Lu par prototypes/compute.lua et prototypes/compute_v2.lua à la création de chaque objet, fluide, baie et technologie ;
  un nom absent de la table garde l'icône provisoire (copie vanilla teintée) de l'appelant.
]]

local ICO = require("__factorio-overhaul__/graphics/calcul/icones/icones")

local M = {}

local function une(i)
  return { { icon = i.icon, icon_size = i.icon_size, icon_mipmaps = i.icon_mipmaps } }
end

--- Icônes d'un objet, d'un fluide ou d'une baie ; nil s'il n'est pas dessiné.
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
