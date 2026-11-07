--[[
  Lot X10-S4 (7/11, accordé par le lead ; critères : fo-logs\2026-11-07_X10\S4_CRITERES.md) : REGISTRE DES GÉNÉRATRICES par
  surface et par force, à la place de six recherches sur TOUTE la surface dans cinq fichiers (relevé du 7/11, SCRIPT.md §4.5) :
    script/team/raccord.lua (live_networks), script/team/reseau_vivant.lua (net_read d'un bloc), script/team/champ.lua (powered_pole et
    raccord_tous), script/team/migration_champ.lua (fuel_burn), script/ai3/petrole.lua (nearest_network).
  (build.lua, « limit = 1 », n'est pas touché : il s'arrête à la première génératrice trouvée, et laquelle dépend de l'ordre du moteur.)

  CONTRAT : Gens.list(surface, force, types) rend les MÊMES entités que surface.find_entities_filtered{force, type = types}, triées par
  unit_number ; Gens.networks rend le même ENSEMBLE de numéros de réseau électrique que la boucle de l'ancien code. `force` est un NOM
  de force (les équipes le gardent ainsi : f.force).

  ENTRÉES : toute pose d'une entité des types tenus (Gens.TYPES) : on_built_entity, on_robot_built_entity, script_raised_built,
  script_raised_revive. Le mod pose ses génératrices avec raise_built ou raise_revive (relevé du 7/11 : tous les `revive` lèvent
  l'événement ; les `create_entity` sans raise_built posent des foreuses, coffres, fours, tourelles, unités, tapis, labos, jamais une
  génératrice). RELEVÉ COMPLET (l'ancienne recherche, SANS filtre de force : une seule recherche par surface, toutes forces rangées
  d'un coup ; relecture revue-0659, réserve 1) : dans on_configuration_changed, pour toutes les surfaces (données ou mod changés ;
  une partie d'avant ce lot passe toujours par là), et à la première lecture d'une surface sans registre (partie neuve). Une force
  apparue après le relevé de sa surface reçoit un seau vide : toutes ses poses sont postérieures, donc viennent par événement.
  Un type demandé que Gens.TYPES ne tient pas : l'ancienne recherche, et une ligne [FO-GENS] (réserve 2), jamais une liste fausse.
  SORTIES : à la lecture, une entité invalide (détruite, minée, morte) est retirée.

  LIMITES, dites telles quelles (comme script/team/abimes.lua) : une génératrice posée SANS événement par un autre mod, une génératrice
  CLONÉE (on_entity_cloned : éditeur, autre mod), une force changée par script ou par fusion, une entité téléportée d'une surface à
  l'autre. Le mod ne fait rien de cela (relevé du 7/11 : aucune écriture de LuaEntity.force, aucun merge_forces, aucun clone, aucun
  teleport entre surfaces). Elles ne seraient vues qu'au prochain relevé complet (prochain on_configuration_changed).

  BANCS HORS JEU à moteur partiel (relevé du 7/11 : reseau_vivant_test, raccord_script_test, migration_champ_test, pouls_test) : le
  registre ne sert qu'ARMÉ, c'est-à-dire après on_init, on_load ou on_configuration_changed (en jeu, l'un des trois vient toujours avant
  tout événement, sur chaque pair) ; une entité tenue SANS unit_number (fausses entités de ces bancs ; jamais en jeu : toute génératrice
  a un propriétaire, donc un numéro) rend son seau illisible : l'ancienne recherche. Un événement sans numéro dans `defines` n'est pas
  abonné. Ces trois chemins sont morts en jeu ; ils gardent les bancs d'avant ce lot sur l'ancienne recherche.

  État : Storage « gens » = { by = { [surface.index] = { [nom de force] = { list = { LuaEntity }, type = { type }, unit = { unit_number },
  seen = { [unit_number] = true } } } }, nounit = { [surface.index] = true } }, listes parallèles triées par unit_number (aucune entité
  lue pour garder l'ordre : une entité invalide ne se lit plus).
  Coût d'une lecture : O(génératrices de la force) au lieu d'un parcours de toute la surface. Gens.ENABLED = false : l'ancienne recherche
  (témoin des bancs).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")

local Gens = {}

Gens.ENABLED = true
local armed = false -- copie LOCALE (jamais dans global) : vraie après on_init, on_load ou on_configuration_changed
Gens.TYPES = { "burner-generator", "generator", "solar-panel" } -- union des types lus par les cinq fichiers, triée
local TRACKED = {}
for _, t in ipairs(Gens.TYPES) do TRACKED[t] = true end

Storage.declare("gens", function() return { by = {} } end)

local function root()
  if not armed then return nil end
  local S = Storage.ns("gens")
  if not S then return nil end
  S.by = S.by or {}
  S.nounit = S.nounit or {}
  return S
end

--- Ajoute une entité valide à son rang (ordre des unit_number : une pose arrive presque toujours en dernier, les numéros ne font que
--- croître).
local function add(b, e, etype)
  local u = e.unit_number
  if not u then
    b.nounit = true
    return
  end
  if b.seen[u] then return end
  b.seen[u] = true
  local list, tl, ul = b.list, b.type, b.unit
  local i = #ul
  while i > 0 and ul[i] > u do
    list[i + 1], tl[i + 1], ul[i + 1] = list[i], tl[i], ul[i]
    i = i - 1
  end
  list[i + 1], tl[i + 1], ul[i + 1] = e, etype, u
end

-- Compteur des relevés complets (bancs hors jeu) : table du MODULE, jamais dans global, jamais lue par une décision.
Gens.stats = { scans = 0 }

local function new_bucket() return { list = {}, type = {}, unit = {}, seen = {} } end

--- Relevé complet d'une surface, TOUTES FORCES d'un coup (relecture revue-0659, réserve 1 : une seule recherche sur toute la surface,
--- jamais une par force au même tick) : l'ancienne recherche sans filtre de force, triée par unit_number, rangée par force. Chaque
--- force du jeu (noms triés) reçoit son seau, vide s'il le faut, pour qu'aucune ne relance de relevé à sa première lecture.
local function scan_all(S, surface)
  Gens.stats.scans = Gens.stats.scans + 1
  local bs = {}
  local names = {}
  for name in pairs(game.forces or {}) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do bs[name] = new_bucket() end
  local rows = {}
  local nounit = false
  for _, e in ipairs(surface.find_entities_filtered({ type = Gens.TYPES })) do
    if e.valid then
      if e.unit_number then
        rows[#rows + 1] = { u = e.unit_number, e = e, t = e.type, f = e.force.name }
      else
        nounit = true -- (bancs à moteur partiel seulement : la force d'une fausse entité ne se lit pas)
      end
    end
  end
  table.sort(rows, function(a, b) return a.u < b.u end)
  for _, r in ipairs(rows) do
    bs[r.f] = bs[r.f] or new_bucket()
    add(bs[r.f], r.e, r.t)
  end
  S.by[surface.index] = bs
  S.nounit[surface.index] = nounit or nil
  return bs
end

--- Données changées (types de prototypes, autre mod) : registre refait EN ENTIER ici, une recherche par surface (toutes forces), dans
--- on_configuration_changed, hors du temps d'un tick de jeu (relecture revue-0659, réserve 1).
local function rescan_all(S)
  S.by, S.nounit = {}, {}
  if not (game and game.surfaces) then return end -- (bancs à moteur partiel)
  local idx, seen = {}, {}
  for _, sf in pairs(game.surfaces) do
    if not seen[sf.index] then
      seen[sf.index] = true
      idx[#idx + 1] = sf.index
    end
  end
  table.sort(idx)
  for _, i in ipairs(idx) do scan_all(S, game.surfaces[i]) end
end

-- Micro-banc en moteur réel (x10-s4-ombre, fo-logs/2026-11-07_X10/S4_CRITERES.md §3 quater) : OMBRE, allumée par l'interface distante
-- « fo-x10-gens » (bancs seulement). Chaque lecture refait alors l'ancienne recherche au même instant, compare, écrit une ligne
-- [FO-GENS-OMBRE] et compte. Copies LOCALES (jamais dans global), jamais lues par une décision.
local shadow = false
local OMB = { sh = nil } -- compteurs de l'ombre : un CHAMP, jamais un local du module réaffecté (fait F403, tests/upvalue_gc_test.lua)
local site = "?"
local depth = 0

--- Pose d'une entité : notée si son type est tenu et que sa surface a été relevée (sinon le relevé complet la verra). Une force apparue
--- après le relevé de la surface reçoit son seau ici : toutes ses poses sont postérieures au relevé, donc viennent par événement.
--- `kind` : nom de l'événement.
function Gens.built(e, kind)
  local ent = e.created_entity or e.entity
  if not (ent and ent.valid) then return end
  local etype = ent.type
  if not TRACKED[etype] then return end
  if shadow and kind then OMB.sh.poses[kind] = (OMB.sh.poses[kind] or 0) + 1 end
  local S = root()
  if not S then return end
  local bs = S.by[ent.surface.index]
  if not bs then return end
  local fname = ent.force.name
  local b = bs[fname]
  if not b then
    b = new_bucket()
    bs[fname] = b
  end
  add(b, ent, etype)
end

local ev = (defines and defines.events) or {}
for _, k in ipairs({ "on_built_entity", "on_robot_built_entity", "script_raised_built", "script_raised_revive" }) do
  if ev[k] then Events.on(ev[k], function(e) Gens.built(e, k) end) end
end

--- Types demandés, ou nil si l'un d'eux n'est pas tenu par le registre (relecture revue-0659, réserve 2 : l'ancienne recherche, jamais
--- une liste fausse).
local untracked_said = {}
local function type_set(types)
  local list = type(types) == "string" and { types } or types
  local w = {}
  for _, t in ipairs(list) do
    if not TRACKED[t] then
      if not untracked_said[t] then
        untracked_said[t] = true
        log("[FO-GENS] type « " .. tostring(t) .. " » non tenu par le registre (Gens.TYPES) : ancienne recherche sur toute la surface")
      end
      return nil
    end
    w[t] = true
  end
  return w
end

local function list_impl(surface, force, types)
  if not Gens.ENABLED then return surface.find_entities_filtered({ force = force, type = types }) end
  local S = root()
  if not S then return surface.find_entities_filtered({ force = force, type = types }) end
  local fname = type(force) == "string" and force or force.name -- clé du registre : toujours le nom
  local want = type_set(types)
  if not want then return surface.find_entities_filtered({ force = force, type = types }) end
  local bs = S.by[surface.index] or scan_all(S, surface)
  if S.nounit[surface.index] then return surface.find_entities_filtered({ force = force, type = types }) end
  local b = bs[fname]
  if not b then -- force apparue après le relevé de la surface, sans génératrice posée depuis (voir Gens.built)
    b = new_bucket()
    bs[fname] = b
  end
  if b.nounit then return surface.find_entities_filtered({ force = force, type = types }) end
  local list, tl, ul, seen, out = b.list, b.type, b.unit, b.seen, {}
  local n, j = #list, 0
  for i = 1, n do
    local e = list[i]
    if e.valid then
      j = j + 1
      list[j], tl[j], ul[j] = e, tl[i], ul[i]
      if want[tl[j]] then out[#out + 1] = e end
    else
      seen[ul[i]] = nil -- un unit_number n'est jamais réutilisé
    end
  end
  for k = n, j + 1, -1 do list[k], tl[k], ul[k] = nil, nil, nil end
  return out
end

--- Ombre : l'ancienne recherche, triée par unit_number, comparée à ce que rend le registre (`got`, et `live` pour les réseaux).
local function shadow_check(surface, force, types, got, live)
  local want = {}
  for _, e in ipairs(surface.find_entities_filtered({ force = force, type = types })) do
    if e.valid and e.unit_number then want[#want + 1] = e end
  end
  table.sort(want, function(a, b) return a.unit_number < b.unit_number end)
  local function units(l)
    local t = {}
    for i, e in ipairs(l) do t[i] = tostring(e.valid and e.unit_number or "X") end
    return table.concat(t, ",")
  end
  local function nets(set)
    local t = {}
    for id in pairs(set) do t[#t + 1] = id end
    table.sort(t)
    return table.concat(t, ",")
  end
  local a, b = units(got), units(want)
  local same = a == b
  local txt = ""
  if live then
    local wl = {}
    for _, g in ipairs(want) do
      local id = g.electric_network_id
      if id then wl[id] = true end
    end
    local la, lb = nets(live), nets(wl)
    same = same and la == lb
    txt = " ; reseaux registre {" .. la .. "} recherche {" .. lb .. "}"
  end
  OMB.sh.lectures = OMB.sh.lectures + 1
  OMB.sh.sites[site] = (OMB.sh.sites[site] or 0) + 1
  if not same then OMB.sh.ecarts = OMB.sh.ecarts + 1 end
  log("[FO-GENS-OMBRE] tick " .. tostring(game.tick) .. " site " .. site .. " force " .. tostring(force) .. " : registre [" .. a
    .. "] recherche [" .. b .. "]" .. txt .. (same and " : EGAL" or " : ECART") .. (Gens.ready() and "" or " (repli)"))
end

--- Génératrices VALIDES de `force` (nom) sur `surface`, des types `types` (chaîne ou liste), triées par unit_number. Retire au passage
--- les entités invalides du registre.
function Gens.list(surface, force, types)
  local out = list_impl(surface, force, types)
  if shadow and depth == 0 then shadow_check(surface, force, types, out, nil) end
  return out
end

--- Vrai quand le registre sert : armé, allumé, espace « gens » créé (en jeu, toujours après on_init ou on_load). Faux : Gens.list fait
--- l'ancienne recherche sur toute la surface, et raccord.lua garde son relevé par bandes (lot LOURD).
function Gens.ready()
  return Gens.ENABLED and root() ~= nil
end

--- Ensemble des numéros de réseau électrique des génératrices de `force` sur `surface` (types `types`) : { [id] = true }, nombre.
function Gens.networks(surface, force, types)
  local live, n = {}, 0
  depth = depth + 1
  local list = Gens.list(surface, force, types)
  depth = depth - 1
  for _, g in ipairs(list) do
    local id = g.electric_network_id
    if id and not live[id] then
      live[id] = true
      n = n + 1
    end
  end
  if shadow and depth == 0 then shadow_check(surface, force, types, list, live) end
  return live, n
end

-- Interface du micro-banc (bancs seulement) : ombre(vrai|faux) ; appels(force, x, y, poteau) passe par les six sites d'appel avec le
-- vrai moteur (modules lus dans package.loaded : aucun require pendant un événement) ; bilan(force) rend les compteurs et le registre.
local function appels(force, x, y, pole)
  local s = game.surfaces[1]
  local f = { force = force, key = "x10" }
  local b = { order = {}, projects = {} }
  local L = package.loaded
  local Ra, Rv, Ch = L["script.team.raccord"], L["script.team.reseau_vivant"], L["script.team.champ"]
  local Mg, Pe = L["script.team.migration_champ"], L["script.ai3.petrole"]
  local calls = {
    { "raccord:live_networks", function() return Ra.generateurs.bloc(f, s) end },
    { "reseau_vivant:net_read", function() return Rv.net_read(f, s, b) end },
    { "champ:powered_pole", function() return Ch.powered_pole(f, s, x, y, 64) end },
    { "champ:raccord_tous", function() -- loin de tout poteau : la lecture du registre faite, sortie « aucun réseau alimenté »
      return Ch._raccord_tous(f, s, { spec = { pole = { wire = 9 } }, names = { pole = pole } }, { { name = pole, x = x + 2000, y = y } }, x + 2000, y)
    end },
    { "migration_champ:fuel_burn", function() return Mg._fuel_burn(f, s) end },
    { "petrole:nearest_network", function() return Pe._nearest_network(f, s, x, y, b) end },
  }
  for _, c in ipairs(calls) do
    site = c[1]
    local ok, err = pcall(c[2])
    if not ok then
      OMB.sh.erreurs = OMB.sh.erreurs + 1
      log("[FO-GENS-OMBRE] tick " .. tostring(game.tick) .. " site " .. site .. " : ERREUR " .. tostring(err))
    end
  end
  site = "?"
end

if remote and remote.add_interface then
  remote.add_interface("fo-x10-gens", {
    ombre = function(on)
      shadow = on and true or false
      if shadow then OMB.sh = { lectures = 0, ecarts = 0, erreurs = 0, sites = {}, poses = {} } end
    end,
    appels = function(force, x, y, pole) if shadow then appels(force, x, y, pole) end end,
    bilan = function(force)
      local reg = {}
      if OMB.sh then
        site = "bilan"
        for _, e in ipairs(Gens.list(game.surfaces[1], force, Gens.TYPES)) do reg[#reg + 1] = e.unit_number end
        site = "?"
      end
      return { ombre = shadow, pret = Gens.ready(), lectures = OMB.sh and OMB.sh.lectures or 0, ecarts = OMB.sh and OMB.sh.ecarts or 0,
        erreurs = OMB.sh and OMB.sh.erreurs or 0, sites = OMB.sh and OMB.sh.sites or {}, poses = OMB.sh and OMB.sh.poses or {}, registre = reg }
    end,
  })
end

local function arm() armed = true end
if Events.on_init then Events.on_init(arm) end
if Events.on_load then Events.on_load(arm) end
-- Données changées (types de prototypes, autre mod) : tout est relevé à nouveau, ici (rescan_all).
Events.on_configuration_changed(function()
  armed = true
  local S = root()
  if S then rescan_all(S) end
end)

return Gens
