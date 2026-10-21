--[[
  Banc d'essai du compagnon (commande /fo-bench). Outil de R&D, réservé aux admins en multijoueur.

    /fo-bench spawn <n> [rayon]   crée n compagnons en errance autour de vous (rayon d'errance, défaut 32)
    /fo-bench follow <n>          crée n compagnons qui vous suivent
    /fo-bench clear               supprime tous les compagnons
    /fo-bench mode lazy|every     mode d'écriture de walking_state (hypothèse H1)
    /fo-bench prof on|off         active la mesure LuaProfiler par sous-système
    /fo-bench reset               remet les compteurs à zéro (début de fenêtre de mesure)
    /fo-bench report              affiche le rapport, l'écrit dans factorio-current.log et dans
                                  script-output/fo-bench/report.txt

  Les commandes sont des actions joueur synchronisées : leurs effets sont déterministes en multijoueur.
]]

local Storage = require("script.core.storage")
local Config = require("script.core.config")
local Profiler = require("script.core.profiler")
local Scheduler = require("script.core.scheduler")
local PathService = require("script.core.path_service")
local RNG = require("script.core.rng")
local Registry = require("script.companion.registry")
local Locomotion = require("script.companion.locomotion")
local Brain = require("script.companion.brain")
local C = require("script.companion.constants")

local Bench = {}

local MAX_SPAWN = 2000

local function fmt(x, digits)
  return string.format("%." .. (digits or 2) .. "f", x)
end

local function reset_stats(tick)
  PathService.reset_stats()
  local ls = Locomotion.stats()
  ls.steers, ls.writes, ls.arrivals = 0, 0, 0
  local cs = Registry.stats()
  cs.dist, cs.move_ticks, cs.stuck, cs.path_fail, cs.since = 0, 0, 0, 0, tick
  if Profiler.enabled() then Profiler.set_enabled(true, tick) end
end

function Bench.spawn_at(surface, center, force, owner_index, n, behavior, radius)
  local made = 0
  for _ = 1, n do
    local pos = { x = center.x + (RNG.float() * 2 - 1) * 6, y = center.y + (RNG.float() * 2 - 1) * 6 }
    local agent = Registry.spawn(surface, pos, force, owner_index, { behavior = behavior, wander_radius = radius })
    if agent then
      Brain.attach(agent, game.tick)
      agent.pause_until = game.tick + RNG.range(0, 120) -- désynchronise les départs
      made = made + 1
    end
  end
  return made
end

local function spawn(player, n, behavior, radius)
  return Bench.spawn_at(player.surface, player.position, player.force, player.index, n, behavior, radius)
end

function Bench.reset_stats(tick) reset_stats(tick) end

--- Construit le rapport : liste de lignes (chaînes) + lignes profiler (LocalisedString).
function Bench.report_lines(tick)
  local lines = {}
  local cs = Registry.stats()
  local window = tick - cs.since
  local counts = Brain.state_counts()
  local queued, inflight = PathService.queued()
  local ps = Storage.ns("path").stats
  local ls = Locomotion.stats()
  local v = Locomotion.speed()
  local mode = Locomotion.mode()

  lines[#lines + 1] = string.format("[FO-BENCH] tick=%d fenetre=%d ticks | mode=%s | pilotage k=%d | cerveau P=%d | inflight max=%d",
    tick, window, mode, Config.get("steer_period"), Config.get("brain_period"), Config.get("path_max_inflight"))
  lines[#lines + 1] = string.format("  Agents: %d (idle %d, pathing %d, moving %d) | voie loco: %d | voie cerveau: %d",
    Registry.count(), counts.idle or 0, counts.pathing or 0, counts.moving or 0,
    Scheduler.count(C.LANE_LOCO), Scheduler.count(C.LANE_BRAIN))
  local lat = ps.ok > 0 and ps.latency_sum / ps.ok or 0
  local wps = ps.ok > 0 and ps.waypoints_sum / ps.ok or 0
  lines[#lines + 1] = string.format("  Pathfinding: demandes %d, emises %d, ok %d, echecs %d, retry %d, timeout %d, abandon %d | file %d, en vol %d | latence moy %s ticks | waypoints moy %s",
    ps.requested, ps.issued, ps.ok, ps.fail, ps.retry, ps.timeout, ps.dropped, queued, inflight, fmt(lat, 1), fmt(wps, 1))
  if ps.fail > 0 then
    lines[#lines + 1] = string.format("  Echecs de chemin : depart bloque %d, but sur l'eau %d, but occupe %d, inaccessible %d | departs degages %d | derniers : %s",
      ps.fail_start or 0, ps.fail_water or 0, ps.fail_blocked or 0, ps.fail_other or 0, ps.start_moved or 0,
      table.concat(PathService.fail_samples(), " ; "))
  end
  local deaths = Registry.deaths()
  if next(deaths) then
    local parts = {}
    for _, k in ipairs(Registry.sorted_keys(deaths)) do parts[#parts + 1] = k .. "=" .. deaths[k] end
    lines[#lines + 1] = "  Morts d'agents (cause/force:degats) : " .. table.concat(parts, ", ")
  end
  local w = math.max(1, window)
  lines[#lines + 1] = string.format("  Locomotion: pilotages %d (%s/tick), ecritures walking_state %d (%s/tick), arrivees %d, blocages %d, echecs chemin %d",
    ls.steers, fmt(ls.steers / w), ls.writes, fmt(ls.writes / w), ls.arrivals, cs.stuck, cs.path_fail)

  if cs.move_ticks > 0 then
    local eff = cs.dist / (cs.move_ticks * v)
    local verdict
    if cs.move_ticks < 600 then
      verdict = "echantillon trop court (< 600 ticks-agent en mouvement)"
    elseif mode == "lazy" then
      if eff >= C.H1_THRESHOLD then
        verdict = "H1 CONFIRMEE : walking_state persiste, pilotage espace viable"
      else
        verdict = "H1 REJETEE : walking_state ne dure pas, passer en mode every avec k=1"
      end
    else
      verdict = "mode every : reference de comparaison"
    end
    lines[#lines + 1] = string.format("  Efficacite de deplacement: %s (distance %s tuiles / theorique %s) -> %s",
      fmt(eff), fmt(cs.dist, 0), fmt(cs.move_ticks * v, 0), verdict)
  else
    lines[#lines + 1] = "  Efficacite de deplacement: aucune donnee (aucun agent n'a encore bouge)"
  end

  local prof_lines, pwin = Profiler.report(tick)
  if #prof_lines > 0 then
    lines[#lines + 1] = string.format("  Profiler (fenetre %d ticks):", pwin)
  elseif not Profiler.enabled() then
    lines[#lines + 1] = "  Profiler: desactive (/fo-bench prof on)"
  end
  return lines, prof_lines
end

local function emit_report(player, tick)
  local lines, prof_lines = Bench.report_lines(tick)
  local file = "fo-bench/report.txt"
  for i = 1, #lines do
    player.print(lines[i])
    log(lines[i])
    game.write_file(file, lines[i] .. "\n", true, player.index)
  end
  for i = 1, #prof_lines do
    player.print(prof_lines[i])
    log(prof_lines[i])
    game.write_file(file, { "", prof_lines[i], "\n" }, true, player.index)
  end
end

local function split(s)
  local out = {}
  for w in string.gmatch(s or "", "%S+") do out[#out + 1] = w end
  return out
end

local USAGE = "Usage : /fo-bench spawn <n> [rayon] | follow <n> | clear | mode lazy|every | prof on|off | reset | report"

local function run(cmd)
  local player = game.get_player(cmd.player_index)
  if not player then return end -- console serveur : ignoré
  if game.is_multiplayer() and not player.admin then
    player.print("[FO-BENCH] reserve aux admins.")
    return
  end
  local args = split(cmd.parameter)
  local sub = args[1]
  local tick = game.tick

  if sub == "spawn" or sub == "follow" then
    local n = math.floor(tonumber(args[2]) or 10)
    if n < 1 then n = 1 end
    if n > MAX_SPAWN then n = MAX_SPAWN end
    local radius = math.floor(tonumber(args[3]) or 32)
    local behavior = sub == "follow" and "follow" or "wander"
    local made = spawn(player, n, behavior, radius)
    player.print(string.format("[FO-BENCH] %d compagnon(s) cree(s) en mode %s (total %d).", made, behavior, Registry.count()))
  elseif sub == "clear" then
    local ids = Registry.ids()
    for i = 1, #ids do Registry.remove(ids[i], true) end
    player.print(string.format("[FO-BENCH] %d compagnon(s) supprime(s).", #ids))
  elseif sub == "mode" and (args[2] == "lazy" or args[2] == "every") then
    Locomotion.set_mode(args[2])
    reset_stats(tick)
    player.print("[FO-BENCH] mode " .. args[2] .. " (compteurs remis a zero).")
  elseif sub == "prof" and (args[2] == "on" or args[2] == "off") then
    Profiler.set_enabled(args[2] == "on", tick)
    player.print("[FO-BENCH] profiler " .. args[2] .. ".")
  elseif sub == "reset" then
    reset_stats(tick)
    player.print("[FO-BENCH] compteurs remis a zero.")
  elseif sub == "report" then
    emit_report(player, tick)
  else
    player.print(USAGE)
  end
end

commands.add_command("fo-bench", USAGE, run)

return Bench
