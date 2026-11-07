--[[
  Lot VIDEO L7 : banc HORS JEU de l'amorce et de son retrait (shared/ai3/amorce.lua, sur la règle du mall shared/ai3/mall.lua).
  Lancement, depuis la racine du mod : lua5.2 tests/amorce_test.lua
    1. graine présente au 1er cycle (Ml.sources), sans épisode de fabrication à la main ; bornée à la liste de matériel ;
       n'écrase pas une demande plus forte ; seuls les K premiers projets ; stock déduit ; objet sans recette écarté ;
    2. retrait à la 1re production OBSERVÉE (jamais à la pose), verrou tenu quand la machine s'arrête (sortie pleine),
       jamais à stock nul, levé quand plus aucun module ne produit l'objet ;
    3. compteur d'amorce (cumul avant la 1re production, gardé après) ; journal [FO-AMORCE] ;
    7. cycles (lot VIDEO-COUVERTURE 5, critère C5.1) : une recette qui consomme son produit reçoit une graine bornée, avec sa cause ;
       sans cycle, rien ; le stock se déduit ; une mesure illisible n'est pas semée ;
    4. sérialisable, déterministe ;
    5. coût en instructions (debug.sethook) ;
    6. mutants refusés.
]]
package.path = "./?.lua;" .. package.path
local Ml = require("shared.ai3.mall")
local Am0 = require("shared.ai3.amorce")
local Id = require("shared.ai3.industrie")
local passes, failures = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else failures = failures + 1 print("  ECHEC : " .. msg) end
  return cond
end
local BOOK = { recipe_for = function(_, it) return (it ~= "brut") and { name = it } or nil end }
local function copy(t) local o = {} for k, v in pairs(t) do o[k] = v end return o end

local function source_of(st, tick, item)
  for _, s in ipairs(Ml.sources(st, tick)) do if s.item == item then return s end end
end

local function battery(Am, verbose)
  local fails = 0
  local function ck(c, msg)
    if not c then fails = fails + 1 if verbose then print("  ECHEC : " .. msg) end end
    if verbose then check(c, msg) end
  end
  -- 1. graine
  local projets = {
    { bom = { bras = 6, tapis = 40, poteau = 4 } },
    { bom = { bras = 4, four = 8 } },
    { bom = { foreuse = 10, brut = 5 } },
    { bom = { assembleur = 12 } },            -- 4e projet : hors de la graine (Am.K = 3)
  }
  local st = Ml.new()
  local seeded = Am.seed(st, 60, projets, { tapis = 15 }, BOOK, Ml)
  local s_bras = source_of(st, 60, "bras")
  ck(s_bras ~= nil and s_bras.src == "amorce", "graine présente au 1er cycle, sans épisode de fabrication à la main")
  ck(s_bras and math.abs(s_bras.rate * Id.HORIZON_MIN - 10) < 1e-9, "bras : 6 + 4 de la liste, couverts en 10 min")
  local s_tapis = source_of(st, 60, "tapis")
  ck(s_tapis and math.abs(s_tapis.rate * Id.HORIZON_MIN - 25) < 1e-9, "tapis : 40 de la liste moins 15 au stock")
  ck(source_of(st, 60, "assembleur") == nil, "4e projet hors de la graine")
  ck(source_of(st, 60, "brut") == nil, "objet sans recette écarté")
  local sum = Am.bom(projets, Am.K)
  for _, s in ipairs(Ml.sources(st, 60)) do
    ck(s.rate * Id.HORIZON_MIN <= (sum[s.item] or 0) + 1e-9, "la graine ne dépasse pas la liste de matériel (" .. s.item .. ")")
    ck(Id.barre(s.rate, 1, 1000) <= (sum[s.item] or 0), "barre de 10 min sous la liste de matériel (" .. s.item .. ")")
  end
  ck(#seeded == 5, "5 objets semés (" .. #seeded .. ")")
  local st2 = Ml.new()
  Ml.want(st2, 50, "four", 9, "capi")
  Am.seed(st2, 60, projets, {}, BOOK, Ml)
  ck(st2.want.four.src == "capi" and st2.want.four.rate == 9, "une demande plus forte d'une autre source n'est pas écrasée")
  Am.seed(st2, 60, projets, { bras = 10, tapis = 40, poteau = 4, four = 8, foreuse = 10 }, BOOK, Ml)
  ck(#(Am.seed(st2, 60, projets, { bras = 10, tapis = 40, poteau = 4, four = 8, foreuse = 10 }, BOOK, Ml)) == 0, "stock suffisant : aucune graine")

  -- 2. retrait et 3. compteur
  local s = Ml.new()
  Am.seed(s, 0, projets, {}, BOOK, Ml)
  ck(Am.hand_allowed(s, "bras", 3, Ml), "avant toute production : la main amorce")
  local r1 = Am.observe(s, 3600, { bras = { made = 5, hand = 5 } }, { bras = true })
  ck(#r1 == 0 and Am.hand_allowed(s, "bras", 3, Ml), "module posé, rien produit par la machine : la main reste (jamais à la pose)")
  Am.observe(s, 7200, { bras = { made = 3, hand = 3 } }, { bras = true })
  ck(Am.supplied(s, "bras") == 8, "compteur d'amorce : 5 + 3 à la main (" .. Am.supplied(s, "bras") .. ")")
  local r2 = Am.observe(s, 10800, { bras = { made = 4, hand = 1 } }, { bras = true })
  ck(#r2 == 1 and r2[1].item == "bras" and r2[1].hand == 8, "retrait à la 1re production observée, compteur au journal")
  ck(not Am.hand_allowed(s, "bras", 3, Ml), "main refusée après la 1re production")
  ck(Am.hand_allowed(s, "bras", 0, Ml), "main toujours permise à stock nul")
  Ml.set_running(s, {})
  local r3 = Am.observe(s, 14400, { bras = { made = 0, hand = 0 } }, { bras = true })
  ck(#r3 == 0 and not Am.hand_allowed(s, "bras", 3, Ml), "machine arrêtée (sortie pleine) : le retrait tient (verrou)")
  ck(Am.supplied(s, "bras") == 8, "compteur gardé après le retrait")
  Am.observe(s, 18000, { bras = { made = 2, hand = 2 } }, { bras = true })
  ck(Am.supplied(s, "bras") == 8, "la main d'après le retrait n'entre pas au compteur d'amorce")
  Am.observe(s, 21600, {}, {})
  ck(Am.hand_allowed(s, "bras", 3, Ml), "plus aucun producteur : la main revient")
  ck(Am.supplied(s, "bras") == 8, "compteur gardé quand la main revient")
  Am.observe(s, 25200, { tapis = { made = 9, hand = 9 } }, nil)
  ck(Am.supplied(s, "tapis") == 9, "objet semé : la main est comptée")
  local tasks = { { kind = "craft", item = "bras", prio = 40 }, { kind = "craft", item = "bras", prio = 95 }, { kind = "craft", item = "tapis", prio = 40 } }
  local s4 = Ml.new()
  Am.seed(s4, 0, projets, {}, BOOK, Ml)
  Am.observe(s4, 3600, { bras = { made = 4, hand = 0 } }, { bras = true })
  local kept = Am.filter_crafts(s4, tasks, { bras = 2, tapis = 2 }, 90, Ml)
  ck(#kept == 2 and kept[1].prio == 95 and kept[2].item == "tapis", "filtre : la main retirée sous l'urgence, gardée au-dessus")
  ck(#Am.filter_crafts(s4, tasks, { bras = 0, tapis = 2 }, 90, Ml) == 3, "filtre : stock nul, la main reste")
  local line = r2[1] and Am.describe(r2[1], s) or ""
  ck(line:find("bras", 1, true) and line:find("8 fourni", 1, true), "ligne [FO-AMORCE] : objet et compteur (" .. line .. ")")

  -- 7. cycles (C5.1). Rg.chain rend seed = { [membre] = { { ingrédient interne, quantité par fabrication } } } et cyc = { [membre] = id }.
  local rg = { seed = { cata = { { "cata", 40 }, { "autre", 5 } } }, cyc = { cata = "cata" } }
  local cyc = Am.flatten(rg)
  ck(#cyc == 2 and cyc[1].item == "autre" and cyc[2].item == "cata" and cyc[2].amount == 40 and cyc[2].id == "cata",
    "cycle : la liste est triee, un objet une fois (" .. #cyc .. ")")
  local sc = Ml.new()
  local out = Am.seed(sc, 60, {}, {}, BOOK, Ml, cyc)
  local by = {}
  for _, o in ipairs(out) do by[o.item] = o end
  ck(by.cata and by.cata.need == 40 * Am.CYCLE_RUNS and by.autre and by.autre.need == 5 * Am.CYCLE_RUNS,
    "cycle : de quoi faire " .. Am.CYCLE_RUNS .. " fabrications (" .. tostring(by.cata and by.cata.need) .. ")")
  local s_cata = source_of(sc, 60, "cata")
  ck(s_cata ~= nil and s_cata.src == "amorce" and math.abs(s_cata.rate * Id.HORIZON_MIN - 80) < 1e-9, "cycle : la graine entre au mall, couverte en 10 min")
  ck(by.cata and type(by.cata.cause) == "string" and by.cata.cause:find("cycle cata", 1, true) and by.cata.cause:find("cata consomme cata", 1, true),
    "cycle : la cause est ecrite (" .. tostring(by.cata and by.cata.cause) .. ")")
  local big = Am.seed(Ml.new(), 60, {}, {}, BOOK, Ml, Am.flatten({ seed = { m = { { "cata", 1e6 } } }, cyc = { m = "m" } }))
  ck(#big == 1 and big[1].need == Am.CYCLE_HARD and Id.barre(big[1].rate, 1, 1000) <= Am.CYCLE_HARD, "cycle : graine bornee (" .. tostring(big[1] and big[1].need) .. ")")
  local none = Am.seed(Ml.new(), 60, {}, {}, BOOK, Ml, Am.flatten({ seed = {}, cyc = {} }))
  ck(#none == 0 and #Am.seed(Ml.new(), 60, {}, {}, BOOK, Ml, nil) == 0 and #Am.flatten(nil) == 0, "sans cycle, rien")
  local stocked = Am.seed(Ml.new(), 60, {}, { cata = 100, autre = 3 }, BOOK, Ml, cyc)
  ck(#stocked == 1 and stocked[1].item == "autre" and stocked[1].need == 7, "cycle : le stock est deduit (cata couvert, autre 10 - 3)")
  local raw, rawskip = Am.seed(Ml.new(), 60, {}, {}, BOOK, Ml, Am.flatten({ seed = { m = { { "brut", 10 } } }, cyc = { m = "m" } }))
  ck(#raw == 0, "cycle : un objet sans recette n'est pas seme")
  ck(#rawskip == 1 and rawskip[1].item == "brut" and rawskip[1].need == 20 and tostring(rawskip[1].cause):find("cycle m", 1, true),
    "cycle : le refus faute de recette a la main est rendu pour le journal, avec sa cause")
  local _, nobom = Am.seed(Ml.new(), 60, { { bom = { brut = 3 } } }, {}, BOOK, Ml, nil)
  ck(#nobom == 0, "liste de materiel sans recette : ecartee comme avant (pas de refus ecrit)")
  local bad = Am.flatten({ seed = { m = { { "x", 0 / 0 }, { "y", -3 }, { "z", "9" }, { 7, 4 }, { "w", math.huge }, { "ok", 2 } } }, cyc = {} })
  ck(#bad == 1 and bad[1].item == "ok" and bad[1].id == "m", "cycle : mesure illisible (NaN, negative, texte, infinie) ecartee")
  local both = Am.seed(Ml.new(), 60, { { bom = { cata = 100 } } }, {}, BOOK, Ml, cyc)
  local bb = {}
  for _, o in ipairs(both) do bb[o.item] = o end
  ck(bb.cata and bb.cata.need == 100 and tostring(bb.cata.cause):find("materiel", 1, true) and tostring(bb.cata.cause):find("cycle cata", 1, true),
    "cycle : dans la liste de materiel ET dans un cycle, le plus grand besoin, les deux causes")
  local st2 = Ml.new()
  Ml.want(st2, 50, "cata", 99, "capi")
  Am.seed(st2, 60, {}, {}, BOOK, Ml, cyc)
  ck(st2.want.cata.src == "capi" and st2.want.cata.rate == 99, "cycle : une demande plus forte d'une autre source n'est pas ecrasee")
  for _, o in ipairs(Am.seed(Ml.new(), 60, { { bom = { bras = 6 } } }, {}, BOOK, Ml)) do
    ck(type(o.cause) == "string" and o.cause:find("materiel", 1, true), "graine de la liste de materiel : cause ecrite (" .. o.item .. ")")
  end
  return fails
end

print("[AMORCE] 1-3. règle")
check(battery(Am0, true) == 0, "batterie sans échec")

-- 4. sérialisable, déterministe
do
  local function has_fn(t, seen)
    seen = seen or {}
    if seen[t] then return false end
    seen[t] = true
    for _, v in pairs(t) do
      if type(v) == "function" then return true end
      if type(v) == "table" and has_fn(v, seen) then return true end
    end
    return false
  end
  local projets = { { bom = { b = 2, a = 3 } }, { bom = { a = 1, c = 4 } } }
  local s1, s2 = Ml.new(), Ml.new()
  local o1 = Am0.seed(s1, 0, projets, {}, BOOK, Ml)
  local o2 = Am0.seed(s2, 0, { { bom = { a = 3, b = 2 } }, { bom = { c = 4, a = 1 } } }, {}, BOOK, Ml)
  local k1, k2 = {}, {}
  for _, o in ipairs(o1) do k1[#k1 + 1] = o.item .. o.need end
  for _, o in ipairs(o2) do k2[#k2 + 1] = o.item .. o.need end
  check(table.concat(k1, ",") == "a4,b2,c4" and table.concat(k1, ",") == table.concat(k2, ","), "déterministe, trié (" .. table.concat(k1, ",") .. ")")
  Am0.observe(s1, 60, { a = { made = 1, hand = 1 } }, nil)
  check(not has_fn(s1), "état sérialisable (aucune fonction)")
end

-- 5. coût en instructions
print("[AMORCE] 5. coût")
do
  local function count(fn)
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    fn()
    debug.sethook()
    return c
  end
  local projets = {}
  for p = 1, 40 do
    local b = {}
    for i = 1, 30 do b["o" .. ((p * 7 + i) % 60)] = i end
    projets[p] = { bom = b }
  end
  local flows = {}
  for i = 0, 59 do flows["o" .. i] = { made = i % 3, hand = i % 2 } end
  local st = Ml.new()
  local seed = count(function() Am0.seed(st, 0, projets, {}, BOOK, Ml) end)
  local obs = count(function() Am0.observe(st, 3600, flows, nil) end)
  local tasks = {}
  for i = 1, 100 do tasks[i] = { kind = "craft", item = "o" .. (i % 60), prio = 40 } end
  local filt = count(function() Am0.filter_crafts(st, tasks, {}, 90, Ml) end)
  print(string.format("[AMORCE] instructions : graine (40 projets, K = %d, 30 objets chacun) %d ; relevé de 60 objets %d ; filtre de 100 fabrications %d",
    Am0.K, seed, obs, filt))
  check(seed < 20000 and obs < 30000 and filt < 10000, "coût borné (une graine et un relevé par minute)")
end

-- 6. mutants
print("[AMORCE] 6. mutants")
local function mutant(name, patch)
  local Am = copy(Am0)
  patch(Am)
  local ok, f = pcall(battery, Am, false)
  if not ok then print("  (mutant " .. name .. " : plantage, " .. tostring(f) .. ")"); f = 1 end
  check(f > 0, "mutant refusé : " .. name .. " (" .. tostring(f) .. " échec(s))")
end
mutant("graine absente", function(Am) Am.seed = function() return {} end end)
mutant("graine non bornée à la liste de matériel (stock ignoré, liste doublée)", function(Am)
  local base = Am.seed
  Am.seed = function(st, tick, projets, have, book, ml)
    local dbl = {}
    for i, p in ipairs(projets) do local b = {} for k, v in pairs(p.bom) do b[k] = 2 * v end dbl[i] = { bom = b } end
    return base(st, tick, dbl, {}, book, ml)
  end
end)
mutant("retrait à la pose", function(Am)
  local base = Am.observe
  Am.observe = function(st, tick, flows, alive)
    local f2 = {}
    for k, v in pairs(flows or {}) do f2[k] = v end
    for k in pairs(alive or {}) do local v = f2[k] or { made = 0, hand = 0 }; f2[k] = { made = (v.made or 0) + 1, hand = v.hand or 0 } end
    return base(st, tick, f2, alive)
  end
end)
mutant("compteur remis à zéro au retrait", function(Am)
  local base = Am.observe
  Am.observe = function(st, ...)
    local r = base(st, ...)
    for _, x in ipairs(r) do st.amorce.hand[x.item] = 0 end
    return r
  end
end)
mutant("main refusée à stock nul", function(Am)
  Am.hand_allowed = function(st, item, have, ml)
    local a = st and st.amorce
    if a and a.done and a.done[item] then return false end
    return ml.hand_allowed(st, item, have)
  end
end)
mutant("sans verrou (retour à Ml.set_running seul)", function(Am)
  Am.hand_allowed = function(st, item, have, ml) return ml.hand_allowed(st, item, have) end
end)
mutant("graine qui écrase une demande plus forte", function(Am)
  Am.seed = function(st, tick, projets, have, book, ml)
    local sum, items = Am.bom(projets, Am.K)
    local out = {}
    for _, it in ipairs(items) do
      local need = sum[it] - ((have or {})[it] or 0)
      if need > 0 and book:recipe_for(it) then ml.want(st, tick, it, need / Am.HORIZON_MIN, Am.SRC); out[#out + 1] = { item = it, need = need } end
    end
    return out
  end
end)

mutant("graine de cycle non bornee", function(Am)
  local base = Am.seed
  Am.seed = function(st, tick, projets, have, book, ml, c)
    local out = base(st, tick, projets, have, book, ml, nil)
    for _, e in ipairs(c or {}) do
      local need = e.amount * 1e6
      ml.want(st, tick, e.item, need / Am.HORIZON_MIN, Am.SRC)
      out[#out + 1] = { item = e.item, need = need, rate = need / Am.HORIZON_MIN, cause = "cycle " .. tostring(e.id) .. " : cata consomme cata" }
    end
    return out
  end
end)
mutant("graine de cycle sans cause", function(Am)
  local base = Am.seed
  Am.seed = function(...)
    local out = base(...)
    for _, o in ipairs(out) do o.cause = nil end
    return out
  end
end)
mutant("cycle ignore", function(Am)
  local base = Am.seed
  Am.seed = function(st, tick, projets, have, book, ml) return base(st, tick, projets, have, book, ml, nil) end
end)
mutant("graine de cycle sans deduire le stock", function(Am)
  local base = Am.seed
  Am.seed = function(st, tick, projets, have, book, ml, c)
    local out = base(st, tick, projets, {}, book, ml, c)
    return out
  end
end)
mutant("mesure de cycle illisible semee", function(Am)
  Am.flatten = function(c)
    local out = {}
    for m, list in pairs((c or {}).seed or {}) do
      for _, e in ipairs(list) do out[#out + 1] = { item = tostring(e[1]), member = m, amount = tonumber(e[2]) or 1, id = m } end
    end
    table.sort(out, function(a, b) return a.item < b.item end)
    return out
  end
end)
mutant("cycle semé même sans cycle (graine fantome)", function(Am)
  local base = Am.seed
  Am.seed = function(st, tick, projets, have, book, ml, c)
    if c == nil or #c == 0 then c = { { item = "fantome", member = "f", amount = 3, id = "f" } } end
    return base(st, tick, projets, have, book, ml, c)
  end
end)

print(string.format("[AMORCE] BILAN : %d OK, %d ECHEC(S)", passes, failures))
os.exit(failures == 0 and 0 or 1)
