--[[
  Niveaux de bâtiments « façon Clash of Clans » en 15 ÉPOQUES (lot V2, session 6).
  Pur Lua : données et règles, testables hors jeu ; lues par l'étape data (prototypes/levels/) et le
  runtime (script/levels/). Chiffres commentés : BALANCE_SHEET §12 (tableaux générés par
  `lua5.2 tests/levels_test.lua --tables`).

  Décisions du Directeur Créatif (OBJECTIFS.md F1, Q6 et Q7, 21/10, 18 h 07) :
  - 15 époques = 15 niveaux du CENTRE DE COMMANDEMENT (l'hôtel de ville) : le niveau du centre EST l'époque.
  - Les 6 autres familles ont 30 niveaux : 2 par époque. Niveau maximal d'un bâtiment = 2 × niveau du centre.
    Le 1er niveau d'une époque change la silhouette, le 2e ajoute une pièce (visuel : lots V3).
  - Ouvriers (chantiers simultanés) : 1 (centre 1-3), 2 (4-6), 3 (7-9), 4 (10-12), 5 (13-15).

  Règles du jeu (inchangées depuis la session 5, E24) :
  - Le niveau 1 est le bâtiment vanilla (ou le centre de commandement de base) ; les niveaux suivants sont
    des prototypes à part, posables et minables (un bâtiment ramassé garde son niveau).
  - Un seul centre par force ; sans centre, rien ne s'améliore.
  - Une amélioration coûte des objets (stock du centre, puis inventaire du joueur) et dure un temps ; le
    bâtiment est HORS SERVICE pendant le chantier. Les murs s'améliorent instantanément, rangée entière.

  Courbe de coûts PAR ÉPOQUE (BALANCE_SHEET §12 : « la croissance se fait par époque (nouveau matériau
  requis), pas par exposant ») :
  - chaque époque a SON matériau (monnaie d'époque, OBJECTIFS §6). Une amélioration faite pendant l'époque
    e se paie avec le matériau de l'époque e (60 % de la valeur d'époque) et celui de l'époque e-1 (40 %) ;
    à l'époque 2, l'époque 1 n'ayant pas de matériau, l'acier paie 100 % ; le matériau de l'époque est
    toujours exigé (au moins 1) ;
  - le panier de base de la famille (fer, cuivre, pierre…) croît LINÉAIREMENT ;
  - la valeur d'époque suit une table PAR ÉPOQUE (L.epochs[e].value_mult) ; les quantités restent bornées
    parce que le matériau change à chaque époque : la valeur monte, le nombre d'objets non ;
  - PLACE : un chantier tient dans la moitié du coffre du centre qui le paie (L.cost_slots, testé), avec
    les vraies tailles de pile (L.stack_size).
  Compatibilité 0.3.0 : les noms fo-command-center et fo-lvl-<famille>-<n> gardent leur sens (même famille,
  même niveau) ; les statistiques des niveaux 1 à 10 sont celles de 0.3.0, sauf les PV et résistances des
  murs (BALANCE_SHEET §12).
]]

local L = {}

L.EPOCHS = 15
L.MAX = 30            -- niveau maximal des 6 familles (2 niveaux par époque)
L.CC_MAX = 15         -- niveau maximal du centre de commandement (= nombre d'époques)
L.MAX_BUILDERS = 5
L.LEGACY_MAX = 10     -- 0.3.0 : 10 niveaux par famille (compatibilité des sauvegardes)
L.PREFIX = "fo-lvl-"
L.CC_HEALTH = 3000    -- centre niveau 1 : PV
L.CC_INVENTORY = 48   -- centre niveau 1 : cases du coffre (+ 16 par niveau, stats ci-dessous)

---------------------------------------------------------------------------------------------------
-- Les 15 époques (OBJECTIFS.md §6, validées par Q7). `color` : couleur d'interface (célébration) et
-- teinte du visuel PROVISOIRE. Multiplicateurs par époque :
--   value_mult   : valeur (unités de matière brute) payée en matériaux d'époque, relative à l'époque 2 ;
--   time_mult    : durée des chantiers des 6 familles, relative à l'époque 1 ;
--   cc_time_mult : durée du chantier du centre PAYÉ pendant cette époque (celui qui ouvre la suivante).
-- Ces tables SONT la courbe : on la règle époque par époque. Elle est GÉOMÉTRIQUE dans les faits (valeur
-- ≈ × 1,7 par époque à partir de l'époque 7, durée ≈ × 1,2), compensée par la production de l'usine
-- (≈ × 1,46 par époque, L.target) : c'est le nombre d'OBJETS qui ne croît pas, puisque la monnaie change.
---------------------------------------------------------------------------------------------------
L.epochs = {
  { key = "pioneer",        color = { r = 1.00, g = 1.00, b = 1.00 }, value_mult = 0, time_mult = 1, cc_time_mult = 1 },
  { key = "forge",          color = { r = 0.80, g = 0.88, b = 1.00 }, value_mult = 1, time_mult = 1.25, cc_time_mult = 2 },
  { key = "steam",          color = { r = 1.00, g = 0.66, b = 0.50 }, value_mult = 1.1, time_mult = 1.4, cc_time_mult = 3 },
  { key = "oil",            color = { r = 0.95, g = 0.84, b = 0.50 }, value_mult = 1.25, time_mult = 1.55, cc_time_mult = 5 },
  { key = "volcano",        color = { r = 0.62, g = 0.55, b = 0.62 }, value_mult = 5, time_mult = 1.75, cc_time_mult = 8 },
  { key = "electricity",    color = { r = 0.62, g = 0.85, b = 1.00 }, value_mult = 9.1, time_mult = 1.95, cc_time_mult = 12 },
  { key = "crystal",        color = { r = 0.82, g = 0.62, b = 1.00 }, value_mult = 18.5, time_mult = 3.2, cc_time_mult = 16 },
  { key = "swamp",          color = { r = 0.66, g = 0.92, b = 0.55 }, value_mult = 32, time_mult = 3.6, cc_time_mult = 20 },
  { key = "atom",           color = { r = 0.72, g = 1.00, b = 0.62 }, value_mult = 54, time_mult = 4.1, cc_time_mult = 25 },
  { key = "hightech",       color = { r = 0.88, g = 0.95, b = 1.00 }, value_mult = 93.5, time_mult = 6.8, cc_time_mult = 30 },
  { key = "titanium",       color = { r = 0.95, g = 0.95, b = 0.98 }, value_mult = 160, time_mult = 7.6, cc_time_mult = 36 },
  { key = "superconductor", color = { r = 0.58, g = 0.80, b = 1.00 }, value_mult = 275, time_mult = 8.6, cc_time_mult = 42 },
  { key = "fusion",         color = { r = 1.00, g = 0.70, b = 0.90 }, value_mult = 490, time_mult = 13, cc_time_mult = 50 },
  { key = "orbit",          color = { r = 1.00, g = 0.86, b = 0.42 }, value_mult = 810, time_mult = 15.5, cc_time_mult = 60 },
  { key = "legend",         color = { r = 1.00, g = 0.94, b = 0.74 }, value_mult = 1460, time_mult = 18.5, cc_time_mult = 60 },
}

---------------------------------------------------------------------------------------------------
-- Table d'INDIRECTION « matériau d'époque → objet ».
--   want        : le matériau voulu (OBJECTIFS §6) ;
--   item        : l'objet qui EXISTE aujourd'hui en jeu et sert de monnaie ;
--   provisional : true si `item` est un REMPLAÇANT existant, en attendant le matériau voulu (lot X0) ;
--   want_item   : nom proposé pour l'objet voulu (à aligner sur le lot X0) ;
--   value       : valeur de `item` en unités de matière brute (1 = une plaque de fer) ; elle convertit une
--                 valeur en quantité. Quand le lot X0 livre le matériau voulu, l'intégrateur remplace
--                 `item` et `value` ICI SEULEMENT : les quantités de tous les niveaux suivent.
-- L'époque 1 (Pionnier) n'a pas de matériau propre : le panier de base de chaque famille la paie.
-- Ordre de déblocage (arbre vanilla + mod) croissant d'une époque à l'autre ; époque 15 : il faut avoir
-- lancé une fusée (pack de science spatiale).
-- PLACE (correction V2) : le remplaçant de l'époque 13 était le combustible nucléaire, qui s'empile par 1 :
-- le centre 15 demandait 366 cases pour un coffre de 256, chantier impossible en jeu. L'uranium 235 (pile
-- de 100, même porte : l'enrichissement de Kovarex) le remplace. Contrainte pour le lot X0 : un matériau
-- d'époque s'empile par L.MIN_MATERIAL_STACK (50) au moins.
---------------------------------------------------------------------------------------------------
L.epoch_materials = {
  [2] = { key = "steel", want = "acier", item = "steel-plate", value = 5 },
  [3] = { key = "engine", want = "moteur (mécanique de l'ère vapeur)", item = "engine-unit", value = 9 },
  [4] = { key = "plastic", want = "plastique", item = "plastic-bar", value = 3 },
  [5] = { key = "tungsten", want = "plaque de tungstène", item = "fo-tungsten-plate", value = 4 },
  [6] = { key = "battery", want = "batterie", item = "battery", value = 9 },
  [7] = { key = "crystal", want = "cristal de résonance", item = "fo-resonance-crystal", value = 3 },
  -- Baril généré par le jeu de base pour chaque fluide (data-updates de base) : un objet réel.
  [8] = { key = "methane", want = "méthane (baril)", item = "fo-methane-barrel", value = 10 },
  [9] = { key = "uranium", want = "uranium", item = "uranium-238", value = 14 },
  [10] = { key = "processor", want = "processeur", item = "processing-unit", value = 75 },
  [11] = { key = "titanium", want = "plaque de titane", want_item = "fo-titanium-plate",
           item = "low-density-structure", provisional = true, value = 45 },
  -- Moteur électrique : moteur 9 + 2 circuits 5 + 15 lubrifiant 1,5 = 15,5.
  [12] = { key = "superconductor", want = "supraconducteur (terres rares)", want_item = "fo-superconductor",
           item = "electric-engine-unit", provisional = true, value = 16 },
  -- Uranium 235 : Kovarex consomme 3 uranium 238 (14) par uranium 235, plus le temps de centrifugeuse.
  [13] = { key = "helium3", want = "hélium-3", want_item = "fo-helium-3",
           item = "uranium-235", provisional = true, value = 45 },
  [14] = { key = "meteorite", want = "fragment de météorite", want_item = "fo-meteorite",
           item = "rocket-control-unit", provisional = true, value = 150 },
  [15] = { key = "exotic", want = "matière exotique", want_item = "fo-exotic-matter",
           item = "space-science-pack", provisional = true, value = 250 },
}

--- Part de la valeur d'époque payée avec le matériau de l'époque (le reste : matériau de l'époque précédente).
L.MAIN_SHARE = 0.6
--- Le 2e niveau d'une époque coûte 25 % de plus que le 1er, et son chantier dure 10 % de plus (la durée
--- reste ainsi strictement croissante : time_mult croît de plus de 10 % d'une époque à la suivante).
L.SECOND_LEVEL_FACTOR = 1.25
L.SECOND_LEVEL_TIME_FACTOR = 1.1

--- Valeur des objets des paniers de base (unités de matière brute : 1 = une plaque de fer ; 10 unités
--- de fluide = 1). Approximations d'après les recettes vanilla, détaillées dans BALANCE_SHEET §12.
--- Un objet qui est AUSSI un matériau d'époque (acier, batterie) prend la valeur de L.epoch_materials, et
--- seulement elle : une seule source, sinon raw_cost et cost_value divergeraient sans bruit (testé).
L.item_value = {
  ["iron-plate"] = 1, ["copper-plate"] = 1, ["stone-brick"] = 2, ["iron-gear-wheel"] = 2,
  ["electronic-circuit"] = 2.5,
}
for e = 1, L.EPOCHS do
  local m = L.epoch_materials[e]
  if m then L.item_value[m.item] = m.value end
end

--- Taille de pile des objets de coût : MIROIR de l'étape data 1.1.91 (relevé le 21/10 par
--- `tests/datastage/harness.lua --dump-final item/<nom>`, tool/space-science-pack ; vérifié en moteur réel
--- par content_test avec game.item_prototypes). Sert à la règle de place (L.cost_slots).
L.stack_size = {
  ["iron-plate"] = 100, ["copper-plate"] = 100, ["stone-brick"] = 100, ["iron-gear-wheel"] = 100,
  ["electronic-circuit"] = 200, ["steel-plate"] = 100, ["battery"] = 200, ["engine-unit"] = 50,
  ["plastic-bar"] = 100, ["fo-tungsten-plate"] = 100, ["fo-resonance-crystal"] = 50, ["fo-methane-barrel"] = 10,
  ["uranium-238"] = 100, ["processing-unit"] = 100, ["low-density-structure"] = 10,
  ["electric-engine-unit"] = 50, ["uranium-235"] = 100, ["rocket-control-unit"] = 10,
  ["space-science-pack"] = 2000,
}
--- Un chantier tient dans cette part du coffre du centre qui le paie (le reste : l'usine continue de le
--- remplir, et le joueur garde son inventaire).
L.MAX_SLOT_SHARE = 0.5
--- Pile minimale exigée d'un matériau d'époque À VENIR (lot X0 : fo-titanium-plate, fo-superconductor,
--- fo-helium-3, fo-meteorite, fo-exotic-matter). Les remplaçants d'aujourd'hui en dessous (baril de
--- méthane, structure légère, unité de contrôle de fusée : 10) tiennent la règle de place, testée.
L.MIN_MATERIAL_STACK = 50

---------------------------------------------------------------------------------------------------
-- Familles
--   max         : niveau maximal (15 pour le centre, 30 pour les autres) ;
--   stats       : { chemin, op, k } appliqué au prototype du niveau 1 :
--                 "mul" : v × (1 + k·(n-1))     "add" : v + k·(n-1)
--                 knee, k2 : au-delà du niveau `knee`, la pente devient k2 (dégressif) ;
--                 hidden : statistique absente du panneau ; label : clé de locale du panneau
--   base_cost   : panier de base (époque 1) ; quantité × (1 + base_growth·(n-2)) : croissance LINÉAIRE ;
--   epoch_value : valeur payée en matériaux d'époque au 1er niveau de l'époque 2 (× value_mult) ;
--   main_share  : part du matériau de l'époque (défaut L.MAIN_SHARE ; murs : 1, sans matériau précédent) ;
--   time0       : durée de référence en secondes (× time_mult de l'époque, × 1,1 au 2e niveau) ;
--                 centre : × cc_time_mult de l'époque qui paie le chantier.
---------------------------------------------------------------------------------------------------
L.families = {
  {
    key = "command", type = "container", base = "fo-command-center", size = 4, max = 15,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.20 },
      { path = { "inventory_size" }, op = "add", k = 16 },
    },
    base_cost = { { "iron-plate", 260 }, { "copper-plate", 130 }, { "stone-brick", 130 }, { "electronic-circuit", 50 } },
    base_growth = 0.15, epoch_value = 150, time0 = 60,
  },
  {
    -- Dégâts : + 8 % par niveau jusqu'au 10 (0.3.0), puis + 2 % (dégressif) : au niveau 30, × 2,12, sous la
    -- tourelle lourde du mod (dégâts 1,5 × cadence 1,5 = × 2,25 en DPS). Testé : DPS ≤ 1,1 × la lourde.
    key = "gun", type = "ammo-turret", base = "gun-turret", size = 2, max = 30,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "attack_parameters", "damage_modifier" }, op = "mul", k = 0.08, knee = 10, k2 = 0.02, default = 1 },
      { path = { "attack_parameters", "range" }, op = "add", k = 0.25 },
      { path = { "rotation_speed" }, op = "mul", k = 0.05 },
    },
    base_cost = { { "iron-plate", 6 }, { "iron-gear-wheel", 3 }, { "copper-plate", 3 } },
    base_growth = 0.15, epoch_value = 12, time0 = 8,
  },
  {
    -- Mêmes dégâts dégressifs (× 4,24 au niveau 30 contre 4 pour la tourelle laser lourde) ; l'énergie par
    -- tir (et le tampon, qui doit la contenir) croît de 4 % par niveau : × 2,16 au niveau 30, les dégâts par
    -- joule restent ceux du niveau 1 (la lourde : × 2,5 d'énergie pour × 2 de dégâts).
    key = "laser", type = "electric-turret", base = "laser-turret", size = 2, max = 30,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "attack_parameters", "damage_modifier" }, op = "mul", k = 0.08, knee = 10, k2 = 0.02, default = 1 },
      { path = { "attack_parameters", "range" }, op = "add", k = 0.25 },
      { path = { "rotation_speed" }, op = "mul", k = 0.05 },
      { path = { "attack_parameters", "ammo_type", "energy_consumption" }, op = "mul", k = 0.04,
        label = "fo-epochs.stat-energy_consumption" },
      { path = { "energy_source", "buffer_capacity" }, op = "mul", k = 0.04, hidden = true },
    },
    base_cost = { { "steel-plate", 3 }, { "electronic-circuit", 3 }, { "battery", 2 } },
    base_growth = 0.15, epoch_value = 20, time0 = 12,
  },
  {
    key = "wall", type = "wall", base = "stone-wall", size = 1, max = 30, instant = true,
    stats = {
      -- 0.3.0 : × 1,30^(n-1) (× 2 000 au niveau 30 : explosion). Désormais linéaire : 350 → 5 425 PV.
      { path = { "max_health" }, op = "mul", k = 0.50 },
    },
    -- Résistances : réduction fixe physique et explosion + 0,5 par niveau (en plus de la vanilla).
    resist_step = { explosion = 0.5, physical = 0.5 },
    base_cost = { { "stone-brick", 3 } },
    base_growth = 0.15, epoch_value = 2, main_share = 1, time0 = 0,
  },
  {
    key = "drill", type = "mining-drill", base = "electric-mining-drill", size = 3, max = 30,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "mining_speed" }, op = "mul", k = 0.10 },
      { path = { "energy_usage" }, op = "mul", k = 0.07 },
    },
    base_cost = { { "iron-plate", 6 }, { "iron-gear-wheel", 3 }, { "electronic-circuit", 2 } },
    base_growth = 0.15, epoch_value = 7, time0 = 6,
  },
  {
    key = "furnace", type = "furnace", base = "steel-furnace", size = 2, max = 30,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "crafting_speed" }, op = "mul", k = 0.08 },
      { path = { "energy_usage" }, op = "mul", k = 0.06 },
    },
    base_cost = { { "steel-plate", 2 }, { "stone-brick", 3 } },
    base_growth = 0.15, epoch_value = 6, time0 = 5,
  },
  {
    key = "assembler", type = "assembling-machine", base = "assembling-machine-2", size = 3, max = 30,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "crafting_speed" }, op = "mul", k = 0.08 },
      { path = { "energy_usage" }, op = "mul", k = 0.06 },
    },
    base_cost = { { "iron-plate", 6 }, { "iron-gear-wheel", 3 }, { "electronic-circuit", 3 } },
    base_growth = 0.15, epoch_value = 7, time0 = 6,
  },
}

L.by_key = {}
for i, f in ipairs(L.families) do
  f.index = i
  L.by_key[f.key] = f
end

---------------------------------------------------------------------------------------------------
-- Époques et niveaux
---------------------------------------------------------------------------------------------------
--- Niveau maximal d'une famille.
function L.max_of(family) return family.max end

--- Époque à laquelle APPARTIENT le niveau n (visuel, panneau) : centre → n ; familles → ⌈n/2⌉.
function L.epoch_of(family, n)
  if family.key == "command" then return n end
  return math.floor((n + 1) / 2)
end

--- Rang du niveau dans son époque : 1 (premier : nouvelle silhouette) ou 2 (second : une pièce de plus).
--- Le centre n'a qu'un niveau par époque (rang 1).
function L.step_of(family, n)
  if family.key == "command" then return 1 end
  return (n % 2 == 1) and 1 or 2
end

--- Époque dont le MATÉRIAU paie l'amélioration vers le niveau n : l'époque pendant laquelle on la fait.
--- Familles : l'époque du niveau n. Centre : l'époque qu'il quitte (n - 1) ; passer au centre n ouvre
--- l'époque n, payée avec la monnaie de l'époque n - 1.
function L.pay_epoch(family, n)
  if family.key == "command" then return n - 1 end
  return L.epoch_of(family, n)
end

--- Niveau du centre requis pour le niveau n d'une famille (le centre lui-même : 0).
function L.required_cc(family, n)
  if family.key == "command" then return 0 end
  return math.floor((n + 1) / 2)
end

---------------------------------------------------------------------------------------------------
-- Noms
---------------------------------------------------------------------------------------------------
function L.name(family, n)
  if n == 1 then return family.base end
  return L.PREFIX .. family.key .. "-" .. n
end

local lookup = {}
for _, f in ipairs(L.families) do
  for n = 1, f.max do lookup[L.name(f, n)] = { family = f, level = n } end
end

--- Famille et niveau d'un nom d'entité ou d'objet, ou nil.
function L.parse(name)
  local r = lookup[name]
  if r then return r.family, r.level end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Règles
---------------------------------------------------------------------------------------------------
--- Valeur d'une statistique au niveau n à partir de la valeur du niveau 1.
function L.apply_stat(stat, v1, n)
  local x = stat.k * (n - 1)
  if stat.knee and n > stat.knee then x = stat.k * (stat.knee - 1) + stat.k2 * (n - stat.knee) end
  if stat.op == "mul" then return v1 * (1 + x) end
  if stat.op == "add" then return v1 + x end
  error("op inconnue " .. tostring(stat.op))
end

--- Arrondi lisible : entier sous 20, multiple de 5 sous 100, de 10 au-delà (au moins 1). Au-dessus de 20,
--- l'écart entre les deux niveaux d'une époque (× 1,25) dépasse le pas d'arrondi ; en dessous, la règle de
--- monotonie de L.rebuild garantit qu'un niveau coûte toujours plus que le précédent.
local function round_nice(x)
  if x < 20 then return math.max(1, math.floor(x + 0.5)) end
  if x < 100 then return math.floor(x / 5 + 0.5) * 5 end
  return math.floor(x / 10 + 0.5) * 10
end

--- Valeur payée en matériaux d'époque pour le niveau n (0 à l'époque 1).
function L.epoch_value(family, n)
  local v = family.epoch_value * L.epochs[L.pay_epoch(family, n)].value_mult
  if L.step_of(family, n) == 2 then v = v * L.SECOND_LEVEL_FACTOR end
  return v
end

--- Valeur d'un coût (unités de matière brute), d'après L.item_value.
function L.cost_value(cost)
  local v = 0
  for _, c in ipairs(cost) do v = v + c[2] * assert(L.item_value[c[1]], "valeur inconnue : " .. c[1]) end
  return v
end

--- Coût brut du niveau n : panier de base (linéaire), matériau de l'époque, matériau de l'époque précédente.
--- Renvoie la liste ordonnée et l'index du matériau de l'époque dans la liste (ou nil).
local function raw_cost(family, n)
  local acc, order = {}, {}
  local function add(item, q)
    if not acc[item] then order[#order + 1] = item; acc[item] = 0 end
    acc[item] = acc[item] + q
  end
  local growth = 1 + family.base_growth * (n - 2)
  for _, b in ipairs(family.base_cost) do add(b[1], round_nice(b[2] * growth)) end
  local e = L.pay_epoch(family, n)
  local v = L.epoch_value(family, n)
  local main = L.epoch_materials[e]
  if main and v > 0 then
    local prev = L.epoch_materials[e - 1]
    -- Sans matériau à l'époque précédente (époque 2 : l'époque 1 n'en a pas), le matériau de l'époque paie
    -- toute la valeur d'époque.
    local share = prev and (family.main_share or L.MAIN_SHARE) or 1
    -- Le matériau de l'époque est TOUJOURS exigé (au moins 1) : c'est lui qui marque l'époque.
    add(main.item, round_nice(v * share / main.value))
    if prev and share < 1 then
      local q = v * (1 - share) / prev.value
      if q >= 0.5 then add(prev.item, round_nice(q)) end
    end
  end
  local out, main_index = {}, nil
  for i, item in ipairs(order) do
    out[i] = { item, acc[item] }
    if main and item == main.item then main_index = i end
  end
  return out, main_index
end

--- Table des coûts, calculée une fois (L.rebuild). Règle de monotonie : si l'arrondi rend un niveau moins
--- cher (en valeur) que le précédent, on ajoute du matériau de l'époque jusqu'à le dépasser (cas des murs,
--- dont la valeur d'époque ne vaut que quelques objets).
local cost_table = {}

function L.rebuild()
  cost_table = {}
  for _, f in ipairs(L.families) do
    local t, prev_value = {}, nil
    for n = 2, f.max do
      local c, mi = raw_cost(f, n)
      if prev_value and mi then
        while L.cost_value(c) <= prev_value do c[mi][2] = c[mi][2] + 1 end
      end
      t[n] = c
      prev_value = L.cost_value(c)
    end
    cost_table[f.key] = t
  end
end

--- Coût du passage au niveau n (n ≥ 2) : NOUVELLE liste ordonnée { {objet, quantité}, ... } (déterministe).
function L.cost(family, n)
  assert(n >= 2 and n <= family.max, "niveau hors bornes")
  local out = {}
  for i, c in ipairs(cost_table[family.key][n]) do out[i] = { c[1], c[2] } end
  return out
end

--- Durée du chantier vers le niveau n, en ticks (0 = instantané). factor : réglage de partie.
function L.time_ticks(family, n, factor)
  if family.instant or family.time0 == 0 then return 0 end
  local ep = L.epochs[L.pay_epoch(family, n)]
  local s
  if family.key == "command" then
    s = family.time0 * ep.cc_time_mult
  else
    s = family.time0 * ep.time_mult
    if L.step_of(family, n) == 2 then s = s * L.SECOND_LEVEL_TIME_FACTOR end
  end
  return math.floor(s * 60 * (factor or 1) + 0.5)
end

--- Plafond des bâtiments (toutes familles sauf le centre) pour un centre de niveau cc : 2 × cc (2 niveaux
--- par époque), au plus 30 ; sans centre, 1. C'est le chiffre qu'affiche le panneau du centre.
function L.building_cap(cc_level)
  if not cc_level or cc_level < 1 then return 1 end
  return math.min(L.MAX, 2 * cc_level)
end

--- Niveau maximal autorisé pour une famille selon le niveau du centre de commandement (0 = pas de centre).
--- Le centre lui-même va jusqu'à 15.
function L.max_level(family, cc_level)
  if family.key == "command" then return family.max end
  return math.min(family.max, L.building_cap(cc_level))
end

--- Ouvriers d'amélioration (chantiers simultanés) selon le niveau du centre : 1 de plus toutes les 3 époques.
function L.builders(cc_level)
  if not cc_level or cc_level < 1 then return 0 end
  return math.min(L.MAX_BUILDERS, 1 + math.floor((cc_level - 1) / 3))
end

--- Peut-on lancer l'amélioration vers le niveau n ? Renvoie true ou false, raison (clé de locale).
function L.check(family, n, cc_level, busy_builders)
  if n > family.max then return false, "max" end
  if n > L.max_level(family, cc_level) then
    if not cc_level or cc_level < 1 then return false, "no-cc" end
    return false, "cc-too-low"
  end
  if not (family.instant or family.time0 == 0) and (busy_builders or 0) >= L.builders(cc_level) then
    return false, "no-builder"
  end
  return true
end

--- Liste triée des objets de coût de toutes les familles à tous les niveaux (pour vérifier qu'ils existent).
function L.cost_items()
  local seen, out = {}, {}
  for _, f in ipairs(L.families) do
    for n = 2, f.max do
      for _, c in ipairs(L.cost(f, n)) do
        if not seen[c[1]] then seen[c[1]] = true; out[#out + 1] = c[1] end
      end
    end
  end
  table.sort(out)
  return out
end

---------------------------------------------------------------------------------------------------
-- Place : un coût tient-il dans le coffre du centre qui le paie ?
---------------------------------------------------------------------------------------------------
--- Cases d'inventaire occupées par un coût : Σ ⌈quantité / pile⌉ (stack : table des piles, défaut
--- L.stack_size ; le moteur réel passe les siennes). Erreur si une pile est inconnue.
function L.cost_slots(cost, stack)
  stack = stack or L.stack_size
  local n = 0
  for _, c in ipairs(cost) do
    local s = assert(stack[c[1]], "taille de pile inconnue : " .. c[1])
    n = n + math.ceil(c[2] / s)
  end
  return n
end

--- Niveau du centre qui PAIE l'amélioration vers le niveau n : centre → n - 1 (le centre lui-même) ;
--- familles → le plus petit centre qui l'autorise, ⌈n/2⌉.
function L.payer_cc(family, n)
  if family.key == "command" then return n - 1 end
  return L.required_cc(family, n)
end

--- Cases du coffre d'un centre de niveau cc (mêmes formules que le prototype).
function L.chest_slots(cc_level)
  for _, st in ipairs(L.by_key.command.stats) do
    if st.path[1] == "inventory_size" then
      return math.floor(L.apply_stat(st, L.CC_INVENTORY, cc_level) + 0.5)
    end
  end
  return L.CC_INVENTORY
end

--- Remplaçants provisoires, par époque : { {epoch, key, want, want_item, item}, ... }.
function L.provisional_materials()
  local out = {}
  for e = 1, L.EPOCHS do
    local m = L.epoch_materials[e]
    if m and m.provisional then
      out[#out + 1] = { epoch = e, key = m.key, want = m.want, want_item = m.want_item, item = m.item }
    end
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Cible de durée de jeu (OBJECTIFS F1-3 ❔ : époque 1 en ~30 min, époque 15 vers ~60 h cumulées) et
-- HYPOTHÈSES du modèle qui relie la courbe aux heures de jeu (BALANCE_SHEET §12, à valider en partie
-- réelle). Données pour les tableaux et les tests : le jeu ne les lit pas.
---------------------------------------------------------------------------------------------------
L.target = {
  -- Durée visée de l'époque e (heures) : 0,5 × 1,261^(e-1) ; somme des 15 époques ≈ 60 h.
  epoch_hours = function(e) return 0.5 * 1.261 ^ (e - 1) end,
  -- Production de l'usine (unités de matière brute par seconde) pendant l'époque e : de 2/s (fours à
  -- combustible) à 1 200/s (usine de fin de partie, avec la Compaction ×4 du lot C).
  production = { 2, 5, 10, 17, 27, 40, 60, 88, 125, 180, 260, 380, 560, 820, 1200 },
  -- Part de la production consacrée aux niveaux.
  spend_share = 0.3,
  -- Base de référence : nombre de bâtiments de chaque famille pendant l'époque e (four en acier et machine
  -- d'assemblage 2 : science verte, vers l'époque 3 ; tourelle laser : époque 6, Électricité).
  base = {
    gun = function(e) return 4 + 3 * (e - 1) end,
    laser = function(e) return e >= 6 and 4 + 4 * (e - 6) or 0 end,
    wall = function(e) return 20 + 30 * (e - 1) end,
    drill = function(e) return 6 + 8 * (e - 1) end,
    furnace = function(e) return e >= 3 and 6 + 8 * (e - 3) or 0 end,
    assembler = function(e) return e >= 3 and 6 + 10 * (e - 3) or 0 end,
  },
}

L.rebuild()

return L
