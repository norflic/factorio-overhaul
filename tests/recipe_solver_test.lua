--[[
  Lot RECIPE-SOLVER (directive du DC) : banc HORS JEU du solveur récursif d'arbres de recettes (shared/team/recipe_solver.lua).
  Lancement : lua5.2 tests/recipe_solver_test.lua (racine du mod).
    1. ratios exacts sur un livre JOUET (recettes inventées a/b/c…) : machines = débit × energy ÷ (quantité × vitesse) ;
    2. agrégation bus_needs, matière brute (raw) sans recette, recette hors de la main (index de repli), cycle coupé ;
    3. mémoïsation (2e appel = 0 miss, même résultat), linéarité (débit 3 = 3 × débit 1), ratio() lu au cache ;
    4. hubs (agrégation, ordre débit décroissant puis nom, k) ;
    5. déterminisme (livre construit dans l'ordre inverse, deux solveurs : mêmes faits) ;
    6. fixture RÉELLE (tests/fixtures/recipes.lua, aucun nom cité) : jamais nil, nombres finis, linéarité, cache ;
    7. mutants : chaque règle cassée change un fait observé.
]]
package.path = "./?.lua;" .. package.path
local Book = require("shared.team.book")
local FIX = require("tests.fixtures.recipes")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b)) end
local function read_src(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read_src("shared/team/recipe_solver.lua")
local function load_S(text) return assert(load(text or SRC, "@shared/team/recipe_solver.lua"))() end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Sérialisation déterministe d'un arbre (clés triées, nombres à 9 chiffres) : comparaison de faits.
local function dump(v)
  if type(v) == "number" then return string.format("%.9g", v) end
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for _, k in ipairs(sorted_keys(v)) do parts[#parts + 1] = tostring(k) .. "=" .. dump(v[k]) end
  return "{" .. table.concat(parts, ",") .. "}"
end

---------------------------------------------------------------------------------------------------
-- Livre jouet : a = 2 b + 1 p (0,5 s, 1 par cycle) ; b = 1 p (0,5 s) ; c = 1 a + 3 q (1 s, 2 par cycle) ;
-- d = 1 b (2 s, catégorie hors de la main) ; x <-> y (cycle) ; g = 1 a + 3 d ; p : matière du bus ; q : aucune recette (brute).
---------------------------------------------------------------------------------------------------
local function ing(name, amount) return { type = "item", name = name, amount = amount } end
local function rec(energy, ings, product, amount, category)
  return { category = category or "crafting", energy = energy, hidden = false, ingredients = ings,
    products = { { type = "item", name = product, amount = amount or 1 } } }
end
local TOY_LIST = {
  { "a", rec(0.5, { ing("b", 2), ing("p", 1) }, "a") },
  { "b", rec(0.5, { ing("p", 1) }, "b") },
  { "c", rec(1, { ing("a", 1), ing("q", 3) }, "c", 2) },
  { "d", rec(2, { ing("b", 1) }, "d", 1, "other-crafting") },
  { "x", rec(1, { ing("y", 1) }, "x") },
  { "y", rec(1, { ing("x", 1), ing("p", 1) }, "y") },
  { "g", rec(1, { ing("a", 1), ing("d", 3) }, "g") },
}
local function toy_recipes(reverse)
  local t = {}
  if reverse then
    for i = #TOY_LIST, 1, -1 do t[TOY_LIST[i][1]] = TOY_LIST[i][2] end
  else
    for i = 1, #TOY_LIST do t[TOY_LIST[i][1]] = TOY_LIST[i][2] end
  end
  return t
end
local BUS = { p = true }

---------------------------------------------------------------------------------------------------
-- 1. Ratios exacts
---------------------------------------------------------------------------------------------------
section("1. Ratios exacts (livre jouet, vitesse 0,5)")
local S = load_S()
local s = S.new(Book.new(toy_recipes()), BUS)
local ta = S.solve(s, "a", 1, 0.5)
check(ta ~= nil and ta.item == "a" and ta.recipe == "a", "arbre rendu pour a")
check(near(ta.rate, 1), "debit de a = 1/s")
check(near(ta.machines, 1), "a : 1 par cycle en 0,5 s a vitesse 0,5 pour 1/s -> 1 machine (obtenu " .. tostring(ta.machines) .. ")")
check(#ta.nodes == 1 and ta.nodes[1].item == "b", "un seul sous-arbre : b (p est au bus)")
check(near(ta.nodes[1].rate, 2), "b demande 2/s")
check(near(ta.nodes[1].machines, 2), "b : 2 par cycle, 1 par 0,5 s a vitesse 0,5 -> 2 machines (obtenu " .. tostring(ta.nodes[1].machines) .. ")")
check(near(ta.total_machines.a, 1) and near(ta.total_machines.b, 2), "total_machines = { a = 1, b = 2 }")
local ta2 = S.solve(s, "a", 1, 1)
check(near(ta2.machines, 0.5) and near(ta2.nodes[1].machines, 1), "vitesse 1 : moitie moins de machines")
local tc = S.solve(s, "c", 2, 0.5)
check(near(tc.machines, 2), "c : 2 par cycle en 1 s a vitesse 0,5 pour 2/s -> 2 machines (obtenu " .. tostring(tc.machines) .. ")")
check(#tc.nodes == 2 and tc.nodes[1].item == "a" and tc.nodes[2].item == "q", "sous-arbres de c dans l'ordre de la recette : a puis q")
check(near(tc.nodes[1].rate, 1), "c a 2/s demande a a 1/s (1 par cycle de 2 c)")

---------------------------------------------------------------------------------------------------
-- 2. bus_needs, raw, index de repli, cycle
---------------------------------------------------------------------------------------------------
section("2. bus_needs, matiere brute, recette hors de la main, cycle")
check(near(ta.bus_needs.p, 3), "bus_needs.p agrege sur l'arbre de a : 1 (a) + 2 (b) = 3 (obtenu " .. tostring(ta.bus_needs.p) .. ")")
check(ta.bus_needs.b == nil and ta.bus_needs.a == nil, "les intermediaires ne sont pas des besoins du bus")
check(near(tc.bus_needs.q, 3) and near(tc.bus_needs.p, 3), "c a 2/s : q brute 3/s (3 par cycle de 2 c), p 3/s")
check(tc.nodes[2].raw == true and tc.nodes[2].recipe == nil and near(tc.nodes[2].machines, 0), "q sans recette : raw = true, 0 machine, jamais nil")
local tq = S.solve(s, "q", 4, 0.5)
check(tq.raw == true and near(tq.bus_needs.q, 4) and #tq.nodes == 0, "racine brute : raw, bus_needs = { q = 4 }")
local tp = S.solve(s, "p", 5, 0.5)
check(tp.bus == true and near(tp.bus_needs.p, 5) and tp.recipe == nil, "racine au bus : bus = true, bus_needs = { p = 5 }")
local td = S.solve(s, "d", 1, 0.5)
check(td.recipe == "d" and near(td.machines, 4), "recette hors de la main (categorie autre) trouvee par l'index de repli : 2 s / 0,5 = 4 machines")
local tx = S.solve(s, "x", 1, 1)
check(tx.cycle == true and tx.recipe == "x", "cycle x -> y -> x : racine signalee cycle = true")
check(tx.nodes[1].item == "y" and tx.nodes[1].nodes[1].item == "x" and tx.nodes[1].nodes[1].cycle == true, "la coupe est sur la seconde visite de x")
check(near(tx.bus_needs.p, 1) and near(tx.machines, 1) and near(tx.nodes[1].machines, 1), "le cycle coupe garde des nombres finis")
check(s.cache.x ~= nil and s.cache.y == nil, "x (cycle coupe sur lui-meme) entre au cache ; y (coupe sur son ancetre x) non")
local ty = S.solve(s, "y", 1, 1)
check(ty.cycle == true and ty.nodes[1].item == "x" and ty.nodes[1].nodes[1].item == "y" and ty.nodes[1].nodes[1].cycle == true,
  "depuis y la coupe est sur y (le cache de x n'est pas relu pendant la visite de y)")
local sy = S.new(Book.new(toy_recipes()), BUS)
check(dump(S.solve(sy, "y", 1, 1)) == dump(ty), "independance de l'historique : y resolu en premier donne le meme arbre")
check(dump(S.solve(sy, "x", 1, 1)) == dump(tx), "idem pour x apres y")
local tnil = S.solve(s, "inconnu", nil, nil)
check(tnil.raw == true and near(tnil.rate, 0), "objet inconnu, debit nil : raw, debit 0, jamais nil")

---------------------------------------------------------------------------------------------------
-- 3. Mémoïsation, linéarité, ratio
---------------------------------------------------------------------------------------------------
section("3. Memoisation et linearite du cache")
local s2 = S.new(Book.new(toy_recipes()), BUS)
local r1 = S.solve(s2, "c", 1, 0.5)
local st1 = S.stats(s2)
check(st1.misses == 4 and st1.hits == 0, "premier calcul de c : 4 manques (c, a, b, q), 0 hit (obtenu " .. st1.misses .. "/" .. st1.hits .. ")")
local r1b = S.solve(s2, "c", 1, 0.5)
local st2 = S.stats(s2)
check(st2.misses == st1.misses and st2.hits == st1.hits + 1, "deuxieme appel : 0 manque de plus, 1 hit")
check(dump(r1) == dump(r1b), "deuxieme appel : meme resultat")
check(s2.cache.c and s2.cache.c[0.5] ~= nil, "cache[item][vitesse] rempli")
local r3 = S.solve(s2, "c", 3, 0.5)
check(S.stats(s2).misses == st1.misses, "debit 3 : aucun calcul (mise a l'echelle)")
check(near(r3.machines, 3 * r1.machines) and near(r3.bus_needs.q, 3 * r1.bus_needs.q) and near(r3.nodes[1].nodes[1].machines, 3 * r1.nodes[1].nodes[1].machines),
  "debit 3 = 3 x debit 1 (racine, bus_needs, sous-arbres)")
check(near(r3.total_machines.b, 3 * r1.total_machines.b), "total_machines mis a l'echelle")
r3.bus_needs.q = -1
check(near(S.solve(s2, "c", 1, 0.5).bus_needs.q, r1.bus_needs.q), "la lecture rend une copie : l'appelant ne corrompt pas le cache")
local sa = S.solve(s2, "a", 1, 0.5)
check(S.stats(s2).misses == st1.misses, "a deja calcule comme sous-arbre de c : servi au cache")
check(near(sa.machines, 1) and near(sa.bus_needs.p, 3), "sous-arbre promu en racine : memes chiffres")
local rat = S.ratio(s2, "c", 0.5)
check(near(rat.c, 1) and near(rat.a, 0.5) and near(rat.b, 1), "ratio(c) = machines par 1/s : c 1, a 0,5, b 1 (obtenu " .. dump(rat) .. ")")
check(S.stats(s2).misses == st1.misses, "ratio lu au cache")
local rat2 = S.ratio(s2, "c", 1)
check(near(rat2.c, 0.5) and S.stats(s2).misses == st1.misses + 4, "autre vitesse : nouveau palier du cache (c, a, b, q recalcules une fois)")
local sn = S.new(Book.new(toy_recipes()), BUS)
local t0 = S.solve(sn, "a", 1, 0)
check(near(t0.machines, 0.5), "vitesse 0 ou nulle : vitesse par defaut 1 (zero blocage)")

---------------------------------------------------------------------------------------------------
-- 4. hubs
---------------------------------------------------------------------------------------------------
section("4. hubs : intermediaires les plus sollicites")
local s4 = S.new(Book.new(toy_recipes()), BUS)
local demands = { { "a", 1, 0.5 }, { "c", 2, 0.5 } }
local hubs = S.hubs(s4, demands)
check(#hubs == 2, "deux intermediaires (b, a) ; ni p (bus), ni q (brute), ni les racines (obtenu " .. #hubs .. ")")
check(hubs[1] and hubs[1].item == "b" and near(hubs[1].rate, 4) and near(hubs[1].machines, 4), "b en tete : 2 (via a) + 2 (via c -> a) = 4/s, 4 machines")
check(hubs[2] and hubs[2].item == "a" and near(hubs[2].rate, 1) and near(hubs[2].machines, 1), "a ensuite : 1/s comme ingredient de c")
local hubs1 = S.hubs(s4, demands, 1)
check(#hubs1 == 1 and hubs1[1].item == "b", "k = 1 : seul b")
check(#S.hubs(s4, {}, 3) == 0 and #S.hubs(s4, nil, 3) == 0, "demandes vides : liste vide")
local tie = S.hubs(s4, { { "a", 1, 0.5 }, { "d", 2, 0.5 } })
check(tie[1].item == "b" and near(tie[1].rate, 4), "meme intermediaire par deux racines : agrege")
local eq = S.hubs(S.new(Book.new(toy_recipes()), BUS), { { "c", 2, 0.5 }, { "d", 1, 0.5 } })
check(eq[1].item == "b" and near(eq[1].rate, 3) and eq[2].item == "a" and eq[3] == nil, "c et d : b 3/s (2 + 1) devant a 1/s")
local eqs = S.hubs(S.new(Book.new(toy_recipes()), { p = true, b = true }), { { "c", 4, 0.5 }, { "g", 1, 0.5 } })
check(#eqs == 2 and near(eqs[1].rate, 3) and near(eqs[2].rate, 3) and eqs[1].item == "a" and eqs[2].item == "d", "a et d a 3/s chacun : a avant d (nom)")
local gd = S.hubs(S.new(Book.new(toy_recipes()), { p = true, b = true }), { { "g", 1, 0.5 } })
check(gd[1].item == "d" and near(gd[1].rate, 3) and gd[2].item == "a", "g : d 3/s devant a 1/s (debit avant nom)")
check(S.hubs(s4, { { item = "c", rate = 2, speed = 0.5 } })[1].item == "b", "demande en champs nommes acceptee")

---------------------------------------------------------------------------------------------------
-- 5. Déterminisme
---------------------------------------------------------------------------------------------------
section("5. Determinisme")
local function facts(Smod, reverse)
  local sv = Smod.new(Book.new(toy_recipes(reverse)), { p = true, b = true })
  local out = {}
  for _, it in ipairs({ "a", "c", "d", "x", "q", "p" }) do out[#out + 1] = dump(Smod.solve(sv, it, 3, 0.5)) end
  out[#out + 1] = dump(Smod.hubs(sv, { { "g", 1, 0.5 }, { "c", 2, 0.5 } }))
  out[#out + 1] = dump(Smod.ratio(sv, "c", 0.5))
  return table.concat(out, "\n")
end
local F0 = facts(S, false)
check(F0 == facts(S, true), "livre construit dans l'ordre inverse : memes faits")
check(F0 == facts(load_S(), false), "module recharge : memes faits")
local sb = S.new(Book.new(toy_recipes()), { p = true, b = true })
local tab = S.solve(sb, "a", 1, 0.5)
check(near(tab.bus_needs.b, 2) and near(tab.bus_needs.p, 1) and tab.total_machines.b == nil and #tab.nodes == 0, "b au bus : plus de recursion sur b")

---------------------------------------------------------------------------------------------------
-- 6. Fixture réelle
---------------------------------------------------------------------------------------------------
section("6. Fixture reelle : jamais nil, fini, lineaire, cache")
local book = Book.new(FIX)
local bus = {}
for _, name in ipairs(sorted_keys(FIX)) do
  for _, i in ipairs(FIX[name].ingredients) do
    if book:natural(i.name) then bus[i.name] = true end
  end
end
local sr = S.new(book, bus)
local nb, bad_nil, bad_num, bad_lin, with_recipe, raw_count = 0, 0, 0, 0, 0, 0
local function finite(x) return type(x) == "number" and x == x and x ~= math.huge and x >= 0 end
local function walk(n, f) f(n); for _, sub in ipairs(n.nodes) do walk(sub, f) end end
for _, name in ipairs(sorted_keys(FIX)) do
  local r = FIX[name]
  if r.category == "crafting" and not r.hidden then
    local item = r.products[1].name
    nb = nb + 1
    local t1 = S.solve(sr, item, 1, 0.75)
    if t1 == nil then bad_nil = bad_nil + 1 else
      if t1.recipe then with_recipe = with_recipe + 1 end
      walk(t1, function(n)
        if not finite(n.machines) or not finite(n.rate) then bad_num = bad_num + 1 end
        if n.raw then raw_count = raw_count + 1 end
      end)
      for _, k in ipairs(sorted_keys(t1.bus_needs)) do if not finite(t1.bus_needs[k]) then bad_num = bad_num + 1 end end
      local t5 = S.solve(sr, item, 5, 0.75)
      if not near(t5.machines, 5 * t1.machines) then bad_lin = bad_lin + 1 end
      for _, k in ipairs(sorted_keys(t1.total_machines)) do
        if not near(t5.total_machines[k], 5 * t1.total_machines[k]) then bad_lin = bad_lin + 1 end
      end
    end
  end
end
check(nb > 100, "fixture : plus de 100 produits de la main (obtenu " .. nb .. ")")
check(bad_nil == 0, "aucun arbre nil")
check(bad_num == 0, "tous les nombres finis et positifs (anomalies : " .. bad_num .. ")")
check(bad_lin == 0, "lineaire sur toute la fixture (anomalies : " .. bad_lin .. ")")
check(with_recipe == nb, "chaque produit de la main a sa recette a la racine")
local str = S.stats(sr)
print("  fixture : hits " .. str.hits .. ", misses " .. str.misses)
local before = S.stats(sr).misses
for _, name in ipairs(sorted_keys(FIX)) do
  local r = FIX[name]
  if r.category == "crafting" and not r.hidden then S.solve(sr, r.products[1].name, 7, 0.75) end
end
check(S.stats(sr).misses == before, "second balayage de la fixture : zero calcul")
local real_hubs = S.hubs(sr, (function()
  local d = {}
  for _, name in ipairs(sorted_keys(FIX)) do
    local r = FIX[name]
    if r.category == "crafting" and not r.hidden then d[#d + 1] = { r.products[1].name, 1, 0.75 } end
  end
  return d
end)(), 5)
local ordered = true
for i = 2, #real_hubs do
  local a, b = real_hubs[i - 1], real_hubs[i]
  if a.rate < b.rate or (a.rate == b.rate and a.item > b.item) then ordered = false end
end
check(#real_hubs == 5 and ordered, "hubs de la fixture : 5 entrees, ordre debit decroissant puis nom")
print("  hubs de la fixture (5) : " .. dump(real_hubs))

---------------------------------------------------------------------------------------------------
-- 7. Mutants
---------------------------------------------------------------------------------------------------
section("7. Mutants : chaque regle cassee change un fait")
local function mutant(label, pat, repl)
  local text, n = SRC:gsub(pat, repl, 1)
  if not check(n == 1, "mutant « " .. label .. " » : motif trouve dans la source") then return end
  local ok, res = pcall(function() return facts(load_S(text), false) end)
  check(not ok or res ~= F0, "mutant « " .. label .. " » detecte (faits differents ou erreur)")
end
local lit = function(s_) return (s_:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")) end
mutant("division par la vitesse retiree", lit("/ (per * speed)"), "/ per")
mutant("quantite produite ignoree", lit("/ (per * speed)"), "/ speed")
mutant("bus ignore", lit("if s.bus[ing.name] then"), "if false then")
mutant("cache rendu sans mise a l'echelle", lit("return scale(tree, type(rate) == \"number\" and rate or 0)"), "return tree")
mutant("hubs non tries", lit("table.sort(list, by_rate_then_name)"), "")
mutant("garde de cycle retiree", lit("if visiting[item] then return leaf(item, \"cycle\"), {}, { [item] = true } end"), "")
mutant("matiere brute non signalee", lit("n[kind] = true"), "")
mutant("ingredient non ramene au cycle", lit("(ing.amount or 1) / per"), "(ing.amount or 1)")
mutant("total_machines sans la racine", lit("total_machines = { [rname] = machines }"), "total_machines = {}")

print(string.format("\nRésultat : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
