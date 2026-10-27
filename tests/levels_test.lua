--[[
  Tests hors jeu des NIVEAUX de bâtiments en 15 ÉPOQUES (session 5, lot V2) : règles pures, courbe de coûts
  et de durées par époque, table d'indirection des matériaux, chantiers en moteur simulé, panneau.
  Usage, depuis la racine du mod :
    lua5.2 tests/levels_test.lua            les tests
    lua5.2 tests/levels_test.lua --tables | tr -d '\r'   les tableaux Markdown de BALANCE_SHEET §12, CALCULÉS
                                                         sur la config (tr : fichier en LF, print ajoute CR sous Windows)
]]

package.path = "./?.lua;" .. package.path
local L = require("shared.levels.config")

--- Dossier `data` du jeu pour le banc de l'étape data : la variable d'environnement FO_DATA_DIR (copie jetable du
--- mod hors de l'arborescence du jeu, suite d'intégration de V3-T), sinon relatif à la racine du mod (dépôt
--- principal : ../../data ; worktree d'agent : ../../../../../data). nil si introuvable. Fonction GLOBALE du banc :
--- le bloc principal de ce fichier est à la limite de 200 variables locales de Lua 5.2.
function game_data_dir()
  local cands = {}
  if os.getenv("FO_DATA_DIR") then cands[#cands + 1] = os.getenv("FO_DATA_DIR") end
  cands[#cands + 1] = "../../data"
  cands[#cands + 1] = "../../../../../data"
  for _, d in ipairs(cands) do
    local fh = io.open(d .. "/base/prototypes/technology.lua", "rb")
    if fh then fh:close(); return d end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Valeurs vanilla du niveau 1 (relevées par tests/datastage/harness.lua --dump-proto ; le centre de
-- commandement est un prototype du mod : 3 000 PV, 48 cases).
---------------------------------------------------------------------------------------------------
local VANILLA = {
  command = { max_health = 3000, inventory_size = 48 },
  gun = { max_health = 400, damage_modifier = 1, range = 18, rotation_speed = 0.015 },
  laser = { max_health = 1000, damage_modifier = 2, range = 24, rotation_speed = 0.01, energy_consumption = 800,
            buffer_capacity = 801 },
  wall = { max_health = 350, physical = 3, explosion = 10 },
  drill = { max_health = 300, mining_speed = 0.5, energy_usage = 90 },
  furnace = { max_health = 300, crafting_speed = 2, energy_usage = 90 },
  assembler = { max_health = 350, crafting_speed = 0.75, energy_usage = 150 },
}

-- Cadence vanilla (ticks entre deux tirs) : la tourelle lourde du mod réduit celle de la mitrailleuse.
local GUN_COOLDOWN, LASER_COOLDOWN = 6, 40

local stat_at
--- DPS relatif à la tourelle vanilla de même famille : dégâts × cadence (la cadence des niveaux ne change pas).
local function dps_at(family, n)
  return stat_at(family, "damage_modifier", n) / VANILLA[family.key].damage_modifier
end

function stat_at(family, key, n)
  if key == "dps" then return dps_at(family, n) end
  for _, st in ipairs(family.stats) do
    if st.path[#st.path] == key then return L.apply_stat(st, VANILLA[family.key][key], n) end
  end
  if family.resist_step and family.resist_step[key] then
    return VANILLA[family.key][key] + family.resist_step[key] * (n - 1)
  end
  return nil
end

--- DPS relatif de la version lourde du mod (shared/content/arsenal.lua) : dégâts × cadence.
local function heavy_dps(key)
  local A = require("shared.content.arsenal")
  for _, t in ipairs(A.turrets) do
    if t.copy == L.by_key[key].base then
      local cd0 = key == "gun" and GUN_COOLDOWN or LASER_COOLDOWN
      return t.damage_modifier * cd0 / (t.cooldown or cd0)
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Modèle de durée de jeu (BALANCE_SHEET §12 ; lot V2c). Le calendrier est celui du scénario X0, LU par
-- L.target (durée, débit moyen, budget). L'amélioration est instantanée (Q19) : la durée IMPLIQUÉE d'une
-- époque est le temps qu'il faut pour payer la dépense de la base de référence avec la part de la
-- production consacrée aux niveaux (même méthode que V2, sans le terme des ouvriers, qui n'existent plus).
---------------------------------------------------------------------------------------------------
local function epoch_levels(f, e)
  local out = {}
  for n = 2 * e - 1, 2 * e do if n >= 2 and n <= f.max then out[#out + 1] = n end end
  return out
end

--- Dépense des 6 familles de la base de référence pendant l'époque e (unités de matière brute).
local function buildings_spend(e)
  local T = L.target
  local spend = 0
  for _, f in ipairs(L.families) do
    if f.key ~= "command" then
      local N = T.base[f.key](e)
      local dN = N - (e > 1 and T.base[f.key](e - 1) or 0)
      for _, n in ipairs(epoch_levels(f, e)) do spend = spend + N * L.cost_value(L.cost(f, n)) end
      -- Rattrapage : les bâtiments ajoutés pendant l'époque montent aussi les niveaux précédents.
      for n = 2, 2 * e - 2 do spend = spend + dN * L.cost_value(L.cost(f, n)) end
    end
  end
  return spend
end

--- Passage du centre PAYÉ pendant l'époque e (e → e + 1 ; 0 à l'époque 15).
local function cc_spend(e)
  if e >= L.CC_MAX then return 0 end
  return L.cost_value(L.cost(L.by_key.command, e + 1))
end

--- prod_k : facteur sur la production supposée (sensibilité). La production de la force est celle du
--- joueur × L.TEAM_FACTOR (équipe de PNJ, lot IA1).
local function model(prod_k)
  prod_k = prod_k or 1
  local T = L.target
  local rows, cumul, implied_cumul = {}, 0, 0
  for e = 1, L.EPOCHS do
    local D = T.epoch_hours(e)
    cumul = cumul + D
    local P = T.production(e) * prod_k * L.TEAM_FACTOR
    local levels_budget = T.spend_share * P * D * 3600
    local cc_value = cc_spend(e)
    local spend = buildings_spend(e) + cc_value
    local implied = spend / (T.spend_share * P * 3600)
    implied_cumul = implied_cumul + implied
    rows[e] = { e = e, hours = D, cumul = cumul, production = P, budget = T.budget(e) * L.TEAM_FACTOR,
                levels_budget = levels_budget, spend = spend, ratio = spend / levels_budget, cc_value = cc_value,
                cc_share = cc_value / (T.budget(e) * prod_k * L.TEAM_FACTOR), implied = implied,
                implied_cumul = implied_cumul }
  end
  return rows
end

--- Chemin le plus court vers le centre 15 (vérification V2c), en heures : le centre, plus UN bâtiment de chaque
--- famille de `keys` monté jusqu'au niveau visé à chaque passage (Q16 ; niveaux 2 à 28), payés avec la part
--- `share` de la production X0 (débit moyen de chaque époque).
local function rush_hours(keys, share)
  local h = 0
  for e = 1, L.CC_MAX - 1 do
    local spend = cc_spend(e)
    for _, key in ipairs(keys) do
      local f = L.by_key[key]
      for _, n in ipairs(epoch_levels(f, e)) do spend = spend + L.cost_value(L.cost(f, n)) end
    end
    h = h + spend / (share * L.target.production(e) * 3600)
  end
  return h
end

---------------------------------------------------------------------------------------------------
-- Mode --calibrate : recalcule la courbe sur le calendrier X0 et imprime les tables à reporter dans
-- shared/levels/config.lua (déterministe ; la config du jeu garde des NOMBRES écrits, jamais un calcul en
-- flottants de log ou de puissance au chargement : même résultat sur tous les clients).
-- Correction V2c (vérification) : le calcul part d'un état de RÉFÉRENCE FIXE (panier V2 du centre, toutes les
-- valeurs d'époque à 0), jamais de la config en place : sa sortie ne dépend que du calendrier X0, des familles
-- et de ce panier de référence. Les tests vérifient que la config livrée EST cette sortie (aucune retouche).
--   1. panier du centre : le passage 1 → 2 comble le budget des niveaux de l'époque 1 que les paniers des
--      bâtiments laissent ; panier V2 mis à l'échelle et arrondi comme le joueur le paie (L.round_nice) ;
--   2. cc_value de l'époque e (passage e → e + 1) : cc_share × budget(e) moins le panier, BORNÉ par la place
--      (CC_SLOT_SHARE du coffre du centre payeur), par MAX_QTY objets d'une sorte, et par la croissance
--      stricte du coût du centre (un passage ne coûte jamais moins que le précédent : la borne d'une époque
--      vaut au plus 97 % de celle de l'époque suivante) ;
--   3. époques 2 à 15 : value_mult (strictement croissant, au moins + 2 %) comble le reste du budget des
--      niveaux ; si les bâtiments le dépassent déjà au plus petit value_mult permis, le passage du centre de
--      l'époque cède la différence.
---------------------------------------------------------------------------------------------------
local CC_SLOT_SHARE, MAX_QTY = 0.45, 2000
-- Panier de référence du centre (celui du lot V2) : seules ses PROPORTIONS comptent.
local REF_CC_BASKET = { { "iron-plate", 260 }, { "copper-plate", 130 }, { "stone-brick", 130 }, { "electronic-circuit", 50 } }

local function sig_floor(x, digits)
  if x <= 0 then return 0 end
  local p = 10 ^ (math.floor(math.log10(x)) - (digits - 1))
  return math.floor(x / p) * p
end
local function sig_round(x, digits)
  if x <= 0 then return 0 end
  local p = 10 ^ (math.floor(math.log10(x)) - (digits - 1))
  return math.floor(x / p + 0.5) * p
end

--- Le coût du centre vers le niveau n tient-il dans CC_SLOT_SHARE du coffre payeur, avec au plus MAX_QTY
--- objets d'une sorte ?
local function cc_fits(n)
  local c = L.cost(L.by_key.command, n)
  for _, x in ipairs(c) do if x[2] > MAX_QTY then return false end end
  return L.cost_slots(c) <= math.floor(CC_SLOT_SHARE * L.chest_slots(n - 1))
end

--- Bissection : plus grande valeur x de [lo, hi] telle que ok(x) (ok décroissant en x).
local function max_ok(lo, hi, ok)
  for _ = 1, 60 do
    local mid = (lo + hi) / 2
    if ok(mid) then lo = mid else hi = mid end
  end
  return lo
end

--- Calibre la courbe EN PLACE dans L (à partir de l'état de référence fixe) et renvoie les bornes de place du
--- centre (cap, eff). L'appelant sauvegarde et restaure la config s'il le faut (calib_state, calib_restore).
local function calibrate()
  local T = L.target
  local C = L.by_key.command
  local function levels_target(e)
    return T.spend_share * T.production(e) * L.TEAM_FACTOR * T.epoch_hours(e) * 3600
  end
  -- 0. État de référence : panier V2 du centre, aucune valeur d'époque (époque 1 : 0, jamais calibrée).
  for i, b in ipairs(REF_CC_BASKET) do C.base_cost[i] = { b[1], b[2] } end
  for i = #REF_CC_BASKET + 1, #C.base_cost do C.base_cost[i] = nil end
  for e = 1, L.EPOCHS do
    L.epochs[e].cc_value = 0
    if e >= 2 then L.epochs[e].value_mult = 0 end
  end
  L.rebuild()
  -- 1. Panier du centre : le passage 1 → 2 comble le budget des niveaux de l'époque 1 que les paniers des
  --    bâtiments (poids 1) laissent. Un panier plus lourd à l'époque 1 renchérirait les niveaux 3 à 8 (règle
  --    de monotonie, rattrapage) et ferait déborder les époques 2 à 4 de 30 à 70 % (essai du 22/10). Arrondi
  --    de L.round_nice (multiple de 10 au-dessus de 100) : le panier écrit est celui que le joueur paie.
  local want1 = levels_target(1) - buildings_spend(1)
  local s = want1 / L.cost_value(L.cost(C, 2))
  for _, b in ipairs(C.base_cost) do b[2] = math.max(5, L.round_nice(b[2] * s)) end
  L.rebuild()
  -- 2. Passage du centre vers n (payé à l'époque n - 1) : borne de place de chaque passage, seul (les autres
  --    à 0, la monotonie ne joue pas), puis bornes rendues strictement croissantes depuis l'époque 15.
  local basket, cap = {}, {}
  for n = 3, L.CC_MAX do
    basket[n] = L.cost_value(L.cost(C, n))
    local v = max_ok(0, T.cc_share * T.budget(n - 1) * L.TEAM_FACTOR, function(x)
      L.epochs[n - 1].cc_value = x
      L.rebuild()
      return cc_fits(n)
    end)
    L.epochs[n - 1].cc_value = v
    L.rebuild()
    cap[n] = L.cost_value(L.cost(C, n))
    L.epochs[n - 1].cc_value = 0
    L.rebuild()
  end
  local eff = {}
  eff[L.CC_MAX] = cap[L.CC_MAX]
  for n = L.CC_MAX - 1, 3, -1 do eff[n] = math.min(cap[n], 0.97 * eff[n + 1]) end
  for n = 3, L.CC_MAX do
    local total = math.min(T.cc_share * T.budget(n - 1) * L.TEAM_FACTOR, eff[n])
    L.epochs[n - 1].cc_value = sig_floor(math.max(0, total - basket[n]), 3)
  end
  L.rebuild()
  for n = 3, L.CC_MAX do
    while L.epochs[n - 1].cc_value > 0 and not cc_fits(n) do
      L.epochs[n - 1].cc_value = sig_floor(L.epochs[n - 1].cc_value * 0.99, 3)
      L.rebuild()
    end
  end
  -- 3. Époques 2 à 15 : value_mult comble le reste du budget des niveaux. Si les bâtiments dépassent déjà
  --    au plus petit value_mult permis (époque 3 : les fours et machines arrivent et rattrapent 3 niveaux,
  --    la monotonie interdit des niveaux moins chers que ceux de l'époque 2), le passage du centre de
  --    l'époque cède la différence (sans descendre sous 1,03 × le passage précédent).
  for e = 2, L.EPOCHS do
    local vm_min = e == 2 and 0.05 or sig_round(L.epochs[e - 1].value_mult * 1.02, 3)
    L.epochs[e].value_mult = vm_min
    L.rebuild()
    local floor_spend = buildings_spend(e)
    if e < L.CC_MAX and floor_spend + cc_spend(e) > levels_target(e) then
      local prev_total = cc_spend(e - 1)
      local want = math.max(levels_target(e) - floor_spend, 1.03 * prev_total)
      L.epochs[e].cc_value = 0
      L.rebuild()
      local basket_e = cc_spend(e)
      L.epochs[e].cc_value = sig_floor(math.max(0, want - basket_e), 3)
      L.rebuild()
    end
    local target = levels_target(e) - cc_spend(e)
    local v = max_ok(vm_min, vm_min * 8 + 10, function(x)
      L.epochs[e].value_mult = x
      L.rebuild()
      return buildings_spend(e) <= target
    end)
    L.epochs[e].value_mult = math.max(vm_min, sig_round(v, 3))
    L.rebuild()
  end
  return cap, eff
end

--- État calibré de la config (panier du centre, value_mult, cc_value) : copie, et restauration.
local function calib_state()
  local s = { basket = {}, value_mult = {}, cc_value = {} }
  for i, b in ipairs(L.by_key.command.base_cost) do s.basket[i] = { b[1], b[2] } end
  for e = 1, L.EPOCHS do s.value_mult[e], s.cc_value[e] = L.epochs[e].value_mult, L.epochs[e].cc_value end
  return s
end
local function calib_restore(s)
  local C = L.by_key.command
  for i = 1, math.max(#C.base_cost, #s.basket) do C.base_cost[i] = s.basket[i] and { s.basket[i][1], s.basket[i][2] } or nil end
  for e = 1, L.EPOCHS do L.epochs[e].value_mult, L.epochs[e].cc_value = s.value_mult[e], s.cc_value[e] end
  L.rebuild()
end

local function print_calibration(cap, eff)
  local T = L.target
  local C = L.by_key.command
  -- Sortie : lignes à reporter dans la config.
  print("-- panier du centre (base_cost) :")
  local parts = {}
  for _, b in ipairs(C.base_cost) do parts[#parts + 1] = string.format('{ "%s", %d }', b[1], b[2]) end
  print("{ " .. table.concat(parts, ", ") .. " }")
  print("-- L.epochs (value_mult, cc_value) :")
  for e = 1, L.EPOCHS do
    print(string.format("%2d %-15s value_mult = %s, cc_value = %s", e, L.epochs[e].key,
      tostring(L.epochs[e].value_mult), tostring(L.epochs[e].cc_value)))
  end
  print("-- bornes de place du centre (valeur totale du passage, u) :")
  for n = 3, L.CC_MAX do
    print(string.format("vers %2d : visée %.0f, borne seule %.0f, borne croissante %.0f", n,
      T.cc_share * T.budget(n - 1) * L.TEAM_FACTOR, cap[n], eff[n]))
  end
  print("-- contrôle :")
  for _, r in ipairs(model()) do
    print(string.format("ép. %2d : visée %.2f h, impliquée %.2f h (%+.1f %%), centre %.0f u = %.2f %% du budget, cumul %.2f h",
      r.e, r.hours, r.implied, 100 * (r.implied / r.hours - 1), r.cc_value, 100 * r.cc_share, r.implied_cumul))
  end
end

if arg and arg[1] == "--calibrate" then
  print_calibration(calibrate())
  os.exit(0)
end

---------------------------------------------------------------------------------------------------
-- Mode --tables : BALANCE_SHEET §12
---------------------------------------------------------------------------------------------------
local function thousands(x)
  local s = string.format("%d", math.floor(x + 0.5))
  local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
  return (out:gsub("^ ", ""))
end

local function num(x, digits)
  if math.abs(x - math.floor(x + 0.5)) < 1e-9 then return thousands(x) end
  local s = string.format("%." .. (digits or 2) .. "f", x):gsub("0+$", ""):gsub("%.$", "")
  return (s:gsub("%.", ","))
end

local function duration(sec)
  if sec <= 0 then return "instantané" end
  sec = math.floor(sec + 0.5)
  if sec < 60 then return sec .. " s" end
  if sec < 3600 then
    local m, s = math.floor(sec / 60), sec % 60
    return s == 0 and (m .. " min") or string.format("%d min %02d s", m, s)
  end
  local h, m = math.floor(sec / 3600), math.floor((sec % 3600) / 60)
  return string.format("%d h %02d", h, m)
end

local function cost_text(cost)
  local parts = {}
  for _, c in ipairs(cost) do parts[#parts + 1] = thousands(c[2]) .. " " .. c[1] end
  return table.concat(parts, ", ")
end

local EPOCH_NAMES = {
  "Pionnier", "Forge", "Vapeur", "Pétrole", "Volcan", "Électricité", "Cristal", "Marais", "Atome",
  "Haute technologie", "Titane", "Supraconducteurs", "Fusion", "Orbite", "Légende",
}

local FAMILY_NAMES = {
  command = "Centre de commandement", gun = "Mitrailleuse", laser = "Tourelle laser", wall = "Mur",
  drill = "Foreuse électrique", furnace = "Four en acier", assembler = "Machine d'assemblage 2",
}

local MAIN_STAT = {
  command = { "inventory_size", "cases" }, gun = { "damage_modifier", "dégâts ×" }, laser = { "damage_modifier", "dégâts ×" },
  wall = { "physical", "réduction physique" }, drill = { "mining_speed", "minage" }, furnace = { "crafting_speed", "vitesse" },
  assembler = { "crafting_speed", "vitesse" },
}
local OTHER_STAT = {
  gun = { "range", "portée" }, laser = { "range", "portée" }, wall = { "explosion", "réduction explosion" },
  drill = { "energy_usage", "kW" }, furnace = { "energy_usage", "kW" }, assembler = { "energy_usage", "kW" },
}

local function print_tables()
  local p = print
  p("#### Les 15 époques et la table d'indirection des matériaux")
  p("")
  p("| Époque | Thème | Matériau voulu | Objet en jeu aujourd'hui | Valeur unitaire (u) | Pile | Valeur d'époque des bâtiments (value_mult) | Monnaie du passage du centre payé dans l'époque (cc_value, u) | Centre (niveau) | Niveaux des bâtiments | Condition du passage suivant (Q16) |")
  p("|---|---|---|---|---|---|---|---|---|---|---|")
  for e = 1, L.EPOCHS do
    local ep, m = L.epochs[e], L.epoch_materials[e]
    local want, item, value, stack = "fer, cuivre, pierre (panier de base)", "panier de base", "—", "—"
    if m then
      want = m.want
      item = "`" .. m.item .. "`" .. (m.provisional and (" **provisoire** (voulu : `" .. m.want_item .. "`)") or "")
      value = num(m.value)
      stack = thousands(L.stack_size[m.item])
    end
    p(string.format("| %d | %s | %s | %s | %s | %s | %s | %s | %d | %d-%d | %s |", e, EPOCH_NAMES[e], want, item, value,
      stack, num(ep.value_mult), e < L.CC_MAX and (e == 1 and "panier seul" or thousands(ep.cc_value)) or "—", e,
      math.max(1, 2 * e - 1), 2 * e, e < L.CC_MAX and ("un bâtiment de chaque famille possédée au niveau " .. L.cc_condition_level(e)) or "—"))
  end
  p("")
  p("#### Repères : niveau 1, niveau 10 (maximum de 0.3.0), dernier niveau, comparés au vanilla et au contenu du mod")
  p("")
  p("| Famille | Statistique | Niveau 1 | Niveau 10 | Dernier niveau | Repère |")
  p("|---|---|---|---|---|---|")
  local A = require("shared.content.arsenal")
  local MD = require("shared.content.modules")
  local heavy, walls = {}, {}
  for _, t in ipairs(A.turrets) do heavy[t.copy] = t end
  for _, w in ipairs(A.walls) do walls[w.name] = w end
  local sp10 = MD.families.speed.effects.speed[MD.TIERS]
  local sp3 = MD.families.speed.effects.speed[3]
  local refs = {
    { "command", "max_health", "—" },
    { "command", "inventory_size", "coffre en acier : 48 cases" },
    { "gun", "max_health", "tourelle lourde (mod) : " .. thousands(heavy["gun-turret"].hp) },
    { "gun", "damage_modifier", "tourelle lourde (mod) : " .. num(VANILLA.gun.damage_modifier * heavy["gun-turret"].damage_modifier) },
    { "gun", "dps", "tourelle lourde (mod) : " .. num(heavy_dps("gun")) .. " (dégâts 1,5 × cadence " .. num(GUN_COOLDOWN / heavy["gun-turret"].cooldown) .. ")" },
    { "gun", "range", "tourelle lourde (mod) : " .. num(heavy["gun-turret"].range) .. " ; ver géant : 48" },
    { "laser", "max_health", "tourelle laser lourde (mod) : " .. thousands(heavy["laser-turret"].hp) },
    { "laser", "damage_modifier", "tourelle laser lourde (mod) : " .. num(VANILLA.laser.damage_modifier * heavy["laser-turret"].damage_modifier) },
    { "laser", "dps", "tourelle laser lourde (mod) : " .. num(heavy_dps("laser")) .. " (même cadence)" },
    { "laser", "energy_consumption", "tourelle laser lourde (mod) : " .. thousands(VANILLA.laser.energy_consumption * heavy["laser-turret"].energy_scale) .. " kJ" },
    { "laser", "range", "tourelle laser lourde (mod) : " .. num(heavy["laser-turret"].range) },
    { "wall", "max_health", "mur renforcé : " .. thousands(walls["fo-reinforced-wall"].hp) .. " ; mur blindé : " .. thousands(walls["fo-armored-wall"].hp) },
    { "wall", "physical", "mur blindé : 3 + 15 = 18 (et 50 %)" },
    { "drill", "mining_speed", string.format("vanilla + 3 modules de vitesse 3 : %s minerai/s ; niveau 30 + 3 modules de vitesse palier %d : %s minerai/s (tapis jaune : 15/s)",
      num(VANILLA.drill.mining_speed * (1 + 3 * sp3)), MD.TIERS, num(stat_at(L.by_key.drill, "mining_speed", 30) * (1 + 3 * sp10))) },
    { "furnace", "crafting_speed", "four électrique vanilla : 2, avec 2 emplacements de module (le four en acier n'en a aucun)" },
    { "assembler", "crafting_speed", "machine d'assemblage 3 vanilla : 1,25, avec 4 emplacements (la machine 2 en a 2)" },
  }
  for _, r in ipairs(refs) do
    local f = L.by_key[r[1]]
    p(string.format("| %s | %s | %s | %s | %s (niveau %d) | %s |", FAMILY_NAMES[f.key], r[2], num(stat_at(f, r[2], 1), 3),
      num(stat_at(f, r[2], 10), 3), num(stat_at(f, r[2], f.max), 3), f.max, r[3]))
  end
  p("")
  p("#### Modèle de durée de jeu (calendrier du scénario X0 ; hypothèses de `L.target`, à valider en partie réelle)")
  p("")
  p("| Époque | Durée X0 | Atteinte X0 | Débit moyen X0 (u/s) | Budget de l'époque X0 (u) | Budget des niveaux (30 %) | Dépense de la base de référence (u) | Dépense / budget des niveaux | Passage du centre suivant (u) | Part du budget de l'époque | Durée impliquée | Cumul impliqué |")
  p("|---|---|---|---|---|---|---|---|---|---|---|---|")
  for _, r in ipairs(model()) do
    p(string.format("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |", r.e, duration(r.hours * 3600),
      r.e == 1 and "0 h" or duration(L.target.reach_hour(r.e) * 3600), thousands(r.production), thousands(r.budget), thousands(r.levels_budget),
      thousands(r.spend), num(r.ratio), r.cc_value > 0 and thousands(r.cc_value) or "—",
      r.cc_value > 0 and (num(100 * r.cc_share, 2) .. " %") or "—", duration(r.implied * 3600), duration(r.implied_cumul * 3600)))
  end
  p("")
  p("#### Sensibilité de la durée impliquée totale (15 époques)")
  p("")
  p("| Production supposée | Durée impliquée totale |")
  p("|---|---|")
  for _, k in ipairs({ 0.7, 1, 1.3 }) do
    p(string.format("| × %s | %s |", num(k), duration(model(k)[L.EPOCHS].implied_cumul * 3600)))
  end
  local cc_v = 0
  for n = 2, L.CC_MAX do cc_v = cc_v + L.cost_value(L.cost(L.by_key.command, n)) end
  -- Q16 : le chemin le plus court vers le centre 15 monte aussi UN bâtiment de chaque famille possédée jusqu'au
  -- niveau visé à chaque passage (28 avant le centre 15) ; ici, les 6 familles possédées, et un bâtiment de
  -- chacune monté du niveau 2 au niveau 28.
  local q16 = 0
  for _, f in ipairs(L.families) do
    if f.key ~= "command" then
      for n = 2, L.cc_condition_level(L.CC_MAX - 1) do q16 = q16 + L.cost_value(L.cost(f, n)) end
    end
  end
  local spent, budget = 0, 0
  for _, r in ipairs(model()) do spent = spent + r.spend; budget = budget + r.budget end
  p("")
  p(string.format("Chemin « centre seul » (centre 1 → 15) : %s u, soit %s %% de la dépense de la base de référence. Avec la condition Q16 (un bâtiment de chaque famille possédée monté jusqu'au niveau visé, ici les 6 familles jusqu'au niveau 28) : %s u, soit %s %% (V2, sans condition : 0,9 %%).",
    thousands(cc_v), num(100 * cc_v / spent, 2), thousands(cc_v + q16), num(100 * (cc_v + q16) / spent, 2)))
  local six = { "gun", "laser", "wall", "drill", "furnace", "assembler" }
  p("")
  p(string.format("En heures (chemin le plus court, payé au débit moyen X0 de chaque époque) : centre 15 atteint en **%s** avec 30 %% de la production X0 et les 6 familles possédées (%s avec 100 %% ; centre seul, aucune famille possédée : %s), pour **%s** au calendrier X0. Le calendrier n'est tenu que si le joueur monte toute la base de référence : rien ne l'y oblige (écart connu, compté par `levels_test`).",
    duration(rush_hours(six, L.target.spend_share) * 3600), duration(rush_hours(six, 1) * 3600),
    duration(rush_hours({}, L.target.spend_share) * 3600), duration(L.target.reach_hour(15) * 3600)))
  for _, f in ipairs(L.families) do
    p("")
    p("#### " .. FAMILY_NAMES[f.key] .. " (" .. f.max .. " niveaux)")
    p("")
    local ms, os_ = MAIN_STAT[f.key], OTHER_STAT[f.key]
    local head = "| Niveau | Époque | PV | " .. ms[2] .. (os_ and (" | " .. os_[2]) or "") .. " | Coût du passage à ce niveau | Valeur (u) | Cases / coffre du centre payeur |"
    p(head)
    p("|" .. string.rep("---|", os_ and 8 or 7))
    for n = 1, f.max do
      local e = L.epoch_of(f, n)
      local cost, value, slots = "—", "—", "—"
      if n >= 2 then
        local c = L.cost(f, n)
        cost, value = cost_text(c), thousands(L.cost_value(c))
        slots = L.cost_slots(c) .. " / " .. L.chest_slots(L.payer_cc(f, n))
      end
      local mark = ""
      if f.key ~= "command" then
        if n == 1 then mark = " (vanilla)"
        elseif L.step_of(f, n) == 1 then mark = " (silhouette)"
        else mark = " (+ pièce)" end
      end
      local row = string.format("| %d | %d %s%s | %s | %s", n, e, EPOCH_NAMES[e], mark, num(stat_at(f, "max_health", n), 1),
        num(stat_at(f, ms[1], n), 3))
      if os_ then row = row .. " | " .. num(stat_at(f, os_[1], n), 3) end
      p(row .. " | " .. cost .. " | " .. value .. " | " .. slots .. " |")
    end
  end
end

if arg and arg[1] == "--tables" then
  print_tables()
  os.exit(0)
end

---------------------------------------------------------------------------------------------------
-- Tests
---------------------------------------------------------------------------------------------------
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end
-- ÉCART CONNU (correction V2c) : un point du CONTRAT qui n'est pas tenu et attend un arbitrage du Directeur
-- Créatif. Tenu : compté OK ; non tenu : affiché « ÉCART CONNU » et compté à part (ni OK, ni ECHEC), pour ne
-- jamais le faire passer pour conforme sans bloquer les bancs.
local gaps = {}
local function known_gap(cond, msg)
  if cond then passes = passes + 1 else gaps[#gaps + 1] = msg; print("  ÉCART CONNU : " .. msg) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------------------------------
section("Cadre des 15 époques")
---------------------------------------------------------------------------------------------------
check(#L.families == 7, "7 familles")
check(L.EPOCHS == 15 and #L.epochs == 15, "15 époques")
check(L.by_key.command.max == 15, "centre de commandement : 15 niveaux (un par époque)")
for _, f in ipairs(L.families) do
  if f.key ~= "command" then check(f.max == 30, f.key .. " : 30 niveaux (2 par époque)") end
end
-- Époque et rang de chaque niveau.
local G = L.by_key.gun
check(L.epoch_of(G, 1) == 1 and L.epoch_of(G, 2) == 1 and L.epoch_of(G, 3) == 2 and L.epoch_of(G, 4) == 2
  and L.epoch_of(G, 29) == 15 and L.epoch_of(G, 30) == 15, "familles : niveaux 2e-1 et 2e = époque e")
check(L.step_of(G, 3) == 1 and L.step_of(G, 4) == 2 and L.step_of(G, 29) == 1 and L.step_of(G, 30) == 2,
  "rang : 1er niveau d'une époque (silhouette), 2e (pièce)")
for n = 1, 15 do
  check(L.epoch_of(L.by_key.command, n) == n, "centre niveau " .. n .. " = époque " .. n)
end
-- Plafond : 2 × niveau du centre, et le niveau n exige le centre ⌈n/2⌉.
for cc = 0, 15 do
  for _, f in ipairs(L.families) do
    if f.key ~= "command" then
      local want = cc < 1 and 1 or math.min(30, 2 * cc)
      check(L.max_level(f, cc) == want, f.key .. " : plafond " .. want .. " avec un centre " .. cc)
    end
  end
end
for n = 2, 30 do
  check(L.required_cc(G, n) == math.ceil(n / 2) and L.max_level(G, L.required_cc(G, n)) >= n
    and L.max_level(G, L.required_cc(G, n) - 1) < n, "niveau " .. n .. " : centre " .. math.ceil(n / 2) .. " requis, pas moins")
end
check(L.max_level(L.by_key.command, 1) == 15, "le centre lui-même va jusqu'à 15")
-- Q19 (lot V2c) : amélioration instantanée, plus d'ouvriers ni de durées (l'ancien comportement : 1 à 5
-- ouvriers, refus « no-builder », durées par époque).
check(L.MAX_BUILDERS == nil and L.builders == nil and L.time_ticks == nil and L.SECOND_LEVEL_TIME_FACTOR == nil,
  "Q19 : plus d'ouvriers ni de durées dans la config (L.MAX_BUILDERS, L.builders, L.time_ticks retirés)")
for _, f in ipairs(L.families) do
  check(f.time0 == nil and f.instant == nil, f.key .. " : aucune durée de chantier (time0, instant retirés)")
end
for e = 1, L.EPOCHS do
  check(L.epochs[e].time_mult == nil and L.epochs[e].cc_time_mult == nil, "époque " .. e .. " : aucun multiplicateur de durée")
end
check(L.by_key.wall.row == true, "murs : rangée entière (bouton « Toute la rangée »)")
local ok, why = L.check(G, 2, 0)
check(not ok and why == "no-cc", "refus sans centre")
ok, why = L.check(G, 3, 1)
check(not ok and why == "cc-too-low", "refus : niveau 3 avec un centre 1")
ok = L.check(G, 4, 2)
check(ok, "niveau 4 autorisé avec un centre 2")
ok, why = L.check(G, 2, 1, 5)
check(ok, "Q19 : aucun refus « ouvrier occupé » (5 chantiers « en cours » n'empêchent rien)")
ok, why = L.check(G, 31, 15)
check(not ok and why == "max", "refus au-delà du niveau 30")

-- Q16 (lot V2c) : le centre quitte le niveau c si chaque famille POSSÉDÉE a un bâtiment au niveau min(30, 2c).
for c = 1, 14 do
  check(L.cc_condition_level(c) == math.min(30, 2 * c), "Q16 : centre " .. c .. " → " .. (c + 1) .. " : niveau visé " .. math.min(30, 2 * c))
end
local function census(spec)
  local t = {}
  for _, f in ipairs(L.families) do
    if f.key ~= "command" then t[f.key] = spec[f.key] or { any = false, top = false } end
  end
  return t
end
local blk = L.cc_blockers(census({}))
check(#blk == 0, "Q16 : aucune famille possédée → rien ne bloque")
blk = L.cc_blockers(census({ gun = { any = true, top = true }, wall = { any = true, top = false } }))
check(#blk == 1 and blk[1] == "wall", "Q16 : murs possédés sans mur au niveau visé → les murs bloquent (et eux seuls)")
blk = L.cc_blockers(census({ gun = { any = true, top = false }, laser = { any = true, top = false },
  wall = { any = true, top = true }, drill = { any = false, top = false }, assembler = { any = true, top = false } }))
check(#blk == 3 and blk[1] == "gun" and blk[2] == "laser" and blk[3] == "assembler",
  "Q16 : familles bloquantes dans l'ordre des familles (mitrailleuse, laser, machine), foreuse non possédée ignorée")
blk = L.cc_blockers(census({ gun = { any = true, top = true }, laser = { any = true, top = true }, wall = { any = true, top = true },
  drill = { any = true, top = true }, furnace = { any = true, top = true }, assembler = { any = true, top = true } }))
check(#blk == 0, "Q16 : un bâtiment au niveau visé dans chaque famille → condition remplie")

---------------------------------------------------------------------------------------------------
section("Noms (compatibilité 0.3.0)")
---------------------------------------------------------------------------------------------------
for _, f in ipairs(L.families) do
  for n = 1, f.max do
    local fam, lv = L.parse(L.name(f, n))
    check(fam == f and lv == n, f.key .. " : nom du niveau " .. n .. " réversible")
  end
  check(L.parse(L.PREFIX .. f.key .. "-" .. (f.max + 1)) == nil, f.key .. " : aucun niveau au-delà de " .. f.max)
end
-- Noms livrés en 0.3.0 (10 niveaux) : même famille, même niveau.
check(L.name(L.by_key.command, 1) == "fo-command-center", "0.3.0 : fo-command-center = centre niveau 1")
for _, f in ipairs(L.families) do
  for n = 2, L.LEGACY_MAX do
    local fam, lv = L.parse("fo-lvl-" .. f.key .. "-" .. n)
    check(fam == f and lv == n, "0.3.0 : fo-lvl-" .. f.key .. "-" .. n .. " garde son sens")
  end
end

---------------------------------------------------------------------------------------------------
section("Courbe de coûts par époque")
---------------------------------------------------------------------------------------------------
local max_qty, max_items = 0, 0
for _, f in ipairs(L.families) do
  local prev_value = -1
  local strict_value, positive = true, true
  for n = 2, f.max do
    local cost = L.cost(f, n)
    max_items = math.max(max_items, #cost)
    for _, c in ipairs(cost) do
      if not (c[2] >= 1 and c[2] == math.floor(c[2])) then positive = false end
      max_qty = math.max(max_qty, c[2])
    end
    local v = L.cost_value(cost)
    if not (v > prev_value) then strict_value = false; print("    " .. f.key .. " N" .. n .. " : valeur " .. v .. " <= " .. prev_value) end
    prev_value = v
    -- La monnaie de l'époque qui paie le niveau est exigée (époques 2+), et celle de l'époque précédente
    -- aussi (époques 3+, sauf les murs).
    local e = L.pay_epoch(f, n)
    local have = {}
    for _, c in ipairs(cost) do have[c[1]] = true end
    if L.epoch_materials[e] then
      check(have[L.epoch_materials[e].item], f.key .. " N" .. n .. " : monnaie de l'époque " .. e .. " exigée")
    end
    -- Même règle que raw_cost : la part de 40 % n'est exigée que si elle vaut au moins un demi-objet.
    local prev = L.epoch_materials[e - 1]
    if prev and L.epoch_materials[e] and not f.main_share
      and L.epoch_value(f, n) * (1 - L.MAIN_SHARE) / prev.value >= 0.5 then
      check(have[prev.item], f.key .. " N" .. n .. " : monnaie de l'époque " .. (e - 1) .. " exigée aussi")
    end
  end
  check(positive, f.key .. " : quantités entières et positives")
  check(strict_value, f.key .. " : valeur du coût strictement croissante")
end
-- Défaut connu, compté (BALANCE_SHEET §12) : au changement d'époque, la monnaie de l'époque précédente passe
-- de 60 % × 1,25 à 40 % de la valeur d'époque, et sa quantité baisse dès que value_mult[e] / value_mult[e-1]
-- < 1,875 ; la valeur totale, elle, croît toujours (testé plus haut).
local drops, drop_ex = 0, {}
for _, f in ipairs(L.families) do
  for n = 3, f.max do
    local before = {}
    for _, c in ipairs(L.cost(f, n - 1)) do before[c[1]] = c[2] end
    for _, c in ipairs(L.cost(f, n)) do
      if before[c[1]] and c[2] < before[c[1]] then
        drops = drops + 1
        if #drop_ex < 3 then drop_ex[#drop_ex + 1] = f.key .. " N" .. n .. " " .. c[1] .. " " .. before[c[1]] .. " → " .. c[2] end
      end
    end
  end
end
print("  Quantités d'une même monnaie en baisse d'un niveau au suivant : " .. drops .. " cas (" .. table.concat(drop_ex, " ; ") .. "…)")
-- Borne sur les OBJETS (la vraie contrainte est la PLACE, section suivante).
check(max_qty <= 2000, "pas d'explosion : au plus 2 000 objets d'une sorte par amélioration (" .. max_qty .. ")")
check(max_items <= 6, "au plus 6 sortes d'objets par amélioration (" .. max_items .. ")")
-- Croissance par époque, pas par exposant : le panier de base est linéaire (× 5,2 au niveau 30 au plus).
for _, f in ipairs(L.families) do
  local first, last = L.cost(f, 2)[1], L.cost(f, f.max)[1]
  check(first[1] == last[1] and last[2] / first[2] <= 1 + f.base_growth * (f.max - 2) + 0.2,
    f.key .. " : panier de base linéaire (" .. first[2] .. " → " .. last[2] .. " " .. first[1] .. ")")
end
-- Les tables par époque sont croissantes (valeur d'époque des familles ; passage du centre, panier compris,
-- testé plus haut par la valeur strictement croissante de la famille « command »).
for e = 2, L.EPOCHS do
  local a, b = L.epochs[e - 1], L.epochs[e]
  check(b.value_mult > a.value_mult, "époque " .. e .. " : value_mult croissant (" .. a.value_mult .. " → " .. b.value_mult .. ")")
end
for e = 2, L.CC_MAX - 1 do
  check(L.epochs[e].cc_value > 0, "époque " .. e .. " : le passage du centre exige la monnaie de l'époque (cc_value " .. L.epochs[e].cc_value .. ")")
end
check(L.epochs[1].cc_value == 0 and L.epochs[L.EPOCHS].cc_value == 0, "cc_value : époque 1 sans monnaie, époque 15 sans passage")
-- Le centre ne prend plus de durée : un coût, c'est tout (Q19).
check(L.epoch_value(L.by_key.command, 2) == 0 and L.cost_value(L.cost(L.by_key.command, 2)) > 0,
  "centre 1 → 2 : panier seul (l'époque 1 n'a pas de monnaie)")

---------------------------------------------------------------------------------------------------
section("Place : chaque chantier tient dans la moitié du coffre du centre qui le paie")
---------------------------------------------------------------------------------------------------
-- Correction V2 : le combustible nucléaire (pile de 1) rendait le centre 14 → 15 impayable (366 cases pour
-- un coffre de 256). Règle : Σ ⌈q / pile⌉ ≤ 50 % des cases du centre payeur (centre : n - 1 ; famille :
-- ⌈n / 2⌉, le plus petit centre qui l'autorise).
local worst = { share = 0 }
for _, f in ipairs(L.families) do
  local ok_f, detail = true, ""
  for n = 2, f.max do
    local slots, chest = L.cost_slots(L.cost(f, n)), L.chest_slots(L.payer_cc(f, n))
    if slots > L.MAX_SLOT_SHARE * chest then ok_f = false; detail = detail .. " N" .. n .. "=" .. slots .. "/" .. chest end
    if slots / chest > worst.share then worst = { share = slots / chest, key = f.key, n = n, slots = slots, chest = chest } end
  end
  check(ok_f, f.key .. " : chaque chantier tient dans la moitié du coffre du centre payeur" .. detail)
end
print(string.format("  Pire chantier : %s niveau %d, %d cases sur %d (%.0f %%)", worst.key, worst.n, worst.slots, worst.chest, 100 * worst.share))
check(L.chest_slots(1) == 48 and L.chest_slots(14) == 256 and L.chest_slots(15) == 272, "coffre du centre : 48 cases + 16 par niveau")
check(L.cost_slots({ { "uranium-235", 101 }, { "rocket-control-unit", 10 } }) == 3, "cases d'un coût : Σ ⌈q / pile⌉")

---------------------------------------------------------------------------------------------------
section("Table d'indirection « matériau d'époque → objet »")
---------------------------------------------------------------------------------------------------
-- Objets dont l'existence en 1.1.91 a été vérifiée par tests/datastage/harness.lua --dump-final (vanilla
-- et mod). Un objet absent de cette liste doit d'abord être vérifié, puis ajouté ici.
local W = require("shared.content.world")
local VERIFIED = {
  ["iron-plate"] = true, ["copper-plate"] = true, ["stone-brick"] = true, ["iron-gear-wheel"] = true,
  ["electronic-circuit"] = true, ["steel-plate"] = true, ["battery"] = true, ["engine-unit"] = true,
  ["plastic-bar"] = true, ["uranium-238"] = true, ["processing-unit"] = true, ["low-density-structure"] = true,
  ["electric-engine-unit"] = true, ["uranium-235"] = true, ["rocket-control-unit"] = true,
  ["space-science-pack"] = true,
  [W.resources.tungsten.plate.item] = true, [W.resources.crystal.item] = true,
  [W.resources.methane.fluid .. "-barrel"] = true, -- baril généré par le jeu de base pour chaque fluide
  ["fo-titanium-plate"] = true, -- lot X1-TITANE (prototypes/titanium.lua)
}
for _, item in ipairs(L.cost_items()) do
  check(VERIFIED[item], "objet de coût existant en jeu : " .. item)
  check(L.item_value[item] ~= nil, "objet de coût valorisé : " .. item)
end
local seen_items = {}
for e = 2, L.EPOCHS do
  local m = L.epoch_materials[e]
  check(m and m.item and m.want and m.key and m.value > 0, "époque " .. e .. " : matériau décrit (voulu, objet, valeur)")
  check(not seen_items[m.item], "époque " .. e .. " : matériau distinct des autres époques (" .. m.item .. ")")
  seen_items[m.item] = true
  if m.provisional then check(m.want_item and m.want_item:match("^fo%-"), "époque " .. e .. " : nom voulu proposé (" .. tostring(m.want_item) .. ")") end
end
check(L.epoch_materials[1] == nil, "époque 1 : payée par le panier de base")
-- Une seule valeur par objet : celle de la table d'indirection (raw_cost lit m.value, cost_value lit item_value).
for e = 2, L.EPOCHS do
  local m = L.epoch_materials[e]
  check(L.item_value[m.item] == m.value, "époque " .. e .. " : valeur unique de " .. m.item .. " (" .. tostring(L.item_value[m.item]) .. " = " .. m.value .. ")")
end
for _, f in ipairs(L.families) do
  for _, b in ipairs(f.base_cost) do check(L.item_value[b[1]] ~= nil, f.key .. " : panier de base valorisé (" .. b[1] .. ")") end
end
-- Piles : chaque objet de coût a sa taille de pile (miroir de l'étape data, vérifié en moteur réel par
-- content_test) ; les matériaux sous la pile minimale exigée du lot X0 sont listés.
for _, item in ipairs(L.cost_items()) do
  check(type(L.stack_size[item]) == "number" and L.stack_size[item] >= 1, "taille de pile connue : " .. item)
end
local low = {}
for e = 2, L.EPOCHS do
  local m = L.epoch_materials[e]
  if L.stack_size[m.item] < L.MIN_MATERIAL_STACK then low[#low + 1] = e .. "=" .. m.item .. " (" .. L.stack_size[m.item] .. ")" end
end
print("  Matériaux d'époque sous la pile minimale (" .. L.MIN_MATERIAL_STACK .. ") exigée des matériaux du lot X0 : " .. table.concat(low, ", "))
check(L.stack_size["nuclear-fuel"] == nil and L.epoch_materials[13].item ~= "nuclear-fuel",
  "époque 13 : plus de combustible nucléaire (pile de 1 : centre 15 impayable)")
print("  Remplaçants PROVISOIRES (matériau voulu → objet existant utilisé aujourd'hui) :")
local prov = L.provisional_materials()
for _, m in ipairs(prov) do
  print(string.format("    époque %2d %-15s %-35s → %s (voulu : %s)", m.epoch, m.key, m.want, m.item, m.want_item))
end
check(#prov == 4, "4 remplaçants provisoires (époques 12 à 15 depuis le lot X1-TITANE : " .. #prov .. ")")
for _, m in ipairs(prov) do check(m.epoch >= 12, "remplaçant provisoire seulement aux époques 12-15 (" .. m.key .. ")") end
check(L.epoch_materials[11].item == "fo-titanium-plate" and not L.epoch_materials[11].provisional and L.epoch_materials[11].value == 20,
  "époque 11 : la vraie plaque de titane (valeur 20 du scénario X0), plus de remplaçant")

---------------------------------------------------------------------------------------------------
section("Statistiques sur 30 niveaux")
---------------------------------------------------------------------------------------------------
for _, f in ipairs(L.families) do
  local keys = {}
  for k in pairs(VANILLA[f.key]) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local growing = true
    for n = 2, f.max do
      if not (stat_at(f, key, n) > stat_at(f, key, n - 1)) then growing = false end
    end
    check(growing, f.key .. " : " .. key .. " strictement croissant de 1 à " .. f.max)
    -- Pas d'explosion : au plus × 16 entre le niveau 1 et le dernier (PV des murs : × 15,5).
    local r = stat_at(f, key, f.max) / VANILLA[f.key][key]
    check(r <= 16, f.key .. " : " .. key .. " × " .. string.format("%.2f", r) .. " au niveau " .. f.max .. " (≤ 16)")
  end
end
-- Niveaux 1 à 10 : mêmes statistiques qu'en 0.3.0 (sauf les PV et résistances des murs, rééquilibrés).
check(math.abs(stat_at(G, "max_health", 10) - 940) < 1e-9 and math.abs(stat_at(G, "range", 10) - 20.25) < 1e-9,
  "mitrailleuse niveau 10 : 940 PV, portée 20,25 (comme en 0.3.0)")
check(math.abs(stat_at(L.by_key.wall, "max_health", 30) - 5425) < 1e-9, "mur niveau 30 : 5 425 PV (0.3.0 : × 1,3^29 ≈ 700 000)")
-- Comparaison au contenu du mod (shared/content/arsenal.lua) : le niveau 30 rejoint les versions « lourdes ».
local A = require("shared.content.arsenal")
local heavy = {}
for _, t in ipairs(A.turrets) do heavy[t.copy] = t end
local armored
for _, w in ipairs(A.walls) do if w.name == "fo-armored-wall" then armored = w end end
local gun30, laser30 = stat_at(G, "max_health", 30), stat_at(L.by_key.laser, "max_health", 30)
check(gun30 >= heavy["gun-turret"].hp and gun30 <= 1.5 * heavy["gun-turret"].hp,
  "mitrailleuse 30 : " .. gun30 .. " PV, entre 1 et 1,5 × la tourelle lourde (" .. heavy["gun-turret"].hp .. ")")
-- DPS (dégâts × cadence) : le dernier niveau rejoint la version lourde sans la dépasser de plus de 10 %.
local LZ = L.by_key.laser
for _, f in ipairs({ G, LZ }) do
  local d30, dh = dps_at(f, f.max), heavy_dps(f.key)
  check(d30 <= 1.1 * dh and d30 >= 0.8 * dh,
    string.format("%s 30 : DPS × %.2f, entre 0,8 et 1,1 × la version lourde (× %.2f)", f.key, d30, dh))
end
-- Niveaux 1 à 10 inchangés depuis 0.3.0 (+ 8 % de dégâts par niveau), dégressifs ensuite.
check(math.abs(stat_at(G, "damage_modifier", 10) - 1.72) < 1e-9 and math.abs(stat_at(G, "damage_modifier", 11) - 1.74) < 1e-9,
  "mitrailleuse : dégâts × 1,72 au niveau 10 (0.3.0), puis + 2 % par niveau")
-- Laser : l'énergie par tir suit les dégâts (dégâts par joule au niveau 30 : ± 10 % du niveau 1), et le
-- tampon contient toujours un tir.
local eff1 = stat_at(LZ, "damage_modifier", 1) / stat_at(LZ, "energy_consumption", 1)
local eff30 = stat_at(LZ, "damage_modifier", 30) / stat_at(LZ, "energy_consumption", 30)
check(eff30 >= 0.9 * eff1 and eff30 <= 1.1 * eff1, string.format("laser 30 : dégâts par joule × %.2f du niveau 1", eff30 / eff1))
local buffer_ok = true
for n = 1, 30 do
  if not (stat_at(LZ, "buffer_capacity", n) > stat_at(LZ, "energy_consumption", n)) then buffer_ok = false end
end
check(buffer_ok, "laser : le tampon contient un tir à tous les niveaux")
check(stat_at(L.by_key.laser, "range", 30) <= heavy["laser-turret"].range,
  "tourelle laser 30 : portée ≤ tourelle laser lourde (" .. heavy["laser-turret"].range .. ")")
check(laser30 <= 2 * heavy["laser-turret"].hp, "tourelle laser 30 : PV ≤ 2 × la tourelle laser lourde")
local wall30 = stat_at(L.by_key.wall, "max_health", 30)
check(armored and wall30 >= armored.hp and wall30 <= 2 * armored.hp,
  "mur 30 : " .. wall30 .. " PV, entre 1 et 2 × le mur blindé (" .. (armored and armored.hp or "?") .. ")")
check(stat_at(L.by_key.assembler, "crafting_speed", 30) <= 2 * 1.25,
  "machine d'assemblage 2 niveau 30 : vitesse ≤ 2 × la machine 3 vanilla (1,25)")

---------------------------------------------------------------------------------------------------
section("Durée de jeu : calendrier du scénario X0, durée impliquée par les coûts (lot V2c)")
---------------------------------------------------------------------------------------------------
-- Une seule source pour le calendrier (QX10) : L.target LIT shared/content/epochs.lua. L'ancienne courbe
-- (0,5 × 1,261^(e-1) h : 12,85 h pour l'époque 15) n'existe plus.
local X = require("shared.content.epochs")
do
for e = 1, L.EPOCHS do
  check(L.target.epoch_hours(e) == X.epoch_hours(e) and L.target.production(e) == X.rate_avg(e)
    and L.target.budget(e) == X.budget(e) and L.target.reach_hour(e) == X.reach_hour(e),
    string.format("époque %d : calendrier lu dans le scénario X0 (%.1f h, %.0f u/s)", e, X.epoch_hours(e), X.rate_avg(e)))
end
check(L.target.epoch_hours(15) == 7 and math.abs(L.target.epoch_hours(15) - 0.5 * 1.261 ^ 14) > 5,
  "époque 15 : 7 h (X0), plus 12,85 h (ancienne courbe du lot V2)")
check(L.target.cc_share == X.CODEX_LOT_SHARE, "part visée du passage du centre lue dans X0 (" .. X.CODEX_LOT_SHARE .. ")")
local rows = model()
-- La durée IMPLIQUÉE par les coûts (le calendrier est une entrée) : chaque époque à ± 5 % de sa durée X0,
-- l'époque 15 atteinte vers 52,5 h et la Porte ouverte vers 59,5 h (QX7 : « 60 h = ouverture de la Porte »).
for _, r in ipairs(rows) do
  check(math.abs(r.implied / r.hours - 1) <= 0.05,
    string.format("époque %d : durée impliquée %.2f h pour %.2f h (X0, ± 5 %%)", r.e, r.implied, r.hours))
end
local reach15 = rows[14].implied_cumul
check(math.abs(reach15 / X.reach_hour(15) - 1) <= 0.02,
  string.format("époque 15 atteinte à %.2f h (X0 : %.1f h, ± 2 %%)", reach15, X.reach_hour(15)))
check(math.abs(rows[15].implied_cumul / X.player_gate_hour() - 1) <= 0.02,
  string.format("Porte ouverte à %.2f h (X0 : %.1f h, ± 2 %%)", rows[15].implied_cumul, X.player_gate_hour()))
-- QX10 (contrat) : le passage du centre pèse environ 10 % du budget de l'époque. Époques 1 à 4 : au moins 5 %
-- (contrôle). Époques 5 à 14 : la règle de place (moitié du coffre du centre payeur, monnaies d'aujourd'hui)
-- le borne entre 3,4 et 0,11 % : le contrat n'est PAS tenu. Chaque époque sous 5 % est un ÉCART CONNU (non
-- conforme ; remèdes chiffrés dans BALANCE_SHEET §12, à trancher par le Directeur Créatif).
for e = 1, 4 do
  check(rows[e].cc_share >= 0.05, string.format("époque %d : passage du centre = %.1f %% du budget (≥ 5 %%)", e, 100 * rows[e].cc_share))
end
for e = 5, L.CC_MAX - 1 do
  known_gap(rows[e].cc_share >= 0.05, string.format("QX10 : époque %d, passage du centre = %.2f %% du budget (contrat : environ 10 %%, seuil 5 %%)",
    e, 100 * rows[e].cc_share))
end
--- Plus grande valeur du passage du centre vers n qui tient dans 45 % du coffre payeur (au plus 2 000 objets
--- d'une sorte), les autres passages à 0 ; la config est rendue intacte.
local function cc_place_bound(n)
  local saved = {}
  for e = 1, L.EPOCHS do saved[e] = L.epochs[e].cc_value; L.epochs[e].cc_value = 0 end
  local v = max_ok(0, 1e7, function(x)
    L.epochs[n - 1].cc_value = x
    L.rebuild()
    return cc_fits(n)
  end)
  L.epochs[n - 1].cc_value = v
  L.rebuild()
  local bound = L.cost_value(L.cost(L.by_key.command, n))
  for e = 1, L.EPOCHS do L.epochs[e].cc_value = saved[e] end
  L.rebuild()
  return bound
end
local bounds, eff_bound = {}, {}
for n = 3, L.CC_MAX do bounds[n] = cc_place_bound(n) end
eff_bound[L.CC_MAX] = bounds[L.CC_MAX]
for n = L.CC_MAX - 1, 3, -1 do eff_bound[n] = math.min(bounds[n], eff_bound[n + 1]) end
-- Contrôle de CALIBRAGE (pas du contrat QX10) : le passage du centre est au plus près de ce que la place permet.
for e = 4, L.CC_MAX - 1 do
  local n = e + 1
  local v = rows[e].cc_value
  local want = L.target.cc_share * L.target.budget(e)
  check(v >= 0.8 * math.min(want, eff_bound[n]),
    string.format("calibrage, époque %d : passage du centre %.0f u (%.2f %% du budget), au plus près de min(10 %% = %.0f, borne de place %.0f)",
      e, v, 100 * rows[e].cc_share, want, eff_bound[n]))
end
-- Chemin le plus court vers le centre 15 (vérification V2c) : le centre, plus UN bâtiment de chaque famille
-- possédée monté jusqu'au niveau visé à chaque passage (Q16 ; niveaux 2 à 28), payés avec une part de la
-- production X0 (débit moyen de chaque époque). Le calendrier (époque 15 à 52,5 h) ne vaut que si le joueur
-- monte TOUTE la base de référence : rien ne l'y oblige. ÉCART CONNU tant que ce chemin prend moins de la
-- moitié du calendrier.
local SIX = { "gun", "laser", "wall", "drill", "furnace", "assembler" }
local rush30, rush100 = rush_hours(SIX, L.target.spend_share), rush_hours(SIX, 1)
local rush_cc = rush_hours({}, L.target.spend_share)
print(string.format("  Chemin le plus court vers le centre 15 : %.2f h avec 30 %% de la production X0 (%.2f h avec 100 %%) ; centre seul (aucune famille possédée) : %.2f h ; calendrier X0 : %.1f h",
  rush30, rush100, rush_cc, L.target.reach_hour(15)))
check(rush30 > 0 and rush100 < rush30 and rush_cc < rush30, "chemin le plus court : chiffré (6 familles > centre seul ; 100 % de la production < 30 %)")
known_gap(rush30 >= 0.5 * L.target.reach_hour(15),
  string.format("QX7 : centre 15 atteignable en %.2f h (6 familles possédées, 30 %% de la production X0 ; %.2f h à 100 %%) pour %.1f h au calendrier : la durée de 52 h ne vaut que pour la base de référence complète",
    rush30, rush100, L.target.reach_hour(15)))
-- Correction V2c (vérification) : la config livrée EST la sortie de `--calibrate`, qui part d'un état de
-- référence fixe (panier V2 du centre) : la procédure documentée est reproductible, sans retouche à la main.
do
  local shipped = calib_state()
  calibrate()
  local got = calib_state()
  calib_restore(shipped)
  local function near(a, b) return math.abs(a - b) <= 1e-9 * math.max(1, math.abs(a)) end
  local diffs = {}
  for i = 1, math.max(#shipped.basket, #got.basket) do
    local a, b = shipped.basket[i], got.basket[i]
    if not (a and b and a[1] == b[1] and a[2] == b[2]) then
      diffs[#diffs + 1] = "panier " .. i .. " : " .. (a and (a[1] .. " " .. a[2]) or "—") .. " / " .. (b and (b[1] .. " " .. b[2]) or "—")
    end
  end
  for e = 1, L.EPOCHS do
    if not near(shipped.value_mult[e], got.value_mult[e]) then diffs[#diffs + 1] = "value_mult " .. e .. " : " .. shipped.value_mult[e] .. " / " .. got.value_mult[e] end
    if not near(shipped.cc_value[e], got.cc_value[e]) then diffs[#diffs + 1] = "cc_value " .. e .. " : " .. shipped.cc_value[e] .. " / " .. got.cc_value[e] end
  end
  check(#diffs == 0, "`--calibrate` (état de référence fixe) redonne exactement la config livrée" .. (#diffs > 0 and (" : " .. table.concat(diffs, " ; ")) or ""))
  local after = model()
  check(math.abs(after[L.EPOCHS].implied_cumul - rows[L.EPOCHS].implied_cumul) < 1e-9, "config rendue intacte après le calibrage du test")
  -- Le panier écrit est celui que le joueur paie au passage 1 → 2 (arrondi de L.round_nice).
  local paid, same = L.cost(L.by_key.command, 2), true
  for i, b in ipairs(L.by_key.command.base_cost) do if not (paid[i] and paid[i][1] == b[1] and paid[i][2] == b[2]) then same = false end end
  check(same, "panier du centre écrit = panier payé au passage 1 → 2 (" .. cost_text(paid) .. ")")
end
-- Paramètre de l'équipe de PNJ (lot IA1) : coûts × facteur et production × facteur, durées presque inchangées.
-- Aux époques 2 à 4, les planchers (au moins 1 objet de la monnaie, niveau jamais moins cher que le précédent)
-- ne doublent pas : jusqu'à 15 % d'écart par époque, total à 2 % près. Le lot IA1 relance `--calibrate` avec
-- son facteur pour retomber sur le calendrier, et revérifie la place (affichée ci-dessous).
local value_1 = L.cost_value(L.cost(L.by_key.laser, 30))
L.TEAM_FACTOR = 2
L.rebuild()
local rows2 = model()
local team_ok, place_bad, team_dev = true, {}, 0
for e = 1, L.EPOCHS do
  local d = math.abs(rows2[e].implied / rows[e].implied - 1)
  if d > team_dev then team_dev = d end
  if d > 0.15 then team_ok = false end
end
if math.abs(rows2[L.EPOCHS].implied_cumul / rows[L.EPOCHS].implied_cumul - 1) > 0.02 then team_ok = false end
for _, f in ipairs(L.families) do
  for n = 2, f.max do
    if L.cost_slots(L.cost(f, n)) > L.MAX_SLOT_SHARE * L.chest_slots(L.payer_cc(f, n)) then place_bad[#place_bad + 1] = f.key .. n end
  end
end
local value_2 = L.cost_value(L.cost(L.by_key.laser, 30))
L.TEAM_FACTOR = 1
L.rebuild()
check(team_ok and math.abs(value_2 / value_1 - 2) < 0.02,
  string.format("L.TEAM_FACTOR = 2 : coûts × %.3f, durées impliquées à 15 %% près par époque (écart maximal %.1f %%), total %.1f h",
    value_2 / value_1, 100 * team_dev, rows2[L.EPOCHS].implied_cumul))
print("  Facteur d'équipe 2 : coûts hors de la règle de place : " .. (#place_bad > 0 and table.concat(place_bad, ", ") or "aucun"))
check(L.TEAM_FACTOR == 1 and math.abs(L.cost_value(L.cost(L.by_key.laser, 30)) - value_1) < 1e-9, "facteur d'équipe rendu à 1 (joueur seul)")
print(string.format("  Durée impliquée totale : %.1f h ; production × 0,7 : %.1f h, × 1,3 : %.1f h",
  rows[15].implied_cumul, model(0.7)[L.EPOCHS].implied_cumul, model(1.3)[L.EPOCHS].implied_cumul))
end

---------------------------------------------------------------------------------------------------
section("Traductions FR et EN des clés du runtime")
---------------------------------------------------------------------------------------------------
local function cfg_keys(path, keys)
  local fh = io.open(path, "r")
  if not fh then return false end
  local sec = ""
  for line in fh:lines() do
    local s = line:match("^%[(.-)%]")
    if s then sec = s else
      local k = line:match("^([^=;#]+)=")
      if k then keys[sec .. "." .. k] = true end
    end
  end
  fh:close()
  return true
end
for _, lang in ipairs({ "fr", "en" }) do
  local keys = {}
  check(cfg_keys("locale/" .. lang .. "/v2.cfg", keys) and cfg_keys("locale/" .. lang .. "/factorio-overhaul.cfg", keys),
    lang .. " : fichiers de traduction lus")
  local need = { "fo-epochs.desc", "fo-epochs.level-line", "fo-epochs.next-line", "fo-epochs.new-silhouette",
    "fo-epochs.new-piece", "fo-epochs.currency", "fo-epochs.currency-provisional", "fo-epochs.epoch-up",
    "fo-epochs.reason-unknown-item", "fo-levels.name", "fo-levels.level-up", "fo-epochs.cc-line",
    "fo-levels.reason-cc-too-low", "fo-levels.maxed", "fo-levels.panel-title", "fo-epochs.desc-cc",
    "fo-epochs.stat-energy_consumption", "fo-epochs.visual", "fo-epochs.desc-cc-max", "fo-epochs.cc-rule",
    "fo-epochs.cc-rule-ok", "fo-epochs.cc-rule-missing", "fo-epochs.reason-cc-families", "fo-levels.instant",
    "fo-levels.msg-done", "fo-levels.reason-no-resources", "fo-levels.upgrade-row" }
  for e = 1, L.EPOCHS do
    need[#need + 1] = "fo-epochs.name-" .. L.epochs[e].key
    if L.epoch_materials[e] then need[#need + 1] = "fo-epochs.want-" .. L.epoch_materials[e].key end
  end
  for _, k in ipairs(need) do check(keys[k], lang .. " : clé " .. k) end
end

---------------------------------------------------------------------------------------------------
section("Garde de l'interface des fichiers de famille (étape data, prototypes simulés)")
---------------------------------------------------------------------------------------------------
-- Correction V2 : la garde était une liste de champs de jeu, trouée (preparing_speed, prepare_range,
-- healing_per_tick, resource_searching_radius, base_productivity, ammo_type, data.raw, ctx). Elle capture
-- désormais TOUT le prototype sauf une liste blanche graphique. Correction V2b : l'état partagé est comparé
-- EN ENTIER (toute la config L, fonctions comprises), data.raw aussi (types surveillés et référencés par
-- famille, puis tout data.raw), et chaque refus est vérifié sur son MOTIF (chemin modifié, « état
-- partagé », « source », « lecture seule »…). Chaque cas ci-dessous est un dress d'agent V3 plausible.
-- Contre-vérification V2b : copie déclarée modifiée APRÈS edit (p17), icons attribué à son niveau (p20), famille
-- suivante qui modifie une famille fermée (p23) ; mutants de la garde détectés (BALANCE_SHEET §12).
local saved_deepcopy, saved_data = table.deepcopy, rawget(_G, "data")
local function deepcopy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local c = {}
  seen[t] = c
  for k, v in pairs(t) do c[deepcopy(k, seen)] = deepcopy(v, seen) end
  return c
end
table.deepcopy = deepcopy
local function sprite(frames) return { filename = "__base__/x.png", width = 8, height = 8, frame_count = frames } end
local function fake_gun()
  return {
    type = "ammo-turret", name = "fo-lvl-gun-5", max_health = 640, prepare_range = 22, rotation_speed = 0.018,
    preparing_speed = 0.08, folding_speed = 0.08, attacking_speed = 0.5, automated_ammo_count = 10,
    call_for_help_radius = 40, healing_per_tick = 0, fast_replaceable_group = "fo-lvl-gun",
    selection_box = { { -1, -1 }, { 1, 1 } }, resistances = { { type = "physical", decrease = 0 } },
    base_picture = { layers = { sprite(1) } }, preparing_animation = { layers = { sprite(8), sprite(8) } },
    folding_animation = { layers = { sprite(8) } }, attacking_animation = { layers = { sprite(2) } },
    working_sound = { filename = "__base__/s.ogg" },
    attack_parameters = { type = "projectile", range = 19, cooldown = 6, damage_modifier = 1.32,
      ammo_category = "bullet", projectile_center = { 0, 0.1 }, projectile_creation_distance = 1.4,
      sound = { { filename = "__base__/s.ogg" } } },
  }
end
local function fake_laser()
  return {
    type = "electric-turret", name = "fo-lvl-laser-5", max_health = 1600, rotation_speed = 0.012, preparing_speed = 0.05,
    folding_speed = 0.05, preparing_animation = { layers = { sprite(15) } }, base_picture = { layers = { sprite(1) } },
    energy_source = { type = "electric", buffer_capacity = "929kJ", drain = "24kW", usage_priority = "primary-input" },
    attack_parameters = { type = "beam", range = 25, cooldown = 40, damage_modifier = 2.64, source_offset = { 0, -0.85 },
      ammo_type = { category = "laser", energy_consumption = "928kJ", action = { type = "direct",
        action_delivery = { type = "beam", beam = "laser-beam", max_length = 24, duration = 40, source_offset = { 0, -1.3 } } } } },
  }
end
local function fake_drill()
  return {
    type = "mining-drill", name = "fo-lvl-drill-5", max_health = 480, mining_speed = 0.7, energy_usage = "115.2kW",
    resource_searching_radius = 2.49, base_productivity = 0, vector_to_place_result = { 0, -1.85 },
    graphics_set = { animation = { north = { layers = { sprite(1) } } } },
    input_fluid_box = { base_area = 1, pipe_picture = { north = sprite(1) }, pipe_connections = { { position = { -2, 0 } } } },
    module_specification = { module_slots = 3, module_info_icon_shift = { 0, 0.5 } },
  }
end
local function fake_beam(name, damage)
  return { type = "beam", name = name, width = 0.5, damage_interval = 20, random_target_offset = true,
    action = { type = "direct", action_delivery = { type = "instant",
      target_effects = { { type = "damage", damage = { amount = damage, type = "laser" } } } } },
    head = sprite(1), tail = sprite(1), body = { sprite(1) }, light_animations = { head = sprite(1) },
    working_sound = { sound = { filename = "__base__/s.ogg" } } }
end
-- data.raw simulé, refait avant chaque cas (un refus qui l'a modifié ne pollue pas le suivant).
local function make_raw()
  return {
    ["ammo-turret"] = { ["gun-turret"] = { type = "ammo-turret", name = "gun-turret", max_health = 400,
      corpse = "gun-turret-remnants", dying_explosion = "gun-turret-explosion" } },
    ["electric-turret"] = { ["laser-turret"] = { type = "electric-turret", name = "laser-turret", max_health = 1000 } },
    ["mining-drill"] = { ["electric-mining-drill"] = { type = "mining-drill", name = "electric-mining-drill", max_health = 300 } },
    item = { ["gun-turret"] = { type = "item", name = "gun-turret", stack_size = 50, place_result = "gun-turret" } },
    recipe = { ["gun-turret"] = { type = "recipe", name = "gun-turret", energy_required = 8 } },
    ammo = { ["firearm-magazine"] = { type = "ammo", name = "firearm-magazine", magazine_size = 10,
      ammo_type = { category = "bullet", action = { type = "direct" } } } },
    beam = { ["laser-beam"] = fake_beam("laser-beam", 10), ["electric-beam"] = fake_beam("electric-beam", 40) },
    projectile = { ["cannon-projectile"] = { type = "projectile", name = "cannon-projectile", acceleration = 0 } },
    explosion = { ["gun-turret-explosion"] = { type = "explosion", name = "gun-turret-explosion", animations = { sprite(4) } } },
    corpse = { ["gun-turret-remnants"] = { type = "corpse", name = "gun-turret-remnants", time_before_removed = 54000,
      animation = sprite(1) } },
    sticker = { ["slowdown-sticker"] = { type = "sticker", name = "slowdown-sticker", duration_in_ticks = 120 } },
    ["trivial-smoke"] = { smoke = { type = "trivial-smoke", name = "smoke", duration = 60 } },
    ["optimized-particle"] = { ["stone-particle"] = { type = "optimized-particle", name = "stone-particle", life_time = 60 } },
    tile = { concrete = { type = "tile", name = "concrete", variants = { material_background = { picture = "__base__/c.png", count = 8 } } } },
    technology = { ["physical-projectile-damage-1"] = { type = "technology", name = "physical-projectile-damage-1",
      effects = { { type = "ammo-damage", ammo_category = "bullet", modifier = 0.1 } } } },
  }
end
_G.data = { raw = make_raw() }
local Common = require("prototypes.levels.common")
local Style = require("prototypes.levels.style")

-- Restauration EN PLACE de l'état partagé (config, boîte à outils, style) après un cas refusé : chaque table
-- retrouve ses clés et ses valeurs d'origine (identités comprises).
local function record(root)
  local rec, seen = {}, {}
  local function walk(t)
    if seen[t] then return end
    seen[t] = true
    local kv = {}
    for k, v in pairs(t) do
      kv[k] = v
      if type(v) == "table" then walk(v) end
    end
    rec[#rec + 1] = { t = t, kv = kv }
  end
  walk(root)
  return rec
end
local SHARED_REC = record({ L, Common.kit, Style })
local function restore_shared()
  for _, e in ipairs(SHARED_REC) do
    for k in pairs(e.t) do if e.kv[k] == nil then e.t[k] = nil end end
    for k, v in pairs(e.kv) do e.t[k] = v end
  end
end

--- Lance un cas : dress (garde complète autour de ce seul appel), puis vérifie l'issue et le motif.
--- expect = true (accepté) ou liste de motifs que le message de refus doit contenir (recherche littérale).
local refused_n, accepted_n = 0, 0
local function verify(okg, err, expect, label)
  local good = okg == (expect == true)
  local missing = {}
  if good and expect ~= true then
    for _, motif in ipairs(expect) do
      if not tostring(err):find(motif, 1, true) then missing[#missing + 1] = motif end
    end
    good = #missing == 0
  end
  check(good, string.format("garde : %s → %s%s%s", label, expect == true and "accepté" or "refusé",
    (okg ~= (expect == true)) and (" (obtenu : " .. tostring(err) .. ")") or "",
    (#missing > 0) and (" (motif absent : « " .. table.concat(missing, " », « ") .. " » dans : " .. tostring(err) .. ")") or ""))
  if expect == true then accepted_n = accepted_n + 1 else refused_n = refused_n + 1 end
  restore_shared()
end
local function run_case(fam, make, fn, expect, label)
  _G.data = { raw = make_raw() }
  local okg, err = pcall(Common.dress, { dress = fn }, make(), fam, 5)
  verify(okg, err, expect, label)
end

local SRC = "prototype source"
local SHARED_MOTIF = "état partagé"
local RO = "lecture seule"
local GUARD_CASES = {
  -- { famille, prototype, dress, true (accepté) | { motifs du refus }, libellé }
  { G, fake_gun, function(p) p.base_picture.layers[1].tint = { r = 1, g = 0.5, b = 0.5 }; p.base_picture.layers[2] = sprite(1) end, true, "teinte et couche ajoutée" },
  { G, fake_gun, function(p) p.working_sound = { filename = "__base__/t.ogg" }; p.attack_parameters.sound = nil end, true, "sons" },
  -- Correction INT-GARDE (E67, lot A1, moteur réel : la levée dure 1 / preparing_speed, quel que soit le nombre
  -- d'images ou repeat_count). Les vitesses sont des clés de JEU ; le nombre d'images est libre.
  { G, fake_gun, function(p) p.preparing_animation = { layers = { sprite(16) } }; p.preparing_speed = 0.16 end,
    { "« preparing_speed »", "valeur modifiée" }, "deux fois plus d'images, deux fois plus vite (levée deux fois plus courte : E67)" },
  { G, fake_gun, function(p) p.preparing_animation = { layers = { sprite(1) } }; p.folding_animation = { layers = { sprite(1) } };
      p.attacking_animation = { layers = { sprite(1) } } end, true, "tête à 1 image à la vitesse vanilla (levée, repli, tir : E67)" },
  { G, fake_gun, function(p) local s = sprite(1); s.repeat_count = 5; p.preparing_animation = { layers = { s } } end, true,
    "levée 1 image × repeat_count 5 à la vitesse vanilla (E67)" },
  { G, fake_gun, function(p) p.preparing_animation = nil end, { "durée de preparing_animation", "animation retirée" },
    "levée sans animation (effet en jeu non mesuré : refusé par prudence)" },
  { G, fake_gun, function(p) p.ending_attack_animation = { layers = { sprite(1) } } end, { "durée de ending_attack_animation", "animation ajoutée" },
    "animation de fin de tir ajoutée (effet en jeu non mesuré : refusé par prudence)" },
  { G, fake_gun, function(p) p.preparing_animation = { layers = { sprite(1) } }; p.preparing_speed = 0.01 end,
    { "« preparing_speed »", "valeur modifiée" }, "1 image à 0,01 (même « images / vitesse » que 8 à 0,08, mais levée 8 fois plus lente : E67)" },
  { G, fake_gun, function(p) p.attacking_speed = 0.25 end, { "« attacking_speed »", "valeur modifiée" }, "attacking_speed seul" },
  { G, fake_gun, function(p) p.folding_speed = 0.04; p.folding_animation = { layers = { sprite(4) } } end,
    { "« folding_speed »", "valeur modifiée" }, "folding_speed et images réduits ensemble (ancienne « même durée »)" },
  { G, fake_gun, function(p) p.starting_attack_speed = 1 end, { "« starting_attack_speed »", "clé ajoutée" },
    "starting_attack_speed ajouté (même à la valeur par défaut)" },
  { G, fake_gun, function(p) p.ending_attack_speed = 0.5 end, { "« ending_attack_speed »", "clé ajoutée" }, "ending_attack_speed ajouté" },
  { G, fake_gun, function(p) p.preparing_speed = nil end, { "« preparing_speed »", "clé retirée" }, "preparing_speed retiré (défaut 1 : levée en 1 tick)" },
  { LZ, fake_laser, function(p) p.preparing_animation = { layers = { sprite(1) } } end, true, "laser : levée à 1 image (E67)" },
  { LZ, fake_laser, function(p) p.folding_speed = 0.1 end, { "« folding_speed »" }, "laser : folding_speed" },
  { G, fake_gun, function(p) p.attack_parameters.projectile_center = { 0, 0.4 } end, true, "origine des balles (visuel)" },
  { G, fake_gun, function(p, ctx) ctx.color.r = 0 end, true, "ctx.color est une copie" },
  { G, fake_gun, function(p, ctx) local _ = ctx.L.CC_HEALTH + #ctx.L.families + ctx.kit.palette.glow[5].r end, true, "lecture de ctx.L et de ctx.kit" },
  { G, fake_gun, function(p, ctx) p.corpse = "gun-turret-remnants"; p.dying_explosion = "gun-turret-explosion" end, true, "reste et explosion vanilla existants (références graphiques)" },
  { G, fake_gun, function(p) p.preparing_speed = 0.16 end, { "« preparing_speed »", "valeur modifiée" }, "preparing_speed seul (déploiement deux fois plus court)" },
  { G, fake_gun, function(p) p.folding_animation = { layers = { sprite(4) } } end, true, "repli à moins d'images, même vitesse (même durée : E67)" },
  { G, fake_gun, function(p) p.prepare_range = 30 end, { "« prepare_range »", "valeur modifiée" }, "prepare_range" },
  { G, fake_gun, function(p) p.healing_per_tick = 1 end, { "« healing_per_tick »" }, "healing_per_tick" },
  { G, fake_gun, function(p) p.automated_ammo_count = 50 end, { "« automated_ammo_count »" }, "automated_ammo_count" },
  { G, fake_gun, function(p) p.call_for_help_radius = nil end, { "« call_for_help_radius »", "clé retirée" }, "clé de jeu retirée" },
  { G, fake_gun, function(p) p.alert_when_attacking = false end, { "« alert_when_attacking »", "clé ajoutée" }, "clé de jeu ajoutée" },
  { G, fake_gun, function(p) p.attack_parameters.cooldown = 4 end, { "« attack_parameters.cooldown »" }, "attack_parameters.cooldown" },
  { G, fake_gun, function(p) p.max_health = 9999 end, { "« max_health »" }, "max_health" },
  { G, fake_gun, function(p) p.selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } } end, { "« selection_box[1][1] »" }, "selection_box" },
  { G, fake_gun, function(p) p.resistances[1].decrease = 5 end, { "« resistances[1].decrease »" }, "resistances" },
  { G, fake_gun, function(p) data.raw["ammo-turret"]["gun-turret"].max_health = 1 end,
    { SRC, 'data.raw["ammo-turret"]["gun-turret"].max_health', "gun.lua (niveau 5" }, "data.raw : prototype vanilla copié (source)" },
  { G, fake_gun, function(p) data.raw.item["gun-turret"].stack_size = 1 end, { SRC, 'data.raw.item["gun-turret"].stack_size' }, "data.raw : objet source" },
  { G, fake_gun, function(p, ctx) ctx.family.size = 9 end, { "ctx.family.size", RO }, "ctx.family (lecture seule)" },
  { G, fake_gun, function(p, ctx) ctx.level = 30 end, { RO, "« level »" }, "écriture dans ctx" },
  { G, fake_gun, function(p, ctx) ctx.L.epochs[2].color.r = 0 end, { SHARED_MOTIF, "L.epochs[2].color.r", RO }, "config partagée (ctx.L)" },
  { G, fake_gun, function(p, ctx) ctx.kit.palette.glow[5] = { r = 0, g = 0, b = 0 } end, { SHARED_MOTIF, "palette.glow[5]" }, "style commun (ctx.kit.palette)" },
  { LZ, fake_laser, function(p) p.attack_parameters.ammo_type.action.action_delivery.source_offset = { 0, -2 } end, true, "origine du faisceau (visuel)" },
  { LZ, fake_laser, function(p) p.attack_parameters.ammo_type.energy_consumption = "100kJ" end, { "« attack_parameters.ammo_type.energy_consumption »" }, "ammo_type.energy_consumption" },
  { LZ, fake_laser, function(p) p.attack_parameters.ammo_type.action.action_delivery.max_length = 40 end, { "action_delivery.max_length »" }, "longueur du faisceau" },
  { LZ, fake_laser, function(p) p.attack_parameters.ammo_type.action.action_delivery.beam = "electric-beam" end, { "action_delivery.beam »" }, "faisceau (ses dégâts)" },
  { LZ, fake_laser, function(p) p.energy_source.buffer_capacity = "2MJ" end, { "« energy_source.buffer_capacity »" }, "tampon d'énergie" },
  { L.by_key.drill, fake_drill, function(p) p.graphics_set.animation.north.layers[2] = sprite(1); p.input_fluid_box.pipe_picture = nil end, true, "foreuse : animation et tuyaux (visuel)" },
  { L.by_key.drill, fake_drill, function(p) p.module_specification.module_info_icon_shift = { 0, 0 } end, true, "foreuse : icône des modules (visuel)" },
  { L.by_key.drill, fake_drill, function(p) p.resource_searching_radius = 4.49 end, { "« resource_searching_radius »" }, "resource_searching_radius" },
  { L.by_key.drill, fake_drill, function(p) p.base_productivity = 0.5 end, { "« base_productivity »" }, "base_productivity" },
  { L.by_key.drill, fake_drill, function(p) p.module_specification.module_slots = 4 end, { "« module_specification.module_slots »" }, "module_slots" },
  { L.by_key.drill, fake_drill, function(p) p.input_fluid_box.base_area = 10 end, { "« input_fluid_box.base_area »" }, "boîte à fluide" },
  -- V2b, état partagé : chemins que l'ancienne garde (epochs, matériaux, familles, valeurs, piles) laissait passer.
  { G, fake_gun, function() require("shared.levels.config").CC_HEALTH = 1 end, { SHARED_MOTIF, "L.CC_HEALTH", RO }, "config par require (L.CC_HEALTH)" },
  { G, fake_gun, function(p, ctx) ctx.L.parse("fo-lvl-gun-2").max = 99 end, { SHARED_MOTIF, ".gun.max" }, "famille rendue par L.parse" },
  { G, fake_gun, function(p, ctx) ctx.L.NOUVELLE_CLE = 1 end, { SHARED_MOTIF, "L.NOUVELLE_CLE", "clé ajoutée" }, "clé ajoutée à la config" },
  { G, fake_gun, function(p, ctx) ctx.L.MAX_SLOT_SHARE = nil end, { SHARED_MOTIF, "L.MAX_SLOT_SHARE", "clé retirée" }, "clé retirée de la config" },
  { G, fake_gun, function(p, ctx) ctx.L.cost = function() return {} end end, { SHARED_MOTIF, "L.cost" }, "fonction de la config remplacée" },
  { G, fake_gun, function(p, ctx) ctx.L.target.spend_share = 1 end, { SHARED_MOTIF, "L.target.spend_share" }, "hypothèses du modèle (L.target)" },
  { G, fake_gun, function(p, ctx) ctx.L.epochs[7].cc_value = 1 end, { SHARED_MOTIF, "L.epochs[7].cc_value" }, "passage du centre (cc_value, V2c)" },
  { G, fake_gun, function(p, ctx) ctx.L.TEAM_FACTOR = 2 end, { SHARED_MOTIF, "L.TEAM_FACTOR" }, "facteur d'équipe (V2c)" },
  { G, fake_gun, function(p, ctx) ctx.kit.tint = function() end end, { SHARED_MOTIF, "kit.tint" }, "fonction de ctx.kit remplacée" },
  { G, fake_gun, function(p, ctx) ctx.kit.lib.PREFIX = "x-" end, { SHARED_MOTIF, "kit.lib.PREFIX" }, "prototypes/lib.lua par ctx.kit.lib" },
  { G, fake_gun, function() require("prototypes.levels.style").palette.foundation[3].tile = "stone-path" end,
    { SHARED_MOTIF, "palette.foundation[3].tile" }, "style commun par require" },
  -- V2b, data.raw hors des sources : types surveillés, type référencé, tout le reste.
  { G, fake_gun, function() data.raw.ammo["firearm-magazine"].magazine_size = 20 end,
    { 'data.raw.ammo["firearm-magazine"].magazine_size', "prototype partagé", "gun.lua (niveau 5" }, "munition vanilla (firearm-magazine)" },
  { LZ, fake_laser, function() data.raw.beam["laser-beam"].damage_interval = 10 end, { 'data.raw.beam["laser-beam"].damage_interval', "prototype partagé" }, "faisceau vanilla (dégâts)" },
  { LZ, fake_laser, function() data.raw.beam["laser-beam"].body[1].tint = { r = 1, g = 0, b = 0 } end, { 'data.raw.beam["laser-beam"].body[1].tint', "ctx.declare" }, "faisceau vanilla (visuel : passer par ctx.declare)" },
  { G, fake_gun, function() data.raw.projectile["cannon-projectile"].acceleration = 1 end, { 'data.raw.projectile["cannon-projectile"]' }, "projectile" },
  { G, fake_gun, function() data.raw.explosion["gun-turret-explosion"].animations[1].tint = { r = 1, g = 0, b = 0 } end, { 'data.raw.explosion["gun-turret-explosion"]' }, "explosion" },
  { G, fake_gun, function() data.raw.corpse["gun-turret-remnants"].time_before_removed = 1 end, { 'data.raw.corpse["gun-turret-remnants"]' }, "reste (corpse)" },
  { G, fake_gun, function() data.raw.sticker["slowdown-sticker"].duration_in_ticks = 1 end, { 'data.raw.sticker["slowdown-sticker"]' }, "autocollant (sticker)" },
  { G, fake_gun, function() data.raw["trivial-smoke"].smoke.duration = 1 end, { 'data.raw["trivial-smoke"].smoke.duration' }, "fumée" },
  { G, fake_gun, function() data.raw["optimized-particle"]["stone-particle"].life_time = 1 end, { 'data.raw["optimized-particle"]["stone-particle"]' }, "particule" },
  { G, fake_gun, function() data.raw.tile.concrete.variants.material_background.count = 1 end, { 'data.raw.tile.concrete.variants.material_background.count' }, "tuile du socle" },
  { G, fake_gun, function() data.raw.recipe["gun-turret"].energy_required = 1 end, { 'data.raw.recipe["gun-turret"].energy_required' }, "type référencé par la source (recette du même nom)" },
  { G, fake_gun, function() data.raw.technology["physical-projectile-damage-1"].effects[1].modifier = 9 end,
    { 'data.raw.technology["physical-projectile-damage-1"].effects[1].modifier' }, "type ni surveillé ni référencé (tout data.raw)" },
  { LZ, fake_laser, function() data.raw.beam["fo-mon-faisceau"] = fake_beam("fo-mon-faisceau", 10) end,
    { 'data.raw.beam["fo-mon-faisceau"]', "prototype ajouté" }, "prototype ajouté pendant dress (data:extend)" },
}

local function declare_beam(suffix, edit, source)
  return function(p, ctx)
    local name = ctx.declare("beam", source or "laser-beam", suffix, edit)
    p.attack_parameters.ammo_type.action.action_delivery.beam = name
  end
end
local DECLARE_CASES = {
  { LZ, fake_laser, declare_beam("beam", function(b) b.body = { sprite(4) }; b.head.tint = { r = 1, g = 0.2, b = 0.2 }; b.light_animations = nil end), true,
    "ctx.declare : faisceau propre (visuel) et référence remplacée" },
  { LZ, fake_laser, function(p, ctx) ctx.declare("corpse", "gun-turret-remnants", "reste", function(c) c.animation = sprite(2) end) end, true,
    "ctx.declare : reste propre (visuel)" },
  { LZ, fake_laser, declare_beam("beam", function(b) b.damage_interval = 5 end), { "ctx.declare", "« damage_interval »" }, "ctx.declare : intervalle de dégâts changé" },
  { LZ, fake_laser, declare_beam("beam", function(b) b.action.action_delivery.target_effects[1].damage.amount = 99 end),
    { "ctx.declare", "« action.action_delivery.target_effects[1].damage.amount »" }, "ctx.declare : dégâts changés" },
  { LZ, fake_laser, declare_beam("beam", function(b) b.body = { sprite(2) } end, "electric-beam"), { "« attack_parameters.ammo_type.action.action_delivery.beam »" },
    "ctx.declare : référence vers la copie d'une AUTRE source" },
  { LZ, fake_laser, function(p, ctx) ctx.declare("ammo", "firearm-magazine", "m", nil) end, { "ctx.declare", "non pris en charge" }, "ctx.declare : type non pris en charge" },
  { LZ, fake_laser, function(p, ctx) ctx.declare("beam", "faisceau-inconnu", "b", nil) end, { "ctx.declare", "introuvable" }, "ctx.declare : source introuvable" },
  { LZ, fake_laser, function(p, ctx) ctx.declare("beam", "laser-beam", "b", nil); ctx.declare("beam", "laser-beam", "b", nil) end,
    { "ctx.declare", "déjà pris : fo-lvl-laser-5-b" }, "ctx.declare : même nom deux fois" },
  { LZ, fake_laser, function(p, ctx) ctx.declare("beam", "laser-beam", "b c", nil) end, { "ctx.declare", "suffixe invalide" }, "ctx.declare : suffixe invalide" },
  { LZ, fake_laser, declare_beam("beam", function(b) data.raw.beam["laser-beam"].width = 2 end), { 'data.raw.beam["laser-beam"].width' },
    "ctx.declare : edit modifie la source dans data.raw" },
  -- Contre-vérification V2b (sonde p17) : une référence à la copie gardée par edit permettait de la modifier
  -- APRÈS la vérification (faisceau du niveau sans dégâts, accepté). La copie est comparée de nouveau après dress.
  { LZ, fake_laser, function(p, ctx)
      local saved
      local n = ctx.declare("beam", "laser-beam", "beam", function(b) saved = b end)
      saved.damage_interval = 1
      saved.action = nil
      p.attack_parameters.ammo_type.action.action_delivery.beam = n
    end, { "laser.lua (niveau 5) : dress a modifié la copie déclarée « fo-lvl-laser-5-beam »", "« action »", "clé retirée" },
    "ctx.declare : copie modifiée après edit par une référence gardée (p17 : action retirée)" },
  { LZ, fake_laser, function(p, ctx)
      local saved
      ctx.declare("beam", "laser-beam", "beam", function(b) saved = b end)
      saved.damage_interval = 1
    end, { "copie déclarée « fo-lvl-laser-5-beam »", "« damage_interval »", "valeur modifiée" },
    "ctx.declare : intervalle de dégâts changé après edit" },
  { LZ, fake_laser, function(p, ctx)
      local saved
      ctx.declare("beam", "laser-beam", "beam", function(b) saved = b end)
      saved.name = "laser-beam"
    end, { "copie déclarée « fo-lvl-laser-5-beam »", "« name »" }, "ctx.declare : copie renommée après edit (nom de la source)" },
  { LZ, fake_laser, function(p, ctx)
      local saved
      ctx.declare("beam", "laser-beam", "beam", function(b) saved = b end)
      saved.localised_name = { "fo-levels.name", { "entity-name.laser-turret" }, 9 }
    end, { "copie déclarée « fo-lvl-laser-5-beam »", "« localised_name »" }, "ctx.declare : nom affiché changé après declare (nombre en paramètre, F43)" },
  { LZ, fake_laser, function(p, ctx)
      local saved
      ctx.declare("beam", "laser-beam", "beam", function(b) saved = b end)
      saved.body = { sprite(8) }
      saved.head = nil
    end, true, "ctx.declare : visuel de la copie changé après edit" },
}

for _, gc in ipairs(GUARD_CASES) do run_case(gc[1], gc[2], gc[3], gc[4], gc[5]) end
for _, gc in ipairs(DECLARE_CASES) do run_case(gc[1], gc[2], gc[3], gc[4], gc[5]) end

-- Correction INT-GARDE (E67) : durées = 1 / vitesse, lues sur l'instantané de jeu (images ignorées).
do
  local d = Common.game_snapshot(fake_gun()).durations
  check(d.preparing_animation == "12.500000" and d.folding_animation == "12.500000" and d.attacking_animation == "2.000000"
    and d.starting_attack_animation == "sans animation" and d.ending_attack_animation == "sans animation",
    "durées de jeu de la tourelle simulée : levée 12,5, repli 12,5, tir 2 ticks (1 / vitesse ; 8, 8 et 2 images ignorées)")
  local one = fake_gun()
  local s = sprite(1); s.repeat_count = 5
  one.preparing_animation = { layers = { s } }
  one.folding_animation = { north = { layers = { sprite(1) } } }
  local d1 = Common.game_snapshot(one).durations
  check(d1.preparing_animation == d.preparing_animation and d1.folding_animation == d.folding_animation,
    "durées : 1 image × 5 et 1 image en 4 orientations donnent la même durée que 8 images (vitesse inchangée)")
  local slow = fake_gun()
  slow.preparing_speed = 0.016
  check(Common.game_snapshot(slow).durations.preparing_animation == "62.500000",
    "durée : preparing_speed 0,016 → 62,5 ticks (E67 : levée en 63 ticks en moteur réel)")
end

-- Mutants de la garde des durées (INT-GARDE) : copies de common.lua où la règle est remise à l'ancienne, en tout
-- ou en partie, chargées à côté du module (rien n'est écrit sur le disque). Chaque mutant rejoue TOUS les cas de
-- garde (GUARD_CASES, DECLARE_CASES) ; il est DÉTECTÉ si au moins un cas change d'issue ou de motif. Le témoin
-- (copie sans mutation) ne doit en changer aucun : la copie chargée à côté est bien équivalente au module.
do
  local saved_data_mut = _G.data
  local fh = assert(io.open("prototypes/levels/common.lua", "rb"))
  local SRC_COMMON = fh:read("*a")
  fh:close()
  local GT_NEW = "return (GRAPHIC_KEYS[k] or has_visual_word(k) or (extra ~= nil and extra[k])) and true or false"
  local GT_OLD = "return (GRAPHIC_KEYS[k] or ({ preparing_speed = true, folding_speed = true, attacking_speed = true, "
    .. "starting_attack_speed = true, ending_attack_speed = true })[k] or has_visual_word(k) or (extra ~= nil and extra[k])) "
    .. "and true or false"
  -- L'ancienne règle « images / vitesse » (main da2e16f, avant INT-GARDE : common.lua:509-532), code recopié mot
  -- pour mot, sans ses commentaires.
  local DUR_OLD = [=[local function frames(a)
  if type(a) ~= "table" then return nil end
  if type(a.layers) == "table" then
    local m
    for _, l in ipairs(a.layers) do
      local f = frames(l)
      if f and (not m or f > m) then m = f end
    end
    return m
  end
  if a.north then return frames(a.north) end
  if a.filename or a.filenames or a.stripes then return (a.frame_count or 1) * (a.repeat_count or 1) end
  return nil
end
local function durations(p)
  local d = {}
  for _, t in ipairs(TIMED_ANIMATIONS) do
    local f = frames(p[t[1]])
    if f then d[t[1]] = string.format("%.6f", f / (p[t[2]] or 1)) end
  end
  return d
end
]=]
  --- Remplace l'unique occurrence littérale de `old` ; nil si elle n'y est pas exactement une fois.
  local function replace_once(src, old, new)
    local i, j = src:find(old, 1, true)
    if not i or src:find(old, j + 1, true) then return nil end
    return src:sub(1, i - 1) .. new .. src:sub(j + 1)
  end
  --- Remplace la fonction locale `durations` (de sa ligne de tête à son « end » de colonne 1).
  local function replace_durations(src, new)
    local i = src:find("local function durations(p)\n", 1, true)
    if not i or src:find("local function durations(p)\n", i + 1, true) then return nil end
    local _, j = src:find("\nend\n", i, true)
    if not j then return nil end
    return src:sub(1, i - 1) .. new .. src:sub(j + 1)
  end
  local function judge(C, fam, make, fn, expect)
    _G.data = { raw = make_raw() }
    local okg, err = pcall(C.dress, { dress = fn }, make(), fam, 5)
    local good = okg == (expect == true)
    if good and expect ~= true then
      for _, motif in ipairs(expect) do
        if not tostring(err):find(motif, 1, true) then good = false end
      end
    end
    restore_shared()
    return good
  end
  local ALL = {}
  for _, gc in ipairs(GUARD_CASES) do ALL[#ALL + 1] = gc end
  for _, gc in ipairs(DECLARE_CASES) do ALL[#ALL + 1] = gc end
  local MUTANTS = {
    { "témoin (copie sans mutation)", function(s) return s end, false },
    { "M1 ancienne règle entière (vitesses graphiques, durée images / vitesse)",
      function(s) s = replace_once(s, GT_NEW, GT_OLD); return s and replace_durations(s, DUR_OLD) end, true },
    { "M2 vitesses graphiques, durée 1 / vitesse", function(s) return replace_once(s, GT_NEW, GT_OLD) end, true },
    { "M3 vitesses de jeu, durée images / vitesse", function(s) return replace_durations(s, DUR_OLD) end, true },
  }
  for _, m in ipairs(MUTANTS) do
    local src = m[2](SRC_COMMON)
    local chunk = src and load(src, "=common.lua (" .. m[1] .. ")", "t")
    if not chunk then
      check(false, "mutant de la garde des durées : « " .. m[1] .. " » non construit (ancre absente de common.lua ?)")
    else
      local MC = chunk()
      local changed, firsts = 0, {}
      for _, gc in ipairs(ALL) do
        if not judge(MC, gc[1], gc[2], gc[3], gc[4]) then
          changed = changed + 1
          if #firsts < 8 then firsts[#firsts + 1] = gc[5] end
        end
      end
      print(string.format("  Garde des durées (INT-GARDE), %s : %d cas de garde sur %d changent d'issue ou de motif%s", m[1], changed,
        #ALL, #firsts > 0 and (" (dont : " .. table.concat(firsts, " ; ") .. ")") or ""))
      if m[3] then
        check(changed >= 1, string.format("garde des durées : mutant « %s » DÉTECTÉ : %d cas sur %d changent (%s)",
          m[1], changed, #ALL, table.concat(firsts, " ; ")))
      else
        check(changed == 0, string.format("garde des durées : %s : 0 cas sur %d changent (obtenu %d : %s)",
          m[1], #ALL, changed, table.concat(firsts, " ; ")))
      end
    end
  end
  _G.data = saved_data_mut
end

-- Correction V2c (sonde probe_x de la vérification) : un dress qui modifiait le scénario X0, lu par la config,
-- était ACCEPTÉ, et automation passait de 1 à 30 unités (X.VANILLA_UNIT_SCALE lu à l'appel en data-final-fixes).
-- Désormais (1) la config recopie au chargement tout ce qu'elle lit dans X : une modification de X n'a AUCUN
-- effet sur elle ; (2) la garde compare X à la fermeture de la famille et refuse, motif vérifié.
do
  local X0 = require("shared.content.epochs")
  local X_REC = record({ X0 })
  local function restore_x()
    for _, e in ipairs(X_REC) do
      for k in pairs(e.t) do if e.kv[k] == nil then e.t[k] = nil end end
      for k, v in pairs(e.kv) do e.t[k] = v end
    end
  end
  local AUTOMATION = { name = "automation", effects = { { type = "unlock-recipe", recipe = "assembling-machine-1" },
    { type = "unlock-recipe", recipe = "long-handed-inserter" } }, unit = { ingredients = { { "automation-science-pack", 1 } } } }
  local before_units = L.vanilla_unit_count(AUTOMATION, 10)
  run_case(G, fake_gun, function() require("shared.content.epochs").VANILLA_UNIT_SCALE[3] = 3 end,
    { "gun.lua (niveau 5", "a modifié le scénario X0 X.VANILLA_UNIT_SCALE[3]", "valeur modifiée", RO },
    "scénario X0 par require (X.VANILLA_UNIT_SCALE[3] = 3 : sonde probe_x, V2c)")
  check(X0.VANILLA_UNIT_SCALE[3] == 3 and before_units == 1 and L.vanilla_unit_count(AUTOMATION, 10) == 1
    and L.VANILLA_UNIT_SCALE[3] == 0.07,
    "X modifié : la config n'en dépend plus (automation reste à 1 unité, L.VANILLA_UNIT_SCALE[3] = 0,07)")
  restore_x()
  run_case(G, fake_gun, function() require("shared.content.epochs").epoch_hours = function() return 99 end end,
    { "a modifié le scénario X0 X.epoch_hours", RO }, "scénario X0 : fonction du calendrier remplacée (V2c)")
  check(L.target.epoch_hours(15) == 7 and L.target.budget(15) == L.target.budget_mu[15],
    "X.epoch_hours remplacée : le calendrier de la config reste celui recopié au chargement (époque 15 : 7 h)")
  restore_x()
  check(X0.VANILLA_UNIT_SCALE[3] == 0.07 and X0.epoch_hours(15) == 7, "scénario X0 restauré après les cas de garde")
end

-- Sonde EXHAUSTIVE de la config : pour CHAQUE clé de L (triées), un dress modifie sa première feuille
-- (nombre + 1, chaîne + "x", booléen inversé, fonction remplacée ; table vide : clé ajoutée). Tous refusés,
-- avec le chemin. families et by_key partagent les mêmes tables : le chemin signalé est le premier dans l'ordre
-- trié (by_key).
local function first_leaf(t, path, seen)
  seen = seen or {}
  if seen[t] then return nil end
  seen[t] = true
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    if type(a) ~= type(b) then return type(a) < type(b) end
    return a < b
  end)
  for _, k in ipairs(keys) do
    local v = t[k]
    if type(v) == "table" then
      local pt, pk = first_leaf(v, path, seen)
      if pt then table.insert(path, 1, k); return pt, pk end
    else
      path[1] = k
      return t, k
    end
  end
  return nil
end
local L_KEYS = {}
for k in pairs(L) do L_KEYS[#L_KEYS + 1] = k end
table.sort(L_KEYS)
local probes_refused = 0
for _, key in ipairs(L_KEYS) do
  local fn = function(p, ctx)
    local CL = ctx.L
    local v = CL[key]
    local holder, leaf = CL, key
    if type(v) == "table" then holder, leaf = first_leaf(v, {}) end
    if holder == nil then
      v.SONDE = true
    else
      local x = holder[leaf]
      if type(x) == "number" then holder[leaf] = x + 1
      elseif type(x) == "string" then holder[leaf] = x .. "x"
      elseif type(x) == "boolean" then holder[leaf] = not x
      else holder[leaf] = function() end end
    end
  end
  _G.data = { raw = make_raw() }
  local okp, err = pcall(Common.dress, { dress = fn }, fake_gun(), G, 5)
  local want = (key == "families") and "L.by_key." or ("L." .. key)
  local good = not okp and tostring(err):find(SHARED_MOTIF, 1, true) ~= nil and tostring(err):find(want, 1, true) ~= nil
  if good then probes_refused = probes_refused + 1 end
  check(good, "garde : sonde de la config L." .. key .. " (" .. type(L[key]) .. ") → refusée, chemin « " .. want .. " »"
    .. (good and "" or (" (obtenu : " .. tostring(err) .. ")")))
  restore_shared()
end
print(string.format("  Sondes de la config : %d clés de L, %d refusées avec leur chemin", #L_KEYS, probes_refused))

-- Garde d'une FAMILLE (generate) : une référence gardée par dress modifie un niveau déjà vérifié → refus à la
-- fermeture ; un prototype déclaré est rendu par guard_end (à ajouter à data.raw).
_G.data = { raw = make_raw() }
local kept
local okf, errf = pcall(function()
  local g = Common.guard_begin(G)
  Common.dress({ dress = function(p) kept = p end }, fake_gun(), G, 5, g)
  Common.dress({ dress = function() kept.max_health = 1 end }, fake_gun(), G, 6, g)
  Common.guard_end(g)
end)
check(not okf and tostring(errf):find("un appel ultérieur", 1, true) and tostring(errf):find("« max_health »", 1, true)
  and tostring(errf):find("gun.lua (niveau 5)", 1, true),
  "garde de famille : niveau 5 modifié par le dress du niveau 6 → refusé à la fermeture (" .. tostring(errf) .. ")")
refused_n = refused_n + 1
restore_shared()
_G.data = { raw = make_raw() }
local declared
local okd, errd = pcall(function()
  local g = Common.guard_begin(LZ)
  Common.dress({ dress = declare_beam("beam", function(b) b.body = { sprite(4) } end) }, fake_laser(), LZ, 9, g)
  declared = Common.guard_end(g)
end)
local d1 = declared and declared[1]
check(okd and #declared == 1 and d1.name == "fo-lvl-laser-9-beam" and d1.type == "beam" and d1.damage_interval == 20
  and d1.action.action_delivery.target_effects[1].damage.amount == 10 and d1.body[1].frame_count == 4
  and d1.localised_name[1] == "fo-epochs.visual" and data.raw.beam["fo-lvl-laser-9-beam"] == nil
  and data.raw.beam["laser-beam"].body[1].frame_count == 1,
  "ctx.declare : copie rendue par guard_end (nom, dégâts de la source, visuel modifié, source intacte) (" .. tostring(errd) .. ")")
accepted_n = accepted_n + 1
restore_shared()

-- Contre-vérification V2b : cas qui traversent plusieurs appels (comme generate : dress, icons_check par niveau,
-- guard_end par famille, final_check après la dernière famille). Chaque cas repart d'un data.raw simulé neuf.
local function family_case(label, fn, expect)
  _G.data = { raw = make_raw() }
  local okc, err = pcall(fn)
  verify(okc, err, expect, label)
end
local NOOP = { dress = function() end }
local function fake_wall() return { type = "wall", name = "fo-lvl-wall-5", max_health = 700 } end
local W_FAM = L.by_key.wall

-- Sonde p20 : icons modifiait l'état partagé et le refus accusait le dress du niveau SUIVANT. Désormais au nom
-- de l'icons du niveau.
family_case("icons modifie l'état partagé → refus au nom de CET icons (p20)", function()
  local g = Common.guard_begin(G)
  local vis = { dress = function() end, icons = function(icons, ctx) ctx.L.CC_HEALTH = 1; return icons end }
  local ctx = Common.dress(vis, fake_gun(), G, 9, g)
  vis.icons({}, ctx)
  Common.icons_check(g, G, 9)
  Common.dress(NOOP, fake_gun(), G, 10, g)
end, { "gun.lua (niveau 9) : icons a modifié l'état partagé L.CC_HEALTH", "lecture seule" })
family_case("icons modifie le prototype du niveau (référence gardée par dress) → refus au nom de l'icons", function()
  local g, kept_p = Common.guard_begin(G), nil
  local vis = { dress = function(p) kept_p = p end, icons = function(icons) kept_p.prepare_range = 40; return icons end }
  local ctx = Common.dress(vis, fake_gun(), G, 9, g)
  vis.icons({}, ctx)
  Common.icons_check(g, G, 9)
end, { "gun.lua (niveau 9) : icons a modifié le champ de jeu « prepare_range »" })
family_case("icons modifie la copie déclarée de son niveau → refus au nom de l'icons", function()
  local g, kept_b = Common.guard_begin(LZ), nil
  local vis = { dress = function(p, ctx) ctx.declare("beam", "laser-beam", "beam", function(b) kept_b = b end) end,
    icons = function(icons) kept_b.width = 3; return icons end }
  local ctx = Common.dress(vis, fake_laser(), LZ, 9, g)
  vis.icons({}, ctx)
  Common.icons_check(g, LZ, 9)
end, { "laser.lua (niveau 9) : icons a modifié la copie déclarée « fo-lvl-laser-9-beam »", "« width »" })
family_case("copie déclarée au niveau 9 modifiée par le dress du niveau 10 → refus à la fermeture de la famille", function()
  local g, kept_b = Common.guard_begin(LZ), nil
  Common.dress({ dress = function(p, ctx) ctx.declare("beam", "laser-beam", "beam", function(b) kept_b = b end) end }, fake_laser(), LZ, 9, g)
  Common.icons_check(g, LZ, 9)
  Common.dress({ dress = function() kept_b.damage_interval = 1 end }, fake_laser(), LZ, 10, g)
  Common.icons_check(g, LZ, 10)
  Common.guard_end(g)
end, { "laser.lua (niveau 9) : un appel ultérieur (dress ou icons) a modifié la copie déclarée « fo-lvl-laser-9-beam »",
  "« damage_interval »" })

-- Sonde p23 : une famille SUIVANTE modifiait un niveau d'une famille déjà fermée (mitrailleuse 30 livrée à 1 PV).
-- guard_end de la famille suivante ne le voit pas (elle ne compare que ses niveaux) : final_check, si.
local closed_ok = false
family_case("famille suivante (laser) modifie un niveau de la mitrailleuse déjà fermée → refus par final_check (p23)", function()
  local kept_gun
  local gG = Common.guard_begin(G)
  Common.dress({ dress = function(p) kept_gun = p end }, fake_gun(), G, 30, gG)
  Common.icons_check(gG, G, 30)
  Common.guard_end(gG)
  local gL = Common.guard_begin(LZ)
  Common.dress({ dress = function() kept_gun.max_health = 1; kept_gun.attack_parameters.cooldown = 1 end }, fake_laser(), LZ, 9, gL)
  Common.icons_check(gL, LZ, 9)
  Common.guard_end(gL)
  closed_ok = true
  Common.final_check({ gG, gL })
end, { "gun.lua (niveau 30) : un appel d'une famille générée après (laser.lua", "« attack_parameters.cooldown »" })
check(closed_ok, "garde : p23, la fermeture de la famille suivante seule ne voit pas l'écart (d'où final_check)")
family_case("famille suivante (mur) modifie la copie déclarée d'un laser → refus par final_check", function()
  local kept_b
  local gL = Common.guard_begin(LZ)
  Common.dress({ dress = function(p, ctx) ctx.declare("beam", "laser-beam", "beam", function(b) kept_b = b end) end }, fake_laser(), LZ, 9, gL)
  Common.icons_check(gL, LZ, 9)
  Common.guard_end(gL)
  local gW = Common.guard_begin(W_FAM)
  Common.dress({ dress = function() kept_b.action = nil end }, fake_wall(), W_FAM, 5, gW)
  Common.icons_check(gW, W_FAM, 5)
  Common.guard_end(gW)
  Common.final_check({ gL, gW })
end, { "laser.lua (niveau 9) : un appel d'une famille générée après (wall.lua", "copie déclarée « fo-lvl-laser-9-beam »", "« action »" })
family_case("trois familles sans écart (copie déclarée comprise) → final_check accepte", function()
  local gG, gL, gW = Common.guard_begin(G), nil, nil
  Common.dress(NOOP, fake_gun(), G, 30, gG)
  Common.icons_check(gG, G, 30)
  Common.guard_end(gG)
  gL = Common.guard_begin(LZ)
  Common.dress({ dress = declare_beam("beam", function(b) b.body = { sprite(4) } end) }, fake_laser(), LZ, 9, gL)
  Common.icons_check(gL, LZ, 9)
  Common.guard_end(gL)
  gW = Common.guard_begin(W_FAM)
  Common.dress(NOOP, fake_wall(), W_FAM, 5, gW)
  Common.icons_check(gW, W_FAM, 5)
  Common.guard_end(gW)
  Common.final_check({ gG, gL, gW })
end, true)

-- Sonde p22 : remplacer Common.dress depuis un fichier de famille neutralisait la garde de generate. generate
-- appelle désormais des LOCALES ; ici : les champs exportés ne sont que des alias (la preuve en étape data
-- réelle est la sonde p22 du harness, BALANCE_SHEET §12).
check(type(Common.dress) == "function" and type(Common.final_check) == "function" and type(Common.icons_check) == "function",
  "garde : fonctions de garde exportées pour les tests (dress, icons_check, guard_end, final_check)")
print(string.format("  Garde : %d cas d'agent V3 (%d acceptés, %d refusés, motif vérifié pour chaque refus) + %d sondes de la config",
  accepted_n + refused_n, accepted_n, refused_n, #L_KEYS))
table.deepcopy, _G.data = saved_deepcopy, saved_data

---------------------------------------------------------------------------------------------------
section("Améliorations instantanées en moteur simulé (Q19)")
---------------------------------------------------------------------------------------------------
local M = require("tests.mock_engine")
M.new_game({})
local Wd = M.world()
-- Prototypes des niveaux (le moteur simulé ne lit pas l'étape data).
for _, f in ipairs(L.families) do
  for n = 1, f.max do
    local proto = {
      type = f.type, max_health = stat_at(f, "max_health", n),
      selection_box = { left_top = { x = -f.size / 2, y = -f.size / 2 }, right_bottom = { x = f.size / 2, y = f.size / 2 } },
    }
    if f.key == "command" then
      local size = stat_at(f, "inventory_size", n)
      proto.get_inventory_size = function() return size end
    end
    rawset(Wd.prototypes, L.name(f, n), proto)
  end
end
local s = game.surfaces[1]
-- Décors retirés sous un bâtiment agrandi : surface.destroy_decoratives du moteur simulé (tests/mock_engine.lua,
-- suite d'intégration de V3-T ; la doublure locale posée ici par le lot V3-T est retirée).
local ev = Wd.events
local function built(e) ev[defines.events.on_built_entity]({ created_entity = e, player_index = 1, tick = game.tick }) end
local Levels = require("script.levels.levels")
local force = game.forces.player
--- Stocke `times` fois le coût du niveau n ; renvoie true si TOUT est entré (coffre borné ci-dessous).
local function stock(inv, family, n, times)
  local all = true
  for _, c in ipairs(L.cost(family, n)) do
    local want = c[2] * (times or 1)
    if inv.insert({ name = c[1], count = want }) < want then all = false end
  end
  return all
end

-- Le moteur simulé a des inventaires sans limite. Correction V2 : le coffre d'un centre est borné à ses
-- vraies cases (L.chest_slots du niveau du centre de la force), avec les vraies piles (L.stack_size), comme
-- le moteur réel : un coût qui ne tient pas dans le coffre n'est plus validé par erreur. C'est une
-- ENVELOPPE du moteur simulé : dans le moteur réel, le coffre est borné par nature ; le banc content (E32) y
-- a vérifié les piles du jeu et la règle de place à chaque niveau.
local TEST_STACK = { ["nuclear-fuel"] = 1, ["firearm-magazine"] = 200, ["uranium-rounds-magazine"] = 200 }
local function stack_of(item) return L.stack_size[item] or TEST_STACK[item] or 50 end
local function limit_chest(centre)
  local inv = centre.get_inventory(defines.inventory.chest)
  if rawget(inv, "_limited") then return inv end
  local force_of_centre = centre.force
  local raw_insert = inv.insert
  inv._limited = true
  inv.insert = function(items)
    local cap = L.chest_slots(math.max(1, Levels.cc_level(force_of_centre)))
    local used = 0
    for item, count in pairs(inv._items) do used = used + math.ceil(count / stack_of(item)) end
    local st, have = stack_of(items.name), inv._items[items.name] or 0
    local room = (math.ceil(have / st) + math.max(0, cap - used)) * st - have
    local n = math.min(math.floor(items.count), room)
    if n <= 0 then return 0 end
    return raw_insert({ name = items.name, count = n })
  end
  return inv
end
-- Correction V2b (contre-vérification V2) : la limite est rebranchée sur chaque centre remplacé par le crochet
-- Levels.on_replaced (enregistré ici, hors événement, et de nouveau après le rechargement plus bas).
local function limit_replaced_centre(_, new)
  if new and new.valid and L.parse(new.name) == L.by_key.command then limit_chest(new) end
end
table.insert(Levels.on_replaced, limit_replaced_centre)
--- Le coffre du centre est-il borné à ses cases ? Y verse (cases libres + 10) combustibles nucléaires (pile
--- de 1) : seules les cases libres doivent entrer. Le coffre est rendu dans son état.
local function chest_bounded(centre)
  local inv = centre.get_inventory(defines.inventory.chest)
  local cap = L.chest_slots(Levels.cc_level(centre.force))
  local used = 0
  for item, count in pairs(inv._items) do used = used + math.ceil(count / stack_of(item)) end
  local free = cap - used
  local got = inv.insert({ name = "nuclear-fuel", count = free + 10 })
  if got > 0 then inv.remove({ name = "nuclear-fuel", count = got }) end
  return got == free, got, free, cap
end
local function no_job()
  return next(global.fo.levels.jobs) == nil
end

local cc = s.create_entity({ name = "fo-command-center", position = { x = 0.5, y = 0.5 }, force = "player" })
built(cc)
limit_chest(cc)
check(cc.get_inventory(defines.inventory.chest).insert({ name = "nuclear-fuel", count = 60 }) == 48
  and cc.get_inventory(defines.inventory.chest).remove({ name = "nuclear-fuel", count = 60 }) == 48,
  "moteur simulé : coffre du centre 1 borné à 48 cases (48 combustibles nucléaires sur 60)")
check(Levels.cc_level(force) == 1, "centre de commandement niveau 1 enregistré")
local cc2 = s.create_entity({ name = "fo-command-center", position = { x = 20.5, y = 0.5 }, force = "player" })
built(cc2)
check(not cc2.valid and Levels.cc(force) == cc, "un seul centre par force (le second est rendu)")

local gun = s.create_entity({ name = "gun-turret", position = { x = 10, y = 10 }, force = "player" })
gun.insert({ name = "firearm-magazine", count = 25 })
gun.health = 200
local r_ok, r_why, r_info, r_new = Levels.start(gun, nil)
check(not r_ok and r_why == "no-resources", "refus faute de ressources")
local chest = cc.get_inventory(defines.inventory.chest)
stock(chest, G, 2, 2)
r_ok, r_why, r_info, r_new = Levels.start(gun, nil)
check(r_ok and r_why == "done", "Q19 : amélioration faite AUSSITÔT, payée par le centre (avant : chantier minuté « started »)")
local g2 = s.find_entity("fo-lvl-gun-2", { x = 10, y = 10 })
check(not gun.valid and g2 ~= nil and r_new == g2, "Q19 : tourelle remplacée par le niveau 2 dans le même appel, au même endroit")
check(g2 and g2.active ~= false, "Q19 : jamais hors service")
check(g2 and g2.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine") == 25, "munitions conservées")
check(g2 and math.abs(g2.get_health_ratio() - 0.5) < 1e-6, "santé conservée en proportion (50 %)")
check(chest.get_item_count("iron-plate") == L.cost(G, 2)[1][2], "coût prélevé une fois dans le centre")
check(no_job() and Levels.busy(force) == 0, "aucun chantier enregistré, aucun ouvrier occupé")
check((Wd.lights or 0) >= 1 and (Wd.flying or 0) >= 1, "célébration (lumière, texte)")
-- Plus de limite d'ouvriers : 6 tourelles améliorées dans le même tick avec un centre niveau 1 (ancienne
-- règle : 1 ouvrier, le 2e chantier était refusé « no-builder »).
local six = {}
for i = 1, 6 do six[i] = s.create_entity({ name = "gun-turret", position = { x = 10 + 4 * i, y = 14 }, force = "player" }) end
stock(chest, G, 2, 6)
local done6 = 0
for i = 1, 6 do if Levels.start(six[i], nil) then done6 = done6 + 1 end end
check(done6 == 6, "Q19 : 6 améliorations dans le même tick avec un centre 1 (plus de limite d'ouvriers) (" .. done6 .. ")")
check(global.fo.levels.stats.upgrades == 7, "statistiques : 7 améliorations comptées (" .. tostring(global.fo.levels.stats.upgrades) .. ")")

-- Plafond : niveau 3 (époque 2) interdit avec un centre niveau 1, autorisé après l'amélioration du centre.
stock(chest, G, 3, 1)
r_ok, r_why = Levels.start(g2, nil)
check(not r_ok and r_why == "cc-too-low", "tourelle niveau 3 refusée : centre niveau 1 (plafond 2)")
local info = Levels.preview(g2, nil)
check(info and info.required_cc == 2, "aperçu : centre niveau 2 requis")
-- Q16 : un mur (niveau 1) posé, les murs sont une famille POSSÉDÉE sans bâtiment au niveau 2 : le centre est
-- bloqué, rien n'est payé.
local lone_wall = s.create_entity({ name = "stone-wall", position = { x = 60.5, y = 0.5 }, force = "player" })
stock(chest, L.by_key.command, 2, 1)
local iron_before = chest.get_item_count("iron-plate")
r_ok, r_why, r_info = Levels.start(cc, nil)
check(not r_ok and r_why == "cc-families" and r_info and r_info.condition_level == 2 and #r_info.blocking == 1
  and r_info.blocking[1] == "wall", "Q16 : centre 1 → 2 refusé, les murs bloquent (niveau visé 2) (" .. tostring(r_why) .. ")")
check(chest.get_item_count("iron-plate") == iron_before and Levels.cc_level(force) == 1, "Q16 : refus sans paiement, centre inchangé")
stock(chest, L.by_key.wall, 2, 1)
check(Levels.start(lone_wall, nil), "Q16 : le mur passe au niveau 2")
r_ok, r_why = Levels.start(cc, nil)
check(r_ok and r_why == "done", "Q16 remplie (mitrailleuses et mur au niveau 2) : centre amélioré aussitôt (" .. tostring(r_why) .. ")")
check(Levels.cc_level(force) == 2 and Levels.cc(force).name == "fo-lvl-command-2", "centre niveau 2 (toujours enregistré après remplacement)")
local bounded, got_fuel, free_slots, cap_slots = chest_bounded(Levels.cc(force))
check(bounded and cap_slots == 64, string.format("coffre du centre 2 REMPLACÉ borné à ses %d cases : %d combustibles nucléaires entrés pour %d cases libres",
  cap_slots, got_fuel, free_slots))
check(Levels.cc(force).get_inventory(defines.inventory.chest).get_item_count("iron-plate") > 0, "le stock du centre a suivi le remplacement")
r_ok, r_why = Levels.start(g2, nil)
check(r_ok and r_why == "done" and s.find_entity(L.name(G, 3), { x = 10, y = 10 }) ~= nil, "tourelle niveau 3 avec un centre niveau 2")

-- Murs : rangée entière, d'un coup.
local walls = {}
for i = 0, 5 do
  walls[#walls + 1] = s.create_entity({ name = "stone-wall", position = { x = 30 + i, y = 5 }, force = "player" })
end
local cinv = Levels.cc(force).get_inventory(defines.inventory.chest)
stock(cinv, L.by_key.wall, 2, 6)
local done = Levels.start_row(walls[3], nil)
check(done == 6, "rangée de 6 murs améliorée d'un coup (" .. tostring(done) .. ")")
check(s.find_entity("fo-lvl-wall-2", { x = 30, y = 5 }) ~= nil and s.find_entity("stone-wall", { x = 35, y = 5 }) == nil, "murs niveau 2 posés")

-- Rangée MIXTE (vérification V2c, mutant M19) : des murs d'une autre force collés à la rangée ne sont pas
-- améliorés, même quand cette force a un centre approvisionné (sinon le joueur ferait dépenser une autre force).
do
  game.create_force("fo-row-rival")
  local rcc = s.create_entity({ name = "fo-command-center", position = { x = 60.5, y = 40.5 }, force = "fo-row-rival" })
  built(rcc)
  local rinv_row = rcc.get_inventory(defines.inventory.chest)
  stock(rinv_row, L.by_key.wall, 2, 4)
  local rival_bricks = rinv_row.get_item_count("stone-brick")
  local mixed = {}
  for i = 0, 3 do
    mixed[#mixed + 1] = s.create_entity({ name = "stone-wall", position = { x = 30 + i, y = 7 }, force = i < 2 and "player" or "fo-row-rival" })
  end
  stock(cinv, L.by_key.wall, 2, 4)
  local bricks_before = cinv.get_item_count("stone-brick")
  local done_m = Levels.start_row(mixed[1], nil)
  check(done_m == 2 and s.find_entity("fo-lvl-wall-2", { x = 31, y = 7 }) ~= nil and s.find_entity("stone-wall", { x = 32, y = 7 }) ~= nil
    and s.find_entity("stone-wall", { x = 33, y = 7 }) ~= nil,
    "rangée mixte : seuls les 2 murs de la force du mur visé sont améliorés (" .. tostring(done_m) .. ")")
  check(bricks_before - cinv.get_item_count("stone-brick") == 2 * L.cost(L.by_key.wall, 2)[1][2]
    and rinv_row.get_item_count("stone-brick") == rival_bricks,
    "rangée mixte : le centre paie 2 murs ; le centre approvisionné de l'autre force n'est pas touché")
end

-- Paiement : centre de commandement D'ABORD, puis inventaire du joueur (vérification V2c, mutant M10). Le centre
-- tient la moitié du coût, le joueur le reste et 5 de plus de chaque objet.
do
  local pg = s.create_entity({ name = "gun-turret", position = { x = 40, y = 14 }, force = "player" })
  local pinv = Wd.player.get_main_inventory()
  local cost = L.cost(G, 2)
  for _, c in ipairs(cost) do
    local have = cinv.get_item_count(c[1])
    if have > 0 then cinv.remove({ name = c[1], count = have }) end
    local p_have = pinv.get_item_count(c[1])
    if p_have > 0 then pinv.remove({ name = c[1], count = p_have }) end
    cinv.insert({ name = c[1], count = math.floor(c[2] / 2) })
  end
  -- Refus « no-resources » (le joueur n'a rien) : personne n'est débité.
  local ok_m, why_m = Levels.start(pg, Wd.player)
  local untouched = true
  for _, c in ipairs(cost) do
    if cinv.get_item_count(c[1]) ~= math.floor(c[2] / 2) or pinv.get_item_count(c[1]) ~= 0 then untouched = false end
  end
  check(not ok_m and why_m == "no-resources" and untouched and pg.valid, "paiement mixte : refus « no-resources » sans débiter ni le centre ni le joueur")
  for _, c in ipairs(cost) do pinv.insert({ name = c[1], count = c[2] - math.floor(c[2] / 2) + 5 }) end
  ok_m, why_m = Levels.start(pg, Wd.player)
  local centre_empty, player_rest = true, true
  for _, c in ipairs(cost) do
    if cinv.get_item_count(c[1]) ~= 0 then centre_empty = false end
    if pinv.get_item_count(c[1]) ~= 5 then player_rest = false end
  end
  check(ok_m and why_m == "done" and s.find_entity(L.name(G, 2), { x = 40, y = 14 }) ~= nil,
    "paiement mixte : amélioration faite (centre + joueur) (" .. tostring(why_m) .. ")")
  check(centre_empty and player_rest, "paiement mixte : le centre est vidé D'ABORD, le joueur ne paie que le complément (il garde 5 de chaque)")
end

---------------------------------------------------------------------------------------------------
section("Hautes époques : plafond, niveau 30, centre 15, condition du centre")
---------------------------------------------------------------------------------------------------
local function new_force_with_cc(name, cc_level, x)
  game.create_force(name)
  local c = s.create_entity({ name = L.name(L.by_key.command, cc_level), position = { x = x, y = 200.5 }, force = name })
  built(c)
  limit_chest(c)
  return game.forces[name], c
end
-- Centre 4 : 3 machines 7 → 8 dans le même tick (ancienne règle : 2 ouvriers, la 3e attendait).
local f4, c4 = new_force_with_cc("fo-test-4", 4, 0.5)
check(Levels.cc_level(f4) == 4, "centre niveau 4 posé directement (époque 4)")
local inv4 = c4.get_inventory(defines.inventory.chest)
local machines = {}
for i = 1, 3 do
  machines[i] = s.create_entity({ name = L.name(L.by_key.assembler, 7), position = { x = 10 * i, y = 220 }, force = "fo-test-4" })
end
stock(inv4, L.by_key.assembler, 8, 3)
local up3 = 0
for i = 1, 3 do if Levels.start(machines[i], nil) then up3 = up3 + 1 end end
check(up3 == 3 and s.find_entity(L.name(L.by_key.assembler, 8), { x = 30, y = 220 }) ~= nil,
  "centre 4 : 3 machines niveau 8 livrées dans le même tick (" .. up3 .. ")")
local am9 = s.create_entity({ name = L.name(L.by_key.assembler, 8), position = { x = 60, y = 220 }, force = "fo-test-4" })
info = Levels.preview(am9, nil)
check(info and not info.ok and info.reason == "cc-too-low" and info.required_cc == 5, "centre 4 : niveau 9 refusé (centre 5 requis)")

-- Centre 13 : 6 foreuses 25 → 26 d'un coup.
local f13, c13 = new_force_with_cc("fo-test-13", 13, 40.5)
local inv13 = c13.get_inventory(defines.inventory.chest)
local drills = {}
for i = 1, 6 do
  drills[i] = s.create_entity({ name = L.name(L.by_key.drill, 25), position = { x = 10 * i, y = 240 }, force = "fo-test-13" })
end
check(stock(inv13, L.by_key.drill, 26, 6), "centre 13 : 6 coûts du niveau 26 rangés dans le coffre")
local up6 = 0
for i = 1, 6 do if Levels.start(drills[i], nil) then up6 = up6 + 1 end end
check(up6 == 6 and Levels.busy(f13) == 0, "centre 13 : 6 foreuses niveau 26 d'un coup (" .. up6 .. ")")

-- Centre 14 → 15, condition Q16 (niveau visé 28) ; puis niveau 29 → 30 ; plus rien au-delà.
local f15, c15 = new_force_with_cc("fo-test-15", 14, 80.5)
local inv15 = c15.get_inventory(defines.inventory.chest)
check(inv15.insert({ name = "nuclear-fuel", count = 310 }) == 256 and inv15.remove({ name = "nuclear-fuel", count = 310 }) == 256,
  "enveloppe du moteur simulé (démonstration du coffre borné, pas une propriété de la config) : 310 combustibles nucléaires (pile de 1) versés dans le centre 14, 256 entrent")
local g27 = s.create_entity({ name = L.name(G, 27), position = { x = 90, y = 260 }, force = "fo-test-15" })
g27.insert({ name = "uranium-rounds-magazine", count = 10 })
check(stock(inv15, L.by_key.command, 15, 1), "centre 14 → 15 : tout le coût tient dans le coffre du centre 14 (cases réelles)")
r_ok, r_why, r_info = Levels.start(c15, nil)
check(not r_ok and r_why == "cc-families" and r_info.condition_level == 28 and r_info.blocking[1] == "gun",
  "Q16 : centre 14 → 15 refusé, mitrailleuse au niveau 27 < 28 (" .. tostring(r_why) .. ")")
stock(inv15, G, 28, 1)
local g28_ok, _, _, g28 = Levels.start(g27, nil)
check(g28_ok and g28 and g28.name == L.name(G, 28), "mitrailleuse 27 → 28")
r_ok, r_why = Levels.start(c15, nil)
check(r_ok and r_why == "done" and Levels.cc_level(f15) == 15, "centre niveau 15 (époque Légende), condition remplie (" .. tostring(r_why) .. ")")
bounded, got_fuel, free_slots, cap_slots = chest_bounded(Levels.cc(f15))
check(bounded and cap_slots == 272, string.format("coffre du centre 15 REMPLACÉ borné à ses %d cases : %d combustibles nucléaires entrés pour %d cases libres",
  cap_slots, got_fuel, free_slots))
local top = Levels.cc(f15)
info = Levels.preview(top, nil)
check(info and not info.ok and info.reason == "max", "centre 15 : niveau maximal")
stock(top.get_inventory(defines.inventory.chest), G, 29, 1)
stock(top.get_inventory(defines.inventory.chest), G, 30, 1)
local g29_ok, g29_why, _, g29 = Levels.start(g28, nil)
local g30_ok, g30_why, _, g30
if g29 then g30_ok, g30_why, _, g30 = Levels.start(g29, nil) end
check(g29_ok and g30_ok and g30 and g30.name == L.name(G, 30),
  "mitrailleuse 28 → 29 → 30 d'affilée avec un centre 15 (" .. tostring(g29_why) .. ", " .. tostring(g30_why) .. ")")
check(g30 and g30.get_inventory(defines.inventory.turret_ammo).get_item_count("uranium-rounds-magazine") == 10,
  "mitrailleuse niveau 30, munitions conservées")
info = g30 and Levels.preview(g30, nil)
check(info and not info.ok and info.reason == "max", "mitrailleuse 30 : niveau maximal")
local st = global.fo.levels.stats
check((st.fallback or 0) == 0, "remplacement rapide partout (aucun secours manuel)")

---------------------------------------------------------------------------------------------------
section("Condition du centre (Q16) : recensement des familles, interface distante")
---------------------------------------------------------------------------------------------------
-- Force au centre 3 (niveau visé 6) : mitrailleuse 6 (remplie), tourelle laser 5 (bloque), mur 6 (remplie),
-- foreuse vanilla (niveau 1, bloque), aucun four (non possédé : ne bloque pas), machine 6 (remplie).
do
local fq, cq = new_force_with_cc("fo-test-q16", 3, 120.5)
local qinv = cq.get_inventory(defines.inventory.chest)
local function put(key, n, x)
  return s.create_entity({ name = L.name(L.by_key[key], n), position = { x = x, y = 300 }, force = "fo-test-q16" })
end
put("gun", 6, 100)
local qlaser = put("laser", 5, 104)
put("wall", 6, 108.5)
local qdrill = put("drill", 1, 112)
put("assembler", 6, 118)
local cen = Levels.census(fq, 6)
check(cen.gun.any and cen.gun.top and cen.laser.any and not cen.laser.top and cen.drill.any and not cen.drill.top
  and not cen.furnace.any and cen.assembler.top, "recensement : possédées, au niveau visé ou non, four non possédé")
stock(qinv, L.by_key.command, 4, 1)
local qiron = qinv.get_item_count("iron-plate")
info = Levels.preview(cq, nil)
check(info and not info.ok and info.reason == "cc-families" and info.condition_level == 6 and #info.blocking == 2
  and info.blocking[1] == "laser" and info.blocking[2] == "drill", "aperçu du centre 3 : laser et foreuse bloquent, niveau visé 6")
local rr = remote.call("factorio-overhaul", "levels_upgrade", cq)
check(type(rr) == "table" and rr.ok == false and rr.reason == "cc-families",
  "interface distante : levels_upgrade sur le centre renvoie le motif « cc-families » (" .. tostring(rr and rr.reason) .. ")")
check(qinv.get_item_count("iron-plate") == qiron and Levels.cc_level(fq) == 3, "interface distante : refus sans paiement")
-- Une famille qui n'est plus possédée ne bloque plus : la tourelle laser démontée (destroy sans événement :
-- aperçu en recensement COMPLET, celui des décisions).
qlaser.destroy()
info = Levels.preview(cq, nil, true)
check(info and #info.blocking == 1 and info.blocking[1] == "drill", "laser retiré : seule la foreuse bloque encore")
-- Les bâtiments d'une AUTRE force ne comptent pas.
s.create_entity({ name = L.name(L.by_key.drill, 6), position = { x = 126, y = 300 }, force = "player" })
info = Levels.preview(cq, nil, true)
check(info and #info.blocking == 1 and info.blocking[1] == "drill", "une foreuse 6 d'une autre force ne lève pas la condition")
put("drill", 6, 130)
rr = remote.call("factorio-overhaul", "levels_upgrade", cq)
check(type(rr) == "table" and rr.ok == true and rr.reason == "done" and Levels.cc_level(fq) == 4,
  "foreuse 6 posée : interface distante, centre 3 → 4 fait aussitôt (" .. tostring(rr and rr.reason) .. ")")

-- Recensement EN CACHE (vérification V2c : 12 balayages de surface toutes les 30 ticks par panneau ouvert).
-- Centre 4 (niveau visé 8) : mitrailleuse, mur, foreuse et machine au niveau 6 bloquent.
local stv = global.fo.levels.stats
local c4q = Levels.cc(fq)
local scans0, calls0 = stv.census_scans, Wd.count_calls or 0
info = Levels.preview(c4q, nil)
local scans1, calls1 = stv.census_scans, Wd.count_calls or 0
for _ = 1, 10 do info = Levels.preview(c4q, nil) end
check(scans1 == scans0 + 1 and stv.census_scans == scans1 and (Wd.count_calls or 0) == calls1 and calls1 > calls0,
  string.format("cache : 1 recensement au premier aperçu du centre 4, puis 10 aperçus sans balayer (%d recensement(s), %d appel(s) moteur)",
    stv.census_scans - scans0, (Wd.count_calls or 0) - calls0))
check(info and #info.blocking == 4 and info.blocking[1] == "gun" and info.blocking[4] == "assembler",
  "cache : aperçu du centre 4, 4 familles bloquent (niveau visé 8)")
-- Une construction met le cache à jour EXACTEMENT, sans balayer : mitrailleuse 8 construite.
local qg8 = put("gun", 8, 140)
built(qg8)
info = Levels.preview(c4q, nil)
check(stv.census_scans == scans1 and info and #info.blocking == 3 and info.blocking[1] == "wall",
  "cache : mitrailleuse 8 construite (on_built) : la mitrailleuse ne bloque plus, aucun balayage")
-- Un retrait l'invalide : la mitrailleuse 8 minée, le prochain aperçu recense de nouveau.
ev[defines.events.on_player_mined_entity]({ entity = qg8, player_index = 1, tick = game.tick })
qg8.destroy()
info = Levels.preview(c4q, nil)
check(stv.census_scans == scans1 + 1 and info and #info.blocking == 4, "cache : un bâtiment à niveaux miné invalide le cache (nouveau recensement, 4 familles bloquent)")
-- Filet : le cache expire après Levels.CENSUS_TTL ticks.
local t_saved = game.tick
game.tick = game.tick + Levels.CENSUS_TTL - 1
Levels.preview(c4q, nil)
local before_ttl = stv.census_scans
game.tick = t_saved + Levels.CENSUS_TTL
Levels.preview(c4q, nil)
check(before_ttl == scans1 + 1 and stv.census_scans == scans1 + 2, "cache : valable " .. Levels.CENSUS_TTL .. " ticks, puis recensé de nouveau")
game.tick = t_saved
-- Une DÉCISION ne lit jamais le cache : chaque Levels.start sur le centre recense.
local scans_d = stv.census_scans
Levels.start(c4q, nil)
Levels.start(c4q, nil)
check(stv.census_scans == scans_d + 2, "cache : chaque décision (Levels.start) refait le recensement complet")
end

---------------------------------------------------------------------------------------------------
section("Panneau « Évolution » (moteur simulé)")
---------------------------------------------------------------------------------------------------
-- Interface graphique simulée un peu plus riche que celle du moteur simulé (clear, style).
do
local function fake_gui()
  local c = { _children = {}, _list = {}, style = {} }
  c.add = function(spec)
    local el = fake_gui()
    for k, v in pairs(spec) do el[k] = v end
    el.valid = true
    el.destroy = function() el.valid = false; if spec.name then c._children[spec.name] = nil end end
    if spec.name then c._children[spec.name] = el end
    c._list[#c._list + 1] = el
    return el
  end
  c.clear = function() c._children, c._list = {}, {} end
  return setmetatable(c, { __index = function(t, k) return rawget(t, "_children")[k] end })
end
local player = Wd.player
player.gui = { left = fake_gui(), top = fake_gui() }
local function captions(el, out)
  out = out or {}
  for _, ch in ipairs(rawget(el, "_list")) do
    if ch.caption then out[#out + 1] = M.ls_to_string(ch.caption) end
    captions(ch, out)
  end
  return out
end
local gpanel = s.create_entity({ name = L.name(G, 4), position = { x = 120, y = 10 }, force = "player" })
rawset(player, "selected", gpanel)
local ok_panel, err_panel = pcall(M.dispatch, ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
check(ok_panel, "panneau ouvert au survol sans erreur (" .. tostring(err_panel) .. ")")
local frame = player.gui.left["fo_lvl_panel"]
check(frame ~= nil, "panneau affiché")
local all = frame and table.concat(captions(frame), "\n") or ""
check(all:find("fo%-epochs%.level%-line") ~= nil, "panneau : ligne niveau / époque")
check(all:find("fo%-epochs%.next%-line") ~= nil, "panneau : prochain niveau et son époque")
check(all:find("fo%-epochs%.currency") ~= nil, "panneau : monnaie de l'époque")
check(all:find("fo%-levels%.reason%-cc%-too%-low") ~= nil, "panneau : niveau 5 refusé, centre trop bas")
check(all:find("fo%-levels%.instant") ~= nil and all:find("fo%-levels%.duration") == nil and all:find("fo%-levels%.builders") == nil,
  "panneau : « amélioration instantanée », ni durée ni ouvriers")
ok_panel, err_panel = pcall(M.run_ticks, 60)
check(ok_panel, "panneau rafraîchi pendant le jeu sans erreur (" .. tostring(err_panel) .. ")")
-- Touche U sur une tourelle niveau 2 avec un centre niveau 2 : améliorée aussitôt.
local gu = s.create_entity({ name = L.name(G, 2), position = { x = 124, y = 10 }, force = "player" })
stock(Levels.cc(force).get_inventory(defines.inventory.chest), G, 3, 1)
rawset(player, "selected", gu)
ok_panel, err_panel = pcall(M.dispatch, ev["fo-level-up"], { player_index = 1, tick = game.tick })
check(ok_panel and not gu.valid and s.find_entity(L.name(G, 3), { x = 124, y = 10 }) ~= nil, "touche U : amélioration faite aussitôt (" .. tostring(err_panel) .. ")")
-- Plafond affiché par le panneau du centre : 2 × son niveau (et non le maximum du centre, 15) ; condition Q16.
local function hover(entity)
  rawset(player, "selected", nil)
  rawset(player, "selected", entity)
  local okh = pcall(M.dispatch, ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
  local fr = player.gui.left["fo_lvl_panel"]
  return okh, fr and table.concat(captions(fr), "\n") or ""
end
local okc, txt = hover(Levels.cc(force))
check(okc and txt:find("{fo-epochs.cc-line:2,4}", 1, true) ~= nil, "panneau du centre 2 : bâtiments jusqu'au niveau 4")
-- À ce stade, la force du joueur a une mitrailleuse 4 (survolée plus haut) et une foreuse 6, mais ses murs
-- sont au niveau 2 : les murs bloquent, et eux seuls.
check(okc and txt:find("{fo-epochs.cc-rule:4}", 1, true) ~= nil and txt:find("fo-epochs.cc-rule-missing", 1, true) ~= nil
  and txt:find("[entity=stone-wall]", 1, true) ~= nil and txt:find("[entity=gun-turret]", 1, true) == nil
  and txt:find("{fo-epochs.reason-cc-families:4,", 1, true) ~= nil,
  "panneau du centre 2 : condition (niveau 4) et famille qui bloque nommée (murs ; mitrailleuse et foreuse en règle)")
-- Vérification V2c : le panneau du centre reste ouvert 300 ticks (10 rafraîchissements) sans aucun recensement
-- (cache par force ; avant : 12 balayages de surface à chaque rafraîchissement).
do
  local scans_p = global.fo.levels.stats.census_scans
  local okr, errr = pcall(M.run_ticks, 300)
  check(okr and global.fo.levels.stats.census_scans == scans_p and global.fo.levels_ui.target[1] == Levels.cc(force),
    "panneau du centre ouvert 300 ticks : aucun recensement (" .. (global.fo.levels.stats.census_scans - scans_p) .. ", " .. tostring(errr) .. ")")
end
local f3, c3 = new_force_with_cc("fo-test-3", 3, 160.5)
local home = player.force
rawset(player, "force", f3)
okc, txt = hover(c3)
check(okc and txt:find("{fo-epochs.cc-line:3,6}", 1, true) ~= nil and txt:find("fo-epochs.cc-rule-ok", 1, true) ~= nil,
  "panneau du centre 3 : bâtiments jusqu'au niveau 6 (et non 15), condition remplie (aucune famille possédée)")
rawset(player, "force", f15)
okc, txt = hover(Levels.cc(f15))
check(okc and txt:find("{fo-epochs.cc-line:15,30}", 1, true) ~= nil and txt:find("fo-epochs.cc-rule", 1, true) == nil,
  "panneau du centre 15 : bâtiments jusqu'au niveau 30, plus de condition (niveau maximal)")
-- Panneau d'une foreuse niveau 22 (force au centre 15) : le niveau 23 se paie en monnaie PROVISOIRE de
-- l'époque 12, et le panneau le dit avec le matériau voulu.
local fp = s.create_entity({ name = L.name(L.by_key.drill, 22), position = { x = 130, y = 10 }, force = "fo-test-15" })
ok_panel, all = hover(fp)
check(ok_panel and all:find("fo%-epochs%.currency%-provisional") ~= nil and all:find("fo%-epochs%.want%-superconductor") ~= nil,
  "panneau : monnaie provisoire signalée avec le matériau voulu (époque 12)")
rawset(player, "force", home)

-- Autre force : ni panneau, ni amélioration, ni paiement par le centre adverse (survol, touche U, bouton).
local frv, crv = new_force_with_cc("fo-rival", 2, 200.5)
local rinv = crv.get_inventory(defines.inventory.chest)
stock(rinv, G, 2, 1)
local iron0 = rinv.get_item_count("iron-plate")
local rg = s.create_entity({ name = "gun-turret", position = { x = 210, y = 10 }, force = "fo-rival" })
hover(rg)
check(global.fo.levels_ui.target[1] ~= rg, "autre force : le survol n'ouvre pas son panneau")
rawset(player, "selected", rg)
pcall(M.dispatch, ev["fo-level-up"], { player_index = 1, tick = game.tick })
check(rg.valid and rinv.get_item_count("iron-plate") == iron0,
  "autre force : la touche U n'améliore rien et ne vide pas son centre")
global.fo.levels_ui.target[1] = rg
global.fo.levels_ui.unit[1] = rg.unit_number
pcall(M.dispatch, ev[defines.events.on_gui_click], { element = { valid = true, name = "fo_lvl_up" }, player_index = 1, tick = game.tick })
check(rg.valid and rinv.get_item_count("iron-plate") == iron0
  and global.fo.levels_ui.target[1] == nil, "autre force : le bouton « Améliorer » n'améliore rien (panneau fermé)")
rawset(player, "selected", nil)
end

---------------------------------------------------------------------------------------------------
section("Sauvegarde 0.4.0 avec chantiers en cours : achevés au chargement")
---------------------------------------------------------------------------------------------------
-- Forme exacte d'un chantier 0.4.0 (script/levels/levels.lua du lot V2) : bâtiment hors service, barre de
-- progression, coût déjà payé, ouvrier occupé.
do
local function job_040(e, family, to, left)
  local j = { entity = e, unit = e.unit_number, force = e.force.name, family = family, to = to, start = game.tick,
              finish = game.tick + left, cost = L.cost(L.by_key[family], to) }
  j.r_bg = rendering.draw_rectangle({ color = { r = 0, g = 0, b = 0 }, filled = true, surface = s, left_top = e, right_bottom = e })
  j.r_fg = rendering.draw_rectangle({ color = { r = 1, g = 1, b = 0 }, filled = true, surface = s, left_top = e, right_bottom = e })
  j.r_text = rendering.draw_text({ text = "x", surface = s, target = e, color = { r = 1, g = 1, b = 1 } })
  j.bar_w, j.bar_top = 3, -2
  e.active = false
  return j
end
local lv = global.fo.levels
local furnaces, renders = {}, {}
for i = 1, 5 do
  furnaces[i] = s.create_entity({ name = L.name(L.by_key.furnace, 24), position = { x = 10 * i, y = 280 }, force = "fo-test-13" })
  furnaces[i].insert({ name = "iron-ore", count = 7 })
  local j = job_040(furnaces[i], "furnace", 25, 6000)
  lv.jobs[j.unit] = j
  renders[#renders + 1] = j.r_text
end
-- Chantier d'un centre (centre 4 → 5) alors que la condition Q16 n'est pas remplie (machines au niveau 8 : la
-- condition visée 8 l'est, mais une mitrailleuse 1 la bloquerait aujourd'hui).
s.create_entity({ name = "gun-turret", position = { x = 80, y = 220 }, force = "fo-test-4" })
local cjob = job_040(c4, "command", 5, 6000)
lv.jobs[cjob.unit] = cjob
-- Chantier dont le bâtiment a disparu.
local ghost = s.create_entity({ name = L.name(L.by_key.drill, 5), position = { x = 70, y = 280 }, force = "fo-test-13" })
local gjob = job_040(ghost, "drill", 6, 600)
lv.jobs[gjob.unit] = gjob
ghost.destroy()
-- Chantiers à CIBLE invalide (vérification V2c, mutant M18) : niveau déjà atteint (to = niveau actuel) et
-- niveau au-delà du maximum. Le bâtiment est remis en service, le chantier compté perdu.
local same_lv = s.create_entity({ name = L.name(L.by_key.furnace, 24), position = { x = 90, y = 280 }, force = "fo-test-13" })
local sjob = job_040(same_lv, "furnace", 25, 6000)
sjob.to = 24
lv.jobs[sjob.unit] = sjob
local over_lv = s.create_entity({ name = L.name(L.by_key.furnace, 30), position = { x = 100, y = 280 }, force = "fo-test-13" })
local ojob = job_040(over_lv, "furnace", 30, 6000)
ojob.to = 31
lv.jobs[ojob.unit] = ojob
lv.busy = { ["fo-test-13"] = 5, ["fo-test-4"] = 1 }
lv.time_factor = 0.05
local up0, lost0 = lv.stats.upgrades, lv.stats.lost or 0
local ok_ser, err_ser = pcall(M.serialize, global)
check(ok_ser, "global sérialisable (" .. tostring(err_ser) .. ")")
local saved = M.deepcopy_global(global)
M.load_mod()
_G.global = saved
local ok_load, err_load = pcall(function() Wd.on_load() end)
check(ok_load, "on_load sans erreur (" .. tostring(err_load) .. ")")
Levels = require("script.levels.levels")
table.insert(Levels.on_replaced, limit_replaced_centre)
local ok_cfg, err_cfg = pcall(M.dispatch, Wd.on_config, { mod_changes = { ["factorio-overhaul"] = { old_version = "0.4.0", new_version = "0.4.1" } } })
check(ok_cfg, "on_configuration_changed sans erreur (" .. tostring(err_cfg) .. ")")
lv = global.fo.levels
local up, active_all, ore_ok = 0, true, true
for i = 1, 5 do
  -- Position attendue calculée depuis la TABLE L.footprints (suite d'intégration de V3-T) : même place si les
  -- niveaux 24 et 25 ont la même emprise (table livrée : four 2×2), sinon la candidate préférée de la règle
  -- d'agrandissement (shared/levels/footprint.lua ; la zone est libre).
  -- Lot V3-T2 : le moteur simulé laisse ces fours 24 en (10 i ; 280), position entière : HORS grille dès que leur
  -- côté est impair (table livrée : 5×5) ; l'emprise actuelle est alors le carré de côté + 1 qui les contient
  -- (Levels.current_box), et un bâtiment hors grille passe toujours par le remplacement par script.
  -- (Sans locale de plus : le bloc principal est à la limite de 200 locales de Lua 5.2.)
  local at = { x = 10 * i, y = 280 }
  if L.footprint(L.by_key.furnace, 24) ~= L.footprint(L.by_key.furnace, 25)
      or not require("shared.levels.footprint").aligned(at, L.footprint(L.by_key.furnace, 24)) then
    at = require("shared.levels.footprint").candidates(require("shared.levels.footprint").tile_box(at,
      L.footprint(L.by_key.furnace, 24) + (require("shared.levels.footprint").aligned(at, L.footprint(L.by_key.furnace, 24)) and 0 or 1)),
      L.footprint(L.by_key.furnace, 25))[1]
  end
  local fu = s.find_entity(L.name(L.by_key.furnace, 25), { x = at.x, y = at.y })
  if fu and (fu.position.x ~= at.x or fu.position.y ~= at.y) then fu = nil end
  if fu then
    up = up + 1
    if fu.active == false then active_all = false end
    if fu.get_item_count("iron-ore") ~= 7 then ore_ok = false end
  end
end
check(up == 5 and active_all, "chantiers 0.4.0 ACHEVÉS au chargement : 5 fours niveau 25, en service (" .. up .. ")")
check(ore_ok, "chantiers 0.4.0 achevés : contenu des fours conservé (remplacement rapide)")
check(Levels.cc_level(game.forces["fo-test-4"]) == 5, "chantier 0.4.0 d'un centre achevé (payé avant Q16 : condition non exigée)")
check(next(lv.jobs) == nil and next(lv.busy) == nil and lv.time_factor == nil, "plus aucun chantier, ouvrier ni réglage de durée enregistré")
check(lv.stats.upgrades == up0 + 6 and lv.stats.lost == lost0 + 3,
  string.format("statistiques : +6 achevés, +3 perdus (bâtiment disparu, cible déjà atteinte, cible au-delà de 30) (%d, %d)",
    lv.stats.upgrades - up0, lv.stats.lost - lost0))
local same_after = s.find_entity(L.name(L.by_key.furnace, 24), { x = 90, y = 280 })
local over_after = s.find_entity(L.name(L.by_key.furnace, 30), { x = 100, y = 280 })
check(same_after == same_lv and same_lv.valid and same_lv.active ~= false,
  "chantier 0.4.0 à cible déjà atteinte : bâtiment inchangé (four 24) et REMIS EN SERVICE")
check(over_after == over_lv and over_lv.valid and over_lv.active ~= false,
  "chantier 0.4.0 à cible au-delà du maximum : bâtiment inchangé (four 30) et REMIS EN SERVICE")
local drawn = 0
for _, id in ipairs(renders) do if rendering.is_valid(id) then drawn = drawn + 1 end end
check(drawn == 0, "barres de progression 0.4.0 effacées")
local ok_run, err_run = pcall(M.run_ticks, 120)
check(ok_run, "jeu continu après le chargement (" .. tostring(err_run) .. ")")

-- Même sauvegarde rechargée SANS changement de version (on_configuration_changed absent) : le filet des 30
-- ticks achève les chantiers.
-- Lot V3-T2 : posé SUR la grille de son côté (le moteur réel recale toujours la position ; le moteur simulé non :
-- en (10 ; 320), un four 5×5 serait hors grille et remis sur la grille par script, à une demi-tuile). Bloc do : le
-- bloc principal est à la limite de 200 locales de Lua 5.2.
do
local p20 = require("shared.levels.footprint").center(require("shared.levels.footprint").tile_box({ x = 10, y = 320 },
  L.footprint(L.by_key.furnace, 20)))
local fu2 = s.create_entity({ name = L.name(L.by_key.furnace, 20), position = p20, force = "fo-test-13" })
local j2 = job_040(fu2, "furnace", 21, 6000)
global.fo.levels.jobs[j2.unit] = j2
saved = M.deepcopy_global(global)
M.load_mod()
_G.global = saved
ok_load = pcall(function() Wd.on_load() end)
Levels = require("script.levels.levels")
ok_run, err_run = pcall(M.run_ticks, 31)
check(ok_load and ok_run and s.find_entity(L.name(L.by_key.furnace, 21), p20) ~= nil
  and next(global.fo.levels.jobs) == nil, "sans changement de version : chantier 0.4.0 achevé dans les 30 ticks (" .. tostring(err_run) .. ")")
end
end

---------------------------------------------------------------------------------------------------
section("Recherche vanilla allégée (QX9) : data-final-fixes.lua sur les technologies de base")
---------------------------------------------------------------------------------------------------
-- Les technologies vanilla de 1.1.91 relues dans data/base/prototypes/technology.lua (comme
-- tests/epochs_test.lua), puis data-final-fixes.lua exécuté sur un data.raw qui les contient. Fonction anonyme :
-- portée de variables locales propre (limite de 200 locales du bloc principal).
;(function()
local vanilla
local tech_dir = game_data_dir()
for _, p in ipairs(tech_dir and { tech_dir .. "/base/prototypes/technology.lua" } or {}) do
  if not vanilla then
    local fh = io.open(p, "rb")
    if fh then
      fh:close()
      local list = {}
      local env = setmetatable({ data = { extend = function(_, t) for _, x in ipairs(t) do list[#list + 1] = x end end },
        util = setmetatable({}, { __index = function() return function() return {} end end }) }, { __index = _G })
      local chunk = loadfile(p, "t", env)
      if chunk and pcall(chunk) then vanilla = list end
    end
  end
end
-- Correction V2c (vérification) : base/data-updates.lua rattache les barils de CHAQUE fluide à fluid-handling,
-- dont le baril de méthane du mod (époque 8 dans X0). Ils ne rangent pas la technologie.
local FH = { name = "fluid-handling", effects = { { type = "unlock-recipe", recipe = "storage-tank" },
  { type = "unlock-recipe", recipe = "empty-barrel" }, { type = "unlock-recipe", recipe = "pump" },
  { type = "unlock-recipe", recipe = "fill-fo-methane-barrel" }, { type = "unlock-recipe", recipe = "empty-fo-methane-barrel" },
  { type = "unlock-recipe", recipe = "fill-water-barrel" } },
  unit = { ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } } } }
local fh_units, fh_epoch = L.vanilla_unit_count(FH, 50)
check(fh_units == 2 and fh_epoch == 4, "QX9 : fluid-handling avec les barils générés (méthane du mod compris) : époque 4, 50 → 2 unités ("
  .. tostring(fh_epoch) .. ", " .. tostring(fh_units) .. ")")
check(L.generated_barrel("fill-fo-methane-barrel") and L.generated_barrel("empty-crude-oil-barrel")
  and not L.generated_barrel("empty-barrel") and not L.generated_barrel("fo-methane-cracking"),
  "QX9 : barils générés reconnus (fill-/empty-<fluide>-barrel), pas le baril vide ni les autres recettes")
check(vanilla ~= nil and #vanilla > 150, "technologies vanilla relues (" .. tostring(vanilla and #vanilla) .. ")")
if vanilla then
  local before, raw_tech = {}, {}
  for _, t in ipairs(vanilla) do
    before[t.name] = t.unit and t.unit.count
    raw_tech[t.name] = t
  end
  raw_tech["fo-test-tech"] = { type = "technology", name = "fo-test-tech", unit = { count = 500, ingredients = { { "logistic-science-pack", 1 } }, time = 30 } }
  local saved_data, saved_deep, saved_log = rawget(_G, "data"), table.deepcopy, rawget(_G, "log")
  _G.data = { raw = { technology = raw_tech, module = {}, recipe = {}, ["ammo-turret"] = {}, ["electric-turret"] = {}, ["fluid-turret"] = {} } }
  table.deepcopy = deepcopy
  _G.log = function() end
  local okd, errd = pcall(dofile, "data-final-fixes.lua")
  _G.data, table.deepcopy, _G.log = saved_data, saved_deep, saved_log
  check(okd, "data-final-fixes.lua exécuté sur les technologies vanilla (" .. tostring(errd) .. ")")
  -- Attendus calculés à la main (époque par les recettes : shared/content/epochs.lua X.base_recipe_epochs ;
  -- échelles X.VANILLA_UNIT_SCALE = 0,9 ; 0,15 ; 0,07 ; 0,04 ; 1 ; 0,15 ; 1… ; 0,25 à l'époque 10).
  local EXPECT = {
    { "steel-processing", 50, 8, "acier : époque 2, × 0,15" },
    { "automation", 10, 1, "machine d'assemblage 1 : époque 3, × 0,07, au moins 1" },
    { "oil-processing", 100, 4, "pétrole : époque 4, × 0,04" },
    { "logistics", 20, 18, "souterrains et répartiteurs : époque 1, × 0,9" },
    { "tank", 250, 250, "char : époque 5, × 1 (inchangé)" },
    { "utility-science-pack", 100, 25, "pack utilitaire : époque 10, × 0,25" },
  }
  for _, ex in ipairs(EXPECT) do
    local t = raw_tech[ex[1]]
    check(t and before[ex[1]] == ex[2] and t.unit.count == ex[3],
      string.format("QX9 : %s %s → %s unités (%s ; obtenu %s → %s)", ex[1], ex[2], ex[3], ex[4], tostring(before[ex[1]]), tostring(t and t.unit.count)))
  end
  -- Toutes les technologies à count : nombre d'unités = arrondi(count × échelle de leur époque), au moins 1 ;
  -- les recherches infinies (formule) et celles du mod ne changent pas.
  local bad, lighter, by_epoch = {}, 0, {}
  for _, t in ipairs(vanilla) do
    local b = before[t.name]
    if b and not t.max_level then
      local e = L.vanilla_tech_epoch(t)
      local want = math.max(1, math.floor(b * X.VANILLA_UNIT_SCALE[e] + 0.5))
      if t.unit.count ~= want then bad[#bad + 1] = t.name .. "=" .. t.unit.count .. "/" .. want end
      if t.unit.count < b then lighter = lighter + 1; by_epoch[e] = (by_epoch[e] or 0) + 1 end
    elseif t.max_level and t.unit.count_formula and t.unit.count ~= b then
      bad[#bad + 1] = t.name .. " (infinie modifiée)"
    end
  end
  check(#bad == 0, "QX9 : chaque technologie vanilla à count suit l'échelle de son époque" .. (#bad > 0 and (" : " .. table.concat(bad, ", ")) or ""))
  local parts = {}
  for e = 1, L.EPOCHS do if by_epoch[e] then parts[#parts + 1] = "ép. " .. e .. " : " .. by_epoch[e] end end
  print("  Technologies vanilla allégées : " .. lighter .. " (" .. table.concat(parts, ", ") .. ")")
  check(lighter >= 50 and not by_epoch[5] and not by_epoch[7], "QX9 : les époques 1 à 4, 6 et 10 sont allégées, pas les époques à × 1 (" .. lighter .. ")")
  check(lighter == 170 and by_epoch[4] == 47, "QX9 : 170 technologies allégées, dont 47 à l'époque 4 (technology.lua)")
  check(raw_tech["fo-test-tech"].unit.count == 500, "QX9 : une technologie du mod (fo-) ne change pas")


  -- Part du budget X0 que prend la recherche vanilla allégée payée avec les packs VANILLA (vérification V2c,
  -- non mesurée jusque-là) : X0 a calibré les échelles avec SES fenêtres de packs (X.pack_window), plus chères
  -- que les packs de la technologie aux époques 2 à 4. Valeurs des packs en MU : modèle « chemin le moins
  -- cher » du lot X0, relevées dans la sortie de tests/epochs_test.lua (« MU des packs par époque », 22/10).
  local PACK_MU = { ["automation-science-pack"] = 2.5, ["logistic-science-pack"] = 6.2, ["military-science-pack"] = 22.8,
    ["chemical-science-pack"] = 19.9, ["production-science-pack"] = 69.7, ["utility-science-pack"] = 32.0,
    ["space-science-pack"] = 105.5 }
  local spent, unknown_pack = {}, {}
  for _, t in ipairs(vanilla) do
    if before[t.name] and not t.max_level then
      local e = L.vanilla_tech_epoch(t)
      local per_unit = 0
      for _, ing in ipairs(t.unit.ingredients or {}) do
        local name, amount = ing.name or ing[1], ing.amount or ing[2] or 1
        if PACK_MU[name] then per_unit = per_unit + amount * PACK_MU[name] else unknown_pack[#unknown_pack + 1] = name end
      end
      spent[e] = (spent[e] or 0) + t.unit.count * per_unit
    end
  end
  check(#unknown_pack == 0, "part de la recherche vanilla : chaque pack valorisé (" .. table.concat(unknown_pack, ", ") .. ")")
  local share_txt = {}
  for e = 1, L.EPOCHS do
    if spent[e] then share_txt[#share_txt + 1] = string.format("ép. %d : %.2f %%", e, 100 * spent[e] / L.target.budget(e)) end
  end
  print("  Recherche vanilla allégée payée en packs vanilla, part du budget X0 de l'époque (X0 vise 17,5 % avec ses fenêtres de packs) : "
    .. table.concat(share_txt, ", "))
  -- Mesure (22/10) : 13 à 16 % du budget aux époques 2 à 4, pas « presque gratuite » ; plus bas qu'X0 (17,5 %)
  -- parce que ses fenêtres comptent des packs plus chers (militaire à l'époque 4).
  for _, e in ipairs({ 1, 2, 3, 4 }) do
    local sh = (spent[e] or 0) / L.target.budget(e)
    check(sh >= 0.05 and sh <= 0.25, string.format("QX9 : époque %d, recherche vanilla allégée payée en packs vanilla = %.2f %% du budget X0 (entre 5 et 25 %% ; X0 : 17,5 %%)",
      e, 100 * sh))
  end
end

-- Étape data RÉELLE (vérification V2c : levels_test ne voyait que technology.lua brut, et fluid-handling restait
-- à 50 unités en jeu) : le banc de l'étape data (tests/datastage/harness.lua) rejoue core, base, le mod,
-- data-updates (barils générés) et data-final-fixes. Attendus : fluid-handling à 2 unités, et la ligne
-- [FO-LEVELS] du journal (celle que le moteur réel écrit aussi) à 170 technologies.
local data_dir = game_data_dir()
check(data_dir ~= nil, "données du jeu trouvées pour le banc de l'étape data (" .. tostring(data_dir) .. ")")
if data_dir then
  local lua = (arg and arg[-1]) or "lua5.2"
  local cmd = lua .. ' tests/datastage/harness.lua "' .. data_dir .. '" . --verbose --dump-final technology/fluid-handling 2>&1'
  local ph = io.popen(cmd, "r")
  local out = ph and ph:read("*a") or ""
  local closed_ok = ph and ph:close()
  local unit_block = out:match("unit = {(.-)}")
  local fh_count = unit_block and tonumber(unit_block:match("count = (%d+)"))
  local logged = tonumber(out:match("%[FO%-LEVELS%] recherche vanilla allégée %(QX9%) : (%d+) technologie"))
  check(closed_ok and out:find('name = "fluid-handling"', 1, true) ~= nil,
    "étape data réelle rejouée sans erreur (garde de dress comprise, scénario X0 comparé à chaque famille)")
  check(fh_count == 2, "étape data réelle : fluid-handling à 2 unités après les barils générés (" .. tostring(fh_count) .. ")")
  check(logged == 170, "étape data réelle : [FO-LEVELS] recherche vanilla allégée (QX9) : 170 technologie(s) (" .. tostring(logged) .. ")")
end
end)()

---------------------------------------------------------------------------------------------------
section("Feuilles de la mitrailleuse hors de git (D-6, correction A2) : manifeste")
---------------------------------------------------------------------------------------------------
-- Les contrôles du harness rejoué ci-dessus (--dump-final) s'arrêtent AVANT la règle « images » : sans ce contrôle,
-- un worktree neuf sans PNG restait vert ici alors que le jeu refuse le mod.
;(function()
local GunSheets = dofile("tests/datastage/gun_sheets.lua")
local r = GunSheets.check(".")
local ok = GunSheets.ok(r)
if not ok then for _, l in ipairs(GunSheets.lines(r)) do print(l) end end
check(ok and r.n > 0, string.format("graphics/levels/gun : %d PNG du manifeste présents, à la taille et aux dimensions "
  .. "du manifeste (%d manquant(s), %d écart(s)%s)", r.n, #r.manquants, #r.ecarts, r.erreur and (", " .. r.erreur) or ""))
-- lot F2-B : feuilles du four (même règle D-6)
local FourSheets = dofile("tests/datastage/four_sheets.lua")
local r4 = FourSheets.check(".")
local ok4 = FourSheets.ok(r4)
if not ok4 then for _, l in ipairs(FourSheets.lines(r4)) do print(l) end end
check(ok4 and r4.n > 0, string.format("graphics/levels/four : %d PNG du manifeste présents, à la taille et aux "
  .. "dimensions du manifeste, %d image(s) de sprites.lua relue(s) (%d manquant(s), %d écart(s)%s)", r4.n, r4.refs or 0,
  #r4.manquants, #r4.ecarts, r4.erreur and (", " .. r4.erreur) or ""))
-- lot F3-B : feuilles de la machine d'assemblage (même règle D-6)
local AsmSheets = dofile("tests/datastage/asm_sheets.lua")
local ra = AsmSheets.check(".")
local oka = AsmSheets.ok(ra)
if not oka then for _, l in ipairs(AsmSheets.lines(ra)) do print(l) end end
check(oka and ra.n > 0, string.format("graphics/levels/assembleur : %d PNG du manifeste présents, à la taille et aux "
  .. "dimensions du manifeste, %d image(s) de sprites.lua relue(s) (%d manquant(s), %d écart(s)%s)", ra.n, ra.refs or 0,
  #ra.manquants, #ra.ecarts, ra.erreur and (", " .. ra.erreur) or ""))
-- lot F4-B : feuilles de la foreuse (même règle D-6)
local DrillSheets = dofile("tests/datastage/drill_sheets.lua")
local rd = DrillSheets.check(".")
local okd = DrillSheets.ok(rd)
if not okd then for _, l in ipairs(DrillSheets.lines(rd)) do print(l) end end
check(okd and rd.n > 0, string.format("graphics/levels/foreuse : %d PNG du manifeste présents, à la taille et aux "
  .. "dimensions du manifeste, %d image(s) de sprites.lua relue(s) (%d manquant(s), %d écart(s)%s)", rd.n, rd.refs or 0,
  #rd.manquants, #rd.ecarts, rd.erreur and (", " .. rd.erreur) or ""))
end)()

---------------------------------------------------------------------------------------------------
section("Emprise croissante (lot V3-T) : table, règle de position, place, agrandissement, contour")
---------------------------------------------------------------------------------------------------
-- Q23 (22/10, 7 h 20) et Q24 (22/10, 7 h 40 : « agrandissement sur place si la place autour est libre ;
-- sinon l'amélioration est refusée et le contour nécessaire s'affiche »). Règles pures : shared/levels/footprint.lua
-- et L.footprint ; runtime : script/levels/levels.lua (moteur simulé, enveloppé ci-dessous). Fonction anonyme :
-- portée de variables locales propre.
;(function()
local Foot = require("shared.levels.footprint")
local GUN = L.by_key.gun

-- 1. Table d'emprise : mitrailleuse 2 → 6 par ère (3 époques), les autres familles à leur côté de base.
local want_gun = { 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6 }
local gun_ok = true
for n = 1, 30 do if L.footprint(GUN, n) ~= want_gun[n] then gun_ok = false end end
check(gun_ok, "table : mitrailleuse 2×2 (niveaux 1-6, époques 1-3), 3×3 (7-12), 4×4 (13-18), 5×5 (19-24), 6×6 (25-30)")
-- Correction V3-T (défaut 3) : le contrôle ne vise plus « toute famille autre que gun » (il cassait dès qu'on
-- activait une autre famille) : famille ABSENTE de la table → côté de base à tous les niveaux ; ligne de la
-- table → niveau 1 au côté de base (le niveau 1 est le prototype vanilla).
local absent_ok, row_ok, mono_ok = true, true, true
for _, f in ipairs(L.families) do
  local prev = 0
  for n = 1, f.max do
    local side = L.footprint(f, n)
    if side < prev then mono_ok = false end
    prev = side
    if not L.footprints[f.key] and side ~= f.size then absent_ok = false end
  end
  if L.footprints[f.key] and L.footprint(f, 1) ~= f.size then row_ok = false end
end
check(absent_ok and row_ok and L.footprints.gun ~= nil,
  "table : famille absente de la table → côté de base partout ; ligne de la table → niveau 1 au côté vanilla")
check(mono_ok, "table : l'emprise ne rétrécit jamais d'un niveau au suivant (toutes les familles)")
-- Garde de la table (L.footprint_errors, appelée par l'étape data avant toute génération).
check(#L.footprint_errors() == 0, "garde : la table livrée est valide")
-- Lot V3-T2 : table livrée = la réponse du Directeur Créatif à Q-S1 (22/10, 16 h 45 : oui ; toutes les familles,
-- plafond 6×6 pour les machines, centre 4×4 → 8×8, mur inchangé).
do
  local want_rows = { command = { 4, 5, 6, 7, 8 }, gun = { 2, 3, 4, 5, 6 }, laser = { 2, 3, 4, 5, 6 }, drill = { 3, 4, 5, 6, 6 },
    furnace = { 2, 3, 4, 5, 6 }, assembler = { 3, 4, 5, 6, 6 } }
  local rows_ok, maxes = true, {}
  for _, f in ipairs(L.families) do
    local row, want = L.footprints[f.key], want_rows[f.key]
    if want then
      if not (row and row.era and #row.era == 5) then rows_ok = false
      else for i = 1, 5 do if row.era[i] ~= want[i] then rows_ok = false end end end
    elseif row ~= nil then
      rows_ok = false
    end
    maxes[#maxes + 1] = f.key .. " " .. L.footprint_max(f)
  end
  local machines_capped = L.footprint_max(L.by_key.drill) == 6 and L.footprint_max(L.by_key.assembler) == 6
    and L.footprint_max(L.by_key.furnace) == 6 and L.footprint(L.by_key.drill, 19) == 6 and L.footprint(L.by_key.drill, 18) == 5
  check(rows_ok and machines_capped and L.footprint(L.by_key.command, 13) == 8 and L.footprint(L.by_key.command, 12) == 7
    and L.footprints.wall == nil and L.footprint_max(L.by_key.wall) == 1,
    "table livrée (Q-S1, lot V3-T2) : toutes les familles sauf le mur ; machines plafonnées à 6×6 (foreuse et assembleur dès le niveau 19), centre 8×8 dès le niveau 13 ("
    .. table.concat(maxes, ", ") .. ")")
  -- Depuis une sauvegarde 0.4.2 (seule la mitrailleuse grandissait) : niveaux qui changent.
  local Foot0 = require("shared.levels.footprint")
  local snap42 = L.footprint_snapshot(true)
  for n = 1, L.by_key.gun.max do snap42.gun[n] = L.footprint(L.by_key.gun, n) end
  local ks = {}
  for _, f in ipairs(L.families) do ks[#ks + 1] = f.key end
  local d42 = Foot0.diff(snap42, L.footprint_snapshot(), ks, function(k) return L.by_key[k].size end)
  local per = {}
  for _, c in ipairs(d42) do per[c.key] = (per[c.key] or 0) + 1 end
  check(#d42 == 108 and per.command == 12 and per.laser == 24 and per.drill == 24 and per.furnace == 24 and per.assembler == 24 and per.gun == nil,
    "migration 0.4.2 → 0.4.3 : " .. #d42 .. " niveaux changent (centre " .. tostring(per.command) .. ", laser " .. tostring(per.laser) .. ", foreuse "
    .. tostring(per.drill) .. ", four " .. tostring(per.furnace) .. ", assembleur " .. tostring(per.assembler) .. ", mitrailleuse 0)")
end
do
  local Common0 = require("prototypes.levels.common")
  -- gen : l'étape data aussi (Common.generate s'arrête sur la garde AVANT de toucher à data.raw ; appelée
  -- seulement avec une table fautive).
  local function errs_with(key, row, gen)
    local before = L.footprints[key]  -- remise ensuite telle quelle (suite d'intégration de V3-T : jamais nil d'office)
    L.footprints[key] = row
    local e = L.footprint_errors()
    local okg, errg
    if gen then okg, errg = pcall(Common0.generate) end
    L.footprints[key] = before
    return table.concat(e, " | "), okg, tostring(errg)
  end
  local e1, ok1, g1 = errs_with("furnace", { era = { 3, 4, 5, 6, 6 } }, true)
  check(e1:find("furnace", 1, true) and e1:find("niveau 1", 1, true) and e1:find("steel-furnace", 1, true)
    and not ok1 and g1:find("table des emprises refusée", 1, true),
    "garde : four « 3 → 6 » REFUSÉ (niveau 1 vanilla 2×2), avec son motif, à l'étape data aussi (" .. e1 .. ")")
  local e2 = errs_with("laser", { era = { 2, 4, 3, 5, 6 } })
  local e3 = errs_with("drill", { era = { 3, 4, 5 } })
  local e4 = errs_with("nope", { era = { 1, 1, 1, 1, 1 } })
  local e5 = errs_with("assembler", { level = { 3, 3 } })
  check(e2:find("rétrécit", 1, true) and e3:find("5 côtés", 1, true) and e4:find("inconnue", 1, true)
    and e5:find("30 côtés", 1, true), "garde : emprise qui rétrécit, ligne incomplète, famille inconnue refusées")
  local e6 = errs_with("furnace", { era = { 2, 3, 4, 5, 6 } })
  check(e6 == "" and #L.footprint_errors() == 0, "garde : four « 2 → 6 » accepté ; table remise en état")
end
check(L.footprint(GUN, 1) == GUN.size and L.footprint_max(GUN) == 6 and L.footprint_max(L.by_key.wall) == 1,
  "table : niveau 1 = bâtiment vanilla (2×2) ; plus grand côté 6 (mitrailleuse), 1 (mur)")
check(L.era_of(GUN, 6) == 1 and L.era_of(GUN, 7) == 2 and L.era_of(GUN, 30) == 5 and L.era_of(L.by_key.command, 3) == 1
  and L.era_of(L.by_key.command, 4) == 2 and L.era_of(L.by_key.command, 15) == 5, "ères : 3 époques chacune (centre : niveau = époque)")
-- Activer une autre famille = remplir la table (forme par ère ou niveau par niveau), rien d'autre.
do
  local LZ = L.by_key.laser
  local before, side30 = L.footprints.laser, L.footprint(LZ, 30)
  L.footprints.laser = { era = { 2, 3, 4, 5, 6 } }
  local era_ok = L.footprint(LZ, 6) == 2 and L.footprint(LZ, 7) == 3 and L.footprint(LZ, 30) == 6 and L.range_bonus(LZ, 30) == 2
  local lv = {}
  for n = 1, 30 do lv[n] = n < 16 and 2 or 4 end
  L.footprints.laser = { level = lv }
  local lvl_ok = L.footprint(LZ, 15) == 2 and L.footprint(LZ, 16) == 4
  L.footprints.laser = before
  check(era_ok and lvl_ok and L.footprints.laser == before and L.footprint(LZ, 30) == side30,
    "table : une famille s'active par sa seule ligne (forme par ère ou par niveau), puis la table revient à son état d'avant")
end
-- Suite d'intégration de V3-T : attentes CALCULÉES depuis la table L.footprints (activer une famille = sa seule
-- ligne, Q-S1 ; le relevé à 24 niveaux de la table livrée n'est plus écrit en dur).
local legacy, current = L.footprint_snapshot(true), L.footprint_snapshot()
local snap_ok, want_ch = true, {}
for _, f in ipairs(L.families) do
  if #current[f.key] ~= f.max or #legacy[f.key] ~= f.max then snap_ok = false end
  for n = 1, f.max do
    if legacy[f.key][n] ~= f.size or current[f.key][n] ~= L.footprint(f, n) then snap_ok = false end
    if L.footprint(f, n) ~= f.size then want_ch[#want_ch + 1] = { key = f.key, level = n, from = f.size, to = L.footprint(f, n) } end
  end
end
check(snap_ok and legacy.gun[30] == 2 and current.gun[30] == L.footprint(GUN, 30) and #current.gun == 30 and #current.command == 15,
  "relevé des emprises : actuel (mitrailleuse 30 : " .. current.gun[30] .. ", centre 15 : " .. current.command[15]
  .. ", tous les niveaux = L.footprint) et d'avant V3-T (toutes au côté de base)")
local keys = {}
for _, f in ipairs(L.families) do keys[#keys + 1] = f.key end
local ch = Foot.diff(nil, current, keys, function(k) return L.by_key[k].size end)
local ch_ok = #ch == #want_ch and #ch > 0
for i, w in ipairs(want_ch) do
  local c = ch[i]
  if not (c and c.key == w.key and c.level == w.level and c.from == w.from and c.to == w.to) then ch_ok = false end
end
local fams_ch = {}
for _, c in ipairs(ch) do if fams_ch[#fams_ch] ~= c.key then fams_ch[#fams_ch + 1] = c.key end end
local first_gun
for _, c in ipairs(ch) do if c.key == "gun" and not first_gun then first_gun = c end end
check(ch_ok and first_gun and first_gun.level == 7 and first_gun.from == 2 and first_gun.to == 3,
  "migration : " .. #ch .. " niveaux changent depuis une sauvegarde d'avant V3-T (familles " .. table.concat(fams_ch, ", ")
  .. " ; dans l'ordre des familles puis des niveaux ; mitrailleuse d'abord au niveau 7 : 2 → 3)")
check(#Foot.diff(current, current, keys, function() return 0 end) == 0, "migration : rien à faire quand le relevé est à jour")
-- Portée : la moitié de la croissance (portée au-delà du bord inchangée).
check(L.range_bonus(GUN, 6) == 0 and L.range_bonus(GUN, 7) == 0.5 and L.range_bonus(GUN, 30) == 2
  and L.range_bonus(L.by_key.wall, 30) == 0
  and L.range_bonus(L.by_key.laser, 30) == (L.footprint(L.by_key.laser, 30) - L.footprint(L.by_key.laser, 1)) / 2,
  "portée : + (côté − 2) / 2 pour la mitrailleuse agrandie (7 : + 0,5 ; 30 : + 2), 0 pour le mur ; laser 30 : + "
  .. L.range_bonus(L.by_key.laser, 30) .. " (selon sa ligne de la table)")

-- 2. Boîtes au style vanilla (relevées par harness --dump-proto : mitrailleuse, machine 2, roboport).
local function same_box(b, x) return math.abs(b[1][1] + x) < 1e-9 and math.abs(b[1][2] + x) < 1e-9 and math.abs(b[2][1] - x) < 1e-9 and math.abs(b[2][2] - x) < 1e-9 end
local c2, s2 = Foot.proto_boxes(2)
local c3, s3 = Foot.proto_boxes(3)
local c4, s4 = Foot.proto_boxes(4)
local c6, s6 = Foot.proto_boxes(6)
check(same_box(c2, 0.7) and same_box(s2, 1) and same_box(c3, 1.2) and same_box(s3, 1.5) and same_box(c4, 1.7) and same_box(s4, 2)
  and same_box(c6, 2.7) and same_box(s6, 3), "boîtes : collision = carré − 0,3 par côté, sélection = carré (2×2 ±0,7/±1 vanilla, 3×3 ±1,2/±1,5, 4×4 ±1,7/±2, 6×6 ±2,7/±3)")

-- 3. Parité et grille.
local b2 = Foot.tile_box({ x = 10, y = 10 }, 2)
local b3 = Foot.tile_box({ x = 9.5, y = 9.5 }, 3)
check(b2.x0 == 9 and b2.x1 == 11 and b3.x0 == 8 and b3.x1 == 11 and Foot.aligned({ x = 10, y = 10 }, 2)
  and Foot.aligned({ x = 9.5, y = 9.5 }, 3) and not Foot.aligned({ x = 10, y = 10 }, 3) and not Foot.aligned({ x = 9.5, y = 10 }, 2),
  "parité : côté pair centré sur un coin de tuile, côté impair au milieu d'une tuile (F41)")
local b3r = Foot.tile_box({ x = 10, y = 10 }, 3)
check(b3r.x1 - b3r.x0 == 3 and Foot.contains(Foot.tile_box({ x = 10, y = 10 }, 4), b3r) or false,
  "parité : position hors grille (sauvegarde d'avant V3-T) arrondie au carré le plus proche")

-- 4. Positions candidates : contiennent l'ancien, dans l'ordre de la règle.
local function centers(list)
  local t = {}
  for i, c in ipairs(list) do t[i] = c.x .. "," .. c.y end
  return table.concat(t, " ")
end
local k23 = Foot.candidates(b2, 3)
check(#k23 == 4 and centers(k23) == "9.5,9.5 10.5,9.5 9.5,10.5 10.5,10.5",
  "2 → 3 : 4 candidates à égale distance, côté impair : nord-ouest, nord-est, sud-ouest, sud-est (" .. centers(k23) .. ")")
local k34 = Foot.candidates(Foot.tile_box({ x = 9.5, y = 9.5 }, 3), 4)
check(#k34 == 4 and centers(k34) == "10,10 9,10 10,9 9,9", "3 → 4 : côté pair : sud-est d'abord, puis sud-ouest, nord-est, nord-ouest (" .. centers(k34) .. ")")
local k24 = Foot.candidates(b2, 4)
check(#k24 == 9 and centers(k24):sub(1, 30) == "10,10 10,11 11,10 9,10 10,9 11" and k24[1].d2 == 0,
  "2 → 4 : 9 candidates, la centrée d'abord, puis les 4 à une tuile (sud, est, ouest, nord), puis les diagonales (" .. centers(k24) .. ")")
local all_ok = true
for a = 1, 6 do
  for b = a, 7 do
    local old = Foot.tile_box({ x = 100 + (a % 2) / 2, y = 50 + (a % 2) / 2 }, a)
    local list = Foot.candidates(old, b)
    if #list ~= (b - a + 1) ^ 2 then all_ok = false end
    local seen, prev = {}, -1
    for _, c in ipairs(list) do
      local key = c.x .. "," .. c.y
      if seen[key] or not Foot.contains(c.box, old) or not Foot.aligned({ x = c.x, y = c.y }, b) or c.d2 < prev then all_ok = false end
      seen[key], prev = true, c.d2
      if not Foot.contains(Foot.search_box(old, b), c.box) then all_ok = false end
    end
    if centers(list) ~= centers(Foot.candidates(old, b)) then all_ok = false end
  end
end
check(all_ok, "candidates (côtés 1 à 7) : (b − a + 1)² positions distinctes, chacune CONTIENT l'ancien, sur la grille, écart croissant, dans le rectangle de recherche, même ordre à chaque appel")
-- Chaîne 2 → 3 → 4 → 5 → 6 en prenant chaque fois la préférée : le centre d'origine revient aux tailles paires.
local box, trail = Foot.tile_box({ x = 0, y = 0 }, 2), {}
for side = 3, 6 do
  local c = Foot.candidates(box, side)[1]
  box = c.box
  trail[#trail + 1] = c.x .. "," .. c.y
end
check(table.concat(trail, " ") == "-0.5,-0.5 0,0 -0.5,-0.5 0,0",
  "chaîne 2 → 6 : demi-tuile au nord-ouest aux tailles impaires, retour au centre d'origine aux tailles paires (" .. table.concat(trail, " ") .. ")")
local shrink = Foot.candidates(Foot.tile_box({ x = 0, y = 0 }, 6), 3)
check(#shrink == 16 and Foot.contains(Foot.tile_box({ x = 0, y = 0 }, 6), shrink[1].box) and shrink[1].x == -0.5,
  "côté plus petit (migration seulement) : 16 positions CONTENUES dans l'ancien, même ordre")

-- 5. Évaluation : tuiles, entités, contact bord à bord.
local function wall_at(tx, ty) return { box = { x0 = tx + 0.01, y0 = ty + 0.01, x1 = tx + 0.99, y1 = ty + 0.99 }, name = "stone-wall" } end
local r = Foot.evaluate(Foot.candidates(b2, 3), {}, {})
check(r.index == 1 and r.chosen == r.preferred, "place libre : la préférée est retenue")
r = Foot.evaluate(Foot.candidates(b2, 3), {}, { wall_at(9, 8), wall_at(9, 11) })
check(r.index == nil and r.chosen == nil and #r.preferred.entities == 1 and r.preferred.entities[1].name == "stone-wall",
  "un mur au nord et un au sud : les 4 positions sont bloquées (refus) ; la préférée nomme son bloqueur")
r = Foot.evaluate(Foot.candidates(b2, 3), {}, { wall_at(8, 8) })
check(r.index == 2 and r.chosen.x == 10.5 and r.chosen.y == 9.5, "mur dans le coin nord-ouest : la 2e position (nord-est) est retenue")
r = Foot.evaluate(Foot.candidates(b2, 3), { { x = 9, y = 8, name = "water" }, { x = 10, y = 11, name = "deepwater" } }, {})
check(r.index == nil and #r.preferred.tiles == 1 and r.preferred.tiles[1].name == "water", "eau au nord et au sud : refus, tuile nommée")
r = Foot.evaluate(Foot.candidates(b2, 3), {}, { wall_at(7, 9), wall_at(12, 9), wall_at(9, 7), wall_at(9, 12) })
check(r.index == 1, "murs collés au carré de 4×4 (contact bord à bord, hors des candidates) : rien ne bloque")
-- Correction V3-T (défaut 8) : refus, candidate MONTRÉE = la plus facile à libérer.
r = Foot.evaluate(Foot.candidates(b2, 3), { { x = 9, y = 8, name = "water" }, { x = 10, y = 8, name = "water" } },
  { { box = { x0 = 9.15, y0 = 11.15, x1 = 9.85, y1 = 11.85 }, name = "wooden-chest" } })
check(r.chosen == nil and #r.candidates[1].tiles == 2 and #r.candidates[1].entities == 0 and #r.candidates[3].tiles == 0
  and #r.candidates[3].entities == 1 and r.target_index == 3 and r.target.y == 10.5 and r.target.entities[1].name == "wooden-chest",
  "refus, eau au nord et coffre au sud : la candidate montrée est la SUD-OUEST (rang 3, gênée par le coffre seul), pas la préférée dans l'eau")
r = Foot.evaluate(Foot.candidates(b2, 3), {}, { wall_at(9, 8), wall_at(10, 8), wall_at(9, 11) })
check(r.target_index == 3 and #r.target.entities == 1, "refus : à tuiles égales, la candidate la moins encombrée en entités (sud-ouest : 1 mur contre 2 au nord)")
r = Foot.evaluate(Foot.candidates(b2, 3), {}, { wall_at(9, 8), wall_at(9, 11) })
check(r.target_index == 1 and r.target == r.preferred, "refus : à égalité parfaite, l'ordre de la règle (la préférée)")
r = Foot.evaluate(Foot.candidates(b2, 3), {}, { wall_at(8, 8) })
check(r.target == r.chosen and r.target_index == 2, "place libre : la candidate montrée est la retenue")

-- 6. Prototypes : garde (l'emprise est une clé de JEU) et boîtes posées par common.lua.
local Common = require("prototypes.levels.common")
local fake = { type = "ammo-turret", name = "fo-lvl-gun-25", collision_box = { { -0.7, -0.7 }, { 0.7, 0.7 } },
  selection_box = { { -1, -1 }, { 1, 1 } }, attack_parameters = { range = 24 } }
Common.apply_footprint(fake, GUN, 25)
check(same_box(fake.collision_box, 2.7) and same_box(fake.selection_box, 3) and fake.attack_parameters.range == 26,
  "common.lua : mitrailleuse 25 → boîtes 6×6, portée + 2")
-- Correction V3-T (défaut 9) : activer une MACHINE déplace ses points de jeu (prototypes au style vanilla :
-- foreuse électrique et assembleur 2 relevés par harness --dump-final).
do
  local DR, AS = L.by_key.drill, L.by_key.assembler
  local function vanilla_drill()
    return { type = "mining-drill", name = "fo-lvl-drill-x", collision_box = { { -1.4, -1.4 }, { 1.4, 1.4 } },
      selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }, vector_to_place_result = { 0, -1.85 }, resource_searching_radius = 2.49,
      input_fluid_box = { pipe_connections = { { position = { -2, 0 } }, { position = { 2, 0 } }, { position = { 0, 2 } } } } }
  end
  local function vanilla_assembler()
    return { type = "assembling-machine", name = "fo-lvl-assembler-x", collision_box = { { -1.2, -1.2 }, { 1.2, 1.2 } },
      selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
      fluid_boxes = { { pipe_connections = { { type = "input", position = { 0, -2 } } } },
        { pipe_connections = { { type = "output", position = { 0, 2 } } } }, off_when_no_fluid_recipe = true } }
  end
  local function pt(v) return (v.x or v[1]) .. "," .. (v.y or v[2]) end
  local function pipes(fbs)
    local t = {}
    for _, fb in ipairs(fbs) do for _, pc in ipairs(fb.pipe_connections) do t[#t + 1] = pt(pc.position) end end
    return table.concat(t, " ")
  end
  local before_dr, before_as = L.footprints.drill, L.footprints.assembler
  L.footprints.drill = { era = { 3, 4, 5, 6, 6 } }
  L.footprints.assembler = { era = { 3, 4, 5, 6, 6 } }
  local d25, d13, d7, d1 = vanilla_drill(), vanilla_drill(), vanilla_drill(), vanilla_drill()
  Common.apply_footprint(d25, DR, 25)
  Common.apply_footprint(d13, DR, 13)
  Common.apply_footprint(d7, DR, 7)
  Common.apply_footprint(d1, DR, 1)
  local a25 = vanilla_assembler()
  Common.apply_footprint(a25, AS, 25)
  local unmoved = vanilla_drill()
  unmoved.collision_box, unmoved.selection_box = Foot.proto_boxes(6)
  local probs_bad = Common.footprint_problems(unmoved, 6)
  local a_bad = vanilla_assembler()
  local probs_abad = Common.footprint_problems(a_bad, 6)
  L.footprints.drill, L.footprints.assembler = before_dr, before_as
  check(same_box(d25.collision_box, 2.7) and pt(d25.vector_to_place_result) == "-0.5,-3.35"
    and math.abs(d25.resource_searching_radius - 3.99) < 1e-9 and pipes({ d25.input_fluid_box }) == "-3.5,-0.5 3.5,-0.5 -0.5,3.5",
    "activation foreuse 6×6 : dépôt " .. pt(d25.vector_to_place_result) .. " (0,35 au-delà du bord nord, comme la 3×3), extraction 8×8 (rayon "
    .. d25.resource_searching_radius .. "), raccords " .. pipes({ d25.input_fluid_box }) .. " (une demi-tuile hors du bord, centres de tuile)")
  check(pt(d13.vector_to_place_result) == "0,-2.85" and pipes({ d13.input_fluid_box }) == "-3,0 3,0 0,3"
    and pt(d7.vector_to_place_result) == "-0.5,-2.35" and pipes({ d7.input_fluid_box }) == "-2.5,-0.5 2.5,-0.5 -0.5,2.5"
    and pt(d1.vector_to_place_result) == "0,-1.85" and d1.resource_searching_radius == 2.49,
    "activation foreuse : 5×5 (" .. pipes({ d13.input_fluid_box }) .. ") et 4×4 (" .. pipes({ d7.input_fluid_box }) .. ") ; niveau 1 intouché")
  check(same_box(a25.collision_box, 2.7) and pipes(a25.fluid_boxes) == "-0.5,-3.5 -0.5,3.5" and a25.fluid_boxes.off_when_no_fluid_recipe == true,
    "activation assembleur 6×6 : raccords " .. pipes(a25.fluid_boxes) .. " hors du bâtiment, réglage de la boîte gardé")
  local bad, abad = table.concat(probs_bad, " | "), table.concat(probs_abad, " | ")
  check(#Common.footprint_problems(d25, 6) == 0 and #Common.footprint_problems(d13, 5) == 0 and #Common.footprint_problems(d7, 4) == 0
    and #Common.footprint_problems(a25, 6) == 0,
    "contrôle de l'étape data (common.lua, footprint_problems) : 0 problème après déplacement (foreuse 4×4, 5×5, 6×6 ; assembleur 6×6)")
  check(bad:find("raccord de tuyau (-2, 0) dans la boîte", 1, true) and bad:find("point de dépôt", 1, true)
    and bad:find("rayon d'extraction", 1, true) and bad:find("hors des centres de tuile", 1, true)
    and abad:find("raccord de tuyau (0, -2) dans la boîte", 1, true),
    "contrôle : la foreuse 6×6 aux points vanilla est REFUSÉE (raccords et dépôt dans le corps, extraction plus petite que l'emprise), l'assembleur aussi ("
    .. #probs_bad .. " et " .. #probs_abad .. " problèmes)")
end
local fake6 = { type = "ammo-turret", name = "fo-lvl-gun-6", collision_box = { { -0.7, -0.7 }, { 0.7, 0.7 } },
  selection_box = { { -1, -1 }, { 1, 1 } }, attack_parameters = { range = 19.25 } }
Common.apply_footprint(fake6, GUN, 6)
check(same_box(fake6.collision_box, 0.7) and fake6.attack_parameters.range == 19.25, "common.lua : niveau à l'emprise de base intouché")
local snap = Common.game_snapshot({ collision_box = 1, selection_box = 2, drawing_box = 3, picture = 4 })
check(snap.part.collision_box == 1 and snap.part.selection_box == 2 and snap.part.drawing_box == nil,
  "garde : collision_box et selection_box sont des champs de JEU (protégés de dress), drawing_box est graphique")
local saved_deep = table.deepcopy
table.deepcopy = deepcopy
local ctx = Common.context(GUN, 25)
check(ctx.footprint == 6 and math.abs(Common.kit.sprite_scale(ctx) - 3 * (1 + 0.10 * 24 / 29)) < 1e-9
  and math.abs(Common.kit.sprite_scale(Common.context(GUN, 6)) - (1 + 0.10 * 5 / 29)) < 1e-9,
  "visuel provisoire : ctx.footprint = 6 ; sprite × 3 (rapport des emprises) au niveau 25, inchangé au niveau 6")
local fp = { attack_parameters = { projectile_creation_distance = 1.39375, projectile_center = { 0, -0.0875 },
  shell_particle = { center = { -0.0625, 0 }, creation_distance = -1.925 } } }
Common.kit.scale_muzzle(fp, 3)
check(math.abs(fp.attack_parameters.projectile_creation_distance - 4.18125) < 1e-9 and math.abs(fp.attack_parameters.projectile_center[2] + 0.2625) < 1e-9
  and math.abs(fp.attack_parameters.shell_particle.creation_distance + 5.775) < 1e-9,
  "visuel provisoire : bouche du canon et douilles à l'échelle de l'emprise (sous-clés graphiques)")
table.deepcopy = saved_deep

-- Étape data RÉELLE (harness) : la mitrailleuse 25 telle que le mod la livre.
local data_dir = game_data_dir()
if data_dir then
  local lua = (arg and arg[-1]) or "lua5.2"
  local ph = io.popen(lua .. ' tests/datastage/harness.lua "' .. data_dir .. '" . --dump-final ammo-turret/fo-lvl-gun-25 2>&1', "r")
  local out = ph and ph:read("*a") or ""
  if ph then ph:close() end
  local col = out:match("\n  collision_box = (%b{})")
  local sel = out:match("\n  selection_box = (%b{})")
  local rng = tonumber(out:match("\n    range = ([%d%.]+)"))
  local want_range = L.apply_stat(GUN.stats[3], 18, 25) + 2
  check(col and col:find("2.7", 1, true) and sel and sel:find("= 3", 1, true) and rng and math.abs(rng - want_range) < 1e-9
    and out:find('fast_replaceable_group = "fo-lvl-gun"', 1, true),
    "étape data réelle : fo-lvl-gun-25 en 6×6 (collision ±2,7, sélection ±3), portée " .. tostring(rng) .. ", même groupe de remplacement (F39)")
else
  check(false, "données du jeu introuvables pour l'étape data réelle")
end

-- 7. Runtime en moteur simulé. Enveloppes du moteur simulé (il ne lit pas l'étape data) : prototypes avec
-- masque et boîte, rendu capturé, tuiles d'eau (bounding_box, recherche par zone et décors : moteur simulé lui-même
-- depuis la suite d'intégration de V3-T).
local MASK = { ["object-layer"] = true, ["player-layer"] = true, ["water-tile"] = true, ["item-layer"] = true }
for n = 1, 30 do
  local p = Wd.prototypes[L.name(GUN, n)]
  local cbox = Foot.proto_boxes(L.footprint(GUN, n))
  p.collision_mask = MASK
  p.collision_box = { left_top = { x = cbox[1][1], y = cbox[1][2] }, right_bottom = { x = cbox[2][1], y = cbox[2][2] } }
end
local function proto(name, ptype, half, mask)
  rawset(Wd.prototypes, name, { type = ptype, max_health = 100, collision_mask = mask,
    collision_box = { left_top = { x = -half, y = -half }, right_bottom = { x = half, y = half } } })
end
proto("stone-wall", "wall", 0.49, { ["object-layer"] = true, ["item-layer"] = true, ["player-layer"] = true, ["water-tile"] = true })
proto("iron-chest", "container", 0.35, { ["object-layer"] = true, ["item-layer"] = true, ["player-layer"] = true, ["water-tile"] = true })
proto("tree-01", "tree", 0.4, { ["object-layer"] = true, ["item-layer"] = true, ["player-layer"] = true, ["water-tile"] = true })
proto("item-on-ground", "item-entity", 0.14, { ["item-layer"] = true })
proto("iron-ore", "resource", 0.1, { ["resource-layer"] = true })
proto("fo-test-walker", "character", 0.2, { ["player-layer"] = true })
-- Correction V3-T (défaut 14) : minerai posé comme une VRAIE entité du moteur simulé (le nom « iron-ore » y
-- part dans les gisements, que find_entities_filtered{area} ne rend jamais : le contrôle était vide) ; seul le
-- filtre par couche commune peut l'écarter.
proto("fo-test-ore", "resource", 0.49, { ["resource-layer"] = true })
-- Correction V3-T (défaut 5) : fantômes (couche « ghost-layer » seulement, comme le moteur).
proto("fo-test-ghost", "entity-ghost", 0.49, { ["ghost-layer"] = true })
proto("fo-test-tile-ghost", "tile-ghost", 0.5, { ["ghost-layer"] = true })
proto("fo-test-floor-thing", "simple-entity", 0.4, { ["floor-layer"] = true })  -- aucune couche commune avec la tourelle
-- bounding_box d'après la boîte du prototype, recherche par zone par boîte et décors : moteur simulé
-- (tests/mock_engine.lua, suite d'intégration de V3-T ; l'enveloppe locale posée ici par le lot V3-T est retirée).
local WATER = {}
Wd.tile_at = function(x, y) return WATER[x .. "," .. y] or "grass-1" end
local drawn = {}
local raw_rect = rendering.draw_rectangle
rendering.draw_rectangle = function(t)
  assert(t.time_to_live and t.time_to_live > 0, "draw_rectangle : durée limitée attendue (time_to_live)")
  drawn[#drawn + 1] = t
  return raw_rect(t)
end

local TF = "fo-taille"
game.create_force(TF)
local tcc = s.create_entity({ name = L.name(L.by_key.command, 15), position = { x = 300.5, y = 500.5 }, force = TF })
built(tcc)
limit_chest(tcc)
local tinv = tcc.get_inventory(defines.inventory.chest)
local replaced_seen = {}
table.insert(Levels.on_replaced, function(old_unit, new) replaced_seen[#replaced_seen + 1] = { old_unit, new } end)
local function st() return global.fo.levels.stats end
local function gun_at(n, x, y, ammo)
  local g = s.create_entity({ name = L.name(GUN, n), position = { x = x, y = y }, force = TF })
  if ammo then g.insert({ name = "firearm-magazine", count = ammo }) end
  return g
end
local function chest_value() return L.cost_value((function()
  local t = {}
  for _, c in ipairs(L.cost(GUN, 7)) do t[#t + 1] = { c[1], tinv.get_item_count(c[1]) } end
  return t
end)()) end

-- a. Place libre : 6 → 7 (2×2 → 3×3), munitions, PV, ancien objet disparu, 0 secours, recensement.
local g6 = gun_at(6, 400, 500, 25)
g6.health = Wd.prototype(L.name(GUN, 6)).max_health / 2
stock(tinv, GUN, 7, 1)
local fb0, rs0, up0 = st().fallback or 0, st().resized or 0, st().upgrades
local seen0 = #replaced_seen
local unit6 = g6.unit_number
local ok7, why7, info7, g7 = Levels.start(g6, nil)
check(ok7 and why7 == "done" and g7 and g7.name == L.name(GUN, 7) and not g6.valid,
  "agrandissement 6 → 7 sur place libre : fait aussitôt (" .. tostring(why7) .. ")")
check(g7 and g7.position.x == 399.5 and g7.position.y == 499.5 and info7.resize.from == 2 and info7.resize.to == 3 and info7.room.index == 1,
  "agrandissement : position préférée (nord-ouest, 399,5 ; 499,5), 2×2 → 3×3")
check(g7 and g7.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine") == 25, "agrandissement : 25 chargeurs transférés")
check(g7 and math.abs(g7.get_health_ratio() - 0.5) < 1e-9, "agrandissement : PV en proportion (50 %)")
check((st().fallback or 0) == fb0 and st().resized == rs0 + 1 and st().upgrades == up0 + 1,
  "agrandissement : remplacement par script compté (resized), 0 secours manuel, 1 amélioration")
check(tinv.get_item_count(L.name(GUN, 6)) == 0 and (Wd.spilled == nil or (Wd.spilled[L.name(GUN, 6)] or 0) == 0),
  "agrandissement : l'objet de l'ancien niveau disparaît (ni dans le centre, ni au sol)")
check(#replaced_seen == seen0 + 1 and replaced_seen[#replaced_seen][1] == unit6 and replaced_seen[#replaced_seen][2] == g7,
  "agrandissement : crochet Levels.on_replaced appelé (ancien numéro, nouvelle entité : le panneau suit)")
local cen = Levels.census(game.forces[TF], 7)
check(cen.gun.any and cen.gun.top, "agrandissement : recensement Q16 à jour (mitrailleuse au niveau 7)")

-- b. Taille constante : 7 → 8, remplacement rapide moteur, inchangé.
local fr0, rs1 = Wd.fast_replaced or 0, st().resized
stock(tinv, GUN, 8, 1)
local ok8, why8, _, g8 = Levels.start(g7, nil)
check(ok8 and g8 and g8.position.x == 399.5 and (Wd.fast_replaced or 0) == fr0 + 1 and st().resized == rs1,
  "taille constante (3×3 → 3×3) : remplacement rapide du moteur, même position, aucun remplacement par script (" .. tostring(why8) .. ")")
check(g8 and g8.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine") == 25, "taille constante : munitions conservées")

-- c. Bloquée par un mur au nord et un coffre au sud : refus « no-room », rien payé, contour.
local gb = gun_at(6, 420, 500, 10)
s.create_entity({ name = "stone-wall", position = { x = 419.5, y = 498.5 }, force = TF })
s.create_entity({ name = "iron-chest", position = { x = 419.5, y = 501.5 }, force = TF })
stock(tinv, GUN, 7, 1)
local before = {}
for _, c in ipairs(L.cost(GUN, 7)) do before[c[1]] = tinv.get_item_count(c[1]) end
local ct0, rr0, nd = st().contours or 0, st().room_refused or 0, #drawn
local okb, whyb, infob = Levels.start(gb, nil)
local unpaid = true
for _, c in ipairs(L.cost(GUN, 7)) do if tinv.get_item_count(c[1]) ~= before[c[1]] then unpaid = false end end
check(not okb and whyb == "no-room" and gb.valid and gb.get_item_count("firearm-magazine") == 10,
  "mur au nord et coffre au sud : refus « no-room », mitrailleuse 6 intacte (" .. tostring(whyb) .. ")")
check(unpaid, "refus « no-room » : coût NON payé (place vérifiée avant le paiement)")
local main = drawn[nd + 1]
check(#drawn == nd + 2 and main and main.left_top[1] == 418 and main.left_top[2] == 498 and main.right_bottom[1] == 421
  and main.right_bottom[2] == 501 and main.filled == false and main.players == nil and main.forces and main.forces[1] == TF
  and main.time_to_live == Levels.CONTOUR_TTL,
  "contour dessiné : carré 3×3 de la position préférée (418, 498 → 421, 501), visible de la force (pas de joueur), durée limitée, + le mur qui la bloque surligné")
check(st().contours == ct0 + 1 and st().room_refused == rr0 + 1, "compteurs : 1 contour, 1 refus faute de place")
local names = Levels.blocker_names(infob.room.preferred)
check(#names == 1 and names[1] == "stone-wall" and Levels.blockers_text(infob.room.preferred) == "[entity=stone-wall]",
  "bloqueur de la position préférée nommé (mur)")
local rb = remote.call("factorio-overhaul", "levels_upgrade", gb)
check(rb and rb.ok == false and rb.reason == "no-room" and rb.entity == nil and rb.resize.to == 3 and rb.position == nil
  and rb.contour.x0 == 418 and rb.contour.y1 == 501 and rb.blockers[1] == "stone-wall",
  "interface distante : levels_upgrade rend « no-room », la taille visée, le contour et les bloqueurs")
local rp = remote.call("factorio-overhaul", "levels_preview", gb)
check(rp and rp.reason == "no-room" and st().contours == ct0 + 2, "interface distante : levels_preview ne dessine rien (seul levels_upgrade a dessiné)")
-- Avec un joueur : contour visible de lui seul.
nd = #drawn
Levels.start(gb, Wd.player)
check(drawn[nd + 1] and drawn[nd + 1].players and drawn[nd + 1].players[1] == 1 and drawn[nd + 1].forces == nil,
  "refus d'un joueur (Levels.start avec joueur : touche U et bouton y mènent, voir j.) : contour visible de ce seul joueur")
local fo_keys = {}
for k in pairs(global.fo.levels) do fo_keys[#fo_keys + 1] = k end
table.sort(fo_keys)
check(table.concat(fo_keys, ",") == "busy,cc,census,footprints,jobs,replacing,stats",
  "global : aucun identifiant de rendu gardé (contours effacés par le moteur) (" .. table.concat(fo_keys, ",") .. ")")

-- c2. Correction V3-T (défaut 16) : « no-room » passe APRÈS les autres motifs. Mitrailleuse bloquée par des
-- murs, centre SANS le coût du niveau 7 : motif « no-resources », aucun contour, aucun refus faute de place
-- compté, mais la place reste calculée pour le panneau.
do
  local gr = gun_at(6, 600, 500)
  s.create_entity({ name = "stone-wall", position = { x = 599.5, y = 498.5 }, force = TF })
  s.create_entity({ name = "stone-wall", position = { x = 599.5, y = 501.5 }, force = TF })
  local item1 = L.cost(GUN, 7)[1][1]
  local kept = tinv.remove({ name = item1, count = 1e9 })
  local ct1, rr1, nd1 = st().contours or 0, st().room_refused or 0, #drawn
  local okr, whyr, infor = Levels.start(gr, nil)
  if kept > 0 then tinv.insert({ name = item1, count = kept }) end
  check(not okr and whyr == "no-resources" and #drawn == nd1 and (st().contours or 0) == ct1 and (st().room_refused or 0) == rr1
    and infor.room and infor.room.chosen == nil and infor.resize.to == 3,
    "priorité des motifs : sans ressources ET sans place → « no-resources » (pas de contour, pas de refus faute de place compté ; place calculée pour le panneau) (" .. tostring(whyr) .. ")")
end

-- d. Bloquée par l'eau : refus, tuile nommée.
local gw = gun_at(6, 440, 500)
WATER["439,498"], WATER["439,501"] = "water", "water"
stock(tinv, GUN, 7, 1)
local okw, whyw, infow = Levels.start(gw, nil)
WATER["439,498"], WATER["439,501"] = nil, nil
check(not okw and whyw == "no-room" and gw.valid and Levels.blocker_names(infow.room.preferred)[1] == "tile:water",
  "eau au nord et au sud : refus « no-room », eau nommée (" .. tostring(whyw) .. ")")

-- d2. Correction V3-T (défaut 8) : eau au nord (rangée y = 498) et coffre au sud-ouest. Le contour montre la
-- candidate SUD-OUEST (rang 3 : gênée par le coffre seul), pas la préférée dans l'eau ; sans le coffre,
-- l'agrandissement passe là.
do
  local gd = gun_at(6, 640, 500, 4)
  WATER["639,498"], WATER["640,498"] = "water", "water"
  local chest = s.create_entity({ name = "iron-chest", position = { x = 639.5, y = 501.5 }, force = TF })
  stock(tinv, GUN, 7, 1)
  local nd2 = #drawn
  local rd2 = remote.call("factorio-overhaul", "levels_upgrade", gd)
  local main2 = drawn[nd2 + 1]
  check(rd2.reason == "no-room" and rd2.contour_candidate == 3 and rd2.contour.x0 == 638 and rd2.contour.y0 == 499
    and rd2.contour.x1 == 641 and rd2.contour.y1 == 502 and #rd2.blockers == 1 and rd2.blockers[1] == "iron-chest"
    and main2 and main2.left_top[1] == 638 and main2.left_top[2] == 499,
    "refus, eau au nord, coffre au sud : contour sur la position SUD-OUEST (gênée par le coffre seul), pas sur l'eau (rang "
    .. tostring(rd2.contour_candidate) .. ", gêne : " .. table.concat(rd2.blockers or {}, ",") .. ")")
  chest.destroy()
  local rd3 = remote.call("factorio-overhaul", "levels_upgrade", gd)
  WATER["639,498"], WATER["640,498"] = nil, nil
  check(rd3.ok and rd3.candidate == 3 and rd3.position.x == 639.5 and rd3.position.y == 500.5 and rd3.entity.get_item_count("firearm-magazine") == 4,
    "coffre retiré : l'agrandissement passe au sud-ouest, là où le contour l'indiquait (" .. tostring(rd3.reason) .. ")")
end

-- e. Position alternative : arbre dans le coin nord-ouest seulement → la 2e position (nord-est).
local ga = gun_at(6, 460, 500, 3)
stock(tinv, GUN, 7, 1)
s.create_entity({ name = "tree-01", position = { x = 458.5, y = 498.5 }, force = "neutral" })
local oka, whya, infoa, ga7 = Levels.start(ga, nil)
check(oka and ga7 and infoa.room.index == 2 and ga7.position.x == 460.5 and ga7.position.y == 499.5
  and ga7.get_item_count("firearm-magazine") == 3,
  "position préférée bloquée par un arbre, la 2e libre (nord-est) : agrandissement à 460,5 ; 499,5 (" .. tostring(whya) .. ")")

-- f. Ni personnage, ni objet au sol, ni minerai, ni fantôme ne bloquent. Corrections V3-T : l'objet au sol est
-- SORTI du nouveau bâtiment (défaut 4), le fantôme d'entité recouvert est RETIRÉ, le fantôme de tuile reste
-- (défaut 5), le minerai est une vraie entité de la zone (défaut 14).
local gn = gun_at(6, 480, 500)
s.create_entity({ name = "fo-test-walker", position = { x = 478.6, y = 498.6 }, force = TF })
local ground = s.create_entity({ name = "item-on-ground", position = { x = 479.5, y = 498.5 }, force = "neutral" })
local ore = s.create_entity({ name = "fo-test-ore", position = { x = 478.5, y = 500.5 }, force = "neutral" })
local ghost = s.create_entity({ name = "fo-test-ghost", position = { x = 478.5, y = 499.5 }, force = TF })
rawset(ghost, "ghost_prototype", Wd.prototypes["stone-wall"])
local tghost = s.create_entity({ name = "fo-test-tile-ghost", position = { x = 480.5, y = 498.5 }, force = TF })
-- Fantôme d'une entité qui ne heurte pas la tourelle (aucune couche commune) : le moteur le laisserait, nous aussi.
local fghost = s.create_entity({ name = "fo-test-ghost", position = { x = 479.5, y = 500.5 }, force = TF })
rawset(fghost, "ghost_prototype", Wd.prototypes["fo-test-floor-thing"])
local in_zone = false
for _, e in ipairs(s.find_entities_filtered({ area = { { 478, 498 }, { 482, 502 } } })) do if e == ore then in_zone = true end end
check(in_zone, "minerai de test rendu par la recherche de zone (le filtre par couche est bien exercé)")
stock(tinv, GUN, 7, 1)
local raw_fncp = s.find_non_colliding_position
local fncp_calls = {}
s.find_non_colliding_position = function(name, center, radius, precision)
  fncp_calls[#fncp_calls + 1] = { name = name, radius = radius, precision = precision }
  return { x = 477.5, y = center.y }  -- moteur réel : position libre la plus proche, hors du bâtiment
end
local gm0, gr0 = st().ground_moved or 0, st().ghosts_removed or 0
local okn, whyn, infon, gn7 = Levels.start(gn, nil)
s.find_non_colliding_position = raw_fncp
check(okn and infon.room.index == 1 and ore.valid, "personnage (écarté par le moteur), objet au sol, minerai et fantômes : ne bloquent pas (" .. tostring(whyn) .. ")")
local rect_n = gn7 and Foot.collision_rect(Foot.tile_box(gn7.position, 3))
check(ground.valid and ground.position.x == 477.5 and rect_n and ground.position.x < rect_n.x0 and st().ground_moved == gm0 + 1
  and #fncp_calls == 1 and fncp_calls[1].name == "item-on-ground" and fncp_calls[1].radius == 5,
  "objet au sol du nouveau carré SORTI du bâtiment (téléporté à la position libre la plus proche, compté) : il reste ramassable")
check(not ghost.valid and tghost.valid and fghost.valid and st().ghosts_removed == gr0 + 1,
  "fantôme d'entité recouvert retiré (comme une pose à la main), compté ; fantôme de tuile et fantôme sans couche commune laissés")
-- Aucune position libre rendue (moteur : nil) : l'objet reste, compté et journalisé ; jamais détruit.
do
  local gl0 = st().ground_left or 0
  local gz = gun_at(6, 680, 500)
  local it = s.create_entity({ name = "item-on-ground", position = { x = 679.5, y = 498.5 }, force = "neutral" })
  stock(tinv, GUN, 7, 1)
  s.find_non_colliding_position = function() return nil end
  local okz = Levels.start(gz, nil)
  s.find_non_colliding_position = raw_fncp
  local logged = false
  for _, line in ipairs(Wd.logs) do if line:find("laissé(s) sous fo-lvl-gun-7", 1, true) then logged = true end end
  check(okz and it.valid and it.position.x == 679.5 and st().ground_left == gl0 + 1 and logged,
    "objet au sol sans position libre autour : laissé en place (jamais détruit), compté et journalisé")
end
-- Suite « défense dense » (correction, 22/10) : un objet au sol dont la boîte TOUCHE seulement le bord (ou le coin) du
-- nouveau bâtiment n'est pas dessous. La recherche par zone le rend (intervalles fermés, comme le moteur réel :
-- RD_LOG F96 provisoire, E53) ; move_ground_items l'écarte par chevauchement strict : ni poussé, ni compté, ni
-- journalisé « laissé sous ». Boîtes de ± 0,25 : position = bord ± 0,25, exacte en double (même binade), la boîte
-- rendue retombe exactement sur le bord. Aucune position libre (nil) : un objet traité à tort serait compté
-- ground_left et journalisé, ce qui rend le contrôle sensible.
do
  rawset(Wd.prototypes, "fo-test-edge-item", { type = "item-entity", max_health = 10, collision_mask = { ["item-layer"] = true },
    collision_box = { left_top = { x = -0.25, y = -0.25 }, right_bottom = { x = 0.25, y = 0.25 } } })
  local ge = gun_at(6, 700, 500)
  -- Place attendue : la 1re position de la règle (nord-ouest), comme au cas f : centre 699,5 ; 499,5.
  local pr = Foot.collision_rect(Foot.tile_box({ x = 699.5, y = 499.5 }, 3))
  local side = s.create_entity({ name = "fo-test-edge-item", position = { x = pr.x1 + 0.25, y = 499.5 }, force = "neutral" })
  local corner = s.create_entity({ name = "fo-test-edge-item", position = { x = pr.x1 + 0.25, y = pr.y0 - 0.25 }, force = "neutral" })
  local seen = {}
  for _, e in ipairs(s.find_entities_filtered({ area = { { pr.x0, pr.y0 }, { pr.x1, pr.y1 } }, type = "item-entity" })) do seen[e] = true end
  local sb, cb = side.bounding_box, corner.bounding_box
  check(seen[side] and seen[corner] and sb.left_top.x == pr.x1 and cb.left_top.x == pr.x1 and cb.right_bottom.y == pr.y0,
    "objets au sol de test bord à bord et par un coin : rendus par la recherche de zone (le refiltre est bien exercé)")
  local gl0, gm0 = st().ground_left or 0, st().ground_moved or 0
  local nlog = #Wd.logs
  local calls = 0
  stock(tinv, GUN, 7, 1)
  s.find_non_colliding_position = function() calls = calls + 1; return nil end
  local oke, whye, _, ge7 = Levels.start(ge, nil)
  s.find_non_colliding_position = raw_fncp
  local logged = false
  for i = nlog + 1, #Wd.logs do if Wd.logs[i]:find("laissé(s) sous", 1, true) then logged = true end end
  local rr = ge7 and Foot.collision_rect(Foot.tile_box(ge7.position, 3))
  check(oke and rr and rr.x1 == pr.x1 and rr.y0 == pr.y0 and calls == 0 and not logged
    and side.valid and side.position.x == pr.x1 + 0.25 and corner.valid and corner.position.y == pr.y0 - 0.25
    and (st().ground_left or 0) == gl0 and (st().ground_moved or 0) == gm0,
    "objet au sol qui touche le nouveau bâtiment par un bord ou un coin, sans être dessous : ni poussé, ni compté, ni journalisé ("
    .. tostring(whye) .. ", appels " .. calls .. ")")
  side.destroy()
  corner.destroy()
end

-- g. F40 simulé : le nouveau bâtiment détruit pendant raise_built (create_entity rend nil) → coût rendu.
local gf = gun_at(6, 500, 500, 4)
stock(tinv, GUN, 7, 1)
local val_before = chest_value()
local raw_create = s.create_entity
s.create_entity = function(t)
  if t.name == L.name(GUN, 7) and not t.fast_replace then return nil end
  return raw_create(t)
end
local rf0, rfail0 = st().refunds or 0, st().resize_failed or 0
local okf, whyf = Levels.start(gf, nil)
s.create_entity = raw_create
check(not okf and whyf == "replace-failed" and gf.valid and gf.get_item_count("firearm-magazine") == 4
  and math.abs(chest_value() - val_before) < 1e-9 and st().refunds == rf0 + 1 and st().resize_failed == rfail0 + 1,
  "F40 : nouveau bâtiment détruit pendant sa construction → ancien intact, munitions comprises, coût RENDU au centre")

-- g2. Correction V3-T (défauts 6 et 17) : F40 avec un paiement RÉPARTI (centre, puis joueur) : chaque part
-- revient à l'inventaire qui l'a payée.
do
  local gs = gun_at(6, 520, 540, 2)
  local cost7 = L.cost(GUN, 7)
  local item1, need1 = cost7[1][1], cost7[1][2]
  local kept1 = tinv.remove({ name = item1, count = 1e9 })
  local half = math.floor(need1 / 2)
  tinv.insert({ name = item1, count = half })
  for i = 2, #cost7 do tinv.insert({ name = cost7[i][1], count = cost7[i][2] }) end
  local pinv = Wd.player.get_main_inventory()
  pinv.insert({ name = item1, count = need1 - half })
  local cb, pb = {}, {}
  for _, c in ipairs(cost7) do cb[c[1]] = tinv.get_item_count(c[1]); pb[c[1]] = pinv.get_item_count(c[1]) end
  local raw_create2 = s.create_entity
  s.create_entity = function(t)
    if t.name == L.name(GUN, 7) and not t.fast_replace then return nil end
    return raw_create2(t)
  end
  local oks, whys = Levels.start(gs, Wd.player)
  s.create_entity = raw_create2
  local same = true
  for _, c in ipairs(cost7) do
    if tinv.get_item_count(c[1]) ~= cb[c[1]] or pinv.get_item_count(c[1]) ~= pb[c[1]] then same = false end
  end
  check(not oks and whys == "replace-failed" and gs.valid and same and pb[item1] >= need1 - half,
    "F40, paiement réparti (" .. half .. " au centre, " .. (need1 - half) .. " au joueur) : chaque part rendue à l'inventaire qui l'a payée")
  pinv.remove({ name = item1, count = need1 - half })
  tinv.remove({ name = item1, count = half })
  if kept1 > 0 then tinv.insert({ name = item1, count = kept1 }) end
  -- Relevé de pay : retraits effectifs, dans l'ordre (centre puis joueur).
  local a = { n = 0 }
  a.remove = function(it) local k = math.min(a.n, it.count); a.n = a.n - k; return k end
  local b = { n = 100 }
  b.remove = function(it) local k = math.min(b.n, it.count); b.n = b.n - k; return k end
  a.n = 40
  local ledger = Levels.pay({ a, b }, { { "iron-plate", 100 } })
  check(#ledger == 2 and ledger[1].inv == a and ledger[1].count == 40 and ledger[2].inv == b and ledger[2].count == 60,
    "paiement : relevé des retraits par inventaire (40 au centre, 60 au joueur)")
end

-- h. Chaîne 6 → 30 : 4 agrandissements (3, 4, 5, 6) ; retour au centre d'origine en 6×6.
local gc = gun_at(6, 540, 520, 40)
local rs2 = st().resized
local cur, chain_ok, why_c = gc, true, nil
local sides = {}
for n = 7, 30 do
  stock(tinv, GUN, n, 1)
  local okc, whyc, _, nxt = Levels.start(cur, nil)
  if not (okc and nxt) then chain_ok, why_c = false, n .. ":" .. tostring(whyc) break end
  if n == 7 or n == 13 or n == 19 or n == 25 then sides[#sides + 1] = nxt.position.x .. "," .. nxt.position.y end
  cur = nxt
end
check(chain_ok and cur.name == L.name(GUN, 30) and st().resized == rs2 + 4,
  "chaîne 6 → 30 : 24 améliorations dont 4 agrandissements (" .. tostring(why_c) .. ")")
check(table.concat(sides, " ") == "539.5,519.5 540,520 539.5,519.5 540,520" and cur.position.x == 540 and cur.position.y == 520,
  "chaîne : 3×3 et 5×5 décalés d'une demi-tuile au nord-ouest, 4×4 et 6×6 au centre d'origine (" .. table.concat(sides, " ") .. ")")
check(cur.get_item_count("firearm-magazine") == 40 and (st().fallback or 0) == fb0, "chaîne : 40 chargeurs au niveau 30, 0 secours manuel")
local ok_ser, err_ser = pcall(M.serialize, global)
check(ok_ser, "global sérialisable après les agrandissements (" .. tostring(err_ser) .. ")")

-- i. Transfert complet (entités simulées à cases, fluides, recette, brûleur, tourelle, fils, foreuse).
local function stack(name, count, extra)
  local st_ = { valid_for_read = name ~= nil, name = name, count = count or 0, extra = extra }
  st_.transfer_stack = function(src)
    if st_.valid_for_read then return false end
    st_.valid_for_read, st_.name, st_.count, st_.extra = true, src.name, src.count, src.extra
    src.valid_for_read, src.name, src.count, src.extra = false, nil, 0, nil
    return true
  end
  return st_
end
local function inventory(slots)
  local inv = { _slots = slots }
  setmetatable(inv, { __len = function(t) return #t._slots end, __index = function(t, k) return rawget(t, "_slots")[k] end })
  inv.is_empty = function() for _, x in ipairs(slots) do if x.valid_for_read then return false end end return true end
  inv.get_contents = function()
    local c = {}
    for _, x in ipairs(slots) do if x.valid_for_read then c[x.name] = (c[x.name] or 0) + x.count end end
    return c
  end
  inv.insert = function(it)
    for _, x in ipairs(slots) do if not x.valid_for_read then x.valid_for_read, x.name, x.count = true, it.name, it.count return it.count end end
    return 0
  end
  inv.remove = function(it)
    local left = it.count
    for _, x in ipairs(slots) do
      if left > 0 and x.valid_for_read and x.name == it.name then
        local k = math.min(left, x.count)
        x.count, left = x.count - k, left - k
        if x.count == 0 then x.valid_for_read, x.name = false, nil end
      end
    end
    return it.count - left
  end
  return inv
end
local target = { valid = true }
local connected = {}
local function fake_entity(etype, invs, extra)
  local e = { type = etype, valid = true, _invs = invs, surface = s, position = { x = 0, y = 0 }, force = game.forces[TF] }
  e.get_inventory = function(i) return invs[i] end
  e.insert = function() return 0 end
  for k, v in pairs(extra or {}) do e[k] = v end
  return e
end
local ofluid = { { name = "water", amount = 80 }, { name = "steam", amount = 10, temperature = 165 } }
local nfluid = { false, false }
local cb_old = { circuit_enable_disable = true, connect_to_logistic_network = false, circuit_read_resources = true,
  resource_read_mode = 1, circuit_condition = { condition = { comparator = ">", first_signal = { type = "item", name = "coal" }, constant = 5 }, fulfilled = true } }
local cb_new = {}
local old_am = fake_entity("assembling-machine",
  { [2] = inventory({ stack("iron-plate", 40, "plaques"), stack(nil) }), [3] = inventory({ stack("iron-gear-wheel", 7) }),
    [4] = inventory({ stack("speed-module", 1), stack("speed-module", 1) }) },
  { get_recipe = function() return "iron-gear-wheel" end, fluidbox = ofluid, energy = 1234, crafting_progress = 0.4,
    bonus_progress = 0.2, last_user = "joueur-1",
    burner = { currently_burning = "coal", remaining_burning_fuel = 2e6, heat = 5 },
    circuit_connection_definitions = { { wire = 1, target_entity = target, source_circuit_id = 1, target_circuit_id = 1 },
      { wire = 2, target_entity = { valid = true }, source_circuit_id = 1, target_circuit_id = 2 } } })
local recipe_set
local new_am = fake_entity("assembling-machine",
  { [2] = inventory({ stack(nil), stack(nil) }), [3] = inventory({ stack(nil) }), [4] = inventory({ stack(nil), stack(nil), stack(nil) }) },
  { set_recipe = function(r) recipe_set = r end, fluidbox = nfluid, burner = {},
    connect_neighbour = function(d) connected[#connected + 1] = d; return d.target_entity == target end })
local moved = Levels.transfer(old_am, new_am)
check(recipe_set == "iron-gear-wheel" and new_am.get_inventory(2)[1].name == "iron-plate" and new_am.get_inventory(2)[1].count == 40
  and new_am.get_inventory(2)[1].extra == "plaques" and new_am.get_inventory(3)[1].count == 7
  and new_am.get_inventory(4)[2].name == "speed-module" and old_am.get_inventory(2).is_empty() and moved.spilled == 0,
  "transfert (cases) : recette, entrée (pile ENTIÈRE avec ses données), sortie, modules ; ancien vidé, rien renversé")
-- Correction V3-T2 (défaut 10) : la machine ne fabrique pas (pas d'is_crafting) : crafting_progress n'est PAS recopiée
-- (F84 : l'écrire sur une machine à l'arrêt lance une fabrication sans prendre d'ingrédients) ; le bonus, si.
check(nfluid[1] == ofluid[1] and nfluid[2] == ofluid[2] and new_am.energy == 1234 and new_am.crafting_progress == nil
  and new_am.bonus_progress == 0.2 and new_am.last_user == "joueur-1" and new_am.burner.currently_burning == "coal"
  and new_am.burner.remaining_burning_fuel == 2e6 and new_am.burner.heat == 5,
  "transfert : fluides, énergie, bonus de productivité, dernier utilisateur, brûleur (combustible en cours, chaleur) ; progression d'une machine qui ne fabrique pas NON recopiée (F84)")
check(#connected == 2 and connected[1].wire == 1 and connected[1].target_entity == target and moved.wires_lost == 1,
  "transfert : fils de circuit rebranchés vers les mêmes voisins ; un fil trop long compté perdu")
local tg = { valid = true }
local old_t = fake_entity("ammo-turret", { [1] = inventory({ stack("uranium-rounds-magazine", 9) }) },
  { kills = 12, damage_dealt = 3400.5, shooting_target = tg })
local new_t = fake_entity("ammo-turret", { [1] = inventory({ stack(nil) }) })
Levels.transfer(old_t, new_t)
check(new_t.kills == 12 and new_t.damage_dealt == 3400.5 and new_t.shooting_target == tg
  and new_t.get_inventory(1)[1].name == "uranium-rounds-magazine" and new_t.get_inventory(1)[1].count == 9,
  "transfert (tourelle) : munitions, cible en cours, victimes et dégâts infligés")
local old_d = fake_entity("mining-drill", {}, { mining_progress = 0.7, bonus_mining_progress = 0.1,
  get_control_behavior = function() return cb_old end })
local new_d = fake_entity("mining-drill", {}, { get_or_create_control_behavior = function() return cb_new end })
Levels.transfer(old_d, new_d)
check(new_d.mining_progress == 0.7 and cb_new.circuit_enable_disable == true and cb_new.resource_read_mode == 1
  and cb_new.circuit_condition.condition == cb_old.circuit_condition.condition and cb_new.circuit_condition.fulfilled == nil,
  "transfert (foreuse) : progression et réglages du circuit (condition sans le champ en lecture seule « fulfilled »)")
-- Cases en nombre différent : le reste passe par contenu, puis au pied du bâtiment en dernier recours (compté).
local old_x = fake_entity("container", { [1] = inventory({ stack("iron-plate", 50), stack("copper-plate", 30) }) })
local new_x = fake_entity("container", { [1] = inventory({ stack(nil) }) })
local spill0 = Wd.spilled and (Wd.spilled["copper-plate"] or 0) or 0
local mx = Levels.transfer(old_x, new_x)
check(new_x.get_inventory(1)[1].count == 50 and mx.spilled == 30 and Wd.spilled["copper-plate"] == spill0 + 30,
  "transfert : sans case libre, le reste est renversé au pied du bâtiment, COMPTÉ (jamais attendu : le niveau suivant a autant de cases)")

-- j. Panneau « Évolution » : taille et place, puis touche U refusée (contour pour ce joueur).
local player = Wd.player
local home = player.force
rawset(player, "force", game.forces[TF])
local gp = gun_at(6, 560, 560)
s.create_entity({ name = "stone-wall", position = { x = 559.5, y = 558.5 }, force = TF })
s.create_entity({ name = "stone-wall", position = { x = 559.5, y = 561.5 }, force = TF })
stock(tinv, GUN, 7, 1)
local function texts(el, out)
  out = out or {}
  for _, c in ipairs(rawget(el, "_list") or {}) do
    if c.caption then out[#out + 1] = M.ls_to_string(c.caption) end
    texts(c, out)
  end
  return out
end
rawset(player, "selected", nil)
rawset(player, "selected", gp)
local okp, errp = pcall(M.dispatch, ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
local fr = player.gui.left["fo_lvl_panel"]
local txt = fr and table.concat(texts(fr), "\n") or ""
check(okp and txt:find("{fo-levels-taille.resize-line:2×2,3×3}", 1, true) ~= nil
  and txt:find("{fo-levels-taille.room-blocked:[entity=stone-wall]}", 1, true) ~= nil
  and txt:find("{fo-levels-taille.reason-no-room:3×3,[entity=stone-wall]}", 1, true) ~= nil,
  "panneau : « Taille : 2×2 → 3×3 », place insuffisante et motif du refus avec ce qui gêne (" .. tostring(errp) .. ")")
-- Corrections V3-T (défauts 2 et 7) : panneau ouvert, AUCUNE touche : le contour nécessaire est déjà dessiné
-- pour ce joueur (aperçu non compté comme refus), et le bouton reste actif pour le motif « no-room ».
local function find_el(el, name)
  for _, c in ipairs(rawget(el, "_list") or {}) do
    if c.name == name then return c end
    local f = find_el(c, name)
    if f then return f end
  end
  return nil
end
local function rects_on(from, x0, y0, x1, y1)
  local out = {}
  for i = from + 1, #drawn do
    local d = drawn[i]
    if d.left_top[1] == x0 and d.left_top[2] == y0 and d.right_bottom[1] == x1 and d.right_bottom[2] == y1 then out[#out + 1] = d end
  end
  return out
end
do
  local hov = rects_on(0, 558, 558, 561, 561)
  local last = hov[#hov]
  check(last and last.players and last.players[1] == 1 and last.forces == nil and last.time_to_live <= 32 and last.time_to_live >= 2,
    "panneau ouvert sans touche : contour nécessaire dessiné pour ce seul joueur, jusqu'au rafraîchissement suivant (" .. tostring(last and last.time_to_live) .. " ticks)")
  local btn = fr and find_el(fr, "fo_lvl_up")
  check(btn and btn.enabled == true, "bouton « Améliorer » ACTIF pour le motif « no-room » (un bouton désactivé n'émet aucun clic)")
  local ct2, nd3 = st().contours or 0, #drawn
  local nlt2 = Wd.local_texts and #Wd.local_texts or 0
  local okc2, errc2 = pcall(M.dispatch, ev[defines.events.on_gui_click], { element = btn, player_index = 1, tick = game.tick })
  local clicked = rects_on(nd3, 558, 558, 561, 561)
  check(okc2 and gp.valid and st().contours == ct2 + 1 and #clicked == 1 and clicked[1].time_to_live == Levels.CONTOUR_TTL
    and clicked[1].players[1] == 1 and Wd.local_texts[nlt2 + 1]:find("fo-levels-taille.reason-no-room", 1, true) ~= nil,
    "clic sur « Améliorer » (souris seule) : refus sans paiement, contour pour ce joueur 300 ticks, message (" .. tostring(errc2) .. ")")
  -- Le panneau reste ouvert 60 ticks : un aperçu par rafraîchissement (2), jamais empilé.
  local nd4, ct3 = #drawn, st().contours
  local okr2, errr2 = pcall(M.run_ticks, 60)
  local periodic = rects_on(nd4, 558, 558, 561, 561)
  check(okr2 and #periodic == 2 and periodic[1].time_to_live == 32 and periodic[2].time_to_live == 32 and st().contours == ct3,
    "panneau ouvert 60 ticks : contour redessiné à chaque rafraîchissement (2 fois, 32 ticks chacun), sans empilement, non compté comme refus (" .. #periodic .. ", " .. tostring(errr2) .. ")")
end
nd = #drawn
local nlt = Wd.local_texts and #Wd.local_texts or 0
okp, errp = pcall(M.dispatch, ev["fo-level-up"], { player_index = 1, tick = game.tick })
check(okp and gp.valid and drawn[nd + 1] and drawn[nd + 1].players[1] == 1
  and Wd.local_texts[nlt + 1]:find("fo-levels-taille.reason-no-room", 1, true) ~= nil,
  "touche U refusée faute de place : message au joueur et contour pour lui seul (" .. tostring(errp) .. ")")
-- Correction V3-T (défaut 10) : place libre, le joueur voit OÙ ira le bâtiment avant de payer : carré vert de la
-- position retenue ; position autre que l'habituelle (arbre au nord-ouest) : direction écrite au panneau.
do
  local gq = gun_at(6, 600, 560)
  s.create_entity({ name = "tree-01", position = { x = 598.5, y = 558.5 }, force = "neutral" })
  stock(tinv, GUN, 7, 1)
  local nd5 = #drawn
  rawset(player, "selected", nil)
  rawset(player, "selected", gq)
  local okq, errq = pcall(M.dispatch, ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
  local frq = player.gui.left["fo_lvl_panel"]
  local tq = frq and table.concat(texts(frq), "\n") or ""
  local green = rects_on(nd5, 599, 558, 602, 561)
  check(okq and #green == 1 and green[1].color.g > green[1].color.r and green[1].players[1] == 1 and green[1].time_to_live <= 32,
    "place libre : carré VERT de la position retenue (nord-est, 599 → 602), pour ce seul joueur (" .. tostring(errq) .. ")")
  check(tq:find("fo-levels-taille.room-free-moved", 1, true) ~= nil and tq:find("fo-levels-taille.dir-ne", 1, true) ~= nil,
    "place libre mais position habituelle prise : le panneau dit « vers le nord-est »")
  local gq2 = gun_at(6, 620, 560)
  local nd6 = #drawn
  rawset(player, "selected", gq2)
  pcall(M.dispatch, ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
  local tq2 = table.concat(texts(player.gui.left["fo_lvl_panel"]), "\n")
  check(#rects_on(nd6, 618, 558, 621, 561) == 1 and tq2:find("{fo-levels-taille.room-free:}", 1, true) ~= nil
    and tq2:find("room-free-moved", 1, true) == nil, "place libre à la position habituelle : carré vert au nord-ouest, pas de direction")
end
-- Traductions FR et EN des clés du lot (y compris les directions, construites par le panneau).
for _, lang in ipairs({ "fr", "en" }) do
  local keys = {}
  local okk = cfg_keys("locale/" .. lang .. "/levels-taille.cfg", keys)
  local miss = {}
  for _, k in ipairs({ "resize-line", "room-free", "room-free-moved", "room-blocked", "reason-no-room", "dir-n", "dir-s",
      "dir-e", "dir-w", "dir-ne", "dir-nw", "dir-se", "dir-sw" }) do
    if not keys["fo-levels-taille." .. k] then miss[#miss + 1] = k end
  end
  check(okk and #miss == 0, lang .. " : clés fo-levels-taille présentes (" .. table.concat(miss, ",") .. ")")
end
-- 8. Lot V3-T2 (correction des défauts 1 et 6 du correcteur) : POINTS SERVIS. Règle : shared/levels/points.lua.
-- a. Pure : la règle des points d'un prototype (déplacée de prototypes/levels/common.lua) s'inverse sur les points
--    vanilla des familles (dépôt de la foreuse, raccords de tuyau) à tous les côtés de leur ligne.
local Points = require("shared.levels.points")
do
  local pts = { { x = 0, y = -1.85 }, { x = 0, y = -2 }, { x = 0, y = 2 }, { x = -2, y = 0 }, { x = 2, y = 0 } }
  local bad = {}
  for _, side in ipairs({ 3, 4, 5, 6 }) do
    for _, pt in ipairs(pts) do
      local m = Points.move_point(pt, 3, side)
      local back = Points.base_point(m, 3, side)
      if math.abs(back.x - pt.x) > 1e-9 or math.abs(back.y - pt.y) > 1e-9 then bad[#bad + 1] = side .. ":" .. pt.x .. "," .. pt.y end
    end
  end
  -- Virgule fixe du moteur (1/256) : dépôt d'une foreuse 4×4 tournée vers l'est relu (2,34765625 ; −0,49609375) en moteur
  -- réel ; ramené au nord puis à la base : (0 ; −1,84765625), pas une proportion fausse.
  local fx = Points.base_point(Points.unrotate({ x = 2.34765625, y = -0.49609375 }, defines.direction.east), 3, 4)
  if math.abs(fx.x) > 1e-9 or math.abs(fx.y + 1.84765625) > 1e-9 then bad[#bad + 1] = "virgule fixe " .. fx.x .. "," .. fx.y end
  local r = Points.rotate({ x = 0, y = -1 }, defines.direction.east)
  local rs = Points.rotate({ x = -0.5, y = -2.35 }, defines.direction.south)
  check(#bad == 0 and r.x == 1 and r.y == 0 and rs.x == 0.5 and rs.y == 2.35
    and Points.unrotate(Points.rotate({ x = 0.5, y = -2.5 }, 6), 6).x == 0.5,
    "points : règle inversible sur les points vanilla (côtés 3 à 6), rotation du moteur (nord → est : (0, −1) → (1, 0) ; sud : (−0,5 ; −2,35) → (0,5 ; 2,35)) ("
    .. table.concat(bad, " ") .. ")")
end
-- b. Pure : reproduction du correcteur. Foreuse (dépôt (0 ; −1,85) au côté 3) qui dépose dans un coffre, assembleur
--    (raccord (0 ; −2)) raccordé à un tuyau, 4 orientations, passages 3 → 4, 4 → 5, 5 → 6, terrain libre sinon. Règle
--    d'avant (sans points) : le point servi change de tuile pour une partie des cas ; règle V3-T2 : jamais, et une
--    position libre existe toujours.
do
  local cases = { { what = "foreuse", pt = { x = 0, y = -1.85 }, half = 0.35 }, { what = "assembleur", pt = { x = 0, y = -2 }, half = 0.29 } }
  local old_moved, new_moved, new_none, total, old_list = 0, 0, 0, 0, {}
  for _, cs in ipairs(cases) do
    for _, tr in ipairs({ { 3, 4 }, { 4, 5 }, { 5, 6 } }) do
      for _, dir in ipairs({ 0, 2, 4, 6 }) do
        local a, b = tr[1], tr[2]
        local c0 = (a % 2 == 1) and { x = 10.5, y = 10.5 } or { x = 10, y = 10 }
        local t = Points.transpose(Points.move_point(cs.pt, 3, a), 3, a, a, b, dir)
        local px, py = c0.x + t.old.x, c0.y + t.old.y
        local tx, ty = math.floor(px) + 0.5, math.floor(py) + 0.5
        local rec = { box = { x0 = tx - cs.half, y0 = ty - cs.half, x1 = tx + cs.half, y1 = ty + cs.half }, name = cs.what }
        local function run(with_points)
          local cands = Foot.candidates(Foot.tile_box(c0, a), b)
          if with_points then Points.mark(cands, { { rel = t.new, box = rec.box, entity = rec } }) end
          local res = Foot.evaluate(cands, {}, { rec }, Foot.MARGIN)
          local c = res.chosen
          return c and Points.inside(rec.box, c.x + t.new.x, c.y + t.new.y), c
        end
        total = total + 1
        local ok_old = run(false)
        local ok_new, cnew = run(true)
        if not ok_old then
          old_moved = old_moved + 1
          old_list[#old_list + 1] = cs.what .. " " .. a .. "→" .. b .. " dir " .. dir
        end
        if not cnew then new_none = new_none + 1 elseif not ok_new then new_moved = new_moved + 1 end
      end
    end
  end
  check(old_moved > 0 and new_moved == 0 and new_none == 0,
    "points servis : règle d'avant, le point change de tuile dans " .. old_moved .. "/" .. total .. " cas (" .. table.concat(old_list, ", ")
    .. ") ; règle V3-T2 : 0 cas, une position libre trouvée dans les " .. total .. " cas")
  -- Deux raccords OPPOSÉS servis (entrée au nord, sortie au sud) : aucune position ne garde les deux, refus ; la
  -- position montrée désigne un des deux tuyaux.
  local c0 = { x = 10.5, y = 10.5 }
  local n = { box = { x0 = 10.21, y0 = 8.21, x1 = 10.79, y1 = 8.79 }, name = "pipe-n" }
  local so = { box = { x0 = 10.21, y0 = 12.21, x1 = 10.79, y1 = 12.79 }, name = "pipe-s" }
  local tn = Points.transpose({ x = 0, y = -2 }, 3, 3, 3, 4, 0)
  local ts = Points.transpose({ x = 0, y = 2 }, 3, 3, 3, 4, 0)
  local cands = Points.mark(Foot.candidates(Foot.tile_box(c0, 3), 4),
    { { rel = tn.new, box = n.box, entity = n }, { rel = ts.new, box = so.box, entity = so } })
  local res = Foot.evaluate(cands, {}, { n, so }, Foot.MARGIN)
  check(res.chosen == nil and res.target and (#res.target.entities + #res.target.moved) >= 1,
    "points servis : deux raccords opposés raccordés, aucune position ne garde les deux : refus, contour avec un tuyau à retirer")
  -- Dépôt sur un CONVOYEUR (foreuse tournée vers le sud) : la position nord-est (rang 3 ; les deux sud recouvrent le
  -- convoyeur) décale le dépôt d'une tuile, sur le convoyeur voisin de la même ligne : servi (alt) ; sans ce voisin, non.
  local tb = Points.transpose({ x = 0, y = -1.85 }, 3, 3, 3, 4, 4)
  local belt = { box = { x0 = 10.1, y0 = 12.1, x1 = 10.9, y1 = 12.9 }, name = "transport-belt" }
  local nextb = { x0 = 11.1, y0 = 12.1, x1 = 11.9, y1 = 12.9 }
  local cb1 = Points.mark(Foot.candidates(Foot.tile_box(c0, 3), 4), { { rel = tb.new, box = belt.box, entity = belt, alt = { nextb } } })
  local cb2 = Points.mark(Foot.candidates(Foot.tile_box(c0, 3), 4), { { rel = tb.new, box = belt.box, entity = belt } })
  check(cb1[3].dx == 0.5 and cb1[3].dy == -0.5 and #cb1[3].moved == 0 and #cb2[3].moved == 1 and cb2[3].moved[1] == belt,
    "points servis : dépôt sur un convoyeur, la position qui le décale d'une tuile sur le convoyeur voisin reste servie ; sans ce voisin, non")
end
-- c. Moteur simulé : Levels.room sur une foreuse 6 tournée vers le SUD qui dépose dans un coffre, puis la même avec
--    la position qui garde le dépôt prise (arbre) : refus, le coffre est désigné comme point servi (« point: »), et le
--    panneau le dit (points-moved).
do
  local DR = L.by_key.drill
  for n = 1, DR.max do
    local pr = Wd.prototypes[L.name(DR, n)]
    local cbox = Foot.proto_boxes(L.footprint(DR, n))
    pr.collision_mask = MASK
    pr.collision_box = { left_top = { x = cbox[1][1], y = cbox[1][2] }, right_bottom = { x = cbox[2][1], y = cbox[2][2] } }
    pr.selection_box = { left_top = { x = -L.footprint(DR, n) / 2, y = -L.footprint(DR, n) / 2 },
      right_bottom = { x = L.footprint(DR, n) / 2, y = L.footprint(DR, n) / 2 } }
  end
  local function drill_south(x, y)
    local d = s.create_entity({ name = L.name(DR, 6), position = { x = x, y = y }, force = TF })
    rawset(d, "direction", defines.direction.south)
    rawset(d, "drop_position", { x = x, y = y + 1.85 })
    local chest = s.create_entity({ name = "iron-chest", position = { x = x, y = y + 2 }, force = TF })
    return d, chest
  end
  local d1, ch1 = drill_south(760.5, 500.5)
  local room = Levels.room(d1, 3, L.name(DR, 7), 4)
  local c = room.chosen
  local dropx, dropy = c and (c.x + 0.5), c and (c.y + 2.35)
  local cb = ch1.bounding_box
  check(c and c.dx == -0.5 and c.dy == -0.5 and room.index == 4 and #room.points == 1
    and dropx >= cb.left_top.x and dropx <= cb.right_bottom.x and dropy >= cb.left_top.y and dropy <= cb.right_bottom.y,
    "moteur simulé : foreuse 6 tournée vers le sud, coffre au dépôt : 3×3 → 4×4 au nord-ouest (rang 4), le dépôt (" .. tostring(dropx)
    .. " ; " .. tostring(dropy) .. ") reste dans le coffre")
  -- Arbre au nord-ouest (la position qui garde le dépôt) ; arbre au sud-est du coffre (les deux positions sud, qui
  -- recouvrent déjà le coffre, ont alors 2 gênes) : la plus facile à libérer est le nord-est (rang 3), libre
  -- d'entités, mais qui ferait déposer à côté du coffre.
  local d2 = drill_south(780.5, 500.5)
  s.create_entity({ name = "tree-01", position = { x = 778.5, y = 498.5 }, force = "neutral" })
  s.create_entity({ name = "tree-01", position = { x = 781.5, y = 502.5 }, force = "neutral" })
  local room2 = Levels.room(d2, 3, L.name(DR, 7), 4)
  local names = table.concat(Levels.blocker_names(room2.target), ",")
  check(room2.chosen == nil and room2.target_index == 3 and names == "point:iron-chest",
    "moteur simulé : la seule position qui garde le dépôt est prise (arbre) : refus « no-room » ; contour au nord-est, seule gêne : le coffre comme point servi (" .. names .. ")")
  local okp = pcall(function()
    rawset(player, "selected", nil)
    rawset(player, "selected", d2)
    M.dispatch(ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
  end)
  local tp = table.concat(texts(player.gui.left["fo_lvl_panel"]), "\n")
  check(okp and tp:find("fo-levels-taille.points-moved", 1, true) ~= nil,
    "panneau : ligne « point de sortie ou raccord » quand la position montrée déplacerait un point servi")
  for _, lang in ipairs({ "fr", "en" }) do
    local keys = {}
    cfg_keys("locale/" .. lang .. "/levels-taille.cfg", keys)
    check(keys["fo-levels-taille.points-moved"] and keys["fo-levels-taille.migration-kept"] and keys["fo-levels-taille.migration-stacked"]
      and keys["fo-levels-taille.regrid-line"], lang .. " : clés du lot V3-T2 (points-moved, migration-kept, migration-stacked, regrid-line)")
  end
end
rawset(player, "selected", nil)
rawset(player, "force", home)
local okt, errt = pcall(M.run_ticks, 60)
check(okt, "jeu continu après les agrandissements (panneau rafraîchi) (" .. tostring(errt) .. ")")
rendering.draw_rectangle = raw_rect
end)()

-- Lot V3-T3 : « libérer la place » (fichier à part : limite des 200 locales) : règle de décalage (cas purs), puis le
-- script en moteur simulé (après les sections qui posent les prototypes des niveaux).
local ClearCases = require("tests.levels_clear_cases")
ClearCases.pure(check, section)
ClearCases.runtime(check, section)

print(string.format("Écarts connus au contrat (non conformes, à trancher par le Directeur Créatif) : %d", #gaps))
print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
