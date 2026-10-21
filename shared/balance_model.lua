--[[
  Modèle quantitatif d'équilibrage — pur Lua, AUCUNE API Factorio.
  Chargeable en data stage (pour générer les prototypes), en control, et hors-jeu
  (lua5.2 tools/print_balance.lua) pour produire les tables de BALANCE_SHEET.md.

  Unités :
    MU   = "unité de matière" (1 MU = 1 plaque de fer vanilla).
    ρ    = densité d'un objet en MU/objet (objets "compactés" des paliers supérieurs).
    Φ    = débit matière d'un tapis = items/s × ρ   [MU/s]

  Principe directeur (convergence UPS × game design) :
    Le coût UPS du moteur suit le nombre d'ENTITÉS ACTIVES et de MOUVEMENTS D'OBJETS, pas la quantité de
    matière. Un palier qui multiplie Φ par la densité ρ (et non par le nombre de machines ou d'objets)
    est donc un vrai saut de gameplay ET un gain UPS par MU produite.
]]

local M = {}

-- Contraintes moteur, vérifiées dans la doc 1.1.91 livrée avec le jeu (doc-html/prototype-api.json).
M.ENGINE = {
  UPS = 60,
  BELT_ITEMS_PER_SPEED = 480,    -- TransportBeltConnectablePrototype.speed : speed × 480 = items/s
  BELT_SPEED_QUANTUM = 1 / 256,  -- virgule fixe 8 bits : pas de 1.875 items/s
  MAX_CRAFTS_PER_TICK = 1,       -- CraftingMachinePrototype : une seule complétion par tick et par machine
  BELT_SPEED_SOFT_CAP = 0.25,    -- HYPOTHÈSE H-B1 (120 items/s) : fiabilité de prise par les bras à valider
}

-- Valeurs vanilla relevées dans data/base/prototypes/entity/entities.lua (1.1.91).
M.VANILLA = {
  belt_items = { 15, 30, 45 },                 -- speed 0.03125 / 0.0625 / 0.09375
  assembler_speed = { 0.5, 0.75, 1.25 },
  furnace_speed = { stone = 1, steel = 2, electric = 2 },
  inserter_rotation = { burner = 0.01, basic = 0.014, long = 0.02, fast = 0.04, stack = 0.04 },
  character = { running_speed = 0.15, mining_speed = 0.5, crafting_speed = 1, inventory = 80, health = 250 },
  iron_plate_energy_s = 3.2,
  stone_furnace_kw = 90,
}

-- PROPOSITION (à arbitrer par le Directeur Créatif) : "Compaction ×4".
M.PROPOSAL = {
  name = "Compaction x4",
  belt_items = { 15, 30, 60, 120, 120 },  -- items/s par tapis
  density = { 1, 2, 4, 8, 32 },           -- MU par objet transporté
  machines_per_belt = 32,                 -- taille de layout constante par palier (vanilla : 24 à 48)
  base_energy_kj_per_mu = 288,            -- four en pierre : 90 kW / 0.3125 plaque/s
  energy_decay = 0.8,                     -- énergie par MU × 0.8 à chaque palier
  handoffs_per_item = 3,                  -- bras -> tapis -> bras : proxy du coût UPS par objet
}

function M.belt_speed(items_per_s)
  return items_per_s / M.ENGINE.BELT_ITEMS_PER_SPEED
end

function M.is_quantized(speed)
  local q = speed / M.ENGINE.BELT_SPEED_QUANTUM
  return math.abs(q - math.floor(q + 0.5)) < 1e-9
end

--- Dérive la table des paliers et liste les violations de contraintes moteur.
function M.derive(p)
  p = p or M.PROPOSAL
  local rows, issues = {}, {}
  for k = 1, #p.belt_items do
    local B, rho = p.belt_items[k], p.density[k]
    local speed = M.belt_speed(B)
    local phi = B * rho
    local machine_mu = phi / p.machines_per_belt
    local machine_items = machine_mu / rho
    local e = p.base_energy_kj_per_mu * p.energy_decay ^ (k - 1)
    local power_kw = machine_mu * e
    rows[k] = {
      tier = k,
      belt_items = B,
      belt_speed = speed,
      density = rho,
      phi = phi,
      phi_ratio = k > 1 and phi / (p.belt_items[k - 1] * p.density[k - 1]) or 1,
      machine_mu = machine_mu,
      machine_items = machine_items,
      energy_kj_per_mu = e,
      machine_kw = power_kw,
      belt_mw = power_kw * p.machines_per_belt / 1000,
      handoffs_per_kmu = 1000 / rho * p.handoffs_per_item,
    }
    if not M.is_quantized(speed) then
      issues[#issues + 1] = string.format("T%d : vitesse %.6f non multiple de 1/256", k, speed)
    end
    if speed > M.ENGINE.BELT_SPEED_SOFT_CAP + 1e-12 then
      issues[#issues + 1] = string.format("T%d : vitesse %.4f au-delà du plafond souple H-B1", k, speed)
    end
    if machine_items > M.ENGINE.UPS * M.ENGINE.MAX_CRAFTS_PER_TICK then
      issues[#issues + 1] = string.format("T%d : %.1f crafts/s > plafond moteur 60/s", k, machine_items)
    end
  end
  return rows, issues
end

return M
