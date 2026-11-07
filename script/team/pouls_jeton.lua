--[[
  Lot POULS (7/11, fo-logs\2026-11-07_POULS\CRITERES.md) : JETON du tick pour les relevés lourds du pouls du chantier (script/team/build.lua,
  Build.PULSE) : une bande du relevé du réseau (script/team/reseau_vivant.lua), une bande ou la fin du relevé du raccordement
  (script/team/raccord.lua). Demandeur : « <équipe>:rv » ou « <équipe>:ra ».
  Lot LOURD (point 2, 7/11 ; fo-logs\2026-11-07_LOURD\CRITERES.md §2) : ce jeton est devenu l'ordonnanceur des travaux lourds de tout le mod,
  à budget par tick (script/core/lourd.lua) ; ce module en est un ALIAS (build.lua garde son local `Jeton` : aucune locale de plus). Même
  file équitable, même espace de global (« pouls_jeton ») : une sauvegarde de la 0.6.59 à 0.6.61 reprend sa file telle quelle.
]]
return require("script.core.lourd")
