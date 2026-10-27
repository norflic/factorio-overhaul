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
  8. Ordre (IA1-d §6.3) : rang 1 fer et cuivre (racines de toutes les chaînes), rang 2 engrenages et circuits, rang 3
     packs. Un rang attend tant qu'une méthode d'un rang inférieur est demandable, en recherche ou en cours. Au plus
     A.MAX_OPEN modules ouverts à la fois (hors centrale) ; au plus A.MAX_PER_PRODUCT modules finis par objet.
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
A.DRILL_RATE = 0.5       -- minerai/s d'une foreuse électrique (vitesse 0,5, temps 1 s)
A.BELT_LEN = 28          -- tuiles de tapis estimées des foreuses à la tête d'alimentation (un pas de treillis)
A.NET_POLES = 3          -- poteaux de réseau estimés jusqu'au carrefour le plus proche
A.MAX_OPEN = 2           -- modules ouverts à la fois (chantier, plan, réserve), hors centrale : fer et cuivre ensemble
A.RESEARCH_WINDOW = 5    -- minutes : un objet impossible (recherche) se voit dès la demi-fenêtre (la recherche prend du temps)
A.MAX_PER_PRODUCT = 2    -- modules finis au plus par objet
A.VALUE = 64             -- valeur de base du projet d'un module (famille capital, pondérée par le chef)
A.BURNER_RATE = 0.25     -- minerai/s d'une foreuse à combustion (avant-postes : capacité d'un module en unités d'avant-poste)

-- Méthodes « machine » (données du mod : générateurs de shared/team/modules.lua). ext = indice du paramètre agrandi
-- (extension du gabarit) ; ore = minerai servi par des foreuses quand le flux le permet ; feed = têtes d'alimentation.
A.METHODS = {
  { product = "iron-plate", rank = 1, gen = "smelter", args = { "stone-furnace", "iron-ore", 1 }, ore = "iron-ore", feed = true },
  { product = "copper-plate", rank = 1, gen = "smelter", args = { "stone-furnace", "copper-ore", 1 }, ore = "copper-ore", feed = true },
  { product = "iron-gear-wheel", rank = 2, gen = "gears", args = { 1, "assembling-machine-1" }, feed = true },
  { product = "electronic-circuit", rank = 2, gen = "circuits", args = { "assembling-machine-1", 1 }, feed = true },
  { product = "automation-science-pack", rank = 3, gen = "red_packs", args = { "assembling-machine-1", 1 }, feed = true },
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
  for i = 1, #args do parts[#parts + 1] = tostring(args[i]) end
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
--- Rend L, D, Lres, n (minutes comptées).
function A.measure(window, item)
  local n = 0
  local load, made, logi = 0, 0, 0
  local first = math.max(1, #window - A.WINDOW + 1)
  for i = first, #window do
    local b = window[i]
    n = n + 1
    load = load + ((b.load or {})[item] or 0)
    made = made + ((b.made or {})[item] or 0)
    logi = logi + ((b.logi or {})[item] or 0)
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
  local outs = 0
  for _, it in ipairs(sorted_keys(g.nominal)) do if it ~= "electricity-kw" then outs = outs + 1 end end
  -- un quai de sortie par port de sortie : les fonderies en ont deux (une rangée de fours chacune)
  local ports = method.gen == "smelter" and 2 or 1
  add("iron-chest", ports)
  add("inserter", ports)
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
-- Décision
---------------------------------------------------------------------------------------------------
local OPEN = { attente = true, plan = true, reserve = true, defrichage = true, fantomes = true, chantier = true,
  raccordement = true, bloque = true, demande = true }
A.OPEN_STATES = OPEN

--- La décision d'une pensée. input = {
---   window, threatened, modules = { { product, state, reason, sig } } (demandes de l'équipe, dans l'ordre),
---   obtainable(item) -> bool (fabricable à la main OU au stock), book, stock, dist, has_plant, sig (contexte) }.
--- Rend { requests = { { product, gen, args, rate, rate_nom, feed, why } }, verdicts = { { product, verdict, why, L, D,
--- T, C, G } } (ordre de A.METHODS), wanted = { [objet] = true } }.
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
  local busy_rank = nil -- plus petit rang qui retient les suivants (demandable, en recherche ou en cours)
  for _, meth in ipairs(A.METHODS) do
    local L, D, Lres, n = A.measure(window, meth.product)
    local v = { product = meth.product, L = L, D = D, rank = meth.rank }
    local st = mods[meth.product] or { open = 0, fini = 0 }
    if busy_rank and meth.rank > busy_rank then
      v.verdict, v.why = "ordre", "rang " .. busy_rank .. " d'abord"
    elseif st.open > 0 then
      v.verdict, v.why = "en_cours", "module ouvert"
      busy_rank = busy_rank or meth.rank
    elseif st.refused and st.refused.sig == input.sig then
      v.verdict, v.why = "refuse", tostring(st.refused.reason)
    elseif st.fini >= A.MAX_PER_PRODUCT then
      v.verdict, v.why = "fini", st.fini .. " module(s)"
    elseif n < A.RESEARCH_WINDOW then
      v.verdict, v.why = "attente", "fenetre " .. n .. "/" .. A.WINDOW .. " min"
    elseif L <= A.LOAD_MIN then
      v.verdict, v.why = "non", string.format("charge %.2f PNJ <= %.2f", L, A.LOAD_MIN)
    else
      local rate = math.max(1, D) * (100 + margin) / 100
      local g, args = A.sized(meth, rate)
      if not g then
        v.verdict, v.why = "non", "gabarit : " .. tostring(args)
      else
        local rate_nom = (g.nominal[meth.product] or 0) * 60
        local C, items, n_ent, det = A.cost(meth, g, { book = input.book, stock = input.stock, dist = input.dist,
          price = price, has_plant = input.has_plant })
        local missing = {}
        for _, name in ipairs(sorted_keys(items)) do
          if not (input.obtainable and input.obtainable(name)) then missing[#missing + 1] = name end
        end
        local share = D > 0 and math.min(1, rate_nom / D) or 1
        local G = L * share - A.residual(det, rate_nom, input.dist)
        v.C, v.G, v.n_ent, v.rate_nom = C, G, n_ent, rate_nom
        if G <= 0 then
          v.verdict, v.why = "non", string.format("gain %.2f PNJ <= 0 (logistique du module %.2f)", G, L * share - G)
        else
          local T = C / (60 * G)
          v.T = T
          if T > H then
            v.verdict, v.why = "non", string.format("retour %.1f min > %d", T, H)
          elseif #missing > 0 then
            v.verdict, v.why = "recherche", "objets impossibles : " .. table.concat(missing, ",")
            for _, name in ipairs(missing) do out.wanted[name] = true end
            busy_rank = busy_rank or meth.rank
          elseif n < A.WINDOW then
            -- Demi-fenêtre : assez pour lancer la recherche d'un objet impossible, pas pour demander le module (H3 :
            -- « pendant 10 min »).
            v.verdict, v.why = "attente", "fenetre " .. n .. "/" .. A.WINDOW .. " min"
          elseif open >= A.MAX_OPEN then
            v.verdict, v.why = "attente", "un module deja ouvert"
            busy_rank = busy_rank or meth.rank
          else
            v.verdict, v.why = "demande", string.format("charge %.2f PNJ, retour %.1f min <= %d", L, T, H)
            out.requests[#out.requests + 1] = { product = meth.product, gen = meth.gen, args = args, rate = rate,
              rate_nom = rate_nom, feed = meth.feed, why = v.why, items = items }
            open = open + 1
            busy_rank = busy_rank or meth.rank
          end
        end
      end
    end
    out.verdicts[#out.verdicts + 1] = v
  end
  return out
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
  local w = (weights or {}).capital or 1000
  for _, m in ipairs(auto.modules or {}) do
    if OPEN[m.state] then
      goals[#goals + 1] = { key = "auto:" .. m.product, family = "capital", kind = "module", product = m.product,
        status = m.state, missing = m.missing, reason = m.reason, value = clamp(math.floor(A.VALUE * w / 1000), 1, 100) }
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
