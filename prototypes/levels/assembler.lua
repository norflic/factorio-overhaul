--[[
  Visuel des niveaux : MACHINE D'ASSEMBLAGE 2 (niveaux 2 à 30 ; le niveau 1 est la machine vanilla).
  Propriétaire : lot V3-g. Interface : en tête de prototypes/levels/common.lua.

  État : PROVISOIRE (lot V2) : visuel commun de la session 5 (teinte d'époque, socle, reflet, halo, échelle
  plafonnée à +10 %). Ce schéma a été REJETÉ sur le design (E25) : aucun progrès visuel revendiqué.
  À faire (V3) : une silhouette par époque (ctx.step == 1), une pièce de plus au 2e niveau (ctx.step == 2).
]]

local M = {}

function M.dress(p, ctx)
  ctx.kit.provisional(p, ctx)
end

return M
