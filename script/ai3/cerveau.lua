--[[
  IA3-c « le cerveau par besoins », côté RUNTIME (docs/IA3_CERVEAU.md §5) : relie la pensée pure
  (shared/ai3/cerveau.lua) au jeu, derrière le réglage de carte « fo-war-ia3-cerveau » (settings/ia3c.lua ; éteint par
  défaut, revue M10).

  - Bascule FIGÉE par équipe à sa première pensée (f.team.ia3c = vrai ou faux) : un changement du réglage en cours de
    partie ne touche que les équipes fondées ensuite ; une partie en cours dont la bascule s'allume à la mise à jour du
    mod est MIGRÉE à la première pensée (§5.4 : technologies reçues gardées, échelle oubliée, tâches libres retirées).
  - Vraie recherche des factions par le « laboratoire du QG » (§5.2, revue B2, faits F269 et F270) : une technologie
    RÉELLE de la force (`add_research`), choisie par valeur ÷ coût parmi celles dont les prérequis sont faits et qui
    sont PAYABLES (règle d'IA3-a : shared/ai3/recherche.lua, A.level_status) ; laboratoires FABRIQUÉS par les PNJ (vraie
    recette) et posés près du coffre ; avancement écrit au temps des prototypes (`research_unit_energy` ticks par unité
    ÷ vitesse des laboratoires), en consommant les VRAIS packs du coffre unité par unité ; écrire 1 termine la
    recherche comme un laboratoire (F270). Les laboratoires ne sont pas alimentés (pas de centrale avant IA3-e).
  - Pont pour le reste du jeu (armée, chef, PvP, fenêtre) : f.tech = nombre de packs que la force sait fabriquer − 1.
  - Mesures (journal [FO-IA3C], les deux cerveaux) : paliers de recherche (§6.1), projets par minute, saturations,
    explorations demandées ; « objectif atteint 'iron2' » (critère K12, même ligne que l'ancien cerveau).
  - Exploration : une ressource dont l'équipe a besoin et qu'elle ne sait trouver nulle part est demandée
    (f.site_needs pour la prospection d'aujourd'hui ; Ia3.explore_requests(f) pour le lot IA3-f).

  Déterminisme : le catalogue (technologies, packs, laboratoires, livre complet) est un cache LOCAL tiré des seuls
  PROTOTYPES, construit au premier usage dans un événement ; tout ce qui vient de l'état de partie est lu et consommé
  dans la même pensée, ou rangé dans f.team.ia3 (global). Listes triées, aucun hasard.
]]

local T = require("shared.team.config")
local Book = require("shared.team.book")
local Planner = require("shared.team.planner")
local B = require("shared.ai3.buts")
local C = require("shared.ai3.cerveau")
local P = require("shared.ai3.projets")
local A = require("shared.ai3.recherche")
local State = require("script.faction.state")
local Board = require("script.team.board")
local Profiler = require("script.core.profiler")

local Ia3 = {}

Ia3.SETTING = "fo-war-ia3-cerveau"
Ia3.LAB_WINDOW_S = 600      -- un laboratoire de plus quand il reste plus de 10 min de laboratoire (§5.2, M12)
Ia3.LABS_MAX = 3
Ia3.PACK_BATCH = 30         -- packs d'une sorte demandés à la fois (comme IA3-a)
Ia3.REACH_RADII = { 48, 96, 160, 250 }
Ia3.REACH_EVERY = 12        -- gisements atteignables relus toutes les 12 pensées (1 min)
Ia3.LAB_OFFSETS = { { -10, -7 }, { -14, -7 }, { -10, -11 }, { -14, -11 } }
-- Paliers de recherche (§6.1, MESURE seulement : le cerveau n'en lit aucun) : technologie, pack, packs fabriqués.
Ia3.PALIERS = {
  { tech = "automation", pack = "automation-science-pack", n = 10 },
  { tech = "logistic-science-pack", pack = "logistic-science-pack", n = 10 },
  { tech = "military-science-pack", pack = "military-science-pack", n = 10 },
  { tech = "chemical-science-pack", pack = "chemical-science-pack", n = 40 },
}

local function sorted_keys(t) return State.sorted_keys(t or {}) end

local function minutes(f, tick)
  local war = State.war()
  return (tick - (f.started or (war and war.started) or 0)) / 3600
end

---------------------------------------------------------------------------------------------------
-- Catalogue (PROTOTYPES seulement : cache local, revue B1)
---------------------------------------------------------------------------------------------------
local cat = nil

local function catalogue()
  if cat then return cat end
  local techs, names, packs = {}, {}, {}
  for name in pairs(game.technology_prototypes) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local t = game.technology_prototypes[name]
    if t.enabled and not t.hidden and not t.research_unit_count_formula then
      local pre = {}
      for pname in pairs(t.prerequisites) do pre[#pre + 1] = pname end
      table.sort(pre)
      local ing = {}
      for _, i in ipairs(t.research_unit_ingredients) do
        ing[#ing + 1] = { i.name, i.amount }
        packs[i.name] = true
      end
      local unlocks, bonus = {}, false
      for _, e in ipairs(t.effects or {}) do
        if e.type == "unlock-recipe" then unlocks[#unlocks + 1] = e.recipe
        elseif e.type ~= "nothing" then bonus = true end
      end
      table.sort(unlocks)
      techs[name] = { name = name, pre = pre, ing = ing, count = t.research_unit_count,
        energy = t.research_unit_energy, unlocks = unlocks, bonus = bonus }
    end
  end
  -- Livre COMPLET (toutes les recettes de la main, prototypes) : payabilité d'une technologie future.
  local full = Book.from_game(game.recipe_prototypes)
  -- Laboratoires : entités de type « lab » posables par un objet.
  local labs = {}
  local lnames = {}
  for name in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = "lab" } })) do lnames[#lnames + 1] = name end
  table.sort(lnames)
  for _, name in ipairs(lnames) do
    local e = game.entity_prototypes[name]
    local items = e.items_to_place_this
    if items and items[1] then
      local inputs = {}
      for _, i in ipairs(e.lab_inputs or {}) do inputs[i] = true end
      labs[#labs + 1] = { entity = name, item = items[1].name, speed = e.researching_speed or 1, inputs = inputs }
    end
  end
  -- Produits des recettes débloquées (valeur d'une technologie).
  local products = {}
  for _, tname in ipairs(names) do
    local t = techs[tname]
    if t then
      for _, r in ipairs(t.unlocks) do
        local rp = game.recipe_prototypes[r]
        if rp and not products[r] then
          local list = {}
          for _, p in ipairs(rp.products) do list[#list + 1] = p.name end
          products[r] = list
        end
      end
    end
  end
  local machines = {}
  for _, n in ipairs({ "assembling-machine", "furnace", "lab", "mining-drill" }) do
    for ename in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = n } })) do
      local e = game.entity_prototypes[ename]
      for _, it in ipairs(e.items_to_place_this or {}) do machines[it.name] = true end
    end
  end
  local kit_items = {}
  for _, k in ipairs(sorted_keys(T.kits)) do for _, it in ipairs(T.kits[k]) do kit_items[it[1]] = true end end
  kit_items[P.TURRET] = true
  kit_items[T.turret_ammo] = true
  cat = { techs = techs, names = names, packs = packs, full = full, labs = labs, products = products,
    machines = machines, kit_items = kit_items, pack_list = sorted_keys(packs) }
  return cat
end

---------------------------------------------------------------------------------------------------
-- Bascule, migration
---------------------------------------------------------------------------------------------------
local function setting_on()
  local s = settings.global[Ia3.SETTING]
  return s ~= nil and s.value == true
end

--- La bascule est-elle allumée pour cette équipe ? Lue et FIGÉE à la première pensée ; migration d'une partie en cours.
function Ia3.active(f, tick)
  local t = f.team
  if not t then return false end
  if t.ia3c == nil then
    t.ia3c = setting_on()
    if t.ia3c then
      t.ia3 = C.new_state(tick)
      local old_done = #sorted_keys(t.done) > 0
      if old_done or (f.tech or 0) > 0 then
        -- Partie en cours (§5.4) : technologies reçues gardées, échelle oubliée, tâches LIBRES retirées (les tâches
        -- prises vont à leur terme), registre et projets neufs.
        Board.sync(f, {}, tick)
        t.deferred = {}
        log(string.format("[FO-IA3C] %s : migration vers le cerveau par besoins (avance de recherche heritee : niveau %d de l'ancien systeme ; %d objectif(s) de l'echelle oublies) a %.1f min",
          f.key or "?", f.tech or 0, #sorted_keys(t.done), minutes(f, tick)))
        t.ia3.migrated = tick
      end
      log(string.format("[FO-IA3C] %s : cerveau par besoins allume a %.1f min", f.key or "?", minutes(f, tick)))
    end
  end
  return t.ia3c == true
end

---------------------------------------------------------------------------------------------------
-- Recherche : laboratoire du QG
---------------------------------------------------------------------------------------------------
local RAW, MINABLE = C.raw_items()
local function obtainable(item) return RAW[item] == true end

--- Packs que la force sait fabriquer (recette active) ; pont f.tech = nombre − 1.
local function packs_enabled(force, c)
  local n = 0
  for _, pack in ipairs(c.pack_list) do
    local rname = c.full:recipe_for(pack)
    local r = rname and force.recipes[rname]
    if r and r.enabled then n = n + 1 end
  end
  return n
end

--- Technologies faites (ensemble tenu dans st.techs, frontière relue à chaque pensée).
local function refresh_techs(force, st, c)
  st.techs = st.techs or {}
  local done = st.techs
  if not st.techs_full then
    for _, name in ipairs(c.names) do
      local t = force.technologies[name]
      if t and t.researched then done[name] = true end
    end
    st.techs_full = true
    return
  end
  for _, name in ipairs(c.names) do
    local spec = c.techs[name]
    if spec and not done[name] then
      local ready = true
      for _, p in ipairs(spec.pre) do if not done[p] then ready = false break end end
      if ready then
        local t = force.technologies[name]
        if t and t.researched then done[name] = true end
      end
    end
  end
end

--- Valeur d'une technologie candidate (H9) : recettes débloquées (pack, armée, machine), bonus, et chaîne vers un pack.
local function tech_value(c, spec, w, chain_value)
  local v = 0
  local palier = false
  for _, r in ipairs(spec.unlocks) do
    for _, p in ipairs(c.products[r] or {}) do
      if c.packs[p] then v = v + 100 palier = true
      elseif c.kit_items[p] then v = v + math.floor(40 * (w.armee or 1000) / 1000)
      elseif c.machines[p] then v = v + math.floor(30 * (w.capital or 1000) / 1000)
      else v = v + 5 end
    end
  end
  if spec.bonus then v = v + math.floor(25 * (w.armee or 1000) / 1000) end
  if chain_value and chain_value > 0 then
    v = v + chain_value
    palier = true
  end
  return v, palier
end

--- Choix de la technologie (inertie : la technologie en cours reste tant qu'elle n'est ni faite ni impayable).
local function choose_tech(f, force, st, c, book, w)
  local done = st.techs
  local lab = st.lab
  if lab and lab.tech and not done[lab.tech] then
    local spec = c.techs[lab.tech]
    if spec then
      local ok = A.level_status(book, spec.ing, obtainable)
      if ok then return lab.tech, true, {}, lab.palier end
    end
  end
  -- Chaînes vers les packs que la force ne sait pas encore fabriquer : les prérequis manquants d'une technologie qui
  -- débloque un pack héritent de sa valeur (divisée par la longueur de la chaîne), si toute la chaîne est payable avec
  -- le livre COMPLET (règle H8 : une chaîne qui touche une matière sans source n'est pas suivie).
  local chain = {}
  for _, name in ipairs(c.names) do
    local spec = c.techs[name]
    if spec and not done[name] then
      local opens = false
      for _, r in ipairs(spec.unlocks) do
        for _, p in ipairs(c.products[r] or {}) do if c.packs[p] then opens = true end end
      end
      if opens then
        local seen, list, ok = {}, {}, true
        local function walk(n)
          if seen[n] or done[n] then return end
          seen[n] = true
          local s2 = c.techs[n]
          if not s2 then ok = false return end
          for _, pre in ipairs(s2.pre) do walk(pre) end
          list[#list + 1] = n
          local pay = A.level_status(c.full, s2.ing, obtainable)
          if not pay then ok = false end
        end
        walk(name)
        if ok and #list > 0 then
          local share = math.floor(100 / #list)
          for _, n in ipairs(list) do chain[n] = math.max(chain[n] or 0, share) end
        end
      end
    end
  end
  local best, best_score, best_palier = nil, nil, false
  local blocked_causes = {}
  for _, name in ipairs(c.names) do
    local spec = c.techs[name]
    if spec and not done[name] then
      local ready = true
      for _, p in ipairs(spec.pre) do if not done[p] then ready = false break end end
      local ft = ready and force.technologies[name]
      if ft and ft.enabled then
        local ok, causes = A.level_status(book, spec.ing, obtainable)
        if ok then
          local v, palier = tech_value(c, spec, w, chain[name])
          local cost = 0
          for _, ing in ipairs(spec.ing) do cost = cost + ing[2] * spec.count end
          local score = math.floor(v * 1000 / (cost + 10))
          if v > 0 and (not best_score or score > best_score) then best, best_score, best_palier = name, score, palier end
        else
          for _, k in ipairs(causes) do blocked_causes[k] = true end
        end
      end
    end
  end
  if best then return best, true, {}, best_palier end
  return nil, false, sorted_keys(blocked_causes), false
end

local function valid_labs(st)
  local out, speed = {}, 0
  local by_entity = {}
  for _, l in ipairs(catalogue().labs) do by_entity[l.entity] = l.speed end
  for _, e in ipairs(st.labs or {}) do
    if e.valid then
      out[#out + 1] = e
      speed = speed + (by_entity[e.name] or 1)
    end
  end
  st.labs = out
  return out, speed
end

local function best_lab(c, book, ing)
  for pass = 1, 2 do
    for _, l in ipairs(c.labs) do
      local fits = true
      for _, i in ipairs(ing or {}) do if not l.inputs[i[1]] then fits = false end end
      if fits and (pass == 2 or book:handcraftable(l.item)) then return l end
    end
  end
  return nil
end

--- Pose des laboratoires du QG (objets au coffre), près du coffre. Renvoie le nombre posé.
local function place_labs(f, st, lab, want)
  local labs = valid_labs(st)
  local placed = 0
  local surface = f.hq.surface
  for _, off in ipairs(Ia3.LAB_OFFSETS) do
    if #labs + placed >= want or f.hq.get_item_count(lab.item) < 1 then break end
    local pos = surface.find_non_colliding_position(lab.entity, { x = f.hq_pos.x + off[1], y = f.hq_pos.y + off[2] }, 8, 1)
    if pos then
      local e = surface.create_entity({ name = lab.entity, position = pos, force = f.force })
      if e then
        f.hq.remove_item({ name = lab.item, count = 1 })
        st.labs[#st.labs + 1] = e
        placed = placed + 1
      end
    end
  end
  return placed
end

--- Recherche d'une faction à cette pensée : choix, laboratoires, avancement. Renvoie l'information pour la pensée pure.
local function research_step(f, st, book, w, tick, view)
  local force = game.forces[f.force]
  if not force then return nil end
  local c = catalogue()
  refresh_techs(force, st, c)
  local tech, payable, causes, palier = choose_tech(f, force, st, c, book, w)
  local info = { tech = tech, payable = payable, causes = causes, palier = palier, packs = {} }
  if not tech then
    info.tech = "?"
    return info
  end
  local spec = c.techs[tech]
  st.lab = st.lab or {}
  local lab = st.lab
  if lab.tech ~= tech then
    if force.add_research(tech) then
      st.lab = { tech = tech, units = 0, paid = 0, last = tick, palier = palier, started = tick }
      lab = st.lab
      log(string.format("[FO-IA3C] %s : recherche '%s' commencee (%d unites de %d s, laboratoires %d) a %.1f min",
        f.key, tech, spec.count, math.floor(spec.energy / 60), #valid_labs(st), minutes(f, tick)))
    else
      info.payable, info.causes = false, { "add_research" }
      return info
    end
  end
  -- Laboratoires.
  local lproto = best_lab(c, book, spec.ing)
  local labs, speed = valid_labs(st)
  local left = spec.count - (lab.units or 0)
  local secs = left * spec.energy / 60 / math.max(1, lproto and lproto.speed or 1)
  local want = math.min(Ia3.LABS_MAX, math.max(1, math.ceil(secs / Ia3.LAB_WINDOW_S)))
  if lproto then
    info.lab_item = lproto.item
    local stock = view.stock[lproto.item] or 0
    local inc = (view.incoming or {})[lproto.item] or 0
    info.labs_craft = math.max(0, want - #labs - stock - inc)
    if stock > 0 and #labs < want then
      local n = place_labs(f, st, lproto, want)
      if n > 0 then
        labs, speed = valid_labs(st)
        log(string.format("[FO-IA3C] %s : %d laboratoire(s) du QG pose(s) (total %d) a %.1f min", f.key, n, #labs, minutes(f, tick)))
      end
    end
  end
  -- Avancement au temps des prototypes, packs consommés unité par unité.
  local cur = force.current_research
  if not cur or cur.name ~= tech then
    if not force.add_research(tech) then return info end
  end
  local dt = tick - (lab.last or tick)
  lab.last = tick
  speed = speed * (1 + (force.laboratory_speed_modifier or 0))
  if speed > 0 and dt > 0 then
    local target = math.min(spec.count, (lab.units or 0) + dt * speed / spec.energy)
    local need_paid = math.ceil(target - 1e-9)
    while lab.paid < need_paid do
      local ok = true
      for _, ing in ipairs(spec.ing) do
        if f.hq.get_item_count(ing[1]) < ing[2] then ok = false break end
      end
      if not ok then break end
      for _, ing in ipairs(spec.ing) do
        f.hq.remove_item({ name = ing[1], count = ing[2] })
        f.team.consumed[ing[1]] = (f.team.consumed[ing[1]] or 0) + ing[2]
      end
      lab.paid = lab.paid + 1
    end
    lab.units = math.min(target, lab.paid)
    if lab.units >= spec.count then
      force.research_progress = 1
      st.techs[tech] = true
      log(string.format("[FO-IA3C] %s : recherche '%s' terminee a %.1f min (laboratoire du QG, %d labo(s))", f.key, tech,
        minutes(f, tick), #labs))
      st.lab = { last = tick }
      f.tech = math.max(f.tech or 0, packs_enabled(force, c) - 1)
      return info
    end
    force.research_progress = lab.units / spec.count
  end
  -- Packs encore à fabriquer pour la technologie en cours (net du coffre et des fabrications en cours).
  local units_left = math.ceil(spec.count - lab.paid)
  for _, ing in ipairs(spec.ing) do
    local need = units_left * ing[2] - (view.stock[ing[1]] or 0) - ((view.incoming or {})[ing[1]] or 0)
    if need > 0 then info.packs[#info.packs + 1] = { ing[1], math.min(Ia3.PACK_BATCH, need) } end
  end
  return info
end

---------------------------------------------------------------------------------------------------
-- Gisements atteignables (minage à la main) : rayon du plus proche, relu toutes les REACH_EVERY pensées
---------------------------------------------------------------------------------------------------
local function reach_of(f, st, tick)
  st.reach_n = (st.reach_n or 0) - 1
  if st.reach and st.reach_n > 0 then return st.reach end
  st.reach_n = Ia3.REACH_EVERY
  local out = {}
  local surface = f.hq.surface
  for _, res in ipairs(sorted_keys(MINABLE)) do
    for _, r in ipairs(Ia3.REACH_RADII) do
      if surface.count_entities_filtered({ position = f.hq_pos, radius = r, name = res, limit = 1 }) > 0 then
        out[res] = r
        break
      end
    end
  end
  st.reach = out
  return out
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
--- Plan d'une équipe (bascule allumée), au format du planificateur.
function Ia3.plan(f, view, book, surface, tick)
  local t = f.team
  local st = t.ia3
  Profiler.start("ia3:research")
  local w = B.weights(f.chef and f.chef.mix, f.traits)
  local research = nil
  if not f.is_player then research = research_step(f, st, book, w, tick, view) end
  Profiler.stop("ia3:research")
  -- Tâches de minage déjà prises, par ressource.
  local mines_open = {}
  for _, tk in ipairs(Board.get(f).list or {}) do
    if tk.worker and tk.kind == "mine" and tk.ia3 then mines_open[tk.resource] = (mines_open[tk.resource] or 0) + 1 end
  end
  -- Plancher de fer des packs (garde de l'économie, revue B3) : fer d'un avant-poste de fer tant que « fer II » manque.
  local iron_floor = 0
  if not st.iron2_done then
    local raw = book:raw_cost(Planner.outpost_items("iron"))
    iron_floor = math.ceil(raw[P.IRON] or 0)
  end
  local army_target = 0
  if not f.is_player then
    local share = T.army_share[view.personality] or 0.6
    army_target = math.floor((view.soldiers_max or 0) * share)
  end
  local ctx = { tick = tick, is_player = f.is_player or false, weights = w, research = research,
    reach = reach_of(f, st, tick), mines_open = mines_open, iron_floor = iron_floor, army_target = army_target }
  Profiler.start("ia3:think")
  local plan = C.think(view, book, st, ctx)
  Profiler.stop("ia3:think")
  -- « Fer II » (critère K12) : même ligne que l'ancien cerveau.
  if not st.iron2_done then
    local cap = { iron = 0, coal = 0 }
    for _, o in ipairs(view.outposts or {}) do
      if cap[o.kind] then cap[o.kind] = cap[o.kind] + o.drills / T.outposts[o.kind].drills end
    end
    if cap.iron >= 1.5 and cap.coal >= 1.5 then
      st.iron2_done = tick
      log(string.format("[FO-TEAM] %s : objectif atteint 'iron2' a %.1f min", f.key, minutes(f, tick)))
    end
  end
  -- Exploration : une ressource sans source connue (prospection d'aujourd'hui ; demande gardée pour IA3-f).
  for _, res in ipairs(sorted_keys(plan.ia3.explore)) do
    local kind = B.kind_of_product(res)
    if kind then plan.site_needs[kind] = math.max(plan.site_needs[kind] or 0, 1) end
    if not (st.explore_logged or {})[res] then
      st.explore_logged = st.explore_logged or {}
      st.explore_logged[res] = tick
      log(string.format("[FO-IA3C] %s : exploration demandee pour '%s' (aucune source connue) a %.1f min", f.key, res,
        minutes(f, tick)))
    end
  end
  -- Annonces du cerveau (projets ouverts, finis, bloqués) : une ligne du journal du mod chacune.
  st.log_seen = st.log_seen or 0
  for _, e in ipairs(st.log or {}) do
    if (e.seq or 0) > st.log_seen then
      log(string.format("[FO-IA3C] %s : projet %s '%s'%s a %.1f min", f.key, e.kind, e.key,
        e.extra ~= nil and (" (" .. tostring(e.extra) .. ")") or "", minutes(f, e.tick)))
      st.log_seen = e.seq
    end
  end
  -- L'échelle n'existe plus : la patience de l'ancien cerveau ne s'applique pas (script/team/team.lua). Les champs
  -- lus ailleurs (bancs, fenêtre) gardent leur sens : un type d'avant-poste bâti une fois est « atteint ».
  t.goal_since = tick
  t.deferred = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do if st.ever[kind] then t.done[kind] = true end end
  if st.army_done then t.done.army = true end
  st.last_plan = { active = plan.ia3.active, productive = plan.ia3.productive, K = plan.ia3.K, dominant = plan.ia3.dominant }
  return plan
end

--- Après le travail de fond (script/team/poles.lua) : retire du tableau les tâches de FOND LIBRES qui extraient une
--- matière SATURÉE (minage, tournée, agrandissement, construction) : ses PNJ passent à ce qui manque (constat du DC,
--- 25/10, 18 h 45). Interface publique du tableau (Board.get, Board.sync) seulement.
function Ia3.after_poles(f, tick)
  local st = f.team.ia3
  local sat = st and st.saturated
  if not sat or next(sat) == nil then return 0 end
  local product_of = {}
  for _, oid in ipairs(sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    product_of[oid] = T.outposts[o.kind] and T.outposts[o.kind].product
  end
  local keep, dropped = {}, 0
  for _, tk in ipairs(Board.get(f).list or {}) do
    if not tk.worker then
      local item = nil
      if tk.fond then
        if tk.kind == "mine" then item = tk.resource
        elseif tk.kind == "service" then item = product_of[tk.outpost]
        elseif tk.kind == "extend" or tk.kind == "build" then
          item = tk.outpost_kind and T.outposts[tk.outpost_kind] and T.outposts[tk.outpost_kind].product
        end
      end
      if item and sat[item] then dropped = dropped + 1 else keep[#keep + 1] = tk end
    end
  end
  if dropped > 0 then
    Board.sync(f, keep, tick)
    st.fond_dropped = (st.fond_dropped or 0) + dropped
  end
  return dropped
end

--- Demandes d'exploration (ressource -> priorité) : pour le lot IA3-f (carte de connaissance, éclaireurs).
function Ia3.explore_requests(f)
  local st = f.team and f.team.ia3
  return st and st.explore or {}
end

---------------------------------------------------------------------------------------------------
-- Mesures (les deux cerveaux) : paliers, projets par minute
---------------------------------------------------------------------------------------------------
function Ia3.measure(f, tick, plan)
  local t = f.team
  if not t then return end
  t.ia3m = t.ia3m or { paliers = {}, last_min = 0 }
  local m = t.ia3m
  local force = game.forces[f.force]
  if force then
    for k, p in ipairs(Ia3.PALIERS) do
      if not m.paliers[k] then
        local tech = force.technologies[p.tech]
        if tech and tech.researched and ((t.delivered or {})[p.pack] or 0) >= p.n then
          m.paliers[k] = tick
          log(string.format("[FO-IA3C] %s : palier %d atteint a %.1f min (%s, %d packs ; cerveau %s)", f.key or "player", k,
            minutes(f, tick), p.tech, (t.delivered or {})[p.pack] or 0, t.ia3c and "par besoins" or "echelle"))
        end
      end
    end
  end
  if tick - (m.last_min or 0) >= 3600 and t.ia3c and t.ia3 then
    m.last_min = tick
    local st = t.ia3
    local taken = {}
    for _, tk in ipairs(Board.get(f).list or {}) do
      if tk.worker and tk.ia3 then taken[tk.ia3] = true end
    end
    local parts, n_taken, n_block = {}, 0, 0
    for _, p in ipairs(st.projects or {}) do
      local tk = taken[p.id] and "*" or ""
      if taken[p.id] then n_taken = n_taken + 1 end
      if p.state == "bloque" then n_block = n_block + 1 end
      parts[#parts + 1] = p.key .. ":" .. p.state .. tk .. (p.cause and ("(" .. p.cause .. ")") or "")
    end
    local sat = sorted_keys(st.saturated)
    local exp = sorted_keys(st.explore)
    local lp = st.last_plan or {}
    log(string.format("[FO-IA3C] %s minute %d | actifs %d productifs %d pris %d bloques %d K %d | inactifs %d/%d | sature [%s] | explore [%s] | fond retire %d | projets {%s}",
      f.key or "player", math.floor(minutes(f, tick) + 0.5), lp.active or 0, lp.productive or 0, n_taken, n_block, lp.K or 0,
      (t.scale and t.scale.last and t.scale.last.idle) or 0, f.engineers_count or 0, table.concat(sat, " "),
      table.concat(exp, " "), st.fond_dropped or 0, table.concat(parts, " ")))
  end
end

return Ia3
