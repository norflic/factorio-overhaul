--[[
  Réglage du lot KIT « kit de départ des factions » (réponse du DC du 28/10). Étape settings uniquement ; requis par
  settings.lua.

  fo-war-kit-genereux   Factions : kit de départ généreux (tests). DÉSACTIVÉ par défaut = le kit des factions est celui de
                        votre équipe (coffre vide, aucun four, seuls les ouvriers armés) : elles récoltent tout le reste.
                        Activé : l'ancien kit (12 foreuses, 8 fours, 4 coffres, 150 charbon, 200 fer, 60 cuivre, 80 pierre,
                        40 chargeurs ; 2 fours posés) ; les bancs de test l'allument (tools/autotest/fo-autotest/control.lua)
                        pour garder leurs attendus. Lu à la fondation d'un QG : sans effet sur une partie en cours.
                        Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
  Traductions : locale/*/kit.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-kit-genereux",
    setting_type = "runtime-global",
    default_value = false,
    order = "e-war-z-kit",
  },
})
