--[[
  Lot PNJ-VÉRIF (24/10) : le diagnostic `pnj-diag` (groupes d'Écarlate) sur la carte et la guerre d'`ia0-normal`
  (difficulté Normale, base témoin du joueur). Sert à suivre le RETOUR d'un groupe après une attaque lointaine
  (1 000 tuiles) : retour direct, puis retour par l'itinéraire de l'aller (script/faction/military.lua).
  Lancement : `fo-autotest.bat nopause <ticks> pnj-diag-normal <source>` (BILAN au tick 215 060 seulement ; un
  passage plus court ne sert qu'au journal [FO-PNJ-DIAG-NORMAL]).
]]
local D = require("scenarios/pnj-diag")
local C = require("scenarios/ia0_common")

return {
  description = "PNJ-VERIF : diagnostic des groupes d'Ecarlate, guerre d'ia0-normal",
  base = nil,
  check_tick = D.check_tick,
  init = function(ctx)
    C.build_base(ctx)
    C.start_war(ctx, "normal")
  end,
  tick = D.tick,
  finish = D.finish,
}
