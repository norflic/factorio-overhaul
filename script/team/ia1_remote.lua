--[[
  Interface distante « fo-ia1 » (lot IA1-a, docs/EQUIPES_PNJ.md §16) : mesures des équipes de PNJ (lecture ; une
  seule écriture, set_setting, pour les bancs), pour les bancs (le mod de test n'a pas accès à `global` de ce mod) et pour l'interface du lot IA1-b.

    remote.call("fo-ia1", "teams") -> { { key, force, n, max, wanted, recruited, guard, thinks, n_sum,
                                          idle_sum, surplus_sum, backlog_sum, last = { n, idle, idle_pct,
                                          backlog_s, surplus }, produced_mu, produced = { [objet] = n },
                                          delivered = { [objet] = n }, nav_fail, goal_moved, rescued,
                                          slots_bad, slots_owned }, ... }  factions vivantes (ordre des id), puis
                                          votre équipe (clé « player ») si elle existe ;
    remote.call("fo-ia1", "path")  -> statistiques du service de chemins (demandes, émissions, réussites,
                                       échecs par cause, au plus haut : demandes en vol, file) + agents riches.
    remote.call("fo-ia1", "set_setting", name, value) -> valeur lue (correction IA1-a : bancs seulement ; un
                                       réglage des équipes, S.SETTINGS ; nil sinon).
  Une seule écriture (set_setting) ; aucune fonction ni objet du moteur dans les résultats. `held` : pensées où
  le frein par le travail (fo-recruit-idle-max) a retenu une recrue.
]]

local Storage = require("script.core.storage")
local State = require("script.faction.state")
local Stock = require("script.team.stock") -- lot COFFRE : stock = coffre du QG + annexes
local Registry = require("script.companion.registry")
local Scale = require("shared.team.scale")
local Team = require("script.team.team")
local Poles = require("script.team.poles")
local Config = require("script.core.config")

-- Lot IA1-b (docs §8.6, pilotage sans clic) :
--   team_status(key)                 -> état d'organisation publié (Poles.status) ou nil ;
--   set_orientation(key, o)          -> points normalisés { e, b, t } ou nil (préréglage, table ou liste) ;
--   inject_crisis(key, n, ticks, res) -> vrai : n tâches de minage d'extraction rouvertes pendant `ticks` (bancs) ;
--   kill_npc(key, id)                -> vrai si le PNJ de cette équipe a été retiré (mort simulée, bancs).
-- Les autres verbes du §8.6 (set_target, add_zone, resurrect, promote) arrivent avec IA1-e1, IA1-g et IA1-h.
local function team_of(key)
  if key == "player" then return State.faction("player") end
  for _, id in ipairs(State.alive()) do
    local f = State.faction(id)
    if f and (f.key == key or id == key) then return f end
  end
  return nil
end

local PRODUCED = { "iron-plate", "copper-plate", "coal", "stone", "iron-ore", "copper-ore" }

local function copy_fields(src, names)
  local out = {}
  for _, k in ipairs(names) do out[k] = (src and src[k]) or 0 end
  return out
end

local function team_row(f)
  if not (f and f.team and f.hq and f.hq.valid) then return nil end
  local acc = f.team.scale or {}
  local st = f.stats or {}
  local row = {
    key = f.key or "player", force = f.force, n = f.engineers_count or 0, max = Team.npc_max(f),
    recruited = st.recruited or 0, guard = st.recruit_guard or 0, held = st.recruit_held or 0,
    thinks = acc.thinks or 0, n_sum = acc.n_sum or 0, idle_sum = acc.idle_sum or 0,
    surplus_sum = acc.surplus_sum or 0, backlog_sum = acc.backlog_sum or 0,
    last = acc.last and copy_fields(acc.last, { "n", "idle", "idle_pct", "backlog_s", "surplus" }) or nil,
    delivered = copy_fields(f.team.delivered, PRODUCED),
    collected = f.team.collected or 0, mined = st.mined or 0,
    nav_fail = st.nav_fail or 0, goal_moved = st.goal_moved or 0, rescued = st.rescued or 0,
    soldiers = f.soldiers_count or 0, tech = f.tech or 0, outposts = f.outposts_count or 0,
    -- Lot IA1-b2 (mesures) : PNJ perdus (toutes causes, puis tués par les ennemis), tourelles vivantes, fer du QG.
    lost = st.engineers_lost or 0, lost_enemy = st.lost_enemy or 0, iron = Stock.count(f, "iron-plate"),
    idle_rien = (f.team.idle_why or {}).rien or 0, idle_bloque = (f.team.idle_why or {}).bloque or 0,
    idle_manque = (f.team.idle_why or {}).manque or 0,
    -- Lot IA3-d : règle d'effectif d'une faction (dernière pensée) : raison, recrues de croissance, travail en attente.
    eff_reason = (f.team.effectif and f.team.effectif.last_d and f.team.effectif.last_d.reason) or "",
    eff_grown = (f.team.effectif and f.team.effectif.grown) or 0,
    eff_waiting = (f.team.effectif and f.team.effectif.last_d and f.team.effectif.last_d.waiting) or 0,
    eff_hands = (f.team.effectif and f.team.effectif.last_d and f.team.effectif.last_d.hands) or 0,
  }
  local turrets, defended, hq_t = 0, {}, 0
  for _, id in ipairs(State.sorted_keys(f.turrets or {})) do
    local t = f.turrets[id]
    if t.valid then
      turrets = turrets + 1
      local owner = State.owner(id)
      if owner and owner.oid then defended[owner.oid] = true else hq_t = hq_t + 1 end
    end
  end
  local def_n = 0
  for _, oid in ipairs(State.sorted_keys(f.outposts or {})) do if defended[oid] then def_n = def_n + 1 end end
  row.turrets, row.outposts_defended, row.hq_turrets = turrets, def_n, hq_t
  -- Production de la force (statistiques du moteur : aucune entité parcourue).
  local force = game.forces[f.force]
  local produced, mu = {}, 0
  -- Lecture protégée : le moteur simulé des tests hors jeu n'a pas de statistiques de production.
  local ok = force and pcall(function()
    local stats = force.item_production_statistics
    for _, name in ipairs(PRODUCED) do produced[name] = stats.get_input_count(name) end
  end)
  if ok then
    for _, it in ipairs(Scale.MU_ITEMS) do mu = mu + (produced[it[1]] or 0) * it[2] end
  else
    produced, mu = {}, -1
  end
  row.produced, row.produced_mu = produced, mu
  local bad, owned = 0, 0
  for i = 1, #Scale.HOME_SLOTS do
    if f.slot_bad and f.slot_bad[i] then bad = bad + 1 end
    if f.slot_owner and f.slot_owner[i] ~= nil then owned = owned + 1 end
  end
  row.slots_bad, row.slots_owned = bad, owned
  return row
end

remote.add_interface("fo-ia1", {
  teams = function()
    local out = {}
    for _, id in ipairs(State.alive()) do
      local r = team_row(State.faction(id))
      if r then out[#out + 1] = r end
    end
    local r = team_row(State.faction("player"))
    if r then out[#out + 1] = r end
    return out
  end,
  path = function()
    local P = Storage.ns("path")
    local st = P.stats
    local out = {}
    for _, k in ipairs({ "requested", "issued", "ok", "fail", "retry", "timeout", "dropped", "latency_sum",
      "fail_start", "fail_water", "fail_blocked", "fail_other", "start_moved", "inflight_max", "queue_max",
      "issued_tick_max" }) do
      out[k] = st[k] or 0
    end
    out.queued = P.tail - P.head + 1
    out.inflight = P.inflight_count
    out.agents = Registry.count()
    return out
  end,
  -- Correction IA1-a : SEULE écriture de l'interface, pour les bancs (un mod ne peut écrire que SES réglages :
  -- le mod de test passe par ici). Réglages des équipes seulement (S.SETTINGS) ; valeur bornée par Scale.read.
  -- Rend la valeur lue ensuite, ou nil si le réglage n'est pas un réglage des équipes.
  set_setting = function(name, value)
    local known = false
    for _, s in ipairs(Scale.SETTINGS) do if s.name == name then known = true end end
    if not known or type(value) ~= "number" then return nil end
    local v = Scale.read(name, function() return value end)
    settings.global[name] = { value = v }
    Config.invalidate()
    return Scale.read(name, function(n) return settings.global[n].value end)
  end,
  team_status = function(key)
    local f = team_of(key)
    return f and f.team and Poles.status(f) or nil
  end,
  set_orientation = function(key, o)
    local f = team_of(key)
    if not (f and f.team) then return nil end
    return Poles.set_orientation(f, o)
  end,
  inject_crisis = function(key, n, ticks, resource)
    local f = team_of(key)
    if not (f and f.team) or type(n) ~= "number" or type(ticks) ~= "number" then return false end
    return Poles.inject_crisis(f, math.max(1, math.min(40, math.floor(n))), math.max(60, math.floor(ticks)), resource)
  end,
  kill_npc = function(key, id)
    local f = team_of(key)
    if not (f and f.engineers and f.engineers[id]) then return false end
    Registry.remove(id, true)
    return true
  end,
})

return {}
