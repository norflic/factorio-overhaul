--[[
  Lot VALEURS (corr-valeurs, 5/11) : test hors jeu de la règle « une recette qui défait exactement une autre ne fixe pas le
  prix » de Ca.values (shared/ai3/capitalisation.lua, Ca.unpackers). Critères écrits avant le code :
  fo-logs/2026-11-05_VALEURS/CRITERES.md (V1 à V5).

    §1 scène synthétique (aucun nom du jeu) : contenant rempli et vidé de deux fluides, l'un fait par une recette,
       l'autre presque gratuit ; recette « presque inverse » (autre quantité) gardée ; couple à autant de sortes des deux
       côtés gardé ; ordre des ingrédients différent d'un sens à l'autre ;
    §2 données des leviers (tests/leviers_common.lua) : prix de la chaîne du pétrole calculés à la main (V1), recettes
       écartées toutes de la forme « 1 contenant plein -> contenant + contenu », aucun couple à sortes égales, point fixe
       atteint ; contre la même règle retirée : aucun prix ne baisse (V2), aucun objet ne perd son prix (V3) ;
    §3 mutants (V5) : chacun refusé par un contrôle, pas par un plantage.
  Usage : lua5.2 tests/valeurs_test.lua   (depuis la racine du mod)
  Ce fichier est du TEST : le §2 nomme des prototypes vanilla (comme le moteur) ; la règle n'en voit rien.
]]
package.path = "./?.lua;" .. package.path

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[VALEURS] ECHEC : " .. msg) end
  end
end

local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read_src("shared/ai3/capitalisation.lua")
local function load_ca(src) return assert(load(src, "@shared.ai3.capitalisation"))() end
local function near(a, b, eps) return a ~= nil and b ~= nil and math.abs(a - b) <= (eps or 1e-9) end

---------------------------------------------------------------------------------------------------
-- Scène synthétique : D au format lu par Ca.values (res_list, res, recipe_list, recipes).
---------------------------------------------------------------------------------------------------
local function I(name, amount) return { name = name, amount = amount } end
local function scene(over)
  local recipes = {
    -- fluide A : 100 minerai -> 45 A en 5 s : (100 + 0,5) / 45 = 2,2333 MU
    ["a-fluide-a"] = { energy = 5, ingredients = { I("minerai", 100) }, products = { I("fluide-a", 45) } },
    -- fluides B et C presque gratuits : aucune entrée, 2 s -> 65 unités : 0,2 / 65 MU
    ["b-air"] = { energy = 2, ingredients = {}, products = { I("fluide-b", 50), I("fluide-c", 15) } },
    -- plaque 1 + 0,32 = 1,32 ; contenant vide 1,32 + 0,1 = 1,42
    ["c-plaque"] = { energy = 3.2, ingredients = { I("minerai", 1) }, products = { I("plaque", 1) } },
    ["d-contenant"] = { energy = 1, ingredients = { I("plaque", 1) }, products = { I("contenant", 1) } },
    -- remplir et vider : ingrédients et produits échangés, listés dans un ORDRE DIFFÉRENT d'un sens à l'autre
    ["e-remplir-a"] = { energy = 0.2, ingredients = { I("contenant", 1), I("fluide-a", 50) }, products = { I("plein-a", 1) } },
    ["f-vider-a"] = { energy = 0.2, ingredients = { I("plein-a", 1) }, products = { I("fluide-a", 50), I("contenant", 1) } },
    ["g-remplir-b"] = { energy = 0.2, ingredients = { I("fluide-b", 50), I("contenant", 1) }, products = { I("plein-b", 1) } },
    ["h-vider-b"] = { energy = 0.2, ingredients = { I("plein-b", 1) }, products = { I("contenant", 1), I("fluide-b", 50) } },
    -- couple à autant de sortes des deux côtés (1 <-> 1) : gardé
    ["i-aller"] = { energy = 1, ingredients = { I("plaque", 2) }, products = { I("tige", 1) } },
    ["j-retour"] = { energy = 1, ingredients = { I("tige", 1) }, products = { I("plaque", 2) } },
  }
  for k, v in pairs(over or {}) do recipes[k] = v end
  local list = {}
  for k in pairs(recipes) do list[#list + 1] = k end
  table.sort(list)
  return { res_list = { "minerai" }, res = { minerai = { mining_time = 1 } }, recipe_list = list, recipes = recipes }
end
-- Variante : le vidage de A rend 40 au lieu de 50 (« presque inverse ») : il n'est PAS écarté.
local function scene_presque()
  return scene({ ["f-vider-a"] = { energy = 0.2, ingredients = { I("plein-a", 1) }, products = { I("fluide-a", 40), I("contenant", 1) } } })
end

local function set_text(t)
  local ks = {}
  for k, v in pairs(t or {}) do if v then ks[#ks + 1] = k end end
  table.sort(ks)
  return table.concat(ks, ",")
end

-- Prix sur les données des leviers (tests/leviers_common.lua) : objets suivis et recette retenue.
local C = require("tests.leviers_common")
local WATCH = { "petroleum-gas", "empty-barrel", "petroleum-gas-barrel", "plastic-bar", "advanced-circuit", "productivity-module",
  "speed-module", "iron-plate", "steel-plate" }

local function facts(Ca)
  local r = {}
  local S = scene()
  r.skip = set_text(Ca.unpackers(S))
  local mu, best = Ca.values(S)
  r.a, r.cont, r.plein_a, r.plein_b, r.tige, r.b = mu["fluide-a"], mu["contenant"], mu["plein-a"], mu["plein-b"], mu["tige"], mu["fluide-b"]
  r.best_a, r.best_cont = best["fluide-a"], best["contenant"]
  local P = scene_presque()
  r.skip_presque = set_text(Ca.unpackers(P))
  local D = C.data()
  local mu2, best2 = Ca.values(D)
  r.real_mu, r.real_best = {}, {}
  for _, k in ipairs(WATCH) do r.real_mu[k], r.real_best[k] = mu2[k], best2[k] end
  r.real_all = mu2
  r.real_skip = Ca.unpackers(D)
  r.D = D
  return r
end

local Ca0 = load_ca(SRC)
local F = facts(Ca0)

---------------------------------------------------------------------------------------------------
-- §1 scène synthétique
---------------------------------------------------------------------------------------------------
check(F.skip == "f-vider-a,h-vider-b", "§1 écartés : les deux vidages, et eux seuls (" .. F.skip .. ")")
check(near(F.a, 100.5 / 45), string.format("§1 fluide A au prix de sa recette 100,5 / 45 = 2,2333 (%s, via %s)", tostring(F.a), tostring(F.best_a)))
check(F.best_a == "a-fluide-a", "§1 fluide A : recette retenue « a-fluide-a » (" .. tostring(F.best_a) .. ")")
check(near(F.cont, 1.42) and F.best_cont == "d-contenant", string.format("§1 contenant vide 1,32 + 0,1 = 1,42 par sa recette (%s)", tostring(F.cont)))
check(near(F.plein_a, 1.42 + 50 * 100.5 / 45 + 0.02), string.format("§1 contenant plein de A : 1,42 + 50 x 2,2333 + 0,02 (%s)", tostring(F.plein_a)))
check(near(F.plein_b, 1.42 + 50 * 0.2 / 65 + 0.02), string.format("§1 contenant plein de B : 1,42 + 50 x 0,2 / 65 + 0,02 (%s)", tostring(F.plein_b)))
check(near(F.b, 0.2 / 65), "§1 fluide B : 0,2 / 65 (sa recette sans entrée)")
check(near(F.tige, 2 * 1.32 + 0.1), string.format("§1 couple à sortes égales gardé : tige 2 x 1,32 + 0,1 (%s)", tostring(F.tige)))
check(F.skip_presque == "h-vider-b", "§1 vidage « presque inverse » (40 au lieu de 50) gardé (" .. F.skip_presque .. ")")

---------------------------------------------------------------------------------------------------
-- §2 données des leviers
---------------------------------------------------------------------------------------------------
-- V1 : valeurs et bornes calculées à la main (CRITERES.md) ; Ca.RAW_MU = 1, Ca.TIME_MU = 0,1.
local WANT = {
  { "petroleum-gas", 2.23, 2.24, "basic-oil-processing", "(100 x 1 + 5 x 0,1) / 45 = 2,2333" },
  { "empty-barrel", 8.29, 8.31, "empty-barrel", "acier 8,2 + 1 x 0,1 = 8,3" },
  { "petroleum-gas-barrel", 119.9, 120.1, "fill-petroleum-gas-barrel", "8,3 + 50 x 2,2333 + 0,02 = 119,99" },
  { "plastic-bar", 22.85, 22.92, "plastic-bar", "(1 + 20 x 2,2333 + 0,1) / 2 = 22,883" },
  { "advanced-circuit", 55.9, 56.0, "advanced-circuit", "4 x 0,685 + 2 x 3,425 + 2 x 22,883 + 0,6 = 55,957" },
  { "productivity-module", 298.2, 298.6, "productivity-module", "5 x 55,957 + 5 x 3,425 + 1,5 = 298,41" },
  { "speed-module", 298.2, 298.6, "speed-module", "5 x 55,957 + 5 x 3,425 + 1,5 = 298,41" },
  { "iron-plate", 1.32 - 1e-9, 1.32 + 1e-9, "iron-plate", "1 + 3,2 x 0,1 = 1,32" },
  { "steel-plate", 8.2 - 1e-9, 8.2 + 1e-9, "steel-plate", "5 x 1,32 + 16 x 0,1 = 8,2" },
}
for _, w in ipairs(WANT) do
  local v, b = F.real_mu[w[1]], F.real_best[w[1]]
  check(v and v >= w[2] and v <= w[3] and b == w[4], string.format("§2 V1 %s = %s via %s (attendu %s via %s)", w[1], tostring(v),
    tostring(b), w[5], w[4]))
end
-- Forme des recettes écartées : 1 ingrédient (le contenant plein) -> 2 produits ; aucun couple inverse à sortes égales.
do
  local D, n, bad, equal = F.D, 0, {}, 0
  local function sig(list)
    local t = {}
    for _, x in ipairs(list) do t[#t + 1] = x.name .. "=" .. x.amount end
    table.sort(t)
    return table.concat(t, ",")
  end
  local fwd = {}
  for _, rn in ipairs(D.recipe_list) do
    local r = D.recipes[rn]
    fwd[sig(r.ingredients) .. ">" .. sig(r.products)] = rn
  end
  for _, rn in ipairs(D.recipe_list) do
    local r = D.recipes[rn]
    if F.real_skip[rn] then
      n = n + 1
      if not (#r.ingredients == 1 and #r.products == 2) then bad[#bad + 1] = rn end
    end
    local inv = fwd[sig(r.products) .. ">" .. sig(r.ingredients)]
    if inv and inv ~= rn and #r.products == #r.ingredients then equal = equal + 1 end
  end
  check(n == 15 and #bad == 0, string.format("§2 15 recettes écartées, toutes « 1 plein -> contenant + contenu » (%d, hors forme : %s)", n,
    table.concat(bad, ",")))
  check(equal == 0, "§2 aucun couple inverse à sortes égales dans les données (" .. equal .. ") : la règle n'a pas à trancher")
  -- Point fixe atteint : aucune recette gardée ne donnerait un prix plus bas.
  local Ca = Ca0
  local mu, lower = F.real_all, {}
  for _, rn in ipairs(D.recipe_list) do
    local r = D.recipes[rn]
    if not F.real_skip[rn] then
      local input, ok = r.energy * Ca.TIME_MU, true
      for _, i in ipairs(r.ingredients) do
        if mu[i.name] == nil then ok = false break end
        input = input + mu[i.name] * i.amount
      end
      local tot = 0
      for _, p in ipairs(r.products) do tot = tot + p.amount end
      if ok and tot > 0 then
        for _, p in ipairs(r.products) do
          if not D.res[p.name] and (mu[p.name] == nil or input / tot < mu[p.name] - 1e-9) then lower[#lower + 1] = rn .. ">" .. p.name end
        end
      end
    end
  end
  check(#lower == 0, "§2 point fixe atteint (" .. table.concat(lower, " ") .. ")")
end
-- V2, V3 : contre la même règle RETIRÉE (aucune recette écartée), sur les mêmes données.
local OFF_OLD, OFF_NEW = "local input, ok = r.energy * Ca.TIME_MU, not skip[rn]", "local input, ok = r.energy * Ca.TIME_MU, true"
do
  local a, b = SRC:find(OFF_OLD, 1, true)
  check(a ~= nil, "§2 texte de la règle trouvé (pour la comparer à la règle retirée)")
  if a then
    local Coff = load_ca(SRC:sub(1, a - 1) .. OFF_NEW .. SRC:sub(b + 1))
    local mu_off = Coff.values(F.D)
    local down, lost, n = {}, {}, 0
    local names = {}
    for k in pairs(mu_off) do names[#names + 1] = k end
    table.sort(names)
    for _, k in ipairs(names) do
      n = n + 1
      local v = F.real_all[k]
      if v == nil then lost[#lost + 1] = k
      elseif v < mu_off[k] - 1e-9 then down[#down + 1] = k end
    end
    check(n > 100 and #down == 0, string.format("§2 V2 aucun prix ne baisse (%d objets ; %s)", n, table.concat(down, " ")))
    check(#lost == 0, "§2 V3 aucun objet ne perd son prix (" .. table.concat(lost, " ") .. ")")
    check(mu_off["petroleum-gas"] < 1, string.format("§2 règle retirée : le gaz retombe sous 1 MU (%.4f), défaut d'origine", mu_off["petroleum-gas"]))
  end
end

---------------------------------------------------------------------------------------------------
-- §3 mutants (V5)
---------------------------------------------------------------------------------------------------
local function same(A, B)
  for _, k in ipairs({ "skip", "a", "cont", "plein_a", "plein_b", "tige", "b", "best_a", "best_cont", "skip_presque" }) do
    if A[k] ~= B[k] then return false end
  end
  for _, k in ipairs(WATCH) do
    if A.real_mu[k] ~= B.real_mu[k] or A.real_best[k] ~= B.real_best[k] then return false end
  end
  return true
end
local MUTANTS = {
  { "règle retirée", OFF_OLD, OFF_NEW },
  { "les deux sens écartés", "if #r.products > #r.ingredients and fwd[", "if fwd[" },
  { "mauvais sens écarté (le remplissage)", "if #r.products > #r.ingredients and fwd[", "if #r.products < #r.ingredients and fwd[" },
  { "couple à sortes égales écarté", "if #r.products > #r.ingredients and fwd[", "if #r.products >= #r.ingredients and fwd[" },
  { "quantités ignorées", 'for _, x in ipairs(list) do t[#t + 1] = x.name .. "=" .. x.amount end', 'for _, x in ipairs(list) do t[#t + 1] = x.name end' },
  { "signature non triée", "    table.sort(t)\n    return table.concat(t, \",\")", "    return table.concat(t, \",\")" },
}
local caught, crashed = 0, 0
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then check(false, "mutant « " .. m[1] .. " » : texte introuvable")
  else
    local ok, G = pcall(function() return facts(load_ca(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))) end)
    if not ok then crashed = crashed + 1 end
    local refused = ok and not same(F, G)
    if refused then caught = caught + 1 end
    check(refused, "mutant « " .. m[1] .. " » refusé par un contrôle" .. (ok and "" or (" (plantage : " .. tostring(G) .. ")")))
  end
end
print(string.format("[VALEURS] mutants refusés : %d sur %d (plantages : %d)", caught, #MUTANTS, crashed))
print(string.format("[VALEURS] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
