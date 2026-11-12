--[[
  Lot PETROLE (A9 « aller au pétrole, comme un joueur »), côté RUNTIME : relie l'exécutant générique des chaînes à
  fluides (shared/ai3/fluides.lua) au cerveau général (script/ai3/general.lua) et au plan directeur (script/team/build.lua).
  Réglage de carte fo-war-petrole, ALLUMÉ par défaut (settings/petrole.lua:20) ; éteint, rien de ce fichier ne change une
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
local Col = require("shared.ai3.collecteur") -- lot PETROLE-RANGEE : collecteur d'un champ de puits (règle pure)
local Rb = require("shared.team.rangee_bus") -- règle COMMUNE de rangée extensible (propriétaire : lot MEGA-FONDERIE) : cible de la rangée et sa cause
local Rf = require("shared.ai3.rangee_fluides") -- lot PETROLE-RANGEE, étape 2 : rangée de modules sur bus (règle pure)
local Dg = require("shared.ai3.danger") -- carte du danger (lot IA3-k) : lue seulement
local State = require("script.faction.state")
local AdRt = require("script.ai3.anti_dispersion") -- lot IA-GARDE : garde anti-dispersion (shared/ai3/anti_dispersion.lua)
local Build = require("script.team.build")
local Board = require("script.team.board") -- (reprise 0.6.20 : chargé ici, plus par un require pendant un appel distant, F24)
local Gens = require("script.team.generateurs") -- lot X10-S4 : registre des génératrices (plus de recherche sur toute la surface)
local Profiler = require("script.core.profiler")
local Storage = require("script.core.storage")
local Events = require("script.core.events")

local Pet = {}

Pet.SETTING = "fo-war-petrole"
-- Décision Q20 du DC (31/10) : une sauvegarde garde l'ancienne valeur du réglage, on l'allume donc une fois, à la mise à jour
-- seulement (une partie neuve a déjà le défaut allumé) ; le joueur qui l'éteint ensuite reste maître.
local migrer_reglage = false
Storage.declare("petrole_allume", function()
  migrer_reglage = true
  return {}
end)
Events.on_init(function() migrer_reglage = false end)
Events.on_configuration_changed(function()
  if migrer_reglage then pcall(function() settings.global[Pet.SETTING] = { value = true } end) end
  migrer_reglage = false
end)
Pet.EVERY = 3600            -- ticks entre deux décisions
Pet.WHY_EVERY = 15 * 3600   -- une cause d'attente toujours vraie est redite toutes les 15 min (Fl.news)
Pet.WATER_R = 160           -- une rive à moins de 160 tuiles du QG : l'eau est connue (la centrale s'y pose)
Pet.PACK_N = 10             -- packs dépliés pour trouver ce qu'il faut
Pet.FEED_STOCK = 20         -- objets gardés au coffre pour les quais d'un site fini
Pet.OUT_AT = 10             -- objets à rapporter d'une sortie (au lieu de 200)
Pet.WATER_SEARCH = { 24, 48, 96, 144, 200 }
Pet.BLOCK_NEAR = 40         -- rive à plus de 40 tuiles du gisement : les machines vont près de la rive…
Pet.BLOCK_OFF = 10          -- … à 10 tuiles d'elle, vers le gisement
Pet.PUMP_TRIES = 160
Pet.DANGER_MIN = 400        -- danger exact d'une menace connue (shared/ai3/danger.lua) au-delà duquel ses abords sont interdits au plan
Pet.DANGER_PAD = 4          -- … rayon de la menace + marge d'exactitude + 4 tuiles
Pet.DUMP = true            -- diagnostic (allumé par les bancs : remote fo-petrole.dump) : relevé du terrain d'un site refusé au journal
Pet.POND = 6               -- côté de l'étang posé au gisement quand aucune rive n'est à portée (comme celui de la centrale, Build.POND)
Pet.POND_NEAR = 60         -- rive à plus de 60 tuiles du gisement : un étang est posé au gisement
Pet.PUMPS = 8               -- places de pompe essayées au plus (la plus proche d'abord)
Pet.PLAN_SLICE = 600          -- nœuds d'A* au plus par passage du plan d'un site (environ 5 à 10 ms ; un plan de 120 000 nœuds : 200 passages)
Pet.RETRY = 10 * 3600       -- un site refusé est revu 10 min plus tard
Pet.CLAIM_R = 48           -- un gisement est PRIS si le site d'une autre équipe (demandé ou bâti) est à moins de 48 tuiles de lui
Pet.BAD_R = 24             -- un gisement dont le site a été refusé est évité (le suivant est essayé) dans ce rayon
Pet.GAIN = 3                -- PNJ « libérés » (valeur du projet de chantier, comme un module de l'automatisation)
-- Lot PETROLE-RANGEE (directive du DC, 8/11 : « un joueur humain pose des chevalets sur l'intégralité des puits disponibles, les relie
-- entre eux, et fait sortir tout ce pétrole brut vers une ligne principale ») : un site FINI grandit par chantiers d'extension.
Pet.CHAMP_SETTING = "fo-war-petrole-champ" -- réglage de carte (settings/petrole_rangee.lua) ; absent = allumé
Pet.EXT_BATCH = 12          -- chevalets au plus par chantier d'extension (la réserve de matières et le plan restent bornés ; le suivant s'enchaîne)
Pet.FIELD_R = 96            -- rayon de recherche des puits autour du site (tuiles)
Pet.FIELD_GAP = 24          -- deux puits séparés de plus de 24 tuiles ne sont pas du même champ
Pet.EXT_MAX_WELLS = 80      -- puits d'un champ pris en compte au plus
Pet.EXT_CHECK = 10 * 3600   -- un champ tout équipé est revu toutes les 10 min
Pet.EXT_RETRY = 5 * 3600    -- une extension refusée est redemandée 5 min plus tard, avec un lot plus petit
Pet.EXT_FAILS = 4           -- refus de suite après lesquels le site n'essaie plus (la cause est au journal)
Pet.EXT_MARGIN = 14         -- tuiles relevées autour des puits et du réseau de brut
Pet.EXT_WINDOW = 200        -- côté du relevé au plus (le reste de la ligne principale est lu par carrés de 32 tuiles)
Pet.RG_FAILS = 3            -- refus de rangée de suite après lesquels le site n'essaie plus

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

--- Réglage fo-war-petrole-champ (défaut : allumé ; absent, moteur simulé ou mod d'avant : allumé comme le défaut).
function Pet.champ_on()
  local ok, v = pcall(function() return settings.global[Pet.CHAMP_SETTING].value end)
  if not ok then return true end
  return v ~= false
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

--- Relecture de la reprise sur 0.6.20 (30/10) : REL et INFO sont des caches LOCAUX (hors de global), remplis par le catalogue.
--- INFO dépend des exécutants déjà là (Fl.executors : done_by), donc de la variante du catalogue (fo-war-ia3e) : General.catalogue
--- le rend à chaque changement de variante (Pet.get_info / Pet.set_info). Après un chargement (ou pour un joueur qui rejoint), ils
--- sont vides jusqu'au premier catalogue : un plan de site GELÉ dans global reprenait alors avec REL nil (rel.entities : erreur
--- Lua), et l'hôte et le joueur qui rejoint ne voyaient pas le même INFO. Ils sont donc refaits à la demande, pareil partout.
function Pet.get_info() return INFO end
function Pet.set_info(i) INFO = i end

local function ensure_rel()
  if REL then return REL end
  local G = package.loaded["script.ai3.general"] -- (pas de require : module déjà chargé par cerveau.lua, cycle general -> petrole)
  if G and G.dump then Pet.releve(G.dump()) end
  return REL
end

--- INFO de la variante COURANTE du catalogue ; nil réglage éteint (jamais un INFO resté d'un autre état).
local function current_info()
  if not Pet.on() then return nil end
  local G = package.loaded["script.ai3.general"]
  if G and G.catalogue then G.catalogue() end
  return INFO
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

--- Lot BLOCAGE-LABOS : pourquoi le pack `pack` n'est pas fabricable cote petrole (journal [FO-LABO]) : etat et raison du site qui doit le
--- permettre (refuse, bloque, reserve…), ou « petrole eteint » ; nil si rien a dire. Lecture seule.
function Pet.reason_for(f, pack)
  if not Pet.on() then return "reglage petrole eteint" end
  local st = f and f.team and f.team.petrole
  if not st then return nil end
  local out = {}
  for _, s in ipairs(st.sites or {}) do
    if s.pack == pack then
      out[#out + 1] = string.format("site '%s' %s%s", tostring(s.key), tostring(s.state), s.reason and (" : " .. tostring(s.reason)) or "")
    end
  end
  if #out == 0 then return "aucun site petrole demande pour ce pack" end
  return table.concat(out, " ; ")
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
    -- Une FACTION a toujours de l'eau : le plan directeur pose un étang quand aucune rive ne tient sa centrale (Build make_pond)
    -- et le lot en pose un au gisement quand aucune rive n'est proche. Sans cela, les éclaireurs cherchaient de l'eau au lieu
    -- du pétrole (moteur simulé, ia3f_test) et, sans eau à 160 tuiles, le pack chimique restait impayable (moteur réel,
    -- etape1-guide 123456789). Votre équipe, elle, n'a que l'eau que vous lui laissez : une rive à portée du QG.
    if not f.is_player then
      st.water = true
    else
      local n = surface.count_tiles_filtered({ position = f.hq_pos, radius = Pet.WATER_R, collision_mask = "water-tile", limit = 1 })
      st.water = n > 0
    end
  end
  -- … ou l'étang que le plan directeur a posé pour la centrale (aucune rive ne la tenait : Build make_pond) : l'équipe a de
  -- l'eau (moteur réel, etape1-guide 123456789 : aucune eau à 160 tuiles, le pack chimique restait impayable, le pétrole « valait 0 »)
  if not st.water and f.build then
    local pl = f.build.plant and f.build.projects[f.build.plant]
    if f.build.pond or (pl and pl.state == "fini") then st.water = true end
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
  -- … et seulement ceux qu'AUCUNE autre recette ne fait à la main ou par un exécutant (INFO.other) : l'acier du four, que le four
  -- à arc fait aussi, n'attend pas la cellule du four à arc (moteur réel, petrole-refus : sa recette verrouillée retenait le pack)
  local made = {}
  for _, rn in ipairs(sorted_keys(INFO.recipes)) do
    for _, p in ipairs((c.g.recipes[rn] and c.g.recipes[rn].products) or {}) do
      if p.type ~= "fluid" and not (INFO.other and INFO.other[p.name]) then made[p.name] = true end
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
  -- diag : packs ouverts, ouverts mais impayables, payables sans objet de cellule (pour dire POURQUOI rien n'est demandé)
  local diag = { open = {}, unpayable = {}, bare = {} }
  for _, pack in ipairs(c.pack_list) do
    if open[pack] or heading[pack] then
      diag.open[#diag.open + 1] = pack
      if General.feasible(f, pack) then
        local sum = General.summary_items(f, { { pack, Pet.PACK_N } })
        local n0 = #out
        for _, it in ipairs(sorted_keys(sum and sum.produce)) do
          if made[it] and not seen[it] then seen[it] = pack; out[#out + 1] = it end
        end
        if #out == n0 then diag.bare[#diag.bare + 1] = pack end
      else
        diag.unpayable[#diag.unpayable + 1] = pack
      end
    end
  end
  return out, seen, diag
end

--- Lot PERF3 : recettes du catalogue qui produisent au moins un PACK, triées, avec ces packs dans leur ordre ({ rn, packs }) ;
--- gardées par catalogue (General.catalogue rend la même table tant que les réglages ne changent pas ; table locale, rebâtie après
--- un chargement : déduite des seuls prototypes, la même sur tous les clients). Pet.think les parcourait TOUTES (377 recettes : tri des
--- noms et deux appels au moteur par recette, à chaque pensée de faction) pour n'en garder que celles-ci.
local pack_rows_cat, pack_rows = nil, nil
local function pack_recipes(c)
  if pack_rows_cat ~= c then
    pack_rows = {}
    for _, rn in ipairs(sorted_keys(c.products)) do
      local pks = {}
      for _, pk in ipairs(c.products[rn]) do if c.packs[pk] then pks[#pks + 1] = pk end end
      if #pks > 0 then pack_rows[#pack_rows + 1] = { rn = rn, packs = pks } end
    end
    pack_rows_cat = c
  end
  return pack_rows
end
Pet.pack_recipes = pack_recipes -- (tests)

--- Objets produits par la force depuis le début (statistiques de production ; 0 si le moteur simulé n'en a pas).
local function produced(force, item)
  local ok, n = pcall(function() return force.item_production_statistics.get_input_count(item) end)
  return ok and n or 0
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
  -- Réseaux ALIMENTÉS : ceux d'une centrale (génératrice). Le poteau le plus proche peut être celui d'un
  -- avant-poste isolé : la ligne y arrivait sans courant (moteur réel, etape1-guide, 28/10 : site fini, « no_power »).
  local powered = Gens.networks(surface, f.force, "generator") -- lot X10-S4 : registre des génératrices
  local poles = surface.find_entities_filtered({ position = { x, y }, radius = Fl.POLE_LINE_MAX, type = "electric-pole", force = f.force })
  local best
  for pass = 1, 2 do -- 1 : poteaux d'un réseau alimenté ; 2 : n'importe lequel (aucune centrale vue)
    local bd
    for _, e in ipairs(poles) do
      if pass == 2 or (e.electric_network_id and powered[e.electric_network_id]) then
        local d = (e.position.x - x) ^ 2 + (e.position.y - y) ^ 2
        if not bd or d < bd or (d == bd and (e.position.x < best.x or (e.position.x == best.x and e.position.y < best.y))) then
          best, bd = { x = e.position.x, y = e.position.y, wire = get(e.prototype, "max_wire_distance") }, d
        end
      end
    end
    if best then return best end
  end
  -- poteaux PLANIFIÉS de la centrale (pas encore bâtis) : la ligne y viendra
  local bd
  local pl = b.plant and b.projects[b.plant]
  for _, e in ipairs((pl and pl.ents) or {}) do
    if e.name:find("electric%-pole") then
      local d = (e.x - x) ^ 2 + (e.y - y) ^ 2
      local pp = game.entity_prototypes[e.name]
      if not bd or d < bd then best, bd = { x = e.x, y = e.y, wire = pp and get(pp, "max_wire_distance") or nil }, d end
    end
  end
  return best
end
Pet._nearest_network = nearest_network -- (lot X10-S4) appel direct du micro-banc x10-s4-ombre (script/team/generateurs.lua) ; aucun autre usage

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
  local boxes = rel.entities[pname].boxes or {}
  local function wet(x, y)
    local tile = surface.get_tile(x, y)
    return tile and tile.valid and tile.collides_with("water-tile")
  end
  for _, t in ipairs(tiles) do
    local tx, ty = math.floor(t.position.x), math.floor(t.position.y)
    for _, d in ipairs({ 0, 2, 4, 6 }) do
      local v = Fl.DV[d]
      local lx, ly = tx - v[1], ty - v[2] -- tuile de terre voisine
      tries = tries + 1
      if tries > Pet.PUMP_TRIES then return out, pname end
      if not wet(lx, ly) then
        for _, dir in ipairs({ 0, 2, 4, 6 }) do
          -- direction lue au raccord du prototype : le raccord tombe sur la TERRE, l'opposé sur l'eau (moteur réel,
          -- petrole-site : can_place_entity par script admet les 4 directions, le raccord tombait dans l'eau)
          local pos = boxes[1] and boxes[1].conns[dir] and boxes[1].conns[dir][1]
          if pos then
            local cx, cy = math.floor(lx + 0.5 + pos[1] + 0.01), math.floor(ly + 0.5 + pos[2] + 0.01)
            local ox, oy = math.floor(lx + 0.5 - pos[1] + 0.01), math.floor(ly + 0.5 - pos[2] + 0.01)
            if not wet(cx, cy) and wet(ox, oy)
                and surface.can_place_entity({ name = pname, position = { lx + 0.5, ly + 0.5 }, direction = dir, force = f.force }) then
              out[#out + 1] = { name = pname, x = lx + 0.5, y = ly + 0.5, dir = dir, fluid = fluid }
            end
          end
        end
      end
      if #out >= Pet.PUMPS then return out, pname end
    end
  end
  return out, pname
end

--- Étang posé près du gisement quand aucune rive n'est à portée (la centrale en pose un de même, Build.POND) : un carré libre
--- de Pet.POND tuiles, hors ressource, cherché sur des anneaux autour de l'origine (ordre fixe). Rend vrai si posé.
--- Tuile d'eau qui donne le fluide `fluid` à la pompe de rive : la tuile de même nom que le fluide si elle en est une, sinon la
--- première (par nom) dont le prototype pompe ce fluide. nil si le jeu n'en a aucune.
local function pond_tile(fluid)
  local function is_water(p)
    local mask = get(p, "collision_mask") or {}
    return mask["water-tile"] == true
  end
  local same = game.tile_prototypes[fluid]
  if same and is_water(same) then return fluid end
  local names = {}
  for name, p in pairs(game.tile_prototypes) do
    if is_water(p) and get(p, "fluid") and get(get(p, "fluid"), "name") == fluid then names[#names + 1] = name end
  end
  table.sort(names)
  return names[1]
end

local function site_pond(f, surface, origin, h, fluid)
  local b = f.build
  local tile = pond_tile(fluid)
  if not tile then return false end
  local N = Pet.POND
  local x0, y0, x1, y1 = origin.x - 60, origin.y - 60, origin.x + 60, origin.y + 60
  local masks = h.read_masks(x0, y0, x1, y1)
  local sx, sy = Fl.pond_spot(origin, N, function(tx, ty)
    local k = Fl.tkey(tx, ty)
    return not (masks.water[k] or masks.blocked[k] or b.occ[k])
  end, function(x0, y0, x1, y1)
    return surface.count_entities_filtered({ area = { { x0, y0 }, { x1, y1 } }, type = "resource" }) == 0
  end)
  if not sx then return false end
  local tiles = {}
  for dx = 0, N - 1 do for dy = 0, N - 1 do tiles[#tiles + 1] = { name = tile, position = { sx + dx, sy + dy } } end end
  surface.set_tiles(tiles, true, true)
  log(string.format("[FO-PETROLE] %s : aucune rive a moins de %d tuiles du gisement : etang de %d x %d tuiles pose en (%d, %d)",
    f.key or "?", Pet.POND_NEAR, N, N, sx, sy))
  return true
end

--- Tuiles des abords des menaces connues de la faction (nids, vers, tourelles adverses, bandes vues : carte du danger d'IA3-k),
--- interdites au plan d'un site : les PNJ n'y vont pas (« attend (bloque) … danger », moteur réel, etape1-guide 271828182 : 11
--- poteaux de la ligne jusqu'au réseau, posés près d'un nid, ne furent jamais bâtis, le site restant à 117/128 de 60 à 89 min).
--- La ligne de poteaux et les tuyaux contournent ces tuiles. nil si rien n'est interdit.
local function danger_tiles(f, tick)
  local Cmp = package.loaded["script.ai3.comportement"]
  if not (Cmp and Cmp.team) then return nil end
  local t = Cmp.team(f)
  local map = t and t.map
  if not (map and map.threats and #map.threats > 0) then return nil end
  local discs = {}
  for _, th in ipairs(map.threats) do
    if Dg.danger_exact(map, th.x, th.y, tick) >= Pet.DANGER_MIN then
      discs[#discs + 1] = { x = th.x, y = th.y, r = th.r + Dg.EXACT_MARGIN + Pet.DANGER_PAD }
    end
  end
  return Fl.disc_tiles(discs)
end
Pet.danger_tiles = danger_tiles

local function freeze_site(f, surface, p, h)
  local b = f.build
  local spec = p.spec
  -- (relecture 0.6.20) réglage éteint : le site attend, au lieu de se figer sur un INFO resté d'un autre état
  if not Pet.on() then return nil, "reglage eteint", true end
  local info = current_info()
  local rel = ensure_rel()
  if not (rel and info) then return nil, "releve absent" end
  -- la centrale d'abord (elle amorce le réseau)
  if not b.plant then h.plant() return nil, "centrale demandee", true end
  local ch, why = Fl.chain(rel, info, spec.targets, { [spec.water or "?"] = spec.water and "pompe" or nil }, chooser(f))
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
    -- les machines se posent autour des puits équipés (les plus proches de l'origine) : la rive se juge depuis leur centre
    local sorted = {}
    for _, w in ipairs(wells) do sorted[#sorted + 1] = w end
    table.sort(sorted, function(a, b)
      local da, db = (a.x - origin.x) ^ 2 + (a.y - origin.y) ^ 2, (b.x - origin.x) ^ 2 + (b.y - origin.y) ^ 2
      if da ~= db then return da < db end
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    local hub = { x = origin.x, y = origin.y }
    local nh = math.min(#sorted, Fl.EXTRACTORS)
    if nh > 0 then
      hub = { x = 0, y = 0 }
      for i = 1, nh do hub.x, hub.y = hub.x + sorted[i].x / nh, hub.y + sorted[i].y / nh end
    end
    local near = pumps[1] and ((pumps[1].x - hub.x) ^ 2 + (pumps[1].y - hub.y) ^ 2) <= Pet.POND_NEAR ^ 2
    if not near and site_pond(f, surface, hub, h, spec.water) then pumps = pump_spots(surface, f, rel, hub, spec.water) end
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
  -- Le terrain, le danger et le réseau sont GELÉS ici (données seules, gardées dans le projet, donc dans global) : le plan est
  -- repris tranche après tranche (Fl.layout_step) et chaque reprise doit voir les mêmes réponses (lot PETROLE 2).
  local fz = {
    origin = origin, wells = wells, pumps = pumps, block = block, net = net, pole = pole, chain = ch,
    x0 = x0, y0 = y0, x1 = x1, y1 = y1,
    water = masks.water, blocked = masks.blocked, clear = masks.clear, extra = {}, danger = danger_tiles(f, game.tick), occ = {},
    targets = spec.targets,
  }
  for _, v in ipairs({ origin, wells, pumps, block or {}, net or {}, pole or {}, ch }) do
    if not Fl.is_plain(v) then return nil, "etat du plan non serialisable" end
  end
  return { jb = Fl.layout_new(), fz = fz, steps = 0 }
end

--- Une tranche du plan d'un site (Pet.PLAN_SLICE nœuds d'A* au plus) : (implantation), ou (nil, raison) refusé, ou (nil, raison,
--- "calcul") à reprendre au prochain passage. L'état est pj = { jb, fz } (voir freeze_site et Fl.layout_step).
local function step_site(f, surface, p, h, pj)
  local b = f.build
  local spec = p.spec
  local fz = pj.fz
  local origin, wells, pumps, block, net, pole = fz.origin, fz.wells, fz.pumps, fz.block, fz.net, fz.pole
  local ch = fz.chain
  local x0, y0, x1, y1 = fz.x0, fz.y0, fz.x1, fz.y1
  local danger = fz.danger
  local masks = { water = fz.water, blocked = fz.blocked, clear = fz.clear }
  masks.free = function(tx, ty)
    local k = Fl.tkey(tx, ty)
    return not masks.water[k] and not masks.blocked[k] and not b.occ[k]
  end
  local rel = ensure_rel() -- (relecture 0.6.20 : plan gelé repris après un chargement, avant tout catalogue)
  if not rel then return nil, "releve absent" end
  -- hors du relevé principal (ligne de poteaux jusqu'au réseau, qui peut traverser le QG) : relevés par carrés de 32
  -- tuiles, lus à la demande et gardés le temps du plan (moteur réel, petrole-partie 271828182 : un relais posé sur le
  -- QG de la faction, hors du relevé, chantier bloqué à 274 entités sur 287)
  local extra = fz.extra
  local function masks_at(tx, ty)
    if tx >= x0 and tx < x1 and ty >= y0 and ty < y1 then return masks end
    local cx, cy = math.floor(tx / 32), math.floor(ty / 32)
    local ck = cx * 65536 + cy
    local m = extra[ck]
    if not m then
      local r = h.read_masks(cx * 32, cy * 32, cx * 32 + 32, cy * 32 + 32)
      m = { water = r.water, blocked = r.blocked, clear = r.clear }
      extra[ck] = m
    end
    return m
  end
  local function blocked(tx, ty)
    -- clé des tuiles du plan directeur (shared/team/plan.lua P.tkey : même formule que Fl.tkey)
    local k = Fl.tkey(tx, ty)
    local o = fz.occ[k]
    if o == nil then o = b.occ[k] ~= nil; fz.occ[k] = o end
    if o then return true end
    if danger and danger[k] then return true end
    local m = masks_at(tx, ty)
    return m.water[k] or m.blocked[k] or false
  end
  local req = { origin = origin, blocked = blocked, ents = rel.entities, chain = ch, wells = wells, pumps = pumps,
    extractor = spec.extractor, conduit = D.PIPE, chest = D.CHEST, arm = D.ARM, poles = pole, network = net, block = block }
  -- rives candidates, de la plus proche à la plus lointaine : la première dont le tuyau se trace (une rive d'une tuile
  -- de terre peut avoir son raccord sur l'eau ; moteur réel, petrole-partie 271828182 : « tuyau de la pompe impossible »)
  -- toutes les rives candidates d'un coup : l'implantation choisit celle qui est la plus proche du consommateur du fluide
  -- (les machines étant posées) et en essaie une autre si son tuyau ne se trace pas (Fl.layout, retour en arrière)
  req.pumps = pumps
  local okc, status, lay, w2
  okc, status, lay = pcall(Fl.layout_step, req, pj.jb, Pet.PLAN_SLICE)
  pj.steps = pj.steps + 1
  if not okc then
    -- reprise incohérente (ne devrait jamais arriver : toutes les entrées sont gelées) : on repart de zéro, deux fois au plus
    log(string.format("[FO-PETROLE] %s : plan du site repris de zero (%s)", f.key or "?", tostring(status)))
    p.plan_job = nil
    p.plan_restarts = (p.plan_restarts or 0) + 1
    if p.plan_restarts > 2 then return nil, "plan incoherent" end
    return nil, "plan repris de zero", "calcul"
  end
  if status == "more" then return nil, "calcul du plan (" .. pj.jb.spent .. " noeuds)", "calcul" end
  p.plan_job = nil
  if status == "fail" then w2, lay = lay, nil end
  if not lay then
    -- Diagnostic (moteur réel, 28/10) : le relevé du terrain autour du site refusé, une fois par faction et par raison
    -- (. libre, # bloqué, ~ eau, O origine, W puits, P pompe, B bloc des machines, * tuile occupée par le plan directeur)
    local st = f.team.petrole
    st.dumped = st.dumped or {}
    local why = tostring(w2):sub(1, 24)
    if Pet.DUMP and not st.dumped[why] then
      st.dumped[why] = true
      local xa, xb, ya, yb = origin.x, origin.x, origin.y, origin.y
      for _, q in ipairs({ pumps[1] or origin, block or origin }) do
        xa, xb, ya, yb = math.min(xa, q.x), math.max(xb, q.x), math.min(ya, q.y), math.max(yb, q.y)
      end
      xa, xb, ya, yb = math.floor(xa) - 24, math.floor(xb) + 24, math.floor(ya) - 24, math.floor(yb) + 24
      if xb - xa > 110 then xb = xa + 110 end
      if yb - ya > 90 then yb = ya + 90 end
      local rows = {}
      for ty = ya, yb do
        local r = {}
        for tx = xa, xb do
          local k = Fl.tkey(tx, ty)
          local ch = "."
          if b.occ[k] then ch = "*" elseif masks.water[k] then ch = "~" elseif masks.blocked[k] then ch = "#" end
          for _, w in ipairs(wells) do if math.floor(w.x) == tx and math.floor(w.y) == ty then ch = "W" end end
          for _, q in ipairs(pumps) do if math.floor(q.x) == tx and math.floor(q.y) == ty then ch = "P" end end
          if block and math.floor(block.x) == tx and math.floor(block.y) == ty then ch = "B" end
          if math.floor(origin.x) == tx and math.floor(origin.y) == ty then ch = "O" end
          r[#r + 1] = ch
        end
        rows[#rows + 1] = table.concat(r)
      end
      log(string.format("[FO-PETROLE-CARTE] %s : %s ; fenetre x %d..%d y %d..%d\n%s", f.key or "?", tostring(w2), xa, xb, ya, yb,
        table.concat(rows, "\n")))
    end
    return nil, w2 .. (#pumps > 1 and (" (" .. #pumps .. " rives essayees)") or "")
  end
  lay.masks = masks
  log(string.format("[FO-PETROLE] %s : plan du site en %d tranche(s), %d noeuds d'A*", f.key or "?", pj.steps, pj.jb.spent))
  lay.out_at = Pet.OUT_AT
  lay.key = "petrole:" .. table.concat(spec.targets, "+")
  return lay
end

---------------------------------------------------------------------------------------------------
-- Extension d'un site FINI : tous les puits du champ (lot PETROLE-RANGEE)
---------------------------------------------------------------------------------------------------
--[[
  Un site fini n'a que Fl.EXTRACTORS chevalets (sa cellule de machines est fermée). Un joueur équipe TOUS les puits et fait sortir le brut
  par une ligne principale (directive du DC, 8/11). Chaîne : Pet.think (site fini) -> extend_site (cherche les puits du champ non
  équipés, lot de Pet.EXT_BATCH) -> Build.request (spec.ext = true, mêmes services que le site : réserve, défrichage, fantômes, ravivage)
  -> Build.SITES.petrole -> freeze_ext (réseau de brut du site, puits, terrain) -> step_ext (Fl.ext_step : collecteur droit, embranchements,
  ligne principale vers le brut du site, poteaux ; tranches de Pet.PLAN_SLICE nœuds) -> chantier. Journal : une ligne [FO-PETROLE] par
  demande, plan, fin, refus.
]]
local function ext_ents(b, ids)
  local ents = {}
  for _, id in ipairs(ids or {}) do
    local q = b.projects[id]
    if q then for _, e in ipairs(q.ents or {}) do ents[#ents + 1] = e end end
  end
  return ents
end

--- Les puits du champ du site `s` (ressource s.res) : { total, wells (non équipés), extractor } ou (nil, raison).
local function field_wells(f, surface, s, ids)
  local b = f.build
  local names = (INFO and INFO.extract and INFO.extract[s.res]) or {}
  local seeds, eq, extractor = {}, {}, nil
  for _, e in ipairs(ext_ents(b, ids)) do
    if e.role == "extracteur" then
      seeds[#seeds + 1] = { x = e.x, y = e.y }
      eq[#eq + 1] = { x = e.x, y = e.y }
      extractor = extractor or e.name
    end
  end
  if #seeds == 0 then return nil, "aucun chevalet au site de base" end
  local pts = {}
  for _, e in ipairs(surface.find_entities_filtered({ position = { s.x, s.y }, radius = Pet.FIELD_R, name = s.res })) do
    pts[#pts + 1] = { x = e.position.x, y = e.position.y, amount = get(e, "amount") }
  end
  local live = {}
  if #names > 0 then
    for _, e in ipairs(surface.find_entities_filtered({ position = { s.x, s.y }, radius = Pet.FIELD_R + 8, name = names })) do
      eq[#eq + 1] = { x = e.position.x, y = e.position.y }
      live[#live + 1] = { x = e.position.x, y = e.position.y }
    end
  end
  local cl = Col.cluster(pts, seeds, Pet.FIELD_GAP, Pet.EXT_MAX_WELLS)
  local wells = {}
  for _, w in ipairs(cl) do
    local taken = false
    for _, q in ipairs(eq) do
      if math.abs(q.x - w.x) <= 1.01 and math.abs(q.y - w.y) <= 1.01 then taken = true break end
    end
    if not taken then wells[#wells + 1] = w end
  end
  -- débit de brut des chevalets POSÉS (unités/s) : vitesse de minage / durée de minage × quantité du produit × rendement du puits
  -- (quantité restante / quantité normale), tout lu aux prototypes ; nil quand un prototype ne le dit pas
  local rate
  local rp = game.entity_prototypes[s.res]
  local ep = extractor and game.entity_prototypes[extractor]
  local mp = rp and get(rp, "mineable_properties")
  local prod = mp and mp.products and mp.products[1]
  if mp and ep and prod and #live > 0 then
    local amt = prod.amount or (((prod.amount_min or 0) + (prod.amount_max or 0)) / 2) * (prod.probability or 1)
    local base = (get(ep, "mining_speed") or 1) / math.max(mp.mining_time or 1, 1e-9) * amt
    local normal = get(rp, "normal_resource_amount")
    rate = 0
    for _, l in ipairs(live) do
      local yield = 1
      for _, w in ipairs(cl) do
        if math.abs(w.x - l.x) <= 1.01 and math.abs(w.y - l.y) <= 1.01 then
          if normal and normal > 0 and w.amount then yield = w.amount / normal end
          break
        end
      end
      rate = rate + base * yield
    end
  end
  return { total = #cl, wells = wells, extractor = extractor, rate = rate, live = #live }
end

local function freeze_ext(f, surface, p, h)
  local b = f.build
  local spec = p.spec
  if not Pet.on() then return nil, "reglage eteint", true end
  if not Pet.champ_on() then return nil, "extension eteinte", true end
  local info = current_info()
  local rel = ensure_rel()
  if not (rel and info) then return nil, "releve absent" end
  local fw, why = field_wells(f, surface, spec, spec.projects)
  if not fw then return nil, why end
  if #fw.wells == 0 then return nil, "plus aucun puits a equiper" end
  local net, forbid = Fl.ext_net(rel, ext_ents(b, spec.projects), spec.extractor or fw.extractor)
  local nn, sx, sy = 0, 0, 0
  for _, k in ipairs(sorted_keys(net)) do
    local tx, ty = math.floor(k / 2097152) - 1048576, k % 2097152 - 1048576
    nn, sx, sy = nn + 1, sx + tx, sy + ty
  end
  if nn == 0 then return nil, "reseau de brut du site introuvable" end
  local toward = { x = sx / nn + 0.5, y = sy / nn + 0.5 }
  -- relevé du terrain : les puits, le réseau de brut et une marge ; le reste de la ligne principale est lu par carrés de 32 tuiles
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, w in ipairs(fw.wells) do
    x0, y0, x1, y1 = math.min(x0, w.x), math.min(y0, w.y), math.max(x1, w.x), math.max(y1, w.y)
  end
  x0, y0, x1, y1 = math.min(x0, toward.x), math.min(y0, toward.y), math.max(x1, toward.x), math.max(y1, toward.y)
  x0, y0 = math.floor(x0) - Pet.EXT_MARGIN, math.floor(y0) - Pet.EXT_MARGIN
  x1, y1 = math.ceil(x1) + Pet.EXT_MARGIN, math.ceil(y1) + Pet.EXT_MARGIN
  if x1 - x0 > Pet.EXT_WINDOW then local m = math.floor((x0 + x1) / 2); x0, x1 = m - Pet.EXT_WINDOW / 2, m + Pet.EXT_WINDOW / 2 end
  if y1 - y0 > Pet.EXT_WINDOW then local m = math.floor((y0 + y1) / 2); y0, y1 = m - Pet.EXT_WINDOW / 2, m + Pet.EXT_WINDOW / 2 end
  local masks = h.read_masks(x0, y0, x1, y1)
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  local fz = {
    wells = fw.wells, total = fw.total, net = net, forbid = forbid, toward = toward, extractor = spec.extractor or fw.extractor,
    pole = pole_of(f, rel), netpt = nearest_network(f, surface, cx, cy, b),
    x0 = x0, y0 = y0, x1 = x1, y1 = y1, water = masks.water, blocked = masks.blocked, clear = masks.clear, extra = {},
    danger = danger_tiles(f, game.tick), occ = {},
  }
  for _, v in ipairs({ fz.wells, net, forbid, toward, fz.pole or {}, fz.netpt or {} }) do
    if not Fl.is_plain(v) then return nil, "etat du plan non serialisable" end
  end
  return { jb = Fl.layout_new(), fz = fz, steps = 0 }
end

local function ext_terrain(b, fz, h)
  local masks = { water = fz.water, blocked = fz.blocked, clear = fz.clear }
  masks.free = function(tx, ty)
    local k = Fl.tkey(tx, ty)
    return not masks.water[k] and not masks.blocked[k] and not b.occ[k]
  end
  local extra = fz.extra
  local function masks_at(tx, ty)
    if tx >= fz.x0 and tx < fz.x1 and ty >= fz.y0 and ty < fz.y1 then return masks end
    local cx, cy = math.floor(tx / 32), math.floor(ty / 32)
    local ck = cx * 65536 + cy
    local m = extra[ck]
    if not m then
      local r = h.read_masks(cx * 32, cy * 32, cx * 32 + 32, cy * 32 + 32)
      m = { water = r.water, blocked = r.blocked, clear = r.clear }
      extra[ck] = m
    end
    return m
  end
  local function blocked(tx, ty)
    local k = Fl.tkey(tx, ty)
    if fz.forbid and fz.forbid[k] then return true end
    local o = fz.occ[k]
    if o == nil then o = b.occ[k] ~= nil; fz.occ[k] = o end
    if o then return true end
    if fz.danger and fz.danger[k] then return true end
    local m = masks_at(tx, ty)
    return m.water[k] or m.blocked[k] or false
  end
  return blocked, masks
end

local function causes_text(list)
  local n, order = {}, {}
  local where = {}
  for i, sk in ipairs(list or {}) do
    if i <= 8 then where[#where + 1] = string.format("(%d,%d)", math.floor(sk.x), math.floor(sk.y)) end
  end
  for _, sk in ipairs(list or {}) do
    local c = tostring(sk.cause):sub(1, 40)
    if not n[c] then n[c] = 0; order[#order + 1] = c end
    n[c] = n[c] + 1
  end
  table.sort(order)
  local out = {}
  for _, c in ipairs(order) do out[#out + 1] = n[c] .. " x " .. c end
  if #where > 0 then out[#out + 1] = "puits " .. table.concat(where, " ") end
  return table.concat(out, " ; ")
end

local function step_ext(f, surface, p, h, pj)
  local b = f.build
  local spec = p.spec
  local fz = pj.fz
  local rel = ensure_rel()
  if not rel then return nil, "releve absent" end
  local blocked, masks = ext_terrain(b, fz, h)
  local req = { ents = rel.entities, conduit = D.PIPE, extractor = fz.extractor, fluid = spec.res, poles = fz.pole, network = fz.netpt,
    blocked = blocked, wells = fz.wells, net = fz.net, toward = fz.toward, max_n = spec.batch, hint = spec.hint }
  local okc, status, lay = pcall(Fl.ext_step, req, pj.jb, pj.steps == 0 and 1 or Pet.PLAN_SLICE)
  pj.steps = pj.steps + 1
  if not okc then
    log(string.format("[FO-PETROLE] %s : plan de l'extension repris de zero (%s)", f.key or "?", tostring(status)))
    p.plan_job = nil
    p.plan_restarts = (p.plan_restarts or 0) + 1
    if p.plan_restarts > 2 then return nil, "plan incoherent" end
    return nil, "plan repris de zero", "calcul"
  end
  if status == "more" then return nil, "calcul du plan (" .. pj.jb.spent .. " noeuds)", "calcul" end
  p.plan_job = nil
  if status == "fail" then
    log(string.format("[FO-PETROLE] %s : extension refusee a %.1f min : %s", f.key or "?", minutes(f, game.tick), tostring(lay)))
    return nil, tostring(lay)
  end
  lay.masks = masks
  lay.out_at = Pet.OUT_AT
  lay.key = "petrole-champ:" .. tostring(spec.res)
  p.champ = { n = lay.extractors, deferred = lay.deferred or 0, skipped = lay.skipped, trunk = lay.trunk, kinds = lay.kinds, pipes = lay.pipes,
    poles = lay.poles, line = lay.line, total = fz.total }
  log(string.format("[FO-PETROLE] %s : extension planifiee a %.1f min : puits equipes %d / %d du champ (lot de %d), collecteur %s, "
    .. "embranchements %s, tuyaux %d, poteaux %d (+%d de ligne), ecartes %d [%s], differes %d, %d noeuds d'A* en %d tranche(s)",
    f.key or "?", minutes(f, game.tick), lay.extractors, fz.total, spec.batch or 0,
    lay.trunk and string.format("%s%d de %d a %d", lay.trunk.axis, lay.trunk.c, lay.trunk.a, lay.trunk.b) or "aucun",
    (function()
      local t = {}
      for _, k in ipairs(sorted_keys(lay.kinds or {})) do t[#t + 1] = k .. " " .. lay.kinds[k] end
      return table.concat(t, ", ")
    end)(), lay.pipes or 0, lay.poles or 0, lay.line or 0, #(lay.skipped or {}), causes_text(lay.skipped), lay.deferred or 0,
    pj.jb.spent, pj.steps))
  return lay
end

--- Rangée de modules (étape 2) : le module du site de base (machines, bras, coffres, tuyaux du fluide interne) copié le long de ses bus.
local function freeze_rangee(f, surface, p, h)
  local b = f.build
  local spec = p.spec
  if not Pet.on() then return nil, "reglage eteint", true end
  if not Pet.champ_on() then return nil, "extension eteinte", true end
  local info = current_info()
  local rel = ensure_rel()
  if not (rel and info) then return nil, "releve absent" end
  local base = b.projects[spec.base]
  if not (base and base.ents) then return nil, "site de base absent" end
  local mod, why = Rf.analyze(rel, base.ents, { quais = base.quais, outs = base.outs })
  if not mod then return nil, "module non copiable : " .. tostring(why) end
  local L0, conn0 = Rf.world0(rel, ext_ents(b, spec.projects))
  -- relevé : l'emprise du module, élargie le long de l'axe de toute la rangée voulue et de la hauteur des bus de l'autre côté
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, t in ipairs(mod.tiles) do
    x0, y0, x1, y1 = math.min(x0, t[1]), math.min(y0, t[2]), math.max(x1, t[1]), math.max(y1, t[2])
  end
  local W = mod.hi - mod.lo + 1
  local along = (spec.kmax + (spec.from or 1)) * (W + Rf.DX_EXTRA + 2)
  local across = Rf.HMAX + 8
  if mod.axis == "h" then x0, x1, y0, y1 = x0 - along, x1 + along, y0 - across, y1 + across
  else y0, y1, x0, x1 = y0 - along, y1 + along, x0 - across, x1 + across end
  x0, y0, x1, y1 = math.floor(x0), math.floor(y0), math.ceil(x1), math.ceil(y1)
  if x1 - x0 > Pet.EXT_WINDOW then local m = math.floor((x0 + x1) / 2); x0, x1 = m - Pet.EXT_WINDOW / 2, m + Pet.EXT_WINDOW / 2 end
  if y1 - y0 > Pet.EXT_WINDOW then local m = math.floor((y0 + y1) / 2); y0, y1 = m - Pet.EXT_WINDOW / 2, m + Pet.EXT_WINDOW / 2 end
  local masks = h.read_masks(x0, y0, x1, y1)
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  local fz = {
    mod = mod, L0 = L0, conn0 = conn0, fixed = spec.fixed, from = spec.from, kmax = spec.kmax,
    pole = pole_of(f, rel), netpt = nearest_network(f, surface, cx, cy, b),
    x0 = x0, y0 = y0, x1 = x1, y1 = y1, water = masks.water, blocked = masks.blocked, clear = masks.clear, extra = {},
    danger = danger_tiles(f, game.tick), occ = {},
  }
  for _, v in ipairs({ mod, L0, conn0, fz.pole or {}, fz.netpt or {}, spec.fixed or {} }) do
    if not Fl.is_plain(v) then return nil, "etat du plan non serialisable" end
  end
  return { jb = Fl.layout_new(), fz = fz, steps = 0 }
end

local function step_rangee(f, surface, p, h, pj)
  local b = f.build
  local spec = p.spec
  local fz = pj.fz
  local rel = ensure_rel()
  if not rel then return nil, "releve absent" end
  local blocked, masks = ext_terrain(b, fz, h)
  local req = { mod = fz.mod, ents = rel.entities, conduit = D.PIPE, poles = fz.pole, network = fz.netpt, blocked = blocked, L0 = fz.L0, conn0 = fz.conn0,
    kmax = fz.kmax, from = fz.from, fixed = fz.fixed }
  local okc, status, lay = pcall(Fl.ext_step, req, pj.jb, pj.steps == 0 and 1 or Pet.PLAN_SLICE)
  pj.steps = pj.steps + 1
  if not okc then
    log(string.format("[FO-PETROLE] %s : plan de la rangee repris de zero (%s)", f.key or "?", tostring(status)))
    p.plan_job = nil
    p.plan_restarts = (p.plan_restarts or 0) + 1
    if p.plan_restarts > 2 then return nil, "plan incoherent" end
    return nil, "plan repris de zero", "calcul"
  end
  -- le plan avance par tranches de noeuds (Pet.PLAN_SLICE) : « more » garde le travail pour le passage suivant (plantage du 9/11 : lay nil)
  if status == "more" then return nil, "calcul du plan (" .. pj.jb.spent .. " noeuds)", "calcul" end
  p.plan_job = nil
  if status == "fail" then
    log(string.format("[FO-PETROLE] %s : rangee refusee a %.1f min : %s", f.key or "?", minutes(f, game.tick), tostring(lay)))
    return nil, tostring(lay)
  end
  lay.masks = masks
  lay.out_at = Pet.OUT_AT
  lay.key = "petrole-rangee:" .. tostring(spec.res)
  p.rangee_fl = { n = lay.copies, dx = lay.dx, sign = lay.sign, hs = lay.hs, axis = fz.mod.axis, from = fz.from or 1 }
  log(string.format("[FO-PETROLE] %s : rangee planifiee a %.1f min : %d copie(s) du module (%d a %d) au pas de %d tuiles, axe %s, sens %d, bus du brut a %d et de l'eau a %d tuile(s) des prises, "
    .. "%d tuyaux, %d poteaux, %d entites%s", f.key or "?", minutes(f, game.tick), lay.copies, fz.from or 1, (fz.from or 1) + lay.copies - 1, lay.dx, fz.mod.axis, lay.sign,
    lay.hs.brut or 0, lay.hs.eau or 0, lay.pipes or 0, lay.poles or 0, #lay.ents, lay.copies < (fz.kmax or 1) and (" ; arret devant : " .. tostring(lay.cause)) or ""))
  return lay
end

local function plan_site(f, surface, p, h)
  local pj = p.plan_job
  if not pj then
    local why, wait
    if p.spec.rangee then
      pj, why, wait = freeze_rangee(f, surface, p, h)
    elseif p.spec.ext then
      pj, why, wait = freeze_ext(f, surface, p, h)
    else
      pj, why, wait = freeze_site(f, surface, p, h)
    end
    if not pj then return nil, why, wait end
    p.plan_job = pj
    return nil, "terrain releve", "calcul" -- la première passe relève le terrain seulement ; l'A* commence à la suivante
  end
  if p.spec.rangee then return step_rangee(f, surface, p, h, pj) end
  if p.spec.ext then return step_ext(f, surface, p, h, pj) end
  return step_site(f, surface, p, h, pj)
end

Build.SITES = Build.SITES or {}
-- chronomètre du plan d'un site (relevés de terrain, A* des tuyaux et des poteaux : un tick entier) : mesure K10
Build.SITES.petrole = function(f, surface, p, h)
  Profiler.start("petrole:plan")
  local a, b, c = plan_site(f, surface, p, h)
  Profiler.stop("petrole:plan")
  return a, b, c
end

---------------------------------------------------------------------------------------------------
-- Pensée
---------------------------------------------------------------------------------------------------
local function site_for(st, key)
  for _, s in ipairs(st.sites) do if s.key == key then return s end end
  return nil
end

--- Le gisement (x, y) de la ressource `res` est-il pris par une autre équipe ? Site demandé ou bâti d'une autre équipe (état du lot
--- de chacune, global) ou extracteur d'une autre force sur le gisement (une partie rechargée sans l'état).
local function claimed(f, res, d, extractors)
  local r2 = Pet.CLAIM_R * Pet.CLAIM_R
  local teams = {}
  local war = State.war()
  for _, id in ipairs(sorted_keys(war and war.factions)) do teams[#teams + 1] = war.factions[id] end
  teams[#teams + 1] = State.faction("player")
  for _, t in ipairs(teams) do
    local ps = t ~= f and t.team and t.team.petrole
    for _, s in ipairs((ps and ps.sites) or {}) do
      if s.res == res and s.state ~= "refuse" and s.x and (s.x - d.x) ^ 2 + (s.y - d.y) ^ 2 <= r2 then return true end
    end
  end
  if extractors and #extractors > 0 and f.hq and f.hq.valid then
    for _, e in ipairs(f.hq.surface.find_entities_filtered({ name = extractors, position = { d.x, d.y }, radius = Pet.CLAIM_R })) do
      if e.force.name ~= f.force then return true end
    end
  end
  return false
end

--- Une cause d'attente de plus (clé stable → texte) : dite au journal à son apparition, à son changement et toutes les
--- Pet.WHY_EVERY ticks tant qu'elle dure, puis une fois levée (Fl.news). Lot DIAG-PETROLE : la partie de 2 h n'avait rien dit
--- pendant 80 minutes d'un pack chimique ouvert sans site.
local function why_line(f, st, tick, now)
  st.why = st.why or {}
  local say, gone = Fl.news(st.why, now, tick, Pet.WHY_EVERY)
  for _, k in ipairs(say) do
    log(string.format("[FO-PETROLE] %s : %s a %.1f min", f.key or "?", now[k], minutes(f, tick)))
  end
  for _, k in ipairs(gone) do
    log(string.format("[FO-PETROLE] %s : cause levee (%s) a %.1f min", f.key or "?", k, minutes(f, tick)))
  end
end

local function decide(f, st, General, deposits, tick)
  local c = General.catalogue()
  refresh_known(f, st, c, deposits, tick)
  local items, pack_of, diag = wanted_items(f, General, c)
  local why = {} -- causes d'attente de cet instant (clé → texte), dites par why_line
  if #items == 0 then
    if #diag.unpayable > 0 then
      why["packs"] = string.format("pack(s) [%s] ouvert(s) mais impayable(s) au graphe : aucun site demande", table.concat(diag.unpayable, " "))
    elseif #diag.bare > 0 then
      why["packs"] = string.format("pack(s) [%s] ouvert(s) et payable(s) : aucun objet ne demande une cellule du lot", table.concat(diag.bare, " "))
    else
      why["packs"] = "aucun pack ouvert (recette debloquee, ou recherche qui y mene)"
    end
    why_line(f, st, tick, why)
    return
  end
  -- regroupement : par fluide EXTRAIT de la chaîne (un site au gisement), sinon un site près du QG
  local groups, order = {}, {}
  local water = nil
  for _, res in ipairs(pump_resources(c)) do if st.known[res] then water = res end end
  local force = game.forces[f.force]
  local locked, locked_pack = {}, {}
  local locked_recipes = {} -- groupe → recettes verrouillées de sa chaîne
  -- chaîne de chaque objet, puis packs COMPLETS : un pack dont un objet n'a pas de chaîne (pétrole pas encore connu) ne fait
  -- demander aucun site, pas même la cellule sans fluide (Fl.complete_packs)
  local chains, rows, reasons = {}, {}, {}
  for _, it in ipairs(items) do
    local ch, cwhy = Fl.chain(REL, INFO, { it }, water and { [water] = "pompe" } or {}, chooser(f))
    chains[it], reasons[it] = ch, cwhy
    rows[#rows + 1] = { item = it, pack = pack_of[it], ok = ch ~= nil }
    if ch == nil then
      why["chaine:" .. it] = string.format("objet '%s' (pack %s) sans chaine : %s", it, tostring(pack_of[it]), tostring(cwhy))
    end
  end
  local complete = Fl.complete_packs(rows)
  local incomplete = {}
  for _, r in ipairs(rows) do
    if r.pack ~= nil and not complete[r.pack] then incomplete[r.pack] = true end
  end
  for _, pk in ipairs(sorted_keys(incomplete)) do
    why["pack:" .. pk] = string.format("pack %s incomplet : aucun site tant qu'un de ses objets n'a pas de chaine", pk)
  end
  for _, it in ipairs(items) do
    local ch = chains[it]
    if pack_of[it] ~= nil and not complete[pack_of[it]] then ch = nil end
    -- une recette de la chaîne encore verrouillée : le GROUPE attend (la machine posée ne pourrait pas la lancer, et un
    -- site bâti pour une partie des objets ne serait pas refait pour les autres)
    local lrec = {}
    if ch then
      for _, cell in ipairs(ch.cells) do
        local fr = force and force.recipes[cell.recipe]
        if not (fr and fr.enabled) then lrec[#lrec + 1] = cell.recipe end
      end
    end
    if ch then
      local res = nil
      for _, fl in ipairs(sorted_keys(ch.sources)) do if ch.sources[fl] == "extract" then res = fl end end
      local g = res or "qg"
      if #lrec > 0 then
        locked[g] = true
        if pack_of[it] then locked_pack[pack_of[it]] = true end
        locked_recipes[g] = locked_recipes[g] or {}
        for _, r in ipairs(lrec) do locked_recipes[g][#locked_recipes[g] + 1] = r end
      end
      if not groups[g] then groups[g] = { res = res, items = {}, water = nil, pack = pack_of[it] }; order[#order + 1] = g end
      groups[g].items[#groups[g].items + 1] = it
      if ch.sources[water or "?"] == "pompe" then groups[g].water = water end
    end
  end
  table.sort(order)
  for _, g in ipairs(order) do
    local grp = groups[g]
    local s = site_for(st, g)
    local again = s and s.state == "refuse" and tick >= (s.retry or 0)
    local waits = (not s) or again
    -- … ni tant qu'une recette d'une autre cellule du MÊME pack est verrouillée (le moteur ne se bâtit pas des dizaines de
    -- minutes avant la raffinerie : moteur réel, etape1-guide 123456789, cellule du moteur à 14 min pour un pack impayable)
    if waits and locked[g] then
      why["groupe:" .. g] = string.format("groupe '%s' [%s] attend : recette(s) verrouillee(s) [%s]", g, table.concat(grp.items, " "),
        table.concat(locked_recipes[g], " "))
    elseif waits and grp.pack and locked_pack[grp.pack] then
      local others = {}
      for _, g2 in ipairs(order) do
        if locked[g2] then others[#others + 1] = g2 .. ":" .. table.concat(locked_recipes[g2], ",") end
      end
      why["groupe:" .. g] = string.format("groupe '%s' [%s] attend le pack %s : recette(s) verrouillee(s) d'une autre cellule [%s]", g,
        table.concat(grp.items, " "), grp.pack, table.concat(others, " "))
    elseif waits then
      local x, y, ok = f.hq_pos.x, f.hq_pos.y, true
      local extractor
      if grp.res then
        local d = deposits and deposits(f, grp.res, tick)
        extractor = INFO.extract[grp.res] and INFO.extract[grp.res][1]
        local bad = st.bad and st.bad[grp.res]
        local n_bad, n_claimed = 0, 0
        local pick = Fl.pick_unclaimed(d, function(dd)
          if Fl.near_any(bad, dd, Pet.BAD_R) then n_bad = n_bad + 1 return true end
          if claimed(f, grp.res, dd, INFO.extract[grp.res]) then n_claimed = n_claimed + 1 return true end
          return false
        end)
        -- tous essayés (ou pris) : on recommence par le plus proche à la prochaine revue
        if not pick and bad then st.bad[grp.res] = nil end
        if pick then x, y = pick.x, pick.y else
          ok = false
          why["gisement:" .. g] = string.format("groupe '%s' : aucun gisement de %s libre (%d connu(s), %d deja refuse(s), %d pris par une autre equipe)",
            g, grp.res, #(d or {}), n_bad, n_claimed)
        end
      end
      if ok then
        if not f.build then Build.enable(f, { radius = 3 }) end
        local id = Build.request(f, { site = "petrole", targets = grp.items, res = grp.res, water = grp.water,
          extractor = extractor, x = x, y = y, prio = Build.PRIO, domain = "production", lazy_clear = true })
        if id then
          if s then s.id, s.state, s.items, s.pack = id, "attente", grp.items, grp.pack else
            st.sites[#st.sites + 1] = { key = g, id = id, items = grp.items, state = "attente", res = grp.res, x = x, y = y,
              pack = grp.pack }
          end
          st.decisions = st.decisions + 1
          note(f, st, tick, string.format("site '%s' demande (projet %d) en (%d, %d) pour [%s]%s%s", g, id, x, y,
            table.concat(grp.items, " "), grp.res and (", gisement de " .. grp.res) or ", pres du QG",
            grp.water and (", eau de " .. grp.water) or ""))
        else
          why["projet:" .. g] = string.format("groupe '%s' [%s] : le plan directeur n'a pas pris la demande de site", g, table.concat(grp.items, " "))
        end
      end
    end
  end
  why_line(f, st, tick, why)
end

---------------------------------------------------------------------------------------------------
-- Lot TV-FLUX (V42, M32) : la SOUPAPE des cuves de fluide d'un site fini
---------------------------------------------------------------------------------------------------
--[[
  Un site FINI (raffinerie, usines chimiques) arrête sa chaîne amont quand la cuve d'un fluide qu'il produit est PLEINE et qu'aucune de ses machines
  ne le mange plus (« in the unlikely event that petroleum pipes get full … turn the excess into solid fuel », vidéo 6:02). Toutes les
  Pet.VALVE_EVERY ticks, pour chaque site fini : MESURE (machines posées du site : boîtes de SORTIE, fluides de leur recette, état « travaille »,
  Fl.valve_reading) -> DÉCISION (Fl.valve : cuve au-delà de 90 % sans débouché ouvert pendant Fl.VALVE_K mesures de suite) -> ACTION (la
  recette de surplus, lue au relevé et débloquée pour la force, Fl.valve_row : prend du fluide dans la cuve la plus pleine, au plus ce que la machine
  de cette recette fait dans le temps écoulé, et dépose les objets au coffre de sortie du site, au plus la place qu'il a, Fl.valve_convert) -> EFFET
  (cuve qui redescend, objets au coffre que les PNJ rapportent, chaîne amont qui repart). La soupape se referme seule quand la cuve repasse sous 90 %.
  Option par défaut (décision de conception du lot, à confirmer par le DC) : la conversion est SCRIPTÉE à débit borné par la machine du relevé, sans
  entité de plus ; une cellule posée (machine, tuyau, coffre, bras) demanderait d'étendre l'implantation d'un site déjà fini.
  Réglage de carte fo-war-soupape, ALLUMÉ par défaut (settings/flux.lua) ; absent (moteur simulé) = éteint. Journal [FO-SOUPAPE] : ouverture,
  chaque conversion, fermeture, cause d'impossibilité (une fois par changement). Aucune horloge : les mesures sont l'état du jeu.
  État (f.team.petrole.valves[site|fluide], nombres et chaînes) : { n (mesures pleines), open, last (tick), total (unités converties), said }.
]]
Pet.VALVE_SETTING = "fo-war-soupape"
Pet.VALVE_EVERY = 1800 -- ticks entre deux mesures (30 s) : 5 mesures pleines de suite ouvrent la soupape en 2,5 min

function Pet.valve_on()
  local ok, v = pcall(function() return settings.global[Pet.VALVE_SETTING].value end)
  return ok and v == true
end

--- Relevé filtré pour la recette de surplus : recettes débloquées pour la force ET faisables par une machine de l'exécutant.
--- Le relevé garde `enabled` AU DÉPART de la partie (faux pour une recette que la recherche débloque) : la force juge ici, d'où `enabled = true`
--- sur la copie. `all` : sans filtre de force ni d'exécutant (diagnostic).
local function open_rel(force, rel, info, all)
  local out = {}
  for _, rn in ipairs(sorted_keys(rel.recipes)) do
    local fr = force and force.recipes[rn]
    if all or (fr and fr.enabled and info.recipes and info.recipes[rn] and #info.recipes[rn] > 0) then
      local c = {}
      for k, x in pairs(rel.recipes[rn]) do c[k] = x end
      c.enabled = true
      out[rn] = c
    end
  end
  return { recipes = out }
end

--- Machines posées d'un site fini : rows pour Fl.valve_reading, et leurs entités (même rang) avec leurs boîtes de sortie.
local function valve_machines(f, surface, p, rel)
  local rows, ents = {}, {}
  for _, e in ipairs(p.ents or {}) do
    if e.built and e.recipe and e.role == "machine" then
      local ent = surface.find_entity(e.name, { e.x, e.y })
      if ent and ent.valid and ent.force.name == f.force then
        local fb = ent.fluidbox
        local out = {}
        for i = 1, #fb do
          local proto = fb.get_prototype(i)
          if type(proto) == "table" and proto.production_type == nil then proto = proto[1] end
          local fl = fb[i]
          if proto and proto.production_type == "output" and fl then
            out[#out + 1] = { fluid = fl.name, amount = fl.amount, capacity = fb.get_capacity(i) }
          end
        end
        local ins = {}
        local r = rel.recipes[e.recipe]
        for _, ing in ipairs((r and r.ingredients) or {}) do if ing.type == "fluid" then ins[#ins + 1] = ing.name end end
        rows[#rows + 1] = { out = out, ins = ins, working = ent.status == defines.entity_status.working }
        ents[#ents + 1] = { ent = ent, out = out }
      end
    end
  end
  return rows, ents
end

--- Coffre de sortie du site qui peut recevoir au moins une fabrication de `row` : (coffre, place par objet) ou nil.
local function valve_chest(f, surface, p, row)
  for _, o in ipairs(p.outs or {}) do
    local chest = surface.find_entity(o.name or D.CHEST, { o.x, o.y }) -- coffre de sortie du site (nom lu aux données, jamais en dur : iag_test)
    if chest and chest.valid and chest.force.name == f.force then
      local inv = chest.get_inventory(defines.inventory.chest)
      local room, ok = {}, true
      for _, pr in ipairs(row.products) do
        room[pr.name] = inv.get_insertable_count(pr.name)
        if room[pr.name] < pr.amount then ok = false end
      end
      if ok then return chest, room end
    end
  end
  return nil
end

local function valve_say(f, tick, v, text)
  if v.said == text then return end
  v.said = text
  log(string.format("[FO-SOUPAPE] %s minute %d : %s", f.key or "?", math.floor(minutes(f, tick)), text))
end

--- Une mesure de la soupape pour un site fini (voir l'en-tête du bloc). Rend les unités de fluide converties ce passage.
local function valve_site(f, st, s, p, surface, rel, info, tick)
  local rows, ents = valve_machines(f, surface, p, rel)
  st.valve_note = string.format("site '%s' : %d machine(s) lue(s) sur %d entite(s)", tostring(s.key), #rows, #(p.ents or {}))
  local converted = 0
  local force = game.forces[f.force]
  for _, rd in ipairs(Fl.valve_reading(rows)) do
    local vkey = s.key .. "|" .. rd.fluid
    local v = st.valves[vkey]
    if not v then v = Fl.valve_new(); st.valves[vkey] = v end
    local full = rd.fill > Fl.VALVE_FILL and rd.outlets == 0
    local surplus = nil
    if full and (v.n or 0) + 1 >= Fl.VALVE_K then surplus = Fl.valve_recipe(open_rel(force, rel, info), rd.fluid) end
    local d = Fl.valve(v, rd.fluid, rd.fill, rd.outlets, surplus)
    local pct = math.floor(rd.fill * 100 + 0.5)
    if d.open then
      local row = Fl.valve_row(rel, d.recipe, rd.fluid)
      local machine = info.recipes[d.recipe] and info.recipes[d.recipe][1]
      local speed = machine and rel.entities[machine] and rel.entities[machine].speed or 1
      if not v.open then
        v.open = true
        valve_say(f, tick, v, string.format("site '%s' fluide %s : cuve a %d %% sans debouche ouvert depuis %d mesures : soupape OUVERTE (recette %s, machine %s)",
          s.key, rd.fluid, pct, Fl.VALVE_K, d.recipe, tostring(machine)))
        st.valve_opened = (st.valve_opened or 0) + 1
      end
      -- la cuve la plus pleine de ce fluide
      local best, best_amount
      for _, m in ipairs(ents) do
        for _, o in ipairs(m.out) do
          if o.fluid == rd.fluid and (best_amount == nil or o.amount > best_amount) then best, best_amount = m.ent, o.amount end
        end
      end
      -- temps écoulé depuis la dernière conversion (plafonné à 5 min) : une mesure qui ne laisse pas le temps d'une fabrication n'efface pas ce temps
      local dt = math.min(5, (tick - (v.last or (tick - Pet.VALVE_EVERY))) / 3600)
      local chest, room = nil, nil
      if row then chest, room = valve_chest(f, surface, p, row) end
      if not row then
        valve_say(f, tick, v, string.format("site '%s' fluide %s : recette de surplus %s illisible au releve", s.key, rd.fluid, tostring(d.recipe)))
      elseif not chest then
        valve_say(f, tick, v, string.format("site '%s' fluide %s : soupape ouverte mais aucun coffre de sortie du site n'a de place pour %s", s.key, rd.fluid, row.products[1].name))
      elseif best and best.valid then
        local cv = Fl.valve_convert(row, speed, best_amount, dt, room)
        if cv.crafts > 0 then
          local removed = best.remove_fluid({ name = rd.fluid, amount = cv.fluid })
          local crafts = math.min(cv.crafts, math.floor(removed / row.fluid_in + 1e-9))
          local list = {}
          for _, pr in ipairs(row.products) do
            local n = math.floor(crafts * pr.amount + 1e-9)
            if n > 0 then
              local put = chest.insert({ name = pr.name, count = n })
              list[#list + 1] = string.format("%s x%d", pr.name, put)
            end
          end
          converted = converted + crafts * row.fluid_in
          -- le temps non employé (reste de la division) est gardé pour la conversion suivante
          local used_min = crafts * row.energy / (speed * 60)
          v.last = tick - math.floor(math.max(0, dt - used_min) * 3600 + 0.5)
          v.total = (v.total or 0) + crafts * row.fluid_in
          st.valve_units = (st.valve_units or 0) + crafts * row.fluid_in
          v.said = nil
          valve_say(f, tick, v, string.format("site '%s' fluide %s : %s x%d = %d unites prises a la cuve -> %s au coffre (%d, %d) ; cuve a %d %% (borne : %s)",
            s.key, rd.fluid, d.recipe, crafts, crafts * row.fluid_in, table.concat(list, ", "), chest.position.x, chest.position.y, pct, cv.limit))
        else
          if v.last == nil then v.last = tick - Pet.VALVE_EVERY end
          valve_say(f, tick, v, string.format("site '%s' fluide %s : soupape ouverte, rien a convertir ce passage (borne : %s)", s.key, rd.fluid, cv.limit))
        end
      end
      if v.last == nil then v.last = tick end
    else
      if v.open then
        v.open = false
        v.said = nil
        valve_say(f, tick, v, string.format("site '%s' fluide %s : soupape FERMEE (%s), cuve a %d %% ; %d unites converties en tout",
          s.key, rd.fluid, d.why, pct, math.floor(v.total or 0)))
      elseif full and not surplus and (v.n or 0) >= Fl.VALVE_K then
        -- pourquoi aucune recette : candidate du relevé entier, débloquée pour la force ?, machine de l'exécutant ?
        local cand = Fl.valve_recipe(open_rel(force, rel, info, true), rd.fluid)
        local fr = cand and force and force.recipes[cand]
        valve_say(f, tick, v, string.format("site '%s' fluide %s : cuve a %d %% sans debouche, mais aucune recette de surplus utilisable (candidate du releve : %s, debloquee : %s, machine de l'executant : %s)",
          s.key, rd.fluid, pct, tostring(cand), tostring(fr and fr.enabled), tostring(cand and info.recipes and info.recipes[cand] and info.recipes[cand][1])))
      end
      v.last = nil
    end
  end
  return converted
end

--- Passage de la soupape pour tous les sites FINIS de la faction. Rend les unités converties.
function Pet.valve_think(f, st, tick)
  if not Pet.valve_on() then return 0 end
  if tick < (st.valve_next or 0) then return 0 end
  st.valve_next = tick + Pet.VALVE_EVERY
  st.valve_calls = (st.valve_calls or 0) + 1
  st.valves = st.valves or {}
  local rel, info = ensure_rel(), current_info()
  local b = f.build
  if not (rel and info and b and f.hq and f.hq.valid) then
    st.valve_note = string.format("passage sans mesure : releve %s, executants %s, plan directeur %s", tostring(rel ~= nil), tostring(info ~= nil), tostring(b ~= nil))
    return 0
  end
  local total = 0
  local surface = f.hq.surface
  st.valve_note = "aucun site fini"
  for _, s in ipairs(st.sites) do
    local p = b.projects[s.id]
    if p and p.state == "fini" and surface then
      st.valve_note = string.format("site '%s' fini mesure", tostring(s.key))
      local ok, res = pcall(valve_site, f, st, s, p, surface, rel, info, tick)
      if ok then total = total + (res or 0) else
        log(string.format("[FO-SOUPAPE] %s : erreur au site '%s' : %s", f.key or "?", tostring(s.key), tostring(res)))
      end
    end
  end
  return total
end

--- Rangée de modules (étape 2) : le site de base est le module 1 ; autant de copies que le brut des chevalets posés en nourrit (Rf.count : débit des
--- chevalets / consommation d'un module, lus aux prototypes), au plus Rf.KMAX modules et Rf.BATCH copies par chantier. Un chantier à la fois ; le
--- pas, le sens et les bus du chantier précédent sont repris (s.rangee). Rien n'est demandé tant qu'un chantier d'extension de puits est en cours.
local function rangee_check(f, st, s, tick, fw)
  if s.rg_stop or s.ext_id or tick < (s.rg_next or 0) then return end
  s.rg_next = tick + Pet.EXT_CHECK
  local rel = ensure_rel()
  local info = current_info()
  if not (rel and info and s.items and #s.items > 0) then return end
  local ids = { s.id }
  for _, id in ipairs(s.exts or {}) do ids[#ids + 1] = id end
  if not fw then fw = field_wells(f, f.hq.surface, s, ids) end
  if not fw then return end
  local G = package.loaded["script.ai3.general"]
  local c = G and G.catalogue and G.catalogue()
  local water
  for _, res in ipairs(c and pump_resources(c) or {}) do if st.known[res] then water = res end end
  local ch = Fl.chain(rel, info, s.items, water and { [water] = "pompe" } or {}, chooser(f))
  if not ch then return end
  local use = Rf.use(rel, ch.cells, s.res)
  local done = s.rangee and s.rangee.n or 0
  -- cible de la rangée par la règle commune : le débit du bus de brut borne (« debit:ligne »), la cible ne baisse jamais ; la demande en aval n'est pas
  -- modélisée (voulu = Rf.KMAX), l'arrêt devant un obstacle est décidé par le plan du chantier (step_rangee)
  local cap = Rf.count(fw.rate, use, Rf.KMAX)
  local g = Rb.croissance({ n = done + 1, prev = s.rg_cible, voulu = Rf.KMAX, extent = Rf.KMAX, cap = cap })
  s.rg_cible = g.cible
  local K = g.cible
  local want = K - 1 - done
  local line = string.format("site '%s' : rangee de modules : brut des %d chevalet(s) pose(s) %s/s, un module en prend %.1f/s, modules voulus %d (%s), copies posees %d",
    s.key, fw.live or 0, fw.rate and string.format("%.1f", fw.rate) or "?", use, K, g.cause, done)
  if s.rg_said ~= line then s.rg_said = line; note(f, st, tick, line) end
  if want < 1 then return end
  local batch = math.min(want, Rf.BATCH)
  local id = Build.request(f, { site = "petrole", rangee = true, base = s.id, projects = ids, res = s.res, x = s.x, y = s.y, kmax = batch,
    from = done + 1, fixed = s.rangee and { dx = s.rangee.dx, sign = s.rangee.sign, hs = s.rangee.hs } or nil, targets = s.items,
    prio = Build.PRIO, domain = "production", lazy_clear = true })
  if id then
    s.ext_id, s.ext_state = id, "attente"
    st.decisions = st.decisions + 1
    note(f, st, tick, string.format("site '%s' : rangee de modules demandee (projet %d) : %d copie(s) de %d a %d", s.key, id, batch, done + 1, done + batch))
  end
end

--- Site FINI : chantier d'extension jusqu'à ce que tous les puits atteignables de son champ soient équipés (lot PETROLE-RANGEE).
--- Un seul chantier d'extension à la fois ; un refus redemande un lot plus petit 5 min plus tard, 4 refus de suite arrêtent le site.
local function extend_site(f, st, s, tick)
  if not (Pet.champ_on() and s.res and s.x and f.build and f.hq and f.hq.valid) then return end
  local b = f.build
  if s.ext_id then
    local br = Build.brief(f, s.ext_id)
    if not br then
      s.ext_id = nil
    elseif br.state == "fini" then
      s.exts = s.exts or {}
      s.exts[#s.exts + 1] = s.ext_id
      local q = b.projects[s.ext_id]
      local ch = q and q.champ
      if ch and ch.trunk then s.hint = { axis = ch.trunk.axis, c = ch.trunk.c } end
      s.ext_fail = 0
      if q and q.rangee_fl then
        -- chantier de rangee fini : le pas, le sens et les bus sont repris par le chantier suivant
        s.rangee = { n = (s.rangee and s.rangee.n or 0) + q.rangee_fl.n, dx = q.rangee_fl.dx, sign = q.rangee_fl.sign, hs = q.rangee_fl.hs }
        s.rg_fail, s.rg_next = 0, tick
        note(f, st, tick, string.format("site '%s' : rangee de modules finie (projet %d) : %d copie(s) du module au total", s.key, s.ext_id, s.rangee.n))
      else
        note(f, st, tick, string.format("site '%s' : extension du champ finie (projet %d, %d chevalet(s))", s.key, s.ext_id, ch and ch.n or 0))
      end
      s.ext_id, s.ext_state, s.ext_next = nil, nil, tick
    elseif br.state == "refuse" and b.projects[s.ext_id] and b.projects[s.ext_id].spec.rangee then
      s.rg_fail = (s.rg_fail or 0) + 1
      note(f, st, tick, string.format("site '%s' : rangee de modules refusee (projet %d, refus %d/%d) : %s", s.key, s.ext_id, s.rg_fail, Pet.RG_FAILS, tostring(br.reason)))
      s.ext_id, s.ext_state = nil, nil
      s.rg_next = tick + Pet.EXT_RETRY
      if s.rg_fail >= Pet.RG_FAILS then
        s.rg_stop = tostring(br.reason)
        note(f, st, tick, string.format("site '%s' : rangee de modules abandonnee (cause : %s)", s.key, s.rg_stop))
      end
      return
    elseif br.state == "refuse" then
      s.ext_fail = (s.ext_fail or 0) + 1
      s.ext_batch = math.max(3, math.floor((s.ext_batch or Pet.EXT_BATCH) / 2))
      note(f, st, tick, string.format("site '%s' : extension du champ refusee (projet %d, refus %d/%d) : %s ; prochain lot de %d", s.key, s.ext_id,
        s.ext_fail, Pet.EXT_FAILS, tostring(br.reason), s.ext_batch))
      s.ext_id, s.ext_state = nil, nil
      s.ext_next = tick + Pet.EXT_RETRY
      if s.ext_fail >= Pet.EXT_FAILS then
        s.ext_stop = tostring(br.reason)
        note(f, st, tick, string.format("site '%s' : extension du champ abandonnee apres %d refus (cause : %s)", s.key, s.ext_fail, s.ext_stop))
      end
      return
    else
      s.ext_state = br.state
      return
    end
  end
  if s.ext_stop or tick < (s.ext_next or 0) then
    if s.ext_stop and not s.ext_id then rangee_check(f, st, s, tick, nil) end -- extension de puits abandonnée : la rangée se juge sur ce qui est posé
    return
  end
  local ids = { s.id }
  for _, id in ipairs(s.exts or {}) do ids[#ids + 1] = id end
  local fw, why = field_wells(f, f.hq.surface, s, ids)
  if not fw then
    s.ext_next = tick + Pet.EXT_CHECK
    if s.ext_why ~= why then s.ext_why = why; note(f, st, tick, string.format("site '%s' : champ non evalue (%s)", s.key, tostring(why))) end
    return
  end
  s.cov = { total = fw.total, eq = fw.total - #fw.wells, left = #fw.wells }
  if #fw.wells == 0 then
    s.ext_next = tick + Pet.EXT_CHECK
    rangee_check(f, st, s, tick, fw)
    if not s.cov_said then
      s.cov_said = true
      note(f, st, tick, string.format("site '%s' : champ de %s tout equipe, puits equipes %d / %d, chantiers d'extension %d", s.key, tostring(s.res),
        fw.total, fw.total, #(s.exts or {})))
    end
    return
  end
  s.cov_said = nil
  local batch = s.ext_batch or Pet.EXT_BATCH
  local id = Build.request(f, { site = "petrole", ext = true, base = s.id, projects = ids, res = s.res, extractor = fw.extractor, x = s.x, y = s.y,
    batch = batch, hint = s.hint, targets = s.items, prio = Build.PRIO, domain = "production", lazy_clear = true })
  if id then
    s.ext_id, s.ext_state = id, "attente"
    st.decisions = st.decisions + 1
    note(f, st, tick, string.format("site '%s' : extension du champ demandee (projet %d) : puits equipes %d / %d, lot de %d au plus, chantiers d'extension finis %d",
      s.key, id, fw.total - #fw.wells, fw.total, batch, #(s.exts or {})))
  else
    s.ext_next = tick + Pet.EXT_RETRY
  end
end

--- Pensée d'une faction (script/ai3/cerveau.lua, après Auto.think) : décisions, état des sites, et leurs projets rendus
--- au cerveau par le contexte de l'automatisation (A.goals : manques des chantiers, quais d'un site fini).
function Pet.think(f, view, book, tick, auto, General, deposits)
  if not Pet.on() or not (f.team and f.hq and f.hq.valid) then return auto end
  Profiler.start("petrole:think")
  local st = state_of(f)
  Profiler.fstart("pet:decide") -- lot PERF3 : portées fines (mesure seulement)
  -- Lot IA-GARDE (règle du DC, 11/11) : sous 2 colonnes de fonderie automatisées et 6 assembleurs actifs, aucune tâche de pétrole : ni site
  -- demandé, ni extension de champ de puits, ni fabrication pour un site pas fini (partie du DC 0.6.96 : Ambre demande son site à 41,6 min)
  local garde = AdRt.voit(f, "petrole", nil, tick)
  if tick >= (st.next or 0) then
    st.next = tick + Pet.EVERY
    if garde then decide(f, st, General, deposits, tick) else AdRt.compte(f, "petrole", 1, tick) end
  end
  Profiler.fstop("pet:decide")
  Profiler.fstart("pet:centrale")
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
  -- Un site qui fait le pack que la recherche EN COURS consomme la SERT (A.serves_research : produit du but = le pack) :
  -- il n'est plus plafonné sous la recherche (moteur réel, petrole-partie 1618033988 : site du pétrole en « réserve » de
  -- 74 à 120 min, raffinerie, chevalets et poteaux jamais fabriqués, la recherche passant devant). Un site au plus par
  -- pack (le premier : celui du gisement, demandé après la cellule sans fluide, passe d'abord dans la liste triée).
  Profiler.fstop("pet:centrale")
  Profiler.fstart("pet:packs")
  local lab = f.team.ia3 and f.team.ia3.lab
  local consumes, used_pack = {}, {}
  local cspec = lab and lab.tech and General.catalogue().techs[lab.tech]
  for _, ing in ipairs((cspec and cspec.ingredients) or {}) do consumes[ing[1]] = true end
  -- … ou le pack OUVERT (sa recette débloquée) que l'équipe ne fabrique pas encore : c'est son palier suivant (un joueur
  -- investit dans l'usine du pack nouveau avant de chercher plus loin)
  do
    local force = game.forces[f.force]
    local c = General.catalogue()
    -- Lot PERF3 : seules les recettes qui font un pack (mêmes recettes, même ordre, mêmes packs : le même ensemble `consumes`)
    for _, row in ipairs(pack_recipes(c)) do
      local fr = force and force.recipes[row.rn]
      if fr and fr.enabled then
        for _, pk in ipairs(row.packs) do
          if (stock[pk] or 0) == 0 and produced(force, pk) == 0 then
            consumes[pk] = true
          end
        end
      end
    end
  end
  Profiler.fstop("pet:packs")
  Profiler.fstart("pet:sites")
  local order_sites = {}
  for i, s in ipairs(st.sites) do order_sites[i] = s end
  table.sort(order_sites, function(a, b2)
    if (a.res ~= nil) ~= (b2.res ~= nil) then return a.res ~= nil end
    return a.key < b2.key
  end)
  local product_of = {}
  for _, s in ipairs(order_sites) do
    if s.pack and consumes[s.pack] and not used_pack[s.pack] then used_pack[s.pack] = true; product_of[s.key] = s.pack end
  end
  for _, s in ipairs(st.sites) do
    local br = Build.brief(f, s.id)
    if br then
      if br.state ~= s.state then
        if br.state == "refuse" or br.state == "fini" or br.state == "bloque" or br.state == "reserve" or br.state == "chantier" then
          note(f, st, tick, string.format("site '%s' (projet %d) : %s%s (%d/%d entites)", s.key, s.id, br.state,
            br.reason and (" (" .. br.reason .. ")") or "", br.built or 0, br.total or 0))
        end
        if br.state == "refuse" then
          s.retry = tick + Pet.RETRY
          -- le gisement refusé est évité à la revue (un autre gisement connu, s'il y en a un, est essayé d'abord)
          if s.res and s.x then
            st.bad = st.bad or {}
            st.bad[s.res] = st.bad[s.res] or {}
            if not Fl.near_any(st.bad[s.res], s, 1) then st.bad[s.res][#st.bad[s.res] + 1] = { x = s.x, y = s.y } end
          end
        end
        s.state = br.state
      end
      s.built, s.total, s.reason = br.built, br.total, br.reason
      if br.state ~= "fini" and br.state ~= "refuse" then
        if garde then
          mods[#mods + 1] = { id = s.id, product = product_of[s.key] or ("petrole:" .. s.key), state = br.state, missing = br.missing or {},
            reason = br.reason, gain = Pet.GAIN }
        end
      elseif br.state == "fini" then
        Profiler.fstart("pet:champ")
        if garde then extend_site(f, st, s, tick) end
        Profiler.fstop("pet:champ")
        if s.ext_id then
          local eb = Build.brief(f, s.ext_id)
          if eb and eb.state ~= "fini" and eb.state ~= "refuse" then
            mods[#mods + 1] = { id = s.ext_id, product = "petrole:" .. s.key .. ":champ", state = eb.state, missing = eb.missing or {}, reason = eb.reason, gain = Pet.GAIN }
          end
        end
        local items = {}
        for _, it in ipairs(br.quais or {}) do
          local have = stock[it] or 0
          -- fabricable à la main, ou par un exécutant de l'équipe (graphe : l'acier des fours du QG ; moteur réel,
          -- petrole-partie 1618033988 : cellule du moteur bâtie, quai d'acier jamais servi)
          local makeable = (book and book.handcraftable and book:handcraftable(it)) or General.feasible(f, it) == true
          if makeable and have < Pet.FEED_STOCK then items[#items + 1] = { it, Pet.FEED_STOCK - have } end
        end
        if #items > 0 then feeds[#feeds + 1] = { product = "petrole:" .. s.key, id = s.id, items = items, gain = Pet.GAIN } end
      end
    end
  end
  Profiler.fstop("pet:sites")
  Profiler.fstart("pet:soupape")
  Pet.valve_think(f, st, tick) -- lot TV-FLUX (V42)
  Profiler.fstop("pet:soupape")
  Profiler.stop("petrole:think")
  if #mods == 0 and #feeds == 0 then return auto end
  auto = auto or { mods = {}, cap = {}, covered = {}, feeds = {} }
  auto.mods = auto.mods or {}
  auto.feeds = auto.feeds or {}
  for _, m in ipairs(mods) do auto.mods[#auto.mods + 1] = m end
  for _, fd in ipairs(feeds) do auto.feeds[#auto.feeds + 1] = fd end
  return auto
end

--- Machines posées par les sites FINIS de la faction ({ [objet] = n }, lu par General.state) : extracteurs, machines,
--- pompes (rôles de l'implantation), comptées par l'objet qui les pose.
function Pet.built(f)
  local st = f and f.team and f.team.petrole
  local b = f and f.build
  local out = {}
  if not (st and b) then return out end
  for _, s in ipairs(st.sites) do
    local ids = { s.id }
    for _, id in ipairs(s.exts or {}) do ids[#ids + 1] = id end -- lot PETROLE-RANGEE : chevalets des chantiers d'extension finis
    for _, id in ipairs(ids) do
      local p = b.projects[id]
      if p and p.state == "fini" then
        for _, e in ipairs(p.ents or {}) do
          if e.built and e.item and (e.role == "machine" or e.role == "extracteur" or e.role == "pompe") then
            out[e.item] = (out[e.item] or 0) + 1
          end
        end
      end
    end
  end
  return out
end

--- Objets qu'un chantier du lot (site, ou la centrale qu'il attend) réserve sans pouvoir les fabriquer, faute de leur
--- recette (verrouillée) : ils deviennent des objets VOULUS par la recherche (comme Auto.wanted, Capital.wanted) ; la
--- technologie qui les débloque prend de la valeur (moteur réel, petrole-partie : centrale jamais finie en 120 min,
--- poteau moyen verrouillé). nil réglage éteint ou rien à vouloir.
function Pet.wanted(f)
  if not Pet.on() then return nil end
  local st = f and f.team and f.team.petrole
  if not (st and f.build) then return nil end
  local force = game.forces[f.force]
  local out, any = {}, false
  local function add(id)
    local br = id and Build.brief(f, id)
    -- (lot CC-PETROLE : une extension partie sans toute sa matière garde ses manques voulus par la recherche)
    if not (br and (br.state == "reserve" or br.progressif)) then return end
    for _, m in ipairs(br.missing or {}) do
      local r = force and force.recipes[m[1]]
      if r and not r.enabled then out[m[1]] = true; any = true end
    end
  end
  for _, s in ipairs(st.sites) do
    add(s.id)
    if s.ext_id then add(s.ext_id) end -- lot PETROLE-RANGEE
  end
  if #st.sites > 0 then add(f.build.plant) end
  return any and out or nil
end

---------------------------------------------------------------------------------------------------
-- Interface distante de LECTURE (bancs)
---------------------------------------------------------------------------------------------------
local function team_of(key)
  if key == "player" then return State.faction("player") end -- votre équipe n'est pas dans la liste des factions (bancs)
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
        reason = s.reason, x = s.x, y = s.y, ext_id = s.ext_id, ext_state = s.ext_state, exts = s.exts, cov = s.cov, ext_fail = s.ext_fail,
        ext_stop = s.ext_stop }
    end
    -- manques des chantiers (4 premiers) et état de la centrale de l'équipe : lisibilité des bancs
    local function brief_of(id)
      local br = id and f.build and Build.brief(f, id)
      if not br then return nil end
      local miss = {}
      for i = 1, math.min(4, #(br.missing or {})) do miss[i] = br.missing[i][1] .. "x" .. br.missing[i][2] end
      return { state = br.state, missing = miss, built = br.built, total = br.total }
    end
    for i, s in ipairs(st.sites) do
      local b = brief_of(s.id)
      sites[i].missing = b and b.missing or nil
      sites[i].ext = brief_of(s.ext_id) -- lot PETROLE-RANGEE : chantier d'extension en cours (état, manques, entités bâties / prévues)
      local q = s.ext_id and f.build and f.build.projects[s.ext_id]
      sites[i].ext_plan = q and (q.champ or q.rangee_fl) or nil -- ... et ce que son plan couvre (chevalets, écartés, différés ; copies, pas, bus)
      if sites[i].ext_plan and q.champ then sites[i].ext_plan = { n = q.champ.n, total = q.champ.total, skipped = #(q.champ.skipped or {}), deferred = q.champ.deferred, pipes = q.champ.pipes } end
    end
    local why = {}
    for _, k in ipairs(sorted_keys(st.why)) do why[#why + 1] = st.why[k].text end
    return { decisions = st.decisions, known = sorted_keys(st.known), sites = sites, logs = st.logs, why = why,
      plant = f.build and brief_of(f.build.plant) or nil }
  end,
  on = function() return Pet.on() end,
  -- BANCS (lot TV-FLUX, scénario flux-soupape) : adopte un site FINI fictif pour la soupape. Les machines et le coffre sont posés par le banc ;
  -- spec = { every = ticks entre deux mesures, ents = { { name, x, y, recipe }, ... }, outs = { { x, y }, ... } }. Rend vrai.
  valve_bench = function(key, spec)
    local f = team_of(key)
    if not (f and f.team and type(spec) == "table") then return false end
    if not f.build then Build.enable(f, { radius = 3 }) end
    local st = state_of(f)
    local id = 9000001
    local ents = {}
    for _, e in ipairs(spec.ents or {}) do
      ents[#ents + 1] = { name = e.name, x = e.x, y = e.y, dir = 0, recipe = e.recipe, role = "machine", built = true, part = 1 }
    end
    local x0, y0 = math.huge, math.huge
    for _, e in ipairs(ents) do x0, y0 = math.min(x0, e.x), math.min(y0, e.y) end
    f.build.projects[id] = { id = id, state = "fini", ents = ents, outs = spec.outs or {}, quais = {}, spec = { site = "petrole" },
      parts = { { kind = "module", key = "bench", lot = "site", ox = math.floor(x0) - 3, oy = math.floor(y0) - 3, k = 0, w = 16, h = 16 } } }
    f.build.order[#f.build.order + 1] = id -- sans cela l'automatisation éteint le plan directeur (rien à servir) et le site disparaît
    st.sites[#st.sites + 1] = { key = "bench", id = id, items = {}, state = "fini", res = nil, x = 0, y = 0 }
    if type(spec.every) == "number" then Pet.VALVE_EVERY = spec.every end
    st.valve_next = 0
    return true
  end,
  -- BANCS (lot PETROLE-RANGEE, scénario petrole-champ) : adopte un site FINI fictif au gisement `spec.res` en (spec.x, spec.y) ; ses entités (chevalets
  -- role « extracteur », tuyaux role « tuyau ») sont posées par le banc. spec = { res, x, y, ents = { { name, x, y, dir, role }, ... } }. Rend vrai.
  ext_bench = function(key, spec)
    local f = team_of(key)
    if not (f and f.team and type(spec) == "table") then return false end
    if not f.build then Build.enable(f, { radius = 3 }) end
    local st = state_of(f)
    local id = 9000002
    local ents = {}
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for _, e in ipairs(spec.ents or {}) do
      ents[#ents + 1] = { name = e.name, x = e.x, y = e.y, dir = e.dir or 0, role = e.role, recipe = e.recipe, built = true, part = 1, item = e.name }
      x0, y0, x1, y1 = math.min(x0, e.x), math.min(y0, e.y), math.max(x1, e.x), math.max(y1, e.y)
    end
    local quais, outs = {}, {}
    for _, q in ipairs(spec.quais or {}) do quais[#quais + 1] = { x = q.x, y = q.y, item = q.item } end
    for _, o in ipairs(spec.outs or {}) do outs[#outs + 1] = { x = o.x, y = o.y, at = Pet.OUT_AT } end
    -- prio et domaine comme un vrai projet (Build.request) : quai_tasks lit p.prio dès qu'un quai est déclaré (plantage observé le 9/11 au banc petrole-rangee)
    f.build.projects[id] = { id = id, state = "fini", ents = ents, outs = outs, quais = quais, spec = { site = "petrole" }, prio = Build.PRIO, domain = "production",
      parts = { { kind = "module", key = "bench", lot = "site", ox = math.floor(x0), oy = math.floor(y0), k = 0, w = math.ceil(x1 - x0) + 1, h = math.ceil(y1 - y0) + 1 } } }
    f.build.order[#f.build.order + 1] = id
    st.sites[#st.sites + 1] = { key = "bench-champ", id = id, items = spec.items or {}, state = "fini", res = spec.res, x = spec.x, y = spec.y }
    return true
  end,
  -- bancs (lot PETROLE-RANGEE) : chevalets au plus par chantier d'extension (le banc n'a que quelques milliers de ticks)
  ext_batch = function(n)
    if type(n) == "number" and n >= 1 then Pet.EXT_BATCH = math.floor(n) end
    return Pet.EXT_BATCH
  end,
  -- bancs (lot TV-FLUX) : état de la soupape d'une équipe { opened, units, valves = { [site|fluide] = { n, open, total } } }
  valve_status = function(key)
    local f = team_of(key)
    local st = f and f.team and f.team.petrole
    if not st then return nil end
    local valves = {}
    for _, k in ipairs(sorted_keys(st.valves or {})) do
      local v = st.valves[k]
      valves[k] = { n = v.n or 0, open = v.open == true, total = v.total or 0 }
    end
    return { opened = st.valve_opened or 0, units = st.valve_units or 0, calls = st.valve_calls or 0, note = st.valve_note, valves = valves, on = Pet.valve_on(), every = Pet.VALVE_EVERY }
  end,
  -- bancs (lot TV-FLUX) : une mesure de la soupape tout de suite (le banc n'a que 2 500 ticks ; la cadence naturelle reste celle de Pet.think)
  valve_tick = function(key)
    local f = team_of(key)
    local st = f and f.team and f.team.petrole
    if not st then return nil end
    st.valve_next = 0
    return Pet.valve_think(f, st, game.tick)
  end,
  -- bancs : relevé ASCII du terrain d'un site refusé au journal ([FO-PETROLE-CARTE], une fois par raison et par équipe)
  dump = function(v) Pet.DUMP = (v == true) end,
  -- bancs : tâches du tableau d'un chantier du lot (clé, prise par, priorité, objets, états), pour savoir pourquoi il n'avance pas
  tasks = function(key, id)
    local f = team_of(key)
    if not f then return nil end
    local out = {}
    for _, tk in ipairs(Board.get(f).list or {}) do
      if tk.key and tk.key:find("ia1d:" .. tostring(id) .. ":", 1, true) == 1 then
        local its = {}
        for _, it in ipairs(tk.items or {}) do its[#its + 1] = tostring(it[1]) .. "x" .. tostring(it[2]) end
        out[#out + 1] = string.format("%s worker=%s prio=%s items=[%s] fails=%s retry=%s", tk.key, tostring(tk.worker), tostring(tk.prio),
          table.concat(its, ","), tostring(tk.fails), tostring(tk.retry_at or tk.pause_until or tk.paused))
      end
    end
    return out
  end,
})

return Pet
