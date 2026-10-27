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
  Exécutants (un seul décideur par levier : la capitalisation ; table du document §5) :
    couvrir/ouvrir, foreuse électrique  fonderie du plan directeur (gabarit à foreuses et tapis d'AUTO, Auto.submit) au
                                        débit des foreuses commandées, posée près du gisement (spec.near) : ses fours
                                        sont dimensionnés par le gabarit sur le minerai des foreuses (critère (2)) ;
    couvrir, foreuse des avant-postes   plafond de foreuses de l'avant-poste du gisement relevé (o.cap_drills), puis
                                        l'extension du cerveau (P.EMIT.outpost) ;
    ouvrir, foreuse des avant-postes    construction d'un avant-poste (P.EMIT.outpost : site prospecté) ;
    fours (au QG)                       rangées de fours du QG (P.EMIT.smelters) ;
    chaine, packs                       rangée d'assembleurs du plan directeur (A.method_for, A.sized, Auto.submit) ;
    labos                               laboratoires du QG (research_step : nombre visé, Capi.labs_want) ;
    energie                             la centrale est demandée par AUTO avant le premier module électrique.
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
local Sites = require("script.faction.sites")
local Profiler = require("script.core.profiler")
local General = require("script.ai3.general")
local Auto = require("script.ai3.automatisation")
local Build = require("script.team.build")

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
Capi.MODULE_DEFAULT_KM = 8   -- dixièmes : taille d'un pas de lot pour la portée du plan directeur (Build.RADIUS_MAX)

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
  if not (Capi.ENABLED and f and not f.is_player and f.team and f.team.ia3 and f.hq and f.hq.valid) then return false end
  local war = State.war()
  if war and war.capi_off then return false end
  local s = settings.global[Capi.SETTING]
  if not (s and s.value == true) then return false end
  return Auto.on() and true or false
end

-- Sous la capitalisation, A.decide ne demande plus rien (il mesure encore) : un seul décideur.
Auto.decide_off = function(f) return Capi.on(f) end

---------------------------------------------------------------------------------------------------
-- Relevé des prototypes (cache LOCAL : prototypes seulement, identiques chez tous les pairs)
---------------------------------------------------------------------------------------------------
local data_cache = {}
local elec_drill = nil

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
local function module_ok(meth, book, stock)
  local g = A.sized(meth, 60)
  if not g then return false, {} end
  local _, items = A.cost(meth, g, { has_plant = true })
  local miss = {}
  for _, name in ipairs(sorted_keys(items)) do
    if not (book:handcraftable(name) or (stock[name] or 0) > 0) then miss[#miss + 1] = name end
  end
  return #miss == 0, miss
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
        local k = e.name .. "|" .. res .. "|" .. did
        if not dk[k] then dk[k] = { entity = e.name, resource = res, n = 0, deposit = did } drills[#drills + 1] = dk[k] end
        dk[k].n = dk[k].n + 1
        drill_pos[#drill_pos + 1] = { x = p.x, y = p.y, r = get(e.prototype, "mining_drill_radius") or 1, res = res, dep = did }
      end
    elseif role == "labo" then
      if not lk[e.name] then lk[e.name] = { entity = e.name, n = 0 } labs[#labs + 1] = lk[e.name] end
      lk[e.name].n = lk[e.name].n + 1
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
        local k = e.name .. "|" .. r.name .. "|" .. where
        if not mk[k] then mk[k] = { entity = e.name, recipe = r.name, n = 0, where = where } machines[#machines + 1] = mk[k] end
        mk[k].n = mk[k].n + 1
      end
    end
  end
  cs.scan = { tick = tick, machines = machines, drills = drills, labs = labs, drill_pos = drill_pos }
  -- Graines de gisements : avant-postes, foreuses, gisements connus (carte d'IA3-f), sites prospectés, lots de gisement
  -- du plan directeur. Une graine déjà dans un gisement recensé n'est pas relue (sauf à l'échéance du recensement).
  local seeds = {}
  local function seed(res, x, y)
    if not (res and x and y) then return end
    if dist({ x = x, y = y }, hq) > Capi.SCAN_R + 64 and not KIND_OF_RES[res] then return end
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
    if not d or tick - (d.tick or 0) >= Capi.CENSUS_EVERY then
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
  for _, t in ipairs((g and g.next) or {}) do
    if t ~= lab.tech and not (st.techs or {})[t] and c.techs[t] then add(t, c.techs[t].count) end
  end
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
  -- laboratoires affamés : des laboratoires, une technologie, et aucune unité payée cette minute (‰)
  local nlabs = 0
  for _, e in ipairs(st.labs or {}) do if e.valid then nlabs = nlabs + 1 end end
  local starved = (nlabs > 0 and lab.tech and rate <= 0) and 1000 or 0
  return { queue = q, rate = rate, starved = starved }, nlabs
end

local function build_input(f, cs, view, book, tick, D, w)
  local st = f.team.ia3
  local force = game.forces[f.force]
  D.bonus.mining = (force and force.mining_drill_productivity_bonus) or 0
  D.bonus.lab = (force and force.laboratory_speed_modifier) or 0
  local stock = view.stock or {}
  -- foreuse imposée par ressource : électrique (fonderie du plan directeur) si le gabarit se pose aujourd'hui, sinon
  -- celle des avant-postes ; aucune autre (aucun exécutant).
  local drill_for, elec = {}, {}
  local plant_state, plant_why = Auto.plant_state(f)
  local wanted = {}
  for _, res in ipairs(D.res_list) do
    local meth = METHOD_OF_ORE[res]
    local ok, miss = false, {}
    if meth and elec_drill and plant_state ~= "refuse" then ok, miss = module_ok(meth, book, stock) end
    if ok then drill_for[res], elec[res] = elec_drill, true
    elseif KIND_OF_RES[res] then drill_for[res] = T.DRILL
    else drill_for[res] = "" end
    for _, m in ipairs(miss) do wanted[m] = true end
  end
  cs.wanted = sorted_keys(wanted)
  -- gisements : recensés, ouverts s'ils portent une foreuse de la force ou un avant-poste ; portée du plan directeur
  local reach = (Build.RADIUS_MAX + 0.5) * Pl.PITCH
  local open_dep = {}
  for _, dr in ipairs(cs.scan and cs.scan.drills or {}) do if dr.deposit ~= "?" then open_dep[dr.deposit] = true end end
  local deposits = {}
  for _, id in ipairs(sorted_keys(cs.deps)) do
    local d = cs.deps[id]
    local kind = KIND_OF_RES[d.resource]
    local blocked = nil
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
    elseif kind then
      local spec = T.outposts[kind]
      if T.smelter_inputs[spec.product] and T.smelter_inputs[spec.product][1] == d.resource then
        smelter = spec.sink
        for _, rn in ipairs(D.producers[spec.product] or {}) do
          local r = D.recipes[rn]
          for _, i in ipairs(r.ingredients) do if i.name == d.resource and not smelt then smelt = rn end end
        end
      end
      if open_dep[id] then
        local full_place = false
        for _, oid in ipairs(sorted_keys(f.outposts)) do
          local o = f.outposts[oid]
          if o.kind == kind and o.full_place and dep_at(cs, d.resource, o.pos.x, o.pos.y) == d then full_place = true end
        end
        if full_place then blocked = "avant-poste plein (place)" end
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
      work_left = o.work_left, value = o.value }
  end
  local research, nlabs = research_of(f, cs)
  cs.nlabs = nlabs
  local labs = {}
  for _, l in ipairs(cs.scan and cs.scan.labs or {}) do labs[#labs + 1] = { entity = l.entity, n = l.n } end
  -- besoin des buts SANS les buts capi ni la recherche : le besoin de matière de la dernière pensée (manque + usage)
  local need = {}
  for _, k in ipairs(sorted_keys(st.need)) do need[k] = st.need[k] end
  local g = f.team.iag
  return {
    data = D, state = { techs = st.techs or {}, known = st.known }, stock = stock, flows = cs.flows or {},
    machines = cs.scan and cs.scan.machines or {}, drills = cs.scan and cs.scan.drills or {}, labs = labs,
    deposits = deposits, open = open, sinks = {}, need = need, research = research, drill_for = drill_for,
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

local function outposts_on(f, cs, dep)
  local out = {}
  if not dep then return out end
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local spec = T.outposts[o.kind]
    if spec and spec.resource == dep.resource and dep_at(cs, dep.resource, o.pos.x, o.pos.y) == dep then out[#out + 1] = o end
  end
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
      local g, args = A.sized(meth, rate)
      if not g then return nil, "gabarit : " .. tostring(args) end
      local near = dep and { x = math.floor(dep.cx), y = math.floor(dep.cy) } or nil
      -- portée du plan directeur : le treillis grandit jusqu'au gisement (au plus Build.RADIUS_MAX)
      if f.build and dep then
        local far = math.max(math.abs(dep.cx - f.hq_pos.x), math.abs(dep.cy - f.hq_pos.y))
        Build.grow(f, math.min(Build.RADIUS_MAX, math.ceil(far / Pl.PITCH)))
      end
      local id, why = Auto.submit(f, { product = meth.product, gen = meth.gen, args = args, feed = meth.feed, rate = rate,
        rate_nom = (g.nominal[meth.product] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, near = near,
        capi = o.key, why = string.format("CAPI %s %s x%d T=%.2f", o.kind, tostring(o.deposit), o.n or 0, o.T or 0) },
        tick, research)
      if not id then return nil, "plan directeur : " .. tostring(why) end
      if f.build and dep then
        local far = math.max(math.abs(dep.cx - f.hq_pos.x), math.abs(dep.cy - f.hq_pos.y))
        Build.grow(f, math.min(Build.RADIUS_MAX, math.ceil(far / Pl.PITCH)))
      end
      rec.exec, rec.module = "module", id
      return rec
    end
    -- foreuses des avant-postes
    local kind = KIND_OF_RES[o.resource]
    if not kind then return nil, "aucun executant pour cette ressource" end
    rec.exec, rec.outpost_kind = "outpost", kind
    if o.kind == "couvrir" then
      local list = outposts_on(f, cs, cs.deps[o.deposit])
      if #list == 0 then return nil, "aucun avant-poste sur ce gisement" end
      -- le plus petit avant-poste du gisement reçoit les foreuses commandées (plafond relevé)
      table.sort(list, function(a, b) if a.drills ~= b.drills then return a.drills < b.drills end return a.id < b.id end)
      local tgt = list[1]
      tgt.cap_drills = math.max(tgt.cap_drills or tgt.drills, tgt.drills) + (o.n or 0)
      if not tgt.full_place then tgt.full = false end
      rec.outpost, rec.target = tgt.id, tgt.cap_drills
    else
      rec.target_count = 0
      for _, oid in ipairs(sorted_keys(f.outposts)) do if f.outposts[oid].kind == kind then rec.target_count = rec.target_count + 1 end end
      rec.target_count = rec.target_count + 1
    end
    return rec
  elseif o.kind == "fours" then
    if o.where ~= Ca.HQ then return nil, "fours hors du QG : aucun executant" end
    rec.exec = "smelters"
    rec.target = #(f.smelters or {}) + (o.n or 0)
    return rec
  elseif o.kind == "labos" then
    rec.exec = "labos"
    rec.target = (cs.nlabs or 0) + (o.n or 0)
    return rec
  elseif o.kind == "chaine" or o.kind == "packs" then
    local meth, why = A.method_for(o.item, book)
    if not meth then return nil, tostring(why) end
    local g, args = A.sized(meth, o.rate or 0)
    if not g then return nil, "gabarit : " .. tostring(args) end
    local id, why2 = Auto.submit(f, { product = o.item, gen = meth.gen, args = args, feed = meth.feed, rate = o.rate,
      rate_nom = (g.nominal[o.item] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, capi = o.key,
      why = string.format("CAPI %s x%d T=%.2f", o.kind, o.n or 0, o.T or 0) }, tick, research)
    if not id then return nil, "plan directeur : " .. tostring(why2) end
    rec.exec, rec.module = "module", id
    return rec
  end
  return nil, "levier sans executant (" .. tostring(o.kind) .. ")"
end

--- Suivi d'un ordre ouvert : manques, reste à poser, fin. Rend "ouvert", "fini" ou "echec", raison.
local function follow(f, cs, rec, tick)
  if rec.exec == "module" then
    local m = Auto.module(f, rec.module)
    if not m then return "echec", "module perdu" end
    rec.missing = (m.state == "reserve" and m.missing) or {}
    rec.blocked = (m.state == "bloque") and tostring(m.reason) or nil
    if m.state == "fini" then return "fini" end
    if m.state == "refuse" then return "echec", "plan directeur : " .. tostring(m.reason) end
    local built = m.built or 0
    if built ~= rec.built then rec.built, rec.progress_tick = built, tick end
    if m.total and m.total > 0 then rec.n_left = math.max(0, math.ceil((rec.n or 0) * (m.total - built) / m.total)) end
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
    end
  end
  -- couverture relue et dépôts suivis (journal : critères (1) et (3))
  local deps = {}
  for _, id in ipairs(sorted_keys(cs.deps)) do
    local d = cs.deps[id]
    deps[#deps + 1] = string.format("%s:%d/%d%s", id, d.covered or 0, d.tiles, d.danger and "!" or "")
  end
  log(string.format("[FO-CAPI] %s minute %d | %s | envoyes [%s] | executant refuse [%s] | depots {%s} | foreuse_par_ressource {%s} | recherche_voulue [%s]",
    f.key or "?", math.floor(minutes(f, tick) + 0.5), Ca.text(res), table.concat(sent, ", "), table.concat(refused, ", "),
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
      if rec.exec == "module" then Build.cancel(f, rec.module, "CAPI : " .. why) end
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
      if rec.exec == "outpost" and rec.outpost and f.outposts[rec.outpost] and state ~= "fini" then
        -- échec : le plafond revient à ce qui est posé
        local o = f.outposts[rec.outpost]
        o.cap_drills = o.drills
      end
      cs.done[#cs.done + 1] = { key = rec.key, kind = rec.kind, exec = rec.exec, n = rec.n, state = state, why = why,
        opened = rec.opened, closed = tick }
      while #cs.done > Capi.LOG_ORDERS do table.remove(cs.done, 1) end
      note(f, cs, tick, string.format("ordre %s %s (%s%s) apres %.1f min", rec.key, state == "fini" and "FINI" or "ECHOUE",
        tostring(rec.exec), why and (", " .. why) or "", (tick - rec.opened) / 3600))
    end
  end
  cs.open = keep
  -- Avant-postes sous la capitalisation : aucun ne grandit au-delà de ce que la règle a commandé.
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    if o.cap_drills == nil then o.cap_drills = o.drills end
  end
  -- Laboratoires visés : ceux du QG plus le reste des ordres ouverts.
  local labs_want = cs.nlabs or 0
  local smelt_want = nil
  for _, rec in ipairs(cs.open) do
    if rec.exec == "labos" then labs_want = math.max(labs_want, rec.target or 0) end
    if rec.exec == "smelters" then smelt_want = math.max(smelt_want or 0, rec.target or 0) end
  end
  cs.labs_want = labs_want
  cs.smelt_want = smelt_want
  -- Buts de fond du cerveau : un par ordre ouvert (Ca.goals), avec ce qui manque à l'exécutant.
  local open = {}
  for _, rec in ipairs(cs.open) do
    open[#open + 1] = { key = rec.key, kind = rec.kind, item = rec.item, value = rec.value, exec = rec.exec,
      outpost_kind = rec.outpost_kind, n_left = rec.n_left, missing = rec.missing, blocked = rec.blocked }
  end
  Profiler.stop("capi:think")
  return { res = cs.res, open = open, smelt_want = cs.smelt_want }
end

--- Laboratoires visés par la capitalisation (nil : capitalisation éteinte pour cette faction).
function Capi.labs_want(f)
  if not Capi.on(f) then return nil end
  local cs = f.team.capi
  return cs and cs.labs_want or nil
end

--- Fours du QG visés par la capitalisation (nil : éteinte, ou aucun ordre de fours ouvert : le nombre posé).
function Capi.smelt_want(f)
  if not Capi.on(f) then return nil end
  local cs = f.team.capi
  return (cs and cs.smelt_want) or #(f.smelters or {})
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

remote.add_interface("fo-capi", {
  status = function(key)
    local f = team_of(key)
    local cs = f and f.team and f.team.capi
    if not cs then return nil end
    local out = { on = Capi.on(f), decisions = cs.decisions, orders = cs.orders, open = {}, done = {}, deps = {},
      res = cs.res, labs_want = cs.labs_want, smelt_want = cs.smelt_want, stats = {}, lag = cs.lag, wanted = cs.wanted }
    for _, rec in ipairs(cs.open) do
      out.open[#out.open + 1] = { key = rec.key, kind = rec.kind, exec = rec.exec, n = rec.n, n_left = rec.n_left,
        module = rec.module, opened = rec.opened }
    end
    for _, d in ipairs(cs.done) do out.done[#out.done + 1] = d end
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
