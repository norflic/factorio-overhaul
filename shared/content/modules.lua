--[[
  Modules : 10 paliers par famille (1-3 = vanilla, inchangés ; 4-10 = mod). Pur Lua.

  Principes :
  - VITESSE : gain croissant (+20 % … +240 %) et coût énergétique qui croît moins vite que le gain :
    l'énergie par fabrication (1 + Σconso) / (1 + Σvitesse) BAISSE avec le palier → récompense réelle.
  - PRODUCTIVITÉ : +4 % … +40 % ; le malus de vitesse est plafonné à -15 % dès le palier 3
    (au-delà, les malus empilés tomberaient sur le plancher moteur de -80 % et rendraient le module absurde).
  - EFFICACITÉ : la consommation atteint le plancher moteur (-80 %) au palier 9 ; les paliers hauts
    réduisent en plus la pollution.
  Planchers moteur : vitesse, consommation et pollution ne descendent pas sous -80 % (20 % restants).
]]

local M = {}

M.TIERS = 10
M.VANILLA_TIERS = 3

M.families = {
  speed = {
    vanilla = { "speed-module", "speed-module-2", "speed-module-3" },
    tint = { { t = 0, c = { r = 0.55, g = 0.75, b = 1.00 } }, { t = 1, c = { r = 0.75, g = 0.35, b = 1.00 } } },
    effects = {
      speed       = { 0.20, 0.30, 0.50, 0.70, 0.90, 1.15, 1.40, 1.70, 2.00, 2.40 },
      consumption = { 0.50, 0.60, 0.70, 0.80, 0.90, 1.00, 1.10, 1.20, 1.30, 1.40 },
    },
    special_ingredient = "fo-resonance-crystal", -- le cristal de résonance accélère tout
  },
  productivity = {
    vanilla = { "productivity-module", "productivity-module-2", "productivity-module-3" },
    tint = { { t = 0, c = { r = 1.00, g = 0.70, b = 0.45 } }, { t = 1, c = { r = 1.00, g = 0.35, b = 0.25 } } },
    effects = {
      productivity = { 0.04, 0.06, 0.10, 0.13, 0.16, 0.20, 0.24, 0.28, 0.33, 0.40 },
      speed        = { -0.05, -0.10, -0.15, -0.15, -0.15, -0.15, -0.15, -0.15, -0.15, -0.15 },
      consumption  = { 0.40, 0.60, 0.80, 0.90, 1.00, 1.10, 1.20, 1.30, 1.40, 1.50 },
      pollution    = { 0.05, 0.07, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.22, 0.25 },
    },
    special_ingredient = "fo-tungsten-plate", -- matrice dense de tungstène
  },
  effectivity = {
    vanilla = { "effectivity-module", "effectivity-module-2", "effectivity-module-3" },
    tint = { { t = 0, c = { r = 0.55, g = 1.00, b = 0.55 } }, { t = 1, c = { r = 0.25, g = 1.00, b = 0.85 } } },
    effects = {
      consumption = { -0.30, -0.40, -0.50, -0.55, -0.60, -0.65, -0.70, -0.75, -0.80, -0.80 },
      pollution   = { 0, 0, 0, -0.05, -0.10, -0.15, -0.20, -0.25, -0.30, -0.40 },
    },
    special_ingredient = "low-density-structure",
  },
}

M.ORDER = { "speed", "productivity", "effectivity" }

function M.name(family, k)
  if k <= M.VANILLA_TIERS then return M.families[family].vanilla[k] end
  return "fo-" .. family .. "-module-" .. k
end

--- Effets du palier k au format prototype. Moteur réel (session 3) : le moteur tronque chaque effet au
--- pourcent entier ; 1.15 en flottant vaut 1.1499999… et devenait +114 %. Un epsilon positif garantit la
--- valeur voulue (les valeurs négatives arrivent déjà exactes).
local EPSILON = 1e-6

function M.effect(family, k)
  local e = {}
  for key, values in pairs(M.families[family].effects) do
    local v = values[k]
    if v ~= 0 then e[key] = { bonus = v > 0 and v + EPSILON or v } end
  end
  return e
end

--- Recette du palier k (k >= 4) : 2 × palier précédent + puces + ingrédient de famille.
function M.recipe(family, k)
  local n = k - M.VANILLA_TIERS
  return {
    ingredients = {
      { M.name(family, k - 1), 2 },
      { "processing-unit", 4 * n },
      { M.families[family].special_ingredient, 10 * n },
    },
    energy = 60 * 1.5 ^ (n - 1),
  }
end

--- Technologie du palier k (k >= 4).
function M.technology(family, k)
  local n = k - M.VANILLA_TIERS
  local packs = { "automation-science-pack", "logistic-science-pack", "chemical-science-pack",
    "production-science-pack", "utility-science-pack" }
  if k >= 6 then packs[#packs + 1] = "space-science-pack" end
  return {
    count = 300 * 2 ^ n,
    packs = packs,
    time = 60,
    prerequisite = (k - 1 <= M.VANILLA_TIERS) and M.name(family, k - 1) or ("fo-" .. family .. "-module-" .. (k - 1)),
  }
end

--- Indicateurs pour BALANCE_SHEET : machine à 4 emplacements remplis du même module.
function M.metrics(family, k, slots)
  slots = slots or 4
  local e = M.families[family].effects
  local function sum(key) return slots * ((e[key] and e[key][k]) or 0) end
  local function floor80(x) return math.max(x, -0.8) end
  local speed = 1 + floor80(sum("speed"))
  local energy = 1 + floor80(sum("consumption"))
  local prod = 1 + math.max(0, sum("productivity"))
  local pollution = (1 + floor80(sum("pollution"))) * energy
  return {
    speed = speed,
    energy = energy,
    output = speed * prod,
    energy_per_output = energy / (speed * prod),
    pollution = pollution,
  }
end

return M
