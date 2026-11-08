--[[
  Lot GISEMENTS-GEANTS (demande du DC, 8/11 17 h 50 : « Forcez l'IA à réagir face à des champs de minerais immenses ») : la partie de
  etape1-guide (mêmes réglages, mêmes relevés, 144 000 ticks si on lance 144 000 ; le code du guide est RÉUTILISÉ, pas copié), avec,
  pour votre équipe ET chaque faction, 2 gisements IMMENSES (2 500 à 5 000 tuiles, irréguliers, à 60-200 tuiles du QG) par minerai :
  fer, cuivre, charbon, pierre ; les gisements de départ sont gardés. Pose, relevé et contrôles : scenarios/geants_common.lua.
  Posés dès que tous les QG existent (lancement automatique de la guerre), avant que les équipes ne posent quoi que ce soit.
  Relevé toutes les minutes, par équipe et par gisement : lignes [FO-GEANTS] (tuiles couvertes par des foreuses électriques et
  thermiques séparées, pour-mille couvert, foreuses dessus, lignes de tapis qui en sortent).
  Lancement (la porte de livraison) :
    py -3.9 -B tools/autotest/banc.py --out <archive> --qui <lot> --captures --visuel="--ticks 144200 --timeout 7200" -- 144200 etape1-geants <source>
  (sans images : retirer --captures et --visuel).
]]

local G = require("scenarios/geants_common")
local guide = require("scenarios/etape1-guide")

local base = {}
for k, v in pairs(guide) do base[k] = v end
local tick0 = guide.tick

-- Partie de 144 000 ticks (40 min) : les contrôles de finish du guide visent 59 min (check_tick 214 000) et n'ont pas de sens ici ;
-- seuls ceux des gisements sont joués, au tick 143 000. Les relevés du guide ([FO-ETAPE1-GUIDE], [FO-FONCTION]) tournent tels quels.
local CHECK = 143000
base.description = "ETAPE1-GEANTS : etape1-guide avec des gisements immenses (2 par minerai, 2 500 a 5 000 tuiles) pour chaque equipe"
base.check_tick = CHECK
base.shots_delay = 143500 -- captures de fin (session avec images) avant la fin d'une partie de 144 200 ticks

base.tick = function(ctx, e)
  if tick0 then tick0(ctx, e) end
  G.on_tick(ctx, e, { every = 3600 })
end

base.finish = function(ctx)
  G.checks(ctx)
end

return base
