--[[
  IA3 (conception) : test hors jeu du PROTOTYPE de dépliage générique (shared/ai3/graphe.lua, NON BRANCHÉ).
  docs/IA3_CERVEAU.md §3 et §7. Données RÉELLES : recettes vanilla + mod (tests/fixtures/recipes_ia1e.lua),
  technologies vanilla (tests/fixtures/tech_ai3.lua, généré par tests/ai3_gen_tech.lua), catégories des machines
  (tests/fixtures/entities_ai3.lua).

  Ce qu'il prouve :
    1. GÉNÉRICITÉ : le code du module ne nomme aucun objet, bâtiment ou ressource du jeu ;
    2. recherche « automation » depuis le kit de départ : laboratoire, électricité (eau, vapeur, machine), packs à la
       main, dans un ordre exécutable, sans aucune règle par bâtiment ;
    3. H8 : pack chimique SANS pétrole connu : impayable, cause « crude-oil », exploration demandée, chaîne de
       recherche payable émise, AUCUNE fabrication ni construction de sa branche (le défaut C1 d'IA3-DIAG) ;
    4. pack chimique AVEC pétrole connu : chevalet, raffinerie, usine chimique, assembleur, électricité, recherches,
       tout déduit des données ; ordre exécutable ; « à la main » seulement pour les recettes que la main sait faire ;
    5. déterminisme : même résultat quel que soit l'ordre d'insertion des données ;
    6. mesure : coût RÉEL des technologies que les factions reçoivent aujourd'hui (T.unlocks) contre ce qu'elles paient
       (T.research) ; military-3 exige le pack chimique.

  Usage : lua5.2 tests/ai3_graphe_test.lua   (depuis la racine du mod)
]]

package.path = "./?.lua;" .. package.path
local G = require("shared.ai3.graphe")
local T = require("shared.team.config")

local pass, fail = 0, 0
local function check(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("[AI3-GRAPHE] ECHEC : " .. msg) end
end

local recipes = dofile("tests/fixtures/recipes_ia1e.lua")
local techs = dofile("tests/fixtures/tech_ai3.lua")
local ent = dofile("tests/fixtures/entities_ai3.lua")

local function spec_with(recs)
  return { recipes = recs, techs = techs, machines = ent.machines, resources = ent.resources,
    pseudo_recipes = ent.pseudo_recipes, hand_categories = ent.hand_categories, fuel = ent.fuel,
    electricity = ent.electricity }
end
local cat = G.new(spec_with(recipes))

local function start_state(known_extra)
  local stock = {}
  for _, it in ipairs(T.start_kit_generous) do stock[it[1]] = it[2] end
  local known = { ["iron-ore"] = true, ["copper-ore"] = true, coal = true, stone = true, water = true }
  for _, k in ipairs(known_extra or {}) do known[k] = true end
  return { stock = stock, techs = {}, built = { ["stone-furnace"] = T.start_smelters_generous }, known = known }
end

local function find(steps, kind, name)
  for i, s in ipairs(steps) do if s.kind == kind and s.name == name then return i, s end end
  return nil
end

local function count(steps, kind)
  local n = 0
  for _, s in ipairs(steps) do if s.kind == kind then n = n + 1 end end
  return n
end

--- Ordre exécutable : une recherche après ses prérequis planifiés ; une fabrication par machine après la
--- construction d'une machine de sa catégorie (ou une machine déjà là) ; une recherche après un laboratoire.
local function check_order(steps, state, label)
  local pos_research, pos_build = {}, {}
  for i, s in ipairs(steps) do
    if s.kind == "research" then pos_research[s.name] = i end
    if s.kind == "build" then pos_build[s.name] = pos_build[s.name] or i end
  end
  local bad = 0
  for i, s in ipairs(steps) do
    if s.kind == "research" then
      for _, pre in ipairs(techs[s.name].prerequisites) do
        if not state.techs[pre] and not (pos_research[pre] and pos_research[pre] < i) then bad = bad + 1 end
      end
      local lab = false
      for _, m in ipairs(cat.labs) do if (pos_build[m] and pos_build[m] < i) or (state.built[m] or 0) > 0 then lab = true end end
      if not lab then bad = bad + 1 end
    elseif s.kind == "produce" then
      local r = cat.recipes[s.name]
      local okm = false
      for _, m in ipairs(cat.by_category[r.category] or {}) do
        if (pos_build[m] and pos_build[m] < i) or (state.built[m] or 0) > 0 then okm = true end
      end
      if not okm then bad = bad + 1; print("  sans machine : " .. s.name) end
    elseif s.kind == "hand" then
      local r = cat.recipes[s.name]
      if not ent.hand_categories[r.category] then bad = bad + 1; print("  main impossible : " .. s.name) end
      for _, ing in ipairs(r.ingredients) do if ing.type == "fluid" then bad = bad + 1 end end
    end
  end
  check(bad == 0, label .. " : ordre exécutable (" .. bad .. " écart(s))")
end

-- 1. GÉNÉRICITÉ : aucun nom du jeu entre guillemets dans le code du module.
do
  local f = assert(io.open("shared/ai3/graphe.lua", "rb"))
  local src = f:read("*a")
  f:close()
  local names = {}
  for name, r in pairs(recipes) do
    names[name] = true
    for _, p in ipairs(r.products) do names[p.name] = true end
    for _, i in ipairs(r.ingredients) do names[i.name] = true end
  end
  for _, m in ipairs(ent.machines) do names[m.name] = true end
  for k in pairs(ent.resources) do names[k] = true end
  local hits = {}
  for name in pairs(names) do
    if src:find('"' .. name .. '"', 1, true) then hits[#hits + 1] = name end
  end
  table.sort(hits)
  check(#hits == 0, "généricité : noms du jeu dans le code : " .. table.concat(hits, ", "))
  local n = 0
  for _ in pairs(names) do n = n + 1 end
  print(string.format("[AI3-GRAPHE] généricité : %d noms du jeu cherchés dans shared/ai3/graphe.lua, %d trouvé(s)", n, #hits))
end

-- 2. Recherche « automation » depuis le kit de départ.
do
  local st = start_state()
  local plan = G.unfold(cat, { { tech = "automation" } }, st)
  check(plan.payable, "automation : payable")
  check(find(plan.steps, "research", "automation") ~= nil, "automation : étape de recherche")
  check(find(plan.steps, "build", "lab") ~= nil, "automation : laboratoire construit")
  check(find(plan.steps, "line", ent.electricity) ~= nil, "automation : électricité (ligne)")
  check(find(plan.steps, "build", "offshore-pump") ~= nil and find(plan.steps, "build", "boiler") ~= nil
    and find(plan.steps, "build", "steam-engine") ~= nil, "automation : eau, chaudière, machine à vapeur déduites")
  local _, h = find(plan.steps, "hand", "automation-science-pack")
  check(h ~= nil and h.n == 10, "automation : 10 packs rouges à la main")
  check(count(plan.steps, "explore") == 0, "automation : aucune exploration")
  check_order(plan.steps, st, "automation")
  local hand_s = 0
  for _, s in ipairs(plan.steps) do
    if s.kind == "hand" then hand_s = hand_s + cat.recipes[s.name].energy * s.n end
  end
  print(string.format("[AI3-GRAPHE] automation : %d étapes, %d noeuds, fabrication à la main %.0f PNJ-s (%.1f PNJ-min)",
    #plan.steps, plan.nodes, hand_s, hand_s / 60))
end

-- 3. Pack chimique SANS pétrole connu (H8).
local forbidden_qty = { "engine-unit", "advanced-circuit", "plastic-bar", "sulfur", "chemical-science-pack" }
do
  local st = start_state()
  local plan = G.unfold(cat, { { item = "chemical-science-pack", n = 10 } }, st)
  check(not plan.payable, "chimique sans pétrole : impayable")
  local cause = false
  for _, b in ipairs(plan.blocked) do
    for _, c in ipairs(b.causes) do if c == "crude-oil" then cause = true end end
  end
  check(cause, "chimique sans pétrole : cause crude-oil")
  local _, ex = find(plan.steps, "explore", "crude-oil")
  check(ex ~= nil and count(plan.steps, "explore") == 1, "chimique sans pétrole : une exploration du pétrole")
  for _, t in ipairs({ "oil-processing", "plastics", "sulfur-processing", "advanced-electronics", "chemical-science-pack" }) do
    check(find(plan.steps, "research", t) ~= nil, "chimique sans pétrole : recherche payable émise : " .. t)
  end
  local bad = {}
  for _, s in ipairs(plan.steps) do
    if s.kind == "hand" or s.kind == "produce" then
      for _, it in ipairs(forbidden_qty) do if s.item == it then bad[#bad + 1] = s.kind .. " " .. it end end
    end
    if s.kind == "build" and (s.name == "pumpjack" or s.name == "oil-refinery" or s.name == "chemical-plant") then
      bad[#bad + 1] = "build " .. s.name
    end
  end
  check(#bad == 0, "chimique sans pétrole : aucune fabrication ni construction de la branche bloquée : " .. table.concat(bad, ", "))
  check_order(plan.steps, st, "chimique sans pétrole")
  print(string.format("[AI3-GRAPHE] chimique sans pétrole : %d étapes, %d recherches, %d bloqué(s), explorations %d",
    #plan.steps, count(plan.steps, "research"), #plan.blocked, count(plan.steps, "explore")))
end

-- 4. Pack chimique AVEC pétrole connu.
local steps_known
do
  local st = start_state({ "crude-oil" })
  local plan = G.unfold(cat, { { item = "chemical-science-pack", n = 10 } }, st)
  steps_known = plan.steps
  check(plan.payable, "chimique avec pétrole : payable")
  for _, m in ipairs({ "pumpjack", "oil-refinery", "chemical-plant" }) do
    check(find(plan.steps, "build", m) ~= nil, "chimique avec pétrole : construit " .. m)
  end
  local _, pj = find(plan.steps, "build", "pumpjack")
  check(pj ~= nil and pj.item == "crude-oil", "chimique avec pétrole : chevalet sur le pétrole")
  local asm = false
  for _, s in ipairs(plan.steps) do
    if s.kind == "build" and s.name:find("assembling%-machine") then asm = true end
  end
  check(asm, "chimique avec pétrole : un assembleur (moteur : catégorie hors main)")
  local _, eng = find(plan.steps, "produce", "engine-unit")
  check(eng ~= nil, "chimique avec pétrole : moteurs produits en machine")
  check(count(plan.steps, "explore") == 0, "chimique avec pétrole : aucune exploration")
  check_order(plan.steps, st, "chimique avec pétrole")
  print(string.format("[AI3-GRAPHE] chimique avec pétrole : %d étapes, %d recherches, %d constructions, %d noeuds",
    #plan.steps, count(plan.steps, "research"), count(plan.steps, "build"), plan.nodes))
end

-- 5. Déterminisme : données insérées dans l'ordre inverse.
do
  local names = {}
  for k in pairs(recipes) do names[#names + 1] = k end
  table.sort(names, function(a, b) return a > b end)
  local rev = {}
  for _, k in ipairs(names) do rev[k] = recipes[k] end
  local cat2 = G.new(spec_with(rev))
  local plan2 = G.unfold(cat2, { { item = "chemical-science-pack", n = 10 } }, start_state({ "crude-oil" }))
  local function ser(steps)
    local out = {}
    for _, s in ipairs(steps) do out[#out + 1] = s.kind .. ":" .. s.name .. ":" .. tostring(s.n) .. ":" .. tostring(s.item) end
    return table.concat(out, "|")
  end
  check(ser(plan2.steps) == ser(steps_known), "déterminisme : mêmes étapes, ordre d'insertion inversé")
end

-- 6. Mesure : ce que les factions reçoivent (T.unlocks) contre ce qu'elles paient (T.research).
do
  local done = {}
  local paid_total, real_total = 0, 0
  for k = 0, 3 do
    local real = {}
    for _, tname in ipairs(T.unlocks[k] or {}) do
      local packs, seen = G.tech_packs(cat, tname, done)
      for p, n in pairs(packs) do real[p] = (real[p] or 0) + n end
      for t in pairs(seen) do done[t] = true end
    end
    local paid = 0
    for _, it in ipairs(T.research[k] or {}) do paid = paid + it[2] end
    local realn = 0
    for _, n in pairs(real) do realn = realn + n end
    paid_total, real_total = paid_total + paid, real_total + realn
    local keys = {}
    for p in pairs(real) do keys[#keys + 1] = p end
    table.sort(keys)
    local parts = {}
    for _, p in ipairs(keys) do parts[#parts + 1] = p .. " " .. real[p] end
    print(string.format("[AI3-GRAPHE] niveau %d des factions : payé %d packs, coût réel des technologies reçues %d packs (%s)",
      k, paid, realn, table.concat(parts, ", ")))
  end
  print(string.format("[AI3-GRAPHE] niveaux 0 à 3 : payé %d packs, coût réel %d packs (rapport %.1f)", paid_total, real_total,
    real_total / paid_total))
  local m3 = G.tech_packs(cat, "military-3")
  check((m3["chemical-science-pack"] or 0) > 0, "military-3 (reçue au niveau 3) exige le pack chimique")
  local plan = G.unfold(cat, { { tech = "military-3" } }, start_state())
  check(not plan.payable, "military-3 sans pétrole : impayable (les factions la reçoivent aujourd'hui sans pétrole)")
  local chem = G.tech_packs(cat, "chemical-science-pack")
  local keys = {}
  for p in pairs(chem) do keys[#keys + 1] = p end
  table.sort(keys)
  local parts = {}
  for _, p in ipairs(keys) do parts[#parts + 1] = p .. " " .. chem[p] end
  print("[AI3-GRAPHE] technologie chemical-science-pack depuis zéro (prérequis compris) : " .. table.concat(parts, ", "))
end

-- Lot IA3-0 (revue M13) : coûts FINAUX. Le mod réécrit le coût des technologies (tests/fixtures/tech_ai3_final.lua,
-- harness --dump-techs) : les chiffres VANILLA ci-dessus ne sont pas ceux du jeu.
do
  local tf = dofile("tests/fixtures/tech_ai3_final.lua")
  local function total(p) local n = 0 for _, v in pairs(p) do n = n + v end return n end
  local function labsec(tname)
    local _, seen = G.tech_packs({ techs = tf }, tname)
    local s = 0
    for t in pairs(seen) do if tf[t] then s = s + tf[t].count * tf[t].time end end
    return s
  end
  local rows = {}
  for k, t in ipairs({ "automation", "logistic-science-pack", "military-science-pack", "chemical-science-pack" }) do
    local p = G.tech_packs({ techs = tf }, t)
    rows[#rows + 1] = string.format("palier %d %d packs %d s", k, total(p), labsec(t))
  end
  print("[AI3-GRAPHE] coûts FINAUX des paliers (vanilla + mod) : " .. table.concat(rows, " ; "))
  local p3 = G.tech_packs({ techs = tf }, "military-science-pack")
  check(total(p3) < 100 and labsec("military-science-pack") < 600,
    "coûts finaux : le palier 3 coûte moins de 100 packs et 10 min de laboratoire (vanilla : 245 packs, 1 625 s)")
  local done, real = {}, 0
  for level = 0, 3 do
    for _, tn in ipairs(T.unlocks[level] or {}) do
      local p, seen = G.tech_packs({ techs = tf }, tn, done)
      real = real + total(p)
      for k in pairs(seen) do done[k] = true end
    end
  end
  print(string.format("[AI3-GRAPHE] niveaux 0 à 3, coûts FINAUX : payé 290 packs, coût réel %d (rapport %.1f)", real, real / 290))
  local m3 = tf["military-3"]
  local chem = false
  for _, i in ipairs(m3 and m3.ingredients or {}) do if i[1] == "chemical-science-pack" then chem = true end end
  check(real > 290 and real < 6415 and chem,
    "coûts finaux : les factions reçoivent plus qu'elles ne paient (" .. real .. " pour 290), mais pas 22 fois ; military-3 exige toujours le pack chimique")
end

-- Lot IA3-0 (revue M2) : clé d'invalidation des points fixes.
do
  local s0 = start_state()
  local k0 = G.state_key(cat, s0)
  local s1 = start_state()
  s1.stock["iron-gear-wheel"] = 12
  s1.stock["copper-cable"] = 40
  local s2 = start_state()
  s2.known["crude-oil"] = true
  local s3 = start_state()
  s3.stock["lab"] = 1
  check(G.state_key(cat, s1) == k0, "clé des points fixes : des intermédiaires au coffre ne la changent pas")
  check(G.state_key(cat, s2) ~= k0 and G.state_key(cat, s3) ~= k0,
    "clé des points fixes : une ressource découverte ou un bâtiment au stock la changent")
  local e0, e1 = G.prepare(cat, s0), G.prepare(cat, s1)
  local same = true
  for _, n in ipairs(cat.recipe_list) do
    for _, p in ipairs(cat.recipes[n].products) do
      if e0.feas[p.name] ~= e1.feas[p.name] then same = false end
    end
  end
  check(same, "même clé, même faisabilité (intermédiaires au coffre ou non)")
end

-- Lot CHAÎNE (anti-boucle) : les données d'un autre mode peuvent contenir un CYCLE de recettes. Le dépliage doit
-- s'arrêter de lui-même (marque « en cours », profondeur maximale, reprises bornées), jamais par MAX_NODES.
do
  local function R(category, energy, ings, prods)
    local function lst(l)
      local out = {}
      for _, e in ipairs(l) do out[#out + 1] = { type = "item", name = e[1], amount = e[2] or 1 } end
      return out
    end
    return { category = category, energy = energy, hidden = false, enabled = true, ingredients = lst(ings), products = lst(prods) }
  end
  local function mini(recs, machines)
    return G.new({
      recipes = recs, techs = {},
      machines = machines or { { name = "hand", hand = true, crafting_categories = { "c" }, resource_categories = { "r" }, energy = "none" },
        { name = "asm", crafting_categories = { "c" }, energy = "none" } },
      resources = { ore = { category = "r" }, gem = { category = "r" } }, hand_categories = { c = true },
    })
  end
  local function state(known, stock)
    return { stock = stock or {}, techs = {}, built = { asm = 1 }, known = known or { ore = true } }
  end
  local function unfold(c, goal, st) return G.unfold(c, { goal }, st or state()) end
  local function uses(res, kind, name)
    local n = 0
    for _, s in ipairs(res.steps) do if s.kind == kind and s.name == name then n = n + 1 end end
    return n
  end
  local function ser(r)
    local out = {}
    for _, s in ipairs(r.steps) do out[#out + 1] = s.kind .. ":" .. s.name .. ":" .. tostring(s.n) end
    return table.concat(out, "|")
  end

  -- a. Deux recettes d'énergie EXACTEMENT 0 (A depuis B, B depuis A) et une entrée par l'extérieur : le coût de choix ne
  -- départage plus, le nom de la recette qui boucle passe devant (avant le lot : 4 000 étapes, truncated).
  local c = mini({
    zA = R("c", 0, { { "ore" } }, { { "A" } }), aB = R("c", 0, { { "A" } }, { { "B" } }),
    aA2 = R("c", 0, { { "B" } }, { { "A" } }), rG = R("c", 1, { { "A" }, { "B" } }, { { "goal" } }),
  })
  local res = unfold(c, { item = "goal", n = 1 })
  check(not res.truncated and res.payable, "chaîne a : cycle A<->B d'énergie 0 : ni tronqué ni impayable")
  check(res.nodes < 20, "chaîne a : moins de 20 nœuds (" .. res.nodes .. ")")
  check(#res.steps < 20 and uses(res, "hand", "aA2") == 0 and uses(res, "hand", "zA") >= 1,
    "chaîne a : A vient de l'entrée (zA), jamais de la boucle (aA2) ; " .. #res.steps .. " étapes")
  check(res.retries == 1 and res.cycles[1] == "A:aA2", "chaîne a : la recette qui ouvrait le cycle est interdite (" .. table.concat(res.cycles, ",") .. ")")
  local c_rev = mini({
    rG = R("c", 1, { { "A" }, { "B" } }, { { "goal" } }), aA2 = R("c", 0, { { "B" } }, { { "A" } }),
    aB = R("c", 0, { { "A" } }, { { "B" } }), zA = R("c", 0, { { "ore" } }, { { "A" } }),
  })
  check(ser(unfold(c_rev, { item = "goal", n = 1 })) == ser(res), "chaîne a : déterminisme (données dans l'ordre inverse)")

  -- b. Rendement supérieur à 1 (B rend 2 pour 1 A, A rend 3 pour 1 B) : le coût de choix descend à chaque tour et préfère
  -- la boucle ; la marque « en cours » la refuse.
  local cg = mini({
    zA = R("c", 5, { { "ore" } }, { { "A" } }), gB = R("c", 0.1, { { "A" } }, { { "B", 2 } }),
    gA = R("c", 0.1, { { "B" } }, { { "A", 3 } }), rG = R("c", 1, { { "B" } }, { { "goal" } }),
  })
  local rg = unfold(cg, { item = "goal", n = 4 })
  check(not rg.truncated and rg.payable and rg.nodes < 30, "chaîne b : rendement supérieur à 1 : ni tronqué ni impayable (" .. rg.nodes .. " nœuds)")
  check(uses(rg, "hand", "gA") == 0, "chaîne b : la boucle qui crée de la matière n'est pas une source")

  -- c. Trois recettes circulaires A <- B <- C <- A (énergie 0), une seule entrée : le dépliage la trouve, pour chaque but.
  local c3 = mini({
    ab = R("c", 0, { { "B" } }, { { "A" } }), bc = R("c", 0, { { "C" } }, { { "B" } }),
    ca = R("c", 0, { { "A" } }, { { "C" } }), zC = R("c", 0, { { "ore" } }, { { "C" } }),
    rG = R("c", 1, { { "A" } }, { { "goal" } }),
  })
  local r3 = unfold(c3, { item = "goal", n = 1 })
  check(not r3.truncated and r3.payable and r3.nodes < 30, "chaîne c : trois recettes circulaires : ni tronqué ni impayable (" .. r3.nodes .. " nœuds)")
  check(uses(r3, "hand", "zC") >= 1 and uses(r3, "hand", "ca") == 0, "chaîne c : C vient de l'entrée, pas de la boucle")
  for _, g in ipairs({ "A", "B", "C" }) do
    local rr = unfold(c3, { item = g, n = 2 })
    check(not rr.truncated and rr.payable and rr.nodes < 30, "chaîne c : but " .. g .. " : fini et payable")
  end

  -- d. Cycle SANS entrée (A depuis B et B depuis A, rien d'autre) : impayable, sans boucle ni troncature.
  local cn = mini({ ab = R("c", 0, { { "B" } }, { { "A" } }), ba = R("c", 0, { { "A" } }, { { "B" } }) })
  local rn = unfold(cn, { item = "A", n = 1 })
  check(not rn.truncated and not rn.payable and rn.nodes < 20 and #rn.steps == 0, "chaîne d : cycle sans entrée : impayable, 0 étape (" .. rn.nodes .. " nœuds)")

  -- e. Objet FAISABLE (le stock durable l'amorce) dont toutes les recettes bouclent : bloqué, cause « cycle:<objet> »,
  -- jamais « ?<objet> », sans troncature.
  local ce = mini({ mb = R("c", 0, { { "N" } }, { { "M" } }), nb = R("c", 0, { { "M" } }, { { "N" } }) },
    { { name = "hand", hand = true, crafting_categories = { "c" }, resource_categories = { "r" }, energy = "none" },
      { name = "M", crafting_categories = { "z" }, energy = "none" } })
  local re = G.unfold(ce, { { item = "M", n = 3 } }, { stock = { M = 1 }, techs = {}, built = {}, known = { ore = true } })
  local cyc_cause = false
  for _, b in ipairs(re.blocked) do for _, k in ipairs(b.causes) do if k == "cycle:M" then cyc_cause = true end end end
  check(not re.truncated and not re.payable and cyc_cause, "chaîne e : objet faisable aux recettes toutes circulaires : bloqué, cause cycle:M")

  -- f. Ressource inconnue (aucun gisement connu) : exploration seule, aucune boucle, cause = la ressource, jamais
  -- « ?<main> ».
  local cu = mini({ rG = R("c", 1, { { "gem" } }, { { "goal" } }) })
  local ru = unfold(cu, { item = "goal", n = 1 })
  check(not ru.truncated and not ru.payable and uses(ru, "explore", "gem") == 1 and ru.nodes < 10, "chaîne f : gisement inconnu : une exploration, pas de boucle")
  local bad = {}
  for _, b in ipairs(ru.blocked) do for _, k in ipairs(b.causes) do
    if k:sub(1, 1) == "?" then bad[#bad + 1] = k end
  end end
  check(#bad == 0 and ru.blocked[1] and ru.blocked[1].causes[1] == "gem", "chaîne f : la cause est la ressource, rien de la forme ?machine : " .. table.concat(bad, ","))

  -- g. Profondeur maximale : une chaîne de 40 objets, une limite à 10, puis la limite d'origine.
  local chain = {}
  chain.i1 = R("c", 1, { { "ore" } }, { { "x1" } })
  for i = 2, 40 do chain["i" .. i] = R("c", 1, { { "x" .. (i - 1) } }, { { "x" .. i } }) end
  local cc = mini(chain)
  local d0 = G.MAX_DEPTH
  G.MAX_DEPTH = 10
  local rd = unfold(cc, { item = "x40", n = 1 })
  G.MAX_DEPTH = d0
  check(rd.truncated and rd.why == "profondeur" and not rd.payable and rd.nodes <= 12, "chaîne g : profondeur maximale : tronqué, raison « profondeur » (" .. rd.nodes .. " nœuds)")
  local rf = unfold(cc, { item = "x40", n = 1 })
  check(not rf.truncated and rf.payable, "chaîne g : 40 niveaux sous la limite d'origine : complet (" .. #rf.steps .. " étapes)")

  -- h. Reprises bornées : sans reprise permise, le cycle tronque avec la raison « cycles ».
  local n0 = G.MAX_RETRIES
  G.MAX_RETRIES = 0
  local rr0 = unfold(c, { item = "goal", n = 1 })
  G.MAX_RETRIES = n0
  check(rr0.truncated and rr0.why == "cycles" and rr0.nodes < 20, "chaîne h : sans reprise permise, le cycle tronque (raison « cycles »)")

  -- i. Une extraction qui brûle ce qu'elle extrait (foreuse à combustible sur le gisement de combustible) n'est PAS un
  -- cycle de recettes : le dépliage de l'automatisation du vrai jeu n'a aucune reprise.
  local ra = G.unfold(cat, { { tech = "automation" } }, start_state())
  check(ra.retries == 0 and #ra.cycles == 0 and ra.payable, "chaîne i : le jeu réel (automation) : aucun cycle, aucune reprise")

  -- l. Amorçage par une MACHINE (la foreuse qui mine la matière du four que la foreuse exige) : ce n'est pas un cycle de
  -- recettes (la machine est posée avant la descente, la main reste possible) ; X3 a six objets de ce genre. Aucune
  -- reprise, aucune interdiction.
  local cb = mini({ f = R("c", 1, { { "ore" } }, { { "F" } }), d = R("c", 1, { { "F" } }, { { "D" } }) },
    { { name = "hand", hand = true, crafting_categories = { "c" }, resource_categories = { "r" }, energy = "none" },
      { name = "D", crafting_categories = { "z" }, resource_categories = { "r" }, energy = "none" } })
  local rb = G.unfold(cb, { { item = "F", n = 2 } }, { stock = {}, techs = {}, built = {}, known = { ore = true } })
  check(rb.payable and not rb.truncated and rb.retries == 0 and #rb.cycles == 0 and rb.nodes < 30,
    "chaîne l : amorçage par une machine : payable, aucune reprise (" .. rb.nodes .. " nœuds, " .. rb.retries .. " reprise(s))")

  -- j. Tous les buts du jeu réel (chaque produit de chaque recette, chaque technologie, deux états) : aucun cycle,
  -- aucune troncature.
  local cyc, trunc, total = 0, 0, 0
  for _, all in ipairs({ false, true }) do
    local stt = start_state()
    if all then for _, k in ipairs(cat.resource_list) do stt.known[k] = true end end
    local ev = G.prepare(cat, stt)
    for _, rn in ipairs(cat.recipe_list) do
      for _, p in ipairs(cat.recipes[rn].products) do
        local r = G.unfold(cat, { { item = p.name, n = 3 } }, stt, ev)
        total = total + 1
        if #r.cycles > 0 then cyc = cyc + 1 end
        if r.truncated then trunc = trunc + 1 end
      end
    end
    for _, tn in ipairs(cat.tech_list) do
      local r = G.unfold(cat, { { tech = tn } }, stt, ev)
      total = total + 1
      if #r.cycles > 0 then cyc = cyc + 1 end
      if r.truncated then trunc = trunc + 1 end
    end
  end
  check(cyc == 0 and trunc == 0 and total > 500, string.format("chaîne j : %d buts du jeu réel : %d avec cycle, %d tronqué(s)", total, cyc, trunc))
  print(string.format("[AI3-GRAPHE] chaîne : %d buts du jeu réel, %d cycle(s), %d tronqué(s)", total, cyc, trunc))

  -- k. Données réelles, ressource inconnue extraite à la main (la catégorie de la main) : la cause est la ressource.
  local ruo = G.unfold(cat, { { item = "uranium-ore", n = 1 } }, start_state())
  local qs = false
  for _, b in ipairs(ruo.blocked) do for _, k in ipairs(b.causes) do if k:sub(1, 1) == "?" then qs = true end end end
  check(not ruo.payable and not qs and #ruo.blocked > 0, "chaîne k : uranium inconnu : la cause est le gisement, pas « ?character »")
end

print(string.format("[AI3-GRAPHE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
