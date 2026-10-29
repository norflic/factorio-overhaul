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
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Board = require("script.team.board")
local Tokens = require("script.team.tokens")
local Profiler = require("script.core.profiler")
local Foot = require("shared.levels.footprint")
local P = require("shared.team.plan")
local M = require("shared.team.modules")
local Fonte = require("shared.team.fonte") -- lot FONDERIES : équilibre entre l'entrée des foreuses et les fours (règle pure)
local Li = require("shared.team.ligne")       -- lot AGENCEMENT : fonderie en longue ligne extensible (règles pures)
local Rg = require("shared.team.rangees")     -- lot AGENCEMENT : foreuses en rangées qui couvrent le gisement (règles pures)
local Conv = require("script.team.convoyeurs") -- lot CONVOYEURS : tapis selon la technologie
local T = require("shared.team.config")      -- lot ESPACE : nom du mur de l'enceinte (T.wall)
local Mq = require("shared.team.masques")   -- lot POTEAUX-MASQUES : relevé paresseux des masques par chunk (règles pures)
local Blocage = require("shared.team.blocage") -- lot FACTIONS-BLOQUEES : tourelle sur un chantier, projet sans progrès (règles pures)
local Enc = require("shared.team.enceinte")  -- lot ESPACE : croissance et enceinte (règles pures)
local PlantArms = require("script.team.plant_arms") -- lot PLANDIR : moniteur de la centrale (journal)
local Rv = require("script.team.reseau_vivant") -- lot CORR-RESEAU : santé de la centrale et du réseau après « fini »
local Outposts = require("script.faction.outposts") -- lot AUTO : crochet des tuiles réservées (Outposts.reserved)

local Build = {}

Build.RADIUS = 3              -- carré de lots évalué au départ (7 × 7)
Build.RADIUS_MAX = 5
P.declare_size(T.wall, 1, 1)  -- lot ESPACE : emprise du mur, connue dès le chargement (les PNJ la lisent avant tout plan)
Build.PULSE = 5               -- ticks entre deux passes de travail
Build.NET_WAIT_TICKS = 1800   -- lot PLANDIR : attente (30 s) entre deux essais d'un projet dont le réseau passe par un projet pas bâti
Build.NET_WAIT_MAX = 40       -- au plus 40 essais (20 min) avant le refus
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
-- Étape 1 / électrification (27/10 au soir, banc etape1-guide, Azure : matière du module de fonderie réunie à 38 min, puis
-- 72 obstacles défrichés par 4 PNJ au plus à la priorité 59, sous les packs (85), les kits et les chargeurs (70 à 85) : le
-- module n'a fini qu'à 46 min) : une tâche de chantier n'existe qu'une fois la matière du projet RÉUNIE (état défrichage,
-- fantômes ou chantier) ; elle termine un investissement déjà payé et passe devant la fabrication d'avance.
Build.FINISH_BONUS = 30
Build.FINISH_CAP = 89         -- … sans jamais atteindre l'urgence (90 : O.URGENT_PRIO, M.URGENT)
local function finish_prio(base) return math.min(base + Build.FINISH_BONUS, Build.FINISH_CAP) end
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
  -- lot ESPACE : le rayon est figé par l'enceinte (un lot posé après l'anneau serait dehors, ou l'anneau couperait un lot)
  if b.enc then r = math.min(r, b.enc.r) end
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

--- Lot ESPACE : le treillis peut-il encore grandir ? (rayon maximal ou enceinte : non). Les replans qui attendent une
--- croissance s'y réfèrent, sinon ils attendraient pour toujours un rayon figé.
function Build.can_grow(b) return b.radius < Build.RADIUS_MAX and not b.enc end

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
    -- Lot AUTO : un lot de GISEMENT qui porte déjà nos bâtiments (avant-poste à combustion posé sur le minerai par le
    -- cerveau) restait « occupe » : ses tuiles libres de minerai n'étaient plus proposées aux foreuses électriques
    -- (« tapis des foreuses (pas de lot) »). Il reste un gisement PARTAGÉ : P.fit n'y pose rien sur une tuile bâtie
    -- (masque `free`), la couverture de minerai (P.DRILL_COVER) se compte sur ce qui reste. Le lot du QG reste occupé.
    local ore, n_ore = P.main_resource(s)
    l.ore, l.ore_n = ore, n_ore
    if l.state == "occupe" and not (l.i == 0 and l.j == 0) and ore and n_ore >= P.MIN_RES_TILES then
      l.state, l.reason, l.shared = "gisement", ore, true
    end
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
    rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }, -- lot POTEAUX-MASQUES : où ce relevé fait foi (Mq.view)
    free = function(tx, ty)
      local k = P.tkey(tx, ty)
      return not water[k] and not blocked[k] and not b.occ[k]
    end,
  }
end

--- Lot POTEAUX-MASQUES : cache LOCAL (jamais dans global, vide à chaque chargement) des relevés par chunk, par surface.
--- Écrit par masques_view, invalidé par finish_project (Mq.invalidate) et par la péremption (Mq.TTL) ; lu par masques_view seul.
local MASQ = {}
local function masq_cache(surface)
  local c = MASQ[surface.index]
  if not c then c = Mq.new(); MASQ[surface.index] = c end
  return c
end

--- Relevé d'un chunk entier au moteur (même lecture que read_masks, donc mêmes règles : eau, bloqué, défrichable).
local function chunk_reader(f, surface)
  return function(cx, cy)
    local x0, y0 = cx * Mq.CHUNK, cy * Mq.CHUNK
    local m = read_masks(f, surface, x0, y0, x0 + Mq.CHUNK, y0 + Mq.CHUNK)
    return { water = m.water, blocked = m.blocked, clear = m.clear }
  end
end

--- Lot POTEAUX-MASQUES : vue des masques sur le couloir des `legs` ({ a, b } à relier par P.pole_chain). Rend la vue, ou nil si
--- l'accord de cet essai (p.masq_n + 1 fois Mq.BUDGET chunks) ne couvre pas tout le couloir : plan_power rend alors le projet
--- en attente (« masques ») et l'essai suivant accorde Mq.BUDGET chunks de plus. L'accord ne dépend que de p (sauvegardé) :
--- jamais du contenu du cache.
local function masques_view(f, surface, p, masks, legs, reach)
  local b = f.build
  local list, total = Mq.corridor(legs, Mq.margin(reach))
  local attempt = (p.masq_n or 0) + 1
  local granted = Mq.grant(attempt, #list)
  local ready, reads, hits = Mq.ensure(masq_cache(surface), list, granted, game.tick, chunk_reader(f, surface))
  local complete = granted >= #list
  if not complete or attempt > 1 then
    p.masq_logged = (p.masq_logged or 0) + 1
    if p.masq_logged <= 6 then
      log(string.format("[FO-MASQUES] %s : projet %d, couloir de %d chunk(s)%s, essai %d : %d accorde(s) (budget %d), %d lu(s) au moteur, %d en cache%s",
        f.key or "player", p.id, #list, total > #list and (" sur " .. total .. " (plafond " .. Mq.MAX_CHUNKS .. ")") or "", attempt, math.min(granted, #list),
        Mq.BUDGET, reads, hits, complete and " : couloir complet" or " : le projet attend la suite"))
    end
  end
  if not complete then return nil end
  return Mq.view(masks, masks.rect, ready, P.tkey, function(tx, ty) return not b.occ[P.tkey(tx, ty)] end)
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

--- Lot AGENCEMENT : le gabarit `g` refait avec `n` pour paramètre d'extension (au poteau du gabarit, sinon au poteau par
--- défaut quand le poteau court ne couvre plus ni ne relie l'extension, lot PLANDIR) ; `g` tel quel si l'extension est refusée.
local function extend_to(g, n)
  local g2 = M.extend(g, n)
  -- lot PLANDIR : l'extension qui ne passe pas avec un poteau court (ni couverture, ni fils) est refaite au poteau par défaut
  if g2 and g.pole_name ~= M.DEFAULT_POLE and #M.check(g2) > 0 then g2 = M.regenerate(g, { [g.extensions[1].arg] = n }, M.DEFAULT_POLE) end
  return g2 or g
end

--- Gabarit d'une demande, dimensionné au débit : (gabarit) ou (nil, raison). `opts` (lot AGENCEMENT) : sortie = "exterieur"
--- (la fonderie à tapis finit côté tête, ses coffres vers l'extérieur) ; grow(g, n) -> n' : taille de la ligne décidée APRÈS
--- celle du débit (la fonderie suit le gisement et le minerai livré, line_rows).
local function template_of(spec, opts)
  local g, why
  if spec.gen then
    local fn = M.GEN[spec.gen]
    if not fn then return nil, "generateur inconnu" end
    local args = spec.args or {}
    if opts and opts.sortie == "exterieur" and spec.gen == "smelter" then
      args = { args[1], args[2], args[3], "exterieur" }
    end
    g, why = M.with_pole(spec.pole, fn, table.unpack(args))
    -- lot PLANDIR : un poteau plus court qui ne couvre pas le gabarit cède au poteau par défaut
    if spec.pole and spec.pole ~= M.DEFAULT_POLE and (not g or #M.check(g) > 0) then g, why = fn(table.unpack(args)) end
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
      if n ~= cur then g = extend_to(g, n) end
    end
  end
  if opts and opts.grow and g.extensions and g.extensions[1] then
    local ex = g.extensions[1]
    local cur = g.args[ex.arg]
    local n = opts.grow(g, cur)
    if type(n) == "number" and n ~= cur and n >= 1 and n <= ex.max then g = extend_to(g, n) end
  end
  return g
end

local function lot_center(b, l)
  local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
  return { x = (x0 + x1) / 2, y = (y0 + y1) / 2 }
end

--- Lots candidats d'une sorte, triés par distance à `toward` (puis i, j).
Build.AVOID_MARGIN = 8 -- tuiles ajoutées au rayon d'un site écarté (le lot fait 32 tuiles de côté)
local REUSE_STATES = { defrichage = true, fantomes = true, chantier = true, raccordement = true, fini = true } -- projets dont les poteaux existent ou vont exister

local function candidates(b, states, toward, res)
  local out = {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    -- un lot de gisement sert plusieurs lignes de foreuses tant qu'il reste de la place (relevé des tuiles libres)
    -- lot IA3-e : la centrale peut aussi aller dans un lot refusé pour l'EAU (plus de la moitié d'eau) : sa rive y est
    -- souvent la seule ; le gabarit ne pose rien sur l'eau (P.fit)
    local ok_state = states[l.state] or (states.eau and l.state == "refuse" and l.reason == "eau")
    if l.out and (l.state == "libre" or l.state == "defricher") then ok_state = false end -- lot ENCEINTE3 : dehors du contour
    if (not l.used or l.state == "gisement") and ok_state and (not res or l.res == res) and not (l.bad and l.bad >= 2) then
      local c = lot_center(b, l)
      -- lot CORR-RESEAU : la centrale ne retourne pas sur un site jugé dangereux (b.avoid, posé par script/team/reseau_vivant.lua)
      local avoided = false
      if states.rive and b.avoid then
        for _, a in ipairs(b.avoid) do
          local m = a.r + Build.AVOID_MARGIN
          if (c.x - a.x) * (c.x - a.x) + (c.y - a.y) * (c.y - a.y) <= m * m then avoided = true break end
        end
      end
      if not avoided then
        out[#out + 1] = { l = l, d = math.abs(c.x - toward.x) + math.abs(c.y - toward.y), k = k }
      end
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

--- Étape 1 / robustesse (28/10, graine 123456789 : Écarlate, QG à (339, −340), AUCUNE eau dans les 121 lots du treillis ni à
--- moins de 256 tuiles : « centrale REFUSEE : pas de lot » à chaque demande, 0 poteau, 0 centrale, 0 foreuse électrique à
--- 60 min ; graine 271828182, Azure : de l'eau, mais aucune rive où le gabarit de la pompe tient, « refuse (place) » à chaque
--- demande, 0 poteau) : sans rive utilisable dans le treillis, la centrale à vapeur n'a nulle part où pomper et
--- l'électrification d'une faction ne démarre JAMAIS. Comme les gisements garantis (lot M0), l'eau de la
--- centrale est GARANTIE : un petit étang (Build.POND × Build.POND tuiles) au centre du lot libre le plus proche du QG
--- (hors lot du QG, hors gisement, hors lot pris), une fois par équipe. Le lot est réévalué (rive) et la centrale replanifiée.
Build.POND = 6
local function make_pond(f, surface)  -- factions seulement (le joueur trouve son eau)
  local b = f.build
  if b.pond then return false end
  local best
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    if not (l.i == 0 and l.j == 0) and not l.used and (l.state == "libre" or l.state == "defricher") and not l.out then
      local d = math.abs(l.i) + math.abs(l.j)
      if not best or d < best.d then best = { d = d, k = k, l = l } end
    end
  end
  if not best then return false end
  local c = lot_center(b, best.l)
  local x0, y0 = math.floor(c.x - Build.POND / 2), math.floor(c.y - Build.POND / 2)
  local tiles = {}
  for dx = 0, Build.POND - 1 do
    for dy = 0, Build.POND - 1 do tiles[#tiles + 1] = { name = "water", position = { x0 + dx, y0 + dy } } end
  end
  surface.set_tiles(tiles, true, true)
  b.pond = best.k
  -- Les rives naturelles déjà essayées sans succès (la pompe de rive demande 2 tuiles d'eau devant elle et 60 % du gabarit
  -- mouillé : graine 271828182, Azure, « centrale refusee : place » à chaque demande malgré l'eau) ne sont plus candidates :
  -- l'étang, au bord rectiligne, l'est seul.
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    if k ~= best.k and (l.water or 0) > 0 then l.bad = math.max(l.bad or 0, 2) end
  end
  best.l.state, best.l.reason, best.l.bad = "inconnu", nil, nil
  b.queue[#b.queue + 1] = { "lot", best.k }
  log(string.format("[FO-IA1D] %s : aucune rive ne tient la centrale : etang de %d x %d tuiles pose au lot %s (%d, %d) pour la centrale",
    f.key or "player", Build.POND, Build.POND, best.k, x0, y0))
  return true
end

--- Lot AGENCEMENT : relevés d'un lot (masques de place, tuiles de minerai `res`) gardés pour la passe de plan en cours. Mémoire
--- LOCALE (jamais dans global), valable pour un tick et une équipe : plan_project lit les lots pour dimensionner la ligne
--- (line_rows) puis pour poser les foreuses (plan_drills, place_module) sans relire le terrain ; vide après un chargement.
local SCAN = { tick = -1, key = nil, data = {} }
local function scan_cache(f)
  local key = tostring(f.key or "player")
  if SCAN.tick ~= game.tick or SCAN.key ~= key then SCAN.tick, SCAN.key, SCAN.data = game.tick, key, {} end
  return SCAN.data
end

--- Relevés du lot `c` (élément de candidates) : masks, et les tuiles de `res` si demandées. `cache` : scan_cache(f) ou nil.
local function lot_scan(f, surface, c, rect, res, cache)
  local masks = cache and cache["m" .. c.k]
  if not masks then
    masks = read_masks(f, surface, rect.x0 - 8, rect.y0 - 8, rect.x1 + 8, rect.y1 + 8)
    if cache then cache["m" .. c.k] = masks end
  end
  local ores
  if res then
    ores = cache and cache["o" .. c.k .. res]
    if not ores then
      ores = ore_set(surface, rect, res)
      if cache then cache["o" .. c.k .. res] = ores end
    end
  end
  return masks, ores
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
    -- lot AGENCEMENT : `opts.cache` (scan_cache) garde les relevés d'un lot entre deux tailles essayées
    local masks, ores = lot_scan(f, surface, c, rect, res, opts and opts.cache)
    local fopts = { free = masks.free, toward = toward, margin = (opts and opts.margin) or 1 }
    -- lot FONDERIES : la tête d'alimentation regarde le gisement (shared/team/plan.lua, P.fit)
    if opts and opts.head_toward then fopts.head_toward = opts.head_toward end
    -- lot AGENCEMENT : couverture visée des foreuses (80 % d'abord) et bras de sortie par quai (P.fit : place du second bras)
    if opts and opts.cover_min then fopts.cover_min = opts.cover_min end
    if opts and opts.fan then fopts.fan = opts.fan end
    if res then fopts.ore = ores end
    if opts and opts.water then fopts.water = masks.water end
    local fit, why = P.fit(g, rect, fopts)
    if fit then
      local r = fit.k == 0 and g or M.rotate(g, fit.k)
      local inst = M.instantiate(r, 0, fit.ox, fit.oy)
      return { g = r, k = fit.k, ox = fit.ox, oy = fit.oy, lot = c.k, inst = inst, cover = fit.cover, masks = masks, fan = fopts.fan }
    end
    last = why or last
    bump(b.stats.plan_refused, last)
    -- Lot AUTO : `nobad` (foreuses de ravitaillement) : un refus ne compte pas contre le lot. Build.plan_drills essaie
    -- n, n-1, … 1 foreuses dans les MÊMES lots : chaque taille refusée y comptait un échec, et le lot était exclu après la
    -- deuxième (« tapis des foreuses (pas de lot) » alors qu'une ligne plus courte y tenait).
    if opts and opts.diag then opts.diag[#opts.diag + 1] = c.k .. ":" .. tostring(why) end
    if not (opts and opts.nobad) then c.l.bad = (c.l.bad or 0) + 1 end
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

local function inst_entities(inst, part, belt)
  local out = {}
  for _, e in ipairs(inst.entities) do
    -- Lot CONVOYEURS : `belt` remplace le tapis du gabarit (le collecteur des foreuses suit le tracé qui l'achemine)
    local name = e.name
    if belt and (M.BASE[name] or {}).kind == "belt" then name = belt end
    out[#out + 1] = { name = name, x = e.position.x, y = e.position.y, dir = e.direction or 0, recipe = e.recipe, part = part }
  end
  return out
end

--- Lot PLANDIR : poteau du réseau. Le grand (5 d'acier la pièce) seulement quand le coffre en contient déjà ; sinon le
--- poteau du module lui-même (`own`, le moins cher débloqué à la demande, A.choose_pole), de la portée de fil de ses données
--- (P.wire). Un seul type de poteau par module et pour sa rue : une île sans courant vient d'un maillon trop long.
local function pole_kind(f, own)
  if Stock.count(f, "big-electric-pole") > 0 then return "big-electric-pole", 30 end
  local name = own or M.DEFAULT_POLE
  return name, P.wire(name) or 9
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
  local pole, reach = pole_kind(f, mp.name)
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
    -- Lot IA3-e : un carrefour BÂTI d'abord (réseau qui existe) ; un carrefour d'un projet encore en réserve disparaît
    -- si ce projet est annulé, et le module qui s'y reliait reste une île sans courant (moteur réel, e7-usine, amber :
    -- rangée de grenades reliée au réseau prévu d'un module annulé, réseau à elle seule, « no_power »).
    -- Le réseau RÉEL : un carrefour bâti dont le poteau est sur le réseau des machines à vapeur (moteur réel, e7-usine
    -- graine 20261020, scarlet : la rangée de pierre reliée à la route d'un module annulé, puis la fonderie et les
    -- chargeurs reliés à elle : trois modules sur une île, centrale à 0 kW). À défaut, les carrefours de la centrale, puis
    -- n'importe lequel.
    local gen_net = nil
    if surface then
      local g = surface.find_entities_filtered({ force = f.force, type = "generator", limit = 1 })[1]
      gen_net = g and g.electric_network_id or nil
    end
    local function live(n)
      if not (n.built and gen_net and surface and n.x) then return false end
      local e = surface.find_entities_filtered({ position = { n.x, n.y }, radius = 0.75, force = f.force, type = "electric-pole", limit = 1 })[1]
      return e ~= nil and e.electric_network_id == gen_net
    end
    local best, bestd, lbest, lbestd, pbest, pbestd
    for _, k in ipairs(keys) do
      local n = b.net[k]
      local d = math.abs(n.i - mi) + math.abs(n.j - mj)
      if not bestd or d < bestd then best, bestd = n, d end
      if b.plant and n.pid == b.plant and (not pbestd or d < pbestd) then pbest, pbestd = n, d end
      if (not lbestd or d < lbestd) and live(n) then lbest, lbestd = n, d end
    end
    target = lbest or pbest or best
  end
  -- route : rues praticables, à défaut par-dessus une rue fermée par une falaise (les fils passent ; correction du
  -- 27/10, banc ia1-build-reseau) ; un carrefour sans place pour son poteau est évité (3 essais)
  local bad = {}
  -- Lot IA3-e : la route ne traverse pas un carrefour PRÉVU par un autre projet et pas encore bâti (il n'y pose pas de
  -- poteau, le croyant là ; ce projet annulé, la route a un trou : moteur réel, e8-usine graine 20261020, scarlet,
  -- rangée de pierre à 95 tuiles de la centrale, réseau à elle seule). Le départ et le but restent permis.
  local skey, tkey = P.lot_key(mi, mj), P.lot_key(target.i, target.j)
  local function foreign(k)
    local n = b.net[k]
    return n ~= nil and not n.built and n.pid ~= p.id and k ~= skey and k ~= tkey
  end
  local function avoid(okf) return function(key)
    if not okf(key) then return false end
    local kind, i, j = P.parse_seg(key)
    if not kind then return true end
    local i2, j2 = i + (kind == "h" and 1 or 0), j + (kind == "v" and 1 or 0)
    local k1, k2 = P.lot_key(i, j), P.lot_key(i2, j2)
    return not bad[k1] and not bad[k2] and not foreign(k1) and not foreign(k2)
  end end
  local nodes
  -- lot PLANDIR : cause exacte d'un refus « pas de rue vers le reseau » (journal [FO-PLANDIR], 3 lignes au plus par projet)
  local cause, blocked_at
  for attempt = 1, 4 do
    nodes = P.route_nodes({ i = mi, j = mj }, target, avoid(seg_passable(b)), b.radius)
    if not nodes then nodes = P.route_nodes({ i = mi, j = mj }, target, avoid(seg_wire(b)), b.radius) end
    if not nodes then cause = "aucune route filtree (essai " .. attempt .. ")" break end
    local blocked
    for _, n in ipairs(nodes) do
      if not spot_of(n.i, n.j) then blocked = n break end
    end
    if not blocked then cause = nil break end
    blocked_at = string.format("(%d,%d)", blocked.i, blocked.j)
    bad[P.lot_key(blocked.i, blocked.j)] = true
    cause = "carrefour " .. blocked_at .. " sans quart libre (essai " .. attempt .. ")"
    nodes = nil
  end
  if not nodes then
    local nbad, nforeign_total = 0, 0
    for _ in pairs(bad) do nbad = nbad + 1 end
    for _, k in ipairs(keys) do if foreign(k) then nforeign_total = nforeign_total + 1 end end
    p.noroute_logged = (p.noroute_logged or 0) + 1
    if p.noroute_logged <= 3 then
      local free_streets = P.route_nodes({ i = mi, j = mj }, target, seg_passable(b), b.radius) ~= nil
      local free_wires = P.route_nodes({ i = mi, j = mj }, target, seg_wire(b), b.radius) ~= nil
      log(string.format("[FO-PLANDIR] %s : pas de rue vers le reseau (projet %d) : cause %s ; depart (%d,%d) cible (%d,%d) rayon %d ; "
        .. "carrefours ecartes %d, etrangers non bati %d, reseau %d carrefour(s) ; route sans filtre : rues %s, fils %s",
        f.key or "player", p.id, tostring(cause), mi, mj, target.i, target.j, b.radius or 0, nbad, nforeign_total, #keys,
        free_streets and "oui" or "non", free_wires and "oui" or "non"))
    end
    -- lot PLANDIR : les carrefours d'un AUTRE projet pas encore bâti ferment seuls la route (elle existe sans le filtre, 27/10,
    -- scarlet : 19 carrefours étrangers sur 20, projet refusé à 13 min) : le projet ATTEND (« net ») que ce réseau soit bâti ou
    -- annulé, au lieu d'être refusé
    local wait = nil
    if (nforeign_total or 0) > 0 and nbad == 0 and cause and cause:find("^aucune route") then
      local ok_s = P.route_nodes({ i = mi, j = mj }, target, seg_passable(b), b.radius) ~= nil
      local ok_w = P.route_nodes({ i = mi, j = mj }, target, seg_wire(b), b.radius) ~= nil
      if ok_s or ok_w then wait = "net" end
    end
    return nil, "pas de rue vers le reseau", wait
  end
  -- tuiles des poteaux déjà prévus ici (un poteau de liaison ne se pose pas sur un poteau de carrefour)
  local taken = {}
  local function take(e) for _, t in ipairs(P.tiles_of(e)) do taken[P.tkey(t[1], t[2])] = true end end
  -- lot POTEAUX-MASQUES : les obstacles du couloir de CHAQUE liaison (le module au carrefour, puis carrefour à carrefour), pas
  -- seulement ceux du rectangle relevé autour du module ; hors couloir relevé, une tuile reste « libre » comme avant
  local view = { free = masks.free, clear = function(tx, ty) return masks.clear[P.tkey(tx, ty)] end }
  if surface then
    local legs = {}
    local npos0 = spot_of(mi, mj) or P.node_pole(b.lat, mi, mj, big)
    legs[1] = { a = { x = mp.x, y = mp.y }, b = npos0 }
    local pv
    for _, n in ipairs(nodes) do
      local pos = spot_of(n.i, n.j)
      if pv and (not big or (pv.x - pos.x) ^ 2 + (pv.y - pos.y) ^ 2 > reach * reach - 1e-6) then legs[#legs + 1] = { a = pv, b = pos } end
      pv = pos
    end
    local v = masques_view(f, surface, p, masks, legs, reach)
    if not v then return nil, "masques (couloir des poteaux en cours de releve)", "masques" end
    view = v
  end
  local function free(x, y)
    local tx, ty = math.floor(x), math.floor(y)
    return view.free(tx, ty) and not taken[P.tkey(tx, ty)] and not view.clear(tx, ty)
  end
  -- lot CORR-RESEAU : poteaux déjà prévus ou posés (ce projet, puis les projets en chantier ou finis) que les chaînes traversent au
  -- lieu d'en doubler un (seuls comptent ceux dont la portée de fil atteint celle de la chaîne ; shift_pole n'est pas touché)
  local known = {}
  local function add_known(e)
    if e.name:find("electric%-pole") and (P.wire(e.name) or 0) >= reach - 1e-9 then known[#known + 1] = { x = e.x, y = e.y } end
  end
  for _, e in ipairs(p.ents) do add_known(e) end
  for _, pid in ipairs(b.order) do
    local q = b.projects[pid]
    -- centrale abandonnée exclue : reseau_vivant ne rouvre plus ses poteaux, on ne s'appuie pas sur eux
    if q and q ~= p and not q.abandoned and REUSE_STATES[q.state] then for _, e in ipairs(q.ents) do add_known(e) end end
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
      local chain = P.pole_chain(prev, pos, reach, big, free, known)
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
  local chain = P.pole_chain({ x = mp.x, y = mp.y }, npos, link_reach, false, free, known)
  if not chain then return nil, "liaison electrique" end
  for _, c in ipairs(chain) do
    local e = { name = mp.name, x = c.x, y = c.y, dir = 0, role = "liaison" }
    out[#out + 1] = e
    take(e)
  end
  if view.stats and (p.masq_logged or 0) < 6 then
    p.masq_logged = (p.masq_logged or 0) + 1
    log(string.format("[FO-MASQUES] %s : projet %d, %d poteau(x) de liaison et de rue planifie(s) : %d interrogation(s) du rectangle du module, %d d'un chunk releve, %d de tuile inconnue (libre)",
      f.key or "player", p.id, #out, view.stats.base, view.stats.chunk, view.stats.unknown))
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
    local sup = (q.name == "big-electric-pole") and 2 or ((M.spec(q.name) or {}).supply or 3.5)
    if math.abs(q.x - e.x) <= sup + 0.15 and math.abs(q.y - e.y) <= sup + 0.15 then return true end
  end
  return false
end
local function quai_poles(b, p, list, masks, pole_name)
  local poles = {}
  for _, e in ipairs(p.ents) do if e.name:find("electric%-pole") then poles[#poles + 1] = e end end
  for _, e in ipairs(list) do if e.name:find("electric%-pole") then poles[#poles + 1] = e end end
  local planned = {}
  for _, e in ipairs(p.ents) do for _, t in ipairs(P.tiles_of(e)) do planned[P.tkey(t[1], t[2])] = true end end
  for _, e in ipairs(list) do for _, t in ipairs(P.tiles_of(e)) do planned[P.tkey(t[1], t[2])] = true end end
  local extra = {}
  for _, e in ipairs(list) do
    if QUAI_ROLES[e.role] and not covered_by(poles, e) then
      local tx0, ty0 = math.floor(e.x), math.floor(e.y)
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } }) do
        local tx, ty = tx0 + d[1], ty0 + d[2]
        local k = P.tkey(tx, ty)
        if not planned[k] and not b.occ[k] and (not masks or masks.free(tx, ty)) then
          local pole = { name = pole_name or M.DEFAULT_POLE, x = tx + 0.5, y = ty + 0.5, dir = 0, role = "quai-poteau", part = e.part }
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

--- Lot AGENCEMENT : bras de sortie par tapis de sortie d'un gabarit : (nom du bras, nombre) pour au plus `fan_max` bras (1 : le
--- quai d'avant seul, comme avant le lot ; 2 : un second bras et son coffre sur le côté extérieur du bout du tapis, dont la place
--- est réservée par P.fit via `fan`). Un bras seul ne suit pas une longue ligne (le plafond de la ligne était son débit).
local function out_arms(g, fan_max)
  local outn = 0
  for _, k in ipairs(sorted_keys(g.nominal or {})) do if k ~= "electricity-kw" then outn = outn + g.nominal[k] end end
  local nports = 0
  for _, q in ipairs(g.ports or {}) do if q.kind == "tapis" and q.io == "out" then nports = nports + 1 end end
  local per = outn / math.max(1, nports)
  local cmax = math.max(1, math.min(fan_max or 1, Li.MAX_ARMS))
  local ins, cnt = M.choose_inserters(per, true, cmax)
  if not ins then ins, cnt = "fast-inserter", cmax end
  return ins, cnt
end

--- Lot AGENCEMENT : un AUTRE projet du plan consomme-t-il `plate` ? (`p.consumes`, posé au plan de chaque projet : les entrées de
--- son gabarit.) Plaques qui nourrissent un module de l'usine : la ligne finit côté tête, coffres vers l'extérieur.
local function plate_used_elsewhere(b, p, plate)
  for _, id in ipairs(b.order) do
    local q = b.projects[id]
    if q and q ~= p and q.consumes and q.consumes[plate] then return true end
  end
  return false
end

Build.LINE_LOGS = 24 -- lignes [FO-LIGNE] au plus, par équipe

--- Lot AGENCEMENT (retour du DC du 29/10 : « ils peuvent pas vraiment étendre plus loin », « 4 foreuses ») : taille de la fonderie
--- à tapis, décidée APRÈS celle de la demande. La ligne suit les foreuses que le gisement le plus proche porte à 80 % de
--- couverture (Rg.pairs_for_tiles : tuiles de minerai du lot, relevé du plan, sans appel moteur), bornée par l'emprise d'un lot,
--- le débit des bras de sortie et une part du stock de plaques. Règle pure : shared/team/ligne.lua. Rend le nombre de rangées.
local function line_rows(f, surface, spec, g, cur, rev)
  local cfg = T.ligne
  local prm = g.params or {}
  if not (cfg and cfg.grow and g.gen == "smelter" and spec.feed == "tapis" and prm.ore and prm.n and prm.n > 0) then return cur end
  local b = f.build
  local plate = M.PLATE_OF[prm.ore]
  local main = g.nominal and plate and g.nominal[plate]
  local fsp, dsp = M.spec(prm.furnace or ""), M.spec(T.DRILL_ELECTRIC)
  if not (main and main > 0 and fsp and dsp) then return cur end
  local cap = main / (2 * prm.n) -- plaques/s d'UN four
  local gd = M.GEN.drills(prm.ore, 1)
  local pairs_line = gd and gd.extensions and gd.extensions[1] and gd.extensions[1].max or 0
  local reach = Rg.reach(dsp.radius, dsp.w)
  -- ce que les lots de gisement les plus proches portent : le comptage des tuiles du relevé de lot donne une BORNE HAUTE
  -- (Rg.pairs_for_tiles), puis P.fit lui-même (pur) dit quelle ligne de foreuses y TIENT à la couverture visée
  local tiles, pairs_dep, bound = 0, 0, 0
  local cache = scan_cache(f)
  for i, c in ipairs(candidates(b, { gisement = true }, { x = b.lat.ox, y = b.lat.oy }, prm.ore)) do
    if i > cfg.top_lots then break end
    local nt = c.l.ore_n or 0
    if nt > tiles then tiles = nt end
    local ub = math.min(Rg.pairs_for_tiles(nt, dsp.w, reach, cfg.cover, pairs_line), pairs_line)
    bound = math.max(bound, ub)
    if ub > pairs_dep then
      local x0, y0, x1, y1 = P.lot_rect(b.lat, c.l.i, c.l.j)
      local rect = { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
      local masks, ores = lot_scan(f, surface, c, rect, prm.ore, cache)
      for n = ub, pairs_dep + 1, -1 do
        local gd2 = M.GEN.drills(prm.ore, n)
        if gd2 and P.fit(gd2, rect, { free = masks.free, ore = ores, cover_min = cfg.cover }) then pairs_dep = n break end
      end
    end
  end
  local rows, why = Li.rows_wanted({
    rows_rate = cur, pairs_dep = pairs_dep, drill_rate = dsp.speed, cap = cap,
    pairs_line = pairs_line, rows_max = g.extensions[1].max, grow = true,
    rows_fit = Li.rows_fit(P.LOT, 1, P.FEED_DEPTH, rev and 0 or 2, fsp.w),
    out_ok = function(r) return M.choose_inserters(r * cap, true, Li.MAX_ARMS) ~= nil end,
    budget_rows = Li.budget_rows(Stock.count(f, T.outposts.iron.product), cfg.row_cost, cfg.stock_share, cfg.rows_floor),
  })
  if rows ~= cur then
    b.line_logs = (b.line_logs or 0) + 1
    if b.line_logs <= Build.LINE_LOGS then
      log(string.format("[FO-LIGNE] %s : fonderie %s, %d rangee(s) demandee(s) -> %d (%s) ; gisement %d tuiles (borne %d paire(s)) = %d paire(s) de foreuses a %d%% verifiees, sortie %s",
        f.key or "player", tostring(prm.ore), cur, rows, why, tiles, bound, pairs_dep, math.floor(cfg.cover * 100 + 0.5),
        rev and "exterieur" or "centre"))
    end
  end
  return rows
end

--- Têtes d'alimentation et quais d'un module posé ; foreuses de ravitaillement et tapis. Rend true ou false, raison.
local function plan_feed(f, surface, p, place, part)
  local b = f.build
  local g = place.g
  -- Lot AUTO : les quais de SORTIE d'abord, puis les entrées (têtes, foreuses et leur tapis). Le tapis des foreuses évite
  -- les tuiles déjà réservées (b.occ) ; réservé AVANT le quai de sortie, il pouvait passer sur sa tuile (reserve_tiles admet
  -- un recouvrement dans le même projet) : moteur réel, a2 et a3-usine graine 271828182, emerald, fantôme du tapis refusé
  -- « occupe » par le coffre du quai de sortie bâti avant lui, fonderie bloquée à 138 entités sur 139 jusqu'à 90 min.
  local ports = {}
  for _, port in ipairs(P.belt_ports(place.inst)) do if port.io ~= "in" then ports[#ports + 1] = port end end
  for _, port in ipairs(P.belt_ports(place.inst)) do if port.io == "in" then ports[#ports + 1] = port end end
  for _, port in ipairs(ports) do
    if port.io == "in" then
      local sources = { nil, nil }
      local drills = {}
      for lane = 1, 2 do
        local item = port.lanes and port.lanes[lane]
        -- une même ressource sur les deux voies : une seule source (la voie 1)
        if item and not (lane == 2 and port.lanes[1] == item) then
          sources[lane] = "quai"
          local flow = g.inputs and g.inputs[item] or 0
          -- Lot IA3-e : feed = "tapis" (fonderie de l'automatisation) : sa voie de minerai est servie par foreuses et
          -- tapis, JAMAIS par un quai (il se remplit depuis le coffre, où il n'y a pas de minerai : e7 et e10-usine,
          -- fours « no_ingredients », 0 plaque sans PNJ) ; sinon le plan est refusé, raison « gisement : … ».
          local need_belt = p.spec.feed == "tapis" and M.ORES[item] and item ~= "coal"
          if M.ORES[item] and flow >= P.AUTO_FLOW and p.spec.feed ~= "quai" then
            local dt = deposit_toward(b, item)
            local reach = (p.spec.feed == "tapis") and 5 or 3
            local d = dt and (math.abs(dt.x - place.ox) + math.abs(dt.y - place.oy)) or nil
            if d and d <= reach * P.PITCH then
              sources[lane] = "tapis"
              drills[lane] = { item = item, flow = flow }
            elseif need_belt then
              -- gisement hors du treillis : le treillis grandit (nouvel essai quand le rayon change)
              if not dt and b.radius < Build.RADIUS_MAX then Build.grow(f, b.radius + 1) end
              return false, dt and string.format("gisement : %s a %d tuiles du lot", item, d) or ("gisement : " .. item .. " hors du treillis")
            end
          elseif need_belt then
            return false, string.format("gisement : %s %.2f/s, sous le seuil du tapis", item, flow)
          end
        end
      end
      -- centrale : bras À COMBUSTION au quai (correction du 27/10 : avec un bras électrique, pas de charbon sans courant
      -- ni de courant sans charbon, 0 kW au banc ia1-build-plaine) ; il se ravitaille avec le charbon qu'il porte. Lot
      -- PLANDIR (28/10) : ils le RESTENT, mesuré : passés à l'électrique, les bras de la centrale la tuaient en 1,5 à 3,5 min
      -- (6 cas sur 6)
      local quai_ins = (g.gen == "steam") and M.BURNER_ARM or "inserter"
      -- Lot CONVOYEURS : la tête et le tracé des foreuses ont le même tapis (le meilleur débloqué, ou celui que le débit exige)
      local head_belt
      do
        local top = 0
        for lane = 1, 2 do if drills[lane] and drills[lane].flow > top then top = drills[lane].flow end end
        if top > 0 then head_belt = Conv.choose(f, top) end
      end
      local fd = P.feeder(port, sources, quai_ins, head_belt)
      for _, e in ipairs(fd.entities) do e.part = part end
      if not reserve_tiles(b, p, fd.entities) then return false, "tete d'alimentation" end
      for _, c in ipairs(fd.chests) do p.quais[#p.quais + 1] = { x = c.x, y = c.y, item = c.item } end
      -- Lot IA3-e : les poteaux des bras de quai APRÈS le tapis des foreuses (posés avant, ils prenaient les tuiles de son
      -- arrivée : tapis impossible, repli sur un quai de minerai vide ; moteur réel, e7-usine, emerald, même lot qu'en
      -- e6, 74 entités sans foreuses contre 138 avec).
      local quay_ents = {}
      for _, e in ipairs(fd.entities) do quay_ents[#quay_ents + 1] = e end
      for _, a in ipairs(fd.arrivals) do
        local d = drills[a.lane]
        if d then
          local ok, why = Build.plan_drills(f, surface, p, d.item, d.flow, a, head_belt)
          if not ok and p.spec.feed == "tapis" then
            bump(b.stats.plan_refused, "tapis:" .. tostring(why))
            return false, "gisement : tapis des foreuses (" .. tostring(why) .. ")"
          end
          if ok then Build.fonte_equilibre(f, p, g, d, #p.parts) end
          if not ok then
            -- repli : quai sur cette voie (le tapis n'a pas pu être tracé ou le gisement manque)
            bump(b.stats.plan_refused, "tapis:" .. tostring(why))
            local alt = P.feeder(port, { a.lane == 1 and "quai" or nil, a.lane == 2 and "quai" or nil }, quai_ins, head_belt)
            local extra = {}
            for _, e in ipairs(alt.entities) do if e.role ~= "tete" then e.part = part; extra[#extra + 1] = e end end
            if reserve_tiles(b, p, extra) then
              for _, c in ipairs(alt.chests) do p.quais[#p.quais + 1] = { x = c.x, y = c.y, item = c.item } end
              for _, e in ipairs(extra) do quay_ents[#quay_ents + 1] = e end
            end
          end
        end
      end
      do
        local qp = quai_poles(b, p, quay_ents, place.masks, g.pole_name)
        if #qp > 0 and not reserve_tiles(b, p, qp) then return false, "poteau de quai" end
      end
    else
      -- lot AGENCEMENT : jusqu'à `place.fan` bras par tapis de sortie (2 pour une longue ligne), le second du côté extérieur
      local ins, arms = out_arms(g, place.fan)
      local q = P.out_quai(port, ins, arms, arms > 1 and P.out_side(place.inst, port) or nil)
      for _, e in ipairs(q) do e.part = part end
      if not reserve_tiles(b, p, q) then return false, "quai de sortie" end
      local qp = quai_poles(b, p, q, place.masks, g.pole_name)
      if #qp > 0 and not reserve_tiles(b, p, qp) then return false, "poteau de quai" end
      for _, e in ipairs(q) do
        if e.role == "sortie" then p.outs[#p.outs + 1] = { x = e.x, y = e.y } end
      end
    end
  end
  return true
end

--- Lot AUTO : l'emprise d'une entité `name` posée en `pos` (direction `dir`) touche-t-elle une tuile RÉSERVÉE par un projet
--- du plan directeur de l'équipe (b.occ) ? Lecture seulement ; faux sans plan directeur. Les autres poseurs (avant-postes
--- d'IA3-c) la consultent : moteur réel, a2-usine graine 271828182, emerald, un coffre d'avant-poste posé à 50 min sur le
--- tracé du tapis de la fonderie planifiée à 31 min : fantôme du tapis refusé « occupe » 18 fois, fonderie bloquée à
--- 138 entités sur 139 jusqu'à 90 min.
function Build.reserved_entity(f, name, pos, dir)
  local b = f and f.build
  if not (b and b.occ and pos) then return false end
  local p = game.entity_prototypes[name]
  if not p then return false end
  local w, h = p.tile_width or 1, p.tile_height or 1
  if dir == 2 or dir == 6 then w, h = h, w end
  local x0, y0 = math.floor(pos.x - w / 2 + 0.01), math.floor(pos.y - h / 2 + 0.01)
  for ty = y0, y0 + h - 1 do
    for tx = x0, x0 + w - 1 do
      if b.occ[P.tkey(tx, ty)] then return true end
    end
  end
  return false
end

-- Crochet des avant-postes (script/faction/outposts.lua, déjà chargé par script/team/worker.lua avant ce fichier : ni
-- l'ordre des require ni celui des abonnements ne change).
Outposts.reserved = function(f, name, pos, dir) return Build.reserved_entity(f, name, pos, dir) end
-- Lot STOCKAGE : les annexes du QG (script/team/stock.lua) sautent une place réservée par le plan directeur.
Stock.reserved = function(f, name, pos) return Build.reserved_entity(f, name, pos) end

Build.ROUTE_WEIGHT = 2        -- lot AUTO : poids de l'heuristique du second tracé du tapis des foreuses (A* pondéré)
Build.DRILL_DIAG_LOGS = 24    -- lot AUTO : lignes de diagnostic des foreuses refusées, au plus, par équipe

--- Lot AUTO : diagnostic d'un refus des foreuses d'une voie (une ligne [FO-AUTO], au plus Build.DRILL_DIAG_LOGS par
--- équipe) : les lots qui portent ce minerai (état, partagé, réservé, échecs, tuiles, distance à l'arrivée) et les raisons
--- de P.fit lot par lot (essai à 1 foreuse). Lecture seulement.
function Build.drill_diag(f, item, n, a, why, diag, s)
  local b = f.build
  b.drill_logs = (b.drill_logs or 0) + 1
  if b.drill_logs > Build.DRILL_DIAG_LOGS then return end
  local lots = {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    if l.ore == item or l.res == item then
      local c = lot_center(b, l)
      lots[#lots + 1] = string.format("%s(%s%s%s,bad%d,%d tuiles,%d)", k, l.state, l.shared and ",partage" or "",
        l.used and (",pris" .. tostring(l.used)) or "", l.bad or 0, l.ore_n or 0, math.floor(math.abs(c.x - a.x) + math.abs(c.y - a.y)))
    end
  end
  log(string.format("[FO-AUTO] %s : foreuses %s refusees (%s) : %d foreuse(s) visees, arrivee (%d, %d)%s ; lots de %s : %s ; essais (1 foreuse) : %s",
    f.key or "player", item, tostring(why), n, a.x, a.y, s and string.format(", queue (%d, %d)", s.x, s.y) or "", item,
    #lots > 0 and table.concat(lots, " ") or "aucun", (diag and #diag > 0) and table.concat(diag, " ") or "-"))
end

--- Lot FONDERIES : le plan d'une fonderie à tapis tient-il l'équilibre entre les foreuses RÉELLEMENT planifiées (la ligne
--- peut avoir été raccourcie : plan_drills essaie n, n-1, … 1) et ses fours ? Règle pure shared/team/fonte.lua ; ici,
--- DIAGNOSTIC seulement (une ligne [FO-FONTE] et p.equilibre), rien n'est retiré ni ajouté au plan.
function Build.fonte_equilibre(f, p, g, d, part)
  local dp = p.parts[part]
  local prm = g.params or {}
  local plate = M.PLATE_OF[d.item]
  local main = g.nominal and plate and g.nominal[plate]
  if not (dp and dp.drills and dp.drills > 0 and prm.n and prm.n > 0 and main and main > 0) then return end
  local drill_rate = dp.drill_rate or 0
  local dec = Fonte.balance({ input = dp.drills * drill_rate, capacity = main / (2 * prm.n), furnaces = 2 * prm.n,
    max_furnaces = 2 * prm.n, drills = dp.drills, drill_rate = drill_rate, max_drills = dp.drills })
  p.equilibre = { action = dec.action, wanted = dec.wanted, furnaces = 2 * prm.n, drills = dp.drills }
  if dec.action ~= "equilibre" then
    log(string.format("[FO-FONTE] %s : projet %d, fonderie de %d fours pour %d foreuses (%s) : equilibre %s, %d four(s) voulu(s)",
      f.key or "player", p.id, 2 * prm.n, dp.drills, d.item, dec.action, dec.wanted))
  end
end

--- Foreuses de ravitaillement d'une voie et leur tapis jusqu'à l'arrivée `a`. Rend true, ou false et raison.
function Build.plan_drills(f, surface, p, item, flow, a, belt)
  local b = f.build
  belt = belt or Conv.choose(f, flow) or "transport-belt" -- lot CONVOYEURS
  local n = math.max(1, math.ceil(flow / (2 * M.spec("electric-mining-drill").speed) - 1e-9))
  local place, why
  local diag = {}
  -- lot AGENCEMENT (retour du DC du 29/10 : « on veut des rangées de foreuses ») : la ligne ne dépasse pas ce qu'un collecteur porte
  -- (le gabarit le dit), s'essaie d'abord à 80 % de tuiles minées portant du minerai SANS réduire la ligne (relecture : une ligne
  -- plus courte à 80 % n'a pas le droit de battre la ligne voulue à la couverture d'avant), puis redescend comme avant (n, n−1, … 1) ;
  -- les relevés d'un lot servent à toutes les tailles essayées (`cache`)
  local g1 = M.GEN.drills(item, 1)
  local pmax = g1 and g1.extensions and g1.extensions[1] and g1.extensions[1].max or n
  local top = math.max(1, math.min(n, pmax))
  local cfg = T.ligne or {}
  local cache, picked = scan_cache(f), nil
  for _, at in ipairs(Rg.attempts(top, top, { high = cfg.cover })) do
    local nn = at.n
    local g = M.with_pole(p.spec and p.spec.pole, M.GEN.drills, item, nn)
    if not g and p.spec and p.spec.pole then g = M.GEN.drills(item, nn) end
    if g then
      place, why = place_module(f, surface, g, { gisement = true }, { x = a.x, y = a.y }, item,
        { nobad = true, diag = (nn == 1 and not at.cover) and diag or nil, cover_min = at.cover, cache = cache })
      if place then picked = at break end
    end
  end
  if not place then
    Build.drill_diag(f, item, n, a, why, diag)
    return false, why
  end
  local part = #p.parts + 1
  p.parts[part] = { kind = "foreuses", key = place.g.key, lot = place.lot, ox = place.ox, oy = place.oy, k = place.k,
    w = place.g.w, h = place.g.h, power = needs_power(place.g), belt = belt, flow = flow,
    drills = 2 * ((place.g.params or {}).n or 0),
    drill_rate = (M.spec((place.g.params or {}).drill or "") or {}).speed or 0,
    pairs = (place.g.params or {}).n, cover = place.cover }
  b.stats.rangees = (b.stats.rangees or 0) + 1
  if b.stats.rangees <= Build.LINE_LOGS then
    log(string.format("[FO-RANGEES] %s : projet %d, foreuses %s : %d paire(s) (%d foreuses) visees %d, couverture %d%% (visee %d%%), %.2f minerai/s demandes",
      f.key or "player", p.id, item, (place.g.params or {}).n or 0, 2 * ((place.g.params or {}).n or 0), n,
      math.floor((place.cover or 0) * 100 + 0.5), picked and picked.cover and math.floor(picked.cover * 100 + 0.5) or math.floor(P.DRILL_COVER * 100 + 0.5), flow))
  end
  local ents = inst_entities(place.inst, part, belt)
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
  if not tiles and n2 == "trop long" then
    -- Lot AUTO (« tapis des foreuses (trop long) » chez scarlet, e15-usine graine 271828182) : l'A* exact s'arrêtait à
    -- P.ASTAR_MAX nœuds dans une boîte qui en compte jusqu'à 14 400 (forêt : chaque tuile coûte 2, rues : 3). Nouvel essai
    -- PONDÉRÉ (heuristique × Build.ROUTE_WEIGHT) sur toute la boîte : un tapis un peu plus long, ou « aucun chemin ».
    -- la plus grande des deux boîtes des essais exacts qui tient dans 120 tuiles (marge d'un pas de treillis, sinon 12)
    local mg = P.PITCH
    if math.max(math.abs(s.x - a.x), math.abs(s.y - a.y)) + 2 * mg > 120 then mg = 12 end
    local cx0, cy0 = math.min(s.x, a.x) - mg, math.min(s.y, a.y) - mg
    local cx1, cy1 = math.max(s.x, a.x) + mg, math.max(s.y, a.y) + mg
    local m2 = read_masks(f, surface, cx0, cy0, cx1 + 1, cy1 + 1)
    masks.water, masks.blocked, masks.clear = m2.water, m2.blocked, m2.clear
    local first = n2
    tiles, n2 = P.belt_route(s, { x = a.x, y = a.y }, a.dir, { x0 = cx0, y0 = cy0, x1 = cx1, y1 = cy1 }, cost,
      { weight = Build.ROUTE_WEIGHT, max = (cx1 - cx0 + 1) * (cy1 - cy0 + 1) })
    bump(b.stats.plan_refused, "tapis-pondere:" .. (tiles and "ok" or tostring(n2)))
    if not tiles then n2 = first .. ", pondere : " .. tostring(n2) end
  end
  if not tiles then
    p.parts[part] = nil
    Build.drill_diag(f, item, n, a, "tapis " .. tostring(n2), nil, s)
    return false, n2
  end
  for _, t in ipairs(tiles) do ents[#ents + 1] = { name = belt, x = t.x + 0.5, y = t.y + 0.5, dir = t.dir, part = part, role = "liaison-tapis" } end
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

---------------------------------------------------------------------------------------------------
-- Lot ESPACE : enceinte (anneau de murs au-delà du treillis ; règle pure : shared/team/enceinte.lua)
---------------------------------------------------------------------------------------------------
--- Relevé des zones d'un projet d'enceinte (rectangles { x0, y0, x1, y1 }) : eau, bloqué, défrichable (read_masks) et
--- tuiles de RESSOURCE (jamais murées).
local function enc_masks(f, surface, areas)
  local m = { water = {}, blocked = {}, clear = {}, ore = {} }
  for _, bd in ipairs(areas) do
    local r = read_masks(f, surface, bd[1], bd[2], bd[3], bd[4])
    for k in pairs(r.water) do m.water[k] = true end
    for k in pairs(r.blocked) do m.blocked[k] = true end
    for k in pairs(r.clear) do m.clear[k] = true end
    for _, e in ipairs(surface.find_entities_filtered({ area = { { bd[1], bd[2] }, { bd[3], bd[4] } }, type = "resource" })) do
      m.ore[P.tkey(math.floor(e.position.x), math.floor(e.position.y))] = true
    end
  end
  return m
end

--- Zones à relever pour l'anneau ENTIER (projet d'une sauvegarde d'avant ENCEINTE2) : quatre bandes de 11 tuiles d'épaisseur
--- vers l'intérieur (de quoi y placer les points d'appui, sur la dernière rue).
local function ring_areas(x0, y0, x1, y1)
  return {
    { x0 - 1, y0 - 1, x1 + 2, y0 + 10 }, { x0 - 1, y1 - 9, x1 + 2, y1 + 2 },
    { x0 - 1, y0 - 1, x0 + 10, y1 + 2 }, { x1 - 9, y0 - 1, x1 + 2, y1 + 2 },
  }
end

--- Lot ENCEINTE3 (retour du DC, Azur : « ils ont vraiment placé super loin ») : contour SERRÉ sur l'empreinte réelle de la base.
--- Empreinte = lots pris par un projet vivant (planifié ou fini), lot du QG, tourelles de l'équipe ; + E.MARGIN tuiles ; les lots
--- et tourelles ISOLÉS (plus de E.ISOLATED_GAP tuiles) restent dehors ; les E.ROOM_LOTS lots libres les plus proches restent dedans.
--- Rend ({ x0, y0, x1, y1 } = tuiles du mur, incluses, info) ou nil (ouvertures hors bornes : repli sur le rayon d'avant).
local function enc_tight_bounds(f)
  local b = f.build
  local rects, room = {}, {}
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
    local box = { x0 = x0, y0 = y0, x1 = x1, y1 = y1, k = k }
    if l.used then
      local p = b.projects[l.used]
      if p and p.state ~= "refuse" and not (p.spec and p.spec.enceinte) then rects[#rects + 1] = box end
    elseif (l.state == "libre" or l.state == "defricher") and not (l.i == 0 and l.j == 0) and not (l.bad and l.bad >= 2) and not l.out then
      room[#room + 1] = box
    end
  end
  for _, id in ipairs(sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t and t.valid then
      local x, y = t.position.x, t.position.y
      rects[#rects + 1] = { x0 = math.floor(x - 1), y0 = math.floor(y - 1), x1 = math.ceil(x + 1), y1 = math.ceil(y + 1) }
    end
  end
  local cx0, cy0, cx1, cy1 = Enc.bounds(b.lat, b.radius) -- relecture ENCEINTE3 : jamais plus large que l'anneau du rayon
  local bounds, info = Enc.tight_bounds(b.lat, rects, room, { clamp = { cx0, cy0, cx1, cy1 } })
  if not Enc.gates_inside(b.lat, bounds) then return nil end
  return bounds, info
end

--- Lot ENCEINTE3 : les lots libres que le mur coupe ou laisse dehors ne reçoivent plus de module (drapeau `out`, lu par
--- `candidates`, `make_pond` et Enc.free_count) ; un lot de GISEMENT reste utilisable dehors (les mines d'avant-poste).
local function enc_mark_out(b, bounds)
  local n = 0
  for _, k in ipairs(sorted_keys(b.lots)) do
    local l = b.lots[k]
    local x0, y0, x1, y1 = P.lot_rect(b.lat, l.i, l.j)
    if not (l.i == 0 and l.j == 0) and not Enc.inside(bounds, { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }) then
      l.out = true
      n = n + 1
    end
  end
  return n
end

--- Lot ENCEINTE3 : rayon libéré (aucun segment posé) : les lots écartés par le contour redeviennent utilisables.
local function enc_release(b)
  for _, k in ipairs(sorted_keys(b.lots)) do b.lots[k].out = nil end
end

--- Plan du projet « enceinte » : (true) ou (false, raison). Mêmes champs qu'un projet de module (entités, points d'appui,
--- obstacles) : la machine d'états d'`advance` ne change pas.
local function plan_enceinte(f, surface, p)
  local b = f.build
  local enc = b.enc
  if not enc then return false, "enceinte annulee" end
  local item = item_of(T.wall)
  if not item then return false, "mur sans objet" end
  local x0, y0, x1, y1 = Enc.bounds(b.lat, enc.r, nil, enc.bounds) -- lot ENCEINTE3 : contour serré s'il y en a un
  -- lot ENCEINTE2 : un projet = un SEGMENT (spec.walls : tuiles { {tx, ty} ... }) ; sans liste (projet d'une sauvegarde d'avant),
  -- l'anneau entier
  local seg = p.spec.walls
  local areas, tiles
  if seg then
    local ax0, ay0, ax1, ay1 = math.huge, math.huge, -math.huge, -math.huge
    tiles = {}
    for _, w in ipairs(seg) do
      tiles[#tiles + 1] = { tx = w[1], ty = w[2], x = w[1] + 0.5, y = w[2] + 0.5 }
      ax0, ay0, ax1, ay1 = math.min(ax0, w[1]), math.min(ay0, w[2]), math.max(ax1, w[1]), math.max(ay1, w[2])
    end
    areas = { { ax0 - 11, ay0 - 11, ax1 + 12, ay1 + 12 } } -- 11 tuiles tout autour : de quoi poser les points d'appui
  else
    areas = ring_areas(x0, y0, x1, y1)
  end
  local m = enc_masks(f, surface, areas)
  local function skip(tx, ty)
    local k = P.tkey(tx, ty)
    if m.water[k] then return "eau" end
    if m.ore[k] then return "ressource" end
    if m.blocked[k] then return "bloque" end
    if b.occ[k] then return "reserve" end
    return nil
  end
  local ring
  if tiles then
    ring = { walls = {}, gates = 0, skipped = {} }
    for _, w in ipairs(tiles) do
      local why = skip(w.tx, w.ty)
      if why then ring.skipped[why] = (ring.skipped[why] or 0) + 1 else ring.walls[#ring.walls + 1] = w end
    end
  else
    ring = Enc.ring(b.lat, enc.r, { skip = skip, bounds = enc.bounds })
  end
  if #ring.walls == 0 then return false, "aucun mur posable" end
  local ents = {}
  for _, w in ipairs(ring.walls) do
    ents[#ents + 1] = { name = T.wall, x = w.x, y = w.y, dir = 0, part = 1, role = "enceinte", wall = true, item = item }
  end
  if not reserve_tiles(b, p, ents) then return false, "place" end
  local passable = seg_passable(b)
  local spots = {}
  for _, e in ipairs(p.ents) do
    local a = P.anchor_for(b.lat, e.x, e.y, passable)
    local ax, ay
    if a then ax, ay = a.x, a.y else ax, ay = math.floor(e.x / 8) * 8 + 4, math.floor(e.y / 8) * 8 + 4 end
    local ck = ax .. ":" .. ay
    local sp = spots[ck]
    if not sp then sp = { free_spot(b, m, ax, ay, nil) }; spots[ck] = sp end
    local fx, fy = sp[1], sp[2]
    if (fx - e.x) * (fx - e.x) + (fy - e.y) * (fy - e.y) > REACH * REACH then fx, fy = free_spot(b, m, e.x, e.y, nil) end
    e.ax, e.ay = fx, fy
    e.anchor = string.format("%s%g:%g", a and "" or "c", fx, fy)
  end
  P.sort_build(p.ents)
  p.obstacles, p.obst_keys = {}, {}
  for _, e in ipairs(p.ents) do
    local tx, ty = math.floor(e.x), math.floor(e.y)
    if m.clear[P.tkey(tx, ty)] then add_obstacle(p, { x = e.x, y = e.y, anchor = e.anchor, ax = e.ax, ay = e.ay }) end
  end
  -- ox, oy : le milieu du segment (la rue qui y mène est défrichée la première) ; ancien projet entier : l'ouverture nord
  local ox, oy = b.lat.ox + 14, y0
  if tiles then
    local mid = ring.walls[math.ceil(#ring.walls / 2)]
    ox, oy = mid.x, mid.y
  end
  p.parts[1] = { kind = "enceinte", key = "enceinte", ox = ox, oy = oy, w = 1, h = 1, power = false,
    ring = { x0, y0, x1, y1 } }
  b.stats.modules_started = b.stats.modules_started + 1
  p.walls_planned = #ring.walls
  log(string.format("[FO-ESPACE] %s : enceinte %s planifiee (rayon %d, anneau %d,%d a %d,%d) : %d murs, tuiles non murees %s, %d obstacles a defricher",
    f.key or "player", tiles and ("segment " .. tostring(p.spec.side)) or "entiere", enc.r, x0, y0, x1, y1, #ring.walls,
    (function()
      local out = {}
      for _, k in ipairs(sorted_keys(ring.skipped)) do out[#out + 1] = k .. "=" .. ring.skipped[k] end
      return #out > 0 and table.concat(out, " ") or "aucune"
    end)(), #p.obstacles))
  return true
end

--- Plan d'un projet : (true) ou (false, raison, attendre). Une seule pensée de plan par passe.
local function plan_project(f, surface, p)
  local b = f.build
  local spec = p.spec
  if spec.enceinte then return plan_enceinte(f, surface, p) end
  Profiler.start("build:plan:place") -- lot IA3-e : parts du coût d'un plan (pics de K10), mesure seulement
  -- lot AGENCEMENT : la fonderie à tapis est une LIGNE qui suit le gisement (line_rows) ; ses coffres vont vers le centre (la
  -- source de ressources de la base, défaut) ou vers l'extérieur (les plaques nourrissent un autre module du plan)
  local topts
  if spec.gen == "smelter" and spec.feed == "tapis" then
    local plate = M.PLATE_OF[(spec.args or {})[2]]
    local use = spec.use or ((plate and plate_used_elsewhere(b, p, plate)) and "usine" or nil)
    local sortie = Li.sortie_for(use)
    topts = { sortie = sortie, grow = function(g1, cur) return line_rows(f, surface, spec, g1, cur, sortie == "exterieur") end }
    p.sortie = sortie
  end
  local g, why = template_of(spec, topts)
  if not g then return false, why end
  p.consumes = {}
  for _, k in ipairs(sorted_keys(g.inputs or {})) do p.consumes[k] = true end
  local main
  local is_plant = g.gen == "steam"
  local toward
  if spec.near then toward = spec.near end
  if is_plant then
    main, why = place_module(f, surface, g, { rive = true, eau = true }, toward or { x = b.lat.ox, y = b.lat.oy }, nil, { water = true, margin = 0 })
  elseif g.resource then
    main, why = place_module(f, surface, g, { gisement = true }, toward or { x = b.lat.ox, y = b.lat.oy }, spec.resource or g.resource)
  else
    local best, bf
    for _, k in ipairs(sorted_keys(g.inputs or {})) do
      if M.ORES[k] and k ~= "coal" and (not bf or g.inputs[k] > bf) then best, bf = k, g.inputs[k] end
    end
    local dep = (best and (not toward or spec.feed == "tapis")) and deposit_toward(b, best) or nil
    if not toward then
      -- « les fonderies vont vers le minerai » : vers le gisement de l'entrée principale
      toward = dep or { x = b.lat.ox, y = b.lat.oy }
    end
    -- lot FONDERIES (retour du DC du 29/10 : tapis en crochet, fours posés « à l'envers ») : une fonderie servie par un
    -- tapis de foreuses est tournée tête vers le gisement ; la colonne de fours s'étend à l'opposé, sans retour.
    local function try_place(gx)
      local fopts = (spec.feed == "tapis" and dep) and { head_toward = dep } or nil
      -- lot AGENCEMENT : deux bras par tapis de sortie quand un seul étranglerait la ligne (place du second réservée par P.fit)
      if topts then
        local _, arms = out_arms(gx, Li.MAX_ARMS)
        if arms > 1 then fopts = fopts or {}; fopts.fan = arms end
      end
      local m, w = place_module(f, surface, gx, { libre = true, defricher = true }, toward, nil, fopts)
      if not m then m, w = place_module(f, surface, gx, { gisement = true }, toward, nil, fopts) end
      return m, w
    end
    main, why = try_place(g)
    -- lot AGENCEMENT (relecture) : la ligne agrandie ne tient dans aucun lot (relief, eau, bâtiments) : repli sur la taille de la
    -- demande, qui se posait avant le lot. Sans cela le projet restait refusé (et le treillis grandissait pour rien).
    if not main and topts then
      local g0 = template_of(spec, { sortie = topts.sortie })
      if g0 and (g0.params or {}).n ~= (g.params or {}).n then
        local m0, w0 = try_place(g0)
        if m0 then
          b.line_logs = (b.line_logs or 0) + 1
          if b.line_logs <= Build.LINE_LOGS then
            log(string.format("[FO-LIGNE] %s : projet %d, fonderie de %d rangee(s) sans place (%s) : repli sur %d rangee(s) de la demande",
              f.key or "player", p.id, (g.params or {}).n or 0, tostring(why), (g0.params or {}).n or 0))
          end
          main, why, g = m0, w0, g0
        end
      end
    end
  end
  Profiler.stop("build:plan:place")
  if not main then
    if Build.can_grow(b) then
      Build.grow(f, b.radius + 1)
      return false, why, true
    end
    if is_plant and not f.is_player and make_pond(f, surface) then return false, why, true end
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
    -- Lot AUTO : diagnostic seulement (aucun refus) : deux entités du projet sur une même tuile ne se bâtiront jamais
    -- toutes les deux (la seconde : fantôme refusé « occupe »).
    local ov = P.overlaps(p.ents)
    if #ov > 0 then
      local e1, e2 = p.ents[ov[1][1]], p.ents[ov[1][2]]
      log(string.format("[FO-AUTO] %s : projet %d, %d chevauchement(s) au plan, dont %s (%s) et %s (%s) en (%.1f, %.1f)",
        f.key or "player", p.id, #ov, e1.name, tostring(e1.role), e2.name, tostring(e2.role), e2.x, e2.y))
    end
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
          if not extra then return false, w3, (nodes == "net" or nodes == "masques") and nodes or nil end
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
  if is_plant and not b.plant then b.plant = p.id end -- (lot CORR-ENERGIE : une centrale de plus ne devient pas LA centrale)
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
function Build.plant(f, pole)
  local b = f.build
  if b.plant then return b.plant end
  local id = Build.request(f, { gen = "steam", args = { 1 }, feed = true, prio = Build.PRIO + 5, domain = "infrastructures",
    pole = pole })
  b.plant = id
  -- la centrale passe avant les autres projets en attente
  local order = { id }
  for _, x in ipairs(b.order) do if x ~= id then order[#order + 1] = x end end
  b.order = order
  return id
end

--- Lot CORR-ENERGIE : une centrale de plus (nb chaudières), demandée comme la première ; son chantier est un projet du plan
--- directeur (réserve de matériaux au coffre d'équipe, plan sur une autre rive libre). Suivi dans b.extra_plants.
function Build.grow_plant(f, nb, tick)
  local b = f.build
  local first = b.plant and b.projects[b.plant]
  if not (first and first.spec and first.spec.gen) then return nil end -- (la centrale de plus est du même type que la première)
  local id = Build.request(f, { gen = first.spec.gen, args = { nb }, feed = true, prio = Build.PRIO + 5, domain = "infrastructures" })
  if not id then return nil end
  b.extra_plants = b.extra_plants or {}
  b.extra_plants[#b.extra_plants + 1] = id
  local g = b.grow or {}
  log(string.format("[FO-ENERGIE] %s : centrale de %d chaudiere(s) demandee a %.1f min (projet %d ; %.0f J/tick sur %.0f, %d centrale(s) finie(s))",
    f.key or "player", nb, tick / 3600, id, g.power or 0, g.capacity or 0, g.done or 0))
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
  return Board.view_stock(f, Stock.contents(f), game.tick)
end

--- Lot ESPACE : recette du mur lue au moteur (ingrédients-objets seuls) : { item, ings, per } ou nil (pas de mur, recette
--- inconnue ou fermée à l'équipe, fluide en ingrédient). Les ingrédients ne sont écrits nulle part : ni nom ni quantité.
local function wall_recipe(f)
  local item = item_of(T.wall)
  local rec = game.recipe_prototypes[T.wall]
  local fo = game.forces[f.force]
  local fr = fo and fo.recipes[T.wall]
  if not (item and rec and fr and fr.enabled) then return nil end
  local ings = {}
  for _, ing in ipairs(rec.ingredients) do
    if ing.type ~= "item" then return nil end
    ings[#ings + 1] = { name = ing.name, amount = ing.amount }
  end
  local per = 1
  for _, pr in ipairs(rec.products) do if pr.name == item then per = pr.amount or 1 end end
  return { item = item, ings = ings, per = per }
end

--- Lot ESPACE : murs que les ingrédients du coffre permettent de fabriquer d'un coup (fabrication « au coffre », instantanée,
--- payée en ingrédients : personne ne fabrique de mur sinon).
local function craftable_walls(f, wr)
  return Enc.crafts_possible(wr.ings, function(n) return Stock.count(f, n) end) * wr.per
end

--- Lot ESPACE : transforme au coffre les ingrédients en murs pour couvrir ce qui manque au projet (une réserve d'enceinte).
local function craft_walls(f, p)
  local wr = wall_recipe(f)
  if not wr then return end
  local need = needs_of(p)[wr.item] or 0
  local missing = need - (p.stock[wr.item] or 0) - Stock.count(f, wr.item)
  local runs = Enc.crafts_to_run(missing, wr.per, Enc.crafts_possible(wr.ings, function(n) return Stock.count(f, n) end))
  if runs <= 0 then return end
  for i, ing in ipairs(wr.ings) do
    local want = ing.amount * runs
    local got = Stock.remove(f, ing.name, want)
    if got < want then -- ne devrait pas arriver (compté dans le même tick) : tout est rendu, rien n'est fabriqué
      Stock.insert(f, ing.name, got)
      for j = 1, i - 1 do Stock.insert(f, wr.ings[j].name, wr.ings[j].amount * runs) end
      return
    end
  end
  local made = wr.per * runs
  local put = Stock.insert(f, wr.item, made)
  if put < made then -- coffre plein : les fabrications entières qui n'ont pas tenu rendent leurs ingrédients
    local back = math.floor((made - put) / wr.per)
    if back > 0 then for _, ing in ipairs(wr.ings) do Stock.insert(f, ing.name, ing.amount * back) end end
  end
  p.crafted = (p.crafted or 0) + put
end

local function reserve(f, p)
  local need = needs_of(p)
  local missing = {}
  local free = free_stock(f)
  for _, it in ipairs(sorted_keys(need)) do
    local want = need[it] - (p.stock[it] or 0)
    if want > 0 then
      local have = math.min(Stock.count(f, it), free[it] or 0)
      local n = math.min(want, have)
      if n > 0 then
        local got = Stock.remove(f, it, n)
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
      local put = Stock.insert(f, it, n)
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
  if p.reopened then return false end -- lot CORR-RESEAU : un projet déjà bâti dont des pièces sont à refaire n'est pas annulable
  -- lot CORR-RESEAU : la centrale de remplacement (p.keep) n'est annulée que par la santé du réseau (raison « reseau: ... »)
  if p.keep and not tostring(why):find("^reseau") then return false end
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
      local add = math.min(want - have, Stock.count(f, it[1]), free[it[1]] or 0)
      if add > 0 then have = have + Stock.remove(f, it[1], add) end
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
--- Lot CORR-RESEAU : retire les RESTES neutres (cadavres de machine, objets au sol) de l'emprise d'une pièce à poser, marge de 0,6.
--- Mesuré le 29/10 (essai court 20261020, journal [FO-IA1D]) : la chaudière détruite d'une centrale n'était jamais reposée, son
--- fantôme refusé « occupe » 11 min de suite, l'emprise ne portant plus que deux item-on-ground neutres au bord (les bras à combustion
--- de la centrale y lâchent leur charbon, la cible ayant disparu) ; un cadavre seul ne bloque pas (expérience reseau-restes).
local function clear_floor(surface, e)
  local a = footprint(e)
  local n = 0
  for _, d in ipairs(surface.find_entities_filtered({ area = { { a[1][1] - 0.6, a[1][2] - 0.6 }, { a[2][1] + 0.6, a[2][2] + 0.6 } },
    type = { "corpse", "item-entity" }, force = "neutral" })) do
    if d.valid then d.destroy() n = n + 1 end
  end
  return n
end

local function place_ghost(surface, f, e)
  if find_real(surface, e, f.force) then return "deja" end
  if find_ghost(surface, e, f.force) then return "ok" end
  local function can_place()
    return surface.can_place_entity({ name = e.name, position = { e.x, e.y }, direction = e.dir, force = f.force,
      build_check_type = defines.build_check_type.ghost_revive })
  end
  if not can_place() and not (clear_floor(surface, e) > 0 and can_place()) then
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
  -- Lot IA3-e : un SOLDAT de l'équipe en garnison ne quitte jamais l'emprise (moteur réel, e9-usine graine 20261020 après
  -- la fusion de main 0.5.0 : fonderie d'emerald bloquée 50 min à 68 entités sur 69, un bras sous fo-emerald-rifleman) :
  -- il s'écarte (téléporté sur la case libre la plus proche HORS de l'emprise). Les personnages (PNJ) bougent seuls.
  local a = footprint(e)
  -- Lot AUTO : un PNJ (personnage SANS joueur) de l'équipe arrêté sur l'emprise s'écarte aussi (moteur réel, a4-usine
  -- graine 271828182, emerald : fonderie à 133 entités sur 135 de 58 à 75 min, four refusé « pnj » ; « les PNJ bougent
  -- seuls » ne vaut pas pour un PNJ sans tâche). Un personnage d'un joueur n'est jamais déplacé.
  local movers = surface.find_entities_filtered({ area = a, type = "unit", force = f.force })
  for _, c in ipairs(surface.find_entities_filtered({ area = a, type = "character", force = f.force })) do
    if not c.player then movers[#movers + 1] = c end
  end
  for _, u in ipairs(movers) do
    local target = { x = a[2][1] + 2, y = (a[1][2] + a[2][2]) / 2 }
    local pos = surface.find_non_colliding_position(u.name, target, 8, 0.5)
    if pos and not (pos.x > a[1][1] - 0.5 and pos.x < a[2][1] + 0.5 and pos.y > a[1][2] - 0.5 and pos.y < a[2][2] + 0.5) then
      u.teleport(pos)
      st.npc_moved = (st.npc_moved or 0) + 1
    end
  end
  if e.npc_blocks % Build.NPC_BLOCKS_PER_FAIL == 0 then e.fails = (e.fails or 0) + 1 end
  log_refusal(f, p, e, "pnj", surface)
end

--- Le bâtisseur `self` est-il debout sur l'emprise de `e` (marge 0,3) ?
local function stands_on(self, e)
  if not (self and self.valid) then return false end
  local a, q = footprint(e), self.position
  return q.x > a[1][1] - 0.3 and q.x < a[2][1] + 0.3 and q.y > a[1][2] - 0.3 and q.y < a[2][2] + 0.3
end

--- Écarte le bâtisseur de l'emprise de `e` : case libre la plus proche à l'est de l'emprise, HORS de toute emprise
--- visée (comme npc_block pour les autres PNJ). Rend vrai s'il ne gêne plus. Sans cela, un bâtisseur arrêté sur le
--- dernier poteau et la dernière machine d'une centrale les « laissait » à chaque pensée en payant ses jetons, et la
--- tâche ne finissait jamais (moteur réel, etape1-guide, VOTRE équipe : centrale à 15 entités sur 17 de 27 à 60 min,
--- module des packs rouges sans courant, aucune foreuse électrique).
local function step_aside(surface, self, e)
  if not stands_on(self, e) then return true end
  local a = footprint(e)
  for _, d in ipairs({ 2, 4, 6 }) do
    local spot = surface.find_non_colliding_position(self.name, { x = a[2][1] + d, y = (a[1][2] + a[2][2]) / 2 }, 6, 0.5)
    if spot then
      self.teleport(spot)
      if not stands_on(self, e) then return true end
    end
  end
  return false
end

--- Lot ELEC2 : un poteau 1 × 1 refusé « occupe » (une falaise que les masques ne voient pas, F294, ou une foreuse à
--- combustion d'un avant-poste posée depuis le plan ; banc etape1-guide : fonderie électrique abandonnée à 181 entités
--- sur 197 sur un seul poteau, 0 foreuse électrique à 60 min) est reposé sur une tuile libre voisine (2 tuiles au plus) qui
--- laisse le réseau local aussi relié qu'avant : mêmes composantes connexes (fil de 7,5 tuiles, poteaux du projet et du
--- réseau alentour). Rend vrai si le fantôme a été posé ailleurs (e.x, e.y changent).
local function shift_pole(f, surface, p, e)
  local reach = P.wire(e.name)
  local w, h = P.size(e.name, e.dir)
  if not reach or w ~= 1 or h ~= 1 then return false end
  local b = f.build
  local win = 2 * reach + 2
  local near = {}
  for _, o in ipairs(p.ents) do
    if o ~= e and P.wire(o.name) and math.abs(o.x - e.x) <= win and math.abs(o.y - e.y) <= win then
      near[#near + 1] = { x = o.x, y = o.y }
    end
  end
  for _, o in ipairs(surface.find_entities_filtered({ position = { e.x, e.y }, radius = win, type = "electric-pole",
    force = f.force })) do
    near[#near + 1] = { x = o.position.x, y = o.position.y }
  end
  -- composantes connexes de `near` plus un poteau en (x, y)
  local function components(x, y)
    local pts = { { x = x, y = y } }
    for _, n in ipairs(near) do pts[#pts + 1] = n end
    local comp, count = {}, 0
    for i = 1, #pts do
      if not comp[i] then
        count = count + 1
        comp[i] = count
        local stack = { i }
        while #stack > 0 do
          local u = table.remove(stack)
          for v = 1, #pts do
            if not comp[v] and (pts[u].x - pts[v].x) ^ 2 + (pts[u].y - pts[v].y) ^ 2 <= reach * reach + 1e-9 then
              comp[v] = count
              stack[#stack + 1] = v
            end
          end
        end
      end
    end
    return count
  end
  local before = components(e.x, e.y)
  local cands = {}
  for dy = -2, 2 do
    for dx = -2, 2 do
      if dx ~= 0 or dy ~= 0 then cands[#cands + 1] = { x = e.x + dx, y = e.y + dy, d = dx * dx + dy * dy } end
    end
  end
  table.sort(cands, function(a, c)
    if a.d ~= c.d then return a.d < c.d end
    if a.y ~= c.y then return a.y < c.y end
    return a.x < c.x
  end)
  local n_occ, n_link, n_ghost = 0, 0, 0
  for _, c in ipairs(cands) do
    local k = P.tkey(math.floor(c.x), math.floor(c.y))
    if b.occ[k] then
      n_occ = n_occ + 1
    elseif components(c.x, c.y) > before then
      n_link = n_link + 1
    elseif place_ghost(surface, f, { name = e.name, x = c.x, y = c.y, dir = e.dir }) == "ok" then
      log(string.format("[FO-IA1D] %s : projet %d, %s deplace de (%g, %g) a (%g, %g) (tuile occupee)", f.key or "player", p.id,
        e.name, e.x, e.y, c.x, c.y))
      b.occ[k] = p.id
      e.x, e.y = c.x, c.y
      b.stats.poles_moved = (b.stats.poles_moved or 0) + 1
      return true
    else
      n_ghost = n_ghost + 1
    end
  end
  if not e.shift_logged then
    e.shift_logged = true
    log(string.format("[FO-IA1D] %s : projet %d, %s en (%g, %g) ne peut pas bouger : %d tuile(s) reservee(s), %d coupant le reseau, %d refusee(s)",
      f.key or "player", p.id, e.name, e.x, e.y, n_occ, n_link, n_ghost))
  end
  return false
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
    if r == "occupe" and shift_pole(f, surface, p, e) then r = "ok" end
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
  clear_floor(surface, e) -- les bras de la centrale relâchent du charbon sur l'emprise d'une chaudière détruite, même sous le fantôme
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
  -- Lot ELEC2 : point d'appui inaccessible à pied (ni arbre à couper ni chemin : emprise cernée par les foreuses d'un
  -- avant-poste, falaises). Moteur réel, etape1-guide 271828182 : le dernier lot de la fonderie électrique (poteau et 4
  -- foreuses) abandonné 30 fois en 15 min à 28 tuiles de son point d'appui, 182 entités sur 197, 0 foreuse électrique à
  -- 60 min. Le bâtisseur est posé sur la case libre la plus proche du point d'appui (une fois par tâche) ; il rentre
  -- ensuite comme les autres (« home »).
  if t and not t.teleported and job.ax and agent.entity and agent.entity.valid then
    local e = agent.entity
    local spot = e.surface.find_non_colliding_position(e.name, { x = job.ax, y = job.ay }, 8, 0.5)
    if spot then
      t.teleported = true
      e.teleport(spot)
      f.build.stats.build_teleports = (f.build.stats.build_teleports or 0) + 1
      log(string.format("[FO-IA1D] %s : batisseur pose pres du point d'appui (%g, %g), inaccessible a pied", f.key or "player", job.ax, job.ay))
      return "more"
    end
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
            -- Debout sur l'emprise : s'écarter AVANT de payer les jetons (step_aside) ; impossible : laissée sans jetons.
            local blocked = stands_on(e, x) and not find_real(surface, x, f.force) and not step_aside(surface, e, x)
            pos = e.position
            local cost = x.name:find("electric%-pole") and Build.COST_REVIVE_POLE or Build.COST_REVIVE
            if blocked then
              left = left + 1
            elseif not Tokens.take(f, tick, cost) then
              return "more"
            elseif revive_one(surface, f, p, x, inv, tick, e) then
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
      key = "ia1d:" .. p.id .. ":b:" .. k, kind = "ghost", prio = finish_prio(p.prio), domain = p.domain, work = 15 + 2 * bt.n,
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
      key = "ia1d:" .. p.id .. ":c:" .. k, kind = "clear", prio = finish_prio(p.prio + 1), domain = "logistique", work = 30,
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
      local have = Stock.count(f, q.item)
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
  if not p.counted then -- lot CORR-RESEAU : un projet rouvert puis refini ne compte qu'une fois
    p.counted = true
    for _, pt in pairs(p.parts) do
      if pt then b.stats.modules_done = b.stats.modules_done + 1 end
    end
    b.stats.projects_done = b.stats.projects_done + 1
  end
  if p.spec.enceinte then
    log(string.format("[FO-ESPACE] %s : segment d'enceinte fini a %.1f min : %d murs, %d abandonne(s) (tuile refusee 3 fois)", f.key or "player",
      tick / 3600, #p.ents - (p.dropped or 0), p.dropped or 0))
  end
  for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n].built = true end end
  -- lot POTEAUX-MASQUES : le terrain a changé là où ce projet a bâti : les relevés de chunk de cette zone tombent
  if #p.ents > 0 and surface and MASQ[surface.index] then
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, e in ipairs(p.ents) do
      x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
    end
    Mq.invalidate(MASQ[surface.index], math.floor(x0) - 4, math.floor(y0) - 4, math.ceil(x1) + 4, math.ceil(y1) + 4)
  end
  log(string.format("[FO-IA1D] %s : projet %d fini (%s, %d entites, %d fils) a %.1f min", f.key or "player", p.id,
    p.parts[1] and p.parts[1].key or "?", #p.ents, p.wired or 0, tick / 3600))
end

---------------------------------------------------------------------------------------------------
-- Avancement : passe de travail (toutes les Build.PULSE ticks) et pensée d'équipe
---------------------------------------------------------------------------------------------------
local function advance(f, surface, p, tick)
  local b = f.build
  if p.state == "attente" then
    if b.qhead > #b.queue and tick >= (p.plan_after or 0) then p.state = "plan" end
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
      p.masq_n = nil -- lot POTEAUX-MASQUES : l'accord de chunks repart de zéro au prochain plan de ce projet
      p.state = "reserve"
      p.started = tick
      log(string.format("[FO-IA1D] %s : projet %d plan (%s, lot %s, %d entites, %d obstacles) a %.1f min", f.key or "player", p.id,
        p.parts[1].key, p.parts[1].lot, #p.ents, #p.obstacles, tick / 3600))
    elseif wait == "masques" then
      -- lot POTEAUX-MASQUES : le couloir des poteaux n'est pas encore relevé en entier (budget de chunks par essai) ; tout ce qui a
      -- été réservé est rendu, nouvel essai sous peu avec Mq.BUDGET chunks accordés de plus (p.masq_n, lu par masques_view)
      for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
      for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
      for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
      p.ents, p.parts = {}, {}
      p.masq_n = (p.masq_n or 0) + 1
      p.plan_after = tick + Mq.WAIT_TICKS
      p.state, p.reason = "attente", why
    elseif wait == "net" and (p.wait_net or 0) < Build.NET_WAIT_MAX then
      -- lot PLANDIR : le réseau d'un autre projet n'est pas bâti ; tout ce qui a été réservé est rendu, nouvel essai plus tard
      for k, v in pairs(b.occ) do if v == p.id then b.occ[k] = nil end end
      for _, l in pairs(b.lots) do if l.used == p.id then l.used = nil end end
      for _, n in ipairs(sorted_keys(b.net)) do if b.net[n].pid == p.id then b.net[n] = nil end end
      p.ents, p.parts = {}, {}
      p.wait_net = (p.wait_net or 0) + 1
      -- lot POTEAUX-MASQUES (relecture) : après 30 s le cache (Mq.TTL) est tombé ; garder l'ancien accord ferait relire jusqu'à 20
      -- chunks en une seule passe (pic) : l'accord repart de zéro, comme pour tout nouveau plan
      p.masq_n = nil
      p.plan_after = tick + Build.NET_WAIT_TICKS
      p.state, p.reason = "attente", why
    elseif wait == true then
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
    if p.spec.enceinte then craft_walls(f, p) end
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
        if e.wall and not e.built and (e.fails or 0) >= Build.FAIL_LIMIT * 2 then
          -- lot ESPACE : un mur refusé 3 fois (tuile prise, falaise cachée) est abandonné : il ne bloque pas toute l'enceinte
          e.built, e.dropped = true, true
          p.dropped = (p.dropped or 0) + 1
        elseif not e.built and (e.fails or 0) >= Build.FAIL_LIMIT * 2 then
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

--- Lot FACTIONS-BLOQUEES : enlève les tourelles de l'équipe qui recouvrent seules l'emprise d'une entité encore à poser du projet
--- (moteur réel, 20261020 : fantôme d'un tapis refusé « occupe » par gun-turret de la même équipe, 30 refus, fonderie bloquée à 111
--- entités sur 113 de 36 min à la fin ; la pose des tourelles évite désormais les tuiles réservées, ceci reprend les chantiers
--- déjà pris). Rend le nombre d'entités enlevées. Une autre entité sur l'emprise (arbre, falaise, bâtiment) : rien n'est touché.
local function free_own_turrets(f, surface, p)
  local n = 0
  for _, e in ipairs(p.ents) do
    if not e.built then
      local found, list = surface.find_entities_filtered({ area = footprint(e) }), {}
      -- seules les tourelles ENREGISTRÉES de l'équipe (posées par les avant-postes) comptent : jamais celle qu'un joueur a posée
      for _, x in ipairs(found) do
        local mine = x.unit_number ~= nil and f.turrets ~= nil and f.turrets[x.unit_number] ~= nil
        list[#list + 1] = { name = x.name, force = mine and x.force.name or "non-enregistree" }
      end
      if Blocage.own_blockers(list, f.force, T.turret) then
        for _, x in ipairs(found) do
          if x.valid then x.destroy() n = n + 1 end
        end
      end
    end
  end
  return n
end

--- Lot FACTIONS-BLOQUEES : un projet qui n'avance plus depuis 10 min (aucune entité bâtie de plus) est écrit UNE fois par équipe et
--- par cause, journal [FO-BLOQUE] (retour du DC du 29/10 : « elles avancent pas »). Horloge propre (tous les 600 ticks), rien à
--- l'état du jeu hors f.build.noprog (nombres et chaînes).
local STALL_STATES = { plan = true, reserve = true, chantier = true, raccordement = true, bloque = true }
local function watch_stall(f, tick)
  local b = f.build
  if tick < (b.noprog_next or 0) then return end
  b.noprog_next = tick + 600
  b.noprog = b.noprog or {}
  b.noprog_dits = b.noprog_dits or {}
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and STALL_STATES[p.state] then
      local built = count_built(p)
      if p.state == "bloque" then p.bloc_cause, p.bloc_built = Blocage.cause(p.state, p.reason), built end
      -- la cause d'un blocage reste celle du blocage tant qu'aucune entité de plus n'est bâtie (reprise en « chantier » comprise)
      local cause = (p.bloc_cause and p.bloc_built == built) and p.bloc_cause or Blocage.cause(p.state, p.reason)
      local rec, say = Blocage.stall(b.noprog[pid], count_built(p), cause, tick)
      b.noprog[pid] = rec
      if say and not b.noprog_dits[pid .. ":" .. say] then -- lot REBUILD-SUIVI : une fois par (projet, cause), non par cause
        b.noprog_dits[pid .. ":" .. say] = true
        log(string.format("[FO-BLOQUE] %s : projet %d (%s) sans progres depuis %d min : %s ; %d entite(s) baties sur %d, etat %s a %.1f min",
          f.key or "player", p.id, tostring(p.spec.key or p.spec.gen or "?"), math.floor((tick - rec.since) / 3600), say, count_built(p), #p.ents,
          p.state, tick / 3600))
      end
    elseif b.noprog[pid] then
      b.noprog[pid] = nil
    end
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
      local freed = free_own_turrets(f, surface, p) -- lot FACTIONS-BLOQUEES
      if freed > 0 then
        b.stats.turrets_freed = (b.stats.turrets_freed or 0) + freed
        log(string.format("[FO-IA1D] %s : projet %d, %d tourelle(s) de l'equipe enlevee(s) de l'emprise du chantier", f.key or "player", p.id, freed))
      end
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
  watch_stall(f, tick) -- lot FACTIONS-BLOQUEES
  -- 3. lot PLANDIR : moniteur de la centrale finie (premier courant, pannes)
  local pp = b.plant and b.projects[b.plant]
  if pp and pp.state == "fini" then PlantArms.step(f, surface, pp, tick) end
  -- 4. lot CORR-RESEAU : santé de la centrale et du réseau (horloge propre, rien si pas l'heure)
  Rv.step({ plant = Build.plant, cancel = Build.cancel }, f, surface, tick)
  -- 5. lot CORR-ENERGIE : centrale saturée, une centrale de plus (même mécanisme que la première)
  local nb, stale = PlantArms.watch(f, surface, tick)
  for _, id in ipairs(stale or {}) do Build.cancel(f, id, PlantArms.STALE_REASON) end
  if nb then Build.grow_plant(f, nb, tick) end
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

---------------------------------------------------------------------------------------------------
-- Lot ESPACE : croissance du treillis et enceinte (décisions toutes les Enc.CHECK_TICKS ; règles pures : shared/team/enceinte.lua)
---------------------------------------------------------------------------------------------------
local ACTIVE = { attente = true, plan = true, reserve = true, defrichage = true, fantomes = true, chantier = true, raccordement = true }

local function space_info(b)
  local busy = 0
  for _, pid in ipairs(b.order) do
    local p = b.projects[pid]
    if p and ACTIVE[p.state] then busy = busy + 1 end
  end
  return { radius = b.radius, rmax = Build.RADIUS_MAX, pending = math.max(0, #b.queue - b.qhead + 1), free = Enc.free_count(b.lots),
    busy = busy, done = b.stats.projects_done, enc = b.enc ~= nil }
end

local function space_log(b, text)
  b.space_logs = (b.space_logs or 0) + 1
  if b.space_logs <= 40 then log(text) end
end

--- Segment d'enceinte en cours (demandé, pas fini ni refusé) : numéro dans enc.segs, ou nil.
local function active_segment(b, enc)
  for i, sg in ipairs(enc.segs) do
    local p = b.projects[sg.pid]
    if p and p.state ~= "fini" and p.state ~= "refuse" then return i end
  end
  return nil
end

--- Contrôle des murs des segments finis, par paquets de Enc.REPAIR_BATCH murs : un segment qui a perdu un mur est rouvert SEUL
--- (réserve, fantômes, chantier) ; les autres ne bougent pas (lot ENCEINTE2). Les statistiques de projets ne sont pas touchées
--- (un projet rouvert ne se recompte pas : le « fini » suivant l'ignore).
local function repair_enclosure(f, surface, tick)
  local b, enc = f.build, f.build.enc
  if not enc.repair_at then
    for _, sg in ipairs(enc.segs) do
      local p = b.projects[sg.pid]
      if p and p.state == "fini" then enc.repair_at = (p.finished or tick) + Enc.REPAIR_TICKS break end
    end
    if not enc.repair_at then return end
  end
  if tick < enc.repair_at then return end
  local si, ei = enc.cur_s or 1, enc.cur_e or 1
  local budget = Enc.REPAIR_BATCH
  while si <= #enc.segs and budget > 0 do
    local sg = enc.segs[si]
    local p = b.projects[sg.pid]
    if p and p.state == "fini" then
      local last = math.min(#p.ents, ei + budget - 1)
      for i = ei, last do
        local e = p.ents[i]
        if e.built and not e.dropped
          and surface.count_entities_filtered({ position = { e.x, e.y }, radius = 0.4, type = { "wall", "gate" }, limit = 1 }) == 0 then
          e.built, e.ghosted, e.fails, e.npc_blocks = false, false, 0, 0
          sg.lost = (sg.lost or 0) + 1
        end
      end
      budget = budget - math.max(1, last - ei + 1)
      if last >= #p.ents then
        if (sg.lost or 0) > 0 then
          p.state, p.reason, p.reserve_next = "reserve", nil, nil
          p.reopened = (p.reopened or 0) + 1 -- non annulable (Build.cancel) tant que ses murs ne sont pas refaits
          space_log(b, string.format("[FO-ESPACE] %s : %d mur(s) detruit(s) au segment %d (%s) : il reprend son chantier a %.1f min",
            f.key or "player", sg.lost, si, tostring(sg.side), tick / 3600))
        end
        sg.lost = nil
        si, ei = si + 1, 1
      else
        ei = last + 1
      end
    else
      si, ei = si + 1, 1
    end
  end
  if si > #enc.segs then
    enc.cur_s, enc.cur_e, enc.repair_at = nil, nil, tick + Enc.REPAIR_TICKS
  else
    enc.cur_s, enc.cur_e = si, ei
  end
end

--- Menaces connues de l'équipe (nids et vers de sa carte de connaissance, lot IA3-f) : liste { x, y, w } (shared/team/enceinte.lua).
local function known_threats(f)
  local m = f.ai3f and f.ai3f.m
  return Enc.known_threats(m and m.s, f.build.lat, Enc.THREAT_RANGE)
end

--- Demande le segment suivant de l'enceinte `enc` (table de b.enc, ou candidate au premier segment) : (true) ou (false, raison).
--- Le segment est payé sur le stock : au plus un quart de ce que le coffre contient en murs ou permet d'en fabriquer.
local function request_segment(f, enc, tick)
  local b = f.build
  local wr = wall_recipe(f)
  if not wr then return false, "recette" end
  local runs = Enc.runs(b.lat, enc.r, { bounds = enc.bounds })
  local equiv = Stock.count(f, wr.item) + craftable_walls(f, wr)
  local threats = known_threats(f)
  -- lot ENCEINTE3 (lot A) : le segment démarre au bout du tronçon le plus proche de la menace connue de son côté, à défaut du QG
  local seg, why = Enc.next_segment(runs, Enc.run_order(runs, b.lat, threats), enc.claimed, Enc.segment_cap(equiv),
    Enc.run_refs(runs, b.lat, threats))
  if not seg then
    if why == "complet" then enc.complete = true end
    return false, why, equiv
  end
  local tiles = {}
  for _, w in ipairs(seg.walls) do tiles[#tiles + 1] = { w.tx, w.ty } end
  local id, rwhy = Build.request(f, { enceinte = true, walls = tiles, side = seg.side, prio = Build.PRIO - 15, domain = "infrastructures" })
  if not id then return false, rwhy end
  Enc.claim(enc.claimed, seg.walls, true)
  enc.segs[#enc.segs + 1] = { pid = id, n = #seg.walls, side = seg.side }
  space_log(b, string.format("[FO-ESPACE] %s : segment d'enceinte %d demande (projet %d, cote %s, %d murs, stock equivalent %d murs, reste %d a reserver) a %.1f min",
    f.key or "player", #enc.segs, id, seg.side, #seg.walls, equiv, Enc.unclaimed(runs, enc.claimed), tick / 3600))
  return true
end

--- Sauvegarde d'avant ENCEINTE2 : un seul projet pour l'anneau entier. Il devient l'unique segment, et l'enceinte est complète.
local function upgrade_legacy_enclosure(enc)
  enc.claimed = enc.claimed or {}
  enc.segs = { { pid = enc.pid, n = enc.walls or 0, side = "tous" } }
  enc.complete = true
end

--- Un segment refusé ou annulé : ses tuiles sont rendues si c'est la place ou la matière qui a manqué (autrement, les tuiles ne
--- sont pas murables et restent réservées : pas de boucle) ; si rien n'est encore posé, le rayon est libéré comme avant.
local function segment_failed(f, tick, i, p)
  local b, enc = f.build, f.build.enc
  local why = p and p.reason or "projet perdu"
  local transient = why == "materiaux" or why == "place" or p == nil
  space_log(b, string.format("[FO-ESPACE] %s : segment d'enceinte %d refuse (%s)%s", f.key or "player", i, tostring(why),
    transient and " : tuiles rendues, nouvel essai plus tard" or " : tuiles non murables, gardees"))
  table.remove(enc.segs, i)
  enc.cur_s, enc.cur_e = nil, nil
  if transient then
    if p and p.spec and p.spec.walls then
      local list = {}
      for _, w in ipairs(p.spec.walls) do list[#list + 1] = { tx = w[1], ty = w[2] } end
      Enc.claim(enc.claimed, list, nil)
    end
    enc.complete = nil
    enc.retry = tick + Enc.SEG_RETRY_TICKS
  end
  -- plus aucun segment : rayon libere (refus durable de l'enceinte d'une sauvegarde d'avant, dont l'etat « complete » ne
  -- demanderait plus jamais de segment, ou anneau entierement refuse)
  if #enc.segs == 0 and (transient or enc.complete) then
    b.enc, b.enc_retry = nil, tick + Enc.RETRY_TICKS
    enc_release(b) -- lot ENCEINTE3
    space_log(b, string.format("[FO-ESPACE] %s : aucun segment pose, rayon libere, nouvel essai a %.1f min", f.key or "player", (tick + Enc.RETRY_TICKS) / 3600))
  end
end

--- Rapport de l'enceinte (Build.report) : rayon, segments (finis / demandés), murs planifiés, ouvertures.
function Build.enclosure_report(b)
  local enc = b.enc
  local fin, walls = 0, 0
  for _, sg in ipairs(enc.segs or {}) do
    local p = b.projects[sg.pid]
    if p then
      if p.state == "fini" then fin = fin + 1 end
      walls = walls + (p.walls_planned or sg.n or 0)
    end
  end
  return { r = enc.r, segments = #(enc.segs or {}), finished = fin, walls = walls, gates = enc.gates or Enc.gate_count(),
    complete = enc.complete == true, bounds = enc.bounds, tight = enc.bounds ~= nil }
end

--- Une décision de croissance ou d'enceinte (appelée à chaque pensée d'équipe, utile seulement toutes les Enc.CHECK_TICKS).
function Build.space_step(f, surface, tick)
  local b = f.build
  if b.opts.espace == false or tick < (b.space_next or 0) then return end
  b.space_next = tick + Enc.CHECK_TICKS
  local enc = b.enc
  if enc then
    if not enc.segs then upgrade_legacy_enclosure(enc) end
    local ai = active_segment(b, enc)
    if ai then
      -- matière absente depuis 5 min (briques dépensées ailleurs) : segment annulé, sinon il bloquerait le suivant
      local p = b.projects[enc.segs[ai].pid]
      if p and Enc.reserve_stalled(p.state, p.started, p.finished, tick) then Build.cancel(f, p.id, "materiaux") end
    end
    -- segments refusés (plan refusé, annulé) : le dernier d'abord, les numéros restent valables
    for i = #enc.segs, 1, -1 do
      local p = b.projects[enc.segs[i].pid]
      if not p or p.state == "refuse" then
        segment_failed(f, tick, i, p)
        if not b.enc then return end
      end
    end
    repair_enclosure(f, surface, tick)
    if enc.complete or active_segment(b, enc) or tick < (enc.retry or 0) then return end
    local ok, why, equiv = request_segment(f, enc, tick)
    if ok then
      enc.poor = nil
    elseif why == "complet" and #enc.segs == 0 then
      -- toutes les tuiles de l'anneau sont non murables et aucun segment n'existe : le rayon n'a pas de raison d'etre fige
      b.enc, b.enc_retry = nil, tick + Enc.RETRY_TICKS
      enc_release(b) -- lot ENCEINTE3
      space_log(b, string.format("[FO-ESPACE] %s : aucune tuile murable, rayon libere, nouvel essai a %.1f min", f.key or "player", (tick + Enc.RETRY_TICKS) / 3600))
    elseif why == "stock" and not enc.poor then
      enc.poor = true
      space_log(b, string.format("[FO-ESPACE] %s : segment suivant attendu : stock equivalent %d murs, un quart = %d (minimum %d)", f.key or "player",
        equiv or 0, Enc.segment_cap(equiv or 0), Enc.SEG_MIN))
    end
    return
  end
  local info = space_info(b)
  if Enc.grow_due(info) then
    space_log(b, string.format("[FO-ESPACE] %s : le treillis grandit au rayon %d (lots libres %d < %d, chantiers %d, projets finis %d)",
      f.key or "player", b.radius + 1, info.free, Enc.GROW_FREE_MIN, info.busy, info.done))
    Build.grow(f, b.radius + 1)
    return
  end
  local on = b.opts.enceinte
  if on == nil then on = not f.is_player end  -- le joueur garde la main sur ses propres murs
  if not on or tick < (b.enc_retry or 0) or not Enc.enclosure_due(info) then return end
  -- premier segment : le rayon n'est figé (b.enc) que si un segment est vraiment demandé
  -- lot ENCEINTE3 : contour serré sur l'empreinte (bornes figées avec le rayon) ; nil : le rayon, comme avant
  local tight, tinfo = enc_tight_bounds(f)
  local cand = { r = b.radius, claimed = {}, segs = {}, tick = tick, gates = Enc.gate_count(), bounds = tight }
  local ok, why, equiv = request_segment(f, cand, tick)
  if not ok then
    if why == "stock" and not b.space_poor then
      b.space_poor = true
      space_log(b, string.format("[FO-ESPACE] %s : enceinte voulue (rayon %d, %d murs au plus), stock equivalent %d murs : un quart = %d, minimum %d : attente",
        f.key or "player", b.radius, Enc.max_walls(b.radius, { bounds = tight }), equiv or 0, Enc.segment_cap(equiv or 0), Enc.SEG_MIN))
    end
    return
  end
  b.enc = cand
  local out_n = tight and enc_mark_out(b, tight) or 0
  space_log(b, string.format("[FO-ESPACE] %s : enceinte progressive commencee (rayon %d fige, %d murs au plus en tout) a %.1f min", f.key or "player",
    b.radius, Enc.max_walls(b.radius, { bounds = tight }), tick / 3600))
  if tight then
    space_log(b, string.format("[FO-ESPACE] %s : contour serre %d,%d a %d,%d (QG %d,%d ; empreinte %d lots/tourelles gardes, %d isoles dehors, %d lots libres gardes dedans, %d lots ecartes du contour)",
      f.key or "player", tight[1], tight[2], tight[3], tight[4], b.lat.ox, b.lat.oy, tinfo.core, #tinfo.excluded, tinfo.room, out_n))
  end
end

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
  Conv.step(f, surface, tick) -- lot CONVOYEURS : amélioration des tapis saturés, tâche de fond bornée
  -- tronçons encombrés : réévalués (défrichés par les PNJ)
  for _, key in ipairs(sorted_keys(b.segs)) do
    local s = b.segs[key]
    if s.state == "encombre" and s.cleared_tick and tick - s.cleared_tick < 600 then
      b.queue[#b.queue + 1] = { "seg", key }
      s.cleared_tick = nil
    end
  end
  Build.space_step(f, surface, tick)
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
    enceinte = b.enc and Build.enclosure_report(b) or nil,
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
  -- banc seulement (migration des bras de la centrale, lot PLANDIR) : reproduit la conversion électrique des versions 0.6.5 à 0.6.7
  legacy_electric_arms = function(key)
    local f = team_of_key(key)
    local surface = f and surface_of(f)
    return (f and f.build and surface) and PlantArms.legacy_electric(f, surface) or 0
  end,
  set_option = function(key, name, value)
    local f = team_of_key(key)
    if not (f and f.build and (name == "seul" or name == "ghosts_ahead" or name == "sante" or name == "no_grow")) then return nil end -- no_grow : coupe la croissance de la centrale (bancs)
    f.build.opts[name] = value and true or false
    return f.build.opts[name]
  end,
})

return Build
