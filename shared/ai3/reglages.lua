--[[
  Lot IA-G « le cerveau général » : les SEULES données nommées admises par la section IA3 (shared/ai3/*.lua), réunies
  ici et justifiées une par une. Le test anti-échelle (tests/iag_test.lua) relit tous les fichiers de décision de
  shared/ai3 et script/ai3/general.lua et y refuse tout nom d'objet, de bâtiment, de ressource ou de technologie du
  jeu ; ce fichier est le seul exempté. Rien ici ne dit QUOI faire ni dans quel ordre : ce sont des mots du VOCABULAIRE
  du moteur (types de prototypes, types d'effets), ou des réglages hérités de lots précédents, déclarés comme tels.

  1. R.ENTITY_ROLE : types de prototypes d'entité du moteur (API 1.1.91, `LuaEntityPrototype.type`) -> rôle dans le
     graphe du cerveau. Justification : le moteur classe ses bâtiments par TYPE ; lire les catégories de fabrication
     d'une machine, les catégories de ressources d'une foreuse ou les entrées d'un laboratoire suppose de savoir quel
     type porte quoi. Un bâtiment nouveau d'un mod (une foreuse de l'âge 9) a l'un de ces types : il est lu sans une
     ligne de plus.
  2. R.ITEM_ROLE : types de prototypes d'objet (`LuaItemPrototype.type`) -> rôle (militaire). Même justification.
  3. R.MODIFIER_ROLE : types d'effets de technologie (`TechnologyModifier.type`) -> famille qu'ils servent (armée ou
     capital). Ce sont les effets « bonus » (dégâts, cadence, vitesse des laboratoires) : leur valeur passe par les poids
     du chef.
  4. R.TURRET : la tourelle des règles « défendre d'abord » d'IA1-b2 (famille DÉFENSE, gardée telle quelle par la
     conception §3.1 et §5.1 ; déplacée ici depuis shared/ai3/projets.lua, P.TURRET, sans changement).
  5. R.MARCHE_CIBLES : cibles de stock du marché d'IA3-b (facteur de besoin des tâches d'extraction ; déplacées ici
     depuis shared/ai3/manque.lua, X.TARGET, sans changement).
  6. R.FALLBACK_KEY : ressources « clés » de l'équipe du JOUEUR (que ce lot ne touche pas) et d'une faction avant sa
     première décision de recherche : les valeurs que l'échelle et IA-V2 avaient écrites à la main (fer d'abord, le
     charbon combustible, la pierre seulement si elle manque). Une faction branchée les DÉDUIT du dépliage de ses buts
     (shared/ai3/general.lua, Gen.key_resources) ; sur les données vanilla, la déduction rend exactement ces valeurs
     (test tests/iag_test.lua §3), c'est ce qui garde les bancs d'aujourd'hui ; sur des données changées, elle rend
     autre chose (§6 du test, et la copie jetable du banc).
  7. R.BODY : le corps du personnage dont l'exécutant d'IA3-f cherche la place libre sur un trajet
     (script/ai3/exploration.lua, find_non_colliding_position ; nom déplacé, inchangé).
  Ce fichier ne contient aucune fonction.
]]

local R = {}

R.ENTITY_ROLE = {
  ["character"] = "main",
  ["assembling-machine"] = "fabrique",
  ["furnace"] = "fabrique",
  ["mining-drill"] = "foreuse",
  ["lab"] = "labo",
  ["offshore-pump"] = "pompe",
  ["boiler"] = "chauffe",
  ["generator"] = "generateur",
  ["ammo-turret"] = "militaire",
  ["electric-turret"] = "militaire",
  ["fluid-turret"] = "militaire",
  ["artillery-turret"] = "militaire",
  ["wall"] = "militaire",
  ["gate"] = "militaire",
  ["transport-belt"] = "logistique",
  ["underground-belt"] = "logistique",
  ["splitter"] = "logistique",
  ["inserter"] = "logistique",
  ["electric-pole"] = "logistique",
  ["pipe"] = "logistique",
  ["pipe-to-ground"] = "logistique",
  ["container"] = "logistique",
  ["logistic-container"] = "logistique",
  ["roboport"] = "logistique",
  ["radar"] = "logistique",
}
-- Ordre de lecture des types (le moteur rend les prototypes dans une table : l'ordre de lecture est fixé ici).
R.ENTITY_TYPES = {}
for k in pairs(R.ENTITY_ROLE) do R.ENTITY_TYPES[#R.ENTITY_TYPES + 1] = k end
table.sort(R.ENTITY_TYPES)

R.ITEM_ROLE = {
  ["ammo"] = "militaire",
  ["gun"] = "militaire",
  ["armor"] = "militaire",
  ["capsule"] = "militaire",
}

R.MODIFIER_ROLE = {
  ["ammo-damage"] = "militaire",
  ["gun-speed"] = "militaire",
  ["turret-attack"] = "militaire",
  ["artillery-range"] = "militaire",
  ["maximum-following-robots-count"] = "militaire",
  ["follower-robot-lifetime"] = "militaire",
  ["character-health-bonus"] = "militaire",
  ["laboratory-speed"] = "capital",
  ["laboratory-productivity"] = "capital",
  ["mining-drill-productivity-bonus"] = "capital",
  ["character-crafting-speed"] = "capital",
  ["character-mining-speed"] = "capital",
  ["character-inventory-slots-bonus"] = "capital",
  ["inserter-stack-size-bonus"] = "capital",
  ["stack-inserter-capacity-bonus"] = "capital",
  ["worker-robot-speed"] = "capital",
  ["worker-robot-storage"] = "capital",
}

R.TURRET = "gun-turret"

R.BODY = "character"

R.MARCHE_CIBLES = { coal = 400, stone = 200, ["iron-ore"] = 200, ["copper-ore"] = 100 }

-- Types d'avant-poste (clés de T.outposts, shared/team/config.lua) : `top` = la ressource la plus demandée, `fuel` = le
-- combustible des machines à combustion, `order` = les autres par besoin décroissant, `optional` = sans besoin au
-- départ (avant-poste seulement si son produit manque).
R.FALLBACK_KEY = { top = "iron", fuel = "coal", order = { "iron", "copper", "stone" }, optional = { stone = true } }

return R
