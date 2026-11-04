--[[
  Paliers et styles de déchiqueteurs du lot EQUILIBRE (shared/content/enemies.lua) : 12 paliers, 6 familles, courbes
  d'apparition, traductions FR/EN, mode défense de tours inchangé. Lot BI-0 : tailles par famille (k), boîtes et plafond,
  moucheron en corps de petit cracheur, nid d'essaim. Pur Lua. Usage : lua5.2 tests/ennemis_test.lua
]]
package.path = "./?.lua;" .. package.path
local E = require("shared.content.enemies")
local passes, failures = 0, 0
local function check(c, m) if c then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. m) end end

--- Règle : liste des motifs de refus (vide = bon) pour un jeu de données de déchiqueteurs d.
local function verifier(d, locales)
  local out = {}
  if #d.tier_names ~= d.TIERS then out[#out + 1] = "noms de paliers != TIERS" end
  local seen = {}
  for _, n in ipairs(d.tier_names) do if seen[n] then out[#out + 1] = "nom en double " .. n end seen[n] = true end
  if #d.spawn_curves ~= d.TIERS then out[#out + 1] = "courbes != TIERS" end
  for t, c in ipairs(d.spawn_curves) do
    for i, p in ipairs(c) do
      if p[2] < 0 then out[#out + 1] = "poids negatif palier " .. t end
      if i > 1 and not (p[1] > c[i - 1][1]) then out[#out + 1] = "evolution non croissante palier " .. t end
      if p[1] < 0 or p[1] > 1 then out[#out + 1] = "evolution hors [0,1] palier " .. t end
    end
  end
  -- chaque évolution de 0 à 1 par pas de 0,01 est couverte par au moins un palier
  for i = 0, 100 do
    local evo, sum = i / 100, 0
    for _, c in ipairs(d.spawn_curves) do
      for k = 1, #c - 1 do
        if evo >= c[k][1] and evo <= c[k + 1][1] then
          local f = (evo - c[k][1]) / (c[k + 1][1] - c[k][1])
          sum = sum + c[k][2] + f * (c[k + 1][2] - c[k][2])
        end
      end
      if evo > c[#c][1] then sum = sum + c[#c][2] end
    end
    if sum <= 0 then out[#out + 1] = "evolution " .. evo .. " sans aucune unite" end
  end
  for t = d.VANILLA_TIERS + 1, d.TIERS do
    local nt, prev = d.new_tiers[t], d.new_tiers[t - 1]
    if not nt then out[#out + 1] = "palier " .. t .. " absent" else
      if not (nt.hp > 1 and nt.damage > 1 and nt.scale > 1 and nt.speed <= 1) then out[#out + 1] = "palier " .. t .. " incoherent" end
      if prev and not (nt.hp > prev.hp and nt.damage > prev.damage and nt.scale > prev.scale and nt.resist > prev.resist and nt.poll > prev.poll) then
        out[#out + 1] = "palier " .. t .. " pas plus fort que le " .. (t - 1) end
      if not d.worm_tiers[t] then out[#out + 1] = "ver du palier " .. t .. " absent" end
    end
  end
  for _, fam in ipairs(d.FAMILY_ORDER) do
    local f = d.families[fam]
    if not (f and f.hp and f.speed and f.damage and f.resist and f.tint1 and f.tint2 and f.glow and f.nest_distance) then
      out[#out + 1] = "famille " .. fam .. " incomplete"
    else
      for _, loc in ipairs(locales) do
        if not loc:find("family-" .. fam .. "=", 1, true) then out[#out + 1] = "famille " .. fam .. " sans traduction" end
        if not loc:find("fo-" .. fam .. "-nest=", 1, true) then out[#out + 1] = "nid " .. fam .. " sans traduction" end
      end
    end
  end
  for t = d.VANILLA_TIERS + 1, d.TIERS do
    for _, loc in ipairs(locales) do
      for _, k in ipairs({ "biter", "spitter", "worm-turret" }) do
        if not loc:find("fo-" .. d.tier_names[t] .. "-" .. k .. "=", 1, true) then out[#out + 1] = "palier " .. t .. " " .. k .. " sans traduction" end
      end
    end
  end
  return out
end
--- Règle BI-0 : motifs de refus (vide = bon) des tailles, boîtes et nids d'un jeu de données d (module rechargé : ses
--- fonctions lisent SES données). Tableau attendu : demi-côté de la boîte de collision d'un déchiqueteur à 3 paliers.
local BOITES = { -- famille = { palier 1 (base 0,2), palier 8 (base 0,4), palier 12 (base 0,4) } (PLAN §5 ter)
  armored = { 0.23, 0.84, 0.87 }, pyro = { 0.20, 0.73, 0.76 }, brood = { 0.22, 0.81, 0.84 },
  storm = { 0.18, 0.66, 0.68 }, toxic = { 0.25, 0.90, 0.90 }, swarm = { 0.12, 0.44, 0.46 },
}
local function verifier_tailles(d)
  local out = {}
  local ks = {}
  for _, fam in ipairs(d.FAMILY_ORDER) do
    local k = d.families[fam].size
    if type(k) ~= "number" or k < 0.5 or k > 1.3 then out[#out + 1] = "taille de " .. fam .. " absente ou hors de 0,5 a 1,3"
    else
      for _, o in ipairs(ks) do
        if math.abs(o - k) < 0.04 then out[#out + 1] = "deux familles de meme taille (" .. fam .. ")" end
      end
      ks[#ks + 1] = k
    end
  end
  local sw = d.families.swarm
  if not (sw.size and sw.size <= 0.7) then out[#out + 1] = "essaim pas nain" end
  if not (d.families.toxic.size and d.families.toxic.size >= 1.2) then out[#out + 1] = "toxique pas la plus grosse" end
  for _, fam in ipairs(d.FAMILY_ORDER) do
    if (fam == "swarm") ~= d.spitter_body("biter", fam) then out[#out + 1] = "corps de cracheur pour " .. fam end
    if d.spitter_body("spitter", fam) then out[#out + 1] = "cracheur " .. fam .. " change de corps" end
    local h = BOITES[fam]
    for i, c in ipairs({ { 1, 0.5, 0.2 }, { 8, d.new_tiers[8].scale, 0.4 }, { 12, d.new_tiers[12].scale, 0.4 } }) do
      local half = c[3] * d.box_factor(c[2], c[1], fam, c[3])
      if math.abs(half - h[i]) > 0.0051 then out[#out + 1] = string.format("boite %s palier %d : %.3f au lieu de %.2f", fam, c[1], half, h[i]) end
      if half > d.BOX_HALF_MAX + 1e-9 then out[#out + 1] = "boite " .. fam .. " au-dela du plafond" end
    end
  end
  -- sans famille : la boite vanilla, puis celle du palier (inchangee par BI-0)
  if d.box_factor(0.5, 1, nil, 0.2) ~= 1 or d.box_factor(1.2, 4, nil, 0.4) ~= 1 then out[#out + 1] = "boite vanilla modifiee" end
  if math.abs(d.box_factor(2.2, 8, nil, 0.4) - 2.2 / 1.2) > 1e-9 or math.abs(d.box_factor(9, 12, nil, 0.4) - 1.9) > 1e-9 then
    out[#out + 1] = "boite des paliers sans famille modifiee" end
  if math.abs(d.stats({ hp = 15, damage = 7, speed = 0.2, scale = 0.5 }, 1, "swarm").scale - 0.3) > 1e-9
    or d.stats({ hp = 15, damage = 7, speed = 0.2, scale = 0.5 }, 1).scale ~= 0.5 then out[#out + 1] = "echelle des statistiques" end
  -- nids : vanilla { 7 unites, 5 amis, cooldown 360 / 150 }
  local base = { max_count_of_owned_units = 7, max_friends_around_to_spawn = 5, spawning_cooldown = { 360, 150 } }
  for _, fam in ipairs(d.FAMILY_ORDER) do
    local n = d.nest_stats(fam, base)
    if fam == "swarm" then
      if not (n.max_count_of_owned_units == 14 and n.max_friends_around_to_spawn == 10 and n.spawning_cooldown[1] == 180 and n.spawning_cooldown[2] == 75) then
        out[#out + 1] = "nid d'essaim : " .. n.max_count_of_owned_units .. " / " .. n.max_friends_around_to_spawn .. " / " .. n.spawning_cooldown[1] .. " " .. n.spawning_cooldown[2] end
    elseif not (n.max_count_of_owned_units == 7 and n.max_friends_around_to_spawn == 5 and n.spawning_cooldown[1] == 360 and n.spawning_cooldown[2] == 150) then
      out[#out + 1] = "nid " .. fam .. " modifie"
    end
  end
  if base.spawning_cooldown[1] ~= 360 then out[#out + 1] = "nid vanilla ecrase par nest_stats" end
  return out
end
local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local LOC = { slurp("locale/fr/factorio-overhaul.cfg"), slurp("locale/en/factorio-overhaul.cfg") }
local function copy(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = copy(v) end return o end

local m0 = verifier(E, LOC)
check(#m0 == 0, "donnees livrees acceptees", table.concat(m0, " ; "))
check(E.TIERS == 12 and #E.FAMILY_ORDER == 6 and E.TD_TIERS == 8 and E.VANILLA_TIERS == 4, "12 paliers, 6 familles, tours a 8")
check(E.family_nest_share * #E.FAMILY_ORDER <= 1.65 and E.family_nest_share * #E.FAMILY_ORDER >= 1.55, "part totale des nids de famille conservee (~1,6)")
check(E.unit_name("biter", 12, "swarm") == "fo-swarm-eternal-biter" and E.unit_name("spitter", 9) == "fo-ancestral-spitter", "noms d'unites")
-- resistances de famille : la part fixe ne depasse jamais sa valeur du palier 8
local r8, r12 = E.family_resist(E.families.armored, 8), E.family_resist(E.families.armored, 12)
check(r12.physical[1] == r8.physical[1] and r12.physical[2] == r8.physical[2], "resistance de famille plafonnee au palier 8")
-- le mode defense de tours n'a que 8 couts
local TD = require("shared.td.waves")
check(TD.max_tier(200) == 8 and TD.boss_tier(200) == 8 and TD.unit_cost[TD.max_tier(200)] ~= nil, "defense de tours : palier max 8")

-- Lot BI-V1 : écraseur, classe neuve (chiffres écrits en dur, PLAN §5 ter)
do
  local attendu = { [6] = 72000, [8] = 450000, [10] = 2160000, [12] = 9900000 }
  for _, tier in ipairs({ 6, 8, 10, 12 }) do
    check(math.abs(E.crusher_stats(tier).hp - attendu[tier]) < 1, "ecraseur : PV du palier " .. tier)
    local poids = 0
    for _, pt in ipairs(E.crusher.curves[tier]) do poids = math.max(poids, pt[2]) end
    check(poids <= 0.05 and E.crusher.curves[tier][1][1] >= 0.78, "ecraseur rare, des 0,78 : palier " .. tier)
  end
  check(E.crusher_name(12) == "fo-crusher-eternal-biter" and E.crusher.radius == 3, "ecraseur : nom et rayon du coup")
end

-- Lot BI-0 : tailles, boites, moucheron, nid d'essaim
local SRC = slurp("shared/content/enemies.lua")
local function charger(src) return assert(load(src, "enemies", "t"))() end
local function muter(from, to)
  local out = SRC:gsub(from:gsub("%p", "%%%0"), (to:gsub("%%", "%%%%")), 1)
  return out
end
local t0 = verifier_tailles(charger(SRC))
check(#t0 == 0, "tailles, boites et nids livres acceptes : " .. table.concat(t0, " ; "))
check(E.size("swarm") == 0.6 and E.size("toxic") == 1.25 and E.size(nil) == 1 and E.size("inconnue") == 1, "taille k par famille, 1 sans famille")
check(E.BOX_HALF_MAX == 0.9, "plafond de boite a 0,9")
local MUT_TAILLES = {
  { "k du toxique retire", "size = 1.25,", "" },
  { "k de l'essaim a 1 (deux familles de meme taille, essaim pas nain)", "size = 0.6,", "size = 1.0," },
  { "essaim a 0,85", "size = 0.6,", "size = 0.85," },
  { "cornu a la taille du tison", "size = 0.9,", "size = 1.0," },
  { "plafond de boite retire", "f = math.min(f, E.BOX_HALF_MAX / base_half)", "f = f" },
  { "plafond a 1,2", "E.BOX_HALF_MAX = 0.9", "E.BOX_HALF_MAX = 1.2" },
  { "k ignore dans la boite", "f = f * E.size(family)", "f = f" },
  { "boite vanilla (paliers 1-4) agrandie", "(tier > E.VANILLA_TIERS) and math.min(scale / 1.2, 1.9) or 1", "math.min(scale / 1.2, 1.9)" },
  { "boite des paliers sans plafond de 1,9", "math.min(scale / 1.2, 1.9)", "scale / 1.2" },
  { "k ignore dans les statistiques", "s.scale = s.scale * E.size(family)", "" },
  { "moucheron sans corps de cracheur", "biter_body = \"spitter\",", "" },
  { "tous les biters en corps de cracheur", "kind == \"biter\" and f ~= nil and f.biter_body == \"spitter\"", "kind == \"biter\"" },
  { "les cracheurs d'essaim changent aussi de corps", "return kind == \"biter\" and f ~= nil", "return f ~= nil" },
  { "nid d'essaim a une fois plus d'unites", "units = 2,", "units = 1," },
  { "nid d'essaim a cooldown inchange", "cooldown_div = 2", "cooldown_div = 1" },
  { "limite d'amis non suivie", "base.max_friends_around_to_spawn * n.units", "base.max_friends_around_to_spawn" },
  { "nid d'essaim a quatre fois plus d'unites", "base.max_count_of_owned_units * n.units", "base.max_count_of_owned_units * n.units * 2" },
  { "cooldown du nid vanilla ecrase", "local cd = {}", "local cd = base.spawning_cooldown" },
}
for _, mu in ipairs(MUT_TAILLES) do
  local src = muter(mu[2], mu[3])
  check(src ~= SRC, "mutant applicable : " .. mu[1])
  check(#verifier_tailles(charger(src)) > 0, "mutant refuse : " .. mu[1])
end

-- Mutants : chacun doit etre refuse par la regle
local muts = {
  { "courbe non croissante", function(d) d.spawn_curves[9][2][1] = 0.80 end },
  { "poids negatif", function(d) d.spawn_curves[10][2][2] = -0.1 end },
  { "palier 11 plus faible que le 10", function(d) d.new_tiers[11].hp = 100 end },
  { "ver du palier 12 absent", function(d) d.worm_tiers[12] = nil end },
  { "famille sans lueur", function(d) d.families.toxic.glow = nil end },
  { "nom de palier en double", function(d) d.tier_names[12] = "eternal" d.tier_names[11] = "eternal" end },
  { "un trou d'evolution", function(d) d.spawn_curves = { d.spawn_curves[1], table.unpack(d.spawn_curves, 2, 11), { { 0.99, 0.0 }, { 1.0, 0.0 } } } end },
  { "palier 12 supprime des courbes", function(d) d.spawn_curves[12] = nil end },
  { "palier 9 plus grand que le 10", function(d) d.new_tiers[9].scale = 5 end },
}
for _, mu in ipairs(muts) do
  local d = copy(E)
  mu[2](d)
  check(#verifier(d, LOC) > 0, "mutant refuse : " .. mu[1])
end
local noloc = { LOC[1]:gsub("family%-swarm=", "x-swarm="), LOC[2] }
check(#verifier(E, noloc) > 0, "mutant refuse : traduction FR de la famille essaim retiree")
local noloc2 = { LOC[1], (LOC[2]:gsub("fo%-eternal%-biter=", "x=")) }
check(#verifier(E, noloc2) > 0, "mutant refuse : traduction EN du biter eternel retiree")
print(string.format("[ENNEMIS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
