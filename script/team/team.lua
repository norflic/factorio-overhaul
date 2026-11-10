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
local QgG = require("script.team.qg_groupe") -- lot QG-GROUPE2 : tourelles de départ du QG en ligne
local Depart = require("shared.team.depart") -- lot PARITE : tourelles de QG offertes au départ (emplacements)
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local ChaineMain = require("shared.team.chaine_main") -- lot FOURS : pas de tournée de fonte à vide
local Scale = require("shared.team.scale")
local O = require("shared.team.org")
local ChefRules = require("shared.faction.chef") -- lot IA2-a : ordre des objectifs choisi par le chef
local Valeur = require("shared.faction.valeur") -- lot IA2-b : éventail des gisements de départ
local Tr = require("shared.faction.traits")
local Config = require("script.core.config")
local Registry = require("script.companion.registry")
local State = require("script.faction.state")
local Outposts = require("script.faction.outposts")
local Famine = require("script.team.famine_fer") -- lot FAMINE-FER : plaque clé en famine, bande en attente : l'avant-poste n'est pas « plein »
local Military = require("script.faction.military")
local Sites = require("script.faction.sites")
local Board = require("script.team.board")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Worker = require("script.team.worker")
local Bail = require("script.team.bail") -- lot ETAGE4 : bail des tournées prises (shared/team/bail.lua)
local Poles = require("script.team.poles") -- lot IA1-b : pôles, managers, généralistes, travail de fond
local Rappel = require("script.team.rappel_urgent") -- lot COLLECTE : rappel d'un PNJ occupé pour une tâche urgente que personne ne prend
local Build = require("script.team.build") -- lot IA1-d : plan directeur et construction (rien sans f.build)
local GardeCentrale = require("script.team.garde_centrale") -- lot CENTRALE-GARDE : la centrale finie est un poste à défendre
local DefenseLog = require("script.team.defense_log") -- lot DEFENSE-FACTIONS : journal des blocages de la défense
local BriquesLog = require("script.team.briques") -- lot BRIQUES : journal [FO-BRIQUES] (lecture seule)
local FluxLog = require("script.team.flux") -- lot FLUX : journal des sorties qui dorment et des brûleurs vitaux à sec
local SortiesLog = require("script.team.sorties") -- lot CHARBON-MAIN : journal [FO-SEC] (brûleurs à sec et état de leur tournée)
local Front = require("script.team.front") -- lot DEFENSE-FRONT : la défense suit les attaques
local Ilots = require("script.team.ilots") -- lot ILOTS-MURS : tourelles des îlots isolés hors de l'enceinte
local DefStock = require("script.team.defense_stock") -- lot DEFENSE-STOCK : tourelles du coffre posées en groupes là où l'ennemi arrive
local Recon = require("script.team.reconstruction") -- lot COUVERTURE : pièces détruites refaites avant d'améliorer
local Objectif = require("script.team.objectif") -- lot AGES : libellé d'un objectif (aucune clé de traduction inconnue)
local Reparation = require("script.team.reparation") -- lot PD-REPARATION (D79) : bâtiments endommagés réparés (toutes les équipes)
local Gisement = require("script.team.gisement") -- lot GISEMENTS : foreuses à combustion à l'arrêt rebranchées ou retirées
local FoSwap = require("script.team.foreuse_swap") -- lot FOREUSES : foreuse à combustion remplacée par l'électrique quand le courant arrive
local Elec = require("script.team.electrique") -- lot ELECTRIQUE (DC 8/11) : verdict « électrique possible, thermique refusée », relu à chaque pensée
local Survie = require("script.team.survie") -- lot SURVIE-PENURIE : mode survie d'une équipe en pénurie (entrée, sortie, tâches, journal)
local SurvieQg = require("script.team.survie_qg") -- lot S1 : QG en péril (défense armée contre la menace reçue, journal [FO-SURVIE])
local MenaceQg = require("script.team.menace_qg") -- lot L12 (partie 1) : hystérésis de la menace sur le QG (hq_threat)
local MenaceEq = require("script.team.menace_equipe") -- lot L12 (partie 3) : menace TENUE (view.threat_held), lue par la capitalisation seulement
local Sq = require("shared.team.survie_qg") -- lot QGSURVIE : réserve de fer du QG (règle pure)
local PileRt = require("script.team.pile") -- lot PILE-PRIORITE : la pile retient l'amélioration (réparer + protéger d'abord)
local Flux = require("shared.team.flux") -- lot FLUX : sorties des avant-postes comptées comme objets attendus (règle pure)
local REPAT_ONLY = Flux.plates_of(Flux.plate_map(T.OUTPOST_ORDER, T.outposts, T.smelter_inputs)) -- lot FLUX : seules les plaques comptent comme objets attendus
local Acier = require("script.team.acier") -- lot ACIER : bloc « fonderie d'acier » (rangée de fours) et coupure des tournées manuelles d'acier
local Inter = require("script.team.intermediaires") -- lot MAIN-ET-INTERMEDIAIRES (D09, D10) : pas de minage à la main de ce que les machines sortent, plafond des intermédiaires
local Src = require("script.team.sources") -- lot MINAGE-MAIN : registre des coffres de SORTIE, tournées « fetch », plus de minage à la main de ce qui dort dans une sortie
local MigChamp = require("script.team.migration_champ") -- lot MIGRATION-CHAMP : un avant-poste de paires thermiques migré par parties vers des rangées électriques
local Profiler = require("script.core.profiler")
local Trace = require("script.core.trace")
local Ia3 = require("script.ai3.cerveau") -- lot IA3-c : cerveau par besoins (réglage fo-war-ia3-cerveau)
local Effectif = require("shared.ai3.effectif") -- lot IA3-d : une faction grandit quand le travail attend (A7)
local FerEquipe = require("shared.team.fer_equipe") -- lot FER-EQUIPE : réserve de fer de votre équipe
local Rsv = require("script.ai3.reserve") -- lot INDUSTRIE I1 : besoin évalué et couvert = plus de réserve de croissance
local JournauxDC = require("shared.team.journaux_dc") -- lot JOURNAUX-DC : plafond d'ouvriers et fer inemployé
local General = require("script.ai3.general") -- lot SCALE : ressource la plus demandée (marge de la recrue)
local Dep = require("script.ai3.depenses") -- lot DEPENSES2 (R1) : journal de la paie des soldats de votre équipe
local Rg = require("shared.ai3.reglages") -- lot SCALE : ressources clés de repli
local DefChoix = require("script.faction.defchoix") -- lot DEFENSE-CHOIX : base menacée ou envahie (tourelles du QG avant les soldats)
local Mu = require("shared.team.munitions") -- lot MUNITIONS : chargeurs voulus par tourelle (cible riche quand le fer la paie)
local Scheduler = require("script.core.scheduler") -- lot DÉCOUPAGE-PENSÉE : minuteurs des étapes d'une pensée
local Et = require("shared.team.etapes") -- lot DÉCOUPAGE-PENSÉE : état gardé de la vue et du plan pour E4
local Lourd = require("script.core.lourd") -- lot LOURD (point 2 c) : chaque étape d'une pensée prend le jeton des travaux lourds
local Sp = require("shared.team.spirale") -- EFFONDREMENT : recrue gratuite sous l'effectif de départ (journal [FO-RECRUE])
local ManqueVue = require("script.team.manque_vue") -- lot VIDEO-L3 : manque mesuré (modules, sorties, transit), à côté du stock

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
--- Lot CHARBON-CAPACITE (F485) : temps de minage de la ressource dont le produit est le combustible (T.outposts, T.fuel), lu aux
--- prototypes du jeu ; nil si aucune (le planificateur garde alors 1 s, la valeur d'un banc pur).
local function fuel_mining_time()
  local kinds = {}
  for kind in pairs(T.outposts) do kinds[#kinds + 1] = kind end
  table.sort(kinds) -- ordre stable (jamais l'ordre de pairs)
  for _, kind in ipairs(kinds) do
    local spec = T.outposts[kind]
    if spec and spec.product == T.fuel and spec.resource then
      local rp = game.entity_prototypes[spec.resource]
      local mp = rp and rp.mineable_properties
      return mp and mp.mining_time or nil
    end
  end
  return nil
end

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
      -- lot POSE-PAR-LOTS : taille des piles pour borner un kit de fabrication à l'inventaire du PNJ (shared/ai3/kit_lot.lua)
      stack_of = function(item)
        local ip = game.item_prototypes[item]
        return ip and ip.stack_size or nil
      end,
    })
    books[key] = b
  end
  return b
end
FoSwap.book_of = book_for -- lot TRANCHES (foreuses) : livre de recettes des tranches jouées hors de la pensée (minuterie)

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

--- Lot PARITE : pose les `n` tourelles de QG offertes à la fondation (emplacements : shared/team/depart.lua), chargées de 20
--- chargeurs, inscrites au groupe « hq » de l'équipe. UNE fonction pour les deux équipes (le QG d'une faction : script/faction/war.lua,
--- found_hq ; le coffre de la vôtre : script/team/player_team.lua). `center` : centre du QG ou du coffre. Rend le nombre posé.
function Team.place_hq_turrets(f, surface, center, n)
  local force = game.forces[f.force]
  local placed = 0
  -- lot QG-GROUPE2 : votre équipe pose ses tourelles de départ en ligne (script/team/qg_groupe.lua, QgG.line ; nil : D.HQ_OFFSETS)
  local line = QgG.line(f, surface, center, n)
  local offsets = line or Depart.offsets(n)
  local got = {} -- lot HQ-RECENSEMENT (relecture, mineur 4) : positions obtenues, pour le journal de la dispersion finale
  for i, o in ipairs(offsets) do
    local tpos = surface.find_non_colliding_position(T.turret, { x = center.x + o[1], y = center.y + o[2] }, 10, 1)
    got[i] = false
    if tpos then
      local t = surface.create_entity({ name = T.turret, position = tpos, force = force })
      if t then
        Outposts.add_turret(f, t, nil, 20)
        placed = placed + 1
        got[i] = { x = t.position.x, y = t.position.y }
      end
    end
  end
  if line then QgG.depart_report(f, center, offsets, got) end
  return placed
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

--- Lot INTEG-DEFENSE D-A : la force produit-elle du fer (statistiques de production de la dernière minute) ? Lecture seule, aucun état.
--- Les fonderies du plan directeur ne sont pas des avant-postes : sans cela, une faction qui forge à plein débit était jugée « sans production »
--- et gardait le plancher de fer ordinaire (planner : iron_producing, Fr.floors). Moteur simulé sans statistiques : faux.
local function iron_flow(f)
  local force = game.forces[f.force]
  local stats = nil
  pcall(function() stats = force and force.item_production_statistics end)
  if not stats then return false end
  local n = 0
  pcall(function()
    n = stats.get_flow_count({ name = T.outposts.iron.product, input = true, precision_index = defines.flow_precision_index.one_minute })
  end)
  return type(n) == "number" and n > 0
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
  local iron0 = stock0["iron-plate"] or 0 -- fer au coffre (hausse de croissance et journal [FO-CENTRALE-GARDE])
  local grow = f.is_player and ((stock0["gun-turret"] or 0) > 0 or book_for(f):handcraftable("gun-turret")) or false
  local on_fond, backlog = 0, 0
  -- Intégration 0.6.30 : un PNJ de la file sûre (lot INDUSTRIE I2, priorité sous tout le fond, rappelé pour le travail du cerveau) reste un BRAS LIBRE pour le
  -- cerveau : sans cela, workers_idle tombait à 0 et avec lui les bras de la capitalisation (Ca.prepare, hands : le stock libéré par I1 restait
  -- refusé faute de bras ; lambda), le travail d'avance (g.spare), le minage d'appoint du planificateur et la paralysie du mode survie.
  local on_safe = 0
  for _, t in ipairs(Board.get(f).list or {}) do
    local soft = t.fond and (not grow or t.kind == "mine" or t.kind == "garrison")
    -- Lot CRAFT-PARALLELE : la tâche de fond qu'un PNJ mène PENDANT sa fabrication en arrière-plan ne le rend pas disponible (avant
    -- ce lot, il était dans sa tâche « craft » et ne l'aurait pas prise) : frein des recrues inchangé à charge de fabrication égale.
    -- Cohérence seulement : aucun effet mesuré au moteur simulé (scénario de pteam_test, 6 graines, chiffres identiques).
    local ag = soft and t.worker and Registry.get(t.worker)
    if t.worker and t.safe then on_safe = on_safe + 1
    elseif t.worker and soft and not (ag and ag.task == t and Worker.crafting(ag)) then on_fond = on_fond + 1 end
    -- Travail qui ATTEND (libre) et qui produit ou construit : celui qui justifie une recrue (la file sûre ne la justifie pas).
    if not t.worker and not t.safe and not (t.fond and (t.kind == "mine" or t.kind == "garrison")) then backlog = backlog + 1 end
  end
  local workers_waiting = workers_idle -- PNJ vraiment sans tâche (mesures, fenêtre « Équipe et factions »)
  workers_idle = workers_idle + on_safe
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
  local fsurface = f.hq and f.hq.valid and f.hq.surface
  for _, oid in ipairs(State.sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    local st = Outposts.status(o, tick)
    -- Lot FLUX : avant-poste DANGEREUX (nid ou ver à moins de Poles.DANGER_RADIUS tuiles, ou perte récente de votre équipe : la même règle
    -- que le fond, script/team/poles.lua) : ni tournée en urgence ni sorties comptées, la porte le refuserait et ses refus pousseraient
    -- l'équipe au mode survie, puis à y aller sans escorte (banc dc-croissance 20261020 : 4 PNJ perdus de votre équipe à 10 min).
    -- Cherché seulement quand une tournée de cet avant-poste serait en jeu.
    local unsafe
    if fsurface and (st.fuel_low or (st.stuck or 0) > 0 or st.output >= T.collect_at) then
      local pos = o.access or o.pos
      Profiler.fstart("view:2-danger") -- lot X10-S0 : mesure seulement
      unsafe = (pos and (fsurface.count_entities_filtered({ position = pos, radius = Poles.DANGER_RADIUS, force = "enemy",
        type = { "unit-spawner", "turret" }, limit = 1 }) > 0 or (f.is_player and Poles.near_loss(f, pos, tick)))) or nil
      Profiler.fstop("view:2-danger")
    end
    -- Lot DEFENSE-AP : la garde voulue suit la menace du site (prévision), pas seulement ses foreuses ; une vague au moins égale au seuil de
    -- protection (Sq.SITE_HIT) et des tourelles en manque : à protéger d'abord (planchers de fer réduits, Sq.floors) AVANT le premier coup.
    -- Seul l'avant-poste de la plaque clé (le fer) est gardé selon sa menace : « les ressources d'abord » (le DC, 29/10) ; les autres gardent la règle
    -- d'avant (mesure 1618033988 : une tourelle de plus demandée à un avant-poste de pierre à 211 tuiles, fer dépensé, PNJ perdu en chemin).
    local base_t = T.defend_turrets(o.drills)
    local want_t, wave_t, why_t = base_t, 0, "base"
    local ospec_t = T.outposts[o.kind]
    if ospec_t and ospec_t.product == T.outposts.iron.product then want_t, wave_t, why_t = SurvieQg.garde(f, oid, tick, base_t) end
    -- trace [FO-OUTPOST-PLEIN] (lecture seule, lot FAMINE-FER) : pourquoi un avant-poste de la plaque clé est « plein » pour le cerveau (une ligne par minute)
    if f.is_player and ospec_t and ospec_t.product == T.outposts.iron.product and tick - (o.fulllog_t or -3600) >= 3600 then
      o.fulllog_t = tick
      local pj = f.migration and f.migration.o and f.migration.o[oid]
      log(string.format("[FO-OUTPOST-PLEIN] %s : avant-poste %d (%s) a %.1f min : foreuses %s, o.full %s (par %s, motif %s), migr %s (etape %s), attente %s, echecs d'extension %s, famine %s",
        tostring(f.key), oid, tostring(o.kind), tick / 3600, tostring(o.drills), tostring(o.full), tostring(o.full_by), tostring(o.full_why), tostring(o.migr),
        tostring(pj and pj.stage), tostring(o.hold_until ~= nil), tostring(o.ext_fails), tostring(Famine.open(f, o, tick))))
    end
    outposts[#outposts + 1] = {
      -- lot MIGRATION-CHAMP : un champ migré (o.migr) n'est jamais « agrandissable » en paires thermiques, même quand la fin d'une attente
      -- (board.lua, release_holds) a remis o.full à faux : sinon des tâches « extend » inutiles (Outposts.extend rend 0) tourneraient sans fin
      id = oid, kind = o.kind, drills = o.drills, famine = Famine.key_starved(f, o, tick), full = ((o.full or o.migr ~= nil) and not Famine.open(f, o, tick)) or false, turrets = st.turrets, coal_needed = Outposts.coal_needed(o, f.team.flux_fill), -- (lot FAMINE-FER : plaque clé en famine, bande en attente ; F488 : les deux champs d'avant sortis du commentaire)
      fuel_low = st.fuel_low, output = st.output, idle_ticks = st.idle_ticks,
      -- Lot FLUX : ce que la tournée rapportera (sorties par objet), réceptacles pleins, brûleurs (à sec), âge de la tournée libre.
      outputs = st.outputs, stuck = st.stuck, burners = st.burners, dry = st.dry, unpowered = st.unpowered, free_age = Board.free_age(f, "service:" .. oid, tick),
      fails = o.flux_fails, unsafe = unsafe,
      has_task = Board.has(f, "service:" .. oid), has_fortify = fortify_open[oid] or false,
      -- Lot IA1-b2 : un PNJ y a été tué il y a moins de T.lethal_ticks (script/team/worker.lua).
      lethal = (o.lethal_tick ~= nil and tick - o.lethal_tick < T.lethal_ticks) or nil,
      -- Lot S1 : des vagues ont touché cet avant-poste (mémoire de la prévision) et il lui manque des tourelles : à protéger avant d'être agrandi
      -- ou refait (shared/team/survie_qg.lua, Sq.protect_first ; lu par le planificateur si une tourelle est posable).
      protect = (SurvieQg.mark_protect(f, oid, tick, st.turrets, want_t) or (why_t ~= "base" and wave_t >= Sq.SITE_HIT and st.turrets < want_t)) or nil,
      want_t = want_t, -- lot DEFENSE-AP : lu par le planificateur (postes de défense, protect_any) ; le journal [FO-DEFENSE] l'écrit en « have/want »
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
    -- Lot L12 (partie 1) : HYSTÉRÉSIS (script/team/menace_qg.lua) : entrée à T.hq_threat_radius tuiles, sortie quand plus aucune unité à
    -- 64 tuiles pendant 2 pensées de suite (avant : seuil unique, la garde et la retenue des recrues clignotaient avec un biter à 48 tuiles).
    if f.hq and f.hq.valid and MenaceQg.observe(f, tick) then
      hq_threat = true
      hq_guards = math.max(hq_guards, f.engineers_count or 0)
    end
  end
  Profiler.fstop("view:2-avant-postes")
  Profiler.fstart("view:3-sites")
  local sites, sites_near = {}, {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do sites[kind], sites_near[kind] = Sites.available(f, T.outposts[kind].resource, tick) end
  Profiler.fstop("view:3-sites")
  Profiler.fstart("view:4-fin")
  -- Lot MUNITIONS (shared/team/munitions.lua, Mu.per_turret) : chargeurs voulus par tourelle, relus à chaque pensée (fer au coffre, tourelles
  -- de l'équipe ; fer d'un chargeur lu au livre quand la technologie change). Lu par Outposts.turret_groups, Outposts.refill_group et la
  -- tournée de recharge (script/team/worker.lua).
  if T.munitions_on then
    if f.team.mag_iron == nil or f.team.mag_iron_tech ~= f.tech then
      local rm = book_for(f):raw_cost({ { T.turret_ammo, 1 } })
      f.team.mag_iron, f.team.mag_iron_tech = rm[T.outposts.iron.product] or 0, f.tech
    end
    local n_turrets = 0
    for _, id in ipairs(State.sorted_keys(f.turrets or {})) do if f.turrets[id].valid then n_turrets = n_turrets + 1 end end
    -- (hystérésis : f.team.ammo_rich garde l'état d'une pensée à l'autre ; essai 1, la cible basculait avec le fer)
    f.team.ammo_per_turret, f.team.ammo_rich = Mu.per_turret({ base = T.turret_ammo_target,
      rich = T.turret_ammo_rich_on and T.turret_ammo_rich or T.turret_ammo_target, turrets = n_turrets, -- (essai 3 : cible riche éteinte)
      iron = iron0, mag_iron = f.team.mag_iron, was = f.team.ammo_rich == true })
    -- Munition choisie (Mu.best_ammo) : la meilleure de T.turret_ammo_ladder dont la recette est ouverte et qui se fabrique depuis le coffre
    -- (le livre de l'équipe : aucune matière à produire autrement), ou qui est au coffre ; collante tant qu'elle le reste.
    -- Votre équipe seulement (T.best_ammo_factions) : chez une faction, la munition plus chère change l'armée et les attaques (pvp_test, base
    -- défendue : 2 factions sur 4 attaquent au lieu de 3 avec l'échange) ; une faction garde la munition de base.
    local choose = f.is_player or T.best_ammo_factions
    local book = book_for(f)
    local force = game.forces[f.force]
    local cands = {}
    for i, name in ipairs(T.turret_ammo_ladder) do
      local r = force and force.recipes[name]
      local enabled = i == 1 or (choose and r ~= nil and r.enabled == true)
      local makeable = enabled and book:handcraftable(name) and next(book:plan({ { name, T.turret_ammo_target } }, stock0).raw) == nil
      cands[i] = { enabled = enabled, makeable = makeable, stock = stock0[name] or 0 }
    end
    -- Essai 3 : choix STABLE (Mu.stable_ammo, état f.team.ammo_state : nombres seulement) ; essai 2 : 17 bascules en 36 min.
    local idx, why
    f.team.ammo_state, idx, why = Mu.stable_ammo(f.team.ammo_state, cands, tick)
    if T.turret_ammo_ladder[idx] ~= (f.team.ammo_item or T.turret_ammo) then
      log(string.format("[FO-MUNITIONS] %s minute %.1f : munition des tourelles %s -> %s (%s)", tostring(f.key or "?"), tick / 3600,
        f.team.ammo_item or T.turret_ammo, T.turret_ammo_ladder[idx], why))
    end
    f.team.ammo_item, f.team.ammo_why = T.turret_ammo_ladder[idx], why
  else
    f.team.ammo_per_turret, f.team.mag_iron, f.team.mag_iron_tech, f.team.ammo_rich, f.team.ammo_item = nil, nil, nil, nil, nil
    f.team.ammo_state = nil
  end
  local groups = {}
  local hq_turrets = 0
  local mj = { n = 0, ammo = 0, low = 0, short = 0, missing = 0, hq_n = 0, hq_ammo = 0 } -- lot MUNITIONS : journal [FO-MUNITIONS]
  for _, g in ipairs(Outposts.turret_groups(f)) do
    groups[#groups + 1] = { key = g.key, low = g.low, has_task = Board.has(f, "refill:" .. g.key),
      n = #g.list, short = T.munitions_on and g.short or nil, missing = T.munitions_on and g.missing or nil, -- lot MUNITIONS
      missing_base = T.munitions_on and g.missing_base or nil, short_base = T.munitions_on and g.short_base or nil,
      worse = T.munitions_on and g.worse or nil, worse_need = T.munitions_on and g.worse_need or nil }
    if g.key == "hq" then hq_turrets = #g.list end -- lot IA1-b2 : tourelles du QG (défendre d'abord)
    mj.n, mj.ammo, mj.low, mj.short, mj.missing = mj.n + #g.list, mj.ammo + g.ammo, mj.low + g.low, mj.short + g.short, mj.missing + g.missing
    if g.key == "hq" then mj.hq_n, mj.hq_ammo = #g.list, g.ammo end
  end
  -- Lot MUNITIONS : journal de MESURE (aucune décision ne le lit), toutes les 5 min : tourelles, chargeurs, moyenne, sous le seuil bas, à
  -- recharger au plein, chargeurs au coffre, cible par tourelle, fer au coffre.
  Worker.rearm_report(f, tick) -- lot REARMEMENT : journal [FO-REARMEMENT] (mesure, toutes les 5 min)
  if tick - (f.team.mun_log or -1000000) >= 5 * 3600 then
    f.team.mun_log = tick
    log(string.format("[FO-MUNITIONS] %s minute %.1f | tourelles %d, chargeurs %d (%.1f par tourelle) ; QG %d tourelle(s), %d chargeur(s) ; " ..
      "sous le seuil bas %d, a recharger %d (%d chargeurs) ; coffre %d chargeur(s) de base, %d de la munition choisie, fer %d ; cible %d par " ..
      "tourelle%s ; munition %s (%s), regle %s",
      tostring(f.key or "?"), tick / 3600, mj.n, mj.ammo, mj.n > 0 and mj.ammo / mj.n or 0, mj.hq_n, mj.hq_ammo, mj.low, mj.short, mj.missing,
      stock0[T.turret_ammo] or 0, stock0[Outposts.ammo_name(f.tech, f)] or 0, iron0, Outposts.ammo_target(f),
      f.team.ammo_rich and " (riche)" or "", Outposts.ammo_name(f.tech, f), tostring(f.team.ammo_why or "base"),
      T.munitions_on and "munitions" or "avant"))
  end
  -- Lot IA1-b2 (règle de croissance, D-18) : une recrue de croissance toutes les T.grow_period tant que le QG et chaque
  -- avant-poste sont défendus, que le coffre garde T.grow_iron_reserve fer et qu'un travail attend (D-16 : pas de
  -- recrue sans travail).
  local grow_due = false
  -- Lot INDUSTRIE I1 (réglage fo-war-industrie) : le besoin de l'équipe est ÉVALUÉ (défense, reconstruction, recrues ; shared/ai3/reserve.lua)
  -- et couvert par le coffre : la réserve de fer de croissance n'a plus de raison (le DC : « pour aucune raison »).
  local evaluated = f.is_player and Rsv.covered(f, tick) or false
  local grow_iron = evaluated and 0 or T.grow_iron_reserve
  if grow and (f.engineers_count or 0) >= floor and backlog > 0
    and tick - (f.team.last_grow or -T.grow_period) >= T.grow_period and hq_turrets >= T.defend_hq
    and iron0 >= grow_iron + 10 + (f.engineers_count or 0) then
    grow_due = true
    for _, o in ipairs(outposts) do
      if (o.turrets or 0) < T.defend_turrets(o.drills) then grow_due = false break end
    end
  end
  if grow_due then recruit_held = false end
  -- Lot FER-EQUIPE : fer gardé au coffre tant que la défense n'est pas couverte (shared/team/fer_equipe.lua), même sans tourelle
  -- possible (avant le lot, la réserve ne valait que `grow`, et 2 500 plaques partaient en 10 recrues avant la 4e minute).
  local iron_reserve
  if f.is_player then
    local needs = {}
    for _, o in ipairs(outposts) do needs[#needs + 1] = { turrets = o.turrets, need = T.defend_turrets(o.drills) } end
    local defended = FerEquipe.defended({ turret_ok = grow, hq_turrets = hq_turrets, defend_hq = T.defend_hq, outposts = needs })
    iron_reserve = FerEquipe.reserve(grow and T.grow_iron_reserve or nil, defended, evaluated)
  end
  -- Lot FLUX : les plaques qui dorment dans les sorties des avant-postes (view.repat) : le tableau retient autant de minage à la main
  -- (Board.sync / Board.add) et le fond les compte dans le stock de minerai ÉQUIVALENT ; la vue du planificateur, elle, ne change pas.
  -- Lot FLUX : niveau de remplissage des brûleurs pour les tournées de la pensée SUIVANTE et des tournées en cours (charbon du coffre,
  -- brûleurs de cette pensée) : shared/team/flux.lua, Fx.refill_to.
  local n_burners = 0
  for _, o in ipairs(outposts) do n_burners = n_burners + (o.burners or 0) end
  f.team.flux_fill = Flux.refill_to(stock0[T.fuel] or 0, n_burners, T.fuel_refill_to, Flux.REFILL_MAX)
  local repat = Flux.repatriable(outposts, REPAT_ONLY)
  local incoming = Src.incoming(f, Board.incoming(f), tick) -- lot MINAGE-MAIN : + ce que les tournées « fetch » rapporteront des sorties (jamais le stock libre)
  local smelter_out, smelter_low = Outposts.smelters_status(f)
  -- Lot FOURS : fours libres et fours à compléter, lus par la décision d'une tournée de fonte (shared/team/chaine_main.lua).
  local four_rule = Outposts.four_rule(f)
  local smelter_free, smelter_loads
  if four_rule then smelter_free, smelter_loads = Outposts.smelters_gate(f) end
  -- Lot BRIQUES : descripteurs des fours et fours à sortie pleine, pour le partage (shared/team/chaine_main.lua) ; absents règle coupée.
  local smelter_furnaces, smelter_blocked
  if Outposts.partage_rule(f) then smelter_furnaces, smelter_blocked = Outposts.smelter_furnaces(f), Outposts.smelters_blocked(f) end
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
    effectif.margin_item = s.margin_item -- lot INDUSTRIE I1 : la marge de la recrue entre au besoin évalué (shared/ai3/reserve.lua)
    effectif.left_iron = s.left[s.margin_item] or 0
    effectif.free_kinds = s.free_kinds
    recruit_held = not effectif.recruit
    -- Recrue décidée : son équipement se fabrique à la valeur du travail qu'elle débloque (prix fictif, borné 55 à 89 :
    -- sous les urgences), et non plus à 55 derrière les fabrications de l'armée (72 à 83).
    if effectif.reason == "recrue" then recruit_prio = Effectif.kit_prio(effectif.value) end
  end
  -- Lot QGSURVIE (shared/team/survie_qg.lua) : votre équipe seulement. Règle 1 : réserve de fer du QG (lue par script/team/build.lua, un
  -- module neuf ne prend rien au coffre dessous), recalculée quand la technologie change. Règle 2 : recrue retenue dans un QG sans
  -- tourelle armée sous l'attaque (script/team/survie_qg.lua, journal [FO-QGSURVIE]).
  if f.is_player and T.qg_reserve_on then
    -- (relue tant que la recette de la tourelle n'est pas acquise : sans elle, le livre rend la tourelle comme matière première, 0 fer)
    if f.team.qg_reserve == nil or f.team.qg_reserve_tech ~= f.tech or not f.team.qg_reserve_full then
      local fe = T.outposts.iron.product
      local book = book_for(f)
      local rt, rm = book:raw_cost({ { T.turret, 1 } }), book:raw_cost({ { T.turret_ammo, 1 } })
      f.team.qg_reserve = Sq.qg_reserve({ floor = T.defend_iron_floor, turret_iron = rt[fe], mag_iron = rm[fe] })
      f.team.qg_reserve_tech, f.team.qg_reserve_full = f.tech, ((rt[fe] or 0) > 0) or nil
    end
  else
    f.team.qg_reserve, f.team.qg_reserve_tech, f.team.qg_reserve_full = nil, nil, nil
  end
  if f.is_player and T.qg_recruit_hold_on and SurvieQg.recruit_hold(f, tick, hq_threat) then
    hold_recruits = true
    -- EFFONDREMENT (choix (1) du lead, 7/11 : garde GARDÉE) : journal [FO-RECRUE] d'une recrue gratuite retenue, au plus 1 par minute
    -- (shared/team/spirale.lua). Retenue ⇒ 0 tourelle armée au QG (Sq.recruit_hold). Journal seul.
    if Sp.free({ workers = f.engineers_count or 0, recover_floor = floor }) and Sp.log_due(f.team.recrue_log, tick) then
      f.team.recrue_log = tick
      local near, n = nil, 0
      for _, u in ipairs(f.hq.surface.find_entities_filtered({ position = f.hq_pos, radius = T.hq_threat_radius, force = "enemy",
        type = "unit" })) do
        local dx, dy = u.position.x - f.hq_pos.x, u.position.y - f.hq_pos.y
        local d2 = dx * dx + dy * dy
        n = n + 1
        if not near or d2 < near then near = d2 end
      end
      log(Sp.held_text({ key = f.key or "player", dist = near and math.sqrt(near) or nil, biters = n, armed = 0,
        workers = f.engineers_count or 0, floor = floor, minutes = tick / 3600 })) -- minutes de partie, comme [FO-QGSURVIE]
    end
  end
  -- EFFONDREMENT (filet de recul, décision du DC, 7/11 vers 16 h 56) : après des recrues gratuites tuées vite, la suivante attend
  -- (shared/team/spirale.lua, f.team.recul écrit à la mort d'un PNJ, script/team/worker.lua) ; journal [FO-RECRUE] au plus 1 par minute.
  local recul_wait = nil
  if f.is_player and f.team.recul and Sp.free({ workers = f.engineers_count or 0, recover_floor = floor })
    and not Sp.recul_ready(f.team.recul, tick) then
    recul_wait = true
    if Sp.log_due(f.team.recul_log, tick) then
      f.team.recul_log = tick
      log(Sp.recul_held_text({ key = f.key or "player", left = (f.team.recul.next_at or tick) - tick, wait = f.team.recul.wait,
        workers = f.engineers_count or 0, floor = floor, minutes = tick / 3600 }))
    end
  end
  -- Lot VIDEO-L3 : manque mesuré (script/team/manque_vue.lua, une fois par minute) sur le stock LIBRE, rendu À CÔTÉ de view.stock, jamais
  -- dedans (piège du lot FLUX) ; lu par la collecte (f.team.mq), la survie (view.mq) et la capitalisation (Mq.sinks).
  local mq = ManqueVue.think(f, tick, stock_free, { effectif = effectif, recruit_prio = recruit_prio })
  Profiler.fstop("view:4-fin") -- lot PERF (fusion de l'intégrateur : la mesure fine couvre aussi la règle d'effectif)
  -- Lot X10-S0 : le constructeur final (appels compris, même ordre) mesuré par « view:5-queue » et ses sous-portées (mesure seulement)
  Profiler.fstart("view:5-queue")
  local out = {
    tech = f.tech, personality = f.personality, done = f.team.done, deferred = f.team.deferred,
    stock = stock_free, incoming = incoming, repat = repat,
    -- lot VIDEO-L3 : manque mesuré (nil : éteint) : besoins et part à construire par objet (le résultat entier reste dans f.team.mq.res :
    -- la vue est COPIÉE à chaque pensée par Et.keep_e1) ; sorties dont la collecte est prise (disponibles) et sorties qui dorment
    mq = mq and { need = mq.need, build = mq.build } or nil, avail_out = mq and mq.dispo_sorties or nil, dort = mq and mq.dort or nil,
    sorties_on = f.team.sorties_regle ~= false or nil, -- lot CHARBON-MAIN : règle « sorties brutes d'abord » (shared/team/sorties_main.lua)
    outposts = outposts, pending = pend, sites = sites, sites_near = sites_near, -- lot SITE-PROCHE (R1)
    smelters = #Outposts.smelters(f), smelters_pending = smelters_pending,
    smelter_task = Board.has(f, "smelt"), smelter_output = smelter_out, smelter_fuel_low = smelter_low,
    smelter_coal = Profiler.fwrap("view:5-fours", Outposts.coal_needed_for, Outposts.smelters(f)),
    build_burn = Profiler.fwrap("view:5-burn", Build.burn_rate, f, game.tick), -- lot INTEG-ECONOMIE (D4) : charbon/s des fours du plan directeur (bilan du charbon du planificateur)
    fuel_mining_time = fuel_mining_time(), -- lot CHARBON-CAPACITE (F485) : temps de minage de la ressource du combustible (prototypes)
    four_rule = four_rule, smelters_free = smelter_free, smelter_loads = smelter_loads, -- lot FOURS
    smelter_furnaces = smelter_furnaces, smelter_blocked = smelter_blocked, -- lot BRIQUES
    turret_groups = groups,
    turret_ammo = T.munitions_on and Outposts.ammo_name(f.tech, f) or nil, -- lot MUNITIONS : munition fabriquée et portée (planificateur, cerveau)
    soldiers = f.soldiers_count, soldiers_max = soldiers_max,
    -- lot DEPENSES2 (b) : plafond des factions, celui des soldats que votre équipe paie sur son stock qui dort (0 sans guerre lancée)
    army_cap = (war.settings and war.settings.soldiers_max) or 0,
    workers = f.engineers_count, workers_max = workers_max, workers_idle = workers_idle, workers_waiting = workers_waiting,
    workers_fond = on_fond, -- lot ZERO-IDLE : PNJ au fond doux (minage à la main, garde) : des bras prêts à poser une fonderie (shared/ai3/zero_idle.lua)
    backlog = backlog, -- lot VIDEO-L6 : tâches libres qui attendent (porte « transport saturé », Capi.portes, script/ai3/capitalisation.lua)
    workers_wanted = workers_wanted, recruit_cost = recruit_cost, recruit_blocked = recruit_blocked,
    recruit_held = recruit_held, recruit_prio = recruit_prio, -- lot IA3-d : priorité de l'équipement d'une recrue décidée
    -- Lot IA2-a : une faction suit l'ordre des objectifs de son chef (T.ladder réordonné selon ses postures,
    -- prérequis gardés) ; sans chef (avant sa première pensée), T.ladder.
    ladder = f.is_player and T.player_ladder or ChefRules.ladder_entries(f.chef), no_research = f.is_player or false,
    threatened = threatened,
    threat_held = MenaceEq.observe(f, tick) or nil, -- lot L12 (partie 3) : menace tenue (une mesure par pensée), lue SEULEMENT par la capitalisation
    -- Lot ARMEE-ANTICIPATION : vague annoncée (script/ai3/soldats.lua, f.armee) : l'armée visée monte au besoin estimé, avec la
    -- priorité de la défense (shared/team/planner.lua). Factions seulement (votre équipe n'a pas de soldats : soldiers_max = 0).
    -- Lot PREVISION : alerte d'ÉTAT (cadre « préparer » de la première vague ouvert, script/ai3/prevision.lua ; plus d'horloge) ;
    -- army_soon : armée visée à moyen terme (vague à 15 min contre les tourelles), servie sans priorité de défense.
    army_alert = (f.armee and f.armee.alert == true) or nil, army_need = (f.armee and f.armee.alert and f.armee.need) or nil,
    army_soon = (f.prevision and f.prevision.pc and (f.prevision.pc.army_soon or 0) > 0 and f.prevision.pc.army_soon) or nil,
    qg_peril = Profiler.fwrap("view:5-survieqg", SurvieQg.update, f, tick), -- lot S1 : péril du QG (shared/team/survie_qg.lua) ; lu par le planificateur (priorité, planchers, tourelles du QG)
    survie = Survie.on(f) or nil, -- lot SURVIE-PENURIE : mode survie (décidé à la pensée précédente) : la production passe avant la défense
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
    thermal_off = Elec.view_off(f, tick), -- lot ELECTRIQUE (a) : types d'avant-poste refusés en thermique ({ [type] = raison } ou nil), lu par shared/ai3/projets.lua
    recul_wait = recul_wait, -- EFFONDREMENT : recrue gratuite en recul (planificateur, bloc de reprise)
    -- Tourelles du QG voulues : votre équipe seulement (une faction garde son QG avec ses soldats ; T.defend_first_factions).
    front = Profiler.fwrap("view:5-front", Front.view, f, fortify_open), -- lot DEFENSE-FRONT : tourelles en plus là où les pièces de l'équipe tombent, et près des laboratoires
    plant = Profiler.fwrap("view:5-garde", GardeCentrale.view, f, fortify_open, iron0), -- lot CENTRALE-GARDE : tourelles armées à portée de toutes les pièces de la centrale finie
    ilot = Profiler.fwrap("view:5-ilots", Ilots.view, f, fortify_open, iron0), -- lot ILOTS-MURS : 1 ou 2 tourelles par îlot isolé (poste facultatif, « ressources d'abord »)
    hq_turrets = hq_turrets, hq_fortify = fortify_open["hq"] or false, hq_defend = f.is_player and SurvieQg.hq_insure(f, tick, T.defend_hq, hq_turrets, iron0) or Profiler.fwrap("view:5-hqpost", Front.hq_post, f, hq_turrets, tick), -- une faction garde son QG avec ses 4 tourelles offertes (Fondation.grant) et ses soldats ; lot DEFENSE-FACTIONS D3 : 2 tourelles refaites si une a été perdue ET que le QG a été attaqué
    iron_flow = ((not f.is_player) and Profiler.fwrap("view:5-ironflow", iron_flow, f)) or nil, -- lot INTEG-DEFENSE D-A : lu par shared/team/planner.lua (iron_producing) ; factions seulement : les statistiques de la force « player » comptent l'usine du joueur, pas le coffre de l'équipe
    -- Lot INTEG-DEFENSE D-D : dernier choix « production d'abord » retenu et nombre de pensées de suite qui ont demandé le contraire (hystérésis
    -- de Pr.decide ; écrits plus bas par Team.think, f.team.priorite_pf et f.team.priorite_streak)
    priorite_pf = (f.team.priorite_pf or false), priorite_streak = f.team.priorite_streak or 0,
    hq_guards = hq_guards, hq_threat = hq_threat or nil, grow_reserve = (grow and not evaluated) and T.grow_iron_reserve or nil, iron_reserve = iron_reserve, grow_due = grow_due or nil,
    -- Lot IA2-b (F209) : orphelins à démonter (factions seulement).
    orphans = (not f.is_player) and Profiler.fwrap("view:5-orphelins", Outposts.orphan_groups, f, tick) or nil,
  }
  -- Lot DEFENSE-STOCK : après le front (la cellule qu'il sert n'est pas doublée) ; poste facultatif, stock seulement
  out.reserve = Profiler.fwrap("view:5-reserve", DefStock.view, f, fortify_open, out, stock_free, hq_turrets, outposts)
  Profiler.fstop("view:5-queue")
  return out
end

---------------------------------------------------------------------------------------------------
-- Mesures publiées (lot IA1-a, docs/EQUIPES_PNJ.md §16) : inactivité RÉELLE (PNJ sans tâche à la pensée) et
-- exécutants AU-DELÀ DU CARNET (O.pole_targets : travail ouvert + restant à l'horizon de 5 min), séparément.
-- Cumulées par pensée dans f.team.scale (lues par l'interface « fo-ia1 » ; moyennes = sommes / pensées).
---------------------------------------------------------------------------------------------------
function Team.measure(f, view, tick)
  local b = Board.get(f)
  local orientation = Poles.orientation(f) -- lot IA1-b : l'orientation choisie, sinon la personnalité
  local m = Scale.metrics(b.list, f.engineers_count, view.workers_waiting or view.workers_idle or 0, orientation, view.threatened, tick)
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
-- Lot DÉCOUPAGE-PENSÉE (7/11, accord du lead) : une pensée en HUIT étapes, une par tick (shared/team/etapes.lua, Et.STAGES ;
-- critères : fo-logs/2026-11-07_DECOUPAGE-PENSEE/CRITERES.md et CRITERES-E1-E4.md). E1a (tick T) : vue, bascule, début du plan du
-- cerveau (Ia3.plan_a : recherche, prévision, automatisation) ; E1b (T + 1) : capitalisation (Ia3.plan_capi) ; E1c (T + 2) : fin du
-- plan (Ia3.plan_b, ou Planner.plan), journaux, tableau, pôles ; E2 (T + 3) : plan directeur ; E3 (T + 4) : reconstruction et
-- réparations ; E4 (T + 5) : marché, stock, recrues, armée, pièces, gisement ; E5 (T + 6) : foreuses ; E6 (T + 7) : champ, capital,
-- fin ; puis la « queue » de l'appelant (commandant : chef, veille, attaque). L'ordre des appels est celui d'avant. L'état gardé
-- (f.team.etape, global) porte des COPIES : vue entière et L de E1a à E1c, vue et plan gelés (Et.freeze) de E1c à E6, stock libre
-- de E4 à E6. Team.ETAPES = false : les huit étapes au tick T, d'un appel, par les mêmes fonctions et les mêmes copies.
---------------------------------------------------------------------------------------------------
local TT = { tails = {} }
Team.ETAPES = true
TT.TIMER = "fo-team-etape"

--- Fonctions laissées de côté par une copie gardée (une fonction n'est pas gardable dans global) : dit une fois par équipe.
TT.note_lost = function(f, tick, lost, where)
  if (lost or 0) > 0 and not f.team.etape_lost then
    f.team.etape_lost = tick
    log(string.format("[FO-ETAPES] %s : %d fonction(s) laissee(s) de cote dans la copie gardee (premiere : %s)", tostring(f.key or "player"),
      lost, tostring(where)))
  end
end

--- E1a (tick T) : vue, bascule, début du plan du cerveau. Rend l'état gardé de la pensée (prochaine étape : E1b) : COPIE entière de la
--- vue et des clés Et.L de L, d'une seule copie (une table partagée par la vue et L le reste).
TT.e1a = function(f, surface, tick, tail)
  Trace.log("team", f.key, #State.sorted_keys(f.outposts))
  Profiler.start("team:view")
  local view = Team.view(f, tick)
  -- Lot DEFENSE-CHOIX : base d'une FACTION menacée ou envahie (script/faction/defchoix.lua) ; lu par shared/team/planner.lua (Dc.turrets).
  -- Votre équipe garde sa règle (T.defend_hq tourelles au QG, toujours voulues).
  local base_state = (not f.is_player) and Profiler.fwrap("view:defchoix", DefChoix.base, f, surface, tick) or nil -- (X10-S0 : mesure)
  view.base_alert = (base_state and base_state.insecure) or nil
  Profiler.stop("team:view")
  Profiler.start("team:plan_a")
  -- Lot IA3-c : bascule figée par équipe à sa première pensée (script/ai3/cerveau.lua) ; éteinte : planificateur d'avant.
  local ia3 = Ia3.active(f, tick)
  local L = ia3 and Ia3.plan_a(f, view, book_for(f), surface, tick) or nil
  Profiler.stop("team:plan_a")
  local et = { n = 2, t0 = tick, tail = tail, sig = Et.SIG, ia3 = ia3, base_why = base_state and base_state.why or nil }
  local lost, where
  if Team.KEEP_HOOK then et.view, et.L = Team.KEEP_HOOK("e1a", view, L)
  else et.view, et.L, lost, where = Et.keep_e1(view, L) end
  TT.note_lost(f, tick, lost, where)
  return et
end

--- E1b (T + 1, et les ticks suivants tant que la décision de capitalisation découpée n'est pas finie : lot CAPI-DECIDE) : la
--- capitalisation (L.capi, copie). Rend vrai si l'étape est à rejouer au tick suivant. `rush` : tout finir dans ce tick.
TT.e1b = function(f, surface, tick, et, rush)
  if not et.ia3 then return false end
  Profiler.start("team:plan_capi")
  local capi, pending = Ia3.plan_capi(f, et.view, book_for(f), tick, et.L, { t = et.t0, rush = rush or false })
  if pending then
    Profiler.stop("team:plan_capi")
    return true
  end
  local lost, where
  if Team.KEEP_HOOK then et.L.capi = Team.KEEP_HOOK("capi", capi)
  else et.L.capi, lost, where = Et.keep(capi, "capi") end
  TT.note_lost(f, tick, lost, where)
  Profiler.stop("team:plan_capi")
  return false
end

--- E1c (T + 2) : fin du plan, journaux, objectifs, tableau, pôles, couloirs ; puis le gel de la vue et du plan pour E4 à E6.
TT.e1c = function(f, surface, tick, et)
  local view, ia3 = et.view, et.ia3
  Profiler.start("team:plan")
  local plan = ia3 and Ia3.plan_b(f, view, book_for(f), surface, tick, et.L) or Planner.plan(view, book_for(f))
  -- Lot BRIQUES (bancs seulement, f.team.bench_smelt posé par fo-ia1 bench_smelt_demand) : demande de fonte imposée, ajoutée au plan.
  if f.team.bench_smelt then
    plan.smelt = f.team.bench_smelt_seul and {} or plan.smelt or {}
    for _, p in ipairs(State.sorted_keys(f.team.bench_smelt)) do plan.smelt[p] = (plan.smelt[p] or 0) + f.team.bench_smelt[p] end
    local has = false
    for _, t in ipairs(plan.tasks) do
      if t.kind == "smelt" then
        t.smelt = plan.smelt
        has = true
      end
    end
    if not has and view.smelters > 0 and not view.smelter_task then
      plan.tasks[#plan.tasks + 1] = { key = "smelt", kind = "smelt", prio = 85, smelt = plan.smelt }
    end
  end
  Acier.apply(f, view, book_for(f), plan, tick) -- lot ACIER : bloc de fours d'acier demandé ; l'acier quitte le plan (tournées manuelles) quand un bloc fini produit assez
  local tasks_avant_filtre = plan.tasks
  -- Lot FOURS (remarque 13 du DC) : une tournée de fonte ne part que si elle sert (shared/team/chaine_main.lua) : minerai à
  -- charger dans un four libre ou à compléter, sortie qui vaut le déplacement, four à ravitailler avec du charbon au coffre.
  if view.four_rule then
    plan.tasks = ChaineMain.filter_tasks(plan.tasks, { inputs = T.smelter_inputs, stock = view.stock, output = view.smelter_output,
      fuel_low = view.smelter_fuel_low, fuel_stock = view.stock[T.fuel] or 0, free = view.smelters_free, loads = view.smelter_loads,
      collect_min = T.smelt_collect_min, blocked = view.smelter_blocked, furnaces = view.smelter_furnaces })
  end
  Profiler.stop("team:plan")
  Profiler.fstart("tt:journaux") -- lot PERF3 : portées fines de la partie non découpée de Team.think (mesure seulement)
  BriquesLog.think(f, view, plan, tasks_avant_filtre, tick)
  DefenseLog.think(f, view, plan, tick) -- lot DEFENSE-FACTIONS D1 : journal [FO-DEFENSE] (lecture seule, toutes les 5 min)
  FluxLog.think(f, view, tick) -- lot FLUX : journal [FO-FLUX] (lecture seule, toutes les 5 min)
  SortiesLog.report(f, view, tick) -- lot CHARBON-MAIN : journal [FO-SEC] (lecture seule, toutes les 5 min)
  -- Lot DEFENSE-CHOIX : journal [FO-DEFCHOIX], une ligne quand « tourelles du QG d'abord » commence ou finit (f.team.defchoix_first, écrit et
  -- lu ICI seulement, en événement).
  local dcp = plan.defchoix
  local dfirst = (dcp and dcp.first) or false
  if dfirst ~= (f.team.defchoix_first or false) then
    f.team.defchoix_first = dfirst
    log(string.format("[FO-DEFCHOIX] %s : %s a %.1f min : base %s, QG %d tourelle(s) sur %d voulue(s), %d payable(s) au-dessus des planchers, soldats %d",
      f.key or "?", dfirst and "TOURELLES DU QG AVANT LES SOLDATS" or "fin des tourelles d'abord", tick / 3600,
      tostring(et.base_why or "sure"), view.hq_turrets or 0, dcp and dcp.want or 0, dcp and dcp.paid or 0, view.soldiers or 0))
  end

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
  -- Lot PRIORITE-RESSOURCES : journal du passage « production d'abord » (le fer ne paie pas la défense ET la production,
  -- shared/team/priorite.lua), une ligne par changement ; aucune décision n'en dépend.
  local pri = plan.priorite
  local pf = (pri and pri.production_first) or false
  -- Lot INTEG-DEFENSE D-D : pensées de suite où la règle brute (sans hystérésis) demande l'autre mode que le retenu ; lu par Team.view
  -- (view.priorite_streak) puis par Pr.decide. Écrit ici, en événement (jamais à on_load).
  local raw = (pri and pri.raw_first) or pf
  f.team.priorite_streak = (raw ~= pf) and ((f.team.priorite_streak or 0) + 1) or 0
  if pf ~= (f.team.priorite_pf or false) then
    f.team.priorite_pf = pf
    log(string.format("[FO-PRIORITE] %s : %s a %.1f min : fer %d, defense %d, prochain pas de production %s, mis de cote %d, objectifs militaires sautes %d",
      f.key or "?", pf and "PRODUCTION d'abord" or "defense et production payees", tick / 3600, math.floor(pri and pri.funds or 0),
      math.floor(pri and pri.defense_cost or 0), tostring(pri and pri.production_cost and math.floor(pri.production_cost) or "aucun"),
      math.floor(pri and pri.hold or 0), plan.skipped_goals or 0))
  end

  -- Besoins de prospection, par ressource.
  local needs = {}
  for kind, n in pairs(plan.site_needs) do needs[T.outposts[kind].resource] = n end
  -- Une réserve d'un site par type déjà exploité, pour l'expansion suivante.
  f.site_needs = needs
  Profiler.fstop("tt:journaux")

  Profiler.start("team:board")
  Board.sync(f, plan.tasks, tick, plan, view, book_for(f)) -- lot IA3-b : manque de plaques (réglage allumé)
  Bail.think(f, tick) -- lot ETAGE4 : une tournée prise sans progrès depuis Bl.LEASE est rendue (le PNJ abandonne, puis est dégagé)
  SurvieQg.note_plan(f, plan) -- lot S1 : une tourelle est-elle posable ? (les attentes de protection ne valent que si oui)
  Survie.think(f, view, plan, tick) -- lot SURVIE-PENURIE : entrée / sortie du mode survie et ses tâches (minage à la main, fours, foreuses)
  Profiler.stop("team:board")

  -- Lot IA1-b : organisation (pôles, managers, généralistes) et travail de fond, sur le tableau synchronisé.
  Profiler.start("team:poles")
  Poles.think(f, view, book_for(f), tick, plan)
  if ia3 then Ia3.after_poles(f, tick) end -- lot IA3-c : pas de fond sur une matière saturée
  for _, a in ipairs(Poles.sur_stops(f)) do Worker.abort(a, f, tick, "preempte") end -- intégration 0.6.30 : la file sûre cède au travail du cerveau
  for _, a in ipairs(Rappel.stops(f, tick)) do Worker.abort(a, f, tick, "preempte") end -- lot COLLECTE : une tâche >= 90 libre sans PNJ libre rappelle un PNJ occupé
  Profiler.stop("team:poles")
  Build.couloir_report(f, tick) -- lot ÉTAGE 5 (revue B3, 2e relecture) : bilan [FO-COULOIR] de TOUTES les équipes, plan directeur ou non
  -- Gel pour E4 à E6 : seuls les champs de Et.VIEW et Et.PLAN (la vue entière et L ne servent plus).
  local fz = TT.freeze(view, plan, ia3)
  TT.note_lost(f, tick, fz.lost, fz.lost_where)
  et.view, et.plan, et.L = fz.view, fz.plan, nil
end

TT.e2 = function(f, surface, tick)
  -- Lot IA1-d : tâches du plan directeur (chantiers, défrichage, quais) ; rien pour une équipe sans plan.
  if f.build then
    Profiler.start("team:build")
    Build.think(f, surface, tick)
    Profiler.stop("team:build")
  end
end

TT.e3 = function(f, surface, tick)
  -- Lot COUVERTURE : pièces de l'équipe détruites, à refaire (tâches « rebuild » ; rien tant que rien n'a été détruit).
  Profiler.fstart("tt:recon")
  Recon.think(f, surface, tick)
  Profiler.fstop("tt:recon")
  Profiler.fstart("tt:reparation")
  Reparation.think(f, surface, tick) -- lot PD-REPARATION (D79) : autres bâtiments endommagés (labos, fours, assembleurs, foreuses...), toutes les équipes
  Profiler.fstop("tt:reparation")
  Profiler.fstart("tt:repair")
  Recon.repair_think(f, surface, tick) -- lot RECONSTRUIRE : infrastructure électrique endommagée remise à neuf
  Profiler.fstop("tt:repair")
end

--- E4 (T + 5) : marché, mesures, stock (recrues, armée), pièces, gisement. Garde une COPIE du stock libre et pile_hold pour E5 et E6.
TT.e4 = function(f, surface, tick, et)
  local view, plan, ia3 = et.view, et.plan, et.ia3
  Profiler.fstart("tt:inter")
  Inter.think(f, tick) -- lot MAIN-ET-INTERMEDIAIRES (D09, D10) : tâches libres retirées AVANT le marché (minage à la main fourni par les machines, quais d'un module au plafond)
  Src.think(f, tick, view.workers_waiting or view.workers_idle or 0) -- lot MINAGE-MAIN : tournées vers les sorties qui dorment, minages libres des ressources qu'elles fournissent retirés (AVANT le marché)
  -- Lot IA3-b : meilleures paires PNJ inactif × tâche (place de marché, réglage allumé). Fusion IA-V2 : APRÈS le plan
  -- directeur (le plan crée ses tâches, puis le marché les attribue ; consigne de l'intégrateur, 27/10).
  Profiler.fstop("tt:inter")
  Profiler.start("team:market")
  Board.assign(f, tick)
  Profiler.stop("team:market")

  Profiler.fstart("tt:idle")
  -- Lot IA1-a : mesures publiées (inactivité réelle ; exécutants au-delà du carnet) et cases du QG revalidées
  -- à tour de rôle.
  -- Lot IA1-b2 (complément du DC, 25/10 vers 11 h 25) : raisons d'attente des PNJ sans tâche à la pensée : « rien »
  -- (aucune tâche libre au tableau), « bloque » (des tâches libres, mais d'un autre pôle ou en pause), « manque » (le
  -- cerveau attend des objets au coffre : affiché au-dessus du coffre, f.team.missing).
  local idle_n = view.workers_waiting or view.workers_idle or 0
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
  Profiler.fstop("tt:idle")
  Profiler.start("team:scale")
  Team.measure(f, view, tick)
  Worker.check_slots(f, surface, Scale.SLOT_CHECKS_PER_THINK)
  if plan.recruit_blocked then f.stats.recruit_guard = (f.stats.recruit_guard or 0) + 1 end
  if plan.recruit_held then f.stats.recruit_held = (f.stats.recruit_held or 0) + 1 end
  -- Lot FER-EQUIPE : première recrue retenue par la réserve de fer (une fois par équipe ; journal seul, aucune décision).
  if plan.grow_short and view.iron_reserve and not f.team.fer_reserve_logged then
    f.team.fer_reserve_logged = tick
    log(string.format("[FO-FER] %s : reserve de fer active, recrue retenue : fer %d, reserve %d + cout %d, effectif %d/%d a %.1f min",
      f.key or "?", view.stock[T.outposts.iron.product] or 0, view.iron_reserve,
      FerEquipe.recruit_iron(view.recruit_cost, T.outposts.iron.product), view.workers or 0,
      view.workers_wanted or 0, tick / 3600))
  end
  Profiler.stop("team:scale")

  Profiler.fstart("tt:stock")
  -- Décisions immédiates sur le stock (relu : les tâches n'ont encore rien pris). Lot IA3-b : stock LIBRE (réglage).
  local stock = Board.view_stock(f, stock_of(f), tick)
  local cost = view.recruit_cost
  -- Lot IA2-a2 (survie) : recrue équipée AU QG avec les plaques du stock (plan.recruit_uses : objets prélevés).
  local pay = plan.recruit_uses or cost
  -- EFFONDREMENT (décision du DC, 7/11 : « je veux toujours n ouvriers minimum, donc 12 si 12 au départ. Au delas ça coute des
  -- ressources ») : votre équipe sous son effectif de départ recrute GRATUITEMENT (plan.recruit_free, shared/team/spirale.lua) :
  -- rien n'est pris au coffre ; la recrue est équipée comme une autre (Worker.recruit, free : kit offert, jamais rendu au coffre).
  local free = f.is_player and plan.recruit_free or false
  if plan.recruit_workers and not plan.recruit_unarmed and (free or has_list(stock, pay)) then
    if not free then remove_list(f, pay) end
    local recruit = Worker.recruit(f, surface, tick, false, free)
    if recruit then
      f.stats.recruited = (f.stats.recruited or 0) + 1
      if free then -- EFFONDREMENT (filet de recul) : arrivée datée (mort rapide, script/team/worker.lua) ; en recul, la suivante attend
        recruit.free_born = tick
        if f.team.recul then Sp.recul_spawn(f.team.recul, tick) end
      end
      if view.grow_due then f.team.last_grow = tick end -- lot IA1-b2 : rythme de la croissance
      -- Lot IA3-d : recrue de CROISSANCE d'une faction (rythme de la règle d'effectif).
      if view.effectif and view.effectif.reason == "recrue" and not plan.emergency_recruit then
        Effectif.grown(f.team.effectif, tick)
      end
      if free then f.stats.free_recruits = (f.stats.free_recruits or 0) + 1 end
      if plan.recruit_uses or free then
        f.stats.emergency_recruits = (f.stats.emergency_recruits or 0) + 1
        -- Votre équipe peut travailler sans guerre (State.war().started nil) : minutes comptées depuis sa fondation,
        -- comme « objectif atteint » plus haut.
        log(string.format("[FO-TEAM] %s : survie, recrue %s au QG (effectif %d, depart %d) a %.1f min", f.key,
          free and "GRATUITE equipee" or "equipee", f.engineers_count or 0,
          (view.emergency and view.emergency.floor) or view.recover_floor or 0,
          (tick - (f.started or State.war().started or 0)) / 3600))
      end
    elseif not free then
      for _, it in ipairs(pay) do Stock.insert(f, it[1], it[2]) end
    end
    stock = Board.view_stock(f, stock_of(f), tick)
  -- Lot QGSURVIE (règle 2) : pas de recrue sans arme non plus dans un QG sans tourelle armée sous l'attaque (f.team.s1.hold, écrit par
  -- SurvieQg.recruit_hold à la vue) : celle de l'équipe vide y mourait toutes les 6 s (tour 1, 51,7 à 54,6 min).
  elseif plan.recruit_unarmed and (f.engineers_count == 0 or (plan.emergency_unarmed and f.engineers_count < 2))
    and not (f.is_player and T.qg_recruit_hold_on and f.team.s1 and f.team.s1.hold) then
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
    if f.is_player then Dep.on_trained(f, tr.unit, made, game.tick) end -- lot DEPENSES2 (R1) : journal de la paie des soldats de votre équipe
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
  -- Lot COUVERTURE : refaire ce qui est détruit AVANT d'améliorer ce qui reste (constat du DC du 28/10).
  Profiler.fstop("tt:stock")
  Profiler.fstart("tt:spares")
  Recon.craft_spares(f, book_for(f), stock, tick) -- lot RECONSTRUIRE : objets d'infrastructure électrique à fabriquer
  Profiler.fstop("tt:spares")
  -- Lot PILE-PRIORITE (« on répare + protège […] et ensuite on continue et on améliore », DC 29/10) : tant qu'un cadre réparer,
  -- protéger ou survivre retient (shared/ai3/pile.lua, f.team.ia3.pile, écrit par la pensée juste avant), ni changement de
  -- foreuses, ni migration du champ, ni amélioration payée. Garde AJOUTÉE à côté de celle de la reconstruction (lot SANS-GEL).
  local pile_hold = ia3 and PileRt.hold(f)
  Profiler.fstart("tt:gisement")
  Gisement.think(f, surface, tick, book_for(f)) -- lot GISEMENTS (retour du DC du 31/10) : foreuses à combustion à l'arrêt rebranchées ou retirées du gisement (rend tout au stock)
  Profiler.fstop("tt:gisement")
  -- Le stock libre passe à E5 et E6 sans être relu, comme avant le découpage (il était passé tel quel à FoSwap, MigChamp et au capital).
  local lost, where
  if Team.KEEP_HOOK then et.stock = Team.KEEP_HOOK("stock", stock)
  else et.stock, lost, where = Et.keep(stock, "stock") end
  TT.note_lost(f, tick, lost, where)
  et.pile_hold = pile_hold
end

--- E5 (T + 6) : foreuses thermiques remplacées par des électriques (retenu par la pile).
TT.e5 = function(f, surface, tick, et)
  -- lot FOREUSES-THERMIQUES (partie C) : électrique sans courant rendue thermique quand le réseau tombe ; une RÉPARATION, jamais retenue
  -- par la pile. AVANT le remplacement : une électrique posée à ce tick est sans courant (tampon vide, banc foreuses-panne-diag du 8/11) ;
  -- vue seulement à la pensée suivante, quand elle a du courant.
  Profiler.fstart("tt:repli")
  FoSwap.repli(f, surface, book_for(f), et.stock, tick)
  Profiler.fstop("tt:repli")
  -- lot ELECTRIQUE (a) : verdict relu à chaque pensée, retenue de la pile ou non (lu par le tableau : Board.sync, Board.add)
  Elec.think(f, book_for(f), tick)
  if not et.pile_hold then
    Profiler.fstart("tt:foswap")
    FoSwap.think(f, surface, book_for(f), et.stock, tick) -- lot FOREUSES (retour du DC du 29/10) : foreuses thermiques remplacées par des électriques alimentées
    Profiler.fstop("tt:foswap")
  end
end

--- E6 (T + 7) : migration du champ, capital, fin.
TT.e6 = function(f, surface, tick, et)
  local view, plan, ia3, stock, pile_hold = et.view, et.plan, et.ia3, et.stock, et.pile_hold
  -- lot MIGRATION-CHAMP (retour du DC du 29/10) : champ thermique migré par parties en rangées électriques. Lot THERMIQUE5 (revue du 3/11 : la
  -- retenue gelait balayage, dégel et chantier ; Azure et Scarlet retenues 99 à 100 % du temps, 139 thermiques et 0 électrique sur 271828182) :
  -- toujours pensée ; pendant la retenue, seul le départ d'une bande neuve est retenu (shared/team/thermique.lua, Th.pile_permits)
  Profiler.fstart("tt:migchamp")
  MigChamp.think(f, surface, book_for(f), stock, tick, pile_hold == true)
  Profiler.fstop("tt:migchamp")
  Profiler.fstart("tt:capital")
  -- Lot SANS-GEL : plus de gel des améliorations après une réouverture ; la reconstruction ne retient que sa matière (Recon.upgrade_stock).
  -- (Intégration 0.6.19 : garde de la pile ET stock libre de SANS-GEL, les deux gardés.)
  -- Lot AMELIORATION (décision du lead, 8/11) : avec la montée par bloc, le gel est LEVÉ sauf manque : le lot est permis si le stock couvre
  -- son coût PLUS les pièces manquantes des projets rouverts, objet par objet (shared/ai3/amelioration.lua, cause reconstruction:<objet>).
  local recon_hold = ia3 and Recon.hold_upgrades(f) and not Ia3.blocs_on()
  -- Lot AGES : le gel du centre n'est pas indéfini (shared/team/degel.lua) : au-delà de 20 min de gel cumulées, et la défense minimale du QG
  -- tenue, le centre (lui seul) se paie avec le stock moins la réserve de la reconstruction (SANS-GEL).
  local thaw = ia3 and (pile_hold or recon_hold) and Ia3.capital_thaw(f, true, tick)
  if ia3 and not (pile_hold or recon_hold) then
    Ia3.capital_thaw(f, false, tick)
    Ia3.capital_pay(f, surface, tick, plan, Recon.upgrade_stock(f, book_for(f), stock, tick, plan))
  elseif ia3 then
    local paid, skipped = 0, true
    -- Mesure (essai 6, graine 271828182, emerald 151,6 min) : fer 35 571, cuivre 8 057, briques 404 au coffre, mais « electronic-circuit
    -- 0/60 » au stock libre : les 138 circuits du coffre sont retenus par la reconstruction de 12 projets rouverts (Recon.upgrade_stock,
    -- [FO-REBUILD-PRIO]) que l'ennemi empêche de refaire. Le gel levé paie donc le centre sur le stock du coffre SANS cette retenue : la
    -- défense minimale est tenue (floor_ok) et le gel a duré plus de Dg.AFTER ; refaire une pièce attend, le centre non.
    if thaw then paid, skipped = Ia3.capital_pay(f, surface, tick, plan, stock, true) end
    if paid == 0 and skipped then -- sinon Capital.pay a déjà dit sa cause
      Ia3.capital_attente(f, pile_hold and "pile" or "reconstruction", tick) -- lot C1 : la cause d'une amélioration retenue est dite
    end
  end
  if ia3 then PileRt.journal(f, tick) end -- lot PILE-PRIORITE : journal [FO-PILE] (changement de sommet, toutes les 5 min)
  Profiler.fstop("tt:capital")
  Profiler.fstart("tt:fin")
  if plan.research and has_list(stock, T.research[plan.research]) then
    remove_list(f, T.research[plan.research])
    f.tech = plan.research
    unlock(f, f.tech)
    log(string.format("[FO-TEAM] %s : recherche niveau %d payee en packs a %.1f min", f.key, f.tech, (tick - State.war().started) / 3600))
  end
  Build.Hygiene.reveil(f, stock, tick) -- lot SCAN-EVENEMENTS (DC 9/11) : réveil du scan sur palier de stock, coupure d'énergie, rupture de ressource (script/team/scan_reveil.lua)
  Ia3.measure(f, tick, plan) -- lot IA3-c : paliers de recherche et projets, mesurés avec les deux cerveaux
  Team.effectif_journal(f, view, tick) -- lot IA3-d : ligne minute « [FO-EFFECTIF] »
  Team.plafond_journal(f, view, stock, tick) -- lot JOURNAUX-DC : plafond d'ouvriers atteint avec du fer inemployé
  -- Lot COFFRE : l'excédent du coffre du QG passe aux annexes, et un coffre se pose quand les cases se remplissent.
  Stock.balance(f)
  Stock.grow(f, surface, tick)
  Profiler.fstop("tt:fin")
end

--- Gel de la vue et du plan pour E4 (tests : Team.FREEZE_HOOK remplace la copie par un enregistreur ou une copie stricte).
TT.freeze = function(view, plan, ia3)
  if Team.FREEZE_HOOK then return Team.FREEZE_HOOK(view, plan, ia3) end
  return Et.freeze(view, plan, ia3)
end

TT.key = function(f) return f.is_player and "player" or f.id end
--- Lot LOURD (point 2 c) : demandeur du jeton des travaux lourds pour les étapes d'une pensée (même forme que « <clé>:rv » et « <clé>:ra »).
TT.who = function(f) return tostring(f.key or "player") .. ":etape" end

TT.surface_of = function(f)
  if f.is_player then return f.hq.surface end
  return game.surfaces[State.war().surface]
end

--- Une étape attendue ne se joue que si l'équipe vit encore (mêmes gardes que les deux appelants de Team.think).
TT.alive = function(f)
  if not (f.hq and f.hq.valid) or f.eliminated then return false end
  if f.is_player then return true end
  local war = State.war()
  return war.active and war.factions[f.id] == f
end

TT.count = function(t, k)
  local c = t.etapes or {}
  t.etapes = c
  c[k] = (c[k] or 0) + 1
end

--- Joue l'étape et.n (2 = E1b … 8 = E6, Et.STAGES) ; rend true après la dernière. E1b peut se rejouer (décision de capitalisation
--- découpée) : et.n reste alors à 2. `rush` : toute tranche restante dans ce tick (mode bloc, rattrapage).
TT.run = function(f, surface, tick, et, rush)
  local n = et.n
  if n == 1 then
    -- Lot LOURD (point 2 c ; condition 1 d'effondrement) : E1a en attente du jeton (Team.think) : jouée ici, par le minuteur ou par un
    -- rattrapage ; l'état rendu (t0 = le tick où E1a se JOUE, condition 3) remplace l'attente, la queue de l'appelant est gardée.
    f.team.etape = TT.e1a(f, surface, tick, et.tail)
    return false
  end
  if n == 2 then
    if TT.e1b(f, surface, tick, et, rush) then return false end
  elseif n == 3 then TT.e1c(f, surface, tick, et)
  elseif n == 4 then TT.e2(f, surface, tick)
  elseif n == 5 then TT.e3(f, surface, tick)
  elseif n == 6 then TT.e4(f, surface, tick, et)
  elseif n == 7 then TT.e5(f, surface, tick, et)
  else -- n == 8 (Et.SIG garde le sens des numéros : un état d'une autre version est effacé au changement de configuration)
    TT.e6(f, surface, tick, et)
    return true
  end
  et.n = n + 1
  return false
end

--- Joue l'étape attendue ; après E6, l'état gardé est effacé et la queue de l'appelant jouée.
TT.play = function(f, surface, tick, et, rush)
  if not TT.run(f, surface, tick, et, rush) then return end
  f.team.etape = nil
  TT.count(f.team, "pensees")
  local tl = et.tail and TT.tails[et.tail]
  if tl then tl(f, tick) end
end

--- Minuteur d'une étape : { key, n, t0 } ; une charge utile périmée (pensée déjà rattrapée) ne fait rien.
TT.step = function(pl, tick)
  local f = State.faction(pl.key)
  if not f then
    -- Lot LOURD (point 2 c ; trou relevé par effondrement, 8/11) : votre équipe a PRIS FIN pendant l'attente d'une étape (coffre perdu :
    -- player_team.lua met Storage.ns("pteam").team à nil) : plus aucune pensée à protéger, son entrée sort de la file (sinon elle
    -- retiendrait tout le budget J.STALE ticks). Les factions restent dans war.factions : leur abandon passe par TT.alive, plus bas. Une
    -- charge utile seulement PÉRIMÉE (équipe présente) ne retire rien : l'entrée appartient alors à la pensée en cours.
    if pl.key == "player" then Lourd.drop(TT.who({ key = "player" })) end
    return
  end
  local t = f.team
  local et = t and t.etape
  if not (et and et.n == pl.n and et.t0 == pl.t0) then return end
  if not TT.alive(f) then
    t.etape = nil
    Lourd.drop(TT.who(f)) -- (lot LOURD, point 2 c : l'entrée de la pensée abandonnée ne retient plus le budget)
    TT.count(t, "abandons")
    log(string.format("[FO-ETAPES] %s : pensee du tick %d abandonnee a l'etape %d (equipe ou QG disparu)", tostring(f.key or "player"),
      et.t0, et.n))
    return
  end
  -- Lot LOURD (point 2 c) : l'étape prend le jeton des travaux lourds (coûts A : tout le budget) ; refusée, RIEN n'est joué et la MÊME
  -- étape est redemandée au tick suivant (même charge utile) : aucune n'est perdue ni jouée deux fois, l'ordre est gardé.
  if not Lourd.take(tick, TT.who(f)) then
    Profiler.fstart("team:attente")
    Profiler.fstop("team:attente")
    Scheduler.after(1, TT.TIMER, { key = pl.key, n = pl.n, t0 = pl.t0 })
    return
  end
  -- (le nom est pris AVANT l'étape : TT.run avance et.n ; avant ce correctif, la portée ouverte « team:etapeN » était fermée sous le
  -- nom de l'étape suivante, chronomètres faux et pile du détail laissée ouverte jusqu'à la fin du tick)
  local scope = "team:etape" .. et.n
  Profiler.start(scope)
  TT.play(f, TT.surface_of(f), tick, et, false)
  Profiler.stop(scope)
  if t.etape then Scheduler.after(1, TT.TIMER, { key = pl.key, n = t.etape.n, t0 = t.etape.t0 }) end
end
Scheduler.define_timer(TT.TIMER, TT.step)

--- Relecture de 6fcfe757 (lead, 7/11) : une pensée en cours garde la SIGNATURE des listes de champs copiés pour E4 (Et.SIG). Au
--- changement de configuration, un état d'une autre signature (autre version de ces listes, ou d'avant la signature) est EFFACÉ,
--- avec une ligne au journal : E4 ne rejoue jamais une copie qui n'a pas les champs qu'il lit (en jeu, la copie n'est pas stricte :
--- un champ manquant vaudrait nil sans rien dire). La pensée suivante de l'équipe repart d'E1 (300 ticks au plus). Même signature :
--- l'état est gardé, ses étapes se jouent à leur tick (CRITERES.md P5). Suite E1-E4 (CRITERES-E1-E4.md) : un changement de VERSION
--- du mod efface aussi toute pensée en cours, même à signature égale (la vue gardée en entier n'a pas de liste de champs).
TT.MOD = "factorio-overhaul"
TT.config_changed = function(data)
  local mc = data and data.mod_changes and data.mod_changes[TT.MOD]
  local version = mc and mc.old_version ~= mc.new_version and (tostring(mc.old_version) .. " -> " .. tostring(mc.new_version)) or nil
  local list = {}
  local war = State.war()
  if war and war.factions then
    for _, id in ipairs(State.sorted_keys(war.factions)) do list[#list + 1] = war.factions[id] end
  end
  list[#list + 1] = State.faction("player")
  for _, f in ipairs(list) do
    local et = f and f.team and f.team.etape
    if et and (version or et.sig ~= Et.SIG) then
      f.team.etape = nil
      Lourd.drop(TT.who(f)) -- (lot LOURD, point 2 c : l'entrée de la pensée effacée ne retient plus le budget)
      TT.count(f.team, "effaces")
      if version then
        log(string.format("[FO-ETAPES] %s : pensee du tick %s effacee a l'etape %s au changement de version du mod (%s)",
          tostring(f.key or "player"), tostring(et.t0), tostring(et.n), version))
      else
        log(string.format("[FO-ETAPES] %s : pensee du tick %s effacee a l'etape %s au changement de configuration (champs gardes : %s, attendus : %s)",
          tostring(f.key or "player"), tostring(et.t0), tostring(et.n), tostring(et.sig), Et.SIG))
      end
    end
  end
end
Team.etapes_config_changed = TT.config_changed -- (champ du module : mutant « signature ignorée » des tests)
Events.on_configuration_changed(function(data) Team.etapes_config_changed(data) end)

--- Queue de l'appelant, jouée après E4 (une fonction n'est pas gardable dans global : la pensée garde son NOM).
function Team.define_tail(name, fn)
  assert(not TT.tails[name], "queue deja definie : " .. tostring(name))
  TT.tails[name] = fn
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
--- Rend false quand des étapes restent à jouer (minuteurs) : l'appelant ne joue pas sa queue, l'étape E4 la jouera.
function Team.think(f, surface, tick, tail)
  if not f.team then return nil end
  if f.team.etape then
    -- pensée précédente pas finie (ne devrait pas arriver : période de 300 ticks) : ses étapes d'abord, d'un bloc
    TT.count(f.team, "rattrapages")
    while f.team.etape do TT.play(f, surface, tick, f.team.etape, true) end
  end
  if Team.ETAPES then
    -- Lot LOURD (point 2 c ; décision Q2 du lead) : E1a prend le jeton au tick du créneau ; libre, elle se joue tout de suite (aucun
    -- décalage) ; pris, l'état « E1a en attente » (n = 1, avec la signature : condition 2 d'effondrement) est posé et le minuteur la
    -- joue au premier tick où le jeton est libre (TT.step, TT.run).
    local key = TT.key(f)
    local et
    if Lourd.take(tick, TT.who(f)) then
      et = TT.e1a(f, surface, tick, tail)
    else
      et = { n = 1, t0 = tick, tail = tail, sig = Et.SIG }
      Profiler.fstart("team:attente")
      Profiler.fstop("team:attente")
    end
    f.team.etape = et
    Scheduler.after(1, TT.TIMER, { key = key, n = et.n, t0 = et.t0 })
    return false
  end
  -- Mode « tout au tick T » : les mêmes étapes et les mêmes copies, d'un appel, sans jeton ; la queue est jouée par l'appelant.
  local et = TT.e1a(f, surface, tick, tail)
  repeat until TT.run(f, surface, tick, et, true)
  return true
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

--- Lot JOURNAUX-DC : d'où vient le plafond d'ouvriers d'une équipe (même règle que Team.npc_max) : le nom du réglage de carte,
--- ou nil quand c'est le nombre écrit au lancement de la guerre (commande, interface distante, bancs).
function Team.plafond_source(f)
  if f.is_player then return "fo-player-team-npc-max" end
  local s = State.war().settings or {}
  if s.npc_from_setting or not s.engineers_max then return "fo-war-workers" end
  return nil
end

--- Lot JOURNAUX-DC (point 2 du rapport CINQ-POINTS : Écarlate à 8/8 PNJ, raison « plafond » 301 minutes sur 312, 48 950 fers
--- libres à la fin) : suivi du plafond d'ouvriers (f.team.plafond, nombres seuls) et ligne [FO-PLAFOND] une fois par épisode,
--- quand l'équipe est au plafond depuis 30 min avec au moins 10 fois le fer d'une recrue au stock LIBRE. L'onglet « Partie »
--- (script/gui/partie.lua) lit la même alerte. Aucune décision : le plafond ne change pas.
function Team.plafond_journal(f, view, stock, tick)
  local iron = T.outposts.iron.product
  local st = f.team.plafond
  if not st then
    st = {}
    f.team.plafond = st
  end
  local a = JournauxDC.plafond_observe(st, tick, view.workers_wanted or 0, f.engineers_count or 0, (stock and stock[iron]) or 0,
    FerEquipe.recruit_iron(view.recruit_cost, iron))
  if a then
    local war = State.war() or {}
    log(string.format("[FO-PLAFOND] %s a %.1f min : plafond d'ouvriers atteint (%d PNJ) depuis %d min, %d fers inemployes "
      .. "(une recrue en coute %d, soit %d recrues) ; plafond donne par %s", f.key or "?",
      (tick - (f.started or war.started or 0)) / 3600, a.cap, a.minutes, a.fer, a.cout, a.recrues,
      Team.plafond_source(f) or "le nombre ecrit au lancement de la guerre"))
  end
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
  if shown == 0 then return { "fo-team.goal-line", Objectif.name(t.goal) } end
  return { "fo-team.goal-line-missing", Objectif.name(t.goal), parts }
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
