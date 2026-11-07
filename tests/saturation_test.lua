--[[
  Lot VIDEO-SAT (rang 12 de docs/TODO_VIDEO.md §I, V79 « un stock qui masque un manque de capacité ») : banc HORS JEU de
  shared/ai3/saturation.lua et du correctif de B.saturated (shared/ai3/buts.lua). Lancement, depuis la racine du mod :
    lua5.2 tests/saturation_test.lua
  Sections :
     1. relevés : période, premier relevé, pente par minute à intervalle irrégulier ;
     2. moyenne des pentes : exacte sur les Sa.WINDOW premières, glissante ensuite ;
     3. fonte durable : échauffement, bruit, stock qui monte, fonte régulière ;
     4. dépense isolée : son poids, sa durée, la saturation d'un gros stock tient ;
     5. stock illisible, objet absent, objet hors de la liste ;
     6. Sa.holds : seuil, projection, raisons ;
     7. B.saturated SANS mesure : identique à la règle d'avant (2 000 situations) ;
     8. B.saturated AVEC mesure : levée par la pente, tenue pour une fonte minime d'un gros stock ;
     9. lecteurs de B.saturated : vague des bras libres (B.targets), reconstruction (B.generate), relève (B.releve) ;
    10. scène V79 : stock qui fond, saturation levée 13 min plus tôt ; stock immense et stock qui monte : inchangés ;
    11. déterminisme ;
    12. coût en INSTRUCTIONS (debug.sethook, jamais os.clock) ;
    13. mutants : chaque règle retirée fait échouer au moins un contrôle.
  Les objets sont des clés opaques ou lues dans shared/team/config.lua (aucun nom du jeu écrit ici).
]]
package.path = "./?.lua;" .. package.path

local passes, failures = 0, 0
local quiet = false
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1; if not quiet then print("  ECHEC : " .. msg) end end
  return cond
end
local function section(name) if not quiet then print("== " .. name) end end
local function slurp(p) local f = assert(io.open(p, "rb")) local x = f:read("*a") f:close() return x end
local function near(a, b, eps) return a ~= nil and b ~= nil and math.abs(a - b) <= (eps or 1e-9) end

local SA_PATH, B_PATH = "shared/ai3/saturation.lua", "shared/ai3/buts.lua"
local function load_src(path, mutate)
  local src = slurp(path)
  if mutate then
    local i, j = src:find(mutate[1], 1, true)
    if not i then return nil, "texte introuvable : " .. mutate[1] end
    src = src:sub(1, i - 1) .. mutate[2] .. src:sub(j + 1)
  end
  local fn, err = load(src, "@" .. path)
  if not fn then return nil, err end
  return fn()
end
--- Charge (Sa, B) ; `which` = "sa" ou "b" : fichier muté. B est rechargé sur le Sa donné (package.loaded).
local function load_pair(which, mutate)
  local Sa, err = load_src(SA_PATH, which == "sa" and mutate or nil)
  if not Sa then return nil, nil, err end
  package.loaded["shared.ai3.saturation"] = Sa
  local B, err2 = load_src(B_PATH, which == "b" and mutate or nil)
  if not B then return nil, nil, err2 end
  return Sa, B
end

local T = require("shared.team.config")
local Dm = require("shared.ai3.demande")
local Br = require("shared.ai3.bras")
local MIN = 3600

--- La règle d'avant (buts.lua avant VIDEO-SAT), recopiée : témoin de l'équivalence sans mesure.
local function old_saturated(s, item, floor_only, B)
  local need = Dm.sat_need(Br.need_floor(s.workers, B.NEED_FLOOR), s.need and s.need[item],
    (not floor_only) and s.puits_flow and s.puits_flow[item] or nil)
  return (s.stock[item] or 0) >= B.SAT_FACTOR * need
end

--- Série de stocks relevés minute par minute ; rend l'état et la liste des fontes après chaque relevé.
local function series(Sa, stocks, item)
  local st = Sa.new()
  local drains = {}
  for i, v in ipairs(stocks) do
    Sa.observe(st, (i - 1) * MIN, { [item] = v }, { item })
    drains[i] = Sa.drain(st, item)
  end
  return st, drains
end

local function run_all(Sa, B)
  local W = Sa.WINDOW

  -- 1. Relevés.
  section("1. releves : periode, premier releve, pente par minute")
  do
    local st = Sa.new()
    check(Sa.observe(st, 0, { a = 1000 }, { "a" }) == true, "1 : premier releve pris")
    check(st.items.a and st.items.a.n == 0 and st.items.a.m == 0, "1 : premier releve sans pente")
    check(Sa.observe(st, MIN - 1, { a = 900 }, { "a" }) == false, "1 : releve avant Sa.PERIOD ignore")
    check(st.items.a.s == 1000, "1 : un releve ignore ne change rien")
    check(Sa.observe(st, MIN, { a = 900 }, { "a" }) == true and near(st.items.a.m, -100) and st.items.a.n == 1,
      "1 : pente -100 par minute")
    -- Intervalle de 1,5 min : -150 objets en 5 400 ticks = -100 par minute.
    check(Sa.observe(st, MIN + 5400, { a = 750 }, { "a" }) == true and near(st.items.a.m, -100), "1 : pente a intervalle irregulier")
    check(Sa.observe(st, nil, { a = 1 }, { "a" }) == false, "1 : tick absent : aucun releve")
  end

  -- 2. Moyenne.
  section("2. moyenne : exacte sur les WINDOW premieres pentes, glissante ensuite")
  do
    local stocks, v = { 10000 }, 10000
    local slopes = {}
    for i = 1, W do slopes[i] = -50 * i v = v + slopes[i] stocks[#stocks + 1] = v end
    local st = series(Sa, stocks, "a")
    local sum = 0
    for i = 1, W do sum = sum + slopes[i] end
    check(near(st.items.a.m, sum / W, 1e-6), "2 : moyenne exacte des " .. W .. " premieres pentes (" .. tostring(st.items.a.m) .. ")")
    local m0 = st.items.a.m
    Sa.observe(st, (#stocks) * MIN, { a = v + 300 }, { "a" })
    check(near(st.items.a.m, m0 + (300 - m0) / W, 1e-6), "2 : pente suivante au poids 1 / WINDOW")
  end

  -- 3. Fonte durable.
  section("3. fonte durable : echauffement, bruit, hausse, fonte reguliere")
  do
    local stocks = {}
    for i = 0, W + 2 do stocks[#stocks + 1] = 5000 - 200 * i end
    local _, d = series(Sa, stocks, "a")
    check(d[W] == nil, "3 : moins de WINDOW pentes : aucune fonte (" .. tostring(d[W]) .. ")")
    check(near(d[W + 1], 200), "3 : WINDOW pentes de -200 : fonte de 200 par minute (" .. tostring(d[W + 1]) .. ")")
    local noise = {}
    for i = 0, W + 2 do noise[#noise + 1] = 5000 - 1 * i end
    local _, dn = series(Sa, noise, "a")
    check(dn[W + 3] == nil, "3 : -1 par minute : du bruit, aucune fonte")
    local edge = {}
    for i = 0, W + 2 do edge[#edge + 1] = 5000 - Sa.MIN_RATE * i end
    local _, de = series(Sa, edge, "a")
    check(near(de[W + 3], Sa.MIN_RATE), "3 : -MIN_RATE par minute : fonte (borne comprise)")
    local up = {}
    for i = 0, W + 2 do up[#up + 1] = 5000 + 300 * i end
    local _, du = series(Sa, up, "a")
    check(du[W + 3] == nil, "3 : stock qui monte : aucune fonte")
  end

  -- 4. Dépense isolée.
  section("4. depense isolee : poids 1 / WINDOW, duree, gros stock")
  do
    local stocks = { 10000, 7200 }
    for i = 1, 30 do stocks[#stocks + 1] = stocks[#stocks] + 200 end
    local _, d = series(Sa, stocks, "a")
    -- Pentes : -2 800 puis +200 : au relevé W + 1 (W pentes), moyenne (-2 800 + 200 × (W - 1)) / W.
    local m = (-2800 + 200 * (W - 1)) / W
    check(near(d[W + 1], -m, 1e-6), "4 : fonte = moyenne des " .. W .. " min (" .. tostring(d[W + 1]) .. ", attendu " .. -m .. ")")
    local last
    for i = W + 1, #stocks do if d[i] then last = i end end -- (#d est faux : d a des trous)
    check(last ~= nil and last < W + 8, "4 : la depense isolee s'efface en moins de 7 releves apres l'echauffement (" .. tostring(last) .. ")")
    -- Stock de 9 000 au seuil 1 500 : projeté à Sa.H, 9 000 - 100 × Sa.H reste au-dessus : la saturation tient.
    check(Sa.holds(stocks[W + 1], 1500, d[W + 1]) == true, "4 : une depense isolee ne leve pas la saturation d'un gros stock")
  end

  -- 5. Stock illisible, absent, hors liste.
  section("5. stock illisible, absent, hors liste")
  do
    for _, bad in ipairs({ 0 / 0, -5, math.huge, "x" }) do
      local st = Sa.new()
      for i = 0, W + 1 do Sa.observe(st, i * MIN, { a = 5000 - 200 * i }, { "a" }) end
      check(Sa.drain(st, "a") ~= nil, "5 : temoin : fonte mesuree")
      Sa.observe(st, (W + 2) * MIN, { a = bad }, { "a" })
      check(st.items.a == nil and Sa.drain(st, "a") == nil, "5 : stock illisible (" .. tostring(bad) .. ") : historique rompu, aucune fonte")
      Sa.observe(st, (W + 3) * MIN, { a = 1000 }, { "a" })
      check(st.items.a and st.items.a.n == 0, "5 : apres un stock illisible, l'historique repart de zero")
    end
    local st = Sa.new()
    Sa.observe(st, 0, { a = 100 }, { "a", "b" })
    check(st.items.b and st.items.b.s == 0, "5 : objet absent du stock : stock 0")
    Sa.observe(st, MIN, { a = 100, b = 5 }, { "a" })
    check(st.items.b == nil, "5 : objet sorti de la liste : oublie (etat borne)")
    local st2 = Sa.new()
    for i = 0, W + 1 do Sa.observe(st2, i * MIN, { a = 5000 - 200 * i, b = 5000 - 300 * i, c = 5000 + 10 * i }, { "a", "b", "c" }) end
    local ds = Sa.drains(st2)
    check(near(ds.a, 200) and near(ds.b, 300) and ds.c == nil, "5 : Sa.drains rend les seules fontes durables")
    check(next(Sa.drains(Sa.new())) == nil and next(Sa.drains(nil)) == nil, "5 : Sa.drains sans etat : vide")
  end

  -- 6. Sa.holds.
  section("6. Sa.holds : seuil, projection, raisons")
  do
    local ok, why = Sa.holds(1000, 1500, nil)
    check(ok == false and why == "seuil", "6 : sous le seuil : faux, seuil")
    check(Sa.holds(1500, 1500, nil) == true, "6 : au seuil sans fonte : sature")
    check(Sa.holds(4000, 1500, 0) == true, "6 : fonte nulle : sature")
    local ok2, why2 = Sa.holds(4000, 1500, 200)
    check(ok2 == false and why2 == "pente", "6 : 4 000 - 200 x H sous 1 500 : faux, pente")
    check(Sa.holds(4000 + 200 * Sa.H, 1500, 200) == true, "6 : projete au-dessus du seuil : sature")
    check(Sa.holds(1500 + 200 * Sa.H - 1, 1500, 200) == false, "6 : projete juste sous le seuil : faux")
    check(Sa.holds(4000, 1500, 200, 5) == true, "6 : horizon donne (5 min) : 4 000 - 1 000 au-dessus")
    check(Sa.holds(1000, 1500, 200) == false, "6 : sous le seuil avec fonte : faux")
  end

  -- 7. Équivalence sans mesure.
  section("7. B.saturated sans mesure : la regle d'avant, 2 000 situations")
  do
    local seed = 12345
    local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648 return seed % n end
    local items = { "a", "b" }
    local diff, lifted = 0, 0
    for _ = 1, 2000 do
      local it = items[rnd(2) + 1]
      local s = { workers = rnd(41), stock = { [it] = rnd(20000) }, need = rnd(3) > 0 and { [it] = rnd(2500) } or nil,
        puits_flow = rnd(2) > 0 and { [it] = rnd(300) } or nil }
      local fo = rnd(2) > 0
      local old = old_saturated(s, it, fo, B)
      if B.saturated(s, it, fo) ~= old then diff = diff + 1 end
      s.drain = {}
      if B.saturated(s, it, fo) ~= old then diff = diff + 1 end
      s.drain = { other = 500 }
      if B.saturated(s, it, fo) ~= old then diff = diff + 1 end
      s.drain = { [it] = 1 + rnd(400) }
      if old and not B.saturated(s, it, fo) then lifted = lifted + 1 end
      if not old and B.saturated(s, it, fo) then diff = diff + 1 end
    end
    check(diff == 0, "7 : sans fonte de l'objet, B.saturated = regle d'avant (" .. diff .. " ecart(s))")
    check(lifted > 0, "7 : temoin : une fonte leve des saturations (" .. lifted .. ")")
  end

  -- 8. Avec mesure.
  section("8. B.saturated avec mesure")
  do
    local s = { workers = 8, stock = { a = 4000 }, need = { a = 500 } } -- seuil 3 × 500 = 1 500
    check(B.saturated(s, "a") == true, "8 : temoin : 4 000 >= 1 500, sature")
    s.drain = { a = 200 }
    local ok, why = B.saturated(s, "a")
    check(ok == false and why == "pente", "8 : fonte de 200/min : saturation levee, raison pente")
    s.drain = { a = 5 }
    check(B.saturated(s, "a") == true, "8 : fonte minime : sature")
    s.drain = { a = 200 }
    s.stock.a = 1000
    local ok3, why3 = B.saturated(s, "a")
    check(ok3 == false and why3 == nil, "8 : sous le seuil : faux sans raison (regle d'avant)")
    -- Plancher seul (lot C2) : même règle.
    local sf = { workers = 8, stock = { a = 4000 }, need = { a = 100 }, puits_flow = { a = 1000 }, drain = { a = 200 } }
    check(B.saturated(sf, "a", true) == false, "8 : plancher seul : la fonte leve aussi la saturation")
    sf.drain = nil
    check(B.saturated(sf, "a", true) == true and B.saturated(sf, "a") == false, "8 : temoin du plancher seul (C2)")
  end

  -- 9. Lecteurs.
  section("9. lecteurs : vague des bras libres, reconstruction, releve")
  do
    local key = B.key({})
    local top = key.top
    local P = T.outposts[top].product
    local function base_s(drain)
      local stock, cap = {}, {}
      for _, kind in ipairs(T.OUTPOST_ORDER) do cap[kind] = 1 stock[T.outposts[kind].product] = 0 end
      stock[P] = 4000
      local need = { [P] = 500 }
      return { workers = 8, stock = stock, need = need, cap = cap, pending = {}, idle_grow = true, tick = 30 * MIN, key = key,
        drain = drain, weights = {}, room = {}, sites = {}, nout = {} }
    end
    local function base_st()
      local tg = {}
      for _, kind in ipairs(T.OUTPOST_ORDER) do tg[kind] = 1 end
      return { targets = tg, iron2_set = true, short_n = {}, short = {} }
    end
    -- Vague des bras libres : une capacité par vague, à la ressource la plus demandée qui n'est pas saturée.
    local st0 = base_st()
    B.targets(base_s(nil), st0)
    check(st0.targets[top] == 1, "9 : sans mesure, la ressource la plus demandee saturee ne grandit pas")
    local st1 = base_st()
    B.targets(base_s({ [P] = 200 }), st1)
    check(st1.targets[top] == 2, "9 : stock qui fond : la vague des bras libres l'agrandit (" .. tostring(st1.targets[top]) .. ")")
    -- Reconstruction d'un avant-poste perdu (B.generate, extraction : capacité sous 75 % de la cible).
    local function extraction_goal(drain)
      local s, st = base_s(drain), base_st()
      s.idle_grow = false
      st.targets[top] = 2
      local goals = B.generate(s, st)
      for _, g in ipairs(goals) do if g.key == "extraction:" .. top then return g end end
      return nil
    end
    check(extraction_goal(nil) == nil, "9 : sans mesure, aucune reconstruction d'une matiere saturee")
    check(extraction_goal({ [P] = 200 }) ~= nil, "9 : stock qui fond : la reconstruction revient")
    -- Relève (Ex.releve) : le drapeau `saturated` du type suit la mesure.
    local function releve_sat(drain)
      local s, st = base_s(drain), base_st()
      local seen
      local Ex = require("shared.ai3.extension")
      local r0 = Ex.releve
      Ex.releve = function(arg, ...)
        for _, k in ipairs(arg.kinds) do if k.kind == top then seen = k.saturated end end
        return r0(arg, ...)
      end
      local ok, err = pcall(B.releve, s, st)
      Ex.releve = r0
      if not ok then return "erreur : " .. tostring(err) end
      return seen
    end
    check(releve_sat(nil) == true, "9 : releve sans mesure : type sature")
    check(releve_sat({ [P] = 200 }) == false, "9 : releve avec fonte : type non sature")
  end

  -- 10. Scène V79.
  section("10. scene V79 : stock qui fond, stock immense, stock qui monte")
  do
    local function first_unsat(S0, rate, need, minutes)
      local st = Sa.new()
      local S = S0
      local f_new, f_old, s_new, s_old
      for m = 0, minutes do
        Sa.observe(st, m * MIN, { a = S }, { "a" })
        local s = { workers = 8, stock = { a = S }, need = { a = need }, drain = Sa.drains(st) }
        if not f_new and not B.saturated(s, "a") then f_new, s_new = m, S end
        if not f_old and not old_saturated(s, "a", false, B) then f_old, s_old = m, S end
        S = math.max(0, S + rate)
      end
      return f_new, f_old, s_new, s_old
    end
    -- Production 200/min, consommation 400/min : le stock de 6 000 fond de 200/min ; seuil 3 × 500.
    local fn, fo, sn, so = first_unsat(6000, -200, 500, 60)
    if not quiet then print(string.format("   fonte de 200/min : saturation levee a %s min (stock %s) ; regle d'avant a %s min (stock %s)",
      tostring(fn), tostring(sn), tostring(fo), tostring(so))) end
    check(fo == 23 and so == 1400, "10 : regle d'avant : levee a 23 min, 1 400 restants (7 min de stock)")
    check(fn == W and sn == 6000 - 200 * W, "10 : nouvelle regle : levee des la fonte mesuree (" .. tostring(fn) .. " min, stock " .. tostring(sn) .. ")")
    -- Stock immense, fonte minime : inchangé sur une heure.
    local fn2, fo2 = first_unsat(45000, -5, 500, 60)
    check(fn2 == nil and fo2 == nil, "10 : 45 000 qui fond de 5/min : sature toute l'heure, comme avant")
    -- Stock qui monte : inchangé.
    local fn3, fo3 = first_unsat(2000, 50, 500, 60)
    check(fn3 == nil and fo3 == nil, "10 : stock qui monte : sature comme avant")
    -- Stock sous le seuil : non saturé dès le début, comme avant.
    local fn4, fo4 = first_unsat(1000, -50, 500, 5)
    check(fn4 == 0 and fo4 == 0, "10 : sous le seuil : non sature des le debut, comme avant")
  end

  -- 11. Déterminisme.
  section("11. determinisme")
  do
    local function run(order)
      local st = Sa.new()
      for i = 0, W + 3 do
        local stock = {}
        for _, k in ipairs(order) do stock[k] = 9000 - (k == "b" and 300 or 100) * i end
        Sa.observe(st, i * MIN, stock, { "a", "b", "c" })
      end
      local ds = Sa.drains(st)
      return string.format("%.6f|%.6f|%s", ds.a or -1, ds.b or -1, tostring(ds.c))
    end
    check(run({ "a", "b", "c" }) == run({ "c", "b", "a" }), "11 : meme etat quel que soit l'ordre d'ecriture du stock")
    check(run({ "a", "b", "c" }) == run({ "a", "b", "c" }), "11 : deux passages identiques")
  end

  -- 12. Coût.
  section("12. cout en instructions (debug.sethook)")
  do
    local function instr(fn)
      local c = 0
      debug.sethook(function() c = c + 1 end, "", 1)
      fn()
      debug.sethook()
      return c
    end
    local s = { workers = 8, stock = { a = 4000 }, need = { a = 500 } }
    local i_old = instr(function() old_saturated(s, "a", false, B) end)
    local i_new = instr(function() B.saturated(s, "a") end)
    s.drain = { a = 200 }
    local i_drain = instr(function() B.saturated(s, "a") end)
    local function items_of(n) local t = {} for i = 1, n do t[i] = string.format("o%03d", i) end return t end
    local function observe_cost(n)
      local it, st = items_of(n), Sa.new()
      local stock = {}
      for i, k in ipairs(it) do stock[k] = 1000 + i end
      Sa.observe(st, 0, stock, it)
      return instr(function() Sa.observe(st, MIN, stock, it) end), st
    end
    local i_obs8, st8 = observe_cost(8)
    local i_obs64 = observe_cost(64)
    local i_drains = instr(function() Sa.drains(st8) end)
    if not quiet then
      print(string.format("   B.saturated : %d instructions (regle d'avant : %d) ; avec fonte : %d ; Sa.observe 8 objets : %d, 64 : %d ; Sa.drains 8 : %d",
        i_new, i_old, i_drain, i_obs8, i_obs64, i_drains))
    end
    check(i_new <= i_old + 40, "12 : B.saturated sans mesure : au plus 40 instructions de plus que la regle d'avant (" .. i_new .. " contre " .. i_old .. ")")
    check(i_drain <= i_old + 80, "12 : B.saturated avec fonte : au plus 80 de plus (" .. i_drain .. ")")
    check(i_obs64 < 10 * i_obs8, "12 : Sa.observe lineaire en objets (" .. i_obs64 .. " pour 64 contre " .. i_obs8 .. " pour 8)")
    check(i_obs8 < 1500 and i_drains < 1500, "12 : un releve de 8 objets et Sa.drains sous 1 500 instructions")
  end
end

local Sa0, B0 = load_pair()
assert(Sa0 and B0, "chargement")
run_all(Sa0, B0)

-- 13. Mutants.
section("13. mutants")
local MUTANTS = {
  { "b", "fonte ignoree par B.saturated", { "if d then return Sa.holds(have, thr, d) end", "" } },
  { "b", "objet sans mesure lu comme une fonte (garde ouverte)", { "local d = s.drain and s.drain[item]", "local d = s.drain and (s.drain[item] or 1e9)" } },
  { "sa", "projection contre zero au lieu du seuil", { "stock - drain * (h or Sa.H) < threshold", "stock - drain * (h or Sa.H) < 0" } },
  { "sa", "seuil retire de Sa.holds", { 'if not (stock >= threshold) then return false, "seuil" end', "" } },
  { "sa", "sans echauffement", { "if not e or e.n < Sa.WINDOW then return nil end", "if not e then return nil end" } },
  { "sa", "bruit compte comme fonte", { "if e.m > -Sa.MIN_RATE then return nil end", "if e.m >= 0 then return nil end" } },
  { "sa", "signe de la fonte inverse", { "return -e.m", "return e.m" } },
  { "sa", "derniere pente au lieu de la moyenne", { "m = e.m + (slope - e.m) / w", "m = slope" } },
  { "sa", "poids fixe des le debut (moyenne biaisee)", { "local w = n < Sa.WINDOW and n or Sa.WINDOW", "local w = Sa.WINDOW" } },
  { "sa", "intervalle ignore", { "local slope = (v - e.s) * Sa.PERIOD / (tick - e.t)", "local slope = (v - e.s)" } },
  { "sa", "releve a chaque appel", { "return type(tick) == \"number\" and (state.tick == nil or tick - state.tick >= Sa.PERIOD)", "return type(tick) == \"number\"" } },
  { "sa", "stock illisible lu comme 0", { "if type(v) ~= \"number\" or v ~= v or v < 0 or v == math.huge then return nil end", "if type(v) ~= \"number\" or v ~= v or v < 0 or v == math.huge then return 0 end" } },
  { "sa", "objets hors liste gardes", { "local old, out = state.items or {}, {}", "local old = state.items or {} local out = old" } },
}
local killed = 0
quiet = true
for _, m in ipairs(MUTANTS) do
  local Sa, B, err = load_pair(m[1], m[3])
  local dead
  if not Sa then
    quiet = false
    check(false, "mutant '" .. m[2] .. "' : " .. tostring(err))
    quiet = true
    dead = false
  else
    local p0, f0 = passes, failures
    local okrun, e = pcall(run_all, Sa, B)
    local nf = failures - f0
    dead = (not okrun) or nf > 0
    passes, failures = p0, f0
    quiet = false
    print(string.format("   %s : %s", m[2], (not okrun) and ("PLANTAGE " .. tostring(e)) or (nf .. " controle(s) en echec")))
    quiet = true
  end
  if dead then killed = killed + 1 else
    quiet = false
    check(false, "mutant SURVIVANT : " .. m[2])
    quiet = true
  end
end
quiet = false
package.loaded["shared.ai3.saturation"] = Sa0
print(string.format("   mutants refuses : %d / %d", killed, #MUTANTS))
check(killed == #MUTANTS, "tous les mutants sont refuses")

print(string.format("[SATURATION] BILAN : %d OK, %d ECHEC(S) ; mutants %d/%d refuses", passes, failures, killed, #MUTANTS))
if failures > 0 then os.exit(1) end
