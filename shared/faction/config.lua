--[[
  Factions IA : paramètres. Pur Lua (partagé par les prototypes, le runtime et le simulateur hors-jeu).

  Architecture à deux classes d'agents (ARCHITECTURE.md §4) :
  - Ingénieurs : agents RICHES (corps "character", pathfinding scripté), ils construisent les avant-postes.
  - Soldats    : agents DE MASSE (prototypes "unit" humanoïdes, IA moteur), coût script par GROUPE.
]]

local F = {}

F.MAX_FACTIONS = 4

F.factions = {
  { key = "scarlet", color = { r = 0.85, g = 0.18, b = 0.16 }, personality = "conqueror" },
  { key = "azure",   color = { r = 0.20, g = 0.45, b = 0.95 }, personality = "technocrat" },
  { key = "emerald", color = { r = 0.20, g = 0.80, b = 0.30 }, personality = "builder" },
  { key = "amber",   color = { r = 0.95, g = 0.70, b = 0.10 }, personality = "balanced" },
}

-- Personnalités : pondérations de la stratégie (1 = neutre).
F.personalities = {
  conqueror  = { greed = 1.0, aggression = 1.5, research = 0.8, keep = 0.20 },
  technocrat = { greed = 1.0, aggression = 0.8, research = 1.6, keep = 0.35 },
  builder    = { greed = 1.5, aggression = 0.7, research = 1.0, keep = 0.40 },
  balanced   = { greed = 1.0, aggression = 1.0, research = 1.0, keep = 0.30 },
}

-- Soldats (débloqués par niveau technologique de la faction).
F.soldier_order = { "rifleman", "gunner", "rocketeer" }
F.soldiers = {
  rifleman  = { tech = 0, cost = 40, hp = 200, damage = 8,  range = 16, cooldown = 20,  armor = 1, speed = 0.12 },
  gunner    = { tech = 1, cost = 110, hp = 600, damage = 14, range = 20, cooldown = 10,  armor = 2, speed = 0.11 },
  rocketeer = { tech = 2, cost = 160, hp = 450, damage = 80, range = 26, cooldown = 120, armor = 3, speed = 0.11, rocket = true },
}

F.economy = {
  start_mu = 400,
  hq_income = 1.0,            -- MU/s du QG seul au départ
  hq_income_growth = 0.1,     -- +0.1 MU/s par minute de guerre (production interne du QG)
  hq_income_max = 5.0,
  engineer_cost = 100,
  outpost_cost = 150,
  drills_per_outpost = 4,
  drill_rate = 0.5,           -- MU/s par foreuse (foreuse électrique vanilla : 0.5 minerai/s)
  tech_income_mult = 1.25,    -- revenu des avant-postes × 1.25 par niveau technologique
  research_base = 1200,
  research_share = 0.15,      -- part du revenu versée au fonds de recherche (× pondération de personnalité)
  research_growth = 2,
  max_tech = 5,
  underdog_bonus = 0.75,      -- rattrapage : revenu × (1 + 0.75 × retard relatif de territoire)
  upgrade_base = 4000,        -- améliorations militaires sans fin (puits de ressources de fin de partie)
  upgrade_growth = 1.5,
  upgrade_damage = 0.10,      -- +10 % de dégâts (balles, roquettes, tourelles) par niveau
  turret_refill_mags = 20,
  mag_cost = 1,
  build_ticks = 600,          -- 10 s de chantier
}

F.military = {
  attack_base = 20,           -- taille minimale d'une attaque (divisée par l'agressivité)
  train_batch = 5,
  staging_step = 96,          -- distance entre étapes d'une marche longue (hypothèse H-F2)
  attack_radius = 24,
  hq_turrets = 4,
}

F.defaults = {
  soldiers_max = 100,
  engineers_max = 10,
  distance = 480,              -- session 3 : à 320, les QG sont dans la zone de fondu des gisements (peu de sites)
  think_period = 300,         -- ticks entre deux décisions d'un commandant
}

function F.research_cost(tech)
  return F.economy.research_base * F.economy.research_growth ^ tech
end

--- Part du revenu réservée à la recherche pour une personnalité.
function F.research_share(personality)
  local P = F.personalities[personality] or F.personalities.balanced
  return F.economy.research_share * P.research
end

function F.hq_income(minutes)
  return F.economy.hq_income + math.min(F.economy.hq_income_max - F.economy.hq_income, F.economy.hq_income_growth * minutes)
end

--- Choix de cible : coalition contre le leader. Une faction attaque en priorité celle qui possède nettement
--- plus de territoire qu'elle ; sinon son rival désigné (le voisin le plus proche en jeu).
--- others = { { id, outposts }, ... } ; renvoie l'id ciblé.
function F.pick_target(own_outposts, rival_id, others)
  local leader, best = nil, -1
  for _, o in ipairs(others) do
    if o.outposts > best then leader, best = o.id, o.outposts end
  end
  if leader and best > math.max(2, own_outposts * 1.3) then return leader end
  return rival_id
end

F.RAID_MIN_SURVIVORS = 10

function F.upgrade_cost(level)
  return F.economy.upgrade_base * F.economy.upgrade_growth ^ level
end

--- Multiplicateur de rattrapage : une faction en retard de territoire produit davantage.
function F.underdog_multiplier(own_outposts, avg_outposts)
  if avg_outposts <= 0 then return 1 end
  local lag = (avg_outposts - own_outposts) / avg_outposts
  if lag < 0 then lag = 0 elseif lag > 1 then lag = 1 end
  return 1 + F.economy.underdog_bonus * lag
end

--- Tourelles par avant-poste selon le niveau technologique.
function F.outpost_turrets(tech)
  return tech >= 2 and 2 or 1
end

function F.outpost_income(drills, tech)
  return drills * F.economy.drill_rate * F.economy.tech_income_mult ^ tech
end

--- Meilleur soldat débloqué au niveau `tech`.
function F.best_soldier(tech)
  local best = "rifleman"
  for _, key in ipairs(F.soldier_order) do
    if F.soldiers[key].tech <= tech then best = key end
  end
  return best
end

function F.unit_name(faction_key, soldier_key)
  return "fo-" .. faction_key .. "-" .. soldier_key
end

return F
