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
  for _, it in ipairs(T.start_kit) do stock[it[1]] = it[2] end
  local known = { ["iron-ore"] = true, ["copper-ore"] = true, coal = true, stone = true, water = true }
  for _, k in ipairs(known_extra or {}) do known[k] = true end
  return { stock = stock, techs = {}, built = { ["stone-furnace"] = T.start_smelters }, known = known }
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

print(string.format("[AI3-GRAPHE] BILAN : %d OK, %d ECHEC(S)", pass, fail))
os.exit(fail == 0 and 0 or 1)
