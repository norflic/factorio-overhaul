--[[
  Lot CARTE-MAX : etape1-geants (carte aux gisements géants posés, partie du guide) avec, aux minutes 20, 40 et 60, pour votre
  équipe et chaque faction, la vue d'ensemble du QG et le plus grand champ de foreuses (scenarios/max_build.lua). Valide la chaîne
  d'images et donne un premier regard sur les bases. Contrôles de etape1-geants conservés (tick 143 000).
  Lancement : py -3.9 -B tools/autotest/banc.py --out <archive> --qui <lot> --captures --visuel="--ticks 217200 --timeout 14400" -- 217200 etape1-geants-vues <source>
]]
return require("scenarios/max_build")({
  description = "ETAPE1-GEANTS-VUES : etape1-geants, vues d'ensemble et champs de foreuses a 20/40/60 min",
  base = "scenarios/etape1-geants",
  nomap = true,
  photo_ticks = { 72000, 144000, 216000 },
  shots = true,
  shots_delay = 216800,
})
