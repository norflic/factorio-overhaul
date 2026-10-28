--[[
  ADOPTION des machines posées à la main par le joueur (lot ADOPTE ; règles pures : shared/team/adopte.lua).

  « Si moi je pose un four, il faut que le four soit visible par mes PNJ » (DC, 27/10). Une machine de fabrication que le
  joueur (ou ses robots) POSE est inscrite au registre de son équipe (f.smelters pour un four à combustion) : les tournées de
  fonte la chargent, la vident et la ravitaillent en combustible, le cerveau la compte (view.smelters), la fonte décidée en
  tient compte. Seulement si elle est ISOLÉE (ni bras, ni tapis, ni foreuse alentour), dans le rayon de service du coffre,
  hors des tuiles du plan directeur et hors des avant-postes. Une machine adoptée qui reçoit ensuite un bras, un tapis ou
  une foreuse est RENDUE au joueur. Jamais de démolition ni de déplacement d'un bâtiment du joueur : l'adoption ne fait
  qu'inscrire l'entité dans une liste ; un bâtiment ramassé ou détruit sort seul de la liste (Outposts.smelters).

  Événements : on_built_entity et on_robot_built_entity (le joueur et ses robots ; pas script_raised_built, qui est celui des
  PNJ). Migration : on_configuration_changed et remote fo-adopte.migrate (machines déjà posées dans le rayon, par numéro
  d'unité). Réglage de carte fo-war-adopte (vrai par défaut) : l'éteindre rend les machines adoptées au joueur à la
  migration suivante et stoppe toute nouvelle adoption.
  État : f.adopt = { units = { [numéro d'unité] = true }, refused = { [numéro] = motif }, n = adoptées au total, logs = n }.
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local A = require("shared.team.adopte")
local Outposts = require("script.faction.outposts")

local Adopte = {}

Adopte.SETTING = "fo-war-adopte"
Adopte.MAX_LOGS = 40 -- lignes [FO-ADOPTE] au plus par équipe

local BLOCKER = {}
for _, ty in ipairs(R.ADOPT_BLOCKERS) do BLOCKER[ty] = true end
local ADOPT_TYPES = {}
for ty in pairs(R.ADOPT) do ADOPT_TYPES[#ADOPT_TYPES + 1] = ty end
table.sort(ADOPT_TYPES)

function Adopte.on()
  local s = settings.global[Adopte.SETTING]
  return not (s ~= nil and s.value == false)
end

local function team() return Storage.ns("pteam").team end

-- Liste d'équipe d'un registre (créée au besoin) ; nil si elle n'existe pas encore (les labos vivent dans l'état du cerveau).
local function list_of(f, registry)
  if registry == "labs" then
    local st = f.team and f.team.ia3
    if not st then return nil end
    st.labs = st.labs or {}
    return st.labs
  end
  f[registry] = f[registry] or {}
  return f[registry]
end

local function kind_ok(ent)
  for _, k in ipairs(T.annex.kinds) do
    if k.item == ent.name then return true end
  end
  return false
end

local function state(f)
  local st = f.adopt
  if not st then
    st = { units = {}, refused = {}, n = 0, logs = 0 }
    f.adopt = st
  end
  return st
end

local function say(f, st, text)
  if st.logs >= Adopte.MAX_LOGS then return end
  st.logs = st.logs + 1
  log(string.format("[FO-ADOPTE] player : %s a %.1f min", text, (game.tick - (f.started or 0)) / 3600))
end

-- Réceptacles des avant-postes (jamais adoptés : l'avant-poste les sert déjà).
local function outpost_sinks(f)
  local set = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do
    for _, s in ipairs(f.outposts[oid].sinks or {}) do
      if s.valid and s.unit_number then set[s.unit_number] = true end
    end
  end
  return set
end

local function half_size(ent)
  local p = ent.prototype
  return (p.tile_width or 2) / 2, (p.tile_height or 2) / 2
end

local function linked(ent)
  local hw, hh = half_size(ent)
  return ent.surface.count_entities_filtered({ area = A.search_box(ent.position, hw, hh), type = R.ADOPT_BLOCKERS, limit = 1 }) > 0
end

local function listed(f, registry, ent)
  for _, e in ipairs(list_of(f, registry) or {}) do
    if e == ent then return true end
  end
  return false
end

--- Étudie une machine posée ; l'adopte si la règle le veut. Rend vrai si adoptée. `sinks` : réceptacles d'avant-poste
--- (calculés une fois par la migration).
function Adopte.consider(f, ent, sinks)
  if not (f and f.hq and f.hq.valid and ent and ent.valid and ent.unit_number and ent.force.name == f.force) then return false end
  local reg = R.ADOPT[ent.type]
  if not reg or R.ENTITY_ROLE[ent.type] ~= reg.role then return false end
  if reg.kinds and not kind_ok(ent) then return false end
  local list = list_of(f, reg.registry)
  if not list then return false end -- registre pas encore créé (laboratoires avant le cerveau) : la migration reprendra
  local st = state(f)
  local u = ent.unit_number
  local dx, dy = ent.position.x - f.hq_pos.x, ent.position.y - f.hq_pos.y
  local ok, why = A.decide({
    on = Adopte.on(), registry = reg.registry, burner_needed = reg.burner, burner = ent.burner ~= nil,
    already = st.units[u] or listed(f, reg.registry, ent), dist2 = dx * dx + dy * dy, radius = reg.radius,
    reserved = (Outposts.reserved and Outposts.reserved(f, ent.name, ent.position, ent.direction)) or (sinks or outpost_sinks(f))[u] or false,
    linked = function() return linked(ent) end, -- lu en dernier : un appel de recherche
  })
  if not ok then
    if why == "ligne" or why == "loin" or why == "plan" then st.refused[u] = why end
    return false
  end
  table.insert(list, ent)
  st.units[u] = true
  st.refused[u] = nil
  st.n = st.n + 1
  f.stats = f.stats or {}
  f.stats.adopted = (f.stats.adopted or 0) + 1
  say(f, st, string.format("%s adopte en (%.1f, %.1f), a %.0f tuiles du coffre (registre %s)", ent.name, ent.position.x, ent.position.y,
    math.sqrt(dx * dx + dy * dy), reg.registry))
  return true
end

--- Rend au joueur une machine adoptée (hors de la liste ; l'entité n'est pas touchée).
local function release(f, registry, ent, why)
  local st = state(f)
  local list = list_of(f, registry) or {}
  for i = #list, 1, -1 do
    if list[i] == ent then table.remove(list, i) end
  end
  if ent.valid then
    st.units[ent.unit_number] = nil
    st.refused[ent.unit_number] = why
    st.released = (st.released or 0) + 1
    say(f, st, string.format("%s rendu au joueur en (%.1f, %.1f) (%s)", ent.name, ent.position.x, ent.position.y, why))
  end
end

--- Un bras, un tapis ou une foreuse vient d'être posé : les machines adoptées qu'il touche sont rendues au joueur.
local function on_neighbor(f, ent)
  local st = f.adopt
  if not (st and st.n > 0 and BLOCKER[ent.type]) then return end
  local p = ent.position
  for _, ty in ipairs(ADOPT_TYPES) do
    local registry = R.ADOPT[ty].registry
    local give = {}
    for _, m in ipairs(list_of(f, registry) or {}) do
      if m.valid and st.units[m.unit_number] and m.surface == ent.surface then
        local hw, hh = half_size(m)
        if math.abs(p.x - m.position.x) <= hw + A.CLEAR and math.abs(p.y - m.position.y) <= hh + A.CLEAR then give[#give + 1] = m end
      end
    end
    table.sort(give, function(a, b) return a.unit_number < b.unit_number end)
    for _, m in ipairs(give) do release(f, registry, m, "ligne") end
  end
end

--- Machine POSÉE À LA MAIN que personne ne sert : d'un type adoptable, hors du registre de l'équipe et isolée (aucun bras, tapis
--- ni foreuse alentour : sinon c'est une ligne du joueur, qu'il alimente lui-même). Le relevé de la capitalisation ne la compte
--- pas (une capacité que personne ne fait tourner n'est pas une capacité). Faux pour une équipe sans état d'adoption.
function Adopte.unserved(f, ent)
  if not (f and f.is_player and ent and ent.valid and ent.unit_number and R.ADOPT[ent.type]) then return false end
  local st = f.adopt
  if st and st.units[ent.unit_number] then return false end
  return not linked(ent)
end

local function on_built(e)
  local ent = e.created_entity or e.entity
  if not (ent and ent.valid) then return end
  local f = team()
  if not (f and f.hq and f.hq.valid) then return end
  if BLOCKER[ent.type] then
    on_neighbor(f, ent)
  elseif R.ADOPT[ent.type] then
    Adopte.consider(f, ent)
  end
end

--- Migration : les machines déjà posées dans le rayon de service (sauvegarde d'avant le lot, réglage rallumé) sont étudiées
--- par numéro d'unité ; si le réglage est éteint, les machines adoptées sont rendues. Rend adoptées, rendues.
function Adopte.migrate(f)
  f = f or team()
  if not (f and f.hq and f.hq.valid) then return 0, 0 end
  local st = state(f)
  local given, taken = 0, 0
  if not Adopte.on() then
    for _, ty in ipairs(ADOPT_TYPES) do
      local registry = R.ADOPT[ty].registry
      local mine = {}
      for _, m in ipairs(list_of(f, registry) or {}) do
        if m.valid and st.units[m.unit_number] then mine[#mine + 1] = m end
      end
      table.sort(mine, function(a, b) return a.unit_number < b.unit_number end)
      for _, m in ipairs(mine) do
        release(f, registry, m, "coupe")
        given = given + 1
      end
    end
    return 0, given
  end
  local surface = f.hq.surface
  local found = surface.find_entities_filtered({ position = f.hq_pos, radius = A.RADIUS, force = f.force, type = ADOPT_TYPES })
  table.sort(found, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  local sinks = outpost_sinks(f)
  for _, ent in ipairs(found) do
    if Adopte.consider(f, ent, sinks) then taken = taken + 1 end
  end
  return taken, given
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on_configuration_changed(function() Adopte.migrate() end)

remote.add_interface("fo-adopte", {
  -- Pose simulée par un banc : le moteur interdit à un script de lever on_built_entity (doc de LuaBootstrap.raise_event) ; cette
  -- fonction appelle le même gestionnaire que l'événement.
  built = function(ent) on_built({ created_entity = ent }) end,
  migrate = function() return Adopte.migrate() end,
  status = function()
    local f = team()
    local st = f and f.adopt
    if not st then return { n = 0, listed = 0, released = 0 } end
    local n = 0
    for _ in pairs(st.units) do n = n + 1 end
    return { n = st.n, listed = n, released = st.released or 0 }
  end,
})

return Adopte
