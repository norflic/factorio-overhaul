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
    -- Moteur réel : du sable teinté restait du sable (brun clair, aucune texture tierce ne vire au lilas :
    -- une teinte ne fait que multiplier). Plaine VITRIFIÉE : surface miroitante (shader d'eau peu profonde)
    -- ardoise-lilas, reflets violets, terrain ferme ; les amas de cristal lumineux en émergent.
    copy_from = "water-shallow",
    ground = true,
    layer = 41,
    tint = { r = 0.92, g = 0.76, b = 1.00 },
    effect_color = { 40, 20, 70, 32 },
    -- Pas de gerbes d'eau ni de clapotis : on marche sur du verre (bruit de pas du pavé).
    no_splash = true,
    sound_from = "stone-path",
    effect_color_secondary = { r = 0.10, g = 0.04, b = 0.16, a = 0.36 },
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
    layer = 42,
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
}

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
      { name = "fo-crystal-dust", copy = "sand-decal", density = 0.04, tint = { r = 0.85, g = 0.80, b = 1.00 } },
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
W.resource_order = { "tungsten", "crystal", "methane" }

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
    map_color = { r = 0.30, g = 0.36, b = 0.52 },
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
    tint = { r = 0.95, g = 0.55, b = 1.00 },
    glint = { tint = { r = 0.85, g = 0.35, b = 1.00 }, min = 0.35, max = 0.75, period = 3 },
    map_color = { r = 0.80, g = 0.25, b = 0.95 },
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
