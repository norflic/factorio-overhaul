--[[
  Visuel des niveaux : TOURELLE LASER (niveaux 2 à 30 ; le niveau 1 est la tourelle vanilla).
  Propriétaire : lot V3-c. Interface : en tête de prototypes/levels/common.lua.

  État : PROVISOIRE (lot V2) : visuel commun de la session 5 (teinte d'époque, socle, reflet, halo, échelle
  plafonnée à +10 %). Ce schéma a été REJETÉ sur le design (E25) : aucun progrès visuel revendiqué.
  À faire (V3) : une silhouette par époque (ctx.step == 1), une pièce de plus au 2e niveau (ctx.step == 2).
]]

-- Lot TIRS (27/10) : faisceau de l'âge (table shared/tirs/ages.lua, champ `laser`) : copie déclarée de laser-beam,
-- textures blanches de même cadre teintées, épaissies (échelle des sprites : `width` est une clé de jeu), cœur
-- lumineux et lumière au sol de l'âge. Les dégâts, la durée et la portée du faisceau ne changent pas.
local TIRS = require("shared.tirs.ages")
local TK = require("prototypes.tirs_kit")

local M = {}

function M.dress(p, ctx)
  ctx.kit.provisional(p, ctx)
  local A = TIRS.ages[ctx.epoch]
  local spec = A and A.laser
  if spec then
    local d = p.attack_parameters.ammo_type.action.action_delivery
    d.beam = ctx.declare("beam", d.beam, "faisceau", function(c) TK.faisceau_blanc(c, spec) end)
  end
end

return M
