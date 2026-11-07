--[[
  Lot X10-CHEMINS (7/11 ; fo-logs/2026-11-07_X10/CHEMINS_CRITERES.md) : règles PURES du service de chemins
  (script/core/path_service.lua). Aucune API Factorio : tests/chemins_test.lua.

  L5 : ne plus demander un chemin VOUÉ À L'ÉCHEC. Sur la sauvegarde du DC (tick 919 256), 5 344 des 149 966 demandes ont échoué
  avec un but dans l'eau et 1 079 avec un départ bloqué ; 99,9 % des échecs venaient de la navigation des PNJ.

  BUT IMPOSSIBLE (Ch.precheck → "refuse_water"). Le service compte les tuiles SANS la couche Ch.LAYER ("player-layer") dans le
  disque de rayon Ch.check_radius(radius) = radius + Ch.MARGIN autour du but. S'il n'y en a aucune, le chemin ne peut pas réussir.
  Preuve :
    - un chemin réussi finit en un point p du corps, à moins de `radius` du but (définition de `radius`, request_path) ;
    - la boîte du corps contient p et ne touche aucune tuile qui a une couche de son masque, donc la tuile de p n'a pas
      "player-layer" (le masque du corps la contient : Ch.checks_goal) ;
    - le centre de cette tuile est à moins de radius + 0,71 du but, et ses quatre coins à moins de radius + 1,42.
  Avec MARGIN = 1,5, la tuile est comptée, que le moteur compte une tuile par son centre, par son recouvrement du disque ou
  seulement si elle y est tout entière. Donc : aucune tuile comptée ⇒ aucun chemin possible. Une seule couche dans le filtre :
  le résultat ne dépend pas de la lecture « une des couches » ou « toutes les couches » du filtre.
  Chunks non générés : le service ne refuse que si TOUS les chunks qui touchent la boîte du disque sont générés (ce que le
  pathfinder fait d'un chunk non généré n'est pas lu : on ne refuse pas sur une inconnue).
  Témoin positif : le service ne refuse que si le même disque compte AU MOINS une tuile AVEC la couche (goal_blocking > 0). Dans
  le jeu, un disque de chunks générés a toujours des tuiles : la règle est la même. Un faux moteur qui rend 0 à toute question
  (bancs hors jeu) ne fait donc jamais refuser.

  DÉPART BLOQUÉ (Ch.precheck → "unpad"). Un départ encore bloqué pour la boîte ÉLARGIE (marge H4) après les déplacements du
  service, mais libre pour la boîte du prototype, est demandé avec la boîte du prototype (marge 0) : sinon la recherche partait
  d'un point en collision. Rien n'est REFUSÉ pour un départ : on ne sait pas si le moteur échoue toujours sur un départ bloqué.
]]

local Ch = {}

Ch.LAYER = "player-layer"
Ch.MARGIN = 1.5
Ch.DEFAULT_RADIUS = 1 -- request_path : `radius` vaut 1 par défaut
Ch.CHUNK = 32

--- Rayon du disque contrôlé autour du but.
function Ch.check_radius(radius)
  if radius == nil then radius = Ch.DEFAULT_RADIUS end
  return radius + Ch.MARGIN
end

--- Le contrôle du but vaut-il pour ce prototype ? `layers` : liste des couches de son masque (sans les drapeaux).
function Ch.checks_goal(layers)
  for i = 1, #(layers or {}) do
    if layers[i] == Ch.LAYER then return true end
  end
  return false
end

--- Chunks (cx, cy) qui touchent la boîte du disque de centre (x, y) et de rayon r, dans l'ordre (y, puis x) : liste de { cx, cy }.
function Ch.disc_chunks(x, y, r)
  local C = Ch.CHUNK
  local floor = math.floor
  local out = {}
  for cy = floor((y - r) / C), floor((y + r) / C) do
    for cx = floor((x - r) / C), floor((x + r) / C) do
      out[#out + 1] = { cx, cy }
    end
  end
  return out
end

--- Décision avant request_path. `obs` :
---   goal_land       nombre de tuiles praticables comptées dans le disque (nil : pas de contrôle du but) ;
---   goal_blocking   nombre de tuiles AVEC la couche comptées dans le même disque (témoin positif ; nil vaut 0) ;
---   goal_generated  vrai si tous les chunks du disque sont générés (nil vaut faux) ;
---   start_blocked   le départ (après les déplacements du service) touche encore un obstacle pour la boîte ÉLARGIE ;
---   start_free_bare le même départ est libre pour la boîte du prototype (marge 0) ;
---   pad             marge de la demande.
--- Rend "refuse_water" (but impossible : ne rien demander), "unpad" (demander avec la boîte du prototype) ou "request".
function Ch.precheck(obs)
  if obs.goal_land == 0 and (obs.goal_blocking or 0) > 0 and obs.goal_generated then return "refuse_water" end
  if obs.start_blocked and (obs.pad or 0) > 0 and obs.start_free_bare then return "unpad" end
  return "request"
end

return Ch
