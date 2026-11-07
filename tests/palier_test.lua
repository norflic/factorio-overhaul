--[[
  Lot L10 (marches de stabilité) : test hors jeu de shared/ai3/palier.lua. Lancer depuis la racine du mod :
    lua5.2 tests/palier_test.lua   -> [L10] BILAN : N OK, 0 ECHEC(S)
  Mutants : substitution unique dans le source du module, rechargé ; la suite doit ÉCHOUER. Coût : instructions (debug.sethook).
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
  { "instabilite qui n'annule pas le minuteur", 'if st.until_tick then st.until_tick = nil return nil, "instable" end', 'if st.until_tick then return nil, "instable" end' },
  { "minuteur a mi-duree", "if tick >= st.until_tick then", "if tick + 9000 >= st.until_tick then" },
  { "bras libres ignores", "if h < Pl.HANDS_MIN then", "if false then" },
  { "entree absente = stable", 'if m == nil or h == nil or type(a.crise) ~= "boolean" then return false', 'if false then return false' },
  { "arbre fini ignore", 'if a.arbre_fini then return { kind = "equipement", n = 1 }, "marche" end', "" },
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
check(w <= 150 and wv <= 400, "cout borne (Pl.step <= 150, Pl.verdict <= 400)")

print(string.format("[L10] BILAN : %d OK, %d ECHEC(S)", pass, fail))
if fail > 0 then os.exit(1) end
