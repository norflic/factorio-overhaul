--[[
  CONSTRUCTION PAR LES PNJ (lot IA1-d, docs/EQUIPES_PNJ.md §6.5 à §6.8) : le plan directeur (shared/team/plan.lua, pur)
  appliqué au monde réel.

  Pour une équipe (faction ou votre équipe), `f.build` porte :
    - le treillis (lots de 24, rues de 4, ancré au QG) et l'ÉVALUATION des lots et des tronçons de rue (3 appels du
      moteur chacun, sur les jetons de travail du mod ; aucune entité posée) ;
    - les PROJETS : « construire tel module à tel débit, ici » (Build.request, l'interface du cerveau IA3-c) :
        attente (lots pas encore évalués) → plan (lot, rotation, têtes d'alimentation, tapis, poteaux) → reserve
        (objets RETIRÉS du coffre vers le stock du chantier : personne ne les arrache) → defrichage (arbres, rochers)
        → fantomes (posés d'avance ; votre équipe : « juste à temps », F176) → chantier (les PNJ ravivent les fantômes
        à 16 tuiles au plus de leur point d'appui) → raccordement (fils, recettes) → fini ; ou refuse / bloque (raison) ;
    - le RÉSEAU électrique : grands poteaux aux carrefours (moyens à défaut), centrale à vapeur sur une rive ;
    - les mesures : refus de lots et fermetures de rues par raison, marches par les rues, PNJ bloqués et replis vers le
      PathService (par minute), fantômes posés, ravivés, refusés.
  Les PNJ prennent les tâches au tableau de l'équipe (Board.add après chaque pensée) : `ghost` (construire un lot de
  fantômes autour d'un point d'appui), `clear` (défricher), `carry` (remplir un quai, vider un quai de sortie). Leurs
  programmes d'étapes sont dans script/team/worker.lua (étape « ia1d »).

  Rien ne change pour une équipe sans `f.build` (Build.enable n'est appelé que par le cerveau ou un banc).
  Déterminisme : listes triées, clés triées ; aucun temps mesuré ; rien de fonctionnel dans global.
]]

local Events = require("script.core.events")
local State = require("script.faction.state")
local Board = require("script.team.board")
local Tokens = require("script.team.tokens")
local Foot = require("shared.levels.footprint")
local P = require("shared.team.plan")
local M = require("shared.team.modules")

local Build = {}

Build.RADIUS = 3              -- carré de lots évalué au départ (7 × 7)
Build.RADIUS_MAX = 5
Build.PULSE = 5               -- ticks entre deux passes de travail
Build.EVAL_PER_PULSE = 4
Build.GHOSTS_PER_PULSE = 6
Build.REVIVE_PER_THINK = 6    -- ravivages par pensée d'un PNJ (pensée toutes les 60 ticks)
Build.CLEAR_PER_THINK = 3
Build.COST_EVAL = 30          -- unités de jetons (estimées ; E122 : un poteau ravivé 200 à 420 µs)
Build.COST_GHOST = 50
Build.COST_REVIVE = 50
Build.COST_REVIVE_POLE = 300
Build.COST_PLAN = 200
Build.QUAI_LOW = 60
Build.QUAI_FILL = 400
Build.COLLECT_AT = 200
Build.PRIO = 55
Build.FAIL_LIMIT = 3          -- §6.6 (4) : un fantôme refusé 3 fois bloque son module (raison écrite)

local REACH = P.BUILD_DISTANCE
local TREE_TYPES = { "tree", "simple-entity" }

---------------------------------------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------------------------------------
local function sorted_keys(t)
  local ks = {}
  for k in pairs(t) do ks[#ks + 1] = k end
  table.sort(ks, function(a, b)
    if type(a) == type(b) then return a < b end
    return type(a) == "number"
  end)
  return ks
end

local function bump(t, k, n) t[k] = (t[k] or 0) + (n or 1) end

local function dist2(a, b) local dx, dy = a.x - b.x, a.y - b.y; return dx * dx + dy * dy end

local ITEM_OF = {}
--- Objet qui pose une entité (prototype du jeu ; mémoire locale, jamais dans global).
local function item_of(name)
  local it = ITEM_OF[name]
  if it == nil then
    local p = game.entity_prototypes[name]
    local list = p and p.items_to_place_this
    it = (list and list[1] and list[1].name) or false
    ITEM_OF[name] = it
  end
  return it or nil
end

local function team_of_key(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

local function surface_of(f)
  return f.hq and f.hq.valid and f.hq.surface or nil
end

local function strict(b, x0, y0, x1, y1)
  return Foot.overlap({ x0 = x0, y0 = y0, x1 = x1, y1 = y1 },
    { x0 = b.left_top.x, y0 = b.left_top.y, x1 = b.right_bottom.x, y1 = b.right_bottom.y })
end

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
local function new_stats()
  return {
    lots = {}, lots_refused = {}, segs = {}, segs_closed = {}, plan_refused = {}, evals = 0,
    ghosts = 0, ghost_refused = 0, revived = 0, revive_fail = 0, cleared = 0, filled = 0, collected = 0,
    street_walks = 0, street_ok = 0, street_stuck = 0, minutes = {}, minute_cur = nil,
    modules_started = 0, modules_done = 0, projects_done = 0, projects_refused = 0, projects_blocked = 0,
  }
end

--- Active le plan directeur d'une équipe (idempotent). opts : seul (le banc retire les tâches libres de l'ancien
--- planificateur), ghosts_ahead (fantômes posés d'avance ; votre équipe : non par défaut, F176), radius.
function Build.enable(f, opts)
  if not (f and f.hq and f.hq.valid) then return nil end
  opts = opts or {}
  local b = f.build
  if not b then
    b = {
      lat = P.lattice(f.hq_pos), radius = 0, lots = {}, segs = {}, queue = {}, qhead = 1,
      projects = {}, order = {}, next_id = 1, occ = {}, net = {}, plant = nil,
      opts = { seul = false, ghosts_ahead = not f.is_player }, stats = new_stats(),
    }
    f.build = b
  end
  for _, k in ipairs({ "seul", "ghosts_ahead" }) do if opts[k] ~= nil then b.opts[k] = opts[k] and true or false end end
  Build.grow(f, opts.radius or Build.RADIUS)
  return b
end

--- Élargit le carré évalué au rayon r (nouveaux lots et tronçons mis en file, du centre vers l'extérieur).
function Build.grow(f, r)
  local b = f.build
  r = math.min(r, Build.RADIUS_MAX)
  if r <= b.radius then return end
  for _, l in ipairs(P.lots_within(r)) do
    local k = P.lot_key(l.i, l.j)
    if not b.lots[k] then
      b.lots[k] = { i = l.i, j = l.j, state = "inconnu" }
      b.queue[#b.queue + 1] = { "lot", k }
    end
  end
  for _, key in ipairs(P.segs_within(r)) do
    if not b.segs[key] then
      b.segs[key] = { state = "inconnu" }
      b.queue[#b.queue + 1] = { "seg", key }
    end
  end
  b.radius = r
end

local function seg_ok(b) return function(key) local s = b.segs[key]; return s ~= nil and s.state == "ouvert" end end
local function seg_passable(b) return function(key) local s = b.segs[key]; return s ~= nil and s.state ~= "ferme" and s.state ~= "inconnu" end end

---------------------------------------------------------------------------------------------------
-- Évaluation d'un lot ou d'un tronçon : 3 appels du moteur, aucune entité posée
---------------------------------------------------------------------------------------------------
local function survey(surface, force, x0, y0, x1, y1)
  local area = { { x0, y0 }, { x1, y1 } }
  local s = { tiles = (x1 - x0) * (y1 - y0), water = 0, cliffs = 0, trees = 0, rocks = 0, foreign = 0, own = 0, nests = 0, res = {} }
  s.water = surface.count_tiles_filtered({ area = area, collision_mask = "water-tile" })
  for _, e in ipairs(surface.find_entities_filtered({ area = area, collision_mask = "object-layer" })) do
    if strict(e.bounding_box, x0, y0, x1, y1) then
      local t = e.type
      local fn = e.force.name
      if t == "tree" then s.trees = s.trees + 1
      elseif t == "cliff" then s.cliffs = s.cliffs + 1
      elseif t == "simple-entity" then s.rocks = s.rocks + 1
      elseif t == "unit-spawner" or (t == "turret" and fn == "enemy") then s.nests = s.nests + 1
      elseif fn == force then s.own = s.own + 1
      elseif fn == "neutral" then s.rocks = s.rocks + 1
      elseif fn ~= "enemy" then s.foreign = s.foreign + 1 end
    end
  end
  for _, e in ipairs(surface.find_entities_filtered({ area = { { x0 + 0.01, y0 + 0.01 }, { x1 - 0.01, y1 - 0.01 } }, type = "resource" })) do
    bump(s.res, e.name)
  end
  return s
end

local function eval_one(f, surface, item, tick)
  local b = f.build
  local st = b.stats
  st.evals = st.evals + 1
  if item[1] == "lot" then
    local l = b.lots[item[2]]
    if not l or l.used then return end
    local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
    local s = survey(surface, f.force, x0, y0, x1, y1)
    -- le lot du QG est toujours « occupé »
    if l.i == 0 and l.j == 0 then s.own = math.max(1, s.own) end
    local old = l.state
    l.state, l.reason = P.classify_lot(s)
    l.res = (l.state == "gisement") and l.reason or nil
    l.water, l.trees, l.rocks, l.tick = s.water, s.trees + s.rocks, s.rocks, tick
    if old == "inconnu" then
      bump(st.lots, l.state)
      if l.state == "refuse" then bump(st.lots_refused, l.reason) end
    end
  else
    local g = b.segs[item[2]]
    local x0, y0, x1, y1 = P.seg_rect(b.lat, item[2])
    local s = survey(surface, f.force, x0, y0, x1, y1)
    local old = g.state
    g.state, g.reason = P.classify_segment(s)
    g.trees, g.tick = s.trees + s.rocks, tick
    if old == "inconnu" then
      bump(st.segs, g.state)
      if g.state == "ferme" then bump(st.segs_closed, g.reason) end
    elseif old == "encombre" and g.state == "ouvert" then
      bump(st.segs, "defriche")
    end
  end
end

--- Masques d'un rectangle lus au moteur (une fois par plan) : eau, bloqué (bâtiments, falaises, nids : non
--- défrichable), obstacles défrichables (arbres, rochers) ; plus les tuiles réservées par nos projets.
local function read_masks(f, surface, x0, y0, x1, y1)
  local b = f.build
  local water, blocked, clear = {}, {}, {}
  for _, t in ipairs(surface.find_tiles_filtered({ area = { { x0, y0 }, { x1, y1 } }, collision_mask = "water-tile" })) do
    water[P.tkey(math.floor(t.position.x), math.floor(t.position.y))] = true
  end
  for _, e in ipairs(surface.find_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, collision_mask = "object-layer" })) do
    local bb = e.bounding_box
    local tx0, ty0 = math.floor(bb.left_top.x + 0.01), math.floor(bb.left_top.y + 0.01)
    local tx1, ty1 = math.ceil(bb.right_bottom.x - 0.01) - 1, math.ceil(bb.right_bottom.y - 0.01) - 1
    local soft = e.type == "tree" or e.type == "simple-entity" or (e.force.name == "neutral" and e.type ~= "cliff")
    for ty = ty0, ty1 do
      for tx = tx0, tx1 do
        local k = P.tkey(tx, ty)
        if soft then clear[k] = true else blocked[k] = true end
      end
    end
  end
  return {
    water = water, blocked = blocked, clear = clear,
    free = function(tx, ty)
      local k = P.tkey(tx, ty)
      return not water[k] and not blocked[k] and not b.occ[k]
    end,
  }
end

---------------------------------------------------------------------------------------------------
-- Projets : demande (interface du cerveau)
---------------------------------------------------------------------------------------------------
--[[
  Build.request(f, spec) -> id, ou nil et raison. spec :
    gen, args     générateur de shared/team/modules.lua et ses paramètres (ou key = gabarit du catalogue) ;
    rate          débit visé en objets/min du produit principal (dimensionne l'extension du gabarit) ;
    resource      ressource exploitée (foreuses) ;
    feed          true : têtes d'alimentation (tapis depuis des foreuses quand une voie dépasse 60/min et qu'un
                  gisement est à portée, sinon quai), quais de sortie ;
    near          {x, y} : la zone préférée (sinon le QG ou le gisement de l'entrée principale) ;
    prio          priorité des tâches (défaut 55) ; domain : domaine des tâches (défaut production).
  Le module électrique demande la centrale (une par équipe, créée au besoin sur la rive la plus proche).
]]
function Build.request(f, spec)
  local b = f.build or Build.enable(f, {})
  if not b then return nil, "equipe" end
  if type(spec) ~= "table" then return nil, "spec" end
  local id = b.next_id
  b.next_id = id + 1
  local p = {
    id = id, spec = spec, state = "attente", created = game.tick, reason = nil,
    parts = {}, ents = {}, wires = {}, stock = {}, quais = {}, outs = {}, obstacles = {}, fails = 0,
    prio = spec.prio or Build.PRIO, domain = spec.domain or "production",
  }
  b.projects[id] = p
  b.order[#b.order + 1] = id
  if spec.gen == "steam" and not b.plant then b.plant = id end
  return id
end

--- Gabarit d'une demande, dimensionné au débit : (gabarit) ou (nil, raison).
local function template_of(spec)
  local g, why
  if spec.gen then
    local fn = M.GEN[spec.gen]
    if not fn then return nil, "generateur inconnu" end
    g, why = fn(table.unpack(spec.args or {}))
  elseif spec.key then
    g = M.get_any(spec.key)
    if not g then why = "gabarit inconnu" end
  end
  if not g then return nil, why end
  if spec.rate and g.extensions and g.extensions[1] and g.nominal then
    local want = spec.rate / 60
    local main
    for _, k in ipairs(sorted_keys(g.nominal)) do if k ~= "electricity-kw" then main = main or k end end
    if main and g.nominal[main] and g.nominal[main] > 0 then
      local ex = g.extensions[1]
      local cur = g.args[ex.arg]
      local n = math.max(1, math.min(ex.max, math.ceil(cur * want / g.nominal[main] - 1e-9)))
      if n ~= cur then
        local g2 = M.extend(g, n)
        if g2 then g = g2 end
      end
    end
  end
  return g
end

local function lot_center(b, l)
  local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
  return { x = (x0 + x1) / 2, y = (y0 + y1) / 2 }
end

--- Lots candidats d'une sorte, triés par distance à `toward` (puis i, j).
local function candidates(b, states, toward, res)
  local out = {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    if not l.used and states[l.state] and (not res or l.res == res) and not (l.bad and l.bad >= 2) then
      local c = lot_center(b, l)
      out[#out + 1] = { l = l, d = math.abs(c.x - toward.x) + math.abs(c.y - toward.y), k = k }
    end
  end
  table.sort(out, function(a, c) if a.d ~= c.d then return a.d < c.d end return a.k < c.k end)
  return out
end

--- Tuiles de minerai `res` d'un lot (un appel).
local function ore_set(surface, rect, res)
  local set, n = {}, 0
  for _, e in ipairs(surface.find_entities_filtered({ area = { { rect.x0 + 0.01, rect.y0 + 0.01 }, { rect.x1 - 0.01, rect.y1 - 0.01 } }, name = res })) do
    set[P.tkey(math.floor(e.position.x), math.floor(e.position.y))] = true
    n = n + 1
  end
  return set, n
end

--- Pose un gabarit dans le meilleur lot : { g (tourné), k, ox, oy, lot, inst } ou nil, raison.
local function place_module(f, surface, g, kind_states, toward, res, opts)
  local b = f.build
  local last = "pas de lot"
  local tries = 0
  for _, c in ipairs(candidates(b, kind_states, toward, res)) do
    tries = tries + 1
    if tries > 8 then break end
    local x0, y0, x1, y1 = P.lot_rect(b.lat, c.l.i, c.l.j)
    local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
    local masks = read_masks(f, surface, x0 - 8, y0 - 8, x1 + 8, y1 + 8)
    local fopts = { free = masks.free, toward = toward, margin = (opts and opts.margin) or 1 }
    if res then fopts.ore = ore_set(surface, rect, res) end
    if opts and opts.water then fopts.water = masks.water end
    local fit, why = P.fit(g, rect, fopts)
    if fit then
      local r = fit.k == 0 and g or M.rotate(g, fit.k)
      local inst = M.instantiate(r, 0, fit.ox, fit.oy)
      return { g = r, k = fit.k, ox = fit.ox, oy = fit.oy, lot = c.k, inst = inst, cover = fit.cover, masks = masks }
    end
    last = why or last
    bump(b.stats.plan_refused, last)
    c.l.bad = (c.l.bad or 0) + 1
  end
  return nil, last
end

--- Ajoute des entités planifiées au projet (contrôle de la place réservée) ; faux si une tuile est déjà prise.
local function reserve_tiles(b, p, list)
  for _, e in ipairs(list) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = P.tkey(t[1], t[2])
      if b.occ[k] and b.occ[k] ~= p.id then return false end
    end
  end
  for _, e in ipairs(list) do
    for _, t in ipairs(P.tiles_of(e)) do b.occ[P.tkey(t[1], t[2])] = p.id end
    p.ents[#p.ents + 1] = e
  end
  return true
end

local function inst_entities(inst, part)
  local out = {}
  for _, e in ipairs(inst.entities) do
    out[#out + 1] = { name = e.name, x = e.position.x, y = e.position.y, dir = e.direction or 0, recipe = e.recipe, part = part }
  end
  return out
end

local function pole_kind(f)
  local force = game.forces[f.force]
  local r = force and force.recipes["big-electric-pole"]
  if (f.hq.get_item_count("big-electric-pole") > 0) or (r and r.enabled) then return "big-electric-pole", 30 end
  return "medium-electric-pole", 9
end

--- Carrefour le plus proche d'une position (i, j).
local function nearest_node(b, x, y)
  local i = math.floor((x - b.lat.ox - P.HALF - 2) / P.PITCH + 0.5)
  local j = math.floor((y - b.lat.oy - P.HALF - 2) / P.PITCH + 0.5)
  return i, j
end

--- Poteaux du réseau à ajouter pour relier le module (premier poteau `mp`) au réseau : carrefours de la route jusqu'au
--- premier carrefour déjà au réseau (ou planifié), chaîne de liaison. Rend la liste d'entités ou nil, raison.
local function plan_power(f, p, mp, masks)
  local b = f.build
  local pole, reach = pole_kind(f)
  local big = pole == "big-electric-pole"
  local mi, mj = nearest_node(b, mp.x, mp.y)
  local out = {}
  -- route de carrefours jusqu'au réseau (tronçons non fermés)
  local target
  local keys = sorted_keys(b.net)
  if #keys == 0 then
    target = { i = mi, j = mj }
  else
    local best, bestd
    for _, k in ipairs(keys) do
      local n = b.net[k]
      local d = math.abs(n.i - mi) + math.abs(n.j - mj)
      if not bestd or d < bestd then best, bestd = n, d end
    end
    target = best
  end
  local nodes = P.route_nodes({ i = mi, j = mj }, target, seg_passable(b), b.radius)
  if not nodes then return nil, "pas de rue vers le reseau" end
  local prev
  for _, n in ipairs(nodes) do
    local k = P.lot_key(n.i, n.j)
    local pos = P.node_pole(b.lat, n.i, n.j, big)
    if not b.net[k] then
      out[#out + 1] = { name = pole, x = pos.x, y = pos.y, dir = 0, role = "reseau", node = k }
    end
    if prev and not big then
      local chain = P.pole_chain(prev, pos, 9, false, function(x, y) return masks.free(math.floor(x), math.floor(y)) end)
      if not chain then return nil, "poteaux de rue" end
      for _, c in ipairs(chain) do out[#out + 1] = { name = pole, x = c.x, y = c.y, dir = 0, role = "rue" } end
    end
    prev = pos
  end
  -- liaison du module au carrefour le plus proche (poteaux du gabarit : moyens)
  local npos = P.node_pole(b.lat, mi, mj, big)
  local link_reach = math.min(reach, P.wire(mp.name) or 9)
  local chain = P.pole_chain({ x = mp.x, y = mp.y }, npos, link_reach, false,
    function(x, y) return masks.free(math.floor(x), math.floor(y)) end)
  if not chain then return nil, "liaison electrique" end
  for _, c in ipairs(chain) do out[#out + 1] = { name = mp.name, x = c.x, y = c.y, dir = 0, role = "liaison" } end
  return out, nil, nodes
end

local function first_pole(ents)
  for _, e in ipairs(ents) do if e.name:find("electric%-pole") then return e end end
  return nil
end

local function needs_power(g) return (g.power_kw or 0) > 0 end

local function deposit_toward(b, res)
  local c = candidates(b, { gisement = true }, { x = b.lat.ox, y = b.lat.oy }, res)[1]
  return c and lot_center(b, c.l) or nil
end

--- Têtes d'alimentation et quais d'un module posé ; foreuses de ravitaillement et tapis. Rend true ou false, raison.
local function plan_feed(f, surface, p, place, part)
  local b = f.build
  local g = place.g
  for _, port in ipairs(P.belt_ports(place.inst)) do
    if port.io == "in" then
      local sources = { nil, nil }
      local drills = {}
      for lane = 1, 2 do
        local item = port.lanes and port.lanes[lane]
        -- une même ressource sur les deux voies : une seule source (la voie 1)
        if item and not (lane == 2 and port.lanes[1] == item) then
          sources[lane] = "quai"
          local flow = g.inputs and g.inputs[item] or 0
          if M.ORES[item] and flow >= P.AUTO_FLOW and p.spec.feed ~= "quai" then
            local dt = deposit_toward(b, item)
            if dt and (math.abs(dt.x - place.ox) + math.abs(dt.y - place.oy)) <= 3 * P.PITCH then
              sources[lane] = "tapis"
              drills[lane] = { item = item, flow = flow }
            end
          end
        end
      end
      local fd = P.feeder(port, sources, "inserter")
      for _, e in ipairs(fd.entities) do e.part = part end
      if not reserve_tiles(b, p, fd.entities) then return false, "tete d'alimentation" end
      for _, c in ipairs(fd.chests) do p.quais[#p.quais + 1] = { x = c.x, y = c.y, item = c.item } end
      for _, a in ipairs(fd.arrivals) do
        local d = drills[a.lane]
        if d then
          local ok, why = Build.plan_drills(f, surface, p, d.item, d.flow, a)
          if not ok then
            -- repli : quai sur cette voie (le tapis n'a pas pu être tracé ou le gisement manque)
            bump(b.stats.plan_refused, "tapis:" .. tostring(why))
            local alt = P.feeder(port, { a.lane == 1 and "quai" or nil, a.lane == 2 and "quai" or nil }, "inserter")
            local extra = {}
            for _, e in ipairs(alt.entities) do if e.role ~= "tete" then e.part = part; extra[#extra + 1] = e end end
            if reserve_tiles(b, p, extra) then
              for _, c in ipairs(alt.chests) do p.quais[#p.quais + 1] = { x = c.x, y = c.y, item = c.item } end
            end
          end
        end
      end
    else
      local outn = 0
      for _, k in ipairs(sorted_keys(g.nominal or {})) do if k ~= "electricity-kw" then outn = outn + g.nominal[k] end end
      local nports = 0
      for _, q in ipairs(P.belt_ports(place.inst)) do if q.io == "out" then nports = nports + 1 end end
      local per = outn / math.max(1, nports)
      local ins = M.choose_inserters(per, true, 1) or "fast-inserter"
      local q = P.out_quai(port, ins)
      for _, e in ipairs(q) do e.part = part end
      if not reserve_tiles(b, p, q) then return false, "quai de sortie" end
      p.outs[#p.outs + 1] = { x = q[2].x, y = q[2].y }
    end
  end
  return true
end

--- Foreuses de ravitaillement d'une voie et leur tapis jusqu'à l'arrivée `a`. Rend true, ou false et raison.
function Build.plan_drills(f, surface, p, item, flow, a)
  local b = f.build
  local n = math.max(1, math.ceil(flow / (2 * M.spec("electric-mining-drill").speed) - 1e-9))
  local place, why
  for nn = n, 1, -1 do
    local g = M.GEN.drills(item, nn)
    if g then
      place, why = place_module(f, surface, g, { gisement = true }, { x = a.x, y = a.y }, item)
      if place then break end
    end
  end
  if not place then return false, why end
  local part = #p.parts + 1
  p.parts[part] = { kind = "foreuses", key = place.g.key, lot = place.lot, ox = place.ox, oy = place.oy, k = place.k,
    w = place.g.w, h = place.g.h, power = needs_power(place.g) }
  local ents = inst_entities(place.inst, part)
  -- tapis : queue des foreuses → arrivée
  local tail
  for _, port in ipairs(P.belt_ports(place.inst)) do if port.io == "out" then tail = port end end
  local v = P.DV[tail.dir]
  local s = { x = tail.x + v[1], y = tail.y + v[2] }
  local bx0 = math.min(s.x, a.x) - 12
  local by0 = math.min(s.y, a.y) - 12
  local bx1 = math.max(s.x, a.x) + 12
  local by1 = math.max(s.y, a.y) + 12
  if bx1 - bx0 > 120 or by1 - by0 > 120 then return false, "trop loin" end
  local masks = read_masks(f, surface, bx0, by0, bx1 + 1, by1 + 1)
  -- anneau d'une tuile autour des modules (aucun tapis ne longe un module : bras, têtes, queues)
  local ring = {}
  local function ring_of(ox, oy, w, h)
    for x = ox - 1, ox + w do ring[P.tkey(x, oy - 1)] = true; ring[P.tkey(x, oy + h)] = true end
    for y = oy - 1, oy + h do ring[P.tkey(ox - 1, y)] = true; ring[P.tkey(ox + w, y)] = true end
  end
  for _, pt in ipairs(p.parts) do ring_of(pt.ox, pt.oy, pt.w, pt.h) end
  local planned = {}
  for _, e in ipairs(ents) do for _, t in ipairs(P.tiles_of(e)) do planned[P.tkey(t[1], t[2])] = true end end
  local sk, ak = P.tkey(s.x, s.y), P.tkey(a.x, a.y)
  local function cost(x, y)
    local k = P.tkey(x, y)
    if k ~= sk and k ~= ak and ring[k] then return nil end
    if masks.water[k] or masks.blocked[k] or b.occ[k] or planned[k] then return nil end
    local c = 1
    if P.in_street(b.lat, x, y) then c = P.STREET_COST end
    if masks.clear[k] then c = c + 1 end
    return c
  end
  local tiles, n2 = P.belt_route(s, { x = a.x, y = a.y }, a.dir, { x0 = bx0, y0 = by0, x1 = bx1, y1 = by1 }, cost)
  if not tiles then
    p.parts[part] = nil
    return false, n2
  end
  for _, t in ipairs(tiles) do ents[#ents + 1] = { name = "transport-belt", x = t.x + 0.5, y = t.y + 0.5, dir = t.dir, part = part, role = "liaison-tapis" } end
  if not reserve_tiles(b, p, ents) then p.parts[part] = nil; return false, "place" end
  b.lots[place.lot].used = p.id
  return true
end

--- Plan d'un projet : (true) ou (false, raison, attendre). Une seule pensée de plan par passe.
local function plan_project(f, surface, p)
  local b = f.build
  local spec = p.spec
  local g, why = template_of(spec)
  if not g then return false, why end
  local main
  local is_plant = g.gen == "steam"
  local toward
  if spec.near then toward = spec.near end
  if is_plant then
    main, why = place_module(f, surface, g, { rive = true }, toward or { x = b.lat.ox, y = b.lat.oy }, nil, { water = true, margin = 0 })
  elseif g.resource then
    main, why = place_module(f, surface, g, { gisement = true }, toward or { x = b.lat.ox, y = b.lat.oy }, spec.resource or g.resource)
  else
    if not toward then
      -- « les fonderies vont vers le minerai » : vers le gisement de l'entrée principale
      local best, bf
      for _, k in ipairs(sorted_keys(g.inputs or {})) do
        if M.ORES[k] and k ~= "coal" and (not bf or g.inputs[k] > bf) then best, bf = k, g.inputs[k] end
      end
      toward = (best and deposit_toward(b, best)) or { x = b.lat.ox, y = b.lat.oy }
    end
    main, why = place_module(f, surface, g, { libre = true, defricher = true }, toward, nil)
    if not main then main, why = place_module(f, surface, g, { gisement = true }, toward, nil) end
  end
  if not main then
    if b.radius < Build.RADIUS_MAX then
      Build.grow(f, b.radius + 1)
      return false, why, true
    end
    return false, why
  end
  p.parts[1] = { kind = is_plant and "centrale" or "module", key = main.g.key, lot = main.lot, ox = main.ox, oy = main.oy,
    k = main.k, w = main.g.w, h = main.g.h, power = needs_power(main.g) }
  local ents = inst_entities(main.inst, 1)
  if not reserve_tiles(b, p, ents) then return false, "place" end
  b.lots[main.lot].used = p.id
  if spec.feed or is_plant then
    local ok, w2 = plan_feed(f, surface, p, main, 1)
    if not ok then return false, w2 end
  end
  -- électricité : le réseau de l'équipe ; la centrale l'amorce
  local masks = main.masks
  local need = false
  for _, pt in ipairs(p.parts) do if pt.power or pt.kind == "centrale" then need = true end end
  if need then
    if not is_plant and not b.plant then
      Build.plant(f)
    end
    local seen = {}
    for idx, pt in ipairs(p.parts) do
      if pt and (pt.power or pt.kind == "centrale") then
        local mp
        for _, e in ipairs(p.ents) do if e.part == idx and e.name:find("electric%-pole") then mp = mp or e end end
        if mp and not seen[idx] then
          seen[idx] = true
          local extra, w3, nodes = plan_power(f, p, mp, masks)
          if not extra then return false, w3 end
          if not reserve_tiles(b, p, extra) then return false, "poteaux" end
          for _, n in ipairs(nodes or {}) do
            local k = P.lot_key(n.i, n.j)
            if not b.net[k] then b.net[k] = { i = n.i, j = n.j, pid = p.id } end
          end
        end
      end
    end
  end
  if is_plant then b.plant = p.id end
  -- points d'appui
  local passable = seg_passable(b)
  for _, e in ipairs(p.ents) do
    local a = P.anchor_for(b.lat, e.x, e.y, passable)
    if a then e.ax, e.ay, e.anchor = a.x, a.y, a.key
    else
      local cx, cy = math.floor(e.x / 8) * 8 + 4, math.floor(e.y / 8) * 8 + 4
      e.ax, e.ay, e.anchor = cx, cy, string.format("c%d:%d", cx, cy)
    end
    e.item = item_of(e.name)
  end
  P.sort_build(p.ents)
  -- obstacles à défricher sous les entités planifiées
  local obst = {}
  local seen_o = {}
  for _, e in ipairs(p.ents) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = P.tkey(t[1], t[2])
      if masks.clear[k] and not seen_o[k] then seen_o[k] = true; obst[#obst + 1] = { x = t[1] + 0.5, y = t[2] + 0.5, anchor = e.anchor, ax = e.ax, ay = e.ay } end
    end
  end
  p.obstacles = obst
  for _, pt in ipairs(p.parts) do if pt then b.stats.modules_started = b.stats.modules_started + 1 end end
  return true
end

--- Centrale de l'équipe (une demande, si aucune n'existe).
function Build.plant(f)
  local b = f.build
  if b.plant then return b.plant end
  local id = Build.request(f, { gen = "steam", args = { 1 }, feed = true, prio = Build.PRIO + 5, domain = "infrastructures" })
  b.plant = id
  -- la centrale passe avant les autres projets en attente
  local order = { id }
  for _, x in ipairs(b.order) do if x ~= id then order[#order + 1] = x end end
  b.order = order
  return id
end

---------------------------------------------------------------------------------------------------
-- Réservation au coffre
---------------------------------------------------------------------------------------------------
local function needs_of(p)
  local need = {}
  for _, e in ipairs(p.ents) do
    if not e.built and e.item then
      bump(need, e.item)
      if e.name == "burner-inserter" then bump(need, "coal", 2) end
    end
  end
  return need
end

local function reserve(f, p)
  local need = needs_of(p)
  local missing = {}
  for _, it in ipairs(sorted_keys(need)) do
    local want = need[it] - (p.stock[it] or 0)
    if want > 0 then
      local have = f.hq.get_item_count(it)
      local n = math.min(want, have)
      if n > 0 then
        local got = f.hq.remove_item({ name = it, count = n })
        bump(p.stock, it, got)
        want = want - got
      end
      if want > 0 then missing[#missing + 1] = { it, want } end
    end
  end
  p.missing = missing
  return #missing == 0
end

local function release(f, p)
  for _, it in ipairs(sorted_keys(p.stock)) do
    local n = p.stock[it]
    if n > 0 and f.hq and f.hq.valid then
      local put = f.hq.insert({ name = it, count = n })
      p.stock[it] = n - put
    end
  end
end

--- Prise au stock du chantier (étape « take_res » d'un PNJ) : rend vrai si tout a été pris.
function Build.take_reserved(f, pid, items, inv)
  local p = f.build and f.build.projects[pid]
  if not p then return false end
  local all = true
  for _, it in ipairs(items) do
    local want = it[2]
    local have = p.stock[it[1]] or 0
    if have < want then
      -- complément au coffre (un PNJ a pu rapporter des objets)
      local add = math.min(want - have, f.hq.get_item_count(it[1]))
      if add > 0 then have = have + f.hq.remove_item({ name = it[1], count = add }) end
    end
    local n = math.min(want, have)
    local put = n > 0 and inv.insert({ name = it[1], count = n }) or 0
    p.stock[it[1]] = have - put
    if put < want then all = false end
  end
  return all
end

---------------------------------------------------------------------------------------------------
-- Fantômes
---------------------------------------------------------------------------------------------------
local function find_real(surface, e, force)
  local found = surface.find_entity(e.name, { e.x, e.y })
  if found and found.force.name == force then return found end
  return nil
end

local function find_ghost(surface, e, force)
  for _, gh in ipairs(surface.find_entities_filtered({ position = { e.x, e.y }, radius = 0.3, name = "entity-ghost", force = force })) do
    if gh.ghost_name == e.name then return gh end
  end
  return nil
end

--- Pose le fantôme d'une entité planifiée : "ok", "deja" (bâtie), "obstacle" (arbre, rocher), "occupe" (autre).
local function place_ghost(surface, f, e)
  if find_real(surface, e, f.force) then return "deja" end
  if find_ghost(surface, e, f.force) then return "ok" end
  if not surface.can_place_entity({ name = e.name, position = { e.x, e.y }, direction = e.dir, force = f.force,
    build_check_type = defines.build_check_type.ghost_revive }) then
    local w, h = P.size(e.name, e.dir)
    local area = { { e.x - w / 2 + 0.05, e.y - h / 2 + 0.05 }, { e.x + w / 2 - 0.05, e.y + h / 2 - 0.05 } }
    if surface.count_entities_filtered({ area = area, type = TREE_TYPES, limit = 1 }) > 0 then return "obstacle" end
    return "occupe"
  end
  local gh = surface.create_entity({ name = "entity-ghost", inner_name = e.name, position = { e.x, e.y }, direction = e.dir,
    force = f.force, expires = false })
  if not gh then return "occupe" end
  return "ok"
end

--- Ravive (ou pose puis ravive) une entité planifiée avec l'objet porté par le PNJ : true si bâtie.
local function revive_one(surface, f, p, e, inv, tick)
  local st = f.build.stats
  if find_real(surface, e, f.force) then e.built = true return true end
  if not e.item or inv.get_item_count(e.item) < 1 then return false end
  local gh = find_ghost(surface, e, f.force)
  if not gh then
    local r = place_ghost(surface, f, e)
    if r == "deja" then e.built = true return true end
    if r ~= "ok" then
      e.fails = (e.fails or 0) + 1
      st.revive_fail = st.revive_fail + 1
      if r == "obstacle" then p.obstacles[#p.obstacles + 1] = { x = e.x, y = e.y, anchor = e.anchor, ax = e.ax, ay = e.ay } end
      return false
    end
    st.ghosts = st.ghosts + 1
    gh = find_ghost(surface, e, f.force)
    if not gh then return false end
  end
  inv.remove({ name = e.item, count = 1 })
  local _, ent = gh.revive({ raise_revive = true })
  if not (ent and ent.valid) then
    inv.insert({ name = e.item, count = 1 })
    e.fails = (e.fails or 0) + 1
    st.revive_fail = st.revive_fail + 1
    return false
  end
  if e.recipe and ent.type == "assembling-machine" then pcall(ent.set_recipe, e.recipe) end
  if e.name == "burner-inserter" and inv.get_item_count("coal") >= 2 then
    local fuel = ent.get_fuel_inventory()
    if fuel then fuel.insert({ name = "coal", count = inv.remove({ name = "coal", count = 2 }) }) end
  end
  e.built = true
  st.revived = st.revived + 1
  return true
end

---------------------------------------------------------------------------------------------------
-- Travail d'un PNJ sur place (état « ia1d » de script/team/worker.lua) : "more", "done" ou "fail"
---------------------------------------------------------------------------------------------------
function Build.work(agent, f, tick)
  local job = agent.ia1d
  local b = f and f.build
  local p = b and job and b.projects[job.pid]
  if not p and not (b and job and job.seg) then return "fail" end
  local e = agent.entity
  local surface = e.surface
  local inv = e.get_main_inventory()
  local pos = e.position
  -- 16 tuiles du point d'appui ; le PNJ s'arrête à 2 tuiles au plus de ce point (étape goto, rayon 1, but déplacé
  -- s'il est occupé) : 18 tuiles au plus du PNJ, distance la plus grande mesurée et publiée (max_reach).
  local reach2 = (REACH + 2) * (REACH + 2)
  if job.mode == "build" then
    local did, left = 0, 0
    for _, x in ipairs(p.ents) do
      if not x.built and x.anchor == job.anchor then
        if dist2(x, pos) <= reach2 and x.item and inv.get_item_count(x.item) > 0 and (x.fails or 0) < Build.FAIL_LIMIT * 2 then
          if did < Build.REVIVE_PER_THINK then
            local cost = x.name:find("electric%-pole") and Build.COST_REVIVE_POLE or Build.COST_REVIVE
            if not Tokens.take(f, tick, cost) then return "more" end
            if revive_one(surface, f, p, x, inv, tick) then
              did = did + 1
              local d = math.sqrt(dist2(x, pos))
              if d > (b.stats.max_reach or 0) then b.stats.max_reach = d end
            else
              left = left + 1
            end
          else
            left = left + 1
          end
        end
      end
    end
    job.done = (job.done or 0) + did
    if did > 0 and left > 0 then return "more" end
    if did > 0 then return "more" end -- une pensée de plus pour constater la fin
    return (job.done or 0) > 0 and "done" or "fail"
  elseif job.mode == "clear" then
    local did = 0
    local rect = job.rect
    local area = rect and { { rect[1], rect[2] }, { rect[3], rect[4] } } or { { pos.x - REACH, pos.y - REACH }, { pos.x + REACH, pos.y + REACH } }
    local list = surface.find_entities_filtered({ area = area, type = TREE_TYPES })
    table.sort(list, function(a, c)
      local da, dc = dist2(a.position, pos), dist2(c.position, pos)
      if da ~= dc then return da < dc end
      if a.position.x ~= c.position.x then return a.position.x < c.position.x end
      return a.position.y < c.position.y
    end)
    local remain = 0
    for _, t in ipairs(list) do
      if dist2(t.position, pos) <= reach2 then
        if did < Build.CLEAR_PER_THINK then
          if not Tokens.take(f, tick, Build.COST_EVAL) then return "more" end
          if t.mine({ inventory = inv, force = e.force, raise_destroyed = true }) then
            did = did + 1
            b.stats.cleared = b.stats.cleared + 1
          else
            if t.valid then t.destroy({ raise_destroy = true }) end
            did = did + 1
            b.stats.cleared = b.stats.cleared + 1
          end
        else
          remain = remain + 1
        end
      end
    end
    job.done = (job.done or 0) + did
    if did > 0 or remain > 0 then return "more" end
    if job.seg then Build.street_cleared(f, job.seg) end
    return "done"
  elseif job.mode == "fill" then
    local q = p.quais[job.idx]
    local chest = q and surface.find_entity("iron-chest", { q.x, q.y })
    if not chest then return "fail" end
    local n = inv.get_item_count(q.item)
    if n > 0 then
      local put = chest.insert({ name = q.item, count = n })
      if put > 0 then inv.remove({ name = q.item, count = put }) end
      b.stats.filled = b.stats.filled + put
    end
    return "done"
  elseif job.mode == "collect" then
    local o = p.outs[job.idx]
    local chest = o and surface.find_entity("iron-chest", { o.x, o.y })
    if not chest then return "fail" end
    local got = 0
    for _, it in ipairs(sorted_keys(chest.get_inventory(defines.inventory.chest).get_contents())) do
      local n = chest.get_item_count(it)
      local put = inv.insert({ name = it, count = n })
      if put > 0 then chest.remove_item({ name = it, count = put }); got = got + put end
    end
    b.stats.collected = b.stats.collected + got
    return "done"
  end
  return "fail"
end

---------------------------------------------------------------------------------------------------
-- Marche par les rues (étape goto de script/team/worker.lua)
---------------------------------------------------------------------------------------------------
--- Waypoints par les rues de p à q quand les deux sont dans le plan (tronçons OUVERTS seulement), sinon nil.
function Build.street_route(f, p, q)
  local b = f.build
  if not b or b.radius == 0 then return nil end
  local lim = (b.radius + 0.5) * P.PITCH
  if math.abs(p.x - b.lat.ox) > lim or math.abs(p.y - b.lat.oy) > lim then return nil end
  if math.abs(q.x - b.lat.ox) > lim or math.abs(q.y - b.lat.oy) > lim then return nil end
  local wp = P.street_path(b.lat, p, q, seg_ok(b), b.radius)
  if not wp then return nil end
  return wp
end

--- Mesures de la marche par les rues : "start", "ok", "stuck" (repli PathService).
function Build.note_walk(f, what)
  local st = f.build and f.build.stats
  if not st then return end
  if what == "start" then st.street_walks = st.street_walks + 1
  elseif what == "ok" then st.street_ok = st.street_ok + 1
  elseif what == "stuck" then st.street_stuck = st.street_stuck + 1 end
end

---------------------------------------------------------------------------------------------------
-- Tâches au tableau
---------------------------------------------------------------------------------------------------
local function batch_tasks(f, p, out)
  local b = f.build
  local by = {}
  local order = {}
  for _, e in ipairs(p.ents) do
    if not e.built and e.item and (e.fails or 0) < Build.FAIL_LIMIT * 2 then
      local k = e.anchor
      if not by[k] then by[k] = { items = {}, ax = e.ax, ay = e.ay, n = 0, poles = 0 }; order[#order + 1] = k end
      local bt = by[k]
      bump(bt.items, e.item)
      if e.name == "burner-inserter" then bump(bt.items, "coal", 2) end
      bt.n = bt.n + 1
    end
  end
  table.sort(order)
  for _, k in ipairs(order) do
    local bt = by[k]
    local items = {}
    for _, it in ipairs(sorted_keys(bt.items)) do items[#items + 1] = { it, bt.items[it] } end
    out[#out + 1] = {
      key = "ia1d:" .. p.id .. ":b:" .. k, kind = "ghost", prio = p.prio, domain = p.domain, work = 15 + 2 * bt.n,
      items = items, ia1d = { pid = p.id, mode = "build", anchor = k, ax = bt.ax, ay = bt.ay },
    }
  end
end

local function clear_tasks(f, p, out)
  local by, order = {}, {}
  for _, o in ipairs(p.obstacles) do
    if not o.done then
      local k = o.anchor or "?"
      if not by[k] then
        by[k] = { ax = o.ax or o.x, ay = o.ay or o.y, x0 = o.x, y0 = o.y, x1 = o.x, y1 = o.y }
        order[#order + 1] = k
      end
      local c = by[k]
      c.x0, c.y0 = math.min(c.x0, o.x), math.min(c.y0, o.y)
      c.x1, c.y1 = math.max(c.x1, o.x), math.max(c.y1, o.y)
    end
  end
  table.sort(order)
  for _, k in ipairs(order) do
    local c = by[k]
    out[#out + 1] = {
      key = "ia1d:" .. p.id .. ":c:" .. k, kind = "clear", prio = p.prio + 1, domain = "logistique", work = 30,
      ia1d = { pid = p.id, mode = "clear", anchor = k, ax = c.ax, ay = c.ay, rect = { c.x0 - 1, c.y0 - 1, c.x1 + 1, c.y1 + 1 } },
    }
  end
end

--- Défrichage des rues (R13) : tronçons encombrés sur les routes du QG vers les chantiers.
local function street_clear_tasks(f, out)
  local b = f.build
  local want = {}
  local passable = seg_passable(b)
  local hi, hj = 0, 0
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and (p.state == "defrichage" or p.state == "fantomes" or p.state == "chantier") and p.parts[1] then
      local pt = p.parts[1]
      local ti, tj = nearest_node(b, pt.ox, pt.oy)
      local nodes = P.route_nodes({ i = hi, j = hj }, { i = ti, j = tj }, passable, b.radius)
      for k = 2, #(nodes or {}) do
        local a, c = nodes[k - 1], nodes[k]
        local key = a.i ~= c.i and P.seg_key("h", math.min(a.i, c.i), a.j) or P.seg_key("v", a.i, math.min(a.j, c.j))
        if b.segs[key] and b.segs[key].state == "encombre" then want[key] = true end
      end
    end
  end
  for _, key in ipairs(sorted_keys(want)) do
    local x0, y0, x1, y1 = P.seg_rect(b.lat, key)
    -- deux moitiés de 16 tuiles : tout arbre du tronçon est à portée d'un point d'appui
    local halves
    if key:sub(1, 1) == "h" then
      local mx = (x0 + x1) / 2
      halves = { { x0, y0, mx, y1 }, { mx, y0, x1, y1 } }
    else
      local my = (y0 + y1) / 2
      halves = { { x0, y0, x1, my }, { x0, my, x1, y1 } }
    end
    for h, r in ipairs(halves) do
      out[#out + 1] = {
        key = "ia1d:rue:" .. key .. ":" .. h, kind = "clear", prio = Build.PRIO + 2, domain = "logistique", work = 40,
        ia1d = { pid = 0, mode = "clear", seg = key, ax = (r[1] + r[3]) / 2, ay = (r[2] + r[4]) / 2, rect = r },
      }
    end
  end
end

local function quai_tasks(f, p, surface, out)
  for i, q in ipairs(p.quais) do
    local chest = surface.find_entity("iron-chest", { q.x, q.y })
    if chest and chest.force.name == f.force then
      local n = chest.get_item_count(q.item)
      local have = f.hq.get_item_count(q.item)
      if n < Build.QUAI_LOW and have > 0 then
        local a = P.anchor_for(f.build.lat, q.x, q.y, seg_passable(f.build)) or { x = q.x, y = q.y }
        out[#out + 1] = {
          key = "ia1d:" .. p.id .. ":q:" .. i, kind = "carry", prio = p.prio + 3, domain = "logistique", work = 40,
          items = { { q.item, math.min(Build.QUAI_FILL - n, have) } },
          ia1d = { pid = p.id, mode = "fill", idx = i, ax = a.x, ay = a.y },
        }
      end
    end
  end
  for i, o in ipairs(p.outs) do
    local chest = surface.find_entity("iron-chest", { o.x, o.y })
    if chest and chest.force.name == f.force then
      local n = chest.get_inventory(defines.inventory.chest).get_item_count()
      if n >= Build.COLLECT_AT then
        local a = P.anchor_for(f.build.lat, o.x, o.y, seg_passable(f.build)) or { x = o.x, y = o.y }
        out[#out + 1] = {
          key = "ia1d:" .. p.id .. ":o:" .. i, kind = "carry", prio = p.prio, domain = "logistique", work = 40,
          ia1d = { pid = p.id, mode = "collect", idx = i, ax = a.x, ay = a.y },
        }
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Raccordement : fils (arbre couvrant au plus court), recettes
---------------------------------------------------------------------------------------------------
local function wire_project(f, surface, p)
  local poles = {}
  local b = f.build
  local seen = {}
  local function add(ent) if ent and ent.valid and not seen[ent.unit_number] then seen[ent.unit_number] = true; poles[#poles + 1] = ent end end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, e in ipairs(p.ents) do
    if e.name:find("electric%-pole") then
      add(find_real(surface, e, f.force))
      x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
    end
  end
  if #poles == 0 then return 0 end
  -- poteaux du réseau voisins
  for _, ent in ipairs(surface.find_entities_filtered({ area = { { x0 - 30, y0 - 30 }, { x1 + 30, y1 + 30 } }, type = "electric-pole", force = f.force })) do add(ent) end
  table.sort(poles, function(a, c) if a.position.y ~= c.position.y then return a.position.y < c.position.y end return a.position.x < c.position.x end)
  local cand = {}
  for a = 1, #poles do
    for c = a + 1, #poles do
      local pa, pc = poles[a], poles[c]
      local reach = math.min(pa.prototype.max_wire_distance, pc.prototype.max_wire_distance)
      local d2 = dist2(pa.position, pc.position)
      if d2 <= reach * reach + 1e-6 then cand[#cand + 1] = { d2, a, c } end
    end
  end
  table.sort(cand, function(u, v) if u[1] ~= v[1] then return u[1] < v[1] end if u[2] ~= v[2] then return u[2] < v[2] end return u[3] < v[3] end)
  local parent = {}
  for i = 1, #poles do parent[i] = i end
  local function find(x) while parent[x] ~= x do x = parent[x] end return x end
  -- poteaux déjà reliés entre eux : même composante
  for a = 1, #poles do
    for _, nb in ipairs((poles[a].neighbours or {}).copper or {}) do
      for c = 1, #poles do if poles[c] == nb then local ra, rc = find(a), find(c); if ra ~= rc then parent[rc] = ra end end end
    end
  end
  local n = 0
  for _, c in ipairs(cand) do
    local ra, rc = find(c[2]), find(c[3])
    if ra ~= rc then
      if poles[c[2]].connect_neighbour(poles[c[3]]) then n = n + 1 end
      parent[rc] = ra
    end
  end
  return n
end

local function all_built(p)
  for _, e in ipairs(p.ents) do if not e.built then return false end end
  return true
end

local function count_built(p)
  local n = 0
  for _, e in ipairs(p.ents) do if e.built then n = n + 1 end end
  return n
end

--- Fin d'un projet : fils, objets restants rendus, modules comptés.
local function finish_project(f, surface, p, tick)
  local b = f.build
  p.wired = wire_project(f, surface, p)
  release(f, p)
  p.state = "fini"
  p.finished = tick
  for _, pt in pairs(p.parts) do
    if pt then b.stats.modules_done = b.stats.modules_done + 1 end
  end
  b.stats.projects_done = b.stats.projects_done + 1
  for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n].built = true end end
  log(string.format("[FO-IA1D] %s : projet %d fini (%s, %d entites, %d fils) a %.1f min", f.key or "player", p.id,
    p.parts[1] and p.parts[1].key or "?", #p.ents, p.wired or 0, tick / 3600))
end

---------------------------------------------------------------------------------------------------
-- Avancement : passe de travail (toutes les Build.PULSE ticks) et pensée d'équipe
---------------------------------------------------------------------------------------------------
local function advance(f, surface, p, tick)
  local b = f.build
  if p.state == "attente" then
    if b.qhead > #b.queue then p.state = "plan" end
    return
  end
  if p.state == "plan" then
    if not Tokens.take(f, tick, Build.COST_PLAN) then return end
    -- un projet ne se planifie qu'après la centrale (qui amorce le réseau)
    if b.plant and b.plant ~= p.id then
      local pl = b.projects[b.plant]
      if pl and (pl.state == "attente" or pl.state == "plan") then return end
    end
    local ok, why, wait = plan_project(f, surface, p)
    if ok then
      p.state = "reserve"
      p.started = tick
      log(string.format("[FO-IA1D] %s : projet %d plan (%s, lot %s, %d entites, %d obstacles) a %.1f min", f.key or "player", p.id,
        p.parts[1].key, p.parts[1].lot, #p.ents, #p.obstacles, tick / 3600))
    elseif wait then
      p.state = "attente"
      p.reason = why
    else
      -- tout ce qui a été réservé est rendu
      for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
      for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
      for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
      p.ents, p.parts = {}, {}
      p.state, p.reason = "refuse", why
      b.stats.projects_refused = b.stats.projects_refused + 1
      if b.plant == p.id then b.plant = nil end
      log(string.format("[FO-IA1D] %s : projet %d refuse (%s)", f.key or "player", p.id, tostring(why)))
    end
    return
  end
  if p.state == "reserve" then
    if reserve(f, p) then p.state = #p.obstacles > 0 and "defrichage" or "fantomes" else p.reason = "materiaux" end
    return
  end
  if p.state == "defrichage" then
    local left = 0
    for _, o in ipairs(p.obstacles) do
      if not o.done then
        if surface.count_entities_filtered({ area = { { o.x - 0.45, o.y - 0.45 }, { o.x + 0.45, o.y + 0.45 } }, type = TREE_TYPES, limit = 1 }) == 0 then
          o.done = true
        else
          left = left + 1
        end
      end
    end
    if left == 0 then p.state = "fantomes" end
    return
  end
  if p.state == "fantomes" then
    if not b.opts.ghosts_ahead then p.state = "chantier" return end
    local placed = 0
    local pending = 0
    for _, e in ipairs(p.ents) do
      if not e.built and not e.ghosted then
        if placed >= Build.GHOSTS_PER_PULSE then pending = pending + 1 break end
        if not Tokens.take(f, tick, Build.COST_GHOST) then return end
        local r = place_ghost(surface, f, e)
        if r == "ok" then e.ghosted = true; placed = placed + 1; b.stats.ghosts = b.stats.ghosts + 1
        elseif r == "deja" then e.built = true
        elseif r == "obstacle" then
          p.obstacles[#p.obstacles + 1] = { x = e.x, y = e.y, anchor = e.anchor, ax = e.ax, ay = e.ay }
          e.ghosted = true
        else
          e.ghosted = true
          e.fails = (e.fails or 0) + 1
          b.stats.ghost_refused = b.stats.ghost_refused + 1
        end
      end
    end
    if pending == 0 then p.state = "chantier" end
    return
  end
  if p.state == "chantier" then
    if all_built(p) then
      p.state = "raccordement"
    else
      -- 3 refus d'un même fantôme : le module est bloqué (raison écrite), §6.6 (4)
      for _, e in ipairs(p.ents) do
        if not e.built and (e.fails or 0) >= Build.FAIL_LIMIT * 2 then
          p.state, p.reason = "bloque", "fantome refuse (" .. e.name .. " en " .. e.x .. "," .. e.y .. ")"
          b.stats.projects_blocked = b.stats.projects_blocked + 1
          log(string.format("[FO-IA1D] %s : projet %d bloque : %s", f.key or "player", p.id, p.reason))
          return
        end
      end
    end
    return
  end
  if p.state == "raccordement" then
    finish_project(f, surface, p, tick)
  end
end

local function pulse_team(f, tick)
  local b = f.build
  local surface = surface_of(f)
  if not (b and surface) then return end
  -- 1. évaluations
  local n = 0
  while b.qhead <= #b.queue and n < Build.EVAL_PER_PULSE do
    if not Tokens.take(f, tick, Build.COST_EVAL) then break end
    eval_one(f, surface, b.queue[b.qhead], tick)
    b.queue[b.qhead] = false
    b.qhead = b.qhead + 1
    n = n + 1
  end
  if b.qhead > #b.queue and #b.queue > 0 then b.queue, b.qhead = {}, 1 end
  -- 2. projets, dans l'ordre des demandes (un plan au plus par passe)
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and p.state ~= "fini" and p.state ~= "refuse" and p.state ~= "bloque" then
      local was = p.state
      advance(f, surface, p, tick)
      if was == "plan" and p.state ~= "plan" then break end
    end
  end
end

local function teams()
  local out = {}
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.build then out[#out + 1] = f end
  end
  local pf = State.faction("player")
  if pf and pf.build then out[#out + 1] = pf end
  return out
end

Events.on_nth_tick(Build.PULSE, function(e)
  for _, f in ipairs(teams()) do
    if f.hq and f.hq.valid then pulse_team(f, e.tick) end
  end
end)

--- Pensée d'équipe (script/team/team.lua, après l'organisation) : tâches au tableau, réévaluation des rues
--- défrichées, mesures par minute. Sans plan directeur : rien.
function Build.think(f, surface, tick)
  local b = f.build
  if not b then return end
  local tasks = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p then
      if p.state == "defrichage" then clear_tasks(f, p, tasks)
      elseif p.state == "chantier" or (p.state == "fantomes" and b.opts.ghosts_ahead) then
        if #p.obstacles > 0 then
          local open = false
          for _, o in ipairs(p.obstacles) do if not o.done then open = true break end end
          if open then clear_tasks(f, p, tasks) end
        end
        batch_tasks(f, p, tasks)
      end
      if p.state == "fini" or p.state == "chantier" then quai_tasks(f, p, surface, tasks) end
    end
  end
  street_clear_tasks(f, tasks)
  if b.opts.seul then
    Board.drop_free(f, function(t) return t.ia1d ~= nil end)
  end
  if #tasks > 0 then Board.add(f, tasks, tick) end
  -- tronçons encombrés : réévalués (défrichés par les PNJ)
  for _, key in ipairs(sorted_keys(b.segs)) do
    local s = b.segs[key]
    if s.state == "encombre" and s.cleared_tick and tick - s.cleared_tick < 600 then
      b.queue[#b.queue + 1] = { "seg", key }
      s.cleared_tick = nil
    end
  end
  -- mesures par minute
  local st = b.stats
  local m = math.floor(tick / 3600)
  if st.minute_cur ~= m then
    st.minute_cur = m
    st.minutes[#st.minutes + 1] = { m = m, walks = st.street_walks, ok = st.street_ok, stuck = st.street_stuck,
      revived = st.revived, cleared = st.cleared, ghosts = st.ghosts }
    if #st.minutes > 240 then table.remove(st.minutes, 1) end
  end
end

--- Un tronçon de rue défriché par un PNJ : réévalué à la pensée suivante.
function Build.street_cleared(f, key)
  local s = f.build and f.build.segs[key]
  if s then s.cleared_tick = game.tick end
end

---------------------------------------------------------------------------------------------------
-- Lecture (interface du cerveau et des bancs)
---------------------------------------------------------------------------------------------------
function Build.status(f, id)
  local p = f and f.build and f.build.projects[id]
  if not p then return nil end
  local parts = {}
  for i = 1, #p.parts do
    local pt = p.parts[i]
    if pt then parts[#parts + 1] = { kind = pt.kind, key = pt.key, lot = pt.lot, x = pt.ox, y = pt.oy, w = pt.w, h = pt.h, rotation = pt.k } end
  end
  local missing = {}
  for _, m in ipairs(p.missing or {}) do missing[#missing + 1] = { m[1], m[2] } end
  return { id = p.id, state = p.state, reason = p.reason, built = count_built(p), total = #p.ents, parts = parts,
    obstacles = #p.obstacles, quais = #p.quais, outs = #p.outs, missing = missing, created = p.created, started = p.started,
    finished = p.finished, wires = p.wired }
end

function Build.report(f)
  local b = f and f.build
  if not b then return nil end
  local st = b.stats
  local projects = {}
  for _, pid in ipairs(b.order) do projects[#projects + 1] = Build.status(f, pid) end
  local lots, segs = {}, {}
  for _, k in ipairs(sorted_keys(b.lots)) do local l = b.lots[k]; bump(lots, l.state .. (l.reason and (":" .. l.reason) or "")) end
  for _, k in ipairs(sorted_keys(b.segs)) do local s = b.segs[k]; bump(segs, s.state .. (s.reason and (":" .. s.reason) or "")) end
  local out = {
    radius = b.radius, lots = lots, segs = segs, queue = #b.queue - b.qhead + 1, projects = projects,
    lots_refused = st.lots_refused, segs_closed = st.segs_closed, plan_refused = st.plan_refused,
    ghosts = st.ghosts, ghost_refused = st.ghost_refused, revived = st.revived, revive_fail = st.revive_fail,
    cleared = st.cleared, filled = st.filled, collected = st.collected,
    street_walks = st.street_walks, street_ok = st.street_ok, street_stuck = st.street_stuck,
    modules_started = st.modules_started, modules_done = st.modules_done, projects_done = st.projects_done,
    projects_refused = st.projects_refused, projects_blocked = st.projects_blocked, minutes = st.minutes,
    net = #sorted_keys(b.net), opts = { seul = b.opts.seul, ghosts_ahead = b.opts.ghosts_ahead },
  }
  return out
end

--- Lots et tronçons (pour les captures et les bancs) : listes { i, j, state, reason } et { key, state, reason }.
function Build.layout(f)
  local b = f and f.build
  if not b then return nil end
  local lots, segs = {}, {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
    lots[#lots + 1] = { i = l.i, j = l.j, state = l.state, reason = l.reason, used = l.used, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  end
  for _, k in ipairs(sorted_keys(b.segs)) do
    local s = b.segs[k]
    local x0, y0, x1, y1 = P.seg_rect(b.lat, k)
    segs[#segs + 1] = { key = k, state = s.state, reason = s.reason, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
  end
  local ents = {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    for _, e in ipairs(p and p.ents or {}) do ents[#ents + 1] = { name = e.name, x = e.x, y = e.y, dir = e.dir, pid = pid, built = e.built or false } end
  end
  return { lots = lots, segs = segs, ents = ents, ox = b.lat.ox, oy = b.lat.oy }
end

remote.add_interface("fo-ia1d", {
  enable = function(key, opts)
    local f = team_of_key(key)
    local b = f and Build.enable(f, type(opts) == "table" and opts or {})
    return b ~= nil
  end,
  request = function(key, spec)
    local f = team_of_key(key)
    if not (f and f.build) then return nil, "plan directeur inactif" end
    return Build.request(f, spec)
  end,
  status = function(key, id) return Build.status(team_of_key(key), id) end,
  report = function(key) return Build.report(team_of_key(key)) end,
  layout = function(key) return Build.layout(team_of_key(key)) end,
  set_option = function(key, name, value)
    local f = team_of_key(key)
    if not (f and f.build and (name == "seul" or name == "ghosts_ahead")) then return nil end
    f.build.opts[name] = value and true or false
    return f.build.opts[name]
  end,
})

return Build
