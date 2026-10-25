--[[
  Lot IA1-b2 : la partie du guide (verif-guide, mêmes réglages, même coffre, mêmes contrôles) AVEC l'étape 8 du guide
  jouée : « Tourelles : fais la recherche Tourelles. Ton équipe les fabrique alors elle-même »
  (fo-logs\2026-10-24_PNJ\GUIDE_PARTIE.md). La recherche « gun-turret » de la force du joueur est terminée par script à
  la minute RESEARCH_MIN (verif-guide ne joue aucune recherche : votre équipe n'y a jamais de tourelle).
  Lancement : `fo-autotest.bat nopause 216000 ia1b2-guide <source>` (graine : FO_MAP_SEED). Journal : [FO-IA1B2-GUIDE].
  Mesures minute par minute : lignes « mesure minute N » (tools/autotest/ia1b2_guide.py).
]]

local base = require("scenarios/verif-guide")

local RESEARCH_MIN = 5

local s = {}
for k, v in pairs(base) do s[k] = v end
s.description = "IA1-b2 : partie du guide, etape 8 jouee (recherche Tourelles a " .. RESEARCH_MIN .. " min)"

s.tick = function(ctx, e)
  if e.tick == RESEARCH_MIN * 3600 then
    local t = game.forces.player.technologies["gun-turret"]
    if t and not t.researched then t.researched = true end
    local r = game.forces.player.recipes["gun-turret"]
    ctx.log(string.format("recherche Tourelles terminee pour le joueur a la minute %d : recette %s", RESEARCH_MIN,
      tostring(r and r.enabled)))
  end
  return base.tick(ctx, e)
end

return s
