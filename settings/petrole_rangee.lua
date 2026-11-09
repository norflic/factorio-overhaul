--[[
  Réglage du lot PETROLE-RANGEE (directive du DC, 8/11 : « un joueur humain pose des chevalets sur l'intégralité des puits
  disponibles, les relie entre eux, et fait sortir tout ce pétrole brut vers une ligne principale »). Étape settings uniquement ;
  à requérir par settings.lua (intégrateur).

  fo-war-petrole-champ   un site de pétrole FINI grandit par chantiers d'extension jusqu'à ce que tous les puits atteignables de son
                         champ soient équipés : collecteur droit, embranchements droits ou en L, ligne principale vers le brut du site
                         (script/ai3/petrole.lua, shared/ai3/collecteur.lua). ALLUMÉ par défaut ; absent du jeu = allumé (le code lit
                         le réglage avec pcall). Éteint : aucune extension nouvelle, les chantiers posés restent.
  Traductions : locale/*/petrole_rangee.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-petrole-champ",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-ia3-p-b",
  },
})
