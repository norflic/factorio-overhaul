--[[
  Lot CARTE-MAX (directive du DC, 9/11) : la partie du guide (etape1-guide : 30 ouvriers par faction, automatisation et
  capitalisation allumées, mêmes relevés [FO-ETAPE1-GUIDE] et [FO-FONCTION]) sur une carte aux gisements AU MAXIMUM (taille et
  richesse 600 % de toutes les ressources, scenarios/max_common.lua), avec, aux minutes 20, 40, 60, 90 et 120, pour votre équipe
  et chaque faction : une vue d'ensemble autour du QG et le plus grand champ de foreuses (scenarios/max_build.lua).
  120 min = 432 000 ticks ; contrôles au tick 431 000, captures de fin du guide au tick 431 600.
  Lancement (images, place 1) :
    py -3.9 -B tools/autotest/banc.py --out <archive> --qui <lot> --captures --visuel="--ticks 432200 --timeout 14400 --pcores" -- 432200 etape1-max <source>
  Sans images (relevés seuls) : retirer --captures et --visuel.
]]
return require("scenarios/max_build")({
  description = "ETAPE1-MAX : partie du guide sur carte aux gisements au maximum (600 %), captures 20/40/60/90/120 min",
  check_tick = 431000,
  releve_at = 1500,
  photo_ticks = { 72000, 144000, 216000, 324000, 432000 - 600 },
  fmin = 3,
  shots = true,
  shots_delay = 431600,
})
