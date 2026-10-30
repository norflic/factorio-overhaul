--[[
  Monde : nouveaux biomes et ressources à effets. Pur Lua (données + règles d'effets).

  Chaque ressource a un EFFET systémique, pas seulement une couleur :
  - Tungstène        : minerai DUR. Les foreuses à combustible ne peuvent pas le miner (catégorie
                       "fo-hard-solid"). Sert aux munitions perforantes, murs blindés, modules de productivité.
  - Cristal de résonance : combustible exotique qui ACCÉLÈRE les véhicules (+50 % accélération,
                       +30 % vitesse de pointe). Gisements luminescents. Sert aux modules de vitesse.
  - Méthane          : fluide extrait par pompe dans les marais. Carburant de lance-flammes
                       (+50 % de dégâts du jet) et craquable en gaz de pétrole.

  Chaque biome a des modificateurs de terrain (natifs moteur) et un danger/bienfait (runtime, peu coûteux) :
  - Cendres volcaniques : marche -10 %, véhicules freinés ; gisements de tungstène.
  - Plaine de cristal   : marche +10 % ; régénère les personnages (+1 PV/s) ; cristaux de résonance.
  - Marais toxique      : marche -30 %, véhicules très freinés, absorbe beaucoup de pollution ;
                          empoisonne les personnages (2 dégâts/s) ; méthane.
]]

local W = {}

W.biomes = {
  {
    name = "fo-volcanic-ash",
    -- Session 4 (retour du Directeur Créatif : « c'est surtout la couleur qui change ») : texture du sol
    -- calciné des cratères (nuclear-ground), pas une terre teintée.
    copy_from = "nuclear-ground",
    layer = 40,
    -- Charbon de bois GRIS (moteur réel : la teinte précédente donnait une terre brune uniforme).
    tint = { r = 0.80, g = 0.92, b = 1.00 },
    map_color = { r = 52, g = 44, b = 42 },
    walking_speed_modifier = 0.9,
    vehicle_friction_modifier = 1.6,
    pollution_absorption_per_second = 0.0000005,
    region = { seed = "fo-biome-volcanic", threshold = 0.32, scale = 1 / 220, moisture_max = 0.5 },
    hazard = nil,
  },
  {
    name = "fo-crystal-flats",
    -- Lot B0 (24/10, retour du DC : « un biome violet […] bizare », « transitions […] ultra pixélisé ») : l'ancienne
    -- copie de l'eau peu profonde (teinte 0,92 ; 0,76 ; 1) se dessinait dans la couche de l'eau, au-dessus de tous les
    -- sols (layer 41) et sans transition vers eux : bords en escalier de tuiles, bleu-violet (Lab 37 ; 17 ; −28) à ΔE 61
    -- de l'herbe et du désert voisins (fo-logs/2026-10-24_B0/NOTES.md). Désormais un SOL comme ceux de vanilla : la
    -- découpe, les variantes et les masques de transition du sable ridé (sand-3), avec une image RECOLORÉE en mauve
    -- bruyère (tools/biomes/sol_cristal.py : une teinte ne fait que multiplier, F36, F38). Au-dessus des sols vanilla
    -- (layer 41) : c'est lui qui dessine sa frange irrégulière sur l'herbe et le désert, comme le désert rouge sur l'herbe.
    copy_from = "sand-3",
    texture = {
      ["__base__/graphics/terrain/sand-3.png"] = "__factorio-overhaul__/graphics/terrain/cristal/sol-cristal.png",
      ["__base__/graphics/terrain/hr-sand-3.png"] = "__factorio-overhaul__/graphics/terrain/cristal/hr-sol-cristal.png",
    },
    ground = true,
    layer = 41,
    -- Pas de poussière de sable brune sous les pas ni les roues (bruit de pas du pavé : on marche sur une croûte dure).
    no_splash = true,
    sound_from = "stone-path",
    map_color = { r = 150, g = 120, b = 185 },
    walking_speed_modifier = 1.1,
    vehicle_friction_modifier = 1.0,
    pollution_absorption_per_second = 0.000004,
    region = { seed = "fo-biome-crystal", threshold = 0.5, scale = 1 / 260, aux_min = 0.45 },
    hazard = { kind = "heal", amount = 1 },
  },
  {
    name = "fo-toxic-marsh",
    -- Eau boueuse peu profonde (shader d'eau animé) mais terrain FERME : on y marche et on y construit.
    copy_from = "water-mud",
    ground = true,
    -- Lot B0 : SOUS les sols vanilla (layer 5, entre l'eau, 3, et l'eau peu profonde, 6 ; 42 avant). Copie de l'eau
    -- boueuse, la tuile se dessine dans la couche de l'eau et n'a de transition que vers le vide : à 42, personne ne
    -- dessinait la limite (bords en escalier de tuiles). En dessous, l'herbe, le sable ou les cendres y dessinent leur
    -- rive, comme au bord d'une mare vanilla (E136).
    layer = 5,
    -- Moteur réel (retour du Directeur Créatif : « ultra vert ») : la texture de base est bleu-vert, la
    -- teinte verte la saturait. Eau croupie OLIVE et brune, reflets vaseux (couleur du shader : eau verte).
    tint = { r = 0.95, g = 0.74, b = 0.50 },
    effect_color = { 58, 60, 24, 32 },
    effect_color_secondary = { r = 0.10, g = 0.08, b = 0.02, a = 0.36 },
    map_color = { r = 70, g = 95, b = 40 },
    walking_speed_modifier = 0.7,
    vehicle_friction_modifier = 2.0,
    pollution_absorption_per_second = 0.00002,
    region = { seed = "fo-biome-marsh", threshold = 0.55, scale = 1 / 200, moisture_min = 0.5 },
    hazard = { kind = "damage", type = "poison", amount = 2 },
  },
  {
    -- Lot X1-TITANE (25/10) : CHAMPS DE CRATÈRES, biome de l'âge 11 (X.tiles, docs/SCENARIO_EPOQUES.md : « texture
    -- choisie d'après sa couleur mesurée, F36 et F38 »). Régolithe d'impact gris : la terre à mottes vanilla (dirt-4)
    -- RECOLORÉE (tools/biomes/sol_crateres.py, méthode du lot B0 : couleur moyenne mesurée (127 ; 126 ; 127) en hr), un
    -- SOL comme la plaine de cristal (découpe, variantes et masques de transition de dirt-4), au-dessus des sols vanilla
    -- et de la plaine (layer 42) : c'est lui qui dessine sa frange. Ni teinte, ni danger : un sol stérile, plus lent pour
    -- les véhicules (poussière). Les cratères EN RELIEF ne sont pas faisables en tuiles 1.1 : non faits (dit).
    -- Région : graine NUMÉRIQUE (seed1), sans nouveau prototype noise-layer (F198 : une noise-layer de plus change la
    -- forêt vanilla partout).
    name = "fo-crater-fields",
    copy_from = "dirt-4",
    texture = {
      ["__base__/graphics/terrain/dirt-4.png"] = "__factorio-overhaul__/graphics/terrain/crateres/sol-crateres.png",
      ["__base__/graphics/terrain/hr-dirt-4.png"] = "__factorio-overhaul__/graphics/terrain/crateres/hr-sol-crateres.png",
    },
    ground = true,
    layer = 42,
    no_splash = true,
    sound_from = "stone-path",
    map_color = { r = 122, g = 122, b = 128 },
    walking_speed_modifier = 1.0,
    vehicle_friction_modifier = 1.3,
    pollution_absorption_per_second = 0.0000005,
    region = { seed1 = 7211, threshold = 0.56, scale = 1 / 240, moisture_max = 0.55 },
    hazard = nil,
  },
  {
    -- Lot X2 (25/10) : SABLES NOIRS, biome de l'âge 12 (X.tiles : fo-black-sands ; X.resources : monazite, « sables noirs
    -- (rivages, ou dunes sur carte sèche) »). Le sable fin vanilla (sand-1) RECOLORÉ en noir de magnétite
    -- (tools/biomes/sol_sables_noirs.py, méthode du lot B0 : couleur moyenne mesurée (51 ; 48 ; 46)), un SOL comme les
    -- champs de cratères (découpe, variantes et masques de transition de sand-1), au-dessus des sols vanilla, de la plaine
    -- et des cratères (layer 43) : c'est lui qui dessine sa frange. Ni teinte, ni danger, ni effet de déplacement (X n'en
    -- donne aucun) ; pas de poussière brune sous les pas. ÉCART : les « rivages » ne sont pas modélisés (bruit de région
    -- seul, comme les cratères) ; la garantie pose des dunes même loin de l'eau, comme X le prévoit pour une carte sèche.
    -- Région : graine NUMÉRIQUE (F198).
    name = "fo-black-sands",
    copy_from = "sand-1",
    texture = {
      ["__base__/graphics/terrain/sand-1.png"] = "__factorio-overhaul__/graphics/terrain/sables-noirs/sol-sables-noirs.png",
      ["__base__/graphics/terrain/hr-sand-1.png"] = "__factorio-overhaul__/graphics/terrain/sables-noirs/hr-sol-sables-noirs.png",
    },
    ground = true,
    layer = 43,
    no_splash = true,
    map_color = { r = 44, g = 42, b = 40 },
    walking_speed_modifier = 1.0,
    vehicle_friction_modifier = 1.0,
    pollution_absorption_per_second = 0.000002,
    region = { seed1 = 7212, threshold = 0.6, scale = 1 / 220 },
    hazard = nil,
  },
}

-- Grain fin des frontières des biomes (lot B0, verdict du DC du 24/10 : « B3 B ») : bruit ajouté à la probabilité de
-- chaque tuile de biome, aux réglages du bruit que vanilla ajoute à ses sols (tiles.lua : 1/6, 2/3, 0,7, 4 octaves).
-- nil : frontières lisses (avant le verdict).
-- seed1 : graines numériques propres (comme les gisements, 7101 à 7103) ; surtout pas de nouveau prototype noise-layer
-- (il décale les couches de bruit existantes et change la forêt vanilla, F198 proposé).
W.grain = { period = 6, influence = 2 / 3, persistence = 0.7, octaves = 4,
  seed1 = { ["fo-volcanic-ash"] = 7201, ["fo-crystal-flats"] = 7202, ["fo-toxic-marsh"] = 7203, ["fo-crater-fields"] = 7204,
    ["fo-black-sands"] = 7205 } } -- X2 : sables noirs

-- Biomes sans AUCUN décor vanilla à la génération (lot B0, verdict « B4 B » : touffes d'herbe et plaques brunes
-- retirées de la plaine de cristal) ; leur propre décor (W.decor) reste.
W.no_vanilla_decor = { "fo-crystal-flats", "fo-crater-fields", "fo-black-sands" } -- X1 : régolithe ; X2 : dunes

-- Décor propre à chaque biome (session 4) : ce qui pousse, ce qui affleure, ce qui luit. Copies vanilla
-- recomposées (teinte + couche lumineuse « draw_as_glow » pour ce qui luit la nuit), placées uniquement
-- sur la tuile du biome (tile_restriction). density = probabilité par tuile.
W.decor = {
  ["fo-volcanic-ash"] = {
    entities = {
      { name = "fo-magma-rock", type = "simple-entity", copy = "rock-huge", density = 0.006,
        tint = { r = 0.32, g = 0.27, b = 0.26 }, glow = { r = 0.75, g = 0.22, b = 0.03, a = 0.6 },
        mined = { { "stone", 24 }, { "coal", 8 } } },
      { name = "fo-basalt-spire", type = "simple-entity", copy = "rock-big", density = 0.009,
        tint = { r = 0.25, g = 0.23, b = 0.24 }, mined = { { "stone", 12 } } },
      { name = "fo-charred-tree", type = "tree", copy = "dead-dry-hairy-tree", density = 0.02,
        tint = { r = 0.22, g = 0.20, b = 0.20 } },
    },
    decoratives = {
      { name = "fo-ash-patch", copy = "nuclear-ground-patch", density = 0.03, tint = { r = 0.70, g = 0.62, b = 0.60 } },
      { name = "fo-ash-cinders", copy = "rock-small", density = 0.05, tint = { r = 0.28, g = 0.24, b = 0.24 } },
      -- Croûtes de braise : rougeoient la nuit (moteur réel : à 0,03 et sans lueur, un tapis rouge mat).
      { name = "fo-ash-embers", copy = "red-desert-decal", density = 0.02, tint = { r = 0.45, g = 0.14, b = 0.06 },
        glow = { r = 0.40, g = 0.10, b = 0.01, a = 0.5 } },
    },
  },
  ["fo-crystal-flats"] = {
    entities = {
      { name = "fo-crystal-cluster", type = "simple-entity", copy = "rock-big", density = 0.010,
        tint = { r = 0.62, g = 0.42, b = 1.00 }, glow = { r = 0.60, g = 0.26, b = 1.00, a = 0.8 },
        mined = { { "fo-resonance-crystal", 6 }, { "stone", 6 } } },
      { name = "fo-crystal-shard", type = "simple-entity", copy = "sand-rock-big", density = 0.012,
        tint = { r = 0.55, g = 0.80, b = 1.00 }, glow = { r = 0.14, g = 0.60, b = 1.00, a = 0.7 },
        mined = { { "stone", 8 }, { "fo-resonance-crystal", 2 } } },
    },
    decoratives = {
      -- Lot B0 : densité 0 (0,04 avant). Le décalque de sable copié est brun (83 ; 58 ; 33 mesuré) et le reste teinté
      -- (F38) : il couvrait la plaine de plaques de boue craquelée. Prototype gardé (sauvegardes, garantie M0).
      { name = "fo-crystal-dust", copy = "sand-decal", density = 0, tint = { r = 0.85, g = 0.80, b = 1.00 } },
      { name = "fo-crystal-bush", copy = "white-desert-bush", density = 0.02, tint = { r = 0.80, g = 0.65, b = 1.00 } },
      { name = "fo-crystal-pebbles", copy = "rock-tiny", density = 0.05, tint = { r = 0.70, g = 0.55, b = 1.00 } },
    },
  },
  ["fo-toxic-marsh"] = {
    entities = {
      { name = "fo-marsh-tree", type = "tree", copy = "tree-09", density = 0.03,
        tint = { r = 0.55, g = 0.62, b = 0.30 } },
      { name = "fo-marsh-snag", type = "tree", copy = "dead-grey-trunk", density = 0.01,
        tint = { r = 0.45, g = 0.50, b = 0.32 } },
    },
    decoratives = {
      { name = "fo-marsh-reeds", copy = "green-pita", density = 0.06, tint = { r = 0.55, g = 0.70, b = 0.25 } },
      -- Écume toxique : luit faiblement la nuit (le marais « respire »).
      { name = "fo-marsh-scum", copy = "dark-mud-decal", density = 0.03, tint = { r = 0.55, g = 0.70, b = 0.30 },
        glow = { r = 0.16, g = 0.38, b = 0.05, a = 0.4 } },
      { name = "fo-marsh-moss", copy = "green-carpet-grass", density = 0.04, tint = { r = 0.55, g = 0.62, b = 0.30 } },
      { name = "fo-marsh-stump", copy = "muddy-stump", density = 0.01, tint = { r = 0.60, g = 0.65, b = 0.40 } },
    },
  },
  -- X1-TITANE : éjectas d'impact, cailloux gris clair (copies vanilla teintées froid) ; aucune entité (la brèche des
  -- remparts est une ressource de la branche D, hors de ce lot).
  ["fo-crater-fields"] = {
    decoratives = {
      { name = "fo-crater-pebbles", copy = "rock-tiny", density = 0.06, tint = { r = 0.86, g = 0.87, b = 0.92 } },
      { name = "fo-crater-ejecta", copy = "rock-small", density = 0.02, tint = { r = 0.80, g = 0.81, b = 0.86 } },
      -- verre d'impact : éclats sombres vert-noir
      { name = "fo-crater-glass", copy = "sand-rock-small", density = 0.01, tint = { r = 0.42, g = 0.48, b = 0.45 } },
    },
  },
  -- X2 : galets de basalte et coquilles blanchies sur les dunes de sable noir (copies vanilla teintées) ; aucune entité.
  ["fo-black-sands"] = {
    decoratives = {
      { name = "fo-black-sand-pebbles", copy = "rock-tiny", density = 0.04, tint = { r = 0.40, g = 0.39, b = 0.38 } },
      { name = "fo-black-sand-shells", copy = "sand-rock-small", density = 0.006, tint = { r = 0.95, g = 0.92, b = 0.86 } },
      -- rides de dune assombries (décalque brun teinté : il reste sombre, F38)
      { name = "fo-black-sand-ripples", copy = "sand-dune-decal", density = 0.01, tint = { r = 0.35, g = 0.34, b = 0.33 } },
    },
  },
}

--[[
  Garantie de placement (lot M0, 23/10) : les trois ressources sont les monnaies des époques 5, 7 et 8
  (shared/levels/config.lua, L.epoch_materials). Nombre et distance au départ : X.base_resources de
  shared/content/epochs.lua (placement.guaranteed) ; forme du site posé par script : `guarantee` ci-dessous.
  Règles : shared/content/guarantee.lua (pur) ; exécution : script/world/guarantee.lua.
    site_radius : rayon du disque de tuiles du biome posé autour du site (bord irrégulier) ;
    ore_radius  : rayon du gisement (minerai) ; amount : quantité par tuile au centre (décroît vers le bord) ;
    min_total   : quantité d'un gisement naturel déjà connu qui vaut « un site » (sauvegarde existante) ;
    wells       : puits (fluide) : quantité par puits, écart entre puits.
]]
W.resource_order = { "tungsten", "crystal", "methane", "ilmenite", "brine", "monazite", "galena", "cassiterite", "bauxite", "fumarole", "sphalerite" }
-- Ressources GARANTIES (lot M0), dans l'ordre des époques. Lot X1-TITANE : l'ilménite (âge 11) est garantie avec son
-- CHAMP DE CRATÈRES complet (X.base_resources, placement.guaranteed.field = "crater") : gisement d'ilménite ET puits de
-- saumure sur le même disque de régolithe (champ `field_wells` de sa garantie) ; la saumure n'a donc pas de site à part.
-- Lot X2 : la monazite (âge 12), 2 taches de sables noirs (X.resources : placement.guaranteed.count = 2).
-- Lot AMELIO-RESSOURCES (30/10) : la galène (âge 9), 2 gisements de 200 000 à 300-600 tuiles, SANS biome (X.resources :
-- « gisements classiques à plus de 300 tuiles du départ ») ; en DERNIER : les sites d'avant gardent leur place.
-- Piste ÉTAIN : la cassitérite (âge 4, X3), 2 gisements de 150 000 à 120-350 tuiles, sans biome, après la galène.
-- Piste BAUXITE : la bauxite (âge 6, X3), 3 gisements de 300 000 à 300-600 tuiles, sans biome, après la cassitérite.
-- Piste GÉOTHERMIE : la fumerolle (âge 5, X0), 2 fumerolles sur un disque de cendres à 250-600 tuiles, après la bauxite.
-- Piste ZINC : la blende (âge 3, X3), 2 gisements de 200 000 à 150-400 tuiles, sans biome, après la fumerolle.
W.guarantee_order = { "tungsten", "crystal", "methane", "ilmenite", "monazite", "galena", "cassiterite", "bauxite", "fumarole",
  "sphalerite" }

W.resources = {
  tungsten = {
    resource = "fo-tungsten-ore",
    kind = "ore",
    epoch = 5,
    -- Site garanti : environ 200 000 minerais (100 000 plaques ; un bâtiment de chaque famille à son niveau
    -- maximal en demande 2 164 plaques en tout, calculé sur L.cost).
    guarantee = { site_radius = 13, ore_radius = 8, amount = 1500, min_total = 100000 },
    item = "fo-tungsten-ore",
    -- Session 4 : forme de gisement différente (blocs de la pierre, pas les grains du fer), métal sombre
    -- et reflets acier bleutés qui scintillent (aperçus calculés sur les textures du jeu : la teinte
    -- précédente donnait des cailloux gris-olive, et l'éclat de l'uranium les verdissait, F38).
    copy_resource = "stone",
    copy_icon = "stone",
    tint = { r = 0.50, g = 0.58, b = 0.90 },
    glint = { tint = { r = 0.40, g = 0.60, b = 1.00 }, min = 0.25, max = 0.60, period = 6 },
    -- Lot M1 (24/10) : feuille PROPRE du kit minerai (tools/render/pieces/ressources ; direction et mesures :
    -- fo-logs/2026-10-24_M1/NOTES.md). Remplace la pierre teintée ci-dessus pour le gisement, son icône et l'objet
    -- du minerai ; `tint` reste la couleur de la plaque, de la technologie et des munitions.
    sheet = {
      dir = "__factorio-overhaul__/graphics/ressources/tungstene",
      name = "tungstene",
      mining_visualisation_tint = { r = 0.62, g = 0.68, b = 0.82, a = 1 },
      -- Correction M1 : de JOUR la couche d'effet se voit à min..max ; de NUIT le moteur la multiplie (mesuré en
      -- moteur, croissance moins que proportionnelle). Alphas minuscules et multiplicateur grand : presque rien de jour,
      -- lueur turquoise franche de nuit (fo-logs/2026-10-24_M1/NOTES.md, « Correction »).
      effet = { period = 6, deviation = 1, darkness_multiplier = 120, min = 0.008, max = 0.012 },
    },
    -- Lot M1 : (0,30 ; 0,36 ; 0,52) était à ΔE 20 de l'eau et 24 du fer sur la carte ; bleu acier froid, ΔE ≥ 48 de
    -- l'eau, du fer, du cristal, du pétrole, des cendres et du marais (mesure.py, CIE76).
    map_color = { r = 0.40, g = 0.42, b = 0.78 },
    mining_time = 2,
    category = "fo-hard-solid",
    biome = "fo-volcanic-ash",
    autoplace = { base_density = 6, base_spots_per_km2 = 1.6, random_spot_size_minimum = 1, random_spot_size_maximum = 3, seed1 = 7101 },
    plate = { item = "fo-tungsten-plate", copy_icon = "iron-plate", energy = 6.4, ore_per_plate = 2 },
  },
  crystal = {
    resource = "fo-resonance-crystal",
    kind = "ore",
    epoch = 7,
    -- Site garanti : environ 115 000 cristaux (un bâtiment de chaque famille au niveau maximal : 5 265).
    guarantee = { site_radius = 15, ore_radius = 7, amount = 1200, min_total = 60000 },
    item = "fo-resonance-crystal",
    -- La texture de l'uranium est verte (moyenne 0,22 ; 0,31 ; 0,07 : presque sans bleu) : teintée en
    -- violet elle donnait un minerai brun-olive (F38). Forme du fer (texture neutre), violet vif, éclats
    -- violets pulsés (3 s) qui luisent dans le noir.
    copy_resource = "iron-ore",
    copy_icon = "iron-ore",
    -- Lot AMELIO-RESSOURCES (30/10 ; retour du DC du 29/10, 22 h 50 : « les pierres violettes/rose pas fou par contre les
    -- bleues claires sont jolies ») : BLEU GLACIER, celui des éclats de la plaine (fo-crystal-shard) qu'il aime. Avant :
    -- teinte (0,95 ; 0,55 ; 1,00), éclats (0,85 ; 0,35 ; 1,00), carte (0,80 ; 0,25 ; 0,95), rose-violet.
    tint = { r = 0.62, g = 0.86, b = 1.00 },
    glint = { tint = { r = 0.40, g = 0.78, b = 1.00 }, min = 0.35, max = 0.75, period = 3 },
    -- Feuille PROPRE du kit minerai (lot M1 ; direction K1, tools/render/pieces/ressources/directions.py : druses de
    -- prismes bleu glacier sur roche grise, givre ; check_gisement 7 OK) : remplace le fer teinté pour le gisement, son
    -- icône et l'objet ; `tint` reste la couleur de la technologie et des dérivés. Lueur bleu clair pulsée (3 s), faible de
    -- jour, franche de nuit (la couche d'effet couvre 69 % du minerai). Choix provisoire, sans verdict du DC.
    sheet = {
      dir = "__factorio-overhaul__/graphics/ressources/cristal",
      name = "cristal",
      mining_visualisation_tint = { r = 0.55, g = 0.82, b = 1.00, a = 1 },
      effet = { period = 3, deviation = 1, darkness_multiplier = 60, min = 0.03, max = 0.10 },
    },
    -- Azur sur la carte : ΔE76 ≥ 39 de tous les minerais, fluides et sols (tungstène 39 ; galène, pétrole, eau plus loin).
    map_color = { r = 0.00, g = 0.70, b = 1.00 },
    mining_time = 1.5,
    category = nil, -- basic-solid
    biome = "fo-crystal-flats",
    autoplace = { base_density = 3, base_spots_per_km2 = 1.2, random_spot_size_minimum = 1, random_spot_size_maximum = 2, seed1 = 7102 },
    fuel = { value = "20MJ", category = "chemical", acceleration = 1.5, top_speed = 1.3, emissions = 0.5 },
  },
  methane = {
    resource = "fo-methane",
    kind = "fluid",
    epoch = 8,
    -- Puits garantis : 150 % de rendement chacun (300 000 = 100 % pour un puits copié du pétrole), dans une
    -- flaque de marais (le poison du biome s'y applique).
    guarantee = { site_radius = 7, wells = { amount = 450000, spacing = 6 } },
    fluid = "fo-methane",
    copy_resource = "crude-oil",
    copy_fluid = "petroleum-gas",
    tint = { r = 0.55, g = 0.85, b = 0.40 },
    map_color = { r = 0.40, g = 0.70, b = 0.25 },
    biome = "fo-toxic-marsh",
    fuel_value = "1.5MJ",
    -- Moteur réel : le bonus ne touche que le jet direct (pas les brûlures) ; à 1,25 l'écart avec le
    -- pétrole léger (1,1) restait dans le bruit du banc de contenu.
    flamethrower_damage_modifier = 1.5,
    -- Craquage (usine chimique) : `input` du fluide -> `output` de `product`, en `energy` secondes.
    cracking = { input = 100, product = "petroleum-gas", output = 60, energy = 3 },
    autoplace = { base_density = 6, base_spots_per_km2 = 2, random_probability = 1 / 40, additional_richness = 200000, seed1 = 7103 },
  },
  -- Lot X1-TITANE (25/10) : ILMÉNITE, minerai du titane (âge 11), dans les champs de cratères (X.base_resources :
  -- fo-ilmenite, catégorie fo-hard-solid, produit fo-ilmenite-ore). Chaîne de transformation : shared/content/titanium.lua.
  ilmenite = {
    resource = "fo-ilmenite",
    kind = "ore",
    epoch = 11,
    -- Site garanti (un champ de cratères complet) : environ 1,6 million de minerais (16 minerais par plaque : 100 000
    -- plaques, comme le site de tungstène ; un bâtiment de chaque famille au niveau maximal en demande 7 865, calculé sur
    -- L.cost), décalé à l'ouest du centre ; 3 puits de saumure à l'est (« 3 lacs », X.base_resources), 150 % chacun.
    -- 9 400 par tuile au centre : stades 1 et 2 de la feuille (seuils du fer), gisement dense (cf. F169 pour le tungstène).
    -- clear_trees : arbres et rochers retirés du disque (régolithe stérile ; capture du 25/10 : la forêt restait debout sur
    -- le champ et sur le minerai).
    guarantee = { site_radius = 22, ore_radius = 9, ore_offset = { -7, 0 }, amount = 9400, min_total = 800000, clear_trees = true,
      field_wells = { key = "brine", resource = "fo-brine", amount = 450000,
        offsets = { { 9, -7 }, { 9, 0 }, { 9, 7 } } } },
    item = "fo-ilmenite-ore",
    copy_resource = "iron-ore",
    copy_icon = "iron-ore",
    -- Titane de l'âge 11 (#8E9AA6, docs/DESIGN_EPOQUES.md §1.5) : teinte de la technologie et des objets dérivés.
    tint = { r = 0.56, g = 0.60, b = 0.65 },
    -- Feuille PROPRE du kit minerai (lot M1 ; direction I3, tools/render/pieces/ressources/directions.py : seule des
    -- trois rendues à passer les 9 critères de jour et de nuit de tools/autotest/x1_lisibilite.py, captures en moteur
    -- du 25/10 ; I1 et I2 : fo-logs/2026-10-25_X1/NOTES.md). Choix provisoire, sans verdict du DC.
    sheet = {
      dir = "__factorio-overhaul__/graphics/ressources/ilmenite",
      name = "ilmenite",
      mining_visualisation_tint = { r = 0.70, g = 0.66, b = 0.60, a = 1 },
      -- Comme le tungstène corrigé (M1) : presque rien de jour, lueur de nuit (couche d'effet ; avec I3, les croûtes
      -- claires ressortent pêche et crème la nuit, plus que l'uranium).
      effet = { period = 8, deviation = 1, darkness_multiplier = 120, min = 0.008, max = 0.012 },
    },
    -- Bleu-blanc pâle (lumière de l'âge 11) : ΔE76 mesuré contre l'eau, le fer, la pierre, le tungstène, le cristal,
    -- le méthane, la saumure et les sols (fo-logs/2026-10-25_X1/NOTES.md).
    map_color = { r = 0.84, g = 0.88, b = 0.96 },
    mining_time = 2,
    category = "fo-hard-solid",
    biome = "fo-crater-fields",
    autoplace = { base_density = 5, base_spots_per_km2 = 1.4, random_spot_size_minimum = 1, random_spot_size_maximum = 3, seed1 = 7104 },
  },
  -- Lot X1-TITANE : SAUMURE (lac de saumure, fond des cratères ; X : fluide, infinie, part minimale 0,2 : celle du
  -- pétrole copié). Chevalet de pompage vanilla (X : « Pompage : saumure », machines { "pumpjack" }).
  brine = {
    resource = "fo-brine",
    kind = "fluid",
    epoch = 11,
    fluid = "fo-brine",
    copy_resource = "crude-oil",
    copy_fluid = "water",
    tint = { r = 0.55, g = 0.82, b = 0.80 },
    -- Lot AMELIO-RESSOURCES (30/10 ; réponse du DC du 25/10, D-17 : « saumure au visuel propre ») : feuille PROPRE, la
    -- silhouette de la flaque de pétrole vanilla (mêmes variantes et découpe : le chevalet s'y pose de même) recolorée en
    -- eau turquoise bordée d'une croûte de sel blanche (tools/render/pieces/ressources/saumure.py, sans Blender). Avant :
    -- la flaque noire du pétrole teintée.
    stages_sheet = { dir = "__factorio-overhaul__/graphics/ressources/saumure", name = "saumure" },
    map_color = { r = 0.36, g = 0.78, b = 0.70 },
    biome = "fo-crater-fields",
    autoplace = { base_density = 5, base_spots_per_km2 = 1.5, random_probability = 1 / 40, additional_richness = 200000, seed1 = 7105 },
  },
  -- Lot X2 (25/10) : MONAZITE, minerai des terres rares (âge 12), dans les sables noirs (X.resources : fo-monazite,
  -- catégorie basic-solid, produit fo-monazite-ore ; minage 2 s, X : « Minage : monazite »). ÉCART noté : X donne à sa
  -- pseudo-recette de minage les foreuses ÉLECTRIQUES (HARD_DRILLS) mais à la ressource la catégorie basic-solid (toutes
  -- les foreuses ; « foreuses communes » dans l'analyse du scénario) ; le prototype suit la RESSOURCE. Chaîne de
  -- transformation : shared/content/superconductors.lua.
  monazite = {
    resource = "fo-monazite",
    kind = "ore",
    epoch = 12,
    -- Sites garantis (X : 2 taches de sables noirs à 400-900 tuiles) : environ 400 000 minerais chacun (8 minerais par
    -- bobine : 100 000 bobines pour les deux) ; arbres et rochers retirés (dunes).
    guarantee = { site_radius = 15, ore_radius = 8, amount = 3000, min_total = 200000, clear_trees = true },
    item = "fo-monazite-ore",
    copy_resource = "iron-ore",
    copy_icon = "iron-ore",
    -- Miel de la monazite : teinte de la technologie et des objets dérivés.
    tint = { r = 0.86, g = 0.66, b = 0.36 },
    -- Feuille PROPRE du kit minerai (lot M1 ; direction Z1, tools/render/pieces/ressources/directions.py) : placer de
    -- galets et prismes miel et brun-rouge mêlés de magnétite noire. Choix provisoire, sans verdict du DC.
    sheet = {
      dir = "__factorio-overhaul__/graphics/ressources/monazite",
      name = "monazite",
      mining_visualisation_tint = { r = 0.80, g = 0.62, b = 0.35, a = 1 },
      -- Couche d'effet ambre faible (pas la lueur trop claire de l'ilménite la nuit). Multiplicateur 40 (captures du
      -- 25/10, 8 h 25) : de nuit ΔE76 au cuivre 7,4 et à la pierre 6,5 (x2_lisibilite.py N1, N2 en échec) ; 80 essayé.
      effet = { period = 10, deviation = 1, darkness_multiplier = 80, min = 0.008, max = 0.012 },
    },
    -- Or franc sur la carte : loin de la pierre (beige), du cuivre (orange) et de l'uranium (vert).
    map_color = { r = 0.93, g = 0.78, b = 0.18 },
    mining_time = 2,
    category = nil, -- basic-solid (X.resources)
    biome = "fo-black-sands",
    autoplace = { base_density = 5, base_spots_per_km2 = 1.4, random_spot_size_minimum = 1, random_spot_size_maximum = 3, seed1 = 7106 },
  },
  -- Lot AMELIO-RESSOURCES (30/10) : GALÈNE, minerai du plomb (âge 9, Atome ; X.resources : fo-galena, catégorie
  -- basic-solid, produit fo-galena ; minage 1 s). « Gisements classiques à plus de 300 tuiles du départ » : AUCUN biome ;
  -- l'autoplace a son jeu de gisements propre (graine numérique, F198 ; jamais le compteur partagé des minerais vanilla :
  -- X dit « vanilla-like », ce qui déplacerait fer, cuivre, charbon, pierre, uranium et pétrole sur toutes les graines) et
  -- un masque de DISTANCE au lieu d'une région (autoplace.distance_min). Chaîne : shared/content/galena.lua.
  galena = {
    resource = "fo-galena",
    kind = "ore",
    epoch = 9,
    -- Sites garantis (X : « 2 gisements de 200 000 posés par script si l'autoplace n'en a mis aucun à cette distance ») :
    -- environ 200 000 chacun (rayon 7, 2 000 par tuile au centre) ; un gisement naturel connu de 130 000 en vaut un
    -- (min_total : le site posé en fait au moins 1,5 fois, règle des autres sites). Pas de biome : aucun disque de sol, arbres et rochers
    -- retirés sur le gisement (clear_trees) ; une eau comblée (palier 2 de la garantie) prend fill_tile.
    guarantee = { site_radius = 9, ore_radius = 7, amount = 2000, min_total = 130000, clear_trees = true, fill_tile = "dirt-4" },
    item = "fo-galena",
    -- Cubes de la pierre (forme en blocs, comme le tungstène d'avant M1), gris de plomb neutre : la texture de la pierre
    -- est beige (0,69 ; 0,61 ; 0,43) ; × (0,70 ; 0,78 ; 1,00) donne un gris (0,48 ; 0,48 ; 0,43) (F36, F38 : une teinte
    -- ne fait que multiplier). Éclats d'argent froid (galène : éclat métallique), discrets de jour.
    copy_resource = "stone",
    copy_icon = "stone",
    tint = { r = 0.70, g = 0.78, b = 1.00 },
    glint = { tint = { r = 0.75, g = 0.85, b = 1.00 }, min = 0.10, max = 0.35, period = 5 },
    -- Feuille PROPRE du kit minerai (30/10 ; direction G1, tools/render/pieces/ressources/directions.py : cubes de galène
    -- argentée dans une gangue de calcite, 128 échantillons) : remplace la pierre teintée ci-dessus pour le gisement, son
    -- icône et l'objet ; `tint` reste la couleur des dérivés. check_gisement : 6 OK, 1 ECHEC (couverture du stade 1 : 0,233
    -- contre 0,316 en vanilla, écart 0,083 pour 0,08 toléré). Éclats d'argent froid, faibles de jour. Choix provisoire,
    -- sans verdict du DC.
    sheet = {
      dir = "__factorio-overhaul__/graphics/ressources/galene",
      name = "galene",
      mining_visualisation_tint = { r = 0.62, g = 0.64, b = 0.70, a = 1 },
      effet = { period = 5, deviation = 1, darkness_multiplier = 60, min = 0.02, max = 0.08 },
    },
    -- Bleu de cobalt sur la carte : le gris est pris (fer, cratères, ilménite à ΔE76 < 20 d'un gris de plomb) ; ΔE76 ≥ 47
    -- de tous les minerais, fluides et sols du jeu (64,8 au pétrole depuis le cristal bleu ; tests/galena_test.lua).
    map_color = { r = 0.00, g = 0.05, b = 1.00 },
    mining_time = 1,
    category = nil, -- basic-solid (X.resources)
    biome = nil,
    autoplace = { base_density = 6, base_spots_per_km2 = 1.0, random_spot_size_minimum = 1, random_spot_size_maximum = 2,
      seed1 = 7107, distance_min = 300 },
  },
  -- Lot AMELIO-RESSOURCES, piste ÉTAIN (30/10) : CASSITÉRITE, minerai de l'étain (âge 4, Pétrole ; proposition X3,
  -- module x3.lua : fo-cassiterite, basic-solid, minage 1 s). « Placers au bord de l'eau » : sans biome, jeu de
  -- gisements propre (graine X3 7302) sur une région de bruit propre (graine 7312) limitée aux basses terres
  -- (élévation ≤ 6) et à plus de 120 tuiles du départ. Chaîne : shared/content/tin.lua (carte imprimée).
  cassiterite = {
    resource = "fo-cassiterite",
    kind = "ore",
    epoch = 4,
    -- X3 : « 2 gisements de 150 000 posés par script si l'autoplace n'en a mis aucun à cette distance » ; rayon 6, 2 000
    -- par tuile au centre : environ 150 000 ; un gisement naturel de 100 000 en vaut un.
    guarantee = { site_radius = 8, ore_radius = 6, amount = 2000, min_total = 100000, clear_trees = true, fill_tile = "sand-1" },
    item = "fo-cassiterite",
    -- Galets brun chocolat (X3 : « à éclat adamantin, éclats blancs de quartz ») : la pierre (beige) × (0,62 ; 0,42 ;
    -- 0,30) ; éclats blancs (quartz) de jour. Feuille M1 propre à faire.
    copy_resource = "stone",
    copy_icon = "stone",
    tint = { r = 0.62, g = 0.42, b = 0.30 },
    glint = { tint = { r = 1.00, g = 0.96, b = 0.90 }, min = 0.15, max = 0.45, period = 4 },
    -- Feuille PROPRE du kit minerai (30/10 ; direction C1 : placer de galets brun chocolat à éclat adamantin et de quartz
    -- blanc, 128 échantillons ; check_gisement 7 OK) : remplace la pierre teintée ci-dessus pour le gisement, son icône et
    -- l'objet. Éclats blancs du quartz, faibles de jour. Choix provisoire, sans verdict du DC.
    sheet = {
      dir = "__factorio-overhaul__/graphics/ressources/cassiterite",
      name = "cassiterite",
      mining_visualisation_tint = { r = 0.45, g = 0.28, b = 0.18, a = 1 },
      effet = { period = 4, deviation = 1, darkness_multiplier = 60, min = 0.02, max = 0.08 },
    },
    -- Bordeaux sur la carte : les bruns sont pris (cuivre, pierre, désert) ; ΔE76 ≥ 45 de tous les minerais et sols.
    map_color = { r = 0.60, g = 0.00, b = 0.30 },
    mining_time = 1,
    category = nil, -- basic-solid (X3)
    biome = nil,
    autoplace = { base_density = 4, base_spots_per_km2 = 1.4, random_spot_size_minimum = 1, random_spot_size_maximum = 2,
      seed1 = 7302, distance_min = 120, region = { seed1 = 7312, threshold = 0.45, scale = 1 / 180, elevation_max = 6 } },
  },
  -- Lot AMELIO-RESSOURCES, piste BAUXITE (30/10) : BAUXITE, minerai de l'aluminium (âge 6, Électricité ; proposition X3,
  -- chaîne C, module x3.lua : fo-bauxite, basic-solid, minage 1 s). « Climat du désert rouge vanilla (aux ≥ 0,6, humidité
  -- ≤ 0,3), à plus de 300 tuiles » : sans biome, jeu de gisements propre (graine X3 7303) sur une région de bruit propre
  -- (graine 7313) restreinte à ce climat. Chaîne : shared/content/bauxite.lua (alumine, boue rouge, aluminium, pylône).
  bauxite = {
    resource = "fo-bauxite",
    kind = "ore",
    epoch = 6,
    -- X3 : « 3 gisements de 300 000 posés par script si l'autoplace n'en a mis aucun à cette distance » ; rayon 8, 2 300
    -- par tuile au centre : environ 300 000 (tests/bauxite_test.lua) ; un gisement naturel de 190 000 en vaut un.
    guarantee = { site_radius = 10, ore_radius = 8, amount = 2300, min_total = 190000, clear_trees = true, fill_tile = "red-desert-0" },
    item = "fo-bauxite",
    -- Pisolithes mates brique-ocre (X3 : « dans une terre rouille ») : la pierre (beige 0,69 ; 0,61 ; 0,43) × (1,00 ; 0,62 ;
    -- 0,45) donne un brique (0,69 ; 0,38 ; 0,19) (F36, F38 : une teinte ne fait que multiplier). Sans éclat (minerai mat).
    copy_resource = "stone",
    copy_icon = "stone",
    tint = { r = 1.00, g = 0.62, b = 0.45 },
    -- Feuille PROPRE du kit minerai (30/10 ; direction B1 : pisolithes brique et ocre, mates, nodules pâles de gibbsite,
    -- 128 échantillons ; check_gisement 6 OK) ; SANS couche d'effet (minerai mat : rien ne luit). Choix provisoire, sans
    -- verdict du DC.
    sheet = {
      dir = "__factorio-overhaul__/graphics/ressources/bauxite",
      name = "bauxite",
      mining_visualisation_tint = { r = 0.70, g = 0.36, b = 0.18, a = 1 },
    },
    -- Chartreuse sur la carte : rouges et bruns sont pris (ennemis, cuivre, désert rouge, cassitérite) ; ΔE76 ≥ 45 de tous
    -- les minerais, fluides et sols (recherche sur une grille de 21³ couleurs, tests/bauxite_test.lua).
    map_color = { r = 0.80, g = 1.00, b = 0.00 },
    mining_time = 1,
    category = nil, -- basic-solid (X3)
    biome = nil,
    autoplace = { base_density = 5, base_spots_per_km2 = 1.2, random_spot_size_minimum = 1, random_spot_size_maximum = 3,
      seed1 = 7303, distance_min = 300, region = { seed1 = 7313, threshold = 0.4, scale = 1 / 240, moisture_max = 0.3, aux_min = 0.6 } },
  },
  -- Lot AMELIO-RESSOURCES, piste GÉOTHERMIE (30/10) : FUMEROLLE (âge 5, Volcan ; X.resources : fo-fumarole, fluide infini,
  -- part minimale 0,2, catégorie PROPRE fo-fumarole : seul le capteur géothermique la capte ; produit fo-volcanic-gas).
  -- Dans les cendres volcaniques, comme le tungstène. Captage : 200 gaz par cycle (X0 : « Captage : fumerolle », 200 gaz,
  -- 1 s) : 200 gaz/s à 100 %, d'où 140 vapeurs/s (4,2 MW) et 2 soufres/s (SCENARIO_EPOQUES). Chaîne :
  -- shared/content/geothermal.lua.
  fumarole = {
    resource = "fo-fumarole",
    kind = "fluid",
    epoch = 5,
    -- X : « 2 fumerolles posées par script dans la première zone de cendres trouvée, ou sur une tache de cendres créée à
    -- cette distance » : un disque de cendres et 2 puits à 100 % (300 000 = 100 % pour un puits copié du pétrole).
    guarantee = { site_radius = 7, wells = { amount = 300000, spacing = 6 } },
    fluid = "fo-volcanic-gas",
    category = "fo-fumarole",
    yield = 200,
    copy_resource = "crude-oil",
    copy_fluid = "petroleum-gas",
    -- Gaz jaune-blanc (teinte du fluide et de l'icône).
    tint = { r = 0.95, g = 0.90, b = 0.55 },
    -- Feuille PROPRE (comme la saumure) : la flaque du pétrole vanilla recolorée en bouche de cendre brûlée bordée d'une
    -- croûte de soufre jaune (tools/render/pieces/ressources/fumerolle.py, sans Blender). Choix provisoire, sans verdict.
    stages_sheet = { dir = "__factorio-overhaul__/graphics/ressources/fumerolle", name = "fumerolle" },
    fluid_temperature = 300, -- X0 : temperature = 300
    -- Crème soufrée sur la carte : un puits est un point, pas une tache ; ΔE76 ≥ 35 de tous les minerais, fluides et sols
    -- (≥ 45 n'est plus possible hors du bleu marine, invisible sur la carte sombre : tests/geothermal_test.lua).
    map_color = { r = 1.00, g = 1.00, b = 0.75 },
    biome = "fo-volcanic-ash",
    autoplace = { base_density = 4, base_spots_per_km2 = 1.2, random_probability = 1 / 50, additional_richness = 300000, seed1 = 7108 },
  },
  -- Lot AMELIO-RESSOURCES, piste ZINC (30/10) : BLENDE, minerai du zinc (âge 3, Vapeur ; proposition X3, module x3.lua :
  -- fo-sphalerite, basic-solid, minage 1 s). « Districts miniers tirés d'un bruit propre, à plus de 150 tuiles » : sans
  -- biome, jeu de gisements propre (graine X3 7301) sur une région de bruit propre (graine 7311). Chaîne :
  -- shared/content/zinc.lua (zinc, laiton, manomètre à tube de Bourdon).
  sphalerite = {
    resource = "fo-sphalerite",
    kind = "ore",
    epoch = 3,
    -- X3 : « 2 gisements de 200 000 posés par script si l'autoplace n'en a mis aucun à cette distance » ; rayon 7, 2 000
    -- par tuile au centre : environ 200 000 (comme la galène) ; un gisement naturel de 130 000 en vaut un.
    guarantee = { site_radius = 9, ore_radius = 7, amount = 2000, min_total = 130000, clear_trees = true, fill_tile = "dirt-4" },
    item = "fo-sphalerite",
    -- Tétraèdres résineux miel (X3 : « couleur miel à rouge rubis ») : la pierre (beige) × (1,00 ; 0,72 ; 0,30) donne un
    -- miel ambré (0,69 ; 0,44 ; 0,13) ; éclats résineux ambre. Feuille M1 propre à faire.
    copy_resource = "stone",
    copy_icon = "stone",
    tint = { r = 1.00, g = 0.72, b = 0.30 },
    glint = { tint = { r = 1.00, g = 0.70, b = 0.30 }, min = 0.15, max = 0.45, period = 4 },
    -- Bleu nuit sur la carte : la seule teinte restée à ΔE76 ≥ 45 de tous les minerais, fluides et sols (recherche sur une
    -- grille de 21³ couleurs, tests/zinc_test.lua) ; foncé : à revoir sur capture de carte.
    map_color = { r = 0.00, g = 0.00, b = 0.55 },
    mining_time = 1,
    category = nil, -- basic-solid (X3)
    biome = nil,
    autoplace = { base_density = 4, base_spots_per_km2 = 1.2, random_spot_size_minimum = 1, random_spot_size_maximum = 2,
      seed1 = 7301, distance_min = 150, region = { seed1 = 7311, threshold = 0.5, scale = 1 / 220 } },
  },
}

--- Effet de biome à appliquer à un personnage sur une tuile, pour une période de `dt` ticks.
--- Renvoie nil ou { kind = "heal"|"damage", amount = PV, type = type_de_dégâts }.
function W.hazard_for_tile(tile_name, dt)
  for _, b in ipairs(W.biomes) do
    if b.name == tile_name and b.hazard then
      return { kind = b.hazard.kind, type = b.hazard.type, amount = b.hazard.amount * dt / 60 }
    end
  end
  return nil
end

return W
