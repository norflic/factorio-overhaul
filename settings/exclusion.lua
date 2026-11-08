--[[
  Lot VIDEO-PLAFONDS, partie d (V99) : réglage d'EXCLUSION de demande. Étape settings uniquement ; le `require("settings.exclusion")`
  de settings.lua est à l'intégrateur (settings.lua, après la ligne de settings.video).

  fo-war-exclusion  runtime-global, CHAÎNE, VIDE par défaut (aucun objet exclu : la décision est celle d'avant, octet pour octet).
                    Noms de prototypes d'objets séparés par des virgules, des points-virgules ou des blancs (64 au plus).
                    Un objet exclu n'apparaît dans aucun puits ni aucune option de la capitalisation des factions et de votre
                    équipe ; chaque refus est écrit ([FO-EXCLU] au journal). Règle pure : shared/ai3/exclusion.lua ; lecture et
                    journal : script/ai3/exclusion.lua. Traductions : locale/*/video-plafonds.cfg.
  Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
]]

data:extend({
  {
    type = "string-setting",
    name = "fo-war-exclusion",
    setting_type = "runtime-global",
    default_value = "",
    allow_blank = true,
    order = "e-war-z-video-e",
  },
})
