--[[
  Sprint s40, axe 3 (logistique des ouvriers), points 21 à 25. Hors jeu, Lua pur.
  p21 : l'état « idle » ne dépense pas de jeton de prise quand le tableau n'a aucune tâche libre (Board.any_free).
  Usage : lua5.2 tests/s40_ouvriers_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local ok_n, fail_n = 0, 0
local function check(c, msg)
  if c then ok_n = ok_n + 1 print("OK     " .. msg) else fail_n = fail_n + 1 print("ECHEC : " .. msg) end
end

local function read(p) local h = io.open(p, "rb"); local s = h:read("*a"); h:close(); return (s:gsub("\r\n", "\n")) end
local BOARD = read("script/team/board.lua")
local WORKER = read("script/team/worker.lua")

--- Texte d'une fonction de premier niveau (de son en-tête à son `end` en colonne 0).
local function fn_text(src, head)
  local a = src:find(head, 1, true)
  if not a then return nil end
  local b = src:find("\nend\n", a, true)
  return b and src:sub(a, b + 4) or nil
end

---------------------------------------------------------------------------------------------------
-- p21 : Board.any_free
---------------------------------------------------------------------------------------------------
do
  local txt = fn_text(BOARD, "function Board.any_free(f)")
  check(txt ~= nil, "p21 : Board.any_free existe dans board.lua")
  local Board = {}
  local board
  Board.get = function() return board end
  local chunk = txt and load(txt, "any_free", "t", { Board = Board, ipairs = ipairs })
  if chunk then chunk() end
  local any = Board.any_free or function() return nil end
  local t1, t2 = { key = "a", worker = 7 }, { key = "b" }
  board = { tasks = {}, list = {} }
  check(any({}) == false, "p21 : tableau vide : aucune tâche libre")
  board = { tasks = { a = t1 }, list = { t1 } }
  check(any({}) == false, "p21 : seule tâche déjà prise : aucune tâche libre")
  board = { tasks = { a = t1, b = t2 }, list = { t1, t2 } }
  check(any({}) == true, "p21 : une tâche sans preneur : libre")
  board = { tasks = { a = t1 }, list = { t1, t2 } }
  check(any({}) == false, "p21 : tâche libre de la liste déjà retirée du tableau : pas libre")
  board = { tasks = { a = t1, b = { key = "b" } }, list = { t1, t2 } }
  check(any({}) == false, "p21 : tâche de la liste remplacée au tableau : pas libre (comme Board.claim)")
  -- Câblage dans l'état « idle » : le jeton n'est demandé que s'il y a une tâche libre, la prise aussi.
  local idle = WORKER:match("FSM%.define%(MACHINE, {\n  idle = {(.-)\n  step = {")
  check(idle ~= nil, "p21 : état « idle » trouvé dans worker.lua")
  idle = idle or ""
  local i_any = idle:find("local any_free = Board.any_free(f)", 1, true)
  local i_tok = idle:find("if any_free and not Tokens.take(f, tick, Tokens.COST_CLAIM) then return end", 1, true)
  local i_claim = idle:find("local task = any_free and Board.claim(f, agent, tick) or nil", 1, true)
  check(i_any and i_tok and i_claim and i_any < i_tok and i_tok < i_claim, "p21 : idle : any_free, puis jeton, puis prise")
  local _, n_take = idle:gsub("Tokens%.take%(", "")
  check(n_take == 1, "p21 : idle : un seul appel de Tokens.take (gardé par any_free)")
  check(idle:find('agent.task, agent.steps, agent.pc = nil, { { "home" } }, 1', 1, true) ~= nil, "p21 : idle : le retour au QG sans tâche reste")
end

---------------------------------------------------------------------------------------------------
-- p22 : abort rend la réservation tout de suite
---------------------------------------------------------------------------------------------------
do
  local txt = fn_text(WORKER, "local function abort(agent, f, tick, reason)")
  check(txt ~= nil, "p22 : abort trouvé dans worker.lua")
  local released, state = 0, nil
  local env = {
    Board = { release = function(_, ag) released = released + 1; ag.resa_id = nil end },
    Build = { restore_reserved = function() end },
    main_inv = function() return {} end,
    set = function(_, st) state = st end,
  }
  local chunk = txt and load(txt .. "\nreturn abort", "abort", "t", env)
  local abort = chunk and chunk() or function() end
  local ag = { task = { key = "t" }, resa_id = 3, steps = { { "home" }, { "take", {} } }, pc = 1 }
  abort(ag, {}, 10, "danger")
  check(released == 1 and ag.resa_id == nil, "p22 : abort rend la réservation (Board.release) avant le retour")
  check(ag.steps[1][1] == "home" and #ag.steps == 1 and ag.pc == 1 and ag.failed == true and state == "step" and ag.task.fail == "danger",
    "p22 : abort : programme « rentrer », raison écrite, état « step » (inchangé)")
  local ok2 = pcall(abort, { task = nil, steps = {} }, nil, 10, "x")
  check(ok2 and released == 1, "p22 : abort sans équipe : aucun appel, aucune erreur")
end

---------------------------------------------------------------------------------------------------
-- p24 : la tuile de minage réservée par Worker.program est rendue au refus de la porte
---------------------------------------------------------------------------------------------------
do
  local idle = WORKER:match("FSM%.define%(MACHINE, {\n  idle = {(.-)\n  step = {") or ""
  local refus = idle:match("if not gate_ok then(.-)Profiler%.fcredit%(\"idle\", \"idle:refus\"%)") or ""
  check(refus:find("release_tile(f, task.target)", 1, true) ~= nil, "p24 : refus de la porte : release_tile(f, task.target)")
  local i_rel, i_fin = refus:find("release_tile(f, task.target)", 1, true), refus:find("Board.finish(f, task, false, tick)", 1, true)
  check(i_rel and i_fin and i_rel < i_fin, "p24 : la tuile est rendue avant la fin de la tâche")
  -- release_tile accepte une tâche sans tuile (task.target nil) : texte de la fonction exécuté
  local txt = fn_text(WORKER, "local function release_tile(f, p)")
  local cl = { by_tile = { ["3,4"] = 100 } }
  local env = { Harvest = { applies = function() return true end }, claims_of = function() return cl end,
    tile_key = function(p) return math.floor(p.x) .. "," .. math.floor(p.y) end }
  local chunk = txt and load(txt .. "\nreturn release_tile", "release_tile", "t", env)
  local rel = chunk and chunk() or function() end
  check(pcall(rel, {}, nil) and cl.by_tile["3,4"] == 100, "p24 : release_tile sans tuile : rien")
  rel({}, { x = 3.5, y = 4.5 })
  check(cl.by_tile["3,4"] == nil, "p24 : release_tile rend la tuile réservée")
end

---------------------------------------------------------------------------------------------------
-- p25 : la tâche d'un PNJ disparu finit comme les autres (Poles.task_done)
---------------------------------------------------------------------------------------------------
do
  local rem = WORKER:match("Registry%.on_removed%(function%(agent%)(.-)\nend%)") or ""
  local i_fin = rem:find("Board.finish(f, agent.task, false, game.tick)", 1, true)
  local i_pol = rem:find("Poles.task_done(f, agent.task, false, game.tick)", 1, true)
  check(i_fin and i_pol and i_fin < i_pol, "p25 : PNJ disparu : Board.finish puis Poles.task_done")
  -- chaque Board.finish(f, task...) de worker.lua est suivi de Poles.task_done dans les 2 lignes
  local n_fin, n_ok = 0, 0
  for pos in WORKER:gmatch("()Board%.finish%(f, [%w%.]+, [%w]+, [%w%.]+%)\n") do
    n_fin = n_fin + 1
    if WORKER:sub(pos, pos + 600):find("Poles.task_done(", 1, true) then n_ok = n_ok + 1 end
  end
  check(n_fin >= 4 and n_ok == n_fin, string.format("p25 : %d Board.finish sur %d suivis de Poles.task_done", n_ok, n_fin))
end

print(string.format("\n[S40-OUVRIERS] BILAN : %d OK, %d ECHEC(S)", ok_n, fail_n))
os.exit(fail_n == 0 and 0 or 1)
