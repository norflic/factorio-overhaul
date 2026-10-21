--[[
  Interface distante "factorio-overhaul" : pilotage sans joueur (tests automatisés en moteur réel,
  scénarios, autres mods). Utilisée par le mod de test fo-autotest (tools/autotest/).

    remote.call("factorio-overhaul", "war_start", n, soldats, ingenieurs, distance) -> bool
    remote.call("factorio-overhaul", "war_fund", MU)                              -> factions financées
    remote.call("factorio-overhaul", "companions_spawn", n, rayon)                 -> nombre créé
    remote.call("factorio-overhaul", "profiler", true|false)
    remote.call("factorio-overhaul", "reset_stats")
    remote.call("factorio-overhaul", "log_report", etiquette)   -- écrit bench + guerre dans le journal
]]

local Profiler = require("script.core.profiler")
local Bench = require("script.companion.bench")
local War = require("script.faction.war")
local F = require("shared.faction.config")
local State = require("script.faction.state")
local Director = require("script.td.director") -- require interdit dans un gestionnaire d'événement
local Team = require("script.team.team")
local Levels = require("script.levels.levels")
local Storage = require("script.core.storage")

local function surface() return game.surfaces[1] end

local function log_lines(lines)
  for _, line in ipairs(lines) do log(line) end
end

remote.add_interface("factorio-overhaul", {
  war_start = function(n, soldiers, engineers, distance)
    local s = surface()
    local ok = War.start_at(s, game.forces.player.get_spawn_position(s), n or 4, soldiers or 100, engineers or 10, distance or F.defaults.distance)
    return ok and true or false
  end,
  war_fund = function(amount)
    return War.fund(amount or 1000)
  end,
  war_option = function(key, value)
    local s = State.war().settings
    if s then s[key] = value end
    return s ~= nil
  end,
  companions_spawn = function(n, radius)
    local s = surface()
    return Bench.spawn_at(s, game.forces.player.get_spawn_position(s), game.forces.player, nil, n or 20, "wander", radius or 32)
  end,
  -- Mode défense de tours : "on" [délai en secondes] | "off" | "next" | "status" -> état
  waves = function(action, delay_s)
    if action == "on" then Director.start(delay_s and math.floor(delay_s * 60) or nil)
    elseif action == "off" then Director.stop()
    elseif action == "next" then Director.next() end
    local st = Director.state()
    return { active = st.active, wave = st.wave, phase = st.phase, alive = st.alive, kills = st.stats.kills, cleared = st.stats.cleared, leaked = st.stats.leaked }
  end,
  -- Équipe du joueur (coffre d'équipe) : ligne d'état, ou nil s'il n'y en a pas.
  team_status = function()
    local f = State.faction("player")
    if not (f and f.hq and f.hq.valid) then return nil end
    return Team.status_line(f)
  end,
  -- Points d'intérêt (lecture seule) pour la revue visuelle : QG et avant-postes des factions et de
  -- l'équipe du joueur. Le mod de test n'a pas accès à `global` de ce mod (une table par mod).
  points_of_interest = function()
    local function team(f)
      if not (f and f.hq and f.hq.valid) then return nil end
      local t = { key = f.key or "player", hq = { x = f.hq_pos.x, y = f.hq_pos.y }, outposts = {} }
      local ids = {}
      for oid in pairs(f.outposts or {}) do ids[#ids + 1] = oid end
      table.sort(ids)
      for _, oid in ipairs(ids) do
        local o = f.outposts[oid]
        t.outposts[#t.outposts + 1] = { kind = o.kind, pos = { x = o.pos.x, y = o.pos.y } }
      end
      return t
    end
    local out = { factions = {} }
    for _, id in ipairs(State.alive()) do
      local t = team(State.faction(id))
      if t then out.factions[#out.factions + 1] = t end
    end
    out.player = team(State.faction("player"))
    return out
  end,
  -- Niveaux (session 5) : lancer une amélioration sans joueur (paiement : centre de commandement).
  levels_upgrade = function(entity)
    local ok, reason = Levels.start(entity, nil)
    return { ok = ok, reason = reason }
  end,
  levels_row = function(entity)
    return Levels.start_row(entity, nil)
  end,
  levels_time_factor = function(f)
    Storage.ns("levels").time_factor = f
  end,
  levels_status = function(force_name)
    local force = game.forces[force_name or "player"]
    local st = Storage.ns("levels")
    local jobs = 0
    for _, j in pairs(st.jobs) do if j.force == force.name then jobs = jobs + 1 end end
    return { cc_level = Levels.cc_level(force), busy = Levels.busy(force), jobs = jobs,
             upgrades = st.stats.upgrades, instant = st.stats.instant, lost = st.stats.lost,
             cancelled = st.stats.cancelled, fallback = st.stats.fallback or 0 }
  end,
  profiler = function(on)
    Profiler.set_enabled(on and true or false, game.tick)
  end,
  reset_stats = function()
    Bench.reset_stats(game.tick)
  end,
  log_report = function(label)
    log("[FO-AUTOTEST] ===== " .. tostring(label) .. " (tick " .. game.tick .. ") =====")
    local lines, prof_lines = Bench.report_lines(game.tick)
    log_lines(lines)
    log_lines(prof_lines)
    log_lines(War.status_lines(game.tick))
  end,
})

return {}
