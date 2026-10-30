--[[
  Valeur en MATIÈRE BRUTE (MU) de chaque objet et CHAÎNE de recettes la moins chère (piste CALCULS, nuit du 29 au
  30/10). Lua 5.2 PUR, sans moteur : lit les données de `harness.lua --dump-calc` (tools/calc/donnees.lua) ou une
  fixture au même format (tests/calc_test.lua).

  Unités (conventions du scénario X0, shared/content/epochs.lua) : un minerai solide extrait = 1 MU, une unité de
  fluide de gisement = X.FLUID_MU (0,1), l'eau et la vapeur = 0. Un gisement qui exige un fluide (uranium : acide
  sulfurique) consomme fluid_amount / 10 de ce fluide par minerai (règle du moteur 1.1).

  MÉTHODE : programme linéaire. MU(cible) = coût brut MINIMAL pour produire une unité nette de la cible, toutes les
  recettes pouvant tourner à n'importe quel régime, les sous-produits inutiles étant jetés :
      min Σ c_r x_r   tel que   Σ_r (sorties − entrées)_ri x_r ≥ [i = cible],   x ≥ 0
  (c_r : matière brute extraite par la recette r ; 0 pour une recette ordinaire). Résolu par son DUAL (prix y_i ≥ 0
  des objets, « la valeur des sorties d'une recette ne dépasse pas celle de ses entrées plus sa matière brute »),
  dont l'origine est réalisable : simplexe en une phase, règle de Bland (aucun cyclage, déterministe). Le régime x_r
  de chaque recette se lit à la fin (coûts réduits des écarts) : c'est la CHAÎNE (recettes par unité de cible), avec
  ses boucles (Kovarex, chlore du titane, craquage) et ses sous-produits, sans approximation de partage.

  Règles (toutes testées par tests/calc_test.lua, un mutant par règle) :
  1. Probabilités : quantité attendue = quantité (ou moyenne de amount_min et amount_max) × probabilité.
  2. Catalyseurs : un objet des deux côtés d'une recette (Kovarex) ne compte que pour sa part NETTE.
  3. Productivité (option `prod(recette)` : facteur ≥ 1) : elle multiplie la part du produit HORS catalyseur
     (amount − catalyst_amount, règle du moteur) ; `mining_prod` multiplie le minerai des foreuses.
  4. Sources hors recette : gisements, résidus de combustion (pile d'uranium usée), lancement de fusée (satellite →
     1 000 packs spatiaux, 100 pièces de fusée), bruts sans source (bois, poisson : 1 MU, signalés).
  Exclusions : vidage des barils générés (un aller-retour avec le remplissage) et lots du lot MOD-2 (« fo-lotN- »,
  même économie que la recette de base).
  Déterminisme : objets et recettes en ordre TRIÉ, règle de Bland ; aucune lecture de temps.
]]

local MU = {}

MU.FLUID_MU = 0.1
MU.FREE = { water = true, steam = true }
MU.TOL = 1e-9
MU.MAX_PIVOTS = 20000

--- Recette exclue du graphe (vidage des barils générés, lots MOD-2).
function MU.excluded(name)
  if name:match("^fo%-lot%d+%-") then return true end
  if name:match("^empty%-.+%-barrel$") then return true end
  return false
end

--- Quantité attendue d'un produit (règle 1).
function MU.expected(p)
  local a = p.amount
  if a == nil then a = ((p.amount_min or 0) + (p.amount_max or p.amount_min or 0)) / 2 end
  return a * (p.probability or 1)
end

local function weight(kind) return kind == "fluid" and MU.FLUID_MU or 1 end
MU.weight = weight

local function sorted_keys(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out)
  return out
end
MU.sorted_keys = sorted_keys

--- Une recette au format commun : { name, category, energy, c, ins = { [objet] = n }, outs = { [objet] = n },
--- kinds = { [objet] = "item"|"fluid" }, prod, raw }, entrées et sorties NETTES (règle 2), eau et vapeur retirées.
local function make(name, category, energy, c, ins_by, outs_by, kinds, pf, raw)
  for _, n in ipairs(sorted_keys(outs_by)) do
    local k = math.min(outs_by[n], ins_by[n] or 0)
    if k > 0 then outs_by[n] = outs_by[n] - k; ins_by[n] = ins_by[n] - k end
  end
  local ins, outs = {}, {}
  for _, n in ipairs(sorted_keys(ins_by)) do
    if ins_by[n] > MU.TOL and not MU.FREE[n] then ins[n] = ins_by[n] end
  end
  local any = false
  for _, n in ipairs(sorted_keys(outs_by)) do
    if outs_by[n] > MU.TOL and not MU.FREE[n] then outs[n] = outs_by[n]; any = true end
  end
  if not any then return nil end
  return { name = name, category = category, energy = energy, c = c, ins = ins, outs = outs, kinds = kinds, prod = pf,
    raw = raw }
end

--- Recettes du jeu (règles 1 à 3). prod : fonction(nom, recette brute) → facteur de productivité (1 par défaut).
--- allow : fonction(nom) → false pour écarter une recette (recette pas encore débloquée à l'époque étudiée).
function MU.normalize(data, prod, allow)
  local out = {}
  for _, name in ipairs(sorted_keys(data.recipes)) do
    local r = data.recipes[name]
    if not MU.excluded(name) and (not allow or allow(name)) then
      local pf = prod and prod(name, r) or 1
      local ins_by, outs_by, kinds = {}, {}, {}
      for _, i in ipairs(r.ingredients or {}) do
        ins_by[i.name] = (ins_by[i.name] or 0) + (i.amount or 1)
        kinds[i.name] = i.type or "item"
      end
      for _, p in ipairs(r.products or {}) do
        local a = MU.expected(p)
        local cat = math.min(p.catalyst_amount or 0, a)
        a = cat + (a - cat) * pf
        outs_by[p.name] = (outs_by[p.name] or 0) + a
        kinds[p.name] = p.type or "item"
      end
      local x = make(name, r.category, r.energy or 0.5, 0, ins_by, outs_by, kinds, pf, r)
      if x then out[#out + 1] = x end
    end
  end
  return out
end

--- Sources hors recette (règle 4). Renvoie la liste des pseudo-recettes et celle des bruts sans source.
--- full_produced (facultatif) : objets produits par une recette QUELCONQUE du jeu ; un objet produit seulement par une
--- recette écartée (pas encore débloquée) n'est pas un brut, il devient inaccessible.
function MU.sources(data, recipes, mining_prod, full_produced)
  local out = {}
  local mp = mining_prod or 1
  for _, name in ipairs(sorted_keys(data.resources or {})) do
    local r = data.resources[name]
    local res = r.results and r.results[1]
    if res and res.name then
      local kind = res.type or "item"
      local amount = MU.expected(res)
      local ins = {}
      if r.required_fluid and (r.fluid_amount or 0) > 0 then ins[r.required_fluid] = r.fluid_amount / 10 end
      local x = make("gisement:" .. name, r.category, r.mining_time or 1, weight(kind) * amount, ins,
        { [res.name] = amount * mp }, { [res.name] = kind }, mp, r)
      x.resource = name
      out[#out + 1] = x
    end
  end
  local items = data.items or {}
  local silo = data.machines and data.machines["rocket-silo"]
  local parts = silo and silo.rocket_parts_required or 100
  for _, name in ipairs(sorted_keys(items)) do
    local it = items[name]
    if it.burnt_result then
      out[#out + 1] = make("combustion:" .. name, "combustion", 0, 0, { [name] = 1 }, { [it.burnt_result] = 1 },
        { [name] = "item", [it.burnt_result] = "item" }, 1, it)
    end
    if it.launch then
      local outs, kinds = {}, { [name] = "item", ["rocket-part"] = "item" }
      for _, p in ipairs(it.launch) do outs[p.name] = (outs[p.name] or 0) + MU.expected(p); kinds[p.name] = "item" end
      local x = make("lancement:" .. name, "rocket-launch", 0, 0, { [name] = 1, ["rocket-part"] = parts }, outs, kinds, 1, it)
      if x then out[#out + 1] = x end
    end
  end
  -- Bruts sans source (utilisés, jamais produits) : 1 MU chacun, signalés.
  local produced, used = {}, {}
  local all = {}
  for _, x in ipairs(recipes) do all[#all + 1] = x end
  for _, x in ipairs(out) do all[#all + 1] = x end
  for _, x in ipairs(all) do
    for n in pairs(x.outs) do produced[n] = true end
    for n in pairs(x.ins) do used[n] = true end
  end
  local orphans = {}
  for _, n in ipairs(sorted_keys(used)) do
    if not produced[n] and not (full_produced and full_produced[n]) then
      orphans[#orphans + 1] = n
      out[#out + 1] = make("brut:" .. n, "brut", 0, 1, {}, { [n] = 1 }, { [n] = "item" }, 1, nil)
    end
  end
  return out, orphans
end

--- Graphe complet : { recipes = liste triée, producers = { objet → { recette } }, orphans }.
function MU.graph(data, opts)
  opts = opts or {}
  local recipes = MU.normalize(data, opts.prod, opts.allow)
  local full_produced
  if opts.allow then
    full_produced = {}
    for _, x in ipairs(MU.normalize(data)) do for n in pairs(x.outs) do full_produced[n] = true end end
  end
  local src, orphans = MU.sources(data, recipes, opts.mining_prod, full_produced)
  for _, x in ipairs(src) do recipes[#recipes + 1] = x end
  local producers = {}
  for _, x in ipairs(recipes) do
    for n in pairs(x.outs) do
      producers[n] = producers[n] or {}
      table.insert(producers[n], x)
    end
  end
  return { recipes = recipes, producers = producers, orphans = orphans }
end

--- Simplexe du dual pour la cible. Renvoie mu (math.huge si la cible est inaccessible), x = { recette → régime par
--- unité de cible }, y = { objet → prix }, pivots. opts.no_raw : sans aucune source de matière brute (c > 0) ; une
--- cible encore accessible (mu fini, nul) révèle une BOUCLE DE MATIÈRE INFINIE (productivité sur un cycle).
function MU.solve_target(G, target, opts)
  local no_raw = opts and opts.no_raw
  -- Fermeture : recettes qui produisent un objet requis, puis leurs ingrédients.
  local need, queue, recs, seen_r = { [target] = true }, { target }, {}, {}
  local qi = 1
  while queue[qi] do
    local it = queue[qi]; qi = qi + 1
    for _, x in ipairs(G.producers[it] or {}) do
      if not seen_r[x] and not (no_raw and x.c > 0) then
        seen_r[x] = true
        recs[#recs + 1] = x
        for _, n in ipairs(sorted_keys(x.ins)) do
          if not need[n] then need[n] = true; queue[#queue + 1] = n end
        end
      end
    end
  end
  if #recs == 0 then return math.huge, {}, {}, 0 end
  table.sort(recs, function(a, b) return a.name < b.name end)
  local items_set = {}
  for _, x in ipairs(recs) do
    for n in pairs(x.ins) do items_set[n] = true end
    for n in pairs(x.outs) do items_set[n] = true end
  end
  local items = sorted_keys(items_set)
  local col = {}
  for j, n in ipairs(items) do col[n] = j end
  local m, n = #recs, #items
  local W = n + m
  -- Tableau : lignes 1..m (contraintes Σ a_ri y_i + s_r = c_r), ligne 0 = objectif (max y_cible → −1 sur la cible).
  local T = {}
  for i, x in ipairs(recs) do
    local row = {}
    for j = 1, W + 1 do row[j] = 0 end
    for it, a in pairs(x.outs) do row[col[it]] = row[col[it]] + a end
    for it, a in pairs(x.ins) do row[col[it]] = row[col[it]] - a end
    row[n + i] = 1
    row[W + 1] = x.c
    T[i] = row
  end
  local z = {}
  for j = 1, W + 1 do z[j] = 0 end
  z[col[target]] = -1
  local basis = {}
  for i = 1, m do basis[i] = n + i end
  local pivots = 0
  while true do
    local e
    for j = 1, W do
      if z[j] < -MU.TOL then e = j; break end -- Bland : plus petit indice
    end
    if not e then break end
    local lv, best
    for i = 1, m do
      local a = T[i][e]
      if a > MU.TOL then
        local ratio = T[i][W + 1] / a
        if not best or ratio < best - MU.TOL or (math.abs(ratio - best) <= MU.TOL and basis[i] < basis[lv]) then
          best, lv = ratio, i
        end
      end
    end
    if not lv then return math.huge, {}, {}, pivots end -- dual non borné : cible inaccessible
    pivots = pivots + 1
    if pivots > MU.MAX_PIVOTS then error("simplexe : trop de pivots pour " .. target) end
    local pr = T[lv]
    local pv = pr[e]
    for j = 1, W + 1 do pr[j] = pr[j] / pv end
    for i = 1, m do
      if i ~= lv then
        local row = T[i]
        local f = row[e]
        if f ~= 0 then for j = 1, W + 1 do row[j] = row[j] - f * pr[j] end end
      end
    end
    local f = z[e]
    for j = 1, W + 1 do z[j] = z[j] - f * pr[j] end
    basis[lv] = e
  end
  local y = {}
  for i = 1, m do
    if basis[i] <= n then y[items[basis[i]]] = T[i][W + 1] end
  end
  local x = {}
  for i, r in ipairs(recs) do
    local v = z[n + i]
    if v > MU.TOL then x[r.name] = { recipe = r, runs = v } end
  end
  return z[W + 1], x, y, pivots
end

--- Boucle de matière infinie : la cible se fabrique sans aucune matière brute. Renvoie la liste triée des recettes de
--- la boucle (régimes positifs), ou nil.
function MU.free_loop(G, target)
  local v, x = MU.solve_target(G, target, { no_raw = true })
  if v == math.huge then return nil end
  return sorted_keys(x)
end

--- Cycle d'objets dans une chaîne (régimes x de MU.solve_target) : un objet qui, de recette en recette (ingrédient →
--- produit, parts NETTES), se refait lui-même. Renvoie le cycle { a, b, …, a } (premier trouvé, ordre trié) ou nil.
function MU.cycle(x)
  local succ = {}
  for _, rn in ipairs(sorted_keys(x)) do
    local r = x[rn].recipe
    for _, i in ipairs(sorted_keys(r.ins)) do
      succ[i] = succ[i] or {}
      for _, o in ipairs(sorted_keys(r.outs)) do table.insert(succ[i], o) end
    end
  end
  local state, stack = {}, {}
  local found
  local function dfs(n)
    state[n] = 1; stack[#stack + 1] = n
    for _, s in ipairs(succ[n] or {}) do
      if found then return end
      if state[s] == 1 then
        local cyc, on = {}, false
        for _, v in ipairs(stack) do
          if v == s then on = true end
          if on then cyc[#cyc + 1] = v end
        end
        cyc[#cyc + 1] = s
        found = cyc
        return
      elseif not state[s] then dfs(s) end
    end
    state[n] = 2; stack[#stack] = nil
  end
  for _, n in ipairs(sorted_keys(succ)) do
    if not state[n] and not found then dfs(n) end
  end
  return found
end

--- Valeurs de plusieurs objets : { [objet] = { mu, x, pivots } } (même graphe).
function MU.values(G, targets)
  local out = {}
  for _, t in ipairs(targets) do
    local v, x, _, piv = MU.solve_target(G, t)
    out[t] = { mu = v, x = x, pivots = piv }
  end
  return out
end

return MU
