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
local Co = require("shared.ai3.commande") -- lot s44 COMMANDE-UPGRADE
local Am = require("shared.ai3.amelioration") -- lot AMELIORATION : montée par bloc
local Sw = require("shared.team.rebuild_sweep") -- lecture seule : ce qui manque encore aux projets rouverts (Sw.rebuild_needs)
local Dg = require("shared.team.degel") -- lot AGES : le gel du centre n'est pas indéfini
local Gen = require("shared.ai3.general")
local R = require("shared.ai3.reglages")
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Outposts = require("script.faction.outposts")
local PlacesQG = require("script.ai3.places_qg") -- lots TUILES-RESERVEES et TAMPON-MINERAI : le centre saute une tuile réservée au plan ou une tuile de ressource
local General = require("script.ai3.general")
local Profiler = require("script.core.profiler")
local Auto = require("script.ai3.automatisation") -- lot IA3-e : Auto.capital_steps (objets du dépliage)
local CentreQG = require("script.faction.centre_qg") -- lot PD-CENTREQG (D20) : le centre de la faction est lié à son QG
local Voulues = require("script.ai3.voulues") -- lot RECHERCHE-BRAS (A) : objets voulus déclarés par un module

local Capital = {}

-- Réglage de carte fo-war-capital (settings/capital.lua), ALLUMÉ par défaut (correction après revue, 27/10 : la recherche
-- des factions est retardée quand il est allumé, D1 ouvert) ; relu à chaque pensée. Capital.ENABLED = false et l'interface
-- « fo-capital » set_enabled(false) (bancs témoins, rangé dans l'état de la guerre) l'éteignent aussi, même réglage allumé.
-- Il commande les buts sur les bâtiments à niveaux et le centre. Le REMPLACEMENT des machines hors famille (lot AMELIORER)
-- a son propre réglage fo-war-remplacer, ALLUMÉ par défaut : il ne remplace que ce qui est déjà débloqué et ne réclame jamais
-- de recherche ; éteint, la pensée est celle d'avant le lot.
Capital.SETTING = "fo-war-capital"
Capital.ENABLED = true
Capital.SCAN_EVERY = 12   -- pensées (1 min à une pensée toutes les 5 s)
Capital.RADIUS = 64       -- tuiles autour du QG : la base (les tourelles des avant-postes sont suivies à part)
Capital.CENTER_OFFSETS = { { 0, 14 }, { 14, 0 }, { -14, 0 }, { 0, -14 }, { 14, 14 }, { -14, 14 } }
Capital.CENTER_SEARCH = 12
Capital.HISTORY = 32
Capital.REFUSE_TICKS = 5 * 3600 -- une cible refusée par l'exécutant est écartée 5 min (pas de nouvel essai à chaque pensée)
Capital.RECHECK_TICKS = 3600    -- lot AGES : un refus « cc-families » (familles à monter connues) n'écarte le centre qu'1 min

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

Capital.SETTING_REPLACE = "fo-war-remplacer"

--- Remplacement des machines hors famille (lot AMELIORER) : réglage fo-war-remplacer (défaut : allumé).
function Capital.replace_on()
  local war = State.war()
  if not (Capital.ENABLED == true and Levels ~= nil and not (war and war.capital_off)) then return false end
  local s = settings.global[Capital.SETTING_REPLACE]
  return s == nil or s.value == true
end

function Capital.on()
  local war = State.war()
  if not (Capital.ENABLED == true and Levels ~= nil and not (war and war.capital_off)) then return false end
  local s = settings.global[Capital.SETTING]
  return s ~= nil and s.value == true
end

Capital.SETTING_BLOCS = "fo-war-amelioration"

--- Lot AMELIORATION : montée par BLOC (réglage fo-war-amelioration, défaut : allumé). Éteint : un bâtiment par pensée, relevé de 64 tuiles.
function Capital.blocs_on()
  local s = settings.global[Capital.SETTING_BLOCS]
  return s == nil or s.value == true
end

--- Un des deux mécanismes est allumé.
function Capital.any_on() return Capital.on() or Capital.replace_on() end

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
  for _, t in ipairs(R.RANG_TYPES) do -- lot AMELIORATION : tapis et bras
    filters[#filters + 1] = { filter = "type", type = t, mode = #filters > 0 and "or" or nil }
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
    local rang = false
    for _, t in ipairs(R.RANG_TYPES) do if p.type == t then rang = true end end
    local speed = get(p, "crafting_speed") or (rang and get(p, R.RANG_SPEED[p.type])) or nil
    local reach = nil
    if p.type == R.RANG_REACH.type then
      local a, b = get(p, R.RANG_REACH.pickup), get(p, R.RANG_REACH.drop)
      if a and b then reach = string.format("%.2f,%.2f>%.2f,%.2f", a[1] or a.x, a[2] or a.y, b[1] or b.x, b[2] or b.y) end
    end
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
      c.by[n] = { type = p.type, group = group, speed = speed, item = item, energy = energy, cats = cats, rang = rang or nil, reach = reach,
        w = math.ceil(cb.right_bottom.x - cb.left_top.x - 1e-6), h = math.ceil(cb.right_bottom.y - cb.left_top.y - 1e-6) }
      c.names[#c.names + 1] = n
    end
  end
  mcat = c
  return c
end
function Capital.mproto(name) return machine_catalog().by[name] end
--- Noms (triés) du catalogue des machines : successeurs à emprise plus grande du rétrofit (shared/team/box_upgrade.lua, Bu.grown_successors).
function Capital.machine_names() return machine_catalog().names end

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
  local blocks = {}
  local function add(e, ref, block)
    if e and e.valid and e.unit_number and cat.by[e.name] then
      ents[e.unit_number] = e
      if ref then refs[e.unit_number] = ref end
      blocks[e.unit_number] = block
    end
  end
  for _, e in ipairs(f.smelters or {}) do add(e, nil, "qg") end
  local b = f.build
  if b and b.projects then
    for _, pid in ipairs(sorted_keys(b.projects)) do
      for _, pe in ipairs(b.projects[pid].ents or {}) do
        if pe.built and cat.by[pe.name] then
          local e = surface.find_entity(pe.name, { pe.x, pe.y })
          if not (e and e.valid) and cat.by[pe.name].rang then
            -- Tapis ou bras déjà monté : le plan garde le nom du rang 1, l'entité porte celui du rang supérieur (même type, même place).
            for _, c in ipairs(surface.find_entities_filtered({ position = { pe.x, pe.y }, radius = 0.3, type = cat.by[pe.name].type, force = f.force })) do
              if c.valid and cat.by[c.name] then e = c break end
            end
          end
          if e and e.valid and e.force.name == f.force then add(e, pe, "p" .. pid) end
        end
      end
    end
  end
  -- Lot s44 COMMANDE-UPGRADE : les bâtiments de la force dans une zone d'amélioration prioritaire du joueur (f.team.commande) entrent
  -- au relevé (catalogue des machines, rayon borné de la zone) ; ceux déjà relevés gardent leur bloc.
  for _, z in ipairs(Co.upgrade_zones(f.team and f.team.commande)) do
    local zs = game.surfaces[z.surface or 1]
    if zs and zs.index == surface.index then
      for _, e in ipairs(surface.find_entities_filtered({ position = { z.x, z.y }, radius = z.r, force = f.force, name = cat.names })) do
        if e.valid and e.unit_number and not ents[e.unit_number] then add(e, nil, "zone" .. z.id) end
      end
    end
  end
  local list = {}
  local ws = defines.entity_status and defines.entity_status.working
  for _, id in ipairs(sorted_keys(ents)) do
    local e = ents[id]
    -- Un tapis n'a pas d'état : il est « en marche » (sa montée rapporte à plein).
    local st = e.status
    -- Lot AMELIORATION-CONTINUE : position et direction (Am.run_order : les pièces d'un lot se suivent le long de la ligne).
    local pos = e.position
    list[#list + 1] = { id = id, name = e.name, working = (st == nil) or (ws ~= nil and st == ws), block = blocks[id],
      x = pos.x, y = pos.y, dir = e.direction }
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

--- Lot AGES : le meilleur bâtiment d'une famille (le niveau le plus haut sous `cond`) où qu'il soit sur la surface du QG, ou nil.
--- Le jeu compte la condition du centre (Q16) sur TOUTE la surface (script/levels/levels.lua, Levels.census) ; le relevé du
--- planificateur ne regarde que le rayon du QG et les tourelles suivies : une famille bloquante dont les bâtiments sont loin
--- (murs d'un avant-poste, foreuses) lui restait invisible, le centre était choisi puis refusé « cc-families » (mesuré, 2
--- graines : 3 refus sur 3 centres choisis).
--- Une famille a-t-elle un bâtiment au niveau voulu par la condition du centre (cond ou plus), où que ce soit sur la surface ?
local function top_exists(f, surface, fam, cond)
  local names = {}
  for n = math.min(cond, fam.max), fam.max do names[#names + 1] = L.name(fam, n) end
  Profiler.fstart("ws:cap-top")
  local n = surface.count_entities_filtered({ force = f.force, name = names, limit = 1 })
  Profiler.fstop("ws:cap-top")
  return n > 0
end

local far_best_raw
local function far_best(f, surface, fam, cond)
  return Profiler.fwrap("ws:cap-far", far_best_raw, f, surface, fam, cond)
end
local FAR_LEVELS = 6 -- niveaux cherchés un à un depuis le haut ; en dessous, UNE recherche pour tous les niveaux restants
function far_best_raw(f, surface, fam, cond) -- (affecte la locale déclarée plus haut : « local function » en ouvrait une seconde, far_best appelait nil)
  local top = math.min(cond, fam.max) - 1
  for n = top, math.max(1, top - FAR_LEVELS + 1), -1 do
    local found = surface.find_entities_filtered({ force = f.force, name = L.name(fam, n), limit = 1 })
    local e = found and found[1]
    if e and e.valid and e.unit_number then return e end
  end
  local rest = {}
  for n = 1, top - FAR_LEVELS do rest[#rest + 1] = L.name(fam, n) end
  if #rest > 0 then
    local found = surface.find_entities_filtered({ force = f.force, name = rest, limit = 1 })
    local e = found and found[1]
    if e and e.valid and e.unit_number then return e end
  end
  return nil
end

--- Lot AMELIORATION : bâtiments à niveaux des PROJETS du plan directeur (bandes de champ, fonderies, ateliers : le gros de la base,
--- hors des 64 tuiles du QG). Chaque projet est un BLOC « p<numéro> » à gabarit FIXE (un bâtiment plus grand n'y tiendrait pas).
--- Rend une liste { e = entité, block = clé } ; jamais un bâtiment d'une autre force (celui du joueur).
local function project_ents(f)
  local out = {}
  local b = f.build
  if not (b and b.projects and f.hq and f.hq.valid) then return out end
  local surface = f.hq.surface
  for _, pid in ipairs(sorted_keys(b.projects)) do
    local p = b.projects[pid]
    for _, pe in ipairs(p.ents or {}) do
      if pe.built and not pe.dropped and pe.x and L.parse(pe.name) then
        local fam = L.parse(pe.name)
        local e = surface.find_entity(pe.name, { pe.x, pe.y })
        if not (e and e.valid) then
          -- Montée à la main ou par un lot précédent : le nom du plan est celui du niveau 1, l'entité porte un nom de niveau.
          local ptype = get(game.entity_prototypes[pe.name], "type")
          for _, c in ipairs(surface.find_entities_filtered({ position = { pe.x, pe.y }, radius = 0.4, type = ptype, force = f.force })) do
            if c.valid and L.parse(c.name) == fam then e = c break end
          end
        end
        if e and e.valid and e.unit_number and e.force.name == f.force then out[#out + 1] = { e = e, block = "p" .. pid } end
      end
    end
  end
  return out
end

--- Relevé des bâtiments à niveaux de la force : { list = { {id, name, working} }, center = {id, name}, blockers = familles que
--- le JEU dit bloquantes (condition Q16, relevé de toute la surface) }.
local function scan(f, c)
  local surface = f.hq.surface
  local by_id = {}
  -- Lot AGES : la condition du centre telle que le jeu la compte, et le meilleur bâtiment de chaque famille bloquante.
  -- Le recensement du jeu (toute la surface : 12 balayages, mesuré : 100 s sur 3 h à 3 factions, ×33 pour capital:decide) n'est PAS
  -- refait à chaque relevé : le refus « cc-families » de l'exécutant nomme les familles bloquantes (c.eblock, Capital.pay), et seules
  -- celles-là sont revérifiées ici, une recherche chacune (une famille qui a un bâtiment au niveau voulu ne bloque plus).
  local cc0 = Levels.cc(game.forces[f.force])
  local lvl0 = 0
  if cc0 and cc0.valid then
    local _, n0 = L.parse(cc0.name)
    lvl0 = n0 or 0
  end
  local blockers
  local eb = c.eblock
  if eb and eb.level == lvl0 and lvl0 >= 1 and lvl0 < CFAM.max then
    local cond = L.cc_condition_level(lvl0)
    blockers = {}
    c.far = c.far or {}
    for _, key in ipairs(eb.keys) do
      local fam = L.by_key[key]
      if fam and not top_exists(f, surface, fam, cond) then
        blockers[#blockers + 1] = key
        -- Le bâtiment qu'on fait monter est retenu d'un relevé à l'autre (il change de numéro à chaque niveau : Capital.pay le suit).
        local e = c.far[key]
        if not (e and e.valid and e.force.name == f.force and L.parse(e.name) == fam) then e = far_best(f, surface, fam, cond) end
        if e then
          by_id[e.unit_number] = e
        end
        c.far[key] = e or nil
      end
    end
    if #blockers == 0 then c.eblock, blockers = nil, nil end
  else
    c.eblock = nil
  end
  for _, e in ipairs(surface.find_entities_filtered({ force = f.force, name = NAMES, position = f.hq_pos,
      radius = Capital.RADIUS })) do
    if e.valid and e.unit_number then by_id[e.unit_number] = e end
  end
  local blk, fixed = {}, {}
  for _, id in ipairs(sorted_keys(f.turrets)) do
    local t = f.turrets[id]
    if t and t.valid and t.unit_number and L.parse(t.name) then
      by_id[t.unit_number] = t
      local ow = State.owner(t.unit_number)
      blk[t.unit_number] = ow and ow.oid and ("t" .. ow.oid) or nil
    end
  end
  -- Lot AMELIORATION : les projets du plan directeur entrent au relevé, chacun comme un bloc (un bâtiment du rayon du QG qui
  -- appartient à un projet suit son projet).
  if Capital.blocs_on() then
    for _, pr in ipairs(project_ents(f)) do
      local u = pr.e.unit_number
      by_id[u], blk[u], fixed[u] = pr.e, pr.block, true
    end
  end
  local ents, list = {}, {}
  local by_family = {}
  for _, id in ipairs(sorted_keys(by_id)) do
    local e = by_id[id]
    ents[#ents + 1] = e
    local ws = defines.entity_status and defines.entity_status.working
    local working = ws ~= nil and e.status == ws
    list[#list + 1] = { id = id, name = e.name, working = working, block = blk[id] or "qg", fixed = fixed[id] or nil }
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
  return { list = list, center = center, blockers = blockers }
end

--- Niveau réel du centre de la force (0 : aucun), lu au module des niveaux. Lot C1 : lu aussi quand les améliorations sont
--- éteintes ou pour votre équipe, pour que le journal ne dise plus « centre niveau 0 » d'un centre de niveau 1 ou plus.
local function cc_level_of(f)
  local cc = Levels and game.forces[f.force] and Levels.cc(game.forces[f.force])
  if cc and cc.valid then
    local _, n = L.parse(cc.name)
    return n or 0
  end
  return 0
end

--- Relevé complet : bâtiments à niveaux et centre (factions seulement), machines hors famille (toutes les équipes).
local function census_of(f, c)
  local census
  if f.is_player or not Capital.on() then
    -- Votre équipe : ni centre à poser ni bâtiments à niveaux du joueur (même force) ; seulement ses propres machines. De
    -- même quand fo-war-capital est éteint : seul le remplacement des machines (fo-war-remplacer) décide.
    census = { list = {}, center = nil, no_center = true }
    c.ents, c.by_family, c.cc_level = {}, {}, cc_level_of(f)
    -- Lot AMELIORATION : votre équipe monte aussi les bâtiments à niveaux de SES projets (jamais ceux du joueur), jusqu'au plafond du
    -- centre du joueur (sa force), payés avec son coffre d'équipe (Capital.own_upgrade), jamais avec le coffre du centre du joueur.
    if f.is_player and Capital.on() and Capital.blocs_on() and Levels and f.hq and f.hq.valid then
      local cc = Levels.cc(game.forces[f.force])
      if cc and cc.valid then
        local ents, list = {}, {}
        local by_family = {}
        local ws = defines.entity_status and defines.entity_status.working
        local seen = {}
        for _, pr in ipairs(project_ents(f)) do
          local e = pr.e
          if not seen[e.unit_number] then
            seen[e.unit_number] = true
            ents[#ents + 1] = e
            list[#list + 1] = { id = e.unit_number, name = e.name, working = ws ~= nil and e.status == ws, block = pr.block, fixed = true }
            local fam, n = L.parse(e.name)
            if fam then by_family[fam.key] = math.max(by_family[fam.key] or 0, n) end
          end
        end
        table.sort(list, function(a, b) return a.id < b.id end)
        census.list, census.center = list, { id = cc.unit_number, name = cc.name }
        c.ents, c.by_family = ents, by_family
        -- Lot S42 QG-NIVEAUX (chantier 2.3 du DC : centre de votre équipe resté au niveau 1 pendant 4 h 15, « equipe-joueur ») : le
        -- centre de votre force devient un candidat de votre équipe, payé avec son coffre d'équipe (Capital.pay). La condition Q16 est
        -- comptée par le jeu sur TOUTE la force (vos bâtiments compris) : le refus « cc-families » nomme les familles (c.eblock), et
        -- seules celles-là sont revérifiées ici, une recherche chacune. La chaîne ne monte que les bâtiments des projets de l'équipe
        -- (jamais les vôtres) : une famille que vous seul possédez reste dite au journal ([FO-CAPITAL-CENTRE], condition:<famille>).
        census.no_center = nil
        local lvl0 = c.cc_level or 0
        local eb = c.eblock
        if eb and eb.level == lvl0 and lvl0 >= 1 and lvl0 < CFAM.max then
          local cond = L.cc_condition_level(lvl0)
          local bl = {}
          for _, key in ipairs(eb.keys) do
            local fam = L.by_key[key]
            if fam and not top_exists(f, f.hq.surface, fam, cond) then bl[#bl + 1] = key end
          end
          if #bl > 0 then census.blockers = bl else c.eblock = nil end
        else
          c.eblock = nil
        end
      end
    end
  else
    census = scan(f, c)
  end
  if Capital.replace_on() then
    local m = scan_machines(f)
    census.machines = m.list
    c.mach_ents, c.mach_refs = m.ents, m.refs
  else
    c.mach_ents, c.mach_refs = {}, {}
  end
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
  if d.bloc then
    return string.format("bloc %s : %s %d -> %d x%d batiment(s) sur %d au plus bas", d.bloc, d.family, d.from, d.to, d.n or 1,
      d.bloc_low or 0)
  end
  if d.replace then
    return string.format("remplacer %s -> %s x%d%s", d.replace.from, d.replace.to, d.replace.n,
      (d.fab and d.fab > d.replace.n) and (" sur un lot demande de " .. d.fab .. ", " .. (d.remaining or 0) .. " a monter dans le bloc") or "")
  end
  return string.format("%s %d -> %d", d.family, d.from, d.to)
end

--- Lot AMELIORATION : une ligne [FO-AMELIORATION] par (bloc, famille) à chaque CHANGEMENT d'état (décidé, refusé et sa cause, niveau,
--- taille) : jamais un bloc qui ne monte pas sans dire pourquoi.
--- Format : « [FO-AMELIORATION] <faction> : bloc <clé> famille <famille> : decide n/bas niveau a -> b (taille t) a <min> min » ou
--- « ... : refuse (<cause>) niveau a, bas/taille au plus bas a <min> min ». Causes : plafond-centre, sans-centre, emprise,
--- sans-cout:<objets>, refus-recent, niveau-max, sans-gain. État gardé : f.team.capital.am_sig[bloc|famille] (chaîne).
function Capital.log_blocs(f, c, d, tick)
  local rep = d and d.report
  if not rep then return end
  c.am_sig = c.am_sig or {}
  c.refus = c.refus or {} -- lu par la vue « Cerveau » : DERNIER refus par bloc|famille { cause = mot fixe, tick }, un état par bloc du relevé
  local seen = {}
  for _, row in ipairs(rep) do
    local k = row.block .. "|" .. row.family
    seen[k] = true
    if row.state == "refuse" then
      local word = tostring(row.cause or ""):match("^[^:]+") or ""
      if not c.refus[k] or c.refus[k].cause ~= word then c.refus[k] = { cause = word, tick = tick } end
    else
      c.refus[k] = nil
    end
    local sig = Am.signature(row)
    if c.am_sig[k] ~= sig then
      c.am_sig[k] = sig
      log(string.format("[FO-AMELIORATION] %s : %s a %.1f min", f.key or "player", Am.line(row), minutes(f, tick)))
    end
  end
  -- Un bloc disparu du relevé (projet fini, détruit) : oublié, sa clé ne reste pas dans la sauvegarde.
  for _, k in ipairs(sorted_keys(c.am_sig)) do
    if not seen[k] then c.am_sig[k], c.refus[k] = nil, nil end
  end
end

--- Lot AMELIORATION-CONTINUE : le PARC des pièces remplaçables (tapis, bras, fours...) par type et par rang, une ligne [FO-AMELIORATION-PARC] par
--- groupe, toutes les Capital.PARC_TICKS ticks de jeu et seulement si un chiffre a changé : la preuve de « plus de la moitié des tapis montés ».
Capital.PARC_TICKS = 5 * 3600
function Capital.log_parc(f, c, census, tick)
  if not (census.machines and #census.machines > 0) then return end
  if tick < (c.parc_next or 0) then return end
  c.parc_next = tick + Capital.PARC_TICKS
  c.parc_sig = c.parc_sig or {}
  local rows = Am.parc(census.machines, Capital.mproto, machine_catalog().names)
  for _, row in ipairs(rows) do
    local line = Am.parc_line(row)
    if c.parc_sig[row.key] ~= line then
      c.parc_sig[row.key] = line
      log(string.format("[FO-AMELIORATION-PARC] %s : %s a %.1f min", f.key or "player", line, minutes(f, tick)))
    end
  end
end

--- Lot C1 : cause de l'état du centre, une ligne [FO-CAPITAL-CENTRE] à chaque CHANGEMENT (jamais un silence sur un centre
--- qui ne monte pas). Causes : reglage-eteint (fo-war-capital), equipe-joueur (le centre est celui du joueur : il le répare et
--- le monte lui-même), famille-absente, objet-absent, niveau-max, sans-valeur, pose, monte (avec les causes qui le bloquent :
--- condition:<famille> = Q16, ou l'objet manquant du coût, ou « refus » récent de l'exécutant).
function Capital.centre_cause(f, d)
  if not Capital.on() then return "reglage-eteint" end
  if f.is_player and not (d and d.centre and d.centre.key) then return "equipe-joueur" end -- lot S42 QG-NIVEAUX : candidat s'il a une cible
  local ce = d and d.centre
  return ce and ce.state or "inconnu"
end

function Capital.log_centre(f, c, d, tick)
  local cause = Capital.centre_cause(f, d)
  local causes = (d and d.centre and d.centre.causes) or {}
  local sig = cause .. "|" .. table.concat(causes, ",") .. "|" .. tostring(c.cc_level or 0) .. "|" .. tostring(d and d.starved or false)
  if c.centre_sig == sig then return end
  c.centre_sig = sig
  local why = #causes > 0 and (" bloque par [" .. table.concat(causes, " ") .. "]") or ""
  local key = d and d.centre and d.centre.key
  log(string.format("[FO-CAPITAL-CENTRE] %s : %s%s ; centre niveau %d%s a %.1f min", f.key or "?", cause, why, c.cc_level or 0,
    key and (", cible '" .. key .. "'") or "", minutes(f, tick)))
  if d and d.starved then
    log(string.format("[FO-CAPITAL-CENTRE] %s : le centre passe devant (reports de valeur %d, valeur du centre %d, prix %d) a %.1f min",
      f.key or "?", (c.defer and c.defer.spent) or 0, d.value or 0, d.work or 0, minutes(f, tick)))
  end
end

--- But « amélioration » de la pensée (nil : aucun, ou éteint). w = poids des familles (B.weights).
function Capital.goal(f, view, book, tick, w)
  if not Capital.any_on() then
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
    zones = Co.upgrade_zones(f.team and f.team.commande), -- lot s44 COMMANDE-UPGRADE : zones d'amélioration prioritaire (rang 0)
    exclude = exclude, defer = c.defer, thaw = (c.thaw and c.thaw.active) or false, tick = tick,
    lead = c.lead or { done = {} }, cash = true, -- lot S42 QG-NIVEAUX : chaîne du centre devant (bornée), centre payé dès que son coût dort au stock
    blocs = (census.list ~= nil and Capital.blocs_on()) or nil, -- lot AMELIORATION
    recon = Capital.blocs_on() and Capital.recon_needs(f) or nil, -- gel de la reconstruction levé sauf manque, objet par objet
    continu = Capital.blocs_on() or nil, -- lot AMELIORATION-CONTINUE : bloc entier à la fabrication, groupe fini d'abord, rang réclamé à la recherche
    last_group = Capital.blocs_on() and c.last_group or nil,
    -- Lot AMELIORATION-CONTINUE : le remplacement ENGAGÉ et les rangs en famine passent devant (Am.engage_update, Am.starved_kinds).
    engaged = Capital.blocs_on() and c.engage and c.engage.group or nil,
    rest = Capital.blocs_on() and c.engage and c.engage.rest or nil,
    starved = Capital.blocs_on() and Am.starved_kinds(c.engage or {}, tick, c.engage and c.engage.kinds) or nil,
    need = function(block)
      -- Un bloc de projet dont le produit manque (f.team.ia3.short, comme repli_opts de la capitalisation) monte d'abord.
      local pid = tonumber(tostring(block):match("^p(%d+)$"))
      local pr = pid and f.build and f.build.projects and f.build.projects[pid]
      local prod = pr and pr.spec and pr.spec.product
      local short = f.team.ia3 and f.team.ia3.short
      if prod and short and (short[prod] or 0) > 0 then return Am.NEED_PCT end
      return 100
    end }
  local d = Cap.choose(L, census, ctx)
  if Capital.blocs_on() then
    -- Lot AMELIORATION-CONTINUE : un pas de l'engagement (lu par la décision suivante : ctx.engaged) et les rangs vus (famine).
    local eng = c.engage or { rest = {}, seen = {}, paid = {} }
    c.engage = eng
    local before = eng.group
    local rg = d.replace and d.replace.group or nil
    Am.engage_update(eng, tick, { start = (not d.all_in) and rg or nil, -- engagé seulement pour une pièce À FABRIQUER
      cost = d.work, -- aucun `threat` : la pile suspend déjà les améliorations sous danger réel, ctx.threat vaut aussi « guerre déclarée »
      alive = (before == nil) or (d.rep_groups and d.rep_groups[before]) or false })
    -- Diagnostic (banc f288d767 : azure n'engage jamais le tapis alors que la famine devait s'en charger) : l'état lu, toutes les 3 min.
    if tick - (eng.diag or -1e9) >= 10800 and #(d.rep_kinds or {}) > 0 then
      eng.diag = tick
      local fam, rest_n = {}, 0
      for _, k in ipairs(sorted_keys(ctx.starved or {})) do fam[#fam + 1] = k end
      for _ in pairs(eng.rest or {}) do rest_n = rest_n + 1 end
      log(string.format("[FO-ENGAGEMENT-DIAG] %s : danger %s ; engage %s ; %d groupe(s) au repos ; famine [%s] ; rangs candidats [%s] ; decision %s a %.1f min",
        f.key or "?", tostring(ctx.threat), tostring(eng.group), rest_n, table.concat(fam, ","), table.concat(d.rep_kinds, ","),
        d.replace and (d.replace.to .. (d.front and " (front)" or "")) or tostring(d.key), minutes(f, tick)))
    end
    eng.kinds = {}
    for i, k in ipairs(d.rep_kinds or {}) do eng.kinds[i] = k end
    if eng.group ~= before then
      log(string.format("[FO-ENGAGEMENT] %s : %s '%s' (rang %s) a %.1f min", f.key or "?", eng.group and "debut" or "fin sans engagement",
        tostring(eng.group or before), d.replace and d.replace.to or "-", minutes(f, tick)))
    end
  end
  Capital.log_blocs(f, c, d, tick)
  Capital.log_parc(f, c, census, tick)
  -- Lot AMELIORATION-CONTINUE : le rang (tapis, bras) à monter en nombre, pas encore débloqué, est déclaré OBJET VOULU (Voulues, source
  -- « amelioration ») ; la règle K1 de Gen (voulue proche devant) et la recherche du cerveau général font le reste. Rien à monter : retiré.
  local rw = {}
  for _, k in ipairs(sorted_keys(d.rang_wanted)) do rw[#rw + 1] = k end
  if Capital.blocs_on() and #rw > 0 then
    if Voulues.set(f, "amelioration", rw, tick) then
      log(string.format("[FO-AMELIORATION] %s : rang a monter en nombre, recherche reclamee pour %s a %.1f min", f.key or "player", table.concat(rw, ","), minutes(f, tick)))
    end
  else
    Voulues.clear(f, "amelioration")
  end
  -- Lot DEFAUT7, étage 3 : fin de l'état « collant » quand la cible du centre change (payé, ou autre centre) : sa durée au journal.
  local old = c.defer
  if old and old.ahead_since and not old.ahead_done and old.key ~= d.gate_key then
    log(string.format("[FO-CAPITAL-CENTRE] %s : fin du collant de '%s' apres %.1f min (cible changee : %s) a %.1f min", f.key or "?",
      old.key, (tick - old.ahead_since) / 3600, tostring(d.gate_key or "aucune"), minutes(f, tick)))
  end
  -- Lot AGES : la valeur des améliorations payées PENDANT que le centre est payable (Cap.starved) ; remise à zéro
  -- quand le centre change (niveau suivant, autre centre) ; le compte vit dans la sauvegarde (nombres et chaînes seulement).
  if d.gate_key then
    if not (c.defer and c.defer.key == d.gate_key) then c.defer = { key = d.gate_key, spent = 0 } end
    c.defer.open = d.gate_open or false
  else
    c.defer = nil
  end
  -- Lot DEFAUT7, étage 3 : le centre passé devant y reste au plus Cap.AHEAD_TICKS (shared/ai3/capital.lua, Cap.ahead_step).
  local ev = Cap.ahead_step(c.defer, d, tick)
  if ev == "debut" then
    log(string.format("[FO-CAPITAL-CENTRE] %s : '%s' reste devant (collant, servi en tete, borne %d min) a %.1f min", f.key or "?",
      d.key, math.floor(Cap.AHEAD_TICKS / 3600), minutes(f, tick)))
  elseif ev == "borne" then
    log(string.format("[FO-CAPITAL-CENTRE] %s : fin du collant de '%s' apres %.1f min (borne atteinte : retour a la regle des reports) a %.1f min",
      f.key or "?", c.defer.key, Cap.AHEAD_TICKS / 3600, minutes(f, tick)))
  end
  -- Lot S42 QG-NIVEAUX : un pas de l'état « chaîne devant » (shared/ai3/capital.lua, Cap.lead_step) ; une ligne par changement.
  local lev
  c.lead, lev = Cap.lead_step(c.lead, d, d.gate_key, tick)
  if lev == "debut" then
    log(string.format("[FO-CAPITAL-CENTRE] %s : chaine du centre devant : '%s' ouvre '%s' (borne %d min de but cumule) a %.1f min",
      f.key or "?", tostring(d.key), tostring(d.gate_key), math.floor(Cap.LEAD_TICKS / 3600), minutes(f, tick)))
  elseif lev == "borne" then
    log(string.format("[FO-CAPITAL-CENTRE] %s : chaine du centre : borne atteinte pour '%s' (retour au rang ordinaire) a %.1f min",
      f.key or "?", tostring(d.key), minutes(f, tick)))
  end
  if d.cash then
    local sigc = "cash|" .. tostring(d.key)
    if c.cash_sig ~= sigc then
      c.cash_sig = sigc
      log(string.format("[FO-CAPITAL-CENTRE] %s : cout du centre au stock libre, '%s' devient le but (prix %d) a %.1f min", f.key or "?",
        tostring(d.key), d.work or 0, minutes(f, tick)))
    end
  end
  c.wanted = {}
  for _, k in ipairs(sorted_keys(d.wanted)) do c.wanted[k] = true end
  Capital.log_centre(f, c, d, tick)
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
    local unit = nil
    if d.unit then
      unit = {}
      for i, it in ipairs(d.unit) do unit[i] = { it[1], it[2] } end
    end
    c.current = { key = d.key, id = d.id, family = d.family, from = d.from, to = d.to, build = d.build or nil,
      center = d.center or nil, value = d.value, work = d.work, score = d.score, cost = cost, ids = ids,
      bloc = d.bloc, n = d.n, unit = unit, bloc_low = d.bloc_low,
      replace = d.replace and { from = d.replace.from, to = d.replace.to, n = d.replace.n, group = d.replace.group } or nil }
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
  if not Capital.any_on() then return nil end
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
    if pos and PlacesQG.on_resource(surface, name, pos) then pos = nil end -- lot TAMPON-MINERAI : jamais sur une ressource (Sm.forbidden)
    if pos and not PlacesQG.is_reserved(f, name, pos) then
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
  if e.type == R.RANG_HALF then args.type = e.belt_to_ground_type end -- entrée ou sortie du souterrain
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
    type = args.type, fast_replace = true, spill = false, raise_built = true, create_build_effect_smoke = false })
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
  -- Le plan garde le nom du rang 1 pour un tapis ou un bras (M.size ne connaît pas tous les rangs ; la reconstruction cherche par TYPE).
  if ref and not tp.rang then ref.name = to end
  return new
end

--- Paie un lot de remplacements (d.ids) : chaque machine refusée est écartée seule, 5 min. Rend le nombre fait et le dernier
--- motif de refus.
local function pay_replace(f, c, d, tick, limit)
  local n, why = 0, nil
  c.refused_until = c.refused_until or {}
  for i, id in ipairs(d.ids or {}) do
    if limit and i > limit then break end -- lot AMELIORATION-CONTINUE : un paiement partiel ne dépasse pas ce que le cerveau a réservé
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

--- Lot C1 : pourquoi la décision en cours n'est PAS payée à cette pensée, une ligne [FO-CAPITAL-ATTENTE] à chaque CHANGEMENT de
--- cause (jamais un silence sur une amélioration décidée qui n'arrive pas). Causes : pile (un cadre réparer / protéger /
--- survivre retient, script/team/team.lua), reconstruction (SANS-GEL), non-reserve (le cerveau n'a pas réservé le coût au stock
--- virtuel : un projet plus prioritaire le prend), stock-libre (le stock libre ne couvre pas le coût : objets manquants).
function Capital.attente(f, cause, tick, detail)
  if not Capital.any_on() then return end
  local c = f.team and f.team.capital
  local d = c and c.current
  if not d then return end
  local sig = d.key .. "|" .. cause .. "|" .. (detail or "")
  if c.attente_sig == sig then return end
  c.attente_sig = sig
  log(string.format("[FO-CAPITAL-ATTENTE] %s : '%s' decide mais non paye, cause %s%s a %.1f min", f.key or "?", d.key, cause,
    detail and (" (" .. detail .. ")") or "", minutes(f, tick)))
end

--- Lot AGES : le gel du centre est-il levé (dernier pas de Capital.thaw_step) ?
function Capital.thaw_active(f)
  local c = f.team and f.team.capital
  return (c and c.thaw and c.thaw.active) or false
end

--- Lot AGES : un pas du compte de gel du centre (appelé par script/team/team.lua à chaque pensée, avec `held` = une garde de la pile ou
--- de la reconstruction gèle les améliorations). Rend vrai quand le centre, lui seul, passe malgré le gel : gel cumulé au-delà de
--- Dg.AFTER et défense minimale du QG tenue (S1 : hors de péril ; sans relevé de S1, rien ne passe). Une ligne [FO-CAPITAL-DEGEL] par
--- changement.
function Capital.thaw_step(f, held, tick)
  if not Capital.on() or f.is_player then return false end
  local c = state_of(f)
  local d = c.defer
  local s1 = f.team and f.team.s1
  local was = c.thaw and c.thaw.active or false
  c.thaw = Dg.step(c.thaw, { key = d and d.key or nil, open = d and d.open or false, held = held, tick = tick,
    floor_ok = (s1 ~= nil and s1.was == false) })
  if c.thaw.active ~= was then
    log(string.format("[FO-CAPITAL-DEGEL] %s : %s a %.1f min (gel cumule %.1f min, defense minimale %s)", f.key or "?",
      c.thaw.active and "le centre passe malgre le gel" or "le gel reprend", minutes(f, tick), c.thaw.frozen / 3600,
      (s1 and s1.was == false) and "tenue" or "sous le plancher"))
  end
  return c.thaw.active
end

--- Lot AMELIORATION : ce que la reconstruction des projets rouverts prendra encore au coffre, { [objet] = quantité } (nil : rien). Lecture
--- seule du lot reconstruction (shared/team/rebuild_sweep.lua, Sw.rebuild_needs).
function Capital.recon_needs(f)
  local b = f.build
  if not (b and b.projects and b.order) then return nil end
  local list = Sw.rebuild_needs(b.projects, b.order)
  if #list == 0 then return nil end
  local m = {}
  for _, it in ipairs(list) do m[it[1]] = it[2] end
  return m
end

--- Lot AMELIORATION : monte UN bâtiment de votre équipe d'un niveau, payé avec son COFFRE d'équipe (jamais le coffre du centre du joueur,
--- que Levels.start tire en premier) ; remplacement rapide du module des niveaux (Levels.swap). Mêmes règles que Levels.preview, sauf
--- l'emprise : un bloc de votre équipe ne grandit pas (gabarit du plan). Rend la nouvelle entité, ou nil et le motif.
function Capital.own_upgrade(f, e)
  local fam, n = L.parse(e.name)
  if not fam or n >= fam.max then return nil, "max" end
  local ok = L.check(fam, n + 1, cc_level_of(f))
  if not ok then return nil, "plafond" end
  if L.footprint(fam, n) ~= L.footprint(fam, n + 1) then return nil, "emprise" end
  local cost = L.cost(fam, n + 1)
  for _, it in ipairs(cost) do
    if Stock.count(f, it[1]) < it[2] then return nil, "stock" end
  end
  local ratio = e.get_health_ratio() or 1
  local new = Levels.swap(e, L.name(fam, n + 1))
  if not (new and new.valid) then return nil, "echec" end
  for _, it in ipairs(cost) do
    Stock.remove(f, it[1], it[2])
    f.team.consumed[it[1]] = (f.team.consumed[it[1]] or 0) + it[2]
  end
  local mh = get(new.prototype, "max_health")
  if mh then new.health = mh * ratio end
  return new
end

--- Lot AMELIORATION : un bâtiment du lot, monté ; les registres qui le tenaient suivent la nouvelle entité (fours du QG, propriété).
--- Le nom du plan directeur (f.build, niveau 1) reste : la reconstruction cherche par TYPE (script/team/rebuild_sweep.lua).
local function upgrade_one(f, c, e, d)
  local old_unit = e.unit_number
  local owner = State.owner(old_unit)
  local slot
  for i, s in ipairs(f.smelters or {}) do
    if s == e then slot = i break end
  end
  local new, why
  if f.is_player then
    new, why = Capital.own_upgrade(f, e)
  else
    local ok, res, _, n = Levels.start(e, nil, { inventories = Stock.inventories(f) })
    if ok and n and n.valid then
      new = n
      for _, it in ipairs(d.unit or {}) do f.team.consumed[it[1]] = (f.team.consumed[it[1]] or 0) + it[2] end
    else
      why = res
    end
  end
  if not new then return false, why end
  if slot then f.smelters[slot] = new end
  if owner then
    if owner.kind == "turret" then
      Outposts.add_turret(f, new, owner.oid, 0) -- l'ancienne sort de f.turrets à son on_entity_destroyed
    else
      State.disown(old_unit) -- avant l'événement de destruction : sinon une foreuse remplacée compterait comme perdue
      State.own(new, f.id, owner.kind, owner.oid)
    end
  end
  return true
end

--- Lot AMELIORATION : paie n bâtiments du lot en cours (d.ids dans l'ordre) ; chaque refus écarte le bâtiment 5 min
--- (c.refused_until["e:<numéro>"], lu par la règle), un manque de matière arrête le lot. Rend le nombre monté et le dernier motif.
local function pay_bloc(f, c, d, n, tick)
  local done, why = 0, nil
  c.refused_until = c.refused_until or {}
  for i = 1, math.min(n or d.n or 1, #(d.ids or {})) do
    local id = d.ids[i]
    local e = find_entity(c, id)
    local ok, w
    if e and e.valid then
      ok, w = upgrade_one(f, c, e, d)
    else
      w = "disparu"
    end
    if ok then
      done = done + 1
    else
      why = w
      if w == "no-resources" or w == "stock" then break end
      c.refused_until["e:" .. id] = tick + Capital.REFUSE_TICKS
    end
  end
  return done, why
end

--- Paie l'amélioration prête (plan.ia3.pay : coût réservé au stock virtuel par la pensée pure) si le stock LIBRE la
--- couvre. Rend le nombre d'améliorations faites.
function Capital.pay(f, surface, tick, plan, stock, only_center)
  local list = plan and plan.ia3 and plan.ia3.pay
  if not Capital.any_on() then return 0 end
  local c = state_of(f)
  local d = c.current
  if only_center and not (d and d.center) then return 0, true end -- lot AGES : gel levé pour le centre seulement (2e valeur : rien tenté)
  if not list or #list == 0 then
    if d then
      -- Lot AGES : le stock libre est dit aussi ici (essai 6 : « non-reserve » 73 min de suite pour le centre d'azure avec du fer libre,
      -- sans que le journal dise quel objet manquait).
      local have = {}
      for _, it in ipairs(d.cost or {}) do have[#have + 1] = it[1] .. " " .. ((stock or {})[it[1]] or 0) .. "/" .. it[2] end
      Capital.attente(f, "non-reserve", tick, "aucun paiement prevu par le cerveau ; stock libre : " .. table.concat(have, ", "))
    end
    return 0
  end
  if d then
    local reserved = false
    for _, p in ipairs(list) do if p.target == d.key then reserved = true end end
    local have = {}
    for _, it in ipairs(d.cost) do have[#have + 1] = it[1] .. " " .. (stock[it[1]] or 0) .. "/" .. it[2] end
    if not reserved then
      -- stock libre listé : couvert -> un projet plus prioritaire a pris le coût au stock virtuel ; sinon la matière manque.
      Capital.attente(f, "non-reserve", tick, (has_list(stock, d.cost) and "stock libre couvre : " or "stock libre : ")
        .. table.concat(have, ", "))
    elseif not has_list(stock, d.cost) then
      Capital.attente(f, "stock-libre", tick, table.concat(have, ", "))
    end
  end
  local done = 0
  for _, p in ipairs(list) do
    -- Un but dont le mécanisme a été éteint depuis sa décision n'est pas payé.
    local allowed = d and ((d.replace and Capital.replace_on()) or (not d.replace and Capital.on()))
    if d and allowed and p.target == d.key and has_list(stock, p.cost or d.cost) then
      local ok, why
      local n_done = 1
      if d.bloc then
        n_done, why = pay_bloc(f, c, d, p.n, tick)
        ok = n_done > 0
        if ok then why = nil end
      elseif d.replace then
        n_done, why = pay_replace(f, c, d, tick, p.n)
        ok = n_done > 0
        if ok then why = nil end
      elseif d.build then
        ok, why = place_center(f, c, d, tick)
        if ok then CentreQG.relink(f, "pose-capital") end
      else
        -- Le centre n'est pas dans le relevé des bâtiments (familles ordinaires) : il est lu au module des niveaux.
        local e
        if d.center then
          e = Levels.cc(game.forces[f.force])
          if e and e.unit_number ~= d.id then e = nil end
        else
          e = find_entity(c, d.id)
        end
        if e and f.is_player and not d.center then
          -- Lot S42 QG-NIVEAUX : bâtiment de la chaîne de VOTRE équipe : coffre d'équipe et gabarit du plan (Capital.own_upgrade), jamais Levels.start.
          ok, why = upgrade_one(f, c, e, d)
        elseif e then
          local owner = State.owner(d.id)
          local res, info, new
          -- Lot PD-CENTREQG : le centre lié (indestructible, non minable) est libéré le temps du remplacement, puis le
          -- centre courant (le nouveau, ou l'ancien sur un refus) est relié au QG.
          if d.center then CentreQG.release(f, e) end
          local far_key
          for _, k in ipairs(sorted_keys(c.far)) do
            if c.far[k] and c.far[k].valid and c.far[k].unit_number == d.id then far_key = k end
          end
          ok, res, info, new = Levels.start(e, nil, { inventories = Stock.inventories(f) })
          if d.center then CentreQG.relink(f, ok and "amelioration" or "amelioration-refusee") end
          why = res
          -- Lot AGES : un refus « cc-families » dit quelles familles bloquent (le recensement du jeu couvre toute la surface, celui
          -- du planificateur la base) et ce que le planificateur croyait voir près du QG.
          if res == "cc-families" and info and info.blocking then
            c.eblock = { keys = {}, level = c.cc_level or 0 }
            for i, k in ipairs(info.blocking) do c.eblock.keys[i] = k end
            local seen = {}
            for _, k in ipairs(sorted_keys(c.by_family)) do seen[#seen + 1] = k .. "=" .. c.by_family[k] end
            why = res .. " [bloquent " .. table.concat(info.blocking, " ") .. " ; vu pres du QG " .. table.concat(seen, " ") .. "]"
          end
          if ok and new and new.valid then
            for _, it in ipairs(d.cost) do f.team.consumed[it[1]] = (f.team.consumed[it[1]] or 0) + it[2] end
            if owner and owner.kind == "turret" then Outposts.add_turret(f, new, owner.oid, 0) end
            -- Lot AGES : le bâtiment éloigné qu'on fait monter garde sa piste (nouveau numéro à chaque niveau).
            if far_key then c.far[far_key] = new end
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
        c.upgrades = (c.upgrades or 0) + n_done
        local value = d.value or 0
        if d.bloc and (d.n or 0) > 0 then value = math.floor(value * n_done / d.n) end
        if not d.center and c.defer and c.defer.open then c.defer.spent = (c.defer.spent or 0) + value end -- lot AGES
        local m = {}
        for _, it in ipairs(d.cost) do m[it[1]] = it[2] end
        if d.bloc then
          m = {}
          for _, it in ipairs(d.unit or {}) do m[it[1]] = it[2] * n_done end
        end
        if d.replace then
          m = {}
          m[d.replace.to] = n_done
        end
        log(string.format("[FO-CAPITAL] %s : amelioration payee '%s' (%s) valeur %d cout %d, paye %s a %.1f min",
          f.key or "?", d.key, Capital.describe(d), d.value or 0, d.work or 0, Gen.fmt_map(m), minutes(f, tick)))
        if d.replace and d.replace.group then c.last_group = d.replace.group end -- lot AMELIORATION-CONTINUE : finir le bloc entamé
        if d.replace and d.replace.group and c.engage then
          c.engage.paid = c.engage.paid or {}
          c.engage.paid[d.replace.to] = tick -- le rang a progressé : plus en famine
          Am.engage_update(c.engage, tick, { paid = d.replace.group }) -- le compte sans progrès repart
        end
        c.current, c.goal, c.scan_n = nil, nil, 0 -- décision suivante dès la prochaine pensée
      else
        c.refused = (c.refused or 0) + 1
        c.refused_until = c.refused_until or {}
        -- Lot AGES : un refus « cc-families » nomme les familles à monter (c.eblock) : le centre est revu à la minute, pas à 5 min.
        c.refused_until[d.key] = tick + ((tostring(why):sub(1, 11) == "cc-families") and Capital.RECHECK_TICKS or Capital.REFUSE_TICKS)
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

---------------------------------------------------------------------------------------------------
-- Lot BOX-UPGRADE (DC 9/11) : la primitive de remplacement sur place, ouverte au rétrofit glissant des boxes
-- (script/team/box_upgrade_rt.lua) : UNE seule façon de remplacer une entité dans le mod.
---------------------------------------------------------------------------------------------------
--- Remplace l'entité `e` par le prototype `to` (replace_one : paiement au stock libre, ancien objet rendu au stock, propriété et
--- entrée du plan suivies, F39 : contenu et recette gardés). Rend la nouvelle entité, ou nil et le motif.
function Capital.replace_entity(f, e, to) return replace_one(f, state_of(f), e, to) end
--- L'objet `item` est-il fabricable par la force (une recette activée le produit) ?
function Capital.unlocked(f, item) return unlocked(f, item) end
-- Liaison tardive (F24 : aucun require pendant un événement ; capital -> automatisation -> build -> hygiene -> boxes_rt ->
-- box_upgrade_rt ferait une boucle de require) : le moteur du rétrofit reçoit la primitive et le stock ici, au chargement.
require("script.team.box_upgrade_rt").bind(Capital, Stock)

return Capital
