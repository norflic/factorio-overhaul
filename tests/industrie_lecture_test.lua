--[[
  Lot INDUSTRIE I4 « lecture générique » : le jeu dit ce qui se fabrique et avec quoi, le code ne nomme rien.
  Hors jeu, Lua pur : lua5.2 tests/industrie_lecture_test.lua

  Preuve « peu importe le mod » (PLAN INDUSTRIE §1) :
    §1 jeu de données ÉCRIT pour la règle : 23 recettes, 12 machines, chaque limite (ingrédients solides, boîtes à fluide,
       filtre, recette imposée, emprise, sortie sans objet, recette cachée ou inconnue) avec sa valeur exacte attendue ;
    §2 kit de logistique : la pièce la moins chère par TYPE (électrique d'abord, filtre exclu, cycle de recettes, égalité) ;
    §3 relevé VANILLA + MOD de référence (fixtures de l'IA-G, complétées des emprises et boîtes des machines) : chiffres,
       indépendance vis-à-vis des exécutants, déterminisme (listes inversées) ;
    §4 NOMS PERMUTÉS : tous les noms du relevé (objets, recettes, machines, catégories, fluides) remplacés par un hachage ;
       mêmes décisions à l'isomorphisme près, recette par recette ;
    §5 MINI-MOD inventé greffé au relevé : machine 4 × 4 à catégorie neuve, recette à 3 solides et 1 fluide, bras neuf,
       tourelle neuve : lus sans une ligne de code ;
    §6 MUTANTS : chaque règle de shared/ai3/lecture.lua cassée (une substitution du source) est vue par le §1 ou le §2.
]]

package.path = "./?.lua;" .. package.path

local L = require("shared.ai3.lecture")
local K = require("shared.ai3.catalogue")
local F = require("tests.iag_fixture")

local pass, fail = 0, 0
local function check(cond, label)
  if cond then
    pass = pass + 1
  else
    fail = fail + 1
    print("ECHEC : " .. label)
  end
end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function names_of(machines)
  local out = {}
  for _, m in ipairs(machines or {}) do out[#out + 1] = m.entity end
  return table.concat(out, ",")
end

---------------------------------------------------------------------------------------------------
-- §1 Jeu de données écrit pour la règle
---------------------------------------------------------------------------------------------------
local function ing(...)
  local out = {}
  for _, v in ipairs({ ... }) do
    local name, fluid = v, false
    if v:sub(1, 1) == "~" then name, fluid = v:sub(2), true end -- « ~f-x » : fluide
    out[#out + 1] = { type = fluid and "fluid" or "item", name = name, amount = 1 }
  end
  return out
end

local function rec(cat, energy, ins, outs, hidden)
  return { category = cat, energy = energy, hidden = hidden or false, enabled = true, ingredients = ins, products = outs }
end

local function box(kind, filter) return { type = kind, filter = filter, conns = { [0] = {}, [2] = {}, [4] = {}, [6] = {} } } end

local function mini()
  local d = { recipes = {}, techs = {}, resources = {}, items = {}, entities = {} }
  local function mach(name, ty, cats, speed, side, cap, boxes, extra)
    local e = { name = name, type = ty, item = name, crafting_categories = cats, energy = "electric", speed = speed,
      w = side, h = side, ingredient_count = cap, boxes = boxes or {} }
    for k, v in pairs(extra or {}) do e[k] = v end
    d.entities[#d.entities + 1] = e
  end
  mach("m-a", "assembling-machine", { "c1" }, 1, 3, 2)
  mach("m-b", "assembling-machine", { "c1", "c2" }, 2, 4, 4, { box("input"), box("input"), box("output") })
  mach("m-f", "furnace", { "c3" }, 1, 2, 0) -- le moteur dirait autre chose pour un four : le type fait foi (R.SOURCE_CAP)
  mach("m-big", "assembling-machine", { "c4" }, 1, 20, 8)
  mach("m-filt", "assembling-machine", { "c5" }, 1, 3, 4, { box("input", "f-x"), box("input"), box("output") })
  mach("m-fix", "assembling-machine", { "c6" }, 1, 3, 4, nil, { fixed_recipe = "r-fix" })
  mach("m-wide", "assembling-machine", { "c7" }, 1, 3, nil)
  mach("m-18", "assembling-machine", { "c8" }, 1, 18, 4)
  mach("m-io", "assembling-machine", { "c10" }, 1, 3, 4, { box("input-output"), box("output") })
  d.entities[#d.entities + 1] = { name = "m-noitem", type = "assembling-machine", crafting_categories = { "c1" }, speed = 9,
    w = 3, h = 3, ingredient_count = 9, boxes = {} } -- sans objet : ne se pose pas
  local R = d.recipes
  R["r1"] = rec("c1", 2, ing("a", "b"), { { type = "item", name = "o1", amount = 3 } })
  R["r2"] = rec("c1", 2, ing("a", "b", "c"), { { type = "item", name = "o2", amount = 1 } })
  R["r3"] = rec("c1", 2, ing("a", "b", "c", "d", "e"), { { type = "item", name = "o3", amount = 1 } })
  R["r4"] = rec("c1", 2, ing("a", "~f-x", "~f-y"), { { type = "item", name = "o4", amount = 1 } })
  R["r5"] = rec("c1", 2, ing("a", "~f-x", "~f-y", "~f-z"), { { type = "item", name = "o5", amount = 1 } })
  R["r6"] = rec("c2", 2, ing("a", "~f-x"), { { type = "item", name = "o6", amount = 1 }, { type = "fluid", name = "f-p", amount = 1 },
    { type = "fluid", name = "f-q", amount = 1 } })
  R["r7"] = rec("c3", 3, ing("a"), { { type = "item", name = "o7", amount = 1 } })
  R["r8"] = rec("c3", 3, ing("a", "b"), { { type = "item", name = "o8", amount = 1 } })
  R["r9"] = rec("c4", 1, ing("a"), { { type = "item", name = "o9", amount = 1 } })
  R["r10"] = rec("c1", 1, ing("a", "~f-x"), { { type = "fluid", name = "f-p", amount = 1 } })
  R["r11"] = rec("c5", 1, ing("~f-x", "~f-y"), { { type = "item", name = "o11", amount = 1 } })
  R["r12"] = rec("c5", 1, ing("~f-y", "~f-z"), { { type = "item", name = "o12", amount = 1 } })
  R["r-fix"] = rec("c6", 1, ing("a"), { { type = "item", name = "o13", amount = 1 } })
  R["r14"] = rec("c6", 1, ing("a"), { { type = "item", name = "o14", amount = 1 } })
  R["r15"] = rec("c9", 1, ing("a"), { { type = "item", name = "o15", amount = 1 } })
  R["r16"] = rec("c1", 1, {}, { { type = "item", name = "o16", amount = 1 } })
  R["r17"] = rec("c1", 1, ing("a"), { { type = "item", name = "o17", amount = 1 } }, true)
  R["r19"] = rec("c7", 1, ing("a", "b", "c", "d", "e", "f", "g", "h"), { { type = "item", name = "o19", amount = 1 } })
  R["r20"] = rec("c7", 1, ing("a", "b", "c", "d", "e", "f", "g", "h", "i"), { { type = "item", name = "o20", amount = 1 } })
  R["r21"] = rec("c1", 1, ing("a"), { { type = "item", name = "o21", amount = 1 } }) -- inconnue de l'équipe (opts.known)
  R["r22"] = rec("c1", 1, ing("a", "b"), { { type = "item", name = "o22a", amount = 1 }, { type = "item", name = "o22b", amount = 2 } })
  R["r23"] = rec("c8", 1, ing("a"), { { type = "item", name = "o23", amount = 1 } })
  R["r24"] = rec("c10", 1, ing("a", "~f-x"), { { type = "item", name = "o24", amount = 1 } })
  return d
end

-- recette -> { patronnable, code du refus, machines (du moins rapide au plus rapide), s, fluides_in, fluides_out, produits, main }
local EXPECT = {
  ["r1"] = { true, nil, "m-a,m-b", 2, 0, 0, 1, true },
  ["r2"] = { true, nil, "m-b", 3, 0, 0, 1, true },
  ["r3"] = { false, "entrees_machine", "", 5, 0, 0, 1, true },
  ["r4"] = { true, nil, "m-b", 1, 2, 0, 1, false },
  ["r5"] = { false, "fluide_entree", "", 1, 3, 0, 1, false },
  ["r6"] = { false, "fluide_sortie", "", 1, 1, 2, 3, false },
  ["r7"] = { true, nil, "m-f", 1, 0, 0, 1, false },
  ["r8"] = { false, "entrees_machine", "", 2, 0, 0, 1, false },
  ["r9"] = { false, "taille", "", 1, 0, 0, 1, false },
  ["r10"] = { false, "sans_produit_solide", "", 1, 1, 1, 1, false },
  ["r11"] = { true, nil, "m-filt", 0, 2, 0, 1, false },
  ["r12"] = { false, "fluide_entree", "", 0, 2, 0, 1, false },
  ["r-fix"] = { true, nil, "m-fix", 1, 0, 0, 1, false },
  ["r14"] = { false, "categorie", "", 1, 0, 0, 1, false },
  ["r15"] = { false, "categorie", "", 1, 0, 0, 1, false },
  ["r16"] = { false, "sans_entree", "", 0, 0, 0, 1, true },
  ["r19"] = { true, nil, "m-wide", 8, 0, 0, 1, false },
  ["r20"] = { false, "entrees_max", "", 9, 0, 0, 1, false },
  ["r22"] = { true, nil, "m-a,m-b", 2, 0, 0, 2, true },
  ["r23"] = { true, nil, "m-18", 1, 0, 0, 1, false },
  ["r24"] = { false, "fluide_entree", "", 1, 1, 0, 1, false },
}

--- Contrôles du §1 contre une version `Lm` de la règle ; rend le nombre d'écarts (les mutants doivent en donner).
local function battery(Lm)
  local bad = 0
  local d = mini()
  local known = {}
  for name in pairs(d.recipes) do known[name] = name ~= "r21" end
  local fab, machines = Lm.read(d, { known = known, hand = { c1 = true } })
  local function eq(a, b) if a ~= b then bad = bad + 1 end end
  eq(fab["r17"], nil) -- cachée : absente
  eq(fab["r21"], nil) -- inconnue de l'équipe : absente
  eq(#machines, 9) -- 9 machines posables (m-noitem n'a pas d'objet)
  for _, name in ipairs(sorted_keys(EXPECT)) do
    local e, x = fab[name], EXPECT[name]
    if not e then
      bad = bad + 1
    else
      eq(e.patronnable, x[1])
      eq(e.refus and e.refus.code or nil, x[2])
      eq(names_of(e.machines), x[3])
      eq(e.s, x[4])
      eq(#e.fluides_in, x[5])
      eq(#e.fluides_out, x[6])
      eq(#e.produits, x[7])
      eq(e.main, x[8])
      if not x[1] then eq(e.refus ~= nil and e.refus.texte:sub(1, 8) == "limite :", true) end
    end
  end
  -- Débit : 60 × vitesse ÷ durée × quantité du premier produit solide (r1 : durée 2, 3 par fabrication)
  local r1 = fab["r1"]
  if r1 and r1.machines[1] and r1.machines[2] then
    eq(r1.machines[1].par_min, 90)
    eq(r1.machines[2].par_min, 180)
  else
    bad = bad + 1
  end
  -- Textes de refus chiffrés (la raison dit le nombre qui bloque)
  eq(fab["r3"] and fab["r3"].refus.texte:find("5 ingredients solides", 1, true) ~= nil and fab["r3"].refus.texte:find("4 au plus", 1, true) ~= nil, true)
  eq(fab["r9"] and fab["r9"].refus.texte:find("20 tuiles", 1, true) ~= nil, true)
  eq(fab["r20"] and fab["r20"].refus.texte:find("9 entrees solides (8 au plus)", 1, true) ~= nil, true)
  eq(fab["r24"] and fab["r24"].refus.texte:find("0 boite(s) d'entree", 1, true) ~= nil, true) -- entrée-sortie : jamais comptée
  eq(fab["r6"] and fab["r6"].refus.texte:find("2 fluide(s) en sortie", 1, true) ~= nil, true)
  -- Bilan
  local sum = Lm.summary(fab)
  eq(sum.total, 21)
  eq(sum.patronnables, 9)
  eq(sum.refus["entrees_machine"], 2)
  eq(sum.refus["fluide_entree"], 3)
  eq(sum.refus["categorie"], 2)
  eq(sum.par_s[1], 4)
  eq(sum.par_s[2], 2)
  eq(sum.main, 5) -- r1, r2, r3, r16, r22 : catégorie de la main sans fluide (r4, r5, r6, r10 : fluide)
  -- Machines utilisables : filtre par l'objet
  local only_b = Lm.machines_for(fab["r1"], { ["m-b"] = true })
  eq(names_of(only_b), "m-b")
  eq(names_of(Lm.machines_for(fab["r1"], function(it) return it == "m-a" end)), "m-a")
  eq(names_of(Lm.machines_for(fab["r1"], nil)), "m-a,m-b")
  return bad
end

local bad = battery(L)
check(bad == 0, "§1 jeu de données écrit : " .. bad .. " écart(s) à la valeur attendue")
do
  local d = mini()
  local fab = L.read(d, { hand = { c1 = true } })
  check(fab["r21"] ~= nil, "§1 sans ensemble de recettes connues, toutes les recettes non cachées sont lues")
  check(fab["r17"] == nil, "§1 une recette cachée n'est jamais lue")
  check(L.line(L.summary(fab), 9):find("%d+ recettes lues, %d+ patronnables") ~= nil, "§1 ligne du journal")
end

---------------------------------------------------------------------------------------------------
-- §2 Kit de logistique
---------------------------------------------------------------------------------------------------
local function kit_dump()
  local d = { recipes = {}, entities = {} }
  local function e(name, ty, extra)
    local en = { name = name, type = ty, item = name, energy = "none" }
    for k, v in pairs(extra or {}) do en[k] = v end
    d.entities[#d.entities + 1] = en
  end
  local up, down = { x = 0, y = -1 }, { x = 0, y = 1.2 }
  local up2, down2 = { x = 0, y = -2 }, { x = 0, y = 2.2 }
  e("i-burner", "inserter", { energy = "burner", pickup = up, drop = down })
  e("i-elec", "inserter", { energy = "electric", pickup = up, drop = down })
  e("i-fast", "inserter", { energy = "electric", pickup = up, drop = down })
  e("i-filter", "inserter", { energy = "electric", pickup = up, drop = down, filters = 5 })
  e("i-weird", "inserter", { energy = "electric", pickup = up, drop = down2 })
  e("i-long", "inserter", { energy = "electric", pickup = up2, drop = down2 })
  e("i-long-b", "inserter", { energy = "electric", pickup = up2, drop = down2 })
  e("b-2", "transport-belt", { belt_speed = 0.06 })
  e("b-1", "transport-belt", { belt_speed = 0.03 })
  e("b-1x", "transport-belt", { belt_speed = 0.03 })
  e("k-wood", "container", { slots = 16 })
  e("k-iron", "container", { slots = 32 })
  e("k-none", "container", { slots = 0 })
  e("k-nomaker", "container", { slots = 8 }) -- aucune recette : jamais le moins cher
  e("p-s", "electric-pole", { supply = 2.5, wire = 7.5 })
  e("p-c", "electric-pole", { supply = 1, wire = 9 })
  local r = d.recipes
  local function item(n, a) return { type = "item", name = n, amount = a } end
  r["gear"] = rec("cr", 1, { item("plate", 2) }, { item("gear", 1) })
  r["i-burner"] = rec("cr", 1, { item("plate", 1) }, { item("i-burner", 1) })
  r["i-elec"] = rec("cr", 1, { item("gear", 1), item("plate", 1) }, { item("i-elec", 1) })
  r["i-fast"] = rec("cr", 1, { item("gear", 2), item("plate", 2) }, { item("i-fast", 1) })
  r["i-weird"] = rec("cr", 1, { item("plate", 1) }, { item("i-weird", 1) }) -- portées inégales : ni bras ni bras long
  r["i-filter"] = rec("cr", 1, { item("plate", 1) }, { item("i-filter", 1) })
  r["i-long"] = rec("cr", 1, { item("gear", 1), item("plate", 3) }, { item("i-long", 1) })
  r["i-long-b"] = rec("cr", 1, { item("gear", 1), item("plate", 3) }, { item("i-long-b", 1) })
  r["b-2"] = rec("cr", 1, { item("gear", 5), item("b-1", 1) }, { item("b-2", 1) })
  r["b-1"] = rec("cr", 1, { item("plate", 1), item("gear", 1) }, { item("b-1", 2) })
  r["b-1x"] = rec("cr", 1, { item("plate", 1), item("gear", 1) }, { item("b-1x", 2) })
  r["k-wood"] = rec("cr", 1, { item("wood", 2) }, { item("k-wood", 1) })
  r["k-none"] = rec("cr", 1, { item("wood", 1) }, { item("k-none", 1) }) -- le moins cher des coffres, mais sans case
  r["k-iron"] = rec("cr", 1, { item("plate", 8) }, { item("k-iron", 1) })
  r["p-s"] = rec("cr", 1, { item("wood", 1), item("cyc-a", 1) }, { item("p-s", 2) })
  r["p-c"] = rec("cr", 1, { item("plate", 1), item("cyc-a", 2) }, { item("p-c", 1) })
  r["cyc-a"] = rec("cr", 1, { item("cyc-b", 1) }, { item("cyc-a", 1) }) -- cycle : a demande b, b demande a
  r["cyc-b"] = rec("cr", 1, { item("cyc-a", 1) }, { item("cyc-b", 1) })
  return d
end

local function kit_battery(Lm)
  local bad = 0
  local function eq(a, b) if a ~= b then bad = bad + 1 end end
  local data = Lm.kit_data(kit_dump())
  local k = Lm.kit(data, nil)
  eq(k.bras and k.bras.item, "i-elec") -- électrique d'abord, filtre exclu, le moins cher (3 contre 6)
  eq(k.bras_long and k.bras_long.item, "i-long") -- égalité de prix : le nom
  eq(k.tapis and k.tapis.item, "b-1") -- égalité de prix : le nom
  eq(k.coffre and k.coffre.item, "k-wood") -- k-none (0 case) exclu ; 2 contre 8
  eq(k.poteau and k.poteau.item, "p-s")
  eq(#k.manque, 0)
  eq(k.bras and k.bras.price, 3)
  eq(k.tapis and k.tapis.price, 1.5) -- (1 + 2) / 2
  eq(k.poteau and k.poteau.supply, 2.5)
  eq(k.tapis and k.tapis.speed, 0.03)
  -- seuls les objets utilisables : la fonction ou l'ensemble
  local k2 = Lm.kit(data, { ["i-fast"] = true, ["i-burner"] = true, ["b-2"] = true })
  eq(k2.bras and k2.bras.item, "i-fast") -- l'électrique utilisable passe devant le bras à combustible moins cher
  eq(k2.tapis and k2.tapis.item, "b-2")
  eq(k2.bras_long, nil)
  eq(k2.coffre, nil)
  eq(table.concat(k2.manque, ","), "bras_long,coffre,poteau")
  local k3 = Lm.kit(data, function(it) return it == "i-burner" or it == "p-c" end)
  eq(k3.bras and k3.bras.item, "i-burner") -- faute d'électrique utilisable
  eq(k3.poteau and k3.poteau.item, "p-c")
  return bad
end

do
  local bad2 = kit_battery(L)
  check(bad2 == 0, "§2 kit de logistique : " .. bad2 .. " écart(s)")
  local d = kit_dump()
  local data = L.kit_data(d)
  local p = data.cands.poteau
  check(#p == 2 and p[1].price > 0 and p[1].price < 1e6, "§2 un cycle de recettes ne bloque pas le prix")
end

---------------------------------------------------------------------------------------------------
-- §3 Relevé vanilla + mod de référence
---------------------------------------------------------------------------------------------------
local BOXES = {
  ["assembling-machine-2"] = { box("input"), box("output") },
  ["assembling-machine-3"] = { box("input"), box("output") },
  ["chemical-plant"] = { box("input"), box("input"), box("output"), box("output") },
  ["oil-refinery"] = { box("input"), box("input"), box("output"), box("output"), box("output") },
}
local SIDE = { ["stone-furnace"] = 2, ["steel-furnace"] = 2, ["electric-furnace"] = 3, ["oil-refinery"] = 5 }

--- Complète le relevé des fixtures (qui ne portait ni emprise ni boîte) avec les valeurs de data/base (1.1.91, relevées par
--- `harness.lua --dump-final`) : 3 × 3 sauf les fours et la raffinerie ; `ingredient_count` absent (255) ; fours par le type.
local SLOTS = { ["wooden-chest"] = 16, ["iron-chest"] = 32, ["steel-chest"] = 48 }
local BELT = { ["transport-belt"] = 0.03125, ["fast-transport-belt"] = 0.0625 }
local POLE = { ["small-electric-pole"] = { 2.5, 7.5 }, ["medium-electric-pole"] = { 3.5, 9 } }
local function augment(dump)
  for _, e in ipairs(dump.entities) do
    if e.type == "assembling-machine" or e.type == "furnace" then
      e.w = SIDE[e.name] or 3
      e.h = e.w
      e.boxes = BOXES[e.name] or {}
    elseif e.type == "inserter" then
      local long = e.name == "long-handed-inserter"
      e.pickup = { x = 0, y = long and -2 or -1 }
      e.drop = { x = 0, y = long and 2.2 or 1.2 }
      e.energy = e.name == "burner-inserter" and "burner" or "electric"
      e.filters = 0
    elseif e.type == "container" then
      e.slots = SLOTS[e.name]
    elseif e.type == "transport-belt" then
      e.belt_speed = BELT[e.name]
    elseif e.type == "electric-pole" then
      e.supply, e.wire = POLE[e.name][1], POLE[e.name][2]
    end
  end
  return dump
end

local function vanilla(opts) return augment(F.dump(opts)) end

local cat_a = K.build(vanilla(), F.opts())
local cat_b = K.build(vanilla(), nil)
local cat_r = K.build(vanilla({ reverse = true }), F.opts())

local function shape(e)
  return string.format("%s|s%d|fi%d|fo%d|p%d|%s|%s|%s", e.category, e.s, #e.fluides_in, #e.fluides_out, #e.produits,
    tostring(e.main), tostring(e.patronnable), e.refus and e.refus.code or "-")
end

do
  local sum = cat_a.lecture
  print(string.format("[IND-LECTURE-TEST] relevé de référence : %s", L.line(sum, #cat_a.fab_machines)))
  check(sum.total > 250, "§3 le relevé de référence donne plus de 250 recettes lues (" .. sum.total .. ")")
  check(sum.patronnables > 200 and sum.patronnables <= sum.total, "§3 plus de 200 recettes patronnables (" .. sum.patronnables .. ")")
  -- Le refus à 3 ingrédients du constat 1 (PLAN §0) n'existe plus : une recette à 3 solides a des machines
  local e3, n3 = nil, 0
  for _, name in ipairs(sorted_keys(cat_a.fab)) do
    local e = cat_a.fab[name]
    if e.s == 3 and e.patronnable then
      n3 = n3 + 1
      e3 = e3 or e
    end
  end
  check(n3 >= 50, "§3 au moins 50 recettes à 3 entrées solides sont patronnables (" .. n3 .. ")")
  check(e3 ~= nil and #e3.machines >= 2, "§3 une recette à 3 solides a au moins deux machines (de la moins à la plus rapide)")
  if e3 then
    local ok = true
    for i = 2, #e3.machines do ok = ok and e3.machines[i - 1].speed <= e3.machines[i].speed end
    check(ok, "§3 machines triées par vitesse croissante")
  end
  -- Les recettes sans produit solide et sans machine sont refusées avec une raison écrite, jamais silencieuses
  local silent = 0
  for _, name in ipairs(sorted_keys(cat_a.fab)) do
    local e = cat_a.fab[name]
    if not e.patronnable and not (e.refus and e.refus.code and e.refus.texte) then silent = silent + 1 end
    if e.patronnable and #e.machines == 0 then silent = silent + 1 end
  end
  check(silent == 0, "§3 aucun refus muet, aucune recette patronnable sans machine (" .. silent .. ")")
  -- Indépendance vis-à-vis des exécutants : la lecture ne dépend que du relevé
  local same = true
  for _, name in ipairs(sorted_keys(cat_a.fab)) do
    if cat_b.fab[name] == nil or shape(cat_a.fab[name]) ~= shape(cat_b.fab[name])
        or names_of(cat_a.fab[name].machines) ~= names_of(cat_b.fab[name].machines) then
      same = false
    end
  end
  check(same, "§3 la lecture ne dépend pas des exécutants (exec et sans exec)")
  -- Déterminisme : listes inversées
  local same_r = true
  for _, name in ipairs(sorted_keys(cat_a.fab)) do
    if cat_r.fab[name] == nil or shape(cat_a.fab[name]) ~= shape(cat_r.fab[name])
        or names_of(cat_a.fab[name].machines) ~= names_of(cat_r.fab[name].machines) then
      same_r = false
    end
  end
  check(same_r and cat_r.lecture.total == sum.total, "§3 listes du relevé inversées : même lecture")
  -- Un fabricant à quatre fluides ou à cinq entrées solides de la raffinerie : les boîtes décident
  local oil = 0
  for _, name in ipairs(sorted_keys(cat_a.fab)) do
    local e = cat_a.fab[name]
    if #e.fluides_in >= 1 and e.patronnable then oil = oil + 1 end
  end
  check(oil >= 8, "§3 des recettes à fluide en entrée sont patronnables sur les machines à boîtes (" .. oil .. ")")
  -- Kit : sur le relevé de référence, tous les types du kit existent
  local kit = cat_a.kit()
  check(#kit.manque == 0, "§3 kit complet sur le relevé de référence (manque : " .. table.concat(kit.manque, ",") .. ")")
end

---------------------------------------------------------------------------------------------------
-- §4 Noms permutés
---------------------------------------------------------------------------------------------------
local function hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967291 end
  return string.format("zq%08x", h)
end

local function permute(dump)
  local seen, back = {}, {}
  local function f(n)
    if n == nil then return nil end
    local h = hash(n)
    if back[h] and back[h] ~= n then error("collision de hachage " .. n .. " / " .. back[h]) end
    back[h] = n
    seen[n] = h
    return h
  end
  local function fl(list)
    if list == nil then return nil end
    local out = {}
    for i, v in ipairs(list) do out[i] = f(v) end
    return out
  end
  local out = { recipes = {}, techs = {}, entities = {}, resources = {}, items = {} }
  for name, r in pairs(dump.recipes) do
    local nr = {}
    for k, v in pairs(r) do nr[k] = v end
    nr.category = f(r.category)
    nr.ingredients, nr.products = {}, {}
    for i, x in ipairs(r.ingredients) do nr.ingredients[i] = { type = x.type, name = f(x.name), amount = x.amount } end
    for i, x in ipairs(r.products) do nr.products[i] = { type = x.type, name = f(x.name), amount = x.amount } end
    out.recipes[f(name)] = nr
  end
  for name, t in pairs(dump.techs) do
    local nt = {}
    for k, v in pairs(t) do nt[k] = v end
    nt.ingredients = {}
    for i, x in ipairs(t.ingredients) do nt.ingredients[i] = { f(x[1]), x[2] } end
    nt.prerequisites, nt.unlocks = fl(t.prerequisites), fl(t.unlocks)
    out.techs[f(name)] = nt
  end
  for _, e in ipairs(dump.entities) do
    local ne = {}
    for k, v in pairs(e) do ne[k] = v end
    ne.name, ne.item = f(e.name), f(e.item)
    ne.crafting_categories, ne.resource_categories = fl(e.crafting_categories), fl(e.resource_categories)
    ne.fluid, ne.fluid_in, ne.fluid_out = f(e.fluid), f(e.fluid_in), f(e.fluid_out)
    ne.lab_inputs = fl(e.lab_inputs)
    out.entities[#out.entities + 1] = ne
  end
  for _, r in ipairs(dump.resources) do
    local nr = { entity = f(r.entity), category = f(r.category), products = {} }
    for i, x in ipairs(r.products) do nr.products[i] = { type = x.type, name = f(x.name), amount = x.amount } end
    out.resources[#out.resources + 1] = nr
  end
  for name, it in pairs(dump.items) do
    local ni = {}
    for k, v in pairs(it) do ni[k] = v end
    out.items[f(name)] = ni
  end
  return out, f
end

do
  local perm, f = permute(vanilla())
  local cat_p = K.build(perm, nil)
  local sum, sump = cat_a.lecture, cat_p.lecture
  check(sum.total == sump.total and sum.patronnables == sump.patronnables and sum.main == sump.main,
    string.format("§4 noms permutés : mêmes totaux (%d/%d patronnables, %d/%d à la main)", sum.patronnables, sump.patronnables, sum.main, sump.main))
  local keys_ok = true
  for _, c in ipairs(sorted_keys(sum.refus)) do keys_ok = keys_ok and sump.refus[c] == sum.refus[c] end
  for _, c in ipairs(sorted_keys(sump.refus)) do keys_ok = keys_ok and sum.refus[c] == sump.refus[c] end
  for _, s in ipairs(sorted_keys(sum.par_s)) do keys_ok = keys_ok and sump.par_s[s] == sum.par_s[s] end
  check(keys_ok, "§4 noms permutés : mêmes raisons de refus, mêmes nombres d'entrées")
  local n_bad, n_cmp = 0, 0
  for _, name in ipairs(sorted_keys(cat_a.fab)) do
    local a, b = cat_a.fab[name], cat_p.fab[f(name)]
    n_cmp = n_cmp + 1
    if not b or shape(a):gsub("^[^|]*", "") ~= shape(b):gsub("^[^|]*", "") then
      n_bad = n_bad + 1
    else
      -- mêmes machines (comparées par leur nom permuté) et mêmes débits, à l'ordre près des égalités de vitesse
      local la, lb = {}, {}
      for _, m in ipairs(a.machines) do la[#la + 1] = f(m.entity) .. "=" .. m.par_min end
      for _, m in ipairs(b.machines) do lb[#lb + 1] = m.entity .. "=" .. m.par_min end
      table.sort(la)
      table.sort(lb)
      if table.concat(la, ",") ~= table.concat(lb, ",") then n_bad = n_bad + 1 end
    end
  end
  check(n_bad == 0 and n_cmp == sum.total, string.format("§4 noms permutés : %d recettes comparées une à une, %d écart(s)", n_cmp, n_bad))
  local kit, kitp = cat_a.kit(), cat_p.kit()
  local kit_ok = #kitp.manque == #kit.manque
  for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do
    kit_ok = kit_ok and ((kit[k] == nil) == (kitp[k] == nil)) and (kit[k] == nil or f(kit[k].item) == kitp[k].item)
  end
  check(kit_ok, "§4 noms permutés : le kit retombe sur la même pièce de chaque type")
  -- Le jeu de données écrit, permuté lui aussi (le tableau EXPECT passe par le hachage des noms de recettes)
  local dmini = mini()
  local pm = { recipes = {}, entities = dmini.entities }
  local fab_orig = L.read(dmini, { hand = { c1 = true } })
  local mapped = {}
  for name, r in pairs(dmini.recipes) do
    local nr = {}
    for k, v in pairs(r) do nr[k] = v end
    nr.category = hash(r.category)
    nr.ingredients = {}
    for i, x in ipairs(r.ingredients) do nr.ingredients[i] = { type = x.type, name = hash(x.name), amount = x.amount } end
    pm.recipes[hash(name)] = nr
    mapped[name] = hash(name)
  end
  pm.entities = {}
  for _, e in ipairs(dmini.entities) do
    local ne = {}
    for k, v in pairs(e) do ne[k] = v end
    ne.name, ne.item = hash(e.name), e.item and hash(e.item) or nil
    ne.crafting_categories = {}
    for i, c in ipairs(e.crafting_categories) do ne.crafting_categories[i] = hash(c) end
    ne.fixed_recipe = e.fixed_recipe and hash(e.fixed_recipe) or nil
    ne.boxes = {}
    for i, b in ipairs(e.boxes) do ne.boxes[i] = { type = b.type, filter = b.filter and hash(b.filter) or nil, conns = b.conns } end
    pm.entities[#pm.entities + 1] = ne
  end
  local fab_p = L.read(pm, { hand = { [hash("c1")] = true } })
  local n_bad2 = 0
  for _, name in ipairs(sorted_keys(fab_orig)) do
    local a, b = fab_orig[name], fab_p[mapped[name]]
    if not b or a.patronnable ~= b.patronnable or (a.refus and a.refus.code) ~= (b.refus and b.refus.code)
        or #a.machines ~= #b.machines or a.main ~= b.main then
      n_bad2 = n_bad2 + 1
    end
  end
  check(n_bad2 == 0, "§4 jeu de données écrit, noms permutés (filtres de boîtes et recette imposée compris) : " .. n_bad2 .. " écart(s)")
end

---------------------------------------------------------------------------------------------------
-- §5 Mini-mod inventé greffé au relevé de référence
---------------------------------------------------------------------------------------------------
do
  local dump = vanilla()
  -- machine 4 × 4 à catégorie neuve, 2 boîtes d'entrée et 1 de sortie, 4 solides au plus
  dump.entities[#dump.entities + 1] = { name = "zz-fonderie-quantique", type = "assembling-machine", item = "zz-fonderie-quantique",
    crafting_categories = { "zz-quantique" }, energy = "electric", speed = 3, w = 4, h = 4, ingredient_count = 4,
    boxes = { box("input"), box("input"), box("output") } }
  -- objet à 3 solides et 1 fluide, et sa propre chaîne de fabrication à la main
  dump.recipes["zz-noyau"] = rec("zz-quantique", 4, { { type = "item", name = "zz-a", amount = 2 }, { type = "item", name = "zz-b", amount = 1 },
    { type = "item", name = "zz-c", amount = 1 }, { type = "fluid", name = "zz-brume", amount = 20 } }, { { type = "item", name = "zz-noyau", amount = 1 } })
  dump.recipes["zz-noyau"].enabled = true
  for _, n in ipairs({ "zz-a", "zz-b", "zz-c", "zz-noyau" }) do dump.items[n] = { type = "item" } end
  -- bras neuf, tourelle neuve : lus par le type
  dump.entities[#dump.entities + 1] = { name = "zz-bras-nova", type = "inserter", item = "zz-bras-nova", energy = "electric",
    pickup = { x = 0, y = -1 }, drop = { x = 0, y = 1.2 } }
  dump.entities[#dump.entities + 1] = { name = "zz-tourelle", type = "ammo-turret", item = "zz-tourelle", energy = "none" }
  dump.recipes["zz-bras-nova"] = rec("crafting", 1, { { type = "item", name = "zz-a", amount = 1 } }, { { type = "item", name = "zz-bras-nova", amount = 1 } })
  dump.items["zz-bras-nova"] = { type = "item" }
  dump.items["zz-tourelle"] = { type = "item" }
  local cat = K.build(dump, nil)
  local e = cat.fab["zz-noyau"]
  check(e ~= nil and e.patronnable and e.s == 3 and #e.fluides_in == 1 and names_of(e.machines) == "zz-fonderie-quantique",
    "§5 recette à 3 solides et 1 fluide d'une catégorie neuve : lue, patronnable sur la machine neuve")
  check(e ~= nil and e.machines[1] and e.machines[1].w == 4 and e.machines[1].par_min == 45, "§5 emprise 4 × 4 lue, débit 60 × 3 ÷ 4 = 45 par minute")
  check(cat.fab["zz-noyau"] and not cat.fab["zz-noyau"].main, "§5 la main ne fait pas une recette à fluide")
  check(cat.lecture.total == cat_a.lecture.total + 2 and cat.lecture.patronnables == cat_a.lecture.patronnables + 2,
    "§5 deux recettes de plus lues, deux patronnables de plus")
  local kit = cat.kit()
  check(kit.bras and (kit.bras.item == "zz-bras-nova" or kit.bras.price <= 4), "§5 le bras neuf entre au choix du kit sans une ligne de code")
  local kit2 = cat.kit({ ["zz-bras-nova"] = true })
  check(kit2.bras and kit2.bras.item == "zz-bras-nova", "§5 le bras neuf est choisi quand lui seul est utilisable")
  check(cat.role["zz-tourelle"] == "militaire" and cat.role["zz-bras-nova"] == "logistique",
    "§5 la tourelle neuve et le bras neuf ont leur rôle par le TYPE du moteur")
  -- machine retirée : la recette retombe sur un refus écrit
  local dump2 = vanilla()
  dump2.recipes["zz-noyau"] = dump.recipes["zz-noyau"]
  local cat2 = K.build(dump2, nil)
  local e2 = cat2.fab["zz-noyau"]
  check(e2 and not e2.patronnable and e2.refus.code == "categorie" and e2.refus.texte:find("zz-quantique", 1, true) ~= nil,
    "§5 sans la machine neuve : refus « categorie » écrit avec la catégorie")
end

---------------------------------------------------------------------------------------------------
-- §6 Mutants
---------------------------------------------------------------------------------------------------
local function read_source(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

local SRC = read_source("shared/ai3/lecture.lua")

local function plain_replace(s, old, new)
  local i, j = s:find(old, 1, true)
  if not i then return nil end
  if s:find(old, j + 1, true) then return nil, "motif en double" end
  return s:sub(1, i - 1) .. new .. s:sub(j + 1)
end

local MUTANTS = {
  { "plafond d'ingrédients : >= devient >", "if m.cap >= e.s then", "if m.cap > e.s then" },
  { "boîtes : <= devient <", "return n_left <= free", "return n_left < free" },
  { "filtre de boîte ignoré", "      if b.filter then\n        if left[b.filter] then", "      if false then\n        if left[b.filter] then" },
  { "recette imposée ignorée", "if m.fixed == nil or m.fixed == name then", "if true then" },
  { "plafond du patron : > devient >=", "if e.s > L.MAX_SOLIDES then", "if e.s >= L.MAX_SOLIDES then" },
  { "emprise : <= devient <", "if side <= L.MAX_COTE then", "if side < L.MAX_COTE then" },
  { "sortie sans objet acceptée", "if e.sorties_solides == 0 then", "if false then" },
  { "catégorie sans machine acceptée", "if #cands == 0 then", "if false then" },
  { "plafond du four lu au moteur", "local cap = R.SOURCE_CAP[e.type] or e.ingredient_count", "local cap = e.ingredient_count" },
  { "boîte entrée-sortie comptée dans l'ajustement des fluides", "    if b.type == kind then\n      if b.filter then",
    "    if b.type == kind or b.type == \"input-output\" then\n      if b.filter then" },
  { "boîte entrée-sortie comptée en sortie", "local function count_boxes(m, kind)\n  local n = 0\n  for _, b in ipairs(m.boxes) do if b.type == kind then n = n + 1 end end",
    "local function count_boxes(m, kind)\n  local n = 0\n  for _, b in ipairs(m.boxes) do if b.type == kind or b.type == \"input-output\" then n = n + 1 end end" },
  { "kit : le plus cher", "if c.price < best.price then best = c end", "if c.price > best.price then best = c end" },
  { "kit : filtre non exclu", "if (e.filters or 0) == 0 and rp and rp == rd then", "if rp and rp == rd then" },
  { "kit : portées asymétriques admises", "if (e.filters or 0) == 0 and rp and rp == rd then", "if (e.filters or 0) == 0 and rp then" },
  { "recette cachée lue", "if not r.hidden and (opts.known == nil or opts.known[name]) then", "if (opts.known == nil or opts.known[name]) then" },
  { "recettes inconnues lues", "if not r.hidden and (opts.known == nil or opts.known[name]) then", "if not r.hidden then" },
  { "tri des machines inversé", "if a.speed ~= b.speed then return a.speed < b.speed end", "if a.speed ~= b.speed then return a.speed > b.speed end" },
  { "débit sans la minute", "local per_min = 60 * m.speed", "local per_min = m.speed" },
  { "main sans condition de fluide", "e.main = (hand ~= nil and hand[r.category] == true) and #e.fluides_in == 0 and #e.fluides_out == 0",
    "e.main = (hand ~= nil and hand[r.category] == true)" },
  { "kit : combustible autant que l'électrique", "local key_c = c.energy == \"electric\" and 0 or 1", "local key_c = 0" },
  { "kit : prix d'un cycle infini", "if not rn or busy[item] then return 1 end", "if not rn then return 1 end" },
  { "kit : pièce sans recette comptée pour 1", "c.price = maker[c.item] and price(c.item) or L.SANS_RECETTE", "c.price = price(c.item)" },
  { "kit : coffre sans case admis", "if (e.slots or 0) > 0 then table.insert(cands.coffre, c) end", "table.insert(cands.coffre, c)" },
  { "objet absent : machine posée quand même", "if R.ENTITY_ROLE[e.type or \"\"] == \"fabrique\" and e.item and", "if R.ENTITY_ROLE[e.type or \"\"] == \"fabrique\" and" },
}

local caught = 0
for _, mu in ipairs(MUTANTS) do
  local src, why = plain_replace(SRC, mu[2], mu[3])
  if not src then
    check(false, "§6 motif du mutant introuvable (" .. tostring(why) .. ") : " .. mu[1])
  else
    local chunk, err = load(src, "=lecture_mutant", "t")
    local detected
    if not chunk then
      detected = true
      print("  (mutant « " .. mu[1] .. " » : source invalide " .. tostring(err) .. ")")
    else
      local ok, Lm = pcall(chunk)
      if not ok then
        detected = true
      else
        local ok2, b1 = pcall(battery, Lm)
        local ok3, b2 = pcall(kit_battery, Lm)
        detected = (not ok2) or (not ok3) or b1 > 0 or b2 > 0
      end
    end
    if detected then caught = caught + 1 end
    check(detected, "§6 mutant refusé : " .. mu[1])
  end
end
check(caught == #MUTANTS, string.format("§6 mutants : %d refusés sur %d", caught, #MUTANTS))

print(string.format("[IND-LECTURE-TEST] BILAN : %d OK, %d ECHEC(S) (dont %d mutants refusés sur %d)", pass, fail, caught, #MUTANTS))
os.exit(fail == 0 and 0 or 1)
