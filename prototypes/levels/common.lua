--[[
  Niveaux de bâtiments : génération des prototypes, partie COMMUNE (lot V2, session 6).
  Données et règles : shared/levels/config.lua. Runtime : script/levels/. Point d'entrée : prototypes/levels.lua.

  Garde de l'interface complétée au lot V2b (état partagé entier, data.raw entier, ctx.declare, messages
  avec chemin, coût mesuré : BALANCE_SHEET §12), puis à la contre-vérification de V2b (copies déclarées
  revérifiées, toutes les familles revérifiées après la dernière, icons attribué à son niveau, fichiers de
  famille chargés dans la garde, fonctions de garde appelées par des locales).

  Ce fichier calcule TOUT ce qui n'est pas visuel : noms, statistiques, objets, minage, groupes de
  remplacement rapide (F39), traductions, recette du centre, touche U. Le visuel de chaque famille vit dans
  SON fichier, prototypes/levels/<famille>.lua (un agent du lot V3 par fichier) :
    command.lua (centre de commandement), gun.lua (mitrailleuse), laser.lua (tourelle laser), wall.lua (mur),
    drill.lua (foreuse électrique), furnace.lua (four en acier), assembler.lua (machine d'assemblage 2).

  =====================================================================================================
  INTERFACE D'UN FICHIER DE FAMILLE
  =====================================================================================================
  Le fichier renvoie une table :

    return {
      dress = function(p, ctx) ... end,          -- OBLIGATOIRE
      icons = function(icons, ctx) return icons end, -- FACULTATIF (icônes de l'entité ET de l'objet)
    }

  Le fichier est chargé (require) par generate, À L'INTÉRIEUR de la garde de sa famille : son code de premier
  niveau est soumis aux mêmes règles que dress (état partagé comparé juste après le chargement, data.raw à la
  fermeture de la famille).

  dress(p, ctx) est appelée une fois par niveau généré : centre, niveaux 1 à 15 ; autres familles,
  niveaux 2 à 30 (le niveau 1 est le bâtiment vanilla, jamais modifié).
    p   : le prototype d'entité, déjà COPIÉ et chiffré (nom, statistiques, minage, groupe…). Le centre
          arrive avec l'image du coffre en acier : dress doit poser `p.picture`.
    ctx : table en LECTURE SEULE (écrire un de ses champs arrête l'étape data) :
      family    : COPIE de la famille (config : key, type, base, size, max…) ; la modifier est refusé
      level     : n (1 à 30 ; centre : 1 à 15)
      epoch     : époque du niveau (1 à 15) ; centre : epoch = level
      step      : 1 = premier niveau de l'époque (la silhouette CHANGE), 2 = second (une pièce S'AJOUTE) ;
                  le centre n'a qu'un niveau par époque (step = 1)
      epoch_key : clé de l'époque ("pioneer", "forge", "steam"… : config L.epochs)
      color     : COPIE de la couleur de l'époque { r, g, b } (interface ; teinte du visuel provisoire)
      footprint : côté de l'emprise du niveau, en tuiles (L.footprint ; lot V3-T) : 2 pour une mitrailleuse
                  des époques 1 à 3, 6 aux époques 13 à 15 ; ctx.family.size reste le côté du niveau 1
      L         : la configuration (shared/levels/config.lua), à LIRE seulement : elle est comparée EN ENTIER
                  après chaque dress (voir les règles)
      kit       : boîte à outils visuelle (ci-dessous), à lire seulement (comparée de même)
      declare   : ctx.declare(type, source, suffixe, edit) → nom : déclare un NOUVEAU prototype visuel
                  (ci-dessous) ; seule voie pour un faisceau, un reste ou une explosion propre à un niveau
  icons(icons, ctx) reçoit les icônes par défaut (icône vanilla teintée + numéro du niveau) et renvoie la
  liste à poser sur l'entité et sur l'objet.

  Règles (vérifiées par la garde : une violation arrête l'étape data avec un message qui nomme le fichier,
  le niveau quand il est connu, et le CHEMIN exact de la valeur modifiée) :
    - dress ne modifie QUE des champs graphiques ou sonores. Garde INVERSÉE : tout le prototype est comparé
      avant et après l'appel, sauf la liste blanche GRAPHIC_KEYS et les clés qui contiennent un mot visuel
      (VISUAL_WORDS : picture, animation, sprite, sound, glow, shadow, light, smoke, icon…) ; dans les champs
      de jeu, seules les sous-clés visuelles (VISUAL_SUBKEYS : source_offset, gun_center_shift…) sont libres.
      Un champ de jeu oublié de toute liste est donc protégé par défaut. Le prototype est comparé de nouveau
      après icons, après le dernier niveau de la famille et après la DERNIÈRE famille : une référence gardée
      par dress ne permet de le changer ni plus tard dans la famille, ni depuis une autre famille (le refus
      nomme le niveau modifié et les familles générées après lui).
    - Animations à durée de jeu (preparing, folding, attacking, starting_attack, ending_attack des
      tourelles) : le nombre d'images est LIBRE, la vitesse (preparing_speed…) est une clé de JEU, inchangée.
      La durée vaut 1 / vitesse ticks, quel que soit le nombre d'images ou repeat_count (doc 1.1.91 ; mesuré en
      moteur réel pour la levée au lot A1, E67 : 5 images, 1 image, 1 image × 5 lèvent toutes en 13 ticks
      à 0,08, en 63 ticks à 0,016). La règle « images / vitesse » d'avant était fausse (correction INT-GARDE).
    - État partagé en lecture seule, comparé EN ENTIER après le chargement du fichier, après CHAQUE dress et
      après CHAQUE icons (le refus nomme la fonction et le niveau fautifs) : la config L (toutes ses clés :
      tables, nombres, chaînes, et ses FONCTIONS, comparées par identité), ctx.kit (avec kit.lib et kit.Evo)
      et le style commun (prototypes/levels/style.lua). Peu importe le chemin : ctx.L,
      require("shared.levels.config"), ou une table rendue par une fonction de L (L.parse rend la vraie
      famille) : toute modification est refusée.
    - Le scénario X0 (require("shared.content.epochs"), lu par la config) est en lecture seule aussi : il est
      comparé EN ENTIER à la fermeture de chaque famille (le refus nomme la famille ; lot V2c).
    - Le fichier (chargement, dress, icons) ne modifie JAMAIS data.raw. data.raw est copié une fois avant la
      première famille ; après le dernier icons de chaque famille sont comparés, en nommant la famille : les types surveillés
      (WATCHED_TYPES : beam, ammo, projectile, artillery-projectile, explosion, corpse, rail-remnants,
      sticker, smoke-with-trigger, trivial-smoke, optimized-particle, particle-source, stream, fire, tile),
      les types des prototypes SOURCES (vanilla copié, objet ; centre : coffre en acier, roboport, radar,
      balise) et tout type RÉFÉRENCÉ par une source (un type qui contient un prototype dont le nom apparaît
      dans la source). Après la dernière famille, TOUT data.raw est comparé (le reste est refusé aussi, sans
      pouvoir nommer la famille). Ajouter un prototype (data:extend) pendant dress est aussi refusé.
    - L'EMPRISE AU SOL est une clé de JEU (lot V3-T ; Q23, Q24 ; critère D1-4 révisé) : common.lua la règle
      d'après la table de la config (L.footprint : collision_box, selection_box, et la portée des tourelles,
      L.range_bonus), et la garde la protège comme tout champ de jeu. Le fichier de famille la LIT dans
      ctx.footprint (côté du niveau, en tuiles) et dessine à cette taille ; drawing_box reste libre (visuel).
    - Nouvelles images : graphics/levels/<famille>/ (lots V3). Chemins "__factorio-overhaul__/graphics/…".

  Déclarer un prototype visuel : ctx.declare(type, source, suffixe, edit)
    type     : "beam", "corpse" ou "explosion" (DECLARABLE ; un autre type : demander à l'intégrateur) ;
    source   : nom d'un prototype EXISTANT de ce type (ex. "laser-beam") : il n'est jamais modifié ;
    suffixe  : [%w-]+ ; le nouveau prototype s'appelle "<nom du niveau>-<suffixe>" (ex. fo-lvl-laser-9-beam) ;
    edit     : function(copie) : modifie la COPIE, et seulement ses champs graphiques (même garde inversée
               que dress, plus les clés graphiques propres au type : DECLARABLE ; la copie est comparée à la
               source, nom excepté) ;
    renvoie  : le nom. dress peut alors remplacer une référence du niveau vers la source par ce nom (ex.
               p.attack_parameters.ammo_type.action.action_delivery.beam = nom) : la garde compare ce nom
               comme la source. Vers une AUTRE source, la référence reste un champ de jeu (refusé).
    La copie est comparée à la source juste après edit, puis de NOUVEAU après le dress et l'icons du niveau,
    en fin de famille et après la dernière famille : une référence à la copie gardée par edit ne permet pas
    de changer ensuite ses champs de jeu (le refus nomme le fichier, le niveau, la copie et le chemin).
    Le prototype est ajouté à data.raw à la fin de la génération (introuvable dans data.raw pendant dress).
    Deux déclarations d'un même nom sont refusées. Nom affiché : « <niveau> (visuel) » (fo-epochs.visual).

  Boîte à outils `ctx.kit` (fonctions pures sur les tables de sprites) :
    kit.provisional(p, ctx, opts)  visuel PROVISOIRE de la session 5 (teinte d'époque, socle, reflet, halo,
                                   échelle plafonnée) ; opts.foundation = false, opts.scale = false
    kit.graphic_fields(p)          main, base, scaled : listes des animations principales, des animations
                                   qui reçoivent un socle, de celles qu'on agrandit
    kit.layered(t, key)            transforme t[key] (sprite isolé) en { layers = { sprite } }
    kit.tint(anim, color)          teinte (multiplie) toutes les couches non lumineuses
    kit.scale(anim, f)             agrandit toutes les couches (échelle et décalage)
    kit.sprite_scale(ctx)          échelle provisoire du niveau : 1 → 1,10 au dernier niveau (plafonnée),
                                   × ctx.footprint / ctx.family.size quand l'emprise a grandi (lot V3-T)
    kit.sheen(anim, color, alpha)  reflet additif draw_as_glow (visible de jour)
    kit.halo(anim, color, k)       halo de nuit draw_as_light
    kit.foundation_sprite(tile, size, tint) / kit.add_foundation(anim, sprite)   socle en première couche
    kit.still(sprite, frame_x) / kit.moved(sprite, dx, dy, scale)              pièces fixes, déplacées
    kit.palette                    palette provisoire par époque (glow, foundation) : STYLE COMMUN des
                                   7 familles, dans prototypes/levels/style.lua (un seul propriétaire)
    kit.lib, kit.Evo               prototypes/lib.lua et prototypes/evolution.lua
]]

local lib = require("prototypes.lib")
local Evo = require("prototypes.evolution")
local L = require("shared.levels.config")
local Foot = require("shared.levels.footprint")
local Points = require("shared.levels.points")
local Style = require("prototypes.levels.style")
-- Scénario X0 : la config en recopie ce qu'elle lit au chargement (L.VANILLA_UNIT_SCALE, L.target) ; la garde
-- le compare EN PLUS à la fermeture de chaque famille (correction V2c : un dress qui modifiait
-- X.VANILLA_UNIT_SCALE changeait le nombre d'unités des recherches vanilla en data-final-fixes).
local X = require("shared.content.epochs")

-- Fichiers de famille : chargés par generate, chacun DANS la garde de sa famille (son code de premier niveau
-- est gardé comme dress ; correction de la contre-vérification V2b).
local VISUAL_MODULES = {
  command = "prototypes.levels.command",
  gun = "prototypes.levels.gun",
  laser = "prototypes.levels.laser",
  wall = "prototypes.levels.wall",
  drill = "prototypes.levels.drill",
  furnace = "prototypes.levels.furnace",
  assembler = "prototypes.levels.assembler",
}

local Common = {}

---------------------------------------------------------------------------------------------------
-- Statistiques (non visuel)
---------------------------------------------------------------------------------------------------
local function get_path(t, path)
  for i = 1, #path - 1 do
    t = t[path[i]]
    if type(t) ~= "table" then return nil end
  end
  return t, path[#path]
end

local function scale_energy(s, f)
  local num, unit = tostring(s):match("^([%d%.]+)(%a+)$")
  if not num then return s end
  return string.format("%.4g", tonumber(num) * f) .. unit
end

--- Applique les statistiques de la famille au niveau n.
local function apply_stats(p, family, n)
  for _, st in ipairs(family.stats) do
    local parent, key = get_path(p, st.path)
    if parent then
      local v = parent[key]
      if v == nil then v = st.default end
      if type(v) == "number" then
        local nv = L.apply_stat(st, v, n)
        if key == "inventory_size" then nv = math.floor(nv + 0.5) end
        parent[key] = nv
      elseif type(v) == "string" then
        -- Puissance « 90kW » : même formule sur le nombre.
        local num = tonumber(v:match("^([%d%.]+)"))
        if num then parent[key] = scale_energy(v, L.apply_stat(st, num, n) / num) end
      end
    end
  end
  if family.resist_step then
    p.resistances = p.resistances or {}
    local types = {}
    for dtype in pairs(family.resist_step) do types[#types + 1] = dtype end
    table.sort(types)
    for _, dtype in ipairs(types) do
      local step = family.resist_step[dtype]
      local found
      for _, r in ipairs(p.resistances) do
        if r.type == dtype then found = r end
      end
      if not found then
        found = { type = dtype, decrease = 0, percent = 0 }
        table.insert(p.resistances, found)
      end
      found.decrease = (found.decrease or 0) + step * (n - 1)
    end
    table.sort(p.resistances, function(a, b) return a.type < b.type end)
  end
end

--- Emplacements de modules du niveau n (lot MOD-1, Q-B2 du DC : 5 au niveau 1, puis +1 par niveau ; familles qui en
--- ont : L.module_slots). Icônes du mode Alt rangées sur la largeur de l'emprise (MOD-0, capture E135 : 34 icônes en
--- 6 par ligne débordaient sous un 3×3) : au plus 2 × côté − 1 par ligne (icône d'une demi-tuile), autant de lignes
--- qu'il faut.
local function apply_module_slots(p, family, n)
  local slots = L.module_slots(family, n)
  if not slots then return end
  local side = L.footprint(family, n)
  local per_row = math.max(1, 2 * side - 1)
  p.module_specification = p.module_specification or {}
  local ms = p.module_specification
  ms.module_slots = slots
  ms.module_info_max_icons_per_row = per_row
  ms.module_info_max_icon_rows = math.ceil(slots / per_row)
end

--- Emprise au sol du niveau n (lot V3-T ; table L.footprints, géométrie shared/levels/footprint.lua). Si le côté
--- diffère du côté du prototype source (niveau 1), boîtes de collision et de sélection au style vanilla (sélection
--- = le carré exact, collision = le carré réduit de 0,3 tuile de chaque côté), drawing_box mise à l'échelle si
--- la source en a une, portée des tourelles complétée de la moitié de la croissance (L.range_bonus : la portée
--- au-delà du bord reste celle de la statistique) et, correction V3-T (défaut 9), les POINTS DE JEU mesurés
--- depuis le centre (move_point ci-dessous) : raccords de tuyaux de toutes les boîtes à fluide, point de dépôt
--- de la foreuse (vector_to_place_result), rayon d'extraction (resource_searching_radius). Un niveau à
--- l'emprise du niveau 1 n'est PAS touché (chemin d'avant le lot V3-T, octet pour octet). Groupe de
--- remplacement rapide inchangé (F39) : le moteur refuse de lui-même un remplacement rapide entre deux
--- tailles, et le runtime ne le lui demande jamais.
---
--- Règle des points (côté a → côté b, centre du bâtiment = origine) :
---   - une coordonnée AU-DELÀ du bord (|v| ≥ a/2) garde son écart au bord : signe(v) × (|v| − a/2 + b/2) ;
---     un raccord de tuyau à une demi-tuile hors du 3×3 (± 2) reste à une demi-tuile hors du 6×6 (± 3,5) ;
---   - une coordonnée À L'INTÉRIEUR (le long du bord) est portée à la même proportion du côté, puis calée
---     sur le centre de tuile le plus proche du nouveau côté (centres entiers pour un côté impair, demi-entiers
---     pour un côté pair ; à égalité, le plus petit) : 0 sur un 3×3 → −0,5 sur un 6×6 (comme la foreuse à
---     charbon vanilla, 2×2, qui dépose en −0,5) ;
---   - rayon d'extraction : même débord au-delà du bord, r + (b − a) / 2 (2,49 sur un 3×3, soit 5×5 tuiles,
---     → 3,99 sur un 6×6, soit 8×8 tuiles).
-- Lot V3-T2 (correction) : la règle est dans shared/levels/points.lua (pure, partagée avec le runtime, qui en a
-- besoin pour garder les points SERVIS d'un bâtiment qui grandit), recopiée telle quelle.
local move_point = Points.move_point

--- Boîtes à fluide d'un prototype (toutes les clés connues de 1.1.91, dans un ordre fixe).
local function fluid_boxes_of(p)
  local out = {}
  for _, k in ipairs({ "fluid_box", "input_fluid_box", "output_fluid_box" }) do
    if type(p[k]) == "table" then out[#out + 1] = p[k] end
  end
  if type(p.fluid_boxes) == "table" then
    for _, fb in ipairs(p.fluid_boxes) do
      if type(fb) == "table" then out[#out + 1] = fb end
    end
  end
  local es = p.energy_source
  if type(es) == "table" and type(es.fluid_box) == "table" then out[#out + 1] = es.fluid_box end
  return out
end

local function move_fluid_boxes(p, a, b)
  for _, fb in ipairs(fluid_boxes_of(p)) do
    for _, pc in ipairs(fb.pipe_connections or {}) do
      if pc.position then pc.position = move_point(pc.position, a, b) end
      if type(pc.positions) == "table" then
        for i, q in ipairs(pc.positions) do pc.positions[i] = move_point(q, a, b) end
      end
    end
  end
end

local function apply_footprint(p, family, n)
  local side = L.footprint(family, n)
  if side == family.size then return end
  local a = family.size
  p.collision_box, p.selection_box = Foot.proto_boxes(side)
  if p.drawing_box then p.drawing_box = lib.scale_box(p.drawing_box, side / a) end
  local bonus = L.range_bonus(family, n)
  local ap = p.attack_parameters
  if bonus ~= 0 and type(ap) == "table" and type(ap.range) == "number" then ap.range = ap.range + bonus end
  move_fluid_boxes(p, a, side)
  if p.vector_to_place_result then p.vector_to_place_result = move_point(p.vector_to_place_result, a, side) end
  if type(p.resource_searching_radius) == "number" then
    p.resource_searching_radius = p.resource_searching_radius + (side - a) / 2
  end
end

--- Contrôle des points de jeu d'un prototype à l'emprise `side` (étape data, après apply_footprint ; tests) :
--- liste des problèmes (vide si tout va bien). Règles du moteur : un raccord de tuyau et le point de dépôt d'une
--- foreuse sont HORS de la boîte de collision (sinon le tuyau ne se raccorde jamais et le minerai tombe dans la
--- foreuse elle-même), un raccord est sur un centre de tuile, et la zone d'extraction couvre au moins l'emprise.
--- Le banc de l'étape data les vérifie aussi, pour toute entité du mod (tests/datastage/engine_rules.lua :
--- pipe-inside, pipe-off-center, drop-inside, drop-on-footprint) ; la zone d'extraction n'est tenue qu'ici.
local function footprint_problems(p, side)
  local out = {}
  local c = side / 2 - Foot.MARGIN
  local function outside(x, y) return math.abs(x) > c + 1e-9 or math.abs(y) > c + 1e-9 end
  local function on_center(v) return math.abs((v + side / 2) % 1 - 0.5) < 1e-9 end
  local function check_point(pt, what)
    local x, y = pt.x or pt[1] or 0, pt.y or pt[2] or 0
    if not outside(x, y) then out[#out + 1] = what .. " (" .. x .. ", " .. y .. ") dans la boîte de collision ±" .. c end
    return x, y
  end
  for _, fb in ipairs(fluid_boxes_of(p)) do
    for _, pc in ipairs(fb.pipe_connections or {}) do
      local list = pc.position and { pc.position } or pc.positions or {}
      for _, q in ipairs(list) do
        local x, y = check_point(q, "raccord de tuyau")
        if not (on_center(x) and on_center(y)) then
          out[#out + 1] = "raccord de tuyau (" .. x .. ", " .. y .. ") hors des centres de tuile"
        end
      end
    end
  end
  if p.vector_to_place_result then check_point(p.vector_to_place_result, "point de dépôt") end
  if type(p.resource_searching_radius) == "number" and p.resource_searching_radius < side / 2 - 0.01 - 1e-9 then
    out[#out + 1] = "rayon d'extraction " .. p.resource_searching_radius .. " < côté / 2 − 0,01 (" .. (side / 2 - 0.01) .. ")"
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Garde de l'interface (INVERSÉE depuis la correction du lot V2 ; STRUCTURELLE et complète depuis le lot
-- V2b). TOUT le prototype est capturé avant dress, SAUF une liste blanche de clés graphiques ou sonores :
-- une clé de jeu nouvelle ou oubliée est protégée par défaut. En plus :
--   - les vitesses d'animation des tourelles (preparing_speed…) sont des clés de JEU : la durée de
--     l'animation vaut 1 / vitesse (délai de déploiement, de repli…), le nombre d'images n'y entre pas (E67,
--     lot A1 ; correction INT-GARDE : l'ancienne règle « images / vitesse » refusait 1 image à la vitesse
--     vanilla et acceptait une levée 5 fois plus lente si les images suivaient) ;
--   - l'état partagé ENTIER (config L, boîte à outils, style commun) ne doit pas bouger ; le scénario X0 non
--     plus (comparé à la fermeture de chaque famille, lot V2c) ;
--   - data.raw ne doit pas bouger (types surveillés et référencés par famille, puis tout data.raw) ;
--   - ctx est en lecture seule (écrire un champ de ctx est une erreur ; family et color sont des copies).
-- Méthode (V2b) : COPIE profonde avant, comparaison par CONTENU après (tables : contenu, identité ignorée,
-- partages et cycles gérés ; toute autre valeur, fonctions comprises : égalité, donc identité). Le
-- résultat (refus ou non) ne dépend d'aucun ordre de parcours ; quand plusieurs valeurs ont changé, le
-- chemin signalé est le premier dans l'ordre trié des deux premiers niveaux (type, nom ; clé du prototype),
-- puis dans l'ordre de `pairs` en dessous (ordre déterministe du moteur pour une même suite d'opérations).
-- Coût mesuré (harness de l'étape data, temps ÉCOULÉ, BALANCE_SHEET §12) : la garde V2 sérialisait les
-- prototypes sources en chaînes après CHAQUE dress (1,44 à 1,99 s, médiane 1,52 s) ; celle-ci copie data.raw
-- une fois et compare par famille (0,56 à 0,78 s, médiane 0,71 s ; + 66 Mo alloués pendant generate, rien
-- de retenu). Les revérifications de la contre-vérification (icons, toutes les familles) en coûtent 0,03 à 0,06.
-- Limites connues :
--   - la garde arrête les ERREURS d'un agent, pas un contournement DÉLIBÉRÉ : la bibliothèque debug, le
--     remplacement d'une fonction globale (table.deepcopy, data.extend…) ou un écart restauré avant la
--     comparaison suivante passent. generate appelle ses fonctions de garde par des LOCALES : remplacer
--     require("prototypes.levels.common").dress (ou guard_begin, guard_end…) n'a aucun effet sur la génération ;
--   - une modification ANNULÉE avant la comparaison suivante n'est pas vue ;
--   - les métatables ne sont pas comparées (une métatable posée sur L est acceptée) ;
--   - seuls les champs de JEU des niveaux et des copies déclarées sont protégés : les champs graphiques d'un
--     autre niveau ou d'une autre famille, atteints par une référence gardée, ne le sont pas ;
--   - l'état caché de la config (upvalues de shared/levels/config.lua : table des coûts, index des noms) n'est
--     pas comparé directement : il ne change que par L.rebuild(), qui le recalcule à partir des données
--     comparées (et l'étape data ne lit pas les coûts) ; L.rebuild() suivi d'une restauration passe.
---------------------------------------------------------------------------------------------------
local function set(list)
  local t = {}
  for _, k in ipairs(list) do t[k] = true end
  return t
end

-- Clés de premier niveau graphiques ou sonores, exactes.
local GRAPHIC_KEYS = set({
  "picture", "pictures", "animation", "animations", "idle_animation", "base_picture", "base_patch",
  "folded_animation", "preparing_animation", "prepared_animation", "prepared_alternative_animation",
  "attacking_animation", "folding_animation", "starting_attack_animation", "ending_attack_animation",
  "energy_glow_animation", "graphics_set", "wet_mining_graphics_set", "working_visualisations",
  "water_reflection", "integration_patch", "integration_patch_render_layer", "drawing_box",
  "radius_visualisation_picture", "circuit_connector_sprites", "circuit_wire_connection_point",
  "circuit_wire_connection_points", "visual_merge_group", "status_colors", "corpse", "dying_explosion",
  "glow_light_intensity", "energy_glow_animation_flicker_strength", "turret_base_has_direction",
  "base_render_layer", "gun_animation_render_layer", "gun_animation_secondary_draw_order",
  "base_picture_render_layer", "base_picture_secondary_draw_order", "always_draw_idle_animation",
  "match_animation_speed_to_activity", "default_recipe_tint", "shift_animation_waypoints",
  "shift_animation_waypoint_stop_duration", "shift_animation_transition_duration", "map_color",
  "friendly_map_color", "enemy_map_color", "scale_info_icons", "show_recipe_icon", "show_recipe_icon_on_map",
  "entity_info_icon_shift", "alert_icon_shift", "alert_icon_scale", "scale_entity_info_icon",
  "draw_entity_info_icon_background", "icon", "icons", "icon_size", "icon_mipmaps",
})
-- Mots qui marquent une clé graphique ou sonore, à tous les niveaux (« pipe_picture », « smoke »,
-- « wall_diode_red », « module_info_icon_shift »…).
local VISUAL_WORDS = { "picture", "cover", "smoke", "light", "animation", "sprite", "sound", "glow", "shadow",
  "visualis", "visualiz", "reflection", "diode", "icon" }
-- Sous-clés graphiques exactes dans les champs de jeu : origine du faisceau, de la douille, du canon.
local VISUAL_SUBKEYS = set({ "source_offset", "projectile_center", "projectile_creation_distance",
  "projectile_orientation_offset", "gun_center_shift", "gun_barrel_length", "shell_particle" })
-- Animation → sa vitesse : la durée 1 / vitesse est un délai de jeu (E67). Les vitesses ne sont dans AUCUNE
-- liste graphique : ce sont des clés de jeu, comparées comme les autres ; les animations, elles, sont libres.
local TIMED_ANIMATIONS = {
  { "preparing_animation", "preparing_speed" }, { "folding_animation", "folding_speed" },
  { "attacking_animation", "attacking_speed" }, { "starting_attack_animation", "starting_attack_speed" },
  { "ending_attack_animation", "ending_attack_speed" },
}

local function has_visual_word(k)
  if type(k) ~= "string" then return false end
  for _, w in ipairs(VISUAL_WORDS) do
    if k:find(w, 1, true) then return true end
  end
  return false
end

local function nested_visual(k)
  return VISUAL_SUBKEYS[k] or has_visual_word(k)
end

--- Clé de premier niveau graphique ? extra : clés graphiques propres à un type (DECLARABLE), ou nil.
local function graphic_top(k, extra)
  if type(k) ~= "string" then return false end
  return (GRAPHIC_KEYS[k] or has_visual_word(k) or (extra ~= nil and extra[k])) and true or false
end

--- Ordre total des clés : par type, puis valeur (nombres et chaînes : ordre natif).
local function key_lt(a, b)
  local ta, tb = type(a), type(b)
  if ta ~= tb then return ta < tb end
  if ta == "number" or ta == "string" then return a < b end
  return tostring(a) < tostring(b)
end

--- Clés de `a` et de `b` (sauf skip), sans doublon, triées.
local function key_union(a, b, skip)
  local keys, seen = {}, {}
  for _, t in ipairs({ a, b }) do
    if type(t) == "table" then
      for k in pairs(t) do
        if not seen[k] and not (skip and skip(k)) then
          seen[k] = true
          keys[#keys + 1] = k
        end
      end
    end
  end
  table.sort(keys, key_lt)
  return keys
end

--- Copie profonde. skip(k) : clés ignorées (à tous les niveaux sous la racine passée). Clés et valeurs non
--- tables reprises telles quelles (une fonction garde son identité). memo : partages et cycles.
local function deep_copy(v, skip, memo)
  if type(v) ~= "table" then return v end
  local c = memo[v]
  if c then return c end
  c = {}
  memo[v] = c
  for k, x in pairs(v) do
    if not (skip and skip(k)) then
      if type(x) == "table" then c[k] = deep_copy(x, skip, memo) else c[k] = x end
    end
  end
  return c
end

--- Compare la COPIE `a` à la valeur VIVANTE `b` (mêmes clés ignorées que la copie). alias : chaîne → chaîne,
--- appliqué aux valeurs de `b` (un prototype déclaré par ctx.declare est comparé comme sa source).
--- Renvoie nil si égal ; sinon `path` complété du chemin de l'écart et sa nature.
local function diff(a, b, skip, alias, memo, path)
  if alias ~= nil and type(b) == "string" and alias[b] ~= nil then b = alias[b] end
  if a == b then return nil end
  if type(a) ~= "table" or type(b) ~= "table" then
    if a ~= a and b ~= b then return nil end -- NaN des deux côtés
    return path, "valeur modifiée"
  end
  if memo[a] == b then return nil end
  memo[a] = b
  for k, x in pairs(a) do
    path[#path + 1] = k
    local y = b[k]
    if y == nil then return path, "clé retirée" end
    local p, why = diff(x, y, skip, alias, memo, path)
    if p then return p, why end
    path[#path] = nil
  end
  for k in pairs(b) do
    if a[k] == nil and not (skip and skip(k)) then
      path[#path + 1] = k
      return path, "clé ajoutée"
    end
  end
  return nil
end

--- Version rapide de diff (sans clé ignorée, sans alias, sans chemin) : true si `a` et `b` diffèrent. Sert
--- au cas courant (aucun écart) ; le chemin n'est cherché, avec diff_sorted, que s'il y a un écart.
local function differs(a, b, memo)
  if a == b then return false end
  if type(a) ~= "table" or type(b) ~= "table" then return not (a ~= a and b ~= b) end
  if memo[a] == b then return false end
  memo[a] = b
  for k, x in pairs(a) do
    local y = b[k]
    if y == nil or (x ~= y and differs(x, y, memo)) then return true end
  end
  for k in pairs(b) do
    if a[k] == nil then return true end
  end
  return false
end

--- Comme diff, mais les clés de PREMIER niveau sont parcourues triées (chemin signalé déterministe).
local function diff_sorted(a, b, skip_top, skip, alias)
  local memo = {}
  for _, k in ipairs(key_union(a, b, skip_top)) do
    local x, y = a[k], b[k]
    if x == nil then return { k }, "clé ajoutée" end
    if y == nil then return { k }, "clé retirée" end
    local p, why = diff(x, y, skip, alias, memo, { k })
    if p then return p, why end
  end
  return nil
end

--- Texte d'un chemin : racine.cle[2]["clé-avec-tiret"].
local function path_text(root, path)
  local parts = { root }
  for _, k in ipairs(path) do
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
      parts[#parts + 1] = (#parts == 1 and root == "") and k or ("." .. k)
    elseif type(k) == "string" then
      parts[#parts + 1] = string.format("[%q]", k)
    else
      parts[#parts + 1] = "[" .. tostring(k) .. "]"
    end
  end
  return table.concat(parts)
end

--- Durées de jeu des animations des tourelles, en ticks (texte, 6 décimales) : 1 / vitesse (défaut 1 dans
--- prototype-api.json 1.1.91), QUEL QUE SOIT le nombre d'images, repeat_count compris (doc 1.1.91 : « 1 ÷
--- preparing_speed = duration of the preparing_animation » ; E67, lot A1, mesuré pour la levée). Les vitesses
--- étant des clés de jeu comparées par la garde, ce contrôle double la comparaison et donne un motif lisible
--- (« durée de … ») ; il ne regarde JAMAIS les images. Prudence : la PRÉSENCE de l'animation compte (« sans
--- animation ») : l'effet en jeu d'une animation retirée ou ajoutée n'a pas été mesuré, donc refusé.
local function durations(p)
  local d = {}
  for _, t in ipairs(TIMED_ANIMATIONS) do
    local v = p[t[2]]
    if v == nil then v = 1 end
    if p[t[1]] == nil then
      d[t[1]] = "sans animation"
    else
      d[t[1]] = type(v) == "number" and string.format("%.6f", 1 / v) or tostring(v)
    end
  end
  return d
end

--- Partie JEU d'un prototype : copie de tout sauf les clés graphiques (premier niveau : GRAPHIC_KEYS, mots
--- visuels, `extra` ; plus bas : VISUAL_SUBKEYS et mots visuels), et durées (1 / vitesse).
local function game_snapshot(p, extra)
  local memo, part = {}, {}
  for k, v in pairs(p) do
    if not graphic_top(k, extra) then part[k] = deep_copy(v, nested_visual, memo) end
  end
  return { part = part, durations = durations(p), extra = extra }
end

--- Écart entre la partie jeu `snap` et le prototype p : texte du chemin et nature, ou nil. ignore : clés de
--- premier niveau à ne pas comparer (prototype déclaré : son nom). alias : voir diff.
local function game_diff(snap, p, alias, ignore)
  local extra = snap.extra
  local path, why = diff_sorted(snap.part, p, function(k) return graphic_top(k, extra) or (ignore ~= nil and ignore[k] ~= nil) end,
    nested_visual, alias)
  if path then return path_text("", path), why end
  local now = durations(p)
  for _, t in ipairs(TIMED_ANIMATIONS) do
    local a, b = snap.durations[t[1]], now[t[1]]
    if a ~= b then
      if a == "sans animation" or b == "sans animation" then
        return "durée de " .. t[1], "animation " .. (b == "sans animation" and "retirée" or "ajoutée") .. " (effet en jeu non mesuré)"
      end
      return "durée de " .. t[1], "1 / " .. t[2] .. " modifiée"
    end
  end
  return nil
end

local function check_snapshot(snap, p, where, alias, who)
  local text, why = game_diff(snap, p, alias)
  if text then
    error("prototypes/levels/" .. where .. " : " .. (who or "dress") .. " a modifié le champ de jeu « " .. text
      .. " » (" .. why .. ") ; interface : seuls les champs graphiques")
  end
end

---------------------------------------------------------------------------------------------------
-- Boîte à outils visuelle (pour les fichiers de famille)
---------------------------------------------------------------------------------------------------
local function is_sprite(t)
  return type(t) == "table" and (t.filename or t.filenames or t.stripes) ~= nil
end

local kit = { lib = lib, Evo = Evo }

function kit.layered(t, key)
  local v = t[key]
  if is_sprite(v) then t[key] = { layers = { v } } end
end

function kit.tint(anim, color) if anim then lib.tint_sprites(anim, color) end end
function kit.scale(anim, f) if anim then lib.scale_sprites(anim, f) end end
function kit.sheen(anim, color, alpha) if anim then return Evo.sheen_layers(anim, color, alpha) end return 0 end
function kit.halo(anim, color, k) if anim then return Evo.light_layers(anim, color, k) end return 0 end

--- Échelle provisoire : +10 % au plus, atteinte au dernier niveau ; lot V3-T : × le rapport des emprises
--- (côté du niveau / côté du niveau 1) quand l'emprise a grandi, pour que le sprite actuel couvre sa nouvelle
--- emprise au lieu de paraître minuscule (visuel PROVISOIRE jusqu'aux sprites V3 : un agrandissement d'échelle
--- n'ajoute aucun détail, ce que D1-4 exige à terme).
function kit.sprite_scale(ctx)
  local f = ctx.family
  local ratio = (ctx.footprint or f.size) / f.size
  if f.max <= 1 then return ratio end
  return (1 + 0.10 * (ctx.level - 1) / (f.max - 1)) * ratio
end

--- Points d'origine des tirs (bouche du canon, douilles, source du faisceau) mis à l'échelle de l'emprise :
--- sous-clés graphiques des paramètres d'attaque (VISUAL_SUBKEYS), libres pour dress. Sans effet si le
--- rapport vaut 1.
function kit.scale_muzzle(p, f)
  local ap = p.attack_parameters
  if f == 1 or type(ap) ~= "table" then return end
  local function vec(v)
    if type(v) ~= "table" then return v end
    return { (v[1] or v.x or 0) * f, (v[2] or v.y or 0) * f }
  end
  if type(ap.projectile_creation_distance) == "number" then ap.projectile_creation_distance = ap.projectile_creation_distance * f end
  if ap.projectile_center then ap.projectile_center = vec(ap.projectile_center) end
  if ap.source_offset then ap.source_offset = vec(ap.source_offset) end
  local sp = ap.shell_particle
  if type(sp) == "table" then
    if sp.center then sp.center = vec(sp.center) end
    if type(sp.creation_distance) == "number" then sp.creation_distance = sp.creation_distance * f end
  end
end

local TURRET_HEAD = { "folded_animation", "preparing_animation", "prepared_animation", "attacking_animation", "folding_animation" }

--- Champs graphiques par type : « main » reçoit teinte, reflet, halo ; « base » le socle ; « scaled » l'échelle.
function kit.graphic_fields(p)
  local t = p.type
  if t == "ammo-turret" or t == "electric-turret" then
    local main = { p.base_picture }
    for _, f in ipairs(TURRET_HEAD) do if p[f] then main[#main + 1] = p[f] end end
    local scaled = { p.base_picture, p.energy_glow_animation }
    for _, f in ipairs(TURRET_HEAD) do if p[f] then scaled[#scaled + 1] = p[f] end end
    return main, { p.base_picture }, scaled
  elseif t == "wall" then
    return { p.pictures }, {}, {}
  elseif t == "mining-drill" then
    local main, base = {}, {}
    for _, gs in ipairs({ p.graphics_set, p.wet_mining_graphics_set }) do
      if gs and gs.animation then
        main[#main + 1] = gs.animation
        base[#base + 1] = gs.animation
      end
    end
    return main, base, { p.graphics_set, p.wet_mining_graphics_set }
  elseif t == "furnace" or t == "assembling-machine" then
    return { p.animation }, { p.animation }, { p.animation, p.working_visualisations }
  elseif t == "container" then
    return { p.picture }, { p.picture }, { p.picture }
  end
  error("type non géré : " .. t)
end

local FOUNDATION_TILE = {
  ["stone-path"] = "stone-path",
  ["concrete"] = "concrete",
  ["refined-concrete"] = "refined-concrete",
  ["refined-hazard-concrete"] = "refined-hazard-concrete-left",
}

--- Socle : texture de sol vanilla découpée à l'emprise (size × size tuiles).
function kit.foundation_sprite(tile_name, size, tint)
  local tile = data.raw.tile[FOUNDATION_TILE[tile_name] or tile_name]
  local v = tile.variants
  local src
  -- Côté (tuiles) d'une variante de la texture : 8 pour le fond des bétons (images de 256 px de haut, relevé
  -- du 22/10 sur data/base/graphics/terrain), 4 pour la variante 4×4 du pavé (128 px).
  local cap = 8
  if v.material_background then
    src = v.material_background
  else
    -- Pavé : variante 4×4 de la texture principale (bords intérieurs nets).
    for _, m in ipairs(v.main) do
      if m.size == 4 then src = m end
    end
    cap = 4
  end
  -- Lot V3-T : une emprise plus grande que la variante est couverte en agrandissant la découpe (sinon le
  -- rectangle sortirait de l'image).
  local tiles = math.min(size, cap)
  local px = 32 * tiles
  local k = size / tiles
  local s = { filename = src.picture, width = px, height = px, x = 0, y = 0, priority = "low", tint = tint }
  if k ~= 1 then s.scale = k end
  if src.hr_version then
    s.hr_version = {
      filename = src.hr_version.picture, width = 2 * px, height = 2 * px, x = 0, y = 0, scale = 0.5 * k,
      priority = "low", tint = tint,
    }
  end
  return s
end

--- Insère le socle en PREMIÈRE couche (dessous) de chaque liste de couches de `anim`, en épousant le
--- nombre d'images et d'orientations des couches voisines.
function kit.add_foundation(anim, sprite, seen)
  seen = seen or {}
  if type(anim) ~= "table" or seen[anim] then return end
  seen[anim] = true
  if type(anim.layers) == "table" then
    local first = anim.layers[1]
    local f = table.deepcopy(sprite)
    local function fit(dst, ref)
      if not ref then return end
      local frames = (ref.frame_count or 1) * (ref.repeat_count or 1)
      if frames > 1 then dst.repeat_count = frames end
      if ref.direction_count and ref.direction_count > 1 then
        dst.direction_count = ref.direction_count
        dst.line_length = ref.direction_count
      elseif ref.direction_count then
        dst.direction_count = 1
      end
    end
    fit(f, first)
    if f.hr_version then fit(f.hr_version, first and (first.hr_version or first)) end
    table.insert(anim.layers, 1, f)
    return
  end
  if is_sprite(anim) then return end
  local keys = {}
  for k, v in pairs(anim) do
    if type(v) == "table" and k ~= "hr_version" then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do kit.add_foundation(anim[k], sprite, seen) end
end

--- Pièce fixe : première image d'un sprite animé (ou celle de la colonne frame_x).
function kit.still(sp, frame_x)
  local s = table.deepcopy(sp)
  local function fix(t)
    t.frame_count, t.repeat_count, t.animation_speed, t.line_length, t.direction_count = nil, nil, nil, nil, nil
    t.x, t.y = frame_x or 0, 0
    t.apply_projection = nil
    t.priority = t.priority or "medium"
    if t.hr_version then fix(t.hr_version) end
  end
  fix(s)
  return s
end

--- Pièce déplacée (en tuiles) et mise à l'échelle.
function kit.moved(sp, dx, dy, scale)
  local s = table.deepcopy(sp)
  local function mv(t)
    local sh = t.shift or { 0, 0 }
    local x, y = sh[1] or sh.x or 0, sh[2] or sh.y or 0
    t.shift = { x * (scale or 1) + dx, y * (scale or 1) + dy }
    if scale then t.scale = (t.scale or 1) * scale end
    if t.hr_version then mv(t.hr_version) end
  end
  mv(s)
  return s
end

--- Palette PROVISOIRE par époque : style commun des 7 familles, dans prototypes/levels/style.lua (un seul
--- propriétaire). Lecture seule.
kit.palette = Style.palette

--- Visuel PROVISOIRE (aucun progrès visuel revendiqué : c'est le schéma rejeté en E25, ramené à 15 époques
--- et à une échelle plafonnée). Teinte de l'époque, reflet au 2e niveau d'une époque, lueur (époque 5+),
--- halo de nuit (époque 6+), socle (niveau 2+).
function kit.provisional(p, ctx, opts)
  opts = opts or {}
  if p.type == "furnace" or p.type == "assembling-machine" then kit.layered(p, "animation") end
  if p.type == "container" then kit.layered(p, "picture") end
  if p.type == "ammo-turret" or p.type == "electric-turret" then kit.layered(p, "base_picture") end
  local main, base, scaled = kit.graphic_fields(p)
  local e, step = ctx.epoch, ctx.step
  -- 1. Taille (avant le socle, qui reste à l'emprise exacte).
  if opts.scale ~= false then
    local f = kit.sprite_scale(ctx)
    for _, a in ipairs(scaled) do kit.scale(a, f) end
    kit.scale_muzzle(p, (ctx.footprint or ctx.family.size) / ctx.family.size)
  end
  -- 2. Teinte de l'époque.
  if e >= 2 then
    for _, a in ipairs(main) do kit.tint(a, ctx.color) end
  end
  -- 3. Reflet (lueur additive) : époque 5+, et un léger reflet au 2e niveau de chaque époque.
  local glow = kit.palette.glow[e]
  local alpha = 0
  if glow then alpha = math.min(0.30, 0.05 + 0.017 * (e - 5)) end
  if step == 2 then alpha = alpha + 0.04 end
  if alpha > 0 then
    local c = glow or ctx.color
    for _, a in ipairs(main) do kit.sheen(a, c, alpha) end
  end
  -- 4. Halo de nuit : époque 6+.
  if e >= 6 then
    local k = math.min(0.65, 0.15 + 0.03 * (e - 6) + 0.05 * (step - 1))
    for _, a in ipairs(main) do kit.halo(a, glow or ctx.color, k) end
  end
  -- 5. Socle (niveau 2+).
  local fspec = kit.palette.foundation[e]
  if opts.foundation ~= false and fspec and ctx.level >= 2 then
    local sprite = kit.foundation_sprite(fspec.tile, ctx.footprint or ctx.family.size, fspec.tint)
    for _, a in ipairs(base) do kit.add_foundation(a, sprite) end
  end
end

---------------------------------------------------------------------------------------------------
-- Icônes par défaut : icône vanilla teintée de la couleur d'époque + numéro du niveau.
---------------------------------------------------------------------------------------------------
local function default_icons(proto_or_item, ctx)
  local icon, size, mip = proto_or_item.icon, proto_or_item.icon_size, proto_or_item.icon_mipmaps
  if not icon and proto_or_item.icons then
    local i1 = proto_or_item.icons[1]
    icon, size, mip = i1.icon, i1.icon_size or proto_or_item.icon_size, i1.icon_mipmaps
  end
  local tint = ctx.epoch >= 2 and ctx.color or nil
  return lib.tier_icons(icon, size or 64, tint, ctx.level, mip)
end

local function family_icons(visual, proto_or_item, ctx)
  local icons = default_icons(proto_or_item, ctx)
  if visual.icons then icons = visual.icons(icons, ctx) end
  return icons
end

---------------------------------------------------------------------------------------------------
-- Centre de commandement : squelette NON visuel (emprise et sons du roboport, coffre de 48 cases).
-- L'image vient de prototypes/levels/command.lua.
---------------------------------------------------------------------------------------------------
local CC = L.by_key.command

local function command_center_skeleton(n)
  local c = lib.copy("container", "steel-chest")
  local rp = data.raw.roboport.roboport
  c.name = L.name(CC, n)
  c.collision_box = table.deepcopy(rp.collision_box)
  c.selection_box = table.deepcopy(rp.selection_box)
  c.max_health = L.CC_HEALTH
  c.inventory_size = L.CC_INVENTORY
  c.corpse = rp.corpse
  c.dying_explosion = rp.dying_explosion
  c.damaged_trigger_effect = table.deepcopy(rp.damaged_trigger_effect)
  c.resistances = table.deepcopy(rp.resistances)
  c.open_sound = table.deepcopy(rp.open_sound)
  c.close_sound = table.deepcopy(rp.close_sound)
  c.vehicle_impact_sound = table.deepcopy(rp.vehicle_impact_sound)
  c.circuit_wire_connection_point, c.circuit_connector_sprites, c.circuit_wire_max_distance = nil, nil, nil
  c.fast_replaceable_group = "fo-lvl-command"
  c.next_upgrade = nil
  c.icon, c.icon_size, c.icon_mipmaps = rp.icon, rp.icon_size, rp.icon_mipmaps
  return c
end

---------------------------------------------------------------------------------------------------
-- Génération
---------------------------------------------------------------------------------------------------
-- Les tourelles vanilla n'ont pas de groupe de remplacement : sans groupe, le moteur refuse de
-- remplacer un niveau par le suivant (F39).
local BASE_GROUP = { gun = "fo-lvl-gun", laser = "fo-lvl-laser" }

local function level_name(family)
  if family.key == "command" then return { "entity-name.fo-command-center" } end
  return { "entity-name." .. family.base }
end

---------------------------------------------------------------------------------------------------
-- Garde : état partagé, data.raw, prototypes déclarés (V2b)
---------------------------------------------------------------------------------------------------
-- Prototypes SOURCES lus pour fabriquer les niveaux d'une famille : dress ne doit jamais les modifier.
local SOURCES = {
  command = { { "container", "steel-chest" }, { "roboport", "roboport" }, { "radar", "radar" },
              { "beacon", "beacon" }, { "item", "roboport" } },
}
local function sources_of(family)
  return SOURCES[family.key] or { { family.type, family.base }, { "item", family.base } }
end

-- État partagé, comparé EN ENTIER (toutes les clés, fonctions comprises) : la config, la boîte à outils
-- (kit.lib et kit.Evo compris) et le style commun. Ordre fixe (chemin signalé déterministe).
local SHARED = { { "L", L }, { "kit", kit }, { "style", Style } }

local function shared_copy()
  local memo, out = {}, {}
  for i, r in ipairs(SHARED) do out[i] = deep_copy(r[2], nil, memo) end
  return out
end

local function shared_check(copy, where, who)
  for i, r in ipairs(SHARED) do
    local path, why
    if differs(copy[i], r[2], {}) then
      path, why = diff_sorted(copy[i], r[2])
      if not path then path, why = {}, "écart non localisé" end
    end
    if path then
      error("prototypes/levels/" .. where .. " : " .. who .. " a modifié l'état partagé " .. path_text(r[1], path)
        .. " (" .. why .. ") ; la config, ctx.kit et le style commun sont en lecture seule")
    end
  end
end

-- Scénario X0 (shared/content/epochs.lua), lu par la config au chargement : en lecture seule lui aussi.
-- Comparé à la FERMETURE de chaque famille seulement (guard_end : 16 000 nœuds environ, 23 fois la config ;
-- après chaque dress, la comparaison coûterait plusieurs dixièmes de seconde à l'étape data) : le refus nomme
-- la famille et ses niveaux, pas le niveau exact. generate prend UNE copie pour les 7 familles.
local function scenario_copy() return deep_copy(X, nil, {}) end

local function scenario_check(copy, where, who)
  if not differs(copy, X, {}) then return end
  local path, why = diff_sorted(copy, X)
  if not path then path, why = {}, "écart non localisé" end
  error("prototypes/levels/" .. where .. " : " .. who .. " a modifié le scénario X0 " .. path_text("X", path)
    .. " (" .. why .. ") ; shared/content/epochs.lua est en lecture seule (la config en recopie au chargement ce"
    .. " qu'elle lit)")
end

-- Types de data.raw comparés après CHAQUE famille (en plus des types des sources et des types référencés) :
-- ceux qu'un visuel de bâtiment est tenté de toucher (faisceau, munition, projectile, explosion, reste,
-- autocollant, fumée, particule, jet, feu, tuile du socle). Un type absent de data.raw est ignoré.
local WATCHED_TYPES = { "ammo", "artillery-projectile", "beam", "corpse", "explosion", "fire", "optimized-particle",
  "particle-source", "projectile", "rail-remnants", "smoke-with-trigger", "sticker", "stream", "tile", "trivial-smoke" }

local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, key_lt)
  return keys
end

--- Types de data.raw qui contiennent un prototype dont le NOM apparaît comme valeur (à toute profondeur)
--- dans une source de la famille : restes, explosions, faisceau, catégories, objet, recette…
local function referenced_types(family)
  local strings, seen = {}, {}
  local function collect(v)
    if type(v) == "string" then
      strings[v] = true
    elseif type(v) == "table" and not seen[v] then
      seen[v] = true
      for _, x in pairs(v) do collect(x) end
    end
  end
  for _, src in ipairs(sources_of(family)) do collect(data.raw[src[1]] and data.raw[src[1]][src[2]]) end
  local out = {}
  for _, t in ipairs(sorted_keys(data.raw)) do
    local list = data.raw[t]
    if type(list) == "table" then
      -- Test d'appartenance : le résultat ne dépend pas de l'ordre de parcours.
      for s in pairs(strings) do
        if list[s] ~= nil then
          out[#out + 1] = t
          break
        end
      end
    end
  end
  return out
end

local function watched_types(family)
  local seen, out = {}, {}
  local function add(t)
    if not seen[t] and data.raw[t] ~= nil then
      seen[t] = true
      out[#out + 1] = t
    end
  end
  for _, t in ipairs(WATCHED_TYPES) do add(t) end
  for _, src in ipairs(sources_of(family)) do add(src[1]) end
  for _, t in ipairs(referenced_types(family)) do add(t) end
  table.sort(out)
  return out
end

--- Copie profonde de data.raw entier (une fois par génération).
local function raw_copy()
  local memo, c = {}, {}
  for t, list in pairs(data.raw) do c[t] = deep_copy(list, nil, memo) end
  return c
end

--- Premier écart entre la copie et data.raw sur `types` (nil : tous les types). Renvoie chemin (type, nom,
--- clés…), nature, type, nom ; ou nil.
local function raw_diff(copy, types)
  types = types or key_union(copy, data.raw)
  local memo = {}
  for _, t in ipairs(types) do
    local a, b = copy[t] or {}, data.raw[t] or {}
    local path, why
    if differs(a, b, memo) then
      path, why = diff_sorted(a, b)
      if not path then path, why = {}, "écart non localisé" end
    end
    if path then
      if #path == 1 then
        if why == "clé ajoutée" then why = "prototype ajouté" elseif why == "clé retirée" then why = "prototype retiré" end
      end
      table.insert(path, 1, t)
      return path, why, t, path[2]
    end
  end
  return nil
end

local function raw_error(g, where, path, why, t, name)
  local text = path_text("data.raw", path)
  local head = where and ("prototypes/levels/" .. where .. " : a modifié ")
    or "prototypes/levels : un fichier de famille (chargement, dress ou icons) a modifié, hors des types comparés par famille, "
  if g then
    for _, s in ipairs(g.sources) do
      if s[1] == t and s[2] == name then
        error(head .. "le prototype source " .. text .. " (" .. why .. ") ; interface : dress et icons ne modifient jamais data.raw")
      end
    end
  end
  error(head .. text .. " (" .. why .. ") : prototype partagé de data.raw, interdit ; un visuel propre à un niveau se déclare par ctx.declare (en-tête de prototypes/levels/common.lua)")
end

-- Types qu'on peut DÉCLARER (ctx.declare) et leurs clés graphiques propres (en plus de GRAPHIC_KEYS et des
-- mots visuels). Tout autre champ (dégâts, action, durée de vie, intervalle…) reste celui de la source.
local DECLARABLE = {
  beam = set({ "head", "tail", "body", "start", "ending", "random_end_animation_rotation",
    "transparent_start_end_animations" }),
  corpse = set({ "splash", "splash_speed", "splash_render_layer", "ground_patch", "ground_patch_higher",
    "ground_patch_render_layer", "ground_patch_fade_in_delay", "ground_patch_fade_in_speed",
    "ground_patch_fade_out_duration", "ground_patch_fade_out_start", "use_tile_color_for_ground_patch_tint",
    "direction_shuffle", "shuffle_directions_at_frame", "final_render_layer" }),
  explosion = set({ "rotate", "correct_rotation", "scale", "scale_animation_speed", "scale_deviation", "scale_end",
    "scale_in_duration", "scale_increment_per_tick", "scale_initial", "scale_initial_deviation", "scale_out_duration",
    "fade_in_duration", "fade_out_duration", "height", "render_layer" }),
}

local function level_where(family, n) return family.key .. ".lua (niveau " .. n .. ")" end

-- Clés de premier niveau d'une copie déclarée qui diffèrent de la source par construction.
local DECLARED_IGNORE = { name = true, localised_name = true }

--- Compare une copie déclarée (ctx.declare) à sa source, partie jeu (nom et nom affiché exceptés), puis
--- vérifie son nom et son nom affiché (posés par declare). where : fichier et niveau où l'écart est constaté ;
--- who : l'appel fautif.
local function check_declared(d, where, alias, who)
  local text, why = game_diff(d.snap, d.copy, alias, DECLARED_IGNORE)
  if not text and d.copy.name ~= d.name then text, why = "name", "valeur modifiée" end
  if not text and differs(d.lname, d.copy.localised_name, {}) then text, why = "localised_name", "valeur modifiée" end
  if text then
    error("prototypes/levels/" .. where .. " : " .. who .. " a modifié la copie déclarée « " .. d.name .. " » ("
      .. d.ptype .. ", déclarée au niveau " .. d.n .. " depuis " .. d.source .. ") après ctx.declare : champ de jeu « "
      .. text .. " » (" .. why .. ") ; seuls ses champs graphiques peuvent changer")
  end
end

--- ctx.declare (interface en tête du fichier).
local function declare(g, family, n, ptype, source, suffix, edit)
  local where = level_where(family, n)
  local function fail(msg) error("prototypes/levels/" .. where .. " : ctx.declare : " .. msg, 0) end
  local extra = type(ptype) == "string" and DECLARABLE[ptype] or nil
  if not extra then fail("type « " .. tostring(ptype) .. " » non pris en charge (beam, corpse, explosion)") end
  local list = data.raw[ptype]
  local src = list and type(source) == "string" and list[source] or nil
  if not src then fail("source introuvable : " .. path_text("data.raw", { ptype, tostring(source) })) end
  if type(suffix) ~= "string" or not suffix:match("^[%w%-]+$") then
    fail("suffixe invalide « " .. tostring(suffix) .. " » (lettres, chiffres, tirets)")
  end
  local name = L.name(family, n) .. "-" .. suffix
  if list[name] ~= nil or g.alias[name] ~= nil then fail("nom déjà pris : " .. name) end
  local snap = game_snapshot(src, extra)
  local copy = table.deepcopy(src)
  copy.name = name
  if edit ~= nil then edit(copy) end
  local text, why = game_diff(snap, copy, g.alias, { name = true })
  if text then
    fail("la copie de " .. path_text("data.raw", { ptype, source }) .. " a un champ de jeu modifié « " .. text .. " » ("
      .. why .. ") ; seuls ses champs graphiques peuvent changer")
  end
  if copy.name ~= name then fail("la copie doit garder son nom " .. name) end
  copy.localised_name = { "fo-epochs.visual", { "fo-levels.name", level_name(family), tostring(n) } }
  g.alias[name] = source
  g.declared[#g.declared + 1] = copy
  -- Instantané de jeu de la SOURCE gardé avec la copie : elle est comparée de nouveau après le dress et
  -- l'icons du niveau, en fin de famille et après la dernière famille (check_declared).
  g.declared_info[#g.declared_info + 1] = { copy = copy, snap = snap, name = name, ptype = ptype, source = source, n = n,
    lname = deep_copy(copy.localised_name, nil, {}) }
  return name
end

--- Contexte passé aux fichiers de famille : en LECTURE SEULE (écrire un champ est une erreur). family et
--- color sont des COPIES (les modifier n'a d'effet que sur ce niveau, et la garde le refuse pour family).
--- g : garde de la famille (ctx.declare en a besoin). Renvoie ctx et sa table interne (pour la garde).
local function context(family, n, g)
  local e = L.epoch_of(family, n)
  local ep = L.epochs[e]
  local inner = {
    family = table.deepcopy(family), level = n, epoch = e, step = L.step_of(family, n), epoch_key = ep.key,
    color = table.deepcopy(ep.color), L = L, kit = kit, footprint = L.footprint(family, n),
  }
  if g then
    inner.declare = function(ptype, source, suffix, edit) return declare(g, family, n, ptype, source, suffix, edit) end
  end
  local ctx = setmetatable({}, {
    __index = inner,
    __newindex = function(_, k) error("prototypes/levels : ctx est en lecture seule (champ « " .. tostring(k) .. " »)", 2) end,
  })
  return ctx, inner
end

--- Ouvre la garde d'une famille, AVANT son premier dress (generate : avant le chargement de son fichier).
--- raw : copie de data.raw déjà prise (generate : une seule copie pour les 7 familles) ; nil : prise ici, et
--- TOUT data.raw sera comparé à la fermeture. scenario : copie du scénario X0 (generate : une seule) ; nil :
--- prise ici.
local function guard_begin(family, raw, scenario)
  return {
    file = family.key .. ".lua", sources = sources_of(family), raw = raw or raw_copy(), own_raw = raw == nil,
    watched = watched_types(family), shared = shared_copy(), family_copy = deep_copy(family, nil, {}),
    scenario = scenario or scenario_copy(),
    levels = {}, declared = {}, declared_info = {}, alias = {}, loaded = false,
  }
end

--- Ferme la garde d'une famille, APRÈS son dernier icons : prototypes des niveaux et copies déclarées (de
--- nouveau), état partagé, data.raw (types surveillés, des sources et référencés ; tout data.raw si la copie
--- est propre à la garde). Renvoie les prototypes déclarés par ctx.declare (à ajouter à data.raw).
local function guard_end(g)
  local lv = g.levels
  local what = g.loaded and "chargement du fichier, dress ou icons" or "dress ou icons"
  local where = g.file .. " (" .. what .. ")"
  if #lv == 1 then
    where = g.file .. " (niveau " .. lv[1].n .. ", " .. what .. ")"
  elseif #lv > 1 then
    where = g.file .. " (niveaux " .. lv[1].n .. " à " .. lv[#lv].n .. ", " .. what .. ")"
  end
  local later = "un appel ultérieur (dress ou icons)"
  for _, l in ipairs(lv) do check_snapshot(l.snap, l.p, l.where, g.alias, later) end
  for _, d in ipairs(g.declared_info) do check_declared(d, g.file .. " (niveau " .. d.n .. ")", g.alias, later) end
  shared_check(g.shared, where, "un appel")
  scenario_check(g.scenario, where, "un appel")
  local path, why, t, name = raw_diff(g.raw, g.watched)
  if path then raw_error(g, where, path, why, t, name) end
  if g.own_raw then
    path, why, t, name = raw_diff(g.raw, nil)
    if path then raw_error(g, where, path, why, t, name) end
  end
  return g.declared
end

--- Appelle visual.dress(p, ctx) sous la garde de l'interface (voir plus haut). g : garde de la famille
--- (guard_begin) ; nil : garde complète autour de ce seul appel (data.raw entier compris).
--- Une violation arrête l'étape data avec un message qui nomme le fichier, le niveau et le chemin modifié.
--- Renvoie ctx et l'instantané de jeu de p.
local function guarded_dress(visual, p, family, n, g)
  local own = g == nil
  g = g or guard_begin(family)
  local where = level_where(family, n)
  local ctx, inner = context(family, n, g)
  local snap = game_snapshot(p)
  local d_from = #g.declared_info + 1
  visual.dress(p, ctx)
  check_snapshot(snap, p, where, g.alias)
  for i = d_from, #g.declared_info do check_declared(g.declared_info[i], where, g.alias, "dress") end
  local path, why = diff_sorted(g.family_copy, inner.family)
  if path then
    error("prototypes/levels/" .. where .. " : dress a modifié " .. path_text("ctx.family", path) .. " (" .. why
      .. ") ; ctx.family est en lecture seule")
  end
  shared_check(g.shared, where, "dress")
  g.levels[#g.levels + 1] = { n = n, p = p, snap = snap, where = where, d_from = d_from }
  if own then guard_end(g) end
  return ctx, snap
end

--- Après l'icons d'un niveau (icônes de l'entité ET de l'objet) : le prototype du niveau, les copies déclarées
--- à ce niveau et l'état partagé sont comparés de nouveau, et un écart est attribué à CET icons (et non au
--- dress du niveau suivant). Le niveau n doit être le dernier passé par guarded_dress dans cette garde.
local function icons_check(g, family, n)
  local l = g.levels[#g.levels]
  assert(l and l.n == n, "prototypes/levels : icons_check hors de son niveau")
  local where = level_where(family, n)
  check_snapshot(l.snap, l.p, where, g.alias, "icons")
  for i = l.d_from, #g.declared_info do check_declared(g.declared_info[i], where, g.alias, "icons") end
  shared_check(g.shared, where, "icons")
end

--- Après la DERNIÈRE famille, avant data:extend : prototypes des niveaux et copies déclarées de TOUTES les
--- familles, de nouveau. Une référence gardée par une famille ne permet pas de changer une famille déjà
--- fermée : le refus nomme le niveau modifié et les familles générées après la sienne (les seules possibles).
local function final_check(guards)
  for i, g in ipairs(guards) do
    local after = {}
    for j = i + 1, #guards do after[#after + 1] = guards[j].file end
    local who = #after > 0
      and ("un appel d'une famille générée après (" .. table.concat(after, ", ") .. " : chargement, dress ou icons)")
      or "un appel ultérieur"
    for _, l in ipairs(g.levels) do check_snapshot(l.snap, l.p, l.where, g.alias, who) end
    for _, d in ipairs(g.declared_info) do check_declared(d, g.file .. " (niveau " .. d.n .. ")", g.alias, who) end
  end
end

--- Charge le fichier de famille DANS sa garde (déjà ouverte) : son code de premier niveau est gardé comme dress
--- (état partagé ici ; data.raw à la fermeture de la famille, guard_end).
local function load_visual(family, g)
  local module = VISUAL_MODULES[family.key]
  assert(module, "prototypes/levels : aucun fichier de famille pour « " .. tostring(family.key) .. " »")
  g.loaded = true
  local visual = require(module)
  shared_check(g.shared, g.file .. " (chargement du fichier)", "le code de premier niveau")
  assert(type(visual) == "table" and type(visual.dress) == "function",
    "prototypes/levels/" .. g.file .. " : fonction dress manquante")
  return visual
end

function Common.generate()
  -- Correction V3-T (défaut 3) : table des emprises vérifiée AVANT toute génération (niveau 1 = côté vanilla,
  -- jamais de rétrécissement, forme de la ligne) ; une ligne fautive arrête le chargement avec son motif.
  local ferrs = L.footprint_errors()
  if #ferrs > 0 then
    error("[FO-LEVELS] table des emprises refusée (shared/levels/config.lua, L.footprints) : " .. table.concat(ferrs, " ; "))
  end
  local out = {}
  for _, key in ipairs({ "gun", "laser" }) do
    local f = L.by_key[key]
    data.raw[f.type][f.base].fast_replaceable_group = BASE_GROUP[key]
  end

  -- Garde : data.raw copié UNE fois, après les groupes de remplacement posés ci-dessus (seule écriture
  -- légitime de ce fichier dans data.raw avant data:extend). Les fonctions de garde sont appelées par des
  -- LOCALES (guard_begin, guarded_dress, icons_check, guard_end, final_check) : un fichier de famille qui
  -- remplacerait Common.dress n'aurait aucun effet ici.
  local raw = raw_copy()
  local scenario = scenario_copy()
  local guards = {}
  for _, family in ipairs(L.families) do
    local guard = guard_begin(family, raw, scenario)
    guards[#guards + 1] = guard
    local visual = load_visual(family, guard)
    for n = 1, family.max do
      local name = L.name(family, n)
      local p
      if family.key == "command" then
        p = command_center_skeleton(n)
        apply_stats(p, family, n)
        apply_footprint(p, family, n)
      elseif n >= 2 then
        p = lib.copy(family.type, family.base)
        p.name = name
        p.next_upgrade = nil
        p.fast_replaceable_group = BASE_GROUP[family.key] or p.fast_replaceable_group
        apply_stats(p, family, n)
        apply_footprint(p, family, n)
        apply_module_slots(p, family, n)
      end
      -- Correction V3-T (défaut 9) : points de jeu d'un niveau agrandi hors de sa boîte de collision.
      if p and L.footprint(family, n) ~= family.size then
        local probs = footprint_problems(p, L.footprint(family, n))
        if #probs > 0 then
          error("[FO-LEVELS] " .. name .. " (emprise " .. L.footprint(family, n) .. "×" .. L.footprint(family, n)
            .. ") : " .. table.concat(probs, " ; "))
        end
      end
      if p then
        local e = L.epoch_of(family, n)
        local ep = L.epochs[e]
        -- Paramètres en CHAÎNES (F43) : le chargeur refuse un nombre dans une chaîne localisée de prototype.
        p.localised_name = { "fo-levels.name", level_name(family), tostring(n) }
        if family.key == "command" then
          -- Le centre énonce la règle : plafond des bâtiments (2 × son niveau) et, s'il n'est pas au maximum,
          -- la condition de son passage (Q16 : un bâtiment de chaque famille possédée au niveau visé).
          if n < family.max then
            p.localised_description = { "fo-epochs.desc-cc", tostring(n), tostring(e), { "fo-epochs.name-" .. ep.key },
              tostring(L.building_cap(n)), tostring(L.cc_condition_level(n)), tostring(n + 1) }
          else
            p.localised_description = { "fo-epochs.desc-cc-max", tostring(n), tostring(e), { "fo-epochs.name-" .. ep.key },
              tostring(L.building_cap(n)) }
          end
        else
          p.localised_description = { "fo-epochs.desc", tostring(n), tostring(e), { "fo-epochs.name-" .. ep.key } }
        end
        p.minable = { mining_time = (p.minable and p.minable.mining_time) or 0.5, result = name }
        p.placeable_by = nil
        if family.key == "command" then p.flags = { "placeable-player", "player-creation" } end

        -- Visuel : fichier de la famille, sous garde.
        local dctx = guarded_dress(visual, p, family, n, guard)
        lib.set_icons(p, family_icons(visual, p, dctx))
        out[#out + 1] = p

        local item
        local base_item_name = family.base
        if family.key == "command" then
          item = lib.copy("item", "roboport")
          item.subgroup = "storage"
          item.stack_size = 1
        else
          item = lib.copy("item", base_item_name)
        end
        item.name = name
        item.place_result = name
        item.localised_name = p.localised_name
        item.localised_description = p.localised_description
        if family.key == "command" then
          item.order = "a[items]-z[fo-command-center]-" .. string.format("%02d", n)
        else
          item.order = (data.raw.item[base_item_name] and data.raw.item[base_item_name].order or "z") .. "-lvl" .. string.format("%02d", n)
        end
        lib.set_icons(item, family_icons(visual, item, dctx))
        out[#out + 1] = item
        -- icons ne reçoit pas p, mais une référence gardée par dress le pourrait : p, les copies déclarées à ce
        -- niveau et l'état partagé sont comparés de nouveau, au nom de cet icons.
        icons_check(guard, family, n)
      end
    end
    -- Fin de la famille : prototypes des niveaux, copies déclarées, état partagé, data.raw (types surveillés
    -- et référencés).
    for _, d in ipairs(guard_end(guard)) do out[#out + 1] = d end
  end
  -- Après la dernière famille : les niveaux et copies déclarées de TOUTES les familles (une famille suivante
  -- ne change pas une famille fermée), puis tout data.raw (une modification hors des types comparés par
  -- famille est refusée aussi).
  final_check(guards)
  local path, why, t, pname = raw_diff(raw, nil)
  if path then raw_error(nil, nil, path, why, t, pname) end

  -- Recette du centre de commandement niveau 1 (disponible dès le départ, comme l'hôtel de ville).
  out[#out + 1] = lib.recipe("fo-command-center",
    { { "iron-chest", 4 }, { "iron-gear-wheel", 20 }, { "electronic-circuit", 10 }, { "stone-brick", 20 } },
    "fo-command-center", 1, 5, { enabled = true })

  -- Raccourci d'amélioration (touche U).
  out[#out + 1] = { type = "custom-input", name = "fo-level-up", key_sequence = "U", consuming = "none", order = "a" }

  data:extend(out)
end

-- Exports pour les tests hors jeu (tests/levels_test.lua). generate ne les relit JAMAIS (voir plus haut).
Common.context = context
Common.guard_begin = guard_begin
Common.guard_end = guard_end
Common.dress = guarded_dress
Common.icons_check = icons_check
Common.final_check = final_check
Common.kit = kit
Common.game_snapshot = game_snapshot
Common.apply_footprint = apply_footprint
Common.footprint_problems = footprint_problems
Common.move_point = move_point
return Common
