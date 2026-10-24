--[[
  Équipe IA, côté runtime : relie le CERVEAU D'ÉQUIPE pur (shared/team/planner.lua) au monde réel.

  Une pensée (appelée par le commandant, une fois toutes les think_period ticks) :
    1. vue de l'équipe : stock réel du QG, avant-postes (charbon, production en attente), tourelles,
       fonderie, ouvriers, soldats, tâches en cours ;
    2. le cerveau décide : objectif, ce qui manque, tâches ;
    3. le tableau des tâches est mis à jour, les ouvriers s'y servent ;
    4. décisions immédiates sur le stock : recruter un ouvrier, équiper des soldats, payer une recherche.
  Tout ce qui est consommé sort du coffre du QG : aucune monnaie abstraite.
]]

local Events = require("script.core.events")
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local Scale = require("shared.team.scale")
local O = require("shared.team.org")
local ChefRules = require("shared.faction.chef") -- lot IA2-a : ordre des objectifs choisi par le chef
local Config = require("script.core.config")
local Registry = require("script.companion.registry")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")
local Military = require("script.faction.military")
local Sites = require("script.faction.sites")
local Board = require("script.team.board")
local Worker = require("script.team.worker")
local Profiler = require("script.core.profiler")
local Trace = require("script.core.trace")

local Team = {}

-- Livres de recettes par (force, niveau) : reconstruits à la demande (jamais dans global).
local books = {}

-- Lot PNJ-VÉRIF (défaut M2) : pour l'équipe du JOUEUR, la clé reste « player:0 » (le joueur recherche lui-même) :
-- un livre construit avant la recherche « Tourelles » ne voyait jamais la recette (moteur réel : 0 tourelle en
-- 29 min avec 4 500 fer au coffre). Le livre est oublié dès que les recherches d'une force changent ; il est
-- refait depuis l'état du jeu, comme après un chargement : tous les pairs ont donc le même livre (avant, une
-- partie rechargée pouvait en avoir un autre que le serveur).
-- Seuls les livres de la force concernée sont oubliés : oublier tous les livres à chaque technologie débloquée
-- faisait reconstruire ceux de toutes les forces (banc `default`, machine chargée : 98 pics « team » de plus de
-- 2 ms avec l'oubli total, 65 avec l'oubli par force ; décisions identiques au tick près).
local function forget_books() books = {} end
local function forget_force(force)
  if not (force and force.valid) then
    forget_books()
    return
  end
  local prefix = force.name .. ":"
  local keys = {}
  for k in pairs(books) do
    if k:sub(1, #prefix) == prefix then keys[#keys + 1] = k end
  end
  table.sort(keys)
  for _, k in ipairs(keys) do books[k] = nil end
end
Events.on(defines.events.on_research_finished, function(e) forget_force(e.research and e.research.force) end)
Events.on(defines.events.on_research_reversed, function(e) forget_force(e.research and e.research.force) end)
Events.on(defines.events.on_technology_effects_reset, function(e) forget_force(e.force) end)
Events.on(defines.events.on_force_reset, function(e) forget_force(e.force) end)

local function book_for(f)
  local key = f.force .. ":" .. f.tech
  local b = books[key]
  if not b then
    local force = game.forces[f.force]
    b = Book.from_game(game.recipe_prototypes, {
      allowed = function(name)
        local r = force.recipes[name]
        return r ~= nil and r.enabled
      end,
    })
    books[key] = b
  end
  return b
end

local function unlock(f, level)
  local force = game.forces[f.force]
  for _, name in ipairs(T.unlocks[level] or {}) do
    local tech = force.technologies[name]
    if tech then tech.researched = true end
  end
end

-- Lot PNJ-VÉRIF (défaut M1) : une partie d'avant la correction n'a jamais reçu « gun-turret » (T.unlocks[0] nommait
-- « turrets », absent en 1.1.91). À la mise à jour du mod, chaque faction vivante reçoit de nouveau les technologies
-- de ses niveaux 0 à f.tech (une technologie déjà recherchée ne change pas). Le livre de recettes est aussi oublié.
Events.on_configuration_changed(function()
  forget_books()
  local war = State.war()
  if not (war and war.active and war.factions) then return end
  for _, id in ipairs(State.sorted_keys(war.factions)) do
    local f = war.factions[id]
    if f.team and not f.is_player and not f.eliminated and game.forces[f.force] then
      for level = 0, f.tech or 0 do unlock(f, level) end
    end
  end
end)

local function stock_of(f)
  return f.hq.get_inventory(defines.inventory.chest).get_contents()
end

local function remove_list(f, list, times)
  for _, it in ipairs(list) do
    local n = it[2] * (times or 1)
    if n > 0 then f.hq.remove_item({ name = it[1], count = n }) end
    f.team.consumed[it[1]] = (f.team.consumed[it[1]] or 0) + n
  end
end

local function has_list(stock, list, times)
  for _, it in ipairs(list) do
    if (stock[it[1]] or 0) < it[2] * (times or 1) then return false end
  end
  return true
end

---------------------------------------------------------------------------------------------------
-- Fondation
---------------------------------------------------------------------------------------------------
--- Zone de départ d'une équipe (session 4) : un gisement de chaque ressource de base à ~45 tuiles du QG,
--- comme la zone de départ du joueur. Moteur réel : à 480 tuiles du centre, la carte vanilla ne place
--- que ~1 gisement de chaque minerai par faction (F15) ; certaines équipes n'avaient ni fer ni charbon
--- accessibles et restaient bloquées dès le 2e objectif.
local SEED_RADIUS_MAX = 11 -- le plus grand rayon de T.seed_radius (contrôle de l'eau)
local SEED_AMOUNT = 3000
-- Directions essayées dans l'ordre, à Scale.SEED_DIST (46) tuiles : table CONSTANTE (lot IA1-a ; cos/sin des
-- angles 0,35 ; 1,9 ; 3,45 ; 5,0 ; 2,7 ; 4,2 ; 5,8 ; 1,1 rad avant, mêmes valeurs à 17 chiffres).
local SEED_OFFSETS = Scale.SEED_OFFSETS

local function seed_resources(f, surface)
  f.prospects = {}
  local used = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local res = T.outposts[kind].resource
    local radius = T.seed_radius[kind] or 8
    for i, d in ipairs(SEED_OFFSETS) do
      if not used[i] then
        local c = { x = math.floor(f.hq_pos.x + d[1]) + 0.5, y = math.floor(f.hq_pos.y + d[2]) + 0.5 }
        local water = surface.count_tiles_filtered({ position = c, radius = SEED_RADIUS_MAX + 2, collision_mask = "water-tile" })
        if water == 0 then
          used[i] = true
          for _, e in ipairs(surface.find_entities_filtered({ position = c, radius = radius + 1, type = "resource" })) do e.destroy() end
          for dx = -radius, radius do
            for dy = -radius, radius do
              if dx * dx + dy * dy <= radius * radius then
                surface.create_entity({ name = res, position = { c.x + dx, c.y + dy }, amount = SEED_AMOUNT })
              end
            end
          end
          f.prospects[#f.prospects + 1] = { x = c.x, y = c.y, resource = res, seeded = true }
          break
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Taille de l'équipe (lot IA1-a : settings/team.lua, shared/team/scale.lua)
---------------------------------------------------------------------------------------------------
--- Maximum de PNJ de l'équipe : votre équipe, fo-player-team-npc-max ; une faction, le nombre donné au
--- lancement de la guerre, ou fo-war-workers (lu à chaque pensée) si la guerre a été lancée sans nombre.
function Team.npc_max(f)
  if f.is_player then return Config.get("player_npc_max") end
  local s = State.war().settings or {}
  if s.npc_from_setting or not s.engineers_max then return Config.get("npc_max") end
  return s.engineers_max
end

--- Époque de l'équipe pour le plafond d'effectif : niveau de recherche + 1 (sans effet sous Q-IA1-2 (2), où le
--- plafond vaut le maximum dès l'époque 1 ; l'époque réelle des factions arrive au lot IA1-f).
local function epoch_of(f) return (f.tech or 0) + 1 end

--- Premiers PNJ d'une équipe (kits offerts) : fo-npc-start, borné par le plafond de l'époque 1. Les cases du QG
--- sont contrôlées avant (fondation ou refondation).
local function first_workers(f, surface)
  f.slot_owner, f.slot_bad, f.slot_cursor = {}, {}, 0
  Worker.check_slots(f, surface)
  local n = Scale.start_headcount(Config.get("npc_start"), Team.npc_max(f))
  for _ = 1, n do Worker.recruit(f, surface, game.tick, false, true) end
  return n
end

--- Prépare l'équipe d'un QG fraîchement posé : stock de départ, technologies de base, premiers ouvriers.
function Team.init(f, surface)
  if f.is_player then
    -- Équipe du joueur : aucun stock offert, aucune technologie débloquée (le joueur recherche lui-même),
    -- les gisements sont ceux de la carte ; les ouvriers sont recrutés avec des équipements du coffre.
    -- Lot IA1-a (Q-IA1-2 (2), « même règle pour votre équipe ») : fo-npc-start PNJ offerts à la pose du coffre
    -- (kits jamais rendus par « /fo-team dismiss »), puis les recrues se paient au coffre.
    f.team = {
      done = {}, goal = nil, missing = {}, board = { tasks = {}, cooldown = {} },
      delivered = {}, consumed = {}, task_stats = {}, fail_reasons = {}, collected = 0,
      trained = 0, researched_at = {}, deferred = {}, goal_since = game.tick,
    }
    f.team.goal = T.player_ladder[1].key
    f.smelters = f.smelters or {}
    f.prospects = f.prospects or {}
    f.home_spot = surface.find_non_colliding_position("fo-companion", { x = f.hq_pos.x, y = f.hq_pos.y + 3 }, 20, 0.5)
      or { x = f.hq_pos.x, y = f.hq_pos.y + 3 }
    first_workers(f, surface)
    return
  end
  f.team = {
    done = {}, goal = nil, missing = {}, board = { tasks = {}, cooldown = {} },
    delivered = {}, consumed = {}, task_stats = {}, fail_reasons = {}, collected = 0,
    trained = 0, researched_at = {}, deferred = {}, goal_since = game.tick,
  }
  f.team.goal = T.ladder[1].key
  f.smelters = {}
  local inv = f.hq.get_inventory(defines.inventory.chest)
  for _, it in ipairs(T.start_kit) do inv.insert({ name = it[1], count = it[2] }) end
  f.home_spot = surface.find_non_colliding_position("fo-companion", { x = f.hq_pos.x - 6, y = f.hq_pos.y + 8 }, 20, 0.5)
    or { x = f.hq_pos.x - 6, y = f.hq_pos.y + 8 }
  unlock(f, 0)
  seed_resources(f, surface)
  -- Fonderie de départ : les fours sont posés avec le stock (comme les premiers fours d'un joueur).
  local inv2 = f.hq.get_inventory(defines.inventory.chest)
  local tmp = game.create_inventory(8)
  tmp.insert({ name = T.SMELTER, count = inv2.remove({ name = T.SMELTER, count = T.start_smelters }) })
  tmp.insert({ name = T.fuel, count = inv2.remove({ name = T.fuel, count = T.fuel_per_burner * T.start_smelters }) })
  Outposts.place_smelters(f, surface, T.start_smelters, tmp)
  for name, n in pairs(tmp.get_contents()) do inv2.insert({ name = name, count = n }) end
  tmp.destroy()
  first_workers(f, surface) -- lot IA1-a : fo-npc-start (8) au lieu de T.start_workers (2)
end

---------------------------------------------------------------------------------------------------
-- Vue
---------------------------------------------------------------------------------------------------
function Team.view(f, tick)
  local war = State.war()
  local soldiers_max = f.is_player and 0 or war.settings.soldiers_max
  -- Lot IA1-a : plafond d'effectif de l'époque (Q-IA1-2 (2) : le maximum dès l'époque 1), recrue au prix
  -- O.recruit_cost, recrutement suspendu au-delà de fo-agents-max agents riches (garde comptée en agents).
  local workers_max = Team.npc_max(f)
  local workers_wanted = Scale.workers_wanted(epoch_of(f), workers_max)
  local recruit_cost = Scale.recruit_cost(f.engineers_count)
  local recruit_blocked = Registry.count() >= Config.get("agents_max")
  -- Correction IA1-a (défauts M1, M2) : frein par le travail. Plus de fo-recruit-idle-max PNJ sans tâche :
  -- aucune recrue (ni équipement de recrue fabriqué) ; le stock reste aux objectifs et à l'armée.
  local workers_idle = Worker.idle_count(f)
  -- Plancher (correction 3) : sous son effectif de départ, une équipe se reconstruit sans frein.
  local recruit_held = Scale.recruit_held(workers_idle, Config.get("recruit_idle_max"), f.engineers_count or 0,
    Scale.start_headcount(Config.get("npc_start"), workers_max))
  local pend, smelters_pending, fortify_open = Board.pending(f)
  local outposts = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local st = Outposts.status(o, tick)
    outposts[#outposts + 1] = {
      id = oid, kind = o.kind, drills = o.drills, full = o.full or false, turrets = st.turrets, coal_needed = Outposts.coal_needed(o),
      fuel_low = st.fuel_low, output = st.output, idle_ticks = st.idle_ticks,
      has_task = Board.has(f, "service:" .. oid), has_fortify = fortify_open[oid] or false,
    }
  end
  local sites = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do sites[kind] = Sites.available(f, T.outposts[kind].resource) end
  local groups = {}
  for _, g in ipairs(Outposts.turret_groups(f)) do
    groups[#groups + 1] = { key = g.key, low = g.low, has_task = Board.has(f, "refill:" .. g.key) }
  end
  local smelter_out, smelter_low = Outposts.smelters_status(f)
  return {
    tech = f.tech, personality = f.personality, done = f.team.done, deferred = f.team.deferred,
    stock = stock_of(f), incoming = Board.incoming(f),
    outposts = outposts, pending = pend, sites = sites,
    smelters = #Outposts.smelters(f), smelters_pending = smelters_pending,
    smelter_task = Board.has(f, "smelt"), smelter_output = smelter_out, smelter_fuel_low = smelter_low,
    smelter_coal = Outposts.coal_needed_for(Outposts.smelters(f)),
    turret_groups = groups,
    soldiers = f.soldiers_count, soldiers_max = soldiers_max,
    workers = f.engineers_count, workers_max = workers_max, workers_idle = workers_idle,
    workers_wanted = workers_wanted, recruit_cost = recruit_cost, recruit_blocked = recruit_blocked,
    recruit_held = recruit_held,
    -- Lot IA2-a : une faction suit l'ordre des objectifs de son chef (T.ladder réordonné selon ses postures,
    -- prérequis gardés) ; sans chef (avant sa première pensée), T.ladder.
    ladder = f.is_player and T.player_ladder or ChefRules.ladder_entries(f.chef), no_research = f.is_player or false,
    threatened = tick < (f.threatened_until or 0),
    open = Board.open(f),
  }
end

---------------------------------------------------------------------------------------------------
-- Mesures publiées (lot IA1-a, docs/EQUIPES_PNJ.md §16) : inactivité RÉELLE (PNJ sans tâche à la pensée) et
-- exécutants AU-DELÀ DU CARNET (O.pole_targets : travail ouvert + restant à l'horizon de 5 min), séparément.
-- Cumulées par pensée dans f.team.scale (lues par l'interface « fo-ia1 » ; moyennes = sommes / pensées).
---------------------------------------------------------------------------------------------------
function Team.measure(f, view, tick)
  local b = Board.get(f)
  local orientation = f.is_player and "equilibre" or (O.PERSONALITY[f.personality] or "equilibre")
  local m = Scale.metrics(b.list, f.engineers_count, view.workers_idle or 0, orientation, view.threatened, tick)
  local acc = f.team.scale or { thinks = 0, n_sum = 0, idle_sum = 0, surplus_sum = 0, backlog_sum = 0 }
  f.team.scale = acc
  acc.thinks = acc.thinks + 1
  acc.n_sum = acc.n_sum + m.n
  acc.idle_sum = acc.idle_sum + m.idle
  acc.surplus_sum = acc.surplus_sum + m.surplus
  acc.backlog_sum = acc.backlog_sum + m.backlog_s
  acc.last = m
  return m
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
function Team.think(f, surface, tick)
  if not f.team then return nil end
  Trace.log("team", f.key, #State.sorted_keys(f.outposts))
  Profiler.start("team:view")
  local view = Team.view(f, tick)
  Profiler.stop("team:view")
  Profiler.start("team:plan")
  local plan = Planner.plan(view, book_for(f))
  Profiler.stop("team:plan")

  for _, key in ipairs(plan.reached) do
    if not f.team.done[key] then
      f.team.done[key] = true
      f.team.researched_at[key] = tick
      log(string.format("[FO-TEAM] %s : objectif atteint '%s' a %.1f min", f.key, key, (tick - (f.started or State.war().started)) / 3600))
    end
  end
  -- Patience : un objectif qui ne progresse plus est mis de côté un temps (voir T.goal_patience).
  if plan.goal ~= f.team.goal then
    f.team.goal_since = tick
  elseif plan.goal and tick - (f.team.goal_since or tick) > T.goal_patience then
    f.team.deferred[plan.goal] = tick + T.goal_defer
    f.team.goal_since = tick
    log(string.format("[FO-TEAM] %s : objectif '%s' mis de cote (aucun progres en %d min)", f.key, plan.goal, T.goal_patience / 3600))
  end
  for _, key in ipairs(State.sorted_keys(f.team.deferred)) do
    if tick >= f.team.deferred[key] then f.team.deferred[key] = nil end
  end
  f.team.goal = plan.goal
  f.team.missing = plan.missing
  f.team.unreachable = plan.unreachable

  -- Besoins de prospection, par ressource.
  local needs = {}
  for kind, n in pairs(plan.site_needs) do needs[T.outposts[kind].resource] = n end
  -- Une réserve d'un site par type déjà exploité, pour l'expansion suivante.
  f.site_needs = needs

  Profiler.start("team:board")
  Board.sync(f, plan.tasks, tick)
  Profiler.stop("team:board")

  -- Lot IA1-a : mesures publiées (inactivité réelle ; exécutants au-delà du carnet) et cases du QG revalidées
  -- à tour de rôle.
  Profiler.start("team:scale")
  Team.measure(f, view, tick)
  Worker.check_slots(f, surface, Scale.SLOT_CHECKS_PER_THINK)
  if plan.recruit_blocked then f.stats.recruit_guard = (f.stats.recruit_guard or 0) + 1 end
  if plan.recruit_held then f.stats.recruit_held = (f.stats.recruit_held or 0) + 1 end
  Profiler.stop("team:scale")

  -- Décisions immédiates sur le stock (relu : les tâches n'ont encore rien pris).
  local stock = stock_of(f)
  local cost = view.recruit_cost
  if plan.recruit_workers and not plan.recruit_unarmed and has_list(stock, cost) then
    remove_list(f, cost)
    if Worker.recruit(f, surface, tick) then
      f.stats.recruited = (f.stats.recruited or 0) + 1
    else
      for _, it in ipairs(cost) do f.hq.insert({ name = it[1], count = it[2] }) end
    end
    stock = stock_of(f)
  elseif plan.recruit_unarmed and f.engineers_count == 0 then
    if Worker.recruit(f, surface, tick, true) then
      if f.stats then f.stats.unarmed_hires = (f.stats.unarmed_hires or 0) + 1 end
    end
  end
  if plan.train and has_list(stock, T.kits[plan.train.unit], plan.train.count) then
    local kit = T.kits[plan.train.unit]
    remove_list(f, kit, plan.train.count)
    local made = Military.train(f, surface, plan.train.unit, plan.train.count)
    if made < plan.train.count then
      for _, it in ipairs(kit) do f.hq.insert({ name = it[1], count = it[2] * (plan.train.count - made) }) end
    end
    f.team.trained = f.team.trained + made
    stock = stock_of(f)
  end
  if plan.research and has_list(stock, T.research[plan.research]) then
    remove_list(f, T.research[plan.research])
    f.tech = plan.research
    unlock(f, f.tech)
    log(string.format("[FO-TEAM] %s : recherche niveau %d payee en packs a %.1f min", f.key, f.tech, (tick - State.war().started) / 3600))
  end
  return plan
end

---------------------------------------------------------------------------------------------------
-- Affichage
---------------------------------------------------------------------------------------------------
local function item_name(name)
  local p = game.item_prototypes[name]
  return p and p.localised_name or name
end

--- Ligne localisée « Objectif : X — il manque : a, b, c ».
function Team.goal_text(f)
  local t = f.team
  if not t then return "" end
  if not t.goal then return { "fo-team.goal-line-done" } end
  local parts = { "" }
  local shown = 0
  for _, m in ipairs(t.missing or {}) do
    if shown >= 3 then break end
    local name = m[1]
    if name:find("^site:") then
      parts[#parts + 1] = { "fo-team.missing-site", { "fo-team.outpost-" .. name:sub(6) } }
    else
      parts[#parts + 1] = { "", m[2], " ", item_name(name) }
    end
    shown = shown + 1
    if shown < math.min(3, #t.missing) then parts[#parts + 1] = ", " end
  end
  if shown == 0 then return { "fo-team.goal-line", { "fo-team.goal-" .. t.goal } } end
  return { "fo-team.goal-line-missing", { "fo-team.goal-" .. t.goal }, parts }
end

local KEY_ITEMS = { "iron-plate", "copper-plate", "coal", "stone", "steel-plate", "firearm-magazine", "automation-science-pack" }

function Team.status_line(f)
  local t = f.team
  if not t then return "" end
  local inv = f.hq.valid and stock_of(f) or {}
  local parts = {}
  for _, k in ipairs(KEY_ITEMS) do parts[#parts + 1] = k:gsub("%-plate", ""):gsub("%-magazine", ""):gsub("automation%-science%-pack", "science1") .. "=" .. (inv[k] or 0) end
  local open, taken = Board.count(f)
  local states = Worker.counts(f)
  local ws = {}
  for _, k in ipairs(State.sorted_keys(states)) do ws[#ws + 1] = k .. ":" .. states[k] end
  local missing = {}
  for _, m in ipairs(t.missing or {}) do missing[#missing + 1] = m[1] .. "x" .. m[2] end
  local ts = {}
  for _, k in ipairs(State.sorted_keys(t.task_stats)) do ts[#ts + 1] = k .. " " .. t.task_stats[k].ok .. "/" .. t.task_stats[k].fail end
  local fr = {}
  for _, k in ipairs(State.sorted_keys(t.fail_reasons)) do fr[#fr + 1] = k .. ":" .. t.fail_reasons[k] end
  local d = t.delivered or {}
  -- Lot IA1-a : effectif / plafond, recrues payées, garde d'agents, mesures de la dernière pensée.
  local m = t.scale and t.scale.last
  local st = f.stats or {}
  return string.format("    equipe : objectif %s | manque [%s] | stock %s | taches %d libres %d prises | ouvriers {%s} | taches ok/echec {%s} | echecs {%s} | ramasse %d | entraines %d | livre fer %d cuivre %d charbon %d minerai %d | effectif %d/%d (recrues %d, garde %d, frein %d) | inactifs %s | au-dela du carnet %s",
    t.goal or "aucun (echelle gravie)", table.concat(missing, " "), table.concat(parts, " "), open, taken,
    table.concat(ws, " "), table.concat(ts, ", "), table.concat(fr, " "), t.collected or 0, t.trained or 0,
    d["iron-plate"] or 0, d["copper-plate"] or 0, d["coal"] or 0, d["iron-ore"] or 0,
    f.engineers_count or 0, Team.npc_max(f), st.recruited or 0, st.recruit_guard or 0, st.recruit_held or 0,
    m and (m.idle .. "/" .. m.n) or "?", m and tostring(m.surplus) or "?")
end

return Team
