--[[
  Lot PETROLE (A9 « aller au pétrole, comme un joueur »), côté RUNTIME : relie l'exécutant générique des chaînes à
  fluides (shared/ai3/fluides.lua) au cerveau général (script/ai3/general.lua) et au plan directeur (script/team/build.lua).
  Réglage de carte fo-war-petrole, ÉTEINT par défaut (settings/petrole.lua) : éteint, rien de ce fichier ne change une
  décision (aucun exécutant déclaré, aucun site, aucune ressource connue en plus).

  Allumé, pour chaque FACTION :
    1. EXÉCUTANTS (Pet.add_executors, appelé par General.exec_opts) : le relevé des prototypes (boîtes à fluide, raccords
       par direction, emprises) donne l'extracteur de chaque ressource fluide, et les machines des recettes que la main ne
       sait pas faire (fluides, catégories hors de la main) ; la centrale du plan directeur (pompe de rive, chaudière,
       machine à vapeur : entités de son gabarit) fait l'électricité. Le pack chimique devient payable au sens du graphe
       (H8) dès que le pétrole est connu.
    2. RESSOURCES CONNUES (Pet.known, lu par General.state) : une ressource fluide dont la carte d'IA3-f connaît un
       gisement ; l'eau (ressource de la pompe) dès qu'une rive est à portée du QG. Le pétrole inconnu « rapporte »
       (Gen.resource_values) : le cerveau général le fait explorer.
    3. SITES (Pet.think, chaque minute) : les objets que la faction ne sait faire qu'avec une cellule de l'exécutant et que
       le dépliage de ses packs ouverts demande (plastique, soufre, moteurs…) deviennent une demande au plan directeur :
       un site au gisement du fluide qu'ils mangent (chevalets centrés sur les puits, raffinerie, usines chimiques, pompe
       de rive, tuyaux, quais, poteaux jusqu'au réseau), ou près du QG pour une cellule sans fluide extrait. Le chantier
       est celui d'IA1-d (réserve, défrichage, fantômes, ravivage par les PNJ) ; ses manques deviennent des projets du
       cerveau (comme un module de l'automatisation : A.goals) ; un site fini se nourrit depuis le coffre du QG.
  Une ligne [FO-PETROLE] par décision ; interface distante « fo-petrole » (bancs).
  Déterminisme : listes triées, aucun hasard, aucun temps mesuré ; relevé des prototypes en mémoire LOCALE (identique
  chez tous les pairs) ; global : nombres, chaînes, tables seulement.
]]

local Fl = require("shared.ai3.fluides")
local K = require("shared.ai3.catalogue")
local R = require("shared.ai3.reglages")
local A = require("shared.ai3.automatiser")
local D = require("shared.team.petrole_donnees")
local State = require("script.faction.state")
local Build = require("script.team.build")
local Profiler = require("script.core.profiler")

local Pet = {}

Pet.SETTING = "fo-war-petrole"
Pet.EVERY = 3600            -- ticks entre deux décisions
Pet.WATER_R = 160           -- une rive à moins de 160 tuiles du QG : l'eau est connue (la centrale s'y pose)
Pet.PACK_N = 10             -- packs dépliés pour trouver ce qu'il faut
Pet.FEED_STOCK = 20         -- objets gardés au coffre pour les quais d'un site fini
Pet.OUT_AT = 10             -- objets à rapporter d'une sortie (au lieu de 200)
Pet.WATER_SEARCH = { 24, 48, 96, 144, 200 }
Pet.BLOCK_NEAR = 40         -- rive à plus de 40 tuiles du gisement : les machines vont près de la rive…
Pet.BLOCK_OFF = 10          -- … à 10 tuiles d'elle, vers le gisement
Pet.PUMP_TRIES = 80
Pet.RETRY = 10 * 3600       -- un site refusé est revu 10 min plus tard
Pet.GAIN = 3                -- PNJ « libérés » (valeur du projet de chantier, comme un module de l'automatisation)

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

function Pet.on()
  local s = settings.global[Pet.SETTING]
  return s ~= nil and s.value == true
end

---------------------------------------------------------------------------------------------------
-- Relevé (mémoire LOCALE : prototypes seulement)
---------------------------------------------------------------------------------------------------
local REL = nil
local INFO = nil

local function size_of(p)
  local cb = get(p, "collision_box")
  if not cb then return 1, 1 end
  local w = math.max(1, math.ceil(cb.right_bottom.x - cb.left_top.x - 0.02))
  local h = math.max(1, math.ceil(cb.right_bottom.y - cb.left_top.y - 0.02))
  return w, h
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
    out[#out + 1] = { type = get(fb, "production_type") or "none", conns = conns }
  end
  return out
end

--- Relevé de l'exécutant depuis le relevé du catalogue `d` (General.dump()).
function Pet.releve(d)
  if REL then return REL end
  local rel = { entities = {}, recipes = d.recipes, resources = d.resources, hand = {} }
  for _, e in ipairs(d.entities) do
    local role = R.ENTITY_ROLE[e.type or ""]
    if role == "main" then for _, c in ipairs(e.crafting_categories or {}) do rel.hand[c] = true end end
    local p = game.entity_prototypes[e.name]
    if p then
      local w, h = size_of(p)
      if role == "pompe" then w, h = 1, 1 end -- elle déborde sur l'eau (comme BASE de shared/team/modules.lua)
      rel.entities[e.name] = { role = role, item = e.item, w = w, h = h, categories = e.crafting_categories,
        rescats = e.resource_categories, fluid = e.fluid, speed = e.speed, boxes = boxes_of(p),
        electric = e.energy == "electric" }
    end
  end
  local pieces = { D.PIPE, D.CHEST, D.ARM }
  for _, n in ipairs(D.POLES) do pieces[#pieces + 1] = n end
  for _, n in ipairs(pieces) do
    local p = game.entity_prototypes[n]
    if p and not rel.entities[n] then
      rel.entities[n] = { role = "piece", w = 1, h = 1, electric = get(p, "electric_energy_source_prototype") ~= nil }
    end
  end
  REL = rel
  return rel
end

--- Exécutants du lot ajoutés à `exec` (catalogue) : extracteurs, machines des cellules, entités de la centrale.
function Pet.add_executors(exec, d)
  local rel = Pet.releve(d)
  local add, info = Fl.executors(rel, exec)
  INFO = info
  for _, en in ipairs(sorted_keys(add)) do
    local v = add[en]
    if exec[en] ~= true then
      if v == true then exec[en] = true
      else
        if type(exec[en]) ~= "table" then exec[en] = {} end
        for _, rn in ipairs(sorted_keys(v)) do exec[en][rn] = true end
      end
    end
  end
  local t = A.template(A.PLANT.gen, A.PLANT.args)
  if t then for _, k in ipairs(sorted_keys(t.items)) do if exec[k] == nil then exec[k] = true end end end
  return exec
end

---------------------------------------------------------------------------------------------------
-- État
---------------------------------------------------------------------------------------------------
local function state_of(f)
  f.team.petrole = f.team.petrole or { v = 1, sites = {}, known = {}, next = 0, decisions = 0, logs = {}, refused = {} }
  return f.team.petrole
end

local function note(f, st, tick, txt)
  local line = string.format("[FO-PETROLE] %s : %s a %.1f min", f.key or "?", txt, minutes(f, tick))
  log(line)
  st.logs[#st.logs + 1] = line
  while #st.logs > 24 do table.remove(st.logs, 1) end
end

--- Ressources fluides connues de la faction (lu par General.state).
function Pet.known(f)
  local st = f and f.team and f.team.petrole
  return st and st.known or {}
end

local function pump_resources(c)
  local out = {}
  for _, res in ipairs(c.resource_list) do
    local r = c.resources[res]
    if r and r.category and c.g.by_rescat[r.category] then
      -- ressource d'une pompe de rive : catégorie de la pompe (pseudo-catégorie du catalogue)
      if r.category == K.PUMP then out[#out + 1] = res end
    end
  end
  return out
end

local function refresh_known(f, st, c, deposits, tick)
  local surface = f.hq.surface
  -- eau : une rive à portée du QG (une fois)
  if st.water == nil then
    local n = surface.count_tiles_filtered({ position = f.hq_pos, radius = Pet.WATER_R, collision_mask = "water-tile", limit = 1 })
    st.water = n > 0
  end
  if st.water then for _, res in ipairs(pump_resources(c)) do st.known[res] = true end end
  for _, fl in ipairs(sorted_keys(INFO and INFO.extract)) do
    if not st.known[fl] and deposits then
      local d = deposits(f, fl, tick)
      if d and d[1] then
        st.known[fl] = true
        note(f, st, tick, string.format("gisement de %s connu en (%d, %d), %d tuiles du QG", fl, d[1].x, d[1].y, d[1].distance or -1))
      end
    end
  end
end

---------------------------------------------------------------------------------------------------
-- Ce qu'il faut : objets des cellules dans le dépliage des packs ouverts
---------------------------------------------------------------------------------------------------
local function wanted_items(f, General, c)
  local out, seen = {}, {}
  if not INFO then return out end
  local made = {}
  for _, rn in ipairs(sorted_keys(INFO.recipes)) do
    for _, p in ipairs((c.g.recipes[rn] and c.g.recipes[rn].products) or {}) do
      if p.type ~= "fluid" then made[p.name] = true end
    end
  end
  -- packs OUVERTS seulement (une recette qui les produit est débloquée pour la force) : un joueur ne bâtit pas sa
  -- raffinerie pour un pack qu'il ne sait pas encore fabriquer (moteur réel, petrole-partie : site demandé à 2 min)
  local force = game.forces[f.force]
  local open = {}
  for _, rn in ipairs(sorted_keys(c.products)) do
    local fr = force and force.recipes[rn]
    if fr and fr.enabled then for _, p in ipairs(c.products[rn]) do open[p] = true end end
  end
  -- … ou le pack vers lequel la recherche EN COURS mène (la technologie choisie est celle qui l'ouvre, ou l'un de ses
  -- prérequis) : un joueur prépare l'usine du pack qu'il est en train de débloquer.
  local lab = f.team.ia3 and f.team.ia3.lab
  local cur = lab and lab.tech
  local heading = {}
  if cur and c.techs[cur] then
    for _, pack in ipairs(c.pack_list) do
      for _, rn in ipairs(sorted_keys(c.products)) do
        local makes = false
        for _, p in ipairs(c.products[rn]) do if p == pack then makes = true end end
        local u = makes and c.g.unlocked_by[rn]
        if u and c.techs[u] then
          local seen = {}
          local function walk(t)
            if seen[t] or heading[pack] then return end
            seen[t] = true
            if t == cur then heading[pack] = true return end
            for _, pre in ipairs((c.techs[t] or {}).prerequisites or {}) do walk(pre) end
          end
          walk(u)
        end
      end
    end
  end
  for _, pack in ipairs(c.pack_list) do
    if (open[pack] or heading[pack]) and General.feasible(f, pack) then
      local sum = General.summary_items(f, { { pack, Pet.PACK_N } })
      for _, it in ipairs(sorted_keys(sum and sum.produce)) do
        if made[it] and not seen[it] then seen[it] = true; out[#out + 1] = it end
      end
    end
  end
  return out
end

local function obtainable(f, name)
  local item = name
  local force = game.forces[f.force]
  if f.hq.get_item_count(item) > 0 then return true end
  local r = force and force.recipes[item]
  return r ~= nil and r.enabled
end

--- Machine posable d'une liste : la première dont l'équipe a l'objet ou la recette ouverte, sinon la première.
local function chooser(f)
  return function(list)
    for _, en in ipairs(list or {}) do
      local e = REL and REL.entities[en]
      if e and e.item and obtainable(f, e.item) then return en end
    end
    return list and list[1]
  end
end

---------------------------------------------------------------------------------------------------
-- Site : planification (crochet de Build, spec.site = "petrole")
---------------------------------------------------------------------------------------------------
local function nearest_network(f, surface, x, y, b)
  local best, bd
  for _, e in ipairs(surface.find_entities_filtered({ position = { x, y }, radius = Fl.POLE_LINE_MAX, type = "electric-pole", force = f.force })) do
    local d = (e.position.x - x) ^ 2 + (e.position.y - y) ^ 2
    if not bd or d < bd or (d == bd and (e.position.x < best.x or (e.position.x == best.x and e.position.y < best.y))) then
      best, bd = { x = e.position.x, y = e.position.y }, d
    end
  end
  if best then return best end
  -- poteaux PLANIFIÉS de la centrale (pas encore bâtis) : la ligne y viendra
  local pl = b.plant and b.projects[b.plant]
  for _, e in ipairs((pl and pl.ents) or {}) do
    if e.name:find("electric%-pole") then
      local d = (e.x - x) ^ 2 + (e.y - y) ^ 2
      if not bd or d < bd then best, bd = { x = e.x, y = e.y }, d end
    end
  end
  return best
end

local function pole_of(f, rel)
  for _, n in ipairs(D.POLES) do
    local p = game.entity_prototypes[n]
    if p and obtainable(f, n) then
      return { name = n, supply = get(p, "supply_area_distance") or 2.5, wire = get(p, "max_wire_distance") or 7.5 }
    end
  end
  local n = D.POLES[#D.POLES]
  local p = game.entity_prototypes[n]
  return p and { name = n, supply = get(p, "supply_area_distance") or 2.5, wire = get(p, "max_wire_distance") or 7.5 } or nil
end

local function pump_spots(surface, f, rel, origin, fluid)
  local pname
  for _, en in ipairs(sorted_keys(rel.entities)) do
    local e = rel.entities[en]
    if e.role == "pompe" and e.fluid == fluid and e.item then pname = en break end
  end
  if not pname then return {}, nil end
  local tiles = {}
  for _, r in ipairs(Pet.WATER_SEARCH) do
    tiles = surface.find_tiles_filtered({ position = { origin.x, origin.y }, radius = r, collision_mask = "water-tile", limit = 400 })
    if #tiles > 0 then break end
  end
  table.sort(tiles, function(a, b)
    local da = (a.position.x - origin.x) ^ 2 + (a.position.y - origin.y) ^ 2
    local db = (b.position.x - origin.x) ^ 2 + (b.position.y - origin.y) ^ 2
    if da ~= db then return da < db end
    if a.position.y ~= b.position.y then return a.position.y < b.position.y end
    return a.position.x < b.position.x
  end)
  local out, tries = {}, 0
  for _, t in ipairs(tiles) do
    local tx, ty = math.floor(t.position.x), math.floor(t.position.y)
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      local v = Fl.DV[d]
      local lx, ly = tx - v[1], ty - v[2] -- tuile de terre voisine, la pompe regarde l'eau
      tries = tries + 1
      if tries > Pet.PUMP_TRIES then return out, pname end
      for _, dir in ipairs({ 0, 2, 4, 6 }) do
        if surface.can_place_entity({ name = pname, position = { lx + 0.5, ly + 0.5 }, direction = dir, force = f.force }) then
          out[#out + 1] = { name = pname, x = lx + 0.5, y = ly + 0.5, dir = dir, fluid = fluid }
        end
      end
      if #out >= 4 then return out, pname end
    end
  end
  return out, pname
end

local function plan_site(f, surface, p, h)
  local b = f.build
  local spec = p.spec
  local rel = REL
  if not (rel and INFO) then return nil, "releve absent" end
  -- la centrale d'abord (elle amorce le réseau)
  if not b.plant then h.plant() return nil, "centrale demandee", true end
  local ch, why = Fl.chain(rel, INFO, spec.targets, { [spec.water or "?"] = spec.water and "pompe" or nil }, chooser(f))
  if not ch then return nil, why end
  local origin = { x = spec.x, y = spec.y }
  local wells = {}
  if spec.res then
    for _, e in ipairs(surface.find_entities_filtered({ position = { spec.x, spec.y }, radius = 24, name = spec.res })) do
      wells[#wells + 1] = { x = e.position.x, y = e.position.y }
    end
    if #wells == 0 then return nil, "aucun puits de " .. spec.res end
  end
  local pumps = {}
  local block = nil
  if spec.water then
    pumps = pump_spots(surface, f, rel, origin, spec.water)
    -- la rive est loin du gisement : les machines vont près de la rive, le brut y vient par un long tuyau (un joueur
    -- raffine là où il a l'eau quand le champ est sec)
    local pp = pumps[1]
    if pp then
      local dx, dy = origin.x - pp.x, origin.y - pp.y
      local d = math.sqrt(dx * dx + dy * dy)
      if d > Pet.BLOCK_NEAR then
        block = { x = math.floor(pp.x + dx * Pet.BLOCK_OFF / d) + 0.5, y = math.floor(pp.y + dy * Pet.BLOCK_OFF / d) + 0.5 }
      end
    end
  end
  local x0, y0, x1, y1 = origin.x - Fl.ROUTE_R - 4, origin.y - Fl.ROUTE_R - 4, origin.x + Fl.ROUTE_R + 4, origin.y + Fl.ROUTE_R + 4
  -- la rive la plus proche (la seule que l'implantation prendra) et la place des machines : le relevé couvre aussi le
  -- couloir jusqu'à elles
  for _, q in ipairs({ pumps[1], block }) do
    x0, y0 = math.min(x0, q.x - Fl.ROUTE_R / 2), math.min(y0, q.y - Fl.ROUTE_R / 2)
    x1, y1 = math.max(x1, q.x + Fl.ROUTE_R / 2), math.max(y1, q.y + Fl.ROUTE_R / 2)
  end
  local masks = h.read_masks(x0, y0, x1, y1)
  local net = nearest_network(f, surface, origin.x, origin.y, b)
  local pole = pole_of(f, rel)
  local function blocked(tx, ty)
    -- clé des tuiles du plan directeur (shared/team/plan.lua P.tkey : même formule que Fl.tkey)
    local k = Fl.tkey(tx, ty)
    if b.occ[k] then return true end
    return masks.water[k] or masks.blocked[k] or false
  end
  local req = { origin = origin, blocked = blocked, ents = rel.entities, chain = ch, wells = wells, pumps = pumps,
    extractor = spec.extractor, conduit = D.PIPE, chest = D.CHEST, arm = D.ARM, poles = pole, network = net, block = block }
  local lay, w2 = Fl.layout(req)
  if not lay then return nil, w2 end
  lay.masks = masks
  lay.out_at = Pet.OUT_AT
  lay.key = "petrole:" .. table.concat(spec.targets, "+")
  return lay
end

Build.SITES = Build.SITES or {}
Build.SITES.petrole = plan_site

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
local function site_for(st, key)
  for _, s in ipairs(st.sites) do if s.key == key then return s end end
  return nil
end

local function decide(f, st, General, deposits, tick)
  local c = General.catalogue()
  refresh_known(f, st, c, deposits, tick)
  local items = wanted_items(f, General, c)
  if #items == 0 then return end
  -- regroupement : par fluide EXTRAIT de la chaîne (un site au gisement), sinon un site près du QG
  local groups, order = {}, {}
  local water = nil
  for _, res in ipairs(pump_resources(c)) do if st.known[res] then water = res end end
  local force = game.forces[f.force]
  local locked = {}
  for _, it in ipairs(items) do
    local ch = Fl.chain(REL, INFO, { it }, water and { [water] = "pompe" } or {}, chooser(f))
    -- une recette de la chaîne encore verrouillée : le GROUPE attend (la machine posée ne pourrait pas la lancer, et un
    -- site bâti pour une partie des objets ne serait pas refait pour les autres)
    local lock = false
    if ch then
      for _, cell in ipairs(ch.cells) do
        local fr = force and force.recipes[cell.recipe]
        if not (fr and fr.enabled) then lock = true end
      end
    end
    if ch then
      local res = nil
      for _, fl in ipairs(sorted_keys(ch.sources)) do if ch.sources[fl] == "extract" then res = fl end end
      local g = res or "qg"
      if lock then locked[g] = true end
      if not groups[g] then groups[g] = { res = res, items = {}, water = nil }; order[#order + 1] = g end
      groups[g].items[#groups[g].items + 1] = it
      if ch.sources[water or "?"] == "pompe" then groups[g].water = water end
    end
  end
  table.sort(order)
  for _, g in ipairs(order) do
    local grp = groups[g]
    local s = site_for(st, g)
    local again = s and s.state == "refuse" and tick >= (s.retry or 0)
    if ((not s) or again) and not locked[g] then
      local x, y, ok = f.hq_pos.x, f.hq_pos.y, true
      local extractor
      if grp.res then
        local d = deposits and deposits(f, grp.res, tick)
        if d and d[1] then x, y = d[1].x, d[1].y else ok = false end
        extractor = INFO.extract[grp.res] and INFO.extract[grp.res][1]
      end
      if ok then
        if not f.build then Build.enable(f, { radius = 3 }) end
        local id = Build.request(f, { site = "petrole", targets = grp.items, res = grp.res, water = grp.water,
          extractor = extractor, x = x, y = y, prio = Build.PRIO, domain = "production" })
        if id then
          if s then s.id, s.state, s.items = id, "attente", grp.items else
            st.sites[#st.sites + 1] = { key = g, id = id, items = grp.items, state = "attente", res = grp.res, x = x, y = y }
          end
          st.decisions = st.decisions + 1
          note(f, st, tick, string.format("site '%s' demande (projet %d) en (%d, %d) pour [%s]%s%s", g, id, x, y,
            table.concat(grp.items, " "), grp.res and (", gisement de " .. grp.res) or ", pres du QG",
            grp.water and (", eau de " .. grp.water) or ""))
        end
      end
    end
  end
end

--- Pensée d'une faction (script/ai3/cerveau.lua, après Auto.think) : décisions, état des sites, et leurs projets rendus
--- au cerveau par le contexte de l'automatisation (A.goals : manques des chantiers, quais d'un site fini).
function Pet.think(f, view, book, tick, auto, General, deposits)
  if f.is_player or not Pet.on() or not (f.team and f.hq and f.hq.valid) then return auto end
  Profiler.start("petrole:think")
  local st = state_of(f)
  if tick >= (st.next or 0) then
    st.next = tick + Pet.EVERY
    decide(f, st, General, deposits, tick)
  end
  local mods, feeds = {}, {}
  local stock = view.stock or {}
  -- La centrale du plan directeur (demandée par un site électrique) est un projet du cerveau comme un site : ses manques
  -- (chaudière, machines à vapeur, pompe) deviennent des fabrications (même produit « centrale » que l'automatisation :
  -- A.goals n'en garde qu'un).
  local b = f.build
  if b and b.plant and #st.sites > 0 then
    local ps = Build.brief(f, b.plant)
    if ps and ps.state ~= "fini" and ps.state ~= "refuse" then
      mods[#mods + 1] = { product = "centrale", state = ps.state, missing = ps.missing or {}, reason = ps.reason, gain = Pet.GAIN }
    end
  end
  for _, s in ipairs(st.sites) do
    local br = Build.brief(f, s.id)
    if br then
      if br.state ~= s.state then
        if br.state == "refuse" or br.state == "fini" or br.state == "bloque" or br.state == "reserve" or br.state == "chantier" then
          note(f, st, tick, string.format("site '%s' (projet %d) : %s%s (%d/%d entites)", s.key, s.id, br.state,
            br.reason and (" (" .. br.reason .. ")") or "", br.built or 0, br.total or 0))
        end
        if br.state == "refuse" then s.retry = tick + Pet.RETRY end
        s.state = br.state
      end
      s.built, s.total, s.reason = br.built, br.total, br.reason
      if br.state ~= "fini" and br.state ~= "refuse" then
        mods[#mods + 1] = { product = "petrole:" .. s.key, state = br.state, missing = br.missing or {}, reason = br.reason, gain = Pet.GAIN }
      elseif br.state == "fini" then
        local items = {}
        for _, it in ipairs(br.quais or {}) do
          local have = stock[it] or 0
          local makeable = book and book.handcraftable and book:handcraftable(it)
          if makeable and have < Pet.FEED_STOCK then items[#items + 1] = { it, Pet.FEED_STOCK - have } end
        end
        if #items > 0 then feeds[#feeds + 1] = { product = "petrole:" .. s.key, id = s.id, items = items, gain = Pet.GAIN } end
      end
    end
  end
  Profiler.stop("petrole:think")
  if #mods == 0 and #feeds == 0 then return auto end
  auto = auto or { mods = {}, cap = {}, covered = {}, feeds = {} }
  auto.mods = auto.mods or {}
  auto.feeds = auto.feeds or {}
  for _, m in ipairs(mods) do auto.mods[#auto.mods + 1] = m end
  for _, fd in ipairs(feeds) do auto.feeds[#auto.feeds + 1] = fd end
  return auto
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  local war = State.war()
  for _, id in ipairs(sorted_keys(war and war.factions)) do
    local fx = war.factions[id]
    if fx.key == key then return fx end
  end
  return nil
end

remote.add_interface("fo-petrole", {
  status = function(key)
    local f = team_of(key)
    local st = f and f.team and f.team.petrole
    if not st then return nil end
    local sites = {}
    for i, s in ipairs(st.sites) do
      sites[i] = { key = s.key, id = s.id, state = s.state, items = s.items, built = s.built, total = s.total,
        reason = s.reason, x = s.x, y = s.y }
    end
    return { decisions = st.decisions, known = sorted_keys(st.known), sites = sites, logs = st.logs }
  end,
  on = function() return Pet.on() end,
})

return Pet
