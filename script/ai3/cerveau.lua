--[[
  IA3-c « le cerveau par besoins », côté RUNTIME (docs/IA3_CERVEAU.md §5) : relie la pensée pure
  (shared/ai3/cerveau.lua) au jeu, derrière le réglage de carte « fo-war-ia3-cerveau » (settings/ia3c.lua ; éteint par
  défaut, revue M10).

  - Bascule par équipe (f.team.ia3c) : relue à chaque pensée tant qu'elle est éteinte ; l'allumer en cours de partie
    MIGRE l'équipe (§5.4 : technologies reçues gardées, échelle oubliée, tâches libres retirées) ; une fois allumée,
    elle est FIGÉE (l'éteindre est ignoré et dit au journal ; aucune migration nouveau → ancien, revue M10).
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
local R = require("shared.ai3.registre") -- lot IA-V2 : contrôle du registre d'IA3-b (interface de lecture)
local State = require("script.faction.state")
local Board = require("script.team.board")
local Profiler = require("script.core.profiler")
local General = require("script.ai3.general") -- lot IA-G : le cerveau général (choix de recherche sur le graphe)
local Rg = require("shared.ai3.reglages") -- lot IA-G : types du moteur, ressources clés de repli
local Paliers = require("script.ai3.paliers") -- lot IA-G : paliers de MESURE (déplacés ; aucune décision ne les lit)
local Auto = require("script.ai3.automatisation") -- lot IA3-e : automatiser ce qui revient (plan directeur d'IA1-d)
local Capital = require("script.ai3.capital") -- lot CAPITAL : améliorer les bâtiments à niveaux, monter le centre
local Br = require("shared.ai3.bras") -- lot SCALE : travail des bras libres
local Pl = require("shared.ai3.places") -- lot SCALE (correction) : places du QG depuis l'emprise du prototype
local PlacesQG = require("script.ai3.places_qg") -- lot SCALE (correction) : pose sur la grille, place vérifiée
local Capi = require("script.ai3.capitalisation") -- lot CAPIB : la capitalisation (réglage fo-war-capi, éteint par défaut)

local Ia3 = {}

Ia3.SETTING = "fo-war-ia3-cerveau"
Ia3.LAB_WINDOW_S = 600      -- un laboratoire de plus quand il reste plus de 10 min de laboratoire (§5.2, M12)
Ia3.LABS_MAX = 3
Ia3.PACK_BATCH = 30         -- packs d'une sorte demandés à la fois (comme IA3-a)
Ia3.PACK_RESERVE = 10       -- réserve de packs de chaque sorte payable (la recherche suivante démarre sans attendre)
Ia3.REACH_RADII = { 48, 96, 160, 250 }
Ia3.REACH_EVERY = 12        -- gisements atteignables relus toutes les 12 pensées (1 min)
-- Places des laboratoires du QG (lot SCALE, correction après revue) : bloc de départ de main 0.6.1 (4 places, même ordre)
-- puis rangées, calculées depuis l'EMPRISE du laboratoire posé (collision_box du prototype) et la disposition nommée de
-- shared/team/config.lua (T.hq_rows.lab) ; règle pure : shared/ai3/places.lua. Plus aucun pas de 4 tuiles écrit en dur.

-- Paliers de recherche (§6.1, MESURE seulement) : lot IA-G, déplacés dans script/ai3/paliers.lua ; le test anti-échelle
-- (tests/iag_test.lua §8) vérifie qu'ils ne sont lus que par Ia3.measure.
Ia3.PALIERS = Paliers.LIST

local function sorted_keys(t) return State.sorted_keys(t or {}) end

--- Lot IA-G : ressources clés d'une équipe (types d'avant-poste) : déduites du dépliage pour une faction au cerveau
--- général (script/ai3/general.lua) ; repli de shared/ai3/reglages.lua (votre équipe, avant la 1re décision).
local function key_of(f)
  local k = (not f.is_player and General.on()) and General.key(f) or nil
  if k and k.top and k.fuel then return k end
  return Rg.FALLBACK_KEY
end

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
  -- Lot IA-G : types du moteur lus dans shared/ai3/reglages.lua (rôle « labo »), plus de nom dans ce fichier.
  for _, ty in ipairs(Rg.ENTITY_TYPES) do
    if Rg.ENTITY_ROLE[ty] == "labo" then
      for name in pairs(game.get_filtered_entity_prototypes({ { filter = "type", type = ty } })) do lnames[#lnames + 1] = name end
    end
  end
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
  local mtypes = {} -- lot IA-G : types des machines (rôles fabrique, labo, foreuse de shared/ai3/reglages.lua)
  for _, ty in ipairs(Rg.ENTITY_TYPES) do
    local r = Rg.ENTITY_ROLE[ty]
    if r == "fabrique" or r == "labo" or r == "foreuse" then mtypes[#mtypes + 1] = ty end
  end
  for _, n in ipairs(mtypes) do
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
    machines = machines, kit_items = kit_items, pack_list = sorted_keys(packs), full_pay = {} }
  return cat
end

---------------------------------------------------------------------------------------------------
-- Bascule, migration
---------------------------------------------------------------------------------------------------
local function setting_on()
  local s = settings.global[Ia3.SETTING]
  return s ~= nil and s.value == true
end

--- La bascule est-elle allumée pour cette équipe ? Lue à chaque pensée tant qu'elle est éteinte : l'allumer en cours de
--- partie MIGRE l'équipe (ancien → nouveau, §5.4 : un réglage de carte ne se change qu'une fois la partie chargée, une
--- partie existante doit donc pouvoir passer au nouveau cerveau). Une fois allumée, elle est FIGÉE : l'éteindre ensuite
--- est ignoré et dit une fois au journal (aucune migration nouveau → ancien, revue M10).
function Ia3.active(f, tick)
  local t = f.team
  if not t then return false end
  if t.ia3c == true then
    if not setting_on() and not t.ia3_off_logged then
      t.ia3_off_logged = tick
      log(string.format("[FO-IA3C] %s : reglage eteint ignore (le cerveau par besoins reste allume pour cette equipe) a %.1f min",
        f.key or "?", minutes(f, tick)))
    end
    return true
  end
  if t.ia3c ~= true then
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

--- Pont f.tech : nombre de technologies RECHERCHÉES qui débloquent la recette d'un pack (le pack rouge est donné au
--- départ : 0 ; pack vert : 1 ; pack militaire : 2 ; pack chimique : 3…). Compté sur les technologies (st.techs), pas
--- sur les recettes actives : le moteur simulé des tests active toutes les recettes.
local function packs_researched(st, c)
  local n = 0
  for _, name in ipairs(c.names) do
    local spec = c.techs[name]
    if spec and st.techs[name] then
      local opens = false
      for _, r in ipairs(spec.unlocks) do
        for _, p in ipairs(c.products[r] or {}) do if c.packs[p] then opens = true end end
      end
      if opens then n = n + 1 end
    end
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
local function tech_value(c, spec, w, chain_value, wanted)
  local v = 0
  local palier = false
  for _, r in ipairs(spec.unlocks) do
    for _, p in ipairs(c.products[r] or {}) do
      if c.packs[p] then v = v + 100 palier = true
      -- Lot IA3-e : un objet que l'automatisation demande et que l'équipe ne sait pas fabriquer (poteau moyen d'un
      -- module) vaut un pack (H9 : « la recherche vaut ce qu'elle débloque »).
      elseif wanted and wanted[p] then v = v + 100
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
Ia3.AUTO_STALL = 10 * 3600  -- lot IA3-e : une recherche pour l'automatisation sans unité payée depuis 10 min…
Ia3.AUTO_PAUSE = 20 * 3600  -- … laisse passer les autres recherches pendant 20 min (les paliers ne reculent pas, K1)

local function choose_tech(f, force, st, c, book, w, tick)
  local done = st.techs
  local wanted = Auto.wanted(f) -- lot IA3-e
  local lab = st.lab
  -- Lot IA3-e (garde de K1) : la chaîne d'un objet voulu ne doit pas FIGER la recherche (moteur réel, e2-usine : azure
  -- bloquée 70 min sur le poteau moyen faute de packs verts, paliers 2 et 3 jamais atteints, contre 32 et 53 min au témoin).
  if lab and lab.for_auto and lab.tech and not done[lab.tech] and tick and tick - (lab.paid_tick or lab.started or tick) > Ia3.AUTO_STALL then
    st.auto_pause = tick + Ia3.AUTO_PAUSE
    log(string.format("[FO-IA3E] %s : recherche '%s' (automatisation) sans progres depuis %d min : les autres recherches passent %d min",
      f.key or "?", lab.tech, math.floor(Ia3.AUTO_STALL / 3600), math.floor(Ia3.AUTO_PAUSE / 3600)))
    lab.for_auto = nil
    lab.stalled = true
  end
  if st.auto_pause and tick and tick < st.auto_pause then wanted = nil end
  if lab and lab.tech and not done[lab.tech] and not lab.stalled then
    local spec = c.techs[lab.tech]
    if spec then
      local ok = A.level_status(book, spec.ing, obtainable)
      if ok then return lab.tech, true, {}, lab.palier, lab.for_auto end
    end
  end
  -- Chaînes vers les packs que la force ne sait pas encore fabriquer : les prérequis manquants d'une technologie qui
  -- débloque un pack héritent de sa valeur (divisée par la longueur de la chaîne), si toute la chaîne est payable avec
  -- le livre COMPLET (règle H8 : une chaîne qui touche une matière sans source n'est pas suivie).
  local chain = {}
  local auto_chain = {} -- lot IA3-e : technologies de la chaîne d'un objet voulu par l'automatisation
  local pack_near = {}  -- lot IA3-e : technologies d'une chaîne COURTE (3 au plus) vers un pack nouveau (palier suivant)
  for _, name in ipairs(c.names) do
    local spec = c.techs[name]
    if spec and not done[name] then
      local opens, for_auto, for_pack = false, false, false
      for _, r in ipairs(spec.unlocks) do
        for _, p in ipairs(c.products[r] or {}) do
          if c.packs[p] then opens, for_pack = true, true end
          if wanted and wanted[p] then opens, for_auto = true, true end
        end
      end
      if opens then
        local seen, list, ok = {}, {}, true
        local function walk(n)
          if seen[n] or done[n] or not ok then return end
          seen[n] = true
          local s2 = c.techs[n]
          if not s2 then ok = false return end
          for _, pre in ipairs(s2.pre) do walk(pre) end
          list[#list + 1] = n
          -- Payabilité avec le livre COMPLET : tirée des seuls prototypes, gardée dans le catalogue (cache local).
          local pay = c.full_pay[n]
          if pay == nil then
            pay = A.level_status(c.full, s2.ing, obtainable) and true or false
            c.full_pay[n] = pay
          end
          if not pay then ok = false end
        end
        walk(name)
        if ok and #list > 0 then
          local share = math.floor(100 / #list)
          for _, n in ipairs(list) do chain[n] = math.max(chain[n] or 0, share) end
          if for_auto then for _, n in ipairs(list) do auto_chain[n] = true end end
          if for_pack and #list <= 3 then for _, n in ipairs(list) do pack_near[n] = true end end
        end
      end
    end
  end
  -- Lot IA3-e (critère K1, e11-usine graine 20261020, scarlet) : packs déjà consommés par une technologie faite ; la
  -- PREMIÈRE technologie qui consomme un pack nouveau le fait fabriquer (palier) : elle passe devant la chaîne de
  -- l'automatisation comme la chaîne courte d'un pack.
  local used_pack = {}
  if wanted then
    for _, name in ipairs(c.names) do
      local spec = c.techs[name]
      if spec and done[name] then
        for _, ing in ipairs(spec.ing) do used_pack[ing[1]] = true end
      end
    end
  end
  local best, best_score, best_palier = nil, nil, false
  local auto_best, auto_cost = nil, nil
  local pack_best, pack_cost = nil, nil
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
          local v, palier = tech_value(c, spec, w, chain[name], wanted)
          local cost = 0
          for _, ing in ipairs(spec.ing) do cost = cost + ing[2] * spec.count end
          local score = math.floor(v * 1000 / (cost + 10))
          if v > 0 and (not best_score or score > best_score) then best, best_score, best_palier = name, score, palier end
          if auto_chain[name] and (not auto_cost or cost < auto_cost) then auto_best, auto_cost = name, cost end
          -- garde de K1 : une technologie qui ouvre un PACK (palier), prête et payable, passe devant la chaîne
          local opens_pack = false
          for _, r in ipairs(spec.unlocks) do
            for _, p in ipairs(c.products[r] or {}) do if c.packs[p] then opens_pack = true end end
          end
          -- critère K1 (moteur réel, e10-usine graine 271828182 : militaire à 22,9 min contre 11,9 au témoin main 0.5.0,
          -- palier 3 à 57-58 min contre 18,7-18,8) : la chaîne COURTE d'un pack nouveau passe aussi devant
          local first_use = false
          if wanted then
            for _, ing in ipairs(spec.ing) do if c.packs[ing[1]] and not used_pack[ing[1]] then first_use = true end end
          end
          if (opens_pack or pack_near[name] or first_use) and (not pack_cost or cost < pack_cost) then pack_best, pack_cost = name, cost end
        else
          for _, k in ipairs(causes) do blocked_causes[k] = true end
        end
      end
    end
  end
  -- Lot IA3-e (H2, le goulot d'abord, appliqué à la recherche) : un objet que l'automatisation attend (poteau moyen d'une
  -- fonderie électrique) passe devant les autres recherches : la moins chère de sa chaîne, prête et payable. Moteur réel,
  -- e1-usine (27/10) : sans cette règle, « electronics » (27 unités) ne partait qu'à 38 min, après des recherches peu
  -- chères mais sans usage immédiat (military-2, defender), et le poteau moyen à 45-49 min (2 factions sur 4 en 90 min).
  if auto_best and pack_best then return pack_best, true, {}, true end
  if auto_best then return auto_best, true, {}, true, true end
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
  if #labs >= want then return 0 end
  -- Lot SCALE (correction après revue) : places en rangées depuis l'emprise du laboratoire (T.hq_rows.lab), recalées sur
  -- la grille et vérifiées avant la pose (script/ai3/places_qg.lua).
  return PlacesQG.place(f.hq.surface, lab.entity, f.force, f.hq_pos, T.hq_rows.lab, Pl.need(0, want, T.hq_rows_slack),
    want - #labs, function(pos)
      if f.hq.get_item_count(lab.item) < 1 then return nil end
      local e = f.hq.surface.create_entity({ name = lab.entity, position = pos, force = f.force })
      if not e then return false end
      f.hq.remove_item({ name = lab.item, count = 1 })
      st.labs[#st.labs + 1] = e
      return true
    end)
end

--- Recherche d'une faction à cette pensée : choix, laboratoires, avancement. Renvoie l'information pour la pensée pure.
local function research_step(f, st, book, w, tick, view)
  local force = game.forces[f.force]
  if not force then return nil end
  local c = catalogue()
  refresh_techs(force, st, c)
  -- Lot IA-G : le cerveau général choisit sur le graphe des prototypes (shared/ai3/general.lua) ; l'ancien choix reste
  -- le repli (General.ENABLED = false). Lot IA3-e : les objets que l'automatisation attend (Auto.wanted : nil réglage
  -- fo-war-ia3e éteint) sont le dernier argument du cerveau général (V_WANTED et chaîne vers l'objet voulu d'IA-G).
  local tech, payable, causes, palier, for_auto
  if General.on() then
    -- Lot CAPITAL : les objets qu'une amélioration de valeur attend sans savoir les obtenir (H8) s'ajoutent aux objets
    -- voulus : la technologie qui les débloque prend de la valeur (H9), sans aucun nom écrit. (Fusion de l'intégrateur :
    -- le 5e retour for_auto du lot AUTO est gardé ; réglages éteints, l'appel est celui d'AUTO.)
    local wanted = Auto.wanted(f)
    local cw = Capital.wanted(f)
    if cw and next(cw) ~= nil then
      local m = {}
      for _, k in ipairs(sorted_keys(wanted)) do m[k] = wanted[k] end
      for _, k in ipairs(sorted_keys(cw)) do m[k] = true end
      wanted = m
    end
    tech, payable, causes, palier, for_auto = General.choose_tech(f, force, st, book, w, tick, view, wanted)
  else
    tech, payable, causes, palier, for_auto = choose_tech(f, force, st, c, book, w, tick)
  end
  local info = { tech = tech, payable = payable, causes = causes, palier = palier, packs = {}, for_auto = for_auto or nil }
  if not tech then
    info.tech = "?"
    return info
  end
  local spec = c.techs[tech]
  st.lab = st.lab or {}
  local lab = st.lab
  if lab.tech ~= tech then
    if force.add_research(tech) then
      st.lab = { tech = tech, units = 0, paid = 0, last = tick, palier = palier, started = tick, for_auto = for_auto or nil }
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
  -- Lot SCALE : bornes et fenêtre selon l'effectif et les bras libres (Br.labs_max, Br.lab_window).
  local spare_hands = General.spare_hands(f, view, tick)
  local window = Br.lab_window(Ia3.LAB_WINDOW_S, spare_hands)
  local want = math.min(Br.labs_max(view.workers, Ia3.LABS_MAX), math.max(1, math.ceil(secs / window)))
  -- Lot CAPIB : sous la capitalisation, ses ordres « labos » fixent le nombre visé (plus de plafond Ia3.LABS_MAX ni
  -- Br.labs_max) ; le petit nombre d'avant (au plus Ia3.LABS_MAX, fenêtre de recherche) reste un plancher.
  local capi_labs = Capi.labs_want(f)
  if capi_labs then want = math.max(capi_labs, math.min(Ia3.LABS_MAX, math.max(1, math.ceil(secs / Ia3.LAB_WINDOW_S)))) end
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
      lab.paid_tick = tick -- lot IA3-e : dernière unité payée (garde de K1)
    end
    lab.units = math.min(target, lab.paid)
    if lab.units >= spec.count then
      force.research_progress = 1
      st.techs[tech] = true
      log(string.format("[FO-IA3C] %s : recherche '%s' terminee a %.1f min (laboratoire du QG, %d labo(s))", f.key, tech,
        minutes(f, tick), #labs))
      st.lab = { last = tick }
      f.tech = math.max(f.tech or 0, packs_researched(st, c))
      return info
    end
    force.research_progress = lab.units / spec.count
  end
  -- Packs encore à fabriquer pour la technologie en cours (net du coffre et des fabrications en cours), plus une RÉSERVE
  -- de Ia3.PACK_RESERVE packs de chaque sorte que la force sait faire et PAYER (un joueur garde quelques packs de chaque
  -- couleur pour les recherches suivantes : la file des laboratoires ne s'arrête pas à chaque technologie ; jamais un
  -- pack impayable, K6).
  local units_left = math.ceil(spec.count - lab.paid)
  local want = {}
  for _, ing in ipairs(spec.ing) do want[ing[1]] = units_left * ing[2] end
  -- Lot IA-G : les packs de la technologie EN COURS (« maintenant ») sont séparés de la réserve et des packs d'avance :
  -- seuls les premiers disent si la recherche est peu chère, et seuls les seconds respectent le plancher de la garde de
  -- l'économie (moteur réel, banc g3, graine 271828182 : « automation », 1 pack rouge, a attendu de 1,4 à 20,1 min chez
  -- Ambre : la réserve de 10 packs verts rendait la recherche « chère », le plancher de fer bloquait le pack, et l'armée,
  -- servie ensuite sans plancher, prenait le fer).
  local now = {}
  for _, ing in ipairs(spec.ing) do now[ing[1]] = units_left * ing[2] end
  for _, pack in ipairs(c.pack_list) do
    -- Lot IA-G : payable au sens du graphe (ressources connues, exécutants) ; repli : la règle d'IA3-a.
    local ok = nil
    if General.on() then ok = General.feasible(f, pack) end
    if ok == nil then ok = A.level_status(book, { { pack, 1 } }, obtainable) and true or false end
    if book:handcraftable(pack) and ok then
      want[pack] = math.max(want[pack] or 0, Ia3.PACK_RESERVE)
    end
  end
  -- Lot IA-G (bras libres) : les packs des recherches SUIVANTES, d'avance, quand des PNJ sont sans tâche.
  if General.on() then
    for _, it in ipairs(General.lookahead(f, st, view, tick)) do
      if book:handcraftable(it[1]) then want[it[1]] = (want[it[1]] or 0) + it[2] end
    end
  end
  info.packs_ahead = {}
  for _, pack in ipairs(sorted_keys(want)) do
    local have = (view.stock[pack] or 0) + ((view.incoming or {})[pack] or 0)
    local need = want[pack] - have
    if need > 0 then
      local need_now = math.max(0, (now[pack] or 0) - have)
      local n_now = math.min(Ia3.PACK_BATCH, need_now)
      if n_now > 0 then info.packs[#info.packs + 1] = { pack, n_now } end
      local n_ahead = math.min(Ia3.PACK_BATCH, need) - n_now
      if n_ahead > 0 then info.packs_ahead[#info.packs_ahead + 1] = { pack, n_ahead } end
    end
  end
  -- Lot IA-V2 : fer encore à dépenser pour cette recherche (packs à fabriquer, laboratoires à fabriquer), plan du livre.
  -- Lot IA-G : la matière de la garde est le produit de la ressource la PLUS DEMANDÉE (ressources clés déduites du
  -- dépliage ; le fer sur les données vanilla), plus le fer écrit à la main.
  local list = {}
  for _, it in ipairs(info.packs) do list[#list + 1] = it end
  if info.lab_item and (info.labs_craft or 0) > 0 then list[#list + 1] = { info.lab_item, info.labs_craft } end
  local raw = #list > 0 and book:raw_cost(list) or {}
  info.iron_cost = math.ceil(raw[T.outposts[key_of(f).top].product] or 0)
  return info
end

---------------------------------------------------------------------------------------------------
-- Gisements atteignables (minage à la main) : rayon du plus proche, relu toutes les REACH_EVERY pensées
---------------------------------------------------------------------------------------------------
-- Lot IA-V2 (fusion d'IA3-c et d'IA3-f) : crochet posé par script/ai3/exploration.lua quand le brouillard est actif :
-- gisements CONNUS d'une ressource (carte de connaissance), du plus proche au plus lointain ({ distance, ... }). Sans
-- crochet (brouillard coupé, témoins « avant ») : le rayon se lit sur la carte entière, comme IA3-c seul.
Ia3.known_deposits = nil
Ia3.home_known = nil -- crochet d'IA3-f : abords du QG vus (aucune exploration demandée avant ; nil sans brouillard)
Ia3.REACH_SEEN = 96 -- au-delà, sous brouillard, seulement un gisement CONNU (le PNJ y va par Worker.far_mine)

Ia3.REACH_EVERY_SHORT = 1 -- … à chaque pensée tant qu'une ressource n'est ni à portée ni connue (lot IA-V2 : à 2, la 2e pensée
                          -- lisait encore le cache de la 1re, carte pas ouverte : exploration du fer demandée à 0,1 min)

local function reach_of(f, st, tick)
  st.reach_n = (st.reach_n or 0) - 1
  if st.reach and st.reach_n > 0 then return st.reach, st.known or {} end
  st.reach_n = Ia3.REACH_EVERY
  local out, known = {}, {}
  local surface = f.hq.surface
  for _, res in ipairs(sorted_keys(MINABLE)) do
    -- Lot IA-V2 : gisement CONNU de l'équipe (carte d'IA3-f), même hors de portée de la main : la ressource n'est pas
    -- « à explorer » (moteur réel, ia3c-dc-apres, 27/10 : exploration du fer demandée à 0,1 min, gisement vu à 127
    -- tuiles mais son site pas encore retenu par la prospection).
    local kd = Ia3.known_deposits and Ia3.known_deposits(f, res, tick) or nil
    if kd and kd[1] then known[res] = true end
    for _, r in ipairs(Ia3.REACH_RADII) do
      -- Sous brouillard (constat du DC : « ils regardent même pas autour d'eux », critère A6) : au-delà des abords du
      -- QG, le minage à la main ne vise qu'un gisement que l'équipe a VU ; la tâche garde le rayon des abords et
      -- l'ouvrier va au gisement connu et sûr le plus proche (Worker.far_mine, lot IA3-f), sinon il demande une
      -- exploration. Avant cette fusion, le rayon allait jusqu'à 250 tuiles sur la carte entière. Le crochet rend nil
      -- quand le brouillard est coupé (témoins) : lecture de la carte entière, comme avant.
      local d = r > Ia3.REACH_SEEN and Ia3.known_deposits and Ia3.known_deposits(f, res, tick) or nil
      if d ~= nil then
        if d[1] and d[1].distance <= Ia3.REACH_RADII[#Ia3.REACH_RADII] then out[res] = Ia3.REACH_SEEN end
        break
      end
      if surface.count_entities_filtered({ position = f.hq_pos, radius = r, name = res, limit = 1 }) > 0 then
        out[res] = r
        break
      end
    end
    if out[res] then known[res] = true end
    if not known[res] then st.reach_n = math.min(st.reach_n, Ia3.REACH_EVERY_SHORT) end
  end
  st.reach, st.known = out, known
  return out, known
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
  -- Lot IA-G : gisements relus AVANT la recherche (le cerveau général en a besoin dès la première pensée).
  Profiler.fstart("ia3:reach")
  local reach, known = reach_of(f, st, tick)
  Profiler.fstop("ia3:reach")
  local research = nil
  Profiler.fstart("ia3:research_step")
  if not f.is_player then research = research_step(f, st, book, w, tick, view) end
  Profiler.fstop("ia3:research_step")
  Profiler.stop("ia3:research")
  -- Tâches de minage déjà prises, par ressource.
  local mines_open = {}
  for _, tk in ipairs(Board.get(f).list or {}) do
    if tk.worker and tk.kind == "mine" and tk.ia3 then mines_open[tk.resource] = (mines_open[tk.resource] or 0) + 1 end
  end
  -- Plancher de fer des packs (garde de l'économie, revue B3) : fer d'un avant-poste de fer tant que « fer II » manque.
  -- Lot IA-G : la matière gardée est le produit de la ressource la PLUS DEMANDÉE par les buts (ressources clés déduites
  -- du dépliage, General.key ; repli : celles de l'échelle), et le plancher = ce que coûte en cette matière l'avant-poste
  -- de cette ressource (livre de recettes). Sur les données vanilla : le fer, comme avant.
  local key = key_of(f)
  local floor_item = T.outposts[key.top].product
  local iron_floor = 0
  if not st.iron2_done and not st.economy_ok then -- lot IA-V2 : plancher levé aussi quand l'économie couvre le besoin
    local raw = book:raw_cost(Planner.outpost_items(key.top))
    iron_floor = math.ceil(raw[floor_item] or 0)
  end
  local army_target = 0
  local spare_hands = General.spare_hands(f, view, tick) -- lot SCALE : bras libres durables (0 pour votre équipe)
  if not f.is_player then
    local share = T.army_share[view.personality] or 0.6
    army_target = math.floor((view.soldiers_max or 0) * share)
    -- Lot SCALE (armée selon le caractère) : une faction agressive aux bras libres arme d'avance, quand sa matière clé ne
    -- manque pas (shared/ai3/bras.lua, Br.army ; jamais au-delà du plafond de soldats).
    local key_short = ((st.short or {})[floor_item] or 0) > 0
    army_target = Br.army(army_target, view.soldiers_max, (f.traits or {}).agressivite, spare_hands, key_short)
  end
  -- En guerre : déclarée au joueur (PvP) ; la posture guerrière du chef passe déjà par les poids (B.weights).
  local at_war = (f.pvp and f.pvp.declared) or false
  local home = Ia3.home_known and Ia3.home_known(f)
  local auto = Auto.think(f, view, book, tick, research) -- lot IA3-e : modules demandés, leur état (nil : éteint)
  -- Lot CAPIB : la capitalisation (une étape par pensée, décision une fois par minute) ; nil réglage éteint.
  local capi = nil
  if not f.is_player then
    Profiler.fstart("ia3:capi")
    capi = Capi.think(f, view, book, tick, research, w)
    Profiler.fstop("ia3:capi")
  end
  local ctx = { tick = tick, is_player = f.is_player or false, weights = w, research = research,
    reach = reach, known = known, mines_open = mines_open, iron_floor = iron_floor, floor_item = floor_item,
    army_target = army_target,
    at_war = at_war and true or false, home_known = home ~= false,
    -- Lot IA-G : ressources clés déduites du dépliage (factions) ; nil : repli (votre équipe).
    key = (not f.is_player) and General.on() and General.key(f) or nil,
    idle_grow = General.idle_grow(f, view, tick),
    spare = spare_hands > 0 and spare_hands or nil, -- lot SCALE : taille des vagues d'extraction d'avance
    auto = auto,
    -- Lot CAPITAL : but « amélioration » (niveau d'un bâtiment, pose ou passage du centre), factions seulement.
    capital = (not f.is_player) and Capital.goal(f, view, book, tick, w) or nil,
    capi = capi } -- lot CAPIB : buts de fond de la capitalisation (nil : éteinte)
  Profiler.start("ia3:think")
  local plan = C.think(view, book, st, ctx)
  Profiler.stop("ia3:think")
  -- Lot IA-G : une ressource INCONNUE qui bloque la recherche de valeur est à explorer (après le regard des abords).
  if not f.is_player and General.on() and home ~= false then
    for _, res in ipairs(sorted_keys(General.explore(f))) do
      plan.ia3.explore[res] = math.max(plan.ia3.explore[res] or 0, General.explore(f)[res])
    end
  end
  -- « Fer II » (critère K12) : même ligne que l'ancien cerveau. Lot IA-G : deux capacités de la ressource la plus
  -- demandée et deux du combustible (ressources clés déduites ; le fer et le charbon sur les données vanilla).
  if not st.iron2_done then
    local cap = { [key.top] = 0, [key.fuel] = 0 }
    for _, o in ipairs(view.outposts or {}) do
      if cap[o.kind] then cap[o.kind] = cap[o.kind] + o.drills / T.outposts[o.kind].drills end
    end
    if cap[key.top] >= 1.5 and cap[key.fuel] >= 1.5 then
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
-- Lot IA3-e : minerai -> plaque fondue (minage de fond d'une plaque couverte).
local PLATE_OF_RES_IA3E = {}
for _, kind in ipairs(T.OUTPOST_ORDER) do
  local spec = T.outposts[kind]
  if T.smelter_inputs[spec.product] then PLATE_OF_RES_IA3E[spec.resource] = spec.product end
end

function Ia3.after_poles(f, tick)
  local st = f.team.ia3
  local sat = st and st.saturated
  -- Lot IA3-e : le fond (minage, tournées) d'une matière COUVERTE par un module fini est retiré, qu'une autre matière
  -- manque ou non (le module livre ce flux ; critère K7).
  local cov = st and st.covered or {}
  if (not sat or next(sat) == nil) and next(cov) == nil then return 0 end
  -- Lot IA-V2 : seulement si une autre matière manque (shared/ai3/cerveau.lua, st.other_short ; critère A5).
  if st.other_short == false then sat = {} end
  if next(sat) == nil and next(cov) == nil then return 0 end
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
      local covered = item and (cov[item] or (tk.kind == "mine" and cov[PLATE_OF_RES_IA3E[item] or ""])) or false
      if item and (sat[item] or covered) then dropped = dropped + 1 else keep[#keep + 1] = tk end
    end
  end
  if dropped > 0 then
    Board.sync(f, keep, tick)
    st.fond_dropped = (st.fond_dropped or 0) + dropped
  end
  return dropped
end

--- Lot CAPITAL : décisions immédiates sur le stock libre (script/team/team.lua) : paie l'amélioration prête.
function Ia3.capital_pay(f, surface, tick, plan, stock)
  if f.is_player then return 0 end
  return Capital.pay(f, surface, tick, plan, stock)
end

--- Demandes d'exploration (ressource -> priorité) : pour le lot IA3-f (carte de connaissance, éclaireurs).
function Ia3.explore_requests(f)
  local st = f.team and f.team.ia3
  return st and st.explore or {}
end

--- Interface distante de LECTURE (bancs) : état du cerveau d'une équipe (« player » ou clé de faction).
local function team_of(key)
  if key == "player" then return State.faction("player") end
  local war = State.war()
  for _, id in ipairs(sorted_keys(war and war.factions)) do
    local f = war.factions[id]
    if f.key == key then return f end
  end
  return nil
end

remote.add_interface("fo-ia3c", {
  status = function(key)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    local t = f.team
    local st = t.ia3
    local out = { ia3c = t.ia3c == true, outposts = {}, projects = {}, taken = 0, saturated = {}, explore = {},
      paliers = {}, labs = 0, tech = f.tech or 0,
      -- Lot IA-V2 : marché et registre d'IA3-b (figés par équipe), registre jamais au-delà du coffre (R.check).
      marche = t.marche, reg_ok = (not t.reg) or (R.check(t.reg) and true or false) }
    for _, oid in ipairs(sorted_keys(f.outposts)) do
      local k = f.outposts[oid].kind
      out.outposts[k] = (out.outposts[k] or 0) + 1
    end
    for k, v in pairs((t.ia3m and t.ia3m.paliers) or {}) do out.paliers[k] = v end
    if st then
      local taken = {}
      for _, tk in ipairs(Board.get(f).list or {}) do if tk.worker and tk.ia3 then taken[tk.ia3] = true end end
      for _, p in ipairs(st.projects or {}) do
        out.projects[#out.projects + 1] = { key = p.key, state = p.state, cause = p.cause, taken = taken[p.id] or false }
        if taken[p.id] then out.taken = out.taken + 1 end
      end
      out.saturated = sorted_keys(st.saturated)
      out.explore = sorted_keys(st.explore)
      out.fond_dropped = st.fond_dropped or 0
      out.lab = st.lab and st.lab.tech or nil
      for _, e in ipairs(st.labs or {}) do if e.valid then out.labs = out.labs + 1 end end
      out.K = st.last_plan and st.last_plan.K or 0
      out.active = st.last_plan and st.last_plan.active or 0
      out.migrated = st.migrated
      out.since = st.since
    end
    return out
  end,
})

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
    -- Lot IA-V2 : diagnostic de K5 (script/team/board.lua, Board.assign) : pensées de la minute avec un PNJ sans tâche
    -- ET des tâches libres ; PNJ sans tâche, tâches libres, tâches non prenables (matière réservée), en somme.
    local bd = Board.get(f)
    local dg = bd.diag or { n = 0, idle = 0, free = 0, blocked = 0 }
    bd.diag = nil
    log(string.format("[FO-IA3C] %s minute %d | actifs %d productifs %d pris %d bloques %d K %d | inactifs %d/%d | attente %d pensees, sans tache %d, libres %d, non prenables %d | sature [%s] | explore [%s] | fond retire %d | projets {%s}",
      f.key or "player", math.floor(minutes(f, tick) + 0.5), lp.active or 0, lp.productive or 0, n_taken, n_block, lp.K or 0,
      (t.scale and t.scale.last and t.scale.last.idle) or 0, f.engineers_count or 0, dg.n, dg.idle, dg.free, dg.blocked,
      table.concat(sat, " "), table.concat(exp, " "), st.fond_dropped or 0, table.concat(parts, " ")))
  end
end

return Ia3
