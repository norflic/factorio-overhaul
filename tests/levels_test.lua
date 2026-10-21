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
-- Modèle de durée de jeu (BALANCE_SHEET §12) : dépense de la base de référence et temps d'ouvriers par
-- époque, comparés au budget (production × part consacrée aux niveaux × durée visée).
---------------------------------------------------------------------------------------------------
local function epoch_levels(f, e)
  local out = {}
  for n = 2 * e - 1, 2 * e do if n >= 2 and n <= f.max then out[#out + 1] = n end end
  return out
end

--- prod_k : facteur sur la production supposée ; eff : efficacité des ouvriers (1 = jamais au repos).
local function model(prod_k, eff)
  prod_k, eff = prod_k or 1, eff or 1
  local T = L.target
  local rows, cumul, implied_cumul = {}, 0, 0
  for e = 1, L.EPOCHS do
    local D = T.epoch_hours(e)
    cumul = cumul + D
    local budget = T.spend_share * T.production[e] * prod_k * D * 3600
    local spend, work = 0, 0
    for _, f in ipairs(L.families) do
      if f.key ~= "command" then
        local N = T.base[f.key](e)
        local dN = N - (e > 1 and T.base[f.key](e - 1) or 0)
        for _, n in ipairs(epoch_levels(f, e)) do
          spend = spend + N * L.cost_value(L.cost(f, n))
          work = work + N * L.time_ticks(f, n, 1) / 60
        end
        -- Rattrapage : les bâtiments ajoutés pendant l'époque montent aussi les niveaux précédents.
        for n = 2, 2 * e - 2 do
          spend = spend + dN * L.cost_value(L.cost(f, n))
          work = work + dN * L.time_ticks(f, n, 1) / 60
        end
      end
    end
    local cc = L.by_key.command
    local cc_value, cc_time = 0, 0
    if e < L.CC_MAX then
      cc_value = L.cost_value(L.cost(cc, e + 1))
      cc_time = L.time_ticks(cc, e + 1, 1) / 60
    end
    spend, work = spend + cc_value, work + cc_time
    local capacity = L.builders(e) * D * 3600
    -- Durée IMPLIQUÉE : le plus long de « payer la dépense avec la part de production consacrée aux
    -- niveaux » et « faire les chantiers avec les ouvriers disponibles » (efficacité eff).
    local implied = math.max(spend / (T.spend_share * T.production[e] * prod_k * 3600), work / (L.builders(e) * eff * 3600))
    implied_cumul = implied_cumul + implied
    rows[e] = { e = e, hours = D, cumul = cumul, production = T.production[e], budget = budget, spend = spend,
                ratio = spend / budget, work = work, capacity = capacity, wratio = work / capacity,
                cc_value = cc_value, cc_time = cc_time, implied = implied, implied_cumul = implied_cumul }
  end
  return rows
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
  p("| Époque | Thème | Matériau voulu | Objet en jeu aujourd'hui | Valeur unitaire (u) | Pile | Valeur d'époque (× époque 2) | Chantiers des bâtiments (× époque 1) | Chantier du centre payé dans l'époque (× 1 min) | Centre (niveau) | Niveaux des bâtiments | Ouvriers |")
  p("|---|---|---|---|---|---|---|---|---|---|---|---|")
  for e = 1, L.EPOCHS do
    local ep, m = L.epochs[e], L.epoch_materials[e]
    local want, item, value, stack = "fer, cuivre, pierre (panier de base)", "panier de base", "—", "—"
    if m then
      want = m.want
      item = "`" .. m.item .. "`" .. (m.provisional and (" **provisoire** (voulu : `" .. m.want_item .. "`)") or "")
      value = num(m.value)
      stack = thousands(L.stack_size[m.item])
    end
    p(string.format("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %d | %d-%d | %d |", e, EPOCH_NAMES[e], want, item, value,
      stack, num(ep.value_mult), num(ep.time_mult), e < L.CC_MAX and num(ep.cc_time_mult) or "—", e, math.max(1, 2 * e - 1), 2 * e,
      L.builders(e)))
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
  p("#### Modèle de durée de jeu (hypothèses de `L.target`, à valider en partie réelle)")
  p("")
  p("| Époque | Durée visée | Cumul visé | Production (u/s) | Budget niveaux (u) | Dépense de la base de référence (u) | Dépense / budget | Temps d'ouvriers | Capacité des ouvriers | Charge des ouvriers | Durée impliquée | Cumul impliqué | Chantier du centre suivant |")
  p("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
  for _, r in ipairs(model()) do
    p(string.format("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |", r.e, duration(r.hours * 3600),
      duration(r.cumul * 3600), thousands(r.production), thousands(r.budget), thousands(r.spend), num(r.ratio),
      duration(r.work), duration(r.capacity), num(r.wratio), duration(r.implied * 3600), duration(r.implied_cumul * 3600),
      r.cc_time > 0 and (thousands(r.cc_value) .. " u, " .. duration(r.cc_time)) or "—"))
  end
  p("")
  p("#### Sensibilité de la durée impliquée totale (15 époques)")
  p("")
  p("| Production supposée | Ouvriers jamais au repos | Ouvriers occupés à 75 % | Ouvriers occupés à 50 % |")
  p("|---|---|---|---|")
  for _, k in ipairs({ 0.7, 1, 1.3 }) do
    local cells = {}
    for _, eff in ipairs({ 1, 0.75, 0.5 }) do cells[#cells + 1] = duration(model(k, eff)[L.EPOCHS].implied_cumul * 3600) end
    p(string.format("| × %s | %s |", num(k), table.concat(cells, " | ")))
  end
  local cc_v, cc_t = 0, 0
  for n = 2, L.CC_MAX do
    cc_v = cc_v + L.cost_value(L.cost(L.by_key.command, n))
    cc_t = cc_t + L.time_ticks(L.by_key.command, n, 1) / 60
  end
  local spent = 0
  for _, r in ipairs(model()) do spent = spent + r.spend end
  p("")
  p(string.format("Chemin « centre seul » (centre 1 → 15, rien d'autre) : %s u et %s de chantiers, soit %s %% de la dépense de la base de référence.",
    thousands(cc_v), duration(cc_t), num(100 * cc_v / spent, 1)))
  for _, f in ipairs(L.families) do
    p("")
    p("#### " .. FAMILY_NAMES[f.key] .. " (" .. f.max .. " niveaux)")
    p("")
    local ms, os_ = MAIN_STAT[f.key], OTHER_STAT[f.key]
    local head = "| Niveau | Époque | PV | " .. ms[2] .. (os_ and (" | " .. os_[2]) or "") .. " | Coût du passage à ce niveau | Valeur (u) | Durée | Cases / coffre du centre payeur |"
    p(head)
    p("|" .. string.rep("---|", os_ and 9 or 8))
    for n = 1, f.max do
      local e = L.epoch_of(f, n)
      local cost, value, time, slots = "—", "—", "—", "—"
      if n >= 2 then
        local c = L.cost(f, n)
        cost, value = cost_text(c), thousands(L.cost_value(c))
        time = duration(L.time_ticks(f, n, 1) / 60)
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
      p(row .. " | " .. cost .. " | " .. value .. " | " .. time .. " | " .. slots .. " |")
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
-- Ouvriers : 1 (1-3), 2 (4-6), 3 (7-9), 4 (10-12), 5 (13-15).
local BUILDERS = { 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5 }
for cc = 1, 15 do check(L.builders(cc) == BUILDERS[cc], "ouvriers au centre " .. cc .. " : " .. BUILDERS[cc]) end
check(L.builders(0) == 0, "sans centre : aucun ouvrier")
local ok, why = L.check(G, 2, 0, 0)
check(not ok and why == "no-cc", "refus sans centre")
ok, why = L.check(G, 3, 1, 0)
check(not ok and why == "cc-too-low", "refus : niveau 3 avec un centre 1")
ok = L.check(G, 4, 2, 0)
check(ok, "niveau 4 autorisé avec un centre 2")
ok, why = L.check(G, 2, 1, 1)
check(not ok and why == "no-builder", "refus : ouvrier occupé")
ok, why = L.check(G, 31, 15, 0)
check(not ok and why == "max", "refus au-delà du niveau 30")
ok = L.check(L.by_key.wall, 2, 1, 5)
check(ok, "les murs n'ont pas besoin d'ouvrier")

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
section("Courbe de coûts et de durées par époque")
---------------------------------------------------------------------------------------------------
local max_qty, max_items = 0, 0
for _, f in ipairs(L.families) do
  local prev_value, prev_time = -1, -1
  local strict_value, strict_time, positive = true, true, true
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
    local t = L.time_ticks(f, n, 1)
    if f.instant then
      if t ~= 0 then strict_time = false end
    elseif not (t > prev_time) then
      strict_time = false; print("    " .. f.key .. " N" .. n .. " : durée " .. t .. " <= " .. prev_time)
    end
    prev_time = t
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
  check(strict_time, f.key .. " : durée strictement croissante" .. (f.instant and " (murs : instantané)" or ""))
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
-- Les tables par époque sont croissantes.
for e = 2, L.EPOCHS do
  local a, b = L.epochs[e - 1], L.epochs[e]
  check(b.value_mult > a.value_mult and b.time_mult > a.time_mult * L.SECOND_LEVEL_TIME_FACTOR
    and b.cc_time_mult >= a.cc_time_mult, "époque " .. e .. " : multiplicateurs croissants")
end
-- Durées : le centre de 1 min à 1 h ; la mitrailleuse de 10 s à moins de 4 min.
check(L.time_ticks(L.by_key.command, 2, 1) == 60 * 60 and L.time_ticks(L.by_key.command, 15, 1) == 3600 * 60,
  "centre : chantier de 1 min (niveau 2) à 1 h (niveau 15)")
check(L.time_ticks(G, 2, 1) == math.floor(8 * 1.1 * 60 + 0.5) and L.time_ticks(G, 30, 1) <= 4 * 3600,
  "mitrailleuse : 8,8 s au niveau 2, moins de 4 min au niveau 30")
check(L.time_ticks(G, 3, 0) == 0 and L.time_ticks(G, 3, 0.5) * 2 == L.time_ticks(G, 3, 1), "réglage fo-level-time-factor appliqué")

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
section("Durée de jeu visée (modèle de BALANCE_SHEET §12)")
---------------------------------------------------------------------------------------------------
local rows = model()
check(math.abs(rows[1].hours - 0.5) < 1e-9, "époque 1 visée en 30 min")
check(rows[15].cumul >= 58 and rows[15].cumul <= 62, string.format("époque 15 visée vers 60 h cumulées (%.1f h)", rows[15].cumul))
-- La durée IMPLIQUÉE par la courbe (pas la durée visée, qui est une entrée) : chaque époque à ± 25 % de
-- sa cible, le total à 60 h ± 10 %, et des ouvriers occupés au plus à 70 % tant que la file de chantiers
-- (E3-4) n'existe pas.
for _, r in ipairs(rows) do
  check(r.implied >= 0.75 * r.hours and r.implied <= 1.25 * r.hours,
    string.format("époque %d : durée impliquée %.2f h pour %.2f h visées (± 25 %%)", r.e, r.implied, r.hours))
  check(r.wratio <= 0.7, string.format("époque %d : charge des ouvriers %.2f (≤ 0,7)", r.e, r.wratio))
end
check(rows[15].implied_cumul >= 54 and rows[15].implied_cumul <= 66,
  string.format("durée impliquée totale %.1f h (60 h ± 10 %%)", rows[15].implied_cumul))
local half = model(1, 0.5)[L.EPOCHS].implied_cumul
print(string.format("  Durée impliquée totale : %.1f h (ouvriers jamais au repos), %.1f h (75 %%), %.1f h (50 %%) ; production × 0,7 : %.1f h, × 1,3 : %.1f h",
  rows[15].implied_cumul, model(1, 0.75)[L.EPOCHS].implied_cumul, half, model(0.7, 1)[L.EPOCHS].implied_cumul,
  model(1.3, 1)[L.EPOCHS].implied_cumul))

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
    "fo-epochs.reason-unknown-item", "fo-levels.name", "fo-levels.level-up", "fo-levels.cc-line",
    "fo-levels.reason-cc-too-low", "fo-levels.maxed", "fo-levels.panel-title", "fo-epochs.desc-cc",
    "fo-epochs.stat-energy_consumption", "fo-epochs.visual" }
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
  { G, fake_gun, function(p, ctx) ctx.L.target.production[3] = 1 end, { SHARED_MOTIF, "L.target.production[3]" }, "hypothèses du modèle (L.target)" },
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
section("Chantiers en moteur simulé")
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
-- le moteur réel : un chantier qui ne tient pas dans le coffre n'est plus validé par erreur. C'est une
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
-- Correction V2b (contre-vérification V2) : seul le coffre du centre POSÉ était borné ; après un chantier du
-- centre, la nouvelle entité avait un coffre ILLIMITÉ, et les contrôles de place suivants ne prouvaient rien.
-- La limite est rebranchée sur chaque centre remplacé par le crochet Levels.on_replaced (enregistré ici, hors
-- événement, et de nouveau après le rechargement plus bas).
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
local r_ok, r_why = Levels.start(gun, nil)
check(not r_ok and r_why == "no-resources", "refus faute de ressources")
local chest = cc.get_inventory(defines.inventory.chest)
stock(chest, G, 2, 2)
r_ok, r_why = Levels.start(gun, nil)
check(r_ok and r_why == "started", "chantier lancé (payé par le centre)")
check(gun.active == false, "bâtiment hors service pendant le chantier")
check(Levels.busy(force) == 1, "un ouvrier occupé")
check(chest.get_item_count("iron-plate") == L.cost(G, 2)[1][2], "coût prélevé dans le centre")
local gun_b = s.create_entity({ name = "gun-turret", position = { x = 14, y = 10 }, force = "player" })
r_ok, r_why = Levels.start(gun_b, nil)
check(not r_ok and r_why == "no-builder", "second chantier refusé (1 ouvrier au centre niveau 1)")
M.run_ticks(L.time_ticks(G, 2, 1) + 31)
check(not gun.valid, "ancienne tourelle remplacée")
local g2 = s.find_entity("fo-lvl-gun-2", { x = 10, y = 10 })
check(g2 ~= nil, "tourelle niveau 2 posée au même endroit")
check(g2 and g2.get_inventory(defines.inventory.turret_ammo).get_item_count("firearm-magazine") == 25, "munitions conservées")
check(g2 and math.abs(g2.get_health_ratio() - 0.5) < 1e-6, "santé conservée en proportion (50 %)")
check(g2 and g2.active ~= false, "tourelle niveau 2 en service")
check(Levels.busy(force) == 0, "ouvrier libéré")
check((Wd.lights or 0) >= 1 and (Wd.flying or 0) >= 1, "célébration (lumière, texte)")

-- Plafond : niveau 3 (époque 2) interdit avec un centre niveau 1, autorisé après l'amélioration du centre.
stock(chest, G, 3, 1)
r_ok, r_why = Levels.start(g2, nil)
check(not r_ok and r_why == "cc-too-low", "tourelle niveau 3 refusée : centre niveau 1 (plafond 2)")
local info = Levels.preview(g2, nil)
check(info and info.required_cc == 2, "aperçu : centre niveau 2 requis")
stock(chest, L.by_key.command, 2, 1)
r_ok, r_why = Levels.start(cc, nil)
check(r_ok and r_why == "started", "chantier du centre lancé")
M.run_ticks(L.time_ticks(L.by_key.command, 2, 1) + 31)
check(Levels.cc_level(force) == 2 and Levels.cc(force).name == "fo-lvl-command-2", "centre niveau 2 (toujours enregistré après remplacement)")
local bounded, got_fuel, free_slots, cap_slots = chest_bounded(Levels.cc(force))
check(bounded and cap_slots == 64, string.format("coffre du centre 2 REMPLACÉ borné à ses %d cases : %d combustibles nucléaires entrés pour %d cases libres",
  cap_slots, got_fuel, free_slots))
check(Levels.cc(force).get_inventory(defines.inventory.chest).get_item_count("iron-plate") > 0, "le stock du centre a suivi le remplacement")
r_ok, r_why = Levels.start(g2, nil)
check(r_ok and r_why == "started", "tourelle niveau 3 autorisée avec un centre niveau 2")

-- Démontage pendant le chantier : moitié du coût rendue.
local buffer = M.new_inventory()
ev[defines.events.on_player_mined_entity]({ entity = g2, buffer = buffer, player_index = 1, tick = game.tick })
check(Levels.busy(force) == 0, "chantier annulé au démontage")
check(buffer.get_item_count("iron-plate") == math.floor(L.cost(G, 3)[1][2] / 2), "moitié du coût rendue")

-- Murs : instantanés, rangée entière.
local walls = {}
for i = 0, 5 do
  walls[#walls + 1] = s.create_entity({ name = "stone-wall", position = { x = 30 + i, y = 5 }, force = "player" })
end
local cinv = Levels.cc(force).get_inventory(defines.inventory.chest)
stock(cinv, L.by_key.wall, 2, 6)
local done = Levels.start_row(walls[3], nil)
check(done == 6, "rangée de 6 murs améliorée d'un coup (" .. tostring(done) .. ")")
check(s.find_entity("fo-lvl-wall-2", { x = 30, y = 5 }) ~= nil and s.find_entity("stone-wall", { x = 35, y = 5 }) == nil, "murs niveau 2 posés")
check(Levels.busy(force) == 0, "les murs n'occupent pas d'ouvrier")

-- Destruction pendant le chantier : chantier perdu, ouvrier libéré.
local drill = s.create_entity({ name = "electric-mining-drill", position = { x = 50, y = 50 }, force = "player" })
stock(cinv, L.by_key.drill, 2, 1)
r_ok = Levels.start(drill, nil)
check(r_ok and Levels.busy(force) == 1, "chantier de foreuse lancé")
drill.die("enemy")
M.run_ticks(31)
check(Levels.busy(force) == 0, "foreuse détruite : chantier perdu, ouvrier libéré")

---------------------------------------------------------------------------------------------------
section("Hautes époques : ouvriers, plafond, niveau 30, centre 15")
---------------------------------------------------------------------------------------------------
local function new_force_with_cc(name, cc_level, x)
  game.create_force(name)
  local c = s.create_entity({ name = L.name(L.by_key.command, cc_level), position = { x = x, y = 200.5 }, force = name })
  built(c)
  limit_chest(c)
  return game.forces[name], c
end
-- Centre 4 : 2 ouvriers ; un 3e chantier est refusé.
local f4, c4 = new_force_with_cc("fo-test-4", 4, 0.5)
check(Levels.cc_level(f4) == 4, "centre niveau 4 posé directement (époque 4)")
local inv4 = c4.get_inventory(defines.inventory.chest)
local machines = {}
for i = 1, 3 do
  machines[i] = s.create_entity({ name = L.name(L.by_key.assembler, 7), position = { x = 10 * i, y = 220 }, force = "fo-test-4" })
end
stock(inv4, L.by_key.assembler, 8, 3)
check(Levels.start(machines[1], nil) and Levels.start(machines[2], nil), "centre 4 : deux chantiers simultanés")
r_ok, r_why = Levels.start(machines[3], nil)
check(not r_ok and r_why == "no-builder", "centre 4 : le 3e chantier attend (2 ouvriers)")
local am9 = s.create_entity({ name = L.name(L.by_key.assembler, 8), position = { x = 60, y = 220 }, force = "fo-test-4" })
info = Levels.preview(am9, nil)
check(info and not info.ok and info.reason == "cc-too-low" and info.required_cc == 5, "centre 4 : niveau 9 refusé (centre 5 requis)")
M.run_ticks(L.time_ticks(L.by_key.assembler, 8, 1) + 31)
check(s.find_entity(L.name(L.by_key.assembler, 8), { x = 10, y = 220 }) ~= nil and Levels.busy(f4) == 0,
  "centre 4 : machines niveau 8 livrées, ouvriers libérés")

-- Centre 13 : 5 ouvriers.
local f13, c13 = new_force_with_cc("fo-test-13", 13, 40.5)
check(L.builders(Levels.cc_level(f13)) == 5, "centre 13 : 5 ouvriers")
local inv13 = c13.get_inventory(defines.inventory.chest)
local drills = {}
for i = 1, 6 do
  drills[i] = s.create_entity({ name = L.name(L.by_key.drill, 25), position = { x = 10 * i, y = 240 }, force = "fo-test-13" })
end
stock(inv13, L.by_key.drill, 26, 6)
local started = 0
for i = 1, 6 do if Levels.start(drills[i], nil) then started = started + 1 end end
check(started == 5 and Levels.busy(f13) == 5, "centre 13 : 5 chantiers simultanés, le 6e attend (" .. started .. ")")

-- Centre 15 : niveau 29 → 30, puis plus rien ; centre 14 → 15, puis plus rien.
local f15, c15 = new_force_with_cc("fo-test-15", 14, 80.5)
local inv15 = c15.get_inventory(defines.inventory.chest)
check(inv15.insert({ name = "nuclear-fuel", count = 310 }) == 256 and inv15.remove({ name = "nuclear-fuel", count = 310 }) == 256,
  "enveloppe du moteur simulé (démonstration du coffre borné, pas une propriété de la config) : 310 combustibles nucléaires (pile de 1) versés dans le centre 14, 256 entrent ; l'ancien coût du centre 15 n'y tenait pas")
check(stock(inv15, L.by_key.command, 15, 1), "centre 14 → 15 : tout le coût tient dans le coffre du centre 14 (cases réelles)")
r_ok, r_why = Levels.start(c15, nil)
check(r_ok and r_why == "started", "centre 14 → 15 : chantier lancé (monnaie de l'époque 14)")
M.run_ticks(L.time_ticks(L.by_key.command, 15, 1) + 31)
check(Levels.cc_level(f15) == 15, "centre niveau 15 (époque Légende)")
bounded, got_fuel, free_slots, cap_slots = chest_bounded(Levels.cc(f15))
check(bounded and cap_slots == 272, string.format("coffre du centre 15 REMPLACÉ borné à ses %d cases : %d combustibles nucléaires entrés pour %d cases libres",
  cap_slots, got_fuel, free_slots))
local top = Levels.cc(f15)
info = Levels.preview(top, nil)
check(info and not info.ok and info.reason == "max", "centre 15 : niveau maximal")
local g29 = s.create_entity({ name = L.name(G, 29), position = { x = 90, y = 260 }, force = "fo-test-15" })
g29.insert({ name = "uranium-rounds-magazine", count = 10 })
stock(top.get_inventory(defines.inventory.chest), G, 30, 1)
r_ok, r_why = Levels.start(g29, nil)
check(r_ok and r_why == "started", "mitrailleuse 29 → 30 lancée avec un centre 15")
M.run_ticks(L.time_ticks(G, 30, 1) + 31)
local g30 = s.find_entity(L.name(G, 30), { x = 90, y = 260 })
check(g30 ~= nil and g30.get_inventory(defines.inventory.turret_ammo).get_item_count("uranium-rounds-magazine") == 10,
  "mitrailleuse niveau 30, munitions conservées")
info = g30 and Levels.preview(g30, nil)
check(info and not info.ok and info.reason == "max", "mitrailleuse 30 : niveau maximal")
local st = global.fo.levels.stats
check((st.fallback or 0) == 0, "remplacement rapide partout (aucun secours manuel)")

---------------------------------------------------------------------------------------------------
section("Panneau « Évolution » (moteur simulé)")
---------------------------------------------------------------------------------------------------
-- Interface graphique simulée un peu plus riche que celle du moteur simulé (clear, style).
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
ok_panel, err_panel = pcall(M.run_ticks, 60)
check(ok_panel, "panneau rafraîchi pendant le jeu sans erreur (" .. tostring(err_panel) .. ")")
-- Touche U sur une tourelle niveau 2 avec un centre niveau 2 : chantier lancé.
local gu = s.create_entity({ name = L.name(G, 2), position = { x = 124, y = 10 }, force = "player" })
stock(Levels.cc(force).get_inventory(defines.inventory.chest), G, 3, 1)
rawset(player, "selected", gu)
ok_panel, err_panel = pcall(M.dispatch, ev["fo-level-up"], { player_index = 1, tick = game.tick })
check(ok_panel and global.fo.levels.jobs[gu.unit_number] ~= nil, "touche U : chantier lancé (" .. tostring(err_panel) .. ")")
-- Plafond affiché par le panneau du centre : 2 × son niveau (et non le maximum du centre, 15).
local function hover(entity)
  rawset(player, "selected", nil)
  rawset(player, "selected", entity)
  local okh = pcall(M.dispatch, ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
  local fr = player.gui.left["fo_lvl_panel"]
  return okh, fr and table.concat(captions(fr), "\n") or ""
end
local okc, txt = hover(Levels.cc(force))
check(okc and txt:find("{fo-levels.cc-line:2,4,1}", 1, true) ~= nil, "panneau du centre 2 : bâtiments jusqu'au niveau 4")
local f3, c3 = new_force_with_cc("fo-test-3", 3, 160.5)
local home = player.force
rawset(player, "force", f3)
okc, txt = hover(c3)
check(okc and txt:find("{fo-levels.cc-line:3,6,1}", 1, true) ~= nil, "panneau du centre 3 : bâtiments jusqu'au niveau 6 (et non 15)")
rawset(player, "force", f15)
okc, txt = hover(Levels.cc(f15))
check(okc and txt:find("{fo-levels.cc-line:15,30,5}", 1, true) ~= nil, "panneau du centre 15 : bâtiments jusqu'au niveau 30, 5 ouvriers")
-- Panneau d'une foreuse niveau 22 (force au centre 15) : le niveau 23 se paie en monnaie PROVISOIRE de
-- l'époque 12, et le panneau le dit avec le matériau voulu.
local fp = s.create_entity({ name = L.name(L.by_key.drill, 22), position = { x = 130, y = 10 }, force = "fo-test-15" })
ok_panel, all = hover(fp)
check(ok_panel and all:find("fo%-epochs%.currency%-provisional") ~= nil and all:find("fo%-epochs%.want%-superconductor") ~= nil,
  "panneau : monnaie provisoire signalée avec le matériau voulu (époque 12)")
rawset(player, "force", home)

-- Autre force : ni panneau, ni chantier, ni paiement par le centre adverse (survol, touche U, bouton).
local frv, crv = new_force_with_cc("fo-rival", 2, 200.5)
local rinv = crv.get_inventory(defines.inventory.chest)
stock(rinv, G, 2, 1)
local iron0 = rinv.get_item_count("iron-plate")
local rg = s.create_entity({ name = "gun-turret", position = { x = 210, y = 10 }, force = "fo-rival" })
hover(rg)
check(global.fo.levels_ui.target[1] ~= rg, "autre force : le survol n'ouvre pas son panneau")
rawset(player, "selected", rg)
pcall(M.dispatch, ev["fo-level-up"], { player_index = 1, tick = game.tick })
check(global.fo.levels.jobs[rg.unit_number] == nil and rinv.get_item_count("iron-plate") == iron0,
  "autre force : la touche U ne lance rien et ne vide pas son centre")
global.fo.levels_ui.target[1] = rg
global.fo.levels_ui.unit[1] = rg.unit_number
pcall(M.dispatch, ev[defines.events.on_gui_click], { element = { valid = true, name = "fo_lvl_up" }, player_index = 1, tick = game.tick })
check(global.fo.levels.jobs[rg.unit_number] == nil and rinv.get_item_count("iron-plate") == iron0
  and global.fo.levels_ui.target[1] == nil, "autre force : le bouton « Améliorer » ne lance rien (panneau fermé)")
rawset(player, "selected", nil)

---------------------------------------------------------------------------------------------------
section("Sauvegarde et rechargement avec chantiers en cours")
---------------------------------------------------------------------------------------------------
-- Force « centre 13 » (plafond 26) : 5 fours niveau 24, 5 chantiers vers le 25.
stock(inv13, L.by_key.furnace, 25, 5)
local relaunched = 0
for i = 1, 5 do
  local fu = s.create_entity({ name = L.name(L.by_key.furnace, 24), position = { x = 10 * i, y = 280 }, force = "fo-test-13" })
  if Levels.start(fu, nil) then relaunched = relaunched + 1 end
end
check(relaunched == 5 and Levels.busy(f13) == 5, "5 chantiers en cours avant la sauvegarde (" .. relaunched .. ")")
local ok_ser, err_ser = pcall(M.serialize, global)
check(ok_ser, "global sérialisable (" .. tostring(err_ser) .. ")")
local saved = M.deepcopy_global(global)
M.load_mod()
_G.global = saved
local ok_load, err_load = pcall(function() Wd.on_load() end)
check(ok_load, "on_load sans erreur (" .. tostring(err_load) .. ")")
Levels = require("script.levels.levels")
table.insert(Levels.on_replaced, limit_replaced_centre)
local ok_run, err_run = pcall(M.run_ticks, L.time_ticks(L.by_key.furnace, 25, 1) + 31)
check(ok_run, "jeu continu après rechargement (" .. tostring(err_run) .. ")")
local up = 0
for i = 1, 5 do if s.find_entity(L.name(L.by_key.furnace, 25), { x = 10 * i, y = 280 }) then up = up + 1 end end
check(up == 5 and Levels.busy(f13) == 0, "chantiers terminés après rechargement (" .. up .. " fours niveau 25)")

print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
