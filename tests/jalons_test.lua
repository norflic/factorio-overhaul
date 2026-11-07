--[[
  Lot VIDEO-TRACES, partie b (V03) : test hors jeu de shared/ai3/jalons.lua.
    §1 une ligne par époque et par faction, jamais deux fois (niveau qui monte, stagne, recule, remonte) ;
    §2 saut de niveau : toutes les époques franchies, dans l'ordre ;
    §3 bornes : niveau négatif ou au-delà de 15 ramené dans [0, 15] ;
    §4 factions indépendantes ;
    §5 ligne [FO-JALON] au format attendu ;
    §6 mutants appliqués au SOURCE : chacun doit faire échouer le test (sinon le test est trop faible).
  Usage : lua5.2 tests/jalons_test.lua   (depuis la racine du mod)
]]

local SRC_PATH = "shared/ai3/jalons.lua"

local pass, fail = 0, 0
local function check(cond, what)
  if cond then pass = pass + 1 else fail = fail + 1; print("ECHEC : " .. what) end
end

local function load_src(src)
  local chunk, err = load(src, "@" .. SRC_PATH)
  if not chunk then error(err) end
  return chunk()
end

--- Batterie : rend le nombre d'échecs de la règle `J` (0 = conforme) et le nombre de contrôles joués.
local function battery(J)
  local bad, n = 0, 0
  local function ok(c) n = n + 1; if not c then bad = bad + 1 end end
  local function eq(a, b) return table.concat(a, ",") == table.concat(b, ",") end
  -- §1 une fois par époque
  local s = {}
  ok(eq(J.crossed(s, "A", 0), {}))
  ok(eq(J.crossed(s, "A", 1), { 1 }))
  ok(eq(J.crossed(s, "A", 1), {}))
  ok(eq(J.crossed(s, "A", 2), { 2 }))
  ok(eq(J.crossed(s, "A", 2), {}))
  ok(eq(J.crossed(s, "A", 1), {}))   -- recul : rien
  ok(eq(J.crossed(s, "A", 2), {}))   -- remontée au même niveau : rien
  ok(eq(J.crossed(s, "A", 3), { 3 }))
  -- §2 saut
  local t = {}
  ok(eq(J.crossed(t, "B", 3), { 1, 2, 3 }))
  ok(eq(J.crossed(t, "B", 4), { 4 }))
  -- §3 bornes
  local u = {}
  ok(eq(J.crossed(u, "C", -2), {}))
  ok(eq(J.crossed(u, "C", 16), { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }))
  ok(eq(J.crossed(u, "C", 40), {}))
  -- §4 indépendance
  local v = {}
  ok(eq(J.crossed(v, "X", 2), { 1, 2 }))
  ok(eq(J.crossed(v, "Y", 1), { 1 }))
  ok(eq(J.crossed(v, "X", 2), {}))
  -- §5 format
  ok(J.line("F1", 3, 12.345) == "[FO-JALON] F1 : epoque 3 atteinte a 12.3 min")
  return bad, n
end

-- §1 à §5 sur le source réel
local J = load_src(assert(io.open(SRC_PATH, "rb")):read("*a"))
local bad_real, n_real = battery(J)
check(bad_real == 0, "§1-§5 la règle réelle donne une ligne par époque et par faction, une fois")

-- §6 mutants : chacun doit être vu par la batterie
local src = assert(io.open(SRC_PATH, "rb")):read("*a")
local MUTANTS = {
  { "re-journalise le niveau courant", "for k = top + 1, to do", "for k = top, to do" },
  { "ne retient jamais le niveau", "if to > top then seen[id] = to end", "if false then seen[id] = to end" },
  { "ignore la mémoire (repart de 0)", "local top = seen[id] or 0", "local top = 0" },
  { "retient le dernier niveau lu, même en recul", "if to > top then seen[id] = to end", "seen[id] = to" },
  { "pas de borne haute", "math.min(math.max(math.floor(level or 0), 0), J.EPOCHS)", "math.max(math.floor(level or 0), 0)" },
  { "mémoire partagée entre factions", "local top = seen[id] or 0", "local top = seen.any or 0; seen.any = top" },
}
local caught = 0
for _, m in ipairs(MUTANTS) do
  local a, b = src:find(m[2], 1, true)
  if not a then
    fail = fail + 1
    print("ECHEC : mutant absent du source (" .. m[1] .. ")")
  else
    local mutated = src:sub(1, a - 1) .. m[3] .. src:sub(b + 1)
    local okload, Jm = pcall(load_src, mutated)
    if not okload or battery(Jm) > 0 then caught = caught + 1 else fail = fail + 1; print("ECHEC : mutant survivant (" .. m[1] .. ")") end
  end
end
check(caught == #MUTANTS, "§6 tous les mutants sont détectés")

print(string.format("[FO-JALON-TEST] BILAN : %d OK, %d ECHEC(S) (%d controles de la regle ; mutants refuses %d sur %d)", pass, fail, n_real, caught, #MUTANTS))
if fail > 0 then os.exit(1) end
