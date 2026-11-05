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

--- Une partie neuve ; une tâche tenue par un PNJ figé par le banc ; rend le délai (ticks) avant que le bail la lâche, ou nil.
--- kind « service » : tournée, le PNJ tourne en rond à l'étape `pc`. kind « ghost » (bâtisseur, accord du lead du 5/11) : mode « boucle » =
--- marche (étape 3) / chantier sans rien poser (étape 4) / « refaire la marche », sur place ; mode « travail » = sur place à l'étape 4, une
--- reconstruction de plus à chaque pensée (ne doit PAS être lâché).
local function run(pc, kind, mode)
  kind = kind or "service"
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
  local key = kind == "ghost" and "ia1d:9:b:1" or "service:99"
  local t = { key = key, kind = kind, outpost = kind == "service" and 99 or nil, prio = 70, worker = agent.id, claimed = game.tick }
  b.tasks[key] = t
  if agent.nav then require("script.agents.nav").stop(agent, game.tick) end
  agent.task, agent.pc = t, pc
  agent.steps = kind == "ghost" and { { "home" }, { "take_res", 9, {} }, { "goto", { x = 50.5, y = -20.5 }, 1 }, { "ia1d" }, { "home" } }
    or { { "home" }, { "goto", { x = 70.5, y = -20.5 }, 3 }, { "act", "service" }, { "home" } }
  local t0 = game.tick
  for k = 1, 80 do
    local tick = t0 + k * 300
    if agent.task ~= t then break end
    agent.state = k % 2 == 0 and "walk" or "step"
    agent.goal = { x = P.x + k % 7, y = P.y - k % 5 }
    if kind == "ghost" and mode == "boucle" then
      agent.pc, agent.ia1d = (k % 2 == 0) and 3 or 4, nil
      if agent.pc == 4 then agent.state = "ia1d" end
    elseif kind == "ghost" then
      agent.pc, agent.state, agent.ia1d = 4, "ia1d", { pid = 9, mode = "build", done = k }
    end
    if mode == "tir" then agent.state, agent.shooting = "walk", true end
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
    d and string.format("lache apres %d s", d / 60) or "jamais lache en 6,7 min")
end
local dt = run(2, "service", "tir")
check("revue R1 : autodefense qui « tire » sans portee (ennemi fixe a 15-18 tuiles) : lache apres la borne du combat", dt ~= nil and dt <= 4 * 3600 + 600,
  dt and string.format("lache apres %d s", dt / 60) or "jamais lache en 6,7 min")
local dg = run(3, "ghost", "boucle")
check("batisseur en boucle marche / chantier vide / marche : lache au bail", dg ~= nil and dg <= LEASE + 600,
  dg and string.format("lache apres %d s", dg / 60) or "jamais lache en 6,7 min")
local dw = run(4, "ghost", "travail")
check("batisseur qui reconstruit sur place : PAS lache", dw == nil, dw and string.format("lache apres %d s", dw / 60) or "jamais lache en 6,7 min")
-- Mutants de la règle (code du dépôt seulement) : chacun doit faire échouer un cas du bâtisseur au moteur simulé.
if not OLD then
  local f = assert(io.open("shared/team/bail.lua", "rb"))
  local SRC = f:read("*a")
  f:close()
  local MUT = {
    { "travail ignore", "if cur.work ~= nil and num(cur.work) > num(prev.work) then return fresh(cur, tick, top) end", "", "travail" },
    { "retour en arriere = progres", "cur.busy == true or num(cur.pc) > num(top) then", "cur.busy == true or cur.pc ~= prev.pc then", "boucle" },
    { "batisseur hors bail", "Bl.KINDS = { service = true, ghost = true }", "Bl.KINDS = { service = true }", "boucle" },
  }
  for _, m in ipairs(MUT) do
    local a, b = SRC:find(m[2], 1, true)
    local seen = false
    if a then
      local src = SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1)
      package.preload["shared.team.bail"] = function() return assert(load(src, "=bail-mutant", "t"))() end
      local d = run(m[4] == "travail" and 4 or 3, "ghost", m[4])
      package.preload["shared.team.bail"] = nil
      if m[4] == "travail" then seen = d ~= nil else seen = d == nil or d > LEASE + 600 end
    end
    check("mutant « " .. m[1] .. " » refuse", seen, a and "" or "motif introuvable")
  end
end
print(string.format("[BAIL-BOUCLE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
