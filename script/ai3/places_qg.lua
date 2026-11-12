--[[
  Lot SCALE (correction après revue, 27/10) : POSE des machines du QG d'une équipe en rangées (fours de la fonderie,
  laboratoires). Les places viennent de la règle pure shared/ai3/places.lua (pas = emprise du prototype, lue dans sa
  collision_box ; disposition nommée de shared/team/config.lua, T.hq_rows) ; chaque place est RECALÉE sur la grille du
  bâtiment (Pl.snap) et VÉRIFIÉE (can_place_entity) avant la pose.

  Pourquoi (capture du QG à 30 PNJ, 45 min, banc s4-qg) : la pose d'avant cherchait une place libre AUTOUR d'un point
  hors grille (le centre du QG est en x,40625) avec find_non_colliding_position, puis create_entity RECALAIT le bâtiment
  sur la grille (F104) sans vérifier la place : un four sur deux chevauchait son voisin (66 chevauchements de boîtes de
  collision sur les 4 QG ; fours en quinconce, à une tuile l'un de l'autre). Chaque nouvelle pose repartait aussi de la
  première place, déjà prise : les rangées n'étaient jamais suivies.

  Deux passes : 1. les places exactes des rangées, dans leur ordre, si elles sont libres ; 2. secours (terrain encombré :
  arbres, rochers, eau) : la place libre la plus proche d'une place des rangées (recherche du moteur dans le rayon
  spec.search, celui de main 0.6.1), recalée et vérifiée elle aussi. Aucun nom du jeu (règle anti-échelle d'IA-G) : le
  prototype et la fonction de pose viennent de l'appelant. Déterminisme : listes dans leur ordre, aucun pairs.
]]
local Pl = require("shared.ai3.places")
local Sm = require("shared.team.sol_minerai") -- lot DECOUPLAGE : rien d'autre que foreuses, poteaux, tapis sur une ressource

local Q = {}

--- Lot DECOUPLAGE : l'entité `name` posée en `pos` couvrirait-elle une tuile de ressource alors que son type ne le permet pas
--- (shared/team/sol_minerai.lua, Sm.forbidden) ? Emprise = collision_box du prototype. Lu aussi par les tourelles (outposts, team).
--- Lot TAMPON-MINERAI : l'emprise est jugée là où create_entity POSE le bâtiment (recalé sur sa grille, Pl.snap, F104), pas à la place
--- trouvée hors grille par find_non_colliding_position (centre de commandement de CAPITAL et du QG) ; une place déjà recalée ne bouge pas.
function Q.on_resource(surface, name, pos)
  local proto = game.entity_prototypes[name]
  local cb = proto and proto.collision_box
  return Sm.forbidden(proto and proto.type, function()
    if not cb then return false end
    local w, h = Pl.tiles(cb)
    pos = { x = Pl.snap(pos.x, w), y = Pl.snap(pos.y, h) }
    return surface.count_entities_filtered({ area = { { pos.x + cb.left_top.x, pos.y + cb.left_top.y }, { pos.x + cb.right_bottom.x, pos.y + cb.right_bottom.y } },
      type = "resource", limit = 1 }) > 0
  end)
end

--- Lot FOUR-PLEIN : crochet des tuiles réservées par le plan directeur (b.occ), posé par script/team/build.lua (Build.reserved_entity) ;
--- absent : rien n'est réservé. Un labo posé à 12 min sur la ligne de plaques planifiée à 9 min du champ de fer coupait ce tapis :
--- 24 fours « sortie pleine », fer au coffre à 0 (etape1-guide, 2507543475).
--- Lot TUILES-RESERVEES : c'est le SEUL crochet des tuiles réservées ; tous les poseurs hors du plan (avant-postes, tourelles, annexes,
--- fours et labos du QG, centre de commandement, reconstruction, remplacements de foreuse, hygiène, adoption) le lisent par
--- Q.is_reserved. opts : ceux de Build.reserved_entity (couloir = false : tuiles du plan seulement ; keep, blocked : remplacement sur place).
Q.reserved = nil

--- Lot TUILES-RESERVEES : l'entité `name` posée en `pos` (direction `dir`) toucherait-elle une tuile réservée au plan directeur de `f` ?
function Q.is_reserved(f, name, pos, dir, opts)
  return Q.reserved ~= nil and Q.reserved(f, name, pos, dir, opts) == true
end

local QG = { couloir = false } -- labos et fours du QG : tuiles du plan, pas les couloirs d'accès (lot FOUR-PLEIN)

--- Lot FOUR-PLEIN : `make` qui saute (rend false : place suivante) une place réservée au plan directeur de l'équipe `f`.
--- opts : ceux de Q.is_reserved (défaut : tuiles du plan seulement).
function Q.skip_reserved(f, name, make, opts)
  return function(pos)
    if Q.is_reserved(f, name, pos, nil, opts or QG) then return false end
    return make(pos)
  end
end

--- Pose au plus `count` bâtiments `name` en rangées autour de `origin` (centre du QG). spec : disposition (T.hq_rows.*) ;
--- need : places à générer ; make(position) pose un bâtiment et rend true (posé), false (raté : place suivante) ou nil
--- (plus d'objet : arrêt). Rend le nombre posé.
function Q.place(surface, name, force, origin, spec, need, count, make)
  local proto = game.entity_prototypes[name]
  local w, h = Pl.tiles(proto and proto.collision_box)
  return Q.place_list(surface, name, force, origin, Pl.rows(spec, w, h, need), spec.search, count, make)
end

--- Même pose sur une LISTE de décalages { { dx, dy } } déjà calculée (lot STOCKAGE : bloc des annexes, de la place la plus
--- proche à la plus lointaine). search : rayon de la passe de secours (nil ou 0 : AUCUNE passe de secours, la liste est
--- bornée par construction et ne déborde pas sur les rues du plan directeur).
function Q.place_list(surface, name, force, origin, list, search, count, make)
  local proto = game.entity_prototypes[name]
  local w, h = Pl.tiles(proto and proto.collision_box)
  local spec = { search = search }
  local placed = 0
  local function try(p)
    if not surface.can_place_entity({ name = name, position = p, force = force }) or Q.on_resource(surface, name, p) then return true end
    local r = make(p)
    if r == nil then return false end
    if r then placed = placed + 1 end
    return true
  end
  for _, o in ipairs(list) do
    if placed >= count then return placed end
    if not try({ x = Pl.snap(origin.x + o[1], w), y = Pl.snap(origin.y + o[2], h) }) then return placed end
  end
  if not spec.search or spec.search <= 0 then return placed end
  for _, o in ipairs(list) do
    if placed >= count then return placed end
    local c = { x = Pl.snap(origin.x + o[1], w), y = Pl.snap(origin.y + o[2], h) }
    local q = surface.find_non_colliding_position(name, c, spec.search, 1)
    if q and not try({ x = Pl.snap(q.x, w), y = Pl.snap(q.y, h) }) then return placed end
  end
  return placed
end

return Q
