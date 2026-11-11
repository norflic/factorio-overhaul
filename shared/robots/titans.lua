--[[
  Lot TITANS (9/11) : les TITANS, données et règles PURES (Lua pur, testé par tests/titans_test.lua ; aucune API du jeu).
  Directive du DC : « Méga-robots titanesques et Kaijus évolutifs ; évolution dynamique : nouvelles armes, masse et plaques de blindage
  selon l'Âge atteint ». Deux archétypes :
  - les titans ALLIÉS (T.ALLIES) : le JUGGERNAUT (bipède, âge 10), la SENTINELLE hexapode (âge 11 : singularité = zone + ralentissement) et le
    LÉVIATHAN serpentin (âge 12 : salve de drones d'escorte) : entrées nouvelles de la famille des géants expérimentaux (shared/robots/experimentaux.lua : `spider-vehicle`
    sans arme, corps en UNE image posée par `rendering`, pattes sans image, chaîne 10 segments au Dock puis assemblage à l'usine de son
    âge). Il ÉVOLUE par PALIER d'âge, de T.AGE_MIN (premier âge des géants, Ech.AGE_ZONE_MIN) au dernier âge du jeu (L.EPOCHS) : un
    prototype par palier (PV, plaques = résistances, masse = vitesse) ; le script le remplace au changement d'âge de sa force ;
    une arme nouvelle par palier franchi (T.ARMES). Les images suivent trois STADES (feuilles : stade = plaques, anneaux, cristaux).
  - le KAIJU cristallin lourd, titan ENNEMI : `unit` (course et attaque à 8 directions), un prototype par ÈRE du jeu (shared/levels/
    config.lua : L.ERA_EPOCHS époques par ère), choisi AU SPAWN selon l'âge de la partie (vagues : shared/td/waves.lua ; nids :
    courbes d'évolution). PV, masse (échelle de l'image et vitesse), plaques (résistances), arme (morsure, griffes de zone, impulsion
    de la gueule-canon) montent avec l'ère ; la lueur prend la couleur de l'ère (L.epochs[].color) : rien n'est écrit en dur, tout est
    lu dans config.lua et dans la règle d'échelle (shared/robots/echelle.lua).
  Lot KAIJUS-MUTANTS (10/11, axe 2 du Mode Démon) : trois archétypes de plus, lus par les données comme les autres :
  - le RAVAGEUR, méga-robot d'assaut allié (âge 13, T.ALLIES[4]) : corps ANIMÉ comme le Juggernaut (8 directions) ; mitraille (gatling :
    salve de projectiles), lames de zone, salve des géants, résonance ;
  - l'ÉCORCHEUR, second titan ennemi (T.KAIJUS[2], dès l'ère T.ECORCHEUR.era_min) : bipède charnel à bras-canon : morsure, tir (ère 2),
    PONTE (ère 3 : il met bas des Écorchés quand un ennemi est à portée, script/robots/kaijus.lua) ;
  - les ÉCORCHÉS, mordeurs mutants (T.ECORCHE : trois variantes rôdeur / porteur / hurleur, un prototype par variante et par ère dès
    T.ECORCHE.era_min), pondus par l'Écorcheur, escorte des assauts (shared/combat/assaut_titan.lua), nids tard dans l'évolution.
  Le choix de l'archétype d'un Kaiju (vagues, assauts) est une ROTATION par les données : T.kaiju_pour(era, n) parmi les archétypes
  ouverts à l'ère (era_min), jamais un nom en dur.
  Chiffres PROVISOIRES (consignés dans fo-logs/2026-11-09_TITANS/JOURNAL.md), le DC tranche.
  Déterminisme : listes, aucun pairs, aucun hasard, aucune trigonométrie.
]]

local L = require("shared.levels.config")
local Ech = require("shared.robots.echelle")
local Ro = require("shared.content.robots")

local T = {}

T.PREFIX = "fo-titan-"
T.LOG = "[FO-TITAN]"
T.SUBGROUP = "fo-robots-xp"
T.SEGMENTS = 10

--- Âges et paliers du titan allié : du premier âge des géants au dernier âge du jeu (lus, jamais écrits).
T.AGE_MIN = Ech.AGE_ZONE_MIN
T.AGE_MAX = L.EPOCHS
T.PALIERS = T.AGE_MAX - T.AGE_MIN + 1
--- Ères du jeu (L.ERA_EPOCHS époques par ère) : paliers du Kaiju.
T.ERAS = math.ceil(L.EPOCHS / L.ERA_EPOCHS)
--- Stades d'images du Juggernaut (3 rendus : plaques, anneaux et cristaux s'ajoutent).
T.STAGES = 3

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

--- Palier d'évolution du titan allié à l'âge `age` (1 à T.PALIERS ; avant T.AGE_MIN : 1).
function T.palier(age)
  age = math.floor(tonumber(age) or 1)
  return clamp(age - T.AGE_MIN + 1, 1, T.PALIERS)
end

--- Âge « nominal » d'un palier (celui dont la règle d'échelle donne PV, résistances, salve).
function T.age_of_palier(palier)
  return T.AGE_MIN + clamp(palier, 1, T.PALIERS) - 1
end

--- Stade d'images d'un palier : les T.PALIERS paliers répartis sur T.STAGES stades (1-2 -> 1, 3-4 -> 2, 5-6 -> 3 avec 6 paliers).
function T.stage(palier)
  return clamp(math.ceil(clamp(palier, 1, T.PALIERS) * T.STAGES / T.PALIERS), 1, T.STAGES)
end

--- Ère du jeu à l'âge `age` (1 à T.ERAS).
function T.era(age)
  age = math.floor(tonumber(age) or 1)
  return clamp(math.floor((age - 1) / L.ERA_EPOCHS) + 1, 1, T.ERAS)
end

--- Dernier âge d'une ère (sa règle d'échelle) ; plafonné au dernier âge du jeu.
function T.age_of_era(era)
  return math.min(L.EPOCHS, clamp(era, 1, T.ERAS) * L.ERA_EPOCHS)
end

--- Couleur d'une ère : celle de son dernier âge (shared/levels/config.lua, L.epochs[].color) ; { r, g, b } entre 0 et 1.
function T.era_color(era)
  local e = L.epochs[T.age_of_era(era)]
  return { r = e.color.r, g = e.color.g, b = e.color.b }
end

---------------------------------------------------------------------------------------------------
-- Plaques et masse (communs)
---------------------------------------------------------------------------------------------------
--- Plaques de blindage : + PLAQUE_PCT points de résistance (en %) par palier au-dessus du premier, plafond PLAQUE_MAX.
T.PLAQUE_PCT = 5
T.PLAQUE_MAX = 85
--- Masse : + MASSE_PART par palier (échelle de l'image du Kaiju), vitesse × (1 − LENTEUR_PART par palier).
T.MASSE_PART = 0.10
T.LENTEUR_PART = 0.05

--- Résistances d'un âge (règle d'échelle E1), plus les plaques du palier `palier` (1 : aucune).
function T.plaques(age, palier)
  local out = {}
  for _, r in ipairs(Ech.resistances(age)) do
    out[#out + 1] = { type = r.type, decrease = r.decrease, percent = math.min(T.PLAQUE_MAX, r.percent + T.PLAQUE_PCT * (palier - 1)) }
  end
  return out
end

function T.masse(palier) return 1 + T.MASSE_PART * (palier - 1) end
function T.vitesse(v0, palier) return v0 * (1 - T.LENTEUR_PART * (palier - 1)) end

---------------------------------------------------------------------------------------------------
-- TITANS ALLIÉS : Juggernaut, Sentinelle, Léviathan (même modèle : spider-vehicle sans arme, corps par `rendering`, effets par script)
---------------------------------------------------------------------------------------------------
--- Armes du Juggernaut : chacune se débloque à un palier (cumulatives, ordre fixe).
--- griffes : dégâts de zone courte autour du titan ; canon : rayon de focalisation annulaire sur la cible (coup = salve de son âge) ;
--- salve : salve de ZONE des géants (règle d'échelle E3, cratère E4) ; resonance : la cadence du canon est doublée.
T.ARMES = {
  { id = "griffes", palier = 1 },
  { id = "canon", palier = 2 },
  { id = "salve", palier = 4 },
  { id = "resonance", palier = 6 },
}
--- Armes de la Sentinelle : singularite : rayon de singularité (l'attraction n'existe pas en 1.1 : dégâts de zone + RALENTISSEMENT par
--- autocollant) ; puis canon annulaire, salve de zone, résonance.
T.ARMES_SENTINELLE = {
  { id = "singularite", palier = 1 },
  { id = "canon", palier = 2 },
  { id = "salve", palier = 4 },
  { id = "resonance", palier = 6 },
}
--- Armes du Léviathan : drones : salve de drones d'escorte (projectiles existants teintés, un par drone) ; puis canon (le vortex frontal),
--- salve de zone, résonance.
T.ARMES_LEVIATHAN = {
  { id = "drones", palier = 1 },
  { id = "canon", palier = 3 },
  { id = "salve", palier = 5 },
  { id = "resonance", palier = 6 },
}

--- Armes débloquées au palier `palier` dans la liste `liste` (défaut : celles du Juggernaut) : { [id] = vrai }, et la liste ordonnée.
function T.armes(palier, liste)
  local set, list = {}, {}
  for _, a in ipairs(liste or T.ARMES) do
    if palier >= a.palier then
      set[a.id] = true
      list[#list + 1] = a.id
    end
  end
  return set, list
end

T.JUGGERNAUT = {
  id = "juggernaut", age = 10, kind = "giant", factory = "fo-robot-dock", after = "fo-robot-dock", ref = "trowel", mu = 60000,
  time = 60, range = 42, cooldown = 120, dtype = "laser", speed = 0.12, effect = "titan", armes = T.ARMES,
  griffes = { radius = 7, cooldown = 60, part = 0.5, edge = 0.6 },
  bouche = { 6.5, -19.0 },                               -- bouche du canon (tuiles depuis le pied ; lu sur le rendu : bras droit, côté caméra)
  segment = { ingredients = { { "processing-unit", 40 }, { "fo-guidance-core", 20 }, { "fo-servo-motor", 20 }, { "fo-controller", 10 },
    { "battery", 60 }, { "steel-plate", 100 } }, time = 30 },
  lueur = { r = 0.10, g = 0.92, b = 1.00 },
}
--- Juggernaut ANIMÉ (FINITIONS 10/11) : corps en 8 directions × images (feuilles : tools/render/pieces/titans/juggernaut.py, SERIE ;
--- foulee = FOULEE du modèle, tuiles par cycle de marche, vérifiée par tests/titans_test.lua) ; attaque_ticks : durée d'une salve à l'écran.
T.JUGGERNAUT.anime = { images = { course = 8, attaque = 4 }, foulee = 6.9, attaque_ticks = 30, directions = 16 }   -- ART-16DIR : 16 directions
--- Couches d'un corps animé (nom de couche, calque de rendu), dans l'ordre de dessin.
T.COUCHES_ANIM = { { "ombre", "lower-object" }, { "corps", "air-object" }, { "lueur", "air-object" } }

--- Direction (0 = nord, sens horaire, `n` secteurs) d'une orientation dans [0, 1[ : le secteur le plus proche, sans trigonométrie.
--- ART-16DIR (11/11) : `n` = r.anime.directions (16 pour Juggernaut, Sentinelle, Ravageur ; 8 sinon), égal aux directions des feuilles.
function T.direction(orientation, n)
  n = n or 8
  local o = tonumber(orientation) or 0
  return math.floor(o * n + 0.5) % n
end
function T.direction8(orientation) return T.direction(orientation, 8) end

--- Vitesse d'animation (images par tick) d'une marche à `speed` tuiles par tick : la foulée (tuiles) défile en `images` images ; 0 à l'arrêt.
function T.vitesse_anim(speed, foulee, images)
  speed = math.abs(tonumber(speed) or 0)
  if speed <= 0 or not (foulee and foulee > 0) then return 0 end
  return speed * images / foulee
end

--- Nom d'une animation de corps d'un titan animé : <préfixe><archétype>-<stade>-<animation>-<direction>-<couche>.
function T.anim_name(r, stage, anim, dir, couche)
  return T.PREFIX .. r.id .. "-" .. stage .. "-" .. anim .. "-" .. dir .. "-" .. couche
end

--- Nom d'une pièce d'un titan segmenté (segment de corps, queue), image fixe par direction :
--- <préfixe><archétype>-<pièce>-<stade>-<direction>-<couche>.
function T.piece_name(r, piece, stage, dir, couche)
  return T.PREFIX .. r.id .. "-" .. piece .. "-" .. stage .. "-" .. dir .. "-" .. couche
end

--- Sentinelle hexapode (âge 11, après le Finback) : plus lente, singularité (zone + ralentissement) ; le canon annulaire est à gauche.
T.SENTINELLE = {
  id = "sentinelle", age = 11, kind = "giant", factory = "fo-robot-dock", after = "fo-robot-finback", ref = "finback", mu = 80000,
  time = 60, range = 40, cooldown = 120, dtype = "laser", speed = 0.10, effect = "titan", armes = T.ARMES_SENTINELLE,
  singularite = { radius = 9, cooldown = 90, part = 0.35, edge = 0.5, slow = 0.5, slow_ticks = 120 },
  bouche = { -8.0, -17.0 },
  segment = { ingredients = { { "fo-titanium-plate", 80 }, { "processing-unit", 40 }, { "fo-guidance-core", 20 }, { "fo-graphics-card", 10 },
    { "battery", 60 }, { "steel-plate", 80 } }, time = 30 },
  lueur = { r = 0.10, g = 0.92, b = 1.00 },
  -- TITANS-8DIR : corps animé (flottement, pattes qui ondulent ; salve : la singularité gonfle puis se libère), FOULEE de sentinelle.py
  anime = { images = { course = 8, attaque = 4 }, foulee = 6.0, attaque_ticks = 30, directions = 16 },   -- ART-16DIR : 16 directions
}
--- Léviathan serpentin (âge 12, après le Lévite) : le plus rapide (il flotte), salve de drones d'escorte ; le vortex frontal sert de canon.
T.LEVIATHAN = {
  id = "leviathan", age = 12, kind = "giant", factory = "fo-robot-dock", after = "fo-robot-levite", ref = "levite", mu = 140000,
  time = 60, range = 46, cooldown = 120, dtype = "laser", speed = 0.14, effect = "titan", armes = T.ARMES_LEVIATHAN,
  drones = { base = 2, plus_palier = 4, orbit = 7, cooldown = 90, part = 0.6, radius = 4, speed = 0.3 },
  bouche = { 14.0, -10.0 },
  segment = { ingredients = { { "fo-superconducting-coil", 80 }, { "processing-unit", 50 }, { "fo-magnetic-actuator", 30 },
    { "fo-titanium-plate", 60 }, { "fo-graphics-card", 10 } }, time = 30 },
  lueur = { r = 0.10, g = 0.92, b = 1.00 },
  -- LEVIATHAN-SEG (mandat du DC, 11/11) : corps ARTICULÉ. L'entité porte la TÊTE seule, animée en 16 directions (marche : la couronne de
  -- crocs respire, le vortex pulse ; salve : les anneaux s'ouvrent, les drones sortent de la gueule ; SERIE et FOULEE de leviathan.py) ;
  -- les SEGMENTS (n) et la QUEUE sont des images fixes par direction posées par `rendering` qui suivent la trajectoire de la tête
  -- (shared/robots/serpent.lua) : le premier segment à `premier` tuiles de la tête, puis tous les `espacement`, la queue `queue` derrière
  -- le dernier ; historique échantillonné tous les `pas` tuiles ; mise à jour toutes les `periode` ticks ; ondulation verticale `onde`
  -- (tuiles). Longueurs = celles des pièces du modèle (leviathan.py, PIECES).
  anime = { images = { course = 4, attaque = 4 }, foulee = 4.5, attaque_ticks = 30, directions = 16 },
  -- tol : tolérance (tuiles) de l'ordre de dessin (la pièce la plus au sud par-dessus) avant de le refaire.
  segmente = { n = 4, premier = 6.0, espacement = 5.0, queue = 5.0, pas = 0.5, periode = 5, directions = 16, onde = 0.12, tol = 1.0,
    pieces = { "segment", "queue" } },
}
--- Armes du Ravageur (KAIJUS-MUTANTS) : mitraille : rafale du gatling (T.RAVAGEUR.mitraille.n projectiles par coup, dégâts = part de la salve
--- répartie) ; lames : coup de zone courte des lames de cristal ; puis salve de zone, résonance.
T.ARMES_RAVAGEUR = {
  { id = "mitraille", palier = 1 },
  { id = "lames", palier = 2 },
  { id = "salve", palier = 4 },
  { id = "resonance", palier = 6 },
}
--- Ravageur bipède (âge 13, après le Portique et son Toroïde) : plus vif que le Juggernaut au même âge, rafales à cadence courte ; corps animé.
T.RAVAGEUR = {
  id = "ravageur", age = 13, kind = "giant", factory = "fo-robot-dock", after = "fo-robot-gantry", ref = "toroid", mu = 220000,
  time = 60, range = 38, cooldown = 90, dtype = "physical", speed = 0.11, effect = "titan", armes = T.ARMES_RAVAGEUR,
  mitraille = { n = 6, part = 0.9, spread = 2.0, speed = 0.45 },
  lames = { radius = 6, cooldown = 50, part = 0.55, edge = 0.6 },
  bouche = { -6.0, -15.0 },                              -- bouche du gatling (tuiles depuis le pied : bras gauche, côté caméra)
  segment = { ingredients = { { "fo-titanium-plate", 80 }, { "processing-unit", 60 }, { "fo-magnetic-actuator", 40 },
    { "fo-superconducting-coil", 40 }, { "battery", 60 } }, time = 30 },
  lueur = { r = 0.10, g = 0.92, b = 1.00 },
  anime = { images = { course = 8, attaque = 4 }, foulee = 4.472, attaque_ticks = 30, directions = 16 },   -- FOULEE de ravageur.py ; ART-16DIR : 16 dir.
}
T.ALLIES = { T.JUGGERNAUT, T.SENTINELLE, T.LEVIATHAN, T.RAVAGEUR }
for _, r in ipairs(T.ALLIES) do
  r.name = T.PREFIX .. r.id
  r.segment_item = T.PREFIX .. "segment-" .. r.id
  r.segment_recipe = T.PREFIX .. "make-segment-" .. r.id
  r.recipe = T.PREFIX .. "make-" .. r.id
  r.tech = T.PREFIX .. r.id
  r.ingredients = { { r.segment_item, T.SEGMENTS } }
end

--- L'allié d'un id (nil sinon).
function T.allie_of_id(id)
  for _, r in ipairs(T.ALLIES) do
    if r.id == id then return r end
  end
  return nil
end

--- Nom du prototype d'un allié au palier `palier`.
function T.allie_name(r, palier) return r.name .. "-" .. clamp(palier, 1, T.PALIERS) end

--- L'allié et le palier d'un nom de prototype (nil sinon).
function T.allie_palier(name)
  if type(name) ~= "string" then return nil end
  for _, r in ipairs(T.ALLIES) do
    local head = r.name .. "-"
    if name:sub(1, #head) == head then
      local p = tonumber(name:sub(#head + 1))
      if p ~= nil and p >= 1 and p <= T.PALIERS and p == math.floor(p) then return r, p end
      return nil
    end
  end
  return nil
end

--- Drones d'escorte du Léviathan au palier `palier` : base, un de plus dès plus_palier.
function T.drones(palier)
  local d = T.LEVIATHAN.drones
  return d.base + (palier >= d.plus_palier and 1 or 0)
end

--- Un allié à un âge : palier, stade d'images, nom, PV (E2 de son âge nominal), plaques (E1 + palier), vitesse (masse), salve, zone,
--- cratère, cadence de zone (règle des géants), armes. Même forme qu'un géant de Xp.GEANTS pour G.cible et G.salve.
function T.allie(r, age)
  local palier = T.palier(age)
  local a = T.age_of_palier(palier)
  local armes, liste = T.armes(palier, r.armes)
  local out = {
    id = r.id, age = a, palier = palier, stage = T.stage(palier), name = T.allie_name(r, palier), dtype = r.dtype,
    hp = Ech.pv(a), resistances = T.plaques(a, palier), speed = T.vitesse(r.speed, palier), masse = T.masse(palier),
    range = r.range, salve = Ech.salve(a, r.dtype), zone = Ech.rayon(a), cratere = Ech.cratere(a),
    zone_cooldown = math.max(r.cooldown, Ech.CADENCE_ZONE), cooldown = r.cooldown, armes = armes, liste_armes = liste,
    griffes = r.griffes, singularite = r.singularite, drones = r.drones, bouche = r.bouche,
    mitraille = r.mitraille, lames = r.lames,
  }
  if r.drones then out.n_drones = T.drones(palier) end
  if armes.resonance then out.cooldown = math.max(1, math.floor(r.cooldown / 2)) end
  return out
end

--- Le Juggernaut (raccourcis historiques, mêmes résultats que T.allie).
function T.juggernaut_name(palier) return T.allie_name(T.JUGGERNAUT, palier) end

--- Le palier d'un nom de prototype de Juggernaut (nil sinon).
function T.juggernaut_palier(name)
  local r, p = T.allie_palier(name)
  if r == T.JUGGERNAUT then return p end
  return nil
end

function T.juggernaut(age) return T.allie(T.JUGGERNAUT, age) end

---------------------------------------------------------------------------------------------------
-- KAIJU (ennemi)
---------------------------------------------------------------------------------------------------
--- Armes du Kaiju par ère : morsure (contact), griffes (coup de zone au contact), impulsion (projectile de la gueule-canon, zone).
T.KAIJU_ARMES = {
  { id = "morsure", era = 1 },
  { id = "griffes", era = 2 },
  { id = "impulsion", era = 3 },
}
T.KAIJU = {
  id = "kaiju", era_min = 1, speed = 0.16, hp_mult = 3, -- 3 × les PV d'un géant de son âge (un titan tient tête à un géant)
  morsure_mult = 6,                                    -- morsure = 6 × celle du déchiqueteur du palier de son âge (E.dechiqueteur)
  morsure_cooldown = 60, griffes_radius = 5, impulsion_range = 22, impulsion_radius = 6, impulsion_cooldown = 150,
  scale0 = 1.0,                                        -- échelle de l'image à l'ère 1 (le rendu est à la taille du jeu)
  glow0 = 0.35, glow_pas = 0.14,                       -- lueur : alpha de la couche additive par ère
  pollution = 4000, vision = 40,
  lueur = { r = 0.10, g = 0.92, b = 1.00 },
}
T.KAIJU.armes = T.KAIJU_ARMES

--- Armes de l'ÉCORCHEUR par ère : morsure (contact), tir du bras-canon (projectile de zone, ère 2), PONTE (ère 3 : des Écorchés sortent
--- du sac ventral quand un ennemi est à portée ; script/robots/kaijus.lua, règle T.ponte).
T.ECORCHEUR_ARMES = {
  { id = "morsure", era = 1 },
  { id = "tir", era = 2 },
  { id = "ponte", era = 3 },
}
T.ECORCHEUR = {
  id = "ecorcheur", era_min = 2, speed = 0.19, hp_mult = 2.2,   -- plus léger et plus vif que le cristallin
  morsure_mult = 4.5, morsure_cooldown = 50,
  tir_range = 20, tir_radius = 4, tir_cooldown = 100,
  ponte = { base = 2, plus_era = 1, cooldown = 1200, max_vivants = 8, radius = 30 },   -- Écorchés par ponte : base + plus_era par ère au-delà de la première
  scale0 = 0.9, glow0 = 0.35, glow_pas = 0.14, pollution = 3000, vision = 42,
  lueur = { r = 0.10, g = 0.92, b = 1.00 },
}
T.ECORCHEUR.armes = T.ECORCHEUR_ARMES
--- Archétypes de Kaiju, dans l'ordre de la rotation (le cristallin d'abord : les vagues et assauts d'avant sont inchangés).
T.KAIJUS = { T.KAIJU, T.ECORCHEUR }

--- Nom du prototype d'un Kaiju à une ère (archétype `k`, défaut : le cristallin).
function T.kaiju_name(era, k) return T.PREFIX .. (k or T.KAIJU).id .. "-" .. clamp(era, 1, T.ERAS) end

--- L'archétype et l'ère d'un nom de prototype de Kaiju (nil sinon).
function T.kaiju_of_name(name)
  if type(name) ~= "string" then return nil end
  for _, k in ipairs(T.KAIJUS) do
    local head = T.PREFIX .. k.id .. "-"
    if name:sub(1, #head) == head then
      local e = tonumber(name:sub(#head + 1))
      if e ~= nil and e >= 1 and e <= T.ERAS and e == math.floor(e) then return k, e end
      return nil
    end
  end
  return nil
end

--- L'ère d'un nom de prototype de Kaiju, quel que soit l'archétype (nil sinon).
function T.kaiju_era_of_name(name)
  local _, e = T.kaiju_of_name(name)
  return e
end

--- Archétypes ouverts à une ère (era_min atteint), dans l'ordre de T.KAIJUS.
function T.kaijus_ouverts(era)
  local out = {}
  for _, k in ipairs(T.KAIJUS) do
    if era >= k.era_min then out[#out + 1] = k end
  end
  if #out == 0 then out[1] = T.KAIJUS[1] end
  return out
end

--- Archétype du n-ième Kaiju d'un événement (vague, assaut) à une ère : rotation parmi les archétypes ouverts ; n = 1 : le premier.
function T.kaiju_pour(era, n)
  local l = T.kaijus_ouverts(clamp(era, 1, T.ERAS))
  n = math.max(1, math.floor(tonumber(n) or 1))
  return l[(n - 1) % #l + 1]
end

--- Arme la plus haute d'une ère (et l'ensemble débloqué) d'un archétype (défaut : le cristallin).
function T.kaiju_armes(era, k)
  local set, top = {}, nil
  for _, a in ipairs((k or T.KAIJU).armes) do
    if era >= a.era then
      set[a.id] = true
      top = a.id
    end
  end
  return set, top
end

--- Un Kaiju d'une ère : nom, âge nominal, PV, plaques, vitesse, échelle (masse), morsure, arme, lueur (alpha, couleur de l'ère) ; archétype
--- `k` (défaut : le cristallin). L'Écorcheur porte en plus tir_* et, dès l'ère de la ponte, `ponte` (T.ponte).
function T.kaiju(era, k)
  k = k or T.KAIJU
  era = clamp(era, 1, T.ERAS)
  local a = T.age_of_era(era)
  local d = Ech.dechiqueteur(Ech.palier(a))
  local armes, top = T.kaiju_armes(era, k)
  local out = {
    id = k.id, era = era, age = a, name = T.kaiju_name(era, k), era_min = k.era_min,
    hp = Ech.pv(a) * k.hp_mult, resistances = T.plaques(a, era), speed = T.vitesse(k.speed, era), scale = k.scale0 * T.masse(era),
    morsure = d.morsure * k.morsure_mult, morsure_cooldown = k.morsure_cooldown,
    armes = armes, arme = top, griffes_radius = k.griffes_radius, impulsion_range = k.impulsion_range, impulsion_radius = k.impulsion_radius,
    impulsion_cooldown = k.impulsion_cooldown, tir_range = k.tir_range, tir_radius = k.tir_radius, tir_cooldown = k.tir_cooldown,
    glow = math.min(1, k.glow0 + k.glow_pas * (era - 1)), tint = T.era_color(era), pollution = k.pollution * era, vision = k.vision,
  }
  if armes.ponte then out.ponte = T.ponte(era, k) end
  return out
end

---------------------------------------------------------------------------------------------------
-- ÉCORCHÉS (mordeurs mutants) et PONTE de l'Écorcheur
---------------------------------------------------------------------------------------------------
--- Trois variantes : multiplicateurs sur le déchiqueteur du palier de l'ère (PV, morsure, vitesse, échelle de l'image), plaques du porteur
--- (points de résistance de plus), cri du hurleur (zone au contact).
--- Lot VISUELS-DISTINCTS (10/11) : chaque variante a sa LUEUR (`lueur`, couleur de la variante, lisible de loin et sur la carte) ;
--- la teinte d'une variante à une ère mêle cette couleur (part `part_variante`) et la couleur de l'ère (T.ecorche_tint).
T.ECORCHE = {
  id = "ecorche", era_min = 2, speed0 = 0.22, hp_mult = 2.5, morsure_mult = 1.5, pollution = 60, vision = 30,   -- 2,5 × les PV, 1,5 × la morsure du déchiqueteur du palier
  glow0 = 0.4, glow_pas = 0.12, scale_pas = 0.05, part_variante = 0.75,
  variants = {
    { id = "rodeur", hp = 0.6, dmg = 0.8, speed = 1.35, scale = 0.9, plaques = 0, cooldown = 35, lueur = { r = 0.70, g = 0.97, b = 1.00 } },
    { id = "porteur", hp = 2.2, dmg = 1.0, speed = 0.8, scale = 1.15, plaques = 10, cooldown = 45, lueur = { r = 1.00, g = 0.50, b = 0.08 } },
    { id = "hurleur", hp = 1.0, dmg = 1.4, speed = 1.0, scale = 1.0, plaques = 0, cooldown = 60, cri_radius = 3,
      lueur = { r = 1.00, g = 0.16, b = 0.78 } },
  },
  lueur = { r = 0.10, g = 0.92, b = 1.00 },
}

function T.ecorche_name(v, era) return T.PREFIX .. T.ECORCHE.id .. "-" .. v.id .. "-" .. clamp(era, 1, T.ERAS) end

--- Teinte (lueur en jeu, couleur de carte) d'une variante à une ère : part_variante × lueur de la variante + le reste × couleur de l'ère ;
--- sans lueur propre : la couleur de l'ère seule (comportement d'avant).
function T.ecorche_tint(v, era)
  local e = T.era_color(era)
  local c = v and v.lueur
  if not c then return e end
  local p = T.ECORCHE.part_variante
  return { r = p * c.r + (1 - p) * e.r, g = p * c.g + (1 - p) * e.g, b = p * c.b + (1 - p) * e.b }
end

--- La variante d'un id (nil sinon) et son rang.
function T.ecorche_variant(id)
  for i, v in ipairs(T.ECORCHE.variants) do
    if v.id == id then return v, i end
  end
  return nil
end

--- La variante et l'ère d'un nom de prototype d'Écorché (nil sinon).
function T.ecorche_of_name(name)
  if type(name) ~= "string" then return nil end
  local head = T.PREFIX .. T.ECORCHE.id .. "-"
  if name:sub(1, #head) ~= head then return nil end
  local rest = name:sub(#head + 1)
  for _, v in ipairs(T.ECORCHE.variants) do
    local h2 = v.id .. "-"
    if rest:sub(1, #h2) == h2 then
      local e = tonumber(rest:sub(#h2 + 1))
      if e ~= nil and e >= 1 and e <= T.ERAS and e == math.floor(e) then return v, e end
      return nil
    end
  end
  return nil
end

--- Un Écorché d'une variante à une ère : nom, âge nominal, PV, morsure, cadence, vitesse, échelle, plaques, lueur (couleur de l'ère), cri.
function T.ecorche(v, era)
  local k = T.ECORCHE
  era = clamp(era, 1, T.ERAS)
  local a = T.age_of_era(era)
  local d = Ech.dechiqueteur(Ech.palier(a))
  local res = {}
  for _, r in ipairs(Ech.resistances(a)) do
    res[#res + 1] = { type = r.type, decrease = r.decrease, percent = math.min(T.PLAQUE_MAX, r.percent + v.plaques) }
  end
  return {
    id = k.id, variant = v.id, era = era, age = a, name = T.ecorche_name(v, era),
    hp = d.pv * k.hp_mult * v.hp, morsure = d.morsure * k.morsure_mult * v.dmg, cooldown = v.cooldown,
    speed = k.speed0 * v.speed, scale = v.scale * (1 + k.scale_pas * (era - 1)), resistances = res, cri_radius = v.cri_radius,
    glow = math.min(1, k.glow0 + k.glow_pas * (era - 1)), tint = T.ecorche_tint(v, era), pollution = k.pollution * era, vision = k.vision,
  }
end

--- Ponte de l'Écorcheur à une ère : { { nom, nombre }, ... } ; base + plus_era par ère au-delà de celle de la ponte ; les variantes tournent
--- (rôdeur, porteur, hurleur, rôdeur…), regroupées par nom, dans l'ordre de première apparition.
function T.ponte(era, k)
  k = k or T.ECORCHEUR
  local e_ponte = T.ERAS
  for _, a in ipairs(k.armes) do
    if a.id == "ponte" then e_ponte = a.era end
  end
  local n = k.ponte.base + k.ponte.plus_era * math.max(0, clamp(era, 1, T.ERAS) - e_ponte)
  local out, idx = {}, {}
  for i = 1, n do
    local v = T.ECORCHE.variants[(i - 1) % #T.ECORCHE.variants + 1]
    local nom = T.ecorche_name(v, era)
    if not idx[nom] then
      out[#out + 1] = { nom, 0 }
      idx[nom] = #out
    end
    out[idx[nom]][2] = out[idx[nom]][2] + 1
  end
  return out
end

--- Nids : courbe d'apparition d'un Écorché (plus tard que les déchiqueteurs lourds, avant le Kaiju ; plus tard pour une ère plus haute et
--- une variante plus lourde).
T.ECORCHE_EVO0 = 0.60
T.ECORCHE_EVO_PAS = 0.05
T.ECORCHE_POIDS = 0.03
function T.ecorche_curve(v, era)
  local _, rang = T.ecorche_variant(v.id)
  local e0 = math.min(0.95, T.ECORCHE_EVO0 + T.ECORCHE_EVO_PAS * (era - T.ECORCHE.era_min) + 0.02 * ((rang or 1) - 1))
  return { { e0, 0.0 }, { math.min(0.99, e0 + 0.04), T.ECORCHE_POIDS }, { 1.0, T.ECORCHE_POIDS } }
end

--- Vagues (mode défense de tours) : un Kaiju est le boss des vagues de boss à partir de KAIJU_FIRST_WAVE, un de plus toutes les
--- KAIJU_PLUS_TOUTES vagues ; `boss_every` : période des vagues de boss (TD.boss_every). Rend le nombre de Kaijus (0 sinon).
T.KAIJU_FIRST_WAVE = 20
T.KAIJU_PLUS_TOUTES = 20
function T.kaiju_in_wave(wave, boss_every)
  if wave < T.KAIJU_FIRST_WAVE or wave % boss_every ~= 0 then return 0 end
  return 1 + math.floor((wave - T.KAIJU_FIRST_WAVE) / T.KAIJU_PLUS_TOUTES)
end

--- Nids (unit-spawner) : courbe d'apparition (évolution -> poids) du Kaiju d'une ère, très tardive et rare, plus tard pour une ère
--- plus haute ; un nid ne connaît pas l'âge : l'évolution en tient lieu. Le moteur REFUSE une courbe dont les évolutions ne sont pas
--- STRICTEMENT croissantes (« Wrong SpawnPoints definition », banc content KAIJUS du 10/11 : l'Écorcheur de l'ère V donnait 0,97, 1, 1) :
--- e0 plafonné à 0,96 et le deuxième point à 0,99, le dernier à 1.
T.KAIJU_EVO0 = 0.80
T.KAIJU_EVO_PAS = 0.04
T.KAIJU_POIDS = 0.012
function T.kaiju_curve(era, k)
  local rang = 1
  for i, kk in ipairs(T.KAIJUS) do
    if kk == (k or T.KAIJU) then rang = i end
  end
  local e0 = math.min(0.96, T.KAIJU_EVO0 + T.KAIJU_EVO_PAS * (era - 1) + 0.01 * (rang - 1))
  return { { e0, 0.0 }, { math.min(0.99, e0 + 0.03), T.KAIJU_POIDS }, { 1.0, T.KAIJU_POIDS } }
end

--- Usine et catégorie de fabrication (Ro.FACTORIES), comme Xp.category.
function T.category(r)
  local f = Ro.factory(r.factory)
  return f and f.category
end

return T
