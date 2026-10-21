--[[
  Visuel des niveaux : MUR (niveaux 2 à 30 ; le niveau 1 est le mur de pierre vanilla).
  Propriétaire : lot V3-d. Interface : en tête de prototypes/levels/common.lua.

  État : PROVISOIRE (lot V2) : teinte d'époque, reflet et halo du visuel commun, SANS socle ni échelle (un
  mur se raccorde à ses voisins : un sprite agrandi ou un socle casserait les jonctions). Ce schéma a été
  REJETÉ sur le design (E25) : aucun progrès visuel revendiqué.
  À faire (V3) : une silhouette par époque (ctx.step == 1), une pièce de plus au 2e niveau (ctx.step == 2),
  en gardant les raccords (pictures.straight_*, corner_*, ending_*, t_up, filling).
]]

local M = {}

function M.dress(p, ctx)
  ctx.kit.provisional(p, ctx, { foundation = false, scale = false })
end

return M
