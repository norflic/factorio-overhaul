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
Capi.MODULES_PER_ORDER = 3   -- modules du plan directeur au plus par ordre (chacun au plus A.FIRST_RATE_MAX objets/min :
                             -- un gabarit plus grand ne tient pas dans un lot, moteur réel p1, « pas de lot », « trop grand »)

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
local function module_ok(meth, book, stock, has_plant, rate)
  local g = A.sized(meth, math.min(rate or 60, A.FIRST_RATE_MAX))
  if not g then return false, {} end
  local _, items = A.cost(meth, g, { has_plant = has_plant })
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
      local sx, sy = 0, 0
      for _, dp in ipairs(by_dep[id]) do
        local r = dp.r
        sx, sy = sx + dp.x, sy + dp.y
        for x = math.floor(dp.x - r + 0.01), math.floor(dp.x + r - 0.01) do
          for y = math.floor(dp.y - r + 0.01), math.floor(dp.y + r - 0.01) do
            local k = tkey(x, y)
            if idx[k] and not seen[k] then seen[k] = true n = n + 1 end
          end
        end
      end
      cs.cov[id] = n
      d.covered = n
      -- tuile de minerai NON couverte la plus proche du centre des foreuses : là où l'exécutant des avant-postes agrandit
      -- (Outposts.extend, o.ext_center) ; ordre fixe (distance, x, y)
      local cx, cy = sx / #by_dep[id], sy / #by_dep[id]
      local best, bd = nil, nil
      for _, e in ipairs(surface.find_entities_filtered({ area = { { d.x0, d.y0 }, { d.x1, d.y1 } }, name = d.resource })) do
        local x, y = math.floor(e.position.x), math.floor(e.position.y)
        if not seen[tkey(x, y)] then
          local dd = (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2
          if bd == nil or dd < bd or (dd == bd and (x < best[1] or (x == best[1] and y < best[2]))) then best, bd = { x, y }, dd end
        end
      end
      d.free_x, d.free_y = best and best[1] or nil, best and best[2] or nil
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
  -- laboratoires affamés : des laboratoires, une technologie en cours, et un de ses packs absent du coffre du QG (‰)
  local nlabs = 0
  for _, e in ipairs(st.labs or {}) do if e.valid then nlabs = nlabs + 1 end end
  local starved = 0
  local spec = lab.tech and c.techs[lab.tech]
  if nlabs > 0 and spec and f.hq and f.hq.valid then
    for _, ing in ipairs(spec.ingredients or {}) do
      if f.hq.get_item_count(ing[1]) < (ing[2] or 1) then starved = 1000 end
    end
  end
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
    if meth and elec_drill and plant_state ~= "refuse" then ok, miss = module_ok(meth, book, stock, plant_state ~= nil) end
    if ok then drill_for[res], elec[res] = elec_drill, true
    elseif KIND_OF_RES[res] then drill_for[res] = T.DRILL
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
  -- L'exécutant des chaînes (rangées du plan directeur) sait-il les poser aujourd'hui ? (mémo de la décision)
  local ce_memo = {}
  local function can_exec(kind, item)
    if kind == "fours" then return nil end
    local m = ce_memo[item]
    if m ~= nil then return m or nil end
    local meth, why = A.method_for(item, book)
    local res = nil
    if not meth then res = tostring(why)
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
  return {
    can_exec = can_exec,
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
      local near = dep and { x = math.floor(dep.cx), y = math.floor(dep.cy) } or nil
      local ids, why = {}, nil
      for _, part in ipairs(Capi.split(rate)) do
        local g, args = A.sized(meth, part)
        if not g then why = "gabarit : " .. tostring(args) break end
        local id, w2 = Auto.submit(f, { product = meth.product, gen = meth.gen, args = args, feed = meth.feed, rate = part,
          rate_nom = (g.nominal[meth.product] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, near = near,
          capi = o.key, why = string.format("CAPI %s %s x%d T=%.2f", o.kind, tostring(o.deposit), o.n or 0, o.T or 0) },
          tick, research)
        if not id then why = "plan directeur : " .. tostring(w2) break end
        ids[#ids + 1] = id
        -- portée du plan directeur : le treillis grandit jusqu'au gisement (au plus Build.RADIUS_MAX)
        if f.build and dep then
          local far = math.max(math.abs(dep.cx - f.hq_pos.x), math.abs(dep.cy - f.hq_pos.y))
          Build.grow(f, math.min(Build.RADIUS_MAX, math.ceil(far / Pl.PITCH)))
        end
      end
      if #ids == 0 then return nil, why end
      rec.exec, rec.mod_ids = "module", ids
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
      -- l'extension se fait là où le gisement n'est pas encore couvert (relevé de l'étape 1), sans compter les tuiles
      -- déjà prises (Outposts.extend, mode capitalisation) ; un « plein » d'avant est revu une fois à ce nouveau centre
      local dep = cs.deps[o.deposit]
      if dep and dep.free_x then
        if not (tgt.ext_center and tgt.ext_center.x == dep.free_x + 0.5 and tgt.ext_center.y == dep.free_y + 0.5) then
          tgt.full_place = nil
        end
        tgt.ext_center = { x = dep.free_x + 0.5, y = dep.free_y + 0.5 }
      end
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
    local ids, why2 = {}, nil
    for _, part in ipairs(Capi.split(o.rate or 0)) do
      local g, args = A.sized(meth, part)
      if not g then why2 = "gabarit : " .. tostring(args) break end
      local id, w2 = Auto.submit(f, { product = o.item, gen = meth.gen, args = args, feed = meth.feed, rate = part,
        rate_nom = (g.nominal[o.item] or 0) * 60, electric = (g.power_kw or 0) > 0, gain = 1, capi = o.key,
        why = string.format("CAPI %s x%d T=%.2f", o.kind, o.n or 0, o.T or 0) }, tick, research)
      if not id then why2 = "plan directeur : " .. tostring(w2) break end
      ids[#ids + 1] = id
    end
    if #ids == 0 then return nil, why2 end
    rec.exec, rec.mod_ids = "module", ids
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
  cs.wanted = sorted_keys(cs.wanted_set or {})
  cs.wanted_set = nil
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
        mod_ids = rec.mod_ids, opened = rec.opened }
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
