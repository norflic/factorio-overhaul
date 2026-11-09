--[[
  Lot MESURE-MODULE (8/11/2026) : banc HORS JEU des copies de coffres d'un projet (cause du « dort » à 4 fois le contenu).
  Lancement : lua5.2 tests/sites_dedup_test.lua (depuis la racine du mod).

  Le défaut : plan_feed (script/team/build.lua) AJOUTAIT les coffres d'entrée (p.quais) et de sortie (p.outs) à chaque plan ; un plan
  qui attend puis recommence (masques, réseau, centrale lointaine) ne remettait à zéro que p.ents et p.parts.

  Sections :
    1. règle pure (shared/team/sites_dedup.lua) : clés, copies retirées, première gardée, champ d'une copie recueilli, entrée intacte ;
    2. Col.waiting_all (script/team/collecte.lua) : un coffre lu une fois, quatre entrées de p.outs ou deux projets qui le désignent ;
       la tâche prise l'emporte ; les coffres distincts restent distincts ;
    3. Build.dedupe_sites (script/team/build.lua, fonction extraite du source) : retire les copies, attend une tâche prise,
       jette les tâches libres du projet, refait le quota, marque p.sites_v, ne fait rien sur un projet propre ;
    4. build.lua, passe « plan » : chaque branche qui rend ce qu'elle a réservé et recommence remet AUSSI p.quais et p.outs à zéro ;
       un plan réussi marque p.sites_v ; la passe des tâches appelle Build.dedupe_sites ;
    5. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Ce n'est pas une preuve en jeu.
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; print("  ECHEC : " .. msg) end
  return cond
end
local function section(name) print("== " .. name) end

local function read_file(p)
  local fh = assert(io.open(p, "rb")); local s = fh:read("*a"); fh:close(); return s
end
local function plain_replace(src, old, new)
  local i, j = src:find(old, 1, true)
  assert(i, "mutant : motif introuvable : " .. old)
  return src:sub(1, i - 1) .. new .. src:sub(j + 1)
end
local function load_chunk(src, name, env)
  local fn, err = load(src, "=" .. name, "t", env or _G)
  assert(fn, err)
  return fn()
end

local SRC_D = read_file("shared/team/sites_dedup.lua")
local function new_d(mut) return load_chunk(mut and mut(SRC_D) or SRC_D, "sites_dedup") end

---------------------------------------------------------------------------------------------------
-- 1. Règle pure
---------------------------------------------------------------------------------------------------
local function pure_cases(D)
  local r = {}
  local out = { x = 10.5, y = 3.5 }
  local list = { out, { x = 10.5, y = 3.5 }, { x = 10.5, y = 3.5, at = 40 }, { x = 12.5, y = 3.5 }, { x = 10.5, y = 3.5 } }
  r.count = D.count_dups(list, D.out_key) == 3
  local d, removed = D.dedupe(list, D.out_key)
  r.dedupe = #d == 2 and removed == 3 and d[1].x == 10.5 and d[2].x == 12.5
  r.order_first = d[1] ~= out -- copie : la liste d'entrée n'est pas modifiée
  r.input_intact = #list == 5 and list[1].at == nil
  r.merge_field = d[1].at == 40
  -- quais : même position mais objets différents = deux coffres ; même position et même objet = une copie
  local q = { { x = 1.5, y = 1.5, item = "iron-plate" }, { x = 1.5, y = 1.5, item = "iron-plate" }, { x = 1.5, y = 1.5, item = "coal" },
    { x = 2.5, y = 1.5, item = "iron-plate" } }
  r.quai_items = D.count_dups(q, D.quai_key) == 1 and #D.dedupe(q, D.quai_key) == 3
  -- virgule fixe : deux écritures de la même position (1/256) sont la même clé
  r.fixed_point = D.out_key({ x = 10.5, y = 3.5 }) == D.out_key({ x = 10.5 + 1 / 1024, y = 3.5 - 1 / 1024 })
    and D.out_key({ x = 10.5, y = 3.5 }) ~= D.out_key({ x = 10.5 + 1 / 128, y = 3.5 })
  -- plan des taches : indice sans coffre = tache libre jetee, tache prise gardee telle quelle
  local pl = D.plan_tasks({ { key = "ia1d:3:o:8", mode = "collect", idx = 8, taken = true },
    { key = "ia1d:3:o:9", mode = "collect", idx = 9, taken = false } }, { [1] = 1 }, {}, 3)
  r.plan_beyond = pl[1].action == "keep" and pl[1].newkey == "ia1d:3:o:8" and pl[2].action == "drop"
  -- liste vide, nil
  local e1 = D.dedupe(nil, D.out_key)
  r.empty = #e1 == 0 and D.count_dups(nil, D.out_key) == 0
  return r
end
local PURE_KEYS = { "count", "dedupe", "order_first", "input_intact", "merge_field", "quai_items", "fixed_point", "plan_beyond", "empty" }
section("1. regle pure")
local pr = pure_cases(new_d())
for _, k in ipairs(PURE_KEYS) do check(pr[k] == true, "regle pure : " .. k) end

---------------------------------------------------------------------------------------------------
-- 2. Col.waiting_all
---------------------------------------------------------------------------------------------------
defines = { inventory = { chest = 1 } }
function log() end
local SRC_COL = read_file("script/team/collecte.lua")
local function new_col(mut)
  package.loaded["script.team.stock"] = {}
  local src = mut and mut(SRC_COL) or SRC_COL
  return load_chunk(src, "collecte")
end

local CHEST_NAME = require("shared.team.config").outposts.coal.sink
local function new_surface(chests)
  return {
    find_entity = function(name, pos)
      if name ~= CHEST_NAME then return nil end
      for _, c in ipairs(chests) do
        if c.valid and c.pos.x == pos[1] and c.pos.y == pos[2] then return c end
      end
      return nil
    end,
    find_nearest_enemy = function() return nil end,
  }
end
local function chest(n, x, y, items)
  return { valid = true, unit_number = n, pos = { x = x, y = y }, force = { name = "player" },
    get_inventory = function() return { get_contents = function() local t = {}; for k, v in pairs(items) do t[k] = v end; return t end } end }
end

local function col_cases(Col)
  local r = {}
  local c1 = chest(11, 10.5, 3.5, { ["automation-science-pack"] = 81 })
  local c2 = chest(12, 20.5, 3.5, { ["iron-plate"] = 500 })
  local surface = new_surface({ c1, c2 })
  local f = { force = "player", key = "player", hq = { valid = true, position = { x = 0, y = 0 } },
    team = { board = { tasks = {} } }, outposts = {} }
  local function o(x, y) return { x = x, y = y } end
  -- a. quatre copies du même coffre (le cas du module de packs rouges) : une source, 81 objets, pas 324
  local b = { order = { 3 }, projects = { [3] = { state = "fini", outs = { o(10.5, 3.5), o(10.5, 3.5), o(10.5, 3.5), o(10.5, 3.5) } } } }
  local src = Col.waiting_all(f, surface, b, 1000)
  local sum = 0
  for _, s in ipairs(src) do sum = sum + (s.items["automation-science-pack"] or 0) end
  r.one_source = #src == 1 and sum == 81
  -- b. coffres distincts : deux sources
  b = { order = { 3 }, projects = { [3] = { state = "fini", outs = { o(10.5, 3.5), o(20.5, 3.5) } } } }
  src = Col.waiting_all(f, surface, b, 1000)
  r.distinct = #src == 2
  -- c. deux projets qui désignent le même coffre : une source
  b = { order = { 3, 4 }, projects = { [3] = { state = "fini", outs = { o(10.5, 3.5) } }, [4] = { state = "fini", outs = { o(10.5, 3.5), o(20.5, 3.5) } } } }
  src = Col.waiting_all(f, surface, b, 1000)
  r.two_projects = #src == 2
  -- d. la tâche de collecte PRISE d'une copie l'emporte sur la tâche libre de la première
  f.team.board.tasks["ia1d:3:o:1"] = { key = "ia1d:3:o:1", ia1d = { pid = 3, mode = "collect", idx = 1 } }
  f.team.board.tasks["ia1d:3:o:3"] = { key = "ia1d:3:o:3", ia1d = { pid = 3, mode = "collect", idx = 3 }, worker = 77 }
  b = { order = { 3 }, projects = { [3] = { state = "fini", outs = { o(10.5, 3.5), o(10.5, 3.5), o(10.5, 3.5), o(10.5, 3.5) } } } }
  src = Col.waiting_all(f, surface, b, 1000)
  r.taken_wins = #src == 1 and src[1].collect == "taken" and src[1].task == "ia1d:3:o:3" and src[1].id == "3:1"
  -- e. un coffre absent est ignoré, un coffre d'une autre force aussi
  c2.force = { name = "enemy" }
  b = { order = { 3 }, projects = { [3] = { state = "fini", outs = { o(20.5, 3.5), o(99.5, 3.5) } } } }
  r.absent_or_foreign = #Col.waiting_all(f, surface, b, 1000) == 0
  return r
end
local COL_KEYS = { "one_source", "distinct", "two_projects", "taken_wins", "absent_or_foreign" }
section("2. Col.waiting_all")
local cr = col_cases(new_col())
for _, k in ipairs(COL_KEYS) do check(cr[k] == true, "waiting_all : " .. k) end

---------------------------------------------------------------------------------------------------
-- 3. Build.dedupe_sites (fonction extraite de build.lua)
---------------------------------------------------------------------------------------------------
local SRC_BUILD = read_file("script/team/build.lua")
local function extract_fn(src)
  local a = src:find("function Build.dedupe_sites(f, p)", 1, true)
  assert(a, "Build.dedupe_sites introuvable")
  local b = src:find("\nend\n", a, true)
  return src:sub(a, b + 4)
end
local logs = {}
local AGENTS = {}
local function new_dedupe(mut_fn, mut_d)
  local fn_src = extract_fn(SRC_BUILD)
  if mut_fn then fn_src = mut_fn(fn_src) end
  local env = setmetatable({
    Build = { Sites = new_d(mut_d), Agents = { get = function(id) return AGENTS[id] end } },
    Board = { drop_free = function(f, keep) -- comme script/team/board.lua : jette les taches libres que `keep` refuse
        local tasks, n = f.team.board.tasks, 0
        local ks = {}
        for k in pairs(tasks) do ks[#ks + 1] = k end
        table.sort(ks)
        for _, k in ipairs(ks) do
          local t = tasks[k]
          if not t.worker and not keep(t) then tasks[k] = nil; n = n + 1 end
        end
        return n
      end },
    sorted_keys = function(t) local ks = {}; for k in pairs(t) do ks[#ks + 1] = k end; table.sort(ks); return ks end,
    log = function(s) logs[#logs + 1] = s end,
    game = { tick = 3600 * 40 },
  }, { __index = _G })
  local chunk = load(fn_src .. "\nreturn Build.dedupe_sites", "=dedupe_sites", "t", env)
  assert(chunk, "extraction invalide")
  return chunk()
end

local function task(pid, mode, idx, worker)
  return { key = "ia1d:" .. pid .. ":" .. (mode == "collect" and "o" or (mode == "fill" and "q" or mode)) .. ":" .. idx, kind = "carry",
    ia1d = { pid = pid, mode = mode, idx = idx }, worker = worker }
end

local function dedupe_cases(dedupe)
  local r = {}
  local function proj()
    return { id = 3, quais = { { x = 1.5, y = 1.5, item = "iron-plate" }, { x = 1.5, y = 1.5, item = "iron-plate" } },
      outs = { { x = 9.5, y = 2.5 }, { x = 9.5, y = 2.5 }, { x = 9.5, y = 2.5 }, { x = 9.5, y = 2.5 } }, quota = { x = 1 }, quota_key = "k" }
  end
  local function board(list)
    local tasks = {}
    for _, t in ipairs(list) do tasks[t.key] = t end
    return { team = { board = { tasks = tasks } }, key = "player" }
  end
  local function count(tasks) local n = 0; for _ in pairs(tasks) do n = n + 1 end; return n end
  -- a. projet x4 : quatre collectes libres, deux « fill » libres, une tache « build » du projet, une tache d'un autre projet :
  --    il reste UNE collecte, UN fill, la tache build et celle de l'autre projet
  local f = board({ task(3, "collect", 1), task(3, "collect", 2), task(3, "collect", 3), task(3, "collect", 4),
    task(3, "fill", 1), task(3, "fill", 2), task(3, "build", 1), task(4, "collect", 2) })
  local p = proj()
  logs = {}
  local n = dedupe(f, p)
  local tk = f.team.board.tasks
  r.removed = n == 4 and #p.quais == 1 and #p.outs == 1 and p.sites_v == 1
  r.quota_reset = p.quota == nil and p.quota_key == nil
  r.free_dups_dropped = tk["ia1d:3:o:1"] ~= nil and tk["ia1d:3:o:2"] == nil and tk["ia1d:3:o:3"] == nil and tk["ia1d:3:o:4"] == nil
    and tk["ia1d:3:q:1"] ~= nil and tk["ia1d:3:q:2"] == nil
  r.others_kept = tk["ia1d:3:build:1"] ~= nil and tk["ia1d:4:o:2"] ~= nil and count(tk) == 4
  r.logged = #logs == 1 and logs[1]:find("FO%-SITES") ~= nil and logs[1]:find("3 de coffre de sortie", 1, true) ~= nil and logs[1]:find("4 tache", 1, true) ~= nil
  -- b. MIGRATION : projet x4, taches libres ET une tache prise (o:3, porteuse 5, son agent a copie l'indice 3) : la prise reste,
  --    passe a l'indice 1 et a la cle o:1, l'agent suit ; les copies libres partent
  AGENTS[5] = { ia1d = { pid = 3, mode = "collect", idx = 3 } }
  local taken = task(3, "collect", 3, 5)
  f = board({ task(3, "collect", 1), task(3, "collect", 2), taken, task(3, "collect", 4), task(3, "fill", 1), task(3, "fill", 2) })
  p = proj()
  dedupe(f, p)
  tk = f.team.board.tasks
  r.taken_kept = tk["ia1d:3:o:1"] == taken and taken.key == "ia1d:3:o:1" and taken.ia1d.idx == 1 and taken.worker == 5
    and tk["ia1d:3:o:2"] == nil and tk["ia1d:3:o:3"] == nil and tk["ia1d:3:o:4"] == nil
  r.agent_follows = AGENTS[5].ia1d.idx == 1
  r.fill_one = tk["ia1d:3:q:1"] ~= nil and tk["ia1d:3:q:2"] == nil
  -- b2. l'agent d'un AUTRE projet n'est pas touche
  AGENTS[6] = { ia1d = { pid = 8, mode = "collect", idx = 3 } }
  local other = task(8, "collect", 3, 6)
  AGENTS[5] = { ia1d = { pid = 3, mode = "collect", idx = 3 } }
  f = board({ task(3, "collect", 1), task(3, "collect", 3, 5), other })
  dedupe(f, proj())
  r.other_agent_untouched = AGENTS[6].ia1d.idx == 3 and other.ia1d.idx == 3 and f.team.board.tasks["ia1d:8:o:3"] == other
  -- b2 bis. la porteuse d'une tache du projet dont l'agent travaille deja pour un autre projet : l'agent n'est pas touche
  AGENTS[9] = { ia1d = { pid = 8, mode = "collect", idx = 3 } }
  f = board({ task(3, "collect", 1), task(3, "collect", 3, 9) })
  dedupe(f, proj())
  r.agent_other_job = AGENTS[9].ia1d.idx == 3 and f.team.board.tasks["ia1d:3:o:1"].ia1d.idx == 1
  -- b2 ter. indice hors liste (plus de coffre a cet indice) : la tache libre est jetee, la prise reste telle quelle
  local far_free, far_taken = task(3, "collect", 9), task(3, "collect", 8, 4)
  f = board({ task(3, "collect", 1), far_free, far_taken })
  dedupe(f, proj())
  r.beyond_list = f.team.board.tasks["ia1d:3:o:9"] == nil and f.team.board.tasks["ia1d:3:o:8"] == far_taken and far_taken.ia1d.idx == 8
  -- b3. deux taches prises sur deux copies du meme coffre : toutes deux gardees, indices coherents (jamais jetees)
  AGENTS[5] = { ia1d = { pid = 3, mode = "collect", idx = 2 } }
  AGENTS[7] = { ia1d = { pid = 3, mode = "collect", idx = 4 } }
  local ta, tb = task(3, "collect", 2, 5), task(3, "collect", 4, 7)
  f = board({ ta, tb })
  dedupe(f, proj())
  r.two_taken = ta.ia1d.idx == 1 and tb.ia1d.idx == 1 and f.team.board.tasks["ia1d:3:o:1"] == ta and AGENTS[5].ia1d.idx == 1
    and AGENTS[7].ia1d.idx == 1 and count(f.team.board.tasks) == 2
  -- c. coffres DISTINCTS a indices decales (outs = A, A, B, A, B) : la tache prise de B passe de 5 a 2
  p = { id = 3, quais = {}, outs = { { x = 1.5, y = 1.5 }, { x = 1.5, y = 1.5 }, { x = 5.5, y = 1.5 }, { x = 1.5, y = 1.5 }, { x = 5.5, y = 1.5 } } }
  local tbk = task(3, "collect", 5, 5)
  AGENTS[5] = { ia1d = { pid = 3, mode = "collect", idx = 5 } }
  f = board({ task(3, "collect", 1), task(3, "collect", 2), task(3, "collect", 3), task(3, "collect", 4), tbk })
  dedupe(f, p)
  tk = f.team.board.tasks
  r.shifted = #p.outs == 2 and p.outs[2].x == 5.5 and tbk.ia1d.idx == 2 and tk["ia1d:3:o:2"] == tbk and tk["ia1d:3:o:1"] ~= nil
    and tk["ia1d:3:o:3"] == nil and tk["ia1d:3:o:5"] == nil and AGENTS[5].ia1d.idx == 2 and count(tk) == 2
  -- d. projet propre : rien, marque ; taches intactes
  p = { id = 3, quais = { { x = 1.5, y = 1.5, item = "coal" } }, outs = { { x = 9.5, y = 2.5 } } }
  f = board({ task(3, "collect", 1) })
  r.clean = dedupe(f, p) == 0 and p.sites_v == 1 and #p.outs == 1 and count(f.team.board.tasks) == 1
  -- e. projet sans listes
  p = { id = 3 }
  r.no_lists = dedupe({ key = "player" }, p) == 0 and p.sites_v == 1
  -- f. plan x4 sans AUCUNE tache au tableau (f.team absent) : les listes sont nettoyees quand meme
  p = proj()
  r.no_board = dedupe({ key = "player", team = {} }, p) == 4 and #p.outs == 1 and p.sites_v == 1
  return r
end
local DD_KEYS = { "removed", "quota_reset", "free_dups_dropped", "others_kept", "logged", "taken_kept", "agent_follows", "fill_one",
  "other_agent_untouched", "agent_other_job", "beyond_list", "two_taken", "shifted", "clean", "no_lists", "no_board" }
section("3. Build.dedupe_sites (migration d'un projet x4)")
logs = {}
do
  local fn = new_dedupe()
  local dr = dedupe_cases(fn)
  for _, k in ipairs(DD_KEYS) do check(dr[k] == true, "dedupe_sites : " .. k) end
end

---------------------------------------------------------------------------------------------------
-- 4. build.lua : la passe « plan »
---------------------------------------------------------------------------------------------------
section("4. build.lua, branches de la passe plan")
local function plan_block(src)
  local a = src:find('  if p.state == "plan" then\n    if not Tokens.take(f, tick, Build.COST_PLAN) then return end', 1, true)
  assert(a, "passe plan introuvable")
  local b = src:find('  if p.state == "reserve" then', a, true)
  return src:sub(a, b - 1)
end
local function branches(block)
  -- chaque branche qui rend ce qui a été réservé : elle remet p.ents et p.parts à zéro
  local n_reset, n_both = 0, 0
  for line_start in block:gmatch("()      p%.ents, p%.parts[^\n]*\n") do
    n_reset = n_reset + 1
    local after = block:sub(line_start, line_start + 400)
    local nxt = after:match("\n([^\n]*)\n", 2)
    if nxt and nxt:find("p.quais, p.outs = {}, {}", 1, true) then n_both = n_both + 1 end
  end
  return n_reset, n_both
end
local block = plan_block(SRC_BUILD)
local n_reset, n_both = branches(block)
check(n_reset == 5, "cinq branches de la passe plan rendent ce qu'elles ont reserve (dont « foreuses », lot TRANCHES-FOREUSES) (trouve " .. n_reset .. ")")
check(n_both == n_reset, "chaque branche remet aussi p.quais et p.outs a zero (" .. n_both .. " sur " .. n_reset .. ")")
check(block:find("p.sites_v = 1", 1, true) ~= nil, "un plan reussi marque p.sites_v")
check(SRC_BUILD:find("if p.sites_v ~= 1 then Build.dedupe_sites(f, p) end", 1, true) ~= nil, "la passe des taches appelle Build.dedupe_sites")
check(SRC_BUILD:find('Build.Sites = require("shared.team.sites_dedup")', 1, true) ~= nil, "Build.Sites est un champ de Build (limite de 200 locales)")

---------------------------------------------------------------------------------------------------
-- 5. Mutants
---------------------------------------------------------------------------------------------------
section("5. mutants")
local function mutant_pure(name, mut, keys)
  local ok, res = pcall(function() return pure_cases(new_d(mut)) end)
  local caught = not ok
  if ok then for _, k in ipairs(keys) do if res[k] ~= true then caught = true end end end
  check(caught, "mutant non detecte : " .. name)
end
mutant_pure("quai sans objet dans la cle", function(s) return plain_replace(s, 'return D.out_key(q) .. "|" .. tostring(q.item)', "return D.out_key(q)") end, { "quai_items" })
mutant_pure("champ d'une copie perdu", function(s) return plain_replace(s, "if first[fk] == nil then first[fk] = fv end", "") end, { "merge_field" })
mutant_pure("position arrondie a la tuile", function(s) return plain_replace(s, "floor((o.x or 0) * 256 + 0.5)", "floor(o.x or 0)") end, { "fixed_point" })
mutant_pure("aucune copie retiree", function(s) return plain_replace(s, "if first then", "if false then") end, { "dedupe", "count" })
mutant_pure("liste d'entree modifiee", function(s) return plain_replace(s, "local c = {}\n      for fk, fv in pairs(e) do c[fk] = fv end", "local c = e") end, { "input_intact", "merge_field" })

local function mutant_col(name, mut, keys)
  local ok, res = pcall(function() return col_cases(new_col(mut)) end)
  local caught = not ok
  if ok then for _, k in ipairs(keys) do if res[k] ~= true then caught = true end end end
  check(caught, "mutant non detecte : " .. name)
end
mutant_col("waiting_all lit chaque copie", function(s) return plain_replace(s, "local prev = seen[ck]", "local prev = nil") end, { "one_source", "two_projects", "taken_wins" })
mutant_col("waiting_all : cle de coffre = indice", function(s) return plain_replace(s, "local ck = c.unit_number or (tostring(o.x) .. \",\" .. tostring(o.y))", "local ck = pid .. \":\" .. i") end, { "one_source", "two_projects" })
mutant_col("waiting_all : la tache prise ne l'emporte pas", function(s) return plain_replace(s, '(entry.collect == "taken" and prev.collect ~= "taken")', "false") end, { "taken_wins" })
mutant_col("waiting_all : tous les coffres fusionnes", function(s) return plain_replace(s, "local ck = c.unit_number or (tostring(o.x) .. \",\" .. tostring(o.y))", "local ck = 1") end, { "distinct" })

local function mutant_dd(name, mut_fn, keys, mut_d)
  logs = {}
  local ok, res = pcall(function() local fn = new_dedupe(mut_fn, mut_d); return dedupe_cases(fn) end)
  local caught = not ok
  if ok then for _, k in ipairs(keys) do if res[k] ~= true then caught = true end end end
  check(caught, "mutant non detecte : " .. name)
end
mutant_dd("dedupe_sites garde le quota", function(s) return plain_replace(s, "p.quota, p.quota_key = nil, nil", "") end, { "quota_reset" })
mutant_dd("dedupe_sites garde les taches libres", function(s) return plain_replace(s, "  if next(dropped) ~= nil then Board.drop_free(f, function(t) return not dropped[t] end) end\n", "") end, { "free_dups_dropped", "taken_kept" })
mutant_dd("dedupe_sites jette tout du projet", function(s) return plain_replace(s, 'if a.action == "drop" then dropped[by_key[a.key]] = true end', "dropped[by_key[a.key]] = true") end, { "others_kept", "fill_one" })
mutant_dd("dedupe_sites : indice de la tache non reecrit", function(s) return plain_replace(s, "      t.ia1d.idx = a.idx\n", "") end, { "taken_kept", "shifted", "two_taken" })
mutant_dd("dedupe_sites : agent non suivi", function(s) return plain_replace(s, "and aj.idx == old then aj.idx = a.idx end", "and aj.idx == old then end") end, { "agent_follows", "shifted", "two_taken" })
mutant_dd("dedupe_sites : agent d'un autre projet reecrit", function(s) return plain_replace(s, "if aj and aj.pid == p.id and aj.mode == t.ia1d.mode and aj.idx == old then", "if aj then") end, { "agent_other_job" })
mutant_dd("dedupe_sites : cle non reecrite", function(s) return plain_replace(s, "      if a.newkey ~= a.key and tasks[a.newkey] == nil then", "      if false then") end, { "taken_kept", "shifted", "two_taken" })
mutant_dd("dedupe_sites : liste des quais intacte", function(s) return plain_replace(s, "p.quais, p.outs = quais, outs", "p.outs = outs") end, { "removed", "no_board" })
mutant_dd("dedupe_sites ne marque pas le projet", function(s) return plain_replace(s, "  p.sites_v = 1\n  log(", "  log(") end, { "removed" })
mutant_dd("dedupe_sites ne dit rien", function(s) return plain_replace(s, "  log(string.format(", "  local _ = (string.format(") end, { "logged" })
mutant_pure("plan : une tache prise est jetee", function(s) return plain_replace(s, 'action = en.taken and "keep" or "drop", idx = en.idx', 'action = "drop", idx = en.idx') end, { "plan_beyond" })
mutant_dd("plan : la prise ne gagne pas", nil, { "taken_kept", "shifted" }, function(s) return plain_replace(s, "(en.taken and not w.taken)", "false") end)
mutant_dd("plan : toutes les copies restent", nil, { "free_dups_dropped" }, function(s) return plain_replace(s, 'out[#out + 1] = { key = en.key, action = "drop", idx = ni, newkey = newkey }', 'out[#out + 1] = { key = en.key, action = "keep", idx = ni, newkey = en.key }') end)
mutant_dd("remap : copie rangee a son propre indice", nil, { "shifted", "removed" }, function(s) return plain_replace(s, "map[i] = first.idx", "map[i] = i") end)

-- mutants de build.lua (texte) : le contrôle de structure les voit
local function mutant_build(name, mut)
  local src = mut(SRC_BUILD)
  local blk = plan_block(src)
  local a, b = branches(blk)
  local caught = (a ~= 4) or (b ~= a) or blk:find("p.sites_v = 1", 1, true) == nil
    or src:find("if p.sites_v ~= 1 then Build.dedupe_sites(f, p) end", 1, true) == nil
  check(caught, "mutant non detecte : " .. name)
end
mutant_build("branche masques sans remise a zero", function(s) return plain_replace(s, "      p.quais, p.outs = {}, {} -- lot MESURE-MODULE : plan_feed les AJOUTE", "      -- lot MESURE-MODULE : plan_feed les AJOUTE") end)
mutant_build("branche loin sans remise a zero", function(s)
  return plain_replace(s, "p.ents, p.parts, p.far = {}, {}, nil\n      p.quais, p.outs = {}, {} -- lot MESURE-MODULE (voir plus haut)", "p.ents, p.parts, p.far = {}, {}, nil")
end)
mutant_build("plan reussi sans marque", function(s) return plain_replace(s, "      p.sites_v = 1 -- lot MESURE-MODULE", "      local _ = 1 -- lot MESURE-MODULE") end)
mutant_build("passe des taches sans dedoublonnage", function(s) return plain_replace(s, "if p.sites_v ~= 1 then Build.dedupe_sites(f, p) end", "") end)

print(string.format("[SITES-DEDUP] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
