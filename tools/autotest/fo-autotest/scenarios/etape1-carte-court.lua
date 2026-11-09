--[[
  Lot CARTE-MAX : micro-banc (3 000 ticks, sans images). Carte aux gisements au maximum (taille et richesse 600 % de TOUTES les
  ressources), relevé au tick 1 500 autour de chaque QG contre une surface de référence de même graine aux réglages d'origine,
  contrôles au tick 2 900. Détail : scenarios/max_common.lua.
  Lancement : py -3.9 -B tools/autotest/banc.py --carte-max --out <archive> --qui <lot> -- 3000 etape1-carte-court <source>
]]
return require("scenarios/max_build")({
  description = "ETAPE1-CARTE-COURT : gisements au maximum (600 %), releve contre la reference, 3 000 ticks",
  check_tick = 2900,
  releve_at = 1500,
  photo_ticks = { 2000 },
  fmin = 3,
  shots = false,
  creation = true,
})
