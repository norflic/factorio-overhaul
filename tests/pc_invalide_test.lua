--[[
  Correction PC-INVALIDE (plantage réel, azure, 87,8 min, partie 271828182 du 9/11, code 12 : « attempt to index field '?' (a nil value) »
  à script/team/bail.lua, B.pre_act : steps[0]).
  Cause mesurée par lecture du code (déduite, reproduite ci-dessous) : l'état « ia1d » (script/team/worker.lua) appelait `defend` SANS lire son
  résultat. Une réaction (demi-tour ou fuite : comportement -> Worker.abort) remet le programme à `{ home }` avec pc = 1 ; le travail sur place
  (Build.work) continuait dans la même pensée et son retour « again » retirait 1 à pc, d'où pc = 0 (aucune étape). Le bail lisait steps[0].
  Corrections testées ici : (1) ia1d rend la main après une réaction ; (2) « again » ne recule que si le programme est le même, que
  l'étape courante est ia1d et que pc > 1 ; sinon abandon ; (3) B.pre_act ne lit plus steps[0] et écrit [FO-PC-INVALIDE] une fois par PNJ
  quand la garde sert.
  Moteur simulé (tests/mock_engine.lua) ; mutants de worker.lua et de bail.lua refusés. Usage : lua5.2 tests/pc_invalide_test.lua
]]
package.path = "./?.lua;" .. package.path

local ok_n, bad = 0, 0
local function check(name, cond)
  if cond then ok_n = ok_n + 1 else bad = bad + 1 print("[PC-INVALIDE] ECHEC : " .. name) end
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

--- Une partie neuve, un PNJ de votre équipe ; `setup(agent, f)` pose le scénario, puis la pensée de l'état ia1d est jouée.
--- `worker_src` / `bail_src` : sources mutées (facultatif). Rend la liste { nom, vrai/faux } et les journaux [FO-PC-INVALIDE].
local function scenario(opts)
  opts = opts or {}
  local res, logs = {}, {}
  local function c(name, cond) res[#res + 1] = { name, cond and true or false } end
  if opts.worker_src then
    package.preload["script.team.worker"] = function() return assert(load(opts.worker_src, "=worker", "t"))() end
  end
  if opts.bail_src then
    package.preload["script.team.bail"] = function() return assert(load(opts.bail_src, "=bail", "t"))() end
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
  package.preload["script.team.bail"] = nil
  if not okg then c("partie au moteur simulé : " .. tostring(err), false) return res, logs end
  local Registry = require("script.companion.registry")
  local State = require("script.faction.state")
  local Worker = require("script.team.worker")
  local Build = require("script.team.build")
  local FSM = require("script.core.fsm")
  local f = global.fo.pteam.team
  local ids = State.sorted_keys(f.engineers or {})
  local agent = ids[1] and Registry.get(ids[1])
  if not (agent and agent.entity and agent.entity.valid) then c("un PNJ de votre equipe", false) return res, logs end
  local tick = game.tick

  -- Capture des journaux (log global) pendant tout le scénario.
  local real_log = log
  log = function(text) logs[#logs + 1] = tostring(text) end

  -- Le demi-tour : le regard (H.sense) rend « pris » et passe par Worker.abort, comme comportement.lua le fait en réaction.
  local sense_on, halt_on = false, false
  Worker.hook = { sense = function(a, t)
    if halt_on then halt_on = false; return true end -- halte : rend vrai, programme inchangé (M.sense, arrêt sur place)
    if sense_on then sense_on = false; Worker.abort(a, f, t, "danger"); return true end
    return false
  end }
  local work_calls, work_fn = 0, opts.work
  local real_work = Build.work
  Build.work = function(a, ff, t)
    work_calls = work_calls + 1
    if work_fn then return work_fn(a, ff, t) end
    return "again"
  end

  --- Pose le programme `steps` au PNJ, pc `pc`, dans l'état ia1d.
  local function pose(steps, pc)
    local task = { key = "ia1d:47", kind = "service", outpost = 99, prio = 70, worker = agent.id, claimed = tick }
    f.build = f.build or {}
    agent.task, agent.steps, agent.pc, agent.failed = task, steps, pc, nil
    agent.ia1d = { pid = 47, mode = "x" }
    agent.state = "ia1d"
    work_calls = 0
  end
  local steps_ia1d = function()
    return { { "goto", { x = 200, y = 200 }, 1 }, { "ia1d" }, { "home" } }
  end

  -- 1. Réaction pendant la pensée ia1d : pas de travail après le demi-tour, pc valide (sans cela : pc = 0).
  pose(steps_ia1d(), 2)
  sense_on = true
  local okt, errt = pcall(FSM.think, "worker", agent, tick)
  c("1 : la pensée ia1d ne plante pas après une réaction", okt)
  if not okt then c("1 : détail : " .. tostring(errt), false) end
  c("1 : pas de travail sur place après le demi-tour (Build.work non appelé)", work_calls == 0)
  c("1 : pc valide après le demi-tour (pc = 1, programme « home »)", agent.pc == 1 and agent.steps[1][1] == "home")
  c("1 : la réaction marque la tâche en échec (abandon)", agent.failed == true)

  -- 1 bis. Halte pendant ia1d (M.sense rend vrai sans changer le programme) : le job reste, aucun travail pendant la halte,
  -- la pensée suivante reprend le travail avec le même job.
  pose(steps_ia1d(), 2)
  local job0 = agent.ia1d
  halt_on = true
  local okh = pcall(FSM.think, "worker", agent, tick)
  c("1 bis : halte : pensee sans erreur", okh)
  c("1 bis : halte : job conserve", agent.ia1d == job0 and job0 ~= nil)
  c("1 bis : halte : pas de travail pendant la halte", work_calls == 0)
  c("1 bis : halte : programme inchange (pc = 2)", agent.pc == 2 and agent.steps[2][1] == "ia1d")
  local seen_job = nil
  work_fn = function(a) seen_job = a.ia1d return "more" end
  local okh2 = pcall(FSM.think, "worker", agent, tick)
  work_fn = nil
  c("1 bis : pensee suivante : pas d'erreur", okh2)
  c("1 bis : pensee suivante reprend le travail avec le job conserve", work_calls == 1 and seen_job == job0 and seen_job ~= nil)

  -- 2. « again » sans réaction : recul d'une étape, comme avant (pc > 1, programme inchangé, étape ia1d).
  pose(steps_ia1d(), 2)
  local okt2 = pcall(FSM.think, "worker", agent, tick)
  c("2 : again normal : pas d'erreur", okt2)
  c("2 : again normal : recul d'une étape (pc = 1, la marche d'avant)", agent.pc == 1 and agent.steps[1][1] == "goto")

  -- 3. « again » quand l'étape ia1d est en PREMIÈRE position (pc = 1) : rien à reculer, abandon (sans cela : pc = 0).
  pose(steps_ia1d(), 2)
  pose({ { "ia1d" }, { "home" } }, 1)
  local okt3 = pcall(FSM.think, "worker", agent, tick)
  c("3 : again sans étape avant : pas d'erreur", okt3)
  c("3 : again sans étape avant : jamais pc = 0", agent.pc ~= 0 and agent.pc == 1 and agent.steps[1][1] == "home")

  -- 3 bis. « again » avec pc > 1 mais l'étape courante qui n'est PAS ia1d : pas de recul, abandon.
  pose({ { "goto", { x = 1, y = 1 }, 1 }, { "home" }, { "ia1d" } }, 2)
  local okt3b = pcall(FSM.think, "worker", agent, tick)
  c("3 bis : again sur une étape qui n'est pas ia1d : pas d'erreur", okt3b)
  c("3 bis : again sur une étape qui n'est pas ia1d : abandon (failed), pas de recul", agent.failed == true and agent.pc == 1)

  -- 4. Le programme a changé pendant le travail : pas de recul sur un programme qui n'est plus celui-là.
  pose(steps_ia1d(), 2)
  work_fn = function(a) a.steps, a.pc = { { "home" } }, 1 return "again" end
  local okt4 = pcall(FSM.think, "worker", agent, tick)
  work_fn = nil
  c("4 : programme remplacé pendant le travail : pas d'erreur", okt4)
  c("4 : programme remplacé : abandon (failed), pc valide", agent.failed == true and agent.pc == 1 and agent.steps[1][1] == "home")

  -- 5. pre_act (script/team/bail.lua) : pc = 0 ne plante pas, rend faux sans acte, et journalise [FO-PC-INVALIDE] une fois.
  local Bail = require("script.team.bail")
  local n0 = #logs
  agent.steps, agent.pc, agent.pc_inv_logged = { { "goto", { x = 1, y = 1 } }, { "act", "service" }, { "home" } }, 0, nil
  local okp, rp = pcall(Bail.pre_act, agent)
  c("5 : pre_act avec pc = 0 ne plante pas", okp)
  c("5 : pre_act avec pc = 0 voit l'acte qui vient (vrai)", okp and rp == true)
  local okp2, rp2 = pcall(Bail.pre_act, agent)
  c("5 : pre_act avec pc = 0 : une seule ligne [FO-PC-INVALIDE]", #logs - n0 == 1 and logs[#logs]:find("FO%-PC%-INVALIDE") ~= nil)
  agent.steps, agent.pc, agent.pc_inv_logged = { { "home" } }, 0, nil
  local okp3, rp3 = pcall(Bail.pre_act, agent)
  c("5 : pre_act sans acte, pc = 0 : ne plante pas et rend faux", okp3 and rp3 == false)
  agent.steps, agent.pc, agent.pc_inv_logged = { { "goto", { x = 1, y = 1 } }, { "act", "service" }, { "home" } }, 1, nil
  local n1 = #logs
  local okp4, rp4 = pcall(Bail.pre_act, agent)
  c("5 : pc valide : pas de ligne [FO-PC-INVALIDE]", okp4 and rp4 == true and #logs == n1)

  Build.work = real_work
  Worker.hook = nil
  log = real_log
  return res, logs
end

local res = scenario()
for _, r in ipairs(res) do check(r[1], r[2]) end

-- Mutants (refusés si UN contrôle au moins échoue). Chacun remplace un extrait exact de la source corrigée.
local W = read("script/team/worker.lua")
local BS = read("script/team/bail.lua")
local MUT_W = {
  { "ia1d continue après une réaction (sans lire defend)", "      if defend(agent, tick) then\n        if agent.steps ~= steps0 or agent.pc ~= pc0 then agent.ia1d = nil end\n        return\n      end",
    "      defend(agent, tick)" },
  { "halte : job effacé à chaque retour de defend (ancienne version du lead)", "if agent.steps ~= steps0 or agent.pc ~= pc0 then agent.ia1d = nil end",
    "agent.ia1d = nil" },
  { "again sans garde de programme (pc - 1 aveugle)", "if agent.steps == steps0 and agent.pc == pc0 and pc0 > 1 and cur and cur[1] == \"ia1d\" then",
    "if pc0 > 1 then" },
  { "again sans garde pc > 1 (pc = 0 possible)", "if agent.steps == steps0 and agent.pc == pc0 and pc0 > 1 and cur and cur[1] == \"ia1d\" then",
    "if agent.steps == steps0 and agent.pc == pc0 and cur and cur[1] == \"ia1d\" then" },
  { "again sans garde d'étape ia1d", "if agent.steps == steps0 and agent.pc == pc0 and pc0 > 1 and cur and cur[1] == \"ia1d\" then",
    "if agent.steps == steps0 and agent.pc == pc0 and pc0 > 1 then" },
}
local MUT_B = {
  { "pre_act lit steps[0] (défaut d'origine : boucle depuis pc, sans garde)",
    "  for i = math.max(agent.pc, 1), #steps do\n    local s = steps[i]\n    if s and s[1] == \"act\" then return true end\n  end",
    "  for i = agent.pc, #steps do\n    if steps[i][1] == \"act\" then return true end\n  end" },
  { "pre_act sans journal [FO-PC-INVALIDE]", "    if not agent.pc_inv_logged then", "    if false then" },
}

local function refused_by(src_kind, src, a, b, replacement)
  local mutated = src:sub(1, a - 1) .. replacement .. src:sub(b + 1)
  local okm, res_m, logs_m
  if src_kind == "w" then
    okm, res_m, logs_m = pcall(scenario, { worker_src = mutated })
  else
    okm, res_m, logs_m = pcall(scenario, { bail_src = mutated })
  end
  if not okm then return true end
  for _, r in ipairs(res_m) do if not r[2] then return true end end
  return false
end

local refused, kept = 0, {}
local total = 0
for _, list in ipairs({ { "w", W, MUT_W }, { "b", BS, MUT_B } }) do
  for _, m in ipairs(list[3]) do
    total = total + 1
    local a, b = list[2]:find(m[2], 1, true)
    if not a then
      kept[#kept + 1] = m[1] .. " (motif introuvable)"
    elseif refused_by(list[1], list[2], a, b, m[3]) then
      refused = refused + 1
    else
      kept[#kept + 1] = m[1]
    end
  end
end
check(string.format("mutants refuses %d/%d%s", refused, total, #kept > 0 and (" ; survivants : " .. table.concat(kept, ", ")) or ""),
  refused == total)

print(string.format("[PC-INVALIDE] BILAN : %d OK, %d ECHEC(S)", ok_n, bad))
os.exit(bad == 0 and 0 or 1)
