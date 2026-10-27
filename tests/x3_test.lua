--[[
  Lot X3 (27/10) : banc hors jeu du graphe réaliste et des minerais par âge (shared/content/x3.lua, PROPOSITION, pas en
  jeu). Usage, depuis la racine du mod ou d'un worktree : lua5.2 tests/x3_test.lua [--court]
    --court : sans les bancs rejoués (epochs, titanium, monde, org), contrôles propres et mutants seulement.

  Ce qu'il prouve, sur la FUSION X0 + X3 (X3.merge sur une copie fraîche d'epochs.lua) :
   1. jeu inchangé : X seul ne contient aucun nom d'X3, aucun fichier du jeu ne lit x3.lua, les retouches ne touchent
      aucune recette que shared/content/titanium.lua déplie et T.maker (première recette d'un objet) est identique ;
      epochs_test, titanium_test, monde_test et org_test rejoués sur X seul ET sur la fusion ;
   2. fermeture du graphe : tout objet, bâtiment et recette se fabrique depuis les ressources de son âge ou d'avant,
      disponible EXACTEMENT à son âge (ni avant, ni après) ; tout ingrédient connu ; une machine par catégorie ;
   3. aucun objet sans usage (un producteur ET un consommateur, ou un usage final) ;
   4. aucune recette orpheline : chaque recette réelle débloquée par exactement une technologie de son âge ;
   5. technologies cohérentes : prérequis déclarés, d'un âge antérieur ou égal, sans cycle ; un objet n'est jamais
      requis avant l'âge où il se débloque (un ingrédient du même âge vient de la technologie elle-même ou de ses
      prérequis, explicites ou implicites : la technologie du pack de l'âge) ;
   6. lisible par le cerveau général (shared/ai3/graphe.lua) : catégories servies, recettes à la main solides à produit
      unique, aucun cycle de production hors catalyse déclarée ; profondeur de chaîne (la faisabilité du cerveau fait
      64 passes au plus) et nœuds du dépliage d'un pack de chaque âge par G.unfold (4 000 nœuds au plus : tout
      dépassement est signalé) ;
   7. la complexité est concentrée : au plus 3 âges reçoivent 5 objets nouveaux ou plus, au plus 2 ressources par âge ;
   8. mutants refusés : recettes cassées (ingrédient inconnu, anachronisme, cycle sans issue), objets sans usage,
      prérequis inversé, en cycle ou postérieur, recette orpheline, retouche d'une recette du titane.
  Ce qu'il ne prouve pas : le moteur réel (aucun prototype n'existe), l'équilibrage en partie, les hypothèses
  H-X3-1 à H-X3-3 (moteur), la mémoire vidéo des futures images.
]]

package.path = "./?.lua;" .. package.path
local X3 = require("shared.content.x3")
local G = require("shared.ai3.graphe")
local A = require("shared.content.arsenal")
local Mo = require("shared.content.modules")
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
local function count_pairs(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

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

  local producers, consumers = {}, {}
  for _, r in ipairs(all) do
    for _, i in ipairs(r.ingredients) do consumers[i[1]] = (consumers[i[1]] or 0) + 1 end
    for _, p in ipairs(r.results) do producers[p[1]] = producers[p[1]] or {}; table.insert(producers[p[1]], r) end
  end
  g.producers, g.consumers = producers, consumers

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
  local s = { recipes = {}, items = {}, buildings = {}, techs = {}, resources = {} }
  for _, n in ipairs(x.added.recipes) do s.recipes[n] = true end
  for _, n in ipairs(x.retouched) do s.recipes[n] = true end
  for _, n in ipairs(x.added.items) do s.items[n] = true end
  for _, n in ipairs(x.added.buildings) do s.buildings[n] = true end
  for _, n in ipairs(x.added.technologies) do s.techs[n] = true end
  for _, n in ipairs(x.extended) do s.techs[n] = true end
  for _, n in ipairs(x.added.resources) do s.resources[n] = true end
  return s
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

  -- (3) Aucun objet sans usage.
  for _, it in ipairs(F.items) do
    c(g.producers[it.name] ~= nil, "usage", it.name .. " : a une recette ou une source")
    local sink = (g.consumers[it.name] or 0) > 0 or SINK_USES[it.use or ""] or it.counter_only
    c(sink, "usage", it.name .. " : consommé par une recette ou un usage final (" .. tostring(it.use) .. ")")
  end
  for _, b in ipairs(F.buildings) do c(g.producers[b.name] ~= nil, "usage", b.name .. " : bâtiment fabricable") end

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
      local r = g.idx.recipe[rn]
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
  local function obtainable(item, t, clos)
    local a = g.av(item)
    if a < t.epoch then return true end
    if a > t.epoch then return false end
    for _, r in ipairs(g.producers[item] or {}) do
      if g.recipe_avail(r) <= t.epoch then
        if r.base or r.barrel or PSEUDO[r.kind] or start[r.name] then return true end
        for _, tt in ipairs(g.unlocked_by[r.name] or {}) do if clos[tt.name] then return true end end
      end
    end
    return false
  end
  local x0_viol = {}
  for _, t in ipairs(F.technologies) do
    local clos = closure(t)
    for _, rn in ipairs(t.unlocks) do
      local r = g.idx.recipe[rn]
      if r then
        local bad = {}
        for _, i in ipairs(r.ingredients) do if not obtainable(i[1], t, clos) then bad[#bad + 1] = i[1] end end
        local mach_ok = false
        for _, m in ipairs(g.machines_of(r)) do
          if (g.machine_def[m] and g.machine_def[m].hand) or obtainable(m, t, clos) then mach_ok = true end
        end
        if not mach_ok then bad[#bad + 1] = "machine de « " .. tostring(r.category) .. " »" end
        local msg = rn .. " (" .. t.name .. ", âge " .. t.epoch .. ") : " .. table.concat(bad, ", ") .. " requis avant son déblocage (ni avant l'âge, ni par la technologie ou ses prérequis)"
        if sc.recipes[rn] or sc.techs[t.name] then c(#bad == 0, "deblocage", msg)
        elseif #bad > 0 then x0_viol[#x0_viol + 1] = msg end
      end
    end
  end
  col.x0_deblocage = x0_viol

  -- (6) Lisible par le cerveau général.
  for rn in pairs(sc.recipes) do
    local r = g.idx.recipe[rn]
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
  for n in pairs(sc.items) do
    local ok = false
    for _, r in ipairs(g.producers[n] or {}) do
      if r.kind == "recipe" or r.kind == "building" or r.kind == "mining" or r.base then ok = true end
    end
    c(ok, "cerveau", n .. " : produit par une recette ou un minage (aucune étape par script : lancement, merveille)")
  end
  -- Cycles de production : composantes fortement connexes (Tarjan) sur les objets, arcs « ingrédient → PRODUIT
  -- PRINCIPAL » (le premier), hors barils, hors catalyse déclarée (ingrédient = produit). Les boucles par sous-produit
  -- existent déjà dans X0 (uranium 238 de la vitrification, poudre de cristal de la mesure de phase...) : le cerveau
  -- les traverse par son point fixe de faisabilité ; une boucle par produits PRINCIPAUX ferait tourner son dépliage.
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

  -- (1) Garde du jeu : retouches hors des recettes du titane ; T.maker inchangé pour tout objet de X0.
  for _, n in ipairs((F.x3 or NO_X3).retouched) do
    c(not TITANIUM_READS[n], "titane", n .. " : la retouche ne vise aucune recette que titanium.lua lit ou déplie")
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
-- Spécification du cerveau général (shared/ai3/graphe.lua) tirée des données, comme en jeu des prototypes : recettes,
-- machines (catégories, énergie), ressources (minage, cueillette, butin), pseudo-recettes (chaleur, lancement,
-- combustion), électricité par la machine à vapeur. Technologies vides : tout est débloqué (mesure de la PRODUCTION).
---------------------------------------------------------------------------------------------------
local BASE_ENERGY = { ["stone-furnace"] = "burner", ["steel-furnace"] = "burner", ["burner-mining-drill"] = "burner", boiler = "burner",
  ["electric-furnace"] = "electric", ["assembling-machine-1"] = "electric", ["assembling-machine-2"] = "electric",
  ["assembling-machine-3"] = "electric", ["chemical-plant"] = "electric", ["oil-refinery"] = "electric", centrifuge = "electric",
  ["rocket-silo"] = "electric", ["electric-mining-drill"] = "electric", pumpjack = "electric" }
local function graphe_spec(F, g)
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
    elseif k == nil or k == "recipe" or k == "building" then
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
  return spec
end

local function brain_measure(F, g, goals_by_label)
  local spec = graphe_spec(F, g)
  local cat = G.new(spec)
  local known = {}
  for _, n in ipairs(sorted_keys(spec.resources)) do known[n] = true end
  local state = { stock = {}, techs = {}, built = {}, known = known }
  local prepared = G.prepare(cat, state)
  local out = { passes = prepared.passes }
  for _, e in ipairs(goals_by_label) do
    local res = G.unfold(cat, { { item = e.item, n = 1 } }, state, prepared)
    out[e.label] = { nodes = res.nodes, payable = res.payable, truncated = res.truncated, blocked = #res.blocked, steps = #res.steps }
  end
  return out
end

---------------------------------------------------------------------------------------------------
-- Bancs rejoués dans ce processus, sur X seul ou sur la fusion (module de X remplacé, sorties captées).
---------------------------------------------------------------------------------------------------
local function run_bench(path, Xmod)
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
  for k in pairs(package.loaded) do if k:find("^shared%.") then package.loaded[k] = nil end end
  for k, v in pairs(saved_loaded) do package.loaded[k] = v end
  local res = { lines = lines, crashed = not ok and err ~= EXIT, err = (err ~= EXIT) and err or nil, fails = {} }
  for _, l in ipairs(lines) do
    local o, f = l:match("Résultat : (%d+) OK, (%d+) ECHEC")
    if o then res.ok, res.ko = tonumber(o), tonumber(f) end
    if l:find("ECHEC :", 1, true) then res.fails[#res.fails + 1] = l end
  end
  return res
end
local function find_line(lines, pat) for _, l in ipairs(lines) do if l:find(pat) then return l end end return nil end

---------------------------------------------------------------------------------------------------
section("Données X3 et fusion")
---------------------------------------------------------------------------------------------------
local X0 = fresh_X()
local F = fusion()
check(F.x3 and #F.x3.added.items == #X3.items, "fusion faite : " .. #X3.items .. " objets, " .. #X3.buildings .. " bâtiments, " .. #X3.recipes
  .. " recettes, " .. #X3.technologies .. " technologies, " .. #X3.resources .. " ressources ajoutés ; " .. #X3.retouches .. " retouches, "
  .. #X3.extends .. " extensions")
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
  local same_head = true
  for i, r in ipairs(X0.recipes) do if F.recipes[i].name ~= r.name then same_head = false end end
  check(same_head, "ordre des recettes d'X0 inchangé dans la fusion")
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
    check(#readers == 0, "aucun fichier du jeu (hors tests/ et tools/) ne lit shared/content/x3.lua : " .. table.concat(readers, ", "))
  end
end

---------------------------------------------------------------------------------------------------
section("Contrôles propres sur la fusion")
---------------------------------------------------------------------------------------------------
local g = build(F)
local g0 = build(X0)
local col = run_checks(F, g, X0)
for _, f in ipairs(col.fails) do check(false, f) end
check(#col.fails == 0, string.format("contrôles propres : %d OK, %d échec(s) (fermeture, usage, orphelines, prérequis, déblocage, cerveau, titane)", col.ok, #col.fails))
passes = passes + col.ok
for _, m in ipairs(col.x0_deblocage) do print("   fusion : " .. m) end
check(#col.x0_deblocage == 0, "fusion ENTIÈRE (X0 compris) : aucun objet requis avant son déblocage (" .. #col.x0_deblocage .. " écart(s))")
local col0 = run_checks(X0, g0, nil)
if #col0.x0_deblocage > 0 then
  info(string.format("AVIS : sur X0 seul, %d recette(s) demandent un objet du même âge hors de leur technologie et de ses prérequis (réparé dans la fusion par X3.extends) :", #col0.x0_deblocage))
  for _, m in ipairs(col0.x0_deblocage) do info("  " .. m) end
end
-- La portée X3 est vide sur X0 seul : on n'y attend que les contrôles généraux, tous verts.
check(#col0.fails == 0 or (function() for _, f in ipairs(col0.fails) do print("   X0 : " .. f) end return false end)(),
  string.format("les mêmes contrôles sur X0 seul : %d OK, %d échec(s)", col0.ok, #col0.fails))

---------------------------------------------------------------------------------------------------
section("Complexité concentrée (« un peu plus de complexité à certains endroits »)")
---------------------------------------------------------------------------------------------------
do
  local per = {}
  for k = 1, 15 do per[k] = { items = 0, recipes = 0, buildings = 0, res = 0 } end
  for _, it in ipairs(X3.items) do per[it.epoch].items = per[it.epoch].items + 1 end
  for _, r in ipairs(X3.recipes) do if not PSEUDO[r.kind] then per[r.epoch].recipes = per[r.epoch].recipes + 1 end end
  for _, b in ipairs(X3.buildings) do per[b.epoch].buildings = per[b.epoch].buildings + 1 end
  for _, r in ipairs(X3.resources) do per[r.epoch].res = per[r.epoch].res + 1 end
  local heavy, empty, row = 0, 0, {}
  for k = 1, 15 do
    if per[k].items >= 5 then heavy = heavy + 1 end
    if per[k].items == 0 and per[k].buildings == 0 then empty = empty + 1 end
    check(per[k].res <= 2, "âge " .. k .. " : au plus 2 ressources nouvelles (" .. per[k].res .. ")")
    row[#row + 1] = string.format("%d:%d/%d/%d/%d", k, per[k].res, per[k].items, per[k].recipes, per[k].buildings)
  end
  info("par âge, ressources/objets/recettes/bâtiments ajoutés : " .. table.concat(row, " "))
  check(heavy <= 3, "au plus 3 âges reçoivent 5 objets nouveaux ou plus (" .. heavy .. ")")
  check(empty >= 7, "au moins 7 âges ne reçoivent ni objet ni bâtiment (" .. empty .. ")")
  local x0r, fr = 0, 0
  for _, r in ipairs(X0.recipes) do if not PSEUDO[r.kind] and r.kind ~= "sink" then x0r = x0r + 1 end end
  for _, r in ipairs(F.recipes) do if not PSEUDO[r.kind] and r.kind ~= "sink" then fr = fr + 1 end end
  info(string.format("volume : objets %d → %d, bâtiments %d → %d, recettes réelles %d → %d, technologies %d → %d, ressources %d → %d ; %d recettes X0 retouchées",
    #X0.items, #F.items, #X0.buildings, #F.buildings, x0r, fr, #X0.technologies, #F.technologies, #X0.resources, #F.resources, #F.x3.retouched))
end

---------------------------------------------------------------------------------------------------
section("Cerveau général : profondeur des chaînes et dépliage par shared/ai3/graphe.lua")
---------------------------------------------------------------------------------------------------
do
  local dF, nF = depth_map(g, 15)
  local d0 = depth_map(g0, 15)
  local maxF, maxF_item, max0 = 0, "?", 0
  for _, n in ipairs(sorted_keys(dF)) do if dF[n] > maxF then maxF, maxF_item = dF[n], n end end
  for _, n in ipairs(sorted_keys(d0)) do if d0[n] > max0 then max0 = d0[n] end end
  info(string.format("profondeur maximale d'une chaîne (recettes depuis les ressources) : X0 %d, fusion %d (%s)", max0, maxF, maxF_item))
  check(maxF < G.MAX_PASSES, string.format("profondeur maximale %d < %d passes de faisabilité du cerveau (G.MAX_PASSES)", maxF, G.MAX_PASSES))
  for _, it in ipairs(X3.items) do check(dF[it.name] ~= nil, it.name .. " : profondeur finie (atteignable par le cerveau)") end

  local goals = {}
  for k = 1, 15 do goals[#goals + 1] = { label = "pack " .. k, item = F.epochs[k].pack } end
  for _, ch in ipairs(X3.chains) do goals[#goals + 1] = { label = "chaîne " .. ch.key, item = ch.target } end
  local mF = brain_measure(F, g, goals)
  local goals0 = {}
  for k = 1, 15 do goals0[#goals0 + 1] = goals[k] end
  local m0 = brain_measure(X0, g0, goals0)
  check(mF.passes < G.MAX_PASSES, string.format("faisabilité du cerveau sur la fusion en %d passes (< %d)", mF.passes, G.MAX_PASSES))
  info(string.format("passes de faisabilité : X0 %d, fusion %d", m0.passes, mF.passes))
  info("dépliage de « 1 pack » de chaque âge (tout débloqué, toutes ressources connues, rien de construit) :")
  info("  âge | pack | profondeur X0 → fusion | nœuds X0 → fusion | payable")
  local over = {}
  for k = 1, 15 do
    local lab = "pack " .. k
    local p = F.epochs[k].pack
    local dk0, dkF = depth_map(g0, k), depth_map(g, k)
    local a, b = m0[lab], mF[lab]
    info(string.format("  %2d | %s | %s → %s | %d → %d%s | %s", k, p, tostring(dk0[p]), tostring(dkF[p]), a.nodes, b.nodes,
      b.truncated and " (TRONQUÉ)" or "", b.payable and "oui" or ("NON, " .. b.blocked .. " blocage(s)")))
    if b.truncated then over[#over + 1] = lab end
    check(not b.truncated or a.truncated, lab .. " (" .. p .. ") : X3 n'ajoute aucun dépassement de " .. G.MAX_NODES .. " nœuds (" .. b.nodes .. ")")
    check(b.payable or not a.payable, lab .. " (" .. p .. ") : payable par le cerveau sur la fusion s'il l'est sur X0")
  end
  for _, ch in ipairs(X3.chains) do
    local lab = "chaîne " .. ch.key
    local b = mF[lab]
    local dk = depth_map(g, 15)[ch.target]
    info(string.format("  chaîne %s « %s » → %s : profondeur %s, %d nœuds, %s", ch.key, ch.fr, ch.target, tostring(dk), b.nodes,
      b.payable and "payable" or "NON payable"))
    check(not b.truncated and b.payable, lab .. " : " .. ch.target .. " dépliable sous " .. G.MAX_NODES .. " nœuds et payable (" .. b.nodes .. ")")
  end
  if #over > 0 then info("DÉPASSEMENT de " .. G.MAX_NODES .. " nœuds (signalé) : " .. table.concat(over, ", ")) else info("aucun dépassement de " .. G.MAX_NODES .. " nœuds") end
end

---------------------------------------------------------------------------------------------------
section("Mutants (chacun doit être refusé par les contrôles propres)")
---------------------------------------------------------------------------------------------------
do
  local function rec(d, name) for _, r in ipairs(d.recipes) do if r.name == name then return r end end end
  local function tech(d, name) for _, t in ipairs(d.technologies) do if t.name == name then return t end end end
  local function ext(d, name) for _, e in ipairs(d.extends) do if e.tech == name then return e end end end
  local function remove(list, pred) for i = #list, 1, -1 do if pred(list[i]) then table.remove(list, i) end end end
  local MUTANTS = {
    { "recette cassée : ingrédient inconnu", "inconnu", function(d)
        rec(d, "fo-etched-wafer").ingredients[3][1] = "fo-photoresist-inexistant" end },
    { "recette cassée : anachronisme (aluminium de l'âge 6 dans la carte imprimée de l'âge 4)", "fermeture", function(d)
        table.insert(rec(d, "fo-printed-circuit-board").ingredients, { "fo-aluminium-plate", 1 }) end },
    { "recette cassée : cycle sans issue (creuset fait de lingots)", "fermeture", function(d)
        rec(d, "fo-quartz-crucible").ingredients = { { "fo-silicon-ingot", 1 } } end },
    { "objet sans usage : boue rouge sans ciment", "usage", function(d)
        remove(d.recipes, function(r) return r.name == "fo-red-mud-cement" end)
        local t = tech(d, "fo-aluminium")
        remove(t.unlocks, function(n) return n == "fo-red-mud-cement" end) end },
    { "objet sans usage : sous-produit nouveau jamais consommé", "usage", function(d)
        table.insert(d.items, { name = "fo-x3-mutant-dross", epoch = 3, fr = "Crasse", en = "Dross", type = "item", stack = 100 })
        table.insert(rec(d, "fo-zinc-retort").results, { "fo-x3-mutant-dross", 1 }) end },
    { "prérequis inversé : la fonderie exige le calcul, le calcul ne l'exige plus", "deblocage", function(d)
        tech(d, "fo-computing").prereq = {}
        ext(d, "fo-silicon").prereq = { "fo-computing" } end },
    { "prérequis en cycle : fonderie ↔ calcul", "prerequis", function(d)
        ext(d, "fo-silicon").prereq = { "fo-computing" } end },
    { "prérequis postérieur : circuits imprimés (4) après l'aluminium (6)", "prerequis", function(d)
        table.insert(tech(d, "fo-printed-circuits").prereq, "fo-aluminium") end },
    { "recette orpheline : module de mémoire débloqué par aucune technologie", "orpheline", function(d)
        remove(ext(d, "fo-silicon").unlocks, function(n) return n == "fo-memory-module" end) end },
    { "garde du jeu : retouche d'une recette que le titane déplie (bobine)", "titane", function(d)
        table.insert(d.retouches, { recipe = "fo-coil", ingredients = { { "fo-enameled-wire", 4 }, { "fo-magnetic-steel", 2 }, { "fo-brass", 1 } } }) end },
    { "cycle de production : la tranche refaite de tranches gravées", "cerveau", function(d)
        for _, r in ipairs(d.retouches) do
          if r.recipe == "fo-silicon-wafer" then
            r.ingredients = { { "fo-silicon-ingot", 1 }, { "fo-crystal-powder", 2 }, { "water", 40 }, { "fo-etched-wafer", 1 } }
          end
        end end },
  }
  local refused = 0
  for _, m in ipairs(MUTANTS) do
    local d = X3.deep_copy(X3)
    m[3](d)
    local ok, Fm = pcall(X3.merge, fresh_X(), d)
    local kinds, total = "", 0
    if ok then
      local cm = run_checks(Fm, build(Fm), X0)
      total = #cm.fails
      kinds = table.concat(sorted_keys(cm.by_kind), ", ")
      local hit = (cm.by_kind[m[2]] or 0) > 0
      if check(hit, "mutant refusé : " .. m[1] .. " (attendu « " .. m[2] .. " », vu : " .. (kinds == "" and "rien" or kinds) .. ")") then refused = refused + 1 end
    else
      if check(false, "mutant « " .. m[1] .. " » : la fusion a planté au lieu d'être refusée par un contrôle (" .. tostring(Fm) .. ")") then end
    end
    info(string.format("mutant « %s » : %d échec(s) [%s]", m[1], total, kinds))
  end
  check(refused == #MUTANTS and refused >= 3, string.format("%d mutants refusés sur %d (3 au moins : recette cassée, objet sans usage, prérequis inversé)", refused, #MUTANTS))
end

---------------------------------------------------------------------------------------------------
section("Bancs rejoués sur X seul et sur la fusion (le jeu ne bouge pas)")
---------------------------------------------------------------------------------------------------
if COURT then
  info("AVIS : --court, bancs non rejoués")
else
  local GEN_PAT = "bloc « [%w]+ » du scénario égal aux données"
  local eX = run_bench("tests/epochs_test.lua", fresh_X())
  local eF = run_bench("tests/epochs_test.lua", fusion())
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
  for _, l in ipairs(eF.lines) do
    local k, sh = l:match("époque%s+(%d+) : nouvelle .-= ([%d%.]+) %% du budget")
    if k and tonumber(k) and ({ [4] = 1, [6] = 1, [10] = 1, [12] = 1 })[tonumber(k)] then info("fusion, recherche de l'âge " .. k .. " : " .. sh .. " % du budget") end
  end
  for _, b in ipairs({ "tests/titanium_test.lua", "tests/monde_test.lua", "tests/org_test.lua" }) do
    local rx = run_bench(b, fresh_X())
    local rf = run_bench(b, fusion())
    check(not rx.crashed and not rf.crashed and rx.ko == 0 and rf.ko == 0 and rx.ok == rf.ok,
      string.format("%s : X seul %s OK / %s ECHEC, fusion %s OK / %s ECHEC (identiques)", b, tostring(rx.ok), tostring(rx.ko), tostring(rf.ok), tostring(rf.ko)))
    info(string.format("%s : X seul %s OK, %s ECHEC(S) ; fusion %s OK, %s ECHEC(S)", b, tostring(rx.ok), tostring(rx.ko), tostring(rf.ok), tostring(rf.ko)))
    if rx.crashed or rf.crashed then print("   " .. tostring(rx.err or rf.err)) end
  end
end

print(string.format("\n[X3] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
