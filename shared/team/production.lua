--[[
  SOLVEUR DE DÉBITS ET DIAGNOSTIC DES MODULES (lot IA1-e1, docs/EQUIPES_PNJ.md §6.1 à §6.3, §6.6 (6), §16). Lua PUR :
  aucune API du jeu. Lu hors jeu (tests/ia1_production_test.lua) et en moteur réel (scénario greffé `ia1-diag`).

  1. SOLVEUR (P.solve) : des objectifs en objets par minute aux machines, flux et besoins bruts.
     - livre de recettes RÉEL : P.book lit le format de `tests/datastage/harness.lua --dump-recipes` (vanilla + mod,
       tests/fixtures/recipes_ia1e.lua) ou celui que le scénario tire de game.recipe_prototypes (même forme) ;
     - machines à leur vitesse réelle : M.spec de shared/team/modules.lua (vanilla relue dans data/base ; niveaux
       fo-lvl-<famille>-<n> par L.apply_stat) ; modules MULTIPLIÉS (MOD-1, D-15) : facteur de vitesse = Π (1 + b),
       facteur d'énergie = Π (1 + c) (MM.target, bornes du moteur comprises), productivité ADDITIVE tant que
       MM.PRODUCTIVITY_MULTIPLIES est faux (Q-M4) ; le drain n'est pas multiplié (F202) ;
     - plafond de 60 fabrications par seconde et par machine (F191), levé par les recettes par lots (MOD-2) quand le
       livre en contient pour la recette : lot choisi par RL.choose, débit de base inchangé (mêmes rapports) ;
     - expansion descendante en débits : ordre topologique (post-ordre d'un parcours en profondeur, listes triées),
       machines = débit ÷ (produits par cycle × (1 + productivité)) × durée ÷ vitesse ; boucle refusée ;
     - pétrole par blocs à ratio fixe : le gaz vient du raffinage de base (P.DEFAULT_RECIPE), sans craquage ;
     - besoins bruts : foreuses (vitesse ÷ temps d'extraction), chevalets (10/s × rendement), pompes de rive ;
     - énergie FERMÉE : charbon des fours à combustible et des chaudières (1 charbon = 4 MJ, rendement 1) ajouté à la
       demande, puis nouvelle passe, jusqu'au point fixe (les foreuses de charbon consomment elles aussi).
  2. VALEURS (P.values) : MU de chaque objet par le chemin le moins cher (même règle que X0, tests/epochs_test.lua :
     matière brute à 1 MU (ρ pour une matière dense), fluide à 0,1 MU l'unité, eau et vapeur gratuites) ; la plaque
     de fer vaut 1 MU. Coût en MU d'un bâtiment posé (niveaux compris : objet de base + L.cost de chaque niveau).
  3. DIAGNOSTIC (P.diagnose) d'un module mesuré (statistiques de la force et machines témoins, §6.2) :
     - « ok » : déficit ≤ 15 % de l'objectif ;
     - « affame » : sortie < 60 % du nominal ET ingrédient manquant chez les témoins : on traite l'AMONT (déficit
       d'entrée chiffré, plan du solveur pour le combler), jamais l'aval ;
     - « bloque » : sortie < 60 % du nominal, sortie pleine chez les témoins : l'aval ne prend pas ;
     - « capacite » : sinon, la capacité installée est sous l'objectif : options chiffrées.
  4. OPTIONS ET CHOIX (P.options, P.choose, §6.3) : agrandir (extension du gabarit), améliorer d'un niveau (sur place,
     L.cost), remplacer de palier (variante d'ère de M.upgrade_plan : nouveaux bâtiments − anciens rendus + production
     perdue pendant la reconstruction, ESTIMÉE), construire un module neuf (+20 % de pénalité de complexité). Pour
     chacune : coût en MU, débit ajouté, gain en MU/min (débit ajouté × MU de l'objet), retour sur investissement
     T = coût ÷ gain (minutes) : c'est ce que lit IA2-d (capitalisation). Choix : le moins cher par unité de débit
     UTILE (au plus le déficit), à 20 % près en faveur de l'option déjà engagée.
  5. RÈGLE D'AUTOMATISATION (§6.6 (6), greffe P1) : un flux de plus de 60/min, nécessaire plus de 10 min, sur 64 tuiles
     ou moins, passe par un tapis ou une conduite. Seuils identiques à O.needs_automation (shared/team/org.lua),
     recoupés par le test ; org.lua n'est pas requis ici (il ne se charge pas depuis le mod de test).

  POINT D'ACCROCHE (branchement dans l'équipe vivante, après IA1-b) : le manager Production appelle, une fois par
  pensée, P.diagnose(modules, ctx) avec, par module posé, son gabarit, son objectif, ses débits LUS (LuaForce
  .item_production_statistics : get_input_count pour la production, get_output_count pour la consommation, écarts
  entre deux pensées) et l'échantillon de ses machines témoins (status, inventaire d'entrée, toutes les 600 ticks) ;
  chaque résultat porte `choice` (option retenue) ou `upstream` (projet amont) ; la file des projets les reprend. Le
  scénario `ia1-diag` montre exactement ces lectures.

  Déterminisme (ARCHITECTURE §2) : listes et tris seulement, aucune table parcourue par pairs sans tri, aucune
  trigonométrie, aucun temps mesuré ; aucune fonction dans les résultats (sérialisables dans global).
]]

local function need(dotted, slashed)
  local ok, res = pcall(require, dotted)
  if ok and type(res) == "table" then return res end
  return require("__factorio-overhaul__/" .. slashed)
end

local L = need("shared.levels.config", "shared/levels/config")
local Mod = need("shared.team.modules", "shared/team/modules")
local MM = need("shared.content.module_mult", "shared/content/module_mult")
local CM = need("shared.content.modules", "shared/content/modules")
local RL = need("shared.content.recipe_lots", "shared/content/recipe_lots")
local X = need("shared.content.epochs", "shared/content/epochs")

local P = {}

P.MAX_NODES = 100              -- au plus 100 nœuds par pensée (§6.1)
P.STARVED_RATIO = 0.60         -- module affamé : moins de 60 % du nominal (§6.2)
P.DEFICIT_TOLERANCE = 0.15     -- déficit toléré (§6.3 : « en déficit de plus de 15 % »)
P.NEW_MODULE_PENALTY = 1.20    -- nouveau module : +20 % de pénalité de complexité (§6.3, greffe P1)
P.HYSTERESIS = 1.20            -- option déjà engagée gardée à 20 % près (§6.3)
P.SHORTAGE_SHARE = 0.5         -- ingrédient manquant chez les témoins dans au moins la moitié des relevés
P.COAL_KJ = 4000               -- un charbon : 4 MJ
P.BOILER_KW = 1800             -- chaudière vanilla, rendement 1
P.ENGINE_KW = 900              -- machine à vapeur
P.OFFSHORE_PER_S = 1200        -- pompe de rive
P.BUILD_TICKS_PER_ENTITY = 10  -- rythme de pose ESTIMÉ (§6.6 (2)) : sert au coût de la production perdue
P.AUTOMATION = { flow = 60, minutes = 10, distance = 64 }
P.FIXPOINT_PASSES = 40
P.EPS = 1e-9

--- Recette choisie pour un objet produit par plusieurs recettes (blocs à ratio fixe).
P.DEFAULT_RECIPE = { ["petroleum-gas"] = "basic-oil-processing" }
--- Machine par défaut de chaque catégorie (jeu d'essai du §6.1).
P.CATEGORY_MACHINE = {
  ["crafting"] = "assembling-machine-2", ["basic-crafting"] = "assembling-machine-2",
  ["advanced-crafting"] = "assembling-machine-2", ["crafting-with-fluid"] = "assembling-machine-2",
  ["smelting"] = "stone-furnace", ["chemistry"] = "chemical-plant", ["oil-processing"] = "oil-refinery",
}
--- Matières brutes (extraites, jamais fabriquées par le solveur) et leur temps d'extraction vanilla (s).
P.RAW = { ["iron-ore"] = 1, ["copper-ore"] = 1, ["coal"] = 1, ["stone"] = 1, ["uranium-ore"] = 2, ["crude-oil"] = 0,
  ["water"] = 0 }
P.OPTION_ORDER = { "agrandir", "ameliorer", "remplacer", "construire" }

local function sorted_keys(t)
  local k = {}
  for x in pairs(t) do k[#k + 1] = x end
  table.sort(k)
  return k
end
P.sorted_keys = sorted_keys

local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end

---------------------------------------------------------------------------------------------------
-- 1. Livre de recettes
---------------------------------------------------------------------------------------------------
local function norm_amount(x)
  local a = x.amount
  if a == nil and x.amount_min and x.amount_max then a = (x.amount_min + x.amount_max) / 2 end
  if a == nil then a = x[2] or 1 end
  return a * (x.probability or 1)
end

--- Livre normalisé : { recipes = { [nom] = { name, category, energy, hidden, ingredients, products } }, names (triés),
--- producers = { [objet] = { noms triés des recettes visibles qui le produisent } }, lots = { [recette] = {1, 10, 100} } }.
--- `src` : table { [nom] = { category, energy, hidden, ingredients = { {type, name, amount} }, products = {...} } }.
function P.book(src)
  local book = { recipes = {}, names = {}, producers = {}, lots = {} }
  for _, name in ipairs(sorted_keys(src)) do
    local r = src[name]
    local o = { name = name, category = r.category or "crafting", energy = r.energy or 0.5, hidden = r.hidden == true,
      ingredients = {}, products = {} }
    for _, i in ipairs(r.ingredients or {}) do
      local n = i.name or i[1]
      o.ingredients[#o.ingredients + 1] = { name = n, amount = norm_amount(i), fluid = i.type == "fluid" }
    end
    for _, p in ipairs(r.products or {}) do
      local n = p.name or p[1]
      o.products[#o.products + 1] = { name = n, amount = norm_amount(p), fluid = p.type == "fluid" }
    end
    book.recipes[name] = o
    book.names[#book.names + 1] = name
  end
  for _, name in ipairs(book.names) do
    local r = book.recipes[name]
    local base, k = RL.parse(name)
    if base and book.recipes[base] then
      book.lots[base] = book.lots[base] or { 1 }
      local l = book.lots[base]
      l[#l + 1] = k
      table.sort(l)
    end
    if not r.hidden then
      for _, p in ipairs(r.products) do
        if p.amount > 0 then
          book.producers[p.name] = book.producers[p.name] or {}
          local list = book.producers[p.name]
          if list[#list] ~= name then list[#list + 1] = name end
        end
      end
    end
  end
  return book
end

local function product_amount(r, item)
  local a = 0
  for _, p in ipairs(r.products) do if p.name == item then a = a + p.amount end end
  for _, i in ipairs(r.ingredients) do if i.name == item then a = a - i.amount end end
  return a
end
P.product_amount = product_amount

--- Est-ce une matière brute pour le solveur ?
function P.is_raw(book, item, opts)
  if opts and opts.raw and opts.raw[item] ~= nil then return opts.raw[item] and true or false end
  if P.RAW[item] then return true end
  return book.producers[item] == nil
end

--- Recette retenue pour `item` : préférence explicite, recette du même nom, bloc à ratio fixe, puis la première (par
--- nom) dont la catégorie a une machine. nil si aucune.
function P.recipe_for(book, item, opts, machines)
  local function usable(rn)
    local r = book.recipes[rn]
    return r and not r.hidden and product_amount(r, item) > 0 and (not machines or machines[r.category] ~= nil)
  end
  if opts and opts.prefer and opts.prefer[item] then
    if usable(opts.prefer[item]) then return opts.prefer[item] end
    return nil
  end
  if usable(item) then return item end
  if P.DEFAULT_RECIPE[item] and usable(P.DEFAULT_RECIPE[item]) then return P.DEFAULT_RECIPE[item] end
  for _, rn in ipairs(book.producers[item] or {}) do
    if usable(rn) then return rn end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- 2. Machines (vitesse réelle, niveaux, modules multipliés)
---------------------------------------------------------------------------------------------------
--- Effets en centièmes d'une liste de modules { { family = "speed", tier = 1 }, ... } : listes par effet.
local function module_lists(mods)
  local out = { speed = {}, consumption = {}, productivity = {} }
  for _, m in ipairs(mods or {}) do
    local c = CM.cents(m.family, m.tier)
    for _, key in ipairs({ "speed", "consumption", "productivity" }) do
      if c[key] and c[key] ~= 0 then out[key][#out[key] + 1] = c[key] end
    end
  end
  return out
end

--- Machine à sa vitesse réelle : { name, kind, speed, base_speed, speed_factor, energy_factor, prod, usage_kw,
--- drain_kw, burner_kw, categories, rate (chevalet), modules }. `mods` : liste { family, tier } (MOD-1).
function P.machine(name, mods)
  local s = Mod.spec(name)
  if not s then return nil, "machine inconnue : " .. tostring(name) end
  local lists = module_lists(mods)
  local fs = MM.target(lists.speed) / 100
  local fc = MM.target(lists.consumption) / 100
  local prod
  if MM.PRODUCTIVITY_MULTIPLIES then prod = MM.target(lists.productivity) / 100 - 1
  else
    prod = 0
    for _, v in ipairs(lists.productivity) do prod = prod + v end
    prod = prod / 100
  end
  local cats = s.categories
  if not cats and s.kind == "furnace" then cats = { "smelting" } end
  local m = { name = name, kind = s.kind, base_speed = s.speed, speed = s.speed and s.speed * fs, speed_factor = fs,
    energy_factor = fc, prod = prod, usage_kw = (s.usage_kw or 0) * fc, drain_kw = s.drain and (s.usage_kw / 30) or 0,
    burner_kw = (s.burner_kw or 0) * fc, categories = cats, rate = s.rate, modules = copy(mods or {}) }
  return m
end

--- Fabrications par seconde (équivalent recette de base) d'une machine sur une recette : plafond de 60/s par machine
--- (F191), levé par les lots du livre. Rend cps, lot, plafonné (bool).
function P.crafts_per_s(m, r, lots)
  local w = m.speed / r.energy
  local avail = lots or { 1 }
  local kmax = avail[#avail]
  if w > RL.CAP * kmax + P.EPS then return RL.CAP * kmax, kmax, true end
  local k = RL.choose(1, RL.milli(m.speed), math.max(1, RL.milli(r.energy)), avail)
  return w, k, false
end

local function resolve_machines(opts)
  local out = {}
  local given = (opts and opts.machines) or {}
  local cats = {}
  for _, c in ipairs(sorted_keys(P.CATEGORY_MACHINE)) do cats[#cats + 1] = c end
  for _, c in ipairs(sorted_keys(given)) do if not P.CATEGORY_MACHINE[c] then cats[#cats + 1] = c end end
  for _, c in ipairs(cats) do
    local v = given[c]
    if v == nil then v = P.CATEGORY_MACHINE[c] end
    if v ~= false then
      if type(v) == "string" then v = P.machine(v) end
      out[c] = v
    end
  end
  return out
end

local function resolve_extract(opts)
  local e = (opts and opts.extract) or {}
  local drill = e.drill or "electric-mining-drill"
  if type(drill) == "string" then drill = P.machine(drill) end
  local pump = e.pumpjack or "pumpjack"
  if type(pump) == "string" then pump = P.machine(pump) end
  return { drill = drill, pumpjack = pump, yield = e.yield or 1, mining_time = e.mining_time or {} }
end

---------------------------------------------------------------------------------------------------
-- 3. Solveur
---------------------------------------------------------------------------------------------------
local function ceil_eps(x) return math.ceil(x - 1e-6) end

local function norm_targets(targets)
  local list = {}
  if targets[1] then
    for _, t in ipairs(targets) do list[#list + 1] = { item = t.item or t[1], per_min = t.per_min or t[2] } end
  else
    for _, k in ipairs(sorted_keys(targets)) do list[#list + 1] = { item = k, per_min = targets[k] } end
  end
  table.sort(list, function(a, b) return a.item < b.item end)
  return list
end

local function one_pass(book, list, extra, opts, machines, ex)
  local recipe_of, order, state = {}, {}, {}
  local err
  local function visit(item)
    if state[item] == 2 then return true end
    if state[item] == 1 then err = "boucle de recettes autour de " .. item; return false end
    state[item] = 1
    local rn
    if not P.is_raw(book, item, opts) then
      rn = P.recipe_for(book, item, opts, machines)
      if not rn then err = "aucune recette utilisable pour " .. item; return false end
    end
    recipe_of[item] = rn
    if rn then
      for _, ing in ipairs(book.recipes[rn].ingredients) do
        if not visit(ing.name) then return false end
      end
    end
    state[item] = 2
    order[#order + 1] = item
    if #order > P.MAX_NODES then err = "plus de " .. P.MAX_NODES .. " nœuds"; return false end
    return true
  end
  local demand = {}
  for _, t in ipairs(list) do
    if not visit(t.item) then return nil, err end
    demand[t.item] = (demand[t.item] or 0) + t.per_min
  end
  for _, k in ipairs(sorted_keys(extra)) do
    if extra[k] > 0 then
      if not visit(k) then return nil, err end
      demand[k] = (demand[k] or 0) + extra[k]
    end
  end
  local nodes, raw, flows = {}, {}, {}
  local byproducts = {}
  local power = { avg_kw = 0, max_kw = 0, usage_max_kw = 0 }
  local burner_kw = 0
  for i = #order, 1, -1 do
    local item = order[i]
    local q = demand[item] or 0
    local rn = recipe_of[item]
    if rn and q > P.EPS then
      local r = book.recipes[rn]
      local m = machines[r.category]
      local out = product_amount(r, item) * (1 + m.prod)
      local crafts = q / 60 / out
      local cps, lot, capped = P.crafts_per_s(m, r, book.lots[rn])
      local n = crafts / cps
      local nc = ceil_eps(n)
      local node = { item = item, recipe = rn, category = r.category, machine = m.name, per_min = q, crafts_per_s = crafts,
        machine_cps = cps, lot = lot, capped = capped, machines = n, machines_ceil = nc,
        kw_avg = n * m.usage_kw + nc * m.drain_kw, kw_max = nc * (m.usage_kw + m.drain_kw), burner_kw = n * m.burner_kw }
      nodes[#nodes + 1] = node
      power.avg_kw = power.avg_kw + node.kw_avg
      power.max_kw = power.max_kw + node.kw_max
      power.usage_max_kw = power.usage_max_kw + nc * m.usage_kw
      burner_kw = burner_kw + node.burner_kw
      for _, ing in ipairs(r.ingredients) do
        local a = ing.amount
        -- catalyseur : la part rendue par la même recette n'est pas consommée
        for _, p in ipairs(r.products) do if p.name == ing.name then a = a - p.amount end end
        if a > 0 then
          local f = crafts * a * 60
          demand[ing.name] = (demand[ing.name] or 0) + f
          flows[#flows + 1] = { item = ing.name, from = recipe_of[ing.name] or "extraction", to = rn, per_min = f, fluid = ing.fluid }
        end
      end
      for _, p in ipairs(r.products) do
        if p.name ~= item then
          local f = crafts * p.amount * (1 + m.prod) * 60
          byproducts[p.name] = (byproducts[p.name] or 0) + f
        end
      end
    elseif not rn and q > P.EPS then
      local row = { item = item, per_min = q }
      if item == "water" then
        row.extractor, row.count = "offshore-pump", q / 60 / P.OFFSHORE_PER_S
      elseif item == "crude-oil" then
        local pj = ex.pumpjack
        row.extractor, row.count = pj.name, q / 60 / (pj.rate * ex.yield)
        row.kw_avg = row.count * pj.usage_kw
        row.kw_max = ceil_eps(row.count) * pj.usage_kw
      elseif P.RAW[item] or ex.mining_time[item] then
        local mt = ex.mining_time[item] or P.RAW[item]
        local d = ex.drill
        row.extractor, row.count = d.name, q / 60 / (d.speed * (1 + d.prod) / mt)
        row.kw_avg = row.count * d.usage_kw
        row.kw_max = ceil_eps(row.count) * d.usage_kw
      else
        row.extractor = "inconnu"
      end
      if row.count then row.count_ceil = ceil_eps(row.count) end
      power.avg_kw = power.avg_kw + (row.kw_avg or 0)
      power.max_kw = power.max_kw + (row.kw_max or 0)
      raw[#raw + 1] = row
    end
  end
  table.sort(nodes, function(a, b) return a.item < b.item end)
  table.sort(raw, function(a, b) return a.item < b.item end)
  table.sort(flows, function(a, b)
    if a.item ~= b.item then return a.item < b.item end
    if a.from ~= b.from then return a.from < b.from end
    return a.to < b.to
  end)
  local bp = {}
  for _, k in ipairs(sorted_keys(byproducts)) do bp[#bp + 1] = { item = k, per_min = byproducts[k] } end
  return { nodes = nodes, raw = raw, flows = flows, byproducts = bp, power = power, burner_kw = burner_kw,
    demand = demand, nodes_count = #order }
end

--- Solveur. `targets` : { [objet] = par minute } ou liste { {item, per_min} }. opts : machines ({ [catégorie] = nom ou
--- table de P.machine ; false = catégorie absente }), extract ({ drill, pumpjack, yield, mining_time }), prefer, raw,
--- power ("vapeur" par défaut : charbon des chaudières ajouté ; "externe" : aucun), fuel ("coal").
--- Rend le plan { nodes, raw, flows, byproducts, power = { avg_kw, max_kw, usage_max_kw, boilers, engines },
--- coal = { recipes, burners, electricity, total }, passes } ou (nil, raison).
function P.solve(book, targets, opts)
  opts = opts or {}
  local machines = resolve_machines(opts)
  local ex = resolve_extract(opts)
  local list = norm_targets(targets)
  local fuel = opts.fuel or "coal"
  local steam = (opts.power or "vapeur") == "vapeur"
  local extra = {}
  local plan, why
  local passes = 0
  for pass = 1, P.FIXPOINT_PASSES do
    passes = pass
    plan, why = one_pass(book, list, extra, opts, machines, ex)
    if not plan then return nil, why end
    local fuel_kw = plan.burner_kw + (steam and plan.power.avg_kw or 0)
    local want = fuel_kw * 60 / P.COAL_KJ
    if math.abs(want - (extra[fuel] or 0)) <= 1e-9 then break end
    extra[fuel] = want
  end
  local base = one_pass(book, list, {}, opts, machines, ex)
  local fuel_demand = (plan.demand[fuel] or 0)
  local burner_max = 0
  for _, n in ipairs(plan.nodes) do
    local m = machines[n.category]
    burner_max = burner_max + n.machines_ceil * m.burner_kw
  end
  plan.coal = {
    burners = plan.burner_kw * 60 / P.COAL_KJ,
    electricity = steam and (plan.power.avg_kw * 60 / P.COAL_KJ) or 0,
    recipes = base and (base.demand[fuel] or 0) or 0,
    total = fuel_demand,
  }
  -- borne haute : toutes les machines posées au travail en continu (puissance installée), sans nouveau point fixe
  plan.coal.at_max = plan.coal.recipes + (burner_max + (steam and plan.power.max_kw or 0)) * 60 / P.COAL_KJ
  if steam then
    plan.power.boilers = plan.power.avg_kw / P.BOILER_KW
    plan.power.engines = plan.power.avg_kw / P.ENGINE_KW
    plan.power.boilers_max = plan.power.max_kw / P.BOILER_KW
  end
  plan.passes = passes
  plan.demand = nil
  return plan
end

--- Nœud du plan pour un objet (ou nil).
function P.node(plan, item)
  for _, n in ipairs(plan.nodes) do if n.item == item then return n end end
  return nil
end
function P.raw_row(plan, item)
  for _, n in ipairs(plan.raw) do if n.item == item then return n end end
  return nil
end

---------------------------------------------------------------------------------------------------
-- 4. Valeurs en MU (chemin le moins cher, règle X0)
---------------------------------------------------------------------------------------------------
local function rho_table()
  local t = {}
  for _, it in ipairs(X.items or {}) do if it.rho then t[it.name] = it.rho end end
  return t
end

--- MU de chaque objet du livre : { [objet] = MU }. Brut : ρ (1 par défaut) ; fluide : X.FLUID_MU ; eau et vapeur : 0.
--- Recettes visibles seulement (les lots ont les mêmes rapports) ; catalyseurs (même objet des deux côtés) nets.
function P.values(book, opts)
  opts = opts or {}
  local rho = opts.rho or rho_table()
  local free = {}
  for _, f in ipairs(X.FREE_FLUIDS or { "water", "steam" }) do free[f] = true end
  local is_fluid = {}
  for _, rn in ipairs(book.names) do
    local r = book.recipes[rn]
    for _, x in ipairs(r.ingredients) do if x.fluid then is_fluid[x.name] = true end end
    for _, x in ipairs(r.products) do if x.fluid then is_fluid[x.name] = true end end
  end
  local function weight(n)
    if is_fluid[n] then return free[n] and 0 or (rho[n] or X.FLUID_MU or 0.1) end
    return rho[n] or 1
  end
  local mu = {}
  -- brut : matières de P.RAW et objets qu'aucune recette visible ne produit
  for _, rn in ipairs(book.names) do
    for _, x in ipairs(book.recipes[rn].ingredients) do
      if (P.RAW[x.name] or not book.producers[x.name]) and mu[x.name] == nil then mu[x.name] = weight(x.name) end
    end
  end
  for _, k in ipairs(sorted_keys(P.RAW)) do mu[k] = weight(k) end
  local changed, passes = true, 0
  while changed and passes < 400 do
    changed, passes = false, passes + 1
    for _, rn in ipairs(book.names) do
      local r = book.recipes[rn]
      if not r.hidden then
        local input, ok = 0, true
        for _, i in ipairs(r.ingredients) do
          local net = i.amount
          for _, p in ipairs(r.products) do if p.name == i.name then net = net - p.amount end end
          if net > 0 then
            local m = (is_fluid[i.name] and weight(i.name) == 0) and 0 or mu[i.name]
            if m == nil then ok = false; break end
            input = input + m * net
          end
        end
        if ok then
          local W = 0
          local nets = {}
          for pi, p in ipairs(r.products) do
            local net = p.amount
            for _, i in ipairs(r.ingredients) do if i.name == p.name then net = net - i.amount end end
            nets[pi] = net
            if net > 0 then W = W + net * weight(p.name) end
          end
          if W > 0 then
            for pi, p in ipairs(r.products) do
              if nets[pi] > 0 and not P.RAW[p.name] then
                local unit = input * weight(p.name) / W
                if mu[p.name] == nil or unit < mu[p.name] - 1e-12 then mu[p.name] = unit; changed = true end
              end
            end
          end
        end
      end
    end
  end
  return mu, passes
end

local function cost_mu(cost, values)
  local v = 0
  for _, c in ipairs(cost) do
    local u = values[c[1]] or L.item_value[c[1]]
    if not u then return nil, "valeur inconnue : " .. c[1] end
    v = v + c[2] * u
  end
  return v
end
P.cost_mu = cost_mu

--- MU d'un bâtiment POSÉ : objet du même nom ; niveau n d'une famille : objet de base + L.cost des niveaux 2 à n.
function P.entity_mu(name, values)
  local fam, n = L.parse(name)
  if fam and n > 1 then
    local v = values[fam.base]
    if not v then return nil, "valeur inconnue : " .. fam.base end
    for i = 2, n do
      local c, why = cost_mu(L.cost(fam, i), values)
      if not c then return nil, why end
      v = v + c
    end
    return v
  end
  local v = values[name]
  if not v then return nil, "valeur inconnue : " .. tostring(name) end
  return v
end

--- Entités d'un gabarit comptées par nom : { [nom] = n }.
function P.entity_counts(g)
  local c = {}
  for _, e in ipairs(g.entities) do c[e.name] = (c[e.name] or 0) + 1 end
  return c
end

--- MU d'un multiensemble { [nom] = n } (rend MU, ou nil et raison).
function P.counts_mu(counts, values)
  local v = 0
  for _, name in ipairs(sorted_keys(counts)) do
    local u, why = P.entity_mu(name, values)
    if not u then return nil, why end
    v = v + counts[name] * u
  end
  return v
end

---------------------------------------------------------------------------------------------------
-- 5. Diagnostic d'un module mesuré
---------------------------------------------------------------------------------------------------
--- module : { id, g (gabarit posé), item (sortie suivie), demand_per_min (objectif), measured_per_min (production lue),
---   inputs = { { item, measured_per_min (consommation lue) } }, witness = { samples (relevés : un tour sur TOUTES
---   les machines témoins), shortage = { [objet] = relevés où il manquait à au moins une d'elles }, output_full =
---   relevés où au moins une avait sa sortie pleine } } : sur une ligne affamée, le premier assembleur prend tout et
---   le dernier manque toujours (banc ia1-diag, essai 1) ; compté machine par machine, le manque se dilue avec le
---   nombre de témoins. Le nominal et les besoins d'entrée viennent du gabarit
---   (g.nominal, g.inputs, en /s). Rend { id, verdict, nominal_per_min, ratio, deficit_per_min, deficit_ratio,
---   lacking, upstream, options, choice }.
function P.diagnose_one(mod, ctx)
  ctx = ctx or {}
  local g = mod.g
  local nominal = ((g.nominal or {})[mod.item] or 0) * 60
  local measured = mod.measured_per_min or 0
  local demand = mod.demand_per_min or nominal
  local d = { id = mod.id, key = g.key, item = mod.item, nominal_per_min = nominal, measured_per_min = measured,
    demand_per_min = demand }
  d.ratio = nominal > 0 and measured / nominal or 0
  d.deficit_per_min = math.max(0, demand - measured)
  d.deficit_ratio = demand > 0 and d.deficit_per_min / demand or 0
  local w = mod.witness or { samples = 0, shortage = {} }
  -- ingrédient le plus souvent manquant chez les témoins (égalité : ordre des noms)
  local lacking, lack_share = nil, 0
  for _, it in ipairs(sorted_keys(w.shortage or {})) do
    local s = (w.samples or 0) > 0 and w.shortage[it] / w.samples or 0
    if s > lack_share + 1e-12 then lacking, lack_share = it, s end
  end
  local full_share = (w.samples or 0) > 0 and (w.output_full or 0) / w.samples or 0
  d.lack_share, d.full_share = lack_share, full_share
  if d.deficit_ratio <= P.DEFICIT_TOLERANCE + 1e-12 then
    d.verdict = "ok"
  elseif d.ratio < P.STARVED_RATIO and lacking and lack_share >= P.SHORTAGE_SHARE then
    d.verdict = "affame"
    d.lacking = lacking
    -- entrée externe à renforcer : l'ingrédient manquant s'il entre par un port ; sinon (produit dans le module)
    -- l'entrée externe la plus déficitaire (rapport consommé / besoin au nominal)
    local ext = g.inputs or {}
    local item_in = ext[lacking] and lacking or nil
    if not item_in then
      local worst
      for _, it in ipairs(sorted_keys(ext)) do
        local need_in = ext[it] * 60
        local got = 0
        for _, x in ipairs(mod.inputs or {}) do if x.item == it then got = x.measured_per_min end end
        local r = need_in > 0 and got / need_in or 1
        if not worst or r < worst - 1e-12 then worst, item_in = r, it end
      end
    end
    local target_out = math.min(demand, nominal)
    local need_in = ((ext[item_in] or 0) * 60) * (nominal > 0 and target_out / nominal or 0)
    local got = 0
    for _, x in ipairs(mod.inputs or {}) do if x.item == item_in then got = x.measured_per_min end end
    d.upstream = { item = item_in, need_per_min = need_in, supplied_per_min = got, deficit_per_min = math.max(0, need_in - got) }
    if ctx.book and d.upstream.deficit_per_min > 0 then
      local plan = P.solve(ctx.book, { [item_in] = d.upstream.deficit_per_min }, ctx.solve_opts)
      if plan then
        local parts = {}
        for _, n in ipairs(plan.nodes) do parts[#parts + 1] = { item = n.item, machine = n.machine, machines = n.machines, machines_ceil = n.machines_ceil } end
        for _, r in ipairs(plan.raw) do parts[#parts + 1] = { item = r.item, machine = r.extractor, machines = r.count, machines_ceil = r.count_ceil } end
        d.upstream.plan = parts
      end
    end
  elseif d.ratio < P.STARVED_RATIO and full_share >= P.SHORTAGE_SHARE then
    d.verdict = "bloque"
  else
    d.verdict = "capacite"
    local opts, refus = P.options(mod, d, ctx)
    d.options, d.refused = opts, refus
    d.choice = P.choose(opts, ctx.engaged and ctx.engaged[mod.id])
  end
  return d
end

--- Diagnostic d'une liste de modules (ordre de la liste).
function P.diagnose(modules, ctx)
  local out = {}
  for i, m in ipairs(modules) do out[i] = P.diagnose_one(m, ctx) end
  return out
end

---------------------------------------------------------------------------------------------------
-- 6. Options (agrandir, améliorer, remplacer, construire), retour sur investissement, choix
---------------------------------------------------------------------------------------------------
local function counts_diff(new, old)
  local add, rem = {}, {}
  local names = {}
  local seen = {}
  for _, t in ipairs({ new, old }) do
    for _, k in ipairs(sorted_keys(t)) do if not seen[k] then seen[k] = true; names[#names + 1] = k end end
  end
  table.sort(names)
  for _, k in ipairs(names) do
    local dlt = (new[k] or 0) - (old[k] or 0)
    if dlt > 0 then add[k] = dlt elseif dlt < 0 then rem[k] = -dlt end
  end
  return add, rem
end

local function finish_option(o, d, item_mu)
  local deficit = d.deficit_per_min
  o.useful_per_min = math.min(o.added_per_min, deficit)
  o.gain_mu_per_min = o.added_per_min * item_mu
  o.roi_min = (o.gain_mu_per_min > P.EPS) and (o.cost_mu / o.gain_mu_per_min) or math.huge
  o.score = (o.useful_per_min > P.EPS) and (o.cost_mu * (o.penalty or 1) / o.useful_per_min) or math.huge
  o.covers = o.added_per_min + P.EPS >= deficit
  o.valid = o.added_per_min > P.EPS
  return o
end

--- Options chiffrées pour un module en manque de capacité. ctx : values (MU), max_level (plafond des bâtiments, 2 ×
--- centre), free_lots (lots libres), builders (PNJ qui construisent, pour la production perdue). Rend la liste des
--- options valides et la liste des refus { kind, reason }.
function P.options(mod, d, ctx)
  local g = mod.g
  local values = ctx.values or {}
  local item_mu = values[mod.item] or L.item_value[mod.item] or 1
  local out, refus = {}, {}
  local base_counts = P.entity_counts(g)
  local nom0 = ((g.nominal or {})[mod.item] or 0) * 60
  -- agrandir : chaque taille de cur + 1 à max
  local ex = g.extensions and g.extensions[1]
  if ex and g.args then
    local cur = g.args[ex.arg]
    if cur >= ex.max then refus[#refus + 1] = { kind = "agrandir", reason = "extension au maximum (" .. ex.param .. " = " .. cur .. ")" } end
    for n = cur + 1, ex.max do
      local g2, why = Mod.extend(g, n)
      if not g2 then refus[#refus + 1] = { kind = "agrandir", n = n, reason = why }
      else
        local add = counts_diff(P.entity_counts(g2), base_counts)
        local c, why2 = P.counts_mu(add, values)
        if not c then refus[#refus + 1] = { kind = "agrandir", n = n, reason = why2 }
        else
          out[#out + 1] = finish_option({ kind = "agrandir", n = n, label = "agrandir " .. ex.param .. " " .. cur .. " → " .. n,
            cost_mu = c, added_per_min = ((g2.nominal or {})[mod.item] or 0) * 60 - nom0, entities = add }, d, item_mu)
        end
      end
    end
  else
    refus[#refus + 1] = { kind = "agrandir", reason = "gabarit sans extension" }
  end
  -- améliorer d'un niveau, et remplacer au palier d'emprise suivant
  local lv = Mod.leveled(g)
  local max_level = ctx.max_level or 30
  if #lv == 0 then
    refus[#refus + 1] = { kind = "ameliorer", reason = "aucun bâtiment à niveaux" }
  else
    local fam, level = lv[1].family, lv[1].level
    local n_build = 0
    for _, e in ipairs(g.entities) do
      local f2 = L.parse(e.name)
      if f2 == fam then n_build = n_build + 1 end
    end
    if level + 1 > math.min(max_level, fam.max) then
      refus[#refus + 1] = { kind = "ameliorer", reason = "plafond des bâtiments (niveau " .. level .. ", plafond " .. max_level .. ")" }
    else
      local plan = Mod.upgrade_plan(g, level + 1)
      if plan.mode ~= "sur-place" then
        refus[#refus + 1] = { kind = "ameliorer", reason = "niveau " .. (level + 1) .. " : " .. plan.mode .. (plan.reason and (" (" .. tostring(plan.reason) .. ")") or "") }
      else
        local c, why = cost_mu(L.cost(fam, level + 1), values)
        if not c then refus[#refus + 1] = { kind = "ameliorer", reason = why }
        else
          out[#out + 1] = finish_option({ kind = "ameliorer", n = level + 1, label = fam.key .. " niveau " .. level .. " → " .. (level + 1)
            .. " (" .. n_build .. " bâtiments, × " .. string.format("%.3f", plan.gain or 1) .. ")", cost_mu = c * n_build,
            added_per_min = ((plan.g.nominal or {})[mod.item] or 0) * 60 - nom0 }, d, item_mu)
        end
      end
    end
    -- remplacer : prochain palier d'emprise sous le plafond
    local step
    for _, s in ipairs(Mod.footprint_steps(fam)) do if s > level and not step then step = s end end
    if not step or step > math.min(max_level, fam.max) then
      refus[#refus + 1] = { kind = "remplacer", reason = step and ("palier " .. step .. " au-dessus du plafond " .. max_level) or "aucun palier d'emprise" }
    else
      local plan = Mod.upgrade_plan(g, step)
      if plan.mode ~= "remplacer" then
        refus[#refus + 1] = { kind = "remplacer", reason = "palier " .. step .. " : " .. plan.mode .. (plan.reason and (" (" .. tostring(plan.reason) .. ")") or "") }
      else
        local newc = P.entity_counts(plan.g)
        local cn, why = P.counts_mu(newc, values)
        local co, why2 = P.counts_mu(base_counts, values)
        if not cn or not co then refus[#refus + 1] = { kind = "remplacer", reason = why or why2 }
        else
          local n_ent = #plan.g.entities
          local minutes = n_ent * P.BUILD_TICKS_PER_ENTITY / 3600 / math.max(1, ctx.builders or 1)
          local lost = (d.measured_per_min or 0) * item_mu * minutes
          out[#out + 1] = finish_option({ kind = "remplacer", n = step, label = "variante " .. plan.g.key .. " (palier " .. step .. ")",
            cost_mu = math.max(0, cn - co) + lost, lost_mu = lost, rebuild_min = minutes,
            added_per_min = ((plan.g.nominal or {})[mod.item] or 0) * 60 - nom0 }, d, item_mu)
        end
      end
    end
  end
  -- construire un module neuf (même gabarit)
  if (ctx.free_lots or 1) <= 0 then
    refus[#refus + 1] = { kind = "construire", reason = "aucun lot libre" }
  else
    local c, why = P.counts_mu(base_counts, values)
    if not c then refus[#refus + 1] = { kind = "construire", reason = why }
    else
      out[#out + 1] = finish_option({ kind = "construire", n = 1, label = "nouveau module " .. g.key, cost_mu = c,
        penalty = P.NEW_MODULE_PENALTY, added_per_min = nom0 }, d, item_mu)
    end
  end
  local valid = {}
  for _, o in ipairs(out) do
    if o.valid then valid[#valid + 1] = o else refus[#refus + 1] = { kind = o.kind, n = o.n, reason = "aucun débit ajouté" } end
  end
  return valid, refus
end

local KIND_RANK = {}
for i, k in ipairs(P.OPTION_ORDER) do KIND_RANK[k] = i end

--- Option retenue : la moins chère par unité de débit UTILE (coût × pénalité ÷ min(débit ajouté, déficit)) ; égalité :
--- ordre agrandir, améliorer, remplacer, construire, puis taille. `engaged` = { kind, n } : gardée si son score est au
--- plus 1,2 × le meilleur. Rend l'option (copie) ou nil.
function P.choose(options, engaged)
  local best
  for _, o in ipairs(options or {}) do
    if o.valid and o.score < math.huge then
      if not best or o.score < best.score - 1e-9 or (math.abs(o.score - best.score) <= 1e-9 and
        (KIND_RANK[o.kind] < KIND_RANK[best.kind] or (o.kind == best.kind and o.n < best.n))) then best = o end
    end
  end
  if best and engaged then
    for _, o in ipairs(options) do
      if o.valid and o.kind == engaged.kind and (engaged.n == nil or o.n == engaged.n) and o.score <= best.score * P.HYSTERESIS + 1e-9 then
        local c = copy(o)
        c.kept = true
        return c
      end
    end
  end
  return best and copy(best) or nil
end

---------------------------------------------------------------------------------------------------
-- 7. Règle d'automatisation (§6.6 (6))
---------------------------------------------------------------------------------------------------
function P.needs_automation(per_min, minutes, distance)
  local A = P.AUTOMATION
  return per_min > A.flow and minutes > A.minutes and distance <= A.distance
end

--- Flux du plan à automatiser : chaque flux reçoit `automate` (bool). opts : minutes (durée du besoin), distance
--- (tuiles entre les modules ; défaut : un pas de lot, 28). Rend le nombre de flux à automatiser.
function P.automation(plan, opts)
  opts = opts or {}
  local n = 0
  for _, f in ipairs(plan.flows) do
    f.automate = P.needs_automation(f.per_min, opts.minutes or 60, opts.distance or 28)
    if f.automate then n = n + 1 end
  end
  return n
end

---------------------------------------------------------------------------------------------------
-- 8. Cas de preuve partagé par le test hors jeu et le scénario `ia1-diag` (arène de modules d'IA1-c)
---------------------------------------------------------------------------------------------------
--- Trois modules : A en manque de capacité (objectif 480 engrenages/min pour 360 de nominal), B affamé (fer livré à
--- 40 % du besoin), C témoin à l'aise (objectif 300/min). `feed` : part du besoin d'entrée livrée, par objet.
P.ARENA = {
  { id = "A", key = "engrenages", item = "iron-gear-wheel", demand_per_min = 480, feed = {} },
  { id = "B", key = "circuits-verts", item = "electronic-circuit", demand_per_min = 180, feed = { ["iron-plate"] = 0.40 } },
  { id = "C", key = "engrenages", item = "iron-gear-wheel", demand_per_min = 300, feed = {} },
}
P.ARENA_MAX_LEVEL = 6          -- plafond des bâtiments de l'arène (centre de niveau 3 : 2 × 3)

--- Module du modèle (débits calculés, pas mesurés) pour un cas de P.ARENA (gabarit `g` : celui du catalogue par
--- défaut) : la sortie suit la part d'entrée livrée la plus faible (débit nominal × min(feed)) ; un ingrédient livré
--- sous 100 % manque chez les témoins à chaque relevé.
function P.model_module(case, g)
  g = g or Mod.get(case.key)
  local nominal = (g.nominal[case.item] or 0) * 60
  local share = 1
  local wit = { samples = 10, shortage = {}, output_full = 0 }
  for _, it in ipairs(sorted_keys(case.feed or {})) do
    if case.feed[it] < share then share = case.feed[it] end
    if case.feed[it] < 1 then wit.shortage[it] = 10 end
  end
  local inputs = {}
  for _, it in ipairs(sorted_keys(g.inputs or {})) do inputs[#inputs + 1] = { item = it, measured_per_min = g.inputs[it] * 60 * share } end
  return { id = case.id, g = g, item = case.item, demand_per_min = case.demand_per_min, measured_per_min = nominal * share,
    inputs = inputs, witness = wit }
end

return P
