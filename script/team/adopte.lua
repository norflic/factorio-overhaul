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
  État : f.adopt = { units = { [numéro d'unité] = true }, refused = { [numéro] = motif }, n = adoptées au total, logs = n,
  drills = { [numéro de foreuse] = { oid, sink = numéro de la réception } } }.

  Lot PARITE (retour du DC du 2/11 : « elles ont même pas su s'adapter au bâtiment que j'ai posé ») : une FOREUSE à combustion posée
  à la main, avec sa réception (four ou coffre) au bout, isolée, dans le rayon de service, devient un AVANT-POSTE de l'équipe
  (o.adopted) : les tournées d'entretien la ravitaillent et vident sa réception, elle compte dans la capacité du minerai, sa perte
  est une perte d'avant-poste. Rendue au joueur quand une ligne la rejoint ou qu'il la ramasse (règle pure : A.decide_drill).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local State = require("script.faction.state")
local R = require("shared.ai3.reglages")
local T = require("shared.team.config")
local A = require("shared.team.adopte")
local Outposts = require("script.faction.outposts")
local PlacesQG = require("script.ai3.places_qg") -- lot TUILES-RESERVEES : crochet unique des tuiles réservées

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

--- Lot PARITE : type d'avant-poste de la ressource que mine la foreuse (nil : aucune ressource connue de l'équipe sous elle).
local function kind_under(drill)
  local target = drill.mining_target
  local name = target and target.valid and target.name
  if not name then
    -- Une foreuse tout juste posée n'a pas encore choisi sa cible : la ressource est lue dans sa zone de minage.
    local r = (drill.prototype and drill.prototype.mining_drill_radius) or 1
    local list = drill.surface.find_entities_filtered({ area = { { drill.position.x - r, drill.position.y - r }, { drill.position.x + r, drill.position.y + r } },
      type = { "resource" } })
    table.sort(list, function(a, b)
      if a.name ~= b.name then return a.name < b.name end
      if a.position.x ~= b.position.x then return a.position.x < b.position.x end
      return a.position.y < b.position.y
    end)
    for _, res in ipairs(list) do
      if res.valid then name = res.name break end
    end
  end
  if not name then return nil end
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    if T.outposts[kind].resource == name then return kind end
  end
  return nil
end

--- Lot PARITE : la réception (four ou coffre) au point de dépôt de la foreuse, ou nil.
local function sink_under(drill)
  if not drill.drop_position then return nil end
  -- par boîte (recouvrement de la boîte de collision), non par rayon : le rayon ne compte que le CENTRE de l'entité (moteur réel, parite-adopte :
  -- le four voisin de 2 x 2 n'était pas vu à 1,1 tuile de son centre)
  local d = drill.drop_position
  local list = drill.surface.find_entities_filtered({ area = { { d.x - 0.1, d.y - 0.1 }, { d.x + 0.1, d.y + 0.1 } }, type = { "furnace", "container" },
    force = drill.force.name })
  table.sort(list, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  for _, e in ipairs(list) do
    if e.valid and e.unit_number then return e end
  end
  return nil
end

--- Lot PARITE : un bras, un tapis ou une autre foreuse touche la paire (hors la foreuse elle-même) : c'est une ligne du joueur.
local function pair_linked(drill, sink)
  for _, e in ipairs({ drill, sink }) do
    local hw, hh = half_size(e)
    local near = e.surface.find_entities_filtered({ area = A.search_box(e.position, hw, hh), type = R.ADOPT_BLOCKERS })
    for _, n in ipairs(near) do
      if n.unit_number ~= drill.unit_number then return true end
    end
  end
  return false
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
    -- lot ÉTAGE 5 (revue B2, décision du lead) : la machine posée par le joueur est adoptée même sur un couloir d'accès
    reserved = PlacesQG.is_reserved(f, ent.name, ent.position, ent.direction, { couloir = false }) or (sinks or outpost_sinks(f))[u] or false,
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

--- Lot PARITE : adopte une foreuse à combustion posée à la main (avec sa réception) comme avant-poste de l'équipe. `sinks` : réceptacles
--- d'avant-poste déjà connus (migration). Rend vrai si adoptée.
function Adopte.consider_drill(f, ent, sinks)
  if not (f and f.hq and f.hq.valid and ent and ent.valid and ent.unit_number and ent.type == "mining-drill"
    and ent.force.name == f.force) then return false end
  local st = state(f)
  st.drills = st.drills or {}
  local u = ent.unit_number
  local sink = sink_under(ent)
  local kind = kind_under(ent)
  local dx, dy = ent.position.x - f.hq_pos.x, ent.position.y - f.hq_pos.y
  local ok, why = A.decide_drill({
    on = Adopte.on(), kind = kind, burner = ent.burner ~= nil, already = st.drills[u] ~= nil or State.owner(u) ~= nil,
    sink = sink ~= nil and State.owner(sink.unit_number) == nil,
    -- lot ÉTAGE 5 (revue B2, décision du lead) : la foreuse posée par le joueur est adoptée même sur un couloir d'accès
    reserved = PlacesQG.is_reserved(f, ent.name, ent.position, ent.direction, { couloir = false }) or (sinks or outpost_sinks(f))[u] or false,
    dist2 = dx * dx + dy * dy, radius = A.RADIUS,
    linked = function() return pair_linked(ent, sink) end, -- lu en dernier : deux recherches
  })
  if not ok then
    if why == "ligne" or why == "loin" or why == "plan" or why == "sans-reception" then st.refused[u] = why end
    if why ~= "deja" and why ~= "coupe" then
      say(f, st, string.format("foreuse %s en (%.1f, %.1f) non adoptee (%s)", ent.name, ent.position.x, ent.position.y, why))
    end
    return false
  end
  -- La réception de la paire n'est plus un four de la fonderie du QG (adopté seul avant que la foreuse soit posée) : elle sert la paire.
  if st.units[sink.unit_number] then
    local registry = sink.type == "furnace" and "smelters" or "annex"
    local list = list_of(f, registry) or {}
    for i = #list, 1, -1 do
      if list[i] == sink then table.remove(list, i) end
    end
    st.units[sink.unit_number] = nil
  end
  local pool = {}
  for _, oid in ipairs(State.sorted_keys(f.outposts)) do
    local o = f.outposts[oid]
    if o.adopted then pool[#pool + 1] = { oid = oid, kind = o.kind, x = o.pos.x, y = o.pos.y } end
  end
  local oid = A.join_target(pool, kind, ent.position.x, ent.position.y)
  local o = oid and f.outposts[oid]
  if not o then
    f.next_oid = (f.next_oid or 0) + 1
    oid = f.next_oid
    o = { id = oid, kind = kind, pos = { x = ent.position.x, y = ent.position.y }, drills = 0, drill_list = {}, sinks = {}, turret_list = {},
      last_service = game.tick, adopted = true, site_info = {},
      -- jamais agrandi par des paires de l'équipe (c'est la paire du joueur) : plein pour de bon, au sens de pose_paires
      full = true, full_by = "pose_paires", full_why = "adopte" }
    f.outposts[oid] = o
    f.outposts_count = (f.outposts_count or 0) + 1
  end
  o.drills = o.drills + 1
  o.drill_list[#o.drill_list + 1] = ent
  o.sinks[#o.sinks + 1] = sink
  State.own(ent, f.id, "drill", oid)
  State.own(sink, f.id, "sink", oid)
  st.drills[u] = { oid = oid, sink = sink.unit_number }
  st.refused[u] = nil
  st.n_drills = (st.n_drills or 0) + 1
  f.stats = f.stats or {}
  f.stats.adopted = (f.stats.adopted or 0) + 1
  say(f, st, string.format("%s adopte en (%.1f, %.1f), a %.0f tuiles du coffre (avant-poste %d de %s, %d foreuse(s), reception %s)", ent.name,
    ent.position.x, ent.position.y, math.sqrt(dx * dx + dy * dy), oid, kind, o.drills, sink.name))
  return true
end

--- Lot PARITE : rend au joueur une foreuse adoptée et sa réception (l'entité n'est pas touchée ; ni perte d'avant-poste, ni pénalité).
local function release_drill(f, unit, why)
  local st = f.adopt
  local rec = st and st.drills and st.drills[unit]
  if not rec then return end
  st.drills[unit] = nil
  local o = f.outposts[rec.oid]
  local ent
  if o then
    for i = #o.drill_list, 1, -1 do
      if o.drill_list[i].valid and o.drill_list[i].unit_number == unit then ent = table.remove(o.drill_list, i) end
    end
    for i = #o.sinks, 1, -1 do
      if o.sinks[i].valid and o.sinks[i].unit_number == rec.sink then table.remove(o.sinks, i) end
    end
    o.drills = math.max(0, o.drills - 1)
    if o.drills == 0 then
      f.outposts[rec.oid] = nil
      f.outposts_count = math.max(0, (f.outposts_count or 1) - 1)
    end
  end
  State.disown(unit)
  State.disown(rec.sink)
  st.refused[unit] = why
  st.released = (st.released or 0) + 1
  say(f, st, string.format("foreuse %s rendue au joueur%s (%s)", tostring(unit),
    ent and ent.valid and string.format(" en (%.1f, %.1f)", ent.position.x, ent.position.y) or "", why))
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
  if not (st and BLOCKER[ent.type]) then return end
  local p = ent.position
  -- Lot PARITE : une paire foreuse + réception touchée par une ligne (hors la foreuse qui vient d'être posée) est rendue au joueur
  if st.drills and next(st.drills) ~= nil then
    local give = {}
    for _, oid in ipairs(State.sorted_keys(f.outposts)) do
      local o = f.outposts[oid]
      if o.adopted then
        for _, d in ipairs(o.drill_list) do
          if d.valid and st.drills[d.unit_number] and d.unit_number ~= ent.unit_number and d.surface == ent.surface then
            local sink
            for _, s in ipairs(o.sinks) do
              if s.valid and s.unit_number == st.drills[d.unit_number].sink then sink = s end
            end
            for _, m in ipairs({ d, sink }) do
              if m then
                local hw, hh = half_size(m)
                if math.abs(p.x - m.position.x) <= hw + A.CLEAR and math.abs(p.y - m.position.y) <= hh + A.CLEAR then
                  give[#give + 1] = d.unit_number
                  break
                end
              end
            end
          end
        end
      end
    end
    table.sort(give)
    for _, u in ipairs(give) do release_drill(f, u, "ligne") end
  end
  if not (st.n > 0) then return end
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
    if ent.type == "mining-drill" then Adopte.consider_drill(f, ent) end
  elseif R.ADOPT[ent.type] then
    -- Lot PARITE : la réception posée APRÈS la foreuse (paire dans l'autre ordre) : la foreuse voisine est étudiée à son tour
    local adopted = Adopte.consider(f, ent)
    if not adopted and (ent.type == "furnace" or ent.type == "container") then
      local near = ent.surface.find_entities_filtered({ position = ent.position, radius = 4, type = { "mining-drill" }, force = f.force })
      table.sort(near, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
      for _, d in ipairs(near) do Adopte.consider_drill(f, d) end
    end
  end
end

--- Lot PARITE : le joueur (ou ses robots) ramasse une foreuse adoptée : elle sort de l'équipe SANS compter comme une perte d'avant-poste.
local function on_mined(e)
  local ent = e.entity
  if not (ent and ent.valid) then return end
  local f = team()
  if not (f and f.adopt) then return end
  if ent.type == "mining-drill" then
    if f.adopt.drills and f.adopt.drills[ent.unit_number] then release_drill(f, ent.unit_number, "ramassee") end
    return
  end
  -- s40 : une machine adoptée ramassée sort de l'état (f.adopt.units) et de la liste d'équipe : avant, son numéro restait pour toujours
  -- dans la table et l'entité (invalide) dans le registre
  local reg, u = R.ADOPT[ent.type], ent.unit_number
  if reg and u and f.adopt.units and f.adopt.units[u] then
    f.adopt.units[u] = nil
    local list = list_of(f, reg.registry) or {}
    for i = #list, 1, -1 do
      if list[i] == ent then table.remove(list, i) end
    end
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
    local mine_drills = {}
    for u in pairs(st.drills or {}) do mine_drills[#mine_drills + 1] = u end
    table.sort(mine_drills)
    for _, u in ipairs(mine_drills) do
      release_drill(f, u, "coupe")
      given = given + 1
    end
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
  -- Lot PARITE : les paires foreuse + réception déjà posées dans le rayon de service
  local drills = surface.find_entities_filtered({ position = f.hq_pos, radius = A.RADIUS, force = f.force, type = { "mining-drill" } })
  table.sort(drills, function(a, b) return (a.unit_number or 0) < (b.unit_number or 0) end)
  for _, ent in ipairs(drills) do
    if Adopte.consider_drill(f, ent, sinks) then taken = taken + 1 end
  end
  return taken, given
end

Events.on(defines.events.on_built_entity, on_built)
Events.on(defines.events.on_robot_built_entity, on_built)
Events.on(defines.events.on_player_mined_entity, on_mined)
Events.on(defines.events.on_robot_mined_entity, on_mined)
Events.on_configuration_changed(function() Adopte.migrate() end)

remote.add_interface("fo-adopte", {
  -- Pose simulée par un banc : le moteur interdit à un script de lever on_built_entity (doc de LuaBootstrap.raise_event) ; cette
  -- fonction appelle le même gestionnaire que l'événement.
  built = function(ent) on_built({ created_entity = ent }) end,
  migrate = function() return Adopte.migrate() end,
  status = function()
    local f = team()
    local st = f and f.adopt
    if not st then return { n = 0, listed = 0, released = 0, drills = 0 } end
    local n, nd = 0, 0
    for _ in pairs(st.units) do n = n + 1 end
    for _ in pairs(st.drills or {}) do nd = nd + 1 end
    return { n = st.n, listed = n, released = st.released or 0, drills = nd }
  end,
})

return Adopte
