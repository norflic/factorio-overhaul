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
local Profiler = require("script.core.profiler")
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
Build.REFUSAL_LOGS = 40       -- refus de fantôme écrits au journal (emprise et occupants), au plus, par équipe
Build.NPC_BLOCKS_PER_FAIL = 5  -- un PNJ debout sur l'emprise est passager : 5 refus de ce genre comptent pour 1 échec
Build.RETRY_TICKS = 7200       -- un projet bloqué rend ses PNJ et reprend 2 min plus tard (au plus Build.RETRIES fois)
Build.RETRIES = 3
Build.ANCHOR_SEARCH = 6        -- rayon (tuiles) de la recherche d'une tuile libre pour un point d'appui
Build.OBST_CHECKS = 8          -- obstacles revus par passe (défrichage et chantier), à tour de rôle
Build.CUT_WIDTH = 1.5          -- demi-largeur (tuiles) du couloir qu'un défricheur arrêté s'ouvre vers son point d'appui
Build.CUT_TRIES = 6            -- marches refaites après une coupe, par tâche

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
      b.seg_ver = (b.seg_ver or 0) + 1
      b.queue[#b.queue + 1] = { "seg", key }
    end
  end
  b.radius = r
end

local function seg_ok(b) return function(key) local s = b.segs[key]; return s ~= nil and s.state == "ouvert" end end
local function seg_passable(b) return function(key) local s = b.segs[key]; return s ~= nil and s.state ~= "ferme" and s.state ~= "inconnu" end end
--- Tronçon que des fils peuvent suivre : connu, et fermé au plus par une falaise ou nos bâtiments (pas l'eau : le
--- carrefour peut y tomber ; ni nid, ni force rivale).
local function seg_wire(b) return function(key)
  local s = b.segs[key]
  if s == nil or s.state == "inconnu" then return false end
  return s.state ~= "ferme" or s.reason == "falaise" or s.reason == "batiments"
end end

---------------------------------------------------------------------------------------------------
-- Évaluation d'un lot ou d'un tronçon : 3 appels du moteur, aucune entité posée
---------------------------------------------------------------------------------------------------
local WALKABLE_OWN = { ["transport-belt"] = true, ["underground-belt"] = true, ["splitter"] = true, ["electric-pole"] = true }

local function survey(surface, force, x0, y0, x1, y1, seg)
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
      elseif fn == force then
        -- un tronçon de rue reste praticable sous nos tapis et nos poteaux (correction du 27/10 : 9 rues « fermées
        -- par nos bâtiments » après défrichage au banc ia1-build-foret)
        if not (seg and WALKABLE_OWN[t]) then s.own = s.own + 1 end
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
    local s = survey(surface, f.force, x0, y0, x1, y1, true)
    local old = g.state
    g.state, g.reason = P.classify_segment(s)
    g.trees, g.tick = s.trees + s.rocks, tick
    if g.state ~= old then b.seg_ver = (b.seg_ver or 0) + 1 end
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
    -- un lot de gisement sert plusieurs lignes de foreuses tant qu'il reste de la place (relevé des tuiles libres)
    -- lot IA3-e : la centrale peut aussi aller dans un lot refusé pour l'EAU (plus de la moitié d'eau) : sa rive y est
    -- souvent la seule ; le gabarit ne pose rien sur l'eau (P.fit)
    local ok_state = states[l.state] or (states.eau and l.state == "refuse" and l.reason == "eau")
    if (not l.used or l.state == "gisement") and ok_state and (not res or l.res == res) and not (l.bad and l.bad >= 2) then
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
  -- poteau d'un carrefour : celui du réseau s'il existe, sinon un quart LIBRE du carrefour (contrôlé au moteur :
  -- falaise, eau, bâti ; arbres et rochers seront défrichés). Correction du 27/10 : le poteau tombait sur le bout d'une
  -- falaise (banc ia1-build-reseau).
  local surface = surface_of(f)
  local spots = {}
  local function spot_of(i, j)
    local k = P.lot_key(i, j)
    if spots[k] ~= nil then return spots[k] or nil end
    local net = b.net[k]
    if net and net.x then spots[k] = { x = net.x, y = net.y } return spots[k] end
    local base = P.node_pole(b.lat, i, j, big)
    local w = big and 2 or 1
    for _, d in ipairs({ { 0, 0 }, { 2, 0 }, { 0, 2 }, { 2, 2 } }) do
      -- quarts du carrefour (4 × 4) : grand poteau 2 × 2 décalé de 2, poteau moyen aux coins (décalé de 3)
      local x, y = base.x + d[1], base.y + d[2]
      if not big then x, y = base.x + d[1] * 1.5, base.y + d[2] * 1.5 end
      local area = { { x - w / 2 + 0.05, y - w / 2 + 0.05 }, { x + w / 2 - 0.05, y + w / 2 - 0.05 } }
      local ok = true
      for ty = math.floor(area[1][2]), math.floor(area[2][2]) do
        for tx = math.floor(area[1][1]), math.floor(area[2][1]) do if b.occ[P.tkey(tx, ty)] then ok = false end end
      end
      if ok and surface then
        if surface.count_tiles_filtered({ area = area, collision_mask = "water-tile", limit = 1 }) > 0 then ok = false end
        if ok then
          for _, e in ipairs(surface.find_entities_filtered({ area = area, collision_mask = "object-layer" })) do
            if e.type ~= "tree" and e.type ~= "simple-entity" and e.type ~= "character" then ok = false break end
          end
        end
      end
      if ok then spots[k] = { x = x, y = y } return spots[k] end
    end
    spots[k] = false
    return nil
  end
  -- Lot IA3-e : le carrefour le plus proche du module peut n'avoir aucun quart libre (rive, eau : la centrale) ; on prend
  -- le plus proche des carrefours voisins qui en a un (moteur réel, e3-usine, azure : centrale refusée « pas de rue vers
  -- le reseau » alors qu'elle amorçait le réseau, son carrefour étant dans l'eau).
  -- Lot IA3-e : le PREMIER réseau (la centrale) part d'un carrefour relié au QG par les rues : la centrale au bord de
  -- l'eau, son carrefour isolé par des rues fermées (eau), aucun module ne pouvait ensuite la rejoindre (moteur réel,
  -- e4-usine graine 271828182, emerald : 15 refus « pas de rue vers le reseau »).
  local first_net = next(b.net) == nil
  local function reach_hq(i, j)
    if not first_net then return true end
    return P.route_nodes({ i = i, j = j }, { i = 0, j = 0 }, seg_passable(b), b.radius) ~= nil
      or P.route_nodes({ i = i, j = j }, { i = 0, j = 0 }, seg_wire(b), b.radius) ~= nil
  end
  if not (spot_of(mi, mj) and reach_hq(mi, mj)) then
    local cands = {}
    for dj = -2, 2 do
      for di = -2, 2 do
        if di ~= 0 or dj ~= 0 then
          local n = P.node_pos(b.lat, mi + di, mj + dj)
          cands[#cands + 1] = { i = mi + di, j = mj + dj, d = (n.x - mp.x) ^ 2 + (n.y - mp.y) ^ 2 }
        end
      end
    end
    table.sort(cands, function(a, c) if a.d ~= c.d then return a.d < c.d end if a.j ~= c.j then return a.j < c.j end return a.i < c.i end)
    for _, c in ipairs(cands) do
      if spot_of(c.i, c.j) and reach_hq(c.i, c.j) then mi, mj = c.i, c.j break end
    end
  end
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
  -- route : rues praticables, à défaut par-dessus une rue fermée par une falaise (les fils passent ; correction du
  -- 27/10, banc ia1-build-reseau) ; un carrefour sans place pour son poteau est évité (3 essais)
  local bad = {}
  local function avoid(okf) return function(key)
    if not okf(key) then return false end
    local kind, i, j = P.parse_seg(key)
    if not kind then return true end
    local i2, j2 = i + (kind == "h" and 1 or 0), j + (kind == "v" and 1 or 0)
    return not bad[P.lot_key(i, j)] and not bad[P.lot_key(i2, j2)]
  end end
  local nodes
  for _ = 1, 4 do
    nodes = P.route_nodes({ i = mi, j = mj }, target, avoid(seg_passable(b)), b.radius)
    if not nodes then nodes = P.route_nodes({ i = mi, j = mj }, target, avoid(seg_wire(b)), b.radius) end
    if not nodes then break end
    local blocked
    for _, n in ipairs(nodes) do
      if not spot_of(n.i, n.j) then blocked = n break end
    end
    if not blocked then break end
    bad[P.lot_key(blocked.i, blocked.j)] = true
    nodes = nil
  end
  if not nodes then return nil, "pas de rue vers le reseau" end
  -- tuiles des poteaux déjà prévus ici (un poteau de liaison ne se pose pas sur un poteau de carrefour)
  local taken = {}
  local function take(e) for _, t in ipairs(P.tiles_of(e)) do taken[P.tkey(t[1], t[2])] = true end end
  local function free(x, y)
    local tx, ty = math.floor(x), math.floor(y)
    return masks.free(tx, ty) and not taken[P.tkey(tx, ty)] and not masks.clear[P.tkey(tx, ty)]
  end
  local prev
  for _, n in ipairs(nodes) do
    local k = P.lot_key(n.i, n.j)
    local pos = spot_of(n.i, n.j)
    n.x, n.y = pos.x, pos.y
    if not b.net[k] then
      local e = { name = pole, x = pos.x, y = pos.y, dir = 0, role = "reseau", node = k }
      out[#out + 1] = e
    end
    take({ name = pole, x = pos.x, y = pos.y, dir = 0 })
    -- poteaux de rue : moyens, ou grands quand deux carrefours décalés passent la portée
    local d2 = prev and ((prev.x - pos.x) ^ 2 + (prev.y - pos.y) ^ 2) or 0
    if prev and (not big or d2 > reach * reach - 1e-6) then
      local chain = P.pole_chain(prev, pos, big and reach or 9, big, free)
      if not chain then return nil, "poteaux de rue" end
      for _, c in ipairs(chain) do
        local e = { name = pole, x = c.x, y = c.y, dir = 0, role = "rue" }
        out[#out + 1] = e
        take(e)
      end
    end
    prev = pos
  end
  -- liaison du module au carrefour le plus proche (poteaux du gabarit : moyens)
  local npos = spot_of(mi, mj) or P.node_pole(b.lat, mi, mj, big)
  local link_reach = math.min(reach, P.wire(mp.name) or 9)
  local chain = P.pole_chain({ x = mp.x, y = mp.y }, npos, link_reach, false, free)
  if not chain then return nil, "liaison electrique" end
  for _, c in ipairs(chain) do
    local e = { name = mp.name, x = c.x, y = c.y, dir = 0, role = "liaison" }
    out[#out + 1] = e
    take(e)
  end
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

--- Lot IA3-e : un bras ÉLECTRIQUE de quai (tête d'alimentation, quai de sortie) hors de l'aire des poteaux du module ne
--- reçoit pas de courant (moteur réel, e5-usine, diagnostic : « inserter:no_power » aux quais, fours « no_fuel » faute du
--- bras du charbon) : un poteau moyen est ajouté sur une tuile libre voisine (le moteur le relie seul aux poteaux à portée).
local QUAI_ROLES = { ["quai-bras"] = true, ["sortie-bras"] = true }
local function covered_by(poles, e)
  for _, q in ipairs(poles) do
    -- aire d'alimentation du poteau (demi-côté) contre la boîte du bras (±0,15) : un bras à 4 tuiles d'un poteau moyen
    -- n'est PAS alimenté (moteur réel, e6-usine : bras de quai « no_power » sous des poteaux du réseau de la centrale)
    local sup = (q.name == "big-electric-pole") and 2 or ((q.name == "small-electric-pole") and 2.5 or 3.5)
    if math.abs(q.x - e.x) <= sup + 0.15 and math.abs(q.y - e.y) <= sup + 0.15 then return true end
  end
  return false
end
local function quai_poles(b, p, list, masks)
  local poles = {}
  for _, e in ipairs(p.ents) do if e.name:find("electric%-pole") then poles[#poles + 1] = e end end
  for _, e in ipairs(list) do if e.name:find("electric%-pole") then poles[#poles + 1] = e end end
  local planned = {}
  for _, e in ipairs(p.ents) do for _, t in ipairs(P.tiles_of(e)) do planned[P.tkey(t[1], t[2])] = true end end
  for _, e in ipairs(list) do for _, t in ipairs(P.tiles_of(e)) do planned[P.tkey(t[1], t[2])] = true end end
  local extra = {}
  for _, e in ipairs(list) do
    if QUAI_ROLES[e.role] and e.name ~= "burner-inserter" and not covered_by(poles, e) then
      local tx0, ty0 = math.floor(e.x), math.floor(e.y)
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }) do
        local tx, ty = tx0 + d[1], ty0 + d[2]
        local k = P.tkey(tx, ty)
        if not planned[k] and not b.occ[k] and (not masks or masks.free(tx, ty)) then
          local pole = { name = "medium-electric-pole", x = tx + 0.5, y = ty + 0.5, dir = 0, role = "quai-poteau", part = e.part }
          extra[#extra + 1] = pole
          poles[#poles + 1] = pole
          planned[k] = true
          break
        end
      end
    end
  end
  return extra
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
      -- centrale : bras À COMBUSTION au quai (correction du 27/10 : avec un bras électrique, pas de charbon sans courant
      -- ni de courant sans charbon, 0 kW au banc ia1-build-plaine) ; il se ravitaille avec le charbon qu'il porte
      local quai_ins = (g.gen == "steam") and "burner-inserter" or "inserter"
      local fd = P.feeder(port, sources, quai_ins)
      for _, e in ipairs(fd.entities) do e.part = part end
      if not reserve_tiles(b, p, fd.entities) then return false, "tete d'alimentation" end
      if quai_ins ~= "burner-inserter" then
        local qp = quai_poles(b, p, fd.entities, place.masks)
        if #qp > 0 and not reserve_tiles(b, p, qp) then return false, "poteau de quai" end
      end
      for _, c in ipairs(fd.chests) do p.quais[#p.quais + 1] = { x = c.x, y = c.y, item = c.item } end
      for _, a in ipairs(fd.arrivals) do
        local d = drills[a.lane]
        if d then
          local ok, why = Build.plan_drills(f, surface, p, d.item, d.flow, a)
          if not ok then
            -- repli : quai sur cette voie (le tapis n'a pas pu être tracé ou le gisement manque)
            bump(b.stats.plan_refused, "tapis:" .. tostring(why))
            local alt = P.feeder(port, { a.lane == 1 and "quai" or nil, a.lane == 2 and "quai" or nil }, quai_ins)
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
      local qp = quai_poles(b, p, q, place.masks)
      if #qp > 0 and not reserve_tiles(b, p, qp) then return false, "poteau de quai" end
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
    -- second essai, marge d'un pas de treillis (contourner une falaise par la brèche voisine ; correction du 27/10)
    local cx0, cy0 = math.min(s.x, a.x) - P.PITCH, math.min(s.y, a.y) - P.PITCH
    local cx1, cy1 = math.max(s.x, a.x) + P.PITCH, math.max(s.y, a.y) + P.PITCH
    if cx1 - cx0 <= 120 and cy1 - cy0 <= 120 then
      local m2 = read_masks(f, surface, cx0, cy0, cx1 + 1, cy1 + 1)
      masks.water, masks.blocked, masks.clear = m2.water, m2.blocked, m2.clear
      tiles, n2 = P.belt_route(s, { x = a.x, y = a.y }, a.dir, { x0 = cx0, y0 = cy0, x1 = cx1, y1 = cy1 }, cost)
    end
  end
  if not tiles then
    p.parts[part] = nil
    return false, n2
  end
  for _, t in ipairs(tiles) do ents[#ents + 1] = { name = "transport-belt", x = t.x + 0.5, y = t.y + 0.5, dir = t.dir, part = part, role = "liaison-tapis" } end
  if not reserve_tiles(b, p, ents) then p.parts[part] = nil; return false, "place" end
  b.lots[place.lot].used = p.id
  return true
end

--- Tuile libre pour un point d'appui, au plus près de (x, y) : ni réservée par un projet (emprise d'une entité
--- planifiée, de cette équipe), ni eau, ni bâtie (relevé `masks`, quand il couvre la tuile), ni arbre (`trees`) ; de
--- préférence avec ses 8 voisines libres (le PNJ s'arrête à une tuile près du point). Anneaux de Chebyshev de rayon 0 à
--- Build.ANCHOR_SEARCH, ordre fixe (distance, puis y, puis x). Rend le centre de la tuile ; à défaut une tuile libre
--- sous un arbre ; sans tuile libre, le point tel quel.
local function free_spot(b, masks, x, y, trees)
  local function free(tx, ty, wood)
    local k = P.tkey(tx, ty)
    if b.occ[k] then return false end
    if masks and (masks.water[k] or masks.blocked[k]) then return false end
    if not wood and ((trees and trees[k]) or (masks and masks.clear and masks.clear[k])) then return false end
    return true
  end
  local function clear3(tx, ty)
    for dy = -1, 1 do for dx = -1, 1 do if not free(tx + dx, ty + dy) then return false end end end
    return true
  end
  local x0, y0 = math.floor(x), math.floor(y)
  local fallback, fallback2
  for r = 0, Build.ANCHOR_SEARCH do
    local ring = {}
    for dy = -r, r do
      for dx = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r then ring[#ring + 1] = { dx, dy } end
      end
    end
    table.sort(ring, function(u, v)
      local du, dv = u[1] * u[1] + u[2] * u[2], v[1] * v[1] + v[2] * v[2]
      if du ~= dv then return du < dv end
      if u[2] ~= v[2] then return u[2] < v[2] end
      return u[1] < v[1]
    end)
    for _, d in ipairs(ring) do
      local tx, ty = x0 + d[1], y0 + d[2]
      if clear3(tx, ty) then return tx + 0.5, ty + 0.5 end
      if not fallback and free(tx, ty) then fallback = { tx + 0.5, ty + 0.5 } end
      if not fallback2 and free(tx, ty, true) then fallback2 = { tx + 0.5, ty + 0.5 } end
    end
  end
  if fallback then return fallback[1], fallback[2] end
  if fallback2 then return fallback2[1], fallback2[2] end
  return x, y
end

--- Arbres et rochers sur l'emprise de TOUTES les entités d'un projet (un appel sur leur boîte englobante, au plan) :
--- { [tuile] = true }. Correction du 27/10 : seul le relevé du module principal était lu, et les arbres sous les
--- foreuses et leur tapis n'étaient découverts qu'à la pose (banc ia1-build-foret).
local STRETCHED = { reseau = true, rue = true, liaison = true, ["liaison-tapis"] = true }

local function wood_of(surface, ents)
  -- une boîte par pièce compacte (module, foreuses, têtes) ; entité par entité pour ce qui s'étire (poteaux de rue et de
  -- liaison, tapis de liaison) : un seul appel sur la boîte de tout le projet coûtait jusqu'à 68 ms en forêt (27/10)
  local boxes, order = {}, {}
  local out = {}
  local function mark(area)
    for _, t in ipairs(surface.find_entities_filtered({ area = area, type = TREE_TYPES })) do
      local bb = t.bounding_box
      for ty = math.floor(bb.left_top.y + 0.01), math.ceil(bb.right_bottom.y - 0.01) - 1 do
        for tx = math.floor(bb.left_top.x + 0.01), math.ceil(bb.right_bottom.x - 0.01) - 1 do out[P.tkey(tx, ty)] = true end
      end
    end
  end
  for _, e in ipairs(ents) do
    local w, h = P.size(e.name, e.dir)
    if STRETCHED[e.role or ""] then
      mark({ { e.x - w / 2 - 1, e.y - h / 2 - 1 }, { e.x + w / 2 + 1, e.y + h / 2 + 1 } })
    else
      local k = e.part or 0
      local bx = boxes[k]
      if not bx then bx = { math.huge, math.huge, -math.huge, -math.huge }; boxes[k] = bx; order[#order + 1] = k end
      bx[1], bx[2] = math.min(bx[1], e.x - w / 2), math.min(bx[2], e.y - h / 2)
      bx[3], bx[4] = math.max(bx[3], e.x + w / 2), math.max(bx[4], e.y + h / 2)
    end
  end
  table.sort(order)
  for _, k in ipairs(order) do
    local bx = boxes[k]
    mark({ { bx[1] - 1, bx[2] - 1 }, { bx[3] + 1, bx[4] + 1 } })
  end
  return out
end

--- Ajoute un obstacle au projet (une fois par tuile).
local function add_obstacle(p, o)
  local k = P.tkey(math.floor(o.x), math.floor(o.y))
  p.obst_keys = p.obst_keys or {}
  if p.obst_keys[k] then
    for _, q in ipairs(p.obstacles) do if q.k == k then q.done = nil end end
    return
  end
  p.obst_keys[k] = true
  o.k = k
  p.obstacles[#p.obstacles + 1] = o
end

--- Revue de Build.OBST_CHECKS obstacles ouverts (à tour de rôle) : faits quand plus aucun arbre ni rocher n'y est.
--- Rend le nombre d'obstacles encore ouverts.
local function review_obstacles(surface, p)
  local n, left = #p.obstacles, 0
  if n == 0 then return 0 end
  local checked = 0
  p.obst_cur = p.obst_cur or 1
  for _ = 1, n do
    if p.obst_cur > n then p.obst_cur = 1 end
    local o = p.obstacles[p.obst_cur]
    p.obst_cur = p.obst_cur + 1
    if not o.done then
      if checked < Build.OBST_CHECKS then
        checked = checked + 1
        if surface.count_entities_filtered({ area = { { o.x - 0.45, o.y - 0.45 }, { o.x + 0.45, o.y + 0.45 } }, type = TREE_TYPES, limit = 1 }) == 0 then
          o.done = true
        else
          left = left + 1
        end
      else
        left = left + 1
      end
    end
  end
  return left
end

--- Plan d'un projet : (true) ou (false, raison, attendre). Une seule pensée de plan par passe.
local function plan_project(f, surface, p)
  local b = f.build
  local spec = p.spec
  Profiler.start("build:plan:place") -- lot IA3-e : parts du coût d'un plan (pics de K10), mesure seulement
  local g, why = template_of(spec)
  if not g then return false, why end
  local main
  local is_plant = g.gen == "steam"
  local toward
  if spec.near then toward = spec.near end
  if is_plant then
    main, why = place_module(f, surface, g, { rive = true, eau = true }, toward or { x = b.lat.ox, y = b.lat.oy }, nil, { water = true, margin = 0 })
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
  Profiler.stop("build:plan:place")
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
    Profiler.start("build:plan:feed")
    local ok, w2 = plan_feed(f, surface, p, main, 1)
    Profiler.stop("build:plan:feed")
    if not ok then return false, w2 end
  end
  Profiler.start("build:plan:power")
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
          -- relevé autour de CE module (eau, bâtiments, arbres) jusqu'aux carrefours voisins
          local pm = idx == 1 and masks or read_masks(f, surface, pt.ox - 32, pt.oy - 32, pt.ox + pt.w + 32, pt.oy + pt.h + 32)
          local extra, w3, nodes = plan_power(f, p, mp, pm)
          if not extra then return false, w3 end
          if not reserve_tiles(b, p, extra) then return false, "poteaux" end
          for _, n in ipairs(nodes or {}) do
            local k = P.lot_key(n.i, n.j)
            if not b.net[k] then b.net[k] = { i = n.i, j = n.j, pid = p.id, x = n.x, y = n.y } end
          end
        end
      end
    end
  end
  Profiler.stop("build:plan:power")
  if is_plant then b.plant = p.id end
  Profiler.start("build:plan:anchors")
  -- points d'appui : sur une rue praticable à 16 tuiles au plus, sinon au centre de la case de 8 × 8 ; dans les deux
  -- cas déplacés sur une tuile LIBRE (correction du 27/10 : le repli tombait sur l'emprise de la chaudière, et le PNJ
  -- bâtisseur, debout dessus, en empêchait la pose : banc ia1-build-plaine, 25/10)
  local passable = seg_passable(b)
  local wood = wood_of(surface, p.ents)
  for _, e in ipairs(p.ents) do
    local a = P.anchor_for(b.lat, e.x, e.y, passable)
    local ax, ay
    if a then ax, ay = a.x, a.y
    else ax, ay = math.floor(e.x / 8) * 8 + 4, math.floor(e.y / 8) * 8 + 4 end
    local fx, fy = free_spot(b, masks, ax, ay, wood)
    if (fx - e.x) * (fx - e.x) + (fy - e.y) * (fy - e.y) > REACH * REACH then fx, fy = free_spot(b, masks, e.x, e.y, wood) end
    e.ax, e.ay = fx, fy
    e.anchor = string.format("%s%g:%g", a and "" or "c", fx, fy)
    e.item = item_of(e.name)
  end
  P.sort_build(p.ents)
  -- obstacles à défricher sous les entités planifiées (toutes les pièces du projet)
  p.obstacles, p.obst_keys = {}, {}
  for _, e in ipairs(p.ents) do
    for _, t in ipairs(P.tiles_of(e)) do
      local k = P.tkey(t[1], t[2])
      if masks.clear[k] or wood[k] then add_obstacle(p, { x = t[1] + 0.5, y = t[2] + 0.5, anchor = e.anchor, ax = e.ax, ay = e.ay }) end
    end
  end
  for _, pt in ipairs(p.parts) do if pt then b.stats.modules_started = b.stats.modules_started + 1 end end
  Profiler.stop("build:plan:anchors")
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

--- Stock LIBRE du coffre (lot IA3-e) : le coffre moins ce que les tâches prises y ont réservé (registre d'IA3-b,
--- Board.view_stock ; registre éteint : le coffre tel quel). Le chantier ne prend plus la matière promise à une tâche
--- (critère K4 : 0 échec « stock »).
local function free_stock(f)
  return Board.view_stock(f, f.hq.get_inventory(defines.inventory.chest).get_contents(), game.tick)
end

local function reserve(f, p)
  local need = needs_of(p)
  local missing = {}
  local free = free_stock(f)
  for _, it in ipairs(sorted_keys(need)) do
    local want = need[it] - (p.stock[it] or 0)
    if want > 0 then
      local have = math.min(f.hq.get_item_count(it), free[it] or 0)
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

--- Lot IA3-e : annule une demande pas encore en chantier (attente, plan, réserve) : objets réservés rendus au coffre,
--- tuiles et lots libérés ; état « refuse » (raison donnée). Rend vrai si la demande a été annulée.
function Build.cancel(f, id, why)
  local b = f and f.build
  local p = b and b.projects[id]
  if not (p and (p.state == "attente" or p.state == "plan" or p.state == "reserve")) then return false end
  release(f, p)
  for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
  for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
  for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
  p.ents, p.parts = {}, {}
  p.state, p.reason = "refuse", why or "annule"
  b.stats.projects_refused = b.stats.projects_refused + 1
  if b.plant == p.id then b.plant = nil end
  log(string.format("[FO-IA1D] %s : projet %d annule (%s)", f.key or "player", p.id, tostring(p.reason)))
  return true
end

--- Prise au stock du chantier (étape « take_res » d'un PNJ) : rend vrai si tout a été pris.
function Build.take_reserved(f, pid, items, inv)
  local p = f.build and f.build.projects[pid]
  if not p then return false end
  local all = true
  local free = nil
  for _, it in ipairs(items) do
    local want = it[2]
    local have = p.stock[it[1]] or 0
    if have < want then
      -- complément au coffre (un PNJ a pu rapporter des objets) : sur le stock LIBRE seulement (lot IA3-e, K4)
      free = free or free_stock(f)
      local add = math.min(want - have, f.hq.get_item_count(it[1]), free[it[1]] or 0)
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

--- Ce qui occupe l'emprise d'une entité planifiée (journal d'un refus) : entités triées, tuiles d'eau.
local function blockers(surface, e)
  local w, h = P.size(e.name, e.dir)
  local area = { { e.x - w / 2 + 0.05, e.y - h / 2 + 0.05 }, { e.x + w / 2 - 0.05, e.y + h / 2 - 0.05 } }
  local out = {}
  for _, x in ipairs(surface.find_entities_filtered({ area = area })) do
    out[#out + 1] = string.format("%s%s %s (%.2f, %.2f) dir %d", x.name, x.name == "entity-ghost" and ("/" .. x.ghost_name) or "",
      x.force.name, x.position.x, x.position.y, x.direction or 0)
  end
  table.sort(out)
  local wet = surface.count_tiles_filtered({ area = area, collision_mask = "water-tile" })
  return (#out > 0 and table.concat(out, ", ") or "rien") .. " ; eau " .. wet .. " tuile(s)"
end

local function log_refusal(f, p, e, why, surface)
  local st = f.build.stats
  st.refusal_logs = (st.refusal_logs or 0) + 1
  if st.refusal_logs > Build.REFUSAL_LOGS then return end
  log(string.format("[FO-IA1D] %s : projet %d, fantome refuse (%s) : %s en (%g, %g) dir %d ; emprise : %s", f.key or "player",
    p and p.id or 0, why, e.name, e.x, e.y, e.dir or 0, blockers(surface, e)))
end

--- Emprise d'une entité planifiée, rognée de 0,05 (les voisins qui la touchent ne comptent pas, F96).
local function footprint(e)
  local w, h = P.size(e.name, e.dir)
  return { { e.x - w / 2 + 0.05, e.y - h / 2 + 0.05 }, { e.x + w / 2 - 0.05, e.y + h / 2 - 0.05 } }
end

--- Un personnage (PNJ, joueur) debout sur l'emprise : refus passager.
local function npc_on(surface, e)
  -- Lot IA3-e : un SOLDAT (unité) debout sur l'emprise est aussi un passager (moteur réel, e2-usine : fantômes d'emerald
  -- refusés « occupe » par fo-emerald-rifleman et fo-emerald-rocketeer, chantier bloqué près du QG).
  return surface.count_entities_filtered({ area = footprint(e), type = { "character", "unit" }, limit = 1 }) > 0
end

--- Pose le fantôme d'une entité planifiée : "ok", "deja" (bâtie), "obstacle" (arbre, rocher), "pnj" (un personnage
--- debout dessus, passager), "occupe" (autre).
local function place_ghost(surface, f, e)
  if find_real(surface, e, f.force) then return "deja" end
  if find_ghost(surface, e, f.force) then return "ok" end
  if not surface.can_place_entity({ name = e.name, position = { e.x, e.y }, direction = e.dir, force = f.force,
    build_check_type = defines.build_check_type.ghost_revive }) then
    local area = footprint(e)
    if surface.count_entities_filtered({ area = area, type = TREE_TYPES, limit = 1 }) > 0 then return "obstacle" end
    if npc_on(surface, e) then return "pnj" end
    return "occupe"
  end
  local gh = surface.create_entity({ name = "entity-ghost", inner_name = e.name, position = { e.x, e.y }, direction = e.dir,
    force = f.force, expires = false })
  if not gh then return "occupe" end
  return "ok"
end

--- Refus passager (un personnage sur l'emprise) : compté à part ; Build.NPC_BLOCKS_PER_FAIL refus valent un échec.
local function npc_block(f, p, e, surface)
  local st = f.build.stats
  st.npc_blocks = (st.npc_blocks or 0) + 1
  e.npc_blocks = (e.npc_blocks or 0) + 1
  if e.npc_blocks % Build.NPC_BLOCKS_PER_FAIL == 0 then e.fails = (e.fails or 0) + 1 end
  log_refusal(f, p, e, "pnj", surface)
end

--- Ravive (ou pose puis ravive) une entité planifiée avec l'objet porté par le PNJ `self` : true si bâtie. Une
--- entité sous les pieds du bâtisseur lui-même est laissée (ni essai, ni échec) : un autre passage la fera.
local function revive_one(surface, f, p, e, inv, tick, self)
  local st = f.build.stats
  if find_real(surface, e, f.force) then e.built = true return true end
  if not e.item or inv.get_item_count(e.item) < 1 then return false end
  if self and self.valid then
    local a, q = footprint(e), self.position
    if q.x > a[1][1] - 0.3 and q.x < a[2][1] + 0.3 and q.y > a[1][2] - 0.3 and q.y < a[2][2] + 0.3 then
      st.self_skips = (st.self_skips or 0) + 1
      return false
    end
  end
  local gh = find_ghost(surface, e, f.force)
  if not gh then
    local r = place_ghost(surface, f, e)
    if r == "deja" then e.built = true return true end
    if r == "pnj" then npc_block(f, p, e, surface) return false end
    if r ~= "ok" then
      e.fails = (e.fails or 0) + 1
      st.revive_fail = st.revive_fail + 1
      log_refusal(f, p, e, r, surface)
      if r == "obstacle" then add_obstacle(p, { x = e.x, y = e.y, anchor = e.anchor, ax = e.ax, ay = e.ay }) end
      return false
    end
    st.ghosts = st.ghosts + 1
    gh = find_ghost(surface, e, f.force)
    if not gh then
      e.fails = (e.fails or 0) + 1
      st.revive_fail = st.revive_fail + 1
      log_refusal(f, p, e, "fantome pose mais introuvable", surface)
      return false
    end
  end
  inv.remove({ name = e.item, count = 1 })
  local _, ent = gh.revive({ raise_revive = true })
  if not (ent and ent.valid) then
    inv.insert({ name = e.item, count = 1 })
    if npc_on(surface, e) then npc_block(f, p, e, surface) return false end
    e.fails = (e.fails or 0) + 1
    st.revive_fail = st.revive_fail + 1
    log_refusal(f, p, e, "ravivage refuse", surface)
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
-- Travail d'un PNJ sur place (état « ia1d » de script/team/worker.lua) : "more", "done", "fail", ou "again" (refaire la
-- marche vers le point d'appui depuis la position atteinte)
---------------------------------------------------------------------------------------------------
--- PNJ arrêté en route (forêt dense) : il coupe les arbres et rochers du couloir (demi-largeur Build.CUT_WIDTH) qui
--- mène à son point d'appui, à sa portée. Rend le nombre coupé, ou nil (jetons épuisés ou limite de la pensée : à
--- reprendre). Correction du 27/10, banc ia1-build-foret.
local function cut_toward(f, agent, job, pos, inv, tick, reach2)
  local e = agent.entity
  local surface = e.surface
  local b = f.build
  local dx, dy = job.ax - pos.x, job.ay - pos.y
  local l2 = dx * dx + dy * dy
  local near = surface.find_entities_filtered({ area = { { pos.x - REACH, pos.y - REACH }, { pos.x + REACH, pos.y + REACH } }, type = TREE_TYPES })
  table.sort(near, function(a, c)
    local da, dc = dist2(a.position, pos), dist2(c.position, pos)
    if da ~= dc then return da < dc end
    if a.position.x ~= c.position.x then return a.position.x < c.position.x end
    return a.position.y < c.position.y
  end)
  local cut = 0
  for _, t in ipairs(near) do
    local tx, ty = t.position.x - pos.x, t.position.y - pos.y
    local u = (tx * dx + ty * dy) / l2
    local px, py = tx - u * dx, ty - u * dy
    if u > 0 and u <= 1 and px * px + py * py <= Build.CUT_WIDTH * Build.CUT_WIDTH and dist2(t.position, pos) <= reach2 then
      if cut >= Build.CLEAR_PER_THINK then return nil end
      if not Tokens.take(f, tick, Build.COST_EVAL) then return nil end
      if not t.mine({ inventory = inv, force = e.force, raise_destroyed = true }) and t.valid then t.destroy({ raise_destroy = true }) end
      cut = cut + 1
      b.stats.cleared = b.stats.cleared + 1
      b.stats.cut = (b.stats.cut or 0) + 1
    end
  end
  return cut
end

--- Point d'appui pas atteint : couper le couloir, puis refaire la marche (Build.CUT_TRIES fois par tâche au plus).
local function not_there(f, agent, job, pos, inv, tick, reach2, give_up)
  local cut = cut_toward(f, agent, job, pos, inv, tick, reach2)
  if cut == nil or cut > 0 then return "more" end
  local t = agent.task
  if t and (t.cut_tries or 0) < Build.CUT_TRIES then
    t.cut_tries = (t.cut_tries or 0) + 1
    return "again"
  end
  return give_up
end

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
            if revive_one(surface, f, p, x, inv, tick, e) then
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
    if (job.done or 0) == 0 and job.ax and dist2({ x = job.ax, y = job.ay }, pos) > 16 then
      return not_there(f, agent, job, pos, inv, tick, reach2, "fail")
    end
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
    -- rien à portée dans la zone (PNJ arrêté en route, forêt dense) : il s'ouvre le couloir vers son point d'appui,
    -- puis refait la marche (correction du 27/10, banc ia1-build-foret)
    if did == 0 and remain == 0 and job.ax and dist2({ x = job.ax, y = job.ay }, pos) > 16 then
      return not_there(f, agent, job, pos, inv, tick, reach2, "done")
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
--- Mémoire des arbres de parcours des rues, par équipe, valable pour une version des tronçons (b.seg_ver) et un rayon.
--- HORS de global : c'est une simple mémoire d'un calcul pur (P.route_tree), vide au chargement et recalculée au
--- besoin, au même résultat (27/10 : 1,7 ms par marche sans elle, hors jeu).
local ROUTES = {}
-- Lot IA3-e : le compte des mémoires refaites reste LOCAL (une mesure) : écrit dans global, il différait entre une partie
-- continue et la même partie rechargée (la mémoire, locale, est refaite après le chargement) ; moteur simulé, pvp_test
-- « partie continue = partie rechargée », 2 ECHEC dès que les factions ont un plan directeur.
local ROUTE_RESETS = {}
local function route_cache(f)
  local b = f.build
  local key = f.key or "player"
  local ver = tostring(b.seg_ver or 0) .. ":" .. tostring(b.radius)
  local c = ROUTES[key]
  if not c or c.ver ~= ver then
    c = { ver = ver, trees = {} }
    ROUTES[key] = c
    ROUTE_RESETS[key] = (ROUTE_RESETS[key] or 0) + 1
  end
  return c.trees
end

function Build.street_route(f, p, q)
  local b = f.build
  if not b or b.radius == 0 then return nil end
  local lim = (b.radius + 0.5) * P.PITCH
  if math.abs(p.x - b.lat.ox) > lim or math.abs(p.y - b.lat.oy) > lim then return nil end
  if math.abs(q.x - b.lat.ox) > lim or math.abs(q.y - b.lat.oy) > lim then return nil end
  b.stats.route_calls = (b.stats.route_calls or 0) + 1
  local wp = P.street_path(b.lat, p, q, seg_ok(b), b.radius, route_cache(f))
  if not wp then b.stats.route_nil = (b.stats.route_nil or 0) + 1 return nil end
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
        local a = P.anchor_for(f.build.lat, q.x, q.y, seg_passable(f.build))
        if not a then local fx, fy = free_spot(f.build, nil, q.x, q.y); a = { x = fx, y = fy } end
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
        local a = P.anchor_for(f.build.lat, o.x, o.y, seg_passable(f.build))
        if not a then local fx, fy = free_spot(f.build, nil, o.x, o.y); a = { x = fx, y = fy } end
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
  -- liaisons de cuivre des poteaux du projet (le moteur relie lui-même un poteau ravivé à ses voisins : les fils
  -- AJOUTÉS ci-dessus ne comptent que les trous)
  local links, idx = 0, {}
  for i, ent in ipairs(poles) do idx[ent.unit_number] = i end
  for a = 1, #poles do
    for _, nb in ipairs((poles[a].neighbours or {}).copper or {}) do
      if nb.valid and idx[nb.unit_number] and idx[nb.unit_number] > a then links = links + 1 end
    end
  end
  p.links = links
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
    Profiler.start("build:plan")
    local ok, why, wait = plan_project(f, surface, p)
    Profiler.stop("build:plan")
    -- lot IA3-e : minuteurs des parties arrêtés aussi après un retour anticipé du plan (refus, attente)
    Profiler.stop("build:plan:place"); Profiler.stop("build:plan:feed"); Profiler.stop("build:plan:power"); Profiler.stop("build:plan:anchors")
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
    -- lot IA3-e : une réserve incomplète n'est relue qu'une fois par seconde (elle relisait le coffre et le registre
    -- toutes les 5 ticks : chantiers des factions en attente de matériaux pendant des dizaines de minutes, K10)
    if p.reserve_next and tick < p.reserve_next then return end
    -- lot IA3-e : la raison « materiaux » est effacée quand la réserve est complète (elle restait affichée au chantier)
    if reserve(f, p) then
      p.state, p.reason, p.reserve_next = #p.obstacles > 0 and "defrichage" or "fantomes", nil, nil
    else
      p.reason, p.reserve_next = "materiaux", tick + 60
    end
    return
  end
  if p.state == "defrichage" then
    if review_obstacles(surface, p) == 0 then p.state = "fantomes" end
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
          add_obstacle(p, { x = e.x, y = e.y, anchor = e.anchor, ax = e.ax, ay = e.ay })
          e.ghosted = true
        elseif r == "pnj" then
          e.ghosted = true -- posé au ravivage (revive_one)
          npc_block(f, p, e, surface)
        else
          e.ghosted = true
          e.fails = (e.fails or 0) + 1
          b.stats.ghost_refused = b.stats.ghost_refused + 1
          log_refusal(f, p, e, r, surface)
        end
      end
    end
    if pending == 0 then p.state = "chantier" end
    return
  end
  if p.state == "chantier" then
    review_obstacles(surface, p)
    if all_built(p) then
      p.state = "raccordement"
    else
      -- 3 refus d'un même fantôme : le module est bloqué (raison écrite), §6.6 (4)
      for _, e in ipairs(p.ents) do
        if not e.built and (e.fails or 0) >= Build.FAIL_LIMIT * 2 then
          p.state, p.reason = "bloque", "fantome refuse (" .. e.name .. " en " .. e.x .. "," .. e.y .. ")"
          b.stats.projects_blocked = b.stats.projects_blocked + 1
          p.retries = (p.retries or 0) + 1
          p.retry_at = p.retries <= Build.RETRIES and (tick + Build.RETRY_TICKS) or nil
          log(string.format("[FO-IA1D] %s : projet %d bloque : %s%s", f.key or "player", p.id, p.reason,
            p.retry_at and string.format(" ; reprise %d/%d a %.1f min", p.retries, Build.RETRIES, p.retry_at / 3600) or " ; abandon"))
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
    -- projet bloqué : il a rendu ses PNJ ; il reprend son chantier à l'heure dite (échecs remis à zéro)
    if p and p.state == "bloque" and p.retry_at and tick >= p.retry_at then
      p.retry_at = nil
      for _, e in ipairs(p.ents) do if not e.built then e.fails, e.npc_blocks = 0, 0 end end
      p.state, p.reason = "chantier", nil
      log(string.format("[FO-IA1D] %s : projet %d reprend son chantier a %.1f min", f.key or "player", p.id, tick / 3600))
    end
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
    if f.hq and f.hq.valid then
      Profiler.start("build:pulse")
      pulse_team(f, e.tick)
      Profiler.stop("build:pulse")
    end
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
  -- quais d'entrée : contenu lu au moteur (le cerveau sait ce qui manque ; le banc sait quand renvoyer l'équipe)
  local quais = {}
  local surface = surface_of(f)
  for _, q in ipairs(p.quais) do
    local chest = surface and surface.find_entity("iron-chest", { q.x, q.y })
    quais[#quais + 1] = { x = q.x, y = q.y, item = q.item, count = chest and chest.get_item_count(q.item) or -1 }
  end
  -- entités pas encore bâties (5 au plus, dans l'ordre de pose) : ce qui retient un chantier
  local unbuilt = {}
  for _, e in ipairs(p.ents) do
    if not e.built and #unbuilt < 5 then
      unbuilt[#unbuilt + 1] = { name = e.name, x = e.x, y = e.y, fails = e.fails or 0, npc = e.npc_blocks or 0, anchor = e.anchor }
    end
  end
  local open_obst = 0
  for _, o in ipairs(p.obstacles or {}) do if not o.done then open_obst = open_obst + 1 end end
  return { id = p.id, state = p.state, reason = p.reason, built = count_built(p), total = #p.ents, parts = parts,
    unbuilt = unbuilt, open_obstacles = open_obst,
    obstacles = #p.obstacles, quais = quais, outs = #p.outs, missing = missing, created = p.created, started = p.started,
    finished = p.finished, wires = p.wired, links = p.links, retry_at = p.retry_at, retries = p.retries }
end

--- Lot IA3-e : état court d'une demande, SANS appel du moteur (lu à chaque pensée par le cerveau ; Build.status relit les
--- quais au moteur) : { state, reason, missing, built, total, retry_at, retries, parts }.
function Build.brief(f, id)
  local p = f and f.build and f.build.projects[id]
  if not p then return nil end
  local missing = {}
  for _, m in ipairs(p.missing or {}) do missing[#missing + 1] = { m[1], m[2] } end
  local parts = {}
  for i = 1, #p.parts do
    local pt = p.parts[i]
    if pt then parts[#parts + 1] = { kind = pt.kind, key = pt.key, x = pt.ox, y = pt.oy, w = pt.w, h = pt.h } end
  end
  -- objets des quais d'entrée (lot IA3-e : un module fini se nourrit DEPUIS LE COFFRE du QG, quai_tasks)
  local quais, seen = {}, {}
  for _, q in ipairs(p.quais or {}) do
    if q.item and not seen[q.item] then seen[q.item] = true; quais[#quais + 1] = q.item end
  end
  return { state = p.state, reason = p.reason, missing = missing, built = count_built(p), total = #p.ents,
    retry_at = p.retry_at, retries = p.retries, parts = parts, quais = quais }
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
    cleared = st.cleared, filled = st.filled, collected = st.collected, npc_blocks = st.npc_blocks or 0,
    route_calls = st.route_calls or 0, route_nil = st.route_nil or 0, route_resets = ROUTE_RESETS[f.key or "player"] or 0,
    self_skips = st.self_skips or 0,
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
