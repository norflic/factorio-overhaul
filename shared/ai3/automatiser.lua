--[[
  IA3-e « automatiser ce qui revient » : la règle MAIN → MACHINE (docs/IA3_CERVEAU.md §1.2 H3 et H4, §3.4 ;
  fo-logs/2026-10-25_IA1-d/INTEGRATION.md §6). PUR (aucune API Factorio) : testé hors jeu
  (tests/ai3_automatiser_test.lua) ; le runtime (script/ai3/automatisation.lua) lui donne les mesures et applique ses
  demandes au plan directeur d'IA1-d (Build.request).

  Ce qu'un joueur fait : il fabrique ses 10 premiers engrenages à la main, puis pose un assembleur quand ça devient
  pénible ; il porte ses premières plaques, puis pose des foreuses électriques et un tapis vers ses fours. En calcul :

  1. CHARGE à la main d'un objet P, en PNJ : L = (PNJ-secondes passées sur les tâches qui produisent P : tournées des
     avant-postes de P, fonte au QG, minage à la main de son minerai, fabrication à la main de P) ÷ (60 × minutes de la
     fenêtre). La fenêtre glisse sur A.WINDOW minutes COMPLÈTES (relevées par le runtime à la fin de chaque tâche).
  2. DÉBIT D = objets P livrés au QG par minute (toutes sources : c'est le besoin que l'équipe réalise aujourd'hui).
  3. Module visé (méthode « machine » de P, A.METHODS) dimensionné au débit R = D × (1 + marge) (25 % en sécurité,
     0 % menacé : H4), au plus l'extension maximale du gabarit ; débit nominal R_nom (gabarit de shared/team/modules.lua).
  4. COÛT C (PNJ-secondes) = pose (entités × A.POSE_S) + allers-retours de chantier + fabrication à la main des
     matériaux (livre de recettes, au stock près) + plaques brutes au prix de leur fabrication (L × 60 ÷ D, mesuré ;
     A.PLATE_S sans mesure).
  5. GAIN G (PNJ) = L × min(1, R_nom ÷ D) − logistique qui reste (porteurs des quais d'entrée et de sortie du module).
  6. RETOUR T = C ÷ (60 × G) minutes. On automatise si L > A.LOAD_MIN (0,25 PNJ) en moyenne sur la fenêtre pleine
     (10 min) ET T ≤ H (A.H_SAFE = 20 min en sécurité, A.H_THREAT = 5 min menacé).
  7. Un objet du gabarit que l'équipe ne sait ni fabriquer ni n'a en stock (poteau moyen sans sa technologie) : verdict
     « recherche » ; l'objet est rendu dans `wanted` (le runtime donne de la valeur à la technologie qui le débloque :
     « la recherche vaut ce qu'elle débloque », H9). Aucune demande tant qu'il manque.
  8. Ordre DÉDUIT DU GRAPHE DES RECETTES (consigne du DC, 27/10, 7 h 10 : « un objet attend que ses ingrédients soient
     automatisés. Pas d'une liste de noms ») : profondeur d'un objet = 1 + la plus grande profondeur de ses entrées
     (entrées du gabarit, sinon ingrédients de sa recette ; objet brut : 0) ; les objets sont pesés par profondeur
     croissante, puis charge décroissante, puis nom ; un objet ATTEND (« ordre ») tant qu'une de ses entrées est en route
     vers l'automatisation (demandée, en recherche, en cours, en attente de place, ou elle-même en attente). Au plus
     A.MAX_OPEN modules ouverts à la fois (hors centrale) ; au plus A.MAX_PER_PRODUCT modules finis par objet.
  10. N'IMPORTE QUEL objet (même consigne) : sont pesés les produits de A.METHODS (gabarits écrits à la main, plus
     efficaces : fonderie avec foreuses, îlots de circuits) ET tout objet qui a coûté de la charge à la main dans la
     fenêtre (ou demandé par l'appelant, input.items). Sans gabarit, le module est GÉNÉRÉ depuis les données : rangée
     d'assembleurs (G.simple) de la première machine de A.MACHINES qui fait la catégorie de sa recette, entrées de la
     recette par quais, débit visé. Limites (verdict « limite », raison écrite) : objet brut (extraction seule), recette
     hors de la main (fours, fluides), plus de 2 ingrédients, plusieurs produits (INTEGRATION.md §0).
     Un objet impossible se voit dès A.RESEARCH_WINDOW minutes de fenêtre (la recherche prend du temps) ; la demande
     du module attend la fenêtre pleine.
  9. Refus du plan directeur : coût infini tant que la raison ne change pas (signature `sig` : raison + contexte
     fourni par le runtime, rayon du treillis et poteau disponible).

  Ce module ne connaît le jeu que par ses DONNÉES (A.METHODS : générateurs et paramètres de shared/team/modules.lua) ;
  la décision est la même pour chaque objet. Déterminisme : listes triées, entiers et flottants calculés dans un ordre
  fixe, aucun hasard, aucun pairs décisionnel ; le cache des gabarits est LOCAL (fonction pure de ses paramètres),
  jamais dans global.
]]

local M = require("shared.team.modules")
local T = require("shared.team.config")

local A = {}

A.WINDOW = 10            -- minutes de la fenêtre glissante (H3 : « pendant 10 min »)
A.LOAD_MIN = 0.25        -- PNJ (H3)
A.H_SAFE = 20            -- minutes (horizon du chef en sécurité)
A.H_THREAT = 5           -- minutes (menacé)
A.MARGIN_SAFE = 25       -- % de débit en plus en sécurité (H4)
A.MARGIN_THREAT = 0
A.POSE_S = 1.5           -- s de pose par entité (plan directeur : ravivage + marche locale)
A.BATCH = 12             -- entités par aller-retour de chantier (le PNJ prend un lot au point d'appui)
A.WALK = 8               -- tuiles par seconde (personnage : 0,15 tuile par tick, marge pour les détours)
A.HANDLE_S = 10          -- s de prise et de dépôt par aller-retour
A.DIST = 56              -- tuiles du QG au module (2 lots) quand le runtime ne la donne pas
A.PLATE_S = 1.0          -- PNJ-s par plaque brute sans mesure (minage à la main 1 s + fonte, à la louche)
A.QUAI_FILL = 400        -- objets portés au quai d'entrée par aller-retour (Build.QUAI_FILL)
A.COLLECT_AT = 200       -- objets rapportés du quai de sortie par aller-retour (Build.COLLECT_AT)
A.BELT_FLOW = 1.0        -- objets/s : au-delà, une voie de minerai est servie par tapis depuis des foreuses (P.AUTO_FLOW)
A.QUAI_RATE = 0.635      -- objets/s d'un bras simple au quai de sortie (0,83 × 0,85 × 0,9 : M.choose_inserters) ; au-delà,
                         -- le plan directeur pose un bras RAPIDE (technologie) : la taille du module se règle sur ce qui se
                         -- fabrique (moteur réel, e4-usine : fonderie de 7 rangées, 2 bras rapides impossibles, réserve 15 min)
A.FIRST_RATE_MAX = 150   -- objets/min au plus pour le PREMIER module d'un objet (on commence petit, on agrandit ensuite :
                         -- e4-usine, fonderie de 7 rangées à 93 entités jamais payée)
A.DRILL_RATE = 0.5       -- minerai/s d'une foreuse électrique (vitesse 0,5, temps 1 s)
A.BELT_LEN = 28          -- tuiles de tapis estimées des foreuses à la tête d'alimentation (un pas de treillis)
A.NET_POLES = 3          -- poteaux de réseau estimés jusqu'au carrefour le plus proche
A.MAX_OPEN = 2           -- modules ouverts à la fois (chantier, plan, réserve), hors centrale : fer et cuivre ensemble
A.RESEARCH_WINDOW = 5    -- minutes : un objet impossible (recherche) se voit dès la demi-fenêtre (la recherche prend du temps)
A.MAX_PER_PRODUCT = 2    -- modules finis au plus par objet
A.VALUE = 64             -- valeur de base du projet d'un module (famille capital, pondérée par le chef)…
A.VALUE_PER_PNJ = 8      -- … plus 8 par PNJ libéré (gain G), au plus A.VALUE_MAX : un module qui libère 2 PNJ passe
A.VALUE_MAX = 90         -- devant l'armée et la recherche au service du fer (piège de pauvreté, e3-usine : réserve
                         -- « materiaux » 64 min, le fer mangé par l'armée et les munitions servies avant lui)
A.BURNER_RATE = 0.25     -- minerai/s d'une foreuse à combustion (avant-postes : capacité d'un module en unités d'avant-poste)

-- Méthodes « machine » (données du mod : générateurs de shared/team/modules.lua). ext = indice du paramètre agrandi
-- (extension du gabarit) ; ore = minerai servi par des foreuses quand le flux le permet ; feed = têtes d'alimentation.
A.METHODS = {
  { product = "iron-plate", gen = "smelter", args = { "stone-furnace", "iron-ore", 1 }, ore = "iron-ore", feed = "tapis" },
  { product = "copper-plate", gen = "smelter", args = { "stone-furnace", "copper-ore", 1 }, ore = "copper-ore", feed = "tapis" },
  { product = "iron-gear-wheel", gen = "gears", args = { 1, "assembling-machine-1" }, feed = true },
  { product = "electronic-circuit", gen = "circuits", args = { "assembling-machine-1", 1 }, feed = true },
  { product = "firearm-magazine", gen = "simple", args = { "firearm-magazine", 1, "assembling-machine-1" }, feed = true },
  { product = "automation-science-pack", gen = "red_packs", args = { "assembling-machine-1", 1 }, feed = true },
  { product = "logistic-science-pack", gen = "green_packs", args = { "assembling-machine-1", 1 }, feed = true },
}
-- La centrale (demandée d'elle-même par le plan directeur au premier module électrique) : comptée dans le coût du
-- premier module quand l'équipe n'en a pas.
A.PLANT = { gen = "steam", args = { 1 } }

local function sorted_keys(t)
  local ks = {}
  for k in pairs(t or {}) do ks[#ks + 1] = k end
  table.sort(ks)
  return ks
end

---------------------------------------------------------------------------------------------------
-- Gabarits (cache LOCAL : fonction pure des paramètres)
---------------------------------------------------------------------------------------------------
local cache = {}

local function args_key(gen, args)
  local parts = { gen }
  for i = 1, #args do
    local a = args[i]
    -- recette tirée des données (G.simple) : son NOM (une adresse de table changerait d'une pensée à l'autre)
    parts[#parts + 1] = type(a) == "table" and ("{" .. tostring(a.name) .. "}") or tostring(a)
  end
  return table.concat(parts, "|")
end

--- Résumé d'un gabarit : { key, n_ent, items = { [objet] = n }, nominal = { [objet] = n/s }, inputs = { [objet] = n/s },
--- power_kw, ext = { arg, max }, args } ou nil, raison. Les entités vanilla se posent par l'objet de même nom.
function A.template(gen, args)
  local k = args_key(gen, args)
  local c = cache[k]
  if c ~= nil then
    if c == false then return nil, "gabarit refuse" end
    return c
  end
  local fn = M.GEN[gen]
  if not fn then cache[k] = false return nil, "generateur inconnu" end
  local g, why = fn(table.unpack(args))
  if not g then cache[k] = false return nil, why end
  local items = {}
  for _, e in ipairs(g.entities) do items[e.name] = (items[e.name] or 0) + 1 end
  local ex = g.extensions and g.extensions[1]
  c = { key = g.key, n_ent = #g.entities, items = items, nominal = g.nominal or {}, inputs = g.inputs or {},
    power_kw = g.power_kw or 0, ext = ex and { arg = ex.arg, max = ex.max } or nil, args = args, gen = gen }
  cache[k] = c
  return c
end

--- Vide le cache (tests).
function A.reset_cache() cache = {} end

--- Gabarit d'une méthode dimensionné au débit `rate` (objets/min du produit) : (résumé, args) ou nil, raison.
function A.sized(method, rate)
  local base, why = A.template(method.gen, method.args)
  if not base then return nil, why end
  local nom = (base.nominal[method.product] or 0) * 60
  if nom <= 0 then return nil, "debit nominal nul" end
  local args = {}
  for i = 1, #method.args do args[i] = method.args[i] end
  if base.ext and base.ext.max >= 1 then
    local cur = args[base.ext.arg]
    local n = math.ceil(cur * rate / nom - 1e-9)
    if n < 1 then n = 1 end
    if n > base.ext.max then n = base.ext.max end
    args[base.ext.arg] = n
  end
  local g, why2 = A.template(method.gen, args)
  if not g then return nil, why2 end
  return g, args
end

---------------------------------------------------------------------------------------------------
-- Mesures de la fenêtre
---------------------------------------------------------------------------------------------------
--- Charge (PNJ), débit (objets/min) et logistique (PNJ) moyens d'un objet sur la fenêtre. window = liste de minutes
--- COMPLÈTES { m, load = { [objet] = ticks }, made = { [objet] = n }, logi = { [objet] = ticks } } (ordre croissant).
--- after (facultatif) : seules les minutes m > after comptent (après la fin d'un module du même objet).
--- Rend L, D, Lres, n (minutes comptées).
function A.measure(window, item, after)
  local n = 0
  local load, made, logi = 0, 0, 0
  local first = math.max(1, #window - A.WINDOW + 1)
  for i = first, #window do
    local b = window[i]
    if after and (b.m or 0) <= after then goto skip end
    n = n + 1
    load = load + ((b.load or {})[item] or 0)
    made = made + ((b.made or {})[item] or 0)
    logi = logi + ((b.logi or {})[item] or 0)
    ::skip::
  end
  if n == 0 then return 0, 0, 0, 0 end
  return load / (n * 3600), made / n, logi / (n * 3600), n
end

---------------------------------------------------------------------------------------------------
-- Coût et gain
---------------------------------------------------------------------------------------------------
--- Entités supplémentaires estimées du plan directeur autour d'un gabarit : foreuses et leur tapis (voie de minerai
--- au-delà de A.BELT_FLOW), quais d'entrée (autres voies), quais de sortie, poteaux de réseau. Rend items, n, quais
--- d'entrée { { objet, flux/s } }, quais de sortie (nombre).
local function feed_extra(method, g)
  local items, n = {}, 0
  local function add(name, k) items[name] = (items[name] or 0) + k; n = n + k end
  local quais_in = {}
  for _, it in ipairs(sorted_keys(g.inputs)) do
    local flow = g.inputs[it]
    if method.ore == it and flow >= A.BELT_FLOW then
      local nd = math.max(1, math.ceil(flow / (2 * A.DRILL_RATE) - 1e-9))
      local d = A.template("drills", { it, nd })
      if d then
        for _, name in ipairs(sorted_keys(d.items)) do add(name, d.items[name]) end
      end
      add("transport-belt", A.BELT_LEN)
    else
      quais_in[#quais_in + 1] = { it, flow }
      add("iron-chest", 1)
      add("inserter", 1)
    end
  end
  local outn = 0
  for _, it in ipairs(sorted_keys(g.nominal)) do if it ~= "electricity-kw" then outn = outn + g.nominal[it] end end
  -- un quai de sortie par port de sortie : les fonderies en ont deux (une rangée de fours chacune) ; bras rapide quand un
  -- bras simple ne suffit pas (choix du plan directeur, P.out_quai)
  local ports = method.gen == "smelter" and 2 or 1
  add("iron-chest", ports)
  add(outn / ports > A.QUAI_RATE and "fast-inserter" or "inserter", ports)
  if (g.power_kw or 0) > 0 then add("medium-electric-pole", A.NET_POLES) end
  return items, n, quais_in, ports
end

--- Coût (PNJ-secondes) et matériaux d'un module : C, items (objet -> n), n_ent, détail.
--- ctx = { book, stock, dist, price = { [plaque] = PNJ-s }, has_plant }.
function A.cost(method, g, ctx)
  local items = {}
  for _, name in ipairs(sorted_keys(g.items)) do items[name] = g.items[name] end
  local extra, n_extra, quais_in, outs = feed_extra(method, g)
  for _, name in ipairs(sorted_keys(extra)) do items[name] = (items[name] or 0) + extra[name] end
  local n_ent = g.n_ent + n_extra
  if (g.power_kw or 0) > 0 and not ctx.has_plant then
    local pl = A.template(A.PLANT.gen, A.PLANT.args)
    if pl then
      for _, name in ipairs(sorted_keys(pl.items)) do items[name] = (items[name] or 0) + pl.items[name] end
      items["iron-chest"] = (items["iron-chest"] or 0) + 1
      n_ent = n_ent + pl.n_ent + 1
    end
  end
  local dist = ctx.dist or A.DIST
  local pose = n_ent * A.POSE_S + math.ceil(n_ent / A.BATCH) * (2 * dist / A.WALK + A.HANDLE_S)
  local list = {}
  for _, name in ipairs(sorted_keys(items)) do list[#list + 1] = { name, items[name] } end
  local craft_s, raw_s = 0, 0
  local raw = {}
  if ctx.book then
    local p = ctx.book:plan(list, ctx.stock or {})
    for _, c in ipairs(p.crafts) do craft_s = craft_s + c.energy end
    for _, k in ipairs(sorted_keys(p.raw)) do
      raw[k] = p.raw[k]
      local price = (ctx.price or {})[k] or A.PLATE_S
      raw_s = raw_s + p.raw[k] * price
    end
  end
  return pose + craft_s + raw_s, items, n_ent, { pose = pose, craft = craft_s, raw = raw_s, quais_in = quais_in, outs = outs }
end

--- Logistique qui RESTE avec le module (PNJ) : porteurs des quais d'entrée et de sortie.
function A.residual(det, rate_nom_min, dist)
  local trip = 2 * (dist or A.DIST) / A.WALK + A.HANDLE_S
  local trips = 0
  for _, q in ipairs(det.quais_in or {}) do trips = trips + q[2] * 60 / A.QUAI_FILL end
  trips = trips + rate_nom_min / A.COLLECT_AT
  return trips * trip / 60
end

---------------------------------------------------------------------------------------------------
-- Graphe des recettes et méthodes générées (consigne du DC du 27/10, 7 h 10)
---------------------------------------------------------------------------------------------------
--- Machines essayées, dans l'ordre, pour un module généré : la première dont les catégories contiennent celle de la
--- recette (M.spec). Un objet de la machine que l'équipe ne sait pas fabriquer fait « recherche » (point 7).
A.MACHINES = { "assembling-machine-1", "assembling-machine-2" }

-- Index produit -> recette de TOUT le livre (fours et fluides compris : le graphe, pas la main). Cache LOCAL par livre
-- (table faible), construit dans l'ordre des noms : fonction pure des recettes.
local INDEX = setmetatable({}, { __mode = "k" })
local function recipe_index(book)
  if not (type(book) == "table" and type(book.recipes) == "table") then return {} end
  local idx = INDEX[book]
  if idx then return idx end
  idx = {}
  for _, name in ipairs(sorted_keys(book.recipes)) do
    local r = book.recipes[name]
    local pr = r.products or {}
    if not r.hidden and #pr == 1 and pr[1].name then
      local p = pr[1].name
      local cur = idx[p]
      if not cur or (name == p and cur ~= p) then idx[p] = name end
    end
  end
  INDEX[book] = idx
  return idx
end

--- Méthode « machine » d'un objet : celle de A.METHODS s'il en a une, sinon un module GÉNÉRÉ depuis la recette de la main
--- (rangée G.simple). Rend la méthode, ou nil et la raison de la limite.
function A.method_for(item, book)
  for _, m in ipairs(A.METHODS) do if m.product == item then return m end end
  local rname = type(book) == "table" and book.recipe_for and book:recipe_for(item) or nil
  if not rname then
    local other = recipe_index(book)[item]
    if other then
      local r = book.recipes[other]
      return nil, "limite : recette " .. other .. " hors de la main (" .. tostring(r and r.category) .. ")"
    end
    return nil, "limite : objet brut (extraction seule)"
  end
  local r = book.recipes[rname]
  local solid, n_in = true, 0
  for _, i in ipairs(r.ingredients or {}) do
    n_in = n_in + 1
    if i.type == "fluid" then solid = false end
  end
  if not solid then return nil, "limite : " .. rname .. " demande un fluide" end
  if n_in < 1 or n_in > 2 then return nil, "limite : " .. rname .. " a " .. n_in .. " ingredients (rangee : 1 ou 2)" end
  if #(r.products or {}) ~= 1 then return nil, "limite : " .. rname .. " a plusieurs produits" end
  local machine = nil
  for _, name in ipairs(A.MACHINES) do
    local sp = M.spec(name)
    for _, c in ipairs(sp and sp.categories or {}) do
      if c == r.category and not machine then machine = name end
    end
  end
  if not machine then return nil, "limite : aucune machine pour la categorie " .. tostring(r.category) end
  local def = { name = rname, category = r.category, energy = r.energy, ingredients = r.ingredients, products = r.products }
  return { product = item, gen = "simple", args = { def, 1, machine }, feed = true, generic = true }
end

--- Entrées d'un objet dans le graphe : celles du gabarit de sa méthode (ce que le module reçoit du dehors : les
--- engrenages des packs rouges se font DANS le module), sinon les ingrédients de sa recette (toutes catégories). Triées.
local function inputs_of(item, book, meth)
  local t = {}
  if meth then
    local base = A.template(meth.gen, meth.args)
    if base then
      for _, k in ipairs(sorted_keys(base.inputs)) do if k ~= "electricity-kw" then t[#t + 1] = k end end
      return t
    end
  end
  local rname = recipe_index(book)[item]
  local r = rname and book.recipes[rname]
  if not r then return t end
  local seen = {}
  for _, i in ipairs(r.ingredients or {}) do
    if i.name and not seen[i.name] then seen[i.name] = true; t[#t + 1] = i.name end
  end
  table.sort(t)
  return t
end
A.inputs_of = inputs_of

--- Profondeur d'un objet dans le graphe des recettes : 0 pour un objet brut, 1 + la plus grande profondeur de ses entrées
--- sinon (fer : 1 ; engrenages, circuits, chargeurs, packs rouges : 2 ; packs verts : 3). memo et meth_of facultatifs.
function A.depth(item, book, memo, meth_of)
  memo = memo or {}
  meth_of = meth_of or function(i) return (A.method_for(i, book)) end
  local d = memo[item]
  if d ~= nil then return d end
  memo[item] = 0 -- garde contre un cycle de recettes
  local best = 0
  for _, i in ipairs(A.inputs_of(item, book, meth_of(item))) do
    local di = A.depth(i, book, memo, meth_of) + 1
    if di > best then best = di end
  end
  memo[item] = best
  return best
end

---------------------------------------------------------------------------------------------------
-- Décision
---------------------------------------------------------------------------------------------------
local OPEN = { attente = true, plan = true, reserve = true, defrichage = true, fantomes = true, chantier = true,
  raccordement = true, bloque = true, demande = true }
A.OPEN_STATES = OPEN

--- La décision d'une pensée. input = {
---   window, threatened, modules = { { product, state, reason, sig, finished_m } } (demandes de l'équipe, dans l'ordre),
---   obtainable(item) -> bool (fabricable à la main OU au stock), book, stock, dist, has_plant, sig (contexte),
---   no_power (raison du refus de la centrale, ou nil), hold (raison d'un repli : aucune demande, ou nil), items (facultatif : objets à peser en plus, par exemple les
---   étapes « produce » du dépliage d'IA-G) }.
--- Rend { requests = { { product, gen, args, rate, rate_nom, feed, why, items, electric, gain } }, verdicts = { { product,
--- verdict, why, L, D, T, C, G, depth, generic } } (ordre de la pesée : profondeur, charge, nom), wanted = { [objet] = true } }.
--- Verdicts : demande, en_cours, ordre (une entrée d'abord), recherche (objet impossible), attente (fenêtre ou place),
--- non (charge, retour, gain, centrale, gabarit), refuse (plan directeur, même signature), fini, limite (pas de méthode).
function A.decide(input)
  local window = input.window or {}
  local H = input.threatened and A.H_THREAT or A.H_SAFE
  local margin = input.threatened and A.MARGIN_THREAT or A.MARGIN_SAFE
  local mods = {}
  local open = 0
  for _, m in ipairs(input.modules or {}) do
    mods[m.product] = mods[m.product] or { open = 0, fini = 0, refused = nil }
    local r = mods[m.product]
    if OPEN[m.state] then
      r.open = r.open + 1
      open = open + 1
    elseif m.state == "fini" then
      r.fini = r.fini + 1
      if m.finished_m and (not r.last_m or m.finished_m > r.last_m) then r.last_m = m.finished_m end
    elseif m.state == "refuse" then
      r.refused = m
    end
  end
  -- Prix des plaques (PNJ-s par plaque) mesurés sur la fenêtre.
  local price = {}
  for _, meth in ipairs(A.METHODS) do
    if meth.ore then
      local L, D = A.measure(window, meth.product)
      if D > 0 and L > 0 then price[meth.product] = L * 60 / D end
    end
  end
  -- Produits de la fonderie du QG (acier) : au prix de leurs plaques d'entrée (données de shared/team/config.lua).
  for _, p in ipairs(sorted_keys(T.smelter_inputs)) do
    local input = T.smelter_inputs[p]
    if not price[p] and price[input[1]] then price[p] = input[2] * price[input[1]] end
  end
  local out = { requests = {}, verdicts = {}, wanted = {} }
  -- Objets pesés : produits des gabarits écrits, objets demandés par l'appelant, objets qui ont coûté de la charge à la
  -- main dans la fenêtre (n'importe lequel : consigne du DC du 27/10).
  local book = input.book
  local cands, seen = {}, {}
  local function cand(item) if item and not seen[item] then seen[item] = true; cands[#cands + 1] = item end end
  for _, m in ipairs(A.METHODS) do cand(m.product) end
  for _, it in ipairs(input.items or {}) do cand(it) end
  local loaded = {}
  for i = math.max(1, #window - A.WINDOW + 1), #window do
    for k, x in pairs(window[i].load or {}) do if x > 0 then loaded[k] = true end end
  end
  for _, k in ipairs(sorted_keys(loaded)) do cand(k) end
  local meths, whys = {}, {}
  local function meth_of(item)
    if meths[item] == nil then
      local m, why = A.method_for(item, book)
      meths[item] = m or false
      whys[item] = why
    end
    return meths[item] or nil
  end
  local memo = {}
  local order = {}
  for _, item in ipairs(cands) do
    local st = mods[item] or { open = 0, fini = 0 }
    local L, D, _, n = A.measure(window, item, st.last_m)
    order[#order + 1] = { item = item, depth = A.depth(item, book, memo, meth_of), L = L, D = D, n = n,
      inputs = A.inputs_of(item, book, meth_of(item)) }
  end
  table.sort(order, function(a, b)
    if a.depth ~= b.depth then return a.depth < b.depth end
    if a.L ~= b.L then return a.L > b.L end
    return a.item < b.item
  end)
  local busy = {} -- objets en route vers l'automatisation : leurs consommateurs attendent (point 8)
  for _, c in ipairs(order) do
    local meth = meth_of(c.item)
    local st = mods[c.item] or { open = 0, fini = 0 }
    local L, D, n = c.L, c.D, c.n
    local v = { product = c.item, L = L, D = D, depth = c.depth, generic = meth and meth.generic or nil }
    local first_busy = nil
    for _, i in ipairs(c.inputs) do if busy[i] and not first_busy then first_busy = i end end
    if first_busy then
      v.verdict, v.why = "ordre", "entree " .. first_busy .. " d'abord"
      busy[c.item] = true
    elseif st.open > 0 then
      v.verdict, v.why = "en_cours", "module ouvert"
      busy[c.item] = true
    elseif st.refused and st.refused.sig == input.sig then
      v.verdict, v.why = "refuse", tostring(st.refused.reason)
    elseif st.fini >= A.MAX_PER_PRODUCT then
      v.verdict, v.why = "fini", st.fini .. " module(s)"
    elseif n < A.RESEARCH_WINDOW then
      v.verdict, v.why = "attente", "fenetre " .. n .. "/" .. A.WINDOW .. " min"
    elseif L <= A.LOAD_MIN then
      v.verdict, v.why = "non", string.format("charge %.2f PNJ <= %.2f", L, A.LOAD_MIN)
    elseif not meth then
      v.verdict, v.why = "limite", tostring(whys[c.item])
    else
      local rate = math.max(1, D) * (100 + margin) / 100
      if st.fini == 0 and rate > A.FIRST_RATE_MAX then rate = A.FIRST_RATE_MAX end
      local g, args = A.sized(meth, rate)
      -- Fonderie : la voie de minerai n'est servie par foreuses et tapis qu'au-delà de A.BELT_FLOW (P.AUTO_FLOW) ; en
      -- dessous, c'est un quai que les porteurs remplissent DEPUIS LE COFFRE, où il n'y a pas de minerai (les avant-postes
      -- livrent des plaques) : moteur réel, e6-usine, emerald, seconde fonderie de fer à quai de minerai vide 30 min. La
      -- plus petite taille servie par tapis, donc.
      local function belt_ok(gg) return not meth.ore or (gg.inputs[meth.ore] or 0) >= A.BELT_FLOW - 1e-9 end
      if g and g.ext and not belt_ok(g) then
        for n = args[g.ext.arg] + 1, g.ext.max do
          local a2 = {}
          for i = 1, #args do a2[i] = args[i] end
          a2[g.ext.arg] = n
          local g2 = A.template(meth.gen, a2)
          if g2 and belt_ok(g2) then g, args = g2, a2 break end
        end
      end
      local function missing_of(gg)
        local _, its = A.cost(meth, gg, { has_plant = true })
        local miss = {}
        for _, name in ipairs(sorted_keys(its)) do
          if not (input.obtainable and input.obtainable(name)) then miss[#miss + 1] = name end
        end
        return miss
      end
      -- La plus grande taille que l'équipe sait FABRIQUER (une taille plus petite peut se passer d'un objet impossible, le
      -- bras rapide d'un quai de sortie) ; l'objet impossible ne fait rechercher que si même la plus petite le demande.
      if g and g.ext and #missing_of(g) > 0 then
        local cur = args[g.ext.arg]
        for n = cur - 1, 1, -1 do
          local a2 = {}
          for i = 1, #args do a2[i] = args[i] end
          a2[g.ext.arg] = n
          local g2 = A.template(meth.gen, a2)
          if g2 and belt_ok(g2) and #missing_of(g2) == 0 then g, args = g2, a2 break end
        end
      end
      if not g then
        v.verdict, v.why = "non", "gabarit : " .. tostring(args)
      else
        local rate_nom = (g.nominal[c.item] or 0) * 60
        local C, items, n_ent, det = A.cost(meth, g, { book = input.book, stock = input.stock, dist = input.dist,
          price = price, has_plant = input.has_plant })
        local electric = (g.power_kw or 0) > 0
        local missing = {}
        for _, name in ipairs(sorted_keys(items)) do
          if not (input.obtainable and input.obtainable(name)) then missing[#missing + 1] = name end
        end
        local share = D > 0 and math.min(1, rate_nom / D) or 1
        local G = L * share - A.residual(det, rate_nom, input.dist)
        v.C, v.G, v.n_ent, v.rate_nom = C, G, n_ent, rate_nom
        if electric and input.no_power then
          -- La centrale du plan directeur est refusée (pas de rive, pas de rue vers le réseau) : un module électrique ne
          -- produirait rien (moteur réel, e2-usine : 5 modules bâtis sans courant chez emerald). Coût infini tant que la
          -- raison ne change pas (signature du refus de la centrale).
          v.verdict, v.why = "non", "pas de centrale : " .. tostring(input.no_power)
        elseif G <= 0 then
          v.verdict, v.why = "non", string.format("gain %.2f PNJ <= 0 (logistique du module %.2f)", G, L * share - G)
        else
          local T = C / (60 * G)
          v.T = T
          if T > H then
            v.verdict, v.why = "non", string.format("retour %.1f min > %d", T, H)
          elseif #missing > 0 then
            v.verdict, v.why = "recherche", "objets impossibles : " .. table.concat(missing, ",")
            for _, name in ipairs(missing) do out.wanted[name] = true end
            busy[c.item] = true
          elseif n < A.WINDOW then
            -- Demi-fenêtre : assez pour lancer la recherche d'un objet impossible, pas pour demander le module (H3 :
            -- « pendant 10 min »).
            v.verdict, v.why = "attente", "fenetre " .. n .. "/" .. A.WINDOW .. " min"
          elseif open >= A.MAX_OPEN then
            v.verdict, v.why = "attente", "un module deja ouvert"
            busy[c.item] = true
          elseif input.hold then
            -- repli de l'équipe après des réserves affamées (le runtime en donne la raison)
            v.verdict, v.why = "attente", tostring(input.hold)
            busy[c.item] = true
          else
            v.verdict, v.why = "demande", string.format("charge %.2f PNJ, retour %.1f min <= %d", L, T, H)
            out.requests[#out.requests + 1] = { product = c.item, gen = meth.gen, args = args, rate = rate,
              rate_nom = rate_nom, feed = meth.feed, why = v.why, items = items, electric = electric, gain = G }
            open = open + 1
            busy[c.item] = true
          end
        end
      end
    end
    out.verdicts[#out.verdicts + 1] = v
  end
  return out
end

--- Interface STABLE pour un appelant qui pèse UN objet (étapes « produce » et « extract » du dépliage d'IA-G) : même
--- décision que A.decide (même contexte : ordre du graphe, modules ouverts, refus), l'objet étant pesé même sans charge
--- mesurée. Rend le verdict de l'objet { product, verdict, why, L, D, T, C, G, depth, generic } et sa demande (ou nil) :
--- le runtime (script/ai3/automatisation.lua) reste seul à appliquer les demandes au plan directeur.
function A.decide_item(input, item)
  local items = {}
  for _, it in ipairs(input.items or {}) do items[#items + 1] = it end
  items[#items + 1] = item
  local copy = {}
  for k, x in pairs(input) do copy[k] = x end
  copy.items = items
  local res = A.decide(copy)
  local verdict, request = nil, nil
  for _, v in ipairs(res.verdicts) do if v.product == item then verdict = v end end
  for _, r in ipairs(res.requests) do if r.product == item then request = r end end
  return verdict, request, res
end

---------------------------------------------------------------------------------------------------
-- Projet du cerveau (IA3-c) : un module demandé est un PROJET compté dans les K projets ouverts
---------------------------------------------------------------------------------------------------
local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

--- Buts « module » des demandes ouvertes (auto = { modules = { { product, state, missing, reason } } }), ajoutés à la
--- liste des buts de la pensée (shared/ai3/cerveau.lua). Valeur : A.VALUE × poids « capital » du chef.
function A.goals(goals, auto, weights)
  if not auto then return goals end
  -- Le caractère peut AVANCER l'automatisation (capitalisation), pas la retarder sous le neutre : un conquérant construit
  -- aussi son usine (moteur réel, e4-usine : scarlet, conquérant, poids « capital » sous 1 000, fonderie servie après la
  -- recherche, l'armée et les munitions, réserve « materiaux » de 26 à 90 min).
  local w = math.max(1000, (weights or {}).capital or 1000)
  local seen = {}
  for _, m in ipairs(auto.modules or {}) do
    if OPEN[m.state] and not seen[m.product] then
      seen[m.product] = true
      local base = math.min(A.VALUE_MAX, A.VALUE + math.floor(A.VALUE_PER_PNJ * math.max(0, m.gain or 0)))
      goals[#goals + 1] = { key = "auto:" .. m.product, family = "capital", kind = "module", product = m.product,
        status = m.state, missing = m.missing, reason = m.reason, value = clamp(math.floor(base * w / 1000), 1, 100) }
    end
  end
  -- Un module FINI se nourrit depuis le coffre du QG (quais d'entrée remplis par les porteurs, plan directeur) : ce qui
  -- manque au coffre pour ses quais (circuits des packs verts, plaques) est un but « alimenter », de la valeur du module
  -- (moteur réel, e7-usine : packs verts finis, quai de circuits vide, 0 pack ; personne ne fabriquait de circuits pour
  -- lui). Ses manques deviennent des sous-buts (fabriquer, fondre) comme ceux d'un chantier ; la charge à la main des
  -- objets qu'il mange se mesure alors, et leur propre module vient en son temps (ordre du graphe).
  local fed = {}
  for _, fd in ipairs(auto.feeds or {}) do
    if not fed[fd.product] and fd.items and #fd.items > 0 then
      fed[fd.product] = true
      local base = math.min(A.VALUE_MAX, A.VALUE + math.floor(A.VALUE_PER_PNJ * math.max(0, fd.gain or 0)))
      goals[#goals + 1] = { key = "alim:" .. fd.product, family = "capital", kind = "module", product = fd.product,
        status = "reserve", missing = fd.items, value = clamp(math.floor(base * w / 1000), 1, 100) }
    end
  end
  table.sort(goals, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.key < b.key
  end)
  return goals
end

--- Émission d'un projet « module » (shared/ai3/projets.lua, EMIT.module) : les objets qui MANQUENT au chantier
--- (Build.status.missing) deviennent des sous-buts (fabriquer à la main, fondre, miner) ; un chantier bloqué est un
--- projet bloqué (il ne prend pas de place) ; sinon le projet est en cours (ses tâches de chantier sont posées au
--- tableau par le plan directeur lui-même).
function A.emit(P)
  return function(E, proj, g)
    local state = g.status
    if state == "bloque" then return "bloque", "module:" .. tostring(g.reason or "?") end
    if state == "reserve" and g.missing and #g.missing > 0 then
      P.want(E, proj, g.missing, proj.prio, false, "module")
      return "matiere"
    end
    return "en_cours"
  end
end

return A
