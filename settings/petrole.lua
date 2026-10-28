--[[
  Réglage du lot PETROLE « aller au pétrole, comme un joueur » (fo-logs/2026-10-27_PETROLE/INTEGRATION.md). Étape
  settings uniquement ; requis par settings.lua.

  fo-war-petrole   les factions savent poser les machines que la main ne sait pas faire : chevalets sur un gisement de
                   pétrole, raffinerie, usines chimiques, pompe de rive, tuyaux, quais et poteaux (exécutant générique :
                   machines et raccords lus dans les prototypes, shared/ai3/fluides.lua). Le cerveau général voit alors
                   le pack chimique payable une fois le pétrole trouvé, le fait explorer, et demande un site au gisement
                   quand ses packs en ont besoin. ALLUMÉ par défaut (lot PETROLE 2 : règle du DC, pas de réglage éteint par défaut ;
                   interrupteur de coupure, preuves en moteur réel dans fo-logs/2026-10-28_PETROLE2). Préfixe « fo-war- » : réglable par les bancs
                   (interface distante war_setting).
  Traductions : locale/*/petrole.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-petrole",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-ia3-p",
  },
})
