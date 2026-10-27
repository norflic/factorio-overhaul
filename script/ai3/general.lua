--[[
  Lot IA-G « le cerveau général », côté RUNTIME : relie la règle pure (shared/ai3/general.lua, shared/ai3/catalogue.lua)
  au cerveau par besoins d'IA-V2 (script/ai3/cerveau.lua) pour les FACTIONS. Votre équipe n'est pas touchée (elle ne
  recherche pas ; ses ressources clés restent celles de repli, shared/ai3/reglages.lua).

  - Catalogue : RELEVÉ des prototypes (game.recipe_prototypes, game.technology_prototypes, game.entity_prototypes,
    game.item_prototypes), une fois, cache LOCAL (revue B1 : prototypes seulement, identiques chez tous les pairs). Les
    exécutants d'aujourd'hui (la main, le laboratoire du QG, les fours du QG et les foreuses des avant-postes : tables de
    l'exécutant, shared/team/config.lua) disent quelles machines existent pour l'équipe.
  - Décision de recherche (General.choose_tech, appelée par la recherche du QG à chaque pensée) : la technologie en cours
    reste tant qu'elle est payable (graphe) ; sinon Gen.choose sur l'état de la force (technologies faites, coffre et
    arrivées, laboratoires, fours du QG, foreuses posées, gisements connus). Une ligne [FO-CERVEAU] par décision : la
    technologie, sa valeur, son coût, son score, la chaîne des pourquoi, le dépliage, les ressources clés.
  - Ressources clés (General.key) : ordre des avant-postes, la plus demandée, le combustible, sans besoin, DÉDUITS du
    besoin brut des buts de la faction (la recherche choisie, le premier lot de soldats, la réserve de munitions) ;
    rangés dans f.team.iag (global : chaînes et nombres) à chaque décision ; lus par la pensée pure (ctx.key).
  - Exploration (General.explore) : une ressource INCONNUE qui bloque une technologie de valeur, et qu'un exécutant
    saurait extraire, est demandée (IA3-f).
  - Payabilité d'un pack de réserve (General.feasible) : faisabilité du graphe à la dernière évaluation.
  Mémo des points fixes par force : fonction PURE de la clé d'état (G.state_key), donc même résultat chez un pair qui
  le recalcule (B1) ; jamais dans global.
  Déterminisme : listes triées, aucun hasard, aucun temps mesuré.
]]

local T = require("shared.team.config")
local R = require("shared.ai3.reglages")
local K = require("shared.ai3.catalogue")
local Gen = require("shared.ai3.general")
local B = require("shared.ai3.buts")
local Planner = require("shared.team.planner")
local State = require("script.faction.state")
local Profiler = require("script.core.profiler")
local Auto = require("script.ai3.automatisation") -- lot AUTO : exécutants de l'automatisation (Auto.on, Auto.exec_entities)

local General = {}

-- Aucun réglage de carte (settings.lua est un fichier de l'intégrateur) : allumé pour toute faction au cerveau par
-- besoins ; General.ENABLED = false rend l'ancien choix d'IA-V2 (tests, essais « avant »).
General.ENABLED = true
General.AUTO_STALL = 10 * 3600 -- lot AUTO (K1, IA3-e) : recherche pour l'automatisation sans unité payée depuis 10 min…
General.AUTO_PAUSE = 20 * 3600 -- … les autres passent 20 min
General.ARMY_FIRST = B.ARMY_FIRST_N
General.AMMO_STOCK = B.AMMO_STOCK

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

local function get(obj, k)
  local ok, v = pcall(function() return obj[k] end)
  if ok then return v end
  return nil
end

local function keys_list(dict)
  local out = {}
  for k in pairs(dict or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

---------------------------------------------------------------------------------------------------
-- Relevé des prototypes et catalogue (cache LOCAL)
---------------------------------------------------------------------------------------------------
local cat = nil
local memos = {}

local function amount_of(p)
  if p.amount then return p.amount end
  local a = ((p.amount_min or 0) + (p.amount_max or 0)) / 2
  return a * (p.probability or 1)
end

function General.dump()
  local d = { recipes = {}, techs = {}, entities = {}, resources = {}, items = {} }
  for _, name in ipairs(keys_list(game.recipe_prototypes)) do
    local r = game.recipe_prototypes[name]
    local ing, prod = {}, {}
    for _, i in ipairs(r.ingredients) do ing[#ing + 1] = { type = i.type, name = i.name, amount = i.amount } end
    for _, p in ipairs(r.products) do prod[#prod + 1] = { type = p.type, name = p.name, amount = amount_of(p) } end
    d.recipes[name] = { category = r.category, energy = r.energy, hidden = r.hidden, enabled = r.enabled,
      ingredients = ing, products = prod }
  end
  for _, name in ipairs(keys_list(game.technology_prototypes)) do
    local t = game.technology_prototypes[name]
    if not t.research_unit_count_formula then
      local ing = {}
      for _, i in ipairs(t.research_unit_ingredients) do ing[#ing + 1] = { i.name, i.amount } end
      local unlocks, effects = {}, {}
      for _, e in ipairs(t.effects or {}) do
        if e.type == "unlock-recipe" then unlocks[#unlocks + 1] = e.recipe else effects[#effects + 1] = e.type end
      end
      table.sort(unlocks)
      table.sort(effects)
      d.techs[name] = { count = t.research_unit_count, time = t.research_unit_energy / 60, ingredients = ing,
        prerequisites = keys_list(t.prerequisites), unlocks = unlocks, effects = effects, enabled = t.enabled,
        hidden = t.hidden }
    end
  end
  for _, ty in ipairs(R.ENTITY_TYPES) do
    local role = R.ENTITY_ROLE[ty]
    local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = ty } })
    for _, name in ipairs(keys_list(protos)) do
      local e = protos[name]
      local items = get(e, "items_to_place_this")
      local en = { name = name, type = ty, item = items and items[1] and items[1].name or nil, energy = "none" }
      if get(e, "electric_energy_source_prototype") then en.energy = "electric"
      elseif get(e, "burner_prototype") then en.energy = "burner" end
      if role == "main" or role == "fabrique" then en.crafting_categories = keys_list(get(e, "crafting_categories")) end
      if role == "main" or role == "foreuse" then en.resource_categories = keys_list(get(e, "resource_categories")) end
      if role == "fabrique" then en.speed = get(e, "crafting_speed") end
      if role == "foreuse" then en.speed = get(e, "mining_speed") end
      if role == "labo" then
        en.lab_inputs = get(e, "lab_inputs")
        en.speed = get(e, "researching_speed")
      end
      if role == "pompe" then
        local fl = get(e, "fluid")
        en.fluid = fl and fl.name or nil
      end
      if role == "chauffe" or role == "generateur" then
        for _, fb in ipairs(get(e, "fluidbox_prototypes") or {}) do
          local filt = get(fb, "filter")
          local pt = get(fb, "production_type")
          if filt and (pt == "input" or pt == "input-output") then en.fluid_in = en.fluid_in or filt.name end
          if filt and pt == "output" then en.fluid_out = en.fluid_out or filt.name end
        end
      end
      d.entities[#d.entities + 1] = en
    end
  end
  local rprotos = game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } })
  for _, name in ipairs(keys_list(rprotos)) do
    local e = rprotos[name]
    local mp = get(e, "mineable_properties")
    local prods = {}
    for _, p in ipairs((mp and mp.products) or {}) do prods[#prods + 1] = { type = p.type, name = p.name, amount = amount_of(p) } end
    d.resources[#d.resources + 1] = { entity = name, category = get(e, "resource_category"), products = prods }
  end
  for _, name in ipairs(keys_list(game.item_prototypes)) do
    local it = game.item_prototypes[name]
    d.items[name] = { type = it.type, fuel_value = it.fuel_value or 0 }
  end
  return d
end

--- Exécutants d'aujourd'hui : la main et le laboratoire du QG (rôles), les fours du QG et les foreuses des avant-postes
--- (tables de l'exécutant). Un lot qui ajoute un exécutant (IA3-e : modules du plan directeur) l'ajoute ici.
--- Lot AUTO : automatisation allumée (réglage fo-war-ia3e, Auto.on), les entités que ses gabarits posent (assembleurs,
--- foreuses électriques, centrale à vapeur : Auto.exec_entities, déduites des gabarits) sont aussi des exécutants :
--- l'électricité et les recettes des assembleurs deviennent payables (H8).
function General.exec_opts(auto_on)
  local exec = { [T.SMELTER] = true, [T.DRILL] = true }
  if auto_on then for _, name in ipairs(Auto.exec_entities()) do exec[name] = true end end
  return { exec = exec, exec_roles = { main = true, labo = true }, labs_unpowered = true,
    -- Combustible : un objet qu'un avant-poste rapporte (moteur réel, banc g2 : sans cela, le cristal de résonance).
    fuel_ok = function(item) return General.kind_of(item) ~= nil end }
end

-- Lot AUTO : un catalogue par état du réglage de l'automatisation (réglage de carte : le même chez tous les pairs) ;
-- changer de catalogue efface les mémos de points fixes (ils appartiennent au graphe de l'autre catalogue).
local cats = {}
function General.catalogue()
  local on = Auto.on() and true or false
  if cat and cats[on] == cat then return cat end
  for k in pairs(memos) do memos[k] = nil end
  if cats[on] then
    cat = cats[on]
    return cat
  end
  Profiler.start("iag:catalogue")
  cat = K.build(General.dump(), General.exec_opts(on))
  cats[on] = cat
  Profiler.stop("iag:catalogue")
  log(string.format("[FO-CERVEAU] catalogue lu dans les prototypes : %d recettes faisables, %d technologies, %d machines exécutables, %d packs, combustible %s%s",
    #cat.g.recipe_list, #cat.tech_list, #cat.g.machine_list, #cat.pack_list, tostring(cat.fuel),
    on and " (automatisation allumee : executants de ses gabarits compris)" or ""))
  return cat
end

function General.on() return General.ENABLED == true end

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
local function kind_of(res)
  for _, k in ipairs(T.OUTPOST_ORDER) do if T.outposts[k].resource == res then return k end end
  return nil
end
General.kind_of = kind_of

--- État du graphe pour une faction : technologies faites (st.techs, tenues par la recherche du QG), coffre et arrivées,
--- machines posées, gisements connus.
function General.state(f, st, view, durable_only)
  local c = General.catalogue()
  local stock = {}
  for _, k in ipairs(sorted_keys(view.stock)) do
    if not durable_only or c.g.machine[k] or c.role[k] then stock[k] = view.stock[k] end
  end
  if not durable_only then
    for _, k in ipairs(sorted_keys(view.incoming)) do stock[k] = (stock[k] or 0) + view.incoming[k] end
  end
  local built = {}
  local nlabs = 0
  for _, e in ipairs(st.labs or {}) do
    if e.valid then
      local it = c.item_of[e.name]
      if it then built[it] = (built[it] or 0) + 1 end
      nlabs = nlabs + 1
    end
  end
  built[T.SMELTER] = (built[T.SMELTER] or 0) + (view.smelters or 0)
  local drills = 0
  for _, o in ipairs(view.outposts or {}) do drills = drills + (o.drills or 0) end
  if drills > 0 then built[T.DRILL] = (built[T.DRILL] or 0) + drills end
  local known = {}
  for _, k in ipairs(sorted_keys(st.known)) do if st.known[k] then known[k] = true end end
  for _, o in ipairs(view.outposts or {}) do known[T.outposts[o.kind].resource] = true end
  return { stock = stock, techs = st.techs or {}, built = built, known = known }, nlabs
end

local function memo_of(f)
  local m = memos[f.force]
  if not m then
    m = {}
    memos[f.force] = m
  end
  return m
end

--- Buts de RÉFÉRENCE d'une faction pour ses ressources clés : la recherche choisie, le premier lot de soldats (le soldat
--- de l'armée à son niveau), la réserve de munitions.
local function ref_goals(f, tech)
  local goals = {}
  if tech then goals[#goals + 1] = { tech = tech } end
  local unit = Planner.best_unit(f.tech or 0)
  for _, it in ipairs(T.kits[unit] or {}) do goals[#goals + 1] = { item = it[1], n = it[2] * General.ARMY_FIRST } end
  goals[#goals + 1] = { item = T.turret_ammo, n = General.AMMO_STOCK }
  return goals
end

---------------------------------------------------------------------------------------------------
-- Décision de recherche
---------------------------------------------------------------------------------------------------
local function iag_state(f)
  f.team.iag = f.team.iag or { decisions = 0, history = {}, explore = {} }
  return f.team.iag
end

--- Ressources clés de la faction (nil : repli de shared/ai3/reglages.lua).
function General.key(f)
  local g = f.team and f.team.iag
  return g and g.key or nil
end

--- Ressources à explorer demandées par le cerveau général.
function General.explore(f)
  local g = f.team and f.team.iag
  return g and g.explore or {}
end

--- Bras libres : packs des technologies suivantes à fabriquer d'avance ({ {pack, n} }, vide si les PNJ sont occupés).
--- Une ligne [FO-CERVEAU] quand la profondeur change.
--- Profondeur d'avance de la pensée (une fois par pensée : compteur de pensées de suite avec des bras libres, global).
local function spare(f, view, tick)
  local g = f.team and f.team.iag
  if not g then return 0 end
  if g.spare_tick ~= tick then
    g.spare_tick = tick
    if Gen.ahead_depth(view.workers_idle, view.workers) > 0 then g.idle_run = (g.idle_run or 0) + 1 else g.idle_run = 0 end
    local war = State.war()
    local elapsed = tick - (f.started or (war and war.started) or 0)
    g.spare = Gen.spare_depth(g.idle_run, view.workers_idle, view.workers, elapsed)
    -- Une exploration demandée (IA3-f, f.ai3f.req) prend d'abord les PNJ sans tâche comme éclaireurs : pas de travail
    -- d'avance tant qu'elle est ouverte (moteur simulé, tests/ia3f_test.lua §6 : avec les bras libres, le pétrole n'était
    -- plus trouvé en 30 min sous 30 % de chemins ratés, les éclaireurs étant occupés aux packs d'avance). Test de vacuité
    -- seulement (aucun ordre de parcours).
    if f.ai3f and f.ai3f.req and next(f.ai3f.req) ~= nil then g.spare = 0 end
  end
  return g.spare or 0
end

function General.lookahead(f, st, view, tick)
  local g = f.team and f.team.iag
  local m = memos[f.force]
  if not (g and g.next and m and m.ev) then return {} end
  local depth = spare(f, view, tick)
  if depth > 0 then g.ahead_thinks = (g.ahead_thinks or 0) + 1 end
  if depth ~= (g.depth or 0) and tick - (g.depth_log or -3600) >= 3600 then
    g.depth = depth
    g.depth_log = tick
    log(string.format("[FO-CERVEAU] %s : bras libres %d/%d : %d recherche(s) suivante(s) preparee(s) d'avance [%s] a %.1f min",
      f.key or "?", view.workers_idle or 0, view.workers or 0, depth, table.concat(g.next, " "), minutes(f, tick)))
  end
  if depth <= 0 then return {} end
  local state = General.state(f, st, view)
  return Gen.lookahead(General.catalogue(), m.ev, state, g.next, depth)
end

--- Bras libres : la pensée pure agrandit d'avance l'extraction de la ressource la plus demandée (shared/ai3/buts.lua).
--- … seulement l'économie faite (« fer II » ou économie couverte : la garde B3 d'IA-V2), et des bras libres durables.
function General.idle_grow(f, view, tick)
  if f.is_player or not General.on() then return false end
  local st = f.team and f.team.ia3
  if not (st and (st.iron2_done or st.economy_ok)) then return false end
  return spare(f, view, tick) > 0
end

--- Faisabilité d'un objet à la dernière évaluation de la force (nil : inconnue).
function General.feasible(f, item)
  local m = memos[f.force]
  if not (m and m.ev) then return nil end
  return m.ev.feas[item] == true
end

--- Une ressource inconnue que l'équipe saurait extraire (un exécutant de sa catégorie) ?
local function explorable(c, res)
  local r = c.resources[res]
  if not r then return false end
  return c.g.by_rescat[r.category] ~= nil
end

--- Choix de la technologie (même contrat que choose_tech de script/ai3/cerveau.lua) : tech, payable, causes, palier.
function General.choose_tech(f, force, st, book, w, tick, view, wanted)
  local c = General.catalogue()
  local g = iag_state(f)
  Profiler.start("iag:choose")
  local state, nlabs = General.state(f, st, view)
  local ev = Gen.prepare(c, state, memo_of(f))
  local lab = st.lab
  -- Lot AUTO (garde de K1 du lot IA3-e, reportée du choix de repli) : une recherche voulue par l'automatisation
  -- (for_auto) sans unité payée depuis General.AUTO_STALL laisse passer les autres General.AUTO_PAUSE (objets voulus
  -- ignorés pendant ce temps).
  if wanted and lab and lab.for_auto and lab.tech and not st.techs[lab.tech]
      and tick - (lab.paid_tick or lab.started or tick) > General.AUTO_STALL then
    st.auto_pause = tick + General.AUTO_PAUSE
    log(string.format("[FO-CERVEAU] %s : recherche '%s' (automatisation) sans progres depuis %d min : les autres recherches passent %d min",
      f.key or "?", lab.tech, math.floor(General.AUTO_STALL / 3600), math.floor(General.AUTO_PAUSE / 3600)))
    lab.for_auto = nil
    lab.stalled = true
  end
  local k1 = wanted ~= nil and Auto.on()
  if st.auto_pause and tick < st.auto_pause then wanted = nil end
  if lab and lab.tech and not st.techs[lab.tech] and not lab.stalled then
    if ev.tfeas[lab.tech] then
      Profiler.stop("iag:choose")
      return lab.tech, true, {}, lab.palier, lab.for_auto
    end
    log(string.format("[FO-CERVEAU] %s : but '%s' abandonne (plus payable) a %.1f min", f.key or "?", lab.tech, minutes(f, tick)))
  end
  local disabled = {}
  for _, t in ipairs(c.tech_list) do
    local ft = force.technologies[t]
    if not ft or not ft.enabled then disabled[t] = true end
  end
  local speed = 1
  for _, l in ipairs(c.labs) do speed = math.max(speed, l.speed or 1) end
  local d = Gen.choose(c, ev, state, { weights = w, wanted = wanted, disabled = disabled, lab_speed = speed * math.max(1, nlabs),
    k1 = k1 or nil })
  -- Ce que rapporterait chaque ressource inconnue qu'un exécutant sait extraire (« quelles ressources peuvent rapporter ») :
  -- la meilleure, si elle rapporte, est à explorer (A6 : explorer pour une raison).
  local rv = Gen.resource_values(c, ev, state, { weights = w, wanted = wanted })
  local rv_txt = {}
  for i = 1, math.min(4, #rv) do rv_txt[#rv_txt + 1] = rv[i][1] .. " " .. rv[i][2] end
  if not d.tech then
    -- Rien de payable : les ressources inconnues qui bloquent la meilleure technologie de valeur sont à explorer.
    local causes, explore = {}, {}
    if rv[1] and rv[1][2] > 0 then explore[rv[1][1]] = 60 end
    if d.blocked[1] then
      local sum = Gen.summary(c, ev, state, { { tech = d.blocked[1].tech } })
      for _, res in ipairs(sum.explore) do if explorable(c, res) then explore[res] = 60 end end
      causes = sum.causes
    end
    g.explore = explore
    local sig = table.concat(causes, ",") .. "|" .. table.concat(sorted_keys(explore), ",")
    if g.blocked_sig ~= sig then
      g.blocked_sig = sig
      log(string.format("[FO-CERVEAU] %s : aucune technologie payable (%s) ; causes [%s] ; ressources inconnues qui rapporteraient [%s] ; exploration [%s] a %.1f min",
        f.key or "?", Gen.why_text(d), table.concat(causes, " "), table.concat(rv_txt, ", "),
        table.concat(sorted_keys(explore), " "), minutes(f, tick)))
    end
    Profiler.stop("iag:choose")
    return nil, false, causes, false
  end
  g.explore = {}
  if rv[1] and rv[1][2] > 0 then g.explore[rv[1][1]] = 40 end
  g.blocked_sig = nil
  local sum = Gen.summary(c, ev, state, { { tech = d.tech } })
  -- Lot IA3-e (points de jonction « hand », « produce », « extract », INTEGRATION.md §3) : objets que le dépliage fait
  -- fabriquer, produire ou extraire pour le but ; la règle « main ou machine » les pèse (script/ai3/automatisation.lua,
  -- input.items de A.decide) même sans charge mesurée. Chaînes seulement.
  local steps = {}
  for _, kind in ipairs({ "hand", "produce", "extract" }) do
    for _, k in ipairs(sorted_keys(sum[kind] or {})) do steps[#steps + 1] = k end
  end
  g.steps = steps
  -- Ressources clés : besoin BRUT des buts de référence (sans le stock consommable).
  local ds = General.state(f, st, view, true)
  local evd = Gen.prepare(c, ds, memo_of(f)) -- même clé (les points fixes ne lisent que le stock durable) : mémo
  local sumd = Gen.summary(c, evd, ds, ref_goals(f, d.tech))
  local key = Gen.key_resources(c, sumd, T.OUTPOST_ORDER, kind_of)
  -- Gardées seulement complètes (une ressource la plus demandée ET un combustible qu'un avant-poste rapporte) ; sinon
  -- le repli de shared/ai3/reglages.lua reste.
  if key.top and key.fuel then g.key = { top = key.top, fuel = key.fuel, order = key.order, optional = key.optional } end
  -- Technologies SUIVANTES (le classement de la décision) : packs fabriqués d'avance quand des bras sont libres.
  g.next = {}
  for i = 2, #(d.ranked or {}) do g.next[#g.next + 1] = d.ranked[i][1] end
  g.decisions = g.decisions + 1
  g.history[#g.history + 1] = { tech = d.tech, tick = tick, value = d.value, cost = d.cost }
  while #g.history > 32 do table.remove(g.history, 1) end
  log(string.format("[FO-CERVEAU] %s : but '%s' valeur %d cout %d score %d%s%s | %s | ressources cles : plus demandee %s, combustible %s, ordre %s, sans besoin [%s], besoins bruts %s | inconnues qui rapporteraient [%s] | %d pretes payables a %.1f min",
    f.key or "?", d.tech, d.value, d.cost, d.score, d.palier and " (palier)" or "",
    d.k1 and (" (K1 : " .. d.k1 .. ")") or ((d.auto and not d.k1_palier) and " (voulue par l'automatisation)" or ""),
    Gen.why_text(d, sum), tostring(key.top),
    tostring(key.fuel), table.concat(key.order, ","), table.concat(sorted_keys(key.optional), ","), Gen.fmt_map(key.need),
    table.concat(rv_txt, ", "), d.n_ready or 0, minutes(f, tick)))
  Profiler.stop("iag:choose")
  -- lot AUTO : for_auto (5e valeur, comme le choix de repli) : la recherche sert l'automatisation sans ouvrir de palier
  -- (garde AUTO_STALL ci-dessus ; plancher et plafond de shared/ai3/projets.lua, buts.lua, automatiser.lua A.goals)
  return d.tech, true, {}, d.palier, (k1 and d.auto and not d.k1_palier) or nil
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  local war = State.war()
  for _, id in ipairs(sorted_keys(war and war.factions)) do
    local f = war.factions[id]
    if f.key == key then return f end
  end
  return nil
end

remote.add_interface("fo-iag", {
  status = function(key)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    local g = f.team.iag or {}
    local out = { decisions = g.decisions or 0, history = {}, key = g.key, explore = sorted_keys(g.explore) }
    for i, h in ipairs(g.history or {}) do out.history[i] = { tech = h.tech, tick = h.tick, value = h.value, cost = h.cost } end
    return out
  end,
  catalogue = function()
    local c = General.catalogue()
    return { recipes = #c.g.recipe_list, techs = #c.tech_list, machines = #c.g.machine_list, packs = #c.pack_list,
      fuel = c.fuel }
  end,
})

return General
