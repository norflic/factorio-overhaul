-- Lot PREUVES (13/11) : UNE partie de 120 min comme chez le DC (partie-reelle-120), photographiée à 30, 60 et 120 min
-- (mêmes gisements, noms de fichier portant la minute : NNN-pav-mMMM-<équipe>-<ressource>-<n>.png). Budget de la session
-- avec images : --visuel="--ticks 434000 --timeout 14400" (ligne « budget ... ticks_min= » du journal).
return require("scenarios/pavage_common")(120, "partie", { 30, 60 })
