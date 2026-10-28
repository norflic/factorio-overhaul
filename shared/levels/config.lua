--[[
  Niveaux de bâtiments « façon Clash of Clans » en 15 ÉPOQUES (lot V2, session 6 ; lot V2c).
  Pur Lua : données et règles, testables hors jeu ; lues par l'étape data (prototypes/levels/,
  data-final-fixes.lua) et le runtime (script/levels/). Chiffres commentés : BALANCE_SHEET §12 (tableaux
  générés par `lua5.2 tests/levels_test.lua --tables`, courbe recalculée par `--calibrate`).

  Décisions du Directeur Créatif (OBJECTIFS.md F1, Q6 et Q7, 21/10, 18 h 07) :
  - 15 époques = 15 niveaux du CENTRE DE COMMANDEMENT (l'hôtel de ville) : le niveau du centre EST l'époque.
  - Les 6 autres familles ont 30 niveaux : 2 par époque. Niveau maximal d'un bâtiment = 2 × niveau du centre.
    Le 1er niveau d'une époque change la silhouette, le 2e ajoute une pièce (visuel : lots V3).

  Lot V2c (OBJECTIFS.md §4) :
  - Q19 (21/10, 21 h 45) : « si on a les ressources, on améliore, terminé » : l'amélioration est
    INSTANTANÉE dès que le coût est payé (stock du centre, puis inventaire du joueur). Plus de durée, plus
    de bâtiment hors service, plus d'ouvriers de chantier (L.MAX_BUILDERS, L.builders, « no-builder » : retirés).
  - Q16 : pour passer le centre du niveau c au niveau c + 1, chaque famille dont la force possède au moins
    un bâtiment doit en avoir un au niveau min(30, 2c) (L.cc_condition_level, L.cc_blockers).
  - QX7 et QX10 : le calendrier des époques a UNE source, le scénario approuvé (shared/content/epochs.lua,
    lot X0) : durées, débit de l'usine et budget, RECOPIÉS dans L.target au chargement. Le temps d'attente
    ne rythme plus le jeu : ce sont les COÛTS qui le portent, recalibrés pour que la durée impliquée tombe sur
    ce calendrier. Le passage du centre vise 10 % du budget de l'époque (X.CODEX_LOT_SHARE) mais la règle de
    place le borne : 23 à 5,6 % aux époques 1 à 4, puis 3,3 à 0,11 % (ÉCART NON CONFORME à QX10, chiffré dans
    BALANCE_SHEET §12, à trancher par le Directeur Créatif ; tests/levels_test.lua le compte comme écart connu).
  - QX9 : la recherche vanilla des premières époques est allégée (X.VANILLA_UNIT_SCALE recopié dans
    L.VANILLA_UNIT_SCALE, appliqué par data-final-fixes.lua : L.vanilla_unit_count).
  - Correction V2c : la config ne lit plus X après son chargement (tout ce qu'elle en lit est recopié dans des
    clés de L, comparées par la garde de dress) ; un dress qui modifierait X n'a donc aucun effet sur elle, et
    la garde le refuse en plus (prototypes/levels/common.lua).

  Règles du jeu (inchangées depuis la session 5, E24) :
  - Le niveau 1 est le bâtiment vanilla (ou le centre de commandement de base) ; les niveaux suivants sont
    des prototypes à part, posables et minables (un bâtiment ramassé garde son niveau).
  - Un seul centre par force ; sans centre, rien ne s'améliore.

  Courbe de coûts PAR ÉPOQUE (BALANCE_SHEET §12 : « la croissance se fait par époque (nouveau matériau
  requis), pas par exposant ») :
  - chaque époque a SON matériau (monnaie d'époque, OBJECTIFS §6). Une amélioration faite pendant l'époque
    e se paie avec le matériau de l'époque e (60 % de la valeur d'époque) et celui de l'époque e-1 (40 %) ;
    à l'époque 2, l'époque 1 n'ayant pas de matériau, l'acier paie 100 % ; le matériau de l'époque est
    toujours exigé (au moins 1) ;
  - le panier de base de la famille (fer, cuivre, pierre…) croît LINÉAIREMENT ;
  - la valeur d'époque suit une table PAR ÉPOQUE (L.epochs[e].value_mult ; centre : L.epochs[e].cc_value) ;
    les quantités restent bornées parce que le matériau change à chaque époque ;
  - PLACE : un coût tient dans la moitié du coffre du centre qui le paie (L.cost_slots, testé), avec
    les vraies tailles de pile (L.stack_size).
  Compatibilité : les noms fo-command-center et fo-lvl-<famille>-<n> gardent leur sens (même famille,
  même niveau) depuis 0.3.0 ; les chantiers en cours d'une sauvegarde 0.4.0 sont achevés au chargement
  (script/levels/levels.lua, Levels.finish_legacy_jobs).
]]

local L = {}

L.EPOCHS = 15
L.MAX = 30            -- niveau maximal des 6 familles (2 niveaux par époque)
L.CC_MAX = 15         -- niveau maximal du centre de commandement (= nombre d'époques)
L.LEGACY_MAX = 10     -- 0.3.0 : 10 niveaux par famille (compatibilité des sauvegardes)
L.PREFIX = "fo-lvl-"
L.CC_HEALTH = 3000    -- centre niveau 1 : PV
L.CC_INVENTORY = 48   -- centre niveau 1 : cases du coffre (+ 16 par niveau, stats ci-dessous)

--- Équipe de PNJ (lot IA1, C5 : « recalibrer les coûts des époques sur joueur + équipe ») : production de
--- la force (joueur + son équipe) rapportée à celle du joueur seul. TOUS les coûts (panier de base et valeur
--- d'époque, centre compris) sont multipliés par ce facteur, et le modèle de durée multiplie la production
--- par le même : la durée impliquée ne change pas. 1 = joueur seul (aujourd'hui). Le lot IA1 le fixe ; la
--- règle de place est alors à revérifier (tests/levels_test.lua l'affiche pour un facteur 2).
L.TEAM_FACTOR = 1

---------------------------------------------------------------------------------------------------
-- Scénario approuvé (lot X0) : SEULE source du calendrier des époques (durées, débit, budget) et des règles
-- de la recherche vanilla. Chargé au chargement du module (jamais pendant un événement, F24). Le mod de test
-- (fo-autotest) requiert ce fichier par « __factorio-overhaul__/… » : le second chemin couvre ce cas.
-- Tout ce que la config lit dans X est lu ICI, au chargement, et recopié dans L (L.VANILLA_UNIT_SCALE,
-- L.target, index de QX9) : aucune fonction de L ne lit X ensuite (correction V2c de la garde de dress).
---------------------------------------------------------------------------------------------------
-- Lot TIRS (D-21) : table des dégâts par niveau (pur, nombres écrits), même chemin double que X ci-dessous.
local DEGATS
do
  local ok, res = pcall(require, "shared.tirs.degats")
  if ok and type(res) == "table" then DEGATS = res else DEGATS = require("__factorio-overhaul__/shared/tirs/degats") end
end

local X
do
  local ok, res = pcall(require, "shared.content.epochs")
  if ok and type(res) == "table" then X = res else X = require("__factorio-overhaul__/shared/content/epochs") end
end

---------------------------------------------------------------------------------------------------
-- Les 15 époques (OBJECTIFS.md §6, validées par Q7). `color` : couleur d'interface (célébration) et
-- teinte du visuel PROVISOIRE. Multiplicateurs par époque (CALIBRÉS par `lua5.2 tests/levels_test.lua
-- --calibrate` sur le calendrier du lot X0, puis arrondis ; ne pas retoucher sans relancer le banc) :
--   value_mult : valeur (unités de matière brute) payée en matériaux d'époque par les 6 familles,
--                relative à l'époque 2 (× epoch_value de la famille, × 1,25 au 2e niveau d'une époque) ;
--   cc_value   : valeur payée en matériaux d'époque par le passage du centre PAYÉ pendant cette époque
--                (celui qui ouvre l'époque suivante), en plus de son panier de base. Visée : 10 % du budget
--                de l'époque (X.CODEX_LOT_SHARE), bornée par la règle de place (45 % du coffre payeur, au
--                plus 2 000 objets d'une sorte) : visée NON atteinte après l'époque 4 (écart QX10).
-- `--calibrate` part d'un état de référence FIXE (panier V2 du centre) : sa sortie est égale à ces tables
-- (testé par tests/levels_test.lua) ; aucune retouche à la main. Lot X1-TITANE (25/10) : époques 10 à 12 recalibrées
-- avec la plaque de titane (valeur 20, pile 100 ; avant : structure basse densité, 45, pile 10) : 371 / 46000, 675 /
-- 47300, 1250 / 48700 avant.
---------------------------------------------------------------------------------------------------
L.epochs = {
  { key = "pioneer",        color = { r = 1.00, g = 1.00, b = 1.00 }, value_mult = 0, cc_value = 0 },
  { key = "forge",          color = { r = 0.80, g = 0.88, b = 1.00 }, value_mult = 1.43, cc_value = 407 },
  { key = "steam",          color = { r = 1.00, g = 0.66, b = 0.50 }, value_mult = 1.46, cc_value = 1050 },
  { key = "oil",            color = { r = 0.95, g = 0.84, b = 0.50 }, value_mult = 4.5, cc_value = 6000 },
  { key = "volcano",        color = { r = 0.62, g = 0.55, b = 0.62 }, value_mult = 15.5, cc_value = 6060 },
  { key = "electricity",    color = { r = 0.62, g = 0.85, b = 1.00 }, value_mult = 29.2, cc_value = 6160 },
  { key = "crystal",        color = { r = 0.82, g = 0.62, b = 1.00 }, value_mult = 57.9, cc_value = 6290 },
  { key = "swamp",          color = { r = 0.66, g = 0.92, b = 0.55 }, value_mult = 110, cc_value = 6380 },
  { key = "atom",           color = { r = 0.72, g = 1.00, b = 0.62 }, value_mult = 204, cc_value = 14100 },
  { key = "hightech",       color = { r = 0.88, g = 0.95, b = 1.00 }, value_mult = 370, cc_value = 50300 },
  { key = "titanium",       color = { r = 0.95, g = 0.95, b = 0.98 }, value_mult = 687, cc_value = 51800 },
  { key = "superconductor", color = { r = 0.58, g = 0.80, b = 1.00 }, value_mult = 1240, cc_value = 53400 },
  { key = "fusion",         color = { r = 1.00, g = 0.70, b = 0.90 }, value_mult = 2270, cc_value = 80100 },
  { key = "orbit",          color = { r = 1.00, g = 0.86, b = 0.42 }, value_mult = 4140, cc_value = 190000 },
  { key = "legend",         color = { r = 1.00, g = 0.94, b = 0.74 }, value_mult = 7070, cc_value = 0 },
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
  -- Lot X1-TITANE (25/10) : la VRAIE plaque de titane (chaîne de Kroll en jeu, shared/content/titanium.lua), valeur et
  -- pile du scénario X0 (X.currencies : 20 MU, pile 100). Avant : structure basse densité, provisoire, valeur 45.
  [11] = { key = "titanium", want = "plaque de titane", item = "fo-titanium-plate", value = 20 },
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
--- Le 2e niveau d'une époque coûte 25 % de plus que le 1er.
L.SECOND_LEVEL_FACTOR = 1.25

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
  ["fo-titanium-plate"] = 100, -- lot X1-TITANE (X.items, pile par défaut d'une matière ρ8)
}
--- Un coût tient dans cette part du coffre du centre qui le paie (le reste : l'usine continue de le
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
--                 "table" : v × t[n] (t : 30 nombres écrits ; lot TIRS, D-21 : dégâts des tourelles par âge)
--                 knee, k2 : au-delà du niveau `knee`, la pente devient k2 (dégressif) ;
--                 hidden : statistique absente du panneau ; label : clé de locale du panneau
--   base_cost   : panier de base (époque 1) ; quantité × (1 + base_growth·(n-2)) : croissance LINÉAIRE ;
--   epoch_value : valeur payée en matériaux d'époque au 1er niveau de l'époque 2 (× value_mult) ; le centre
--                 n'en a pas : L.epochs[e].cc_value ;
--   main_share  : part du matériau de l'époque (défaut L.MAIN_SHARE ; murs : 1, sans matériau précédent) ;
--   row         : bouton « Toute la rangée » (murs reliés de même niveau, améliorés d'un coup).
---------------------------------------------------------------------------------------------------
L.families = {
  {
    key = "command", type = "container", base = "fo-command-center", size = 4, max = 15,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.20 },
      { path = { "inventory_size" }, op = "add", k = 16 },
    },
    -- Panier calibré (V2c, `--calibrate` depuis le panier V2 260/130/130/50 : 775 u) : le passage 1 → 2 comble
    -- le budget des niveaux de l'époque 1 (940 u, 23,2 % du budget de l'époque). Arrondi de L.round_nice : c'est
    -- exactement ce que le joueur paie au passage 1 → 2.
    base_cost = { { "iron-plate", 310 }, { "copper-plate", 160 }, { "stone-brick", 160 }, { "electronic-circuit", 60 } },
    base_growth = 0.15,
  },
  {
    -- Dégâts (lot TIRS, D-21 révisée le 28/10 : × 1,15 par âge) : niveaux 1 à 6 comme avant (+ 8 % par niveau), puis × 1,15 par ÂGE
    -- (shared/tirs/degats.lua, nombres écrits) : × 7,49 au niveau 30 (× 1,15 par âge ; 0.6.5 : × 2,12, + 2 % par âge de 6 à 15).
    -- La tourelle lourde du mod (dégâts 1,5 × cadence 1,5 = × 2,25 en DPS) vaut le niveau 12-13 : testé.
    key = "gun", type = "ammo-turret", base = "gun-turret", size = 2, max = 30,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "attack_parameters", "damage_modifier" }, op = "table", t = DEGATS.par_niveau, default = 1 },
      { path = { "attack_parameters", "range" }, op = "add", k = 0.25 },
      { path = { "rotation_speed" }, op = "mul", k = 0.05 },
    },
    base_cost = { { "iron-plate", 6 }, { "iron-gear-wheel", 3 }, { "copper-plate", 3 } },
    base_growth = 0.15, epoch_value = 12,
  },
  {
    -- Mêmes dégâts que la mitrailleuse (lot TIRS, D-21 : 2 × 7,49 = × 14,98 en absolu au niveau 30, contre 4 pour la
    -- tourelle laser lourde) ; l'énergie par tir (et le tampon, qui doit la contenir) croît de 4 % par niveau :
    -- × 2,16 au niveau 30 (une tourelle laser ne tire pas plus qu'une entrée de 9,6 MW), donc les dégâts par joule
    -- CROISSENT avec l'âge (les balles aussi : une balle de plus haut niveau fait plus de dégâts pour la même munition).
    key = "laser", type = "electric-turret", base = "laser-turret", size = 2, max = 30,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "attack_parameters", "damage_modifier" }, op = "table", t = DEGATS.par_niveau, default = 1 },
      { path = { "attack_parameters", "range" }, op = "add", k = 0.25 },
      { path = { "rotation_speed" }, op = "mul", k = 0.05 },
      { path = { "attack_parameters", "ammo_type", "energy_consumption" }, op = "mul", k = 0.04,
        label = "fo-epochs.stat-energy_consumption" },
      { path = { "energy_source", "buffer_capacity" }, op = "mul", k = 0.04, hidden = true },
    },
    base_cost = { { "steel-plate", 3 }, { "electronic-circuit", 3 }, { "battery", 2 } },
    base_growth = 0.15, epoch_value = 20,
  },
  {
    key = "wall", type = "wall", base = "stone-wall", size = 1, max = 30, row = true,
    stats = {
      -- 0.3.0 : × 1,30^(n-1) (× 2 000 au niveau 30 : explosion). Désormais linéaire : 350 → 5 425 PV.
      { path = { "max_health" }, op = "mul", k = 0.50 },
    },
    -- Résistances : réduction fixe physique et explosion + 0,5 par niveau (en plus de la vanilla).
    resist_step = { explosion = 0.5, physical = 0.5 },
    base_cost = { { "stone-brick", 3 } },
    base_growth = 0.15, epoch_value = 2, main_share = 1,
  },
  {
    key = "drill", type = "mining-drill", base = "electric-mining-drill", size = 3, max = 30, modules = true,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "mining_speed" }, op = "mul", k = 0.10 },
      { path = { "energy_usage" }, op = "mul", k = 0.07 },
    },
    base_cost = { { "iron-plate", 6 }, { "iron-gear-wheel", 3 }, { "electronic-circuit", 2 } },
    base_growth = 0.15, epoch_value = 7,
  },
  {
    key = "furnace", type = "furnace", base = "steel-furnace", size = 2, max = 30,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "crafting_speed" }, op = "mul", k = 0.08 },
      { path = { "energy_usage" }, op = "mul", k = 0.06 },
    },
    base_cost = { { "steel-plate", 2 }, { "stone-brick", 3 } },
    base_growth = 0.15, epoch_value = 6,
  },
  {
    key = "assembler", type = "assembling-machine", base = "assembling-machine-2", size = 3, max = 30, modules = true,
    stats = {
      { path = { "max_health" }, op = "mul", k = 0.15 },
      { path = { "crafting_speed" }, op = "mul", k = 0.08 },
      { path = { "energy_usage" }, op = "mul", k = 0.06 },
    },
    base_cost = { { "iron-plate", 6 }, { "iron-gear-wheel", 3 }, { "electronic-circuit", 3 } },
    base_growth = 0.15, epoch_value = 7,
  },
}

L.by_key = {}
for i, f in ipairs(L.families) do
  f.index = i
  L.by_key[f.key] = f
end

---------------------------------------------------------------------------------------------------
-- EMPLACEMENTS DE MODULES (lot MOD-1). Q-B2 du Directeur Créatif (24/10, vers 20 h 30) : « QB2 B, on commence à 5 et
-- ensuite +1 par niveau ». Familles qui ont des modules (family.modules) : foreuse et assembleur (le four en acier,
-- à combustible, n'en a aucun en vanilla et n'en reçoit pas). Niveau 1 = le prototype vanilla, dont SEUL module_slots
-- est réécrit (prototypes/modules.lua) ; niveaux 2 à 30 : prototypes/levels/common.lua. 34 au niveau 30.
---------------------------------------------------------------------------------------------------
L.MODULE_SLOTS_FIRST = 5
L.MODULE_SLOTS_STEP = 1

--- Emplacements de modules du niveau n d'une famille (nil : la famille n'a pas de modules).
function L.module_slots(family, n)
  if not family.modules then return nil end
  return L.MODULE_SLOTS_FIRST + L.MODULE_SLOTS_STEP * (n - 1)
end

---------------------------------------------------------------------------------------------------
-- EMPRISE AU SOL par famille et par niveau (lot V3-T). Q23 (22/10, 7 h 20 : « les dernières machines pour
-- construire, elles sont de taille, je sais pas moi 6 par six […] des tailles qui augmentent ») et Q24
-- (22/10, 7 h 40 : « agrandissement sur place si la place autour est libre ; sinon l'amélioration est
-- refusée et le contour nécessaire s'affiche »). OBJECTIFS D1-4 révisé.
--   L.footprints[clé] = { era = { côté de l'ère I, II, III, IV, V } }  (une ère = L.ERA_EPOCHS époques), ou
--                       { level = { côté du niveau 1, 2, … max } }       (réglage fin, niveau par niveau).
--   Famille absente de la table : côté constant = family.size (aujourd'hui : le mur seul).
-- Lot V3-T (22/10, 14 h 50, version 0.4.2) : activée pour la seule MITRAILLEUSE (famille témoin du lot V3-S).
-- Lot V3-T2 (22/10, version 0.4.3) : activée pour TOUTES les familles. Q-S1 répondue OUI par le Directeur
-- Créatif (22/10, 16 h 45) : l'échelle vaut pour toutes les familles, plafond 6×6 pour les machines de
-- production, centre 4×4 → 8×8, mur inchangé. Une ère = 3 époques = 6 niveaux d'une famille (3 niveaux du
-- centre) :
--   gun, laser, furnace : 2×2 aux niveaux 1-6, 3×3 aux 7-12, 4×4 aux 13-18, 5×5 aux 19-24, 6×6 aux 25-30 ;
--   drill, assembler    : 3×3 aux niveaux 1-6, 4×4 aux 7-12, 5×5 aux 13-18, 6×6 aux 19-30 (plafond atteint à
--                         l'ère IV : « machines 3×3 → 6×6 ») ;
--   command             : 4×4 aux niveaux 1-3, 5×5 aux 4-6, 6×6 aux 7-9, 7×7 aux 10-12, 8×8 aux 13-15 ;
--   wall                : 1×1 inchangé (pas de ligne).
-- Le four en acier vanilla est un 2×2 (family.size = 2) : « 3 → 6 » exigerait un niveau 1 non vanilla ; la
-- ligne { 2, 3, 4, 5, 6 } est retenue (même échelle que les tourelles). Boîtes, portée, raccords de tuyaux,
-- point de dépôt et rayon d'extraction des prototypes (prototypes/levels/common.lua, apply_footprint), place,
-- migration et tests suivent la table. CONDITION (garde L.footprint_errors, refusée à l'étape data et par
-- tests/levels_test.lua) : le côté du NIVEAU 1 vaut family.size, car le niveau 1 EST le bâtiment vanilla, jamais
-- retouché ; une ligne ne rétrécit jamais d'un niveau au suivant. Visuel PROVISOIRE : le sprite actuel mis à
-- l'échelle de l'emprise (kit.sprite_scale), en attendant les sprites du lot V3-E.
-- Règle de position (le nouveau bâtiment CONTIENT l'ancien, la plus centrée d'abord, puis un ordre fixe) et
-- géométrie : shared/levels/footprint.lua. Prototypes : prototypes/levels/common.lua. Remplacement par script,
-- refus « no-room » et contour : script/levels/levels.lua.
---------------------------------------------------------------------------------------------------
L.ERA_EPOCHS = 3
L.footprints = {
  command = { era = { 4, 5, 6, 7, 8 } },
  gun = { era = { 2, 3, 4, 5, 6 } },
  laser = { era = { 2, 3, 4, 5, 6 } },
  drill = { era = { 3, 4, 5, 6, 6 } },
  furnace = { era = { 2, 3, 4, 5, 6 } },
  assembler = { era = { 3, 4, 5, 6, 6 } },
}

--- Garde de la table (correction V3-T, défaut 3) : liste des erreurs (vide si la table est valide), dans
--- l'ordre des familles. Une ligne doit nommer une famille, avoir la forme par ère (5 côtés) ou niveau par
--- niveau (family.max côtés), des côtés entiers ≥ 1, un niveau 1 au côté de base (family.size : le niveau 1
--- est le prototype vanilla, que l'étape data ne retouche pas) et ne jamais rétrécir.
function L.footprint_errors()
  local errs = {}
  local keys = {}
  for k in pairs(L.footprints) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local f, row = L.by_key[k], L.footprints[k]
    if not f then
      errs[#errs + 1] = "famille inconnue : " .. tostring(k)
    elseif type(row) ~= "table" or (row.era == nil) == (row.level == nil) then
      errs[#errs + 1] = k .. " : une ligne a soit « era » (5 côtés), soit « level » (" .. f.max .. " côtés)"
    elseif row.era and #row.era ~= 5 then
      errs[#errs + 1] = k .. " : « era » doit avoir 5 côtés (ères I à V), pas " .. #row.era
    elseif row.level and #row.level ~= f.max then
      errs[#errs + 1] = k .. " : « level » doit avoir " .. f.max .. " côtés, pas " .. #row.level
    else
      local prev = 0
      for n = 1, f.max do
        local side = L.footprint(f, n)
        if type(side) ~= "number" or side < 1 or side ~= math.floor(side) then
          errs[#errs + 1] = k .. " : côté du niveau " .. n .. " invalide (" .. tostring(side) .. ")"
          break
        end
        if side < prev then
          errs[#errs + 1] = k .. " : l'emprise rétrécit au niveau " .. n .. " (" .. prev .. " → " .. side .. ")"
          break
        end
        prev = side
      end
      local s1 = L.footprint(f, 1)
      if s1 ~= f.size then
        errs[#errs + 1] = k .. " : le niveau 1 (" .. f.base .. ", prototype vanilla jamais retouché) fait "
          .. f.size .. "×" .. f.size .. ", la table dit " .. tostring(s1) .. " (mettre le premier côté à " .. f.size .. ")"
      end
    end
  end
  return errs
end

--- Ère (1 à 5) du niveau n : ⌈époque / L.ERA_EPOCHS⌉.
function L.era_of(family, n)
  return math.floor((L.epoch_of(family, n) - 1) / L.ERA_EPOCHS) + 1
end

--- Côté de l'emprise (tuiles) du niveau n de la famille (table L.footprints ; sinon family.size).
function L.footprint(family, n)
  local row = L.footprints[family.key]
  if not row then return family.size end
  if row.level then return row.level[n] end
  return row.era[L.era_of(family, n)]
end

--- Plus grand côté d'une famille (tous niveaux).
function L.footprint_max(family)
  local m = 0
  for n = 1, family.max do m = math.max(m, L.footprint(family, n)) end
  return m
end

--- Relevé des côtés de toutes les familles : { [clé] = { côté du niveau 1, … } } (nombres seulement :
--- gardé dans la sauvegarde pour la migration, script/levels/levels.lua). legacy = true : le relevé d'une
--- sauvegarde d'avant le lot V3-T (toutes les emprises au côté de base).
function L.footprint_snapshot(legacy)
  local out = {}
  for _, f in ipairs(L.families) do
    local t = {}
    for n = 1, f.max do t[n] = legacy and f.size or L.footprint(f, n) end
    out[f.key] = t
  end
  return out
end

--- Portée ajoutée au niveau n d'une tourelle qui a grandi : (côté − côté du niveau 1) / 2. La portée du
--- moteur se mesure depuis le CENTRE (range_mode « center-to-center » par défaut en 1.1.91) : sans ce
--- complément, une mitrailleuse 6×6 porterait 2 tuiles de moins au-delà de son bord qu'une 2×2 du même
--- niveau. Avec lui, la portée au-delà du bord reste celle de la statistique (BALANCE_SHEET §12). 0 pour une
--- famille sans statistique de portée.
function L.range_bonus(family, n)
  for _, st in ipairs(family.stats) do
    if st.path[#st.path] == "range" then
      return (L.footprint(family, n) - L.footprint(family, 1)) / 2
    end
  end
  return 0
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
  if stat.op == "table" then return v1 * stat.t[n] end
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
--- Même arrondi, exposé pour `--calibrate` (le panier écrit est celui que le joueur paie au niveau 2).
L.round_nice = round_nice

--- Valeur payée en matériaux d'époque pour le niveau n (0 à l'époque 1), facteur d'équipe compris.
--- Familles : epoch_value × value_mult de l'époque (× 1,25 au 2e niveau d'une époque) ; centre : cc_value
--- de l'époque qui paie le passage.
function L.epoch_value(family, n)
  local ep = L.epochs[L.pay_epoch(family, n)]
  local v
  if family.key == "command" then
    v = ep.cc_value or 0
  else
    v = family.epoch_value * ep.value_mult
    if L.step_of(family, n) == 2 then v = v * L.SECOND_LEVEL_FACTOR end
  end
  return v * L.TEAM_FACTOR
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
  local e = L.pay_epoch(family, n)
  local growth = (1 + family.base_growth * (n - 2)) * L.TEAM_FACTOR
  for _, b in ipairs(family.base_cost) do add(b[1], round_nice(b[2] * growth)) end
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

--- Peut-on améliorer vers le niveau n (règles pures : maximum, plafond du centre) ? Renvoie true ou
--- false, raison (clé de locale). L'amélioration est instantanée (Q19) : plus aucune limite d'ouvriers.
--- La condition du centre (Q16) dépend des bâtiments de la force : L.cc_blockers.
function L.check(family, n, cc_level)
  if n > family.max then return false, "max" end
  if n > L.max_level(family, cc_level) then
    if not cc_level or cc_level < 1 then return false, "no-cc" end
    return false, "cc-too-low"
  end
  return true
end

--- Q16 (« condition légère ») : niveau qu'un bâtiment de CHAQUE famille possédée doit avoir pour que le
--- centre quitte le niveau c (passage c → c + 1) : le niveau maximal de l'époque c, min(30, 2c).
function L.cc_condition_level(c)
  return L.building_cap(c)
end

--- Familles qui BLOQUENT le passage du centre (Q16), dans l'ordre de L.families. census[clé] décrit les
--- bâtiments de la force pour une famille : { any = au moins un bâtiment de la famille, tout niveau ;
--- top = au moins un au niveau L.cc_condition_level(c) ou plus }. Une famille que la force ne possède pas
--- ne bloque jamais. Renvoie une liste de clés (vide : condition remplie).
function L.cc_blockers(census)
  local out = {}
  for _, f in ipairs(L.families) do
    if f.key ~= "command" then
      local c = census and census[f.key]
      if c and c.any and not c.top then out[#out + 1] = f.key end
    end
  end
  return out
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
-- QX9 : recherche vanilla allégée des premières époques. Règles du lot X0 (tests/epochs_test.lua) : une
-- technologie vanilla appartient à l'époque de son re-rangement explicite (X.vanilla_tech_epochs), sinon à
-- la plus haute époque des recettes qu'elle débloque (X.base_recipe_epochs, sans X.base_recipe_never),
-- sinon à la plus haute époque de ses packs ; son nombre d'unités est multiplié par X.VANILLA_UNIT_SCALE
-- de cette époque (arrondi, au moins 1). Index et échelles recopiés ici, au chargement, à partir de X.
-- Correction V2c (étape data réelle) : les recettes de baril que base/data-updates.lua génère pour CHAQUE
-- fluide (« fill-<fluide>-barrel », « empty-<fluide>-barrel ») et rattache d'office à fluid-handling ne
-- rangent pas la technologie. X0 calibre fluid-handling sur technology.lua, sans elles (époque 4) ; avec le
-- baril de méthane du mod (époque 8 dans X.base_recipe_epochs), elle passait à l'époque 8 et gardait
-- 50 unités au lieu de 2 (169 technologies allégées en jeu au lieu de 170).
---------------------------------------------------------------------------------------------------
local recipe_epoch, recipe_never, pack_epoch, tech_epoch_fixed = {}, {}, {}, {}
for _, row in ipairs(X.base_recipe_epochs) do
  for _, r in ipairs(row[2]) do recipe_epoch[r] = row[1] end
end
for _, row in ipairs(X.base_recipe_hidden_allowed) do recipe_epoch[row[1]] = row[2] end
for _, r in ipairs(X.base_recipe_never) do recipe_never[r] = true end
for k, e in ipairs(X.epochs) do pack_epoch[e.pack] = k end
for _, row in ipairs(X.vanilla_tech_epochs) do tech_epoch_fixed[row[1]] = row[2] end

--- Échelle du nombre d'unités des technologies vanilla de l'époque e (copie de X.VANILLA_UNIT_SCALE).
L.VANILLA_UNIT_SCALE = {}
for e = 1, L.EPOCHS do L.VANILLA_UNIT_SCALE[e] = X.VANILLA_UNIT_SCALE[e] or 1 end

local function ingredient_name(ing) return ing.name or ing[1] end

--- Recette de baril générée par le jeu de base pour un fluide (voir plus haut) ? « empty-barrel » (le baril
--- vide, recette de technology.lua) n'en est pas une.
function L.generated_barrel(recipe)
  return type(recipe) == "string"
    and (recipe:match("^fill%-.+%-barrel$") ~= nil or recipe:match("^empty%-.+%-barrel$") ~= nil)
end

--- Époque (1 à 15) d'une technologie, décrite comme à l'étape data : { name, effects, unit = { ingredients } }
--- (le runtime passe effects et research_unit_ingredients sous la même forme). Ingrédients au format court
--- { "pack", n } ou long { name = "pack", amount = n }.
function L.vanilla_tech_epoch(tech)
  local e = tech_epoch_fixed[tech.name]
  if not e then
    e = 0
    for _, ef in ipairs(tech.effects or {}) do
      if ef.type == "unlock-recipe" and not recipe_never[ef.recipe] and not L.generated_barrel(ef.recipe) then
        local re = recipe_epoch[ef.recipe]
        if re and re > e then e = re end
      end
    end
    if e == 0 then
      local unit = tech.unit or {}
      for _, ing in ipairs(unit.ingredients or {}) do
        local pe = pack_epoch[ingredient_name(ing)] or 1
        if pe > e then e = pe end
      end
    end
  end
  return math.max(1, math.min(L.EPOCHS, e))
end

--- Nouveau nombre d'unités d'une technologie vanilla (QX9) : count × L.VANILLA_UNIT_SCALE[époque], arrondi,
--- au moins 1 ; et son époque. nil si elle n'est pas concernée : préfixe « fo- » (technologies du mod),
--- recherche infinie (max_level) ou sans `count` (formule).
function L.vanilla_unit_count(tech, count)
  if type(tech.name) ~= "string" or tech.name:sub(1, 3) == "fo-" then return nil end
  if tech.max_level or type(count) ~= "number" then return nil end
  local e = L.vanilla_tech_epoch(tech)
  local scale = L.VANILLA_UNIT_SCALE[e] or 1
  return math.max(1, math.floor(count * scale + 0.5)), e, scale
end

---------------------------------------------------------------------------------------------------
-- Cible de durée de jeu (OBJECTIFS F1-3 ; QX7 : 60 h = ouverture de la Porte, époque 15 vers 52 h) et
-- HYPOTHÈSES du modèle qui relie la courbe aux heures de jeu (BALANCE_SHEET §12, à valider en partie
-- réelle). Le calendrier (durées, débit, budget) vient du scénario X0 : ses valeurs sont RECOPIÉES ici au
-- chargement (une seule source, X ; aucune courbe propre). Données pour les tableaux et les tests : le jeu
-- ne les lit pas.
---------------------------------------------------------------------------------------------------
local target_hours, target_reach, target_rate, target_budget = {}, {}, {}, {}
for e = 1, L.EPOCHS do
  target_hours[e] = X.epoch_hours(e)
  target_reach[e] = X.reach_hour(e)
  target_rate[e] = X.rate_avg(e)
  target_budget[e] = X.budget(e)
end
L.target = {
  -- Copies du calendrier X0, par époque : durée (h, X.epoch_hours), heure d'arrivée (h, X.reach_hour),
  -- débit MOYEN de l'usine du joueur (unités de matière brute par seconde, X.rate_avg), budget (débit moyen ×
  -- durée, X.budget) ; heure d'ouverture de la Porte (X.player_gate_hour).
  hours = target_hours, reach = target_reach, rate = target_rate, budget_mu = target_budget,
  gate_hour = X.player_gate_hour(),
  -- Accès par fonction (interface des tableaux et des tests), sur ces copies.
  epoch_hours = function(e) return L.target.hours[e] end,
  reach_hour = function(e) return L.target.reach[e] end,
  production = function(e) return L.target.rate[e] end,
  budget = function(e) return L.target.budget_mu[e] end,
  -- Part du budget visée par le passage du centre (QX10 ; X.CODEX_LOT_SHARE).
  cc_share = X.CODEX_LOT_SHARE,
  -- Part de la production consacrée aux niveaux (centre compris ; X0 : la recherche en prend 35 %).
  spend_share = 0.3,
  -- Base de référence : nombre de bâtiments de chaque famille pendant l'époque e (four en acier et machine
  -- d'assemblage 2 : science verte, vers l'époque 3 ; tourelle laser : époque 6, Électricité). Hypothèse du
  -- lot V2 conservée : elle suit le jeu d'AUJOURD'HUI (murs et foreuses dès l'époque 1) ; le re-rangement
  -- du lot X0 (X.v2_family_epochs : murs et fours à l'époque 2, foreuses à l'époque 3) la changera.
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
