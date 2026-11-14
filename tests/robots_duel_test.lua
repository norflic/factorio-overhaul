--[[
  Lot RB-4 GAMME (1/11) : banc hors jeu du MODÈLE DE DUEL (shared/robots/duel.lua) et du CALIBRAGE de la gamme de 12 robots
  (shared/content/robots.lua). PLAN fo-logs/2026-10-31_ROBOTS §2 : « PV et DPS à recaler par le banc de duel et par le modèle, pas à la
  main ».
    §1 règle de résistance du moteur ; §2 déchiqueteurs des 12 paliers (vanilla 1 à 4, × 1 100 au palier 12, familles) ;
    §3 palier de l'âge (fenêtre d'évolution et courbes d'apparition) ; §4 le duel (tir, zone, portée minimale, soin, déterminisme) ;
    §5 le CALIBRAGE : les chiffres écrits dans shared/content/robots.lua SONT ceux que le modèle calcule (aucun chiffre à la main), et
       chaque robot gagne son duel contre 3 déchiqueteurs du palier de son âge, avec la marge visée ;
    §6 la gamme : portée de palier croissante, aucun robot inutile ; §7 mutants du modèle.
  Usage : lua5.2 tests/robots_duel_test.lua            (contrôles)
          lua5.2 tests/robots_duel_test.lua --calibrer (imprime la table calibrée, à recopier dans shared/content/robots.lua)
          lua5.2 tests/robots_duel_test.lua --tables   (marges par palier, pour BALANCE_SHEET)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local DU_SRC = read("shared/robots/duel.lua")
local function load_duel(src)
  local f, e = load(src, "=duel", "t")
  if not f then return nil, e end
  local ok, D = pcall(f)
  if not ok then return nil, D end
  return D
end

local Ro = require("shared.content.robots")
local E = require("shared.content.enemies")
local Ech = require("shared.robots.echelle")

local function suite(D)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end
  local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) * math.max(1, math.abs(b)) end

  -- §1 Résistance.
  local res = { physical = { 12, 0.10 } }
  check(near(D.after_resist(100, "physical", res), 79.2), "§1 retrait fixe puis pourcentage : (100 − 12) × 0,9")
  check(D.after_resist(100, "laser", res) == 100 and D.after_resist(100, "physical", nil) == 100, "§1 un type sans résistance passe entier")
  check(near(D.after_resist(5, "physical", res), (1 / (2 + 7)) * 0.9), "§1 sous 1 de dégâts : 1 / (2 − x), puis le pourcentage")
  check(near(D.after_resist(13, "physical", res), 1 * 0.9), "§1 un dégât restant à exactement 1 vaut 1")
  check(D.after_resist(12, "physical", res) < 1 and D.after_resist(12, "physical", res) > 0, "§1 le retrait fixe ne ramène jamais à 0")

  -- §2 Déchiqueteurs.
  local b1, b4, b12 = D.biter(1), D.biter(4), D.biter(12)
  check(b1.hp == 15 and b1.dmg == 7 and b1.speed == 0.2, "§2 palier 1 : petit déchiqueteur vanilla (15 PV, 7 dégâts)")
  check(D.biter(2).hp == 75 and D.biter(3).hp == 375 and b4.hp == 3000 and b4.dmg == 90 and b4.cd == 50 and near(b4.speed, 0.3),
    "§2 paliers 2 à 4 : moyen, gros, béhémoth vanilla")
  check(b12.hp == 3000 * 1100 and b12.dmg == 90 * 90 and near(b12.speed, 0.3 * 0.79), "§2 palier 12 : PV × 1 100, dégâts × 90, vitesse × 0,79")
  check(b12.res.physical[1] == 12 + 64 and near(b12.res.physical[2], 0.74) and b12.res.explosion[1] == 76 and near(b12.res.acid[2], 0.64)
    and b12.res.laser == nil and b12.res.electric == nil and b12.res.fire == nil, "§2 palier 12 : résistances physique et explosion fortes, laser et électricité libres")
  local hp_ok = true
  for t = 2, E.TIERS do if D.biter(t).hp <= D.biter(t - 1).hp then hp_ok = false end end
  check(hp_ok and E.TIERS == 12, "§2 douze paliers aux PV croissants")
  local arm = D.biter(8, "armored")
  check(arm.hp == D.biter(8).hp * 1.5 and arm.res.physical[1] > D.biter(8).res.physical[1], "§2 famille blindée : PV × 1,5 et plus de résistance")
  check(D.biter(6, "toxic").dtype == "acid" and D.biter(6).dtype == "physical", "§2 morsure d'acide de la famille toxique")

  -- §3 Palier de l'âge.
  local want = { 1, 1, 2, 2, 3, 3, 4, 5, 6, 6, 7, 9, 10, 12, 12 }
  local got, mono = {}, true
  for a = 1, 15 do
    got[a] = D.tier_of_age(a)
    if a > 1 and got[a] < got[a - 1] then mono = false end
  end
  check(table.concat(got, ",") == table.concat(want, ","), "§3 palier de chaque âge", table.concat(got, ","))
  check(mono and D.tier_of_age(15) == 12 and D.tier_of_age(0) == 1 and D.tier_of_age(99) == 12, "§3 palier croissant ; âge 15 -> palier 12 ; âges bornés")
  check(near(D.weight(1, 0), 0.30) and near(D.weight(2, 0.35), 0.30) and near(D.weight(12, 1.0), 0.25) and D.weight(5, 0.2) == 0 and near(D.weight(2, 0.425), 0.175),
    "§3 poids d'apparition interpolé sur les courbes")

  -- §4 Le duel.
  local line = { { hp = 1000, back = 0, shot = { damage = 100, cooldown = 30, dtype = "laser", range = 20 } } }
  local biter = { hp = 100, dmg = 10, cd = 35, speed = 0.2, res = {} }
  local r1 = D.fight(line, biter, 3)
  check(r1.win and r1.fraction[1] > 0.9, "§4 un robot fort tue trois petits déchiqueteurs presque sans dégât")
  local weak = { { hp = 10, back = 0, shot = { damage = 1, cooldown = 30, dtype = "laser", range = 20 } } }
  check(not D.fight(weak, biter, 3).win, "§4 un robot faible perd")
  local mute = { { hp = 1000, back = 0 } }
  check(not D.fight(mute, { hp = 100, dmg = 1, cd = 35, speed = 0.2, res = {} }, 3, { max_ticks = 600 }).win, "§4 sans arme, pas de victoire (impasse)")
  local r2 = D.fight(line, biter, 3)
  check(r1.ticks == r2.ticks and r1.left[1] == r2.left[1], "§4 déterministe : deux duels identiques")
  -- la portée donne des tirs avant le contact
  local short = { { hp = 1000, back = 0, shot = { damage = 100, cooldown = 30, dtype = "laser", range = 2 } } }
  local far = { { hp = 1000, back = 0, shot = { damage = 100, cooldown = 30, dtype = "laser", range = 40 } } }
  check(D.fight(far, biter, 3).left[1] > D.fight(short, biter, 3).left[1], "§4 une portée de 40 abîme moins qu'une portée de 2 (tirs avant le contact)")
  -- zone : un tir touche les trois ; sans zone, un seul
  local thick = { hp = 450, dmg = 10, cd = 35, speed = 0.2, res = {} }
  local zone = { { hp = 1000, back = 0, shot = { damage = 100, cooldown = 30, dtype = "laser", range = 20, area = 4 } } }
  check(D.fight(zone, thick, 3).left[1] > D.fight(line, thick, 3).left[1], "§4 un tir de zone vaut mieux contre trois déchiqueteurs")
  -- portée minimale : l'artillerie se tait quand les déchiqueteurs arrivent
  local hard = { hp = 7000, dmg = 40, cd = 35, speed = 0.2, res = {} }
  local with_min = { { hp = 500, back = 0, shot = { damage = 5000, cooldown = 120, dtype = "explosion", range = 45, min_range = 12, area = 3 } } }
  local no_min = { { hp = 500, back = 0, shot = { damage = 5000, cooldown = 120, dtype = "explosion", range = 45, area = 3 } } }
  check(not D.fight(with_min, hard, 3).win and D.fight(no_min, hard, 3).win,
    "§4 artillerie : la portée minimale la rend muette au contact (sans elle, le même tir gagne)")
  -- soin
  local line2 = { hp = 300, back = 0, shot = { damage = 30, cooldown = 30, dtype = "laser", range = 20 } }
  local healer = { hp = 3000, back = 6, heal = { amount = 40, period = 60, max = 30 } }
  local b2 = { hp = 400, dmg = 6, cd = 35, speed = 0.2, res = {} }
  local without = D.fight({ line2 }, b2, 3)
  local with = D.fight({ line2, healer }, b2, 3)
  check(with.left[1] > without.left[1], "§4 le soin en impulsion garde le robot de ligne en vie plus longtemps")

  -- §5 Calibrage : les chiffres écrits sont ceux du modèle.
  local cal = D.calibrate_all(Ro.ROBOTS)
  for _, r in ipairs(Ro.ROBOTS) do
    local c = cal[r.id]
    if r.is_giant then
      -- géants : PV de la règle d'échelle (lot EXPERIMENTAUX-PUISSANCE, réponses du DC du 5/11), plus du calibrage ; le canon reste calibré
      check(r.hp == Ech.pv(r.age), "§5 PV d'un géant = PV de la règle d'échelle : " .. r.id .. " (" .. tostring(r.hp) .. " contre " .. tostring(Ech.pv(r.age)) .. ")")
    else
      check(c.hp == r.hp, "§5 PV écrits = PV calibrés : " .. r.id .. " (" .. tostring(r.hp) .. " contre " .. tostring(c.hp) .. ")")
    end
    if r.heal then
      check(c.heal == r.heal.amount, "§5 soin écrit = soin calibré : " .. r.id .. " (" .. tostring(r.heal.amount) .. " contre " .. tostring(c.heal) .. ")")
      check(r.shot.damage == 0 and r.dps == 0, "§5 la Cloche n'a aucun dégât")
    else
      check(near(c.damage, r.shot.damage, 1e-9), "§5 dégâts écrits = dégâts calibrés : " .. r.id .. " (" .. tostring(r.shot.damage) .. " contre " .. tostring(c.damage) .. ")")
    end
    check(c.tier == D.tier_of_age(r.age), "§5 palier du duel = palier de l'âge : " .. r.id)
    check(c.fraction >= D.TARGET - 1e-9 or r.heal ~= nil, "§5 marge visée tenue : " .. r.id .. string.format(" (%.2f)", c.fraction))
    if r.heal then check(c.fraction >= D.HEAL_TARGET - 1e-9 and c.base < c.fraction, "§5 le soin améliore la marge : " .. r.id) end
  end
  -- chaque robot gagne son duel, avec les chiffres ÉCRITS
  local reach, reach_age = {}, {} -- lot s43-robots : l'âge de chaque entrée (les variantes suivent les 12, hors de l'ordre des âges)
  for _, r in ipairs(Ro.ROBOTS) do
    if not r.heal then
      local tier = D.tier_of_age(r.age)
      local ref = nil
      local run = D.run(r, r.hp, r.shot.damage, tier, ref)
      check(run.win and run.fraction_subject >= D.TARGET - 0.01, "§5 " .. r.id .. " gagne son duel contre 3 du palier " .. tier .. string.format(" (%.2f)", run.fraction_subject or -1))
      reach[#reach + 1] = D.reach(r, r.hp, r.shot.damage, ref)
      reach_age[#reach] = r.age
      check(reach[#reach] >= tier, "§5 " .. r.id .. " bat au moins le palier de son âge (palier le plus haut battu : " .. reach[#reach] .. ")")
      -- une moitié de la puissance perd : le calibrage est serré (pas de surplus caché)
      local half = D.run(r, r.hp / 3, r.shot.damage / 3, tier, ref)
      check(not half.win or half.fraction_subject < D.TARGET, "§5 " .. r.id .. " : avec un tiers de la puissance, la marge s'effondre")
    end
  end
  -- §5 bis Géants (règle d'échelle, lot EXPERIMENTAUX-PUISSANCE) : résistances et salve de zone dans le duel.
  local tor = Ro.robot("toroid")
  local ech = D.echelle_of(tor)
  check(ech ~= nil and ech.zone.damage == Ech.salve(13, "electric") and ech.zone.cooldown == Ech.CADENCE_ZONE and ech.zone.dtype == "electric",
    "§5 bis géant : salve de zone de son âge et de son type, cadence de la règle")
  check(D.echelle_of(Ro.robot("finback")) == nil, "§5 bis un robot de ligne n'a pas de salve de zone")
  local t10 = D.tier_of_age(13)
  local avec = D.run(tor, tor.hp, tor.shot.damage, t10, nil, nil, ech)
  local sans = D.run(tor, tor.hp, tor.shot.damage, t10)
  check(avec.win and avec.ticks < sans.ticks, "§5 bis la salve de zone abrège le duel du géant", string.format("%d contre %d", avec.ticks, sans.ticks))
  check(avec.ticks == D.ZONE_DELAY + (Ech.SALVES - 1) * Ech.CADENCE_ZONE,
    "§5 bis Torique contre 3 du palier 10 : la 5e salve finit le duel", tostring(avec.ticks))
  local b10 = D.biter(t10)
  local m1 = D.fight({ { hp = 1e9, back = 0, res = D.res_of(tor.resistances) } }, b10, 1, { max_ticks = 600 })
  local m0 = D.fight({ { hp = 1e9, back = 0 } }, b10, 1, { max_ticks = 600 })
  local ratio = (1e9 - m1.left[1]) / (1e9 - m0.left[1])
  local want = Ech.apres(b10.dmg, Ech.resistances(13)[1].decrease, Ech.resistances(13)[1].percent) / b10.dmg
  check(math.abs(ratio - want) < 1e-6 and ratio < 1, "§5 bis les résistances du géant réduisent chaque morsure selon la formule du moteur",
    string.format("%.6f contre %.6f", ratio, want))
  -- §6 La gamme.
  local mono_r = true
  for i = 1, #reach do
    for j = 1, #reach do if reach_age[j] > reach_age[i] and reach[j] < reach[i] then mono_r = false end end
  end
  check(mono_r, "§6 le palier battu ne baisse jamais d'un âge à l'autre", table.concat(reach, ","))
  local g13 = Ro.robot("toroid")
  check(D.reach(g13, g13.hp, g13.shot.damage) >= 10 and Ro.robot("crowned").hp > g13.hp, "§6 le Couronné est plus robuste que le Torique")
  return pass, fail, msgs
end


--- Bloc MODELE de tools/autotest/fo-autotest/scenarios/rb-duel.lua : prédictions du modèle pour les robots de ligne du banc.
local DUEL_IDS = { "steam-trotter", "scalehide", "coiler", "needle", "trowel", "finback", "levite" }
local function modele_block(D)
  local out = { "local MODELE = {" }
  for _, id in ipairs(DUEL_IDS) do
    local r = Ro.robot(id)
    local run = D.run(r, r.hp, r.shot.damage, D.tier_of_age(r.age))
    out[#out + 1] = string.format('  ["%s"] = { age = %d, frac = %.2f, ticks = %d },', id, r.age, run.fraction_subject, run.ticks)
  end
  out[#out + 1] = "}"
  return table.concat(out, "\n")
end

local function giant_block(D)
  local out = { "local MODELE = {" }
  for _, id in ipairs({ "toroid", "heliast", "crowned" }) do
    local r = Ro.robot(id)
    local tier = D.tier_of_age(r.age)
    local run = D.run(r, r.hp, r.shot.damage, tier, nil, nil, D.echelle_of(r)) -- règle d'échelle : résistances et salve de zone
    out[#out + 1] = string.format('  ["%s"] = { age = %d, tier = %d, frac = %.2f, ticks = %d },', id, r.age, tier, run.fraction_subject, run.ticks)
  end
  out[#out + 1] = "}"
  return table.concat(out, "\n")
end

if arg and arg[1] == "--scenario" then
  print(modele_block(assert(load_duel(DU_SRC))))
  print(giant_block(assert(load_duel(DU_SRC))))
  os.exit(0)
end

if arg and arg[1] == "--calibrer" then
  local D = assert(load_duel(DU_SRC))
  local cal = D.calibrate_all(Ro.ROBOTS)
  for _, r in ipairs(Ro.ROBOTS) do
    local c = cal[r.id]
    print(string.format("%-14s age %2d palier %2d  hp = %-9s damage = %-9s%s  marge %.2f", r.id, r.age, c.tier, tostring(c.hp), tostring(c.damage),
      c.heal and (" heal.amount = " .. c.heal) or "", c.fraction or -1))
  end
  os.exit(0)
end

if arg and arg[1] == "--tables" then
  local D = assert(load_duel(DU_SRC))
  print("robot / palier battu le plus haut (1 contre 3), puis marge au palier de l'âge")
  for _, r in ipairs(Ro.ROBOTS) do
    if not r.heal then
      local tier = D.tier_of_age(r.age)
      local run = D.run(r, r.hp, r.shot.damage, tier)
      print(string.format("%-14s age %2d palier %2d : bat jusqu'au palier %2d, marge %.2f, durée %.1f s, %d PV, %.0f par tir (%.0f DPS)",
        r.id, r.age, tier, D.reach(r, r.hp, r.shot.damage), run.fraction_subject, run.ticks / 60, r.hp, r.shot.damage, r.dps))
    end
  end
  os.exit(0)
end

local D0 = assert(load_duel(DU_SRC))
local pass, fail, msgs = suite(D0)

-- §6 bis : le scénario rb-duel porte les prédictions du modèle actuel, et sa table d'âges est celle du modèle.
do
  local sc = read("tools/autotest/fo-autotest/scenarios/rb-duel.lua")
  local block = sc:match("%-%-MODELE%-DEBUT\n(.-)%-%-MODELE%-FIN")
  local fresh = modele_block(D0)
  local function check6(c, m) if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end end
  check6(block ~= nil and block:gsub("%s+$", "") == fresh, "§6 bis le bloc MODELE de rb-duel est celui du modèle (relancer --scenario)")
  local sg = read("tools/autotest/fo-autotest/scenarios/rb-geant.lua")
  local gblock = sg:match("%-%-MODELE%-DEBUT\n(.-)%-%-MODELE%-FIN")
  check6(gblock ~= nil and gblock:gsub("%s+$", "") == giant_block(D0), "§6 bis le bloc MODELE de rb-geant est celui du modèle (relancer --scenario)")
  local speeds = sg:match("local Ro_VITESSE = { (.-) }")
  local okv = speeds ~= nil
  for _, id in ipairs({ "toroid", "heliast", "crowned" }) do
    local v = speeds and tonumber(speeds:match(id .. " = ([%d%.]+)"))
    if v ~= Ro.robot(id).speed then okv = false end
  end
  check6(okv, "§6 bis les vitesses de rb-geant sont celles des données")
  local ss = read("tools/autotest/fo-autotest/scenarios/rb-soutien.lua")
  local dm = tonumber(ss:match("local DEGATS_CHANFREIN = ([%d%.]+)"))
  check6(dm == Ro.robot("chamfer").shot.damage, "§6 bis les dégâts du Chanfrein de rb-soutien sont ceux des données")
  local tbl = sc:match("local TIER_OF_AGE = { ([%d, ]+) }")
  local want = {}
  for a = 1, 15 do want[a] = D0.tier_of_age(a) end
  check6(tbl == table.concat(want, ", "), "§6 bis la table âge -> palier de rb-duel est celle du modèle")
  local names = sc:match('local TIER_NAMES = { (.-) }')
  local expect = {}
  for i, n in ipairs(E.tier_names) do expect[i] = '"' .. n .. '"' end
  check6(names == table.concat(expect, ", "), "§6 bis les noms de palier de rb-duel sont ceux de shared/content/enemies.lua")
end

-- §7 Mutants du modèle.
local MUTANTS = {
  { "retrait fixe ignoré", "local x = amount - r[1]", "local x = amount" },
  { "pourcentage ignoré", "return x * (1 - r[2])", "return x" },
  { "sous 1 de dégâts : zéro", "if x < 1 then x = 1 / (2 - x) end", "if x < 1 then x = 0 end" },
  { "palier 12 sans multiplicateur de PV", "hp = v.hp * nt.hp,", "hp = v.hp," },
  { "résistances de palier ignorées", "b.res[k] = { r[1] + flat, min(0.95, r[2] + pct) }", "b.res[k] = { r[1], r[2] }" },
  { "seuil de présence à 0,30", "Duel.WEIGHT_MIN = 0.10", "Duel.WEIGHT_MIN = 0.30" },
  { "seuil de présence à 0", "Duel.WEIGHT_MIN = 0.10", "Duel.WEIGHT_MIN = 0.001" },
  { "la zone ne touche qu'un", "if (s.area or 0) >= 2 then", "if false then" },
  { "portée minimale ignorée", "local lo = s.min_range or 0", "local lo = 0" },
  { "soin jamais joué", "if t % 60 == 59 then", "if t % 60 == 1000 then" },
  { "morsure sans délai de contact", "if b.ready == nil then b.ready = t + Duel.CONTACT_DELAY end", "if b.ready == nil then b.ready = t end" },
  { "tir sans délai de visée", "if m.ready == nil then m.ready = t + Duel.AIM_DELAY end", "if m.ready == nil then m.ready = t end" },
  { "déchiqueteurs immobiles", "if p < tg.back then p = min(tg.back, p + biter.speed) end", "" },
  { "marge visée à 0", "Duel.TARGET = 0.35", "Duel.TARGET = 0.0" },
  { "famille sans PV", "b.hp, b.dmg, b.speed = b.hp * f.hp, b.dmg * f.damage, b.speed * f.speed", "b.dmg, b.speed = b.dmg * f.damage, b.speed * f.speed" },
  { "trois déchiqueteurs devenus un", "Duel.BITERS = 3", "Duel.BITERS = 1" },
  { "écran de 3 s", "Duel.SCREEN_SECONDS = 12", "Duel.SCREEN_SECONDS = 3" },
  { "salve de zone jamais jouée", "        if t >= m.zready then", "        if false then" },
  { "salve de zone sans délai", "if m.zready == nil then m.zready = Duel.ZONE_DELAY end", "if m.zready == nil then m.zready = 0 end" },
  { "cadence de zone ignorée", "m.zready = t + z.cooldown", "m.zready = t + 60" },
  { "morsure sans résistance du géant", "tg.hp = tg.hp - (tg.res and Duel.after_resist(biter.dmg, biter.dtype, tg.res) or biter.dmg)", "tg.hp = tg.hp - biter.dmg" },
  { "pourcentage du prototype lu comme fraction", "(x.percent or 0) / 100", "(x.percent or 0) / 1000" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = DU_SRC:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif absent)"
  else
    local D = load_duel(DU_SRC:sub(1, a - 1) .. m[3] .. DU_SRC:sub(b + 1))
    local f2 = 1
    if D then
      local ok, _, ff = pcall(suite, D)
      f2 = ok and ff or 1
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  msgs[#msgs + 1] = "§7 mutants NON refusés : " .. table.concat(kept, " ; ")
end

for _, m in ipairs(msgs) do print("[ROBOTS-DUEL] ECHEC " .. m) end
print(string.format("[ROBOTS-DUEL] mutants refusés : %d sur %d", refused, #MUTANTS))
print(string.format("[ROBOTS-DUEL] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
