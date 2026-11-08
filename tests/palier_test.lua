--[[
  Lot L10 (marches de stabilité) : test hors jeu de shared/ai3/palier.lua. Lancer depuis la racine du mod :
    lua5.2 tests/palier_test.lua   -> [L10] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source du module, rechargé ; la suite doit ÉCHOUER. Coût : instructions (debug.sethook).
  Lot BLOCAGE-SORTIE-2 : soupape de dormance (un manque seul retient le palier 10 min alors que le stock libre dort : le puits de C2 s'ouvre à
  chaque décision, sans minuteur) ; section 8 de la suite et 10 mutants de plus.
]]
package.path = "./?.lua;" .. package.path
local PATH = "shared/ai3/palier.lua"
local pass, fail = 0, 0
local function check(ok, msg)
  if ok then pass = pass + 1 else fail = fail + 1 print("[L10] ECHEC : " .. msg) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local SRC = read(PATH)
local function load_mod(src) return assert(load(src, "=" .. PATH, "t", _ENV))() end

local STABLE = { manques = 0, crise = false, bras_libres = 3 }
local function with(t) local c = {} for k, v in next, STABLE do c[k] = v end for k, v in next, t do c[k] = v end return c end

local function suite(Pl)
  local bad = {}
  local function want(ok, msg) if not ok then bad[#bad + 1] = msg end end
  local TK = 18000
  -- 1. Minuteur : armé au tick 0, marche à 18 000 exactement, pas avant.
  local st = Pl.new()
  local m, ev = Pl.step(st, STABLE, 0)
  want(m == nil and ev == "arme", "stable : minuteur arme")
  m = Pl.step(st, STABLE, TK - 1)
  want(m == nil, "pas de marche avant 18 000 ticks")
  m, ev = Pl.step(st, STABLE, TK)
  want(m and m.kind == "recherche" and m.labs == 1 and ev == "marche", "marche a 18 000 ticks : un laboratoire")
  -- 2. I1 : pas de deuxième marche sans pose.
  m, ev = Pl.step(st, STABLE, 2 * TK)
  local m2 = Pl.step(st, STABLE, 4 * TK)
  want(m == nil and m2 == nil and ev == "attend_pose", "I1 : aucune marche sans pose entre elles")
  -- la pose (le laboratoire posé) relance le minuteur depuis zéro.
  m, ev = Pl.step(st, with({ pose = true }), 5 * TK)
  want(m == nil and st.until_tick == 6 * TK, "pose : minuteur relance depuis zero (" .. tostring(st.until_tick) .. ")")
  m = Pl.step(st, STABLE, 6 * TK)
  want(m ~= nil, "deuxieme marche apres la pose et 5 min stables")
  -- 3. Toute pose annule : posée à mi-course, la marche recule de 18 000 ticks depuis la pose.
  st = Pl.new()
  Pl.step(st, STABLE, 0)
  Pl.step(st, with({ pose = true }), 9000)
  m = Pl.step(st, STABLE, TK)
  want(m == nil, "pose a 9 000 : pas de marche a 18 000")
  m = Pl.step(st, STABLE, 9000 + TK)
  want(m ~= nil and st.annules == 1, "marche a 27 000 apres la pose")
  -- 4. Stabilité continue : un manque jette le minuteur ; une crise aussi ; plus de bras libre aussi.
  for _, bad_in in ipairs({ { manques = 1 }, { crise = true }, { bras_libres = 0 } }) do
    st = Pl.new()
    Pl.step(st, STABLE, 0)
    Pl.step(st, with(bad_in), 9000)
    m = Pl.step(st, STABLE, TK)
    local m_late = Pl.step(st, STABLE, 9000 + TK + 9000)
    want(m == nil and m_late ~= nil, "instabilite (" .. next(bad_in) .. ") : minuteur jete puis rearme")
  end
  -- 5. Garde fermée : entrées absentes -> jamais stable.
  st = Pl.new()
  local _, ev5 = Pl.step(st, { crise = false, bras_libres = 3 }, 0)
  Pl.step(st, { crise = false, bras_libres = 3 }, TK)
  want(st.until_tick == nil and st.marches == 0 and ev5 == "instable", "manques absent : pas stable")
  Pl.step(st, { manques = 0, bras_libres = 3 }, 0)
  want(st.until_tick == nil, "crise absente : pas stable")
  m, ev = Pl.step(st, STABLE, nil)
  want(m == nil and ev == "tick", "tick absent : rien")
  -- 6. Arbre fini : la marche va à l'équipement.
  st = Pl.new()
  Pl.step(st, with({ arbre_fini = true }), 0)
  m = Pl.step(st, with({ arbre_fini = true }), TK)
  want(m and m.kind == "equipement", "arbre fini : equipement")
  -- 8. Soupape de dormance (lot BLOCAGE-SORTIE-2).
  local SV = 10 * 3600
  local DORT = with({ manques = 1, dort = true })
  st = Pl.new()
  m, ev = Pl.step(st, DORT, 1000)
  want(m == nil and ev == "instable" and st.manque_depuis == 1000 and st.soupape == false, "soupape : le manque seul court, rien encore")
  m = Pl.step(st, DORT, 1000 + SV - 1)
  want(m == nil and st.soupape == false, "soupape : fermee a 36 000 - 1 ticks")
  m, ev = Pl.step(st, DORT, 1000 + SV)
  want(m and m.kind == "soupape" and ev == "soupape" and st.soupape == true and st.soupapes == 1, "soupape : ouverte a 36 000 ticks exactement")
  m, ev = Pl.step(st, DORT, 1000 + SV + 3600)
  want(m and m.kind == "soupape" and ev == "soupape_tient" and st.soupapes == 1, "soupape : tient a la decision suivante (une seule ouverture comptee)")
  want(st.until_tick == nil and st.wait_pose == false, "soupape : ni minuteur ni attente de pose")
  m = Pl.step(st, with({ manques = 1, dort = true, pose = true }), 1000 + SV + 7200)
  want(m and m.kind == "soupape", "soupape : une pose ne la ferme pas")
  -- fermeture : le stock ne dort plus
  m, ev = Pl.step(st, with({ manques = 1, dort = false }), 1000 + SV + 10800)
  want(m == nil and ev == "soupape_ferme" and st.soupape == false and st.manque_depuis == nil, "soupape : le stock ne dort plus -> fermee")
  m, ev = Pl.step(st, DORT, 1000 + SV + 14400)
  want(m == nil and st.manque_depuis == 1000 + SV + 14400, "soupape : refermee, la duree repart de zero")
  -- fermeture : plus rien ne manque -> la video reprend (minuteur de 5 min)
  st = Pl.new()
  Pl.step(st, DORT, 0)
  m = Pl.step(st, DORT, SV)
  want(m and m.kind == "soupape", "soupape : ouverte (cas video)")
  m, ev = Pl.step(st, with({ manques = 0, dort = true }), SV + 3600)
  want(m == nil and ev == "soupape_ferme" and st.until_tick == SV + 3600 + TK, "soupape : plus de manque -> fermee et minuteur de la video arme")
  m, ev = Pl.step(st, with({ manques = 0, dort = true }), SV + 3600 + TK)
  want(m and m.kind == "recherche" and ev == "marche", "soupape : la video reprend, marche a 5 min")
  -- une crise, plus de bras libre, un stock qui ne dort pas, ou plus de manque, a mi-chemin : duree remise a zero
  local BREAKS = {
    { name = "crise", a = { manques = 1, dort = true, crise = true } },
    { name = "bras", a = { manques = 1, dort = true, bras_libres = 0 } },
    { name = "dort faux", a = { manques = 1, dort = false } },
    { name = "dort absent", a = { manques = 1, dort = nil } },
    { name = "plus de manque", a = { manques = 0, dort = true } },
  }
  for _, b in ipairs(BREAKS) do
    st = Pl.new()
    Pl.step(st, DORT, 0)
    Pl.step(st, with(b.a), SV / 2)
    m = Pl.step(st, DORT, SV)
    want(m == nil, "soupape : " .. b.name .. " a mi-chemin -> duree remise a zero, pas de soupape a 36 000")
    m = Pl.step(st, DORT, 2 * SV)
    want(m and m.kind == "soupape", "soupape : " .. b.name .. " -> ouverte 36 000 ticks apres la remise a zero")
  end
  st = Pl.new()
  Pl.step(st, with({ manques = 1 }), 0)
  m = Pl.step(st, with({ manques = 1 }), 10 * SV)
  want(m == nil and st.soupapes == 0, "soupape : entree dort absente -> jamais de soupape")
  -- marche de la video puis soupape : l'attente de pose ne la retient pas
  st = Pl.new()
  Pl.step(st, STABLE, 0)
  m = Pl.step(st, STABLE, TK)
  want(m and m.kind == "recherche" and st.wait_pose == true, "soupape : marche de la video faite, attente de pose")
  Pl.step(st, DORT, TK + 100)
  m = Pl.step(st, DORT, TK + 100 + SV)
  want(m and m.kind == "soupape" and st.wait_pose == false, "soupape : ouverte malgre l'attente de pose de la marche d'avant")
  -- base saine : un manque de 5 min puis plus rien -> video a l'identique (aucune soupape)
  st = Pl.new()
  Pl.step(st, DORT, 0)
  Pl.step(st, DORT, 18000)
  Pl.step(st, with({ manques = 0, dort = true }), 18000 + 3600)
  m = Pl.step(st, with({ manques = 0, dort = true }), 18000 + 3600 + TK)
  want(m and m.kind == "recherche" and st.soupapes == 0, "base saine : manque de 5 min puis rien -> marche de la video, aucune soupape")
  want(Pl.shortage_only(DORT) and not Pl.shortage_only(STABLE) and not Pl.shortage_only(with({ manques = 1, crise = true }))
    and not Pl.shortage_only(with({ manques = 1, bras_libres = 0 })) and not Pl.shortage_only({ manques = 1 }) and not Pl.shortage_only(nil),
    "shortage_only : manque seul, rien d'autre")
  -- 9. Manques insolubles écartés (Pl.fixable) et raison du palier (Pl.explain).
  local n9, out9 = Pl.fixable({ a = 3, b = 2, c = 0, d = 1 }, { b = true, c = true })
  want(n9 == 2 and #out9 == 1 and out9[1] == "b", "fixable : a et d comptent, b impayable ecarte, c (quantite 0) ne compte pas")
  n9, out9 = Pl.fixable({ a = 1, b = 1 }, nil)
  want(n9 == 2 and #out9 == 0, "fixable : sans liste d'impayables, tout compte")
  n9, out9 = Pl.fixable({ z = 1, y = 1, x = 1 }, { z = true, x = true })
  want(n9 == 1 and out9[1] == "x" and out9[2] == "z", "fixable : ecartes rendus tries")
  n9 = Pl.fixable(nil, { a = true })
  want(n9 == nil, "fixable : build absent (L3 eteint) -> nil, jamais stable")
  -- la partie du DC : le seul manque est impayable (plastique sans petrole) -> stable des la premiere mesure, marche a 5 min
  st = Pl.new()
  local nn = Pl.fixable({ plastic = 12 }, { plastic = true })
  m, ev = Pl.step(st, with({ manques = nn, dort = true }), 0)
  want(nn == 0 and m == nil and ev == "arme" and st.until_tick == TK, "DC : manque impayable ecarte -> minuteur arme a la premiere mesure")
  m, ev = Pl.step(st, with({ manques = nn, dort = true }), TK)
  want(m and m.kind == "recherche", "DC : marche de la video a 5 min, sans attendre la soupape")
  st = Pl.new()
  nn = Pl.fixable({ plastic = 12, gear = 4 }, { plastic = true })
  Pl.step(st, with({ manques = nn, dort = true }), 0)
  want(nn == 1 and st.until_tick == nil and st.manque_depuis == 0, "DC : un manque soluble en plus -> instable, la soupape compte")
  -- Pl.explain
  local txt = Pl.explain(with({ manques = 2, dort = true }), "instable", { manque_depuis = 0 }, 9000)
  want(txt:find("instable", 1, true) and txt:find("2 manque", 1, true) and txt:find("soupape de dormance dans 7.5 min", 1, true), "explain : instable + soupape dans 7.5 min (" .. txt .. ")")
  txt = Pl.explain(with({ manques = 2, dort = false }), "instable", { manque_depuis = nil }, 9000)
  want(txt:find("pas de soupape", 1, true) ~= nil, "explain : le stock ne dort pas -> pas de soupape")
  txt = Pl.explain(with({ crise = true }), "instable", {}, 0)
  want(txt:find("crise", 1, true) and not txt:find("soupape", 1, true), "explain : crise")
  txt = Pl.explain(STABLE, "attente", { until_tick = 18000 }, 0)
  want(txt:find("marche dans 5.0 min", 1, true) ~= nil, "explain : stable, marche dans 5.0 min (" .. txt .. ")")
  want(Pl.explain(STABLE, "attend_pose", {}, 0):find("attente d'une pose", 1, true) ~= nil, "explain : attente de pose")
  want(Pl.explain(DORT, "soupape", {}, 0):find("soupape de dormance ouverte", 1, true) ~= nil, "explain : soupape ouverte")
  -- 7. Critère A/B.
  local A = { { seed = 1, prod = 100, manque_min = 30, crise_min = 2 }, { seed = 2, prod = 100, manque_min = 30, crise_min = 2 },
    { seed = 3, prod = 100, manque_min = 30, crise_min = 2 } }
  local function B(p, m1, m2, m3, c)
    return { { seed = 1, prod = p, manque_min = m1, crise_min = c }, { seed = 2, prod = p, manque_min = m2, crise_min = c },
      { seed = 3, prod = p, manque_min = m3, crise_min = c } }
  end
  want(Pl.verdict(A, B(96, 10, 10, 40, 2)) == "B", "A/B : production tenue a 96 %, moins de manque sur 2 graines : B")
  want(Pl.verdict(A, B(94, 10, 10, 10, 2)) == "A", "A/B : 6 % de production perdue : A")
  want(Pl.verdict(A, B(100, 10, 40, 40, 2)) == "A", "A/B : moins de manque sur 1 graine seulement : A")
  want(Pl.verdict(A, B(100, 10, 10, 10, 3)) == "A", "A/B : plus de crise : A")
  want(Pl.verdict(A, { A[1], A[2] }) == "A", "A/B : 2 graines seulement : A")
  local Bx = B(100, 10, 10, 10, 2)
  Bx[2].seed = 9
  want(Pl.verdict(A, Bx) == "A", "A/B : graines differentes : A")
  return bad
end

local Pl = require("shared.ai3.palier")
local bad = suite(Pl)
for _, m in ipairs(bad) do check(false, m) end
check(#bad == 0, "suite du module")
print(string.format("[L10] suite : %d defaut(s)", #bad))

local MUTANTS = {
  { "minuteur non annule par la pose", "st.until_tick, st.wait_pose, cancelled = nil, false, true", "st.wait_pose, cancelled = false, true" },
  { "marche sans condition de stabilite", "local ok = Pl.stable(a)", "local ok = true" },
  { "deux marches sans pose (I1)", 'if st.wait_pose then return nil, "attend_pose" end', "" },
  { "instabilite qui n'annule pas le minuteur", 'if st.until_tick then st.until_tick = nil return nil, closed and "soupape_ferme" or "instable" end', 'if st.until_tick then return nil, closed and "soupape_ferme" or "instable" end' },
  { "minuteur a mi-duree", "if tick >= st.until_tick then", "if tick + 9000 >= st.until_tick then" },
  { "bras libres ignores", "if h < Pl.HANDS_MIN then", "if false then" },
  { "entree absente = stable", 'if m == nil or h == nil or type(a.crise) ~= "boolean" then return false, "entree absente (garde fermee)" end', 'if false then return false, "entree absente (garde fermee)" end' },
  { "arbre fini ignore", 'if a.arbre_fini then return { kind = "equipement", n = 1 }, "marche" end', "" },
  { "soupape : ouverte a mi-duree", "tick - st.manque_depuis >= Pl.SOUPAPE_TICKS then", "tick - st.manque_depuis >= Pl.SOUPAPE_TICKS / 2 then" },
  { "soupape : stock qui ne dort pas ignore", "if Pl.shortage_only(a) and a.dort == true then", "if Pl.shortage_only(a) then" },
  { "soupape : duree non remise a zero", "  else\n    st.manque_depuis = nil\n  end", "  end" },
  { "soupape : crise ignoree", "return m > 0 and not a.crise and h >= Pl.HANDS_MIN", "return m > 0 and h >= Pl.HANDS_MIN" },
  { "soupape : bras libres ignores", "return m > 0 and not a.crise and h >= Pl.HANDS_MIN", "return m > 0 and not a.crise" },
  { "soupape : jamais refermee", "local closed = st.soupape == true\n  st.soupape = false\n", "local closed = st.soupape == true\n" },
  { "soupape : ouvertures mal comptees", "if first then st.soupapes = (st.soupapes or 0) + 1 end", "st.soupapes = (st.soupapes or 0) + 1" },
  { "soupape : puits non ouvert", 'return { kind = "soupape" }, first and "soupape" or "soupape_tient"', 'return nil, first and "soupape" or "soupape_tient"' },
  { "soupape : attente de pose gardee", "st.until_tick, st.wait_pose = nil, false -- la vidéo reprendra à zéro à la fermeture", "st.until_tick = nil" },
  { "soupape : minuteur de la video non rearme a la fermeture", 'return nil, closed and "soupape_ferme" or (cancelled and "annule" or "arme")', 'return nil, cancelled and "annule" or "arme"' },
  { "fixable : les impayables comptent", "if impayable and impayable[k] then out[#out + 1] = k else n = n + 1 end", "n = n + 1" },
  { "fixable : une quantite nulle compte", "if (num(build[k]) or 0) > 0 then", "if true then" },
  { "fixable : build absent = aucun manque", "if type(build) ~= \"table\" then return nil, {} end", "if type(build) ~= \"table\" then return 0, {} end" },
  { "explain : delai de la soupape faux", "Pl.SOUPAPE_TICKS - (tick - st.manque_depuis)", "Pl.SOUPAPE_TICKS" },
  { "explain : stable sans minuteur lu", "if st and st.until_tick then", "if false then" },
  { "A/B : perte de production toleree", "if pb * 1000 < pa * (1000 - Pl.PROD_TOL_PM) then", "if false then" },
  { "A/B : une seule graine gagnee suffit", "if wins < Pl.WIN_MIN then", "if wins < 1 then" },
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
    if killed then refused = refused + 1 else print("[L10] mutant NON refuse : " .. m[1]) end
    check(killed, "mutant refuse : " .. m[1])
  end
end
print(string.format("[L10] mutants refuses : %d sur %d", refused, #MUTANTS))

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
local st = Pl.new()
local tick = 0
local w = instr(function() tick = tick + 3600 Pl.step(st, (tick % 36000 == 0) and with({ pose = true }) or STABLE, tick) end, 200)
local A3 = { { seed = 1, prod = 100, manque_min = 30, crise_min = 2 }, { seed = 2, prod = 100, manque_min = 30, crise_min = 2 },
  { seed = 3, prod = 100, manque_min = 30, crise_min = 2 } }
local wv = instr(function() Pl.verdict(A3, A3) end, 20)
print(string.format("[L10] cout : Pl.step pire %d instructions ; Pl.verdict (3 graines) %d (sethook, compte de 1)", w, wv))
check(w <= 150 and wv <= 400, "cout borne (Pl.step <= 150, Pl.verdict <= 400 ; la soupape de dormance coute 125)")

print(string.format("[L10] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
