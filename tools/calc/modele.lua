--[[
  Modèle d'équilibre par époque (piste CALCULS) : machines, modules, productivité, chaînes, dépense des niveaux et
  calendrier. Lua 5.2 PUR, lancé depuis la racine du mod (package.path "./?.lua"). Lit :
    - les données FINALES de l'étape data (tools/calc/donnees.lua, `harness.lua --dump-calc`) ;
    - shared/levels/config.lua (L : coûts des niveaux, base de référence, calendrier X0 recopié) ;
    - shared/content/modules.lua (barème D-17, M.metrics : multiplication et plafond × 328,67) ;
    - shared/content/epochs.lua (X : époques des recettes, d'où le palier de module disponible à chaque époque).

  Hypothèses de modules (H) :
    H0 : aucun module (le modèle de `levels_test --tables`) ;
    H1 : modules de VITESSE du meilleur palier disponible dans toutes les cases (ne change pas la matière brute, seulement
         le nombre de machines) ;
    H2 : modules de PRODUCTIVITÉ du meilleur palier disponible dans toutes les cases des machines qui les admettent
         (limitation du jeu), machines au niveau maximal de l'époque (2e), foreuses comprises ;
    H2r : comme H2, SANS la productivité des foreuses (recettes seules).
  Le four de la famille est le four en acier (aucune case) : la fusion n'a jamais de module ici (le four électrique
  vanilla, 2 cases, n'est pas compté ; hypothèse prudente).
]]

local MU = require("tools.calc.mu")
local L = require("shared.levels.config")
local M = require("shared.content.modules")
local X = require("shared.content.epochs")

local Mo = {}
Mo.L, Mo.M, Mo.X, Mo.MU = L, M, X, MU

--- Époque de chaque recette de base ou du mod listée par X.base_recipe_epochs.
local recipe_epoch = {}
for _, row in ipairs(X.base_recipe_epochs) do
  for _, r in ipairs(row[2]) do recipe_epoch[r] = row[1] end
end
Mo.recipe_epoch = recipe_epoch

--- Meilleur palier de module de la famille `fam` disponible à l'époque e (nil : aucun).
function Mo.tier_available(fam, e)
  local best
  for k = 1, M.TIERS do
    local ep = recipe_epoch[M.name(fam, k)]
    if ep and ep <= e then best = k end
  end
  return best
end

--- Familles de niveaux par catégorie de recette.
Mo.FAMILY_OF_CATEGORY = {
  crafting = "assembler", ["advanced-crafting"] = "assembler", ["crafting-with-fluid"] = "assembler",
  ["basic-crafting"] = "assembler", smelting = "furnace",
}

local function eligible_fixed(name)
  return not name:match("^fo%-lvl%-") and not name:match("^fo%-vitrine")
end

--- Machine qui fabrique une catégorie à l'époque e : famille de niveaux au niveau 2e (max), sinon la machine fixe la
--- plus rapide de la catégorie. Renvoie { name, speed, slots, side, allows_prod, family }.
function Mo.machine_for(D, category, e)
  local fk = Mo.FAMILY_OF_CATEGORY[category]
  if fk then
    local f = L.by_key[fk]
    local n = math.min(f.max, 2 * e)
    local name = L.name(f, n)
    local m = D.machines[name]
    if m then
      return { name = name, speed = m.crafting_speed, slots = m.module_slots or 0, side = m.side, family = fk, level = n,
        allows_prod = Mo.allows(m, "productivity") }
    end
  end
  local best
  for _, name in ipairs(MU.sorted_keys(D.machines)) do
    local m = D.machines[name]
    if eligible_fixed(name) and m.crafting_speed then
      for _, c in ipairs(m.categories or {}) do
        if c == category and (not best or m.crafting_speed > best.speed) then
          best = { name = name, speed = m.crafting_speed, slots = m.module_slots or 0, side = m.side,
            allows_prod = Mo.allows(m, "productivity") }
        end
      end
    end
  end
  return best
end

--- Foreuse de l'époque e (famille drill au niveau 2e) pour les gisements solides.
function Mo.drill_for(D, e)
  local f = L.by_key.drill
  local n = math.min(f.max, 2 * e)
  local name = L.name(f, n)
  local m = D.machines[name]
  return { name = name, speed = m.mining_speed, slots = m.module_slots or 0, side = m.side, family = "drill", level = n,
    allows_prod = Mo.allows(m, "productivity") }
end

function Mo.allows(m, effect)
  if not m.allowed_effects then return true end
  for _, a in ipairs(m.allowed_effects) do if a == effect then return true end end
  return false
end

--- Facteurs d'une machine pleine de modules `fam` au palier k : { speed, prod, energy } (M.metrics, D-17).
function Mo.full_factors(fam, k, slots)
  if not k or not slots or slots <= 0 then return { speed = 1, prod = 1, energy = 1 } end
  local x = M.metrics(fam, k, slots)
  return { speed = x.speed, prod = x.output / x.speed, energy = x.energy }
end

local function limitation_set(D)
  local s = {}
  local mod = D.modules and D.modules[M.name("productivity", 1)]
  for _, r in ipairs(mod and mod.limitation or {}) do s[r] = true end
  return s
end

--- Options du graphe pour l'hypothèse h à l'époque e : { prod = fonction, mining_prod = facteur }.
function Mo.graph_opts(D, h, e)
  if h ~= "H2" and h ~= "H2r" then return {} end
  local k = Mo.tier_available("productivity", e)
  if not k then return {} end
  local lim = limitation_set(D)
  local function prod(name, r)
    if not lim[name] then return 1 end
    local mach = Mo.machine_for(D, r.category, e)
    if not mach or not mach.allows_prod then return 1 end
    return Mo.full_factors("productivity", k, mach.slots).prod
  end
  local mp = 1
  if h == "H2" then
    local d = Mo.drill_for(D, e)
    if d.allows_prod then mp = Mo.full_factors("productivity", k, d.slots).prod end
  end
  -- Seules les recettes débloquées à l'époque e (X.base_recipe_epochs ; recette non rangée : admise).
  local function allow(name)
    local re = recipe_epoch[name]
    return re == nil or re <= e
  end
  return { prod = prod, mining_prod = mp, allow = allow }
end

--- Graphes mis en cache par (hypothèse, époque).
function Mo.new_cache(D)
  local cache = { D = D, graphs = {}, values = {} }
  function cache.graph(h, e)
    local key = h .. ":" .. ((h == "H2" or h == "H2r") and e or 0)
    if not cache.graphs[key] then cache.graphs[key] = MU.graph(D, Mo.graph_opts(D, h, e)) end
    return cache.graphs[key], key
  end
  --- MU d'un objet sous l'hypothèse h à l'époque e (mise en cache) ; renvoie aussi la chaîne (x).
  function cache.mu(item, h, e)
    local G, key = cache.graph(h, e)
    cache.values[key] = cache.values[key] or {}
    local v = cache.values[key][item]
    if not v then
      local mu, x, _, piv = MU.solve_target(G, item)
      v = { mu = mu, x = x, pivots = piv }
      cache.values[key][item] = v
    end
    return v.mu, v.x
  end
  return cache
end

--- Machines pour 1 objet/s d'une chaîne (x : régimes par unité), à l'époque e, avec des modules de vitesse du
--- palier `speed_tier` (nil : aucun) dans toutes les cases (H1) ; les modules de productivité, s'ils sont dans le
--- graphe (H2), ont déjà réduit les régimes, et leur malus de vitesse est appliqué. Renvoie une liste triée
--- { machine, count, tiles } et le total des tuiles ; les fluides de gisement sont comptés à part (u/s).
function Mo.chain_machines(D, x, e, opts)
  opts = opts or {}
  local by, fluids = {}, {}
  local names = MU.sorted_keys(x)
  for _, rn in ipairs(names) do
    local runs = x[rn].runs
    local r = x[rn].recipe
    local mach, time
    if rn:match("^gisement:") then
      local res = D.resources[r.resource]
      local kind = res.results[1].type or "item"
      if kind == "fluid" then
        for it, a in pairs(r.outs) do fluids[it] = (fluids[it] or 0) + a * runs end
      else
        mach = Mo.drill_for(D, e)
        time = r.energy
      end
    elseif rn:match("^lancement:") or rn:match("^combustion:") or rn:match("^brut:") then
      mach = nil
    else
      mach = Mo.machine_for(D, r.category, e)
      time = r.energy
    end
    if mach then
      local sp = mach.speed
      if opts.speed_tier and mach.slots > 0 then
        sp = sp * Mo.full_factors("speed", opts.speed_tier, mach.slots).speed
      elseif opts.prod_tier and mach.slots > 0 and (r.prod or 1) > 1 then
        sp = sp * Mo.full_factors("productivity", opts.prod_tier, mach.slots).speed
      end
      local count = runs * time / sp
      local b = by[mach.name]
      if not b then b = { machine = mach.name, count = 0, side = mach.side or 1 }; by[mach.name] = b end
      b.count = b.count + count
    end
  end
  local out, tiles = {}, 0
  for _, k in ipairs(MU.sorted_keys(by)) do
    local b = by[k]
    b.tiles = b.count * b.side * b.side
    tiles = tiles + b.tiles
    out[#out + 1] = b
  end
  return out, tiles, fluids
end

---------------------------------------------------------------------------------------------------
-- Dépense des niveaux et calendrier (même méthode que tests/levels_test.lua, modèle de durée ; valeur d'un coût
-- passée en paramètre : déclarée L.cost_value, ou matière brute réelle sous une hypothèse).
---------------------------------------------------------------------------------------------------
local function epoch_levels(f, e)
  local out = {}
  for n = 2 * e - 1, 2 * e do if n >= 2 and n <= f.max then out[#out + 1] = n end end
  return out
end
Mo.epoch_levels = epoch_levels

--- Dépense de l'époque e (6 familles de la base de référence + passage du centre payé pendant e).
--- value(cost, epoch_paid) → valeur d'un coût.
function Mo.spend(e, value)
  local T = L.target
  local spend = 0
  for _, f in ipairs(L.families) do
    if f.key ~= "command" then
      local N = T.base[f.key](e)
      local dN = N - (e > 1 and T.base[f.key](e - 1) or 0)
      for _, n in ipairs(epoch_levels(f, e)) do spend = spend + N * value(L.cost(f, n), e) end
      for n = 2, 2 * e - 2 do spend = spend + dN * value(L.cost(f, n), e) end
    end
  end
  if e < L.CC_MAX then spend = spend + value(L.cost(L.by_key.command, e + 1), e) end
  return spend
end

--- Heures impliquées de l'époque e pour une dépense donnée (part spend_share de la production X0).
function Mo.implied_hours(e, spend)
  local T = L.target
  return spend / (T.spend_share * T.production(e) * L.TEAM_FACTOR * 3600)
end

--- Valeur d'un coût sous l'hypothèse h (matière brute réelle) ; les objets sont valorisés à l'époque où l'on PAIE.
function Mo.real_value_fn(cache, h)
  return function(cost, e)
    local v = 0
    for _, c in ipairs(cost) do
      local mu = cache.mu(c[1], h, e)
      v = v + c[2] * mu
    end
    return v
  end
end

---------------------------------------------------------------------------------------------------
-- Recherche par époque : époque d'une technologie (règle QX9 de la config, L.vanilla_tech_epoch, puis le maximum
-- de ses prérequis), unités, temps de laboratoire, coût des packs en matière brute.
---------------------------------------------------------------------------------------------------
function Mo.tech_epochs(D)
  local ep, busy = {}, {}
  local function epoch(name)
    if ep[name] then return ep[name] end
    if busy[name] then return 1 end
    busy[name] = true
    local t = D.techs[name]
    local e = 1
    if t then
      local effects = {}
      for _, r in ipairs(t.unlocks or {}) do effects[#effects + 1] = { type = "unlock-recipe", recipe = r } end
      local ings = {}
      for _, i in ipairs(t.ingredients or {}) do ings[#ings + 1] = { i[1], i[2] } end
      e = L.vanilla_tech_epoch({ name = name, effects = effects, unit = { ingredients = ings } })
      for _, p in ipairs(t.prerequisites or {}) do
        if D.techs[p] then e = math.max(e, epoch(p)) end
      end
    end
    busy[name] = nil
    ep[name] = e
    return e
  end
  for _, name in ipairs(MU.sorted_keys(D.techs)) do epoch(name) end
  return ep
end

return Mo
