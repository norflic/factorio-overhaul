--[[
  Réglage du lot IA3-e « automatiser ce qui revient » (fo-logs/2026-10-27_IA3-e/INTEGRATION.md). Étape settings
  uniquement ; requis par settings.lua.

  fo-war-ia3e   les factions mesurent le temps que leurs PNJ passent à la main sur chaque objet et demandent au plan
                directeur un module (fonderie électrique avec foreuses et tapis, rangée d'assembleurs) quand il se
                rembourse en moins de 20 min (5 sous menace) ; centrale à vapeur d'abord ; un module fini se nourrit et
                remplace les tournées. Votre équipe n'automatise pas (même éteint ou allumé). Relu à chaque pensée :
                l'éteindre en cours de partie arrête les NOUVELLES demandes (les modules posés restent).
                Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
  Traductions : locale/*/ia3e.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-ia3e",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-ia3-e",
  },
})
