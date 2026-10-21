--[[
  Visuel des niveaux : FOREUSE ÉLECTRIQUE (niveaux 2 à 30 ; le niveau 1 est la foreuse vanilla).
  Propriétaire : lot V3-e. Interface : en tête de prototypes/levels/common.lua.

  État : PROVISOIRE (lot V2) : visuel commun de la session 5 (teinte d'époque, socle, reflet, halo, échelle
  plafonnée à +10 %). Ce schéma a été REJETÉ sur le design (E25) : aucun progrès visuel revendiqué.
  À faire (V3) : une silhouette par époque (ctx.step == 1), une pièce de plus au 2e niveau (ctx.step == 2),
  pour graphics_set ET wet_mining_graphics_set, dans les 4 orientations.
]]

local M = {}

function M.dress(p, ctx)
  ctx.kit.provisional(p, ctx)
end

return M
