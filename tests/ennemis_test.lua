--[[
  Paliers et styles de déchiqueteurs du lot EQUILIBRE (shared/content/enemies.lua) : 12 paliers, 6 familles, courbes
  d'apparition, traductions FR/EN, mode défense de tours inchangé. Pur Lua. Usage : lua5.2 tests/ennemis_test.lua
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
