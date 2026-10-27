--[[
  Réglage du lot IA3-b « personne n'attend, personne n'arrache » (docs/IA3_CERVEAU.md §2.2, §2.3, §6.2). Étape
  settings uniquement. Fichier du lot IA3-b ; requis par settings.lua (commit de l'intégrateur).

  fo-war-ia3-marche   place de marché des tâches (n'importe quel PNJ libre prend la tâche la plus utile qu'il sait
                      faire, le pôle oriente sans interdire), registre des réservations (une tâche prise réserve sa
                      matière au coffre, prise stricte, préemption réglée et journalisée) et manque de plaques (fours
                      du QG, minage à la main par plusieurs PNJ). Factions ET votre équipe. Lu à la PREMIÈRE pensée de
                      chaque équipe et FIGÉ dans son état (f.team.marche) : un changement en cours de partie ne touche
                      que les équipes fondées ensuite. Préfixe « fo-war- » : réglable par les bancs (war_setting).
                      Valeur par défaut : shared/ai3/marche.lua (M.DEFAULT_ON), la même que celle du moteur simulé.
  Traductions : locale/*/ia3b.cfg.
]]

local M = require("shared.ai3.marche")

data:extend({
  {
    type = "bool-setting",
    name = M.SETTING,
    setting_type = "runtime-global",
    default_value = M.DEFAULT_ON,
    order = "e-war-z-ia3-b",
  },
})
