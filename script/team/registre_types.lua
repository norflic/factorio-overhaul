--[[
  Lot UPS (13/11, sprint de 7 h) : REGISTRE DES MACHINES par surface, par force et par TYPE, à la place des recherches sur TOUTE la
  surface faites à chaque pensée d'équipe. Mesuré sur partie-reelle-120 (graine 123456789, 60 à 120 min, cinq équipes) : chaque
  recherche « force + type » sans zone parcourt tous les chunks de la carte, quel que soit le nombre de résultats ; les sites ci-dessous
  en font environ 600 par tranche de 10 min, et ce sont elles les ticks de script au-dessus de 16,7 ms.

  Sites servis (mêmes entités, mêmes décisions) :
    script/team/electrique.lua       live_drills (foreuses électriques qui tournent, toutes les 600 ticks) et Elec.count (une par minute) ;
    script/team/plafond_charbon.lua  Cap.read (chaudières, fours, foreuses : toutes les 600 ticks) ;
    script/team/front.lua            refresh_cover (laboratoires, toutes les 1 800 ticks) ;
    script/ai3/anti_dispersion.lua   measure (assembleurs, une fois par minute) ;
    script/team/gisement.lua         Gis.prune (foreuses, une ronde toutes les 4 min).

  CONTRAT : Rt.list(surface, force, types) rend les MÊMES entités que surface.find_entities_filtered{force, type = types}. L'ORDRE est
  celui du registre (type par type dans l'ordre demandé, puis unit_number croissant), pas celui du moteur : les six sites ne lisent que
  des comptes, des ensembles ou une liste qu'ils trient eux-mêmes ; Cap.read additionne des puissances (somme de nombres : égale à
  l'ancienne tant que les termes s'additionnent sans arrondi, ce qui est le cas des puissances entières des prototypes).
  `force` est un NOM de force (les équipes le gardent ainsi : f.force).

  ENTRÉES : toute pose d'une entité d'un type tenu (Rt.TYPES) :
    1. événements on_built_entity, on_robot_built_entity, script_raised_built, script_raised_revive, on_entity_cloned,
       on_trigger_created_entity ;
    2. Rt.note(entité) aux poses SANS événement du mod (create_entity sans raise_built ; relevé du 13/11 sur tout script/ : onze
       sites, tests/registre_types_test.lua garde la liste égale) ;
    3. RELEVÉ COMPLET d'une surface, toutes forces d'un coup, à sa première lecture (partie neuve, partie d'avant ce lot) et dans
       on_configuration_changed (données ou mod changés).
  SORTIES : à la lecture, une entité invalide (détruite, minée, morte, remplacée) est retirée.

  LIMITES, dites telles quelles (les mêmes que script/team/generateurs.lua) : une machine posée SANS événement par un autre mod, une
  force changée par script ou par fusion, une entité téléportée d'une surface à l'autre : vues au prochain relevé complet
  (on_configuration_changed). Le mod ne fait rien de cela.

  BANCS HORS JEU à moteur partiel : le registre ne sert qu'ARMÉ (après on_init, on_load ou on_configuration_changed) ; une entité tenue
  sans unit_number rend son seau illisible : l'ancienne recherche. Rt.ENABLED = false : l'ancienne recherche partout (témoin).

  OMBRE (bancs seulement, interface distante « fo-ups-registre ») : chaque lecture refait l'ancienne recherche au même instant et
  compare les ensembles de unit_number ; un écart écrit une ligne [FO-REGISTRE-OMBRE] ; le bilan compte lectures et écarts.

  État : Storage « regtypes » = { by = { [surface.index] = { [nom de force] = { [type] = { list = { LuaEntity }, unit = { unit_number },
  seen = { [unit_number] = true } } } } }, nounit = { [surface.index] = true } }. Coût d'une lecture : O(machines de la force du type).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")

local Rt = {}

Rt.ENABLED = true
Rt.TYPES = { "assembling-machine", "boiler", "furnace", "lab", "mining-drill" } -- union des types lus par les sites servis, triée
local TRACKED = {}
for _, t in ipairs(Rt.TYPES) do TRACKED[t] = true end
local NAMED_TYPE = {} -- [nom de prototype] = type (Rt.named) : copie LOCALE, jamais dans global, jamais lue par une décision autrement que comme le prototype
local armed = false -- copie LOCALE (jamais dans global) : vraie après on_init, on_load ou on_configuration_changed

Storage.declare("regtypes", function() return { by = {} } end)

-- Compteurs (table du MODULE, jamais dans global, jamais lus par une décision) : relevés complets, et l'ombre des bancs.
Rt.stats = { scans = 0 }
local OMB = { on = false, lectures = 0, ecarts = 0, replis = 0, sites = {} }

local function root()
  if not armed then return nil end
  local S = Storage.ns("regtypes")
  if not S then return nil end
  S.by = S.by or {}
  S.nounit = S.nounit or {}
  return S
end

local function new_bucket() return { list = {}, unit = {}, seen = {} } end

--- Seau du type `etype` de la force `fname` dans les seaux `bs` d'une surface (créé au besoin).
local function bucket(bs, fname, etype)
  local bf = bs[fname]
  if not bf then
    bf = {}
    bs[fname] = bf
  end
  local b = bf[etype]
  if not b then
    b = new_bucket()
    bf[etype] = b
  end
  return b
end

--- Ajoute une entité valide à son rang (unit_number croissant : une pose arrive presque toujours en dernier).
local function add(b, e)
  local u = e.unit_number
  if not u then
    b.nounit = true
    return
  end
  if b.seen[u] then return end
  b.seen[u] = true
  local list, ul = b.list, b.unit
  local i = #ul
  while i > 0 and ul[i] > u do
    list[i + 1], ul[i + 1] = list[i], ul[i]
    i = i - 1
  end
  list[i + 1], ul[i + 1] = e, u
end

--- Relevé complet d'une surface, TOUTES FORCES d'un coup (une seule recherche), rangé par force et par type, trié par unit_number.
local function scan_all(S, surface)
  Rt.stats.scans = Rt.stats.scans + 1
  local bs = {}
  local rows = {}
  local nounit = false
  for _, e in ipairs(surface.find_entities_filtered({ type = Rt.TYPES })) do
    if e.valid then
      if e.unit_number then
        rows[#rows + 1] = { u = e.unit_number, e = e, t = e.type, f = e.force.name }
      else
        nounit = true -- (bancs à moteur partiel seulement)
      end
    end
  end
  table.sort(rows, function(a, b) return a.u < b.u end)
  for _, r in ipairs(rows) do add(bucket(bs, r.f, r.t), r.e) end
  S.by[surface.index] = bs
  S.nounit[surface.index] = nounit or nil
  return bs
end

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

--- Pose d'une entité (événement ou appel direct du mod après un create_entity sans événement) : notée si son type est tenu et que sa
--- surface a déjà été relevée (sinon le relevé complet de la première lecture la verra). nil ou invalide : rien.
function Rt.note(ent)
  if not (ent and ent.valid) then return end
  local etype = ent.type
  if not TRACKED[etype] then return end
  local S = root()
  if not S then return end
  local bs = S.by[ent.surface.index]
  if not bs then return end
  add(bucket(bs, ent.force.name, etype), ent)
end

local function built(e)
  Rt.note(e.created_entity or e.entity or e.destination)
end

local ev = (defines and defines.events) or {}
for _, k in ipairs({ "on_built_entity", "on_robot_built_entity", "script_raised_built", "script_raised_revive", "on_entity_cloned",
  "on_trigger_created_entity" }) do
  local id = rawget(ev, k) -- (rawget : le moteur simulé des tests refuse un nom d'événement qu'il ne connaît pas)
  if id then Events.on(id, built) end
end

local function old_search(surface, force, types)
  return surface.find_entities_filtered({ force = force, type = types })
end

--- Liste du registre, ou nil quand il ne peut pas servir (éteint, pas armé, type non tenu, seau illisible) : l'appelant fait alors
--- l'ancienne recherche.
local function from_registry(surface, force, types)
  if not Rt.ENABLED then return nil end
  local S = root()
  if not S then return nil end
  local list = type(types) == "string" and { types } or types
  for _, t in ipairs(list) do
    if not TRACKED[t] then return nil end
  end
  local fname = type(force) == "string" and force or force.name
  local idx = surface.index
  local bs = S.by[idx] or scan_all(S, surface)
  if S.nounit[idx] then return nil end
  local out = {}
  local done = {}
  for _, t in ipairs(list) do
    if not done[t] then -- (un type demandé deux fois n'est rendu qu'une fois, comme la recherche du moteur)
      done[t] = true
      local b = bucket(bs, fname, t)
      if b.nounit then return nil end
      local l, ul, seen = b.list, b.unit, b.seen
      local n, j = #l, 0
      for i = 1, n do
        local e = l[i]
        if e.valid then
          j = j + 1
          l[j], ul[j] = e, ul[i]
          out[#out + 1] = e
        else
          seen[ul[i]] = nil -- un unit_number n'est jamais réutilisé
        end
      end
      for k = n, j + 1, -1 do l[k], ul[k] = nil, nil end
    end
  end
  return out
end

local function units(l)
  local t = {}
  for _, e in ipairs(l) do
    if e.valid and e.unit_number then t[#t + 1] = e.unit_number end
  end
  table.sort(t)
  return t
end

--- Ombre : l'ancienne recherche comparée à ce que rend le registre (ensembles de unit_number).
local function shadow_check(surface, force, types, got, site)
  local a, b = units(got), units(old_search(surface, force, types))
  local same = #a == #b
  if same then
    for i = 1, #a do
      if a[i] ~= b[i] then
        same = false
        break
      end
    end
  end
  OMB.lectures = OMB.lectures + 1
  OMB.sites[site] = (OMB.sites[site] or 0) + 1
  if not same then
    OMB.ecarts = OMB.ecarts + 1
    if OMB.ecarts <= 40 then
      local ta = type(types) == "table" and table.concat(types, "+") or tostring(types)
      log("[FO-REGISTRE-OMBRE] tick " .. tostring(game.tick) .. " site " .. tostring(site) .. " force " .. tostring(force) .. " types " .. ta
        .. " : registre " .. #a .. " [" .. table.concat(a, ",", 1, math.min(#a, 30)) .. "] recherche " .. #b .. " ["
        .. table.concat(b, ",", 1, math.min(#b, 30)) .. "] : ECART")
    end
  end
end

--- Machines VALIDES de `force` (nom) sur `surface`, des types `types` (chaîne ou liste). `site` : nom du lecteur (ombre des bancs).
function Rt.list(surface, force, types, site)
  local out = from_registry(surface, force, types)
  if not out then
    if OMB.on then OMB.replis = OMB.replis + 1 end
    return old_search(surface, force, types)
  end
  if OMB.on then shadow_check(surface, force, types, out, site or "?") end
  return out
end

--- Machines de `force` qui portent le NOM `name` (même résultat que find_entities_filtered{name, force}) : le registre ne sert que si
--- le prototype de ce nom est d'un type tenu ; sinon (nom inconnu du jeu compris) l'ancienne recherche, telle quelle.
function Rt.named(surface, force, name, site)
  -- s40 ups-team p45 : type du prototype gardé (table du MODULE, jamais dans global ; un prototype ne change pas pendant une session,
  -- on_configuration_changed la vide) : plus d'accès au moteur à chaque lecture. Un nom inconnu n'est pas gardé (relu, comme avant).
  local etype = NAMED_TYPE[name]
  if etype == nil then
    local proto = game and game.entity_prototypes and game.entity_prototypes[name]
    etype = proto and proto.type
    if type(etype) == "string" then NAMED_TYPE[name] = etype end
  end
  if not (etype and TRACKED[etype]) then
    return surface.find_entities_filtered({ name = name, force = force })
  end
  local out = {}
  for _, e in ipairs(Rt.list(surface, force, etype, site)) do
    if e.name == name then out[#out + 1] = e end
  end
  return out
end

--- Vrai quand le registre sert (armé, allumé, espace créé).
function Rt.ready()
  return Rt.ENABLED and root() ~= nil
end

if remote and remote.add_interface then
  remote.add_interface("fo-ups-registre", {
    ombre = function(on)
      OMB.on = on and true or false
      OMB.lectures, OMB.ecarts, OMB.replis, OMB.sites = 0, 0, 0, {}
    end,
    bilan = function()
      local S = root()
      local n = 0
      if S then
        for _, bs in pairs(S.by) do -- (compte seul : l'ordre de parcours n'a aucun effet)
          for _, bf in pairs(bs) do
            for _, b in pairs(bf) do n = n + #b.list end
          end
        end
      end
      return { ombre = OMB.on, pret = Rt.ready(), lectures = OMB.lectures, ecarts = OMB.ecarts, replis = OMB.replis, sites = OMB.sites,
        tenues = n, releves = Rt.stats.scans }
    end,
  })
end

local function arm() armed = true end
if Events.on_init then Events.on_init(arm) end
if Events.on_load then Events.on_load(arm) end
-- Données changées (types de prototypes, autre mod) : tout est relevé à nouveau, ici, hors du temps d'un tick de jeu.
Events.on_configuration_changed(function()
  armed = true
  for k in pairs(NAMED_TYPE) do NAMED_TYPE[k] = nil end -- (données changées : types relus)
  local S = root()
  if S then rescan_all(S) end
end)

return Rt
