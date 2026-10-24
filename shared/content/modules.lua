--[[
  Modules : 10 paliers par famille (1-3 = objets vanilla ; 4-10 = mod). Pur Lua.

  Principes :
  - VITESSE (lot MOD-1, décision D-15 du Directeur Créatif, 24/10) : +50 %, +80 %, +110 %, puis +30 points par
    palier (+320 % au palier 10), paliers 1 à 3 VANILLA COMPRIS (leurs effets sont réécrits) ; énergie = 60 % du
    bonus de vitesse (+50 % de vitesse → +30 % d'énergie). Les modules d'une machine se MULTIPLIENT (vitesse et
    énergie) : shared/content/module_mult.lua.
  - PRODUCTIVITÉ : +4 % … +40 % ; le malus de vitesse est plafonné à -15 % dès le palier 3
    (au-delà, les malus empilés tomberaient sur le plancher moteur de -80 % et rendraient le module absurde).
  - EFFICACITÉ : la consommation atteint le plancher moteur (-80 %) au palier 9 ; les paliers hauts
    réduisent en plus la pollution.
  Planchers moteur : vitesse, consommation et pollution ne descendent pas sous -80 % (20 % restants).
]]

local M = {}

-- Règle multiplicative (lot MOD-1). Le mod de test (fo-autotest) requiert ce fichier par « __factorio-overhaul__/… » :
-- le second chemin couvre ce cas (même règle que shared/levels/config.lua).
local MM
do
  local ok, res = pcall(require, "shared.content.module_mult")
  if ok and type(res) == "table" then MM = res else MM = require("__factorio-overhaul__/shared/content/module_mult") end
end
M.mult = MM

M.TIERS = 10
M.VANILLA_TIERS = 3

--- D-15 : bonus de vitesse par palier, en CENTIÈMES (entiers) : 50, 80, 110, puis +30 par palier.
M.SPEED_CENTS = { 50, 80, 110, 140, 170, 200, 230, 260, 290, 320 }
--- D-15 : l'énergie ajoutée par un module de vitesse vaut 60 % de son bonus de vitesse (en dixièmes : 6 / 10).
M.SPEED_ENERGY_SHARE_TENTHS = 6

--- Énergie (centièmes) d'un module de vitesse de bonus `speed_cents` : 60 % du bonus, entier (exact ici : les bonus
--- sont des multiples de 10).
function M.speed_energy_cents(speed_cents)
  return math.floor(speed_cents * M.SPEED_ENERGY_SHARE_TENTHS / 10 + 0.5)
end

local function speed_effects()
  local speed, consumption = {}, {}
  for k, c in ipairs(M.SPEED_CENTS) do
    speed[k] = c / 100
    consumption[k] = M.speed_energy_cents(c) / 100
  end
  return speed, consumption
end
local SPEED, SPEED_CONSUMPTION = speed_effects()

M.families = {
  speed = {
    vanilla = { "speed-module", "speed-module-2", "speed-module-3" },
    tint = { { t = 0, c = { r = 0.55, g = 0.75, b = 1.00 } }, { t = 1, c = { r = 0.75, g = 0.35, b = 1.00 } } },
    -- Lot MOD-1 (D-15) : avant, vitesse 0,20 … 2,40 et énergie 0,50 … 1,40 (paliers 1 à 3 vanilla inchangés).
    effects = {
      speed       = SPEED,              -- 0,50 0,80 1,10 1,40 1,70 2,00 2,30 2,60 2,90 3,20
      consumption = SPEED_CONSUMPTION,  -- 0,30 0,48 0,66 0,84 1,02 1,20 1,38 1,56 1,74 1,92
    },
    vanilla_overridden = true, -- paliers 1 à 3 : effets des objets vanilla réécrits (prototypes/modules.lua)
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

--- Effets du palier k en CENTIÈMES entiers (valeurs voulues), clés triées : { speed = 50, consumption = 30 }.
function M.cents(family, k)
  local out = {}
  local keys = {}
  for key in pairs(M.families[family].effects) do keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local v = M.families[family].effects[key][k]
    if v ~= 0 then
      local x = v * 100
      out[key] = x >= 0 and math.floor(x + 0.5) or -math.floor(-x + 0.5)
    end
  end
  return out
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

--- Indicateurs pour BALANCE_SHEET : machine à 4 emplacements remplis du même module. Lot MOD-1 (D-15) : vitesse et
--- énergie MULTIPLIÉES (shared/content/module_mult.lua, plafond × 328,67), productivité et pollution additives.
function M.metrics(family, k, slots)
  slots = slots or 4
  local e = M.families[family].effects
  local c = M.cents(family, k)
  local function sum(key) return slots * ((e[key] and e[key][k]) or 0) end
  local function floor80(x) return math.max(x, -0.8) end
  local function product(key)
    local list = {}
    for _ = 1, (c[key] and slots or 0) do list[#list + 1] = c[key] end
    return MM.target(list) / 100
  end
  local speed = product("speed")
  local energy = product("consumption")
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
