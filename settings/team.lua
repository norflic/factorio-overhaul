--[[
  Réglages des équipes de PNJ, lot IA1-a « Échelle 30 » (docs/EQUIPES_PNJ.md §11 ; OBJECTIFS.md C5).
  Étape settings uniquement. Fichier possédé par le lot IA1 (docs §20).

  Tous « runtime-global » (réglages de partie, synchronisés en multijoueur, modifiables en cours de partie) :
    fo-factions             factions lancées par « /fo-war start » sans argument (2 à 4) ;
    fo-team-npc-max         PNJ par faction (30 ; 6 à 60) : plafond dès l'époque 1 (Q-IA1-2 (2)), seul le
                            stock freine ; s'applique aussi à une guerre en cours lancée sans nombre explicite ;
    fo-player-team-npc-max  PNJ de votre équipe (30 ; 6 à 60) ;
    fo-npc-start            effectif de départ d'une équipe (8 ; 2 à 30), offert à la fondation ;
    fo-agents-max           garde de performance comptée en agents riches (300 ; 50 à 600) : au-delà, le
                            recrutement est suspendu ;
    fo-path-issue-per-tick  demandes de chemin émises par tick pour tout le mod (2 ; 1 à 6), en plus de la
                            limite des demandes en vol (fo-path-max-inflight, 6).
  Défauts et bornes : shared/team/scale.lua (S.SETTINGS), une seule source avec la lecture runtime.
  Traductions : locale/*/ia1.cfg.
]]

local S = require("shared.team.scale")

local list = {}
for _, s in ipairs(S.SETTINGS) do
  list[#list + 1] = {
    type = "int-setting",
    name = s.name,
    setting_type = "runtime-global",
    default_value = s.default,
    minimum_value = s.min,
    maximum_value = s.max,
    order = s.order,
  }
end
data:extend(list)
