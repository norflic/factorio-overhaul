--[[
  CERVEAU D'ÉQUIPE — PUR (aucune API Factorio). Un seul par équipe : il sait ce qu'il reste à faire et
  comment le faire ; les ouvriers exécutent ses tâches.

  P.plan(view, book) renvoie :
    goal     = clé de l'objectif poursuivi (premier palier non atteint de T.ladder), nil si échelle gravie
    reached  = { clé, ... } paliers atteints à cette pensée (mémorisés par l'appelant : jamais réouverts)
    missing  = { {objet, n}, ... } ce qui manque pour l'objectif (affichage « il manque »)
    tasks    = { tâche, ... } triées par priorité décroissante ; une tâche = { key, kind, prio, ... }
    site_needs = { [type d'avant-poste] = n } sites à prospecter
    research = niveau dont les packs sont au stock (le runtime les consomme), ou nil
    smelt    = { [produit] = n } production demandée à la fonderie du QG

  view = {
    tech, personality, done = { [clé] = true },
    stock = { [objet] = n }, incoming = { [objet] = n },     -- QG ; fabrications en cours
    outposts = { { id, kind, drills, turrets, fuel_low, output, idle_ticks, has_task }, ... },
    pending = { [type] = n }, sites = { [type] = n },
    smelters = n, smelters_pending = n, smelter_task = bool, smelter_output = n, smelter_fuel_low = bool,
    turret_groups = { { key, low, has_task }, ... },
    soldiers, soldiers_max, workers, workers_max, threatened,
    open = { [clé de tâche] = true },                       -- tâches en cours (affectées)
  }

  Priorités : 95 ravitaillement urgent > 90 munitions des tourelles > 80 objectif (pose) > 70 entretien >
  60 fonderie > 55 ouvriers > 50 objectif (fabrication) > 45 armée > 40 recherche > 30 minage d'appoint.
]]

local T = require("shared.team.config")

local P = {}

local MAX_CRAFT_TASKS = 8
local CHUNK_SECONDS = 30
local MINE_BATCH = 50
local MINE_MIN = 20 -- une sortie de minage rapporte au moins 20 minerais (9 plaques manquantes : 9 minerais, trop peu)

local function sorted_uses(uses)
  local ks = {}
  for k in pairs(uses) do ks[#ks + 1] = k end
  table.sort(ks)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = { k, uses[k] } end
  return out
end

-- Matières premières : d'où elles viennent quand le livre ne sait pas les fabriquer à la main.
local SOURCE = {
  ["coal"] = { outpost = "coal", mine = "coal" },
  ["stone"] = { outpost = "stone", mine = "stone" },
  ["iron-ore"] = { mine = "iron-ore" },
  ["copper-ore"] = { mine = "copper-ore" },
  ["iron-plate"] = { outpost = "iron", smelt = "iron-plate", mine = "iron-ore" },
  ["copper-plate"] = { outpost = "copper", smelt = "copper-plate", mine = "copper-ore" },
  ["steel-plate"] = { smelt = "steel-plate" },
  ["stone-brick"] = { smelt = "stone-brick" },
}

local function count_kind(view, kind)
  local n = 0
  for _, o in ipairs(view.outposts) do if o.kind == kind then n = n + 1 end end
  return n
end

--- Capacité d'extraction d'un type, en « avant-postes équivalents » (foreuses / foreuses par avant-poste).
local function capacity(view, kind)
  local drills = 0
  for _, o in ipairs(view.outposts) do if o.kind == kind then drills = drills + o.drills end end
  return drills / T.outposts[kind].drills
end

--- Avant-poste de ce type qui peut encore s'agrandir (le plus ancien d'abord), ou nil.
local function extendable(view, kind)
  for _, o in ipairs(view.outposts) do
    if o.kind == kind and not o.full and o.drills < T.max_drills(kind) then return o end
  end
  return nil
end

local function outpost_items(kind)
  local spec = T.outposts[kind]
  -- Un avant-poste de charbon démarre avec 2 charbons par foreuse puis se ravitaille sur sa production.
  local fuel = kind == "coal" and 2 * spec.drills or T.fuel_per_burner * spec.drills * (spec.sink == "stone-furnace" and 2 or 1)
  return { { T.DRILL, spec.drills }, { spec.sink, spec.drills }, { T.fuel, fuel } }
end

function P.outpost_items(kind) return outpost_items(kind) end

--- Avant-poste minimal (reconstruction) : 2 paires et leur combustible.
local function minimal_items(kind)
  local spec = T.outposts[kind]
  local n = math.min(2, spec.drills)
  local fuel = kind == "coal" and 2 * n or T.fuel_per_burner * n * (spec.sink == "stone-furnace" and 2 or 1)
  return { { T.DRILL, n }, { spec.sink, n }, { T.fuel, fuel } }
end

--- Le palier `goal` est-il atteint ? Renvoie atteint, liste des besoins (avant-postes, objets...).
local function goal_status(goal, view)
  local need = goal.need
  local reached = true
  local parts = {}
  if need.outposts then
    for _, kind in ipairs(T.OUTPOST_ORDER) do
      local want = need.outposts[kind]
      if want then
        -- Atteint à 75 % de la capacité visée (un gisement étroit n'accueille pas toujours toutes les paires).
        local have = capacity(view, kind)
        local pend = view.pending[kind] or 0
        if have < want * 0.75 then
          reached = false
          if have + pend < want * 0.75 then parts[#parts + 1] = { outpost = kind, n = math.max(1, math.ceil(want - have - pend)) } end
        end
      end
    end
  end
  if need.smelters and view.smelters < need.smelters then
    reached = false
    if view.smelters + view.smelters_pending < need.smelters then
      parts[#parts + 1] = { smelters = need.smelters - view.smelters - view.smelters_pending }
    end
  end
  if need.tech and view.tech < need.tech then
    reached = false
    parts[#parts + 1] = { tech = view.tech + 1 }
  end
  if need.soldiers and view.soldiers < need.soldiers then
    reached = false
    parts[#parts + 1] = { soldiers = need.soldiers - view.soldiers }
  end
  if need.stock then
    for item, n in pairs(need.stock) do
      if (view.stock[item] or 0) < n then
        reached = false
        parts[#parts + 1] = { item = item, n = n - (view.stock[item] or 0) }
      end
    end
  end
  if need.outpost_turrets then
    -- Atteint quand 75 % des avant-postes sont défendus (moteur réel, E16 it. 10 : « tous » n'était
    -- jamais atteint, des tourelles tombant sous les attaques pendant qu'on fortifiait les autres).
    local ok_n, todo = 0, {}
    for _, o in ipairs(view.outposts) do
      if o.turrets >= need.outpost_turrets then
        ok_n = ok_n + 1
      elseif not o.has_fortify then
        todo[#todo + 1] = { fortify = o.id, n = need.outpost_turrets - o.turrets }
      end
    end
    if ok_n < math.ceil(0.75 * #view.outposts) then
      reached = false
      for _, part in ipairs(todo) do parts[#parts + 1] = part end
    end
  end
  return reached, parts
end

function P.best_unit(tech)
  local best = "rifleman"
  if tech >= 1 then best = "gunner" end
  if tech >= 2 then best = "rocketeer" end
  return best
end

function P.army_target(view)
  local share = T.army_share[view.personality] or 0.6
  return math.floor(view.soldiers_max * share)
end

local function kit_list(kit, n)
  local out = {}
  for _, it in ipairs(T.kits[kit]) do out[#out + 1] = { it[1], it[2] * n } end
  return out
end

function P.plan(view, book)
  local out = { tasks = {}, missing = {}, reached = {}, site_needs = {}, smelt = {} }
  local tasks = out.tasks
  local open = view.open or {}
  local function add(t)
    if not open[t.key] then tasks[#tasks + 1] = t end
  end

  -- Stock virtuel : stock du QG + fabrications en cours. Chaque besoin servi y puise, du plus urgent au
  -- moins urgent : deux tâches ne comptent jamais sur les mêmes plaques.
  local avail = {}
  for k, v in pairs(view.stock) do avail[k] = v end
  for k, v in pairs(view.incoming or {}) do avail[k] = (avail[k] or 0) + v end
  local function take(list)
    for _, it in ipairs(list) do
      if (avail[it[1]] or 0) < it[2] then return false end
    end
    for _, it in ipairs(list) do avail[it[1]] = avail[it[1]] - it[2] end
    return true
  end

  local raw_short = {}   -- matières premières manquantes (toutes demandes confondues)
  local last_raw = {}    -- matières manquantes de la dernière demande (affichage « il manque »)
  local crafts = 0
  --- Fait fabriquer `list` (fabrication à la main depuis le stock virtuel). Renvoie true si tout est servi.
  --- fresh = besoin d'ACCUMULATION (stock visé, packs de recherche) : la quantité demandée est à fabriquer
  --- en plus du stock, elle n'y est pas prélevée.
  local function want(list, prio, tag, fresh)
    local missing_here = false
    last_raw = {}
    local function short_raw(item, n)
      raw_short[item] = (raw_short[item] or 0) + n
      last_raw[item] = (last_raw[item] or 0) + n
    end
    for _, it in ipairs(list) do
      local item, n = it[1], it[2]
      local have = fresh and 0 or (avail[item] or 0)
      if have >= n then
        avail[item] = have - n
      else
        local short = n - have
        if not fresh then avail[item] = 0 end
        if book:handcraftable(item) then
          -- Besoin d'accumulation : l'objet lui-même ne doit pas être « pris » au stock par le plan.
          local saved = avail[item]
          if fresh then avail[item] = 0 end
          local p = book:plan({ { item, short } }, avail)
          if next(p.raw) == nil then
            -- Les grosses commandes sont partagées entre plusieurs ouvriers (lots de ~CHUNK_SECONDS de
            -- fabrication) : toute l'équipe fabrique en parallèle.
            local energy = 0
            for _, c in ipairs(p.crafts) do energy = energy + c.energy end
            local chunks = math.max(1, math.min(short, math.ceil(energy / CHUNK_SECONDS), MAX_CRAFT_TASKS - crafts))
            local per = math.ceil(short / chunks)
            local left = short
            local i = 0
            while left > 0 and crafts < MAX_CRAFT_TASKS do
              i = i + 1
              local n = math.min(per, left)
              local q = book:plan({ { item, n } }, avail)
              crafts = crafts + 1
              left = left - n
              avail = q.avail
              add({ key = "craft:" .. item .. ":" .. tag .. ":" .. i, kind = "craft", prio = prio, item = item, count = n,
                steps = q.crafts, uses = sorted_uses(q.uses), tag = tag })
            end
            if left > 0 then avail = book:plan({ { item, left } }, avail).avail end
            if fresh then avail[item] = saved end
          else
            if fresh then avail[item] = saved end
            missing_here = true
            for r, k in pairs(p.raw) do short_raw(r, k) end
          end
        else
          missing_here = true
          short_raw(item, short)
        end
      end
    end
    return not missing_here
  end

  ---------------------------------------------------------------------------------------------------
  -- 1. Entretien : brûleurs, production en attente, munitions des tourelles
  ---------------------------------------------------------------------------------------------------
  local fuel_reserve = view.smelter_coal or 0
  for _, o in ipairs(view.outposts) do
    if o.kind ~= "coal" then fuel_reserve = fuel_reserve + (o.coal_needed or 0) end
    if not o.has_task then
      if o.fuel_low then
        add({ key = "service:" .. o.id, kind = "service", prio = 95, outpost = o.id })
      elseif o.output >= T.collect_at or o.idle_ticks >= T.service_period then
        add({ key = "service:" .. o.id, kind = "service", prio = 70, outpost = o.id })
      end
    end
  end
  -- Bilan du charbon (AVANT la réserve de tournée : sans production de charbon, rien ne tourne) : production des avant-postes de charbon contre consommation des brûleurs. Moteur :
  -- foreuse à combustible 150 kW (0,0375 charbon/s) et 0,25 minerai/s, four en pierre 90 kW (0,0225/s).
  -- Si la marge passe sous 40 %, un avant-poste de charbon de plus devient prioritaire.
  do
    local coal_rate, burn_rate = 0, 0
    for _, o in ipairs(view.outposts) do
      local spec = T.outposts[o.kind]
      if o.kind == "coal" then coal_rate = coal_rate + o.drills * 0.25 end
      burn_rate = burn_rate + o.drills * 0.0375 + (spec.sink == "stone-furnace" and o.drills * 0.0225 or 0)
    end
    burn_rate = burn_rate + view.smelters * 0.0225
    out.coal_rate, out.burn_rate = coal_rate, burn_rate
    if #view.outposts > 0 and coal_rate < 1.4 * burn_rate and (view.pending.coal or 0) == 0 then
      local items = outpost_items("coal")
      local ext = extendable(view, "coal")
      if ext and not open["extend:" .. ext.id] then
        if take(items) then
          add({ key = "extend:" .. ext.id, kind = "extend", prio = 85, outpost = ext.id, outpost_kind = "coal", items = items })
        else
          want(items, 52, "charbon")
        end
      elseif not ext then
        out.site_needs.coal = math.max(out.site_needs.coal or 0, 1)
        if (view.sites.coal or 0) > 0 and take(items) then
          add({ key = "build:coal", kind = "build", prio = 85, outpost_kind = "coal", items = items })
        else
          want(items, 52, "charbon")
        end
      end
    end
  end

  -- Le charbon nécessaire aux tournées est réservé avant toute fabrication (grenades, etc.).
  avail[T.fuel] = math.max(0, (avail[T.fuel] or 0) - math.min(fuel_reserve, avail[T.fuel] or 0))

  local ammo = T.turret_ammo
  for _, g in ipairs(view.turret_groups) do
    if g.low > 0 and not g.has_task then
      local n = g.low * T.turret_ammo_target
      if (avail[ammo] or 0) >= n or (avail["firearm-magazine"] or 0) >= n then
        add({ key = "refill:" .. g.key, kind = "refill", prio = 90, group = g.key })
        local use = (avail[ammo] or 0) >= n and ammo or "firearm-magazine"
        avail[use] = avail[use] - n
      else
        want({ { ammo, n } }, 90, "munitions")
      end
    end
  end

  -- Reconstruction : un avant-poste détruit (attaque d'une faction, déchiqueteurs) dont l'objectif était
  -- atteint est reconstruit. Un objectif atteint n'étant jamais réouvert, une équipe vivait sans pierre ni
  -- cuivre après la perte de son avant-poste (moteur réel, E16 it. 10). Placée avant l'objectif : les
  -- foreuses en stock vont d'abord à la reconstruction, puis aux agrandissements.
  local done0 = view.done or {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    if done0[kind] and count_kind(view, kind) == 0 and (view.pending[kind] or 0) == 0 then
      local key = "build:" .. kind
      if (view.sites[kind] or 0) > 0 then
        if not open[key] then
          -- Kit complet si le stock le permet, sinon un avant-poste minimal (2 paires) qui relance la
          -- production : sans fer, une équipe ne pouvait plus fabriquer les 8 foreuses d'un avant-poste
          -- de fer complet (moteur réel, E16 it. 11 : fer livré figé à 412 pendant 50 min).
          local items = outpost_items(kind)
          local mini = minimal_items(kind)
          if take(items) then
            add({ key = key, kind = "build", prio = 80, outpost_kind = kind, items = items })
          elseif take(mini) then
            add({ key = key, kind = "build", prio = 80, outpost_kind = kind, items = mini })
          else
            want(mini, 60, "reconstruction")
          end
        end
      else
        out.site_needs[kind] = math.max(out.site_needs[kind] or 0, 1)
      end
    end
  end

  ---------------------------------------------------------------------------------------------------
  -- 2. Objectif : premier palier non atteint
  ---------------------------------------------------------------------------------------------------
  local done = view.done or {}
  local goal, parts
  local deferred = view.deferred or {}
  local ladder = view.ladder or T.ladder
  for _, g in ipairs(ladder) do
    if not done[g.key] and not deferred[g.key] then
      local reached, p = goal_status(g, view)
      if reached then
        out.reached[#out.reached + 1] = g.key
      else
        goal, parts = g, p
        break
      end
    end
  end
  out.goal = goal and goal.key or nil

  -- Anticipation : on prospecte aussi pour les deux prochains paliers d'avant-postes (un site se trouve
  -- en arrière-plan ; l'attendre au dernier moment coûtait plusieurs minutes par palier).
  do
    local seen, ahead = false, 0
    for _, g in ipairs(view.ladder or T.ladder) do
      if g == goal then seen = true end
      if seen and g ~= goal and g.need.outposts and ahead < 2 then
        ahead = ahead + 1
        for kind, n in pairs(g.need.outposts) do
          local missing_n = n - capacity(view, kind) - (view.pending[kind] or 0)
          if missing_n > 0 then out.site_needs[kind] = math.max(out.site_needs[kind] or 0, 1) end
        end
      end
    end
  end

  local missing_index = {}
  local function add_missing(raw)
    local ks = {}
    for k in pairs(raw) do ks[#ks + 1] = k end
    table.sort(ks)
    for _, k in ipairs(ks) do
      local i = missing_index[k]
      if i then
        out.missing[i][2] = out.missing[i][2] + math.ceil(raw[k])
      else
        out.missing[#out.missing + 1] = { k, math.ceil(raw[k]) }
        missing_index[k] = #out.missing
      end
    end
  end

  local army_now = false
  local research_now = false
  if goal then
    for _, part in ipairs(parts) do
      if part.outpost then
        local kind = part.outpost
        local items = outpost_items(kind)
        local ext = extendable(view, kind)
        if ext then
          -- D'abord agrandir un avant-poste existant : pas de prospection, trajets connus.
          if take(items) then
            add({ key = "extend:" .. ext.id, kind = "extend", prio = 80, outpost = ext.id, outpost_kind = kind, items = items })
          elseif not want(items, 50, "objectif") then
            add_missing(last_raw)
          end
        else
          local sites = view.sites[kind] or 0
          out.site_needs[kind] = (out.site_needs[kind] or 0) + part.n
          if sites > 0 and take(items) then
            add({ key = "build:" .. kind, kind = "build", prio = 80, outpost_kind = kind, items = items })
          elseif not want(items, 50, "objectif") then
            add_missing(last_raw)
          end
          if sites == 0 then add_missing({ ["site:" .. kind] = 1 }) end
        end
      elseif part.smelters then
        local items = { { T.SMELTER, part.smelters }, { T.fuel, T.fuel_per_burner * part.smelters } }
        if take(items) then
          add({ key = "smelters", kind = "smelters", prio = 80, count = part.smelters, items = items })
        elseif not want(items, 50, "objectif") then
          add_missing(last_raw)
        end
      elseif part.item then
        if not want({ { part.item, part.n } }, 50, "objectif", true) then add_missing(last_raw) end
      elseif part.soldiers then
        army_now = true
      elseif part.tech then
        research_now = true
      elseif part.fortify then
        local items = { { "gun-turret", part.n }, { ammo, part.n * T.turret_ammo_target } }
        if take(items) then
          add({ key = "fortify:" .. part.fortify, kind = "fortify", prio = 75, outpost = part.fortify, items = items })
        elseif not want(items, 50, "objectif") then
          add_missing(last_raw)
        end
      end
    end
  end

  ---------------------------------------------------------------------------------------------------
  -- 3. Fonderie du QG : production demandée (acier, briques ; plaques si aucun avant-poste)
  ---------------------------------------------------------------------------------------------------
  -- (les besoins en matières premières sont connus après les demandes : on les traite en fin de plan)

  ---------------------------------------------------------------------------------------------------
  -- 4. Ouvriers, armée, recherche (fond permanent, par ordre de priorité)
  ---------------------------------------------------------------------------------------------------
  local workers_wanted = T.workers_wanted(#view.outposts, view.workers_max)
  if view.workers < workers_wanted then
    if take(kit_list("worker", 1)) then
      out.recruit_workers = 1
    elseif view.workers == 0 then
      -- Secours (moteur réel, E16 it. 9) : une équipe dont tous les ouvriers sont morts ne pouvait plus
      -- rien fabriquer, pas même le pistolet d'un nouvel ouvrier. Le QG embauche un ouvrier SANS arme.
      out.recruit_workers = 1
      out.recruit_unarmed = true
    else
      want(kit_list("worker", 1), 55, "ouvrier")
    end
  end

  local army_goal_passed = done["army"] or army_now
  if view.threatened or army_goal_passed then
    local target = view.threatened and math.max(P.army_target(view), view.soldiers + T.kit_batch) or P.army_target(view)
    if army_now and goal and goal.need.soldiers then target = math.max(target, goal.need.soldiers) end
    target = math.min(target, view.soldiers_max)
    if view.soldiers < target then
      local unit = P.best_unit(view.tech)
      local n = math.min(T.kit_batch, target - view.soldiers)
      local kits = kit_list(unit, n)
      if take(kits) then
        out.train = { unit = unit, count = n }
      else
        -- Repli sur le fusilier si l'équipement du meilleur soldat n'est pas encore fabricable.
        local ok = want(kits, view.threatened and 85 or 45, "armee")
        if not ok and army_now then add_missing(last_raw) end
        if not ok and unit ~= "rifleman" then
          local fallback = kit_list("rifleman", n)
          if take(fallback) then out.train = { unit = "rifleman", count = n } else want(fallback, 45, "armee") end
        end
      end
    end
  end

  local next_tech = view.tech + 1
  if not view.no_research and (research_now or done["tech1"]) and T.research[next_tech] then
    local packs = T.research[next_tech]
    local have_all = true
    for _, it in ipairs(packs) do
      if (view.stock[it[1]] or 0) < it[2] then have_all = false break end
    end
    if have_all then
      out.research = next_tech
    else
      local short = {}
      for _, it in ipairs(packs) do
        local h = view.stock[it[1]] or 0
        if h < it[2] then short[#short + 1] = { it[1], math.min(10, it[2] - h) } end
      end
      if not want(short, 40, "recherche", true) and research_now then add_missing(last_raw) end
    end
  end

  -- Réserve de munitions pour les tourelles.
  if (view.stock[ammo] or 0) < 40 then want({ { ammo, 20 } }, 35, "reserve", true) end

  ---------------------------------------------------------------------------------------------------
  -- 5. Matières premières manquantes : avant-poste existant (on attend sa tournée), fonderie, minage
  ---------------------------------------------------------------------------------------------------
  local raws = {}
  for k in pairs(raw_short) do raws[#raws + 1] = k end
  table.sort(raws)
  -- Ouvriers sans tâche : ils minent à la main la matière qui manque le plus (comme un joueur au début),
  -- le minerai est fondu dans la fonderie du QG. Moteur réel (session 4) : sans cela, une équipe privée de
  -- plaques de fer (avant-poste de fer perdu ou introuvable) restait bloquée pour toute la partie.
  local idle = view.workers_idle or 0
  local mines = 0
  for _, item in ipairs(raws) do
    local n = raw_short[item]
    local src = SOURCE[item]
    if src then
      local has_outpost = src.outpost and count_kind(view, src.outpost) > 0
      if src.smelt then
        if view.smelters > 0 then out.smelt[src.smelt] = (out.smelt[src.smelt] or 0) + n end
        local ore = T.smelter_inputs[src.smelt][1]
        local minable = src.mine and src.mine ~= item
        if minable and view.smelters > 0 and (view.stock[ore] or 0) < n and (not has_outpost or idle > mines)
          and not open["mine:" .. ore] then
          add({ key = "mine:" .. ore, kind = "mine", prio = has_outpost and 25 or 45, resource = ore, count = math.min(MINE_BATCH, math.max(n, MINE_MIN)) })
          mines = mines + 1
        end
      elseif src.mine == item and (not has_outpost or idle > mines) and not open["mine:" .. item] then
        add({ key = "mine:" .. item, kind = "mine", prio = has_outpost and 25 or 45, resource = item, count = math.min(MINE_BATCH, math.max(n, MINE_MIN)) })
        mines = mines + 1
      end
    else
      out.unreachable = out.unreachable or {}
      out.unreachable[#out.unreachable + 1] = item
    end
  end

  -- Goulot d'étranglement : une plaque qui manque durablement (plus de 120 en attente) fait agrandir son
  -- avant-poste, même hors de l'échelle d'objectifs. Moteur réel (session 4) : le fer manquait à toutes
  -- les équipes (cuivre et pierre s'entassaient), l'armée restait à 0-5 soldats à 30 min.
  for _, item in ipairs({ "iron-plate", "copper-plate" }) do
    local short = raw_short[item] or 0
    local kind = item == "iron-plate" and "iron" or "copper"
    if short > 120 and (view.pending[kind] or 0) == 0 then
      local items = outpost_items(kind)
      local ext = extendable(view, kind)
      local key = ext and ("extend:" .. ext.id) or ("build:" .. kind)
      if not open[key] and (ext or (view.sites[kind] or 0) > 0) and take(items) then
        add({ key = key, kind = ext and "extend" or "build", prio = 78, outpost = ext and ext.id or nil, outpost_kind = kind, items = items })
      elseif not ext then
        out.site_needs[kind] = math.max(out.site_needs[kind] or 0, 1)
      end
    end
  end

  -- Fonderie : une tournée si elle a quelque chose à produire, à vider ou à ravitailler.
  if view.smelters > 0 and not view.smelter_task then
    if next(out.smelt) ~= nil or view.smelter_output > 0 or view.smelter_fuel_low then
      add({ key = "smelt", kind = "smelt", prio = view.smelter_fuel_low and 65 or 60, smelt = out.smelt })
    end
  end

  table.sort(tasks, function(a, b)
    if a.prio ~= b.prio then return a.prio > b.prio end
    return a.key < b.key
  end)
  return out
end

return P
