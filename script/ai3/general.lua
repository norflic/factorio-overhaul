--[[
  Lot IA-G « le cerveau général », côté RUNTIME : relie la règle pure (shared/ai3/general.lua, shared/ai3/catalogue.lua)
  au cerveau par besoins d'IA-V2 (script/ai3/cerveau.lua) pour les FACTIONS. Votre équipe n'est pas touchée (elle ne
  recherche pas ; ses ressources clés restent celles de repli, shared/ai3/reglages.lua).

  - Catalogue : RELEVÉ des prototypes (game.recipe_prototypes, game.technology_prototypes, game.entity_prototypes,
    game.item_prototypes), une fois, cache LOCAL (revue B1 : prototypes seulement, identiques chez tous les pairs). Les
    exécutants d'aujourd'hui (la main, le laboratoire du QG, les fours du QG et les foreuses des avant-postes : tables de
    l'exécutant, shared/team/config.lua) disent quelles machines existent pour l'équipe.
  - Décision de recherche (General.choose_tech, appelée par la recherche du QG à chaque pensée) : la technologie en cours
    reste tant qu'elle est payable (graphe) ; sinon Gen.choose sur l'état de la force (technologies faites, coffre et
    arrivées, laboratoires, fours du QG, foreuses posées, gisements connus). Une ligne [FO-CERVEAU] par décision : la
    technologie, sa valeur, son coût, son score, la chaîne des pourquoi, le dépliage, les ressources clés.
  - Ressources clés (General.key) : ordre des avant-postes, la plus demandée, le combustible, sans besoin, DÉDUITS du
    besoin brut des buts de la faction (la recherche choisie, le premier lot de soldats, la réserve de munitions) ;
    rangés dans f.team.iag (global : chaînes et nombres) à chaque décision ; lus par la pensée pure (ctx.key).
  - Exploration (General.explore) : une ressource INCONNUE qui bloque une technologie de valeur, et qu'un exécutant
    saurait extraire, est demandée (IA3-f).
  - Payabilité d'un pack de réserve (General.feasible) : faisabilité du graphe à la dernière évaluation.
  Mémo des points fixes par force : fonction PURE de la clé d'état (G.state_key), donc même résultat chez un pair qui
  le recalcule (B1) ; jamais dans global.
  Déterminisme : listes triées, aucun hasard, aucun temps mesuré.
]]

local T = require("shared.team.config")
local R = require("shared.ai3.reglages")
local K = require("shared.ai3.catalogue")
local Im = require("shared.ai3.impayable") -- lot RB-FLUIDE : la recherche impayable lâchée, reprise quand son pack est produit
local Br = require("shared.ai3.bras") -- lot SCALE : bras libres lissés
local Gen = require("shared.ai3.general")
local L = require("shared.ai3.lecture") -- lot INDUSTRIE I4 : bilan de la lecture des recettes et machines
local Jdc = require("shared.team.journaux_dc") -- lot JOURNAUX-DC : règle du journal [FO-MUR]
local B = require("shared.ai3.buts")
local Planner = require("shared.team.planner")
local State = require("script.faction.state")
local Profiler = require("script.core.profiler")
local Auto = require("script.ai3.automatisation") -- lot AUTO : exécutants de l'automatisation (Auto.on, Auto.exec_entities)
local Pet = require("script.ai3.petrole") -- lot PETROLE : exécutants des chaînes à fluides (Pet.on, réglage ALLUMÉ par défaut)

local General = {}

-- Aucun réglage de carte (settings.lua est un fichier de l'intégrateur) : allumé pour toute faction au cerveau par
-- besoins ; General.ENABLED = false rend l'ancien choix d'IA-V2 (tests, essais « avant »).
General.ENABLED = true
General.AUTO_STALL = 10 * 3600 -- lot AUTO (K1, IA3-e) : recherche pour l'automatisation sans unité payée depuis 10 min…
General.AUTO_PAUSE = 20 * 3600 -- … les autres passent 20 min
-- Votre équipe : une recherche (quelle qu'elle soit) sans unité payée depuis 8 min laisse la place aux autres pendant 30 min
-- (un joueur ne garde pas son seul laboratoire sur une recherche dont il ne peut pas fabriquer les packs : moteur réel,
-- etape1-guide, « defender » gardait le laboratoire de 27,8 à 38,8 min, puis de 27,8 à 49,3 min).
-- Lot RB-FLUIDE : la même garde vaut pour les FACTIONS (partie de 4 h, C4 : `military-3` tient le laboratoire 157 min sans pack) ; règle pure
-- shared/ai3/impayable.lua, qui porte ces deux durées.
General.PLAYER_STALL = Im.STALL
General.PLAYER_STALL_PAUSE = Im.PAUSE
General.ARMY_FIRST = B.ARMY_FIRST_N
General.AMMO_STOCK = B.AMMO_STOCK

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

local function keys_list(dict)
  local out = {}
  for k in pairs(dict or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

---------------------------------------------------------------------------------------------------
-- Relevé des prototypes et catalogue (cache LOCAL)
---------------------------------------------------------------------------------------------------
local cat = nil
local memos = {}

-- Lot INDUSTRIE I4 : emprise (tuiles) et boîtes à fluide d'un prototype, lues telles quelles (même lecture que
-- script/ai3/petrole.lua, qui garde la sienne pour ses cellules).
local function size_of(p)
  local w, h = get(p, "tile_width"), get(p, "tile_height")
  if w and h and w > 0 and h > 0 then return w, h end
  local cb = get(p, "collision_box")
  if not cb then return 1, 1 end
  return math.max(1, math.ceil(cb.right_bottom.x - cb.left_top.x - 0.02)), math.max(1, math.ceil(cb.right_bottom.y - cb.left_top.y - 0.02))
end

local function boxes_of(p)
  local out = {}
  for _, fb in ipairs(get(p, "fluidbox_prototypes") or {}) do
    local conns = { [0] = {}, [2] = {}, [4] = {}, [6] = {} }
    for _, pc in ipairs(get(fb, "pipe_connections") or {}) do
      if not pc.max_underground_distance or pc.max_underground_distance == 0 then
        for i, d in ipairs({ 0, 2, 4, 6 }) do
          local v = pc.positions and pc.positions[i]
          if v then conns[d][#conns[d] + 1] = { v.x or v[1], v.y or v[2] } end
        end
      end
    end
    local filt = get(fb, "filter")
    out[#out + 1] = { type = get(fb, "production_type") or "none", filter = filt and filt.name or nil, conns = conns }
  end
  return out
end

local function vec_of(v)
  if not v then return nil end
  return { x = v.x or v[1] or 0, y = v.y or v[2] or 0 }
end

--- Lot INDUSTRIE I4 : champs ajoutés au relevé d'une entité de fabrication (emprise, ingrédients solides au plus, recette
--- imposée, boîtes à fluide) ou d'une pièce du kit de logistique (R.KIT_TYPE : portée et cadence des bras, vitesse des
--- tapis, cases des coffres, fil et couverture des poteaux).
local function lecture_fields(en, e, ty, role)
  if role == "fabrique" then
    en.w, en.h = size_of(e)
    if not R.SOURCE_CAP[ty] then en.ingredient_count = get(e, "ingredient_count") end
    en.fixed_recipe = get(e, "fixed_recipe")
    en.boxes = boxes_of(e)
  end
  local kind = R.KIT_TYPE[ty]
  if kind == "bras" then
    en.pickup, en.drop = vec_of(get(e, "inserter_pickup_position")), vec_of(get(e, "inserter_drop_position"))
    en.rot, en.ext = get(e, "inserter_rotation_speed"), get(e, "inserter_extension_speed")
    en.filters, en.stack = get(e, "filter_count") or 0, get(e, "inserter_stack_size_bonus") or 0
  elseif kind == "tapis" then
    en.belt_speed = get(e, "belt_speed")
  elseif kind == "coffre" then
    local ok, n = pcall(function() return e.get_inventory_size(defines.inventory.chest) end)
    en.slots = ok and n or nil
  elseif kind == "poteau" then
    en.supply, en.wire = get(e, "supply_area_distance"), get(e, "max_wire_distance")
  end
end

local function amount_of(p)
  if p.amount then return p.amount end
  local a = ((p.amount_min or 0) + (p.amount_max or 0)) / 2
  return a * (p.probability or 1)
end

--- Lot RB-3 : ce que le relevé sait de l'attaque d'une unité (AttackParameters) : portée, portée minimale, cadence, zone (une action
--- de type « area » ou « cluster ») et les dégâts DIRECTS lisibles ; le DPS reste nil quand les dégâts ne sont pas dans le relevé
--- (projectile, flux : leurs dégâts sont dans un autre prototype). Chaque lecture est protégée : un champ absent donne nil.
local function read_attack(ap)
  local out = {}
  if not ap then return out end
  out.range, out.min_range, out.cooldown = get(ap, "range"), get(ap, "min_range"), get(ap, "cooldown")
  local at = get(ap, "ammo_type")
  local total
  for _, act in ipairs(get(at, "action") or {}) do
    local t = get(act, "type")
    if t == "area" or t == "cluster" then out.zone = true end
    for _, del in ipairs(get(act, "action_delivery") or {}) do
      for _, te in ipairs(get(del, "target_effects") or {}) do
        if get(te, "type") == "damage" then
          local dm = get(te, "damage")
          local amount = dm and get(dm, "amount")
          if type(amount) == "number" then total = (total or 0) + amount * (get(te, "repeat_count") or 1) end
        end
      end
    end
  end
  if total and type(out.cooldown) == "number" and out.cooldown > 0 then
    out.dps = total * 60 / out.cooldown * (get(ap, "damage_modifier") or 1)
  end
  return out
end

function General.dump()
  local d = { recipes = {}, techs = {}, entities = {}, resources = {}, items = {}, units = {} }
  for _, name in ipairs(keys_list(game.recipe_prototypes)) do
    local r = game.recipe_prototypes[name]
    local ing, prod = {}, {}
    for _, i in ipairs(r.ingredients) do ing[#ing + 1] = { type = i.type, name = i.name, amount = i.amount } end
    for _, p in ipairs(r.products) do prod[#prod + 1] = { type = p.type, name = p.name, amount = amount_of(p) } end
    d.recipes[name] = { category = r.category, energy = r.energy, hidden = r.hidden, enabled = r.enabled,
      ingredients = ing, products = prod }
  end
  for _, name in ipairs(keys_list(game.technology_prototypes)) do
    local t = game.technology_prototypes[name]
    if not t.research_unit_count_formula then
      local ing = {}
      for _, i in ipairs(t.research_unit_ingredients) do ing[#ing + 1] = { i.name, i.amount } end
      local unlocks, effects = {}, {}
      for _, e in ipairs(t.effects or {}) do
        if e.type == "unlock-recipe" then unlocks[#unlocks + 1] = e.recipe else effects[#effects + 1] = e.type end
      end
      table.sort(unlocks)
      table.sort(effects)
      d.techs[name] = { count = t.research_unit_count, time = t.research_unit_energy / 60, ingredients = ing,
        prerequisites = keys_list(t.prerequisites), unlocks = unlocks, effects = effects, enabled = t.enabled,
        hidden = t.hidden }
    end
  end
  for _, ty in ipairs(R.ENTITY_TYPES) do
    local role = R.ENTITY_ROLE[ty]
    local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = ty } })
    for _, name in ipairs(keys_list(protos)) do
      local e = protos[name]
      local items = get(e, "items_to_place_this")
      local en = { name = name, type = ty, item = items and items[1] and items[1].name or nil, energy = "none" }
      if get(e, "electric_energy_source_prototype") then en.energy = "electric"
      elseif get(e, "burner_prototype") then en.energy = "burner" end
      if role == "main" or role == "fabrique" then en.crafting_categories = keys_list(get(e, "crafting_categories")) end
      if role == "main" or role == "foreuse" then en.resource_categories = keys_list(get(e, "resource_categories")) end
      if role == "fabrique" then en.speed = get(e, "crafting_speed") end
      if role == "foreuse" then en.speed = get(e, "mining_speed") end
      if role == "labo" then
        en.lab_inputs = get(e, "lab_inputs")
        en.speed = get(e, "researching_speed")
      end
      if role == "pompe" then
        local fl = get(e, "fluid")
        en.fluid = fl and fl.name or nil
      end
      if role == "chauffe" or role == "generateur" then
        for _, fb in ipairs(get(e, "fluidbox_prototypes") or {}) do
          local filt = get(fb, "filter")
          local pt = get(fb, "production_type")
          if filt and (pt == "input" or pt == "input-output") then en.fluid_in = en.fluid_in or filt.name end
          if filt and pt == "output" then en.fluid_out = en.fluid_out or filt.name end
        end
      end
      lecture_fields(en, e, ty, role)
      d.entities[#d.entities + 1] = en
    end
  end
  -- Lot RB-3 : les unités qu'un objet pose (le kit d'un robot) : caractéristiques lues aux prototypes, sans un nom.
  for _, ty in ipairs(R.UNIT_TYPE_LIST) do
    local protos = game.get_filtered_entity_prototypes({ { filter = "type", type = ty } })
    for _, name in ipairs(keys_list(protos)) do
      local e = protos[name]
      local items = get(e, "items_to_place_this")
      if items and items[1] then
        local u = { name = name, type = ty, item = items[1].name, hp = get(e, "max_health"), speed = get(e, "speed") }
        local cb = get(e, "collision_box")
        u.half = cb and math.max(math.abs(cb.left_top.x), math.abs(cb.right_bottom.x)) or 0.4
        local ap = get(e, "attack_parameters")
        if not ap then
          -- une araignée tire par ses armes : la plus longue portée des armes, les dégâts ne sont pas lus
          for _, gname in ipairs(keys_list(get(e, "guns"))) do
            local gap = get(get(e, "guns")[gname], "attack_parameters")
            local a = read_attack(gap)
            if a.range and (u.range or 0) < a.range then u.range, u.min_range, u.cooldown = a.range, a.min_range, a.cooldown end
            if a.zone then u.zone = true end
          end
        else
          local a = read_attack(ap)
          u.range, u.min_range, u.cooldown, u.zone, u.dps = a.range, a.min_range, a.cooldown, a.zone, a.dps
        end
        d.units[#d.units + 1] = u
      end
    end
  end
  local rprotos = game.get_filtered_entity_prototypes({ { filter = "type", type = "resource" } })
  for _, name in ipairs(keys_list(rprotos)) do
    local e = rprotos[name]
    local mp = get(e, "mineable_properties")
    local prods = {}
    for _, p in ipairs((mp and mp.products) or {}) do prods[#prods + 1] = { type = p.type, name = p.name, amount = amount_of(p) } end
    d.resources[#d.resources + 1] = { entity = name, category = get(e, "resource_category"), products = prods }
  end
  for _, name in ipairs(keys_list(game.item_prototypes)) do
    local it = game.item_prototypes[name]
    d.items[name] = { type = it.type, fuel_value = it.fuel_value or 0 }
  end
  return d
end

--- Exécutants d'aujourd'hui : la main et le laboratoire du QG (rôles), les fours du QG et les foreuses des avant-postes
--- (tables de l'exécutant). Un lot qui ajoute un exécutant (IA3-e : modules du plan directeur) l'ajoute ici.
--- Lot AUTO : automatisation allumée (réglage fo-war-ia3e, Auto.on), les entités que ses gabarits posent (assembleurs,
--- foreuses électriques, centrale à vapeur : Auto.exec_entities, déduites des gabarits) sont aussi des exécutants :
--- l'électricité devient payable (H8). Correction après revue (H8) : une machine de fabrication de l'automatisation
--- ne fait que les recettes que son exécutant sait LANCER (Auto.add_executors : gabarits écrits et rangées générées,
--- ni fluide ni plus de 2 ingrédients hors d'un gabarit écrit), pas toutes celles de ses catégories. `recipes` : le
--- relevé des recettes (General.dump().recipes), requis quand auto_on.
function General.exec_opts(auto_on, recipes, petrole_dump)
  local exec = { [T.SMELTER] = true, [T.DRILL] = true }
  if auto_on then Auto.add_executors(exec, recipes) end
  -- Lot PETROLE (réglage fo-war-petrole allumé) : extracteurs des ressources fluides, machines des recettes que la main ne
  -- sait pas faire (catégorie, boîtes à fluide lues dans les prototypes), entités de la centrale.
  if petrole_dump then Pet.add_executors(exec, petrole_dump) end
  return { exec = exec, exec_roles = { main = true, labo = true }, labs_unpowered = true,
    -- Combustible : un objet qu'un avant-poste rapporte (moteur réel, banc g2 : sans cela, le cristal de résonance).
    fuel_ok = function(item) return General.kind_of(item) ~= nil end }
end

-- Lot AUTO : un catalogue par état du réglage de l'automatisation (réglage de carte : le même chez tous les pairs) ;
-- changer de catalogue efface les mémos de points fixes (ils appartiennent au graphe de l'autre catalogue).
local cats = {}
local pet_infos = {} -- lot PETROLE (relecture 0.6.20) : relevé des chaînes à fluides de chaque catalogue « p » (Pet.get_info)
function General.catalogue()
  local on = Auto.on() and true or false
  -- lot PETROLE : un catalogue par état des deux réglages (clé « a » / « - », puis « p » si fo-war-petrole est allumé)
  local pon = Pet.on()
  local ck = (on and "a" or "-") .. (pon and "p" or "")
  if cat and cats[ck] == cat then return cat end
  for k in pairs(memos) do memos[k] = nil end
  if cats[ck] then
    cat = cats[ck]
    if pon then Pet.set_info(pet_infos[ck]) end -- le relevé de CE catalogue, pas celui du dernier construit
    return cat
  end
  Profiler.start("iag:catalogue")
  local d = General.dump()
  cat = K.build(d, General.exec_opts(on, d.recipes, pon and d or nil))
  cats[ck] = cat
  if pon then pet_infos[ck] = Pet.get_info() end
  Profiler.stop("iag:catalogue")
  -- Lot INDUSTRIE I4 : ce que les machines du jeu permettent de fabriquer, et le kit de logistique (une ligne par lecture).
  log("[FO-IND-LECTURE] " .. L.line(cat.lecture, #cat.fab_machines) .. " | " .. General.kit_text(cat.kit()))
  log(string.format("[FO-CERVEAU] catalogue lu dans les prototypes : %d recettes faisables, %d technologies, %d machines exécutables, %d packs, combustible %s%s%s",
    #cat.g.recipe_list, #cat.tech_list, #cat.g.machine_list, #cat.pack_list, tostring(cat.fuel),
    on and " (automatisation allumee : executants de ses gabarits compris)" or "",
    pon and " (petrole allume : extracteurs des fluides et machines des cellules compris)" or ""))
  return cat
end

--- Kit de logistique en une ligne de journal (les objets viennent du relevé).
function General.kit_text(kit)
  local out = {}
  for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do
    local c = kit[k]
    out[#out + 1] = k .. " " .. (c and c.item or "AUCUN")
  end
  return "kit " .. table.concat(out, ", ")
end

function General.on() return General.ENABLED == true end

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
local function kind_of(res)
  for _, k in ipairs(T.OUTPOST_ORDER) do if T.outposts[k].resource == res then return k end end
  return nil
end
General.kind_of = kind_of

--- État du graphe pour une faction : technologies faites (st.techs, tenues par la recherche du QG), coffre et arrivées,
--- machines posées, gisements connus.
function General.state(f, st, view, durable_only)
  local c = General.catalogue()
  local stock = {}
  for _, k in ipairs(sorted_keys(view.stock)) do
    if not durable_only or c.g.machine[k] or c.role[k] then stock[k] = view.stock[k] end
  end
  if not durable_only then
    for _, k in ipairs(sorted_keys(view.incoming)) do stock[k] = (stock[k] or 0) + view.incoming[k] end
  end
  local built = {}
  local nlabs = 0
  for _, e in ipairs(st.labs or {}) do
    if e.valid then
      local it = c.item_of[e.name]
      if it then built[it] = (built[it] or 0) + 1 end
      nlabs = nlabs + 1
    end
  end
  built[T.SMELTER] = (built[T.SMELTER] or 0) + (view.smelters or 0)
  local drills = 0
  for _, o in ipairs(view.outposts or {}) do drills = drills + (o.drills or 0) end
  if drills > 0 then built[T.DRILL] = (built[T.DRILL] or 0) + drills end
  local known = {}
  for _, k in ipairs(sorted_keys(st.known)) do if st.known[k] then known[k] = true end end
  for _, o in ipairs(view.outposts or {}) do known[T.outposts[o.kind].resource] = true end
  -- Lot PETROLE (réglage allumé) : ressources fluides dont un gisement est connu, eau d'une rive à portée du QG ; machines
  -- posées par ses sites (le graphe ne les fait plus « construire » une seconde fois).
  if Pet.on() then
    for _, k in ipairs(sorted_keys(Pet.known(f))) do known[k] = true end
    local pb = Pet.built(f)
    for _, k in ipairs(sorted_keys(pb)) do built[k] = (built[k] or 0) + pb[k] end
  end
  return { stock = stock, techs = st.techs or {}, built = built, known = known }, nlabs
end

local function memo_of(f)
  local m = memos[f.force]
  if not m then
    m = {}
    memos[f.force] = m
  end
  return m
end

--- Buts de RÉFÉRENCE d'une faction pour ses ressources clés : la recherche choisie, le premier lot de soldats (le soldat
--- de l'armée à son niveau), la réserve de munitions.
local function ref_goals(f, tech)
  local goals = {}
  if tech then goals[#goals + 1] = { tech = tech } end
  local unit = Planner.best_unit(f.tech or 0)
  for _, it in ipairs(T.kits[unit] or {}) do goals[#goals + 1] = { item = it[1], n = it[2] * General.ARMY_FIRST } end
  goals[#goals + 1] = { item = T.turret_ammo, n = General.AMMO_STOCK }
  return goals
end

---------------------------------------------------------------------------------------------------
-- Décision de recherche
---------------------------------------------------------------------------------------------------
local function iag_state(f)
  f.team.iag = f.team.iag or { decisions = 0, history = {}, explore = {} }
  return f.team.iag
end

--- Ressources clés de la faction (nil : repli de shared/ai3/reglages.lua).
function General.key(f)
  local g = f.team and f.team.iag
  return g and g.key or nil
end

General.EXPLORE_TOP = 2 -- ressources inconnues explorées en même temps (les plus rentables ; réglage fo-war-petrole allumé seulement)

--- Ressources à explorer demandées par le cerveau général.
function General.explore(f)
  local g = f.team and f.team.iag
  return g and g.explore or {}
end

--- Bras libres : packs des technologies suivantes à fabriquer d'avance ({ {pack, n} }, vide si les PNJ sont occupés).
--- Une ligne [FO-CERVEAU] quand la profondeur change.
--- Profondeur d'avance de la pensée (une fois par pensée : compteur de pensées de suite avec des bras libres, global).
local function spare(f, view, tick)
  local g = f.team and f.team.iag
  if not g then return 0 end
  if g.spare_tick ~= tick then
    g.spare_tick = tick
    -- Lot SCALE : PNJ sans tâche LISSÉS (moyenne glissante d'environ 1 min, shared/ai3/bras.lua, Br.smooth) au lieu du
    -- compte de la pensée : une pensée sous le seuil ne remet plus le compteur à zéro (moteur simulé, 30 PNJ : 7,8 à
    -- 9,5 PNJ sans tâche par pensée, aucune tâche libre, aucun travail d'avance).
    g.idle_ema = Br.smooth(g.idle_ema, view.workers_idle)
    local idle_s = math.floor(g.idle_ema / 10)
    if Gen.ahead_depth(idle_s, view.workers) > 0 then g.idle_run = (g.idle_run or 0) + 1 else g.idle_run = 0 end
    local war = State.war()
    local elapsed = tick - (f.started or (war and war.started) or 0)
    g.spare = Gen.spare_depth(g.idle_run, idle_s, view.workers, elapsed)
    -- Lot SCALE : nombre de bras libres durables (0 si la profondeur est nulle) : taille des vagues d'avance.
    g.spare_hands = g.spare > 0 and idle_s or 0
    -- Une exploration demandée (IA3-f, f.ai3f.req) prend d'abord les PNJ sans tâche comme éclaireurs : pas de travail
    -- d'avance tant qu'elle est ouverte (moteur simulé, tests/ia3f_test.lua §6 : avec les bras libres, le pétrole n'était
    -- plus trouvé en 30 min sous 30 % de chemins ratés, les éclaireurs étant occupés aux packs d'avance). Test de vacuité
    -- seulement (aucun ordre de parcours).
    if f.ai3f and f.ai3f.req and next(f.ai3f.req) ~= nil then g.spare, g.spare_hands = 0, 0 end
  end
  return g.spare or 0
end

function General.lookahead(f, st, view, tick)
  local g = f.team and f.team.iag
  local m = memos[f.force]
  if not (g and g.next and m and m.ev) then return {} end
  local depth = spare(f, view, tick)
  if depth > 0 then g.ahead_thinks = (g.ahead_thinks or 0) + 1 end
  if depth ~= (g.depth or 0) and tick - (g.depth_log or -3600) >= 3600 then
    g.depth = depth
    g.depth_log = tick
    log(string.format("[FO-CERVEAU] %s : bras libres %d/%d : %d recherche(s) suivante(s) preparee(s) d'avance [%s] a %.1f min",
      f.key or "?", view.workers_idle or 0, view.workers or 0, depth, table.concat(g.next, " "), minutes(f, tick)))
  end
  if depth <= 0 then return {} end
  local state = General.state(f, st, view)
  return Gen.lookahead(General.catalogue(), m.ev, state, g.next, depth)
end

--- Bras libres : la pensée pure agrandit d'avance l'extraction de la ressource la plus demandée (shared/ai3/buts.lua).
--- … seulement l'économie faite (« fer II » ou économie couverte : la garde B3 d'IA-V2), et des bras libres durables.
function General.idle_grow(f, view, tick)
  if f.is_player or not General.on() then return false end
  local st = f.team and f.team.ia3
  if not (st and (st.iron2_done or st.economy_ok)) then return false end
  return spare(f, view, tick) > 0
end

--- Lot SCALE : bras libres DURABLES de la pensée (nombre de PNJ sans tâche quand la profondeur d'avance est > 0, sinon
--- 0) ; factions seulement, cerveau général allumé.
function General.spare_hands(f, view, tick)
  if f.is_player or not General.on() then return 0 end
  spare(f, view, tick)
  local g = f.team and f.team.iag
  return (g and g.spare_hands) or 0
end

--- Lot RB-FLUIDE : où en est une technologie pour une faction, à la dernière évaluation de la force (journal [FO-ROBOTS], aucune décision n'en dépend) :
--- { done, ready (prérequis faits), missing (prérequis manquants), tfeas (payable d'après le graphe), packs = { { pack, fabricable } },
--- value (valeur propre, sans chaîne), rank (0 : recherche en cours ; n : n-ième des suivantes ; nil : hors classement), current (technologie en cours) }.
function General.tech_info(f, t)
  local st = f.team and f.team.ia3
  local c = General.catalogue()
  local spec = c and c.techs[t]
  if not (st and spec) then return nil end
  local techs = st.techs or {}
  local info = { done = techs[t] == true, missing = {}, packs = {} }
  for _, p in ipairs(spec.prerequisites) do if not techs[p] then info.missing[#info.missing + 1] = p end end
  info.ready = #info.missing == 0
  local m = memos[f.force]
  if m and m.ev then
    info.tfeas = m.ev.tfeas[t] == true
    for _, ing in ipairs(spec.ingredients) do info.packs[#info.packs + 1] = { ing[1], m.ev.feas[ing[1]] == true } end
    info.value = Gen.value(c, m.ev, { stock = {}, techs = techs, built = {}, known = {} }, t, {})
  end
  info.current = st.lab and st.lab.tech or nil
  if info.current == t then info.rank = 0 end
  for i, n in ipairs((f.team.iag and f.team.iag.next) or {}) do
    if n == t then info.rank = i end
  end
  return info
end

--- Faisabilité d'un objet à la dernière évaluation de la force (nil : inconnue).
function General.feasible(f, item)
  local m = memos[f.force]
  if not (m and m.ev) then return nil end
  return m.ev.feas[item] == true
end

--- Lot CAPITAL : coût unitaire d'un objet (point fixe min-plus du graphe) à la dernière évaluation de la force ; nil si
--- l'objet n'y est pas faisable ou si la force n'a pas encore été évaluée.
function General.unit_cost(f, item)
  local m = memos[f.force]
  if not (m and m.ev and m.ev.feas[item]) then return nil end
  return m.ev.cost[item]
end

--- Lot CAPITAL : dépliage d'une liste { {objet, n} } (coût d'une amélioration) sur la dernière évaluation de la force :
--- le même Gen.summary que la recherche (main, machine, extraire, construire). nil sans évaluation.
function General.summary_items(f, list)
  local m = memos[f.force]
  if not (m and m.ev) or not General.on() then return nil end
  local st = f.team and f.team.ia3
  if not st then return nil end
  local goals = {}
  for _, it in ipairs(list or {}) do goals[#goals + 1] = { item = it[1], n = it[2] } end
  local state = { stock = {}, techs = st.techs or {}, built = {}, known = {} }
  for _, k in ipairs(sorted_keys(st.known)) do if st.known[k] then state.known[k] = true end end
  if Pet.on() then for _, k in ipairs(sorted_keys(Pet.known(f))) do state.known[k] = true end end -- lot PETROLE
  return Gen.summary(General.catalogue(), m.ev, state, goals)
end

--- Une ressource inconnue que l'équipe saurait extraire (un exécutant de sa catégorie) ?
local function explorable(c, res)
  local r = c.resources[res]
  if not r then return false end
  return c.g.by_rescat[r.category] ~= nil
end

--- Lot JOURNAUX-DC (point 3 du rapport CINQ-POINTS : Écarlate bloquée de la minute 289 à 312 sur « impayable:?engine-unit,
--- ?plastic-bar,?sulfur », sans ligne qui dise que la faction plafonne) : AUCUNE technologie payable, même de valeur nulle
--- (Gen.fallback) : ligne [FO-MUR] à l'entrée dans le mur, quand les recherches prêtes impayables ou le nombre restant
--- changent, et à la sortie (g.mur, nombres et chaînes).
--- Matière qui manque : union des causes du dépliage des technologies prêtes impayables (au plus General.MUR_MAX, les plus
--- valables d'abord). Lecture seule : rien n'est décidé ici. Annoncé après un blocage CONTINU de Jdc.MUR_DELAI seulement
--- (shared/team/journaux_dc.lua) : un blocage passager (banc journaux-dc : votre équipe « au mur » à la minute 0 faute de
--- gisement de fer encore connu) n'est pas un mur.
General.MUR_MAX = 8
function General.mur(f, g, c, ev, state, d, disabled, tick)
  local techs = {}
  for i = 1, math.min(General.MUR_MAX, #(d.blocked or {})) do techs[#techs + 1] = d.blocked[i].tech end
  local left = 0
  for _, t in ipairs(c.tech_list) do
    if not state.techs[t] and not disabled[t] then left = left + 1 end
  end
  -- Signature bon marché (technologies prêtes impayables, nombre restant) : le dépliage ne se refait qu'à une annonce.
  local action
  g.mur, action = Jdc.mur_bloque(g.mur, tick, table.concat(techs, " ") .. "|" .. left)
  if not action then return end
  local miss = {}
  for _, t in ipairs(techs) do
    for _, k in ipairs(Gen.summary(c, ev, state, { { tech = t } }).causes or {}) do miss[k] = true end
  end
  local what = left == 0 and "arbre de recherche termine (ou tout desactive)"
    or "toutes les recherches restantes sont impayables"
  log(string.format("[FO-MUR] %s : %s a %.1f min : %s (%d restantes, %d pretes de valeur) ; matiere qui manque [%s] ; "
    .. "pretes de valeur [%s] ; bloquee depuis %.1f min", f.key or "?", action == "annonce" and "mur atteint" or "mur, situation changee",
    minutes(f, tick), what, left, #(d.blocked or {}), table.concat(sorted_keys(miss), " "), table.concat(techs, " "),
    (tick - g.mur.since) / 3600))
end

--- Choix de la technologie (même contrat que choose_tech de script/ai3/cerveau.lua) : tech, payable, causes, palier.
function General.choose_tech(f, force, st, book, w, tick, view, wanted)
  local c = General.catalogue()
  local g = iag_state(f)
  Profiler.start("iag:choose")
  Profiler.fstart("iag:state") -- lot PERF3 : portées fines (mesure seulement)
  local state, nlabs = General.state(f, st, view)
  Profiler.fstop("iag:state")
  Profiler.fstart("iag:prepare")
  local ev = Gen.prepare(c, state, memo_of(f))
  Profiler.fstop("iag:prepare")
  local lab = st.lab
  -- Lot AUTO (garde de K1 du lot IA3-e, reportée du choix de repli) : une recherche voulue par l'automatisation
  -- (for_auto) sans unité payée depuis General.AUTO_STALL laisse passer les autres General.AUTO_PAUSE (objets voulus
  -- ignorés pendant ce temps).
  if wanted and lab and lab.for_auto and lab.tech and not st.techs[lab.tech]
      and tick - (lab.paid_tick or lab.started or tick) > General.AUTO_STALL then
    st.auto_pause = tick + General.AUTO_PAUSE
    log(string.format("[FO-CERVEAU] %s : recherche '%s' (automatisation) sans progres depuis %d min : les autres recherches passent %d min",
      f.key or "?", lab.tech, math.floor(General.AUTO_STALL / 3600), math.floor(General.AUTO_PAUSE / 3600)))
    lab.for_auto = nil
    lab.stalled = true
  end
  -- Lot RB-FLUIDE : la garde du joueur vaut pour toute équipe (règle pure shared/ai3/impayable.lua) ; les packs qui manquaient sont retenus pour le retour.
  st.grace = st.grace or {}
  Im.expire_grace(st, tick)
  -- Relecture d'intégration 0.6.35 : la recherche qui OUVRE la tourelle n'est jamais lâchée tant que la recette est fermée (palier de défense, S1 : ses packs
  -- passent avant tout) ; lâchée au fer à 0, elle laissait la place à une autre recherche qui la gardait jusqu'à sa fin, tourelle repoussée de dizaines de minutes.
  local defense_tech = c.g.unlocked_by[T.turret]
  local turret_rec = force.recipes[T.turret]
  local keep_defense = defense_tech ~= nil and lab ~= nil and lab.tech == defense_tech and turret_rec ~= nil and not turret_rec.enabled
  if not keep_defense and Im.should_stall(lab, tick, lab and lab.tech and st.techs[lab.tech], lab and lab.tech and st.grace[lab.tech]) then
    local spec = c.techs[lab.tech]
    local stock = view.stock or {}
    Im.stall(st, lab.tech, tick, Im.missing(spec and spec.ingredients, stock))
    lab.stalled = true
    log(string.format("[FO-CERVEAU] %s : recherche '%s' sans progres depuis %d min (packs qui manquent : %s) : les autres passent %d min au plus, retour des que les packs sont au coffre",
      f.key or "?", lab.tech, math.floor(Im.STALL / 3600), table.concat(st.stall_packs[lab.tech], ",") ~= "" and table.concat(st.stall_packs[lab.tech], ",") or "aucun",
      math.floor(Im.PAUSE / 3600)))
  end
  local k1 = wanted ~= nil and Auto.on()
  if st.auto_pause and tick < st.auto_pause then wanted = nil end
  if lab and lab.tech and not st.techs[lab.tech] and not lab.stalled then
    -- FIX-P3 : tourelle fermée et recherche en cours autre que la sienne : Gen.choose décide (defense_first).
    if ev.tfeas[lab.tech] and Gen.keep_current(lab.tech, defense_tech, turret_rec ~= nil and not turret_rec.enabled) then
      Profiler.stop("iag:choose")
      return lab.tech, true, {}, lab.palier, lab.for_auto
    end
    log(string.format("[FO-CERVEAU] %s : but '%s' abandonne (plus payable) a %.1f min", f.key or "?", lab.tech, minutes(f, tick)))
  end
  Profiler.fstart("iag:disabled")
  local disabled = {}
  for _, t in ipairs(c.tech_list) do
    local ft = force.technologies[t]
    if not ft or not ft.enabled then disabled[t] = true end
  end
  Profiler.fstop("iag:disabled")
  local stalled_now = Im.active(st, tick,
    function(t) return c.techs[t] and c.techs[t].ingredients or {} end,
    function(t) return c.techs[t] and c.techs[t].count or 0 end, view.stock or {})
  for _, t in ipairs(sorted_keys(stalled_now)) do disabled[t] = true end
  local speed = 1
  for _, l in ipairs(c.labs) do speed = math.max(speed, l.speed or 1) end
  -- Lot LEVIERS : recherches à effet choisies par la capitalisation (script/ai3/capitalisation.lua), lues à l'appel.
  local Capi = package.loaded["script.ai3.capitalisation"]
  local levers = Capi and Capi.techs_wanted and Capi.techs_wanted(f) or nil
  local function choose()
    return Gen.choose(c, ev, state, { weights = w, wanted = wanted, disabled = disabled, lab_speed = speed * math.max(1, nlabs),
      k1 = k1 or nil, levers = levers, new_pack = Pet.on() or nil, -- lot PETROLE (réglage fo-war-petrole)
      -- Lot DEFENSE-FACTIONS D2 : la technologie de la tourelle est un palier ; la recette est celle que les planificateurs commandent
      -- (T.turret), la règle pure ne la nomme pas. Lot EQUIPE (1/11) : aussi pour votre équipe (recherche de la tourelle à 10,9 min,
      -- QG attaqué dès 8,6 min : fo-logs/2026-11-01_EQUIPE/RAPPORT.md).
      defense = T.turret })
  end
  Profiler.fstart("iag:gen-choose")
  local d = choose()
  Profiler.fstop("iag:gen-choose")
  -- Lot RB-FLUIDE : rien d'autre de payable : la recherche lâchée depuis le plus longtemps revient (le laboratoire ne reste pas oisif), sans reprise de la garde avant la fin de la pause
  if not d.tech then
    local back = Im.lift(st, tick)
    if back then
      disabled[back] = nil
      if lab and lab.tech == back then lab.stalled = nil end -- la garde se réarme (après sa `grace`)
      log(string.format("[FO-CERVEAU] %s : rien d'autre de payable : la recherche '%s' revient (pas de nouvel arret avant %d min)", f.key or "?", back,
        math.floor(Im.PAUSE / 3600)))
      d = choose()
    end
  end
  -- Ce que rapporterait chaque ressource inconnue qu'un exécutant sait extraire (« quelles ressources peuvent rapporter ») :
  -- la meilleure, si elle rapporte, est à explorer (A6 : explorer pour une raison).
  Profiler.fstart("iag:rv")
  -- Lot PERF4 : dépliages par ressource inconnue mémorisés par clé d'état (table locale du mémo de la force, vidée avec lui quand le
  -- catalogue change) ; même résultat (Gen.resource_values).
  local mf = memo_of(f)
  mf.rv = mf.rv or {}
  local rv = Gen.resource_values(c, ev, state, { weights = w, wanted = wanted }, mf.rv)
  Profiler.fstop("iag:rv")
  local rv_txt = {}
  for i = 1, math.min(4, #rv) do rv_txt[#rv_txt + 1] = rv[i][1] .. " " .. rv[i][2] end
  if not d.tech then
    -- Rien de payable : les ressources inconnues qui bloquent la meilleure technologie de valeur sont à explorer.
    local causes, explore = {}, {}
    if rv[1] and rv[1][2] > 0 then explore[rv[1][1]] = 60 end
    if d.blocked[1] then
      local sum = Gen.summary(c, ev, state, { { tech = d.blocked[1].tech } })
      for _, res in ipairs(sum.explore) do if explorable(c, res) then explore[res] = 60 end end
      causes = sum.causes
    end
    g.explore = explore
    local sig = table.concat(causes, ",") .. "|" .. table.concat(sorted_keys(explore), ",")
    if g.blocked_sig ~= sig then
      g.blocked_sig = sig
      log(string.format("[FO-CERVEAU] %s : aucune technologie payable (%s) ; causes [%s] ; ressources inconnues qui rapporteraient [%s] ; exploration [%s] a %.1f min",
        f.key or "?", Gen.why_text(d), table.concat(causes, " "), table.concat(rv_txt, ", "),
        table.concat(sorted_keys(explore), " "), minutes(f, tick)))
    end
    General.mur(f, g, c, ev, state, d, disabled, tick)
    Profiler.stop("iag:choose")
    return nil, false, causes, false
  end
  if Jdc.mur_libre(g.mur) then
    log(string.format("[FO-MUR] %s : fin du mur a %.1f min (bloque depuis %.1f min) : recherche '%s'%s", f.key or "?",
      minutes(f, tick), (tick - g.mur.since) / 3600, d.tech, d.repli and " (repli : valeur nulle, payable)" or ""))
  end
  g.mur = nil
  -- Les General.EXPLORE_TOP ressources inconnues les plus rentables sont explorées ENSEMBLE (lot PETROLE 2 : seule la
  -- première l'était ; moteur réel, etape1-guide 123456789 : le tungstène, 250, passait devant le pétrole, 40, qui ne fut
  -- jamais cherché et le pack chimique restait impayable).
  -- Relecture de la reprise sur 0.6.20 (30/10) : SEULEMENT réglage fo-war-petrole allumé ; éteint, une seule ressource comme sur
  -- main (sans cette garde, le lot changeait l'exploration de toutes les parties, réglage éteint compris).
  g.explore = Gen.explore_set(rv, 40, Pet.on() and General.EXPLORE_TOP or 1)
  -- (Intégration 0.6.23 : ensemble d'exploration de PETROLE 2 ci-dessus, puis les priorités du repli de JOURNAUX-DC.)
  -- Relecture JOURNAUX-DC : le repli (technologie de valeur nulle, Gen.fallback) ne vaut que faute de candidate de valeur
  -- payable ; l'exploration des ressources inconnues qui bloquent la meilleure technologie de valeur reste donc celle de la
  -- branche « rien de payable » ci-dessus (priorité 60), sinon le repli ferait chercher moins ce qui débloquerait l'équipe.
  if d.repli then
    if rv[1] and rv[1][2] > 0 then g.explore[rv[1][1]] = 60 end
    if d.blocked and d.blocked[1] then
      for _, res in ipairs(Gen.summary(c, ev, state, { { tech = d.blocked[1].tech } }).explore) do
        if explorable(c, res) then g.explore[res] = 60 end
      end
    end
  end
  g.blocked_sig = nil
  local sum = Gen.summary(c, ev, state, { { tech = d.tech } })
  -- Lot IA3-e (points de jonction « hand », « produce », « extract », INTEGRATION.md §3) : objets que le dépliage fait
  -- fabriquer, produire ou extraire pour le but ; la règle « main ou machine » les pèse (script/ai3/automatisation.lua,
  -- input.items de A.decide) même sans charge mesurée. Chaînes seulement.
  local steps = {}
  for _, kind in ipairs({ "hand", "produce", "extract" }) do
    for _, k in ipairs(sorted_keys(sum[kind] or {})) do steps[#steps + 1] = k end
  end
  g.steps = steps
  -- Ressources clés : besoin BRUT des buts de référence (sans le stock consommable).
  local ds = General.state(f, st, view, true)
  local evd = Gen.prepare(c, ds, memo_of(f)) -- même clé (les points fixes ne lisent que le stock durable) : mémo
  local sumd = Gen.summary(c, evd, ds, ref_goals(f, d.tech))
  local key = Gen.key_resources(c, sumd, T.OUTPOST_ORDER, kind_of)
  -- Gardées seulement complètes (une ressource la plus demandée ET un combustible qu'un avant-poste rapporte) ; sinon
  -- le repli de shared/ai3/reglages.lua reste.
  if key.top and key.fuel then g.key = { top = key.top, fuel = key.fuel, order = key.order, optional = key.optional } end
  -- Technologies SUIVANTES (le classement de la décision) : packs fabriqués d'avance quand des bras sont libres.
  g.next = {}
  for i = 2, #(d.ranked or {}) do g.next[#g.next + 1] = d.ranked[i][1] end
  g.decisions = g.decisions + 1
  g.history[#g.history + 1] = { tech = d.tech, tick = tick, value = d.value, cost = d.cost }
  while #g.history > 32 do table.remove(g.history, 1) end
  log(string.format("[FO-CERVEAU] %s : but '%s' valeur %d cout %d score %d%s%s | %s | ressources cles : plus demandee %s, combustible %s, ordre %s, sans besoin [%s], besoins bruts %s | inconnues qui rapporteraient [%s] | %d pretes payables a %.1f min",
    f.key or "?", d.tech, d.value, d.cost, d.score, d.palier and " (palier)" or "",
    d.k1 and (" (K1 : " .. d.k1 .. ")") or ((d.auto and not d.k1_palier) and " (voulue par l'automatisation)" or ""),
    Gen.why_text(d, sum), tostring(key.top),
    tostring(key.fuel), table.concat(key.order, ","), table.concat(sorted_keys(key.optional), ","), Gen.fmt_map(key.need),
    table.concat(rv_txt, ", "), d.n_ready or 0, minutes(f, tick)))
  Profiler.stop("iag:choose")
  -- lot AUTO : for_auto (5e valeur, comme le choix de repli) : la recherche sert l'automatisation sans ouvrir de palier
  -- (garde AUTO_STALL ci-dessus ; plancher et plafond de shared/ai3/projets.lua, buts.lua, automatiser.lua A.goals)
  return d.tech, true, {}, d.palier, (k1 and d.auto and not d.k1_palier) or nil
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  local war = State.war()
  for _, id in ipairs(sorted_keys(war and war.factions)) do
    local f = war.factions[id]
    if f.key == key then return f end
  end
  return nil
end

remote.add_interface("fo-iag", {
  status = function(key)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    local g = f.team.iag or {}
    local out = { decisions = g.decisions or 0, history = {}, key = g.key, explore = sorted_keys(g.explore) }
    for i, h in ipairs(g.history or {}) do out.history[i] = { tech = h.tech, tick = h.tick, value = h.value, cost = h.cost } end
    return out
  end,
  -- Lot INDUSTRIE I4 : la lecture générique (cat.fab) en chaînes et nombres, pour le banc `ind-lecture` et la copie jetable.
  -- `recette` (facultatif) : l'entrée de cette recette seulement (machines, refus).
  lecture = function(recette)
    local c = General.catalogue()
    local kit = c.kit()
    local out = { summary = c.lecture, line = L.line(c.lecture, #c.fab_machines), kit = General.kit_text(kit),
      kit_items = {}, machines = {}, fab = {} }
    for _, k in ipairs({ "bras", "bras_long", "tapis", "coffre", "poteau" }) do out.kit_items[k] = kit[k] and kit[k].item or nil end
    for _, m in ipairs(c.fab_machines) do out.machines[#out.machines + 1] = m.entity end
    local names = recette and { recette } or sorted_keys(c.fab)
    for _, n in ipairs(names) do
      local e = c.fab[n]
      if e then
        local ms = {}
        for _, m in ipairs(e.machines) do ms[#ms + 1] = m.entity end
        out.fab[n] = { category = e.category, s = e.s, fluides_in = #e.fluides_in, fluides_out = #e.fluides_out,
          produits = #e.produits, main = e.main, patronnable = e.patronnable, machines = ms,
          refus = e.refus and e.refus.code or nil, texte = e.refus and e.refus.texte or nil }
      end
    end
    return out
  end,
  catalogue = function()
    local c = General.catalogue()
    return { recipes = #c.g.recipe_list, techs = #c.tech_list, machines = #c.g.machine_list, packs = #c.pack_list,
      fuel = c.fuel }
  end,
})

return General
