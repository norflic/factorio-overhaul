--[[
  Lot EXPERIMENTAUX (3/11) : banc hors jeu des robots expérimentaux (shared/robots/experimentaux.lua). Lua 5.2, depuis la racine du mod :
      lua5.2 tests/experimentaux_test.lua
    §1 données : les 5 petits de FAISABILITE (âge, rôle, usine de l'âge, technologie de l'époque), ingrédients au plus 100, coût en MU
       à ±20 % (même fonction de MU que tests/robots_test.lua) ;
    §2 valeur pour la valeur : PV, dégâts par seconde, coup, charge = référence × mu / ref.mu (× 3 en PV pour une défense posée) ;
    §3 règles des effets : plus proche, sauts de l'arc, pointes, jets, chute des dégâts, zone, noms ;
    §4 feuilles (D-6) : sprites.lua, chaque PNG présent, dimensions lues dans l'en-tête PNG égales à sprites.lua, au plus 4 096 px ;
       MANIFEST.json cite chaque fichier ;
    §5 forme des fichiers : aucun pairs dans shared/robots/experimentaux.lua, aucun require dans une fonction (F24), `global` jamais nommé ;
    §6 traductions : chaque clé citée par le prototype existe en FR et EN, mêmes clés des deux côtés ;
    §7 mutants : chaque règle a un mutant, tous doivent être refusés ;
    §9 coûts (lot XP-COUTS, décisions du DC du 4/11, 19 h 48) : technologie = le double de la technologie de robot prérequise, packs de
       l'âge (C.packs) ; aucun ingrédient plus tardif que l'âge du robot (âges lus sur la page du graphe du 4/11).
]]

package.path = "./?.lua;" .. package.path

local X = require("shared.content.epochs")
local Lv = require("shared.levels.config")
local Cp = require("shared.content.compute")
local Pt = require("shared.content.robot_parts")
local Ro = require("shared.content.robots")
local C = require("shared.content.crafts")
local Ech = require("shared.robots.echelle")

local function read(p)
  local f = assert(io.open(p, "rb"), "lecture impossible : " .. p)
  local s = f:read("*a")
  f:close()
  return s
end

local XP_SRC = read("shared/robots/experimentaux.lua")

-- MU d'un objet : même fonction que tests/robots_test.lua (monnaies, matières d'âge, pièces de robots, calcul)
local value = {}
for _, c in ipairs(X.currencies) do value[c.item] = c.value end
for e = 2, 12 do local m = Lv.epoch_materials[e]; if m then value[m.item] = m.value end end
local memo = {}
local function mu_of(item)
  if memo[item] then return memo[item] end
  local v
  if Pt.present(item) then
    local rr = Pt.recipe(item)
    local s = 0
    for _, g in ipairs(rr.ingredients) do s = s + mu_of(g[1]) * g[2] end
    v = s / rr.results[1][2]
  elseif value[item] then v = value[item]
  elseif Ro.MU_ASSUMED[item] then v = Ro.MU_ASSUMED[item]
  else v = Cp.mu(item) end
  memo[item] = v
  return v
end

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) * math.max(1, math.abs(b)) end

-- feuilles générées (D-6) : l'échelle écrite par feuilles_xp.py doit être celle des données (contrôlé aussi sur les mutants)
local okspr0, SPR0 = pcall(dofile, "graphics/robots/experimentaux/sprites.lua")

-- §9 coûts des technologies, figés (décisions du DC du 4/11, 19 h 48) : unités = 2 × la technologie de robot prérequise ; packs de
-- l'âge. R rouge, V vert, M militaire, B bleu, P production, J utilité, S spatial.
local TECH_WANT = {
  ["mat-foudre"] = { 36, "RVMBP" }, geode = { 300, "RVMBP" }, sarracenie = { 300, "RVMBP" }, ["demi-vie"] = { 300, "RVMBP" },
  veilleuse = { 600, "RVMBPJ" }, cairn = { 100, "RVMBPJ" }, stylet = { 400, "RVMBPJ" }, trombe = { 500, "RVMBPJ" },
  ixion = { 600, "RVMBPJ" }, tournesol = { 600, "RVMBPJS" },
}
local PACK_LETTER = { ["automation-science-pack"] = "R", ["logistic-science-pack"] = "V", ["military-science-pack"] = "M",
  ["chemical-science-pack"] = "B", ["production-science-pack"] = "P", ["utility-science-pack"] = "J", ["space-science-pack"] = "S" }
local function letters(packs)
  local o = {}
  for _, p in ipairs(packs) do o[#o + 1] = PACK_LETTER[p] or "?" end
  return table.concat(o)
end
-- Âge des ingrédients (page du graphe du 4/11, fo-logs/2026-11-04_GRAPHE, données finales : âge de la première recette en jeu).
-- Un ingrédient absent de cette table est refusé : ajouter son âge en l'ajoutant à une recette.
local INGREDIENT_AGE = {
  ["copper-cable"] = 1, ["electronic-circuit"] = 1, ["fo-methane-barrel"] = 1, ["steel-plate"] = 2, ["engine-unit"] = 3,
  ["advanced-circuit"] = 4, ["plastic-bar"] = 4, battery = 6, ["fo-controller"] = 7, ["fo-optical-sensor"] = 7, ["fo-titanium-composite"] = 8,
  ["fo-resonance-crystal"] = 7, ["fo-servo-motor"] = 7, ["fo-lead-plate"] = 9, ["uranium-238"] = 9, ["fo-guidance-core"] = 10,
  ["processing-unit"] = 10, ["low-density-structure"] = 10, ["fo-graphics-card"] = 11, ["fo-titanium-plate"] = 11, ["fo-laser-module"] = 12,
  ["fo-magnetic-actuator"] = 12, ["fo-superconducting-coil"] = 12,
}
--- Ingrédients plus tardifs que l'âge `age` (ou d'âge inconnu) : liste de noms.
local function late_ingredients(list, age)
  local bad = {}
  for _, g in ipairs(list) do
    local a = INGREDIENT_AGE[g[1]]
    if not a or a > age then bad[#bad + 1] = g[1] .. " (" .. tostring(a) .. ")" end
  end
  return bad
end

--- La suite : rend (ok, échecs, messages). `Xp` : le module (réel ou mutant).
local function suite(Xp)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end

  -- §1 données
  local want = {
    { "mat-foudre", 6, "turret-electric", "fo-robot-workshop", 1800, 30 },
    { "geode", 7, "unit-capsule", "fo-robotics-bay", 3400, 30 },
    { "sarracenie", 8, "turret", "fo-robotics-bay", 6200, 30 },
    { "demi-vie", 9, "unit-capsule", "fo-robotics-bay", 7500, 20 },
    { "veilleuse", 13, "turret", "fo-robot-gantry", 42000, 10 },
  }
  check(#Xp.ROBOTS == #want, "§1 cinq petits")
  for i, w in ipairs(want) do
    local r = Xp.ROBOTS[i]
    check(r and r.id == w[1] and r.age == w[2] and r.kind == w[3] and r.factory == w[4] and r.mu == w[5] and r.time == w[6],
      "§1 " .. w[1] .. " : âge, rôle, usine, coût et durée de FAISABILITE")
    if r then
      local f = Ro.factory(r.factory)
      check(f and f.age <= r.age, "§1 " .. r.id .. " : son usine existe et arrive avant lui")
      -- l'usine de son âge : la plus récente arrivée à son âge
      local best
      for _, ff in ipairs(Ro.FACTORIES) do if ff.age <= r.age and (not best or ff.age > best.age) then best = ff end end
      check(best and f == best, "§1 " .. r.id .. " : usine de robots de SON âge (la plus récente)")
      check(Xp.category(r) == (f and f.category), "§1 " .. r.id .. " : catégorie de fabrication de l'usine")
      local t = Ro.tech(r.after)
      check(t and t.epoch == r.age, "§1 " .. r.id .. " : technologie de robot d'époque égale à son âge (" .. tostring(r.after) .. ")")
      local ok100, dup, seen = true, false, {}
      for _, g in ipairs(r.ingredients) do
        if g[2] > 100 or g[2] < 1 then ok100 = false end
        if seen[g[1]] then dup = true end
        seen[g[1]] = true
      end
      check(ok100 and not dup, "§1 " .. r.id .. " : ingrédients de 1 à 100, sans doublon")
      local c = 0
      for _, g in ipairs(r.ingredients) do c = c + mu_of(g[1]) * g[2] end
      local ratio = c / r.mu
      check(ratio >= 0.8 and ratio <= 1.2, string.format("§1 %s : coût %.0f MU contre %d (±20 %%)", r.id, c, r.mu))
      check(r.name == "fo-xp-" .. r.id and r.recipe == "fo-xp-make-" .. r.id and r.tech == "fo-xp-" .. r.id, "§1 " .. r.id .. " : noms")
      check(Xp.of_name(r.name) == r and Xp.robot(r.id) == r, "§1 " .. r.id .. " : retrouvé par son nom")
      check((r.kind == "unit-capsule") == r.is_unit, "§1 " .. r.id .. " : unité si et seulement si lancé")
      if r.is_unit then
        check(r.half and r.half <= 1.5 and r.speed and r.speed > 0, "§1 " .. r.id .. " : unité de demi-boîte au plus 1,5 (chemins), vitesse > 0")
      else
        check(r.foot == 3, "§1 " .. r.id .. " : défense posée en 3 × 3 (décision du lead, 4/11)")
      end
      check(r.range > 0 and r.cooldown > 0, "§1 " .. r.id .. " : portée et cadence")
      check(okspr0 and SPR0.corps[r.id] and SPR0.corps[r.id].echelle == r.scale and r.scale > 0 and r.scale < 0.5,
        "§1 " .. r.id .. " : réduit (échelle " .. tostring(r.scale) .. ", celle des feuilles)")
      check((r.single_use == true) == (r.id == "demi-vie"), "§1 " .. r.id .. " : usage unique pour la seule Demi-Vie")
      local tw = TECH_WANT[r.id]
      local units = t and Xp.tech_units and Xp.tech_units(C.tech_count(t))
      check(tw and units == tw[1] and units == 2 * C.tech_count(t), string.format("§9 %s : technologie à %s unités (2 × %s), attendu %s",
        r.id, tostring(units), t and tostring(C.tech_count(t)) or "?", tw and tostring(tw[1]) or "?"))
      check(tw and letters(C.packs(r.age)) == tw[2], "§9 " .. r.id .. " : packs de l'âge " .. letters(C.packs(r.age)))
      local bad = late_ingredients(r.ingredients, r.age)
      check(#bad == 0, "§9 " .. r.id .. " : aucun ingrédient plus tardif que l'âge " .. r.age .. " : " .. table.concat(bad, ", "))
    end
  end

  -- §2 dégâts par seconde : valeur pour la valeur ; PV, résistances et salve : règle d'échelle par âge (QCM du DC du 5/11)
  local function same_res(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i].type ~= b[i].type or a[i].decrease ~= b[i].decrease or a[i].percent ~= b[i].percent then return false end end
    return true
  end
  for _, r in ipairs(Xp.ROBOTS) do
    local ref = Ro.robot(r.ref)
    check(ref ~= nil, "§2 " .. r.id .. " : robot de référence " .. tostring(r.ref))
    if ref then
      check(ref.age <= r.age and (ref.dps or 0) > 0, "§2 " .. r.id .. " : référence d'âge au plus égal, qui tire")
      local k = r.mu / ref.mu
      check(r.hp == Ech.pv(r.age), string.format("§2 %s : PV %s = règle d'échelle de l'âge %d (%d)", r.id, tostring(r.hp), r.age, Ech.pv(r.age)))
      check(same_res(r.resistances, Ech.resistances(r.age)), "§2 " .. r.id .. " : résistances d'écart d'âge de son âge")
      check(near(r.dps, ref.dps * k, 1e-3), "§2 " .. r.id .. " : dégâts par seconde = référence × coût")
      local base = math.floor(r.dps * r.cooldown / 60 / 0.1 + 0.5) * 0.1
      local salve = Ech.salve(r.age, r.dtype)
      check(r.salve == salve and near(r.shot, math.max(base, salve * ((r.jets and r.jets.count) or 1)), 1e-3),
        string.format("§2 %s : coup %s = le plus grand de la valeur (%.1f) et de la salve de l'âge par cible touchée (%s)", r.id, tostring(r.shot), base, tostring(salve)))
      if r.single_use then
        check(near(r.burst, ref.dps * k * Xp.BURST_SECONDS, 1e-3), "§2 " .. r.id .. " : charge = 30 s de dégâts")
      else
        check(r.burst == nil, "§2 " .. r.id .. " : pas de charge hors usage unique")
      end
      check(r.zone == nil, "§2 " .. r.id .. " : un petit garde la forme de son attaque (pas de salve de zone)")
    end
  end
  check(Xp.BURST_SECONDS == 30 and Xp.HP_POSE == nil, "§2 constantes : charge de 30 s ; plus de facteur des défenses posées (règle d'échelle)")

  -- §3 règles
  local P = function(x, y, id) return { x = x, y = y, id = id } end
  local c3 = { P(3, 0, 7), P(0, 3, 5), P(-3, 0, 9), P(10, 10, 1) }
  check(Xp.nearest(P(0, 0, 0), c3).id == 5, "§3 plus proche : égalité de distance -> plus petit numéro")
  check(Xp.nearest(P(0, 0, 0), c3, 2) == nil, "§3 plus proche : rien au-delà de la distance maximale")
  check(Xp.nearest(P(0, 0, 0), {}) == nil, "§3 plus proche : liste vide")
  local first = P(0, 0, 100)
  local line = { first, P(4, 0, 2), P(8, 0, 3), P(12, 0, 4), P(30, 0, 5) }
  local ch = Xp.chain(first, line, 2, 5)
  check(#ch == 2 and ch[1].id == 2 and ch[2].id == 3, "§3 arc : deux sauts, chacun vers le plus proche du précédent")
  local ch3 = Xp.chain(first, line, 10, 5)
  check(#ch3 == 3 and ch3[3].id == 4, "§3 arc : s'arrête quand plus rien n'est à portée (la 5e cible est à 18)")
  local ids = {}
  local rep = false
  for _, c in ipairs(Xp.chain(first, { first, P(1, 0, 2), P(2, 0, 3) }, 5, 5)) do
    if ids[c.id] or c.id == first.id then rep = true end
    ids[c.id] = true
  end
  check(not rep, "§3 arc : jamais deux fois la même cible, jamais la première")
  check(#Xp.chain(first, { first }, 2, 8) == 0, "§3 arc : aucune autre cible, aucun saut")
  local sp = Xp.spike_points(P(0, 0), P(8, -4), 8)
  check(#sp == 8 and near(sp[8].x, 8) and near(sp[8].y, -4) and near(sp[1].x, 1) and near(sp[1].y, -0.5), "§3 pointes : 8 points, le dernier sur la cible")
  local eq = true
  for i = 2, #sp do
    local dx, dy = sp[i].x - sp[i - 1].x, sp[i].y - sp[i - 1].y
    if not near(dx * dx + dy * dy, 1.25) then eq = false end
  end
  check(eq, "§3 pointes : également espacées")
  local jp = Xp.jet_points(P(0, 0), P(10, 0), 3, 3)
  check(#jp == 3 and near(jp[1].x, 10) and near(jp[1].y, 0), "§3 jets : le premier tombe sur la cible")
  check(jp[2] and jp[3] and near(jp[2].x, 10) and near(jp[3].x, 10) and near(jp[2].y + jp[3].y, 0) and near(math.abs(jp[2].y), 3),
    "§3 jets : deux de part et d'autre, à 3 tuiles, perpendiculaires au tir")
  local jp0 = Xp.jet_points(P(5, 5), P(5, 5), 3, 3)
  check(#jp0 == 3 and near(jp0[2].x, 5) and near(jp0[2].y, 5), "§3 jets : tir à bout portant, pas de division par zéro")
  check(near(Xp.falloff(100, 0, 12, 0.5), 100) and near(Xp.falloff(100, 12, 12, 0.5), 50) and near(Xp.falloff(100, 6, 12, 0.5), 75),
    "§3 chute : 100 au centre, 50 au bord, linéaire")
  check(Xp.falloff(100, 12.01, 12, 0.5) == 0, "§3 chute : rien au-delà du rayon")
  local ir = Xp.in_radius(P(0, 0), { P(2, 0, 9), P(0, 2, 3), P(1, 0, 8), P(5, 5, 1) }, 2)
  check(#ir == 3 and ir[1].c.id == 8 and ir[2].c.id == 3 and ir[3].c.id == 9, "§3 zone : bord compris, triés par distance puis numéro")
  local dv = Xp.robot("demi-vie")
  check(dv and Xp.zone_alive(dv, 100, 100 + dv.contamination.duration - 1) and not Xp.zone_alive(dv, 100, 100 + dv.contamination.duration),
    "§3 zone contaminée : vit exactement sa durée")
  check(dv and near(Xp.contamination_pulse(dv), dv.burst * dv.contamination.share), "§3 zone contaminée : impulsion = charge × part")
  check(Xp.of_launch_effect(Xp.launch_effect("geode")) == Xp.robot("geode") and Xp.of_launch_effect(Xp.launch_effect("veilleuse")) == nil,
    "§3 capsule : effet de lancer d'un attaquant seulement")
  check(Xp.of_name("fo-xp-inconnu") == nil and Xp.of_name("fo-robot-geode") == nil and Xp.of_name(nil) == nil, "§3 nom inconnu : nil")
  local dups = {}
  local uniq = true
  for _, v in ipairs({ Xp.EFFECT.arc, Xp.EFFECT.buisson, Xp.EFFECT.crachat, Xp.EFFECT.jet, Xp.EFFECT.fusion, Xp.EFFECT.goutte, Xp.EFFECT.lance }) do
    if dups[v] then uniq = false end
    dups[v] = true
  end
  check(uniq, "§3 effets script : identifiants distincts")

  -- §8 géants (palier 3)
  local wantg = {
    { "cairn", 10, "fo-robot-dock", 41000, "balayage" }, { "stylet", 11, "fo-robot-dock", 75000, "ecriture" },
    { "trombe", 12, "fo-robot-dock", 137000, "gel" }, { "ixion", 13, "fo-robot-gantry", 251000, "tranchee" },
    { "tournesol", 14, "fo-robot-gantry", 459000, "foyer" },
  }
  check(#Xp.GEANTS == #wantg and Xp.SEGMENTS == 10, "§8 cinq géants, 10 segments chacun")
  for i, w in ipairs(wantg) do
    local r = Xp.GEANTS[i]
    check(r and r.id == w[1] and r.age == w[2] and r.factory == w[3] and r.mu == w[4] and r.effect == w[5] and r.time == 60,
      "§8 " .. w[1] .. " : âge, usine, coût, effet, 60 s")
    if r then
      local f = Ro.factory(r.factory)
      local best
      for _, ff in ipairs(Ro.FACTORIES) do if ff.age <= r.age and (not best or ff.age > best.age) then best = ff end end
      check(f and f == best, "§8 " .. r.id .. " : assemblé à l'usine de son âge")
      local t = Ro.tech(r.after)
      check(t and t.epoch == r.age, "§8 " .. r.id .. " : technologie de robot de son époque (" .. tostring(r.after) .. ")")
      local ok100, dup, seen, c = true, false, {}, 0
      for _, g in ipairs(r.segment.ingredients) do
        if g[2] > 100 or g[2] < 1 then ok100 = false end
        if seen[g[1]] then dup = true end
        seen[g[1]] = true
        c = c + mu_of(g[1]) * g[2]
      end
      check(ok100 and not dup, "§8 " .. r.id .. " : segment de 1 à 100 par ingrédient, sans doublon")
      local ratio = c * Xp.SEGMENTS / r.mu
      check(ratio >= 0.8 and ratio <= 1.2, string.format("§8 %s : 10 segments = %.0f MU contre %d (±20 %%)", r.id, c * Xp.SEGMENTS, r.mu))
      check(r.ingredients[1][1] == r.segment_item and r.ingredients[1][2] == Xp.SEGMENTS and #r.ingredients == 1, "§8 " .. r.id .. " : assemblage = 10 segments")
      check(r.is_giant and not r.is_unit and not r.is_turret and Xp.of_name(r.name) == r, "§8 " .. r.id .. " : géant, retrouvé par son nom")
      local ref = Ro.robot(r.ref)
      check(ref and ref.age == r.age and near(r.dps, ref.dps * r.mu / ref.mu, 1e-3), "§8 " .. r.id .. " : dégâts par seconde, valeur pour la valeur")
      check(r.hp == Ech.pv(r.age) and same_res(r.resistances, Ech.resistances(r.age)), "§8 " .. r.id .. " : PV et résistances de la règle d'échelle")
      check(r.salve == Ech.salve(r.age, r.dtype) and r.zone == Ech.rayon(r.age) and r.zone == 15 * (r.age - 9) and r.cratere == Ech.cratere(r.age),
        string.format("§8 %s : salve %s par cible, zone %s (15 × (âge − 9)), cratère %s", r.id, tostring(r.salve), tostring(r.zone), tostring(r.cratere)))
      check(r.zone_cooldown == math.max(r.cooldown, Ech.CADENCE_ZONE) and r.zone_cooldown >= 180, "§8 " .. r.id .. " : une salve de zone au plus toutes les 3 s")
      check(r.range > 0 and r.cooldown > 0 and r.speed > 0, "§8 " .. r.id .. " : portée, cadence, vitesse")
      local tw = TECH_WANT[r.id]
      local units = t and Xp.tech_units and Xp.tech_units(C.tech_count(t))
      check(tw and units == tw[1] and units == 2 * C.tech_count(t), string.format("§9 %s : technologie à %s unités (2 × %s), attendu %s",
        r.id, tostring(units), t and tostring(C.tech_count(t)) or "?", tw and tostring(tw[1]) or "?"))
      check(tw and letters(C.packs(r.age)) == tw[2], "§9 " .. r.id .. " : packs de l'âge " .. letters(C.packs(r.age)))
      local bad = late_ingredients(r.segment.ingredients, r.age)
      check(#bad == 0, "§9 " .. r.id .. " : aucun ingrédient de segment plus tardif que l'âge " .. r.age .. " : " .. table.concat(bad, ", "))
    end
  end
  check(Xp.giant_cap(9) == 0 and Xp.giant_cap(10) == 1 and Xp.giant_cap(12) == 1 and Xp.giant_cap(13) == 1 and Xp.giant_cap(14) == 2
    and Xp.giant_cap(15) == 3 and Xp.giant_cap(nil) == 0, "§8 plafond : 0 avant l'âge 10, 1 de 10 à 13, puis celui de Ro (2, 3)")
  check(Xp.giant_ok(10, 0) and not Xp.giant_ok(10, 1) and Xp.giant_ok(14, 1) and not Xp.giant_ok(14, 2) and not Xp.giant_ok(9, 0),
    "§8 plafond : un de plus admis seulement sous le plafond")
  check(near(Xp.split(90, 3), 30) and near(Xp.split(90, 0), 90), "§8 coup partagé entre les cibles (au moins une)")
  local mk = Xp.marks(P(0, 0), { P(5, 0, 4), P(1, 0, 9), P(50, 0, 1), P(0, 2, 3) }, 2, 40)
  check(#mk == 2 and mk[1].id == 9 and mk[2].id == 3, "§8 Cairn : les n plus proches dans la portée")
  local nodes, pts = Xp.circuit(P(0, 0), P(10, 5, 1), { P(10, 5, 1), P(12, 8, 2), P(40, 40, 3) }, 6, 6)
  check(#nodes == 2 and nodes[1].id == 1 and nodes[2].id == 2, "§8 Stylet : la cible puis de proche en proche (bond au plus 6)")
  local droit = true
  for i = 2, #pts do if pts[i].x ~= pts[i - 1].x and pts[i].y ~= pts[i - 1].y then droit = false end end
  check(droit and pts[#pts].x == 12 and pts[#pts].y == 8, "§8 Stylet : tracé à angles droits jusqu'au dernier nœud")
  local fz = Xp.fissure(P(0, 0), P(30, 0), 3, 10)
  check(#fz == 13 and near(fz[1].x, 3) and near(fz[13].x, 39) and near(fz[13].y, 0), "§8 Ixion : fissure tous les 3, prolongée de 10")
  check(#Xp.fissure(P(1, 1), P(1, 1), 3, 10) == 0, "§8 Ixion : cible sur place, pas de fissure")
  check(Xp.foyer_fires(0, 0.5) and Xp.foyer_fires(0.49, 0.5) and not Xp.foyer_fires(0.5, 0.5) and not Xp.foyer_fires(0.85, 0.5),
    "§8 Tournesol : ne tire pas la nuit")
  return pass, fail, msgs
end

local Xp = require("shared.robots.experimentaux")
local pass, fail, msgs = suite(Xp)
local function check(c, m) if c then pass = pass + 1 else fail = fail + 1; msgs[#msgs + 1] = m end end

-- §4 feuilles (D-6)
local SPR_PATH = "graphics/robots/experimentaux/sprites.lua"
local okspr, SPR = pcall(dofile, SPR_PATH)
check(okspr and type(SPR) == "table", "§4 sprites.lua lisible (sinon : py -3.9 tools/render/pieces/experimentaux/feuilles_xp.py)")
local function png_size(p)
  local f = io.open(p, "rb")
  if not f then return nil end
  local h = f:read(24)
  f:close()
  if not h or #h < 24 or h:sub(2, 4) ~= "PNG" then return nil end
  local function u32(s) local a, b, c, d = s:byte(1, 4) return ((a * 256 + b) * 256 + c) * 256 + d end
  return u32(h:sub(17, 20)), u32(h:sub(21, 24))
end
local MAN = okspr and read("graphics/robots/experimentaux/MANIFEST.json") or ""
local function file_of(fn) return fn:gsub("^__factorio%-overhaul__/", "") end
local nfiles = 0
local function check_img(def, what)
  for _, q in ipairs({ "hr", "lr" }) do
    local d = def[q]
    local p = file_of(d.filename)
    local w, h = png_size(p)
    nfiles = nfiles + 1
    check(w == d.width and h == d.height, "§4 " .. what .. " " .. q .. " : PNG présent, " .. tostring(w) .. " × " .. tostring(h) .. " = sprites.lua")
    check(d.width <= 4096 and d.height <= 4096, "§4 " .. what .. " " .. q .. " : au plus 4 096 px")
    check(MAN:find('"' .. p:match("[^/]+$") .. '"', 1, true) ~= nil, "§4 " .. what .. " " .. q .. " : cité au MANIFEST")
  end
end
if okspr then
  for _, r in ipairs(Xp.ROBOTS) do
    local s = SPR.corps[r.id]
    check(s and s.main and s.ombre and s.icone and #s.lueurs >= 1, "§4 " .. r.id .. " : corps, ombre, icône, au moins une lueur")
    if s then
      check_img(s.main, r.id)
      check_img(s.ombre, r.id .. " ombre")
      for _, g in ipairs(s.lueurs) do check_img(g, r.id .. " lueur " .. tostring(g.nom)) end
      local w, h = png_size(file_of(s.icone.filename))
      check(w == 64 and h == 64, "§4 " .. r.id .. " : icône 64 × 64")
      check(near(s.main.hr.scale, 0.5) and near(s.main.lr.scale, 1) and s.px_rendu == 64, "§4 " .. r.id .. " : 64 px par tuile en haute, 32 en normale")
      check(s.echelle == r.scale, "§4 " .. r.id .. " : feuilles à l'échelle de shared (" .. tostring(s.echelle) .. " / " .. tostring(r.scale) .. ")")
      -- taille du corps à l'écran (tuiles), décision du lead du 4/11 : défenses ~3 de large, 4 à 5 de haut ; Géode ~3 (sphère ; débris
      -- compris, 6,5 au plus) ; Demi-Vie ~2
      local w, h = s.main.hr.width * s.main.hr.scale / 32, s.main.hr.height * s.main.hr.scale / 32
      local maxw, maxh = 3.3, 5.1
      if r.id == "geode" then maxw, maxh = 6.5, 5.1 elseif r.id == "demi-vie" then maxw, maxh = 2.1, 3.0 end
      check(w <= maxw and h <= maxh and w >= maxw * 0.6, string.format("§4 %s : corps de %.2f × %.2f tuiles (au plus %.1f × %.1f)", r.id, w, h, maxw, maxh))
    end
  end
  for _, k in ipairs({ "pointe", "pointe-lueur", "eclair", "verre" }) do
    check(SPR.effets[k] ~= nil, "§4 effet " .. k)
    if SPR.effets[k] then check_img(SPR.effets[k], "effet " .. k) end
  end
end

-- §5 forme des fichiers
local SCRIPT = read("script/robots/experimentaux.lua")
local PROTO = read("prototypes/experimentaux.lua")
check(not (XP_SRC:gsub("ipairs%(", "")):find("pairs%("), "§5 shared : aucun pairs")
local function no_require_in_function(src)
  local depth = 0
  for line in src:gmatch("[^\n]*") do
    local code = line:gsub("%-%-.*$", "")
    if depth > 0 and code:find("require%(") then return false end
    for _ in code:gmatch("%f[%w]function%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]do%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]then%f[%W]") do depth = depth + 1 end
    for _ in code:gmatch("%f[%w]end%f[%W]") do depth = depth - 1 end
    for _ in code:gmatch("%f[%w]elseif%f[%W]") do depth = depth - 1 end
  end
  return true
end
for _, p in ipairs({ "script/robots/experimentaux.lua", "script/robots/experimentaux_commun.lua", "script/robots/experimentaux_geants.lua" }) do
  local f = io.open(p, "rb")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  check(no_require_in_function(src), "§5 " .. p .. " : aucun require dans une fonction (F24)")
  check(not src:find("%f[%w]global%f[%W]%s*[%.%[]"), "§5 " .. p .. " : `global` jamais nommé")
  local pairs_ok = true
  for line in src:gmatch("[^\n]*") do
    if line:find("[^i]pairs%(") and not line:find("trié juste après") then pairs_ok = false end
  end
  check(pairs_ok, "§5 " .. p .. " : pairs seulement sur game.forces, trié juste après")
end
check(not XP_SRC:find("%f[%w]global%f[%W]%s*[%.%[]"), "§5 shared : `global` jamais nommé")

-- §5 noms : tout nom littéral `Xp.PREFIX .. "…"` d'un script (sprite, rayon, explosion, fumée, jet) est déclaré par un prototype, littéral
-- ou sprite d'effet (Xp.EFFET_SPRITES, bouclé par prototypes/experimentaux.lua). g1 (4/11) : la glace de la Trombe manquait, la partie s'arrêtait.
local function prefix_names(src, set)
  set = set or {}
  for n in src:gmatch("Xp%.PREFIX%s*%.%.%s*\"([^\"]+)\"") do set[n] = true end
  return set
end
local function declared_names()
  local set = prefix_names(PROTO)
  prefix_names(read("prototypes/experimentaux_geants.lua"), set)
  if PROTO:find("ipairs%(Xp%.EFFET_SPRITES%)") then
    for _, n in ipairs(Xp.EFFET_SPRITES or {}) do set[n] = true end
  end
  return set
end
local DECL = declared_names()
check(PROTO:find("ipairs%(Xp%.EFFET_SPRITES%)") ~= nil, "§5 prototypes : les sprites d'effet sont bouclés sur Xp.EFFET_SPRITES")
for _, p in ipairs({ "prototypes/experimentaux.lua", "prototypes/experimentaux_geants.lua" }) do
  local src = read(p)
  check(src:find("count = Xp.tech_units(C.tech_count(after)), packs = C.packs(r.age),", 1, true) ~= nil,
    "§9 " .. p .. " : unités par Xp.tech_units, packs de l'âge")
end
for _, p in ipairs({ "script/robots/experimentaux.lua", "script/robots/experimentaux_commun.lua", "script/robots/experimentaux_geants.lua" }) do
  local used, list = prefix_names(read(p)), {}
  for n in pairs(used) do list[#list + 1] = n end
  table.sort(list)
  local missing = {}
  for _, n in ipairs(list) do if not DECL[n] then missing[#missing + 1] = n end end
  check(#missing == 0, "§5 " .. p .. " : noms Xp.PREFIX déclarés par un prototype (manquent : " .. table.concat(missing, ", ") .. ")")
  -- couleurs du rendering : prémultipliées (gi1 : un disque { …, a = 0.3 } écrit tel quel sortait blanc opaque) ; une couleur translucide
  -- passe par rgba(), aucune table littérale avec `a` < 1
  local brut = {}
  for line in read(p):gmatch("[^\n]*") do
    local code = line:gsub("%-%-.*$", "")
    if code:find("[%w_]+%s*=%s*{[^}]*%f[%w]a%s*=%s*0?%.%d") then brut[#brut + 1] = code:match("^%s*(.-)%s*$"):sub(1, 60) end
  end
  check(#brut == 0, "§5 " .. p .. " : aucune couleur translucide littérale (non prémultipliée) : " .. table.concat(brut, " | "))
end

-- §6 traductions
local function cfg(p)
  local t, sec = {}, ""
  for line in read(p):gmatch("[^\r\n]+") do
    local s = line:match("^%[([%w%-_]+)%]$")
    if s then sec = s else
      local k, v = line:match("^([%w%-_]+)=(.*)$")
      if k then t[sec .. "." .. k] = v end
    end
  end
  return t
end
local FR, EN = cfg("locale/fr/experimentaux.cfg"), cfg("locale/en/experimentaux.cfg")
local keys = {}
for _, r in ipairs(Xp.ROBOTS) do
  for _, k in ipairs({ "entity-name.", "entity-description.", "item-description.", "technology-name.", "technology-description." }) do
    keys[#keys + 1] = k .. r.name
  end
end
-- noms des effets que le prototype nomme par { "entity-name." .. Xp.PREFIX .. "<effet>" } ou { "entity-name." .. f.name }
for rest in PROTO:gmatch('"entity%-name%." %.%. Xp%.PREFIX %.%. "([%w%-_]+)"') do keys[#keys + 1] = "entity-name.fo-xp-" .. rest end
keys[#keys + 1] = "entity-name.fo-xp-demi-vie-fusion"
keys[#keys + 1] = "item-subgroup-name." .. Xp.SUBGROUP
keys[#keys + 1] = "ammo-category-name." .. Xp.AMMO_CATEGORY
for _, k in ipairs(keys) do check(FR[k] ~= nil and EN[k] ~= nil and FR[k] ~= "" and EN[k] ~= "", "§6 clé en FR et EN : " .. k) end
local same = true
for k in pairs(FR) do if not EN[k] then same = false end end -- comparaison d'ensembles : l'ordre ne compte pas
for k in pairs(EN) do if not FR[k] then same = false end end
check(same, "§6 FR et EN : mêmes clés")

-- §7 mutants (chaque règle de shared/robots/experimentaux.lua)
local MUTANTS = {
  { "Mât-Foudre à l'âge 5", 'id = "mat-foudre", src = "mat_foudre", age = 6', 'id = "mat-foudre", src = "mat_foudre", age = 5' },
  { "Géode à l'Atelier", 'kind = "unit-capsule", factory = "fo-robotics-bay", after = "fo-robot-bay"', 'kind = "unit-capsule", factory = "fo-robot-workshop", after = "fo-robot-bay"' },
  { "Veilleuse après une technologie d'un autre âge", 'factory = "fo-robot-gantry", after = "fo-robot-gantry"', 'factory = "fo-robot-gantry", after = "fo-robot-levite"' },
  { "ingrédient au-delà de 100", '{ "battery", 100 }, { "steel-plate", 100 }, { "engine-unit", 60 }', '{ "battery", 101 }, { "steel-plate", 100 }, { "engine-unit", 60 }' },
  { "coût de la Sarracénie divisé", '{ "fo-methane-barrel", 100 }, { "fo-servo-motor", 50 }', '{ "fo-methane-barrel", 10 }, { "fo-servo-motor", 5 }' },
  { "ingrédient en double", '{ "fo-lead-plate", 100 }, { "advanced-circuit", 100 }', '{ "uranium-238", 100 }, { "advanced-circuit", 100 }' },
  { "technologie au prix du robot", "Xp.TECH_FACTOR = 2", "Xp.TECH_FACTOR = 1" },
  { "Demi-Vie au processeur (âge 10)", '{ "advanced-circuit", 100 }, { "fo-servo-motor", 70 },', '{ "processing-unit", 40 }, { "fo-servo-motor", 70 },' },
  { "Demi-Vie à 30 servomoteurs", '{ "advanced-circuit", 100 }, { "fo-servo-motor", 70 },', '{ "advanced-circuit", 100 }, { "fo-servo-motor", 30 },' },
  { "segment du Cairn avec une pièce de l'âge 11", '{ "processing-unit", 30 }, { "fo-guidance-core", 10 }', '{ "fo-graphics-card", 30 }, { "fo-guidance-core", 10 }' },
  { "PV de la valeur au lieu de la règle d'échelle", "out.hp = Ech.pv(r.age)", "out.hp = ref.hp * k" },
  { "résistances oubliées", "out.resistances = Ech.resistances(r.age)", "out.resistances = {}" },
  { "salve d'un âge de moins", "out.salve = Ech.salve(r.age, r.dtype)", "out.salve = Ech.salve(r.age - 1, r.dtype)" },
  { "zone d'un âge de moins", "out.zone, out.cratere = Ech.rayon(r.age), Ech.cratere(r.age)", "out.zone, out.cratere = Ech.rayon(r.age - 1), Ech.cratere(r.age)" },
  { "salve de zone à la cadence de l'effet", "out.zone_cooldown = math.max(r.cooldown, Ech.CADENCE_ZONE)", "out.zone_cooldown = r.cooldown" },
  { "petit sans la salve de son âge", "out.shot = math.max(out.shot, out.salve * ((r.jets and r.jets.count) or 1))", "out.shot = out.shot" },
  { "géants admis avant l'âge 10", "Xp.GIANT_EARLY_AGE = 10", "Xp.GIANT_EARLY_AGE = 9" },
  { "plafond des géants sans Ro", "return math.max(Ro.giant_allowed(age), early)", "return early" },
  { "géant admis au plafond", "return (have or 0) < Xp.giant_cap(age)", "return (have or 0) <= Xp.giant_cap(age)" },
  { "Cairn marque une cible de trop", "for i = 1, math.min(n, #all) do out[i] = all[i].c end", "for i = 1, math.min(n + 1, #all) do out[i] = all[i].c end" },
  { "coup non partagé", "return shot / math.max(1, n or 0)", "return shot" },
  { "circuit en diagonale", "local corner = { x = nd.x, y = cur.y }", "local corner = { x = nd.x, y = nd.y }" },
  { "circuit sans la cible", "local nodes = { target }", "local nodes = {}" },
  { "fissure sans prolongement", "local total = len + beyond", "local total = len" },
  { "Tournesol qui tire la nuit", "return (darkness or 0) < night", "return true" },
  { "Ixion coûte moitié", '{ "fo-superconducting-coil", 100 }, { "processing-unit", 100 }, { "fo-magnetic-actuator", 80 },', '{ "fo-superconducting-coil", 50 }, { "processing-unit", 50 }, { "fo-magnetic-actuator", 40 },' },
  { "Trombe au Portique", 'id = "trombe", src = "trombe", age = 12, kind = "giant", factory = "fo-robot-dock"', 'id = "trombe", src = "trombe", age = 12, kind = "giant", factory = "fo-robot-gantry"' },
  { "neuf segments", "Xp.SEGMENTS = 10", "Xp.SEGMENTS = 9" },
  { "valeur sans le rapport des coûts", "local k = r.mu / ref.mu", "local k = 1" },
  { "coup sans la cadence", "shot = round(dps * r.cooldown / 60, 0.1)", "shot = round(dps, 0.1)" },
  { "plus proche sans départage", "(d == bd and c.id < best.id)", "(d == bd and c.id > best.id)" },
  { "plus proche sans borne", "if d <= lim and", "if" },
  { "arc qui revient sur ses pas", "if not used[c.id] then pool[#pool + 1] = c end", "pool[#pool + 1] = c" },
  { "arc depuis la première cible à chaque saut", "    cur = nx\n", "\n" },
  { "pointes qui s'arrêtent avant la cible", "local t = i / count", "local t = i / (count + 1)" },
  { "jets du même côté", "local side = (#out % 2 == 1) and 1 or -1", "local side = 1" },
  { "chute à l'envers", "return amount * (1 - (1 - edge) * d / radius)", "return amount * (edge + (1 - edge) * d / radius)" },
  { "chute sans bord", "if d > radius then return 0 end", "" },
  { "zone triée sans départage", "return a.c.id < b.c.id", "return a.c.id > b.c.id" },
  { "zone qui dure un tick de trop", "return tick - t0 < r.contamination.duration", "return tick - t0 <= r.contamination.duration" },
  { "capsule de défense acceptée", "return r and r.is_unit and r or nil", "return r" },
  { "Demi-Vie réutilisable", "speed = 0.16, single_use = true,", "speed = 0.16," },
  { "charge de 20 s", "Xp.BURST_SECONDS = 30", "Xp.BURST_SECONDS = 20" },
  { "unité trop large pour les chemins", 'half = 0.8, range = 3', 'half = 2.5, range = 3' },
  { "Mât-Foudre à l'ancienne échelle", 'mu = 1800, time = 30, scale = 0.262, foot = 3,', 'mu = 1800, time = 30, scale = 1, foot = 3,' },
  { "Veilleuse en 11 × 11", 'mu = 42000, time = 10, scale = 0.215, foot = 3,', 'mu = 42000, time = 10, scale = 0.215, foot = 11,' },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = XP_SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local src = XP_SRC:sub(1, a - 1) .. m[3] .. XP_SRC:sub(b + 1)
    local f = load(src, "=mutant", "t")
    local f2 = 1
    if f then
      local ok, M = pcall(f)
      if ok and type(M) == "table" then
        local ok2, _, ff = pcall(suite, M)
        f2 = ok2 and ff or 1
      end
    end
    if f2 > 0 then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(#kept == 0, "§7 mutants NON refusés : " .. table.concat(kept, " ; "))

for _, m in ipairs(msgs) do print("[EXPERIMENTAUX] ECHEC " .. m) end
print(string.format("[EXPERIMENTAUX] feuilles relues : %d ; mutants refusés : %d sur %d", nfiles, refused, #MUTANTS))
print(string.format("[EXPERIMENTAUX] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
