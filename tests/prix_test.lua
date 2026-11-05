--[[
  Lot SOUS-PRODUITS (5/11) : test hors jeu de la règle PURE shared/ai3/prix.lua (pas encore branchée).
  Critères écrits avant le code : fo-logs/2026-11-05_SOUS-PRODUITS/CRITERES.md (P1 à P6).

    §1 scènes synthétiques : produit principal qui porte tout (B2) puis crédité (B3) ; sous-produit au prix de sa propre voie ;
       déchet à 0 ; récupération écartée si une voie primaire existe, utilisée sinon ; entrée principale solide avant fluide ;
       catalyseur en forme nette ; co-produits à parts égales ; crédits croisés qui ne se stabilisent pas -> B2 rendu et signalé ;
    §2 relevé du 5/11 (tests/fixtures/recipes_0511.lua ; HYPOTHÈSE : minerais et fluides du mod absents des données des leviers à
       1 MU par unité, eau sans prix) : prix calculés à la main ;
    §4 tous les noms changés et relevé en ordre inverse : mêmes prix ;
    §5 mutants, chacun refusé par un contrôle.
  Usage : lua5.2 tests/prix_test.lua   (depuis la racine du mod)
  Ce fichier est du TEST : §2 à §4 nomment des prototypes (comme le moteur) ; la règle n'en voit rien.
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[PRIX] ECHEC : " .. msg) end
  end
end
local function near(a, b, tol) return a ~= nil and b ~= nil and math.abs(a - b) <= (tol or 1e-9) * math.max(1, math.abs(b)) end
local function f4(v) return v and string.format("%.4f", v) or "nil" end

local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read_src("shared/ai3/prix.lua")
local function load_px(src) return assert(load(src, "@shared.ai3.prix"))() end

local C = require("tests.leviers_common")
local Ca = require("shared.ai3.capitalisation")

---------------------------------------------------------------------------------------------------
-- Scènes synthétiques : D au format de Ca.data (listes triées par nom), aucun nom du jeu.
---------------------------------------------------------------------------------------------------
local function I(name, amount, fluid) return { name = name, amount = amount, fluid = fluid } end
local function mkD(recipes)
  local list = {}
  for k in pairs(recipes) do list[#list + 1] = k end
  table.sort(list)
  for _, rn in ipairs(list) do
    local r = recipes[rn]
    table.sort(r.ingredients, function(a, b) return a.name < b.name end)
    table.sort(r.products, function(a, b) return a.name < b.name end)
    r.name = rn
  end
  return { res_list = { "minerai" }, res = { minerai = { mining_time = 1 } }, recipe_list = list, recipes = recipes }
end
local O = { raw_mu = 1, time_mu = 0.1 }

-- S1 : principal X et sous-produit B ; B a sa propre voie (3,1) ; à parts égales, la recette « a » le donnerait à 0,7.
local function S1() return mkD({
  ["a-principal"] = { energy = 1, ingredients = { I("minerai", 2) }, products = { I("x", 1), I("b", 2) }, main = "x" },
  ["b-propre"] = { energy = 1, ingredients = { I("minerai", 3) }, products = { I("b", 1) } },
}) end
-- S2 : déchet W (sous-produit sans autre voie) ; récupération d (entrée principale W) écartée car Z a une voie primaire ;
-- récupération f seule voie de V : utilisée ; l : 40 de fluide déchet F et 2 de solide S -> entrée principale S, pas une récupération.
local function S2(with_primary) local r = {
  ["c-principal"] = { energy = 1, ingredients = { I("minerai", 4) }, products = { I("y", 1), I("w", 1) }, main = "y" },
  ["d-recup"] = { energy = 1, ingredients = { I("w", 2), I("minerai", 1) }, products = { I("z", 1) } },
  ["f-recup"] = { energy = 1, ingredients = { I("w", 3) }, products = { I("v", 1) } },
  ["g-fluide"] = { energy = 1, ingredients = { I("minerai", 1) }, products = { I("t", 1), I("f", 10, true) }, main = "t" },
  ["h-solide"] = { energy = 1, ingredients = { I("minerai", 2) }, products = { I("s", 1) } },
  ["l-melange"] = { energy = 1, ingredients = { I("f", 40, true), I("s", 2) }, products = { I("u", 1) } },
  }
  if with_primary then r["e-primaire"] = { energy = 1, ingredients = { I("minerai", 5) }, products = { I("z", 1) } } end
  return mkD(r)
end
-- S3 : catalyseur H (25 en entrée, 90 en sortie) et co-produits sans principal.
local function S3() return mkD({
  ["h-catalyse"] = { energy = 5, ingredients = { I("minerai", 10), I("h", 25) }, products = { I("h", 90), I("g", 10) } },
  ["i-coproduits"] = { energy = 1, ingredients = { I("minerai", 3) }, products = { I("p", 1), I("q", 2) } },
}) end
-- S5 : crédits croisés : M principal de j (2 N en sous-produit), N principal de k (2 M en sous-produit).
local function S5() return mkD({
  ["j-m"] = { energy = 0, ingredients = { I("minerai", 5) }, products = { I("m", 1), I("n", 2) }, main = "m" },
  ["k-n"] = { energy = 0, ingredients = { I("minerai", 5) }, products = { I("n", 1), I("m", 2) }, main = "n" },
}) end

---------------------------------------------------------------------------------------------------
-- Relevé du 5/11 (hypothèse : minerais et fluides du mod à 1 MU par unité ; eau sans prix).
---------------------------------------------------------------------------------------------------
local SOLID = { "fo-bauxite", "fo-cassiterite", "fo-galena", "fo-ilmenite-ore", "fo-monazite-ore", "fo-resonance-crystal",
  "fo-sphalerite", "fo-tungsten-ore", "wood", "raw-fish" }
local FLUID = { "fo-brine", "fo-methane", "fo-volcanic-gas" }
local function add_res(d)
  for _, n in ipairs(SOLID) do d.resources[#d.resources + 1] = { entity = n, category = "basic-solid", products = { { type = "item", name = n, amount = 1 } } } end
  for _, n in ipairs(FLUID) do d.resources[#d.resources + 1] = { entity = n, category = "basic-fluid", products = { { type = "fluid", name = n, amount = 1 } } } end
end
local FIX = "tests/fixtures/recipes_0511.lua"
local function dump0(reverse) return C.dump(nil, { recipes_file = FIX, mutate = add_res, reverse = reverse }) end
local D = Ca.data(dump0(), {})
local OD = { raw_mu = Ca.RAW_MU, time_mu = Ca.TIME_MU, skip = Ca.unpackers(D) }

local WATCH = { "iron-plate", "copper-plate", "fo-coke", "fo-graphite", "steel-plate", "fo-slag", "fo-red-mud", "fo-zinc-plate",
  "fo-hydrogen", "fo-chlorine", "fo-magnesium", "fo-magnesium-chloride", "fo-caustic-soda", "steam", "petroleum-gas", "plastic-bar",
  "electronic-circuit", "copper-cable", "advanced-circuit", "productivity-module", "fo-titanium-slag", "fo-titanium-tetrachloride",
  "fo-titanium-sponge", "fo-cement" }
--- Faits : ce que la règle rend sur toutes les scènes (comparés aux mutants).
local function facts(Px)
  local r = {}
  local mu, best, info = Px.values(S1(), O)
  r.s1_x, r.s1_b, r.s1_bb = mu.x, mu.b, best.b
  local mu2 = Px.values(S1(), { raw_mu = 1, time_mu = 0.1, credit = false })
  r.s1_x2 = mu2.x
  mu, best, info = Px.values(S2(true), O)
  r.s2_w, r.s2_z, r.s2_zb, r.s2_v, r.s2_u = mu.w, mu.z, best.z, mu.v, mu.u
  r.s2_rec = table.concat(info.recovery, ",")
  r.s2_waste = table.concat(info.waste, ",")
  mu, best = Px.values(S2(false), O)
  r.s2n_z, r.s2n_zb = mu.z, best.z
  mu = Px.values(S3(), O)
  r.s3_h, r.s3_g, r.s3_p, r.s3_q = mu.h, mu.g, mu.p, mu.q
  mu, best, info = Px.values(S5(), { raw_mu = 1, time_mu = 0.1, max_rounds = 3 })
  r.s5_m, r.s5_n, r.s5_fb, r.s5_rounds = mu.m, mu.n, info.fallback, info.rounds
  mu, best, info = Px.values(D, OD)
  r.real = {}
  for _, n in ipairs(WATCH) do r.real[n] = mu[n]; r.real[n .. "@"] = best[n] end
  r.real_rounds, r.real_fb = info.rounds, info.fallback
  r.real_waste = table.concat(info.waste, ",")
  r.real_rec = table.concat(info.recovery, ",")
  return r
end

local Px0 = load_px(SRC)
local F = facts(Px0)

---------------------------------------------------------------------------------------------------
-- §1 scènes synthétiques
---------------------------------------------------------------------------------------------------
check(near(F.s1_b, 3.1) and F.s1_bb == "b-propre", "§1 sous-produit au prix de SA voie, jamais fixé où il est sous-produit (" .. f4(F.s1_b) .. ")")
check(near(F.s1_x2, 2.1), "§1 B2 : le principal porte tout le coût (2 + 0,1 = 2,1 ; " .. f4(F.s1_x2) .. ")")
check(near(F.s1_x, 0), "§1 B3 : principal crédité de ses sous-produits, jamais sous 0 (2,1 - 2 x 3,1 -> 0 ; " .. f4(F.s1_x) .. ")")
check(F.s2_waste == "f,w" and near(F.s2_w, 0), "§1 déchets : sous-produits sans autre voie à 0, le fluide F et W (" .. F.s2_waste .. ")")
check(near(F.s2_z, 5.1) and F.s2_zb == "e-primaire", "§1 récupération écartée : Z vient de sa voie primaire 5,1 (" .. f4(F.s2_z) .. ", " .. tostring(F.s2_zb) .. ")")
check(near(F.s2n_z, 1.1) and F.s2n_zb == "d-recup", "§1 sans voie primaire, la récupération fixe Z : 0 + 1 + 0,1 (" .. f4(F.s2n_z) .. ")")
check(near(F.s2_v, 0.1), "§1 récupération seule voie de V : 0 + 0,1 (" .. f4(F.s2_v) .. ")")
check(F.s2_rec == "d-recup,f-recup" and near(F.s2_u, 0 * 40 + 2 * 2.1 + 0.1),
  "§1 entrée principale : le solide avant le fluide ; l (40 fluide déchet, 2 solides) n'est pas une récupération (" .. F.s2_rec .. ")")
check(near(F.s3_h, 10.5 / 75) and near(F.s3_g, 10.5 / 75), "§1 forme nette : catalyseur retiré, 10 + 0,5 pour 65 + 10 (" .. f4(F.s3_h) .. ")")
check(near(F.s3_p, 3.1 / 3) and near(F.s3_q, 3.1 / 3), "§1 co-produits sans principal : parts égales 3,1 / 3")
check(F.s5_fb == true and F.s5_rounds == 3 and near(F.s5_m, 5) and near(F.s5_n, 5),
  "§1 crédits croisés sans stabilité : plafond de tours, B2 rendu (5 et 5) et signalé (" .. f4(F.s5_m) .. ", " .. f4(F.s5_n) .. ")")

---------------------------------------------------------------------------------------------------
-- §2 relevé du 5/11 : valeurs calculées à la main (CRITERES.md)
---------------------------------------------------------------------------------------------------
local H2 = (50 + 100 * (100.1 / 71) + 0.2) / 200
local CL = (100 + 0.3 - 40 * H2) / 40
local TISLAG = 2 * 8.1 + 2 * 1.7 + 0.1 - 6 * ((8.1 + 0.0533 + 0.1) / 8)
local TICL4 = (TISLAG + 1.7 + 60 * CL + 0.5) / 40
local GAS = (10 + 50 * (100.1 / 71) + 0.5) / 95
local FE = (8 + 0.1 + 0.0533 + 0.1) / 8
local CABLE, EC = (FE + 0.05) / 2, nil
EC = 3 * CABLE + FE + 0.05
local PLAST = (1 + 20 * GAS + 0.1) / 2
local AC = 4 * CABLE + 2 * EC + 2 * PLAST + 0.6
local WANT = {
  { "iron-plate", FE, "fo-iron-plate-r8-unpacking", "concentré 8,1, paquet + 0,0533, 8 plaques + 0,1 ; boue rouge écartée" },
  { "copper-plate", FE, "fo-copper-plate-r8-unpacking", "comme le fer" },
  { "fo-coke", 1.7, "fo-coke", "(3 + 0,4) / 2" },
  { "fo-graphite", (4 * 1.7 + 0.6) / 3, "fo-graphite", "(4 x 1,7 + 0,6) / 3" },
  { "steel-plate", 3 * FE + (4 * 1.7 + 0.6) / 3 + 0.3, "fo-arc-steel", "acier électrique (haut fourneau 7,03, recette 6,76)" },
  { "fo-slag", 0, nil, "déchet" }, { "fo-red-mud", 0, nil, "déchet" }, { "fo-magnesium-chloride", 0, nil, "déchet" },
  { "fo-caustic-soda", 0, nil, "déchet" },
  { "fo-zinc-plate", (4 + 1 + 0.6) / 2, "fo-zinc-retort", "cornue, laitier déchet" },
  { "steam", 100.1 / 71, "fo-volcanic-gas-separation", "co-produits (100 + 0,1) / 71" },
  { "fo-hydrogen", H2, "fo-methane-reforming", "reformage, CO2 déchet" },
  { "fo-chlorine", CL, "fo-brine-electrolysis", "saumure moins 40 hydrogènes" },
  { "fo-magnesium", 0, "fo-magnesium-electrolysis", "0,3 - 15 chlores < 0" },
  { "fo-titanium-slag", TISLAG, "fo-ilmenite-smelting", "ilménite moins 6 plaques de fer" },
  { "fo-titanium-tetrachloride", TICL4, "fo-chlorination", "chloration" },
  { "fo-titanium-sponge", 40 * TICL4 + 0.05, "fo-kroll-reduction", "Kroll, magnésium 0, MgCl2 déchet" },
  { "petroleum-gas", GAS, "coal-liquefaction", "liquéfaction nette (catalyseur 25 retiré)" },
  { "plastic-bar", PLAST, "plastic-bar", "(1 + 20 gaz + 0,1) / 2" },
  { "advanced-circuit", AC, "advanced-circuit", "4 câbles + 2 circuits + 2 plastiques + 0,6" },
  { "productivity-module", 5 * AC + 5 * EC + 1.5, "productivity-module", "5 circuits avancés + 5 circuits + 1,5" },
}
for _, w in ipairs(WANT) do
  local v, b = F.real[w[1]], F.real[w[1] .. "@"]
  check(near(v, w[2], 1e-6) and b == w[3], string.format("§2 %s = %s via %s (main : %.4f via %s ; %s)", w[1], f4(v), tostring(b), w[2],
    tostring(w[3]), w[4]))
end
check(F.real_rounds == 2 and F.real_fb == false, "§2 crédits stables en 2 tours, sans repli (" .. tostring(F.real_rounds) .. ")")
check(F.real_waste:find("fo-slag", 1, true) and F.real_rec:find("fo-red-mud-iron", 1, true) ~= nil,
  "§2 laitier déchet, fer de la boue rouge en récupération")

---------------------------------------------------------------------------------------------------
-- §4 noms changés, ordre inverse
---------------------------------------------------------------------------------------------------
do
  local d0 = dump0()
  local map = C.name_map(d0)
  local d2 = C.rename(d0, map)
  for _, rn in ipairs(C.sorted_keys(d0.recipes)) do
    local mp = d0.recipes[rn].main_product
    if mp and mp ~= "" then d2.recipes[map[rn]].main_product = map[mp] end
  end
  local Db = Ca.data(d2, {})
  local mua = Px0.values(D, OD)
  local mub = Px0.values(Db, { raw_mu = Ca.RAW_MU, time_mu = Ca.TIME_MU, skip = Ca.unpackers(Db) })
  local bad, n = 0, 0
  for _, k in ipairs(C.sorted_keys(mua)) do
    n = n + 1
    if not near(mub[map[k] or k], mua[k], 1e-9) then bad = bad + 1 end
  end
  -- 270 objets ont un prix sur le relevé du 5/11 (le garde-fou de 300 écrit avant le premier passage était une estimation).
  check(n >= 270 and bad == 0, string.format("§4 tous les noms changés : mêmes prix (%d objets, %d écarts)", n, bad))
  local Dr = Ca.data(dump0(true), {})
  local mur = Px0.values(Dr, { raw_mu = Ca.RAW_MU, time_mu = Ca.TIME_MU, skip = Ca.unpackers(Dr) })
  bad = 0
  for _, k in ipairs(C.sorted_keys(mua)) do if not near(mur[k], mua[k], 1e-9) then bad = bad + 1 end end
  check(bad == 0, "§4 relevé en ordre inverse : mêmes prix (" .. bad .. " écarts)")
end

---------------------------------------------------------------------------------------------------
-- §5 mutants
---------------------------------------------------------------------------------------------------
local function same(A, B)
  for _, k in ipairs(C.sorted_keys(A)) do
    local a, b = A[k], B[k]
    if type(a) == "table" then
      if type(b) ~= "table" or not same(a, b) or not same(b, a) then return false end
    elseif a ~= b then return false end
  end
  for _, k in ipairs(C.sorted_keys(B)) do if A[k] == nil then return false end end
  return true
end
local MUTANTS = {
  { "produit principal ignoré", "if #prod >= 2 and r.main then", "if false then" },
  { "crédit ignoré", "elseif credit then cr = cr + p.amount * (credit[p.name] or 0) end", "end" },
  { "déchet laissé sans prix", "if p.name ~= r.main and mu0[p.name] == nil and not D.res[p.name] then waste[p.name] = 0 end", "" },
  { "forme brute", "local a = inq[n] - math.min(inq[n], outq[n] or 0)", "local a = inq[n]" },
  { "récupération non écartée", "if pr and waste[pr] ~= nil then rec[rn] = true end", "" },
  { "entrée principale prise au fluide", "for _, want_fluid in ipairs({ false, true }) do", "for _, want_fluid in ipairs({ true, false }) do" },
  { "plafond sans retour à B2", "  info.fallback = true\n  return mu2, best2, info", "  info.fallback = true\n  return prev, best2, info" },
  { "repli non signalé", "  info.fallback = true\n", "" },
  { "récupération jamais utilisée", "if next(open) ~= nil then mu, best = fixpoint(ctx, credit, waste, rec, open) end", "" },
}
local caught, crashed = 0, 0
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a or SRC:find(m[2], b + 1, true) then check(false, "mutant « " .. m[1] .. " » : texte introuvable ou ambigu")
  else
    local ok, G = pcall(function() return facts(load_px(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))) end)
    if not ok then crashed = crashed + 1 end
    local refused = ok and not same(F, G)
    if refused then caught = caught + 1 end
    check(refused, "mutant « " .. m[1] .. " » refusé par un contrôle" .. (ok and "" or (" (plantage : " .. tostring(G) .. ")")))
  end
end
print(string.format("[PRIX] mutants refusés : %d sur %d (plantages : %d)", caught, #MUTANTS, crashed))
print(string.format("[PRIX] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
