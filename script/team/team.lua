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
local Fondation = require("shared.team.fondation") -- lot KIT : kit de départ commun aux deux équipes
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local Scale = require("shared.team.scale")
local O = require("shared.team.org")
local ChefRules = require("shared.faction.chef") -- lot IA2-a : ordre des objectifs choisi par le chef
local Valeur = require("shared.faction.valeur") -- lot IA2-b : éventail des gisements de départ
local Tr = require("shared.faction.traits")
local Config = require("script.core.config")
local Registry = require("script.companion.registry")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")
local Military = require("script.faction.military")
local Sites = require("script.faction.sites")
local Board = require("script.team.board")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Worker = require("script.team.worker")
local Poles = require("script.team.poles") -- lot IA1-b : pôles, managers, généralistes, travail de fond
local Build = require("script.team.build") -- lot IA1-d : plan directeur et construction (rien sans f.build)
local Profiler = require("script.core.profiler")
local Trace = require("script.core.trace")
local Ia3 = require("script.ai3.cerveau") -- lot IA3-c : cerveau par besoins (réglage fo-war-ia3-cerveau)
local Effectif = require("shared.ai3.effectif") -- lot IA3-d : une faction grandit quand le travail attend (A7)
local General = require("script.ai3.general") -- lot SCALE : ressource la plus demandée (marge de la recrue)
local Rg = require("shared.ai3.reglages") -- lot SCALE : ressources clés de repli

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
    -- Lot IA3-c : une faction au cerveau par besoins fait sa VRAIE recherche (aucun niveau offert).
    if f.team and not f.team.ia3c and not f.is_player and not f.eliminated and game.forces[f.force] then
      for level = 0, f.tech or 0 do unlock(f, level) end
    end
  end
end)

local function stock_of(f)
  return Stock.contents(f)
end

local function remove_list(f, list, times)
  for _, it in ipairs(list) do
    local n = it[2] * (times or 1)
    if n > 0 then Stock.remove(f, it[1], n) end
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
  -- Lot IA2-b : les 4 gisements en ÉVENTAIL autour d'un axe tiré du flux d'expansion de la faction (sel 100 + id),
  -- et non plus en croix aux mêmes angles pour toutes : la base s'étire d'un côté (shared/faction/valeur.lua V.FAN).
  local offsets = SEED_OFFSETS
  if not f.is_player then
    local axis = Tr.range(Sites.stream(f), 0, 63)
    f.seed_axis = axis
    offsets = Valeur.start_slots(axis)
  end
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local res = T.outposts[kind].resource
    local radius = T.seed_radius[kind] or 8
    for i, d in ipairs(offsets) do
      if not used[i] then
        local c = { x = math.floor(f.hq_pos.x + d[1]) + 0.5, y = math.floor(f.hq_pos.y + d[2]) + 0.5 }
        local water = surface.count_tiles_filtered({ position = c, radius = SEED_RADIUS_MAX + 2, collision_mask = "water-tile" })
        if water == 0 then
          used[i] = true
          for _, e in ipairs(surface.find_entities_filtered({ position = c, radius = radius + 1, type = "resource" })) do e.destroy() end
          local placed = 0
          for dx = -radius, radius do
            for dy = -radius, radius do
              if dx * dx + dy * dy <= radius * radius then
                surface.create_entity({ name = res, position = { c.x + dx, c.y + dy }, amount = SEED_AMOUNT })
                placed = placed + 1
              end
            end
          end
          -- Lot IA2-b : richesse comme une découverte (somme des amount de 64 tuiles au plus, carte de valeur).
          local read = math.min(64, placed)
          f.prospects[#f.prospects + 1] = { x = c.x, y = c.y, resource = res, seeded = true, rich = read * SEED_AMOUNT,
            tiles = read, water = false, rough = 0, cliffs = 0 }
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

--- Lot KIT : le kit généreux (réglage fo-war-kit-genereux, bancs seulement) est-il demandé ? Faux par défaut et quand le
--- réglage n'existe pas (moteur simulé des tests hors jeu).
function Team.kit_generous()
  local g = settings and settings.global
  local s = g and g[Fondation.SETTING]
  return s ~= nil and s.value == true
end

--- Lot KIT : le cerveau par besoins (réglage fo-war-ia3-cerveau, défaut vrai) est-il éteint ? Vrai seulement si le réglage
--- existe et vaut faux.
function Team.brain_off()
  local g = settings and settings.global
  local s = g and g[Ia3.SETTING]
  return s ~= nil and s.value == false
end

--- Lot KIT : ce que reçoit une faction à la fondation (règle pure : shared/team/fondation.lua).
function Team.faction_grant() return Fondation.grant(false, Team.kit_generous(), Team.brain_off()) end

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
    -- Lot KIT : la même règle que les factions (F.grant) : aucun objet au coffre d'équipe ; lu ici pour que le kit des deux
    -- équipes ait une seule source (test pur : tests/kit_test.lua).
    for _, it in ipairs(Fondation.grant(true, false).chest) do
      local chest = f.hq or f.chest
      if chest and chest.valid then chest.get_inventory(defines.inventory.chest).insert({ name = it[1], count = it[2] }) end
    end
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
  -- Lot KIT : même kit que votre équipe (coffre vide, aucun four) ; le kit généreux d'avant n'est offert qu'aux bancs
  -- (réglage fo-war-kit-genereux). Lu à chaque fondation et refondation : une sauvegarde existante ne change pas.
  local grant = Team.faction_grant()
  local inv = f.hq.get_inventory(defines.inventory.chest)
  for _, it in ipairs(grant.chest) do inv.insert({ name = it[1], count = it[2] }) end
  f.home_spot = surface.find_non_colliding_position("fo-companion", { x = f.hq_pos.x - 6, y = f.hq_pos.y + 8 }, 20, 0.5)
    or { x = f.hq_pos.x - 6, y = f.hq_pos.y + 8 }
  if grant.unlock0 then unlock(f, 0) end -- lot KIT : sans kit généreux, une faction recherche comme votre équipe
  seed_resources(f, surface)
  -- Fonderie de départ : les fours sont posés avec le stock (comme les premiers fours d'un joueur). Aucun en kit égal.
  if grant.smelters > 0 then
    local inv2 = f.hq.get_inventory(defines.inventory.chest)
    local tmp = game.create_inventory(8)
    tmp.insert({ name = T.SMELTER, count = inv2.remove({ name = T.SMELTER, count = grant.smelters }) })
    tmp.insert({ name = T.fuel, count = inv2.remove({ name = T.fuel, count = T.fuel_per_burner * grant.smelters }) })
    Outposts.place_smelters(f, surface, grant.smelters, tmp)
    for name, n in pairs(tmp.get_contents()) do inv2.insert({ name = name, count = n }) end
    tmp.destroy()
  end
  first_workers(f, surface) -- lot IA1-a : fo-npc-start (8) au lieu de T.start_workers (2)
end

---------------------------------------------------------------------------------------------------
-- Lot IA3-d : effectif d'une faction (shared/ai3/effectif.lua). Situation lue au tableau des tâches tel qu'il est à la
-- pensée (tâches libres, date de naissance, matière stricte libre au registre), au stock LIBRE et au manque de l'objectif.
---------------------------------------------------------------------------------------------------
-- Plaques du coût d'une recrue (lot SCALE, règle anti-échelle : shared/ai3/effectif.lua ne nomme aucun objet) : les
-- produits des avant-postes que la fonderie sait faire (données de shared/team/config.lua), triés.
local PLATES = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do
  local p = T.outposts[kind].product
  if T.smelter_inputs[p] then PLATES[#PLATES + 1] = p end
end
table.sort(PLATES)
local PLATE = {}
for _, p in ipairs(PLATES) do PLATE[p] = true end

--- Ajoute une liste { {objet, n}, ... } à la table `acc` ({ [objet] = n }).
local function add_list(acc, list)
  for _, it in ipairs(list or {}) do acc[it[1]] = (acc[it[1]] or 0) + it[2] end
end

--- Situation de l'équipe pour la règle d'effectif. free = stock libre (coffre − réservé, Board.view_stock).
local function effectif_input(f, tick, free, args)
  local list = Board.get(f).list or {}
  local tasks, reserved, kinds, making = {}, {}, {}, {}
  for i = 1, #list do
    local t = list[i]
    -- Équipement de recrue déjà en fabrication (libre ou pris) : compté comme prêt dans le coût (sa matière est réservée
    -- au registre dès la prise : la compter aussi dans le coût le paierait deux fois).
    if t.tag == Effectif.RECRUIT_TAG and t.kind == "craft" and t.item then
      making[t.item] = (making[t.item] or 0) + (t.count or 0)
    end
    if not t.worker then
      local strict = Board.strict_list(t)
      local prenable = true
      for _, it in ipairs(strict or {}) do
        if (free[it[1]] or 0) < it[2] then prenable = false break end
      end
      -- L'équipement de la recrue en fabrication (tâche « ouvrier ») EST son coût : pas réservé contre elle (sinon le coût
      -- compte deux fois et la décision bascule « recrue » / « cout » à chaque pensée : moteur réel, ia3d-charge, Écarlate).
      if not t.fond and t.tag ~= Effectif.RECRUIT_TAG then add_list(reserved, strict) end
      tasks[#tasks + 1] = { kind = t.kind, prio = t.prio, critical = t.critical, created = t.created, fond = t.fond,
        tag = t.tag, prenable = prenable }
      local k = (t.kind or "?") .. (t.fond and "(fond)" or "") .. ":" .. tostring(t.prio or 0)
      kinds[k] = (kinds[k] or 0) + 1
    end
  end
  local kk = {}
  for _, k in ipairs(State.sorted_keys(kinds)) do kk[#kk + 1] = k .. "x" .. kinds[k] end
  -- Ce que l'objectif courant attend encore (dernière pensée : f.team.missing, plaques seulement).
  for _, m in ipairs(f.team.missing or {}) do
    if PLATE[m[1]] then reserved[m[1]] = (reserved[m[1]] or 0) + (m[2] or 0) end
  end
  -- Coût de la recrue en plaques : ce que le coffre a de prêt (libre, hors travail en attente) est déjà payé ; le reste
  -- se fabrique (livre de recettes : pistolet, chargeurs).
  local cost, rest = {}, {}
  for _, it in ipairs(args.recruit_cost) do
    local have = math.max(0, (free[it[1]] or 0) - (reserved[it[1]] or 0)) + (making[it[1]] or 0)
    local need = it[2] - have
    if need > 0 then
      if PLATE[it[1]] then cost[it[1]] = (cost[it[1]] or 0) + need
      else rest[#rest + 1] = { it[1], need } end
    end
  end
  if #rest > 0 then
    local raw = book_for(f):raw_cost(rest)
    for _, k in ipairs(PLATES) do if raw[k] then cost[k] = (cost[k] or 0) + raw[k] end end
  end
  local left = {}
  for _, k in ipairs(PLATES) do left[k] = (free[k] or 0) - (reserved[k] or 0) end
  local tr = f.traits or {}
  local key = General.key(f) or Rg.FALLBACK_KEY
  local margin_item = T.outposts[key.top] and T.outposts[key.top].product or PLATES[#PLATES]
  return {
    plates = PLATES, margin_item = margin_item,
    n = f.engineers_count or 0, cap = args.cap, floor = args.floor, blocked = args.blocked, limit = args.limit,
    threatened = args.threatened, idle = args.idle, fond = args.fond, tasks = tasks, cost = cost, left = left,
    traits = { ambition = tr.ambition, prudence = tr.prudence },
    free_kinds = table.concat(kk, " "), -- tâches libres par genre et priorité (journal : diagnostic)
  }
end

--- Texte de la fenêtre « Équipe et factions » (carte d'une faction) : décision de la dernière pensée et sa raison.
function Team.effectif_text(f)
  local ef = f.team and f.team.effectif
  local d = ef and ef.last_d
  if not d then return nil end
  local r = d.reason
  local why
  if r == "plafond" then why = { "fo-ia3d.why-plafond", f.engineers_count or 0 }
  elseif r == "plancher" then why = { "fo-ia3d.why-plancher", d.floor or 0 }
  elseif r == "inactifs" then why = { "fo-ia3d.why-inactifs", d.hands, d.waiting }
  elseif r == "matiere" then why = { "fo-ia3d.why-matiere", d.matter or 0 }
  elseif r == "travail_recent" then why = { "fo-ia3d.why-travail_recent", d.young or 0 }
  elseif r == "cout" then why = { "fo-ia3d.why-cout", d.cost_iron or 0, math.max(0, d.left_iron or 0) }
  elseif r == "rythme" then why = { "fo-ia3d.why-rythme", d.waiting, math.ceil((d.wait_left or 0) / 60) }
  elseif r == "recrue" then why = { "fo-ia3d.why-recrue", d.waiting }
  else why = { "fo-ia3d.why-" .. r } end
  return { "fo-ia3d.recruit-line", why }
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
  Profiler.fstart("view:1-debut")
  local workers_idle = Worker.idle_count(f)
  -- Lot IA1-b : un PNJ au travail de FOND compte comme disponible pour le frein (le fond s'étire à volonté : sans cela,
  -- l'équipe n'est jamais « inactive » et achète des recrues jusqu'à vider son coffre ; moteur réel, verif-guide sur
  -- la graine 1618033988 : 17 PNJ à 8 min, 6 à 85 fer au coffre de 8 à 32 min, aucune tourelle, coffre détruit
  -- vers 38 min). Le frein garde ainsi le sens d'IA1-a : recruter quand le travail du CERVEAU occupe tout le monde.
  -- Lot IA1-b2 (D-17, « Laisser grandir ») : sous « défendre d'abord », seul le fond qui ne produit ni ne construit
  -- (minage à la main de fond, plafonné ; garde) compte comme disponible ; un PNJ qui agrandit, bâtit, fond le minerai ou
  -- fabrique la réserve TRAVAILLE : quand tous travaillent, une recrue vient (le stock la paie toujours).
  local defend_first = f.is_player or T.defend_first_factions or false
  -- « Défendre d'abord, puis grandir » : la croissance (frein levé par le travail qui attend) ne vaut que pour une équipe
  -- QUI PEUT POSER DES TOURELLES (au coffre ou fabricables). Essai 5 du lot, verif-guide graine 1618033988, sans
  -- recherche : votre équipe à 10 PNJ et 6 avant-postes à 8 min, coffre détruit à 17 min (main : 4 avant-postes, vivante).
  -- R-QCM-25c : la croissance reste à votre équipe (une faction a sa taille réglée, fo-war-workers).
  local stock0 = stock_of(f)
  local grow = f.is_player and ((stock0["gun-turret"] or 0) > 0 or book_for(f):handcraftable("gun-turret")) or false
  local on_fond, backlog = 0, 0
  for _, t in ipairs(Board.get(f).list or {}) do
    local soft = t.fond and (not grow or t.kind == "mine" or t.kind == "garrison")
    if t.worker and soft then on_fond = on_fond + 1 end
    -- Travail qui ATTEND (libre) et qui produit ou construit : celui qui justifie une recrue.
    if not t.worker and not (t.fond and (t.kind == "mine" or t.kind == "garrison")) then backlog = backlog + 1 end
  end
  -- Lot IA1-b2 : retenue des recrues après une perte (T.recruit_calm ; COUPÉE, 0 : voir shared/team/config.lua).
  local losses = f.team.org and f.team.org.losses
  local last_loss = losses and losses[#losses]
  local hold_recruits = defend_first and T.recruit_calm > 0 and last_loss ~= nil and tick - last_loss < T.recruit_calm or false
  -- Lot SCALE (correction après revue) : QG OCCUPÉ par les biters (script/team/worker.lua, f.hq_lethal_tick ; données
  -- T.hq_lethal_* de shared/team/config.lua) : une faction n'envoie plus de recrue mourir à son QG (ni survie, ni secours).
  if not f.is_player and f.hq_lethal_tick and tick - f.hq_lethal_tick < T.hq_lethal_ticks then hold_recruits = true end
  -- Plancher (correction 3) : sous son effectif de départ, une équipe se reconstruit sans frein.
  local floor = Scale.start_headcount(Config.get("npc_start"), workers_max)
  local recruit_held = Scale.recruit_held(workers_idle + on_fond, Config.get("recruit_idle_max"), f.engineers_count or 0, floor)
  -- Lot IA1-b2 (« Laisser grandir », D-16 « pas de recrue sans travail » gardé) : sous « défendre d'abord », du travail
  -- qui attend au-delà des bras libres lève le frein (un PNJ entre deux tâches à l'instant de la pensée retenait sinon
  -- toute recrue : votre équipe restait à 8 PNJ toute la partie du guide).
  -- (Remplacé par la règle de croissance à rythme fixe ci-dessous, D-18 : grow_due.)
  f.team.floor = floor -- lot IA2-a2 : lu par le chef (survie)
  Profiler.fstop("view:1-debut")
  Profiler.fstart("view:2-avant-postes")
  local pend, smelters_pending, fortify_open = Board.pending(f)
  local outposts = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local st = Outposts.status(o, tick)
    outposts[#outposts + 1] = {
      id = oid, kind = o.kind, drills = o.drills, full = o.full or false, turrets = st.turrets, coal_needed = Outposts.coal_needed(o),
      fuel_low = st.fuel_low, output = st.output, idle_ticks = st.idle_ticks,
      has_task = Board.has(f, "service:" .. oid), has_fortify = fortify_open[oid] or false,
      -- Lot IA1-b2 : un PNJ y a été tué il y a moins de T.lethal_ticks (script/team/worker.lua).
      lethal = (o.lethal_tick ~= nil and tick - o.lethal_tick < T.lethal_ticks) or nil,
      -- R-QCM-25c (c) : distance au QG au carré (tuiles entières ; transport de fond sans tourelle : avant-postes proches).
      d2 = math.floor((o.pos.x - f.hq_pos.x) ^ 2 + (o.pos.y - f.hq_pos.y) ^ 2),
    }
  end
  -- R-QCM-25c (b) « L'équipe le défend » : dès qu'une faction a déclaré la guerre au joueur, des PNJ armés restent au
  -- coffre (T.hq_guards). Factions vivantes dans l'ordre des id.
  local hq_guards = 0
  local hq_threat = false
  if f.is_player then
    for _, id in ipairs(State.alive()) do
      local g = State.faction(id)
      if g and g.pvp and g.pvp.declared then hq_guards = T.hq_guards(f.engineers_count or 0) break end
    end
    -- QG MENACÉ (unités ennemies à moins de T.hq_threat_radius tuiles du coffre) : tout le monde garde le coffre, le fond
    -- s'arrête. Moteur réel : avant le lot, les PNJ inactifs restés au coffre le défendaient ; occupés au loin, le coffre
    -- tombait sous une attaque de biters (verif-guide 577215664, 33 min ; ia1b-scale10, 24 min).
    if f.hq and f.hq.valid and f.hq.surface.count_entities_filtered({ position = f.hq_pos, radius = T.hq_threat_radius,
      force = "enemy", type = "unit", limit = 1 }) > 0 then
      hq_threat = true
      hq_guards = math.max(hq_guards, f.engineers_count or 0)
    end
  end
  Profiler.fstop("view:2-avant-postes")
  Profiler.fstart("view:3-sites")
  local sites = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do sites[kind] = Sites.available(f, T.outposts[kind].resource) end
  Profiler.fstop("view:3-sites")
  Profiler.fstart("view:4-fin")
  local groups = {}
  local hq_turrets = 0
  for _, g in ipairs(Outposts.turret_groups(f)) do
    groups[#groups + 1] = { key = g.key, low = g.low, has_task = Board.has(f, "refill:" .. g.key) }
    if g.key == "hq" then hq_turrets = #g.list end -- lot IA1-b2 : tourelles du QG (défendre d'abord)
  end
  -- Lot IA1-b2 (règle de croissance, D-18) : une recrue de croissance toutes les T.grow_period tant que le QG et chaque
  -- avant-poste sont défendus, que le coffre garde T.grow_iron_reserve fer et qu'un travail attend (D-16 : pas de
  -- recrue sans travail).
  local grow_due = false
  if grow and (f.engineers_count or 0) >= floor and backlog > 0
    and tick - (f.team.last_grow or -T.grow_period) >= T.grow_period and hq_turrets >= T.defend_hq
    and (stock0["iron-plate"] or 0) >= T.grow_iron_reserve + 10 + (f.engineers_count or 0) then
    grow_due = true
    for _, o in ipairs(outposts) do
      if (o.turrets or 0) < T.defend_turrets(o.drills) then grow_due = false break end
    end
  end
  if grow_due then recruit_held = false end
  local smelter_out, smelter_low = Outposts.smelters_status(f)
  -- Lot IA3-b (réglage fo-war-ia3-marche) : le cerveau voit le coffre MOINS ce que les tâches prises y ont réservé.
  local stock_free = Board.view_stock(f, stock_of(f), tick, true)
  local threatened = tick < (f.threatened_until or 0)
  -- Lot IA3-d (A7, « ils ne scalent pas ») : une FACTION grandit quand du travail attend depuis 2 min au-delà de ses bras
  -- libres et que la recrue se paie (shared/ai3/effectif.lua) ; elle ne recrute pas quand ses PNJ sont inactifs. La règle
  -- remplace, pour les factions, le frein « tout le monde travaille à l'instant de la pensée » (fo-recruit-idle-max = 0 :
  -- 36 à 99 % des pensées retenues sur la partie default de 2 h, fo-logs/2026-10-27_IA3-d/NOTES.md). Mêmes cas sans frein
  -- qu'avant : sous l'effectif de départ (survie), et fo-recruit-idle-max ≥ 60. Votre équipe garde sa règle d'IA1-b2
  -- (grow_due : défendue, 400 fer, une recrue par 5 min) : la croissance sans défense l'a perdue (F241, IA1-b2 essais 2 et 5).
  local effectif, recruit_prio
  if not f.is_player then
    local st = f.team.effectif
    if not st then
      st = {}
      f.team.effectif = st
    end
    local s = effectif_input(f, tick, stock_free, {
      recruit_cost = recruit_cost, cap = workers_wanted, floor = floor, blocked = recruit_blocked,
      limit = Config.get("recruit_idle_max"), threatened = threatened, idle = workers_idle, fond = on_fond,
    })
    effectif = Effectif.decide(s, st, tick)
    effectif.floor = floor
    effectif.cost_iron = (s.cost[s.margin_item] or 0) + effectif.margin
    effectif.left_iron = s.left[s.margin_item] or 0
    effectif.free_kinds = s.free_kinds
    recruit_held = not effectif.recruit
    -- Recrue décidée : son équipement se fabrique à la valeur du travail qu'elle débloque (prix fictif, borné 55 à 89 :
    -- sous les urgences), et non plus à 55 derrière les fabrications de l'armée (72 à 83).
    if effectif.reason == "recrue" then recruit_prio = Effectif.kit_prio(effectif.value) end
  end
  Profiler.fstop("view:4-fin") -- lot PERF (fusion de l'intégrateur : la mesure fine couvre aussi la règle d'effectif)
  return {
    tech = f.tech, personality = f.personality, done = f.team.done, deferred = f.team.deferred,
    stock = stock_free, incoming = Board.incoming(f),
    outposts = outposts, pending = pend, sites = sites,
    smelters = #Outposts.smelters(f), smelters_pending = smelters_pending,
    smelter_task = Board.has(f, "smelt"), smelter_output = smelter_out, smelter_fuel_low = smelter_low,
    smelter_coal = Outposts.coal_needed_for(Outposts.smelters(f)),
    turret_groups = groups,
    soldiers = f.soldiers_count, soldiers_max = soldiers_max,
    workers = f.engineers_count, workers_max = workers_max, workers_idle = workers_idle,
    workers_wanted = workers_wanted, recruit_cost = recruit_cost, recruit_blocked = recruit_blocked,
    recruit_held = recruit_held, recruit_prio = recruit_prio, -- lot IA3-d : priorité de l'équipement d'une recrue décidée
    -- Lot IA2-a : une faction suit l'ordre des objectifs de son chef (T.ladder réordonné selon ses postures,
    -- prérequis gardés) ; sans chef (avant sa première pensée), T.ladder.
    ladder = f.is_player and T.player_ladder or ChefRules.ladder_entries(f.chef), no_research = f.is_player or false,
    threatened = threatened,
    open = Board.open(f),
    effectif = effectif, -- lot IA3-d : décision et raison de la règle d'effectif (factions seulement)
    -- Lot IA3-d : effectif visé atteint selon la règle (aucun bras ne manque) ; le cerveau d'IA-V2 attendait sinon le
    -- plafond (workers ≥ workers_wanted) pour dire l'économie « faite », jamais atteint par une faction qui n'a pas besoin
    -- de grandir.
    workers_enough = effectif and Effectif.enough(effectif.reason) or nil,
    -- Lot IA2-a2 (SURVIE, factions seulement) : sous son effectif de départ, une faction équipe ses recrues au QG avec
    -- les plaques du stock ; en reconstruction (chef) ou menacée, elle y équipe aussi sa garde (shared/team/planner.lua).
    emergency = (not f.is_player) and { floor = floor, rebuild = (f.chef and f.chef.rebuild) or false } or nil,
    -- Correction VERIF-NUIT (25/10) : votre équipe, sous son effectif de départ, équipe ses recrues au QG avec les
    -- plaques du coffre (shared/team/planner.lua, view.recover_floor) ; le reste de la survie reste aux factions.
    recover_floor = f.is_player and floor or nil,
    -- Lot IA1-b2 (D-17) : défendre d'abord (tourelles avant les ouvriers ; shared/team/planner.lua) ; recrues retenues
    -- après une perte récente.
    defend_first = defend_first or nil, hold_recruits = hold_recruits or nil,
    -- Tourelles du QG voulues : votre équipe seulement (une faction garde son QG avec ses soldats ; T.defend_first_factions).
    hq_turrets = hq_turrets, hq_fortify = fortify_open["hq"] or false, hq_defend = (f.is_player or not Team.kit_generous()) and T.defend_hq or 0, -- lot KIT : sans kit généreux, une faction pose ses 4 tourelles de QG comme votre équipe
    hq_guards = hq_guards, hq_threat = hq_threat or nil, grow_reserve = grow and T.grow_iron_reserve or nil, grow_due = grow_due or nil,
    -- Lot IA2-b (F209) : orphelins à démonter (factions seulement).
    orphans = (not f.is_player) and Outposts.orphan_groups(f, tick) or nil,
  }
end

---------------------------------------------------------------------------------------------------
-- Mesures publiées (lot IA1-a, docs/EQUIPES_PNJ.md §16) : inactivité RÉELLE (PNJ sans tâche à la pensée) et
-- exécutants AU-DELÀ DU CARNET (O.pole_targets : travail ouvert + restant à l'horizon de 5 min), séparément.
-- Cumulées par pensée dans f.team.scale (lues par l'interface « fo-ia1 » ; moyennes = sommes / pensées).
---------------------------------------------------------------------------------------------------
function Team.measure(f, view, tick)
  local b = Board.get(f)
  local orientation = Poles.orientation(f) -- lot IA1-b : l'orientation choisie, sinon la personnalité
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
  -- Lot IA3-c : bascule figée par équipe à sa première pensée (script/ai3/cerveau.lua) ; éteinte : planificateur d'avant.
  local ia3 = Ia3.active(f, tick)
  local plan = ia3 and Ia3.plan(f, view, book_for(f), surface, tick) or Planner.plan(view, book_for(f))
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
  Board.sync(f, plan.tasks, tick, plan, view, book_for(f)) -- lot IA3-b : manque de plaques (réglage allumé)
  Profiler.stop("team:board")

  -- Lot IA1-b : organisation (pôles, managers, généralistes) et travail de fond, sur le tableau synchronisé.
  Profiler.start("team:poles")
  Poles.think(f, view, book_for(f), tick, plan)
  if ia3 then Ia3.after_poles(f, tick) end -- lot IA3-c : pas de fond sur une matière saturée
  Profiler.stop("team:poles")
  -- Lot IA1-d : tâches du plan directeur (chantiers, défrichage, quais) ; rien pour une équipe sans plan.
  if f.build then
    Profiler.start("team:build")
    Build.think(f, surface, tick)
    Profiler.stop("team:build")
  end
  -- Lot IA3-b : meilleures paires PNJ inactif × tâche (place de marché, réglage allumé). Fusion IA-V2 : APRÈS le plan
  -- directeur (le plan crée ses tâches, puis le marché les attribue ; consigne de l'intégrateur, 27/10).
  Profiler.start("team:market")
  Board.assign(f, tick)
  Profiler.stop("team:market")

  -- Lot IA1-a : mesures publiées (inactivité réelle ; exécutants au-delà du carnet) et cases du QG revalidées
  -- à tour de rôle.
  -- Lot IA1-b2 (complément du DC, 25/10 vers 11 h 25) : raisons d'attente des PNJ sans tâche à la pensée : « rien »
  -- (aucune tâche libre au tableau), « bloque » (des tâches libres, mais d'un autre pôle ou en pause), « manque » (le
  -- cerveau attend des objets au coffre : affiché au-dessus du coffre, f.team.missing).
  local idle_n = view.workers_idle or 0
  if idle_n > 0 then
    local free_n = 0
    for _, t in ipairs(Board.get(f).list or {}) do if not t.worker then free_n = free_n + 1 end end
    local miss = false
    for _, m in ipairs(plan.missing or {}) do
      if type(m[1]) == "string" and m[1]:sub(1, 5) ~= "site:" then miss = true break end
    end
    local r = f.team.idle_why or { rien = 0, bloque = 0, manque = 0 }
    f.team.idle_why = r
    if free_n == 0 then r.rien = r.rien + idle_n else r.bloque = r.bloque + idle_n end
    if miss then r.manque = r.manque + idle_n end
  end
  Profiler.start("team:scale")
  Team.measure(f, view, tick)
  Worker.check_slots(f, surface, Scale.SLOT_CHECKS_PER_THINK)
  if plan.recruit_blocked then f.stats.recruit_guard = (f.stats.recruit_guard or 0) + 1 end
  if plan.recruit_held then f.stats.recruit_held = (f.stats.recruit_held or 0) + 1 end
  Profiler.stop("team:scale")

  -- Décisions immédiates sur le stock (relu : les tâches n'ont encore rien pris). Lot IA3-b : stock LIBRE (réglage).
  local stock = Board.view_stock(f, stock_of(f), tick)
  local cost = view.recruit_cost
  -- Lot IA2-a2 (survie) : recrue équipée AU QG avec les plaques du stock (plan.recruit_uses : objets prélevés).
  local pay = plan.recruit_uses or cost
  if plan.recruit_workers and not plan.recruit_unarmed and has_list(stock, pay) then
    remove_list(f, pay)
    if Worker.recruit(f, surface, tick) then
      f.stats.recruited = (f.stats.recruited or 0) + 1
      if view.grow_due then f.team.last_grow = tick end -- lot IA1-b2 : rythme de la croissance
      -- Lot IA3-d : recrue de CROISSANCE d'une faction (rythme de la règle d'effectif).
      if view.effectif and view.effectif.reason == "recrue" and not plan.emergency_recruit then
        Effectif.grown(f.team.effectif, tick)
      end
      if plan.recruit_uses then
        f.stats.emergency_recruits = (f.stats.emergency_recruits or 0) + 1
        -- Votre équipe peut travailler sans guerre (State.war().started nil) : minutes comptées depuis sa fondation,
        -- comme « objectif atteint » plus haut.
        log(string.format("[FO-TEAM] %s : survie, recrue equipee au QG (effectif %d, depart %d) a %.1f min", f.key,
          f.engineers_count or 0, (view.emergency and view.emergency.floor) or view.recover_floor or 0,
          (tick - (f.started or State.war().started or 0)) / 3600))
      end
    else
      for _, it in ipairs(pay) do Stock.insert(f, it[1], it[2]) end
    end
    stock = Board.view_stock(f, stock_of(f), tick)
  elseif plan.recruit_unarmed and (f.engineers_count == 0 or (plan.emergency_unarmed and f.engineers_count < 2)) then
    if Worker.recruit(f, surface, tick, true) then
      if f.stats then f.stats.unarmed_hires = (f.stats.unarmed_hires or 0) + 1 end
    end
  end
  local tr = plan.train
  local tr_pay = tr and (tr.uses or T.kits[tr.unit])
  if tr and has_list(stock, tr_pay, tr.uses and 1 or tr.count) then
    local kit = T.kits[tr.unit]
    remove_list(f, tr_pay, tr.uses and 1 or tr.count)
    local made = Military.train(f, surface, tr.unit, tr.count)
    if made < tr.count then
      for _, it in ipairs(kit) do Stock.insert(f, it[1], it[2] * (tr.count - made)) end
    end
    f.team.trained = f.team.trained + made
    if tr.uses and made > 0 then
      f.stats.emergency_trained = (f.stats.emergency_trained or 0) + made
      log(string.format("[FO-TEAM] %s : survie, %d %s equipe(s) au QG (soldats %d) a %.1f min", f.key, made, tr.unit,
        f.soldiers_count or 0, (tick - State.war().started) / 3600))
    end
    stock = Board.view_stock(f, stock_of(f), tick)
  end
  -- Lot CAPITAL : amélioration d'un bâtiment à niveaux ou du centre, payée sur le stock LIBRE après les recrues et l'armée.
  if ia3 then Ia3.capital_pay(f, surface, tick, plan, stock) end
  if plan.research and has_list(stock, T.research[plan.research]) then
    remove_list(f, T.research[plan.research])
    f.tech = plan.research
    unlock(f, f.tech)
    log(string.format("[FO-TEAM] %s : recherche niveau %d payee en packs a %.1f min", f.key, f.tech, (tick - State.war().started) / 3600))
  end
  Ia3.measure(f, tick, plan) -- lot IA3-c : paliers de recherche et projets, mesurés avec les deux cerveaux
  Team.effectif_journal(f, view, tick) -- lot IA3-d : ligne minute « [FO-EFFECTIF] »
  -- Lot COFFRE : l'excédent du coffre du QG passe aux annexes, et un coffre se pose quand les cases se remplissent.
  Stock.balance(f)
  Stock.grow(f, surface, tick)
  return plan
end

--- Lot IA3-d (lisibilité, critère 5 d'A7) : chaque minute de partie, une ligne par faction : effectif, recrues de
--- croissance, raisons des pensées de la minute, dernière situation (travail qui attend, bras libres, fer).
function Team.effectif_journal(f, view, tick)
  local d = view.effectif
  local st = f.team.effectif
  if not (d and st) then return end
  local war = State.war() or {}
  local m = math.floor((tick - (f.started or war.started or 0)) / 3600)
  if st.minute == nil then st.minute = m end
  if m ~= st.minute then
    local sum = Effectif.minute_summary(st)
    local l = st.last_d or {}
    local a = sum.avg
    local function dec(x) return string.format("%d,%d", math.floor(x / 10), x % 10) end
    log(string.format("[FO-EFFECTIF] %s minute %d | effectif %d/%d (depart %d) | croissance %d (recrues %d) | raisons {%s} | "
      .. "moyennes : attente %s, sans tache %s, fond %s, recentes %s, sans matiere %s, faible valeur %s, exclues %s | "
      .. "derniere : %s, attente %d (plus ancienne %d s, valeur %d), bras libres %d, manque %d, libres {%s} | "
      .. "fer libre %d, cout fer %d (marge %d) | periode %d s",
      f.key, st.minute, f.engineers_count or 0, view.workers_wanted or 0, l.floor or 0, st.grown or 0,
      (f.stats and f.stats.recruited) or 0, sum.reasons, dec(a.waiting), dec(a.idle), dec(a.fond), dec(a.young),
      dec(a.matter), dec(a.low), dec(a.excluded), l.reason or "-", l.waiting or 0, math.floor((l.oldest or 0) / 60),
      l.value or 0, l.hands or 0, l.short or 0, l.free_kinds or "", l.left_iron or 0, l.cost_iron or 0,
      l.margin or 0, math.floor((l.period or 0) / 60)))
    st.minute = m
  end
  Effectif.count(st, d)
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
