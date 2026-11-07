--[[
  Lot CORR-PROFIL-ETAPE (7/11) : chaque portée « team:etapeN » du profileur ouverte par une étape de la pensée en étapes
  (script/team/team.lua, TT.step) est fermée SOUS LE MÊME NOM, dans le même tick. Défaut de 6fcfe757 (0.6.58) : l'étape avance
  et.n, la portée était fermée sous le nom de l'étape suivante (chronomètres team:etapeN faux, pile du détail laissée ouverte).
  Moteur simulé, 2 factions, pensée en étapes, 30 s de jeu ; Profiler.start et Profiler.stop enveloppés.
  Usage : lua5.2 tests/profil_etape_test.lua   (depuis la racine du mod ; quelques secondes)
]]
package.path = "./?.lua;" .. package.path
local M = require("tests.mock_engine")

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
end

local function patches()
  local o = {}
  local d = 0.7071
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for _, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do
    local hx, hy = c[1] * 320, c[2] * 320
    for i = 0, 11 do
      local a = i * math.pi / 6
      o[#o + 1] = { x = hx + math.cos(a) * 50, y = hy + math.sin(a) * 50, name = names[i % 4 + 1] }
    end
  end
  return o
end
M.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, ia3e = true })
local W = M.world()
for _, p in pairs(W.prototypes) do if p.has_flag == nil then p.has_flag = function() return false end end end
local Team = require("script.team.team")
local Profiler = require("script.core.profiler")
Team.ETAPES = true
assert(remote.call("factorio-overhaul", "war_start", 2, 100, nil, 320) == true)

-- Portées team:etapeN ouvertes (nom -> tick d'ouverture), fermetures sous un nom non ouvert, portées encore ouvertes en fin de tick.
local open, stats = {}, { opened = 0, closed = 0, wrong = 0, left = 0 }
local o_start, o_stop = Profiler.start, Profiler.stop
Profiler.start = function(name, ...)
  if type(name) == "string" and name:match("^team:etape%d") then
    stats.opened = stats.opened + 1
    open[name] = game.tick
  end
  return o_start(name, ...)
end
Profiler.stop = function(name, ...)
  if type(name) == "string" and name:match("^team:etape%d") then
    if open[name] == game.tick then
      stats.closed = stats.closed + 1
      open[name] = nil
    else
      stats.wrong = stats.wrong + 1
    end
  end
  return o_stop(name, ...)
end
for _ = 1, 1800 do
  M.run_ticks(1)
  for name, t in pairs(open) do -- (ensemble : l'ordre ne décide de rien)
    if t <= game.tick then stats.left = stats.left + 1; open[name] = nil end
  end
end

print(string.format("== portées team:etapeN : %d ouvertes, %d fermées sous leur nom, %d fermetures sous un autre nom, %d laissées ouvertes",
  stats.opened, stats.closed, stats.wrong, stats.left))
check(stats.opened >= 10, "des étapes jouées par le minuteur (" .. stats.opened .. ")")
check(stats.wrong == 0, "aucune fermeture sous un nom non ouvert (" .. stats.wrong .. ")")
check(stats.left == 0, "aucune portée laissée ouverte à la fin du tick (" .. stats.left .. ")")
check(stats.closed == stats.opened, "chaque portée ouverte est fermée sous son nom (" .. stats.closed .. " sur " .. stats.opened .. ")")
print(string.format("[PROFIL-ETAPE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
