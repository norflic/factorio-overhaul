--[[
  Lot L6 (portes avant d'étendre) : test hors jeu de shared/ai3/portes_extension.lua. Lancer depuis la racine du mod :
    lua5.2 tests/portes_extension_test.lua   -> [L6] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source du module, rechargé ; la suite doit ÉCHOUER. Coût : instructions (debug.sethook).
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/ai3/portes_extension.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L6] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

local function ord(key, t)
  t.key, t.item = key, t.item or key
  t.n, t.rank = t.n or 1, t.rank or 3
  return t
end
local function keys(list) local o = {} for _, x in ipairs(list) do o[#o + 1] = x.key end return table.concat(o, ",") end

local function suite(Pe)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  -- 1. Le défaut du 7/11 : 2 PNJ, 0 libre, 16 tâches libres. Fermée à la 2e mesure de suite (pas à la 1re).
  local D1 = { workers = 2, idle = 0, free_tasks = 16, batis = 10, open_sites = 0 }
  local st = Pe.new()
  local orders = { ord("chantier", { tours = true, site = true }), ord("tapis", { tours = true, belt = true }),
    ord("defense", { rank = 1, tours = true, site = true, n = 4 }) }
  local r1 = Pe.decide(st, D1, orders)
  want(not r1.closed, "D1 : une seule mesure tendue ne ferme pas")
  local r2 = Pe.decide(st, D1, orders)
  want(r2.closed, "D1 : fermee a la 2e mesure tendue")
  want(keys(r2.kept) == "tapis,defense", "D1 : chantier retenu, tapis et R1 gardes (" .. keys(r2.kept) .. ")")
  -- I2 : la défense (R1) garde ses 4 unités.
  want(r2.kept[2] and r2.kept[2].n == 4, "I2 : R1 ni retenu ni reduit")
  -- 2. Hystérésis : une mesure à peine sous le seuil de sortie ne rouvre pas ; 2 mesures détendues rouvrent.
  local mid = { workers = 10, idle = 1, free_tasks = 10, batis = 10, open_sites = 0 } -- 100 ‰ libres : ni tendu ni détendu
  Pe.decide(st, mid, {})
  Pe.decide(st, mid, {})
  want(st.closed, "hysteresis : 10 % libres ne rouvre pas (sortie a 20 %)")
  local calm = { workers = 10, idle = 3, free_tasks = 10, batis = 10, open_sites = 0 }
  Pe.decide(st, calm, {})
  want(st.closed, "hysteresis : une mesure detendue ne rouvre pas")
  local r3 = Pe.decide(st, calm, { ord("chantier", { tours = true, site = true }) })
  want(not r3.closed and keys(r3.kept) == "chantier", "2 mesures detendues rouvrent")
  -- 3. Seuil qui SUIT la taille : 30 PNJ, 10 libres, 20 tâches libres : pas tendu (seuil 92) ; 100 tâches : tendu.
  local big = Pe.new()
  local t30 = Pe.measure({ workers = 30, idle = 10, free_tasks = 20 })
  want(t30 == false, "30 PNJ, 20 taches libres : pas tendu (seuil qui suit l'effectif)")
  local t30b = Pe.measure({ workers = 30, idle = 10, free_tasks = 100 })
  want(t30b == true, "30 PNJ, 100 taches libres : tendu")
  local t30c = Pe.measure({ workers = 30, idle = 2, free_tasks = 0 })
  want(t30c == true, "30 PNJ, 2 libres (67 pour mille) : tendu")
  -- 4. Garde fermée : mesure absente ou effectif nul -> fermée.
  local ra = Pe.decide(big, { batis = 0, open_sites = 0 }, { ord("chantier", { tours = true }) })
  want(ra.closed and #ra.kept == 0, "mesure absente : porte fermee")
  local z = Pe.measure({ workers = 0, idle = 0, free_tasks = 0 })
  want(z == true, "aucun PNJ : tendu")
  -- 5. Bras à seuil croissant : 0 module -> 1 chantier ; 100 modules -> 5 ; ouverts déduits ; I1.
  local room0, lim0 = Pe.site_room(0, 0)
  local room100, lim100 = Pe.site_room(100, 2)
  want(lim0 == 1 and room0 == 1, "0 module : 1 chantier a la fois")
  want(lim100 == 5 and room100 == 3, "100 modules, 2 ouverts : 3 places (" .. room100 .. ")")
  local calm2 = { workers = 10, idle = 5, free_tasks = 0, batis = 50, open_sites = 1 } -- limite 3, 2 places
  local s5 = Pe.new()
  local many = {}
  for i = 1, 6 do many[i] = ord("c" .. i, { site = true }) end
  local r5 = Pe.decide(s5, calm2, many)
  want(#r5.kept == 2 and #r5.refused == 4, "I1 : 2 chantiers ouverts sur 6 demandes (" .. #r5.kept .. ")")
  -- 6. Petites marches : tendu (une seule mesure) -> une unité ; détendu -> n ; mesuré -> une unité.
  local s6 = Pe.new()
  local r6 = Pe.decide(s6, { workers = 4, idle = 0, free_tasks = 0, batis = 0, open_sites = 0 }, { ord("fours", { n = 3 }) })
  want(r6.kept[1] and r6.kept[1].n == 1 and r6.kept[1].reduced, "tendu : une unite par decision")
  local s6b = Pe.new()
  local r6b = Pe.decide(s6b, calm2, { ord("fours", { n = 3 }), ord("labos", { n = 2, measured = true }) })
  want(r6b.kept[1].n == 3 and r6b.kept[2].n == 1, "detendu : n garde ; manque mesure : une unite")
  -- 7. Anti-répétition : même objet mesuré deux décisions de suite -> retenu, sauf seul de son rang ; un autre objet passe.
  local s7 = Pe.new()
  Pe.decide(s7, calm2, { ord("a", { item = "x", measured = true }) })
  local r7 = Pe.decide(s7, calm2, { ord("a", { item = "x", measured = true }), ord("b", { item = "y", measured = true }) })
  want(keys(r7.kept) == "b", "repetition : x retenu, y passe (" .. keys(r7.kept) .. ")")
  local r7b = Pe.decide(s7, calm2, { ord("a", { item = "y", measured = true, alone = true }) })
  want(keys(r7b.kept) == "a", "repetition : seul en manque de son rang, permis")
  -- 7 bis. API option par option (decide_turn de la décision découpée) : places décomptées, R1 non réduit.
  local s7c = Pe.new()
  local g = Pe.gate(s7c, calm2)
  local why_site = Pe.check(g, ord("c", { site = true }))
  Pe.take(g, ord("c", { site = true }))
  Pe.take(g, ord("c2", { site = true }))
  local why_full = Pe.check(g, ord("c3", { site = true }))
  local n_def = Pe.units(g, ord("def", { rank = 1, n = 5 }))
  want(why_site == nil and why_full ~= nil and n_def == 5, "API option par option : places decomptees, R1 non reduit")
  -- 8. Déterminisme : mêmes entrées, mêmes sorties.
  local sa, sb = Pe.new(), Pe.new()
  local ra8 = Pe.decide(sa, D1, orders)
  local rb8 = Pe.decide(sb, D1, orders)
  want(Pe.describe(sa, ra8) == Pe.describe(sb, rb8), "deterministe")
  return bad
end

local Pe = require("shared.ai3.portes_extension")
local bad = suite(Pe)
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "suite du module")
print(string.format("[L6] suite : %d defaut(s)", #bad))

local MUTANTS = {
  { "porte du transport retiree", "if g.closed and o.tours and not o.belt then", "if false then" },
  { "tapis non exempte", "if g.closed and o.tours and not o.belt then", "if g.closed and o.tours then" },
  { "seuil fixe au lieu du seuil qui suit l'effectif", "local y = Pe.BACKLOG_PER * w + Pe.BACKLOG_BASE", "local y = 8" },
  { "bras : seuil fixe (sans les modules)", "local limit = math.floor(math.max(0, int(batis) or 0) / Pe.MODULES_PER_SITE) + 1", "local limit = 1" },
  { "R0 et R1 retenus (I2 rompu)", "if rank > Pe.SAFE_RANK then\n", "if true then\n" },
  { "petites marches retirees", "and (g.tense or o.measured) and", "and false and" },
  { "anti-repetition retiree", "elseif o.measured and o.item ~= nil and o.item == g.last_item and not o.alone then", "elseif false then" },
  { "sans hysteresis (rouvre des que non tendu)", "st.calm_n = calm and (st.calm_n or 0) + 1 or 0", "st.calm_n = (not tense) and 99 or 0" },
  { "mesure absente = porte ouverte", "return true, cause -- garde fermée", "return false, cause -- garde fermée" },
  { "fermee des la 1re mesure tendue", "if st.tense_n >= Pe.SAT_THINKS then", "if st.tense_n >= 1 then" },
  { "places de chantier non decomptees (I1 rompu)", "if o.site and rank > Pe.SAFE_RANK then g.room = g.room - 1 end", "" },
  { "anti-repetition sans memoire d'une decision a l'autre", "function Pe.finish(st, g) st.last_item = g.measured_item end", "function Pe.finish(st, g) end" },
}
local refused = 0
for _, m in ipairs(MUTANTS) do
  local s, n = SRC:gsub(m[2]:gsub("%p", "%%%0"), (m[3]:gsub("%%", "%%%%")))
  if n ~= 1 then
    check(false, "mutant introuvable (" .. n .. " substitution(s)) : " .. m[1])
  else
    local ok, Pm = pcall(load_mod, s)
    local ran, sb = false, nil
    if ok then ran, sb = pcall(suite, Pm) end
    local killed = (not ok) or (not ran) or (#sb > 0)
    if killed then refused = refused + 1 else print("[L6] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[L6] mutants refuses : %d sur %d", refused, #MUTANTS))

-- Coût en INSTRUCTIONS.
local function instr(fn, n)
  local worst = 0
  for _ = 1, n do
    local c = 0
    debug.sethook(function() c = c + 1 end, "", 1)
    fn()
    debug.sethook()
    if c > worst then worst = c end
  end
  return worst
end
local function orders_n(k)
  local l = {}
  for i = 1, k do l[i] = ord("o" .. i, { item = "i" .. (i % 7), n = 3, tours = i % 2 == 0, site = i % 3 == 0, measured = i % 4 == 0 }) end
  return l
end
local o8, o40 = orders_n(8), orders_n(40)
local st = Pe.new()
local a = { workers = 12, idle = 2, free_tasks = 20, batis = 60, open_sites = 1 }
local w0 = instr(function() Pe.transport(st, a) end, 50)
local w8 = instr(function() Pe.decide(st, a, o8) end, 50)
local w40 = instr(function() Pe.decide(st, a, o40) end, 20)
print(string.format("[L6] cout : mesure %d instructions ; decision a 8 ordres %d ; a 40 ordres %d (sethook, compte de 1)", w0, w8, w40))
check(w0 <= 300 and w8 <= 3000 and w40 <= 12000, "cout borne (mesure <= 300, 8 ordres <= 3 000, 40 ordres <= 12 000)")
check(w40 - w8 <= 6 * (w8 - w0) + 1000, "cout lineaire en nombre d'ordres")

print(string.format("[L6] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
