--[[
  Lot L1 « le rang calculé » (tiers dynamiques). Demande du DC du 7/11 : reprendre au moins 50 % de la logique de la vidéo
  « Factorio Automated », dont les « tiers dynamiques » (docs/VIDEO_AUTOMATISATION.md §3 et §6 L1). PUR (aucune API Factorio),
  testé hors jeu (tests/rang_test.lua). BRANCHÉ (lot L1b) : Ca.RANG = true (shared/ai3/capitalisation.lua:153) : le besoin suit
  Rg.chain (requirements_by_rank, :768-816) et non plus le `depth` seul.

  DEUX RANGS, deux usages :
    - Rg.build : rang du LIVRE de la force (min sur les recettes retenues, fluides comptés) : les tiers du journal [FO-RANG] et
      du DC. Calcul complet mesuré à 1,1 à 1,8 × 10⁵ instructions sur le livre réel : gardé par Rg.get (cache par signature).
    - Rg.chain : rang de la DÉCISION (recette choisie par la capitalisation, fermeture des besoins de la décision) : l'ordre de
      propagation des besoins et la porte de rang (L1b, L2). Égal au `depth` d'aujourd'hui sans cycle. Calculé à chaque
      décision, sans cache (quelques milliers d'instructions, mesuré par tests/rang_test.lua §9).

  RANG d'un objet = 1 + le plus grand rang des ingrédients de sa recette la plus basse, sur les recettes RETENUES :
    - recettes du relevé (Ca.data : visibles, actives au départ ou débloquables), OUVERTES pour la force (prédicat `open`,
      même règle que Ca.recipe_open : Rg.open_of) ;
    - faisables : catégorie de la main ou d'une fabrique du relevé (comme shared/ai3/graphe.lua) ;
    - hors recettes de VIDAGE (Rg.unpackers, même règle que Ca.unpackers : un contenant vidé ne crée rien). Mesuré sur le relevé
      du mod : avec elles, remplissage et vidage des contenants font UN cycle de 32 objets (fluides, contenants, soufre), qui
      prendrait un seul rang ;
    - qui rendent au moins un objet non brut.
  BRUT (rang 0) : produit d'une ressource (D.res), fluide pompé (D.pumped), objets donnés par l'appelant (opts.raw = { [objet] =
  vrai } : un fluide qu'un bâtiment rend sans recette, par exemple). Un objet qu'aucune recette retenue ne sait faire n'a pas
  de rang (nil, raison dans `why`).
  Calcul : plus petit point fixe, min sur les recettes UTILISABLES (tous leurs ingrédients ont un rang) de 1 + max des rangs
  des ingrédients ; égalité : la recette au plus petit nom. Une recette ouverte de plus ne fait jamais monter un rang, sauf si
  elle ferme un cycle (contraction).

  CYCLES. Graphe ingrédient -> produit des recettes retenues (bruts exclus), composantes fortement connexes (Tarjan, sans
  récursion), traitées de l'amont vers l'aval. Une composante de plusieurs objets, ou un objet qu'une de ses recettes consomme,
  est un CYCLE :
    1. point fixe interne (les ingrédients hors du cycle ont déjà leur rang définitif) ;
    2. AMORCE pour les membres restés sans rang : un membre sans rang compte pour 0 (on en apporte) ; la recette la plus basse
       donne le rang, seed[objet] = { { membre amorcé, quantité par fabrication } } ;
    3. CONTRACTION : tous les membres qui ont un rang prennent le PLUS GRAND (le rang où tout le cycle tourne). Un seul rang
       par cycle ; rang(ingrédient hors du cycle) < rang(membre) reste vrai, et l'aval du cycle est au-dessus.
  NIVEAU (`level`) : plus long chemin dans le graphe CONTRACTÉ, sur TOUTES les recettes retenues (0 : brut ou sans recette) :
  strictement croissant le long de toute recette retenue hors cycle, quelle que soit la recette choisie (ordre sûr pour
  propager un besoin du produit vers ses ingrédients). Le rang, lui, ne suit que la recette du rang (`rec`).

  SIGNATURE ET CACHE. Le livre préparé (recettes candidates, bruts, contenu) est gardé par relevé (table faible : données des
  prototypes, identiques chez tous les pairs). Rg.signature = contenu du livre + recettes ouvertes. Rg.get(cache, clé, D, open,
  opts) ne refait le calcul que si l'une des deux change (nouvel âge, recherche finie, relevé refait) ; le cache est une table
  de l'appelant (en jeu : mémoire du module, jamais `global`).

  Aucun nom du jeu ici (anti-échelle, tests/iag_test.lua §8). Déterminisme : recettes et objets triés par nom, égalités
  départagées par le nom, listes rendues triées ; aucun pairs qui décide sans tri ; ni hasard ni horloge.

  Rg.build(D, open, opts) -> R = {
    rank = { [objet] = entier >= 0 }, rec = { [objet] = recette du rang }, level = { [objet] = entier >= 0 },
    tiers = { [k] = objets du rang k, triés } (tiers[0] : les bruts), max = plus grand rang,
    cyc = { [objet] = id du cycle (son plus petit membre) }, cycles = { { id, members, rank (nil : aucun membre n'a de rang),
    seeded (vrai : un membre n'a son rang que par une amorce) } } (triés par id),
    seed = { [objet] = { { membre, quantité } } }, none = objets sans rang (triés), why = { [objet] = raison },
    recipes = recettes retenues et ouvertes (triées), n_recipes, n_cand (retenues), n_items (objets non bruts du graphe) }
]]

local Rg = {}

local function sorted_keys(t)
  local ks = {}
  for k, v in pairs(t or {}) do if v then ks[#ks + 1] = k end end
  table.sort(ks)
  return ks
end

local function sorted_copy(list)
  local out = {}
  for i, v in ipairs(list or {}) do out[i] = v end
  table.sort(out)
  return out
end

--- Recettes de VIDAGE : mêmes objets aux mêmes quantités qu'une autre recette, ingrédients et produits échangés, et plus de
--- sortes de produits que d'ingrédients. Même règle que Ca.unpackers (tests/rang_test.lua contrôle l'égalité sur le relevé).
function Rg.unpackers(D)
  local function sig(list)
    local t = {}
    for _, x in ipairs(list) do t[#t + 1] = x.name .. "=" .. x.amount end
    table.sort(t)
    return table.concat(t, ",")
  end
  local names = sorted_copy(D.recipe_list)
  local fwd, out = {}, {}
  for _, rn in ipairs(names) do
    local r = D.recipes[rn]
    fwd[sig(r.ingredients) .. ">" .. sig(r.products)] = true
  end
  for _, rn in ipairs(names) do
    local r = D.recipes[rn]
    if #r.products > #r.ingredients and fwd[sig(r.products) .. ">" .. sig(r.ingredients)] then out[rn] = true end
  end
  return out
end

--- Recette ouverte pour une force (technologies faites `techs`) : même prédicat que Ca.recipe_open.
function Rg.open_of(D, techs)
  techs = techs or {}
  return function(rn)
    local r = D.recipes[rn]
    if not r then return false end
    if r.enabled then return true end
    local t = D.unlocked_by[rn]
    return t ~= nil and techs[t] == true
  end
end

--- open : nil (tout le livre), table { [recette] = vrai } ou fonction (recette -> booléen).
local function is_open(open, rn)
  if open == nil then return true end
  if type(open) == "table" then return open[rn] == true end
  return open(rn) and true or false
end

---------------------------------------------------------------------------------------------------
-- Livre préparé : une fois par relevé (et par jeu de bruts donnés)
---------------------------------------------------------------------------------------------------
local BOOKS = setmetatable({}, { __mode = "k" })

local function book_of(D, opts)
  local extra = sorted_keys((opts or {}).raw)
  local rkey = table.concat(extra, ",")
  local memo = BOOKS[D]
  if memo == nil then
    memo = {}
    BOOKS[D] = memo
  end
  if memo[rkey] then return memo[rkey] end
  local raw = {}
  for _, n in ipairs(sorted_keys(D.res)) do raw[n] = true end
  for _, n in ipairs(sorted_keys(D.pumped)) do raw[n] = true end
  for _, n in ipairs(extra) do raw[n] = true end
  local cats = {}
  for _, c in ipairs(sorted_keys(D.hand)) do cats[c] = true end
  for _, m in ipairs(D.makers or {}) do
    for _, c in ipairs(m.cat_list or sorted_keys(m.cats)) do cats[c] = true end
  end
  local skip = Rg.unpackers(D)
  local cand, parts = {}, {}
  for _, rn in ipairs(sorted_copy(D.recipe_list)) do
    local r = D.recipes[rn]
    local made = false
    for _, p in ipairs(r.products) do if p.amount > 0 and not raw[p.name] then made = true end end
    if made and cats[r.category] and not skip[rn] then
      cand[#cand + 1] = rn
      local ins, outs = {}, {}
      for _, i in ipairs(r.ingredients) do ins[#ins + 1] = i.name .. "=" .. i.amount end
      for _, p in ipairs(r.products) do outs[#outs + 1] = p.name .. "=" .. p.amount end
      table.sort(ins)
      table.sort(outs)
      parts[#parts + 1] = rn .. " " .. r.category .. " " .. table.concat(ins, " ") .. " > " .. table.concat(outs, " ")
    end
  end
  local raw_list = sorted_keys(raw)
  parts[#parts + 1] = "brut " .. table.concat(raw_list, " ")
  local bk = { raw = raw, raw_list = raw_list, cand = cand, content = table.concat(parts, "\n") }
  memo[rkey] = bk
  return bk
end

--- Recettes candidates OUVERTES, en indices de la liste triée : la partie « force » de la signature.
local function open_key(bk, open)
  local idx = {}
  for i, rn in ipairs(bk.cand) do
    if is_open(open, rn) then idx[#idx + 1] = i end
  end
  return table.concat(idx, ",")
end

--- Signature du livre d'une force : contenu des recettes retenues et bruts, puis recettes ouvertes.
function Rg.signature(D, open, opts)
  local bk = book_of(D, opts)
  return bk.content .. "\n#" .. open_key(bk, open)
end

---------------------------------------------------------------------------------------------------
-- Calcul
---------------------------------------------------------------------------------------------------
--- Composantes fortement connexes (Tarjan sans récursion). Rend les composantes de l'AMONT vers l'aval (une composante vient
--- après toutes celles dont elle a un ingrédient), chacune triée par nom.
local function components(nodes, succ)
  local index, low, onst, st, comps = {}, {}, {}, {}, {}
  local counter = 0
  local function enter(v, stack)
    counter = counter + 1
    index[v], low[v] = counter, counter
    st[#st + 1] = v
    onst[v] = true
    stack[#stack + 1] = { v, 0 }
  end
  for _, v0 in ipairs(nodes) do
    if not index[v0] then
      local stack = {}
      enter(v0, stack)
      while #stack > 0 do
        local top = stack[#stack]
        local v, j = top[1], top[2] + 1
        local s = succ[v]
        if j <= #s then
          top[2] = j
          local w = s[j]
          if not index[w] then enter(w, stack)
          elseif onst[w] and index[w] < low[v] then low[v] = index[w] end
        else
          stack[#stack] = nil
          local up = stack[#stack]
          if up and low[v] < low[up[1]] then low[up[1]] = low[v] end
          if low[v] == index[v] then
            local c = {}
            repeat
              local w = st[#st]
              st[#st] = nil
              onst[w] = false
              c[#c + 1] = w
            until w == v
            table.sort(c)
            comps[#comps + 1] = c
          end
        end
      end
    end
  end
  local out = {}
  for i = #comps, 1, -1 do out[#out + 1] = comps[i] end
  return out
end

function Rg.build(D, open, opts)
  local bk = book_of(D, opts)
  local raw = bk.raw
  -- Graphe des recettes retenues et ouvertes (recettes dans l'ordre des noms : prod_of est trié par nom).
  local nodes, isnode, succ, prod_of, loops, recs = {}, {}, {}, {}, {}, {}
  local function node(x)
    if not isnode[x] then
      isnode[x] = true
      nodes[#nodes + 1] = x
      succ[x], prod_of[x] = {}, {}
    end
  end
  for _, rn in ipairs(bk.cand) do
    if is_open(open, rn) then
      recs[#recs + 1] = rn
      local r = D.recipes[rn]
      for _, p in ipairs(r.products) do
        if p.amount > 0 and not raw[p.name] then
          node(p.name)
          local pl = prod_of[p.name]
          if pl[#pl] ~= rn then pl[#pl + 1] = rn end
          for _, i in ipairs(r.ingredients) do
            if not raw[i.name] then
              node(i.name)
              local sl = succ[i.name]
              sl[#sl + 1] = p.name
              if i.name == p.name then loops[p.name] = true end
            end
          end
        end
      end
    end
  end
  table.sort(nodes)
  local comps = components(nodes, succ)
  local rank, rec, level, cyc, seed, why, comp_of = {}, {}, {}, {}, {}, {}, {}
  for _, n in ipairs(bk.raw_list) do rank[n], level[n] = 0, 0 end
  for ci, c in ipairs(comps) do for _, m in ipairs(c) do comp_of[m] = ci end end
  -- 1 + le plus grand rang des ingrédients ; nil si un ingrédient n'a pas de rang (sauf membre amorcé : 0).
  local function value(rn, seeded)
    local top = 0
    local ings = D.recipes[rn].ingredients
    for j = 1, #ings do
      local k = rank[ings[j].name]
      if k == nil then
        if seeded and seeded[ings[j].name] then k = 0 else return nil end
      end
      if k > top then top = k end
    end
    return top + 1
  end
  -- La recette du rang : la première (plus petit nom) qui atteint le rang.
  local function rank_recipe(m, seeded)
    for _, rn in ipairs(prod_of[m]) do
      if value(rn, seeded) == rank[m] then return rn end
    end
    return nil
  end
  local cycles = {}
  for ci, c in ipairs(comps) do
    local cyclic = #c > 1 or loops[c[1]] == true
    if not cyclic then
      local m = c[1]
      local best = nil
      for _, rn in ipairs(prod_of[m]) do
        local v = value(rn)
        if v and (best == nil or v < best) then best = v end
      end
      rank[m] = best
      if best then rec[m] = rank_recipe(m) end
    else
      -- 1. Point fixe interne (les valeurs ne font que baisser ; chacune a une recette pour témoin).
      local changed = true
      while changed do
        changed = false
        for _, m in ipairs(c) do
          for _, rn in ipairs(prod_of[m]) do
            local v = value(rn)
            if v and (rank[m] == nil or v < rank[m]) then rank[m], changed = v, true end
          end
        end
      end
      for _, m in ipairs(c) do if rank[m] then rec[m] = rank_recipe(m) end end
      -- 2. Amorce : valeurs figées (aucun ordre ne compte), membres sans rang à 0.
      local seeded, any, fed = {}, false, false
      for _, m in ipairs(c) do if rank[m] == nil then seeded[m], any = true, true end end
      if any then
        local got = {}
        for _, m in ipairs(c) do
          if seeded[m] then
            for _, rn in ipairs(prod_of[m]) do
              local v = value(rn, seeded)
              if v and (got[m] == nil or v < got[m][1]) then got[m] = { v, rn } end
            end
          end
        end
        for _, m in ipairs(c) do
          if got[m] then
            fed = true
            rank[m], rec[m] = got[m][1], got[m][2]
            local s = {}
            for _, i in ipairs(D.recipes[rec[m]].ingredients) do
              if seeded[i.name] then s[#s + 1] = { i.name, i.amount } end
            end
            table.sort(s, function(a, b) return a[1] < b[1] end)
            seed[m] = s
          end
        end
      end
      -- 3. Contraction : un seul rang, le plus grand des membres.
      local K = nil
      for _, m in ipairs(c) do if rank[m] and (K == nil or rank[m] > K) then K = rank[m] end end
      for _, m in ipairs(c) do
        cyc[m] = c[1]
        if rank[m] then rank[m] = K end
      end
      cycles[#cycles + 1] = { id = c[1], members = c, rank = K, seeded = fed }
    end
    -- Niveau de la composante (toutes ses recettes, ingrédients hors composante).
    local lv, has = 0, false
    for _, m in ipairs(c) do
      for _, rn in ipairs(prod_of[m]) do
        has = true
        for _, i in ipairs(D.recipes[rn].ingredients) do
          local l = level[i.name]
          if comp_of[i.name] ~= ci and l ~= nil and l > lv then lv = l end
        end
      end
    end
    for _, m in ipairs(c) do level[m] = has and lv + 1 or 0 end
  end
  -- Rangs, objets sans rang et raisons (objets dans l'ordre des noms).
  local tiers, none, maxk = { [0] = {} }, {}, 0
  for _, n in ipairs(bk.raw_list) do tiers[0][#tiers[0] + 1] = n end
  for _, m in ipairs(nodes) do
    local k = rank[m]
    if k then
      tiers[k] = tiers[k] or {}
      tiers[k][#tiers[k] + 1] = m
      if k > maxk then maxk = k end
    else
      none[#none + 1] = m
      if #prod_of[m] == 0 then why[m] = "aucune recette retenue"
      elseif cyc[m] then why[m] = "cycle sans entree ni amorce"
      else
        local miss = nil -- le plus petit nom (l'ordre des ingrédients ne compte pas)
        for _, i in ipairs(D.recipes[prod_of[m][1]].ingredients) do
          if rank[i.name] == nil and (miss == nil or i.name < miss) then miss = i.name end
        end
        why[m] = "ingredient sans rang : " .. tostring(miss)
      end
    end
  end
  for k = 1, maxk do tiers[k] = tiers[k] or {} end
  table.sort(cycles, function(a, b) return a.id < b.id end)
  return { rank = rank, rec = rec, level = level, tiers = tiers, max = maxk, cyc = cyc, cycles = cycles, seed = seed,
    none = none, why = why, recipes = recs, n_recipes = #recs, n_cand = #bk.cand, n_items = #nodes }
end

---------------------------------------------------------------------------------------------------
-- Rang de la DÉCISION : recette choisie, fermeture des graines (docs/TODO_VIDEO.md §H)
---------------------------------------------------------------------------------------------------
--- Classe un objet de la fermeture : vrai s'il a une recette choisie (rec[i]) ; sinon feuille au rang 0, avec sa raison.
local function classify(D, pick, i, rec, why)
  if D.res[i] then return false end
  local r, w = pick(i)
  if not r then
    why[i] = w or "aucune recette"
    return false
  elseif r.fluid then
    why[i] = "limite : fluide (" .. r.name .. ")"
    return false
  end
  rec[i] = r
  return true
end

--- Ordre de propagation (rang décroissant, nom), liste (rang croissant, nom), plus grand rang.
local function chain_result(nodes, rank, rec, why, cyc, seed, cycles)
  local order, list, maxk = {}, {}, 0
  for j, n in ipairs(nodes) do
    order[j], list[j] = n, n
    if rank[n] > maxk then maxk = rank[n] end
  end
  table.sort(order, function(a, b)
    if rank[a] ~= rank[b] then return rank[a] > rank[b] end
    return a < b
  end)
  table.sort(list, function(a, b)
    if rank[a] ~= rank[b] then return rank[a] < rank[b] end
    return a < b
  end)
  return { rank = rank, rec = rec, why = why, cyc = cyc, seed = seed, cycles = cycles, order = order, list = list,
    max = maxk, n_items = #nodes }
end

--- Chemin RAPIDE : un parcours en profondeur (pile explicite) calcule le rang en post-ordre ; rend nil dès qu'un ingrédient
--- est un objet en cours de parcours (arc de retour : la fermeture a un cycle, le chemin complet le contracte).
local function chain_fast(D, pick, seeds)
  local rec, why, rank, state, nodes = {}, {}, {}, {}, {}
  local function enter(i)
    state[i] = 1
    nodes[#nodes + 1] = i
    if classify(D, pick, i, rec, why) then return true end
    rank[i], state[i] = 0, 2
    return false
  end
  for _, s0 in ipairs(sorted_copy(seeds)) do
    if state[s0] == nil and enter(s0) then
      local stack = { { s0, 0, 0 } } -- objet, ingrédient suivant, plus grand rang des ingrédients vus
      while #stack > 0 do
        local fr = stack[#stack]
        local ings = rec[fr[1]].ingredients
        local j = fr[2] + 1
        if j <= #ings then
          fr[2] = j
          local w = ings[j].name
          local s = state[w]
          if s == 1 then return nil end
          if s == nil and enter(w) then stack[#stack + 1] = { w, 0, 0 }
          elseif rank[w] > fr[3] then fr[3] = rank[w] end
        else
          local k = fr[3] + 1
          rank[fr[1]], state[fr[1]] = k, 2
          stack[#stack] = nil
          local up = stack[#stack]
          if up and k > up[3] then up[3] = k end
        end
      end
    end
  end
  return chain_result(nodes, rank, rec, why, {}, {}, {})
end

--- Chemin COMPLET (fermeture avec cycle) : composantes de Tarjan sur la fermeture, un rang par composante.
local function chain_full(D, pick, seeds)
  local rec, why, nodes, seen, stack = {}, {}, {}, {}, {}
  local sl = sorted_copy(seeds)
  for j = #sl, 1, -1 do stack[#stack + 1] = sl[j] end
  while #stack > 0 do
    local i = stack[#stack]
    stack[#stack] = nil
    if not seen[i] then
      seen[i] = true
      nodes[#nodes + 1] = i
      if classify(D, pick, i, rec, why) then
        for _, ing in ipairs(rec[i].ingredients) do if not seen[ing.name] then stack[#stack + 1] = ing.name end end
      end
    end
  end
  table.sort(nodes)
  local succ, loops = {}, {}
  for _, i in ipairs(nodes) do succ[i] = {} end
  for _, i in ipairs(nodes) do
    for _, ing in ipairs((rec[i] or {}).ingredients or {}) do
      local s = succ[ing.name]
      s[#s + 1] = i
      if ing.name == i then loops[i] = true end
    end
  end
  local comps = components(nodes, succ)
  local rank, cyc, seed, comp_of, cycles = {}, {}, {}, {}, {}
  for ci, c in ipairs(comps) do for _, m in ipairs(c) do comp_of[m] = ci end end
  for ci, c in ipairs(comps) do
    local top, leaf = 0, true
    for _, m in ipairs(c) do
      if rec[m] then
        leaf = false
        for _, ing in ipairs(rec[m].ingredients) do
          if comp_of[ing.name] ~= ci and rank[ing.name] > top then top = rank[ing.name] end
        end
      end
    end
    local k = leaf and 0 or top + 1
    for _, m in ipairs(c) do rank[m] = k end
    if #c > 1 or loops[c[1]] then
      for _, m in ipairs(c) do
        cyc[m] = c[1]
        local s = {}
        for _, ing in ipairs(rec[m].ingredients) do
          if comp_of[ing.name] == ci then s[#s + 1] = { ing.name, ing.amount } end
        end
        table.sort(s, function(a, b) return a[1] < b[1] end)
        seed[m] = s
      end
      cycles[#cycles + 1] = { id = c[1], members = c, rank = k }
    end
  end
  table.sort(cycles, function(a, b) return a.id < b.id end)
  return chain_result(nodes, rank, rec, why, cyc, seed, cycles)
end

--- Rang sur la recette que la capitalisation UTILISE, pick(objet) -> recette | nil, raison (en jeu : choose_recipe de
--- shared/ai3/capitalisation.lua, la même que la propagation des besoins), sur la fermeture des graines `seeds` (liste de
--- noms : puits, besoins des buts, manques des ordres ouverts, packs, combustible). Feuilles au rang 0, comme `depth` de
--- Ca.requirements : ressource, objet sans recette choisie (raison de pick), recette à fluide (« limite : fluide »). Cycles
--- (composantes de Tarjan, boucle comprise) : un seul rang, 1 + max des ingrédients EXTERNES ; seed[objet] = ingrédients
--- internes de sa recette (quantité par fabrication) : l'arc qui referme le cycle ne se propage pas, c'est l'amorce.
--- Chemin rapide sans cycle (un parcours), chemin complet (Tarjan) dès qu'un cycle est vu ; `full` = vrai : chemin complet
--- d'office (test d'égalité des deux chemins). Sans cycle, rang = `depth` et `list` = `req.list` (tests/rang_test.lua §9).
--- Aucun cache : pick dépend de l'état de la décision (catégories présentes, machines disponibles), pas du seul livre.
--- Rend { rank, rec = { [objet] = recette (table) }, why, cyc, seed, cycles = { { id, members, rank } }, order (rang
--- décroissant puis nom : ordre de propagation), list (rang croissant puis nom), max, n_items }.
function Rg.chain(D, pick, seeds, full)
  local R = (not full) and chain_fast(D, pick, seeds) or nil
  return R or chain_full(D, pick, seeds)
end

---------------------------------------------------------------------------------------------------
-- Cache par force
---------------------------------------------------------------------------------------------------
--- Rang de la force `key` : refait seulement si le contenu du livre ou ses recettes ouvertes ont changé. cache = table de
--- l'appelant ({} au départ). Rend R et vrai s'il a été recalculé.
function Rg.get(cache, key, D, open, opts)
  local bk = book_of(D, opts)
  local ok = open_key(bk, open)
  local e = cache[key]
  if e and e.content == bk.content and e.open == ok then return e.R, false end
  local R = Rg.build(D, open, opts)
  cache[key] = { content = bk.content, open = ok, R = R }
  return R, true
end

--- Ligne de journal [FO-RANG] d'un recalcul.
function Rg.text(R, who)
  local per = {}
  for k = 0, R.max do per[#per + 1] = k .. ":" .. #(R.tiers[k] or {}) end
  local cy = {}
  for _, c in ipairs(R.cycles) do
    if #c.members > 1 or c.seeded or c.rank == nil then
      cy[#cy + 1] = string.format("%s(%d, rang %s%s)", c.id, #c.members, tostring(c.rank), c.seeded and ", amorce" or "")
    end
  end
  return string.format("[FO-RANG] %s : %d recettes ouvertes sur %d, %d objets, rangs 0 a %d (%s), cycles %d [%s], sans rang %d",
    tostring(who), R.n_recipes, R.n_cand, R.n_items, R.max, table.concat(per, " "), #R.cycles, table.concat(cy, " "), #R.none)
end

---------------------------------------------------------------------------------------------------
-- Journal et signature du rang de la DÉCISION (lot VIDEO-TRACES, G34). Entrée : résultat de Rg.chain (champs rank, list, cycles,
-- max, n_items, rec, why). Pur : aucun cache, aucune horloge, listes triées (list est déjà dans l'ordre rang croissant, nom).
---------------------------------------------------------------------------------------------------
--- Signature du rang : chaîne courte et déterministe ; change si un objet change de rang, entre ou sort de la fermeture, ou si la
--- liste des cycles change. Empreinte FNV modulo 2^31-1 (entiers, aucun bit à bit) sur « objet=rang; » dans l'ordre de `list`.
function Rg.chain_signature(res)
  local h = 0
  for _, i in ipairs(res.list) do
    local s = i .. "=" .. tostring(res.rank[i]) .. ";"
    for j = 1, #s do h = (h * 31 + s:byte(j)) % 2147483647 end
  end
  return string.format("%d/%d/%d/%d", res.n_items, res.max, #res.cycles, h)
end

--- Ligne [FO-RANG] du rang de la décision (Rg.chain). who = clé de la faction. Le nombre d'objets par rang vient de `list` ;
--- les cycles de plus d'un membre (ou amorcés) sont nommés.
function Rg.text_chain(res, who)
  local per, count = {}, {}
  for _, i in ipairs(res.list) do count[res.rank[i]] = (count[res.rank[i]] or 0) + 1 end
  for k = 0, res.max do per[k + 1] = k .. ":" .. (count[k] or 0) end
  local cy = {}
  for _, c in ipairs(res.cycles) do
    if #c.members > 1 or (res.seed[c.id] ~= nil) then
      cy[#cy + 1] = string.format("%s(%d, rang %s)", c.id, #c.members, tostring(c.rank))
    end
  end
  local nrec, nwhy = 0, 0
  for _, i in ipairs(res.list) do
    if res.rec[i] then nrec = nrec + 1 end
    if res.why[i] ~= nil then nwhy = nwhy + 1 end
  end
  return string.format("[FO-RANG] %s : %d objets, %d recettes choisies, %d sans recette ou a fluide, rangs 0 a %d (%s), cycles %d [%s]",
    tostring(who), res.n_items, nrec, nwhy, res.max, table.concat(per, " "), #res.cycles, table.concat(cy, " "))
end

return Rg
