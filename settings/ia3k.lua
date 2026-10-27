--[[
  Réglage du lot IA3-k « comportements visibles » (docs/IA3K_COMPORTEMENTS.md). Étape settings uniquement. Fichier
  possédé par le lot IA3-k ; requis par settings.lua (commit de l'intégrateur).

  fo-war-ia3-comportement  carte du danger, trajets qui évitent le danger et varient, réaction en marche, peur, porte
                           des tâches dangereuses, rôles des soldats, états visibles au-dessus des PNJ. ALLUMÉ par défaut
                           (garde-fous mesurés : fo-logs/2026-10-27_IA3-k/INTEGRATION.md) ; éteint, aucun crochet n'agit.
                           Lu à chaque usage (modifiable en cours de partie). Préfixe « fo-war- » : réglable par les bancs
                           (interface distante war_setting).
  Traductions : locale/*/ia3k.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-ia3-comportement",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-ia3-k",
  },
})
