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
  - CHIFFRES PROVISOIRES, NON CALIBRÉS par rb-duel : « valeur pour la valeur ». Un expérimental vaut, en PV et en dégâts par seconde, le robot
    de référence de son âge (`ref`, lu dans Ro.ROBOTS) multiplié par le rapport des coûts en MU (mu / ref.mu) ; une défense posée a HP_POSE fois
    ces PV. Si robotsjeu recalibre ses robots, ces chiffres suivent.
  - TOUS les dégâts passent par le script (entity.damage, jamais sur la force du tireur ni ses amis, ni en cessez-le-feu) : l'attaque du moteur
    ne lève qu'un effet `script` ; on mesure donc exactement ce qui est infligé (journal [FO-XP]). Seules les flaques de la Sarracénie
    (feu d'acide vanilla) piquent aussi par le moteur, sur les unités au sol ennemies.
  Déterminisme : listes, aucun pairs, aucun hasard, aucune trigonométrie (positions par interpolation linéaire et rotations d'un quart de tour).
]]

local Ro = require("shared.content.robots")

local Xp = {}

Xp.PREFIX = "fo-xp-"
Xp.AMMO_CATEGORY = "fo-xp"
Xp.SUBGROUP = "fo-robots-xp"
Xp.LOG = "[FO-XP]"
Xp.HP_POSE = 3        -- une défense posée a 3 fois les PV de la valeur (elle ne fuit pas, elle encaisse)
Xp.BURST_SECONDS = 30 -- usage unique : la charge vaut 30 s de dégâts de la valeur

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

--- Les petits (FAISABILITE, tableau « La famille »). `kind` : turret-electric, turret, unit-capsule. `foot` : côté de l'emprise (tuiles) d'une
--- défense posée ; `half` : demi-boîte d'une unité. `src` : dossier des sources (fo-logs/2026-10-31_ROBOTS/experimentaux/final/sprites).
--- `ref` : robot de même âge (ou du dernier âge qui en a un qui tire) dont on tire la valeur. `after` : technologie de robot de l'époque.
Xp.ROBOTS = {
  {
    id = "mat-foudre", src = "mat_foudre", age = 6, kind = "turret-electric", factory = "fo-robot-workshop", after = "fo-robot-coil",
    ref = "coiler", mu = 1800, time = 30, foot = 7, range = 24, cooldown = 60, dtype = "electric",
    chain = { jumps = 2, radius = 8, share = 0.5 },
    ingredients = { { "battery", 100 }, { "steel-plate", 100 }, { "engine-unit", 60 }, { "copper-cable", 100 }, { "electronic-circuit", 60 } },
    lueur = { r = 0.35, g = 0.9, b = 1.0 },
  },
  {
    id = "geode", src = "geode", age = 7, kind = "unit-capsule", factory = "fo-robotics-bay", after = "fo-robot-bay",
    ref = "needle", mu = 3400, time = 30, half = 1.0, range = 20, cooldown = 120, dtype = "physical", speed = 0.10,
    spikes = { count = 8, step_ticks = 3, radius = 1.5, share = 0.1, final_radius = 2.5 },
    ingredients = { { "fo-resonance-crystal", 100 }, { "fo-servo-motor", 30 }, { "battery", 100 }, { "steel-plate", 100 },
      { "fo-optical-sensor", 40 }, { "fo-controller", 18 } },
    lueur = { r = 0.62, g = 0.3, b = 1.0 },
  },
  {
    id = "sarracenie", src = "sarracenie", age = 8, kind = "turret", factory = "fo-robotics-bay", after = "fo-robot-bellwether",
    ref = "needle", mu = 6200, time = 30, foot = 9, range = 30, cooldown = 90, dtype = "acid",
    jets = { count = 3, spread = 3, radius = 2 }, puddle_share = 0.25,
    ingredients = { { "fo-methane-barrel", 100 }, { "fo-servo-motor", 50 }, { "fo-controller", 40 }, { "battery", 100 },
      { "steel-plate", 100 }, { "fo-optical-sensor", 100 }, { "plastic-bar", 100 } },
    lueur = { r = 0.55, g = 1.0, b = 0.35 },
  },
  {
    id = "demi-vie", src = "demi_vie", age = 9, kind = "unit-capsule", factory = "fo-robotics-bay", after = "fo-robot-mortar",
    ref = "chamfer", mu = 7500, time = 20, half = 1.2, range = 3, cooldown = 30, dtype = "explosion", speed = 0.16, single_use = true,
    blast = { radius = 12, edge = 0.5 }, contamination = { radius = 10, duration = 2700, period = 30, share = 0.005, dtype = "poison" },
    ingredients = { { "uranium-238", 100 }, { "fo-lead-plate", 100 }, { "processing-unit", 40 }, { "fo-servo-motor", 30 },
      { "fo-controller", 30 }, { "steel-plate", 100 }, { "battery", 50 } },
    lueur = { r = 0.45, g = 1.0, b = 0.3 },
  },
  {
    id = "veilleuse", src = "veilleuse", age = 13, kind = "turret", factory = "fo-robot-gantry", after = "fo-robot-gantry",
    ref = "toroid", mu = 42000, time = 10, foot = 11, range = 40, cooldown = 120, dtype = "laser",
    drop = { radius = 4 },
    ingredients = { { "fo-superconducting-coil", 100 }, { "fo-laser-module", 100 }, { "fo-magnetic-actuator", 100 }, { "processing-unit", 100 },
      { "fo-graphics-card", 100 }, { "fo-guidance-core", 60 }, { "fo-titanium-plate", 100 } },
    lueur = { r = 1.0, g = 0.3, b = 0.85 },
  },
}

local by_id = {}

function Xp.name(id) return Xp.PREFIX .. id end
function Xp.recipe_name(id) return Xp.PREFIX .. "make-" .. id end
function Xp.tech_name(id) return Xp.PREFIX .. id end

local function round(x, step)
  step = step or 1
  return math.floor(x / step + 0.5) * step
end

--- Statistiques d'un expérimental : PV, dégâts par seconde, dégâts d'un coup (cadence), charge d'un usage unique.
--- Valeur pour la valeur : référence × mu / ref.mu ; une défense posée a HP_POSE fois les PV.
function Xp.stats(r)
  local ref = Ro.robot(r.ref)
  assert(ref, "experimentaux : robot de reference absent " .. tostring(r.ref))
  local k = r.mu / ref.mu
  local dps = ref.dps * k
  local hp = ref.hp * k
  if r.kind ~= "unit-capsule" then hp = hp * Xp.HP_POSE end
  local out = { k = k, dps = round(dps, 0.1), hp = round(hp), shot = round(dps * r.cooldown / 60, 0.1) }
  if r.single_use then out.burst = round(dps * Xp.BURST_SECONDS) end
  return out
end

for _, r in ipairs(Xp.ROBOTS) do
  r.name = Xp.name(r.id)
  r.recipe = Xp.recipe_name(r.id)
  r.tech = Xp.tech_name(r.id)
  r.is_unit = r.kind == "unit-capsule"
  r.is_turret = not r.is_unit
  local s = Xp.stats(r)
  r.hp, r.dps, r.shot, r.burst = s.hp, s.dps, s.shot, s.burst
  by_id[r.id] = r
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

--- Usine et catégorie de fabrication d'un expérimental (lues dans Ro.FACTORIES).
function Xp.category(r)
  local f = Ro.factory(r.factory)
  return f and f.category
end

return Xp
