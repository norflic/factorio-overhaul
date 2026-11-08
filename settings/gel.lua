--[[
  Réglage du lot X10-GEL (fo-logs/2026-11-07_X10/L1_CRITERES.md ; décision du DC du 7/11 en QCM : « Oui, figées hors de vue
  (Recommandé) »). Étape settings uniquement ; requis par settings.lua.

  fo-war-gel   les usines des factions (pas votre équipe) qu'aucun joueur ne voit s'arrêtent au moteur (active = false) et leur
               production est comptée comme si elles tournaient (script/faction/gel_usines.lua, gel_usines_jeu.lua). Relu à chaque
               guet (20 ticks) : l'éteindre en cours de partie réveille tout, plus rien n'est figé.
  Traductions : locale/*/x10-gel.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-gel",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-gel",
  },
})
