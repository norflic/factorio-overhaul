--[[
  Lot RESEAU-VIVANT : test hors jeu des fils REELS dans le plan de reparation (shared/team/reseau.lua, R.repair avec net.edges).
    1 sans `edges`, deux poteaux vivants a portee sont tenus pour relies : un consommateur sur un ilot reel est juge alimente, plan vide ;
    2 avec `edges` (les fils du moteur : aucun fil entre eux), le plan choisit le poteau perdu qui les relie ;
    3 avec `edges` complets (les deux poteaux sont relies), le plan reste vide : rien n'est releve pour rien ;
    4 les paires ou entre un poteau perdu restent calculees a la portee ; 5 mutants.
  Usage : lua5.2 tests/reseau_fils_test.lua   (depuis la racine du mod)
]]
package.path = "./?.lua;" .. package.path
local oks, fails = 0, 0
local function check(c, msg) if c then oks = oks + 1 else fails = fails + 1; print("  ECHEC : " .. msg) end end
local function read(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s end
local SRC = read("shared/team/reseau.lua")
local function load_r(src) local fn, err = load(src, "=reseau", "t"); assert(fn, err); return fn() end
local R = load_r(SRC)

local function pole(x, y) return { x = x, y = y, wire = 7.5, supply = 2.5 } end
local function box(cx, cy) return { x0 = cx - 1, y0 = cy - 1, x1 = cx + 1, y1 = cy + 1 } end
local gen = { box(0, 0) }
-- A couvre la centrale, B couvre le consommateur, a 6 tuiles l'un de l'autre (a portee) ; C = poteau perdu au milieu
local live = { pole(2.5, 0), pole(8.5, 0) }
local cons = { box(10, 0) }
local lost = { pole(5.5, 0) }

local plan = R.repair({ poles = live, consumers = cons, producers = gen }, lost)
check(#plan.chosen == 0, "sans fils reels : le modele croit A et B relies, plan vide")

local plan2 = R.repair({ poles = live, consumers = cons, producers = gen, edges = {} }, lost)
check(#plan2.chosen == 1 and plan2.chosen[1] == 1, "avec les fils reels (aucun) : le poteau perdu qui les relie est choisi")
check(plan2.restored == 1, "le consommateur est rallume")

local plan3 = R.repair({ poles = live, consumers = cons, producers = gen, edges = { { 1, 2 } } }, lost)
check(#plan3.chosen == 0, "fils reels complets : rien n'est releve pour rien")

-- 4 : un poteau perdu trop loin des deux ne relie rien
local far = { pole(5.5, 12) }
local plan4 = R.repair({ poles = live, consumers = cons, producers = gen, edges = {} }, far)
check(#plan4.chosen == 0, "poteau perdu hors de portee des deux : jamais choisi")

-- 5 mutants
local MUT = {
  { "edges ignores a l'analyse initiale", "producers = net.producers, edges = edges_with(net, all, nlive) }", "producers = net.producers }" },
  { "paires du poteau perdu oubliees", "if e[2] > nlive then out[#out + 1] = e end", "" },
  { "edges ignores a l'elagage", "edges = edges_with(net, poles, nlive) })\n    for _, k in ipairs(must)", "})\n    for _, k in ipairs(must)" },
}
local refused = 0
for _, m in ipairs(MUT) do
  local s, e = SRC:find(m[2], 1, true)
  assert(s, "mutant introuvable : " .. m[1])
  local R2 = load_r(SRC:sub(1, s - 1) .. m[3] .. SRC:sub(e + 1))
  local a = R2.repair({ poles = live, consumers = cons, producers = gen, edges = {} }, lost)
  local b = R2.repair({ poles = live, consumers = cons, producers = gen, edges = { { 1, 2 } } }, lost)
  local killed = not (#a.chosen == 1 and a.restored == 1) or #b.chosen ~= 0
  check(killed, "mutant refuse : " .. m[1])
  if killed then refused = refused + 1 end
end
print(string.format("[FILS] mutants refuses : %d sur %d", refused, #MUT))
print(string.format("[FILS] BILAN : %d OK, %d ECHEC(S)", oks, fails))
os.exit(fails == 0 and 0 or 1)
