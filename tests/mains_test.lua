--[[
  Lot MAINS : bancs HORS JEU de la règle « le fond ne travaille pas à la main ce que les machines fournissent »
  (shared/team/mains.lua, branchée sur shared/team/fond.lua par script/team/poles.lua).
    1. mesure : étiquettes, unités, texte ;
    2. règle : saturée / module / débit automatique mesuré / manque / mesure trop courte, débit moyen, chaînes ;
    3. comparaison à une FORCE BRUTE (grille de petits cas, formulation entière indépendante) et propriétés de monotonie ;
    4. fond : ni minage ni fonte de fond d'une matière couverte, le reste inchangé (fond.lua) ;
    5. généralisation : mêmes décisions sur des données aux noms changés (aucun nom dans la règle) ;
    6. 14 mutants de la règle, tous refusés.
  Lancement : lua5.2 tests/mains_test.lua (depuis la racine du mod).
]]
package.path = "./?.lua;" .. package.path
local T = require("shared.team.config")
local Book = require("shared.team.book")
local Fond = require("shared.team.fond")
local B = require("shared.ai3.buts")

local passes, failures = 0, 0
local current = nil -- liste de collecte d'échecs d'un jeu de contrôles (mutants)
local function check(cond, msg)
  if cond then passes = passes + 1
  elseif current then current[#current + 1] = msg
  else failures = failures + 1; print("  ECHEC : " .. msg) end
end
local function section(name) print("== " .. name) end

local function read(path)
  local h = assert(io.open(path, "rb"))
  local s = h:read("*a")
  h:close()
  return s
end

local function ser(v)
  if type(v) == "table" then
    local ks = {}
    for k in pairs(v) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(ks) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
  end
  return tostring(v)
end

local seed = 20281028
local function rnd(n)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return math.floor(seed / 65536) % n
end

---------------------------------------------------------------------------------------------------
-- Jeu de contrôles de la RÈGLE (rejoué sur chaque mutant avec le module muté)
---------------------------------------------------------------------------------------------------
-- Entrée construite sur UNE chaîne de fonte (produit P, ressource R) et UNE chaîne brute (produit = ressource Q).
local function rule_checks(M, Tcfg)
  local chains = M.chains(Tcfg)
  local smelted, raw
  for _, ch in ipairs(chains) do
    if ch.smelted and not smelted then smelted = ch end
    if not ch.smelted and not raw then raw = ch end
  end
  local P, R = smelted.product, smelted.resource
  local function ctx(o)
    o = o or {}
    return { saturated = o.sat or {}, modules = o.mod or {}, short = o.short or {}, need = o.need or {}, flow = o.flow or {} }
  end
  local function flow(rate, n) return { rate = rate, n = n } end

  -- Cas de la règle.
  check(M.reason(P, ctx({ sat = { [P] = true } })) == "sature", "saturée : couverte (sature)")
  check(M.reason(P, ctx({ mod = { [P] = true } })) == "module", "module fini : couverte (module)")
  check(M.reason(P, ctx({})) == nil, "aucune mesure : jamais couverte")
  check(M.reason(P, ctx({ need = { [P] = 100 }, flow = { [P] = flow(10, 5) } })) == "debit",
    "débit 10/min x 10 min = besoin 100 : couverte (égalité comprise)")
  check(M.reason(P, ctx({ need = { [P] = 101 }, flow = { [P] = flow(10, 5) } })) == nil, "débit juste sous le besoin : pas couverte")
  check(M.reason(P, ctx({ need = { [P] = 100 }, flow = { [P] = flow(50, 2) } })) == nil,
    "mesure de 2 minutes seulement : pas de verdict « debit »")
  check(M.reason(P, ctx({ need = { [P] = 100 }, flow = { [P] = flow(50, 3) } })) == "debit", "mesure de 3 minutes : verdict possible")
  check(M.reason(P, ctx({ need = { [P] = 100 }, short = { [P] = 5 }, flow = { [P] = flow(50, 9) } })) == nil,
    "la matière MANQUE : jamais couverte par le débit")
  check(M.reason(P, ctx({ need = { [P] = 0 }, flow = { [P] = flow(0, 9) } })) == nil, "débit nul : jamais couverte")
  check(M.reason(P, ctx({ need = { [P] = 100 }, flow = { [raw.product] = flow(50, 9) } })) == nil,
    "le débit d'une AUTRE matière ne couvre pas celle-ci")

  -- Débit moyen : production moins minage à la main, jamais négatif, sur 10 minutes au plus.
  local r, n = M.auto_flow({ { total = 30, hand = 10 }, { total = 20, hand = 0 } })
  check(r == 20 and n == 2, "débit moyen : (20 + 20) / 2 (" .. tostring(r) .. ", " .. tostring(n) .. ")")
  r = M.auto_flow({ { total = 5, hand = 40 }, { total = 15, hand = 0 } })
  check(r == 7.5, "le minage à la main ne rend jamais un débit négatif : (0 + 15) / 2 (" .. tostring(r) .. ")")
  local long = {}
  for i = 1, 14 do long[i] = { total = i <= 4 and 1000 or 10, hand = 0 } end
  r, n = M.auto_flow(long)
  check(r == 10 and n == 10, "fenêtre : les 10 dernières minutes seulement (" .. tostring(r) .. ", " .. tostring(n) .. ")")
  local r0, n0 = M.auto_flow({})
  check(r0 == 0 and n0 == 0, "aucun échantillon : débit nul")

  -- Chaînes et ensembles à écarter.
  check(smelted.resource ~= smelted.product and raw.resource == raw.product, "chaînes : fonte (produit != ressource) et brute")
  local mine, smelt = M.skips(chains, ctx({ sat = { [P] = true } }))
  check(mine[R] == "sature" and smelt[P] == "sature", "plaque saturée : minerai ET fonte de fond écartés")
  check(next(mine, next(mine)) == nil, "plaque saturée : un seul minerai écarté")
  mine, smelt = M.skips(chains, ctx({ mod = { [raw.product] = true } }))
  check(mine[raw.resource] == "module" and next(smelt) == nil, "produit brut couvert : minage écarté, aucune fonte")
  mine, smelt = M.skips(chains, ctx({}))
  check(next(mine) == nil and next(smelt) == nil, "rien de couvert : rien d'écarté")
  mine, smelt = M.skips(chains, ctx({ need = { [P] = 40 }, flow = { [P] = flow(4, 6) } }))
  check(mine[R] == "debit" and smelt[P] == "debit" and mine[P] == nil, "le minerai est écarté sous le nom de la RESSOURCE, la fonte sous celui du produit")
end

---------------------------------------------------------------------------------------------------
section("1. Mesure : étiquettes, unités, texte")
local Mains = require("shared.team.mains")
do
  local function prod(oid) return oid == 7 and "produit-sept" or nil end
  check(Mains.label({ kind = "mine", resource = "r1", fond = true, key = "fond:mine:r1:1" }) == "mine:r1+", "minage de fond : mine:r1+")
  check(Mains.label({ kind = "mine", resource = "r1", key = "manque:mine:r1:2" }) == "mine:r1@manque", "minage du manque : @manque")
  check(Mains.label({ kind = "mine", resource = "r1", key = "mine:r1" }) == "mine:r1", "minage du planificateur : sans suffixe")
  check(Mains.label({ kind = "smelt", smelt = { b = 3, a = 2 }, fond = true }) == "smelt:a/b+", "fonte de fond : plaques triées")
  check(Mains.label({ kind = "smelt", smelt = {} }) == "smelt:vide", "fonte sans plaque : vide")
  check(Mains.label({ kind = "service", outpost = 7 }, prod) == "service:produit-sept", "tournée : produit de l'avant-poste")
  check(Mains.label({ kind = "garrison", fond = true }) == "garrison+", "garde de fond")
  check(Mains.label({ kind = "mine", resource = "r1", fond = true }, nil, function() return true end) == "mine:r1+#sat", "matière saturée : #sat")
  check(Mains.units({ kind = "mine", count = 50 }) == 50 and Mains.units({ kind = "smelt", smelt = { a = 2, b = 3 } }) == 5
    and Mains.units({ kind = "service" }) == 0, "unités : minerai, plaques fondues, 0 sinon")
  local acc = {}
  Mains.add(acc, "x", true, 10.4, 50)
  Mains.add(acc, "x", false, 5, 0)
  Mains.add(acc, "a", true, 1, 2)
  check(Mains.format(acc) == "a=1/0,1s,2u x=1/1,15s,50u", "texte : étiquettes triées, ok/ko, secondes, unités (" .. Mains.format(acc) .. ")")
end

---------------------------------------------------------------------------------------------------
section("2. Règle (données de l'exécutant)")
rule_checks(Mains, T)

---------------------------------------------------------------------------------------------------
section("3. Force brute et monotonie")
do
  local chains = Mains.chains(T)
  local P = nil
  for _, ch in ipairs(chains) do if ch.smelted then P = ch.product break end end
  -- Oracle indépendant, en entiers : la plaque est couverte quand elle est saturée (stock >= SAT x besoin), fournie par un
  -- module, ou que rien ne manque et que les machines livreraient le besoin en 10 minutes (somme des k dernières minutes
  -- x 10 >= besoin x k), avec au moins 3 minutes de mesure.
  local function oracle(stock, need, short, module, samples)
    if stock >= B.SAT_FACTOR * need and need > 0 then return "sature" end
    if module then return "module" end
    if short > 0 then return nil end
    local k = math.min(#samples, 10)
    if k < 3 then return nil end
    local sum = 0
    for i = #samples - k + 1, #samples do sum = sum + math.max(0, samples[i].total - samples[i].hand) end
    if sum > 0 and sum * 10 >= need * k then return "debit" end
    return nil
  end
  local bad, total, covered, uncovered = 0, 0, 0, 0
  for _ = 1, 6000 do
    local need = rnd(40) * 25
    local stock = rnd(3000)
    local short = (rnd(4) == 0) and rnd(50) + 1 or 0
    local module = rnd(8) == 0
    local k = rnd(14)
    local samples = {}
    for i = 1, k do samples[i] = { total = rnd(60), hand = rnd(3) == 0 and rnd(80) or 0 } end
    local rate, n = Mains.auto_flow(samples)
    local c = { saturated = {}, modules = { [P] = module or nil }, short = { [P] = short }, need = { [P] = need },
      flow = { [P] = { rate = rate, n = n } } }
    if need > 0 and stock >= B.SAT_FACTOR * need then c.saturated[P] = true end
    local got = Mains.reason(P, c)
    local want = oracle(stock, need, short, module, samples)
    total = total + 1
    if got ~= want then
      bad = bad + 1
      if bad <= 3 then print("  écart : stock " .. stock .. " besoin " .. need .. " manque " .. short .. " -> " .. tostring(got) .. " / " .. tostring(want)) end
    end
    if got then covered = covered + 1 else uncovered = uncovered + 1 end
  end
  check(bad == 0, "force brute : " .. total .. " cas tirés, " .. bad .. " écart(s) avec l'oracle entier")
  check(covered > 500 and uncovered > 500, "force brute : les deux issues sont bien couvertes par le tirage (" .. covered .. "/" .. uncovered .. ")")
  -- Monotonie : plus de débit ne découvre jamais ; plus de besoin ne couvre jamais ; un manque découvre toujours (hors saturée/module).
  local mono_flow, mono_need, mono_short = true, true, true
  for _ = 1, 3000 do
    local need = rnd(40) * 25
    local rate = rnd(100)
    local n = rnd(12)
    local base = { saturated = {}, modules = {}, short = { [P] = 0 }, need = { [P] = need }, flow = { [P] = { rate = rate, n = n } } }
    local more = { saturated = {}, modules = {}, short = { [P] = 0 }, need = { [P] = need }, flow = { [P] = { rate = rate + rnd(50), n = n } } }
    if Mains.reason(P, base) and not Mains.reason(P, more) then mono_flow = false end
    local needier = { saturated = {}, modules = {}, short = { [P] = 0 }, need = { [P] = need + rnd(100) }, flow = { [P] = { rate = rate, n = n } } }
    if Mains.reason(P, needier) and not Mains.reason(P, base) then mono_need = false end
    local sh = { saturated = {}, modules = {}, short = { [P] = rnd(20) + 1 }, need = { [P] = need }, flow = { [P] = { rate = rate, n = n } } }
    if Mains.reason(P, sh) then mono_short = false end
  end
  check(mono_flow, "monotonie : un débit plus fort ne retire jamais la couverture")
  check(mono_need, "monotonie : un besoin plus fort ne crée jamais la couverture")
  check(mono_short, "un manque annule toujours le verdict « debit »")
end

---------------------------------------------------------------------------------------------------
section("4. Fond : ni minage ni fonte de fond d'une matière couverte")
do
  local book = Book.new(dofile("tests/fixtures/recipes.lua"))
  local function view(o)
    return { outposts = o.outposts or {}, sites = o.sites or {}, smelters = o.smelters or 0, stock = o.stock or {}, incoming = {} }
  end
  local v = view({ outposts = { { id = 1, kind = "iron", drills = 8, full = true } }, smelters = 2,
    stock = { ["iron-ore"] = 60, ["copper-ore"] = 60, coal = 50, stone = 20, ["iron-plate"] = 900, ["copper-plate"] = 300 } })
  local function run(ctx)
    ctx.book, ctx.keys, ctx.mine_left = book, {}, 6
    local c = Fond.candidates(v, Fond.free_stock(v.stock, {}), ctx)
    local mines, smelts = {}, {}
    for _, t in ipairs(c.extraction) do
      if t.kind == "mine" then mines[t.resource] = (mines[t.resource] or 0) + 1 end
      if t.kind == "smelt" then for p in pairs(t.smelt) do smelts[p] = true end end
    end
    return mines, smelts
  end
  local m0, s0 = run({})
  check(m0["iron-ore"] and m0["copper-ore"] and s0["iron-plate"] and s0["copper-plate"],
    "sans règle : le fond mine les deux minerais et fond les deux plaques (" .. ser(m0) .. " " .. ser(s0) .. ")")
  local mine_skip, smelt_skip = Mains.skips(Mains.chains(T), { saturated = { ["iron-plate"] = true }, modules = {}, short = {}, need = {}, flow = {} })
  local m1, s1 = run({ mine_skip = mine_skip, smelt_skip = smelt_skip })
  check(m1["iron-ore"] == nil and s1["iron-plate"] == nil, "fer couvert : ni minage du minerai ni fonte de la plaque")
  check(m1["copper-ore"] and s1["copper-plate"], "fer couvert : le cuivre est travaillé comme avant")
  check(m1.coal or m1.stone, "fer couvert : le charbon et la pierre sont minés comme avant")
  local mine_all, smelt_all = Mains.skips(Mains.chains(T), { saturated = { ["iron-plate"] = true, ["copper-plate"] = true, coal = true, stone = true },
    modules = {}, short = {}, need = {}, flow = {} })
  local m2, s2 = run({ mine_skip = mine_all, smelt_skip = smelt_all })
  check(next(m2) == nil and next(s2) == nil, "tout couvert : aucun minage ni fonte de fond (" .. ser(m2) .. " " .. ser(s2) .. ")")
  -- Les tâches du reste du fond ne bougent pas : mêmes extensions et mêmes constructions avec ou sans règle.
  local v2 = view({ outposts = { { id = 1, kind = "iron", drills = 4 } }, sites = { copper = 1 }, smelters = 1,
    stock = { ["burner-mining-drill"] = 6, ["stone-furnace"] = 6, ["iron-chest"] = 4, coal = 300, ["iron-ore"] = 80 } })
  local function others(ctx)
    ctx.book, ctx.keys, ctx.mine_left = book, {}, 3
    local c = Fond.candidates(v2, Fond.free_stock(v2.stock, {}), ctx)
    local ks = {}
    for _, name in ipairs({ "extraction", "base", "territoire" }) do
      for _, t in ipairs(c[name]) do if t.kind ~= "mine" and t.kind ~= "smelt" then ks[#ks + 1] = t.key end end
    end
    return table.concat(ks, ",")
  end
  check(others({}) == others({ mine_skip = mine_all, smelt_skip = smelt_all }), "agrandir, construire, fabriquer, garder : inchangés par la règle")
  -- Déterminisme.
  local a, b = ser(select(1, run({ mine_skip = mine_skip, smelt_skip = smelt_skip }))), ser(select(1, run({ mine_skip = mine_skip, smelt_skip = smelt_skip })))
  check(a == b, "même entrée, même sortie")
end

---------------------------------------------------------------------------------------------------
section("5. Généralisation : données aux noms changés")
do
  -- Copie des tables de l'exécutant avec tous les noms changés (aucun nom du jeu de base) ; la règle ne doit rien y lire d'autre.
  local map = {}
  local function rn(x) map[x] = map[x] or ("zz-" .. x:reverse()); return map[x] end
  local T2 = { OUTPOST_ORDER = {}, outposts = {}, smelter_inputs = {} }
  for i, kind in ipairs(T.OUTPOST_ORDER) do
    local spec = T.outposts[kind]
    T2.OUTPOST_ORDER[i] = "k" .. i
    T2.outposts["k" .. i] = { resource = rn(spec.resource), product = rn(spec.product), sink = rn(spec.sink), drills = spec.drills }
  end
  for p, inp in pairs(T.smelter_inputs) do T2.smelter_inputs[rn(p)] = { rn(inp[1]), inp[2] } end
  rule_checks(Mains, T2)
  local c1, c2 = Mains.chains(T), Mains.chains(T2)
  local same = #c1 == #c2
  for i = 1, #c1 do
    if c1[i].smelted ~= c2[i].smelted or rn(c1[i].product) ~= c2[i].product or rn(c1[i].resource) ~= c2[i].resource then same = false end
  end
  check(same, "chaînes déduites identiques à un renommage près (fonte ou brute)")
  -- Une ressource dont la fonte prend une AUTRE entrée que la ressource de l'avant-poste n'est pas une chaîne fondue.
  local T3 = { OUTPOST_ORDER = { "a" }, outposts = { a = { resource = "r", product = "p", drills = 1 } }, smelter_inputs = { p = { "autre", 1 } } }
  check(Mains.chains(T3)[1].smelted == false, "fonte d'une autre entrée : chaîne non fondue")
  local T4 = { OUTPOST_ORDER = { "a" }, outposts = { a = { resource = "r", product = "p", drills = 1 } } }
  check(Mains.chains(T4)[1].smelted == false, "sans table de fonte : chaîne non fondue")
  -- Aucun nom d'objet du jeu dans les fichiers de la règle (registre anti-échelle).
  local names = {}
  for _, kind in ipairs(T.OUTPOST_ORDER) do
    local s = T.outposts[kind]
    names[s.resource], names[s.product], names[s.sink] = true, true, true
  end
  for p, inp in pairs(T.smelter_inputs) do names[p], names[inp[1]] = true, true end
  for _, path in ipairs({ "shared/team/mains.lua", "script/team/mains.lua" }) do
    local src = read(path)
    local found = {}
    for lit in src:gmatch('"([^"\n]*)"') do if names[lit] then found[#found + 1] = lit end end
    check(#found == 0, path .. " : aucun nom d'objet du jeu entre guillemets (" .. table.concat(found, ",") .. ")")
  end
end

---------------------------------------------------------------------------------------------------
section("6. Mutants de la règle")
do
  local src = read("shared/team/mains.lua")
  local mutants = {
    { "débit sans minimum de mesure", "(fl.n or 0) >= M.MIN_SAMPLES", "(fl.n or 0) >= 0" },
    { "égalité exclue", "fl.rate * M.COVER_MIN >= ((c.need", "fl.rate * M.COVER_MIN > ((c.need" },
    { "manque ignoré", "  if c.short and (c.short[item] or 0) > 0 then return nil end\n", "" },
    { "minage à la main non retiré du débit", "(s.total or 0) - (s.hand or 0)", "(s.total or 0)" },
    { "débit négatif admis", "math.max(0, (s.total or 0) - (s.hand or 0))", "((s.total or 0) - (s.hand or 0))" },
    { "saturation ignorée", 'if c.saturated and c.saturated[item] then return "sature" end', "" },
    { "module ignoré", 'if c.modules and c.modules[item] then return "module" end', "" },
    { "fonte écartée aussi pour un produit brut", "if ch.smelted then smelt[ch.product] = why end", "smelt[ch.product] = why" },
    { "fenêtre sans limite", "local first = math.max(1, n - M.COVER_MIN + 1)", "local first = 1" },
    { "minerai écarté sous le nom du produit", "mine[ch.resource] = why", "mine[ch.product] = why" },
    { "toute chaîne dite fondue", "smelted = input ~= nil and input[1] == spec.resource", "smelted = true" },
    { "débit d'une autre matière", "local fl = c.flow and c.flow[item]", "local fl = c.flow and c.flow[next(c.flow)]" },
    { "besoin ignoré", "and fl.rate * M.COVER_MIN >= ((c.need and c.need[item]) or 0) then", "then" },
    { "débit nul accepté", "and (fl.rate or 0) > 0\n", "\n" },
  }
  for _, m in ipairs(mutants) do
    local i, j = src:find(m[2], 1, true)
    check(i ~= nil, "mutant « " .. m[1] .. " » : motif trouvé dans la source")
    if i then
      local msrc = src:sub(1, i - 1) .. m[3] .. src:sub(j + 1)
      local chunk, err = load(msrc, "@mutant", "t")
      check(chunk ~= nil, "mutant « " .. m[1] .. " » : compile (" .. tostring(err) .. ")")
      if chunk then
        current = {}
        local ok, perr = pcall(function() rule_checks(chunk(), T) end)
        local killed = (not ok) or #current > 0
        current = nil
        check(killed, "mutant refusé : " .. m[1] .. (ok and "" or (" (plantage : " .. tostring(perr) .. ")")))
      end
    end
  end
end

print(string.format("[MAINS] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
