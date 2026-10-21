--[[
  Mode DÉFENSE DE TOURS — règles pures (aucune API Factorio), testables hors-jeu.

  Une partie de défense = une suite de vagues numérotées. Entre deux vagues, une phase de construction
  (compte à rebours affiché). Chaque vague dispose d'un BUDGET qui croît géométriquement ; il est dépensé
  en déchiqteurs dont le coût suit leur palier (8 paliers, shared/content/enemies.lua). Les familles à
  mécaniques (blindée, ignée, couvée, foudroyante) entrent progressivement, chacune obligeant à changer
  de défense. Toutes les 5 vagues : vague de BOSS (une unité de palier élevé et son escorte).
]]

local E = require("shared.content.enemies")

local TD = {}

TD.first_delay = 120 * 60          -- phase de construction avant la vague 1 (activable à tout moment)
TD.boss_every = 5
TD.spawn_per_second = 12           -- apparition progressive (pas de pic de création d'entités)
TD.wave_timeout = 6 * 3600         -- une vague qui ne finit pas (unités bloquées) est rappelée
TD.spawn_distance = 190            -- tuiles du centre de la base
TD.target_radius = 40

-- Coût d'une unité par palier (≈ PV relatifs, écrasés pour garder des vagues lisibles).
TD.unit_cost = { 1, 3, 10, 30, 90, 260, 700, 2000 }

-- Vague à partir de laquelle chaque famille peut apparaître.
TD.family_from = { armored = 4, pyro = 7, brood = 9, storm = 12 }
local FAMILY_ROTATION = { "armored", "pyro", "brood", "storm" }

function TD.build_ticks(wave)
  return math.max(45, 120 - 3 * wave) * 60
end

function TD.budget(wave)
  return math.floor(24 * 1.3 ^ (wave - 1))
end

-- Moteur réel (session 4) : avec un palier de plus toutes les 3 vagues et un boss énorme dès la vague 5,
-- une base de 12 mitrailleuses sans recherche tombait à la vague 5 (~10 min) ; les paliers montent
-- désormais toutes les 4 vagues et le boss suit 2 + vague / 5 (gros à 5, énorme à 10, colossal à 15...).
function TD.max_tier(wave)
  return math.min(E.TIERS, 1 + math.floor(wave / 4))
end

function TD.boss_tier(wave)
  return math.min(E.TIERS, 2 + math.floor(wave / TD.boss_every))
end

function TD.spawn_points(wave)
  if wave < 5 then return 1 end
  if wave < 12 then return 2 end
  return 3
end

function TD.is_boss(wave)
  return wave % TD.boss_every == 0
end

--- Familles disponibles à cette vague.
function TD.families(wave)
  local out = {}
  for _, f in ipairs(FAMILY_ROTATION) do
    if wave >= TD.family_from[f] then out[#out + 1] = f end
  end
  return out
end

--- Composition d'une vague : { { name, count }, ... } (tri déterministe), boss éventuel en tête.
--- rng() renvoie un flottant dans [0, 1) (générateur déterministe de l'appelant).
function TD.compose(wave, rng)
  local budget = TD.budget(wave)
  local top = TD.max_tier(wave)
  local fams = TD.families(wave)
  local counts, order = {}, {}
  local function add(name, n)
    if n <= 0 then return end
    if not counts[name] then
      counts[name] = 0
      order[#order + 1] = name
    end
    counts[name] = counts[name] + n
  end

  if TD.is_boss(wave) then
    local tier = TD.boss_tier(wave)
    local fam = #fams > 0 and fams[(math.floor(wave / TD.boss_every) - 1) % #fams + 1] or nil
    add(E.unit_name("biter", tier, fam), 1)
    budget = math.floor(budget * 0.7) -- l'escorte
  end

  -- 55 % du budget au palier le plus haut abordable, le reste en paliers inférieurs.
  local share = { 0.55, 0.3, 0.15 }
  for i = 1, 3 do
    local tier = math.max(1, top - (i - 1))
    local cost = TD.unit_cost[tier]
    local spend = budget * share[i]
    local n = math.floor(spend / cost)
    if i == 3 then n = math.floor(budget / cost) end -- reliquat
    if n > 0 then
      local spitters = math.floor(n * 0.3)
      local biters = n - spitters
      for _, kind in ipairs({ { "biter", biters }, { "spitter", spitters } }) do
        local fam = nil
        if #fams > 0 and rng() < 0.45 then fam = fams[math.floor(rng() * #fams) + 1] end
        add(E.unit_name(kind[1], tier, fam), kind[2])
      end
      budget = budget - n * cost
    end
  end

  local out = {}
  for _, name in ipairs(order) do out[#out + 1] = { name, counts[name] } end
  return out
end

function TD.total(list)
  local n = 0
  for _, it in ipairs(list) do n = n + it[2] end
  return n
end

--- Récompense d'une vague tenue (objets donnés à chaque joueur connecté de la force défendue).
function TD.reward(wave)
  local r = {
    { "iron-plate", 40 + 20 * wave },
    { "copper-plate", 20 + 10 * wave },
    { "piercing-rounds-magazine", 10 + 4 * wave },
  }
  if wave >= 4 then r[#r + 1] = { "steel-plate", 5 * wave } end
  if wave >= 8 then r[#r + 1] = { "fo-tungsten-plate", 4 * wave } end
  if TD.is_boss(wave) then
    r[#r + 1] = { "fo-resonance-crystal", 10 * wave }
    r[#r + 1] = { "processing-unit", wave }
  end
  return r
end

return TD
