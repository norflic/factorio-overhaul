--[[
  Lot TV-ARCHI (feuille de route « Factorio Automated », docs/TODO_VIDEO.md V23 l.89) : réglage de l'enveloppe d'avance des quartiers.
  Étape settings uniquement ; requis par settings.lua (ligne posée par l'intégrateur). Allumé par défaut (ordre du DC : les points de la
  TODO vidéo intégrés et allumés). Son lecteur (script/team/quartiers.lua, Qr.on) garde un repli à « éteint » quand le réglage MANQUE
  (moteur simulé des tests) : les suites gardent le plan directeur d'avant ; le test allumé est tests/quartiers_test.lua.

  fo-war-enveloppe   V23 : un quartier (3 × 3 lots) s'ouvre d'avance (poteau relié au réseau, coffres de dépôt, lot du pôle et rues
                     défrichés) quand les lots libres des quartiers ouverts passent sous le besoin anticipé. Traductions :
                     locale/*/tv-archi.cfg. Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-enveloppe",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-video-t",
  },
})
