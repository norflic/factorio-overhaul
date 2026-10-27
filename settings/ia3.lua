--[[
  Réglages de la section IA3 « le cerveau des PNJ » (docs/IA3_CERVEAU.md §5.4, §6.2). Étape settings uniquement.
  Fichier possédé par la section IA3 ; requis par settings.lua (commit de l'intégrateur).

  fo-war-ia3-recherche   lot IA3-a « recherche d'abord, rien d'impayable » (règle pure shared/ai3/recherche.lua) :
                         ÉTEINT par défaut tant que les critères K1, K6, K9, K12 ne sont pas mesurés (règle de
                         l'intégrateur, revue M10) ; la valeur est lue à la fondation de chaque équipe de faction et
                         FIGÉE dans son état (un changement en cours de partie ne touche que les équipes fondées
                         ensuite). Préfixe « fo-war- » : réglable par les bancs (interface distante war_setting).
  Traductions : locale/*/ia3.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-ia3-recherche",
    setting_type = "runtime-global",
    default_value = false,
    order = "e-war-z-ia3-a",
  },
})
