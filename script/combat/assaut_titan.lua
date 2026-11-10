--[[
  Lot ASSAUTS-TITANESQUES (10/11) : ASSAUTS DE BOSS coordonnés en moteur réel. Règles pures : shared/combat/assaut_titan.lua (Ra).
  Requis par script/td/director.lua (combat), interface distante « assaut » (script/remote.lua) pour les bancs.

  - Toutes les PENSEE ticks, sans assaut en cours : l'évolution de la force naturelle, l'âge de la partie (le plus haut des forces :
    factions vivantes et équipe du joueur, Armee.age) et les BASES (QG des factions et de l'équipe du joueur, tourelles relevées à
    Ra.DEFENSE_R) sont lus ; Ra.pret dit si un assaut part, Ra.cible qui est visé (rotation, la mieux défendue), Ra.composition qui vient.
  - Les assaillants sont des unités de la force NATURELLE (« enemy ») : les factions les voient comme des envahisseurs (DefChoix, soldats,
    front, reconstruction : les chemins existants réagissent sans rien de neuf), le joueur aussi.
  - Phases (Ra.suivante) : annonce (message FR/EN, points rouges sur la carte du joueur) -> rassemblement (apparition étalée,
    TD.spawn_per_second par seconde, groupes par point) -> marche (attaque de zone, groupes relancés) -> assaut -> fin ; repli si le
    Kaiju meurt (retour aux points, rappel au bout de Ra.REPLI). Journal [FO-ASSAUT] une ligne par phase.
  - Rien de mesuré en temps, aucun pairs sur une décision (listes), hasard : RNG maison (décalage du cercle des points seulement),
    aucune fonction dans l'état sauvegardé, aucun nom d'objet en dur (noms par la règle pure, lus aux données).
]]

local Events = require("script.core.events")
local Storage = require("script.core.storage")
local RNG = require("script.core.rng")
local Ra = require("shared.combat.assaut_titan")
local T = require("shared.robots.titans")
local TD = require("shared.td.waves")
local Tc = require("shared.team.config")
local State = require("script.faction.state")
local Armee = require("script.robots.armee")

local M = {}

local PENSEE = 600          -- une pensée toutes les 10 s hors assaut
local PAS = 60              -- un pas de la machine à phases par seconde pendant un assaut
local RELANCE = 600         -- groupes relancés toutes les 10 s pendant la marche

Storage.declare("assaut", function()
  return { n = 0, last = nil, recent = {}, cur = nil }
end)

local function S() return Storage.ns("assaut") end

local function say(msg)
  game.print(msg)
end

local function horde() return game.forces.enemy end

local function nom_base(b)
  if b.key then return { "fo-faction.name-" .. b.key } end
  return { "fo-faction.name-player" }
end

local function defenses_de(surface, pos, force)
  return surface.count_entities_filtered({ position = pos, radius = Ra.DEFENSE_R, force = force, type = Tc.TURRET_TYPES })
end

--- Bases candidates (ordre stable : factions par id trié, puis l'équipe du joueur) et âges de leurs forces.
local function bases(surface)
  local out, ages = {}, {}
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and f.hq_pos and f.force and game.forces[f.force] then
      local force = game.forces[f.force]
      out[#out + 1] = { id = id, key = f.key, pos = { x = f.hq_pos.x, y = f.hq_pos.y }, force = force, defenses = defenses_de(surface, f.hq_pos, force) }
      ages[#ages + 1] = Armee.age(force)
    end
  end
  local pt = State.faction("player")
  local pf = game.forces.player
  ages[#ages + 1] = Armee.age(pf)
  if pt and pt.hq_pos then
    out[#out + 1] = { id = "player", pos = { x = pt.hq_pos.x, y = pt.hq_pos.y }, force = pf, defenses = defenses_de(surface, pt.hq_pos, pf) }
  end
  return out, ages
end

local function journal(cur, phase, issue, detail)
  log(Ra.ligne(cur.cible.id, cur.n, phase, issue, detail))
end

local function clear_tags(cur)
  for _, tag in ipairs(cur.tags or {}) do if tag.valid then tag.destroy() end end
  cur.tags = {}
end

local function phase(cur, ph, tick, issue, detail)
  cur.phase, cur.t_phase, cur.issue = ph, tick, issue
  journal(cur, ph, issue, detail)
end

--- Points de rassemblement sur la terre ferme (règle pure + terrain), annoncés sur la carte du joueur.
local function points(surface, cur)
  local n = Ra.n_points(Ra.total(cur.compo))
  local cran = RNG.range(0, 11)
  local out = {}
  for _, p in ipairs(Ra.points(cur.cible.pos, n, cran)) do
    surface.request_to_generate_chunks(p, 1)
    surface.force_generate_chunk_requests()
    local q = surface.find_non_colliding_position(cur.compo[1][1], p, 48, 2) or p
    out[#out + 1] = q
    local tag = game.forces.player.add_chart_tag(surface, { position = q, icon = { type = "virtual", name = "signal-red" }, text = "Assaut" })
    if tag then cur.tags[#cur.tags + 1] = tag end
  end
  cur.points = out
end

local function commander_attaque(g, cur)
  g.set_command({ type = defines.command.attack_area, destination = cur.cible.pos, radius = Ra.CIBLE_R, distraction = defines.distraction.by_enemy })
  g.start_moving()
end

local function commander_repli(g, cur, k)
  g.set_command({ type = defines.command.go_to_location, destination = cur.points[k] or cur.points[1], distraction = defines.distraction.none })
  g.start_moving()
end

local function apparaitre(surface, cur)
  local force = horde()
  local budget = TD.spawn_per_second
  while budget > 0 and #cur.pending > 0 do
    local entry = cur.pending[1]
    local k = Ra.point_de(cur.spawned + 1, #cur.points)
    local sp = cur.points[k]
    local pos = surface.find_non_colliding_position(entry[1], sp, 24, 0.5)
    if not pos then break end
    local u = surface.create_entity({ name = entry[1], position = pos, force = force })
    if u then
      cur.units[#cur.units + 1] = u
      if T.kaiju_era_of_name(u.name) then cur.kaijus[#cur.kaijus + 1] = u end
      local g = cur.groups[k]
      if not (g and g.valid) then
        g = surface.create_unit_group({ position = sp, force = force })
        cur.groups[k] = g
      end
      g.add_member(u)
    end
    cur.spawned = cur.spawned + 1
    entry[2] = entry[2] - 1
    if entry[2] <= 0 then table.remove(cur.pending, 1) end
    budget = budget - 1
  end
end

local function recompte(cur)
  local vivants, kaijus = {}, 0
  for _, u in ipairs(cur.units) do
    if u.valid then
      vivants[#vivants + 1] = u
      if T.kaiju_era_of_name(u.name) then kaijus = kaijus + 1 end
    end
  end
  cur.units = vivants
  return #vivants, kaijus
end

local function d2(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function arrives(cur)
  local r2 = Ra.CIBLE_R * Ra.CIBLE_R
  for k = 1, #cur.points do
    local g = cur.groups[k]
    if g and g.valid and #g.members > 0 and d2(g.position, cur.cible.pos) <= r2 then return true end
  end
  return false
end

--- Groupes finis ou errants relancés ; unités sans groupe regroupées (marche et assaut).
local function relancer(surface, cur)
  local orphelins = {}
  for _, u in ipairs(cur.units) do
    if u.valid and not (u.unit_group and u.unit_group.valid) then orphelins[#orphelins + 1] = u end
  end
  if #orphelins > 0 then
    local g = surface.create_unit_group({ position = orphelins[1].position, force = horde() })
    for _, u in ipairs(orphelins) do g.add_member(u) end
    cur.groups[#cur.groups + 1] = g
    commander_attaque(g, cur)
  end
  for k = 1, #cur.groups do
    local g = cur.groups[k]
    if g and g.valid and #g.members > 0 then
      local st = g.state
      if st == defines.group_state.finished or st == defines.group_state.wander_in_group then commander_attaque(g, cur) end
    end
  end
end

local function fin(cur, tick, issue)
  local st = S()
  clear_tags(cur)
  for _, u in ipairs(cur.units) do if u.valid then u.destroy() end end
  for _, g in ipairs(cur.groups) do if g and g.valid then g.destroy() end end
  cur.units, cur.groups = {}, {}
  say({ "fo-assaut." .. issue, nom_base(cur.cible), cur.n })
  st.cur = nil
end

local function demarrer(surface, cible, tick, preavis)
  local st = S()
  st.n = st.n + 1
  st.last = tick
  st.recent[#st.recent + 1] = cible.id
  local age = cible.age
  local compo = Ra.composition(age, cible.defenses)
  local cur = { n = st.n, cible = { id = cible.id, key = cible.key, pos = cible.pos, force_name = cible.force.name }, compo = compo, pending = {},
    phase = "annonce", t0 = tick, t_phase = tick, preavis = preavis, points = {}, groups = {}, units = {}, kaijus = {}, spawned = 0, tags = {},
    next_relance = tick }
  for _, it in ipairs(compo) do cur.pending[#cur.pending + 1] = { it[1], it[2] } end
  st.cur = cur
  points(surface, cur)
  say({ "fo-assaut.annonce", nom_base(cur.cible), math.floor((preavis or Ra.ANNONCE) / 60), Ra.total(compo), { "entity-name." .. compo[1][1] } })
  journal(cur, "annonce", nil, string.format("age %d, %d tourelles, %d assaillants dont %d kaiju(s) %s", age, cible.defenses, Ra.total(compo),
    compo[1][2], compo[1][1]))
  return cur
end

--- Pensée hors assaut : un assaut part si la règle le dit.
local function penser(ev)
  local st = S()
  if st.cur then return end
  local surface = game.surfaces[1]
  local liste, ages = bases(surface)
  local age = Ra.age_partie(ages)
  local ok, why = Ra.pret({ tick = ev.tick, last = st.last, evolution = horde().evolution_factor, age = age, bases = #liste })
  if not ok then return end
  local cible, raison = Ra.cible(liste, st.recent)
  if not cible then return end
  cible.age = age
  demarrer(surface, cible, ev.tick, nil)
  journal(st.cur, "cible", nil, raison .. " (" .. tostring(why) .. ")")
end

--- Un pas de l'assaut en cours.
local function pas(ev)
  local st = S()
  local cur = st.cur
  if not cur then return end
  local surface = game.surfaces[1]
  local tick = ev.tick
  if cur.phase == "rassemblement" and #cur.pending > 0 then apparaitre(surface, cur) end
  local vivants, kaijus = recompte(cur)
  local obs = { tick = tick, tout_apparu = #cur.pending == 0, vivants = vivants, kaijus_vivants = kaijus }
  if cur.phase == "marche" or cur.phase == "assaut" then
    if tick >= cur.next_relance then
      relancer(surface, cur)
      cur.next_relance = tick + RELANCE
    end
    obs.arrives = arrives(cur)
    if cur.phase == "assaut" then
      obs.defenses = defenses_de(surface, cur.cible.pos, game.forces[cur.cible.force_name] or game.forces.player)
    end
  end
  -- préavis des bancs (interface distante) : la règle lit Ra.ANNONCE ; un préavis plus court avance l'entrée dans la phase
  local st_regle = { phase = cur.phase, t0 = cur.t0, t_phase = cur.t_phase, issue = cur.issue }
  if cur.phase == "annonce" and cur.preavis and tick - cur.t_phase >= cur.preavis then st_regle.t_phase = tick - Ra.ANNONCE end
  local suivante, issue = Ra.suivante(st_regle, obs)
  if suivante == cur.phase then return end
  if suivante == "fin" then
    phase(cur, "fin", tick, issue, string.format("%d vivant(s), %d kaiju(s)", vivants, kaijus))
    fin(cur, tick, issue)
    return
  end
  phase(cur, suivante, tick, nil, string.format("%d vivant(s), %d kaiju(s)", vivants, kaijus))
  if suivante == "marche" then
    for k = 1, #cur.groups do
      local g = cur.groups[k]
      if g and g.valid then commander_attaque(g, cur) end
    end
    say({ "fo-assaut.marche", nom_base(cur.cible), vivants })
  elseif suivante == "repli" then
    for k = 1, #cur.groups do
      local g = cur.groups[k]
      if g and g.valid then commander_repli(g, cur, k) end
    end
    say({ "fo-assaut.kaiju-mort", nom_base(cur.cible) })
  end
end

---------------------------------------------------------------------------------------------------
-- Interface (bancs et commandes) : état, départ forcé
---------------------------------------------------------------------------------------------------
function M.state()
  local st = S()
  local cur = st.cur
  return { n = st.n, last = st.last, phase = cur and cur.phase or "aucun", cible = cur and cur.cible.id or nil, vivants = cur and #cur.units or 0,
    kaijus = cur and #cur.kaijus or 0, apparus = cur and cur.spawned or 0 }
end

--- Départ forcé (bancs, commandes) : opts = { preavis (ticks), cible = { x, y } (une position quelconque : base « banc » sans tourelles),
--- age (âge forcé) }. Sans base ni position : le point de départ du joueur. Rend l'état.
function M.force_now(opts)
  opts = opts or {}
  local st = S()
  if st.cur then return M.state() end
  local surface = game.surfaces[1]
  local liste, ages = bases(surface)
  local age = opts.age or Ra.age_partie(ages)
  local cible
  if opts.cible then
    cible = { id = "banc", pos = { x = opts.cible.x or opts.cible[1], y = opts.cible.y or opts.cible[2] }, force = game.forces.player, defenses = opts.defenses or 0 }
    surface.request_to_generate_chunks(cible.pos, 2)
    surface.force_generate_chunk_requests()
  else
    cible = Ra.cible(liste, st.recent)
    if not cible then
      local p = game.forces.player.get_spawn_position(surface)
      cible = { id = "player", pos = { x = p.x, y = p.y }, force = game.forces.player, defenses = defenses_de(surface, p, game.forces.player) }
    end
  end
  cible.age = age
  demarrer(surface, cible, game.tick, opts.preavis)
  return M.state()
end

Events.on_nth_tick(PENSEE, penser)
Events.on_nth_tick(PAS, pas)

return M
