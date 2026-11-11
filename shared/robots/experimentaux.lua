--[[
  Lot EXPERIMENTAUX (3/11) : les robots EXPÉRIMENTAUX de la famille EXP2 (et Ixion), données et règles PURES.
  Cahier des charges : fo-logs/2026-10-31_ROBOTS/experimentaux/FAISABILITE.md (rôle, âge, coût, effet, voie moteur de chacun).
  Lua PUR : lu par prototypes/experimentaux.lua (étape data), script/robots/experimentaux.lua (exécution) et
  tests/experimentaux_test.lua (hors jeu). Aucune API du jeu ici.

  Décisions tenues ici :
  - Palier 1, les 5 PETITS : trois défenses POSÉES (tourelles en 1 image de corps : un corps fixe ne pivote pas, FAISABILITE l. 58) et deux
    attaquants LANCÉS (capsule : le script pose l'unité au point visé, de la force du lanceur, puis l'envoie sur l'ennemi le plus proche).
  - Chaque petit sort d'une usine de robots de son âge (shared/content/robots.lua, Ro.FACTORIES) et d'une technologie d'époque égale à son âge,
    après la technologie de robot de la même époque (Ro.TECHS).
  - Dégâts par seconde et coup : « valeur pour la valeur » (robot de référence de son âge, `ref`, × mu / ref.mu ; provisoire, non calibré).
  - PV, résistances, salve par cible, zone, cratère : RÈGLE D'ÉCHELLE PAR ÂGE (lot EXPERIMENTAUX-PUISSANCE, QCM du DC du 5/11,
    shared/robots/echelle.lua) : tenir 3 min sous 10 déchiqueteurs de son âge ; « mouche » à 4 âges de moins ; 5 salves pour un déchiqueteur
    de son âge ; zone 15 × (âge − 9) pour les géants.
  - TOUS les dégâts passent par le script (entity.damage, jamais sur la force du tireur ni ses amis, ni en cessez-le-feu) : l'attaque du moteur
    ne lève qu'un effet `script` ; on mesure donc exactement ce qui est infligé (journal [FO-XP]). Seules les flaques de la Sarracénie
    (feu d'acide vanilla) piquent aussi par le moteur, sur les unités au sol ennemies.
  Déterminisme : listes, aucun pairs, aucun hasard, aucune trigonométrie (positions par interpolation linéaire et rotations d'un quart de tour).
]]

local Ro = require("shared.content.robots")
local Ech = require("shared.robots.echelle")

local Xp = {}

Xp.PREFIX = "fo-xp-"
Xp.AMMO_CATEGORY = "fo-xp"
Xp.SUBGROUP = "fo-robots-xp"
Xp.LOG = "[FO-XP]"
Xp.BURST_SECONDS = 30 -- usage unique : la charge vaut 30 s de dégâts de la valeur

--- Unités de recherche de la technologie d'un expérimental : le double de la technologie de robot qui la précède (`after`).
--- Décision du DC (4/11, 19 h 48, QCM du lot XP-COUTS) : « Le double du robot précédent ». `robot_units` : unités EN JEU de la
--- technologie de robot (C.tech_count). Les packs sont ceux de l'âge (C.packs).
Xp.TECH_FACTOR = 2
function Xp.tech_units(robot_units) return Xp.TECH_FACTOR * robot_units end

--- Effets du moteur qui appellent le script (on_script_trigger_effect).
Xp.EFFECT = {
  arc = "fo-xp-arc",           -- Mât-Foudre : l'arc touche (rayon du moteur)
  buisson = "fo-xp-buisson",   -- Géode : la pointe part vers la cible
  crachat = "fo-xp-crachat",   -- Sarracénie : le jet principal retombe
  jet = "fo-xp-jet",           -- Sarracénie : un jet secondaire retombe
  fusion = "fo-xp-fusion",     -- Demi-Vie : au contact
  goutte = "fo-xp-goutte",     -- Veilleuse : la goutte retombe
  lance = "fo-xp-lance",       -- capsule lancée (Géode, Demi-Vie) : préfixe, suivi de l'identifiant
}

--- Sprites d'effet posés par le script (`rendering`), déclarés par prototypes/experimentaux.lua (préfixe Xp.PREFIX). Un nom qui manque
--- arrête la partie au premier dessin (g1, 4/11 : « Missing specification of sprite » pour la glace de la Trombe) : le banc hors jeu
--- contrôle que tout nom `Xp.PREFIX .. "…"` des scripts est déclaré.
Xp.EFFET_SPRITES = { "pointe", "pointe-lueur", "eclair", "verre", "glace" }

--- Les petits (FAISABILITE, tableau « La famille »). `kind` : turret-electric, turret, unit-capsule. `foot` : côté de l'emprise (tuiles) d'une
--- défense posée ; `half` : demi-boîte d'une unité. `scale` : réduction du rendu validé (décision du lead, 4/11 : « des plus petits » ;
--- défenses en 3 x 3, corps d'environ 3 tuiles sur 4 à 5 ; Géode environ 3 ; Demi-Vie environ 2) ; les effets gardent leur taille. `src` : dossier des sources (fo-logs/2026-10-31_ROBOTS/experimentaux/final/sprites).
--- `ref` : robot de même âge (ou du dernier âge qui en a un qui tire) dont on tire la valeur. `after` : technologie de robot de l'époque.
Xp.ROBOTS = {
  {
    id = "mat-foudre", src = "mat_foudre", age = 6, kind = "turret-electric", factory = "fo-robot-workshop", after = "fo-robot-coil",
    ref = "coiler", mu = 1800, time = 30, scale = 0.262, foot = 3, range = 24, cooldown = 60, dtype = "electric",
    chain = { jumps = 2, radius = 8, share = 0.5 },
    ingredients = { { "battery", 100 }, { "steel-plate", 100 }, { "engine-unit", 60 }, { "copper-cable", 100 }, { "electronic-circuit", 60 } },
    lueur = { r = 0.35, g = 0.9, b = 1.0 },
  },
  {
    id = "geode", src = "geode", age = 7, kind = "unit-capsule", factory = "fo-robotics-bay", after = "fo-robot-bay",
    ref = "needle", mu = 3400, time = 30, scale = 0.34, half = 1.0, range = 20, cooldown = 120, dtype = "physical", speed = 0.10,
    spikes = { count = 8, step_ticks = 3, radius = 1.5, share = 0.1, final_radius = 2.5 },
    ingredients = { { "fo-resonance-crystal", 100 }, { "fo-servo-motor", 30 }, { "battery", 100 }, { "steel-plate", 100 },
      { "fo-optical-sensor", 40 }, { "fo-controller", 18 } },
    lueur = { r = 0.62, g = 0.3, b = 1.0 },
  },
  {
    id = "sarracenie", src = "sarracenie", age = 8, kind = "turret", factory = "fo-robotics-bay", after = "fo-robot-bellwether",
    ref = "needle", mu = 6200, time = 30, scale = 0.227, foot = 3, range = 30, cooldown = 90, dtype = "acid",
    jets = { count = 3, spread = 3, radius = 2 }, puddle_share = 0.25,
    ingredients = { { "fo-methane-barrel", 100 }, { "fo-servo-motor", 50 }, { "fo-controller", 40 }, { "battery", 100 },
      { "steel-plate", 100 }, { "fo-optical-sensor", 100 }, { "plastic-bar", 100 } },
    lueur = { r = 0.55, g = 1.0, b = 0.35 },
  },
  {
    id = "demi-vie", src = "demi_vie", age = 9, kind = "unit-capsule", factory = "fo-robotics-bay", after = "fo-robot-mortar",
    ref = "chamfer", mu = 7500, time = 20, scale = 0.155, half = 0.8, range = 3, cooldown = 30, dtype = "explosion", speed = 0.16, single_use = true,
    blast = { radius = 12, edge = 0.5 }, contamination = { radius = 10, duration = 2700, period = 30, share = 0.005, dtype = "poison" },
    -- décision du DC (4/11, 19 h 48) : 100 circuits avancés et 70 servomoteurs à la place de 40 processeurs (âge 10, plus tard que
    -- la Demi-Vie) et 30 servomoteurs ; 7 178 MU contre 7 500 (0,957)
    ingredients = { { "uranium-238", 100 }, { "fo-lead-plate", 100 }, { "advanced-circuit", 100 }, { "fo-servo-motor", 70 },
      { "fo-controller", 30 }, { "steel-plate", 100 }, { "battery", 50 } },
    lueur = { r = 0.45, g = 1.0, b = 0.3 },
  },
  {
    id = "veilleuse", src = "veilleuse", age = 13, kind = "turret", factory = "fo-robot-gantry", after = "fo-robot-gantry",
    ref = "toroid", mu = 42000, time = 10, scale = 0.215, foot = 3, range = 40, cooldown = 120, dtype = "laser",
    drop = { radius = 4 },
    ingredients = { { "fo-superconducting-coil", 100 }, { "fo-laser-module", 100 }, { "fo-magnetic-actuator", 100 }, { "processing-unit", 100 },
      { "fo-graphics-card", 100 }, { "fo-guidance-core", 60 }, { "fo-titanium-plate", 100 } },
    lueur = { r = 1.0, g = 0.3, b = 0.85 },
  },
}

--- Palier 3, les 5 GÉANTS (FAISABILITE : Cairn, Stylet, Trombe, Tournesol ; Ixion du premier tableau). `spider-vehicle` sans arme : l'effet
--- part du script, à la cadence, vers l'ennemi le plus proche à portée. Chaîne : 10 segments (Dock, comme les géants de shared/content/robots.lua,
--- au plus 100 de chaque ingrédient) puis l'assemblage final (60 s) à l'usine de son âge. `mu` : coût de FAISABILITE (Ixion : non écrit,
--- celui du Torique, géant du même âge, déclaré). Corps : 1 image, flotte (pattes sans image, sans collision, comme le Bourdon).
--- `effect` : la règle de l'effet (voir plus bas) ; `range`, `cooldown` : portée (tuiles) et cadence (ticks) ; `split` : le coup est PARTAGÉ
--- entre les cibles (la valeur ne change pas avec le nombre de cibles).
Xp.SEGMENTS = 10
--- Corps d'un géant : « rendering » (sprites attachés à l'entité par le script : prouvé par le Bourdon, BO-2) ou « prototype »
--- (graphics_set.animation du spider-vehicle : essai E-XP1, palier 2).
Xp.GIANT_BODY = "rendering"
--- ART-GEANTS (11/11, F525) : corps ORIENTÉ. Ixion (roue de feu qui roule) a 16 directions de marche servies par 8 poses (une roue est la
--- même à 180° près : direction d -> pose d mod 8), feuilles de tools/render/pieces/experimentaux/feuilles_ixion_dirs.py (ixion_dirs.lua,
--- contrôlé par prototypes/experimentaux_geants.lua). Les quatre autres gardent UNE image par dessin (leur bible : Cairn, pile de galets qui
--- « ne se retourne pas » ; Stylet, lance verticale à 3 pans ; Trombe, entonnoir ; Tournesol, miroir tourné vers le soleil).
Xp.CORPS_DIRS = { ixion = { directions = 16, poses = 8 } }
--- Couches du corps dessinées par le script (rendering), dans l'ordre de dessin.
Xp.CORPS_COUCHES = { "ombre", "corps", "lueur-1" }

--- Pose du corps (0-based) d'un géant `id` pour l'orientation `o` (0 = nord, sens horaire, en tours ; celle du TORSE : la seule qu'un
--- spider-vehicle tient à jour, F507) ; nil pour un géant à une seule image. Arrondi au secteur le plus proche, sans trigonométrie.
function Xp.pose(id, o)
  local d = Xp.CORPS_DIRS[id]
  if not d then return nil end
  local n = d.directions
  local dir = math.floor((tonumber(o) or 0) * n + 0.5) % n
  return dir % d.poses
end

--- Nom du sprite d'une couche du corps (`couche` dans Xp.CORPS_COUCHES), pour une pose (0-based) ou sans pose (une image).
function Xp.sprite_corps(id, couche, pose)
  return Xp.PREFIX .. id .. "-" .. couche .. (pose and string.format("-d%02d", pose) or "")
end
Xp.SEGMENT_FACTORY = "fo-robot-dock"
Xp.GEANTS = {
  {
    id = "cairn", src = "cairn", age = 10, kind = "giant", factory = "fo-robot-dock", after = "fo-robot-dock", ref = "trowel", mu = 41000,
    time = 60, range = 40, cooldown = 180, dtype = "electric", speed = 0.12, effect = "balayage", marks = 8, delay = 30,
    segment = { ingredients = { { "processing-unit", 30 }, { "fo-guidance-core", 10 }, { "fo-servo-motor", 10 }, { "fo-controller", 10 },
      { "battery", 50 }, { "steel-plate", 50 } }, time = 30 },
    lueur = { r = 0.35, g = 0.75, b = 1.0 },
  },
  {
    id = "stylet", src = "stylet", age = 11, kind = "giant", factory = "fo-robot-dock", after = "fo-robot-finback", ref = "finback", mu = 75000,
    time = 60, range = 45, cooldown = 240, dtype = "electric", speed = 0.12, effect = "ecriture", nodes = 6, node_radius = 3, step_ticks = 4,
    segment = { ingredients = { { "fo-titanium-plate", 100 }, { "processing-unit", 40 }, { "fo-guidance-core", 20 }, { "fo-graphics-card", 10 },
      { "steel-plate", 100 } }, time = 30 },
    lueur = { r = 0.75, g = 0.9, b = 1.0 },
  },
  {
    id = "trombe", src = "trombe", age = 12, kind = "giant", factory = "fo-robot-dock", after = "fo-robot-levite", ref = "levite", mu = 137000,
    time = 60, range = 40, cooldown = 300, dtype = "physical", speed = 0.1, effect = "gel", freeze = 120,
    segment = { ingredients = { { "fo-superconducting-coil", 100 }, { "processing-unit", 50 }, { "fo-magnetic-actuator", 30 },
      { "fo-titanium-plate", 50 }, { "fo-graphics-card", 10 } }, time = 30 },
    lueur = { r = 0.6, g = 0.95, b = 1.0 },
  },
  {
    id = "ixion", src = "ixion", age = 13, kind = "giant", factory = "fo-robot-gantry", after = "fo-robot-gantry", ref = "toroid", mu = 251000,
    time = 60, range = 45, cooldown = 240, dtype = "fire", speed = 0.1, effect = "tranchee", step = 3, width = 3, step_ticks = 3, beyond = 10,
    segment = { ingredients = { { "fo-superconducting-coil", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 80 },
      { "fo-laser-module", 60 }, { "fo-titanium-plate", 100 } }, time = 30 },
    lueur = { r = 1.0, g = 0.55, b = 0.2 },
  },
  {
    id = "tournesol", src = "tournesol", age = 14, kind = "giant", factory = "fo-robot-gantry", after = "fo-robot-gantry-heliast", ref = "heliast",
    mu = 459000, time = 60, range = 60, cooldown = 30, dtype = "laser", speed = 0.09, effect = "foyer", night = 0.5, glass_every = 2,
    segment = { ingredients = { { "fo-superconducting-coil", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 100 },
      { "fo-laser-module", 100 }, { "fo-graphics-card", 100 }, { "fo-guidance-core", 100 }, { "fo-titanium-composite", 100 },
      { "low-density-structure", 50 } }, time = 30 },
    lueur = { r = 1.0, g = 0.85, b = 0.45 },
  },
}

local by_id = {}

function Xp.name(id) return Xp.PREFIX .. id end
function Xp.segment_name(id) return Xp.PREFIX .. "segment-" .. id end
function Xp.segment_recipe_name(id) return Xp.PREFIX .. "make-segment-" .. id end
function Xp.recipe_name(id) return Xp.PREFIX .. "make-" .. id end
function Xp.tech_name(id) return Xp.PREFIX .. id end

local function round(x, step)
  step = step or 1
  return math.floor(x / step + 0.5) * step
end

--- Statistiques d'un expérimental. Dégâts par seconde, coup (cadence) et charge d'un usage unique : valeur pour la valeur (référence × mu /
--- ref.mu). PV, résistances, salve par cible (et, pour un géant, zone, cratère, cadence de zone) : règle d'échelle par âge (Ech).
--- Un petit garde la forme de son attaque : chaque cible touchée prend au moins la salve de son âge (coup × nombre de jets).
function Xp.stats(r)
  local ref = Ro.robot(r.ref)
  assert(ref, "experimentaux : robot de reference absent " .. tostring(r.ref))
  local k = r.mu / ref.mu
  local dps = ref.dps * k
  local out = { k = k, dps = round(dps, 0.1), shot = round(dps * r.cooldown / 60, 0.1) }
  if r.single_use then out.burst = round(dps * Xp.BURST_SECONDS) end
  out.hp = Ech.pv(r.age)
  out.resistances = Ech.resistances(r.age)
  out.salve = Ech.salve(r.age, r.dtype)
  if r.kind == "giant" then
    out.zone, out.cratere = Ech.rayon(r.age), Ech.cratere(r.age)
    out.zone_cooldown = math.max(r.cooldown, Ech.CADENCE_ZONE)
  else
    out.shot = math.max(out.shot, out.salve * ((r.jets and r.jets.count) or 1))
  end
  return out
end

for _, r in ipairs(Xp.ROBOTS) do
  r.name = Xp.name(r.id)
  r.recipe = Xp.recipe_name(r.id)
  r.tech = Xp.tech_name(r.id)
  r.is_unit = r.kind == "unit-capsule"
  r.is_turret = not r.is_unit
  local s = Xp.stats(r)
  r.hp, r.dps, r.shot, r.burst, r.resistances, r.salve = s.hp, s.dps, s.shot, s.burst, s.resistances, s.salve
  by_id[r.id] = r
end
for _, r in ipairs(Xp.GEANTS) do
  r.name = Xp.name(r.id)
  r.recipe = Xp.recipe_name(r.id)
  r.tech = Xp.tech_name(r.id)
  r.is_giant = true
  r.segment_item = Xp.segment_name(r.id)
  r.segment_recipe = Xp.segment_recipe_name(r.id)
  r.ingredients = { { r.segment_item, Xp.SEGMENTS } }
  local s = Xp.stats(r)
  r.hp, r.dps, r.shot, r.resistances, r.salve = s.hp, s.dps, s.shot, s.resistances, s.salve
  r.zone, r.cratere, r.zone_cooldown = s.zone, s.cratere, s.zone_cooldown
  by_id[r.id] = r
end

--- Géants admis pour une force à l'âge `age`, géants de shared/content/robots.lua COMPRIS : le plafond de Ro.giant_allowed (1, 2, 3 aux
--- âges 13, 14, 15), et UN dès l'âge 10 (Cairn, Stylet, Trombe arrivent avant l'âge 13 : sans cela, ils ne sortiraient jamais).
--- PROPOSITION du lot, à trancher par le lead : voir RAPPORT.md.
Xp.GIANT_EARLY_AGE = 10
function Xp.giant_cap(age)
  age = math.floor(tonumber(age) or 1)
  local early = age >= Xp.GIANT_EARLY_AGE and 1 or 0
  return math.max(Ro.giant_allowed(age), early)
end

--- Un géant de plus est-il admis ? (déjà là : tous les géants vivants de la force, des deux familles)
function Xp.giant_ok(age, have)
  return (have or 0) < Xp.giant_cap(age)
end

function Xp.robot(id) return by_id[id] end

--- L'expérimental d'un nom d'entité ou d'objet (« fo-xp-<id> ») ; nil sinon.
function Xp.of_name(name)
  if type(name) ~= "string" or name:sub(1, #Xp.PREFIX) ~= Xp.PREFIX then return nil end
  return by_id[name:sub(#Xp.PREFIX + 1)]
end

--- Effet `script` de la capsule d'un attaquant.
function Xp.launch_effect(id) return Xp.EFFECT.lance .. "-" .. id end
--- L'attaquant d'un effet de capsule ; nil sinon.
function Xp.of_launch_effect(effect_id)
  local head = Xp.EFFECT.lance .. "-"
  if type(effect_id) ~= "string" or effect_id:sub(1, #head) ~= head then return nil end
  local r = by_id[effect_id:sub(#head + 1)]
  return r and r.is_unit and r or nil
end

---------------------------------------------------------------------------------------------------
-- Règles des effets (positions en tuiles ; listes de candidats { x =, y =, id = } où `id` est un entier unique : numéro d'unité)
---------------------------------------------------------------------------------------------------
local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

--- Le plus proche d'un point parmi des candidats (égalité : le plus petit id) ; nil si la liste est vide ou si tous sont au-delà de `max_d`.
function Xp.nearest(p, candidates, max_d)
  local best, bd
  local lim = max_d and max_d * max_d or math.huge
  for _, c in ipairs(candidates) do
    local d = d2(p, c)
    if d <= lim and (not best or d < bd or (d == bd and c.id < best.id)) then best, bd = c, d end
  end
  return best
end

--- Les sauts de l'arc (Mât-Foudre) : depuis la première cible, au plus `jumps` cibles de plus, chacune la plus proche de la précédente
--- dans `radius`, jamais deux fois la même, jamais la première. Rend la liste des candidats choisis, dans l'ordre des sauts.
function Xp.chain(first, candidates, jumps, radius)
  local out, used = {}, { [first.id] = true }
  local cur = first
  for _ = 1, jumps do
    local pool = {}
    for _, c in ipairs(candidates) do if not used[c.id] then pool[#pool + 1] = c end end
    local nx = Xp.nearest(cur, pool, radius)
    if not nx then break end
    out[#out + 1] = nx
    used[nx.id] = true
    cur = nx
  end
  return out
end

--- Les points des pointes (Géode) : `count` points de `from` à `to`, également espacés, le dernier SUR la cible.
function Xp.spike_points(from, to, count)
  local out = {}
  for i = 1, count do
    local t = i / count
    out[i] = { x = from.x + (to.x - from.x) * t, y = from.y + (to.y - from.y) * t }
  end
  return out
end

--- Les points d'arrivée des jets (Sarracénie) : la cible, puis des points écartés de `spread` tuiles de part et d'autre, perpendiculairement
--- à la direction du tir (quart de tour : pas de trigonométrie). `count` impair conseillé.
function Xp.jet_points(from, to, count, spread)
  local dx, dy = to.x - from.x, to.y - from.y
  local len = math.sqrt(dx * dx + dy * dy)
  local px, py = 0, 0
  if len > 1e-9 then px, py = -dy / len, dx / len end
  local out = { { x = to.x, y = to.y } }
  local k = 1
  while #out < count do
    local side = (#out % 2 == 1) and 1 or -1
    out[#out + 1] = { x = to.x + px * spread * k * side, y = to.y + py * spread * k * side }
    if side == -1 then k = k + 1 end
  end
  return out
end

--- Dégâts d'une explosion à la distance `d` du centre : `amount` au centre, `amount × edge` au bord du rayon, linéaire ; 0 au-delà.
function Xp.falloff(amount, d, radius, edge)
  if d > radius then return 0 end
  return amount * (1 - (1 - edge) * d / radius)
end

--- Une zone de contamination (Demi-Vie) : dégâts d'une impulsion à une cible dans le rayon.
function Xp.contamination_pulse(r)
  local c = r.contamination
  return r.burst * c.share
end

--- La zone vit-elle encore au tick `tick` (créée au tick `t0`) ?
function Xp.zone_alive(r, t0, tick)
  return tick - t0 < r.contamination.duration
end

--- Cibles d'un dégât de zone : les candidats dans le rayon (bord compris), triés par distance puis par id. Rend { { c =, d = } }.
function Xp.in_radius(p, candidates, radius)
  local out = {}
  local lim = radius * radius
  for _, c in ipairs(candidates) do
    local d = d2(p, c)
    if d <= lim then out[#out + 1] = { c = c, d = math.sqrt(d) } end
  end
  table.sort(out, function(a, b)
    if a.d ~= b.d then return a.d < b.d end
    return a.c.id < b.c.id
  end)
  return out
end

---------------------------------------------------------------------------------------------------
-- Règles des géants
---------------------------------------------------------------------------------------------------
--- Part de chaque cible quand un coup est partagé entre `n` cibles (au moins une).
function Xp.split(shot, n)
  return shot / math.max(1, n or 0)
end

--- Cairn, « Le Balayage » : les `n` cibles les plus proches dans la portée (distance, puis numéro).
function Xp.marks(p, candidates, n, range)
  local all = Xp.in_radius(p, candidates, range)
  local out = {}
  for i = 1, math.min(n, #all) do out[i] = all[i].c end
  return out
end

--- Stylet, « L'Écriture » : les nœuds (la cible, puis de proche en proche, au plus `n`, chacun à moins de `hop` tuiles du précédent)
--- et le tracé à angles droits qui les relie depuis `from` : liste de points (coude horizontal puis vertical à chaque nœud).
function Xp.circuit(from, target, candidates, n, hop)
  local nodes = { target }
  for _, c in ipairs(Xp.chain(target, candidates, n - 1, hop)) do nodes[#nodes + 1] = c end
  local pts = { { x = from.x, y = from.y } }
  local cur = pts[1]
  for _, nd in ipairs(nodes) do
    local corner = { x = nd.x, y = cur.y }
    if corner.x ~= cur.x then pts[#pts + 1] = corner end
    if nd.y ~= cur.y then pts[#pts + 1] = { x = nd.x, y = nd.y } end
    cur = { x = nd.x, y = nd.y }
  end
  return nodes, pts
end

--- Ixion, « La Tranchée » : points de la fissure, tous les `step` tuiles depuis `from` vers `to`, prolongée de `beyond` tuiles au-delà.
function Xp.fissure(from, to, step, beyond)
  local dx, dy = to.x - from.x, to.y - from.y
  local len = math.sqrt(dx * dx + dy * dy)
  local out = {}
  if len < 1e-9 then return out end
  local ux, uy = dx / len, dy / len
  local total = len + beyond
  local k = 1
  while k * step <= total + 1e-9 do
    out[#out + 1] = { x = from.x + ux * k * step, y = from.y + uy * k * step }
    k = k + 1
  end
  return out
end

--- Tournesol, « Le Foyer » : il ne tire que de jour (obscurité de la surface sous le seuil `night`).
function Xp.foyer_fires(darkness, night)
  return (darkness or 0) < night
end

--- Usine et catégorie de fabrication d'un expérimental (lues dans Ro.FACTORIES).
function Xp.category(r)
  local f = Ro.factory(r.factory)
  return f and f.category
end

return Xp
