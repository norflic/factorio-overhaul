--[[
  Réglages des équipes de PNJ, lot IA1-a « Échelle 30 » (docs/EQUIPES_PNJ.md §11 ; OBJECTIFS.md C5).
  Étape settings uniquement. Fichier possédé par le lot IA1 (docs §20).

  Tous « runtime-global » (réglages de partie, synchronisés en multijoueur, modifiables en cours de partie) :
    (fusion avec 0.4.15 : le nombre de factions et les PNJ par faction sont les réglages de la guerre
    « fo-war-factions » et « fo-war-workers », déclarés par settings/faction.lua avec les valeurs de
    S.SETTINGS ; plafond des PNJ dès l'époque 1 (Q-IA1-2 (2)), suivi en cours de partie par une guerre lancée
    sans nombre) ;
    fo-player-team-npc-max  PNJ de votre équipe (30 ; 6 à 60) ;
    fo-npc-start            effectif de départ d'une équipe (8 ; 2 à 30), offert à la fondation ;
    fo-agents-max           garde de performance comptée en agents riches (300 ; 50 à 600) : au-delà, le
                            recrutement est suspendu ;
    fo-path-issue-per-tick  demandes de chemin émises par tick pour tout le mod (2 ; 1 à 6), en plus de la
                            limite des demandes en vol (fo-path-max-inflight, 6) ;
    fo-recruit-idle-max     frein par le travail (correction IA1-a ; 0 ; 0 à 60) : une équipe ne recrute que si
                            au plus ce nombre de ses PNJ sont sans tâche ; 60 = seul le stock freine.
  Défauts et bornes : shared/team/scale.lua (S.SETTINGS), une seule source avec la lecture runtime.
  Traductions : locale/*/ia1.cfg.
]]

local S = require("shared.team.scale")

local list = {}
for _, s in ipairs(S.SETTINGS) do
  if not s.declared_in then -- fo-war-factions, fo-war-workers : settings/faction.lua
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
end
data:extend(list)
