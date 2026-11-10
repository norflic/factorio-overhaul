--[[
  Lot CC-COMBUSTIBLE (10/11, partie du DC en 0.6.87 : fo-logs/2026-11-10_PLAYTEST-0687/factorio-current.log, graine 3592985581) :
  la partie du guide aux REGLAGES DE CETTE PARTIE (ligne [FO-REGLAGES] du journal : fo-war-factions=4, fo-war-workers=8,
  fo-npc-start=12 ; difficulte normale, coffre d'equipe garni d'office). Banc d'orientation et critere du lot : bruleurs vitaux
  a sec de votre equipe ([FO-FLUX]) a 15, 20, 25 et 30 min, et la ligne [FO-CHARBON-SORTIE] (ou va le charbon du coffre).
  Lancement : banc.py --out <archive> --graine 3592985581 --qui CC-COMBUSTIBLE -- 108000 cc-combustible-dc <source>
]]

local base = require("scenarios/verif_guide_common")(8)
local init0 = base.init

base.description = "CC-COMBUSTIBLE : partie du guide aux reglages de la partie du DC du 10/11 (4 factions, 8 ouvriers, 12 PNJ)"

base.init = function(ctx)
  ctx.check(ctx.remote("fo-ia1", "set_setting", "fo-npc-start", 12) == 12, "effectif de depart 12 (reglage du DC)")
  init0(ctx)
  ctx.check(ctx.remote("factorio-overhaul", "war_setting", "fo-war-factions", 4) == 4, "4 factions (reglage du DC)")
end

return base
