--[[
  Lot CAPITAL « améliorer, et monter les époques », côté RUNTIME (règle pure : shared/ai3/capital.lua). Pour les FACTIONS
  au cerveau par besoins (votre équipe n'est pas touchée : c'est vous qui améliorez vos bâtiments).

  - RELEVÉ (toutes les Capital.SCAN_EVERY pensées, et juste après un paiement) : les bâtiments à niveaux de la force
    (noms lus dans les données des niveaux, shared/levels/config.lua) autour du QG et ses tourelles suivies (avant-postes
    compris), en marche ou non ; son centre (script/levels/levels.lua, Levels.cc). Rangé dans f.team.capital (global :
    entités, nombres, chaînes).
  - PROTOTYPES des niveaux (cache LOCAL, prototypes seulement, revue B1) : type -> rôle (R.ENTITY_ROLE), vitesse de
    fabrication ou de minage, vie, dégâts par tir ÷ cadence, objet qui le pose.
  - COÛT UNITAIRE d'un objet : le point fixe du graphe du cerveau général pour la force (General.unit_cost) ; repli sans
    cerveau général : les matières brutes du livre de recettes ; objet que le graphe dit infaisable : inconnu (H8).
  - DÉCISION (Cap.choose) et BUT (Cap.goal) donnés à la pensée pure par ctx.capital ; une ligne [FO-CAPITAL] par
    décision (valeur, coût, score, raisons, dépliage du coût par le graphe : main, machine, extraire).
  - EXÉCUTANT (Capital.pay, décisions immédiates de script/team/team.lua, sur le stock LIBRE) : le centre absent est
    POSÉ près du QG (objet du coffre, create_entity raise_built : le module des niveaux l'enregistre comme centre de la
    force) ; un niveau est PAYÉ par Levels.start, le mécanisme du joueur, avec le coffre du QG comme inventaire payeur
    (après le coffre du centre) ; une tourelle améliorée reste une tourelle de la faction (Outposts.add_turret).
  - REMPLACER (lot AMELIORER) : les machines HORS famille que l'équipe a posées (fours du QG f.smelters, machines des projets
    du plan directeur f.build) sont remplacées sur place par la machine supérieure, dérivée des PROTOTYPES (shared/ai3/
    capital.lua, Cap.successors : même type, même groupe de remplacement rapide, même emprise, même énergie, vitesse
    supérieure) ; create_entity{fast_replace} (F39) garde contenu et recette ; la cible est payée au stock libre, l'ancienne
    machine y revient. Factions ET votre équipe (pour elle, seules ses machines suivies : jamais celles du joueur).
  Le lien avec script/levels/levels.lua est posé au chargement par les deux modules (Capital.bind), sans changer l'ordre
  des require de control.lua.
  Déterminisme : listes triées par numéro d'entité, aucun hasard, aucun temps mesuré.
]]

local L = require("shared.levels.config")
local Cap = require("shared.ai3.capital")
local Gen = require("shared.ai3.general")
local R = require("shared.ai3.reglages")
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Outposts = require("script.faction.outposts")
local General = require("script.ai3.general")
local Profiler = require("script.core.profiler")
local Auto = require("script.ai3.automatisation") -- lot IA3-e : Auto.capital_steps (objets du dépliage)

local Capital = {}

-- Réglage de carte fo-war-capital (settings/capital.lua), ALLUMÉ par défaut depuis le lot AMELIORER (28/10) ; relu à chaque
-- pensée. Capital.ENABLED = false et l'interface « fo-capital » set_enabled(false) (bancs témoins, rangé dans l'état de la
-- guerre) l'éteignent aussi, même réglage allumé.
Capital.SETTING = "fo-war-capital"
Capital.ENABLED = true
Capital.SCAN_EVERY = 12   -- pensées (1 min à une pensée toutes les 5 s)
Capital.RADIUS = 64       -- tuiles autour du QG : la base (les tourelles des avant-postes sont suivies à part)
Capital.CENTER_OFFSETS = { { 0, 14 }, { 14, 0 }, { -14, 0 }, { 0, -14 }, { 14, 14 }, { -14, 14 } }
Capital.CENTER_SEARCH = 12
Capital.HISTORY = 32
Capital.REFUSE_TICKS = 5 * 3600 -- une cible refusée par l'exécutant est écartée 5 min (pas de nouvel essai à chaque pensée)

local Levels = package.loaded["script.levels.levels"] -- lien inverse : script/levels/levels.lua, Capital.bind
function Capital.bind(levels) Levels = levels end

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

function Capital.on()
  local war = State.war()
  if not (Capital.ENABLED == true and Levels ~= nil and not (war and war.capital_off)) then return false end
  local s = settings.global[Capital.SETTING]
  return s ~= nil and s.value == true
end

---------------------------------------------------------------------------------------------------
-- Noms des bâtiments à niveaux (données des niveaux) et prototypes (cache LOCAL)
---------------------------------------------------------------------------------------------------
local CFAM = Cap.center_family(L)
local NAMES = {}
for _, fam in ipairs(L.families) do
  if fam ~= CFAM then
    for n = 1, fam.max do NAMES[#NAMES + 1] = L.name(fam, n) end
  end
end
table.sort(NAMES)

local protos = {}
local function proto(name)
  local c = protos[name]
  if c == nil then
    c = false
    local p = game.entity_prototypes[name]
    if p then
      local ap = get(p, "attack_parameters")
      local items = get(p, "items_to_place_this")
      c = { type = p.type, role = R.ENTITY_ROLE[p.type], health = get(p, "max_health"),
        item = items and items[1] and items[1].name or nil,
        speed = get(p, "crafting_speed") or get(p, "mining_speed"),
        dps = ap and ((ap.damage_modifier or 1) / math.max(1, ap.cooldown or 1)) or nil }
    end
    protos[name] = c
  end
  return c or nil
end
Capital.proto = proto

---------------------------------------------------------------------------------------------------
-- Machines hors famille (lot AMELIORER) : catalogue des prototypes (cache LOCAL) et relevé des machines de l'équipe
---------------------------------------------------------------------------------------------------
local mcat = nil
--- Catalogue des machines de fabrication (types « fabrique » de R.ENTITY_ROLE) qui ont un objet, un groupe de remplacement
--- rapide et une vitesse : { names (triés), by[nom] = { type, group, w, h, energy, cats, speed, item } }.
local function machine_catalog()
  if mcat then return mcat end
  local c = { names = {}, by = {} }
  local filters = {}
  for _, t in ipairs(R.ENTITY_TYPES) do
    if R.ENTITY_ROLE[t] == "fabrique" then
      filters[#filters + 1] = { filter = "type", type = t, mode = #filters > 0 and "or" or nil }
    end
  end
  local list = #filters > 0 and game.get_filtered_entity_prototypes(filters) or {}
  local names = {}
  for n in pairs(list) do names[#names + 1] = n end
  table.sort(names)
  for _, n in ipairs(names) do
    local p = list[n]
    local items = get(p, "items_to_place_this")
    local item = items and items[1] and items[1].name or nil
    local group = get(p, "fast_replaceable_group")
    local speed = get(p, "crafting_speed")
    local hidden = false
    pcall(function() hidden = p.has_flag("hidden") end)
    local cb = get(p, "collision_box")
    if item and group and speed and speed > 0 and cb and not hidden then
      local cats = {}
      for k, v in pairs(get(p, "crafting_categories") or {}) do if v then cats[k] = true end end
      local energy = "none"
      if get(p, "burner_prototype") then energy = "burner"
      elseif get(p, "electric_energy_source_prototype") then energy = "electric"
      elseif get(p, "fluid_energy_source_prototype") then energy = "fluid"
      elseif get(p, "heat_energy_source_prototype") then energy = "heat" end
      c.by[n] = { type = p.type, group = group, speed = speed, item = item, energy = energy, cats = cats,
        w = math.ceil(cb.right_bottom.x - cb.left_top.x - 1e-6), h = math.ceil(cb.right_bottom.y - cb.left_top.y - 1e-6) }
      c.names[#c.names + 1] = n
    end
  end
  mcat = c
  return c
end
function Capital.mproto(name) return machine_catalog().by[name] end

--- Machines supérieures vers lesquelles `name` se remplace sur place (liste triée : vitesse croissante), lues aux prototypes.
--- Interface du lot LEVIERS (valeur d'une recherche qui débloque une meilleure machine) : même règle que le remplacement.
function Capital.successors_of(name)
  return Cap.successors(L, { mproto = Capital.mproto, machines = machine_catalog().names }, name)
end

-- Recettes (prototypes) qui donnent un objet, cache LOCAL ; l'objet est « débloqué » pour la force quand l'une est activée.
local recipes_of = {}
local function unlocked(f, item)
  local r = recipes_of[item]
  if not r then
    r = {}
    for n in pairs(game.get_filtered_recipe_prototypes({ { filter = "has-product-item",
        elem_filters = { { filter = "name", name = item } } } })) do
      r[#r + 1] = n
    end
    table.sort(r)
    recipes_of[item] = r
  end
  local force = game.forces[f.force]
  for _, n in ipairs(r) do
    local rc = force and force.recipes[n]
    if rc and rc.enabled then return true end
  end
  return false
end

--- Machines que l'équipe a posées, hors familles à niveaux : fours du QG et machines des projets du plan directeur
--- (jamais celles du joueur, même force). Rend { list = { {id, name, working} } triée par id, ents = { [id] = entité },
--- refs = { [id] = entrée du plan } }.
local function scan_machines(f)
  local cat = machine_catalog()
  local surface = f.hq.surface
  local ents, refs = {}, {}
  local function add(e, ref)
    if e and e.valid and e.unit_number and cat.by[e.name] then
      ents[e.unit_number] = e
      if ref then refs[e.unit_number] = ref end
    end
  end
  for _, e in ipairs(f.smelters or {}) do add(e) end
  local b = f.build
  if b and b.projects then
    for _, pid in ipairs(sorted_keys(b.projects)) do
      for _, pe in ipairs(b.projects[pid].ents or {}) do
        if pe.built and cat.by[pe.name] then
          local e = surface.find_entity(pe.name, { pe.x, pe.y })
          if e and e.force.name == f.force then add(e, pe) end
        end
      end
    end
  end
  local list = {}
  local ws = defines.entity_status and defines.entity_status.working
  for _, id in ipairs(sorted_keys(ents)) do
    local e = ents[id]
    list[#list + 1] = { id = id, name = e.name, working = ws ~= nil and e.status == ws }
  end
  return { list = list, ents = ents, refs = refs }
end

---------------------------------------------------------------------------------------------------
-- État de la faction (global)
---------------------------------------------------------------------------------------------------
local function state_of(f)
  f.team.consumed = f.team.consumed or {}
  f.team.capital = f.team.capital or { decisions = 0, upgrades = 0, paid = 0, history = {}, ents = {}, scan_n = 0,
    by_family = {}, steps = {} }
  return f.team.capital
end

--- Relevé des bâtiments à niveaux de la force : { list = { {id, name, working} }, center = {id, name} }.
local function scan(f, c)
  local surface = f.hq.surface
  local by_id = {}
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, name = NAMES, position = f.hq_pos,
      radius = Capital.RADIUS })) do
    if e.valid and e.unit_number then by_id[e.unit_number] = e end
  end
  for _, id in ipairs(sorted_keys(f.turrets)) do
    local t = f.turrets[id]
    if t and t.valid and t.unit_number and L.parse(t.name) then by_id[t.unit_number] = t end
  end
  local ents, list = {}, {}
  local by_family = {}
  for _, id in ipairs(sorted_keys(by_id)) do
    local e = by_id[id]
    ents[#ents + 1] = e
    local ws = defines.entity_status and defines.entity_status.working
    local working = ws ~= nil and e.status == ws
    list[#list + 1] = { id = id, name = e.name, working = working }
    local fam, n = L.parse(e.name)
    if fam then by_family[fam.key] = math.max(by_family[fam.key] or 0, n) end
  end
  c.ents = ents
  c.by_family = by_family
  local cc = Levels.cc(game.forces[f.force])
  local center = nil
  if cc and cc.valid then
    center = { id = cc.unit_number, name = cc.name }
    local _, n = L.parse(cc.name)
    c.cc_level = n or 0
  else
    c.cc_level = 0
  end
  return { list = list, center = center }
end

--- Relevé complet : bâtiments à niveaux et centre (factions seulement), machines hors famille (toutes les équipes).
local function census_of(f, c)
  local census
  if f.is_player then
    -- Votre équipe : ni centre à poser ni bâtiments à niveaux du joueur (même force) ; seulement ses propres machines.
    census = { list = {}, center = nil, no_center = true }
    c.ents, c.by_family, c.cc_level = {}, {}, 0
  else
    census = scan(f, c)
  end
  local m = scan_machines(f)
  census.machines = m.list
  c.mach_ents, c.mach_refs = m.ents, m.refs
  return census
end

local function find_entity(c, id)
  for _, e in ipairs(c.ents or {}) do
    if e.valid and e.unit_number == id then return e end
  end
  return nil
end

---------------------------------------------------------------------------------------------------
-- Décision (appelée par la pensée de la faction : script/ai3/cerveau.lua)
---------------------------------------------------------------------------------------------------
--- Coût unitaire d'un objet pour la force : graphe du cerveau général ; repli : matières brutes du livre.
local function unit_cost_fn(f, book)
  return function(item)
    if General.on() then
      local u = General.unit_cost(f, item)
      if u ~= nil then return u end
      if General.feasible(f, item) == false then return nil end
    end
    local raw = book:raw_cost({ { item, 1 } })
    local s = 0
    for _, k in ipairs(sorted_keys(raw)) do s = s + raw[k] end
    if s <= 0 and not book:handcraftable(item) then return nil end
    return s
  end
end

--- Texte d'une décision pour le journal : « famille de -> à » ou « remplacer machine -> machine xN ».
function Capital.describe(d)
  if d.replace then return string.format("remplacer %s -> %s x%d", d.replace.from, d.replace.to, d.replace.n) end
  return string.format("%s %d -> %d", d.family, d.from, d.to)
end

--- But « amélioration » de la pensée (nil : aucun, ou éteint). w = poids des familles (B.weights).
function Capital.goal(f, view, book, tick, w)
  if not Capital.on() then
    -- Éteint en cours de partie : la décision en cours et ses objets (voulus, dépliage) sont oubliés ; relevé et compteurs
    -- gardés (interface fo-capital).
    local c = f.team and f.team.capital
    if c then c.current, c.goal, c.wanted, c.steps, c.scan_n = nil, nil, nil, nil, 0 end
    return nil
  end
  if not (f.hq and f.hq.valid) then return nil end
  local c = state_of(f)
  c.scan_n = (c.scan_n or 0) - 1
  if c.goal and c.scan_n > 0 then return c.goal end
  c.scan_n = Capital.SCAN_EVERY
  Profiler.start("capital:decide")
  local census = census_of(f, c)
  local exclude = {}
  c.refused_until = c.refused_until or {}
  for _, k in ipairs(sorted_keys(c.refused_until)) do
    if tick < c.refused_until[k] then exclude[k] = true else c.refused_until[k] = nil end
  end
  local ctx = { proto = proto, mproto = Capital.mproto, machines = machine_catalog().names,
    available = function(item) return unlocked(f, item) end,
    unit_cost = unit_cost_fn(f, book), stock = view.stock or {}, weights = w,
    threat = view.threatened or (f.pvp and f.pvp.declared) or false, current = c.current and c.current.key or nil,
    exclude = exclude }
  local d = Cap.choose(L, census, ctx)
  c.wanted = {}
  for _, k in ipairs(sorted_keys(d.wanted)) do c.wanted[k] = true end
  local goal = Cap.goal(d, w)
  local prev = c.current and c.current.key or nil
  if d.none then
    c.current = nil
    local sig = Cap.why_text(d)
    if c.none_sig ~= sig then
      c.none_sig = sig
      log(string.format("[FO-CAPITAL] %s : %s ; centre niveau %d a %.1f min", f.key or "?", sig, c.cc_level or 0,
        minutes(f, tick)))
    end
  else
    c.none_sig = nil
    local cost = {}
    for i, it in ipairs(d.cost) do cost[i] = { it[1], it[2] } end
    local ids = nil
    if d.ids then
      ids = {}
      for i, v in ipairs(d.ids) do ids[i] = v end
    end
    c.current = { key = d.key, id = d.id, family = d.family, from = d.from, to = d.to, build = d.build or nil,
      center = d.center or nil, value = d.value, work = d.work, score = d.score, cost = cost, ids = ids,
      replace = d.replace and { from = d.replace.from, to = d.replace.to, n = d.replace.n } or nil }
    if d.key ~= prev then
      c.decisions = (c.decisions or 0) + 1
      -- Dépliage du coût par le graphe du cerveau général (le même que pour la recherche) : ce que la faction fabriquera
      -- à la main, produira en machine, extraira ; ces objets nourrissent aussi la règle « main ou machine » (IA3-e).
      local sum_txt = ""
      c.steps = {}
      local sum = General.on() and General.summary_items(f, cost) or nil
      if sum then
        for _, kind in ipairs({ "hand", "produce", "extract" }) do
          for _, k in ipairs(sorted_keys(sum[kind] or {})) do c.steps[#c.steps + 1] = k end
        end
        sum_txt = string.format(" | depliage %d etapes : main %s machine %s extraire %s construire %s", sum.steps,
          Gen.fmt_map(sum.hand, 6), Gen.fmt_map(sum.produce, 6), Gen.fmt_map(sum.extract), Gen.fmt_map(sum.build))
      end
      c.history[#c.history + 1] = { key = d.key, tick = tick, value = d.value, work = d.work, score = d.score }
      while #c.history > Capital.HISTORY do table.remove(c.history, 1) end
      log(string.format("[FO-CAPITAL] %s : but '%s' (%s) valeur %d cout %d score %d%s | %s%s | centre niveau %d, %d candidat(s) a %.1f min",
        f.key or "?", d.key, Capital.describe(d), d.value, d.work, d.score, d.all_in and " (cout au stock)" or "",
        Cap.why_text(d), sum_txt, c.cc_level or 0, d.n_cands or 0, minutes(f, tick)))
    end
  end
  c.goal = goal
  Profiler.stop("capital:decide")
  return goal
end

--- Objets que les améliorations de valeur attendent et que la faction ne sait pas obtenir (H8 -> H9 : la recherche
--- qui les débloque prend de la valeur, script/ai3/cerveau.lua).
--- Éteint (réglage, témoin) : nil, même si une pensée allumée les avait rangés (l'éteindre en cours de partie ne laisse
--- aucun objet voulu peser sur la recherche).
function Capital.wanted(f)
  if not Capital.on() then return nil end
  local c = f.team and f.team.capital
  return c and c.wanted or nil
end

--- Objets du dépliage du coût de l'amélioration en cours (pour la règle « main ou machine » d'IA3-e) ; nil éteint.
function Capital.steps(f)
  if not Capital.on() then return nil end
  local c = f.team and f.team.capital
  return c and c.steps or nil
end
Auto.capital_steps = Capital.steps

---------------------------------------------------------------------------------------------------
-- Exécutant : poser le centre, payer le niveau (décisions immédiates de script/team/team.lua)
---------------------------------------------------------------------------------------------------
local function has_list(stock, list)
  for _, it in ipairs(list) do
    if (stock[it[1]] or 0) < it[2] then return false end
  end
  return true
end

local function place_center(f, c, d, tick)
  local surface = f.hq.surface
  local item = d.cost[1][1]
  if Stock.count(f, item) < 1 then return false, "objet" end
  local name = L.name(CFAM, 1)
  for _, off in ipairs(Capital.CENTER_OFFSETS) do
    local pos = surface.find_non_colliding_position(name, { x = f.hq_pos.x + off[1], y = f.hq_pos.y + off[2] },
      Capital.CENTER_SEARCH, 1)
    if pos then
      local e = surface.create_entity({ name = name, position = pos, force = f.force, raise_built = true })
      if e and e.valid then
        Stock.remove(f, item, 1)
        f.team.consumed[item] = (f.team.consumed[item] or 0) + 1
        log(string.format("[FO-CAPITAL] %s : centre de commandement pose (niveau 1) en (%d, %d) a %.1f min", f.key or "?",
          math.floor(pos.x), math.floor(pos.y), minutes(f, tick)))
        return true
      end
    end
  end
  return false, "place"
end

--- Remplace UNE machine sur place par `to` (remplacement rapide du moteur, F39 : contenu, recette et munitions gardés). Rend
--- la nouvelle entité, ou nil et le motif. L'objet de la cible vient du stock libre, celui de l'ancienne machine y revient ;
--- les registres qui tenaient l'ancienne entité (fours du QG, propriété, entrée du plan directeur) suivent la nouvelle.
local function replace_one(f, c, e, to)
  local cat = machine_catalog()
  local tp, op = cat.by[to], cat.by[e.name]
  if not (tp and op) then return nil, "inconnue" end
  if Stock.count(f, tp.item) < 1 then return nil, "objet" end
  local surface = e.surface
  local args = { name = to, position = e.position, direction = e.direction, force = e.force }
  if not surface.can_fast_replace(args) then return nil, "pas-remplacable" end
  local old_unit = e.unit_number
  local ratio = e.get_health_ratio() or 1
  local owner = State.owner(old_unit)
  local ref = c.mach_refs and c.mach_refs[old_unit]
  local slot
  for i, s in ipairs(f.smelters or {}) do
    if s == e then slot = i break end
  end
  local new = surface.create_entity({ name = to, position = args.position, direction = args.direction, force = args.force,
    fast_replace = true, spill = false, raise_built = true, create_build_effect_smoke = false })
  if not (new and new.valid and new.name == to) then return nil, "echec" end
  if e.valid then
    -- Posée par-dessus sans rien remplacer (F86, hors grille) : annulé, l'ancienne reste.
    new.destroy()
    return nil, "hors-grille"
  end
  Stock.remove(f, tp.item, 1)
  Stock.insert(f, op.item, 1)
  f.team.consumed[tp.item] = (f.team.consumed[tp.item] or 0) + 1
  local mh = get(new.prototype, "max_health")
  if mh then new.health = mh * ratio end
  if slot then f.smelters[slot] = new end
  if owner then
    State.disown(old_unit)
    State.own(new, f.id, owner.kind, owner.oid)
  end
  if ref then ref.name = to end
  return new
end

--- Paie un lot de remplacements (d.ids) : chaque machine refusée est écartée seule, 5 min. Rend le nombre fait et le dernier
--- motif de refus.
local function pay_replace(f, c, d, tick)
  local n, why = 0, nil
  c.refused_until = c.refused_until or {}
  for _, id in ipairs(d.ids or {}) do
    local e = c.mach_ents and c.mach_ents[id]
    local new, w
    if e and e.valid and e.name == d.replace.from then
      new, w = replace_one(f, c, e, d.replace.to)
    else
      w = "disparue"
    end
    if new then
      n = n + 1
    else
      why = w
      c.refused_until["m:" .. id] = tick + Capital.REFUSE_TICKS
      if w == "objet" then break end
    end
  end
  return n, why
end

--- Paie l'amélioration prête (plan.ia3.pay : coût réservé au stock virtuel par la pensée pure) si le stock LIBRE la
--- couvre. Rend le nombre d'améliorations faites.
function Capital.pay(f, surface, tick, plan, stock)
  local list = plan and plan.ia3 and plan.ia3.pay
  if not list or #list == 0 or not Capital.on() then return 0 end
  local c = state_of(f)
  local d = c.current
  local done = 0
  for _, p in ipairs(list) do
    if d and p.target == d.key and has_list(stock, d.cost) then
      local ok, why
      local n_done = 1
      if d.replace then
        n_done, why = pay_replace(f, c, d, tick)
        ok = n_done > 0
        if ok then why = nil end
      elseif d.build then
        ok, why = place_center(f, c, d, tick)
      else
        -- Le centre n'est pas dans le relevé des bâtiments (familles ordinaires) : il est lu au module des niveaux.
        local e
        if d.center then
          e = Levels.cc(game.forces[f.force])
          if e and e.unit_number ~= d.id then e = nil end
        else
          e = find_entity(c, d.id)
        end
        if e then
          local owner = State.owner(d.id)
          local res, info, new
          ok, res, info, new = Levels.start(e, nil, { inventories = Stock.inventories(f) })
          why = res
          if ok and new and new.valid then
            for _, it in ipairs(d.cost) do f.team.consumed[it[1]] = (f.team.consumed[it[1]] or 0) + it[2] end
            if owner and owner.kind == "turret" then Outposts.add_turret(f, new, owner.oid, 0) end
            if d.center then
              log(string.format("[FO-CAPITAL] %s : centre monte au niveau %d (epoque %d ouverte) a %.1f min", f.key or "?",
                d.to, d.to, minutes(f, tick)))
            end
          end
        else
          ok, why = false, "disparu"
        end
      end
      if ok then
        done = done + 1
        c.upgrades = (c.upgrades or 0) + 1
        local m = {}
        for _, it in ipairs(d.cost) do m[it[1]] = it[2] end
        if d.replace then
          m = {}
          m[d.replace.to] = n_done
        end
        log(string.format("[FO-CAPITAL] %s : amelioration payee '%s' (%s) valeur %d cout %d, paye %s a %.1f min",
          f.key or "?", d.key, Capital.describe(d), d.value or 0, d.work or 0, Gen.fmt_map(m), minutes(f, tick)))
        c.current, c.goal, c.scan_n = nil, nil, 0 -- décision suivante dès la prochaine pensée
      else
        c.refused = (c.refused or 0) + 1
        c.refused_until = c.refused_until or {}
        c.refused_until[d.key] = tick + Capital.REFUSE_TICKS
        c.current = nil
        if c.refused_sig ~= (d.key .. "|" .. tostring(why)) then
          c.refused_sig = d.key .. "|" .. tostring(why)
          log(string.format("[FO-CAPITAL] %s : amelioration '%s' refusee (%s) a %.1f min", f.key or "?", d.key, tostring(why),
            minutes(f, tick)))
        end
        c.goal, c.scan_n = nil, 0
      end
      break
    end
  end
  return done
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs) et bascule des témoins
---------------------------------------------------------------------------------------------------
local function team_of(key)
  local war = State.war()
  for _, id in ipairs(sorted_keys(war and war.factions)) do
    local f = war.factions[id]
    if f.key == key then return f end
  end
  return nil
end

remote.add_interface("fo-capital", {
  status = function(key)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    local c = f.team.capital or {}
    local out = { decisions = c.decisions or 0, upgrades = c.upgrades or 0, refused = c.refused or 0,
      cc_level = 0, by_family = {}, history = {} }
    if Levels and f.hq and f.hq.valid then
      local cc = Levels.cc(game.forces[f.force])
      if cc and cc.valid then
        local _, n = L.parse(cc.name)
        out.cc_level = n or 0
      end
    end
    for _, k in ipairs(sorted_keys(c.by_family)) do out.by_family[k] = c.by_family[k] end
    for i, h in ipairs(c.history or {}) do out.history[i] = { key = h.key, tick = h.tick, value = h.value, work = h.work,
      score = h.score } end
    return out
  end,
  -- Témoins des bancs : l'interrupteur est rangé dans l'état de la guerre (global : survit à la sauvegarde du banc).
  set_enabled = function(on)
    local war = State.war()
    if war then war.capital_off = not on or nil end
  end,
})

return Capital
