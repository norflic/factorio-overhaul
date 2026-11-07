-- Banc hors jeu de scenarios/x10-rendu.lua (moteur simulé minimal) : vitesse remise à 10, 3 phases chronométrées au
-- format que lit vram.py, zoom posé par phase, BILAN, une capture à la position du joueur ; sans joueur, phase sautée.
-- usage (depuis la racine du mod) : lua5.2 tools/autotest/tests/x10_rendu_test.lua   (attendu : [X10-RENDU] BILAN : 11 OK, 0 ECHEC(S))
package.path = "./tools/autotest/fo-autotest/?.lua;./?.lua;" .. package.path
local OK, KO = 0, 0
local function check(c, msg) if c then OK = OK + 1 else KO = KO + 1; print("ECHEC " .. msg) end end

local function setup(with_player)
  _G.LOGS = {}
  _G.log = function(s)
    if type(s) == "table" then
      local parts = {}
      for i = 2, #s do parts[#parts + 1] = type(s[i]) == "table" and ("Duration: " .. s[i].ms .. "ms") or tostring(s[i]) end
      s = table.concat(parts)
    end
    LOGS[#LOGS + 1] = s
  end
  local zooms = {}
  local player = setmetatable({ name = "DC", position = { x = 12, y = -7 }, display_resolution = { width = 1920, height = 1080 },
    surface = { daytime = 0.25 } }, { __newindex = function(t, k, v) if k == "zoom" then zooms[#zooms + 1] = v else rawset(t, k, v) end end })
  _G.game = { tick = 919256, speed = 8, connected_players = with_player and { player } or {},
    create_profiler = function() local p = { ms = 0 } function p.stop() p.ms = 1234.5 end return p end }
  _G.script = { active_mods = { base = "1.1.91" } }
  package.loaded["scenarios/x10-rendu"] = nil
  local S = require("scenarios/x10-rendu")
  local res = { ok = 0, fail = 0 }
  local ctx = { tag = "[FO-X10-RENDU]" }
  local st = {}
  function ctx.log(m) log("[FO-X10-RENDU] " .. m) end
  function ctx.call() end
  function ctx.state() return st end
  function ctx.check(c) if c then res.ok = res.ok + 1 else res.fail = res.fail + 1 end end
  return S, ctx, res, zooms
end

local S, ctx, res, zooms = setup(true)
S.init(ctx)
check(game.speed == 10, "vitesse remise a 10")
check(LOGS[1]:find("^%[FO%-PERF4%] debut tick 919256") ~= nil, "ligne d'alignement perf3 en tete")
for t = game.tick + 1, S.check_tick do S.tick(ctx, { tick = t }) end
S.finish(ctx)
local starts, ends = 0, 0
for _, l in ipairs(LOGS) do
  if l:match("^%[FO%-X10%-RENDU%] PHASE debut (%S+) tick (%d+) zoom ([0-9.]+) daytime ([0-9.]+)") then starts = starts + 1 end
  if l:match("^%[FO%-X10%-RENDU%] PHASE fin (%S+) tick (%d+) ticks (%d+) .-Duration: ([0-9.]+)ms") then ends = ends + 1 end
end
check(starts == 3 and ends == 3, "3 phases : debut et fin au format de vram.py (" .. starts .. ", " .. ends .. ")")
check(table.concat(LOGS, "|"):find("ticks 2400 Duration", 1, true) ~= nil, "phase de 2 400 ticks")
check(#zooms == 3 and zooms[1] == 1.0 and zooms[2] == 0.5 and zooms[3] == 0.3, "zoom pose par phase : 1, 0,5, 0,3")
check(res.ok == 3 and res.fail == 0, "BILAN : 3 OK (partie chargee, phases, joueur)")
check(S.check_tick == 919256 + 8200 and S.shots_delay == 8400, "BILAN avant les captures")
local shots = {}
S.shots(ctx, function(name, x, y, z) shots[#shots + 1] = { name, x, y, z } end)
check(#shots == 1 and shots[1][2] == 12 and shots[1][3] == -7, "une capture a la position du joueur")

-- sans joueur connecté : phases sautées, BILAN en échec (la mesure ne vaut rien sans la vue du DC)
S, ctx, res, zooms = setup(false)
S.init(ctx)
for t = game.tick + 1, S.check_tick do S.tick(ctx, { tick = t }) end
S.finish(ctx)
check(#zooms == 0, "sans joueur : aucun zoom")
check(res.fail == 2, "sans joueur : 2 ECHEC (phases, joueur)")
check(table.concat(LOGS, "|"):find("aucun joueur connecte, phase sautee", 1, true) ~= nil, "sans joueur : dit dans le journal")

print(string.format("[X10-RENDU] BILAN : %d OK, %d ECHEC(S)", OK, KO))
os.exit(KO == 0 and 0 or 1)
