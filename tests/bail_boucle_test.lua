--[[
  Lot ETAGE4 (5/11, règle de méthode du lead : le défaut reproduit au moteur simulé avant tout banc long) : un PNJ qui TOURNE EN ROND sur place
  (marche / arrêt à chaque pensée, nouveau point de passage à chaque itinéraire, comme PNJ 22 d'Azur et PNJ 3 de votre équipe dans
  lot3-croiss-123456789) avec une tournée prise doit être lâché en MOINS DE 2 MIN (bail, Bl.LEASE), avant l'acte comme au retour.
  Moteur simulé : votre équipe, un vrai PNJ, une tournée au vrai tableau ; le vrai moniteur (script/team/bail.lua) est appelé pensée par pensée
  (toutes les 300 ticks) ; la machine du PNJ est figée par le banc (état basculé, corps ramené au même point).
  Usage : lua5.2 tests/bail_boucle_test.lua [dossier]
    sans argument : le code du dépôt ; avec un dossier qui contient shared_team_bail.lua et script_team_bail.lua (par exemple ceux de
    fa246935, extraits par `git show`), ce code-là : le témoin de l'ancien code doit ÉCHOUER.
]]
package.path = "./?.lua;" .. package.path
local OLD = arg and arg[1]
if OLD then
  package.preload["shared.team.bail"] = function() return dofile(OLD .. "/shared_team_bail.lua") end
  package.preload["script.team.bail"] = function() return dofile(OLD .. "/script_team_bail.lua") end
end

local Mk = require("tests.mock_engine")
local function patches()
  local out = {}
  local names = { "coal", "iron-ore", "copper-ore", "stone" }
  for i = 0, 11 do
    local a = i * math.pi / 6
    out[#out + 1] = { x = math.cos(a) * 60, y = math.sin(a) * 60, name = names[i % 4 + 1] }
  end
  return out
end

local LEASE = 2 * 3600

--- Une partie neuve ; la tournée tenue par un PNJ qui tourne en rond à l'étape `pc` ; rend le délai (ticks) avant que le bail la lâche, ou nil.
local function run(pc)
  Mk.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, seed = 11 })
  local s = game.surfaces[1]
  local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
  Mk.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
  Mk.run_ticks(300)
  local Registry = require("script.companion.registry")
  local State = require("script.faction.state")
  local Board = require("script.team.board")
  local Bail = require("script.team.bail")
  local f = global.fo.pteam.team
  local agent = Registry.get(State.sorted_keys(f.engineers)[1])
  local e = agent.entity
  local b = Board.get(f)
  local P = { x = 30.5, y = -20.5 }
  local key = "service:99"
  local t = { key = key, kind = "service", outpost = 99, prio = 70, worker = agent.id, claimed = game.tick }
  b.tasks[key] = t
  if agent.nav then require("script.agents.nav").stop(agent, game.tick) end
  agent.task, agent.pc = t, pc
  agent.steps = { { "home" }, { "goto", { x = 70.5, y = -20.5 }, 3 }, { "act", "service" }, { "home" } }
  local t0 = game.tick
  for k = 1, 40 do
    local tick = t0 + k * 300
    if agent.task ~= t then break end
    agent.state = k % 2 == 0 and "walk" or "step"
    agent.goal = { x = P.x + k % 7, y = P.y - k % 5 }
    e.teleport(P)
    Bail.think(f, tick)
    if t.bailed or b.tasks[key] ~= t then return tick - t0 end
  end
  return nil
end

local ok_n, bad = 0, 0
local function check(name, cond, detail)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 end
  print(string.format("[BAIL-BOUCLE] %s %s : %s", cond and "OK" or "ECHEC", name, detail))
end
local code = OLD and ("ancien code (" .. OLD .. ")") or "code du depot"
print("[BAIL-BOUCLE] " .. code)
for _, case in ipairs({ { 2, "avant l'acte (aller)" }, { 4, "au retour (apres l'acte)" } }) do
  local d = run(case[1])
  check(case[2] .. " : lache en moins de 2 min", d ~= nil and d <= LEASE + 300,
    d and string.format("lache apres %d s", d / 60) or "jamais lache en 10 min")
end
print(string.format("[BAIL-BOUCLE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
