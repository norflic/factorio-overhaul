--[[
  Lot PNJ-VÉRIF (24/10) : `pnj-vue`, captures prises plus tard (tick 100 800, ≈ 28 min de jeu), quand la 1re
  attaque contre le joueur arrive sur la base témoin (dans `ia0-normal`, base touchée au tick 100 380). Même carte,
  même guerre ; ×8 jusqu'au tick 96 000, puis ×1. Lancement :
    $env:FO_VISUAL_ARGS = '--ticks 103000'
    & "<racine>\fo-captures.bat" pnj-vue-attaque "<source>"
    $env:FO_VISUAL_ARGS = $null
]]
local V = require("scenarios/pnj-vue")

local out = {}
for k, v in pairs(V) do out[k] = v end
out.description = "PNJ-VERIF : captures des PNJ en action, au moment de l'attaque contre la base temoin"
out.shots_delay = 100800
return out
