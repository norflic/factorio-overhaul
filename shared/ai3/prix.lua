--[[
  Lots SOUS-PRODUITS et VALEURS-ÂGE (5/11, décisions du lead) : VALEUR des objets (MU), règle PURE, PAS ENCORE BRANCHÉE.
  Ca.values (shared/ai3/capitalisation.lua) reste la règle en jeu jusqu'à la bascule du relevé des recettes et au recalage des
  tests qui le lisent (lot FIXTURE-RECETTES). Critères : fo-logs/2026-11-05_SOUS-PRODUITS/CRITERES.md. Aucun nom du jeu
  (tests/iag_test.lua §8).

  Règle (point fixe min-plus, comme Ca.values, avec ces différences) :
    1. vidages de contenant écartés (o.skip, Ca.unpackers de l'appelant) ;
    2. FORME NETTE : un objet à la fois entrée et sortie d'une recette ne compte que pour la différence (catalyseur) ;
    3. PRODUIT PRINCIPAL déclaré (champ `main` de Ca.data, main_product du relevé) : la recette ne fixe que le prix de ce produit,
       qui porte le coût de la recette MOINS la valeur de ses sous-produits par leurs propres voies (jamais sous 0) ;
    4. DÉCHET : un sous-produit d'une recette à produit principal qui n'a aucune autre voie vaut 0 ;
    5. RÉCUPÉRATION : une recette dont l'entrée principale (l'ingrédient solide le plus nombreux ; sans solide, le fluide le plus
       nombreux ; égalité : ordre des noms) est un déchet ne fixe le prix d'un produit que si aucune autre voie ne le fixe (sa
       capacité est bornée par la production du déchet ; le point fixe ignore les quantités) ;
    6. CO-PRODUITS sans produit principal déclaré : parts égales par unité (comme Ca.values) ;
    7. les valeurs des sous-produits viennent du tour précédent ; au plus o.max_rounds tours ; sans stabilité, la règle rend les
       prix SANS crédit (B2), déterministes, et info.fallback le dit.
  VALEURS-ÂGE : Px.by_age, mêmes prix sur les seules recettes d'âge <= k (âge fourni par l'appelant ; recette sans âge
  écartée), gardés en cache par âge.

  Px.values(D, o) -> mu, best, info
    D : données de Ca.data (res_list, res, recipe_list, recipes { energy, ingredients, products, main }).
    o.raw_mu, o.time_mu : Ca.RAW_MU et Ca.TIME_MU de l'appelant ; o.skip : { [recette] = vrai } écartées ; o.allowed :
    { [recette] = vrai } (nil : toutes) ; o.credit (défaut vrai) ; o.max_rounds (défaut Px.MAX_ROUNDS).
    info = { waste = { objets à 0, triés }, recovery = { recettes de récupération, triées }, rounds, fallback }.
  Px.by_age(D, o, age_of, k, cache) -> mu, best, info ; age_of = { [recette] = âge } ; cache = table gardée par l'appelant.
]]

local Px = {}

Px.MAX_ROUNDS = 8 -- tours de crédits au plus (2 suffisent sur le relevé du 5/11)
Px.TOL = 1e-9     -- écart relatif sous lequel deux tours sont égaux
local EPS = 1e-12

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

--- Forme nette d'une recette (listes triées par nom, comme Ca.data), produit principal et entrée principale.
local function net_of(r)
  local inq, outq, fl = {}, {}, {}
  for _, i in ipairs(r.ingredients) do inq[i.name] = (inq[i.name] or 0) + i.amount; fl[i.name] = i.fluid end
  for _, p in ipairs(r.products) do outq[p.name] = (outq[p.name] or 0) + p.amount end
  local ing, prod = {}, {}
  for _, n in ipairs(sorted_keys(inq)) do
    local a = inq[n] - math.min(inq[n], outq[n] or 0)
    if a > EPS then ing[#ing + 1] = { name = n, amount = a, fluid = fl[n] } end
  end
  for _, n in ipairs(sorted_keys(outq)) do
    local a = outq[n] - math.min(outq[n], inq[n] or 0)
    if a > EPS then prod[#prod + 1] = { name = n, amount = a } end
  end
  local main = nil
  if #prod >= 2 and r.main then
    for _, p in ipairs(prod) do if p.name == r.main then main = p.name end end
  end
  local principal = nil
  for _, want_fluid in ipairs({ false, true }) do
    if not principal then
      local best = nil
      for _, i in ipairs(ing) do
        if (i.fluid == true) == want_fluid and (best == nil or i.amount > best.amount + EPS) then best = i end
      end
      principal = best and best.name or nil
    end
  end
  return { energy = r.energy, ingredients = ing, products = prod, main = main, principal = principal }
end

local function prepare(D, o)
  local ctx = { D = D, raw_mu = o.raw_mu or 1, time_mu = o.time_mu or 0.1, net = {}, list = {} }
  for _, rn in ipairs(D.recipe_list) do
    if not (o.skip and o.skip[rn]) and (o.allowed == nil or o.allowed[rn]) then
      local n = net_of(D.recipes[rn])
      if #n.products > 0 then
        ctx.net[rn] = n
        ctx.list[#ctx.list + 1] = rn
      end
    end
  end
  return ctx
end

--- Point fixe. credit : { [objet] = valeur } des sous-produits (nil : aucun crédit) ; fixed : { [objet] = 0 } (déchets) ;
--- rec : { [recette] = vrai } de récupération ; open : objets que la récupération a le droit de fixer (nil : aucun).
local function fixpoint(ctx, credit, fixed, rec, open)
  local D = ctx.D
  local mu, best = {}, {}
  for _, n in ipairs(D.res_list) do mu[n] = ctx.raw_mu * D.res[n].mining_time end
  for _, n in ipairs(sorted_keys(fixed)) do mu[n] = fixed[n] end
  local changed
  local function offer(rn, name, u)
    if D.res[name] or fixed[name] ~= nil then return end
    if rec[rn] and not (open and open[name]) then return end
    if mu[name] == nil or u < mu[name] - EPS then
      mu[name], best[name], changed = u, rn, true
    end
  end
  for _ = 1, #ctx.list + 1 do
    changed = false
    for _, rn in ipairs(ctx.list) do
      local r = ctx.net[rn]
      local input, ok = r.energy * ctx.time_mu, true
      for _, i in ipairs(r.ingredients) do
        local m = mu[i.name]
        if m == nil then ok = false break end
        input = input + m * i.amount
      end
      if ok then
        if #r.products == 1 then
          offer(rn, r.products[1].name, input / r.products[1].amount)
        elseif r.main then
          local cr, am = 0, 0
          for _, p in ipairs(r.products) do
            if p.name == r.main then am = p.amount
            elseif credit then cr = cr + p.amount * (credit[p.name] or 0) end
          end
          offer(rn, r.main, math.max(0, input - cr) / am)
        else
          local tot = 0
          for _, p in ipairs(r.products) do tot = tot + p.amount end
          for _, p in ipairs(r.products) do offer(rn, p.name, input / tot) end
        end
      end
    end
    if not changed then break end
  end
  return mu, best
end

--- Prix avec déchets fixés et récupération écartée, puis récupération pour les seuls objets restés sans prix.
local function settle(ctx, credit, waste, rec)
  local mu, best = fixpoint(ctx, credit, waste, rec, nil)
  local open = {}
  for _, rn in ipairs(ctx.list) do
    if rec[rn] then
      for _, p in ipairs(ctx.net[rn].products) do if mu[p.name] == nil then open[p.name] = true end end
    end
  end
  if next(open) ~= nil then mu, best = fixpoint(ctx, credit, waste, rec, open) end
  return mu, best
end

local function same(a, b)
  for _, n in ipairs(sorted_keys(a)) do
    local x, y = a[n], b[n]
    if y == nil or math.abs(x - y) > Px.TOL * math.max(1, math.abs(x)) then return false end
  end
  for _, n in ipairs(sorted_keys(b)) do if a[n] == nil then return false end end
  return true
end

function Px.values(D, o)
  o = o or {}
  local ctx = prepare(D, o)
  -- Déchets : sous-produits restés sans prix quand chaque recette à principal ne fixe que son principal.
  local mu0 = fixpoint(ctx, nil, {}, {}, nil)
  local waste = {}
  for _, rn in ipairs(ctx.list) do
    local r = ctx.net[rn]
    if r.main then
      for _, p in ipairs(r.products) do
        if p.name ~= r.main and mu0[p.name] == nil and not D.res[p.name] then waste[p.name] = 0 end
      end
    end
  end
  local rec = {}
  for _, rn in ipairs(ctx.list) do
    local pr = ctx.net[rn].principal
    if pr and waste[pr] ~= nil then rec[rn] = true end
  end
  local info = { waste = sorted_keys(waste), recovery = sorted_keys(rec), rounds = 0, fallback = false }
  local mu2, best2 = settle(ctx, nil, waste, rec)
  if o.credit == false then return mu2, best2, info end
  local prev, max_rounds = mu2, o.max_rounds or Px.MAX_ROUNDS
  for k = 1, max_rounds do
    local mu, best = settle(ctx, prev, waste, rec)
    info.rounds = k
    if same(prev, mu) then return mu, best, info end
    prev = mu
  end
  info.fallback = true
  return mu2, best2, info
end

--- Prix à l'âge k : recettes d'âge connu <= k ; cache[k] gardé (un calcul par âge).
function Px.by_age(D, o, age_of, k, cache)
  if cache and cache[k] then return cache[k].mu, cache[k].best, cache[k].info end
  local allowed = {}
  for _, rn in ipairs(D.recipe_list) do
    local a = age_of[rn]
    if a and a <= k then allowed[rn] = true end
  end
  local oo = {}
  for _, key in ipairs(sorted_keys(o or {})) do oo[key] = o[key] end
  oo.allowed = allowed
  local mu, best, info = Px.values(D, oo)
  info.age = k
  if cache then cache[k] = { mu = mu, best = best, info = info } end
  return mu, best, info
end

return Px
