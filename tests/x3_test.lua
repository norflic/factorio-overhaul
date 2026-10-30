--[[
  Lot X3 (27/10) : banc hors jeu du graphe réaliste et des minerais par âge (shared/content/x3.lua, PROPOSITION, pas en
  jeu). Usage, depuis la racine du mod ou d'un worktree : lua5.2 tests/x3_test.lua [--court]
    --court : sans les bancs rejoués (epochs, titanium, monde, org, levels), contrôles propres, cerveau et mutants
              (mutants jugés par les contrôles propres seulement).

  Version 2 (correction du 27/10, après deux critiques adverses). Ce qu'il prouve, sur la FUSION X0 + X3 (X3.merge sur
  une copie fraîche d'epochs.lua) :
   1. jeu inchangé : X seul ne contient aucun nom d'X3, aucun fichier du jeu ne lit x3.lua, AUCUNE recette d'X0 n'est
      modifiée (règle « des voies, jamais une porte » : toute voie qui touche un objet d'X0 est une variante), T.maker
      (première recette d'un objet) identique ; aucune technologie de pack ni de Codex ne prend un prérequis d'X3 ;
      epochs_test, titanium_test, monde_test, org_test et levels_test rejoués sur X seul ET sur la fusion ;
   2. fermeture du graphe : tout objet, bâtiment et recette disponible EXACTEMENT à son âge ; ingrédients connus ;
      limites moteur des recettes d'X3 (boîtes à fluide, four à une entrée, minage et catégorie de ressource, noms
      uniques, catégories des bâtiments servies, calcul sans baril et boîtes filtrées) ;
   3. aucun objet sans usage, et tout objet d'X3 consommé DÈS SON ÂGE (hors usages finals) ; tout sous-produit d'une
      recette d'X3 a deux exutoires ;
   4. aucune recette orpheline : chaque recette réelle débloquée par exactement une technologie de son âge ;
   5. technologies : prérequis déclarés, d'un âge antérieur ou égal, sans cycle ; un objet n'est jamais requis avant
      son déblocage ; pour les recettes d'X3, un objet d'un âge ANTÉRIEUR n'est obtenu que si une technologie qui le
      débloque est dans la fermeture des prérequis, ou dans le chemin obligatoire (packs, Codex et leurs prérequis) ;
      recalage des unités borné (âges d'X3 seulement, 0,7 à 1,3 × X0) ;
   6. placement des ressources : jeu de gisements propre (aucun « vanilla-like », graines numériques uniques, absentes
      de world.lua), aucun masque de biome partagé avec un gisement en place, garantie déclarée ; au plus 2 ressources
      par âge sur la fusion ;
   7. cerveau général (shared/ai3/graphe.lua), AVEC les technologies (prérequis, technologie du pack, packs × unités) :
      à chaque âge k, technologies des âges < k recherchées, ressources des âges ≤ k connues, rien de construit :
      chaque technologie de l'âge k dépliée sous 0,9 × G.MAX_NODES (sans régression sur X0), 4 technologies ensemble
      (lookahead du cerveau général) sans troncature nouvelle, cibles d'X3 payables à leur âge ; AUCUNE PORTE : avec
      les ressources d'X3 inconnues, tout ce qui est payable dans X0 l'est dans la fusion, sans exploration d'une
      ressource d'X3 ; la voie du cerveau (tout construit) donne des packs à 10 % au plus du chemin le moins cher ;
   8. valeurs : MU, énergie (MJ) et temps-machine des variantes face à la voie d'X0 (aucune variante moins chère en MU
      mais plus chère en énergie ET en temps-machine) ; monnaies (valeur / coût ≤ 1,15 × X0) ; part de la recherche
      dans [30 %, 40 %] sur la fusion ET sur la voie d'X0 (fusion sans variantes) ;
   9. mutants refusés : par les contrôles propres, et (voie complète) par epochs_test rejoué sur leur fusion.
  Ce qu'il ne prouve pas : le moteur réel (aucun prototype n'existe), l'équilibrage en partie, les hypothèses
  H-X3-1 à H-X3-4 (moteur), la mémoire vidéo des futures images ; titanium, monde, org et levels ne lisent pas le
  contenu d'X3 (ils prouvent seulement que la fusion ne casse rien de ce qu'ils lisent).
]]

package.path = "./?.lua;" .. package.path
local X3 = require("shared.content.x3")
local G = require("shared.ai3.graphe")
local A = require("shared.content.arsenal")
local Mo = require("shared.content.modules")
local W = require("shared.content.world")
local FIX = dofile("tests/fixtures/recipes.lua")

local COURT = false
for _, a in ipairs(arg or {}) do if a == "--court" then COURT = true end end

local INF = math.huge
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("[X3] ECHEC : " .. msg) end
  return cond
end
local function section(s) print("== " .. s) end
local function info(s) print("   " .. s) end
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
  return ks
end
local function set_of(list) local s = {} for _, v in ipairs(list or {}) do s[v] = true end return s end
local function fr(x, d) return (string.format("%." .. (d or 1) .. "f", x):gsub("%.", ",")) end

local function fresh_X() return dofile("shared/content/epochs.lua") end
local function fusion(data) return X3.merge(fresh_X(), data) end

local PSEUDO = { mining = true, gather = true, loot = true, burn = true, launch = true, heat = true }

---------------------------------------------------------------------------------------------------
-- Graphe complet (même construction qu'epochs_test : vanilla réelle, existant, barils, pseudo-recettes, X ou fusion).
---------------------------------------------------------------------------------------------------
local function build(F)
  local g = { F = F, idx = F.index() }
  local base_recipes = {}
  local function to_pairs(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = { e.name or e[1], e.amount or e[2] } end
    return out
  end
  local never = set_of(F.base_recipe_never)
  local hidden_allowed = {}
  for _, h in ipairs(F.base_recipe_hidden_allowed) do hidden_allowed[h[1]] = h[2] end
  for _, rn in ipairs(sorted_keys(FIX)) do
    local f = FIX[rn]
    if (not f.hidden or hidden_allowed[rn]) and not never[rn] then
      local r = { name = rn, category = f.category, time = f.energy, ingredients = to_pairs(f.ingredients), results = to_pairs(f.products), base = true }
      if rn:find("^empty%-.+%-barrel$") then for _, p in ipairs(r.results) do if p[1] == "empty-barrel" then p.back = true end end end
      if rn:find("^fill%-.+%-barrel$") or rn:find("^empty%-.+%-barrel$") then r.barrel = true end
      base_recipes[rn] = r
    end
  end
  local function from_arsenal(spec, category_is_recipe)
    local ing = {}
    for _, i in ipairs(spec.ingredients) do
      if i.type == "fluid" then ing[#ing + 1] = { i.name, i.amount } else ing[#ing + 1] = { i[1], i[2] } end
    end
    base_recipes[spec.name] = { name = spec.name, category = (category_is_recipe and spec.category) or "crafting", time = spec.energy or 10,
      ingredients = ing, results = { { spec.name, 1 } }, base = true }
  end
  for _, list in ipairs({ A.ammo, A.guns, A.turrets, A.walls, A.special_turrets, A.special_guns }) do
    for _, spec in ipairs(list) do from_arsenal(spec, true) end
  end
  for _, spec in ipairs(A.special_ammo) do from_arsenal(spec, false) end
  for _, fam in ipairs(Mo.ORDER) do
    for k = Mo.VANILLA_TIERS + 1, Mo.TIERS do
      local rec = Mo.recipe(fam, k)
      base_recipes[Mo.name(fam, k)] = { name = Mo.name(fam, k), category = "crafting", time = rec.energy,
        ingredients = to_pairs(rec.ingredients), results = { { Mo.name(fam, k), 1 } }, base = true }
    end
  end
  base_recipes["fo-command-center"] = { name = "fo-command-center", category = "crafting", time = 5, base = true,
    ingredients = { { "iron-chest", 4 }, { "iron-gear-wheel", 20 }, { "electronic-circuit", 10 }, { "stone-brick", 20 } },
    results = { { "fo-command-center", 1 } } }
  for _, ov in ipairs(F.existing_overrides) do if base_recipes[ov.name] then base_recipes[ov.name].ingredients = ov.ingredients end end
  local base_epoch = {}
  for _, row in ipairs(F.base_recipe_epochs) do for _, n in ipairs(row[2]) do base_epoch[n] = row[1] end end
  for rn, e in pairs(hidden_allowed) do base_epoch[rn] = e end
  for _, rn in ipairs(sorted_keys(base_recipes)) do base_recipes[rn].epoch = base_epoch[rn] or 99 end
  local all = {}
  for _, rn in ipairs(sorted_keys(base_recipes)) do all[#all + 1] = base_recipes[rn] end
  for _, p in ipairs(F.base_pseudo) do all[#all + 1] = p end
  for _, it in ipairs(F.items) do
    if it.type == "fluid" and it.barrel then
      local bn, e = it.name .. "-barrel", math.max(4, it.epoch)
      all[#all + 1] = { name = "fill-" .. bn, epoch = e, category = "crafting-with-fluid", time = 0.2, barrel = true, kind = "recipe",
        ingredients = { { it.name, 50 }, { "empty-barrel", 1 } }, results = { { bn, 1 } } }
      all[#all + 1] = { name = "empty-" .. bn, epoch = e, category = "crafting-with-fluid", time = 0.2, barrel = true, kind = "recipe",
        ingredients = { { bn, 1 } }, results = { { it.name, 50 }, { "empty-barrel", 1, back = true } } }
    end
  end
  for _, r in ipairs(F.recipes) do all[#all + 1] = r end
  table.sort(all, function(a, b) return a.name < b.name end)
  g.all = all
  g.recipe = {}
  for _, r in ipairs(all) do if not g.recipe[r.name] then g.recipe[r.name] = r end end

  local is_fluid = {}
  for _, f in ipairs(F.base_fluids) do is_fluid[f] = true end
  for _, it in ipairs(F.items) do if it.type == "fluid" then is_fluid[it.name] = true end end
  for _, rn in ipairs(sorted_keys(FIX)) do
    for _, i in ipairs(FIX[rn].ingredients) do if i.type == "fluid" then is_fluid[i.name] = true end end
    for _, p in ipairs(FIX[rn].products) do if p.type == "fluid" then is_fluid[p.name] = true end end
  end
  g.is_fluid = is_fluid

  local known = {}
  for _, rn in ipairs(sorted_keys(FIX)) do
    for _, i in ipairs(FIX[rn].ingredients) do known[i.name] = true end
    for _, p in ipairs(FIX[rn].products) do known[p.name] = true end
  end
  for _, f in ipairs(F.base_fluids) do known[f] = true end
  for _, m in ipairs(F.base_machines) do known[m.name] = true end
  for _, r in ipairs(all) do for _, p in ipairs(r.results) do known[p[1]] = true end end
  for _, it in ipairs(F.items) do known[it.name] = true end
  for _, b in ipairs(F.buildings) do known[b.name] = true end
  g.known = known

  local machine_def, cat_machines = {}, {}
  for _, m in ipairs(F.base_machines) do machine_def[m.name] = m end
  for _, b in ipairs(F.buildings) do machine_def[b.name] = b end
  for _, mn in ipairs(sorted_keys(machine_def)) do
    for _, c in ipairs(machine_def[mn].categories or {}) do
      cat_machines[c] = cat_machines[c] or {}
      table.insert(cat_machines[c], mn)
    end
  end
  g.machine_def, g.cat_machines = machine_def, cat_machines
  function g.machines_of(r) return r.machines or cat_machines[r.category] or {} end

  local avail = {}
  local function av(n) return avail[n] or INF end
  local function machine_avail(r)
    local best = INF
    for _, m in ipairs(g.machines_of(r)) do
      local e = (machine_def[m] and machine_def[m].hand) and 1 or av(m)
      if e < best then best = e end
    end
    return best
  end
  local function recipe_avail(r)
    local e = r.epoch or INF
    for _, i in ipairs(r.ingredients) do local a = av(i[1]); if a > e then e = a end end
    local m = machine_avail(r)
    if m > e then e = m end
    return e
  end
  local changed, n = true, 0
  while changed and n < 200 do
    changed, n = false, n + 1
    for _, r in ipairs(all) do
      local e = recipe_avail(r)
      if e < INF then
        for _, p in ipairs(r.results) do if e < av(p[1]) then avail[p[1]] = e; changed = true end end
      end
    end
  end
  g.fixpoint_passes = n
  g.av, g.recipe_avail = av, recipe_avail

  local producers, consumers, consumer_list = {}, {}, {}
  for _, r in ipairs(all) do
    for _, i in ipairs(r.ingredients) do
      consumers[i[1]] = (consumers[i[1]] or 0) + 1
      if not r.barrel then consumer_list[i[1]] = consumer_list[i[1]] or {}; table.insert(consumer_list[i[1]], r) end
    end
    for _, p in ipairs(r.results) do producers[p[1]] = producers[p[1]] or {}; table.insert(producers[p[1]], r) end
  end
  g.producers, g.consumers, g.consumer_list = producers, consumers, consumer_list

  g.tech_by, g.unlocked_by = {}, {}
  for _, t in ipairs(F.technologies) do g.tech_by[t.name] = g.tech_by[t.name] or t end
  for _, t in ipairs(F.technologies) do
    for _, rn in ipairs(t.unlocks) do g.unlocked_by[rn] = g.unlocked_by[rn] or {}; table.insert(g.unlocked_by[rn], t) end
  end
  return g
end

--- Noms touchés par X3 dans une fusion (recettes nouvelles et retouchées : la « portée » des contrôles propres).
local NO_X3 = { added = { recipes = {}, items = {}, buildings = {}, technologies = {}, resources = {} }, retouched = {}, extended = {} }
local function scope_of(F)
  local x = F.x3 or NO_X3
  local s = { recipes = {}, added_recipes = {}, items = {}, buildings = {}, techs = {}, added_techs = {}, resources = {} }
  for _, n in ipairs(x.added.recipes) do s.recipes[n] = true; s.added_recipes[n] = true end
  for _, n in ipairs(x.retouched) do s.recipes[n] = true end
  for _, n in ipairs(x.added.items) do s.items[n] = true end
  for _, n in ipairs(x.added.buildings) do s.buildings[n] = true end
  for _, n in ipairs(x.added.technologies) do s.techs[n] = true; s.added_techs[n] = true end
  for _, n in ipairs(x.extended) do s.techs[n] = true end
  for _, n in ipairs(x.added.resources) do s.resources[n] = true end
  return s
end

--- Graines numériques déjà prises par shared/content/world.lua (gisements, régions de biome, grain fin).
local WORLD_SEEDS, WORLD_RES = {}, {}
do
  for _, key in ipairs(sorted_keys(W.resources)) do
    local ap = W.resources[key].autoplace
    if ap and ap.seed1 then WORLD_SEEDS[ap.seed1] = "world.lua, gisement " .. key; WORLD_RES[WORLD_SEEDS[ap.seed1]] = W.resources[key].resource end
    if ap and ap.region and ap.region.seed1 then
      WORLD_SEEDS[ap.region.seed1] = "world.lua, région du gisement " .. key; WORLD_RES[WORLD_SEEDS[ap.region.seed1]] = W.resources[key].resource
    end
  end
  for _, b in ipairs(W.biomes) do if b.region and b.region.seed1 then WORLD_SEEDS[b.region.seed1] = "world.lua, région " .. b.name end end
  for _, n in ipairs(sorted_keys(W.grain.seed1)) do WORLD_SEEDS[W.grain.seed1[n]] = "world.lua, grain " .. n end
end

---------------------------------------------------------------------------------------------------
-- Contrôles propres (fusion entière, ou portée X3 quand c'est dit). Collecteur : réutilisé par les mutants.
---------------------------------------------------------------------------------------------------
local SINK_USES = { pack = true, data = true, codex = true, ammo = true, armor = true, tile = true, consumable = true, launch = true }

--- Recettes que shared/content/titanium.lua lit ou déplie (EN JEU) : aucune retouche X3 ne doit les viser.
local TITANIUM_READS
do
  local T = require("shared.content.titanium")
  TITANIUM_READS = {}
  for _, r in ipairs(T.RECIPES) do TITANIUM_READS[r.name] = true end
  for _, b in ipairs(T.BUILDINGS) do
    TITANIUM_READS[b.name] = true
    local br = T.building_recipe(b.name)
    for _, tr in ipairs(br.trace) do TITANIUM_READS[tr[2]] = true end
  end
  -- Lot AMELIO-CRAFTS : les recettes de X0 mises en jeu par shared/content/crafts.lua (bobine comprise, que le titane
  -- ne déplie plus) sont EN JEU au même titre.
  local C = require("shared.content.crafts")
  for _, rr in ipairs(C.RECIPES) do TITANIUM_READS[rr.name] = true end
  for _, b in ipairs(C.BUILDINGS) do TITANIUM_READS[b.name] = true end
end
--- Règle T.maker de titanium.lua, rejouée sur une liste de recettes.
local function maker(recipes, name)
  for _, r in ipairs(recipes) do
    if r.kind == "recipe" or r.kind == "building" or r.kind == nil then
      for _, p in ipairs(r.results or {}) do if p[1] == name and not p.p then return r.name end end
    end
  end
  return nil
end

local function run_checks(F, g, X0)
  local col = { ok = 0, fails = {}, by_kind = {} }
  local function c(cond, kind, msg)
    if cond then col.ok = col.ok + 1
    else col.fails[#col.fails + 1] = kind .. " : " .. msg; col.by_kind[kind] = (col.by_kind[kind] or 0) + 1 end
  end
  local sc = scope_of(F)
  local start = set_of(F.start_recipes)
  local idx = g.idx

  -- (2) Fermeture du graphe.
  c(g.fixpoint_passes < 200, "fermeture", "point fixe convergent (" .. g.fixpoint_passes .. " passes)")
  for _, r in ipairs(F.recipes) do
    for _, i in ipairs(r.ingredients) do c(g.known[i[1]], "inconnu", r.name .. " : ingrédient connu " .. tostring(i[1])) end
    for _, p in ipairs(r.results) do c(g.known[p[1]], "inconnu", r.name .. " : produit connu " .. tostring(p[1])) end
    c(#g.machines_of(r) > 0, "machine", r.name .. " : au moins une machine pour « " .. tostring(r.category) .. " »")
    for _, m in ipairs(g.machines_of(r)) do c(g.machine_def[m] ~= nil, "machine", r.name .. " : machine déclarée " .. m) end
    local e = g.recipe_avail(r)
    c(e < INF, "fermeture", r.name .. " : réalisable depuis les ressources de la carte")
    if e < INF then c(e == r.epoch, "fermeture", r.name .. " : disponible à son âge " .. r.epoch .. " (calculé : " .. e .. ")") end
  end
  for _, it in ipairs(F.items) do
    c(g.av(it.name) == it.epoch, "fermeture", it.name .. " : fabricable depuis les ressources de son âge " .. it.epoch .. " (calculé : " .. tostring(g.av(it.name)) .. ")")
  end
  for _, b in ipairs(F.buildings) do
    c(g.av(b.name) == b.epoch, "fermeture", b.name .. " : bâtiment disponible à son âge " .. b.epoch .. " (calculé : " .. tostring(g.av(b.name)) .. ")")
  end

  -- (2 bis) Limites moteur des recettes et bâtiments d'X3 (voie courte, sans epochs_test).
  do
    local item_count, recipe_count, tech_count = {}, {}, {}
    for _, it in ipairs(F.items) do item_count[it.name] = (item_count[it.name] or 0) + 1 end
    for _, b in ipairs(F.buildings) do item_count[b.name] = (item_count[b.name] or 0) + 1 end
    for _, r in ipairs(F.recipes) do recipe_count[r.name] = (recipe_count[r.name] or 0) + 1 end
    for _, t in ipairs(F.technologies) do tech_count[t.name] = (tech_count[t.name] or 0) + 1 end
    for _, n in ipairs(sorted_keys(sc.items)) do c(item_count[n] == 1, "doublon", n .. " : nom d'objet unique (objets et bâtiments)") end
    for _, n in ipairs(sorted_keys(sc.buildings)) do c(item_count[n] == 1, "doublon", n .. " : nom de bâtiment unique (objets et bâtiments)") end
    for _, n in ipairs(sorted_keys(sc.added_recipes)) do c(recipe_count[n] == 1, "doublon", n .. " : nom de recette unique") end
    for _, n in ipairs(sorted_keys(sc.added_techs)) do c(tech_count[n] == 1, "doublon", n .. " : nom de technologie unique") end
  end
  for _, rn in ipairs(sorted_keys(sc.recipes)) do
    local r = g.recipe[rn]
    if r and not PSEUDO[r.kind] then
      local nfi, nfo, nsi = 0, 0, 0
      for _, i in ipairs(r.ingredients) do if g.is_fluid[i[1]] then nfi = nfi + 1 else nsi = nsi + 1 end end
      for _, p in ipairs(r.results) do if g.is_fluid[p[1]] then nfo = nfo + 1 end end
      local fits, all_furnace = false, true
      for _, m in ipairs(g.machines_of(r)) do
        local d = g.machine_def[m]
        if d and not d.hand then
          local furnace = d.furnace or d.proto == "furnace"
          if not furnace then all_furnace = false end
          local fin, fout = d.fluid_in or 0, d.fluid_out or 0
          if nfi <= fin and nfo <= fout and (not furnace or (nfi == 0 and nsi <= 1)) then fits = true end
        end
      end
      c(fits, "moteur", rn .. " : une machine de « " .. tostring(r.category) .. " » a les entrées voulues (" .. nsi .. " solide(s), " .. nfi .. " fluide(s) en entrée, " .. nfo .. " en sortie)")
      if all_furnace and #g.machines_of(r) > 0 then c(nsi <= 1 and nfi == 0, "moteur", rn .. " : recette de four à UNE entrée solide") end
    end
    if r and r.kind == "mining" then
      local res = idx.resource[r.resource]
      local cat = res and res.category or "basic-solid"
      local hard = set_of(X3.HARD_DRILLS)
      for _, m in ipairs(r.machines or {}) do
        if cat == "fo-hard-solid" then c(hard[m], "moteur", rn .. " : " .. m .. " ne mine pas une ressource dure (fo-hard-solid)") end
      end
      if cat == "basic-solid" then c(table.concat(r.machines or {}, ",") == table.concat(X3.DRILLS, ","), "moteur", rn .. " : ressource ordinaire minée par les foreuses d'X0 (main comprise)") end
    end
  end
  for _, bn in ipairs(sorted_keys(sc.buildings)) do
    local b = idx.building[bn]
    for _, cat in ipairs(b.categories or {}) do
      local served = false
      for _, r in ipairs(g.all) do if r.category == cat and not PSEUDO[r.kind] then served = true end end
      c(served, "batiment", bn .. " : sa catégorie « " .. cat .. " » est servie par au moins une recette")
    end
    if b.fixed_recipe then c(g.recipe[b.fixed_recipe] ~= nil and set_of(b.categories)[g.recipe[b.fixed_recipe].category], "batiment", bn .. " : recette fixe réelle et de sa catégorie") end
  end
  do -- le calcul : fluide sans baril, boîtes filtrées sur ses bâtiments.
    local cmp = idx.item["fo-compute"]
    if cmp then
      c(cmp.type == "fluid" and cmp.barrel == false, "baril", "fo-compute : fluide SANS baril (auto_barrel = false)")
      local dc, rb = idx.building["fo-data-center"], idx.building["fo-robotics-bay"]
      local function has(list, n) return set_of(list or {})[n] == true end
      c(dc and dc.fluid_filters and has(dc.fluid_filters.input, "water") and has(dc.fluid_filters.output, "fo-compute"), "baril",
        "centre de calcul : entrée filtrée sur l'eau, sortie filtrée sur le calcul (FluidBox.filter)")
      c(rb and rb.fluid_filters and has(rb.fluid_filters.input, "fo-compute"), "baril", "atelier de robotique : entrée filtrée sur le calcul")
    end
  end

  -- (3) Aucun objet sans usage ; objets d'X3 consommés dès leur âge ; sous-produits à deux exutoires.
  for _, it in ipairs(F.items) do
    c(g.producers[it.name] ~= nil, "usage", it.name .. " : a une recette ou une source")
    local sink = (g.consumers[it.name] or 0) > 0 or SINK_USES[it.use or ""] or it.counter_only
    c(sink, "usage", it.name .. " : consommé par une recette ou un usage final (" .. tostring(it.use) .. ")")
  end
  for _, b in ipairs(F.buildings) do c(g.producers[b.name] ~= nil, "usage", b.name .. " : bâtiment fabricable") end
  for _, n in ipairs(sorted_keys(sc.items)) do
    local it = idx.item[n]
    if it and not SINK_USES[it.use or ""] then
      local same = false
      for _, r in ipairs(g.consumer_list[n] or {}) do if r.epoch == it.epoch then same = true end end
      c(same, "usage-age", n .. " : consommé dès son âge " .. it.epoch .. " (hors usages finals)")
    end
  end
  for _, rn in ipairs(sorted_keys(sc.recipes)) do
    local r = g.recipe[rn]
    if r and not PSEUDO[r.kind] then
      local ing = {}
      for _, i in ipairs(r.ingredients) do ing[i[1]] = true end
      for k, p in ipairs(r.results) do
        if k > 1 and not p.back and not ing[p[1]] then
          local outs = 0
          for _, cr in ipairs(g.consumer_list[p[1]] or {}) do if cr.name ~= rn then outs = outs + 1 end end
          c(outs >= 2, "sous-produit", rn .. " : son sous-produit " .. p[1] .. " a deux exutoires (" .. outs .. ")")
        end
      end
    end
  end

  -- (4) Aucune recette orpheline.
  for _, r in ipairs(F.recipes) do
    if not PSEUDO[r.kind] and r.kind ~= "sink" then
      local by = g.unlocked_by[r.name] or {}
      if start[r.name] then c(#by == 0, "orpheline", r.name .. " : recette de départ sans technologie")
      elseif r.unlock == "wonder" then c(#by == 0, "orpheline", r.name .. " : activée par une merveille")
      else
        c(#by == 1, "orpheline", r.name .. " : débloquée par exactement une technologie (" .. #by .. ")")
        if #by == 1 then c(by[1].epoch == r.epoch, "orpheline", r.name .. " : technologie " .. by[1].name .. " de son âge " .. r.epoch) end
      end
    end
  end
  for _, t in ipairs(F.technologies) do
    for _, rn in ipairs(t.unlocks) do
      local r = idx.recipe[rn]
      c(r ~= nil and not PSEUDO[r.kind], "orpheline", t.name .. " : débloque une recette réelle " .. rn)
    end
  end

  -- (5) Technologies et prérequis.
  local pack_tech = {}
  for _, t in ipairs(F.technologies) do if t.role == "pack" then pack_tech[t.epoch] = t.name end end
  for _, t in ipairs(F.technologies) do
    for _, pr in ipairs(t.prereq) do
      local p = g.tech_by[pr]
      c(p ~= nil, "prerequis", t.name .. " : prérequis déclaré " .. pr)
      if p then c(p.epoch <= t.epoch, "prerequis", t.name .. " (âge " .. t.epoch .. ") : prérequis " .. pr .. " d'un âge antérieur ou égal (" .. p.epoch .. ")") end
    end
  end
  do -- sans cycle (tri topologique déterministe)
    local indeg, order, ready = {}, 0, {}
    for _, t in ipairs(F.technologies) do indeg[t.name] = 0 end
    for _, t in ipairs(F.technologies) do for _, pr in ipairs(t.prereq) do if g.tech_by[pr] then indeg[t.name] = indeg[t.name] + 1 end end end
    for _, t in ipairs(F.technologies) do if indeg[t.name] == 0 then ready[#ready + 1] = t.name end end
    while #ready > 0 do
      table.sort(ready)
      local n = table.remove(ready, 1)
      order = order + 1
      for _, t in ipairs(F.technologies) do
        for _, pr in ipairs(t.prereq) do
          if pr == n then indeg[t.name] = indeg[t.name] - 1; if indeg[t.name] == 0 then ready[#ready + 1] = t.name end end
        end
      end
    end
    c(order == #F.technologies, "prerequis", "prérequis sans cycle (" .. order .. " / " .. #F.technologies .. ")")
  end
  -- Fermeture des prérequis d'une technologie : elle-même, ses prérequis (transitifs) et, pour une technologie qui n'est
  -- pas celle du pack, la technologie du pack de son âge (prérequis implicite d'X0).
  local closure_cache = {}
  local function closure(t)
    if closure_cache[t.name] then return closure_cache[t.name] end
    local seen = {}
    local function walk(name, depth)
      if seen[name] or depth > 200 then return end
      seen[name] = true
      local tt = g.tech_by[name]
      if not tt then return end
      for _, pr in ipairs(tt.prereq) do walk(pr, depth + 1) end
      if tt.role ~= "pack" and pack_tech[tt.epoch] then walk(pack_tech[tt.epoch], depth + 1) end
    end
    walk(t.name, 0)
    closure_cache[t.name] = seen
    return seen
  end
  -- Chemin obligatoire avant l'âge k : technologies de pack et de Codex des âges < k, et leurs prérequis.
  local must_cache = {}
  local function mandatory_before(k)
    if must_cache[k] then return must_cache[k] end
    local m = {}
    for _, t in ipairs(F.technologies) do
      if t.epoch < k and (t.role == "pack" or t.role == "codex") then for n in pairs(closure(t)) do m[n] = true end end
    end
    must_cache[k] = m
    return m
  end
  local function obtainable(item, t, clos, strict)
    local a = g.av(item)
    if a < t.epoch and not strict then return true end
    if a > t.epoch then return false end
    local must = (a < t.epoch) and mandatory_before(t.epoch) or {}
    for _, r in ipairs(g.producers[item] or {}) do
      if g.recipe_avail(r) <= t.epoch then
        if r.base or r.barrel or PSEUDO[r.kind] or start[r.name] then return true end
        for _, tt in ipairs(g.unlocked_by[r.name] or {}) do if clos[tt.name] or must[tt.name] then return true end end
      end
    end
    return false
  end
  local x0_viol = {}
  for _, t in ipairs(F.technologies) do
    local clos = closure(t)
    for _, rn in ipairs(t.unlocks) do
      local r = idx.recipe[rn]
      if r then
        local strict = sc.added_recipes[rn] == true
        local bad = {}
        for _, i in ipairs(r.ingredients) do if not obtainable(i[1], t, clos, strict) then bad[#bad + 1] = i[1] end end
        local mach_ok = false
        for _, m in ipairs(g.machines_of(r)) do
          if (g.machine_def[m] and g.machine_def[m].hand) or obtainable(m, t, clos, strict) then mach_ok = true end
        end
        if not mach_ok then bad[#bad + 1] = "machine de « " .. tostring(r.category) .. " »" end
        local msg = rn .. " (" .. t.name .. ", âge " .. t.epoch .. ") : " .. table.concat(bad, ", ") .. " requis avant son déblocage (ni par la technologie, ni par ses prérequis"
          .. (strict and ", ni par le chemin obligatoire)" or ")")
        if sc.recipes[rn] or sc.techs[t.name] then c(#bad == 0, "deblocage", msg)
        elseif #bad > 0 then x0_viol[#x0_viol + 1] = msg end
      end
    end
  end
  col.x0_deblocage = x0_viol
  if X0 then -- recalage des unités : aux âges d'X3 seulement, et borné.
    local x3_age = {}
    for _, tn in ipairs(sorted_keys(sc.added_techs)) do x3_age[g.tech_by[tn].epoch] = true end
    for k = 1, F.EPOCHS do
      local u, u0 = F.TECH_UNITS[k], X0.TECH_UNITS[k]
      if u ~= u0 then
        c(x3_age[k] == true, "recherche", "âge " .. k .. " : unités recalées (" .. u .. " contre " .. u0 .. ") seulement aux âges qui reçoivent une technologie d'X3")
        c(u >= 0.7 * u0 and u <= 1.3 * u0, "recherche", "âge " .. k .. " : recalage borné à 0,7 à 1,3 × X0 (" .. u .. " contre " .. u0 .. ")")
      end
    end
  end

  -- (6) Lisible par le cerveau général.
  for _, rn in ipairs(sorted_keys(sc.recipes)) do
    local r = idx.recipe[rn]
    if r and not PSEUDO[r.kind] then
      local non_hand = 0
      for _, m in ipairs(g.machines_of(r)) do if not (g.machine_def[m] and g.machine_def[m].hand) then non_hand = non_hand + 1 end end
      c(non_hand > 0, "cerveau", rn .. " : une vraie machine sert sa catégorie « " .. tostring(r.category) .. " »")
      if r.category == "crafting" then
        local fl = false
        for _, i in ipairs(r.ingredients) do if g.is_fluid[i[1]] then fl = true end end
        for _, p in ipairs(r.results) do if g.is_fluid[p[1]] then fl = true end end
        c(not fl and #r.results == 1, "cerveau", rn .. " : recette à la main = solides, un seul produit")
      end
    end
  end
  for _, n in ipairs(sorted_keys(sc.items)) do
    local ok = false
    for _, r in ipairs(g.producers[n] or {}) do
      if r.kind == "recipe" or r.kind == "building" or r.kind == "mining" or r.base then ok = true end
    end
    c(ok, "cerveau", n .. " : produit par une recette ou un minage (aucune étape par script : lancement, merveille)")
  end
  -- Cycles de production : composantes fortement connexes (Tarjan) sur les objets, arcs « ingrédient → PRODUIT
  -- PRINCIPAL » (le premier), hors barils, hors catalyse déclarée (ingrédient = produit).
  do
    local edges, edge_x3 = {}, {}
    for _, r in ipairs(g.all) do
      local k = r.kind
      local p = r.results[1]
      if (k == nil or k == "recipe" or k == "building") and not r.barrel and p and not p.back then
        for _, i in ipairs(r.ingredients) do
          if i[1] ~= p[1] then
            edges[i[1]] = edges[i[1]] or {}
            table.insert(edges[i[1]], p[1])
            if sc.recipes[r.name] then edge_x3[i[1] .. ">" .. p[1]] = r.name end
          end
        end
      end
    end
    local index, low, onstack, stack, comp, counter = {}, {}, {}, {}, {}, 0
    local function strong(v)
      counter = counter + 1
      index[v], low[v] = counter, counter
      stack[#stack + 1] = v; onstack[v] = true
      for _, w in ipairs(edges[v] or {}) do
        if not index[w] then strong(w); if low[w] < low[v] then low[v] = low[w] end
        elseif onstack[w] and index[w] < low[v] then low[v] = index[w] end
      end
      if low[v] == index[v] then
        local id = v
        repeat
          local w = table.remove(stack)
          onstack[w] = nil
          comp[w] = id
        until w == v
      end
    end
    for _, v in ipairs(sorted_keys(edges)) do if not index[v] then strong(v) end end
    local x3_cycles = {}
    for _, key in ipairs(sorted_keys(edge_x3)) do
      local a, b = key:match("^(.-)>(.*)$")
      if comp[a] and comp[a] == comp[b] then x3_cycles[#x3_cycles + 1] = edge_x3[key] .. " (" .. a .. " → " .. b .. ")" end
    end
    c(#x3_cycles == 0, "cerveau", "aucun cycle de production par une recette X3 hors catalyse déclarée : " .. table.concat(x3_cycles, " ; "))
  end

  -- (7) Placement des ressources d'X3.
  do
    local used = {}
    for _, n in ipairs(sorted_keys(sc.resources)) do
      local r = idx.resource[n]
      local pl = r and r.placement or {}
      c(pl.autoplace ~= nil and pl.autoplace ~= "vanilla-like", "placement", n .. " : aucun autoplace « vanilla-like » (compteur de jeux de gisements partagé : il déplacerait tous les minerais)")
      c(pl.guaranteed and (pl.guaranteed.count or 0) >= 1 and pl.guaranteed.what_fr, "placement", n .. " : garantie de placement déclarée")
      local ps = pl.patch_set
      if ps then
        c(r.biome == nil, "placement", n .. " : un jeu de gisements propre ne partage aucun masque de biome (deux ressources se disputeraient les tuiles)")
        c(type(ps.seed1) == "number" and ps.seed1 >= 1, "placement", n .. " : graine seed1 NUMÉRIQUE (F198)")
        c(ps.region and type(ps.region.seed1) == "number", "placement", n .. " : masque de région à graine numérique propre")
        for _, s in ipairs({ ps.seed1, ps.region and ps.region.seed1 }) do
          if type(s) == "number" then
            -- piste ÉTAIN : la ressource EN JEU porte sa propre graine dans world.lua (même nom de ressource)
            local own = WORLD_SEEDS[s] and WORLD_RES[WORLD_SEEDS[s]] == n
            c(WORLD_SEEDS[s] == nil or own, "placement", n .. " : graine " .. s .. " libre dans world.lua, ou celle de la ressource elle-même (" .. tostring(WORLD_SEEDS[s]) .. ")")
            c(used[s] == nil, "placement", n .. " : graine " .. s .. " unique parmi les ressources d'X3 (" .. tostring(used[s]) .. ")")
            used[s] = n
          end
        end
      else
        c(pl.autoplace and pl.autoplace:find("^aucune"), "placement", n .. " : sans jeu de gisements propre, PAS d'autoplace (garantie seule)")
      end
    end
  end

  -- (1) Garde du jeu : aucune recette d'X0 modifiée, variantes réelles, chemin obligatoire intact, T.maker inchangé.
  local retouched = (F.x3 or NO_X3).retouched
  if F.x3 then c(#retouched == 0, "regle", "aucune recette d'X0 modifiée : des voies, jamais une porte (" .. #retouched .. " retouche(s) : " .. table.concat(retouched, ", ") .. ")") end
  for _, n in ipairs(retouched) do
    c(not TITANIUM_READS[n], "titane", n .. " : la retouche ne vise aucune recette que titanium.lua lit ou déplie")
  end
  for _, rn in ipairs(sorted_keys(sc.added_recipes)) do
    local r = idx.recipe[rn]
    if r and r.variant_of then
      local makes, other = false, false
      for _, p in ipairs(r.results) do if p[1] == r.variant_of then makes = true end end
      for _, pr in ipairs(g.producers[r.variant_of] or {}) do if not sc.added_recipes[pr.name] and not pr.barrel then other = true end end
      c(makes and other, "variante", rn .. " : variante de " .. r.variant_of .. " (elle le produit, et une voie d'X0 ou vanilla reste)")
    end
  end
  for _, t in ipairs(F.technologies) do
    if (t.role == "pack" or t.role == "codex") and not sc.added_techs[t.name] then
      for _, pr in ipairs(t.prereq) do c(not sc.added_techs[pr], "regle", t.name .. " (" .. t.role .. ") : aucun prérequis d'X3 sur le chemin obligatoire (" .. pr .. ")") end
    end
  end
  if X0 then
    local diff = {}
    for _, it in ipairs(X0.items) do
      if maker(X0.recipes, it.name) ~= maker(F.recipes, it.name) then diff[#diff + 1] = it.name end
    end
    c(#diff == 0, "titane", "T.maker identique sur X0 et sur la fusion pour les " .. #X0.items .. " objets de X0 : " .. table.concat(diff, ", "))
  end
  return col
end

---------------------------------------------------------------------------------------------------
-- Profondeur de chaîne (plus courte chaîne de recettes depuis les ressources, recettes de l'âge E ou d'avant).
---------------------------------------------------------------------------------------------------
local function depth_map(g, E)
  local d = {}
  for _, r in ipairs(g.all) do
    if (r.kind == "mining" or r.kind == "gather" or r.kind == "loot") and (r.epoch or 99) <= E then
      for _, p in ipairs(r.results) do d[p[1]] = 0 end
    end
  end
  local changed, n = true, 0
  while changed and n < 300 do
    changed, n = false, n + 1
    for _, r in ipairs(g.all) do
      local k = r.kind
      if (k == nil or k == "recipe" or k == "building" or k == "heat" or (k == "launch" and #r.results > 0)) and (r.epoch or 99) <= E then
        local m, ok = 0, true
        for _, i in ipairs(r.ingredients) do
          local x = d[i[1]]
          if x == nil then ok = false break end
          if x > m then m = x end
        end
        if ok then
          for _, p in ipairs(r.results) do
            local self = false
            for _, i in ipairs(r.ingredients) do if i[1] == p[1] then self = true end end
            if not self and not p.back and (d[p[1]] == nil or m + 1 < d[p[1]]) then d[p[1]] = m + 1; changed = true end
          end
        end
      end
    end
  end
  return d, n
end

---------------------------------------------------------------------------------------------------
-- MU (même règle qu'epochs_test : chemin le moins cher, fluides à 0,1 MU, eau et vapeur gratuites, catalyseurs
-- soustraits, partage des sous-produits au poids), énergie (MJ) et temps-machine (s) le long du chemin retenu.
-- allow(r, produit) : restreint les recettes (voie du cerveau) ; nil = toutes.
---------------------------------------------------------------------------------------------------
local function weight_fn(F, g)
  local rho = {}
  for _, it in ipairs(F.items) do if it.rho then rho[it.name] = it.rho end end
  local free = set_of(F.FREE_FLUIDS)
  return function(n)
    if g.is_fluid[n] then return free[n] and 0 or (rho[n] or F.FLUID_MU) end
    return rho[n] or 1
  end
end
local function mu_map(F, g, allow)
  local w = weight_fn(F, g)
  local mu, best = {}, {}
  local changed, n = true, 0
  while changed and n < 400 do
    changed, n = false, n + 1
    for _, r in ipairs(g.all) do
      if r.kind ~= "burn" and r.kind ~= "sink" and r.unlock ~= "wonder" then
        local input, ok = 0, true
        if r.kind == "mining" or r.kind == "gather" or r.kind == "loot" or (r.kind == "launch" and r.extraction) then
          input = nil
        else
          for _, i in ipairs(r.ingredients) do
            local m = (g.is_fluid[i[1]] and w(i[1]) == 0) and 0 or (mu[i[1]] or INF)
            if m == INF then ok = false break end
            input = input + m * (i[2] - (i.catalyst or 0))
          end
        end
        if ok then
          local Wt = 0
          for _, p in ipairs(r.results) do if not p.back then Wt = Wt + (p[2] - (p.catalyst or 0)) * (p.p or 1) * w(p[1]) end end
          for _, p in ipairs(r.results) do
            if not p.back and p[2] - (p.catalyst or 0) > 0 and (not allow or allow(r, p[1])) then
              local unit
              if input == nil then unit = w(p[1]) elseif Wt > 0 then unit = input * w(p[1]) / Wt end
              if unit and unit < (mu[p[1]] or INF) - 1e-12 then mu[p[1]] = unit; best[p[1]] = r; changed = true end
            end
          end
        end
      end
    end
  end
  return mu, best, n
end
--- Machine de référence d'une recette : la moins gourmande par seconde de recette (kW / vitesse), hors main s'il y a
--- une vraie machine ; minage : vitesse de minage, foreuse électrique à 90 kW.
local function machine_of(g, r)
  local bk, bs, bratio
  for _, m in ipairs(g.machines_of(r)) do
    local d = g.machine_def[m]
    if d and not d.hand then
      local sp = (r.kind == "mining") and (d.mining_speed or 0.5) or (d.speed or 1)
      local kw = d.kw or ((r.kind == "mining") and 90 or 0)
      if sp > 0 and (not bratio or kw / sp < bratio - 1e-12) then bk, bs, bratio = kw, sp, kw / sp end
    end
  end
  if not bk then return 0, (r.kind == "mining") and 0.5 or 1 end
  return bk, bs
end
local function energy_fn(F, g, mu, best)
  local w = weight_fn(F, g)
  local memo, visiting = {}, {}
  local cost
  local function per_unit(r, item, depth)
    local kw, sp = machine_of(g, r)
    local t = tonumber(r.time) or 1
    local mj, ms = kw * t / sp / 1000, t / sp
    for _, i in ipairs(r.ingredients) do
      local q = i[2] - (i.catalyst or 0)
      if q > 0 then
        local cc = cost(i[1], depth + 1)
        mj, ms = mj + cc[1] * q, ms + cc[2] * q
      end
    end
    local Wt, wi = 0, 0
    for _, p in ipairs(r.results) do
      if not p.back then
        local x = (p[2] - (p.catalyst or 0)) * (p.p or 1) * w(p[1])
        Wt = Wt + x
      end
    end
    wi = w(item)
    if Wt <= 0 then
      local amt = 1
      for _, p in ipairs(r.results) do if p[1] == item then amt = p[2] end end
      return { mj / amt, ms / amt }
    end
    return { mj * wi / Wt, ms * wi / Wt }
  end
  cost = function(n, depth)
    depth = depth or 0
    if memo[n] then return memo[n] end
    local r = best[n]
    if not r or visiting[n] or depth > 80 then return { 0, 0 } end
    visiting[n] = true
    local v = per_unit(r, n, depth)
    visiting[n] = nil
    memo[n] = v
    return v
  end
  local function unit_mu(r, item)
    local input = 0
    for _, i in ipairs(r.ingredients) do
      local m = (g.is_fluid[i[1]] and w(i[1]) == 0) and 0 or (mu[i[1]] or INF)
      input = input + m * (i[2] - (i.catalyst or 0))
    end
    local Wt = 0
    for _, p in ipairs(r.results) do if not p.back then Wt = Wt + (p[2] - (p.catalyst or 0)) * (p.p or 1) * w(p[1]) end end
    return Wt > 0 and input * w(item) / Wt or INF
  end
  return { cost = cost, per_unit = function(r, item) return per_unit(r, item, 0) end, unit_mu = unit_mu }
end

---------------------------------------------------------------------------------------------------
-- Spécification du cerveau général (shared/ai3/graphe.lua) tirée des données, comme en jeu des prototypes : recettes
-- (sans les variantes activées par une merveille), machines (catégories, énergie), ressources (minage, cueillette,
-- butin), pseudo-recettes, électricité par la machine à vapeur ; avec ou sans les technologies (prérequis déclarés et
-- technologie du pack de l'âge, packs de la fenêtre × unités).
---------------------------------------------------------------------------------------------------
local BASE_ENERGY = { ["stone-furnace"] = "burner", ["steel-furnace"] = "burner", ["burner-mining-drill"] = "burner", boiler = "burner",
  ["electric-furnace"] = "electric", ["assembling-machine-1"] = "electric", ["assembling-machine-2"] = "electric",
  ["assembling-machine-3"] = "electric", ["chemical-plant"] = "electric", ["oil-refinery"] = "electric", centrifuge = "electric",
  ["rocket-silo"] = "electric", ["electric-mining-drill"] = "electric", pumpjack = "electric" }
local function graphe_spec(F, g, with_techs)
  local spec = { recipes = {}, pseudo_recipes = {}, techs = {}, machines = {}, resources = {},
    hand_categories = { crafting = true }, fuel = "coal", electricity = "x3-electricity" }
  local function typed(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = { name = e[1], amount = e[2] * (e.p or 1), type = g.is_fluid[e[1]] and "fluid" or "item" } end
    return out
  end
  local extra_cat, extra_res = {}, {}
  local function add(t, m, c) t[m] = t[m] or {}; table.insert(t[m], c) end
  local res_epoch = {}
  for _, r in ipairs(g.all) do
    local k = r.kind
    if k == "mining" or k == "gather" or k == "loot" then
      local cat = "x3-res-" .. r.name
      for _, m in ipairs(g.machines_of(r)) do add(extra_res, m, cat) end
      for _, p in ipairs(r.results) do
        local e = r.epoch or 99
        if not res_epoch[p[1]] or e < res_epoch[p[1]] then res_epoch[p[1]] = e; spec.resources[p[1]] = { category = cat } end
      end
    elseif k == "heat" or ((k == "launch" or k == "burn") and #r.results > 0) then
      local cat = "x3-" .. r.name
      for _, m in ipairs(g.machines_of(r)) do add(extra_cat, m, cat) end
      spec.pseudo_recipes[r.name] = { category = cat, energy = tonumber(r.time) or 10, hidden = false, ingredients = typed(r.ingredients), products = typed(r.results) }
    elseif (k == nil or k == "recipe" or k == "building") and r.unlock ~= "wonder" then
      spec.recipes[r.name] = { category = r.category, energy = tonumber(r.time) or 10, hidden = false, ingredients = typed(r.ingredients), products = typed(r.results) }
    end
  end
  for _, mn in ipairs(sorted_keys(g.machine_def)) do
    local m = g.machine_def[mn]
    local cats, rcats = {}, {}
    for _, c in ipairs(m.categories or {}) do cats[#cats + 1] = c end
    for _, c in ipairs(extra_cat[mn] or {}) do cats[#cats + 1] = c end
    for _, c in ipairs(m.resource_categories or {}) do rcats[#rcats + 1] = c end
    for _, c in ipairs(extra_res[mn] or {}) do rcats[#rcats + 1] = c end
    local energy = "none"
    if m.energy then
      if m.energy.type == "electric" then energy = "electric"
      elseif m.energy.type == "burner" and m.energy.fuel_category == "chemical" then energy = "burner" end
    elseif BASE_ENERGY[mn] then energy = BASE_ENERGY[mn] end
    spec.machines[#spec.machines + 1] = { name = mn, hand = m.hand, crafting_categories = cats, resource_categories = rcats,
      energy = energy, lab = m.proto == "lab" }
  end
  spec.machines[#spec.machines + 1] = { name = "steam-engine", crafting_categories = { "x3-generating" }, energy = "none" }
  spec.pseudo_recipes["x3-steam-power"] = { category = "x3-generating", energy = 1, hidden = false,
    ingredients = { { name = "steam", amount = 30, type = "fluid" } }, products = { { name = "x3-electricity", amount = 1, type = "fluid" } } }
  local tech_epoch = {}
  if with_techs then
    local pack_tech = {}
    for _, t in ipairs(F.technologies) do if t.role == "pack" then pack_tech[t.epoch] = t.name end end
    for _, t in ipairs(F.technologies) do
      local pre = {}
      for _, p in ipairs(t.prereq) do pre[#pre + 1] = p end
      if t.role ~= "pack" and pack_tech[t.epoch] and pack_tech[t.epoch] ~= t.name then pre[#pre + 1] = pack_tech[t.epoch] end
      local ing = {}
      for _, p in ipairs(t.packs or {}) do ing[#ing + 1] = { p, 1 } end
      spec.techs[t.name] = { unlocks = t.unlocks, prerequisites = pre, ingredients = ing, count = t.units }
      tech_epoch[t.name] = t.epoch
    end
  end
  return spec, res_epoch, tech_epoch
end

local function brain_world(F, g, with_techs)
  local spec, res_epoch, tech_epoch = graphe_spec(F, g, with_techs)
  return { F = F, g = g, cat = G.new(spec), spec = spec, res_epoch = res_epoch, tech_epoch = tech_epoch,
    tech_names = sorted_keys(tech_epoch), res_names = sorted_keys(spec.resources) }
end
--- État du cerveau : technologies des âges < k (ou ≤ k), ressources des âges ≤ k (sauf `unknown`), machines posées.
local function brain_state(Wb, k, o)
  o = o or {}
  local techs, known, built = {}, {}, {}
  for _, n in ipairs(Wb.tech_names) do
    local e = Wb.tech_epoch[n]
    if o.techs_all or e < k or (o.techs_through and e <= k) then techs[n] = true end
  end
  for _, n in ipairs(Wb.res_names) do
    if (o.res_all or (Wb.res_epoch[n] or 99) <= k) and not (o.unknown and o.unknown[n]) then known[n] = true end
  end
  if o.built then for _, m in ipairs(Wb.cat.machine_list) do built[m] = 1 end end
  local state = { stock = {}, techs = techs, built = built, known = known }
  return state, G.prepare(Wb.cat, state)
end
local function unf(Wb, st, prep, goals) return G.unfold(Wb.cat, goals, st, prep) end

---------------------------------------------------------------------------------------------------
-- Bancs rejoués dans ce processus, sur X seul ou sur la fusion (module de X remplacé, sorties captées).
---------------------------------------------------------------------------------------------------
local function run_bench(path, Xmod)
  -- Le banc rejoué laisse des modules (script.*, prototypes.*, tests.*) et des globales (moteur simulé) : sans les
  -- retirer, un second passage de levels_test dans le même processus plante (constaté le 27/10, X seul deux fois).
  local before_loaded, before_globals = {}, {}
  for k in pairs(package.loaded) do before_loaded[k] = true end
  for k in pairs(_G) do before_globals[k] = true end
  local saved_loaded = {}
  for k, v in pairs(package.loaded) do if k:find("^shared%.") then saved_loaded[k] = v; package.loaded[k] = nil end end
  package.loaded["shared.content.epochs"] = Xmod
  local lines = {}
  local real_print, real_exit, real_arg = print, os.exit, arg
  print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local EXIT = {}
  os.exit = function(code) error(EXIT, 0) end
  arg = {}
  local ok, err = pcall(dofile, path)
  print, os.exit, arg = real_print, real_exit, real_arg
  for k in pairs(package.loaded) do if k:find("^shared%.") or not before_loaded[k] then package.loaded[k] = nil end end
  for k, v in pairs(saved_loaded) do package.loaded[k] = v end
  for k in pairs(_G) do if not before_globals[k] then _G[k] = nil end end
  local res = { lines = lines, crashed = not ok and err ~= EXIT, err = (err ~= EXIT) and err or nil, fails = {} }
  for _, l in ipairs(lines) do
    local o, f = l:match("Résultat : (%d+) OK, (%d+) ECHEC")
    if o then res.ok, res.ko = tonumber(o), tonumber(f) end
    if l:find("ECHEC :", 1, true) then res.fails[#res.fails + 1] = l end
  end
  return res
end
local function find_line(lines, pat) for _, l in ipairs(lines) do if l:find(pat) then return l end end return nil end
local GEN_PAT = "bloc « [%w]+ » du scénario égal aux données"
local function research_shares(lines)
  local out = {}
  for _, l in ipairs(lines) do
    local k, sh = l:match("époque%s+(%d+) : nouvelle .-= ([%d%.]+) %% du budget")
    if k then out[tonumber(k)] = tonumber(sh) end
  end
  return out
end

---------------------------------------------------------------------------------------------------
section("Données X3 et fusion")
---------------------------------------------------------------------------------------------------
local X0 = fresh_X()
local F = fusion()
local nvar = 0
for _, r in ipairs(X3.recipes) do if r.variant_of then nvar = nvar + 1 end end
check(F.x3 and #F.x3.added.items == #X3.items, "fusion faite : " .. #X3.items .. " objets, " .. #X3.buildings .. " bâtiments, " .. #X3.recipes
  .. " recettes (dont " .. nvar .. " variantes), " .. #X3.technologies .. " technologies, " .. #X3.resources .. " ressources ajoutés ; " .. #X3.retouches .. " retouche(s), "
  .. #X3.extends .. " extensions")
check(X3.VERSION == 2 and #X3.retouches == 0, "version 2 : règle « des voies, jamais une porte » (X3.retouches vide)")
do -- X seul ne contient rien d'X3 ; la copie de require reste intacte.
  local names = {}
  for _, coll in ipairs({ "items", "buildings", "recipes", "technologies", "resources" }) do
    for _, e in ipairs(X3[coll]) do names[#names + 1] = { coll, e.name } end
  end
  local leaked = {}
  for _, pair in ipairs(names) do
    for _, e in ipairs(X0[pair[1]]) do if e.name == pair[2] then leaked[#leaked + 1] = pair[2] end end
  end
  check(#leaked == 0, "X seul (shared/content/epochs.lua) ne contient aucun nom d'X3 : " .. table.concat(leaked, ", "))
  local req = require("shared.content.epochs")
  check(req.x3 == nil and #req.items == #X0.items and #req.recipes == #X0.recipes, "le module de require (lu par le jeu) n'est pas touché par la fusion")
  check(#F.items == #X0.items + #X3.items and #F.recipes == #X0.recipes + #X3.recipes and #F.technologies == #X0.technologies + #X3.technologies,
    "additions en FIN de liste : X0 garde ses " .. #X0.items .. " objets et " .. #X0.recipes .. " recettes en tête")
  local same_head, same_body = true, true
  for i, r in ipairs(X0.recipes) do
    local fr_ = F.recipes[i]
    if fr_.name ~= r.name then same_head = false end
    for _, f in ipairs({ "ingredients", "results" }) do
      local a, b = {}, {}
      for _, e in ipairs(r[f]) do a[#a + 1] = e[1] .. "×" .. e[2] end
      for _, e in ipairs(fr_[f]) do b[#b + 1] = e[1] .. "×" .. e[2] end
      if table.concat(a, ",") ~= table.concat(b, ",") then same_body = false end
    end
    if r.category ~= fr_.category or r.time ~= fr_.time then same_body = false end
  end
  check(same_head, "ordre des recettes d'X0 inchangé dans la fusion")
  check(same_body, "les " .. #X0.recipes .. " recettes d'X0 sont identiques dans la fusion (ingrédients, produits, catégorie, durée)")
end
do -- listes et poids recopiés d'epochs.lua (locales là-bas) : aucune dérive.
  local galena, ilmenite
  for _, r in ipairs(X0.recipes) do
    if r.name == "fo-mine-galena" then galena = r end
    if r.name == "fo-mine-ilmenite" then ilmenite = r end
  end
  check(table.concat(galena.machines, ",") == table.concat(X3.DRILLS, ","), "X3.DRILLS = foreuses d'X0 (minage de la galène)")
  check(table.concat(ilmenite.machines, ",") == table.concat(X3.HARD_DRILLS, ","), "X3.HARD_DRILLS = foreuses dures d'X0 (minage de l'ilménite)")
  local drift = {}
  for _, t in ipairs(X0.technologies) do
    local c = { epoch = t.epoch, role = t.role, branch = t.branch, level = t.level }
    X3.tech_cost(X0, c)
    if c.units ~= t.units or table.concat(c.packs, ",") ~= table.concat(t.packs, ",") then drift[#drift + 1] = t.name end
  end
  check(#drift == 0, "X3.TECH_WEIGHT et X3.tech_cost redonnent unités et packs de toutes les technologies d'X0 : " .. table.concat(drift, ", "))
end
do -- aucun fichier du jeu ne lit x3.lua (fichiers suivis par git).
  local p = io.popen("git ls-files")
  local files = {}
  if p then for l in p:lines() do files[#files + 1] = l end p:close() end
  if #files == 0 then
    print("   AVIS : git ls-files indisponible ; lecture de x3.lua par le jeu non contrôlée")
  else
    local readers = {}
    local game = function(f)
      return f:match("%.lua$") and not f:match("^tests/") and not f:match("^tools/") and f ~= "shared/content/x3.lua"
    end
    for _, f in ipairs(files) do
      if game(f) then
        local h = io.open(f, "rb")
        if h then
          local s = h:read("*a"); h:close()
          if s:find("content%.x3") or s:find("content/x3") then readers[#readers + 1] = f end
        end
      end
    end
    -- Piste ÉTAIN (AMELIO-RESSOURCES, 30/10) : la cassitérite et la carte imprimée sont EN JEU ; seuls la garantie (ressource
    -- de X3) et le module de l'étain lisent x3.lua (comme le jeu lit epochs.lua). Tout autre lecteur reste refusé.
    local allowed = { ["shared/content/guarantee.lua"] = true, ["shared/content/tin.lua"] = true, ["shared/content/bauxite.lua"] = true }
    local other = {}
    for _, f in ipairs(readers) do if not allowed[f] then other[#other + 1] = f end end
    check(#other == 0, "aucun fichier du jeu (hors tests/, tools/, garantie et étain) ne lit shared/content/x3.lua : " .. table.concat(other, ", "))
  end
end

---------------------------------------------------------------------------------------------------
section("Contrôles propres sur la fusion")
---------------------------------------------------------------------------------------------------
local g = build(F)
local g0 = build(X0)
local col = run_checks(F, g, X0)
for _, f in ipairs(col.fails) do check(false, f) end
check(#col.fails == 0, string.format("contrôles propres : %d OK, %d échec(s) (fermeture, moteur, usage, usage à l'âge, sous-produits, orphelines, prérequis, déblocage strict, recherche, cerveau, placement, règle, variantes, titane)", col.ok, #col.fails))
passes = passes + col.ok
for _, m in ipairs(col.x0_deblocage) do print("   fusion : " .. m) end
check(#col.x0_deblocage == 0, "fusion ENTIÈRE (X0 compris) : aucun objet requis avant son déblocage (" .. #col.x0_deblocage .. " écart(s))")
local col0 = run_checks(X0, g0, nil)
if #col0.x0_deblocage > 0 then
  info(string.format("AVIS : sur X0 seul, %d recette(s) demandent un objet du même âge hors de leur technologie et de ses prérequis (réparé dans la fusion par X3.extends) :", #col0.x0_deblocage))
  for _, m in ipairs(col0.x0_deblocage) do info("  " .. m) end
end
check(#col0.fails == 0 or (function() for _, f in ipairs(col0.fails) do print("   X0 : " .. f) end return false end)(),
  string.format("les mêmes contrôles sur X0 seul : %d OK, %d échec(s)", col0.ok, #col0.fails))

---------------------------------------------------------------------------------------------------
section("Placement des ressources (jeux de gisements propres, H-X3-4)")
---------------------------------------------------------------------------------------------------
for _, r in ipairs(X3.resources) do
  local pl = r.placement
  local ps = pl.patch_set
  info(string.format("%-16s âge %2d : %s%s ; garantie %d × à %d-%d tuiles", r.name, r.epoch, pl.autoplace,
    ps and string.format(" (seed1 %d, région seed1 %d, seuil %s, échelle 1/%d%s%s%s)", ps.seed1, ps.region.seed1, tostring(ps.region.threshold),
      math.floor(1 / ps.region.scale + 0.5), ps.region.moisture_max and (", humidité ≤ " .. ps.region.moisture_max) or "",
      ps.region.aux_min and (", aux ≥ " .. ps.region.aux_min) or "", ps.region.elevation_max and (", élévation ≤ " .. ps.region.elevation_max) or "") or "",
    pl.guaranteed.count, pl.guaranteed.distance[1], pl.guaranteed.distance[2]))
end
do
  local x0_vl = {}
  for _, r in ipairs(X0.resources) do if r.placement and r.placement.autoplace == "vanilla-like" then x0_vl[#x0_vl + 1] = r.name .. " (âge " .. r.epoch .. ")" end end
  if #x0_vl > 0 then info("AVIS (défaut d'X0, hors X3) : autoplace « vanilla-like » dans X0 aussi : " .. table.concat(x0_vl, ", ") .. " ; même correction à son intégration") end
end

---------------------------------------------------------------------------------------------------
section("Complexité concentrée (« un peu plus de complexité à certains endroits »)")
---------------------------------------------------------------------------------------------------
do
  local per = {}
  for k = 1, 15 do per[k] = { items = 0, recipes = 0, buildings = 0, res = 0, all_res = 0 } end
  for _, it in ipairs(X3.items) do per[it.epoch].items = per[it.epoch].items + 1 end
  for _, r in ipairs(X3.recipes) do if not PSEUDO[r.kind] then per[r.epoch].recipes = per[r.epoch].recipes + 1 end end
  for _, b in ipairs(X3.buildings) do per[b.epoch].buildings = per[b.epoch].buildings + 1 end
  for _, r in ipairs(X3.resources) do per[r.epoch].res = per[r.epoch].res + 1 end
  for _, r in ipairs(F.resources) do per[r.epoch].all_res = per[r.epoch].all_res + 1 end
  for _, r in ipairs(F.base_resources) do if per[r.epoch] then per[r.epoch].all_res = per[r.epoch].all_res + 1 end end
  local heavy, empty, row, rrow = 0, 0, {}, {}
  for k = 1, 15 do
    if per[k].items >= 5 then heavy = heavy + 1 end
    if per[k].items == 0 and per[k].buildings == 0 then empty = empty + 1 end
    check(per[k].res <= 1, "âge " .. k .. " : au plus 1 ressource nouvelle d'X3 (" .. per[k].res .. ")")
    if per[k].res > 0 then check(per[k].all_res <= 2, "âge " .. k .. " : au plus 2 ressources de l'âge sur la FUSION, X0 compris (" .. per[k].all_res .. ")") end
    row[#row + 1] = string.format("%d:%d/%d/%d/%d", k, per[k].res, per[k].items, per[k].recipes, per[k].buildings)
    rrow[#rrow + 1] = string.format("%d:%d", k, per[k].all_res)
  end
  info("par âge, ressources/objets/recettes/bâtiments ajoutés : " .. table.concat(row, " "))
  info("ressources de l'âge sur la fusion (X0 et vanilla re-rangée comprises) : " .. table.concat(rrow, " "))
  check(heavy <= 3, "au plus 3 âges reçoivent 5 objets nouveaux ou plus (" .. heavy .. ")")
  check(empty >= 7, "au moins 7 âges ne reçoivent ni objet ni bâtiment (" .. empty .. ")")
  local x0r, fr_ = 0, 0
  for _, r in ipairs(X0.recipes) do if not PSEUDO[r.kind] and r.kind ~= "sink" then x0r = x0r + 1 end end
  for _, r in ipairs(F.recipes) do if not PSEUDO[r.kind] and r.kind ~= "sink" then fr_ = fr_ + 1 end end
  info(string.format("volume : objets %d → %d, bâtiments %d → %d, recettes réelles %d → %d (dont %d variantes), technologies %d → %d, ressources %d → %d ; %d recette(s) X0 retouchée(s)",
    #X0.items, #F.items, #X0.buildings, #F.buildings, x0r, fr_, nvar, #X0.technologies, #F.technologies, #X0.resources, #F.resources, #F.x3.retouched))
  local cats = {}
  for _, b in ipairs(X3.buildings) do for _, c in ipairs(b.categories) do cats[#cats + 1] = c end end
  local controls = 0
  for _, r in ipairs(X3.resources) do if r.placement.patch_set then controls = controls + 1 end end
  info(string.format("hors du compte d'epochs_test (VOL) : %d catégories de recette, %d contrôles d'autoplace, 2 entités combat-robot (drones laser et de garde), 1 unité (robot de combat), 3 projectiles de capsule (et leurs effets)",
    #cats, controls))
end

---------------------------------------------------------------------------------------------------
section("Valeurs : MU, énergie et temps-machine (voie d'X0 contre variantes), monnaies")
---------------------------------------------------------------------------------------------------
local muF, bestF = mu_map(F, g)
local mu0 = mu_map(X0, g0)
do
  local E = energy_fn(F, g, muF, bestF)
  info("variante          | objet               | MU variante / X0 | MJ variante / X0 | temps-machine (s) variante / X0 | X0 = voie")
  for _, r in ipairs(F.recipes) do
    if r.variant_of and scope_of(F).added_recipes[r.name] then
      local item = r.variant_of
      local best0, m0 = nil, INF
      for _, pr in ipairs(g.producers[item] or {}) do
        if not scope_of(F).added_recipes[pr.name] and not pr.barrel and not PSEUDO[pr.kind] then
          local m = E.unit_mu(pr, item)
          if m < m0 then best0, m0 = pr, m end
        end
      end
      if best0 then
        local mv = E.unit_mu(r, item)
        local ev, e0 = E.per_unit(r, item), E.per_unit(best0, item)
        info(string.format("%-17s | %-19s | %s / %s | %s / %s | %s / %s | %s", r.name, item, fr(mv, 2), fr(m0, 2), fr(ev[1], 1), fr(e0[1], 1), fr(ev[2], 1), fr(e0[2], 1), best0.name))
        check(not (mv < m0 - 1e-9 and ev[1] > e0[1] and ev[2] > e0[2]),
          string.format("%s : pas moins chère en MU (%s contre %s) ET plus chère en énergie (%s contre %s MJ) et en temps-machine (%s contre %s s) que la voie d'X0 (%s)",
            r.name, fr(mv, 2), fr(m0, 2), fr(ev[1], 1), fr(e0[1], 1), fr(ev[2], 1), fr(e0[2], 1), best0.name))
      end
    end
  end
  for _, n in ipairs({ "processing-unit", "fo-graphics-card", "fo-guidance-core", "fo-combat-robot", "fo-laser-drone-capsule", "fo-guard-drone-capsule" }) do
    local e = E.cost(n)
    info(string.format("%-22s : %s MU, %s MJ, %s s de machine (chemin le moins cher en MU ; le calcul vaut 0 MU, son énergie est comptée ici)", n, fr(muF[n] or INF, 1), fr(e[1], 1), fr(e[2], 1)))
  end
  for k = 2, F.EPOCHS do
    local c = F.currency_of(k)
    if c and muF[c.item] and mu0[c.item] then
      local rF, r0 = c.value / muF[c.item], c.value / mu0[c.item]
      check(rF <= 1.15 * r0 + 1e-9, string.format("âge %d : la monnaie %s vaut %s × son coût sur la fusion, contre %s × dans X0 (au plus 1,15 fois plus)", k, c.item, fr(rF, 2), fr(r0, 2)))
      if math.abs(rF - r0) > 0.005 then info(string.format("monnaie de l'âge %d (%s, %g MU) : %s × son coût (X0 : %s ×)", k, c.item, c.value, fr(rF, 2), fr(r0, 2))) end
    end
  end
end

---------------------------------------------------------------------------------------------------
section("Cerveau général : profondeur des chaînes et dépliage par shared/ai3/graphe.lua")
---------------------------------------------------------------------------------------------------
local LIM = math.floor(0.9 * G.MAX_NODES)
do
  local dF = depth_map(g, 15)
  local d0 = depth_map(g0, 15)
  local maxF, maxF_item, max0 = 0, "?", 0
  for _, n in ipairs(sorted_keys(dF)) do if dF[n] > maxF then maxF, maxF_item = dF[n], n end end
  for _, n in ipairs(sorted_keys(d0)) do if d0[n] > max0 then max0 = d0[n] end end
  info(string.format("profondeur maximale d'une chaîne (recettes depuis les ressources) : X0 %d, fusion %d (%s)", max0, maxF, maxF_item))
  check(maxF < G.MAX_PASSES, string.format("profondeur maximale %d < %d passes de faisabilité du cerveau (G.MAX_PASSES)", maxF, G.MAX_PASSES))
  for _, it in ipairs(X3.items) do check(dF[it.name] ~= nil, it.name .. " : profondeur finie (atteignable par le cerveau)") end
end

-- (a) Tout débloqué, toutes ressources connues, rien de construit (mesure de la PRODUCTION seule, version 1).
-- Référence du cerveau : X0 RÉPARÉ (ses trois prérequis manquants, X3.repairs_only), pour ne pas compter au débit
-- des chaînes d'X3 les recherches que les réparations ajoutent aux âges 4 et 14.
local X0r = X3.merge(fresh_X(), X3.repairs_only(X3))
local g0r = build(X0r)
local WbF, Wb0 = brain_world(F, g, true), brain_world(X0r, g0r, true)
do
  local WfF, Wf0 = brain_world(F, g, false), brain_world(X0, g0, false)
  local stF, pF = brain_state(WfF, 15, { techs_all = true, res_all = true })
  local st0, p0 = brain_state(Wf0, 15, { techs_all = true, res_all = true })
  check(pF.passes < G.MAX_PASSES, string.format("faisabilité du cerveau sur la fusion en %d passes (< %d)", pF.passes, G.MAX_PASSES))
  info(string.format("(a) tout débloqué, rien de construit : passes de faisabilité X0 %d, fusion %d ; nœuds de « 1 pack » par âge, X0 → fusion :", p0.passes, pF.passes))
  local row = {}
  for k = 1, 15 do
    local p = F.epochs[k].pack
    local a = unf(Wf0, st0, p0, { { item = p, n = 1 } })
    local b = unf(WfF, stF, pF, { { item = p, n = 1 } })
    row[#row + 1] = string.format("%d:%d→%d%s", k, a.nodes, b.nodes, b.truncated and "!" or "")
    check(not b.truncated or a.truncated, "(a) pack " .. k .. " : X3 n'ajoute aucun dépassement de " .. G.MAX_NODES .. " nœuds (" .. b.nodes .. ")")
    check(b.payable or not a.payable, "(a) pack " .. k .. " : payable sur la fusion s'il l'est sur X0")
  end
  info("    " .. table.concat(row, " "))
end

-- (b) Âges bornés AVEC les technologies : à l'âge k, technologies des âges < k recherchées, ressources ≤ k connues.
local X3_RES = {}
for _, r in ipairs(X3.resources) do for _, p in ipairs(r.products) do X3_RES[p] = true end end
do
  local by_age_F, by_age_0 = {}, {}
  for _, t in ipairs(F.technologies) do by_age_F[t.epoch] = by_age_F[t.epoch] or {}; table.insert(by_age_F[t.epoch], t.name) end
  for _, t in ipairs(X0r.technologies) do by_age_0[t.epoch] = by_age_0[t.epoch] or {}; table.insert(by_age_0[t.epoch], t.name) end
  local x3_tech = set_of(F.x3.added.technologies)
  info("(b) âges bornés : technologies < k recherchées, ressources ≤ k connues, rien de construit ; nœuds X0 réparé → fusion")
  info("    âge | technologie la plus lourde (nœuds) | 4 plus lourdes ensemble | payables X0 / fusion")
  local worst_single, worst_name, worst_four = 0, "?", 0
  for k = 1, 15 do
    local stF, pF = brain_state(WbF, k)
    local st0, p0 = brain_state(Wb0, k)
    local resF, res0 = {}, {}
    local maxF, maxFn, max0, max0n, payF, pay0 = 0, "?", 0, "?", 0, 0
    for _, tn in ipairs(by_age_0[k] or {}) do
      local r = unf(Wb0, st0, p0, { { tech = tn } })
      res0[tn] = r
      if r.payable then pay0 = pay0 + 1 end
      if r.nodes > max0 then max0, max0n = r.nodes, tn end
    end
    for _, tn in ipairs(by_age_F[k] or {}) do
      local r = unf(WbF, stF, pF, { { tech = tn } })
      resF[tn] = r
      if r.payable then payF = payF + 1 end
      if r.nodes > maxF then maxF, maxFn = r.nodes, tn end
      local a = res0[tn]
      if a then
        check(r.payable or not a.payable, string.format("(b) âge %d, %s : payable sur la fusion s'il l'est sur X0", k, tn))
        check(not r.truncated or a.truncated, string.format("(b) âge %d, %s : aucune troncature nouvelle (%d nœuds)", k, tn, r.nodes))
        local lim = LIM
        if a.nodes > LIM then lim = math.floor(a.nodes * 1.05) end
        check(r.nodes <= lim, string.format("(b) âge %d, %s : %d nœuds ≤ %d (0,9 × %d, ou X0 + 5 %%)", k, tn, r.nodes, lim, G.MAX_NODES))
      else
        check(x3_tech[tn] and r.payable and not r.truncated and r.nodes <= LIM,
          string.format("(b) âge %d, %s (X3) : payable à son âge, %d nœuds ≤ %d", k, tn, r.nodes, LIM))
      end
    end
    -- Lookahead du cerveau général (lot IA-G : but courant + 3 d'avance) : les 4 technologies les plus lourdes ensemble.
    local function four(list, res, Wb, st, p)
      local names = {}
      for _, tn in ipairs(list or {}) do names[#names + 1] = tn end
      table.sort(names, function(a, b) if res[a].nodes ~= res[b].nodes then return res[a].nodes > res[b].nodes end return a < b end)
      local goals = {}
      for i = 1, math.min(4, #names) do goals[#goals + 1] = { tech = names[i] } end
      if #goals == 0 then return { nodes = 0, truncated = false } end
      return unf(Wb, st, p, goals)
    end
    local f0, fF = four(by_age_0[k], res0, Wb0, st0, p0), four(by_age_F[k], resF, WbF, stF, pF)
    check(not fF.truncated or f0.truncated, string.format("(b) âge %d : 4 technologies ensemble sans troncature nouvelle (%d nœuds, X0 %d)", k, fF.nodes, f0.nodes))
    info(string.format("    %3d | %d → %d (%s) | %d%s → %d%s | %d/%d → %d/%d", k, max0, maxF, maxFn, f0.nodes, f0.truncated and " TRONQUÉ" or "",
      fF.nodes, fF.truncated and " TRONQUÉ" or "", pay0, #(by_age_0[k] or {}), payF, #(by_age_F[k] or {})))
    if maxF > worst_single then worst_single, worst_name = maxF, maxFn .. " (âge " .. k .. ")" end
    if fF.nodes > worst_four then worst_four = fF.nodes end
  end
  info(string.format("    plus lourd : %d nœuds (%s), soit %d %% de G.MAX_NODES ; 4 ensemble : %d nœuds au plus", worst_single, worst_name,
    math.floor(100 * worst_single / G.MAX_NODES + 0.5), worst_four))

  -- Cibles des chaînes et technologies d'X3 à LEUR âge (les recherches d'avant comprises dans le dépliage).
  for _, ch in ipairs(X3.chains) do
    local k = g.idx.item[ch.target].epoch
    local st, p = brain_state(WbF, k)
    local r = unf(WbF, st, p, { { item = ch.target, n = 1 } })
    local nres = 0
    for _, s in ipairs(r.steps) do if s.kind == "research" then nres = nres + 1 end end
    check(r.payable and not r.truncated and r.nodes <= LIM, string.format("(b) chaîne %s : %s à l'âge %d payable, %d nœuds ≤ %d (%d recherches dépliées)", ch.key, ch.target, k, r.nodes, LIM, nres))
    info(string.format("    chaîne %s « %s » → %s à l'âge %d : %d nœuds, %d recherches, %s", ch.key, ch.fr, ch.target, k, r.nodes, nres, r.payable and "payable" or "NON payable"))
  end

  -- (c) AUCUNE PORTE : ressources d'X3 inconnues ; tout ce qui est payable dans X0 l'est dans la fusion, sans explorer
  -- une ressource d'X3 (technologies de l'âge, pack, Codex).
  local gates, explored, total = 0, 0, 0
  for k = 1, 15 do
    local stU, pU = brain_state(WbF, k, { unknown = X3_RES })
    local st0, p0 = brain_state(Wb0, k)
    local goals = {}
    for _, tn in ipairs(by_age_0[k] or {}) do goals[#goals + 1] = { label = tn, goal = { tech = tn } } end
    goals[#goals + 1] = { label = "pack " .. F.epochs[k].pack, goal = { item = F.epochs[k].pack, n = 1 } }
    if k <= 14 then goals[#goals + 1] = { label = "fo-codex-" .. k, goal = { item = "fo-codex-" .. k, n = 1 } } end
    for _, gl in ipairs(goals) do
      local a = unf(Wb0, st0, p0, { gl.goal })
      local b = unf(WbF, stU, pU, { gl.goal })
      local ex = {}
      for _, s in ipairs(b.steps) do if s.kind == "explore" and X3_RES[s.name] then ex[#ex + 1] = s.name end end
      total = total + 1
      if not (b.payable or not a.payable) then gates = gates + 1 end
      if #ex > 0 then explored = explored + 1 end
      check(b.payable or not a.payable, string.format("(c) âge %d, %s : payable SANS les ressources d'X3 s'il l'est dans X0 (aucune porte)", k, gl.label))
      check(#ex == 0, string.format("(c) âge %d, %s : aucune exploration d'une ressource d'X3 (%s)", k, gl.label, table.concat(ex, ", ")))
    end
  end
  info(string.format("(c) aucune porte : %d buts d'X0 (technologies, packs, Codex), %d deviennent impayables sans les ressources d'X3, %d demandent de les explorer", total, gates, explored))

  -- (d) Rien de recherché (signalé, pas exigé : aucune faction n'est dans cet état passé l'âge 1).
  local stF, pF = brain_state(WbF, 15, { res_all = true })
  local st0, p0 = brain_state(Wb0, 15, { res_all = true })
  local row = {}
  for k = 1, 15 do
    local p = F.epochs[k].pack
    local a = unf(Wb0, st0, p0, { { item = p, n = 1 } }) -- X0 réparé
    local b = unf(WbF, stF, pF, { { item = p, n = 1 } })
    row[#row + 1] = string.format("%d:%d%s→%d%s", k, a.nodes, a.truncated and "!" or "", b.nodes, b.truncated and "!" or "")
    if b.truncated and not a.truncated then info("AVIS : (d) pack " .. k .. " tronqué sur la fusion et pas sur X0, rien de recherché") end
  end
  info("(d) rien de recherché, toutes ressources connues : nœuds de « 1 pack », X0 → fusion (! = tronqué) : " .. table.concat(row, " "))

  -- (e) Voie du cerveau (tout recherché, tout connu, tout construit) : MU des packs sur les recettes qu'il choisit,
  -- rapportées au chemin le moins cher (celui qui fixe le calendrier). Comparé à X0 réparé : X3 ne doit pas creuser
  -- l'écart de plus de 5 % (X0 lui-même s'en écarte : défaut du coût de choix, signalé au lot IA-G).
  local stA, pA = brain_state(WbF, 15, { techs_all = true, res_all = true, built = true })
  local st0A, p0A = brain_state(Wb0, 15, { techs_all = true, res_all = true, built = true })
  local mu0r = mu_map(X0r, g0r)
  local chosen_x3 = {}
  local x3r = scope_of(F).added_recipes
  local row2 = {}
  local function brain_ratio(Wb, st, p, D, gD, muD, pk, mark)
    local r = unf(Wb, st, p, { { item = pk, n = 1 } })
    local choice = {}
    for _, s in ipairs(r.steps) do
      if (s.kind == "produce" or s.kind == "hand") and s.item then
        choice[s.item] = choice[s.item] or s.name
        if mark and x3r[s.name] then chosen_x3[s.name] = true end
      end
    end
    local muB = mu_map(D, gD, function(rr, prod) return choice[prod] == nil or choice[prod] == rr.name end)
    return (muB[pk] or INF) / muD[pk], muB[pk] or INF
  end
  local worst, worst0 = 0, 0
  for k = 1, 15 do
    local p = F.epochs[k].pack
    local ratio, mub = brain_ratio(WbF, stA, pA, F, g, muF, p, true)
    local ratio0 = brain_ratio(Wb0, st0A, p0A, X0r, g0r, mu0r, p, false)
    if ratio > worst then worst = ratio end
    if ratio0 > worst0 then worst0 = ratio0 end
    row2[#row2 + 1] = string.format("%d:%s/%s", k, fr(ratio0, 3), fr(ratio, 3))
    check(ratio <= ratio0 * 1.05 + 1e-9, string.format("(e) pack %d (%s) : voie du cerveau à %s × le chemin le moins cher (%s MU) sur la fusion, contre %s × dans X0 réparé (au plus +5 %%)",
      k, p, fr(ratio, 3), fr(mub, 1), fr(ratio0, 3)))
  end
  info("(e) voie du cerveau / chemin le moins cher, MU des packs, X0 réparé / fusion : " .. table.concat(row2, " "))
  info(string.format("(e) AVIS (lot IA-G) : dans X0 seul, la voie du cerveau s'écarte déjà du chemin le moins cher jusqu'à %s × (coût de choix = secondes et quantités, pas MU ni énergie ; catalyseurs non soustraits)", fr(worst0, 2)))
  info("(e) variantes d'X3 choisies par le cerveau pour les packs (tout construit) : " .. (next(chosen_x3) and table.concat(sorted_keys(chosen_x3), ", ") or "aucune"))
  -- Choix de chaque variante isolée (tout construit) : quelle voie le cerveau prend-il pour l'objet ?
  local picks = {}
  for _, rr in ipairs(X3.recipes) do
    if rr.variant_of then
      local r = unf(WbF, stA, pA, { { item = rr.variant_of, n = 1 } })
      local pick
      for _, s in ipairs(r.steps) do if s.item == rr.variant_of and (s.kind == "produce" or s.kind == "hand") then pick = s.name end end
      picks[#picks + 1] = rr.variant_of .. " → " .. tostring(pick) .. (pick == rr.name and " (variante)" or "")
    end
  end
  info("(e) voie choisie par le cerveau, objet par objet (tout construit) : " .. table.concat(picks, " ; "))
end

---------------------------------------------------------------------------------------------------
section("Mutants (chacun doit être refusé ; voie complète : aussi par epochs_test sur leur fusion)")
---------------------------------------------------------------------------------------------------
local eF_base -- échecs d'epochs_test sur la fusion de référence (blocs GEN seulement), rempli plus bas si besoin
local function epochs_extra_fails(Fm)
  local res = run_bench("tests/epochs_test.lua", Fm)
  local out = {}
  for _, l in ipairs(res.fails) do if not l:find(GEN_PAT) then out[#out + 1] = l end end
  if res.crashed then out[#out + 1] = "PLANTAGE : " .. tostring(res.err) end
  return out
end
do
  local function rec(d, name) for _, r in ipairs(d.recipes) do if r.name == name then return r end end end
  local function tech(d, name) for _, t in ipairs(d.technologies) do if t.name == name then return t end end end
  local function res_(d, name) for _, r in ipairs(d.resources) do if r.name == name then return r end end end
  local function bld(d, name) for _, b in ipairs(d.buildings) do if b.name == name then return b end end end
  local function item(d, name) for _, i in ipairs(d.items) do if i.name == name then return i end end end
  local function remove(list, pred) for i = #list, 1, -1 do if pred(list[i]) then table.remove(list, i) end end end
  local function drop_recipe(d, name)
    remove(d.recipes, function(r) return r.name == name end)
    for _, t in ipairs(d.technologies) do remove(t.unlocks, function(n) return n == name end) end
  end
  local MUTANTS = {
    { "recette cassée : ingrédient inconnu", "inconnu", function(d)
        rec(d, "fo-etched-wafer").ingredients[3][1] = "fo-photoresist-inexistant" end },
    { "recette cassée : anachronisme (aluminium de l'âge 6 dans la carte imprimée de l'âge 4)", "fermeture", function(d)
        table.insert(rec(d, "fo-printed-circuit-board").ingredients, { "fo-aluminium-plate", 1 }) end },
    { "recette cassée : cycle sans issue (creuset fait de lingots)", "fermeture", function(d)
        rec(d, "fo-quartz-crucible").ingredients = { { "fo-silicon-ingot", 1 } } end },
    { "sous-produit à un seul exutoire : boue rouge sans fer", "sous-produit", function(d) drop_recipe(d, "fo-red-mud-iron") end },
    { "objet sans usage : sous-produit nouveau jamais consommé", "usage", function(d)
        table.insert(d.items, { name = "fo-x3-mutant-dross", epoch = 3, fr = "Crasse", en = "Dross", type = "item", stack = 100 })
        table.insert(rec(d, "fo-zinc-retort").results, { "fo-x3-mutant-dross", 1 }) end },
    { "objet sans usage à son âge : drone laser sans servomoteur (servomoteur de l'âge 7 servi à l'âge 10)", "usage-age", function(d)
        remove(rec(d, "fo-laser-drone-capsule").ingredients, function(i) return i[1] == "fo-servo-motor" end) end },
    { "prérequis inversé : la fonderie exige le calcul, le calcul ne l'exige plus", "deblocage", function(d)
        tech(d, "fo-computing").prereq = {}
        tech(d, "fo-chip-foundry").prereq = { "fo-silicon", "fo-servo-mechanisms", "fo-computing" } end },
    { "prérequis en cycle : fonderie ↔ calcul", "prerequis", function(d)
        table.insert(tech(d, "fo-chip-foundry").prereq, "fo-computing") end },
    { "prérequis postérieur : circuits imprimés (4) après l'aluminium (6)", "prerequis", function(d)
        table.insert(tech(d, "fo-printed-circuits").prereq, "fo-aluminium") end },
    { "prérequis manquant entre âges : servomécanismes (7) sans l'aluminium (6)", "deblocage", function(d)
        tech(d, "fo-servo-mechanisms").prereq = { "fo-printed-circuits" } end },
    { "recette orpheline : module de mémoire débloqué par aucune technologie", "orpheline", function(d)
        remove(tech(d, "fo-chip-foundry").unlocks, function(n) return n == "fo-memory-module" end) end },
    { "garde du jeu : retouche d'une recette que le titane déplie (bobine)", "titane", function(d)
        table.insert(d.retouches, { recipe = "fo-coil", ingredients = { { "fo-enameled-wire", 4 }, { "fo-magnetic-steel", 2 }, { "fo-brass", 1 } } }) end },
    { "règle : retouche d'une recette d'X0 (10 cartes imprimées dans le Codex IV : une porte)", "regle", function(d)
        table.insert(d.retouches, { recipe = "fo-codex-4", ingredients = { { "plastic-bar", 20 }, { "advanced-circuit", 10 }, { "chemical-science-pack", 10 },
          { "fo-asphalt", 20 }, { "fo-printed-circuit-board", 10 } } }) end },
    { "règle : prérequis d'X3 sur une technologie de pack (pack magnétique ← aluminium)", "regle", function(d)
        table.insert(d.extends, { tech = "fo-magnetic-pack", prereq = { "fo-aluminium" } }) end },
    { "cycle de production : tranches sciées refaites de tranches gravées", "cerveau", function(d)
        table.insert(rec(d, "fo-wafer-sawing").ingredients, { "fo-etched-wafer", 1 }) end },
    { "placement : autoplace « vanilla-like » (blende)", "placement", function(d)
        local r = res_(d, "fo-sphalerite"); r.placement.autoplace = "vanilla-like"; r.placement.patch_set = nil end },
    { "placement : quartz autoplacé sur la plaine de cristal (masque partagé avec le cristal de résonance)", "placement", function(d)
        local r = res_(d, "fo-vein-quartz"); r.biome = "fo-crystal-flats"
        r.placement.autoplace = "fo-crystal-flats"; r.placement.patch_set = { seed1 = 7304, region = { seed1 = 7314, threshold = 0.5, scale = 1 / 260 } } end },
    { "placement : graine du cristal de résonance (7102, world.lua) reprise pour la bauxite", "placement", function(d)
        res_(d, "fo-bauxite").placement.patch_set.seed1 = 7102 end },
    { "bâtiment inutile (catégorie servie par aucune recette)", "batiment", function(d)
        table.insert(d.buildings, { name = "fo-x3-useless", epoch = 4, fr = "Inutile", en = "Useless", proto = "assembling-machine",
          size = { 3, 3 }, energy = { type = "electric" }, kw = 100, speed = 1, categories = { "fo-x3-nothing" }, levels = { family = "assembler" } })
        table.insert(d.recipes, { name = "fo-x3-useless", epoch = 4, category = "crafting", time = 5, kind = "recipe",
          ingredients = { { "steel-plate", 5 } }, results = { { "fo-x3-useless", 1 } } })
        table.insert(tech(d, "fo-printed-circuits").unlocks, "fo-x3-useless") end },
    { "boîte à fluide manquante (atelier de robotique sans entrée : le calcul n'entre pas)", "moteur", function(d)
        bld(d, "fo-robotics-bay").fluid_in = nil end },
    { "four à deux entrées (étain au four avec du charbon)", "moteur", function(d)
        table.insert(rec(d, "fo-tin-plate").ingredients, { "coal", 1 }) end },
    { "nom en double (un objet X3 « fo-glass », déjà dans X0)", "doublon", function(d)
        table.insert(d.items, { name = "fo-glass", epoch = 3, fr = "Verre bis", en = "Glass bis", type = "item", stack = 100 }) end },
    { "minage dur par les foreuses ordinaires (cassitérite en fo-hard-solid)", "moteur", function(d)
        res_(d, "fo-cassiterite").category = "fo-hard-solid" end },
    { "calcul mis en baril (contredit « sans baril »)", "baril", function(d) item(d, "fo-compute").barrel = true end },
    { "recherche effondrée (âge 4 : 7 unités)", "recherche", function(d) d.tech_units[4] = 7 end },
    { "recalage hors des âges d'X3 (âge 11 : 3 000 unités)", "recherche", function(d) d.tech_units[11] = 3000 end },
    { "dépendance d'une BRANCHE facultative d'un âge antérieur, sans prérequis (robot de combat)", "deblocage", function(d)
        local X = fresh_X()
        local tby, pick = {}, nil
        for _, t in ipairs(X.technologies) do for _, r in ipairs(t.unlocks) do tby[r] = t end end
        for _, r in ipairs(X.recipes) do
          local t = tby[r.name]
          if not pick and t and t.branch and t.epoch < 12 and r.kind == "recipe" and #r.results == 1 then
            for _, i in ipairs(X.items) do if not pick and i.name == r.results[1][1] and i.type == "item" then pick = i.name end end
          end
        end
        table.insert(rec(d, "fo-combat-robot").ingredients, { pick, 1 }) end },
    { "variante qui casse le calendrier : processeur gravé à 10 par fabrication", "epochs", function(d)
        rec(d, "fo-etched-processor").results = { { "processing-unit", 10 } } end },
  }
  local refused, judged = 0, 0
  for _, m in ipairs(MUTANTS) do
    local d = X3.deep_copy(X3)
    m[3](d)
    local ok, Fm = pcall(X3.merge, fresh_X(), d)
    if not ok then
      check(false, "mutant « " .. m[1] .. " » : la fusion a planté au lieu d'être refusée par un contrôle (" .. tostring(Fm) .. ")")
    else
      local cm = run_checks(Fm, build(Fm), X0)
      local kinds = table.concat(sorted_keys(cm.by_kind), ", ")
      local hit = (cm.by_kind[m[2]] or 0) > 0
      local ep = nil
      if not COURT then ep = epochs_extra_fails(Fm) end
      if m[2] == "epochs" then
        if COURT then
          info("mutant « " .. m[1] .. " » : jugé par epochs_test seulement (voie complète) ; non joué en --court")
        else
          judged = judged + 1
          if check(#ep > 0, "mutant refusé par epochs_test : " .. m[1] .. " (" .. #ep .. " échec(s))") then refused = refused + 1 end
          if #ep > 0 then info("   " .. ep[1]:gsub("^%s+", "")) end
        end
      else
        judged = judged + 1
        if check(hit, "mutant refusé : " .. m[1] .. " (attendu « " .. m[2] .. " », vu : " .. (kinds == "" and "rien" or kinds) .. ")") then refused = refused + 1 end
      end
      info(string.format("mutant « %s » : contrôles propres %d échec(s) [%s]%s", m[1], #cm.fails, kinds,
        ep and string.format(" ; epochs_test %d échec(s) hors blocs GEN", #ep) or ""))
    end
  end
  check(refused == judged and refused >= 3, string.format("%d mutants refusés sur %d jugés (%d au total)", refused, judged, #MUTANTS))
end

---------------------------------------------------------------------------------------------------
section("Bancs rejoués sur X seul et sur la fusion (le jeu ne bouge pas)")
---------------------------------------------------------------------------------------------------
if COURT then
  info("AVIS : --court, bancs non rejoués")
else
  local eX = run_bench("tests/epochs_test.lua", fresh_X())
  local eF = run_bench("tests/epochs_test.lua", fusion())
  local eN = run_bench("tests/epochs_test.lua", X3.merge(fresh_X(), X3.without_variants(X3)))
  check(not eX.crashed and eX.ko == 0, string.format("epochs_test sur X seul : %s OK, %s ECHEC(S)", tostring(eX.ok), tostring(eX.ko)))
  info(string.format("epochs_test sur X seul : %s OK, %s ECHEC(S)", tostring(eX.ok), tostring(eX.ko)))
  local other = {}
  for _, l in ipairs(eF.fails) do if not l:find(GEN_PAT) then other[#other + 1] = l end end
  check(not eF.crashed and eF.ok and #other == 0, string.format("epochs_test sur la fusion : %s OK, %s ECHEC(S), tous des blocs GEN de SCENARIO_EPOQUES.md (la doc décrit X seul) ; autres : %d",
    tostring(eF.ok), tostring(eF.ko), #other))
  info(string.format("epochs_test sur la fusion : %s OK, %s ECHEC(S), dont %d bloc(s) GEN de docs/SCENARIO_EPOQUES.md (la doc générée décrit X seul : attendu) et %d autre(s)",
    tostring(eF.ok), tostring(eF.ko), (eF.ko or 0) - #other, #other))
  for _, l in ipairs(other) do print("   fusion : " .. l) end
  check(eF.ok and eX.ok and eF.ok > eX.ok, "la fusion passe plus de contrôles d'epochs_test que X seul (" .. tostring(eF.ok) .. " > " .. tostring(eX.ok) .. ")")
  local px = find_line(eX.lines, "MU des packs par époque")
  local pf = find_line(eF.lines, "MU des packs par époque")
  if px and pf then info("X0     " .. px:gsub("^%s+", "")); info("fusion " .. pf:gsub("^%s+", "")) end
  if pf then -- le calcul des MU de ce banc suit celui d'epochs_test (même règle, même chemin).
    local same = true
    for k, v in pf:gmatch("(%d+):([%d%.]+)") do
      if math.abs(tonumber(v) - (muF[F.epochs[tonumber(k)].pack] or INF)) > 0.051 then same = false end
    end
    check(same, "MU des packs de ce banc = MU d'epochs_test sur la fusion (même règle)")
  end
  -- Part de la recherche : sur la fusion (variantes comprises) ET sur la voie d'X0 (fusion sans variantes : une faction
  -- qui n'a pas les ressources d'X3 garde la voie d'X0 et paie ses packs au prix d'X0).
  local sF, sN = research_shares(eF.lines), research_shares(eN.lines)
  local row = {}
  for k = 1, 15 do
    check(sF[k] and sF[k] >= 30 and sF[k] <= 40, string.format("âge %d : recherche %s %% du budget sur la fusion (30 à 40 %%)", k, tostring(sF[k])))
    check(sN[k] and sN[k] >= 30 and sN[k] <= 40, string.format("âge %d : recherche %s %% du budget sur la voie d'X0, sans les variantes (30 à 40 %%)", k, tostring(sN[k])))
    row[#row + 1] = string.format("%d:%s/%s", k, fr(sF[k] or -1, 1), fr(sN[k] or -1, 1))
  end
  info("part de la recherche (%), fusion / voie d'X0 sans variantes : " .. table.concat(row, " "))
  local vx = find_line(eX.lines, "prototypes nouveaux estimés")
  local vf = find_line(eF.lines, "prototypes nouveaux estimés")
  if vx and vf then
    local a, al = vx:match("estimés : (%d+) %(dont (%d+)")
    local b, bl = vf:match("estimés : (%d+) %(dont (%d+)")
    if a and b then info(string.format("volume estimé par epochs_test (VOL) : %s → %s prototypes (+%d), dont de niveau %s → %s (+%d)", a, b, tonumber(b) - tonumber(a), al, bl, tonumber(bl) - tonumber(al))) end
  end
  for _, b in ipairs({ "tests/titanium_test.lua", "tests/monde_test.lua", "tests/org_test.lua", "tests/levels_test.lua" }) do
    local rx = run_bench(b, fresh_X())
    local rf = run_bench(b, fusion())
    local same = #rx.fails == #rf.fails
    if same then for i = 1, #rx.fails do if rx.fails[i] ~= rf.fails[i] then same = false end end end
    local clean = rx.ko == 0
    if b == "tests/levels_test.lua" and not clean then
      local sheets = 0
      for _, l in ipairs(rx.fails) do if l:find("feuilles", 1, true) or l:find("FEUILLES", 1, true) or l:find("PNG", 1, true) or l:find("graphics/levels", 1, true) then sheets = sheets + 1 end end
      clean = sheets == rx.ko
      info(string.format("%s : %d échec(s) sur X seul, dus aux feuilles PNG absentes de ce dossier (D-6 : %d)", b, rx.ko or -1, sheets))
    end
    check(not rx.crashed and not rf.crashed and clean and rx.ok == rf.ok and rx.ko == rf.ko and same,
      string.format("%s : X seul %s OK / %s ECHEC, fusion %s OK / %s ECHEC (identiques, échecs compris)", b, tostring(rx.ok), tostring(rx.ko), tostring(rf.ok), tostring(rf.ko)))
    info(string.format("%s : X seul %s OK, %s ECHEC(S) ; fusion %s OK, %s ECHEC(S)", b, tostring(rx.ok), tostring(rx.ko), tostring(rf.ok), tostring(rf.ko)))
    if rx.crashed or rf.crashed then print("   " .. tostring(rx.err or rf.err)) end
  end
  info("NB : titanium, monde, org et levels ne lisent pas le contenu d'X3 (ils lisent X.rate_avg, X.budget, X.currency_of, X.resources par world.lua, L.epochs) : ils prouvent que la fusion ne casse rien de ce qu'ils lisent, pas plus")
end

print(string.format("\n[X3] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
