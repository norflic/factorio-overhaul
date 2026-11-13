--[[
  Lot L12, partie 3 : MENACE TENUE d'une équipe (état séparé f.threat_held, rendu dans la vue sous view.threat_held), lue SEULEMENT par
  la décision de capitalisation ; f.threatened_until et view.threatened ne changent pas. Test hors jeu de shared/team/menace_equipe.lua
  (règle pure) et de script/team/menace_equipe.lua (runtime, au moteur simulé). Lancer depuis la racine du mod (git requis, §3) :
    lua5.2 tests/menace_equipe_test.lua   -> [L12C] BILAN : N OK, 0 ECHEC(S)
  §1 règle pure ; §2 runtime au moteur simulé (perte, puis menace tenue tant que les tourelles sont vides ; plafond ; f.threatened_until
  jamais écrit) ; §2 bis appel réel (partie de 2 factions : décisions de capitalisation sous menace tenue) ; §3 câblage, et git grep :
  aucun autre lecteur de threat_held ; §4 mutants ; §5 coût (debug.sethook).
]]
package.path = "./?.lua;" .. package.path
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L12C] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local P = 300 -- ticks entre deux pensées d'équipe (think_period)

-- Joue des pensées de t0 à t1 (pas P) ; losses = { [tick de pensée] = tick de la perte } ; armed(t) ; rend la liste des (tick, menace, ev, cause).
local function play(Me, t1, losses, armed)
  local st, out, loss_t = Me.new(), {}, nil
  for t = 0, t1, P do
    if losses[t] then loss_t = losses[t] end
    local on, ev, cause = Me.update(st, { tick = t, loss_t = loss_t, armed = armed(t) })
    out[#out + 1] = { t = t, on = on, ev = ev, cause = cause }
  end
  return out, st
end
local function first_off(out, from)
  for _, r in ipairs(out) do if r.t >= (from or 0) and not r.on then return r end end
  return nil
end
local function never() return false end
local function always() return true end

local function suite(Me)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  -- 1. QG défendu : perte à 0 ; menace jusqu'à 2 pensées calmes après la fenêtre de 900 ticks (sortie à 1 200 : 20 s)
  local d = play(Me, 3000, { [0] = 0 }, always)
  local off = first_off(d, 0)
  want(d[1].on and d[1].ev == "entree" and d[1].cause == "perte", "defendu : entree a la perte")
  want(off and off.t == 1200 and off.ev == "sortie" and off.cause == "calme + tourelles", "defendu : sortie « calme + tourelles » a 1 200 (" .. tostring(off and off.t) .. ")")
  -- 2. QG sans tourelle armée : menace tenue jusqu'au plafond (18 000 ticks après la dernière perte), cause « plafond »
  local u = play(Me, 24000, { [0] = 0 }, never)
  local offu = first_off(u, 0)
  want(offu and offu.t == 18000 and offu.cause == "plafond", "sans tourelle : sortie par le plafond a 18 000 (" .. tostring(offu and offu.t) .. ", " .. tostring(offu and offu.cause) .. ")")
  local held = 0
  for _, r in ipairs(u) do if r.t < 18000 and r.on then held = held + 1 end end
  want(held == 60, "sans tourelle : 60 pensees de menace d'affilee (" .. held .. ")")
  -- 3. nouvelle perte pendant la menace : événement, et le plafond repart de cette perte
  local n = play(Me, 30000, { [0] = 0, [6000] = 5950 }, never)
  local seen = false
  for _, r in ipairs(n) do if r.ev == "perte" and r.cause == "nouvelle perte" and r.t == 6000 then seen = true end end
  local offn = first_off(n, 0)
  want(seen, "nouvelle perte pendant la menace : evenement « nouvelle perte »")
  want(offn and offn.t == 24000 and offn.cause == "plafond", "plafond compte depuis la DERNIERE perte (5 950 + 18 000 -> 24 000) (" .. tostring(offn and offn.t) .. ")")
  -- 4. attaque qui dure (une perte toutes les 2 min pendant 10 min) sans tourelle : jamais de sortie pendant l'attaque
  local losses = {}
  for t = 0, 36000, 7200 do losses[t] = t end
  local a = play(Me, 36000 + 18000, losses, never)
  local offa = first_off(a, 0)
  want(offa and offa.t == 36000 + 18000, "attaque qui dure : menace tenue jusqu'au plafond apres la derniere perte (" .. tostring(offa and offa.t) .. ")")
  -- 5. tourelles qui se vident pendant le calme : la sortie attend (les 2 pensées calmes doivent être défendues)
  local function armed_until(t) return t < 900 end
  local v = play(Me, 3000, { [0] = 0 }, armed_until)
  want(first_off(v, 0) == nil, "tourelles videes pendant le calme : menace tenue")
  -- 6. aucune perte : jamais de menace ; perte ancienne (plus de 900 ticks) vue tard : pas d'entrée
  local z = play(Me, 3000, {}, always)
  want(not z[1].on and first_off(z, 0).t == 0, "aucune perte : jamais menace")
  local st = Me.new()
  local on = Me.update(st, { tick = 5000, loss_t = 3000, armed = false })
  want(not on, "perte de plus de 900 ticks vue a la premiere pensee : pas d'entree")
  return bad
end

local Me = require("shared.team.menace_equipe")
local bad = suite(Me)
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "§1 suite de la regle pure")
check(Me.THREAT_TICKS == require("shared.team.defchoix").THREAT_TICKS and Me.THREAT_TICKS == 900, "§1 fenetre d'une perte lue dans defchoix (900)")
print(string.format("[L12C] §1 sortie : QG defendu a %d ticks apres la perte (avant : 900) ; sans tourelle armee a %d (avant : 900)", 1200, 18000))

-- §2 Moteur simulé : le runtime (script/team/menace_equipe.lua). Il n'écrit JAMAIS f.threatened_until (ses 16 lecteurs : inchangés).
local M = require("tests.mock_engine")
M.new_world({ p_busy = 0, p_nopath = 0, p_lost = 0 })
local W = M.world()
local QG = { armed = 0, ammo = 0 }
local NOW = 0
local PREV_STUB = { qg_view = function() return { qg = { tick = NOW, armed = QG.armed, ammo = QG.ammo } } end }
package.loaded["script.ai3.prevision"] = PREV_STUB
local MenaceEq = require("script.team.menace_equipe")
-- Pensées de 0 à t1 ; une perte près du QG fait ce que font commander.lua:229 et sa ligne de ce lot. Rend les ticks de menace TENUE, les
-- ticks de la menace d'AVANT (fenêtre de 15 s de f.threatened_until, relue aux pensées) et le nombre d'écritures de f.threatened_until par
-- le runtime.
local function sim(f, t1, loss_ticks, armed_at, observe)
  observe = observe or MenaceEq.observe
  local held, old, writes, li = 0, 0, 0, 1
  for t = 0, t1, P do
    NOW = t
    while loss_ticks[li] and loss_ticks[li] <= t do
      f.threatened_until = loss_ticks[li] + 900
      f.threat_loss_t = loss_ticks[li]
      li = li + 1
    end
    local a = armed_at(t)
    QG.armed, QG.ammo = a and 1 or 0, a and 10 or 0
    local before = f.threatened_until
    if observe(f, t) then held = held + P end
    if f.threatened_until ~= before then writes = writes + 1 end
    if t < (f.threatened_until or 0) then old = old + P end
  end
  return held, old, writes
end
do
  local f = { key = "f1", team = {} }
  local held, old, writes = sim(f, 30000, { 100 }, never)
  print(string.format("[L12C] §2 sans tourelle armee : menace TENUE %d ticks ; menace d'avant (f.threatened_until) %d ticks, inchangee ; "
    .. "f.threatened_until ecrit %d fois par le runtime", held, old, writes))
  check(writes == 0, "§2 le runtime n'ecrit jamais f.threatened_until (" .. writes .. ")")
  check(held >= 18000 and held <= 18300, "§2 sans tourelle : menace tenue jusqu'au plafond (" .. held .. " ticks)")
  check(old <= 900 and f.threatened_until == 100 + 900, "§2 menace d'avant inchangee : 15 s apres la perte (" .. old .. " ticks, fin " .. tostring(f.threatened_until) .. ")")
  check(f.threat_held and f.threat_held.crise == false, "§2 etat f.threat_held ; menace levee par le plafond")
  local keys = {}
  for k in pairs(f) do keys[#keys + 1] = k end
  table.sort(keys)
  check(table.concat(keys, ",") == "key,team,threat_held,threat_loss_t,threatened_until" and next(f.team) == nil,
    "§2 le runtime n'ecrit que f.threat_held (" .. table.concat(keys, ",") .. ")")
  local f2 = { key = "f2", team = {} }
  local held2, _, writes2 = sim(f2, 6000, { 100 }, always)
  print(string.format("[L12C] §2 QG defendu : menace tenue %d ticks (avant : 900)", held2))
  check(writes2 == 0 and held2 >= 900 and held2 <= 1500, "§2 QG defendu : tenue de 900 a 1 500 ticks (" .. held2 .. "), f.threatened_until non ecrit")
  local nlog, causes = 0, {}
  for _, l in ipairs(W.logs or {}) do
    if l:find("[FO-MENACE]", 1, true) then
      nlog = nlog + 1
      if l:find("plafond", 1, true) then causes.plafond = true end
      if l:find("calme + tourelles", 1, true) then causes.calme = true end
    end
  end
  check(nlog == 4 and causes.plafond and causes.calme, "§2 journal [FO-MENACE] : entree et sortie de chaque cas, causes ecrites (" .. nlog .. ")")
  check(M.serialize(f.threat_held) ~= nil, "§2 etat serialisable")
end

-- §2 bis APPEL RÉEL : une partie de 2 factions (capitalisation branchée, comme tests/portes_paliers_moteur_test.lua). À 5 min, une perte
-- au QG de la faction 1 (ce que font commander.lua:229 et la ligne de ce lot), QG sans tourelle armée ; puis 4 min. Chaque décision de
-- capitalisation (Ca.decide_begin, entrée réelle de build_input) est relevée : la faction 1 décide sous menace au-delà des 15 s de
-- f.threatened_until, la faction 2 jamais. `cap_src` (mutant du §4) : source de script/ai3/capitalisation.lua chargée à la place du fichier.
local function partie(cap_src)
  local function patches()
    local out = {}
    local d = 0.7071
    local dirs = { { 1, 0 }, { 0.866, 0.5 }, { 0.5, 0.866 }, { 0, 1 }, { -0.5, 0.866 }, { -0.866, 0.5 },
      { -1, 0 }, { -0.866, -0.5 }, { -0.5, -0.866 }, { 0, -1 }, { 0.5, -0.866 }, { 0.866, -0.5 } }
    for _, c in ipairs({ { d, -d }, { d, d }, { -d, d }, { -d, -d } }) do
      local hx, hy = c[1] * 320, c[2] * 320
      local names = { "coal", "iron-ore", "copper-ore", "stone" }
      for ri, r in ipairs({ 40, 64, 88 }) do
        for di, v in ipairs(dirs) do out[#out + 1] = { x = hx + v[1] * r, y = hy + v[2] * r, name = names[(ri + di) % 4 + 1] } end
      end
    end
    return out
  end
  package.loaded["script.ai3.prevision"] = nil
  package.preload["script.ai3.capitalisation"] = cap_src and function() return assert(load(cap_src, "=capitalisation_mutant", "t", _ENV))() end or nil
  M.new_world({ patches = patches(), p_busy = 0, p_nopath = 0, p_lost = 0, difficulty = "peaceful", ia3e = true, capi = true })
  local W2 = M.world()
  M.load_mod()
  package.preload["script.ai3.capitalisation"] = nil
  M.dispatch(W2.on_init)
  local Ca = package.loaded["shared.ai3.capitalisation"]
  local calls = {}
  local orig_begin = Ca.decide_begin
  Ca.decide_begin = function(input, st)
    calls[#calls + 1] = { tick = game.tick, threat = input.threat and true or false, traits = M.serialize(input.traits or {}) }
    return orig_begin(input, st)
  end
  M.command("fo-war", "start 2 30 30 320")
  local r = {}
  local ok1, err1 = pcall(M.run_ticks, 5 * 3600)
  local f1, f2 = global.fo.war.factions[1], global.fo.war.factions[2]
  r.t1s, r.t2s = M.serialize(f1.traits or {}), M.serialize(f2.traits or {})
  local Prev = package.loaded["script.ai3.prevision"]
  local nat = Prev.qg_view(f1)
  r.nat_armed = (nat and nat.qg and ((nat.qg.armed or 0) > 0 or (nat.qg.ammo or 0) > 0)) and true or false
  if r.nat_armed then -- QG de la faction 1 sans tourelle armée (forcé pour elle seule ; sans cela, sortie à 20 s, cas du §2)
    local orig_q = Prev.qg_view
    Prev.qg_view = function(f)
      local v = orig_q(f)
      if f == f1 and v and v.qg then return { waves = v.waves, qg = { tick = v.qg.tick, armed = 0, ammo = 0 } } end
      return v
    end
  end
  local t_loss = game.tick
  f1.threatened_until, f1.threat_loss_t = t_loss + 900, t_loss
  local n0, c0 = #W2.logs, #calls
  local ok2, err2 = pcall(M.run_ticks, 4 * 3600)
  r.ok, r.err = ok1 and ok2, err1 or err2
  r.pre1, r.post1, r.held1, r.post2 = 0, 0, 0, 0
  for i, c in ipairs(calls) do
    if i <= c0 then
      if c.threat then r.pre1 = r.pre1 + 1 end
    elseif c.traits == r.t1s then
      r.post1 = r.post1 + 1
      if c.threat and c.tick >= t_loss + 900 then r.held1 = r.held1 + 1 end
    elseif c.traits == r.t2s and c.threat then
      r.post2 = r.post2 + 1
    end
  end
  r.entree1, r.menace2 = 0, 0
  for i = n0 + 1, #W2.logs do
    local l = W2.logs[i]
    if l:find("[FO-MENACE] " .. tostring(f1.key) .. " : MENACE TENUE", 1, true) then r.entree1 = r.entree1 + 1 end
    if l:find("[FO-MENACE] " .. tostring(f2.key), 1, true) then r.menace2 = r.menace2 + 1 end
  end
  r.held_on = f1.threat_held and f1.threat_held.crise == true
  r.old_ok = game.tick > (f1.threatened_until or 0) and f1.threatened_until == t_loss + 900
  Ca.decide_begin = orig_begin
  return r
end
do
  local r = partie(nil)
  print(string.format("[L12C] §2 bis partie reelle : QG de la faction 1 %s ; %d decision(s) avant la perte sous menace ; apres : faction 1 %d decision(s), "
    .. "%d sous menace TENUE au-dela des 15 s ; faction 2 %d sous menace", r.nat_armed and "arme (tourelles forcees vides)" or "sans tourelle armee",
    r.pre1, r.post1, r.held1, r.post2))
  check(r.ok, "§2 bis partie sans erreur (" .. tostring(r.err) .. ")")
  check(r.t1s ~= r.t2s, "§2 bis decisions attribuees aux factions (caracteres distincts)")
  check(r.pre1 == 0, "§2 bis temoin : aucune decision sous menace avant la perte (" .. r.pre1 .. ")")
  check(r.entree1 == 1 and r.held_on, "§2 bis [FO-MENACE] « MENACE TENUE » chez la faction 1, toujours tenue 4 min apres")
  check(r.post1 >= 3 and r.held1 >= 2, "§2 bis la decision de capitalisation de la faction 1 lit la menace tenue (" .. r.held1 .. " sur " .. r.post1 .. " decision(s))")
  check(r.post2 == 0 and r.menace2 == 0, "§2 bis faction 2 sans perte : aucune decision sous menace, aucune ligne [FO-MENACE] (" .. r.post2 .. ", " .. r.menace2 .. ")")
  check(r.old_ok, "§2 bis f.threatened_until d'avant inchange (fin 15 s apres la perte)")
end

-- §3 câblage ; et AUCUN autre lecteur de threat_held (git grep sur tout le Lua du dépôt, suivi ou non, tests exceptés).
do
  local cm = read("script/faction/commander.lua"):gsub("%-%-[^\n]*", "")
  local a = cm:find("f.threatened_until = e.tick + THREAT_TICKS", 1, true)
  local b = cm:find("f.threat_loss_t = e.tick", 1, true)
  check(a and b and b > a and b - a < 80, "§3 commander.lua : f.threat_loss_t pose juste apres f.threatened_until (perte pres du QG)")
  local tm = read("script/team/team.lua"):gsub("%-%-[^\n]*", "")
  -- Lot UPS : l'appel passe par Profiler.fwrap (portée fine « view:5-menace », mesure seulement : fwrap rend le résultat de l'appel).
  check(tm:find("threat_held = Profiler.fwrap(\"view:5-menace\", MenaceEq.observe, f, tick) or nil,", 1, true) ~= nil, "§3 team.lua : view.threat_held rendu par MenaceEq.observe")
  check(tm:find("local threatened = tick < (f.threatened_until or 0)", 1, true) ~= nil, "§3 team.lua : view.threatened d'avant inchange")
  check(tm:find('local MenaceEq = require("script.team.menace_equipe")', 1, true) ~= nil, "§3 require en tete de team.lua (F24)")
  local cap = read("script/ai3/capitalisation.lua"):gsub("%-%-[^\n]*", "")
  local p1 = cap:find("if threat and R.PILE_BUDGET and Pi.threat_open(st.pile) then threat = false end", 1, true)
  -- 0.6.66 (lot BLOCAGE-SORTIE-2, 1fd11a07) : le bloc tenait sur UNE ligne ; il en compte quatre depuis que la raison de fermeture
  -- (threat_why, journal du puits ferme) y est posee. Meme regle (la menace tenue ferme, APRES Pi.threat_open) : le motif suit la forme multiligne.
  local p2 = cap:find("if not threat and view%.threat_held then%s+threat = %(Sv%.capi%(")
  check(p1 and p2 and p2 > p1, "§3 capitalisation : la menace tenue ferme les gisements, APRES Pi.threat_open")
end
local ALLOWED = { ["script/team/team.lua"] = true, ["script/ai3/capitalisation.lua"] = true, ["script/team/menace_equipe.lua"] = true,
  ["shared/team/menace_equipe.lua"] = true }
-- Lot TESTS-GIT (0.6.64) : lignes lues par tests/depot.lua (tous les .lua suivis ou non suivis non ignorés, comme
-- git grep --untracked ; sans git, le disque, annoncé par une ligne [ENVIRONNEMENT]). Avant : sans git, 0 ligne, et les deux contrôles
-- échouaient sans dire pourquoi (« 0 ligne(s) », « 0 fichier(s) »).
local Depot = require("tests.depot")
local function grep_lua(word)
  local out = {}
  local lines, _, nfiles, source = Depot.grep(word, { "." }, { untracked = true })
  if source == "disque" then Depot.env("§3 lecteurs de threat_held et témoin threatened (git grep)", nfiles > 0) end
  for _, l in ipairs(lines) do if not l:find("^tests/") then out[#out + 1] = l end end
  return out
end
local function foreign(lines)
  local bad = {}
  for _, l in ipairs(lines) do
    local file = l:match("^([^:]+):")
    if file and not ALLOWED[file] then bad[#bad + 1] = l end
  end
  return bad
end
do
  local lines = grep_lua("threat_held")
  local bad = foreign(lines)
  check(#lines >= 3 and #bad == 0, "§3 threat_held lu SEULEMENT par la capitalisation (" .. #lines .. " ligne(s) ; hors liste : " .. table.concat(bad, " | ") .. ")")
  local files = {}
  for _, l in ipairs(foreign(grep_lua("threatened"))) do files[l:match("^([^:]+):")] = true end
  local nf = 0
  for _ in pairs(files) do nf = nf + 1 end
  check(nf >= 10, "§3 temoin : la meme commande trouve les lecteurs de threatened hors de la liste (" .. nf .. " fichier(s))")
end

-- §4 mutants
local SRC = read("shared/team/menace_equipe.lua")
local MUT = {
  { "plafond ignore", "local capped = st.crise and since ~= nil and since >= Me.CAP_TICKS", "local capped = false" },
  { "tourelles non lues", "elseif not a.armed then lvl = 1 end", "end" },
  { "sortie a la 1re pensee calme", "Me.CALM_THINKS = 2      ", "Me.CALM_THINKS = 1      " },
  { "nouvelle perte non vue", "local new_loss = a.loss_t ~= nil and a.loss_t ~= st.loss_t", "local new_loss = false" },
  { "perte ancienne qui ouvre la menace", "local recent = since ~= nil and since < Me.THREAT_TICKS", "local recent = since ~= nil" },
  { "plafond a l'entree (depuis la 1re perte)", "if a.loss_t ~= nil then st.loss_t = a.loss_t end", "if a.loss_t ~= nil and st.loss_t == nil then st.loss_t = a.loss_t end" },
}
local refused = 0
for _, m in ipairs(MUT) do
  local s2, nsub = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if nsub ~= 1 then
    check(false, "§4 mutant introuvable (" .. nsub .. ") : " .. m[1])
  else
    local ok, Mm = pcall(function() return assert(load(s2, "=menace_equipe", "t", _ENV))() end)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Mm) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if killed then refused = refused + 1 else print("[L12C] mutant NON refuse : " .. m[1]) end
    check(killed, "§4 mutant refuse : " .. m[1])
  end
end
do -- mutant du runtime : la menace tenue écrite dans f.threatened_until (ses 16 lecteurs la verraient)
  package.loaded["script.ai3.prevision"] = PREV_STUB
  local RS = read("script/team/menace_equipe.lua")
  local s2, nsub = RS:gsub(("  return on\nend"):gsub("%p", "%%%0"), "  if on then f.threatened_until = tick + 900 end\n  return on\nend")
  local killed = false
  if nsub == 1 then
    local Rm = assert(load(s2, "=menace_equipe_rt", "t", _ENV))()
    local _, _, writes = sim({ key = "m", team = {} }, 6000, { 100 }, never, Rm.observe)
    killed = writes > 0
  end
  if killed then refused = refused + 1 end
  check(nsub == 1 and killed, "§4 mutant du runtime refuse : menace tenue ecrite dans f.threatened_until")
end
do -- mutant « un autre lecteur lit threat_held » : une ligne de plus dans la sortie du git grep du §3
  local seen = #foreign({ "script/team/poles.lua:503:  if view.threat_held then" }) == 1
  if seen then refused = refused + 1 end
  check(seen, "§4 mutant refuse : un autre lecteur lit threat_held (git grep du §3)")
end
do -- mutant « la capitalisation ne lit pas la menace tenue » : la ligne de build_input retirée, la partie réelle du §2 bis rejouée
  local CS = read("script/ai3/capitalisation.lua")
  -- 0.6.66 (lot BLOCAGE-SORTIE-2) : le bloc fait quatre lignes (if ... threat = ... threat_why ... end) ; le mutant retire le bloc ENTIER.
  local i = CS:find("  if not threat and view.threat_held then\n    threat = (Sv.capi(", 1, true)
  local killed, r = false, nil
  if i then
    local _, k = CS:find("\n  end\n", i, true)
    r = partie(CS:sub(1, i - 1) .. CS:sub(k + 1))
    killed = r.ok and r.held1 < 2
  end
  if killed then refused = refused + 1 end
  check(killed, "§4 mutant refuse : la capitalisation ne lit pas view.threat_held (partie reelle : " .. tostring(r and r.held1) .. " decision(s) sous menace tenue, "
    .. tostring(r and r.err) .. ")")
end
print(string.format("[L12C] §4 mutants refuses : %d sur %d", refused, #MUT + 3))

-- §5 coût
local worst, st5, k = 0, Me.new(), 0
for _ = 1, 200 do
  k = k + 1
  local c = 0
  debug.sethook(function() c = c + 1 end, "", 1)
  Me.update(st5, { tick = k * P, loss_t = (k % 20 == 0) and k * P or st5.loss_t, armed = k % 3 ~= 0 })
  debug.sethook()
  if c > worst then worst = c end
end
print(string.format("[L12C] §5 cout : Me.update pire %d instructions par pensee (sethook, compte de 1)", worst))
check(worst <= 250, "§5 cout borne : 250 instructions par pensee (" .. worst .. ")")

print(string.format("[L12C] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
