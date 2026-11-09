--[[
  Lot TITANS (9/11) : les TITANS, données et règles PURES (Lua pur, testé par tests/titans_test.lua ; aucune API du jeu).
  Directive du DC : « Méga-robots titanesques et Kaijus évolutifs ; évolution dynamique : nouvelles armes, masse et plaques de blindage
  selon l'Âge atteint ». Deux archétypes :
  - le JUGGERNAUT, titan ALLIÉ : entrée nouvelle de la famille des géants expérimentaux (shared/robots/experimentaux.lua : `spider-vehicle`
    sans arme, corps en UNE image posée par `rendering`, pattes sans image, chaîne 10 segments au Dock puis assemblage à l'usine de son
    âge). Il ÉVOLUE par PALIER d'âge, de T.AGE_MIN (premier âge des géants, Ech.AGE_ZONE_MIN) au dernier âge du jeu (L.EPOCHS) : un
    prototype par palier (PV, plaques = résistances, masse = vitesse) ; le script le remplace au changement d'âge de sa force ;
    une arme nouvelle par palier franchi (T.ARMES). Les images suivent trois STADES (feuilles : stade = plaques, anneaux, cristaux).
  - le KAIJU cristallin lourd, titan ENNEMI : `unit` (course et attaque à 8 directions), un prototype par ÈRE du jeu (shared/levels/
    config.lua : L.ERA_EPOCHS époques par ère), choisi AU SPAWN selon l'âge de la partie (vagues : shared/td/waves.lua ; nids :
    courbes d'évolution). PV, masse (échelle de l'image et vitesse), plaques (résistances), arme (morsure, griffes de zone, impulsion
    de la gueule-canon) montent avec l'ère ; la lueur prend la couleur de l'ère (L.epochs[].color) : rien n'est écrit en dur, tout est
    lu dans config.lua et dans la règle d'échelle (shared/robots/echelle.lua).
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
-- JUGGERNAUT (allié)
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

--- Armes débloquées au palier `palier` : { [id] = vrai }, et la liste ordonnée.
function T.armes(palier)
  local set, list = {}, {}
  for _, a in ipairs(T.ARMES) do
    if palier >= a.palier then
      set[a.id] = true
      list[#list + 1] = a.id
    end
  end
  return set, list
end

T.JUGGERNAUT = {
  id = "juggernaut", age = 10, kind = "giant", factory = "fo-robot-dock", after = "fo-robot-dock", ref = "trowel", mu = 60000,
  time = 60, range = 42, cooldown = 120, dtype = "laser", speed = 0.12, effect = "titan",
  griffes = { radius = 7, cooldown = 60, part = 0.5, edge = 0.6 },
  segment = { ingredients = { { "processing-unit", 40 }, { "fo-guidance-core", 20 }, { "fo-servo-motor", 20 }, { "fo-controller", 10 },
    { "battery", 60 }, { "steel-plate", 100 } }, time = 30 },
  lueur = { r = 0.10, g = 0.92, b = 1.00 },
}
T.JUGGERNAUT.name = T.PREFIX .. T.JUGGERNAUT.id
T.JUGGERNAUT.segment_item = T.PREFIX .. "segment-" .. T.JUGGERNAUT.id
T.JUGGERNAUT.segment_recipe = T.PREFIX .. "make-segment-" .. T.JUGGERNAUT.id
T.JUGGERNAUT.recipe = T.PREFIX .. "make-" .. T.JUGGERNAUT.id
T.JUGGERNAUT.tech = T.PREFIX .. T.JUGGERNAUT.id
T.JUGGERNAUT.ingredients = { { T.JUGGERNAUT.segment_item, T.SEGMENTS } }

--- Nom du prototype du Juggernaut au palier `palier`.
function T.juggernaut_name(palier) return T.JUGGERNAUT.name .. "-" .. clamp(palier, 1, T.PALIERS) end

--- Le palier d'un nom de prototype de Juggernaut (nil sinon).
function T.juggernaut_palier(name)
  if type(name) ~= "string" then return nil end
  local head = T.JUGGERNAUT.name .. "-"
  if name:sub(1, #head) ~= head then return nil end
  local p = tonumber(name:sub(#head + 1))
  if p == nil or p < 1 or p > T.PALIERS or p ~= math.floor(p) then return nil end
  return p
end

--- Le Juggernaut à un âge : palier, stade d'images, nom, PV (E2 de son âge nominal), plaques (E1 + palier), vitesse (masse),
--- salve, zone, cratère, cadence de zone (règle des géants), armes. Même forme qu'un géant de Xp.GEANTS pour G.cible et G.salve.
function T.juggernaut(age)
  local r = T.JUGGERNAUT
  local palier = T.palier(age)
  local a = T.age_of_palier(palier)
  local armes, liste = T.armes(palier)
  local out = {
    id = r.id, age = a, palier = palier, stage = T.stage(palier), name = T.juggernaut_name(palier), dtype = r.dtype,
    hp = Ech.pv(a), resistances = T.plaques(a, palier), speed = T.vitesse(r.speed, palier), masse = T.masse(palier),
    range = r.range, salve = Ech.salve(a, r.dtype), zone = Ech.rayon(a), cratere = Ech.cratere(a),
    zone_cooldown = math.max(r.cooldown, Ech.CADENCE_ZONE), cooldown = r.cooldown, armes = armes, liste_armes = liste,
    griffes = r.griffes,
  }
  if armes.resonance then out.cooldown = math.max(1, math.floor(r.cooldown / 2)) end
  return out
end

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
  id = "kaiju", speed = 0.16, hp_mult = 3,             -- 3 × les PV d'un géant de son âge (un titan tient tête à un géant)
  morsure_mult = 6,                                    -- morsure = 6 × celle du déchiqueteur du palier de son âge (E.dechiqueteur)
  morsure_cooldown = 60, griffes_radius = 5, impulsion_range = 22, impulsion_radius = 6, impulsion_cooldown = 150,
  scale0 = 1.0,                                        -- échelle de l'image à l'ère 1 (le rendu est à la taille du jeu)
  glow0 = 0.35, glow_pas = 0.14,                       -- lueur : alpha de la couche additive par ère
  pollution = 4000, vision = 40,
  lueur = { r = 0.10, g = 0.92, b = 1.00 },
}

function T.kaiju_name(era) return T.PREFIX .. T.KAIJU.id .. "-" .. clamp(era, 1, T.ERAS) end

function T.kaiju_era_of_name(name)
  if type(name) ~= "string" then return nil end
  local head = T.PREFIX .. T.KAIJU.id .. "-"
  if name:sub(1, #head) ~= head then return nil end
  local e = tonumber(name:sub(#head + 1))
  if e == nil or e < 1 or e > T.ERAS or e ~= math.floor(e) then return nil end
  return e
end

--- Arme la plus haute d'une ère (et l'ensemble débloqué).
function T.kaiju_armes(era)
  local set, top = {}, nil
  for _, a in ipairs(T.KAIJU_ARMES) do
    if era >= a.era then
      set[a.id] = true
      top = a.id
    end
  end
  return set, top
end

--- Le Kaiju d'une ère : nom, âge nominal, PV, plaques, vitesse, échelle (masse), morsure, arme, lueur (alpha, couleur de l'ère).
function T.kaiju(era)
  local k = T.KAIJU
  era = clamp(era, 1, T.ERAS)
  local a = T.age_of_era(era)
  local d = Ech.dechiqueteur(Ech.palier(a))
  local armes, top = T.kaiju_armes(era)
  return {
    id = k.id, era = era, age = a, name = T.kaiju_name(era),
    hp = Ech.pv(a) * k.hp_mult, resistances = T.plaques(a, era), speed = T.vitesse(k.speed, era), scale = k.scale0 * T.masse(era),
    morsure = d.morsure * k.morsure_mult, morsure_cooldown = k.morsure_cooldown,
    armes = armes, arme = top, griffes_radius = k.griffes_radius, impulsion_range = k.impulsion_range, impulsion_radius = k.impulsion_radius,
    impulsion_cooldown = k.impulsion_cooldown,
    glow = math.min(1, k.glow0 + k.glow_pas * (era - 1)), tint = T.era_color(era), pollution = k.pollution * era, vision = k.vision,
  }
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
--- plus haute ; un nid ne connaît pas l'âge : l'évolution en tient lieu.
T.KAIJU_EVO0 = 0.80
T.KAIJU_EVO_PAS = 0.04
T.KAIJU_POIDS = 0.012
function T.kaiju_curve(era)
  local e0 = math.min(0.98, T.KAIJU_EVO0 + T.KAIJU_EVO_PAS * (era - 1))
  return { { e0, 0.0 }, { math.min(1.0, e0 + 0.03), T.KAIJU_POIDS }, { 1.0, T.KAIJU_POIDS } }
end

--- Usine et catégorie de fabrication (Ro.FACTORIES), comme Xp.category.
function T.category(r)
  local f = Ro.factory(r.factory)
  return f and f.category
end

return T
