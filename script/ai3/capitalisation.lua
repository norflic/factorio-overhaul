--[[
  Lot CAPIB « brancher la capitalisation » (demandes du DC du 27/10 : 12 h 05 « Le scaling des IA est aussi et surtout
  dans la maximisation des gisements, de la fonte et des crafts en fait, c'est le concept de capitalisation qu'il faut
  implémenter » ; 12 h 15 « A ne pas oublier toute la partie plus de gisements. Plus de fours (dans la limite de ce qu'on
  peut faire fondre évidemment), si assembleurs disponibles alors on ajoute des chaînes de production etc etc. » ; 12 h 30
  « un joueur […] aurait maximisé vraiment tout le gisement, il aurait mis des foreuses partout »).
  Côté RUNTIME de la règle pure shared/ai3/capitalisation.lua (conception : docs/IA_CAPITALISATION.md ; plan de
  branchement : fo-logs/2026-10-27_CAPI/INTEGRATION.md §5). Pour les FACTIONS seulement, réglage de carte fo-war-capi
  (ÉTEINT par défaut) ET automatisation allumée (fo-war-ia3e : sans son exécutant, ni foreuses électriques ni chaînes).

  Cycle d'une faction : une pensée sur 12 (une minute à une pensée toutes les 300 ticks), chaque pensée à son créneau
  de l'ordonnanceur (les factions sont décalées) et UNE seule étape coûteuse par pensée (coût étalé : jamais deux lectures
  de la carte dans la même pensée) :
    étape 0     relevé des machines, foreuses et laboratoires de la force autour du QG (un find_entities_filtered),
                foreuses des avant-postes lointains (listes de l'exécutant), graines de gisements ;
    étape 1     couverture MESURÉE de chaque gisement exploité : tuiles de minerai sous l'aire d'au moins une foreuse
                (aire lue sur le prototype, mining_drill_radius) ;
    étapes 2-9  RECENSEMENT d'un gisement par pensée (Sites.census : composante connexe ENTIÈRE, plus de 64 tuiles),
                relu toutes les Capi.CENSUS_EVERY ;
    étape 10    DÉCISION (Ca.decide) et ENVOI des ordres aux exécutants ; ligne « [FO-CAPI] <faction> minute M » ;
    toutes      suivi des ordres ouverts (état de l'exécutant, manques), buts de FOND du cerveau (Ca.goals).
  Exécutants (un seul décideur par levier ; périmètre RÉDUIT après les bancs p1 et p2 du lot, BRANCHEMENT.md §3) :
    couvrir/ouvrir, foreuse électrique  fonderies du plan directeur (gabarit à foreuses et tapis d'AUTO, Auto.submit), au
                                        débit des foreuses commandées, découpé en modules d'au plus A.FIRST_RATE_MAX
                                        objets/min : leurs fours sont dimensionnés par le gabarit sur le minerai des
                                        foreuses (critère (2)) ;
    chaine, packs                       rangées d'assembleurs du plan directeur (A.method_for, A.sized, Auto.submit) ;
    labos                               laboratoires du QG (research_step : nombre visé, Capi.labs_want) ;
    energie                             la centrale est demandée par AUTO avant le premier module électrique.
  Restent à leur décideur d'avant (refus écrit) : les avant-postes à COMBUSTION (croissance des buts, vagues de SCALE :
  leur charbon est porté par les PNJ, travail récurrent que la règle ne compte pas) et les fours du QG nourris par les PNJ
  (Br.smelters).
  Ce qui s'éteint sous la capitalisation : les demandes d'A.decide (il mesure encore), les vagues d'extraction et la
  croissance des capacités par manque (B.targets : s.capi), les vagues de fours de SCALE (Br.smelters) et le plafond de
  laboratoires (Br.labs_max, Ia3.LABS_MAX). Aucun nom du jeu ici (anti-échelle, tests/iag_test.lua §8) : objets,
  recettes, machines viennent des prototypes, des données de l'exécutant (shared/team/config.lua,
  shared/team/automatisation_donnees.lua par A.METHODS) et de la règle.
  Déterminisme : listes triées, aucun hasard, aucun temps mesuré ; état dans f.team.capi (global : nombres, chaînes,
  tables) ; cache LOCAL du relevé des prototypes seulement.
]]

local T = require("shared.team.config")
local Ca = require("shared.ai3.capitalisation")
local A = require("shared.ai3.automatiser")
local R = require("shared.ai3.reglages")
local Pl = require("shared.team.plan")
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Sites = require("script.faction.sites")
local Profiler = require("script.core.profiler")
local General = require("script.ai3.general")
local Auto = require("script.ai3.automatisation")
local Build = require("script.team.build")
local Adopte = require("script.team.adopte") -- lot ADOPTE : machines du joueur que personne ne sert
local Equip = require("script.team.equiper") -- lot LEVIERS : tâche « equiper »
local Lv = require("shared.ai3.leviers")
local MM = require("shared.content.module_mult")

local Capi = {}

Capi.SETTING = "fo-war-capi"
Capi.ENABLED = true
Capi.CYCLE = 12              -- pensées par cycle (une minute à une pensée toutes les 300 ticks)
Capi.SCAN_R = 160            -- tuiles autour du QG : machines, foreuses, gisements connus
Capi.HQ_R = 40               -- une machine à moins de 40 tuiles du QG est « au QG »
Capi.DEP_MAX = 16            -- gisements suivis au plus par faction (les plus proches)
Capi.CENSUS_EVERY = 5 * 3600 -- un gisement est relu toutes les 5 min
Capi.ORDER_TTL = 30 * 3600   -- un ordre qui n'avance plus depuis 30 min est retiré (refus écrit)
Capi.LOG_ORDERS = 64         -- lignes d'ordres gardées pour l'interface des bancs
Capi.QUEUE_MAX = 12          -- technologies au plus dans la file de recherche vue par la règle (recherche élastique)
Capi.BACKOFF = 10 * 3600     -- un produit refusé par le plan directeur n'est plus demandé pendant 10 min × 2^(refus - 1),
Capi.BACKOFF_MAX = 40 * 3600 -- au plus 40 min (banc p3 du lot : 63 demandes refusées d'un même produit en 50 min, un plan
                             -- coûte 25 à 40 ms : comme AUTO, un refus vaut tant que le contexte n'a pas changé)
Capi.EQUIP_BATCH = 6         -- lot LEVIERS : machines équipées par tâche de PNJ (Equip.BATCH)
Capi.UNITS_MAX = 48          -- lot LEVIERS : machines gardées par groupe au relevé (positions, pour la tâche « equiper »)
Capi.MODULES_PER_ORDER = 1   -- modules du plan directeur au plus par ordre (chacun au plus A.FIRST_RATE_MAX objets/min :
                             -- un gabarit plus grand ne tient pas dans un lot, moteur réel p1, « pas de lot », « trop grand »).
                             -- 3 avant le banc p4 : le plan directeur RÉSERVE au coffre toute la matière d'un module dès sa
                             -- demande (Build.reserve) ; plusieurs modules à la fois vidaient le fer du QG (« stock iron=5 »)
                             -- et l'économie s'arrêtait (3 factions sur 4 à plus de 60 % de PNJ sans tâche après 40 min).

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

function Capi.on(f)
  -- Votre équipe aussi (27/10 au soir) : « si elles ont des ressources, elles veulent encore plus de ressources ».
  if not (Capi.ENABLED and f and f.team and f.team.ia3 and f.hq and f.hq.valid) then return false end
  local war = State.war()
  if war and war.capi_off then return false end
  local s = settings.global[Capi.SETTING]
  if not (s and s.value == true) then return false end
  return Auto.on() and true or false
end

-- Ordres nouveaux au plus par décision (Ca.MAX_ORDERS : 24 dans la règle pure) : le glouton recalcule TOUTES les options
-- après chaque ordre retenu ; l'exécutant n'en prend de toute façon que A.MAX_OPEN à la fois. Banc p4 du lot : décision à
-- 1,45 ms en médiane dans son tick, 5,2 ms au p90, 37 % au-dessus de 2 ms (banc non seul).
Capi.MAX_ORDERS = 4
Ca.MAX_ORDERS = Capi.MAX_ORDERS

-- Sous la capitalisation, A.decide ne demande plus rien (il mesure encore) : un seul décideur.
Auto.decide_off = function(f) return Capi.on(f) end

---------------------------------------------------------------------------------------------------
-- Relevé des prototypes (cache LOCAL : prototypes seulement, identiques chez tous les pairs)
---------------------------------------------------------------------------------------------------
local data_cache = {}
local elec_drill = nil

--- Lot LEVIERS : relevé des modules (effets en centièmes, recettes permises), des emplacements de chaque machine et des
--- recherches à effet (types de R.LEVER_EFFECT) : ce que lit shared/ai3/leviers.lua (Lv.build). Prototypes seulement.
local function lever_dump(d)
  local lv = { equip = {}, slots = {}, techs = {} }
  local protos = game.get_filtered_item_prototypes({ { filter = "type", type = R.ITEM_MODULE } })
  for _, name in ipairs(sorted_keys(protos)) do
    -- les modules cachés du complément de la balise (MOD-0) ne sont pas à vendre
    if name:sub(1, #MM.PREFIX) ~= MM.PREFIX then
      local p = protos[name]
      local eff, me = {}, get(p, "module_effects") or {}
      for _, ef in ipairs(sorted_keys(me)) do eff[ef] = MM.runtime_cents(me[ef].bonus) end
      local lim = get(p, "limitations")
      lv.equip[name] = { effects = eff, limit = (lim and #lim > 0) and lim or nil }
    end
  end
  for _, e in ipairs(d.entities) do
    local p = game.entity_prototypes[e.name]
    local n = p and get(p, "module_inventory_size") or 0
    if n and n > 0 then lv.slots[e.name] = { n = n, allowed = get(p, "allowed_effects") or {} } end
  end
  for _, name in ipairs(sorted_keys(game.technology_prototypes)) do
    local t = game.technology_prototypes[name]
    if not t.research_unit_count_formula then
      local list = {}
      for _, e in ipairs(t.effects or {}) do
        if R.LEVER_EFFECT[e.type] and e.modifier then list[#list + 1] = { type = e.type, modifier = e.modifier } end
      end
      if #list > 0 then lv.techs[name] = list end
    end
  end
  return lv
end

local function dump_full()
  local d = General.dump()
  for _, e in ipairs(d.entities) do
    local p = game.entity_prototypes[e.name]
    if p then
      local conv = Ca.entity_of({ crafting_speed = get(p, "crafting_speed"), mining_speed = get(p, "mining_speed"),
        researching_speed = get(p, "researching_speed"), resource_searching_radius = get(p, "mining_drill_radius"),
        tile_width = get(p, "tile_width"), energy_usage = get(p, "energy_usage") or get(p, "max_energy_usage") })
      e.speed = e.speed or conv.speed
      e.mining_area = conv.mining_area
      e.size = conv.size
      e.energy_kw = conv.energy_kw
    end
  end
  for _, r in ipairs(d.resources) do
    local p = game.entity_prototypes[r.entity]
    local mp = p and get(p, "mineable_properties")
    r.mining_time = (mp and mp.mining_time) or 1
  end
  d.lv = lever_dump(d)
  return d
end

--- Données de la règle (Ca.data) pour l'état du réglage de l'automatisation (exécutants).
function Capi.data()
  local on = Auto.on() and true or false
  local D = data_cache[on]
  if D then return D end
  Profiler.start("capi:data")
  local d = dump_full()
  local eo = General.exec_opts(on, d.recipes)
  local exec = {}
  for _, k in ipairs(sorted_keys(eo.exec)) do if eo.exec[k] then exec[k] = true end end
  D = Ca.data(d, { exec = exec, exec_roles = eo.exec_roles, cat = General.catalogue() })
  data_cache[on] = D
  -- Foreuse électrique de l'exécutant : celle que pose le gabarit de fonderie (entités d'AUTO), alimentée au courant.
  local auto_set = {}
  for _, n in ipairs(Auto.exec_entities()) do auto_set[n] = true end
  elec_drill = nil
  for _, m in ipairs(D.drills) do
    if auto_set[m.name] and m.energy == "electric" and not elec_drill then elec_drill = m.name end
  end
  Profiler.stop("capi:data")
  log(string.format("[FO-CAPI] releve des prototypes : %d recettes, %d fabriques, %d foreuses, %d laboratoires, combustible %s, foreuse electrique de l'executant %s",
    #D.recipe_list, #D.makers, #D.drills, #D.labs, tostring(D.fuel), tostring(elec_drill)))
  return D
end

---------------------------------------------------------------------------------------------------
-- État de la faction (global)
---------------------------------------------------------------------------------------------------
local function state_of(f)
  local t = f.team
  t.capi = t.capi or { v = 1, n = 0, st = {}, deps = {}, seeds = {}, open = {}, done = {}, refused = {}, prod = {},
    flows = {}, scan = nil, cov = {}, census_i = 0, decisions = 0, orders = 0, stats = {}, series = {} }
  return t.capi
end

---------------------------------------------------------------------------------------------------
-- Méthodes de l'exécutant (fonderies à foreuses d'AUTO) : minerai -> méthode
---------------------------------------------------------------------------------------------------
local METHOD_OF_ORE = {}
for _, m in ipairs(A.METHODS) do if m.ore and not METHOD_OF_ORE[m.ore] then METHOD_OF_ORE[m.ore] = m end end
local KIND_OF_RES = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do KIND_OF_RES[T.outposts[kind].resource] = kind end

--- Une fonderie à foreuses de ce minerai peut-elle se poser MAINTENANT (tous ses objets fabricables ou au coffre) ?
--- Rend vrai, ou faux et les objets manquants (la recherche qui les débloque prend de la valeur : Auto.wanted).
--- Gabarit d'une méthode au débit `rate`, RÉDUIT (paramètre agrandi pas à pas vers 1) jusqu'à ce que l'équipe sache
--- fabriquer tous ses objets (comme A.decide : un module plus grand demande des bras rapides ou d'autres objets pas encore
--- recherchés ; banc p4 du lot : modules à 150/min en réserve 15 min sur « fast-inserter », jamais recherché). Rend
--- (gabarit, args) ou (nil, objets manquants de la plus petite taille).
local function fit_module(meth, rate, book, stock, has_plant)
  -- lot PLANDIR : poteau du gabarit = le moins cher dont la recette est débloquée (A.choose_pole)
  local pole = A.choose_pole(book, stock)
  local g, args = A.sized(meth, rate, pole)
  if not g then return nil, {} end
  local function missing_of(gg)
    local _, items = A.cost(meth, gg, { has_plant = has_plant })
    local miss = {}
    for _, name in ipairs(sorted_keys(items)) do
      if not (book:handcraftable(name) or (stock[name] or 0) > 0) then miss[#miss + 1] = name end
    end
    return miss
  end
  local miss = missing_of(g)
  while #miss > 0 and g.ext and (args[g.ext.arg] or 1) > 1 do
    local a2 = {}
    for i = 1, #args do a2[i] = args[i] end
    a2[g.ext.arg] = args[g.ext.arg] - 1
    local g2 = A.template(meth.gen, a2, pole)
    if not g2 then break end
    g, args = g2, a2
    miss = missing_of(g)
  end
  if #miss > 0 then return nil, miss end
  return g, args
end

local function module_ok(meth, book, stock, has_plant, rate)
  local g, miss = fit_module(meth, math.min(rate or A.FIRST_RATE_MAX, A.FIRST_RATE_MAX), book, stock, has_plant)
  if not g then return false, miss end
  return true, {}
end

---------------------------------------------------------------------------------------------------
-- Étape 0 : relevé des machines, foreuses, laboratoires ; graines de gisements
---------------------------------------------------------------------------------------------------
-- Types du moteur relevés : ceux des rôles fabrique, foreuse, laboratoire (shared/ai3/reglages.lua, seules données
-- nommées admises par l'anti-échelle).
local SCAN_ROLES = { fabrique = true, foreuse = true, labo = true }
local SCAN_TYPES = {}
for _, ty in ipairs(R.ENTITY_TYPES) do if SCAN_ROLES[R.ENTITY_ROLE[ty]] then SCAN_TYPES[#SCAN_TYPES + 1] = ty end end

local function dist(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return math.sqrt(dx * dx + dy * dy)
end

local function dep_at(cs, res, x, y)
  for _, id in ipairs(sorted_keys(cs.deps)) do
    local d = cs.deps[id]
    if d.resource == res and x >= d.x0 - 3 and x <= d.x1 + 3 and y >= d.y0 - 3 and y <= d.y1 + 3 then return d end
  end
  return nil
end

--- Lot LEVIERS : modules posés dans une machine ({ [objet] = nombre } ou nil) et leur signature (clé de groupe).
local function modules_of(e)
  local ok, inv = pcall(function() return e.get_module_inventory() end)
  if not ok or not inv or #inv == 0 then return nil, "-" end
  local c = inv.get_contents()
  if next(c) == nil then return nil, "-" end
  local mods = {}
  for _, nm in ipairs(sorted_keys(c)) do mods[nm] = c[nm] end
  return mods, Lv.sig(mods)
end

local function scan(f, cs, tick)
  local surface = f.hq.surface
  local hq = f.hq_pos
  local found = surface.find_entities_filtered({ area = { { hq.x - Capi.SCAN_R, hq.y - Capi.SCAN_R },
    { hq.x + Capi.SCAN_R, hq.y + Capi.SCAN_R } }, force = f.force, type = SCAN_TYPES })
  local seen = {}
  local list = {}
  for _, e in ipairs(found) do
    if e.valid and e.unit_number and not seen[e.unit_number] then seen[e.unit_number] = true list[#list + 1] = e end
  end
  -- Foreuses des avant-postes lointains (listes de l'exécutant).
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    for _, d in ipairs(f.outposts[oid].drill_list or {}) do
      if d.valid and d.unit_number and not seen[d.unit_number] then seen[d.unit_number] = true list[#list + 1] = d end
    end
  end
  table.sort(list, function(a, b) return a.unit_number < b.unit_number end)
  local machines, drills, labs = {}, {}, {}
  local mk, dk, lk = {}, {}, {}
  local drill_pos = {}
  for _, e in ipairs(list) do
    local p = e.position
    local role = R.ENTITY_ROLE[e.type]
    if role == "foreuse" then
      local tgt = e.mining_target
      local res = tgt and tgt.valid and tgt.name or nil
      if res then
        local d = dep_at(cs, res, p.x, p.y)
        local did = d and d.id or "?"
        local mods, sig = modules_of(e)
        local k = e.name .. "|" .. res .. "|" .. did .. "|" .. sig
        if not dk[k] then
          dk[k] = { entity = e.name, resource = res, n = 0, deposit = did, mods = mods, sig = sig, units = {} }
          drills[#drills + 1] = dk[k]
        end
        dk[k].n = dk[k].n + 1
        if #dk[k].units < Capi.UNITS_MAX then dk[k].units[#dk[k].units + 1] = { x = p.x, y = p.y, u = e.unit_number } end
        drill_pos[#drill_pos + 1] = { x = p.x, y = p.y, r = get(e.prototype, "mining_drill_radius") or 1, res = res, dep = did }
      end
    elseif role == "labo" then
      if not lk[e.name] then lk[e.name] = { entity = e.name, n = 0 } labs[#labs + 1] = lk[e.name] end
      lk[e.name].n = lk[e.name].n + 1
    elseif Adopte.unserved(f, e) then
      -- lot ADOPTE : machine posée à la main, isolée et non servie par l'équipe (hors rayon, réglage coupé) : pas une capacité
    else
      local r = nil
      local ok = pcall(function() r = e.get_recipe() end)
      if not ok or not r then pcall(function() r = e.previous_recipe end) end
      if r then
        local where = dist(p, hq) <= Capi.HQ_R and Ca.HQ or "?"
        if where ~= Ca.HQ then
          -- fonte sur place : un four sur le bord d'un gisement de son minerai
          for _, ing in ipairs(r.ingredients) do
            local d = dep_at(cs, ing.name, p.x, p.y)
            if d then where = d.id break end
          end
          if where == "?" then where = "loin" end
        end
        local mods, sig = modules_of(e)
        local k = e.name .. "|" .. r.name .. "|" .. where .. "|" .. sig
        if not mk[k] then
          mk[k] = { entity = e.name, recipe = r.name, n = 0, where = where, mods = mods, sig = sig, units = {} }
          machines[#machines + 1] = mk[k]
        end
        mk[k].n = mk[k].n + 1
        if #mk[k].units < Capi.UNITS_MAX then mk[k].units[#mk[k].units + 1] = { x = p.x, y = p.y, u = e.unit_number } end
      end
    end
  end
  cs.scan = { tick = tick, machines = machines, drills = drills, labs = labs, drill_pos = drill_pos }
  -- Graines de gisements : avant-postes, foreuses, gisements connus (carte d'IA3-f), sites prospectés, lots de gisement
  -- du plan directeur. Une graine déjà dans un gisement recensé n'est pas relue (sauf à l'échéance du recensement).
  local seeds = {}
  local function seed(res, x, y)
    if not (res and x and y) then return end
    if dist({ x = x, y = y }, hq) > Capi.SCAN_R + 64 then return end
    seeds[#seeds + 1] = { res = res, x = math.floor(x), y = math.floor(y) }
  end
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    seed(T.outposts[o.kind] and T.outposts[o.kind].resource, o.pos.x, o.pos.y)
  end
  for _, dp in ipairs(drill_pos) do seed(dp.res, dp.x, dp.y) end
  local Ia3 = package.loaded["script.ai3.cerveau"]
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local res = T.outposts[kind].resource
    local kd = Ia3 and Ia3.known_deposits and Ia3.known_deposits(f, res, tick) or nil
    for i, d in ipairs(kd or {}) do
      if i > 4 then break end
      if (d.distance or 0) <= Capi.SCAN_R then seed(res, d.x, d.y) end
    end
  end
  for _, s in ipairs(f.prospects or {}) do seed(s.resource, s.x, s.y) end
  local b = f.build
  if b then
    for _, k in ipairs(sorted_keys(b.lots)) do
      local l = b.lots[k]
      if l.state == "gisement" and (l.res or l.ore) then
        local x0, y0, x1, y1 = Pl.lot_rect(b.lat, l.i, l.j)
        seed(l.res or l.ore, (x0 + x1) / 2, (y0 + y1) / 2)
      end
    end
  end
  table.sort(seeds, function(a, c)
    local da, dc = dist(a, hq), dist(c, hq)
    if da ~= dc then return da < dc end
    if a.res ~= c.res then return a.res < c.res end
    if a.x ~= c.x then return a.x < c.x end
    return a.y < c.y
  end)
  cs.seeds = seeds
  -- graines oubliées après deux échéances du recensement
  for _, k in ipairs(sorted_keys(cs.seed_seen or {})) do
    if tick - cs.seed_seen[k] >= 2 * Capi.CENSUS_EVERY then cs.seed_seen[k] = nil end
  end
end

---------------------------------------------------------------------------------------------------
-- Étape 1 : couverture mesurée des gisements exploités
---------------------------------------------------------------------------------------------------
local OFF = 1048576
local function tkey(x, y) return (x + OFF) * 2097152 + (y + OFF) end

local function coverage(f, cs)
  local sc = cs.scan
  if not sc then return end
  local surface = f.hq.surface
  local by_dep = {}
  for _, dp in ipairs(sc.drill_pos) do
    if dp.dep ~= "?" then
      by_dep[dp.dep] = by_dep[dp.dep] or {}
      local l = by_dep[dp.dep]
      l[#l + 1] = dp
    end
  end
  cs.cov = {}
  for _, id in ipairs(sorted_keys(by_dep)) do
    local d = cs.deps[id]
    if d then
      local idx = {}
      for _, e in ipairs(surface.find_entities_filtered({ area = { { d.x0, d.y0 }, { d.x1, d.y1 } }, name = d.resource })) do
        idx[tkey(math.floor(e.position.x), math.floor(e.position.y))] = true
      end
      local seen, n = {}, 0
      for _, dp in ipairs(by_dep[id]) do
        local r = dp.r
        for x = math.floor(dp.x - r + 0.01), math.floor(dp.x + r - 0.01) do
          for y = math.floor(dp.y - r + 0.01), math.floor(dp.y + r - 0.01) do
            local k = tkey(x, y)
            if idx[k] and not seen[k] then seen[k] = true n = n + 1 end
          end
        end
      end
      cs.cov[id] = n
      d.covered = n
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Étapes 2 à 9 : recensement d'un gisement
---------------------------------------------------------------------------------------------------
local function census_one(f, cs, tick)
  local surface = f.hq.surface
  local seeds = cs.seeds or {}
  local n = #seeds
  if n == 0 then return end
  for _ = 1, n do
    cs.census_i = (cs.census_i % n) + 1
    local s = seeds[cs.census_i]
    local d = dep_at(cs, s.res, s.x, s.y)
    -- une graine relue il y a moins de Capi.CENSUS_EVERY n'est pas relue (une graine HORS de la boîte de son gisement :
    -- centre de site prospecté, gisement connu ; banc p3 : le même gisement recensé à chaque pensée, 4 s de script)
    local sk = s.res .. "@" .. s.x .. "," .. s.y
    cs.seed_seen = cs.seed_seen or {}
    local fresh = cs.seed_seen[sk] and tick - cs.seed_seen[sk] < Capi.CENSUS_EVERY
    if not fresh and (not d or tick - (d.tick or 0) >= Capi.CENSUS_EVERY) then
      cs.seed_seen[sk] = tick
      local c = Sites.census(surface, s.res, { x = s.x + 0.5, y = s.y + 0.5 })
      if c then
        -- une composante déjà connue sous un autre identifiant (coin épuisé) : la même entrée, mise à jour
        local old = dep_at(cs, s.res, c.cx, c.cy)
        if old and old.id ~= c.id then cs.deps[old.id] = nil end
        local hostile = surface.count_entities_filtered({ position = { x = c.cx, y = c.cy }, radius = 40, force = "enemy",
          limit = 1 }) > 0
        cs.deps[c.id] = { id = c.id, resource = s.res, tiles = c.tiles, amount = c.amount, x0 = c.x0, y0 = c.y0, x1 = c.x1,
          y1 = c.y1, cx = c.cx, cy = c.cy, tick = tick, cut = c.cut, danger = hostile or nil,
          covered = old and old.covered or (cs.deps[c.id] and cs.deps[c.id].covered) or nil }
        -- au plus Capi.DEP_MAX gisements : les plus lointains sont oubliés
        local ids = sorted_keys(cs.deps)
        if #ids > Capi.DEP_MAX then
          table.sort(ids, function(a, b)
            local da, db = dist({ x = cs.deps[a].cx, y = cs.deps[a].cy }, f.hq_pos), dist({ x = cs.deps[b].cx, y = cs.deps[b].cy }, f.hq_pos)
            if da ~= db then return da < db end
            return a < b
          end)
          for i = Capi.DEP_MAX + 1, #ids do cs.deps[ids[i]] = nil end
        end
      end
      return
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Entrée de la règle
---------------------------------------------------------------------------------------------------
--- Débits par objet sur la minute écoulée (statistiques de production de la force : machines et foreuses ; la fabrication
--- par script des PNJ n'y entre pas, F244). Rend { [objet] = { made } }.
local function flows_of(f, cs)
  local force = game.forces[f.force]
  local stats = nil
  pcall(function() stats = force.item_production_statistics end)
  local cur = {}
  if stats then pcall(function() cur = stats.input_counts end) end
  local out = {}
  local prev = cs.prod or {}
  for _, k in ipairs(sorted_keys(cur)) do
    local d = (cur[k] or 0) - (prev[k] or 0)
    if d > 0 and prev[k] ~= nil then out[k] = { made = d } end
  end
  cs.prod = cur
  -- Fabrication À LA MAIN des PNJ (insérée par script : hors des statistiques, F244) : compteurs de l'automatisation
  -- (f.team.ia3e.hand_all, objets fabriqués). Elle nourrit aujourd'hui (couverture d'un ingrédient, packs des
  -- laboratoires) sans être du capital (Ca.HAND_CAPITAL = 0).
  local ha = (f.team.ia3e and f.team.ia3e.hand_all) or {}
  local hp = cs.hand_prev or {}
  for _, k in ipairs(sorted_keys(ha)) do
    local d = (ha[k] or 0) - (hp[k] or 0)
    if d > 0 and hp[k] ~= nil then
      local o = out[k] or { made = 0 }
      o.made = (o.made or 0) + d
      o.hand = (o.hand or 0) + d
      out[k] = o
    end
  end
  local copy = {}
  for _, k in ipairs(sorted_keys(ha)) do copy[k] = ha[k] end
  cs.hand_prev = copy
  return out
end

--- File de recherche : la technologie en cours (unités restantes) puis les suivantes du cerveau général.
local function research_of(f, cs)
  local st = f.team.ia3
  local c = General.catalogue()
  local q = {}
  local lab = st.lab or {}
  local function add(tech, left)
    local spec = c.techs[tech]
    if not spec or left <= 0 then return end
    local packs = {}
    for _, ing in ipairs(spec.ingredients or {}) do packs[#packs + 1] = { ing[1], ing[2] } end
    q[#q + 1] = { tech = tech, left = left, time = spec.time or 1, packs = packs }
  end
  if lab.tech and c.techs[lab.tech] then add(lab.tech, c.techs[lab.tech].count - (lab.units or 0)) end
  local g = f.team.iag
  local seen = { [lab.tech or ""] = true }
  for _, t in ipairs((g and g.next) or {}) do
    if not seen[t] and not (st.techs or {})[t] and c.techs[t] then
      seen[t] = true
      add(t, c.techs[t].count)
    end
  end
  -- Recherche ÉLASTIQUE (lot CAPIB, banc p3 : « recherche=47 s/min, labos=1 » à 60 min, épargne de 19 000 MU sans ordre) :
  -- un joueur ne s'arrête pas à la technologie suivante. La file vue par la règle compte aussi les technologies que la
  -- force peut chercher avec les packs qu'elle sait déjà fabriquer (recettes de packs ouvertes), les moins chères
  -- d'abord (unités × temps, puis le nom), au plus Capi.QUEUE_MAX : la demande de packs grandit avec la règle (g par
  -- cycle, jamais plus de Ca.LEAD × ce qui tourne), et avec elle les chaînes et l'extraction en amont.
  local force = game.forces[f.force]
  local open_pack = {}
  for _, p in ipairs(c.pack_list or {}) do
    local r = force and force.recipes[p]
    if r and r.enabled then open_pack[p] = true end
  end
  local extra = {}
  for _, t in ipairs(c.tech_list or sorted_keys(c.techs)) do
    local spec = c.techs[t]
    if spec and not seen[t] and not (st.techs or {})[t] then
      local ok = #(spec.ingredients or {}) > 0
      for _, ing in ipairs(spec.ingredients or {}) do if not open_pack[ing[1]] then ok = false end end
      if ok then extra[#extra + 1] = { t = t, cost = (spec.count or 1) * (spec.time or 1) } end
    end
  end
  table.sort(extra, function(a, b) if a.cost ~= b.cost then return a.cost < b.cost end return a.t < b.t end)
  for i = 1, math.min(Capi.QUEUE_MAX, #extra) do add(extra[i].t, c.techs[extra[i].t].count) end
  -- débit de recherche MESURÉ (secondes de laboratoire par minute) : unités payées depuis la minute précédente
  local key = tostring(lab.tech) .. ":" .. tostring(lab.started or 0)
  local units = lab.units or 0
  local rate = 0
  if cs.r_key == key and cs.r_units then
    local du = units - cs.r_units
    local spec = lab.tech and c.techs[lab.tech]
    if du > 0 and spec then rate = du * (spec.time or 1) end
  end
  cs.r_key, cs.r_units = key, units
  -- laboratoires affamés : des laboratoires, une technologie en cours, et un de ses packs absent du coffre du QG (‰)
  local nlabs = 0
  for _, e in ipairs(st.labs or {}) do if e.valid then nlabs = nlabs + 1 end end
  local starved = 0
  local spec = lab.tech and c.techs[lab.tech]
  if nlabs > 0 and spec and f.hq and f.hq.valid then
    for _, ing in ipairs(spec.ingredients or {}) do
      if Stock.count(f, ing[1]) < (ing[2] or 1) then starved = 1000 end
    end
  end
  return { queue = q, rate = rate, starved = starved }, nlabs
end

--- Produit en repli après un refus du plan directeur (rend la raison, ou nil).
local function held(cs, product, tick)
  local b = (cs.backoff or {})[product]
  if b and tick < b.until_tick then
    return string.format("repli apres %d refus du plan directeur (%s) jusqu'a %.0f min", b.n, tostring(b.why), b.until_tick / 3600)
  end
  return nil
end

local function hold(cs, product, why, tick)
  cs.backoff = cs.backoff or {}
  local b = cs.backoff[product] or { n = 0 }
  b.n = b.n + 1
  b.why = why
  b.until_tick = tick + math.min(Capi.BACKOFF_MAX, Capi.BACKOFF * 2 ^ (b.n - 1))
  cs.backoff[product] = b
end

-- Lot LEVIERS : machines supérieures de chaque machine posée, lues aux prototypes par le lot AMELIORER (Cap.successors, via
-- Capital.successors_of : aucune logique de successeur ici). Cache LOCAL (prototypes seulement). Nil : la fonction n'existe pas.
local succ_cache = {}
local function successors_for(cs)
  local Cp = package.loaded["script.ai3.capital"]
  if not (Cp and Cp.successors_of) then return nil end
  local out = {}
  for _, m in ipairs(cs.scan and cs.scan.machines or {}) do
    if out[m.entity] == nil then
      local l = succ_cache[m.entity]
      if l == nil then
        l = Cp.successors_of(m.entity) or {}
        succ_cache[m.entity] = l
      end
      out[m.entity] = l
    end
  end
  return out
end

local function build_input(f, cs, view, book, tick, D, w)
  local st = f.team.ia3
  local force = game.forces[f.force]
  D.bonus.mining = (force and force.mining_drill_productivity_bonus) or 0
  D.bonus.lab = (force and force.laboratory_speed_modifier) or 0
  local stock = view.stock or {}
  -- foreuse imposée par ressource : électrique (fonderie du plan directeur) si le gabarit se pose aujourd'hui ; sinon
  -- AUCUNE (« » : la règle refuse « aucune foreuse disponible »). Les avant-postes à combustion restent au décideur
  -- d'avant (croissance des buts et vagues de SCALE) : leur combustible est porté par les PNJ, un travail récurrent que
  -- la règle ne compte pas (moteur réel, bancs p1 et p2 du lot : avant-postes « pleins », puis 75 à 102 foreuses à
  -- combustion sans charbon, fer extrait divisé par 4, 50 à 75 % de PNJ sans tâche).
  local drill_for, elec = {}, {}
  local plant_state, plant_why = Auto.plant_state(f)
  -- Centrale demandée mais pas finie : un seul module électrique ouvert à la fois (celui qui l'a fait demander) ; les
  -- suivants attendent le réseau (banc p3 du lot : « pas de rue vers le reseau », « pas de centrale » à la chaîne).
  local elec_open = 0
  for _, o in ipairs(cs.open) do if o.exec == "module" then elec_open = elec_open + 1 end end
  local wait_plant = plant_state ~= nil and plant_state ~= "fini" and elec_open > 0
  -- Au plus A.MAX_OPEN modules ouverts à la fois (la limite de l'exécutant, celle d'AUTO) : la matière réservée par le plan
  -- directeur ne doit pas vider le coffre (banc p4).
  local busy = elec_open >= A.MAX_OPEN
  local wanted = {}
  for _, res in ipairs(D.res_list) do
    local meth = METHOD_OF_ORE[res]
    local ok, miss = false, {}
    if meth and elec_drill and plant_state ~= "refuse" and not wait_plant and not busy and not held(cs, meth.product, tick) then
      ok, miss = module_ok(meth, book, stock, plant_state ~= nil)
    end
    if ok then drill_for[res], elec[res] = elec_drill, true
    else drill_for[res] = "" end
    for _, m in ipairs(miss) do wanted[m] = true end
  end
  cs.wanted_set = wanted
  -- gisements : recensés, ouverts s'ils portent une foreuse de la force ou un avant-poste ; portée du plan directeur
  local reach = (Build.RADIUS_MAX + 0.5) * Pl.PITCH
  local open_dep = {}
  for _, dr in ipairs(cs.scan and cs.scan.drills or {}) do if dr.deposit ~= "?" then open_dep[dr.deposit] = true end end
  local deposits = {}
  for _, id in ipairs(sorted_keys(cs.deps)) do
    local d = cs.deps[id]
    local blocked = nil
    if cs.block_all then blocked = "interdit (banc)" end -- lot LEVIERS : banc « tous les sites interdits » (remote block_sites)
    local smelt, smelter = nil, nil
    if elec[d.resource] then
      local far = math.max(math.abs(d.cx - f.hq_pos.x), math.abs(d.cy - f.hq_pos.y))
      if far > reach then blocked = "hors du plan directeur" end
      local meth = METHOD_OF_ORE[d.resource]
      smelter = meth.args[1]
      for _, rn in ipairs(D.producers[meth.product] or {}) do
        local r = D.recipes[rn]
        for _, i in ipairs(r.ingredients) do if i.name == d.resource and not smelt then smelt = rn end end
      end
    end
    deposits[#deposits + 1] = { id = id, resource = d.resource, tiles = d.tiles, amount = d.amount, covered = d.covered,
      dist = math.floor(dist({ x = d.cx, y = d.cy }, f.hq_pos)), open = open_dep[id] or false, smelt = smelt,
      smelter = smelter, danger = d.danger, blocked = blocked }
  end
  -- ordres ouverts : reste à poser
  local open = {}
  for _, o in ipairs(cs.open) do
    open[#open + 1] = { key = o.key, kind = o.kind, item = o.item, resource = o.resource, deposit = o.deposit,
      entity = o.entity, n = o.n, n_left = o.n_left or o.n, rate = o.rate, where = o.where, smelt_n = o.smelt_n,
      smelt_left = o.smelt_left, smelt_recipe = o.smelt_recipe, smelt_entity = o.smelt_entity, missing = o.missing or {},
      work_left = o.work_left, value = o.value,
      -- lot LEVIERS : ce que l'ordre ajoute au plan tant qu'il n'est pas fini
      tech = o.tech, d_item = o.d_item, d_out = o.d_out, d_in = o.d_in, d_kw = o.d_kw, d_fuel = o.d_fuel }
  end
  local research, nlabs = research_of(f, cs)
  cs.nlabs = nlabs
  local labs = {}
  for _, l in ipairs(cs.scan and cs.scan.labs or {}) do labs[#labs + 1] = { entity = l.entity, n = l.n } end
  -- besoin des buts SANS les buts capi ni la recherche : le besoin de matière de la dernière pensée (manque + usage)
  local need = {}
  for _, k in ipairs(sorted_keys(st.need)) do need[k] = st.need[k] end
  -- L'exécutant des chaînes (rangées du plan directeur) sait-il les poser aujourd'hui ? (mémo de la décision)
  local ce_memo = {}
  local function can_exec(kind, item)
    -- fours du QG : nourris à la main par les PNJ (tâches de fonte du cerveau) ; leur nombre reste au décideur d'avant
    -- (Br.smelters, SCALE). Moteur réel, banc p2 du lot : 25 fours du QG commandés « d'avance » pour les briques, 25
    -- affamés sur 26 (aucune tâche de fonte ne les nourrit sans manque). La fonte au débit des foreuses passe par les
    -- fonderies à foreuses (ordre « couvrir » : leurs fours sont dimensionnés par le gabarit sur le minerai des foreuses).
    if kind == "fours" then return "fours du QG nourris par les PNJ : decideur SCALE (Br.smelters)" end
    -- Lot LEVIERS : un module s'insère s'il est au coffre, ou si l'équipe sait le fabriquer à la main aujourd'hui (la
    -- recherche qui le débloque est sinon DEMANDÉE : wanted, donnée à la recherche par Auto.want).
    if kind == "equiper" then
      local m2 = ce_memo[item]
      if m2 ~= nil then return m2 or nil end
      local res2 = nil
      if (stock[item] or 0) <= 0 and not book:handcraftable(item) then
        res2 = "recherche : " .. item
        wanted[item] = true
      end
      ce_memo[item] = res2 or false
      return res2
    end
    local m = ce_memo[item]
    if m ~= nil then return m or nil end
    local meth, why = A.method_for(item, book)
    local res = nil
    local hw = held(cs, item, tick)
    if not meth then res = tostring(why)
    elseif hw then res = hw
    elseif busy then res = "plan directeur occupe (" .. elec_open .. " module(s) ouvert(s), au plus " .. A.MAX_OPEN .. ")"
    elseif wait_plant and ((A.template(meth.gen, meth.args) or {}).power_kw or 0) > 0 then
      res = "centrale demandee, pas finie (" .. tostring(plant_state) .. ")"
    elseif plant_state == "refuse" and ((A.template(meth.gen, meth.args) or {}).power_kw or 0) > 0 then
      res = "centrale refusee (" .. tostring(plant_why) .. ")"
    else
      local ok, miss = module_ok(meth, book, stock, plant_state ~= nil)
      if not ok then
        res = "recherche : " .. table.concat(miss, ",")
        for _, x in ipairs(miss) do wanted[x] = true end
      end
    end
    ce_memo[item] = res or false
    return res
  end
  local g = f.team.iag
  -- Lot LEVIERS : clés d'ordres de leviers refusées par l'exécutant, en repli (Ca.decide : input.skip).
  local skip = {}
  for _, k in ipairs(sorted_keys(cs.stale or {})) do
    if cs.scan and cs.scan.tick == cs.stale[k] then skip[k] = true else cs.stale[k] = nil end
  end
  for _, k in ipairs(sorted_keys(cs.backoff or {})) do
    if (k:sub(1, 8) == "equiper:" or k:sub(1, 7) == "techno:") and held(cs, k, tick) then skip[k] = true end
  end
  return {
    can_exec = can_exec, skip = skip, successors = successors_for(cs),
    data = D, state = { techs = st.techs or {}, known = st.known }, stock = stock, flows = cs.flows or {},
    machines = cs.scan and cs.scan.machines or {}, drills = cs.scan and cs.scan.drills or {}, labs = labs,
    deposits = deposits, open = open, sinks = cs.bench_sinks or {}, need = need, research = research, drill_for = drill_for,
    limits = { max_ingredients = 2 }, workers = view.workers or 0, idle = Ca.idle_of(g and g.idle_ema or 0),
    can_grow = (view.workers or 0) < (view.workers_wanted or 0), traits = f.traits or {},
    weights = w or {}, threat = view.threatened or false, dt = 1, lag = cs.lag,
  }
end

---------------------------------------------------------------------------------------------------
-- Exécution des ordres
---------------------------------------------------------------------------------------------------
local function note(f, cs, tick, text)
  log(string.format("[FO-CAPI] %s : %s a %.1f min", f.key or "?", text, minutes(f, tick)))
end

--- Débit d'un ordre découpé en modules d'au plus A.FIRST_RATE_MAX objets/min (au plus Capi.MODULES_PER_ORDER).
function Capi.split(rate)
  local cap = A.FIRST_RATE_MAX
  local k = math.max(1, math.min(Capi.MODULES_PER_ORDER, math.ceil((rate or 0) / cap - 1e-9)))
  local each = math.min(cap, (rate or 0) / k)
  local out = {}
  for i = 1, k do out[i] = each end
  return out
end

--- Envoie un ordre de la règle à son exécutant. Rend l'enregistrement de l'ordre ouvert, ou nil et la raison.
local function execute(f, cs, o, view, book, tick, research)
  local rec = { key = o.key, kind = o.kind, item = o.item, resource = o.resource, deposit = o.deposit, entity = o.entity,
    n = o.n, n_left = o.n, rate = o.rate, where = o.where, smelt_n = o.smelt_n, smelt_left = o.smelt_n,
    smelt_recipe = o.smelt_recipe, smelt_entity = o.smelt_entity, value = o.value, T = o.T, opened = tick,
    progress_tick = tick, missing = {}, why = o.why }
  local D = Capi.data()
  if o.kind == "couvrir" or o.kind == "ouvrir" then
    local dm = D.drill_by[o.entity]
    if dm and dm.energy == "electric" then
      local meth = METHOD_OF_ORE[o.resource]
      if not meth then return nil, "aucune fonderie a foreuses pour ce minerai" end
      local dep = cs.deps[o.deposit]
      local per_ore = 1
      local rn = o.smelt_recipe or (dep and nil)
      local r = rn and D.recipes[rn]
      if r then
        local pin, pout = 0, 0
        for _, i in ipairs(r.ingredients) do if i.name == o.resource then pin = i.amount end end
        for _, p in ipairs(r.products) do if p.name == meth.product then pout = p.amount end end
        if pin > 0 then per_ore = pout / pin end
      end
      local rate = (o.rate or 0) * per_ore
      -- Pas de « near » : le plan directeur pose la fonderie au plus près de SON gisement de lots (comme AUTO, fonderies
      -- validées en 0.6.3) ; banc p2 du lot : avec la fonderie posée au centre du gisement, 174 refus « tapis des
      -- foreuses (minerai) » et 124 « (trop loin) ».
      local near = nil
      local ids, why = {}, nil
      for _, part in ipairs(Capi.split(rate)) do
        local g, args = fit_module(meth, part, book, view.stock or {}, Auto.plant_state(f) ~= nil)
        if not g then why = "objets impossibles : " .. table.concat(args or {}, ",") break end
        local id, w2 = Auto.submit(f, { product = meth.product, gen = meth.gen, args = args, feed = meth.feed, rate = part,
          rate_nom = (g.nominal[meth.product] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, near = near, pole = g.pole,
          capi = o.key, why = string.format("CAPI %s %s x%d T=%.2f", o.kind, tostring(o.deposit), o.n or 0, o.T or 0) },
          tick, research)
        if not id then why = "plan directeur : " .. tostring(w2) hold(cs, meth.product, w2, tick) break end
        ids[#ids + 1] = id
        -- portée du plan directeur : le treillis grandit jusqu'au gisement (au plus Build.RADIUS_MAX)
        if f.build and dep then
          local far = math.max(math.abs(dep.cx - f.hq_pos.x), math.abs(dep.cy - f.hq_pos.y))
          Build.grow(f, math.min(Build.RADIUS_MAX, math.ceil(far / Pl.PITCH)))
        end
      end
      if #ids == 0 then return nil, why end
      rec.exec, rec.mod_ids, rec.product = "module", ids, meth.product
      return rec
    end
    return nil, "foreuses a combustion : decideur d'avant (SCALE)"
  elseif o.kind == "fours" then
    return nil, "fours du QG : decideur SCALE (Br.smelters)"
  elseif o.kind == "equiper" then
    -- Lot LEVIERS : machines DÉJÀ posées (relevé de cette minute) du groupe décidé : même machine, même recette ou
    -- ressource, même endroit, mêmes modules déjà posés ; au plus o.n machines, les premières par numéro d'unité.
    local list = o.resource and (cs.scan and cs.scan.drills or {}) or (cs.scan and cs.scan.machines or {})
    local targets = {}
    for _, g in ipairs(list) do
      local same = g.entity == o.entity and g.sig == o.sig
      if same and o.resource then same = g.resource == o.resource and tostring(g.deposit) == tostring(o.deposit) end
      if same and not o.resource then same = g.recipe == o.recipe and tostring(g.where) == tostring(o.where) end
      if same then
        for _, u in ipairs(g.units or {}) do
          if #targets < (o.n or 0) then targets[#targets + 1] = { x = u.x, y = u.y, u = u.u, entity = g.entity } end
        end
      end
    end
    if #targets == 0 then return nil, "aucune machine du groupe au releve (releve perime)" end
    table.sort(targets, function(a, b) return a.u < b.u end)
    rec.exec, rec.module, rec.per, rec.targets, rec.done, rec.inserted = "equiper", o.module, o.per, targets, {}, 0
    rec.n, rec.n_left = #targets, #targets
    rec.missing = { { o.module, #targets * o.per } }
    rec.d_item, rec.d_out, rec.d_in, rec.d_kw, rec.d_fuel, rec.sig = o.d_item, o.d_out, o.d_in, o.d_kw, o.d_fuel, o.sig
    -- sortie annoncée pour les machines réellement ciblées (le plan applique n_left ÷ n de l'ordre décidé)
    if (o.n or 0) > #targets and o.n > 0 then
      local k = #targets / o.n
      rec.d_out, rec.d_kw, rec.d_fuel = (o.d_out or 0) * k, (o.d_kw or 0) * k, (o.d_fuel or 0) * k
      rec.d_in = {}
      for _, e in ipairs(o.d_in or {}) do rec.d_in[#rec.d_in + 1] = { e[1], e[2] * k } end
    end
    rec.announced = { d_out = rec.d_out, item = o.d_item, factor = o.factor }
    return rec
  elseif o.kind == "techno" then
    rec.exec, rec.tech, rec.n, rec.n_left = "techno", o.tech, 1, 1
    return rec
  elseif o.kind == "labos" then
    rec.exec = "labos"
    rec.target = (cs.nlabs or 0) + (o.n or 0)
    return rec
  elseif o.kind == "chaine" or o.kind == "packs" then
    local meth, why = A.method_for(o.item, book)
    if not meth then return nil, tostring(why) end
    local ids, why2 = {}, nil
    for _, part in ipairs(Capi.split(o.rate or 0)) do
      local g, args = fit_module(meth, part, book, view.stock or {}, Auto.plant_state(f) ~= nil)
      if not g then why2 = "objets impossibles : " .. table.concat(args or {}, ",") break end
      local id, w2 = Auto.submit(f, { product = o.item, gen = meth.gen, args = args, feed = meth.feed, rate = part,
        rate_nom = (g.nominal[o.item] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, capi = o.key, pole = g.pole,
        why = string.format("CAPI %s x%d T=%.2f", o.kind, o.n or 0, o.T or 0) }, tick, research)
      if not id then why2 = "plan directeur : " .. tostring(w2) hold(cs, o.item, w2, tick) break end
      ids[#ids + 1] = id
    end
    if #ids == 0 then return nil, why2 end
    rec.exec, rec.mod_ids, rec.product = "module", ids, o.item
    return rec
  end
  return nil, "levier sans executant (" .. tostring(o.kind) .. ")"
end

--- Suivi d'un ordre ouvert : manques, reste à poser, fin. Rend "ouvert", "fini" ou "echec", raison.
local function follow(f, cs, rec, tick)
  if rec.exec == "module" then
    -- plusieurs modules par ordre : fini quand tous sont finis ou refusés (au moins un fini) ; échec si tous refusés
    local missing, n_fini, n_ref, built, total, why = {}, 0, 0, 0, 0, nil
    local blocked = nil
    for _, id in ipairs(rec.mod_ids or { rec.module }) do
      local m = Auto.module(f, id)
      if not m or m.state == "refuse" then
        n_ref = n_ref + 1
        why = m and tostring(m.reason) or "module perdu"
      elseif m.state == "fini" then n_fini = n_fini + 1
      else
        if m.state == "reserve" then for _, it in ipairs(m.missing or {}) do missing[#missing + 1] = it end end
        if m.state == "bloque" then blocked = tostring(m.reason) end
      end
      if m then built, total = built + (m.built or 0), total + (m.total or 0) end
    end
    local n_mod = #(rec.mod_ids or { rec.module })
    rec.missing, rec.blocked = missing, blocked
    if n_fini + n_ref >= n_mod then
      if n_fini > 0 then return "fini" end
      return "echec", "plan directeur : " .. tostring(why)
    end
    if built ~= rec.built then rec.built, rec.progress_tick = built, tick end
    if total > 0 then rec.n_left = math.max(0, math.ceil((rec.n or 0) * (total - built) / total)) end
    return "ouvert"
  elseif rec.exec == "equiper" then
    -- Lot LEVIERS : fini quand chaque machine ciblée a été traitée par un PNJ (module posé, ou refus du moteur écrit).
    local done = {}
    for _, u in ipairs(rec.done or {}) do done[u] = true end
    local left, first = 0, nil
    for _, t in ipairs(rec.targets or {}) do
      if not done[t.u] then
        left = left + 1
        first = first or t
      end
    end
    if #(rec.done or {}) ~= rec.ndone then rec.ndone, rec.progress_tick = #(rec.done or {}), tick end
    rec.n_left = left
    local have = Stock.count(f, rec.module)
    rec.missing = {}
    if left > 0 and have < left * rec.per then rec.missing = { { rec.module, left * rec.per - have } } end
    if left == 0 then
      if (rec.inserted or 0) > 0 then return "fini" end
      return "echec", "aucun module pose (" .. tostring(rec.why_refused) .. ")"
    end
    return "ouvert"
  elseif rec.exec == "techno" then
    -- Lot LEVIERS : fini quand la technologie est faite ; progrès tant que le laboratoire la cherche ou qu'elle attend sa file.
    local st = f.team.ia3
    if (st.techs or {})[rec.tech] then return "fini" end
    if st.lab and st.lab.tech == rec.tech then rec.progress_tick = tick end
    return "ouvert"
  elseif rec.exec == "outpost" then
    if rec.outpost then
      local o = f.outposts[rec.outpost]
      if not o then return "echec", "avant-poste perdu" end
      rec.n_left = math.max(0, (rec.target or 0) - o.drills)
      if o.drills ~= rec.built then rec.built, rec.progress_tick = o.drills, tick end
      if o.drills >= (rec.target or 0) then return "fini" end
      if o.full_place then return "echec", "avant-poste plein (place)" end
      return "ouvert"
    end
    local n = 0
    for _, oid in ipairs(sorted_keys(f.outposts)) do if f.outposts[oid].kind == rec.outpost_kind then n = n + 1 end end
    if n >= (rec.target_count or 0) then return "fini" end
    return "ouvert"
  elseif rec.exec == "smelters" then
    local n = #(f.smelters or {})
    if n ~= rec.built then rec.built, rec.progress_tick = n, tick end
    rec.n_left = math.max(0, (rec.target or 0) - n)
    if n >= (rec.target or 0) then return "fini" end
    return "ouvert"
  elseif rec.exec == "labos" then
    local n = cs.nlabs or 0
    if n ~= rec.built then rec.built, rec.progress_tick = n, tick end
    rec.n_left = math.max(0, (rec.target or 0) - n)
    if n >= (rec.target or 0) then return "fini" end
    return "ouvert"
  end
  return "echec", "executant inconnu"
end

---------------------------------------------------------------------------------------------------
-- Étape 10 : décision
---------------------------------------------------------------------------------------------------
local function decide(f, cs, view, book, tick, research, w)
  local D = Capi.data()
  cs.flows = flows_of(f, cs)
  local input = build_input(f, cs, view, book, tick, D, w)
  Profiler.fstart("capi:decide")
  local res = Ca.decide(input, cs.st)
  Profiler.fstop("capi:decide")
  -- Lot LEVIERS : les modules rentables mais pas encore fabricables sont DEMANDÉS à la recherche (comme une chaîne refusée).
  cs.wanted_set = cs.wanted_set or {}
  for _, nm in ipairs(res.want or {}) do cs.wanted_set[nm] = true end
  cs.wanted = sorted_keys(cs.wanted_set or {})
  cs.wanted_set = nil
  -- Lot LEVIERS : « repli : pourquoi » (ressources bloquées, leviers retenus ou raison de n'en avoir aucun). Écrit quand la
  -- SITUATION change (ressources bloquées, leviers), jamais à l'horloge.
  if res.repli then
    local rs, ls = {}, {}
    for _, b in ipairs(res.repli.blocked) do rs[#rs + 1] = b.resource end
    for _, l in ipairs(res.repli.levers) do ls[#ls + 1] = l.key end
    local sig = table.concat(rs, ",") .. "|" .. table.concat(ls, ",") .. "|" .. tostring(res.repli.none)
    if cs.repli_sig ~= sig then
      cs.repli_sig = sig
      log(string.format("[FO-CERVEAU] %s : %s a %.1f min", f.key or "?", res.repli.text, minutes(f, tick)))
      for _, l in ipairs(res.repli.levers) do
        log(string.format("[FO-CERVEAU] %s : repli : levier %s : %s", f.key or "?", l.key, tostring(l.why)))
      end
      cs.repli_refus = cs.repli_refus or {}
      for _, r in ipairs(res.repli.refus) do
        -- chaque refus n'est écrit qu'une fois par raison (le même refus se répète à chaque changement de situation)
        local sig2 = r.key .. "|" .. tostring(r.why)
        if not cs.repli_refus[sig2] then
          cs.repli_refus[sig2] = true
          log(string.format("[FO-CERVEAU] %s : repli : levier refuse %s : %s", f.key or "?", r.key, tostring(r.why)))
        end
      end
    end
    cs.repli_text = res.repli.text
  else
    cs.repli_sig, cs.repli_text = nil, nil
  end
  -- Lot LEVIERS : recherches retenues parce qu'elles débloquent une meilleure machine (écrit quand l'ensemble change).
  do
    local names = {}
    for _, u in ipairs(res.unlocks or {}) do names[#names + 1] = u.tech end
    local sig3 = table.concat(names, ",")
    if sig3 ~= (cs.unlock_sig or "") then
      cs.unlock_sig = sig3
      for _, u in ipairs(res.unlocks or {}) do
        log(string.format("[FO-CERVEAU] %s : %s a %.1f min", f.key or "?", u.why, minutes(f, tick)))
      end
    end
    cs.unlocks = names
    -- technologies de la chaîne (la technologie et ses prérequis non faits) : valeur d'un objet voulu SANS le quart des
    -- machines « pour plus tard » (Gen.LATER_DIV) : la machine supérieure est posée sur place par le lot AMELIORER
    cs.unlock_techs = {}
    for _, u in ipairs(res.unlocks or {}) do
      for _, t in ipairs(u.chain or {}) do cs.unlock_techs[t] = u.tech end
    end
  end
  -- Les objets que ses exécutants attendent sont DONNÉS à la recherche (étape 1 du 27/10 au soir : sans cela, scarlet cherchait
  -- grenades et armure pendant 30 min pendant que les chaînes de la capitalisation étaient refusées « recherche :
  -- fast-inserter, medium-electric-pole » ; le critère « automation à 2 min comme au témoin » interdisait toute électrification).
  -- La garde K1 ne retient plus que les recherches voulues LOINTAINES (Gen.k1, near).
  Auto.want(f, cs.wanted)
  cs.decisions = cs.decisions + 1
  cs.res = { delta = res.delta, alpha = res.alpha, s = res.s, K = res.K, Y = res.Y, budget = res.budget, spent = res.spent,
    labs_target = res.labs_target, u_star = res.u_star }
  local sent, refused = {}, {}
  for _, o in ipairs(res.orders) do
    local rec, why = execute(f, cs, o, view, book, tick, research)
    if rec then
      cs.open[#cs.open + 1] = rec
      cs.orders = cs.orders + 1
      sent[#sent + 1] = string.format("%s:%s(%s x%d)", o.kind, tostring(o.item or o.resource), tostring(rec.exec), o.n or 0)
      cs.stats[o.kind] = (cs.stats[o.kind] or 0) + 1
    else
      refused[#refused + 1] = o.key .. " (" .. tostring(why) .. ")"
      cs.refused[o.key] = tick
      if o.kind == "equiper" or o.kind == "techno" then hold(cs, o.key, why, tick) end -- lot LEVIERS : pas redemandé tout de suite
      -- l'ordre n'a rien coûté : l'épargne débitée par la règle lui est rendue
      cs.st.bank = (cs.st.bank or 0) + (o.cost_m or 0)
    end
  end
  -- couverture relue et dépôts suivis (journal : critères (1) et (3))
  local deps = {}
  for _, id in ipairs(sorted_keys(cs.deps)) do
    local d = cs.deps[id]
    deps[#deps + 1] = string.format("%s:%d/%d%s", id, d.covered or 0, d.tiles, d.danger and "!" or "")
  end
  log(string.format("[FO-CAPI] %s minute %d | tick %d | %s | envoyes [%s] | executant refuse [%s] | depots {%s} | foreuse_par_ressource {%s} | recherche_voulue [%s]",
    f.key or "?", math.floor(minutes(f, tick) + 0.5), tick, Ca.text(res), table.concat(sent, ", "), table.concat(refused, ", "),
    table.concat(deps, " "), (function()
      local o = {}
      for _, k in ipairs(sorted_keys(input.drill_for)) do if input.drill_for[k] ~= "" then o[#o + 1] = k .. "=" .. input.drill_for[k] end end
      return table.concat(o, " ")
    end)(), table.concat(cs.wanted or {}, " ")))
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
--- Appelé par le cerveau (Ia3.plan) avant la pensée pure. Rend ctx.capi = { res, open } (buts de fond), ou nil.
function Capi.think(f, view, book, tick, research, w)
  if not Capi.on(f) then return nil end
  local cs = state_of(f)
  Profiler.start("capi:think")
  local phase = cs.n % Capi.CYCLE
  cs.n = cs.n + 1
  if phase == 0 then
    Profiler.fstart("capi:scan")
    scan(f, cs, tick)
    Profiler.fstop("capi:scan")
  elseif phase == 1 then
    Profiler.fstart("capi:coverage")
    coverage(f, cs)
    Profiler.fstop("capi:coverage")
  elseif phase >= 2 and phase <= 9 then
    census_one(f, cs, tick)
  elseif phase == 10 and cs.scan then
    decide(f, cs, view, book, tick, research, w)
  end
  -- Suivi des ordres ouverts (chaque pensée : lectures sans appel coûteux du moteur).
  local keep = {}
  for _, rec in ipairs(cs.open) do
    local state, why = follow(f, cs, rec, tick)
    if state == "ouvert" and tick - (rec.progress_tick or rec.opened) > Capi.ORDER_TTL then
      state, why = "echec", "aucun progres en " .. math.floor(Capi.ORDER_TTL / 3600) .. " min"
      if rec.exec == "module" then
        for _, id in ipairs(rec.mod_ids or { rec.module }) do Build.cancel(f, id, "CAPI : " .. why) end
      end
    end
    if state == "ouvert" then keep[#keep + 1] = rec
    else
      if state == "fini" then
        cs.lag_hist = cs.lag_hist or {}
        cs.lag_hist[#cs.lag_hist + 1] = (tick - rec.opened) / 3600
        while #cs.lag_hist > 5 do table.remove(cs.lag_hist, 1) end
        local s = 0
        for _, x in ipairs(cs.lag_hist) do s = s + x end
        cs.lag = s / #cs.lag_hist
      end
      if state == "echec" and rec.exec == "module" and rec.product then hold(cs, rec.product, why, tick) end
      if state == "echec" and (rec.exec == "equiper" or rec.exec == "techno") then hold(cs, rec.key, why, tick) end
      -- Lot LEVIERS : le relevé des machines (une fois par minute) ne montre pas encore les modules qu'un PNJ vient de poser :
      -- cette clé n'est pas redécidée avant le relevé suivant (banc leviers-modules : le même ordre, réémis sur l'ancien relevé).
      if rec.exec == "equiper" and cs.scan then
        cs.stale = cs.stale or {}
        cs.stale[rec.key] = cs.scan.tick
      end
      cs.done[#cs.done + 1] = { key = rec.key, kind = rec.kind, exec = rec.exec, n = rec.n, state = state, why = why,
        opened = rec.opened, closed = tick }
      while #cs.done > Capi.LOG_ORDERS do table.remove(cs.done, 1) end
      note(f, cs, tick, string.format("ordre %s %s (%s%s) apres %.1f min", rec.key, state == "fini" and "FINI" or "ECHOUE",
        tostring(rec.exec), why and (", " .. why) or "", (tick - rec.opened) / 3600))
    end
  end
  cs.open = keep
  -- Laboratoires visés : ceux du QG plus le reste des ordres ouverts.
  local labs_want = cs.nlabs or 0
  for _, rec in ipairs(cs.open) do
    if rec.exec == "labos" then labs_want = math.max(labs_want, rec.target or 0) end
  end
  cs.labs_want = labs_want
  -- Buts de fond du cerveau : un par ordre ouvert (Ca.goals), avec ce qui manque à l'exécutant.
  local open = {}
  for _, rec in ipairs(cs.open) do
    open[#open + 1] = { key = rec.key, kind = rec.kind, item = rec.item, value = rec.value, exec = rec.exec,
      outpost_kind = rec.outpost_kind, n_left = rec.n_left, missing = rec.missing, blocked = rec.blocked, tech = rec.tech }
  end
  -- Lot LEVIERS : tâches « equiper » (une par ordre : le premier lot de machines non traitées, dès que les modules sont
  -- au coffre) ; renouvelées à chaque pensée, comme le plan.
  local tasks = {}
  for _, rec in ipairs(cs.open) do
    if rec.exec == "equiper" and (rec.n_left or 0) > 0 then
      local done = {}
      for _, u in ipairs(rec.done or {}) do done[u] = true end
      local nb = math.ceil(#rec.targets / Equip.BATCH)
      for b = 1, nb do
        local batch = {}
        for i = (b - 1) * Equip.BATCH + 1, math.min(#rec.targets, b * Equip.BATCH) do
          if not done[rec.targets[i].u] then batch[#batch + 1] = rec.targets[i] end
        end
        if #batch > 0 then
          if Stock.count(f, rec.module) >= #batch * rec.per then
            tasks[#tasks + 1] = { key = "eq:" .. rec.key .. ":" .. b, kind = Equip.KIND, prio = Equip.PRIO, domain = "production",
              work = 20 + 10 * #batch, items = { { rec.module, #batch * rec.per } }, targets = batch, module = rec.module,
              per = rec.per, rec_key = rec.key }
          end
          break -- un lot à la fois par ordre : les modules du suivant attendent le coffre
        end
      end
    end
  end
  Profiler.stop("capi:think")
  return { res = cs.res, open = open, tasks = tasks }
end

--- Lot LEVIERS : recherches à effet que la capitalisation a CHOISIES et qui restent ouvertes : { [technologie] = valeur }.
--- Lue par le choix de la technologie (script/ai3/general.lua, ctx.levers de Gen.choose). Nil : aucune.
function Capi.techs_wanted(f)
  if not (f and f.team and f.team.capi) or not Capi.on(f) then return nil end
  local out = nil
  for _, rec in ipairs(f.team.capi.open) do
    if rec.exec == "techno" and rec.tech then
      out = out or {}
      out[rec.tech] = rec.value or Ca.V_MIN
    end
  end
  for _, t in ipairs(sorted_keys(f.team.capi.unlock_techs or {})) do
    out = out or {}
    if out[t] == nil then out[t] = Ca.V_MIN end
  end
  return out
end

--- Laboratoires visés par la capitalisation (nil : capitalisation éteinte pour cette faction).
function Capi.labs_want(f)
  if not Capi.on(f) then return nil end
  local cs = f.team.capi
  return cs and cs.labs_want or nil
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  if key == "player" then return State.faction("player") end -- lot LEVIERS : votre équipe aussi (bancs)
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

remote.add_interface("fo-capi", {
  --- Lot LEVIERS (BANC SEULEMENT) : déclare interdits tous les gisements de la faction (même champ que « hors du plan
  --- directeur ») ; la détection du danger elle-même n'est pas touchée. Rend vrai si la faction existe.
  --- Lot LEVIERS (BANC SEULEMENT) : un client externe de la faction consomme `rate` objets/min de `item` (puits mesuré de la
  --- règle, élastique en dehors du banc) ; rate 0 le retire.
  bench_sink = function(key, item, rate)
    local f = team_of(key)
    if not (f and f.team) then return false end
    local cs = state_of(f)
    cs.bench_sinks = (rate and rate > 0) and { { item = item, rate = rate, want = rate } } or nil
    return true
  end,
  block_sites = function(key, on)
    local f = team_of(key)
    if not (f and f.team) then return false end
    state_of(f).block_all = on and true or nil
    return true
  end,
  status = function(key)
    local f = team_of(key)
    local cs = f and f.team and f.team.capi
    if not cs then return nil end
    local out = { on = Capi.on(f), decisions = cs.decisions, orders = cs.orders, open = {}, done = {}, deps = {},
      res = cs.res, labs_want = cs.labs_want, stats = {}, lag = cs.lag, wanted = cs.wanted, repli = cs.repli_text, unlocks = cs.unlocks }
    for _, rec in ipairs(cs.open) do
      out.open[#out.open + 1] = { key = rec.key, kind = rec.kind, exec = rec.exec, n = rec.n, n_left = rec.n_left,
        mod_ids = rec.mod_ids, opened = rec.opened, module = rec.module, per = rec.per, inserted = rec.inserted,
        refused = rec.refused, why_refused = rec.why_refused, tech = rec.tech, announced = rec.announced }
    end
    for _, d in ipairs(cs.done) do out.done[#out.done + 1] = d end
    -- lot LEVIERS : machines relevées (groupes) pour les bancs
    out.machines = {}
    for _, m in ipairs(cs.scan and cs.scan.machines or {}) do
      out.machines[#out.machines + 1] = { entity = m.entity, recipe = m.recipe, where = m.where, n = m.n, sig = m.sig }
    end
    for _, id in ipairs(sorted_keys(cs.deps)) do
      local d = cs.deps[id]
      out.deps[#out.deps + 1] = { id = id, resource = d.resource, tiles = d.tiles, amount = d.amount, covered = d.covered,
        x0 = d.x0, y0 = d.y0, x1 = d.x1, y1 = d.y1, cx = d.cx, cy = d.cy, danger = d.danger, cut = d.cut }
    end
    for _, k in ipairs(sorted_keys(cs.stats)) do out.stats[k] = cs.stats[k] end
    return out
  end,
})

return Capi
