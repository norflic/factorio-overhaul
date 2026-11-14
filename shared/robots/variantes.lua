--[[
  Lot s43-robots (14/11) : VARIANTES complémentaires de la gamme des 12 robots (pilier C, « ajoute et équilibre de nouvelles
  variantes de robots complémentaires »). Lua PUR : lu par shared/content/robots.lua (qui les ajoute à Ro.ROBOTS, APRÈS les 12 du
  plan) et par tests/s43_robots_test.lua.

  Trous de rôle comblés (recensement de la gamme, PLAN fo-logs/2026-10-31_ROBOTS §2) :
    - aucun soutien avant l'âge 8 (Cloche)          -> Rafistoleur (âge 4, petit, soin de terrain) ;
    - aucun robot rapide avant l'âge 11 (Aileron)   -> Furet (âge 5, petit, éclaireur à 0,22 tuile par tick) ;
    - aucun tir lourd à coup unique (anti-blindé)   -> Perce-Blindage (âge 8, moyen, gros coup lent à longue portée : un tir
      lourd use moins la résistance FIXE des déchiqueteurs blindés qu'une rafale de même DPS).
  Chaque variante est DÉRIVÉE d'un robot parent par une règle pure (V.derive) : forme (hp0, dmg0, cadence), portée, vitesse,
  classe, et coût visé V.cost = V.mu(classe, âge) (secondes de la classe × débit de fin d'âge, X.rate, la règle du plan §2) × la prime
  de vitesse V.prime. Les PV et les
  dégâts sont ensuite CALIBRÉS par shared/robots/duel.lua comme pour les 12 (tests/robots_duel_test.lua contrôle l'égalité ;
  `lua5.2 tests/robots_duel_test.lua --calibrer` les imprime). Visuel : la feuille du parent (`look.sheet`), mise à l'échelle
  et teinte (aucun rendu neuf, verrou Blender saturé).
  CHOIX D'ÉQUILIBRAGE PROVISOIRES (le DC tranchera) : facteurs de V.SPECS, âges 4, 5 et 8 (8 et non 9 : les packs de l'âge 9
  ont changé au lot XP-COUTS, tests/xp_couts_test.lua fige leur liste), rayon et cibles du soin.
  Le cerveau ne lit aucun de ces noms : il voit trois unités de plus dans le catalogue des prototypes (PV, DPS, portée,
  portée minimale) et les classe par ses règles (soutien = DPS 0).
]]

local X = require("shared.content.epochs")

local V = {}

--- Secondes du débit de fin d'âge qu'une classe coûte (PLAN §2 : P 10 s, M 20 s, G 30 s), plancher 200 MU.
V.SECONDS = { P = 10, M = 20, G = 30 }
V.MU_FLOOR = 200
--- Demi-boîte par classe (tests/robots_test.lua : P ±0,4, M ±0,6, G ±0,9).
V.HALF = { P = 0.4, M = 0.6, G = 0.9 }
--- Image du parent ramenée à la classe de la variante : rapport des demi-boîtes, puis le facteur propre `look.k` de la spec.
V.VITESSE_MAX = 0.24 -- l'Aileron (âge 11) reste le plus rapide de la gamme

--- Coût visé (MU) d'une classe à un âge, arrondi à la dizaine.
function V.mu(class, age)
  local s = V.SECONDS[class] or V.SECONDS.M
  return math.max(V.MU_FLOOR, math.floor(s * X.rate(age) / 10 + 0.5) * 10)
end

--- Prime de vitesse : une variante plus rapide que son parent coûte (vitesse ÷ vitesse du parent)² de plus (l'énergie cinétique
--- se paie) ; plus lente, elle ne coûte pas moins. Sans elle, le Furet (calibré pour gagner le duel de son âge comme tout robot)
--- valait 1,54 en valeur ÷ coût au cerveau, deux fois le Trotte-Vapeur : l'éclaireur aurait remplacé toute la ligne des âges 5 et 6.
function V.prime(speed_factor)
  local f = math.max(1, speed_factor or 1)
  return f * f
end

--- Coût visé d'une variante : V.mu × V.prime, arrondi à la dizaine.
function V.cost(s)
  return math.floor(V.mu(s.class, s.age) * V.prime(s.f and s.f.speed) / 10 + 0.5) * 10
end

--- Les variantes : parent, âge, classe, rôle, facteurs de forme ; usine, ingrédients (au plus 100 de chaque) ; calibrage écrit
--- (`hp`, `damage`, `heal`) : sorties de Duel.calibrate / calibrate_all, jamais à la main ; teinte de la feuille du parent.
V.SPECS = {
  {
    id = "mender", parent = "bellwether", age = 4, class = "P", role = "support-light", factory = "fo-robot-workshop",
    -- soin de terrain : moins de cibles, rayon plus court que la Cloche
    f = { range = 2 / 3, speed = 1.2 }, heal = { radius = 8, max = 6, period = 60 }, tons = 2,
    ingredients = { { "engine-unit", 10 }, { "steel-plate", 20 }, { "plastic-bar", 50 }, { "electronic-circuit", 20 } }, time = 8,
    calibre = { hp = 926, heal = 207 * 0.1 }, -- 207 × 0,1 : le produit exact de Duel.sig3
    look = { k = 1, tint = { r = 0.70, g = 1.00, b = 0.55 } },
    tech = { name = "fo-robot-mender", epoch = 4, count = 110, time = 30, prerequisites = { "fo-robot-automata" } },
  },
  {
    id = "skitter", parent = "steam-trotter", age = 5, class = "P", role = "scout", factory = "fo-robot-workshop",
    -- éclaireur : 60 % de la masse de feu du Trotte-Vapeur, tir plus serré, plus loin, 1,6 fois plus vite
    f = { hp0 = 0.6, dmg0 = 0.4, cooldown = 2 / 3, range = 22 / 18, speed = 1.6 }, tons = 1.5,
    ingredients = { { "engine-unit", 40 }, { "steel-plate", 30 }, { "fo-tungsten-plate", 100 }, { "plastic-bar", 60 },
      { "electronic-circuit", 40 } }, time = 10,
    calibre = { hp = 1340, damage = 49.7 },
    look = { k = 0.85, tint = { r = 0.95, g = 0.92, b = 0.70 } },
    tech = { name = "fo-robot-skitter", epoch = 5, count = 120, time = 30, prerequisites = { "fo-robot-heavy" } },
  },
  {
    id = "lancer", parent = "needle", age = 8, class = "M", role = "anti-armor", factory = "fo-robotics-bay", dtype = "physical",
    -- anti-blindé : même DPS de forme que l'Aiguille mais en coups 2,5 fois plus lourds et plus lents, physiques, plus loin
    f = { hp0 = 0.8, dmg0 = 2.5, cooldown = 2.5, range = 42 / 36, speed = 0.8 }, tons = 4.5,
    ingredients = { { "fo-resonance-crystal", 100 }, { "battery", 100 }, { "fo-servo-motor", 40 }, { "fo-controller", 30 },
      { "fo-optical-sensor", 60 }, { "steel-plate", 50 } }, time = 25,
    calibre = { hp = 5870, damage = 5510 },
    look = { k = 1.15, tint = { r = 0.95, g = 0.55, b = 0.45 } },
    tech = { name = "fo-robot-lancer", epoch = 8, count = 150, time = 30, prerequisites = { "fo-robot-bay" } },
  },
}

local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end

--- Forme d'une variante dérivée de son parent `p` (entrée de Ro.ROBOTS) : rend une entrée au format de Ro.ROBOTS, PV et dégâts
--- pris au calibrage écrit (`s.calibre`). Pure : mêmes entrées, même sortie.
function V.derive(p, s)
  local f = s.f or {}
  local cd = math.max(1, math.floor(p.shot.cooldown * (f.cooldown or 1) + 0.5))
  local r = {
    id = s.id, age = s.age, class = s.class, role = s.role, factory = s.factory, dtype = s.dtype or p.dtype, variant = p.id,
    hp0 = math.floor(p.hp0 * (f.hp0 or 1) + 0.5), dmg0 = s.heal and 0 or math.floor(p.dmg0 * (f.dmg0 or 1) + 0.5),
    range = math.floor(p.range * (f.range or 1) + 0.5), speed = r3(math.min(V.VITESSE_MAX, p.speed * (f.speed or 1))),
    half = V.HALF[s.class], tons = s.tons, ingredients = s.ingredients, time = s.time, mu = V.cost(s),
    hp = s.calibre.hp,
    look = { sheet = p.id, scale = r3((V.HALF[s.class] / p.half) * (s.look.k or 1)), tint = s.look.tint },
  }
  if s.heal then
    r.hp_rule = "screen"
    r.heal = { amount = s.calibre.heal, radius = s.heal.radius, max = s.heal.max, period = s.heal.period }
    r.shot = { damage = 0, cooldown = cd }
  else
    r.shot = { damage = s.calibre.damage, cooldown = cd }
  end
  return r
end

--- Les variantes dérivées, dans l'ordre de V.SPECS ; `lookup(id)` rend le parent (Ro.robot).
function V.build(lookup)
  local out = {}
  for _, s in ipairs(V.SPECS) do out[#out + 1] = V.derive(assert(lookup(s.parent), "variante sans parent : " .. s.parent), s) end
  return out
end

--- Technologies des variantes (format de Ro.TECHS : une par variante).
function V.techs()
  local out = {}
  for _, s in ipairs(V.SPECS) do
    local t = s.tech
    out[#out + 1] = { name = t.name, epoch = t.epoch, count = t.count, time = t.time, prerequisites = t.prerequisites, robots = { s.id } }
  end
  return out
end

return V
