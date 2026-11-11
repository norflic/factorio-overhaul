--[[
  Lot INDUSTRIE, sous-lot I2 « INACTIFS » : test hors jeu de la file sûre des PNJ sans tâche (shared/team/travail_sur.lua) et de
  son branchement dans script/team/poles.lua.
    §1 attente : un PNJ est affamé après Sur.STARVE_THINKS pensées de suite sans tâche, l'oubli d'un PNJ occupé ou disparu ;
    §2 cause d'une attente : menace, bloque, rien ;
    §3 file : bornée par les affamés moins les tâches déjà ouvertes ; rien en cas de menace, de prudence, d'équipe décimée ;
       tournées d'abord (plus gros reste, avant-poste proche, ni dangereux, ni non défendu, ni déjà servi), puis minage des seules
       ressources permises, la plus en manque d'abord, à tour de rôle, clés uniques ; aucune tâche ne porte d'objets à prendre
       au coffre ; déterminisme ; aucun nom d'objet du jeu dans la règle ;
    §4 journal : cumuls, parts en PNJ-pensées, ligne [FO-INACTIF] ;
    §5 branchement : script/team/poles.lua appelle la règle après l'ouverture du fond, hors menace, et compte les fins de tâche ;
    §6 mutants : chaque règle retirée est vue.
  Usage : lua5.2 tests/travail_sur_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path

local function read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end
local SRC = read("shared/team/travail_sur.lua")

local function load_mod(src)
  local fn, err = load(src, "=travail_sur", "t")
  if not fn then return nil, err end
  local ok, mod = pcall(fn)
  if not ok then return nil, mod end
  return mod
end

local function keys_of(r)
  local out = {}
  for _, t in ipairs(r.tasks) do out[#out + 1] = t.key end
  return table.concat(out, ",")
end

local function base_ctx(extra)
  local c = {
    starved = 5, open = 0, keys = {}, batch = 50, radius = 96, near_d2 = 64 * 64,
    outposts = {
      { id = 3, output = 12, d2 = 900 },
      { id = 1, output = 9, d2 = 5000 },
      { id = 2, output = 9, d2 = 100 },
      { id = 4, output = 0, d2 = 100 },
    },
    resources = {
      { res = "r-a", gap = 500, ok = true },
      { res = "r-b", gap = 900, ok = true },
      { res = "r-c", gap = 0, ok = false },
    },
  }
  for k, v in pairs(extra or {}) do c[k] = v end
  return c
end

local function suite(S)
  local pass, fail, msgs = 0, 0, {}
  local function check(c, m)
    if c then pass = pass + 1 else fail = fail + 1 msgs[#msgs + 1] = m end
  end

  -- §1 Attente.
  local st, n, fr = S.track(nil, { 7, 9 })
  check(n == 0 and fr == 2 and st[7] == 1 and st[9] == 1, "§1 premier relevé : personne d'affamé, 2 frais (" .. n .. ", " .. fr .. ")")
  st, n, fr = S.track(st, { 7, 9, 11 })
  check(n == 2 and fr == 1 and st[7] == 2 and st[11] == 1, "§1 deuxième pensée : 2 affamés, 1 frais (" .. n .. ", " .. fr .. ")")
  st, n, fr = S.track(st, { 9 })
  check(n == 1 and fr == 0 and st[7] == nil and st[11] == nil and st[9] == 3, "§1 un PNJ occupé ou disparu est oublié, l'autre garde sa suite")
  st, n, fr = S.track(st, {})
  check(n == 0 and fr == 0 and next(st) == nil, "§1 plus personne sans tâche : table vide")
  check(S.STARVE_THINKS >= 2, "§1 un PNJ n'est pas affamé à sa première pensée sans tâche (marge d'ouverture du fond)")

  -- §2 Cause.
  check(S.cause(true, 0) == "menace" and S.cause(true, 5) == "menace", "§2 QG menacé : menace, quelles que soient les tâches libres")
  check(S.cause(false, 3) == "bloque" and S.cause(false, 0) == "rien" and S.cause(false, nil) == "rien",
    "§2 tâches libres : bloque ; aucune : rien")

  -- §3 File.
  local r = S.plan(base_ctx())
  check(r.want == 5 and #r.tasks == 5 and r.left == 0, "§3 5 affamés : 5 tâches (" .. #r.tasks .. ")")
  check(r.service == 2 and r.mine == 3, "§3 deux tournées (avant-postes 3 puis 2) puis 3 minages (" .. r.service .. ", " .. r.mine .. ")")
  check(keys_of(r) == "service:3,service:2,sur:mine:r-b:1,sur:mine:r-a:1,sur:mine:r-b:2",
    "§3 ordre : tournées (plus gros reste, puis proche), minage de la ressource la plus en manque d'abord, à tour de rôle : " .. keys_of(r))
  local clean = true
  for _, t in ipairs(r.tasks) do
    if t.items or t.uses or t.steps or not t.fond or not t.safe or (t.prio or 99) >= 18 then clean = false end
  end
  check(clean, "§3 aucune tâche ne prend d'objet au coffre ; toutes de fond et sûres, sous la priorité de la garde (18)")
  check(r.tasks[3].count == 50 and r.tasks[3].radius == 96 and r.tasks[3].resource == "r-b", "§3 minage : fournée et rayon près du coffre")
  local r1 = S.plan(base_ctx({ starved = 1 }))
  check(#r1.tasks == 1 and r1.service == 1 and r1.mine == 0, "§3 1 affamé : une seule tournée")
  local ro = S.plan(base_ctx({ starved = 6, open = 4 }))
  check(ro.want == 2 and #ro.tasks == 2, "§3 6 affamés dont 4 tâches de la file déjà ouvertes : 2 de plus (" .. ro.want .. ")")
  check(#S.plan(base_ctx({ starved = 3, open = 5 })).tasks == 0, "§3 plus de tâches ouvertes que d'affamés : rien")
  check(#S.plan(base_ctx({ starved = 0 })).tasks == 0, "§3 personne d'affamé ni de frais : rien")
  local rf = S.plan(base_ctx({ starved = 1, fresh = 3 }))
  check(rf.want == 4 and #rf.tasks == 4, "§3 1 affamé et 3 frais : 4 tâches, un PNJ qui vient de finir n'attend pas 2 pensées (" .. rf.want .. ")")
  local rg = S.plan(base_ctx({ starved = 1, fresh = 3, also = { { key = "f1" }, { key = "f2" } } }))
  check(rg.want == 2 and #rg.tasks == 2, "§3 2 tâches de fond ouvertes dans la pensée servent 2 frais : 2 tâches seulement (" .. rg.want .. ")")
  local rh = S.plan(base_ctx({ starved = 0, fresh = 2, also = { { key = "f1" }, { key = "f2" }, { key = "f3" } } }))
  check(rh.want == 0 and #rh.tasks == 0, "§3 le fond sert tous les frais : rien")
  check(#S.plan(base_ctx({ threat = true })).tasks == 0, "§3 QG menacé : rien (tout le monde au coffre)")
  check(#S.plan(base_ctx({ prudent = true })).tasks == 0, "§3 prudence après des pertes : rien hors du QG")
  check(#S.plan(base_ctx({ floor_ok = false })).tasks == 0, "§3 équipe décimée (sous son effectif de départ) : rien (F241)")
  check(#S.plan(base_ctx({ floor_ok = true })).tasks == 5, "§3 effectif de départ atteint : la file sert")
  local rd = S.plan(base_ctx({ outposts = {
    { id = 1, output = 9, d2 = 100, danger = true }, { id = 2, output = 9, d2 = 100, undefended = true },
    { id = 3, output = 9, d2 = 100, has_task = true }, { id = 4, output = 9, d2 = 64 * 64 + 1 },
    { id = 5, output = 0, d2 = 100 } }, starved = 3, resources = {} }))
  check(#rd.tasks == 0 and rd.left == 3, "§3 avant-poste dangereux, non défendu, déjà servi, trop loin ou vide : aucune tournée (" .. #rd.tasks .. ")")
  local rk = S.plan(base_ctx({ starved = 3, keys = { ["service:2"] = true, ["sur:mine:r-b:1"] = true }, resources = {
    { res = "r-b", gap = 900, ok = true } } }))
  check(keys_of(rk) == "service:3,sur:mine:r-b:2,sur:mine:r-b:3", "§3 clés déjà au tableau sautées : " .. keys_of(rk))
  local ra = S.plan(base_ctx({ starved = 2, also = { { key = "service:2" }, { key = "service:3" } }, resources = {
    { res = "r-b", gap = 900, ok = true } } }))
  check(keys_of(ra) == "sur:mine:r-b:1,sur:mine:r-b:2", "§3 tâches ouvertes dans la même pensée (also) sautées : " .. keys_of(ra))
  local rn = S.plan(base_ctx({ starved = 4, outposts = {}, resources = {
    { res = "r-a", gap = 500, ok = false }, { res = "r-b", gap = 900, ok = false } } }))
  check(#rn.tasks == 0 and rn.left == 4, "§3 aucune ressource permise : rien, et les 4 affamés restent comptés (" .. rn.left .. ")")
  local re = S.plan(base_ctx({ starved = 4, outposts = {}, resources = {
    { res = "r-a", gap = 400, ok = true }, { res = "r-b", gap = 400, ok = true } } }))
  check(keys_of(re) == "sur:mine:r-a:1,sur:mine:r-b:1,sur:mine:r-a:2,sur:mine:r-b:2", "§3 manque égal : l'ordre de la liste, à tour de rôle : " .. keys_of(re))
  local seen, uniq = {}, true
  local rb = S.plan(base_ctx({ starved = 40, outposts = {} }))
  for _, t in ipairs(rb.tasks) do
    if seen[t.key] then uniq = false end
    seen[t.key] = true
  end
  check(uniq and #rb.tasks == 40, "§3 40 affamés : 40 clés distinctes (" .. #rb.tasks .. ")")
  local rx = S.plan(base_ctx({ starved = 500, outposts = {} }))
  check(#rx.tasks <= S.MINE_TRIES * 2 and rx.left > 0, "§3 borne d'indices par ressource : " .. #rx.tasks)
  check(keys_of(S.plan(base_ctx())) == keys_of(S.plan(base_ctx())), "§3 déterminisme : même entrée, même sortie")
  local code = SRC:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local named = {}
  for _, w in ipairs({ "iron", "copper", "coal", "stone", "plate", "ore", "wood", "gun%-turret", "burner", "fo%-" }) do
    if code:find(w) then named[#named + 1] = w end
  end
  check(#named == 0, "§3 aucun nom d'objet du jeu dans la règle : " .. table.concat(named, ", "))
  -- S.kind_list énumère les genres puis TRIE : c'est la seule lecture par pairs, et aucune décision n'en dépend.
  local kl_a, kl_b = code:find("function S%.kind_list.-\nend")
  local rest = kl_a and (code:sub(1, kl_a - 1) .. code:sub(kl_b + 1)) or code
  check(kl_a ~= nil and not (rest:gsub("ipairs%(", "")):find("pairs%("), "§3 aucune itération par pairs hors S.kind_list (qui trie)")
  check(code:find("table%.sort%(out%)", kl_a or 1) ~= nil, "§3 S.kind_list trie")
  check(not code:find("os%.time") and not code:find("math%.random") and not code:find("game"), "§3 ni horloge, ni hasard, ni moteur")

  -- §3 bis Mise à l'écart d'une ressource qui échoue.
  local bad = {}
  check(not S.blocked(bad, "r-a", 0) and not S.blocked(nil, "r-a", 0), "§3 bis rien d'écarté au départ")
  S.fail(bad, "r-a", 1000, "programme")
  check(S.blocked(bad, "r-a", 1000 + 7199) and not S.blocked(bad, "r-a", 1000 + 7200), "§3 bis premier échec : 2 min")
  S.fail(bad, "r-a", 9000, "main:stock")
  check(S.blocked(bad, "r-a", 9000 + 14399) and not S.blocked(bad, "r-a", 9000 + 14400), "§3 bis deuxième échec de suite : 4 min")
  S.fail(bad, "r-a", 30000, nil)
  S.fail(bad, "r-a", 60000, nil)
  S.fail(bad, "r-a", 90000, nil)
  check(not S.blocked(bad, "r-a", 90000 + 7200 * 8) and S.blocked(bad, "r-a", 90000 + 7200 * 8 - 1), "§3 bis au plus 16 min (4 doublements)")
  S.success(bad, "r-a")
  check(not S.blocked(bad, "r-a", 90001) and bad["r-a"] == nil, "§3 bis une réussite efface l'écart")
  S.fail(bad, "r-b", 0, "danger")
  S.fail(bad, "r-b", 0, "abri")
  S.fail(bad, "r-b", 0, "fuite")
  S.fail(bad, "r-b", 0, "preempte")
  check(not S.blocked(bad, "r-b", 1) and bad["r-b"] == nil, "§3 bis un refus passager (danger, abri, fuite, rappel pour une urgence) n'écarte rien")

  -- §3 ter Intégration 0.6.30 : rappel pour une urgence, matière retirée du fond par le cerveau.
  check(S.recall_n(2, 2, 0, 0) == 2 and S.recall_n(2, 2, 1, 0) == 1 and S.recall_n(2, 2, 5, 9999) == 0 and S.recall_n(0, 0, 0, 9999) == 0, "§3 ter urgences sans PNJ libre : rappel aussitôt")
  check(S.recall_n(0, 3, 0, S.RECALL_EVERY - 1) == 0 and S.recall_n(0, 3, 0, S.RECALL_EVERY) == 1 and S.recall_n(0, 3, 3, S.RECALL_EVERY) == 0, "§3 ter travail ordinaire : un seul rappel à la fois, espacé")
  check(not S.withdrawn(nil, "a") and not S.withdrawn({}, nil) and not S.withdrawn({}, "a", "b"), "§3 ter rien de retiré sans état")
  check(S.withdrawn({ saturated = { a = true } }, "a") and not S.withdrawn({ saturated = { a = true } }, "b"), "§3 ter matière saturée")
  check(not S.withdrawn({ saturated = { a = true }, other_short = false }, "a"), "§3 ter saturée sans autre manque : le cerveau ne retire rien (comme Ia3.after_poles)")
  check(S.withdrawn({ covered = { a = true }, other_short = false }, "a"), "§3 ter couverte par un module : retirée même sans autre manque")
  check(S.withdrawn({ covered = { p = true } }, "ore", "p") and not S.withdrawn({ covered = { p = true } }, "ore"), "§3 ter minerai d'une plaque couverte")

  -- §4 Journal.
  local acc = {}
  S.note(acc, { n = 10, idle = 4, starved = 2, cause = "rien", opened_service = 1, opened_mine = 1 })
  S.note(acc, { n = 10, idle = 2, starved = 0, cause = "menace" })
  S.note(acc, { n = 10, idle = 0, cause = "rien" })
  check(acc.thinks == 3 and acc.n == 30 and acc.idle == 6 and acc.starved == 2, "§4 cumuls : pensées, PNJ-pensées, inactifs, affamés")
  check(acc.rien == 4 and acc.menace == 2 and (acc.bloque or 0) == 0, "§4 causes comptées en PNJ-pensées, aucune pour 0 inactif (" .. tostring(acc.rien) .. ")")
  local acc2 = {}
  S.note(acc2, { n = 10, idle = 1, cause = "bloque", kinds = { craft = 3, garrison = 1 } })
  S.note(acc2, { n = 10, idle = 0, cause = "rien", kinds = { craft = 9 } })
  check(acc2.kinds.craft == 3 and acc2.kinds.garrison == 1, "§4 genres des tâches libres comptés seulement quand un PNJ attend")
  check(S.kinds_text(acc2.kinds):find("craft 3, garrison 1", 1, true) ~= nil and S.kinds_text({}) == "", "§4 genres écrits triés")
  local many = {}
  for i, k in ipairs({ "zz", "aa", "mm", "bb", "kk", "qq", "dd", "xx", "cc", "pp", "ee", "yy" }) do many[k] = i end
  local list = S.kind_list(many)
  local sorted = true
  for i = 2, #list do if list[i - 1] > list[i] then sorted = false end end
  check(sorted and #list == 12, "§4 douze genres rendus dans l'ordre")
  S.done(acc, true)
  S.done(acc, false)
  S.done(acc, true)
  check(acc.done_ok == 2 and acc.done_fail == 1, "§4 fins de tâche de la file")
  local line = S.report_line("player", 18000, acc, true)
  check(line:find("^%[FO%-INACTIF%] player : bilan a 5%.0 min") ~= nil, "§4 ligne : [FO-INACTIF] et minute")
  check(line:find("inactifs 20%.0 %%") ~= nil and line:find("hors menace 14%.3 %%") ~= nil, "§4 inactifs 6 sur 30 = 20 % ; hors menace 4 sur 28 = 14,3 %")
  check(line:find("rien 4 %(rien 13%.3 %%%)") ~= nil and line:find("1 tournee%(s%) et 1 minage%(s%) ouverts, 2 finis, 1 en echec") ~= nil,
    "§4 cause rien et file sûre dans la ligne : " .. line)
  check(S.report_line("x", 0, {}, false):find("file sure eteinte") ~= nil, "§4 témoin : file sûre éteinte écrite")

  return pass, fail, msgs
end

local S0 = assert(load_mod(SRC))
local pass, fail, msgs = suite(S0)
for _, m in ipairs(msgs) do print("[TRAVAIL-SUR] ECHEC : " .. m) end

-- §5 Branchement.
do
  local P = read("script/team/poles.lua"):gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  local bad = {}
  for _, need in ipairs({
    -- (F544, PURGE-MINE 77c26cc8 : la file sûre ne mine plus : Sur.blocked, Sur.fail, Sur.success et le retrait des minages d'une plaque
    -- couverte, Sur.withdrawn(ia3, m[1], ...), ne sont plus branchés ; la ligne « mine » de board.lua ne distingue plus la file sûre)
    'require("shared.team.travail_sur")', "Sur.track(", "Sur.plan(", "Sur.cause(", "Sur.note(", "Sur.report_line(", "Sur.done(",
    "not view.hq_threat", "floor_ok = n >= floor0", "if #r.tasks > 0 then Board.add(f, r.tasks, tick) end", "function Poles.set_sur(",
    "org.sur_off", "not org.sur_off and Rsv.on()", "function Poles.sur_hold(f, tick)", "not (org.sur_hold and tick < org.sur_hold)", "function Poles.sur_stops(f)", "Sur.recall_n(", "Sur.withdrawn(ia3, spec and spec.product)",
  }) do
    if not P:find(need, 1, true) then bad[#bad + 1] = need end
  end
  -- Intégration 0.6.30 : un PNJ de la file reste un bras libre pour le cerveau ; les mesures gardent les PNJ vraiment sans tâche.
  local Tm = read("script/team/team.lua"):gsub("%-%-[^\n]*", "")
  for _, need in ipairs({ "if t.worker and t.safe then on_safe = on_safe + 1", "workers_idle = workers_idle + on_safe", "workers_waiting = workers_waiting",
    "not t.worker and not t.safe and", "view.workers_waiting or view.workers_idle or 0, orientation", 'Worker.abort(a, f, tick, "preempte")' }) do
    if not Tm:find(need, 1, true) then bad[#bad + 1] = need end
  end
  -- … et les autres lecteurs des PNJ libres et des minages ouverts aussi.
  for _, p in ipairs({ { "script/team/survie.lua", 'if t.kind == "mine" and t.resource and not t.safe then' },
    { "script/team/board.lua", "if not t.worker and not t.safe and Board.prenable(f, t) then n = n + 1 end" },
    { "script/ai3/exploration.lua", "Poles.sur_hold(f, game.tick)" }, { "script/ai3/exploration.lua", "a.task and a.task.safe then n = n + 1 end" } }) do
    if not read(p[1]):find(p[2], 1, true) then bad[#bad + 1] = p[2] end
  end
  local Sp = read("settings/industrie.lua"):gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
  if not Sp:find("default_value = true", 1, true) then bad[#bad + 1] = "fo-war-industrie allume par defaut" end
  local Mk = read("tests/mock_engine.lua")
  if not Mk:find('["fo-war-industrie"] = (opts.industrie ~= false)', 1, true) then bad[#bad + 1] = "moteur simule : reglage maitre comme le jeu" end
  local a_add = P:find("Board.add(f, add, tick)", 1, true)
  local a_sur = P:find("Sur.plan(", 1, true)
  if not (a_add and a_sur and a_add < a_sur) then bad[#bad + 1] = "la file passe APRES l'ouverture du fond" end
  if #bad == 0 then pass = pass + 1 else
    fail = fail + 1
    print("[TRAVAIL-SUR] ECHEC : §5 branchement incomplet : " .. table.concat(bad, " ; "))
  end
  local R = read("script/team/ia1_remote.lua")
  if R:find("set_sur = function", 1, true) and R:find("Poles.set_sur(", 1, true) then pass = pass + 1 else
    fail = fail + 1
    print("[TRAVAIL-SUR] ECHEC : §5 interface fo-ia1 sans set_sur")
  end
end

-- §6 Mutants.
local MUTANTS = {
  { "seuil d'affamé ignoré", "if n >= S.STARVE_THINKS then starved = starved + 1 elseif", "if true then starved = starved + 1 elseif" },
  { "suite comptée double", "local n = ((prev or {})[id] or 0) + 1", "local n = ((prev or {})[id] or 0) + 2" },
  { "menace sans cause", 'if threat then return "menace" end', "" },
  { "bloque jamais", 'if (free or 0) > 0 then return "bloque" end', "" },
  { "frais ignorés", "(ctx.starved or 0) + fresh - (ctx.open or 0)", "(ctx.starved or 0) - (ctx.open or 0)" },
  { "fond de la pensée non déduit des frais", "local fresh = math.max(0, (ctx.fresh or 0) - #(ctx.also or {}))",
    "local fresh = math.max(0, (ctx.fresh or 0))" },
  { "frais comptés comme affamés", "elseif n == 1 then fresh = fresh + 1 end", "elseif n == 1 then fresh = fresh + 0 end" },
  { "ouvertes non déduites", "(ctx.starved or 0) + fresh - (ctx.open or 0)", "(ctx.starved or 0) + fresh" },
  { "menace ignorée", "if want == 0 or ctx.threat or ctx.prudent or ctx.floor_ok == false then return r end",
    "if want == 0 or ctx.prudent or ctx.floor_ok == false then return r end" },
  { "prudence ignorée", "if want == 0 or ctx.threat or ctx.prudent or ctx.floor_ok == false then return r end",
    "if want == 0 or ctx.threat or ctx.floor_ok == false then return r end" },
  { "équipe décimée servie", "if want == 0 or ctx.threat or ctx.prudent or ctx.floor_ok == false then return r end",
    "if want == 0 or ctx.threat or ctx.prudent then return r end" },
  { "avant-poste dangereux servi", "and not o.danger and not o.undefended", "and not o.undefended" },
  { "avant-poste non défendu servi", "and not o.danger and not o.undefended", "and not o.danger" },
  { "avant-poste déjà servi doublé", "and not o.has_task", "" },
  { "avant-poste lointain servi", "(ctx.near_d2 == nil or (o.d2 or 0) <= ctx.near_d2)", "true" },
  { "reste vide servi", "(o.output or 0) >= S.SERVICE_MIN", "true" },
  { "tournée sans tri du plus gros reste", "if (a.output or 0) ~= (b.output or 0) then return (a.output or 0) > (b.output or 0) end", "" },
  { "borne des tournées ignorée", "if r.left == 0 then break end", "" },
  { "minage d'une ressource non permise", "if m.ok then list[#list + 1]", "if true then list[#list + 1]" },
  { "ressource la moins en manque d'abord", "if a.gap ~= b.gap then return a.gap > b.gap end", "if a.gap ~= b.gap then return a.gap < b.gap end" },
  { "minage sans tour de rôle", "local m = list[k % #list + 1]", "local m = list[1]" },
  { "clés du tableau ignorées (minage)", "until (not keys[S.KEY_PREFIX", "until (true or not keys[S.KEY_PREFIX" },
  { "clés ouvertes dans la pensée ignorées", "for _, t in ipairs(ctx.also or {}) do taken[t.key] = true end", "" },
  { "tâche de la file sans marque sûre", "radius = ctx.radius, fond = true, safe = true", "radius = ctx.radius, fond = true" },
  { "tâche de la file hors du fond", "radius = ctx.radius, fond = true, safe = true", "radius = ctx.radius, safe = true" },
  { "priorité au-dessus du fond", "S.PRIO = 10 ", "S.PRIO = 30 " },
  { "tâche payée au coffre", 'safe = true, domain = "gisements" }\n    r.service', 'safe = true, domain = "gisements", items = { { "x", 1 } } }\n    r.service' },
  { "rayon de minage perdu", "radius = ctx.radius,", "" },
  { "genres comptés sans attente", "if (a.idle or 0) > 0 and a.kinds then", "if a.kinds then" },
  { "genres non triés", "  table.sort(out)", "" },
  { "rappel compté comme échec", "fuite = true, preempte = true }", "fuite = true }" },
  { "rappel sans déduire les PNJ libres", "local n = math.max(0, (urgent or 0) - (free or 0))", "local n = math.max(0, (urgent or 0))" },
  { "aller-retour à chaque pensée", "(since or 0) >= S.RECALL_EVERY and", "" },
  { "travail ordinaire jamais rappelé", "if n == 0 and (since or 0) >= S.RECALL_EVERY and (wanted or 0) > (free or 0) then n = 1 end", "" },
  { "saturée retirée sans autre manque", "if st.other_short ~= false and st.saturated", "if st.saturated" },
  { "plaque couverte ignorée", "or (fondu ~= nil and cov[fondu] == true))", ")" },
  { "échec sans doublement", "b.k = math.min(S.BACKOFF_MAX, b.k + 1)", "b.k = 1" },
  { "doublements sans borne", "b.k = math.min(S.BACKOFF_MAX, b.k + 1)", "b.k = b.k + 1" },
  { "refus passager écarté", "if S.TRANSIENT[why or \"\"] then return end", "" },
  { "écart sans fin", "return b ~= nil and tick < b.till", "return b ~= nil" },
  { "réussite sans effacement", "bad[res] = nil", "" },
  { "causes non comptées", "if (a.idle or 0) > 0 and a.cause then acc[a.cause] = (acc[a.cause] or 0) + a.idle end", "" },
  { "fins de tâche non comptées", "if ok then acc.done_ok = (acc.done_ok or 0) + 1 else acc.done_fail = (acc.done_fail or 0) + 1 end", "" },
  { "inactivité hors menace comptée avec la menace", "local hors = math.max(0, (acc.idle or 0) - menace)", "local hors = acc.idle or 0" },
}
local refused, kept = 0, {}
for _, m in ipairs(MUTANTS) do
  local a, b = SRC:find(m[2], 1, true)
  if not a then kept[#kept + 1] = m[1] .. " (motif absent)" else
    local mod = load_mod(SRC:sub(1, a - 1) .. m[3] .. SRC:sub(b + 1))
    local seen_fail = true
    if mod then
      local ok, _, f2 = pcall(suite, mod)
      seen_fail = (not ok) or (f2 or 0) > 0
    end
    if seen_fail then refused = refused + 1 else kept[#kept + 1] = m[1] end
  end
end
if #kept == 0 then pass = pass + 1 else
  fail = fail + 1
  print("[TRAVAIL-SUR] ECHEC : mutants NON refusés : " .. table.concat(kept, " ; "))
end
print(string.format("[TRAVAIL-SUR] mutants refusés : %d sur %d", refused, #MUTANTS))
print(string.format("[TRAVAIL-SUR] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
