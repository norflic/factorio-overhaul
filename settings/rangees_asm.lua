--[[
  Réglage du lot RANGEES-ASM (8/11) : rangées d'assembleurs DYNAMIQUES et sortie sur deux voies. Étape settings uniquement ;
  requis par settings.lua (ajouté par l'intégrateur).

  fo-war-rangee-dyn   une rangée d'assembleurs demandée par la capitalisation (ordre « chaine ») est planifiée entière à la borne de
                      son gabarit (place réservée) et posée à la taille de la demande ; une hausse de la demande la FAIT GRANDIR sur
                      place, finie ou pas (script/team/rangee_dyn.lua, règle shared/team/rangee_dyn.lua) ; une recette que la sortie
                      sur une voie bornerait sous 5 machines (câbles) sort sur les deux voies par une jonction (shared/team/modules.lua,
                      G.simple, voies = 2). Éteint : comportement d'avant (rangée posée à sa taille, agrandie seulement en attente).
                      Relu à chaque ordre : l'éteindre n'agit que sur les NOUVELLES rangées.
  Traductions : locale/*/rangees_asm.cfg.
]]

data:extend({
  {
    type = "bool-setting",
    name = "fo-war-rangee-dyn",
    setting_type = "runtime-global",
    default_value = true,
    order = "e-war-z-capi-rangee",
  },
})
