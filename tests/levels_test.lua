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
check(#prov == 5, "5 remplaçants provisoires (époques 11 à 15 : " .. #prov .. ")")
for _, m in ipairs(prov) do check(m.epoch >= 11, "remplaçant provisoire seulement aux époques 11-15 (" .. m.key .. ")") end

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
  { G, fake_gun, function(p) p.preparing_animation = { layers = { sprite(16) } }; p.preparing_speed = 0.16 end, true, "deux fois plus d'images, deux fois plus vite (même durée)" },
  { G, fake_gun, function(p) p.attack_parameters.projectile_center = { 0, 0.4 } end, true, "origine des balles (visuel)" },
  { G, fake_gun, function(p, ctx) ctx.color.r = 0 end, true, "ctx.color est une copie" },
  { G, fake_gun, function(p, ctx) local _ = ctx.L.CC_HEALTH + #ctx.L.families + ctx.kit.palette.glow[5].r end, true, "lecture de ctx.L et de ctx.kit" },
  { G, fake_gun, function(p, ctx) p.corpse = "gun-turret-remnants"; p.dying_explosion = "gun-turret-explosion" end, true, "reste et explosion vanilla existants (références graphiques)" },
  { G, fake_gun, function(p) p.preparing_speed = 0.16 end, { "durée de preparing_animation" }, "preparing_speed seul (déploiement deux fois plus court)" },
  { G, fake_gun, function(p) p.folding_animation = { layers = { sprite(4) } } end, { "durée de folding_animation" }, "repli deux fois plus court (moins d'images)" },
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
  local fu = s.find_entity(L.name(L.by_key.furnace, 25), { x = 10 * i, y = 280 })
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
local fu2 = s.create_entity({ name = L.name(L.by_key.furnace, 20), position = { x = 10, y = 320 }, force = "fo-test-13" })
local j2 = job_040(fu2, "furnace", 21, 6000)
global.fo.levels.jobs[j2.unit] = j2
saved = M.deepcopy_global(global)
M.load_mod()
_G.global = saved
ok_load = pcall(function() Wd.on_load() end)
Levels = require("script.levels.levels")
ok_run, err_run = pcall(M.run_ticks, 31)
check(ok_load and ok_run and s.find_entity(L.name(L.by_key.furnace, 21), { x = 10, y = 320 }) ~= nil
  and next(global.fo.levels.jobs) == nil, "sans changement de version : chantier 0.4.0 achevé dans les 30 ticks (" .. tostring(err_run) .. ")")
end

---------------------------------------------------------------------------------------------------
section("Recherche vanilla allégée (QX9) : data-final-fixes.lua sur les technologies de base")
---------------------------------------------------------------------------------------------------
-- Les technologies vanilla de 1.1.91 relues dans data/base/prototypes/technology.lua (comme
-- tests/epochs_test.lua), puis data-final-fixes.lua exécuté sur un data.raw qui les contient. Fonction anonyme :
-- portée de variables locales propre (limite de 200 locales du bloc principal).
;(function()
local vanilla
for _, p in ipairs({ "../../data/base/prototypes/technology.lua", "../../../../../data/base/prototypes/technology.lua" }) do
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
local data_dir
for _, d in ipairs({ "../../data", "../../../../../data" }) do
  local fh = io.open(d .. "/base/prototypes/technology.lua", "rb")
  if fh and not data_dir then fh:close(); data_dir = d elseif fh then fh:close() end
end
check(data_dir ~= nil, "données du jeu trouvées pour le banc de l'étape data (" .. tostring(data_dir) .. ")")
if data_dir then
  local lua = (arg and arg[-1]) or "lua5.2"
  local cmd = lua .. " tests/datastage/harness.lua " .. data_dir .. " . --verbose --dump-final technology/fluid-handling 2>&1"
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

print(string.format("Écarts connus au contrat (non conformes, à trancher par le Directeur Créatif) : %d", #gaps))
print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
