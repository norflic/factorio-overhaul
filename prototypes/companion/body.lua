-- Corps physique du compagnon : clone du personnage vanilla.
-- Hypothèse H0 (RD_LOG.md) : un `character` sans joueur conserve inventaire, PV, minage et tir.
-- Aucun sprite nouveau : la teinte est appliquée au runtime via LuaEntity.color.

local body = table.deepcopy(data.raw["character"]["character"])
body.name = "fo-companion"
body.localised_name = { "entity-name.fo-companion" }
body.localised_description = { "entity-description.fo-companion" }

-- Lot X10 (le DC, 7/11, 18 h 33, par QCM : « Les retirer aux PNJ (Recommandé) ») : ni poussière sous les pas ni
-- empreintes pour les PNJ. M1 (fo-logs\2026-11-07_X10\MOTEUR.md §12.3) : sur la partie du DC, les PNJ font 90 % des
-- particules, de 0,04 à 0,05 ms par tick. Le personnage du joueur (« character ») garde les siennes : seule cette copie
-- change. footstep_particle_triggers n'est pas défini en vanilla 1.1.91 : retiré aussi, au cas où un mod chargé avant
-- celui-ci le pose sur « character ».
body.synced_footstep_particle_triggers = nil
body.footstep_particle_triggers = nil
body.footprint_particles = nil

data:extend({ body })
