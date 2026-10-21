--[[
  Visuel des niveaux : FOUR EN ACIER (niveaux 2 à 30 ; le niveau 1 est le four vanilla).
  Propriétaire : lot V3-f. Interface : en tête de prototypes/levels/common.lua.

  État : PROVISOIRE (lot V2) : visuel commun de la session 5 (teinte d'époque, socle, reflet, halo, échelle
  plafonnée à +10 %). Ce schéma a été REJETÉ sur le design (E25) : aucun progrès visuel revendiqué. Défaut
  connu (F42) : le socle est invisible sous le four, dont le sprite couvre toute l'emprise ; il faut des
  pièces qui DÉPASSENT la silhouette.
  À faire (V3) : une silhouette par époque (ctx.step == 1), une pièce de plus au 2e niveau (ctx.step == 2).
]]

local M = {}

function M.dress(p, ctx)
  ctx.kit.provisional(p, ctx)
end

return M
