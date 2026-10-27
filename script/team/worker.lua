--[[
  OUVRIERS d'équipe : agents riches (corps "character") qui exécutent les tâches du cerveau d'équipe.
  Ils marchent, minent à la main, fabriquent (file de fabrication du personnage), portent des objets,
  posent des bâtiments, ravitaillent foreuses, fours et tourelles, et se défendent avec leur arme.

  Une tâche devient un PROGRAMME d'étapes (sérialisable), exécuté par la machine "worker" :
     idle ──(tâche)──▶ step ◀──▶ walk / craft / mine ──(fin)──▶ idle
  Étapes : home (rentrer au QG et y déposer ce qu'on porte), take (prendre au QG), goto, act (action sur
  place : poser un avant-poste, ravitailler...), craft (fabrications successives), mine.
  Une tâche qui échoue rend ce qui a été pris (étape home finale) et rend la main au cerveau.
]]

local FSM = require("script.core.fsm")
local T = require("shared.team.config")
local Scale = require("shared.team.scale")
local Registry = require("script.companion.registry")
local Render = require("script.companion.render")
local Brain = require("script.companion.brain")
local Nav = require("script.agents.nav")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")
local Sites = require("script.faction.sites")
local Board = require("script.team.board")
local Poles = require("script.team.poles") -- lot IA1-b : fin de tâche (O.settle), durées mesurées
local Tokens = require("script.team.tokens") -- lot IA1-b : jetons de travail globaux
local Profiler = require("script.core.profiler")
local Trace = require("script.core.trace")
local Foot = require("shared.levels.footprint")
local Build = require("script.team.build") -- lot IA1-d : plan directeur, construction par fantômes, marche par les rues
local Locomotion = require("script.companion.locomotion")

local Worker = {}

Worker.DANGER_RADIUS = 40 -- lot IA1-b : rayon « nid ou ver » qui écarte un minage ou une garde de fond

local MACHINE = "worker"
local HOME_RADIUS = 6
local MAX_STEPS_PER_THINK = 6
local MINE_TIMEOUT = 90 * 60
local CRAFT_TIMEOUT = 5 * 60 * 60
local DEFENSE_PERIOD = 60
local DEFENSE_RADIUS = 18

local function set(agent, state, tick) FSM.set(MACHINE, agent, state, tick) end

local function faction_of(agent)
  return agent.faction and State.faction(agent.faction) or nil
end

local function main_inv(agent) return agent.entity.get_main_inventory() end

-- Place de chacun au QG. Moteur réel (session 4) : tous les ouvriers rentraient au MÊME point ; empilés,
-- leurs départs suivants se chevauchaient et 150 demandes de chemin échouaient « départ bloqué » (tournées
-- perdues, plaques de fer bloquées dans les fours). Chaque ouvrier a sa case.
-- Lot IA1-a : 64 cases en TABLE CONSTANTE (Scale.HOME_SLOTS ; 16 cases calculées par cos/sin avant), et une
-- case ATTRIBUÉE à chaque PNJ (la première libre, rendue à sa disparition) au lieu de « id modulo 16 » : à
-- 30 PNJ, deux PNJ ne partagent plus une case (F27). Une case couverte par un bâtiment, un arbre ou de l'eau
-- est marquée « bloquée » (contrôle à la fondation, puis 2 cases par pensée d'équipe, à tour de rôle) : un
-- PNJ dont la case se bloque en reçoit une autre au prochain retour. Au-delà de 64 PNJ vivants (ou de cases
-- libres), les cases se partagent (id modulo 64) : réglage maximal 60.
local SLOTS = Scale.HOME_SLOTS

local function slot_tables(f)
  f.slot_owner = f.slot_owner or {}
  f.slot_bad = f.slot_bad or {}
  return f.slot_owner, f.slot_bad
end

local function release_slot(f, agent)
  local i = agent.slot
  if not i then return end
  local owner = slot_tables(f)
  if owner[i] == agent.id then owner[i] = nil end
  agent.slot = nil
end

local function home_slot(agent, f)
  local owner, bad = slot_tables(f)
  local i = agent.slot
  if not i or bad[i] or (owner[i] ~= nil and owner[i] ~= agent.id) then
    if i and owner[i] == agent.id then owner[i] = nil end
    i = Scale.free_slot(bad, owner)
    if i then owner[i] = agent.id end
    agent.slot = i
  end
  local o = SLOTS[i or ((agent.id - 1) % #SLOTS + 1)]
  return { x = f.home_spot.x + o[1], y = f.home_spot.y + o[2] }
end

--- Une case est-elle praticable ? Ni eau, ni entité de la couche des objets (bâtiments, arbres, rochers) sous
--- la boîte d'un corps (0,4 × 0,4, marge 0,1) ; les personnages ne comptent pas (couche des joueurs seule).
local function slot_ok(surface, p)
  local area = { { p.x - 0.5, p.y - 0.5 }, { p.x + 0.5, p.y + 0.5 } }
  if surface.count_tiles_filtered({ area = area, collision_mask = "water-tile", limit = 1 }) > 0 then return false end
  -- Correction IA1-a (mineur 9 de la vérification) : la recherche par zone rend aussi une entité qui TOUCHE
  -- seulement la case (F96, intervalles fermés) ; seul un chevauchement strict la bloque (Foot.overlap).
  local r = { x0 = area[1][1], y0 = area[1][2], x1 = area[2][1], y1 = area[2][2] }
  for _, e in ipairs(surface.find_entities_filtered({ area = area, collision_mask = "object-layer" })) do
    local b = e.bounding_box
    if Foot.overlap(r, { x0 = b.left_top.x, y0 = b.left_top.y, x1 = b.right_bottom.x, y1 = b.right_bottom.y }) then
      return false
    end
  end
  return true
end

--- Revalide `count` cases du QG à tour de rôle (toutes si count = nil : fondation). O(count).
function Worker.check_slots(f, surface, count)
  local _, bad = slot_tables(f)
  local n = #SLOTS
  local k = count or n
  for _ = 1, k do
    local i = (f.slot_cursor or 0) % n + 1
    f.slot_cursor = i
    local o = SLOTS[i]
    bad[i] = not slot_ok(surface, { x = f.home_spot.x + o[1], y = f.home_spot.y + o[2] }) or nil
  end
end

local function dist2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

---------------------------------------------------------------------------------------------------
-- Transferts avec le stock (QG)
---------------------------------------------------------------------------------------------------
local function deposit_inventory(f, inv, keep)
  local contents = inv.get_contents()
  local names = {}
  for name in pairs(contents) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local n = contents[name] - (keep and keep[name] or 0)
    if n > 0 then
      local moved = f.hq.insert({ name = name, count = n })
      if moved > 0 then
        inv.remove({ name = name, count = moved })
        f.team.delivered[name] = (f.team.delivered[name] or 0) + moved
      end
    end
  end
end

--- Dépose au QG tout ce que l'ouvrier porte, sauf son arme et ses munitions de défense.
--- Moteur réel (session 4) : un personnage range lui-même les armes et munitions qu'il FABRIQUE dans ses
--- emplacements d'arme et de munitions (3 × 200 chargeurs) ; en ne vidant que l'inventaire principal, les
--- chargeurs et mitraillettes fabriqués pour l'équipe disparaissaient dans les poches des ouvriers (des
--- milliers de plaques de fer par partie, armée et défense bloquées).
local KEEP_GUN = { [T.worker_gun] = 1 }
local KEEP_AMMO = { [T.worker_ammo] = T.worker_ammo_keep }
local function deposit_all(agent, f)
  if not (f.hq and f.hq.valid) then return end
  local e = agent.entity
  deposit_inventory(f, main_inv(agent), nil)
  local guns = e.get_inventory(defines.inventory.character_guns)
  if guns then deposit_inventory(f, guns, KEEP_GUN) end
  local ammo = e.get_inventory(defines.inventory.character_ammo)
  if ammo then deposit_inventory(f, ammo, KEEP_AMMO) end
  local armor = e.get_inventory(defines.inventory.character_armor)
  if armor then deposit_inventory(f, armor, nil) end
end

--- Prend au QG la liste { {objet, n} }. Renvoie true si tout a été pris.
local function take(agent, f, list)
  local inv = main_inv(agent)
  local all = true
  for _, it in ipairs(list) do
    local want = it[2]
    local n = math.min(want, f.hq.get_item_count(it[1]))
    if n > 0 then
      local got = f.hq.remove_item({ name = it[1], count = n })
      local put = inv.insert({ name = it[1], count = got })
      if put < got then f.hq.insert({ name = it[1], count = got - put }) end
      if put < want then all = false end
    else
      all = false
    end
  end
  return all
end

---------------------------------------------------------------------------------------------------
-- Programmes
---------------------------------------------------------------------------------------------------
--- Point d'accès d'un avant-poste : là où l'ouvrier se tenait en le construisant (atteignable par
--- construction). Moteur réel (session 4) : viser le centre du gisement, désormais couvert de foreuses,
--- faisait échouer le pathfinder (« but occupé ») et les tournées d'entretien.
local function access(o)
  return o.access or o.pos
end
--- Lot IA1-d : programme d'une tâche du plan directeur (script/team/build.lua). build : prise au stock du chantier,
--- point d'appui, ravivages ; clear : défrichage sur place ; fill : remplir un quai ; collect : vider un quai de sortie.
local function ia1d_program(task)
  local j = task.ia1d
  local at = { x = j.ax, y = j.ay }
  if j.mode == "build" then
    return { { "home" }, { "take_res", j.pid, task.items }, { "goto", at, 1 }, { "ia1d" }, { "home" } }
  elseif j.mode == "fill" then
    return { { "home" }, { "take", task.items, strict = true }, { "goto", at, 1 }, { "ia1d" }, { "home" } }
  elseif j.mode == "clear" or j.mode == "collect" then
    return { { "goto", at, 1 }, { "ia1d" }, { "home" } }
  end
  return nil
end

--- Construit le programme d'une tâche au moment où un ouvrier la prend. Renvoie steps ou nil (impossible).
function Worker.program(f, task, surface, tick)
  local k = task.kind
  if task.ia1d then return ia1d_program(task) end
  if k == "craft" then
    return { { "home" }, { "take", task.uses, strict = true }, { "craft", task.steps }, { "home" } }
  elseif k == "build" then
    local site = Sites.find(f, surface, tick, T.outposts[task.outpost_kind].resource)
    if not site then return nil end
    -- Lot IA1-b2 (défendre d'abord, votre équipe) : un site gardé par un nid ou un ver (apparu depuis la prospection)
    -- n'est pas tenté : le constructeur y mourait (essai 9, graine 314159265 : 4 constructeurs tués par des vers à
    -- 421-429 tuiles, un seul avant-poste en 60 min). Le site est écarté comme injoignable.
    if f.is_player and surface.count_entities_filtered({ position = site, radius = Worker.DANGER_RADIUS, force = "enemy",
      type = { "unit-spawner", "turret" }, limit = 1 }) > 0 then
      Sites.mark_unreachable(site, tick)
      return nil
    end
    -- Lot IA1-b2 (D-18, décision de l'orchestrateur), votre équipe : sans tourelle possible, aucun site au-delà de
    -- T.site_max_noturret tuiles ; et un site dont le CHEMIN (segment depuis le QG, un point tous les 32 tuiles) passe à
    -- moins de Worker.DANGER_RADIUS tuiles d'un nid ou d'un ver est écarté (graine 314159265 : sites à 585 tuiles derrière
    -- une ceinture de vers, 4 constructeurs tués vers 425 tuiles). Les vers des chunks pas encore générés ne se voient
    -- pas : la limite de distance couvre ce cas.
    if f.is_player then
      local force = game.forces[f.force]
      local rec = force and force.recipes and force.recipes["gun-turret"]
      local turret_ok = f.hq.get_item_count("gun-turret") > 0 or (rec ~= nil and rec.enabled)
      local d2 = dist2(site, f.hq_pos)
      local bad = (not turret_ok) and d2 > T.site_max_noturret * T.site_max_noturret
      if not bad then
        local d = math.sqrt(d2)
        local steps = math.floor(d / 32)
        for k = 1, steps do
          local q = { x = f.hq_pos.x + (site.x - f.hq_pos.x) * k / (steps + 1), y = f.hq_pos.y + (site.y - f.hq_pos.y) * k / (steps + 1) }
          if surface.count_entities_filtered({ position = q, radius = Worker.DANGER_RADIUS, force = "enemy",
            type = { "unit-spawner", "turret" }, limit = 1 }) > 0 then
            bad = true
            break
          end
        end
      end
      if bad then
        Sites.mark_unreachable(site, tick)
        f.stats.site_refused = (f.stats.site_refused or 0) + 1
        return nil
      end
      -- Prudence par zone : un site près d'une perte récente attend (rendu à la réserve).
      if Poles.near_loss(f, site, tick) then
        f.prospects = f.prospects or {}
        if Sites.room_for(f, site.resource) then table.insert(f.prospects, 1, site) end
        return nil
      end
    end
    Sites.claim(f, site)
    task.site = site
    return { { "home" }, { "take", task.items, strict = true }, { "goto", site, 5 }, { "act", "build" }, { "home" } }
  elseif k == "extend" then
    local o = f.outposts[task.outpost]
    if not o then return nil end
    return { { "home" }, { "take", task.items, strict = true }, { "goto", access(o), 3 }, { "act", "extend" }, { "home" } }
  elseif k == "garrison" then
    -- Lot IA1-b (fond du pôle Territoire) : garde d'un avant-poste ou du QG ; le PNJ tire sur ce qui approche
    -- (autodéfense, rayon DEFENSE_RADIUS) pendant task.wait ticks, puis rentre.
    local pos
    if task.post == "hq" then
      pos = f.home_spot
    else
      local o = f.outposts[task.post]
      pos = o and access(o)
    end
    if not pos then return nil end
    return { { "goto", pos, 6 }, { "wait", task.wait or 3600 }, { "home" } }
  elseif k == "salvage" then
    -- Lot IA2-b (F209) : démontage des réceptacles orphelins d'un avant-poste perdu.
    return { { "home" }, { "goto", task.pos, 4 }, { "act", "salvage" }, { "home" } }
  elseif k == "service" then
    local o = f.outposts[task.outpost]
    if not o then return nil end
    local need = Outposts.coal_needed(o)
    local steps = { { "home" } }
    if need > 0 and o.kind ~= "coal" then steps[#steps + 1] = { "take", { { T.fuel, need } } } end
    steps[#steps + 1] = { "goto", access(o), 3 }
    steps[#steps + 1] = { "act", "service" }
    steps[#steps + 1] = { "home" }
    return steps
  elseif k == "refill" then
    local pos = task.group == "hq" and f.home_spot or Outposts.group_pos(f, task.group)
    if not pos then return nil end
    local o = task.group ~= "hq" and f.outposts[tonumber(task.group:sub(2))]
    if o then pos = access(o) end
    local ammo = Outposts.ammo_name(f.tech)
    return { { "home" }, { "take", { { ammo, 200 }, { "firearm-magazine", 200 } } }, { "goto", pos, 6 }, { "act", "refill" }, { "home" } }
  elseif k == "fortify" then
    -- Lot IA1-b2 : tourelles du QG (défendre d'abord), posées sans quitter le QG.
    if task.outpost == "hq" then return { { "home" }, { "take", task.items, strict = true }, { "act", "fortify" }, { "home" } } end
    local o = f.outposts[task.outpost]
    if not o then return nil end
    return { { "home" }, { "take", task.items, strict = true }, { "goto", access(o), 3 }, { "act", "fortify" }, { "home" } }
  elseif k == "smelters" then
    return { { "home" }, { "take", task.items, strict = true }, { "act", "smelters" }, { "home" } }
  elseif k == "smelt" then
    local list = {}
    local products = {}
    for p in pairs(task.smelt or {}) do products[#products + 1] = p end
    table.sort(products)
    for _, p in ipairs(products) do
      local input = T.smelter_inputs[p]
      if input then list[#list + 1] = { input[1], math.min(input[2] * 20, input[2] * task.smelt[p]) } end
    end
    list[#list + 1] = { T.fuel, Outposts.coal_needed_for(Outposts.smelters(f)) }
    return { { "home" }, { "take", list }, { "act", "smelt" }, { "home" } }
  elseif k == "mine" then
    -- Lot IA1-b : 256 tuiles au lieu de 64 (essai 2 du banc ia1-poles : les 64 tuiles les plus proches d'un gisement
    -- exploité sont toutes sous des foreuses ; le minage échouait sans raison écrite). Au plus 40 tuiles contrôlées.
    -- Lot IA1-b2 (R-QCM-25c (c)) : task.radius (minage de fond de votre équipe : près du coffre, T.near_mine).
    local res = surface.find_entities_filtered({ position = f.hq_pos, radius = task.radius or 96, name = task.resource, limit = 256 })
    table.sort(res, function(a, b)
      local da, db = dist2(a.position, f.hq_pos), dist2(b.position, f.hq_pos)
      if da ~= db then return da < db end
      if a.position.x ~= b.position.x then return a.position.x < b.position.x end
      return a.position.y < b.position.y
    end)
    -- Tuile LIBRE : sous un four ou une foreuse (avant-poste détruit, restes), l'ouvrier sélectionnait le
    -- bâtiment et ne minait rien (moteur réel, E16 it. 11 : 4 minerais livrés en 50 min).
    local best
    local stride = math.max(1, math.floor(#res / 40))
    for i = 1, #res, stride do
      local r = res[i]
      local p = r.position
      local busy = surface.count_entities_filtered({
        area = { { p.x - 0.5, p.y - 0.5 }, { p.x + 0.5, p.y + 0.5 } }, type = "resource", invert = true, limit = 1,
      })
      -- Lot IA1-b : un minage de FOND ne va pas miner à moins de 40 tuiles d'un nid ou d'un ver (morts des PNJ).
      if busy == 0 and task.fond and surface.count_entities_filtered({ position = p, radius = Worker.DANGER_RADIUS,
        force = "enemy", type = { "unit-spawner", "turret" }, limit = 1 }) > 0 then
        busy = 1
      end
      -- Lot IA1-b2 : prudence par zone (votre équipe) : pas de minage de fond près d'une perte récente.
      if busy == 0 and task.fond and f.is_player and Poles.near_loss(f, p, tick) then busy = 1 end
      if busy == 0 then best = r break end
    end
    if not best then return nil end
    task.target = { x = best.position.x, y = best.position.y }
    return { { "home" }, { "goto", task.target, 1.5 }, { "mine", task.resource, task.count }, { "home" } }
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Actions sur place
---------------------------------------------------------------------------------------------------
local ACTS = {}

ACTS.build = function(agent, f, task, surface, tick)
  local o = Outposts.build(f, surface, task.outpost_kind, task.site, main_inv(agent))
  if not o then
    Sites.release(task.site)
    Sites.mark_unreachable(task.site, tick)
    task.site_used = true
    f.stats.build_fail = (f.stats.build_fail or 0) + 1
    return false
  end
  local p = agent.entity.position
  o.access = { x = p.x, y = p.y }
  task.site_used = true
  f.stats.built = (f.stats.built or 0) + 1
  -- Lot IA1-b2 (défendre d'abord) : les tourelles portées avec la construction sont posées sur place, à la même visite.
  local inv = main_inv(agent)
  local nt = inv.get_item_count("gun-turret")
  if nt > 0 then
    local put = Outposts.fortify(f, surface, o, nt, inv)
    f.stats.defend_built = (f.stats.defend_built or 0) + put
  end
  return true
end

ACTS.extend = function(agent, f, task, surface)
  local o = f.outposts[task.outpost]
  if not o then return false end
  local n = Outposts.extend(f, surface, o, main_inv(agent))
  f.stats.extended = (f.stats.extended or 0) + n
  return true
end

ACTS.service = function(agent, f, task, surface, tick)
  local o = f.outposts[task.outpost]
  if not o then return false end
  local n = Outposts.service(o, main_inv(agent), tick)
  f.stats.serviced = (f.stats.serviced or 0) + 1
  f.team.collected = (f.team.collected or 0) + n
  return true
end

ACTS.salvage = function(agent, f, task)
  local n = Outposts.salvage(f, task.orphan, main_inv(agent))
  return n > 0
end

ACTS.refill = function(agent, f, task)
  local n = Outposts.refill_group(f, task.group, main_inv(agent))
  f.stats.refilled = (f.stats.refilled or 0) + n
  return n > 0
end

ACTS.fortify = function(agent, f, task, surface)
  -- Lot IA1-b2 : « hq » = autour du QG (tourelles du groupe « hq », Outposts.turret_groups).
  local o = task.outpost == "hq" and { pos = f.hq_pos } or f.outposts[task.outpost]
  if not o then return false end
  local n = Outposts.fortify(f, surface, o, task.items[1][2], main_inv(agent))
  if task.defend then f.stats.defend_fortified = (f.stats.defend_fortified or 0) + n end
  return n > 0
end

ACTS.smelters = function(agent, f, task, surface)
  local n = Outposts.place_smelters(f, surface, task.count, main_inv(agent))
  return n > 0
end

ACTS.smelt = function(agent, f, task)
  Outposts.service_smelters(f, main_inv(agent), task.smelt)
  return true
end

---------------------------------------------------------------------------------------------------
-- Exécution des étapes
---------------------------------------------------------------------------------------------------
--- Un chantier abandonné avant la pose (stock pris entre-temps...) rend son site à la réserve.
local function return_site(f, task)
  if task and task.site and not task.site_used then
    Sites.release(task.site)
    f.prospects = f.prospects or {}
    -- Lot IA2-c : dans les bornes de la réserve (Sites.room_for) : pendant le chantier, la prospection a pu la
    -- remplir de nouveau (moteur simulé, tests/valeur_test.lua : 4 sites de charbon, 13 en tout).
    if Sites.room_for(f, task.site.resource) then table.insert(f.prospects, 1, task.site) end
    task.site_used = true
  end
end

local function finish(agent, f, ok, tick)
  local task = agent.task
  agent.task = nil
  agent.steps = nil
  if task then
    if not ok then return_site(f, task) end
    Board.finish(f, task, ok, tick)
    Poles.task_done(f, task, ok, tick)
  end
  -- Lot IA1-b : fin de tâche, la destination différée devient le pôle (avant la tâche suivante).
  Poles.settle(f, agent, tick)
  set(agent, "idle", tick)
end

--- Échec : on rapporte au QG ce qu'on porte, puis la tâche est rendue.
local function abort(agent, f, tick, reason)
  if agent.task then agent.task.fail = reason end
  agent.failed = true
  agent.steps = { { "home" } }
  agent.pc = 1
  set(agent, "step", tick)
end

local function goto_step(agent, pos, radius, tick)
  local e = agent.entity
  local p = e.position
  if dist2(p, pos) <= (radius + 1) * (radius + 1) then return true end
  -- Lot IA1-a : but OCCUPÉ (F28 : 128 échecs « but occupé » en 60 min dans ia0-normal, journal archivé du
  -- 21/10) : un point d'accès couvert depuis par une foreuse, une case du QG sous un four, un autre PNJ.
  -- Le but devient le point libre le plus proche (test seulement, aucune entité posée : F26).
  local surface = e.surface
  if not surface.can_place_entity({ name = e.name, position = pos }) then
    local free = surface.find_non_colliding_position(e.name, pos, radius + 6, 0.5)
    if free then
      pos = free
      local f = faction_of(agent)
      if f and f.stats then f.stats.goal_moved = (f.stats.goal_moved or 0) + 1 end
      if dist2(p, pos) <= (radius + 1) * (radius + 1) then return true end
    end
  end
  -- Lot IA1-d : dans le plan directeur, marche par les rues (tronçons OUVERTS, points de passage en Manhattan, sans
  -- pathfinder) ; un PNJ bloqué (aucun progrès pendant 2 pensées) est rendu au PathService (agent.street_off).
  local fb = faction_of(agent)
  if fb and fb.build and not agent.street_off then
    local wp = Build.street_route(fb, p, pos)
    if wp then
      local path = {}
      for i, w in ipairs(wp) do path[i] = { position = w } end
      agent.walk_radius = radius
      agent.goal = pos
      Locomotion.set_path(agent, path)
      agent.last_x, agent.last_y, agent.last_check = p.x, p.y, tick
      agent.stuck = 0
      agent.nav = "moving"
      agent.street_walk = true
      Locomotion.start(agent)
      Build.note_walk(fb, "start")
      set(agent, "walk", tick)
      return false
    end
  end
  agent.walk_radius = radius
  Nav.go(agent, pos, tick, { radius = radius })
  set(agent, "walk", tick)
  return false
end

local function run_steps(agent, tick)
  local f = faction_of(agent)
  if not f or not (f.hq and f.hq.valid) then return end
  local surface = agent.entity.surface
  for _ = 1, MAX_STEPS_PER_THINK do
    local step = agent.steps and agent.steps[agent.pc]
    if not step then
      local ok = not agent.failed
      agent.failed = nil
      finish(agent, f, ok, tick)
      return
    end
    local kind = step[1]
    if kind == "home" then
      if not goto_step(agent, home_slot(agent, f), 1, tick) then return end
      deposit_all(agent, f)
      agent.pc = agent.pc + 1
    elseif kind == "take" then
      local all = take(agent, f, step[2])
      if agent.task then agent.task.took = true end -- lot IA1-b : objets pris (stock libre du fond)
      if step.strict and not all then
        abort(agent, f, tick, "stock")
        return
      end
      agent.pc = agent.pc + 1
    elseif kind == "wait" then
      agent.wait_until = tick + (step[2] or 0)
      set(agent, "wait", tick)
      return
    elseif kind == "goto" then
      if not goto_step(agent, step[2], step[3] or 4, tick) then return end
      agent.street_off = nil -- lot IA1-d : le repli vers le PathService ne vaut que pour ce trajet
      agent.pc = agent.pc + 1
    elseif kind == "take_res" then
      -- Lot IA1-d : objets réservés au chantier (retirés du coffre à la réservation : personne ne les arrache)
      local all = Build.take_reserved(f, step[2], step[3], main_inv(agent))
      if agent.task then agent.task.took = true end
      if not all then
        local any = false
        for _, it in ipairs(step[3]) do if main_inv(agent).get_item_count(it[1]) > 0 then any = true break end end
        if not any then
          abort(agent, f, tick, "stock")
          return
        end
      end
      agent.pc = agent.pc + 1
    elseif kind == "ia1d" then
      local j = agent.task and agent.task.ia1d
      if not j then
        abort(agent, f, tick, "chantier")
        return
      end
      agent.ia1d = { pid = j.pid, mode = j.mode, anchor = j.anchor, idx = j.idx, seg = j.seg, rect = j.rect, ax = j.ax, ay = j.ay }
      set(agent, "ia1d", tick)
      return
    elseif kind == "act" then
      Trace.log("act", step[2], f.key)
      local fn = ACTS[step[2]]
      local ok = fn and fn(agent, f, agent.task, surface, tick)
      if not ok then
        abort(agent, f, tick, step[2])
        return
      end
      agent.pc = agent.pc + 1
    elseif kind == "craft" then
      agent.craft_i = 1
      agent.craft_started = tick
      set(agent, "craft", tick)
      return
    elseif kind == "mine" then
      agent.mine_started = tick
      agent.mine_base = agent.entity.get_item_count(step[2])
      set(agent, "mine", tick)
      return
    else
      agent.pc = agent.pc + 1
    end
  end
end

--- Autodéfense : un ouvrier armé tire sur l'ennemi le plus proche (déchiqueteurs, autres factions).
local function defend(agent, tick)
  if tick - (agent.defense_tick or 0) < DEFENSE_PERIOD then return end
  agent.defense_tick = tick
  local e = agent.entity
  local enemy = e.surface.find_nearest_enemy({ position = e.position, max_distance = DEFENSE_RADIUS, force = e.force })
  if enemy and e.get_item_count(T.worker_ammo) + e.get_item_count("piercing-rounds-magazine") > 0 then
    e.shooting_state = { state = defines.shooting.shooting_enemies, position = enemy.position }
    agent.shooting = true
    local f = faction_of(agent)
    if f then f.stats.worker_shots = (f.stats.worker_shots or 0) + 1 end
  elseif agent.shooting then
    e.shooting_state = { state = defines.shooting.not_shooting, position = e.position }
    agent.shooting = nil
  end
end

FSM.define(MACHINE, {
  idle = {
    think = function(agent, tick)
      defend(agent, tick)
      local f = faction_of(agent)
      if not f or f.eliminated then return end
      -- Lot IA1-b : une prise de tâche coûte des jetons de travail (budget par tick pour tout le mod).
      if not Tokens.take(f, tick, Tokens.COST_CLAIM) then return end
      local task = Board.claim(f, agent, tick)
      if not task then
        -- Rien à faire : rentrer au QG (et y déposer) plutôt que rester au loin.
        if dist2(agent.entity.position, home_slot(agent, f)) > 3 * 3 and not agent.nav then
          agent.task, agent.steps, agent.pc = nil, { { "home" } }, 1
          set(agent, "step", tick)
        end
        return
      end
      local steps = Worker.program(f, task, agent.entity.surface, tick)
      if not steps then
        task.fail = task.fail or "programme" -- lot IA1-b : raison écrite (minerai introuvable, avant-poste disparu)
        Board.finish(f, task, false, tick)
        Poles.task_done(f, task, false, tick)
        return
      end
      agent.task, agent.steps, agent.pc, agent.failed = task, steps, 1, nil
      set(agent, "step", tick)
    end,
  },
  step = {
    think = function(agent, tick)
      defend(agent, tick)
      run_steps(agent, tick)
    end,
  },
  -- Lot IA1-d : travail sur place du plan directeur (ravivages, défrichage, quais) : script/team/build.lua.
  ia1d = {
    think = function(agent, tick)
      defend(agent, tick)
      local f = faction_of(agent)
      if not f then return end
      local r = Build.work(agent, f, tick)
      if r == "more" then return end
      agent.ia1d = nil
      if r == "again" then
        -- refaire la marche vers le point d'appui (étape précédente), depuis la position atteinte
        agent.pc = agent.pc - 1
        set(agent, "step", tick)
        return
      end
      if r == "done" then
        agent.pc = agent.pc + 1
        set(agent, "step", tick)
      else
        abort(agent, f, tick, "chantier")
      end
    end,
  },
  -- Lot IA1-b : attente sur place (garnison) ; l'autodéfense tourne.
  wait = {
    think = function(agent, tick)
      defend(agent, tick)
      if tick >= (agent.wait_until or 0) then
        agent.pc = agent.pc + 1
        set(agent, "step", tick)
      end
    end,
  },
  walk = {
    think = function(agent, tick)
      defend(agent, tick)
      Nav.think(agent, tick)
    end,
    exit = function(agent, tick) if agent.nav then Nav.stop(agent, tick) end end,
    on = {
      nav_arrived = function(agent, tick)
        if agent.street_walk then
          agent.street_walk = nil
          local fa = faction_of(agent)
          if fa then Build.note_walk(fa, "ok") end
        end
        set(agent, "step", tick)
      end,
      nav_failed = function(agent, tick)
        local f = faction_of(agent)
        -- Lot IA1-d : PNJ bloqué dans une rue : rendu au PathService pour la suite de ce trajet (compté).
        if agent.street_walk then
          agent.street_walk = nil
          agent.street_off = true
          if f then Build.note_walk(f, "stuck") end
        end
        local reason = agent.nav_fail or "no_path"
        agent.walk_retries = (agent.walk_retries or 0) + 1
        if f then f.stats.nav_fail = (f.stats.nav_fail or 0) + 1 end
        if agent.walk_retries <= 3 and reason ~= "no_path" then
          set(agent, "step", tick) -- nouvel essai depuis la position atteinte
          return
        end
        agent.walk_retries = 0
        local step = agent.steps and agent.steps[agent.pc]
        -- Lot IA1-d : un défricheur ou un bâtisseur arrêté en route travaille là où il est (il s'ouvre le chemin vers son
        -- point d'appui, script/team/build.lua)
        if step and step[1] == "goto" and agent.task and agent.task.ia1d
          and (agent.task.ia1d.mode == "clear" or agent.task.ia1d.mode == "build") then
          agent.pc = agent.pc + 1
          set(agent, "step", tick)
          return
        end
        if step and step[1] == "home" then
          -- Ne jamais rester égaré : rappel au QG (le dépôt se fait à l'arrivée).
          local e = agent.entity
          local spot = f and e.surface.find_non_colliding_position(e.name, home_slot(agent, f), 20, 0.5)
          if spot then
            e.teleport(spot)
            if f then f.stats.rescued = (f.stats.rescued or 0) + 1 end
          end
          set(agent, "step", tick)
          return
        end
        if f and agent.task and agent.task.site and not agent.task.site_used then
          Sites.release(agent.task.site)
          Sites.mark_unreachable(agent.task.site, tick)
          agent.task.site_used = true
        end
        if f and Profiler.enabled() and agent.entity.valid then
          local p = agent.entity.position
          log(string.format("[FO-TEAM] %s : ouvrier %d, chemin introuvable (%s) depuis (%d,%d) pour %s",
            f.key, agent.id, reason, math.floor(p.x), math.floor(p.y), agent.task and agent.task.key or "?"))
        end
        abort(agent, f, tick, "chemin")
      end,
    },
  },
  craft = {
    think = function(agent, tick)
      defend(agent, tick)
      local e = agent.entity
      if e.crafting_queue_size > 0 then
        if tick - agent.craft_started > CRAFT_TIMEOUT then
          abort(agent, faction_of(agent), tick, "fabrication")
        end
        return
      end
      local step = agent.steps[agent.pc]
      local list = step[2]
      local c = list[agent.craft_i]
      if not c then
        local f = faction_of(agent)
        if f then f.stats.crafted = (f.stats.crafted or 0) + 1 end
        agent.pc = agent.pc + 1
        set(agent, "step", tick)
        return
      end
      local n = e.begin_crafting({ count = c.runs, recipe = c.recipe, silent = true })
      if n < c.runs then
        local f = faction_of(agent)
        if f then f.stats.craft_fail = (f.stats.craft_fail or 0) + 1 end
        if n == 0 then
          abort(agent, f, tick, "fabrication")
          return
        end
      end
      agent.craft_i = agent.craft_i + 1
    end,
  },
  mine = {
    think = function(agent, tick)
      defend(agent, tick)
      local e = agent.entity
      local step = agent.steps[agent.pc]
      local item, count = step[2], step[3]
      local got = e.get_item_count(item) - (agent.mine_base or 0)
      local target = agent.task and agent.task.target
      local res = target and e.surface.find_entities_filtered({ position = target, radius = 2.5, name = item, limit = 1 })[1]
      if got >= count or not res or tick - agent.mine_started > MINE_TIMEOUT then
        e.mining_state = { mining = false }
        local f = faction_of(agent)
        if f then f.stats.mined = (f.stats.mined or 0) + got end
        agent.pc = agent.pc + 1
        set(agent, "step", tick)
        return
      end
      e.update_selected_entity(res.position)
      e.mining_state = { mining = true, position = res.position }
    end,
  },
})

FSM.observe(MACHINE, function(agent) Render.state_changed(agent) end)

--- Recrute un ouvrier équipé de son kit (déjà retiré du stock), ou SANS arme (secours : unarmed).
--- free = kit OFFERT (effectif de départ, lot IA1-a) : jamais rendu au coffre quand on renvoie l'équipe.
function Worker.recruit(f, surface, tick, unarmed, free)
  -- Lot IA1-a : la recrue naît sur SA case (la première libre), pas au point de rassemblement : 8 recrues
  -- posées au même point se gênaient au départ (essai court du banc ia1-scale : 15 % d'échecs « départ bloqué »).
  local owner, bad = slot_tables(f)
  local i = Scale.free_slot(bad, owner)
  local o = i and SLOTS[i]
  local at = o and { x = f.home_spot.x + o[1], y = f.home_spot.y + o[2] } or f.home_spot
  local agent = Registry.spawn(surface, at, f.force, nil, {
    machine = MACHINE, faction = f.id, behavior = "worker", color = f.color,
  })
  if not agent then return nil end
  if i then
    owner[i] = agent.id
    agent.slot = i
  end
  local e = agent.entity
  if not unarmed then
    e.get_inventory(defines.inventory.character_guns).insert({ name = T.worker_gun, count = 1 })
    e.get_inventory(defines.inventory.character_ammo).insert({ name = T.worker_ammo, count = T.worker_ammo_keep })
  end
  if free or unarmed then agent.free_kit = true end
  f.engineers[agent.id] = true
  f.engineers_count = f.engineers_count + 1
  home_slot(agent, f) -- case attribuée dès le recrutement (lot IA1-a)
  Brain.attach(agent, tick, "idle")
  return agent
end

function Worker.idle_count(f)
  local n = 0
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a and not a.task then n = n + 1 end
  end
  return n
end

function Worker.counts(f)
  local states = {}
  for _, id in ipairs(State.sorted_keys(f.engineers)) do
    local a = Registry.get(id)
    if a then
      local key = a.task and a.task.kind or a.state
      states[key] = (states[key] or 0) + 1
    end
  end
  return states
end

Registry.on_removed(function(agent)
  if not agent.faction then return end
  local f = State.faction(agent.faction)
  if not f or not f.engineers[agent.id] then return end
  release_slot(f, agent)
  f.engineers[agent.id] = nil
  f.engineers_count = (f.engineers_count or 1) - 1
  if f.stats then f.stats.engineers_lost = (f.stats.engineers_lost or 0) + 1 end
  -- Lot IA1-b2 (mesure) : PNJ TUÉ (cause connue) : tâche, distance au QG, cause ; tués par les ennemis comptés à part.
  if agent.death_cause and f.stats then
    if agent.death_cause:find("/enemy:", 1, true) then f.stats.lost_enemy = (f.stats.lost_enemy or 0) + 1 end
    local p = agent.death_pos
    local d = (p and f.hq_pos) and math.floor(math.sqrt(dist2(p, f.hq_pos))) or -1
    local t = agent.task
    log(string.format("[FO-TEAM] %s : PNJ %d tue (%s) a %d tuiles du QG, tache %s%s, %.1f min", f.key or "player",
      agent.id, agent.death_cause, d, t and t.kind or "aucune", (t and t.fond) and " (fond)" or "",
      game.tick / 3600))
    -- Lot IA1-b2 (défendre d'abord) : l'avant-poste vers lequel allait le PNJ tué devient MEURTRIER (date gardée) : le
    -- cerveau n'y envoie plus personne pendant T.lethal_ticks, sauf pour y poser des tourelles.
    local oid = t and (t.outpost or (type(t.post) == "number" and t.post) or nil)
    if not oid and t and type(t.group) == "string" and t.group:sub(1, 1) == "o" then oid = tonumber(t.group:sub(2)) end
    local o = oid and f.outposts and f.outposts[oid]
    if o then o.lethal_tick = game.tick end
    -- Constructeur de votre équipe tué : les sites connus à moins de 64 tuiles du lieu de la mort sont écartés (les vers
    -- n'existent qu'une fois leur chunk généré, à l'approche : la vérification du site avant le départ ne les voit pas ;
    -- essai 10, graine 314159265 : 4 constructeurs tués au même endroit).
    if f.is_player and t and t.kind == "build" and p then
      for _, s in ipairs(f.prospects or {}) do
        if dist2(s, p) <= 64 * 64 then Sites.mark_unreachable(s, game.tick) end
      end
    end
  end
  if agent.task then
    if agent.task.site and not agent.task.site_used then
      Sites.release(agent.task.site)
      Sites.mark_unreachable(agent.task.site, game.tick)
    end
    Board.finish(f, agent.task, false, game.tick)
  end
end)

return Worker
