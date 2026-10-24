--[[
  Vérification adverse du lot PNJ-VÉRIF : témoin de verif-tourelles, recherche « Tourelles » faite à l'init, AVANT le
  premier passage du cerveau de l'équipe du joueur. Lancement : fo-autotest.bat nopause 108000 verif-tourelles-avant <source>
]]
local V = require("scenarios/verif-tourelles")
return V.make(true)
