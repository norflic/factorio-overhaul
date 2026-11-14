-- s46 profileur : la sonde [FO-PERF-PIC] ne change rien à la portée (arguments, valeurs rendues, nil compris), écrit une ligne
-- par appel avec le profileur arrêté, et se tait sans game.create_profiler. Faux `game`, hors jeu.
package.path = "./?.lua;" .. package.path
local ok, n = 0, 0
local function check(c, msg) n = n + 1; if c then ok = ok + 1 else print("ECHEC : " .. msg) end end

local lines, stopped = {}, 0
_G.log = function(x) lines[#lines + 1] = x end
_G.game = { tick = 0, create_profiler = function()
  local p = { stopped = false }
  p.stop = function() p.stopped = true; stopped = stopped + 1 end
  return p
end }

local Sonde = require("script.core.sonde_pic")
local seen
local fn = function(f, a, b) seen = { f, a, b }; return nil, "pourquoi", nil end
local w = Sonde.wrap("champ:frame", fn)
local r1, r2, r3 = w({ key = "nord" }, 1, 2)
local nret = select("#", w({ key = "nord" }, 1, 2))
check(r1 == nil and r2 == "pourquoi" and r3 == nil, "valeurs rendues")
check(nret == 3, "nombre de valeurs rendues " .. nret)
check(seen[1].key == "nord" and seen[2] == 1 and seen[3] == 2, "arguments")
check(#lines == 2 and stopped == 2, "une ligne et un arret par appel")
check(type(lines[1]) == "table" and lines[1][1] == "" and lines[1][2] == "[FO-PERF-PIC] champ:frame nord " and lines[1][3].stopped,
  "ligne localisee avec le profileur arrete")
w(nil); check(lines[3][2] == "[FO-PERF-PIC] champ:frame player ", "equipe par defaut")
_G.game = nil
lines = {}
local a = Sonde.wrap("x", function(f) return f + 1 end)(41)
check(a == 42 and #lines == 0, "sans game : appel direct, rien au journal")

-- câblage : champ.lua emballe Champ.frame (le module se charge avec le faux game)
local src = io.open("script/team/champ.lua"):read("*a")
check(src:find('Champ.frame = require("script.core.sonde_pic").wrap("champ:frame", Champ.frame)', 1, true) ~= nil, "cablage champ.lua")

print(string.format("s46_profileur_test : %d/%d OK", ok, n))
if ok ~= n then os.exit(1) end
