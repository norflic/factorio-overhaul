--[[
  IA3 « le cerveau des PNJ » : PROTOTYPE PUR (conception, NON BRANCHÉ) du dépliage générique des buts sur le graphe
  recettes-technologies-machines-ressources. docs/IA3_CERVEAU.md §3.2 et §3.3.

  Ce module ne connaît AUCUN bâtiment ni objet par son nom : tout vient de `spec` (en jeu : game.recipe_prototypes,
  game.technology_prototypes, game.entity_prototypes ; hors jeu : tests/fixtures/recipes_ia1e.lua,
  tests/fixtures/tech_ai3.lua, tests/fixtures/entities_ai3.lua). Le test tests/ai3_graphe_test.lua relit ce fichier
  et refuse tout nom de bâtiment ou de produit du jeu dans le code.

  Six méthodes génériques pour « obtenir N × objet » (HTN à méthodes déduites des données) :
    take     prendre au stock (une réservation, §2.2) ;
    hand     fabriquer à la main (recette d'une catégorie « main », solides seulement, un seul produit) ;
    produce  faire produire par une machine de la catégorie de la recette (la construire si l'équipe n'en a pas :
             build, avec son énergie : électricité ou combustible) ;
    extract  extraire une ressource connue (construire l'extracteur de sa catégorie si besoin) ;
    explore  chercher une ressource inconnue (seule étape émise pour elle) ;
    research rechercher la technologie qui débloque une recette verrouillée (prérequis, packs, laboratoire).
  Les fluides (et l'électricité, pseudo-fluide) se raisonnent en CAPACITÉ (une ligne qui les produit), pas en
  quantité : les débits sont l'affaire du solveur d'IA1-e1 (shared/team/production.lua).

  Règle H8 (« ne pas fabriquer ce qui ne servira pas ») : un objet dont le dépliage touche une ressource inconnue est
  IMPAYABLE ; pour lui, seules les étapes qui ouvrent la voie (recherche payable, exploration) sont émises, jamais
  une fabrication ni une construction.

  Évaluation : deux POINTS FIXES sur tout le graphe (les recettes ont des cycles : barils, craquage) :
    - faisabilité (booléens, plus petit point fixe : un cycle ne rend rien faisable) ;
    - coût de choix (min-plus, à la Bellman-Ford) : temps de recette + ingrédients + surcoûts (recette verrouillée,
      catégorie sans machine) ; il ne sert qu'à CHOISIR entre méthodes, pas à chiffrer un débit.
  Coût : environ (passes × recettes × ingrédients) opérations, refait seulement quand l'état change (technologie
  recherchée, ressource découverte, machine construite).

  G.new(spec) -> catalogue ; G.unfold(cat, goals, state) -> { steps, blocked, payable, nodes, truncated, passes }
    goals = { { item = nom, n = quantité } | { tech = nom } , ... } (dans l'ordre de priorité)
    state = { stock = {[objet]=n}, techs = {[techno]=true}, built = {[machine]=n}, known = {[ressource]=true} }
  Une étape = { kind, name, n, item, why } ; l'ordre des étapes est exécutable (dépendances d'abord).

  Déterminisme : listes triées partout (aucun pairs décisionnel), égalités départagées par le nom ; aucun hasard.
]]

local G = {}

G.HUGE = 1e12
G.EXPLORE_COST = 1e6        -- coût de choix d'une ressource inconnue
G.RESEARCH_PENALTY = 60     -- recette verrouillée : surcoût de choix (le coût réel des packs est émis à part)
G.MACHINE_PENALTY = 30      -- catégorie sans machine construite ni main : surcoût de choix
G.MAX_PASSES = 64
G.MAX_NODES = 4000

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

local function copy(t)
  local c = {}
  for k, v in pairs(t or {}) do c[k] = v end
  return c
end

--- Catalogue : index du graphe, construit une fois (en jeu : au premier usage après chargement, cache local).
function G.new(spec)
  local cat = {
    recipes = {}, recipe_list = {}, techs = spec.techs or {}, tech_list = sorted_keys(spec.techs),
    producers = {}, unlocked_by = {}, by_category = {}, by_rescat = {}, labs = {}, machine = {},
    machine_list = {}, resources = spec.resources or {}, resource_list = sorted_keys(spec.resources),
    hand = spec.hand_categories or {}, fuel = spec.fuel, electricity = spec.electricity,
  }
  local machines = {}
  for _, m in ipairs(spec.machines or {}) do machines[#machines + 1] = m end
  table.sort(machines, function(a, b) return a.name < b.name end)
  for _, m in ipairs(machines) do
    cat.machine[m.name] = m
    cat.machine_list[#cat.machine_list + 1] = m.name
    if not m.hand then
      for _, c in ipairs(m.crafting_categories or {}) do
        local l = cat.by_category[c] or {}
        l[#l + 1] = m.name
        cat.by_category[c] = l
      end
    end
    for _, c in ipairs(m.resource_categories or {}) do
      local l = cat.by_rescat[c] or {}
      l[#l + 1] = m.name
      cat.by_rescat[c] = l
    end
    if m.lab then cat.labs[#cat.labs + 1] = m.name end
  end
  -- Recettes : une recette qu'aucune machine connue ni la main ne sait faire est ignorée (elle n'existe pas pour
  -- l'équipe ; en jeu : catégorie sans bâtiment fabricable).
  local all = {}
  for _, name in ipairs(sorted_keys(spec.recipes)) do all[#all + 1] = { name, spec.recipes[name] } end
  for _, name in ipairs(sorted_keys(spec.pseudo_recipes)) do all[#all + 1] = { name, spec.pseudo_recipes[name] } end
  table.sort(all, function(a, b) return a[1] < b[1] end)
  for _, e in ipairs(all) do
    local name, r = e[1], e[2]
    local doable = cat.by_category[r.category] ~= nil or cat.hand[r.category]
    if not r.hidden and doable then
      cat.recipes[name] = r
      cat.recipe_list[#cat.recipe_list + 1] = name
      for _, p in ipairs(r.products) do
        local list = cat.producers[p.name] or {}
        list[#list + 1] = name
        cat.producers[p.name] = list
      end
    end
  end
  for _, tname in ipairs(cat.tech_list) do
    for _, rname in ipairs(cat.techs[tname].unlocks or {}) do
      if not cat.unlocked_by[rname] then cat.unlocked_by[rname] = tname end
    end
  end
  return cat
end

local function handable(cat, r)
  if not cat.hand[r.category] or #r.products ~= 1 or r.products[1].type == "fluid" then return false end
  for _, i in ipairs(r.ingredients) do if i.type == "fluid" then return false end end
  return true
end

local function product_amount(r, item)
  for _, p in ipairs(r.products) do if p.name == item then return p.amount end end
  return 1
end

--- Une recette qui consomme ce qu'elle produit (liquéfaction : il faut de l'huile lourde pour en faire) n'est pas un
--- moyen d'OBTENIR cet objet : il faut d'abord l'avoir. Elle est ignorée pour cet objet (coût et choix).
local function self_loop(r, item)
  for _, i in ipairs(r.ingredients) do if i.name == item then return true end end
  return false
end

---------------------------------------------------------------------------------------------------
-- Évaluation : points fixes de faisabilité et de coût de choix.
---------------------------------------------------------------------------------------------------
local function energy_ok(cat, st, m)
  local e = cat.machine[m].energy
  if e == "electric" and cat.electricity then return st.feas[cat.electricity] == true end
  if e == "burner" and cat.fuel then return st.feas[cat.fuel] == true end
  return true
end

local function machines_ok(cat, st, list)
  for _, m in ipairs(list or {}) do
    -- La main (personnage) est toujours là : un PNJ mine à la main ce que sa catégorie permet.
    if (st.built[m] or 0) > 0 or cat.machine[m].hand then return true end
  end
  for _, m in ipairs(list or {}) do
    if st.feas[m] and energy_ok(cat, st, m) then return true end
  end
  return false
end

local function tech_done(st, t) return t == nil or st.techs[t] == true end

local function recipe_ok(cat, st, rname)
  local r = cat.recipes[rname]
  local t = cat.unlocked_by[rname]
  if not tech_done(st, t) and not st.tfeas[t] then return false end
  if not handable(cat, r) and not machines_ok(cat, st, cat.by_category[r.category]) then return false end
  for _, i in ipairs(r.ingredients) do if not st.feas[i.name] then return false end end
  return true
end

local function machine_cost(cat, st, list)
  local best = G.HUGE
  for _, m in ipairs(list or {}) do
    if (st.built[m] or 0) > 0 then return 0 end
    local c = st.cost[m] or G.HUGE
    if c < best then best = c end
  end
  return best
end

local function evaluate(cat, st)
  -- Faisabilité : plus petit point fixe (tout faux au départ, on ne fait que passer à vrai).
  local passes = 0
  local changed = true
  while changed and passes < G.MAX_PASSES do
    changed, passes = false, passes + 1
    for _, res in ipairs(cat.resource_list) do
      if not st.feas[res] and st.known[res] and machines_ok(cat, st, cat.by_rescat[cat.resources[res].category]) then
        st.feas[res], changed = true, true
      end
    end
    for _, rname in ipairs(cat.recipe_list) do
      local r = cat.recipes[rname]
      local need = false
      for _, p in ipairs(r.products) do if not st.feas[p.name] then need = true end end
      if need and recipe_ok(cat, st, rname) then
        for _, p in ipairs(r.products) do
          if not st.feas[p.name] then st.feas[p.name], changed = true, true end
        end
      end
    end
    for _, t in ipairs(cat.tech_list) do
      if not st.tfeas[t] and not st.techs[t] then
        local spec, ok = cat.techs[t], true
        for _, pre in ipairs(spec.prerequisites or {}) do if not (st.techs[pre] or st.tfeas[pre]) then ok = false end end
        for _, ing in ipairs(spec.ingredients or {}) do if not st.feas[ing[1]] then ok = false end end
        if ok and not machines_ok(cat, st, cat.labs) then ok = false end
        if ok then st.tfeas[t], changed = true, true end
      end
    end
  end
  st.passes = passes
  -- Coût de choix : min-plus, itéré jusqu'à stabilité (borne MAX_PASSES).
  for _, res in ipairs(cat.resource_list) do st.cost[res] = st.known[res] and 1 or G.EXPLORE_COST end
  changed, passes = true, 0
  while changed and passes < G.MAX_PASSES do
    changed, passes = false, passes + 1
    for _, rname in ipairs(cat.recipe_list) do
      local r = cat.recipes[rname]
      local base = 0
      for _, i in ipairs(r.ingredients) do
        local c = st.cost[i.name]
        if not c then base = G.HUGE break end
        base = base + c * i.amount
      end
      if base < G.HUGE then
        local extra = 0
        if not tech_done(st, cat.unlocked_by[rname]) then extra = extra + G.RESEARCH_PENALTY end
        if not handable(cat, r) then
          local mc = machine_cost(cat, st, cat.by_category[r.category])
          if mc > 0 then extra = extra + G.MACHINE_PENALTY + math.min(mc, G.EXPLORE_COST) * 0.01 end
        end
        for _, p in ipairs(r.products) do
          local c = (r.energy + base) / p.amount + extra
          if not self_loop(r, p.name) and c < (st.cost[p.name] or G.HUGE) - 1e-9 then st.cost[p.name], changed = c, true end
        end
      end
    end
  end
end

--- Meilleur producteur d'un objet : faisable d'abord, puis le moins cher, puis le nom (ressource avant recette).
local function best_method(cat, st, item)
  local best
  local res = cat.resources[item]
  if res then best = { kind = "resource", name = item, ok = st.feas[item] == true, cost = st.cost[item] or G.HUGE } end
  for _, rname in ipairs(cat.producers[item] or {}) do
    local r = cat.recipes[rname]
    if not self_loop(r, item) then
      local ok = recipe_ok(cat, st, rname)
      local base = r.energy
      for _, i in ipairs(r.ingredients) do base = base + (st.cost[i.name] or G.HUGE) * i.amount end
      local c = base / product_amount(r, item)
      if not tech_done(st, cat.unlocked_by[rname]) then c = c + G.RESEARCH_PENALTY end
      local better = not best or (ok and not best.ok) or (ok == best.ok and c < best.cost - 1e-9)
      if better then best = { kind = "recipe", name = rname, ok = ok, cost = c } end
    end
  end
  return best
end

--- Meilleure machine d'une liste : déjà construite, sinon faisable (énergie comprise), la moins chère, puis le nom.
--- La main n'est choisie que si aucune vraie machine n'est faisable (un joueur pose une foreuse dès qu'il peut).
local function best_machine(cat, st, list)
  for _, m in ipairs(list or {}) do
    if (st.built[m] or 0) > 0 and not cat.machine[m].hand then return m, true end
  end
  local best, bestc, bestok, hand
  for _, m in ipairs(list or {}) do
    if cat.machine[m].hand then
      hand = hand or m
    else
      local ok = st.feas[m] == true and energy_ok(cat, st, m)
      local c = st.cost[m] or G.HUGE
      if not best or (ok and not bestok) or (ok == bestok and c < bestc - 1e-9) then best, bestc, bestok = m, c, ok end
    end
  end
  if hand and not bestok then return hand, true end
  return best, bestok
end

--- Ressources inconnues qui bloquent un objet (parcours du meilleur producteur, chaque nœud une fois).
local function causes_of(cat, st, item, seen, out)
  if seen[item] then return end
  seen[item] = true
  if st.feas[item] then return end
  local m = best_method(cat, st, item)
  if not m then out["?" .. item] = true return end
  if m.kind == "resource" then
    if not st.known[item] then out[item] = true end
    local res = cat.resources[item]
    for _, d in ipairs(cat.by_rescat[res.category] or {}) do causes_of(cat, st, d, seen, out) end
    return
  end
  local r = cat.recipes[m.name]
  local t = cat.unlocked_by[m.name]
  if t and not tech_done(st, t) and not st.tfeas[t] then
    for _, ing in ipairs(cat.techs[t].ingredients or {}) do causes_of(cat, st, ing[1], seen, out) end
  end
  for _, i in ipairs(r.ingredients) do causes_of(cat, st, i.name, seen, out) end
  if not handable(cat, r) and not machines_ok(cat, st, cat.by_category[r.category]) then
    local mach = best_machine(cat, st, cat.by_category[r.category])
    if mach then causes_of(cat, st, mach, seen, out) end
  end
end

---------------------------------------------------------------------------------------------------
-- Émission des étapes (ordre exécutable).
---------------------------------------------------------------------------------------------------
local emit_item, emit_tech, ensure_capacity, ensure_supply, emit_enable

local function push(st, step)
  st.steps[#st.steps + 1] = step
end

local function tick_node(st)
  st.nodes = st.nodes + 1
  if st.nodes > G.MAX_NODES then st.truncated = true end
  return not st.truncated
end

local function block(cat, st, entry, item)
  local out = {}
  causes_of(cat, st, item, {}, out)
  entry.causes = sorted_keys(out)
  st.blocked[#st.blocked + 1] = entry
end

local function ensure_energy(cat, st, mname, why)
  local e = cat.machine[mname].energy
  if e == "electric" and cat.electricity then ensure_capacity(cat, st, cat.electricity, why)
  elseif e == "burner" and cat.fuel then ensure_supply(cat, st, cat.fuel, why) end
end

local function ensure_machine(cat, st, list, why, site)
  for _, m in ipairs(list or {}) do if (st.built[m] or 0) > 0 then return true end end
  local m = best_machine(cat, st, list)
  if not m then return false end
  if cat.machine[m].hand then return true end
  st.built[m] = 1
  emit_item(cat, st, m, 1, why)
  ensure_energy(cat, st, m, why)
  push(st, { kind = "build", name = m, item = site, why = why })
  return true
end

local function ensure_unlocked(cat, st, rname, why)
  local t = cat.unlocked_by[rname]
  if t and not st.techs[t] then emit_tech(cat, st, t, why) end
end

local function ensure_extractor(cat, st, res, why)
  ensure_machine(cat, st, cat.by_rescat[cat.resources[res].category], why, res)
end

emit_tech = function(cat, st, tname, why)
  if st.techs[tname] or st.planned[tname] or not tick_node(st) then return end
  st.planned[tname] = true
  local t = cat.techs[tname]
  if not t then return end
  for _, pre in ipairs(t.prerequisites or {}) do emit_tech(cat, st, pre, why) end
  local label = "recherche " .. tname
  if not st.tfeas[tname] then
    -- Recherche impayable : on ouvre seulement la voie de ses packs (exploration, recherches payables).
    for _, ing in ipairs(t.ingredients or {}) do emit_enable(cat, st, ing[1], label) end
    local out = {}
    for _, ing in ipairs(t.ingredients or {}) do causes_of(cat, st, ing[1], {}, out) end
    st.blocked[#st.blocked + 1] = { tech = tname, causes = sorted_keys(out) }
    return
  end
  ensure_machine(cat, st, cat.labs, label)
  for _, ing in ipairs(t.ingredients or {}) do emit_item(cat, st, ing[1], ing[2] * t.count, label) end
  push(st, { kind = "research", name = tname, why = why })
end

ensure_supply = function(cat, st, item, why)
  if st.supply[item] or not tick_node(st) then return end
  st.supply[item] = true
  if not st.feas[item] then
    emit_enable(cat, st, item, why)
    block(cat, st, { item = item }, item)
    return
  end
  local m = best_method(cat, st, item)
  if m.kind == "resource" then
    ensure_extractor(cat, st, item, why)
  else
    local r = cat.recipes[m.name]
    ensure_unlocked(cat, st, m.name, why)
    if not handable(cat, r) then ensure_machine(cat, st, cat.by_category[r.category], "ligne " .. item) end
    for _, ing in ipairs(r.ingredients) do
      if ing.type == "fluid" then ensure_capacity(cat, st, ing.name, "ligne " .. item)
      else ensure_supply(cat, st, ing.name, "ligne " .. item) end
    end
  end
  push(st, { kind = "supply", name = item, why = why })
end

ensure_capacity = function(cat, st, fluid, why)
  if st.cap[fluid] or not tick_node(st) then return end
  st.cap[fluid] = true
  if not st.feas[fluid] then
    emit_enable(cat, st, fluid, why)
    block(cat, st, { item = fluid }, fluid)
    return
  end
  local m = best_method(cat, st, fluid)
  if m.kind == "resource" then
    ensure_extractor(cat, st, fluid, why)
  else
    local r = cat.recipes[m.name]
    ensure_unlocked(cat, st, m.name, why)
    ensure_machine(cat, st, cat.by_category[r.category], "ligne " .. fluid)
    for _, ing in ipairs(r.ingredients) do
      if ing.type == "fluid" then ensure_capacity(cat, st, ing.name, "ligne " .. fluid)
      else ensure_supply(cat, st, ing.name, "ligne " .. fluid) end
    end
  end
  push(st, { kind = "line", name = fluid, why = why })
end

--- Objet impayable : ouvrir la voie seulement (explorer les ressources inconnues, rechercher ce qui est payable).
emit_enable = function(cat, st, item, why)
  if st.enabled[item] or st.feas[item] or not tick_node(st) then return end
  st.enabled[item] = true
  local m = best_method(cat, st, item)
  if not m then return end
  if m.kind == "resource" then
    if not st.known[item] and not st.explore[item] then
      st.explore[item] = true
      push(st, { kind = "explore", name = item, why = why })
    end
    for _, d in ipairs(cat.by_rescat[cat.resources[item].category] or {}) do emit_enable(cat, st, d, why) end
    return
  end
  local r = cat.recipes[m.name]
  local t = cat.unlocked_by[m.name]
  if t and not st.techs[t] then
    if st.tfeas[t] then emit_tech(cat, st, t, why)
    else for _, ing in ipairs(cat.techs[t].ingredients or {}) do emit_enable(cat, st, ing[1], why) end end
  end
  for _, ing in ipairs(r.ingredients) do emit_enable(cat, st, ing.name, why) end
  if not handable(cat, r) and not machines_ok(cat, st, cat.by_category[r.category]) then
    local mach = best_machine(cat, st, cat.by_category[r.category])
    if mach then emit_enable(cat, st, mach, why) end
  end
end

emit_item = function(cat, st, item, n, why)
  if n <= 0 or not tick_node(st) then return end
  local have = st.avail[item] or 0
  local take = have < n and have or n
  if take > 0 then
    st.avail[item] = have - take
    push(st, { kind = "take", name = item, n = take, why = why })
    n = n - take
    if n <= 0 then return end
  end
  if not st.feas[item] then
    emit_enable(cat, st, item, why)
    block(cat, st, { item = item, n = n }, item)
    return
  end
  local m = best_method(cat, st, item)
  if m.kind == "resource" then
    ensure_extractor(cat, st, item, why)
    push(st, { kind = "extract", name = item, n = n, why = why })
    return
  end
  local r = cat.recipes[m.name]
  local amount = product_amount(r, item)
  local runs = math.ceil(n / amount)
  ensure_unlocked(cat, st, m.name, why)
  local how = handable(cat, r) and "hand" or "produce"
  if how == "produce" then ensure_machine(cat, st, cat.by_category[r.category], item) end
  for _, ing in ipairs(r.ingredients) do
    if ing.type == "fluid" then ensure_capacity(cat, st, ing.name, item)
    else emit_item(cat, st, ing.name, ing.amount * runs, item) end
  end
  push(st, { kind = how, name = m.name, item = item, n = runs, why = why })
  local surplus = runs * amount - n
  if surplus > 0 then st.avail[item] = (st.avail[item] or 0) + surplus end
end

--- Objets DURABLES du stock (lot IA3-0, revue M2) : les machines du catalogue (bâtiments posables) et ceux que l'état
--- déclare durables (`state.durable`). Eux seuls amorcent la faisabilité : un engrenage qui apparaît puis disparaît du
--- coffre ne doit pas obliger à refaire les points fixes. Liste triée.
function G.durable_kinds(cat, state)
  local out = {}
  for _, item in ipairs(sorted_keys(state.stock)) do
    if (state.stock[item] or 0) > 0 and (cat.machine[item] or (state.durable and state.durable[item])) then
      out[#out + 1] = item
    end
  end
  return out
end

--- Clé d'invalidation des points fixes (revue M2) : technologies, machines posées, ressources connues, objets
--- durables. Deux états de même clé ont la même faisabilité et les mêmes coûts de choix. Chaîne stable (triée).
function G.state_key(cat, state)
  local parts = { "t" }
  for _, k in ipairs(sorted_keys(state.techs)) do if state.techs[k] then parts[#parts + 1] = k end end
  parts[#parts + 1] = "|b"
  for _, k in ipairs(sorted_keys(state.built)) do if (state.built[k] or 0) > 0 then parts[#parts + 1] = k end end
  parts[#parts + 1] = "|k"
  for _, k in ipairs(sorted_keys(state.known)) do if state.known[k] then parts[#parts + 1] = k end end
  parts[#parts + 1] = "|d"
  for _, k in ipairs(G.durable_kinds(cat, state)) do parts[#parts + 1] = k end
  return table.concat(parts, ",")
end

--- Évalue l'état (points fixes) ; réutilisable pour plusieurs dépliages tant que la clé (G.state_key) ne change pas.
function G.prepare(cat, state)
  local st = {
    known = copy(state.known), techs = copy(state.techs), built = copy(state.built),
    feas = {}, tfeas = {}, cost = {}, passes = 0,
  }
  -- Les objets DURABLES du stock sont atteignables (le kit de départ apporte ses foreuses et ses fours). Les autres
  -- objets du stock sont pris par le dépliage (étape « take ») mais n'amorcent pas la faisabilité (revue M2).
  for _, item in ipairs(G.durable_kinds(cat, state)) do st.feas[item] = true end
  evaluate(cat, st)
  return st
end

function G.unfold(cat, goals, state, prepared)
  local ev = prepared or G.prepare(cat, state)
  local st = {
    known = ev.known, techs = ev.techs, built = copy(ev.built), avail = copy(state.stock),
    feas = ev.feas, tfeas = ev.tfeas, cost = ev.cost,
    planned = {}, cap = {}, supply = {}, enabled = {}, explore = {},
    steps = {}, blocked = {}, nodes = 0, truncated = false,
  }
  for _, g in ipairs(goals) do
    if g.tech then emit_tech(cat, st, g.tech, "but " .. g.tech)
    else emit_item(cat, st, g.item, g.n or 1, "but " .. g.item) end
  end
  return { steps = st.steps, blocked = st.blocked, payable = #st.blocked == 0 and not st.truncated, nodes = st.nodes,
    truncated = st.truncated, passes = ev.passes }
end

--- Une technologie est-elle payable dans cet état (toutes ses feuilles atteignables) ?
function G.tech_payable(cat, state, tname, prepared)
  local ev = prepared or G.prepare(cat, state)
  return ev.techs[tname] == true or ev.tfeas[tname] == true
end

--- Coût d'une technologie en packs, prérequis non recherchés compris (chacun compté une fois).
function G.tech_packs(cat, tname, done)
  local seen, packs = {}, {}
  local function walk(t)
    if seen[t] or (done and done[t]) then return end
    seen[t] = true
    local spec = cat.techs[t]
    if not spec then return end
    for _, pre in ipairs(spec.prerequisites or {}) do walk(pre) end
    for _, ing in ipairs(spec.ingredients or {}) do packs[ing[1]] = (packs[ing[1]] or 0) + ing[2] * spec.count end
  end
  walk(tname)
  return packs, seen
end

return G
