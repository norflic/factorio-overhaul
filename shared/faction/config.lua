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

---------------------------------------------------------------------------------------------------
-- PvP : les factions attaquent-elles le joueur d'elles-mêmes ? (OBJECTIFS.md C4, réponse du Directeur
-- Créatif à Q4, 21/10 18 h 07 : « oui (et différents niveaux de difficulté) »). Lot IA0.
--
-- Un réglage de partie (fo-pvp-difficulty, runtime-global) choisit le niveau. Paramètres par niveau :
--   grace_min    délai de grâce (min) compté depuis le lancement de la guerre, DIVISÉ par l'agressivité
--                de la personnalité (conquérant 1,5 : plus tôt ; bâtisseur 0,7 : plus tard) ;
--   cooldown_min intervalle minimal (min) entre deux attaques d'une même faction contre le joueur ;
--   share        part visée des soldats envoyés au combat qui vont contre le joueur (règle du déficit) ;
--   keep_mult    multiplie la garnison gardée par la personnalité quand l'attaque vise le joueur ;
--   min_mult     multiplie la taille minimale (20 / agressivité) : en dessous, aucune attaque ;
--   size_mult    multiplie la même base pour la taille VISÉE des attaques qui suivent la première ;
--   save_min     quand le joueur est « dû », la faction garde ses soldats pour lui (elle n'attaque plus
--                sa rivale) pendant au plus save_min minutes, le temps d'atteindre la taille visée.
-- Débit d'une faction contre le joueur ≈ part × production de soldats / taille : share / size_mult croît
-- avec le niveau (0,33 ; 0,40 ; 0,46 ; 0,60), donc les attaques sont à la fois plus grosses et plus
-- fréquentes (vérifié par la campagne pure de tests/pvp_test.lua, dans 4 configurations : joueur non
-- leader, joueur leader, leader défendu, gros leader. Une valeur de 1,8 pour Impitoyable donnait autant
-- d'attaques que Difficile pour le conquérant ; 1,6 en donnait autant pour l'équilibré quand le joueur
-- est leader, d'où 1,5). La première attaque après la déclaration n'attend pas la taille visée (taille
-- minimale).
-- « Paisible » garde le comportement d'avant IA0 : cessez-le-feu, rompu seulement si le joueur détruit
-- une entité de la faction, et jamais d'attaque délibérée contre lui.
---------------------------------------------------------------------------------------------------
F.pvp_order = { "peaceful", "easy", "normal", "hard", "merciless" }
F.pvp_default = "normal"
F.pvp = {
  peaceful  = { aggressive = false, grace_min = 0,  cooldown_min = 0,  share = 0,    keep_mult = 1,    min_mult = 1,   size_mult = 1,   save_min = 0 },
  easy      = { aggressive = true,  grace_min = 45, cooldown_min = 15, share = 0.20, keep_mult = 1.5,  min_mult = 0.6, size_mult = 0.6, save_min = 0 },
  normal    = { aggressive = true,  grace_min = 30, cooldown_min = 8,  share = 0.40, keep_mult = 1,    min_mult = 1,   size_mult = 1,   save_min = 3 },
  hard      = { aggressive = true,  grace_min = 18, cooldown_min = 5,  share = 0.65, keep_mult = 0.5,  min_mult = 0.9, size_mult = 1.4, save_min = 5 },
  merciless = { aggressive = true,  grace_min = 10, cooldown_min = 3,  share = 0.90, keep_mult = 0.25, min_mult = 0.8, size_mult = 1.5, save_min = 7 },
}
F.pvp_rules = {
  warn_ticks = 2 * 3600,      -- préavis avant la fin de la grâce
  min_attack = 4,             -- taille minimale absolue d'une attaque contre le joueur
  max_keep = 0.9,             -- garnison gardée au plus (quel que soit le niveau)
  -- Coalition (le joueur est le « leader » : territoire nettement supérieur) : la part visée s devient
  -- s + leader_bonus × (1 - s). Correction du lot IA0 : l'ancien « × 1,5 plafonné à 100 % » rendait
  -- Difficile et Impitoyable indiscernables (tous deux à 100 %) et arrêtait les guerres entre factions.
  -- Le bonus garde l'ordre strict des niveaux (0,40 ; 0,55 ; 0,74 ; 0,925) et laisse au moins 7,5 % aux
  -- rivales.
  leader_bonus = 0.25,
  -- Unité commune joueur / factions : le territoire du joueur se compte en secteurs repérés (64 × 64
  -- tuiles, au moins sector_min installations), celui d'une faction en avant-postes (une grappe de
  -- foreuses de 30 à 40 tuiles de large). On compte sectors_per_outpost secteurs pour un avant-poste.
  -- PROVISOIRE : valeur de conception, non mesurée en moteur réel.
  sectors_per_outpost = 2,
  defense_per_turret = 8,     -- même estimation que pour une faction (équivalents fusiliers par tourelle)
  defense_radius = 40,        -- tourelles comptées autour de la cible (attaque de zone 24 + portée)
  sector = 64,                -- repérage : secteurs de 64 × 64 tuiles (2 × 2 chunks)
  -- Disque de 24 secteurs (1 536 tuiles, 1 793 secteurs) autour du point de départ du joueur : les
  -- avant-postes lointains (souvent les plus proches des QG de faction) sont repérés. Au-delà : jamais
  -- ciblé (limite documentée). Le coût par tick ne dépend pas du rayon, seulement du débit ci-dessous.
  scan_radius = 24,
  -- Débit : 1 secteur (1 count_entities_filtered) toutes les 8 ticks, soit 7,5 secteurs/s ; balayage
  -- complet en 1 793 × 8 = 14 344 ticks (4 min). Un seul appel par tick porteur (pic divisé par 2 par
  -- rapport à 2 appels toutes les 15 ticks, même débit).
  scan_period = 8,            -- ticks entre deux passes du repérage
  scan_per_pass = 1,          -- secteurs comptés par passe (1 appel moteur chacun)
  sector_min = 2,             -- installations pour qu'un secteur soit une cible
  target_ttl = 1800,          -- cible du joueur réévaluée au plus toutes les 30 s par faction
}

--- Paramètres d'un niveau (repli sur le défaut pour une valeur inconnue).
function F.pvp_params(level)
  return F.pvp[level] or F.pvp[F.pvp_default]
end

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
