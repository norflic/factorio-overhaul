--[[
  Tests hors jeu des NIVEAUX de bâtiments en 15 ÉPOQUES (session 5, lot V2) : règles pures, courbe de coûts
  et de durées par époque, table d'indirection des matériaux, chantiers en moteur simulé, panneau.
  Usage, depuis la racine du mod :
    lua5.2 tests/levels_test.lua            les tests
    lua5.2 tests/levels_test.lua --tables   les tableaux Markdown de BALANCE_SHEET §12, CALCULÉS sur la config
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
  laser = { max_health = 1000, damage_modifier = 2, range = 24, rotation_speed = 0.01 },
  wall = { max_health = 350, physical = 3, explosion = 10 },
  drill = { max_health = 300, mining_speed = 0.5, energy_usage = 90 },
  furnace = { max_health = 300, crafting_speed = 2, energy_usage = 90 },
  assembler = { max_health = 350, crafting_speed = 0.75, energy_usage = 150 },
}

local function stat_at(family, key, n)
  for _, st in ipairs(family.stats) do
    if st.path[#st.path] == key then return L.apply_stat(st, VANILLA[family.key][key], n) end
  end
  if family.resist_step and family.resist_step[key] then
    return VANILLA[family.key][key] + family.resist_step[key] * (n - 1)
  end
  return nil
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

local function model()
  local T = L.target
  local rows, cumul = {}, 0
  for e = 1, L.EPOCHS do
    local D = T.epoch_hours(e)
    cumul = cumul + D
    local budget = T.spend_share * T.production[e] * D * 3600
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
    rows[e] = { e = e, hours = D, cumul = cumul, production = T.production[e], budget = budget, spend = spend,
                ratio = spend / budget, work = work, capacity = capacity, wratio = work / capacity,
                cc_value = cc_value, cc_time = cc_time }
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
  p("| Époque | Thème | Matériau voulu | Objet en jeu aujourd'hui | Valeur unitaire (u) | Valeur d'époque (× époque 2) | Chantiers des bâtiments (× époque 1) | Chantier du centre payé dans l'époque (× 1 min) | Centre (niveau) | Niveaux des bâtiments | Ouvriers |")
  p("|---|---|---|---|---|---|---|---|---|---|---|")
  for e = 1, L.EPOCHS do
    local ep, m = L.epochs[e], L.epoch_materials[e]
    local want, item, value = "fer, cuivre, pierre (panier de base)", "panier de base", "—"
    if m then
      want = m.want
      item = "`" .. m.item .. "`" .. (m.provisional and (" **provisoire** (voulu : `" .. m.want_item .. "`)") or "")
      value = num(m.value)
    end
    p(string.format("| %d | %s | %s | %s | %s | %s | %s | %s | %d | %d-%d | %d |", e, EPOCH_NAMES[e], want, item, value,
      num(ep.value_mult), num(ep.time_mult), e < L.CC_MAX and num(ep.cc_time_mult) or "—", e, math.max(1, 2 * e - 1), 2 * e,
      L.builders(e)))
  end
  p("")
  p("#### Repères : niveau 1, niveau 10 (maximum de 0.3.0), dernier niveau, comparés au vanilla et au contenu du mod")
  p("")
  p("| Famille | Statistique | Niveau 1 | Niveau 10 | Dernier niveau | Repère |")
  p("|---|---|---|---|---|---|")
  local A = require("shared.content.arsenal")
  local heavy, walls = {}, {}
  for _, t in ipairs(A.turrets) do heavy[t.copy] = t end
  for _, w in ipairs(A.walls) do walls[w.name] = w end
  local refs = {
    { "command", "max_health", "—" },
    { "command", "inventory_size", "coffre en acier : 48 cases" },
    { "gun", "max_health", "tourelle lourde (mod) : " .. thousands(heavy["gun-turret"].hp) },
    { "gun", "damage_modifier", "tourelle lourde (mod) : " .. num(VANILLA.gun.damage_modifier * heavy["gun-turret"].damage_modifier) },
    { "gun", "range", "tourelle lourde (mod) : " .. num(heavy["gun-turret"].range) .. " ; ver géant : 48" },
    { "laser", "max_health", "tourelle laser lourde (mod) : " .. thousands(heavy["laser-turret"].hp) },
    { "laser", "damage_modifier", "tourelle laser lourde (mod) : " .. num(VANILLA.laser.damage_modifier * heavy["laser-turret"].damage_modifier) },
    { "laser", "range", "tourelle laser lourde (mod) : " .. num(heavy["laser-turret"].range) },
    { "wall", "max_health", "mur renforcé : " .. thousands(walls["fo-reinforced-wall"].hp) .. " ; mur blindé : " .. thousands(walls["fo-armored-wall"].hp) },
    { "wall", "physical", "mur blindé : 3 + 15 = 18 (et 50 %)" },
    { "drill", "mining_speed", "foreuse électrique vanilla : 0,5" },
    { "furnace", "crafting_speed", "four électrique vanilla : 2" },
    { "assembler", "crafting_speed", "machine d'assemblage 3 vanilla : 1,25" },
  }
  for _, r in ipairs(refs) do
    local f = L.by_key[r[1]]
    p(string.format("| %s | %s | %s | %s | %s (niveau %d) | %s |", FAMILY_NAMES[f.key], r[2], num(stat_at(f, r[2], 1), 3),
      num(stat_at(f, r[2], 10), 3), num(stat_at(f, r[2], f.max), 3), f.max, r[3]))
  end
  p("")
  p("#### Modèle de durée de jeu (hypothèses de `L.target`, à valider en partie réelle)")
  p("")
  p("| Époque | Durée visée | Cumul | Production (u/s) | Budget niveaux (u) | Dépense de la base de référence (u) | Dépense / budget | Temps d'ouvriers | Capacité des ouvriers | Charge des ouvriers | Chantier du centre suivant |")
  p("|---|---|---|---|---|---|---|---|---|---|---|")
  for _, r in ipairs(model()) do
    p(string.format("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |", r.e, duration(r.hours * 3600),
      duration(r.cumul * 3600), thousands(r.production), thousands(r.budget), thousands(r.spend), num(r.ratio),
      duration(r.work), duration(r.capacity), num(r.wratio), r.cc_time > 0 and (thousands(r.cc_value) .. " u, " .. duration(r.cc_time)) or "—"))
  end
  for _, f in ipairs(L.families) do
    p("")
    p("#### " .. FAMILY_NAMES[f.key] .. " (" .. f.max .. " niveaux)")
    p("")
    local ms, os_ = MAIN_STAT[f.key], OTHER_STAT[f.key]
    local head = "| Niveau | Époque | PV | " .. ms[2] .. (os_ and (" | " .. os_[2]) or "") .. " | Coût du passage à ce niveau | Valeur (u) | Durée |"
    p(head)
    p("|" .. string.rep("---|", os_ and 8 or 7))
    for n = 1, f.max do
      local e = L.epoch_of(f, n)
      local cost, value, time = "—", "—", "—"
      if n >= 2 then
        local c = L.cost(f, n)
        cost, value = cost_text(c), thousands(L.cost_value(c))
        time = duration(L.time_ticks(f, n, 1) / 60)
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
      p(row .. " | " .. cost .. " | " .. value .. " | " .. time .. " |")
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
    if L.epoch_materials[e - 1] and not f.main_share then
      check(have[L.epoch_materials[e - 1].item], f.key .. " N" .. n .. " : monnaie de l'époque " .. (e - 1) .. " exigée aussi")
    end
  end
  check(positive, f.key .. " : quantités entières et positives")
  check(strict_value, f.key .. " : valeur du coût strictement croissante")
  check(strict_time, f.key .. " : durée strictement croissante" .. (f.instant and " (murs : instantané)" or ""))
end
check(max_qty <= 1500, "pas d'explosion : au plus 1 500 objets d'une sorte par amélioration (" .. max_qty .. ")")
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
section("Table d'indirection « matériau d'époque → objet »")
---------------------------------------------------------------------------------------------------
-- Objets dont l'existence en 1.1.91 a été vérifiée par tests/datastage/harness.lua --dump-final (vanilla
-- et mod). Un objet absent de cette liste doit d'abord être vérifié, puis ajouté ici.
local W = require("shared.content.world")
local VERIFIED = {
  ["iron-plate"] = true, ["copper-plate"] = true, ["stone-brick"] = true, ["iron-gear-wheel"] = true,
  ["electronic-circuit"] = true, ["steel-plate"] = true, ["battery"] = true, ["engine-unit"] = true,
  ["plastic-bar"] = true, ["uranium-238"] = true, ["processing-unit"] = true, ["low-density-structure"] = true,
  ["electric-engine-unit"] = true, ["nuclear-fuel"] = true, ["rocket-control-unit"] = true,
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
check(rows[15].cumul >= 58 and rows[15].cumul <= 62, string.format("époque 15 atteinte vers 60 h cumulées (%.1f h)", rows[15].cumul))
for _, r in ipairs(rows) do
  check(r.ratio >= 0.5 and r.ratio <= 1.6, string.format("époque %d : dépense / budget = %.2f (entre 0,5 et 1,6)", r.e, r.ratio))
  check(r.wratio <= 1.1, string.format("époque %d : charge des ouvriers %.2f (≤ 1,1)", r.e, r.wratio))
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
    "fo-epochs.reason-unknown-item", "fo-levels.name", "fo-levels.level-up", "fo-levels.cc-line",
    "fo-levels.reason-cc-too-low", "fo-levels.maxed", "fo-levels.panel-title" }
  for e = 1, L.EPOCHS do
    need[#need + 1] = "fo-epochs.name-" .. L.epochs[e].key
    if L.epoch_materials[e] then need[#need + 1] = "fo-epochs.want-" .. L.epoch_materials[e].key end
  end
  for _, k in ipairs(need) do check(keys[k], lang .. " : clé " .. k) end
end

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
local function stock(inv, family, n, times)
  for _, c in ipairs(L.cost(family, n)) do inv.insert({ name = c[1], count = c[2] * (times or 1) }) end
end

local cc = s.create_entity({ name = "fo-command-center", position = { x = 0.5, y = 0.5 }, force = "player" })
built(cc)
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
stock(inv15, L.by_key.command, 15, 1)
r_ok, r_why = Levels.start(c15, nil)
check(r_ok and r_why == "started", "centre 14 → 15 : chantier lancé (monnaie de l'époque 14)")
M.run_ticks(L.time_ticks(L.by_key.command, 15, 1) + 31)
check(Levels.cc_level(f15) == 15, "centre niveau 15 (époque Légende)")
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
-- Panneau d'une foreuse niveau 22 (force au centre 15) : le niveau 23 se paie en monnaie PROVISOIRE de
-- l'époque 12, et le panneau le dit avec le matériau voulu.
rawset(player, "selected", nil)
local fp = s.create_entity({ name = L.name(L.by_key.drill, 22), position = { x = 130, y = 10 }, force = "fo-test-15" })
rawset(player, "selected", fp)
ok_panel = pcall(M.dispatch, ev[defines.events.on_selected_entity_changed], { player_index = 1, tick = game.tick })
all = table.concat(captions(player.gui.left["fo_lvl_panel"]), "\n")
check(ok_panel and all:find("fo%-epochs%.currency%-provisional") ~= nil and all:find("fo%-epochs%.want%-superconductor") ~= nil,
  "panneau : monnaie provisoire signalée avec le matériau voulu (époque 12)")

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
local ok_run, err_run = pcall(M.run_ticks, L.time_ticks(L.by_key.furnace, 25, 1) + 31)
check(ok_run, "jeu continu après rechargement (" .. tostring(err_run) .. ")")
local up = 0
for i = 1, 5 do if s.find_entity(L.name(L.by_key.furnace, 25), { x = 10 * i, y = 280 }) then up = up + 1 end end
check(up == 5 and Levels.busy(f13) == 0, "chantiers terminés après rechargement (" .. up .. " fours niveau 25)")

print(string.format("Résultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
