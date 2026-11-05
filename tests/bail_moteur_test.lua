--[[
  Lot ETAGE4 (revue du lead, 5/11) : Worker.release_stuck (script/team/worker.lua) au moteur simulé : votre équipe, un PNJ réel, une tournée
  posée au tableau.
    1re fois : abandon (programme « rentrer », tâche encore tenue, motif « bail ») ; 2e fois : DÉGAGÉ près du QG, tâche finie et retirée du
    tableau, PNJ sans tâche (le mutant `if task then` du lead, m6, le laisse tenir la tournée sans fin) ;
    motif d'un abandon antérieur (fuite) gardé (m5) ;
    place du dégagement : jamais sur un fantôme (F293), jamais là où find_non_colliding_position n'a rien rendu.
  Mutants de worker.lua chargés par package.preload (le moteur simulé recharge le mod à chaque partie).
  Usage : lua5.2 tests/bail_moteur_test.lua   (depuis la racine du mod ; quelques secondes)
]]
package.path = "./?.lua;" .. package.path

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[BAIL-MOTEUR] ECHEC : " .. name) end
end

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
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

--- Une partie neuve (worker.lua éventuellement muté), puis le scénario. Rend la liste { nom, vrai/faux }.
local function scenario(worker_src)
  local res = {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  if worker_src then
    package.preload["script.team.worker"] = function() return assert(load(worker_src, "=worker", "t"))() end
  end
  local okg, err = pcall(function()
    Mk.new_game({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, seed = 7 })
    local s = game.surfaces[1]
    local chest = s.create_entity({ name = "fo-team-chest", position = { x = 5, y = 5 }, force = "player" })
    chest.insert({ name = "iron-plate", count = 100 })
    Mk.world().events[defines.events.on_built_entity]({ created_entity = chest, player_index = 1, tick = game.tick })
    Mk.run_ticks(600)
  end)
  package.preload["script.team.worker"] = nil
  if not okg then c("partie au moteur simulé : " .. tostring(err), false) return res end
  local Registry = require("script.companion.registry")
  local State = require("script.faction.state")
  local Board = require("script.team.board")
  local Worker = require("script.team.worker")
  local f = global.fo.pteam.team
  local ids = State.sorted_keys(f.engineers or {})
  local agent = ids[1] and Registry.get(ids[1])
  if not (agent and agent.entity and agent.entity.valid) then c("un PNJ de votre equipe", false) return res end
  local e = agent.entity
  local b = Board.get(f)
  local function give(key, fail)
    local t = { key = key, kind = "service", outpost = 99, prio = 70, worker = agent.id, claimed = game.tick, fail = fail }
    b.tasks[key] = t
    agent.task, agent.steps, agent.pc, agent.state = t, { { "goto", { x = 200, y = 200 } }, { "act", "service" }, { "home" } }, 1, "step"
    return t
  end
  local function d2(p, q) return (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 end
  local tick = game.tick
  -- 1. Abandon puis dégagement.
  local t = give("service:99")
  e.teleport({ x = 200, y = 200 })
  local h1 = Worker.release_stuck(agent, f, tick)
  c("1re fois : abandon", h1 == "abandon")
  c("abandon : programme rentrer, tache encore tenue, motif bail", agent.task == t and agent.steps and agent.steps[1][1] == "home"
    and t.bailed == true and t.fail == "bail" and b.tasks["service:99"] == t)
  local rescued = f.stats.rescued or 0
  local h2 = Worker.release_stuck(agent, f, tick + 7200)
  local p1 = { x = e.position.x, y = e.position.y }
  c("2e fois : degage (m6 : jamais un abandon sans fin)", h2 == "degage")
  c("degage : PNJ sans tache, tournee retiree du tableau", agent.task == nil and b.tasks["service:99"] == nil)
  c("degage : teleporte pres du QG", f.home_spot and d2(p1, f.home_spot) < 15 * 15 and (f.stats.rescued or 0) == rescued + 1)
  -- 2. Motif d'un abandon antérieur gardé (m5).
  local t2 = give("service:98", "fuite")
  local h3 = Worker.release_stuck(agent, f, tick + 7500)
  c("abandon d'une tournee deja abandonnee en fuite : motif garde", h3 == "abandon" and t2.fail == "fuite")
  Worker.release_stuck(agent, f, tick + 7800)
  -- 3. F293 : un fantôme sur la place du PNJ au QG ; le dégagement suivant ne le pose pas dessus.
  game.surfaces[1].create_entity({ name = "entity-ghost", inner_name = "stone-furnace", position = { x = p1.x, y = p1.y }, force = "player" })
  give("service:97")
  e.teleport({ x = 200, y = 200 })
  Worker.release_stuck(agent, f, tick + 8100)
  Worker.release_stuck(agent, f, tick + 8400)
  local p2 = e.position
  local ghosts = game.surfaces[1].count_entities_filtered({ type = "entity-ghost", area = { { p2.x - 0.5, p2.y - 0.5 }, { p2.x + 0.5, p2.y + 0.5 } } })
  c("F293 : degage hors du fantome pose sur sa place", ghosts == 0 and d2(p2, p1) > 1 and d2(p2, f.home_spot) < 15 * 15)
  -- 4. La place sans fantôme : directement.
  local spot = Worker.ghost_free_spot(e, { x = p1.x, y = p1.y })
  c("ghost_free_spot : evite le fantome", spot ~= nil and d2(spot, p1) > 1)
  local spot2 = Worker.ghost_free_spot(e, { x = p1.x + 40, y = p1.y })
  c("ghost_free_spot : place libre rendue telle quelle", spot2 ~= nil and d2(spot2, { x = p1.x + 40, y = p1.y }) < 1e-9)
  return res
end

for _, r in ipairs(scenario(nil)) do check(r[1], r[2]) end

local W = read("script/team/worker.lua")
local MUTANTS = {
  { "release_stuck ne degage jamais (m6, `if task then`)", "if task and not task.bailed then\n    task.bailed = true", "if task then\n    task.bailed = true" },
  { "motif ecrase en bail (m5)", "if why then task.fail = why end", "" },
  { "degagement sans garde des fantomes (F293)", "Worker.ghost_free_spot(e, home_slot(agent, f))",
    "e.surface.find_non_colliding_position(e.name, home_slot(agent, f), 20, 0.5)" },
  { "garde des fantomes inerte", "area = { { spot.x - 0.5, spot.y - 0.5 }, { spot.x + 0.5, spot.y + 0.5 } } }) == 0 then",
    "area = { { spot.x - 0.5, spot.y - 0.5 }, { spot.x + 0.5, spot.y + 0.5 } } }) >= 0 then" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = W:find(m[2], 1, true)
  if not a then
    kept[#kept + 1] = m[1] .. " (motif introuvable)"
  else
    local seen = false
    local okm, res = pcall(scenario, W:sub(1, a - 1) .. m[3] .. W:sub(b + 1))
    if not okm then seen = true else for _, r in ipairs(res) do if not r[2] then seen = true break end end end
    if seen then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
check(string.format("mutants de worker.lua refuses %d/%d%s", refused, #MUTANTS, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""),
  refused == #MUTANTS)

print(string.format("[BAIL-MOTEUR] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
