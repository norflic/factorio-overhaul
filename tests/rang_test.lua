--[[
  Lot L1 « le rang calculé » (tiers dynamiques) : test hors jeu de la règle PURE shared/ai3/rang.lua.
  Rien n'est branché en jeu.

    §1 règle sur des données jouets (relevé passé par Ca.data, comme en jeu) : chaîne, min sur les recettes, cycle contracté,
       amorce (recette qui consomme son produit, cycle sans entrée), bruts à 0, objet sans recette, recette de vidage,
       recherche qui ouvre une recette (rang, signature, cache), catégorie sans fabrique ;
    §2 livre réel (tests/fixtures/recipes_ia1e.lua par tests/iag_fixture.lua, ce que Ca.data lit dans les tests) :
       invariants (ingrédient < produit hors cycle, niveau croissant sur toute recette retenue, bruts à 0, rangs triés),
       valeurs vanilla, les 3 erreurs de la table de l'auteur de la vidéo, cycles réels, ouverture technologie par
       technologie (le cache n'est refait que si une recette retenue s'ouvre ; aucun rang ne monte sans cycle nouveau),
       même prédicat que Ca.unpackers et Ca.recipe_open ;
    §3 déterminisme : listes inversées, recettes, ingrédients et tables permutés : même résultat, même signature ;
    §4 livre complété (SUPPOSÉ : catégories sans fabrique et objets sans recette reçoivent une fabrique et une ressource
       fictives, parce que la fixture ne connaît ni les machines ni les ressources du mod) : rien sans rang, cycles du mod ;
    §5 comparaison au `depth` de Ca.requirements (shared/ai3/capitalisation.lua:764-788) : écarts et raison de chacun ;
    §6 coût en INSTRUCTIONS (debug.sethook) : calcul complet, lecture du cache, part de Ca.requirements dans Ca.decide ;
    §7 aucun pairs sans tri dans la règle ; §8 mutants appliqués au SOURCE de la règle (chacun doit faire échouer §1 à §4 ou §9) ;
    §9 rang de la DÉCISION (Rg.chain, docs/TODO_VIDEO.md §H) : recette choisie, feuilles à 0, cycles contractés et amorcés,
       I5 (égal au depth sur des appels RÉELS de Ca.requirements sans cycle), I1, I6, chemin rapide = chemin complet,
       déterminisme (relevé permuté, graines inversées), borne linéaire sur une chaîne de 6 000 objets (I8).
  Usage : lua5.2 tests/rang_test.lua [--livre <relevé de harness.lua --dump-recipes>] [--ecarts]   (depuis la racine du mod)
  Ce fichier est du TEST : il nomme les prototypes vanilla (comme le moteur) ; la règle n'en voit rien.
]]

package.path = "./?.lua;" .. package.path
local F = require("tests.iag_fixture")
local Ca = require("shared.ai3.capitalisation")
local Rg0 = require("shared.ai3.rang")

local LIVRE, ECARTS = nil, false
for i = 1, #arg do
  if arg[i] == "--livre" then LIVRE = arg[i + 1] end
  if arg[i] == "--ecarts" then ECARTS = true end
end

local pass, fail = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then pass = pass + 1 else
    fail = fail + 1
    if not quiet then print("[RANG] ECHEC : " .. msg) end
  end
end
local function say(s) if not quiet then print("[RANG] " .. s) end end

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function copy(t)
  local c = {}
  for k, v in pairs(t) do c[k] = v end
  return c
end

local function deep(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = deep(v) end
  return c
end

---------------------------------------------------------------------------------------------------
-- Données
---------------------------------------------------------------------------------------------------
--- Relevé réel : fixture des tests, recettes débloquées par une technologie inactives au départ (comme dans le jeu).
local function real_dump(recipes_file)
  local d = F.dump()
  if recipes_file then d.recipes = deep(dofile(recipes_file)) end
  for _, t in ipairs(sorted_keys(d.techs)) do
    for _, r in ipairs(d.techs[t].unlocks or {}) do if d.recipes[r] then d.recipes[r].enabled = false end end
  end
  return d
end

--- Relevé COMPLÉTÉ (supposé) : une fabrique fictive par catégorie qu'aucune machine ne fait, une ressource fictive par
--- objet qu'aucune recette retenue (hors vidage) ni ressource ne rend (bois, minerais et fluides du mod, vapeur des
--- chaudières…).
local function augmented_dump(recipes_file)
  local d = real_dump(recipes_file)
  local covered = {}
  for _, e in ipairs(d.entities) do
    for _, c in ipairs(e.crafting_categories or {}) do covered[c] = true end
  end
  local cats = {}
  for _, rn in ipairs(sorted_keys(d.recipes)) do
    local r = d.recipes[rn]
    if not r.hidden and not covered[r.category or ""] then cats[r.category or ""] = true end
  end
  for _, c in ipairs(sorted_keys(cats)) do
    d.entities[#d.entities + 1] = { name = "fictive-" .. c, type = "assembling-machine", item = "fictive-" .. c,
      crafting_categories = { c }, energy = "none", speed = 1 }
  end
  local D0 = Ca.data(d, {})
  local unp = Ca.unpackers(D0)
  local made = {}
  for n in pairs(D0.res) do made[n] = true end
  for n in pairs(D0.pumped) do made[n] = true end
  for _, rn in ipairs(D0.recipe_list) do
    if not unp[rn] then for _, p in ipairs(D0.recipes[rn].products) do made[p.name] = true end end
  end
  local used = {}
  for _, rn in ipairs(D0.recipe_list) do
    if not unp[rn] then
      for _, i in ipairs(D0.recipes[rn].ingredients) do if not made[i.name] then used[i.name] = i.fluid and "fluid" or "item" end end
    end
  end
  for _, n in ipairs(sorted_keys(used)) do
    d.resources[#d.resources + 1] = { entity = "fictive-" .. n, category = "fictive",
      products = { { type = used[n] or "item", name = n, amount = 1 } } }
  end
  return d, #sorted_keys(cats), #sorted_keys(used)
end

local DUMP = real_dump()
local D = Ca.data(DUMP, {})
local ALL = {}
for _, t in ipairs(sorted_keys(DUMP.techs)) do ALL[t] = true end
local ADUMP, A_CATS, A_RES = augmented_dump()
local DA = Ca.data(ADUMP, {})

-- Relevé vanilla RÉALISTE (vitesses, aires, puissances de data/base 1.1.91 : copie de tests/ai3_capitalisation_test.lua) pour
-- des décisions réelles de la capitalisation (§6, §9).
local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["electric-furnace"] = 2, ["assembling-machine-1"] = 0.5,
  ["assembling-machine-2"] = 0.75, ["assembling-machine-3"] = 1.25, ["burner-mining-drill"] = 0.25,
  ["electric-mining-drill"] = 0.5, ["pumpjack"] = 1, ["lab"] = 1, ["chemical-plant"] = 1, ["oil-refinery"] = 1, ["centrifuge"] = 1 }
local V_AREA = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5, ["pumpjack"] = 1 }
local V_SIZE = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 3, ["stone-furnace"] = 2, ["steel-furnace"] = 2 }
local V_KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["electric-furnace"] = 180, ["burner-mining-drill"] = 150,
  ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150,
  ["assembling-machine-3"] = 375, ["lab"] = 60, ["boiler"] = 1800 }
local function vanilla(d)
  for _, e in ipairs(d.entities) do
    if V_SPEED[e.name] then e.speed = V_SPEED[e.name] end
    e.mining_area = V_AREA[e.name]
    e.size = V_SIZE[e.name] or 3
    e.energy_kw = V_KW[e.name]
  end
  for _, r in ipairs(d.resources) do r.mining_time = r.entity == "uranium-ore" and 2 or 1 end
  return d
end
local EXEC = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["burner-mining-drill"] = true,
  ["electric-mining-drill"] = true, ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
local DV = Ca.data(vanilla(real_dump()), { exec = EXEC, exec_roles = { main = true, labo = true } })
local DVA = Ca.data(vanilla((augmented_dump())), {})

--- Entrée d'une décision (scène riche de tests/ai3_capitalisation_test.lua §12, puits et recherches au choix).
local function scene(Dx, techs, sinks)
  return { data = Dx, state = { techs = techs }, stock = { ["electronic-circuit"] = 3000 }, workers = 30, idle = 10,
    can_grow = true, traits = {}, weights = {}, open = {},
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 },
      { id = "dc", resource = "copper-ore", tiles = 200, amount = 5e5, open = true, dist = 80, smelt = "copper-plate",
        smelter = "stone-furnace" },
      { id = "dk", resource = "coal", tiles = 200, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 4, deposit = "d1" },
      { entity = "burner-mining-drill", resource = "copper-ore", n = 4, deposit = "dc" },
      { entity = "burner-mining-drill", resource = "coal", n = 2, deposit = "dk" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 6, where = "qg" },
      { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d1" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 4, where = "dc" } },
    labs = { { entity = "lab", n = 8 } },
    research = { queue = { { tech = "electronics", left = 27, time = 15, packs = { { "automation-science-pack", 1 } } },
      { tech = "fast-inserter", left = 2000, time = 15, packs = { { "automation-science-pack", 1 } } } }, rate = 450 },
    flows = { ["iron-ore"] = { made = 120 }, ["iron-plate"] = { made = 110 }, ["copper-plate"] = { made = 60 },
      ["coal"] = { made = 30 }, ["iron-gear-wheel"] = { made = 20, hand = 20 } },
    sinks = sinks }
end

--- Tous les appels de Ca.requirements d'une décision réelle (ctx, plan, besoin rendu). `hook` (facultatif) : appelée autour de
--- chaque appel (mesure).
local function capture(inp, around)
  local calls, orig = {}, Ca.requirements
  Ca.requirements = function(cx, pl)
    local req = around and around(function() return orig(cx, pl) end, cx) or orig(cx, pl)
    calls[#calls + 1] = { ctx = cx, plan = pl, req = req }
    return req
  end
  local ok, res = pcall(Ca.decide, inp, {})
  Ca.requirements = orig
  assert(ok, res)
  return calls, res
end

--- Besoin de TOUS les objets du livre ouvert (pire fermeture d'une décision), par Ca.requirements.
local function all_req(Dx, techs)
  local need = {}
  for _, rn in ipairs(Dx.recipe_list) do
    if Ca.recipe_open({ D = Dx, techs = techs }, rn) then
      for _, p in ipairs(Dx.recipes[rn].products) do if not Dx.res[p.name] then need[p.name] = 1 end end
    end
  end
  local cats = {}
  for c in pairs(Dx.hand) do cats[c] = true end
  local ctx = { D = Dx, input = { need = need }, sinks = {}, open = {}, pack_rates = {}, stock = {}, rec_memo = {},
    cats_present = cats, techs = techs, best_m = {}, best_d = {}, obt = {}, fuel_mu = 0 }
  return { ctx = ctx, plan = { burn = 0 }, req = Ca.requirements(ctx, { burn = 0 }) }
end

--- La recette CHOISIE par la capitalisation pendant la décision (mémo de choose_recipe) ; D2 : relevé permuté (ses copies).
local function pick_of(ctx, D2)
  return function(i)
    local m = ctx.rec_memo[i]
    if not m then return nil, "hors memo" end
    if m.r and D2 then return D2.recipes[m.r.name], m.why end
    return m.r, m.why
  end
end

-- Corpus des décisions : départ, toutes recherches (packs hauts, uranium), livre complété (objets des rangs hauts), et la
-- fermeture de TOUS les objets (fixture et livre complété).
local CORPUS = {}
do
  local auto = { automation = true }
  local top = {}
  local RVA = Rg0.build(DVA, nil)
  for k = 6, RVA.max do for _, n in ipairs(RVA.tiers[k]) do top[#top + 1] = { item = n, rate = 1 } end end
  local scenes = {
    { "riche", scene(DV, auto, { { item = "firearm-magazine", rate = 20, elastic = true } }) },
    { "packs hauts", scene(DV, ALL, { { item = "utility-science-pack", rate = 5 }, { item = "production-science-pack", rate = 5 } }) },
    { "uranium", scene(DV, ALL, { { item = "uranium-fuel-cell", rate = 2 }, { item = "rocket-control-unit", rate = 2 } }) },
    { "livre complet, rangs hauts", scene(DVA, ALL, top) },
  }
  for _, s in ipairs(scenes) do
    local calls = capture(s[2])
    for j, c in ipairs(calls) do CORPUS[#CORPUS + 1] = { label = s[1] .. " #" .. j, ctx = c.ctx, plan = c.plan, req = c.req } end
  end
  local a = all_req(D, ALL)
  CORPUS[#CORPUS + 1] = { label = "tous les objets (fixture)", ctx = a.ctx, plan = a.plan, req = a.req }
  local b = all_req(DA, ALL)
  CORPUS[#CORPUS + 1] = { label = "tous les objets (livre complet)", ctx = b.ctx, plan = b.plan, req = b.req }
end

--- Relevé jouet au format du moteur, passé par Ca.data. recipes = { nom = { cat, ingrédients, produits, [tech] } }.
local function toy(recipes, extra)
  local d = { recipes = {}, techs = {}, items = {}, resources = {
      { entity = "o1", category = "r", products = { { type = "item", name = "o1", amount = 1 } } } },
    entities = {
      { name = "corps", type = "character", crafting_categories = { "c" }, resource_categories = { "r" } },
      { name = "m1", type = "assembling-machine", item = "m1", crafting_categories = { "c", "k" }, energy = "none" },
      { name = "pp", type = "offshore-pump", item = "pp", fluid = "fl", energy = "none" } } }
  local function list(l, kind)
    local out = {}
    for _, x in ipairs(l or {}) do
      out[#out + 1] = { type = (x[1] == "fl" or x[3] == "fluid") and "fluid" or "item", name = x[1], amount = x[2] or 1 }
    end
    return out
  end
  for _, rn in ipairs(sorted_keys(recipes)) do
    local r = recipes[rn]
    d.recipes[rn] = { category = r[1], energy = 1, hidden = false, enabled = r[4] == nil, ingredients = list(r[2]),
      products = list(r[3]) }
    if r[4] then
      d.techs[r[4]] = d.techs[r[4]] or { unlocks = {}, enabled = true, hidden = false, ingredients = {} }
      local u = d.techs[r[4]].unlocks
      u[#u + 1] = rn
    end
  end
  if extra then extra(d) end
  return Ca.data(d, {})
end

--- Résultat sérialisé (tout ce qui est rendu, dans l'ordre rendu).
local function ser(R)
  local t = {}
  for _, k in ipairs(sorted_keys(R.rank)) do
    t[#t + 1] = string.format("%s=%s/%s/%s/%s", k, tostring(R.rank[k]), tostring(R.rec[k]), tostring(R.level[k]), tostring(R.cyc[k]))
  end
  for k = 0, R.max do t[#t + 1] = "T" .. k .. ":" .. table.concat(R.tiers[k] or {}, ",") end
  for _, c in ipairs(R.cycles) do
    t[#t + 1] = "C" .. c.id .. ":" .. table.concat(c.members, ",") .. ":" .. tostring(c.rank) .. ":" .. tostring(c.seeded)
  end
  for _, k in ipairs(sorted_keys(R.seed)) do
    local s = {}
    for _, x in ipairs(R.seed[k]) do s[#s + 1] = x[1] .. "x" .. x[2] end
    t[#t + 1] = "S" .. k .. ":" .. table.concat(s, ",")
  end
  t[#t + 1] = "N:" .. table.concat(R.none, ",")
  for _, k in ipairs(sorted_keys(R.why)) do t[#t + 1] = "W" .. k .. ":" .. R.why[k] end
  t[#t + 1] = "R:" .. table.concat(R.recipes, ",")
  return table.concat(t, "\n")
end

--- Relevé permuté : liste des recettes, tables des recettes, ingrédients, produits, fabriques et ressources dans un autre
--- ordre d'insertion (générateur congruentiel à graine fixe).
local function shuffled(D0, s)
  local x = s
  local function rnd(n)
    x = (x * 1103515245 + 12345) % 2147483648
    return x % n + 1
  end
  local function perm(list)
    local o = {}
    for i, v in ipairs(list) do o[i] = v end
    for i = #o, 2, -1 do
      local j = rnd(i)
      o[i], o[j] = o[j], o[i]
    end
    return o
  end
  local D2 = copy(D0)
  D2.recipe_list = perm(D0.recipe_list)
  D2.recipes = {}
  for _, rn in ipairs(D2.recipe_list) do
    local r2 = copy(D0.recipes[rn])
    r2.ingredients, r2.products = perm(r2.ingredients), perm(r2.products)
    D2.recipes[rn] = r2
  end
  D2.makers = perm(D0.makers)
  local rl = perm(sorted_keys(D0.res))
  D2.res = {}
  for _, n in ipairs(rl) do D2.res[n] = D0.res[n] end
  D2.res_list = rl
  local pl = perm(sorted_keys(D0.pumped))
  D2.pumped = {}
  for _, n in ipairs(pl) do D2.pumped[n] = true end
  local hl = perm(sorted_keys(D0.hand))
  D2.hand = {}
  for _, n in ipairs(hl) do D2.hand[n] = true end
  return D2
end

--- Invariants d'un résultat sur un relevé : rend le nombre de violations et la première de chaque sorte.
local function invariants(Rg, Dx, R)
  local raw = {}
  for n in pairs(Dx.res) do raw[n] = true end
  for n in pairs(Dx.pumped) do raw[n] = true end
  local v = { i1 = 0, lvl = 0, raw = 0, zero = 0, sorted = 0, part = 0 }
  local first = {}
  local function bad(k, msg)
    v[k] = v[k] + 1
    first[k] = first[k] or msg
  end
  -- I1 : recette du rang, ingrédients strictement plus bas hors du même cycle.
  for _, i in ipairs(sorted_keys(R.rank)) do
    local rn = R.rec[i]
    if rn then
      for _, ing in ipairs(Dx.recipes[rn].ingredients) do
        local same = R.cyc[i] ~= nil and R.cyc[i] == R.cyc[ing.name]
        local ki = R.rank[ing.name]
        if not same and (ki == nil or ki >= R.rank[i]) then
          bad("i1", string.format("%s (%d, %s) <- %s (%s)", i, R.rank[i], rn, ing.name, tostring(ki)))
        end
      end
    elseif not raw[i] then bad("i1", i .. " a un rang sans recette") end
  end
  -- Niveau : strictement croissant le long de TOUTE recette retenue, hors du même cycle.
  for _, rn in ipairs(R.recipes) do
    local r = Dx.recipes[rn]
    for _, p in ipairs(r.products) do
      if p.amount > 0 and not raw[p.name] then
        for _, ing in ipairs(r.ingredients) do
          local same = R.cyc[p.name] ~= nil and R.cyc[p.name] == R.cyc[ing.name]
          if not same and not ((R.level[ing.name] or -1) < (R.level[p.name] or -1)) then
            bad("lvl", string.format("%s : %s (%s) -> %s (%s)", rn, ing.name, tostring(R.level[ing.name]), p.name, tostring(R.level[p.name])))
          end
        end
      end
    end
  end
  -- Bruts à 0, rien d'autre à 0.
  for n in pairs(raw) do if R.rank[n] ~= 0 then bad("raw", n .. " brut au rang " .. tostring(R.rank[n])) end end
  for _, i in ipairs(sorted_keys(R.rank)) do
    if not raw[i] and R.rank[i] < 1 then bad("zero", i .. " non brut au rang " .. R.rank[i]) end
  end
  -- Rangs : listes triées, partition des objets qui ont un rang ; sans rang : triés, disjoints.
  local seen = {}
  for k = 0, R.max do
    local l = R.tiers[k] or {}
    for j, n in ipairs(l) do
      if j > 1 and not (l[j - 1] < n) then bad("sorted", "rang " .. k .. " : " .. l[j - 1] .. " avant " .. n) end
      if R.rank[n] ~= k then bad("part", n .. " dans le rang " .. k .. " mais rang " .. tostring(R.rank[n])) end
      seen[n] = true
    end
  end
  for _, n in ipairs(sorted_keys(R.rank)) do if not seen[n] then bad("part", n .. " absent des rangs") end end
  for j, n in ipairs(R.none) do
    if j > 1 and not (R.none[j - 1] < n) then bad("sorted", "sans rang : " .. R.none[j - 1] .. " avant " .. n) end
    if R.rank[n] ~= nil then bad("part", n .. " sans rang mais rang " .. R.rank[n]) end
  end
  local total = 0
  for _, k in pairs(v) do total = total + k end
  return total, v, first
end

---------------------------------------------------------------------------------------------------
-- Batterie (§1 à §4) : rejouée par chaque mutant
---------------------------------------------------------------------------------------------------
local function battery(Rg)
  local p0, f0 = pass, fail

  -- §1 a. Chaîne : o1 -> a (1) -> b (2) ; a + b -> c (3).
  local T1 = toy({ a = { "c", { { "o1", 2 } }, { { "a", 1 } } }, b = { "c", { { "a", 1 } }, { { "b", 1 } } },
    c = { "c", { { "a", 1 }, { "b", 1 } }, { { "c", 1 } } } })
  local R1 = Rg.build(T1, nil)
  check(R1.rank.o1 == 0 and R1.rank.a == 1 and R1.rank.b == 2 and R1.rank.c == 3,
    string.format("§1a chaîne : o1 0, a 1, b 2, c 3 (%s %s %s %s)", tostring(R1.rank.o1), tostring(R1.rank.a), tostring(R1.rank.b), tostring(R1.rank.c)))
  check(R1.rec.c == "c" and R1.level.c == 3 and R1.max == 3, "§1a recette du rang et niveau de c")
  check(table.concat(R1.tiers[0], ",") == "fl,o1", "§1a bruts : la ressource et le fluide pompé (" .. table.concat(R1.tiers[0], ",") .. ")")

  -- §1 b. Min sur les recettes : c aussi depuis a seul (c2) : rang 2 par c2 ; le niveau garde le plus long chemin (3).
  local T2 = toy({ a = { "c", { { "o1", 2 } }, { { "a", 1 } } }, b = { "c", { { "a", 1 } }, { { "b", 1 } } },
    c = { "c", { { "a", 1 }, { "b", 1 } }, { { "c", 1 } } }, c2 = { "c", { { "a", 3 } }, { { "c", 1 } } } })
  local R2 = Rg.build(T2, nil)
  check(R2.rank.c == 2 and R2.rec.c == "c2", "§1b rang = min sur les recettes (c " .. tostring(R2.rank.c) .. " par " .. tostring(R2.rec.c) .. ")")
  check(R2.level.c == 3, "§1b niveau = plus long chemin sur toutes les recettes (" .. tostring(R2.level.c) .. ")")
  -- Égalité : deux recettes de même rang, la recette au plus petit nom.
  local T2b = toy({ a = { "c", { { "o1", 2 } }, { { "a", 1 } } }, zz = { "c", { { "a", 1 } }, { { "e", 1 } } },
    aa = { "c", { { "a", 2 } }, { { "e", 1 } } } })
  check(Rg.build(T2b, nil).rec.e == "aa", "§1b égalité de rang : la recette au plus petit nom")

  -- §1 c. Cycle : x depuis o1 (x0), y depuis x (y1), x depuis y (x1) ; z depuis y. Un seul rang pour {x, y}.
  local T3 = toy({ x0 = { "c", { { "o1", 1 } }, { { "x", 1 } } }, y1 = { "c", { { "x", 1 } }, { { "y", 1 } } },
    x1 = { "c", { { "y", 1 } }, { { "x", 2 } } }, z1 = { "c", { { "y", 1 } }, { { "z", 1 } } } })
  local R3 = Rg.build(T3, nil)
  check(R3.rank.x == 2 and R3.rank.y == 2, string.format("§1c cycle contracté : x et y au même rang, le plus grand (%s, %s)", tostring(R3.rank.x), tostring(R3.rank.y)))
  check(R3.cyc.x == "x" and R3.cyc.y == "x" and #R3.cycles == 1 and R3.cycles[1].rank == 2 and not R3.cycles[1].seeded,
    "§1c cycle {x, y} d'identifiant x, sans amorce")
  check(R3.rank.z == 3 and R3.level.x == R3.level.y and R3.level.z == R3.level.x + 1, "§1c aval du cycle au-dessus (rang et niveau)")
  check(R3.rec.x == "x0" and R3.rec.y == "y1", "§1c recettes du rang : l'entrée du cycle")

  -- §1 d. Amorce : h ne se fait que depuis h (recette qui consomme son produit) ; g depuis h. Cycle u <-> v sans entrée.
  local T4 = toy({ h1 = { "c", { { "o1", 1 }, { "h", 2 } }, { { "h", 3 } } }, g1 = { "c", { { "h", 1 } }, { { "g", 1 } } },
    u1 = { "c", { { "v", 1 }, { "o1", 1 } }, { { "u", 1 } } }, v1 = { "c", { { "u", 2 } }, { { "v", 1 } } } })
  local R4 = Rg.build(T4, nil)
  check(R4.rank.h == 1 and R4.seed.h and R4.seed.h[1] and R4.seed.h[1][1] == "h" and R4.seed.h[1][2] == 2,
    "§1d recette qui consomme son produit : h au rang 1 par amorce de 2 h")
  check(R4.rank.g == 2, "§1d l'aval de l'amorce a un rang (g " .. tostring(R4.rank.g) .. ")")
  check(R4.rank.u == 1 and R4.rank.v == 1 and R4.seed.u and R4.seed.v, "§1d cycle sans entrée : u et v amorcés, un seul rang")
  local seeded = 0
  for _, c in ipairs(R4.cycles) do if c.seeded then seeded = seeded + 1 end end
  check(#R4.cycles == 2 and seeded == 2, "§1d deux cycles amorcés (h, u-v)")

  -- §1 e/f. Bruts et objets sans recette : w n'a aucune recette ; q depuis w ; avec opts.raw, w est brut.
  local T5 = toy({ q1 = { "c", { { "w", 1 } }, { { "q", 1 } } } })
  local R5 = Rg.build(T5, nil)
  check(R5.rank.w == nil and R5.rank.q == nil and R5.why.w == "aucune recette retenue" and R5.why.q == "ingredient sans rang : w",
    "§1f objet sans recette : sans rang, avec sa raison (" .. tostring(R5.why.w) .. " ; " .. tostring(R5.why.q) .. ")")
  local R5b = Rg.build(T5, nil, { raw = { w = true } })
  check(R5b.rank.w == 0 and R5b.rank.q == 1, "§1e opts.raw : brut au rang 0, son produit au rang 1")
  check(Rg.signature(T5, nil) ~= Rg.signature(T5, nil, { raw = { w = true } }), "§1e la signature suit les bruts donnés")

  -- §1 g. Vidage : remplir (fl + e -> fb), vider (fb -> fl + e) ; e depuis o1. Le vidage n'entre pas : aucun cycle.
  local T6 = toy({ e1 = { "c", { { "o1", 1 } }, { { "e", 1 } } }, fill = { "c", { { "fl", 50 }, { "e", 1 } }, { { "fb", 1 } } },
    vide = { "c", { { "fb", 1 } }, { { "fl", 50 }, { "e", 1 } } } })
  local R6 = Rg.build(T6, nil)
  check(#R6.cycles == 0 and R6.rank.e == 1 and R6.rank.fb == 2, "§1g recette de vidage hors du rang : aucun cycle, e 1, fb 2")

  -- §1 h. Recherche : c2 (c depuis a seul) ouverte par t1. Rang, signature, cache.
  local T7 = toy({ a = { "c", { { "o1", 2 } }, { { "a", 1 } } }, b = { "c", { { "a", 1 } }, { { "b", 1 } } },
    c = { "c", { { "a", 1 }, { "b", 1 } }, { { "c", 1 } } }, c2 = { "c", { { "a", 3 } }, { { "c", 1 } }, "t1" } })
  local o0, o1 = Rg.open_of(T7, {}), Rg.open_of(T7, { t1 = true })
  check(Rg.build(T7, o0).rank.c == 3 and Rg.build(T7, o1).rank.c == 2, "§1h la recherche de t1 fait descendre c de 3 à 2")
  check(Rg.signature(T7, o0) ~= Rg.signature(T7, o1), "§1h la signature change avec la recherche")
  local cache = {}
  local ra, b1 = Rg.get(cache, "f", T7, o0)
  local rb, b2 = Rg.get(cache, "f", T7, o0)
  local rc, b3 = Rg.get(cache, "f", T7, o1)
  local rd, b4 = Rg.get(cache, "f", T7, o1)
  local re, b5 = Rg.get(cache, "autre", T7, o1)
  check(b1 and not b2 and ra == rb, "§1h cache : calcul au premier appel, lecture au second (même résultat)")
  check(b3 and rc.rank.c == 2 and not b4 and rd == rc, "§1h cache refait après la recherche, puis relu")
  check(b5 and re ~= rc, "§1h cache par force : une autre force calcule le sien")
  local _, b6 = Rg.get(cache, "f", T7, o0)
  check(b6, "§1h cache refait au retour à l'ancien livre")
  -- Même livre, contenu changé (une quantité) : refait.
  local T7b = toy({ a = { "c", { { "o1", 2 } }, { { "a", 1 } } }, b = { "c", { { "a", 1 } }, { { "b", 1 } } },
    c = { "c", { { "a", 1 }, { "b", 2 } }, { { "c", 1 } } }, c2 = { "c", { { "a", 3 } }, { { "c", 1 } }, "t1" } })
  check(Rg.signature(T7b, Rg.open_of(T7b, {})) ~= Rg.signature(T7, o0), "§1h signature : une quantité d'ingrédient changée la change")

  -- §1 i. Catégorie sans fabrique ni main : la recette n'est pas retenue.
  local T8 = toy({ a = { "c", { { "o1", 2 } }, { { "a", 1 } } }, s1 = { "zz", { { "a", 1 } }, { { "s", 1 } } } })
  local R8 = Rg.build(T8, nil)
  check(R8.rank.s == nil and R8.rank.a == 1 and #R8.recipes == 1, "§1i catégorie sans fabrique : recette non retenue")

  -- §2 Livre réel, tout ouvert.
  local Rall = Rg.build(D, Rg.open_of(D, ALL))
  local nv, v, first = invariants(Rg, D, Rall)
  check(nv == 0, string.format("§2 invariants du livre réel : %d violation(s) (i1 %d, niveau %d, bruts %d, zéro %d, tri %d, partition %d) %s",
    nv, v.i1, v.lvl, v.raw, v.zero, v.sorted, v.part, table.concat({ first.i1 or "", first.lvl or "", first.raw or "", first.sorted or "", first.part or "" }, " | ")))
  local EXPECT = { ["iron-plate"] = 1, ["copper-plate"] = 1, ["stone-brick"] = 1, ["steel-plate"] = 2,
    ["iron-gear-wheel"] = 2, ["copper-cable"] = 2, ["electronic-circuit"] = 3, ["transport-belt"] = 3,
    ["automation-science-pack"] = 3, ["inserter"] = 4, ["advanced-circuit"] = 4, ["logistic-science-pack"] = 5,
    ["chemical-science-pack"] = 5, ["petroleum-gas"] = 1, ["sulfur"] = 2, ["engine-unit"] = 3, ["iron-ore"] = 0, ["coal"] = 0 }
  local wrong = {}
  for _, k in ipairs(sorted_keys(EXPECT)) do
    if Rall.rank[k] ~= EXPECT[k] then wrong[#wrong + 1] = k .. " " .. tostring(Rall.rank[k]) .. " (attendu " .. EXPECT[k] .. ")" end
  end
  check(#wrong == 0, "§2 rangs vanilla attendus : " .. table.concat(wrong, ", "))
  -- Les 3 erreurs de la table écrite à la main (docs/VIDEO_AUTOMATISATION.md §3.2) : notre calcul les évite.
  check(Rall.rank["logistic-science-pack"] == Rall.rank["inserter"] + 1 and Rall.rank["logistic-science-pack"] ~= 4,
    "§2 erreur 1 de l'auteur : le pack logistique est AU-DESSUS du bras, son ingrédient (5, pas 4 comme le bras)")
  check(Rall.rank["stone-furnace"] == 1 and Rall.rank["stone-furnace"] == Rall.rank["stone"] + 1,
    "§2 erreur 2 de l'auteur : le four en pierre est au rang 1 (la pierre est brute), pas 2 (" .. tostring(Rall.rank["stone-furnace"]) .. ")")
  check(Rall.rank["plastic-bar"] == 1 + math.max(Rall.rank["coal"], Rall.rank["petroleum-gas"]) and Rall.rank["plastic-bar"] == 2,
    "§2 erreur 3 de l'auteur : le plastique vient du charbon et du gaz (rang 2), pas 5 (" .. tostring(Rall.rank["plastic-bar"]) .. ")")
  -- Cycles réels : la recette qui consomme son produit (une boucle) et l'uranium à deux membres ; aucun cycle géant.
  local big = 0
  for _, c in ipairs(Rall.cycles) do if #c.members > big then big = #c.members end end
  check(#Rall.cycles == 2 and big == 2, string.format("§2 cycles du livre réel : 2, le plus grand de 2 membres (%d, %d)", #Rall.cycles, big))
  -- Même prédicat que la capitalisation.
  local up_r, up_c = Rg.unpackers(D), Ca.unpackers(D)
  local same_up = #sorted_keys(up_r) == #sorted_keys(up_c) and #sorted_keys(up_c) > 0
  for k in pairs(up_c) do if not up_r[k] then same_up = false end end
  check(same_up, "§2 Rg.unpackers = Ca.unpackers sur le livre réel (" .. #sorted_keys(up_c) .. " recettes de vidage)")
  local diff_open = 0
  local half = {}
  for i, t in ipairs(sorted_keys(ALL)) do if i % 2 == 0 then half[t] = true end end
  for _, techs in ipairs({ {}, half, ALL }) do
    local op = Rg.open_of(D, techs)
    for _, rn in ipairs(D.recipe_list) do
      if op(rn) ~= Ca.recipe_open({ D = D, techs = techs }, rn) then diff_open = diff_open + 1 end
    end
  end
  check(diff_open == 0, "§2 Rg.open_of = Ca.recipe_open (départ, moitié, tout) : " .. diff_open .. " écart(s)")
  -- Signature : chaque recette retenue compte (l'ôter du livre ouvert change la signature).
  local sig_all = Rg.signature(D, nil)
  local blind = {}
  for _, rn in ipairs(Rall.recipes) do
    if Rg.signature(D, function(x) return x ~= rn end) == sig_all then blind[#blind + 1] = rn end
  end
  check(#blind == 0, "§2 signature : " .. #blind .. " recette(s) retenue(s) ignorée(s) " .. table.concat(blind, " ", 1, math.min(#blind, 5)))
  -- Ouverture technologie par technologie (ordre des noms) : le cache n'est refait que quand une recette retenue s'ouvre ;
  -- un rang ne monte qu'à un pas où les cycles changent.
  local cand = {}
  for _, rn in ipairs(Rg.build(D, nil).recipes) do cand[rn] = true end
  local cache2, done, prev = {}, {}, nil
  local rebuilds, bad_rb, rises, bad_rise = 0, 0, 0, 0
  local function cyc_sig(R)
    local t = {}
    for _, c in ipairs(R.cycles) do t[#t + 1] = c.id .. ":" .. table.concat(c.members, ",") end
    return table.concat(t, ";")
  end
  for _, t in ipairs(sorted_keys(ALL)) do
    done[t] = true
    local opens = false
    for _, rn in ipairs(DUMP.techs[t].unlocks or {}) do if cand[rn] and D.unlocked_by[rn] == t then opens = true end end
    local R, rb = Rg.get(cache2, "f", D, Rg.open_of(D, done))
    if rb then rebuilds = rebuilds + 1 end
    if prev and rb ~= opens then bad_rb = bad_rb + 1 end
    if prev then
      local up = false
      for _, i in ipairs(sorted_keys(prev.rank)) do
        if R.rank[i] ~= nil and R.rank[i] > prev.rank[i] then up = true end
      end
      if up then
        rises = rises + 1
        if cyc_sig(R) == cyc_sig(prev) then bad_rise = bad_rise + 1 end
      end
    end
    prev = R
  end
  check(bad_rb == 0, string.format("§2 cache refait exactement aux recherches qui ouvrent une recette retenue (%d recalculs, %d écart(s))", rebuilds, bad_rb))
  check(bad_rise == 0, string.format("§2 aucun rang ne monte sans cycle nouveau (%d pas avec une hausse, %d sans cycle nouveau)", rises, bad_rise))
  check(ser(prev) == ser(Rall), "§2 toutes les recherches faites une à une : même résultat que le livre entier ouvert")
  say(string.format("§2 livre réel (fixture recipes_ia1e) : %s", Rg.text(Rall, "tout ouvert")))
  say(string.format("§2 au départ : %s", Rg.text(Rg.build(D, Rg.open_of(D, {})), "depart")))
  say(string.format("§2 ouverture par technologie : %d technologies, %d recalculs, %d pas avec une hausse de rang", #sorted_keys(ALL), rebuilds, rises))

  -- §3 Déterminisme.
  local Drev = Ca.data(real_dump(), {})
  local Dr2 = Ca.data((function() local d = F.dump({ reverse = true })
    for _, t in ipairs(sorted_keys(d.techs)) do for _, r in ipairs(d.techs[t].unlocks or {}) do if d.recipes[r] then d.recipes[r].enabled = false end end end
    return d end)(), {})
  local ref = ser(Rall)
  check(ser(Rg.build(Drev, Rg.open_of(Drev, ALL))) == ref, "§3 relevé refait : même résultat")
  check(ser(Rg.build(Dr2, Rg.open_of(Dr2, ALL))) == ref, "§3 relevé aux listes inversées : même résultat")
  for _, s in ipairs({ 1, 7, 20261107 }) do
    local Ds = shuffled(D, s)
    check(ser(Rg.build(Ds, Rg.open_of(Ds, ALL))) == ref, "§3 relevé permuté (graine " .. s .. ") : même résultat")
    check(Rg.signature(Ds, Rg.open_of(Ds, ALL)) == Rg.signature(D, Rg.open_of(D, ALL)), "§3 relevé permuté (graine " .. s .. ") : même signature")
  end
  local Ds3 = shuffled(DA, 3)
  check(ser(Rg.build(Ds3, nil)) == ser(Rg.build(DA, nil)), "§3 livre complété permuté : même résultat")

  -- §4 Livre complété (supposé) : rien sans rang, cycles du mod.
  local RA = Rg.build(DA, nil)
  local na, va, fa = invariants(Rg, DA, RA)
  check(na == 0, string.format("§4 invariants du livre complété : %d violation(s) %s", na, table.concat({ fa.i1 or "", fa.lvl or "", fa.part or "" }, " | ")))
  check(#RA.none == 0, "§4 livre complété : aucun objet sans rang (" .. table.concat(RA.none, " ", 1, math.min(#RA.none, 8)) .. ")")
  local kroll = nil
  for _, c in ipairs(RA.cycles) do if #c.members >= 4 then kroll = c end end
  local one = kroll ~= nil
  if kroll then for _, m in ipairs(kroll.members) do if RA.rank[m] ~= kroll.rank then one = false end end end
  check(one, "§4 cycle du titane (4 membres) : un seul rang pour tous ses membres")
  say(string.format("§4 livre complété (%d fabrique(s) et %d ressource(s) fictives) : %s", A_CATS, A_RES, Rg.text(RA, "complet")))

  -- §9 Rang de la DÉCISION (Rg.chain, docs/TODO_VIDEO.md §H) : recette choisie, fermeture des graines.
  -- a. Données jouets ; pick = la première recette ouverte au plus petit nom.
  local function first_pick(Dx, open)
    return function(i)
      for _, rn in ipairs(Dx.producers[i] or {}) do
        if open == nil or open(rn) then return Dx.recipes[rn], nil end
      end
      return nil, "aucune recette"
    end
  end
  local T9 = toy({ a = { "c", { { "o1", 2 } }, { { "a", 1 } } }, b = { "c", { { "a", 1 } }, { { "b", 1 } } },
    c = { "c", { { "a", 1 }, { "b", 1 } }, { { "c", 1 } } }, f1 = { "c", { { "fl", 5 }, { "a", 1 } }, { { "f", 1 } } },
    g1 = { "c", { { "f", 1 }, { "w", 1 } }, { { "g", 1 } } },
    h1 = { "c", { { "o1", 1 }, { "h", 2 } }, { { "h", 3 } } }, k1 = { "c", { { "h", 1 } }, { { "k", 1 } } },
    x1 = { "c", { { "y", 1 } }, { { "x", 1 } } }, y1 = { "c", { { "x", 1 }, { "o1", 1 } }, { { "y", 2 } } } })
  local C9 = Rg.chain(T9, first_pick(T9), { "c", "g", "k", "x" })
  check(C9.rank.o1 == 0 and C9.rank.a == 1 and C9.rank.b == 2 and C9.rank.c == 3, "§9a chaîne sur la recette choisie : a 1, b 2, c 3")
  check(C9.rank.f == 0 and C9.why.f == "limite : fluide (f1)" and C9.rank.w == 0 and C9.why.w == "aucune recette" and C9.rank.g == 1,
    "§9a feuilles au rang 0 comme depth : recette à fluide et objet sans recette, avec leur raison")
  check(C9.rank.h == 1 and C9.cyc.h == "h" and C9.seed.h and C9.seed.h[1] and C9.seed.h[1][1] == "h" and C9.seed.h[1][2] == 2 and C9.rank.k == 2,
    "§9a boucle sur lui-même : un rang (1 + ingrédients externes), amorce de 2, l'aval au-dessus")
  check(C9.rank.x == 1 and C9.rank.y == 1 and C9.cyc.x == "x" and C9.cyc.y == "x" and C9.seed.x and C9.seed.x[1] and C9.seed.x[1][1] == "y" and C9.seed.y and C9.seed.y[1] and C9.seed.y[1][1] == "x",
    "§9a cycle à deux objets : un seul rang, chacun amorcé par l'autre")
  local ok_ord = true
  for j = 2, #C9.order do
    local a, b = C9.order[j - 1], C9.order[j]
    if not (C9.rank[a] > C9.rank[b] or (C9.rank[a] == C9.rank[b] and a < b)) then ok_ord = false end
  end
  for j = 2, #C9.list do
    local a, b = C9.list[j - 1], C9.list[j]
    if not (C9.rank[a] < C9.rank[b] or (C9.rank[a] == C9.rank[b] and a < b)) then ok_ord = false end
  end
  check(ok_ord and #C9.order == C9.n_items, "§9a ordre de propagation (rang décroissant, nom) et liste (rang croissant, nom)")
  -- I6 : une recherche entre deux décisions change la recette choisie, donc le rang.
  local T9b = toy({ a = { "c", { { "o1", 2 } }, { { "a", 1 } } }, b = { "c", { { "a", 1 } }, { { "b", 1 } } },
    c2 = { "c", { { "a", 1 }, { "b", 1 } }, { { "c", 1 } } }, c1 = { "c", { { "a", 3 } }, { { "c", 1 } }, "t1" } })
  local before = Rg.chain(T9b, first_pick(T9b, Rg.open_of(T9b, {})), { "c" }).rank.c
  local after = Rg.chain(T9b, first_pick(T9b, Rg.open_of(T9b, { t1 = true })), { "c" }).rank.c
  check(before == 3 and after == 2, "§9a I6 : la recherche ouvre une recette choisie de plus bas rang (c de 3 à 2)")
  -- b. I5 : sur des décisions RÉELLES de la capitalisation, même fermeture, même rang que depth hors de l'influence d'un cycle,
  --    même recette, même raison, même liste ; I1 : ingrédient externe strictement plus bas.
  local n_cyc, n_free, bad_tot = 0, 0, {}
  for _, c in ipairs(CORPUS) do
    local req = c.req
    local R = Rg.chain(c.ctx.D, pick_of(c.ctx), sorted_keys(req.fin))
    local errs = {}
    local nd = 0
    for i, d in pairs(req.depth) do
      nd = nd + 1
      if R.rank[i] == nil then errs[#errs + 1] = "fermeture : " .. i end
    end
    if nd ~= R.n_items then errs[#errs + 1] = "fermeture " .. nd .. " contre " .. R.n_items end
    local aff = {}
    for _, i in ipairs(R.list) do
      if R.cyc[i] then aff[i] = true end
      for _, ing in ipairs((R.rec[i] or {}).ingredients or {}) do
        if aff[ing.name] then aff[i] = true end
        if R.cyc[ing.name] == nil or R.cyc[ing.name] ~= R.cyc[i] then
          if not (R.rank[ing.name] < R.rank[i]) then errs[#errs + 1] = "I1 " .. i .. " <- " .. ing.name end
        end
      end
    end
    for _, i in ipairs(R.list) do
      if not aff[i] and R.rank[i] ~= req.depth[i] then errs[#errs + 1] = string.format("rang %s %s, depth %s", i, R.rank[i], tostring(req.depth[i])) end
      if ((R.rec[i] or {}).name) ~= ((req.rec[i] or {}).name) then errs[#errs + 1] = "recette " .. i end
      if R.why[i] ~= req.why[i] then errs[#errs + 1] = "raison " .. i end
    end
    if #R.cycles == 0 then
      n_free = n_free + 1
      if table.concat(R.list, ",") ~= table.concat(req.list, ",") then errs[#errs + 1] = "liste differente de req.list" end
    else
      n_cyc = n_cyc + 1
      for _, cy in ipairs(R.cycles) do for _, m in ipairs(cy.members) do
        if R.rank[m] ~= cy.rank or not R.seed[m] or #R.seed[m] == 0 then errs[#errs + 1] = "cycle " .. cy.id .. " : " .. m end
      end end
    end
    if #errs > 0 then bad_tot[#bad_tot + 1] = c.label .. " : " .. table.concat(errs, " ; ", 1, math.min(#errs, 3)) end
  end
  check(#bad_tot == 0, string.format("§9b I5 et I1 sur %d appels réels de Ca.requirements : %s", #CORPUS, table.concat(bad_tot, " | ", 1, math.min(#bad_tot, 3))))
  check(n_cyc >= 1 and n_free >= 1, string.format("§9b le corpus a des fermetures avec cycle (%d) et sans cycle (%d)", n_cyc, n_free))
  say(string.format("§9b I5 : %d appels réels de Ca.requirements, %d sans cycle (rang = depth, même liste), %d avec cycle (égaux hors de l'aval du cycle)",
    #CORPUS, n_free, n_cyc))
  -- c. Déterminisme : relevé permuté (ingrédients compris), graines inversées : même résultat.
  local function ser_chain(R)
    local t = {}
    for _, k in ipairs(sorted_keys(R.rank)) do
      t[#t + 1] = string.format("%s=%d/%s/%s/%s", k, R.rank[k], tostring((R.rec[k] or {}).name), tostring(R.why[k]), tostring(R.cyc[k]))
    end
    t[#t + 1] = "O:" .. table.concat(R.order, ",")
    t[#t + 1] = "L:" .. table.concat(R.list, ",")
    for _, k in ipairs(sorted_keys(R.seed)) do
      local s = {}
      for _, x in ipairs(R.seed[k]) do s[#s + 1] = x[1] .. "x" .. x[2] end
      t[#t + 1] = "S" .. k .. ":" .. table.concat(s, ",")
    end
    for _, c in ipairs(R.cycles) do t[#t + 1] = "C" .. c.id .. ":" .. table.concat(c.members, ",") .. ":" .. c.rank end
    return table.concat(t, "\n")
  end
  -- Chemin rapide (un parcours) et chemin complet (Tarjan) : même résultat sur toute fermeture.
  local same_path = 0
  for _, c in ipairs(CORPUS) do
    local seeds = sorted_keys(c.req.fin)
    if ser_chain(Rg.chain(c.ctx.D, pick_of(c.ctx), seeds)) == ser_chain(Rg.chain(c.ctx.D, pick_of(c.ctx), seeds, true)) then same_path = same_path + 1 end
  end
  check(same_path == #CORPUS, string.format("§9c chemin rapide = chemin complet (%d sur %d)", same_path, #CORPUS))
  local same_det = 0
  for _, c in ipairs(CORPUS) do
    local seeds = sorted_keys(c.req.fin)
    local rev = {}
    for j = #seeds, 1, -1 do rev[#rev + 1] = seeds[j] end
    local D2 = shuffled(c.ctx.D, 11)
    if ser_chain(Rg.chain(c.ctx.D, pick_of(c.ctx), seeds)) == ser_chain(Rg.chain(D2, pick_of(c.ctx, D2), rev)) then same_det = same_det + 1 end
  end
  check(same_det == #CORPUS, string.format("§9c relevé permuté et graines inversées : même résultat (%d sur %d)", same_det, #CORPUS))
  -- d. Borne (I8) : chaîne synthétique de N objets, coût linéaire (sans récursion).
  local function long_chain(n, full)
    local Dl = { res = { o = true }, recipes = {} }
    local recs = {}
    for k = 1, n do
      recs["x" .. k] = { name = "x" .. k, fluid = false, ingredients = { { name = k == 1 and "o" or ("x" .. (k - 1)), amount = 1 } } }
    end
    local cnt = 0
    debug.sethook(function() cnt = cnt + 1 end, "", 1)
    local R = Rg.chain(Dl, function(i) return recs[i] end, { "x" .. n }, full)
    debug.sethook()
    return cnt, R.rank["x" .. n]
  end
  for _, full in ipairs({ false, true }) do
    local c1, r1 = long_chain(3000, full)
    local c2, r2 = long_chain(6000, full)
    check(r1 == 3000 and r2 == 6000 and c2 <= 2.4 * c1, string.format("§9d chaîne de 3 000 et 6 000 objets (chemin %s) : rangs justes, coût %d puis %d (rapport %.2f, borne 2,4)",
      full and "complet" or "rapide", c1, c2, c2 / c1))
  end

  return pass - p0, fail - f0
end

---------------------------------------------------------------------------------------------------
-- Passage principal
---------------------------------------------------------------------------------------------------
local _, BASE_FAILS = battery(Rg0)

-- §5 Comparaison au `depth` de Ca.requirements, sur tous les objets du livre ouvert : livre de la fixture, puis livre complété
-- (où plus rien n'est sans rang faute de ressource ou de machine dans la fixture).
local function compare(D, label)
  local Rg = Rg0
  local techs = ALL
  local R = Rg.build(D, Rg.open_of(D, techs))
  local retained = {}
  for _, rn in ipairs(R.recipes) do retained[rn] = true end
  local need = {}
  for _, rn in ipairs(D.recipe_list) do
    if Ca.recipe_open({ D = D, techs = techs }, rn) then
      for _, p in ipairs(D.recipes[rn].products) do if not D.res[p.name] then need[p.name] = 1 end end
    end
  end
  local cats = {}
  for c in pairs(D.hand) do cats[c] = true end
  local ctx = { D = D, input = { need = need }, sinks = {}, open = {}, pack_rates = {}, stock = {}, rec_memo = {},
    cats_present = cats, techs = techs, best_m = {}, best_d = {}, obt = {}, fuel_mu = 0 }
  local req = Ca.requirements(ctx, { burn = 0 })
  local counts, lines, same, unexplained = {}, {}, 0, 0
  -- Raison d'un écart : (classe, détail). Ordre : la cause propre à l'objet d'abord, l'héritage d'un ingrédient ensuite.
  local function reason_of(i)
    local rr = req.rec[i]
    if R.rank[i] == nil then return "A sans rang au livre", tostring(R.why[i]) end
    if req.why[i] and req.why[i]:find("^limite : fluide") then return "B fluide coupe par depth (0)", req.why[i] end
    if req.why[i] then return "C depth sans recette ouverte (0)", req.why[i] end
    if rr and not retained[rr.name] then return "D recette de depth non retenue par le rang", rr.name end
    if R.cyc[i] then return "E cycle (rang contracte)", R.cyc[i] end
    if rr and rr.name ~= R.rec[i] then return "F recette differente", "depth " .. rr.name .. ", rang " .. tostring(R.rec[i]) end
    for _, ing in ipairs((rr and rr.ingredients) or {}) do
      if (req.depth[ing.name] or 0) ~= (R.rank[ing.name] or -1) then return "G herite d'un ingredient", ing.name end
    end
    return nil, nil
  end
  for _, i in ipairs(sorted_keys(req.depth)) do
    if not D.res[i] and not D.pumped[i] then
      if req.depth[i] == R.rank[i] then same = same + 1 else
        local cls, det = reason_of(i)
        if not cls then unexplained, cls, det = unexplained + 1, "INEXPLIQUE", "" end
        counts[cls] = (counts[cls] or 0) + 1
        lines[#lines + 1] = string.format("%s depth %d rang %s : %s (%s)", i, req.depth[i], tostring(R.rank[i]), cls:sub(3), det)
      end
    end
  end
  -- Ordre de propagation : une recette CHOISIE par depth dont un ingrédient n'est pas plus bas que le produit (hors cycle).
  local bad_rank, bad_level, bad_ex = 0, 0, {}
  for _, i in ipairs(sorted_keys(req.rec)) do
    local rr = req.rec[i]
    if not rr.fluid and R.rank[i] then
      for _, ing in ipairs(rr.ingredients) do
        local same_c = R.cyc[i] ~= nil and R.cyc[i] == R.cyc[ing.name]
        if not same_c and (R.rank[ing.name] or math.huge) >= R.rank[i] then
          bad_rank = bad_rank + 1
          bad_ex[#bad_ex + 1] = string.format("%s (rang %d, recette de depth %s, recette du rang %s) <- %s (rang %s)", i, R.rank[i],
            rr.name, tostring(R.rec[i]), ing.name, tostring(R.rank[ing.name]))
        end
        if not same_c and (R.level[ing.name] or math.huge) >= (R.level[i] or -1) then bad_level = bad_level + 1 end
      end
    end
  end
  local cl = {}
  for _, k in ipairs(sorted_keys(counts)) do cl[#cl + 1] = k:sub(3) .. " " .. counts[k] end
  print(string.format("[RANG] §5 %s : depth contre rang : %d objets, %d égaux, %d écarts (%s)", label, same + #lines, same, #lines, table.concat(cl, ", ")))
  print(string.format("[RANG] §5 %s : ordre de propagation sur les recettes choisies par depth : %d arête(s) non croissantes en RANG, %d en NIVEAU", label, bad_rank, bad_level))
  for _, l in ipairs(bad_ex) do print("[RANG] §5 " .. label .. " : arete non croissante en rang : " .. l) end
  if ECARTS then for _, l in ipairs(lines) do print("[RANG] §5 " .. label .. " : ecart : " .. l) end
  else for j = 1, math.min(6, #lines) do print("[RANG] §5 " .. label .. " : ecart : " .. lines[j]) end end
  check(unexplained == 0, "§5 " .. label .. " : chaque écart a sa raison (" .. unexplained .. " inexpliqué(s))")
  check(bad_level == 0, "§5 " .. label .. " : le NIVEAU ordonne toute recette choisie par depth (ordre sûr pour L1b)")
end
compare(D, "fixture")
compare(DA, "complet")

-- §6 Coût en instructions (debug.sethook, une instruction par appel du crochet : compte exact, indépendant du PC).
local COST = {}
do
  local Rg = Rg0
  local function instr(f)
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    f()
    debug.sethook()
    return c
  end
  local open_all, open_start = Rg.open_of(D, ALL), Rg.open_of(D, {})
  local Dfresh = Ca.data(real_dump(), {})
  COST.book = instr(function() Rg.signature(Dfresh, open_all) end)            -- premier appel : livre préparé
  COST.build_all = instr(function() Rg.build(D, open_all) end)
  COST.build_start = instr(function() Rg.build(D, open_start) end)
  COST.build_aug = instr(function() Rg.build(DA, nil) end)
  local cache = {}
  Rg.get(cache, "f", D, open_all)
  COST.hit = instr(function() Rg.get(cache, "f", D, open_all) end)
  COST.miss = instr(function() Rg.get(cache, "f", D, open_start) end)
  COST.hit_table = instr(function() Rg.get(cache, "g", D, nil) end)
  local tabl = {}
  for _, rn in ipairs(D.recipe_list) do tabl[rn] = true end
  Rg.get(cache, "t", D, tabl)
  COST.hit_tab = instr(function() Rg.get(cache, "t", D, tabl) end)
  print(string.format("[RANG] §6 instructions : livre préparé (1re fois par relevé) %d ; calcul complet : tout ouvert %d, départ %d, livre complété %d ; cache : lecture %d (prédicat fonction), %d (table), recalcul %d",
    COST.book, COST.build_all, COST.build_start, COST.build_aug, COST.hit, COST.hit_tab, COST.miss))
  -- Gardes : le double du mesuré le 7/11 (112 056 et 8 854 : un calcul qui double de complexité échoue).
  check(COST.build_all <= 225000, "§6 calcul complet sous 225 000 instructions (" .. COST.build_all .. ")")
  check(COST.hit <= 18000, "§6 lecture du cache sous 18 000 instructions (" .. COST.hit .. ")")

  -- Rang de la DÉCISION (Rg.chain) contre Ca.requirements, sur les mêmes appels réels (mémo de choose_recipe chaud, comme aux
  -- appels 2 à N d'une décision). Par scène : appels, plus grande fermeture, médiane et maximum.
  local groups, gorder = {}, {}
  for _, c in ipairs(CORPUS) do
    local g = c.label:gsub(" #%d+$", "")
    if not groups[g] then groups[g] = { n = 0, items = 0, ch = {}, rq = {} } gorder[#gorder + 1] = g end
    local G = groups[g]
    local seeds = sorted_keys(c.req.fin)
    local pk = pick_of(c.ctx)
    local nd = 0
    for _ in pairs(c.req.depth) do nd = nd + 1 end
    G.n = G.n + 1
    if nd > G.items then G.items = nd end
    G.ch[#G.ch + 1] = instr(function() Rg.chain(c.ctx.D, pk, seeds) end)
    G.rq[#G.rq + 1] = instr(function() Ca.requirements(c.ctx, c.plan) end)
  end
  local function med(l)
    local s = {}
    for j, v in ipairs(l) do s[j] = v end
    table.sort(s)
    return s[math.floor((#s + 1) / 2)], s[#s]
  end
  COST.chain_max = 0
  for _, g in ipairs(gorder) do
    local G = groups[g]
    local cm, cx = med(G.ch)
    local rm, rx = med(G.rq)
    if cx > COST.chain_max then COST.chain_max = cx end
    print(string.format("[RANG] §6 rang de la décision, %s : %d appel(s), fermeture %d objets au plus ; Rg.chain médiane %d, max %d ; Ca.requirements médiane %d, max %d",
      g, G.n, G.items, cm, cx, rm, rx))
  end
  -- Garde : le double du pire mesuré le 7/11 (115 255, fermeture de TOUS les objets, avec le cycle de l'uranium).
  check(COST.chain_max <= 231000, "§6 rang de la décision sous 231 000 instructions, pire fermeture (" .. COST.chain_max .. ")")

  -- H-VID-3 : part de Ca.requirements dans une décision réelle de la capitalisation (scène riche de
  -- tests/ai3_capitalisation_test.lua §12, recopiée : relevé vanilla réaliste, recherche aux packs rouges, 4 gisements).
  local V_SPEED = { ["stone-furnace"] = 1, ["steel-furnace"] = 2, ["electric-furnace"] = 2, ["assembling-machine-1"] = 0.5,
    ["assembling-machine-2"] = 0.75, ["assembling-machine-3"] = 1.25, ["burner-mining-drill"] = 0.25,
    ["electric-mining-drill"] = 0.5, ["pumpjack"] = 1, ["lab"] = 1, ["chemical-plant"] = 1, ["oil-refinery"] = 1, ["centrifuge"] = 1 }
  local V_AREA = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 5, ["pumpjack"] = 1 }
  local V_SIZE = { ["burner-mining-drill"] = 2, ["electric-mining-drill"] = 3, ["stone-furnace"] = 2, ["steel-furnace"] = 2 }
  local V_KW = { ["stone-furnace"] = 90, ["steel-furnace"] = 90, ["electric-furnace"] = 180, ["burner-mining-drill"] = 150,
    ["electric-mining-drill"] = 90, ["assembling-machine-1"] = 75, ["assembling-machine-2"] = 150,
    ["assembling-machine-3"] = 375, ["lab"] = 60, ["boiler"] = 1800 }
  local d = real_dump()
  for _, e in ipairs(d.entities) do
    if V_SPEED[e.name] then e.speed = V_SPEED[e.name] end
    e.mining_area = V_AREA[e.name]
    e.size = V_SIZE[e.name] or 3
    e.energy_kw = V_KW[e.name]
  end
  for _, r in ipairs(d.resources) do r.mining_time = r.entity == "uranium-ore" and 2 or 1 end
  local EXEC = { ["stone-furnace"] = true, ["steel-furnace"] = true, ["burner-mining-drill"] = true,
    ["electric-mining-drill"] = true, ["assembling-machine-1"] = true, ["assembling-machine-2"] = true }
  local DV = Ca.data(d, { exec = EXEC, exec_roles = { main = true, labo = true } })
  local inp = { data = DV, state = { techs = { automation = true } }, stock = { ["electronic-circuit"] = 3000 }, flows = {},
    workers = 30, idle = 10, can_grow = true, traits = {}, weights = {}, open = {},
    deposits = { { id = "d1", resource = "iron-ore", tiles = 270, amount = 1e6, open = true, dist = 60 },
      { id = "s2", resource = "iron-ore", tiles = 270, amount = 1e6, dist = 150 },
      { id = "dc", resource = "copper-ore", tiles = 200, amount = 5e5, open = true, dist = 80, smelt = "copper-plate",
        smelter = "stone-furnace" },
      { id = "dk", resource = "coal", tiles = 200, amount = 5e5, open = true, dist = 50 } },
    drills = { { entity = "electric-mining-drill", resource = "iron-ore", n = 4, deposit = "d1" },
      { entity = "burner-mining-drill", resource = "copper-ore", n = 4, deposit = "dc" },
      { entity = "burner-mining-drill", resource = "coal", n = 2, deposit = "dk" } },
    machines = { { entity = "stone-furnace", recipe = "iron-plate", n = 6, where = "qg" },
      { entity = "stone-furnace", recipe = "iron-plate", n = 8, where = "d1" },
      { entity = "stone-furnace", recipe = "copper-plate", n = 4, where = "dc" } },
    labs = { { entity = "lab", n = 8 } },
    research = { queue = { { tech = "electronics", left = 27, time = 15, packs = { { "automation-science-pack", 1 } } },
      { tech = "fast-inserter", left = 2000, time = 15, packs = { { "automation-science-pack", 1 } } } }, rate = 450 },
    flows = { ["iron-ore"] = { made = 120 }, ["iron-plate"] = { made = 110 }, ["copper-plate"] = { made = 60 },
      ["coal"] = { made = 30 }, ["iron-gear-wheel"] = { made = 20, hand = 20 } },
    sinks = { { item = "firearm-magazine", rate = 20, elastic = true } } }
  local c = 0
  local orig = Ca.requirements
  local in_req, n_req = 0, 0
  Ca.requirements = function(cx, pl)
    local a = c
    local r = orig(cx, pl)
    in_req, n_req = in_req + (c - a), n_req + 1
    return r
  end
  debug.sethook(function() c = c + 1 end, "", 1)
  local res = Ca.decide(inp, {})
  debug.sethook()
  Ca.requirements = orig
  COST.decide, COST.req, COST.nreq = c, in_req, n_req
  print(string.format("[RANG] §6 H-VID-3 (scène riche) : Ca.decide %d instructions, %d ordres ; Ca.requirements appelé %d fois, %d instructions (%.1f %%, %d par appel)",
    c, #res.orders, n_req, in_req, 100 * in_req / math.max(1, c), math.floor(in_req / math.max(1, n_req))))
  check(n_req == #res.orders + 1, "§6 Ca.requirements : 1 + un appel par ordre décidé")
end

-- §6 bis (facultatif) : relevé frais de harness.lua --dump-recipes (livre de la version du worktree).
if LIVRE then
  local Rg = Rg0
  local DL = Ca.data(real_dump(LIVRE), {})
  local all = {}
  for _, t in ipairs(sorted_keys(DUMP.techs)) do all[t] = true end
  local R = Rg.build(DL, nil)
  local nv = invariants(Rg, DL, R)
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  Rg.build(DL, nil)
  debug.sethook()
  local DLA = Ca.data((augmented_dump(LIVRE)), {})
  local RA = Rg.build(DLA, nil)
  local c2 = 0
  debug.sethook(function() c2 = c2 + 1 end, "", 1)
  Rg.build(DLA, nil)
  debug.sethook()
  print(string.format("[RANG] §6 bis livre %s : %d recettes au relevé ; %s ; %d violation(s) ; %d instructions", LIVRE, #DL.recipe_list, Rg.text(R, "fixture+livre"), nv, c))
  print(string.format("[RANG] §6 bis livre complété : %s ; %d violation(s) ; %d instructions", Rg.text(RA, "complet"), (invariants(Rg, DLA, RA)), c2))
  local a = all_req(DLA, all)
  local pk = pick_of(a.ctx)
  local seeds = sorted_keys(a.req.fin)
  local c3 = 0
  debug.sethook(function() c3 = c3 + 1 end, "", 1)
  local RC = Rg.chain(DLA, pk, seeds)
  debug.sethook()
  local c4 = 0
  debug.sethook(function() c4 = c4 + 1 end, "", 1)
  Ca.requirements(a.ctx, a.plan)
  debug.sethook()
  print(string.format("[RANG] §6 bis livre complété, rang de la décision sur TOUS les objets : %d objets, %d cycle(s), Rg.chain %d instructions ; Ca.requirements %d",
    RC.n_items, #RC.cycles, c3, c4))
  check(nv == 0, "§6 bis invariants du livre frais")
end

-- §7 Aucun pairs qui décide sans tri : la règle n'a qu'un `pairs`, dans sorted_keys.
do
  local f = assert(io.open("shared/ai3/rang.lua", "rb"))
  local src = f:read("*a")
  f:close()
  local code = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local n = 0
  for _ in code:gmatch("[^i]pairs%(") do n = n + 1 end
  local in_sk = code:match("local function sorted_keys%(t%).-\nend") or ""
  local m = 0
  for _ in in_sk:gmatch("[^i]pairs%(") do m = m + 1 end
  check(n == 1 and m == 1, string.format("§7 un seul pairs dans la règle, dans sorted_keys (%d, dont %d)", n, m))
end

-- §8 Mutants : chacun remplace un extrait EXACT du source (une seule occurrence) ; la batterie §1-§4 doit échouer.
do
  local f = assert(io.open("shared/ai3/rang.lua", "rb"))
  local SRC = f:read("*a")
  f:close()
  local MUT = {
    { "ingrédient oublié (le dernier d'une recette)", "for j = 1, #ings do", "for j = 1, #ings - 1 do" },
    { "cycle non contracté", "if rank[m] then rank[m] = K end", "if rank[m] then rank[m] = rank[m] end" },
    { "tri des recettes retiré", "for _, rn in ipairs(sorted_copy(D.recipe_list)) do\n    local r = D.recipes[rn]\n    local made",
      "for _, rn in ipairs(D.recipe_list) do\n    local r = D.recipes[rn]\n    local made" },
    { "tri des objets retiré", "  table.sort(nodes)\n  local comps = components(nodes, succ)\n  local rank, rec, level",
      "  local comps = components(nodes, succ)\n  local rank, rec, level" },
    -- Rang de la décision (Rg.chain).
    { "chaîne (rapide) : max au lieu de 1 + max", "local k = fr[3] + 1", "local k = fr[3]" },
    { "chaîne (cycles) : max au lieu de 1 + max", "local k = leaf and 0 or top + 1", "local k = leaf and 0 or top" },
    { "chaîne (rapide) : cycle non détecté", "if s == 1 then return nil end", "if s == 1 then s = 2 rank[w] = rank[w] or 0 end" },
    { "chaîne : amorce du cycle oubliée", "if comp_of[ing.name] == ci then s[#s + 1]", "if false then s[#s + 1]" },
    { "chaîne : recette choisie contournée (pick ignoré)", "local r, w = pick(i)",
      "local r, w = D.producers and D.recipes[(D.producers[i] or {})[1] or \"\"], nil" },
    { "chaîne : ordre de propagation inversé", "if rank[a] ~= rank[b] then return rank[a] > rank[b] end",
      "if rank[a] ~= rank[b] then return rank[a] < rank[b] end" },
    { "chaîne : fluide non coupé", "elseif r.fluid then\n    why[i] =", "elseif false then\n    why[i] =" },
    { "cache jamais invalidé", "if e and e.content == bk.content and e.open == ok then", "if e then" },
    { "rang brut différent de 0", "rank[n], level[n] = 0, 0", "rank[n], level[n] = 1, 0" },
    { "signature qui ignore une recette (la dernière)", "for i, rn in ipairs(bk.cand) do\n    if is_open(open, rn) then idx",
      "for i, rn in ipairs(bk.cand) do\n    if i < #bk.cand and is_open(open, rn) then idx" },
    { "signature qui ignore les quantités", 'ins[#ins + 1] = i.name .. "=" .. i.amount', "ins[#ins + 1] = i.name" },
    { "rang = max au lieu de 1 + max", "return top + 1", "return top" },
    { "première recette au lieu du min", "if v and (best == nil or v < best) then best = v end", "if v and best == nil then best = v end" },
    { "recettes de vidage gardées", "if made and cats[r.category] and not skip[rn] then", "if made and cats[r.category] then" },
    { "faisabilité ignorée", "if made and cats[r.category] and not skip[rn] then", "if made and not skip[rn] then" },
    { "niveau sur la seule recette du rang", "for _, rn in ipairs(prod_of[m]) do\n        has = true",
      "for _, rn in ipairs({ rec[m] }) do\n        has = true" },
    { "amorce absente", "if any then", "if false then" },
  }
  local caught = 0
  -- Un mutant ne se juge que contre une batterie de base sans échec (sinon un échec de base passerait pour un refus).
  check(BASE_FAILS == 0, "§8 mutants jugés sur une batterie de base verte (" .. BASE_FAILS .. " échec(s) de base)")
  for _, mu in ipairs(BASE_FAILS == 0 and MUT or {}) do
    local name, from, to = mu[1], mu[2], mu[3]
    local s, e = SRC:find(from, 1, true)
    local again = s and SRC:find(from, e + 1, true)
    if not s or again then
      check(false, "§8 mutant mal formé (extrait absent ou en double) : " .. name)
    else
      local msrc = SRC:sub(1, s - 1) .. to .. SRC:sub(e + 1)
      local chunk = assert(load(msrc, "=rang-mutant"))
      local Rm = chunk()
      local p0, f0 = pass, fail
      quiet = true
      local ok, err = pcall(battery, Rm)
      debug.sethook()
      quiet = false
      local fails = fail - f0
      pass, fail = p0, f0
      local hit = (not ok) or fails > 0
      if hit then caught = caught + 1 end
      check(hit, "§8 mutant NON refusé : " .. name)
      print(string.format("[RANG] §8 mutant « %s » : %s", name, ok and (fails .. " contrôle(s) en échec") or ("plantage " .. tostring(err))))
    end
  end
  check(caught == #MUT, string.format("§8 mutants : %d refusés sur %d", caught, #MUT))
end

print(string.format("[RANG] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
