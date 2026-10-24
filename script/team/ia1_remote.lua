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
local Registry = require("script.companion.registry")
local Scale = require("shared.team.scale")
local Team = require("script.team.team")
local Config = require("script.core.config")

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
  }
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
})

return {}
